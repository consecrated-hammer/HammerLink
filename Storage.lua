local _, ns = ...

-- Persist observations per character and client. Even account storage is kept
-- as this character's observation, never an authoritative cross-character total.
local scopes = { bank = "character_bank", warbandBank = "account_bank", guildBank = "guild_bank", voidStorage = "character_void_storage" }
local open = {}
local pending = false
local jobs = {}
ns.StorageProgress = {}
local function notify(category, updated)
    if ns.StorageChanged then ns.StorageChanged(category, updated) end
end
local function cancel(category)
    jobs[category] = nil
    ns.StorageProgress[category] = nil
end
local function checkpoint(category)
    local job = jobs[category]
    if not job then return end
    job.processed = job.processed + 1
    ns.StorageProgress[category] = { active = true, processed = job.processed }
    if job.processed % 40 == 0 and C_Timer and C_Timer.After then
        notify()
        coroutine.yield()
    end
end
local function startJob(category, collect, guard, complete)
    local job = { processed = 0 }
    jobs[category] = job
    ns.StorageProgress[category] = { active = true, processed = 0 }
    local thread = coroutine.create(collect)
    local function resume()
        if jobs[category] ~= job then return end
        if not guard() then cancel(category) notify() return end
        local ok, err = coroutine.resume(thread)
        if not ok or coroutine.status(thread) == "dead" then
            cancel(category)
            if not ok and ns.Print then ns.Print("Storage scan stopped: " .. tostring(err)) end
            notify(category, ok)
            if complete then complete(ok) end
        else
            C_Timer.After(0, resume)
        end
    end
    notify()
    resume()
end
local function call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end
local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = clone(item) end
    return result
end
local function identity()
    local ok, guid = call(UnitGUID, "player")
    if not ok or not guid then
        local name, realm
        ok, name, realm = call(UnitFullName, "player")
        if not ok or not name then return nil end
        local _, fallback = call(GetRealmName)
        guid = name .. "@" .. (realm or fallback or "unknown")
    end
    return (ns.IsForeverClient() and "forever:" or "retail:") .. guid
end
local function guildIdentity()
    local ok, name, _, _, realm = call(GetGuildInfo, "player")
    if not ok or not name then return nil end
    local _, fallback = call(GetRealmName)
    return name .. "@" .. (realm or fallback or "unknown"), name
end
local function cache(create)
    local key = identity()
    if not key or not ns.db then return nil end
    if not ns.db.storageByCharacter then
        if not create then return nil end
        ns.db.storageByCharacter = {}
    end
    if not ns.db.storageByCharacter[key] and create then ns.db.storageByCharacter[key] = {} end
    return ns.db.storageByCharacter[key]
end
local function unavailable(category, reason)
    return { schemaVersion = 1, scope = scopes[category], available = false,
        entries = {}, tabs = {}, partial = true, reason = reason, absenceMeans = "unknown" }
end
local function observation(category)
    return { schemaVersion = 1, scope = scopes[category], available = true,
        capturedAt = time(), cached = true, partial = false,
        entries = {}, tabs = {}, absenceMeans = "unknown", coverage = "client_observed_slots" }
end
local function itemRecord(itemID, link, count, quality, name)
    if type(itemID) ~= "number" or itemID <= 0 then
        itemID = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
    end
    local speciesID = type(link) == "string" and tonumber(link:match("battlepet:(%d+)")) or nil
    if not itemID and not speciesID then return nil end
    local record = { itemID = itemID, stackCount = type(count) == "number" and count or 1 }
    if speciesID then record.battlePetSpeciesID = speciesID end
    if type(link) == "string" then record.link = link end
    if type(quality) == "number" then record.quality = quality end
    if type(name) == "string" and name ~= "" then record.name = name end
    if not record.name then
        local ok, cachedName = call(C_Item and C_Item.GetItemInfo or GetItemInfo, link or itemID)
        if ok and type(cachedName) == "string" then record.name = cachedName end
    end
    return record
end
local function guildPetDetails(item, tab, slot)
    if item.itemID ~= 82800 and not item.battlePetSpeciesID then return end
    local ok, tooltip = call(C_TooltipInfo and C_TooltipInfo.GetGuildBankItem, tab, slot)
    if not ok or type(tooltip) ~= "table" then return end
    local species = tooltip.battlePetSpeciesID
    if type(species) ~= "number" or species <= 0 or species > 9007199254740991 or species % 1 ~= 0 then return end
    item.battlePetSpeciesID = species
    local nameOK, name = call(C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID, species)
    if nameOK and type(name) == "string" and name ~= "" and #name <= 512 then item.name = name end
    for _, key in ipairs({ "battlePetLevel", "battlePetBreedQuality" }) do
        local value = tooltip[key]
        local minimum, maximum = key == "battlePetLevel" and 1 or 0, key == "battlePetLevel" and 255 or 8
        if type(value) == "number" and value >= minimum and value <= maximum and value % 1 == 0 then item[key] = value end
    end
end
local function scanContainer(result, bag, name)
    local tab = { id = bag, name = name, status = "unavailable" }
    result.tabs[#result.tabs + 1] = tab
    local ok, slots = call(C_Container and C_Container.GetContainerNumSlots, bag)
    -- Zero slots on a purchased tab can mean it has not loaded, not empty.
    if not ok or type(slots) ~= "number" or slots <= 0 or slots > 200 then
        result.partial = true
        return
    end
    tab.status, tab.capturedAt, tab.slots, tab.observedSlots = "observed", result.capturedAt, slots, 0
    for slot = 1, slots do
        checkpoint(result.scope == "account_bank" and "warbandBank" or "bank")
        local readOK, info = call(C_Container and C_Container.GetContainerItemInfo, bag, slot)
        if readOK then tab.observedSlots = tab.observedSlots + 1 end
        if not readOK then
            result.partial, tab.status = true, "partial"
        elseif type(info) == "table" then
            local link = info.hyperlink
            if not link then local _, value = call(C_Container.GetContainerItemLink, bag, slot) link = value end
            local item = itemRecord(info.itemID, link, info.stackCount, info.quality, info.itemName)
            if item then
                item.bag, item.slot = bag, slot
                if type(info.isBound) == "boolean" then item.isBound = info.isBound end
                result.entries[#result.entries + 1] = item
            else
                result.partial, tab.status = true, "partial"
            end
        end
    end
end
local function retainCachedTabs(result, previous, locationKey, keepEmpty)
    if not previous then return end
    local oldTabs = {}
    for _, tab in ipairs(previous.tabs or {}) do oldTabs[tab.id] = tab end
    local populated = {}
    for _, item in ipairs(previous.entries or {}) do
        if item[locationKey] ~= nil then populated[item[locationKey]] = true end
    end
    for index, tab in ipairs(result.tabs) do
        local old = oldTabs[tab.id]
        if old and old.capturedAt and (keepEmpty ~= false or populated[tab.id])
            and (tab.status == "unavailable" or tab.status == "unobserved" or tab.status == "partial") then
            local replacement = clone(old)
            replacement.status = "cached"
            if keepEmpty == false then replacement.reason = "Latest read incomplete; retained the earlier observation." end
            result.tabs[index], result.partial = replacement, true
            local kept = {}
            for _, item in ipairs(result.entries) do
                if item[locationKey] ~= tab.id then kept[#kept + 1] = item end
            end
            for _, item in ipairs(previous.entries or {}) do
                if item[locationKey] == tab.id then kept[#kept + 1] = clone(item) end
            end
            result.entries = kept
        end
    end
end
local function saveBank(category, result)
    local observed = false
    for _, tab in ipairs(result.tabs) do
        if (tab.observedSlots or 0) > 0 then observed = true end
    end
    -- Loading or failed reads must not erase the last useful observation.
    if not observed then return end
    local store = cache(true)
    if store then
        retainCachedTabs(result, store[category], "bag")
        store[category] = result
    end
end
local function captureBank(category)
    if not open.bank then return end
    local bankType = Enum and Enum.BankType and Enum.BankType[category == "bank" and "Character" or "Account"]
    if C_Bank and bankType ~= nil and C_Bank.FetchPurchasedBankTabData then
        local usable, canUse = call(C_Bank.CanUseBank, bankType)
        if not usable or canUse ~= true then return end
        local ok, tabs = call(C_Bank.FetchPurchasedBankTabData, bankType)
        if not ok or type(tabs) ~= "table" or #tabs == 0 or #tabs > 20 then return end
        local result = observation(category)
        for _, tab in ipairs(tabs) do
            if type(tab) == "table" and type(tab.ID) == "number" then
                scanContainer(result, tab.ID, tab.name)
            else result.partial = true end
        end
        saveBank(category, result)
    elseif category == "bank" then
        -- Compatibility fallback for clients with the original bank bags.
        local result = observation(category)
        scanContainer(result, BANK_CONTAINER or -1, "Bank")
        local ok, count = call(GetNumBankSlots)
        if ok and type(count) == "number" and count >= 0 and count <= 14 then
            local lastEquipped = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
            for bag = lastEquipped + 1, lastEquipped + count do
                scanContainer(result, bag, "Bank bag")
            end
        else result.partial = true end
        local reagent = Enum and Enum.BagIndex and Enum.BagIndex.Reagentbank
        local unlocked, purchased = call(IsReagentBankUnlocked)
        if reagent and unlocked and purchased then scanContainer(result, reagent, "Reagent bank") end
        saveBank(category, result)
    end
end

local guildTabs = {}
local guildSessionKey
local guildVisit = 0
local guildPending
local guildReadingKey
local guildQueriedTabs = {}
local guildDirty = false
local function captureGuild(captureCurrent)
    if not open.guild then return end
    local guildKey, guildName = guildIdentity()
    local store = cache(true)
    if not store or not guildKey then return end
    if guildSessionKey ~= guildKey then guildTabs = {} guildQueriedTabs = {} guildSessionKey = guildKey end
    local previous = store.guildBank
    if not previous or previous.guildKey ~= guildKey then previous = nil end
    local ok, total = call(GetNumGuildBankTabs)
    if not ok or type(total) ~= "number" or total < 1 or total > 20 then return end
    if not captureCurrent then
        if not previous then return end
        local allowed, changed = {}, false
        for _, tab in ipairs(previous.tabs) do
            local readOK, _, _, viewable = call(GetGuildBankTabInfo, tab.id)
            allowed[tab.id] = readOK and viewable == true
            if not allowed[tab.id] then
                if tab.status ~= "not_viewable" then changed = true end
                guildTabs[tab.id], guildQueriedTabs[tab.id] = nil, nil
            end
        end
        if changed then
            local result = clone(previous)
            result.partial = true
            for _, tab in ipairs(result.tabs) do
                if not allowed[tab.id] then
                    tab.status, tab.capturedAt, tab.reason = "not_viewable", nil, nil
                end
            end
            result.entries = {}
            for _, item in ipairs(previous.entries) do
                if allowed[item.tab] then result.entries[#result.entries + 1] = clone(item) end
            end
            store.guildBank = result
        end
        return changed
    end
    local result = observation("guildBank")
    result.guildKey, result.guildName = guildKey, guildName
    for tabID = 1, total do
        local infoOK, name, _, canView = call(GetGuildBankTabInfo, tabID)
        local tab = { id = tabID, name = type(name) == "string" and name or nil, status = "unobserved" }
        result.tabs[#result.tabs + 1] = tab
        if not infoOK or canView ~= true then
            tab.status = "not_viewable"
            guildTabs[tabID] = nil
        else
            local saved = { entries = {}, capturedAt = time(), partial = false }
            for slot = 1, 98 do
                checkpoint("guildBank")
                local itemOK, texture, count, _, _, quality = call(GetGuildBankItemInfo, tabID, slot)
                local linkOK, link = call(GetGuildBankItemLink, tabID, slot)
                if not itemOK or not linkOK then saved.partial = true
                elseif texture or link then
                    local item = itemRecord(nil, link, count, quality)
                    if item then
                        guildPetDetails(item, tabID, slot)
                        item.tab, item.slot = tabID, slot
                        saved.entries[#saved.entries + 1] = item
                    else saved.partial = true end
                end
            end
            -- The event has no tab ID or explicit loaded acknowledgement.
            -- An all-nil read is unknown, never proof of an empty guild tab.
            if #saved.entries == 0 then
                saved.partial = true
                tab.reason = "No item stacks exposed; this may be empty or still loading."
            elseif saved.partial then
                tab.reason = "Some slot data could not be read."
            end
            guildTabs[tabID] = saved
        end
        -- Carry forward only this session's observed tabs. Reopening the bank
        -- starts a new view and avoids exporting revoked or stale permissions.
        local saved = canView == true and guildTabs[tabID] or nil
        if saved then
            tab.status = saved.partial and "partial" or "observed"
            tab.capturedAt = saved.capturedAt
            for _, item in ipairs(saved.entries) do result.entries[#result.entries + 1] = clone(item) end
            if saved.partial then result.partial = true end
        else result.partial = true end
    end
    -- Selection is a UI concern: explicit tab-index reads also work with
    -- combined bank views. Recheck permissions after yielding, before any
    -- current or retained rows are committed.
    local allowed = {}
    for _, tab in ipairs(result.tabs) do
        local ok, _, _, canView = call(GetGuildBankTabInfo, tab.id)
        allowed[tab.id] = ok and canView == true
        if not allowed[tab.id] then
            tab.status, tab.capturedAt, tab.reason = "not_viewable", nil, nil
            result.partial = true
            guildTabs[tab.id], guildQueriedTabs[tab.id] = nil, nil
        end
    end
    local visible = {}
    for _, item in ipairs(result.entries) do if allowed[item.tab] then visible[#visible + 1] = item end end
    result.entries = visible
    retainCachedTabs(result, previous, "tab", false)
    store.guildBank = result
end

local queueGuild
queueGuild = function()
    if not open.guild then return end
    if jobs.guildBank then guildDirty = true return end
    cancel("guildBank")
    guildReadingKey = nil
    ns.StorageProgress.guildBank = { active = true, processed = 0, queued = true }
    notify()
    if guildPending then return end
    local request = { visit = guildVisit, owner = identity(), attempts = 0 }
    guildPending = request
    local function run()
        if guildPending ~= request then return end
        if not open.guild or guildVisit ~= request.visit or identity() ~= request.owner then
            guildPending = nil
            cancel("guildBank") notify()
            return
        end
        request.attempts = request.attempts + 1
        local guildKey = guildIdentity()
        local totalOK, total = call(GetNumGuildBankTabs)
        local ready = guildKey and totalOK and type(total) == "number" and total >= 1 and total <= 20
        if ready then
            if guildSessionKey ~= guildKey then
                guildTabs, guildQueriedTabs, guildSessionKey = {}, {}, guildKey
            end
            ready = false
            for tab = 1, total do
                local infoOK, _, _, canView = call(GetGuildBankTabInfo, tab)
                if infoOK and canView == true then
                    ready = true
                    if not guildQueriedTabs[tab] then
                        guildQueriedTabs[tab] = true
                        call(QueryGuildBankTab, tab)
                    end
                end
            end
        end
        if not ready then
            -- The interaction opens before guild identity, tab metadata and
            -- permissions are necessarily ready. Retry without relying on a
            -- subsequent item-change event, and never wait indefinitely.
            if request.attempts < 8 and C_Timer and C_Timer.After then
                C_Timer.After(0.25, run)
            else
                guildPending = nil
                cancel("guildBank") notify()
            end
            return
        end
        guildPending = nil
        guildReadingKey = guildKey
        guildDirty = false
        startJob("guildBank", function() captureGuild(true) end, function()
            return open.guild and guildVisit == request.visit and identity() == request.owner
                and guildIdentity() == guildKey
        end, function(ok)
            if ok and guildDirty and open.guild and guildVisit == request.visit then
                guildDirty = false
                queueGuild()
            end
        end)
    end
    -- Give initial metadata and cached contents a frame to become available.
    -- Explicit tab reads do not depend on the bank UI's current selection.
    if C_Timer and C_Timer.After then C_Timer.After(0.1, run) else run() end
end

local function openGuild()
    if not open.guild then
        open.guild = true
        guildVisit = guildVisit + 1
        guildTabs = {}
        guildQueriedTabs = {}
        guildSessionKey = guildIdentity()
    end
    queueGuild()
end

local function closeGuild()
    open.guild = false
    guildDirty = false
    guildVisit = guildVisit + 1
    guildPending = nil
    guildReadingKey = nil
    guildTabs = {}
    guildQueriedTabs = {}
    cancel("guildBank") notify()
end

local function captureVoid()
    if not open.void or type(GetVoidItemInfo) ~= "function" then return end
    local result = observation("voidStorage")
    for tab = 1, (VOID_STORAGE_PAGES or 2) do
        local tabInfo = { id = tab, status = "observed", capturedAt = result.capturedAt }
        result.tabs[#result.tabs + 1] = tabInfo
        local before = #result.entries
        for slot = 1, (VOID_STORAGE_MAX or 80) do
            checkpoint("voidStorage")
            local ok, itemID, _, _, _, _, quality = call(GetVoidItemInfo, tab, slot)
            if not ok then result.partial, tabInfo.status = true, "partial"
            elseif type(itemID) == "number" and itemID > 0 then
                local _, link = call(GetVoidItemHyperlinkString, tab, slot)
                local item = itemRecord(itemID, link, 1, quality)
                item.tab, item.slot = tab, slot
                result.entries[#result.entries + 1] = item
            end
        end
        if #result.entries == before then result.partial, tabInfo.status = true, "partial" end
    end
    local store = cache(true)
    if store and #result.entries > 0 then
        retainCachedTabs(result, store.voidStorage, "tab")
        store.voidStorage = result
    end
end
local function queueBanks()
    cancel("bank") cancel("warbandBank")
    for _, category in ipairs({ "bank", "warbandBank" }) do
        if not ns.IsExportSupported or ns.IsExportSupported(category) then
            ns.StorageProgress[category] = { active = true, processed = 0, queued = true }
        end
    end
    notify()
    if pending then return end
    pending = true
    local function run()
        pending = false
        local key = identity()
        for _, category in ipairs({ "bank", "warbandBank" }) do
            local selected = category
            startJob(selected, function() captureBank(selected) end, function() return open.bank and identity() == key end)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, run) else run() end
end
function ns.GetStorage(category)
    local store = cache(false)
    local value = store and store[category]
    if category == "guildBank" then
        local key = guildIdentity()
        if not key or not value or value.guildKey ~= key then value = nil end
    end
    if value then return clone(value) end
    return unavailable(category, category == "voidStorage" and "Open void storage to capture its contents, if this client supports it."
        or category == "guildBank" and "Open the guild bank and wait for its contents to load, then reopen the export chooser."
        or "Open the bank and wait for its contents to load, then reopen the export chooser.")
end

-- Core.lua owns the first event frame; keep this separate and loaded after it.
local frame = CreateFrame("Frame")
for _, event in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
    "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "BANK_TABS_CHANGED", "BAG_CONTAINER_UPDATE",
    "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "GUILDBANKBAGSLOTS_CHANGED", "GUILDBANK_UPDATE_TABS",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "GUILD_ROSTER_UPDATE",
    "VOID_STORAGE_OPEN", "VOID_STORAGE_CLOSE", "VOID_STORAGE_UPDATE", "VOID_STORAGE_CONTENTS_UPDATE" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, bagID)
    if event == "BANKFRAME_OPENED" then open.bank = true queueBanks()
    elseif event == "BANKFRAME_CLOSED" then open.bank = false cancel("bank") cancel("warbandBank") notify()
    elseif event == "GUILDBANKFRAME_OPENED" then openGuild()
    elseif event == "GUILDBANKFRAME_CLOSED" then closeGuild()
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local guildBanker = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.GuildBanker
        if guildBanker ~= nil and bagID == guildBanker then
            if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then openGuild() else closeGuild() end
        end
    elseif event == "GUILDBANKBAGSLOTS_CHANGED" then queueGuild()
    elseif event == "GUILDBANK_UPDATE_TABS" or event == "GUILD_ROSTER_UPDATE" then
        if open.guild then
            if captureGuild(false) then notify("guildBank", true) end
            local key = guildIdentity()
            -- Metadata can unblock the initial read, but unrelated roster
            -- traffic must not restart a current scan or recapture known tabs.
            local readingGuild = jobs.guildBank and guildReadingKey == key
            if not guildPending and not readingGuild then
                local totalOK, total = call(GetNumGuildBankTabs)
                if totalOK and type(total) == "number" and total >= 1 and total <= 20 then
                    for tab = 1, total do
                        local ok, _, _, canView = call(GetGuildBankTabInfo, tab)
                        if ok and canView == true and not guildTabs[tab] then queueGuild() break end
                    end
                end
            end
        end
    elseif event == "VOID_STORAGE_OPEN" then open.void = true
    elseif event == "VOID_STORAGE_CLOSE" then open.void = false cancel("voidStorage") notify()
    elseif event == "VOID_STORAGE_UPDATE" or event == "VOID_STORAGE_CONTENTS_UPDATE" then
        local key = identity()
        startJob("voidStorage", captureVoid, function() return open.void and identity() == key end)
    elseif open.bank and (event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" or event == "BANK_TABS_CHANGED") then
        queueBanks()
    elseif open.bank and event == "BAG_CONTAINER_UPDATE" and type(bagID) == "number" then
        local store = cache(false)
        for _, category in ipairs({ "bank", "warbandBank" }) do
            for _, tab in ipairs(store and store[category] and store[category].tabs or {}) do
                if tab.id == bagID then queueBanks() return end
            end
        end
    end
end)
