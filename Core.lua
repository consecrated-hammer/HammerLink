local addonName, ns = ...

_G.HammerLink = ns
ns.name = addonName
ns.VERSION = "0.8.1"
ns.PREFIX = "HL1:"

local MAX_CACHED_PROFESSION_RECIPES = 8192
local DEFAULT_EXPORT_FORMAT = "ai"

local DEFAULT_OPTIONS = {
    equipment = true,
    bagItems = true,
    currentSpellbook = true,
    talents = true,
    vault = true,
    currencyCaps = true,
    decorInventory = true,
    questLog = true,
    professionRecipes = true,
}

function ns.GetExportOptions()
    return ns.db and ns.db.options or DEFAULT_OPTIONS
end

function ns.IsExportEnabled(category)
    return ns.GetExportOptions()[category] ~= false
end

function ns.ResetExportOptions()
    ns.db.options = {}
    for category, enabled in pairs(DEFAULT_OPTIONS) do ns.db.options[category] = enabled end
end

function ns.GetExportFormat()
    local format = ns.db and ns.db.exportFormat
    if format == "compact" or format == "ai" then return format end
    return DEFAULT_EXPORT_FORMAT
end

function ns.SetExportFormat(format)
    if not ns.db or (format ~= "compact" and format ~= "ai") then return false end
    ns.db.exportFormat = format
    return true
end

function ns.RefreshDecorInventory()
    if not C_HousingCatalog or not C_HousingCatalog.CreateCatalogSearcher then
        ns.decorInventory = { available = false, reason = "The Retail Housing Catalog API is unavailable in this client." }
        return
    end
    local searcher = C_HousingCatalog.CreateCatalogSearcher()
    if not searcher then
        ns.decorInventory = { available = false, reason = "The Retail Housing Catalog could not be opened for this character." }
        return
    end
    ns.decorSearcher = searcher
    -- Stored-only hides an entry once all copies are placed. Search the catalog
    -- and retain only entries the player actually owns below, so fully placed
    -- decor remains part of the inventory.
    if searcher.SetStoredOnly then searcher:SetStoredOnly(false) end
    if searcher.SetBaseVariantOnly then searcher:SetBaseVariantOnly(true) end
    if searcher.SetAutoUpdateOnParamChanges then searcher:SetAutoUpdateOnParamChanges(false) end
    if searcher.SetResultsUpdatedCallback then
        searcher:SetResultsUpdatedCallback(function()
            local entries = searcher.GetCatalogSearchResults and searcher:GetCatalogSearchResults() or {}
            local packedItems = {}
            for _, entryID in ipairs(entries or {}) do
                local info = C_HousingCatalog.GetCatalogEntryInfo and C_HousingCatalog.GetCatalogEntryInfo(entryID)
                local owned = info and ((info.totalNumStored or 0) > 0 or (info.totalNumPlaced or 0) > 0 or (info.remainingRedeemable or 0) > 0)
                if owned and type(info.recordID) == "number" and type(info.name) == "string" and info.name ~= "" then
                    local flags = (info.isUniqueTrophy and 1 or 0)
                        + (info.isAllowedIndoors and 2 or 0)
                        + (info.isAllowedOutdoors and 4 or 0)
                    -- Fixed-position rows avoid repeating nine JSON field names
                    -- for every decor entry. The importer expands these back to
                    -- the public object shape after validating the whole list.
                    packedItems[#packedItems + 1] = {
                        info.recordID, info.name,
                        type(info.itemID) == "number" and info.itemID or 0,
                        type(info.iconTexture) == "number" and info.iconTexture or 0,
                        info.totalNumStored or 0, info.totalNumPlaced or 0,
                        info.remainingRedeemable or 0, info.destroyableInstanceCount or 0,
                        flags,
                    }
                end
            end
            table.sort(packedItems, function(a, b) return (a[2] or "") < (b[2] or "") end)
            local totalOwned, exemptOwned
            if C_HousingCatalog.GetDecorTotalOwnedCount then
                local totalsOK, owned, exempt = pcall(C_HousingCatalog.GetDecorTotalOwnedCount)
                if totalsOK then totalOwned, exemptOwned = owned, exempt end
            end
            ns.decorInventory = {
                available = true, capturedAt = time(), packedItems = packedItems,
                totalOwnedCount = totalOwned,
                exemptOwnedCount = exemptOwned,
                maxOwnedCount = C_HousingCatalog.GetDecorMaxOwnedCount and C_HousingCatalog.GetDecorMaxOwnedCount() or nil,
                scope = "account_housing_catalog",
                truncated = false,
            }
        end)
    end
    if searcher.RunSearch then searcher:RunSearch() end
end

function ns.GetDecorInventory()
    if ns.decorInventory then return ns.decorInventory end
    ns.RefreshDecorInventory()
    return ns.decorInventory or { available = false, reason = "Housing decor inventory is loading; wait a moment then export again." }
end

local function recipeLineName(info, fallback)
    if type(fallback) == "string" and fallback ~= "" then return fallback end
    if type(info) ~= "table" then return "Unknown profession" end
    local professionName = type(info.professionName) == "string" and info.professionName or "Unknown profession"
    local expansionName = type(info.expansionName) == "string" and info.expansionName or ""
    if expansionName ~= "" and not professionName:find(expansionName, 1, true) then
        return expansionName .. " " .. professionName
    end
    return professionName
end

local function currentProfessionInfo()
    if not C_TradeSkillUI then return nil end
    for _, getter in ipairs({ C_TradeSkillUI.GetChildProfessionInfo, C_TradeSkillUI.GetBaseProfessionInfo }) do
        if getter then
            local ok, info = pcall(getter)
            if ok and type(info) == "table" and type(info.professionID) == "number" and info.professionID > 0 then return info end
        end
    end
    return nil
end

local function cachedRecipeCount(cache)
    local count = 0
    for _, line in pairs(cache.lines or {}) do
        for _ in pairs(type(line) == "table" and line.recipes or {}) do count = count + 1 end
    end
    return count
end

local function currentCharacterKey()
    if not UnitFullName then return nil end
    local name, realm = UnitFullName("player")
    realm = realm or (GetRealmName and GetRealmName())
    if type(name) ~= "string" or name == "" or type(realm) ~= "string" or realm == "" then return nil end
    return name .. "@" .. realm
end

local function professionRecipeCache(create)
    local characterKey = currentCharacterKey()
    if not characterKey then return nil end
    local caches = ns.db.professionRecipesByCharacter
    if not caches and not create then return nil end
    if not caches then
        -- The short-lived development build wrote one account-wide recipe
        -- cache. It has no character provenance, so carrying it forward would
        -- risk assigning recipes to the wrong character. Re-open professions
        -- once to repopulate the safe per-character cache instead.
        ns.db.professionRecipes = nil
        caches = {}
        ns.db.professionRecipesByCharacter = caches
    end
    local cache = caches[characterKey]
    if not cache and create then
        cache = { lines = {}, truncated = false, recipeCount = 0 }
        caches[characterKey] = cache
    end
    return cache
end

-- Retail only exposes a recipe collection while a profession window is loaded.
-- Cache the learned positives per character, never using an unseen recipe as a
-- negative result.  GetAllRecipeIDs is used when the client exposes it; the
-- visible-profession fallback is marked filtered so consumers retain that fact.
function ns.CaptureProfessionRecipes()
    if not ns.db or not C_TradeSkillUI or not C_TradeSkillUI.GetRecipeInfo then return false end
    local getRecipeIDs = C_TradeSkillUI.GetAllRecipeIDs or C_TradeSkillUI.GetFilteredRecipeIDs
    if not getRecipeIDs then return false end
    local idsOK, recipeIDs = pcall(getRecipeIDs)
    if not idsOK or type(recipeIDs) ~= "table" then return false end

    local cache = professionRecipeCache(true)
    if not cache then return false end
    cache.lines = cache.lines or {}
    local recipeCount = type(cache.recipeCount) == "number" and cache.recipeCount or cachedRecipeCount(cache)
    cache.recipeCount = recipeCount
    local baseInfo = currentProfessionInfo()
    local source = C_TradeSkillUI.GetAllRecipeIDs and "all" or "filtered"
    local changed = false

    for _, recipeID in ipairs(recipeIDs) do
        if type(recipeID) == "number" and recipeID > 0 then
            local infoOK, recipeInfo = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
            local learned = infoOK and type(recipeInfo) == "table" and recipeInfo.learned == true
            if not learned and C_TradeSkillUI.IsRecipeProfessionLearned then
                local learnedOK, value = pcall(C_TradeSkillUI.IsRecipeProfessionLearned, recipeID)
                learned = learnedOK and value == true
            end
            if learned and type(recipeInfo) == "table" and type(recipeInfo.name) == "string" and recipeInfo.name ~= "" then
                local professionInfo = nil
                if C_TradeSkillUI.GetProfessionInfoByRecipeID then
                    local professionOK, value = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeID)
                    if professionOK and type(value) == "table" then professionInfo = value end
                end
                professionInfo = professionInfo or baseInfo
                local skillLineID, skillLineName
                if C_TradeSkillUI.GetTradeSkillLineForRecipe then
                    local lineOK, lineID, lineName = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, recipeID)
                    if lineOK then skillLineID, skillLineName = lineID, lineName end
                end
                skillLineID = skillLineID or (professionInfo and professionInfo.professionID)
                if type(skillLineID) == "number" and skillLineID > 0 then
                    local key = tostring(skillLineID)
                    local line = cache.lines[key]
                    if not line then
                        line = { skillLineID = skillLineID, recipes = {} }
                        cache.lines[key] = line
                    end
                    line.professionID = (professionInfo and (professionInfo.parentProfessionID or professionInfo.professionID)) or line.professionID
                    line.name = recipeLineName(professionInfo, skillLineName)
                    line.professionName = professionInfo and professionInfo.professionName or line.professionName
                    line.expansionName = professionInfo and professionInfo.expansionName or line.expansionName
                    line.skillLevel = professionInfo and professionInfo.skillLevel or line.skillLevel
                    line.maxSkillLevel = professionInfo and professionInfo.maxSkillLevel or line.maxSkillLevel
                    line.source = source
                    line.capturedAt = time()
                    if not line.recipes[tostring(recipeID)] then
                        if recipeCount < MAX_CACHED_PROFESSION_RECIPES then
                            line.recipes[tostring(recipeID)] = { recipeID = recipeID, name = recipeInfo.name, learned = true }
                            recipeCount = recipeCount + 1
                            cache.recipeCount = recipeCount
                            changed = true
                        else
                            cache.truncated = true
                        end
                    end
                end
            end
        end
    end
    if changed then cache.updatedAt = time() end
    return changed
end

function ns.GetProfessionRecipes()
    local cache = ns.db and professionRecipeCache(false)
    if not cache or type(cache.lines) ~= "table" or not next(cache.lines) then
        return {
            available = false, capturedAt = time(), professions = {},
            reason = "One-time setup per character: open each profession once. Reopen that profession after learning something new to refresh HammerLink's saved cache. Unopened professions are unknown, not evidence that the character has no recipes or techniques.",
        }
    end
    local result = { available = true, capturedAt = cache.updatedAt or time(), professions = {}, truncated = cache.truncated == true }
    local total = 0
    for _, cachedLine in pairs(cache.lines) do
        if type(cachedLine) == "table" and type(cachedLine.skillLineID) == "number" and type(cachedLine.recipes) == "table" then
            local line = {
                skillLineID = cachedLine.skillLineID, professionID = cachedLine.professionID,
                name = cachedLine.name or "Unknown profession", professionName = cachedLine.professionName,
                expansionName = cachedLine.expansionName, skillLevel = cachedLine.skillLevel,
                maxSkillLevel = cachedLine.maxSkillLevel, source = cachedLine.source,
                capturedAt = cachedLine.capturedAt, recipes = {},
            }
            for _, recipe in pairs(cachedLine.recipes) do
                if total >= MAX_CACHED_PROFESSION_RECIPES then result.truncated = true break end
                if type(recipe) == "table" and type(recipe.recipeID) == "number" and type(recipe.name) == "string" then
                    line.recipes[#line.recipes + 1] = { recipeID = recipe.recipeID, name = recipe.name, learned = true }
                    total = total + 1
                end
            end
            table.sort(line.recipes, function(a, b) return a.name == b.name and a.recipeID < b.recipeID or a.name < b.name end)
            if #line.recipes > 0 then result.professions[#result.professions + 1] = line end
        end
    end
    table.sort(result.professions, function(a, b) return a.name == b.name and a.skillLineID < b.skillLineID or a.name < b.name end)
    return result
end

function ns.QueueProfessionRecipeCapture()
    if ns.professionCaptureQueued then return end
    if not C_Timer or not C_Timer.After then
        ns.CaptureProfessionRecipes()
        return
    end
    ns.professionCaptureQueued = true
    C_Timer.After(0, function()
        ns.professionCaptureQueued = false
        ns.CaptureProfessionRecipes()
    end)
end

function ns.GetMetadata(key)
    return GetAddOnMetadata and GetAddOnMetadata(addonName, key)
end

function ns.Print(message)
    print("|cfff2d493HammerLink:|r " .. tostring(message or ""))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("HOUSING_STORAGE_UPDATED")
frame:RegisterEvent("HOUSING_DECOR_PLACE_SUCCESS")
frame:RegisterEvent("HOUSING_DECOR_REMOVED")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
frame:SetScript("OnEvent", function(_, event, loadedName)
    if event == "ADDON_LOADED" then
        if loadedName ~= addonName then return end
        HammerLinkDB = HammerLinkDB or { schemaVersion = 2, minimapAngle = 225, options = {} }
        HammerLinkDB.minimapAngle = HammerLinkDB.minimapAngle or 225
        ns.db = HammerLinkDB
        ns.db.schemaVersion = 2
        ns.db.options = ns.db.options or {}
        if ns.db.exportFormat ~= "compact" and ns.db.exportFormat ~= "ai" then
            ns.db.exportFormat = DEFAULT_EXPORT_FORMAT
        end
        for category, enabled in pairs(DEFAULT_OPTIONS) do
            if ns.db.options[category] == nil then ns.db.options[category] = enabled end
        end
    elseif event == "PLAYER_LOGIN" then
        if ns.Minimap then ns.Minimap:Create() end
        ns.RefreshDecorInventory()
    elseif event == "HOUSING_STORAGE_UPDATED" or event == "HOUSING_DECOR_PLACE_SUCCESS" or event == "HOUSING_DECOR_REMOVED" then
        ns.RefreshDecorInventory()
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        ns.QueueProfessionRecipeCapture()
    end
end)

SLASH_HAMMERLINK1 = "/hammerlink"
SLASH_HAMMERLINK2 = "/hl"
SlashCmdList.HAMMERLINK = function(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "" or command == "export" then
        ns.ShowExport()
    elseif command == "about" then
        ns.ShowAbout()
    elseif command == "options" or command == "settings" then
        ns.ShowOptions()
    elseif command == "help" then
        ns.Print("|cfff2d493/hammerlink export|r — choose a Consecrated Hammer code or AI-readable character report")
        ns.Print("|cfff2d493/hammerlink about|r — show version, links and important link notes")
        ns.Print("|cfff2d493/hammerlink options|r — open the same export chooser")
    else
        ns.Print("Unknown command. Use /hammerlink export, /hammerlink about or /hammerlink options.")
    end
end
