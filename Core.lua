local addonName, ns = ...

_G.HammerLink = ns
ns.name = addonName
ns.VERSION = "0.2.0"
ns.PREFIX = "HL1:"

function ns.Print(message)
    print("|cfff2d493HammerLink:|r " .. tostring(message or ""))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, loadedName)
    if event == "ADDON_LOADED" then
        if loadedName ~= addonName then return end
        HammerLinkDB = HammerLinkDB or { schemaVersion = 1, minimapAngle = 225 }
        HammerLinkDB.minimapAngle = HammerLinkDB.minimapAngle or 225
        ns.db = HammerLinkDB
    elseif event == "PLAYER_LOGIN" and ns.Minimap then
        ns.Minimap:Create()
    end
end)

SLASH_HAMMERLINK1 = "/hammerlink"
SLASH_HAMMERLINK2 = "/hl"
SlashCmdList.HAMMERLINK = function(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "" or command == "export" then
        ns.ShowExport()
    elseif command == "help" then
        ns.Print("/hl export — copy your current character, equipped and bag gear, talents and Vault state")
    else
        ns.Print("Unknown command. Use /hl export.")
    end
end
