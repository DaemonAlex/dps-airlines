-- Client: Crew management system

---Open crew management menu
function OpenCrewMenu()
    if not State.CurrentFlight then
        Bridge.Notify('Start a flight first to manage crew', 'error')
        return
    end

    lib.callback('dps-airlines:server:getFlightCrew', false, function(crew)
        local options = {
            {
                title = 'Invite Crew Member',
                description = 'Invite nearby airline employee',
                icon = 'user-plus',
                onSelect = function()
                    InviteCrewMember()
                end,
            },
        }

        if crew and #crew > 0 then
            for _, member in ipairs(crew) do
                local roleLabel = Config.Roles[member.role] and Config.Roles[member.role].label or member.role
                options[#options + 1] = {
                    title = member.citizenid,
                    description = string.format('Role: %s | Rating: %.1f | Hours: %.1f',
                        roleLabel, member.service_rating or 0, member.flight_hours or 0),
                    icon = 'user',
                    onSelect = function()
                        ManageCrewMember(member)
                    end,
                }
            end
        end

        lib.registerContext({
            id = 'airline_crew',
            title = 'Crew Management',
            options = options,
        })
        lib.showContext('airline_crew')
    end, State.CurrentFlight.flightId)
end

---Invite a nearby crew member
function InviteCrewMember()
    if not State.CurrentFlight then return end

    local players = lib.getNearbyPlayers(GetEntityCoords(PlayerPedId()), Config.Crew.inviteRange, true)

    if not players or #players == 0 then
        Bridge.Notify('No nearby players', 'error')
        return
    end

    local playerOptions = {}
    for _, p in ipairs(players) do
        local serverId = GetPlayerServerId(p.id)
        playerOptions[#playerOptions + 1] = {
            label = 'Player ' .. serverId,
            value = serverId,
        }
    end

    local input = lib.inputDialog('Invite Crew Member', {
        { type = 'select', label = 'Player', options = playerOptions, required = true },
    })

    if not input then return end

    lib.callback('dps-airlines:server:inviteCrew', false, function(success, err)
        if success then
            Bridge.Notify('Crew invite sent!', 'success')
        else
            Bridge.Notify(err or 'Failed to invite', 'error')
        end
    end, input[1], State.CurrentFlight.flightId)
end

---Manage a specific crew member
---@param member table
function ManageCrewMember(member)
    lib.registerContext({
        id = 'airline_crew_member',
        title = 'Crew: ' .. member.citizenid,
        menu = 'airline_crew',
        options = {
            {
                title = 'Remove from Crew',
                description = 'Remove this member from the flight crew',
                icon = 'user-minus',
                onSelect = function()
                    lib.callback('dps-airlines:server:removeCrewMember', false, function(success, err)
                        if success then
                            Bridge.Notify('Crew member removed', 'success')
                        else
                            Bridge.Notify(err or 'Failed', 'error')
                        end
                    end, State.CurrentFlight.flightId, member.citizenid)
                end,
            },
        },
    })
    lib.showContext('airline_crew_member')
end

-- Handle crew invite received
RegisterNetEvent('dps-airlines:client:crewInvite', function(data)
    local confirm = lib.alertDialog({
        header = 'Crew Invitation',
        content = string.format('Captain %s invites you to join flight crew.\n\nAccept?', data.captainName or 'Unknown'),
        centered = true,
        cancel = true,
    })

    if confirm == 'confirm' then
        lib.callback('dps-airlines:server:acceptCrewInvite', false, function(success, role)
            if success then
                Bridge.Notify('Joined crew as ' .. (Config.Roles[role] and Config.Roles[role].label or role), 'success')
            else
                Bridge.Notify(role or 'Failed to join', 'error')
            end
        end, data.flightId)
    end
end)
