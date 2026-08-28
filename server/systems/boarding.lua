-- Server relay for attendant group-boarding (2026-08-26).
-- The attendant triggers this; the server finds players near the aircraft and
-- tells each to seat themselves into a free cabin seat (client does the actual
-- SetPedIntoVehicle so seat selection stays client-authoritative).
RegisterNetEvent('dps-airlines:server:boardNearbyPassengers', function(netId)
    local src = source
    local ok = Validation.Check(src, { employee = true, onDuty = true })
    if not ok then return end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local vcoords = GetEntityCoords(veh)

    for _, pid in ipairs(GetPlayers()) do
        pid = tonumber(pid)
        if pid and pid ~= src then
            local ped = GetPlayerPed(pid)
            if ped and ped ~= 0 and #(GetEntityCoords(ped) - vcoords) <= 15.0 then
                TriggerClientEvent('dps-airlines:client:boardIntoPlane', pid, netId)
            end
        end
    end
end)
