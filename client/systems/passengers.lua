-- Client: Passenger NPC system

local passengerPeds = {}
local boardingActive = false

---Spawn passenger NPCs at a gate
---@param gateCoords vector3
---@param count number
---@param heading number
function SpawnPassengers(gateCoords, count, heading)
    DespawnPassengers()

    local models = {
        'a_f_m_tourist_01', 'a_m_m_business_01', 'a_f_y_business_01',
        'a_m_y_tourist_01', 'a_f_m_fatbla_01', 'a_m_m_afriamer_01',
        'a_f_y_hipster_01', 'a_m_y_hipster_01',
    }

    for i = 1, math.min(count, 20) do -- Cap visual passengers at 20
        local modelHash = joaat(models[math.random(#models)])
        lib.requestModel(modelHash)

        local offsetX = (i % 5) * 1.5 - 3.0
        local offsetY = math.floor(i / 5) * 1.5

        local x = gateCoords.x + offsetX
        local y = gateCoords.y + offsetY
        local z = gateCoords.z - 1.0

        local ped = CreatePed(0, modelHash, x, y, z, heading or 0.0, false, true)

        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedDiesWhenInjured(ped, false)
        SetPedCanBeTargetted(ped, false)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)

        -- Random idle scenarios
        local scenarios = {
            'WORLD_HUMAN_STAND_IMPATIENT',
            'WORLD_HUMAN_STAND_MOBILE',
            'WORLD_HUMAN_AA_COFFEE',
        }
        TaskStartScenarioInPlace(ped, scenarios[math.random(#scenarios)], 0, true)

        SetModelAsNoLongerNeeded(modelHash)
        passengerPeds[#passengerPeds + 1] = ped
    end
end

---Despawn all passenger NPCs
function DespawnPassengers()
    for _, ped in ipairs(passengerPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    passengerPeds = {}
end

---Animate passengers boarding
---@param vehicle number
---@param count number
function BoardPassengers(vehicle, count)
    if boardingActive then return end
    boardingActive = true

    -- Simulate boarding with progress bar
    local boardingTime = math.min(count * 500, 15000) -- 0.5s per passenger, max 15s

    local success = lib.progressBar({
        duration = boardingTime,
        label = string.format('Boarding %d passengers...', count),
        useWhileDead = false,
        canCancel = true,
    })

    if success then
        DespawnPassengers()
        Bridge.Notify('All passengers boarded!', 'success')
    else
        Bridge.Notify('Boarding interrupted', 'error')
    end

    boardingActive = false
end

---Spawn passengers at destination on arrival
---@param gateCoords vector3
---@param count number
---@param heading number
function DisembarkPassengers(gateCoords, count, heading)
    SpawnPassengers(gateCoords, count, heading)

    -- Auto-despawn after delay
    SetTimeout(30000, function()
        DespawnPassengers()
    end)
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    DespawnPassengers()
end)
