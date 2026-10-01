WeaponModule = WeaponModule or BeardLib:ModuleClass("Weapon", ItemModuleBase)

function WeaponModule:init(...)
    self.required_params = {}
    self.clean_table = table.add(clone(self.clean_table), {
        {param = "weapon.kick", action = "remove_metas"},
        {param = "weapon.crosshair", action = "remove_metas"},
        {param = "weapon.stats", action = "remove_metas"},
        {param = "factory.default_blueprint", action = "remove_metas"},
        {param = "factory.uses_parts",  action = "remove_metas"},
        {param = "factory.optional_types", action = "remove_metas"},
        {param = "factory.animations", action = "remove_metas"},
        {param = "factory.override", action = {"remove_metas", "shallow_no_number_indexes"}},
        {param = "factory.adds", action = {"remove_metas", "shallow_no_number_indexes"}},
        {param = "factory.sight_adds", action = {"remove_metas", "shallow_no_number_indexes"}},
        {param = "stance.standard.shoulders.rotation", action = "normalize"},
        {param = "stance.steelsight.shoulders.rotation", action = "normalize"},
        {param = "stance.crouched.shoulders.rotation", action = "normalize"},
        {param = "stance.bipod.shoulders.rotation", action = "normalize"},
	})

    return WeaponModule.super.init(self, ...)
end

local default_weap = "glock_17"
function WeaponModule:GetBasedOn(w_self, based_on)
    w_self = w_self or tweak_data.weapon
    based_on = based_on or self._config.weapon.based_on
    if based_on and w_self[based_on] then
        return based_on
    else
        return default_weap
    end
end

local default_weap_crew = "glock_18_crew"
function WeaponModule:GetCrewBasedOn(w_self, based_on)
    w_self = w_self or tweak_data.weapon
    based_on = based_on or self._config.weapon.crew_based_on or self._config.weapon.based_on
    if based_on then
        local crew = based_on.."_crew"
        local npc = based_on.."_npc"
        if w_self[crew] then
            return crew
        elseif w_self[npc] then
            return npc
        end
    end
    return default_weap_crew
end

function WeaponModule:RegisterHook()
    local dlc = self._config.dlc or self.defaults.dlc

    --Old eh? lets convert it!
    if not self._config.weapon and not self._config.factory and self._config.fac_id then
        self:ConvertOldToNew()
    end

    for _, param in pairs({"weapon", "factory", "weapon.id"}) do
        if BeardLib.Utils:StringToValue(param, self._config, true) == nil then
            self:Err("Parameter '%s' is required!", param)
            return false
        end
    end

    Hooks:PostHook(WeaponTweakData, "_init_new_weapons", self._config.weapon.id .. "AddWeaponTweakData", function(w_self, autohit_rifle_default, autohit_pistol_default, autohit_shotgun_default, autohit_lmg_default, autohit_snp_default, autohit_smg_default, autohit_minigun_default, damage_melee_default, damage_melee_effect_multiplier_default, aim_assist_rifle_default, aim_assist_pistol_default, aim_assist_shotgun_default, aim_assist_lmg_default, aim_assist_snp_default, aim_assist_smg_default, aim_assist_minigun_default)
        local config = self._config.weapon

        if w_self[config.id] then
            self:Err("Weapon with id '%s' already exists!", config.id)
            return
        end

        local default_autohit = {
            rifle = autohit_rifle_default,
            pistol = autohit_pistol_default,
            shotgun = autohit_shotgun_default,
            lmg = autohit_lmg_default,
            snp = autohit_snp_default,
            smg = autohit_smg_default,
            minigun = autohit_minigun_default,
        }

        local default_aim_assist = {
            rifle = aim_assist_rifle_default,
            pistol = aim_assist_pistol_default,
            shotgun = aim_assist_shotgun_default,
            lmg = aim_assist_lmg_default,
            snp = aim_assist_snp_default,
            smg = aim_assist_smg_default,
            minigun = aim_assist_minigun_default,
        }

        local data = table.merge(deep_clone(w_self[self:GetBasedOn(w_self)]), table.merge({
            name_id = "bm_w_" .. config.id,
            desc_id = "bm_w_" .. config.id .. "_desc",
            description_id = "des_" .. config.id,
            autohit = default_autohit[config.default_autohit],
            aim_assist = default_aim_assist[config.default_aim_assist],
            damage_melee = damage_melee_default,
            damage_melee_effect_mul = damage_melee_effect_multiplier_default,
            global_value = self.defaults.global_value,
            texture_bundle_folder = "mods",
            mod_path = self._mod.ModPath,
            custom = true
        }, config))
        data.AMMO_MAX = data.CLIP_AMMO_MAX * data.NR_CLIPS_MAX
        data.AMMO_PICKUP = config.ammo_pickup and w_self:_pickup_chance(data.AMMO_MAX, config.ammo_pickup) or data.AMMO_PICKUP
        data.npc = nil
        data.override = nil

        if config.override then
            data = table.merge(data, config.override)
        end

	    w_self[config.id] = data
    end)

    Hooks:PostHook(WeaponTweakData, "_precalculate_values", self._config.weapon.id .. "AddCrewWeaponTweakData", function(w_self)
        local config = self._config.weapon
        w_self[config.id .. "_crew"] = table.merge(deep_clone(w_self[self:GetCrewBasedOn(w_self)]), table.merge({custom = true}, config.crew))
        -- Assign NPC variant to be the same as crew if there's any code that relies on the NPC table.
        -- tbh I'm not sure at this point if this will work the weapon code in this game is absolute mess.
        if not w_self[config.id .. "_npc"] then
          w_self[config.id .. "_npc"] = w_self[config.id .. "_crew"]
        end
    end)

    Hooks:PostHook(TweakDataVR , "init", self._config.weapon.id .. "AddVRWeaponTweakData", function(vrself)
        local config = self._config.vr or {}

        local id = self._config.weapon.id
        if config.locked then
            vrself.locked.weapons[id] = true
            return
        end

        local timelines = vrself.reload_timelines
        local based_on = self:GetBasedOn(timelines, config.based_on) --If not present, use normal based on of weapon tweakdata.
        timelines[id] = table.merge(deep_clone(timelines[based_on]), config.reload_timelines)

        local tweak_offsets = vrself.weapon_offsets
        local tweak_weapon_assist = vrself.weapon_assist.weapons
        local tweak_weapon_hidden = vrself.weapon_hidden
        local tweak_custom_wall_check = vrself.custom_wall_check
        local tweak_magazine_offsets = vrself.magazine_offsets
        local tweak_sound_overrides = vrself.weapon_sound_overrides

        local offsets = tweak_offsets[based_on]
        local weapon_assist = tweak_weapon_assist[based_on]
        local weapon_hidden = tweak_weapon_hidden[based_on]
        local custom_wall_check = tweak_custom_wall_check[based_on]
        local magazine_offsets = tweak_magazine_offsets[based_on]
        local sound_overrides = tweak_sound_overrides[based_on]

        tweak_offsets[id] = offsets and table.merge(offsets, config.offsets) or config.offsets or nil
        tweak_weapon_assist[id] = weapon_assist and table.merge(weapon_assist, config.weapon_assist) or config.weapon_assist or nil
        tweak_weapon_hidden[id] = weapon_hidden and table.merge(weapon_hidden, config.weapon_hidden) or config.weapon_hidden or nil
        tweak_custom_wall_check[id] = custom_wall_check and table.merge(custom_wall_check, config.custom_wall_check) or config.custom_wall_check or nil
        tweak_magazine_offsets[id] = magazine_offsets and table.merge(magazine_offsets, config.magazine_offsets) or config.magazine_offsets or nil
        tweak_sound_overrides[id] = sound_overrides and table.merge(sound_overrides, config.sound_overrides) or config.sound_overrides or nil
    end)

    self._config.factory.id = self._config.factory.id or ("wpn_fps_"..self._config.weapon.id)

    Hooks:Add("BeardLibCreateCustomWeapons", self._config.factory.id .. "AddWeaponFactoryTweakData", function(f_self)
        local config = self._config.factory
        config.id = config.id or ("wpn_fps_"..self._config.weapon)
        if f_self[config.id] then
            self:Err("Weapon with factory id '%s' already exists!", config.id)
            return
        end

        config.custom = true

        if config.guess_unit ~= false then
            config.unit = config.unit or ("units/mods/weapons/"..config.id.."/"..config.id)
        end

        config.mod_path = self._mod.ModPath
        config.weapon_id = self._config.weapon.id -- Fuck going over upgrades tweakdata.
        if config.based_on then
            local based_on = f_self[config.based_on] and config.based_on or nil
            f_self[config.id] = based_on and table.merge(deep_clone(f_self[based_on]), config) or config
            if not based_on then
                self:Err("Factory data has an invalid based on! %s", tostring(config.based_on))
            end
        else
            f_self[config.id] = config
        end

        local npc_data = clone(f_self[config.id])
        npc_data.unit = npc_data.unit.."_npc"
        f_self[config.id .. "_npc"] = npc_data
    end)

    Hooks:PostHook(UpgradesTweakData, "init", self._config.weapon.id .. "AddWeaponUpgradesData", function(u_self)
        local unlock_level = self._config.weapon.unlock_level or self._config.unlock_level or 1

        --Stance mod stuff. We can't do this in weapon factory hook since upgrade tweakdata isn't ready yet (and we use it to find the factory ids)
        local fac_id = self._config.factory.id
        local based_on_fac = self._config.factory.based_on or u_self.definitions[self:GetBasedOn(u_self.definitions)].factory_id
        local factory = _tweakdata.weapon.factory
        local fac_weapon = factory[fac_id]
        local sight_adds = self._config.factory.sight_adds
        for _, part_id in pairs(fac_weapon.uses_parts) do
            local part = factory.parts[part_id]
            if part and part.stance_mod then
                if not part.stance_mod[fac_id] and part.stance_mod[based_on_fac] then
                    part.stance_mod[fac_id] = deep_clone(part.stance_mod[based_on_fac])
                end

                if sight_adds then
                    fac_weapon.adds[fac_id] = table.merge(fac_weapon.adds[fac_id], sight_adds)
                end
            end
        end
        --

        u_self.definitions[self._config.weapon.id] = {
            category = "weapon",
            weapon_id = self._config.weapon.id,
            factory_id = self._config.factory.id,
            dlc = dlc
        }
        u_self.level_tree[unlock_level] = u_self.level_tree[unlock_level] or {upgrades={}, name_id="weapons"}
        table.insert(u_self.level_tree[unlock_level].upgrades, self._config.weapon.id)
    end)

    Hooks:PostHook(PlayerTweakData, "_init_new_stances", self._config.weapon.id .. "AddWeaponStancesData", function(p_self)
        local stance_data = self._config.stance or {}
        local stances = p_self.stances
        stances[self._config.weapon.id] = table.merge(deep_clone(stances[self:GetBasedOn(stances, stance_data.based_on)]), stance_data)
    end)
end

function WeaponModule:ConvertOldToNew()
    self:log("Converting weapon module from old to new(It's recommended to update the module)")
    local anims = self._config.animations and BeardLib.Utils:RemoveMetas(self._config.animations)
    self._config.weapon = {
        id = self._config.id,
        based_on = self._config.based_on,
        default_autohit = self._config.autohit,
        default_aim_assist = self._config.aim_assist,
        damage_melee = self._config.damage_melee,
        damage_melee_effect_mul = self._config.damage_melee_effect_mul,
        global_value = self._config.global_value,
        override = self._config.merge_data,
        muzzleflash = self._config.muzzleflash,
        shell_ejection = self._config.shell_ejection,
        use_data = self._config.use_data,
        DAMAGE = self._config.DAMAGE,
        damage_near = self._config.damage_near,
        damage_far = self._config.damage_far,
        shake = self._config.shake,
        weapon_hold = self._config.weapon_hold,
        rays = self._config.rays,
        CLIP_AMMO_MAX = self._config.CLIP_AMMO_MAX,
        NR_CLIPS_MAX = self._config.NR_CLIPS_MAX,
        FIRE_MODE = self._config.FIRE_MODE,
        fire_mode_data = self._config.fire_mode_data,
        single = self._config.single,
        spread = self._config.spread,
        category = self._config.category,
        sub_category = self._config.sub_category,
        sounds = self._config.sounds,
        timers = self._config.timers,
        cam_animations = self._config.cam_animations,
        animations = anims,
        texture_bundle_folder = self._config.texture_bundle_folder,
        panic_suppression_chance = self._config.panic_suppression_chance,
        kick = self._config.kick and BeardLib.Utils:RemoveMetas(self._config.kick),
        crosshair = self._config.crosshair and BeardLib.Utils:RemoveMetas(self._config.crosshair),
        stats = self._config.stats and BeardLib.Utils:RemoveMetas(self._config.stats),
    }
    self._config.factory = {
        id = self._config.fac_id,
        unit = self._config.unit,
        default_blueprint = self._config.default_blueprint and BeardLib.Utils:RemoveMetas(self._config.default_blueprint),
        uses_parts = self._config.uses_parts and BeardLib.Utils:RemoveMetas(self._config.uses_parts),
        optional_types = self._config.optional_types and BeardLib.Utils:RemoveMetas(self._config.optional_types),
        animations = anims,
        override = self._config.fac_merge_data and BeardLib.Utils:RemoveMetas(BeardLib.Utils:RemoveAllNumberIndexes(self._config.override)),
        adds = self._config.adds and BeardLib.Utils:RemoveMetas(BeardLib.Utils:RemoveAllNumberIndexes(self._config.adds)),
    }
    --now those are useless.
    --weapon
    self._config.id = nil
    self._config.based_on = nil
    self._config.autohit  = nil
    self._config.aim_assist = nil
    self._config.damage_melee  = nil
    self._config.damage_melee_effect_mul = nil
    self._config.global_value = nil
    self._config.merge_data = nil
    self._config.muzzleflash = nil
    self._config.shell_ejection = nil
    self._config.use_data = nil
    self._config.DAMAGE = nil
    self._config.damage_near = nil
    self._config.damage_far = nil
    self._config.kick = nil
    self._config.crosshair = nil
    self._config.shake = nil
    self._config.weapon_hold = nil
    self._config.cam_animations = nil
    self._config.texture_bundle_folder = nil
    self._config.panic_suppression_chance = nil
    self._config.stats = nil
    self._config.rays = nil
    self._config.CLIP_AMMO_MAX = nil
    self._config.NR_CLIPS_MAX = nil
    self._config.FIRE_MODE = nil
    self._config.fire_mode_data = nil
    self._config.single = nil
    self._config.spread = nil
    self._config.category = nil
    self._config.sub_category = nil
    self._config.sounds = nil
    self._config.timers = nil
    --factory
    self._config.override = nil
    self._config.unit = nil
    self._config.default_blueprint = nil
    self._config.uses_parts = nil
    self._config.optional_types = nil
    self._config.animations = nil
    self._config.fac_id = nil
    self._config.adds = nil
end

WeaponModuleNew = WeaponModuleNew or BeardLib:ModuleClass("WeaponNew", WeaponModule) --Kept for backwards compatibility