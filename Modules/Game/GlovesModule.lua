--[[

    Maintenance by Cpone (Cpone#8463 on Discord).
    Don't spam Luffy or whatever about this shite, this is all mine.

]]

GlovesModule = GlovesModule or BeardLib:ModuleClass("Gloves", ItemModuleBase)

function GlovesModule:init(...)
    self.clean_table = table.add(clone(self.clean_table), {
        {param = "variations", action = "remove_metas"},
        {param = "variations", action = "no_number_indexes"}
    })

    return GlovesModule.super.init(self, ...)
end

function GlovesModule:RegisterHook()
    if not self._config.id then
        self:Err("Cannot add Gloves, no ID specified.")
        return
    end

    self._config.name_id = self._config.name_id or ("bm_gloves_" .. self._config.id)
    self._config.desc_id = self._config.desc_id or self._config.name_id .. "_desc"

    -- Super simple, just takes XML and shoves it into the gloves. Piggyback off of the player style hook because I'm lazy.
    Hooks:Add("BeardLibCreateCustomPlayerStyles", self._config.id .. "AddGlovesTweakData", function(bm_self)
        local gl_self = bm_self.gloves
        local config = self._config

        if gl_self[config.id] then
            self:Err("Gloves with id '%s' already exists!", config.id)
            return
        end

        gl_self[config.id] = table.merge({
            texture_bundle_folder = "mods",
            global_value = self.defaults.global_value,
            unlocked = true,
            custom = true
        }, config)
    end)
end