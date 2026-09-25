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
	local stored = LfgUtilsGlobalDB and LfgUtilsGlobalDB["COLLAPSED_" .. key]
	if stored ~= nil then return stored == true end
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
	LfgUtils:SetConfig("COLLAPSED_" .. key, value == true)
end

LfgUtils.filterLayouts = {}

function LfgUtils:RegisterFilterLayout(layout)
	layout.sectionsByKey = {}
	for _, section in ipairs(layout.sections) do
		layout.sectionsByKey[section.key] = section
	end

	tinsert(LfgUtils.filterLayouts, layout)
end

function LfgUtils:GetFilterLayoutLabel(layout)
	if type(layout.label) == "function" then return layout.label() end

	return layout.label
end

function LfgUtils:IsFilterSectionShown(layout, key)
	local stored = LfgUtilsGlobalDB and LfgUtilsGlobalDB[layout.key .. "_SHOW_" .. key]
	if stored ~= nil then return stored == true end
	local section = layout.sectionsByKey[key]

	return section ~= nil and section.hidden ~= true
end

function LfgUtils:GetFilterSectionOrder(layout)
	local order = {}
	local seen = {}
	local stored = LfgUtilsGlobalDB and LfgUtilsGlobalDB[layout.key .. "_ORDER"]
	if type(stored) == "table" then
		for _, key in ipairs(stored) do
			if layout.sectionsByKey[key] and not seen[key] then
				seen[key] = true
				tinsert(order, key)
			end
		end
	end

	for _, section in ipairs(layout.sections) do
		if not seen[section.key] then tinsert(order, section.key) end
	end

	return order
end

function LfgUtils:SetFilterLayout(layout, nodes)
	local order = {}
	for _, node in ipairs(nodes) do
		tinsert(order, node.key)
		LfgUtils:SetConfig(layout.key .. "_SHOW_" .. node.key, node.checked ~= false)
	end

	LfgUtils:SetConfig(layout.key .. "_ORDER", order)
	if layout.onChange then layout.onChange() end
end

function LfgUtils:ApplyFilterLayout(win, layout, headers)
	local keys = {}
	for _, key in ipairs(LfgUtils:GetFilterSectionOrder(layout)) do
		tinsert(keys, layout.key .. "_" .. key)
	end

	win:SetCategoryOrder(keys)
	for key, header in pairs(headers) do
		win:SetElementShown(header, LfgUtils:IsFilterSectionShown(layout, key))
	end
end

function LfgUtils:GetFilterWidth(default)
	return LfgUtils:GetConfig("FILTERWIDTH", default)
end

function LfgUtils:IsFilterShown()
	return LfgUtils:GetConfig("FILTERSHOWN", true) ~= false
end

function LfgUtils:CreateFilterToggle(parent, name, onToggle)
	local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
	button:SetText(FILTER or "Filter")
	button:SetSize(button:GetTextWidth() + 24, 20)
	local parentName = parent:GetName()
	local close = parent.CloseButton or (parentName and _G[parentName .. "CloseButton"])
	if close then
		button:SetPoint("RIGHT", close, "LEFT", -2, 0)
	else
		button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -28, -2)
	end

	local function UpdateHighlight()
		if close then button:SetFrameLevel(close:GetFrameLevel() + 1) end
		if LfgUtils:IsFilterShown() then
			button:LockHighlight()
		else
			button:UnlockHighlight()
		end
	end

	button:SetScript(
		"OnClick",
		function()
			LfgUtils:SetConfig("FILTERSHOWN", not LfgUtils:IsFilterShown())
			UpdateHighlight()
			onToggle()
		end
	)
	button:HookScript("OnShow", UpdateHighlight)
	UpdateHighlight()

	return button
end

function LfgUtils:AddSettingsFooter(win)
	local footer = win:AddFooter({["height"] = 22})
	local button = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
	button:SetText(LfgUtils:Trans("LID_OPENSETTINGS"))
	button:SetSize(button:GetTextWidth() + 24, 20)
	button:SetPoint("LEFT", footer, "LEFT", 8, 0)
	button:SetScript("OnClick", function() LfgUtils:ShowSettings() end)

	return button
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
