local namespace = {
    VERSION = "0.8.0-test",
    db = { options = {
        equipment = true, bagItems = true, currentSpellbook = true, talents = true, vault = true,
        currencyCaps = true, currencies = true, reputations = true, decorInventory = true, questLog = true,
        professionRecipes = true,
    } },
}
namespace.IsExportSupported = function() return true end
namespace.IsForeverClient = function() return false end

local categories = {
    "equipment", "bagItems", "currentSpellbook", "talents", "vault", "currencyCaps", "currencies", "reputations",
    "decorInventory", "questLog", "professionRecipes",
}
local counts = {
    equipment = 15, bagItems = 118, currentSpellbook = 96, talents = 1, vault = 8,
    currencyCaps = 6, currencies = 14, reputations = 42, decorInventory = 666, questLog = 24,
    professionRecipes = 142,
}
local frames = {}

local function widget(kind, name, template)
    local value = { kind = kind, name = name, template = template, scripts = {}, shown = true }
    function value:SetSize(width, height) self.width, self.height = width, height end
    function value:SetWidth(width) self.width = width end
    function value:SetHeight(height) self.height = height end
    function value:SetPoint(...) self.point = { ... } end
    function value:ClearAllPoints() self.point = nil end
    function value:SetAllPoints() end
    function value:SetFrameStrata() end
    function value:SetBackdrop() end
    function value:SetBackdropColor() end
    function value:SetMovable() end
    function value:Enable() self.enabled = true end
    function value:Disable() self.enabled = false end
    function value:EnableMouse() end
    function value:EnableKeyboard() end
    function value:RegisterForDrag() end
    function value:SetPropagateKeyboardInput() end
    function value:SetMultiLine() end
    function value:SetAutoFocus() end
    function value:SetFontObject() end
    function value:SetAlpha(alpha) self.alpha = alpha end
    function value:SetTextInsets() end
    function value:SetTextColor() end
    function value:SetHighlightColor() end
    function value:SetWordWrap() end
    function value:SetMaxLines() end
    function value:SetJustifyH(justification) self.justifyH = justification end
    function value:SetJustifyV(justification) self.justifyV = justification end
    function value:SetScrollChild(child) self.scrollChild = child end
    function value:SetVerticalScroll(position) self.scrollPosition = position end
    function value:SetFocus() self.focused = true end
    function value:HighlightText() self.highlightedText = true end
    function value:SetText(text) self.text = text end
    function value:SetTexture(texture) self.texture = texture end
    function value:GetText() return self.text end
    function value:SetChecked(checked) self.checked = checked and true or false end
    function value:GetChecked() return self.checked end
    function value:SetScript(event, callback) self.scripts[event] = callback end
    function value:Show() self.shown = true end
    function value:Hide() self.shown = false if self.scripts.OnHide then self.scripts.OnHide() end end
    function value:SetShown(shown) self.shown = shown end
    function value:LockHighlight() self.highlighted = true end
    function value:UnlockHighlight() self.highlighted = false end
    function value:CreateFontString()
        local font = widget("FontString")
        frames[#frames + 1] = font
        return font
    end
    function value:CreateTexture()
        local texture = widget("Texture")
        frames[#frames + 1] = texture
        return texture
    end
    function value:SetAtlas(atlas) self.atlas = atlas end
    if template == "UICheckButtonTemplate" or template == "UIDropDownMenuTemplate" then value.Text = widget("FontString") end
    if name then _G[name] = value end
    frames[#frames + 1] = value
    return value
end

function CreateFrame(kind, name, parent, template) return widget(kind, name, template) end
UIParent = widget("Frame", "UIParent")
GameFontHighlight = "GameFontHighlight"
GameFontNormal = "GameFontNormal"
GameFontNormalSmall = "GameFontNormalSmall"
GameFontHighlightSmall = "GameFontHighlightSmall"
ChatFontNormal = "ChatFontNormal"
local numberFormatCalls = 0
BreakUpLargeNumbers = function(value)
    numberFormatCalls = numberFormatCalls + 1
    return "L" .. tostring(value)
end
GameTooltip = {
    SetOwner = function() end, SetText = function() end, AddLine = function() end,
    Show = function() end, Hide = function() end,
}

local activeDropdown
function UIDropDownMenu_SetWidth(frame, width) frame.dropdownWidth = width end
function UIDropDownMenu_Initialize(frame, callback)
    frame.dropdownInitializer = callback
    frame.items = {}
    activeDropdown = frame
    callback(frame)
    activeDropdown = nil
end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info) activeDropdown.items[#activeDropdown.items + 1] = info end
function UIDropDownMenu_SetSelectedValue(frame, value) frame.selectedValue = value end
function UIDropDownMenu_SetText(frame, value) frame.dropdownText = value end

function namespace.GetExportOptions() return namespace.db.options end
function namespace.IsExportEnabled(category)
    if category == "achievements" then return namespace.db.options[category] == true end
    return namespace.db.options[category] ~= false
end
local achievementOptions = { scope = "dungeons", categoryIDs = {}, expansionCategoryIDs = {} }
function namespace.GetAchievementOptions() return achievementOptions end
function namespace.SetAchievementScope(scope) achievementOptions.scope = scope end
function namespace.GetAchievementCategories() return {} end
local achievementCollections = 0
function namespace.CollectAchievements(callback)
    achievementCollections = achievementCollections + 1
    callback({ entries = { { achievementID = 1 } }, available = achievementOptions.scope ~= "all" })
    return function() end
end
function namespace.GetExportFormat() return namespace.db.exportFormat or "ai" end
function namespace.SetExportFormat(format)
    if format ~= "compact" and format ~= "ai" then return false end
    namespace.db.exportFormat = format
    return true
end
function namespace.ResetExportOptions()
    for _, category in ipairs(categories) do namespace.db.options[category] = true end
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
GetTime = function() return 20 end
local pendingExport, pendingProgress
function namespace.BuildExportAsync(snapshot, callback, progress)
    namespace.asyncCalls = (namespace.asyncCalls or 0) + 1
    pendingProgress = progress
    pendingExport = function() callback(namespace.BuildExport(snapshot), 0, snapshot) end
    return function() pendingExport = nil end
end
function namespace.FormatExportSummary() return "exported — test" end
function namespace.Print(message) namespace.lastMessage = message end
function namespace.GetMetadata() return nil end

assert(loadfile("UI.lua"))("HammerLink", namespace)

namespace.ShowExport()
local chooser = HammerLinkOptionsFrame
assert(chooser and chooser.shown, "expected the export chooser to open")
assert(chooser.format == "ai", "expected AI-readable export to be the default")
assert(chooser.formatDropdown.selectedValue == "ai" and chooser.formatDropdown.dropdownText == "AI-readable report", "expected the native dropdown to show the selected format")
assert(chooser.formatDropdown.dropdownWidth == 210, "expected the format dropdown to fit its text rather than span the panel")
assert(chooser.formatDropdown.Text.justifyH == "LEFT", "expected the selected dropdown value to be left-aligned")
assert(chooser.rows.bagItems.count.text:find("L118 records", 1, true), "expected locale-aware per-category counts")
assert(chooser.rows.talents.count.text:find("L1 record", 1, true), "expected singular per-category count wording")
assert(numberFormatCalls > 0, "expected Blizzard's number formatter")
assert(chooser.summary.text:find("records across 11 categories", 1, true), "expected live selected-record total")
assert(chooser.summary.text:find("about ", 1, true) and chooser.summary.text:find("KB", 1, true), "expected an approximate report size in KB")
assert(not chooser.summary.text:find("characters", 1, true), "expected the raw character estimate to be hidden")
assert(chooser.categoryScroll and chooser.categoryScroll.scrollChild == chooser.categoryContent, "expected a native scroll area for export categories")
assert(chooser.categoryContent.height >= #categories * 45, "expected the scroll child to grow with future categories")
assert(chooser.categoryScroll.point[1] == "BOTTOMRIGHT" and chooser.categoryScroll.point[2] == -52, "expected the scrollbar inset from the dialog border")
for _, category in ipairs(categories) do
    local icon = chooser.rows[category].icon
    assert(icon and icon.texture:find("Interface", 1, true) == 1, "expected a built-in category icon for " .. category)
    assert(icon.width == 28 and icon.height == 28, "expected a larger category icon for " .. category)
    assert(chooser.rows[category].check.width == 28 and chooser.rows[category].check.height == 28, "expected the checkbox aligned to the icon for " .. category)
    local title = chooser.rows[category].check.Text
    assert(title.height == 14 and title.justifyV == "TOP", "expected the label top-aligned for " .. category)
    assert(title.point[1] == "TOPLEFT" and title.point[2] == icon and title.point[3] == "TOPRIGHT", "expected the text block aligned to the icon top for " .. category)
end
assert(chooser.rows.professionRecipes.warning.shown, "expected large rendered AI section warning")
assert(not chooser.rows.professionRecipes.warning.tooltipText:find("still export normally", 1, true), "expected the redundant warning reassurance to be removed")
assert(chooser.rows.professionRecipes.warning.tooltipText:find("KB", 1, true) and not chooser.rows.professionRecipes.warning.tooltipText:find("characters", 1, true), "expected the large-section estimate in KB only")
assert(chooser.rows.professionRecipes.detail.text:find("One-time setup per character", 1, true), "expected a clear per-character recipe cache requirement")
assert(chooser.rows.professionRecipes.check.Text.text == "Learned recipes and techniques", "expected the profession category to cover non-recipe entries honestly")
assert(chooser.rows.professionRecipes.detail.text:find("Reopen it after learning something new", 1, true), "expected explicit profession cache refresh instructions")
assert(chooser.rows.professionRecipes.actionNotice and chooser.rows.professionRecipes.actionNotice.icon.atlas == "QuestNormal", "expected a native quest marker beside the required recipe action")
assert(chooser.rows.professionRecipes.actionNotice.point[1] == "LEFT" and chooser.rows.professionRecipes.actionNotice.point[2] == chooser.rows.professionRecipes.check.Text, "expected the recipe action marker attached to its label")
assert(chooser.rows.professionRecipes.actionNotice.point[5] == 2, "expected the recipe action marker nudged upward")

local compactOption, aiOption
for _, option in ipairs(chooser.formatDropdown.items) do
    if option.value == "compact" then compactOption = option end
    if option.value == "ai" then aiOption = option end
end
assert(compactOption and aiOption, "expected both export formats in the dropdown")
compactOption.func()
assert(chooser.format == "compact" and namespace.db.exportFormat == "compact", "expected compact selection to persist")
assert(chooser.formatDropdown.selectedValue == "compact" and chooser.formatDropdown.dropdownText == "Consecrated Hammer code", "expected dropdown selection to refresh")
assert(not chooser.rows.professionRecipes.warning.shown, "expected AI size warning to stay hidden for compact exports")
namespace.ShowExport()
assert(chooser.shown and chooser.format == "compact", "expected the last selected format to be remembered")
aiOption.func()
assert(chooser.format == "ai" and namespace.db.exportFormat == "ai", "expected AI-readable selection to persist")
assert(chooser.summary.text:find("about", 1, true), "expected AI report character estimate")

local bagCheck = chooser.rows.bagItems.check
bagCheck:SetChecked(false)
bagCheck.scripts.OnClick(bagCheck)
assert(namespace.db.options.bagItems == false, "expected category selection to persist")
assert(chooser.summary.text:find("records across 10 categories", 1, true), "expected total to react to category changes")

local generate
for _, frame in ipairs(frames) do
    if frame.text == "Generate export" then generate = frame end
end
assert(generate, "expected Generate export button")
assert(generate.enabled, "generation must be enabled when collection is ready")
generate.scripts.OnClick()
assert(namespace.lastAI and namespace.lastAI.exportOptions.bagItems == false, "expected selected AI snapshot")
assert(HammerLinkExportFrame and HammerLinkExportFrame.box.text:find("# AI report", 1, true), "expected readable report in copy dialog")
assert(HammerLinkExportFrame.box.highlightedText, "expected complete output to be selected for copying")
assert(HammerLinkExportFrame.box.height == 250, "expected native multiline growth instead of a capped report height")
local output = HammerLinkExportFrame
assert(output.scroll.shown and not output.copyScroll.shown and not output.preview.shown, "small reports keep the scrolling view")
assert(output.copyHint.text == "Press Ctrl+C to copy the complete report")
local smallReport = namespace.BuildAIReport
namespace.BuildAIReport = function(snapshot)
    return "# Large report\n" .. string.rep("- achievement line\n", 8000)
end
namespace.ShowExport()
generate.scripts.OnClick()
assert(not output.scroll.shown and output.copyScroll.shown and output.preview.shown, "large reports use the copy box")
assert(output.copyScroll.scrollChild == output.copyBox, "the copy box must be clipped by its scroll frame")
assert(#output.copyBox.text > 100000 and output.copyBox.focused and output.copyBox.highlightedText, "the whole report is selected for one copy")
assert(output.box.text == "" and output.preview.text:find("# Large report", 1, true))
assert(output.copyHint.text:find("Ctrl+C", 1, true) and output.copyHint.text:find("KB", 1, true))
output.copyBox.scripts.OnTextChanged(output.copyBox, true)
assert(#output.copyBox.text > 100000, "typing cannot change the report")
namespace.BuildAIReport = smallReport

namespace.ShowExport()
assert(chooser.shown and chooser.format == "ai", "expected reopening the chooser to retain the selected format")
compactOption.func()
generate.scripts.OnClick()
assert(chooser.generating and generate.text == "Generating...", "generation must show busy state")
assert(not generate.enabled, "generation must disable the button while exporting")
pendingProgress("compressing", 250, 1000)
assert(chooser.exportWarning.shown and chooser.exportWarning.text:find("compressing 25%", 1, true),
    "busy status must show advancing phase and percentage")
generate.scripts.OnClick()
assert(namespace.asyncCalls == 1, "repeat clicks must not launch another job")
pendingExport()
assert(not chooser.generating, "completion must clear busy state")
assert(generate.enabled, "completion must restore the button")
assert(namespace.lastCompact and namespace.lastCompact.exportOptions.bagItems == false, "expected selected compact snapshot")
assert(HammerLinkExportFrame.box.text == "HL1:test", "expected compact code in the same copy dialog")

-- About is HammerCore's standard page; see addon_test.lua.
assert(not chooser.exportWarning.shown, "warning must be hidden without achievements")
assert(achievementCollections == 0, "opening the chooser must not scan optional achievements")
assert(chooser.achievementScope.selectedValue == "dungeons", "default achievement scope is Dungeons & Raids")
aiOption.func()
local achievementCheck = chooser.rows.achievements.check
local immediateCollection = namespace.CollectAchievements
local completeCollection
local reportProgress
namespace.CollectAchievements = function(callback, progress)
    reportProgress = progress
    completeCollection = function() return immediateCollection(callback) end
    return function() completeCollection = nil end
end
achievementCheck:SetChecked(true)
achievementCheck.scripts.OnClick(achievementCheck)
assert(chooser.achievementLoading and not generate.enabled, "collection must disable Generate export")
assert(generate.text == "Collecting...", "the disabled button must say why")
assert(chooser.exportWarning.shown and chooser.exportWarning.text:find("Collecting achievements", 1, true))
reportProgress(1234)
assert(chooser.exportWarning.text:find("L1234 records so far", 1, true), "collection shows a running count")
completeCollection()
assert(not chooser.achievementLoading and generate.enabled, "finished collection must enable Generate export")
assert(generate.text == "Generate export" and chooser.exportWarning.text:find("about a minute", 1, true))
achievementCheck:SetChecked(false)
achievementCheck.scripts.OnClick(achievementCheck)
namespace.CollectAchievements = immediateCollection
achievementCollections = 0
achievementCheck:SetChecked(true)
achievementCheck.scripts.OnClick(achievementCheck)
assert(chooser.exportWarning.shown and chooser.exportWarning.text:find("about a minute", 1, true))
assert(chooser.exportWarning.point[2] == chooser.summary, "warning must sit above the record summary")
assert(achievementCollections == 1 and chooser.snapshot.achievements, "checking achievements collects the selected scope")
assert(chooser.rows.achievements.warning.shown and chooser.snapshot.exportOptions.achievements == true,
    "achievement size warnings must use the collected snapshot's live selection")
for _, option in ipairs(chooser.achievementScope.items) do if option.value == "all" then option.func() end end
assert(chooser.rows.achievements.count.text:find("Unavailable", 1, true), "failed achievement scans must show unavailable, not zero records")
for _, option in ipairs(chooser.achievementScope.items) do
    if option.value == "currentExpansion" then option.func() end
end
assert(chooser.achievementCategories.shown and chooser.achievementHint.text:find("current expansion categories", 1, true))
achievementCheck:SetChecked(false)
achievementCheck.scripts.OnClick(achievementCheck)
assert(not chooser.snapshot.achievements, "unchecking achievements discards the scan")
assert(not chooser.exportWarning.shown, "warning must disappear when achievements are unchecked")
compactOption.func()
generate.scripts.OnClick()
chooser:Hide()
assert(not pendingExport and not chooser.generating, "closing cancels generation and clears busy state")
namespace.ShowExport()
generate.scripts.OnClick()
namespace.ShowExport()
assert(not pendingExport and not chooser.generating, "reopening discards an unfinished generation")
print("HammerLink UI tests passed")
