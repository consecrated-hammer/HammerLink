local addonName, ns = ...

-- A native launcher, deliberately independent of LibDBIcon. HammerLink owns
-- its position regardless of which other addons happen to supply libraries.
ns.Minimap = {}
local Minimap_ = ns.Minimap
local ICON = "Interface\\AddOns\\HammerLink\\Textures\\HammerLinkClean"
local RADIUS = 80

function Minimap_:Create()
    if self.button then return self.button end
    local button = CreateFrame("Button", "HammerLinkMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:GetHighlightTexture():SetBlendMode("ADD")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetAllPoints()
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -7)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -7, 7)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    local function place(angle)
        local radians = math.rad(angle or 225)
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * RADIUS, math.sin(radians) * RADIUS)
    end
    local atan2 = math.atan2 or math.atan
    local function follow()
        local scale = Minimap:GetEffectiveScale()
        local cursorX, cursorY = GetCursorPosition()
        local mapX, mapY = Minimap:GetCenter()
        if not mapX or not mapY then return end
        local angle = math.deg(atan2(cursorY / scale - mapY, cursorX / scale - mapX))
        ns.db.minimapAngle = angle
        place(angle)
    end

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function() button:SetScript("OnUpdate", follow) end)
    button:SetScript("OnDragStop", function() button:SetScript("OnUpdate", nil); button.dragged = true end)
    button:SetScript("OnClick", function(_, mouseButton)
        if button.dragged then button.dragged = nil return end
        if mouseButton == "LeftButton" then
            ns.ShowExport()
        else
            ns.ShowAbout()
        end
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("HammerLink")
        GameTooltip:AddLine("Left-click: export", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Right-click: about HammerLink", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Drag: move this icon", 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    place(ns.db.minimapAngle)
    self.button = button
    return button
end
