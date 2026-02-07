-- Client: Helicopter operations

---Open helicopter operations menu
---@param airportCode string
function OpenHeliMenu(airportCode)
    if not Config.Helicopters.enabled then
        Bridge.Notify('Helicopter operations are disabled', 'error')
        return
    end

    -- Find nearby helipads
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearbyPads = {}

    for _, pad in ipairs(Locations.Helipads) do
        local dist = #(playerCoords - pad.coords)
        if dist < 500.0 then
            nearbyPads[#nearbyPads + 1] = pad
        end
    end

    local options = {}

    -- Medevac
    options[#options + 1] = {
        title = 'Medevac Mission',
        description = string.format('Base pay: $%d | Time-sensitive medical transport', Config.Helicopters.medevac.basePay),
        icon = 'heartbeat',
        onSelect = function()
            StartMedevac(airportCode)
        end,
    }

    -- Tour
    options[#options + 1] = {
        title = 'Sightseeing Tour',
        description = string.format('Base pay: $%d | Scenic helicopter tour', Config.Helicopters.tour.basePay),
        icon = 'binoculars',
        onSelect = function()
            StartTour(airportCode)
        end,
    }

    -- VIP Transport
    options[#options + 1] = {
        title = 'VIP Transport',
        description = string.format('Base pay: $%d | Executive helicopter transport', Config.Helicopters.vip.basePay),
        icon = 'star',
        onSelect = function()
            StartVIPTransport(airportCode)
        end,
    }

    -- Search & Rescue
    options[#options + 1] = {
        title = 'Search & Rescue',
        description = string.format('Base pay: $%d | Locate and rescue targets', Config.Helicopters.searchRescue.basePay),
        icon = 'search-location',
        onSelect = function()
            StartSearchRescue(airportCode)
        end,
    }

    -- Spawn helicopter option
    options[#options + 1] = {
        title = 'Spawn Helicopter',
        description = 'Spawn a helicopter at nearest pad',
        icon = 'helicopter',
        onSelect = function()
            SpawnHelicopterMenu(airportCode)
        end,
    }

    lib.registerContext({
        id = 'airline_heli_ops',
        title = 'Helicopter Operations',
        options = options,
    })
    lib.showContext('airline_heli_ops')
end

---Spawn helicopter selection menu
---@param airportCode string
function SpawnHelicopterMenu(airportCode)
    local heliOptions = {}
    for _, heli in ipairs(Config.HeliModels) do
        heliOptions[#heliOptions + 1] = { label = heli.label, value = heli.model }
    end

    -- Find nearest helipad
    local nearestPad = Locations.GetNearestHelipad(GetEntityCoords(PlayerPedId()))
    if not nearestPad then
        Bridge.Notify('No helipad nearby', 'error')
        return
    end

    local input = lib.inputDialog('Spawn Helicopter', {
        { type = 'select', label = 'Helicopter', options = heliOptions, required = true },
    })

    if not input then return end

    lib.callback('dps-airlines:server:spawnHelicopter', false, function(spawnData, err)
        if not spawnData then
            Bridge.Notify(err or 'Failed to spawn', 'error')
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

        Bridge.Notify('Helicopter spawned!', 'success')
    end, input[1], nearestPad.code)
end

---Start medevac mission
function StartMedevac(airportCode)
    -- Generate random emergency location
    local playerCoords = GetEntityCoords(PlayerPedId())
    local angle = math.random() * math.pi * 2
    local distance = math.random(2000, 5000)
    local targetX = playerCoords.x + math.cos(angle) * distance
    local targetY = playerCoords.y + math.sin(angle) * distance

    -- Find ground Z
    local targetZ = playerCoords.z

    SetNewWaypoint(targetX, targetY)

    Bridge.Notify(string.format(
        'MEDEVAC: Patient needs airlift! Time limit: %ds. Waypoint set.',
        Config.Helicopters.medevac.timeLimit
    ), 'error', 10000)

    lib.callback('dps-airlines:server:startHeliOp', false, function(result, err)
        if not result then
            Bridge.Notify(err or 'Failed to start medevac', 'error')
            return
        end

        State.CurrentHeliOp = result
        local startTime = GetGameTimer()
        local timeLimit = Config.Helicopters.medevac.timeLimit * 1000

        -- Monitor medevac
        CreateThread(function()
            while State.CurrentHeliOp do
                Wait(1000)

                local elapsed = GetGameTimer() - startTime
                local remaining = math.max(0, timeLimit - elapsed)

                if remaining <= 0 then
                    Bridge.Notify('Medevac time expired!', 'error')
                    CompleteHeliOp({ timeRemaining = 0, duration = elapsed / 1000 })
                    return
                end

                -- Check if near target
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local dist = #(coords - vector3(targetX, targetY, coords.z))

                if dist < 50.0 then
                    -- "Rescue" the patient
                    local pickup = lib.progressBar({
                        duration = 5000,
                        label = 'Loading patient...',
                        useWhileDead = false,
                        canCancel = true,
                    })

                    if pickup then
                        -- Now fly to hospital
                        local hospital = Locations.Helipads[1] -- First helipad is hospital
                        if hospital then
                            SetNewWaypoint(hospital.coords.x, hospital.coords.y)
                            Bridge.Notify('Patient loaded! Fly to hospital. Time remaining: ' .. math.floor(remaining/1000) .. 's', 'inform')

                            -- Wait for hospital arrival
                            while State.CurrentHeliOp do
                                Wait(1000)
                                local hospitalDist = #(GetEntityCoords(PlayerPedId()) - hospital.coords)
                                if hospitalDist < 50.0 then
                                    local timeRemaining = math.max(0, timeLimit - (GetGameTimer() - startTime)) / 1000
                                    CompleteHeliOp({ timeRemaining = timeRemaining, duration = (GetGameTimer() - startTime) / 1000 })
                                    return
                                end
                            end
                        end
                    end
                    return
                end
            end
        end)
    end, {
        opType = Constants.HELI_MEDEVAC,
        model = GetDisplayNameFromVehicleModel(GetEntityModel(GetVehiclePedIsIn(PlayerPedId(), false))):lower(),
        originCode = airportCode,
    })
end

---Start sightseeing tour
function StartTour(airportCode)
    -- Select tour route
    local routeOptions = {}
    for key, route in pairs(Locations.TourRoutes) do
        routeOptions[#routeOptions + 1] = { label = route.label, value = key }
    end

    local input = lib.inputDialog('Select Tour', {
        { type = 'select', label = 'Tour Route', options = routeOptions, required = true },
    })
    if not input then return end

    local route = Locations.TourRoutes[input[1]]
    if not route then return end

    lib.callback('dps-airlines:server:startHeliOp', false, function(result, err)
        if not result then
            Bridge.Notify(err or 'Failed to start tour', 'error')
            return
        end

        State.CurrentHeliOp = result
        Bridge.Notify('Tour started: ' .. route.label .. '. Follow the waypoints!', 'success')

        local waypointsHit = 0
        local startTime = GetGameTimer()

        for i, wp in ipairs(route.waypoints) do
            SetNewWaypoint(wp.x, wp.y)
            Bridge.Notify(string.format('Waypoint %d/%d', i, #route.waypoints), 'inform')

            -- Wait for waypoint
            while State.CurrentHeliOp do
                Wait(1000)
                local dist = #(GetEntityCoords(PlayerPedId()) - wp)
                if dist < 100.0 then
                    waypointsHit = waypointsHit + 1
                    Bridge.Notify('Waypoint reached!', 'success')
                    break
                end
            end

            if not State.CurrentHeliOp then return end
        end

        -- Tour complete
        local duration = (GetGameTimer() - startTime) / 1000
        CompleteHeliOp({ waypointsHit = waypointsHit, duration = duration })
    end, {
        opType = Constants.HELI_TOUR,
        model = GetDisplayNameFromVehicleModel(GetEntityModel(GetVehiclePedIsIn(PlayerPedId(), false))):lower(),
        originCode = airportCode,
    })
end

---Start VIP transport
function StartVIPTransport(airportCode)
    local destOptions = {}
    for _, pad in ipairs(Locations.Helipads) do
        destOptions[#destOptions + 1] = { label = pad.label, value = pad.code }
    end

    local input = lib.inputDialog('VIP Transport', {
        { type = 'select', label = 'Destination', options = destOptions, required = true },
    })
    if not input then return end

    local destPad = nil
    for _, pad in ipairs(Locations.Helipads) do
        if pad.code == input[1] then
            destPad = pad
            break
        end
    end

    if not destPad then return end

    lib.callback('dps-airlines:server:startHeliOp', false, function(result, err)
        if not result then
            Bridge.Notify(err or 'Failed to start VIP transport', 'error')
            return
        end

        State.CurrentHeliOp = result
        SetNewWaypoint(destPad.coords.x, destPad.coords.y)
        Bridge.Notify('VIP Transport to ' .. destPad.label .. '. Fly smoothly!', 'success')

        local startTime = GetGameTimer()

        CreateThread(function()
            while State.CurrentHeliOp do
                Wait(1000)
                local dist = #(GetEntityCoords(PlayerPedId()) - destPad.coords)
                if dist < 50.0 then
                    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                    local velocity = GetEntityVelocity(vehicle)
                    local landingSmooth = math.abs(velocity.z) < Constants.LANDING_SMOOTH
                    local duration = (GetGameTimer() - startTime) / 1000

                    CompleteHeliOp({
                        landingSmooth = landingSmooth,
                        minutesLate = 0,
                        duration = duration,
                    })
                    return
                end
            end
        end)
    end, {
        opType = Constants.HELI_VIP,
        model = GetDisplayNameFromVehicleModel(GetEntityModel(GetVehiclePedIsIn(PlayerPedId(), false))):lower(),
        originCode = airportCode,
        destinationCode = input[1],
    })
end

---Start search & rescue
function StartSearchRescue(airportCode)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local angle = math.random() * math.pi * 2
    local distance = math.random(3000, 7000)
    local searchX = playerCoords.x + math.cos(angle) * distance
    local searchY = playerCoords.y + math.sin(angle) * distance

    lib.callback('dps-airlines:server:startHeliOp', false, function(result, err)
        if not result then
            Bridge.Notify(err or 'Failed to start search', 'error')
            return
        end

        State.CurrentHeliOp = result
        Bridge.Notify(string.format('Search area marked. Time limit: %ds', Config.Helicopters.searchRescue.timeLimit), 'inform', 10000)

        -- Add search area blip
        local searchBlip = AddBlipForRadius(searchX, searchY, 0.0, 500.0)
        SetBlipColour(searchBlip, 1)
        SetBlipAlpha(searchBlip, 100)

        local startTime = GetGameTimer()
        local timeLimit = Config.Helicopters.searchRescue.timeLimit * 1000

        CreateThread(function()
            while State.CurrentHeliOp do
                Wait(1000)

                local elapsed = GetGameTimer() - startTime
                if elapsed > timeLimit then
                    Bridge.Notify('Search time expired!', 'error')
                    RemoveBlip(searchBlip)
                    CompleteHeliOp({ rescued = false, duration = elapsed / 1000 })
                    return
                end

                local dist = #(GetEntityCoords(PlayerPedId()) - vector3(searchX, searchY, GetEntityCoords(PlayerPedId()).z))
                if dist < 200.0 then
                    Bridge.Notify('Target located! Land to rescue.', 'success')

                    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                    if vehicle ~= 0 and GetEntityHeightAboveGround(vehicle) < 5.0 then
                        local rescue = lib.progressBar({
                            duration = 8000,
                            label = 'Rescuing survivor...',
                            useWhileDead = false,
                            canCancel = true,
                        })

                        if rescue then
                            RemoveBlip(searchBlip)
                            CompleteHeliOp({ rescued = true, duration = elapsed / 1000 })
                            return
                        end
                    end
                end
            end

            RemoveBlip(searchBlip)
        end)
    end, {
        opType = Constants.HELI_SEARCH,
        model = GetDisplayNameFromVehicleModel(GetEntityModel(GetVehiclePedIsIn(PlayerPedId(), false))):lower(),
        originCode = airportCode,
    })
end

---Complete a helicopter operation
---@param details table
function CompleteHeliOp(details)
    if not State.CurrentHeliOp then return end

    lib.callback('dps-airlines:server:completeHeliOp', false, function(result, err)
        if result then
            Bridge.Notify(string.format('Operation complete! Pay: $%d', result.pay), 'success', 8000)
        else
            Bridge.Notify(err or 'Failed to complete operation', 'error')
        end
        State.CurrentHeliOp = nil
    end, State.CurrentHeliOp.opId, details)
end
