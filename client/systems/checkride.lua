-- Client: Checkride system (extended flight test logic)
-- The basic checkride is in school.lua. This file adds the practical flight test.

local checkrideActive = false
local checkrideWaypoints = {}
local checkrideScore = 100

---Start a practical checkride flight test
---@param airportCode string
function StartPracticalCheckride(airportCode)
    if checkrideActive then
        Bridge.Notify('Checkride already in progress', 'error')
        return
    end

    local airport = Locations.GetAirport(airportCode)
    if not airport then return end

    checkrideActive = true
    checkrideScore = 100
    checkrideWaypoints = {}

    -- Generate waypoints for the test route
    local testAirport = nil
    for code, ap in pairs(Locations.Airports) do
        if code ~= airportCode then
            testAirport = code
            break
        end
    end

    if not testAirport then
        Bridge.Notify('Cannot set up checkride route', 'error')
        checkrideActive = false
        return
    end

    local destAirport = Locations.GetAirport(testAirport)

    -- Create waypoint markers
    checkrideWaypoints = {
        { coords = airport.runway.start, label = 'Takeoff', reached = false },
        { coords = vector3(
            (airport.coords.x + destAirport.coords.x) / 2,
            (airport.coords.y + destAirport.coords.y) / 2,
            500.0
        ), label = 'Cruise Altitude', reached = false },
        { coords = destAirport.coords, label = 'Destination', reached = false },
    }

    SetNewWaypoint(checkrideWaypoints[1].coords.x, checkrideWaypoints[1].coords.y)
    Bridge.Notify('Practical checkride started! Follow the waypoints.', 'inform', 10000)

    -- Monitor checkride
    CreateThread(function()
        local waypointIndex = 1

        while checkrideActive and waypointIndex <= #checkrideWaypoints do
            Wait(1000)

            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle == 0 then
                checkrideScore = checkrideScore - 5
                Bridge.Notify('You left the aircraft! -5 points', 'error')
                if checkrideScore <= 0 then
                    EndCheckride(false)
                    return
                end
                goto continue
            end

            -- Check waypoint proximity
            local wp = checkrideWaypoints[waypointIndex]
            local dist = #(GetEntityCoords(vehicle) - wp.coords)

            if dist < 200.0 then
                wp.reached = true
                Bridge.Notify('Waypoint reached: ' .. wp.label, 'success')
                waypointIndex = waypointIndex + 1

                if waypointIndex <= #checkrideWaypoints then
                    local nextWp = checkrideWaypoints[waypointIndex]
                    SetNewWaypoint(nextWp.coords.x, nextWp.coords.y)
                end
            end

            -- Check for dangerous flying
            local speed = GetEntitySpeed(vehicle) * 3.6
            if speed > 400 then -- Unreasonable speed
                checkrideScore = checkrideScore - 2
            end

            if IsEntityDead(vehicle) then
                EndCheckride(false)
                return
            end

            ::continue::
        end

        if checkrideActive then
            -- All waypoints reached, evaluate landing
            EndCheckride(checkrideScore >= 70)
        end
    end)
end

---End the checkride
---@param passed boolean
function EndCheckride(passed)
    checkrideActive = false

    if passed then
        Bridge.Notify(string.format('Practical checkride PASSED! Score: %d/100', checkrideScore), 'success', 10000)
    else
        Bridge.Notify(string.format('Practical checkride FAILED. Score: %d/100 (need 70)', checkrideScore), 'error', 10000)
    end

    checkrideWaypoints = {}
end
