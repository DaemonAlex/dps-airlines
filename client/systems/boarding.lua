-- Passenger cabin boarding (2026-08-26)
-- Interior planes (e145, l650, ...) have walkable cabins with real seats, but
-- GTA routes every entry point through a single front door bone, so cabin seats
-- are unreachable by walking up. This seats a player DIRECTLY into a free cabin
-- seat via SetPedIntoVehicle, bypassing the door/entry system entirely.

local PLANE_CLASS = 16
local MIN_BUS_SEATS = 6  -- buses/coaches: board any vehicle this size, whatever its class

-- Is this a passenger transport a player can board (plane or bus/coach)?
local function IsBoardableTransport(veh)
    if GetVehicleClass(veh) == PLANE_CLASS then return true end
    local seats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
    return seats and seats >= MIN_BUS_SEATS
end

-- Free passenger cabin seat, skipping driver (-1) and co-pilot (0).
-- Returns a seat index >= 1, or nil if the cabin is full / not multi-seat.
local function GetFreeCabinSeat(veh)
    local seats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
    if not seats or seats < 3 then return nil end        -- needs a cabin beyond pilot+copilot
    for seat = 1, seats - 2 do                            -- seat 1 = first cabin seat
        if IsVehicleSeatFree(veh, seat) then return seat end
    end
    return nil
end

local function BoardAircraft(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if not IsBoardableTransport(veh) then
        Bridge.Notify('You can only board aircraft or buses.', 'error'); return
    end
    if GetPedInVehicleSeat(veh, -1) == 0 and IsVehicleSeatFree(veh, -1) then
        -- no pilot yet: allow, but warn it won't move without one
    end
    if ApplyAircraftInterior then ApplyAircraftInterior(veh) end  -- ensure the cabin exists before seating
    local seat = GetFreeCabinSeat(veh)
    if not seat then
        Bridge.Notify('No free cabin seats on this aircraft.', 'error'); return
    end
    SetPedIntoVehicle(PlayerPedId(), veh, seat)
    Bridge.Notify('Boarded — welcome aboard.', 'success')
end

-- expose for the attendant group-seat below
BoardAircraftLocal = BoardAircraft

-- ox_target: "Board Aircraft" on any plane with a free cabin seat
CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end
    exports.ox_target:addGlobalVehicle({
        {
            name = 'dps_air_board',
            icon = 'fa-solid fa-plane-arrival',
            label = 'Board',
            distance = 4.0,
            canInteract = function(entity)
                if not entity or not DoesEntityExist(entity) then return false end
                if not IsBoardableTransport(entity) then return false end
                return GetFreeCabinSeat(entity) ~= nil
            end,
            onSelect = function(data)
                BoardAircraft(data and data.entity)
            end,
        },
    })
end)

-- /boardplane fallback: board the nearest plane within 12m
RegisterCommand('board', function()
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local veh = GetClosestVehicle(pc.x, pc.y, pc.z, 12.0, 0, 71)
    if veh == 0 then Bridge.Notify('Nothing to board nearby.', 'error'); return end
    BoardAircraft(veh)
end, false)

RegisterCommand('boardplane', function()
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local veh = GetClosestVehicle(pc.x, pc.y, pc.z, 12.0, 0, 71)
    if veh == 0 then Bridge.Notify('No aircraft nearby.', 'error'); return end
    BoardAircraft(veh)
end, false)

-- Attendant group-seat: pull nearby players into free cabin seats of the
-- plane the attendant is standing at. Server relays to each nearby player.
RegisterNetEvent('dps-airlines:client:boardIntoPlane', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then BoardAircraft(veh) end
end)

function SeatNearbyPassengers()
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local veh = GetClosestVehicle(pc.x, pc.y, pc.z, 15.0, 0, 71)
    if veh == 0 or not IsBoardableTransport(veh) then
        Bridge.Notify('Stand next to an aircraft or bus to board passengers.', 'error'); return
    end
    if GetFreeCabinSeat(veh) == nil then
        Bridge.Notify('Cabin is already full.', 'error'); return
    end
    local netId = VehToNet(veh)
    TriggerServerEvent('dps-airlines:server:boardNearbyPassengers', netId)
    Bridge.Notify('Boarding nearby passengers…', 'inform')
end


-- Auto-fit interior aircraft (2026-08-26): the walkable cabin/cockpit on planes
-- like the e145/l650 is shipped as tuning mods. Rather than make players use a
-- mechanic, the airline applies every mod slot to max on spawn, so the interior
-- is always present. Models listed here get the treatment; harmless on shells.
INTERIOR_AIRCRAFT = { e145 = true, l650 = true, a220 = true, a332 = true }

function ApplyAircraftInterior(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local model = GetEntityModel(veh)
    local isInterior = false
    for name in pairs(INTERIOR_AIRCRAFT) do
        if GetHashKey(name) == model then isInterior = true break end
    end
    if not isInterior then return end
    SetVehicleModKit(veh, 0)
    for modType = 0, 49 do
        local n = GetNumVehicleMods(veh, modType)
        if n and n > 0 then SetVehicleMod(veh, modType, n - 1, false) end
    end
    SetVehicleToggleMod(veh, 20, true)  -- some packs put the cabin on a toggle
end

