local _, LfgUtils = ...

local FILTER_WIDTH = 250
local FILTER_HEIGHT_FALLBACK = 512
local MAX_LEVEL = 60
local filterWindow = nil
local browseFrame = nil
local classChecks = {}
local minLevelControl = nil
local maxLevelControl = nil
local hooked = false

local function GetAvailableClasses()
    return {"WARRIOR", "PALADIN", "SHAMAN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "DRUID"}
end

local function GetClassName(classFilename)
    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFilename] then
        return LOCALIZED_CLASS_NAMES_MALE[classFilename]
    end

    return classFilename
end

local function CopyResults(results)
    local copy = {}
    for index, resultID in ipairs(results or {}) do
        copy[index] = resultID
    end

    return copy
end

local function MatchesMember(memberInfo, minLevel, maxLevel)
    if not memberInfo then return false end
    local classFilename = memberInfo.classFilename
    local level = tonumber(memberInfo.level)
    if not classFilename or not level then return false end
    if not LfgUtils:GetConfig("FOREVER_CLASS_" .. classFilename, true) then return false end

    return level >= minLevel and level <= maxLevel
end

local function MatchesResult(resultID)
    local minLevel = LfgUtils:GetConfig("FOREVER_LEVEL_MIN", 1)
    local maxLevel = LfgUtils:GetConfig("FOREVER_LEVEL_MAX", MAX_LEVEL)
    local resultInfo = C_LFGList.GetSearchResultInfo(resultID)
    if not resultInfo then return true end
    local foundMember = false
    for memberIndex = 1, resultInfo.numMembers or 1 do
        local memberInfo = C_LFGList.GetSearchResultPlayerInfo(resultID, memberIndex)
        if memberInfo then
            foundMember = true
            if MatchesMember(memberInfo, minLevel, maxLevel) then return true end
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

local function UpdateVisibility()
    if not filterWindow or not browseFrame then return end
    if LFGParentFrame and LFGParentFrame:IsShown() and browseFrame:IsShown() then
        filterWindow:Show()
    else
        filterWindow:Hide()
    end
end

local function UpdateFilterHeight(_, height)
    if not filterWindow then return end
    local targetHeight = tonumber(height)
    if not targetHeight and LFGParentFrame then targetHeight = LFGParentFrame:GetHeight() end
    if not targetHeight or targetHeight <= 0 then targetHeight = FILTER_HEIGHT_FALLBACK end
    filterWindow:SetHeight(targetHeight)
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
        ["parent"] = UIParent,
        ["pTab"] = {"TOPLEFT", LFGParentFrame, "TOPRIGHT", 4, 0},
        ["width"] = FILTER_WIDTH,
        ["height"] = FILTER_HEIGHT_FALLBACK,
        ["resizable"] = false,
        ["escClose"] = false,
        ["title"] = FILTER or "Filter"
    })
    if filterWindow.CloseButton then filterWindow.CloseButton:Hide() end
    filterWindow:SuspendLayout()
    for _, classFilename in ipairs(GetAvailableClasses()) do
        local classToken = classFilename
        classChecks[classToken] = filterWindow:AddCheckbox({
            ["label"] = GetClassName(classToken),
            ["value"] = LfgUtils:GetConfig("FOREVER_CLASS_" .. classToken, true),
            ["func"] = function(value)
                LfgUtils:SetConfig("FOREVER_CLASS_" .. classToken, value)
                ApplyFilters(browseFrame)
            end
        })
    end
    minLevelControl = filterWindow:AddSlider({
        ["label"] = (LEVEL or "Level") .. " " .. (MINIMUM or "Min"),
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
        ["label"] = (LEVEL or "Level") .. " " .. (MAXIMUM or "Max"),
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
    LFGParentFrame:HookScript("OnSizeChanged", UpdateFilterHeight)
    browseFrame:HookScript("OnShow", UpdateVisibility)
    browseFrame:HookScript("OnHide", UpdateVisibility)
    UpdateFilterHeight()
    UpdateVisibility()
end

local function HookBrowseFrame()
    if hooked or not LFGBrowseMixin or not LFGBrowseFrame then return end
    hooked = true
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
