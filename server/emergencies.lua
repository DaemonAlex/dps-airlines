-- Emergency Scenarios Server Handler
local QBCore = exports['qb-core']:GetCoreObject()

-- =====================================
-- EMERGENCY EVENTS
-- =====================================

RegisterNetEvent('dps-airlines:server:emergencyStarted', function(emergencyType)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local charinfo = Player.PlayerData.charinfo

    -- Log the emergency start
    if Config.Debug then
        print(string.format('[dps-airlines] %s %s experienced %s emergency',
            charinfo.firstname, charinfo.lastname, emergencyType))
    end

    -- Notify bosses/dispatchers
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.job.name == Config.Job then
            if player.PlayerData.job.grade.level >= Config.BossGrade then
                TriggerClientEvent('ox_lib:notify', player.PlayerData.source, {
                    title = 'EMERGENCY ALERT',
                    description = string.format('%s %s: %s',
                        charinfo.firstname, charinfo.lastname, emergencyType:upper():gsub('_', ' ')),
                    type = 'error',
                    duration = 10000
                })
            end
        end
    end
end)

RegisterNetEvent('dps-airlines:server:emergencyResolved', function(emergencyType, success, repChange)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Update pilot stats
    if success then
        MySQL.update.await([[
            UPDATE airline_pilot_stats SET
                emergencies_handled = COALESCE(emergencies_handled, 0) + 1,
                reputation = reputation + ?
            WHERE citizenid = ?
        ]], { math.abs(repChange or 5), citizenid })

        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Reputation',
            description = string.format('+%d reputation for handling emergency', math.abs(repChange or 5)),
            type = 'success'
        })
    else
        MySQL.update.await([[
            UPDATE airline_pilot_stats SET
                incidents = COALESCE(incidents, 0) + 1,
                reputation = GREATEST(0, reputation + ?)
            WHERE citizenid = ?
        ]], { repChange or -10, citizenid })

        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Reputation',
            description = string.format('%d reputation for incident', repChange or -10),
            type = 'error'
        })
    end

    -- Log to database
    MySQL.insert.await([[
        INSERT INTO airline_incidents (citizenid, incident_type, success, reputation_change, created_at)
        VALUES (?, ?, ?, ?, NOW())
    ]], { citizenid, emergencyType, success, repChange or 0 })
end)

RegisterNetEvent('dps-airlines:server:planeCrashed', function()
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid

    -- Heavy reputation penalty
    MySQL.update.await([[
        UPDATE airline_pilot_stats SET
            crashes = COALESCE(crashes, 0) + 1,
            reputation = GREATEST(0, reputation - 25)
        WHERE citizenid = ?
    ]], { citizenid })

    -- Log crash
    MySQL.insert.await([[
        INSERT INTO airline_incidents (citizenid, incident_type, success, reputation_change, created_at)
        VALUES (?, 'crash', 0, -25, NOW())
    ]], { citizenid })

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'CRASH',
        description = '-25 reputation. Your safety record has been affected.',
        type = 'error',
        duration = 10000
    })
end)

-- =====================================
-- INCIDENT QUERIES
-- =====================================

lib.callback.register('dps-airlines:server:getIncidentHistory', function(source, targetCitizenid)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return {} end

    local citizenid = targetCitizenid or Player.PlayerData.citizenid

    -- Only allow viewing own incidents or if boss
    if citizenid ~= Player.PlayerData.citizenid then
        if Player.PlayerData.job.name ~= Config.Job or Player.PlayerData.job.grade.level < Config.BossGrade then
            return {}
        end
    end

    local incidents = MySQL.query.await([[
        SELECT * FROM airline_incidents
        WHERE citizenid = ?
        ORDER BY created_at DESC
        LIMIT 50
    ]], { citizenid })

    return incidents or {}
end)

print('^2[dps-airlines]^7 Emergency Server module loaded')
