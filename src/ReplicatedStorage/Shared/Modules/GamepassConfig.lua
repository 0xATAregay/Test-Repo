-- ============================================================================
-- GamepassConfig.lua
-- Centralized GamePass and Developer Product ID configuration.
-- Replace placeholder IDs with actual Roblox Creator Dashboard IDs.
-- ============================================================================

local GamepassConfig = {}

-- ============================================================================
-- GAME PASSES (one-time purchases)
-- Replace 0 with your actual GamePass IDs from Roblox Creator Dashboard.
-- ============================================================================
GamepassConfig.PASSES = {
    SOUL_HARVESTER = {
        id = 000000001,  -- TODO: Replace with real GamePass ID
        name = "Soul Harvester",
        description = "Permanently doubles all soul income",
        multiplier = 2.0,
        robuxPrice = 199,
    },
    LUCKY_REAPER = {
        id = 000000002,  -- TODO: Replace with real GamePass ID
        name = "Lucky Reaper",
        description = "2x better rarity rolls on all eggs",
        luckMultiplier = 2.0,
        robuxPrice = 299,
    },
    INFINITE_INVENTORY = {
        id = 000000003,  -- TODO: Replace with real GamePass ID
        name = "Infinite Inventory",
        description = "Unlimited Spirit storage (default: 50)",
        maxSpirits = math.huge,
        robuxPrice = 149,
    },
    AUTO_HARVESTER = {
        id = 000000004,  -- TODO: Replace with real GamePass ID
        name = "Auto Harvester",
        description = "Auto-swings your scythe while idle",
        autoSwingInterval = 0.5, -- seconds between auto-swings
        robuxPrice = 249,
    },
    VIP = {
        id = 000000005,  -- TODO: Replace with real GamePass ID
        name = "VIP Pass",
        description = "All passes + exclusive VIP cosmetic + priority queue",
        includesAll = true,
        robuxPrice = 499,
    },
}

-- ============================================================================
-- DEVELOPER PRODUCTS (repeatable purchases)
-- Replace 0 with your actual Developer Product IDs.
-- ============================================================================
GamepassConfig.DEV_PRODUCTS = {
    GEMS_1000 = {
        id = 000000010,  -- TODO: Replace with real ID
        name = "1,000 Gems",
        currency = "gems",
        amount = 1000,
    },
    GEMS_5000 = {
        id = 000000011,
        name = "5,000 Gems",
        currency = "gems",
        amount = 5000,
    },
    GEMS_15000 = {
        id = 000000012,
        name = "15,000 Gems",
        currency = "gems",
        amount = 15000,
    },
    SPIRIT_SHARDS_50 = {
        id = 000000013,
        name = "Spirit Shard x50",
        currency = "spiritShards",
        amount = 50,
    },
    SOUL_BOOST_2X = {
        id = 000000014,
        name = "2x Soul Boost (1hr)",
        type = "boost",
        boostType = "soul_2x",
        duration = 3600,
    },
    SOUL_BOOST_5X = {
        id = 000000015,
        name = "5x Soul Boost (1hr)",
        type = "boost",
        boostType = "soul_5x",
        duration = 3600,
    },
}

-- Helper: get pass config by effect name
function GamepassConfig.getPassByEffect(effectName)
    for _, pass in pairs(GamepassConfig.PASSES) do
        if pass.name:lower():gsub(" ", "_") == effectName then
            return pass
        end
    end
    return nil
end

-- Helper: get dev product config by ID
function GamepassConfig.getDevProductById(productId)
    for _, product in pairs(GamepassConfig.DEV_PRODUCTS) do
        if product.id == productId then
            return product
        end
    end
    return nil
end

return GamepassConfig
