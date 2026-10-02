local namespace = {}
local exportOptions = { equipment = true, bagItems = true, currentSpellbook = true, talents = true, vault = true, currencyCaps = true, currencies = true, reputations = true, decorInventory = true, questLog = true, professionRecipes = true }
namespace.GetExportOptions = function() return exportOptions end
namespace.IsExportEnabled = function(category) return exportOptions[category] ~= false end
namespace.IsExportSupported = function(category)
    local _, _, _, tocVersion = GetBuildInfo()
    return tocVersion ~= 16001 or (category ~= "vault" and category ~= "decorInventory"
        and category ~= "currencyCaps" and category ~= "currencies")
end
namespace.IsForeverClient = function()
    local _, _, _, tocVersion = GetBuildInfo()
    return tocVersion == 16001
end
namespace.GetDecorInventory = function() return {
    available = true, truncated = false,
    packedItems = { { 77, "Warm Chair", 228000, 134400, 2, 1, 0, 2, 3 } },
} end
namespace.GetProfessionRecipes = function() return {
    available = true, capturedAt = 1787200000, truncated = false,
    professions = { { skillLineID = 755, professionID = 755, name = "Classic Jewelcrafting", recipes = { { recipeID = 1261659, name = "Ironforge Chandelier", learned = true } } } },
} end

namespace.LibDeflate = (function()
    return {
        CompressDeflate = function(_, value) return value end,
        EncodeForPrint = function(_, value) return value end,
    }
end)()

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
WOW_PROJECT_ID = 1
function GetBuildInfo() return "12.1.0", "69893", "September 18 2026", 120100 end
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
assert(namespace.BuildSnapshot().achievements == nil, "achievements must remain opt-in")
local snapshot = namespace.BuildSnapshot()
assert(snapshot.client.projectID == 1 and snapshot.client.tocVersion == 120100,
    "expected client project and TOC provenance")
assert(snapshot.client.version == "12.1.0" and snapshot.client.build == "69893",
    "expected client version and build provenance")

local savedGetSpecialization = GetSpecialization
local savedGetAverageItemLevel = GetAverageItemLevel
local savedGetBuildInfo = GetBuildInfo
GetSpecialization = nil
GetAverageItemLevel = nil
GetBuildInfo = function() return "1.60.1", "69893", "September 18 2026", 16001 end
local foreverSnapshot = namespace.BuildSnapshot()
assert(foreverSnapshot.character.specID == nil, "expected missing Forever specialization API to be omitted")
assert(foreverSnapshot.character.equippedItemLevel == nil and foreverSnapshot.character.overallItemLevel == nil,
    "expected missing Forever item-level API to be omitted")
assert(foreverSnapshot.client.tocVersion == 16001, "expected Forever client provenance")
assert(foreverSnapshot.vault == nil and foreverSnapshot.decorInventory == nil
    and foreverSnapshot.currencyCaps == nil and foreverSnapshot.currencies == nil,
    "expected Forever-only systems to be omitted")
assert(foreverSnapshot.talents == nil, "expected unavailable Forever talents to be omitted instead of encoded as an empty array")
local foreverReport = namespace.BuildAIReport(foreverSnapshot)
assert(not foreverReport:find("Great Vault", 1, true) and not foreverReport:find("Housing decor", 1, true)
    and not foreverReport:find("Currency caps", 1, true) and not foreverReport:find("Current currencies", 1, true),
    "expected unsupported Forever categories to be absent from the report")
assert(not foreverReport:find("Equipped item level", 1, true) and not foreverReport:find("Overall item level", 1, true),
    "expected placeholder Forever item levels to be absent from the report")
GetSpecialization = savedGetSpecialization
GetAverageItemLevel = savedGetAverageItemLevel
GetBuildInfo = savedGetBuildInfo

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
assert(aiReport:find("abilities beyond those currently usable", 1, true), "expected client-neutral spellbook scope wording")
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

-- Exercise the optional collector through both serialization paths.
function CreateFrame() return { RegisterEvent = function() end, SetScript = function() end } end
namespace.db = { achievementOptions = { scope = "dungeons" } }
namespace.PREFIX = "HL1:"
function GetCategoryList() return { 168, 900 } end
function GetCategoryInfo(id) if id == 168 then return "Dungeons & Raids", -1 end return "Test raids", 168 end
function GetCategoryNumAchievements(id) return id == 900 and 1 or 0 end
function GetAchievementInfo(id, index)
    if index then id = 12345 end
    return id, "Unfinished test raid", 10, false, nil, nil, nil, "Fixture", 131072, 1, "", false, false
end
function GetAchievementCategory() return 900 end
function GetAchievementNumCriteria() return 1 end
function GetAchievementCriteriaInfo() return "Missing boss", 0, false, 0, 1, nil, 0, 55, "0/1", 789 end
assert(loadfile("Achievements.lua"))("HammerLink", namespace)
exportOptions.achievements = true
local achievementSnapshot = namespace.BuildSnapshot()
assert(achievementSnapshot.format == 3 and achievementSnapshot.exportOptions.achievements == true)
local achievementCode = namespace.BuildExport(achievementSnapshot)
assert(achievementCode:find('"completed":false', 1, true) and achievementCode:find('"current":0', 1, true))
assert(achievementCode:find('"criteriaID":789', 1, true) and achievementCode:find('"categoryID":900', 1, true))
local achievementReport = namespace.BuildAIReport(achievementSnapshot)
assert(achievementReport:find("## Achievements", 1, true) and achievementReport:find("HammerLink format version: 3", 1, true))
assert(achievementReport:find("**incomplete**", 1, true))
assert(namespace.GetExportCategoryInfo(achievementSnapshot, "achievements").count == 1)
local renderAchievements, renders = namespace.AchievementReport, 0
namespace.AchievementReport = function(value) renders = renders + 1 return renderAchievements(value) end
local cachedSnapshot = namespace.SelectSnapshot(achievementSnapshot, { achievements = true })
cachedSnapshot.achievements = namespace.GetAchievements()
namespace.GetExportCategoryInfo(cachedSnapshot, "achievements")
namespace.GetExportCategoryInfo(cachedSnapshot, "achievements")
assert(namespace.BuildAIReport(cachedSnapshot):find("Unfinished test raid", 1, true))
assert(renders == 1, "chooser refreshes and Generate must reuse the rendered achievement section")
namespace.AchievementReport = renderAchievements

exportOptions.achievements = false
assert(namespace.SelectSnapshot(achievementSnapshot).achievements == nil)
assert(namespace.BuildCompleteSnapshot().achievements == nil, "chooser's general scan must not collect achievements")

local largeSnapshot = namespace.SelectSnapshot(achievementSnapshot, { achievements = true })
largeSnapshot.achievements = namespace.GetAchievements()
largeSnapshot.achievements.entries = {}
for id = 1, 5 do
    largeSnapshot.achievements.entries[id] = { achievementID = id, name = string.rep("x", 200000),
        completionState = "incomplete", completed = false, criteria = {} }
end
namespace.SummarizeAchievements(largeSnapshot.achievements)
local fullCode, fullBytes, fullSnapshot = namespace.BuildExport(largeSnapshot)
assert(fullBytes > 262144 and #fullCode > 262144)
assert(#fullSnapshot.achievements.entries == 5 and not fullSnapshot.achievements.truncated,
    "captures above the old printable limit must retain all records")
for _, entry in ipairs(largeSnapshot.achievements.entries) do
    entry.name = string.rep("x", 1024 * 1024)
end
local limitedCode, _, limitedSnapshot = namespace.BuildExport(largeSnapshot)
assert(#limitedCode - 4 <= 4 * 1024 * 1024 and limitedSnapshot.achievements.truncated)
assert(limitedSnapshot.achievements.summary.omittedForPayloadSize == 2 and limitedSnapshot.achievements.summary.exported == 3)
assert(#largeSnapshot.achievements.entries == 5 and not largeSnapshot.achievements.truncated,
    "size trimming must not mutate a captured snapshot")
local tooLarge = { format = 3, character = { name = string.rep("x", 32 * 1024 * 1024 + 1) } }
assert(not pcall(namespace.BuildExport, tooLarge), "oversized non-achievement data must fail clearly")

-- Use the shipped compressor for a real HL1 round trip. Optionally keep a
-- fixture artifact for the existing importer to decode outside this harness.
LibStub = nil
strmatch = string.match
assert(loadfile("Libs/LibStub/LibStub.lua"))()
namespace.LibDeflate = assert(loadfile("Libs/LibDeflate/LibDeflate.lua"))()
assert(loadfile("Export.lua"))("HammerLink", namespace)
local realCode = namespace.BuildExport(achievementSnapshot)
local lib = namespace.LibDeflate
local roundTrip = lib:DecompressDeflate(lib:DecodeForPrint(realCode:sub(5)))
assert(roundTrip:find('"completed":false', 1, true) and roundTrip:find('"criteriaID":789', 1, true))
local artifact = os.getenv("HL_TEST_ARTIFACT")
if artifact then
    local codeFile = assert(io.open(artifact .. ".hl1", "w")) codeFile:write(realCode) codeFile:close()
    local reportFile = assert(io.open(artifact .. ".md", "w")) reportFile:write(achievementReport) reportFile:close()
end
-- Force checkpoints on every clock read to exercise Lua 5.1 yields inside
-- JSON escaping, LZ77 searches, block cleanup and printable encoding.
local jobs, clockTick = {}, 0
C_Timer = { After = function(_, job) jobs[#jobs + 1] = job end }
debugprofilestop = function() clockTick = clockTick + 5 return clockTick end
local function drain()
    local count = 0
    while #jobs > 0 do
        table.remove(jobs, 1)()
        count = count + 1
    end
    return count
end
local large = { format = 3, character = { name = "Checkpoint test" }, entries = {} }
for i = 1, 120 do
    large.entries[i] = { id = i, completed = false, quantity = 0,
        description = string.rep('quotes " slash \\ newline \n café ' .. tostring(i), 600) }
end
local expected = namespace.BuildExport(large)
local completed
local phases, advanced = {}, false
namespace.BuildExportAsync(large, function(code, bytes, exported, err)
    assert(not err and exported == large and bytes > 1024 * 1024)
    completed = code
end, function(phase, position, total)
    phases[phase] = true
    if phase == "compressing" and position > 0 and total > position then advanced = true end
end)
assert(not completed, "generation must start on a later timer")
assert(drain() > 100, "large generation must yield repeatedly")
assert(phases.serializing and phases.compressing and phases.encoding and advanced, "progress must cover all phases and advancing input")
assert(completed == expected, "yielding must preserve the exact synchronous HL1 stream")
assert(lib:DecompressDeflate(lib:DecodeForPrint(completed:sub(5))) ==
    lib:DecompressDeflate(lib:DecodeForPrint(expected:sub(5))))

-- A cached or reset profiling clock must still allow bounded cooperative work.
debugprofilestop = function() return 0 end
completed = nil
namespace.BuildExportAsync(large, function(code, _, _, err) assert(not err) completed = code end)
assert(drain() > 1 and completed == expected, "a flat profiling clock must not prevent yields or completion")
debugprofilestop = function() clockTick = clockTick + 5 return clockTick end
local called = false
local cancel = namespace.BuildExportAsync(large, function() called = true end)
cancel()
drain()
assert(not called, "cancel before start must discard the result")
cancel = namespace.BuildExportAsync(large, function() called = true end)
table.remove(jobs, 1)()
assert(#jobs == 1, "first resume must schedule another frame")
cancel()
drain()
assert(not called, "cancel during compression must discard the result")

local compress = lib.CompressDeflate
lib.CompressDeflate = function() error("compressor test failure") end
local failure
namespace.BuildExportAsync(large, function(code, _, _, err) assert(not code) failure = err end)
drain()
lib.CompressDeflate = compress
assert(failure and failure:find("compressor test failure", 1, true), "resume errors must reach the UI")
lib.CompressDeflate = function() error(nil) end
failure = nil
namespace.BuildExportAsync({ character = { name = "Error test" } }, function(_, _, _, err) failure = err end)
drain()
lib.CompressDeflate = compress
assert(type(failure) == "string", "nil-valued errors must still be reported as failures")

local captured = { character = { name = "Stable selection" }, exportOptions = { achievements = true },
    achievements = achievementSnapshot.achievements }
local chosen = namespace.SelectSnapshot(captured, { achievements = true })
local chosenExpected = namespace.BuildExport(chosen)
completed = nil
namespace.BuildExportAsync(chosen, function(code, _, _, err) assert(not err) completed = code end)
captured.achievements = nil
captured.exportOptions.achievements = false
drain()
assert(completed == chosenExpected, "replacing the chooser capture must not change an unfinished export")
assert(not LibStub:GetLibrary("LibDeflate", true), "private compressor must not register the shared library")
local shared = LibStub:NewLibrary("LibDeflate", 999)
shared.marker = "another addon"
local isolated = {}
assert(loadfile("Libs/LibDeflate/LibDeflate.lua"))("HammerLink", isolated)
assert(isolated.LibDeflate ~= shared and LibStub("LibDeflate").marker == "another addon",
    "a shared library loaded by another addon must remain independent")
assert(isolated.LibDeflate:CompressDeflate("wire test", { level = 9 }) == lib:CompressDeflate("wire test", { level = 9 }))
print("HammerLink export tests passed")
