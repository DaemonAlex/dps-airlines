-- Server: Dispatcher role logic

-- Create a flight schedule
lib.callback.register('dps-airlines:server:createSchedule', function(source, data)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true, canDispatch = true,
        rateLimit = { action = 'createSchedule', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return nil, reason end

    if not data then return nil, 'No data' end
    if not Validation.ValidateAirportCode(data.departure) then return nil, 'Invalid departure' end
    if not Validation.ValidateAirportCode(data.arrival) then return nil, 'Invalid arrival' end
    if data.departure == data.arrival then return nil, 'Same airport' end

    local aircraft = Locations.GetAircraftConfig(data.model)
    if not aircraft then return nil, 'Invalid aircraft' end

    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    local flightNum = 'DPS' .. math.random(100, 999)

    local scheduleId = MySQL.insert.await([[
        INSERT INTO airline_dispatch_schedules
        (dispatcher_citizenid, flight_number, departure_airport, arrival_airport,
         aircraft_model, passengers, cargo_weight, priority, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        player.identifier, flightNum, data.departure, data.arrival,
        data.model, data.passengers or 0, data.cargoWeight or 0,
        data.priority or 'normal', data.notes or ''
    })

    -- Update stats
    MySQL.update.await(
        'UPDATE airline_pilot_stats SET dispatches_created = dispatches_created + 1 WHERE citizenid = ?',
        { player.identifier }
    )

    Cache.Invalidate('stats_' .. player.identifier)

    return {
        scheduleId = scheduleId,
        flightNumber = flightNum,
    }
end)

-- Get all pending schedules
lib.callback.register('dps-airlines:server:getSchedules', function(source, statusFilter)
    local ok = Validation.Check(source, { employee = true, onDuty = true })
    if not ok then return {} end

    local status = statusFilter or Constants.DISPATCH_PENDING
    return MySQL.query.await(
        'SELECT * FROM airline_dispatch_schedules WHERE status = ? ORDER BY created_at DESC LIMIT 50',
        { status }
    )
end)

-- Assign pilot to schedule
lib.callback.register('dps-airlines:server:assignPilot', function(source, scheduleId, pilotCitizenId)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true, canDispatch = true,
        rateLimit = { action = 'assignPilot', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false, reason end

    if not Validation.ValidateString(pilotCitizenId, 50) then return false, 'Invalid pilot ID' end

    -- Verify pilot is airline employee with flight privileges
    local pilotRole = MySQL.scalar.await(
        'SELECT role FROM airline_role_assignments WHERE citizenid = ?',
        { pilotCitizenId }
    )
    if not pilotRole then return false, 'Pilot not found' end

    local roleConfig = Config.Roles[pilotRole]
    if not roleConfig or not roleConfig.canFly then
        return false, 'Target employee cannot fly'
    end

    MySQL.update.await(
        'UPDATE airline_dispatch_schedules SET assigned_pilot = ?, status = ? WHERE id = ? AND status = ?',
        { pilotCitizenId, Constants.DISPATCH_ASSIGNED, scheduleId, Constants.DISPATCH_PENDING }
    )

    -- Notify pilot if online
    local pilotPlayer = Bridge.GetPlayerByIdentifier(pilotCitizenId)
    if pilotPlayer then
        TriggerClientEvent('dps-airlines:client:notify', pilotPlayer.source, 'You have been assigned a flight')
    end

    -- Commission pay for dispatcher
    local dispatcher = Bridge.GetPlayer(source)
    if dispatcher then
        local schedule = MySQL.single.await('SELECT * FROM airline_dispatch_schedules WHERE id = ?', { scheduleId })
        if schedule then
            local route = Locations.GetRoute(schedule.departure_airport, schedule.arrival_airport)
            if route then
                local flightPay = Payments.CalculateFlightPay({ distance = route.distance, passengers = schedule.passengers, cargoWeight = schedule.cargo_weight })
                local commission = math.floor(flightPay * (Config.Roles[Constants.ROLE_DISPATCHER].commissionPercent or 0.05))
                Payments.PayPlayer(source, commission, 'Dispatch commission for ' .. schedule.flight_number)
            end
        end
    end

    return true
end)

-- Cancel schedule
lib.callback.register('dps-airlines:server:cancelSchedule', function(source, scheduleId)
    local ok, reason = Validation.Check(source, {
        employee = true, canDispatch = true,
        rateLimit = { action = 'cancelSchedule', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false, reason end

    MySQL.update.await(
        'UPDATE airline_dispatch_schedules SET status = ? WHERE id = ? AND status IN (?, ?)',
        { Constants.DISPATCH_CANCELLED, scheduleId, Constants.DISPATCH_PENDING, Constants.DISPATCH_ASSIGNED }
    )

    return true
end)

-- Get live flight tracker data (for dispatcher map)
lib.callback.register('dps-airlines:server:getFlightTracker', function(source)
    local ok = Validation.Check(source, { employee = true, canDispatch = true })
    if not ok then return {} end

    return MySQL.query.await([[
        SELECT ft.*, f.flight_number, f.departure_airport, f.arrival_airport, f.aircraft_model
        FROM airline_flight_tracker ft
        JOIN airline_flights f ON ft.flight_id = f.id
        WHERE f.status = ?
    ]], { Constants.DB_STATUS_ACTIVE })
end)

-- Get available pilots for assignment
lib.callback.register('dps-airlines:server:getAvailablePilots', function(source)
    local ok = Validation.Check(source, { employee = true, canDispatch = true })
    if not ok then return {} end

    return MySQL.query.await([[
        SELECT ps.citizenid, ps.flight_hours, ps.total_flights, ps.service_rating, ra.role
        FROM airline_pilot_stats ps
        JOIN airline_role_assignments ra ON ps.citizenid = ra.citizenid
        WHERE ra.role IN (?, ?, ?)
        ORDER BY ps.flight_hours DESC
    ]], { Constants.ROLE_CAPTAIN, Constants.ROLE_FIRST_OFFICER, Constants.ROLE_CHIEF_PILOT })
end)
