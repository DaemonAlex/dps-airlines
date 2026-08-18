Payments = {}

---Calculate flight pay based on server-validated flight data
---@param flightData table { distance, passengers, cargoWeight, weatherSeverity, priority, isNight, isEmergency, duration }
---@return number totalPay
function Payments.CalculateFlightPay(flightData)
    local cfg = Config.FlightPay
    local pay = cfg.baseRate

    -- Distance component
    local distKm = (flightData.distance or 0) / 1000.0
    pay = pay + (distKm * cfg.perKilometer)

    -- Passenger component
    pay = pay + ((flightData.passengers or 0) * cfg.perPassenger)

    -- Cargo component (convert kg to tons)
    local cargoTons = (flightData.cargoWeight or 0) / 1000.0
    pay = pay + (cargoTons * cfg.perCargoTon)

    -- Weather multiplier
    local weatherSev = flightData.weatherSeverity or Constants.WEATHER_CLEAR
    local weatherMult = Constants.WeatherMultipliers[weatherSev] or 1.0
    pay = pay * weatherMult

    -- Priority multiplier
    if flightData.priority then
        pay = pay * cfg.priorityMultiplier
    end

    -- Night flying bonus
    if flightData.isNight then
        pay = pay * cfg.nightMultiplier
    end

    -- Emergency bonus
    if flightData.isEmergency then
        pay = pay + cfg.emergencyBonus
    end

    return math.floor(pay)
end

---Distribute crew pay based on role multipliers.
---The total disbursed across all crew is capped at `totalPay`; if the sum of the
---computed shares exceeds the flight pay, every share is scaled down proportionally
---so the company never mints more than it earned for the flight (M2 fix).
---@param totalPay number
---@param crewMembers table[] { source, role }
---@return table[] { source, role, amount }
function Payments.DistributeCrewPay(totalPay, crewMembers)
    local payouts = {}
    local sum = 0

    for _, member in ipairs(crewMembers) do
        local roleConfig = Config.Roles[member.role]
        -- Skip anyone already paid for this flight. Flight attendants collect via
        -- attendantService (which stamps pay_amount on the crew row) and were then
        -- paid the flat rate AGAIN here at completion - double pay per flight.
        if roleConfig and (tonumber(member.pay_amount) or 0) == 0 then
            local amount = 0

            if member.role == Constants.ROLE_CAPTAIN or member.role == Constants.ROLE_CHIEF_PILOT then
                amount = math.floor(totalPay * (roleConfig.payMultiplier or 1.0))
            elseif member.role == Constants.ROLE_FIRST_OFFICER then
                amount = math.floor(totalPay * (roleConfig.payMultiplier or 0.7))
            elseif member.role == Constants.ROLE_FLIGHT_ATTENDANT then
                amount = roleConfig.flatRate or 150
            elseif member.role == Constants.ROLE_GROUND_CREW then
                amount = roleConfig.taskBonus or 25
            elseif member.role == Constants.ROLE_DISPATCHER then
                amount = math.floor(totalPay * (roleConfig.commissionPercent or 0.05))
            end

            sum = sum + amount
            payouts[#payouts + 1] = {
                source = member.source,
                citizenid = member.citizenid,
                role = member.role,
                amount = amount,
            }
        end
    end

    -- Cap total crew disbursement to the flight's computed pay. Scale shares to fit.
    if totalPay > 0 and sum > totalPay then
        local scale = totalPay / sum
        for _, payout in ipairs(payouts) do
            payout.amount = math.floor(payout.amount * scale)
        end
    end

    return payouts
end

---Calculate charter price (server-side only, no client input)
---@param fromCode string
---@param toCode string
---@param passengers number
---@param vip boolean
---@param luggage number
---@return number price
function Payments.CalculateCharterPrice(fromCode, toCode, passengers, vip, luggage)
    local cfg = Config.Charter
    local route = Locations.GetRoute(fromCode, toCode)
    if not route then return cfg.minPrice end

    local distKm = route.distance / 1000.0
    local price = cfg.basePrice

    -- Distance component
    price = price + (distKm * cfg.perKilometer)

    -- Passenger component
    price = price + ((passengers or 0) * cfg.perPassenger)

    -- VIP multiplier
    if vip then
        price = price * cfg.vipMultiplier
    end

    -- Luggage fee
    price = price + ((luggage or 0) * cfg.luggageFee)

    -- Clamp
    price = math.max(cfg.minPrice, math.min(cfg.maxPrice, math.floor(price)))

    return price
end

---Calculate ground task pay
---@param taskType string
---@return number
function Payments.CalculateGroundTaskPay(taskType)
    local roleConfig = Config.Roles[Constants.ROLE_GROUND_CREW]
    return roleConfig and roleConfig.taskBonus or 25
end

---Calculate dispatcher salary per cycle
---@return number
function Payments.CalculateDispatcherSalary()
    local roleConfig = Config.Roles[Constants.ROLE_DISPATCHER]
    return roleConfig and roleConfig.salaryPerCycle or 200
end

-- Map operation type identifiers to their Config.Helicopters keys.
-- (The opType constants are 'vip_transport'/'search_rescue' but the config keys
-- are 'vip'/'searchRescue' - without this map those ops silently paid $0.)
Payments.HeliOpConfigKey = {
    [Constants.HELI_MEDEVAC] = 'medevac',
    [Constants.HELI_TOUR]    = 'tour',
    [Constants.HELI_VIP]     = 'vip',
    [Constants.HELI_SEARCH]  = 'searchRescue',
}

---Calculate helicopter operation pay.
---IMPORTANT: `details` here is built ENTIRELY server-side by the completeHeliOp
---callback (timeRemaining from the server clock, waypoints from elapsed server time,
---rescued/near-destination from the server-sampled player position). Never pass raw
---client input to this function. Bonus inputs are additionally clamped here as
---defence-in-depth so no single value can inflate the payout (C1 fix).
---@param opType string
---@param details table { timeRemaining?, waypointsHit?, rescued? } - server-derived only
---@return number
function Payments.CalculateHeliPay(opType, details)
    local cfg = Config.Helicopters
    if not cfg then return 0 end
    local key = Payments.HeliOpConfigKey[opType]
    local opCfg = key and cfg[key]
    if not opCfg then return 0 end

    details = details or {}
    local pay = opCfg.basePay or 0

    if opType == Constants.HELI_MEDEVAC then
        local maxT = opCfg.timeLimit or 300
        local timeSaved = math.max(0, math.min(details.timeRemaining or 0, maxT))
        pay = pay + (timeSaved * (opCfg.bonusPerSecondSaved or 5))

    elseif opType == Constants.HELI_TOUR then
        local waypoints = math.max(0, math.min(details.waypointsHit or 0, Constants.TOUR_MAX_WAYPOINTS))
        pay = pay + (waypoints * (opCfg.waypointBonus or 50))

    elseif opType == Constants.HELI_VIP then
        -- Landing smoothness / lateness are not verifiable server-side at completion
        -- (the aircraft is already parked), so no touchdown bonus/penalty is applied.
        -- VIP transport pays its flat base rate only.

    elseif opType == Constants.HELI_SEARCH then
        if details.rescued then
            pay = pay + (opCfg.rescueBonus or 300)
        end
    end

    return math.max(0, math.floor(pay))
end

---Calculate landing quality bonus multiplier
---@param verticalSpeed number
---@return number multiplier, string label
function Payments.GetLandingBonus(verticalSpeed)
    local absSpeed = math.abs(verticalSpeed)
    for _, rating in ipairs(Constants.LandingRatings) do
        if absSpeed <= rating.threshold then
            return rating.bonus, rating.label
        end
    end
    return 0.0, 'Crash'
end

---Calculate cargo contract completion pay
---@param contract table
---@return number
function Payments.CalculateContractPay(contract)
    local basePay = contract.pay_per_delivery or 500
    local isComplete = (contract.completed_deliveries + 1) >= contract.total_deliveries
    local bonus = isComplete and (contract.completion_bonus or 0) or 0
    return basePay + bonus
end

---Pay a player through the bridge
---@param source number
---@param amount number
---@param reason string
---@return boolean
function Payments.PayPlayer(source, amount, reason)
    if amount <= 0 then return false end
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    local success, err = pcall(function()
        player.addMoney('bank', amount, reason or 'airline_payment')
    end)

    if success then
        -- Log to company ledger
        pcall(function()
            MySQL.insert.await(
                'INSERT INTO airline_company_ledger (transaction_type, amount, description, initiated_by) VALUES (?, ?, ?, ?)',
                { 'payment', -amount, reason, player.identifier }
            )
        end)
    else
        print('^1[DPS-Airlines] Payment failed for source ' .. source .. ': ' .. tostring(err) .. '^0')
    end

    return success
end

---Charge a player
---@param source number
---@param amount number
---@param reason string
---@return boolean
function Payments.ChargePlayer(source, amount, reason)
    if amount <= 0 then return false end
    local player = Bridge.GetPlayer(source)
    if not player then return false end

    if player.getMoney('bank') < amount then
        if player.getMoney('cash') < amount then
            return false
        end
        player.removeMoney('cash', amount, reason or 'airline_charge')
    else
        player.removeMoney('bank', amount, reason or 'airline_charge')
    end

    pcall(function()
        MySQL.insert.await(
            'INSERT INTO airline_company_ledger (transaction_type, amount, description, initiated_by) VALUES (?, ?, ?, ?)',
            { 'revenue', amount, reason, player.identifier }
        )
    end)

    return true
end

---Add money to society account
---@param amount number
---@param reason string
---@return boolean
function Payments.AddToSociety(amount, reason)
    local success = Bridge.AddSocietyMoney(Config.SocietyAccount, amount)
    if success then
        pcall(function()
            MySQL.insert.await(
                'INSERT INTO airline_company_ledger (transaction_type, amount, description) VALUES (?, ?, ?)',
                { 'society_deposit', amount, reason }
            )
        end)
    end
    return success
end
