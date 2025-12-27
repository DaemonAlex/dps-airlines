# DPS Airlines

A comprehensive airlines job system for FiveM QBCore servers using ox_lib.

## Features

- **Passenger Flights** - Transport NPC passengers between airports
- **Cargo Transport** - Haul freight with weight-based payouts
- **Private Charters** - VIP transport services for players
- **Flight School** - 3-lesson training program for pilot certification
- **Aircraft Maintenance** - Service and repair company aircraft
- **Boss Menu** - Manage employees, view finances, hire/fire pilots
- **Dispatch System** - Available jobs board with priority assignments
- **ATC Clearance** - Realistic flight plan approval system
- **Weather Delays** - Dynamic weather impacts on flight operations
- **Reputation System** - Build pilot rep for better assignments

## Dependencies

- [qb-core](https://github.com/qbcore-framework/qb-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)
- qs-fuel (or compatible fuel script)

## Installation

1. Place `dps-airlines` in your resources folder
2. Run `sql/install.sql` in your database
3. Add the `pilot` job to `qb-core/shared/jobs.lua`:
```lua
pilot = {
    label = 'Los Santos Airlines',
    type = 'transportation',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Trainee', payment = 50 },
        [1] = { name = 'Pilot', payment = 75 },
        [2] = { name = 'Boss', isboss = true, payment = 150 }
    }
},
```
4. Add `pilots_license` item to `qb-core/shared/items.lua`
5. Add `flightrep = 0` to player metadata in `qb-core/config.lua`
6. Restart server (resource auto-loads if in a bracket folder)

## Airports

| Airport | Type | Planes |
|---------|------|--------|
| Los Santos International (LSIA) | Hub/International | All |
| Sandy Shores Airfield | Regional | Luxor, Shamal |
| Grapeseed Airstrip | Rural | Luxor only |
| Fort Zancudo | Military (Restricted) | All |
| Roxwood International | International | All |
| Paleto Regional | Regional | Luxor, Shamal, Nimbus |

## Configuration

Edit `shared/config.lua` to customize:
- Pay rates and multipliers
- Plane models and capacity
- Weather thresholds
- Maintenance intervals
- Flight school pricing
- Dispatch job generation

Edit `shared/locations.lua` for:
- Airport coordinates
- NPC positions
- Spawn points

## License
 Original concept and code by @daemonalex
Free to use and modify for your server.
