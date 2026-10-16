local events, jobs, source, calls = nil, {}, { 9, 2, 9, 999999 }, 0
function CreateFrame()
    events = { RegisterEvent = function() end }
    function events:SetScript(_, handler) self.handler = handler end
    return events
end
time = function() return 1800000000 end
C_Timer = { After = function(_, job) jobs[#jobs + 1] = job end }
local secret = {}
issecretvalue = function(value) return value == secret end
C_QuestLog = {
    GetAllCompletedQuestIDs = function() calls = calls + 1; return source end,
    GetTitleForQuestID = function(id) if id == 2 then return "Second quest" end end,
}
local ns = {}
assert(loadfile("Numbers.lua"))("HammerLink", ns)
assert(loadfile("QuestHistory.lua"))("HammerLink", ns)
local value = ns.GetQuestHistory()
assert(value.available and #value.entries == 3 and value.entries[1].questID == 2 and value.entries[3].questID == 999999)
assert(value.entries[1].completed == true and value.entries[1].title == "Second quest")
assert(value.summary.duplicates == 1 and value.summary.titlesUnavailable == 2)
assert(value.absenceMeans == "unknown" and value.completionDatesAvailable == false)
source = {}
value = ns.GetQuestHistory()
assert(value.available and #value.entries == 0, "successfully empty is available")
source = secret
value = ns.GetQuestHistory()
assert(not value.available and value.enumerationRetried, "unreadable enumeration retries and stays unavailable")
C_QuestLog.GetAllCompletedQuestIDs = nil
GetQuestsCompleted = function() return { [55] = true, [12] = true, [13] = false } end
value = ns.GetQuestHistory()
assert(value.source == "GetQuestsCompleted" and #value.entries == 2 and value.entries[1].questID == 12)
assert(not value.truncated and value.summary.invalidRows == 0, "known false legacy entries are not lost completion flags")
GetQuestsCompleted = nil
assert(not ns.GetQuestHistory().available, "missing APIs do not imply empty history")
source = { 7, -1, "bad", secret, 0, 1.5 }
C_QuestLog.GetAllCompletedQuestIDs = function() calls = calls + 1; return source end
value = ns.GetQuestHistory()
assert(#value.entries == 1 and value.truncated and value.summary.invalidRows == 5)
source = {}
for id = 2000, 1, -1 do source[#source + 1] = id end
local done, phases = nil, {}
ns.CollectQuestHistory(function(result) done = result end, function(_, phase) phases[phase] = true end)
assert(not done, "collection starts on a later frame")
local ticks = 0
while #jobs > 0 do ticks = ticks + 1; table.remove(jobs, 1)() end
assert(done and #done.entries == 2000 and ticks > 50 and phases.sorting and phases.names)
for id, entry in ipairs(done.entries) do assert(entry.questID == id) end
local stripped = ns.QuestHistoryWithoutTitles(done)
assert(stripped.summary.titlesOmittedForSize == 1 and stripped.entries[2].title == nil and done.entries[2].title)
assert(stripped.entries[2000].completed and #stripped.entries == 2000)
local cancelled = ns.CollectQuestHistory(function() error("cancelled scan called back") end)
cancelled()
while #jobs > 0 do table.remove(jobs, 1)() end
-- A completion during enumeration replaces the old observation once only.
done, calls = nil, 0
ns.CollectQuestHistory(function(result) done = result end)
table.remove(jobs, 1)()
events.handler()
source = { 5 }
while #jobs > 0 do table.remove(jobs, 1)() end
assert(done.collectionAttempts == 2 and #done.entries == 1 and done.entries[1].questID == 5 and calls == 2)
-- Never drop IDs to keep names in the readable report.
local big = { available = true, entries = {}, summary = { titlesUnavailable = 0 }, truncated = false }
for id = 1, 2000 do big.entries[id] = { questID = id, completed = true, title = string.rep("x", 700) } end
local report = ns.QuestHistoryReport(big)
assert(report:find("Names omitted for size", 1, true) and report:find("- 2000: complete", 1, true))
assert(not report:find(string.rep("x", 700), 1, true) and big.entries[1].title)
local escaped = { available = true, summary = {}, entries = {
    { questID = 1, completed = true, title = "|Hquest:1|hLinked quest|h|n|T123:16|t" },
    { questID = 2, completed = true, title = "|cffffffff|r" },
} }
local cleaned = ns.QuestHistoryReport(escaped)
assert(cleaned:find("- 1: complete - Linked quest", 1, true) and not cleaned:find("|H", 1, true))
assert(not cleaned:find("- 2: complete - ", 1, true), "empty cleaned titles have no dangling suffix")
print("HammerLink quest history tests passed")

source = { 42 }
local cached = ns.GetQuestHistory()
local firstReport = ns.QuestHistoryReport(cached)
assert(firstReport == ns.QuestHistoryReport(cached), "report cache retains the same content")
cached.changedDuringCollection = true
assert(ns.QuestHistoryReport(cached):find("changed during collection: true", 1, true), "cached report keeps live coverage flags")
