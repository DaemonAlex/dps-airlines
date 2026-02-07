-- Server: Maintenance system

-- Get maintenance status for an aircraft at an airport
lib.callback.register('dps-airlines:server:getMaintenanceStatus', function(source, model, airportCode)
    local ok = Validation.Check(source, { employee = true })
    if not ok then return nil end

    if not Validation.ValidateAirportCode(airportCode) then return nil end

    return Cache.Get('maint_' .. model .. '_' .. airportCode, Constants.CACHE_MAINTENANCE, function()
        local result = MySQL.single.await(
            'SELECT * FROM airline_maintenance WHERE aircraft_model = ? AND airport_code = ?',
            { model, airportCode }
        )
        if not result then
            -- No record means pristine condition
            return { condition_pct = 100, flights_since_inspection = 0, status = Constants.MAINT_GOOD }
        end
        return result
    end)
end)

-- Perform maintenance (ground crew or boss)
lib.callback.register('dps-airlines:server:performMaintenance', function(source, model, airportCode, repairPoints)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true,
        rateLimit = { action = 'maintenance', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return false, reason end

    local role = Validation.GetPlayerRole(source)
    if role ~= Constants.ROLE_GROUND_CREW and role ~= Constants.ROLE_CHIEF_PILOT then
        return false, 'Must be Ground Crew or Chief Pilot'
    end

    if not Validation.ValidateNumber(repairPoints, 1, 100) then return false, 'Invalid repair amount' end

    local cost = repairPoints * Config.Maintenance.repairCostPerPoint

    -- Check society funds
    local balance = Bridge.GetSocietyBalance(Config.SocietyAccount)
    if balance < cost then return false, 'Insufficient company funds' end

    -- Deduct from society
    Bridge.RemoveSocietyMoney(Config.SocietyAccount, cost)

    -- Update maintenance record
    MySQL.query.await([[
        INSERT INTO airline_maintenance (aircraft_model, airport_code, condition_pct, flights_since_inspection, status)
        VALUES (?, ?, ?, 0, ?)
        ON DUPLICATE KEY UPDATE
            condition_pct = LEAST(100, condition_pct + ?),
            status = CASE
                WHEN LEAST(100, condition_pct + ?) > 75 THEN 'good'
                WHEN LEAST(100, condition_pct + ?) > 50 THEN 'fair'
                ELSE 'poor'
            END
    ]], {
        model, airportCode, math.min(100, repairPoints), Constants.MAINT_GOOD,
        repairPoints, repairPoints, repairPoints
    })

    Cache.Invalidate('maint_' .. model .. '_' .. airportCode)

    -- Create ground task record for stats
    local player = Bridge.GetPlayer(source)
    if player then
        MySQL.update.await(
            'UPDATE airline_pilot_stats SET ground_tasks_completed = ground_tasks_completed + 1 WHERE citizenid = ?',
            { player.identifier }
        )
        Payments.PayPlayer(source, Payments.CalculateGroundTaskPay(Constants.TASK_MAINTENANCE), 'Maintenance work')
        Cache.Invalidate('stats_' .. player.identifier)
    end

    return true, { cost = cost, repaired = repairPoints }
end)

-- Perform inspection
lib.callback.register('dps-airlines:server:performInspection', function(source, model, airportCode)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true,
        rateLimit = { action = 'inspection', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return false, reason end

    MySQL.query.await([[
        UPDATE airline_maintenance SET flights_since_inspection = 0, last_inspection = NOW()
        WHERE aircraft_model = ? AND airport_code = ?
    ]], { model, airportCode })

    Cache.Invalidate('maint_' .. model .. '_' .. airportCode)
    return true
end)

-- Get all maintenance records for an airport
lib.callback.register('dps-airlines:server:getAirportMaintenance', function(source, airportCode)
    local ok = Validation.Check(source, { employee = true, onDuty = true })
    if not ok then return {} end

    if not Validation.ValidateAirportCode(airportCode) then return {} end

    return MySQL.query.await(
        'SELECT * FROM airline_maintenance WHERE airport_code = ? ORDER BY condition_pct ASC',
        { airportCode }
    )
end)
