local namespace = {}
local messages = {}

SlashCmdList = {}
function CreateFrame()
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end
function GetAddOnMetadata(_, key)
    return ({ Version = "0.3.0", Author = "consecrated-hammer" })[key]
end
function print(message) messages[#messages + 1] = message end

assert(loadfile("Core.lua"))("HammerLink", namespace)
assert(namespace.GetMetadata("Version") == "0.3.0", "expected addon metadata helper")

local exports, about, options = 0, 0, 0
namespace.ShowExport = function() exports = exports + 1 end
namespace.ShowAbout = function() about = about + 1 end
namespace.ShowOptions = function() options = options + 1 end

SlashCmdList.HAMMERLINK("export")
SlashCmdList.HAMMERLINK("about")
SlashCmdList.HAMMERLINK("options")
SlashCmdList.HAMMERLINK("")
assert(exports == 2, "expected bare and export commands to open export")
assert(about == 1, "expected about command to open About")
assert(options == 1, "expected options command to open export settings")

SlashCmdList.HAMMERLINK("help")
assert(#messages >= 3 and messages[#messages]:find("options", 1, true), "expected help to document options")

print("HammerLink core tests passed")
