-- ============================================================================
-- PlayerDataService.lua
-- ServerScriptService/Services/PlayerDataService.lua
--
-- Responsibilities:
--   * Load each player's profile via ProfileService on join
--   * Expose GetData() / UpdateData() to all other services
--   * Auto-save every 60 s (ProfileService handles the actual DataStore write)
--   * Guarantee a final save on server shutdown (BindToClose)
--   * Version the data schema so future additions never break existing saves
--
-- Dependencies:
--   ProfileService  - madstudioroblox/ProfileService (open-source community library)
--                     https://madstudioroblox.github.io/ProfileService/
-- ============================================================================

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")

-- ProfileService must be parented somewhere require()-able.
local ProfileService     = require(game.ServerScriptService.Lib.ProfileService)

local PlayerDataService  = {}

-- Schema versioning
local CURRENT_VERSION = 1

-- Default data template
local DATA_TEMPLATE = {
    -- Meta
    _version        = CURRENT_VERSION,
    _createdAt      = 0,
    _lastSeen       = 0,

    -- Currencies
    souls           = 0,
    gems            = 0,
    reaperTokens    = 0,
    spiritShards    = 0,

    -- Lifetime stats (never reset on rebirth)
    totalSoulsMined = 0,
    totalClicks     = 0,
    totalEggsOpened = 0,

    -- Progression
    currentZone     = 1,
    rebirthCount    = 0,
    ascensionCount  = 0,

    -- Upgrades
    upgrades = {
        swingDamage    = 0,
        swingSpeed     = 0,
        soulMultiplier = 0,
        gemFindChance  = 0,
    },

    -- Inventory
    spirits         = {},
    equippedSpirits = {},   -- max 3 spirit ids

    -- Gacha pity counters (per egg type)
    pity = {
        shadowEgg   = 0,
        infernalEgg = 0,
        voidEgg     = 0,
    },

    -- Quest state
    dailyQuests      = {},
    questResetTime   = 0,

    -- Retention
    loginStreak         = 0,
    lastLoginDate       = "",
    dailyRewardIndex    = 0,
    dailyRewardClaimed  = false,

    -- Settings
    settings = {
        sfxEnabled           = true,
        musicEnabled         = true,
        notificationsEnabled = true,
    },
}

-- Migration steps
local MIGRATIONS = {
    {
        toVersion = 1,
        fn = function(_data)
            -- no-op: first version, all fields come from DATA_TEMPLATE reconcile
        end,
    },
}

-- ProfileStore
local ProfileStore = ProfileService.GetProfileStore(
    "SoulMiners_v1",
    DATA_TEMPLATE
)

-- Private state
local _profiles   = {}   -- [player] = Profile object
local _saveTimers = {}   -- [player] = last auto-save tick()

local AUTO_SAVE_INTERVAL = 60

-- Internal: run pending migrations
local function _migrate(data)
    local currentVer = data._version or 0

    for _, step in ipairs(MIGRATIONS) do
        if step.toVersion > currentVer then
            local ok, err = pcall(step.fn, data)
            if not ok then
                warn(string.format(
                    "[PlayerDataService] Migration to v%d failed: %s",
                    step.toVersion, tostring(err)
                ))
            else
                data._version = step.toVersion
            end
        end
    end

    data._version = CURRENT_VERSION
end

-- Internal: post-load setup
local function _onProfileLoaded(player, profile)
    profile:Reconcile()
    _migrate(profile.Data)

    local data = profile.Data
    if data._createdAt == 0 then
        data._createdAt = os.time()
    end
    data._lastSeen = os.time()

    profile:ListenToRelease(function()
        _profiles[player] = nil
        player:Kick(
            "Your data was loaded on another server. " ..
            "Please wait a moment and rejoin."
        )
    end)

    _profiles[player]   = profile
    _saveTimers[player] = tick()

    print(string.format(
        "[PlayerDataService] Profile loaded for %s (v%d, %d souls)",
        player.Name,
        data._version,
        data.souls
    ))
end

-- Auto-save loop
task.spawn(function()
    while true do
        task.wait(10)
        local now = tick()
        for player, profile in pairs(_profiles) do
            if (now - (_saveTimers[player] or 0)) >= AUTO_SAVE_INTERVAL then
                _saveTimers[player] = now
                task.spawn(function()
                    profile:Save()
                end)
            end
        end
    end
end)

-- Shutdown save
game:BindToClose(function()
    print("[PlayerDataService] Server shutting down - saving all profiles...")

    if RunService:IsStudio() then
        for player, profile in pairs(_profiles) do
            profile:Release()
            _profiles[player] = nil
        end
        return
    end

    local pending = 0
    for _, profile in pairs(_profiles) do
        pending += 1
        task.spawn(function()
            profile:Release()
            pending -= 1
        end)
    end

    local deadline = tick() + 25
    while pending > 0 and tick() < deadline do
        task.wait(0.5)
    end

    if pending > 0 then
        warn(string.format(
            "[PlayerDataService] Shutdown timeout - %d profile(s) may not have saved.",
            pending
        ))
    else
        print("[PlayerDataService] All profiles released cleanly.")
    end
end)

-- Player lifecycle
Players.PlayerAdded:Connect(function(player)
    local profile = ProfileStore:LoadProfileAsync("player_" .. player.UserId, "ForceLoad")

    if not profile then
        player:Kick(
            "Failed to load your data. Please rejoin in a moment. " ..
            "If this persists, contact support."
        )
        return
    end

    if not player:IsDescendantOf(Players) then
        profile:Release()
        return
    end

    _onProfileLoaded(player, profile)
end)

Players.PlayerRemoving:Connect(function(player)
    local profile = _profiles[player]
    if profile then
        profile:Release()
        _profiles[player]   = nil
        _saveTimers[player] = nil
    end
end)

-- Handle players who joined before this script ran (Studio edge case)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(function()
        if not _profiles[player] then
            local profile = ProfileStore:LoadProfileAsync("player_" .. player.UserId, "ForceLoad")
            if profile and player:IsDescendantOf(Players) then
                _onProfileLoaded(player, profile)
            elseif profile then
                profile:Release()
            end
        end
    end)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--[[
    PlayerDataService.GetData(player) -> table | nil
    Returns the live in-memory profile data for a player.
    All services should use this - never read from DataStore directly.
]]
function PlayerDataService.GetData(player)
    local profile = _profiles[player]
    return profile and profile.Data or nil
end

--[[
    PlayerDataService.UpdateData(player, callback) -> boolean
    The correct way to mutate player data from any service.
    callback(data) receives the live data table.
    Returns true if the update was applied.
]]
function PlayerDataService.UpdateData(player, callback)
    assert(type(callback) == "function", "[PlayerDataService] UpdateData requires a function callback")

    local profile = _profiles[player]
    if not profile then
        warn(string.format(
            "[PlayerDataService] UpdateData called for %s but profile is not loaded.",
            player and player.Name or "unknown"
        ))
        return false
    end

    local ok, err = pcall(callback, profile.Data)
    if not ok then
        warn(string.format(
            "[PlayerDataService] UpdateData callback error for %s: %s",
            player.Name, tostring(err)
        ))
        return false
    end

    return true
end

--[[
    PlayerDataService.IsDataLoaded(player) -> boolean
    Quick check if a player's data is available.
]]
function PlayerDataService.IsDataLoaded(player)
    return _profiles[player] ~= nil
end

return PlayerDataService
