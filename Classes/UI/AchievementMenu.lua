local function thousand_sep(number)
	local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
	int = int:reverse():gsub("(%d%d%d)", "%1,")
	return minus .. int:reverse():gsub("^,", "") .. fraction
end

local default_margin = 10
local cash_icon = "guis/textures/pd2/blackmarket/cash_drop"
local cc_icon = "guis/textures/pd2/ccoin"
local xp_icon = "guis/textures/pd2/blackmarket/xp_drop"

BeardLibAchievementMenu = BeardLibAchievementMenu or BeardLib:MenuClass("Achievement")

function BeardLibAchievementMenu:init()
	local accent_color = BeardLib.Options:GetValue("MenuColor")

	self._menu = MenuUI:new({
		name = "BeardLibAchievementMenu",
		animate_colors = true,
		layer = 1500,
		background_color = Color(0.8, 0.2, 0.2, 0.2),
		use_default_close_key = true,
		accent_color = accent_color,
		inherit_values = {
			background_color = Color.transparent,
			scroll_color = Color.white:with_alpha(0.1),
			highlight_color = Color.white:with_alpha(0.1)
		},
		animate_toggle = true
	})

	self._initialized = false
	-- Deprecated, try not to use.
	BeardLib.managers.custom_achievement_menu = self
end

function BeardLibAchievementMenu:InitPanels(parent)
	self._header = parent:Grid({background_color = self._menu.accent_color, auto_foreground = true, h = 36})
	self._holder = parent:Holder({
		auto_foreground = true,
		auto_height = false,
		fit_width = false,
		w = parent:ItemsWidth(),
		h = parent:ItemsHeight(2) - 32,
		offset = default_margin,
		position = {0, self._header:Bottom() + 4}
	})
	local w = self._holder:ItemsWidth(2, default_margin)
	local h = self._holder:ItemsHeight(2, default_margin)

	self._account_progression = self._holder:Grid({
		background_color = Color.black:with_alpha(0.75),
		w = w * 1/3,
		h = h * 1/5,
		foreground = Color("808080"),
	})
	self._package_list = self._holder:GridMenu({
		background_color = Color.black:with_alpha(0.75),
		inherit_values = {offset = 3},
		auto_align = false,
		w = w * 1/3,
		h = h * 4/5
	})

	self._achievement_list_header = self._holder:Holder({
		background_color = Color.black:with_alpha(0.75),
		w = w * 2/3,
		h = h * 1/7,
		position = function(item)
			item:SetXY(self._account_progression:Right() + default_margin, default_margin)
		end
	})

	self._achievement_panel = self._holder:Grid({
		background_color = Color.black:with_alpha(0.75),
		w = w * 2/3,
		h = h * 6/7,
		position = function(item)
			item:SetXY(self._achievement_list_header:X(), self._achievement_list_header:Bottom() + default_margin)
		end
	})

	self._package_not_selected_label = self._achievement_panel:Divider({
		text = "beardlib_achieves_no_pkg",
		localized = true,
		text_vertical = "center",
		text_align = "center",
		position = function(item)
			item:Panel():set_world_center_y(self._achievement_panel:Panel():world_center_y())
		end
	})

	local ach_w = self._achievement_panel:ItemsWidth(2)
	self._achievement_list = self._achievement_panel:GridMenu({
		auto_align = false,
		w = ach_w * 3/5,
		offset = 6,
		h = self._achievement_panel:Panel():h(),
		visible = false
	})

	self._achievement_details = self._achievement_panel:Grid({
		w = ach_w * 2/5,
		offset = 6,
		h = self._achievement_panel:Panel():h(),
		visible = false
	})
end

function BeardLibAchievementMenu:InitHeader()
	self._header:Image({texture = "guis/textures/achievement_trophy_white", h = 30, w = 30, highlight_color = Color.transparent})

	self._header:Divider({
		text = managers.localization:text("beardlib_achieves_title"),
		size_by_text = true,
		size = 24,
		count_as_aligned = true,
		position = "Centery"
	})

	self._header:Button({
		text = managers.localization:text("beardlib_close"),
		text_align = "right",
		position = "RightOffset-x",
		size_by_text = true,
		size = 24,
		foreground = Color("fff"),
		on_callback = ClassClbk(self, "Close")
	})
end

function BeardLibAchievementMenu:InitAccount()
	local panel = self._account_progression
	local avatar = panel:Image({texture = "guis/texture/pd2/none_icon", img_color = Color.white, w = 64, h = 64})
	local stats = panel:Grid({
		name = "Stats",
		inherit_values = {offset = {0, 3}},
		w = panel:ItemsWidth() - avatar:OuterWidth() - panel:OffsetX()*2
	})

	local large = Distribution.ProfilePictureSize_Large

	Distribution:request_user_profile_picture(large, Distribution:local_user_id(), function (texture)
		avatar:SetImage(texture or "guis/textures/pd2/none_icon")
	end)

	-- TODO: Might be unecessary now
	BeardLib:AddDelayedCall("BeardLib_Recheck_Account_Avatar", 2, function()
		Distribution:request_user_profile_picture(large, Distribution:local_user_id(), function (texture)
			if alive(avatar) then
				avatar:SetImage(texture or "guis/textures/pd2/none_icon")
			end
		end)
	end)

	stats:Divider({
		name = "Name",
		text = managers.network.account:username(),
		size = 22
	})

	local percent_total = "--"
	local manager = BeardLib.Managers.Achievement

	if manager:NumberOfAchievements() > 0 then
		percent_total = math.floor(manager:CompletedAchievementsTotal() * 100 / manager:NumberOfAchievements())
	end

	stats:QuickText(managers.localization:text("beardlib_achieves_completed_achievements", {
		completed = manager:CompletedAchievementsTotal(), total = manager:NumberOfAchievements(), percent = percent_total
	}))

	stats:QuickText(managers.localization:text("beardlib_achieves_packages_installed", {
		nbpackages = manager:NumberOfPackages()
	}))

	local rank_texture = "guis/textures/achievement_trophy_white"
	for idx, nb in ipairs(manager:GetAllCompletedRanks()) do
		local rank_icon = stats:Image({
			name = "rank_icon_".. idx,
			texture = rank_texture,
			w = 24,
			h = 24,
			layer = 5,
			img_color = Color(manager._ranks[idx].color)
		})

		stats:Divider({
			text = "x".. tostring(nb),
			size_by_text = true,
			count_as_aligned = true,
			position = function(item)
				item:SetCenterY(rank_icon:CenterY())
			end,
			font = tweak_data.menu.pd2_large_font,
			size = 16
		})
	end
end

function BeardLibAchievementMenu:InitPackages()
	local panel = self._package_list
	local sorted_packages = {}

	for i, package_id in ipairs(BeardLib.Managers.Achievement:FetchPackages()) do
		local pck = CustomAchievementPackage:new(package_id)
		sorted_packages[i] = {id = package_id, name = pck:GetName()}
	end

	table.sort(sorted_packages, function(a, b)
		return a.name < b.name
	end)

	for _, package_data in pairs(sorted_packages) do
		local package_id = package_data.id
		local package = CustomAchievementPackage:new(package_id)

		local package_icon = panel:Image({
			texture = package:GetIcon(),
			w = 32,
			h = 32,
			highlight_color = Color.transparent
		})

		panel:Button({
			text = package:GetName(),
			h = 32,
			w = panel:Panel():w() - package_icon:Panel():w() - 100,
			foreground = Color("eeeeee"),
			on_callback = ClassClbk(self, "DisplayAchievementsFromPackage", package)
		})

		panel:Divider({
			text = package:GetCompletedAchievements() .. " / " .. package:GetTotalAchievements(),
			text_align = "center",
			foreground = Color("808080"),
			h = 32,
			w = 82
		})
	end

	panel:AlignItems(true)
end

function BeardLibAchievementMenu:DisplayAchievementsFromPackage(package)
	local panel = self._achievement_list
	panel:ClearItems()
	panel:SetVisible(true)
	self._achievement_details:SetVisible(false)

	local sorted_achievements = {}

	for achievement_id, achievement_data in pairs(package:FetchAchievements()) do
		local ach = CustomAchievement:new(package:GetConfigOf(achievement_id), package._package_id)
		table.insert(sorted_achievements, {id = ach._id, rank = ach:GetRankID()})
	end

	table.sort(sorted_achievements, function(a, b)
		return a.rank > b.rank
	end)

	for _, achievement_data in pairs(sorted_achievements) do
		local achievement_id = achievement_data.id
		local achievement = CustomAchievement:new(package:GetConfigOf(achievement_id), package._package_id)

		if achievement:IsDefaultIcon() then
			panel:Image({
				texture = achievement:GetIcon(),
				h = 48,
				w = 48,
				layer = 1,
				foreground = Color(achievement:GetRankColor()):with_alpha(0.7),
				highlight_color = Color.transparent
			})
		else
			panel:Image({
				texture = achievement:GetIcon(),
				h = 48,
				w = 48,
				layer = -1,
				highlight_color = Color.transparent
			})
		end

		local achievement_button = panel:Button({
			h = 48,
			w = panel:Panel():w() - 48 - (default_margin * 3),
			text_offset = 0,
			text = false,
			on_callback = ClassClbk(self, "DisplayAchievementDetails", achievement)
		})

		achievement_button:QuickText(achievement:GetName(), {foreground = achievement:IsUnlocked() and Color.green or Color.white})
		achievement_button:Image({
			img_color = Color(achievement:GetRankColor()),
			texture = "guis/textures/achievement_trophy_white",
			offset = 2,
			position = "RightTopOffset-xy",
			h = 24,
			w = 24,
		})

		if achievement:IsUnlocked() then
			achievement_button:Divider({
				text = managers.localization:to_upper_text("beardlib_achieves_unlocked", {time = os.date('%d/%m/%Y @ %H:%M:%S', achievement:GetUnlockTimestamp())}),
				size = 14,
				size_by_text = true,
				offset_y = 1,
				foreground = Color.white:with_alpha(0.5)
			})
		elseif not achievement:IsUnlocked() and achievement:HasAmountValue() then
			local progress = achievement:CurrentAmountValue() / achievement:AmountValue()

			TextProgressBar:new(achievement_button:Panel(), {
				h = 16,
				w = achievement_button:Panel():w(),
				y = achievement_button:Panel():h() - 16,
				back_color = Color(255, 60, 60, 65) / 255,
			}, {font = tweak_data.menu.pd2_medium_font, font_size = 16}, progress)
		end
	end

	panel:AlignItems(true)

	self:DisplayPackageHeader(package)
end

function BeardLibAchievementMenu:DisplayPackageHeader(package)
	local panel = self._achievement_list_header
	local name = package:GetName()
	local desc = package:GetDesc()
	local icon = package:GetIcon()
	local banner = package:GetBanner()
	local total_achievements = package:GetTotalAchievements()
	local completed_achievements = package:GetCompletedAchievements()
	local percent_display = total_achievements > 0 and math.floor(completed_achievements * 100 / total_achievements) or '--'

	panel:ClearItems()
	self._package_not_selected_label:SetVisible(false)

	local banner_panel = panel:Grid({
		name = "banner_panel",
		w = panel:Panel():w(),
		h = panel:Panel():h(),
		offset = 0
	})

	if banner then
		banner_panel:Panel():bitmap({
			texture = banner,
			w = banner_panel:Panel():w(),
			h = banner_panel:Panel():h(),
			layer = 2
		})
	end

	banner_panel:Image({
		name = "package_icon",
		texture = icon,
		h = 86,
		w = 86,
		offset = 4
	})

	local package_name = banner_panel:FitDivider({
		name = "package_name",
		text = utf8.to_upper(name),
		size = 28
	})

	local current_progress = banner_panel:FitDivider({
		name = "current_progress",
		text = managers.localization:to_upper_text("beardlib_achieves_completed_achievements", {completed = completed_achievements, total = total_achievements, percent = percent_display}),
		position = function(item)
			item:SetXY(package_name:X(), 30)
		end,
		size = 18,
		foreground = Color(0.3, 0.3, 0.3),
	})

	local package_desc = banner_panel:FitDivider({
		name = "package_desc",
		text = "\"" .. desc .. "\"",
		position = function(item)
			if alive(current_progress) then
				item:SetXY(current_progress:LeftBottom())
				item:Move(0, 14)
			end
		end,
		size = 16,
		visible = desc ~= ""
	})
end

function BeardLibAchievementMenu:DisplayAchievementDetails(achievement)
	local panel = self._achievement_details
	panel:SetVisible(true)
	panel:ClearItems()

	local achiev_details = {
		name = achievement:GetName(),
		icon = achievement:GetIcon(),
		desc = achievement:GetDesc(),
		obj = achievement:GetObjective(),
		rank_name = achievement:GetRankName(),
		rank_color = achievement:GetRankColor(),
		is_unlocked = achievement:IsUnlocked()
	}

	panel:Divider({
		text = achiev_details.name,
		background_color = Color(achiev_details.rank_color):with_alpha(0.5),
		size = 24,
		text_align = "center"
	})

	panel:Image({
		texture = achiev_details.icon,
		w = 64,
		h = 64,
		foreground = achievement:IsDefaultIcon() and not achievement:IsHidden() and Color(achiev_details.rank_color) or nil,
		highlight_color = Color.transparent
	})

	panel:Button({
		text = achiev_details.desc,
		size = 14,
		w = 207,
		highlight_color = Color.transparent
	})

	local achiev_objective_header = panel:Divider({
		text = managers.localization:to_upper_text("beardlib_achieves_header_objectives"),
		text_align = "center",
		background_color = Color(achiev_details.rank_color):with_alpha(0.5)
	})

	panel:Divider({
		text = achiev_details.obj
	})

	if not achievement:IsUnlocked() and achievement:HasAmountValue() then
		panel:Divider({
			text = utf8.to_upper("Progress"),
			text_align = "center",
			background_color = Color(achiev_details.rank_color):with_alpha(0.5)
		})

		local progress = achievement:CurrentAmountValue() * 100 / achievement:AmountValue()

		panel:Divider({
			text = tostring(achievement:CurrentAmountValue()) .. " / " .. tostring(achievement:AmountValue()) .. " ( " .. math.floor(progress) .. " %)"
		})
	end

	if achievement:HasReward() then
		panel:Divider({
			text = managers.localization:to_upper_text("beardlib_achieves_header_rewards"),
			text_align = "center",
			background_color = Color(achiev_details.rank_color):with_alpha(0.5)
		})

		local achiev_reward_panel = panel:Grid({h = 68, w = panel:Panel():w() - 10})
		local rewards = thousand_sep(achievement:SanitizeMaxRewards(achievement:GetRewardAmount()))
		local reward_loc
		local reward_icon

		if achievement:GetRewardType() == "xp" then
			reward_icon = xp_icon
			reward_loc = "beardlib_achieves_reward_exp"
		elseif achievement:GetRewardType() == "cash" then
			reward_icon = cash_icon
			reward_loc = "beardlib_achieves_reward_cash"
		elseif achievement:GetRewardType() == "offshore" then
			reward_icon = cash_icon
			reward_loc = "beardlib_achieves_reward_offshore"
		elseif achievement:GetRewardType() == "cc" then
			reward_icon = cc_icon
			reward_loc = "beardlib_achieves_reward_cc"
		end

		achiev_reward_panel:Image({texture = reward_icon, h = 32, w = 32})
		achiev_reward_panel:FitDivider({text = managers.localization:to_upper_text(reward_loc) .. " + ".. rewards, offset = {6, 14}})
	end

	if achiev_details.is_unlocked then
		panel:Divider({
			text = managers.localization:to_upper_text("beardlib_achieves_header_unlocked"),
			text_align = "center",
			background_color = Color.green
		})

		panel:Divider({
			text = managers.localization:text("beardlib_achieves_header_unlocked_date", {time = os.date('%d/%m/%Y @ %H:%M:%S', achievement:GetUnlockTimestamp())}),
			foreground = Color("aaaaaa"), -- AAAAAAAA
			text_align = "center",
		})
	end
end

function BeardLibAchievementMenu:Close()
	self._menu:SetEnabled(false)
end

function BeardLibAchievementMenu:SetEnabled(state)
	self._menu:SetEnabled(state)

	if not self._initialized then
		self:InitPanels(self._menu)
		self:InitHeader()
		self:InitAccount()
		self:InitPackages()

		self._initialized = true
	end
end
