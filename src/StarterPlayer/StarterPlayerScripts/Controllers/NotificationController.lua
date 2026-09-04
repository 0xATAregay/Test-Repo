-- ============================================================================
-- NotificationController.lua
-- Manages toast notifications, server-wide announcements, and quest alerts.
-- Provides a queue system to prevent notification spam.
-- ============================================================================

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")

local NotificationController = {}

-- Config
local MAX_VISIBLE = 3          -- max notifications visible at once
local DEFAULT_DURATION = 4     -- seconds
local SLIDE_IN_TIME = 0.3
local SLIDE_OUT_TIME = 0.25
local NOTIFICATION_HEIGHT = 50
local NOTIFICATION_PADDING = 8

-- State
local _queue = {}
local _visible = {}
local _container = nil
local _nextId = 0

-- Create notification UI element
local function _createNotificationFrame(message, color, duration)
    _nextId = _nextId + 1
    local id = _nextId

    local frame = Instance.new("Frame")
    frame.Name = "Notification_" .. id
    frame.Size = UDim2.new(0.3, 0, 0, NOTIFICATION_HEIGHT)
    frame.Position = UDim2.new(1.05, 0, 0, 0) -- off-screen right
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0

    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    -- Color accent bar on the left
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 4, 1, 0)
    accent.Position = UDim2.new(0, 0, 0, 0)
    accent.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
    accent.BorderSizePixel = 0
    accent.Parent = frame

    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(0, 4)
    accentCorner.Parent = accent

    -- Text
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = message
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = frame

    return frame, id, duration or DEFAULT_DURATION
end

-- Reposition visible notifications
local function _repositionVisible()
    for i, entry in ipairs(_visible) do
        local targetY = (i - 1) * (NOTIFICATION_HEIGHT + NOTIFICATION_PADDING)
        TweenService:Create(entry.frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Position = UDim2.new(0.98, 0, 0, targetY + 10),
        }):Play()
    end
end

-- Remove a notification
local function _removeNotification(entry)
    -- Slide out
    local tween = TweenService:Create(entry.frame, TweenInfo.new(SLIDE_OUT_TIME, Enum.EasingStyle.Quad), {
        Position = UDim2.new(1.05, 0, 0, entry.frame.Position.Y.Offset),
        BackgroundTransparency = 1,
    })
    tween:Play()
    tween.Completed:Connect(function()
        entry.frame:Destroy()
    end)

    -- Remove from visible list
    for i, v in ipairs(_visible) do
        if v.id == entry.id then
            table.remove(_visible, i)
            break
        end
    end

    _repositionVisible()

    -- Show next in queue if available
    if #_queue > 0 then
        local next = table.remove(_queue, 1)
        NotificationController.showImmediate(next.message, next.color, next.duration)
    end
end

-- Show a notification immediately
function NotificationController.showImmediate(message, color, duration)
    if not _container then return end

    local frame, id, dur = _createNotificationFrame(message, color, duration)
    frame.Parent = _container

    local entry = { frame = frame, id = id, duration = dur }
    table.insert(_visible, entry)

    _repositionVisible()

    -- Slide in
    local targetY = (#_visible - 1) * (NOTIFICATION_HEIGHT + NOTIFICATION_PADDING)
    TweenService:Create(frame, TweenInfo.new(SLIDE_IN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.98, 0, 0, targetY + 10),
    }):Play()

    -- Auto-dismiss
    task.delay(dur, function()
        if frame.Parent then
            _removeNotification(entry)
        end
    end)
end

-- Public API: queue a notification (respects MAX_VISIBLE)
function NotificationController.show(message, color, duration)
    if #_visible >= MAX_VISIBLE then
        table.insert(_queue, {
            message = message,
            color = color,
            duration = duration,
        })
    else
        NotificationController.showImmediate(message, color, duration)
    end
end

-- Priority notification (always shows immediately, pushes others down)
function NotificationController.showPriority(message, color, duration)
    NotificationController.showImmediate(message, color, duration or 6)
end

function NotificationController.initialize()
    local player = Players.LocalPlayer
    local gui = player.PlayerGui:FindFirstChild("SoulMinersGui")

    if gui then
        _container = gui:FindFirstChild("NotificationContainer")
    end

    if not _container then
        -- Create container if it doesn't exist
        local screenGui = player.PlayerGui:FindFirstChild("SoulMinersGui")
        if not screenGui then
            screenGui = Instance.new("ScreenGui")
            screenGui.Name = "SoulMinersGui"
            screenGui.ResetOnSpawn = false
            screenGui.Parent = player.PlayerGui
        end

        _container = Instance.new("Frame")
        _container.Name = "NotificationContainer"
        _container.Size = UDim2.new(0.35, 0, 0.5, 0)
        _container.Position = UDim2.new(1, 0, 0, 0)
        _container.AnchorPoint = Vector2.new(1, 0)
        _container.BackgroundTransparency = 1
        _container.Parent = screenGui
    end

    print("[NotificationController] Initialised.")
end

return NotificationController
