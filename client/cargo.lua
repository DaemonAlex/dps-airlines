-- Cargo System
local QBCore = exports['qb-core']:GetCoreObject()

local CurrentCargo = nil
local CargoLoaded = false

-- =====================================
-- CARGO MENU
-- =====================================

function OpenCargoMenu()
    if not OnDuty then
        lib.notify({ title = 'Airlines', description = 'You must be on duty', type = 'error' })
        return
    end

    local options = {
        {
            title = 'Load Cargo',
            description = 'Load cargo onto your aircraft',
            icon = 'fas fa-truck-loading',
            onSelect = function()
                OpenCargoLoadMenu()
            end,
            disabled = not CurrentPlane or CargoLoaded
        },
        {
            title = 'Unload Cargo',
            description = 'Unload cargo from your aircraft',
            icon = 'fas fa-dolly',
            onSelect = function()
                UnloadCargo()
            end,
            disabled = not CargoLoaded
        },
        {
            title = 'View Cargo Manifest',
            description = 'Check current cargo details',
            icon = 'fas fa-clipboard-list',
            onSelect = function()
                ViewCargoManifest()
            end,
            disabled = not CurrentCargo
        }
    }

    lib.registerContext({
        id = 'airlines_cargo_menu',
        title = 'Cargo Operations',
        options = options
    })

    lib.showContext('airlines_cargo_menu')
end

function OpenCargoLoadMenu()
    if not CurrentPlane or not DoesEntityExist(CurrentPlane) then
        lib.notify({ title = 'Cargo', description = 'You need an aircraft first', type = 'error' })
        return
    end

    -- Get plane cargo capacity
    local planeModel = GetEntityModel(CurrentPlane)
    local planeData = nil
    local planeName = nil

    for model, data in pairs(Config.Planes) do
        if GetHashKey(model) == planeModel then
            planeData = data
            planeName = model
            break
        end
    end

    if not planeData then
        lib.notify({ title = 'Cargo', description = 'Unknown aircraft', type = 'error' })
        return
    end

    local options = {}

    for _, cargoType in ipairs(Config.Cargo.cargoTypes) do
        local maxWeight = math.min(cargoType.weight.max, planeData.maxCargo)
        local minWeight = cargoType.weight.min

        table.insert(options, {
            title = cargoType.label,
            description = string.format('Weight: %d-%dkg | Pay: $%.2f/kg', minWeight, maxWeight, Config.Cargo.payPerKg * cargoType.payMultiplier),
            icon = 'fas fa-box',
            onSelect = function()
                LoadCargo(cargoType, planeData.maxCargo)
            end
        })
    end

    lib.registerContext({
        id = 'airlines_cargo_load_menu',
        title = string.format('Load Cargo (Max: %dkg)', planeData.maxCargo),
        menu = 'airlines_cargo_menu',
        options = options
    })

    lib.showContext('airlines_cargo_load_menu')
end

-- =====================================
-- CARGO LOADING
-- =====================================

function LoadCargo(cargoType, maxCapacity)
    local input = lib.inputDialog('Load Cargo', {
        {
            type = 'slider',
            label = 'Weight (kg)',
            default = cargoType.weight.min,
            min = cargoType.weight.min,
            max = math.min(cargoType.weight.max, maxCapacity),
            step = 10
        }
    })

    if not input then return end

    local weight = input[1]

    -- Loading animation
    local success = lib.progressBar({
        duration = math.floor(weight / 10) * 1000, -- 1 second per 10kg
        label = string.format('Loading %dkg of %s...', weight, cargoType.label),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'anim@heists@box_carry@',
            clip = 'idle'
        }
    })

    if success then
        CurrentCargo = {
            type = cargoType.name,
            label = cargoType.label,
            weight = weight,
            payMultiplier = cargoType.payMultiplier,
            loadedAt = GetGameTimer()
        }
        CargoLoaded = true

        lib.notify({
            title = 'Cargo Loaded',
            description = string.format('%dkg of %s loaded', weight, cargoType.label),
            type = 'success'
        })
    else
        lib.notify({ title = 'Cargo', description = 'Loading cancelled', type = 'error' })
    end
end

-- =====================================
-- CARGO UNLOADING
-- =====================================

function UnloadCargo()
    if not CurrentCargo then
        lib.notify({ title = 'Cargo', description = 'No cargo to unload', type = 'error' })
        return
    end

    local success = lib.progressBar({
        duration = math.floor(CurrentCargo.weight / 10) * 800,
        label = string.format('Unloading %dkg of %s...', CurrentCargo.weight, CurrentCargo.label),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'anim@heists@box_carry@',
            clip = 'idle'
        }
    })

    if success then
        lib.notify({
            title = 'Cargo Unloaded',
            description = string.format('%dkg delivered', CurrentCargo.weight),
            type = 'success'
        })

        -- Return cargo info for payment calculation
        local cargo = CurrentCargo
        CurrentCargo = nil
        CargoLoaded = false

        return cargo
    end

    return nil
end

-- =====================================
-- CARGO MANIFEST
-- =====================================

function ViewCargoManifest()
    if not CurrentCargo then
        lib.notify({ title = 'Cargo', description = 'No cargo loaded', type = 'error' })
        return
    end

    local estimatedPay = CurrentCargo.weight * Config.Cargo.payPerKg * CurrentCargo.payMultiplier

    lib.alertDialog({
        header = 'Cargo Manifest',
        content = string.format([[
**Type:** %s
**Weight:** %d kg
**Pay Rate:** $%.2f/kg
**Estimated Payment:** $%d

*Deliver to destination to receive payment*
        ]],
            CurrentCargo.label,
            CurrentCargo.weight,
            Config.Cargo.payPerKg * CurrentCargo.payMultiplier,
            math.floor(estimatedPay)
        ),
        centered = true,
        cancel = false
    })
end

-- =====================================
-- EXPORTS
-- =====================================

exports('GetCurrentCargo', function() return CurrentCargo end)
exports('IsCargoLoaded', function() return CargoLoaded end)
exports('LoadCargo', LoadCargo)
exports('UnloadCargo', UnloadCargo)
