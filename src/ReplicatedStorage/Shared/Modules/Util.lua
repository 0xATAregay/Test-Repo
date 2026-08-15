-- Util.lua
-- Shared utility functions used by both client and server.

local Util = {}

-- Formats large numbers: 1500 -> "1.5K", 1500000 -> "1.5M"
function Util.formatNumber(n)
    n = math.floor(n + 0.5)
    if     n >= 1e12 then return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9  then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6  then return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3  then return string.format("%.1fK", n / 1e3)
    else                  return tostring(n)
    end
end

-- Deep copy a table (prevents mutation of config tables)
function Util.deepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    local copy = {}
    for key, value in pairs(original) do
        copy[Util.deepCopy(key)] = Util.deepCopy(value)
    end
    return copy
end

-- Shallow merge table b into table a (b overwrites a)
function Util.merge(a, b)
    local result = {}
    for k, v in pairs(a) do result[k] = v end
    for k, v in pairs(b) do result[k] = v end
    return result
end

-- Clamp a number between min and max
function Util.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Get current date as "YYYY-MM-DD" string
function Util.getDateString()
    return os.date("!%Y-%m-%d")
end

-- Check if two date strings represent the same day
function Util.isSameDay(date1, date2)
    return date1 == date2
end

-- Check if date1 is exactly one day before date2
function Util.isConsecutiveDay(date1, date2)
    if date1 == "" or date2 == "" then return false end

    local y1, m1, d1 = date1:match("(%d+)-(%d+)-(%d+)")
    local y2, m2, d2 = date2:match("(%d+)-(%d+)-(%d+)")

    if not (y1 and y2) then return false end

    local time1 = os.time({ year = tonumber(y1), month = tonumber(m1), day = tonumber(d1) })
    local time2 = os.time({ year = tonumber(y2), month = tonumber(m2), day = tonumber(d2) })

    local diff = time2 - time1
    return diff >= 86400 and diff < 172800 -- between 1 and 2 days
end

-- Weighted random selection from a table of { item, weight } pairs
function Util.weightedRandom(entries)
    local total = 0
    for _, entry in ipairs(entries) do
        total = total + entry.weight
    end
    if total <= 0 then return nil end

    local roll = math.random(1, total)
    local cumulative = 0
    for _, entry in ipairs(entries) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.item
        end
    end
    return entries[#entries].item -- fallback
end

-- Shuffle an array in-place (Fisher-Yates)
function Util.shuffle(array)
    for i = #array, 2, -1 do
        local j = math.random(1, i)
        array[i], array[j] = array[j], array[i]
    end
    return array
end

return Util
