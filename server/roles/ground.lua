-- Server: Ground Crew role logic

-- Get available ground tasks
lib.callback.register('dps-airlines:server:getGroundTasks', function(source, airportCode)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true,
        rateLimit = { action = 'getGroundTasks', cooldown = Constants.THROTTLE_NORMAL },
    })
    if not ok then return nil, reason end

    if not Validation.ValidateAirportCode(airportCode) then return nil, 'Invalid airport' end

    return MySQL.query.await(
        'SELECT * FROM airline_ground_tasks WHERE airport_code = ? AND status = ? ORDER BY created_at ASC LIMIT 20',
        { airportCode, Constants.DISPATCH_PENDING }
    )
end)

-- Accept a ground task
lib.callback.register('dps-airlines:server:acceptGroundTask', function(source, taskId)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true,
        rateLimit = { action = 'acceptTask', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false, reason end

    local role = Validation.GetPlayerRole(source)
    if role ~= Constants.ROLE_GROUND_CREW and role ~= Constants.ROLE_CHIEF_PILOT then
        return false, 'Must be Ground Crew'
    end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    -- Check task is available
    local task = MySQL.single.await(
        'SELECT * FROM airline_ground_tasks WHERE id = ? AND status = ? AND assigned_to IS NULL',
        { taskId, Constants.DISPATCH_PENDING }
    )
    if not task then return false, 'Task not available' end

    -- Assign task
    MySQL.update.await(
        'UPDATE airline_ground_tasks SET assigned_to = ?, status = ? WHERE id = ?',
        { player.identifier, Constants.DISPATCH_ASSIGNED, taskId }
    )

    return true, task
end)

-- Complete a ground task
lib.callback.register('dps-airlines:server:completeGroundTask', function(source, taskId)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true,
        rateLimit = { action = 'completeTask', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    -- Verify task belongs to player
    local task = MySQL.single.await(
        'SELECT * FROM airline_ground_tasks WHERE id = ? AND assigned_to = ? AND status = ?',
        { taskId, player.identifier, Constants.DISPATCH_ASSIGNED }
    )
    if not task then return false, 'Task not found or not assigned to you' end

    -- Complete task
    MySQL.update.await(
        'UPDATE airline_ground_tasks SET status = ?, completed_at = NOW() WHERE id = ?',
        { Constants.DISPATCH_COMPLETED, taskId }
    )

    -- Pay
    local pay = task.pay_amount or Payments.CalculateGroundTaskPay(task.task_type)
    Payments.PayPlayer(source, pay, 'Ground task: ' .. task.task_type)

    -- Update stats
    MySQL.update.await(
        'UPDATE airline_pilot_stats SET ground_tasks_completed = ground_tasks_completed + 1 WHERE citizenid = ?',
        { player.identifier }
    )

    Cache.Invalidate('stats_' .. player.identifier)

    return true, pay
end)

-- Hourly pay cycle for ground crew on duty
CreateThread(function()
    while true do
        Wait(Config.PayCycleMinutes * 60 * 1000)

        local players = Bridge.GetPlayers()
        for _, player in ipairs(players) do
            if player.job.name == Config.Job and player.job.onDuty then
                local role = MySQL.scalar.await(
                    'SELECT role FROM airline_role_assignments WHERE citizenid = ?',
                    { player.identifier }
                )
                if role == Constants.ROLE_GROUND_CREW then
                    local roleConfig = Config.Roles[Constants.ROLE_GROUND_CREW]
                    Payments.PayPlayer(player.source, roleConfig.hourlyPay, 'Ground crew hourly pay')
                elseif role == Constants.ROLE_DISPATCHER then
                    Payments.PayPlayer(player.source, Payments.CalculateDispatcherSalary(), 'Dispatcher salary')
                end
            end
        end
    end
end)
