-- NUI Bridge: Communication between Lua and React

local isNuiOpen = false

---Open the NUI with a specific page and data
---@param page string
---@param data table|nil
function OpenNUI(page, data)
    if isNuiOpen then return end
    isNuiOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        page = page or 'overview',
        data = data or {},
    })
end

---Close the NUI
function CloseNUI()
    if not isNuiOpen then return end
    isNuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---Update NUI data without opening/closing
---@param page string
---@param data table
function UpdateNUI(page, data)
    SendNUIMessage({
        action = 'update',
        page = page,
        data = data,
    })
end

-- Close callback (ESC key or close button)
RegisterNUICallback('close', function(_, cb)
    CloseNUI()
    cb('ok')
end)

-- Fetch data callback (React -> Lua)
RegisterNUICallback('fetchData', function(data, cb)
    local callbackName = data.callback
    local args = data.args or {}

    if not callbackName then
        cb({ error = 'No callback specified' })
        return
    end

    -- Map NUI requests to server callbacks
    local callbackMap = {
        getPlayerData = 'dps-airlines:server:getPlayerData',
        getPilotStats = 'dps-airlines:server:getPilotStats',
        getFlightLog = 'dps-airlines:server:getFlightLog',
        getTypeRatings = 'dps-airlines:server:getTypeRatings',
        getIncidents = 'dps-airlines:server:getIncidents',
        getCompanyStats = 'dps-airlines:server:getCompanyStats',
        getFlightTracker = 'dps-airlines:server:getFlightTracker',
        getFlightCrew = 'dps-airlines:server:getFlightCrew',
        getEmployees = 'dps-airlines:server:getEmployees',
        getSchoolProgress = 'dps-airlines:server:getSchoolProgress',
        getCargoContracts = 'dps-airlines:server:getCargoContracts',
        getSchedules = 'dps-airlines:server:getSchedules',
        getSocietyBalance = 'dps-airlines:server:getSocietyBalance',
    }

    local serverCallback = callbackMap[callbackName]
    if not serverCallback then
        cb({ error = 'Unknown callback: ' .. callbackName })
        return
    end

    lib.callback(serverCallback, false, function(result)
        cb(result or {})
    end, table.unpack(args))
end)

-- NUI action callback (React -> Lua for actions)
RegisterNUICallback('action', function(data, cb)
    local actionName = data.action
    if not actionName then
        cb({ error = 'No action specified' })
        return
    end

    if actionName == 'navigate' then
        -- Just change page, handled by React
        cb({ ok = true })
    elseif actionName == 'openStats' then
        -- Refresh and send stats
        lib.callback('dps-airlines:server:getPilotStats', false, function(stats)
            SendNUIMessage({ action = 'update', page = 'overview', data = { stats = stats } })
            cb({ ok = true })
        end)
    else
        cb({ error = 'Unknown action' })
    end
end)

-- Keybind to open NUI (when on duty)
RegisterCommand('airlinemenu', function()
    if not State.IsEmployee() or not State.OnDuty then
        Bridge.Notify('You must be on duty as an airline employee', 'error')
        return
    end

    local nearestCode, nearestDist = Locations.GetNearestAirport(GetEntityCoords(PlayerPedId()))
    if nearestDist > Constants.DIST_APPROACH_DETECT then
        Bridge.Notify('You must be near an airport', 'error')
        return
    end

    OpenNUI('overview', {
        role = State.Role,
        airport = nearestCode,
    })
end, false)

RegisterKeyMapping('airlinemenu', 'Open Airline Menu', 'keyboard', 'F7')
