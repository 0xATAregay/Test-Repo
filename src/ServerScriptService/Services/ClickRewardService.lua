-- ============================================================================
-- ClickRewardService.lua
-- Handles validated click-to-earn Soul rewards.
--
-- Flow:
--   Client fires "ClickRequest" ->
--   Server validates cooldown + rate limit ->
--   Server awards Souls via PlayerDataService ->
--   Server fires "DataUpdate" to client
-- ============================================================================

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local RemoteEvents       = require(ReplicatedStorage.Shared.Events.RemoteEvents)
local PlayerDataService  = require(script.Parent.PlayerDataService)
local QuestService       = require(script.Parent.QuestService)

-- Tuning constants
local CONFIG = {
    CLICK_COOLDOWN_SEC   = 0.2,
    BASE_SOULS_PER_CLICK = 10,
    SPAM_THRESHOLD       = 30,
    SPAM_WINDOW_SEC      = 5,
    SPAM_LOCKOUT_SEC     = 10,
}

-- Per-player tracking
local lastClickTime  = {}
local clickLog       = {}
local lockedUntil    = {}

local ClickRewardService = {}

-- Check rolling window for spam
local function _isSpamming(userId)
    local now = tick()
    local log = clickLog[userId]

    if not log then
        clickLog[userId] = {}
        return false
    end

    local cutoff = now - CONFIG.SPAM_WINDOW_SEC
    local pruned = {}
    for _, t in ipairs(log) do
        if t > cutoff then
            pruned[#pruned + 1] = t
        end
    end
    clickLog[userId] = pruned

    return #pruned >= CONFIG.SPAM_THRESHOLD
end

local function _recordClick(userId)
    local log = clickLog[userId] or {}
    log[#log + 1] = tick()
    clickLog[userId] = log
end

-- Calculate reward using UpgradeService if available, else fallback
local function _getSoulsReward(player, profile)
    local base = CONFIG.BASE_SOULS_PER_CLICK

    local damageLevel  = (profile.upgrades and profile.upgrades.swingDamage) or 0
    local upgradeBonus = damageLevel * 8

    -- Soul multiplier upgrade (5% per level)
    local soulMultLevel = (profile.upgrades and profile.upgrades.soulMultiplier) or 0
    local soulMult = 1.0 + (soulMultLevel * 0.05)

    local rebirthMult  = 1 + ((profile.rebirthCount or 0) * 0.15)
    local ascensionMult = 1 + ((profile.ascensionCount or 0) * 4.0)

    -- Spirit multiplier (equippedSpirits stores uid strings)
    local spiritMult = 1.0
    if profile.equippedSpirits and profile.spirits then
        for _, spiritUid in ipairs(profile.equippedSpirits) do
            for _, spirit in ipairs(profile.spirits) do
                if spirit.uid == spiritUid then
                    spiritMult = spiritMult * spirit.multiplier
                    break
                end
            end
        end
    end

    -- Zone multiplier
    local zoneMult = 1
    local ZoneConfig = require(game.ReplicatedStorage.Shared.Modules.ZoneConfig)
    local zoneData = ZoneConfig.getZone(profile.currentZone or 1)
    if zoneData then
        zoneMult = zoneData.multiplier
    end

    return math.max(1, math.floor((base + upgradeBonus) * soulMult * rebirthMult * ascensionMult * spiritMult * zoneMult))
end

-- Core click handler
local function _handleClick(player)
    local userId = player.UserId
    local now    = tick()

    local profile = PlayerDataService.GetData(player)
    if not profile then return end

    if lockedUntil[userId] and now < lockedUntil[userId] then
        return
    end

    if _isSpamming(userId) then
        lockedUntil[userId] = now + CONFIG.SPAM_LOCKOUT_SEC
        warn(string.format(
            "[ClickRewardService] Spam lockout applied -> %s (%d) for %.0fs",
            player.Name, userId, CONFIG.SPAM_LOCKOUT_SEC
        ))
        return
    end

    local last = lastClickTime[userId] or 0
    if (now - last) < CONFIG.CLICK_COOLDOWN_SEC then
        return
    end
    lastClickTime[userId] = now

    _recordClick(userId)

    local soulsEarned = _getSoulsReward(player, profile)

    PlayerDataService.UpdateData(player, function(data)
        data.souls           = (data.souls or 0) + soulsEarned
        data.totalSoulsMined = (data.totalSoulsMined or 0) + soulsEarned
        data.totalClicks     = (data.totalClicks or 0) + 1
    end)

    local updatedData = PlayerDataService.GetData(player)

    RemoteEvents.DataUpdate:FireClient(player, {
        currency    = "souls",
        newBalance  = updatedData and updatedData.souls or 0,
        delta       = soulsEarned,
    })

    -- Wire quest progress: track soul mining and click count
    QuestService.trackProgress(player, "mine_souls", soulsEarned)
    QuestService.trackProgress(player, "clicks", 1)

    -- Small chance to drop gems
    local DataConfig = require(game.ReplicatedStorage.Shared.Modules.DataConfig)
    local gemConfig = DataConfig.UPGRADES.gemFindChance
    local gemLevel = profile.upgrades.gemFindChance or 0
    local gemChance = gemConfig.baseValue + (gemLevel * gemConfig.valuePerLevel)

    if math.random() < gemChance then
        PlayerDataService.UpdateData(player, function(data)
            data.gems = (data.gems or 0) + 1
        end)
        local newData = PlayerDataService.GetData(player)
        RemoteEvents.DataUpdate:FireClient(player, {
            currency   = "gems",
            newBalance = newData and newData.gems or 0,
            delta      = 1,
        })

        -- Wire quest progress: track gem collection
        QuestService.trackProgress(player, "collect_gems", 1)
    end
end

-- Lifecycle
function ClickRewardService.init()
    RemoteEvents.ClickRequest.OnServerEvent:Connect(function(player)
        task.spawn(_handleClick, player)
    end)

    -- Also listen on SwingScythe for backward compatibility
    RemoteEvents.SwingScythe.OnServerEvent:Connect(function(player)
        task.spawn(_handleClick, player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        local userId = player.UserId
        lastClickTime[userId] = nil
        clickLog[userId]      = nil
        lockedUntil[userId]   = nil
    end)

    print("[ClickRewardService] Initialised.")
end

-- Public API: award souls directly (for quest/daily rewards)
function ClickRewardService.awardSouls(player, amount)
    assert(type(amount) == "number" and amount > 0, "amount must be a positive number")

    local success = PlayerDataService.UpdateData(player, function(data)
        data.souls           = (data.souls or 0) + amount
        data.totalSoulsMined = (data.totalSoulsMined or 0) + amount
    end)

    if not success then return false end

    local data = PlayerDataService.GetData(player)
    RemoteEvents.DataUpdate:FireClient(player, {
        currency   = "souls",
        newBalance = data and data.souls or 0,
        delta      = amount,
    })

    return true
end

return ClickRewardService
