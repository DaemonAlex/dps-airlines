-- Server: Helicopter operations (medevac, tour, VIP, search & rescue)

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

    local pay = Payments.CalculateHeliPay(op.operation_type, details or {})
    local duration = details and details.duration or 0

    MySQL.update.await([[
        UPDATE airline_heli_ops SET
            status = ?, duration = ?, pay_amount = ?, completed_at = NOW(),
            details = ?
        WHERE id = ?
    ]], {
        Constants.DB_STATUS_COMPLETED, duration, pay,
        json.encode(details or {}), opId
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
