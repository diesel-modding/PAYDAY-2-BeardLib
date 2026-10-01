if CoreLoadingSetup then
    LevelModule = LevelModule or BeardLib:ModuleClass("level", ItemModuleBase)
    LevelModule.levels_folder = "levels/mods/"

    BeardLib:RegisterModule("Level", LevelModule)

    function LevelModule:init(...)
        if not LevelModule.super.init(self, ...) then  return false end

        if arg and arg.load_level_data and arg.load_level_data.level_data and arg.load_level_data.level_data.level_id == self._config.id then
            self:Load()
        end
    end

    function LevelModule:Load()
        if self._config.hooks then
            HooksModule:new(self._mod, self._config.hooks)
        end
    end

    return
end

LevelModule = LevelModule or BeardLib:ModuleClass("level", ItemModuleBase)
LevelModule.levels_folder = "levels/mods/"

BeardLib:RegisterModule("Level", LevelModule)

local TEXTURE = Idstring("texture")

function LevelModule:init(...)
    self.clean_table = table.add(clone(self.clean_table), {
        {param = "preplanning", action = function(tbl)
            table.remove_condition(tbl, function(v)
                return v._meta == "default_plans" or v._meta == "start_location"
            end)
        end},
        {param = "teams", action = "no_number_indexes"},
        {param = "teams", action = "remove_metas"},
    })

    if not LevelModule.super.init(self, ...) then
        return false
    end

    if Version:new(self._mod:MinLibVer()) >= Version:new("4.5") then
        self.levels_folder = Path:CombineDir(self.levels_folder, self._mod.Name)
    end

    self._config.id = tostring(self._config.id)
    self._addfiles_modules = {}

    self._inner_dir = Path:Combine(self.levels_folder, self._config.id)
    self._levels_less_path = self._inner_dir:gsub("levels/", "")
    self._level_dir = "levels/"..self._config.id

    if not self._config.load_screen or self._config.load_screen == "" then
        local icon = Path:Combine(self._mod.ModPath, self._level_dir, "loading")
        local icon_png = icon..".png"
        local icon_texture = icon..".texture"
        local found_icon
        if FileIO:Exists(icon_png) then
            found_icon = icon_png
        elseif FileIO:Exists(icon_texture) then
            found_icon = icon_texture
        end
        if found_icon then
            local ingame_path = Path:Combine("guis/textures/mods/icons/level_", self._config.id)
            BeardLib.Managers.File:AddFile(TEXTURE, Idstring(ingame_path), found_icon)
            self._config.load_screen = ingame_path
        end
    end

    if Global.level_data and Global.level_data.level_id == self._config.id then
        BeardLib.current_level = self
        self._currently_loaded = true
        self:Load()
    end
    return true
end

function LevelModule:Load()
    if self._config.include then
        for i, include_data in ipairs(self._config.include) do
            if include_data.file then
                local file_split = string.split(include_data.file, "[.]")
                local complete_path = Path:Combine(self._mod.ModPath, self._config.include.directory, include_data.file)
                local new_path = Path:Combine(self._inner_dir, file_split[1])
                if FileIO:Exists(complete_path) then
                    if include_data.type then
                        BeardLib.Managers.File:ScriptReplaceFile(file_split[2], new_path, complete_path, {type = include_data.type, add = true})
					else
						local ext_id = file_split[2]:id()
						local path_id = new_path:id()
						BeardLib.Managers.File:AddFile(ext_id, path_id, complete_path)
						if include_data.reload then
							PackageManager:reload(ext_id, path_id)
						end
                    end
                else
                    self:log("[ERROR] Included file '%s' is not readable by the lua state!", complete_path)
                end
            end
        end
    end

    if self._config.sounds then --Sounds unload automatically.
        SoundsModule:new(self._mod, self._config.sounds)
    end

    self._addfiles_modules = {}

    self._add_path = self._level_dir.."/add.xml"
    if self._config.add or FileIO:Exists(Path:CombineDir(self._mod.ModPath, self._add_path)) then
        local module = AddFilesModule:new(self._mod, self._config.add or {file = self._add_path, directory = "assets"})
        self._loaded_addfiles = module
        table.insert(self._addfiles_modules, module)
    end

    self._local_add_path = self._level_dir.."/add_local.xml"
    if FileIO:Exists(Path:CombineDir(self._mod.ModPath, self._local_add_path)) then
        local module = AddFilesModule:new(self._mod, {file = self._local_add_path, directory = self._level_dir, inner_directory = self._inner_dir})
        table.insert(self._addfiles_modules, module)
    end

    if self._config.script_data_mods then
        local script_mods = ScriptReplacementsModule:new(self._mod, self._config.script_data_mods)
        script_mods:PostInit()
	end

    if self._config.hooks then
        HooksModule:new(self._mod, self._config.hooks)
    end

    if self._config.classes then
        ClassesModule:new(self._mod, self._config.classes)
    end

    if self._config.xml then
        for _, xml in ipairs(self._config.xml) do
            if xml.path then
                XMLModule:new(self._mod, xml)
            end
        end
    end
end

function LevelModule:AddLevelDataToTweak(l_self)
    local id = tostring(self._config.id)

    l_self[id] = table.merge(clone(self._config), {
        name_id = self._config.name_id or ("heist_" .. id .. "_name"),
        briefing_id = self._config.brief_id or ("heist_" .. id .. "_brief"),
        world_name = self._levels_less_path,
        ai_group_type = l_self.ai_groups[self._config.ai_group_type] or l_self.ai_groups.default,
        intro_event = self._config.intro_event or "nothing",
        outro_event = self._config.outro_event or "nothing",
        music = self._config.music or "heist",
        custom_packages = self._config.packages or self._config.custom_packages,
        mod_path = self._mod.ModPath,
        custom = true
    })
    if self._config.merge_data then
        table.merge(l_self[id], BeardLib.Utils:RemoveMetas(self._config.merge_data, true))
	end
	if not table.contains(l_self._level_index, id) then
		table.insert(l_self._level_index, id)
	end
end

function LevelModule:AddAssetsDataToTweak(a_self)
    for _, value in ipairs(self._config.assets) do
		if value._meta == "asset" then
			local exclude = value.exclude
			local asset = a_self[value.name]
			if asset ~= nil then
				if (exclude and asset.exclude_stages ~= "all") or (not exclude and asset.stages ~= "all") then
					asset.exclude_stages = asset.exclude_stages or {}
					asset.stages = asset.stages or {}
					table.insert(exclude and asset.exclude_stages or asset.stages, self._config.id)
				end
            else
                self:Err("Asset %s does not exist! (Map: %s)", value.name, name)
            end
        else
            if not a_self[value._meta] then
                a_self[value._meta] = value
            else
                self:Err("Asset with name: %s already exists! (Map: %s)", value._meta, name)
            end
        end
    end
end

function LevelModule:AddPrePlanningDataToTweak(pp_self)
    pp_self.locations[self._config.id] = self._config.preplanning
end

function LevelModule:RegisterHook()
    if tweak_data and tweak_data.levels then
        self:AddLevelDataToTweak(tweak_data.levels)
    else
        Hooks:PostHook(LevelsTweakData, "init", self._config.id .. "AddLevelData", ClassClbk(self, "AddLevelDataToTweak"))
    end

    if self._currently_loaded then
        if self._config.interactions then
            local interactions = InteractionsModule:new(self._mod, self._config.interactions)
            interactions:RegisterHook()
        end

        if self._config.equipments then
            local equipments = EquipmentsModule:new(self._mod, self._config.equipments)
            equipments:RegisterHook()
        end

        if self._config.lootbags then
            local lootbags = LootBagsModule:new(self._mod, self._config.lootbags)
            lootbags:RegisterHook()
        end
		
		if self._config.hudicon then
            local hudicon = HUDIconModule:new(self._mod, self._config.hudicon)
            hudicon:RegisterHook()
        end

        if self._config.assets then
            if tweak_data and tweak_data.assets then
                self:AddAssetsDataToTweak(tweak_data.assets)
            else
                Hooks:PostHook(AssetsTweakData, "init", self._config.id .. "AddAssetsData", ClassClbk(self, "AddAssetsDataToTweak"))
            end
        end

        if self._config.preplanning then
            if tweak_data and tweak_data.preplanning then
                self:AddPrePlanningDataToTweak(tweak_data.preplanning)
            else
                Hooks:PostHook(PrePlanningTweakData, "init", self._config.id .. "AddPrePlanningData", ClassClbk(self, "AddPrePlanningDataToTweak"))
            end
        end
    end
end

InstanceModule = InstanceModule or BeardLib:ModuleClass("instance", LevelModule)
InstanceModule.levels_folder = "levels/instances/mods/"
InstanceModule._loaded_packages = {}

BeardLib:RegisterModule("Instance", InstanceModule)

function InstanceModule:init(...)
    if not LevelModule.super.init(self, ...) then
        return false
    end

    if Version:new(self._mod:MinLibVer()) >= Version:new("4.5") then
        self.levels_folder = Path:CombineDir(self.levels_folder, self._mod.Name)
    end

    self._inner_dir = Path:Combine(self.levels_folder, self._config.id)
    self._levels_less_path = self._inner_dir:gsub("levels/", "")
    self._level_dir = "levels/instances/"..self._config.id
    self._world_path = Path:Combine(self.levels_folder, self._config.id, "world")
    BeardLib.Frameworks.Base._loaded_instances[self._world_path] = self --long ass line

    return true
end

function InstanceModule:PostInit()
    --USED ONLY IN EDITOR!
    if Global.editor_loaded_instance then
        if Global.level_data and Global.level_data.level_id == self._levels_less_path then
            BeardLib.current_level = self
            self:Load()
        end
    end
end

function InstanceModule:LoadPackage(package)
    if PackageManager:package_exists(package) then
        if not PackageManager:loaded(package) then
            PackageManager:load(package)
            table.insert(self._loaded_packages, package)
        end
    else
        self:Warn("Attempted to load package %s, but it doesn't exist!", tostring(package))
    end
end

function InstanceModule:RegisterHook()
    if self._config.interactions then
        local interactions = InteractionsModule:new(self._mod, self._config.interactions)
        interactions:RegisterHook()
    end

    if self._config.equipments then
        local equipments = EquipmentsModule:new(self._mod, self._config.equipments)
        equipments:RegisterHook()
    end

    if self._config.lootbags then
        local lootbags = LootBagsModule:new(self._mod, self._config.lootbags)
        lootbags:RegisterHook()
    end
    
end

function InstanceModule:Load()
    if self._config.packages or self._config.custom_packages then
        for _, package in ipairs(self._config.packages or self._config.custom_packages) do
            self:LoadPackage(package)
        end
    end
    InstanceModule.super.Load(self)
end

function InstanceModule:Unload()
    for _, package in pairs(self._loaded_packages) do
        if PackageManager:loaded(package) then
            PackageManager:unload(package)
        end
    end
    self._loaded_packages = nil
    for _, module in pairs(self._addfiles_modules) do
        module:Unload()
    end
    self._addfiles_modules = {}
end