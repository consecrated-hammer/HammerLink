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
    local button = ns.Minimap and ns.Minimap.button
    local supported, enabled = {}, {}
    for _, category in ipairs({ "equipment", "bagItems", "currentSpellbook", "talents", "vault", "currencyCaps", "currencies", "reputations", "decorInventory", "questLog", "professionRecipes" }) do
        if ns.IsExportSupported(category) then
            supported[#supported + 1] = category
            if ns.IsExportEnabled(category) then enabled[#enabled + 1] = category end
        end
    end
    local recipes = ns.GetProfessionRecipes and ns.GetProfessionRecipes() or nil
    local lines = {
        "HammerLink diagnostics",
        "Version: " .. tostring(ns.GetMetadata("Version") or ns.VERSION or "unknown"),
        "Interface: " .. tostring(interface or "unknown"),
        "Target: " .. (ns.IsForeverClient() and "WoW Forever" or "Retail"),
        "Database: " .. (ns.dbWasFresh and "created this load" or type(ns.db) == "table" and "loaded" or "unavailable"),
        "Schema: " .. tostring(db.schemaVersion or "unknown"),
        "Export format: " .. tostring(ns.GetExportFormat()),
        "Supported export categories: " .. table.concat(supported, ", "),
        "Enabled export categories: " .. table.concat(enabled, ", "),
        "Profession cache: " .. (recipes and recipes.available and "available" or "not captured"),
        "Minimap stored angle: " .. tostring(db.minimapAngle or "none"),
        "Minimap visible: " .. yesNo(button and button:IsShown()),
        "Minimap point: " .. framePoint(button),
        "Minimap size/scale: " .. string.format("%.1f x %.1f / %.3f", Minimap:GetWidth() or 0, Minimap:GetHeight() or 0, Minimap:GetEffectiveScale() or 0),
        "Report privacy: no character name, realm, gear, bags, spells, quest data or export code included.",
    }
    return table.concat(lines, "\n")
end

local dialog
function ns.ShowDiagnosticReport()
    if not dialog then
        dialog = CreateFrame("Frame", "HammerLinkCopyReport", UIParent, "BackdropTemplate")
        dialog:SetSize(680, 360); dialog:SetPoint("CENTER"); dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        dialog:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
        dialog:SetBackdropColor(0.035, 0.035, 0.04, 0.98); dialog:SetBackdropBorderColor(0.58, 0.43, 0.22, 1); dialog:EnableMouse(true)
        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 18, -16); title:SetText("Copy HammerLink report")
        local help = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5); help:SetText("Press Ctrl+C, then Escape. This report excludes character data.")
        local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT", 18, -66); scroll:SetPoint("BOTTOMRIGHT", -38, 44)
        local edit = CreateFrame("EditBox", nil, scroll); edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal); edit:SetWidth(605); edit:SetHeight(250); edit:SetTextInsets(4, 4, 4, 4); edit:SetScript("OnEscapePressed", function() dialog:Hide() end); scroll:SetScrollChild(edit); dialog.edit = edit
        local close = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate"); close:SetSize(90, 22); close:SetPoint("BOTTOMRIGHT", -18, 14); close:SetText("Close"); close:SetScript("OnClick", function() dialog:Hide() end)
    end
    dialog.edit:SetText(ns.BuildDiagnosticReport()); dialog:Show(); dialog.edit:SetFocus(); dialog.edit:HighlightText()
end
