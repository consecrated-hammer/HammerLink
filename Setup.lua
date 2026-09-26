local addonName, ns = ...
local HC = ns.HammerCore

-- Declares HammerLink to HammerCore: commands, the minimap right-click
-- (export), status, diagnostics and About.  The export chooser stays
-- HammerLink's own main tool; settings are HammerCore's window.

local aboutTips = {
    "Every bag slot was inspected. The potions are innocent until opened.",
    "No network requests were made. The bits stayed home.",
    "The Great Vault remembers. HammerLink merely takes notes.",
    "Item links are tiny historical documents with an alarming number of colons.",
    "Your reagent bag has been perceived respectfully.",
    "Compression level nine: because character data deserves a snug blanket.",
    "The readable report speaks fluent robot, but remains perfectly legible to humans.",
}

HC:Init({
    name = "HammerLink",
    command = "hammerlink",
    aliases = { "hl" },
    savedVariable = "HammerLinkDB",
    db = function() return ns.db end,
    icon = "Interface\\AddOns\\HammerLink\\Textures\\HammerLink",
    legacy = {
        startupMessage = "showStartupMessage",
        minimapAngle = "minimapAngle",
    },
    clientLabel = function() return ns.IsForeverClient() and "WoW Forever" or "Retail" end,
    minimap = {
        icon = "Interface\\AddOns\\HammerLink\\Textures\\HammerLinkClean",
        rightClick = function() ns.ShowExport() end,
        rightClickLabel = "export",
    },
    status = function()
        local recipes = ns.GetProfessionRecipes and ns.GetProfessionRecipes() or nil
        return table.concat({
            "Export format: " .. (ns.GetExportFormat() == "ai" and "AI-readable report" or "Consecrated Hammer code"),
            "Profession cache: " .. (recipes and recipes.available and "available" or "not captured"),
        }, "\n")
    end,
    diagnostics = function() return ns.BuildDiagnosticReport() end,
    about = {
        note = "FROM THE LINKSMITH",
        tips = aboutTips,
        action = "Forge another link",
    },
})

HC.Commands:Add({ name = "export", section = "Export", help = "Choose and create an export",
    run = function() ns.ShowExport() end })
