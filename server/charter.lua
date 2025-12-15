-- Charter System Server
local QBCore = exports['qb-core']:GetCoreObject()

-- =====================================
-- CHARTER REQUESTS
-- =====================================

RegisterNetEvent('dps-airlines:server:requestCharter', function(data)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Check cooldown
    local lastCharter = MySQL.scalar.await([[
        SELECT created_at FROM airline_charters
        WHERE client_citizenid = ? AND status != 'cancelled'
        ORDER BY created_at DESC LIMIT 1
    ]], { citizenid })

    if lastCharter then
        local cooldownEnd = lastCharter + Config.Charter.cooldown
        if os.time() < cooldownEnd then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Charter',
                description = 'Please wait before requesting another charter',
                type = 'error'
            })
            return
        end
    end

    -- Check if player can afford
    local fee = data.fee
    if Player.Functions.GetMoney('cash') < fee and Player.Functions.GetMoney('bank') < fee then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Charter',
            description = 'You cannot afford this charter',
            type = 'error'
        })
        return
    end

    -- Create charter request
    local charterId = MySQL.insert.await([[
        INSERT INTO airline_charters (client_citizenid, pickup_coords, dropoff_coords, fee, status)
        VALUES (?, ?, ?, ?, 'pending')
    ]], {
        citizenid,
        json.encode(data.pickup),
        json.encode(data.dropoff),
        fee
    })

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Charter Requested',
        description = 'A pilot will be notified of your request',
        type = 'success'
    })

    -- Notify online pilots
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.job.name == Config.Job and player.PlayerData.job.onduty then
            TriggerClientEvent('ox_lib:notify', player.PlayerData.source, {
                title = 'New Charter Request',
                description = string.format('Charter #%d - Fee: $%d', charterId, fee),
                type = 'inform'
            })
        end
    end
end)

-- =====================================
-- CHARTER ACCEPTANCE
-- =====================================

lib.callback.register('dps-airlines:server:getAvailableCharters', function(source)
    local charters = MySQL.query.await([[
        SELECT * FROM airline_charters
        WHERE status = 'pending'
        ORDER BY created_at ASC
        LIMIT 10
    ]])

    return charters or {}
end)

lib.callback.register('dps-airlines:server:acceptCharter', function(source, charterId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    local citizenid = Player.PlayerData.citizenid

    -- Check if charter still available
    local charter = MySQL.single.await('SELECT * FROM airline_charters WHERE id = ? AND status = ?', { charterId, 'pending' })

    if not charter then
        return false
    end

    -- Assign to pilot
    MySQL.update.await('UPDATE airline_charters SET pilot_citizenid = ?, status = ? WHERE id = ?', {
        citizenid,
        'accepted',
        charterId
    })

    -- Notify client
    local clientPlayer = QBCore.Functions.GetPlayerByCitizenId(charter.client_citizenid)
    if clientPlayer then
        TriggerClientEvent('ox_lib:notify', clientPlayer.PlayerData.source, {
            title = 'Charter Accepted',
            description = 'A pilot is on the way to pick you up',
            type = 'success'
        })
    end

    charter.status = 'accepted'
    charter.pilot_citizenid = citizenid

    return charter
end)

-- =====================================
-- CHARTER PROGRESS
-- =====================================

RegisterNetEvent('dps-airlines:server:charterPickedUp', function(charterId)
    local source = source

    MySQL.update.await('UPDATE airline_charters SET status = ? WHERE id = ?', { 'inprogress', charterId })

    -- Notify client
    local charter = MySQL.single.await('SELECT client_citizenid FROM airline_charters WHERE id = ?', { charterId })
    if charter then
        local clientPlayer = QBCore.Functions.GetPlayerByCitizenId(charter.client_citizenid)
        if clientPlayer then
            TriggerClientEvent('ox_lib:notify', clientPlayer.PlayerData.source, {
                title = 'Charter',
                description = 'You have been picked up. Enjoy your flight!',
                type = 'success'
            })
        end
    end
end)

RegisterNetEvent('dps-airlines:server:completeCharter', function(charterId)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local charter = MySQL.single.await('SELECT * FROM airline_charters WHERE id = ? AND status = ?', { charterId, 'inprogress' })

    if not charter then return end

    -- Charge client
    local clientPlayer = QBCore.Functions.GetPlayerByCitizenId(charter.client_citizenid)
    if clientPlayer then
        if clientPlayer.Functions.RemoveMoney('bank', charter.fee, 'charter-payment') or
           clientPlayer.Functions.RemoveMoney('cash', charter.fee, 'charter-payment') then

            -- Pay pilot
            Player.Functions.AddMoney(Config.PaymentAccount, charter.fee, 'charter-completion')

            TriggerClientEvent('ox_lib:notify', clientPlayer.PlayerData.source, {
                title = 'Charter Complete',
                description = string.format('You were charged $%d for the charter', charter.fee),
                type = 'inform'
            })
        end
    else
        -- Client offline, pay pilot from system (or handle differently)
        Player.Functions.AddMoney(Config.PaymentAccount, charter.fee, 'charter-completion')
    end

    -- Update charter status
    MySQL.update.await('UPDATE airline_charters SET status = ?, completed_at = NOW() WHERE id = ?', { 'completed', charterId })

    -- Update pilot stats
    local citizenid = Player.PlayerData.citizenid
    MySQL.update.await([[
        UPDATE airline_pilot_stats SET
            total_earnings = total_earnings + ?,
            reputation = reputation + 2
        WHERE citizenid = ?
    ]], { charter.fee, citizenid })
end)

-- =====================================
-- CHARTER CANCELLATION
-- =====================================

RegisterNetEvent('dps-airlines:server:cancelCharter', function(charterId)
    local source = source

    MySQL.update.await('UPDATE airline_charters SET status = ? WHERE id = ?', { 'cancelled', charterId })

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Charter',
        description = 'Charter cancelled',
        type = 'warning'
    })
end)

-- =====================================
-- CLEANUP OLD CHARTERS
-- =====================================

CreateThread(function()
    while true do
        Wait(300000) -- Every 5 minutes

        -- Cancel pending charters older than max wait time
        MySQL.update.await([[
            UPDATE airline_charters
            SET status = 'cancelled'
            WHERE status = 'pending'
            AND created_at < DATE_SUB(NOW(), INTERVAL ? SECOND)
        ]], { Config.Charter.maxWaitTime })
    end
end)

print('^2[dps-airlines]^7 Charter module loaded')
