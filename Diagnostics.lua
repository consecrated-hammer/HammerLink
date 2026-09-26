local addonName, ns = ...

local function yesNo(value) return value and "yes" or "no" end

local function framePoint(frame)
    if not frame or not frame.GetPoint then return "not created" end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    local anchor = relativeTo == Minimap and "Minimap" or "other frame"
    return table.concat({ tostring(point or "?"), anchor,
        tostring(relativePoint or "?"), string.format("%.1f", x or 0), string.format("%.1f", y or 0) }, " ")
end

function ns.BuildDiagnosticReport()
    local interface
    if GetBuildInfo then
        local ok, _, _, _, value = pcall(GetBuildInfo)
        if ok then interface = value end
    end
    local db = ns.db or {}
    local button = ns.HammerCore.Minimap.button
    local supported, enabled = {}, {}
    for _, category in ipairs({ "equipment", "bagItems", "currentSpellbook", "talents", "vault", "currencyCaps", "currencies", "reputations", "decorInventory", "questLog", "professionRecipes" }) do
        if ns.IsExportSupported(category) then
            supported[#supported + 1] = category
            if ns.IsExportEnabled(category) then enabled[#enabled + 1] = category end
        end
    end
    local recipes = ns.GetProfessionRecipes and ns.GetProfessionRecipes() or nil
    local lines = {
        "Interface: " .. tostring(interface or "unknown"),
        "Target: " .. (ns.IsForeverClient() and "WoW Forever" or "Retail"),
        "Database: " .. (ns.dbWasFresh and "created this load" or type(ns.db) == "table" and "loaded" or "unavailable"),
        "Schema: " .. tostring(db.schemaVersion or "unknown"),
        "Export format: " .. tostring(ns.GetExportFormat()),
        "Supported export categories: " .. table.concat(supported, ", "),
        "Enabled export categories: " .. table.concat(enabled, ", "),
        "Profession cache: " .. (recipes and recipes.available and "available" or "not captured"),
        "Minimap stored angle: " .. tostring((ns.HammerCore.State() or {}).minimapAngle or "none"),
        "Minimap visible: " .. yesNo(button and button:IsShown()),
        "Minimap point: " .. framePoint(button),
        "Minimap size/scale: " .. string.format("%.1f x %.1f / %.3f", Minimap:GetWidth() or 0, Minimap:GetHeight() or 0, Minimap:GetEffectiveScale() or 0),
        "Report privacy: no character name, realm, gear, bags, spells, quest data or export code included.",
    }
    return table.concat(lines, "\n")
end
