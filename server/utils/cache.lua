---@class Cache
---@field data table
---@field ttl table
Cache = {}
Cache._store = {}

---Get a cached value, or compute and store it
---@param key string
---@param ttlSeconds number
---@param computeFn function
---@return any
function Cache.Get(key, ttlSeconds, computeFn)
    local entry = Cache._store[key]
    local now = os.time()

    if entry and (now - entry.time) < ttlSeconds then
        return entry.value
    end

    local success, value = pcall(computeFn)
    if success then
        Cache._store[key] = { value = value, time = now }
        return value
    else
        print('^1[DPS-Airlines Cache] Error computing key ' .. key .. ': ' .. tostring(value) .. '^0')
        return entry and entry.value or nil
    end
end

---Invalidate a specific cache key
---@param key string
function Cache.Invalidate(key)
    Cache._store[key] = nil
end

---Invalidate all keys matching a pattern prefix
---@param prefix string
function Cache.InvalidatePrefix(prefix)
    for key in pairs(Cache._store) do
        if key:sub(1, #prefix) == prefix then
            Cache._store[key] = nil
        end
    end
end

---Clear entire cache
function Cache.Clear()
    Cache._store = {}
end

---Get cache stats
---@return table
function Cache.Stats()
    local count = 0
    for _ in pairs(Cache._store) do
        count = count + 1
    end
    return { entries = count }
end
