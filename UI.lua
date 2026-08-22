local addonName, ns = ...

local dialog
local aboutDialog
local optionsDialog

local aboutTips = {
    "Every bag slot was inspected. The potions are innocent until opened.",
    "No network requests were made. The bits stayed home.",
    "The Great Vault remembers. HammerLink merely takes notes.",
    "Item links are tiny historical documents with an alarming number of colons.",
    "Your reagent bag has been perceived respectfully.",
    "Compression level nine: because character data deserves a snug blanket.",
}

local function createDialog()
    local f = CreateFrame("Frame", "HammerLinkExportFrame", UIParent, "BackdropTemplate")
    f:SetSize(760, 360)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32, insets = { left = 11, right = 11, top = 11, bottom = 11 } })
    f:Hide()
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOP", 0, -18)
    title:SetText("HammerLink export")
    local help = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    help:SetPoint("TOPLEFT", 24, -45)
    help:SetPoint("TOPRIGHT", -24, -45)
    help:SetJustifyH("LEFT")
    help:SetText("Copy this into Consecrated Hammer. It includes the categories enabled in /hammerlink options. It is local data: nothing is uploaded by the addon.")

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 25, -78)
    scroll:SetPoint("BOTTOMRIGHT", -42, 48)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    box:SetWidth(680)
    -- EditBox has no text-measurement API. A deliberately tall scroll child
    -- avoids text escaping the viewport while retaining a usable Close button.
    box:SetHeight(2048)
    box:SetTextInsets(8, 8, 8, 8)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(box)
    f.scroll = scroll
    f.box = box

    local copyHint = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    copyHint:SetPoint("BOTTOMLEFT", 26, 18)
    copyHint:SetText("Press Ctrl+C to copy")

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(86, 22)
    close:SetPoint("BOTTOM", 0, 14)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    return f
end

function ns.ShowExport()
    local ok, output, rawLength = pcall(ns.BuildExport)
    if not ok then
        ns.Print("Export failed: " .. tostring(output))
        return
    end
    dialog = dialog or createDialog()
    dialog.box:SetText(output)
    dialog.scroll:SetVerticalScroll(0)
    dialog:Show()
    dialog.box:SetFocus()
    dialog.box:HighlightText()
    ns.Print(("export ready — %d characters after compression"):format(#output))
end

local exportCategories = {
    { key = "equipment", title = "Equipped gear", detail = "Current equipment links and slots." },
    { key = "bagItems", title = "Bag items", detail = "Every occupied backpack, bag and reagent-bag slot." },
    { key = "talents", title = "Active talents", detail = "The active talent import string when the client exposes it." },
    { key = "vault", title = "Great Vault", detail = "Exact current in-game Vault progress and generated rewards." },
    { key = "currencyCaps", title = "Currency caps", detail = "Crests and other capped currencies: amounts, weekly and seasonal caps." },
    { key = "decorInventory", title = "Housing decor inventory", detail = "Owned Housing Catalog decor, including stored and placed counts." },
    { key = "questLog", title = "Current quest log", detail = "Active quests, objective progress, quest types and available waypoints." },
}

local function createOptionsDialog()
    local f = CreateFrame("Frame", "HammerLinkOptionsFrame", UIParent, "BackdropTemplate")
    f:SetSize(540, 475)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32, insets = { left = 11, right = 11, top = 11, bottom = 11 } })
    f:SetBackdropColor(0.025, 0.02, 0.04, 1)
    f:Hide()
    f:SetMovable(true)
    f:EnableMouse(true)
    f:EnableKeyboard(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnKeyDown", function(_, key) if key == "ESCAPE" then f:Hide() end end)
    f:SetPropagateKeyboardInput(false)

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOP", 0, -18)
    title:SetText("HammerLink export options")
    local intro = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    intro:SetPoint("TOPLEFT", 28, -47)
    intro:SetWidth(484)
    intro:SetJustifyH("LEFT")
    intro:SetText("Everything starts enabled. Uncheck a category to leave it out of future exports; the import records exactly what was excluded.")

    f.checkboxes = {}
    for index, category in ipairs(exportCategories) do
        local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 30, -78 - (index - 1) * 45)
        check.Text:SetText(category.title)
        check.Text:SetFontObject("GameFontHighlightSmall")
        local detail = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        detail:SetPoint("TOPLEFT", check.Text, "BOTTOMLEFT", 0, -2)
        detail:SetWidth(440)
        detail:SetJustifyH("LEFT")
        detail:SetText(category.detail)
        check:SetScript("OnClick", function(self)
            ns.db.options[category.key] = self:GetChecked() and true or false
        end)
        f.checkboxes[category.key] = check
    end

    local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reset:SetSize(108, 24)
    reset:SetPoint("BOTTOMLEFT", 28, 23)
    reset:SetText("Enable all")
    reset:SetScript("OnClick", function()
        ns.ResetExportOptions()
        for key, check in pairs(f.checkboxes) do check:SetChecked(ns.IsExportEnabled(key)) end
        ns.Print("all export categories enabled")
    end)
    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(86, 24)
    close:SetPoint("BOTTOMRIGHT", -28, 23)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    return f
end

function ns.ShowOptions()
    optionsDialog = optionsDialog or createOptionsDialog()
    if aboutDialog then aboutDialog:Hide() end
    for key, check in pairs(optionsDialog.checkboxes) do check:SetChecked(ns.IsExportEnabled(key)) end
    optionsDialog:Show()
end

local function createAboutDialog()
    local f = CreateFrame("Frame", "HammerLinkAboutFrame", UIParent, "BackdropTemplate")
    f:SetSize(500, 374)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32, insets = { left = 11, right = 11, top = 11, bottom = 11 } })
    f:Hide()
    f:SetMovable(true)
    f:EnableMouse(true)
    f:EnableKeyboard(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOP", 0, -18)
    title:SetText("About HammerLink")

    local detail = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    detail:SetPoint("TOPLEFT", 28, -52)
    detail:SetWidth(444)
    detail:SetJustifyH("LEFT")
    detail:SetText(table.concat({
        "|cfff2d493Version|r  " .. tostring(ns.VERSION or "unknown"),
        "|cfff2d493Released|r  " .. tostring(ns.GetMetadata("X-ReleaseDate") or "local build"),
        "|cfff2d493Author|r  " .. tostring(ns.GetMetadata("Author") or "consecrated-hammer"),
        "|cfff2d493License|r  " .. tostring(ns.GetMetadata("X-License") or "GPL-3.0"),
        "|cfff2d493Source|r  " .. tostring(ns.GetMetadata("X-Website") or ""),
    }, "\n"))

    local body = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    body:SetPoint("TOPLEFT", detail, "BOTTOMLEFT", 0, -20)
    body:SetWidth(444)
    body:SetJustifyH("LEFT")
    body:SetText("HammerLink captures client-only character state for Consecrated Hammer: gear, every occupied bag slot, talents, Vault progress, capped currencies and Housing Catalog decor. It never sends anything anywhere. Copy the export yourself; the addon is not your butler.")

    local tip = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tip:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -18)
    tip:SetWidth(444)
    tip:SetJustifyH("LEFT")
    local lastTip
    local function showTip()
        local nextTip
        repeat nextTip = math.random(#aboutTips) until #aboutTips == 1 or nextTip ~= lastTip
        lastTip = nextTip
        tip:SetText("|cfff2d493Link note:|r " .. aboutTips[nextTip])
    end
    showTip()

    local forge = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    forge:SetSize(174, 36)
    forge:SetPoint("BOTTOMLEFT", 28, 22)
    forge:SetText("Forge another link")
    forge:SetScript("OnClick", function()
        showTip()
        ns.Print("link forged. Nothing was uploaded. Obviously.")
    end)

    local options = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    options:SetSize(174, 24)
    options:SetPoint("BOTTOMLEFT", forge, "TOPLEFT", 0, 8)
    options:SetText("Export options")
    options:SetScript("OnClick", function() ns.ShowOptions() end)

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(86, 22)
    close:SetPoint("BOTTOMRIGHT", -28, 29)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    f:SetScript("OnKeyDown", function(_, key) if key == "ESCAPE" then f:Hide() end end)
    f:SetPropagateKeyboardInput(false)
    return f
end

function ns.ShowAbout()
    aboutDialog = aboutDialog or createAboutDialog()
    aboutDialog:Show()
end
