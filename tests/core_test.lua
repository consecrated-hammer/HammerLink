local namespace = {}
local messages = {}

SlashCmdList = {}
local eventFrame
function CreateFrame()
    local frame = {
        RegisterEvent = function() end,
        SetScript = function(self, _, callback) self.callback = callback end,
    }
    eventFrame = frame
    return frame
end
function GetAddOnMetadata(_, key)
    return ({ Version = "0.3.0", Author = "consecrated-hammer" })[key]
end
function print(message) messages[#messages + 1] = message end
function time() return 1787200000 end
function UnitFullName() return "Bluehoof", "Dath'Remar" end
C_Timer = { After = function(_, callback) callback() end }
C_TradeSkillUI = {
    GetAllRecipeIDs = function() return { 1261659, 1261660, 1261661 } end,
    GetRecipeInfo = function(recipeID)
        if recipeID == 1261659 then return { name = "Ironforge Chandelier", learned = true } end
        if recipeID == 1261660 then return { name = "Unlearned Test", learned = false } end
    end,
    IsRecipeProfessionLearned = function(recipeID) return recipeID == 1261659 or recipeID == 1261661 end,
    GetProfessionInfoByRecipeID = function() return { professionID = 755, professionName = "Jewelcrafting", expansionName = "Classic", skillLevel = 100, maxSkillLevel = 100 } end,
    GetTradeSkillLineForRecipe = function() return 755, "Classic Jewelcrafting" end,
}

assert(loadfile("Core.lua"))("HammerLink", namespace)
assert(namespace.VERSION == "0.7.1", "expected the visible addon version")
assert(namespace.GetMetadata("Version") == "0.3.0", "expected addon metadata helper")
eventFrame.callback(nil, "ADDON_LOADED", "HammerLink")
assert(namespace.GetProfessionRecipes().available == false and namespace.db.professionRecipesByCharacter == nil, "expected an uncached export read to avoid SavedVariables writes")
namespace.db.professionRecipes = { lines = { stale = { recipes = { old = { recipeID = 1, name = "Unsafe legacy cache" } } } } }
assert(namespace.CaptureProfessionRecipes(), "expected opened profession recipes to be cached")
assert(namespace.db.professionRecipes == nil, "expected unsafe shared development cache to be discarded")
local professions = namespace.GetProfessionRecipes()
assert(professions.available and #professions.professions == 1, "expected profession cache export")
assert(professions.professions[1].name == "Classic Jewelcrafting", "expected skill line name")
assert(#professions.professions[1].recipes == 1 and professions.professions[1].recipes[1].recipeID == 1261659, "expected learned-only recipe cache")
UnitFullName = function() return "SecondCharacter", "Dath'Remar" end
local secondCharacter = namespace.GetProfessionRecipes()
assert(secondCharacter.available == false, "expected profession cache to stay scoped to the exporting character")

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
