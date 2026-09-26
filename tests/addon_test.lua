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
    equal(table.concat(names, ","), "Export,Visibility,Theme,Commands,Troubleshooting,About", toc .. ": rail order")
    local failures = {}
    for name, err in pairs(HC.Settings.errors) do failures[#failures + 1] = name .. ": " .. err end
    equal(table.concat(failures, "; "), "", toc .. ": every settings page builds")
    for _, spec in ipairs(HC.Settings.order) do
        HC.Settings:Show(spec.name)
        equal(HC.Settings.selected, spec.name, toc .. ": " .. spec.name .. " opens")
    end

    local opened = 0
    ns.ShowExport = function() opened = opened + 1 end
    SlashCmdList.HAMMERLINK("export")
    equal(opened, 1, toc .. ": export opens the chooser")
    wow.Click(HC.Minimap.button, "RightButton")
    equal(opened, 2, toc .. ": right-clicking the minimap button opens the chooser")

    SlashCmdList.HAMMERLINK("debug")
    equal(HC.Copy.frame.edit:GetText():find("Export format:", 1, true) ~= nil, true,
        toc .. ": debug includes HammerLink's report")
    for _, old in ipairs({ "options", "settings", "diagnostics", "loadmsg on" }) do
        SlashCmdList.HAMMERLINK(old)
        equal(wow.LastPrint(), "HammerLink: unknown command. Type /hammerlink help for the list.",
            toc .. ": old command '" .. old .. "' is removed")
    end
end

io.write("HammerLink addon tests passed\n")
