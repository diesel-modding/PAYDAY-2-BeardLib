if BeardLib then
	return
end

BeardLib = {
	Name = "BeardLib",
	ModPath = BeardLibModPath or ModPath,
	SavePath = SavePath
}

BeardLibModPath = nil

function BeardLib:Init()
	Hooks:Call("BeardLibPreInit")

	Global.beardlib_checked_updates = Global.beardlib_checked_updates or {}

	self._call_next_update = {}
	self._paused_updaters = {}
	self._updaters = {}
	self._errors = {}
	self._modules = {}
	self._delayed_calls = {}

	self.Frameworks = {}
	self.Managers = {}
	self.Menus = {}
	self.Modules = {}
	self.Items = {}
	self.Mods = {}
	self.MusicMods = {}

	self._classes_to_init = {}

	dofile(self.ModPath.."Classes/Utils/FileIO.lua")
	dofile(self.ModPath.."Classes/Utils/Utils.lua")
	dofile(self.ModPath.."Classes/Utils/Path.lua")
	dofile(self.ModPath.."Classes/Utils/Version.lua")
	self._config = FileIO:ReadConfig(self.ModPath.."main.xml", self)
	self.config = self._config

	self:LoadClasses()

	local modules = self._config.modules_dir

	local modules_config = table.list_to_set(self._config.load_enabled_modules)
	self:LoadModules(modules_config, modules.."Addons/")
	self:LoadModules(modules_config, modules.."Utils/")

	if BeardLib:GetGame() == "raid" then
		self:LoadModules(modules_config, modules.."Raid/")
	else
		self:LoadModules(modules_config, modules.."PD2/")
	end
	self:LoadLocalization()

	for _, init in pairs(self._classes_to_init) do
		if not init.done and init.type == self.Constants.ClassTypes.Manager then
			local obj = init.class:new()
			if obj.type_name then
				self:RegisterClass(obj.type_name, obj, init.type)
			end
			init.done = true
		end
	end

	for name, config in pairs(self._config.load_modules) do
		if BeardLib.modules[name] then
			local module = BeardLib.Modules[name]:new(self, config)
			self[module._name] = module
			table.insert(self._modules, module)
			module:PostInit()
		end
	end

	self.Version = Version:new(self.config.version)
	self.DevMode = self.Options:GetValue("DevMode")
	self.LogSounds = self.Options:GetValue("LogSounds")
	self.OptimizedMusicLoad = BeardLib.Options:GetValue("OptimizedMusicLoad")

	if ModAssetsModule then
		if self.Options:GetValue("GithubUpdates") then
			local module = ModAssetsModule:new(self, {id = "simon-wh/PAYDAY-2-BeardLib", _meta = "AssetUpdates", important = true, provider = "github", branch = "master"})
			self[module._name] = module
			table.insert(self._modules, module)
		else
			local module = ModAssetsModule:new(self, {id = 14924, semantic_version = true, version = self.config.version, _meta = "AssetUpdates", important = true, provider = "modworkshop"})
			self[module._name] = module
			table.insert(self._modules, module)
		end
	end

	self:MigrateModSettings()

	for _, init in pairs(self._classes_to_init) do
		if not init.done then
			local obj = init.class:new()
			if obj.type_name then
				self:RegisterClass(obj.type_name, obj, init.type)
			end
			init.done = true
		end
	end

	self:FullyLoadFrameworks()

	self._classes_to_init = nil

	Hooks:Call("BeardLibPostInit")
end

--- Returns the name of the current game. If BLT is not setup to do so, assume we are in PD2.
function BeardLib:GetGame()
	return blt.blt_info().game or 'pd2'
end

function BeardLib:LoadClasses(config, prev_dir)
	local wanted_meta = CoreLoadingSetup and "loading_classes" or "classes"

	config = config or self._config[wanted_meta]
	local dir = Path:Combine(prev_dir or self.ModPath, config.directory)
    for _, c in ipairs(config) do
        if not c.game or (BeardLib:GetGame() or "pd2") == c.game then
			if c._meta == "class" then
				self:DevLog("Loading class %s", tostring(c.file))
				dofile(dir and Path:Combine(dir, c.file) or c.file)
			elseif c._meta == "classes" then
				self:LoadClasses(c, dir)
			end
		end
    end
end

--- Fully loads the frameworks after they're initalized and know their own mods so they can interact with each other better
--- Fixes #502
function BeardLib:FullyLoadFrameworks()
	for _, framework in pairs(self.Frameworks) do
		framework:InitMods()
	end
end

function BeardLib:LoadModules(config, dir)
	dir = dir or self._config.modules_dir
	local modules = FileIO:GetFiles(dir)
	if modules then
		table.sort(modules) -- Sort for predicatable order on different file systems
		for _, mdle in pairs(modules) do
			local dopath = Path:Combine(dir, mdle)
			if CoreLoadingSetup then
				local module_name = mdle:match("(.+)%..+")
				if config[module_name] then
					dofile(dopath)
				end
			else
				dofile(dopath)
			end
		end
		local folders = FileIO:GetFolders(dir)
		table.sort(folders) -- Sort for predicatable order on different file systems
		for _, cat in pairs(folders) do
			self:LoadModules(config, Path:CombineDir(dir, cat))
		end
	end
end

function BeardLib:LoadLocalization()
	if not LocalizationModule then return end

	local languages = {default = "english.yaml"}
	for _, file in pairs(FileIO:GetFiles(self._config.localization_dir)) do
		table.insert(languages, {_meta = "localization", file = file, language = Path:GetFileNameWithoutExtension(file)})
	end
	languages.directory = Path:GetFileNameWithoutExtension(self._config.localization_dir)
	LocalizationModule:new(self, languages)
end

function BeardLib:AddUpdater(id, clbk, paused)
	self._updaters[id] = clbk
	if paused then
		self._paused_updaters[id] = clbk
	end
end

function BeardLib:RemoveUpdater(id)
	self._updaters[id] = nil
	self._paused_updaters[id] = nil
end

function BeardLib:CallOnNextUpdate(func, only_unpaused, only_paused)
	table.insert(self._call_next_update, {func = func, only_unpaused = only_unpaused, only_paused = only_paused})
end

function BeardLib:AddDelayedCall(id, seconds, func, paused)
	self._delayed_calls[id] = {func = func, call_t = TimerManager:main():time() + seconds, paused = paused}
end

function BeardLib:RemoveDelayedCall(id, func)
	self._delayed_calls[id] = nil
end

function BeardLib:RegisterFramework(name, clss)
	self.Frameworks[name] = clss
end

function BeardLib:MenuClass(name, inherit)
	return self:Class(inherit, name, self.Constants.ClassTypes.Menu)
end

function BeardLib:ManagerClass(name, inherit)
	return self:Class(inherit, name, self.Constants.ClassTypes.Manager)
end

function BeardLib:ModuleClass(name, inherit)
	return self:Class(inherit, name, self.Constants.ClassTypes.Module, true)
end

function BeardLib:Class(inherit, type_name, typ, no_init)
	local clss = inherit and class(inherit) or class()
	if type_name then
		clss.type_name = type_name
	end
	if no_init then
		self:RegisterClass(type_name, clss, typ)
	else
		table.insert(self._classes_to_init, {class = clss, type = typ})
	end
	return clss
end

function BeardLib:RegisterClass(name, clss, typ)
	local types = self.Constants.ClassTypes
	if typ == types.Manager then
		self:RegisterManager(name, clss)
	elseif typ == types.Framework then
		self:RegisterFramework(name, clss)
	elseif typ == types.Module then
		self:RegisterModule(name, clss)
	elseif typ == types.Menu then
		self:RegisterMenu(name, clss)
	end
end

function BeardLib:RegisterManager(name, clss)
	self.Managers[name] = clss
end

function BeardLib:RegisterMenu(name, clss)
	self.Menus[name] = clss
end

function BeardLib:RegisterModule(key, module)
	if not key or type(key) ~= "string" then
		self:log("[ERROR] BeardLib:RegisterModule parameter #1, string expected got %s", key and type(key) or "nil")
	end

	if not self.Modules[key] then
		self:DevLog("Registered module with key %s", key)
		self.Modules[key] = module
	end
end

function BeardLib:Update(t, dt)
	for _, manager in pairs(self.Managers) do
		if manager.Update then
			manager:Update(t, dt)
		end
	end
	local main_t = TimerManager:main():time()
	for id, delayed in pairs(self._delayed_calls) do
		if delayed.call_t <= main_t then
			self._delayed_calls[id] = nil
			delayed.func()
		end
	end
	for _, beardlib_update in pairs(self._updaters) do
		beardlib_update(t, dt)
	end
	for _, call in pairs(self._call_next_update) do
		if not call.only_paused then
			call.func(t, dt)
		end
	end
	self._call_next_update = {}
end

function BeardLib:PausedUpdate(t, dt)
	for _, manager in pairs(self.Managers) do
		if manager.Update then
			manager:Update(t, dt, true)
		end
	end

	local main_t = TimerManager:main():time()
	for id, delayed in pairs(self._delayed_calls) do
		if delayed.paused and delayed.call_t <= t then
			delayed.func()
			self._delayed_calls[id] = nil
		end
	end
	for _, beardlib_paused_update in pairs(self._paused_updaters) do
		beardlib_paused_update(t, dt)
	end
	for _, call in pairs(self._call_next_update) do
		if not call.only_unpaused then
			call.func(t, dt)
		end
	end
	self._call_next_update = {}
end

function BeardLib:DevLog(str, ...)
	if false and self.log then
		self:log(str, ...)
	end
end

function BeardLib:ModError(mod, str, ...)
	self._errors[mod.ModPath] = self._errors[mod.ModPath] or {}
	table.insert(self._errors[mod.ModPath], string.format(str, ...))
end

function BeardLib:ShowErrorsDialog()
	local loc = managers.localization
	BeardLib.Managers.Dialog:Simple():Show({
		force = true,
		w = 1100,
		full_bg_color = Color.black:with_alpha(0.9),
		title = loc:text("beardlib_found_errors"),
		create_items = function(menu)
			menu:TextBox({name = loc:text("beardlib_search"), lines = 1, on_callback = function(item)
				local list = menu:GetItem("MessageScroll")
				for _, group in pairs(list:Items()) do
					local search = item:Value()
					local visible = search == "" or group.text:lower():find(search:lower()) ~= nil
					group:SetVisible(visible)
				end
			end})
			menu:QuickText(loc:text("beardlib_errors_tip"))
		end,
		create_items_contained = function(scroll)
			for mod_path, err_list in pairs(BeardLib._errors) do
				if mod_path == BeardLib.ModPath then
					mod_path = "BeardLib/Mix of mods"
				end
				local mod = scroll:Group({text = "Mod: "..mod_path, private = {background_color = Color.red:with_alpha(0.8), highlight_color = false}, offset = {16, 2}})
				for _, err in pairs(err_list) do
					mod:QuickText(err)
				end
			end
		end
	})
end

--Migrate old data (<4.0) to BeardLib 4.0'S ModSettings.
function BeardLib:MigrateModSettings()
    local disabled_mods = self.Options:GetValue("DisabledMods")
	local ignored_updates = self.Options:GetValue("IgnoredUpdates")
	local mod_settings = self.Options:GetValue("ModSettings")

	local migrated = false
	if disabled_mods and table.size(disabled_mods) > 0 then
		for mod_path, value in pairs(disabled_mods) do
			if mod_path ~= "_meta" then
				if type(mod_settings[mod_path]) ~= "table" then
					mod_settings[mod_path] = {}
				end
				mod_settings[mod_path].Enabled = not value
				migrated = true
			end
		end
		self.Options:SetValue("DisabledMods", {})
	end
	if ignored_updates and table.size(ignored_updates) > 0 then
		for mod_path, value in pairs(ignored_updates) do
			if mod_path ~= "_meta" then
				if type(mod_settings[mod_path]) ~= "table" then
					mod_settings[mod_path] = {}
				end
				mod_settings[mod_path].IgnoreUpdates = value
				migrated = true
			end
		end
		self.Options:SetValue("IgnoredUpdates", {})
	end
	if migrated then
		self.Options:SetValue("ModSettings", mod_settings)
		self.Options:Save()
	end
end

Hooks:Register("BeardLibPreInit")
Hooks:Register("BeardLibPostInit")
Hooks:Register("BeardLibAddCustomWeaponModsToWeapons")
Hooks:Register("BeardLibCreateCustomNodesAndButtons")
Hooks:Register("BeardLibPostCreateCustomProjectiles")
Hooks:Register("BeardLibCreateCustomProjectiles")
Hooks:Register("BeardLibCreateCustomWeaponSkins")
Hooks:Register("BeardLibCreateCustomWeaponMods")
Hooks:Register("BeardLibPreProcessScriptData")
Hooks:Register("BeardLibCreateCustomWeapons")
Hooks:Register("BeardLibCreateCustomPlayerStyles")
Hooks:Register("BeardLibCreateCustomPlayerStyleVariants")
Hooks:Register("BeardLibExtraOutfit")
Hooks:Register("BeardLibExtraOutfitReload")
Hooks:Register("BeardLibSetupUnloadPackages")
Hooks:Register("GameSetupPrePausedUpdate")
Hooks:Register("BeardLibRequireHook")
Hooks:Register("BeardLibCreateCustomMenus")
Hooks:Register("BeardLibProcessScriptData")
Hooks:Register("BeardLibSetupInitFinalize")
Hooks:Register("GameSetupPauseUpdate")
Hooks:Register("SetupInitManagers")
Hooks:Register("SetupPreUpdate")

--Wish I didn't have to do this. But sadly I don't think there's a hook for this.
local OrigRequire = require
BeardLib.OrigRequire = OrigRequire
function require(...)
	Hooks:Call("BeardLibRequireHook", false, ...)
	local res = OrigRequire(...)
	Hooks:Call("BeardLibRequireHook", true, ...)
	return res
end

BeardLib:Init()

Hooks:Add("GameSetupPauseUpdate", "BeardLibGameSetupPausedUpdate", ClassClbk(BeardLib, "PausedUpdate"))
Hooks:Add("GameSetupUpdate", "BeardLibGameSetupUpdate", ClassClbk(BeardLib, "Update"))
Hooks:Add("MenuUpdate", "BeardLibMenuUpdate", ClassClbk(BeardLib, "Update"))

Hooks:Add("MenuManagerInitialize", "BeardLibCreateMenuHooks", function(self)
    managers.menu = managers.menu or self
    Hooks:Call("BeardLibCreateCustomMenus", self)
    Hooks:Call("BeardLibMenuHelperPlusInitMenus", self)
	Hooks:Call("BeardLibCreateCustomNodesAndButtons", self)

	Global.game_settings.custom_maps_only = BeardLib.Options:GetValue("CustomMapsOnlyFilter")
end)

Hooks:Add("MenuManagerOnOpenMenu", "BeardLibShowErrors", function(self, menu)
	if menu == "menu_main" and not LuaNetworking:IsMultiplayer() then
		if BeardLib.Options:GetValue("ShowErrorsDialog") and table.size(BeardLib._errors) > 0 then
			BeardLib:ShowErrorsDialog()
		end

		if (BeardLib:GetGame() or "pd2") == "pd2" then
			-- Add Crime.Net custom maps only button to the filters
			function MenuCallbackHandler:beardlib_custom_maps_only(item)
				local val = item:value() == "on"
				BeardLib.Options:SetValue("CustomMapsOnlyFilter", val)
				Global.game_settings.custom_maps_only = val
				managers.network.matchmake:search_lobby(managers.network.matchmake:search_friends_only())
			end


			local node = MenuHelperPlus:GetNode(nil, "crimenet_filters")
			MenuHelperPlus:AddToggle({
				id = "beardlib_custom_maps_only",
				title = "beardlib_custom_maps_only",
				node = node,
				value = Global.game_settings.custom_maps_only,
				position = 13,
				callback = "beardlib_custom_maps_only",
			})
		end
	end
end)
