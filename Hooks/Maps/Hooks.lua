-- Contains a bunch of hooks to make custom heists work Mostly client-side code.
-- Anything >100 lines of code should be its own file.

local F = table.remove(RequiredScript:split("/"))

----------------------------------------------------------------
if F == "missionmanager" then
	-- Loads custom elements
	for _, name in ipairs(BeardLib.config.mission_elements) do
		dofile(Path:Combine(BeardLib.config.classes_dir, "Elements", "Element"..name..".lua"))
	end

	local add_script = MissionManager._add_script
	function MissionManager:_add_script(data, ...)
		if self._scripts[data.name] then
			return
		end
		return add_script(self, data, ...)
	end
----------------------------------------------------------------
elseif F == "killzonemanager" then
	-- Adds "kill" to killzone so you can kill the player instantly
	KillzoneManager.type_upd_funcs.kill = function (obj, t, dt, data)
		if not data.killed then
			data.timer = data.timer + dt
			if data.next_fire < data.timer then
				data.killed = true
				obj:_kill_unit(data.unit)
			end
		end
	end

	Hooks:PostHook(KillzoneManager, "_add_unit", "BeardLib.AddUnit", function(self, unit, zone_type, element_id)
		if zone_type == "kill" then
			local u_key = unit:key()
			self._units[u_key] = self._units[u_key] or {}
			self._units[u_key][zone_type] = self._units[u_key][zone_type] or {}
			self._units[u_key][zone_type][element_id] = {
				type = zone_type,
				timer = 0,
				next_fire = 0.1,
				unit = unit
			}
		end
	end)
elseif F == "groupaistatebase" then
GroupAIStateBase.orig_beardlib_on_criminal_objective_complete = GroupAIStateBase.on_criminal_objective_complete
function GroupAIStateBase:on_criminal_objective_complete( unit, objective )
	if not objective then -- Fixes a crash on Hell's Nightmare, not sure if other heists are affected
		return
	end
	self:orig_beardlib_on_criminal_objective_complete( unit, objective )
end
----------------------------------------------------------------
elseif F == "coreenvironmentmanager" then
	--Sky texture code.
	core:import("CoreClass")
	core:import("CoreEnvironmentHandler")
	core:import("CoreEnvironmentFeeder")
	core:module("CoreEnvironmentManager")

	EnvironmentManager = EnvironmentManager or CoreClass.class()
	Hooks:PostHook(EnvironmentManager, "init", "BeardLib.Init", function(self)
		local feeder_class = CoreEnvironmentFeeder.SkyTexturePathFeeder
		self._feeder_class_map[feeder_class.DATA_PATH_KEY] = feeder_class
		if feeder_class.FILTER_CATEGORY then
			local filter_list = self._predefined_environment_filter_map[feeder_class.FILTER_CATEGORY]
			if not filter_list then
				filter_list = {}
				self._predefined_environment_filter_map[feeder_class.FILTER_CATEGORY] = filter_list
			end
			table.insert(filter_list, feeder_class.DATA_PATH_KEY)
		end
	end)

	CoreEnvironmentFeeder.SkyTexturePathFeeder = CoreEnvironmentFeeder.SkyTexturePathFeeder or CoreClass.class(CoreEnvironmentFeeder.StringFeeder)
	local SkyTex = CoreEnvironmentFeeder.SkyTexturePathFeeder
	SkyTex.APPLY_GROUP_ID = CoreEnvironmentFeeder.Feeder.get_next_id()
	SkyTex.DATA_PATH_KEY = Idstring("others/sky_texture"):key()
	SkyTex.IS_GLOBAL = true
	SkyTex.FILTER_CATEGORY = "Sky texture path"
	function SkyTex:apply(handler, viewport, scene)
		if self._current and Underlay:loaded() then
			local texture = self._current
			if texture then
				local material = Underlay:material(Idstring("sky"))
				if material and DB:has(Idstring("texture"), texture:id()) then
					Application:set_material_texture(material, Idstring("diffuse_texture"), texture:id(), Idstring("normal"))
				end
			end
		end
	end
----------------------------------------------------------------
elseif F == "coresequencemanager" then
	if not CoreSequenceManager then
		return
	end

	Hooks:Register("BeardLibCreateScriptDataMods")
	Hooks:PostHook(CoreSequenceManager.SequenceManager, "init", "BeardLibSequenceManagerPostInit", function() 
		Hooks:Call("BeardLibCreateScriptDataMods")
	end)

	local MaterialElement = CoreSequenceManager.MaterialElement
	MaterialElement.FUNC_MAP.texture = "set_texture"

	function MaterialElement:set_texture(env, old_material, key)
		local materials = env.dest_unit:get_objects_by_type(Idstring("material"))
		local texture = TextureCache:retrieve(string.gsub(self._parameters["texture"], "'", ""), "normal")
		if self._parameters["multiple_objects"] then
			for _, imaterial in pairs(materials) do
				if imaterial:name() == Idstring(string.gsub(self._parameters["name"], "'", "")) then
					Application:set_material_texture(imaterial, Idstring("diffuse_texture"), texture)
				end
			end
		else
			local name = self:run_parsed_func(env, self._name)
			local new_material = env.dest_unit:material(name:id())
			Application:set_material_texture(new_material, Idstring("diffuse_texture"), texture)
		end
	end
	--Fixes some random crash
	local BodyElement = CoreSequenceManager.BodyElement
	function BodyElement.load(unit, data)
		for body_id, cat_data in pairs(data) do
			for _, sub_data in pairs(cat_data) do
				local body = unit:body(body_id)
				local param = sub_data[2]
				if type(param) == "string" then
					param = Idstring(param)
				end
				if body then
					body[sub_data[1]](body, param)
				end
			end
		end
	end
elseif F == "elementinteraction" then
    --Checks if the interaction unit is loaded to avoid crashes
    --Checks if interaction tweak id exists
    core:import("CoreMissionScriptElement")
    ElementInteraction = ElementInteraction or class(CoreMissionScriptElement.MissionScriptElement)
    local orig_init = ElementInteraction.init
    local unit_ids = Idstring("unit")
    local norm_ids = Idstring("units/dev_tools/mission_elements/point_interaction/interaction_dummy")
    local nosync_ids = Idstring("units/dev_tools/mission_elements/point_interaction/interaction_dummy_nosync")
    function ElementInteraction:init(mission_script, data, ...)
        if not PackageManager:has(unit_ids, norm_ids) or not PackageManager:has(unit_ids, nosync_ids) then
            return ElementInteraction.super.init(self, mission_script, data, ...)
        end
        if data and data.values and not tweak_data.interaction[data.values.tweak_data_id] then
            return ElementInteraction.super.init(self, mission_script, data, ...)
        end
        return orig_init(self, mission_script, data, ...)
    end

    function MissionScriptElement:init(mission_script, data)
        self._mission_script = mission_script
        self._id = data.id
        self._editor_name = data.editor_name
        self._values = data.values
    end
----------------------------------------------------------------
elseif F == "elementvehiclespawner" then
    --Same as interaction element but checks the selected vehicle
    core:import("CoreMissionScriptElement")
    ElementVehicleSpawner = ElementVehicleSpawner or class(CoreMissionScriptElement.MissionScriptElement)
    local orig_on_executed = ElementVehicleSpawner.on_executed
    local unit_ids = Idstring("unit")
    function ElementVehicleSpawner:on_executed(...)
        if not PackageManager:has(unit_ids, Idstring(self._vehicles[self._values.vehicle] or "")) then
            return
        end
        return orig_on_executed(self, ...)
    end
----------------------------------------------------------------
elseif F == "coresoundenvironmentmanager" then
    --From what I remember, this fixes a crash, these are useless in public.
    function CoreSoundEnvironmentManager:emitter_events(path)
        return {""}
    end
    function CoreSoundEnvironmentManager:ambience_events()
        return {""}
    end
----------------------------------------------------------------
elseif F == "coreelementinstance" then
    core:module("CoreElementInstance")
    core:import("CoreMissionScriptElement")
    function ElementInstancePoint:client_on_executed(...)
        self:on_executed(...)
    end
----------------------------------------------------------------
elseif F == "coreelementshape"  or F == "coreelementarea" then
	if F == "coreelementshape" then
		core:module("CoreElementShape")
	else
		core:module("CoreElementArea")
	end
    Hooks:PostHook(F == "coreelementshape" and ElementShape or ElementAreaTrigger, "init", "BeardLibAddSphereShape", function(self)
        if self._values.shape_type == "sphere" then
            self:_add_shape(CoreShapeManager.ShapeSphere:new({
                position = self._values.position,
                rotation = self._values.rotation,
                height = self._values.height,
                radius = self._values.radius
            }))
        end
    end)
----------------------------------------------------------------
elseif F == "playermovement" then
    --VR teleporation fix
    if _G.IS_VR then
        function PlayerMovement:trigger_teleport(data)
            if game_state_machine and game_state_machine:current_state() then
                self._vr_has_teleported = data
            end
        end

        function PlayerMovement:update(unit, t, dt)
            if _G.IS_VR then
                self:_update_vr(unit, t, dt)
            end

            self:_calculate_m_pose()

            if self:_check_out_of_world(t) then
                return
            end

            if self._vr_has_teleported then
                managers.player:warp_to(self._vr_has_teleported.position or Vector3(), self._vr_has_teleported.rotation or Rotation())
                self._vr_has_teleported = nil
                return
            end

            self:_upd_underdog_skill(t)

            if self._current_state then
                self._current_state:update(t, dt)
            end

            self:update_stamina(t, dt)
            self:update_teleport(t, dt)
        end
    else
        local trigger = PlayerMovement.trigger_teleport
        function PlayerMovement:trigger_teleport(data, ...)
            data.fade_in = data.fade_in or 0
            data.sustain = data.sustain or 0
            data.fade_out = data.fade_out or 0
            return trigger(self, data, ...)
        end
    end
----------------------------------------------------------------
elseif F == "playerdamage" then
    Hooks:PostHook(PlayerDamage, "init", "BeardLibPlyDmgInit", function(self)
        local level_tweak = tweak_data.levels[managers.job:current_level_id()]

        if level_tweak and level_tweak.player_invulnerable then
            self:set_mission_damage_blockers("damage_fall_disabled", true)
            self:set_mission_damage_blockers("invulnerable", true)
        end
    end)
----------------------------------------------------------------
elseif F == "coreworldinstancemanager" then
    --Fixes #252
    local prepare = CoreWorldInstanceManager.prepare_mission_data
    function CoreWorldInstanceManager:prepare_mission_data(instance, ...)
        local instance_data = prepare(self, instance, ...)
        for _, script_data in pairs(instance_data) do
            for _, element in ipairs(script_data.elements) do
                local vals = element.values
                if element.class == "ElementMoveUnit" then
                    if vals.start_pos then
                        vals.start_pos = instance.position + element.values.start_pos:rotate_with(instance.rotation)
                    end
                    if vals.end_pos then
                        vals.end_pos = instance.position + element.values.end_pos:rotate_with(instance.rotation)
                    end
                elseif element.class == "ElementRotateUnit" then
                    vals.end_rot = instance.rotation * vals.end_rot
                end
            end
        end
        return instance_data
    end
----------------------------------------------------------------
elseif F == "groupaitweakdata" then
    --Fixes a weird crash when exiting instance levels or in general the game not having a sanity check for having the level.
    local _read_mission_preset = GroupAITweakData._read_mission_preset

    function GroupAITweakData:_read_mission_preset(tweak_data, ...)
        if not Global.game_settings or not Global.game_settings.level_id or not tweak_data.levels[Global.game_settings.level_id] then
            return
        end
        return _read_mission_preset(self, tweak_data, ...)
    end
----------------------------------------------------------------
elseif F == "narrativetweakdata" then
	-- Not sure about this, could be pointless.
	Hooks:PostHook(NarrativeTweakData, "init", "MapFrameworkAddFinalNarrativeData", SimpleClbk(NarrativeTweakData.set_job_wrappers))
----------------------------------------------------------------
elseif F == "elementfilter" then
    --Overkill decided not to add a one down check alongside the difficulties, so here's one, because why not.

    Hooks:PostHook(ElementFilter, "_check_difficulty", "BeardLibFilterOneDownCheck", function(self)
        if self._values.one_down and Global.game_settings.one_down then
            return true
        end
    end)
----------------------------------------------------------------
elseif F == "menumanager" then
	local o_refresh = MenuManager.refresh_level_select
	function MenuManager.refresh_level_select(...)
		if Global.game_settings.level_id then
			return o_refresh(...)
		else
			BeardLib:log("[Warning] Refresh level select was called while level id was nil!")
		end
	end
----------------------------------------------------------------
elseif F == "gameplaycentralmanager" then
	function GamePlayCentralManager:add_move_unit(unit, from, to, speed, done_callback)
		self._move_units = self._move_units or {}
		if alive(unit) then
			from = from or unit:position()
			speed = speed or 1
			local total_time = mvector3.distance(from, to) / speed
			self._move_units[unit:key()] = {unit = unit, from = from, to = to, speed = speed, done_callback = done_callback, t = 0, total_time = total_time}
		end
	end

	function GamePlayCentralManager:add_rotate_unit(unit, from, to, speed, done_callback)
		self._rotate_units = self._rotate_units or {}
		if alive(unit) then
			from = from or unit:rotation()
			speed = speed or 1
			local temp_rot = Rotation:rotation_difference(from, to)
			local total_time = math.abs((temp_rot:yaw() + temp_rot:pitch() + temp_rot:roll())) / speed
			self._rotate_units[unit:key()] = {unit = unit, to = to, from = from, speed = speed, done_callback = done_callback, t = 0, total_time = total_time}
		end
	end

	Hooks:PostHook(GamePlayCentralManager, "update", "BeardLibGamePlayCentralManagerpost_update", function(self, t, dt)
		if self._rotate_units then
			for unit_k, task in pairs(self._rotate_units) do
				if task.t == task.total_time then
					self._rotate_units[unit_k] = nil
					if task.done_callback then
						task.done_callback()
					end
				else
					local rot = Rotation()
					task.t = math.min(task.t + dt, task.total_time)
					mrotation.step(rot, task.from, task.to, task.speed * task.t)
					if not alive(task.unit) then
						self._rotate_units[unit_k] = nil
					else
						self:set_position(task.unit, nil, rot)
					end
				end
			end
		end

		if self._move_units then
			for unit_k, task in pairs(self._move_units) do
				if task.t == task.total_time then
					self._move_units[unit_k] = nil
					if task.done_callback then
						task.done_callback()
					end
				else
					local pos = Vector3()
					task.t = math.min(task.t + dt, task.total_time)
					mvector3.step(pos, task.from, task.to, task.speed * task.t)
					if not alive(task.unit) then
						self._move_units[unit_k] = nil
					else
						self:set_position(task.unit, pos)
					end
				end
			end
		end
	end)

	function GamePlayCentralManager:is_unit_moving(unit)
		return alive(unit) and (self._move_units and self._move_units[unit:key()] or self._rotate_units and self._rotate_units[unit:key()])
	end

	function GamePlayCentralManager:set_position(unit, position, rotation)
		if position then
			unit:set_position(position)
		end
		if rotation then
			unit:set_rotation(rotation)
		end
		local objects = unit:get_objects_by_type(Idstring("model"))
		for _, object in pairs(objects) do
			object:set_visibility(not object:visibility())
			object:set_visibility(not object:visibility())
		end
		local num = unit:num_bodies()
		for i = 0, num - 1 do
			local unit_body = unit:body(i)
			unit_body:set_enabled(not unit_body:enabled())
			unit_body:set_enabled(not unit_body:enabled())
		end
	end
----------------------------------------------------------------
elseif F == "dialogmanager" then
	Hooks:PreHook(DialogManager, "queue_dialog", "BeardLibQueueDialogFixIds", function(self, id)
		if id and not managers.dialog._dialog_list[id] then
			local sound = BeardLib.Managers.Sound:GetSound(id)
			if sound then
				managers.dialog._dialog_list[id] = {
					id = id,
					sound = id,
					priority = sound.priority and tonumber(sound.priority) or tweak_data.dialog.DEFAULT_PRIORITY
				}
			end
		end
	end)
end