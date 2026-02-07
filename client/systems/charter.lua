-- Client: Charter system (menu is in pilot.lua, this handles charter-specific logic)

-- Charter flight NPC interactions at airports
CreateThread(function()
    Wait(2000)

    for code, airport in pairs(Locations.Airports) do
        if airport.terminals and airport.terminals.charter then
            exports.ox_target:addSphereZone({
                coords = airport.terminals.charter,
                radius = Config.InteractDistance,
                name = 'airline_charter_' .. code,
                options = {
                    {
                        name = 'airline_charter_book',
                        label = 'Book Charter Flight',
                        icon = 'fas fa-ticket-alt',
                        onSelect = function()
                            if State.CanFly() and State.OnDuty then
                                OpenCharterMenu(code)
                            else
                                Bridge.Notify('Must be an on-duty pilot to book charters', 'error')
                            end
                        end,
                        canInteract = function()
                            return State.IsEmployee() and State.OnDuty and State.CanFly()
                        end,
                    },
                },
            })
        end
    end
end)
