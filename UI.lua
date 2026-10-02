local addonName, ns = ...

local dialog
local chooserDialog


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
    help:SetText("Copy this into Consecrated Hammer. It includes the categories chosen in the export chooser. It is local data: nothing is uploaded by the addon.")

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

    -- WoW stops drawing a scrolling EditBox reliably once it holds a very
    -- large report, and Ctrl+A then jumps to the undrawn end. Large output
    -- goes in a copy box whose text is invisible, under a short preview, so
    -- one Ctrl+C still copies everything. The box must sit in a ScrollFrame:
    -- unclipped, megabytes of text drawn past the dialog blanked the whole UI.
    local preview = f:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    preview:SetPoint("TOPLEFT", 33, -86)
    preview:SetPoint("BOTTOMRIGHT", -33, 56)
    preview:SetJustifyH("LEFT")
    preview:SetJustifyV("TOP")
    preview:SetWordWrap(true)
    preview:SetMaxLines(13)
    local copyScroll = CreateFrame("ScrollFrame", nil, f)
    copyScroll:SetPoint("TOPLEFT", 25, -78)
    copyScroll:SetPoint("BOTTOMRIGHT", -25, 48)
    local copyBox = CreateFrame("EditBox", nil, copyScroll)
    copyBox:SetWidth(700)
    copyBox:SetHeight(230)
    copyScroll:SetScrollChild(copyBox)
    copyBox:SetMultiLine(true)
    copyBox:SetAutoFocus(false)
    copyBox:SetFontObject("ChatFontNormal")
    copyBox:SetTextColor(0, 0, 0, 0)
    copyBox:SetHighlightColor(0, 0, 0, 0)
    copyBox:SetScript("OnEscapePressed", function() f:Hide() end)
    copyBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    copyBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(f.output or "")
            self:HighlightText()
        end
    end)
    f.preview, f.copyBox, f.copyScroll = preview, copyBox, copyScroll
    return f
end

local LARGE_OUTPUT_CHARACTERS = 100000

local function previewText(output, format)
    if format ~= "ai" then return output:sub(1, 600) .. "..." end
    local lines = {}
    for line in output:gmatch("[^\n]+") do
        lines[#lines + 1] = line
        if #lines == 12 then break end
    end
    return table.concat(lines, "\n") .. "\n..."
end

local function showOutput(output, snapshot, format)
    dialog = dialog or createDialog()
    local kilobytes = string.format("%.0f KB", #output / 1024)
    if format == "ai" then
        dialog.title:SetText("AI-readable HammerLink report")
        dialog.help:SetText("Copy this Markdown report into ChatGPT, Claude or another AI. Review it before sharing: it contains the selected character data.")
        dialog.copyHint:SetText("Press Ctrl+C to copy the complete report")
    else
        dialog.title:SetText("Consecrated Hammer export")
        dialog.help:SetText("Copy this code into Consecrated Hammer. It is local data: nothing is uploaded by the addon.")
        dialog.copyHint:SetText("Press Ctrl+C to copy the complete code")
    end
    local large = #output > LARGE_OUTPUT_CHARACTERS
    dialog.output = output
    dialog.scroll:SetShown(not large)
    dialog.preview:SetShown(large)
    dialog.copyScroll:SetShown(large)
    dialog:Show()
    if large then
        dialog.box:SetText("")
        dialog.preview:SetText(previewText(output, format))
        dialog.copyHint:SetText("All " .. kilobytes .. " is selected. Press Ctrl+C to copy it, then paste it in one go")
        dialog.copyBox:SetText(output)
        dialog.copyBox:SetFocus()
        dialog.copyBox:HighlightText()
        dialog.copyScroll:SetVerticalScroll(0)
    else
        dialog.copyBox:SetText("")
        dialog.box:SetText(output)
        dialog.box:SetFocus()
        dialog.box:HighlightText()
        local function refreshScroll()
            if dialog.scroll.UpdateScrollChildRect then dialog.scroll:UpdateScrollChildRect() end
            dialog.scroll:SetVerticalScroll(0)
        end
        refreshScroll()
        if C_Timer and C_Timer.After then C_Timer.After(0, refreshScroll) end
    end
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
    { key = "currencies", title = "Current currencies", icon = "Interface\\Icons\\INV_Misc_Coin_02", detail = "Current wallet entries exposed in Retail's currency list. This is a snapshot, not a transaction history." },
    { key = "reputations", title = "Current reputations", icon = "Interface\\Icons\\INV_Misc_Note_06", detail = "Visible Retail faction standings and progress. Collapsed headers and unavailable client fields are not inferred." },
    { key = "decorInventory", title = "Housing decor inventory", icon = "Interface\\Icons\\INV_Misc_Statue_05", detail = "Owned Housing Catalog decor, including stored and placed counts." },
    { key = "questLog", title = "Current quest log", icon = "Interface\\Icons\\INV_Misc_Note_01", detail = "Active quests, objective progress, quest types and available waypoints." },
    { key = "professionRecipes", title = "Learned recipes and techniques", icon = "Interface\\Icons\\INV_Scroll_03", detail = "|cffffc44dOne-time setup per character:|r Open each profession once. Reopen it after learning something new to refresh the saved cache." },
    { key = "achievements", title = "Achievements (optional)", icon = "Interface\\Icons\\Achievement_General", detail = "Complete and incomplete achievements, with criteria progress and category IDs." },
}

local function visibleExportCategories()
    local visible = {}
    for _, category in ipairs(exportCategories) do
        if ns.IsExportSupported(category.key) then visible[#visible + 1] = category end
    end
    return visible
end

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
    for _, category in ipairs(f.categories) do
        local checked = ns.IsExportEnabled(category.key)
        local info = ns.GetExportCategoryInfo(f.snapshot, category.key, f.format == "ai")
        local row = f.rows[category.key]
        row.check:SetChecked(checked)
        if category.key == "achievements" and f.achievementLoading then
            row.count:SetText("|cffaaaaaaCollecting...|r")
        elseif info.unavailable then
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
    if f.achievementLoading or f.generating then
        f.generate:Disable()
    else
        f.generate:Enable()
    end
    if f.achievementLoading then
        f.generate:SetText("Collecting...")
        f.exportWarning:SetText("|cffffc44dCollecting achievements|r ("
            .. recordCountText(f.achievementProgress or 0) .. " so far).")
    elseif not f.generating then
        f.generate:SetText("Generate export")
        f.exportWarning:SetText("With achievements enabled, generating the export may take about a minute.")
    end
    f.exportWarning:SetShown(f.generating or ns.IsExportEnabled("achievements"))
    if f.achievementScope then
        local options = ns.GetAchievementOptions()
        UIDropDownMenu_SetSelectedValue(f.achievementScope, options.scope)
        UIDropDownMenu_SetText(f.achievementScope, f.achievementLabels[options.scope])
        local needsCategories = options.scope == "selected" or options.scope == "currentExpansion"
        f.achievementCategories:SetShown(needsCategories)
        f.achievementHint:SetText(options.scope == "currentExpansion"
            and "Choose this client's current expansion categories. Descendants are included."
            or "Missing achievements remain unknown. Incomplete criteria are included.")
    end
end

local function collectAchievements(f)
    if f.cancelAchievements then f.cancelAchievements() f.cancelAchievements = nil end
    f.achievementLoading = false
    f.snapshot.achievements = nil
    f.snapshot.exportOptions.achievements = ns.IsExportEnabled("achievements")
    if not ns.IsExportEnabled("achievements") then refreshChooser(f) return end
    f.achievementLoading = true
    f.achievementProgress = 0
    refreshChooser(f)
    f.cancelAchievements = ns.CollectAchievements(function(value, err)
        f.achievementLoading = false
        f.snapshot.achievements = value
        if err then ns.Print("Could not collect achievements: " .. err) end
        refreshChooser(f)
    end, function(count)
        f.achievementProgress = count
        f.exportWarning:SetText("|cffffc44dCollecting achievements|r ("
            .. recordCountText(count or 0) .. " so far).")
    end)
end

local function showAchievementCategoryPicker(f)
    local picker = f.achievementPicker
    if not picker then
        picker = CreateFrame("Frame", "HammerLinkAchievementCategories", f, "BackdropTemplate")
        picker:SetSize(540, 470)
        picker:SetPoint("CENTER")
        picker:SetFrameStrata("FULLSCREEN_DIALOG")
        picker:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32, insets = { left = 11, right = 11, top = 11, bottom = 11 } })
        local title = picker:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        title:SetPoint("TOP", 0, -22)
        title:SetText("Choose achievement categories and their descendants")
        local search = CreateFrame("EditBox", nil, picker, "InputBoxTemplate")
        search:SetSize(450, 24)
        search:SetPoint("TOPLEFT", 38, -53)
        search:SetAutoFocus(false)
        search:SetScript("OnEscapePressed", function() picker:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 25, -90)
        scroll:SetPoint("BOTTOMRIGHT", -46, 52)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(460, 300)
        scroll:SetScrollChild(content)
        picker.rows = {}
        local function refresh()
            local query = (search:GetText() or ""):lower()
            local options = ns.GetAchievementOptions()
            local ids = options.scope == "currentExpansion" and options.expansionCategoryIDs or options.categoryIDs
            local selected = {}
            for _, id in ipairs(ids) do selected[id] = true end
            local visible = 0
            for _, category in ipairs(picker.categories) do
                local label = (category.name or "Unavailable category") .. " [" .. category.id .. "]"
                if query == "" or label:lower():find(query, 1, true) then
                    visible = visible + 1
                    local row = picker.rows[visible]
                    if not row then
                        row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
                        row:SetSize(28, 28)
                        row:SetPoint("TOPLEFT", 0, -(visible - 1) * 30)
                        row.Text:SetWidth(410)
                        row.Text:SetJustifyH("LEFT")
                        row:SetScript("OnClick", function(self)
                            ns.ToggleAchievementCategory(self.categoryID)
                            refresh()
                        end)
                        picker.rows[visible] = row
                    end
                    row.categoryID = category.id
                    row.Text:SetText(label)
                    row:SetChecked(selected[category.id] == true)
                    row:Show()
                end
            end
            for index = visible + 1, #picker.rows do picker.rows[index]:Hide() end
            content:SetHeight(math.max(300, visible * 30))
            if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        end
        search:SetScript("OnTextChanged", function() scroll:SetVerticalScroll(0) refresh() end)
        local done = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
        done:SetSize(100, 24)
        done:SetPoint("BOTTOM", 0, 20)
        done:SetText("Done")
        done:SetScript("OnClick", function() picker:Hide() end)
        picker:SetScript("OnHide", function() collectAchievements(f) end)
        picker.search, picker.refresh = search, refresh
        f.achievementPicker = picker
    end
    picker.categories = ns.GetAchievementCategories()
    picker.search:SetText("")
    picker.refresh()
    picker:Show()
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
    categoryScroll:SetPoint("BOTTOMRIGHT", -52, 105)
    local categoryContent = CreateFrame("Frame", nil, categoryScroll)
    f.categories = visibleExportCategories()
    categoryContent:SetSize(510, math.max(410, #f.categories * 45 + 115))
    categoryScroll:SetScrollChild(categoryContent)
    f.categoryScroll = categoryScroll
    f.categoryContent = categoryContent

    f.rows = {}
    for index, category in ipairs(f.categories) do
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
            if category.key == "achievements" then collectAchievements(f) else refreshChooser(f) end
        end)
        f.rows[category.key] = { check = check, icon = categoryIcon, detail = detail, count = count, warning = warning, actionNotice = actionNotice }
    end

    local scope = CreateFrame("Frame", "HammerLinkAchievementScope", categoryContent, "UIDropDownMenuTemplate")
    scope:SetPoint("TOPLEFT", 35, -#f.categories * 45 - 2)
    UIDropDownMenu_SetWidth(scope, 230)
    local scopeOptions = {
        { value = "dungeons", text = "Dungeons & Raids" },
        { value = "all", text = "All discoverable achievements" },
        { value = "currentExpansion", text = "Current expansion" },
        { value = "incomplete", text = "Incomplete achievements only" },
        { value = "selected", text = "Selected categories" },
    }
    f.achievementLabels = {}
    for _, option in ipairs(scopeOptions) do f.achievementLabels[option.value] = option.text end
    UIDropDownMenu_Initialize(scope, function()
        for _, option in ipairs(scopeOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = option.text, option.value
            info.checked = ns.GetAchievementOptions().scope == option.value
            info.func = function() ns.SetAchievementScope(option.value) collectAchievements(f) end
            UIDropDownMenu_AddButton(info)
        end
    end)
    f.achievementScope = scope
    local chooseCategories = CreateFrame("Button", nil, categoryContent, "UIPanelButtonTemplate")
    chooseCategories:SetSize(150, 24)
    chooseCategories:SetPoint("LEFT", scope, "RIGHT", 0, 0)
    chooseCategories:SetText("Choose categories")
    chooseCategories:SetScript("OnClick", function() showAchievementCategoryPicker(f) end)
    f.achievementCategories = chooseCategories
    local hint = categoryContent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 62, -#f.categories * 45 - 43)
    hint:SetWidth(425)
    hint:SetJustifyH("LEFT")
    f.achievementHint = hint

    local summary = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    summary:SetPoint("BOTTOMLEFT", 30, 62)
    summary:SetWidth(550)
    summary:SetJustifyH("LEFT")
    f.summary = summary

    local exportWarning = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    exportWarning:SetPoint("BOTTOMLEFT", summary, "TOPLEFT", 0, 8)
    exportWarning:SetWidth(550)
    exportWarning:SetJustifyH("LEFT")
    exportWarning:SetText("With achievements enabled, generating the export may take about a minute.")
    f.exportWarning = exportWarning

    local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reset:SetSize(108, 24)
    reset:SetPoint("BOTTOMLEFT", 28, 23)
    reset:SetText("Enable all")
    reset:SetScript("OnClick", function()
        ns.ResetExportOptions()
        ns.db.options.achievements = true
        collectAchievements(f)
        ns.Print("all export categories enabled")
    end)

    local generate = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    generate:SetSize(138, 24)
    generate:SetPoint("BOTTOMRIGHT", -124, 23)
    generate:SetText("Generate export")
    f.generate = generate
    local function finishGeneration()
        f.generating = false
        f.cancelExport = nil
        generate:SetText("Generate export")
        refreshChooser(f)
    end
    f:SetScript("OnHide", function()
        if f.cancelExport then f.cancelExport() end
        finishGeneration()
    end)
    generate:SetScript("OnClick", function()
        if f.generating then return end
        if f.achievementLoading then ns.Print("Achievements are still being collected. Try again in a moment.") return end
        if ns.IsExportEnabled("achievements") and not f.snapshot.achievements then
            ns.Print("Achievements could not be collected. Retry or switch off achievements.") return
        end
        local snapshot = selectedSnapshot(f)
        local ok, output, _, exportedSnapshot
        if f.format == "ai" then
            ok, output = pcall(ns.BuildAIReport, snapshot)
        else
            f.generating = true
            generate:SetText("Generating...")
            generate:Disable()
            local generationStarted = GetTime()
            f.exportWarning:SetText("Generating: preparing data...")
            f.exportWarning:Show()
            f.cancelExport = ns.BuildExportAsync(snapshot, function(code, bytes, exported, err)
                finishGeneration()
                if err then ns.Print("Export failed: " .. tostring(err)) return end
                f:Hide()
                showOutput(code, exported, "compact")
            end, function(phase, position, total)
                local labels = { serializing = "preparing data", compressing = "compressing", encoding = "encoding" }
                local percent = total and math.floor(100 * position / math.max(1, total))
                local elapsed = math.floor(GetTime() - generationStarted)
                f.exportWarning:SetText("Generating: " .. (labels[phase] or phase)
                    .. (percent and (" " .. percent .. "%") or "") .. " (" .. elapsed .. "s elapsed).")
            end)
            return
        end
        if not ok then
            ns.Print("Export failed: " .. tostring(output))
            return
        end
        f:Hide()
        showOutput(output, exportedSnapshot or snapshot, f.format)
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
    if chooserDialog.cancelExport then chooserDialog.cancelExport() end
    chooserDialog.generating = false
    chooserDialog.generate:SetText("Generate export")
    chooserDialog.cancelExport = nil
    chooserDialog.snapshot = snapshot
    chooserDialog.format = ns.GetExportFormat()
    collectAchievements(chooserDialog)
    chooserDialog:Show()
end
