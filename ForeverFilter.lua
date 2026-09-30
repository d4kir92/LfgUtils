local _, LfgUtils = ...

local FILTER_WIDTH = 250
local FILTER_MIN_WIDTH = 200
local FILTER_MAX_WIDTH = 600
local FILTER_HEIGHT_FALLBACK = 512
local FILTER_GAP = 4
local FILTER_OVERLAP = 8
local STRATA_ORDER = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"}
local MAX_LEVEL = 60
local ROLES = {"TANK", "HEALER", "DAMAGER"}
local ROLE_FALLBACK_NAMES = {["TANK"] = "Tank", ["HEALER"] = "Healer", ["DAMAGER"] = "Damage"}
local LFG_ROLE_KEYS = {["TANK"] = "tank", ["HEALER"] = "healer", ["DAMAGER"] = "dps"}
local ROLE_ATLASES = {["TANK"] = "groupfinder-icon-role-micro-tank", ["HEALER"] = "groupfinder-icon-role-micro-heal", ["DAMAGER"] = "groupfinder-icon-role-micro-dps"}
local LAYOUT = {
    ["key"] = "FOREVER",
    ["label"] = FILTER or "Filter",
    ["sections"] = {
        {["key"] = "ROLES", ["label"] = ROLE or "Role"},
        {["key"] = "CLASSES", ["label"] = CLASS or "Class"},
        {["key"] = "LEVEL", ["label"] = LEVEL or "Level"},
        {["key"] = "LOCATION", ["label"] = "LID_FILTERLOCATION"},
        {["key"] = "SORTING", ["label"] = "LID_FILTERSORTING"}
    }
}
local SORT_DROPDOWN_WIDTH = 100
local SORT_CHOICES = {
    {["value"] = "NEAR", ["label"] = "LID_FILTERSORTNEARBY"},
    {["value"] = "LEVEL", ["label"] = LEVEL or "Level"}
}
local ZONE_ICON_ATLAS = "Waypoint-MapPin-ChatIcon"
local ZONE_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_Map_01"
local ZONE_TOOLTIP_ICON_SIZE = 16
local ZONE_TOOLTIP_BOTTOM = 12
local ZONE_TOOLTIP_MAX_WIDTH = 320
local INSTANCE_ZONE_AREAS = {
    [389] = {1637},
    [36] = {40},
    [43] = {17},
    [33] = {130},
    [34] = {1519},
    [48] = {331},
    [90] = {1},
    [47] = {17},
    [189] = {85},
    [129] = {17, 400},
    [70] = {3},
    [209] = {440},
    [349] = {405},
    [109] = {8},
    [230] = {25, 51, 46},
    [229] = {25, 51, 46},
    [409] = {25, 51, 46},
    [469] = {25, 51, 46},
    [429] = {357},
    [289] = {28},
    [329] = {139},
    [309] = {33},
    [509] = {1377},
    [531] = {1377},
    [249] = {15},
    [533] = {139},
    [572] = {1497, 85}
}
local instanceZoneNames = {}
local filterWindow = nil
local toggleButton = nil
local browseFrame = nil
local minLevelControl = nil
local maxLevelControl = nil
local sectionHeaders = {}
local hooked = false
local tooltipHooked = false
local roleColorHooked = false

local function GetAvailableClasses()
    return {"WARRIOR", "PALADIN", "SHAMAN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "DRUID"}
end

local function GetClassName(classFilename)
    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFilename] then
        return LOCALIZED_CLASS_NAMES_MALE[classFilename]
    end

    return classFilename
end

local function GetRoleName(role)
    return _G[role] or ROLE_FALLBACK_NAMES[role]
end

local function GetAtlasMarkup(atlas)
    if CreateAtlasMarkup then return CreateAtlasMarkup(atlas, 16, 16) end

    return "|A:" .. atlas .. ":16:16|a"
end

local function GetClassLabel(classFilename)
    local name = GetClassName(classFilename)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename]
    if color then
        name = string.format("|cff%02x%02x%02x%s|r", math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255), name)
    end

    return GetAtlasMarkup("groupfinder-icon-class-" .. string.lower(classFilename)) .. " " .. name
end

local function GetRoleLabel(role)
    return GetAtlasMarkup(ROLE_ATLASES[role]) .. " " .. GetRoleName(role)
end

local function IsRoleEnabled(role)
    return LfgUtils:GetConfig("FOREVER_ROLE_" .. role, true)
end

local function IsRoleFilterActive()
    for _, role in ipairs(ROLES) do
        if not IsRoleEnabled(role) then return true end
    end

    return false
end

local function MatchesRole(memberInfo, isSolo)
    if isSolo then
        local lfgRoles = memberInfo.lfgRoles
        if not lfgRoles then return false end
        for _, role in ipairs(ROLES) do
            if lfgRoles[LFG_ROLE_KEYS[role]] and IsRoleEnabled(role) then return true end
        end

        return false
    end

    local role = memberInfo.assignedRole
    return LFG_ROLE_KEYS[role] ~= nil and IsRoleEnabled(role)
end

local function CopyResults(results)
    local copy = {}
    for index, resultID in ipairs(results or {}) do
        copy[index] = resultID
    end

    return copy
end

local function MatchesMember(memberInfo, state, isSolo)
    if not memberInfo then return false end
    if state.checkClasses then
        local classFilename = memberInfo.classFilename
        if not classFilename or not LfgUtils:GetConfig("FOREVER_CLASS_" .. classFilename, true) then return false end
    end

    if state.checkRoles and not MatchesRole(memberInfo, isSolo) then return false end
    if not state.checkLevel then return true end
    local level = tonumber(memberInfo.level)

    return level ~= nil and level >= state.minLevel and level <= state.maxLevel
end

local function GetInstanceZoneNames(mapID)
    if not mapID or mapID <= 0 then return nil end
    if instanceZoneNames[mapID] then return instanceZoneNames[mapID] end
    local names = {}
    local instanceName = GetRealZoneText and GetRealZoneText(mapID)
    if instanceName and instanceName ~= "" then names[instanceName] = true end
    for _, areaID in ipairs(INSTANCE_ZONE_AREAS[mapID] or {}) do
        local areaName = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(areaID)
        if areaName and areaName ~= "" then names[areaName] = true end
    end

    instanceZoneNames[mapID] = names

    return names
end

local function GetMembersInActivityZone(resultID, resultInfo)
    local members = {}
    if not resultInfo or resultInfo.hasSelf then return members end
    local zoneNames = {}
    local hasZone = false
    for _, activityID in ipairs(resultInfo.activityIDs or {}) do
        local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
        local names = activityInfo and GetInstanceZoneNames(activityInfo.mapID)
        if names then
            for name in pairs(names) do
                zoneNames[name] = true
                hasZone = true
            end
        end
    end

    if not hasZone then return members end
    for memberIndex = 1, resultInfo.numMembers or 1 do
        local memberInfo = C_LFGList.GetSearchResultPlayerInfo(resultID, memberIndex)
        if memberInfo and memberInfo.areaName and zoneNames[memberInfo.areaName] then table.insert(members, memberInfo) end
    end

    return members
end

local function GetFilterState()
    return {
        ["checkRoles"] = LfgUtils:IsFilterSectionShown(LAYOUT, "ROLES") and IsRoleFilterActive(),
        ["checkClasses"] = LfgUtils:IsFilterSectionShown(LAYOUT, "CLASSES"),
        ["checkLevel"] = LfgUtils:IsFilterSectionShown(LAYOUT, "LEVEL"),
        ["minLevel"] = LfgUtils:GetConfig("FOREVER_LEVEL_MIN", 1),
        ["maxLevel"] = LfgUtils:GetConfig("FOREVER_LEVEL_MAX", MAX_LEVEL),
        ["nearOnly"] = LfgUtils:IsFilterSectionShown(LAYOUT, "LOCATION") and LfgUtils:GetConfig("FOREVER_NEARONLY", false)
    }
end

local function GetResultLevel(resultID, resultInfo)
    local memberInfo = resultInfo.numMembers == 1 and C_LFGList.GetSearchResultPlayerInfo(resultID, 1) or C_LFGList.GetSearchResultLeaderInfo(resultID)

    return memberInfo and tonumber(memberInfo.level) or 0
end

local function GetSortContext(resultID, index, blockRanks)
    local resultInfo = C_LFGList.GetSearchResultInfo(resultID)
    if not resultInfo then return {["block"] = 0, ["near"] = false, ["level"] = 0, ["order"] = index} end
    local block = 0
    if not resultInfo.hasSelf then
        block = resultInfo.numMembers == 1 and "SOLO" or "GROUP"
        blockRanks.count = blockRanks.count or 0
        if not blockRanks[block] then
            blockRanks.count = blockRanks.count + 1
            blockRanks[block] = blockRanks.count
        end

        block = blockRanks[block]
    end

    return {
        ["block"] = block,
        ["near"] = #GetMembersInActivityZone(resultID, resultInfo) > 0,
        ["level"] = GetResultLevel(resultID, resultInfo),
        ["order"] = index
    }
end

local function CompareSort(contextA, contextB, sort)
    if sort == "NEAR" and contextA.near ~= contextB.near then return contextA.near end
    if sort == "LEVEL" and contextA.level ~= contextB.level then return contextA.level > contextB.level end

    return nil
end

local function SortResults(results)
    if not LfgUtils:IsFilterSectionShown(LAYOUT, "SORTING") then return end
    local primary = LfgUtils:GetConfig("FOREVER_SORT", "NEAR")
    local secondary = LfgUtils:GetConfig("FOREVER_THEN", "LEVEL")
    if primary == "NONE" then return end
    local contexts = {}
    local blockRanks = {}
    for index, resultID in ipairs(results) do
        contexts[resultID] = GetSortContext(resultID, index, blockRanks)
    end

    table.sort(
        results,
        function(a, b)
            local contextA = contexts[a]
            local contextB = contexts[b]
            if contextA.block ~= contextB.block then return contextA.block < contextB.block end
            local result = CompareSort(contextA, contextB, primary)
            if result ~= nil then return result end
            if secondary ~= "NONE" then
                result = CompareSort(contextA, contextB, secondary)
                if result ~= nil then return result end
            end

            return contextA.order < contextB.order
        end
    )
end

local function MatchesResult(resultID, state)
    local resultInfo = C_LFGList.GetSearchResultInfo(resultID)
    if not resultInfo then return true end
    if state.nearOnly and not resultInfo.hasSelf and #GetMembersInActivityZone(resultID, resultInfo) == 0 then return false end
    local numMembers = resultInfo.numMembers or 1
    local isSolo = numMembers == 1
    local foundMember = false
    for memberIndex = 1, numMembers do
        local memberInfo = C_LFGList.GetSearchResultPlayerInfo(resultID, memberIndex)
        if memberInfo then
            foundMember = true
            if MatchesMember(memberInfo, state, isSolo) then return true end
        end
    end

    return not foundMember
end

local function ApplyFilters(frame)
    if not frame or not frame.lfgUtilsUnfilteredResults then return end
    local state = GetFilterState()
    local filtered = {}
    for _, resultID in ipairs(frame.lfgUtilsUnfilteredResults) do
        if MatchesResult(resultID, state) then table.insert(filtered, resultID) end
    end
    SortResults(filtered)
    frame.results = filtered
    frame.totalResults = #filtered
    frame:UpdateResults()
end

local function AreAllEnabled(prefix, tokens)
    for _, token in ipairs(tokens) do
        if not LfgUtils:GetConfig(prefix .. token, true) then return false end
    end

    return true
end

local function AddToggleGroup(prefix, tokens, getLabel)
    local checks = {}
    local allCheck = filterWindow:AddCheckbox({
        ["label"] = ALL or "All",
        ["value"] = AreAllEnabled(prefix, tokens),
        ["func"] = function(value)
            for _, token in ipairs(tokens) do
                LfgUtils:SetConfig(prefix .. token, value)
                checks[token]:SetChecked(value)
            end

            ApplyFilters(browseFrame)
        end
    })

    for _, token in ipairs(tokens) do
        local current = token
        checks[current] = filterWindow:AddCheckbox({
            ["label"] = getLabel(current),
            ["value"] = LfgUtils:GetConfig(prefix .. current, true),
            ["func"] = function(value)
                LfgUtils:SetConfig(prefix .. current, value)
                allCheck:SetChecked(AreAllEnabled(prefix, tokens))
                ApplyFilters(browseFrame)
            end
        })
    end
end

local function DecorateTooltipMember(frame, classFilename)
    if not frame or not frame.Name or not classFilename then return end
    if not frame.LfgUtilsClassIcon then
        frame.LfgUtilsClassIcon = frame:CreateTexture(nil, "ARTWORK")
        frame.LfgUtilsClassIcon:SetSize(14, 14)
    end
    frame.LfgUtilsClassIcon:ClearAllPoints()
    frame.LfgUtilsClassIcon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.LfgUtilsClassIcon:SetAtlas("groupfinder-icon-class-" .. string.lower(classFilename), false)
    frame.LfgUtilsClassIcon:Show()
    frame.Name:ClearAllPoints()
    frame.Name:SetPoint("TOPLEFT", frame.LfgUtilsClassIcon, "TOPRIGHT", 2, 0)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename]
    if color then frame.Name:SetTextColor(color.r, color.g, color.b) end
end

local function UpdateTooltipMembers(tooltip, resultID)
    if not tooltip or not resultID or not tooltip.memberPool then return end
    local resultInfo = C_LFGList.GetSearchResultInfo(resultID)
    if not resultInfo then return end
    local leaderInfo = C_LFGList.GetSearchResultLeaderInfo(resultID)
    if leaderInfo then DecorateTooltipMember(tooltip.Leader, leaderInfo.classFilename) end
    local classesByName = {}
    for memberIndex = 1, resultInfo.numMembers or 1 do
        local memberInfo = C_LFGList.GetSearchResultPlayerInfo(resultID, memberIndex)
        if memberInfo and memberInfo.name and not memberInfo.isLeader then
            classesByName[memberInfo.name] = memberInfo.classFilename
        end
    end
    for frame in tooltip.memberPool:EnumerateActive() do
        DecorateTooltipMember(frame, classesByName[frame.Name:GetText()])
    end
    tooltip:SetWidth(tooltip:GetWidth() + 18)
end

local function HookTooltip()
    if tooltipHooked or not LFGBrowseSearchEntryTooltip_UpdateAndShow then return end
    tooltipHooked = true
    hooksecurefunc("LFGBrowseSearchEntryTooltip_UpdateAndShow", UpdateTooltipMembers)
end

local function SetRoleIconClassColor(icon, classFilename, disabled)
    if not icon then return end
    icon:SetVertexColor(1, 1, 1)
    icon:SetDesaturated(disabled)
    if disabled or not classFilename then return end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename]
    if not color then return end
    icon:SetDesaturated(true)
    icon:SetVertexColor(color.r, color.g, color.b)
end

local function UpdateSearchEntryRoleColors(entry)
    if not entry or not entry.resultID or not entry.DataDisplay then return end
    local resultInfo = C_LFGList.GetSearchResultInfo(entry.resultID)
    if not resultInfo then return end
    local disabled = resultInfo.isDelisted == true
    local solo = entry.DataDisplay.Solo
    if solo and solo.Roles then
        for _, icon in ipairs(solo.Roles) do
            SetRoleIconClassColor(icon, nil, disabled)
        end
    end
    local enumerate = entry.DataDisplay.Enumerate
    if enumerate and enumerate.Icons then
        for _, icon in ipairs(enumerate.Icons) do
            SetRoleIconClassColor(icon, nil, disabled)
        end
    end
    if resultInfo.numMembers == 1 then
        local memberInfo = C_LFGList.GetSearchResultPlayerInfo(entry.resultID, 1)
        if memberInfo and solo and solo.Roles then
            for _, icon in ipairs(solo.Roles) do
                if icon:IsShown() then SetRoleIconClassColor(icon, memberInfo.classFilename, disabled) end
            end
        end
        return
    end
    local displayType, maxNumPlayers = LFGBrowseUtil_GetBestDisplayTypeForActivityIDs(resultInfo.activityIDs)
    if displayType ~= Enum.LFGListDisplayType.RoleEnumerate or not enumerate or not enumerate.Icons then return end
    local membersByRole = {TANK = {}, HEALER = {}, DAMAGER = {}}
    for memberIndex = 1, resultInfo.numMembers or 1 do
        local memberInfo = C_LFGList.GetSearchResultPlayerInfo(entry.resultID, memberIndex)
        if memberInfo and membersByRole[memberInfo.assignedRole] then
            table.insert(membersByRole[memberInfo.assignedRole], memberInfo)
        end
    end
    local iconIndex = maxNumPlayers
    for _, role in ipairs(ROLES) do
        for _, memberInfo in ipairs(membersByRole[role]) do
            SetRoleIconClassColor(enumerate.Icons[iconIndex], memberInfo.classFilename, disabled)
            iconIndex = iconIndex - 1
        end
    end
end

local function SetZoneIconTexture(texture)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ZONE_ICON_ATLAS) then
        texture:SetAtlas(ZONE_ICON_ATLAS, false)
    else
        texture:SetTexture(ZONE_ICON_FALLBACK)
    end
end

local function UpdateSearchEntryZoneIcon(entry)
    if not entry or not entry.resultID or not entry.ActivityName then return end
    local resultInfo = C_LFGList.GetSearchResultInfo(entry.resultID)
    if #GetMembersInActivityZone(entry.resultID, resultInfo) == 0 then
        if entry.LfgUtilsZoneIcon then entry.LfgUtilsZoneIcon:Hide() end

        return
    end

    if not entry.LfgUtilsZoneIcon then
        entry.LfgUtilsZoneIcon = entry:CreateTexture(nil, "OVERLAY")
        entry.LfgUtilsZoneIcon:SetSize(14, 14)
        entry.LfgUtilsZoneIcon:SetPoint("LEFT", entry.ActivityName, "RIGHT", 2, 0)
        SetZoneIconTexture(entry.LfgUtilsZoneIcon)
    end

    entry.LfgUtilsZoneIcon:SetDesaturated(resultInfo.isDelisted == true)
    entry.LfgUtilsZoneIcon:Show()
end

local function GetZoneTooltipText(resultInfo, members)
    local text = LfgUtils:Trans("LID_NEARDUNGEON")
    if (resultInfo.numMembers or 1) == 1 then return text end
    local names = {}
    for _, memberInfo in ipairs(members) do
        local name = memberInfo.name or ""
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[memberInfo.classFilename]
        if color then name = string.format("|cff%02x%02x%02x%s|r", math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255), name) end
        table.insert(names, name)
    end

    return text .. ": " .. table.concat(names, ", ")
end

local function UpdateTooltipZone(tooltip, resultID)
    if not tooltip or not resultID then return end
    local resultInfo = C_LFGList.GetSearchResultInfo(resultID)
    local members = GetMembersInActivityZone(resultID, resultInfo)
    if #members == 0 then
        if tooltip.LfgUtilsZoneIcon then
            tooltip.LfgUtilsZoneIcon:Hide()
            tooltip.LfgUtilsZoneText:Hide()
        end

        return
    end

    if not tooltip.LfgUtilsZoneIcon then
        tooltip.LfgUtilsZoneIcon = tooltip:CreateTexture(nil, "ARTWORK")
        tooltip.LfgUtilsZoneIcon:SetSize(ZONE_TOOLTIP_ICON_SIZE, ZONE_TOOLTIP_ICON_SIZE)
        tooltip.LfgUtilsZoneIcon:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", 11, ZONE_TOOLTIP_BOTTOM)
        SetZoneIconTexture(tooltip.LfgUtilsZoneIcon)
        tooltip.LfgUtilsZoneText = tooltip:CreateFontString(nil, "ARTWORK", "GameFontGreen")
        tooltip.LfgUtilsZoneText:SetJustifyH("LEFT")
        tooltip.LfgUtilsZoneText:SetPoint("TOPLEFT", tooltip.LfgUtilsZoneIcon, "TOPRIGHT", 4, -1)
    end

    local zoneText = tooltip.LfgUtilsZoneText
    local textOffset = 11 + ZONE_TOOLTIP_ICON_SIZE + 4
    zoneText:SetWidth(0)
    zoneText:SetText(GetZoneTooltipText(resultInfo, members))
    local width = math.max(tooltip:GetWidth(), math.min(zoneText:GetStringWidth() + textOffset + 11, ZONE_TOOLTIP_MAX_WIDTH))
    tooltip:SetWidth(width)
    zoneText:SetWidth(width - textOffset - 11)
    local lineHeight = math.max(ZONE_TOOLTIP_ICON_SIZE, zoneText:GetStringHeight() + 1)
    tooltip.LfgUtilsZoneIcon:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", 11, ZONE_TOOLTIP_BOTTOM + lineHeight - ZONE_TOOLTIP_ICON_SIZE)
    tooltip:SetHeight(tooltip:GetHeight() + lineHeight + 8)
    tooltip.LfgUtilsZoneIcon:SetDesaturated(resultInfo.isDelisted == true)
    tooltip.LfgUtilsZoneIcon:Show()
    zoneText:Show()
end

local function HookRoleColors()
    if roleColorHooked or not LFGBrowseSearchEntry_Update then return end
    roleColorHooked = true
    hooksecurefunc("LFGBrowseSearchEntry_Update", UpdateSearchEntryRoleColors)
    hooksecurefunc("LFGBrowseSearchEntry_Update", UpdateSearchEntryZoneIcon)
    if LFGBrowseSearchEntryTooltip_UpdateAndShow then hooksecurefunc("LFGBrowseSearchEntryTooltip_UpdateAndShow", UpdateTooltipZone) end
end

local function GetLowestSideTab()
    for _, key in ipairs({"WhoListingTab", "BrowsingTab", "ListingTab"}) do
        local tab = LFGParentFrame[key]
        if tab and tab:IsShown() then return tab end
    end

    return nil
end

local function GetStrataBelow(strata)
    for index, name in ipairs(STRATA_ORDER) do
        if name == strata then return STRATA_ORDER[math.max(1, index - 1)] end
    end

    return "LOW"
end

local function DockFilterWindow()
    filterWindow:ClearAllPoints()
    local tab = GetLowestSideTab()
    if tab then
        filterWindow:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", -FILTER_OVERLAP, -FILTER_GAP)
    else
        filterWindow:SetPoint("TOPLEFT", LFGParentFrame, "TOPRIGHT", -FILTER_OVERLAP, 0)
    end

    filterWindow:SetPoint("BOTTOMLEFT", LFGParentFrame, "BOTTOMRIGHT", -FILTER_OVERLAP, 0)
    filterWindow:SetWidth(LfgUtils:GetFilterWidth(FILTER_WIDTH) + FILTER_OVERLAP)
    filterWindow:SetFrameStrata(GetStrataBelow(LFGParentFrame:GetFrameStrata()))
end

local function UpdateVisibility()
    if not filterWindow or not browseFrame then return end
    local browsing = LFGParentFrame and LFGParentFrame:IsShown() and browseFrame:IsShown()
    if toggleButton then toggleButton:SetShown(browsing) end
    if browsing and LfgUtils:IsFilterShown() then
        DockFilterWindow()
        filterWindow:Show()
    else
        filterWindow:Hide()
    end
end

local function ApplyLayout()
    filterWindow:SuspendLayout()
    LfgUtils:ApplyFilterLayout(filterWindow, LAYOUT, sectionHeaders)
    filterWindow:ResumeLayout()
end

local function AddSection(key)
    sectionHeaders[key] = filterWindow:AddCategory({
        ["label"] = LAYOUT.sectionsByKey[key].label,
        ["key"] = LAYOUT.key .. "_" .. key
    })
end

local function AddSortDropdown(label, key, default, noneValue, noneLabel)
    local choices = {{["value"] = noneValue, ["label"] = noneLabel}}
    for _, choice in ipairs(SORT_CHOICES) do
        table.insert(choices, choice)
    end

    return filterWindow:AddDropdown({
        ["label"] = label,
        ["value"] = LfgUtils:GetConfig(key, default),
        ["width"] = SORT_DROPDOWN_WIDTH,
        ["choices"] = choices,
        ["func"] = function(value)
            LfgUtils:SetConfig(key, value)
            ApplyFilters(browseFrame)
        end
    })
end

local function CreateFilterWindow()
    if filterWindow or not LFGParentFrame or not LFGBrowseFrame then return end
    browseFrame = LFGBrowseFrame
    local savedMinLevel = math.max(1, math.min(MAX_LEVEL, LfgUtils:GetConfig("FOREVER_LEVEL_MIN", 1)))
    local savedMaxLevel = math.max(1, math.min(MAX_LEVEL, LfgUtils:GetConfig("FOREVER_LEVEL_MAX", MAX_LEVEL)))
    if savedMinLevel > savedMaxLevel then savedMinLevel = savedMaxLevel end
    LfgUtils:SetConfig("FOREVER_LEVEL_MIN", savedMinLevel)
    LfgUtils:SetConfig("FOREVER_LEVEL_MAX", savedMaxLevel)
    filterWindow = LfgUtils:CreateUIWindow({
        ["name"] = "LfgUtilsForeverFilter",
        ["modern"] = true,
        ["parent"] = UIParent,
        ["pTab"] = {"TOPLEFT", LFGParentFrame, "TOPRIGHT", -FILTER_OVERLAP, 0},
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
        ["title"] = FILTER or "Filter"
    })
    if filterWindow.CloseButton then filterWindow.CloseButton:Hide() end
    LfgUtils:AddSettingsFooter(filterWindow)
    filterWindow:SuspendLayout()
    AddSection("ROLES")
    AddToggleGroup("FOREVER_ROLE_", ROLES, GetRoleLabel)
    AddSection("CLASSES")
    AddToggleGroup("FOREVER_CLASS_", GetAvailableClasses(), GetClassLabel)
    AddSection("LEVEL")
    minLevelControl = filterWindow:AddSlider({
        ["label"] = MINIMUM or "Minimum",
        ["min"] = 1,
        ["max"] = MAX_LEVEL,
        ["step"] = 1,
        ["value"] = savedMinLevel,
        ["func"] = function(value)
            if maxLevelControl and value > maxLevelControl.value then maxLevelControl.slider:SetValue(value) end
            LfgUtils:SetConfig("FOREVER_LEVEL_MIN", value)
            ApplyFilters(browseFrame)
        end
    })
    maxLevelControl = filterWindow:AddSlider({
        ["label"] = MAXIMUM or "Maximum",
        ["min"] = 1,
        ["max"] = MAX_LEVEL,
        ["step"] = 1,
        ["value"] = savedMaxLevel,
        ["func"] = function(value)
            if minLevelControl and value < minLevelControl.value then minLevelControl.slider:SetValue(value) end
            LfgUtils:SetConfig("FOREVER_LEVEL_MAX", value)
            ApplyFilters(browseFrame)
        end
    })
    AddSection("LOCATION")
    filterWindow:AddCheckbox({
        ["label"] = "LID_FILTERNEARONLY",
        ["value"] = LfgUtils:GetConfig("FOREVER_NEARONLY", false),
        ["func"] = function(value)
            LfgUtils:SetConfig("FOREVER_NEARONLY", value)
            ApplyFilters(browseFrame)
        end
    })
    AddSection("SORTING")
    AddSortDropdown("LID_FILTERSORT", "FOREVER_SORT", "NEAR", "NONE", "LID_FILTERDEFAULT")
    AddSortDropdown("LID_FILTERTHENBY", "FOREVER_THEN", "LEVEL", "NONE", "LID_FILTERNONE")
    LfgUtils:ApplyFilterLayout(filterWindow, LAYOUT, sectionHeaders)
    filterWindow:ResumeLayout()
    toggleButton = LfgUtils:CreateFilterToggle(LFGParentFrame, "LfgUtilsForeverFilterToggle", UpdateVisibility)
    LFGParentFrame:HookScript("OnShow", UpdateVisibility)
    LFGParentFrame:HookScript("OnHide", UpdateVisibility)
    browseFrame:HookScript("OnShow", UpdateVisibility)
    browseFrame:HookScript("OnHide", UpdateVisibility)
    UpdateVisibility()
end

local function GetDividerKey(dividerType)
    return "FOREVER_BROWSE_COLLAPSED_" .. tostring(dividerType)
end

local function UpdateDividerIcons(button, collapsed)
    if button.ExpandIcon then button.ExpandIcon:SetShown(collapsed) end
    if button.CollapseIcon then button.CollapseIcon:SetShown(not collapsed) end
end

local function OnDividerClick(button)
    local node = button.GetElementData and button:GetElementData()
    local data = node and node.GetData and node:GetData()
    if not data or not data.dividerType then return end
    LfgUtils:SetConfig(GetDividerKey(data.dividerType), node:IsCollapsed() == true)
end

local function OnBrowseFrameInitialized(_, button, node)
    local data = node and node.GetData and node:GetData()
    if not data or not data.dividerType then return end
    button:HookScript("OnClick", OnDividerClick)
    UpdateDividerIcons(button, node:IsCollapsed() == true)
end

local function SaveDividerStates(dataProvider)
    if not dataProvider or not dataProvider.GetChildrenNodes then return end
    for _, node in ipairs(dataProvider:GetChildrenNodes()) do
        local data = node:GetData()
        if data and data.dividerType then LfgUtils:SetConfig(GetDividerKey(data.dividerType), node:IsCollapsed() == true) end
    end
end

local function RestoreDividerStates(frame)
    local dataProvider = frame.ScrollBox and frame.ScrollBox:GetDataProvider()
    if frame.lfgUtilsDividerProvider ~= dataProvider then SaveDividerStates(frame.lfgUtilsDividerProvider) end
    frame.lfgUtilsDividerProvider = dataProvider
    if not dataProvider or not dataProvider.GetChildrenNodes then return end
    local changed = false
    for _, node in ipairs(dataProvider:GetChildrenNodes()) do
        local data = node:GetData()
        if data and data.dividerType and LfgUtils:GetConfig(GetDividerKey(data.dividerType), false) and not node:IsCollapsed() then
            node:SetCollapsed(true, false, true)
            changed = true
        end
    end

    if not changed then return end
    dataProvider:Invalidate()
    frame.ScrollBox:ForEachFrame(function(button, node)
        local data = node and node.GetData and node:GetData()
        if data and data.dividerType then UpdateDividerIcons(button, node:IsCollapsed() == true) end
    end)
end

local function HookDividers(frame)
    local view = frame.ScrollBox and frame.ScrollBox:GetView()
    if not view or not view.RegisterCallback or not ScrollBoxListViewMixin then return end
    view:RegisterCallback(ScrollBoxListViewMixin.Event.OnInitializedFrame, OnBrowseFrameInitialized, LfgUtils)
    hooksecurefunc(frame, "UpdateResults", RestoreDividerStates)
end

local function HookBrowseFrame()
    if hooked or not LFGBrowseMixin or not LFGBrowseFrame then return end
    hooked = true
    HookTooltip()
    HookRoleColors()
    HookDividers(LFGBrowseFrame)
    hooksecurefunc(LFGBrowseFrame, "UpdateResultList", function(frame)
        frame.lfgUtilsUnfilteredResults = CopyResults(frame.results)
        ApplyFilters(frame)
    end)
    CreateFilterWindow()
    if LFGBrowseFrame.results then
        LFGBrowseFrame.lfgUtilsUnfilteredResults = CopyResults(LFGBrowseFrame.results)
        ApplyFilters(LFGBrowseFrame)
    end
end

LAYOUT.onChange = function()
    if not filterWindow then return end
    ApplyLayout()
    ApplyFilters(browseFrame)
end

LfgUtils:RegisterFilterLayout(LAYOUT)
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event, addonName)
    if event == "PLAYER_LOGIN" or addonName == "Blizzard_GroupFinder_VanillaStyle" then HookBrowseFrame() end
end)
