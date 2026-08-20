core:import("CoreSerialize")
ModCore = ModCore or class()
ModCore._auto_post_init = true

function ModCore:init(config_path, load_modules)
    if not FileIO:Exists(config_path) then
        BeardLib:Err("Config file at path '%s' is not readable!", config_path)
        return
    end

	self.ModPath = ModPath
    self.Priority = 1
	self.SavePath = SavePath
    self._modules = {}

    self._blt_mod = config_path:begins("mods/")

    if self:GetSetting("Enabled") == false and not self._blt_mod then
        self:ForceDisable()
	end

    if self._blt_mod then
		local mod = BLT.Mods:GetModOwnerOfFile(ModPath)
		if mod and not mod:IsEnabled() then
			self:ForceDisable()
		end
	end

	self:LoadConfigFile(config_path)
    table.insert(BeardLib.Mods, self)
    if load_modules == nil or load_modules then
        self:PreInitModules()
    end
end

function ModCore:PostInit(ignored_modules)
    if self._post_init_done then
        return
	end

	if not self._disabled and self._core_class then
		self._core_class:PreInit()
    end

    ignored_modules = ignored_modules or self._config.ignored_post_init_modules
    for _, module in pairs(self._modules) do
        if (not ignored_modules or not table.contains(ignored_modules, module._name)) then
            if module._config.auto_post_init ~= false then
                local success, err = pcall(function() module:PostInit() end)

                if not success then
                    self:Err("An error occurred on the post initialization of %s. Error:\n%s", module._name, tostring(err))
                end
            end
        end
    end

    if self._disabled then
        return
    end

	if self._core_class then
		self._core_class:Init()
	end

	local post_init = self._config.post_init_clbk or self._config.post_init
    if post_init then
        local clbk = self:StringToCallback(post_init)
        if clbk then
            clbk()
        end
	end
	self._post_init_done = true
end

local TEXTURE = Idstring("texture")
function ModCore:LoadConfigFile(path)
    local config = FileIO:ReadConfig(path)

    self.Name = config.name or tostring(table.remove(string.split(self.ModPath, "/")))
    self.Priority = tonumber(config.priority) or self.Priority

    local lib_ver = config.min_lib_ver
    if lib_ver then
        if tonumber(lib_ver) then
            lib_ver = math.round_with_precision(tonumber(config.min_lib_ver), 4)
        end
        local ver = Version:new(lib_ver)
        if ver > BeardLib.Version then
            if config.notify_about_version ~= false then
                self:ModError("The mod requires BeardLib version %s or higher in order to run", tostring(ver))
            end
            self:ForceDisable()
        end
    end

    if not self._disabled then
        if config.global_key then
            self.global = config.global_key
            if not _G[self.global] then
                rawset( _G, self.global, self)
            end
        end
    end

    if not CoreLoadingSetup then
        local icon = Path:Combine(self.ModPath, "icon")
        local icon_png = icon..".png"
        local icon_texture = icon..".texture"
        local found_icon
        if FileIO:Exists(icon_png) then
            found_icon = icon_png
        elseif FileIO:Exists(icon_texture) then
            found_icon = icon_texture
        end
        if found_icon then
            local ingame_path = Path:Combine("guis/textures/mods/icons", "mod_"..self.ModPath:key())
            BeardLib.Managers.File:AddFile(TEXTURE, Idstring(ingame_path), found_icon)
            config.image = ingame_path
        end
    end

    self._clean_config = deep_clone(config)
	self._config = config
end

function ModCore:ModError(...)
    BeardLib:ModError(self, ...)
    self:ForceDisable()
end

function ModCore:PreInitModules()
	if self._config and not self._disabled then
		self:InitModules()
	end
end

local load_first = {Dependencies = true, Hooks = true, Classes = true}
local updates = "AssetUpdates"

function ModCore:InitModules()
    if self.modules_initialized then
        return
    end

    if not self._disabled and self._config.core_class then
        self._core_class = self:Dofile(Path:Combine(self.ModPath, self._config.core_class)) or self
        --Allows to check for things before initializing the modules. Call :ModError from here only.
        if self._core_class and self._core_class.PreModuleInit then
            self._core_class:PreModuleInit()
        end
	end

	local order = self._config.load_first or load_first

	table.sort(self._config, function(a,b)
		local a_ok = type(a) == "table" and order[a._meta] or false
		local b_ok = type(b) == "table" and order[b._meta] or false
		return (a_ok and not b_ok) or (a.priority or 1) > (b.priority or 1)
	end)

    for _, module_tbl in ipairs(self._config) do
        self:AddModule(module_tbl)
    end

	if self._auto_post_init then
		self:PostInit()
    end

    if self._disabled and self.global and _G[self.global] then
        rawset( _G, self.global, nil)
    end
    self.modules_initialized = true
end


function ModCore:AddModule(module_tbl)
    if type(module_tbl) == "table" then
        local meta = string.PascalCase(module_tbl._meta)
        if (not self._disabled or (not self._config.no_disabled_updates and meta == updates)) and self._config.auto_init ~= false and not (self._config.ignored_modules and table.contains(self._config.ignored_modules, meta)) then
            local node_class = BeardLib.modules[meta]

            if not node_class and module_tbl._force_search then
                node_class = CoreSerialize.string_to_classtable(meta)
            end

            if node_class then
                local success, node_obj, valid = pcall(function() return node_class:new(self, module_tbl) end)
                if success then
                    if valid == false then
                        self:Log("Module with name %s does not contain a valid config. See above for details", node_obj._name)
                    else
                        if not node_obj._loose and self[node_obj._name] then
                            self:Log("The name of module: %s (%s) already exists in the mod table, please make sure this is a unique name!", node_obj._name, node_obj.type_name)
                        else
                            self[node_obj._name] = node_obj
                        end
                        table.insert(self._modules, node_obj)
                    end
                else
                    self:Err("An error occurred on initilization of module: %s. Error:\n%s", meta, tostring(node_obj))
                end
            elseif not (self._config.ignore_errors or CoreLoadingSetup) then
                self:Err("Unable to find module with key %s", meta)
            end
        end
    end
end

function ModCore:GetRealFilePath(path, lookup_tbl)
    if string.find(path, "%$") then
        return string.gsub(path, "%$(%w+)%$", lookup_tbl or self)
    else
        return path
    end
end

function ModCore:Log(str, ...)
    log("[" .. self.Name .. "] " .. string.format(str, ...))
end

function ModCore:Err(str, ...)
    log("[" .. self.Name .. "][ERROR] " .. string.format(str, ...))
    if BeardLib.DevMode then
        BeardLib:ModError(self, str, ...)
    end
end

function ModCore:LogErr(str, ...)
    log("[" .. self.Name .. "][ERROR] " .. string.format(str, ...))
end

function ModCore:Warn(str, ...)
    log("[" .. self.Name .. "][WARN] " .. string.format(str, ...))
end

function ModCore:StringToValue(str)
    if str == "self" then return self end

    if (string.find(str, "$")) then
        str = string.gsub(str, "%$(%w+)%$", self)
    end

    local global_tbl
    local self_search = "self."
    if string.begins(str, self_search) then
        str = string.sub(str, #self_search + 1, #str)
        global_tbl = self
    end

    return BeardLib.Utils:StringToValue(str, global_tbl)
end

function ModCore:StringToCallback(str)
	local value = BeardLib.Utils:normalize_string_value(str)
	if type(value) == "function" then
		return value
	else
		local split = string.split(str, ":")
		local func_name = table.remove(split)
		local global_tbl_name = split[1]

        local val = self:StringToValue(global_tbl_name)
        local typ = type(val)
        if typ == "table" then
			return ClassClbk(val, func_name)
        elseif typ == "function" then
            return val
        else
			return nil
		end
	end
end

function ModCore:RegisterHook(source_file, file, pre)
	local path = self:GetPath()
    local hook_file = Path:Combine(path, file)
    local dest_tbl = pre and (_prehooks or (BLT and BLT.hook_tables.pre)) or (_posthooks or (BLT and BLT.hook_tables.post))
	if dest_tbl then
		if FileIO:Exists(hook_file) then
			local req_script = source_file:lower()
			dest_tbl[req_script] = dest_tbl[req_script] or {}
			table.insert(dest_tbl[req_script], {
				mod_path = path,
				mod = self,
				script = file
			})
		else
			self:Err("Failed reading hook file %s of type %s", tostring(hook_file), tostring(pre and "pre" or "post"))
		end
	end
end

function ModCore:ForceDisable()
    self._disabled = true
end

function ModCore:Modules()
    return self._modules
end

function ModCore:GetModule(type_name)
    for _, module in pairs(self._modules) do
        if module.type_name == type_name then
            return module
        end
    end
    return nil
end

function ModCore:GetModuleIndex(m)
    local bigget_i = 0
    for i, module in pairs(self._modules) do
        if module == m then
            return i
        elseif module.type_name == m.type_name then
            bigget_i = i
        end
    end
    return bigget_i+1
end

function ModCore:GetModules(type_name)
    local modules = {}
    for _, module in pairs(self._modules) do
        if module.type_name == type_name then
            table.insert(modules, module)
        end
    end
    return modules
end

function ModCore:GetSettings()
    return BeardLib.Options:GetValue("ModSettings")[self.ModPath] or {}
end

function ModCore:SetSetting(setting, value)
    local mod_settings = BeardLib.Options:GetValue("ModSettings")
    mod_settings[self.ModPath] = mod_settings[self.ModPath] or {}
    mod_settings[self.ModPath][setting] = value
    BeardLib.Options:Save()
end

function ModCore:GetSetting(setting)
    local settings = self:GetSettings()
    return settings[setting]
end

function ModCore:Dofile(path)
    rawset(_G, "ModInstance", self)
    rawset(_G, "ModPath", self.ModPath)
    dofile(path)
end

function ModCore:PreInit() end
function ModCore:Init() end
function ModCore:GetPath() return self.ModPath end
function ModCore:Disabled() return self._disabled end
function ModCore:Enabled() return not self._disabled end
function ModCore:Config() return not self._config end
function ModCore:Priority() return not self.Priority end
function ModCore:IsBLTMod() return self._blt_mod end
function ModCore:MinLibVer() return self._config.min_lib_ver or -1 end

--BLT Keybinds support:

function ModCore:IsEnabled() return self:Enabled()end
function ModCore:WasEnabledAtStart() return self:Enabled()end
function ModCore:GetName() return self.Name end

ModCore.log = ModCore.Log
ModCore.post_init = ModCore.PostInit
ModCore.init_modules = ModCore.InitModules
ModCore.StringToTable = ModCore.StringToValue

--Add some functions to BeardLib class
for n, func in pairs(ModCore) do
    if not BeardLib[n] then
        BeardLib[n] = func
    end
end