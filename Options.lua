local addonName, ns = ...
local HC = ns.HammerCore
local UI = HC.UI

-- HammerLink's own settings page.  The export chooser remains the place to
-- pick categories; this page holds the saved format and a way back to it.

-- One column: the format names are long.
HC.Settings:NewPage({ name = "Export", columns = 1, description = "What an export contains and how it reads." }, function(panel, y)
    _, y = UI.Header(panel, "Export", y, "Interface\\Icons\\INV_Misc_Note_01")
    _, y = UI.Dropdown(panel, "Format", "The AI-readable report is Markdown; the code is for Consecrated Hammer.", y,
        { "ai", "compact" }, { "AI-readable report", "Consecrated Hammer code" },
        function() return ns.GetExportFormat() end,
        function(value) ns.SetExportFormat(value) end, nil, 150, 240)
    -- Percent steps: the slider's fill assumes a range wider than 1.
    _, y = UI.Slider(panel, "Window opacity", "How solid the export windows are.", y, 50, 100, 5,
        function() return math.floor(ns.GetWindowOpacity() * 100 + 0.5) end,
        function(value) ns.SetWindowOpacity(value / 100) end,
        function(value) return math.floor(value + 0.5) .. "%" end)
    _, y = UI.Text(panel, "Choose categories in the export chooser; your choices are remembered.", y)
    _, y = UI.ActionButton(panel, y, "Open export chooser", function()
        HC.Settings:Hide()
        ns.ShowExport()
    end, "Pick categories and create an export.", "primary", 180)
    _, y = UI.PageReset(panel, y, function() ns.ResetExportOptions() end, "Reset export choices")
    return y
end)
