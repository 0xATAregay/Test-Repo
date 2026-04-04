-- ============================================================================
-- Server.server.lua
-- Master bootstrapper. Initializes all services and wires up event handlers.
-- This is the ONLY script that should call require() on multiple services.
-- Named .server.lua so Rojo creates a Script (not ModuleScript).
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load shared modules
local RemoteEvents = require(ReplicatedStorage.Shared.Events.RemoteEvents)

-- Load services (ORDER MATTERS: PlayerDataService must come first)
local PlayerDataService  = require(script.Parent.Parent.Services.PlayerDataService)
local CurrencyService    = require(script.Parent.Parent.Services.CurrencyService)
local ClickRewardService = require(script.Parent.Parent.Services.ClickRewardService)
local EggService         = require(script.Parent.Parent.Services.EggService)
local UpgradeService     = require(script.Parent.Parent.Services.UpgradeService)
local RebirthService     = require(script.Parent.Parent.Services.RebirthService)
local ZoneService        = require(script.Parent.Parent.Services.ZoneService)
local QuestService       = require(script.Parent.Parent.Services.QuestService)
local ShopService        = require(script.Parent.Parent.Services.ShopService)
local LeaderboardService = require(script.Parent.Parent.Services.LeaderboardService)

print("[Server] Soul Miners server initializing...")

-- ============================================================================
-- INITIALIZE SERVICES
-- Order matters: data first, then systems that depend on data.
-- ============================================================================

ClickRewardService.init()
EggService.init()
UpgradeService.init()
RebirthService.init()
ZoneService.init()
QuestService.init()
ShopService.init()
LeaderboardService.init()

-- ============================================================================
-- PLAYER LIFECYCLE
-- PlayerDataService handles its own PlayerAdded/Removing internally.
-- This section is for cross-service coordination after data loads.
-- ============================================================================

-- Track which players have received initial data (kept outside profile.Data
-- so this transient flag never gets persisted to DataStore).
local _initialDataSent = {} -- [player] = true

-- Post-data-load setup: fire initial data to client
task.spawn(function()
    while true do
        task.wait(1)
        for _, player in ipairs(Players:GetPlayers()) do
            if PlayerDataService.IsDataLoaded(player) and not _initialDataSent[player] then
                local data = PlayerDataService.GetData(player)
                if data then
                    _initialDataSent[player] = true

                    RemoteEvents.DataLoaded:FireClient(player, {
                        currencies = {
                            souls = data.souls,
                            gems = data.gems,
                            reaperTokens = data.reaperTokens,
                            spiritShards = data.spiritShards,
                        },
                        upgrades = data.upgrades,
                        currentZone = data.currentZone,
                        rebirthCount = data.rebirthCount,
                        ascensionCount = data.ascensionCount or 0,
                        spirits = data.spirits,
                        equippedSpirits = data.equippedSpirits,
                        pity = data.pity,
                        settings = data.settings,
                        dailyQuests = data.dailyQuests,
                        dailyRewardClaimed = data.dailyRewardClaimed,
                        loginStreak = data.loginStreak,
                    })
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    _initialDataSent[player] = nil
end)

print("[Server] Soul Miners initialization complete.")
