BeardLibAchievementManager = BeardLibAchievementManager or BeardLib:ManagerClass("Achievement")

function BeardLibAchievementManager:init()
    -- Support multiple user on same PC, tracking each progress
    local user_id = Distribution:local_user_id() or "unknown"
    self._achievements_folder = SavePath .. "CustomAchievements/" ..tostring(user_id).."/"
    self._achievement_icons_spoofer = {}
    self._ranks = {
        [1] = {name = "Bronze", color = "CD7F32"},
        [2] = {name = "Silver", color = "C0C0C0"},
        [3] = {name = "Gold", color = "FFD700"},
        [4] = {name = "Platinum", color = "42d9f4"},
        [0] = {name = "Hidden Rank", color = "000000"} -- Don't define the rank 0 yourself, that's used by me.
    }

    -- Deprecated, try not to use.
    BeardLib.managers.custom_achievement = self
    CustomAchievementManager = self

    Hooks:Add("SetupInitManagers", "PostInitTweakData_BeardLibAchievementManager", ClassClbk(self, "SetupAchievements"))
end

function BeardLibAchievementManager:GetRankDetails(rank_id)
    return self._ranks[rank_id]
end

function BeardLibAchievementManager:AddToIconSpoofer(params)
    table.insert(self._achievement_icons_spoofer, params)
end

function BeardLibAchievementManager:HasPackage(package_id)
    if self._tweak_data[package_id] then
        return true
    end

    return false
end

function BeardLibAchievementManager:HasAnyPackage()
    if self:NumberOfPackages() > 0 then
        return true
    end

    return false
end

-- Use CustomAchievementPackage when possible.
function BeardLibAchievementManager:HasAchievement(package_id, achievement_id)
    if self._tweak_data[package_id][achievement_id] then
        return true
    end

    return false
end

function BeardLibAchievementManager:SetupAchievements()
    self._tweak_data = tweak_data.achievement.custom_achievements or {}

    -- I --     Make the base directory.
    FileIO:MakeDir(self._achievements_folder)

    -- II --    Read Packages, create folders.
    for package_id, _ in pairs(self._tweak_data) do
        local package_path = self._achievements_folder .. "/" .. tostring(package_id)

        FileIO:MakeDir(package_path)

        -- III --   Create achievement file by packages.
        local package = CustomAchievementPackage:new(package_id)

        for achievement_id, achievement_data in pairs(package:FetchAchievements()) do
            if achievement_id ~= "icon" then    -- Prevent adding package icon param to achievements.
                local achievement_path = package_path .. "/" .. achievement_id .. ".json"
                if not FileIO:Exists(achievement_path) then

                    local achievement_progress_config = {
                        completed = false,
                        amount = 0,
                        date_unlocked = 0
                    }

                    local content = json.custom_encode(achievement_progress_config)
                    FileIO:WriteTo(achievement_path, content, "w+")
                end
            end
        end
    end
end

function BeardLibAchievementManager:FetchPackages()
    if not self:HasAnyPackage() then
        return {}
    end

    local packages = {}

    for id, _ in pairs(tweak_data.achievement.custom_achievements_packages) do
        table.insert(packages, id)
    end

    return packages
end

function BeardLibAchievementManager:NumberOfPackages()
    local nb = 0
    local tweak = tweak_data.achievement.custom_achievements or {}

    for _, package in pairs(tweak) do
        nb = nb + 1
    end

    return nb
end

function BeardLibAchievementManager:NumberOfAchievements()
    local nb = 0
    local tweak = tweak_data.achievement.custom_achievements or {}

    for package, _ in pairs(tweak) do
        for _, achievement in pairs(tweak[package]) do
            if type(achievement) == "table" then
                nb = nb + 1
            end
        end
    end

    return nb
end

function BeardLibAchievementManager:CompletedAchievementsTotal()
    local nb = 0

    if not self._tweak_data then -- i hate this game
        self._tweak_data = tweak_data and tweak_data.achievement and tweak_data.achievement.custom_achievements or {}
    end

    for package_id, _ in pairs(self._tweak_data or {}) do
        local package = CustomAchievementPackage:new(package_id)

        for achievement_id, _ in pairs(package:FetchAchievements()) do
            local config = package:GetConfigOf(achievement_id)
            --log("config is " .. tostring(config))
            if type(config) == "table" then
                local achievement = CustomAchievement:new(config, package_id)
                --log(tostring(achievement:GetName()) .. " unlock state: " .. tostring(achievement:IsUnlocked()))
                if achievement:IsUnlocked() then
                    nb = nb + 1
                end
            end
        end
    end

    return nb
end

function BeardLibAchievementManager:GetAllCompletedRanks()
    local t = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0
    }

    local tweak = tweak_data.achievement.custom_achievements or {}

    for package_id, _ in pairs(tweak) do
        local package = CustomAchievementPackage:new(package_id)

        for achievement_id, _ in pairs(package:FetchAchievements()) do
            local config = package:GetConfigOf(achievement_id)

            if type(config) == "table" then
                local achievement = CustomAchievement:new(config, package_id)

                if achievement:IsUnlocked() then
                    t[achievement:GetRankID()] = t[achievement:GetRankID()] + 1
                end
            end
        end
    end

    return t
end

CustomAchievementPackage = CustomAchievementPackage or class()

function CustomAchievementPackage:init(package_id)
    tweak_data.achievement.custom_achievements_packages = tweak_data.achievement.custom_achievements_packages or {}
    local tweak = tweak_data.achievement.custom_achievements_packages[package_id]
    if not tweak then
      BeardLib:Err("[CustomAchievementPackage] Achievement package '%s' does not exist", package_id)
    end

    self._package_id = package_id
    self._achievements = tweak_data.achievement.custom_achievements[package_id] or {}
    self._name_id = tweak and tweak.name or package_id .. "_name"
    self._desc_id = tweak and tweak.desc
    self._icon = tweak and tweak.icon or "guis/textures/achievement_package_default"
    self._banner = tweak and tweak.banner
end

function CustomAchievementPackage:GetName()
    return managers.localization:text(self._name_id)
end

function CustomAchievementPackage:GetDesc()
    if not self._desc_id then
        return ""
    end

    return managers.localization:text(self._desc_id)
end

function CustomAchievementPackage:GetIcon()
    return self._icon
end

function CustomAchievementPackage:GetBanner()
    return self._banner
end

function CustomAchievementPackage:FetchAchievements()
    return self._achievements
end

function CustomAchievementPackage:ManualAchievementAddition(achievement_id, config)
    if tweak_data and tweak_data.achievement then
        tweak_data.achievement.custom_achievements[self._package_id][achievement_id] = config
        BeardLib.Managers.Achievement:SetupAchievements()
    end
end

function CustomAchievementPackage:GetConfigOf(achievement_id)
    return self._achievements[achievement_id]
end

function CustomAchievementPackage:HasAchievement(achievement_id)
    if self._achievements[achievement_id] then
        return true
    end

    return false
end

function CustomAchievementPackage:Achievement(achievement_id)
    if not self:HasAchievement(achievement_id) then
        return BeardLib:Err("[CustomAchievementPackage] '%s' does not exist for the achievement package '%s'", achievement_id, self._package_id)
    end

    return CustomAchievement:new(self:GetConfigOf(achievement_id), self._package_id)
end

function CustomAchievementPackage:GenerateAchievementTable()
    local achievement_table = {}
    achievement_table[self._package_id] = {}
    local fetched_achievements = self:FetchAchievements()
    achievement_table[self._package_id] = fetched_achievements
    return achievement_table[self._package_id]
end

function CustomAchievementPackage:GetCompletedAchievements()
    local nb = 0

    for achievement_id, _ in pairs(self:FetchAchievements()) do
        local config = self:GetConfigOf(achievement_id)

        if type(config) == "table" then
            local achievement = CustomAchievement:new(config, self._package_id)

            if achievement:IsUnlocked() then
                nb = nb + 1
            end
        end
    end

    return nb
end

-- Useful for "complete all achievements" achievement.
function CustomAchievementPackage:AllAchievementsCompletedExceptOne()
    local nb = self:GetTotalAchievements() - 1

    if self:GetCompletedAchievements() == nb then
        return true
    end

    return false
end

function CustomAchievementPackage:GetTotalAchievements()
    local nb = 0

    for achievement_id, _ in pairs(self:FetchAchievements()) do
        local config = self:GetConfigOf(achievement_id)

        if type(config) == "table" then
            nb = nb + 1
        end
    end

    return nb
end

CustomAchievement = CustomAchievement or class()

CustomAchievement._MAX_EXP_AMOUNT = 10000000
CustomAchievement._MAX_MONEY_AMOUNT = 50000000
CustomAchievement._MAX_OFFSHORE_AMOUNT = 100000000
CustomAchievement._MAX_CC_AMOUNT = 1000

CustomAchievement.limits = {
    xp = CustomAchievement._MAX_EXP_AMOUNT,
    cc = CustomAchievement._MAX_CC_AMOUNT,
    cash = CustomAchievement._MAX_MONEY_AMOUNT,
    offshore = CustomAchievement._MAX_OFFSHORE_AMOUNT
}

CustomAchievement.valid_rewards = {
    "xp",
    "cc",
    "cash",
    "offshore"
}

function CustomAchievement:init(config, package)
    if type(config) ~= "table" then
        return
    end

    local folder = BeardLib.Managers.Achievement._achievements_folder
    self._progress_file = folder .. "/" .. tostring(package) .. "/" .. tostring(config.id) .. ".json"

    self._package_id = package
    self._id = config.id
    self._name_id = config.name_id or "no_name_id"
    self._desc_id = config.desc_id or "no_desc_id"
    self._obj_id = config.obj_id or "no_obj_id"
    self._rank = config.rank or 1
    self._icon_path = config.icon
    self._amount = config.amount
    self._hidden_details = config.hidden_achievement or false
    self._reward_type = config.reward_type
    self._reward_amount = config.reward_amount

    self._saved_amount = 0          --  In Progression File
    self._unlocked = false          --  In Progression File
    self._timestamp_unlocked = 0    --  In Progression File

    self:LoadProgress()
end

function CustomAchievement:GetName()
    if self:IsHidden() and not self:IsUnlocked() then
        return managers.localization:text("beardlib_achieves_hidden")
    end

    return managers.localization:text(self._name_id)
end

function CustomAchievement:GetDesc()
    if self:IsHidden() and not self:IsUnlocked() then
        return managers.localization:text("beardlib_achieves_hidden_desc")
    end

    return managers.localization:text(self._desc_id)
end

function CustomAchievement:GetObjective()
    if self:IsHidden() and not self:IsUnlocked() then
        return "???"
    end

    return managers.localization:text(self._obj_id)
end

function CustomAchievement:GetIcon()
    if self:IsHidden() and not self:IsUnlocked() then
        return "guis/textures/achievement_trophy_white"
    end

    return self._icon_path
end

function CustomAchievement:GetUnlockTimestamp()
    return self._timestamp_unlocked
end

function CustomAchievement:GetRankName()
    local rank_id = self:IsHidden() and 0 or self._rank

    local rank = BeardLib.Managers.Achievement:GetRankDetails(rank_id)
    return rank.name
end

function CustomAchievement:GetRankColor()
    local rank_id = self:IsHidden() and 0 or self._rank

    local rank = BeardLib.Managers.Achievement:GetRankDetails(rank_id)
    return rank.color
end

function CustomAchievement:IsDefaultIcon()
    if self:IsHidden() or self._icon_path == "guis/textures/achievement_trophy_white" then
        return true
    end

    return false
end

function CustomAchievement:Package()
    if not self._package_id then
        return BeardLib:Err("[CustomAchievementPackage] Achievement '%s' lacking package id. Did you invoked the CustomAchievement class with the package ID?", self._id)
    end

    return CustomAchievementPackage:new(self._package_id)
end

function CustomAchievement:LoadProgress()
    local progress_data = json.custom_decode(FileIO:ReadFrom(self._progress_file))

    self._saved_amount = progress_data.amount
    self._unlocked = progress_data.completed
    self._timestamp_unlocked = progress_data.date_unlocked
end

function CustomAchievement:SaveProgress()
    local data = {
        amount = self._saved_amount,
        completed = self._unlocked,
        date_unlocked = self._timestamp_unlocked
    }

    FileIO:WriteTo(self._progress_file, json.custom_encode(data), "w+")
end

function CustomAchievement:IncreaseAmount(amt, to_max)
    if self:IsUnlocked() then
        return
    end

    if to_max then
        self._saved_amount = self._amount
        self:SaveProgress()
        self:CheckCompletion()
        return
    end

    self._saved_amount = self._saved_amount + amt

    if (self._saved_amount > self._amount) then
        self._saved_amount = self._amount
    end

    self:SaveProgress()
    self:CheckCompletion()
end

function CustomAchievement:CheckCompletion()
    if self:IsUnlocked() then
        return
    end

    if self._saved_amount >= self._amount then
        self:Unlock()
    end
end

function CustomAchievement:Unlock()
    if self:IsUnlocked() then
        return
    end

    self._unlocked = true
    self._timestamp_unlocked = os.time()

    if HudChallengeNotification then
        HudChallengeNotification.queue(
            managers.localization:to_upper_text("hud_achieved_popup"),
            managers.localization:to_upper_text(self._name_id),
            self._icon_path or "placeholder_circle"
        )
    end

    self:GiveReward()
    self:IncreaseAmount(nil, true)
    self:SaveProgress()
end

function CustomAchievement:Lock()
    self._unlocked = false
    self._timestamp_unlocked = 0
    self:SaveProgress()
end

function CustomAchievement:GetRewardType()
    return tostring(self._reward_type)
end

function CustomAchievement:GetRewardAmount()
    return self._reward_amount
end

function CustomAchievement:GiveReward()
    if not self._reward_type then
        return
    end

    local continue = false

    -- Sanity checks
    for _, v in pairs(CustomAchievement.valid_rewards) do
        if self._reward_type == v then
            continue = true
        end
    end

    if continue then
        if self._reward_amount > CustomAchievement.limits[self._reward_type] then
            self._reward_amount = CustomAchievement.limits[self._reward_type]
        end

        if self._reward_amount < 0 then
            self._reward_amount = 0
        end

        if self._reward_type == "xp" then
            managers.experience:debug_add_points(self._reward_amount, false)

        elseif self._reward_type == "cc" then
            local current_cc = Application:digest_value(managers.custom_safehouse._global.total)
            local new_cc = current_cc + self._reward_amount

            Global.custom_safehouse_manager.total = Application:digest_value(new_cc, true)

        elseif self._reward_type == "cash" then
            managers.money:_add_to_total(self._reward_amount, {no_offshore = true})

        elseif self._reward_type == "offshore" then
            managers.money:add_to_offshore(self._reward_amount)

        end
    end
end

function CustomAchievement:IsUnlocked()
    return self._unlocked
end

function CustomAchievement:SanitizeMaxRewards(amount)
    if amount > CustomAchievement.limits[self._reward_type] then
        amount = CustomAchievement.limits[self._reward_type]
    end

    if amount < 0 then
        amount = 0
    end

    return amount
end

function CustomAchievement:HasAmountValue()
    if self._amount > 0 then
        return true
    end

    return false
end

function CustomAchievement:AmountValue()
    return self._amount
end

function CustomAchievement:CurrentAmountValue()
    return self._saved_amount
end

function CustomAchievement:IsHidden()
    if self:IsUnlocked() then
        return false
    end

    return self._hidden_details
end

function CustomAchievement:HasReward()
    return self._reward_type and true or false
end

function CustomAchievement:GetRankID()
    if self:IsHidden() and not self:IsUnlocked() then
        return 0
    end

    return self._rank
end
