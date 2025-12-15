-- Flight & ATC System
local QBCore = exports['qb-core']:GetCoreObject()

local CurrentCallsign = nil
local HasClearance = false
local FlightPhase = 'ground' -- ground, taxiing, takeoff, cruise, approach, landed
local WeatherDelay = nil

-- =====================================
-- ATC / CLEARANCE SYSTEM
-- =====================================

function RequestClearance(runway)
    if not Config.ATC.enabled or not Config.ATC.requireClearance then
        HasClearance = true
        return true
    end

    if HasClearance then
        lib.notify({ title = 'ATC', description = 'You already have clearance', type = 'warning' })
        return true
    end

    -- Generate callsign
    CurrentCallsign = string.format('%s%d', Config.ATC.callsigns.prefix, math.random(100, 999))

    lib.notify({
        title = 'ATC Request',
        description = string.format('%s requesting clearance for %s', CurrentCallsign, runway.label),
        type = 'inform'
    })

    -- Simulate ATC delay
    local delay = math.random(Config.ATC.clearanceDelay.min, Config.ATC.clearanceDelay.max) * 1000

    local success = lib.progressBar({
        duration = delay,
        label = 'Awaiting ATC clearance...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = false, combat = true }
    })

    if success then
        HasClearance = true
        lib.notify({
            title = 'ATC',
            description = string.format('%s, cleared for takeoff %s. Winds calm.', CurrentCallsign, runway.label),
            type = 'success',
            duration = 5000
        })
        return true
    else
        lib.notify({ title = 'ATC', description = 'Clearance cancelled', type = 'error' })
        return false
    end
end

function LandingClearance(airport)
    if not Config.ATC.enabled then return true end

    lib.notify({
        title = 'ATC',
        description = string.format('%s, cleared to land at %s', CurrentCallsign or 'Aircraft', airport.label),
        type = 'success',
        duration = 5000
    })

    return true
end

function ResetClearance()
    HasClearance = false
    CurrentCallsign = nil
    FlightPhase = 'ground'
end

-- =====================================
-- WEATHER SYSTEM
-- =====================================

local function GetCurrentWeather()
    -- Get weather from qb-weathersync or similar
    local weather = exports['qb-weathersync']:getWeatherState() if exports['qb-weathersync'] then
        return exports['qb-weathersync']:getWeatherState()
    end
    return 'CLEAR'
end

function CheckWeatherConditions()
    if not Config.Weather.enabled then
        return { canFly = true, delay = 0, bonus = 1.0 }
    end

    local weather = GetCurrentWeather()

    -- Check if grounded
    for _, grounded in ipairs(Config.Weather.groundedWeather) do
        if weather == grounded then
            return {
                canFly = false,
                reason = 'All flights grounded due to severe weather',
                weather = weather
            }
        end
    end

    -- Check for delays
    local delayInfo = Config.Weather.delays[weather]
    if delayInfo then
        local roll = math.random(1, 100)
        if roll <= delayInfo.chance then
            return {
                canFly = true,
                delay = delayInfo.delayMinutes,
                bonus = delayInfo.payBonus,
                weather = weather
            }
        end
    end

    return { canFly = true, delay = 0, bonus = 1.0, weather = weather }
end

function ApplyWeatherDelay()
    local conditions = CheckWeatherConditions()

    if not conditions.canFly then
        lib.notify({
            title = 'Weather Alert',
            description = conditions.reason,
            type = 'error',
            duration = 7000
        })
        return false
    end

    if conditions.delay > 0 then
        WeatherDelay = {
            minutes = conditions.delay,
            bonus = conditions.bonus,
            weather = conditions.weather
        }

        local alert = lib.alertDialog({
            header = 'Weather Delay',
            content = string.format(
                'Due to %s conditions, there is a %d minute delay.\n\nFly anyway for a %d%% bonus, or wait for better conditions?',
                conditions.weather,
                conditions.delay,
                math.floor((conditions.bonus - 1) * 100)
            ),
            centered = true,
            cancel = true,
            labels = {
                confirm = 'Fly Now (Bonus)',
                cancel = 'Wait'
            }
        })

        if alert == 'confirm' then
            lib.notify({
                title = 'Weather Bonus',
                description = string.format('%d%% bonus applied for flying in %s', math.floor((conditions.bonus - 1) * 100), conditions.weather),
                type = 'success'
            })
            return true, conditions.bonus
        else
            return false
        end
    end

    return true, 1.0
end

-- =====================================
-- FLIGHT TRACKING
-- =====================================

function SetFlightPhase(phase)
    FlightPhase = phase

    if phase == 'takeoff' then
        lib.notify({ title = 'Flight', description = 'Takeoff', type = 'inform' })
    elseif phase == 'cruise' then
        lib.notify({ title = 'Flight', description = 'Cruising altitude reached', type = 'inform' })
    elseif phase == 'approach' then
        lib.notify({ title = 'Flight', description = 'Beginning approach', type = 'inform' })
    elseif phase == 'landed' then
        lib.notify({ title = 'Flight', description = 'Landed safely', type = 'success' })
    end
end

function GetFlightPhase()
    return FlightPhase
end

-- Monitor altitude and speed for flight phases
CreateThread(function()
    while true do
        Wait(2000)

        if CurrentFlight and CurrentPlane and DoesEntityExist(CurrentPlane) then
            local ped = PlayerPedId()
            if IsPedInVehicle(ped, CurrentPlane, false) then
                local altitude = GetEntityCoords(CurrentPlane).z
                local speed = GetEntitySpeed(CurrentPlane) * 3.6 -- km/h

                if FlightPhase == 'ground' and speed > 50 then
                    SetFlightPhase('takeoff')
                elseif FlightPhase == 'takeoff' and altitude > 500 then
                    SetFlightPhase('cruise')
                elseif FlightPhase == 'cruise' then
                    -- Check proximity to destination
                    local dest = Locations.Airports[CurrentFlight.to]
                    if dest then
                        local dist = #(GetEntityCoords(CurrentPlane) - vector3(dest.coords.x, dest.coords.y, dest.coords.z))
                        if dist < 2000 and altitude < 300 then
                            SetFlightPhase('approach')
                        end
                    end
                elseif FlightPhase == 'approach' and IsEntityOnScreen(CurrentPlane) and GetEntityHeightAboveGround(CurrentPlane) < 5 and speed < 30 then
                    SetFlightPhase('landed')
                end
            end
        else
            FlightPhase = 'ground'
        end
    end
end)

-- =====================================
-- RUNWAY SELECTION MENU
-- =====================================

function OpenRunwayMenu()
    local options = {}

    for _, runway in ipairs(Locations.Hub.runways) do
        table.insert(options, {
            title = runway.label,
            description = 'Request clearance for this runway',
            icon = 'fas fa-road',
            onSelect = function()
                local success = RequestClearance(runway)
                if success then
                    SetNewWaypoint(runway.location.x, runway.location.y)
                    lib.notify({
                        title = 'Waypoint Set',
                        description = 'Navigate to ' .. runway.label,
                        type = 'inform'
                    })
                end
            end
        })
    end

    lib.registerContext({
        id = 'airlines_runway_menu',
        title = 'Select Runway',
        options = options
    })

    lib.showContext('airlines_runway_menu')
end

-- =====================================
-- EXPORTS
-- =====================================

exports('RequestClearance', RequestClearance)
exports('LandingClearance', LandingClearance)
exports('ResetClearance', ResetClearance)
exports('CheckWeatherConditions', CheckWeatherConditions)
exports('ApplyWeatherDelay', ApplyWeatherDelay)
exports('GetFlightPhase', GetFlightPhase)
exports('HasClearance', function() return HasClearance end)
exports('GetCallsign', function() return CurrentCallsign end)
