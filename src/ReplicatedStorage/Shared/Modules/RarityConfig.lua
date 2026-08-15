-- RarityConfig.lua
-- All egg and spirit rarity definitions.
-- Weighted RNG uses cumulative probability for O(1) lookup.

local RarityConfig = {}

-- Rarity tier definitions
RarityConfig.TIERS = {
    COMMON    = { name = "Common",    color = Color3.fromRGB(180,180,180), weight = 6000 },
    UNCOMMON  = { name = "Uncommon",  color = Color3.fromRGB(80,200,80),   weight = 2500 },
    RARE      = { name = "Rare",      color = Color3.fromRGB(80,120,255),  weight = 1000 },
    EPIC      = { name = "Epic",      color = Color3.fromRGB(160,60,255),  weight = 400  },
    LEGENDARY = { name = "Legendary", color = Color3.fromRGB(255,200,0),   weight = 90   },
    MYTHIC    = { name = "Mythic",    color = Color3.fromRGB(255,80,200),  weight = 10   },
}

-- Egg definitions with rarity weight tables
RarityConfig.EGGS = {
    shadowEgg = {
        displayName = "Shadow Egg",
        cost = 100,
        costCurrency = "spiritShards",
        requiredZone = 1,
        pityEpicAt = 50,
        pityLegendaryAt = 100,
        rarityWeights = {
            COMMON    = 6000,
            UNCOMMON  = 2500,
            RARE      = 1200,
            EPIC      = 290,
            LEGENDARY = 10,
            MYTHIC    = 0,  -- not available in starter egg
        },
    },
    infernalEgg = {
        displayName = "Infernal Egg",
        cost = 500,
        costCurrency = "spiritShards",
        requiredZone = 3,
        pityEpicAt = 50,
        pityLegendaryAt = 100,
        rarityWeights = {
            COMMON    = 4500,
            UNCOMMON  = 3000,
            RARE      = 1700,
            EPIC      = 600,
            LEGENDARY = 180,
            MYTHIC    = 20,
        },
    },
    voidEgg = {
        displayName = "Void Egg",
        cost = 2000,
        costCurrency = "spiritShards",
        requiredZone = 5,
        pityEpicAt = 50,
        pityLegendaryAt = 100,
        rarityWeights = {
            COMMON    = 3000,
            UNCOMMON  = 2800,
            RARE      = 2500,
            EPIC      = 1200,
            LEGENDARY = 400,
            MYTHIC    = 100,
        },
    },
}

-- Spirit pool per rarity (extend this table as you add more spirits)
RarityConfig.SPIRITS = {
    COMMON = {
        { id = "wisp_grey",    name = "Grey Wisp",       multiplier = 1.1 },
        { id = "shade_small",  name = "Shade",           multiplier = 1.15 },
        { id = "ember_dim",    name = "Dim Ember",       multiplier = 1.2 },
        { id = "shadow_pup",   name = "Shadow Pup",      multiplier = 1.25 },
        { id = "mist_orb",     name = "Mist Orb",        multiplier = 1.3 },
    },
    UNCOMMON = {
        { id = "spirit_cat",   name = "Spirit Cat",      multiplier = 1.5 },
        { id = "soul_fox",     name = "Soul Fox",        multiplier = 1.6 },
        { id = "grave_owl",    name = "Grave Owl",       multiplier = 1.75 },
    },
    RARE = {
        { id = "phantom_wolf", name = "Phantom Wolf",    multiplier = 2.2 },
        { id = "reaper_imp",   name = "Reaper Imp",      multiplier = 2.5 },
        { id = "void_serpent",  name = "Void Serpent",    multiplier = 3.0 },
    },
    EPIC = {
        { id = "hell_dragon",  name = "Hell Dragon",     multiplier = 5.0 },
        { id = "death_angel",  name = "Death Angel",     multiplier = 6.0 },
    },
    LEGENDARY = {
        { id = "soul_titan",   name = "Soul Titan",      multiplier = 12.0 },
        { id = "void_king",    name = "Void King",       multiplier = 15.0 },
    },
    MYTHIC = {
        { id = "eternal_reaper", name = "Eternal Reaper", multiplier = 35.0 },
        { id = "cosmos_wraith",  name = "Cosmos Wraith",  multiplier = 50.0 },
    },
}

--[[
    RarityConfig.rollRarity(eggId, pityCount)
    
    Uses weighted random selection with pity override.
    Returns rarity string (e.g., "LEGENDARY") and new pity count.
    
    Algorithm: sum all weights, roll random 1-totalWeight,
    walk cumulative sum until roll falls in a bucket.
    O(n) but n=6 tiers so effectively O(1).
]]
function RarityConfig.rollRarity(eggId, currentPity)
    local eggConfig = RarityConfig.EGGS[eggId]
    assert(eggConfig, "Invalid egg ID: " .. tostring(eggId))

    local newPity = currentPity + 1

    -- Pity overrides
    if newPity >= eggConfig.pityLegendaryAt then
        newPity = 0
        return "LEGENDARY", newPity
    elseif newPity >= eggConfig.pityEpicAt and newPity < eggConfig.pityLegendaryAt then
        -- Guarantee at least Epic (but don't reset pity yet, still building to legendary)
        local epicOrBetter = { "EPIC", "LEGENDARY", "MYTHIC" }
        local weights = {}
        local total = 0
        for _, rarity in ipairs(epicOrBetter) do
            local w = eggConfig.rarityWeights[rarity] or 0
            table.insert(weights, { rarity = rarity, weight = w })
            total += w
        end
        if total == 0 then return "EPIC", newPity end
        local roll = math.random(1, total)
        local cumulative = 0
        for _, entry in ipairs(weights) do
            cumulative += entry.weight
            if roll <= cumulative then
                return entry.rarity, newPity
            end
        end
        return "EPIC", newPity
    end

    -- Normal weighted roll
    local total = 0
    local weightedTable = {}
    for rarity, weight in pairs(eggConfig.rarityWeights) do
        if weight > 0 then
            total += weight
            table.insert(weightedTable, { rarity = rarity, weight = weight })
        end
    end

    local roll = math.random(1, total)
    local cumulative = 0
    for _, entry in ipairs(weightedTable) do
        cumulative += entry.weight
        if roll <= cumulative then
            return entry.rarity, newPity
        end
    end

    return "COMMON", newPity -- fallback (should never reach)
end

-- Generate a unique instance key for each spirit obtained.
-- Uses a combination of timestamp and random to avoid collisions.
local _uidCounter = 0
function RarityConfig._generateUID()
    _uidCounter = _uidCounter + 1
    return string.format("%s_%d_%d", os.time(), math.random(10000, 99999), _uidCounter)
end

-- Pick a random spirit from the rolled rarity tier
function RarityConfig.rollSpirit(rarity)
    local pool = RarityConfig.SPIRITS[rarity]
    assert(pool and #pool > 0, "No spirits defined for rarity: " .. tostring(rarity))
    local picked = pool[math.random(1, #pool)]
    -- Return a copy with a unique instance key (uid) so duplicate spirits
    -- (e.g., two "phantom_wolf") can be independently equipped/unequipped.
    return {
        uid = RarityConfig._generateUID(),
        id = picked.id,
        name = picked.name,
        rarity = rarity,
        multiplier = picked.multiplier,
        obtainedAt = os.time(),
    }
end

return RarityConfig
