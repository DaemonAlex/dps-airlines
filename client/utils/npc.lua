-- Client utilities: NPC helpers

---Spawn an interaction NPC with ox_target
---@param coords vector4
---@param model string
---@param scenario string
---@param targetOptions table
---@return number ped
function SpawnInteractionNPC(coords, model, scenario, targetOptions)
    local hash = type(model) == 'string' and joaat(model) or model
    lib.requestModel(hash)

    local ped = CreatePed(0, hash, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanBeTargetted(ped, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)

    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(hash)

    if targetOptions then
        exports.ox_target:addLocalEntity(ped, targetOptions)
    end

    return ped
end
