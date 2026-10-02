local _, ns = ...

-- API evidence and the serialized contract are in docs/achievements.md.
local LIMITS = { categories = 1024, achievements = 8192, criteria = 32768, criteriaPerAchievement = 256, calls = 100000 }
local SCOPES = { all = true, dungeons = true, currentExpansion = true, incomplete = true, selected = true }
local updates = 0
local events = CreateFrame("Frame")
for _, event in ipairs({ "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "RECEIVED_ACHIEVEMENT_LIST" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function() updates = updates + 1 end)

local function readable(value, kind)
    return not (issecretvalue and issecretvalue(value)) and type(value) == kind
end

local function number(value)
    return readable(value, "number") and value == value and value >= 0 and value < math.huge and value or nil
end

local function text(value)
    return readable(value, "string") and value or nil
end

local function boolean(value)
    if readable(value, "boolean") then return value end
end

local function state(value)
    if value == true then return "complete" end
    if value == false then return "incomplete" end
    return "unknown"
end

function ns.GetAchievementOptions()
    local saved = ns.db and ns.db.achievementOptions or {}
    if type(saved) ~= "table" then saved = {} end
    local value = { scope = SCOPES[saved.scope] and saved.scope or "dungeons", categoryIDs = {}, expansionCategoryIDs = {} }
    for _, key in ipairs({ "categoryIDs", "expansionCategoryIDs" }) do
        local seen = {}
        for _, id in ipairs(type(saved[key]) == "table" and saved[key] or {}) do
            if number(id) and id > 0 and id % 1 == 0 and not seen[id] and #value[key] < LIMITS.categories then
                seen[id] = true
                value[key][#value[key] + 1] = id
            end
        end
        table.sort(value[key])
    end
    return value
end

function ns.SetAchievementScope(scope)
    if not ns.db or not SCOPES[scope] then return false end
    ns.db.achievementOptions = ns.GetAchievementOptions()
    ns.db.achievementOptions.scope = scope
    return true
end

function ns.ToggleAchievementCategory(id)
    local options = ns.GetAchievementOptions()
    local key = options.scope == "currentExpansion" and "expansionCategoryIDs" or "categoryIDs"
    local found = false
    for index, value in ipairs(options[key]) do
        if value == id then table.remove(options[key], index) found = true break end
    end
    if not found then options[key][#options[key] + 1] = id end
    ns.db.achievementOptions = options
end

function ns.GetAchievementCategories()
    if not GetCategoryList or not GetCategoryInfo then return {}, false end
    local ok, ids = pcall(GetCategoryList)
    if not ok or not readable(ids, "table") then return {}, false end
    local categories = {}
    for index, id in ipairs(ids) do
        if index > LIMITS.categories then break end
        if number(id) then
            local got, name, parent, flags = pcall(GetCategoryInfo, id)
            categories[#categories + 1] = { id = id, name = got and text(name) or nil,
                parentID = got and readable(parent, "number") and parent or nil,
                flags = got and number(flags) or nil }
        end
    end
    table.sort(categories, function(a, b) return a.id < b.id end)
    return categories, true, #ids > LIMITS.categories
end

local function collector(options)
    local result = {
        schemaVersion = 1, available = false, capturedAt = time(), collectionStartedAt = time(),
        scope = "client_enumerable_personal_achievements", absenceMeans = "unknown_never_completed",
        filters = options, entries = {}, categories = {}, failedCategories = {}, failedAchievements = {},
        summary = { exported = 0, complete = 0, incomplete = 0, unknown = 0, excludedComplete = 0,
            criteriaExported = 0, criteriaFailures = 0, achievementFailures = 0 },
        truncated = false, truncationReasons = {}, limits = LIMITS,
        coverage = "partial_client_enumeration", hiddenCoverage = "not_guaranteed",
        completionBasis = "client_account_completion", criteriaCompletionBasis = "client_reported_scope_unknown",
    }
    local revision, calls = updates, 0
    local function finish()
        result.collectionFinishedAt = time()
        result.changedDuringCollection = updates ~= revision
        return result
    end
    local function truncate(reason)
        result.truncated = true
        result.truncationReasons[reason] = true
    end
    local function call(fn, ...)
        calls = calls + 1
        if calls % 100 == 0 then coroutine.yield(#result.entries) end
        if calls > LIMITS.calls then truncate("api_call_limit") return false end
        if type(fn) ~= "function" then return false end
        return pcall(fn, ...)
    end
    local categories, available, categoryTruncated = ns.GetAchievementCategories()
    result.categories = categories
    if not available or not GetCategoryNumAchievements or not GetAchievementInfo then
        result.reason = "Achievement category enumeration is unavailable in this client."
        return finish()
    end
    if categoryTruncated then truncate("category_limit") end
    local byID = {}
    for _, category in ipairs(categories) do byID[category.id] = category end
    local roots = {}
    if options.scope == "dungeons" then roots = { 168 }
    elseif options.scope == "selected" then roots = options.categoryIDs
    elseif options.scope == "currentExpansion" then
        roots = options.expansionCategoryIDs
        result.filters.expansionSelection = "player_selected_category_roots"
        local ok, level = call(GetClientDisplayExpansionLevel)
        if ok then result.filters.clientExpansionLevel = number(level) end
    end
    if (options.scope == "selected" or options.scope == "currentExpansion") and #roots == 0 then
        result.reason = "Choose category roots for this achievement scope. Current expansion categories must be selected for this client."
        return finish()
    end
    local function ancestry(id)
        local path, seen = {}, {}
        while id and id ~= -1 and not seen[id] and #path < 32 do
            seen[id] = true
            local category = byID[id]
            if not category then
                local ok, name, parent, flags = call(GetCategoryInfo, id)
                category = { id = id, name = ok and text(name) or nil,
                    parentID = ok and readable(parent, "number") and parent or nil,
                    flags = ok and number(flags) or nil }
                byID[id] = category
            end
            path[#path + 1] = category
            id = category.parentID
        end
        return path, id == -1
    end
    local function inScope(path)
        if #roots == 0 then return true end
        for _, category in ipairs(path) do
            for _, root in ipairs(roots) do if category.id == root then return true end end
        end
        return false
    end
    for _, root in ipairs(roots) do
        if not byID[root] or not byID[root].name then
            result.failedCategories[#result.failedCategories + 1] = { categoryID = root, reason = "scope_root_unavailable" }
        end
    end
    local seen, criteriaTotal = {}, 0
    local function flag(flags, mask)
        if flags and number(mask) and mask > 0 then return flags % (mask * 2) >= mask end
    end
    local function addAchievement(id, fallbackCategory)
        if seen[id] then return end
        seen[id] = true
        if #result.entries >= LIMITS.achievements then truncate("achievement_limit") return end
        local ok, actualID, name, _, completed, month, day, year, description, flags, _, _, isGuild, earnedByMe, _, isStatistic = call(GetAchievementInfo, id)
        if not ok or not number(actualID) or not text(name) then
            result.summary.achievementFailures = result.summary.achievementFailures + 1
            if #result.failedAchievements < 256 then result.failedAchievements[#result.failedAchievements + 1] = id end
            return
        end
        if boolean(isGuild) == true or boolean(isStatistic) == true then return end
        local catOK, categoryID = call(GetAchievementCategory, actualID)
        categoryID = catOK and number(categoryID) or fallbackCategory
        local path, pathComplete = ancestry(categoryID)
        if not inScope(path) then return end
        completed = boolean(completed)
        if options.scope == "incomplete" and completed == true then
            result.summary.excludedComplete = result.summary.excludedComplete + 1
            return
        end
        flags = number(flags)
        local entry = { achievementID = actualID, name = name, description = text(description),
            completed = completed, completionState = state(completed), completedByCharacter = boolean(earnedByMe),
            categoryID = categoryID, categoryName = path[1] and path[1].name,
            parentCategoryID = path[1] and path[1].parentID, parentCategoryName = path[2] and path[2].name,
            categoryPath = path, categoryPathComplete = pathComplete, rawFlags = flags,
            accountWide = flag(flags, ACHIEVEMENT_FLAGS_ACCOUNT or 131072),
            hiddenWhenIncomplete = flag(flags, ACHIEVEMENT_FLAGS_HIDE_INCOMPLETE or 2048),
            criteria = {}, criteriaAvailable = false, criteriaTruncated = false }
        entry.characterCompletionState = state(entry.completedByCharacter)
        entry.ownership = entry.accountWide == true and "account_wide_warband" or (entry.accountWide == false and "character_specific" or "unknown")
        -- Category membership is the client UI's classification, not a guessed flag.
        if pathComplete then entry.featOfStrength = false entry.legacy = false end
        for _, category in ipairs(path) do
            if category.id == 81 then entry.featOfStrength = true end
            if category.id == 15234 then entry.legacy = true end
        end
        if completed == true and number(month) and month >= 1 and month <= 12 and month % 1 == 0
            and number(day) and day >= 1 and day <= 31 and day % 1 == 0 and number(year) and year % 1 == 0 then
            entry.completionDate = { month = month, day = day, year = year, yearBasis = "client_year_since_2000" }
        end
        local countOK, count
        if calls >= LIMITS.calls then
            entry.criteriaTruncated = true truncate("api_call_limit")
        else
            countOK, count = call(GetAchievementNumCriteria, actualID, true)
        end
        if countOK and number(count) then
            entry.criteriaAvailable = true
            entry.criteriaTotal = count
            for index = 1, math.min(count, LIMITS.criteriaPerAchievement) do
                if calls >= LIMITS.calls then entry.criteriaTruncated = true truncate("api_call_limit") break end
                if criteriaTotal >= LIMITS.criteria then entry.criteriaTruncated = true truncate("criteria_limit") break end
                local got, detail, kind, done, quantity, required, _, criterionFlags, assetID, quantityString, criterionID = call(GetAchievementCriteriaInfo, actualID, index, true)
                local criterion = { index = index, criteriaID = got and number(criterionID) or nil,
                    description = got and text(detail) or nil, criteriaType = got and number(kind) or nil,
                    completed = got and boolean(done) or nil, current = got and number(quantity) or nil,
                    required = got and number(required) or nil, rawFlags = got and number(criterionFlags) or nil,
                    assetID = got and number(assetID) or nil, progressText = got and text(quantityString) or nil }
                -- Do not use Lua's and/or idiom for false completion values.
                if got then criterion.completed = boolean(done) end
                criterion.completionState = state(criterion.completed)
                criterion.available = got and text(detail) ~= nil or false
                if not criterion.available then result.summary.criteriaFailures = result.summary.criteriaFailures + 1 end
                entry.criteria[#entry.criteria + 1] = criterion
                criteriaTotal = criteriaTotal + 1
            end
            if count > LIMITS.criteriaPerAchievement then entry.criteriaTruncated = true truncate("criteria_per_achievement_limit") end
        elseif not entry.criteriaTruncated then
            result.summary.criteriaFailures = result.summary.criteriaFailures + 1
        end
        result.entries[#result.entries + 1] = entry
    end
    for _, category in ipairs(categories) do
        if calls >= LIMITS.calls then truncate("api_call_limit") break end
        local path, pathComplete = ancestry(category.id)
        if not category.name then
            result.failedCategories[#result.failedCategories + 1] = { categoryID = category.id, reason = "metadata_unavailable" }
        end
        if category.name and not pathComplete then
            result.failedCategories[#result.failedCategories + 1] = { categoryID = category.id, reason = "ancestry_unavailable" }
        end
        if category.name and inScope(path) then
            -- includeAll includes progressive achievements; also walk links to
            -- recover ranks a client exposes only via previous/next references.
            local ok, count = call(GetCategoryNumAchievements, category.id, true)
            if not ok or not number(count) then
                result.failedCategories[#result.failedCategories + 1] = { categoryID = category.id, reason = "enumeration_failed" }
            else
                result.available = true
                for index = 1, math.min(count, LIMITS.achievements) do
                    if calls >= LIMITS.calls then truncate("api_call_limit") break end
                    local got, id = call(GetAchievementInfo, category.id, index)
                    if got and number(id) and id > 0 then
                        local queue, queued = { id }, { [id] = true }
                        local cursor = 1
                        while cursor <= #queue and cursor <= LIMITS.achievements and calls < LIMITS.calls do
                            local current = queue[cursor]
                            cursor = cursor + 1
                            if not seen[current] then
                                addAchievement(current, category.id)
                                for _, getter in ipairs({ GetPreviousAchievement or false, GetNextAchievement or false }) do
                                    local linked, nextID = call(getter, current)
                                    if linked and number(nextID) and nextID > 0 and not queued[nextID] then
                                        queued[nextID] = true queue[#queue + 1] = nextID
                                    end
                                end
                            end
                        end
                        if cursor <= #queue then truncate("chain_limit") end
                    else
                        result.summary.achievementFailures = result.summary.achievementFailures + 1
                        if #result.failedCategories < LIMITS.categories then
                            result.failedCategories[#result.failedCategories + 1] = { categoryID = category.id, index = index, reason = "achievement_lookup_failed" }
                        end
                    end
                end
                if count > LIMITS.achievements then truncate("category_achievement_limit") end
            end
        end
    end
    table.sort(result.entries, function(a, b) return a.achievementID < b.achievementID end)
    ns.SummarizeAchievements(result)
    if not result.available then result.reason = "No selected category could be enumerated. Missing achievements remain unknown." end
    return finish()
end

function ns.SummarizeAchievements(value)
    local summary = value.summary
    summary.exported, summary.complete, summary.incomplete, summary.unknown, summary.criteriaExported = 0, 0, 0, 0, 0
    for _, entry in ipairs(value.entries) do
        summary.exported = summary.exported + 1
        summary[entry.completionState] = summary[entry.completionState] + 1
        summary.criteriaExported = summary.criteriaExported + #entry.criteria
    end
end

function ns.GetAchievements()
    local thread = coroutine.create(function() return collector(ns.GetAchievementOptions()) end)
    while true do
        local ok, value = coroutine.resume(thread)
        if not ok then error(value) end
        if coroutine.status(thread) == "dead" then return value end
    end
end

function ns.CollectAchievements(callback, progress)
    local options = ns.GetAchievementOptions()
    local thread = coroutine.create(function() return collector(options) end)
    local cancelled = false
    local function step()
        if cancelled then return end
        local ok, value = coroutine.resume(thread)
        if not ok then callback(nil, tostring(value)) return end
        if coroutine.status(thread) == "dead" then callback(value) return end
        if progress then progress(value) end
        if C_Timer and C_Timer.After then C_Timer.After(0, step) else step() end
    end
    step()
    return function() cancelled = true end
end

-- The AI report groups records under one category heading and lists criteria
-- only where the achievement is not complete. Every state stays explicit; the
-- full per-criterion IDs, types and flags remain in the compact HL1 export.
function ns.AchievementReport(value)
    local function clean(valueText)
        return (tostring(valueText or "unknown"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\r\n]+", " "))
    end
    local lines = { "## Achievements", "", "> An absent achievement is unknown, never evidence of completion. Only explicit client states establish completion.", "" }
    local function add(line) lines[#lines + 1] = line end
    if not value then add("Unavailable: achievements were not collected.") return table.concat(lines, "\n") end
    local summary = value.summary
    add("- Scope: " .. value.filters.scope .. "; completion filter uses client account completion.")
    if value.filters.scope == "dungeons" then
        add("- Category roots: 168 (Dungeons & Raids), including descendants.")
    elseif value.filters.scope == "all" or value.filters.scope == "incomplete" then
        add("- Category roots: every client-enumerable category.")
    else
        add("- Category roots: " .. table.concat(value.filters.scope == "currentExpansion" and value.filters.expansionCategoryIDs or value.filters.categoryIDs, ", "))
    end
    if value.filters.expansionSelection then add("- Current expansion categories: selected by the player for this client; no automatic expansion classification.") end
    add("- Captured at: Unix " .. value.capturedAt .. "; achievement schema version: " .. value.schemaVersion)
    add("- Exported: " .. summary.exported .. "; complete: " .. summary.complete .. "; incomplete: " .. summary.incomplete
        .. "; unknown: " .. summary.unknown .. "; criteria: " .. summary.criteriaExported)
    if summary.omittedForPayloadSize then add("- Omitted for payload size: " .. summary.omittedForPayloadSize) end
    add("- Truncated: " .. (value.truncated and "yes" or "no") .. "; changed during collection: " .. (value.changedDuringCollection and "yes" or "no"))
    add("- Criteria failures: " .. summary.criteriaFailures .. "; achievement lookup failures: " .. summary.achievementFailures)
    add("- Hidden achievement coverage is not guaranteed. All means all client-enumerable personal achievements; statistics and guild achievements are excluded.")
    if value.reason then add("- Unavailable: " .. clean(value.reason)) end
    -- One line per category and reason; a category can fail hundreds of lookups.
    local failures, failureOrder = {}, {}
    for _, failed in ipairs(value.failedCategories) do
        local key = failed.categoryID .. " (" .. failed.reason .. ")"
        if not failures[key] then failures[key] = 0 failureOrder[#failureOrder + 1] = key end
        failures[key] = failures[key] + 1
    end
    for _, key in ipairs(failureOrder) do
        add("- Category could not be enumerated: " .. key .. (failures[key] > 1 and (", " .. failures[key] .. " times") or ""))
    end
    if #value.failedAchievements > 0 then add("- Achievements that could not be read: " .. table.concat(value.failedAchievements, ", ")) end
    local reasons = {}
    for reason in pairs(value.truncationReasons) do reasons[#reasons + 1] = reason end
    table.sort(reasons)
    if #reasons > 0 then add("- Truncation reasons: " .. table.concat(reasons, ", ")) end
    if #value.entries == 0 then return table.concat(lines, "\n") end
    add("")
    add("How to read the list: achievements sit under their category path, root first, with category IDs in brackets."
        .. " Each line is `achievement ID name: client completion`, then the completion date (YYYY-MM-DD)."
        .. " \"This character\" or \"another character\" says who earned a completed achievement; \"earner unknown\" means the client did not say."
        .. " \"Warband\" marks account-wide achievements, \"ownership unknown\" means the flag was unreadable, and no mark means character-specific."
        .. " Criteria are listed only under achievements that are not complete, split into not done, done and unknown and separated by semicolons."
        .. " Numbers such as 3/10 are client-reported progress whose account or character scope is unknown.")

    local headings, order = {}, {}
    for index, entry in ipairs(value.entries) do
        local path = {}
        for depth = #entry.categoryPath, 1, -1 do
            local category = entry.categoryPath[depth]
            path[#path + 1] = clean(category.name) .. " [" .. category.id .. "]"
        end
        local heading = #path > 0 and table.concat(path, " > ") or ("Unknown category [" .. tostring(entry.categoryID or "unknown") .. "]")
        if not entry.categoryPathComplete then heading = heading .. " (ancestry incomplete)" end
        headings[entry] = heading
        order[index] = entry
    end
    table.sort(order, function(a, b)
        if headings[a] ~= headings[b] then return headings[a] < headings[b] end
        return a.achievementID < b.achievementID
    end)

    local current
    for _, entry in ipairs(order) do
        if headings[entry] ~= current then
            current = headings[entry]
            add("")
            add("### " .. current)
            add("")
        end
        local state = entry.completionState == "complete" and "complete" or ("**" .. entry.completionState .. "**")
        local date = entry.completionDate
        if date then state = state .. " " .. string.format("%04d-%02d-%02d", 2000 + date.year, date.month, date.day) end
        local tags = {}
        if entry.completionState == "complete" then
            tags[#tags + 1] = entry.completedByCharacter == true and "this character"
                or entry.completedByCharacter == false and "another character" or "earner unknown"
        end
        if entry.accountWide == true then tags[#tags + 1] = "warband"
        elseif entry.accountWide == nil then tags[#tags + 1] = "ownership unknown" end
        if entry.legacy then tags[#tags + 1] = "legacy" end
        if entry.featOfStrength then tags[#tags + 1] = "Feat of Strength" end
        if entry.hiddenWhenIncomplete then tags[#tags + 1] = "hidden until complete" end
        local line = "- " .. entry.achievementID .. " " .. clean(entry.name) .. ": " .. state
        if #tags > 0 then line = line .. "; " .. table.concat(tags, ", ") end
        if entry.completionState ~= "complete" then
            if entry.description then line = line .. " — " .. clean(entry.description) end
            add(line)
            if not entry.criteriaAvailable then add("  - Criteria unavailable") end
            local groups = { complete = {}, incomplete = {}, unknown = {} }
            for _, criterion in ipairs(entry.criteria) do
                local text = criterion.description and clean(criterion.description) or ""
                if not criterion.available then
                    text = "criterion " .. tostring(criterion.criteriaID or criterion.index) .. " unreadable"
                end
                if criterion.required and criterion.required > 1 then
                    text = (text ~= "" and text .. " " or "") .. tostring(criterion.current or "?") .. "/" .. criterion.required
                end
                if text == "" then text = "unnamed criterion" end
                local group = groups[criterion.completionState]
                group[#group + 1] = text
            end
            local total = #entry.criteria
            if #groups.incomplete > 0 then
                add("  - Not done (" .. #groups.incomplete .. " of " .. total .. "): " .. table.concat(groups.incomplete, "; "))
            end
            if #groups.complete > 0 then add("  - Done: " .. table.concat(groups.complete, "; ")) end
            if #groups.unknown > 0 then add("  - Unknown: " .. table.concat(groups.unknown, "; ")) end
            if entry.criteriaTruncated then add("  - Further criteria truncated") end
        else
            add(line)
        end
    end
    return table.concat(lines, "\n")
end
