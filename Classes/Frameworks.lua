Hooks:Register("BeardLibFrameworksInit")
Hooks:Register("BeardLibFrameworksLoad")
Hooks:Register("BeardLibFrameworksFindMods")
Hooks:Register("BeardLibFrameworksSortMods")
Hooks:Register("BeardLibFrameworksInitMods")
Hooks:Register("BeardLibFrameworksInitMod")
Hooks:Register("BeardLibFrameworksFoldersLoop")

FrameworkBase = FrameworkBase or BeardLib:Class()

FrameworkBase._directory = BLTModManager.Constants.mods_directory or "mods/"
FrameworkBase._format = Path:Combine(FrameworkBase._directory, "%s", "main.xml")
FrameworkBase._mod_core = ModCore
FrameworkBase._ignore_folders = {["base"] = true, ["BeardLib"] = true, ["PAYDAY-2-BeardLib-master"] = true, ["downloads"] = true, ["logs"] = true, ["saves"] = true}
FrameworkBase._ignore_detection_errors = true

FrameworkBase.main_file_name = "main.xml"
FrameworkBase.add_file = "add.xml"
FrameworkBase.loading_scene_file_name = "enable_in_loading_scene"
FrameworkBase.auto_init_modules = true
FrameworkBase.type_name = "Base"
FrameworkBase.menu_color = Color(0.6, 0, 1)
FrameworkBase.add_configs = {}
FrameworkBase._loaded_instances = {}

function FrameworkBase:init()
	Hooks:Call("BeardLibFrameworksInit", self)
	BeardLib:RegisterFramework(self.type_name, self)

	self._ignored_configs = {}
	self._loaded_mods = {}
	self._sorted_mods = {}
	self._waiting_to_load = {}
	self._overridden_files = {}
	self._log_init = BeardLib.Options:GetValue("LogInit")

	-- Deprecated, try not to use.
	if AddFramework and self.type_name == AddFramework.type_name then
		BeardLib.Frameworks.base = self
		BeardLib.managers.BaseFramework = self
	end

	Hooks:Add("BeardLibRequireHook", self.type_name.."_framework_require", function(post, file)
		self:CheckModQueue(post, file)
	end)

	self:Load()
end

function FrameworkBase:CheckModQueue(post, file)
	if #self._waiting_to_load == 0 or post == nil or file == nil then
		return
	end
	local shortened = file
	for part, _ in string.gmatch(file, "%w+") do
		shortened = part
	end
	shortened = shortened:lower()

	local next_queue = {}
	local load = {}
	local pre = not post
	for _, mod in pairs(self._waiting_to_load) do
		local config = mod._config
		if (post and config.post_hook == shortened) or (pre and config.pre_hook == shortened) then
			table.insert(load, mod)
		else
			table.insert(next_queue, mod)
		end
	end

	for _, mod in pairs(load) do
		mod:PreInitModules(self.auto_init_modules)
	end

	self._waiting_to_load = next_queue
end

function FrameworkBase:Load()
	Hooks:Call("BeardLibFrameworksLoad", self)
	if DB then
		self:FindAlreadyOverriden()
	end
	self:FindMods()
	self:SortMods()
end

--- Search for files that were overriden by mod_overrides and ignore them in other folders
function FrameworkBase:FindAlreadyOverriden()
	for _, mod in pairs(DB:mods()) do
		if mod.enabled then
			for _, file in pairs(mod.files) do
				self._overridden_files[file] = true
			end
		end
	end
end

function FrameworkBase:FindMods()
	Hooks:Call("BeardLibFrameworksFindMods", self)

	local is_raid = BeardLib:GetGame() == "raid"

	local dirs = FileIO:GetFolders(self._directory)
    if dirs then
		for _, folder_name in pairs(dirs) do
			Hooks:Call("BeardLibFrameworksFoldersLoop", self, folder_name)
            if not self._ignore_folders[folder_name] then
                local directory = path:CombineDir(self._directory, folder_name)
                local main_file = path:Combine(directory, self.main_file_name)
                local mod_file = path:Combine(directory, "mod.xml")
				local add_file = path:Combine(directory, self.add_file)

				-- Prevent loading when DB isn't available
				if DB then
					self:FindOverrides(directory)
				end

				-- If a raid mod has a mod.xml, read that instead.
				if is_raid and FileIO:Exists(mod_file) then
					main_file = mod_file
				end

				-- Read main.xml
                if FileIO:Exists(main_file) then
                    local do_load = not self._loaded_mods[folder_name]

                    if CoreLoadingSetup then
                        local loading_scene_file = path:Combine(directory, self.loading_scene_file_name)
                        if not FileIO:Exists(loading_scene_file) then
                            do_load = false
                        end
                    end

                    if do_load then
                        self:LoadMod(folder_name, directory, main_file)
                    end
                elseif not self._ignore_detection_errors and not self._ignored_configs[main_file] then
                    self:log("Could not read %s", main_file)
                    self._ignored_configs[main_file] = true
                end

				-- Read add.xml
				if FileIO:Exists(add_file) and SystemFS then
					local config = FileIO:ReadConfig(add_file)
					local directory = config.full_directory or Path:Combine(directory, config.directory)
					BeardLib.Managers.Package:LoadConfig(directory, config)
					self.add_configs[directory] = config
				end
            end
        end
	end
end

-- Folders the function should look in
FrameworkBase._overrides_folders_of_interest = {
	anims = true,
	core = true,
	environments = true,
	fonts = true,
	gamedata = true,
	guis = true,
	movies = true,
	physic_effects = true,
	settings = true,
	shaders = true,
	soundbanks = true,
	strings = true,
	units = true
}

--- Attempts to load overrides from all mods in the framework.
--- It doesn't require the mod to be specifically made for BeardLib so it attempts to load regular mod_overrides mods
function FrameworkBase:FindOverrides(mod_path, path, check_all)
	local full_path = Path:Combine(mod_path, path)

	if path and check_all then
		for _, file in pairs(FileIO:GetFiles(full_path)) do
			local file_path = Path:Combine(mod_path, path, file)
			local ext = Path:GetFileExtension(file_path):id()

			-- Avoid loading things that are already handled by the game
			if self.type_name ~= AddFramework.type_name then
				local file_id =  Path:Combine(path, Path:GetFileNameNoExt(file)):id()
				local ext_id = ext:id()

				local file_key = Path:Combine(path, file)
				-- Only override once
				if not self._overridden_files[file_key] and DB:has(ext_id, file_id) then
					BLT.AssetManager:CreateEntry(file_id, ext_id, file_path)
					self._overridden_files[file_key] = true
				end
			end
		end
	end
	for _, folder in pairs(FileIO:GetFolders(full_path)) do
		if check_all or self._overrides_folders_of_interest[folder] then
			self:FindOverrides(mod_path, path and Path:Combine(path, folder) or folder, true)
		end
	end
end

function FrameworkBase:SortMods()
	Hooks:Call("BeardLibFrameworksSortMods", self)

	table.sort(self._sorted_mods, function(a,b)
        return a.Priority > b.Priority
	end)
	table.sort(self._waiting_to_load, function(a,b)
        return a.Priority > b.Priority
	end)
end

function FrameworkBase:InitMods()
	Hooks:Call("BeardLibFrameworksInitMods", self)

	for _, mod in pairs(self._sorted_mods) do
		Hooks:Call("BeardLibFrameworksInitMod", self, mod)

		local config = mod._config
		if not config.post_hook and not config.pre_hook then
			mod:PreInitModules(self.auto_init_modules)
			if self._log_init then
				self:log("Initialized Mod: %s", mod.ModPath)
			end
		end
	end
end

function FrameworkBase:RegisterHooks()
	self:AddCustomContact()
	self:SortMods()
    for _, mod in pairs(self._sorted_mods) do
        if not mod._disabled and mod._modules then
			for _, module in pairs(mod._modules) do
                if module.DoRegisterHook and self.auto_register_hook ~= false and not module.Registered then
                    local success, err = pcall(function() module:DoRegisterHook() end)
                    module.Registered = true
                    if not success then
                        self:log("[ERROR] An error occurred on the hook registration of %s. Error:\n%s", module._name, tostring(err))
                    end
                end
            end
        end
    end
end

local cap = string.capitalize
function FrameworkBase:Log(s, ...)
	BeardLib:Log("["..cap(self.type_name).." Framework] " .. s, ...)
end

FrameworkBase.log = FrameworkBase.Log

function FrameworkBase:LogErr(s, ...)
	BeardLib:LogErr("["..cap(self.type_name).." Framework] " .. s, ...)
end

function FrameworkBase:Warn(s, ...)
	BeardLib:Warn("["..cap(self.type_name).." Framework] " .. s, ...)
end

function FrameworkBase:DevLog(s, ...)
	BeardLib:DevLog("["..cap(self.type_name).." Framework] " .. s, ...)
end

function FrameworkBase:GetModByDir(dir)
    return self._loaded_mods[dir]
end

function FrameworkBase:GetModByName(name)
	if self._loaded_mods then
		for _, mod in pairs(self._loaded_mods) do
			if mod.Name == name then
				return mod
			end
		end
	end
    return nil
end

function FrameworkBase:IsModedLoaded(name)
	local mod = self:GetModByName(name)
	return mod and mod:IsEnabled() or false
end

function FrameworkBase:LoadMod(folder_name, directory, main_file)
	self:Log("Loading mod %s (%s)", folder_name, directory)

	rawset(_G, "ModPath", directory)
	local success, mod = pcall(function() return self._mod_core:new(main_file, false) end)
	if success then
		self:DevLog("Loaded Config: %s", directory)
		local framework = mod._config and mod._config.framework and BeardLib.Frameworks[mod._config.framework] or self
		if framework then
			framework:AddMod(folder_name, mod)
		end
	else
		self:LogErr("An error occurred on initilization of mod %s. Error:\n%s", folder_name, tostring(mod))
	end
end

function FrameworkBase:AddMod(folder_name, mod)
	self._loaded_mods[folder_name] = mod
	table.insert(self._sorted_mods, mod)
	mod._framework = self
	local config = mod._config
	if config and (config.post_hook or config.pre_hook) then
		table.insert(self._waiting_to_load, mod)
	end
end

function FrameworkBase:RemoveMod(folder_name)
	local mod = self._loaded_mods[folder_name]
	if mod then
		table.delete(self._sorted_mods, mod)
		table.delete(self._waiting_to_load, mod)
		self._loaded_mods[folder_name] = nil
		mod._framework = nil
	end
end

function FrameworkBase:AddCustomContact()
	if not FrameworkBase._added_contact and ContactModule then
		FrameworkBase._added_contact = true
		ContactModule:new(BeardLib, {
			id = "custom",
			name_id = "heist_contact_custom",
			description_id = "heist_contact_custom_description",
			package = "packages/contact_bain",
			assets_gui = "guis/mission_briefing/preload_contact_bain"
		}):RegisterHook()
	end
end

MapFramework = MapFramework or BeardLib:Class(FrameworkBase)
MapFramework._ignore_folders = {backups = true, prefabs = true}
MapFramework._directory = BeardLib.config.maps_dir
MapFramework.type_name = "Map"

function MapFramework:init()
    -- Deprecated, try not to use.
    if self.type_name == MapFramework.type_name then
        BeardLib.Frameworks.map = self
        BeardLib.managers.MapFramework = self
    end

    MapFramework.super.init(self)
end

---@deprecated
---Use BeardLib.Utils:GetMapByJobId instead
function MapFramework:GetMapByJobId(job_id)
    for _, map in pairs(self._loaded_mods) do
        if map._modules then
            for _, module in pairs(map._modules) do
                if module.type_name == "narrative" and module._config and module._config.id == job_id then
                    return map
                end
            end
        end
    end
    return nil
end

AddFramework = AddFramework or BeardLib:Class(FrameworkBase)
AddFramework.type_name = "Add"
AddFramework._directory = BeardLib.config.mod_override_dir

function AddFramework:init()
    -- Deprecated, try not to use.
    if self.type_name == AddFramework.type_name then
        BeardLib.Frameworks.add = self
        BeardLib.managers.AddFramework = self
    end

    AddFramework.super.init(self)
end