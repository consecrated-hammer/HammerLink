local _, ns = ...

-- Positive completion flags, not a lifetime event log or an all-quest catalogue.
-- Cached titles enrich IDs but never determine whether a record is retained.
local MAX_QUESTS, MAX_ROWS = 131072, 262144
local revision = 0
local events = CreateFrame("Frame")
for _, event in ipairs({ "QUEST_TURNED_IN", "DAILY_QUESTS_RESET", "PLAYER_ENTERING_WORLD" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function() revision = revision + 1 end)

local function readable(value, kind)
    return not (issecretvalue and issecretvalue(value)) and type(value) == kind
end
local function validID(id)
    return readable(id, "number") and id > 0 and id < math.huge and id % 1 == 0
end

local function collect(yieldWork)
    local startedRevision = revision
    local result = {
        schemaVersion = 1, available = false, capturedAt = time(), collectionStartedAt = time(),
        scope = "client_reported_completed_quest_flags", absenceMeans = "unknown",
        coverage = "client_completion_flags_not_lifetime_history", completionBasis = "client_reported",
        completionDatesAvailable = false, repeatCountsAvailable = false,
        entries = {}, truncated = false, truncationReasons = {},
        limits = { quests = MAX_QUESTS, rows = MAX_ROWS },
        summary = { exported = 0, titlesExported = 0, titlesUnavailable = 0, invalidRows = 0, duplicates = 0 },
    }
    local function finish()
        result.collectionFinishedAt = time()
        result.changedDuringCollection = startedRevision ~= revision
        return result
    end
    local getter = C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs
    local legacy = type(getter) ~= "function"
    if legacy then getter = GetQuestsCompleted end
    if type(getter) ~= "function" then
        result.reason = "Completed quest enumeration is unavailable in this client."
        return finish()
    end
    result.source = legacy and "GetQuestsCompleted" or "C_QuestLog.GetAllCompletedQuestIDs"
    local ok, raw = pcall(getter)
    if not ok or not readable(raw, "table") then
        -- One delayed retry for an API that is temporarily not ready.
        yieldWork(0, "retrying", 0.25)
        result.enumerationRetried = true
        ok, raw = pcall(getter)
    end
    if not ok or not readable(raw, "table") then
        result.reason = "Completed quest enumeration failed; no empty history was inferred."
        return finish()
    end
    result.available = true
    local ids, seen, rows = {}, {}, 0
    for key, value in pairs(raw) do
        rows = rows + 1
        if rows > MAX_ROWS then
            result.truncated, result.truncationReasons.row_limit = true, true
            break
        end
        local id = legacy and key or value
        local valid = validID(id) and (not legacy or (readable(value, "boolean") and value == true))
        if valid then
            if seen[id] then result.summary.duplicates = result.summary.duplicates + 1
            elseif #ids >= MAX_QUESTS then
                result.truncated, result.truncationReasons.quest_limit = true, true
            else seen[id] = true; ids[#ids + 1] = id end
        elseif not (legacy and validID(key) and readable(value, "boolean") and value == false) then
            result.summary.invalidRows = result.summary.invalidRows + 1
        end
        if rows % 100 == 0 then yieldWork(#ids, "collecting") end
    end
    if result.summary.invalidRows > 0 then result.truncated, result.truncationReasons.unreadable_rows = true, true end
    raw, seen = nil, nil
    -- Bottom-up merge sort: yields outside comparators, including on Lua 5.1.
    local width, scratch, operations = 1, {}, 0
    while width < #ids do
        for start = 1, #ids, width * 2 do
            local left, middle, finishIndex = start, math.min(start + width, #ids + 1), math.min(start + 2 * width - 1, #ids)
            local right = middle
            for index = start, finishIndex do
                if left < middle and (right > finishIndex or ids[left] <= ids[right]) then
                    scratch[index], left = ids[left], left + 1
                else scratch[index], right = ids[right], right + 1 end
                operations = operations + 1
                if operations % 2000 == 0 then yieldWork(#ids, "sorting") end
            end
        end
        ids, scratch, width = scratch, ids, width * 2
    end
    local titleGetter = C_QuestLog and C_QuestLog.GetTitleForQuestID
    for index, id in ipairs(ids) do
        local entry = { questID = id, completed = true }
        if type(titleGetter) == "function" then
            local titleOK, title = pcall(titleGetter, id)
            if titleOK and readable(title, "string") and title ~= "" then
                entry.title = title
            end
        end
        result.entries[index] = entry
        if entry.title then result.summary.titlesExported = result.summary.titlesExported + 1
        else result.summary.titlesUnavailable = result.summary.titlesUnavailable + 1 end
        if index % 100 == 0 then yieldWork(index, "names") end
    end
    result.summary.exported = #result.entries
    -- Also prepare this when Compact is selected: switching to AI later must
    -- not synchronously render thousands of rows inside the dropdown click.
    ns.QuestHistoryReport(result, function(count) yieldWork(count, "reporting") end)
    return finish()
end

local function collection(yieldWork)
    local result = collect(yieldWork)
    result.collectionAttempts = 1
    if result.changedDuringCollection then
        yieldWork(0, "refreshing", 0.5)
        result = collect(yieldWork)
        result.collectionAttempts, result.changedOnInitialAttempt = 2, true
    end
    return result
end

function ns.GetQuestHistory()
    return collection(function() end)
end

function ns.CollectQuestHistory(callback, progress)
    local cancelled, thread = false, coroutine.create(function()
        return collection(function(count, phase, delay) coroutine.yield(count, phase, delay) end)
    end)
    local function step()
        if cancelled then return end
        local ok, value, phase, delay = coroutine.resume(thread)
        if not ok or coroutine.status(thread) == "dead" then
            thread = nil
            local done = callback
            callback, progress = nil, nil
            if ok then done(value) else done(nil, tostring(value)) end
        else
            if progress then
                local progressOK, progressError = pcall(progress, value, phase)
                if not progressOK then
                    local done = callback
                    cancelled = true
                    thread, callback, progress = nil, nil, nil
                    done(nil, tostring(progressError))
                    return
                end
            end
            C_Timer.After(delay or 0, step)
        end
    end
    C_Timer.After(0, step)
    return function() cancelled = true; thread, callback, progress = nil, nil, nil end
end

function ns.QuestHistoryWithoutTitles(source, checkpoint)
    local copy = {}
    for key, value in pairs(source) do copy[key] = value end
    copy.entries, copy.summary = {}, {}
    for key, value in pairs(source.summary or {}) do copy.summary[key] = value end
    local omitted = 0
    for index, entry in ipairs(source.entries or {}) do
        copy.entries[index] = { questID = entry.questID, completed = entry.completed }
        if entry.title then omitted = omitted + 1 end
        if checkpoint and index % 100 == 0 then checkpoint("serializing") end
    end
    copy.summary.titlesExported, copy.summary.titlesOmittedForSize = 0, omitted
    copy.titlePolicy = "ids_and_status_only_for_size"
    return copy
end

-- Pre-render the large body cooperatively during collection. Headers stay live
-- so a quest update during rendering is still reported on subsequent display.
local reportBodies = setmetatable({}, { __mode = "k" })
function ns.QuestHistoryReport(value, checkpoint)
    local header = "## Quest history\n\n"
    if not value or not value.available then return header .. "Unavailable: " .. (value and value.reason or "not collected") end
    local body = reportBodies[value]
    if not body then
        local lines, size, omitNames = {}, 0, value.titlePolicy ~= nil
        for index, entry in ipairs(value.entries) do
            local title = entry.title and entry.title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                :gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
                :gsub("|n", " "):gsub("[\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")
            local line = "- " .. entry.questID .. ": complete" .. (title and title ~= "" and (" - " .. title) or "")
            size = size + #line + 1
            lines[#lines + 1] = line
            if checkpoint and index % 100 == 0 then checkpoint(index) end
            if size > 1024 * 1024 then omitNames = true; break end
        end
        if omitNames then
            lines = {}
            for index, entry in ipairs(value.entries) do
                lines[index] = "- " .. entry.questID .. ": complete"
                if checkpoint and index % 100 == 0 then checkpoint(index) end
            end
        end
        body = { text = table.concat(lines, "\n"), namesOmitted = omitNames }
        reportBodies[value] = body
    end
    local lines = { header .. "Completed quest flags reported by this client. Absent IDs remain unknown.",
        "No completion dates or repeat counts are exposed. Resettable, hidden, alternate and account-related flags may be included.",
        "Exported: " .. ns.FormatCount(#value.entries) .. "; missing cached names: " .. ns.FormatCount(value.summary.titlesUnavailable or 0)
            .. "; truncated: " .. tostring(value.truncated) .. "; changed during collection: " .. tostring(value.changedDuringCollection), "" }
    if body.namesOmitted then lines[#lines + 1] = "Names omitted for size; all collected quest IDs and statuses retained." end
    local prefix = table.concat(lines, "\n")
    if body.prefix ~= prefix then
        body.prefix = prefix
        body.report = prefix .. "\n" .. body.text
    end
    return body.report
end
