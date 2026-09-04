-- ============================================================================
-- ShopService.lua
-- Handles GamePass and Developer Product purchases.
-- All validation is server-side. Client never determines what was purchased.
-- ============================================================================

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local RemoteEvents       = require(ReplicatedStorage.Shared.Events.RemoteEvents)
local PlayerDataService  = require(script.Parent.PlayerDataService)
local CurrencyService    = require(script.Parent.CurrencyService)

local ShopService = {}

-- ============================================================================
-- GAME PASSES
-- Replace 0 with actual GamePass IDs from Roblox Creator Dashboard
-- ============================================================================
local GAME_PASSES = {
    {
        id = 000000001, -- Replace with actual ID
        name = "Soul Harvester",
        description = "+2x all soul gain",
        price = 199,
        effect = "soul_2x",
    },
    {
        id = 000000002, -- Replace with actual ID
        name = "Lucky Reaper",
        description = "+2x egg luck (better rarity rolls)",
        price = 299,
        effect = "egg_luck_2x",
    },
    {
        id = 000000003, -- Replace with actual ID
        name = "Infinite Inventory",
        description = "Unlimited Spirit storage",
        price = 149,
        effect = "infinite_inventory",
    },
    {
        id = 000000004, -- Replace with actual ID
        name = "Auto Harvester",
        description = "Auto-swings scythe",
        price = 249,
        effect = "auto_swing",
    },
    {
        id = 000000005, -- Replace with actual ID
        name = "VIP Pass",
        description = "All of the above + exclusive cosmetic",
        price = 499,
        effect = "vip",
    },
}

-- ============================================================================
-- DEVELOPER PRODUCTS (repeat purchases)
-- Replace 0 with actual Developer Product IDs
-- ============================================================================
local DEV_PRODUCTS = {
    [000000010] = { -- Replace with actual ID
        name = "1,000 Gems",
        currency = "gems",
        amount = 1000,
    },
    [000000011] = {
        name = "5,000 Gems",
        currency = "gems",
        amount = 5000,
    },
    [000000012] = {
        name = "15,000 Gems",
        currency = "gems",
        amount = 15000,
    },
    [000000013] = {
        name = "Spirit Shard x50",
        currency = "spiritShards",
        amount = 50,
    },
    [000000014] = {
        name = "2x Soul Boost (1hr)",
        type = "boost",
        boostType = "soul_2x",
        duration = 3600,
    },
    [000000015] = {
        name = "5x Soul Boost (1hr)",
        type = "boost",
        boostType = "soul_5x",
        duration = 3600,
    },
}

-- Active boosts are persisted in player profile (activeBoosts field).
-- In-memory cache mirrors profile for fast reads; written back on change.
local _activeBoosts = {} -- [userId] = { [boostType] = expiryTime }

--[[
    ShopService.hasGamePass(player, passId) -> boolean
    Checks if a player owns a specific GamePass.
    Cached after first check per session.
]]
local _gamePassCache = {} -- [userId] = { [passId] = bool }

function ShopService.hasGamePass(player, passId)
    local userId = player.UserId
    if not _gamePassCache[userId] then
        _gamePassCache[userId] = {}
    end

    if _gamePassCache[userId][passId] ~= nil then
        return _gamePassCache[userId][passId]
    end

    local owns = false
    pcall(function()
        owns = MarketplaceService:UserOwnsGamePassAsync(userId, passId)
    end)

    _gamePassCache[userId][passId] = owns
    return owns
end

--[[
    ShopService.hasEffect(player, effectName) -> boolean
    Checks if a player has a specific effect (from gamepass or VIP).
]]
function ShopService.hasEffect(player, effectName)
    for _, pass in ipairs(GAME_PASSES) do
        if pass.effect == effectName or pass.effect == "vip" then
            if ShopService.hasGamePass(player, pass.id) then
                return true
            end
        end
    end
    return false
end

--[[
    ShopService.hasActiveBoost(player, boostType) -> boolean
    Checks if a player has an active temporary boost.
]]
function ShopService.hasActiveBoost(player, boostType)
    local userId = player.UserId
    local boosts = _activeBoosts[userId]
    if not boosts then
        -- Try loading from profile if not cached yet
        local data = PlayerDataService.GetData(player)
        if data and data.activeBoosts then
            _activeBoosts[userId] = data.activeBoosts
            boosts = _activeBoosts[userId]
        end
        if not boosts then return false end
    end

    local expiry = boosts[boostType]
    if not expiry then return false end

    if os.time() > expiry then
        boosts[boostType] = nil
        -- Persist expiry cleanup to profile
        PlayerDataService.UpdateData(player, function(d)
            if d.activeBoosts then
                d.activeBoosts[boostType] = nil
            end
        end)
        return false
    end

    return true
end

--[[
    ShopService.getBoostMultiplier(player) -> number
    Returns the total boost multiplier from active boosts.
]]
function ShopService.getBoostMultiplier(player)
    local mult = 1.0

    if ShopService.hasActiveBoost(player, "soul_2x") then
        mult = mult * 2.0
    end
    if ShopService.hasActiveBoost(player, "soul_5x") then
        mult = mult * 5.0
    end

    return mult
end

-- Handle Developer Product purchases
local function processReceipt(receiptInfo)
    local userId = receiptInfo.PlayerId
    local productId = receiptInfo.ProductId

    local player = Players:GetPlayerByUserId(userId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local productConfig = DEV_PRODUCTS[productId]
    if not productConfig then
        warn("[ShopService] Unknown product ID:", productId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Currency products
    if productConfig.currency then
        local success = CurrencyService.addCurrency(player, productConfig.currency, productConfig.amount)
        if success then
            RemoteEvents.ProcessDevProduct:FireClient(player, {
                success = true,
                productName = productConfig.name,
                currency = productConfig.currency,
                amount = productConfig.amount,
            })
            print(string.format(
                "[ShopService] %s purchased %s (+%d %s)",
                player.Name, productConfig.name, productConfig.amount, productConfig.currency
            ))
            return Enum.ProductPurchaseDecision.PurchaseGranted
        else
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
    end

    -- Boost products
    if productConfig.type == "boost" then
        if not _activeBoosts[userId] then
            _activeBoosts[userId] = {}
        end

        local currentExpiry = _activeBoosts[userId][productConfig.boostType] or os.time()
        local newExpiry = math.max(currentExpiry, os.time()) + productConfig.duration
        _activeBoosts[userId][productConfig.boostType] = newExpiry

        -- Persist boost to player profile so it survives disconnect/restart
        local saved = PlayerDataService.UpdateData(player, function(d)
            if not d.activeBoosts then d.activeBoosts = {} end
            d.activeBoosts[productConfig.boostType] = newExpiry
        end)

        if not saved then
            -- Data save failed — don't grant yet so receipt is retried
            _activeBoosts[userId][productConfig.boostType] = nil
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        RemoteEvents.ProcessDevProduct:FireClient(player, {
            success = true,
            productName = productConfig.name,
            boostType = productConfig.boostType,
            duration = productConfig.duration,
        })
        print(string.format(
            "[ShopService] %s activated boost: %s for %ds",
            player.Name, productConfig.boostType, productConfig.duration
        ))
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Handle shop data requests
local function handleShopDataRequest(player)
    local passOwnership = {}
    for _, pass in ipairs(GAME_PASSES) do
        passOwnership[pass.name] = ShopService.hasGamePass(player, pass.id)
    end

    local boosts = {}
    local userId = player.UserId
    if _activeBoosts[userId] then
        for boostType, expiry in pairs(_activeBoosts[userId]) do
            if os.time() < expiry then
                boosts[boostType] = expiry - os.time() -- time remaining
            end
        end
    end

    return {
        gamePasses = GAME_PASSES,
        ownership = passOwnership,
        activeBoosts = boosts,
    }
end

function ShopService.init()
    -- Wire MarketplaceService receipt processor
    MarketplaceService.ProcessReceipt = processReceipt

    -- Wire shop data request
    RemoteEvents.RequestShopData.OnServerInvoke = handleShopDataRequest

    -- Invalidate GamePass cache when a player purchases a pass in-session
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
        if wasPurchased then
            local userId = player.UserId
            if _gamePassCache[userId] then
                _gamePassCache[userId][passId] = true
            end
        end
    end)

    -- Clean up caches on player leave (boost data is persisted in profile)
    Players.PlayerRemoving:Connect(function(player)
        local userId = player.UserId
        _gamePassCache[userId] = nil
        _activeBoosts[userId] = nil  -- clear cache only; data is in profile
    end)

    print("[ShopService] Initialised.")
end

return ShopService
