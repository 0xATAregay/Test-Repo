-- ============================================================================
-- ZoneService.lua
-- Manages zone unlocks, teleportation, and per-zone multipliers.
-- Players unlock zones by reaching soul thresholds.
-- ============================================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents      = require(ReplicatedStorage.Shared.Events.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ZoneConfig        = require(game.ReplicatedStorage.Shared.Modules.ZoneConfig)

local ZoneService = {}

-- Rate limiting for zone changes
local _lastZoneChange = {}
local ZONE_CHANGE_COOLDOWN = 1.0

--[[
    ZoneService.requestZoneChange(player, targetZoneIndex)
    Validates the player can access the zone and teleports them.
]]
function ZoneService.requestZoneChange(player, targetZoneIndex)
    local userId = player.UserId

    -- Rate limit
    if _lastZoneChange[userId] and (tick() - _lastZoneChange[userId]) < ZONE_CHANGE_COOLDOWN then
        return
    end
    _lastZoneChange[userId] = tick()

    -- Validate zone exists
    targetZoneIndex = tonumber(targetZoneIndex)
    if not targetZoneIndex then return end

    local zoneData = ZoneConfig.getZone(targetZoneIndex)
    if not zoneData then
        RemoteEvents.ZoneChangeResult:FireClient(player, {
            success = false,
            reason = "Invalid zone.",
        })
        return
    end

    local data = PlayerDataService.GetData(player)
    if not data then return end

    -- Check unlock requirement
    if not ZoneConfig.canAccessZone(targetZoneIndex, data.totalSoulsMined) then
        RemoteEvents.ZoneChangeResult:FireClient(player, {
            success = false,
            reason = string.format(
                "You need %s total souls to access %s!",
                tostring(zoneData.soulsRequired),
                zoneData.name
            ),
        })
        return
    end

    -- Already in this zone
    if data.currentZone == targetZoneIndex then
        RemoteEvents.ZoneChangeResult:FireClient(player, {
            success = false,
            reason = "You are already in " .. zoneData.name .. "!",
        })
        return
    end

    -- Update zone
    PlayerDataService.UpdateData(player, function(d)
        d.currentZone = targetZoneIndex
    end)

    -- Teleport player to zone spawn point
    ZoneService.teleportToZone(player, targetZoneIndex)

    RemoteEvents.ZoneChangeResult:FireClient(player, {
        success = true,
        zoneIndex = targetZoneIndex,
        zoneName = zoneData.name,
        zoneMultiplier = zoneData.multiplier,
    })

    print(string.format(
        "[ZoneService] %s moved to Zone %d: %s (x%d multiplier)",
        player.Name, targetZoneIndex, zoneData.name, zoneData.multiplier
    ))
end

--[[
    ZoneService.teleportToZone(player, zoneIndex)
    Moves the player's character to the zone's spawn point.
]]
function ZoneService.teleportToZone(player, zoneIndex)
    local character = player.Character
    if not character then return end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    local zoneData = ZoneConfig.getZone(zoneIndex)
    if not zoneData then return end

    -- Find the zone spawn point in workspace
    local zonesFolder = workspace:FindFirstChild("Zones")
    if not zonesFolder then return end

    local zoneFolder = zonesFolder:FindFirstChild(zoneData.id)
    if not zoneFolder then return end

    local spawnPoint = zoneFolder:FindFirstChild("SpawnPoint")
    if spawnPoint then
        humanoidRootPart.CFrame = spawnPoint.CFrame + Vector3.new(0, 5, 0)
    end
end

--[[
    ZoneService.checkNewUnlocks(player)
    Called after soul changes to check if new zones have been unlocked.
    Fires ZoneUnlocked event for UI notifications.
]]
function ZoneService.checkNewUnlocks(player)
    local data = PlayerDataService.GetData(player)
    if not data then return end

    local totalZones = ZoneConfig.getZoneCount()

    for i = data.currentZone + 1, totalZones do
        local zone = ZoneConfig.getZone(i)
        if zone and ZoneConfig.canAccessZone(i, data.totalSoulsMined) then
            RemoteEvents.ZoneUnlocked:FireClient(player, {
                zoneIndex = i,
                zoneName = zone.name,
                zoneMultiplier = zone.multiplier,
            })
        else
            break -- zones are sequential
        end
    end
end

--[[
    ZoneService.getZoneInfo(player) -> table
    Returns all zone info for the player (for UI map display).
]]
function ZoneService.getZoneInfo(player)
    local data = PlayerDataService.GetData(player)
    if not data then return nil end

    local zones = {}
    local totalZones = ZoneConfig.getZoneCount()

    for i = 1, totalZones do
        local zone = ZoneConfig.getZone(i)
        if zone then
            table.insert(zones, {
                index = i,
                id = zone.id,
                name = zone.name,
                theme = zone.theme,
                description = zone.description,
                soulsRequired = zone.soulsRequired,
                multiplier = zone.multiplier,
                unlocked = ZoneConfig.canAccessZone(i, data.totalSoulsMined),
                isCurrent = data.currentZone == i,
            })
        end
    end

    return {
        currentZone = data.currentZone,
        zones = zones,
    }
end

function ZoneService.init()
    RemoteEvents.RequestZoneChange.OnServerEvent:Connect(function(player, targetZoneIndex)
        task.spawn(ZoneService.requestZoneChange, player, targetZoneIndex)
    end)

    Players.PlayerRemoving:Connect(function(player)
        _lastZoneChange[player.UserId] = nil
    end)

    print("[ZoneService] Initialised.")
end

return ZoneService
