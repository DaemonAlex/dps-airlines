-- Server: Flight school system

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

-- Log flight hours for school
lib.callback.register('dps-airlines:server:logSchoolHours', function(source, hours)
    local ok = Validation.Check(source, { employee = true })
    if not ok then return false end

    if not Validation.ValidateNumber(hours, 0.01, 5) then return false end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    MySQL.update.await(
        'UPDATE airline_flight_school SET flight_hours_logged = flight_hours_logged + ? WHERE citizenid = ? AND checkride_passed = 0',
        { hours, player.identifier }
    )

    return true
end)

-- Attempt checkride
lib.callback.register('dps-airlines:server:attemptCheckride', function(source, passed)
    local ok, reason = Validation.Check(source, {
        employee = true,
        rateLimit = { action = 'checkride', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return false, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    local school = MySQL.single.await(
        'SELECT * FROM airline_flight_school WHERE citizenid = ? AND checkride_passed = 0',
        { player.identifier }
    )
    if not school then return false, 'Not enrolled or already graduated' end

    -- Check prerequisites
    if school.lessons_completed < Config.FlightSchool.requiredLessons then
        return false, 'Need ' .. Config.FlightSchool.requiredLessons .. ' lessons (have ' .. school.lessons_completed .. ')'
    end
    if school.flight_hours_logged < Config.FlightSchool.requiredFlightHours then
        return false, 'Need ' .. Config.FlightSchool.requiredFlightHours .. 'h flight time (have ' .. string.format('%.1f', school.flight_hours_logged) .. ')'
    end

    -- Charge checkride fee
    if not Payments.ChargePlayer(source, Config.FlightSchool.checkrideFee, 'Checkride attempt') then
        return false, 'Insufficient funds'
    end

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
