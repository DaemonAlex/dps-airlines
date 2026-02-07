Validation = {}

local rateLimits = {} -- [source][action] = lastTime

---Check if player is an airline employee
---@param source number
---@return boolean
function Validation.IsAirlineEmployee(source)
    local player = Bridge.GetPlayer(source)
    if not player then return false end
    return player.job.name == Config.Job
end

---Check if player has minimum grade
---@param source number
---@param minGrade number
---@return boolean
function Validation.HasMinGrade(source, minGrade)
    local player = Bridge.GetPlayer(source)
    if not player then return false end
    if player.job.name ~= Config.Job then return false end
    return player.job.grade >= minGrade
end

---Check if player is on duty
---@param source number
---@return boolean
function Validation.IsOnDuty(source)
    local player = Bridge.GetPlayer(source)
    if not player then return false end
    if player.job.name ~= Config.Job then return false end
    return player.job.onDuty
end

---Get the player's assigned role from DB
---@param source number
---@return string|nil
function Validation.GetPlayerRole(source)
    local player = Bridge.GetPlayer(source)
    if not player then return nil end

    local result = MySQL.scalar.await('SELECT role FROM airline_role_assignments WHERE citizenid = ?', { player.identifier })
    if result then return result end

    -- Fallback: derive from grade
    local grade = player.job.grade
    local roles = Constants.GradeToRoles[grade]
    if roles and #roles == 1 then
        return roles[1]
    end

    return nil
end

---Check if player can fly (pilot, copilot, or chief pilot)
---@param source number
---@return boolean
function Validation.CanFly(source)
    local role = Validation.GetPlayerRole(source)
    if not role then return false end
    local roleConfig = Config.Roles[role]
    if not roleConfig then return false end
    return roleConfig.canFly == true
end

---Check if player can dispatch
---@param source number
---@return boolean
function Validation.CanDispatch(source)
    local role = Validation.GetPlayerRole(source)
    if not role then return false end
    local roleConfig = Config.Roles[role]
    if not roleConfig then return false end
    return roleConfig.canDispatch == true
end

---Check if player can manage (boss menu)
---@param source number
---@return boolean
function Validation.CanManage(source)
    local role = Validation.GetPlayerRole(source)
    if not role then return false end
    local roleConfig = Config.Roles[role]
    if not roleConfig then return false end
    return roleConfig.canManage == true
end

---Rate limit a player action
---@param source number
---@param action string
---@param cooldownMs number
---@return boolean allowed
function Validation.RateLimit(source, action, cooldownMs)
    local now = GetGameTimer()
    if not rateLimits[source] then
        rateLimits[source] = {}
    end
    local lastTime = rateLimits[source][action]
    if lastTime and (now - lastTime) < cooldownMs then
        return false
    end
    rateLimits[source][action] = now
    return true
end

---Validate airport code exists
---@param code string
---@return boolean
function Validation.ValidateAirportCode(code)
    if type(code) ~= 'string' then return false end
    return Locations.GetAirport(code) ~= nil
end

---Validate passenger count for aircraft
---@param count number
---@param model string
---@return boolean
function Validation.ValidatePassengerCount(count, model)
    if type(count) ~= 'number' then return false end
    if count < Constants.PASSENGERS_MIN then return false end
    local aircraft = Locations.GetAircraftConfig(model)
    if not aircraft then return false end
    return count <= aircraft.passengers
end

---Validate cargo weight for aircraft
---@param weight number
---@param model string
---@return boolean
function Validation.ValidateCargoWeight(weight, model)
    if type(weight) ~= 'number' then return false end
    if weight < Constants.CARGO_MIN_WEIGHT then return false end
    local aircraft = Locations.GetAircraftConfig(model)
    if not aircraft then return false end
    return weight <= aircraft.cargo
end

---Validate flight completion (anti-cheat)
---@param source number
---@param flightData table
---@return boolean, string|nil reason
function Validation.ValidateFlightCompletion(source, flightData)
    if not flightData then return false, 'No flight data' end

    -- Check minimum flight time based on distance
    local route = Locations.GetRoute(flightData.departure, flightData.arrival)
    if not route then return false, 'Invalid route' end

    local distKm = route.distance / 1000.0
    local minTime = distKm * Constants.MIN_FLIGHT_TIME_PER_KM

    if flightData.duration and flightData.duration < minTime then
        Validation.LogSuspicious(source, 'fast_flight', string.format(
            'Flight %s->%s completed in %ds, minimum expected %ds',
            flightData.departure, flightData.arrival, flightData.duration, minTime
        ))
        return false, 'Flight completed too quickly'
    end

    -- Check player is near destination
    local ped = GetPlayerPed(source)
    if ped and ped > 0 then
        local destAirport = Locations.GetAirport(flightData.arrival)
        if destAirport then
            local playerCoords = GetEntityCoords(ped)
            local dist = #(playerCoords - destAirport.coords)
            if dist > Constants.DIST_APPROACH_DETECT then
                Validation.LogSuspicious(source, 'position_mismatch', string.format(
                    'Player %.0fm from destination %s on completion',
                    dist, flightData.arrival
                ))
                return false, 'Not near destination'
            end
        end
    end

    return true
end

---Validate a number is within range
---@param value any
---@param min number
---@param max number
---@return boolean
function Validation.ValidateNumber(value, min, max)
    if type(value) ~= 'number' then return false end
    return value >= min and value <= max
end

---Validate a string is non-empty and within length
---@param value any
---@param maxLen number
---@return boolean
function Validation.ValidateString(value, maxLen)
    if type(value) ~= 'string' then return false end
    return #value > 0 and #value <= maxLen
end

---Log suspicious activity
---@param source number
---@param action string
---@param details string
function Validation.LogSuspicious(source, action, details)
    local player = Bridge.GetPlayer(source)
    local name = player and player.fullName or ('Source:' .. source)
    local identifier = player and player.identifier or 'unknown'
    print(string.format('^1[DPS-Airlines SECURITY] Suspicious: %s (%s) - %s: %s^0',
        name, identifier, action, details))
end

---Full permission check wrapper for callbacks
---@param source number
---@param requirements table { employee?, minGrade?, onDuty?, canFly?, canDispatch?, canManage?, rateLimit? }
---@return boolean, string|nil reason
function Validation.Check(source, requirements)
    if requirements.employee ~= false then
        if not Validation.IsAirlineEmployee(source) then
            return false, 'Not an airline employee'
        end
    end

    if requirements.onDuty then
        if not Validation.IsOnDuty(source) then
            return false, 'Not on duty'
        end
    end

    if requirements.minGrade then
        if not Validation.HasMinGrade(source, requirements.minGrade) then
            return false, 'Insufficient grade'
        end
    end

    if requirements.canFly then
        if not Validation.CanFly(source) then
            return false, 'Not authorized to fly'
        end
    end

    if requirements.canDispatch then
        if not Validation.CanDispatch(source) then
            return false, 'Not authorized to dispatch'
        end
    end

    if requirements.canManage then
        if not Validation.CanManage(source) then
            return false, 'Not authorized to manage'
        end
    end

    if requirements.rateLimit then
        local action = requirements.rateLimit.action or 'default'
        local cooldown = requirements.rateLimit.cooldown or Constants.THROTTLE_NORMAL
        if not Validation.RateLimit(source, action, cooldown) then
            return false, 'Rate limited'
        end
    end

    return true
end

-- Cleanup rate limits when player drops
AddEventHandler('playerDropped', function()
    local source = source
    rateLimits[source] = nil
end)
