Config = {}

-- General Settings
Config.Debug = false
Config.UseTarget = true -- Use ox_target for interactions
Config.FuelScript = 'qs-fuel' -- qs-fuel, LegacyFuel, cdn-fuel, ps-fuel

-- Job Settings
Config.Job = 'pilot'
Config.BossGrade = 2

-- Economy Settings
Config.PaymentAccount = 'bank' -- bank, cash
Config.UseSocietyFunds = true -- Pay from society account (requires qb-management/qb-banking)

-- Flight Reputation Settings
Config.RepGainPerFlight = 1
Config.RepRequirements = {
    ['shamal'] = 30,      -- Unlock at 30 rep
    ['nimbus'] = 60,      -- Unlock at 60 rep
    ['miljet'] = 100,     -- Unlock at 100 rep
}

-- Plane Configuration
Config.Planes = {
    ['luxor'] = {
        label = 'Luxor (Small)',
        model = 'luxor',
        maxPassengers = 4,
        maxCargo = 500, -- kg
        fuelConsumption = 1.2, -- multiplier
        basePayment = 100,
        repRequired = 0,
        category = 'small',
    },
    ['shamal'] = {
        label = 'Shamal (Medium)',
        model = 'shamal',
        maxPassengers = 8,
        maxCargo = 1000,
        fuelConsumption = 1.5,
        basePayment = 200,
        repRequired = 30,
        category = 'medium',
    },
    ['nimbus'] = {
        label = 'Nimbus (Large)',
        model = 'nimbus',
        maxPassengers = 12,
        maxCargo = 2000,
        fuelConsumption = 1.8,
        basePayment = 300,
        repRequired = 60,
        category = 'large',
    },
    ['miljet'] = {
        label = 'Miljet (Executive)',
        model = 'miljet',
        maxPassengers = 16,
        maxCargo = 3000,
        fuelConsumption = 2.0,
        basePayment = 400,
        repRequired = 100,
        category = 'executive',
    },
}

-- Passenger System
Config.Passengers = {
    enabled = true,
    payPerPassenger = 15, -- Extra pay per passenger delivered
    boardingTime = 3000, -- ms per passenger to board
    models = {
        'a_m_m_business_01',
        'a_f_y_business_01',
        'a_m_y_business_02',
        'a_f_y_business_02',
        'a_m_m_tourist_01',
        'a_f_m_tourist_01',
    },
}

-- Cargo System
Config.Cargo = {
    enabled = true,
    payPerKg = 0.5, -- Payment per kg delivered
    cargoTypes = {
        { name = 'mail', label = 'Mail & Packages', weight = { min = 100, max = 300 }, payMultiplier = 1.0 },
        { name = 'medical', label = 'Medical Supplies', weight = { min = 50, max = 150 }, payMultiplier = 1.5 },
        { name = 'freight', label = 'General Freight', weight = { min = 200, max = 500 }, payMultiplier = 0.8 },
        { name = 'valuables', label = 'Valuables', weight = { min = 20, max = 50 }, payMultiplier = 2.5 },
    },
}

-- Charter System
Config.Charter = {
    enabled = true,
    baseFee = 500, -- Base fee for charter
    perKmFee = 5, -- Additional fee per km
    maxWaitTime = 300, -- Seconds to wait for pickup
    cooldown = 600, -- Cooldown between charter requests (seconds)
}

-- Weather System
Config.Weather = {
    enabled = true,
    checkInterval = 60000, -- Check weather every 60 seconds
    delays = {
        ['RAIN'] = { chance = 30, delayMinutes = 15, payBonus = 1.2 },
        ['THUNDER'] = { chance = 60, delayMinutes = 30, payBonus = 1.5 },
        ['SNOW'] = { chance = 40, delayMinutes = 20, payBonus = 1.3 },
        ['FOGGY'] = { chance = 20, delayMinutes = 10, payBonus = 1.1 },
    },
    groundedWeather = { 'THUNDER' }, -- Weather that grounds all flights
}

-- Maintenance System
Config.Maintenance = {
    enabled = true,
    flightsBeforeService = 10, -- Flights before maintenance required
    serviceCost = {
        ['small'] = 500,
        ['medium'] = 1000,
        ['large'] = 2000,
        ['executive'] = 3500,
    },
    breakdownChance = 5, -- % chance of issue per flight when overdue
}

-- Flight School
Config.FlightSchool = {
    enabled = true,
    licenseCost = 2500,
    requiredLessons = 3,
    lessons = {
        {
            name = 'takeoff_landing',
            label = 'Takeoff & Landing',
            description = 'Learn basic takeoff and landing procedures',
            reward = 100,
        },
        {
            name = 'navigation',
            label = 'Navigation',
            description = 'Learn to navigate using waypoints',
            reward = 150,
        },
        {
            name = 'emergency',
            label = 'Emergency Procedures',
            description = 'Handle engine failures and emergencies',
            reward = 200,
        },
    },
}

-- Dispatch System
Config.Dispatch = {
    enabled = true,
    autoAssign = false, -- Auto-assign flights to available pilots
    maxActiveFlights = 3, -- Max concurrent flights per pilot
    priorityMultiplier = 1.5, -- Pay multiplier for priority flights
    expiryTime = 300, -- Seconds before unaccepted flight expires
}

-- ATC / Flight Plans
Config.ATC = {
    enabled = true,
    requireClearance = true, -- Must request clearance before takeoff
    clearanceDelay = { min = 5, max = 15 }, -- Seconds to wait for clearance
    callsigns = {
        prefix = 'DPS',
        format = '%s%d', -- DPS123
    },
}

-- NPC Interaction
Config.NPCs = {
    useTarget = true,
    blips = true,
    peds = {
        {
            model = 's_m_m_pilot_02',
            scenario = 'WORLD_HUMAN_CLIPBOARD',
        },
        {
            model = 's_f_y_airhostess_01',
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        },
    },
}

-- Notifications
Config.Notifications = {
    type = 'ox_lib', -- ox_lib, qb, okok
}
