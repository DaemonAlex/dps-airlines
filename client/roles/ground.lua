-- Client: Ground Crew role

---Open ground crew menu
---@param airportCode string
function OpenGroundMenu(airportCode)
    local options = {
        {
            title = 'View Available Tasks',
            description = 'See pending ground tasks at this airport',
            icon = 'clipboard-list',
            onSelect = function()
                ViewGroundTasks(airportCode)
            end,
        },
        {
            title = 'Aircraft Maintenance',
            description = 'Inspect and repair aircraft',
            icon = 'wrench',
            onSelect = function()
                OpenMaintenanceMenu(airportCode)
            end,
        },
        {
            title = 'Refuel Aircraft',
            description = 'Refuel parked aircraft',
            icon = 'gas-pump',
            onSelect = function()
                RefuelNearbyAircraft()
            end,
        },
        {
            title = 'Marshal Aircraft',
            description = 'Guide aircraft to gate',
            icon = 'arrows-alt',
            onSelect = function()
                MarshalAircraft()
            end,
        },
        {
            title = 'De-Ice Aircraft',
            description = 'Remove ice from aircraft',
            icon = 'snowflake',
            onSelect = function()
                DeIceAircraft()
            end,
        },
        {
            title = 'View Stats',
            description = 'View your ground crew statistics',
            icon = 'chart-bar',
            onSelect = function()
                OpenNUI('overview')
            end,
        },
    }

    lib.registerContext({
        id = 'airline_ground_menu',
        title = 'Ground Crew Menu',
        options = options,
    })
    lib.showContext('airline_ground_menu')
end

---View available ground tasks
---@param airportCode string
function ViewGroundTasks(airportCode)
    lib.callback('dps-airlines:server:getGroundTasks', false, function(tasks, err)
        if not tasks or #tasks == 0 then
            Bridge.Notify('No pending tasks at this airport', 'inform')
            return
        end

        local options = {}
        local taskLabels = {
            [Constants.TASK_CARGO_LOAD] = 'Load Cargo',
            [Constants.TASK_CARGO_UNLOAD] = 'Unload Cargo',
            [Constants.TASK_REFUEL] = 'Refuel Aircraft',
            [Constants.TASK_MARSHAL] = 'Marshal Aircraft',
            [Constants.TASK_DEICE] = 'De-Ice Aircraft',
            [Constants.TASK_BAGGAGE] = 'Handle Baggage',
            [Constants.TASK_MAINTENANCE] = 'Maintenance',
        }

        for _, task in ipairs(tasks) do
            options[#options + 1] = {
                title = taskLabels[task.task_type] or task.task_type,
                description = string.format('Pay: $%d | Flight #%s', task.pay_amount, task.flight_id or 'N/A'),
                icon = 'tasks',
                onSelect = function()
                    AcceptAndCompleteTask(task)
                end,
            }
        end

        lib.registerContext({
            id = 'airline_ground_tasks',
            title = 'Available Tasks (' .. airportCode .. ')',
            menu = 'airline_ground_menu',
            options = options,
        })
        lib.showContext('airline_ground_tasks')
    end, airportCode)
end

---Accept and complete a ground task
---@param task table
function AcceptAndCompleteTask(task)
    -- Accept
    lib.callback('dps-airlines:server:acceptGroundTask', false, function(success, err)
        if not success then
            Bridge.Notify(err or 'Failed to accept task', 'error')
            return
        end

        Bridge.Notify('Task accepted! Complete it now.', 'success')

        -- Simulate task completion with progress bar
        local durations = {
            [Constants.TASK_CARGO_LOAD] = 15000,
            [Constants.TASK_CARGO_UNLOAD] = 12000,
            [Constants.TASK_REFUEL] = 20000,
            [Constants.TASK_MARSHAL] = 10000,
            [Constants.TASK_DEICE] = 18000,
            [Constants.TASK_BAGGAGE] = 8000,
            [Constants.TASK_MAINTENANCE] = 25000,
        }

        local duration = durations[task.task_type] or 10000

        local completed = lib.progressBar({
            duration = duration,
            label = 'Completing: ' .. (task.task_type or 'task'),
            useWhileDead = false,
            canCancel = true,
            anim = {
                dict = 'mini@repair',
                clip = 'fixing_a_player',
            },
        })

        if not completed then
            Bridge.Notify('Task cancelled', 'error')
            return
        end

        -- Complete on server
        lib.callback('dps-airlines:server:completeGroundTask', false, function(ok, pay)
            if ok then
                Bridge.Notify(string.format('Task complete! Earned: $%s', pay or 0), 'success')
            else
                Bridge.Notify('Failed to complete task', 'error')
            end
        end, task.id)
    end, task.id)
end

---Open maintenance menu
---@param airportCode string
function OpenMaintenanceMenu(airportCode)
    lib.callback('dps-airlines:server:getAirportMaintenance', false, function(records)
        if not records or #records == 0 then
            Bridge.Notify('No maintenance records found', 'inform')
            return
        end

        local options = {}
        for _, record in ipairs(records) do
            local statusColor = record.status == Constants.MAINT_GOOD and '~g~' or
                               record.status == Constants.MAINT_FAIR and '~y~' or '~r~'

            options[#options + 1] = {
                title = record.aircraft_model,
                description = string.format('Condition: %d%% | Status: %s | Flights since inspection: %d',
                    record.condition_pct, record.status, record.flights_since_inspection),
                icon = 'plane',
                onSelect = function()
                    RepairAircraft(record)
                end,
            }
        end

        lib.registerContext({
            id = 'airline_maintenance',
            title = 'Aircraft Maintenance',
            menu = 'airline_ground_menu',
            options = options,
        })
        lib.showContext('airline_maintenance')
    end, airportCode)
end

---Repair an aircraft
---@param record table
function RepairAircraft(record)
    local repairNeeded = 100 - record.condition_pct
    if repairNeeded <= 0 then
        Bridge.Notify('Aircraft is in perfect condition', 'inform')
        return
    end

    local input = lib.inputDialog('Repair Aircraft', {
        { type = 'number', label = 'Repair Points (1-' .. repairNeeded .. ')', min = 1, max = repairNeeded, default = repairNeeded },
    })
    if not input then return end

    local cost = input[1] * Config.Maintenance.repairCostPerPoint
    local confirm = lib.alertDialog({
        header = 'Confirm Repair',
        content = string.format('Repair %d points for $%d from company funds?', input[1], cost),
        centered = true,
        cancel = true,
    })

    if confirm ~= 'confirm' then return end

    lib.callback('dps-airlines:server:performMaintenance', false, function(success, result)
        if success then
            Bridge.Notify(string.format('Repaired! Cost: $%d', result.cost), 'success')
        else
            Bridge.Notify(result or 'Repair failed', 'error')
        end
    end, record.aircraft_model, record.airport_code, input[1])
end

---Refuel nearby aircraft (quick task)
function RefuelNearbyAircraft()
    local success = lib.progressBar({
        duration = 15000,
        label = 'Refueling aircraft...',
        useWhileDead = false,
        canCancel = true,
        anim = {
            dict = 'timetable@gardener@filling_can',
            clip = 'gar_ig_filling_can',
        },
    })

    if success then
        Bridge.Notify('Aircraft refueled!', 'success')
    end
end

---Marshal aircraft (visual guidance)
function MarshalAircraft()
    local success = lib.progressBar({
        duration = 20000,
        label = 'Marshaling aircraft to gate...',
        useWhileDead = false,
        canCancel = true,
        anim = {
            dict = 'anim@mp_point',
            clip = 'task_mp_point_stand',
        },
    })

    if success then
        Bridge.Notify('Aircraft marshaled to gate!', 'success')
    end
end

---De-ice aircraft
function DeIceAircraft()
    local success = lib.progressBar({
        duration = 25000,
        label = 'De-icing aircraft...',
        useWhileDead = false,
        canCancel = true,
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped',
        },
    })

    if success then
        Bridge.Notify('Aircraft de-iced and ready for departure!', 'success')
    end
end
