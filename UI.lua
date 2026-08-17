local addonName, ns = ...

local dialog

local function createDialog()
    local f = CreateFrame("Frame", "HammerLinkExportFrame", UIParent, "BackdropTemplate")
    f:SetSize(700, 190)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32, insets = { left = 11, right = 11, top = 11, bottom = 11 } })
    f:Hide()
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOP", 0, -18)
    title:SetText("HammerLink export")
    local help = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    help:SetPoint("TOPLEFT", 24, -45)
    help:SetPoint("TOPRIGHT", -24, -45)
    help:SetJustifyH("LEFT")
    help:SetText("Copy this into Consecrated Hammer. It contains this character’s live gear, talent import and exact Great Vault state. It is local data: nothing is uploaded by the addon.")

    local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    box:SetPoint("TOPLEFT", 25, -78)
    box:SetPoint("BOTTOMRIGHT", -25, 42)
    box:SetTextInsets(8, 8, 8, 8)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    f.box = box

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(86, 22)
    close:SetPoint("BOTTOM", 0, 14)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    return f
end

function ns.ShowExport()
    local ok, output, rawLength = pcall(ns.BuildExport)
    if not ok then
        ns.Print("Export failed: " .. tostring(output))
        return
    end
    dialog = dialog or createDialog()
    dialog.box:SetText(output)
    dialog:Show()
    dialog.box:SetFocus()
    dialog.box:HighlightText()
    ns.Print(("export ready — %d characters after compression"):format(#output))
end
