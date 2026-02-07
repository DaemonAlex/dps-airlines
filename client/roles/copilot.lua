-- Client: First Officer (Co-Pilot) role

---Open co-pilot menu
---@param airportCode string
function OpenCopilotMenu(airportCode)
    local options = {
        {
            title = 'Join Flight as Co-Pilot',
            description = 'Join an active flight as First Officer',
            icon = 'user-plus',
            onSelect = function()
                JoinFlightAsCopilot()
            end,
        },
        {
            title = 'Pre-Flight Checklist',
            description = 'Complete pre-flight checks',
            icon = 'clipboard-check',
            onSelect = function()
                DoCopilotChecklist('preflight')
            end,
            disabled = State.CurrentFlight == nil,
        },
        {
            title = 'In-Flight Checklist',
            description = 'Complete in-flight checks',
            icon = 'tasks',
            onSelect = function()
                DoCopilotChecklist('inflight')
            end,
            disabled = State.CurrentFlight == nil,
        },
        {
            title = 'ATC Communications',
            description = 'Handle radio communications',
            icon = 'tower-broadcast',
            onSelect = function()
                HandleATCComms()
            end,
            disabled = State.CurrentFlight == nil,
        },
        {
            title = 'Navigation',
            description = 'Set and manage waypoints',
            icon = 'compass',
            onSelect = function()
                HandleNavigation()
            end,
        },
        {
            title = 'View Stats',
            description = 'View your co-pilot statistics',
            icon = 'chart-bar',
            onSelect = function()
                OpenNUI('overview')
            end,
        },
    }

    lib.registerContext({
        id = 'airline_copilot_menu',
        title = 'First Officer Menu',
        options = options,
    })
    lib.showContext('airline_copilot_menu')
end

---Join an active flight as co-pilot
function JoinFlightAsCopilot()
    -- Find nearby captains with active flights
    Bridge.Notify('Looking for active flights nearby...', 'inform')

    -- Get active flights from dispatcher view
    lib.callback('dps-airlines:server:getSchedules', false, function(schedules)
        if not schedules or #schedules == 0 then
            Bridge.Notify('No active flights found', 'error')
            return
        end

        local options = {}
        for _, schedule in ipairs(schedules) do
            if schedule.status == Constants.DISPATCH_ASSIGNED or schedule.status == Constants.DISPATCH_PENDING then
                options[#options + 1] = {
                    label = schedule.flight_number .. ' (' .. schedule.departure_airport .. ' → ' .. schedule.arrival_airport .. ')',
                    value = schedule.id,
                }
            end
        end

        if #options == 0 then
            Bridge.Notify('No joinable flights available', 'error')
            return
        end

        local input = lib.inputDialog('Join Flight', {
            { type = 'select', label = 'Select Flight', options = options, required = true },
        })

        if not input then return end

        lib.callback('dps-airlines:server:joinFlightCopilot', false, function(success, result)
            if success then
                Bridge.Notify('Joined flight as First Officer!', 'success')
                if type(result) == 'table' then
                    State.CurrentFlight = result
                end
            else
                Bridge.Notify(result or 'Failed to join flight', 'error')
            end
        end, input[1])
    end, Constants.DISPATCH_ASSIGNED)
end

---Perform co-pilot checklist
---@param checklistType string
function DoCopilotChecklist(checklistType)
    if not State.CurrentFlight then
        Bridge.Notify('No active flight', 'error')
        return
    end

    local checklists = {
        preflight = {
            'Exterior walk-around complete',
            'Flight controls free and correct',
            'Instruments and avionics checked',
            'Fuel quantity verified',
            'Weight and balance calculated',
            'Weather briefing reviewed',
        },
        inflight = {
            'Altitude and heading confirmed',
            'Fuel burn rate normal',
            'Engine instruments in green',
            'Navigation waypoints verified',
            'Communication frequencies set',
            'Emergency procedures reviewed',
        },
    }

    local items = checklists[checklistType] or checklists.preflight

    -- Simulate checklist with progress bar
    for i, item in ipairs(items) do
        local success = lib.progressBar({
            duration = 2000,
            label = 'Checking: ' .. item,
            useWhileDead = false,
            canCancel = true,
        })

        if not success then
            Bridge.Notify('Checklist interrupted', 'error')
            return
        end
    end

    -- Report completion to server
    lib.callback('dps-airlines:server:copilotChecklist', false, function(success)
        if success then
            Bridge.Notify(checklistType .. ' checklist complete!', 'success')
        end
    end, State.CurrentFlight.flightId, checklistType)
end

---Handle ATC communications (simulated)
function HandleATCComms()
    if not State.CurrentFlight then return end

    local options = {
        { label = 'Request Takeoff Clearance', value = 'takeoff' },
        { label = 'Report Position', value = 'position' },
        { label = 'Request Landing Clearance', value = 'landing' },
        { label = 'Declare Emergency', value = 'emergency' },
    }

    local input = lib.inputDialog('ATC Communications', {
        { type = 'select', label = 'Transmission', options = options, required = true },
    })

    if not input then return end

    local messages = {
        takeoff = 'Tower, DPS Airlines requesting takeoff clearance',
        position = 'Center, DPS Airlines reporting position',
        landing = 'Approach, DPS Airlines requesting landing clearance',
        emergency = 'Mayday, DPS Airlines declaring emergency',
    }

    Bridge.Notify(messages[input[1]] or 'Transmission sent', 'inform', 5000)

    if input[1] == 'emergency' then
        lib.callback('dps-airlines:server:copilotEmergency', false, function(success)
            if success then
                Bridge.Notify('Emergency declared and logged', 'error')
            end
        end, State.CurrentFlight.flightId, 'atc_emergency')
    end
end

---Handle navigation
function HandleNavigation()
    local nearestCode, nearestDist = Locations.GetNearestAirport(GetEntityCoords(PlayerPedId()))

    local destOptions = {}
    for code, ap in pairs(Locations.Airports) do
        destOptions[#destOptions + 1] = { label = ap.label, value = code }
    end

    local input = lib.inputDialog('Navigation', {
        { type = 'select', label = 'Set Waypoint To', options = destOptions, required = true },
    })

    if not input then return end

    local airport = Locations.GetAirport(input[1])
    if airport then
        SetNewWaypoint(airport.coords.x, airport.coords.y)
        Bridge.Notify('Waypoint set to ' .. airport.label, 'success')
    end
end
