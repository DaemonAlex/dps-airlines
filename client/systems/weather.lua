-- Client: Weather monitoring system

local currentWeatherData = {
    severity = Constants.WEATHER_CLEAR,
    name = 'Clear',
    visibility = 'Good',
    windSpeed = 0,
    isNight = false,
}

---Get current weather data
---@return table
function GetCurrentWeather()
    return currentWeatherData
end

---Get weather severity multiplier
---@return number
function GetWeatherMultiplier()
    return Constants.WeatherMultipliers[currentWeatherData.severity] or 1.0
end

---Check if it's night time
---@return boolean
function IsNightTime()
    local hour = GetClockHours()
    return hour < 6 or hour > 20
end

-- Weather monitoring thread
CreateThread(function()
    while true do
        Wait(10000) -- Update every 10 seconds

        local weatherHash = GetPrevWeatherTypeHashName()
        local hour = GetClockHours()

        local severity = Constants.WEATHER_CLEAR
        local name = 'Clear'
        local visibility = 'Good'

        if weatherHash == joaat('RAIN') then
            severity = Constants.WEATHER_MODERATE
            name = 'Rain'
            visibility = 'Reduced'
        elseif weatherHash == joaat('THUNDER') then
            severity = Constants.WEATHER_SEVERE
            name = 'Thunderstorm'
            visibility = 'Poor'
        elseif weatherHash == joaat('FOGGY') then
            severity = Constants.WEATHER_MODERATE
            name = 'Foggy'
            visibility = 'Very Low'
        elseif weatherHash == joaat('SMOG') then
            severity = Constants.WEATHER_LIGHT
            name = 'Smog'
            visibility = 'Reduced'
        elseif weatherHash == joaat('CLOUDS') then
            severity = Constants.WEATHER_LIGHT
            name = 'Cloudy'
            visibility = 'Good'
        elseif weatherHash == joaat('OVERCAST') then
            severity = Constants.WEATHER_LIGHT
            name = 'Overcast'
            visibility = 'Fair'
        elseif weatherHash == joaat('SNOW') or weatherHash == joaat('SNOWLIGHT') or weatherHash == joaat('BLIZZARD') then
            severity = Constants.WEATHER_SEVERE
            name = 'Snow/Blizzard'
            visibility = 'Poor'
        elseif weatherHash == joaat('XMAS') then
            severity = Constants.WEATHER_MODERATE
            name = 'Snow'
            visibility = 'Reduced'
        else
            severity = Constants.WEATHER_CLEAR
            name = 'Clear'
            visibility = 'Excellent'
        end

        -- Wind estimation (GTA doesn't have precise wind API)
        local windSpeed = math.random(0, 30)
        if severity >= Constants.WEATHER_SEVERE then
            windSpeed = math.random(25, 60)
        elseif severity >= Constants.WEATHER_MODERATE then
            windSpeed = math.random(10, 35)
        end

        currentWeatherData = {
            severity = severity,
            name = name,
            visibility = visibility,
            windSpeed = windSpeed,
            isNight = hour < 6 or hour > 20,
            hour = hour,
        }
    end
end)
