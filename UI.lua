local addonName, ns = ...

local dialog

local function createDialog()
    local f = CreateFrame("Frame", "HammerLinkExportFrame", UIParent, "BackdropTemplate")
    f:SetSize(760, 360)
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
    help:SetText("Copy this into Consecrated Hammer. It contains equipped and bag gear, the active talent import and exact Great Vault state. It is local data: nothing is uploaded by the addon.")

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 25, -78)
    scroll:SetPoint("BOTTOMRIGHT", -42, 48)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    box:SetWidth(680)
    -- EditBox has no text-measurement API. A deliberately tall scroll child
    -- avoids text escaping the viewport while retaining a usable Close button.
    box:SetHeight(2048)
    box:SetTextInsets(8, 8, 8, 8)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(box)
    f.scroll = scroll
    f.box = box

    local copyHint = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    copyHint:SetPoint("BOTTOMLEFT", 26, 18)
    copyHint:SetText("Press Ctrl+C to copy")

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
    dialog.scroll:SetVerticalScroll(0)
    dialog:Show()
    dialog.box:SetFocus()
    dialog.box:HighlightText()
    ns.Print(("export ready — %d characters after compression"):format(#output))
end
