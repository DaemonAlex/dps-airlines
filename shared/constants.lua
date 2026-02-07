Constants = {}

-- Flight phases
Constants.PHASE_GROUND    = 0
Constants.PHASE_TAXIING   = 1
Constants.PHASE_TAKEOFF   = 2
Constants.PHASE_CRUISE    = 3
Constants.PHASE_APPROACH  = 4
Constants.PHASE_LANDED    = 5

Constants.PhaseNames = {
    [Constants.PHASE_GROUND]   = 'Ground',
    [Constants.PHASE_TAXIING]  = 'Taxiing',
    [Constants.PHASE_TAKEOFF]  = 'Takeoff',
    [Constants.PHASE_CRUISE]   = 'Cruise',
    [Constants.PHASE_APPROACH] = 'Approach',
    [Constants.PHASE_LANDED]   = 'Landed',
}

-- Role grades
Constants.GRADE_GROUND_CREW    = 1
Constants.GRADE_FLIGHT_ATTEND  = 2
Constants.GRADE_DISPATCHER     = 2
Constants.GRADE_FIRST_OFFICER  = 3
Constants.GRADE_CAPTAIN        = 4
Constants.GRADE_CHIEF_PILOT    = 5

-- Role identifiers (used in airline_role_assignments)
Constants.ROLE_GROUND_CREW     = 'ground_crew'
Constants.ROLE_FLIGHT_ATTENDANT = 'flight_attendant'
Constants.ROLE_DISPATCHER      = 'dispatcher'
Constants.ROLE_FIRST_OFFICER   = 'first_officer'
Constants.ROLE_CAPTAIN         = 'captain'
Constants.ROLE_CHIEF_PILOT     = 'chief_pilot'

Constants.GradeToRoles = {
    [1] = { Constants.ROLE_GROUND_CREW },
    [2] = { Constants.ROLE_FLIGHT_ATTENDANT, Constants.ROLE_DISPATCHER },
    [3] = { Constants.ROLE_FIRST_OFFICER },
    [4] = { Constants.ROLE_CAPTAIN },
    [5] = { Constants.ROLE_CHIEF_PILOT },
}

-- Database statuses
Constants.DB_STATUS_ACTIVE    = 'active'
Constants.DB_STATUS_COMPLETED = 'completed'
Constants.DB_STATUS_CANCELLED = 'cancelled'
Constants.DB_STATUS_FAILED    = 'failed'

-- Dispatch statuses
Constants.DISPATCH_PENDING    = 'pending'
Constants.DISPATCH_ASSIGNED   = 'assigned'
Constants.DISPATCH_IN_FLIGHT  = 'in_flight'
Constants.DISPATCH_COMPLETED  = 'completed'
Constants.DISPATCH_CANCELLED  = 'cancelled'

-- Rate limit tiers (ms)
Constants.THROTTLE_FAST     = 100
Constants.THROTTLE_NORMAL   = 500
Constants.THROTTLE_SLOW     = 1000
Constants.THROTTLE_VERY_SLOW = 5000

-- Landing quality thresholds (vertical speed m/s)
Constants.LANDING_SMOOTH    = 5.0
Constants.LANDING_NORMAL    = 10.0
Constants.LANDING_HARD      = 15.0
Constants.LANDING_CRASH     = 25.0

Constants.LandingRatings = {
    { threshold = Constants.LANDING_SMOOTH, label = 'Butter',   bonus = 1.25 },
    { threshold = Constants.LANDING_NORMAL, label = 'Normal',   bonus = 1.0 },
    { threshold = Constants.LANDING_HARD,   label = 'Hard',     bonus = 0.75 },
    { threshold = Constants.LANDING_CRASH,  label = 'Crash',    bonus = 0.0 },
}

-- Detection distances (units)
Constants.DIST_APPROACH_DETECT   = 2000.0
Constants.DIST_COMPLETION        = 200.0
Constants.DIST_COMPLETION_AGL    = 5.0
Constants.DIST_NPC_SPAWN         = 100.0
Constants.DIST_NPC_DESPAWN       = 150.0
Constants.DIST_INTERACT          = 3.0

-- Fuel
Constants.FUEL_MAX               = 100.0
Constants.FUEL_LOW_WARNING       = 20.0
Constants.FUEL_CRITICAL_WARNING  = 10.0
Constants.FUEL_BASE_BURN_RATE    = 0.08  -- per second base

-- Cargo
Constants.CARGO_MAX_WEIGHT       = 10000 -- kg
Constants.CARGO_MIN_WEIGHT       = 0

-- Passengers
Constants.PASSENGERS_MIN         = 0
Constants.PASSENGERS_MAX_DEFAULT = 150

-- Flight time validation
Constants.MIN_FLIGHT_TIME_PER_KM = 3.0  -- seconds per km minimum
Constants.MAX_FLIGHT_SPEED       = 300.0 -- knots for validation

-- Weather severity
Constants.WEATHER_CLEAR   = 0
Constants.WEATHER_LIGHT   = 1
Constants.WEATHER_MODERATE = 2
Constants.WEATHER_SEVERE  = 3

Constants.WeatherMultipliers = {
    [Constants.WEATHER_CLEAR]    = 1.0,
    [Constants.WEATHER_LIGHT]    = 1.1,
    [Constants.WEATHER_MODERATE] = 1.25,
    [Constants.WEATHER_SEVERE]   = 1.5,
}

-- Maintenance statuses
Constants.MAINT_GOOD      = 'good'
Constants.MAINT_FAIR      = 'fair'
Constants.MAINT_POOR      = 'poor'
Constants.MAINT_GROUNDED  = 'grounded'

-- Ground task types
Constants.TASK_CARGO_LOAD   = 'cargo_load'
Constants.TASK_CARGO_UNLOAD = 'cargo_unload'
Constants.TASK_REFUEL       = 'refuel'
Constants.TASK_MARSHAL      = 'marshal'
Constants.TASK_DEICE        = 'deice'
Constants.TASK_BAGGAGE      = 'baggage'
Constants.TASK_MAINTENANCE  = 'maintenance'

-- Helicopter operation types
Constants.HELI_MEDEVAC      = 'medevac'
Constants.HELI_TOUR         = 'tour'
Constants.HELI_VIP          = 'vip_transport'
Constants.HELI_SEARCH       = 'search_rescue'

-- Review ratings
Constants.RATING_MIN = 1
Constants.RATING_MAX = 5

-- Cache TTLs (seconds)
Constants.CACHE_PILOT_STATS      = 30
Constants.CACHE_MAINTENANCE      = 60
Constants.CACHE_COMPANY_STATS    = 300

return Constants
