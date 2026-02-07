Bridge = Bridge or {}
Bridge.Framework = nil
Bridge.FrameworkName = ''

local function DetectFramework()
    if GetResourceState('qbx_core') == 'started' then
        return 'qbox'
    elseif GetResourceState('qb-core') == 'started' then
        return 'qbcore'
    elseif GetResourceState('es_extended') == 'started' then
        return 'esx'
    end
    return nil
end

local framework = DetectFramework()

if not framework then
    print('^1[DPS-Airlines] ERROR: No supported framework detected! Requires qb-core, qbx_core, or es_extended.^0')
    return
end

Bridge.FrameworkName = framework
print('^2[DPS-Airlines] Detected framework: ' .. framework .. '^0')

-- Shared utilities available on both client and server

---Get the airline job name
---@return string
function Bridge.GetJobName()
    return Config.Job
end

-- ============================================================================
-- SERVER SIDE
-- ============================================================================
if IsDuplicityVersion() then

    if framework == 'qbcore' then
        local QBCore = exports['qb-core']:GetCoreObject()

        ---@param source number
        ---@return table|nil
        function Bridge.GetPlayer(source)
            local player = QBCore.Functions.GetPlayer(source)
            if not player then return nil end
            local charInfo = player.PlayerData.charinfo or {}
            return {
                source = source,
                identifier = player.PlayerData.citizenid,
                firstName = charInfo.firstname or '',
                lastName = charInfo.lastname or '',
                fullName = (charInfo.firstname or '') .. ' ' .. (charInfo.lastname or ''),
                phone = charInfo.phone or '',
                job = {
                    name = player.PlayerData.job.name,
                    grade = player.PlayerData.job.grade.level,
                    gradeName = player.PlayerData.job.grade.name,
                    onDuty = player.PlayerData.job.onduty,
                },
                addMoney = function(moneyType, amount, reason)
                    player.Functions.AddMoney(moneyType, amount, reason)
                end,
                removeMoney = function(moneyType, amount, reason)
                    player.Functions.RemoveMoney(moneyType, amount, reason)
                end,
                getMoney = function(moneyType)
                    return player.Functions.GetMoney(moneyType)
                end,
                setJob = function(job, grade)
                    player.Functions.SetJob(job, grade)
                end,
                setJobDuty = function(onDuty)
                    player.Functions.SetJobDuty(onDuty)
                end,
                _raw = player,
            }
        end

        ---@param identifier string
        ---@return table|nil
        function Bridge.GetPlayerByIdentifier(identifier)
            local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
            if not player then return nil end
            return Bridge.GetPlayer(player.PlayerData.source)
        end

        ---@return table[]
        function Bridge.GetPlayers()
            local players = {}
            local qbPlayers = QBCore.Functions.GetQBPlayers()
            for src, _ in pairs(qbPlayers) do
                local wrapped = Bridge.GetPlayer(src)
                if wrapped then
                    players[#players + 1] = wrapped
                end
            end
            return players
        end

        function Bridge.GetSocietyBalance(account)
            local balance = 0
            local success, result = pcall(function()
                return exports['qb-management']:GetAccount(account)
            end)
            if success and result then
                balance = result
            end
            return balance
        end

        function Bridge.AddSocietyMoney(account, amount)
            local success = pcall(function()
                exports['qb-management']:AddMoney(account, amount)
            end)
            return success
        end

        function Bridge.RemoveSocietyMoney(account, amount)
            local success = pcall(function()
                exports['qb-management']:RemoveMoney(account, amount)
            end)
            return success
        end

        function Bridge.CreateCallback(name, cb)
            QBCore.Functions.CreateCallback(name, cb)
        end

    elseif framework == 'qbox' then

        ---@param source number
        ---@return table|nil
        function Bridge.GetPlayer(source)
            local player = exports.qbx_core:GetPlayer(source)
            if not player then return nil end
            local charInfo = player.PlayerData.charinfo or {}
            return {
                source = source,
                identifier = player.PlayerData.citizenid,
                firstName = charInfo.firstname or '',
                lastName = charInfo.lastname or '',
                fullName = (charInfo.firstname or '') .. ' ' .. (charInfo.lastname or ''),
                phone = charInfo.phone or '',
                job = {
                    name = player.PlayerData.job.name,
                    grade = player.PlayerData.job.grade.level,
                    gradeName = player.PlayerData.job.grade.name,
                    onDuty = player.PlayerData.job.onduty,
                },
                addMoney = function(moneyType, amount, reason)
                    player.Functions.AddMoney(moneyType, amount, reason)
                end,
                removeMoney = function(moneyType, amount, reason)
                    player.Functions.RemoveMoney(moneyType, amount, reason)
                end,
                getMoney = function(moneyType)
                    return player.Functions.GetMoney(moneyType)
                end,
                setJob = function(job, grade)
                    player.Functions.SetJob(job, grade)
                end,
                setJobDuty = function(onDuty)
                    player.Functions.SetJobDuty(onDuty)
                end,
                _raw = player,
            }
        end

        ---@param identifier string
        ---@return table|nil
        function Bridge.GetPlayerByIdentifier(identifier)
            local player = exports.qbx_core:GetPlayerByCitizenId(identifier)
            if not player then return nil end
            return Bridge.GetPlayer(player.PlayerData.source)
        end

        ---@return table[]
        function Bridge.GetPlayers()
            local players = {}
            local qbPlayers = exports.qbx_core:GetQBPlayers()
            for src, _ in pairs(qbPlayers) do
                local wrapped = Bridge.GetPlayer(src)
                if wrapped then
                    players[#players + 1] = wrapped
                end
            end
            return players
        end

        function Bridge.GetSocietyBalance(account)
            local balance = 0
            local success, result = pcall(function()
                return exports['qb-management']:GetAccount(account)
            end)
            if success and result then
                balance = result
            end
            return balance
        end

        function Bridge.AddSocietyMoney(account, amount)
            local success = pcall(function()
                exports['qb-management']:AddMoney(account, amount)
            end)
            return success
        end

        function Bridge.RemoveSocietyMoney(account, amount)
            local success = pcall(function()
                exports['qb-management']:RemoveMoney(account, amount)
            end)
            return success
        end

        function Bridge.CreateCallback(name, cb)
            lib.callback.register(name, cb)
        end

    elseif framework == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()

        ---@param source number
        ---@return table|nil
        function Bridge.GetPlayer(source)
            local xPlayer = ESX.GetPlayerFromId(source)
            if not xPlayer then return nil end
            return {
                source = source,
                identifier = xPlayer.getIdentifier(),
                firstName = xPlayer.getName() or '',
                lastName = '',
                fullName = xPlayer.getName() or '',
                phone = '',
                job = {
                    name = xPlayer.getJob().name,
                    grade = xPlayer.getJob().grade,
                    gradeName = xPlayer.getJob().grade_label or '',
                    onDuty = true, -- ESX doesn't have native duty toggle
                },
                addMoney = function(moneyType, amount, reason)
                    if moneyType == 'bank' then
                        xPlayer.addAccountMoney('bank', amount, reason)
                    else
                        xPlayer.addMoney(amount, reason)
                    end
                end,
                removeMoney = function(moneyType, amount, reason)
                    if moneyType == 'bank' then
                        xPlayer.removeAccountMoney('bank', amount, reason)
                    else
                        xPlayer.removeMoney(amount, reason)
                    end
                end,
                getMoney = function(moneyType)
                    if moneyType == 'bank' then
                        return xPlayer.getAccount('bank').money
                    end
                    return xPlayer.getMoney()
                end,
                setJob = function(job, grade)
                    xPlayer.setJob(job, grade)
                end,
                setJobDuty = function(onDuty)
                    -- ESX doesn't have native duty; use metadata or custom implementation
                end,
                _raw = xPlayer,
            }
        end

        ---@param identifier string
        ---@return table|nil
        function Bridge.GetPlayerByIdentifier(identifier)
            local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
            if not xPlayer then return nil end
            return Bridge.GetPlayer(xPlayer.source)
        end

        ---@return table[]
        function Bridge.GetPlayers()
            local players = {}
            local xPlayers = ESX.GetExtendedPlayers()
            for _, xPlayer in ipairs(xPlayers) do
                local wrapped = Bridge.GetPlayer(xPlayer.source)
                if wrapped then
                    players[#players + 1] = wrapped
                end
            end
            return players
        end

        function Bridge.GetSocietyBalance(account)
            local balance = 0
            local success = pcall(function()
                TriggerEvent('esx_addonaccount:getSharedAccount', account, function(sa)
                    if sa then balance = sa.money end
                end)
            end)
            return balance
        end

        function Bridge.AddSocietyMoney(account, amount)
            local success = pcall(function()
                TriggerEvent('esx_addonaccount:getSharedAccount', account, function(sa)
                    if sa then sa.addMoney(amount) end
                end)
            end)
            return success
        end

        function Bridge.RemoveSocietyMoney(account, amount)
            local success = pcall(function()
                TriggerEvent('esx_addonaccount:getSharedAccount', account, function(sa)
                    if sa then sa.removeMoney(amount) end
                end)
            end)
            return success
        end

        function Bridge.CreateCallback(name, cb)
            ESX.RegisterServerCallback(name, cb)
        end
    end

-- ============================================================================
-- CLIENT SIDE
-- ============================================================================
else

    if framework == 'qbcore' then
        local QBCore = exports['qb-core']:GetCoreObject()

        ---@return table
        function Bridge.GetPlayerData()
            local pd = QBCore.Functions.GetPlayerData()
            if not pd then return {} end
            local charInfo = pd.charinfo or {}
            return {
                identifier = pd.citizenid,
                firstName = charInfo.firstname or '',
                lastName = charInfo.lastname or '',
                fullName = (charInfo.firstname or '') .. ' ' .. (charInfo.lastname or ''),
                phone = charInfo.phone or '',
                job = {
                    name = pd.job and pd.job.name or '',
                    grade = pd.job and pd.job.grade and pd.job.grade.level or 0,
                    gradeName = pd.job and pd.job.grade and pd.job.grade.name or '',
                    onDuty = pd.job and pd.job.onduty or false,
                },
            }
        end

        Bridge.Events = {
            playerLoaded = 'QBCore:Client:OnPlayerLoaded',
            playerUnloaded = 'QBCore:Client:OnPlayerUnload',
            jobUpdated = 'QBCore:Client:OnJobUpdate',
        }

        function Bridge.TriggerCallback(name, cb, ...)
            QBCore.Functions.TriggerCallback(name, cb, ...)
        end

        function Bridge.Notify(msg, notifType, duration)
            QBCore.Functions.Notify(msg, notifType, duration)
        end

    elseif framework == 'qbox' then

        ---@return table
        function Bridge.GetPlayerData()
            local pd = exports.qbx_core:GetPlayerData()
            if not pd then return {} end
            local charInfo = pd.charinfo or {}
            return {
                identifier = pd.citizenid,
                firstName = charInfo.firstname or '',
                lastName = charInfo.lastname or '',
                fullName = (charInfo.firstname or '') .. ' ' .. (charInfo.lastname or ''),
                phone = charInfo.phone or '',
                job = {
                    name = pd.job and pd.job.name or '',
                    grade = pd.job and pd.job.grade and pd.job.grade.level or 0,
                    gradeName = pd.job and pd.job.grade and pd.job.grade.name or '',
                    onDuty = pd.job and pd.job.onduty or false,
                },
            }
        end

        Bridge.Events = {
            playerLoaded = 'QBCore:Client:OnPlayerLoaded',
            playerUnloaded = 'QBCore:Client:OnPlayerUnload',
            jobUpdated = 'QBCore:Client:OnJobUpdate',
        }

        function Bridge.TriggerCallback(name, cb, ...)
            lib.callback(name, false, cb, ...)
        end

        function Bridge.Notify(msg, notifType, duration)
            lib.notify({ description = msg, type = notifType, duration = duration })
        end

    elseif framework == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()

        ---@return table
        function Bridge.GetPlayerData()
            local pd = ESX.GetPlayerData()
            if not pd then return {} end
            return {
                identifier = pd.identifier or '',
                firstName = pd.firstName or pd.name or '',
                lastName = pd.lastName or '',
                fullName = (pd.firstName or pd.name or '') .. ' ' .. (pd.lastName or ''),
                phone = '',
                job = {
                    name = pd.job and pd.job.name or '',
                    grade = pd.job and pd.job.grade or 0,
                    gradeName = pd.job and pd.job.grade_label or '',
                    onDuty = true,
                },
            }
        end

        Bridge.Events = {
            playerLoaded = 'esx:playerLoaded',
            playerUnloaded = 'esx:onPlayerLogout',
            jobUpdated = 'esx:setJob',
        }

        function Bridge.TriggerCallback(name, cb, ...)
            ESX.TriggerServerCallback(name, cb, ...)
        end

        function Bridge.Notify(msg, notifType, duration)
            lib.notify({ description = msg, type = notifType, duration = duration })
        end
    end
end
