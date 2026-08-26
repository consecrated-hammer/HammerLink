local addonName, ns = ...

local dialog
local aboutDialog
local chooserDialog

local aboutTips = {
    "Every bag slot was inspected. The potions are innocent until opened.",
    "No network requests were made. The bits stayed home.",
    "The Great Vault remembers. HammerLink merely takes notes.",
    "Item links are tiny historical documents with an alarming number of colons.",
    "Your reagent bag has been perceived respectfully.",
    "Compression level nine: because character data deserves a snug blanket.",
    "The readable report speaks fluent robot, but remains perfectly legible to humans.",
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
    -- Multiline EditBoxes grow with their content when used as a ScrollFrame
    -- child. Keep only a viewport-sized initial height so long reports can
    -- extend the native scroll range instead of hitting an arbitrary cap.
    box:SetHeight(250)
    box:SetTextInsets(8, 8, 8, 8)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(box)
    f.scroll = scroll
    f.box = box
    f.title = title
    f.help = help

    local copyHint = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    copyHint:SetPoint("BOTTOMLEFT", 26, 18)
    copyHint:SetText("Press Ctrl+C to copy")
    f.copyHint = copyHint

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(86, 22)
    close:SetPoint("BOTTOM", 0, 14)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    return f
end

local function showOutput(output, snapshot, format)
    dialog = dialog or createDialog()
    if format == "ai" then
        dialog.title:SetText("AI-readable HammerLink report")
        dialog.help:SetText("Copy this Markdown report into ChatGPT, Claude or another AI. Review it before sharing: it contains the selected character data.")
        dialog.copyHint:SetText("Press Ctrl+C to copy the complete report")
    else
        dialog.title:SetText("Consecrated Hammer export")
        dialog.help:SetText("Copy this code into Consecrated Hammer. It is local data: nothing is uploaded by the addon.")
        dialog.copyHint:SetText("Press Ctrl+C to copy the complete code")
    end
    dialog.box:SetText(output)
    if dialog.scroll.UpdateScrollChildRect then dialog.scroll:UpdateScrollChildRect() end
    dialog.scroll:SetVerticalScroll(0)
    dialog:Show()
    dialog.box:SetFocus()
    dialog.box:HighlightText()
    if format == "ai" then
        ns.Print(("AI-readable report ready — %d characters"):format(#output))
    else
        ns.Print(("export ready — %d characters after compression"):format(#output))
    end
    ns.Print(ns.FormatExportSummary(snapshot))
end

local exportCategories = {
    { key = "equipment", title = "Equipped gear", icon = "Interface\\Icons\\INV_Chest_Chain_05", detail = "Current equipment links and slots." },
    { key = "bagItems", title = "Bag items", icon = "Interface\\Buttons\\Button-Backpack-Up", detail = "Every occupied backpack, bag and reagent-bag slot." },
    { key = "currentSpellbook", title = "Current spellbook", icon = "Interface\\Icons\\INV_Misc_Book_09", detail = "General, class and active-specialisation spells currently exposed by the client." },
    { key = "talents", title = "Active talents", icon = "Interface\\Icons\\INV_Misc_Book_11", detail = "The active talent import string when the client exposes it." },
    { key = "vault", title = "Great Vault", icon = "Interface\\Icons\\INV_Misc_TreasureChest04b", detail = "Exact current in-game Vault progress and generated rewards." },
    { key = "currencyCaps", title = "Currency caps", icon = "Interface\\Icons\\INV_Misc_Coin_01", detail = "Crests and other capped currencies: amounts, weekly and seasonal caps." },
    { key = "decorInventory", title = "Housing decor inventory", icon = "Interface\\Icons\\INV_Misc_Statue_05", detail = "Owned Housing Catalog decor, including stored and placed counts." },
    { key = "questLog", title = "Current quest log", icon = "Interface\\Icons\\INV_Misc_Note_01", detail = "Active quests, objective progress, quest types and available waypoints." },
    { key = "professionRecipes", title = "Learned recipes and techniques", icon = "Interface\\Icons\\INV_Scroll_03", detail = "|cffffc44dOne-time setup per character:|r Open each profession once. Reopen it after learning something new to refresh the saved cache." },
}

local exportFormats = {
    { value = "ai", text = "AI-readable report" },
    { value = "compact", text = "Consecrated Hammer code" },
}
local exportFormatLabels = {
    ai = "AI-readable report",
    compact = "Consecrated Hammer code",
}

local LARGE_SECTION_CHARACTERS = 5000

local function commaNumber(value)
    local number = math.floor(tonumber(value) or 0)
    if type(BreakUpLargeNumbers) == "function" then
        local ok, formatted = pcall(BreakUpLargeNumbers, number)
        if ok and formatted ~= nil then return tostring(formatted) end
    end
    local text = tostring(number)
    while true do
        local replaced, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        text = replaced
        if count == 0 then return text end
    end
end

local function recordCountText(value)
    return commaNumber(value) .. (value == 1 and " record" or " records")
end

local function kilobyteText(characters)
    return string.format("%.1fKB", (tonumber(characters) or 0) / 1024)
end

local function createWarning(parent)
    local warning = CreateFrame("Frame", nil, parent)
    warning:SetSize(18, 18)
    local mark = warning:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    mark:SetAllPoints()
    mark:SetJustifyH("CENTER")
    mark:SetText("|cffffc44d!|r")
    warning:EnableMouse(true)
    warning:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Large AI-readable section")
        GameTooltip:AddLine(self.tooltipText or "This category will add a lot of text.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    warning:SetScript("OnLeave", function() GameTooltip:Hide() end)
    warning:Hide()
    return warning
end

local function createActionNotice(parent)
    local notice = CreateFrame("Frame", nil, parent)
    notice:SetSize(20, 20)
    local icon = notice:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas("QuestNormal")
    notice.icon = icon
    notice:EnableMouse(true)
    notice:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Action required")
        GameTooltip:AddLine("Open each profession once on this character. Reopen it after learning recipes to refresh the saved cache.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    notice:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return notice
end

local function selectedSnapshot(f)
    return ns.SelectSnapshot(f.snapshot, ns.GetExportOptions())
end

local function refreshChooser(f)
    local selectedCount = 0
    local selectedCategories = 0
    local selectedCharacters = 1000
    for _, category in ipairs(exportCategories) do
        local checked = ns.IsExportEnabled(category.key)
        local info = ns.GetExportCategoryInfo(f.snapshot, category.key, f.format == "ai")
        local row = f.rows[category.key]
        row.check:SetChecked(checked)
        if info.unavailable then
            row.count:SetText("|cffaaaaaaUnavailable|r")
        else
            row.count:SetText("|cffaaaaaa" .. recordCountText(info.count) .. "|r")
        end
        local large = f.format == "ai" and checked and info.characters >= LARGE_SECTION_CHARACTERS
        if large then
            row.warning.tooltipText = category.title .. " will add about "
                .. kilobyteText(info.characters) .. " across "
                .. recordCountText(info.count) .. "."
            row.warning:Show()
        else
            row.warning:Hide()
        end
        if checked then
            selectedCount = selectedCount + info.count
            selectedCategories = selectedCategories + 1
            selectedCharacters = selectedCharacters + info.characters
        end
    end
    UIDropDownMenu_SetSelectedValue(f.formatDropdown, f.format)
    UIDropDownMenu_SetText(f.formatDropdown, exportFormatLabels[f.format])
    local footer = recordCountText(selectedCount) .. " across " .. tostring(selectedCategories) .. " categories"
    if f.format == "ai" then
        footer = footer .. " · about " .. kilobyteText(selectedCharacters)
    else
        footer = footer .. " · compressed when generated"
    end
    f.summary:SetText(footer)
end

local function setFormat(f, format)
    if not ns.SetExportFormat(format) then return end
    f.format = ns.GetExportFormat()
    refreshChooser(f)
end

local function createChooserDialog()
    local f = CreateFrame("Frame", "HammerLinkOptionsFrame", UIParent, "BackdropTemplate")
    f:SetSize(610, 650)
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
    title:SetText("What do you want to export?")
    local intro = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    intro:SetPoint("TOPLEFT", 28, -47)
    intro:SetWidth(554)
    intro:SetJustifyH("LEFT")
    intro:SetText("Choose a destination and the categories to include. Nothing is uploaded by the addon.")

    local formatLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    formatLabel:SetPoint("TOPLEFT", 28, -78)
    formatLabel:SetText("1. Choose a format")

    local formatDropdown = CreateFrame("Frame", "HammerLinkFormatDropdown", f, "UIDropDownMenuTemplate")
    formatDropdown:SetPoint("TOPLEFT", 12, -96)
    UIDropDownMenu_SetWidth(formatDropdown, 210)
    local formatDropdownText = formatDropdown.Text or _G.HammerLinkFormatDropdownText
    if formatDropdownText then formatDropdownText:SetJustifyH("LEFT") end
    UIDropDownMenu_Initialize(formatDropdown, function()
        for _, option in ipairs(exportFormats) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.checked = f.format == option.value
            info.func = function() setFormat(f, option.value) end
            UIDropDownMenu_AddButton(info)
        end
    end)
    f.formatDropdown = formatDropdown

    local categoryLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    categoryLabel:SetPoint("TOPLEFT", 28, -140)
    categoryLabel:SetText("2. Choose the data")

    local categoryScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    categoryScroll:SetPoint("TOPLEFT", 24, -153)
    categoryScroll:SetPoint("BOTTOMRIGHT", -52, 77)
    local categoryContent = CreateFrame("Frame", nil, categoryScroll)
    categoryContent:SetSize(510, math.max(410, #exportCategories * 45))
    categoryScroll:SetScrollChild(categoryContent)
    f.categoryScroll = categoryScroll
    f.categoryContent = categoryContent

    f.rows = {}
    for index, category in ipairs(exportCategories) do
        local rowTop = -4 - (index - 1) * 45
        local check = CreateFrame("CheckButton", nil, categoryContent, "UICheckButtonTemplate")
        check:SetSize(28, 28)
        check:SetPoint("TOPLEFT", 6, rowTop)
        local categoryIcon = categoryContent:CreateTexture(nil, "ARTWORK")
        categoryIcon:SetSize(28, 28)
        categoryIcon:SetPoint("LEFT", check, "RIGHT", 0, 0)
        categoryIcon:SetTexture(category.icon)
        check.Text:ClearAllPoints()
        check.Text:SetPoint("TOPLEFT", categoryIcon, "TOPRIGHT", 5, -1)
        check.Text:SetHeight(14)
        check.Text:SetJustifyV("TOP")
        check.Text:SetText(category.title)
        check.Text:SetFontObject("GameFontHighlightSmall")
        local detail = categoryContent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        detail:SetPoint("TOPLEFT", check.Text, "BOTTOMLEFT", 0, -2)
        detail:SetWidth(430)
        detail:SetJustifyH("LEFT")
        detail:SetText(category.detail)
        local count = categoryContent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        count:SetPoint("RIGHT", categoryContent, "RIGHT", -26, 0)
        count:SetPoint("TOP", categoryContent, "TOP", 0, rowTop - 3)
        count:SetJustifyH("RIGHT")
        local warning = createWarning(categoryContent)
        warning:SetPoint("RIGHT", categoryContent, "RIGHT", -4, 0)
        warning:SetPoint("TOP", categoryContent, "TOP", 0, rowTop)
        local actionNotice
        if category.key == "professionRecipes" then
            actionNotice = createActionNotice(categoryContent)
            actionNotice:SetPoint("LEFT", check.Text, "RIGHT", 2, 2)
        end
        check:SetScript("OnClick", function(self)
            ns.db.options[category.key] = self:GetChecked() and true or false
            refreshChooser(f)
        end)
        f.rows[category.key] = { check = check, icon = categoryIcon, detail = detail, count = count, warning = warning, actionNotice = actionNotice }
    end

    local summary = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    summary:SetPoint("BOTTOMLEFT", 30, 62)
    summary:SetWidth(550)
    summary:SetJustifyH("LEFT")
    f.summary = summary

    local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reset:SetSize(108, 24)
    reset:SetPoint("BOTTOMLEFT", 28, 23)
    reset:SetText("Enable all")
    reset:SetScript("OnClick", function()
        ns.ResetExportOptions()
        refreshChooser(f)
        ns.Print("all export categories enabled")
    end)

    local generate = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    generate:SetSize(138, 24)
    generate:SetPoint("BOTTOMRIGHT", -124, 23)
    generate:SetText("Generate export")
    generate:SetScript("OnClick", function()
        local snapshot = selectedSnapshot(f)
        local ok, output
        if f.format == "ai" then
            ok, output = pcall(ns.BuildAIReport, snapshot)
        else
            ok, output = pcall(ns.BuildExport, snapshot)
        end
        if not ok then
            ns.Print("Export failed: " .. tostring(output))
            return
        end
        f:Hide()
        showOutput(output, snapshot, f.format)
    end)

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(86, 24)
    close:SetPoint("BOTTOMRIGHT", -28, 23)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    return f
end

function ns.ShowExport()
    local ok, snapshot = pcall(ns.BuildCompleteSnapshot)
    if not ok then
        ns.Print("Could not inspect export data: " .. tostring(snapshot))
        return
    end
    chooserDialog = chooserDialog or createChooserDialog()
    if aboutDialog then aboutDialog:Hide() end
    chooserDialog.snapshot = snapshot
    chooserDialog.format = ns.GetExportFormat()
    refreshChooser(chooserDialog)
    chooserDialog:Show()
end

function ns.ShowOptions()
    ns.ShowExport()
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
    body:SetText("HammerLink captures client-only character state for Consecrated Hammer or an AI-readable report: gear, every occupied bag slot, the current spellbook, talents, Vault progress, capped currencies, quests, Housing decor and observed profession entries. It never sends anything anywhere. Copy the export yourself; the addon is not your butler.")

    local tip = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tip:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -18)
    tip:SetWidth(444)
    tip:SetJustifyH("LEFT")
    local lastTip
    local function showTip()
        local nextTip
        repeat nextTip = math.random(#aboutTips) until #aboutTips == 1 or nextTip ~= lastTip
        lastTip = nextTip
        local tipText = aboutTips[nextTip]
        tip:SetText("|cfff2d493Tip:|r " .. tipText)
        return tipText
    end
    showTip()

    local forge = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    forge:SetSize(174, 36)
    forge:SetPoint("BOTTOMLEFT", 28, 22)
    forge:SetText("Forge another link")
    forge:SetScript("OnClick", function()
        ns.Print("Tip: " .. showTip())
    end)

    local options = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    options:SetSize(174, 24)
    options:SetPoint("BOTTOMLEFT", forge, "TOPLEFT", 0, 8)
    options:SetText("Create export")
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
