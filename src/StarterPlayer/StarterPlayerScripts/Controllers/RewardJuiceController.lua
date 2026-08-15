-- ============================================================================
-- RewardJuiceController.lua
-- The "reward juice" layer: floating numbers, screen shake, particle effects,
-- combo counters, and sound effects that make clicking feel AMAZING.
-- ============================================================================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.Events.RemoteEvents)

local RewardJuiceController = {}

-- Config
local FLOAT_DISTANCE = 100        -- pixels to float up
local FLOAT_DURATION = 1.2        -- seconds
local SHAKE_INTENSITY = 4         -- pixels
local SHAKE_DURATION = 0.08       -- seconds
local COMBO_RESET_TIME = 1.5      -- seconds between clicks to reset combo
local COMBO_SCALE_BONUS = 0.02    -- extra scale per combo hit

-- Sound IDs (replace with actual uploaded sound asset IDs)
local SOUNDS = {
    click     = "",  -- rbxassetid://XXXXXXXXX
    gem       = "",  -- rbxassetid://XXXXXXXXX
    levelUp   = "",  -- rbxassetid://XXXXXXXXX
    rebirth   = "",  -- rbxassetid://XXXXXXXXX
    mythicPull = "", -- rbxassetid://XXXXXXXXX
}

-- State
local _combo = 0
local _lastComboTime = 0
local _screenGui = nil
local _camera = nil

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

-- Floating text that rises and fades
local function _spawnFloatingText(text, color, startPos, scale)
    if not _screenGui then return end

    scale = scale or 1.0

    local label = Instance.new("TextLabel")
    label.Text = text
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.GothamBlack
    label.TextSize = math.floor(22 * scale)
    label.Size = UDim2.new(0, 200, 0, 50)
    label.AnchorPoint = Vector2.new(0.5, 0.5)

    -- Random horizontal spread for visual variety
    local xOffset = math.random(-60, 60)
    local yOffset = math.random(-15, 15)
    label.Position = startPos or UDim2.new(0.5, xOffset, 0.45, yOffset)

    label.Parent = _screenGui

    -- Initial pop-in scale
    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 0.3
    uiScale.Parent = label

    -- Pop in
    TweenService:Create(uiScale, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = scale,
    }):Play()

    -- Float up and fade out
    local floatTween = TweenService:Create(label,
        TweenInfo.new(FLOAT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Position = label.Position + UDim2.new(0, 0, 0, -FLOAT_DISTANCE),
            TextTransparency = 1,
            TextStrokeTransparency = 1,
        }
    )
    floatTween:Play()
    floatTween.Completed:Connect(function()
        label:Destroy()
    end)
end

-- Camera screen shake
local function _screenShake(intensity, duration)
    if not _camera then
        _camera = workspace.CurrentCamera
    end
    if not _camera then return end

    intensity = intensity or SHAKE_INTENSITY
    duration = duration or SHAKE_DURATION

    local originalCFrame = _camera.CFrame
    local shakeStart = tick()

    local connection
    connection = game:GetService("RunService").RenderStepped:Connect(function()
        local elapsed = tick() - shakeStart
        if elapsed >= duration then
            connection:Disconnect()
            return
        end

        local progress = elapsed / duration
        local dampening = 1 - progress -- shake gets weaker over time
        local offsetX = (math.random() - 0.5) * 2 * intensity * dampening
        local offsetY = (math.random() - 0.5) * 2 * intensity * dampening

        _camera.CFrame = _camera.CFrame * CFrame.new(offsetX, offsetY, 0)
    end)
end

-- Play a sound effect
local function _playSound(soundKey)
    local soundId = SOUNDS[soundKey]
    if not soundId or soundId == "" then return end

    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 0.5
    sound.PlayOnRemove = false
    sound.Parent = SoundService
    sound:Play()
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

-- Update combo counter
local function _updateCombo()
    local now = tick()
    if (now - _lastComboTime) > COMBO_RESET_TIME then
        _combo = 0
    end
    _combo = _combo + 1
    _lastComboTime = now
    return _combo
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

local function _onMineReward(data)
    if not data then return end

    local combo = _updateCombo()
    local comboScale = 1.0 + (math.min(combo, 50) * COMBO_SCALE_BONUS)

    -- Soul floating text
    local soulsText = "+" .. _format(data.delta or data.soulsGained or 0)
    if combo >= 5 then
        soulsText = soulsText .. " x" .. combo
    end

    _spawnFloatingText(soulsText, Color3.fromRGB(220, 230, 255), nil, comboScale)

    -- Click sound with pitch variation based on combo
    _playSound("click")

    -- Screen shake scales with combo
    if combo >= 3 then
        _screenShake(SHAKE_INTENSITY * math.min(comboScale, 2.5), SHAKE_DURATION)
    end

    -- Gem drop
    if data.gemDropped then
        task.delay(0.15, function()
            _spawnFloatingText("+1 GEM!", Color3.fromRGB(100, 220, 255), nil, 1.3)
            _playSound("gem")
            _screenShake(8, 0.12)
        end)
    end
end

local function _onEggResult(data)
    if not data or not data.success then return end

    for i, spirit in ipairs(data.results or {}) do
        task.delay((i - 1) * 0.4, function()
            local rarityColors = {
                COMMON    = Color3.fromRGB(180,180,180),
                UNCOMMON  = Color3.fromRGB(80,200,80),
                RARE      = Color3.fromRGB(80,120,255),
                EPIC      = Color3.fromRGB(160,60,255),
                LEGENDARY = Color3.fromRGB(255,200,0),
                MYTHIC    = Color3.fromRGB(255,80,200),
            }
            local rarityScales = {
                COMMON = 1.0, UNCOMMON = 1.1, RARE = 1.3,
                EPIC = 1.5, LEGENDARY = 1.8, MYTHIC = 2.2,
            }

            local color = rarityColors[spirit.rarity] or Color3.new(1,1,1)
            local scale = rarityScales[spirit.rarity] or 1.0
            local text = spirit.name .. "! (" .. spirit.multiplier .. "x)"

            _spawnFloatingText(text, color, nil, scale)
            _screenShake(scale * 5, 0.15)

            if spirit.rarity == "MYTHIC" then
                _playSound("mythicPull")
                _screenShake(15, 0.4) -- big shake for mythic
            elseif spirit.rarity == "LEGENDARY" then
                _screenShake(10, 0.25)
            end
        end)
    end
end

local function _onRebirthResult(data)
    if not data or not data.success then return end

    _playSound("rebirth")
    _screenShake(20, 0.5)

    _spawnFloatingText("REBORN!", Color3.fromRGB(255, 150, 0), nil, 2.5)

    task.delay(0.5, function()
        _spawnFloatingText(
            "+" .. data.tokensEarned .. " Reaper Tokens",
            Color3.fromRGB(255, 200, 100), nil, 1.5
        )
    end)

    if data.isAscension then
        _screenShake(30, 0.8)
        _spawnFloatingText("ASCENDED!", Color3.fromRGB(255, 80, 200), nil, 3.0)
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function RewardJuiceController.initialize()
    local player = Players.LocalPlayer
    _screenGui = player.PlayerGui:FindFirstChild("SoulMinersGui")

    if not _screenGui then
        _screenGui = Instance.new("ScreenGui")
        _screenGui.Name = "SoulMinersGui"
        _screenGui.ResetOnSpawn = false
        _screenGui.Parent = player.PlayerGui
    end

    _camera = workspace.CurrentCamera

    -- Wire events
    RemoteEvents.DataUpdate.OnClientEvent:Connect(function(data)
        if data.currency and data.delta and data.delta > 0 then
            _onMineReward(data)
        end
    end)

    RemoteEvents.EggResult.OnClientEvent:Connect(_onEggResult)
    RemoteEvents.RebirthResult.OnClientEvent:Connect(_onRebirthResult)

    print("[RewardJuiceController] Initialised. Juice is flowing!")
end

return RewardJuiceController
