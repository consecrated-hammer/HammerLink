local frames, timers = {}, {}
local now, player, forever, guild = 1000, "Player-A", false, "Guild A"
function time() return now end
function UnitGUID() return player end
function GetRealmName() return "Realm" end
function GetGuildInfo() return guild, "Member", 3, "Realm" end
function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(_, fn) self.callback = fn end
    frames[#frames + 1] = frame
    return frame
end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function drain()
    local rounds = 0
    while #timers > 0 do
        local pending = timers timers = {}
        for _, fn in ipairs(pending) do fn() end
        rounds = rounds + 1 assert(rounds < 1000, "scan must terminate")
    end
end
local function event(name, ...)
    for _, frame in ipairs(frames) do if frame.events[name] then frame.callback(frame, name, ...) end end
end
Enum = { BankType = { Character = 0, Account = 2 } }
local tabs = { [0] = { { ID = 6, name = "Personal" } }, [2] = { { ID = 12, name = "Shared" } } }
local use = { [0] = true, [2] = true }
local slots = { [6] = 3, [12] = 2 }
local contents = { [6] = { [1] = { itemID = 100, stackCount = 7, itemName = "Cloth", quality = 1 } },
    [12] = { [2] = { itemID = 200, stackCount = 3, hyperlink = "item:200" } } }
local failSlot = false
C_Bank = {
    CanUseBank = function(kind) return use[kind] end,
    FetchPurchasedBankTabData = function(kind) return tabs[kind] end,
}
C_Container = {
    GetContainerNumSlots = function(bag) return slots[bag] or 0 end,
    GetContainerItemInfo = function(bag, slot)
        if failSlot and bag == 6 and slot == 2 then error("slot unavailable") end
        return (contents[bag] or {})[slot]
    end,
}
C_Item = { GetItemInfo = function() return nil end }
local currentTab, canView, guildLoaded = 1, { true, true, false }, true
function GetNumGuildBankTabs() return 3 end
function GetCurrentGuildBankTab() return currentTab end
function GetGuildBankTabInfo(tab) return "Tab " .. tab, nil, canView[tab] end
function GetGuildBankItemInfo(tab, slot)
    if guildLoaded and tab == 1 and slot == 1 then return 134400, 8, false, false, 2 end
end
function GetGuildBankItemLink(tab, slot)
    if guildLoaded and tab == 1 and slot == 1 then return "|Hitem:300|h[Guild cloth]|h" end
end
function GetVoidItemInfo(tab, slot) if tab == 2 and slot == 80 then return 400 end end
local ns = { db = {}, IsForeverClient = function() return forever end }
assert(loadfile("Storage.lua"))("HammerLink", ns)
assert(ns.GetStorage("bank").available == false, "unopened bank stays unknown")
event("PLAYERBANKSLOTS_CHANGED") drain()
assert(not ns.GetStorage("bank").available, "bag updates away from a bank cannot create an empty observation")
local queuedNotifications = 0
ns.StorageChanged = function()
    local progress = ns.StorageProgress.bank
    if progress and progress.queued then queuedNotifications = queuedNotifications + 1 end
end
event("BANKFRAME_OPENED")
assert(ns.StorageProgress.bank.active and ns.StorageProgress.bank.queued and ns.StorageProgress.bank.processed == 0,
    "opening a bank reports queued progress before timers run")
assert(ns.StorageProgress.warbandBank.active and ns.StorageProgress.warbandBank.queued)
event("PLAYERBANKSLOTS_CHANGED")
assert(ns.StorageProgress.bank.queued and queuedNotifications == 2,
    "updates while debounce is pending keep the chooser notified and busy")
drain()
local bank, warband = ns.GetStorage("bank"), ns.GetStorage("warbandBank")
assert(bank.available and not bank.partial and #bank.entries == 1)
assert(bank.entries[1].itemID == 100 and bank.entries[1].stackCount == 7 and bank.entries[1].bag == 6)
assert(warband.scope == "account_bank" and warband.entries[1].itemID == 200)
assert(bank.capturedAt == 1000 and bank.cached and bank.absenceMeans == "unknown")
contents[6][1].stackCount, now = 9, 1100
event("PLAYERBANKSLOTS_CHANGED") drain()
assert(bank.entries[1].stackCount == 7, "existing export is immutable when the saved cache refreshes")
assert(ns.GetStorage("bank").entries[1].stackCount == 9)
failSlot = true
event("PLAYERBANKSLOTS_CHANGED") drain()
assert(ns.GetStorage("bank").partial and ns.GetStorage("bank").tabs[1].status == "cached", "API errors retain the previous tab with explicit cached status")
failSlot, slots[12] = false, 0
event("PLAYERBANKSLOTS_CHANGED") drain()
assert(ns.GetStorage("warbandBank").entries[1].itemID == 200 and ns.GetStorage("warbandBank").capturedAt == 1100, "unloaded tabs preserve the previous observation")
slots[12] = 2
use[2] = false
now = 1200
event("PLAYERBANKSLOTS_CHANGED") drain()
assert(ns.GetStorage("warbandBank").capturedAt == 1100, "locked account bank keeps its dated observation")
event("BANKFRAME_CLOSED")
contents[6] = {}
event("PLAYERBANKSLOTS_CHANGED") drain()
assert(ns.GetStorage("bank").entries[1].stackCount == 9, "bank close must preserve its observation")
player = "Player-B"
assert(not ns.GetStorage("bank").available and not ns.GetStorage("warbandBank").available, "no cache leaks across characters")
player, forever = "Player-A", true
assert(not ns.GetStorage("bank").available, "Forever and Retail caches stay separate")
-- Forever's purchased bank bags may have a different count and capacity.
tabs[0] = { { ID = 20, name = "Forever bag" }, { ID = 21, name = "Another bag" } }
slots[20], slots[21] = 24, 30
contents[20] = { [24] = { itemID = 500, stackCount = 2 } }
event("BANKFRAME_OPENED") drain()
assert(ns.GetStorage("bank").entries[1].bag == 20 and #ns.GetStorage("bank").tabs == 2)
forever = false
assert(ns.GetStorage("bank").entries[1].itemID == 100)
event("BANKFRAME_CLOSED")

event("GUILDBANKFRAME_OPENED")
assert(not ns.GetStorage("guildBank").available, "opening a guild bank is not proof of loaded contents")
event("GUILDBANKBAGSLOTS_CHANGED") drain()
local gb = ns.GetStorage("guildBank")
assert(gb.available and gb.partial and #gb.entries == 1 and gb.entries[1].stackCount == 8)
assert(gb.tabs[2].status == "unobserved" and gb.tabs[3].status == "not_viewable")
currentTab = 2
event("GUILDBANKBAGSLOTS_CHANGED") drain()
gb = ns.GetStorage("guildBank")
assert(gb.tabs[2].status == "partial" and #gb.entries == 1, "empty guild reads remain unknown without a loaded acknowledgement")
canView[1] = false
event("GUILDBANK_UPDATE_TABS")
gb = ns.GetStorage("guildBank")
assert(#gb.entries == 0 and gb.tabs[1].status == "not_viewable", "revoked tab visibility removes cached items")
guild = "Guild B"
assert(not ns.GetStorage("guildBank").available, "guild changes must not export the old guild inventory")
guild = nil
assert(not ns.GetStorage("guildBank").available, "unguilded characters cannot export old guild storage")
guild = "Guild A"
event("GUILDBANKFRAME_CLOSED")
event("VOID_STORAGE_OPEN")
assert(not ns.GetStorage("voidStorage").available)
event("VOID_STORAGE_CONTENTS_UPDATE") drain()
local void = ns.GetStorage("voidStorage")
assert(void.available and #void.entries == 1 and void.entries[1].tab == 2 and void.entries[1].slot == 80)
event("VOID_STORAGE_CLOSE")
-- A scheduled bank read must not run after the bank closes.
player = "Player-C"
event("BANKFRAME_OPENED")
assert(ns.StorageProgress.bank.queued, "a pending read remains busy")
event("BANKFRAME_CLOSED")
assert(not ns.StorageProgress.bank and not ns.StorageProgress.warbandBank, "closing clears queued progress immediately")
drain()
assert(not ns.StorageProgress.bank and not ns.StorageProgress.warbandBank, "closed-bank timers cannot leave progress active")
assert(not ns.GetStorage("bank").available)
-- Original bank API fallback uses the client's equipped-bag count.
C_Bank = nil
NUM_BAG_SLOTS, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4, nil
function GetNumBankSlots() return 1 end
slots[-1], slots[5] = 28, 16
contents[5] = { [16] = { itemID = 600 } }
event("BANKFRAME_OPENED") drain()
local legacy = ns.GetStorage("bank")
assert(legacy.available and not legacy.partial and legacy.entries[1].bag == 5)
print("HammerLink storage tests passed (Retail, Forever, legacy banks, permissions, cache isolation and readiness)")

-- Large Forever bags yield between bounded batches and commit atomically.
event("BANKFRAME_CLOSED")
forever, player = true, "Large-bank-character"
C_Bank = { CanUseBank = function() return true end, FetchPurchasedBankTabData = function(kind) return tabs[kind] end }
local before = ns.GetStorage("bank")
event("BANKFRAME_OPENED")
local callbacks = timers timers = {}
for _, fn in ipairs(callbacks) do fn() end
assert(ns.StorageProgress.bank and ns.StorageProgress.bank.processed == 40, "large banks must yield after a bounded batch")
assert(not ns.GetStorage("bank").available, "unfinished scans must not publish a partial snapshot")
drain()
assert(not ns.StorageProgress.bank and ns.GetStorage("bank").available, "finishing a scan clears progress and commits")
event("BANKFRAME_CLOSED")
-- Guild metadata refresh alone must not erase saved item observations.
forever, player, guild = false, "Player-A", "Guild A"
canView[1], currentTab = true, 1
event("GUILDBANKFRAME_OPENED") event("GUILDBANKBAGSLOTS_CHANGED") drain()
local oldGuild = ns.GetStorage("guildBank")
event("GUILDBANKFRAME_CLOSED") event("GUILDBANKFRAME_OPENED") event("GUILDBANK_UPDATE_TABS")
assert(ns.GetStorage("guildBank").entries[1].itemID == oldGuild.entries[1].itemID)
-- Preserve battle-pet identity even without a normal item link.
function GetGuildBankItemLink(tab, slot) if tab == 1 and slot == 1 then return "|Hbattlepet:123:25:3:1:2:3|h[Caged pet]|h" end end
event("GUILDBANKBAGSLOTS_CHANGED") drain()
assert(ns.GetStorage("guildBank").entries[1].battlePetSpeciesID == 123)
print("HammerLink batched collection, saved observations and battle-pet tests passed")

-- Keep older per-tab observations when another tab can refresh.
event("GUILDBANKFRAME_CLOSED") event("BANKFRAME_CLOSED")
forever, player = false, "Multi-tab-bank"
tabs[0] = { { ID = 20 }, { ID = 21 } }
contents[20], contents[21] = { [1] = { itemID = 800, stackCount = 1 } }, { [1] = { itemID = 801, stackCount = 4 } }
event("BANKFRAME_OPENED") drain()
local firstStamp = ns.GetStorage("bank").tabs[2].capturedAt
slots[21], now = 0, now+10
event("PLAYERBANKSLOTS_CHANGED") drain()
local retained = ns.GetStorage("bank")
assert(#retained.entries == 2 and retained.tabs[2].status == "cached" and retained.tabs[2].capturedAt == firstStamp)
assert(retained.partial, "mixed-age tab observations remain explicitly partial")
-- Unrelated backpack activity must not cancel an in-flight bank scan.
slots[21] = 200
event("PLAYERBANKSLOTS_CHANGED")
local batch = timers timers = {}
for _, fn in ipairs(batch) do fn() end
local progress = ns.StorageProgress.bank
assert(progress and progress.processed == 40)
event("BAG_CONTAINER_UPDATE", 0)
assert(ns.StorageProgress.bank == progress)
drain()
assert(ns.GetStorage("bank").tabs[2].status == "observed")
print("HammerLink mixed-age tabs and unrelated bag-update regressions passed")
