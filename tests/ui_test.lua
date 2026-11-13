-- The export chooser, copy window and achievement picker, loaded through the
-- HammerCore harness with HammerLink's data functions replaced by fixtures.
package.path = "./tests/hammercore/?.lua;" .. package.path
local wow = require("wow")

-- The harness treats unknown widget methods as no-ops; record the ones the
-- copy mechanics depend on.
local createRegion = wow.CreateRegion
wow.CreateRegion = function(parent, kind)
    local region = createRegion(parent, kind)
    region.SetNonSpaceWrap = function(self, enabled) self.nonSpaceWrap = enabled end
    region.SetFontObject = function(self, font) self.fontObject = font end
    region.SetAtlas = function(self, atlas) self.atlas = atlas end
    return region
end
local function instrument()
    local create = wow.CreateFrame
    CreateFrame = function(kind, name, parent, template)
        local frame = create(kind, name, parent, template)
        frame.SetScale = function(self, scale) self.appliedScale = scale end
        frame.SetMultiLine = function(self, enabled) self.multiline = enabled end
        frame.SetFontObject = function(self, font) self.fontObject = font end
        frame.SetFocus = function(self) self.focused = true end
        frame.ClearFocus = function(self) self.focused = false end
        frame.HasFocus = function(self) return self.focused == true end
        frame.HighlightText = function(self) self.highlightedText = true end
        frame.SetScrollChild = function(self, child) self.scrollChild = child end
        frame.SetVerticalScroll = function(self, position) self.scrollPosition = position end
        return frame
    end
end

local categories = {
    "equipment", "bagItems", "bank", "warbandBank", "guildBank", "voidStorage", "currentSpellbook", "talents", "vault", "currencyCaps", "currencies", "reputations",
    "decorInventory", "questLog", "professionRecipes",
}
local counts = {
    bank = 2, warbandBank = 3, guildBank = 4, voidStorage = 1,
    equipment = 15, bagItems = 118, currentSpellbook = 96, talents = 1, vault = 8,
    currencyCaps = 6, currencies = 14, reputations = 42, decorInventory = 666, questLog = 24,
    professionRecipes = 142,
}

local function loadAddon(classic)
    wow.Install({ HammerLink = { Version = "0.8.0-test" } })
    instrument()
    C_Timer = { After = function() end }
    UnitFullName = function() return "Tester", "Realm" end
    time = function() return 1800000000 end
    date = os.date
    GetTime = function() return 20 end
    GetBuildInfo = function() return "12.1.0", "1", "", 120100 end
    local options = {}
    for _, category in ipairs(categories) do options[category] = true end
    HammerLinkDB = { schemaVersion = 2, options = options, hammerCore = classic and { theme = "classic" } or nil }
    local ns = {}
    for line in io.lines("HammerLink.toc") do
        local entry = line:gsub("\r", ""):gsub("\\", "/")
        if entry:match("%.xml$") then
            wow.LoadHammerCore(entry:match("^(.*)/[^/]+$"), "HammerLink", ns)
        elseif entry:match("%.lua$") then
            assert(loadfile(entry))("HammerLink", ns)
        end
    end
    local events
    for _, frame in ipairs(wow.frames) do
        if frame.scripts.OnEvent and not events then events = frame end
    end
    events.scripts.OnEvent(events, "ADDON_LOADED", "HammerLink")
    if classic then ns.HammerCore.Theme.registry.classic.available = true end
    C_Timer = nil
    return ns
end

-- Opens a HammerCore select and picks the visible menu item with this label.
local function pick(button, label)
    wow.Click(button)
    for index = #wow.frames, 1, -1 do
        local item = wow.frames[index]
        local text = rawget(item, "label")
        if type(text) == "table" and text.text == label and rawget(item, "value") ~= nil and wow.Visible(item) then
            wow.Click(item)
            return
        end
    end
    error("no menu item " .. label, 2)
end

local function run(classic)
    local theme = classic and "classic: " or "modern: "
    local function check(condition, label)
        if not condition then error(theme .. (label or "assertion failed"), 2) end
    end
    local namespace = loadAddon(classic)
    check(namespace.HammerCore.Theme.IsClassic() == (classic and true or false), "theme is active")

    namespace.IsExportSupported = function() return true end
    namespace.IsForeverClient = function() return false end
    function namespace.GetExportOptions() return namespace.db.options end
    function namespace.IsExportEnabled(category)
        if category == "achievements" or category == "questHistory" then return namespace.db.options[category] == true end
        return namespace.db.options[category] ~= false
    end
    local achievementOptions = { scope = "all", categoryIDs = {}, expansionCategoryIDs = {} }
    function namespace.GetAchievementOptions() return achievementOptions end
    function namespace.SetAchievementScope(scope) achievementOptions.scope = scope end
    function namespace.GetAchievementCategories() return {} end
    function namespace.ToggleAchievementCategory(id)
        local ids = achievementOptions.categoryIDs
        for index, value in ipairs(ids) do
            if value == id then table.remove(ids, index) return end
        end
        ids[#ids + 1] = id
    end
    local achievementCollections = 0
    local historyCollections = 0
    function namespace.CollectQuestHistory(callback)
        historyCollections = historyCollections + 1
        callback({ entries = { { questID = 42, completed = true } }, available = true })
        return function() end
    end
    function namespace.CollectAchievements(callback)
        achievementCollections = achievementCollections + 1
        callback({ entries = { { achievementID = 1 } }, available = achievementOptions.scope ~= "all" })
        return function() end
    end
    function namespace.ResetExportOptions()
        for _, category in ipairs(categories) do namespace.db.options[category] = true end
        namespace.db.options.achievements, namespace.db.options.questHistory = false, false
    end
    function namespace.BuildCompleteSnapshot()
        local options = {}
        for _, category in ipairs(categories) do options[category] = true end
        return { character = { name = "Bluehoof", realm = "Dath'Remar" }, exportOptions = options }
    end
    function namespace.SelectSnapshot(snapshot, options)
        local selected = { character = snapshot.character, exportOptions = {} }
        for _, category in ipairs(categories) do selected.exportOptions[category] = options[category] ~= false end
        return selected
    end
    function namespace.GetExportCategoryInfo(snapshot, category)
        if category == "questHistory" then
            local value = snapshot.questHistory
            return { count = value and #value.entries or 0, characters = 100, unavailable = not value }
        end
        if category == "achievements" then
            local enabled = snapshot.exportOptions.achievements == true
            local value = snapshot.achievements
            return { count = value and #value.entries or 0, characters = enabled and 6000 or 0,
                unavailable = enabled and (not value or value.available == false) }
        end
        return {
            count = counts[category], unavailable = false,
            characters = category == "professionRecipes" and 12000 or 1000,
        }
    end
    function namespace.BuildAIReport(snapshot)
        namespace.lastAI = snapshot
        return "# AI report for " .. snapshot.character.name
    end
    function namespace.BuildExport(snapshot)
        namespace.lastCompact = snapshot
        return "HL1:test"
    end
    local pendingExport, pendingProgress
    function namespace.BuildExportAsync(snapshot, callback, progress)
        namespace.asyncCalls = (namespace.asyncCalls or 0) + 1
        pendingProgress = progress
        pendingExport = function() callback(namespace.BuildExport(snapshot), 0, snapshot) end
        return function() pendingExport = nil end
    end
    function namespace.FormatExportSummary() return "exported — test" end
    function namespace.Print(message) namespace.lastMessage = message end

    namespace.ShowExport()
    local chooser = HammerLinkOptionsFrame
    check(chooser and chooser:IsShown(), "expected the export chooser to open")
    check(chooser.format == "ai", "expected AI-readable export to be the default")
    check(chooser.formatButton.text == "Readable report", "expected the format select to show the selected format")
    check(chooser.rows.bagItems.count.text:find("118 records", 1, true), "expected grouped per-category counts")
    check(chooser.rows.talents.count.text:find("1 record", 1, true), "expected singular per-category count wording")
    check(namespace.FormatCount(123456789) == "123,456,789", "counts use comma grouping")
    check(namespace.FormatCount(-12345.5) == "-12,345.5", "fractional signed amounts retain their value")
    check(chooser.summary.text:find("records across 15 categories", 1, true), "expected live selected-record total")
    check(chooser.summary.text:find("about ", 1, true) and chooser.summary.text:find("KB", 1, true), "expected an approximate report size in KB")
    check(not chooser.summary.text:find("characters", 1, true), "expected the raw character estimate to be hidden")
    check(chooser.categoryScroll and chooser.categoryScroll.scrollChild == chooser.categoryContent, "expected a scroll area for export categories")
    check(chooser.categoryContent:GetHeight() >= #categories * 46, "expected the scroll child to grow with future categories")
    for _, category in ipairs(categories) do
        local icon = chooser.rows[category].icon
        check(icon and icon.texture:find("Interface", 1, true) == 1, "expected a built-in category icon for " .. category)
    end
    check(chooser.rows.professionRecipes.warning.shown, "expected large rendered AI section warning")
    check(not chooser.rows.professionRecipes.warning.tooltipText:find("still export normally", 1, true), "expected the redundant warning reassurance to be removed")
    check(chooser.rows.professionRecipes.warning.tooltipText:find("KB", 1, true) and not chooser.rows.professionRecipes.warning.tooltipText:find("characters", 1, true), "expected the large-section estimate in KB only")
    check(chooser.rows.professionRecipes.detail.text == "Open each profession once", "recipe setup summary must fit on its row")
    check(chooser.rows.professionRecipes.title.text == "Learned recipes and techniques", "expected the profession category to cover non-recipe entries honestly")
    check(chooser.rows.professionRecipes.hint:find("Reopen it after learning something new", 1, true), "expected explicit profession cache refresh instructions")
    check(chooser.rows.professionRecipes.frame.hcHint == chooser.rows.professionRecipes.hint, "the full detail is the row's tooltip")
    check(chooser.rows.professionRecipes.actionNotice and chooser.rows.professionRecipes.actionNotice.icon.atlas == "QuestNormal", "expected a native quest marker beside the required recipe action")
    check(chooser.rows.professionRecipes.actionNotice.points[1][1] == "LEFT" and chooser.rows.professionRecipes.actionNotice.points[1][2] == chooser.rows.professionRecipes.title, "expected the recipe action marker attached to its label")

    -- The new look: HammerCore chrome, opaque body, striped rows, switches.
    check(chooser.strata == "DIALOG" and chooser.closeButton and chooser.title.text == "Export", "chooser has the header bar")
    check(chooser.hcBody.colour[4] == 1 and chooser.backdropColour[4] == 0, "the default window is fully solid")
    check(chooser:GetAlpha() == 1, "opacity never fades the text and controls")
    check(wow.FindText("FORMAT") and wow.FindText("DATA"), "section headings are HammerCore's small capitals")
    check(chooser.rows.equipment.frame.fill.colour ~= chooser.rows.bagItems.frame.fill.colour, "rows alternate stripes")
    check(chooser.rows.bagItems.toggle:GetChecked() == true and chooser.rows.achievements.toggle:GetChecked() == false,
        "each toggle reflects its saved option")
    check((chooser.rows.bagItems.toggle.track ~= nil) == not classic, "modern rows use switches, Classic its checkbox")

    pick(chooser.formatButton, "Import code")
    check(chooser.format == "compact" and namespace.db.exportFormat == "compact", "expected compact selection to persist")
    check(chooser.formatButton.text == "Import code", "expected the select to refresh")
    check(not chooser.rows.professionRecipes.warning.shown, "expected AI size warning to stay hidden for compact exports")
    namespace.ShowExport()
    check(chooser:IsShown() and chooser.format == "compact", "expected the last selected format to be remembered")
    pick(chooser.formatButton, "Readable report")
    check(chooser.format == "ai" and namespace.db.exportFormat == "ai", "expected AI-readable selection to persist")
    check(chooser.summary.text:find("about", 1, true), "expected AI report character estimate")
    -- A format change from elsewhere (the minimap menu) reaches the open chooser.
    check(not namespace.IsExportGenerating(), "nothing is generating yet")
    namespace.SetExportFormat("compact")
    check(chooser.format == "compact" and chooser.formatButton.text == "Import code"
        and chooser.summary.text:find("compressed when generated", 1, true), "the chooser follows an outside format change")
    namespace.SetExportFormat("ai")
    check(chooser.format == "ai" and chooser.formatButton.text == "Readable report", "and back")

    local function switch(key, on)
        local row = chooser.rows[key]
        if row.toggle:GetChecked() ~= on then wow.Click(row.frame) end
        check(row.toggle:GetChecked() == on, "the " .. key .. " toggle follows the click")
    end
    wow.Click(chooser.rows.bagItems.frame)
    check(namespace.db.options.bagItems == false and chooser.rows.bagItems.toggle:GetChecked() == false,
        "clicking anywhere on a row toggles it")
    check(chooser.summary.text:find("records across 14 categories", 1, true), "expected total to react to category changes")

    local generate = chooser.generate
    check(wow.FindButton("Generate export") == generate, "expected Generate export button")
    check(generate.enabled, "generation must be enabled when collection is ready")
    wow.Click(generate)
    check(namespace.lastAI and namespace.lastAI.exportOptions.bagItems == false, "expected selected AI snapshot")
    local output = HammerLinkExportFrame
    check(output and output.box.text:find("# AI report", 1, true), "expected readable report in copy dialog")
    check(output.box.highlightedText, "expected complete output to be selected for copying")
    check(output.box.height == 250, "expected native multiline growth instead of a capped report height")
    check(output.scroll.shown and not output.copyScroll.shown and not output.preview.shown, "small reports keep the scrolling view")
    check(output.copyHint.text == "Press Ctrl+C to copy the complete report")
    check(output.title.text == "Readable report" and output.closeButton, "the copy window has the header bar")
    check(output.hcBody.colour[4] == 1, "the copy window is solid")
    local smallReport = namespace.BuildAIReport
    namespace.BuildAIReport = function()
        return "# Large report\n" .. string.rep("- achievement line\n", 8000)
    end
    namespace.ShowExport()
    wow.Click(generate)
    check(not output.scroll.shown and output.copyScroll.shown and output.preview.shown, "large reports use the copy box")
    check(output.copyScroll.scrollChild == output.copyBox, "the copy box must be clipped by its scroll frame")
    check(#output.copyBox.text > 100000 and output.copyBox.focused and output.copyBox.highlightedText, "the whole report is selected for one copy")
    check(output.box.text == "" and output.preview.text:find("# Large report", 1, true))
    check(output.copyHint.text:find("Ctrl+C", 1, true) and output.copyHint.text:find("KB", 1, true))
    output.copyBox.scripts.OnTextChanged(output.copyBox, true)
    check(#output.copyBox.text > 100000, "typing cannot change the report")
    namespace.BuildAIReport = smallReport
    wow.Click(output.closeButton)
    check(not output:IsShown(), "the copy window's close button hides it")

    namespace.ShowExport()
    check(chooser:IsShown() and chooser.format == "ai", "expected reopening the chooser to retain the selected format")
    pick(chooser.formatButton, "Import code")
    wow.Click(generate)
    check(chooser.generating and generate.text == "Generating...", "generation must show busy state")
    check(namespace.IsExportGenerating(), "the menu can tell an export is running")
    namespace.SetExportFormat("ai")
    check(chooser.format == "compact", "an export in progress keeps its format")
    namespace.SetExportFormat("compact")
    check(not generate.enabled, "generation must disable the button while exporting")
    pendingProgress("compressing", 250, 1000)
    check(chooser.exportWarning.shown and chooser.exportWarning.text:find("compressing 25%", 1, true),
        "busy status must show advancing phase and percentage")
    wow.Click(generate)
    check(namespace.asyncCalls == 1, "repeat clicks must not launch another job")
    pendingExport()
    check(not chooser.generating, "completion must clear busy state")
    check(generate.enabled, "completion must restore the button")
    check(namespace.lastCompact and namespace.lastCompact.exportOptions.bagItems == false, "expected selected compact snapshot")
    check(output.box.text == "HL1:test", "expected compact code in the same copy dialog")
    check(output.title.text == "Import code", "compact output has its own title")

    check(not chooser.exportWarning.shown, "warning must be hidden without achievements")
    check(achievementCollections == 0, "opening the chooser must not scan optional achievements")
    check(not chooser.achievementPanel.shown and chooser.categoryContent.height == chooser.baseContentHeight, "optional achievement controls collapse when off")
    check(chooser.achievementScope.text == "All achievements", "default achievement scope is All achievements")
    pick(chooser.formatButton, "Readable report")
    local immediateCollection = namespace.CollectAchievements
    local completeCollection
    local reportProgress
    namespace.CollectAchievements = function(callback, progress)
        reportProgress = progress
        completeCollection = function() return immediateCollection(callback) end
        return function() completeCollection = nil end
    end
    chooser:Show() -- exercise a visible chooser, as a player click would
    chooser.categoryScroll.GetVerticalScrollRange = function() return math.max(0, chooser.categoryContent:GetHeight() - 300) end
    switch("achievements", true)
    check(chooser.achievementPanel.shown and chooser.categoryContent.height == chooser.expandedContentHeight, "enabling achievements reveals its controls")
    check(chooser.categoryScroll.scrollPosition > 0, "enabling achievements scrolls its options into view")
    check(chooser.achievementLoading and not generate.enabled, "collection must disable Generate export")
    check(generate.text == "Collecting...", "the disabled button must say why")
    local messageBefore = namespace.lastMessage
    generate.scripts.OnClick(generate)
    check(chooser.exportWarning.shown and chooser.exportWarning.text:find("Achievements are still", 1, true), "blocked generate explains collection inline")
    check(namespace.lastMessage == messageBefore, "blocked generate does not hide feedback in chat")
    check(chooser.achievementCollectionStatus.shown and chooser.achievementCollectionStatus.text:find("Collecting achievements", 1, true))
    check(chooser.rows.achievements.count.text == "Collecting...", "the row shows collection")
    reportProgress(1234)
    check(chooser.achievementCollectionStatus.text:find("1,234 records so far", 1, true), "collection shows a running count")
    completeCollection()
    check(not chooser.achievementLoading and generate.enabled, "finished collection must enable Generate export")
    check(generate.text == "Generate export" and chooser.exportWarning.text:find("about a minute", 1, true))
    switch("achievements", false)
    namespace.CollectAchievements = immediateCollection
    achievementCollections = 0
    switch("achievements", true)
    check(chooser.exportWarning.shown and chooser.exportWarning.text:find("about a minute", 1, true))
    check(chooser.exportWarning.points[1][2] == chooser.summary, "warning must sit above the record summary")
    check(achievementCollections == 1 and chooser.snapshot.achievements, "checking achievements collects the selected scope")
    check(chooser.rows.achievements.warning.shown and chooser.snapshot.exportOptions.achievements == true,
        "achievement size warnings must use the collected snapshot's live selection")
    chooser.noticeMessage = "Old action confirmation"
    pick(chooser.achievementScope, "All achievements")
    check(chooser.noticeMessage == nil, "scope change clears action confirmation")
    check(achievementOptions.scope == "all" and chooser.achievementScope.text == "All achievements")
    check(chooser.rows.achievements.count.text:find("Unavailable", 1, true), "failed achievement scans must show unavailable, not zero records")
    check(not chooser.achievementCategories.shown, "category picking is only offered for scopes that use it")
    pick(chooser.achievementScope, "Current expansion")
    check(chooser.achievementCategories.shown and chooser.achievementHint.text:find("current expansion categories", 1, true))

    -- Achievement category picker.
    namespace.ShowExport()
    pick(chooser.achievementScope, "Selected categories")
    namespace.GetAchievementCategories = function()
        return { { id = 92, name = "General" }, { id = 96, name = "Quests" }, { id = 15234 } }
    end
    achievementCollections = 0
    chooser.noticeMessage = "All export categories enabled."
    wow.Click(chooser.achievementCategories)
    check(chooser.exportWarning.text:find("Finish choosing", 1, true), "picker instruction outranks old action notice")
    local picker = HammerLinkAchievementCategories
    check(picker and picker:IsShown() and picker.title.text == "Achievement categories" and picker.closeButton,
        "the picker opens with the header bar")
    check(picker.strata == "FULLSCREEN_DIALOG" and picker.hcBody.colour[4] == 1, "the picker sits above the chooser, solid")
    check(picker.rows[1].Text.text == "General" and picker.rows[3].Text.text == "Unavailable category")
    check(picker.search.placeholder.shown, "an empty search shows its placeholder")
    picker.search:SetText("15234")
    picker.search.scripts.OnTextChanged(picker.search)
    check(picker.rows[1].categoryID == 15234 and not picker.rows[2].shown, "hidden IDs remain searchable")
    picker.search:SetText("")
    picker.search.scripts.OnTextChanged(picker.search)
    wow.Click(picker.rows[1])
    check(achievementOptions.categoryIDs[1] == 92 and picker.rows[1].check:GetChecked() == true, "clicking a row selects its category")
    local originalBaseline = picker.selectionBefore
    wow.Click(chooser.achievementCategories)
    check(picker.selectionBefore == originalBaseline and not chooser.achievementCategories.enabled,
        "reopening an active picker preserves its original change baseline")
    picker.search:SetText("ques")
    picker.search.scripts.OnTextChanged(picker.search)
    check(picker.rows[1].Text.text == "Quests" and picker.rows[1].check:GetChecked() == false
        and not picker.rows[2].shown, "search filters the list")
    check(not picker.search.placeholder.shown, "typing hides the placeholder")
    wow.Click(picker.done)
    check(not picker:IsShown() and achievementCollections == 1, "Done closes the picker and collects again")

    -- Empty search, ancestry, unchanged close, and parent cancellation.
    namespace.GetAchievementCategories = function()
        return { { id = 92, name = "General" }, { id = 93, name = "Child", parentID = 92 } }
    end
    wow.Click(chooser.achievementCategories)
    check(picker.rows[2].Text.text == "General > Child", "picker shows category ancestry")
    check(picker.selection.text:find("1 categories selected", 1, true), "selection feedback counts roots")
    picker.search:SetText("no such category")
    picker.search.scripts.OnTextChanged(picker.search)
    check(picker.empty.shown and picker.empty.text:find("No categories match", 1, true), "empty search is explicit")
    local beforeClose = achievementCollections
    wow.Click(picker.done)
    check(achievementCollections == beforeClose, "unchanged picker does not restart collection")
    wow.Click(chooser.achievementCategories)
    check(picker.scroll.scrollPosition == 0, "reopened picker resets scrolling")
    check(not generate.enabled, "picker blocks generation until Done")
    chooser:Hide()
    check(not picker.shown and achievementCollections == beforeClose and not picker.search.focused,
        "parent close hides picker without restarting collection or retaining search focus")
    namespace.ShowExport()

    switch("achievements", false)
    check(not chooser.snapshot.achievements, "unchecking achievements discards the scan")
    check(not chooser.exportWarning.shown, "warning must disappear when achievements are unchecked")
    -- The compact copy above closed the chooser; reopen it to close it.
    namespace.ShowExport()
    pick(chooser.formatButton, "Import code")
    wow.Click(generate)
    wow.Click(chooser.closeButton)
    check(not chooser:IsShown(), "the header close button hides the chooser")
    check(not pendingExport and not chooser.generating, "closing cancels generation and clears busy state")
    namespace.ShowExport()
    wow.Click(generate)
    namespace.ShowExport()
    check(not pendingExport and not chooser.generating, "reopening discards an unfinished generation")
    check(historyCollections == 0, "opening chooser never scans optional quest history")
    local historyDone, historyCancelled, historyProgress
    namespace.CollectQuestHistory = function(callback, progress)
        historyDone, historyProgress = callback, progress
        return function() historyCancelled = true; historyDone = nil end
    end
    switch("questHistory", true)
    check(chooser.questHistoryLoading and not generate.enabled and generate.text == "Collecting...", "history loading disables generation")
    historyProgress(1200, "sorting")
    check(chooser.questCollectionStatus.text:find("Sorting quest history", 1, true), "history sorting shows progress")
    local achievementDone, achievementProgress
    namespace.CollectAchievements = function(callback, progress)
        achievementDone, achievementProgress = callback, progress
        return function() achievementDone = nil end
    end
    switch("achievements", true)
    achievementProgress(90, "retrying")
    historyProgress(1300, "names")
    check(chooser.questCollectionStatus.shown and chooser.achievementCollectionStatus.shown
        and chooser.questCollectionStatus.text:find("1,300 records", 1, true)
        and chooser.achievementCollectionStatus.text:find("90 records", 1, true),
        "concurrent collectors have independent status lines")
    historyDone({ available = true, entries = { { questID = 42, completed = true } } })
    check(not generate.enabled and chooser.achievementCollectionStatus.text:find("Retrying achievement reads", 1, true),
        "finishing history leaves achievement progress and busy state intact")
    achievementDone({ available = true, entries = {} })
    switch("achievements", false)
    check(chooser.snapshot.questHistory.entries[1].questID == 42 and generate.enabled, "history completion enables generation")
    switch("questHistory", false)
    check(not chooser.snapshot.questHistory and not chooser.questHistoryLoading, "unchecking discards history")
    switch("questHistory", true)
    chooser:Hide()
    check(historyCancelled and not historyDone and not chooser.questHistoryLoading, "closing cancels history collection")
    historyCancelled = false
    namespace.ShowExport()
    namespace.ShowExport()
    check(historyCancelled and chooser.questHistoryLoading, "reopening cancels the previous history scan")
    switch("questHistory", false)
    switch("questHistory", true)
    historyDone(nil, "test collection failure")
    check(chooser.snapshot.questHistory.available == false and generate.enabled,
        "collection failure exports explicit unavailable metadata rather than blocking all other sections")
    switch("questHistory", false)

    chooser.noticeMessage = "All export categories enabled."
    namespace.StorageProgress = { bank = { active = true, processed = 0, queued = true } }
    namespace.StorageChanged()
    check(chooser.storageLoading and not generate.enabled, "queued selected storage disables generation before reads start")
    check(chooser.exportWarning.text:find("Keep the storage window open", 1, true), "storage instruction outranks old action notice")
    namespace.StorageProgress = { bank = { active = true, processed = 80 } }
    namespace.StorageChanged()
    check(chooser.storageLoading and not generate.enabled, "selected storage scan disables export generation")
    check(chooser.rows.bank.count.text:find("80 slots", 1, true), "the chooser shows storage slot progress")
    check(chooser.exportWarning.text:find("Keep the storage window open", 1, true))
    check(chooser.exportWarning.points[1][5] ~= chooser.achievementCollectionStatus.points[1][5], "storage warning and achievement progress have distinct positions")
    namespace.StorageProgress = {}
    namespace.StorageChanged()
    check(not chooser.storageLoading and generate.enabled, "finishing storage re-enables generation")

    -- A guild capture finishing while the chooser is open must replace its
    -- unavailable snapshot, rather than requiring another chooser open.
    local previousCategoryInfo = namespace.GetExportCategoryInfo
    namespace.GetExportCategoryInfo = function(snapshot, category, ...)
        if category ~= "guildBank" then return previousCategoryInfo(snapshot, category, ...) end
        local section = snapshot.guildBank
        return { count = section and #(section.entries or {}) or 0, characters = 100,
            unavailable = not section or section.available == false }
    end
    chooser.snapshot.guildBank = { available = false, entries = {} }
    namespace.StorageProgress.guildBank = { active = true, processed = 0, queued = true }
    namespace.StorageChanged()
    check(not generate.enabled and chooser.rows.guildBank.count.text:find("Reading", 1, true))
    namespace.GetStorage = function(category)
        assert(category == "guildBank")
        return { available = true, entries = { { itemID = 300, tab = 1, slot = 1, stackCount = 8 } } }
    end
    namespace.StorageProgress.guildBank = nil
    namespace.StorageChanged("guildBank", true)
    check(chooser.snapshot.guildBank.available and generate.enabled)
    check(chooser.rows.guildBank.count.text:find("1 record", 1, true), "guild completion must replace Unavailable in the open chooser")
    namespace.GetExportCategoryInfo = previousCategoryInfo

    -- Ellesmere-style copy interaction: a smaller code popup, full selection,
    -- read-only contents, deferred click selection and no focus stolen after close.
    namespace.ShowExport()
    pick(chooser.formatButton, "Import code")
    wow.Click(generate)
    pendingExport()
    check(output.width == 520 and output.height == 334, "compact codes use the smaller popup")
    check(output.box.multiline and output.box.fontObject == "GameFontHighlightSmall")
    check(output.box.text == "HL1:test" and output.copyTarget == output.box)
    output.box:SetText("accidental edit")
    output.box.scripts.OnTextChanged(output.box, true)
    check(output.box.text == "HL1:test" and output.box.highlightedText, "editing must restore the original complete code")
    output.box:SetText("typed")
    output.box.scripts.OnChar(output.box, "x")
    check(output.box.text == "HL1:test")
    output.box.highlightedText = false
    output.box.scripts.OnEditFocusGained(output.box)
    check(output.box.highlightedText, "focus must select the whole export")
    local deferred = {}
    C_Timer = { After = function(_, callback) deferred[#deferred + 1] = callback end }
    output.box.highlightedText = false
    output.box.scripts.OnMouseUp(output.box)
    check(not output.box.highlightedText, "click selection must follow the native mouse handler")
    table.remove(deferred, 1)()
    check(output.box.highlightedText and output.box.focused)
    output.box.scripts.OnMouseUp(output.box)
    output:Hide()
    table.remove(deferred, 1)()
    check(not output.box.focused and not output.copyBox.focused, "a stale click must not steal focus after closing")
    C_Timer = nil
    local normalCompact = namespace.BuildExport
    namespace.BuildExport = function() return "HL1:" .. string.rep("a", 150000) end
    namespace.ShowExport()
    wow.Click(generate)
    pendingExport()
    check(output.width == 520 and output.height == 334 and output.copyTarget == output.copyBox)
    check(#output.copyBox.text == 150004 and output.copyBox.highlightedText, "large codes retain every byte in the copy target")
    check(output.preview.nonSpaceWrap and #output.preview.text < 1000, "unbroken code previews wrap without drawing the full payload")
    check(output.copyHint.text:find("Preview shown", 1, true), "the preview must not be mistaken for the copied payload")
    local fullLargeCode = output.copyBox.text
    local setCopyText, restoreCalls = output.copyBox.SetText, 0
    output.copyBox.SetText = function(self, text) restoreCalls = restoreCalls + 1 setCopyText(self, text) end
    setCopyText(output.copyBox, "accidental edit")
    output.copyBox.scripts.OnChar(output.copyBox, "x")
    output.copyBox.scripts.OnTextChanged(output.copyBox, true)
    check(output.copyBox.text == fullLargeCode and restoreCalls == 1, "large text must be restored once when both edit callbacks fire")
    output.copyBox.SetText = setCopyText
    output.copyBox.highlightedText = false
    output.copyBox.scripts.OnMouseUp(output.copyBox)
    check(output.copyBox.highlightedText and output.copyBox.text == fullLargeCode)
    namespace.BuildExport = normalCompact
    namespace.ShowExport()
    pick(chooser.formatButton, "Readable report")
    wow.Click(generate)
    check(output.width == 760 and output.height == 384 and output.box.height == 250, "Markdown keeps the readable report layout")
    local fullMarkdown = output.box.text
    output.box:SetText("accidental report edit")
    output.box.scripts.OnTextChanged(output.box, true)
    check(output.box.text == fullMarkdown)
    output.box.highlightedText = false
    output.box.scripts.OnMouseUp(output.box)
    check(output.box.highlightedText and output.box.text == fullMarkdown)

    -- Generation failures stay visible and give an actionable retry.
    namespace.ShowExport()
    local buildReport = namespace.BuildAIReport
    namespace.BuildAIReport = function() error("synthetic failure") end
    wow.Click(generate)
    check(chooser:IsShown() and chooser.exportWarning.shown and chooser.exportWarning.text:find("Refresh data", 1, true),
        "report failure stays inline with retry guidance")
    namespace.BuildAIReport = buildReport
    wow.Click(chooser.refresh)
    check(not chooser.errorMessage, "refresh clears stale failure feedback")
    wow.Click(generate)

    -- The copy workflow returns to current choices without leaving two windows open.
    wow.Click(output.back)
    check(chooser:IsShown() and not output:IsShown(), "Back to choices returns to the chooser")
    check(chooser.formatHelp.text:find("Start here", 1, true), "AI format guidance is explicit")
    local savedScope = achievementOptions.scope
    namespace.SetExportFormat("compact")
    namespace.SetWindowOpacity(0.8)
    wow.Click(chooser.enableAll)
    check(chooser.exportWarning.shown and chooser.exportWarning.text:find("All export categories enabled.", 1, true), "Enable all confirms inline")
    achievementDone({ entries = {}, available = true })
    historyDone({ entries = {}, available = true })
    check(chooser.exportWarning.text:find("about a minute", 1, true), "action notice retains achievement size guidance")
    pick(chooser.formatButton, "Readable report")
    check(chooser.noticeMessage == nil, "format change clears action confirmation")
    pick(chooser.formatButton, "Import code")
    check(namespace.db.options.achievements and namespace.db.options.questHistory, "Enable all includes both optional collectors")
    wow.Click(chooser.defaults)
    check(not namespace.db.options.achievements and not namespace.db.options.questHistory, "defaults restore both opt-in categories to off")
    check(namespace.GetExportFormat() == "compact" and namespace.GetWindowOpacity() == 0.8 and achievementOptions.scope == savedScope,
        "category reset keeps unrelated preferences")
    check(chooser.rows.questHistory.count.text == "Not included", "omitted is distinct from empty")
    chooser.snapshot.bank = { available = true, cached = true, partial = true, capturedAt = 1800000000,
        tabs = { { id = 1, status = "cached", capturedAt = 1799900000, reason = "Latest read incomplete" } } }
    namespace.StorageChanged()
    check(chooser.rows.bank.detail.text:find("Partly saved", 1, true), "cached partial observations are explicit")
    check(chooser.rows.bank.detail.text:find(os.date("%Y", 1800000000), 1, true), "saved observation timestamp includes its year")
    check(chooser.rows.bank.hint:find("Tab 1: cached", 1, true) and chooser.rows.bank.hint:find("Latest read incomplete", 1, true), "tooltip retains tab coverage and capture context")
    check(chooser.snapshot.bank.capturedAt == 1800000000 and chooser.snapshot.bank.tabs[1].capturedAt == 1799900000, "display does not change observation times")
    for _, scale in ipairs({ 0.7, 1.3 }) do
        namespace.HammerCore.State().settingsScale = scale
        chooser:Hide()
        namespace.ShowExport()
        check(chooser.appliedScale == scale, "standalone chooser follows Window scale on open")
    end
    namespace.SetWindowOpacity(1)

    -- Window opacity: solid by default; the settings slider applies it live
    -- to every window's backing and nothing else.
    check(namespace.GetWindowOpacity() == 1 and namespace.db.windowOpacity == 1, "windows default to fully solid")
    namespace.ShowExport()
    local HC = namespace.HammerCore
    HC.Settings:Show("Export")
    local slider
    for _, frame in ipairs(wow.frames) do
        local row = frame.parent
        if frame.kind == "Slider" and row and rawget(row, "Title") and row.Title.text == "Window opacity" then slider = frame end
    end
    check(slider and slider:GetValue() == 100, "the Export page has a Window opacity slider at 100")
    slider:SetValue(70)
    check(namespace.db.windowOpacity == 0.7, "the slider saves the opacity")
    check(chooser:IsShown() and chooser.hcBody.colour[4] == 0.7, "the open chooser's backing follows the slider")
    check(output.hcBody.colour[4] == 0.7 and picker.hcBody.colour[4] == 0.7, "every window's backing follows the slider")
    check(chooser:GetAlpha() == 1 and chooser.backdropColour[4] == 0, "text and controls stay opaque")
    check(namespace.SetWindowOpacity(0.2) and namespace.GetWindowOpacity() == 0.5, "opacity is clamped to 50%")
    check(namespace.SetWindowOpacity(1) and chooser.hcBody.colour[4] == 1)
    switch("achievements", false)
    chooser.categoryScroll.GetHeight = function() return 2000 end
    chooser.categoryScroll:SetVerticalScroll(0)
    switch("achievements", true)
    check(chooser.categoryScroll.scrollPosition == 0, "already visible achievement options do not move the list")
    switch("achievements", false)
    chooser.categoryScroll.GetHeight = function() return 300 end
    switch("achievements", true)
    check(chooser.categoryScroll.scrollPosition == chooser.expandedContentHeight - 300, "scroll reveals the options panel within the viewport")
end

run(false)
run(true)
io.write("HammerLink UI tests passed\n")
