MaskModule = MaskModule or BeardLib:ModuleClass("Mask", ItemModuleBase)

function MaskModule:init(...)
    self.clean_table = table.add(clone(self.clean_table), {
        {param = "pcs", action = "no_number_indexes"},
        {param = "offsets", action = function(tbl)
            for _, v in pairs(tbl) do
                if type(v) == "table" and v[2] ~= nil then
                    v[2] = BeardLib.Utils:normalize_string_value(v[2])
                end
            end
        end}
    })
	return MaskModule.super.init(self, ...)
end

function MaskModule:RegisterHook()
    self._config.default_amount = self._config.default_amount and tonumber(self._config.default_amount) or 1
    Hooks:PostHook(BlackMarketTweakData, "_init_masks", self._config.id .. "AddMaskData", function(bm_self)
        if bm_self.masks[self._config.id] then
            self:Err("Mask with id '%s' already exists!", self._config.id)
            return
        end
        local data = table.merge({
            name_id = "bm_msk_" .. self._config.id,
            desc_id = "bm_msk_" .. self._config.id .. "_desc",
            dlc = self.defaults.dlc,
            pcs = {},
            value = 0,
			texture_bundle_folder = "mods",
            global_value = self.defaults.global_value,
            mod_path = self._mod.ModPath,
            custom = true
        }, self._config.item or self._config)
        if self._config.guess_unit ~= false then
            data.unit = data.unit or ("units/mods/masks/msk_"..self._config.id.."/msk_"..self._config.id)
        end
        bm_self.masks[self._config.id] = data
        if data.drop ~= false and data.dlc then
            TweakDataHelper:ModifyTweak({{
                type_items = "masks",
                item_entry = self._config.id,
                amount = self._config.default_amount,
                global_value = data.global_value
            }}, "dlc", data.dlc, "content", "loot_drops")
        end
    end)
end