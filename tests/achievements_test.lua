local ns = { db = { options = {} } }
function CreateFrame() return { RegisterEvent = function() end, SetScript = function() end } end
function time() return 1790900000 end
local ticks = {}
C_Timer = { After = function(_, callback) ticks[#ticks + 1] = callback end }
assert(loadfile("Achievements.lua"))("HammerLink", ns)
assert(ns.GetAchievementOptions().scope == "dungeons")
local categories = {
    [168] = { "Donjons et raids", -1 }, [900] = { "Expansion test", 168 },
    [81] = { "Tours de force", -1 }, [15234] = { "Héritage", -1 },
    [902] = { "Category fails", -1 },
}
function GetCategoryList() return { 902, 900, 168, 81, 15234 } end
function GetCategoryInfo(id) return unpack(categories[id] or {}) end
local categoryAchievements = { [168] = { 10 }, [900] = { 20, 10 }, [81] = { 30 }, [15234] = { 40 } }
function GetCategoryNumAchievements(id, includeAll)
    assert(includeAll == true, "must request all category achievements")
    if id == 902 then error("category not ready") end
    return #(categoryAchievements[id] or {})
end
local data = {
    [10] = { name = "Incomplete raid", completed = false, mine = false, category = 900, flags = 131072 },
    [11] = { name = "Previous rank", completed = true, mine = false, category = 900, flags = 0 },
    [12] = { name = "Next rank", completed = false, mine = false, category = 900, flags = 2048 },
    [20] = { name = "Unknown state", category = 900, flags = 0 },
    [30] = { name = "Feat", completed = false, mine = false, category = 81, flags = 0 },
    [40] = { name = "Legacy", completed = true, mine = true, category = 15234, flags = 0 },
}
function GetAchievementInfo(id, index)
    if index then id = (categoryAchievements[id] or {})[index] end
    local d = data[id]
    if not d then return end
    return id, d.name, 10, d.completed, d.completed and 10, d.completed and 2, d.completed and 26,
        "Description", d.flags, 1, "", false, d.mine, "Other character", false
end
function GetAchievementCategory(id) return data[id].category end
function GetPreviousAchievement(id) if id == 10 then return 11 elseif id == 11 then return 10 end end
function GetNextAchievement(id) if id == 10 then return 12 elseif id == 12 then return 10 end end
function GetAchievementNumCriteria(_, includeHidden) assert(includeHidden == true) return 2 end
function GetAchievementCriteriaInfo(_, index, includeHidden)
    assert(includeHidden == true)
    if index == 2 then return "Boss defeated", 0, true, 1, 1, nil, 0, 999, "1/1", 102 end
    return "Boss still required", 0, false, 0, 1, nil, 0, 998, "0/1", 101
end
local result = ns.GetAchievements()
assert(result.available and #result.entries == 4, "default must include descendants and all chain ranks, deduplicated")
assert(result.summary.complete == 1 and result.summary.incomplete == 2 and result.summary.unknown == 1)
local first = result.entries[1]
assert(first.achievementID == 10 and first.completed == false and first.completedByCharacter == false)
assert(first.accountWide == true and first.ownership == "account_wide_warband")
assert(first.categoryID == 900 and first.parentCategoryID == 168 and first.parentCategoryName == "Donjons et raids")
assert(first.criteria[1].completed == false and first.criteria[1].current == 0 and first.criteria[1].required == 1)
assert(first.criteria[1].criteriaID == 101 and first.criteria[2].completed == true)
assert(result.entries[2].completionDate.year == 26 and result.entries[2].completedByCharacter == false)
local report = ns.AchievementReport(result)
assert(report:find("- 10 Incomplete raid: **incomplete**; warband", 1, true))
assert(report:find("  - Not done (1 of 2): Boss still required\n  - Done: Boss defeated", 1, true))
assert(report:find("- 11 Previous rank: complete 2026-10-02; another character\n", 1, true),
    "completed achievements stay on one line without criteria")
assert(report:find("- 20 Unknown state: **unknown**", 1, true))
assert(report:find("### Donjons et raids [168] > Expansion test [900]", 1, true))
assert(report:find("never evidence of completion", 1, true))
local crafted = ns.GetAchievements()
crafted.failedCategories = {
    { categoryID = 92, reason = "achievement_lookup_failed" }, { categoryID = 92, reason = "achievement_lookup_failed" },
    { categoryID = 95, reason = "metadata_unavailable" },
}
crafted.entries[1].criteria = {
    { index = 1, available = true, description = "", completionState = "incomplete", completed = false, current = 0, required = 100 },
    { index = 2, available = true, description = "", completionState = "incomplete", completed = false, current = 0, required = 1 },
    { index = 3, criteriaID = 77, available = false, completionState = "unknown" },
}
local craftedReport = ns.AchievementReport(crafted)
assert(craftedReport:find("- Category could not be enumerated: 92 (achievement_lookup_failed), 2 times\n", 1, true))
assert(craftedReport:find("- Category could not be enumerated: 95 (metadata_unavailable)\n", 1, true))
assert(craftedReport:find("  - Not done (2 of 3): 0/100; unnamed criterion\n  - Unknown: criterion 77 unreadable", 1, true))
local _, headingCount = report:gsub("\n### ", "")
assert(headingCount == 1, "one heading per category path")

ns.SetAchievementScope("all")
result = ns.GetAchievements()
assert(#result.entries == 6 and #result.failedCategories == 1)
assert(result.entries[5].featOfStrength == true and result.entries[6].legacy == true)
ns.SetAchievementScope("incomplete")
result = ns.GetAchievements()
assert(#result.entries == 4 and result.summary.excludedComplete == 2 and result.summary.unknown == 1,
    "incomplete filter retains unknown records and explicitly excludes only true completions")
ns.SetAchievementScope("selected")
result = ns.GetAchievements()
assert(not result.available and #result.entries == 0)
ns.ToggleAchievementCategory(81)
result = ns.GetAchievements()
assert(result.available and #result.entries == 1 and result.entries[1].achievementID == 30)
ns.SetAchievementScope("currentExpansion")
assert(not ns.GetAchievements().available, "must not guess current expansion categories")
ns.ToggleAchievementCategory(900)
result = ns.GetAchievements()
assert(#result.entries == 4 and result.filters.expansionSelection == "player_selected_category_roots")

local previousCriteria = GetAchievementCriteriaInfo
GetAchievementCriteriaInfo = function(_, index) if index == 1 then error("not ready") end return previousCriteria(nil, index, true) end
result = ns.GetAchievements()
assert(result.entries[1].criteria[1].completionState == "unknown" and not result.entries[1].criteria[1].available)
assert(result.summary.criteriaFailures == 4)
GetAchievementCriteriaInfo = previousCriteria
GetAchievementNumCriteria = function() return 300 end
result = ns.GetAchievements()
assert(result.truncated and result.entries[1].criteriaTruncated and #result.entries[1].criteria == 256)

local completed, progressCounts = nil, {}
ns.CollectAchievements(function(value) completed = value end, function(count) progressCounts[#progressCounts + 1] = count end)
assert(not completed and #ticks > 0, "large scans must yield between frames")
assert(#progressCounts > 0 and type(progressCounts[1]) == "number", "each yield reports the records collected so far")
while #ticks > 0 do local tick = table.remove(ticks, 1) tick() end
assert(completed and #completed.entries == 4)
local cancelledResult
local cancel = ns.CollectAchievements(function(value) cancelledResult = value end)
cancel()
while #ticks > 0 do local tick = table.remove(ticks, 1) tick() end
assert(cancelledResult == nil)

-- Exhaust the work budget with repeated category indices. Unattempted
-- categories must be truncation, never reported as failed client reads.
ns.SetAchievementScope("all")
GetCategoryList = function()
    local ids = {}
    for id = 10000, 10019 do ids[#ids + 1] = id end
    return ids
end
local previousCategoryInfo = GetCategoryInfo
GetCategoryInfo = function(id)
    if id >= 10000 then return "Budget fixture", -1 end
    return previousCategoryInfo(id)
end
GetCategoryNumAchievements = function() return 8192 end
local previousAchievementInfo = GetAchievementInfo
GetAchievementInfo = function(id, index) return previousAchievementInfo(index and 10 or id) end
result = ns.GetAchievements()
assert(result.truncated and result.truncationReasons.api_call_limit)
assert(#result.failedCategories == 0 and result.summary.achievementFailures == 0,
    "call budget omissions are not failed enumeration")

GetCategoryList = nil
result = ns.GetAchievements()
assert(not result.available and result.summary.exported == 0 and result.reason)
print("HammerLink achievement tests passed")
