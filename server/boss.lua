-- Boss Management Server
local QBCore = exports['qb-core']:GetCoreObject()

-- =====================================
-- BOSS MENU
-- =====================================

lib.callback.register('dps-airlines:server:getBossData', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return nil end

    if Player.PlayerData.job.name ~= Config.Job or Player.PlayerData.job.grade.level < Config.BossGrade then
        return nil
    end

    -- Get society balance (if using qb-management)
    local societyBalance = 0
    local success, balance = pcall(function()
        return exports['qb-management']:GetAccount('pilot')
    end)
    if success then
        societyBalance = balance or 0
    end

    -- Get employee list
    local employees = MySQL.query.await([[
        SELECT
            p.citizenid,
            p.charinfo,
            p.job,
            COALESCE(s.total_flights, 0) as flights,
            COALESCE(s.reputation, 0) as reputation
        FROM players p
        LEFT JOIN airline_pilot_stats s ON p.citizenid = s.citizenid
        WHERE JSON_EXTRACT(p.job, '$.name') = 'pilot'
    ]])

    -- Parse employee data
    local parsedEmployees = {}
    for _, emp in ipairs(employees or {}) do
        local charinfo = json.decode(emp.charinfo)
        local job = json.decode(emp.job)

        table.insert(parsedEmployees, {
            citizenid = emp.citizenid,
            name = string.format('%s %s', charinfo.firstname, charinfo.lastname),
            grade = job.grade.level,
            gradeName = job.grade.name,
            flights = emp.flights,
            reputation = emp.reputation
        })
    end

    -- Get company stats
    local stats = MySQL.single.await([[
        SELECT
            COUNT(*) as total_flights,
            SUM(passengers) as total_passengers,
            SUM(cargo_weight) as total_cargo,
            SUM(payment) as total_revenue
        FROM airline_flights
        WHERE status = 'arrived'
        AND completed_at > DATE_SUB(NOW(), INTERVAL 7 DAY)
    ]])

    return {
        balance = societyBalance,
        employees = parsedEmployees,
        weeklyStats = stats or {}
    }
end)

-- =====================================
-- EMPLOYEE MANAGEMENT
-- =====================================

RegisterNetEvent('dps-airlines:server:hireEmployee', function(targetId)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    local Target = QBCore.Functions.GetPlayer(targetId)

    if not Player or not Target then return end

    if Player.PlayerData.job.name ~= Config.Job or Player.PlayerData.job.grade.level < Config.BossGrade then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Airlines',
            description = 'You do not have permission',
            type = 'error'
        })
        return
    end

    Target.Functions.SetJob('pilot', 0)

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Airlines',
        description = 'Employee hired',
        type = 'success'
    })

    TriggerClientEvent('ox_lib:notify', targetId, {
        title = 'Airlines',
        description = 'You have been hired as a pilot!',
        type = 'success'
    })
end)

RegisterNetEvent('dps-airlines:server:fireEmployee', function(citizenid)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then return end

    if Player.PlayerData.job.name ~= Config.Job or Player.PlayerData.job.grade.level < Config.BossGrade then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Airlines',
            description = 'You do not have permission',
            type = 'error'
        })
        return
    end

    -- Get target player
    local Target = QBCore.Functions.GetPlayerByCitizenId(citizenid)

    if Target then
        Target.Functions.SetJob('unemployed', 0)
        TriggerClientEvent('ox_lib:notify', Target.PlayerData.source, {
            title = 'Airlines',
            description = 'You have been fired',
            type = 'error'
        })
    else
        -- Update offline player
        MySQL.update.await([[
            UPDATE players SET job = ? WHERE citizenid = ?
        ]], {
            json.encode({
                name = 'unemployed',
                label = 'Civilian',
                payment = 10,
                onduty = false,
                isboss = false,
                grade = { name = 'Freelancer', level = 0 }
            }),
            citizenid
        })
    end

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Airlines',
        description = 'Employee terminated',
        type = 'success'
    })
end)

RegisterNetEvent('dps-airlines:server:promoteEmployee', function(citizenid, newGrade)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then return end

    if Player.PlayerData.job.name ~= Config.Job or Player.PlayerData.job.grade.level < Config.BossGrade then
        return
    end

    local Target = QBCore.Functions.GetPlayerByCitizenId(citizenid)

    if Target then
        Target.Functions.SetJob('pilot', newGrade)
        TriggerClientEvent('ox_lib:notify', Target.PlayerData.source, {
            title = 'Airlines',
            description = 'You have been promoted!',
            type = 'success'
        })
    end

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Airlines',
        description = 'Employee promoted',
        type = 'success'
    })
end)

-- =====================================
-- SOCIETY MANAGEMENT
-- =====================================

RegisterNetEvent('dps-airlines:server:withdrawSociety', function(amount)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then return end

    if Player.PlayerData.job.name ~= Config.Job or Player.PlayerData.job.grade.level < Config.BossGrade then
        return
    end

    local success = exports['qb-management']:RemoveMoney('pilot', amount)

    if success then
        Player.Functions.AddMoney('cash', amount, 'society-withdrawal')
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Airlines',
            description = string.format('Withdrew $%d from company', amount),
            type = 'success'
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Airlines',
            description = 'Insufficient company funds',
            type = 'error'
        })
    end
end)

RegisterNetEvent('dps-airlines:server:depositSociety', function(amount)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then return end

    if Player.PlayerData.job.name ~= Config.Job or Player.PlayerData.job.grade.level < Config.BossGrade then
        return
    end

    if Player.Functions.RemoveMoney('cash', amount, 'society-deposit') then
        exports['qb-management']:AddMoney('pilot', amount)
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Airlines',
            description = string.format('Deposited $%d to company', amount),
            type = 'success'
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Airlines',
            description = 'Insufficient funds',
            type = 'error'
        })
    end
end)

-- =====================================
-- MAINTENANCE HISTORY
-- =====================================

lib.callback.register('dps-airlines:server:getMaintenanceHistory', function(source)
    local history = MySQL.query.await([[
        SELECT * FROM airline_maintenance
        WHERE owned_by = 'company'
        ORDER BY last_service DESC
    ]])

    return history or {}
end)

print('^2[dps-airlines]^7 Boss module loaded')
