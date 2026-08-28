-- DPS Airlines v3.0 - Server Main
-- Handles initialization, startup validation, and core server events

local resourceName = GetCurrentResourceName()

-- ============================================================================
-- STARTUP VALIDATION
-- ============================================================================
local function ValidateStartup()
    local errors = {}

    -- Check ox_lib
    if GetResourceState('ox_lib') ~= 'started' then
        errors[#errors + 1] = 'ox_lib is not started'
    end

    -- Check oxmysql
    if GetResourceState('oxmysql') ~= 'started' then
        errors[#errors + 1] = 'oxmysql is not started'
    end

    -- Check bridge loaded
    if not Bridge or not Bridge.FrameworkName then
        errors[#errors + 1] = 'Bridge failed to load - no supported framework detected'
    end

    -- Check database tables
    local requiredTables = {
        'airline_pilot_stats',
        'airline_role_assignments',
        'airline_flights',
        'airline_crew_assignments',
        'airline_ground_tasks',
        'airline_passenger_reviews',
        'airline_cargo_contracts',
        'airline_heli_ops',
        'airline_flight_tracker',
        'airline_dispatch_schedules',
        'airline_maintenance',
        'airline_incidents',
        'airline_flight_school',
        'airline_company_ledger',
    }

    for _, tableName in ipairs(requiredTables) do
        local success, result = pcall(function()
            return MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.tables WHERE table_name = ?', { tableName })
        end)
        if not success or (result and result == 0) then
            errors[#errors + 1] = 'Missing database table: ' .. tableName
        end
    end

    if #errors > 0 then
        print('^1[DPS-Airlines] STARTUP ERRORS:^0')
        for _, err in ipairs(errors) do
            print('^1  - ' .. err .. '^0')
        end
        print('^1[DPS-Airlines] Resource may not function correctly!^0')
        return false
    end

    print('^2[DPS-Airlines] Startup validation passed^0')
    return true
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
CreateThread(function()
    Wait(2000) -- Wait for DB to be ready
    ValidateStartup()
    print(string.format('^2[DPS-Airlines] v3.0 loaded successfully | Framework: %s^0', Bridge.FrameworkName))
end)

-- ============================================================================
-- PLAYER STAT MANAGEMENT
-- ============================================================================

---Ensure pilot stats exist for a player
---@param citizenid string
---@param role string|nil
local function EnsurePilotStats(citizenid, role)
    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM airline_pilot_stats WHERE citizenid = ?', { citizenid })
    if exists == 0 then
        MySQL.insert.await(
            'INSERT INTO airline_pilot_stats (citizenid, role) VALUES (?, ?)',
            { citizenid, role or Constants.ROLE_GROUND_CREW }
        )
    end
end

---Ensure role assignment exists
---@param citizenid string
---@param role string
---@param assignedBy string|nil
local function EnsureRoleAssignment(citizenid, role, assignedBy)
    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM airline_role_assignments WHERE citizenid = ?', { citizenid })
    if exists == 0 then
        MySQL.insert.await(
            'INSERT INTO airline_role_assignments (citizenid, role, assigned_by) VALUES (?, ?, ?)',
            { citizenid, role, assignedBy or 'system' }
        )
    end
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

-- Get player's airline data
lib.callback.register('dps-airlines:server:getPlayerData', function(source)
    local ok, reason = Validation.Check(source, { employee = true })
    if not ok then return nil end

    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    EnsurePilotStats(player.identifier)
    EnsureRoleAssignment(player.identifier, Validation.GetPlayerRole(source) or Constants.ROLE_GROUND_CREW)

    local stats = Cache.Get('stats_' .. player.identifier, Constants.CACHE_PILOT_STATS, function()
        return MySQL.single.await('SELECT * FROM airline_pilot_stats WHERE citizenid = ?', { player.identifier })
    end)

    local roleAssignment = MySQL.single.await('SELECT * FROM airline_role_assignments WHERE citizenid = ?', { player.identifier })

    return {
        stats = stats,
        role = roleAssignment and roleAssignment.role or Constants.ROLE_GROUND_CREW,
        identifier = player.identifier,
        name = player.fullName,
        grade = player.job.grade,
        onDuty = player.job.onDuty,
    }
end)

-- Get pilot stats
lib.callback.register('dps-airlines:server:getPilotStats', function(source)
    local ok = Validation.Check(source, { employee = true })
    if not ok then return nil end

    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    return Cache.Get('stats_' .. player.identifier, Constants.CACHE_PILOT_STATS, function()
        return MySQL.single.await('SELECT * FROM airline_pilot_stats WHERE citizenid = ?', { player.identifier })
    end)
end)

-- Get flight log
lib.callback.register('dps-airlines:server:getFlightLog', function(source, page, limit)
    local ok = Validation.Check(source, { employee = true })
    if not ok then return {} end

    local player = Bridge.GetPlayer(source)
    if not player then return {} end

    page = math.max(1, tonumber(page) or 1)
    limit = math.min(50, math.max(1, tonumber(limit) or 10))
    local offset = (page - 1) * limit

    return MySQL.query.await(
        'SELECT * FROM airline_flights WHERE pilot_citizenid = ? OR copilot_citizenid = ? ORDER BY departure_time DESC LIMIT ? OFFSET ?',
        { player.identifier, player.identifier, limit, offset }
    )
end)

-- Get type ratings
lib.callback.register('dps-airlines:server:getTypeRatings', function(source)
    local ok = Validation.Check(source, { employee = true })
    if not ok then return nil end

    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    local stats = MySQL.single.await('SELECT type_ratings FROM airline_pilot_stats WHERE citizenid = ?', { player.identifier })
    if stats and stats.type_ratings then
        return json.decode(stats.type_ratings) or {}
    end
    return {}
end)

-- Get incidents
lib.callback.register('dps-airlines:server:getIncidents', function(source, page, limit)
    local ok = Validation.Check(source, { employee = true })
    if not ok then return {} end

    local player = Bridge.GetPlayer(source)
    if not player then return {} end

    page = math.max(1, tonumber(page) or 1)
    limit = math.min(50, math.max(1, tonumber(limit) or 10))
    local offset = (page - 1) * limit

    return MySQL.query.await(
        'SELECT * FROM airline_incidents WHERE citizenid = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
        { player.identifier, limit, offset }
    )
end)

-- Toggle duty
lib.callback.register('dps-airlines:server:toggleDuty', function(source)
    local ok, reason = Validation.Check(source, {
        employee = true,
        rateLimit = { action = 'toggleDuty', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    local newDuty = not player.job.onDuty
    player.setJobDuty(newDuty)

    return true, newDuty
end)

-- ============================================================================
-- MANAGEMENT CALLBACKS (Boss only)
-- ============================================================================

-- Get all employees
lib.callback.register('dps-airlines:server:getEmployees', function(source)
    local ok, reason = Validation.Check(source, { employee = true, canManage = true })
    if not ok then return nil, reason end

    return MySQL.query.await([[
        SELECT ps.*, ra.role as assigned_role
        FROM airline_pilot_stats ps
        LEFT JOIN airline_role_assignments ra ON ps.citizenid = ra.citizenid
        ORDER BY ra.role, ps.flight_hours DESC
    ]])
end)

-- Set employee role
lib.callback.register('dps-airlines:server:setEmployeeRole', function(source, targetCitizenId, newRole)
    local ok, reason = Validation.Check(source, { employee = true, canManage = true })
    if not ok then return false, reason end

    if not Config.Roles[newRole] then return false, 'Invalid role' end
    if not Validation.ValidateString(targetCitizenId, 50) then return false, 'Invalid citizen ID' end

    local manager = Bridge.GetPlayer(source)
    if not manager then return false end

    local roleConfig = Config.Roles[newRole]

    -- Update role assignment
    MySQL.query.await(
        'INSERT INTO airline_role_assignments (citizenid, role, assigned_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE role = ?, assigned_by = ?',
        { targetCitizenId, newRole, manager.identifier, newRole, manager.identifier }
    )

    -- Update job grade for target player
    local targetPlayer = Bridge.GetPlayerByIdentifier(targetCitizenId)
    if targetPlayer then
        targetPlayer.setJob(Config.Job, roleConfig.grade)
    end

    -- Update stats
    MySQL.update.await('UPDATE airline_pilot_stats SET role = ? WHERE citizenid = ?', { newRole, targetCitizenId })

    Cache.InvalidatePrefix('stats_')
    return true
end)

-- Fire employee
lib.callback.register('dps-airlines:server:fireEmployee', function(source, targetCitizenId)
    local ok, reason = Validation.Check(source, { employee = true, canManage = true })
    if not ok then return false, reason end

    local manager = Bridge.GetPlayer(source)
    if not manager then return false end

    -- Can't fire yourself
    if manager.identifier == targetCitizenId then return false, 'Cannot fire yourself' end

    -- Remove role assignment
    MySQL.query.await('DELETE FROM airline_role_assignments WHERE citizenid = ?', { targetCitizenId })

    -- Set to unemployed via bridge
    local targetPlayer = Bridge.GetPlayerByIdentifier(targetCitizenId)
    if targetPlayer then
        targetPlayer.setJob('unemployed', 0)
    end

    Cache.InvalidatePrefix('stats_')
    return true
end)

-- Get society balance
lib.callback.register('dps-airlines:server:getSocietyBalance', function(source)
    local ok = Validation.Check(source, { employee = true, canManage = true })
    if not ok then return 0 end

    return Bridge.GetSocietyBalance(Config.SocietyAccount)
end)

-- Get company stats
lib.callback.register('dps-airlines:server:getCompanyStats', function(source)
    local ok = Validation.Check(source, { employee = true })
    if not ok then return nil end

    return Cache.Get('company_stats', Constants.CACHE_COMPANY_STATS, function()
        local totalFlights = MySQL.scalar.await('SELECT COUNT(*) FROM airline_flights') or 0
        local totalEmployees = MySQL.scalar.await('SELECT COUNT(*) FROM airline_pilot_stats') or 0
        local totalEarnings = MySQL.scalar.await('SELECT COALESCE(SUM(total_pay), 0) FROM airline_flights WHERE status = ?', { Constants.DB_STATUS_COMPLETED }) or 0
        local avgRating = MySQL.scalar.await('SELECT COALESCE(AVG(overall_rating), 5.0) FROM airline_passenger_reviews') or 5.0
        local activeContracts = MySQL.scalar.await('SELECT COUNT(*) FROM airline_cargo_contracts WHERE status = ?', { Constants.DB_STATUS_ACTIVE }) or 0

        return {
            totalFlights = totalFlights,
            totalEmployees = totalEmployees,
            totalEarnings = totalEarnings,
            averageRating = math.floor(avgRating * 10) / 10,
            activeContracts = activeContracts,
            balance = Bridge.GetSocietyBalance(Config.SocietyAccount),
        }
    end)
end)

-- ============================================================================
-- HIRE PLAYER
-- ============================================================================
RegisterNetEvent('dps-airlines:server:hirePlayer', function(targetSource, role)
    local source = source
    local ok, reason = Validation.Check(source, { employee = true, canManage = true })
    if not ok then
        TriggerClientEvent('dps-airlines:client:notify', source, reason or 'Not authorized')
        return
    end

    if not Config.Roles[role] then
        TriggerClientEvent('dps-airlines:client:notify', source, 'Invalid role')
        return
    end

    local targetPlayer = Bridge.GetPlayer(targetSource)
    if not targetPlayer then
        TriggerClientEvent('dps-airlines:client:notify', source, 'Player not found')
        return
    end

    local roleConfig = Config.Roles[role]
    targetPlayer.setJob(Config.Job, roleConfig.grade)

    EnsurePilotStats(targetPlayer.identifier, role)
    EnsureRoleAssignment(targetPlayer.identifier, role, Bridge.GetPlayer(source).identifier)

    MySQL.update.await('UPDATE airline_pilot_stats SET role = ? WHERE citizenid = ?', { role, targetPlayer.identifier })

    TriggerClientEvent('dps-airlines:client:notify', source, 'Hired ' .. targetPlayer.fullName .. ' as ' .. roleConfig.label)
    TriggerClientEvent('dps-airlines:client:notify', targetSource, 'You have been hired as ' .. roleConfig.label .. ' at DPS Airlines!')

    Cache.InvalidatePrefix('stats_')
end)

-- ============================================================================
-- EMERGENCY LOGGING
-- ============================================================================
RegisterNetEvent('dps-airlines:server:logEmergency', function(flightId, emergencyType)
    local source = source
    if not Validation.IsAirlineEmployee(source) then return end
    if not Validation.RateLimit(source, 'logEmergency', Constants.THROTTLE_SLOW) then return end

    local player = Bridge.GetPlayer(source)
    if not player then return end

    pcall(function()
        MySQL.insert.await(
            'INSERT INTO airline_incidents (flight_id, citizenid, incident_type, severity, description) VALUES (?, ?, ?, ?, ?)',
            { flightId, player.identifier, emergencyType, 'moderate', 'In-flight emergency: ' .. emergencyType }
        )

        MySQL.update.await(
            'UPDATE airline_pilot_stats SET incidents = incidents + 1 WHERE citizenid = ?',
            { player.identifier }
        )
    end)
end)

-- ============================================================================
-- RESOURCE CLEANUP
-- ============================================================================
AddEventHandler('onResourceStop', function(resource)
    if resource ~= resourceName then return end

    -- Clean up active flight trackers
    pcall(function()
        MySQL.query.await('DELETE FROM airline_flight_tracker')
    end)

    Cache.Clear()
    print('^3[DPS-Airlines] Resource stopped, cleaned up flight trackers^0')
end)
