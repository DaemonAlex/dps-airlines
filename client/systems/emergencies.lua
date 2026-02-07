-- Client: Emergency system

---Trigger an in-flight emergency
---@param emergencyType string
function TriggerEmergency(emergencyType)
    if not State.CurrentFlight then
        Bridge.Notify('No active flight', 'error')
        return
    end

    local emergencies = {
        engine_failure = {
            label = 'Engine Failure',
            effect = function()
                if State.CurrentPlane and DoesEntityExist(State.CurrentPlane) then
                    SetVehicleEngineHealth(State.CurrentPlane, 100.0)
                    Bridge.Notify('ENGINE FAILURE! Attempt emergency landing!', 'error', 10000)
                end
            end,
        },
        bird_strike = {
            label = 'Bird Strike',
            effect = function()
                if State.CurrentPlane and DoesEntityExist(State.CurrentPlane) then
                    SetVehicleEngineHealth(State.CurrentPlane, GetVehicleEngineHealth(State.CurrentPlane) - 200.0)
                    Bridge.Notify('BIRD STRIKE! Check engine status!', 'error', 5000)
                end
            end,
        },
        hydraulic_failure = {
            label = 'Hydraulic Failure',
            effect = function()
                Bridge.Notify('HYDRAULIC FAILURE! Controls affected!', 'error', 8000)
            end,
        },
        cabin_depressure = {
            label = 'Cabin Depressurization',
            effect = function()
                Bridge.Notify('CABIN DEPRESSURIZATION! Descend to 10,000ft!', 'error', 10000)
                -- Visual effect
                SetTimecycleModifier('spectator5')
                SetTimeout(15000, function()
                    ClearTimecycleModifier()
                end)
            end,
        },
        electrical = {
            label = 'Electrical Failure',
            effect = function()
                if State.CurrentPlane and DoesEntityExist(State.CurrentPlane) then
                    SetVehicleLights(State.CurrentPlane, 1)
                    Bridge.Notify('ELECTRICAL FAILURE! Instruments offline!', 'error', 8000)
                end
            end,
        },
    }

    local emergency = emergencies[emergencyType]
    if not emergency then return end

    emergency.effect()

    -- Log to server
    if State.CurrentFlight then
        TriggerServerEvent('dps-airlines:server:logEmergency', State.CurrentFlight.flightId, emergencyType)
    end
end

---Open emergency menu (for testing / random events)
function OpenEmergencyMenu()
    if not State.CurrentFlight then
        Bridge.Notify('No active flight', 'error')
        return
    end

    lib.registerContext({
        id = 'airline_emergency',
        title = 'Emergency Procedures',
        options = {
            {
                title = 'Declare Emergency',
                description = 'Declare a general emergency',
                icon = 'exclamation-triangle',
                onSelect = function()
                    Bridge.Notify('MAYDAY MAYDAY MAYDAY - Emergency declared', 'error', 10000)
                end,
            },
            {
                title = 'Emergency Landing',
                description = 'Attempt emergency landing at nearest airport',
                icon = 'plane-arrival',
                onSelect = function()
                    local nearestCode = Locations.GetNearestAirport(GetEntityCoords(PlayerPedId()))
                    if nearestCode then
                        local airport = Locations.GetAirport(nearestCode)
                        SetNewWaypoint(airport.coords.x, airport.coords.y)
                        Bridge.Notify('Nearest airport: ' .. airport.label .. ' - Waypoint set', 'inform')
                    end
                end,
            },
        },
    })
    lib.showContext('airline_emergency')
end

-- Random emergency event system (small chance during flights)
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute

        if State.CurrentFlight and State.FlightPhase == Constants.PHASE_CRUISE then
            -- 2% chance per minute of minor emergency
            if math.random(100) <= 2 then
                local types = { 'bird_strike', 'hydraulic_failure', 'electrical' }
                local randomType = types[math.random(#types)]
                TriggerEmergency(randomType)
            end
        end
    end
end)
