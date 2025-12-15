-- NPC Interaction System
local QBCore = exports['qb-core']:GetCoreObject()

-- This file handles any additional NPC-related functionality
-- Main NPC spawning is in main.lua

-- =====================================
-- AMBIENT AIRPORT PEDS
-- =====================================

local AmbientPeds = {}
local AmbientPedsEnabled = true

local AmbientPedModels = {
    'a_m_m_business_01',
    'a_f_y_business_01',
    'a_m_y_business_02',
    'a_f_y_business_02',
    'a_m_m_tourist_01',
    'a_f_m_tourist_01',
    's_f_y_airhostess_01',
    's_m_m_pilot_01',
    's_m_y_airworker',
}

local AmbientScenarios = {
    'WORLD_HUMAN_STAND_MOBILE',
    'WORLD_HUMAN_STAND_IMPATIENT',
    'WORLD_HUMAN_SMOKING',
    'WORLD_HUMAN_AA_COFFEE',
    'WORLD_HUMAN_CLIPBOARD',
}

-- Spawn ambient peds at terminal
function SpawnAmbientPeds()
    if not AmbientPedsEnabled then return end

    CleanupAmbientPeds()

    local terminal = Locations.Hub.terminal
    if not terminal then return end

    -- Spawn 5-10 ambient peds
    local count = math.random(5, 10)

    for i = 1, count do
        local model = AmbientPedModels[math.random(1, #AmbientPedModels)]
        local hash = GetHashKey(model)
        lib.requestModel(hash)

        local offset = vector3(
            math.random(-15, 15),
            math.random(-15, 15),
            0
        )

        local spawnPos = vector3(
            terminal.x + offset.x,
            terminal.y + offset.y,
            terminal.z
        )

        local ped = CreatePed(4, hash, spawnPos.x, spawnPos.y, spawnPos.z - 1.0, math.random(0, 360), false, true)

        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, true)

        local scenario = AmbientScenarios[math.random(1, #AmbientScenarios)]
        TaskStartScenarioInPlace(ped, scenario, 0, true)

        table.insert(AmbientPeds, ped)
    end
end

function CleanupAmbientPeds()
    for _, ped in ipairs(AmbientPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    AmbientPeds = {}
end

-- Spawn ambient peds when player is near terminal
CreateThread(function()
    while true do
        Wait(5000)

        local playerPos = GetEntityCoords(PlayerPedId())
        local terminal = Locations.Hub.terminal

        if terminal then
            local dist = #(playerPos - vector3(terminal.x, terminal.y, terminal.z))

            if dist < 100 and #AmbientPeds == 0 then
                SpawnAmbientPeds()
            elseif dist > 150 and #AmbientPeds > 0 then
                CleanupAmbientPeds()
            end
        end
    end
end)

-- =====================================
-- GROUND CREW
-- =====================================

local GroundCrewPeds = {}

function SpawnGroundCrew(planeCoords)
    CleanupGroundCrew()

    local crewModels = {
        's_m_y_airworker',
        's_m_m_ups_01',
    }

    -- Spawn 2-3 ground crew near plane
    for i = 1, math.random(2, 3) do
        local model = crewModels[math.random(1, #crewModels)]
        local hash = GetHashKey(model)
        lib.requestModel(hash)

        local offset = vector3(
            math.random(-5, 5),
            math.random(-5, 5),
            0
        )

        local ped = CreatePed(4, hash,
            planeCoords.x + offset.x,
            planeCoords.y + offset.y,
            planeCoords.z - 1.0,
            math.random(0, 360),
            false, true
        )

        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)

        -- Ground crew scenarios
        local scenarios = {
            'WORLD_HUMAN_CLIPBOARD',
            'CODE_HUMAN_MEDIC_TEND_TO_DEAD',
            'WORLD_HUMAN_CONST_DRILL',
        }
        TaskStartScenarioInPlace(ped, scenarios[math.random(1, #scenarios)], 0, true)

        table.insert(GroundCrewPeds, ped)
    end
end

function CleanupGroundCrew()
    for _, ped in ipairs(GroundCrewPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    GroundCrewPeds = {}
end

-- =====================================
-- FUEL TRUCK
-- =====================================

local FuelTruck = nil
local FuelTruckPed = nil

function SpawnFuelTruck(coords)
    CleanupFuelTruck()

    local truckHash = GetHashKey('airtug')
    local tankerHash = GetHashKey('tanker')
    local pedHash = GetHashKey('s_m_y_airworker')

    lib.requestModel(truckHash)
    lib.requestModel(pedHash)

    FuelTruck = CreateVehicle(truckHash, coords.x, coords.y, coords.z, coords.w or 0.0, false, false)
    SetEntityAsMissionEntity(FuelTruck, true, true)
    SetVehicleOnGroundProperly(FuelTruck)

    FuelTruckPed = CreatePed(4, pedHash, coords.x, coords.y, coords.z, 0.0, false, true)
    SetEntityAsMissionEntity(FuelTruckPed, true, true)
    SetPedIntoVehicle(FuelTruckPed, FuelTruck, -1)
end

function CleanupFuelTruck()
    if FuelTruckPed and DoesEntityExist(FuelTruckPed) then
        DeleteEntity(FuelTruckPed)
        FuelTruckPed = nil
    end
    if FuelTruck and DoesEntityExist(FuelTruck) then
        DeleteEntity(FuelTruck)
        FuelTruck = nil
    end
end

-- =====================================
-- CLEANUP ON RESOURCE STOP
-- =====================================

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        CleanupAmbientPeds()
        CleanupGroundCrew()
        CleanupFuelTruck()
    end
end)

-- =====================================
-- EXPORTS
-- =====================================

exports('SpawnGroundCrew', SpawnGroundCrew)
exports('CleanupGroundCrew', CleanupGroundCrew)
exports('SpawnFuelTruck', SpawnFuelTruck)
exports('CleanupFuelTruck', CleanupFuelTruck)
