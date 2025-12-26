-- Pilot Logbook NUI Handler
local QBCore = exports['qb-core']:GetCoreObject()

local LogbookOpen = false

-- =====================================
-- OPEN LOGBOOK NUI
-- =====================================

function OpenLogbookNUI()
    if LogbookOpen then return end

    -- Fetch pilot data
    local stats = lib.callback.await('dps-airlines:server:getPilotDetailedStats', false)
    local flights = lib.callback.await('dps-airlines:server:getPilotLogbook', false, nil, 50, 0)
    local incidents = lib.callback.await('dps-airlines:server:getPilotIncidents', false)

    if not stats then
        lib.notify({ title = 'Logbook', description = 'No pilot data found', type = 'error' })
        return
    end

    -- Get pilot name
    local Player = QBCore.Functions.GetPlayerData()
    stats.name = Player.charinfo.firstname .. ' ' .. Player.charinfo.lastname

    LogbookOpen = true

    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'openLogbook',
        stats = stats,
        flights = flights,
        incidents = incidents
    })
end

-- =====================================
-- CLOSE LOGBOOK NUI
-- =====================================

RegisterNUICallback('closeLogbook', function(data, cb)
    CloseLogbookNUI()
    cb('ok')
end)

function CloseLogbookNUI()
    if not LogbookOpen then return end

    LogbookOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'closeLogbook'
    })
end

-- =====================================
-- COMMANDS & EXPORTS
-- =====================================

RegisterCommand('logbook', function()
    if not PlayerData.job or PlayerData.job.name ~= Config.Job then
        lib.notify({ title = 'Logbook', description = 'You are not a pilot', type = 'error' })
        return
    end

    OpenLogbookNUI()
end, false)

exports('OpenLogbookNUI', OpenLogbookNUI)
exports('CloseLogbookNUI', CloseLogbookNUI)
exports('IsLogbookOpen', function() return LogbookOpen end)

-- =====================================
-- KEYBIND (Optional)
-- =====================================

if Config.LogbookKeybind then
    RegisterKeyMapping('logbook', 'Open Pilot Logbook', 'keyboard', Config.LogbookKeybind)
end

print('^2[dps-airlines]^7 Logbook NUI module loaded')
