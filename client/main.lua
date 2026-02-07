-- DPS Airlines v3.0 - Client Main
-- Bootstrap, state module, and cleanup

local resourceName = GetCurrentResourceName()

-- ============================================================================
-- STATE MODULE - Encapsulated client state
-- ============================================================================
State = {
    PlayerData = nil,
    OnDuty = false,
    CurrentFlight = nil,
    CurrentPlane = nil,
    CurrentHeliOp = nil,
    FlightPhase = Constants.PHASE_GROUND,
    Role = nil,
    AirportCode = nil,
    FuelLevel = Constants.FUEL_MAX,
    CrewMembers = {},
    SpawnedNPCs = {},
    SpawnedBlips = {},
    FlightStartTime = 0,
    LastTrackerUpdate = 0,
}

---Reset all flight-related state
function State.ResetFlight()
    State.CurrentFlight = nil
    State.FlightPhase = Constants.PHASE_GROUND
    State.FuelLevel = Constants.FUEL_MAX
    State.CrewMembers = {}
    State.FlightStartTime = 0
    State.LastTrackerUpdate = 0

    if State.CurrentPlane and DoesEntityExist(State.CurrentPlane) then
        DeleteEntity(State.CurrentPlane)
    end
    State.CurrentPlane = nil
end

---Check if player is airline employee
---@return boolean
function State.IsEmployee()
    if not State.PlayerData then return false end
    return State.PlayerData.job and State.PlayerData.job.name == Config.Job
end

---Check if player can fly based on role
---@return boolean
function State.CanFly()
    if not State.Role then return false end
    local roleConfig = Config.Roles[State.Role]
    return roleConfig and roleConfig.canFly == true
end

-- Export state for other resources
exports('GetState', function()
    return State
end)

-- ============================================================================
-- PLAYER DATA SYNC
-- ============================================================================
local function RefreshPlayerData()
    State.PlayerData = Bridge.GetPlayerData()
    if State.IsEmployee() then
        lib.callback('dps-airlines:server:getPlayerData', false, function(data)
            if data then
                State.Role = data.role
                State.OnDuty = data.onDuty
            end
        end)
    else
        State.OnDuty = false
        State.Role = nil
    end
end

-- Framework event handlers
RegisterNetEvent(Bridge.Events.playerLoaded, function()
    RefreshPlayerData()
end)

RegisterNetEvent(Bridge.Events.jobUpdated, function()
    Wait(100)
    RefreshPlayerData()

    -- If no longer airline, clean up
    if not State.IsEmployee() then
        State.ResetFlight()
        CleanupNPCs()
        CleanupBlips()
        SendNUIMessage({ action = 'close' })
    end
end)

RegisterNetEvent(Bridge.Events.playerUnloaded, function()
    FullCleanup()
end)

-- ============================================================================
-- NPC MANAGEMENT
-- ============================================================================
function SpawnNPC(coords, heading, model, scenario)
    model = model or Config.NPCs.model
    local hash = type(model) == 'string' and joaat(model) or model

    lib.requestModel(hash)

    local npc = CreatePed(0, hash, coords.x, coords.y, coords.z - 1.0, heading or 0.0, false, true)
    SetEntityAsMissionEntity(npc, true, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedDiesWhenInjured(npc, false)
    SetPedCanBeTargetted(npc, false)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)

    if scenario then
        TaskStartScenarioInPlace(npc, scenario, 0, true)
    end

    State.SpawnedNPCs[#State.SpawnedNPCs + 1] = npc
    return npc
end

function CleanupNPCs()
    for _, npc in ipairs(State.SpawnedNPCs) do
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
    end
    State.SpawnedNPCs = {}
end

-- ============================================================================
-- BLIP MANAGEMENT
-- ============================================================================
function CreateAirportBlips()
    CleanupBlips()

    for code, airport in pairs(Locations.Airports) do
        local blip = AddBlipForCoord(airport.coords.x, airport.coords.y, airport.coords.z)
        SetBlipSprite(blip, Config.Blips.airport.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.Blips.airport.scale)
        SetBlipColour(blip, Config.Blips.airport.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(airport.label)
        EndTextCommandSetBlipName(blip)
        State.SpawnedBlips[#State.SpawnedBlips + 1] = blip
    end

    if Config.Helicopters.enabled then
        for _, pad in ipairs(Locations.Helipads) do
            local blip = AddBlipForCoord(pad.coords.x, pad.coords.y, pad.coords.z)
            SetBlipSprite(blip, Config.Blips.helipad.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.Blips.helipad.scale)
            SetBlipColour(blip, Config.Blips.helipad.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(pad.label)
            EndTextCommandSetBlipName(blip)
            State.SpawnedBlips[#State.SpawnedBlips + 1] = blip
        end
    end
end

function CleanupBlips()
    for _, blip in ipairs(State.SpawnedBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    State.SpawnedBlips = {}
end

-- ============================================================================
-- ROLE MENU ROUTER
-- ============================================================================
---Open the appropriate menu for the player's role
---@param airportCode string
function OpenRoleMenu(airportCode)
    if not State.IsEmployee() or not State.OnDuty then
        Bridge.Notify('Must be on duty', 'error')
        return
    end

    local role = State.Role

    if role == Constants.ROLE_CAPTAIN or role == Constants.ROLE_CHIEF_PILOT then
        OpenPilotMenu(airportCode)
    elseif role == Constants.ROLE_FIRST_OFFICER then
        OpenCopilotMenu(airportCode)
    elseif role == Constants.ROLE_FLIGHT_ATTENDANT then
        OpenAttendantMenu(airportCode)
    elseif role == Constants.ROLE_GROUND_CREW then
        OpenGroundMenu(airportCode)
    elseif role == Constants.ROLE_DISPATCHER then
        OpenDispatcherMenu(airportCode)
    else
        -- Default: show all available options
        lib.registerContext({
            id = 'airline_generic_menu',
            title = 'DPS Airlines',
            options = {
                {
                    title = 'View Stats',
                    icon = 'chart-bar',
                    onSelect = function() OpenNUI('overview') end,
                },
                {
                    title = 'Flight School',
                    icon = 'graduation-cap',
                    onSelect = function() OpenSchoolMenu() end,
                },
            },
        })
        lib.showContext('airline_generic_menu')
    end
end

-- ============================================================================
-- DUTY TOGGLE
-- ============================================================================
function ToggleDuty()
    lib.callback('dps-airlines:server:toggleDuty', false, function(success, newDuty)
        if success then
            State.OnDuty = newDuty
            Bridge.Notify(newDuty and 'You are now on duty' or 'You are now off duty', newDuty and 'success' or 'inform')

            if newDuty then
                CreateAirportBlips()
            else
                State.ResetFlight()
                CleanupBlips()
            end
        end
    end)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
CreateThread(function()
    Wait(1000)
    RefreshPlayerData()

    -- Spawn NPCs at airports
    if Config.NPCs.enabled then
        for code, airport in pairs(Locations.Airports) do
            if airport.npc then
                SpawnNPC(
                    vector3(airport.npc.x, airport.npc.y, airport.npc.z),
                    airport.npc.w,
                    Config.NPCs.model,
                    Config.NPCs.scenario
                )
            end
        end
    end

    -- Create ox_target interactions at airports
    for code, airport in pairs(Locations.Airports) do
        if airport.terminals and airport.terminals.duty then
            exports.ox_target:addSphereZone({
                coords = airport.terminals.duty,
                radius = Config.InteractDistance,
                name = 'airline_duty_' .. code,
                options = {
                    {
                        name = 'airline_duty_toggle',
                        label = 'Toggle Duty',
                        icon = 'fas fa-briefcase',
                        onSelect = function()
                            ToggleDuty()
                        end,
                        canInteract = function()
                            return State.IsEmployee()
                        end,
                    },
                    {
                        name = 'airline_open_menu',
                        label = 'Airline Menu',
                        icon = 'fas fa-plane',
                        onSelect = function()
                            OpenRoleMenu(code)
                        end,
                        canInteract = function()
                            return State.IsEmployee() and State.OnDuty
                        end,
                    },
                },
            })
        end
    end

    if State.IsEmployee() and State.OnDuty then
        CreateAirportBlips()
    end
end)

-- ============================================================================
-- FULL CLEANUP
-- ============================================================================
function FullCleanup()
    State.ResetFlight()
    CleanupNPCs()
    CleanupBlips()
    SendNUIMessage({ action = 'close' })
    State.PlayerData = nil
    State.OnDuty = false
    State.Role = nil
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= resourceName then return end
    FullCleanup()
end)

-- ============================================================================
-- NOTIFICATION HANDLER
-- ============================================================================
RegisterNetEvent('dps-airlines:client:notify', function(msg, notifType)
    Bridge.Notify(msg, notifType or 'inform')
end)
