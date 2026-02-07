Locations = {}

Locations.Airports = {
    ['LSIA'] = {
        label = 'Los Santos International Airport',
        code = 'LSIA',
        coords = vector3(-1037.0, -2963.0, 13.95),
        heading = 90.0,
        runway = {
            start = vector3(-1497.84, -3032.93, 13.94),
            finish = vector3(-942.40, -2957.74, 13.94),
            heading = 30.0,
        },
        spawns = {
            planes = {
                vector4(-998.87, -2993.88, 13.95, 60.0),
                vector4(-1037.81, -3010.91, 13.95, 60.0),
                vector4(-1072.59, -3028.53, 13.95, 60.0),
                vector4(-1108.79, -3045.58, 13.95, 60.0),
            },
            helicopters = {
                vector4(-1145.67, -2864.16, 13.95, 150.0),
                vector4(-1172.29, -2846.68, 13.95, 150.0),
            },
        },
        terminals = {
            duty = vector3(-1040.46, -2745.57, 21.36),
            charter = vector3(-1020.80, -2727.27, 21.36),
            cargo = vector3(-1095.23, -3043.39, 13.95),
            fuel = vector3(-1050.0, -2990.0, 13.95),
            maintenance = vector3(-1060.0, -3000.0, 13.95),
        },
        gates = {
            { label = 'Gate A1', coords = vector3(-1045.0, -2750.0, 21.36), heading = 270.0 },
            { label = 'Gate A2', coords = vector3(-1045.0, -2765.0, 21.36), heading = 270.0 },
            { label = 'Gate A3', coords = vector3(-1045.0, -2780.0, 21.36), heading = 270.0 },
            { label = 'Gate B1', coords = vector3(-1020.0, -2750.0, 21.36), heading = 90.0 },
            { label = 'Gate B2', coords = vector3(-1020.0, -2765.0, 21.36), heading = 90.0 },
        },
        npc = vector4(-1040.46, -2745.57, 21.36, 240.0),
    },

    ['SSA'] = {
        label = 'Sandy Shores Airfield',
        code = 'SSA',
        coords = vector3(1692.87, 3281.69, 41.14),
        heading = 180.0,
        runway = {
            start = vector3(1741.22, 3270.60, 41.14),
            finish = vector3(1396.88, 3271.56, 41.14),
            heading = 268.0,
        },
        spawns = {
            planes = {
                vector4(1692.87, 3281.69, 41.14, 92.0),
                vector4(1707.74, 3256.49, 41.14, 92.0),
            },
            helicopters = {
                vector4(1770.0, 3240.0, 41.14, 180.0),
            },
        },
        terminals = {
            duty = vector3(1693.30, 3280.82, 41.14),
            charter = vector3(1700.0, 3283.0, 41.14),
            cargo = vector3(1672.0, 3285.0, 41.14),
            fuel = vector3(1680.0, 3275.0, 41.14),
            maintenance = vector3(1685.0, 3270.0, 41.14),
        },
        gates = {
            { label = 'Pad 1', coords = vector3(1692.87, 3281.69, 41.14), heading = 92.0 },
        },
        npc = vector4(1693.30, 3280.82, 41.14, 225.0),
    },

    ['FZ'] = {
        label = 'Fort Zancudo',
        code = 'FZ',
        coords = vector3(-2105.18, 3049.73, 32.81),
        heading = 150.0,
        runway = {
            start = vector3(-2265.32, 3098.32, 32.81),
            finish = vector3(-1836.63, 2947.76, 32.81),
            heading = 150.0,
        },
        spawns = {
            planes = {
                vector4(-2105.18, 3049.73, 32.81, 150.0),
                vector4(-2130.35, 3061.64, 32.81, 150.0),
            },
            helicopters = {
                vector4(-2069.93, 3058.08, 32.81, 200.0),
            },
        },
        terminals = {
            duty = vector3(-2105.18, 3049.73, 32.81),
            cargo = vector3(-2120.0, 3055.0, 32.81),
            fuel = vector3(-2110.0, 3045.0, 32.81),
            maintenance = vector3(-2115.0, 3040.0, 32.81),
        },
        gates = {
            { label = 'Military Pad 1', coords = vector3(-2105.18, 3049.73, 32.81), heading = 150.0 },
        },
        npc = vector4(-2105.18, 3049.73, 32.81, 150.0),
    },

    ['MK'] = {
        label = 'McKenzie Airfield',
        code = 'MK',
        coords = vector3(2121.72, 4796.36, 41.19),
        heading = 225.0,
        runway = {
            start = vector3(2135.93, 4813.97, 41.19),
            finish = vector3(2015.78, 4730.83, 41.19),
            heading = 225.0,
        },
        spawns = {
            planes = {
                vector4(2121.72, 4796.36, 41.19, 225.0),
                vector4(2133.58, 4775.47, 41.19, 225.0),
            },
            helicopters = {
                vector4(2140.0, 4810.0, 41.19, 225.0),
            },
        },
        terminals = {
            duty = vector3(2121.72, 4796.36, 41.19),
            cargo = vector3(2115.0, 4790.0, 41.19),
            fuel = vector3(2125.0, 4800.0, 41.19),
            maintenance = vector3(2130.0, 4795.0, 41.19),
        },
        gates = {
            { label = 'Strip 1', coords = vector3(2121.72, 4796.36, 41.19), heading = 225.0 },
        },
        npc = vector4(2121.72, 4796.36, 41.19, 225.0),
    },

    ['CP'] = {
        label = 'Cayo Perico Airstrip',
        code = 'CP',
        coords = vector3(4449.07, -4481.98, 4.20),
        heading = 315.0,
        runway = {
            start = vector3(4517.65, -4558.27, 3.88),
            finish = vector3(4372.20, -4413.17, 2.08),
            heading = 315.0,
        },
        spawns = {
            planes = {
                vector4(4449.07, -4481.98, 4.20, 315.0),
                vector4(4462.30, -4497.52, 4.20, 315.0),
            },
            helicopters = {
                vector4(4440.0, -4445.0, 4.20, 315.0),
            },
        },
        terminals = {
            duty = vector3(4449.07, -4481.98, 4.20),
            charter = vector3(4455.0, -4475.0, 4.20),
            cargo = vector3(4435.0, -4470.0, 4.20),
            fuel = vector3(4445.0, -4485.0, 4.20),
            maintenance = vector3(4440.0, -4480.0, 4.20),
        },
        gates = {
            { label = 'Island Pad 1', coords = vector3(4449.07, -4481.98, 4.20), heading = 315.0 },
        },
        npc = vector4(4449.07, -4481.98, 4.20, 315.0),
    },
}

Locations.Helipads = {
    {
        label = 'Central Hospital Helipad',
        code = 'HOS1',
        coords = vector3(338.17, -583.98, 74.16),
        heading = 0.0,
        spawn = vector4(338.17, -583.98, 74.16, 0.0),
        types = { Constants.HELI_MEDEVAC },
    },
    {
        label = 'Pillbox Hospital Helipad',
        code = 'HOS2',
        coords = vector3(352.14, -588.24, 74.16),
        heading = 0.0,
        spawn = vector4(352.14, -588.24, 74.16, 0.0),
        types = { Constants.HELI_MEDEVAC, Constants.HELI_VIP },
    },
    {
        label = 'LSIA Helipad',
        code = 'LSIAH',
        coords = vector3(-1145.67, -2864.16, 13.95),
        heading = 150.0,
        spawn = vector4(-1145.67, -2864.16, 13.95, 150.0),
        types = { Constants.HELI_TOUR, Constants.HELI_VIP, Constants.HELI_SEARCH },
    },
    {
        label = 'Vespucci Helipad',
        code = 'VESP',
        coords = vector3(-724.97, -1444.04, 5.0),
        heading = 140.0,
        spawn = vector4(-724.97, -1444.04, 5.0, 140.0),
        types = { Constants.HELI_TOUR, Constants.HELI_VIP },
    },
    {
        label = 'Merryweather Helipad',
        code = 'MERR',
        coords = vector3(486.36, -1772.41, 29.29),
        heading = 90.0,
        spawn = vector4(486.36, -1772.41, 29.29, 90.0),
        types = { Constants.HELI_VIP, Constants.HELI_SEARCH },
    },
    {
        label = 'Paleto Bay Helipad',
        code = 'PALT',
        coords = vector3(-475.24, 6019.0, 31.34),
        heading = 45.0,
        spawn = vector4(-475.24, 6019.0, 31.34, 45.0),
        types = { Constants.HELI_MEDEVAC, Constants.HELI_SEARCH },
    },
}

-- Tour waypoints for helicopter tours
Locations.TourRoutes = {
    ['vinewood'] = {
        label = 'Vinewood Hills Tour',
        duration = 300,
        waypoints = {
            vector3(297.0, 180.0, 104.0),
            vector3(654.0, 558.0, 130.0),
            vector3(100.0, 834.0, 235.0),
            vector3(-596.0, 651.0, 155.0),
            vector3(-809.0, 413.0, 136.0),
        },
    },
    ['coastal'] = {
        label = 'Coastal Tour',
        duration = 420,
        waypoints = {
            vector3(-1850.0, -1231.0, 13.0),
            vector3(-2991.0, 41.0, 10.0),
            vector3(-3415.0, 967.0, 8.0),
            vector3(-2178.0, 1741.0, 140.0),
            vector3(-1601.0, 2171.0, 60.0),
        },
    },
    ['city'] = {
        label = 'Downtown LS Tour',
        duration = 360,
        waypoints = {
            vector3(-75.0, -818.0, 326.0),
            vector3(136.0, -1079.0, 29.0),
            vector3(-271.0, -1908.0, 27.0),
            vector3(237.0, -2017.0, 18.0),
            vector3(-62.0, -1454.0, 32.0),
        },
    },
}

-- Flight routes (airport to airport)
Locations.Routes = {}

-- Auto-generate routes between all airports
for fromCode, fromAirport in pairs(Locations.Airports) do
    for toCode, toAirport in pairs(Locations.Airports) do
        if fromCode ~= toCode then
            local dist = #(fromAirport.coords - toAirport.coords)
            local routeKey = fromCode .. '_' .. toCode
            Locations.Routes[routeKey] = {
                from = fromCode,
                to = toCode,
                fromLabel = fromAirport.label,
                toLabel = toAirport.label,
                distance = dist,
                estimatedTime = math.ceil(dist / 50), -- rough seconds estimate
            }
        end
    end
end

-- Helper functions
function Locations.GetAirport(code)
    return Locations.Airports[code]
end

function Locations.GetNearestAirport(coords)
    local nearest, nearestDist = nil, math.huge
    for code, airport in pairs(Locations.Airports) do
        local dist = #(coords - airport.coords)
        if dist < nearestDist then
            nearest = code
            nearestDist = dist
        end
    end
    return nearest, nearestDist
end

function Locations.GetNearestHelipad(coords)
    local nearest, nearestDist = nil, math.huge
    for i, pad in ipairs(Locations.Helipads) do
        local dist = #(coords - pad.coords)
        if dist < nearestDist then
            nearest = pad
            nearestDist = dist
        end
    end
    return nearest, nearestDist
end

function Locations.GetRoute(fromCode, toCode)
    return Locations.Routes[fromCode .. '_' .. toCode]
end

function Locations.GetAircraftConfig(model)
    for _, aircraft in ipairs(Config.Aircraft) do
        if aircraft.model == model then
            return aircraft
        end
    end
    return nil
end

function Locations.GetHeliConfig(model)
    for _, heli in ipairs(Config.HeliModels) do
        if heli.model == model then
            return heli
        end
    end
    return nil
end

return Locations
