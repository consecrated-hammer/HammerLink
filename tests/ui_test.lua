local namespace = {
    VERSION = "0.7.0-test",
    db = { options = {
        equipment = true, bagItems = true, talents = true, vault = true,
        currencyCaps = true, decorInventory = true, questLog = true,
        professionRecipes = true,
    } },
}

local categories = {
    "equipment", "bagItems", "talents", "vault", "currencyCaps",
    "decorInventory", "questLog", "professionRecipes",
}
local counts = {
    equipment = 15, bagItems = 118, talents = 1, vault = 8,
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
    function value:SetTextInsets() end
    function value:SetJustifyH() end
    function value:SetScrollChild(child) self.scrollChild = child end
    function value:SetVerticalScroll(position) self.scrollPosition = position end
    function value:SetFocus() self.focused = true end
    function value:HighlightText() self.highlightedText = true end
    function value:SetText(text) self.text = text end
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
    if template == "UICheckButtonTemplate" then value.Text = widget("FontString") end
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

function namespace.GetExportOptions() return namespace.db.options end
function namespace.IsExportEnabled(category) return namespace.db.options[category] ~= false end
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
assert(chooser.format == "compact" and chooser.compact.highlighted, "expected compact export to be the default")
assert(chooser.rows.bagItems.count.text:find("L118 records", 1, true), "expected locale-aware per-category counts")
assert(numberFormatCalls > 0, "expected Blizzard's number formatter")
assert(chooser.summary.text:find("records across 8 categories", 1, true), "expected live selected-record total")
assert(not chooser.rows.professionRecipes.warning.shown, "expected AI size warning to stay hidden for compact exports")

chooser.ai.scripts.OnClick()
assert(chooser.format == "ai" and chooser.ai.highlighted, "expected AI-readable format selection")
assert(chooser.rows.professionRecipes.warning.shown, "expected large rendered AI section warning")
assert(chooser.summary.text:find("about", 1, true), "expected AI report character estimate")

local bagCheck = chooser.rows.bagItems.check
bagCheck:SetChecked(false)
bagCheck.scripts.OnClick(bagCheck)
assert(namespace.db.options.bagItems == false, "expected category selection to persist")
assert(chooser.summary.text:find("records across 7 categories", 1, true), "expected total to react to category changes")

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
assert(chooser.shown and chooser.format == "compact", "expected /hl options compatibility to open the same chooser")
assert(not chooser.rows.professionRecipes.warning.shown, "expected large-section warning to clear when compact mode is restored")
generate.scripts.OnClick()
assert(namespace.lastCompact and namespace.lastCompact.exportOptions.bagItems == false, "expected selected compact snapshot")
assert(HammerLinkExportFrame.box.text == "HL1:test", "expected compact code in the same copy dialog")

print("HammerLink UI tests passed")
