-- Client: Dynamic fuel system

---Update fuel level for vehicle
---@param vehicle number
---@param deltaTime number seconds since last update
function UpdateFuel(vehicle, deltaTime)
    if not Config.Fuel.enabled then return end
    if not DoesEntityExist(vehicle) then return end

    local aircraft = Locations.GetAircraftConfig(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower())
    if not aircraft then
        -- Try helicopter
        local heli = Locations.GetHeliConfig(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower())
        if heli then
            aircraft = { fuelRate = heli.fuelRate, cargo = 0 }
        else
            return
        end
    end

    -- Calculate burn rate
    local baseBurn = Constants.FUEL_BASE_BURN_RATE
    local planeMult = aircraft.fuelRate or 1.0

    -- Weight factor based on cargo
    local cargoWeight = State.CurrentFlight and State.CurrentFlight.cargoWeight or 0
    local weightFactor = 1.0 + (cargoWeight * Config.Fuel.weightFactor)

    -- Speed factor
    local speed = GetEntitySpeed(vehicle)
    local speedFactor = math.max(0.5, speed / 50.0)

    -- Total burn per second
    local burnRate = baseBurn * planeMult * weightFactor * speedFactor

    -- Only burn fuel when engine is running
    if IsVehicleEngineOn(vehicle) then
        State.FuelLevel = math.max(0, State.FuelLevel - (burnRate * deltaTime))
    end

    -- Warnings
    if State.FuelLevel <= Constants.FUEL_CRITICAL_WARNING then
        if State.FuelLevel > 0 then
            Bridge.Notify('CRITICAL: Fuel critically low! Land immediately!', 'error')
        else
            -- Engine failure
            SetVehicleEngineOn(vehicle, false, true, true)
            Bridge.Notify('ENGINE FAILURE: Out of fuel!', 'error')
        end
    elseif State.FuelLevel <= Constants.FUEL_LOW_WARNING then
        Bridge.Notify('Warning: Fuel level low (' .. math.floor(State.FuelLevel) .. '%)', 'error')
    end

    -- Update HUD (via NUI)
    SendNUIMessage({
        action = 'updateFuel',
        data = {
            level = math.floor(State.FuelLevel),
            burnRate = burnRate,
        },
    })
end

---Refuel the current aircraft
---@param vehicle number
function RefuelAircraft(vehicle)
    if not DoesEntityExist(vehicle) then return end

    -- Check if at fuel terminal
    local coords = GetEntityCoords(vehicle)
    local nearFuel = false
    local nearestCode = Locations.GetNearestAirport(coords)
    if nearestCode then
        local airport = Locations.GetAirport(nearestCode)
        if airport and airport.terminals and airport.terminals.fuel then
            local dist = #(coords - airport.terminals.fuel)
            if dist < 50.0 then
                nearFuel = true
            end
        end
    end

    if not nearFuel then
        Bridge.Notify('Must be near a fuel terminal', 'error')
        return
    end

    local fuelNeeded = Constants.FUEL_MAX - State.FuelLevel
    if fuelNeeded <= 0 then
        Bridge.Notify('Tank is already full', 'inform')
        return
    end

    local cost = math.floor(fuelNeeded * Config.Fuel.refuelCostPerUnit)

    local duration = math.floor(fuelNeeded / Config.Fuel.refuelRate) * 1000

    local success = lib.progressBar({
        duration = duration,
        label = string.format('Refueling... ($%d)', cost),
        useWhileDead = false,
        canCancel = true,
    })

    if success then
        State.FuelLevel = Constants.FUEL_MAX
        Bridge.Notify(string.format('Refueled! Cost: $%d', cost), 'success')
    end
end
