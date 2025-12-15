-- Private Charter System
local QBCore = exports['qb-core']:GetCoreObject()

local ActiveCharter = nil
local CharterBlip = nil

-- =====================================
-- CHARTER MENU (For Pilots)
-- =====================================

function OpenCharterMenu()
    local charters = lib.callback.await('dps-airlines:server:getAvailableCharters', false)
    local options = {}

    if not charters or #charters == 0 then
        table.insert(options, {
            title = 'No Charter Requests',
            description = 'Check back later for private charter requests',
            icon = 'fas fa-info-circle',
            disabled = true
        })
    else
        for _, charter in ipairs(charters) do
            table.insert(options, {
                title = string.format('Charter #%d', charter.id),
                description = string.format('Fee: $%d | Status: %s', charter.fee, charter.status),
                icon = 'fas fa-user-tie',
                onSelect = function()
                    ViewCharterDetails(charter)
                end
            })
        end
    end

    lib.registerContext({
        id = 'airlines_charter_menu',
        title = 'Charter Requests',
        menu = 'airlines_main_menu',
        options = options
    })

    lib.showContext('airlines_charter_menu')
end

function ViewCharterDetails(charter)
    local pickup = json.decode(charter.pickup_coords)
    local dropoff = json.decode(charter.dropoff_coords)

    local distance = #(vector3(pickup.x, pickup.y, pickup.z) - vector3(dropoff.x, dropoff.y, dropoff.z)) / 1000

    local confirm = lib.alertDialog({
        header = string.format('Charter #%d', charter.id),
        content = string.format([[
**Client:** Awaiting pickup
**Distance:** %.1f km
**Fee:** $%d

Accept this charter?
        ]], distance, charter.fee),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Accept',
            cancel = 'Decline'
        }
    })

    if confirm == 'confirm' then
        AcceptCharter(charter.id)
    end
end

function AcceptCharter(charterId)
    local success = lib.callback.await('dps-airlines:server:acceptCharter', false, charterId)

    if success then
        ActiveCharter = success

        -- Set pickup waypoint
        local pickup = json.decode(ActiveCharter.pickup_coords)
        SetNewWaypoint(pickup.x, pickup.y)

        -- Create blip
        CharterBlip = AddBlipForCoord(pickup.x, pickup.y, pickup.z)
        SetBlipSprite(CharterBlip, 280)
        SetBlipColour(CharterBlip, 5)
        SetBlipScale(CharterBlip, 0.8)
        SetBlipRoute(CharterBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Charter Pickup')
        EndTextCommandSetBlipName(CharterBlip)

        lib.notify({
            title = 'Charter Accepted',
            description = 'Head to the pickup location',
            type = 'success'
        })

        -- Start pickup monitoring
        MonitorCharterPickup()
    else
        lib.notify({ title = 'Charter', description = 'Failed to accept charter', type = 'error' })
    end
end

-- =====================================
-- CHARTER PICKUP/DROPOFF
-- =====================================

function MonitorCharterPickup()
    CreateThread(function()
        local pickup = json.decode(ActiveCharter.pickup_coords)
        local pickupVec = vector3(pickup.x, pickup.y, pickup.z)

        while ActiveCharter and ActiveCharter.status == 'accepted' do
            Wait(1000)

            local playerPos = GetEntityCoords(PlayerPedId())
            local dist = #(playerPos - pickupVec)

            if dist < 50.0 and CurrentPlane and DoesEntityExist(CurrentPlane) then
                -- Near pickup with plane
                if dist < 10.0 then
                    lib.notify({
                        title = 'Charter',
                        description = 'Client boarding...',
                        type = 'inform'
                    })

                    Wait(5000) -- Simulate boarding

                    -- Update to in progress
                    TriggerServerEvent('dps-airlines:server:charterPickedUp', ActiveCharter.id)
                    ActiveCharter.status = 'inprogress'

                    -- Set dropoff waypoint
                    local dropoff = json.decode(ActiveCharter.dropoff_coords)

                    if CharterBlip then
                        RemoveBlip(CharterBlip)
                    end

                    CharterBlip = AddBlipForCoord(dropoff.x, dropoff.y, dropoff.z)
                    SetBlipSprite(CharterBlip, 280)
                    SetBlipColour(CharterBlip, 2)
                    SetBlipScale(CharterBlip, 0.8)
                    SetBlipRoute(CharterBlip, true)
                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentString('Charter Dropoff')
                    EndTextCommandSetBlipName(CharterBlip)

                    SetNewWaypoint(dropoff.x, dropoff.y)

                    lib.notify({
                        title = 'Charter',
                        description = 'Client aboard! Head to destination',
                        type = 'success'
                    })

                    MonitorCharterDropoff()
                    break
                end
            end
        end
    end)
end

function MonitorCharterDropoff()
    CreateThread(function()
        local dropoff = json.decode(ActiveCharter.dropoff_coords)
        local dropoffVec = vector3(dropoff.x, dropoff.y, dropoff.z)

        while ActiveCharter and ActiveCharter.status == 'inprogress' do
            Wait(1000)

            local playerPos = GetEntityCoords(PlayerPedId())
            local dist = #(playerPos - dropoffVec)

            if dist < 50.0 and CurrentPlane and DoesEntityExist(CurrentPlane) then
                if dist < 15.0 and GetEntitySpeed(CurrentPlane) < 5.0 then
                    -- Landed at destination
                    lib.notify({
                        title = 'Charter',
                        description = 'Client disembarking...',
                        type = 'inform'
                    })

                    Wait(3000)

                    -- Complete charter
                    TriggerServerEvent('dps-airlines:server:completeCharter', ActiveCharter.id)

                    if CharterBlip then
                        RemoveBlip(CharterBlip)
                        CharterBlip = nil
                    end

                    lib.notify({
                        title = 'Charter Complete',
                        description = string.format('Earned $%d', ActiveCharter.fee),
                        type = 'success',
                        duration = 5000
                    })

                    ActiveCharter = nil
                    break
                end
            end
        end
    end)
end

-- =====================================
-- PLAYER CHARTER REQUEST (For Clients)
-- =====================================

RegisterNetEvent('dps-airlines:client:openCharterRequest', function()
    -- This allows any player to request a charter
    local input = lib.inputDialog('Request Private Charter', {
        {
            type = 'input',
            label = 'Pickup Location (or "current" for here)',
            default = 'current',
            required = true
        },
        {
            type = 'input',
            label = 'Destination',
            description = 'Enter airport name or coordinates',
            required = true
        }
    })

    if not input then return end

    local pickup = input[1]
    local destination = input[2]

    -- Get pickup coords
    local pickupCoords
    if pickup:lower() == 'current' then
        local pos = GetEntityCoords(PlayerPedId())
        pickupCoords = { x = pos.x, y = pos.y, z = pos.z }
    else
        -- Try to parse as airport
        local airport = Locations.Airports[pickup:lower()]
        if airport then
            pickupCoords = { x = airport.coords.x, y = airport.coords.y, z = airport.coords.z }
        end
    end

    -- Get destination coords
    local destCoords
    local airport = Locations.Airports[destination:lower()]
    if airport then
        destCoords = { x = airport.coords.x, y = airport.coords.y, z = airport.coords.z }
    end

    if not pickupCoords or not destCoords then
        lib.notify({ title = 'Charter', description = 'Invalid location', type = 'error' })
        return
    end

    -- Calculate fee
    local distance = #(vector3(pickupCoords.x, pickupCoords.y, pickupCoords.z) - vector3(destCoords.x, destCoords.y, destCoords.z)) / 1000
    local fee = Config.Charter.baseFee + math.floor(distance * Config.Charter.perKmFee)

    local confirm = lib.alertDialog({
        header = 'Confirm Charter Request',
        content = string.format([[
**Distance:** %.1f km
**Total Fee:** $%d

A pilot will be notified of your request.
        ]], distance, fee),
        centered = true,
        cancel = true
    })

    if confirm == 'confirm' then
        TriggerServerEvent('dps-airlines:server:requestCharter', {
            pickup = pickupCoords,
            dropoff = destCoords,
            fee = fee
        })
    end
end)

-- =====================================
-- CLEANUP
-- =====================================

function CancelCharter()
    if ActiveCharter then
        TriggerServerEvent('dps-airlines:server:cancelCharter', ActiveCharter.id)
        ActiveCharter = nil
    end

    if CharterBlip then
        RemoveBlip(CharterBlip)
        CharterBlip = nil
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        CancelCharter()
    end
end)

-- =====================================
-- EXPORTS
-- =====================================

exports('GetActiveCharter', function() return ActiveCharter end)
exports('CancelCharter', CancelCharter)
