local namespace = {}

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
        return id == 2001 and "Bag Helm" or "Item", link, 4, 701, 80, "Armor", "Plate", 1, "INVTYPE_HEAD", 12345, 4, 4, 2, 10, 99, false
    end,
    GetDetailedItemLevelInfo = function(link) return link:find("2001", 1, true) and 710 or 700 end,
    GetItemStats = function(link) return link:find("2001", 1, true) and { ITEM_MOD_STRENGTH_SHORT = 123, ITEM_MOD_HASTE_RATING_SHORT = 456 } or {} end,
    GetItemGem = function(link, socket)
        if link:find("2001", 1, true) and socket == 1 then return "Test Gem", "|cff0070dd|Hitem:3001:0:0:0|h[Test Gem]|h|r" end
    end,
}

C_WeeklyRewards = nil

assert(loadfile("Export.lua"))("HammerLink", namespace)
local snapshot = namespace.BuildSnapshot()

assert(#snapshot.equipment == 1, "expected equipped item export to remain intact")
assert(#snapshot.bagEquipment == 2, "expected only equippable bag items")

local helm = snapshot.bagEquipment[1]
assert(helm.bag == 0 and helm.slot == 1 and helm.itemID == 2001, "expected bag location and item ID")
assert(helm.link == bagItems[0][1].hyperlink, "expected complete item link")
assert(helm.itemLevel == 710 and helm.baseItemLevel == 701, "expected effective and base item levels")
assert(helm.stats.ITEM_MOD_STRENGTH_SHORT == 123, "expected resolved item stats")
assert(helm.gems[1].itemID == 3001, "expected socketed gem details")
assert(helm.durability.current == 77 and helm.durability.maximum == 100, "expected durability")
assert(helm.equipmentSets == "Raid", "expected equipment-set membership")

local reagentBagWeapon = snapshot.bagEquipment[2]
assert(reagentBagWeapon.bag == 5 and reagentBagWeapon.itemID == 2003, "expected reagent bag scan")

print("HammerLink export tests passed")
