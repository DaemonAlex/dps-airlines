-- Client: Flight Attendant role

---Open attendant menu
---@param airportCode string
function OpenAttendantMenu(airportCode)
    local options = {
        {
            title = 'Join Flight',
            description = 'Join an active flight as Flight Attendant',
            icon = 'user-plus',
            onSelect = function()
                JoinFlightAsAttendant()
            end,
        },
        {
            title = 'Safety Briefing',
            description = 'Perform passenger safety briefing',
            icon = 'shield-alt',
            onSelect = function()
                PerformSafetyBriefing()
            end,
            disabled = State.CurrentFlight == nil,
        },
        {
            title = 'Passenger Boarding',
            description = 'Manage passenger boarding process',
            icon = 'door-open',
            onSelect = function()
                ManageBoarding()
            end,
            disabled = State.CurrentFlight == nil,
        },
        {
            title = 'In-Flight Service',
            description = 'Serve passengers during flight',
            icon = 'utensils',
            onSelect = function()
                InFlightService()
            end,
            disabled = State.CurrentFlight == nil or State.FlightPhase ~= Constants.PHASE_CRUISE,
        },
        {
            title = 'View Stats',
            description = 'View your attendant statistics',
            icon = 'chart-bar',
            onSelect = function()
                OpenNUI('overview')
            end,
        },
    }

    lib.registerContext({
        id = 'airline_attendant_menu',
        title = 'Flight Attendant Menu',
        options = options,
    })
    lib.showContext('airline_attendant_menu')
end

---Join an active flight as attendant
function JoinFlightAsAttendant()
    Bridge.Notify('Looking for active flights...', 'inform')

    lib.callback('dps-airlines:server:getSchedules', false, function(schedules)
        if not schedules or #schedules == 0 then
            Bridge.Notify('No flights available', 'error')
            return
        end

        local options = {}
        for _, s in ipairs(schedules) do
            options[#options + 1] = {
                label = s.flight_number .. ' (' .. s.departure_airport .. ' → ' .. s.arrival_airport .. ')',
                value = s.id,
            }
        end

        if #options == 0 then
            Bridge.Notify('No joinable flights', 'error')
            return
        end

        local input = lib.inputDialog('Join Flight', {
            { type = 'select', label = 'Select Flight', options = options, required = true },
        })
        if not input then return end

        lib.callback('dps-airlines:server:joinFlightAttendant', false, function(success, result)
            if success then
                Bridge.Notify('Joined flight as Flight Attendant!', 'success')
                if type(result) == 'table' then
                    State.CurrentFlight = result
                end
            else
                Bridge.Notify(result or 'Failed to join', 'error')
            end
        end, input[1])
    end)
end

---Perform safety briefing
function PerformSafetyBriefing()
    if not State.CurrentFlight then return end

    local briefingSteps = {
        'Welcome passengers aboard',
        'Demonstrate seatbelt usage',
        'Point out emergency exits',
        'Explain oxygen mask procedure',
        'Demonstrate life vest usage',
        'Secure cabin for departure',
    }

    for i, step in ipairs(briefingSteps) do
        local success = lib.progressBar({
            duration = 3000,
            label = step,
            useWhileDead = false,
            canCancel = true,
            anim = {
                dict = 'anim@mp_point',
                clip = 'task_mp_point_stand',
            },
        })

        if not success then
            Bridge.Notify('Briefing interrupted', 'error')
            return
        end
    end

    Bridge.Notify('Safety briefing complete!', 'success')

    lib.callback('dps-airlines:server:attendantService', false, function(success)
        -- Logged on server
    end, State.CurrentFlight.flightId, 'safety_briefing')
end

---Manage passenger boarding
function ManageBoarding()
    if not State.CurrentFlight then return end

    local success = lib.progressBar({
        duration = 10000,
        label = 'Managing passenger boarding...',
        useWhileDead = false,
        canCancel = true,
        anim = {
            dict = 'anim@mp_point',
            clip = 'task_mp_point_stand',
        },
    })

    if success then
        Bridge.Notify('All passengers boarded successfully!', 'success')
    end
end

---In-flight service
function InFlightService()
    if not State.CurrentFlight then return end

    local serviceSteps = {
        'Preparing beverage cart',
        'Serving drinks to passengers',
        'Distributing snacks',
        'Checking on passenger comfort',
        'Collecting trash',
    }

    for i, step in ipairs(serviceSteps) do
        local success = lib.progressBar({
            duration = 4000,
            label = step,
            useWhileDead = false,
            canCancel = true,
        })

        if not success then
            Bridge.Notify('Service interrupted', 'error')
            return
        end
    end

    -- Complete service on server
    lib.callback('dps-airlines:server:attendantService', false, function(success, pay)
        if success then
            Bridge.Notify(string.format('In-flight service complete! Earned: $%s', pay or 0), 'success')
        end
    end, State.CurrentFlight.flightId, 'complete')
end
