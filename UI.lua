local addonName, ns = ...
local HC = ns.HammerCore
local UI, T = HC.UI, HC.Theme

local dialog
local chooserDialog

-- HammerLink's three windows share HammerCore's settings look: an edged
-- surface, a header bar with the title and a close button, drag by the bar.
local HEADER, PAD = 40, 16

-- Every window, for re-applying the opacity setting live.
local windows = {}

-- The theme's "outer" colour is slightly see-through, so the backdrop keeps
-- only its edge and a separate body texture carries the fill. Its alpha is
-- the player's Window opacity; text and controls are never faded.
local function applyOpacity(win)
    local opacity = ns.GetWindowOpacity and ns.GetWindowOpacity() or 1
    local r, g, b = T.Unpack("content")
    win.hcBody:SetColorTexture(r, g, b, opacity)
    local br, bg, bb = T.Unpack("outer")
    if win.SetBackdropColor then win:SetBackdropColor(br, bg, bb, 0) end
end

function ns.ApplyWindowOpacity()
    for _, win in ipairs(windows) do applyOpacity(win) end
end

local function createWindow(name, parent, width, height, titleText, strata)
    local win = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
    win:SetSize(width, height)
    win:SetPoint("CENTER")
    win:SetFrameStrata(strata or "DIALOG")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    T.Surface(win, "outer", "edge")
    local framed = T.Active().surfaces and T.Active().surfaces.outer
    local inset = framed and framed.inset or 1
    local body = win:CreateTexture(nil, "BACKGROUND")
    body:SetPoint("TOPLEFT", inset, -inset)
    body:SetPoint("BOTTOMRIGHT", -inset, inset)
    win.hcBody = body
    windows[#windows + 1] = win
    applyOpacity(win)
    win:Hide()
    win:SetScript("OnShow", function()
        local scale = tonumber(HC.State().settingsScale) or 1
        win:SetScale(parent and parent ~= UIParent and 1 or math.max(0.7, math.min(1.3, scale)))
    end)

    local bar = CreateFrame("Frame", nil, win)
    bar:SetPoint("TOPLEFT", inset, -inset)
    bar:SetPoint("TOPRIGHT", -inset, -inset)
    bar:SetHeight(HEADER)
    T.Fill(bar:CreateTexture(nil, "BACKGROUND"), "header"):SetAllPoints()
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() win:StartMoving() end)
    bar:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)
    local title = T.Font(UI.FontString(bar, "GameFontNormalLarge", "text"), 16)
    title:SetPoint("LEFT", PAD, 0)
    title:SetText(titleText)
    local close = UI.CloseButton(bar, function() win:Hide() end, 24)
    close:SetPoint("RIGHT", -8, 0)
    win.bar, win.title, win.closeButton = bar, title, close
    return win
end

-- A one-line label; settings text never wraps.
local function line(parent, template, role)
    local fs = UI.FontString(parent, template or "GameFontHighlightSmall", role or "muted")
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

-- A section heading in HammerCore's small capitals.
local function heading(parent, text, x, y)
    local fs = UI.FontString(parent, "GameFontNormalSmall", "section")
    fs:SetPoint("TOPLEFT", x + 2, y)
    fs:SetText(text:upper())
    return fs
end

-- A scroll area with HammerCore's thin bar: an edge track and accent thumb.
local function themedScroll(parent, left, top, right, bottom)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetPoint("TOPLEFT", left, top)
    scroll:SetPoint("BOTTOMRIGHT", -(right + 12), bottom)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(4)
    bar:SetPoint("TOPRIGHT", -right, top)
    bar:SetPoint("BOTTOMRIGHT", -right, bottom)
    T.Fill(bar:CreateTexture(nil, "BACKGROUND"), "edge"):SetAllPoints()
    local thumb = T.Fill(bar:CreateTexture(nil, "ARTWORK"), "accent")
    thumb:SetSize(4, 36)
    if bar.SetThumbTexture then bar:SetThumbTexture(thumb) end
    local content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)
    local syncing = false
    local function update()
        local range = scroll:GetVerticalScrollRange() or 0
        bar:SetShown(range > 1)
        range = math.max(1, range)
        bar:SetMinMaxValues(0, range)
        syncing = true
        bar:SetValue(math.min(range, scroll:GetVerticalScroll() or 0))
        syncing = false
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 46)))
    end)
    scroll:SetScript("OnVerticalScroll", update)
    scroll:SetScript("OnScrollRangeChanged", update)
    bar:SetScript("OnValueChanged", function(_, value)
        if syncing then return end
        scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange() or 0, value)))
    end)
    scroll.hcUpdateBar = update
    update()
    return scroll, content, bar
end

local function setButtonEnabled(button, enabled)
    enabled = enabled and true or false
    button:SetEnabled(enabled)
    button.enabled = enabled
    if not T.IsClassic() then T.Text(button.Text, enabled and "text" or "muted") end
end

local function createDialog()
    local f = createWindow("HammerLinkExportFrame", UIParent, 520, 310, "HammerLink export")

    local help = line(f)
    help:SetPoint("TOPLEFT", PAD + 2, -(HEADER + 12))
    help:SetPoint("RIGHT", -PAD, 0)
    help:SetText("Paste this into the Consecrated Hammer website.")

    -- The text sits on a field surface, as HammerCore's inputs do.
    local field = CreateFrame("Frame", nil, f, "BackdropTemplate")
    field:SetPoint("TOPLEFT", PAD, -(HEADER + 32))
    field:SetPoint("BOTTOMRIGHT", -PAD, 74)
    T.Surface(field, "field", "edge")

    local scroll = CreateFrame("ScrollFrame", nil, field, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    T.Text(box, "text")
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
    f.help = help
    f.field = field

    local copyHint = line(f, "GameFontHighlightSmall", "accent")
    copyHint:SetPoint("BOTTOMLEFT", PAD + 2, 48)
    copyHint:SetPoint("RIGHT", -PAD, 0)
    copyHint:SetText("Press Ctrl+C to copy")
    f.copyHint = copyHint

    local close = UI.Button(f, 90, 26)
    close:SetPoint("BOTTOMRIGHT", -PAD, 12)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    f.close = close
    local back = UI.Button(f, 130, 26)
    back:SetPoint("BOTTOMLEFT", PAD, 12)
    back:SetText("Back to choices")
    back:SetScript("OnClick", function() f:Hide() ns.ShowExport() end)
    f.back = back

    -- WoW stops drawing a scrolling EditBox reliably once it holds a very
    -- large report, and Ctrl+A then jumps to the undrawn end. Large output
    -- goes in a copy box whose text is invisible, under a short preview, so
    -- one Ctrl+C still copies everything. The box must sit in a ScrollFrame:
    -- unclipped, megabytes of text drawn past the dialog blanked the whole UI.
    local preview = field:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    T.Text(preview, "text")
    preview:SetPoint("TOPLEFT", 8, -8)
    preview:SetPoint("BOTTOMRIGHT", -8, 8)
    preview:SetJustifyH("LEFT")
    preview:SetJustifyV("TOP")
    preview:SetWordWrap(true)
    preview:SetNonSpaceWrap(true)
    preview:SetMaxLines(13)
    local copyScroll = CreateFrame("ScrollFrame", nil, field)
    copyScroll:SetPoint("TOPLEFT", 6, -6)
    copyScroll:SetPoint("BOTTOMRIGHT", -6, 6)
    local copyBox = CreateFrame("EditBox", nil, copyScroll)
    copyBox:SetWidth(700)
    copyBox:SetHeight(230)
    copyScroll:SetScrollChild(copyBox)
    copyBox:SetMultiLine(true)
    copyBox:SetAutoFocus(false)
    copyBox:SetFontObject("ChatFontNormal")
    copyBox:SetTextColor(T.Unpack("transparent"))
    copyBox:SetHighlightColor(T.Unpack("transparent"))
    local function selectAll(edit)
        if f:IsShown() and f.copyTarget == edit then
            edit:SetFocus()
            edit:HighlightText()
        end
    end
    for _, edit in ipairs({ box, copyBox }) do
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        edit:SetScript("OnMouseUp", function(self)
            -- Selection follows the native mouse handler, which otherwise
            -- replaces the highlight with the clicked cursor position.
            if C_Timer and C_Timer.After then C_Timer.After(0, function() selectAll(self) end)
            else selectAll(self) end
        end)
        local function restore(self)
            if f.copyTarget ~= self then return end
            local original = f.output or ""
            if self:GetText() ~= original then self:SetText(original) end
            self:HighlightText()
        end
        edit:SetScript("OnChar", restore)
        edit:SetScript("OnTextChanged", function(self, userInput)
            if userInput then restore(self) end
        end)
    end
    f:SetScript("OnHide", function()
        box:ClearFocus()
        copyBox:ClearFocus()
        scroll:SetVerticalScroll(0)
        copyScroll:SetVerticalScroll(0)
    end)
    f.preview, f.copyBox, f.copyScroll = preview, copyBox, copyScroll
    return f
end

local LARGE_OUTPUT_CHARACTERS = 100000

local function previewText(output, format)
    if format ~= "ai" then return output:sub(1, 600) .. "..." end
    local lines = {}
    for text in output:gmatch("[^\n]+") do
        lines[#lines + 1] = text
        if #lines == 12 then break end
    end
    return table.concat(lines, "\n") .. "\n..."
end

local function showOutput(output, snapshot, format)
    dialog = dialog or createDialog()
    local compact = format ~= "ai"
    dialog:SetSize(compact and 520 or 760, compact and 310 or 360)
    dialog.box:SetWidth(compact and 440 or 680)
    dialog.box:SetHeight(compact and 184 or 250)
    dialog.box:SetFontObject(compact and "GameFontHighlightSmall" or "ChatFontNormal")
    T.Text(dialog.box, "text")
    dialog.copyBox:SetWidth(compact and 470 or 700)
    dialog.copyBox:SetHeight(compact and 184 or 230)
    dialog.preview:SetFontObject(compact and "GameFontHighlightSmall" or "ChatFontNormal")
    T.Text(dialog.preview, "text")
    local kilobytes = ns.FormatCount(math.floor(#output / 1024 + 0.5)) .. " KB"
    if format == "ai" then
        dialog.title:SetText("Readable report")
        dialog.help:SetText("Paste into ChatGPT, Claude or another AI. Review it first: it holds the selected character data.")
        dialog.copyHint:SetText("Press Ctrl+C to copy the complete report")
    else
        dialog.title:SetText("Import code")
        dialog.help:SetText("A compact code (HL1) to paste into the Consecrated Hammer website.")
        dialog.copyHint:SetText("Press Ctrl+C to copy the complete code")
    end
    local large = #output > LARGE_OUTPUT_CHARACTERS
    dialog.output = output
    dialog.copyTarget = large and dialog.copyBox or dialog.box
    dialog.scroll:SetShown(not large)
    dialog.preview:SetShown(large)
    dialog.copyScroll:SetShown(large)
    dialog:Show()
    if large then
        dialog.box:SetText("")
        dialog.preview:SetText(previewText(output, format))
        dialog.copyHint:SetText("Preview shown. Ctrl+C copies all " .. kilobytes .. ".")
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
        ns.Print(("Readable report ready: %s characters"):format(ns.FormatCount(#output)))
    else
        ns.Print(("export ready: %s characters after compression"):format(ns.FormatCount(#output)))
    end
    ns.Print(ns.FormatExportSummary(snapshot))
end

-- `summary` is the row's one line; `detail` is its tooltip.
local exportCategories = {
    { key = "equipment", title = "Equipped gear", icon = "Interface\\Icons\\INV_Chest_Chain_05",
        summary = "Current gear and slots", detail = "Current equipment links and slots." },
    { key = "bagItems", title = "Bag items", icon = "Interface\\Buttons\\Button-Backpack-Up",
        summary = "Bags and reagent bag", detail = "Every occupied backpack, bag and reagent-bag slot." },
    { key = "bank", title = "Character bank", icon = "Interface\\Icons\\INV_Misc_TreasureChest01",
        summary = "Saved when you open the bank", detail = "Open the bank to refresh. Includes legacy bank bags and reagent storage where present." },
    { key = "warbandBank", title = "Warband Bank", icon = "Interface\\Icons\\INV_Misc_TreasureChest04b",
        summary = "Shared; saved when you open the bank", detail = "Shared account storage. Open the bank to refresh the saved observation." },
    { key = "guildBank", title = "Guild bank", icon = "Interface\\Icons\\INV_Misc_Coin_01",
        summary = "Saved for each tab you view", detail = "Shared guild storage. Visit each viewable tab to refresh; withdrawal rights are not inferred." },
    { key = "voidStorage", title = "Void storage", icon = "Interface\\Icons\\INV_Misc_Bag_10",
        summary = "Saved when you open it", detail = "Open void storage to refresh, on clients that still provide it." },
    { key = "currentSpellbook", title = "Current spellbook", icon = "Interface\\Icons\\INV_Misc_Book_09",
        summary = "General, class and spec spells", detail = "General, class and active-specialisation spells currently exposed by the client." },
    { key = "talents", title = "Active talents", icon = "Interface\\Icons\\INV_Misc_Book_11",
        summary = "Active talent import string", detail = "The active talent import string when the client exposes it." },
    { key = "vault", title = "Great Vault", icon = "Interface\\Icons\\INV_Misc_TreasureChest04b",
        summary = "Progress and rewards", detail = "Exact current in-game Vault progress and generated rewards." },
    { key = "currencyCaps", title = "Currency caps", icon = "Interface\\Icons\\INV_Misc_Coin_01",
        summary = "Crests and capped currencies", detail = "Crests and other capped currencies: amounts, weekly and seasonal caps." },
    { key = "currencies", title = "Current currencies", icon = "Interface\\Icons\\INV_Misc_Coin_02",
        summary = "Current wallet", detail = "Current wallet entries exposed in Retail's currency list. This is a snapshot, not a transaction history." },
    { key = "reputations", title = "Current reputations", icon = "Interface\\Icons\\INV_Misc_Note_06",
        summary = "Visible faction standings", detail = "Visible Retail faction standings and progress. Collapsed headers and unavailable client fields are not inferred." },
    { key = "decorInventory", title = "Housing decor inventory", icon = "Interface\\Icons\\INV_Misc_Statue_05",
        summary = "Owned decor, stored and placed", detail = "Owned Housing Catalog decor, including stored and placed counts." },
    { key = "questLog", title = "Current quest log", icon = "Interface\\Icons\\INV_Misc_Note_01",
        summary = "Active quests and objectives", detail = "Active quests, objective progress, quest types and available waypoints." },
    { key = "questHistory", title = "Quest history", icon = "Interface\\Icons\\INV_Misc_Book_09",
        summary = "Every completed quest", detail = "Every quest the game reports as completed, with names where it has them." },
    { key = "professionRecipes", title = "Learned recipes and techniques", icon = "Interface\\Icons\\INV_Scroll_03",
        summary = "Open each profession once",
        detail = "One-time setup per character: open each profession once. Reopen it after learning something new to refresh the saved cache." },
    { key = "achievements", title = "Achievements", icon = "Interface\\Icons\\Achievement_General",
        summary = "Achievements and criteria progress", detail = "Complete and incomplete achievements, with criteria progress and category IDs." },
}

local categoryGroups = {
    { title = "Equipment and storage", keys = { "equipment", "bagItems", "bank", "warbandBank", "guildBank", "voidStorage" } },
    { title = "Character and abilities", keys = { "currentSpellbook", "talents", "professionRecipes" } },
    { title = "Progression and collections", keys = { "vault", "currencyCaps", "currencies", "reputations", "decorInventory", "questLog", "questHistory", "achievements" } },
}
local function visibleExportCategories()
    local visible, byKey = {}, {}
    for _, category in ipairs(exportCategories) do byKey[category.key] = category end
    for _, group in ipairs(categoryGroups) do
        local first = true
        for _, key in ipairs(group.keys) do
            if ns.IsExportSupported(key) then
                local category = byKey[key]
                category.group = first and group.title or nil
                visible[#visible + 1] = category
                first = false
            end
        end
    end
    return visible
end

local exportFormatValues = { "ai", "compact" }
local exportFormatLabels = { "Readable report", "Import code" }

local achievementScopeValues = { "dungeons", "all", "currentExpansion", "incomplete", "selected" }
local achievementScopeLabels = { "Dungeons & Raids", "All achievements", "Current expansion",
    "Incomplete achievements only", "Selected categories" }

local LARGE_SECTION_CHARACTERS = 5000

local commaNumber = ns.FormatCount

local function recordCountText(value)
    return commaNumber(value) .. (value == 1 and " record" or " records")
end

local function kilobyteText(characters)
    return ns.FormatCount(tonumber(string.format("%.1f", (tonumber(characters) or 0) / 1024))) .. "KB"
end

local function createWarning(parent)
    local warning = CreateFrame("Frame", nil, parent)
    warning:SetSize(18, 18)
    local mark = UI.FontString(warning, "GameFontNormal", "accent")
    mark:SetAllPoints()
    mark:SetJustifyH("CENTER")
    mark:SetText("!")
    warning:EnableMouse(true)
    UI.AttachHint(warning, "Large report section", function()
        return warning.tooltipText or "This category will add a lot of text."
    end)
    warning:Hide()
    return warning
end

local function createActionNotice(parent)
    local notice = CreateFrame("Frame", nil, parent)
    notice:SetSize(18, 18)
    local icon = notice:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas("QuestNormal")
    notice.icon = icon
    notice:EnableMouse(true)
    UI.AttachHint(notice, "Action required",
        "Open each profession once on this character. Reopen it after learning recipes to refresh the saved cache.")
    return notice
end

local function selectedSnapshot(f)
    return ns.SelectSnapshot(f.snapshot, ns.GetExportOptions())
end

local function refreshCollectionStatus(f)
    if f.generating then return end
    local count = recordCountText
    f.questCollectionStatus:SetShown(f.questHistoryLoading == true)
    f.achievementCollectionStatus:SetShown(f.achievementLoading == true)
    if f.questHistoryLoading then
        local labels = { retrying = "Retrying quest history", sorting = "Sorting quest history",
            names = "Reading cached quest names", refreshing = "Refreshing quest history",
            reporting = "Preparing quest history report" }
        f.questCollectionStatus:SetText((labels[f.questHistoryPhase] or "Collecting quest history")
            .. " (" .. count(f.questHistoryProgress or 0) .. " so far).")
    end
    if f.achievementLoading then
        local labels = { retrying = "Retrying achievement reads", refreshing = "Refreshing after achievement updates" }
        f.achievementCollectionStatus:SetText((labels[f.achievementPhase] or "Collecting achievements")
            .. " (" .. count(f.achievementProgress or 0) .. " so far).")
    end
    f.generate:SetText((f.questHistoryLoading or f.achievementLoading or f.storageLoading) and "Collecting..." or "Generate export")
    f.exportWarning:SetText("With achievements enabled, generating the export may take about a minute.")
end

local storageCategories = { bank = true, warbandBank = true, guildBank = true, voidStorage = true }
local function categoryFeedback(f, category, info, checked)
    local value = f.snapshot[category.key]
    local detail, state = category.summary, nil
    if type(value) == "table" then
        if value.reason then detail = value.reason end
        if value.available == false then state = "Unavailable" end
        if storageCategories[category.key] and value.available ~= false then
            state = value.partial and "Partly saved" or "Saved"
            detail = state .. (value.capturedAt and (" " .. date("%d %b %Y %H:%M", value.capturedAt)) or "")
                .. ". Open it in game to update. Slots you haven't viewed aren't included."
        elseif value.available ~= false and (value.partial or value.truncated or value.changedDuringCollection
            or (type(value.coverage) == "string" and value.coverage:find("partial", 1, true))) then
            state = "Partly saved"
            detail = "Partly saved. Missing records aren't included. " .. detail
        end
    end
    if info.unavailable then state = "Unavailable" end
    if checked and (category.key == "achievements" or category.key == "questHistory") and not value then
        state = "Not collected"
        detail = "Not collected. Use Refresh data to retry, or switch this category off."
    end
    if not checked then return "Not included", "Not included in this export. " .. detail end
    return state, detail
end

local function refreshChooser(f)
    f.storageLoading = false
    local selectedCount = 0
    local selectedCategories = 0
    local selectedCharacters = 1000
    for _, category in ipairs(f.categories) do
        local checked = ns.IsExportEnabled(category.key)
        local info = ns.GetExportCategoryInfo(f.snapshot, category.key, f.format == "ai")
        local row = f.rows[category.key]
        row.toggle:SetChecked(checked)
        local storageProgress = ns.StorageProgress and ns.StorageProgress[category.key]
        if checked and storageProgress and storageProgress.active then f.storageLoading = true end
        local state, detail = categoryFeedback(f, category, info, checked)
        if checked and ((category.key == "achievements" and f.achievementLoading)
            or (category.key == "questHistory" and f.questHistoryLoading)) then
            detail = "Still reading. You can generate when it finishes."
        end
        row.detail:SetText(category.key == "professionRecipes" and category.summary or detail)
        row.hint = category.detail .. "\n" .. detail
        if type(f.snapshot[category.key]) == "table" then
            for _, tab in ipairs(f.snapshot[category.key].tabs or {}) do
                row.hint = row.hint .. "\nTab " .. tostring(tab.id) .. ": " .. tostring(tab.status or "unknown")
                    .. (tab.capturedAt and ("; " .. date("%Y-%m-%d %H:%M", tab.capturedAt)) or "")
                    .. (tab.reason and ("; " .. tab.reason) or "")
            end
        end
        row.frame.hcHint = row.hint
        if row.actionNotice then row.actionNotice:SetShown(checked and (info.unavailable or not f.snapshot.professionRecipes)) end
        row.frame:SetEnabled(not f.generating)
        if not checked then
            row.count:SetText("Not included")
        elseif storageProgress and storageProgress.active then
            row.count:SetText("Reading " .. ns.FormatCount(storageProgress.processed) .. " slots")
        elseif (category.key == "achievements" and f.achievementLoading)
            or (category.key == "questHistory" and f.questHistoryLoading) then
            row.count:SetText("Collecting...")
        elseif state == "Unavailable" or state == "Not collected" then
            row.count:SetText(state)
        else
            row.count:SetText(recordCountText(info.count) .. ((state == "Partly saved" or (type(f.snapshot[category.key]) == "table" and f.snapshot[category.key].partial)) and " (partial)" or ""))
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
    -- The selects read the saved format and scope.
    for _, render in ipairs(f.hcRefresh) do render() end
    local footer = recordCountText(selectedCount) .. " across " .. tostring(selectedCategories) .. " categories"
    if f.format == "ai" then
        footer = footer .. " · about " .. kilobyteText(selectedCharacters)
    else
        footer = footer .. " · compressed when generated"
    end
    f.summary:SetText(footer)
    setButtonEnabled(f.generate, not (f.achievementLoading or f.questHistoryLoading or f.storageLoading or f.generating or f.pickingAchievements))
    refreshCollectionStatus(f)
    f.exportWarning:SetShown(f.errorMessage ~= nil or f.noticeMessage ~= nil or f.storageLoading or f.generating or f.pickingAchievements or (ns.IsExportEnabled("achievements") and not f.questHistoryLoading and not f.achievementLoading))
    if f.noticeMessage then
        local guidance = ns.IsExportEnabled("achievements") and not f.questHistoryLoading and not f.achievementLoading
        f.exportWarning:SetText(guidance and ("Achievement exports may take about a minute. " .. f.noticeMessage) or f.noticeMessage)
    end
    -- Blocking instructions outrank an informational action confirmation.
    if f.storageLoading then f.exportWarning:SetText("Reading storage in batches. Keep the storage window open.") end
    if f.pickingAchievements then f.exportWarning:SetText("Finish choosing achievement categories before generating.") end
    if f.errorMessage then f.exportWarning:SetText(f.errorMessage) end
    local options = ns.GetAchievementOptions()
    local enabled = ns.IsExportEnabled("achievements")
    f.achievementPanel:SetShown(enabled)
    f.categoryContent:SetHeight(enabled and f.expandedContentHeight or f.baseContentHeight)
    if f.categoryScroll.UpdateScrollChildRect then f.categoryScroll:UpdateScrollChildRect() end
    f.categoryScroll.hcUpdateBar()
    f.formatHelp:SetText(f.format == "ai" and "Readable Markdown for you or an AI chat. Start here if unsure."
        or "A compact code (HL1) to paste into the Consecrated Hammer website.")
    for _, control in ipairs({ f.formatButton, f.achievementScope, f.enableAll, f.defaults, f.refresh, f.settings }) do
        setButtonEnabled(control, not (f.generating or f.pickingAchievements))
    end
    local needsCategories = enabled and (options.scope == "selected" or options.scope == "currentExpansion")
    f.achievementCategories:SetShown(needsCategories)
    setButtonEnabled(f.achievementCategories, not (f.generating or f.pickingAchievements))
    local ids = options.scope == "currentExpansion" and options.expansionCategoryIDs or options.categoryIDs
    f.achievementCategories:SetText("Categories (" .. #ids .. ")")
    f.achievementHint:SetText(options.scope == "currentExpansion"
        and "Choose this client's current expansion categories. Descendants are included."
        or "Missing achievements remain unknown. Incomplete criteria are included.")
end

-- Storage reads run independently while the relevant game window is open.
-- Replace captured tables only; exports already generating keep their selection.
function ns.StorageChanged(category, updated)
    local f = chooserDialog
    if not f or not f.snapshot or not f:IsShown() or f.generating then return end
    if updated and category and ns.IsExportSupported(category) and ns.GetStorage then
        f.snapshot[category] = ns.GetStorage(category)
    end
    refreshChooser(f)
end

local function collectQuestHistory(f)
    if f.cancelQuestHistory then f.cancelQuestHistory() f.cancelQuestHistory = nil end
    f.questHistoryLoading = false
    f.snapshot.questHistory = nil
    f.snapshot.exportOptions.questHistory = ns.IsExportEnabled("questHistory")
    if not ns.IsExportEnabled("questHistory") then refreshChooser(f) return end
    f.questHistoryLoading, f.questHistoryProgress, f.questHistoryPhase = true, 0, nil
    refreshChooser(f)
    f.cancelQuestHistory = ns.CollectQuestHistory(function(value, err)
        f.questHistoryLoading, f.cancelQuestHistory = false, nil
        f.snapshot.questHistory = value
        if err then
            ns.Print("Could not collect quest history: " .. err)
            f.snapshot.questHistory = { schemaVersion = 1, available = false, entries = {},
                summary = { exported = 0, titlesExported = 0, titlesUnavailable = 0 }, absenceMeans = "unknown", capturedAt = time(),
                scope = "client_reported_completed_quest_flags", coverage = "client_completion_flags_not_lifetime_history",
                completionBasis = "client_reported", completionDatesAvailable = false, repeatCountsAvailable = false,
                truncated = false, truncationReasons = {},
                reason = "Quest history collection failed. Reopen the chooser to retry." }
        end
        if value and value.changedDuringCollection then
            ns.Print("Quest completion flags changed during collection. Reopen the export chooser for a fresh capture.")
        end
        refreshChooser(f)
    end, function(count, phase)
        f.questHistoryProgress, f.questHistoryPhase = count, phase
        refreshCollectionStatus(f)
    end)
end

local function collectAchievements(f)
    if f.cancelAchievements then f.cancelAchievements() f.cancelAchievements = nil end
    f.achievementLoading = false
    f.snapshot.achievements = nil
    f.snapshot.exportOptions.achievements = ns.IsExportEnabled("achievements")
    if not ns.IsExportEnabled("achievements") then refreshChooser(f) return end
    f.achievementLoading = true
    f.achievementProgress = 0
    f.achievementPhase = nil
    refreshChooser(f)
    f.cancelAchievements = ns.CollectAchievements(function(value, err)
        f.achievementLoading = false
        f.snapshot.achievements = value
        if err then ns.Print("Could not collect achievements: " .. err) end
        if value and value.lookupDiagnostics then
            local reads = value.lookupDiagnostics
            if reads.initialFailures > 0 or reads.unresolved > 0 then
                ns.Print("Achievement reads: " .. reads.recovered .. " recovered after retry; "
                    .. reads.unresolved .. " unresolved. Missing achievements remain unknown.")
            end
            if value.changedDuringCollection then
                ns.Print("Achievements changed again during the repeat scan. Exported states may reflect different moments; collect again when updates settle.")
            end
        end
        refreshChooser(f)
    end, function(count, phase)
        f.achievementProgress, f.achievementPhase = count, phase
        refreshCollectionStatus(f)
    end)
end

-- Rows alternate HammerCore's two stripe fills, and brighten on hover.
local function stripeRole(index) return index % 2 == 1 and "stripe" or "content" end

local function hoverRow(row, index)
    row:SetScript("OnEnter", function(self) T.Fill(self.fill, "hover") end)
    row:SetScript("OnLeave", function(self) T.Fill(self.fill, stripeRole(index)) end)
end

-- The on/off control at a row's right: a switch, or Blizzard's checkbox
-- under the Classic theme (as UI.Check does). The row takes the clicks.
local TOGGLE_WIDTH = 68
local function createToggle(row)
    local toggle
    if T.IsClassic() then
        toggle = UI.CheckButton(row)
        toggle:SetPoint("RIGHT", -(UI.CELL_INSET + 9), 0)
    else
        toggle = UI.Switch(row)
        toggle:SetPoint("TOPRIGHT")
        toggle:SetPoint("BOTTOMRIGHT")
        toggle:SetWidth(TOGGLE_WIDTH)
    end
    toggle:EnableMouse(false)
    return toggle
end

local function showAchievementCategoryPicker(f)
    if f.pickingAchievements then return end
    local picker = f.achievementPicker
    if not picker then
        local WIDTH = 540
        picker = createWindow("HammerLinkAchievementCategories", f, WIDTH, 470, "Achievement categories", "FULLSCREEN_DIALOG")
        local help = line(picker)
        help:SetPoint("TOPLEFT", PAD + 2, -(HEADER + 12))
        help:SetText("Picking a category includes everything inside it.")

        local search = CreateFrame("EditBox", nil, picker, "BackdropTemplate")
        search:SetHeight(26)
        search:SetPoint("TOPLEFT", PAD, -(HEADER + 32))
        search:SetPoint("RIGHT", -PAD, 0)
        search:SetAutoFocus(false)
        search:SetFontObject(ChatFontNormal)
        search:SetTextInsets(8, 8, 0, 0)
        T.Surface(search, "field", "edge")
        T.Text(search, "text")
        search:SetScript("OnEscapePressed", function() picker:Hide() end)
        local placeholder = line(search)
        placeholder:SetPoint("LEFT", 8, 0)
        placeholder:SetText("Search categories")
        search.placeholder = placeholder

        local scroll, content = themedScroll(picker, PAD, -(HEADER + 68), PAD, 52)
        local contentWidth = WIDTH - PAD * 2 - 12
        content:SetSize(contentWidth, 1)
        picker.rows = {}
        local function refresh()
            local query = (search:GetText() or ""):lower()
            placeholder:SetShown(query == "")
            local options = ns.GetAchievementOptions()
            local ids = options.scope == "currentExpansion" and options.expansionCategoryIDs or options.categoryIDs
            local selected = {}
            for _, id in ipairs(ids) do selected[id] = true end
            local visible = 0
            for _, category in ipairs(picker.categories) do
                local names, seen, current = {}, {}, category
                while current and not seen[current.id] do
                    seen[current.id] = true
                    table.insert(names, 1, current.name or "Unavailable category")
                    current = picker.byID[current.parentID]
                end
                local label = table.concat(names, " > ")
                local searchable = label:lower() .. " " .. tostring(category.id)
                if query == "" or searchable:find(query, 1, true) then
                    visible = visible + 1
                    local row = picker.rows[visible]
                    if not row then
                        row = CreateFrame("Button", nil, content)
                        row:SetSize(contentWidth, 28)
                        row:SetPoint("TOPLEFT", 0, -(visible - 1) * 28)
                        row.fill = T.Fill(row:CreateTexture(nil, "BACKGROUND"), stripeRole(visible))
                        row.fill:SetAllPoints()
                        row.check = UI.CheckButton(row)
                        row.check:SetPoint("LEFT", 10, 0)
                        row.check:EnableMouse(false)
                        row.check.Text:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                        if row.check.Text.SetWordWrap then row.check.Text:SetWordWrap(false) end
                        row.Text = row.check.Text
                        hoverRow(row, visible)
                        UI.AttachHint(row, function() return row.Text:GetText() end, "Picking a category includes everything inside it. Checked rows are the categories you picked.")
                        row:SetScript("OnClick", function(self)
                            ns.ToggleAchievementCategory(self.categoryID)
                            refresh()
                        end)
                        picker.rows[visible] = row
                    end
                    row.categoryID = category.id
                    row.Text:SetText(label)
                    row.check:SetChecked(selected[category.id] == true)
                    row:Show()
                end
            end
            for index = visible + 1, #picker.rows do picker.rows[index]:Hide() end
            picker.empty:SetShown(visible == 0)
            picker.empty:SetText(query == "" and "No categories available from this client." or "No categories match your search.")
            picker.selection:SetText(#ids .. " categories selected. " .. visible .. " shown.")
            content:SetHeight(math.max(1, visible * 28))
            if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
            scroll.hcUpdateBar()
        end
        picker.empty = line(content)
        picker.empty:SetPoint("TOPLEFT", 10, -8)
        picker.selection = line(picker)
        picker.selection:SetPoint("BOTTOMLEFT", PAD, 20)
        picker.selection:SetPoint("RIGHT", -130, 0)
        search:SetScript("OnTextChanged", function() scroll:SetVerticalScroll(0) refresh() end)
        local done = UI.Button(picker, 100, 26, "primary")
        done:SetPoint("BOTTOMRIGHT", -PAD, 12)
        done:SetText("Done")
        done:SetScript("OnClick", function() picker:Hide() end)
        picker:SetScript("OnHide", function()
            search:ClearFocus()
            f.pickingAchievements = false
            if f.closing or not f:IsShown() then return end
            local options = ns.GetAchievementOptions()
            local ids = options.scope == "currentExpansion" and options.expansionCategoryIDs or options.categoryIDs
            if picker.selectionBefore ~= table.concat(ids, ",") then collectAchievements(f)
            else refreshChooser(f) end
        end)
        picker.search, picker.refresh, picker.scroll, picker.done = search, refresh, scroll, done
        f.achievementPicker = picker
    end
    picker.categories = ns.GetAchievementCategories()
    picker.byID = {}
    for _, category in ipairs(picker.categories) do picker.byID[category.id] = category end
    local options = ns.GetAchievementOptions()
    picker.selectionBefore = table.concat(options.scope == "currentExpansion" and options.expansionCategoryIDs or options.categoryIDs, ",")
    f.pickingAchievements = true
    refreshChooser(f)
    picker.scroll:SetVerticalScroll(0)
    picker.search:SetText("")
    picker.refresh()
    picker:Show()
    picker.search:SetFocus()
end

local function setFormat(f, format)
    if not ns.SetExportFormat(format) then return end
    f.format = ns.GetExportFormat()
    f.errorMessage, f.noticeMessage = nil, nil
    refreshChooser(f)
end

-- The saved format changed somewhere else (the minimap menu): an open
-- chooser follows it.  An export in progress keeps the format it started with.
function ns.ExportFormatChanged()
    local f = chooserDialog
    if not f or f.generating then return end
    f.format = ns.GetExportFormat()
    f.noticeMessage = nil
    if f:IsShown() then refreshChooser(f) end
end

function ns.IsExportGenerating()
    return chooserDialog ~= nil and chooserDialog.generating == true
end

-- HammerCore's select row (label left, themed select and menu right) on a
-- plain holder frame, sized to this window rather than the settings page.
local function selectRow(f, parent, x, y, width, label, hint, values, labels, get, set)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", x, y)
    holder:SetSize(width, UI.CELL_H)
    holder.hcRefresh = f.hcRefresh
    -- Each set refreshes the chooser itself.
    holder.hcRefreshAll = function() end
    holder.hcColumns = 1
    local row, _, button = UI.Dropdown(holder, label, hint, 0, values, labels, get, set, nil, nil, 260)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, 0)
    row:SetSize(width, UI.CELL_H)
    if row.hcStripe then row.hcStripe:SetSize(width, UI.CELL_H) end
    return button, row
end

local function createChooserDialog()
    local WIDTH, HEIGHT, FOOTER, ROW_H = 700, 720, 148, 56
    local f = createWindow("HammerLinkOptionsFrame", UIParent, WIDTH, HEIGHT, "Export")
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(self, key)
        self:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then f:Hide() end
    end)
    f.hcRefresh = {}
    local inner = WIDTH - PAD * 2

    local intro = line(f)
    intro:SetPoint("TOPLEFT", PAD + 2, -(HEADER + 14))
    intro:SetPoint("RIGHT", -PAD, 0)
    intro:SetText("Choose a format and data, generate, then copy. Your choices are remembered.")
    f.intro = intro

    f.formatHeading = heading(f, "Format", PAD, -(HEADER + 42))
    f.formatButton = selectRow(f, f, PAD, -(HEADER + 60), inner, "Export as",
        "Read the report yourself, or paste the Import code into the Consecrated Hammer website.",
        exportFormatValues, exportFormatLabels,
        function() return f.format end,
        function(value) setFormat(f, value) end)

    f.formatHelp = line(f)
    f.formatHelp:SetPoint("TOPLEFT", PAD + 2, -(HEADER + 110))
    f.formatHelp:SetPoint("RIGHT", -PAD, 0)
    f.dataHeading = heading(f, "Data", PAD, -(HEADER + 138))
    local categoryScroll, categoryContent = themedScroll(f, PAD, -(HEADER + 158), PAD, FOOTER)
    local contentWidth = inner - 12
    f.categories = visibleExportCategories()
    f.categoryScroll = categoryScroll
    f.categoryContent = categoryContent

    f.rows = {}
    f.categoryHeadings = {}
    local rowTop = 0
    for index, category in ipairs(f.categories) do
        if category.group then
            if rowTop > 0 then rowTop = rowTop + 14 end
            local section = T.Font(UI.FontString(categoryContent, "GameFontNormalLarge", "accent"), 16)
            section:SetPoint("TOPLEFT", 10, -rowTop - 6)
            section:SetText(category.group)
            local divider = T.Fill(categoryContent:CreateTexture(nil, "ARTWORK"), "edge")
            divider:SetPoint("TOPLEFT", 10, -rowTop - 29)
            divider:SetSize(contentWidth - 20, 1)
            f.categoryHeadings[#f.categoryHeadings + 1] = section
            rowTop = rowTop + 40
        end
        local row = CreateFrame("Button", nil, categoryContent)
        row:SetSize(contentWidth, ROW_H)
        row:SetPoint("TOPLEFT", 0, -rowTop)
        rowTop = rowTop + ROW_H
        row.fill = T.Fill(row:CreateTexture(nil, "BACKGROUND"), stripeRole(index))
        row.fill:SetAllPoints()
        local categoryIcon = row:CreateTexture(nil, "ARTWORK")
        categoryIcon:SetSize(26, 26)
        categoryIcon:SetPoint("LEFT", 12, 0)
        categoryIcon:SetTexture(category.icon)
        if categoryIcon.SetTexCoord then categoryIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        local title = line(row, "GameFontHighlight", "text")
        title:SetPoint("TOPLEFT", 50, -8)
        title:SetPoint("RIGHT", -(TOGGLE_WIDTH + 184), 0)
        title:SetText(category.title)
        local toggle = createToggle(row)
        local count = line(row, "GameFontHighlightSmall", "muted")
        count:SetPoint("RIGHT", row, "RIGHT", -TOGGLE_WIDTH, 0)
        count:SetWidth(160)
        count:SetJustifyH("RIGHT")
        local warning = createWarning(row)
        warning:SetPoint("RIGHT", count, "LEFT", -6, 0)
        local detail = line(row)
        detail:SetPoint("TOPLEFT", 50, -26)
        detail:SetPoint("RIGHT", -(TOGGLE_WIDTH + 184), 0)
        detail:SetText(category.summary)
        local actionNotice
        if category.key == "professionRecipes" then
            actionNotice = createActionNotice(row)
            actionNotice:SetPoint("LEFT", title, "RIGHT", 4, 1)
        end
        hoverRow(row, index)
        UI.AttachHint(row, category.title, category.detail)
        row:SetScript("OnClick", function()
            if f.generating or f.pickingAchievements then return end
            f.errorMessage, f.noticeMessage = nil, nil
            local checked = not toggle:GetChecked()
            toggle:SetChecked(checked)
            ns.db.options[category.key] = checked
            if category.key == "achievements" then
                collectAchievements(f)
                if checked then
                    local function revealOptions()
                        if not f:IsShown() or not ns.IsExportEnabled("achievements") or not f.achievementPanel:IsShown() then return end
                        if f.categoryScroll.UpdateScrollChildRect then f.categoryScroll:UpdateScrollChildRect() end
                        local viewport = f.categoryScroll:GetHeight() or 0
                        local top = (f.baseContentHeight or 0) + 14
                        local bottom = top + (f.achievementPanel:GetHeight() or 124)
                        local current = f.categoryScroll:GetVerticalScroll() or 0
                        if current <= top and current + viewport >= bottom then return end
                        local desired = math.max(0, bottom - viewport)
                        local range = f.categoryScroll:GetVerticalScrollRange()
                        f.categoryScroll:SetVerticalScroll(math.max(0, math.min(range or desired, desired)))
                        f.categoryScroll.hcUpdateBar()
                    end
                    -- Native scroll ranges settle after the content height changes.
                    if C_Timer and C_Timer.After then C_Timer.After(0, revealOptions) else revealOptions() end
                end
            elseif category.key == "questHistory" then collectQuestHistory(f)
            else refreshChooser(f) end
        end)
        f.rows[category.key] = { frame = row, toggle = toggle, icon = categoryIcon, title = title, detail = detail,
            hint = category.detail, count = count, warning = warning, actionNotice = actionNotice }
    end

    -- Achievement scope, under the list in the same striped style.
    local scopeTop = -rowTop - 14
    f.baseContentHeight = rowTop
    local achievementPanel = CreateFrame("Frame", nil, categoryContent)
    achievementPanel:SetPoint("TOPLEFT", 0, scopeTop)
    achievementPanel:SetSize(contentWidth, 124)
    f.achievementPanel = achievementPanel
    scopeTop = 0
    f.scopeHeading = heading(achievementPanel, "Achievement options", 0, scopeTop)
    f.achievementScope = selectRow(f, achievementPanel, 0, scopeTop - 18, contentWidth, "Scope",
        "Which achievements the export reads.",
        achievementScopeValues, achievementScopeLabels,
        function() return ns.GetAchievementOptions().scope end,
        function(value) f.noticeMessage = nil; ns.SetAchievementScope(value); collectAchievements(f) end)
    local hintTop = scopeTop - 18 - UI.CELL_H - 10
    local hint = line(achievementPanel)
    hint:SetPoint("TOPLEFT", UI.CELL_INSET, hintTop - 6)
    hint:SetPoint("RIGHT", -(UI.CELL_INSET + 160), 0)
    hint:SetWordWrap(true)
    hint:SetHeight(42)
    f.achievementHint = hint
    local chooseCategories = UI.Button(achievementPanel, 150, 24)
    chooseCategories:SetPoint("TOPRIGHT", -UI.CELL_INSET, hintTop)
    chooseCategories:SetText("Choose categories")
    chooseCategories:SetScript("OnClick", function() showAchievementCategoryPicker(f) end)
    UI.AttachHint(chooseCategories, "Choose categories", "Pick the achievement categories to read.")
    f.achievementCategories = chooseCategories
    f.expandedContentHeight = rowTop + 138
    categoryContent:SetSize(contentWidth, f.baseContentHeight)

    -- Footer: status lines, the record summary, then the actions.
    local rule = T.Fill(f:CreateTexture(nil, "ARTWORK"), "edge")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", PAD, FOOTER - 8)
    rule:SetPoint("BOTTOMRIGHT", -PAD, FOOTER - 8)

    local summary = line(f, "GameFontHighlightSmall", "text")
    summary:SetPoint("BOTTOMLEFT", PAD + 2, 52)
    summary:SetPoint("RIGHT", -PAD, 0)
    f.summary = summary

    local exportWarning = line(f, "GameFontHighlightSmall", "accent")
    exportWarning:SetPoint("BOTTOMLEFT", summary, "TOPLEFT", 0, 8)
    exportWarning:SetPoint("RIGHT", -PAD, 0)
    exportWarning:SetText("With achievements enabled, generating the export may take about a minute.")
    f.exportWarning = exportWarning

    local function collectionLine(offset)
        local status = line(f)
        status:SetPoint("BOTTOMLEFT", summary, "TOPLEFT", 0, offset)
        status:SetPoint("RIGHT", -PAD, 0)
        status:Hide()
        return status
    end
    f.achievementCollectionStatus = collectionLine(30)
    f.questCollectionStatus = collectionLine(50)

    local reset = UI.Button(f, 110, 26)
    reset:SetPoint("TOPRIGHT", -PAD, -(HEADER + 130))
    reset:SetText("Enable all")
    UI.AttachHint(reset, "Enable all", "Switch on every category, achievements and quest history included.")
    reset:SetScript("OnClick", function()
        if f.generating or f.pickingAchievements then return end
        f.errorMessage, f.noticeMessage = nil, "All export categories enabled."
        for _, category in ipairs(f.categories) do ns.db.options[category.key] = true end
        collectAchievements(f)
        collectQuestHistory(f)
        refreshChooser(f)
    end)
    f.enableAll = reset
    local defaults = UI.Button(f, 150, 26)
    defaults:SetPoint("RIGHT", reset, "LEFT", -8, 0)
    defaults:SetText("Category defaults")
    defaults:SetScript("OnClick", function()
        if f.generating or f.pickingAchievements then return end
        f.errorMessage, f.noticeMessage = nil, nil
        ns.ResetExportOptions()
        collectAchievements(f)
        collectQuestHistory(f)
    end)
    UI.AttachHint(defaults, "Category defaults", "Restore category defaults: achievements and quest history off, other supported categories on. Keeps format, opacity and achievement scope.")
    f.defaults = defaults
    local refresh = UI.Button(f, 110, 26)
    refresh:SetPoint("BOTTOMLEFT", PAD, 12)
    refresh:SetText("Refresh data")
    refresh:SetScript("OnClick", function() if not f.generating then ns.ShowExport() end end)
    UI.AttachHint(refresh, "Refresh data", "Reads everything again. Bank and guild bank only update while their window is open.")
    f.refresh = refresh
    local settings = UI.Button(f, 90, 26)
    settings:SetPoint("LEFT", refresh, "RIGHT", 8, 0)
    settings:SetText("Settings")
    settings:SetScript("OnClick", function() f:Hide() HC.Settings:Show("Export") end)
    f.settings = settings

    local close = UI.Button(f, 90, 26)
    close:SetPoint("BOTTOMRIGHT", -PAD, 12)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    f.close = close

    local generate = UI.Button(f, 150, 26, "primary")
    generate:SetPoint("RIGHT", close, "LEFT", -8, 0)
    generate:SetText("Generate export")
    f.generate = generate
    local function finishGeneration()
        f.generating = false
        f.cancelExport = nil
        generate:SetText("Generate export")
        refreshChooser(f)
    end
    f:SetScript("OnHide", function()
        f.closing = true
        if f.achievementPicker then f.achievementPicker:Hide() end
        f.pickingAchievements = false
        if f.cancelExport then f.cancelExport() end
        if f.cancelQuestHistory then f.cancelQuestHistory() f.cancelQuestHistory = nil end
        if f.cancelAchievements then f.cancelAchievements() f.cancelAchievements = nil end
        f.questHistoryLoading, f.achievementLoading = false, false
        finishGeneration()
        f.closing = false
    end)
    local function blocked(message)
        refreshChooser(f)
        f.exportWarning:SetText(message)
        f.exportWarning:Show()
    end
    generate:SetScript("OnClick", function()
        if f.generating then return end
        if f.pickingAchievements then blocked("Finish choosing achievement categories before generating.") return end
        if f.storageLoading then blocked("Storage is still being read. Keep its window open and try again shortly.") return end
        if f.questHistoryLoading then blocked("Quest history is still being collected. Try again in a moment.") return end
        if f.achievementLoading then blocked("Achievements are still being collected. Try again in a moment.") return end
        if ns.IsExportEnabled("achievements") and not f.snapshot.achievements then
            blocked("Achievements could not be collected. Retry or switch off achievements.") return
        end
        if ns.IsExportEnabled("questHistory") and not f.snapshot.questHistory then
            blocked("Quest history could not be collected. Retry or switch off quest history.") return
        end
        f.noticeMessage = nil
        local snapshot = selectedSnapshot(f)
        local ok, output, _, exportedSnapshot
        if f.format == "ai" then
            ok, output = pcall(ns.BuildAIReport, snapshot)
        else
            f.generating = true
            generate:SetText("Generating...")
            setButtonEnabled(generate, false)
            refreshChooser(f)
            local generationStarted = GetTime()
            f.exportWarning:SetText("Generating: preparing data...")
            f.exportWarning:Show()
            f.cancelExport = ns.BuildExportAsync(snapshot, function(code, bytes, exported, err)
                finishGeneration()
                if err then
                    f.errorMessage = "Export failed. Refresh data to retry, or reduce selected categories."
                    ns.Print("Export failed: " .. tostring(err))
                    refreshChooser(f)
                    return
                end
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
            f.errorMessage = "Export failed. Refresh data to retry, or reduce selected categories."
            ns.Print("Export failed: " .. tostring(output))
            refreshChooser(f)
            return
        end
        f:Hide()
        showOutput(output, exportedSnapshot or snapshot, f.format)
    end)
    UI.AttachHint(generate, "Generate export", "Build the export from the switched-on categories.")
    return f
end

function ns.ShowExport()
    local ok, snapshot = pcall(ns.BuildCompleteSnapshot)
    if not ok then
        ns.Print("Could not inspect export data: " .. tostring(snapshot))
        return
    end
    if dialog then dialog:Hide() end
    chooserDialog = chooserDialog or createChooserDialog()
    if chooserDialog.achievementPicker then
        chooserDialog.closing = true
        chooserDialog.achievementPicker:Hide()
        chooserDialog.closing = false
    end
    if chooserDialog.cancelExport then chooserDialog.cancelExport() end
    chooserDialog.generating = false
    chooserDialog.generate:SetText("Generate export")
    chooserDialog.cancelExport = nil
    chooserDialog.errorMessage, chooserDialog.noticeMessage = nil, nil
    chooserDialog.snapshot = snapshot
    chooserDialog.format = ns.GetExportFormat()
    collectAchievements(chooserDialog)
    collectQuestHistory(chooserDialog)
    chooserDialog:Show()
end

-- A settings reset changes only selections. Rebuild an open chooser so its
-- optional collectors are cancelled and the controls follow those choices.
function ns.ExportChoicesChanged()
    if chooserDialog and chooserDialog:IsShown() and not chooserDialog.generating then ns.ShowExport() end
end
