-- ============================================================================
-- UpgradeService.lua
-- Handles all upgrade purchases and stat calculations.
-- Server never trusts the client's claimed level or cost.
-- ============================================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents      = require(ReplicatedStorage.Shared.Events.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local QuestService      = require(script.Parent.QuestService)
local DataConfig        = require(ReplicatedStorage.Shared.Modules.DataConfig)

local UpgradeService = {}

-- Upgrade catalogue: display metadata here, balance values from DataConfig (single source of truth)
local CATALOGUE = {
    clickPower = {
        displayName    = "Click Power",
        description    = "Increases souls earned per click.",
        baseCost       = DataConfig.UPGRADES.swingDamage.baseCost,
        costMultiplier = DataConfig.UPGRADES.swingDamage.costMultiplier,
        baseValue      = DataConfig.UPGRADES.swingDamage.baseValue,
        valuePerLevel  = DataConfig.UPGRADES.swingDamage.valuePerLevel,
        maxLevel       = DataConfig.UPGRADES.swingDamage.maxLevel,
        statKey        = "swingDamage",
        currency       = "souls",
    },
    clickSpeed = {
        displayName    = "Click Speed",
        description    = "Reduces the cooldown between clicks.",
        baseCost       = DataConfig.UPGRADES.swingSpeed.baseCost,
        costMultiplier = DataConfig.UPGRADES.swingSpeed.costMultiplier,
        baseValue      = DataConfig.UPGRADES.swingSpeed.baseValue,
        valuePerLevel  = DataConfig.UPGRADES.swingSpeed.valuePerLevel,
        maxLevel       = DataConfig.UPGRADES.swingSpeed.maxLevel,
        statKey        = "swingSpeed",
        currency       = "souls",
    },
    soulMultiplier = {
        displayName    = "Soul Multiplier",
        description    = "Multiplies all soul income.",
        baseCost       = DataConfig.UPGRADES.soulMultiplier.baseCost,
        costMultiplier = DataConfig.UPGRADES.soulMultiplier.costMultiplier,
        baseValue      = DataConfig.UPGRADES.soulMultiplier.baseValue,
        valuePerLevel  = DataConfig.UPGRADES.soulMultiplier.valuePerLevel,
        maxLevel       = DataConfig.UPGRADES.soulMultiplier.maxLevel,
        statKey        = "soulMultiplier",
        currency       = "souls",
    },
    gemFindChance = {
        displayName    = "Gem Finder",
        description    = "Increases the chance of finding a gem per click.",
        baseCost       = DataConfig.UPGRADES.gemFindChance.baseCost,
        costMultiplier = DataConfig.UPGRADES.gemFindChance.costMultiplier,
        baseValue      = DataConfig.UPGRADES.gemFindChance.baseValue,
        valuePerLevel  = DataConfig.UPGRADES.gemFindChance.valuePerLevel,
        maxLevel       = DataConfig.UPGRADES.gemFindChance.maxLevel,
        statKey        = "gemFindChance",
        currency       = "souls",
    },
}

-- Pure math helpers
local function _costAtLevel(cfg, level)
    return math.floor(cfg.baseCost * (cfg.costMultiplier ^ level))
end

local function _statAtLevel(cfg, level)
    return cfg.baseValue + (cfg.valuePerLevel * level)
end

local function _getLevel(data, statKey)
    return (data.upgrades and data.upgrades[statKey]) or 0
end

local function _setLevel(data, statKey, level)
    if not data.upgrades then data.upgrades = {} end
    data.upgrades[statKey] = level
end

-- Response builders
local function _buildUpgradePayload(upgradeId, cfg, newLevel)
    local atMax = newLevel >= cfg.maxLevel
    return {
        type         = "upgrade",
        upgradeId    = upgradeId,
        displayName  = cfg.displayName,
        newStatValue = _statAtLevel(cfg, newLevel),
        newLevel     = newLevel,
        maxLevel     = cfg.maxLevel,
        isMaxLevel   = atMax,
        nextCost     = atMax and 0 or _costAtLevel(cfg, newLevel),
        currency     = cfg.currency,
    }
end

local function _buildErrorPayload(upgradeId, reason)
    return {
        type      = "upgradeError",
        upgradeId = upgradeId,
        reason    = reason,
    }
end

-- Rate limiter
local _lastRequestTime = {}
local REQUEST_COOLDOWN = 0.1

local function _isRateLimited(userId)
    local now  = tick()
    local last = _lastRequestTime[userId] or 0
    if (now - last) < REQUEST_COOLDOWN then
        return true
    end
    _lastRequestTime[userId] = now
    return false
end

-- Core purchase handler
local function _processPurchase(player, upgradeId)
    local userId = player.UserId

    if _isRateLimited(userId) then return end

    local cfg = CATALOGUE[upgradeId]
    if not cfg then
        warn(string.format(
            "[UpgradeService] Unknown upgradeId '%s' from %s",
            tostring(upgradeId), player.Name
        ))
        RemoteEvents.DataUpdate:FireClient(player,
            _buildErrorPayload(upgradeId, "Unknown upgrade.")
        )
        return
    end

    local purchaseError = nil

    local ok = PlayerDataService.UpdateData(player, function(data)
        if not data then
            purchaseError = "Profile not available. Please rejoin."
            return
        end

        local currentLevel = _getLevel(data, cfg.statKey)

        if currentLevel >= cfg.maxLevel then
            purchaseError = cfg.displayName .. " is already at max level!"
            return
        end

        local cost = _costAtLevel(cfg, currentLevel)
        local balance = data[cfg.currency] or 0

        if balance < cost then
            purchaseError = string.format(
                "Not enough %s. Need %d, have %d.",
                cfg.currency, cost, balance
            )
            return
        end

        data[cfg.currency]         = balance - cost
        data.upgrades[cfg.statKey] = currentLevel + 1
    end)

    if not ok then
        RemoteEvents.DataUpdate:FireClient(player,
            _buildErrorPayload(upgradeId, "Could not process upgrade. Please rejoin.")
        )
        return
    end

    if purchaseError then
        RemoteEvents.DataUpdate:FireClient(player,
            _buildErrorPayload(upgradeId, purchaseError)
        )
        return
    end

    -- Success path
    local data = PlayerDataService.GetData(player)
    if not data then return end

    local confirmedLevel = _getLevel(data, cfg.statKey)

    RemoteEvents.DataUpdate:FireClient(player,
        _buildUpgradePayload(upgradeId, cfg, confirmedLevel)
    )

    RemoteEvents.DataUpdate:FireClient(player, {
        type       = "currency",
        currency   = cfg.currency,
        newBalance = data[cfg.currency],
    })

    -- Wire quest progress: track upgrade purchases
    QuestService.trackProgress(player, "upgrades", 1)

    print(string.format(
        "[UpgradeService] %s purchased '%s' -> level %d",
        player.Name, upgradeId, confirmedLevel
    ))
end

-- Public API
function UpgradeService.GetCatalogue()
    return CATALOGUE
end

function UpgradeService.GetUpgradeInfo(player, upgradeId)
    local cfg = CATALOGUE[upgradeId]
    if not cfg then return nil end

    local data = PlayerDataService.GetData(player)
    if not data then return nil end

    local level = _getLevel(data, cfg.statKey)
    local atMax = level >= cfg.maxLevel

    return {
        level      = level,
        statValue  = _statAtLevel(cfg, level),
        cost       = atMax and 0 or _costAtLevel(cfg, level),
        isMaxLevel = atMax,
        maxLevel   = cfg.maxLevel,
        currency   = cfg.currency,
    }
end

function UpgradeService.GetStatValue(player, upgradeId)
    local info = UpgradeService.GetUpgradeInfo(player, upgradeId)
    return info and info.statValue or nil
end

function UpgradeService.init()
    RemoteEvents.UpgradeRequest.OnServerEvent:Connect(function(player, upgradeId)
        task.spawn(_processPurchase, player, upgradeId)
    end)

    RemoteEvents.PurchaseUpgrade.OnServerEvent:Connect(function(player, upgradeKey)
        task.spawn(_processPurchase, player, upgradeKey)
    end)

    Players.PlayerRemoving:Connect(function(player)
        _lastRequestTime[player.UserId] = nil
    end)

    print("[UpgradeService] Initialised.")
end

return UpgradeService
