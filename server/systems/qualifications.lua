-- Server: Pilot qualifications - the pilot license and per-aircraft type ratings
--
-- One check (Qualifications.CanFlyAircraft) gates every way into a cockpit: startFlight,
-- spawnAircraft and bookCharter. In order: the pilot license from the flight school
-- checkride, the pilot rank (Config.PilotRanks), then a type rating for the model.
-- Trainers at or below Config.Qualifications.licenseCoversRank need only the license.
-- Type ratings are bought per aircraft on the Type Ratings screen.

Qualifications = {}

local function Decode(value)
    if type(value) ~= 'string' or value == '' then return {} end
    local ok, decoded = pcall(json.decode, value)
    return (ok and type(decoded) == 'table') and decoded or {}
end

local function NeedsRating(aircraft)
    return (aircraft.minRank or 1) > (Config.Qualifications.licenseCoversRank or 1)
end

---Licenses and type ratings for a pilot. Pilots who flew before qualifications existed
---keep what they have flown: the first read (type_ratings still NULL) rates them for every
---model they completed a flight in, and gives them the license if they completed any.
---@param citizenid string
---@return table licenses, table ratings
function Qualifications.Get(citizenid)
    local row = MySQL.single.await(
        'SELECT licenses, type_ratings FROM airline_pilot_stats WHERE citizenid = ?',
        { citizenid }
    )
    if not row then return {}, {} end

    local licenses = Decode(row.licenses)
    local ratings = Decode(row.type_ratings)

    if row.type_ratings == nil then
        local flown = MySQL.query.await(
            'SELECT DISTINCT aircraft_model FROM airline_flights WHERE pilot_citizenid = ? AND status = ?',
            { citizenid, Constants.DB_STATUS_COMPLETED }
        ) or {}
        for _, f in ipairs(flown) do
            ratings[f.aircraft_model] = { model = f.aircraft_model, granted = os.time(), source = 'flown' }
        end
        if #flown > 0 and not licenses.ppl then
            licenses.ppl = { granted = os.time(), type = 'Private Pilot License', source = 'flown' }
        end
        MySQL.update.await(
            'UPDATE airline_pilot_stats SET licenses = ?, type_ratings = ? WHERE citizenid = ?',
            { json.encode(licenses), json.encode(ratings), citizenid }
        )
    end

    return licenses, ratings
end

---May this pilot fly this aircraft? Every cockpit entry point calls this.
---@param citizenid string
---@param aircraft table entry from Config.Aircraft
---@return boolean ok, string|nil reason
function Qualifications.CanFlyAircraft(citizenid, aircraft)
    local q = Config.Qualifications
    local licenses, ratings = Qualifications.Get(citizenid)

    if q.requireLicense and not licenses.ppl then
        return false, 'You need a pilot license: pass the flight school checkride first'
    end

    local rank = GetPilotRankShared(citizenid)
    if (aircraft.minRank or 1) > rank.rank then
        local need = Config.PilotRanks[aircraft.minRank or 1]
        return false, ('Requires %s - you are %s'):format(need and need.name or 'a higher rank', rank.name)
    end

    if q.requireTypeRating and NeedsRating(aircraft) and not ratings[aircraft.model] then
        return false, ('No type rating for the %s: get rated on the Type Ratings screen'):format(aircraft.label)
    end

    return true
end

-- Buy a type rating course for one aircraft. Server-side price, rank and license checks;
-- the client only says which model. Returns one table ({ ok, reason }) because the NUI
-- fetch bridge passes only a callback's first return value back to React.
lib.callback.register('dps-airlines:server:buyTypeRating', function(source, model)
    local ok, reason = Validation.Check(source, {
        employee = true,
        rateLimit = { action = 'buyTypeRating', cooldown = Constants.THROTTLE_SLOW },
    })
    if not ok then return { ok = false, reason = reason } end

    local aircraft = Locations.GetAircraftConfig(model)
    if not aircraft then return { ok = false, reason = 'Invalid aircraft' } end
    if not NeedsRating(aircraft) then
        return { ok = false, reason = 'Your pilot license already covers this aircraft' }
    end

    local player = Bridge.GetPlayer(source)
    if not player then return { ok = false, reason = 'Player not found' } end

    local licenses, ratings = Qualifications.Get(player.identifier)
    if Config.Qualifications.requireLicense and not licenses.ppl then
        return { ok = false, reason = 'Pass the flight school checkride first' }
    end
    if ratings[aircraft.model] then return { ok = false, reason = 'Already rated' } end

    local rank = GetPilotRankShared(player.identifier)
    if (aircraft.minRank or 1) > rank.rank then
        local need = Config.PilotRanks[aircraft.minRank or 1]
        return { ok = false, reason = ('Requires %s - you are %s'):format(need and need.name or 'a higher rank', rank.name) }
    end

    local fee = Config.Qualifications.typeRatingFee[aircraft.minRank or 1] or 0
    if fee > 0 and not Payments.ChargePlayer(source, fee, 'Type rating: ' .. aircraft.label) then
        return { ok = false, reason = 'Insufficient funds' }
    end

    ratings[aircraft.model] = { model = aircraft.model, granted = os.time(), source = 'course' }
    MySQL.update.await(
        'UPDATE airline_pilot_stats SET type_ratings = ? WHERE citizenid = ?',
        { json.encode(ratings), player.identifier }
    )
    Cache.Invalidate('stats_' .. player.identifier)

    return { ok = true, label = aircraft.label, fee = fee }
end)

-- Tell the admin who ran a command: a notification in game, a line in the server console.
local function Reply(source, msg, notifType)
    if source > 0 then
        TriggerClientEvent('dps-airlines:client:notify', source, msg, notifType)
    else
        print('[dps-airlines] ' .. msg)
    end
end

-- Admin test helper: /airlinequalify [id] gives the license and every type rating.
-- Rank still comes from hours and flights. ox_lib restricts it to group.admin.
lib.addCommand('airlinequalify', {
    help = 'Give an airline pilot the license and every type rating (testing)',
    params = { { name = 'target', type = 'playerId', help = 'Player id (default: you)', optional = true } },
    restricted = 'group.admin',
}, function(source, args)
    local target = args.target or source
    local player = target > 0 and Bridge.GetPlayer(target) or nil
    if not player then return Reply(source, 'Player not found', 'error') end

    local licenses, ratings = Qualifications.Get(player.identifier)
    licenses.ppl = licenses.ppl or { granted = os.time(), type = 'Private Pilot License', source = 'admin' }
    for _, ac in ipairs(Config.Aircraft) do
        ratings[ac.model] = ratings[ac.model] or { model = ac.model, granted = os.time(), source = 'admin' }
    end
    MySQL.update.await(
        'UPDATE airline_pilot_stats SET licenses = ?, type_ratings = ? WHERE citizenid = ?',
        { json.encode(licenses), json.encode(ratings), player.identifier }
    )
    Cache.Invalidate('stats_' .. player.identifier)

    Reply(source, ('%s now has the pilot license and all %d type ratings'):format(player.fullName or player.identifier, #Config.Aircraft), 'success')
end)
