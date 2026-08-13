WeaponSkinModule = WeaponSkinModule or BeardLib:ModuleClass("WeaponSkin", ItemModuleBase)

function WeaponSkinModule:RegisterHook()
    self._config.id = self._config.id or self:Err("Cannot add a weapon skin : No ID specified.")
    self._config.weapon_id = self._config.weapon_id or "amcar"
    self._config.weapon_ids = self._config.weapon_ids or nil
    self._config.name_id = self._config.name_id or self._config.name or "bm_wskn_" .. self._config.id
    self._config.desc_id = self._config.desc_id or self._config.desc
    self._config.rarity = self._config.rarity or "common"
    self._config.is_a_color_skin = self._config.is_a_color_skin or self._config.universal or false
    self._config.skin_folder = self._config.skin_folder and self:GetPath(self._config.skin_folder) or not self._config.is_a_color_skin and self:Err("The weapon skin '%s' is not shipped with the skin folder.", self._config.skin_folder)
    self._config.locked = self._config.locked or nil
    self._config.unique_name_id = self._config.unique_name_id or self._config.unique_name and self._config.name or nil

    if (not self._config.is_a_color_skin) or self._config.universal then
        self._config.texture_bundle_folder = self._config.texture_bundle_folder or self._config.id
    else
        self._config.texture_bundle_folder = self._config.texture_bundle_folder or self._config.global_value or "mods"
    end

    self._config.global_value = self._config.global_value or self.defaults.global_value
    self._config.group_id = self._config.global_value_category or self._config.global_value

    if self._config.skin_attachments then
        self._skin_attachments = self._config.skin_attachments

        for k, v in pairs(self._skin_attachments) do
            if k == "_meta" then
                table.remove_key( self._skin_attachments, "_meta" )
            end
        end
    end

    self._assets_folders = self._config.skin_folder
    self._skin_design = {}

    if self._assets_folders and not SystemFS:exists(self._assets_folders) then
        self._mod:Err("[WeaponSkinModule] Asset directory at '%s' doesn't exist.", self._assets_folders)
        return
    end

    Hooks:Add("BeardLibCreateCustomWeaponSkins", self._config.id .. "_SkinData", function()
        local config = self._config

        if tweak_data.blackmarket.weapon_skins[config.id] then
            self:Err("The weapon skin '%s' already exists in the tweak data table.", config.id)
            return
        end

        if self._assets_folders then
            local skin_data = WeaponSkinExtension:new(self._assets_folders, self._config.id)
            self._skin_design = {
                base_gradient = skin_data:get_base_gradient(),
                pattern_gradient = skin_data:get_pattern_gradient(),
                pattern = skin_data:get_pattern(),
                pattern_tweak = skin_data:get_pattern_tweak(),
                pattern_pos = skin_data:get_pattern_pos(),
                sticker = skin_data:get_sticker(),
                uv_scale = skin_data:get_uv_scale(),
                uv_offset_rot = skin_data:get_uv_offset_rot(),
                cubemap_pattern_control = skin_data:get_cubemap_pattern_control(),
                types = skin_data:get_types(),
                parts = skin_data:get_parts()
            }
        end

        if config.is_a_color_skin then
            if config.color_skin_data then
                for key, value in pairs(config.color_skin_data) do
                    if type(value) == "string" then
                        config.color_skin_data[key] = Idstring(value)
                    end
                end
            end

            tweak_data.blackmarket.weapon_skins[config.id] = table.merge({
                color = Color("FF0000"),
                weapon_ids = { "akm_gold" },
                use_blacklist = true,
                is_a_unlockable = true,
                is_a_color_skin = true,
                color_skin_data = {},
                base_gradient = self._skin_design.base_gradient,
                pattern_gradient = self._skin_design.pattern_gradient,
                pattern = self._skin_design.pattern,
                pattern_tweak = self._skin_design.pattern_tweak,
                pattern_pos = self._skin_design.pattern_pos,
                sticker = self._skin_design.sticker,
                uv_scale = self._skin_design.uv_scale,
                uv_offset_rot = self._skin_design.uv_offset_rot,
                cubemap_pattern_control = self._skin_design.cubemap_pattern_control,
                types = self._skin_design.types,
                parts = self._skin_design.parts,
                default_blueprint = self._skin_attachments,
                custom = true
            }, config)

            local wcg = tweak_data.blackmarket.weapon_color_groups
            if not table.contains(wcg, config.group_id) then
                table.insert(wcg, config.group_id)
            end
            table.insert(tweak_data.blackmarket.weapon_colors, config.id)
        else
            tweak_data.blackmarket.weapon_skins[config.id] = table.merge({
                is_a_unlockable = true,
                bonus = "recoil_p1", -- Aint gonna code a "statboost" version cause nobody would care for one. It's just to fill the table.
                reserve_quality = true,
                base_gradient = self._skin_design.base_gradient,
                pattern_gradient = self._skin_design.pattern_gradient,
                pattern = self._skin_design.pattern,
                pattern_tweak = self._skin_design.pattern_tweak,
                pattern_pos = self._skin_design.pattern_pos,
                sticker = self._skin_design.sticker,
                uv_scale = self._skin_design.uv_scale,
                uv_offset_rot = self._skin_design.uv_offset_rot,
                cubemap_pattern_control = self._skin_design.cubemap_pattern_control,
                types = self._skin_design.types,
                parts = self._skin_design.parts,
                default_blueprint = self._skin_attachments,
                mod_path = self._mod.ModPath,
                custom = true
            }, config)
        end

        table.insert( tweak_data.dlc.starter_kit.content.loot_drops, {
            type_items = "weapon_skins",
            item_entry = config.id,
            global_value = config.global_value
        })
    end)
end
