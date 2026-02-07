-- Server: First Officer (Co-Pilot) role logic

-- Join a flight as co-pilot
lib.callback.register('dps-airlines:server:joinFlightCopilot', function(source, flightId)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true,
        rateLimit = { action = 'joinFlight', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false, reason end

    local role = Validation.GetPlayerRole(source)
    if role ~= Constants.ROLE_FIRST_OFFICER and role ~= Constants.ROLE_CHIEF_PILOT then
        return false, 'Must be First Officer or Chief Pilot'
    end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    -- Check flight exists and has no copilot
    local flight = MySQL.single.await(
        'SELECT * FROM airline_flights WHERE id = ? AND status = ? AND copilot_citizenid IS NULL',
        { flightId, Constants.DB_STATUS_ACTIVE }
    )
    if not flight then return false, 'Flight not available or already has copilot' end

    -- Can't copilot your own flight
    if flight.pilot_citizenid == player.identifier then
        return false, 'Cannot copilot your own flight'
    end

    -- Update flight with copilot
    MySQL.update.await(
        'UPDATE airline_flights SET copilot_citizenid = ? WHERE id = ?',
        { player.identifier, flightId }
    )

    -- Add crew assignment
    MySQL.insert.await(
        'INSERT INTO airline_crew_assignments (flight_id, citizenid, role) VALUES (?, ?, ?)',
        { flightId, player.identifier, Constants.ROLE_FIRST_OFFICER }
    )

    return true, flight
end)

-- Co-pilot checklist completion
lib.callback.register('dps-airlines:server:copilotChecklist', function(source, flightId, checklistType)
    local ok = Validation.Check(source, { employee = true, onDuty = true })
    if not ok then return false end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    -- Verify copilot assignment
    local assignment = MySQL.single.await(
        'SELECT * FROM airline_crew_assignments WHERE flight_id = ? AND citizenid = ? AND role = ?',
        { flightId, player.identifier, Constants.ROLE_FIRST_OFFICER }
    )
    if not assignment then return false end

    -- Log checklist completion (for stat tracking)
    return true, checklistType
end)

-- Co-pilot emergency assistance
lib.callback.register('dps-airlines:server:copilotEmergency', function(source, flightId, emergencyType)
    local ok = Validation.Check(source, { employee = true, onDuty = true })
    if not ok then return false end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    local assignment = MySQL.single.await(
        'SELECT * FROM airline_crew_assignments WHERE flight_id = ? AND citizenid = ?',
        { flightId, player.identifier }
    )
    if not assignment then return false end

    -- Log the emergency assistance
    MySQL.insert.await(
        'INSERT INTO airline_incidents (flight_id, citizenid, incident_type, severity, description) VALUES (?, ?, ?, ?, ?)',
        { flightId, player.identifier, 'emergency_' .. emergencyType, 'minor', 'Co-pilot assisted with ' .. emergencyType }
    )

    return true
end)
