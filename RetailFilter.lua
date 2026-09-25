local _, LfgUtils = ...

local DUNGEON = 2
local RAID = 3
local ARENA = 4
local RATEDBG = 9
local DELVE = 121
local FILTER_WIDTH = 340
local FILTER_MIN_WIDTH = 250
local FILTER_MAX_WIDTH = 700
local FILTER_HEIGHT_FALLBACK = 428
local FILTER_OVERLAP = 8
local DROPDOWN_WIDTH = 100
local MAX_TIER = 11
local MAX_ROLE_COUNT = 30
local SPEC_AUGMENTATION = 1473
local STRATA_ORDER = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"}
local BLOODLUST_CLASSES = {["SHAMAN"] = true, ["MAGE"] = true, ["EVOKER"] = true, ["HUNTER"] = true}
local ACTIVE_APP_STATUS = {["applied"] = true, ["invited"] = true, ["inviteaccepted"] = true}
local ROLES = {"TANK", "HEALER", "DAMAGER"}
local ROLE_FALLBACK_NAMES = {["TANK"] = "Tank", ["HEALER"] = "Healer", ["DAMAGER"] = "Damage"}
local ROLE_ATLASES = {["TANK"] = "groupfinder-icon-role-micro-tank", ["HEALER"] = "groupfinder-icon-role-micro-heal", ["DAMAGER"] = "groupfinder-icon-role-micro-dps"}
local ROLE_DEFAULT_COUNTS = {["TANK"] = 1, ["HEALER"] = 2, ["DAMAGER"] = 0}
local PLAYSTYLE_FALLBACK_NAMES = {"Learning", "Relaxed", "Competitive", "Carry Offered"}
local DIFFICULTY_KEYS = {"difficultyNormal", "difficultyHeroic", "difficultyMythic", "difficultyMythicPlus"}
local PLAYSTYLE_KEYS = {"generalPlaystyle1", "generalPlaystyle2", "generalPlaystyle3", "generalPlaystyle4"}
local DUNGEON_DIFFICULTIES = {
    {["key"] = "difficultyNormal", ["flag"] = "isNormalActivity", ["short"] = "N", ["label"] = "PLAYER_DIFFICULTY1", ["fallback"] = "Normal"},
    {["key"] = "difficultyHeroic", ["flag"] = "isHeroicActivity", ["short"] = "H", ["label"] = "PLAYER_DIFFICULTY2", ["fallback"] = "Heroic"},
    {["key"] = "difficultyMythic", ["flag"] = "isMythicActivity", ["short"] = "M", ["label"] = "PLAYER_DIFFICULTY6", ["fallback"] = "Mythic"},
    {["key"] = "difficultyMythicPlus", ["flag"] = "isMythicPlusActivity", ["short"] = "M+", ["label"] = "PLAYER_DIFFICULTY_MYTHIC_PLUS", ["fallback"] = "Mythic+"}
}
local RAID_DIFFICULTIES = {
    {["key"] = "NORMAL", ["id"] = 14, ["label"] = "PLAYER_DIFFICULTY1", ["fallback"] = "Normal"},
    {["key"] = "HEROIC", ["id"] = 15, ["label"] = "PLAYER_DIFFICULTY2", ["fallback"] = "Heroic"},
    {["key"] = "MYTHIC", ["id"] = 16, ["label"] = "PLAYER_DIFFICULTY6", ["fallback"] = "Mythic"}
}
local RAID_DIFFICULTY_KEYS = {[14] = "NORMAL", [15] = "HEROIC", [16] = "MYTHIC"}
local OPERATORS = {
    {["value"] = "OFF", ["label"] = "LID_FILTEROFF"},
    {["value"] = ">=", ["label"] = "LID_FILTERATLEAST"},
    {["value"] = "<=", ["label"] = "LID_FILTERATMOST"},
    {["value"] = "=", ["label"] = "LID_FILTEREXACTLY"}
}
local DIRECTIONS = {
    {["value"] = "asc", ["label"] = "LID_FILTERASCENDING"},
    {["value"] = "desc", ["label"] = "LID_FILTERDESCENDING"}
}
local SORT_LABELS = {
    ["age"] = "LID_FILTERSORTAGE",
    ["rating"] = "LID_FILTERSORTRATING",
    ["bosses"] = "LID_FILTERBOSSES",
    ["size"] = "LID_FILTERSORTSIZE",
    ["ilvl"] = "LID_FILTERSORTILVL",
    ["name"] = "LID_FILTERSORTNAME"
}
local CATEGORY_ORDER = {DUNGEON, RAID, DELVE, ARENA, RATEDBG}
local CATEGORIES = {
    [DUNGEON] = {["key"] = "DUNGEON", ["name"] = "Dungeons", ["sorts"] = {"age", "rating", "ilvl", "name"}, ["direction"] = "desc", ["sections"] = {"ACTIVITIES", "DIFFICULTY", "PLAYSTYLE", "GROUP", "SORTING"}},
    [RAID] = {["key"] = "RAID", ["name"] = "Raids", ["sorts"] = {"age", "bosses", "size", "ilvl", "name"}, ["direction"] = "desc", ["sections"] = {"ACTIVITIES", "BOSSES", "DIFFICULTY", "PLAYSTYLE", "ROLES", "SORTING"}},
    [DELVE] = {["key"] = "DELVE", ["name"] = "Delves", ["sorts"] = {"age", "size", "ilvl", "name"}, ["direction"] = "asc", ["sections"] = {"ACTIVITIES", "TIER", "PLAYSTYLE", "SORTING"}},
    [ARENA] = {["key"] = "ARENA", ["name"] = "Arenas", ["sorts"] = {"age", "size", "rating", "name"}, ["direction"] = "asc", ["sections"] = {"ACTIVITIES", "RATING", "PLAYSTYLE", "SORTING"}},
    [RATEDBG] = {["key"] = "RATEDBG", ["name"] = "Rated Battlegrounds", ["sorts"] = {"age", "size", "rating", "name"}, ["direction"] = "asc", ["sections"] = {"ACTIVITIES", "RATING", "PLAYSTYLE", "SORTING"}}
}
local HIDDEN_SECTIONS = {["DIFFICULTY"] = true, ["PLAYSTYLE"] = true}
local panels = {}
local toggleButton = nil
local activityCache = {}
local specIDs = {}
local specsBuilt = false
local hooked = false
local savingAdvanced = false

local function ConfigKey(category, name)
    return "FILTER_" .. CATEGORIES[category].key .. "_" .. name
end

local function Get(category, name, default)
    local value = LfgUtilsGlobalDB and LfgUtilsGlobalDB[ConfigKey(category, name)]
    if value == nil then return default end

    return value
end

local function Set(category, name, value)
    LfgUtils:SetConfig(ConfigKey(category, name), value)
end

local function GetGlobal(name, fallback)
    local value = _G[name]
    if type(value) == "string" and value ~= "" then return value end

    return fallback
end

local function GetSectionLabel(key)
    if key == "DIFFICULTY" then return GetGlobal("LFG_LIST_DIFFICULTY", "Difficulty") end
    if key == "PLAYSTYLE" then return GetGlobal("GROUP_FINDER_FILTER_PLAYSTYLE", "Playstyle") end

    return "LID_FILTER" .. key
end

local function GetCategoryName(category)
    local info = C_LFGList.GetLfgCategoryInfo and C_LFGList.GetLfgCategoryInfo(category)
    if info and info.name and info.name ~= "" then return info.name end

    return CATEGORIES[category].name
end

local function IsSectionShown(category, key)
    return LfgUtils:IsFilterSectionShown(CATEGORIES[category].layout, key)
end

local function GetRoleName(role)
    return GetGlobal(role, ROLE_FALLBACK_NAMES[role])
end

local function GetRoleLabel(role)
    return CreateAtlasMarkup(ROLE_ATLASES[role], 16, 16) .. " " .. GetRoleName(role)
end

local function GetActivityInfo(activityID)
    if not activityID then return nil end
    local info = activityCache[activityID]
    if info == nil then
        info = C_LFGList.GetActivityInfoTable(activityID) or false
        activityCache[activityID] = info
    end

    return info or nil
end

local function IsActivityEnabled(category, key)
    return Get(category, "ACT_" .. key, true) ~= false
end

local function GetAdvancedFilter()
    if not C_LFGList.GetAdvancedFilter then return nil end

    return C_LFGList.GetAdvancedFilter()
end

local function IsNoneChecked(filter, keys)
    for _, key in ipairs(keys) do
        if filter[key] then return false end
    end

    return true
end

local function IsAdvancedEnabled(filter, key, keys)
    if not filter then return keys ~= nil end
    if keys and IsNoneChecked(filter, keys) then return true end

    return filter[key] == true
end

local function SaveAdvancedFilter(filter)
    savingAdvanced = true
    C_LFGList.SaveAdvancedFilter(filter)
    savingAdvanced = false
end

local function SetAdvanced(key, value, keys)
    local filter = GetAdvancedFilter()
    if not filter then return end
    if keys and IsNoneChecked(filter, keys) then
        for _, other in ipairs(keys) do
            filter[other] = true
        end
    end

    filter[key] = value
    SaveAdvancedFilter(filter)
end

local function BuildSpecCache()
    if specsBuilt then return end
    local getSpec = GetSpecializationInfoForClassID or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID)
    if not getSpec or not GetClassInfo then return end
    local numClasses = GetNumClasses and GetNumClasses() or 20
    for classID = 1, numClasses do
        local _, classFilename = GetClassInfo(classID)
        if classFilename then
            for specIndex = 1, 5 do
                for sex = 1, 3 do
                    local specID, specName = getSpec(classID, specIndex, sex)
                    if specID and specName and specName ~= "" then
                        specIDs[classFilename .. "\1" .. specName] = specID
                        specsBuilt = true
                    end
                end
            end
        end
    end
end

local function GetSpecID(specName, classFilename)
    if not specName or specName == "" or not classFilename then return nil end
    BuildSpecCache()

    return specIDs[classFilename .. "\1" .. specName]
end

local function GetPlayerSpec()
    local getSpecialization = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    local index = getSpecialization and getSpecialization()
    if not index or not getInfo then return nil, nil end
    local specID, specName = getInfo(index)

    return specID, specName
end

local function PartyHasBloodlust()
    local _, classFilename = UnitClass("player")
    if classFilename and BLOODLUST_CLASSES[classFilename] then return true end
    for index = 1, 4 do
        local unit = "party" .. index
        if UnitExists(unit) then
            local _, unitClass = UnitClass(unit)
            if unitClass and BLOODLUST_CLASSES[unitClass] then return true end
        end
    end

    return false
end

local function GetRoleVectors()
    local tanks, healers, damagers = 0, 0, 0
    for index = 1, 4 do
        local unit = "party" .. index
        if UnitExists(unit) then
            local role = UnitGroupRolesAssigned(unit)
            if role == "TANK" then
                tanks = tanks + 1
            elseif role == "HEALER" then
                healers = healers + 1
            elseif role == "DAMAGER" then
                damagers = damagers + 1
            end
        end
    end

    local _, tank, healer, damager = GetLFGRoles()
    local vectors = {}
    if tank then table.insert(vectors, {tanks + 1, healers, damagers}) end
    if healer then table.insert(vectors, {tanks, healers + 1, damagers}) end
    if damager then table.insert(vectors, {tanks, healers, damagers + 1}) end

    return vectors
end

local function BuildState(category)
    local state = {
        ["category"] = category,
        ["activities"] = IsSectionShown(category, "ACTIVITIES"),
        ["sorting"] = IsSectionShown(category, "SORTING")
    }
    if category == DUNGEON then
        state.group = IsSectionShown(category, "GROUP")
        if not state.group then return state end
        local advanced = GetAdvancedFilter()
        state.minRating = advanced and advanced.minimumRating or 0
        state.tankOrHealer = Get(category, "TANKORHEALER", false)
        state.augmentation = Get(category, "AUGMENTATION", false)
        state.bloodlust = Get(category, "BLOODLUST", false)
        state.hideAugmentation = Get(category, "HIDEAUGMENTATION", false)
        state.hideBloodlust = Get(category, "HIDEBLOODLUST", false)
        state.hideSameSpec = Get(category, "HIDESAMESPEC", false)
        if state.bloodlust then state.partyLust = PartyHasBloodlust() end
        if state.hideSameSpec then
            state.playerSpecID, state.playerSpecName = GetPlayerSpec()
            state.playerClass = select(2, UnitClass("player"))
        end

        if Get(category, "INCOMPATIBLE", false) then state.vectors = GetRoleVectors() end
        state.needMembers = state.augmentation or state.bloodlust or state.hideAugmentation or state.hideBloodlust or state.hideSameSpec

        return state
    end

    state.playstyles = {}
    local playstyleShown = IsSectionShown(category, "PLAYSTYLE")
    for index = 1, #PLAYSTYLE_KEYS do
        state.playstyles[index] = Get(category, "PLAYSTYLE_" .. index, true)
        if playstyleShown and not state.playstyles[index] then state.playstyleFilter = true end
    end

    if category == RAID then
        local difficultyShown = IsSectionShown(category, "DIFFICULTY")
        state.difficulties = {}
        for _, difficulty in ipairs(RAID_DIFFICULTIES) do
            state.difficulties[difficulty.id] = Get(category, "DIFF_" .. difficulty.key, true)
            if difficultyShown and not state.difficulties[difficulty.id] then state.difficultyFilter = true end
        end

        local bossesShown = IsSectionShown(category, "BOSSES")
        state.bossMin = bossesShown and Get(category, "BOSSMIN", 0) or 0
        state.bossMax = bossesShown and Get(category, "BOSSMAX", -1) or -1
        local rolesShown = IsSectionShown(category, "ROLES")
        state.roles = {}
        for _, role in ipairs(ROLES) do
            state.roles[role] = {
                ["op"] = rolesShown and Get(category, "ROLEOP_" .. role, "OFF") or "OFF",
                ["count"] = Get(category, "ROLECOUNT_" .. role, ROLE_DEFAULT_COUNTS[role])
            }
        end
    elseif category == DELVE then
        state.tierFilter = IsSectionShown(category, "TIER")
        state.tierMin = Get(category, "TIERMIN", 1)
        state.tierMax = Get(category, "TIERMAX", MAX_TIER)
        state.specialTiers = Get(category, "SPECIALTIERS", true)
    else
        state.minPvpRating = IsSectionShown(category, "RATING") and Get(category, "MINRATING", 0) or 0
    end

    return state
end

local function ReadMembers(context, resultID, numMembers, state)
    for memberIndex = 1, numMembers do
        local member = C_LFGList.GetSearchResultPlayerInfo(resultID, memberIndex)
        if member then
            local classFilename = member.classFilename
            local specName = member.specName
            local specID = GetSpecID(specName, classFilename)
            if classFilename and BLOODLUST_CLASSES[classFilename] then context.groupLust = true end
            if specID == SPEC_AUGMENTATION or (not specID and classFilename == "EVOKER" and specName and string.lower(specName) == "augmentation") then context.augmentation = true end
            if state.hideSameSpec then
                if state.playerSpecID and specID then
                    if specID == state.playerSpecID then context.sameSpec = true end
                elseif classFilename == state.playerClass and specName and state.playerSpecName and string.lower(specName) == string.lower(state.playerSpecName) then
                    context.sameSpec = true
                end
            end
        end
    end
end

local function BuildContext(resultID, state)
    local info = C_LFGList.GetSearchResultInfo(resultID)
    if not info then return nil end
    local _, appStatus, pendingStatus = C_LFGList.GetApplicationInfo(resultID)
    local context = {
        ["isApplied"] = pendingStatus ~= nil or ACTIVE_APP_STATUS[appStatus or "none"] == true,
        ["age"] = info.age or 0,
        ["ilvl"] = info.requiredItemLevel or 0,
        ["name"] = info.leaderName and string.lower(info.leaderName) or "",
        ["size"] = info.numMembers or 0,
        ["mprating"] = info.leaderOverallDungeonScore or 0,
        ["playstyle"] = info.generalPlaystyle or 0,
        ["tanks"] = 0,
        ["healers"] = 0,
        ["damagers"] = 0,
        ["tankNeeded"] = 0,
        ["healerNeeded"] = 0,
        ["damagerNeeded"] = 0
    }

    local activityID = info.activityIDs and info.activityIDs[1] or info.activityID
    local activity = GetActivityInfo(activityID)
    if not activity then return context end
    context.categoryID = activity.categoryID
    local groupID = activity.groupFinderActivityGroupID
    if groupID and groupID > 0 then
        context.activityKey = groupID
    else
        context.activityKey = -activityID
    end

    local counts = C_LFGList.GetSearchResultMemberCounts(resultID)
    if counts then
        context.tanks = counts.TANK or 0
        context.healers = counts.HEALER or 0
        context.damagers = (counts.DAMAGER or 0) + (counts.NOROLE or 0)
        context.tankNeeded = counts.TANK_REMAINING or 0
        context.healerNeeded = counts.HEALER_REMAINING or 0
        context.damagerNeeded = counts.DAMAGER_REMAINING or 0
    end

    if activity.categoryID == DUNGEON then
        context.mythicplus = activity.isMythicPlusActivity == true
        if state.needMembers then ReadMembers(context, resultID, info.numMembers or 0, state) end
    elseif activity.categoryID == RAID then
        context.difficultyID = activity.difficultyID
        local encounters = C_LFGList.GetSearchResultEncounterInfo(resultID)
        context.bosses = encounters and #encounters or 0
    elseif activity.categoryID == DELVE then
        context.tier = tonumber(string.match(activity.fullName or "", "%(.-(%d+)%)$")) or 0
    elseif activity.categoryID == ARENA or activity.categoryID == RATEDBG then
        local rating = 0
        for _, ratingInfo in ipairs(info.leaderPvpRatingInfo or {}) do
            if ratingInfo.rating and ratingInfo.rating > rating then rating = ratingInfo.rating end
        end

        context.pvpRating = rating
    end

    return context
end

local function Compare(actual, op, expected)
    if op == ">=" then return actual >= expected end
    if op == "<=" then return actual <= expected end
    if op == "=" then return actual == expected end

    return true
end

local function PassesDungeon(context, state)
    if not state.group then return true end
    if state.minRating > 0 and context.mythicplus and context.mprating < state.minRating then return false end
    if state.tankOrHealer and context.tanks == 0 and context.healers == 0 then return false end
    if state.augmentation and not context.augmentation then return false end
    if state.bloodlust and not (context.groupLust or state.partyLust) then return false end
    if state.hideBloodlust and context.groupLust then return false end
    if state.hideAugmentation and context.augmentation then return false end
    if state.hideSameSpec and context.sameSpec then return false end
    if not state.vectors or #state.vectors == 0 then return true end
    for _, vector in ipairs(state.vectors) do
        if context.tankNeeded >= vector[1] and context.healerNeeded >= vector[2] and context.damagerNeeded >= vector[3] then return true end
    end

    return false
end

local function PassesRaid(context, state)
    if state.difficultyFilter and state.difficulties[context.difficultyID] == false then return false end
    local counts = {["TANK"] = context.tanks, ["HEALER"] = context.healers, ["DAMAGER"] = context.damagers}
    for _, role in ipairs(ROLES) do
        local requirement = state.roles[role]
        if requirement.op ~= "OFF" and not Compare(counts[role], requirement.op, requirement.count) then return false end
    end

    if context.bosses < state.bossMin then return false end
    if state.bossMax >= 0 and context.bosses > state.bossMax then return false end

    return true
end

local function PassesDelve(context, state)
    if not state.tierFilter then return true end
    if context.tier > 0 then return context.tier >= state.tierMin and context.tier <= state.tierMax end

    return state.specialTiers
end

local function Passes(context, state)
    if context.isApplied then return true end
    local category = state.category
    if context.categoryID ~= category then return true end
    if state.activities and not IsActivityEnabled(category, context.activityKey) then return false end
    if category == DUNGEON then return PassesDungeon(context, state) end
    if state.playstyleFilter and state.playstyles[context.playstyle] == false then return false end
    if category == RAID then return PassesRaid(context, state) end
    if category == DELVE then return PassesDelve(context, state) end

    return state.minPvpRating <= 0 or (context.pvpRating or 0) >= state.minPvpRating
end

local function GetSortValue(context, sort)
    if sort == "age" then return context.age end
    if sort == "rating" then return context.pvpRating or context.mprating end
    if sort == "bosses" then return context.bosses or 0 end
    if sort == "size" then return context.size end
    if sort == "ilvl" then return context.ilvl end
    if sort == "name" then return context.name end

    return 0
end

local function CompareSort(contextA, contextB, sort, direction)
    local valueA = GetSortValue(contextA, sort)
    local valueB = GetSortValue(contextB, sort)
    if valueA == valueB then return nil end
    if direction == "desc" then return valueA > valueB end

    return valueA < valueB
end

local function MergeApplications(results, contexts, applications, state)
    local present = {}
    for _, resultID in ipairs(results) do
        present[resultID] = true
    end

    for _, resultID in ipairs(applications or {}) do
        if not present[resultID] then
            local context = contexts[resultID] or BuildContext(resultID, state)
            if context and context.isApplied then
                contexts[resultID] = context
                present[resultID] = true
                table.insert(results, resultID)
            end
        end
    end
end

local function SortResults(results, contexts, category)
    local primary = Get(category, "SORT", "DEFAULT")
    local pendingTop = Get(category, "PENDINGTOP", true)
    if primary == "DEFAULT" and not pendingTop then return end
    local direction = CATEGORIES[category].direction
    local primaryDirection = Get(category, "SORTDIR", direction)
    local secondary = Get(category, "THEN", "NONE")
    local secondaryDirection = Get(category, "THENDIR", direction)
    local order = {}
    for index, resultID in ipairs(results) do
        order[resultID] = index
    end

    table.sort(
        results,
        function(a, b)
            local contextA = contexts[a]
            local contextB = contexts[b]
            if pendingTop and contextA.isApplied ~= contextB.isApplied then return contextA.isApplied end
            if primary ~= "DEFAULT" then
                local result = CompareSort(contextA, contextB, primary, primaryDirection)
                if result ~= nil then return result end
                if secondary ~= "NONE" then
                    result = CompareSort(contextA, contextB, secondary, secondaryDirection)
                    if result ~= nil then return result end
                end
            end

            return order[a] < order[b]
        end
    )
end

local function ApplyFilters(panel)
    if not panel or panel.searching or type(panel.results) ~= "table" then return end
    if C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo() then return end
    local category = panel.categoryID
    if not CATEGORIES[category] then return end
    local state = BuildState(category)
    local contexts = {}
    local filtered = {}
    for _, resultID in ipairs(panel.results) do
        local context = BuildContext(resultID, state)
        if context then
            contexts[resultID] = context
            if Passes(context, state) then table.insert(filtered, resultID) end
        end
    end

    if state.sorting then
        if Get(category, "PENDINGTOP", true) then MergeApplications(filtered, contexts, panel.applications, state) end
        SortResults(filtered, contexts, category)
    end

    panel.results = filtered
    panel.totalResults = #filtered
    LFGListSearchPanel_UpdateResults(panel)
end

local function GetSearchPanel()
    return LFGListFrame and LFGListFrame.SearchPanel
end

local function Refilter()
    local panel = GetSearchPanel()
    if not panel or not panel:IsVisible() or panel.searching then return end
    LFGListSearchPanel_UpdateResultList(panel)
end

local function Search()
    local panel = GetSearchPanel()
    if panel and panel:IsVisible() and LFGListSearchPanel_DoSearch then LFGListSearchPanel_DoSearch(panel) end
end

local function IsLegacyRaidView()
    local panel = GetSearchPanel()
    local filters = panel and panel.filters or 0
    if not Enum.LFGListFilter.NotRecommended then return false end

    return bit.band(filters, Enum.LFGListFilter.NotRecommended) ~= 0
end

local function CombineFilters(...)
    local value = 0
    for index = 1, select("#", ...) do
        local flag = select(index, ...)
        if flag then value = bit.bor(value, flag) end
    end

    return value
end

local function GetGroups(category, ...)
    return C_LFGList.GetAvailableActivityGroups(category, CombineFilters(...)) or {}
end

local function SortGroupsByName(groups)
    local sorted = {}
    for _, groupID in ipairs(groups) do
        local name = C_LFGList.GetActivityGroupInfo(groupID)
        if name then table.insert(sorted, {["id"] = groupID, ["name"] = name}) end
    end

    table.sort(sorted, function(a, b) return a.name < b.name end)

    return sorted
end

local function SortGroupsByLevel(category, groups)
    local sorted = {}
    for _, groupID in ipairs(groups) do
        local name = C_LFGList.GetActivityGroupInfo(groupID)
        if name then
            local level = 0
            local maxActivityID = 0
            for _, activityID in ipairs(C_LFGList.GetAvailableActivities(category, groupID) or {}) do
                local activity = GetActivityInfo(activityID)
                if activity then
                    level = math.max(level, activity.maxLevelSuggestion or activity.minLevel or 0)
                    maxActivityID = math.max(maxActivityID, activityID)
                end
            end

            table.insert(sorted, {["id"] = groupID, ["name"] = name, ["level"] = level, ["activityID"] = maxActivityID})
        end
    end

    table.sort(
        sorted,
        function(a, b)
            if a.level ~= b.level then return a.level > b.level end

            return a.activityID > b.activityID
        end
    )

    return sorted
end

local function GetGroupDifficulties(category, groupID)
    local found = {}
    for _, activityID in ipairs(C_LFGList.GetAvailableActivities(category, groupID) or {}) do
        local activity = GetActivityInfo(activityID)
        if activity then
            if category == DUNGEON then
                for _, difficulty in ipairs(DUNGEON_DIFFICULTIES) do
                    if activity[difficulty.flag] then found[difficulty.key] = true end
                end
            else
                found[activity.difficultyID or 0] = true
            end
        end
    end

    return found
end

local function GetDungeonSuffix(difficulties)
    local parts = {}
    for _, difficulty in ipairs(DUNGEON_DIFFICULTIES) do
        if difficulties[difficulty.key] then table.insert(parts, difficulty.short) end
    end

    if #parts == 0 then return "" end

    return " |cff888888(" .. table.concat(parts, "/") .. ")|r"
end

local function FitLabel(check)
    check.Label:SetPoint("RIGHT", check.holder, "RIGHT", 0, 0)
    check.Label:SetJustifyH("LEFT")
    check.Label:SetWordWrap(false)
end

local function AddSection(panel, key, collapsed)
    panel.headers[key] = panel.win:AddCategory({
        ["label"] = GetSectionLabel(key),
        ["key"] = ConfigKey(panel.category, key),
        ["collapsed"] = collapsed
    })
end

local function AddToggle(panel, label, name, default)
    local check = panel.win:AddCheckbox({
        ["label"] = label,
        ["value"] = Get(panel.category, name, default),
        ["func"] = function(value)
            Set(panel.category, name, value)
            Refilter()
        end
    })
    FitLabel(check)

    return check
end

local function UpdateAllCheck(panel)
    local any = false
    for _, entry in ipairs(panel.activities) do
        if entry.visible then
            any = true
            if not IsActivityEnabled(panel.category, entry.key) then
                panel.allCheck:SetChecked(false)

                return
            end
        end
    end

    panel.allCheck:SetChecked(any)
end

local function AddActivity(panel, key, label, entry)
    if panel.activityKeys[key] then return end
    entry.key = key
    entry.check = panel.win:AddCheckbox({
        ["label"] = label,
        ["value"] = IsActivityEnabled(panel.category, key),
        ["func"] = function(value)
            Set(panel.category, "ACT_" .. key, value)
            UpdateAllCheck(panel)
            Refilter()
        end
    })
    FitLabel(entry.check)
    panel.activityKeys[key] = entry
    table.insert(panel.activities, entry)
end

local function AddGroupActivities(panel, groups, entryData)
    for _, group in ipairs(groups) do
        local difficulties = GetGroupDifficulties(panel.category, group.id)
        local label = group.name
        if panel.category == DUNGEON then label = label .. GetDungeonSuffix(difficulties) end
        AddActivity(panel, group.id, label, {["difficulties"] = difficulties, ["legacy"] = entryData and entryData.legacy})
    end
end

local function AddSingleActivities(panel, activityIDs, legacy)
    for _, activityID in ipairs(activityIDs) do
        local activity = GetActivityInfo(activityID)
        if activity then
            local name = activity.fullName or activity.shortName or tostring(activityID)
            AddActivity(panel, -activityID, name, {["difficulties"] = {[activity.difficultyID or 0] = true}, ["legacy"] = legacy})
        end
    end
end

local function BuildActivityList(panel)
    local category = panel.category
    local filters = Enum.LFGListFilter
    if category == DUNGEON then
        AddGroupActivities(panel, SortGroupsByName(GetGroups(category, filters.CurrentSeason, filters.PvE)))
        AddGroupActivities(panel, SortGroupsByName(GetGroups(category, filters.CurrentExpansion, filters.NotCurrentSeason, filters.PvE)))
    elseif category == RAID then
        for _, legacy in ipairs({false, true}) do
            local flag = legacy and filters.NotRecommended or filters.Recommended
            local combined = CombineFilters(flag, filters.PvE)
            AddGroupActivities(panel, SortGroupsByLevel(category, GetGroups(category, flag, filters.PvE)), {["legacy"] = legacy})
            AddSingleActivities(panel, C_LFGList.GetAvailableActivities(category, 0, combined) or {}, legacy)
        end
    elseif category == DELVE then
        AddGroupActivities(panel, SortGroupsByName(GetGroups(category, filters.Recommended, filters.PvE)))
        AddGroupActivities(panel, SortGroupsByName(GetGroups(category, filters.NotRecommended, filters.PvE)))
    else
        local recommended = SortGroupsByName(GetGroups(category, filters.Recommended, filters.PvP))
        local legacy = SortGroupsByName(GetGroups(category, filters.NotRecommended, filters.PvP))
        if #recommended + #legacy > 0 then
            AddGroupActivities(panel, recommended)
            AddGroupActivities(panel, legacy)
        else
            AddSingleActivities(panel, C_LFGList.GetAvailableActivities(category) or {})
        end
    end
end

local function IsDungeonEntryVisible(entry, advanced)
    if not next(entry.difficulties) then return true end
    local none = not advanced or IsNoneChecked(advanced, DIFFICULTY_KEYS)
    for key in pairs(entry.difficulties) do
        if none or advanced[key] then return true end
    end

    return false
end

local function IsRaidEntryVisible(entry, legacy)
    if (entry.legacy == true) ~= legacy then return false end
    if not IsSectionShown(RAID, "DIFFICULTY") then return true end
    local anyEnabled = false
    for _, difficulty in ipairs(RAID_DIFFICULTIES) do
        if Get(RAID, "DIFF_" .. difficulty.key, true) then anyEnabled = true end
    end

    if not anyEnabled or not next(entry.difficulties) then return true end
    for difficultyID in pairs(entry.difficulties) do
        local key = RAID_DIFFICULTY_KEYS[difficultyID]
        if not key or Get(RAID, "DIFF_" .. key, true) then return true end
    end

    return false
end

local function UpdateActivities(panel)
    local advanced = panel.category == DUNGEON and GetAdvancedFilter()
    local legacy = panel.category == RAID and IsLegacyRaidView()
    for _, entry in ipairs(panel.activities) do
        local visible = true
        if panel.category == DUNGEON then
            visible = IsDungeonEntryVisible(entry, advanced)
        elseif panel.category == RAID then
            visible = IsRaidEntryVisible(entry, legacy)
        end

        entry.visible = visible
        entry.check:SetChecked(IsActivityEnabled(panel.category, entry.key))
        panel.win:SetElementShown(entry.check, visible)
    end

    UpdateAllCheck(panel)
end

local function UpdateAdvanced(panel)
    if not panel.advancedChecks then return end
    local filter = GetAdvancedFilter()
    for key, check in pairs(panel.advancedChecks) do
        check:SetChecked(IsAdvancedEnabled(filter, key, check.lfgUtilsKeys))
    end

    local box = panel.ratingBox
    if box and not box.control:HasFocus() then
        local rating = filter and filter.minimumRating or 0
        box:SetValue(rating > 0 and tostring(rating) or "")
    end
end

local function UpdateRoleControls(panel)
    if not panel.roleSliders then return end
    for role, slider in pairs(panel.roleSliders) do
        panel.win:SetElementShown(slider, Get(RAID, "ROLEOP_" .. role, "OFF") ~= "OFF")
    end
end

local function UpdateSortControls(panel)
    local custom = Get(panel.category, "SORT", "DEFAULT") ~= "DEFAULT"
    panel.win:SetElementShown(panel.sortDirection, custom)
    panel.win:SetElementShown(panel.thenBy, custom)
    panel.win:SetElementShown(panel.thenDirection, custom and Get(panel.category, "THEN", "NONE") ~= "NONE")
end

local function RefreshPanel(panel)
    panel.win:SuspendLayout()
    LfgUtils:ApplyFilterLayout(panel.win, CATEGORIES[panel.category].layout, panel.headers)
    UpdateActivities(panel)
    UpdateAdvanced(panel)
    UpdateRoleControls(panel)
    UpdateSortControls(panel)
    panel.win:ResumeLayout()
end

local function AddActivitySection(panel)
    AddSection(panel, "ACTIVITIES", false)
    panel.activities = {}
    panel.activityKeys = {}
    panel.allCheck = panel.win:AddCheckbox({
        ["label"] = GetGlobal("ALL", "All"),
        ["value"] = true,
        ["func"] = function(value)
            for _, entry in ipairs(panel.activities) do
                if entry.visible then
                    Set(panel.category, "ACT_" .. entry.key, value)
                    entry.check:SetChecked(value)
                end
            end

            Refilter()
        end
    })
    BuildActivityList(panel)
end

local function AddAdvancedToggle(panel, label, key, keys)
    local check = panel.win:AddCheckbox({
        ["label"] = label,
        ["value"] = IsAdvancedEnabled(GetAdvancedFilter(), key, keys),
        ["func"] = function(value)
            SetAdvanced(key, value, keys)
            RefreshPanel(panel)
            Search()
        end
    })
    FitLabel(check)
    check.lfgUtilsKeys = keys
    panel.advancedChecks[key] = check
end

local function AddDungeonSections(panel)
    panel.advancedChecks = {}
    AddSection(panel, "DIFFICULTY", true)
    for _, difficulty in ipairs(DUNGEON_DIFFICULTIES) do
        AddAdvancedToggle(panel, GetGlobal(difficulty.label, difficulty.fallback), difficulty.key, DIFFICULTY_KEYS)
    end

    AddSection(panel, "PLAYSTYLE", true)
    for index, key in ipairs(PLAYSTYLE_KEYS) do
        AddAdvancedToggle(panel, GetGlobal("GROUP_FINDER_GENERAL_PLAYSTYLE" .. index, PLAYSTYLE_FALLBACK_NAMES[index]), key, PLAYSTYLE_KEYS)
    end

    AddSection(panel, "GROUP", true)
    local filter = GetAdvancedFilter()
    local rating = filter and filter.minimumRating or 0
    panel.ratingBox = panel.win:AddEditbox({
        ["label"] = GetGlobal("LFG_LIST_MINIMUM_RATING", "Minimum Rating"),
        ["value"] = rating > 0 and tostring(rating) or "",
        ["numeric"] = true,
        ["maxLetters"] = 4,
        ["func"] = function(value)
            local current = GetAdvancedFilter()
            if not current then return end
            current.minimumRating = tonumber(value) or 0
            SaveAdvancedFilter(current)
            Refilter()
        end
    })
    AddAdvancedToggle(panel, GetGlobal("LFG_LIST_HAS_TANK", "Has Tank"), "hasTank")
    AddAdvancedToggle(panel, GetGlobal("LFG_LIST_HAS_HEALER", "Has Healer"), "hasHealer")
    AddToggle(panel, "LID_FILTERHASTANKORHEALER", "TANKORHEALER", false)
    AddToggle(panel, "LID_FILTERHASAUGMENTATION", "AUGMENTATION", false)
    AddToggle(panel, "LID_FILTERHASBLOODLUST", "BLOODLUST", false)
    AddToggle(panel, "LID_FILTERHIDEAUGMENTATION", "HIDEAUGMENTATION", false)
    AddToggle(panel, "LID_FILTERHIDEBLOODLUST", "HIDEBLOODLUST", false)
    AddToggle(panel, "LID_FILTERHIDESAMESPEC", "HIDESAMESPEC", false)
    AddToggle(panel, "LID_FILTERHIDEINCOMPATIBLE", "INCOMPATIBLE", false)
end

local function AddPlaystyleSection(panel)
    AddSection(panel, "PLAYSTYLE", true)
    for index = 1, #PLAYSTYLE_KEYS do
        AddToggle(panel, GetGlobal("GROUP_FINDER_GENERAL_PLAYSTYLE" .. index, PLAYSTYLE_FALLBACK_NAMES[index]), "PLAYSTYLE_" .. index, true)
    end
end

local function AddRangeBox(panel, label, name, emptyValue)
    local value = Get(panel.category, name, emptyValue)
    panel.win:AddEditbox({
        ["label"] = label,
        ["value"] = value ~= emptyValue and tostring(value) or "",
        ["numeric"] = true,
        ["maxLetters"] = 2,
        ["func"] = function(text)
            Set(panel.category, name, tonumber(text) or emptyValue)
            Refilter()
        end
    })
end

local function AddRaidSections(panel)
    AddSection(panel, "BOSSES", true)
    AddRangeBox(panel, "LID_FILTERBOSSMIN", "BOSSMIN", 0)
    AddRangeBox(panel, "LID_FILTERBOSSMAX", "BOSSMAX", -1)
    AddSection(panel, "DIFFICULTY", true)
    for _, difficulty in ipairs(RAID_DIFFICULTIES) do
        local check = AddToggle(panel, GetGlobal(difficulty.label, difficulty.fallback), "DIFF_" .. difficulty.key, true)
        check:HookScript("OnClick", function() RefreshPanel(panel) end)
    end

    AddPlaystyleSection(panel)
    AddSection(panel, "ROLES", true)
    panel.roleSliders = {}
    for _, role in ipairs(ROLES) do
        local current = role
        panel.win:AddDropdown({
            ["label"] = GetRoleLabel(current),
            ["value"] = Get(RAID, "ROLEOP_" .. current, "OFF"),
            ["width"] = DROPDOWN_WIDTH,
            ["choices"] = OPERATORS,
            ["func"] = function(value)
                Set(RAID, "ROLEOP_" .. current, value)
                UpdateRoleControls(panel)
                Refilter()
            end
        })
        panel.roleSliders[current] = panel.win:AddSlider({
            ["label"] = GetRoleName(current),
            ["min"] = 0,
            ["max"] = MAX_ROLE_COUNT,
            ["step"] = 1,
            ["value"] = Get(RAID, "ROLECOUNT_" .. current, ROLE_DEFAULT_COUNTS[current]),
            ["func"] = function(value)
                Set(RAID, "ROLECOUNT_" .. current, value)
                Refilter()
            end
        })
    end
end

local function AddDelveSections(panel)
    AddSection(panel, "TIER", true)
    local minControl = nil
    local maxControl = nil
    minControl = panel.win:AddSlider({
        ["label"] = "LID_FILTERMINIMUM",
        ["min"] = 1,
        ["max"] = MAX_TIER,
        ["step"] = 1,
        ["value"] = Get(DELVE, "TIERMIN", 1),
        ["func"] = function(value)
            if maxControl and value > maxControl.value then maxControl.slider:SetValue(value) end
            Set(DELVE, "TIERMIN", value)
            Refilter()
        end
    })
    maxControl = panel.win:AddSlider({
        ["label"] = "LID_FILTERMAXIMUM",
        ["min"] = 1,
        ["max"] = MAX_TIER,
        ["step"] = 1,
        ["value"] = Get(DELVE, "TIERMAX", MAX_TIER),
        ["func"] = function(value)
            if minControl and value < minControl.value then minControl.slider:SetValue(value) end
            Set(DELVE, "TIERMAX", value)
            Refilter()
        end
    })
    AddToggle(panel, "LID_FILTERSPECIALTIERS", "SPECIALTIERS", true)
    AddPlaystyleSection(panel)
end

local function AddPvpSections(panel)
    AddSection(panel, "RATING", true)
    local rating = Get(panel.category, "MINRATING", 0)
    panel.win:AddEditbox({
        ["label"] = GetGlobal("LFG_LIST_MINIMUM_RATING", "Minimum Rating"),
        ["value"] = rating > 0 and tostring(rating) or "",
        ["numeric"] = true,
        ["maxLetters"] = 4,
        ["func"] = function(value)
            Set(panel.category, "MINRATING", tonumber(value) or 0)
            Refilter()
        end
    })
    AddPlaystyleSection(panel)
end

local function GetSortChoices(category, first, firstLabel)
    local choices = {{["value"] = first, ["label"] = firstLabel}}
    for _, sort in ipairs(CATEGORIES[category].sorts) do
        table.insert(choices, {["value"] = sort, ["label"] = SORT_LABELS[sort]})
    end

    return choices
end

local function AddSortDropdown(panel, label, name, default, choices)
    return panel.win:AddDropdown({
        ["label"] = label,
        ["value"] = Get(panel.category, name, default),
        ["width"] = DROPDOWN_WIDTH,
        ["choices"] = choices,
        ["func"] = function(value)
            Set(panel.category, name, value)
            RefreshPanel(panel)
            Refilter()
        end
    })
end

local function AddSortSection(panel)
    local category = panel.category
    local direction = CATEGORIES[category].direction
    AddSection(panel, "SORTING", true)
    AddToggle(panel, "LID_FILTERPENDINGTOP", "PENDINGTOP", true)
    AddSortDropdown(panel, "LID_FILTERSORT", "SORT", "DEFAULT", GetSortChoices(category, "DEFAULT", "LID_FILTERDEFAULT"))
    panel.sortDirection = AddSortDropdown(panel, "LID_FILTERDIRECTION", "SORTDIR", direction, DIRECTIONS)
    panel.thenBy = AddSortDropdown(panel, "LID_FILTERTHENBY", "THEN", "NONE", GetSortChoices(category, "NONE", "LID_FILTERNONE"))
    panel.thenDirection = AddSortDropdown(panel, "LID_FILTERDIRECTION", "THENDIR", direction, DIRECTIONS)
end

local function CreatePanel(category)
    local panel = {["category"] = category, ["headers"] = {}}
    panel.win = LfgUtils:CreateUIWindow({
        ["name"] = "LfgUtilsFilter" .. CATEGORIES[category].key,
        ["modern"] = true,
        ["parent"] = UIParent,
        ["pTab"] = {"TOPLEFT", PVEFrame, "TOPRIGHT", -FILTER_OVERLAP, 0},
        ["width"] = LfgUtils:GetFilterWidth(FILTER_WIDTH) + FILTER_OVERLAP,
        ["height"] = FILTER_HEIGHT_FALLBACK,
        ["resizable"] = "width",
        ["minWidth"] = FILTER_MIN_WIDTH + FILTER_OVERLAP,
        ["maxWidth"] = FILTER_MAX_WIDTH + FILTER_OVERLAP,
        ["onResize"] = function(width) LfgUtils:SetConfig("FILTERWIDTH", width - FILTER_OVERLAP) end,
        ["movable"] = false,
        ["escClose"] = false,
        ["getCollapsed"] = function(key) return LfgUtils:GetCollapsed(key) end,
        ["setCollapsed"] = function(key, value) LfgUtils:SetCollapsed(key, value) end,
        ["title"] = GetGlobal("FILTER", "Filter")
    })
    if panel.win.CloseButton then panel.win.CloseButton:Hide() end
    LfgUtils:AddSettingsFooter(panel.win)
    panel.win:SuspendLayout()
    AddActivitySection(panel)
    if category == DUNGEON then
        AddDungeonSections(panel)
    elseif category == RAID then
        AddRaidSections(panel)
    elseif category == DELVE then
        AddDelveSections(panel)
    else
        AddPvpSections(panel)
    end

    AddSortSection(panel)
    panel.win:ResumeLayout()
    panels[category] = panel

    return panel
end

local function GetStrataBelow(strata)
    for index, name in ipairs(STRATA_ORDER) do
        if name == strata then return STRATA_ORDER[math.max(1, index - 1)] end
    end

    return "LOW"
end

local function DockPanel(panel)
    local win = panel.win
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", PVEFrame, "TOPRIGHT", -FILTER_OVERLAP, 0)
    win:SetPoint("BOTTOMLEFT", PVEFrame, "BOTTOMRIGHT", -FILTER_OVERLAP, 0)
    win:SetWidth(LfgUtils:GetFilterWidth(FILTER_WIDTH) + FILTER_OVERLAP)
    win:SetFrameStrata(GetStrataBelow(PVEFrame:GetFrameStrata()))
end

local function GetShownCategory()
    local searchPanel = GetSearchPanel()
    if not PVEFrame:IsVisible() or not searchPanel or not searchPanel:IsVisible() then return nil end
    if LFGListFrame.activePanel ~= searchPanel then return nil end
    if C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo() then return nil end
    if not CATEGORIES[searchPanel.categoryID] then return nil end

    return searchPanel.categoryID
end

local function UpdateVisibility()
    local category = GetShownCategory()
    if toggleButton then toggleButton:SetShown(category ~= nil) end
    if not LfgUtils:IsFilterShown() then category = nil end
    for key, panel in pairs(panels) do
        if key ~= category then panel.win:Hide() end
    end

    if not category then return end
    local panel = panels[category] or CreatePanel(category)
    DockPanel(panel)
    RefreshPanel(panel)
    panel.win:Show()
end

local function OnAdvancedFilterSaved()
    if savingAdvanced then return end
    local panel = panels[DUNGEON]
    if not panel or not panel.win:IsShown() then return end
    C_Timer.After(0, function() RefreshPanel(panel) end)
end

local function Init()
    if hooked or LfgUtils:GetWoWBuild() ~= "RETAIL" or LfgUtils:IsForever() then return end
    if not PVEFrame or not GetSearchPanel() or not LFGListSearchPanel_UpdateResultList or not LFGListSearchPanel_UpdateResults then return end
    hooked = true
    toggleButton = LfgUtils:CreateFilterToggle(PVEFrame, "LfgUtilsFilterToggle", UpdateVisibility)
    hooksecurefunc("LFGListSearchPanel_UpdateResultList", ApplyFilters)
    hooksecurefunc("LFGListSearchPanel_SetCategory", UpdateVisibility)
    if C_LFGList.SaveAdvancedFilter then hooksecurefunc(C_LFGList, "SaveAdvancedFilter", OnAdvancedFilterSaved) end
    PVEFrame:HookScript("OnShow", UpdateVisibility)
    PVEFrame:HookScript("OnHide", UpdateVisibility)
    GetSearchPanel():HookScript("OnShow", UpdateVisibility)
    GetSearchPanel():HookScript("OnHide", UpdateVisibility)
    UpdateVisibility()
end

local function OnLayoutChanged(category)
    local panel = panels[category]
    if not panel then return end
    RefreshPanel(panel)
    if panel.win:IsShown() then Refilter() end
end

local function RegisterLayouts()
    if LfgUtils:GetWoWBuild() ~= "RETAIL" or LfgUtils:IsForever() then return end
    for _, category in ipairs(CATEGORY_ORDER) do
        local definition = CATEGORIES[category]
        local layout = {
            ["key"] = "FILTER_" .. definition.key,
            ["label"] = function() return GetCategoryName(category) end,
            ["sections"] = {},
            ["onChange"] = function() OnLayoutChanged(category) end
        }
        for _, key in ipairs(definition.sections) do
            table.insert(layout.sections, {["key"] = key, ["label"] = GetSectionLabel(key), ["hidden"] = HIDDEN_SECTIONS[key]})
        end

        definition.layout = layout
        LfgUtils:RegisterFilterLayout(layout)
    end
end

RegisterLayouts()
local loader = CreateFrame("Frame")
LfgUtils:RegisterEvent(loader, "ADDON_LOADED")
LfgUtils:RegisterEvent(loader, "PLAYER_LOGIN")
LfgUtils:RegisterEvent(loader, "LFG_LIST_ACTIVE_ENTRY_UPDATE")
loader:SetScript(
    "OnEvent",
    function(_, event)
        if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
            if hooked then UpdateVisibility() end

            return
        end

        Init()
    end
)
