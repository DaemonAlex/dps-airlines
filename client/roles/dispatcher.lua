-- Client: Dispatcher role

---Open dispatcher menu
---@param airportCode string
function OpenDispatcherMenu(airportCode)
    local options = {
        {
            title = 'Create Flight Schedule',
            description = 'Schedule a new flight',
            icon = 'calendar-plus',
            onSelect = function()
                CreateFlightSchedule(airportCode)
            end,
        },
        {
            title = 'View Schedules',
            description = 'View all pending flight schedules',
            icon = 'calendar-alt',
            onSelect = function()
                ViewSchedules()
            end,
        },
        {
            title = 'Assign Pilots',
            description = 'Assign available pilots to flights',
            icon = 'user-check',
            onSelect = function()
                AssignPilotMenu()
            end,
        },
        {
            title = 'Flight Tracker',
            description = 'View live aircraft positions',
            icon = 'map-marked-alt',
            onSelect = function()
                OpenNUI('tracker')
            end,
        },
        {
            title = 'Weather Monitor',
            description = 'Check current weather conditions',
            icon = 'cloud-sun',
            onSelect = function()
                CheckWeather()
            end,
        },
        {
            title = 'View Stats',
            description = 'View dispatcher statistics',
            icon = 'chart-bar',
            onSelect = function()
                OpenNUI('overview')
            end,
        },
    }

    lib.registerContext({
        id = 'airline_dispatcher_menu',
        title = 'Dispatcher Menu',
        options = options,
    })
    lib.showContext('airline_dispatcher_menu')
end

---Create a flight schedule
---@param airportCode string
function CreateFlightSchedule(airportCode)
    local aircraftOptions = {}
    for _, ac in ipairs(Config.Aircraft) do
        aircraftOptions[#aircraftOptions + 1] = { label = ac.label .. ' (Cap: ' .. ac.passengers .. ' pax)', value = ac.model }
    end

    local destOptions = {}
    for code, ap in pairs(Locations.Airports) do
        if code ~= airportCode then
            destOptions[#destOptions + 1] = { label = ap.label .. ' (' .. code .. ')', value = code }
        end
    end

    local input = lib.inputDialog('Create Flight Schedule', {
        { type = 'select', label = 'Destination', options = destOptions, required = true },
        { type = 'select', label = 'Aircraft', options = aircraftOptions, required = true },
        { type = 'number', label = 'Expected Passengers', min = 0, max = 200, default = 0 },
        { type = 'number', label = 'Cargo Weight (kg)', min = 0, max = 10000, default = 0 },
        { type = 'select', label = 'Priority', options = {
            { label = 'Normal', value = 'normal' },
            { label = 'Priority', value = 'priority' },
            { label = 'Emergency', value = 'emergency' },
        }, default = 'normal' },
        { type = 'input', label = 'Notes (optional)' },
    })

    if not input then return end

    lib.callback('dps-airlines:server:createSchedule', false, function(result, err)
        if result then
            Bridge.Notify(string.format('Schedule created: %s', result.flightNumber), 'success')
        else
            Bridge.Notify(err or 'Failed to create schedule', 'error')
        end
    end, {
        departure = airportCode,
        arrival = input[1],
        model = input[2],
        passengers = input[3] or 0,
        cargoWeight = input[4] or 0,
        priority = input[5] or 'normal',
        notes = input[6] or '',
    })
end

---View all schedules
function ViewSchedules()
    lib.callback('dps-airlines:server:getSchedules', false, function(schedules)
        if not schedules or #schedules == 0 then
            Bridge.Notify('No pending schedules', 'inform')
            return
        end

        local options = {}
        for _, s in ipairs(schedules) do
            local pilotLabel = s.assigned_pilot and ('Pilot: ' .. s.assigned_pilot) or 'No pilot assigned'
            local statusIcon = s.status == Constants.DISPATCH_PENDING and 'clock' or
                              s.status == Constants.DISPATCH_ASSIGNED and 'check' or 'plane'

            options[#options + 1] = {
                title = s.flight_number,
                description = string.format('%s → %s | %s | %s',
                    s.departure_airport, s.arrival_airport, pilotLabel, s.status),
                icon = statusIcon,
                onSelect = function()
                    ScheduleDetails(s)
                end,
            }
        end

        lib.registerContext({
            id = 'airline_schedules',
            title = 'Flight Schedules',
            menu = 'airline_dispatcher_menu',
            options = options,
        })
        lib.showContext('airline_schedules')
    end)
end

---Show schedule details with actions
---@param schedule table
function ScheduleDetails(schedule)
    local options = {
        {
            title = 'Assign Pilot',
            icon = 'user-check',
            onSelect = function()
                AssignPilotToSchedule(schedule.id)
            end,
            disabled = schedule.status ~= Constants.DISPATCH_PENDING,
        },
        {
            title = 'Cancel Schedule',
            icon = 'times',
            onSelect = function()
                lib.callback('dps-airlines:server:cancelSchedule', false, function(success)
                    if success then
                        Bridge.Notify('Schedule cancelled', 'success')
                    end
                end, schedule.id)
            end,
        },
    }

    lib.registerContext({
        id = 'airline_schedule_detail',
        title = schedule.flight_number .. ' Details',
        menu = 'airline_schedules',
        options = options,
    })
    lib.showContext('airline_schedule_detail')
end

---Assign pilot menu
function AssignPilotMenu()
    -- First get pending schedules
    lib.callback('dps-airlines:server:getSchedules', false, function(schedules)
        if not schedules or #schedules == 0 then
            Bridge.Notify('No unassigned schedules', 'inform')
            return
        end

        local pendingSchedules = {}
        for _, s in ipairs(schedules) do
            if s.status == Constants.DISPATCH_PENDING and not s.assigned_pilot then
                pendingSchedules[#pendingSchedules + 1] = s
            end
        end

        if #pendingSchedules == 0 then
            Bridge.Notify('All schedules have pilots assigned', 'inform')
            return
        end

        local scheduleOptions = {}
        for _, s in ipairs(pendingSchedules) do
            scheduleOptions[#scheduleOptions + 1] = {
                label = s.flight_number .. ' (' .. s.departure_airport .. '→' .. s.arrival_airport .. ')',
                value = s.id,
            }
        end

        local input = lib.inputDialog('Select Schedule', {
            { type = 'select', label = 'Flight', options = scheduleOptions, required = true },
        })

        if not input then return end
        AssignPilotToSchedule(input[1])
    end)
end

---Assign a pilot to a specific schedule
---@param scheduleId number
function AssignPilotToSchedule(scheduleId)
    lib.callback('dps-airlines:server:getAvailablePilots', false, function(pilots)
        if not pilots or #pilots == 0 then
            Bridge.Notify('No available pilots', 'error')
            return
        end

        local pilotOptions = {}
        for _, p in ipairs(pilots) do
            pilotOptions[#pilotOptions + 1] = {
                label = string.format('%s (%.1fh, Rating: %.1f)', p.citizenid, p.flight_hours, p.service_rating),
                value = p.citizenid,
            }
        end

        local input = lib.inputDialog('Assign Pilot', {
            { type = 'select', label = 'Pilot', options = pilotOptions, required = true },
        })

        if not input then return end

        lib.callback('dps-airlines:server:assignPilot', false, function(success, err)
            if success then
                Bridge.Notify('Pilot assigned successfully!', 'success')
            else
                Bridge.Notify(err or 'Failed to assign pilot', 'error')
            end
        end, scheduleId, input[1])
    end)
end

---Check weather conditions
function CheckWeather()
    local weather = GetPrevWeatherTypeHashName()
    local hour = GetClockHours()
    local isNight = hour < 6 or hour > 20

    local severity = Constants.WEATHER_CLEAR
    local weatherName = 'Clear'

    -- Map GTA weather to severity
    local weatherHash = GetPrevWeatherTypeHashName()
    if weatherHash == joaat('RAIN') or weatherHash == joaat('THUNDER') then
        severity = Constants.WEATHER_SEVERE
        weatherName = 'Severe (Rain/Thunder)'
    elseif weatherHash == joaat('FOGGY') or weatherHash == joaat('SMOG') then
        severity = Constants.WEATHER_MODERATE
        weatherName = 'Moderate (Fog/Smog)'
    elseif weatherHash == joaat('CLOUDS') or weatherHash == joaat('OVERCAST') then
        severity = Constants.WEATHER_LIGHT
        weatherName = 'Light (Clouds)'
    end

    local payMult = Constants.WeatherMultipliers[severity] or 1.0

    lib.alertDialog({
        header = 'Weather Report',
        content = string.format(
            '**Conditions:** %s\n**Time:** %02d:00 (%s)\n**Pay Multiplier:** x%.2f\n**Flight Advisory:** %s',
            weatherName, hour, isNight and 'Night' or 'Day', payMult,
            severity >= Constants.WEATHER_SEVERE and 'Caution advised' or 'Normal operations'
        ),
        centered = true,
    })
end
