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

local function weeklyRewardValue(method)
    local getter = C_WeeklyRewards and C_WeeklyRewards[method]
    if not getter then return nil end
    local ok, value = pcall(getter)
    if not ok then return nil end
    return value
end

local function vault()
    local snapshot = {
        capturedAt = time(),
        nextResetSeconds = GetQuestResetTime and GetQuestResetTime() or nil,
        currentPeriod = weeklyRewardValue("AreRewardsForCurrentRewardPeriod"),
        hasAvailableRewards = weeklyRewardValue("HasAvailableRewards"),
        hasGeneratedRewards = weeklyRewardValue("HasGeneratedRewards"),
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
                        if type(objective) == "table" and type(objective.text) == "string" and objective.text ~= "" then
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

local CATEGORY_ORDER = {
    "equipment", "bagItems", "talents", "vault", "currencyCaps",
    "decorInventory", "questLog", "professionRecipes",
}

local CATEGORY_FIELDS = {
    equipment = "equipment", bagItems = "bagEquipment", talents = "talents",
    vault = "vault", currencyCaps = "currencyCaps",
    decorInventory = "decorInventory", questLog = "questLog",
    professionRecipes = "professionRecipes",
}

local CATEGORY_TITLES = {
    equipment = "Equipped gear", bagItems = "Bag items", talents = "Active talents",
    vault = "Great Vault", currencyCaps = "Currency caps",
    decorInventory = "Housing decor inventory", questLog = "Current quest log",
    professionRecipes = "Learned profession recipes",
}

local function selectedOptions(options)
    local selected = {}
    options = options or ns.GetExportOptions()
    for _, category in ipairs(CATEGORY_ORDER) do selected[category] = options[category] ~= false end
    return selected
end

function ns.BuildSnapshot(options)
    local selected = selectedOptions(options)
    local snapshot = {
        format = 3,
        capturedAt = time(),
        character = character(),
        exportOptions = selected,
    }
    if selected.equipment then snapshot.equipment = equipment() end
    if selected.bagItems then snapshot.bagEquipment = bagEquipment() end
    if selected.talents then snapshot.talents = { importString = talentExport() } end
    if selected.vault then snapshot.vault = vault() end
    if selected.currencyCaps then snapshot.currencyCaps = currencyCaps() end
    if selected.decorInventory then snapshot.decorInventory = ns.GetDecorInventory() end
    if selected.questLog then snapshot.questLog = questLog() end
    if selected.professionRecipes then snapshot.professionRecipes = ns.GetProfessionRecipes() end
    return snapshot
end

function ns.BuildCompleteSnapshot()
    local all = {}
    for _, category in ipairs(CATEGORY_ORDER) do all[category] = true end
    return ns.BuildSnapshot(all)
end

function ns.SelectSnapshot(snapshot, options)
    local selected = selectedOptions(options)
    local result = {
        format = snapshot.format,
        capturedAt = snapshot.capturedAt,
        character = snapshot.character,
        exportOptions = selected,
    }
    for _, category in ipairs(CATEGORY_ORDER) do
        if selected[category] then
            local field = CATEGORY_FIELDS[category]
            result[field] = snapshot[field]
        end
    end
    return result
end

local function countRecipes(professionRecipes)
    local total = 0
    for _, profession in ipairs((professionRecipes and professionRecipes.professions) or {}) do
        total = total + #(profession.recipes or {})
    end
    return total
end

function ns.FormatExportSummary(snapshot)
    local options = snapshot.exportOptions or {}
    local parts = {}
    local function add(label, enabled, count, unavailable)
        if not enabled then
            parts[#parts + 1] = label .. " omitted"
        elseif unavailable then
            parts[#parts + 1] = label .. " unavailable"
        else
            parts[#parts + 1] = label .. " " .. tostring(count or 0)
        end
    end
    add("equipped", options.equipment, #(snapshot.equipment or {}))
    add("bag items", options.bagItems, #(snapshot.bagEquipment or {}))
    add("talents", options.talents, snapshot.talents and snapshot.talents.importString and 1 or 0)
    add("Vault activities", options.vault, snapshot.vault and #(snapshot.vault.activities or {}) or 0)
    add("currency caps", options.currencyCaps, #(snapshot.currencyCaps or {}))
    local decor = snapshot.decorInventory
    add("decor", options.decorInventory, decor and #(decor.packedItems or decor.items or {}) or 0, decor and decor.available == false)
    local quests = snapshot.questLog
    add("quests", options.questLog, quests and #(quests.entries or {}) or 0, quests and quests.available == false)
    local recipes = snapshot.professionRecipes
    add("learned recipes", options.professionRecipes, countRecipes(recipes), recipes and recipes.available == false)
    return "exported — " .. table.concat(parts, "; ")
end

local function plain(value)
    if value == nil then return nil end
    local text = tostring(value)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[\r\n]+", " ")
    return text
end

local function linkName(link)
    return type(link) == "string" and link:match("%[([^%]]+)%]") or nil
end

local function itemString(link)
    return type(link) == "string" and link:match("H(item:[^|]+)|h") or nil
end

local function append(lines, value)
    lines[#lines + 1] = value
end

local function addValue(parts, label, value)
    if value ~= nil and value ~= "" then parts[#parts + 1] = label .. " " .. plain(value) end
end

local function itemLine(item, location)
    local parts = {}
    local name = item.name or linkName(item.link) or "Unknown item"
    addValue(parts, "item ID", item.itemID)
    addValue(parts, "item level", item.itemLevel or item.baseItemLevel)
    addValue(parts, "quantity", item.stackCount and item.stackCount > 1 and item.stackCount or nil)
    addValue(parts, "quality", item.quality)
    addValue(parts, "type", item.itemSubType or item.itemType)
    if item.isBound ~= nil then addValue(parts, "bound", item.isBound and "yes" or "no") end
    addValue(parts, "item string", itemString(item.link))
    return "- " .. plain(location) .. ": " .. plain(name)
        .. (#parts > 0 and " (" .. table.concat(parts, "; ") .. ")" or "")
end

local function categoryCount(snapshot, category)
    if category == "equipment" then return #(snapshot.equipment or {}) end
    if category == "bagItems" then return #(snapshot.bagEquipment or {}) end
    if category == "talents" then return snapshot.talents and snapshot.talents.importString and 1 or 0 end
    if category == "vault" then return snapshot.vault and #(snapshot.vault.activities or {}) or 0 end
    if category == "currencyCaps" then return #(snapshot.currencyCaps or {}) end
    if category == "decorInventory" then
        local decor = snapshot.decorInventory
        return decor and #(decor.packedItems or decor.items or {}) or 0
    end
    if category == "questLog" then return snapshot.questLog and #(snapshot.questLog.entries or {}) or 0 end
    if category == "professionRecipes" then return countRecipes(snapshot.professionRecipes) end
    return 0
end

local function categoryUnavailable(snapshot, category)
    local field = CATEGORY_FIELDS[category]
    local value = snapshot[field]
    if category == "talents" then return not (value and value.importString) end
    if category == "vault" then
        return not (value and (value.currentPeriod ~= nil or value.hasAvailableRewards ~= nil
            or value.hasGeneratedRewards ~= nil or value.dungeonRuns or #(value.activities or {}) > 0))
    end
    if category == "decorInventory" or category == "questLog" or category == "professionRecipes" then
        return value and value.available == false
    end
    return false
end

local function unavailableReason(snapshot, category)
    local value = snapshot[CATEGORY_FIELDS[category]]
    if value and value.reason then return plain(value.reason) end
    if category == "talents" then return "The active talent import string was not available from the client." end
    if category == "vault" then return "Great Vault data was not available from the client." end
    return "This category was unavailable when the report was captured."
end

local function boolText(value)
    if value == nil then return nil end
    return value and "yes" or "no"
end

local function capturedTime(value)
    if type(value) == "number" and type(date) == "function" then
        local ok, formatted = pcall(date, "%Y-%m-%d %H:%M:%S", value)
        if ok and type(formatted) == "string" and formatted ~= "" then
            return formatted .. " (local time; Unix " .. tostring(value) .. ")"
        end
    end
    return tostring(value or "unknown") .. " (Unix time)"
end

local function specialisationText(specID)
    if type(specID) == "number" and type(GetSpecializationInfoByID) == "function" then
        local ok, _, name = pcall(GetSpecializationInfoByID, specID)
        if ok and type(name) == "string" and name ~= "" then
            return plain(name) .. " (ID " .. tostring(specID) .. ")"
        end
    end
    return specID and ("ID " .. tostring(specID)) or "unknown"
end

local function reportSection(snapshot, category)
    local lines = { "## " .. CATEGORY_TITLES[category], "" }
    if categoryUnavailable(snapshot, category) then
        append(lines, "**Unavailable:** " .. unavailableReason(snapshot, category))
        return table.concat(lines, "\n")
    end

    if category == "equipment" then
        for _, item in ipairs(snapshot.equipment or {}) do
            append(lines, itemLine(item, item.slot or "Unknown slot"))
        end
    elseif category == "bagItems" then
        for _, item in ipairs(snapshot.bagEquipment or {}) do
            append(lines, itemLine(item, "Bag " .. tostring(item.bag or "?") .. ", slot " .. tostring(item.slot or "?")))
            if item.stats then
                local stats = {}
                for stat, amount in pairs(item.stats) do stats[#stats + 1] = plain(stat) .. " " .. tostring(amount) end
                table.sort(stats)
                if #stats > 0 then append(lines, "  - Stats: " .. table.concat(stats, "; ")) end
            end
            for _, gem in ipairs(item.gems or {}) do
                append(lines, "  - Gem " .. tostring(gem.socket or "?") .. ": "
                    .. plain(gem.name or linkName(gem.link) or "Unknown gem")
                    .. (gem.itemID and " (item ID " .. tostring(gem.itemID) .. ")" or ""))
            end
        end
    elseif category == "talents" then
        append(lines, "```text")
        append(lines, plain(snapshot.talents.importString))
        append(lines, "```")
    elseif category == "vault" then
        local value = snapshot.vault or {}
        append(lines, "- Current reward period: " .. tostring(boolText(value.currentPeriod) or "unknown"))
        append(lines, "- Rewards available: " .. tostring(boolText(value.hasAvailableRewards) or "unknown"))
        append(lines, "- Generated rewards: " .. tostring(boolText(value.hasGeneratedRewards) or "unknown"))
        if value.nextResetSeconds then append(lines, "- Seconds until reset: " .. tostring(value.nextResetSeconds)) end
        if value.dungeonRuns then
            append(lines, "- Dungeon runs: Heroic " .. tostring(value.dungeonRuns.heroic or 0)
                .. ", Mythic " .. tostring(value.dungeonRuns.mythic or 0)
                .. ", Mythic+ " .. tostring(value.dungeonRuns.mythicPlus or 0))
        end
        for _, activity in ipairs(value.activities or {}) do
            local parts = {}
            addValue(parts, "type", activity.type)
            addValue(parts, "index", activity.index)
            addValue(parts, "activity ID", activity.id)
            if activity.progress ~= nil or activity.threshold ~= nil then
                parts[#parts + 1] = "progress " .. tostring(activity.progress or "?") .. "/" .. tostring(activity.threshold or "?")
            end
            addValue(parts, "level", activity.level)
            addValue(parts, "tier ID", activity.activityTierID)
            addValue(parts, "raid", activity.raidString)
            append(lines, "- " .. table.concat(parts, "; "))
            for _, rewardInfo in ipairs(activity.rewards or {}) do
                local rewardParts = {}
                addValue(rewardParts, "type", rewardInfo.type)
                addValue(rewardParts, "ID", rewardInfo.id)
                addValue(rewardParts, "quantity", rewardInfo.quantity)
                addValue(rewardParts, "item", linkName(rewardInfo.link))
                addValue(rewardParts, "item string", itemString(rewardInfo.link))
                append(lines, "  - Reward: " .. table.concat(rewardParts, "; "))
            end
        end
    elseif category == "currencyCaps" then
        for _, currency in ipairs(snapshot.currencyCaps or {}) do
            local parts = {}
            addValue(parts, "currency ID", currency.currencyID)
            addValue(parts, "quantity", currency.quantity)
            addValue(parts, "weekly earned", currency.quantityEarnedThisWeek)
            addValue(parts, "weekly cap", currency.maxWeeklyQuantity)
            addValue(parts, "total earned", currency.totalEarned)
            addValue(parts, "maximum", currency.maxQuantity)
            addValue(parts, "account-wide", boolText(currency.isAccountWide))
            addValue(parts, "transferable", boolText(currency.isAccountTransferable))
            append(lines, "- " .. plain(currency.name or "Unknown currency") .. " (" .. table.concat(parts, "; ") .. ")")
        end
    elseif category == "decorInventory" then
        local decor = snapshot.decorInventory or {}
        if decor.totalOwnedCount ~= nil then append(lines, "- Total owned copies: " .. tostring(decor.totalOwnedCount)) end
        if decor.maxOwnedCount ~= nil then append(lines, "- Collection capacity: " .. tostring(decor.maxOwnedCount)) end
        if decor.truncated then append(lines, "- **Truncated:** yes") end
        for _, row in ipairs(decor.packedItems or {}) do
            local flags = tonumber(row[9]) or 0
            local properties = {}
            if flags % 2 >= 1 then properties[#properties + 1] = "unique trophy" end
            if flags % 4 >= 2 then properties[#properties + 1] = "indoors" end
            if flags % 8 >= 4 then properties[#properties + 1] = "outdoors" end
            append(lines, "- " .. plain(row[2] or "Unknown decor")
                .. " (record ID " .. tostring(row[1] or "unknown")
                .. (tonumber(row[3]) and row[3] > 0 and "; item ID " .. tostring(row[3]) or "")
                .. "): stored " .. tostring(row[5] or 0)
                .. ", placed " .. tostring(row[6] or 0)
                .. ", redeemable " .. tostring(row[7] or 0)
                .. ", destroyable " .. tostring(row[8] or 0)
                .. (#properties > 0 and "; " .. table.concat(properties, ", ") or ""))
        end
        for _, item in ipairs(decor.items or {}) do
            append(lines, "- " .. plain(item.name or "Unknown decor")
                .. " (record ID " .. tostring(item.recordID or "unknown")
                .. (item.itemID and "; item ID " .. tostring(item.itemID) or "") .. ")")
        end
    elseif category == "questLog" then
        local quests = snapshot.questLog or {}
        if quests.truncated then append(lines, "- **Truncated:** yes") end
        for _, quest in ipairs(quests.entries or {}) do
            local parts = { "quest ID " .. tostring(quest.questID or "unknown") }
            addValue(parts, "level", quest.level)
            addValue(parts, "tag", quest.tag and quest.tag.name)
            addValue(parts, "complete", boolText(quest.isComplete))
            addValue(parts, "failed", boolText(quest.isFailed))
            addValue(parts, "suggested group", quest.suggestedGroup and quest.suggestedGroup > 0 and quest.suggestedGroup or nil)
            append(lines, "- " .. plain(quest.title or "Unknown quest") .. " (" .. table.concat(parts, "; ") .. ")")
            for _, objective in ipairs(quest.objectives or {}) do
                append(lines, "  - " .. plain(objective.text or "Objective progress")
                    .. (objective.finished ~= nil and "; complete " .. boolText(objective.finished) or ""))
            end
            if quest.waypoint then
                append(lines, "  - Waypoint: map " .. tostring(quest.waypoint.mapID)
                    .. ", " .. tostring(quest.waypoint.x) .. ", " .. tostring(quest.waypoint.y))
            end
            if quest.timer then
                append(lines, "  - Timer: " .. tostring(quest.timer.elapsedSeconds or 0)
                    .. "/" .. tostring(quest.timer.totalSeconds or 0) .. " seconds")
            end
        end
    elseif category == "professionRecipes" then
        local professions = snapshot.professionRecipes or {}
        if professions.truncated then append(lines, "**Truncated:** yes") append(lines, "") end
        for _, profession in ipairs(professions.professions or {}) do
            local skill = profession.skillLevel and (" — skill " .. tostring(profession.skillLevel)
                .. (profession.maxSkillLevel and "/" .. tostring(profession.maxSkillLevel) or "")) or ""
            append(lines, "### " .. plain(profession.name or "Unknown profession") .. skill)
            append(lines, "")
            append(lines, "Skill line ID: " .. tostring(profession.skillLineID or "unknown"))
            append(lines, "")
            for _, recipe in ipairs(profession.recipes or {}) do
                append(lines, "- " .. plain(recipe.name or "Unknown recipe")
                    .. " (recipe ID " .. tostring(recipe.recipeID or "unknown") .. ")")
            end
            append(lines, "")
        end
    end

    if categoryCount(snapshot, category) == 0 and #lines == 2 then append(lines, "_No records captured._") end
    return table.concat(lines, "\n")
end

function ns.GetExportCategoryInfo(snapshot, category, includeCharacters)
    local options = snapshot.exportOptions or {}
    local enabled = options[category] ~= false
    local unavailable = enabled and categoryUnavailable(snapshot, category)
    local count = categoryCount(snapshot, category)
    local section = enabled and includeCharacters ~= false and reportSection(snapshot, category) or ""
    return {
        enabled = enabled,
        count = count,
        unavailable = unavailable,
        truncated = enabled and snapshot[CATEGORY_FIELDS[category]]
            and snapshot[CATEGORY_FIELDS[category]].truncated == true or false,
        characters = #section,
        title = CATEGORY_TITLES[category],
    }
end

function ns.BuildAIReport(snapshot)
    snapshot = snapshot or ns.BuildSnapshot()
    local characterData = snapshot.character or {}
    local characterLabel = plain(characterData.name or "Unknown") .. "-" .. plain(characterData.realm or "Unknown realm")
    local lines = { "# HammerLink character report — " .. characterLabel, "" }
    append(lines, "> Captured from World of Warcraft by HammerLink. Omitted, unavailable and unknown data are not evidence that a character has none.")
    append(lines, "")
    append(lines, "- Captured at: " .. capturedTime(snapshot.capturedAt))
    append(lines, "- Character: " .. characterLabel)
    append(lines, "- Class: " .. plain(characterData.class or "Unknown"))
    append(lines, "- Level: " .. tostring(characterData.level or "unknown"))
    append(lines, "- Specialisation: " .. specialisationText(characterData.specID))
    append(lines, "- Equipped item level: " .. tostring(characterData.equippedItemLevel or "unknown"))
    append(lines, "- Overall item level: " .. tostring(characterData.overallItemLevel or "unknown"))
    append(lines, "")
    append(lines, "## Export scope")
    append(lines, "")
    for _, category in ipairs(CATEGORY_ORDER) do
        local info = ns.GetExportCategoryInfo(snapshot, category, false)
        local state
        if not info.enabled then state = "omitted by export settings"
        elseif info.unavailable then state = "unavailable or unknown"
        else state = "included — " .. tostring(info.count) .. " records" end
        if info.truncated then state = state .. "; truncated" end
        append(lines, "- " .. info.title .. ": " .. state)
    end
    for _, category in ipairs(CATEGORY_ORDER) do
        if snapshot.exportOptions[category] ~= false then
            append(lines, "")
            append(lines, reportSection(snapshot, category))
        end
    end
    append(lines, "")
    append(lines, "---")
    append(lines, "Generated by HammerLink " .. tostring(ns.VERSION or "unknown") .. ". The addon did not upload this report.")
    return table.concat(lines, "\n")
end

function ns.BuildExport(snapshot)
    snapshot = snapshot or ns.BuildSnapshot()
    local json = encode(snapshot)
    local compressed = LibDeflate:CompressDeflate(json, { level = 9 })
    assert(compressed, "could not compress export")
    return ns.PREFIX .. LibDeflate:EncodeForPrint(compressed), #json, snapshot
end
