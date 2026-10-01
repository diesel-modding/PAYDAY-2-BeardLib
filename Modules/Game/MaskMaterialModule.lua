MaskMaterialModule = MaskMaterialModule or BeardLib:ModuleClass("MaskMaterial", ItemModuleBase)

function MaskMaterialModule:init(...)
    self.clean_table = table.add(clone(self.clean_table), {{param = "pcs", action = "no_number_indexes"}})
    return MaskMaterialModule.super.init(self, ...)
end

function MaskMaterialModule:RegisterHook()
    self._config.default_amount = self._config.default_amount and tonumber(self._config.default_amount) or 1
    local id = self._config.id
    Hooks:PostHook(BlackMarketTweakData, "_init_materials", id .. "AddMaskMaterialData", function(bm_self)
        if bm_self.materials[id] then
            self:Err("Mask Material with id '%s' already exists!", id)
            return
        end
        local data = table.merge({
            name_id = "material_" .. id .. "_title",
            dlc = self.defaults.dlc or "mods",
            value = 0,
            texture = "units/mods/matcaps/"..id.."_df",
            texture_bundle_folder = self._config.ver == 2 and "mods" or nil,
            global_value = self.defaults.global_value,
            mod_path = self._mod.ModPath,
            custom = true
        }, self._config.item or self._config)
        bm_self.materials[id] = data
        if data.dlc then
            TweakDataHelper:ModifyTweak({{
                type_items = "materials",
                item_entry = id,
                amount = self._config.default_amount,
                global_value = data.global_value
            }}, "dlc", data.dlc, "content", "loot_drops")
        end
    end)
end