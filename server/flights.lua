-- Flight Management Server
local QBCore = exports['qb-core']:GetCoreObject()

-- =====================================
-- FLIGHT GENERATION
-- =====================================

local function GenerateRandomFlight()
    local routes = Locations.Routes
    local route = routes[math.random(1, #routes)]

    local fromAirport = Locations.Airports[route.from]
    local toAirport = Locations.Airports[route.to]

    if not fromAirport or not toAirport then return nil end

    -- Calculate base payment
    local distance = toAirport.distance or 5
    local basePay = 100 + (distance * 20)

    -- Apply priority multiplier
    local priorityMultipliers = {
        ['low'] = 0.8,
        ['normal'] = 1.0,
        ['high'] = 1.3,
        ['urgent'] = 1.5
    }
    local payment = math.floor(basePay * (priorityMultipliers[route.priority] or 1.0))

    -- Generate passengers or cargo
    local passengers = 0
    local cargoWeight = 0
    local cargoType = nil

    if route.flightType == 'passenger' then
        passengers = math.random(4, 16)
        payment = payment + (passengers * Config.Passengers.payPerPassenger)
    elseif route.flightType == 'cargo' then
        local cargo = Config.Cargo.cargoTypes[math.random(1, #Config.Cargo.cargoTypes)]
        cargoWeight = math.random(cargo.weight.min, cargo.weight.max)
        cargoType = cargo.name
        payment = payment + math.floor(cargoWeight * Config.Cargo.payPerKg * cargo.payMultiplier)
    end

    -- Determine plane requirement based on size
    local planeRequired = nil
    if passengers > 12 then
        planeRequired = 'miljet'
    elseif passengers > 8 then
        planeRequired = 'nimbus'
    elseif passengers > 4 then
        planeRequired = 'shamal'
    end

    return {
        from = route.from,
        to = route.to,
        from_label = fromAirport.label,
        to_label = toAirport.label,
        flightType = route.flightType,
        priority = route.priority,
        passengers = passengers,
        cargoWeight = cargoWeight,
        cargoType = cargoType,
        planeRequired = planeRequired,
        payment = payment,
        restricted = route.restricted or false
    }
end

-- =====================================
-- DISPATCH GENERATION LOOP
-- =====================================

CreateThread(function()
    while true do
        Wait(60000) -- Generate new flights every minute

        if Config.Dispatch.enabled then
            -- Check current available flights
            local currentFlights = MySQL.scalar.await('SELECT COUNT(*) FROM airline_dispatch WHERE status = ?', { 'available' })

            if currentFlights < 5 then
                local flight = GenerateRandomFlight()
                if flight then
                    -- Set expiry time
                    local expirySeconds = Config.Dispatch.expiryTime

                    MySQL.insert.await([[
                        INSERT INTO airline_dispatch
                        (flight_type, from_airport, to_airport, priority, plane_required, passengers, cargo_weight, cargo_type, payment, expires_at, status)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND), 'available')
                    ]], {
                        flight.flightType,
                        flight.from,
                        flight.to,
                        flight.priority,
                        flight.planeRequired,
                        flight.passengers,
                        flight.cargoWeight,
                        flight.cargoType,
                        flight.payment,
                        expirySeconds
                    })

                    -- Notify online pilots
                    local players = QBCore.Functions.GetQBPlayers()
                    for _, player in pairs(players) do
                        if player.PlayerData.job.name == Config.Job and player.PlayerData.job.onduty then
                            TriggerClientEvent('dps-airlines:client:dispatchGenerated', player.PlayerData.source, {
                                flight_type = flight.flightType,
                                to_label = flight.to_label,
                                payment = flight.payment
                            })
                        end
                    end
                end
            end
        end
    end
end)

-- Cleanup expired flights
CreateThread(function()
    while true do
        Wait(30000)
        MySQL.update.await('UPDATE airline_dispatch SET status = ? WHERE status = ? AND expires_at < NOW()', { 'expired', 'available' })
    end
end)

-- =====================================
-- CALLBACKS
-- =====================================

lib.callback.register('dps-airlines:server:acceptDispatch', function(source, dispatchId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    local citizenid = Player.PlayerData.citizenid

    -- Check if dispatch is still available
    local dispatch = MySQL.single.await('SELECT * FROM airline_dispatch WHERE id = ? AND status = ?', { dispatchId, 'available' })

    if not dispatch then
        return false
    end

    -- Assign to player
    MySQL.update.await('UPDATE airline_dispatch SET assigned_to = ?, status = ? WHERE id = ?', {
        citizenid,
        'assigned',
        dispatchId
    })

    return dispatch
end)

-- =====================================
-- FLIGHT STATS TRACKING
-- =====================================

lib.callback.register('dps-airlines:server:getFlightHistory', function(source, limit)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return {} end

    local citizenid = Player.PlayerData.citizenid
    limit = limit or 10

    local flights = MySQL.query.await([[
        SELECT * FROM airline_flights
        WHERE pilot_citizenid = ?
        ORDER BY created_at DESC
        LIMIT ?
    ]], { citizenid, limit })

    return flights or {}
end)

lib.callback.register('dps-airlines:server:getCompanyStats', function(source)
    local stats = MySQL.single.await([[
        SELECT
            COUNT(*) as total_flights,
            SUM(passengers) as total_passengers,
            SUM(cargo_weight) as total_cargo,
            SUM(payment) as total_revenue,
            COUNT(DISTINCT pilot_citizenid) as unique_pilots
        FROM airline_flights
        WHERE status = 'arrived'
    ]])

    return stats or {
        total_flights = 0,
        total_passengers = 0,
        total_cargo = 0,
        total_revenue = 0,
        unique_pilots = 0
    }
end)

print('^2[dps-airlines]^7 Flights module loaded')
