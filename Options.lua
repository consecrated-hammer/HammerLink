local addonName, ns = ...
local HC = ns.HammerCore
local UI = HC.UI

-- HammerLink's own settings page.  The export chooser remains the place to
-- pick categories; this page holds the saved format and a way back to it.

HC.Settings:NewPage({ name = "Export", description = "What an export contains and how it reads." }, function(panel, y)
    _, y = UI.Header(panel, "Export", y)
    _, y = UI.Dropdown(panel, "Format", "The AI-readable report is Markdown; the code is for Consecrated Hammer.", y,
        { "ai", "compact" }, { "AI-readable report", "Consecrated Hammer code" },
        function() return ns.GetExportFormat() end,
        function(value) ns.SetExportFormat(value) end, nil, 150, 240)
    _, y = UI.Text(panel, "Choose categories in the export chooser; your choices are remembered.", y)
    local open = UI.Button(panel, 180, 22, "primary")
    open:SetPoint("TOPLEFT", UI.PAD, y - 4)
    open:SetText("Open export chooser")
    open:SetScript("OnClick", function()
        HC.Settings:Hide()
        ns.ShowExport()
    end)
    y = y - 38
    _, y = UI.PageReset(panel, y, function() ns.ResetExportOptions() end, "Reset export choices")
    return y
end)
