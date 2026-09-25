local _, LfgUtils = ...

local FILTER_WIDTH = 250
local FILTER_HEIGHT_FALLBACK = 512
local FILTER_GAP = 4
local FILTER_OVERLAP = 8
local STRATA_ORDER = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"}
local MAX_LEVEL = 60
local ROLES = {"TANK", "HEALER", "DAMAGER"}
local ROLE_FALLBACK_NAMES = {["TANK"] = "Tank", ["HEALER"] = "Healer", ["DAMAGER"] = "Damage"}
local LFG_ROLE_KEYS = {["TANK"] = "tank", ["HEALER"] = "healer", ["DAMAGER"] = "dps"}
local ROLE_ATLASES = {["TANK"] = "groupfinder-icon-role-micro-tank", ["HEALER"] = "groupfinder-icon-role-micro-heal", ["DAMAGER"] = "groupfinder-icon-role-micro-dps"}
local filterWindow = nil
local browseFrame = nil
local minLevelControl = nil
local maxLevelControl = nil
local hooked = false
local tooltipHooked = false

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

local function MatchesMember(memberInfo, minLevel, maxLevel, isSolo, checkRoles)
    if not memberInfo then return false end
    local classFilename = memberInfo.classFilename
    local level = tonumber(memberInfo.level)
    if not classFilename or not level then return false end
    if not LfgUtils:GetConfig("FOREVER_CLASS_" .. classFilename, true) then return false end
    if checkRoles and not MatchesRole(memberInfo, isSolo) then return false end

    return level >= minLevel and level <= maxLevel
end

local function MatchesResult(resultID)
    local minLevel = LfgUtils:GetConfig("FOREVER_LEVEL_MIN", 1)
    local maxLevel = LfgUtils:GetConfig("FOREVER_LEVEL_MAX", MAX_LEVEL)
    local checkRoles = IsRoleFilterActive()
    local resultInfo = C_LFGList.GetSearchResultInfo(resultID)
    if not resultInfo then return true end
    local numMembers = resultInfo.numMembers or 1
    local isSolo = numMembers == 1
    local foundMember = false
    for memberIndex = 1, numMembers do
        local memberInfo = C_LFGList.GetSearchResultPlayerInfo(resultID, memberIndex)
        if memberInfo then
            foundMember = true
            if MatchesMember(memberInfo, minLevel, maxLevel, isSolo, checkRoles) then return true end
        end
    end

    return not foundMember
end

local function ApplyFilters(frame)
    if not frame or not frame.lfgUtilsUnfilteredResults then return end
    local filtered = {}
    for _, resultID in ipairs(frame.lfgUtilsUnfilteredResults) do
        if MatchesResult(resultID) then table.insert(filtered, resultID) end
    end
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
    filterWindow:SetFrameStrata(GetStrataBelow(LFGParentFrame:GetFrameStrata()))
end

local function UpdateVisibility()
    if not filterWindow or not browseFrame then return end
    if LFGParentFrame and LFGParentFrame:IsShown() and browseFrame:IsShown() then
        DockFilterWindow()
        filterWindow:Show()
    else
        filterWindow:Hide()
    end
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
        ["width"] = FILTER_WIDTH + FILTER_OVERLAP,
        ["height"] = FILTER_HEIGHT_FALLBACK,
        ["resizable"] = false,
        ["movable"] = false,
        ["escClose"] = false,
        ["getCollapsed"] = function(key) return LfgUtils:GetCollapsed(key) end,
        ["setCollapsed"] = function(key, value) LfgUtils:SetCollapsed(key, value) end,
        ["title"] = FILTER or "Filter"
    })
    if filterWindow.CloseButton then filterWindow.CloseButton:Hide() end
    filterWindow:SuspendLayout()
    filterWindow:AddCategory({
        ["label"] = ROLE or "Role",
        ["key"] = "FOREVER_ROLES"
    })
    AddToggleGroup("FOREVER_ROLE_", ROLES, GetRoleLabel)
    filterWindow:AddCategory({
        ["label"] = CLASS or "Class",
        ["key"] = "FOREVER_CLASSES"
    })
    AddToggleGroup("FOREVER_CLASS_", GetAvailableClasses(), GetClassLabel)
    filterWindow:AddCategory({
        ["label"] = LEVEL or "Level",
        ["key"] = "FOREVER_LEVEL"
    })
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
    filterWindow:ResumeLayout()
    LFGParentFrame:HookScript("OnShow", UpdateVisibility)
    LFGParentFrame:HookScript("OnHide", UpdateVisibility)
    browseFrame:HookScript("OnShow", UpdateVisibility)
    browseFrame:HookScript("OnHide", UpdateVisibility)
    UpdateVisibility()
end

local function HookBrowseFrame()
    if hooked or not LFGBrowseMixin or not LFGBrowseFrame then return end
    hooked = true
    HookTooltip()
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

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event, addonName)
    if event == "PLAYER_LOGIN" or addonName == "Blizzard_GroupFinder_VanillaStyle" then HookBrowseFrame() end
end)
