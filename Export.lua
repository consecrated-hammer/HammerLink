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
    if value.itemType == "" then value.itemType = nil end
    if value.itemSubType == "" then value.itemSubType = nil end
    if value.inventoryType == "" then value.inventoryType = nil end
    addIfPresent(value, "name", containerInfo.itemName)
    addIfPresent(value, "quality", containerInfo.quality)
    local canEquip = value.inventoryType ~= nil

    if C_Item.GetItemInfo then
        local ok, name, _, quality, baseItemLevel, requiredLevel, _, _, _, _, _, sellPrice,
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
            -- The Retail client has returned non-boolean placeholders here for
            -- uncached items. Do not let one odd reagent flag reject the whole
            -- otherwise-valid export on the website.
            if type(isCraftingReagent) == "boolean" then
                value.isCraftingReagent = isCraftingReagent
            end
        end
    end

    if canEquip and C_Item.GetDetailedItemLevelInfo then
        local ok, itemLevel = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok then addIfPresent(value, "itemLevel", itemLevel) end
    end

    if canEquip and C_Item.GetItemStats then
        local ok, itemStats = pcall(C_Item.GetItemStats, link)
        if ok and type(itemStats) == "table" then
            local stats = {}
            for stat, amount in pairs(itemStats) do
                if type(stat) == "string" and type(amount) == "number" then stats[stat] = amount end
            end
            if next(stats) then value.stats = stats end
        end
    end

    if canEquip and C_Item.GetItemGem then
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
                        local item = itemDetails(link, containerInfo)
                        item.bag = bag
                        item.slot = slot

                        if item.inventoryType and C_Container.GetContainerItemDurability then
                            local durabilityOK, current, maximum = pcall(C_Container.GetContainerItemDurability, bag, slot)
                            if durabilityOK and current ~= nil and maximum ~= nil then
                                item.durability = { current = current, maximum = maximum }
                            end
                        end
                        if item.inventoryType and C_Container.GetContainerItemEquipmentSetInfo then
                            local setOK, inSet, setList = pcall(C_Container.GetContainerItemEquipmentSetInfo, bag, slot)
                            if setOK and inSet then addIfPresent(item, "equipmentSets", setList) end
                        end

                        result[#result + 1] = item
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

local function currencyCaps()
    local result = {}
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyListSize or not C_CurrencyInfo.GetCurrencyListInfo then return result end
    local ok, size = pcall(C_CurrencyInfo.GetCurrencyListSize)
    if not ok or type(size) ~= "number" then return result end
    for index = 1, size do
        local listOK, listed = pcall(C_CurrencyInfo.GetCurrencyListInfo, index)
        local currencyID = listOK and listed and listed.currencyID
        if currencyID and not listed.isHeader then
            local infoOK, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
            if infoOK and info and (info.maxQuantity and info.maxQuantity > 0 or info.maxWeeklyQuantity and info.maxWeeklyQuantity > 0 or info.useTotalEarnedForMaxQty) then
                result[#result + 1] = {
                    currencyID = currencyID, name = info.name, quantity = info.quantity,
                    iconFileID = info.iconFileID, maxQuantity = info.maxQuantity,
                    maxWeeklyQuantity = info.maxWeeklyQuantity,
                    quantityEarnedThisWeek = info.quantityEarnedThisWeek,
                    totalEarned = info.totalEarned, canEarnPerWeek = info.canEarnPerWeek,
                    useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty,
                    isAccountWide = info.isAccountWide, isAccountTransferable = info.isAccountTransferable,
                }
            end
        end
    end
    table.sort(result, function(a, b) return (a.name or "") < (b.name or "") end)
    return result
end

local function questLog()
    local snapshot = { available = false, capturedAt = time(), entries = {}, truncated = false }
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then
        snapshot.reason = "The Retail quest log API is unavailable in this client."
        return snapshot
    end

    local countOK, shownEntries, questCount = pcall(C_QuestLog.GetNumQuestLogEntries)
    if not countOK or type(shownEntries) ~= "number" then
        snapshot.reason = "The current quest log could not be read."
        return snapshot
    end

    snapshot.available = true
    snapshot.totalQuests = type(questCount) == "number" and questCount or nil
    local limit = math.min(shownEntries, 256)
    snapshot.truncated = shownEntries > limit
    local seen = {}
    for index = 1, limit do
        local infoOK, info = pcall(C_QuestLog.GetInfo, index)
        if infoOK and type(info) == "table" and not info.isHeader
            and type(info.questID) == "number" and info.questID > 0
            and type(info.title) == "string" and info.title ~= "" and not seen[info.questID] then
            seen[info.questID] = true
            local quest = {
                questID = info.questID, logIndex = index, title = info.title,
                level = info.level, difficultyLevel = info.difficultyLevel,
                suggestedGroup = info.suggestedGroup, frequency = info.frequency,
                campaignID = info.campaignID, questClassification = info.questClassification,
                isTask = info.isTask, isBounty = info.isBounty, isStory = info.isStory,
                isHidden = info.isHidden, isAutoComplete = info.isAutoComplete,
                objectives = {},
            }

            if C_QuestLog.IsComplete then
                local ok, value = pcall(C_QuestLog.IsComplete, info.questID)
                if ok and type(value) == "boolean" then quest.isComplete = value end
            end
            if C_QuestLog.IsFailed then
                local ok, value = pcall(C_QuestLog.IsFailed, info.questID)
                if ok and type(value) == "boolean" then quest.isFailed = value end
            end
            if C_QuestLog.GetQuestWatchType then
                local ok, value = pcall(C_QuestLog.GetQuestWatchType, info.questID)
                if ok and type(value) == "number" then quest.watchType = value end
            end
            if C_QuestLog.GetQuestObjectives then
                local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, info.questID)
                if ok and type(objectives) == "table" then
                    for objectiveIndex, objective in ipairs(objectives) do
                        if objectiveIndex > 64 then break end
                        if type(objective) == "table" and type(objective.text) == "string" then
                            quest.objectives[#quest.objectives + 1] = {
                                text = objective.text, type = objective.type,
                                finished = objective.finished,
                                numFulfilled = objective.numFulfilled,
                                numRequired = objective.numRequired,
                                objectiveType = objective.objectiveType,
                            }
                        end
                    end
                end
            end
            if C_QuestLog.GetQuestTagInfo then
                local ok, tag = pcall(C_QuestLog.GetQuestTagInfo, info.questID)
                if ok and type(tag) == "table" and type(tag.tagName) == "string" then
                    quest.tag = {
                        name = tag.tagName, id = tag.tagID,
                        worldQuestType = tag.worldQuestType, quality = tag.quality,
                        tradeskillLineID = tag.tradeskillLineID,
                        isElite = tag.isElite, displayExpiration = tag.displayExpiration,
                    }
                end
            end
            if C_QuestLog.GetNextWaypoint then
                local ok, mapID, x, y = pcall(C_QuestLog.GetNextWaypoint, info.questID)
                if ok and type(mapID) == "number" and type(x) == "number" and type(y) == "number" then
                    quest.waypoint = { mapID = mapID, x = x, y = y }
                end
            end
            if C_QuestLog.GetTimeAllowed then
                local ok, totalTime, elapsedTime = pcall(C_QuestLog.GetTimeAllowed, info.questID)
                if ok and type(totalTime) == "number" and type(elapsedTime) == "number" then
                    quest.timer = { totalSeconds = totalTime, elapsedSeconds = elapsedTime }
                end
            end
            snapshot.entries[#snapshot.entries + 1] = quest
        end
    end
    return snapshot
end

function ns.BuildSnapshot()
    local options = ns.GetExportOptions()
    local snapshot = {
        format = 3,
        capturedAt = time(),
        character = character(),
        exportOptions = {
            equipment = ns.IsExportEnabled("equipment"), bagItems = ns.IsExportEnabled("bagItems"),
            talents = ns.IsExportEnabled("talents"), vault = ns.IsExportEnabled("vault"),
            currencyCaps = ns.IsExportEnabled("currencyCaps"), decorInventory = ns.IsExportEnabled("decorInventory"),
            questLog = ns.IsExportEnabled("questLog"),
        },
    }
    if options.equipment ~= false then snapshot.equipment = equipment() end
    if options.bagItems ~= false then snapshot.bagEquipment = bagEquipment() end
    if options.talents ~= false then snapshot.talents = { importString = talentExport() } end
    if options.vault ~= false then snapshot.vault = vault() end
    if options.currencyCaps ~= false then snapshot.currencyCaps = currencyCaps() end
    if options.decorInventory ~= false then snapshot.decorInventory = ns.GetDecorInventory() end
    if options.questLog ~= false then snapshot.questLog = questLog() end
    return snapshot
end

function ns.BuildExport()
    local json = encode(ns.BuildSnapshot())
    local compressed = LibDeflate:CompressDeflate(json, { level = 9 })
    assert(compressed, "could not compress export")
    return ns.PREFIX .. LibDeflate:EncodeForPrint(compressed), #json
end
