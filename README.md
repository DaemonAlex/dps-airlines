# DPS Airlines v3.0

A comprehensive airlines job system for FiveM servers with **multi-framework support** (QBCore, Qbox, ESX), 5 realistic airline roles, React NUI, and server-side security hardening.

![plane-pack-120-planes-728486](https://github.com/user-attachments/assets/fa89d591-6a1d-4d3c-a03b-85fd3a35b58d)
## Features

### 5 Airline Roles
| Grade | Role | Key Duties |
|-------|------|------------|
| 1 | **Ground Crew** | Cargo loading, refueling, marshaling, de-icing, baggage handling |
| 2 | **Flight Attendant** | Passenger boarding, safety briefings, in-flight service |
| 2 | **Dispatcher** | Create flight schedules, assign pilots, weather monitoring |
| 3 | **First Officer** | Assist captain, checklists, ATC comms, navigation |
| 4 | **Captain** | Fly aircraft, flight decisions, crew management |
| 5 | **Chief Pilot** | All captain duties + management menu, hire/fire, finances |

### Core Systems
- **Passenger Flights** - Transport NPC passengers between 5 airports
- **Cargo Transport** - Weight-based hauling with contract system
- **Cargo Contracts** - Multi-delivery agreements with deadlines and bonuses
- **Private Charters** - VIP transport services for players
- **Flight School** - Training program with checkrides and PPL licensing
- **Aircraft Maintenance** - Service and repair company aircraft
- **Dispatch System** - Live flight scheduling with StateBag updates
- **Weather System** - Dynamic weather impacts on operations
- **Reputation System** - Build pilot rep for better assignments
- **Crew System** - Captain invites co-pilot and attendant for multi-crew flights
- **Helicopter Operations** - Medevac, tours, VIP transport, search & rescue
- **Dynamic Fuel** - Weight-based burn rate with fuel planning
- **Emergency Scenarios** - Random in-flight emergencies (engine failure, bird strikes, etc.)
- **Black Box Recorder** - Flight data recording for incident investigation
- **Passenger Reviews** - Auto-generated ratings based on landing and service quality
- **Flight Tracker** - Live map view for dispatchers showing all active flights

### Technical
- **Multi-Framework Bridge** - Auto-detects QBCore, Qbox, or ESX
- **React TypeScript NUI** - Modern UI with dark theme, pre-built and ready to use
- **Server-Side Security** - All payments calculated server-side, anti-cheat validation
- **Rate Limiting** - Per-player cooldowns on all actions
- **Input Validation** - Airport codes, passenger counts, cargo weights all validated
- **TTL Cache** - Optimized database queries with configurable cache

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)
- One of: [qb-core](https://github.com/qbcore-framework/qb-core) / [qbx_core](https://github.com/Qbox-project/qbx_core) / [es_extended](https://github.com/esx-framework/esx_core)

## Installation

1. Place `dps-airlines` in your resources folder
2. Run `sql/install.sql` in your database
3. Register the `airline` job in your framework with 6 grades (0-5):

**QBCore / Qbox** - Add to your jobs config:
```lua
airline = {
    label = 'Los Santos Airlines',
    type = 'transportation',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Trainee', payment = 0 },
        [1] = { name = 'Ground Crew', payment = 50 },
        [2] = { name = 'Cabin/Dispatch', payment = 75 },
        [3] = { name = 'First Officer', payment = 100 },
        [4] = { name = 'Captain', payment = 150 },
        [5] = { name = 'Chief Pilot', isboss = true, payment = 200 }
    }
},
```

**ESX** - Add job and grades to your `jobs` and `job_grades` database tables.

4. Add to your `server.cfg`:
```
ensure dps-airlines
```
5. Restart your server

### Upgrading from v2

1. Back up your `airline_*` database tables
2. Run `sql/migrate_v2_to_v3.sql` to migrate your data
3. Change the job name from `pilot` to `airline` in your framework config
4. Update grades to match the 6-grade structure above
5. Restart your server

## Airports

| Code | Airport | Type |
|------|---------|------|
| LSIA | Los Santos International | Hub / International |
| SSA | Sandy Shores Airfield | Regional |
| FZ | Fort Zancudo | Military |
| MK | McKenzie Airfield | Regional |
| CP | Cayo Perico | Island / International |

## Helipads

- Los Santos Hospital, Maze Bank Tower, Vespucci Helipad, Sandy Shores Medical, Paleto Bay, LSIA Heliport

## Configuration

Edit `shared/config.lua` for:
- Role pay rates and multipliers
- Aircraft models and capacities (17 planes + 5 helicopters)
- Charter pricing
- Flight school settings
- Cargo contract parameters
- Helicopter operation settings
- Fuel burn rates
- Maintenance intervals
- Crew system settings

Edit `shared/locations.lua` for:
- Airport coordinates and terminals
- Helipad locations
- Tour routes
- NPC spawn points

Edit `shared/constants.lua` for:
- Flight phase thresholds
- Landing quality ratings
- Detection distances
- Rate limit cooldowns

## Project Structure

```
dps-airlines/
├── bridge/loader.lua          # Multi-framework auto-detection
├── shared/                    # Config, constants, locations
├── client/
│   ├── main.lua               # Bootstrap, state management, cleanup
│   ├── roles/                 # Role-specific menus (5 files)
│   ├── systems/               # Gameplay systems (14 files)
│   ├── ui/nui.lua             # NUI bridge
│   └── utils/                 # NPC spawning, blips
├── server/
│   ├── main.lua               # Init, core callbacks
│   ├── validation.lua         # Security, rate limiting
│   ├── payments.lua           # Server-side pay calculations
│   ├── roles/                 # Role server logic (5 files)
│   ├── systems/               # System server logic (6 files)
│   └── utils/cache.lua        # TTL cache
├── web/                       # React NUI (pre-built)
│   ├── dist/                  # Ready to use, no build needed
│   └── src/                   # Source (6 pages, hooks, styles)
└── sql/
    ├── install.sql            # Fresh install (14 tables)
    └── migrate_v2_to_v3.sql   # v2 migration
```

## NUI Pages

1. **Overview** - Pilot stats, hours, earnings, ratings, company overview
2. **Flight Log** - Paginated flight history with sorting and filters
3. **Type Ratings** - Aircraft certification grid (locked/unlocked)
4. **Incidents** - Safety record and incident history
5. **Flight Tracker** - Live map with active aircraft positions (dispatcher)
6. **Crew Management** - Employee roster and role management (chief pilot)

## License

Original concept and code by @daemonalex. Free to use and modify for your server.
