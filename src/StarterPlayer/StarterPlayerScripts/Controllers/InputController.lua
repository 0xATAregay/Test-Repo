-- ============================================================================
-- InputController.lua
-- Handles all player input: click-to-mine, keyboard shortcuts, mobile tap.
-- Client-side cooldown prevents unnecessary RemoteEvent spam.
-- ============================================================================

local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.Events.RemoteEvents)

local InputController = {}

-- Client-side cooldown (mirrored from ClickRewardService for responsiveness)
local CLICK_COOLDOWN = 0.18   -- slightly shorter than server to feel snappy
local _lastClick = 0
local _enabled = true

-- Animation state
local _swinging = false

local function _canClick()
    if not _enabled then return false end
    local now = tick()
    if (now - _lastClick) < CLICK_COOLDOWN then return false end
    _lastClick = now
    return true
end

local function _playSwingAnimation()
    if _swinging then return end
    _swinging = true

    local player = Players.LocalPlayer
    local character = player.Character
    if not character then _swinging = false return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then _swinging = false return end

    -- Play a swing animation if a scythe tool is equipped
    local tool = character:FindFirstChildOfClass("Tool")
    if tool then
        local animation = tool:FindFirstChild("SwingAnimation")
        if animation and animation:IsA("Animation") then
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                local track = animator:LoadAnimation(animation)
                track:Play()
                track.Stopped:Wait()
            end
        end
    end

    _swinging = false
end

local function _handleClick()
    if not _canClick() then return end

    -- Fire to server
    RemoteEvents.ClickRequest:FireServer()

    -- Play swing animation in parallel (doesn't block clicking)
    task.spawn(_playSwingAnimation)
end

-- Detect what the player clicked on (for future crystal mining)
local function _handleMouseClick(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        _handleClick()
    end
end

-- Keyboard shortcuts
local function _handleKeyPress(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.Space then
        _handleClick()
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function InputController.enable()
    _enabled = true
end

function InputController.disable()
    _enabled = false
end

function InputController.isEnabled()
    return _enabled
end

function InputController.initialize()
    UserInputService.InputBegan:Connect(_handleMouseClick)
    UserInputService.InputBegan:Connect(_handleKeyPress)

    print("[InputController] Initialised. Click, tap, or press Space to mine.")
end

return InputController
