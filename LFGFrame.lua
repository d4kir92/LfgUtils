local _, LfgUtils = ...

function LfgUtils:GetFlagString(realmName, text)
	if not LfgUtils:GetConfig("LFGSHOWLANGUAGEFLAG", false) then return text end
	local realmLang = LfgUtils:GetRealmFlag(realmName)
	if realmLang and realmLang ~= "" then
		return "|TInterface\\AddOns\\LfgUtils\\media\\flags\\" .. realmLang .. ":0:2:0:0|t " .. text
	end

	return text
end

local function GetRealmFromName(name)
	local separator = string.find(name, "-")
	if separator then return strsub(name, separator + 1) end

	return GetRealmName()
end

local function HookApplicationViewer()
	if LfgUtils.applicationViewerHooked or not LFGListApplicationViewer_UpdateApplicantMember then return end
	LfgUtils.applicationViewerHooked = true
	hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", function(member, id, index)
		local name, class = C_LFGList.GetApplicantMemberInfo(id, index)
		local activeEntryInfo = C_LFGList.GetActiveEntryInfo()
		if not activeEntryInfo or not name then return end
		local activityID = activeEntryInfo.activityIDs and activeEntryInfo.activityIDs[1]
		if not activityID then return end
		local bestDungeonScoreForListing = C_LFGList.GetApplicantDungeonScoreForListing and C_LFGList.GetApplicantDungeonScoreForListing(id, index, activityID)
		local showDungeonScore = LfgUtils:GetConfig("LFGSHOWDUNGEONSCORE", false)
		local showDungeonKey = LfgUtils:GetConfig("LFGSHOWDUNGEONKEY", false)
		if member.Rating and bestDungeonScoreForListing and (showDungeonScore or showDungeonKey) then
			local font, _, flags = member.Rating:GetFont()
			if font then member.Rating:SetFont(font, 8, flags) end
			if member.Rating:IsShown() then
				local info = {}
				local dungeonKey = bestDungeonScoreForListing.bestRunLevel
				local dungeonRating = bestDungeonScoreForListing.mapScore
				if showDungeonKey and dungeonKey and dungeonKey > 0 then info[#info + 1] = dungeonKey end
				if showDungeonScore and dungeonRating and dungeonRating > 0 then
					local color = C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(dungeonRating)
					info[#info + 1] = color and ("|c" .. color:GenerateHexColor() .. dungeonRating .. "|r") or dungeonRating
				end
				if #info > 0 then member.Rating:SetText((member.Rating:GetText() or "") .. " (" .. table.concat(info, ":") .. ")") end
			end
		end

		if member.RoleIcon1 and LfgUtils.GetClassAtlas then
			if not member.LfgUtilsClassIcon then
				member.LfgUtilsClassIcon = member:CreateTexture(nil, "OVERLAY")
				member.LfgUtilsClassIcon:SetSize(16, 16)
				member.LfgUtilsClassIcon:SetPoint("RIGHT", member.RoleIcon1, "LEFT", -2, 0)
				for pointIndex = 1, member.Name:GetNumPoints() do
					local point, relativeTo, relativePoint, x, y = member.Name:GetPoint(pointIndex)
					if point == "RIGHT" then
						member.LfgUtilsNameRight = {relativeTo or member, relativePoint, x, y}
						break
					end
				end
			end
			if LfgUtils:GetConfig("LFGSHOWCLASSICON", false) and class then
				member.LfgUtilsClassIcon:SetAtlas(LfgUtils:GetClassAtlas(class))
				member.LfgUtilsClassIcon:Show()
				member.Name:SetPoint("RIGHT", member.RoleIcon1, "LEFT", -20, 0)
			else
				member.LfgUtilsClassIcon:Hide()
				if member.LfgUtilsNameRight then
					member.Name:SetPoint("RIGHT", member.LfgUtilsNameRight[1], member.LfgUtilsNameRight[2], member.LfgUtilsNameRight[3], member.LfgUtilsNameRight[4])
				end
			end
		end

		local text = member.Name:GetText()
		if text then
			local languageText = LfgUtils:GetFlagString(GetRealmFromName(name), text)
			if member.Name.SetWordWrap then member.Name:SetWordWrap(false) end
			member.Name:SetText(languageText)
		end
	end)
end

local function HookSearchEntries()
	if LfgUtils.searchEntryHooked or not LFGListSearchEntry_Update then return end
	LfgUtils.searchEntryHooked = true
	hooksecurefunc("LFGListSearchEntry_Update", function(entry)
		local searchResultInfo = C_LFGList.GetSearchResultInfo(entry.resultID)
		if not searchResultInfo or not searchResultInfo.leaderName then return end
		local text = entry.Name:GetText()
		if not text then return end
		if searchResultInfo.isWarMode then text = "[WM] " .. text end
		if searchResultInfo.requiredItemLevel > 0 then text = "[ilvl: " .. searchResultInfo.requiredItemLevel .. "+] " .. text end
		local dungeonScoreInfo = searchResultInfo.leaderDungeonScoreInfo
		if dungeonScoreInfo and dungeonScoreInfo.mapScore then
			local score = ""
			if LfgUtils:GetConfig("LFGSHOWOVERALLSCORE", false) and searchResultInfo.leaderOverallDungeonScore and searchResultInfo.leaderOverallDungeonScore > 0 then
				local color = C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(searchResultInfo.leaderOverallDungeonScore)
				if color then score = "|c" .. color:GenerateHexColor() .. searchResultInfo.leaderOverallDungeonScore .. "|r" end
			end
			local info = {}
			if LfgUtils:GetConfig("LFGSHOWDUNGEONKEY", false) and dungeonScoreInfo.bestRunLevel and dungeonScoreInfo.bestRunLevel > 0 then
				info[#info + 1] = dungeonScoreInfo.bestRunLevel
			end
			if LfgUtils:GetConfig("LFGSHOWDUNGEONSCORE", false) and dungeonScoreInfo.mapScore > 0 then
				local color = C_ChallengeMode and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(dungeonScoreInfo.mapScore)
				info[#info + 1] = color and ("|c" .. color:GenerateHexColor() .. dungeonScoreInfo.mapScore .. "|r") or dungeonScoreInfo.mapScore
			end
			if #info > 0 then score = score ~= "" and (score .. " (" .. table.concat(info, ":") .. ")") or table.concat(info, ":") end
			if score ~= "" then text = score .. " " .. text end
		end
		entry.Name:SetText(text)
		local activityText = entry.ActivityName:GetText()
		if activityText then
			if entry.ActivityName.SetWordWrap then entry.ActivityName:SetWordWrap(false) end
			entry.ActivityName:SetText(LfgUtils:GetFlagString(GetRealmFromName(searchResultInfo.leaderName), activityText))
		end
	end)
end

function LfgUtils:InitLFGFrame()
	if not C_LFGList then return end
	HookApplicationViewer()
	HookSearchEntries()
end

local loader = CreateFrame("Frame")
LfgUtils:RegisterEvent(loader, "ADDON_LOADED")
LfgUtils:RegisterEvent(loader, "PLAYER_LOGIN")
loader:SetScript("OnEvent", function() LfgUtils:InitLFGFrame() end)
