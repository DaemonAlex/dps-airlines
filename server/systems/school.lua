-- Server: Flight school system

-- Server-tracked practice sessions and checkride flights. Flight hours and the
-- checkride outcome are derived from these, never from client-supplied numbers/booleans
-- (C2 fix).
local PracticeSessions = {}   -- [citizenid] = startTime (GetGameTimer)
local CheckrideSessions = {}  -- [citizenid] = { startTime, departure, arrival }

-- Enroll in flight school
lib.callback.register('dps-airlines:server:enrollFlightSchool', function(source)
    local ok, reason = Validation.Check(source, {
        employee = true,
        rateLimit = { action = 'enroll', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return false, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    -- Check not already enrolled
    local existing = MySQL.single.await(
        'SELECT * FROM airline_flight_school WHERE citizenid = ?',
        { player.identifier }
    )
    if existing then
        if existing.checkride_passed == 1 then
            return false, 'Already graduated'
        end
        return false, 'Already enrolled'
    end

    -- Charge enrollment fee
    if not Payments.ChargePlayer(source, Config.FlightSchool.enrollmentFee, 'Flight school enrollment') then
        return false, 'Insufficient funds'
    end

    MySQL.insert.await(
        'INSERT INTO airline_flight_school (citizenid) VALUES (?)',
        { player.identifier }
    )

    return true
end)

-- Complete a lesson
lib.callback.register('dps-airlines:server:completeLesson', function(source, lessonType)
    local ok, reason = Validation.Check(source, {
        employee = true,
        rateLimit = { action = 'lesson', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return false, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    local school = MySQL.single.await(
        'SELECT * FROM airline_flight_school WHERE citizenid = ? AND checkride_passed = 0',
        { player.identifier }
    )
    if not school then return false, 'Not enrolled or already graduated' end

    -- Charge lesson fee
    if not Payments.ChargePlayer(source, Config.FlightSchool.lessonFee, 'Flight lesson') then
        return false, 'Insufficient funds'
    end

    MySQL.update.await(
        'UPDATE airline_flight_school SET lessons_completed = lessons_completed + 1 WHERE citizenid = ?',
        { player.identifier }
    )

    return true, school.lessons_completed + 1
end)

-- Begin a server-tracked practice flight. The server records the start time; hours are
-- credited from that clock on logSchoolHours, so the client can no longer just declare
-- an arbitrary number.
lib.callback.register('dps-airlines:server:startPracticeFlight', function(source)
    local ok, reason = Validation.Check(source, {
        employee = true,
        rateLimit = { action = 'startPractice', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    local school = MySQL.single.await(
        'SELECT id FROM airline_flight_school WHERE citizenid = ? AND checkride_passed = 0',
        { player.identifier }
    )
    if not school then return false, 'Not enrolled or already graduated' end

    PracticeSessions[player.identifier] = GetGameTimer()
    return true
end)

-- Log flight hours for school. Hours are computed from the SERVER-tracked practice
-- session start (any client argument is ignored), capped per-call and in total (C2 fix).
lib.callback.register('dps-airlines:server:logSchoolHours', function(source)
    local ok = Validation.Check(source, {
        employee = true,
        rateLimit = { action = 'logHours', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    local startTime = PracticeSessions[player.identifier]
    if not startTime then return false, 'No active practice flight' end
    PracticeSessions[player.identifier] = nil  -- one credit per session

    -- Elapsed real time on the server clock, converted to hours and capped per call.
    local elapsedHours = (GetGameTimer() - startTime) / 3600000.0
    elapsedHours = math.max(0, math.min(elapsedHours, Constants.SCHOOL_MAX_HOURS_PER_LOG))
    if elapsedHours <= 0 then return false end

    -- Credit hours but never exceed the hard total cap.
    MySQL.update.await([[
        UPDATE airline_flight_school
        SET flight_hours_logged = LEAST(flight_hours_logged + ?, ?)
        WHERE citizenid = ? AND checkride_passed = 0
    ]], { elapsedHours, Constants.SCHOOL_MAX_HOURS_TOTAL, player.identifier })

    return true
end)

-- Begin a checkride: verify prerequisites, charge the fee, and assign a server-chosen
-- route (departure = airport nearest the candidate, arrival = a different airport). The
-- start time and route are recorded server-side so the outcome can be verified from a
-- real flown flight rather than a client boolean.
lib.callback.register('dps-airlines:server:startCheckride', function(source)
    local ok, reason = Validation.Check(source, {
        employee = true,
        rateLimit = { action = 'startCheckride', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return nil, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    local school = MySQL.single.await(
        'SELECT * FROM airline_flight_school WHERE citizenid = ? AND checkride_passed = 0',
        { player.identifier }
    )
    if not school then return nil, 'Not enrolled or already graduated' end

    if school.lessons_completed < Config.FlightSchool.requiredLessons then
        return nil, 'Need ' .. Config.FlightSchool.requiredLessons .. ' lessons (have ' .. school.lessons_completed .. ')'
    end
    if school.flight_hours_logged < Config.FlightSchool.requiredFlightHours then
        return nil, 'Need ' .. Config.FlightSchool.requiredFlightHours .. 'h flight time (have ' .. string.format('%.1f', school.flight_hours_logged) .. ')'
    end

    -- Choose the route server-side from the candidate's current position.
    local ped = GetPlayerPed(source)
    local coords = (ped and ped > 0) and GetEntityCoords(ped) or nil
    local departure = coords and Locations.GetNearestAirport(coords) or nil
    if not departure then return nil, 'Start the checkride at an airport' end

    -- Pick any other airport as the destination.
    local arrival
    for code in pairs(Locations.Airports) do
        if code ~= departure then arrival = code break end
    end
    if not arrival then return nil, 'No valid checkride route' end

    -- Charge the checkride fee up front (an attempt costs money, pass or fail).
    if not Payments.ChargePlayer(source, Config.FlightSchool.checkrideFee, 'Checkride attempt') then
        return nil, 'Insufficient funds'
    end

    CheckrideSessions[player.identifier] = {
        startTime = GetGameTimer(),
        departure = departure,
        arrival = arrival,
    }

    local arrivalAirport = Locations.GetAirport(arrival)
    return {
        departure = departure,
        arrival = arrival,
        arrivalLabel = arrivalAirport and arrivalAirport.label or arrival,
        arrivalCoords = arrivalAirport and arrivalAirport.coords or nil,
    }
end)

-- Attempt (finish) the checkride. The pass/fail outcome is computed SERVER-SIDE from the
-- flight the candidate actually flew - reusing ValidateFlightCompletion (minimum flight
-- time for the route + player must be at the destination). The old client `passed`
-- boolean is gone (C2 fix).
lib.callback.register('dps-airlines:server:attemptCheckride', function(source)
    local ok, reason = Validation.Check(source, {
        employee = true,
        rateLimit = { action = 'checkride', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return false, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    local session = CheckrideSessions[player.identifier]
    if not session then return false, 'Start a checkride first' end

    local school = MySQL.single.await(
        'SELECT * FROM airline_flight_school WHERE citizenid = ? AND checkride_passed = 0',
        { player.identifier }
    )
    if not school then
        CheckrideSessions[player.identifier] = nil
        return false, 'Not enrolled or already graduated'
    end

    -- Server-computed flight duration from the recorded start time.
    local duration = (GetGameTimer() - session.startTime) / 1000.0

    -- The outcome IS the result of the anti-cheat flight validation.
    local passed = Validation.ValidateFlightCompletion(source, {
        departure = session.departure,
        arrival = session.arrival,
        duration = duration,
    })

    CheckrideSessions[player.identifier] = nil

    if passed then
        MySQL.update.await(
            'UPDATE airline_flight_school SET checkride_passed = 1, checkride_attempts = checkride_attempts + 1, graduated_at = NOW() WHERE citizenid = ?',
            { player.identifier }
        )

        -- Grant pilot license
        local stats = MySQL.single.await('SELECT licenses FROM airline_pilot_stats WHERE citizenid = ?', { player.identifier })
        local licenses = stats and stats.licenses and json.decode(stats.licenses) or {}
        licenses['ppl'] = { granted = os.time(), type = 'Private Pilot License' }
        MySQL.update.await(
            'UPDATE airline_pilot_stats SET licenses = ? WHERE citizenid = ?',
            { json.encode(licenses), player.identifier }
        )
    else
        MySQL.update.await(
            'UPDATE airline_flight_school SET checkride_attempts = checkride_attempts + 1 WHERE citizenid = ?',
            { player.identifier }
        )
    end

    return true, passed
end)

-- Drop tracked school sessions when a player disconnects.
AddEventHandler('playerDropped', function()
    local src = source
    local player = Bridge.GetPlayer(src)
    if player then
        PracticeSessions[player.identifier] = nil
        CheckrideSessions[player.identifier] = nil
    end
end)

-- Get school progress
lib.callback.register('dps-airlines:server:getSchoolProgress', function(source)
    local ok = Validation.Check(source, { employee = true })
    if not ok then return nil end

    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    return MySQL.single.await(
        'SELECT * FROM airline_flight_school WHERE citizenid = ?',
        { player.identifier }
    )
end)
