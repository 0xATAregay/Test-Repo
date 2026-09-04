-- BindableEvents.lua
-- Server-side signals for inter-service communication.
-- These never cross the network boundary (server-only).

local BindableEvents = {}

local function createBindable(name)
    local bindable = Instance.new("BindableEvent")
    bindable.Name = name
    return bindable
end

-- Inter-service signals
BindableEvents.PlayerDataReady     = createBindable("PlayerDataReady")      -- Fires when a player's data finishes loading
BindableEvents.CurrencyChanged     = createBindable("CurrencyChanged")      -- Fires when any currency changes
BindableEvents.UpgradePurchased    = createBindable("UpgradePurchased")     -- Fires when an upgrade is bought
BindableEvents.EggHatched          = createBindable("EggHatched")           -- Fires when an egg is opened
BindableEvents.PlayerReborn        = createBindable("PlayerReborn")         -- Fires when a player rebirths
BindableEvents.ZoneChanged         = createBindable("ZoneChanged")          -- Fires when a player changes zones
BindableEvents.QuestProgress       = createBindable("QuestProgress")        -- Fires for quest progress tracking

return BindableEvents
