-- Client: Maintenance system - target zones at maintenance terminals

CreateThread(function()
    Wait(2000)

    for code, airport in pairs(Locations.Airports) do
        if airport.terminals and airport.terminals.maintenance then
            exports.ox_target:addSphereZone({
                coords = airport.terminals.maintenance,
                radius = Config.InteractDistance,
                name = 'airline_maint_' .. code,
                options = {
                    {
                        name = 'airline_maintenance_check',
                        label = 'Aircraft Maintenance',
                        icon = 'fas fa-wrench',
                        onSelect = function()
                            OpenMaintenanceMenu(code)
                        end,
                        canInteract = function()
                            if not State.IsEmployee() or not State.OnDuty then return false end
                            local role = State.Role
                            return role == Constants.ROLE_GROUND_CREW or role == Constants.ROLE_CHIEF_PILOT
                        end,
                    },
                },
            })
        end
    end
end)
