-- Server: Captain & Chief Pilot role logic

-- Start a flight
lib.callback.register('dps-airlines:server:startFlight', function(source, data)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true, canFly = true,
        rateLimit = { action = 'startFlight', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return nil, reason end

    if not data then return nil, 'No data' end
    if not Validation.ValidateAirportCode(data.departure) then return nil, 'Invalid departure' end
    if not Validation.ValidateAirportCode(data.arrival) then return nil, 'Invalid arrival' end
    if data.departure == data.arrival then return nil, 'Same airport' end

    local model = data.model
    local aircraft = Locations.GetAircraftConfig(model)
    if not aircraft then return nil, 'Invalid aircraft model' end

    if not Validation.ValidatePassengerCount(data.passengers or 0, model) then return nil, 'Invalid passenger count' end
    if not Validation.ValidateCargoWeight(data.cargoWeight or 0, model) then return nil, 'Invalid cargo weight' end

    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    -- Check maintenance status
    local maint = MySQL.single.await(
        'SELECT * FROM airline_maintenance WHERE aircraft_model = ? AND airport_code = ?',
        { model, data.departure }
    )
    if maint and maint.status == Constants.MAINT_GROUNDED then
        return nil, 'Aircraft is grounded for maintenance'
    end

    -- Generate flight number
    local flightNum = 'DPS' .. math.random(100, 999)

    local route = Locations.GetRoute(data.departure, data.arrival)
    local distance = route and route.distance or 0

    local flightId = MySQL.insert.await([[
        INSERT INTO airline_flights
        (flight_number, pilot_citizenid, aircraft_model, departure_airport, arrival_airport,
         passengers, cargo_weight, flight_type, status, distance)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        flightNum, player.identifier, model, data.departure, data.arrival,
        data.passengers or 0, data.cargoWeight or 0, data.flightType or 'scheduled',
        Constants.DB_STATUS_ACTIVE, distance
    })

    -- Create ground tasks for this flight
    local groundTasks = {
        Constants.TASK_CARGO_LOAD,
        Constants.TASK_REFUEL,
        Constants.TASK_BAGGAGE,
    }
    for _, taskType in ipairs(groundTasks) do
        MySQL.insert.await(
            'INSERT INTO airline_ground_tasks (task_type, airport_code, flight_id, pay_amount) VALUES (?, ?, ?, ?)',
            { taskType, data.departure, flightId, Payments.CalculateGroundTaskPay(taskType) }
        )
    end

    -- Insert flight tracker
    MySQL.insert.await(
        'INSERT INTO airline_flight_tracker (flight_id, citizenid, phase) VALUES (?, ?, ?)',
        { flightId, player.identifier, Constants.PHASE_GROUND }
    )

    Cache.Invalidate('stats_' .. player.identifier)
    Cache.Invalidate('company_stats')

    return {
        flightId = flightId,
        flightNumber = flightNum,
        departure = data.departure,
        arrival = data.arrival,
        model = model,
        passengers = data.passengers or 0,
        cargoWeight = data.cargoWeight or 0,
        distance = distance,
    }
end)

-- Complete a flight
lib.callback.register('dps-airlines:server:completeFlight', function(source, data)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true, canFly = true,
        rateLimit = { action = 'completeFlight', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return nil, reason end

    if not data or not data.flightId then return nil, 'No flight data' end

    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    -- Verify this flight belongs to the player
    local flight = MySQL.single.await(
        'SELECT * FROM airline_flights WHERE id = ? AND pilot_citizenid = ? AND status = ?',
        { data.flightId, player.identifier, Constants.DB_STATUS_ACTIVE }
    )
    if not flight then return nil, 'Flight not found or not active' end

    -- Validate completion
    local valid, validReason = Validation.ValidateFlightCompletion(source, {
        departure = flight.departure_airport,
        arrival = flight.arrival_airport,
        duration = data.duration,
    })
    if not valid then return nil, validReason end

    -- Calculate landing quality
    local landingBonus, landingLabel = Payments.GetLandingBonus(data.landingSpeed or 10)

    -- Calculate pay
    local totalPay = Payments.CalculateFlightPay({
        distance = flight.distance,
        passengers = flight.passengers,
        cargoWeight = flight.cargo_weight,
        weatherSeverity = data.weatherSeverity or Constants.WEATHER_CLEAR,
        priority = flight.flight_type == 'priority',
        isNight = data.isNight or false,
        isEmergency = flight.flight_type == 'emergency',
        duration = data.duration,
    })

    -- Apply landing bonus
    totalPay = math.floor(totalPay * landingBonus)

    -- Update flight record
    MySQL.update.await([[
        UPDATE airline_flights SET
            status = ?, duration = ?, fuel_used = ?, landing_speed = ?,
            landing_quality = ?, weather_conditions = ?, total_pay = ?,
            arrival_time = NOW()
        WHERE id = ?
    ]], {
        Constants.DB_STATUS_COMPLETED, data.duration or 0, data.fuelUsed or 0,
        data.landingSpeed, landingLabel, data.weatherCondition or 'clear',
        totalPay, data.flightId
    })

    -- Get crew members for this flight
    local crewRows = MySQL.query.await(
        'SELECT * FROM airline_crew_assignments WHERE flight_id = ?',
        { data.flightId }
    )

    -- Build crew list for payment
    local crewMembers = {
        { source = source, citizenid = player.identifier, role = Validation.GetPlayerRole(source) or Constants.ROLE_CAPTAIN }
    }
    for _, crew in ipairs(crewRows or {}) do
        local crewPlayer = Bridge.GetPlayerByIdentifier(crew.citizenid)
        if crewPlayer then
            crewMembers[#crewMembers + 1] = {
                source = crewPlayer.source,
                citizenid = crew.citizenid,
                role = crew.role,
            }
        end
    end

    -- Distribute pay
    local payouts = Payments.DistributeCrewPay(totalPay, crewMembers)
    for _, payout in ipairs(payouts) do
        if payout.source then
            Payments.PayPlayer(payout.source, payout.amount, 'Flight ' .. flight.flight_number .. ' completion')
        end
    end

    -- Update pilot stats
    MySQL.update.await([[
        UPDATE airline_pilot_stats SET
            total_flights = total_flights + 1,
            successful_flights = successful_flights + 1,
            total_passengers = total_passengers + ?,
            total_cargo = total_cargo + ?,
            total_distance = total_distance + ?,
            total_earnings = total_earnings + ?,
            flight_hours = flight_hours + ?
        WHERE citizenid = ?
    ]], {
        flight.passengers, flight.cargo_weight, flight.distance,
        totalPay, (data.duration or 0) / 3600.0, player.identifier
    })

    -- Generate passenger review
    if Config.Reviews.enabled and flight.passengers > 0 then
        local landingQuality = math.max(1, math.min(5, 5 - (math.abs(data.landingSpeed or 10) / 5)))
        local serviceQuality = 3 + math.random() * 2
        local timeQuality = data.duration and math.min(5, 3 + (1 - math.min(1, data.duration / (flight.distance / 30)))) or 3
        local overall = (landingQuality * Config.Reviews.landingWeight)
                      + (serviceQuality * Config.Reviews.serviceWeight)
                      + (timeQuality * Config.Reviews.timeWeight)

        MySQL.insert.await(
            'INSERT INTO airline_passenger_reviews (flight_id, landing_quality, service_quality, time_quality, overall_rating) VALUES (?, ?, ?, ?, ?)',
            { data.flightId, landingQuality, serviceQuality, timeQuality, overall }
        )

        -- Update service rating
        MySQL.update.await(
            'UPDATE airline_pilot_stats SET service_rating = (service_rating + ?) / 2, landing_rating = (landing_rating + ?) / 2 WHERE citizenid = ?',
            { overall, landingQuality, player.identifier }
        )
    end

    -- Update maintenance
    MySQL.query.await([[
        INSERT INTO airline_maintenance (aircraft_model, airport_code, condition_pct, flights_since_inspection, status)
        VALUES (?, ?, ?, 1, ?)
        ON DUPLICATE KEY UPDATE
            condition_pct = GREATEST(0, condition_pct - ?),
            flights_since_inspection = flights_since_inspection + 1,
            status = CASE
                WHEN condition_pct - ? <= ? THEN 'grounded'
                WHEN condition_pct - ? <= 50 THEN 'poor'
                WHEN condition_pct - ? <= 75 THEN 'fair'
                ELSE 'good'
            END
    ]], {
        flight.aircraft_model, flight.arrival_airport,
        100 - Config.Maintenance.degradePerFlight, Constants.MAINT_GOOD,
        Config.Maintenance.degradePerFlight,
        Config.Maintenance.degradePerFlight, Config.Maintenance.groundedThreshold,
        Config.Maintenance.degradePerFlight,
        Config.Maintenance.degradePerFlight,
    })

    -- Clean up flight tracker
    MySQL.query.await('DELETE FROM airline_flight_tracker WHERE flight_id = ?', { data.flightId })

    Cache.Invalidate('stats_' .. player.identifier)
    Cache.Invalidate('company_stats')

    return {
        pay = totalPay,
        landingQuality = landingLabel,
        landingBonus = landingBonus,
        payouts = payouts,
    }
end)

-- Cancel/fail a flight
lib.callback.register('dps-airlines:server:failFlight', function(source, flightId, reason)
    local ok = Validation.Check(source, { employee = true, canFly = true })
    if not ok then return false end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    local flight = MySQL.single.await(
        'SELECT * FROM airline_flights WHERE id = ? AND pilot_citizenid = ? AND status = ?',
        { flightId, player.identifier, Constants.DB_STATUS_ACTIVE }
    )
    if not flight then return false end

    MySQL.update.await(
        'UPDATE airline_flights SET status = ?, arrival_time = NOW() WHERE id = ?',
        { Constants.DB_STATUS_FAILED, flightId }
    )

    MySQL.update.await(
        'UPDATE airline_pilot_stats SET failed_flights = failed_flights + 1 WHERE citizenid = ?',
        { player.identifier }
    )

    -- Log incident
    MySQL.insert.await(
        'INSERT INTO airline_incidents (flight_id, citizenid, incident_type, severity, description) VALUES (?, ?, ?, ?, ?)',
        { flightId, player.identifier, 'flight_failure', 'moderate', reason or 'Flight failed' }
    )

    MySQL.query.await('DELETE FROM airline_flight_tracker WHERE flight_id = ?', { flightId })

    Cache.Invalidate('stats_' .. player.identifier)
    return true
end)

-- Update flight tracker position
RegisterNetEvent('dps-airlines:server:updateTracker', function(flightId, posData)
    local source = source
    if not Validation.RateLimit(source, 'tracker', Constants.THROTTLE_SLOW) then return end

    local player = Bridge.GetPlayer(source)
    if not player then return end

    pcall(function()
        MySQL.update.await([[
            UPDATE airline_flight_tracker SET
                pos_x = ?, pos_y = ?, pos_z = ?, heading = ?,
                speed = ?, altitude = ?, fuel_level = ?, phase = ?
            WHERE flight_id = ? AND citizenid = ?
        ]], {
            posData.x or 0, posData.y or 0, posData.z or 0, posData.heading or 0,
            posData.speed or 0, posData.altitude or 0, posData.fuel or 100, posData.phase or 0,
            flightId, player.identifier
        })
    end)
end)

-- Spawn aircraft
lib.callback.register('dps-airlines:server:spawnAircraft', function(source, model, spawnIndex, airportCode)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true, canFly = true,
        rateLimit = { action = 'spawnAircraft', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return nil, reason end

    local aircraft = Locations.GetAircraftConfig(model)
    if not aircraft then return nil, 'Invalid aircraft' end

    local airport = Locations.GetAirport(airportCode)
    if not airport then return nil, 'Invalid airport' end

    local spawns = airport.spawns.planes
    if not spawns or not spawns[spawnIndex] then
        spawnIndex = 1
    end

    local spawn = spawns[spawnIndex]
    if not spawn then return nil, 'No spawn available' end

    return {
        model = model,
        coords = spawn,
        heading = spawn.w,
    }
end)
