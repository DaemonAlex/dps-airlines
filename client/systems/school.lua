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

---Start a practice flight (server tracks the time; hours are credited server-side)
function StartPracticeFlight()
    lib.callback('dps-airlines:server:startPracticeFlight', false, function(ok, err)
        if not ok then
            Bridge.Notify(err or 'Could not start practice flight', 'error')
            return
        end

        Bridge.Notify('Practice flight started! Fly around to log hours.', 'inform')

        -- Monitor practice flight; when the player leaves the plane, ask the server to
        -- credit hours. The server computes the amount from its own recorded start time,
        -- so no hours value is sent from here.
        CreateThread(function()
            while true do
                Wait(60000) -- check every minute
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)

                if vehicle == 0 or not IsThisModelAPlane(GetEntityModel(vehicle)) then
                    lib.callback('dps-airlines:server:logSchoolHours', false, function(logged)
                        if logged then
                            Bridge.Notify('Practice hours logged', 'success')
                        end
                    end)
                    return
                end
            end
        end)
    end)
end

---Start checkride. The candidate must actually fly a server-assigned route; the
---pass/fail result is decided server-side from that flight (no client pass flag).
function StartCheckride()
    local confirm = lib.alertDialog({
        header = 'Checkride',
        content = string.format('Take the checkride exam? Fee: $%d\n\nYou will be assigned a route to fly. Reach the destination airport to complete the checkride. Your flight is graded on the server.',
            Config.FlightSchool.checkrideFee),
        centered = true,
        cancel = true,
    })

    if confirm ~= 'confirm' then return end

    lib.callback('dps-airlines:server:startCheckride', false, function(route, err)
        if not route then
            Bridge.Notify(err or 'Could not start checkride', 'error')
            return
        end

        Bridge.Notify(string.format('Checkride started! Fly from %s to %s (%s).',
            route.departure, route.arrival, route.arrivalLabel), 'inform', 10000)

        if route.arrivalCoords then
            SetNewWaypoint(route.arrivalCoords.x, route.arrivalCoords.y)
        end

        local destAirport = Locations.GetAirport(route.arrival)

        -- Monitor arrival, then let the server grade the flight.
        CreateThread(function()
            while true do
                Wait(2000)
                local coords = GetEntityCoords(PlayerPedId())
                local dist = destAirport and #(coords - destAirport.coords) or 9999.0

                if dist < Constants.DIST_COMPLETION then
                    lib.callback('dps-airlines:server:attemptCheckride', false, function(handled, passed)
                        if handled then
                            if passed then
                                Bridge.Notify('Congratulations! You passed the checkride! Pilot license granted!', 'success', 10000)
                            else
                                Bridge.Notify('Checkride failed. Fly the assigned route properly and try again.', 'error', 7000)
                            end
                        end
                    end)
                    return
                end
            end
        end)
    end)
end
