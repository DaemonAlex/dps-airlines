-- Client utilities: Blip helpers

---Create a blip with standard settings
---@param coords vector3
---@param sprite number
---@param color number
---@param scale number
---@param label string
---@param shortRange boolean
---@return number blip
function CreateStandardBlip(coords, sprite, color, scale, label, shortRange)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, scale or 0.8)
    SetBlipColour(blip, color or 0)
    SetBlipAsShortRange(blip, shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Blip')
    EndTextCommandSetBlipName(blip)
    return blip
end

---Create a route blip to a destination
---@param coords vector3
---@param color number
---@return number blip
function CreateRouteBlip(coords, color)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, color or 3)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, color or 3)
    return blip
end

---Create a radius blip for search areas
---@param coords vector3
---@param radius number
---@param color number
---@param alpha number
---@return number blip
function CreateRadiusBlip(coords, radius, color, alpha)
    local blip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
    SetBlipColour(blip, color or 1)
    SetBlipAlpha(blip, alpha or 100)
    return blip
end
