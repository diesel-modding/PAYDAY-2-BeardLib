-- Contains a bunch of hooks to make custom items work. Mostly client-side code
-- Anything >100 lines of code should be its own file.

local F = table.remove(RequiredScript:split("/"))
local Hooks = Hooks

if F == "weaponfactorymanager" then
----------------------------------------------------------------
    --Custom weapons crash fix based of Rokk's mod.
    --I wish I could make a warning dialog for custom weapon crash fix but you'd need to pause the save manager or something..
    local orig_unpack = WeaponFactoryManager.unpack_blueprint_from_string
    function WeaponFactoryManager:unpack_blueprint_from_string(factory_id, ...)
        local factory = tweak_data.weapon.factory
        if not factory[factory_id] then
            return {}
        end
        return orig_unpack(self, factory_id, ...)
    end


    local orig_has = WeaponFactoryManager.has_perk
    function WeaponFactoryManager:has_perk(perk_name, factory_id, blueprint, ...)
        local factory = tweak_data.weapon.factory

        for _, part_id in pairs(blueprint) do
            if not factory.parts[part_id] then
                BeardLib:log("[Fixes][Warning] Weapon mod with the ID '%s' was found in the save but was missing, the weapon mod will be deleted from the save", tostring(part_id))
                return false
            elseif type(factory.parts[part_id].perks) == "string" then
                BeardLib:log("[Fixes][Warning] Perks value is a string when it's supposed to be a table, weapon mod id %s, perk value %s", tostring(part_id), tostring(factory.parts[part_id].perks))
                factory.parts[part_id].perks = {factory.parts[part_id].perks}
            end
        end

        return orig_has(self, perk_name, factory_id, blueprint, ...)
    end

    --https://github.com/simon-wh/PAYDAY-2-BeardLib/issues/112
    Hooks:PreHook(WeaponFactoryManager, "_read_factory_data", "BeardLibFixMissingParts", function(self)
        local tweak = tweak_data.weapon.factory
        for factory_id, data in pairs(tweak) do
            if factory_id ~= "parts" and type(data.uses_parts) == "table" then
                local new_uses_parts = {}
                for _, part_id in pairs(data.uses_parts) do
                    if tweak.parts[part_id] then
                        table.insert(new_uses_parts, part_id)
                    elseif not factory_id:ends("_npc") then
                        BeardLib:log("[Fixes][Warning] Weapon with the factory ID %s has the part %s defined but the part does not exist", tostring(factory_id), tostring(part_id))
                    end
                end
                data.uses_parts = new_uses_parts
            end
        end
    end)
----------------------------------------------------------------
elseif F == "blackmarketmanager" then
    local orig_get = BlackMarketManager.get_silencer_concealment_modifiers
    function BlackMarketManager:get_silencer_concealment_modifiers(weapon, ...)
        local weapon_id = weapon.weapon_id or managers.weapon_factory:get_weapon_id_by_factory_id(weapon.factory_id)
        if tweak_data.weapon[weapon_id] then
            return orig_get(self, weapon, ...)
        else
            BeardLib:log("[Fixes][Warning] Weapon with the ID '%s' was found in the save but was missing, the weapon will be deleted from the save", tostring(weapon_id))
            return 0
        end
    end

    local orig_string_mask = BlackMarketManager._outfit_string_mask
    function BlackMarketManager:_outfit_string_mask(...)
        if not managers.blackmarket:equipped_mask() then
            BeardLib:log("[Fixes][Warning] Mask is null, returning default.")
            return "character_locked"
        end
        return orig_string_mask(self, ...)
    end

    --Fixes #211.
    --Fixes duplicates with custom weapon mods that use gloval values by forcing 1 of each weapon mod.
    local orig_get_mods = BlackMarketManager.get_dropable_mods_by_weapon_id
    function BlackMarketManager:get_dropable_mods_by_weapon_id(weapon_id, weapon_data)
        local parts = tweak_data.weapon.factory.parts
        local droppable_mods = orig_get_mods(self, weapon_id, weapon_data)
        for k, v in pairs(droppable_mods) do
            local new_tbl = {}
            local duplicate = {}
            for _, drop in pairs(v) do
                if not duplicate[drop[1]] then
                    local part = parts[drop[1]]
                    if part and part.global_value and not part.allow_duplicates then
                        drop[2] = part.global_value
                        duplicate[drop[1]] = true
                    end
                    table.insert(new_tbl, drop)
                end
            end
            droppable_mods[k] = new_tbl
        end
        return droppable_mods
    end

    --WARNING: this function has been completely replaced. If anything fucks up, please removed it.
    --Fixes sorting for custom melee.
    function BlackMarketManager:get_sorted_melee_weapons(hide_locked, id_list_only)
        local items = {}
        local global_value, td, category

        for id, item in pairs(Global.blackmarket_manager.melee_weapons) do
            td = tweak_data.blackmarket.melee_weapons[id]
            global_value = td.dlc or td.global_value or "normal"
            category = td.type or "unknown"
            local add_item = item.unlocked or item.equipped or not hide_locked and not tweak_data:get_raw_value("lootdrop", "global_values", global_value, "hide_unavailable")

            if add_item then
                table.insert(items, {
                    id,
                    item
                })
            end
        end

        local xd, yd, x_td, y_td, x_sn, y_sn, x_gv, y_gv
        local m_tweak_data = tweak_data.blackmarket.melee_weapons
        local l_tweak_data = tweak_data.lootdrop.global_values

        local function sort_func(x, y)
            xd = x[2]
            yd = y[2]
            x_td = m_tweak_data[x[1]]
            y_td = m_tweak_data[y[1]]

            if x_td.custom ~= y_td.custom then
                return x_td.custom == nil
            end

            if _G.IS_VR and xd.vr_locked ~= yd.vr_locked then
                return not xd.vr_locked
            end

            if xd.unlocked ~= yd.unlocked then
                return xd.unlocked
            end

            if xd.level ~= yd.level then
                return xd.level < yd.level
            end

            if x_td.instant ~= y_td.instant then
                return x_td.instant
            end

            if xd.skill_based ~= yd.skill_based then
                return xd.skill_based
            end

            if x_td.free ~= y_td.free then
                return x_td.free
            end

            x_gv = x_td.global_value or x_td.dlc or "normal"
            y_gv = y_td.global_value or y_td.dlc or "normal"
            x_sn = l_tweak_data[x_gv]
            y_sn = l_tweak_data[y_gv]
            x_sn = x_sn and x_sn.sort_number or 1
            y_sn = y_sn and y_sn.sort_number or 1

            if x_sn ~= y_sn then
                return x_sn < y_sn
            end

            if xd.level ~= yd.level then
                return xd.level < yd.level
            end

            return x[1] < y[1]
        end

        table.sort(items, sort_func)

        if id_list_only then
            local id_list = {}

            for _, data in ipairs(items) do
                table.insert(id_list, data[1])
            end

            return id_list
        end

        local override_slots = {
            4,
            4
        }
        local num_slots_per_category = override_slots[1] * override_slots[2]
        local sorted_categories = {}
        local item_categories = {}
        local category = nil

        for index, item in ipairs(items) do
            category = math.max(1, math.ceil(index / num_slots_per_category))
            item_categories[category] = item_categories[category] or {}

            table.insert(item_categories[category], item)
        end

        for i = 1, #item_categories, 1 do
            table.insert(sorted_categories, i)
        end

        return sorted_categories, item_categories, override_slots
    end

    --No clue how but sometimes the first function (get_silencer_concealment_modifiers) fails to remove the weapon so this comes as a backup.
    local orig_weapons_unlocked = BlackMarketManager.weapon_unlocked_by_crafted
    function BlackMarketManager:weapon_unlocked_by_crafted(category, slot, ...)
        local crafted = self._global and self._global.crafted_items[category][slot]

        if not crafted then
            return false
        end
        local data = Global.blackmarket_manager.weapons[crafted.weapon_id]
        if data then
            return orig_weapons_unlocked(self, category, slot, ...)
        else
            BeardLib:log("[Fixes][Warning #2] Weapon with the ID '%s' was found in the save but was missing, the weapon will be deleted from the save", tostring(weapon_id))
            return false
        end
    end

    -- This is literally just a check if they exist, even in vanilla this wouldn't mark pirates. 
    function BlackMarketManager:verfify_recived_crew_loadout(loadout, mark_host_as_cheater)
        return true
    end
----------------------------------------------------------------
elseif F == "crewmanagementgui" then
    local orig = CrewManagementGui.populate_primaries
    --Blocks out custom weapons that don't have support for AI.
    function CrewManagementGui:populate_primaries(i, data, ...)
        local res = orig(self, i, data, ...)
        for k, v in ipairs(data) do
            local fac_id = managers.weapon_factory:get_factory_id_by_weapon_id(v.name)
            if fac_id then
                local factory = tweak_data.weapon.factory[fac_id.."_npc"]
                if factory and factory.custom and not DB:has(Idstring("unit"), factory.unit:id()) then
                    v.buttons = {}
                    v.unlocked = false
                    v.lock_texture = "guis/textures/pd2/lock_incompatible"
                    v.lock_text = managers.localization:text("menu_data_crew_not_allowed")
                end
            end
        end
        return res
    end
----------------------------------------------------------------
elseif F == "raycastweaponbase" then
    if RaycastWeaponBase._soundfix_should_play_normal then
        return --Don't run if fix installed.
    end

    function RaycastWeaponBase:use_soundfix()
        local sounds = tweak_data.weapon[self:get_name_id()].sounds
        return sounds and sounds.use_fix == true
    end

    --Based of https://modworkshop.net/mydownloads.php?action=view_down&did=20403
    local fire_sound = RaycastWeaponBase._fire_sound
    function RaycastWeaponBase:_fire_sound(...)
        if not self:use_soundfix() then
            return fire_sound(self, ...)
        end
    end

    local fire = RaycastWeaponBase.fire
    function RaycastWeaponBase:fire(...)
        local result = fire(self, ...)
        if self:use_soundfix() and result then
			self._bullets_fired = 0
            self:play_tweak_data_sound("fire_single", "fire")
        end
        return result
    end

    Hooks:PreHook(RaycastWeaponBase, "update_next_shooting_time", "BeardLibUpdateNextShootingTime", function(self)
        if self:use_soundfix() then
            self:_fire_sound()
        end
    end)

    Hooks:PreHook(RaycastWeaponBase, "trigger_held", "BeardLibTriggerHeld", function(self)
        if not self:start_shooting_allowed() and self:use_soundfix() then
            self:play_tweak_data_sound("stop_fire")
        end
    end)

    --Checks the name ID of the weapon to ensure it exists. If it doesn't exist, it searches for a factory that holds this unit
    --and then accesses its weapon_id parameter (because fuck going through shit upgradestweakdata). If that fails, it falls back to amcar.
    Hooks:PreHook(RaycastWeaponBase, "_create_use_setups", "BeardLibCheckWeaponExistence", function(self)
        if not tweak_data.weapon[self._name_id] then
            local unit_name = self._unit:name()
            for _, fac in pairs(tweak_data.weapon.factory) do
                self._name_id = nil
                if fac.weapon_id and fac.unit and fac.unit:id() == unit_name then
                    self._name_id = fac.weapon_id
                    break
                end
            end
            self._name_id = self._name_id or "amcar"
        end
    end)
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
elseif F == "dlcmanager" then
    --Fixes parts receiving global value doing a check here using global values and disregarding if the global value is not a DLC. https://github.com/simon-wh/PAYDAY-2-BeardLib/issues/237
    function GenericDLCManager:is_dlc_unlocked(dlc)
        if not tweak_data.dlc[dlc] then
            local global_value = tweak_data.lootdrop.global_values[dlc]
            if global_value and global_value.custom then
                return tweak_data.lootdrop.global_values[dlc].dlc == false
            end
        end
        return tweak_data.dlc[dlc] and tweak_data.dlc[dlc].free or self:has_dlc(dlc)
    end
----------------------------------------------------------------
elseif F == "playerhandstatemelee" then
    --Removes the need of having a thq material config for custom melee in VR.
    local mtr_cubemap = Idstring("mtr_cubemap")
    Hooks:PostHook(PlayerHandStateMelee, "_spawn_melee_unit", "VRBeardLibForceMeleeTHQ", function(self)
        if alive(self._melee_unit) then
            local tweak = tweak_data.blackmarket.melee_weapons[self._melee_entry]
            if tweak.custom then
                if tweak.auto_thq ~= false then
                    for _, material in ipairs(self._melee_unit:get_objects_by_type(Idstring("material"))) do
                        if material:name() == mtr_cubemap then
                            material:set_render_template(Idstring("generic:CUBE_ENVIRONMENT_MAPPING:DIFFUSE_TEXTURE:NORMALMAP"))
                        else
                            material:set_render_template(Idstring("generic:DIFFUSE_TEXTURE:NORMALMAP"))
                        end
                    end
                end
            end
        end
    end)
----------------------------------------------------------------
elseif F == "hudbelt" then
    local function scale_by_aspect(gui_obj, max_size)
        local w = gui_obj:texture_width()
        local h = gui_obj:texture_height()

        if h < w then
            gui_obj:set_size(max_size, max_size / w * h)
        else
            gui_obj:set_size(max_size / h * w, max_size)
        end
    end

    --Fixes melees in VR having no fallback and to make them use based_on when the files are missing.
    local tex_ids = Idstring("texture")
    Hooks:PostHook(HUDBeltInteraction, "update_icon", "BeardLibFixCustomMelee", function(self)
        if self._id == "melee" then
            local tweak = tweak_data.blackmarket.melee_weapons[managers.blackmarket:equipped_melee_weapon()]
            local id = tweak.based_on
            if id then
                if self._texture then
                    if not DB:has(tex_ids, self._texture) then
                        local prefix = "guis"
                        local texture = "/textures/pd2/blackmarket/icons/melee_weapons/outline/" .. id

                        if not DB:has(tex_ids, Idstring(prefix .. texture)) then
                            prefix = "guis/dlcs/" .. tweak_data.blackmarket.melee_weapons[id].texture_bundle_folder
                        end

                        if DB:has(tex_ids, Idstring(prefix .. texture)) then
                            self._texture = prefix .. texture
                        else
                            self._texture = "guis/textures/pd2/blackmarket/icons/melee_weapons/outline/weapon"
                        end

                        self._icon:set_image(self._texture)
                        scale_by_aspect(self._icon, math.min(self._w, self._h))
                        self._icon:set_center(self._panel:w() / 2, self._panel:h() / 2)
                    end
                end
            end
        end
    end)
----------------------------------------------------------------
elseif F == "blackmarketgui" then
    -- Universal icon backwards compatibility.
    Hooks:PostHook(BlackMarketGui, "populate_weapon_category_new", "BeardLibUniversalIconMiniIconFix", function(self, data)
        local category = data.category
        local crafted_category = managers.blackmarket:get_crafted_category(category) or {}

        for i, index in pairs(data.on_create_data) do
            local crafted = crafted_category[index]

            if crafted then
                local equipped_cosmetic_id = crafted and crafted.cosmetics and crafted.cosmetics.id
                local color_tweak = tweak_data.blackmarket.weapon_skins[equipped_cosmetic_id]

                if color_tweak and color_tweak.universal then
                    local guis_catalog = "guis/"
                    local bundle_folder = color_tweak.texture_bundle_folder
                    if bundle_folder then
                        guis_catalog = guis_catalog .. "dlcs/" .. tostring(bundle_folder) .. "/"
                    end

                    local mini_icons = data[i].mini_icons
                    mini_icons[#mini_icons].texture = guis_catalog .. "weapon_skins/" .. equipped_cosmetic_id
                end
            end
        end
    end)

    Hooks:PostHook(BlackMarketGui, "populate_weapon_cosmetics", "BeardLibUniversalIconMiniIconFix2", function(self, data)
        local crafted = managers.blackmarket:get_crafted_category(data.category)[data.prev_node_data and data.prev_node_data.slot]
        local equipped_cosmetic_id = crafted and crafted.cosmetics and crafted.cosmetics.id
        local color_tweak = tweak_data.blackmarket.weapon_skins[equipped_cosmetic_id]

        if color_tweak and color_tweak.universal then
            local guis_catalog = "guis/"
            local bundle_folder = color_tweak.texture_bundle_folder
            if bundle_folder then
                guis_catalog = guis_catalog .. "dlcs/" .. tostring(bundle_folder) .. "/"
            end

            data[1].bitmap_texture = guis_catalog .. "weapon_skins/" .. equipped_cosmetic_id
        end
    end)
----------------------------------------------------------------
elseif F == "menunodecustomizeweaponcolorgui" then
    -- Universal icon backwards compatibility.
    Hooks:PreHook(MenuCustomizeWeaponColorInitiator, "create_grid", "BeardLibUniversalIconGridFix", function(self, node, colors_data)
        for _, color_data in pairs(colors_data) do
            local color_tweak = tweak_data.blackmarket.weapon_skins[color_data.value]

            if color_tweak and color_tweak.universal then
                local guis_catalog = "guis/"
                local bundle_folder = color_tweak.texture_bundle_folder
                if bundle_folder then
                    guis_catalog = guis_catalog .. "dlcs/" .. tostring(bundle_folder) .. "/"
                end

                color_data.texture = guis_catalog .. "weapon_skins/" .. color_data.value
            end
        end
    end)
----------------------------------------------------------------
elseif F == "tweakdata" then
	local function icon_and_unit_check(list, folder, friendly_name, uses_texture_val, only_check_units)
		for id, thing in pairs(list) do
			if thing.custom and not id:ends("_npc") and not id:ends("_crew") then
				if not only_check_units and not thing.hidden then
					if folder ~= "mods" or thing.pcs then
						local guis_catalog = "guis/"
						local bundle_folder = thing.texture_bundle_folder
						if bundle_folder then
							guis_catalog = guis_catalog .. "dlcs/" .. tostring(bundle_folder) .. "/"
						end

						guis_catalog = guis_catalog .. "textures/pd2/blackmarket/icons/"..folder.."/"
						local tex = uses_texture_val and thing.texture or guis_catalog .. id
						if not DB:has(Idstring("texture"), tex) then
							local mod = BeardLib.Utils:FindModWithPath(thing.mod_path) or BeardLib
							mod:Err("Icon for %s %s doesn't exist path: %s", tostring(friendly_name), tostring(id), tostring(tex))
						end
					end
				end
				if thing.unit then
					if not DB:has(Idstring("unit"), thing.unit) then
						local mod = BeardLib.Utils:FindModWithPath(thing.mod_path) or BeardLib
						mod:Err("Unit for %s %s doesn't exist path: %s", tostring(friendly_name), tostring(id), tostring(thing.unit))
					end
				end
			end
		end
	end
	icon_and_unit_check(tweak_data.weapon, "weapons", "weapon")
	icon_and_unit_check(tweak_data.weapon.factory, "weapons", "weapon", false, true)
	icon_and_unit_check(tweak_data.weapon.factory.parts, "mods", "weapon mod")
	icon_and_unit_check(tweak_data.blackmarket.melee_weapons, "melee_weapons", "melee weapon")
	icon_and_unit_check(tweak_data.blackmarket.textures, "textures", "mask pattern", true)
	icon_and_unit_check(tweak_data.blackmarket.materials, "materials", "mask material")
----------------------------------------------------------------
elseif F == "tweakdatapd2" then
    for _, framework in pairs(BeardLib.Frameworks) do framework:RegisterHooks() end

	Hooks:PostHook(WeaponFactoryTweakData, "_init_content_unfinished", "CallWeaponFactoryAdditionHooks", function(self)
		Hooks:Call("BeardLibCreateCustomWeapons", self)
		Hooks:Call("BeardLibCreateCustomWeaponMods", self)
	end)

	Hooks:PostHook(BlackMarketTweakData, "init", "CallAddCustomProjectiles", function(self, tweak_data)
		Hooks:Call("BeardLibCreateCustomProjectiles", self, tweak_data)
	end)

	-- Store all the part types that are getting cloned so we can redo them to account for modded parts.
	-- I'd store them under WFTD but code expects weapon data to be stored there.
	local clone_part_type_for_weapon = WeaponFactoryTweakData._clone_part_type_for_weapon
	function WeaponFactoryTweakData:_clone_part_type_for_weapon(...)
		BeardLibTemporaryTypeClonesToRedo = BeardLibTemporaryTypeClonesToRedo or {}
		table.insert(BeardLibTemporaryTypeClonesToRedo, {...})
	end

    local create_bonuses = WeaponFactoryTweakData.create_bonuses
    function WeaponFactoryTweakData:create_bonuses(tweak_data, weapon_skins)
        if self.parts.wpn_fps_upg_bonus_concealment_p1 then return end
        create_bonuses(self, tweak_data, weapon_skins)
    end

    local _add_charms_to_all_weapons = WeaponFactoryTweakData._add_charms_to_all_weapons
    function WeaponFactoryTweakData:_add_charms_to_all_weapons(tweak_data, weapon_charms, weapon_overrides, part_overrides, weapon_exclude_list)
        if self.parts.wpn_fps_upg_charm_bag then return table.map_keys(weapon_charms) end
        return _add_charms_to_all_weapons(self, tweak_data, weapon_charms, weapon_overrides, part_overrides, weapon_exclude_list)
    end

	Hooks:PreHook(BlackMarketTweakData, "_init_weapon_mods", "CallAddCustomWeaponModsToWeapons", function(self, tweak_data)
		-- Pre-generate boosts and charms as some custom stuff might rely on them.
        -- Make sure to only run these two once (see soft hooks above).
        -- https://github.com/simon-wh/PAYDAY-2-BeardLib/issues/651
		if self.weapon_skins then
			tweak_data.weapon.factory:create_bonuses(tweak_data, self.weapon_skins)
		end
		self.weapon_charms = tweak_data.weapon.factory:create_charms(tweak_data)

		Hooks:Call("BeardLibAddCustomWeaponModsToWeapons", tweak_data.weapon.factory, tweak_data)

		-- This has to go after our BeardLib hook so any clone related tweak data doesn't get inherited weirdly.
		-- But it also has to go before "_init_weapon_mods" so that it's blackmarket data gets generated correctly.
		-- Frustrating...

		-- This only gets used for one weapon and attachment type for now, but who knows what else will end up using it.
		-- Don't have to worry about setting custom as they are only `adds` which isn't synced.
		if BeardLibTemporaryTypeClonesToRedo then
			for _, clone_data in pairs(BeardLibTemporaryTypeClonesToRedo) do
				clone_part_type_for_weapon(tweak_data.weapon.factory, unpack(clone_data))
			end

			-- Cleanup after ourselves.
			BeardLibTemporaryTypeClonesToRedo = nil
		end
	end)

	--Big brain.
	Hooks:PostHook(BlackMarketTweakData, "_init_weapon_mods", "FixGlobalValueWeaponMods", function(self, tweak_data)
		local parts = tweak_data.weapon.factory.parts
		for id, mod in pairs(self.weapon_mods) do
			local gv = parts[id] and parts[id].global_value
			if gv then
				mod.global_value = gv
			end
		end
	end)

	Hooks:PreHook(WeaponTweakData, "init", "BeardLibWeaponTweakDataPreInit", function(self, tweak_data)
		_tweakdata = tweak_data
	end)

	Hooks:PostHook(WeaponTweakData, "init", "BeardLibWeaponTweakDataInit", function(self, tweak_data)
		Hooks:Call("BeardLibPostCreateCustomProjectiles", tweak_data)
	end)

	Hooks:PostHook(BlackMarketTweakData, "init", "CallPlayerStyleAdditionHooks", function(self)
		Hooks:Call("BeardLibCreateCustomPlayerStyles", self)
		Hooks:Call("BeardLibCreateCustomPlayerStyleVariants", self)
	end)
----------------------------------------------------------------
elseif F == "playerstandard" then
	--Ignores full or regular reload for weapons that have the tweakdata value set to true. Otherwise, continues with the original function.
	--Based on Custom Weapon Animations Fixes by Pawcio
	local _start_action_reload = PlayerStandard._start_action_reload
	function PlayerStandard:_start_action_reload(t, ...)
		local weapon = self._equipped_unit:base()
		if weapon then
			local weapon_tweak = weapon:weapon_tweak_data()
			local anims_tweak = weapon_tweak.animations or {}
			local ignore_fullreload = anims_tweak.ignore_fullreload
			local ignore_nonemptyreload = anims_tweak.ignore_nonemptyreload
			local clip_empty = weapon:clip_empty()
			if ((ignore_fullreload and clip_empty) or (ignore_nonemptyreload and not clip_empty)) and weapon:can_reload() then
				weapon:tweak_data_anim_stop("fire")

				local speed_multiplier = weapon:reload_speed_multiplier()
				local reload_prefix = weapon:reload_prefix() or ""
				local reload_name_id = anims_tweak.reload_name_id or weapon.name_id

				local expire_t = weapon_tweak.timers.reload_not_empty or weapon:reload_expire_t() or (ignore_fullreload and 2.2 or 2.8)
				local reload_anim = ignore_fullreload and "reload_not_empty" or "reload"

				self._ext_camera:play_redirect(Idstring(reload_prefix .. reload_anim .. "_" .. reload_name_id), speed_multiplier)
				self._state_data.reload_expire_t = t + expire_t / speed_multiplier

				weapon:start_reload()

				if not weapon:tweak_data_anim_play(reload_anim, speed_multiplier) then
					weapon:tweak_data_anim_play("reload", speed_multiplier)
				end

				self._ext_network:send("reload_weapon", ignore_fullreload and 0 or 1, speed_multiplier)

				return
			end
		end
		return _start_action_reload(self, t, ...)
	end

	--Reload shell by shell.
	--Based on Custom Weapon Animations Fixes by Pawcio
	local _start_action_reload_enter = PlayerStandard._start_action_reload_enter
	function PlayerStandard:_start_action_reload_enter(t, ...)
		if self._equipped_unit:base():can_reload() then
			local weapon = self._equipped_unit:base()
			local tweak_data = weapon:weapon_tweak_data()
			self:_interupt_action_steelsight(t)
			if not self.RUN_AND_RELOAD then
				self:_interupt_action_running(t)
			end
			if tweak_data.animations.reload_shell_by_shell and  self._equipped_unit:base():reload_enter_expire_t()  then
				local speed_multiplier = self._equipped_unit:base():reload_speed_multiplier()
				self._ext_camera:play_redirect(Idstring("reload_enter_" .. tweak_data.animations.reload_name_id), speed_multiplier)
				self._state_data.reload_enter_expire_t = t + self._equipped_unit:base():reload_enter_expire_t() / speed_multiplier
				self._equipped_unit:base():tweak_data_anim_play("reload_enter", speed_multiplier)
				return
			end
		end
		return _start_action_reload_enter(self, t, ...)
	end
----------------------------------------------------------------
elseif F == "newraycastweaponbase" then
	--Related to top hook ^
	--Based on Custom Weapon Animations Fixes by Pawcio
	local started_reload_empty = NewRaycastWeaponBase.started_reload_empty
	function NewRaycastWeaponBase:started_reload_empty(...)
		if self:weapon_tweak_data().animations.ignore_fullreload then
			return self._started_reload_empty
		else
			return started_reload_empty(self, ...)
		end
	end
----------------------------------------------------------------
elseif F == "dlctweakdata" then
	Hooks:PostHook(DLCTweakData, "init", "BeardLibModDLCGlobalValue", function(self, tweak_data)
		tweak_data.lootdrop.global_values.mod = {
			name_id = "bm_global_value_mod",
			desc_id = "menu_l_global_value_mod",
			color = Color(255, 59, 174, 254) / 255,
			dlc = false,
			chance = 1,
			value_multiplier = 1,
			durability_multiplier = 1,
			track = false,
			sort_number = -10
		}

		table.insert(tweak_data.lootdrop.global_value_list_index, "mod")

		self.mod = {
			free = true,
			content = {loot_drops = {}, upgrades = {}}
		}
	end)
----------------------------------------------------------------
elseif F == "workshopmanager" then
	Hooks:PreHook(WorkshopManager, "_setup", "BeardLibPreInitItems", function()
		Hooks:Call("BeardLibCreateCustomWeaponSkins")
	end)
end