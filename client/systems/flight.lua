-- Client: Flight system - monitoring, phase detection, completion

local flightMonitorActive = false

---Detect the current flight phase based on vehicle state
---@param vehicle number
---@return number phase
local function DetectFlightPhase(vehicle)
    if not DoesEntityExist(vehicle) then return Constants.PHASE_GROUND end

    local speed = GetEntitySpeed(vehicle) * 3.6 -- km/h
    local heightAboveGround = GetEntityHeightAboveGround(vehicle)
    local isInAir = not IsEntityOnScreen(vehicle) or heightAboveGround > 3.0

    if not IsVehicleEngineOn(vehicle) then
        return Constants.PHASE_GROUND
    end

    if heightAboveGround > 50.0 then
        -- Check if approaching destination
        if State.CurrentFlight then
            local destAirport = Locations.GetAirport(State.CurrentFlight.arrival)
            if destAirport then
                local dist = #(GetEntityCoords(vehicle) - destAirport.coords)
                if dist < Constants.DIST_APPROACH_DETECT then
                    return Constants.PHASE_APPROACH
                end
            end
        end
        return Constants.PHASE_CRUISE
    end

    if speed > 10 and heightAboveGround < 5.0 then
        if State.FlightPhase == Constants.PHASE_GROUND or State.FlightPhase == Constants.PHASE_TAXIING then
            return Constants.PHASE_TAXIING
        end
    end

    if heightAboveGround > 3.0 and heightAboveGround <= 50.0 then
        if State.FlightPhase <= Constants.PHASE_TAXIING then
            return Constants.PHASE_TAKEOFF
        else
            return Constants.PHASE_APPROACH
        end
    end

    if State.FlightPhase >= Constants.PHASE_APPROACH and heightAboveGround < Constants.DIST_COMPLETION_AGL and speed < 5 then
        return Constants.PHASE_LANDED
    end

    return State.FlightPhase
end

---Start monitoring the current flight
function StartFlightMonitor()
    if flightMonitorActive then return end
    flightMonitorActive = true

    CreateThread(function()
        while flightMonitorActive and State.CurrentFlight do
            Wait(500)

            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle == 0 then
                -- Not in vehicle, check if we should stop monitoring
                if State.FlightPhase >= Constants.PHASE_CRUISE then
                    -- Fell out of plane during flight
                    Bridge.Notify('You left the aircraft during flight!', 'error')
                end
                goto continue
            end

            if vehicle ~= State.CurrentPlane then
                goto continue
            end

            -- Detect phase
            local newPhase = DetectFlightPhase(vehicle)
            if newPhase ~= State.FlightPhase then
                local oldPhase = State.FlightPhase
                State.FlightPhase = newPhase

                -- Phase change notifications
                local phaseName = Constants.PhaseNames[newPhase] or 'Unknown'
                Bridge.Notify('Flight Phase: ' .. phaseName, 'inform')

                -- Check for landing completion
                if newPhase == Constants.PHASE_LANDED and oldPhase == Constants.PHASE_APPROACH then
                    CheckFlightCompletion(vehicle)
                end
            end

            -- Update fuel
            if Config.Fuel.enabled and State.FlightPhase >= Constants.PHASE_TAXIING then
                UpdateFuel(vehicle, 0.5)
            end

            -- Update flight tracker (throttled)
            local now = GetGameTimer()
            if now - State.LastTrackerUpdate > 2000 then
                State.LastTrackerUpdate = now
                UpdateFlightTracker(vehicle)
            end

            ::continue::
        end

        flightMonitorActive = false
    end)
end

---Stop the flight monitor
function StopFlightMonitor()
    flightMonitorActive = false
end

---Check if the flight can be completed
---@param vehicle number
function CheckFlightCompletion(vehicle)
    if not State.CurrentFlight then return end

    local destAirport = Locations.GetAirport(State.CurrentFlight.arrival)
    if not destAirport then return end

    local coords = GetEntityCoords(vehicle)
    local dist = #(coords - destAirport.coords)

    if dist > Constants.DIST_COMPLETION then
        Bridge.Notify('Not close enough to destination airport', 'error')
        return
    end

    -- Calculate landing speed
    local velocity = GetEntityVelocity(vehicle)
    local verticalSpeed = math.abs(velocity.z)

    -- Calculate duration
    local duration = (GetGameTimer() - State.FlightStartTime) / 1000

    -- Detect weather and night
    local hour = GetClockHours()
    local isNight = hour < 6 or hour > 20
    local weatherHash = GetPrevWeatherTypeHashName()
    local weatherSeverity = Constants.WEATHER_CLEAR

    if weatherHash == joaat('RAIN') or weatherHash == joaat('THUNDER') then
        weatherSeverity = Constants.WEATHER_SEVERE
    elseif weatherHash == joaat('FOGGY') or weatherHash == joaat('SMOG') then
        weatherSeverity = Constants.WEATHER_MODERATE
    elseif weatherHash == joaat('CLOUDS') or weatherHash == joaat('OVERCAST') then
        weatherSeverity = Constants.WEATHER_LIGHT
    end

    -- Complete on server
    lib.callback('dps-airlines:server:completeFlight', false, function(result, err)
        if not result then
            Bridge.Notify(err or 'Failed to complete flight', 'error')
            return
        end

        Bridge.Notify(string.format(
            'Flight complete! Landing: %s | Pay: $%d',
            result.landingQuality, result.pay
        ), 'success', 10000)

        -- Show detailed results in NUI
        OpenNUI('overview', {
            flightResult = result,
        })

        -- Cleanup
        StopFlightMonitor()
        State.ResetFlight()
    end, {
        flightId = State.CurrentFlight.flightId,
        landingSpeed = verticalSpeed,
        duration = duration,
        fuelUsed = Constants.FUEL_MAX - State.FuelLevel,
        weatherSeverity = weatherSeverity,
        weatherCondition = Constants.PhaseNames[weatherSeverity] or 'clear',
        isNight = isNight,
    })
end

---Fail/cancel the current flight
function FailCurrentFlight(reason)
    if not State.CurrentFlight then return end

    lib.callback('dps-airlines:server:failFlight', false, function(success)
        if success then
            Bridge.Notify('Flight cancelled: ' .. (reason or 'Unknown'), 'error')
        end
        StopFlightMonitor()
        State.ResetFlight()
    end, State.CurrentFlight.flightId, reason)
end

---Update flight tracker data
---@param vehicle number
function UpdateFlightTracker(vehicle)
    if not State.CurrentFlight or not DoesEntityExist(vehicle) then return end

    local coords = GetEntityCoords(vehicle)
    local heading = GetEntityHeading(vehicle)
    local speed = GetEntitySpeed(vehicle) * 1.94384 -- m/s to knots

    TriggerServerEvent('dps-airlines:server:updateTracker', State.CurrentFlight.flightId, {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading,
        speed = speed,
        altitude = coords.z,
        fuel = State.FuelLevel,
        phase = State.FlightPhase,
    })
end

-- Vehicle destruction detection
CreateThread(function()
    while true do
        Wait(2000)
        if State.CurrentPlane and State.CurrentFlight then
            if not DoesEntityExist(State.CurrentPlane) or IsEntityDead(State.CurrentPlane) then
                FailCurrentFlight('Aircraft destroyed')
            end
        end
    end
end)
