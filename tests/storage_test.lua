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
assert(gb.tabs[2].status == "partial" and gb.tabs[2].reason and gb.tabs[3].status == "not_viewable")
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

-- Retail opens guild-bank windows through the interaction manager. The first
-- tab can already be cached without another item-change event after opening.
event("BANKFRAME_CLOSED") event("GUILDBANKFRAME_CLOSED")
Enum.PlayerInteractionType = { GuildBanker = 10, Banker = 8 }
player, guild, currentTab, guildLoaded = "Retail-modern-guild", "Guild A", 1, true
canView[1] = true
event("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.GuildBanker)
assert(ns.StorageProgress.guildBank and ns.StorageProgress.guildBank.queued,
    "Retail interaction-manager guild open must queue its own initial scan")
drain()
assert(ns.GetStorage("guildBank").available and #ns.GetStorage("guildBank").entries == 1,
    "initial cached guild contents must be captured without an item-change event")
event("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.GuildBanker)
assert(not ns.StorageProgress.guildBank)
print("HammerLink Retail interaction-manager guild-bank regression passed")

local function stepTimers()
    local ready = timers timers = {}
    for _, fn in ipairs(ready) do fn() end
end
-- Identity, tab metadata and permissions can arrive after the open event.
player, guild = "Retail-late-guild-data", nil
local totalReady = false
function GetNumGuildBankTabs() return totalReady and 3 or 0 end
canView[1], canView[2] = false, false
event("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.GuildBanker)
stepTimers()
assert(ns.StorageProgress.guildBank.queued and not ns.GetStorage("guildBank").available)
guild = "Guild A"
stepTimers()
assert(ns.StorageProgress.guildBank.queued, "missing purchased-tab data should retry")
totalReady = true
stepTimers()
assert(ns.StorageProgress.guildBank.queued, "unready view permission should retry")
canView[1], canView[2] = true, true
drain()
assert(ns.GetStorage("guildBank").available, "late metadata must be captured without another item event")
-- The legacy event may follow the modern one for the same visit.
currentTab = 2
event("GUILDBANKBAGSLOTS_CHANGED") drain()
event("GUILDBANKFRAME_OPENED") drain()
assert(ns.GetStorage("guildBank").tabs[1].status == "observed", "duplicate open events must keep this visit's observed tabs")
event("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.Banker)
currentTab = 1
event("GUILDBANKBAGSLOTS_CHANGED") drain()
assert(not ns.StorageProgress.guildBank and ns.GetStorage("guildBank").available, "unrelated interaction hide cannot close a guild visit")
event("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.GuildBanker)
-- Cancel pending retries and multi-frame reads on close.
player, totalReady = "Retail-guild-close-before-ready", false
event("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.GuildBanker)
stepTimers()
event("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.GuildBanker)
drain()
assert(not ns.StorageProgress.guildBank and not ns.GetStorage("guildBank").available)
player, totalReady = "Retail-guild-close-during-read", true
event("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.GuildBanker)
stepTimers()
assert(ns.StorageProgress.guildBank.processed == 40)
event("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.GuildBanker)
drain()
assert(not ns.StorageProgress.guildBank and not ns.GetStorage("guildBank").available)
-- Exhausted retries stop progress; metadata events can start a fresh attempt.
player, totalReady = "Retail-guild-retry-bound", false
event("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.GuildBanker)
drain()
assert(not ns.StorageProgress.guildBank and not ns.GetStorage("guildBank").available, "unready guild data cannot wait indefinitely")
totalReady = true
event("GUILDBANK_UPDATE_TABS") drain()
assert(ns.GetStorage("guildBank").available, "metadata-only updates must recover the first observation")
event("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.GuildBanker)
-- Retain legacy client compatibility when the interaction enum isn't present.
Enum.PlayerInteractionType, forever, player = nil, true, "Forever-legacy-guild-open"
event("GUILDBANKFRAME_OPENED") drain()
assert(ns.GetStorage("guildBank").available, "Forever legacy open must capture initial contents too")
event("GUILDBANKFRAME_CLOSED")
print("HammerLink guild-open retries, duplicate events, cancellation and Forever compatibility passed")

-- Metadata and roster notifications must not starve an active item read or
-- recapture a tab that this visit has already observed.
Enum.PlayerInteractionType = { GuildBanker = 10, Banker = 8 }
forever, player, currentTab = false, "Retail-guild-roster-traffic", 1
event("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.GuildBanker)
stepTimers()
local reading = ns.StorageProgress.guildBank
assert(reading and reading.processed == 40)
for i = 1, 20 do event("GUILD_ROSTER_UPDATE") event("GUILDBANK_UPDATE_TABS") end
assert(ns.StorageProgress.guildBank == reading, "metadata notifications must not restart the active scan")
drain()
local captured = ns.GetStorage("guildBank").capturedAt
now = now + 10
event("GUILD_ROSTER_UPDATE") event("GUILDBANK_UPDATE_TABS") drain()
assert(ns.GetStorage("guildBank").capturedAt == captured, "metadata-only updates cannot invent a fresh item observation")
event("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.GuildBanker)
local notices = 0
local storageChanged = ns.StorageChanged
ns.StorageChanged = function() notices = notices + 1 end
event("GUILD_ROSTER_UPDATE")
assert(notices == 0, "roster updates away from the bank must not rebuild the chooser")
ns.StorageChanged = storageChanged
print("HammerLink guild metadata traffic and idle-chooser regressions passed")

-- Baganator's Everything view is game tab 1 while data for several tabs is
-- already readable. Export all viewable tabs without requiring UI selection.
event("GUILDBANKFRAME_CLOSED")
forever, player, guild, currentTab, totalReady = false, "Baganator-everything", "Guild A", 1, true
canView[1], canView[2], canView[3] = true, true, false
function GetGuildBankItemInfo(tab, slot)
    if slot == 1 then return 134400, tab+1, false, false, 2 end
end
function GetGuildBankItemLink(tab, slot)
    if slot == 1 then return "|Hitem:" .. (900+tab) .. "|h[Cached guild item]|h" end
end
event("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.GuildBanker)
drain()
local everything = ns.GetStorage("guildBank")
assert(#everything.entries == 2 and everything.entries[2].tab == 2,
    "Everything must include readable nonselected tabs without requiring another visit")

-- Selection changes do not invalidate explicit-index reads; queries are bounded.
event("GUILDBANKFRAME_CLOSED")
player, currentTab = "Combined-view-selection", 0
local queries = {}
function QueryGuildBankTab(tab) queries[tab] = (queries[tab] or 0) + 1 end
function SetCurrentGuildBankTab() error("collector must not change UI selection") end
event("GUILDBANKFRAME_OPENED") stepTimers()
currentTab = 3
drain()
assert(#ns.GetStorage("guildBank").entries == 2)
assert(queries[1] == 1 and queries[2] == 1 and not queries[3])
event("GUILDBANKBAGSLOTS_CHANGED") drain()
assert(queries[1] == 1 and queries[2] == 1)
-- Revocation during a yielded scan removes rows before committing.
event("GUILDBANKBAGSLOTS_CHANGED") stepTimers()
canView[1] = false
drain()
local revoked = ns.GetStorage("guildBank")
assert(revoked.tabs[1].status == "not_viewable" and #revoked.entries == 1 and revoked.entries[1].tab == 2)
canView[1] = true
-- Generic cage links gain pet identity from native tooltip data when available.
event("GUILDBANKFRAME_CLOSED")
player = "Guild-pet-tooltip"
function GetGuildBankItemLink(tab, slot)
    if slot == 1 then return "|Hitem:82800|h[Pet Cage]|h" end
end
C_TooltipInfo = { GetGuildBankItem = function(tab)
    return { battlePetSpeciesID = 123 + tab, battlePetLevel = 25, battlePetBreedQuality = 3 }
end }
C_PetJournal = { GetPetInfoBySpeciesID = function(species) return "Species " .. species end }
event("GUILDBANKFRAME_OPENED") drain()
local pet = ns.GetStorage("guildBank").entries[1]
assert(pet.itemID == 82800 and pet.battlePetSpeciesID == 124 and pet.name == "Species 124")
assert(pet.battlePetLevel == 25 and pet.battlePetBreedQuality == 3)
C_TooltipInfo.GetGuildBankItem = function() return { battlePetSpeciesID = 124, battlePetLevel = 0, battlePetBreedQuality = 99 } end
event("GUILDBANKBAGSLOTS_CHANGED") drain()
pet = ns.GetStorage("guildBank").entries[1]
assert(pet.battlePetSpeciesID == 124 and not pet.battlePetLevel and not pet.battlePetBreedQuality)
C_TooltipInfo.GetGuildBankItem = function() error("tooltip unavailable") end
event("GUILDBANKBAGSLOTS_CHANGED") drain()
assert(not ns.GetStorage("guildBank").entries[1].battlePetSpeciesID)
C_TooltipInfo, C_PetJournal = nil, nil
event("GUILDBANKBAGSLOTS_CHANGED") drain()
assert(ns.GetStorage("guildBank").entries[1].itemID == 82800)
-- All-nil tabs remain explicitly unknown; keep populated older observations.
now = now + 10
function GetGuildBankItemInfo() end
function GetGuildBankItemLink() end
event("GUILDBANKBAGSLOTS_CHANGED") drain()
local older = ns.GetStorage("guildBank")
assert(older.tabs[1].status == "cached" and #older.entries == 2 and older.tabs[1].reason)
event("GUILDBANKFRAME_CLOSED")
player = "Guild-empty-unknown"
event("GUILDBANKFRAME_OPENED") drain()
local empty = ns.GetStorage("guildBank")
assert(empty.tabs[1].status == "partial" and empty.tabs[1].reason and #empty.entries == 0)
now = now + 10
event("GUILDBANKBAGSLOTS_CHANGED") drain()
assert(ns.GetStorage("guildBank").tabs[1].capturedAt == now, "empty unknown reads must not retain old empty timestamps")
print("HammerLink combined guild views, bounded queries, permissions, pet tooltips and unknown-empty regressions passed")

-- Late identity must not reset query accounting after queries have been sent.
event("GUILDBANKFRAME_CLOSED")
player, guild = "Guild-late-query-identity", nil
queries = {}
event("GUILDBANKFRAME_OPENED") stepTimers()
guild = "Guild A"
stepTimers()
event("GUILDBANKBAGSLOTS_CHANGED")
drain()
assert(queries[1] == 1 and queries[2] == 1, "late guild identity must query each tab only once")
-- Item traffic cannot cancel a scan before it commits. Further events coalesce.
event("GUILDBANKFRAME_CLOSED")
player = "Guild-busy-bank"
event("GUILDBANKFRAME_OPENED") stepTimers()
for batch = 1, 5 do
    for update = 1, 10 do event("GUILDBANKBAGSLOTS_CHANGED") end
    stepTimers()
end
assert(ns.GetStorage("guildBank").available, "busy guild bank must commit the first scan")
drain()
assert(not ns.StorageProgress.guildBank, "coalesced follow-up scan must finish")
print("HammerLink late-identity query bounds and busy-bank scan completion passed")
