--[[

    Maintenance by Cpone (Cpone#8463 on Discord).
    Don't spam Luffy or whatever about this shite, this is all mine.

]]

PlayerStyleVariantModule = PlayerStyleVariantModule or BeardLib:ModuleClass("PlayerStyleVariant", ItemModuleBase)

PlayerStyleVariantModule.SetupMaterialVariant = PlayerStyleModule.SetupMaterialVariant
function PlayerStyleVariantModule:RegisterHook()
    if not self._config.id then
        self:Err("Cannot add a Player Style Variant, no ID specified.")
        return
    end

    if not self._config.player_style_id then
        self:Err("Cannot add a Player Style Variant '%s', no Player Style ID specified.", self._config.id)
        return
    end

    -- Super simple, just takes XML and shoves it into the player style stuff.
    Hooks:Add("BeardLibCreateCustomPlayerStyleVariants", self._config.id .. self._config.player_style_id .. "AddPlayerStyleVariantTweakData", function(bm_self)
        local ps_self = bm_self.player_styles
        local config = self._config

        if not ps_self[config.player_style_id] then
            self:Err("Player Style with id '%s' doesn't exist when trying to create variant '%s'!", config.player_style_id, config.id)
            return
        end

        local outfit_data = ps_self[config.player_style_id]
        self:SetupMaterialVariant(config.player_style_id, outfit_data, self._config.id, self._config)
    end)
end