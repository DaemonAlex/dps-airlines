# DPS Airlines v3.0

A comprehensive airlines job system for FiveM servers with **multi-framework support** (QBCore, Qbox, ESX), 5 realistic airline roles, React NUI, and server-side security hardening.

## Status

Not running on DelPerroSands. MS_FlightSim took over the pilot career on 25 October 2026. The
dps-airlines folder was still on the server on 1 November 2026 and is not there now. MS_FlightSim
and the aircraft packs were removed on 8 November 2026, so the server has no airline script at
present. The code here is complete (version 3.1.0).

## What it is for

It turns the airport into a workplace. Players take the `airline` job and work as ground crew,
flight attendant, dispatcher, first officer, captain or chief pilot. They fly passengers and
cargo between five airports, run helicopter jobs, train new pilots and manage the company from
one screen.

## On its own, and with other scripts

**On its own.** It needs `ox_lib`, `ox_target`, `oxmysql` and a framework (Qbox, QBCore or ESX).
A player clocks on at the airport desk, picks a flight, boards NPC passengers or loads cargo,
flies the route and gets paid on landing. The server works out every payout itself. Pilots earn
hours and ranks, and higher ranks unlock bigger aircraft. `/airlinemenu` opens the stats screen.
`/board` and `/boardplane` seat a player in a nearby aircraft. Fuel burn is the script's own
figure. It does not read or set a fuel script.

**With [dps-aviation](https://github.com/DaemonAlex/dps-aviation).** When the co-pilot finishes
the preflight checklist, the captain's aircraft begins its timed engine start. Without
dps-aviation the captain starts the engines by hand.

**With a society bank.** Company money goes through the `qb-management` exports (`GetAccount`,
`AddMoney`, `RemoveMoney`). On DelPerroSands wasabi_banking answers under that name. If no script
provides those exports the calls fail quietly and the company account stays empty.

**What is out of date for DelPerroSands.** The aircraft list in `shared/config.lua` names models
from packs the server no longer has. The `airline` job grades in the server's `qbx_core` jobs
file were changed on 25 October 2026 to fit MS_FlightSim, so they no longer match the six grades
this script expects.

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
- **Server-Side Security** - Payouts are calculated and validated server-side from authoritative state (server clock, server-sampled position, server-tracked op/flight timers); bonus magnitudes and pass/fail outcomes are never taken from the client. See the payout-hardening notes below.
- **Rate Limiting** - Per-player cooldowns on all actions
- **Input Validation** - Airport codes, passenger counts, cargo weights all validated
- **TTL Cache** - Optimized database queries with configurable cache

### Payout hardening (v3.1.0)

Several payouts previously trusted client-supplied values. As of v3.1.0 every payout is derived from authoritative server state:

- **Helicopter ops** - op start time and target are tracked server-side; time bonuses come from the server clock, tour waypoints from elapsed server time, and rescue/arrival credit from the server-sampled player position. All bonus inputs are clamped. (This also fixes a latent bug where VIP/search ops paid $0 due to an op-type/config-key mismatch.)
- **Passenger flights** - `isNight` comes from the server clock and weather is fixed to Clear (no server weather feed). The landing multiplier is dropped because touchdown vertical speed is not knowable server-side after the aircraft has parked; the distance-based minimum-flight-time and near-destination anti-cheat checks remain.
- **Cargo deliveries** - a delivery must be backed by a real, recently-completed cargo flight flown by the claimant; each flight can credit at most one delivery.
- **Flight school** - practice hours are credited from a server-tracked timer, and the checkride pass/fail is decided server-side from an actually-flown, validated route (the old client "passed" flag is gone).
- **Flight attendant** - completion pay is granted once per flight per attendant.
- **Crew distribution** - total crew disbursement is capped at the flight's computed pay.

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

## Recent changes

- **12 November 2026.** README: status, what it is for, how it works alone and with paid scripts, other DPS scripts.
- **10 October 2026.** Airlines screen: DelPerroSands logo, title "Airlines", house colours.
- **4 October 2026.** The co-pilot's preflight checklist hands the captain the engine start. Desk
  positions moved.
- **24 September 2026.** Co-pilot preflight checklist added, linked to dps-aviation.
- **28 August 2026.** Synced with the live server.
- **18 August 2026.** Audit fixes: a commission that could be claimed again and again, co-pilot
  pay theft, and double pay.

## Author

Made by [DaemonAlex](https://github.com/DaemonAlex) for DelPerroSands.

## Other DPS scripts

All of these are made for DelPerroSands and run together on one Qbox server. Each one works on
its own. The ones marked "pairs with" do more when both are running.

| Script | What it does |
|---|---|
| [dps-inventory](https://github.com/DaemonAlex/dps-inventory) | The inventory: ox_inventory with equipment slots, backpacks, armour plates and a self status panel, in the DelPerroSands colours. |
| [dps-medical](https://github.com/DaemonAlex/dps-medical) | Patient records, illness and diagnostic tests. A companion to wasabi_ambulance. Pairs with dps-inventory: symptoms and diagnoses show on the status panel. |
| [dps-insurance](https://github.com/DaemonAlex/dps-insurance) | Ties m-Insurance into the MDT, impound, hospital and medical chart. Pairs with dps-medical. |
| [dps-studio](https://github.com/DaemonAlex/dps-studio) | Build rooms, doors and portals in game from one panel (`/studio`), with owners and managers so staff do not have to support them. |
| [dps-shops](https://github.com/DaemonAlex/dps-shops) | Shop clerks who greet and react to a robbery, then player-owned shops. |
| [dps-fleet](https://github.com/DaemonAlex/dps-fleet) | Vehicle browser and workshop on one panel: extras, liveries and mods for emergency vehicles. |
| [dps-parking](https://github.com/DaemonAlex/dps-parking) | Parking with valet, impound, violations and reserved spots. |
| [dps-vehiclepersistence](https://github.com/DaemonAlex/dps-vehiclepersistence) | Vehicles stay where they were parked. Pairs with dps-parking. |
| [dps-towjob](https://github.com/DaemonAlex/dps-towjob) | Queue-based tow job with jg-mechanic integration. |
| [dps-services](https://github.com/DaemonAlex/dps-services) | Request a tow and follow it live on the lb-phone and lb-tablet. Pairs with dps-towjob. |
| [dps-autoshops](https://github.com/DaemonAlex/dps-autoshops) | Self-service repair shops when no mechanic is on duty. |
| [dps-cityworker](https://github.com/DaemonAlex/dps-cityworker) | City infrastructure job and career. |
| [dps-ainpcs](https://github.com/DaemonAlex/dps-ainpcs) | NPCs you can talk to, with trust, quests and intel. |
| [dps-badpeds](https://github.com/DaemonAlex/dps-badpeds) | Police interaction with NPCs: stops, arrests, intel and jail records. |
| [dps-gangwars](https://github.com/DaemonAlex/dps-gangwars) | Ambient gang NPCs, territory population and war reinforcements. |
| [dps-rotations](https://github.com/DaemonAlex/dps-rotations) | Moves dealers, harvests and other spots on a fixed schedule. |
| [dps-trains](https://github.com/DaemonAlex/dps-trains) | The train system. Pairs with dps-trains-stock, dps-traintools and dps-transitapp. |
| [dps-transitapp](https://github.com/DaemonAlex/dps-transitapp) | Live train arrival boards on the lb-phone. |
| [dps-faceplant](https://github.com/DaemonAlex/dps-faceplant) | City help, reports and staff tools on the lb-phone and lb-tablet. |
| [dps-chat](https://github.com/DaemonAlex/dps-chat) | A command box for voice-only servers. No chat feed. |
| [dps-filmmode](https://github.com/DaemonAlex/dps-filmmode) | One key hides every HUD layer and gives a smooth free camera for recording. |
