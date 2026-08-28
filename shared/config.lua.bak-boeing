Config = {}

Config.Debug = false
Config.Job = 'airline'

-- Society account name for airline funds
Config.SocietyAccount = 'society_airline'

-- Pay cycle interval (minutes)
Config.PayCycleMinutes = 30

-- Roles configuration
Config.Roles = {
    [Constants.ROLE_GROUND_CREW] = {
        label = 'Ground Crew',
        grade = Constants.GRADE_GROUND_CREW,
        hourlyPay = 50,
        taskBonus = 25,
        canFly = false,
        canDispatch = false,
        canManage = false,
    },
    [Constants.ROLE_FLIGHT_ATTENDANT] = {
        label = 'Flight Attendant',
        grade = Constants.GRADE_FLIGHT_ATTEND,
        flatRate = 150,
        tipPercent = 0.15,
        canFly = false,
        canDispatch = false,
        canManage = false,
    },
    [Constants.ROLE_DISPATCHER] = {
        label = 'Dispatcher',
        grade = Constants.GRADE_DISPATCHER,
        salaryPerCycle = 200,
        commissionPercent = 0.05,
        canFly = false,
        canDispatch = true,
        canManage = false,
    },
    [Constants.ROLE_FIRST_OFFICER] = {
        label = 'First Officer',
        grade = Constants.GRADE_FIRST_OFFICER,
        payMultiplier = 0.70,
        canFly = true,
        canDispatch = false,
        canManage = false,
    },
    [Constants.ROLE_CAPTAIN] = {
        label = 'Captain',
        grade = Constants.GRADE_CAPTAIN,
        payMultiplier = 1.0,
        canFly = true,
        canDispatch = false,
        canManage = false,
    },
    [Constants.ROLE_CHIEF_PILOT] = {
        label = 'Chief Pilot',
        grade = Constants.GRADE_CHIEF_PILOT,
        payMultiplier = 1.0,
        canFly = true,
        canDispatch = true,
        canManage = true,
    },
}

-- Flight pay structure
Config.FlightPay = {
    baseRate = 500,
    perPassenger = 5,
    perCargoTon = 15,
    perKilometer = 2,
    priorityMultiplier = 1.5,
    nightMultiplier = 1.15,
    emergencyBonus = 250,
}

-- Charter pricing
Config.Charter = {
    basePrice = 1000,
    perKilometer = 8,
    perPassenger = 50,
    vipMultiplier = 2.0,
    luggageFee = 25,
    minPrice = 500,
    maxPrice = 50000,
}

-- Flight school
Config.FlightSchool = {
    enrollmentFee = 5000,
    lessonFee = 1500,
    checkrideFee = 3000,
    requiredLessons = 5,
    requiredFlightHours = 10,
}

-- Cargo contracts
Config.CargoContracts = {
    minDeliveries = 3,
    maxDeliveries = 10,
    deadlineHours = 48,
    completionBonusPercent = 0.25,
    lateDeliveryPenalty = 0.50,
}

-- Helicopter operations
Config.Helicopters = {
    enabled = true,
    medevac = {
        timeLimit = 300, -- seconds
        basePay = 750,
        bonusPerSecondSaved = 5,
    },
    tour = {
        basePay = 400,
        waypointBonus = 50,
        passengerTipChance = 0.3,
        tipAmount = { min = 25, max = 100 },
    },
    vip = {
        basePay = 1200,
        landingBonusSmooth = 500,
        latePenaltyPerMinute = 50,
    },
    searchRescue = {
        basePay = 600,
        timeLimit = 600,
        rescueBonus = 300,
    },
}

-- Helicopter models allowed
Config.HeliModels = {
    { model = 'polmav',    label = 'Police Maverick',  seats = 4, fuelRate = 1.2 },
    { model = 'maverick',  label = 'Maverick',         seats = 4, fuelRate = 1.0 },
    { model = 'frogger',   label = 'Frogger',          seats = 4, fuelRate = 0.9 },
    { model = 'swift',     label = 'Swift',            seats = 4, fuelRate = 1.1 },
    { model = 'swift2',    label = 'Swift Deluxe',     seats = 4, fuelRate = 1.1 },
    { model = 'supervolito', label = 'SuperVolito',    seats = 4, fuelRate = 1.3 },
}

-- Aircraft configuration
Config.Aircraft = {
    { model = 'luxor',     label = 'Luxor',         passengers = 10, cargo = 500,  fuelRate = 1.0, class = 'small' },
    { model = 'luxor2',    label = 'Luxor Deluxe',  passengers = 10, cargo = 500,  fuelRate = 1.1, class = 'small' },
    { model = 'shamal',    label = 'Shamal',         passengers = 8,  cargo = 400,  fuelRate = 0.9, class = 'small' },
    { model = 'miljet',    label = 'Miljet',         passengers = 16, cargo = 800,  fuelRate = 1.2, class = 'medium' },
    { model = 'nimbus',    label = 'Nimbus',         passengers = 12, cargo = 600,  fuelRate = 1.0, class = 'medium' },
    { model = 'vestra',    label = 'Vestra',         passengers = 2,  cargo = 200,  fuelRate = 0.7, class = 'small' },
    { model = 'velum',     label = 'Velum',          passengers = 4,  cargo = 300,  fuelRate = 0.5, class = 'prop' },
    { model = 'velum2',    label = 'Velum 5-Seater', passengers = 5,  cargo = 350,  fuelRate = 0.6, class = 'prop' },
    { model = 'dodo',      label = 'Dodo',           passengers = 2,  cargo = 200,  fuelRate = 0.6, class = 'prop' },
    { model = 'cuban800',  label = 'Cuban 800',      passengers = 2,  cargo = 250,  fuelRate = 0.5, class = 'prop' },
    { model = 'mammatus',  label = 'Mammatus',       passengers = 2,  cargo = 150,  fuelRate = 0.4, class = 'prop' },
    { model = 'duster',    label = 'Duster',         passengers = 1,  cargo = 100,  fuelRate = 0.3, class = 'prop' },
    { model = 'stunt',     label = 'Mallard',        passengers = 2,  cargo = 100,  fuelRate = 0.4, class = 'prop' },
    { model = 'titan',     label = 'Titan',          passengers = 50, cargo = 5000, fuelRate = 2.0, class = 'large' },
    { model = 'cargoplane', label = 'Cargo Plane',   passengers = 0,  cargo = 10000, fuelRate = 2.5, class = 'cargo' },
    { model = 'jet',       label = 'Commercial Jet', passengers = 150, cargo = 3000, fuelRate = 2.0, class = 'large' },
    { model = 'alkonost',  label = 'Alkonost',       passengers = 0,  cargo = 8000, fuelRate = 3.0, class = 'cargo' },
}

-- Fuel configuration
Config.Fuel = {
    enabled = true,
    refuelRate = 2.0,       -- fuel units per second when refueling
    refuelCostPerUnit = 5,  -- $ per fuel unit
    weightFactor = 0.001,   -- additional burn per kg of cargo
}

-- Maintenance
Config.Maintenance = {
    degradePerFlight = 5,       -- condition lost per flight
    repairCostPerPoint = 100,   -- $ per condition point
    inspectionInterval = 10,    -- flights between required inspections
    groundedThreshold = 20,     -- condition below this = grounded
}

-- Passenger reviews
Config.Reviews = {
    enabled = true,
    landingWeight = 0.4,
    serviceWeight = 0.3,
    timeWeight = 0.3,
}

-- NPC configuration
Config.NPCs = {
    enabled = true,
    model = 's_m_m_pilot_02',
    dutyModel = 's_m_m_pilot_01',
    scenario = 'WORLD_HUMAN_CLIPBOARD',
}

-- Blips
Config.Blips = {
    airport = {
        sprite = 423,
        color = 3,
        scale = 0.8,
        label = 'Airport',
    },
    helipad = {
        sprite = 360,
        color = 1,
        scale = 0.6,
        label = 'Helipad',
    },
}

-- Target interaction distance
Config.InteractDistance = Constants.DIST_INTERACT

-- Crew system
Config.Crew = {
    maxSize = 4,         -- captain + copilot + attendant + 1
    inviteRange = 10.0,  -- meters
    inviteTimeout = 30,  -- seconds
}

return Config
