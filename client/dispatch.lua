-- Dispatch System
local QBCore = exports['qb-core']:GetCoreObject()

local ActiveDispatch = nil
local DispatchBlip = nil

-- =====================================
-- DISPATCH NOTIFICATION
-- =====================================

RegisterNetEvent('dps-airlines:client:newDispatch', function(dispatch)
    if not OnDuty then return end

    lib.notify({
        title = 'New Flight Available',
        description = string.format('%s → %s | $%d',
            dispatch.from_label,
            dispatch.to_label,
            dispatch.payment
        ),
        type = 'inform',
        duration = 10000
    })

    -- Play sound
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', false)
end)

-- =====================================
-- ACCEPT DISPATCH
-- =====================================

function AcceptDispatch(dispatch)
    if ActiveDispatch then
        lib.notify({ title = 'Dispatch', description = 'You already have an active assignment', type = 'error' })
        return
    end

    if not CurrentPlane then
        lib.notify({ title = 'Dispatch', description = 'You need an aircraft first', type = 'error' })
        return
    end

    local success = lib.callback.await('dps-airlines:server:acceptDispatch', false, dispatch.id)

    if success then
        ActiveDispatch = dispatch

        -- Set waypoint to origin if not already there
        local fromAirport = Locations.Airports[dispatch.from_airport]
        if fromAirport then
            local playerPos = GetEntityCoords(PlayerPedId())
            local dist = #(playerPos - vector3(fromAirport.coords.x, fromAirport.coords.y, fromAirport.coords.z))

            if dist > 500 then
                -- Need to go to origin first
                SetNewWaypoint(fromAirport.coords.x, fromAirport.coords.y)
                lib.notify({
                    title = 'Dispatch',
                    description = 'Head to ' .. fromAirport.label .. ' first',
                    type = 'inform'
                })
            else
                -- Already at origin, set destination
                local toAirport = Locations.Airports[dispatch.to_airport]
                SetNewWaypoint(toAirport.coords.x, toAirport.coords.y)
                lib.notify({
                    title = 'Dispatch',
                    description = 'Head to ' .. toAirport.label,
                    type = 'success'
                })
            end
        end

        -- Start flight
        TriggerServerEvent('dps-airlines:server:startFlight', {
            from = dispatch.from_airport,
            to = dispatch.to_airport,
            flightType = dispatch.flight_type,
            plane = GetCurrentPlaneName(),
            passengers = dispatch.passengers or 0,
            cargo = dispatch.cargo_weight or 0
        })
    else
        lib.notify({ title = 'Dispatch', description = 'Failed to accept dispatch', type = 'error' })
    end
end

function GetCurrentPlaneName()
    if not CurrentPlane then return nil end

    local model = GetEntityModel(CurrentPlane)
    for name, data in pairs(Config.Planes) do
        if GetHashKey(name) == model then
            return name
        end
    end
    return nil
end

-- =====================================
-- DISPATCH COMPLETION CHECK
-- =====================================

CreateThread(function()
    while true do
        Wait(2000)

        if ActiveDispatch and CurrentPlane and DoesEntityExist(CurrentPlane) then
            local toAirport = Locations.Airports[ActiveDispatch.to_airport]
            if toAirport then
                local playerPos = GetEntityCoords(PlayerPedId())
                local dist = #(playerPos - vector3(toAirport.coords.x, toAirport.coords.y, toAirport.coords.z))
                local heightAboveGround = GetEntityHeightAboveGround(CurrentPlane)
                local speed = GetEntitySpeed(CurrentPlane)

                -- Check if landed at destination
                if dist < 200 and heightAboveGround < 5 and speed < 10 then
                    CompleteDispatch()
                end
            end
        end
    end
end)

function CompleteDispatch()
    if not ActiveDispatch then return end

    lib.notify({
        title = 'Flight Complete',
        description = 'Arrived at destination',
        type = 'success'
    })

    TriggerServerEvent('dps-airlines:server:completeFlight')

    -- Cleanup
    ActiveDispatch = nil
    if DispatchBlip then
        RemoveBlip(DispatchBlip)
        DispatchBlip = nil
    end
end

-- =====================================
-- CANCEL DISPATCH
-- =====================================

function CancelDispatch()
    if not ActiveDispatch then return end

    local confirm = lib.alertDialog({
        header = 'Cancel Assignment',
        content = 'Are you sure you want to cancel this flight? This may affect your reputation.',
        centered = true,
        cancel = true
    })

    if confirm == 'confirm' then
        TriggerServerEvent('dps-airlines:server:cancelFlight')

        ActiveDispatch = nil
        if DispatchBlip then
            RemoveBlip(DispatchBlip)
            DispatchBlip = nil
        end

        lib.notify({ title = 'Dispatch', description = 'Flight cancelled', type = 'warning' })
    end
end

-- =====================================
-- AUTO DISPATCH GENERATION (Server triggers this periodically)
-- =====================================

RegisterNetEvent('dps-airlines:client:dispatchGenerated', function(dispatch)
    if OnDuty then
        lib.notify({
            title = 'New Dispatch',
            description = string.format('%s flight to %s available',
                dispatch.flight_type:gsub("^%l", string.upper),
                dispatch.to_label
            ),
            type = 'inform',
            duration = 8000
        })
    end
end)

-- =====================================
-- EXPORTS
-- =====================================

exports('GetActiveDispatch', function() return ActiveDispatch end)
exports('AcceptDispatch', AcceptDispatch)
exports('CancelDispatch', CancelDispatch)
