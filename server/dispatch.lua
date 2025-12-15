-- Dispatch System Server
local QBCore = exports['qb-core']:GetCoreObject()

-- =====================================
-- DISPATCH CALLBACKS
-- =====================================

lib.callback.register('dps-airlines:server:getDispatchQueue', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return {} end

    if Player.PlayerData.job.name ~= Config.Job then
        return {}
    end

    local dispatches = MySQL.query.await([[
        SELECT d.*,
            (SELECT label FROM JSON_TABLE('[' || ? || ']', '$[*]' COLUMNS(name VARCHAR(50) PATH '$.name', label VARCHAR(100) PATH '$.label')) AS airports WHERE name = d.from_airport) as from_label,
            (SELECT label FROM JSON_TABLE('[' || ? || ']', '$[*]' COLUMNS(name VARCHAR(50) PATH '$.name', label VARCHAR(100) PATH '$.label')) AS airports WHERE name = d.to_airport) as to_label
        FROM airline_dispatch d
        WHERE d.status = 'available'
        AND (d.expires_at IS NULL OR d.expires_at > NOW())
        ORDER BY
            CASE d.priority
                WHEN 'urgent' THEN 1
                WHEN 'high' THEN 2
                WHEN 'normal' THEN 3
                ELSE 4
            END,
            d.created_at ASC
        LIMIT 20
    ]])

    -- Add labels from Locations (since JSON_TABLE might not work in all MySQL versions)
    for _, dispatch in ipairs(dispatches or {}) do
        local fromAirport = Locations.Airports[dispatch.from_airport]
        local toAirport = Locations.Airports[dispatch.to_airport]
        dispatch.from_label = fromAirport and fromAirport.label or dispatch.from_airport
        dispatch.to_label = toAirport and toAirport.label or dispatch.to_airport
    end

    return dispatches or {}
end)

-- =====================================
-- MANUAL DISPATCH CREATION (Boss only)
-- =====================================

RegisterNetEvent('dps-airlines:server:createDispatch', function(data)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then return end

    if Player.PlayerData.job.name ~= Config.Job or Player.PlayerData.job.grade.level < Config.BossGrade then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Dispatch',
            description = 'You do not have permission',
            type = 'error'
        })
        return
    end

    local fromAirport = Locations.Airports[data.from]
    local toAirport = Locations.Airports[data.to]

    if not fromAirport or not toAirport then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Dispatch',
            description = 'Invalid airports',
            type = 'error'
        })
        return
    end

    -- Calculate payment
    local basePay = 100 + (toAirport.distance or 5) * 20
    local priorityMultiplier = data.priority == 'urgent' and 1.5 or data.priority == 'high' and 1.3 or 1.0
    local payment = math.floor(basePay * priorityMultiplier)

    if data.flightType == 'passenger' then
        payment = payment + (data.passengers * Config.Passengers.payPerPassenger)
    elseif data.flightType == 'cargo' then
        payment = payment + math.floor(data.cargoWeight * Config.Cargo.payPerKg)
    end

    MySQL.insert.await([[
        INSERT INTO airline_dispatch
        (flight_type, from_airport, to_airport, priority, plane_required, passengers, cargo_weight, payment, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'available')
    ]], {
        data.flightType,
        data.from,
        data.to,
        data.priority,
        data.planeRequired,
        data.passengers or 0,
        data.cargoWeight or 0,
        payment
    })

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Dispatch',
        description = 'Flight dispatch created',
        type = 'success'
    })

    -- Notify all on-duty pilots
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.job.name == Config.Job and player.PlayerData.job.onduty then
            TriggerClientEvent('dps-airlines:client:newDispatch', player.PlayerData.source, {
                from_label = fromAirport.label,
                to_label = toAirport.label,
                payment = payment
            })
        end
    end
end)

-- =====================================
-- AUTO-ASSIGN SYSTEM
-- =====================================

if Config.Dispatch.autoAssign then
    CreateThread(function()
        while true do
            Wait(30000) -- Check every 30 seconds

            -- Get available dispatches
            local dispatches = MySQL.query.await([[
                SELECT * FROM airline_dispatch
                WHERE status = 'available'
                AND assigned_to IS NULL
                ORDER BY
                    CASE priority
                        WHEN 'urgent' THEN 1
                        WHEN 'high' THEN 2
                        ELSE 3
                    END
                LIMIT 5
            ]])

            if dispatches and #dispatches > 0 then
                -- Get available pilots
                local players = QBCore.Functions.GetQBPlayers()
                local availablePilots = {}

                for _, player in pairs(players) do
                    if player.PlayerData.job.name == Config.Job and player.PlayerData.job.onduty then
                        -- Check if pilot has capacity
                        local activeCount = MySQL.scalar.await([[
                            SELECT COUNT(*) FROM airline_dispatch
                            WHERE assigned_to = ? AND status = 'assigned'
                        ]], { player.PlayerData.citizenid })

                        if activeCount < Config.Dispatch.maxActiveFlights then
                            table.insert(availablePilots, player)
                        end
                    end
                end

                -- Auto-assign dispatches to available pilots
                for i, dispatch in ipairs(dispatches) do
                    local pilot = availablePilots[((i - 1) % #availablePilots) + 1]
                    if pilot then
                        MySQL.update.await('UPDATE airline_dispatch SET assigned_to = ?, status = ? WHERE id = ?', {
                            pilot.PlayerData.citizenid,
                            'assigned',
                            dispatch.id
                        })

                        local fromAirport = Locations.Airports[dispatch.from_airport]
                        local toAirport = Locations.Airports[dispatch.to_airport]

                        TriggerClientEvent('ox_lib:notify', pilot.PlayerData.source, {
                            title = 'Flight Assigned',
                            description = string.format('%s → %s', fromAirport.label, toAirport.label),
                            type = 'inform'
                        })
                    end
                end
            end
        end
    end)
end

-- =====================================
-- DISPATCH STATISTICS
-- =====================================

lib.callback.register('dps-airlines:server:getDispatchStats', function(source)
    local stats = MySQL.single.await([[
        SELECT
            COUNT(CASE WHEN status = 'available' THEN 1 END) as pending,
            COUNT(CASE WHEN status = 'assigned' THEN 1 END) as assigned,
            COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
            COUNT(CASE WHEN status = 'expired' THEN 1 END) as expired
        FROM airline_dispatch
        WHERE created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
    ]])

    return stats or { pending = 0, assigned = 0, completed = 0, expired = 0 }
end)

print('^2[dps-airlines]^7 Dispatch module loaded')
