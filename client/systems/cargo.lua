-- Client: Cargo system

---Open cargo management menu
function OpenCargoMenu()
    lib.registerContext({
        id = 'airline_cargo',
        title = 'Cargo Management',
        options = {
            {
                title = 'View Cargo Contracts',
                description = 'Available and active contracts',
                icon = 'file-contract',
                onSelect = function()
                    ViewCargoContracts()
                end,
            },
            {
                title = 'Load Cargo',
                description = 'Load cargo onto aircraft',
                icon = 'box',
                onSelect = function()
                    LoadCargo()
                end,
                disabled = State.CurrentPlane == nil,
            },
            {
                title = 'Unload Cargo',
                description = 'Unload cargo from aircraft',
                icon = 'box-open',
                onSelect = function()
                    UnloadCargo()
                end,
                disabled = State.CurrentPlane == nil,
            },
        },
    })
    lib.showContext('airline_cargo')
end

---View cargo contracts
function ViewCargoContracts()
    lib.callback('dps-airlines:server:getCargoContracts', false, function(contracts)
        if not contracts or #contracts == 0 then
            Bridge.Notify('No contracts available', 'inform')
            return
        end

        local options = {}
        for _, contract in ipairs(contracts) do
            local statusLabel = contract.status == 'available' and 'Available' or
                               string.format('%d/%d deliveries', contract.completed_deliveries, contract.total_deliveries)

            options[#options + 1] = {
                title = contract.contract_name,
                description = string.format(
                    'Client: %s | Type: %s | Weight: %dkg | Pay: $%d/delivery | %s',
                    contract.client_name, contract.cargo_type, contract.weight_per_delivery,
                    contract.pay_per_delivery, statusLabel
                ),
                icon = contract.status == 'available' and 'plus-circle' or 'truck-loading',
                onSelect = function()
                    if contract.status == 'available' then
                        AcceptContract(contract.id)
                    else
                        Bridge.Notify(string.format('Progress: %d/%d deliveries', contract.completed_deliveries, contract.total_deliveries), 'inform')
                    end
                end,
            }
        end

        lib.registerContext({
            id = 'airline_cargo_contracts',
            title = 'Cargo Contracts',
            menu = 'airline_cargo',
            options = options,
        })
        lib.showContext('airline_cargo_contracts')
    end)
end

---Accept a cargo contract
---@param contractId number
function AcceptContract(contractId)
    lib.callback('dps-airlines:server:acceptCargoContract', false, function(success, result)
        if success then
            Bridge.Notify('Contract accepted! Start delivering.', 'success')
        else
            Bridge.Notify(result or 'Failed to accept contract', 'error')
        end
    end, contractId)
end

---Load cargo animation
function LoadCargo()
    if not State.CurrentPlane or not DoesEntityExist(State.CurrentPlane) then
        Bridge.Notify('No aircraft nearby', 'error')
        return
    end

    local success = lib.progressBar({
        duration = 10000,
        label = 'Loading cargo...',
        useWhileDead = false,
        canCancel = true,
        anim = {
            dict = 'anim@heists@box_carry@',
            clip = 'idle',
        },
    })

    if success then
        Bridge.Notify('Cargo loaded!', 'success')
    end
end

---Unload cargo animation
function UnloadCargo()
    if not State.CurrentPlane or not DoesEntityExist(State.CurrentPlane) then
        Bridge.Notify('No aircraft nearby', 'error')
        return
    end

    local success = lib.progressBar({
        duration = 8000,
        label = 'Unloading cargo...',
        useWhileDead = false,
        canCancel = true,
        anim = {
            dict = 'anim@heists@box_carry@',
            clip = 'idle',
        },
    })

    if success then
        Bridge.Notify('Cargo unloaded!', 'success')
    end
end
