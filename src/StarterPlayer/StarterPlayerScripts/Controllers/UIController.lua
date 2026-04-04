-- ============================================================================
-- UIController.lua
-- Manages ALL UI state. Single source of truth for what the player sees.
-- Reacts to server events and updates UI elements accordingly.
-- ============================================================================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents      = require(ReplicatedStorage.Shared.Events.RemoteEvents)

local UIController = {}

-- Local state (mirrors server data, updated via RemoteEvents)
local _displayValues = {
    souls        = 0,
    gems         = 0,
    spiritShards = 0,
    reaperTokens = 0,
}

local _labels = {
    souls        = nil,
    gems         = nil,
    spiritShards = nil,
    reaperTokens = nil,
}

local _activeTweens = {}
local _upgrades = {}
local _spirits = {}
local _equippedSpirits = {}

-- Tween config
local TWEEN_DURATION  = 0.35
local PULSE_DURATION  = 0.12
local PULSE_SCALE     = 1.18

-- Currency key mapping (tolerates both camelCase and snake_case)
local CURRENCY_TO_KEY = {
    souls         = "souls",
    gems          = "gems",
    spiritShards  = "spiritShards",
    spirit_shards = "spiritShards",
    reaperTokens  = "reaperTokens",
    reaper_tokens = "reaperTokens",
}

-- Number formatting
local function _format(n)
    n = math.floor(n + 0.5)
    if     n >= 1e12 then return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9  then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6  then return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3  then return string.format("%.1fK", n / 1e3)
    else                  return tostring(n)
    end
end

-- Label discovery (recursive search)
local function _findLabel(gui, name)
    if not gui then return nil end
    local found = gui:FindFirstChild(name, true)
    if found and found:IsA("TextLabel") then
        return found
    end
    return nil
end

local function _resolveLabels(gui)
    _labels.souls        = _findLabel(gui, "SoulsLabel")
    _labels.gems         = _findLabel(gui, "GemsLabel")
    _labels.spiritShards = _findLabel(gui, "ShardsLabel")
    _labels.reaperTokens = _findLabel(gui, "TokensLabel")
end

-- Pulse animation
local function _pulseThenRestoreScale(label)
    if not label then return end

    local uiScale = label:FindFirstChildOfClass("UIScale")
    if not uiScale then
        uiScale = Instance.new("UIScale")
        uiScale.Parent = label
    end

    local pulseUpInfo   = TweenInfo.new(PULSE_DURATION, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
    local pulseDownInfo = TweenInfo.new(PULSE_DURATION, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)

    local tweenUp   = TweenService:Create(uiScale, pulseUpInfo,   { Scale = PULSE_SCALE })
    local tweenDown = TweenService:Create(uiScale, pulseDownInfo, { Scale = 1.0 })

    tweenUp:Play()
    tweenUp.Completed:Connect(function(state)
        if state == Enum.PlaybackState.Completed then
            tweenDown:Play()
        end
    end)
end

-- Smooth number tween
local function _tweenValue(key, targetValue)
    local label = _labels[key]
    _displayValues[key] = targetValue

    if not label then return end

    -- Cancel existing tween
    if _activeTweens[key] then
        _activeTweens[key]:Cancel()
        _activeTweens[key] = nil
    end

    local tweenInfo = TweenInfo.new(TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local counter = Instance.new("NumberValue")
    counter.Value = tonumber(label.Text:gsub("[%a,]", "")) or 0
    counter.Parent = label

    local tween = TweenService:Create(counter, tweenInfo, { Value = targetValue })

    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        if label and label.Parent then
            label.Text = _format(counter.Value)
        end
    end)

    tween.Completed:Connect(function()
        connection:Disconnect()
        counter:Destroy()
        _activeTweens[key] = nil
        if label and label.Parent then
            label.Text = _format(targetValue)
        end
    end)

    _activeTweens[key] = tween
    tween:Play()
    _pulseThenRestoreScale(label)
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function UIController.onCurrencyUpdate(data)
    if type(data) ~= "table" then return end

    local key    = CURRENCY_TO_KEY[data.currency]
    local amount = tonumber(data.newBalance)

    if not key or not amount then return end
    _tweenValue(key, amount)
end

function UIController.setAll(currencyTable)
    if type(currencyTable) ~= "table" then return end
    for serverKey, amount in pairs(currencyTable) do
        local key = CURRENCY_TO_KEY[serverKey]
        if key and tonumber(amount) then
            _displayValues[key] = tonumber(amount)
            local label = _labels[key]
            if label then
                label.Text = _format(tonumber(amount))
            end
        end
    end
end

function UIController.refreshCurrencyDisplay()
    for key, label in pairs(_labels) do
        if label then
            label.Text = _format(_displayValues[key] or 0)
        end
    end
end

function UIController.refreshSpiritPanel()
    -- Refresh spirit panel UI if visible
    -- Implementation depends on your UI structure
end

function UIController.showFloatingText(text, color)
    local screenGui = Players.LocalPlayer.PlayerGui:FindFirstChild("SoulMinersGui")
    if not screenGui then return end

    local label = Instance.new("TextLabel")
    label.Text = text
    label.TextColor3 = color
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 20
    label.Size = UDim2.new(0, 200, 0, 40)
    label.Position = UDim2.new(0.5, math.random(-50, 50), 0.5, math.random(-20, 20))
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Parent = screenGui

    TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = label.Position + UDim2.new(0, 0, -0.15, 0),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()

    game:GetService("Debris"):AddItem(label, 1.3)
end

function UIController.showNotification(message, color, duration)
    duration = duration or 3
    print("[Notification]", message)
end

function UIController.playEggOpenAnimation(results)
    for _, spirit in ipairs(results) do
        local rarityColors = {
            COMMON    = Color3.fromRGB(180,180,180),
            UNCOMMON  = Color3.fromRGB(80,200,80),
            RARE      = Color3.fromRGB(80,120,255),
            EPIC      = Color3.fromRGB(160,60,255),
            LEGENDARY = Color3.fromRGB(255,200,0),
            MYTHIC    = Color3.fromRGB(255,80,200),
        }
        UIController.showNotification(
            "You got " .. spirit.name .. "! [" .. spirit.rarity .. "] (" .. spirit.multiplier .. "x)",
            rarityColors[spirit.rarity] or Color3.new(1,1,1)
        )
    end
end

function UIController.playRebirthAnimation(data)
    UIController.showNotification(
        "REBORN! You earned " .. data.tokensEarned .. " Reaper Tokens! Total Rebirths: " .. data.rebirthCount,
        Color3.fromRGB(255, 150, 0),
        5
    )
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function UIController.initialize(initialData)
    local player = Players.LocalPlayer
    local gui = player.PlayerGui:WaitForChild("SoulMinersGui", 10)
    if not gui then
        warn("[UIController] SoulMinersGui not found in PlayerGui.")
    end

    _resolveLabels(gui)

    -- Snap to initial values with no animation
    if initialData and initialData.currencies then
        UIController.setAll(initialData.currencies)
    end

    _upgrades = initialData.upgrades or {}
    _spirits = initialData.spirits or {}
    _equippedSpirits = initialData.equippedSpirits or {}

    UIController.wireEvents()
    print("[UIController] Initialised.")
end

function UIController.wireEvents()
    -- Currency updated (generic DataUpdate)
    RemoteEvents.DataUpdate.OnClientEvent:Connect(function(data)
        if data.type == "upgrade" then
            UIController.showNotification(
                "Upgrade successful! " .. data.displayName .. " Level " .. data.newLevel,
                Color3.fromRGB(80, 255, 120)
            )
            _upgrades[data.upgradeId] = data.newLevel
        elseif data.type == "upgradeError" then
            UIController.showNotification(
                data.reason or "Upgrade failed",
                Color3.fromRGB(255, 80, 80)
            )
        elseif data.type == "currency" or data.currency then
            UIController.onCurrencyUpdate(data)
        end
    end)

    -- Legacy currency update
    RemoteEvents.UpdateCurrency.OnClientEvent:Connect(function(data)
        UIController.onCurrencyUpdate(data)
    end)

    -- Mine result
    RemoteEvents.MineResult.OnClientEvent:Connect(function(data)
        UIController.showFloatingText("+" .. _format(data.soulsGained), Color3.fromRGB(255, 255, 255))
        if data.gemDropped then
            UIController.showFloatingText("+1 GEM!", Color3.fromRGB(100, 200, 255))
        end
    end)

    -- Egg result
    RemoteEvents.EggResult.OnClientEvent:Connect(function(data)
        if data.success then
            UIController.playEggOpenAnimation(data.results)
        else
            UIController.showNotification(data.reason or "Cannot open egg", Color3.fromRGB(255, 80, 80))
        end
    end)

    -- Rebirth result
    RemoteEvents.RebirthResult.OnClientEvent:Connect(function(data)
        if data.success then
            if data.isAscension then
                UIController.showNotification(
                    "ASCENDED! God-tier multiplier x" .. data.godTierMultiplier .. " unlocked!",
                    Color3.fromRGB(255, 80, 200),
                    8
                )
            else
                UIController.playRebirthAnimation(data)
            end
        else
            UIController.showNotification(data.reason or "Cannot rebirth", Color3.fromRGB(255, 80, 80))
        end
    end)

    -- Spirit inventory sync
    RemoteEvents.UpdateSpirits.OnClientEvent:Connect(function(data)
        _spirits = data.spirits
        _equippedSpirits = data.equippedSpirits
        UIController.refreshSpiritPanel()
    end)

    -- Zone change result
    RemoteEvents.ZoneChangeResult.OnClientEvent:Connect(function(data)
        if data.success then
            UIController.showNotification(
                "Teleported to " .. data.zoneName .. "! (x" .. data.zoneMultiplier .. " multiplier)",
                Color3.fromRGB(100, 200, 255),
                5
            )
        else
            UIController.showNotification(data.reason or "Cannot travel", Color3.fromRGB(255, 80, 80))
        end
    end)

    -- Zone unlocked
    RemoteEvents.ZoneUnlocked.OnClientEvent:Connect(function(data)
        UIController.showNotification(
            "NEW ZONE UNLOCKED: " .. data.zoneName .. "! (x" .. data.zoneMultiplier .. " multiplier)",
            Color3.fromRGB(255, 200, 0),
            6
        )
    end)

    -- Server-wide announcement
    RemoteEvents.ServerAnnouncement.OnClientEvent:Connect(function(data)
        if data.type == "RARE_PULL" then
            local rarityColors = {
                LEGENDARY = Color3.fromRGB(255, 200, 0),
                MYTHIC    = Color3.fromRGB(255, 80, 200),
            }
            UIController.showNotification(
                data.playerName .. " pulled " .. data.spiritName .. "! [" .. data.rarity .. "]",
                rarityColors[data.rarity] or Color3.fromRGB(255, 255, 255),
                6
            )
        elseif data.type == "REBIRTH" then
            UIController.showNotification(
                data.playerName .. " has been REBORN! (Rebirth #" .. data.rebirthCount .. ")",
                Color3.fromRGB(255, 150, 0),
                4
            )
        elseif data.type == "ASCENSION" then
            UIController.showNotification(
                data.playerName .. " has ASCENDED! (Ascension #" .. data.ascensionCount .. ")",
                Color3.fromRGB(255, 80, 200),
                8
            )
        end
    end)

    -- Daily reward result
    RemoteEvents.DailyRewardResult.OnClientEvent:Connect(function(data)
        if data.success then
            UIController.showNotification(
                "Daily reward claimed! +" .. data.reward.amount .. " " .. data.reward.currency,
                Color3.fromRGB(255, 200, 0),
                4
            )
        else
            UIController.showNotification(data.reason or "Cannot claim", Color3.fromRGB(255, 80, 80))
        end
    end)
end

return UIController
