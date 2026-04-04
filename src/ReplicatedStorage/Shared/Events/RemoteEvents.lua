-- RemoteEvents.lua
-- Central registry for ALL RemoteEvents and RemoteFunctions.
-- Both client and server require this module to get references.
-- This prevents typo-based bugs and makes the event surface explicit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Lazy-create a folder to hold all remotes
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreate(className, name)
    local existing = remotesFolder:FindFirstChild(name)
    if existing then return existing end
    local remote = Instance.new(className)
    remote.Name = name
    remote.Parent = remotesFolder
    return remote
end

-- All events are defined here. Server creates them, client finds them.
local RemoteEvents = {
    -- Data / UI sync
    DataLoaded          = getOrCreate("RemoteEvent",    "DataLoaded"),          -- Server -> Client: initial data push
    DataUpdate          = getOrCreate("RemoteEvent",    "DataUpdate"),          -- Server -> Client: generic data update
    UpdateCurrency      = getOrCreate("RemoteEvent",    "UpdateCurrency"),      -- Server -> Client: currency changed
    UpdateUpgrades      = getOrCreate("RemoteEvent",    "UpdateUpgrades"),      -- Server -> Client: upgrade state sync
    UpdateSpirits       = getOrCreate("RemoteEvent",    "UpdateSpirits"),       -- Server -> Client: inventory sync

    -- Mining / Clicking
    SwingScythe         = getOrCreate("RemoteEvent",    "SwingScythe"),         -- Client -> Server: player swung
    ClickRequest        = getOrCreate("RemoteEvent",    "ClickRequest"),        -- Client -> Server: click to earn
    MineResult          = getOrCreate("RemoteEvent",    "MineResult"),          -- Server -> Client: result of swing

    -- Upgrades
    PurchaseUpgrade     = getOrCreate("RemoteEvent",    "PurchaseUpgrade"),     -- Client -> Server: buy upgrade
    UpgradeRequest      = getOrCreate("RemoteEvent",    "UpgradeRequest"),      -- Client -> Server: upgrade request
    UpgradeResult       = getOrCreate("RemoteEvent",    "UpgradeResult"),       -- Server -> Client: success/fail

    -- Gacha
    OpenEgg             = getOrCreate("RemoteEvent",    "OpenEgg"),             -- Client -> Server: open egg request
    EggResult           = getOrCreate("RemoteEvent",    "EggResult"),           -- Server -> Client: spirit rolled

    -- Spirit management
    EquipSpirit         = getOrCreate("RemoteEvent",    "EquipSpirit"),         -- Client -> Server: equip spirit
    UnequipSpirit       = getOrCreate("RemoteEvent",    "UnequipSpirit"),       -- Client -> Server: unequip spirit
    EquipResult         = getOrCreate("RemoteEvent",    "EquipResult"),         -- Server -> Client: equip result

    -- Rebirth
    AttemptRebirth      = getOrCreate("RemoteEvent",    "AttemptRebirth"),      -- Client -> Server
    RebirthResult       = getOrCreate("RemoteEvent",    "RebirthResult"),       -- Server -> Client

    -- Zones
    RequestZoneChange   = getOrCreate("RemoteEvent",    "RequestZoneChange"),   -- Client -> Server: teleport request
    ZoneChangeResult    = getOrCreate("RemoteEvent",    "ZoneChangeResult"),    -- Server -> Client: teleport result
    ZoneUnlocked        = getOrCreate("RemoteEvent",    "ZoneUnlocked"),        -- Server -> Client: new zone available

    -- Quests
    QuestUpdate         = getOrCreate("RemoteEvent",    "QuestUpdate"),         -- Server -> Client: quest progress
    ClaimQuestReward    = getOrCreate("RemoteEvent",    "ClaimQuestReward"),    -- Client -> Server: claim completed quest

    -- Shop (GamePasses validated server-side, dev products fire MarketplaceService)
    RequestShopData     = getOrCreate("RemoteFunction", "RequestShopData"),     -- Client -> Server: get pass ownership
    ProcessDevProduct   = getOrCreate("RemoteEvent",    "ProcessDevProduct"),   -- Server -> Client: confirm product granted
    PurchaseGamepass    = getOrCreate("RemoteEvent",    "PurchaseGamepass"),     -- Client -> Server: gamepass purchase
    PurchaseDevProduct  = getOrCreate("RemoteEvent",    "PurchaseDevProduct"),  -- Client -> Server: dev product purchase

    -- Leaderboard
    RequestLeaderboard  = getOrCreate("RemoteFunction", "RequestLeaderboard"),  -- Client -> Server: get top N

    -- Notifications (server-wide events)
    ServerAnnouncement  = getOrCreate("RemoteEvent",    "ServerAnnouncement"),  -- Server -> All clients

    -- Daily reward
    ClaimDailyReward    = getOrCreate("RemoteEvent",    "ClaimDailyReward"),    -- Client -> Server
    DailyRewardResult   = getOrCreate("RemoteEvent",    "DailyRewardResult"),   -- Server -> Client
}

return RemoteEvents
