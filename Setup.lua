local addonName, ns = ...
local HC = ns.HammerCore

-- Declares HammerLink to HammerCore: commands, the minimap clicks
-- (export and settings), status, diagnostics and About.  The export chooser stays
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

-- Highlights for HammerCore's What's new page, newest first. Every
-- CurseForge release gets an entry, fixes included (Kevin, 2026-11-09);
-- HammerCore's tools/whatsnew_check.py fails the release without one. A
-- `page` adds a link to that settings page.
local WHATS_NEW = {
    { version = "0.13.0", date = "2026-11-09", items = {
        { title = "A fresh coat of paint", text = "Settings got a new look: a cleaner header, switches, a Window scale slider and this What's new page.",
            kind = "improved" },
        { title = "Support links", text = "CurseForge, Discord and Buy me a coffee sit at the bottom of the settings window. Hide them on Visibility.",
            kind = "improved", page = "Visibility" },
        { title = "Export windows", text = "The export chooser, copy window and achievement picker match the new look, solid by default. Window opacity on the Export page if you like a peek through.",
            kind = "improved", page = "Export" },
    } },
    -- History: written after the fact for releases from before What's new.
    { version = "0.12.0", date = "2026-11-01", history = true, items = {
        "Export what your character bank, Warband Bank and guild bank held when you last opened them.",
    } },
    { version = "0.11.0", date = "2026-10-17", history = true, items = {
        "Quest history: every quest you've completed, alongside your current quest log.",
    } },
    { version = "0.10.0", date = "2026-10-02", history = true, items = {
        "Achievements in exports, from Dungeons & Raids up to everything the game will list.",
    } },
    { version = "0.9.0", date = "2026-09-26", history = true, items = {
        { text = "A settings window with your saved export format.", page = "Export" },
        "A lore quiz, and the same commands as every Consecrated Hammer addon.",
    } },
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
        leftClick = function() ns.ShowExport() end,
        leftClickLabel = "export",
        rightClick = function() HC.Settings:Toggle() end,
        rightClickLabel = "settings",
    },
    status = function()
        local recipes = ns.GetProfessionRecipes and ns.GetProfessionRecipes() or nil
        return table.concat({
            "Export format: " .. (ns.GetExportFormat() == "ai" and "AI-readable report" or "Consecrated Hammer code"),
            "Profession cache: " .. (recipes and recipes.available and "available" or "not captured"),
        }, "\n")
    end,
    diagnostics = function() return ns.BuildDiagnosticReport() end,
    whatsNew = WHATS_NEW,
    about = {
        note = "FROM THE LINKSMITH",
        tips = aboutTips,
        action = "Forge another link",
    },
})

HC.Commands:Add({ name = "export", section = "Export", help = "Choose and create an export",
    run = function() ns.ShowExport() end })
