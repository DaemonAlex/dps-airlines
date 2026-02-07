-- Server: Cargo system & cargo contracts

-- Get available cargo contracts
lib.callback.register('dps-airlines:server:getCargoContracts', function(source)
    local ok = Validation.Check(source, { employee = true, onDuty = true })
    if not ok then return {} end

    local player = Bridge.GetPlayer(source)
    if not player then return {} end

    -- Get contracts assigned to player or available
    return MySQL.query.await([[
        SELECT * FROM airline_cargo_contracts
        WHERE (assigned_to = ? OR (assigned_to IS NULL AND status = 'available'))
        ORDER BY deadline ASC
        LIMIT 20
    ]], { player.identifier })
end)

-- Accept a cargo contract
lib.callback.register('dps-airlines:server:acceptCargoContract', function(source, contractId)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true,
        rateLimit = { action = 'acceptContract', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return false, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    -- Check contract available
    local contract = MySQL.single.await(
        'SELECT * FROM airline_cargo_contracts WHERE id = ? AND status = ? AND assigned_to IS NULL',
        { contractId, 'available' }
    )
    if not contract then return false, 'Contract not available' end

    -- Check player doesn't have too many active contracts
    local activeCount = MySQL.scalar.await(
        'SELECT COUNT(*) FROM airline_cargo_contracts WHERE assigned_to = ? AND status = ?',
        { player.identifier, Constants.DB_STATUS_ACTIVE }
    )
    if activeCount >= 3 then return false, 'Maximum 3 active contracts' end

    MySQL.update.await(
        'UPDATE airline_cargo_contracts SET assigned_to = ?, status = ? WHERE id = ?',
        { player.identifier, Constants.DB_STATUS_ACTIVE, contractId }
    )

    return true, contract
end)

-- Complete a cargo delivery (part of a contract)
lib.callback.register('dps-airlines:server:completeCargoDelivery', function(source, contractId, flightId)
    local ok, reason = Validation.Check(source, {
        employee = true, onDuty = true,
        rateLimit = { action = 'cargoDelivery', cooldown = Constants.THROTTLE_VERY_SLOW },
    })
    if not ok then return false, reason end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    local contract = MySQL.single.await(
        'SELECT * FROM airline_cargo_contracts WHERE id = ? AND assigned_to = ? AND status = ?',
        { contractId, player.identifier, Constants.DB_STATUS_ACTIVE }
    )
    if not contract then return false, 'Contract not found' end

    -- Increment completed deliveries
    local newCompleted = contract.completed_deliveries + 1
    local isComplete = newCompleted >= contract.total_deliveries

    local newStatus = isComplete and Constants.DB_STATUS_COMPLETED or Constants.DB_STATUS_ACTIVE
    MySQL.update.await(
        'UPDATE airline_cargo_contracts SET completed_deliveries = ?, status = ? WHERE id = ?',
        { newCompleted, newStatus, contractId }
    )

    -- Calculate and pay
    local pay = Payments.CalculateContractPay(contract)

    -- Check deadline
    if contract.deadline then
        local deadline = contract.deadline
        -- If past deadline, apply penalty
        -- (simplified - in production you'd parse the timestamp)
    end

    Payments.PayPlayer(source, pay, 'Cargo contract delivery ' .. newCompleted .. '/' .. contract.total_deliveries)

    if isComplete then
        -- Pay completion bonus
        if contract.completion_bonus > 0 then
            Payments.PayPlayer(source, contract.completion_bonus, 'Cargo contract completion bonus')
        end
    end

    Cache.Invalidate('stats_' .. player.identifier)

    return true, {
        pay = pay,
        completed = newCompleted,
        total = contract.total_deliveries,
        isComplete = isComplete,
        bonus = isComplete and contract.completion_bonus or 0,
    }
end)

-- Generate random cargo contracts (runs periodically)
CreateThread(function()
    Wait(10000)
    while true do
        -- Check how many available contracts exist
        local available = MySQL.scalar.await(
            'SELECT COUNT(*) FROM airline_cargo_contracts WHERE status = ?',
            { 'available' }
        )

        if available < 5 then
            local airports = {}
            for code in pairs(Locations.Airports) do
                airports[#airports + 1] = code
            end

            local cargoTypes = { 'general', 'fragile', 'perishable', 'hazardous', 'medical', 'electronics' }
            local clientNames = { 'Pacific Freight Co.', 'LS Logistics', 'Santos Express', 'Blaine Cargo', 'Merryweather Shipping', 'PostOP' }

            local numToCreate = 5 - available
            for i = 1, numToCreate do
                local from = airports[math.random(#airports)]
                local to = airports[math.random(#airports)]
                while to == from do to = airports[math.random(#airports)] end

                local deliveries = math.random(Config.CargoContracts.minDeliveries, Config.CargoContracts.maxDeliveries)
                local weight = math.random(200, 2000)
                local payPerDelivery = math.floor(weight * 0.5 + math.random(100, 500))
                local bonus = math.floor(payPerDelivery * deliveries * Config.CargoContracts.completionBonusPercent)

                MySQL.insert.await([[
                    INSERT INTO airline_cargo_contracts
                    (contract_name, client_name, total_deliveries, cargo_type, weight_per_delivery,
                     pay_per_delivery, completion_bonus, deadline, status)
                    VALUES (?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR), 'available')
                ]], {
                    from .. ' → ' .. to .. ' Cargo Run',
                    clientNames[math.random(#clientNames)],
                    deliveries,
                    cargoTypes[math.random(#cargoTypes)],
                    weight,
                    payPerDelivery,
                    bonus,
                    Config.CargoContracts.deadlineHours,
                })
            end
        end

        Wait(1800000) -- Check every 30 minutes
    end
end)
