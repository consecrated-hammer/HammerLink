local addonName, ns = ...

_G.HammerLink = ns
ns.name = addonName
ns.VERSION = "0.4.0"
ns.PREFIX = "HL1:"

local DEFAULT_OPTIONS = {
    equipment = true,
    bagItems = true,
    talents = true,
    vault = true,
    currencyCaps = true,
    decorInventory = true,
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
frame:SetScript("OnEvent", function(_, event, loadedName)
    if event == "ADDON_LOADED" then
        if loadedName ~= addonName then return end
        HammerLinkDB = HammerLinkDB or { schemaVersion = 2, minimapAngle = 225, options = {} }
        HammerLinkDB.minimapAngle = HammerLinkDB.minimapAngle or 225
        ns.db = HammerLinkDB
        ns.db.schemaVersion = 2
        ns.db.options = ns.db.options or {}
        for category, enabled in pairs(DEFAULT_OPTIONS) do
            if ns.db.options[category] == nil then ns.db.options[category] = enabled end
        end
    elseif event == "PLAYER_LOGIN" then
        if ns.Minimap then ns.Minimap:Create() end
        ns.RefreshDecorInventory()
    elseif event == "HOUSING_STORAGE_UPDATED" or event == "HOUSING_DECOR_PLACE_SUCCESS" or event == "HOUSING_DECOR_REMOVED" then
        ns.RefreshDecorInventory()
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
        ns.Print("|cfff2d493/hammerlink export|r — copy your character, gear, bag items, talents and Vault state")
        ns.Print("|cfff2d493/hammerlink about|r — show version, links and important link notes")
        ns.Print("|cfff2d493/hammerlink options|r — choose which categories an export includes")
    else
        ns.Print("Unknown command. Use /hammerlink export, /hammerlink about or /hammerlink options.")
    end
end
