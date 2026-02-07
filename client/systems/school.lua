-- Client: Flight school system

---Open flight school menu
function OpenSchoolMenu()
    lib.callback('dps-airlines:server:getSchoolProgress', false, function(progress)
        local enrolled = progress ~= nil
        local graduated = enrolled and progress.checkride_passed == 1

        local options = {}

        if not enrolled then
            options[#options + 1] = {
                title = 'Enroll in Flight School',
                description = string.format('Fee: $%d', Config.FlightSchool.enrollmentFee),
                icon = 'graduation-cap',
                onSelect = function()
                    lib.callback('dps-airlines:server:enrollFlightSchool', false, function(success, err)
                        if success then
                            Bridge.Notify('Enrolled in flight school!', 'success')
                        else
                            Bridge.Notify(err or 'Failed to enroll', 'error')
                        end
                    end)
                end,
            }
        elseif graduated then
            options[#options + 1] = {
                title = 'Flight School - GRADUATED',
                description = 'You have completed flight school!',
                icon = 'award',
                disabled = true,
            }
        else
            options[#options + 1] = {
                title = 'Take Lesson',
                description = string.format('Lessons: %d/%d | Fee: $%d',
                    progress.lessons_completed, Config.FlightSchool.requiredLessons,
                    Config.FlightSchool.lessonFee),
                icon = 'book-open',
                onSelect = function()
                    TakeLesson()
                end,
            }

            options[#options + 1] = {
                title = 'Practice Flight',
                description = string.format('Hours: %.1f/%d',
                    progress.flight_hours_logged, Config.FlightSchool.requiredFlightHours),
                icon = 'plane',
                onSelect = function()
                    StartPracticeFlight()
                end,
            }

            local canCheckride = progress.lessons_completed >= Config.FlightSchool.requiredLessons and
                                progress.flight_hours_logged >= Config.FlightSchool.requiredFlightHours

            options[#options + 1] = {
                title = 'Take Checkride',
                description = canCheckride and string.format('Fee: $%d | Attempts: %d',
                    Config.FlightSchool.checkrideFee, progress.checkride_attempts)
                    or 'Requirements not met',
                icon = 'clipboard-check',
                onSelect = function()
                    StartCheckride()
                end,
                disabled = not canCheckride,
            }
        end

        lib.registerContext({
            id = 'airline_school',
            title = 'Flight School',
            options = options,
        })
        lib.showContext('airline_school')
    end)
end

---Take a flight lesson
function TakeLesson()
    local lessons = {
        { label = 'Pre-flight Inspection', duration = 8000 },
        { label = 'Taxi Procedures', duration = 10000 },
        { label = 'Takeoff Technique', duration = 12000 },
        { label = 'Level Flight', duration = 8000 },
        { label = 'Landing Approach', duration = 15000 },
    }

    local lesson = lessons[math.random(#lessons)]

    local success = lib.progressBar({
        duration = lesson.duration,
        label = 'Lesson: ' .. lesson.label,
        useWhileDead = false,
        canCancel = true,
    })

    if success then
        lib.callback('dps-airlines:server:completeLesson', false, function(ok, count)
            if ok then
                Bridge.Notify(string.format('Lesson complete! (%d/%d)', count, Config.FlightSchool.requiredLessons), 'success')
            else
                Bridge.Notify(count or 'Failed', 'error')
            end
        end, lesson.label)
    end
end

---Start a practice flight (logs hours)
function StartPracticeFlight()
    Bridge.Notify('Practice flight started! Fly around to log hours.', 'inform')

    local startTime = GetGameTimer()

    -- Monitor practice flight
    CreateThread(function()
        while true do
            Wait(60000) -- Log every minute
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle == 0 or not IsThisModelAPlane(GetEntityModel(vehicle)) then
                local elapsed = (GetGameTimer() - startTime) / 3600000.0 -- hours
                if elapsed > 0.01 then
                    lib.callback('dps-airlines:server:logSchoolHours', false, function(ok)
                        if ok then
                            Bridge.Notify(string.format('Logged %.2f practice hours', elapsed), 'success')
                        end
                    end, elapsed)
                end
                return
            end
        end
    end)
end

---Start checkride
function StartCheckride()
    local confirm = lib.alertDialog({
        header = 'Checkride',
        content = string.format('Take the checkride exam? Fee: $%d\n\nYou will need to demonstrate:\n- Proper takeoff\n- Level cruise\n- Smooth landing',
            Config.FlightSchool.checkrideFee),
        centered = true,
        cancel = true,
    })

    if confirm ~= 'confirm' then return end

    -- Simulate checkride (simplified - could be expanded to actual flight test)
    local steps = {
        { label = 'Written Exam', duration = 10000 },
        { label = 'Oral Examination', duration = 8000 },
        { label = 'Pre-Flight Check', duration = 5000 },
    }

    for _, step in ipairs(steps) do
        local success = lib.progressBar({
            duration = step.duration,
            label = step.label,
            useWhileDead = false,
            canCancel = true,
        })
        if not success then
            Bridge.Notify('Checkride interrupted', 'error')
            return
        end
    end

    -- 80% pass rate
    local passed = math.random(100) <= 80

    lib.callback('dps-airlines:server:attemptCheckride', false, function(success)
        if success then
            if passed then
                Bridge.Notify('Congratulations! You passed the checkride! Pilot license granted!', 'success', 10000)
            else
                Bridge.Notify('Checkride failed. Study more and try again.', 'error', 5000)
            end
        end
    end, passed)
end
