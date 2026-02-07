-- Client: Dispatch system - StateBag pattern for live updates

-- Listen for dispatch updates via state bags
AddStateBagChangeHandler('airline_dispatch', nil, function(bagName, key, value)
    if not State.IsEmployee() or not State.OnDuty then return end

    if value and type(value) == 'table' then
        if value.type == 'new_schedule' then
            Bridge.Notify('New flight scheduled: ' .. (value.flightNumber or 'Unknown'), 'inform')
        elseif value.type == 'pilot_assigned' then
            Bridge.Notify('Pilot assigned to ' .. (value.flightNumber or 'flight'), 'inform')
        elseif value.type == 'flight_departed' then
            Bridge.Notify('Flight ' .. (value.flightNumber or '') .. ' has departed', 'inform')
        elseif value.type == 'flight_arrived' then
            Bridge.Notify('Flight ' .. (value.flightNumber or '') .. ' has arrived', 'inform')
        end
    end
end)

---Get formatted dispatch board data
---@return table
function GetDispatchBoard()
    local data = {
        activeFlights = {},
        pendingSchedules = {},
        completedToday = 0,
    }

    -- This would be populated via NUI callbacks
    return data
end
