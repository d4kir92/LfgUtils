local _, LfgUtils = ...
local ICON = 134148
local DEFAULT_WIDTH = 420
local DEFAULT_HEIGHT = 340
local settingsWindow = nil

local function GetTocVersion()
	if C_AddOns and C_AddOns.GetAddOnMetadata then return C_AddOns.GetAddOnMetadata("LfgUtils", "Version") end
	if GetAddOnMetadata then return GetAddOnMetadata("LfgUtils", "Version") end

	return "0.0.0"
end

local function AddCheckbox(key)
	settingsWindow:AddCheckbox({
		["label"] = "LID_" .. key,
		["search"] = key,
		["value"] = LfgUtils:GetConfig(key, false),
		["func"] = function(value) LfgUtils:SetConfig(key, value) end
	})
end

function LfgUtils:ToggleSettings()
	if settingsWindow then settingsWindow:Toggle() end
end

function LfgUtils:InitSettings()
	if settingsWindow then return end
	LfgUtilsGlobalDB = LfgUtilsGlobalDB or {}
	LfgUtils:SetVersion(ICON, GetTocVersion())
	LfgUtils:SetAppendTab(LfgUtilsGlobalDB)
	settingsWindow = LfgUtils:CreateUIWindow({
		["name"] = "LfgUtilsSettings",
		["pTab"] = {"CENTER"},
		["width"] = LfgUtils:GetConfig("WINDOWWIDTH", DEFAULT_WIDTH),
		["height"] = LfgUtils:GetConfig("WINDOWHEIGHT", DEFAULT_HEIGHT),
		["minWidth"] = 340,
		["minHeight"] = 260,
		["onResize"] = function(width, height)
			LfgUtils:SetConfig("WINDOWWIDTH", width)
			LfgUtils:SetConfig("WINDOWHEIGHT", height)
		end,
		["getCollapsed"] = function(key) return LfgUtils:GetCollapsed(key) end,
		["setCollapsed"] = function(key, value) LfgUtils:SetCollapsed(key, value) end,
		["title"] = format("|T%d:16:16:0:0|t LFG Utils v%s", ICON, GetTocVersion())
	})

	settingsWindow:SuspendLayout()
	settingsWindow:AddSearch()
	local hasLFGList = C_LFGList and C_LFGList.GetApplicantMemberInfo
	if hasLFGList then
		settingsWindow:AddCategory({
			["label"] = "LID_LOOKINGFORGROUP",
			["key"] = "LOOKINGFORGROUP",
			["search"] = "LOOKINGFORGROUP"
		})
		AddCheckbox("LFGSHOWLANGUAGEFLAG")
		AddCheckbox("LFGSHOWCLASSICON")
		local hasMythicScore = C_LFGList.GetApplicantDungeonScoreForListing and C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor
		if hasMythicScore then
			AddCheckbox("LFGSHOWOVERALLSCORE")
			AddCheckbox("LFGSHOWDUNGEONSCORE")
			AddCheckbox("LFGSHOWDUNGEONKEY")
		end
	end
	settingsWindow:ResumeLayout()
	LfgUtils:AddSlash("lfgutils", function() LfgUtils:ToggleSettings() end)
end

local loader = CreateFrame("Frame")
LfgUtils:RegisterEvent(loader, "PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	LfgUtils:MigrateImproveAnySettings()
	LfgUtils:InitSettings()
end)
