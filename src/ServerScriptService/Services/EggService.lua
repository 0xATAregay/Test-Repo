-- ============================================================================
-- EggService.lua
-- Handles all gacha/egg opening logic.
-- All RNG happens server-side. Client only receives the result.
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.Events.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local RarityConfig = require(game.ReplicatedStorage.Shared.Modules.RarityConfig)

local EggService = {}

-- Rate limiting: prevent spam-clicking egg open
local _lastEggOpen = {} -- [userId] = tick()
local EGG_COOLDOWN = 0.5 -- seconds
local MAX_EQUIPPED_SPIRITS = 3

--[[
    EggService.openEgg(player, eggId, quantity)
    Validates the request, deducts cost, rolls RNG server-side,
    adds spirit to inventory, and fires result to client.
]]
function EggService.openEgg(player, eggId, quantity)
    quantity = math.clamp(tonumber(quantity) or 1, 1, 10)

    local userId = player.UserId
    if _lastEggOpen[userId] and (tick() - _lastEggOpen[userId]) < EGG_COOLDOWN then
        return
    end
    _lastEggOpen[userId] = tick()

    -- Validate egg ID
    local eggConfig = RarityConfig.EGGS[eggId]
    if not eggConfig then
        warn("[EggService] Invalid egg ID from", player.Name, ":", eggId)
        return
    end

    local data = PlayerDataService.GetData(player)
    if not data then return end

    -- Check zone requirement
    if data.currentZone < eggConfig.requiredZone then
        RemoteEvents.EggResult:FireClient(player, {
            success = false,
            reason = "You must reach Zone " .. eggConfig.requiredZone .. " to open this egg.",
        })
        return
    end

    -- Calculate total cost
    local totalCost = eggConfig.cost * quantity
    local currency = eggConfig.costCurrency

    -- Attempt to deduct cost
    local afforded = CurrencyService.deductCurrency(player, currency, totalCost)
    if not afforded then
        RemoteEvents.EggResult:FireClient(player, {
            success = false,
            reason = "Not enough " .. currency .. "!",
        })
        return
    end

    -- Roll spirits
    local results = {}
    local pityKey = eggId

    PlayerDataService.UpdateData(player, function(d)
        if not d.pity[pityKey] then
            d.pity[pityKey] = 0
        end

        for i = 1, quantity do
            local rarity, newPity = RarityConfig.rollRarity(eggId, d.pity[pityKey])
            d.pity[pityKey] = newPity

            local spirit = RarityConfig.rollSpirit(rarity)
            table.insert(d.spirits, spirit)
            table.insert(results, spirit)

            d.totalEggsOpened = (d.totalEggsOpened or 0) + 1

            -- Server-wide broadcast for Mythic/Legendary pulls
            if rarity == "MYTHIC" or rarity == "LEGENDARY" then
                RemoteEvents.ServerAnnouncement:FireAllClients({
                    type = "RARE_PULL",
                    playerName = player.Name,
                    spiritName = spirit.name,
                    rarity = rarity,
                })
            end
        end
    end)

    -- Sync full spirit inventory to client
    local updatedData = PlayerDataService.GetData(player)
    if updatedData then
        RemoteEvents.UpdateSpirits:FireClient(player, {
            spirits = updatedData.spirits,
            equippedSpirits = updatedData.equippedSpirits,
        })
    end

    -- Send specific results for opening animation
    RemoteEvents.EggResult:FireClient(player, {
        success = true,
        results = results,
        newPityCount = updatedData and updatedData.pity[pityKey] or 0,
        pityEpicAt = eggConfig.pityEpicAt,
        pityLegendaryAt = eggConfig.pityLegendaryAt,
    })
end

--[[
    EggService.equipSpirit(player, spiritId)
    Equips a spirit from inventory. Max 3 equipped at once.
]]
function EggService.equipSpirit(player, spiritId)
    local data = PlayerDataService.GetData(player)
    if not data then return end

    -- Verify spirit exists in inventory
    local found = false
    for _, spirit in ipairs(data.spirits) do
        if spirit.id == spiritId then
            found = true
            break
        end
    end

    if not found then
        RemoteEvents.EquipResult:FireClient(player, {
            success = false,
            reason = "Spirit not found in inventory.",
        })
        return
    end

    -- Check if already equipped
    for _, equipped in ipairs(data.equippedSpirits) do
        if equipped == spiritId then
            RemoteEvents.EquipResult:FireClient(player, {
                success = false,
                reason = "Spirit is already equipped.",
            })
            return
        end
    end

    -- Check max equipped
    if #data.equippedSpirits >= MAX_EQUIPPED_SPIRITS then
        RemoteEvents.EquipResult:FireClient(player, {
            success = false,
            reason = "Maximum " .. MAX_EQUIPPED_SPIRITS .. " spirits can be equipped at once.",
        })
        return
    end

    PlayerDataService.UpdateData(player, function(d)
        table.insert(d.equippedSpirits, spiritId)
    end)

    local updatedData = PlayerDataService.GetData(player)
    RemoteEvents.EquipResult:FireClient(player, {
        success = true,
        equippedSpirits = updatedData and updatedData.equippedSpirits or {},
    })
    RemoteEvents.UpdateSpirits:FireClient(player, {
        spirits = updatedData and updatedData.spirits or {},
        equippedSpirits = updatedData and updatedData.equippedSpirits or {},
    })
end

--[[
    EggService.unequipSpirit(player, spiritId)
    Removes a spirit from the equipped list.
]]
function EggService.unequipSpirit(player, spiritId)
    local data = PlayerDataService.GetData(player)
    if not data then return end

    local foundIndex = nil
    for i, equipped in ipairs(data.equippedSpirits) do
        if equipped == spiritId then
            foundIndex = i
            break
        end
    end

    if not foundIndex then
        RemoteEvents.EquipResult:FireClient(player, {
            success = false,
            reason = "Spirit is not equipped.",
        })
        return
    end

    PlayerDataService.UpdateData(player, function(d)
        table.remove(d.equippedSpirits, foundIndex)
    end)

    local updatedData = PlayerDataService.GetData(player)
    RemoteEvents.EquipResult:FireClient(player, {
        success = true,
        equippedSpirits = updatedData and updatedData.equippedSpirits or {},
    })
    RemoteEvents.UpdateSpirits:FireClient(player, {
        spirits = updatedData and updatedData.spirits or {},
        equippedSpirits = updatedData and updatedData.equippedSpirits or {},
    })
end

-- Lifecycle
function EggService.init()
    RemoteEvents.OpenEgg.OnServerEvent:Connect(function(player, eggId, quantity)
        EggService.openEgg(player, eggId, quantity or 1)
    end)

    RemoteEvents.EquipSpirit.OnServerEvent:Connect(function(player, spiritId)
        EggService.equipSpirit(player, spiritId)
    end)

    RemoteEvents.UnequipSpirit.OnServerEvent:Connect(function(player, spiritId)
        EggService.unequipSpirit(player, spiritId)
    end)

    Players.PlayerRemoving:Connect(function(player)
        _lastEggOpen[player.UserId] = nil
    end)

    print("[EggService] Initialised.")
end

return EggService
