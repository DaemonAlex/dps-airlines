-- Client: Black box flight data recorder

local blackboxData = {}
local blackboxRecording = false

---Start recording black box data
function StartBlackbox()
    if blackboxRecording then return end
    blackboxRecording = true
    blackboxData = {
        startTime = GetGameTimer(),
        entries = {},
        events = {},
    }

    CreateThread(function()
        while blackboxRecording do
            Wait(5000) -- Record every 5 seconds

            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                local coords = GetEntityCoords(vehicle)
                local velocity = GetEntityVelocity(vehicle)
                local speed = GetEntitySpeed(vehicle)

                blackboxData.entries[#blackboxData.entries + 1] = {
                    time = GetGameTimer() - blackboxData.startTime,
                    x = math.floor(coords.x),
                    y = math.floor(coords.y),
                    z = math.floor(coords.z),
                    speed = math.floor(speed * 3.6),
                    heading = math.floor(GetEntityHeading(vehicle)),
                    altitude = math.floor(coords.z),
                    verticalSpeed = math.floor(velocity.z * 10) / 10,
                    engineHealth = math.floor(GetVehicleEngineHealth(vehicle)),
                    fuel = math.floor(State.FuelLevel),
                    phase = State.FlightPhase,
                }
            end
        end
    end)
end

---Stop recording and return data
---@return table
function StopBlackbox()
    blackboxRecording = false
    blackboxData.endTime = GetGameTimer()
    blackboxData.duration = (blackboxData.endTime - blackboxData.startTime) / 1000

    local data = blackboxData
    blackboxData = {}
    return data
end

---Add an event to the black box log
---@param eventType string
---@param description string
function LogBlackboxEvent(eventType, description)
    if not blackboxRecording then return end

    blackboxData.events[#blackboxData.events + 1] = {
        time = GetGameTimer() - blackboxData.startTime,
        type = eventType,
        description = description,
    }
end

---Check if black box is recording
---@return boolean
function IsBlackboxRecording()
    return blackboxRecording
end

---Get current black box entry count
---@return number
function GetBlackboxEntryCount()
    return #(blackboxData.entries or {})
end
