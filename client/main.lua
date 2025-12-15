local QBCore = exports['qb-core']:GetCoreObject()

-- Player State
PlayerData = {}
PlayerStats = nil
OnDuty = false
HasLicense = false
CurrentPlane = nil
CurrentFlight = nil
SpawnedNPCs = {}
CreatedBlips = {}

-- =====================================
-- INITIALIZATION
-- =====================================

local function LoadPlayerData()
    PlayerData = lib.callback.await('dps-airlines:server:getPlayerData', false)
    if PlayerData then
        PlayerStats = PlayerData.stats
        HasLicense = PlayerData.hasLicense
        OnDuty = PlayerData.onDuty
    end
end

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(100)
    end
    Wait(1000)
    LoadPlayerData()
    SetupBlips()
    SetupNPCs()
    SetupTargets()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    LoadPlayerData()
    SetupBlips()
    SetupNPCs()
    SetupTargets()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    PlayerStats = nil
    OnDuty = false
    HasLicense = false
    CleanupPlane()
    CleanupNPCs()
    CleanupBlips()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
    OnDuty = job.onduty
end)

-- =====================================
-- BLIPS
-- =====================================

function SetupBlips()
    CleanupBlips()

    -- Hub blip
    local hubBlip = AddBlipForCoord(Locations.Hub.coords.x, Locations.Hub.coords.y, Locations.Hub.coords.z)
    SetBlipSprite(hubBlip, Locations.Blips.hub.sprite)
    SetBlipColour(hubBlip, Locations.Blips.hub.color)
    SetBlipScale(hubBlip, Locations.Blips.hub.scale)
    SetBlipAsShortRange(hubBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Locations.Blips.hub.label)
    EndTextCommandSetBlipName(hubBlip)
    table.insert(CreatedBlips, hubBlip)

    -- Flight school blip
    local schoolBlip = AddBlipForCoord(Locations.Hub.flightSchool.x, Locations.Hub.flightSchool.y, Locations.Hub.flightSchool.z)
    SetBlipSprite(schoolBlip, Locations.Blips.flightSchool.sprite)
    SetBlipColour(schoolBlip, Locations.Blips.flightSchool.color)
    SetBlipScale(schoolBlip, Locations.Blips.flightSchool.scale)
    SetBlipAsShortRange(schoolBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Locations.Blips.flightSchool.label)
    EndTextCommandSetBlipName(schoolBlip)
    table.insert(CreatedBlips, schoolBlip)

    -- Airport destination blips (only show when on duty)
    -- These are added dynamically
end

function CleanupBlips()
    for _, blip in ipairs(CreatedBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    CreatedBlips = {}
end

-- =====================================
-- NPCs
-- =====================================

function SetupNPCs()
    CleanupNPCs()

    for _, npc in ipairs(Locations.NPCs) do
        local model = GetHashKey(npc.model)
        lib.requestModel(model)

        local ped = CreatePed(4, model, npc.coords.x, npc.coords.y, npc.coords.z - 1.0, npc.coords.w, false, true)
        SetEntityHeading(ped, npc.coords.w)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)

        if npc.scenario then
            TaskStartScenarioInPlace(ped, npc.scenario, 0, true)
        end

        SpawnedNPCs[npc.id] = ped
    end
end

function CleanupNPCs()
    for id, ped in pairs(SpawnedNPCs) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    SpawnedNPCs = {}
end

-- =====================================
-- TARGET SETUP
-- =====================================

function SetupTargets()
    -- Job Menu / Dispatch NPC
    if SpawnedNPCs['dispatch'] then
        exports.ox_target:addLocalEntity(SpawnedNPCs['dispatch'], {
            {
                name = 'airlines_dispatch',
                icon = 'fas fa-plane',
                label = 'Airlines Dispatch',
                onSelect = function()
                    OpenMainMenu()
                end,
            }
        })
    end

    -- Flight School NPC
    if SpawnedNPCs['flightschool'] then
        exports.ox_target:addLocalEntity(SpawnedNPCs['flightschool'], {
            {
                name = 'airlines_school',
                icon = 'fas fa-graduation-cap',
                label = 'Flight School',
                onSelect = function()
                    OpenFlightSchoolMenu()
                end,
            }
        })
    end

    -- Mechanic NPC
    if SpawnedNPCs['mechanic'] then
        exports.ox_target:addLocalEntity(SpawnedNPCs['mechanic'], {
            {
                name = 'airlines_mechanic',
                icon = 'fas fa-wrench',
                label = 'Aircraft Maintenance',
                onSelect = function()
                    OpenMaintenanceMenu()
                end,
                canInteract = function()
                    return PlayerData.job and PlayerData.job.name == Config.Job
                end
            }
        })
    end

    -- Cargo NPC
    if SpawnedNPCs['cargo'] then
        exports.ox_target:addLocalEntity(SpawnedNPCs['cargo'], {
            {
                name = 'airlines_cargo',
                icon = 'fas fa-boxes',
                label = 'Cargo Operations',
                onSelect = function()
                    OpenCargoMenu()
                end,
                canInteract = function()
                    return PlayerData.job and PlayerData.job.name == Config.Job and OnDuty
                end
            }
        })
    end

    -- Plane spawn zone
    exports.ox_target:addBoxZone({
        coords = Locations.Hub.planeSpawns[1],
        size = vec3(4, 4, 3),
        rotation = Locations.Hub.planeSpawns[1].w,
        debug = Config.Debug,
        options = {
            {
                name = 'spawn_plane',
                icon = 'fas fa-plane-departure',
                label = 'Spawn Aircraft',
                onSelect = function()
                    OpenPlaneSpawnMenu()
                end,
                canInteract = function()
                    return PlayerData.job and PlayerData.job.name == Config.Job and OnDuty and not CurrentPlane
                end
            },
            {
                name = 'store_plane',
                icon = 'fas fa-plane-arrival',
                label = 'Store Aircraft',
                onSelect = function()
                    StorePlane()
                end,
                canInteract = function()
                    return CurrentPlane and DoesEntityExist(CurrentPlane)
                end
            }
        }
    })

    -- Fuel zone
    exports.ox_target:addBoxZone({
        coords = Locations.Hub.fuel,
        size = vec3(5, 5, 3),
        rotation = Locations.Hub.fuel.w,
        debug = Config.Debug,
        options = {
            {
                name = 'refuel_plane',
                icon = 'fas fa-gas-pump',
                label = 'Refuel Aircraft',
                onSelect = function()
                    RefuelPlane()
                end,
                canInteract = function()
                    return CurrentPlane and DoesEntityExist(CurrentPlane)
                end
            }
        }
    })
end

-- =====================================
-- MENUS
-- =====================================

function OpenMainMenu()
    LoadPlayerData()

    local options = {}

    -- Clock in/out (pilots only)
    if PlayerData.job and PlayerData.job.name == Config.Job then
        table.insert(options, {
            title = OnDuty and 'Clock Out' or 'Clock In',
            description = OnDuty and 'End your shift' or 'Start your shift',
            icon = OnDuty and 'fas fa-clock' or 'fas fa-sign-in-alt',
            onSelect = function()
                TriggerServerEvent('dps-airlines:server:toggleDuty')
            end
        })
    end

    -- View flights (on duty only)
    if OnDuty then
        table.insert(options, {
            title = 'Available Flights',
            description = 'View and accept flight assignments',
            icon = 'fas fa-clipboard-list',
            onSelect = function()
                OpenFlightsMenu()
            end
        })

        table.insert(options, {
            title = 'Charter Requests',
            description = 'View private charter requests',
            icon = 'fas fa-user-tie',
            onSelect = function()
                OpenCharterMenu()
            end
        })
    end

    -- Stats
    table.insert(options, {
        title = 'My Statistics',
        description = 'View your pilot statistics',
        icon = 'fas fa-chart-bar',
        onSelect = function()
            OpenStatsMenu()
        end
    })

    -- Boss menu (grade 2+)
    if PlayerData.job and PlayerData.job.name == Config.Job and PlayerData.job.grade.level >= Config.BossGrade then
        table.insert(options, {
            title = 'Management',
            description = 'Boss management options',
            icon = 'fas fa-briefcase',
            onSelect = function()
                OpenBossMenu()
            end
        })
    end

    lib.registerContext({
        id = 'airlines_main_menu',
        title = 'Los Santos Airlines',
        options = options
    })

    lib.showContext('airlines_main_menu')
end

function OpenPlaneSpawnMenu()
    local stats = lib.callback.await('dps-airlines:server:getPilotStats', false)
    local options = {}

    for model, data in pairs(Config.Planes) do
        local canUse = stats.reputation >= data.repRequired
        local maintenance = lib.callback.await('dps-airlines:server:getMaintenanceStatus', false, model)
        local needsService = maintenance and maintenance.flights_since_service >= Config.Maintenance.flightsBeforeService

        local description = string.format('Passengers: %d | Cargo: %dkg', data.maxPassengers, data.maxCargo)
        if not canUse then
            description = string.format('Requires %d reputation', data.repRequired)
        elseif needsService then
            description = 'NEEDS MAINTENANCE'
        end

        table.insert(options, {
            title = data.label,
            description = description,
            icon = 'fas fa-plane',
            disabled = not canUse or needsService,
            onSelect = function()
                SpawnPlane(model)
            end
        })
    end

    lib.registerContext({
        id = 'airlines_spawn_menu',
        title = 'Select Aircraft',
        menu = 'airlines_main_menu',
        options = options
    })

    lib.showContext('airlines_spawn_menu')
end

function OpenFlightsMenu()
    local flights = lib.callback.await('dps-airlines:server:getAvailableFlights', false)
    local options = {}

    if #flights == 0 then
        table.insert(options, {
            title = 'No Flights Available',
            description = 'Check back later for new assignments',
            icon = 'fas fa-info-circle',
            disabled = true
        })
    else
        for _, flight in ipairs(flights) do
            local fromAirport = Locations.Airports[flight.from_airport]
            local toAirport = Locations.Airports[flight.to_airport]
            local priorityColor = flight.priority == 'urgent' and '^1' or flight.priority == 'high' and '^3' or ''

            table.insert(options, {
                title = string.format('%s → %s', fromAirport.label, toAirport.label),
                description = string.format('Type: %s | Pay: $%d | Priority: %s',
                    flight.flight_type:gsub("^%l", string.upper),
                    flight.payment,
                    flight.priority:upper()
                ),
                icon = flight.flight_type == 'cargo' and 'fas fa-boxes' or 'fas fa-users',
                onSelect = function()
                    AcceptFlight(flight)
                end
            })
        end
    end

    lib.registerContext({
        id = 'airlines_flights_menu',
        title = 'Available Flights',
        menu = 'airlines_main_menu',
        options = options
    })

    lib.showContext('airlines_flights_menu')
end

function OpenStatsMenu()
    local stats = lib.callback.await('dps-airlines:server:getPilotStats', false)

    local options = {
        {
            title = 'Total Flights',
            description = tostring(stats.total_flights),
            icon = 'fas fa-plane'
        },
        {
            title = 'Passengers Transported',
            description = tostring(stats.total_passengers),
            icon = 'fas fa-users'
        },
        {
            title = 'Cargo Delivered',
            description = string.format('%d kg', stats.total_cargo),
            icon = 'fas fa-boxes'
        },
        {
            title = 'Total Earnings',
            description = string.format('$%d', stats.total_earnings),
            icon = 'fas fa-dollar-sign'
        },
        {
            title = 'Flight Hours',
            description = string.format('%.1f hours', stats.flight_hours),
            icon = 'fas fa-clock'
        },
        {
            title = 'Reputation',
            description = tostring(stats.reputation),
            icon = 'fas fa-star'
        }
    }

    lib.registerContext({
        id = 'airlines_stats_menu',
        title = 'Pilot Statistics',
        menu = 'airlines_main_menu',
        options = options
    })

    lib.showContext('airlines_stats_menu')
end

-- =====================================
-- PLANE FUNCTIONS
-- =====================================

function SpawnPlane(model)
    local canUse, reason = lib.callback.await('dps-airlines:server:canUsePlane', false, model)
    if not canUse then
        lib.notify({ title = 'Airlines', description = reason, type = 'error' })
        return
    end

    -- Find available spawn point
    local spawnPoint = nil
    for _, point in ipairs(Locations.Hub.planeSpawns) do
        local vehicles = lib.getNearbyVehicles(point, 10.0, true)
        if #vehicles == 0 then
            spawnPoint = point
            break
        end
    end

    if not spawnPoint then
        lib.notify({ title = 'Airlines', description = 'All spawn points occupied', type = 'error' })
        return
    end

    local hash = GetHashKey(model)
    lib.requestModel(hash)

    local plane = CreateVehicle(hash, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, false)

    SetVehicleOnGroundProperly(plane)
    SetEntityAsMissionEntity(plane, true, true)
    SetVehicleEngineOn(plane, false, true, false)

    -- Set fuel if using qs-fuel
    if Config.FuelScript == 'qs-fuel' then
        exports['qs-fuelstations']:SetFuel(plane, 100.0)
    elseif Config.FuelScript == 'LegacyFuel' then
        exports['LegacyFuel']:SetFuel(plane, 100.0)
    end

    CurrentPlane = plane
    SetPedIntoVehicle(PlayerPedId(), plane, -1)

    lib.notify({ title = 'Airlines', description = 'Aircraft spawned', type = 'success' })
end

function StorePlane()
    if CurrentPlane and DoesEntityExist(CurrentPlane) then
        DeleteEntity(CurrentPlane)
        CurrentPlane = nil
        lib.notify({ title = 'Airlines', description = 'Aircraft stored', type = 'success' })
    end
end

function CleanupPlane()
    if CurrentPlane and DoesEntityExist(CurrentPlane) then
        DeleteEntity(CurrentPlane)
        CurrentPlane = nil
    end
end

function RefuelPlane()
    if not CurrentPlane or not DoesEntityExist(CurrentPlane) then
        lib.notify({ title = 'Airlines', description = 'No aircraft to refuel', type = 'error' })
        return
    end

    local progress = lib.progressBar({
        duration = 5000,
        label = 'Refueling aircraft...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true }
    })

    if progress then
        if Config.FuelScript == 'qs-fuel' then
            exports['qs-fuelstations']:SetFuel(CurrentPlane, 100.0)
        elseif Config.FuelScript == 'LegacyFuel' then
            exports['LegacyFuel']:SetFuel(CurrentPlane, 100.0)
        end
        lib.notify({ title = 'Airlines', description = 'Aircraft refueled', type = 'success' })
    end
end

-- =====================================
-- FLIGHT FUNCTIONS
-- =====================================

function AcceptFlight(flight)
    if not CurrentPlane then
        lib.notify({ title = 'Airlines', description = 'You need an aircraft first', type = 'error' })
        return
    end

    -- Check if plane can fly to destination
    local destAirport = Locations.Airports[flight.to_airport]
    local planeModel = GetEntityModel(CurrentPlane)
    local planeName = nil

    for model, data in pairs(Config.Planes) do
        if GetHashKey(model) == planeModel then
            planeName = model
            break
        end
    end

    if destAirport.availablePlanes and planeName then
        local canLand = false
        for _, allowed in ipairs(destAirport.availablePlanes) do
            if allowed == planeName then
                canLand = true
                break
            end
        end
        if not canLand then
            lib.notify({ title = 'Airlines', description = 'This aircraft cannot land at that destination', type = 'error' })
            return
        end
    end

    CurrentFlight = {
        id = flight.id,
        from = flight.from_airport,
        to = flight.to_airport,
        type = flight.flight_type,
        passengers = flight.passengers or 0,
        cargo = flight.cargo_weight or 0,
        payment = flight.payment
    }

    -- Set waypoint to destination
    SetNewWaypoint(destAirport.coords.x, destAirport.coords.y)

    TriggerServerEvent('dps-airlines:server:startFlight', {
        from = CurrentFlight.from,
        to = CurrentFlight.to,
        flightType = CurrentFlight.type,
        plane = planeName,
        passengers = CurrentFlight.passengers,
        cargo = CurrentFlight.cargo
    })

    lib.notify({ title = 'Airlines', description = 'Flight accepted! Head to your destination', type = 'success' })
end

-- =====================================
-- EVENTS
-- =====================================

RegisterNetEvent('dps-airlines:client:dutyChanged', function(duty)
    OnDuty = duty
end)

RegisterNetEvent('dps-airlines:client:flightStarted', function(data)
    lib.notify({
        title = 'Flight ' .. data.flightNumber,
        description = 'Departed to ' .. data.destination.label,
        type = 'success'
    })
end)

RegisterNetEvent('dps-airlines:client:flightCompleted', function(data)
    lib.notify({
        title = 'Flight Completed',
        description = string.format('Earned $%d | %d passengers | %dkg cargo',
            data.payment, data.passengers, data.cargo),
        type = 'success',
        duration = 7000
    })
    CurrentFlight = nil
end)

-- =====================================
-- EXPORTS
-- =====================================

exports('IsOnDuty', function()
    return OnDuty
end)

exports('GetCurrentFlight', function()
    return CurrentFlight
end)

exports('GetCurrentPlane', function()
    return CurrentPlane
end)

print('^2[dps-airlines]^7 Client loaded')
