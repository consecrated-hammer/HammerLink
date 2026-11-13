package.path = "./tests/hammercore/?.lua;" .. package.path
local wow = require("wow")

local function equal(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function loadAddon(tocName, saved)
    wow.Install({ HammerLink = { Version = "0.8.8-dev1" } })
    C_Timer = { After = function() end }
    UnitFullName = function() return "Tester", "Realm" end
    time = function() return 1787200000 end
    GetBuildInfo = function() return "12.1.0", "1", "", 120100 end
    HammerLinkDB = saved
    local ns = {}
    for line in io.lines(tocName) do
        local entry = line:gsub("\r", ""):gsub("\\", "/")
        if entry:match("%.xml$") then
            wow.LoadHammerCore(entry:match("^(.*)/[^/]+$"), "HammerLink", ns)
        elseif entry:match("%.lua$") then
            assert(loadfile(entry))("HammerLink", ns)
        end
    end
    -- The event frame is the only unnamed frame with an OnEvent script at load.
    local events
    for _, frame in ipairs(wow.frames) do
        if frame.scripts.OnEvent and not events then events = frame end
    end
    events.scripts.OnEvent(events, "ADDON_LOADED", "HammerLink")
    return ns
end

for _, toc in ipairs({ "HammerLink.toc", "HammerLink_Camelot.toc" }) do
    local ns = loadAddon(toc, { schemaVersion = 2, options = {}, showStartupMessage = true, minimapAngle = 60 })
    local HC = ns.HammerCore
    equal(wow.LastPrint(), "HammerLink v0.8.8-dev1 loaded - type /hammerlink for settings, /hammerlink help for commands",
        toc .. ": standard login message")
    equal(HC.State().minimapAngle, 60, toc .. ": minimap position is kept")
    equal(HammerLinkDB.showStartupMessage, nil, toc .. ": the old startup key is removed")
    equal(SLASH_HAMMERLINK2, "/hl", toc .. ": /hl is registered")

    SlashCmdList.HAMMERLINK("")
    equal(HC.Settings:IsShown(), true, toc .. ": the bare command opens settings")
    local names = {}
    for _, spec in ipairs(HC.Settings.order) do names[#names + 1] = spec.name end
    equal(table.concat(names, ","), "Export,Visibility,What's new,Commands,Troubleshooting,About", toc .. ": rail order")
    local failures = {}
    for name, err in pairs(HC.Settings.errors) do failures[#failures + 1] = name .. ": " .. err end
    equal(table.concat(failures, "; "), "", toc .. ": every settings page builds")
    for _, spec in ipairs(HC.Settings.order) do
        HC.Settings:Show(spec.name)
        equal(HC.Settings.selected, spec.name, toc .. ": " .. spec.name .. " opens")
    end

    HC.Settings:Show("Export")
    local format = wow.FindButton("AI-readable report")
    equal(format ~= nil and format:GetWidth() >= 240, true, toc .. ": the format select fits its longest choice")

    -- Every Export control and useful chooser synonyms enter shared search.
    local labels = { "Saved format", "Window opacity", "Open export chooser", "Restore category defaults" }
    local indexed = {}
    for _, label in ipairs(labels) do
        local matches = HC.Settings:Search(label, 100)
        local found
        for _, match in ipairs(matches) do
            if match.page == "Export" and match.label == label then found = match end
        end
        equal(found ~= nil, true, toc .. ": searchable " .. label)
        equal(HC.Settings:Focus("Export", label) ~= nil, true, toc .. ": focus " .. label)
        indexed[label] = HC.Settings:Focus("Export", label)
    end
    for _, query in ipairs({ "bank storage", "professions", "quest history", "achievements", "HL1 snapshot" }) do
        local found = false
        for _, match in ipairs(HC.Settings:Search(query, 100)) do
            if match.page == "Export" and match.label == "Open export chooser" then found = true end
        end
        equal(found, true, toc .. ": chooser discoverable through " .. query)
    end
    for _, scale in ipairs({ 0.7, 1.3 }) do
        HC.State().settingsScale = scale
        HC.Settings:ApplyScale()
        HC.Settings:Show("Export")
        equal(HC.Settings.errors.Export, nil, toc .. ": Export builds at scale " .. scale)
    end
    HC.Settings:RefreshSearch()
    equal(HC.Settings:Focus("Export", "Saved format"), indexed["Saved format"], toc .. ": refresh has no stale registration")
    ns.SetExportFormat("compact")
    ns.SetWindowOpacity(0.75)
    ns.db.achievementOptions = { scope = "selected", categoryIDs = { 92 }, expansionCategoryIDs = { 96 } }
    ns.db.options.bagItems, ns.db.options.achievements, ns.db.options.questHistory = false, true, true
    local resetNotice = 0
    ns.ExportChoicesChanged = function() resetNotice = resetNotice + 1 end
    wow.Click(indexed["Restore category defaults"])
    equal(ns.db.options.bagItems and not ns.db.options.achievements and not ns.db.options.questHistory, true, toc .. ": default categories retain opt-in semantics")
    equal(ns.GetExportFormat(), "compact", toc .. ": reset keeps format")
    equal(ns.GetWindowOpacity(), 0.75, toc .. ": reset keeps opacity")
    equal(ns.db.achievementOptions.categoryIDs[1], 92, toc .. ": reset keeps achievement roots")
    equal(resetNotice, 1, toc .. ": reset notifies chooser")
    ns.SetExportFormat("ai")

    local opened = 0
    ns.ShowExport = function() opened = opened + 1 end
    wow.Click(indexed["Open export chooser"])
    equal(opened, 1, toc .. ": settings action opens chooser")
    equal(HC.Settings:IsShown(), false, toc .. ": action closes settings")
    opened = 0
    SlashCmdList.HAMMERLINK("export")
    equal(opened, 1, toc .. ": export opens the chooser")
    wow.Click(HC.Minimap.button, "LeftButton")
    equal(opened, 2, toc .. ": left-clicking the minimap button opens the chooser")

    -- Right-click is HammerCore's menu with HammerLink's extras after settings.
    equal(HC.Minimap.RightClickMode(), "menu", toc .. ": right-click opens the shared menu")
    local items = HC.Minimap:MenuItems()
    local labels = {}
    for _, item in ipairs(items) do labels[#labels + 1] = item.separator and "-" or item.text end
    equal(table.concat(labels, ","), "HammerLink settings,-,Export,Format,AI-readable report,Consecrated Hammer code",
        toc .. ": minimap menu items")
    items[3].func()
    equal(opened, 3, toc .. ": the menu's Export opens the chooser")
    equal(items[5].checked, true, toc .. ": the saved format is ticked")
    equal(items[6].checked, false, toc .. ": the other format is not ticked")
    items[6].func()
    equal(ns.GetExportFormat(), "compact", toc .. ": the menu switches the saved format")
    items = HC.Minimap:MenuItems()
    equal(items[6].checked and not items[5].checked, true, toc .. ": the menu follows the new format")
    items[5].func()
    equal(ns.GetExportFormat(), "ai", toc .. ": and back")
    wow.Click(HC.Minimap.button, "RightButton")
    equal(HC.Menu:IsShown(), true, toc .. ": right-clicking the minimap button opens the menu")
    HC.Menu:Close()

    SlashCmdList.HAMMERLINK("debug")
    equal(HC.Copy.frame.edit:GetText():find("Export format:", 1, true) ~= nil, true,
        toc .. ": debug includes HammerLink's report")
    for _, old in ipairs({ "options", "settings", "diagnostics", "loadmsg on" }) do
        SlashCmdList.HAMMERLINK(old)
        equal(wow.LastPrint(), "HammerLink: unknown command. Type /hammerlink help for the list.",
            toc .. ": old command '" .. old .. "' is removed")
    end
end

-- Every page also builds under HammerCore's Classic theme.
for _, toc in ipairs({ "HammerLink.toc", "HammerLink_Camelot.toc" }) do
    local ns = loadAddon(toc, { schemaVersion = 2, options = {}, hammerCore = { theme = "classic" } })
    local HC = ns.HammerCore
    -- Classic is switched off for players until it is reworked; keep it building.
    HC.Theme.registry.classic.available = true
    equal(HC.Theme.IsClassic(), true, toc .. ": classic theme is active")
    HC.Settings:Show()
    local failures = {}
    for name, err in pairs(HC.Settings.errors) do failures[#failures + 1] = name .. ": " .. err end
    equal(table.concat(failures, "; "), "", toc .. ": every settings page builds in classic")
    for _, spec in ipairs(HC.Settings.order) do
        HC.Settings:Show(spec.name)
        equal(HC.Settings.selected, spec.name, toc .. ": " .. spec.name .. " opens in classic")
    end
end

io.write("HammerLink addon tests passed\n")

-- Existing preferences survive a normal load, including explicit exclusions.
do
    local saved = { schemaVersion = 2, exportFormat = "compact", windowOpacity = 0.65,
        options = { equipment = false, bank = false, achievements = true, questHistory = true },
        achievementOptions = { scope = "currentExpansion", categoryIDs = { 92 }, expansionCategoryIDs = { 96 } },
        storageByCharacter = { fixture = { sentinel = true } }, hammerCore = { settingsScale = 1.3 } }
    local ns = loadAddon("HammerLink_Camelot.toc", saved)
    equal(ns.db, saved, "existing saved table retained")
    equal(ns.GetExportFormat(), "compact", "saved compact format survives load")
    equal(ns.GetWindowOpacity(), 0.65, "saved opacity survives load")
    equal(ns.IsExportEnabled("equipment"), false, "explicit exclusion survives load")
    equal(ns.IsExportEnabled("achievements") and ns.IsExportEnabled("questHistory"), true, "opt-ins survive load")
    equal(ns.GetAchievementOptions().expansionCategoryIDs[1], 96, "expansion roots survive load")
    equal(ns.db.storageByCharacter.fixture.sentinel, true, "storage cache not reset")
    GetBuildInfo = function() return "1.60.1", "1", "", 16001 end
    for _, key in ipairs({ "vault", "currencies", "currencyCaps", "decorInventory" }) do
        equal(ns.IsExportSupported(key), false, "Forever excludes " .. key)
    end
end
