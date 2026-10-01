--[[

    Maintenance by Cpone (Cpone#8463 on Discord).
    Don't spam Luffy or whatever about this shite, this is all mine.

]]

PlayerStyleModule = PlayerStyleModule or BeardLib:ModuleClass("PlayerStyle", ItemModuleBase)

function PlayerStyleModule:SetupMaterialVariant(outfit_id, outfit_data, variant_id, variant_data)
    if outfit_data.material_variations and outfit_data.material_variations[variant_id] then
        self:Err("Player Style Variant with id '%s' already exists for '%s'!", variant_id, outfit_id)
        return
    end

    outfit_data.material_variations = outfit_data.material_variations or {}
    outfit_data.material_variations[variant_id] = table.merge({
        name_id = "bm_suit_var_" .. outfit_id .. "_" .. variant_id,
        desc_id = "bm_suit_var_" .. outfit_id .. "_" .. variant_id .. "_desc",
        global_value = outfit_data.global_value or self.defaults.global_value,
        auto_aquire = true,
        custom = outfit_data.custom
    }, variant_data)

    -- Setup "default" variant just in case their isn't one.
    outfit_data.material_variations.default = table.merge({
    	name_id = "bm_suit_var_" .. outfit_id .. "_default",
    	desc_id = "bm_suit_var_" .. outfit_id .. "_default_desc",
    	global_value = outfit_data.global_value,
    	auto_aquire = true,
    	custom = outfit_data.custom
    })
end

function PlayerStyleModule:RegisterHook()
    if not self._config.id then
        self:Err("Cannot add a Player Style, no ID specified.")
        return
    end

    self._config.name_id = self._config.name_id or ("bm_suit_" .. self._config.id)
    self._config.desc_id = self._config.desc_id or self._config.name_id .. "_desc"

    -- Super simple, just takes XML and shoves it into the player style stuff, and then add some extra glove bs because overkill. :)
    Hooks:Add("BeardLibCreateCustomPlayerStyles", self._config.id .. "AddPlayerStyleTweakData", function(bm_self)
        local ps_self = bm_self.player_styles
        local config = self._config

        if ps_self[config.id] then
            self:Err("Player Style with id '%s' already exists!", config.id)
            return
        end

        -- Cleanup any variants added this way.
        if config.variations or config.material_variations then
            local stored_variants = config.variations or config.material_variations
            config.material_variations = {}

            for variant_id, variant_data in pairs(stored_variants) do
                if variant_id ~= "_meta" and type(variant_id) == "string" then
                    self:SetupMaterialVariant(config.id, config, variant_id, variant_data)
                end
            end
        end

        if config.exclude_glove_adapter then
            config.glove_adapter = false
        end
        config.default_glove_id = config.default_glove_id or config.default_gloves

        ps_self[config.id] = table.merge({
            texture_bundle_folder = "mods",
            global_value = self.defaults.global_value,
            unlocked = true,
            custom = true
        }, config)
    end)
end