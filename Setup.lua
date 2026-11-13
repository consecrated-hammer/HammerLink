local addonName, ns = ...
local HC = ns.HammerCore

-- Declares HammerLink to HammerCore: commands, the minimap clicks (export,
-- and HammerCore's right-click menu), status, diagnostics and About.  The
-- export chooser stays HammerLink's own main tool; settings are HammerCore's
-- window.

local aboutTips = {
    "Every bag slot was inspected. The potions are innocent until opened.",
    "No network requests were made. The bits stayed home.",
    "The Great Vault remembers. HammerLink merely takes notes.",
    "Item links are tiny historical documents with an alarming number of colons.",
    "Your reagent bag has been perceived respectfully.",
    "Compression level nine: because character data deserves a snug blanket.",
    "The readable report speaks fluent robot, but remains perfectly legible to humans.",
}

-- Minimap right-click extras after HammerCore's settings item: open the
-- export chooser, and switch the saved format.  The format rows wait while an
-- export is being built, so it keeps the format it started with.
local FORMATS = { { "ai", "Readable report" }, { "compact", "Import code" } }

function ns.MinimapMenuItems()
    local items = { { text = "Export", func = function() ns.ShowExport() end }, { title = true, text = "Format" } }
    local busy = ns.IsExportGenerating and ns.IsExportGenerating() or false
    local current = ns.GetExportFormat()
    for _, entry in ipairs(FORMATS) do
        local value = entry[1]
        items[#items + 1] = { text = entry[2], checked = current == value, disabled = busy,
            func = function() ns.SetExportFormat(value) end }
    end
    return items
end

-- Highlights for HammerCore's What's new page, newest first. Every
-- CurseForge release gets an entry, fixes included (Kevin, 2026-11-09);
-- HammerCore's tools/whatsnew_check.py fails the release without one. A
-- `page` adds a link to that settings page.
local WHATS_NEW = {
    { version = "0.15.0", date = "2026-11-13", items = {
        { title = "A clearer export workflow", text = "Larger section headings, clear record counts and short setup summaries. Achievements start with All achievements unless you saved another scope. Controls scroll into view when enabled; category names and IDs are searchable.", kind = "improved", page = "Export" },
        { title = "Copy and adjust", text = "Back to choices returns from either copy window to your saved choices. Cached storage shows observation times and partial coverage. Large exports still copy their complete payload.", kind = "improved", page = "Export" },
    } },
    { version = "0.14.0", date = "2026-11-10", items = {
        { title = "Minimap menu", text = "Right-click the minimap button for Export, the export format and settings. Prefer straight to settings? Change Minimap right-click.",
            kind = "new", page = "Visibility" },
        { title = "Settings search", text = "Search box at the top of settings. Type a word, jump to the setting.",
            kind = "new" },
    } },
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
        -- Right-click is HammerCore's menu: settings, then these.
        menu = function() return ns.MinimapMenuItems() end,
    },
    status = function()
        local recipes = ns.GetProfessionRecipes and ns.GetProfessionRecipes() or nil
        return table.concat({
            "Export format: " .. (ns.GetExportFormat() == "ai" and "Readable report" or "Import code"),
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
