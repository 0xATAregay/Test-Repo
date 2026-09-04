-- ============================================================================
-- QuestService.lua
-- Handles daily quest generation, tracking, and reward distribution.
-- Quests reset daily at midnight UTC.
-- ============================================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents      = require(ReplicatedStorage.Shared.Events.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService   = require(script.Parent.CurrencyService)
local QuestConfig       = require(game.ReplicatedStorage.Shared.Modules.QuestConfig)
local Util              = require(game.ReplicatedStorage.Shared.Modules.Util)

local QuestService = {}

--[[
    QuestService.generateDailyQuests(player)
    Randomly selects DAILY_QUEST_COUNT quests from the pool.
    Only generates if quests haven't been set today.
]]
function QuestService.generateDailyQuests(player)
    local data = PlayerDataService.GetData(player)
    if not data then return end

    local now = os.time()

    -- Check if quests need resetting
    if data.questResetTime > now and #data.dailyQuests > 0 then
        return -- quests are still valid
    end

    -- Calculate next midnight UTC
    local nextMidnight = math.floor(now / 86400 + 1) * 86400

    -- Shuffle and pick quests
    local pool = Util.deepCopy(QuestConfig.DAILY_QUESTS)
    Util.shuffle(pool)

    local selectedQuests = {}
    for i = 1, math.min(QuestConfig.DAILY_QUEST_COUNT, #pool) do
        local quest = pool[i]
        table.insert(selectedQuests, {
            id = quest.id,
            description = quest.description,
            type = quest.type,
            target = quest.target,
            progress = 0,
            completed = false,
            claimed = false,
            rewards = quest.rewards,
        })
    end

    PlayerDataService.UpdateData(player, function(d)
        d.dailyQuests = selectedQuests
        d.questResetTime = nextMidnight
    end)

    -- Sync to client
    RemoteEvents.QuestUpdate:FireClient(player, {
        quests = selectedQuests,
        resetTime = nextMidnight,
    })

    print(string.format("[QuestService] Generated %d daily quests for %s", #selectedQuests, player.Name))
end

--[[
    QuestService.trackProgress(player, questType, amount)
    Called by other services when relevant events occur.
    questType: "mine_souls", "hatch_eggs", "collect_gems", "clicks", "upgrades"
]]
function QuestService.trackProgress(player, questType, amount)
    local data = PlayerDataService.GetData(player)
    if not data or not data.dailyQuests then return end

    amount = amount or 1
    local anyUpdated = false

    PlayerDataService.UpdateData(player, function(d)
        for _, quest in ipairs(d.dailyQuests) do
            if quest.type == questType and not quest.completed then
                quest.progress = math.min(quest.progress + amount, quest.target)
                if quest.progress >= quest.target then
                    quest.completed = true
                end
                anyUpdated = true
            end
        end
    end)

    if anyUpdated then
        local updatedData = PlayerDataService.GetData(player)
        if updatedData then
            RemoteEvents.QuestUpdate:FireClient(player, {
                quests = updatedData.dailyQuests,
                resetTime = updatedData.questResetTime,
            })
        end
    end
end

--[[
    QuestService.claimReward(player, questId)
    Awards rewards for a completed quest.
]]
function QuestService.claimReward(player, questId)
    local data = PlayerDataService.GetData(player)
    if not data or not data.dailyQuests then return end

    local targetQuest = nil
    for _, quest in ipairs(data.dailyQuests) do
        if quest.id == questId then
            targetQuest = quest
            break
        end
    end

    if not targetQuest then return end

    if not targetQuest.completed then
        return -- quest not finished yet
    end

    if targetQuest.claimed then
        return -- already claimed
    end

    -- Mark as claimed
    PlayerDataService.UpdateData(player, function(d)
        for _, quest in ipairs(d.dailyQuests) do
            if quest.id == questId then
                quest.claimed = true
                break
            end
        end
    end)

    -- Award rewards
    if targetQuest.rewards then
        for currency, amount in pairs(targetQuest.rewards) do
            CurrencyService.addCurrency(player, currency, amount)
        end
    end

    -- Sync quests
    local updatedData = PlayerDataService.GetData(player)
    if updatedData then
        RemoteEvents.QuestUpdate:FireClient(player, {
            quests = updatedData.dailyQuests,
            resetTime = updatedData.questResetTime,
        })
    end
end

--[[
    QuestService.handleDailyLogin(player)
    Processes login streaks and daily reward claims.
]]
function QuestService.handleDailyLogin(player)
    local data = PlayerDataService.GetData(player)
    if not data then return end

    local today = Util.getDateString()

    if Util.isSameDay(data.lastLoginDate, today) then
        return -- already logged in today
    end

    PlayerDataService.UpdateData(player, function(d)
        if Util.isConsecutiveDay(d.lastLoginDate, today) then
            d.loginStreak = d.loginStreak + 1
        else
            d.loginStreak = 1 -- streak broken, restart
        end

        d.lastLoginDate = today
        d.dailyRewardClaimed = false

        -- Advance daily reward index (wraps around 7-day cycle)
        d.dailyRewardIndex = ((d.dailyRewardIndex) % 7) + 1
    end)
end

function QuestService.init()
    -- Generate quests on player join (poll for data instead of fixed delay)
    Players.PlayerAdded:Connect(function(player)
        task.spawn(function()
            local maxWait = 30
            local waited = 0
            while waited < maxWait and not PlayerDataService.IsDataLoaded(player) do
                task.wait(1)
                waited = waited + 1
            end
            if PlayerDataService.IsDataLoaded(player) then
                QuestService.handleDailyLogin(player)
                QuestService.generateDailyQuests(player)
            else
                warn("[QuestService] Data never loaded for " .. player.Name .. ", skipping daily setup.")
            end
        end)
    end)

    -- Handle quest reward claims
    RemoteEvents.ClaimQuestReward.OnServerEvent:Connect(function(player, questId)
        QuestService.claimReward(player, questId)
    end)

    -- Handle daily reward claims (separate 7-day cycle system)
    RemoteEvents.ClaimDailyReward.OnServerEvent:Connect(function(player)
        local data = PlayerDataService.GetData(player)
        if not data then return end

        if data.dailyRewardClaimed then
            RemoteEvents.DailyRewardResult:FireClient(player, {
                success = false,
                reason = "Already claimed today!",
            })
            return
        end

        local DataConfig = require(game.ReplicatedStorage.Shared.Modules.DataConfig)
        local rewardData = DataConfig.DAILY_REWARDS[data.dailyRewardIndex]
        if not rewardData then return end

        PlayerDataService.UpdateData(player, function(d)
            d.dailyRewardClaimed = true
        end)

        CurrencyService.addCurrency(player, rewardData.currency, rewardData.amount)

        RemoteEvents.DailyRewardResult:FireClient(player, {
            success = true,
            reward = rewardData,
            loginStreak = data.loginStreak,
            nextRewardIndex = (data.dailyRewardIndex % 7) + 1,
        })
    end)

    print("[QuestService] Initialised.")
end

return QuestService
