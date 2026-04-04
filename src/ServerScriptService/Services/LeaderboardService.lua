-- ============================================================================
-- LeaderboardService.lua
-- Manages OrderedDataStore leaderboards with rate-limit-aware queuing.
-- Updates leaderboards periodically and serves cached results to clients.
-- ============================================================================

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents      = require(ReplicatedStorage.Shared.Events.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)

local LeaderboardService = {}

-- Leaderboard definitions
local BOARDS = {
    topSouls = {
        dataStoreName = "Leaderboard_TopSouls",
        displayName = "Most Souls Mined",
        statKey = "totalSoulsMined",
        maxEntries = 100,
    },
    topRebirths = {
        dataStoreName = "Leaderboard_TopRebirths",
        displayName = "Most Rebirths",
        statKey = "rebirthCount",
        maxEntries = 50,
    },
    topSpirits = {
        dataStoreName = "Leaderboard_TopSpirits",
        displayName = "Most Spirits",
        statKey = function(data) return #data.spirits end,
        maxEntries = 50,
    },
}

-- Cached leaderboard results
local _cache = {} -- [boardId] = { entries = {}, lastUpdate = tick() }
local CACHE_TTL = 60 -- seconds between cache refreshes
local UPDATE_INTERVAL = 30 -- seconds between player stat pushes

-- Get or create an OrderedDataStore
local function _getStore(boardConfig)
    return DataStoreService:GetOrderedDataStore(boardConfig.dataStoreName)
end

-- Get a player's stat value for a leaderboard
local function _getStatValue(data, statKey)
    if type(statKey) == "function" then
        return statKey(data)
    end
    return data[statKey] or 0
end

--[[
    LeaderboardService.updatePlayerStats()
    Pushes all online players' stats to the ordered data stores.
    Rate-limited to avoid DataStore throttling.
]]
function LeaderboardService.updatePlayerStats()
    for boardId, boardConfig in pairs(BOARDS) do
        local store = _getStore(boardConfig)

        for _, player in ipairs(Players:GetPlayers()) do
            local data = PlayerDataService.GetData(player)
            if data then
                local value = _getStatValue(data, boardConfig.statKey)
                if value > 0 then
                    pcall(function()
                        store:SetAsync(tostring(player.UserId), value)
                    end)
                end
            end
            task.wait(0.5) -- Rate limit: 1 write per 0.5s per key
        end
    end
end

--[[
    LeaderboardService.getLeaderboard(boardId, count) -> table
    Returns the top N entries from a leaderboard.
    Uses cached results if available and fresh.
]]
function LeaderboardService.getLeaderboard(boardId, count)
    count = count or 10
    local boardConfig = BOARDS[boardId]
    if not boardConfig then return { entries = {}, boardType = boardId } end

    -- Check cache
    local cached = _cache[boardId]
    if cached and (tick() - cached.lastUpdate) < CACHE_TTL then
        local result = {}
        for i = 1, math.min(count, #cached.entries) do
            result[i] = cached.entries[i]
        end
        return { entries = result, boardType = boardId, displayName = boardConfig.displayName }
    end

    -- Fetch from DataStore
    local store = _getStore(boardConfig)
    local entries = {}

    local success, pages = pcall(function()
        return store:GetSortedAsync(false, boardConfig.maxEntries)
    end)

    if success and pages then
        local page = pages:GetCurrentPage()
        for rank, entry in ipairs(page) do
            local userId = tonumber(entry.key)
            local playerName = "[Unknown]"

            pcall(function()
                playerName = Players:GetNameFromUserIdAsync(userId)
            end)

            table.insert(entries, {
                rank = rank,
                userId = userId,
                playerName = playerName,
                value = entry.value,
            })
        end
    end

    -- Update cache
    _cache[boardId] = {
        entries = entries,
        lastUpdate = tick(),
    }

    local result = {}
    for i = 1, math.min(count, #entries) do
        result[i] = entries[i]
    end
    return { entries = result, boardType = boardId, displayName = boardConfig.displayName }
end

function LeaderboardService.init()
    -- Handle leaderboard requests
    RemoteEvents.RequestLeaderboard.OnServerInvoke = function(player, boardType)
        return LeaderboardService.getLeaderboard(boardType or "topSouls", 10)
    end

    -- Periodic stat update loop
    task.spawn(function()
        while true do
            task.wait(UPDATE_INTERVAL)
            pcall(LeaderboardService.updatePlayerStats)
        end
    end)

    print("[LeaderboardService] Initialised.")
end

return LeaderboardService
