-- Server: Crew management system

-- Invite a player to crew
lib.callback.register('dps-airlines:server:inviteCrew', function(source, targetSource, flightId)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true, canFly = true,
        rateLimit = { action = 'inviteCrew', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false, reason end

    -- Verify target is airline employee
    if not Validation.IsAirlineEmployee(targetSource) then
        return false, 'Target is not an airline employee'
    end

    if not Validation.IsOnDuty(targetSource) then
        return false, 'Target is not on duty'
    end

    -- Check crew size
    local crewCount = MySQL.scalar.await(
        'SELECT COUNT(*) FROM airline_crew_assignments WHERE flight_id = ?',
        { flightId }
    )
    if crewCount >= Config.Crew.maxSize then
        return false, 'Crew is full'
    end

    -- Send invite to target
    TriggerClientEvent('dps-airlines:client:crewInvite', targetSource, {
        flightId = flightId,
        captainSource = source,
        captainName = Bridge.GetPlayer(source).fullName,
    })

    return true
end)

-- Accept crew invite
lib.callback.register('dps-airlines:server:acceptCrewInvite', function(source, flightId)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true,
        rateLimit = { action = 'acceptCrew', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    local role = Validation.GetPlayerRole(source) or Constants.ROLE_GROUND_CREW

    -- Check not already in crew
    local existing = MySQL.scalar.await(
        'SELECT COUNT(*) FROM airline_crew_assignments WHERE flight_id = ? AND citizenid = ?',
        { flightId, player.identifier }
    )
    if existing > 0 then return false, 'Already in crew' end

    MySQL.insert.await(
        'INSERT INTO airline_crew_assignments (flight_id, citizenid, role) VALUES (?, ?, ?)',
        { flightId, player.identifier, role }
    )

    -- If copilot, update flight record
    if role == Constants.ROLE_FIRST_OFFICER then
        MySQL.update.await(
            'UPDATE airline_flights SET copilot_citizenid = ? WHERE id = ? AND copilot_citizenid IS NULL',
            { player.identifier, flightId }
        )
    end

    return true, role
end)

-- Get crew for a flight
lib.callback.register('dps-airlines:server:getFlightCrew', function(source, flightId)
    local ok = Validation.Check(source, { employee = true })
    if not ok then return {} end

    return MySQL.query.await([[
        SELECT ca.*, ps.service_rating, ps.flight_hours
        FROM airline_crew_assignments ca
        LEFT JOIN airline_pilot_stats ps ON ca.citizenid = ps.citizenid
        WHERE ca.flight_id = ?
    ]], { flightId })
end)

-- Remove crew member
lib.callback.register('dps-airlines:server:removeCrewMember', function(source, flightId, targetCitizenId)
    local ok, reason = Validation.Check(source, {
        employee = true, canFly = true,
        rateLimit = { action = 'removeCrew', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    -- Verify captain of this flight
    local flight = MySQL.single.await(
        'SELECT * FROM airline_flights WHERE id = ? AND pilot_citizenid = ?',
        { flightId, player.identifier }
    )
    if not flight then return false, 'Not the captain of this flight' end

    MySQL.query.await(
        'DELETE FROM airline_crew_assignments WHERE flight_id = ? AND citizenid = ?',
        { flightId, targetCitizenId }
    )

    -- If was copilot, clear from flight
    MySQL.update.await(
        'UPDATE airline_flights SET copilot_citizenid = NULL WHERE id = ? AND copilot_citizenid = ?',
        { flightId, targetCitizenId }
    )

    -- Notify removed player
    local targetPlayer = Bridge.GetPlayerByIdentifier(targetCitizenId)
    if targetPlayer then
        TriggerClientEvent('dps-airlines:client:notify', targetPlayer.source, 'You have been removed from the crew')
    end

    return true
end)
