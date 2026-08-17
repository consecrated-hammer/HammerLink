local addonName, ns = ...

local LibDeflate = LibStub("LibDeflate")

-- This encoder deliberately handles only values HammerLink emits. Keeping the
-- payload shape explicit avoids serialising arbitrary Blizzard tables whose
-- fields can change or become private between client patches.
local function quote(value)
    return '"' .. tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
end

local function encode(value)
    local kind = type(value)
    if kind == "string" then return quote(value) end
    if kind == "number" then return tostring(value) end
    if kind == "boolean" then return value and "true" or "false" end
    if kind ~= "table" then return "null" end

    local count, array = 0, true
    for key in pairs(value) do
        count = count + 1
        if type(key) ~= "number" or key < 1 or key > count or key % 1 ~= 0 then array = false end
    end
    if array then
        local values = {}
        for i = 1, count do values[i] = encode(value[i]) end
        return "[" .. table.concat(values, ",") .. "]"
    end
    local pairsOut = {}
    for key, item in pairs(value) do
        pairsOut[#pairsOut + 1] = quote(key) .. ":" .. encode(item)
    end
    table.sort(pairsOut)
    return "{" .. table.concat(pairsOut, ",") .. "}"
end

local EQUIPMENT_SLOTS = {
    { "HEAD", INVSLOT_HEAD }, { "NECK", INVSLOT_NECK }, { "SHOULDER", INVSLOT_SHOULDER },
    { "BACK", INVSLOT_BACK }, { "CHEST", INVSLOT_CHEST }, { "WRIST", INVSLOT_WRIST },
    { "HANDS", INVSLOT_HAND }, { "WAIST", INVSLOT_WAIST }, { "LEGS", INVSLOT_LEGS },
    { "FEET", INVSLOT_FEET }, { "FINGER_1", INVSLOT_FINGER1 }, { "FINGER_2", INVSLOT_FINGER2 },
    { "TRINKET_1", INVSLOT_TRINKET1 }, { "TRINKET_2", INVSLOT_TRINKET2 },
    { "MAIN_HAND", INVSLOT_MAINHAND }, { "OFF_HAND", INVSLOT_OFFHAND },
}

local function character()
    local name, realm = UnitFullName("player")
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or nil
    local _, equipped, overall = GetAverageItemLevel()
    return {
        name = name,
        realm = realm or GetRealmName(),
        region = GetCurrentRegion and GetCurrentRegion() or nil,
        class = class,
        level = UnitLevel("player"),
        specID = specID,
        equippedItemLevel = equipped,
        overallItemLevel = overall,
    }
end

local function equipment()
    local result = {}
    for _, descriptor in ipairs(EQUIPMENT_SLOTS) do
        local slot, inventorySlot = descriptor[1], descriptor[2]
        local link = GetInventoryItemLink("player", inventorySlot)
        if link then
            local itemID = C_Item.GetItemInfoInstant(link)
            result[#result + 1] = { slot = slot, itemID = itemID, link = link }
        end
    end
    return result
end

local function talentExport()
    local specIndex = GetSpecialization()
    if not specIndex or not C_ClassTalents or not C_Traits then return nil end
    local configID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then return nil end
    local ok, importString = pcall(C_Traits.GenerateImportString, configID)
    return ok and importString or nil
end

local function reward(rewardInfo)
    local value = { type = rewardInfo.type, id = rewardInfo.id, quantity = rewardInfo.quantity }
    if rewardInfo.itemDBID and C_WeeklyRewards and C_WeeklyRewards.GetItemHyperlink then
        value.link = C_WeeklyRewards.GetItemHyperlink(rewardInfo.itemDBID)
    end
    return value
end

local function vault()
    local snapshot = {
        capturedAt = time(),
        nextResetSeconds = GetQuestResetTime and GetQuestResetTime() or nil,
        currentPeriod = C_WeeklyRewards and C_WeeklyRewards.AreRewardsForCurrentRewardPeriod and C_WeeklyRewards.AreRewardsForCurrentRewardPeriod() or nil,
        hasAvailableRewards = C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards and C_WeeklyRewards.HasAvailableRewards() or nil,
        hasGeneratedRewards = C_WeeklyRewards and C_WeeklyRewards.HasGeneratedRewards and C_WeeklyRewards.HasGeneratedRewards() or nil,
        activities = {},
    }
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return snapshot end
    for _, activity in ipairs(C_WeeklyRewards.GetActivities() or {}) do
        local item = {
            type = activity.type, index = activity.index, id = activity.id,
            threshold = activity.threshold, progress = activity.progress,
            activityTierID = activity.activityTierID, level = activity.level,
            claimID = activity.claimID, raidString = activity.raidString, rewards = {},
        }
        for _, rewardInfo in ipairs(activity.rewards or {}) do item.rewards[#item.rewards + 1] = reward(rewardInfo) end
        snapshot.activities[#snapshot.activities + 1] = item
    end
    if C_WeeklyRewards.GetNumCompletedDungeonRuns then
        local heroic, mythic, mythicPlus = C_WeeklyRewards.GetNumCompletedDungeonRuns()
        snapshot.dungeonRuns = { heroic = heroic, mythic = mythic, mythicPlus = mythicPlus }
    end
    return snapshot
end

function ns.BuildSnapshot()
    return {
        format = 1,
        capturedAt = time(),
        character = character(),
        equipment = equipment(),
        talents = { importString = talentExport() },
        vault = vault(),
    }
end

function ns.BuildExport()
    local json = encode(ns.BuildSnapshot())
    local compressed = LibDeflate:CompressDeflate(json, { level = 9 })
    assert(compressed, "could not compress export")
    return ns.PREFIX .. LibDeflate:EncodeForPrint(compressed), #json
end
