local _, LfgUtils = ...

local ICON = 134148
local MIGRATION_KEYS = {
	"LFGSHOWLANGUAGEFLAG",
	"LFGSHOWCLASSICON",
	"LFGSHOWOVERALLSCORE",
	"LFGSHOWDUNGEONSCORE",
	"LFGSHOWDUNGEONKEY"
}

LfgUtils:SetAddonOutput("LfgUtils", ICON)

function LfgUtils:GetConfig(key, default)
	LfgUtilsGlobalDB = LfgUtilsGlobalDB or {}
	if LfgUtilsGlobalDB[key] == nil then LfgUtilsGlobalDB[key] = default end

	return LfgUtilsGlobalDB[key]
end

function LfgUtils:SetConfig(key, value)
	LfgUtilsGlobalDB = LfgUtilsGlobalDB or {}
	LfgUtils:SV(LfgUtilsGlobalDB, key, value)
end

function LfgUtils:GetCollapsed(key)
	local collapsed = LfgUtils:GetConfig("COLLAPSED", {})
	return collapsed[key]
end

function LfgUtils:SetCollapsed(key, value)
	local collapsed = LfgUtils:GetConfig("COLLAPSED", {})
	if value then
		collapsed[key] = true
	else
		collapsed[key] = nil
	end
end

function LfgUtils:MigrateImproveAnySettings()
	LfgUtilsGlobalDB = LfgUtilsGlobalDB or {}
	if LfgUtilsGlobalDB["IMPROVEANY_MIGRATED"] then return end
	if type(IATAB) ~= "table" or type(IATAB["PROFILES"]) ~= "table" then return end
	local profileName = IATAB["CURRENTPROFILE"] or "DEFAULT"
	local profile = IATAB["PROFILES"][profileName]
	local options = profile and profile["ELES"] and profile["ELES"]["OPTIONS"]
	if type(options) ~= "table" then return end
	for _, key in ipairs(MIGRATION_KEYS) do
		local option = options[key]
		if LfgUtilsGlobalDB[key] == nil and type(option) == "table" and option["ENABLED"] ~= nil then
			LfgUtilsGlobalDB[key] = option["ENABLED"]
		end
	end
	LfgUtilsGlobalDB["IMPROVEANY_MIGRATED"] = true
end
