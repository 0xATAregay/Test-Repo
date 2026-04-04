-- DataConfig.lua
-- Single source of truth for all game balance values.
-- Change numbers here, not scattered across scripts.

local DataConfig = {}

DataConfig.SCHEMA_VERSION = 1

-- Default player profile (used for new players AND schema reconciliation)
DataConfig.DEFAULT_PROFILE = {
    schemaVersion = 1,

    -- Currencies
    souls = 0,
    gems = 0,
    reaperTokens = 0,
    spiritShards = 0,

    -- Progression
    currentZone = 1,
    rebirthCount = 0,
    ascensionCount = 0,
    totalSoulsMined = 0, -- lifetime stat (never reset on rebirth)
    totalClicks = 0,
    totalEggsOpened = 0,

    -- Upgrades (indexes into upgrade config)
    upgrades = {
        swingDamage = 0,    -- upgrade level
        swingSpeed = 0,
        soulMultiplier = 0,
        gemFindChance = 0,
    },

    -- Inventory
    spirits = {},           -- array of { id, rarity, name, multiplier }
    equippedSpirits = {},   -- max 3 equipped at once

    -- Gacha pity tracking (per egg type)
    pity = {
        shadowEgg = 0,
        infernalEgg = 0,
        voidEgg = 0,
    },

    -- Quest tracking
    dailyQuests = {},       -- populated by QuestService on login
    questResetTime = 0,     -- Unix timestamp of next daily reset

    -- Retention
    loginStreak = 0,
    lastLoginDate = "",     -- "YYYY-MM-DD" format
    dailyRewardIndex = 0,   -- which day in the 7-day cycle they're on
    dailyRewardClaimed = false,

    -- Settings
    settings = {
        sfxEnabled = true,
        musicEnabled = true,
        notificationsEnabled = true,
    },

    -- Meta
    _version = 1,
    _createdAt = 0,
    _lastSeen = 0,
}

-- Upgrade costs and values
DataConfig.UPGRADES = {
    swingDamage = {
        baseCost = 100,
        costMultiplier = 1.35,
        baseValue = 10,
        valuePerLevel = 8,
        maxLevel = 100,
    },
    swingSpeed = {
        baseCost = 200,
        costMultiplier = 1.4,
        baseValue = 1.0,        -- swings per second
        valuePerLevel = 0.05,
        maxLevel = 50,
    },
    soulMultiplier = {
        baseCost = 500,
        costMultiplier = 1.5,
        baseValue = 1.0,
        valuePerLevel = 0.1,
        maxLevel = 200,
    },
    gemFindChance = {
        baseCost = 1000,
        costMultiplier = 1.6,
        baseValue = 0.01,       -- 1% base chance
        valuePerLevel = 0.005,
        maxLevel = 100,
    },
}

-- Rebirth thresholds and rewards
DataConfig.REBIRTHS = {
    [1]  = { soulsRequired = 1e6,   tokenReward = 1,  multiplierBonus = 0.15 },
    [2]  = { soulsRequired = 5e6,   tokenReward = 2,  multiplierBonus = 0.15 },
    [3]  = { soulsRequired = 25e6,  tokenReward = 4,  multiplierBonus = 0.15 },
    [4]  = { soulsRequired = 100e6, tokenReward = 8,  multiplierBonus = 0.15 },
    [5]  = { soulsRequired = 500e6, tokenReward = 15, multiplierBonus = 0.15 },
    [6]  = { soulsRequired = 2e9,   tokenReward = 25, multiplierBonus = 0.15 },
    [7]  = { soulsRequired = 10e9,  tokenReward = 40, multiplierBonus = 0.15 },
    [8]  = { soulsRequired = 50e9,  tokenReward = 60, multiplierBonus = 0.15 },
    [9]  = { soulsRequired = 250e9, tokenReward = 85, multiplierBonus = 0.15 },
    [10] = { soulsRequired = 1e12,  tokenReward = 120, multiplierBonus = 0.20 },
}

-- Ascension config (unlocks after 10 rebirths)
DataConfig.ASCENSION = {
    rebirthsRequired = 10,
    godTierMultiplier = 5.0,  -- permanent multiplier per ascension
    maxAscensions = 5,
}

-- Daily reward calendar (7-day cycle)
DataConfig.DAILY_REWARDS = {
    [1] = { currency = "souls",        amount = 500   },
    [2] = { currency = "gems",         amount = 10    },
    [3] = { currency = "spiritShards", amount = 25    },
    [4] = { currency = "souls",        amount = 2000  },
    [5] = { currency = "gems",         amount = 25    },
    [6] = { currency = "spiritShards", amount = 75    },
    [7] = { currency = "spiritShards", amount = 200, bonus = "guaranteedRareShardPack" },
}

return DataConfig
