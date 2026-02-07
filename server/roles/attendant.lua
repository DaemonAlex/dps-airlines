-- Server: Flight Attendant role logic

-- Join a flight as attendant
lib.callback.register('dps-airlines:server:joinFlightAttendant', function(source, flightId)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true,
        rateLimit = { action = 'joinFlight', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false, reason end

    local role = Validation.GetPlayerRole(source)
    if role ~= Constants.ROLE_FLIGHT_ATTENDANT then
        return false, 'Must be a Flight Attendant'
    end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    -- Check flight exists
    local flight = MySQL.single.await(
        'SELECT * FROM airline_flights WHERE id = ? AND status = ?',
        { flightId, Constants.DB_STATUS_ACTIVE }
    )
    if not flight then return false, 'Flight not available' end

    -- Check not already assigned
    local existing = MySQL.scalar.await(
        'SELECT COUNT(*) FROM airline_crew_assignments WHERE flight_id = ? AND citizenid = ?',
        { flightId, player.identifier }
    )
    if existing > 0 then return false, 'Already assigned to this flight' end

    -- Add crew assignment
    MySQL.insert.await(
        'INSERT INTO airline_crew_assignments (flight_id, citizenid, role) VALUES (?, ?, ?)',
        { flightId, player.identifier, Constants.ROLE_FLIGHT_ATTENDANT }
    )

    return true, flight
end)

-- Complete passenger service (safety briefing, in-flight service)
lib.callback.register('dps-airlines:server:attendantService', function(source, flightId, serviceType)
    local ok = Validation.Check(source, {
        employee = true, onDuty = true,
        rateLimit = { action = 'service', cooldown = Constants.THROTTLE_NORMAL },
    })
    if not ok then return false end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    -- Verify assignment
    local assignment = MySQL.single.await(
        'SELECT * FROM airline_crew_assignments WHERE flight_id = ? AND citizenid = ? AND role = ?',
        { flightId, player.identifier, Constants.ROLE_FLIGHT_ATTENDANT }
    )
    if not assignment then return false end

    -- Update attendant stats
    if serviceType == 'complete' then
        MySQL.update.await(
            'UPDATE airline_pilot_stats SET attendant_flights = attendant_flights + 1 WHERE citizenid = ?',
            { player.identifier }
        )

        -- Pay flat rate + potential tips
        local roleConfig = Config.Roles[Constants.ROLE_FLIGHT_ATTENDANT]
        local pay = roleConfig.flatRate or 150

        -- Random tip chance
        local flight = MySQL.single.await('SELECT passengers FROM airline_flights WHERE id = ?', { flightId })
        if flight and flight.passengers > 0 then
            local tipChance = roleConfig.tipPercent or 0.15
            if math.random() < tipChance then
                local tip = math.random(10, 50) * flight.passengers
                pay = pay + tip
            end
        end

        Payments.PayPlayer(source, pay, 'Flight attendant service')
        Cache.Invalidate('stats_' .. player.identifier)

        return true, pay
    end

    return true
end)
