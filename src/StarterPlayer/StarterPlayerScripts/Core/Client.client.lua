-- ============================================================================
-- Client.client.lua
-- Client-side bootstrapper.
-- Initializes all controllers after data is received from server.
-- Handles re-syncs on rebirth/ascension via subsequent DataLoaded events.
-- ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.Events.RemoteEvents)

-- Controllers are loaded lazily after data arrives to prevent race conditions
local UIController
local InputController
local NotificationController
local RewardJuiceController

local Client = {}
local _initialized = false

-- Wait for server to confirm our data is loaded before initializing UI.
-- Subsequent DataLoaded events (e.g. after rebirth/ascension) trigger a
-- full UI resync without re-initializing controllers.
RemoteEvents.DataLoaded.OnClientEvent:Connect(function(initialData)
    if _initialized then
        -- Re-sync: rebirth or ascension reset all data, update UI state
        print("[Client] DataLoaded resync received (rebirth/ascension). Updating UI...")
        if UIController then
            UIController.initialize(initialData)
        end
        return
    end
    _initialized = true

    print("[Client] Data received from server. Initializing controllers...")

    -- Load controllers in dependency order
    UIController            = require(script.Parent.Parent.Controllers.UIController)
    InputController         = require(script.Parent.Parent.Controllers.InputController)
    NotificationController  = require(script.Parent.Parent.Controllers.NotificationController)
    RewardJuiceController   = require(script.Parent.Parent.Controllers.RewardJuiceController)

    -- Initialize with server data
    UIController.initialize(initialData)
    InputController.initialize()
    NotificationController.initialize()
    RewardJuiceController.initialize()

    print("[Client] Soul Miners client ready.")
end)
