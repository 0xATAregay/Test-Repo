-- ZoneConfig.lua
-- World/Zone definitions for Soul Miners.
-- Each zone has unique theming, soul requirements, and multipliers.

local ZoneConfig = {}

-- Zone definitions ordered by progression
ZoneConfig.ZONES = {
    [1] = {
        id = "limbo_fields",
        name = "Limbo Fields",
        theme = "Tutorial",
        description = "Where every Reaper begins their journey. Glowing crystals dot the misty landscape.",
        soulsRequired = 0,
        multiplier = 1,
        crystalHealth = 50,
        crystalRespawnTime = 3,
        ambientColor = Color3.fromRGB(180, 180, 200),
        skyboxId = "",
        musicId = "",
    },
    [2] = {
        id = "shadow_caverns",
        name = "Shadow Caverns",
        theme = "Dark Cave",
        description = "Deep underground where shadows dance. Crystals pulse with dark energy.",
        soulsRequired = 10000,
        multiplier = 3,
        crystalHealth = 120,
        crystalRespawnTime = 4,
        ambientColor = Color3.fromRGB(40, 30, 60),
        skyboxId = "",
        musicId = "",
    },
    [3] = {
        id = "infernal_depths",
        name = "Infernal Depths",
        theme = "Lava",
        description = "Rivers of molten soul-fire flow between obsidian platforms. Only the brave mine here.",
        soulsRequired = 100000,
        multiplier = 10,
        crystalHealth = 300,
        crystalRespawnTime = 5,
        ambientColor = Color3.fromRGB(200, 60, 20),
        skyboxId = "",
        musicId = "",
    },
    [4] = {
        id = "celestial_rift",
        name = "Celestial Rift",
        theme = "Heaven/Hell Border",
        description = "Where light meets darkness. Crystals here shimmer between gold and void-black.",
        soulsRequired = 10000000,
        multiplier = 50,
        crystalHealth = 800,
        crystalRespawnTime = 6,
        ambientColor = Color3.fromRGB(200, 180, 255),
        skyboxId = "",
        musicId = "",
    },
    [5] = {
        id = "void_nexus",
        name = "Void Nexus",
        theme = "Endgame",
        description = "The center of all realities. Crystals here contain pure concentrated soul energy.",
        soulsRequired = 1000000000,
        multiplier = 200,
        crystalHealth = 2000,
        crystalRespawnTime = 8,
        ambientColor = Color3.fromRGB(20, 0, 40),
        skyboxId = "",
        musicId = "",
    },
}

-- Get zone data by index
function ZoneConfig.getZone(zoneIndex)
    return ZoneConfig.ZONES[zoneIndex]
end

-- Get total number of zones
function ZoneConfig.getZoneCount()
    return #ZoneConfig.ZONES
end

-- Check if a player can access a zone given their total souls mined
function ZoneConfig.canAccessZone(zoneIndex, totalSoulsMined)
    local zone = ZoneConfig.ZONES[zoneIndex]
    if not zone then return false end
    return totalSoulsMined >= zone.soulsRequired
end

-- Get the next locked zone and its requirement
function ZoneConfig.getNextLockedZone(currentZone)
    local nextIndex = currentZone + 1
    local zone = ZoneConfig.ZONES[nextIndex]
    if not zone then return nil end
    return {
        index = nextIndex,
        name = zone.name,
        soulsRequired = zone.soulsRequired,
    }
end

return ZoneConfig
