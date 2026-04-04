-- ============================================================================
-- RebirthService.lua
-- Handles rebirth and ascension logic.
-- Rebirth resets currencies + upgrades but awards permanent Reaper Tokens.
-- Ascension unlocks after 10 rebirths for a god-tier multiplier.
-- ============================================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents      = require(ReplicatedStorage.Shared.Events.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local DataConfig        = require(game.ReplicatedStorage.Shared.Modules.DataConfig)

local RebirthService = {}

-- Rate limiting
local _lastRebirthTime = {}
local REBIRTH_COOLDOWN = 2.0

--[[
    RebirthService.attemptRebirth(player)
    Validates requirements, resets progress, awards Reaper Tokens.
    Preserves: spirits, equippedSpirits, totalSoulsMined, settings,
               reaperTokens, rebirthCount, ascensionCount.
]]
function RebirthService.attemptRebirth(player)
    local userId = player.UserId

    -- Rate limit
    if _lastRebirthTime[userId] and (tick() - _lastRebirthTime[userId]) < REBIRTH_COOLDOWN then
        return
    end
    _lastRebirthTime[userId] = tick()

    local data = PlayerDataService.GetData(player)
    if not data then return end

    local nextRebirthIndex = data.rebirthCount + 1
    local rebirthData = DataConfig.REBIRTHS[nextRebirthIndex]

    if not rebirthData then
        -- Check if eligible for ascension instead
        if data.rebirthCount >= DataConfig.ASCENSION.rebirthsRequired then
            RebirthService.attemptAscension(player)
            return
        end

        RemoteEvents.RebirthResult:FireClient(player, {
            success = false,
            reason = "Max rebirths reached! Try ascending instead.",
        })
        return
    end

    if data.totalSoulsMined < rebirthData.soulsRequired then
        RemoteEvents.RebirthResult:FireClient(player, {
            success = false,
            reason = string.format(
                "You need %s lifetime souls to rebirth! (You have %s)",
                tostring(rebirthData.soulsRequired),
                tostring(data.totalSoulsMined)
            ),
        })
        return
    end

    -- Apply rebirth
    PlayerDataService.UpdateData(player, function(d)
        d.rebirthCount = d.rebirthCount + 1
        d.reaperTokens = (d.reaperTokens or 0) + rebirthData.tokenReward

        -- Reset currencies (except reaperTokens)
        d.souls = 0
        d.gems = 0
        d.spiritShards = 0

        -- Reset zone progress
        d.currentZone = 1

        -- Reset upgrades
        d.upgrades = {
            swingDamage = 0,
            swingSpeed = 0,
            soulMultiplier = 0,
            gemFindChance = 0,
        }

        -- Reset pity counters
        d.pity = {
            shadowEgg = 0,
            infernalEgg = 0,
            voidEgg = 0,
        }

        -- Spirits are preserved (collection persists across rebirths)
        -- equippedSpirits preserved
        -- totalSoulsMined preserved (lifetime stat)
        -- totalClicks preserved
        -- totalEggsOpened preserved
        -- settings preserved
    end)

    local updatedData = PlayerDataService.GetData(player)

    RemoteEvents.RebirthResult:FireClient(player, {
        success = true,
        rebirthCount = updatedData.rebirthCount,
        tokensEarned = rebirthData.tokenReward,
        newTokenBalance = updatedData.reaperTokens,
        multiplierBonus = rebirthData.multiplierBonus,
    })

    -- Full data resync
    RemoteEvents.DataLoaded:FireClient(player, {
        currencies = {
            souls = 0,
            gems = 0,
            reaperTokens = updatedData.reaperTokens,
            spiritShards = 0,
        },
        upgrades = updatedData.upgrades,
        currentZone = updatedData.currentZone,
        rebirthCount = updatedData.rebirthCount,
        spirits = updatedData.spirits,
        equippedSpirits = updatedData.equippedSpirits,
        pity = updatedData.pity,
        settings = updatedData.settings,
        dailyQuests = updatedData.dailyQuests,
        dailyRewardClaimed = updatedData.dailyRewardClaimed,
        loginStreak = updatedData.loginStreak,
    })

    -- Server announcement
    RemoteEvents.ServerAnnouncement:FireAllClients({
        type = "REBIRTH",
        playerName = player.Name,
        rebirthCount = updatedData.rebirthCount,
    })

    print(string.format(
        "[RebirthService] %s reborn! Count: %d, Tokens earned: %d",
        player.Name, updatedData.rebirthCount, rebirthData.tokenReward
    ))
end

--[[
    RebirthService.attemptAscension(player)
    Ascension resets rebirth count and awards a god-tier permanent multiplier.
    Requires 10+ rebirths.
]]
function RebirthService.attemptAscension(player)
    local data = PlayerDataService.GetData(player)
    if not data then return end

    if data.rebirthCount < DataConfig.ASCENSION.rebirthsRequired then
        RemoteEvents.RebirthResult:FireClient(player, {
            success = false,
            reason = string.format(
                "You need %d rebirths to ascend! (You have %d)",
                DataConfig.ASCENSION.rebirthsRequired,
                data.rebirthCount
            ),
        })
        return
    end

    if (data.ascensionCount or 0) >= DataConfig.ASCENSION.maxAscensions then
        RemoteEvents.RebirthResult:FireClient(player, {
            success = false,
            reason = "You have reached the maximum number of ascensions!",
        })
        return
    end

    PlayerDataService.UpdateData(player, function(d)
        d.ascensionCount = (d.ascensionCount or 0) + 1

        -- Reset rebirths
        d.rebirthCount = 0

        -- Full reset like rebirth
        d.souls = 0
        d.gems = 0
        d.spiritShards = 0
        d.currentZone = 1
        d.upgrades = {
            swingDamage = 0,
            swingSpeed = 0,
            soulMultiplier = 0,
            gemFindChance = 0,
        }
        d.pity = {
            shadowEgg = 0,
            infernalEgg = 0,
            voidEgg = 0,
        }

        -- Spirits preserved, reaperTokens preserved
    end)

    local updatedData = PlayerDataService.GetData(player)

    RemoteEvents.RebirthResult:FireClient(player, {
        success = true,
        isAscension = true,
        ascensionCount = updatedData.ascensionCount,
        godTierMultiplier = DataConfig.ASCENSION.godTierMultiplier,
    })

    -- Full data resync so client UI reflects the reset
    RemoteEvents.DataLoaded:FireClient(player, {
        currencies = {
            souls = 0,
            gems = 0,
            reaperTokens = updatedData.reaperTokens,
            spiritShards = 0,
        },
        upgrades = updatedData.upgrades,
        currentZone = updatedData.currentZone,
        rebirthCount = updatedData.rebirthCount,
        ascensionCount = updatedData.ascensionCount,
        spirits = updatedData.spirits,
        equippedSpirits = updatedData.equippedSpirits,
        pity = updatedData.pity,
        settings = updatedData.settings,
        dailyQuests = updatedData.dailyQuests,
        dailyRewardClaimed = updatedData.dailyRewardClaimed,
        loginStreak = updatedData.loginStreak,
    })

    RemoteEvents.ServerAnnouncement:FireAllClients({
        type = "ASCENSION",
        playerName = player.Name,
        ascensionCount = updatedData.ascensionCount,
    })

    print(string.format(
        "[RebirthService] %s ASCENDED! Count: %d",
        player.Name, updatedData.ascensionCount
    ))
end

--[[
    RebirthService.getRebirthInfo(player) -> table
    Returns current rebirth state for UI display.
]]
function RebirthService.getRebirthInfo(player)
    local data = PlayerDataService.GetData(player)
    if not data then return nil end

    local nextIndex = data.rebirthCount + 1
    local nextRebirth = DataConfig.REBIRTHS[nextIndex]

    local canAscend = data.rebirthCount >= DataConfig.ASCENSION.rebirthsRequired
        and (data.ascensionCount or 0) < DataConfig.ASCENSION.maxAscensions

    return {
        rebirthCount = data.rebirthCount,
        ascensionCount = data.ascensionCount or 0,
        currentMultiplier = 1 + (data.rebirthCount * 0.15),
        nextRebirthSouls = nextRebirth and nextRebirth.soulsRequired or nil,
        nextTokenReward = nextRebirth and nextRebirth.tokenReward or nil,
        totalSoulsMined = data.totalSoulsMined,
        canRebirth = nextRebirth and data.totalSoulsMined >= nextRebirth.soulsRequired,
        canAscend = canAscend,
        maxRebirthReached = not nextRebirth and not canAscend,
    }
end

function RebirthService.init()
    RemoteEvents.AttemptRebirth.OnServerEvent:Connect(function(player)
        task.spawn(RebirthService.attemptRebirth, player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        _lastRebirthTime[player.UserId] = nil
    end)

    print("[RebirthService] Initialised.")
end

return RebirthService
