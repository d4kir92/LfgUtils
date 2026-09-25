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

local function BuildLayoutNodes(layout)
	local nodes = {}
	for _, key in ipairs(LfgUtils:GetFilterSectionOrder(layout)) do
		tinsert(
			nodes,
			{
				["key"] = key,
				["label"] = layout.sectionsByKey[key].label,
				["checked"] = LfgUtils:IsFilterSectionShown(layout, key)
			}
		)
	end

	return nodes
end

local function AddLayoutList(layout, label)
	settingsWindow:AddOrderList({
		["label"] = label,
		["search"] = "FILTERCATEGORIES",
		["items"] = BuildLayoutNodes(layout),
		["func"] = function(nodes) LfgUtils:SetFilterLayout(layout, nodes) end
	})
end

local function AddFilterLayouts()
	local layouts = LfgUtils.filterLayouts
	if #layouts == 0 then return end
	settingsWindow:AddCategory({
		["label"] = "LID_FILTERCATEGORIES",
		["key"] = "FILTERCATEGORIES",
		["search"] = "FILTERCATEGORIES"
	})
	if #layouts == 1 then
		AddLayoutList(layouts[1], "LID_FILTERCATEGORIES")

		return
	end

	for _, layout in ipairs(layouts) do
		local label = LfgUtils:GetFilterLayoutLabel(layout)
		settingsWindow:AddCategory({
			["label"] = label,
			["key"] = "FILTERCATEGORIES_" .. layout.key,
			["search"] = "FILTERCATEGORIES",
			["level"] = 2
		})
		AddLayoutList(layout, label)
	end
end

function LfgUtils:ToggleSettings()
	if settingsWindow then settingsWindow:Toggle() end
end

function LfgUtils:ShowSettings()
	if not settingsWindow then return end
	settingsWindow:Show()
	settingsWindow:Raise()
end

function LfgUtils:InitSettings()
	if settingsWindow then return end
	LfgUtilsGlobalDB = LfgUtilsGlobalDB or {}
	LfgUtils:SetVersion(ICON, GetTocVersion())
	LfgUtils:SetAppendTab(LfgUtilsGlobalDB)
	settingsWindow = LfgUtils:CreateUIWindow({
		["name"] = "LfgUtilsSettings",
		["modern"] = true,
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
	AddFilterLayouts()
	settingsWindow:ResumeLayout()
	LfgUtils:AddSlash("lfgutils", function() LfgUtils:ToggleSettings() end)
end

local loader = CreateFrame("Frame")
LfgUtils:RegisterEvent(loader, "PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	LfgUtils:MigrateImproveAnySettings()
	LfgUtils:InitSettings()
end)
