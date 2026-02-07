-- Client: Ferry flight system (repositioning flights without passengers)

---Start a ferry flight (no passengers, reduced pay)
---@param airportCode string
function StartFerryFlight(airportCode)
    if not State.CanFly() then
        Bridge.Notify('Not authorized to fly', 'error')
        return
    end

    local destOptions = {}
    for code, ap in pairs(Locations.Airports) do
        if code ~= airportCode then
            destOptions[#destOptions + 1] = { label = ap.label .. ' (' .. code .. ')', value = code }
        end
    end

    local aircraftOptions = {}
    for _, ac in ipairs(Config.Aircraft) do
        aircraftOptions[#aircraftOptions + 1] = { label = ac.label, value = ac.model }
    end

    local input = lib.inputDialog('Ferry Flight', {
        { type = 'select', label = 'Aircraft', options = aircraftOptions, required = true },
        { type = 'select', label = 'Destination', options = destOptions, required = true },
    })

    if not input then return end

    lib.callback('dps-airlines:server:startFlight', false, function(result, err)
        if not result then
            Bridge.Notify(err or 'Failed to start ferry flight', 'error')
            return
        end

        State.CurrentFlight = result
        State.FlightPhase = Constants.PHASE_GROUND
        State.FlightStartTime = GetGameTimer()

        Bridge.Notify('Ferry flight ' .. result.flightNumber .. ' created!', 'success')
        SpawnFlightAircraft(input[1], airportCode, result)
    end, {
        departure = airportCode,
        arrival = input[2],
        model = input[1],
        passengers = 0,
        cargoWeight = 0,
        flightType = 'ferry',
    })
end
