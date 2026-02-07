-- Client: Captain & Chief Pilot role

---Open the pilot-specific menu at an airport
---@param airportCode string
function OpenPilotMenu(airportCode)
    if not State.CanFly() then return end

    local airport = Locations.GetAirport(airportCode)
    if not airport then return end

    local options = {
        {
            title = 'Start Flight',
            description = 'Select aircraft and destination',
            icon = 'plane-departure',
            onSelect = function()
                OpenFlightSetup(airportCode)
            end,
        },
        {
            title = 'Charter Flight',
            description = 'Start a charter flight',
            icon = 'ticket-alt',
            onSelect = function()
                OpenCharterMenu(airportCode)
            end,
        },
        {
            title = 'View Flight Log',
            description = 'View your flight history',
            icon = 'book',
            onSelect = function()
                OpenNUI('flightlog')
            end,
        },
        {
            title = 'Crew Management',
            description = 'Invite crew for your flight',
            icon = 'users',
            onSelect = function()
                OpenCrewMenu()
            end,
        },
        {
            title = 'Type Ratings',
            description = 'View aircraft certifications',
            icon = 'certificate',
            onSelect = function()
                OpenNUI('typeratings')
            end,
        },
        {
            title = 'View Stats',
            description = 'View your pilot statistics',
            icon = 'chart-bar',
            onSelect = function()
                OpenNUI('overview')
            end,
        },
    }

    -- Helicopter ops
    if Config.Helicopters.enabled then
        options[#options + 1] = {
            title = 'Helicopter Operations',
            description = 'Medevac, tours, VIP transport',
            icon = 'helicopter',
            onSelect = function()
                OpenHeliMenu(airportCode)
            end,
        }
    end

    -- Boss menu for chief pilot
    if State.Role == Constants.ROLE_CHIEF_PILOT then
        options[#options + 1] = {
            title = 'Management Menu',
            description = 'Manage employees, finances, and operations',
            icon = 'building',
            onSelect = function()
                OpenBossMenu()
            end,
        }
    end

    lib.registerContext({
        id = 'airline_pilot_menu',
        title = 'Airline - ' .. (Config.Roles[State.Role] or {}).label or 'Pilot',
        options = options,
    })
    lib.showContext('airline_pilot_menu')
end

---Open flight setup menu
---@param airportCode string
function OpenFlightSetup(airportCode)
    local airport = Locations.GetAirport(airportCode)
    if not airport then return end

    -- Build aircraft options
    local aircraftOptions = {}
    for _, ac in ipairs(Config.Aircraft) do
        aircraftOptions[#aircraftOptions + 1] = { label = ac.label .. ' (' .. ac.class .. ')', value = ac.model }
    end

    -- Build destination options
    local destOptions = {}
    for code, ap in pairs(Locations.Airports) do
        if code ~= airportCode then
            local route = Locations.GetRoute(airportCode, code)
            local distLabel = route and string.format(' (%.1f km)', route.distance / 1000) or ''
            destOptions[#destOptions + 1] = { label = ap.label .. distLabel, value = code }
        end
    end

    local input = lib.inputDialog('Flight Setup', {
        { type = 'select', label = 'Aircraft', options = aircraftOptions, required = true },
        { type = 'select', label = 'Destination', options = destOptions, required = true },
        { type = 'number', label = 'Passengers', min = 0, max = 200, default = 0 },
        { type = 'number', label = 'Cargo Weight (kg)', min = 0, max = 10000, default = 0 },
        { type = 'select', label = 'Flight Type', options = {
            { label = 'Scheduled', value = 'scheduled' },
            { label = 'Priority', value = 'priority' },
            { label = 'Emergency', value = 'emergency' },
            { label = 'Ferry', value = 'ferry' },
        }, default = 'scheduled' },
    })

    if not input then return end

    local model = input[1]
    local destination = input[2]
    local passengers = input[3] or 0
    local cargoWeight = input[4] or 0
    local flightType = input[5] or 'scheduled'

    -- Start flight on server
    lib.callback('dps-airlines:server:startFlight', false, function(result, err)
        if not result then
            Bridge.Notify(err or 'Failed to start flight', 'error')
            return
        end

        State.CurrentFlight = result
        State.FlightPhase = Constants.PHASE_GROUND
        State.FlightStartTime = GetGameTimer()

        Bridge.Notify('Flight ' .. result.flightNumber .. ' created! Spawning aircraft...', 'success')

        -- Spawn aircraft
        SpawnFlightAircraft(model, airportCode, result)
    end, {
        departure = airportCode,
        arrival = destination,
        model = model,
        passengers = passengers,
        cargoWeight = cargoWeight,
        flightType = flightType,
    })
end

---Spawn the flight aircraft
---@param model string
---@param airportCode string
---@param flightData table
function SpawnFlightAircraft(model, airportCode, flightData)
    lib.callback('dps-airlines:server:spawnAircraft', false, function(spawnData, err)
        if not spawnData then
            Bridge.Notify(err or 'Failed to spawn aircraft', 'error')
            return
        end

        local hash = joaat(spawnData.model)
        lib.requestModel(hash)

        local coords = spawnData.coords
        local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, spawnData.heading, true, false)

        SetVehicleOnGroundProperly(vehicle)
        SetVehicleEngineOn(vehicle, false, true, false)
        SetModelAsNoLongerNeeded(hash)

        State.CurrentPlane = vehicle
        State.FuelLevel = Constants.FUEL_MAX

        -- Set a route blip to destination
        local destAirport = Locations.GetAirport(flightData.arrival)
        if destAirport then
            SetNewWaypoint(destAirport.coords.x, destAirport.coords.y)
        end

        -- Start flight monitoring thread
        StartFlightMonitor()

        Bridge.Notify('Aircraft spawned! Board and begin your flight.', 'success')
    end, model, 1, airportCode)
end

---Open charter menu
---@param airportCode string
function OpenCharterMenu(airportCode)
    local destOptions = {}
    for code, ap in pairs(Locations.Airports) do
        if code ~= airportCode then
            destOptions[#destOptions + 1] = { label = ap.label, value = code }
        end
    end

    local aircraftOptions = {}
    for _, ac in ipairs(Config.Aircraft) do
        if ac.passengers > 0 then
            aircraftOptions[#aircraftOptions + 1] = { label = ac.label, value = ac.model }
        end
    end

    local input = lib.inputDialog('Charter Flight', {
        { type = 'select', label = 'Destination', options = destOptions, required = true },
        { type = 'select', label = 'Aircraft', options = aircraftOptions, required = true },
        { type = 'number', label = 'Passengers', min = 1, max = 200, default = 1 },
        { type = 'checkbox', label = 'VIP Service' },
        { type = 'number', label = 'Luggage Pieces', min = 0, max = 50, default = 0 },
    })

    if not input then return end

    lib.callback('dps-airlines:server:bookCharter', false, function(result, err)
        if not result then
            Bridge.Notify(err or 'Failed to book charter', 'error')
            return
        end

        State.CurrentFlight = result
        Bridge.Notify(string.format('Charter %s booked! Price: $%s', result.flightNumber, result.price), 'success')
        SpawnFlightAircraft(input[2], airportCode, result)
    end, {
        from = airportCode,
        to = input[1],
        model = input[2],
        passengers = input[3] or 1,
        vip = input[4] or false,
        luggage = input[5] or 0,
    })
end

---Open boss/management menu
function OpenBossMenu()
    lib.registerContext({
        id = 'airline_boss_menu',
        title = 'Airline Management',
        options = {
            {
                title = 'Employee Roster',
                description = 'View and manage employees',
                icon = 'users-cog',
                onSelect = function() OpenNUI('crew') end,
            },
            {
                title = 'Company Finances',
                description = 'View society balance and transactions',
                icon = 'dollar-sign',
                onSelect = function()
                    lib.callback('dps-airlines:server:getSocietyBalance', false, function(balance)
                        Bridge.Notify('Company Balance: $' .. (balance or 0), 'inform')
                    end)
                end,
            },
            {
                title = 'Company Statistics',
                description = 'View overall company performance',
                icon = 'chart-line',
                onSelect = function() OpenNUI('overview') end,
            },
            {
                title = 'Hire Employee',
                description = 'Hire a nearby player',
                icon = 'user-plus',
                onSelect = function() HireNearbyPlayer() end,
            },
        },
    })
    lib.showContext('airline_boss_menu')
end

---Hire a nearby player
function HireNearbyPlayer()
    local players = lib.getNearbyPlayers(GetEntityCoords(PlayerPedId()), 5.0, true)
    if not players or #players == 0 then
        Bridge.Notify('No nearby players found', 'error')
        return
    end

    local options = {}
    for _, p in ipairs(players) do
        options[#options + 1] = {
            label = 'Player ' .. GetPlayerServerId(p.id),
            value = GetPlayerServerId(p.id),
        }
    end

    local input = lib.inputDialog('Hire Employee', {
        { type = 'select', label = 'Player', options = options, required = true },
        { type = 'select', label = 'Role', options = {
            { label = 'Ground Crew', value = Constants.ROLE_GROUND_CREW },
            { label = 'Flight Attendant', value = Constants.ROLE_FLIGHT_ATTENDANT },
            { label = 'Dispatcher', value = Constants.ROLE_DISPATCHER },
            { label = 'First Officer', value = Constants.ROLE_FIRST_OFFICER },
            { label = 'Captain', value = Constants.ROLE_CAPTAIN },
        }, required = true },
    })

    if not input then return end

    TriggerServerEvent('dps-airlines:server:hirePlayer', input[1], input[2])
end
