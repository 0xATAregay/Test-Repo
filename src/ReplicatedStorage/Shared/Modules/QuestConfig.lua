-- QuestConfig.lua
-- Quest definitions for daily, weekly, and lifetime achievements.

local QuestConfig = {}

-- Daily quest pool (3 randomly selected per day)
QuestConfig.DAILY_QUESTS = {
    {
        id = "mine_souls_500",
        description = "Mine 500 Souls",
        type = "mine_souls",
        target = 500,
        rewards = { spiritShards = 10, gems = 2 },
    },
    {
        id = "mine_souls_2000",
        description = "Mine 2,000 Souls",
        type = "mine_souls",
        target = 2000,
        rewards = { spiritShards = 25, gems = 5 },
    },
    {
        id = "hatch_eggs_2",
        description = "Hatch 2 Eggs",
        type = "hatch_eggs",
        target = 2,
        rewards = { spiritShards = 20, gems = 3 },
    },
    {
        id = "hatch_eggs_5",
        description = "Hatch 5 Eggs",
        type = "hatch_eggs",
        target = 5,
        rewards = { spiritShards = 50, gems = 8 },
    },
    {
        id = "collect_gems_50",
        description = "Collect 50 Gems",
        type = "collect_gems",
        target = 50,
        rewards = { spiritShards = 30 },
    },
    {
        id = "click_100",
        description = "Click 100 Times",
        type = "clicks",
        target = 100,
        rewards = { spiritShards = 15, gems = 2 },
    },
    {
        id = "click_500",
        description = "Click 500 Times",
        type = "clicks",
        target = 500,
        rewards = { spiritShards = 40, gems = 10 },
    },
    {
        id = "upgrade_3",
        description = "Purchase 3 Upgrades",
        type = "upgrades",
        target = 3,
        rewards = { spiritShards = 20, gems = 5 },
    },
}

-- Lifetime achievements
QuestConfig.ACHIEVEMENTS = {
    {
        id = "rebirth_1",
        description = "Rebirth for the first time",
        type = "rebirths",
        target = 1,
        rewards = { reaperTokens = 5 },
    },
    {
        id = "rebirth_5",
        description = "Rebirth 5 times",
        type = "rebirths",
        target = 5,
        rewards = { reaperTokens = 25 },
    },
    {
        id = "rebirth_10",
        description = "Rebirth 10 times",
        type = "rebirths",
        target = 10,
        rewards = { reaperTokens = 100 },
    },
    {
        id = "spirits_10",
        description = "Collect 10 unique Spirits",
        type = "unique_spirits",
        target = 10,
        rewards = { gems = 50 },
    },
    {
        id = "spirits_50",
        description = "Collect 50 unique Spirits",
        type = "unique_spirits",
        target = 50,
        rewards = { gems = 200, reaperTokens = 10 },
    },
    {
        id = "spirits_100",
        description = "Collect 100 unique Spirits",
        type = "unique_spirits",
        target = 100,
        rewards = { gems = 500, reaperTokens = 50 },
    },
    {
        id = "souls_1m",
        description = "Mine 1,000,000 lifetime Souls",
        type = "total_souls",
        target = 1000000,
        rewards = { reaperTokens = 5, gems = 100 },
    },
    {
        id = "souls_1b",
        description = "Mine 1,000,000,000 lifetime Souls",
        type = "total_souls",
        target = 1000000000,
        rewards = { reaperTokens = 50, gems = 1000 },
    },
}

-- Number of daily quests given per day
QuestConfig.DAILY_QUEST_COUNT = 3

return QuestConfig
