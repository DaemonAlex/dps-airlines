-- Server: Charter system - all pricing server-side

-- Get charter price quote
lib.callback.register('dps-airlines:server:getCharterPrice', function(source, fromCode, toCode, passengers, vip, luggage)
    local ok = Validation.Check(source, { employee = true, onDuty = true })
    if not ok then return 0 end

    if not Validation.ValidateAirportCode(fromCode) then return 0 end
    if not Validation.ValidateAirportCode(toCode) then return 0 end

    return Payments.CalculateCharterPrice(fromCode, toCode, passengers or 0, vip or false, luggage or 0)
end)

-- Book a charter flight
lib.callback.register('dps-airlines:server:bookCharter', function(source, data)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true, canFly = true,
        rateLimit = { action = 'bookCharter', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return nil, reason end

    if not data then return nil, 'No data' end
    if not Validation.ValidateAirportCode(data.from) then return nil, 'Invalid origin' end
    if not Validation.ValidateAirportCode(data.to) then return nil, 'Invalid destination' end

    local aircraft = Locations.GetAircraftConfig(data.model)
    if not aircraft then return nil, 'Invalid aircraft' end

    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    -- Calculate price server-side (ignore any client-sent price)
    local price = Payments.CalculateCharterPrice(
        data.from, data.to, data.passengers or 0, data.vip or false, data.luggage or 0
    )

    -- Add revenue to society
    Payments.AddToSociety(price, 'Charter booking ' .. data.from .. ' -> ' .. data.to)

    -- Create the flight
    local flightNum = 'CHT' .. math.random(100, 999)
    local route = Locations.GetRoute(data.from, data.to)

    local flightId = MySQL.insert.await([[
        INSERT INTO airline_flights
        (flight_number, pilot_citizenid, aircraft_model, departure_airport, arrival_airport,
         passengers, cargo_weight, flight_type, status, distance)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        flightNum, player.identifier, data.model, data.from, data.to,
        data.passengers or 0, 0, 'charter', Constants.DB_STATUS_ACTIVE,
        route and route.distance or 0
    })

    return {
        flightId = flightId,
        flightNumber = flightNum,
        price = price,
    }
end)
