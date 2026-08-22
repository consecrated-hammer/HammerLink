local namespace = {}
local exportOptions = { equipment = true, bagItems = true, talents = true, vault = true, currencyCaps = true, decorInventory = true, questLog = true }
namespace.GetExportOptions = function() return exportOptions end
namespace.IsExportEnabled = function(category) return exportOptions[category] ~= false end
namespace.GetDecorInventory = function() return {
    available = true, truncated = false,
    packedItems = { { 77, "Warm Chair", 228000, 134400, 2, 1, 0, 2, 3 } },
} end

LibStub = function()
    return {
        CompressDeflate = function(_, value) return value end,
        EncodeForPrint = function(_, value) return value end,
    }
end

INVSLOT_HEAD = 1
INVSLOT_NECK = 2
INVSLOT_SHOULDER = 3
INVSLOT_BACK = 15
INVSLOT_CHEST = 5
INVSLOT_WRIST = 9
INVSLOT_HAND = 10
INVSLOT_WAIST = 6
INVSLOT_LEGS = 7
INVSLOT_FEET = 8
INVSLOT_FINGER1 = 11
INVSLOT_FINGER2 = 12
INVSLOT_TRINKET1 = 13
INVSLOT_TRINKET2 = 14
INVSLOT_MAINHAND = 16
INVSLOT_OFFHAND = 17
NUM_BAG_SLOTS = 4
Enum = { BagIndex = { Backpack = 0, ReagentBag = 5 } }

function UnitFullName() return "Bluehoof", "Dath'Remar" end
function UnitClass() return "Paladin", "PALADIN" end
function GetSpecialization() return nil end
function GetAverageItemLevel() return 700, 695, 700 end
function GetCurrentRegion() return 1 end
function UnitLevel() return 80 end
function time() return 1787200000 end
function GetRealmName() return "Dath'Remar" end
function GetInventoryItemLink(_, slot)
    if slot == INVSLOT_HEAD then return "|cff0070dd|Hitem:1001:0:0:0|h[Equipped Helm]|h|r" end
end

local bagItems = {
    [0] = {
        [1] = { itemID = 2001, hyperlink = "|cffa335ee|Hitem:2001:321:3001:0|h[Bag Helm]|h|r", itemName = "Bag Helm", quality = 4, iconFileID = 20, stackCount = 1, isBound = true },
        [2] = { itemID = 2002, hyperlink = "|cffffffff|Hitem:2002:0:0:0|h[Potion]|h|r", itemName = "Potion", quality = 1, iconFileID = 21, stackCount = 3, isBound = false },
    },
    [5] = {
        [1] = { itemID = 2003, hyperlink = "|cff0070dd|Hitem:2003:0:0:0|h[Reagent Bag Sword]|h|r", itemName = "Reagent Bag Sword", quality = 3, iconFileID = 22, stackCount = 1, isBound = false },
    },
}

C_Container = {
    GetContainerNumSlots = function(bag) return bagItems[bag] and 2 or 0 end,
    GetContainerItemInfo = function(bag, slot) return bagItems[bag] and bagItems[bag][slot] end,
    GetContainerItemLink = function(bag, slot) local item = bagItems[bag] and bagItems[bag][slot]; return item and item.hyperlink end,
    GetContainerItemDurability = function(bag, slot) if bag == 0 and slot == 1 then return 77, 100 end end,
    GetContainerItemEquipmentSetInfo = function(bag, slot) if bag == 0 and slot == 1 then return true, "Raid" end return false, "" end,
}

C_Item = {
    GetItemInfoInstant = function(link)
        local id = tonumber(link:match("item:(%d+)"))
        if id == 2002 then return id, "Consumable", "Potion", "", 21, 0, 1 end
        if id == 2003 then return id, "Weapon", "Sword", "INVTYPE_WEAPON", 22, 2, 7 end
        return id, "Armor", "Plate", "INVTYPE_HEAD", 20, 4, 4
    end,
    GetItemInfo = function(link)
        local id = tonumber(link:match("item:(%d+)"))
        if id == 2002 then
            return "Potion", link, 1, nil, nil, "Consumable", "Potion", 20, "", 21, 12, 0, 1, 0, 10, nil, "not-a-boolean"
        end
        return id == 2001 and "Bag Helm" or "Item", link, 4, 701, 80, "Armor", "Plate", 1, "INVTYPE_HEAD", 20, 12345, 4, 4, 2, 10, 99, false
    end,
    GetDetailedItemLevelInfo = function(link) return link:find("2001", 1, true) and 710 or 700 end,
    GetItemStats = function(link) return link:find("2001", 1, true) and { ITEM_MOD_STRENGTH_SHORT = 123, ITEM_MOD_HASTE_RATING_SHORT = 456 } or {} end,
    GetItemGem = function(link, socket)
        if link:find("2001", 1, true) and socket == 1 then return "Test Gem", "|cff0070dd|Hitem:3001:0:0:0|h[Test Gem]|h|r" end
    end,
}

C_WeeklyRewards = nil
C_QuestLog = {
    GetNumQuestLogEntries = function() return 3, 2 end,
    GetInfo = function(index)
        if index == 1 then return { isHeader = true, title = "Midnight" } end
        if index == 2 then return { questID = 9001, title = "A Dark Errand", level = 80, difficultyLevel = 80, suggestedGroup = 3, frequency = 1, campaignID = 12, questClassification = 2, isHeader = false, isTask = false, isBounty = false, isStory = true, isHidden = false, isAutoComplete = false } end
        return { questID = 9002, title = "Worldly Work", level = 80, difficultyLevel = 80, suggestedGroup = 0, frequency = 2, questClassification = 3, isHeader = false, isTask = true, isBounty = false, isStory = false, isHidden = true, isAutoComplete = true }
    end,
    IsComplete = function(questID) return questID == 9002 end,
    IsFailed = function() return false end,
    GetQuestWatchType = function(questID) return questID == 9001 and 1 or nil end,
    GetQuestObjectives = function(questID)
        if questID == 9001 then return { { text = "Collect 2/5 void shards", type = "item", finished = false, numFulfilled = 2, numRequired = 5, objectiveType = 1 } } end
        return {}
    end,
    GetQuestTagInfo = function(questID) if questID == 9002 then return { tagName = "World Quest", tagID = 128, worldQuestType = 1, quality = 2, isElite = false, displayExpiration = true } end end,
    GetNextWaypoint = function(questID) if questID == 9001 then return 2395, 0.42, 0.73 end end,
    GetTimeAllowed = function(questID) if questID == 9002 then return 3600, 1200 end end,
}
C_CurrencyInfo = {
    GetCurrencyListSize = function() return 2 end,
    GetCurrencyListInfo = function(index)
        if index == 1 then return { isHeader = true } end
        return { currencyID = 3284, isHeader = false }
    end,
    GetCurrencyInfo = function(currencyID)
        if currencyID == 3284 then
            return { name = "Gilded Crest", quantity = 42, maxQuantity = 90, maxWeeklyQuantity = 30, quantityEarnedThisWeek = 12, totalEarned = 312, canEarnPerWeek = true, useTotalEarnedForMaxQty = true, isAccountWide = false, isAccountTransferable = true }
        end
    end,
}

assert(loadfile("Export.lua"))("HammerLink", namespace)
local snapshot = namespace.BuildSnapshot()

assert(#snapshot.equipment == 1, "expected equipped item export to remain intact")
assert(#snapshot.bagEquipment == 3, "expected every occupied bag slot")

local helm = snapshot.bagEquipment[1]
assert(helm.bag == 0 and helm.slot == 1 and helm.itemID == 2001, "expected bag location and item ID")
assert(helm.link == bagItems[0][1].hyperlink, "expected complete item link")
assert(helm.itemLevel == 710 and helm.baseItemLevel == 701, "expected effective and base item levels")
assert(helm.stats.ITEM_MOD_STRENGTH_SHORT == 123, "expected resolved item stats")
assert(helm.gems[1].itemID == 3001, "expected socketed gem details")
assert(helm.durability.current == 77 and helm.durability.maximum == 100, "expected durability")
assert(helm.equipmentSets == "Raid", "expected equipment-set membership")
assert(helm.sellPrice == 12345 and helm.classID == 4 and helm.subclassID == 4, "expected item-info metadata in the correct return positions")
assert(helm.bindType == 2 and helm.expansionID == 10 and helm.setID == 99, "expected item-info binding and set metadata")
assert(helm.isCraftingReagent == false, "expected a boolean crafting-reagent flag to be retained")

local potion = snapshot.bagEquipment[2]
assert(potion.bag == 0 and potion.slot == 2 and potion.itemID == 2002, "expected non-equippable bag item scan")
assert(potion.stackCount == 3 and potion.inventoryType == nil, "expected item metadata for a consumable")
assert(potion.isCraftingReagent == nil, "expected non-boolean reagent flag to be omitted")
assert(potion.sellPrice == 12 and potion.classID == 0 and potion.subclassID == 1, "expected consumable metadata in the correct return positions")

local reagentBagWeapon = snapshot.bagEquipment[3]
assert(reagentBagWeapon.bag == 5 and reagentBagWeapon.itemID == 2003, "expected reagent bag scan")
assert(snapshot.format == 3 and snapshot.exportOptions.currencyCaps and snapshot.exportOptions.decorInventory, "expected enabled export options metadata")
assert(snapshot.decorInventory.available and snapshot.decorInventory.truncated == false, "expected complete housing inventory metadata")
assert(snapshot.decorInventory.packedItems[1][1] == 77 and snapshot.decorInventory.packedItems[1][2] == "Warm Chair", "expected compact housing row")
assert(snapshot.currencyCaps[1].currencyID == 3284 and snapshot.currencyCaps[1].quantityEarnedThisWeek == 12, "expected capped currency metadata")
assert(snapshot.exportOptions.questLog and snapshot.questLog.available and #snapshot.questLog.entries == 2, "expected current quest log")
assert(snapshot.questLog.totalQuests == 2, "expected quest count without header rows")
local quest = snapshot.questLog.entries[1]
assert(quest.questID == 9001 and quest.logIndex == 2 and quest.isComplete == false, "expected quest identity and completion")
assert(quest.objectives[1].numFulfilled == 2 and quest.objectives[1].numRequired == 5, "expected quest objective progress")
assert(quest.waypoint.mapID == 2395 and quest.waypoint.x == 0.42, "expected available quest waypoint")
assert(snapshot.questLog.entries[2].isHidden and snapshot.questLog.entries[2].timer.elapsedSeconds == 1200, "expected hidden quest and timer metadata")

exportOptions.bagItems = false
exportOptions.vault = false
exportOptions.questLog = false
local reducedSnapshot = namespace.BuildSnapshot()
assert(reducedSnapshot.bagEquipment == nil and reducedSnapshot.vault == nil and reducedSnapshot.questLog == nil, "expected disabled categories to be omitted")
assert(reducedSnapshot.exportOptions.bagItems == false and reducedSnapshot.exportOptions.vault == false and reducedSnapshot.exportOptions.questLog == false, "expected omitted categories to be explicit")

print("HammerLink export tests passed")
