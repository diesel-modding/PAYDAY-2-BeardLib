GlobalValueModule = GlobalValueModule or BeardLib:ModuleClass("GlobalValue", ItemModuleBase)

function GlobalValueModule:init(...)
    self.clean_table = table.add(clone(self.clean_table), {{param = "color", action = "normalize"}})
    return GlobalValueModule.super.init(self, ...)
end

function GlobalValueModule:RegisterHook()
    Hooks:PostHook(LootDropTweakData, "init", self._config.id .. "AddGlobalValueData", function(loot_self, tweak_data)
        if loot_self.global_values[self._config.id] and not self._config.overwrite then
            self:Err("Global value with key %s already exists! overwrite should be set to true if this is intentional.")
            return
        end

        loot_self.global_values[self._config.id] = table.merge({
            name_id = "bm_global_value_" .. self._config.id,
            desc_id = "menu_l_global_value_" .. self._config.id,
            color = Color.white,
            dlc = false,
            chance = 1,
            custom = true,
            value_multiplier = 1,
            track = false,
            sort_number = 0,
            category = not self._config.is_category and "mod",
        }, self._config)

        table.insert(loot_self.global_value_list_index, self._config.id)
        loot_self.global_value_list_map[self._config.id] = #loot_self.global_value_list_index
    end)
end