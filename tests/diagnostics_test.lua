local namespace = {
    VERSION = "stale fallback",
    dbWasFresh = true,
    db = { schemaVersion = 2, minimapAngle = 225 },
    Minimap = { button = {
        IsShown = function() return true end,
        GetPoint = function()
            return "CENTER", { GetName = function() return "PrivateCharacterName" end },
                "CENTER", 4, -8
        end,
    } },
    GetMetadata = function(key) if key == "Version" then return "0.8.8" end end,
    IsForeverClient = function() return false end,
    IsExportSupported = function() return true end,
    IsExportEnabled = function() return true end,
    GetExportFormat = function() return "ai" end,
    GetProfessionRecipes = function()
        return { available = true, characterName = "PrivateCharacterName" }
    end,
}

Minimap = {
    GetWidth = function() return 140 end,
    GetHeight = function() return 140 end,
    GetEffectiveScale = function() return 1 end,
}
GetBuildInfo = function() return nil, nil, nil, 120100 end

assert(loadfile("Diagnostics.lua"))("HammerLink", namespace)
local report = namespace.BuildDiagnosticReport()
assert(report:find("Version: 0.8.8", 1, true), "expected the loaded TOC version")
assert(report:find("Target: Retail", 1, true), "expected client identification")
assert(report:find("Database: created this load", 1, true), "expected database state")
assert(report:find("Profession cache: available", 1, true), "expected cache availability")
assert(not report:find("PrivateCharacterName", 1, true), "diagnostics exposed character data")

namespace.IsForeverClient = function() return true end
namespace.dbWasFresh = false
report = namespace.BuildDiagnosticReport()
assert(report:find("Target: WoW Forever", 1, true), "expected Forever client identification")
assert(report:find("Database: loaded", 1, true), "expected persisted database state")

print("HammerLink diagnostics tests passed")
