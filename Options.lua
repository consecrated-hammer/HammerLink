local addonName, ns = ...
local HC = ns.HammerCore
local UI = HC.UI

-- HammerLink's own settings page.  The export chooser remains the place to
-- pick categories; this page holds the saved format and a way back to it.

-- One column: the format names are long.
HC.Settings:NewPage({ name = "Export", columns = 1, description = "Saved export preferences. Choose data in the export chooser." }, function(panel, y)
    _, y = UI.Header(panel, "Export preferences", y, "Interface\\Icons\\INV_Misc_Note_01")
    _, y = UI.Dropdown(panel, "Format", "Readable report for you or an AI chat; Import code for the Consecrated Hammer website. Also change this in the chooser or minimap menu. The last choice is remembered.", y,
        { "ai", "compact" }, { "Readable report", "Import code" },
        function() return ns.GetExportFormat() end,
        function(value) ns.SetExportFormat(value) end, nil, 150, 240)
    _, y = UI.Text(panel, "Format is shared with the chooser and minimap menu. Category choices are saved in the chooser.", y)
    _, y = UI.ActionButton(panel, y, "Open export chooser", function()
        HC.Settings:Hide()
        ns.ShowExport()
    end, "Choose data categories, achievements, quest history, bank storage and professions; generate and copy a report or Import code.", "primary", 180)
    _, y = UI.Header(panel, "Export windows", y)
    -- Percent steps: the slider's fill assumes a range wider than 1.
    _, y = UI.Slider(panel, "Window opacity", "How solid the export windows are.", y, 50, 100, 5,
        function() return math.floor(ns.GetWindowOpacity() * 100 + 0.5) end,
        function(value) ns.SetWindowOpacity(value / 100) end,
        function(value) return math.floor(value + 0.5) .. "%" end)
    _, y = UI.Header(panel, "Category defaults", y)
    local resetButton
    resetButton, y = UI.PageReset(panel, y, function()
        ns.ResetExportOptions()
        if ns.ExportChoicesChanged then ns.ExportChoicesChanged() end
    end, "Reset category defaults", "data category selections")
    resetButton:SetWidth(210)
    UI.AttachHint(resetButton, "Reset category defaults", "Reset only data category selections. Keeps format, window opacity, achievement scope, selected achievement categories and saved observations.")
    return y
end)
