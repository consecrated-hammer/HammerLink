local namespace = {}
local exportOptions = { equipment = true, bagItems = true, currentSpellbook = true, talents = true, vault = true, currencyCaps = true, currencies = true, reputations = true, decorInventory = true, questLog = true, professionRecipes = true }
namespace.GetExportOptions = function() return exportOptions end
namespace.IsExportEnabled = function(category) return exportOptions[category] ~= false end
namespace.GetDecorInventory = function() return {
    available = true, truncated = false,
    packedItems = { { 77, "Warm Chair", 228000, 134400, 2, 1, 0, 2, 3 } },
} end
namespace.GetProfessionRecipes = function() return {
    available = true, capturedAt = 1787200000, truncated = false,
    professions = { { skillLineID = 755, professionID = 755, name = "Classic Jewelcrafting", recipes = { { recipeID = 1261659, name = "Ironforge Chandelier", learned = true } } } },
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
Enum = {
    BagIndex = { Backpack = 0, ReagentBag = 5 },
    SpellBookSpellBank = { Player = 0 },
    SpellBookItemType = { Spell = 1, Flyout = 2 },
}
LOCALIZED_CLASS_NAMES_MALE = { SHAMAN = "Shaman" }

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
    GetItemStats = function(link) return link:find("2001", 1, true) and { ITEM_MOD_STRENGTH_SHORT = 123, ITEM_MOD_HASTE_RATING_SHORT = 456, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 51.730770111084 } or {} end,
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
        if questID == 9001 then return {
            { text = "", type = "item", finished = false, numFulfilled = 0, numRequired = 1, objectiveType = 1 },
            { text = "Collect 2/5 void shards", type = "item", finished = false, numFulfilled = 2, numRequired = 5, objectiveType = 1 },
        } end
        return {}
    end,
    GetQuestTagInfo = function(questID) if questID == 9002 then return { tagName = "World Quest", tagID = 128, worldQuestType = 1, quality = 2, isElite = false, displayExpiration = true } end end,
    GetNextWaypoint = function(questID) if questID == 9001 then return 2395, 0.42, 0.73 end end,
    GetTimeAllowed = function(questID) if questID == 9002 then return 3600, 1200 end end,
}
C_CurrencyInfo = {
    GetCurrencyListSize = function() return 3 end,
    GetCurrencyListInfo = function(index)
        if index == 1 then return { isHeader = true } end
        if index == 2 then return { currencyID = 3284, isHeader = false } end
        return { currencyID = 3000, isHeader = false }
    end,
    GetCurrencyInfo = function(currencyID)
        if currencyID == 3284 then
            return { name = "Gilded Crest", quantity = 42, maxQuantity = 90, maxWeeklyQuantity = 30, quantityEarnedThisWeek = 12, totalEarned = 52, canEarnPerWeek = true, useTotalEarnedForMaxQty = true, isAccountWide = false, isAccountTransferable = true }
        end
        if currencyID == 3000 then return { name = "Traveler's Coin", quantity = 17, iconFileID = 1, isAccountWide = true, isAccountTransferable = false } end
    end,
}
C_Reputation = {
    GetNumFactions = function() return 3 end,
    GetFactionDataByIndex = function(index)
        if index == 1 then return { isHeader = true, factionID = 1, name = "Header" } end
        if index == 2 then return { factionID = 2507, name = "Dornogal", reaction = 5, currentStanding = 6000, currentReactionThreshold = 3000, nextReactionThreshold = 9000, isWatched = true } end
        return { factionID = 2570, name = "Council of Dornogal", reaction = 8, currentStanding = 2500, currentReactionThreshold = 0, nextReactionThreshold = 2500, isWatched = false }
    end,
    IsMajorFaction = function(factionID) return factionID == 2570 end,
}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 2 end,
    GetSpellBookSkillLineInfo = function(index)
        if index == 1 then return { name = "Enhancement", itemIndexOffset = 0, numSpellBookItems = 2 } end
        return { name = "Shaman", itemIndexOffset = 2, numSpellBookItems = 1 }
    end,
    GetSpellBookItemInfo = function(index)
        if index == 1 then return { itemType = 1, spellID = 188389, name = "Flame Shock", isPassive = false } end
        if index == 2 then return { itemType = 2, actionID = 50 } end
        return { itemType = 1, spellID = 1230990, name = "Improved Stormstrike", isPassive = true }
    end,
}
C_Spell = { GetSpellName = function(spellID) if spellID == 57994 then return "Wind Shear" end end }
function GetFlyoutInfo() return "Shaman utility", nil, 2, true end
function GetFlyoutSlotInfo(_, slot)
    if slot == 1 then return 57994, 0, true, nil end
    return 99999, 0, false, "Unlearned Test"
end

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

bagItems[0][2].itemName = ""
local originalGetItemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(link)
    if link:find("2002", 1, true) then return "", link end
    return originalGetItemInfo(link)
end
local blankNameSnapshot = namespace.BuildSnapshot()
assert(blankNameSnapshot.bagEquipment[2].name == nil, "expected a blank optional bag name to be omitted")
bagItems[0][2].itemName = "Potion"
C_Item.GetItemInfo = originalGetItemInfo

local reagentBagWeapon = snapshot.bagEquipment[3]
assert(reagentBagWeapon.bag == 5 and reagentBagWeapon.itemID == 2003, "expected reagent bag scan")
assert(snapshot.format == 3 and snapshot.exportOptions.currencyCaps and snapshot.exportOptions.decorInventory, "expected enabled export options metadata")
assert(snapshot.decorInventory.available and snapshot.decorInventory.truncated == false, "expected complete housing inventory metadata")
assert(snapshot.decorInventory.packedItems[1][1] == 77 and snapshot.decorInventory.packedItems[1][2] == "Warm Chair", "expected compact housing row")
assert(snapshot.currencyCaps[1].currencyID == 3284 and snapshot.currencyCaps[1].quantityEarnedThisWeek == 12, "expected capped currency metadata")
assert(snapshot.currencies.available and #snapshot.currencies.entries == 2 and snapshot.currencies.entries[1].name == "Gilded Crest", "expected all visible current currencies")
assert(snapshot.reputations.available and #snapshot.reputations.entries == 2 and snapshot.reputations.entries[1].factionID == 2570 and snapshot.reputations.entries[1].isMajorFaction, "expected visible faction standings")
assert(snapshot.exportOptions.questLog and snapshot.questLog.available and #snapshot.questLog.entries == 2, "expected current quest log")
assert(snapshot.exportOptions.currentSpellbook and snapshot.currentSpellbook.available and #snapshot.currentSpellbook.spells == 3, "expected current spellbook export")
assert(snapshot.currentSpellbook.spells[1].name == "Flame Shock" and snapshot.currentSpellbook.spells[2].isPassive, "expected sorted spell identity and passive state")
assert(snapshot.exportOptions.professionRecipes and snapshot.professionRecipes.available, "expected learned profession recipe export")
assert(snapshot.professionRecipes.professions[1].recipes[1].recipeID == 1261659, "expected cached learned recipe")
local summary = namespace.FormatExportSummary(snapshot)
assert(summary:find("equipped 1", 1, true) and summary:find("bag items 3", 1, true), "expected chat export counts")
assert(summary:find("profession entries 1", 1, true), "expected profession entry count in chat summary")
assert(summary:find("current spells 3", 1, true), "expected current spell count in chat summary")
assert(snapshot.questLog.totalQuests == 2, "expected quest count without header rows")
local quest = snapshot.questLog.entries[1]
assert(quest.questID == 9001 and quest.logIndex == 2 and quest.isComplete == false, "expected quest identity and completion")
assert(quest.objectives[1].numFulfilled == 2 and quest.objectives[1].numRequired == 5, "expected quest objective progress")
assert(quest.waypoint.mapID == 2395 and quest.waypoint.x == 0.42, "expected available quest waypoint")
assert(snapshot.questLog.entries[2].isHidden and snapshot.questLog.entries[2].timer.elapsedSeconds == 1200, "expected hidden quest and timer metadata")

local completeSnapshot = namespace.BuildCompleteSnapshot()
completeSnapshot.character.class = "SHAMAN"
completeSnapshot.character.equippedItemLevel = 257.5
completeSnapshot.character.overallItemLevel = 265.6875
completeSnapshot.equipment[1].name = "Equipped Helm |A:Professions-ChatIcon-Quality-Tier5:17:15::1|a"
completeSnapshot.talents = { importString = "TEST-TALENT-STRING" }
completeSnapshot.vault = {
    currentPeriod = false, hasAvailableRewards = true, hasGeneratedRewards = false,
    activities = { {
        type = 6, index = 1, id = 207, progress = 1, threshold = 2,
        level = 0, activityTierID = 0,
        raidString = "Defeat %d Midnight |4Season 1 Boss:Season 1 Bosses",
        rewards = {},
    }, {
        type = 1, index = 1, id = 213, progress = 0, threshold = 1,
        level = 0, activityTierID = 0,
        raidString = "Defeat %d Midnight |4Boss:Bosses;",
        rewards = {},
    }, {
        type = 99, index = 1, id = 999, progress = 0,
        level = 0, activityTierID = 0,
        raidString = "Defeat %d future |4Boss:Bosses;",
        rewards = {},
    } },
}
local equipmentInfo = namespace.GetExportCategoryInfo(completeSnapshot, "equipment")
local bagInfo = namespace.GetExportCategoryInfo(completeSnapshot, "bagItems")
local recipeInfo = namespace.GetExportCategoryInfo(completeSnapshot, "professionRecipes")
local spellInfo = namespace.GetExportCategoryInfo(completeSnapshot, "currentSpellbook")
assert(equipmentInfo.count == 1 and bagInfo.count == 3 and recipeInfo.count == 1 and spellInfo.count == 3, "expected chooser category counts from the captured snapshot")
assert(equipmentInfo.characters > 0 and recipeInfo.characters > 0, "expected rendered section sizes for chooser warnings")

local aiReport = namespace.BuildAIReport(completeSnapshot)
assert(aiReport:find("# HammerLink character report — Bluehoof-Dath'Remar", 1, true), "expected character name and realm in the report heading")
assert(aiReport:find("Character: Bluehoof-Dath'Remar", 1, true), "expected character identity in report metadata")
assert(aiReport:find("Class: Shaman", 1, true), "expected a human-readable class name")
assert(aiReport:find("Equipped item level: 257.5", 1, true), "expected concise fractional equipped item level")
assert(aiReport:find("Overall item level: 265.69", 1, true), "expected overall item level rounded to two decimals")
assert(aiReport:find("Active talents: included — 1 record", 1, true), "expected singular report record wording")
assert(aiReport:find("Equipped Helm", 1, true) and aiReport:find("item ID 1001", 1, true), "expected readable equipped item identity")
assert(not aiReport:find("|A:", 1, true), "expected Blizzard atlas markup to be removed")
assert(aiReport:find("raid Defeat 2 Midnight Season 1 Bosses", 1, true), "expected Vault count and plural grammar to be resolved")
assert(aiReport:find("raid Defeat 1 Midnight Boss", 1, true), "expected singular Vault grammar to be resolved")
assert(aiReport:find("raid Defeat the required number of future Bosses", 1, true), "expected readable fallback when a Vault threshold is unavailable")
assert(not aiReport:find("%d", 1, true) and not aiReport:find("|4", 1, true), "expected no raw Blizzard grammar in the report")
assert(aiReport:find("Bag Helm", 1, true) and aiReport:find("ITEM_MOD_STRENGTH_SHORT 123", 1, true), "expected readable bag item details")
assert(aiReport:find("ITEM_MOD_DAMAGE_PER_SECOND_SHORT 51.73", 1, true) and not aiReport:find("51.730770111084", 1, true), "expected readable stat precision")
assert(aiReport:find("current amount 42", 1, true), "expected current currency balance to be explicit")
assert(aiReport:find("weekly cap progress 12/30", 1, true), "expected weekly currency cap progress")
assert(aiReport:find("season-cap progress 52/90", 1, true), "expected seasonal currency cap progress instead of ambiguous total-earned labels")
assert(not aiReport:find("total earned", 1, true), "expected ambiguous currency API labels to be omitted")
assert(aiReport:find("Traveler's Coin", 1, true) and aiReport:find("current amount 17", 1, true), "expected current-currency identity and wallet amount")
assert(aiReport:find("Dornogal", 1, true) and aiReport:find("faction ID 2507", 1, true), "expected visible reputation identity")
assert(aiReport:find("standing Friendly", 1, true) and aiReport:find("standing progress 3000/6000", 1, true), "expected readable within-tier reputation progress")
assert(aiReport:find("Warm Chair", 1, true) and aiReport:find("record ID 77", 1, true), "expected readable decor record")
assert(aiReport:find("A Dark Errand", 1, true) and aiReport:find("quest ID 9001", 1, true), "expected readable quest identity")
assert(aiReport:find("Ironforge Chandelier", 1, true) and aiReport:find("recipe ID 1261659", 1, true), "expected readable learned recipe identity")
assert(aiReport:find("Current spellbook: included — 3 records", 1, true), "expected current spellbook in report scope")
assert(aiReport:find("Wind Shear", 1, true) and aiReport:find("spell ID 57994", 1, true), "expected flyout spell identity in readable report")
assert(aiReport:find("Improved Stormstrike", 1, true) and aiReport:find("passive", 1, true), "expected passive spell state in readable report")
assert(aiReport:find("marked off-spec abilities", 1, true), "expected accurate spellbook scope wording")
assert(not aiReport:find("source spellbook", 1, true) and aiReport:find("flyout", 1, true), "expected only exceptional flyout provenance")
assert(aiReport:find("Cached positive observations", 1, true) and aiReport:find("Missing entries remain unknown", 1, true), "expected permanent profession completeness guidance")
assert(aiReport:find("Omitted, unavailable and unknown data are not evidence", 1, true), "expected conservative data-state guidance")

local vaultOnly = {
    equipment = false, bagItems = false, currentSpellbook = false, talents = false, vault = true,
    currencyCaps = false, currencies = false, reputations = false, decorInventory = false, questLog = false,
    professionRecipes = false,
}
C_WeeklyRewards = {
    AreRewardsForCurrentRewardPeriod = function() return false end,
    HasAvailableRewards = function() return false end,
    HasGeneratedRewards = function() return false end,
    GetActivities = function() return {} end,
}
local zeroVault = namespace.BuildSnapshot(vaultOnly)
assert(zeroVault.vault.currentPeriod == false and zeroVault.vault.hasAvailableRewards == false and zeroVault.vault.hasGeneratedRewards == false, "expected known false Vault state to survive capture")
assert(not namespace.GetExportCategoryInfo(zeroVault, "vault").unavailable, "expected zero-progress Vault data to remain available")
local zeroVaultReport = namespace.BuildAIReport(zeroVault)
assert(zeroVaultReport:find("Current reward period: no", 1, true), "expected known false Vault state in readable report")
assert(zeroVaultReport:find("Great Vault: included — 0 records", 1, true), "expected zero-progress Vault scope instead of unavailable")
C_WeeklyRewards = nil

exportOptions.bagItems = false
exportOptions.currentSpellbook = false
exportOptions.vault = false
exportOptions.currencies = false
exportOptions.reputations = false
exportOptions.questLog = false
exportOptions.professionRecipes = false
local reducedSnapshot = namespace.BuildSnapshot()
assert(reducedSnapshot.bagEquipment == nil and reducedSnapshot.currentSpellbook == nil and reducedSnapshot.vault == nil and reducedSnapshot.currencies == nil and reducedSnapshot.reputations == nil and reducedSnapshot.questLog == nil and reducedSnapshot.professionRecipes == nil, "expected disabled categories to be omitted")
assert(reducedSnapshot.exportOptions.bagItems == false and reducedSnapshot.exportOptions.vault == false and reducedSnapshot.exportOptions.currencies == false and reducedSnapshot.exportOptions.reputations == false and reducedSnapshot.exportOptions.questLog == false and reducedSnapshot.exportOptions.professionRecipes == false, "expected omitted categories to be explicit")
assert(namespace.FormatExportSummary(reducedSnapshot):find("bag items omitted", 1, true), "expected omitted category in chat summary")

local selectedSnapshot = namespace.SelectSnapshot(completeSnapshot, exportOptions)
assert(selectedSnapshot.bagEquipment == nil and selectedSnapshot.vault == nil, "expected chooser selection to remove omitted payload sections")
local reducedReport = namespace.BuildAIReport(selectedSnapshot)
assert(reducedReport:find("Bag items: omitted by export settings", 1, true), "expected omitted categories to remain explicit in readable report")
assert(not reducedReport:find("Bag Helm", 1, true), "expected omitted records to stay out of readable report")

local unknownRecipes = namespace.SelectSnapshot(completeSnapshot, exportOptions)
unknownRecipes.exportOptions.professionRecipes = true
unknownRecipes.professionRecipes = {
    available = false, professions = {},
    reason = "Open each profession window once; uncached professions are unknown.",
}
local unknownInfo = namespace.GetExportCategoryInfo(unknownRecipes, "professionRecipes")
local unknownReport = namespace.BuildAIReport(unknownRecipes)
assert(unknownInfo.unavailable and unknownInfo.count == 0, "expected unavailable recipe data instead of a false zero")
assert(unknownReport:find("Learned recipes and techniques: unavailable or unknown", 1, true), "expected unknown profession state in report scope")
assert(unknownReport:find("uncached professions are unknown", 1, true), "expected unavailable reason in readable report")

print("HammerLink export tests passed")
