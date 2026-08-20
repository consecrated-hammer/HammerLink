local addonName, ns = ...

local LibDeflate = LibStub("LibDeflate")

-- This encoder deliberately handles only values HammerLink emits. Keeping the
-- payload shape explicit avoids serialising arbitrary Blizzard tables whose
-- fields can change or become private between client patches.
local function quote(value)
    return '"' .. tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
end

local function encode(value)
    local kind = type(value)
    if kind == "string" then return quote(value) end
    if kind == "number" then return tostring(value) end
    if kind == "boolean" then return value and "true" or "false" end
    if kind ~= "table" then return "null" end

    local count, maximumIndex, array = 0, 0, true
    for key in pairs(value) do
        count = count + 1
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            array = false
        elseif key > maximumIndex then
            maximumIndex = key
        end
    end
    array = array and maximumIndex == count
    if array then
        local values = {}
        for i = 1, count do values[i] = encode(value[i]) end
        return "[" .. table.concat(values, ",") .. "]"
    end
    local pairsOut = {}
    for key, item in pairs(value) do
        pairsOut[#pairsOut + 1] = quote(key) .. ":" .. encode(item)
    end
    table.sort(pairsOut)
    return "{" .. table.concat(pairsOut, ",") .. "}"
end

local EQUIPMENT_SLOTS = {
    { "HEAD", INVSLOT_HEAD }, { "NECK", INVSLOT_NECK }, { "SHOULDER", INVSLOT_SHOULDER },
    { "BACK", INVSLOT_BACK }, { "CHEST", INVSLOT_CHEST }, { "WRIST", INVSLOT_WRIST },
    { "HANDS", INVSLOT_HAND }, { "WAIST", INVSLOT_WAIST }, { "LEGS", INVSLOT_LEGS },
    { "FEET", INVSLOT_FEET }, { "FINGER_1", INVSLOT_FINGER1 }, { "FINGER_2", INVSLOT_FINGER2 },
    { "TRINKET_1", INVSLOT_TRINKET1 }, { "TRINKET_2", INVSLOT_TRINKET2 },
    { "MAIN_HAND", INVSLOT_MAINHAND }, { "OFF_HAND", INVSLOT_OFFHAND },
}

local function character()
    local name, realm = UnitFullName("player")
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or nil
    local overall, equipped = GetAverageItemLevel()
    return {
        name = name,
        realm = realm or GetRealmName(),
        region = GetCurrentRegion and GetCurrentRegion() or nil,
        class = class,
        level = UnitLevel("player"),
        specID = specID,
        equippedItemLevel = equipped,
        overallItemLevel = overall,
    }
end

local function equipment()
    local result = {}
    for _, descriptor in ipairs(EQUIPMENT_SLOTS) do
        local slot, inventorySlot = descriptor[1], descriptor[2]
        local link = GetInventoryItemLink("player", inventorySlot)
        if link then
            local itemID = C_Item.GetItemInfoInstant(link)
            result[#result + 1] = { slot = slot, itemID = itemID, link = link }
        end
    end
    return result
end

local function addIfPresent(target, key, value)
    if value ~= nil then target[key] = value end
end

local function itemDetails(link, containerInfo)
    local itemID, itemType, itemSubType, inventoryType, iconFileID, classID, subclassID = C_Item.GetItemInfoInstant(link)
    local value = {
        itemID = containerInfo.itemID or itemID,
        link = link,
        itemType = itemType,
        itemSubType = itemSubType,
        inventoryType = inventoryType,
        iconFileID = containerInfo.iconFileID or iconFileID,
        classID = classID,
        subclassID = subclassID,
        stackCount = containerInfo.stackCount,
        isBound = containerInfo.isBound,
    }
    addIfPresent(value, "name", containerInfo.itemName)
    addIfPresent(value, "quality", containerInfo.quality)

    if C_Item.GetItemInfo then
        local ok, name, _, quality, baseItemLevel, requiredLevel, _, _, _, _, sellPrice,
            cachedClassID, cachedSubclassID, bindType, expansionID, setID, isCraftingReagent = pcall(C_Item.GetItemInfo, link)
        if ok then
            addIfPresent(value, "name", name)
            addIfPresent(value, "quality", quality)
            addIfPresent(value, "baseItemLevel", baseItemLevel)
            addIfPresent(value, "requiredLevel", requiredLevel)
            addIfPresent(value, "sellPrice", sellPrice)
            addIfPresent(value, "classID", cachedClassID)
            addIfPresent(value, "subclassID", cachedSubclassID)
            addIfPresent(value, "bindType", bindType)
            addIfPresent(value, "expansionID", expansionID)
            addIfPresent(value, "setID", setID)
            addIfPresent(value, "isCraftingReagent", isCraftingReagent)
        end
    end

    if C_Item.GetDetailedItemLevelInfo then
        local ok, itemLevel = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok then addIfPresent(value, "itemLevel", itemLevel) end
    end

    if C_Item.GetItemStats then
        local ok, itemStats = pcall(C_Item.GetItemStats, link)
        if ok and type(itemStats) == "table" then
            local stats = {}
            for stat, amount in pairs(itemStats) do
                if type(stat) == "string" and type(amount) == "number" then stats[stat] = amount end
            end
            if next(stats) then value.stats = stats end
        end
    end

    if C_Item.GetItemGem then
        local gems = {}
        for socket = 1, 4 do
            local ok, gemName, gemLink = pcall(C_Item.GetItemGem, link, socket)
            if ok and gemLink then
                local gemID = C_Item.GetItemInfoInstant(gemLink)
                gems[#gems + 1] = { socket = socket, itemID = gemID, name = gemName, link = gemLink }
            end
        end
        if #gems > 0 then value.gems = gems end
    end

    return value
end

local function bagEquipment()
    local result = {}
    if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then return result end

    local bagIDs, seenBags = {}, {}
    local function addBag(bag)
        if type(bag) == "number" and not seenBags[bag] then
            seenBags[bag] = true
            bagIDs[#bagIDs + 1] = bag
        end
    end

    addBag(Enum and Enum.BagIndex and Enum.BagIndex.Backpack or 0)
    for bag = 1, (NUM_BAG_SLOTS or 4) do addBag(bag) end
    addBag(Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5)

    for _, bag in ipairs(bagIDs) do
        local slotsOK, slotCount = pcall(C_Container.GetContainerNumSlots, bag)
        if slotsOK and type(slotCount) == "number" then
            for slot = 1, slotCount do
                local infoOK, containerInfo = pcall(C_Container.GetContainerItemInfo, bag, slot)
                if infoOK and containerInfo then
                    local link = containerInfo.hyperlink
                    if not link and C_Container.GetContainerItemLink then
                        local linkOK, itemLink = pcall(C_Container.GetContainerItemLink, bag, slot)
                        if linkOK then link = itemLink end
                    end
                    if link then
                        local _, _, _, inventoryType = C_Item.GetItemInfoInstant(link)
                        if inventoryType and inventoryType ~= "" then
                            local item = itemDetails(link, containerInfo)
                            item.bag = bag
                            item.slot = slot

                            if C_Container.GetContainerItemDurability then
                                local durabilityOK, current, maximum = pcall(C_Container.GetContainerItemDurability, bag, slot)
                                if durabilityOK and current ~= nil and maximum ~= nil then
                                    item.durability = { current = current, maximum = maximum }
                                end
                            end
                            if C_Container.GetContainerItemEquipmentSetInfo then
                                local setOK, inSet, setList = pcall(C_Container.GetContainerItemEquipmentSetInfo, bag, slot)
                                if setOK and inSet then addIfPresent(item, "equipmentSets", setList) end
                            end

                            result[#result + 1] = item
                        end
                    end
                end
            end
        end
    end
    return result
end

local function talentExport()
    local specIndex = GetSpecialization()
    if not specIndex or not C_ClassTalents or not C_Traits then return nil end
    local configID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then return nil end
    local ok, importString = pcall(C_Traits.GenerateImportString, configID)
    return ok and importString or nil
end

local function reward(rewardInfo)
    local value = { type = rewardInfo.type, id = rewardInfo.id, quantity = rewardInfo.quantity }
    if rewardInfo.itemDBID and C_WeeklyRewards and C_WeeklyRewards.GetItemHyperlink then
        value.link = C_WeeklyRewards.GetItemHyperlink(rewardInfo.itemDBID)
    end
    return value
end

local function vault()
    local snapshot = {
        capturedAt = time(),
        nextResetSeconds = GetQuestResetTime and GetQuestResetTime() or nil,
        currentPeriod = C_WeeklyRewards and C_WeeklyRewards.AreRewardsForCurrentRewardPeriod and C_WeeklyRewards.AreRewardsForCurrentRewardPeriod() or nil,
        hasAvailableRewards = C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards and C_WeeklyRewards.HasAvailableRewards() or nil,
        hasGeneratedRewards = C_WeeklyRewards and C_WeeklyRewards.HasGeneratedRewards and C_WeeklyRewards.HasGeneratedRewards() or nil,
        activities = {},
    }
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return snapshot end
    for _, activity in ipairs(C_WeeklyRewards.GetActivities() or {}) do
        local item = {
            type = activity.type, index = activity.index, id = activity.id,
            threshold = activity.threshold, progress = activity.progress,
            activityTierID = activity.activityTierID, level = activity.level,
            claimID = activity.claimID, raidString = activity.raidString, rewards = {},
        }
        for _, rewardInfo in ipairs(activity.rewards or {}) do item.rewards[#item.rewards + 1] = reward(rewardInfo) end
        snapshot.activities[#snapshot.activities + 1] = item
    end
    if C_WeeklyRewards.GetNumCompletedDungeonRuns then
        local heroic, mythic, mythicPlus = C_WeeklyRewards.GetNumCompletedDungeonRuns()
        snapshot.dungeonRuns = { heroic = heroic, mythic = mythic, mythicPlus = mythicPlus }
    end
    return snapshot
end

function ns.BuildSnapshot()
    return {
        format = 1,
        capturedAt = time(),
        character = character(),
        equipment = equipment(),
        bagEquipment = bagEquipment(),
        talents = { importString = talentExport() },
        vault = vault(),
    }
end

function ns.BuildExport()
    local json = encode(ns.BuildSnapshot())
    local compressed = LibDeflate:CompressDeflate(json, { level = 9 })
    assert(compressed, "could not compress export")
    return ns.PREFIX .. LibDeflate:EncodeForPrint(compressed), #json
end
