MaskPatternModule = MaskPatternModule or BeardLib:ModuleClass("MaskPattern", ItemModuleBase)

function MaskPatternModule:init(...)
    self.clean_table = table.add(clone(self.clean_table), {{param = "pcs",action = "no_number_indexes"}})
    return MaskPatternModule.super.init(self, ...)
end

function MaskPatternModule:RegisterHook()
    self._config.default_amount = self._config.default_amount ~= nil and tonumber(self._config.default_amount) or 1
    local id = self._config.id
    Hooks:PostHook(BlackMarketTweakData, "_init_textures", id .. "AddMaskPatternData", function(bm_self)
        if bm_self.textures[id] then
            self:Err("Mask Pattern with id '%s' already exists!", id)
            return
        end
        local data = table.merge({
            name_id = "pattern_" .. id .. "_title",
            dlc = self.defaults.dlc,
            pcs = {},
			value = 0,
            texture = "units/mods/masks/shared_textures/pattern_"..id.."_df",
            texture_bundle_folder = "mods",
            global_value = self.defaults.global_value,
            mod_path = self._mod.ModPath,
            custom = true
        }, self._config)
        bm_self.textures[self._config.id] = data
        if data.dlc then
            TweakDataHelper:ModifyTweak({{
                type_items = "textures",
                item_entry = self._config.id,
                amount = self._config.default_amount,
                global_value = data.global_value
            }}, "dlc", data.dlc, "content", "loot_drops")
        end
    end)
end