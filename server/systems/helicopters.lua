-- Server: Helicopter operations (medevac, tour, VIP, search & rescue)

-- Server-tracked state for every active operation, keyed by opId. This is the ONLY
-- source of truth for op timing/completion - the client's `details` payload is ignored
-- for anything that affects pay (C1 fix).
local ActiveHeliOps = {}  -- [opId] = { startTime, opType, citizenid, source, destinationCode }

---Server-side distance from a coordinate to the nearest helipad, optionally filtered
---to pads that support a given operation type.
---@param coords vector3
---@param requiredType string|nil
---@return number distance (math.huge if none found)
local function NearestHelipadDist(coords, requiredType)
    local best = math.huge
    for _, pad in ipairs(Locations.Helipads) do
        local matches = true
        if requiredType then
            matches = false
            for _, t in ipairs(pad.types or {}) do
                if t == requiredType then matches = true break end
            end
        end
        if matches then
            local d = #(coords - pad.coords)
            if d < best then best = d end
        end
    end
    return best
end

---Server-side distance from a coordinate to a specific helipad by code.
---@param coords vector3
---@param code string
---@return number distance (math.huge if not found)
local function HelipadDistByCode(coords, code)
    for _, pad in ipairs(Locations.Helipads) do
        if pad.code == code then
            return #(coords - pad.coords)
        end
    end
    return math.huge
end

-- Start helicopter operation
lib.callback.register('dps-airlines:server:startHeliOp', function(source, data)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true, canFly = true,
        rateLimit = { action = 'startHeliOp', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return nil, reason end

    if not Config.Helicopters.enabled then return nil, 'Helicopter ops disabled' end
    if not data or not data.opType then return nil, 'Invalid data' end

    local validTypes = { Constants.HELI_MEDEVAC, Constants.HELI_TOUR, Constants.HELI_VIP, Constants.HELI_SEARCH }
    local validOp = false
    for _, t in ipairs(validTypes) do
        if data.opType == t then validOp = true break end
    end
    if not validOp then return nil, 'Invalid operation type' end

    local heli = Locations.GetHeliConfig(data.model)
    if not heli then return nil, 'Invalid helicopter model' end

    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    local opId = MySQL.insert.await([[
        INSERT INTO airline_heli_ops
        (operation_type, pilot_citizenid, helicopter_model, origin_code, destination_code, status)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        data.opType, player.identifier, data.model, data.originCode or '',
        data.destinationCode or '', Constants.DB_STATUS_ACTIVE
    })

    -- Record the authoritative server start time / target for this op.
    ActiveHeliOps[opId] = {
        startTime = GetGameTimer(),
        opType = data.opType,
        citizenid = player.identifier,
        source = source,
        destinationCode = data.destinationCode,
    }

    return {
        opId = opId,
        opType = data.opType,
        model = data.model,
    }
end)

-- Complete helicopter operation
lib.callback.register('dps-airlines:server:completeHeliOp', function(source, opId, details)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true, canFly = true,
        rateLimit = { action = 'completeHeliOp', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return nil, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    local op = MySQL.single.await(
        'SELECT * FROM airline_heli_ops WHERE id = ? AND pilot_citizenid = ? AND status = ?',
        { opId, player.identifier, Constants.DB_STATUS_ACTIVE }
    )
    if not op then return nil, 'Operation not found' end

    -- Everything that affects pay is derived from SERVER state, never the client payload.
    local state = ActiveHeliOps[opId]

    -- Server-computed elapsed duration (monotonic game timer), clamped.
    local duration = 0
    if state then
        duration = math.max(0, math.min((GetGameTimer() - state.startTime) / 1000.0, Constants.HELI_MAX_OP_TIME))
    end

    -- Server-sampled player position at completion.
    local ped = GetPlayerPed(source)
    local coords = (ped and ped > 0) and GetEntityCoords(ped) or nil

    local opType = op.operation_type
    local opKey = Payments.HeliOpConfigKey[opType]
    local opCfg = opKey and Config.Helicopters[opKey] or {}

    -- Build the bonus inputs entirely server-side.
    local serverDetails = {}

    if opType == Constants.HELI_MEDEVAC then
        -- Bonus only if the pilot actually flew for a plausible time AND is at a
        -- medevac-capable pad (the hospital) on completion.
        local atHospital = coords and NearestHelipadDist(coords, Constants.HELI_MEDEVAC) <= Constants.HELI_DEST_RADIUS
        if duration >= Constants.HELI_MIN_OP_TIME and atHospital then
            local timeLimit = opCfg.timeLimit or 300
            serverDetails.timeRemaining = math.max(0, timeLimit - duration)
        else
            serverDetails.timeRemaining = 0
        end

    elseif opType == Constants.HELI_TOUR then
        -- Credit one waypoint per fixed slice of elapsed server time, hard-capped.
        serverDetails.waypointsHit = math.min(
            Constants.TOUR_MAX_WAYPOINTS,
            math.floor(duration / Constants.TOUR_SEC_PER_WAYPOINT)
        )

    elseif opType == Constants.HELI_VIP then
        -- Pays base rate only (see Payments.CalculateHeliPay); still require the pilot
        -- to have actually reached the booked destination pad to be paid at all.
        local atDest = op.destination_code and op.destination_code ~= ''
            and coords and HelipadDistByCode(coords, op.destination_code) <= Constants.HELI_DEST_RADIUS
        if not atDest or duration < Constants.HELI_MIN_OP_TIME then
            -- Not a legitimate completion: close the op with no pay.
            ActiveHeliOps[opId] = nil
            MySQL.update.await([[
                UPDATE airline_heli_ops SET status = ?, duration = ?, pay_amount = 0, completed_at = NOW()
                WHERE id = ?
            ]], { Constants.DB_STATUS_COMPLETED, math.floor(duration), opId })
            return nil, 'Destination not reached'
        end

    elseif opType == Constants.HELI_SEARCH then
        -- The search target is generated client-side and not knowable server-side, so
        -- rescue credit is gated purely on a plausible elapsed time within the limit.
        local timeLimit = opCfg.timeLimit or 600
        serverDetails.rescued = (duration >= Constants.HELI_MIN_OP_TIME and duration <= timeLimit)
    end

    local pay = Payments.CalculateHeliPay(opType, serverDetails)

    ActiveHeliOps[opId] = nil

    MySQL.update.await([[
        UPDATE airline_heli_ops SET
            status = ?, duration = ?, pay_amount = ?, completed_at = NOW(),
            details = ?
        WHERE id = ?
    ]], {
        Constants.DB_STATUS_COMPLETED, math.floor(duration), pay,
        json.encode(serverDetails), opId
    })

    Payments.PayPlayer(source, pay, 'Helicopter operation: ' .. op.operation_type)

    -- Update flight hours
    MySQL.update.await(
        'UPDATE airline_pilot_stats SET flight_hours = flight_hours + ?, total_earnings = total_earnings + ? WHERE citizenid = ?',
        { duration / 3600.0, pay, player.identifier }
    )

    Cache.Invalidate('stats_' .. player.identifier)

    return {
        pay = pay,
        opType = op.operation_type,
        duration = duration,
    }
end)

-- Get available helicopter operations
lib.callback.register('dps-airlines:server:getHeliOps', function(source)
    local ok = Validation.Check(source, { employee = true, onDuty = true })
    if not ok then return {} end

    -- Get available helipads near the player
    return MySQL.query.await(
        'SELECT * FROM airline_heli_ops WHERE status = ? ORDER BY started_at DESC LIMIT 20',
        { Constants.DB_STATUS_ACTIVE }
    )
end)

-- Spawn helicopter
lib.callback.register('dps-airlines:server:spawnHelicopter', function(source, model, padCode)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true, canFly = true,
        rateLimit = { action = 'spawnHeli', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return nil, reason end

    local heli = Locations.GetHeliConfig(model)
    if not heli then return nil, 'Invalid helicopter' end

    -- Find the helipad
    for _, pad in ipairs(Locations.Helipads) do
        if pad.code == padCode then
            return {
                model = model,
                coords = pad.spawn,
                heading = pad.heading,
            }
        end
    end

    return nil, 'Helipad not found'
end)

-- Drop any tracked heli-op state for a player who disconnects mid-operation.
AddEventHandler('playerDropped', function()
    local src = source
    for opId, state in pairs(ActiveHeliOps) do
        if state.source == src then
            ActiveHeliOps[opId] = nil
        end
    end
end)
