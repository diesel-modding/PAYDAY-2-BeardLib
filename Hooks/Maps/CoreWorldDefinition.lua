local BeardLib = BeardLib
local Framework = BeardLib.Frameworks.Base
local Hooks = Hooks

core:module("CoreWorldDefinition")
WorldDefinition = WorldDefinition or CoreWorldDefinition.WorldDefinition

local WorldDefinition_init = WorldDefinition.init
function WorldDefinition:init(...)
    WorldDefinition_init(self, ...)
    if self._ignore_spawn_list then
        self._ignore_spawn_list[Idstring("units/dev_tools/level_tools/ai_coverpoint"):key()] = true
    end
end

function WorldDefinition:do_package_load(pkg)
    if PackageManager:package_exists(pkg) then
        if not PackageManager:loaded(pkg) then
            PackageManager:load(pkg)
            --BeardLib:log("Loaded package: "..pkg)
        end
        table.insert(self._custom_loaded_packages, pkg)
    end
end

local WorldDefinition_load_world_package = WorldDefinition._load_world_package
function WorldDefinition:_load_world_package(...)
    if Global.level_data then
        local level_tweak = _G.tweak_data.levels[Global.level_data.level_id]
        if level_tweak then
            self._has_package = not not level_tweak.package
            if level_tweak.custom_packages then
                self._custom_loaded_packages = self._custom_loaded_packages or {}
                for _, package in ipairs(level_tweak.custom_packages) do
                    self:do_package_load(package.."_init")
                    self:do_package_load(package)
                end
            end
        end
    end
    if not BeardLib.current_level then
        WorldDefinition_load_world_package(self, ...)
    end
end

local WorldDefinitionunload_packages = WorldDefinition.unload_packages
function WorldDefinition:unload_packages(...)
    if Global.level_data then
        if BeardLib.current_level then
            for _, module in pairs(BeardLib.current_level._addfiles_modules) do
                module:Unload()
            end
        end

        if self._custom_instances then
            for _, instance in pairs(self._custom_instances) do
                instance:Unload()
            end
        end

        if self._custom_loaded_packages then
            for _, package in pairs(self._custom_loaded_packages) do
                --BeardLib:log("Unloaded package: "..package)
                --Disabled vanilla package unloading for the time being. This will crash certain custom maps after reloading them.
                --The exact reason is unknown.
                if PackageManager:loaded(package) and BeardLib.Managers.Package:HasPackage(package) then
                    PackageManager:unload(package)
                end
            end
            self._custom_loaded_packages = {}
        end
    end
    if not BeardLib.current_level and self._continent_packages then
        WorldDefinitionunload_packages(self, ...)
    end
end

local WorldDefinition_load_continent_init_package = WorldDefinition._load_continent_init_package
function WorldDefinition:_load_continent_init_package(path, ...)
    if not PackageManager:package_exists(path) then
        return
    end

    WorldDefinition_load_continent_init_package(self, path, ...)
end

local WorldDefinition_load_continent_package =  WorldDefinition._load_continent_package
function WorldDefinition:_load_continent_package(path, ...)
    if not PackageManager:package_exists(path) then
        return
    end

    WorldDefinition_load_continent_package(self, path, ...)
end

function WorldDefinition:convert_mod_path(path)
    if Global.level_data then
        local level_tweak = _G.tweak_data.levels[Global.level_data.level_id]
        if level_tweak then
            if BeardLib.current_level and level_tweak.custom and path and string.begins(path, ".map/") then
                path = path:gsub(".map", BeardLib.current_level._inner_dir)
            end
            if not PackageManager:has(Idstring("environment"), path:id()) then
                return "core/environments/default"
            end
        end
    end
    return path
end

local WorldDefinition_create_environment = WorldDefinition._create_environment
function WorldDefinition:_create_environment(data, offset, ...)
    data.environment_values.environment = self:convert_mod_path(data.environment_values.environment)
    for _, area in pairs(data.environment_areas) do
        if type(area) == "table" and area.environment then
            area.environment = self:convert_mod_path(area.environment)
        end
    end
    local shape_data
    if data.dome_occ_shapes and data.dome_occ_shapes[1] and data.dome_occ_shapes[1].world_dir then
        shape_data = data.dome_occ_shapes[1]
        data.dome_occ_shapes = nil
    end

    WorldDefinition_create_environment(self, data, offset, ...)

	if shape_data then
		local corner = shape_data.position
		local size = Vector3(shape_data.depth, shape_data.width, shape_data.height)
		local texture_name = shape_data.world_dir .. "cube_lights/" .. "dome_occlusion"
		if not DB:has(Idstring("texture"), Idstring(texture_name)) then
			Application:error("Dome occlusion texture doesn't exists, probably needs to be generated", texture_name)
		else
			managers.environment_controller:set_dome_occ_params(corner, size, texture_name)
		end
	end
end

function WorldDefinition:try_loading_custom_instance(instance)
    local module = Framework._loaded_instances[instance]
    if module then
        self._custom_instances = self._custom_instances or {}
        if not self._custom_instances[instance] then
            module:Load()
            self._custom_instances[instance] = module
        end
    end
end

function WorldDefinition:load_custom_instances()
    for name, data in pairs(self._continent_definitions) do
        if data.instances then
            for _, instance in pairs(data.instances) do
                self:try_loading_custom_instance(instance.folder)
            end
        end
    end
end

Hooks:PreHook(WorldDefinition, "_insert_instances", "BeardLibInsertCustomInstances", function(self)
    self:load_custom_instances()
end)

local add_trigger_sequence = WorldDefinition.add_trigger_sequence
function WorldDefinition:add_trigger_sequence(unit, triggers, ...)
	if not triggers then
		return
    end

    local fixed_triggers = {}
    for _, trigger in pairs(triggers) do
        if trigger.notify_unit_id then
            table.insert(fixed_triggers, trigger)
        end
    end

    return add_trigger_sequence(self, unit, fixed_triggers, ...)
end

Hooks:PostHook(WorldDefinition, "assign_unit_data", "BeardLibAssignUnitData", function(self, unit, data)
	self:_setup_cubemaps(unit, data)

    --- This fixes custom XML thinking that "01" is a number therefore converting it to just "1" https://github.com/Luffyyy/BeardLib-Editor/issues/557
    --- In order for this fix to work, the editor will insert a space after these problematic texts and then BeardLib will remove them.

    if data.editable_gui then
        local text = unit:editable_gui():text()
        if type(text) == "string" and data.editable_gui.space_fix and text:ends(" ") then
            unit:editable_gui():set_text(text:sub(0, text:len()-1))
        end
    end
end)

function WorldDefinition:_setup_cubemaps(unit, data)
	if not data.cubemap then
		return
	end

	unit:unit_data().cubemap_resolution = data.cubemap.cubemap_resolution

	local texture_name = (self._cube_lights_path or self:world_dir()) .. "cubemaps/" .. unit:unit_data().unit_id
	if not DB:has(Idstring("texture"), Idstring(texture_name)) then
		log("Cubemap texture doesn't exist, probably needs to be generated: " .. tostring(texture_name))
		return
	end
	-- This is needed to get the cubemap texture to show up
	local light = World:create_light("omni")

	light:set_projection_texture(Idstring(texture_name), true, true)
	light:set_enable(false)

	unit:unit_data().cubemap_fake_light = light
end

local unit_ids = Idstring("unit")
local key_unit = unit_ids:key()
Hooks:PreHook(WorldDefinition, "_create_massunit", "BeardLibForceLoadMassunitUnits", function(self, data)
    self:preload_massunit_units(data)
end)

function WorldDefinition:preload_massunit_units(data)
    -- Units inside massunits don't pass through the regular spawning function and is spawned inside the engine
    -- Unfortunately the units there don't load through dynamic resources
    -- In order to deal with this issue, we had to essentially include each unit that is used in the massunit (from the editor) in the world file.
    if data and data.preload_units then
        for _, unit in pairs(data.preload_units) do
            if Global.fm.added_files[key_unit] then
                local file = Global.fm.added_files[key_unit][unit:key()]
                if file then
                    BeardLib.Managers.File:LoadAsset(unit_ids, file.path, file.file)
                end
            end
        end
    end
end

Hooks:PreHook(WorldDefinition, "make_unit", "BeardLibEnsureUnitsAreLoaded", function(self, unit_data)
    local name_ids  = unit_data.name:id()
    if DB:has(unit_ids, name_ids) and not PackageManager:has(unit_ids, name_ids) then
        BeardLib:Log("[WorldDefinition] Unit %s was not loaded, dynamic resource loading it. You should add it to your add.xml", unit_data.name)
        BeardLib.Managers.File:LoadFileFromDB("unit", unit_data.name)
    end
end)