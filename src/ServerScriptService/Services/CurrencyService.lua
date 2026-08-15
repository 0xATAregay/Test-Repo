-- ============================================================================
-- CurrencyService.lua
-- All currency read/write operations go through this service.
-- NEVER modify currency directly on the profile - always use these functions.
-- This centralizes validation, anti-exploit checks, and event firing.
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.Events.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CurrencyService = {}

-- Valid currency keys (whitelist - never trust a string from the client)
local VALID_CURRENCIES = {
    souls = true,
    gems = true,
    reaperTokens = true,
    spiritShards = true,
}

--[[
    CurrencyService.getCurrency(player, currencyName) -> number
    Returns the player's current balance for the given currency.
]]
function CurrencyService.getCurrency(player, currencyName)
    assert(VALID_CURRENCIES[currencyName], "Invalid currency: " .. tostring(currencyName))
    local data = PlayerDataService.GetData(player)
    if not data then return 0 end
    return data[currencyName] or 0
end

--[[
    CurrencyService.addCurrency(player, currencyName, amount) -> boolean
    Adds `amount` to the player's currency balance.
    Amount must be positive. Use deductCurrency for removals.
    Fires UpdateCurrency event to sync client UI.
]]
function CurrencyService.addCurrency(player, currencyName, amount)
    assert(VALID_CURRENCIES[currencyName], "Invalid currency: " .. tostring(currencyName))
    assert(type(amount) == "number" and amount > 0, "Amount must be a positive number")

    local success = PlayerDataService.UpdateData(player, function(data)
        data[currencyName] = (data[currencyName] or 0) + amount

        -- Track lifetime stat
        if currencyName == "souls" then
            data.totalSoulsMined = (data.totalSoulsMined or 0) + amount
        end
    end)

    if not success then return false end

    local data = PlayerDataService.GetData(player)
    if data then
        RemoteEvents.UpdateCurrency:FireClient(player, {
            currency = currencyName,
            newBalance = data[currencyName],
            delta = amount,
        })
    end

    return true
end

--[[
    CurrencyService.deductCurrency(player, currencyName, amount) -> boolean
    Removes `amount` from currency balance.
    Returns true on success, false if insufficient funds.
    NEVER goes negative - prevents exploit-based free purchases.
]]
function CurrencyService.deductCurrency(player, currencyName, amount)
    assert(VALID_CURRENCIES[currencyName], "Invalid currency: " .. tostring(currencyName))
    assert(type(amount) == "number" and amount > 0, "Amount must be a positive number")

    local deducted = false

    local success = PlayerDataService.UpdateData(player, function(data)
        local currentBalance = data[currencyName] or 0
        if currentBalance < amount then
            return -- insufficient funds
        end
        data[currencyName] = currentBalance - amount
        deducted = true
    end)

    if not success or not deducted then return false end

    local data = PlayerDataService.GetData(player)
    if data then
        RemoteEvents.UpdateCurrency:FireClient(player, {
            currency = currencyName,
            newBalance = data[currencyName],
            delta = -amount,
        })
    end

    return true
end

--[[
    CurrencyService.calculateMineReward(player) -> number
    Calculates how many souls a player earns per swing,
    taking into account all multipliers.
]]
function CurrencyService.calculateMineReward(player)
    local data = PlayerDataService.GetData(player)
    if not data then return 0 end

    local DataConfig = require(game.ReplicatedStorage.Shared.Modules.DataConfig)
    local ZoneConfig = require(game.ReplicatedStorage.Shared.Modules.ZoneConfig)

    -- Base damage from upgrade level
    local damageConfig = DataConfig.UPGRADES.swingDamage
    local damageLevel = data.upgrades.swingDamage or 0
    local baseDamage = damageConfig.baseValue + (damageLevel * damageConfig.valuePerLevel)

    -- Soul multiplier upgrade
    local multConfig = DataConfig.UPGRADES.soulMultiplier
    local multLevel = data.upgrades.soulMultiplier or 0
    local upgradeMultiplier = multConfig.baseValue + (multLevel * multConfig.valuePerLevel)

    -- Rebirth multiplier (15% per rebirth)
    local rebirthMultiplier = 1 + (data.rebirthCount * 0.15)

    -- Ascension multiplier
    local ascensionMultiplier = 1 + ((data.ascensionCount or 0) * (DataConfig.ASCENSION.godTierMultiplier - 1))

    -- Spirit multipliers (equippedSpirits stores uid strings)
    local spiritMultiplier = 1.0
    for _, spiritUid in ipairs(data.equippedSpirits) do
        for _, spirit in ipairs(data.spirits) do
            if spirit.uid == spiritUid then
                spiritMultiplier = spiritMultiplier * spirit.multiplier
                break
            end
        end
    end

    -- Zone multiplier
    local zoneData = ZoneConfig.getZone(data.currentZone)
    local zoneMultiplier = zoneData and zoneData.multiplier or 1

    -- Gamepass check: 2x Soul Harvester pass
    local MarketplaceService = game:GetService("MarketplaceService")
    local SOUL_HARVESTER_PASS_ID = 000000000 -- Replace with actual GamePass ID
    local hasHarvesterPass = false
    pcall(function()
        hasHarvesterPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, SOUL_HARVESTER_PASS_ID)
    end)
    local gamepassMultiplier = hasHarvesterPass and 2.0 or 1.0

    -- Final calculation
    local finalReward = math.floor(
        baseDamage
        * upgradeMultiplier
        * rebirthMultiplier
        * ascensionMultiplier
        * spiritMultiplier
        * zoneMultiplier
        * gamepassMultiplier
    )

    return math.max(finalReward, 1) -- Always award at least 1 soul
end

return CurrencyService
