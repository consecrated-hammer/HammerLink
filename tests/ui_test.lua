local namespace = {
    VERSION = "0.8.0-test",
    db = { options = {
        equipment = true, bagItems = true, currentSpellbook = true, talents = true, vault = true,
        currencyCaps = true, decorInventory = true, questLog = true,
        professionRecipes = true,
    } },
}

local categories = {
    "equipment", "bagItems", "currentSpellbook", "talents", "vault", "currencyCaps",
    "decorInventory", "questLog", "professionRecipes",
}
local counts = {
    equipment = 15, bagItems = 118, currentSpellbook = 96, talents = 1, vault = 8,
    currencyCaps = 6, decorInventory = 666, questLog = 24,
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
    function value:EnableMouse() end
    function value:EnableKeyboard() end
    function value:RegisterForDrag() end
    function value:SetPropagateKeyboardInput() end
    function value:SetMultiLine() end
    function value:SetAutoFocus() end
    function value:SetFontObject() end
    function value:SetAlpha(alpha) self.alpha = alpha end
    function value:SetTextInsets() end
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
    function value:Hide() self.shown = false end
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
function namespace.IsExportEnabled(category) return namespace.db.options[category] ~= false end
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
function namespace.GetExportCategoryInfo(_, category)
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
assert(chooser.summary.text:find("records across 9 categories", 1, true), "expected live selected-record total")
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
namespace.ShowOptions()
assert(chooser.shown and chooser.format == "compact", "expected the last selected format to be remembered")
aiOption.func()
assert(chooser.format == "ai" and namespace.db.exportFormat == "ai", "expected AI-readable selection to persist")
assert(chooser.summary.text:find("about", 1, true), "expected AI report character estimate")

local bagCheck = chooser.rows.bagItems.check
bagCheck:SetChecked(false)
bagCheck.scripts.OnClick(bagCheck)
assert(namespace.db.options.bagItems == false, "expected category selection to persist")
assert(chooser.summary.text:find("records across 8 categories", 1, true), "expected total to react to category changes")

local generate
for _, frame in ipairs(frames) do
    if frame.text == "Generate export" then generate = frame end
end
assert(generate, "expected Generate export button")
generate.scripts.OnClick()
assert(namespace.lastAI and namespace.lastAI.exportOptions.bagItems == false, "expected selected AI snapshot")
assert(HammerLinkExportFrame and HammerLinkExportFrame.box.text:find("# AI report", 1, true), "expected readable report in copy dialog")
assert(HammerLinkExportFrame.box.highlightedText, "expected complete output to be selected for copying")
assert(HammerLinkExportFrame.box.height == 250, "expected native multiline growth instead of a capped report height")

namespace.ShowOptions()
assert(chooser.shown and chooser.format == "ai", "expected /hl options compatibility to retain the selected format")
compactOption.func()
generate.scripts.OnClick()
assert(namespace.lastCompact and namespace.lastCompact.exportOptions.bagItems == false, "expected selected compact snapshot")
assert(HammerLinkExportFrame.box.text == "HL1:test", "expected compact code in the same copy dialog")

namespace.ShowAbout()
local about = HammerLinkAboutFrame
local forge
for _, frame in ipairs(frames) do
    if frame.text == "Forge another link" then forge = frame end
end
assert(about and about.shown and forge, "expected the About dialog and Forge another link button")
forge.scripts.OnClick()
assert(namespace.lastMessage and namespace.lastMessage:find("Tip: ", 1, true) == 1, "expected the forged tip to be printed to chat")
local displayedTip = namespace.lastMessage:sub(6)
local matchingTip
for _, frame in ipairs(frames) do
    if frame.text and frame.text:find("Tip:", 1, true) and frame.text:find(displayedTip, 1, true) then matchingTip = frame end
end
assert(matchingTip, "expected the chat tip to match the tip displayed in About")

print("HammerLink UI tests passed")
