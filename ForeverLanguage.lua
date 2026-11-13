local _, LfgUtils = ...

local Language = {}
LfgUtils.ForeverLanguage = Language
Language.FALLBACK_NAMES = {
    ["enUS"] = "English",
    ["deDE"] = "German",
    ["frFR"] = "French",
    ["esES"] = "Spanish (Spain)",
    ["esMX"] = "Spanish (Mexico)",
    ["itIT"] = "Italian",
    ["ptBR"] = "Portuguese",
    ["ruRU"] = "Russian",
    ["koKR"] = "Korean",
    ["zhCN"] = "Chinese (Simplified)",
    ["zhTW"] = "Chinese (Traditional)"
}

Language.SIBLINGS = {
    ["esES"] = "esMX",
    ["esMX"] = "esES",
    ["zhCN"] = "zhTW",
    ["zhTW"] = "zhCN"
}

Language.FLAG_PATH = "Interface\\AddOns\\LfgUtils\\media\\flags\\"
Language.searching = false
Language.searchToken = 0
Language.SEARCH_TIMEOUT = 15

function Language:GetClientCode()
    local locale = GetLocale()
    if locale == "enGB" then return "enUS" end

    return locale
end

function Language:GetAvailable()
    if self.available then return self.available end
    local list = nil
    if C_LFGList and C_LFGList.GetAvailableLanguageSearchFilter then
        local ok, result = pcall(C_LFGList.GetAvailableLanguageSearchFilter)
        if ok and type(result) == "table" then list = result end
    end

    self.available = {}
    local client = self:GetClientCode()
    local hasClient = false
    for _, code in ipairs(list or {}) do
        if type(code) == "string" then
            tinsert(self.available, code)
            if code == client then hasClient = true end
        end
    end

    if not hasClient then tinsert(self.available, 1, client) end

    return self.available
end

function Language:GetRawName(code)
    local name = _G["LFG_LIST_LANGUAGE_" .. string.upper(code)]
    if type(name) == "string" and name ~= "" then return name end

    return self.FALLBACK_NAMES[code] or code
end

function Language:GetName(code)
    local name = self:GetRawName(code)
    local sibling = self.SIBLINGS[code]
    if sibling and self:GetRawName(sibling) == name then name = name .. " (" .. string.sub(code, 3) .. ")" end

    return name
end

function Language:GetLabel(code)
    return "|T" .. self.FLAG_PATH .. code .. ":0:2:0:0|t " .. self:GetName(code)
end

function Language:IsActive()
    return self.isSectionShown == nil or self.isSectionShown()
end

function Language:GetMode()
    if not self:IsActive() then return "DEFAULT" end

    return LfgUtils:GetConfig("FOREVER_LANGUAGE_MODE", "DEFAULT")
end

function Language:IsSelected(code)
    return LfgUtils:GetConfig("FOREVER_LANGUAGE_" .. code, false) == true
end

function Language:HasSelection()
    local client = self:GetClientCode()
    for _, code in ipairs(self:GetAvailable()) do
        if code ~= client and self:IsSelected(code) then return true end
    end

    return false
end

function Language:IsSearched(code, mode)
    if code == self:GetClientCode() or mode == "ALL" then return true end

    return mode == "CUSTOM" and self:IsSelected(code)
end

function Language:BuildFilter()
    local mode = self:GetMode()
    if mode == "DEFAULT" then return nil end
    local filter = {}
    for _, code in ipairs(self:GetAvailable()) do
        filter[code] = self:IsSearched(code, mode)
    end

    return filter
end

function Language:GetSearchedText()
    local mode = self:GetMode()
    if mode == "ALL" then return LfgUtils:Trans("LID_LANGUAGEALL") end
    if mode == "DEFAULT" then return LfgUtils:Trans("LID_LANGUAGEDEFAULT") end
    local names = {}
    for _, code in ipairs(self:GetAvailable()) do
        if self:IsSearched(code, mode) then tinsert(names, self:GetName(code)) end
    end

    return table.concat(names, ", ")
end

function Language:GetCategoryID()
    local dropdown = self.browseFrame and self.browseFrame.CategoryDropdown
    if not dropdown or not dropdown.GetValue then return 0 end
    local ok, value = pcall(dropdown.GetValue, dropdown)
    if ok and type(value) == "number" then return value end

    return 0
end

function Language:IsActivityInLevelRange(activityID, playerLevel)
    local info = C_LFGList.GetActivityInfoTable(activityID)
    if not info then return true end
    if (info.minLevelSuggestion or 0) > 0 and info.minLevelSuggestion > playerLevel then return false end
    if (info.maxLevelSuggestion or 0) > 0 and info.maxLevelSuggestion < playerLevel then return false end

    return true
end

function Language:GetActivities(categoryID)
    local activities = {}
    local dropdown = self.browseFrame.ActivityDropdown
    for _, activityID in ipairs(dropdown and dropdown.selectedValues or {}) do
        tinsert(activities, activityID)
    end

    if #activities > 0 then return activities end
    local ignoreLevel = C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("disableSuggestedLevelActivityFilter")
    local listed = {}
    local entry = C_LFGList.GetActiveEntryInfo()
    for _, activityID in ipairs(entry and entry.activityIDs or {}) do
        listed[activityID] = true
    end

    local playerLevel = UnitLevel("player")
    for _, activityID in ipairs(C_LFGList.GetAvailableActivities(categoryID) or {}) do
        if ignoreLevel or listed[activityID] or self:IsActivityInLevelRange(activityID, playerLevel) then tinsert(activities, activityID) end
    end

    return activities
end

function Language:CanSearch()
    if not self.browseFrame or not self.browseFrame:IsVisible() or self.searching then return false end
    local refresh = self.browseFrame.RefreshButton
    if refresh and not refresh:IsEnabled() then return false end

    return self:GetCategoryID() > 0
end

function Language:Search()
    if not self:CanSearch() then return end
    local categoryID = self:GetCategoryID()
    local ok = pcall(C_LFGList.Search, categoryID, 0, 0, self:BuildFilter(), false, nil, self:GetActivities(categoryID))
    if not ok then return end
    self.searching = true
    self.searchToken = self.searchToken + 1
    local token = self.searchToken
    if self.browseFrame.SearchingSpinner then self.browseFrame.SearchingSpinner:Show() end
    if self.browseFrame.NoResultsFound then self.browseFrame.NoResultsFound:Hide() end
    self:UpdateButton()
    C_Timer.After(
        self.SEARCH_TIMEOUT,
        function()
            if Language.searching and Language.searchToken == token then
                Language.searching = false
                Language:UpdateButton()
            end
        end
    )
end

function Language:UpdateButton()
    if not self.button then return end
    self.button:SetShown(self:GetMode() ~= "DEFAULT")
    self.button:SetEnabled(not self.searching and self:CanSearch())
end

function Language:OnButtonEnter()
    GameTooltip:SetOwner(self.button, "ANCHOR_RIGHT")
    GameTooltip:SetText(LFG_LIST_SEARCH_AGAIN or SEARCH or "Search", HIGHLIGHT_FONT_COLOR:GetRGB())
    GameTooltip:AddLine(self:GetSearchedText(), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
    GameTooltip:Show()
end

function Language:CreateButton()
    local native = self.browseFrame.RefreshButton
    if self.button or not native then return end
    local button = CreateFrame("Button", "LfgUtilsLanguageSearchButton", self.browseFrame)
    button:SetAllPoints(native)
    button:SetFrameLevel(native:GetFrameLevel() + 3)
    button:SetNormalTexture("Interface\\Buttons\\UI-SquareButton-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-SquareButton-Down")
    button:SetDisabledTexture("Interface\\Buttons\\UI-SquareButton-Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    button.Icon = button:CreateTexture(nil, "ARTWORK", nil, 5)
    button.Icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    button.Icon:SetSize(16, 16)
    button.Icon:SetPoint("CENTER", -1, 0)
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnMouseDown", function(sel) if sel:IsEnabled() then sel.Icon:SetPoint("CENTER", -2, -1) end end)
    button:SetScript("OnMouseUp", function(sel) sel.Icon:SetPoint("CENTER", -1, 0) end)
    button:SetScript("OnEnter", function() Language:OnButtonEnter() end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript(
        "OnClick",
        function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            Language:Search()
        end
    )
    self.button = button
    self:UpdateButton()
end

function Language:SetMode(mode)
    LfgUtils:SetConfig("FOREVER_LANGUAGE_MODE", mode)
    self:RefreshChecks()
    self:UpdateButton()
    self:Search()
end

function Language:ToggleLanguage(code, value)
    if LfgUtils:GetConfig("FOREVER_LANGUAGE_MODE", "DEFAULT") ~= "CUSTOM" then
        for _, other in ipairs(self:GetAvailable()) do
            LfgUtils:SetConfig("FOREVER_LANGUAGE_" .. other, false)
        end
    end

    LfgUtils:SetConfig("FOREVER_LANGUAGE_" .. code, value == true)
    if self:HasSelection() then
        self:SetMode("CUSTOM")
    else
        self:SetMode("DEFAULT")
    end
end

function Language:RefreshChecks()
    if not self.checks then return end
    local mode = LfgUtils:GetConfig("FOREVER_LANGUAGE_MODE", "DEFAULT")
    self.checks.DEFAULT:SetChecked(mode == "DEFAULT")
    self.checks.ALL:SetChecked(mode == "ALL")
    local client = self:GetClientCode()
    for code, check in pairs(self.checks.languages) do
        check:SetChecked(code == client or (mode == "CUSTOM" and self:IsSelected(code)))
    end
end

function Language:AddOptions(win, isSectionShown)
    self.isSectionShown = isSectionShown
    self.checks = {["languages"] = {}}
    for _, mode in ipairs({"DEFAULT", "ALL"}) do
        local current = mode
        self.checks[current] = win:AddCheckbox({
            ["label"] = current == "ALL" and "LID_LANGUAGEALL" or "LID_LANGUAGEDEFAULT",
            ["value"] = false,
            ["func"] = function() Language:SetMode(current) end
        })
    end

    local client = self:GetClientCode()
    for _, code in ipairs(self:GetAvailable()) do
        local current = code
        local label = self:GetLabel(current)
        if current == client then label = label .. " (" .. LfgUtils:Trans("LID_LANGUAGEALWAYS") .. ")" end
        local check = win:AddCheckbox({
            ["label"] = label,
            ["value"] = false,
            ["func"] = function(value) Language:ToggleLanguage(current, value) end
        })
        if current == client then
            check:SetEnabled(false)
            check.Label:SetFontObject("GameFontDisable")
        end

        self.checks.languages[current] = check
    end

    if LfgUtils:GetConfig("FOREVER_LANGUAGE_MODE", "DEFAULT") == "CUSTOM" and not self:HasSelection() then LfgUtils:SetConfig("FOREVER_LANGUAGE_MODE", "DEFAULT") end
    self:RefreshChecks()
end

function Language:OnEvent(event)
    if event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" or event == "LFG_LIST_SEARCH_FAILED" then self.searching = false end
    self:UpdateButton()
end

function Language:Install(browseFrame)
    if self.installed or not browseFrame or not C_LFGList or not C_LFGList.Search then return end
    self.installed = true
    self.browseFrame = browseFrame
    self:CreateButton()
    if browseFrame.UpdateButtonState then hooksecurefunc(browseFrame, "UpdateButtonState", function() Language:UpdateButton() end) end
    browseFrame:HookScript("OnShow", function() Language:UpdateButton() end)
    local events = CreateFrame("Frame")
    events:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    events:RegisterEvent("LFG_LIST_SEARCH_FAILED")
    events:SetScript("OnEvent", function(_, event) Language:OnEvent(event) end)
end
