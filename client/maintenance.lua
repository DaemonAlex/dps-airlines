-- Aircraft Maintenance System
local QBCore = exports['qb-core']:GetCoreObject()

-- =====================================
-- MAINTENANCE MENU
-- =====================================

function OpenMaintenanceMenu()
    if not PlayerData.job or PlayerData.job.name ~= Config.Job then
        lib.notify({ title = 'Maintenance', description = 'Pilots only', type = 'error' })
        return
    end

    local options = {
        {
            title = 'View Aircraft Status',
            description = 'Check maintenance status of all aircraft',
            icon = 'fas fa-clipboard-check',
            onSelect = function()
                ViewAircraftStatus()
            end
        },
        {
            title = 'Request Service',
            description = 'Schedule maintenance for an aircraft',
            icon = 'fas fa-tools',
            onSelect = function()
                OpenServiceMenu()
            end,
            disabled = PlayerData.job.grade.level < Config.BossGrade
        },
        {
            title = 'Maintenance History',
            description = 'View past maintenance records',
            icon = 'fas fa-history',
            onSelect = function()
                ViewMaintenanceHistory()
            end
        }
    }

    lib.registerContext({
        id = 'airlines_maintenance_menu',
        title = 'Aircraft Maintenance',
        options = options
    })

    lib.showContext('airlines_maintenance_menu')
end

-- =====================================
-- AIRCRAFT STATUS
-- =====================================

function ViewAircraftStatus()
    local options = {}

    for model, data in pairs(Config.Planes) do
        local maintenance = lib.callback.await('dps-airlines:server:getMaintenanceStatus', false, model)

        if maintenance then
            local flightsSince = maintenance.flights_since_service or 0
            local maxFlights = Config.Maintenance.flightsBeforeService
            local needsService = flightsSince >= maxFlights

            local statusText = needsService
                and '^1NEEDS SERVICE^7'
                or string.format('%d/%d flights until service', flightsSince, maxFlights)

            local progressPercent = math.floor((flightsSince / maxFlights) * 100)

            table.insert(options, {
                title = data.label,
                description = statusText,
                icon = needsService and 'fas fa-exclamation-triangle' or 'fas fa-plane',
                progress = progressPercent,
                colorScheme = needsService and 'red' or (progressPercent > 70 and 'yellow' or 'green'),
                metadata = {
                    { label = 'Flights Since Service', value = tostring(flightsSince) },
                    { label = 'Service Interval', value = tostring(maxFlights) },
                    { label = 'Status', value = needsService and 'Grounded' or 'Operational' }
                }
            })
        end
    end

    lib.registerContext({
        id = 'airlines_aircraft_status',
        title = 'Aircraft Status',
        menu = 'airlines_maintenance_menu',
        options = options
    })

    lib.showContext('airlines_aircraft_status')
end

-- =====================================
-- SERVICE MENU
-- =====================================

function OpenServiceMenu()
    local options = {}

    for model, data in pairs(Config.Planes) do
        local maintenance = lib.callback.await('dps-airlines:server:getMaintenanceStatus', false, model)
        local cost = Config.Maintenance.serviceCost[data.category]

        if maintenance then
            local needsService = maintenance.flights_since_service >= Config.Maintenance.flightsBeforeService

            table.insert(options, {
                title = data.label,
                description = needsService
                    and string.format('NEEDS SERVICE - $%d', cost)
                    or string.format('Service cost: $%d', cost),
                icon = 'fas fa-wrench',
                disabled = not needsService,
                onSelect = function()
                    ServiceAircraft(model, data.label, cost)
                end
            })
        end
    end

    lib.registerContext({
        id = 'airlines_service_menu',
        title = 'Request Service',
        menu = 'airlines_maintenance_menu',
        options = options
    })

    lib.showContext('airlines_service_menu')
end

function ServiceAircraft(model, label, cost)
    local confirm = lib.alertDialog({
        header = 'Confirm Service',
        content = string.format([[
**Aircraft:** %s
**Cost:** $%d

This will be paid from company funds.
        ]], label, cost),
        centered = true,
        cancel = true
    })

    if confirm == 'confirm' then
        -- Play animation
        lib.progressBar({
            duration = 10000,
            label = string.format('Servicing %s...', label),
            useWhileDead = false,
            canCancel = false,
            disable = { move = true, car = true, combat = true },
            anim = {
                dict = 'mini@repair',
                clip = 'fixing_a_player'
            }
        })

        TriggerServerEvent('dps-airlines:server:servicePlane', model)
    end
end

-- =====================================
-- MAINTENANCE HISTORY
-- =====================================

function ViewMaintenanceHistory()
    local history = lib.callback.await('dps-airlines:server:getMaintenanceHistory', false)

    if not history or #history == 0 then
        lib.notify({ title = 'Maintenance', description = 'No maintenance records found', type = 'inform' })
        return
    end

    local options = {}

    for _, record in ipairs(history) do
        table.insert(options, {
            title = record.plane_model:upper(),
            description = string.format('Last service: %s', record.last_service or 'Never'),
            icon = 'fas fa-file-alt',
            metadata = {
                { label = 'Service Type', value = 'Full Service' },
                { label = 'Date', value = record.last_service or 'N/A' }
            }
        })
    end

    lib.registerContext({
        id = 'airlines_maintenance_history',
        title = 'Maintenance History',
        menu = 'airlines_maintenance_menu',
        options = options
    })

    lib.showContext('airlines_maintenance_history')
end

-- =====================================
-- PRE-FLIGHT CHECK
-- =====================================

function PerformPreFlightCheck(plane)
    if not Config.Maintenance.enabled then return true end

    local model = GetEntityModel(plane)
    local planeName = nil

    for name, data in pairs(Config.Planes) do
        if GetHashKey(name) == model then
            planeName = name
            break
        end
    end

    if not planeName then return true end

    local maintenance = lib.callback.await('dps-airlines:server:getMaintenanceStatus', false, planeName)

    if maintenance and maintenance.flights_since_service >= Config.Maintenance.flightsBeforeService then
        lib.notify({
            title = 'Pre-Flight Check',
            description = 'This aircraft requires maintenance before flying',
            type = 'error',
            duration = 5000
        })
        return false
    end

    -- Random breakdown chance if close to service interval
    local flightsRemaining = Config.Maintenance.flightsBeforeService - (maintenance and maintenance.flights_since_service or 0)
    if flightsRemaining <= 3 then
        lib.notify({
            title = 'Pre-Flight Warning',
            description = string.format('Aircraft due for service in %d flights', flightsRemaining),
            type = 'warning',
            duration = 5000
        })
    end

    return true
end

-- =====================================
-- IN-FLIGHT BREAKDOWN
-- =====================================

function CheckForBreakdown(plane)
    if not Config.Maintenance.enabled then return false end

    local model = GetEntityModel(plane)
    local planeName = nil

    for name, data in pairs(Config.Planes) do
        if GetHashKey(name) == model then
            planeName = name
            break
        end
    end

    if not planeName then return false end

    local maintenance = lib.callback.await('dps-airlines:server:getMaintenanceStatus', false, planeName)

    if maintenance and maintenance.flights_since_service >= Config.Maintenance.flightsBeforeService then
        -- Roll for breakdown
        local roll = math.random(1, 100)
        if roll <= Config.Maintenance.breakdownChance then
            TriggerBreakdown(plane)
            return true
        end
    end

    return false
end

function TriggerBreakdown(plane)
    lib.notify({
        title = 'ENGINE TROUBLE',
        description = 'You are experiencing mechanical issues!',
        type = 'error',
        duration = 10000
    })

    -- Reduce engine performance
    SetVehicleEngineHealth(plane, 500.0)

    -- Could add more effects like smoke, etc.
end

-- =====================================
-- EVENT HANDLERS
-- =====================================

RegisterNetEvent('dps-airlines:client:planeServiced', function(model)
    lib.notify({
        title = 'Maintenance',
        description = 'Aircraft has been serviced and is ready for flight',
        type = 'success'
    })
end)

-- =====================================
-- EXPORTS
-- =====================================

exports('PerformPreFlightCheck', PerformPreFlightCheck)
exports('CheckForBreakdown', CheckForBreakdown)
