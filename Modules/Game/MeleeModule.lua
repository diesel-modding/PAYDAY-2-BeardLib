MeleeModule = MeleeModule or BeardLib:ModuleClass("Melee", ItemModuleBase)

function MeleeModule:init(...)
    self.clean_table = table.add(clone(self.clean_table), {
        {param = "vr.offsets.rotation", action = "normalize"},
        {param = "vr.offsets.left.rotation", action = "normalize"},
        {param = "vr.offsets.right.rotation", action = "normalize"},
    })
	return MeleeModule.super.init(self, ...)
end

local default_melee = "kabar"
function MeleeModule:GetBasedOn(melees, based_on)
    melees = melees or tweak_data.blackmarket.melee_weapons
    based_on = based_on or self._config.based_on
    if based_on and melees[based_on] then
        return based_on
    else
        return default_melee
    end
end

local unit_ids = Idstring("unit")
function MeleeModule:RegisterHook()
    local dlc
    local config = self._config
    config.unlock_level = config.unlock_level or 1
    Hooks:PostHook(BlackMarketTweakData, "_init_melee_weapons", config.id .. "AddMeleeData", function(bm_self)
        if bm_self.melee_weapons[config] then
            self:Err("Melee weapon with id '%s' already exists!", config)
            return
        end

        if config.guess_unit ~= false then
            config.unit = config.unit or ("units/mods/weapons/wpn_fps_mel_"..config.id.."/wpn_fps_mel_"..config.id)
            config.third_unit = config.unit
            if not DB:has(unit_ids, config.unit:id()) then
                self:Err("Unit %s of melee %s is not loaded.", tostring(config.unit), tostring(config.id))
                config.unit = nil
            end
        end

        local data = table.merge(deep_clone(bm_self.melee_weapons[self:GetBasedOn(bm_self.melee_weapons)]), table.merge({
            name_id = "bm_melee_" .. config.id,
            dlc = self.defaults.dlc,
            texture_bundle_folder = "mods",
            mod_path = self._mod.ModPath,
            custom = true,
            free = not config.unlock_level
        }, config.item or config))
        dlc = data.dlc

        bm_self.melee_weapons[config.id] = data

        if dlc then
            TweakDataHelper:ModifyTweak({config.id}, "dlc", dlc, "content", "upgrades")
        end
    end)

    Hooks:PostHook(TweakDataVR , "init", self._config.id .. "AddVRMeleeTweakData", function(vrself)
        local vr_config = self._config.vr or {}
        local id = self._config.id

        if vr_config.locked then
            vrself.locked.melee_weapons[id] = true
            return
        end

        local tweak_offsets = vrself.melee_offsets.weapons
        local offsets = tweak_offsets[self:GetBasedOn(tweak_offsets, vr_config.based_on)]

        tweak_offsets[id] = offsets and table.merge(offsets, vr_config.offsets) or vr_config.offsets or nil

        local tweak_offsets_npc = vrself.melee_offsets.weapons_npc
        local npc_offsets = tweak_offsets_npc[self:GetBasedOn(tweak_offsets_npc, vr_config.based_on)]

        tweak_offsets_npc[id] = npc_offsets and table.merge(npc_offsets, vr_config.npc_offsets) or vr_config.npc_offsets or nil
    end)


    Hooks:PostHook(UpgradesTweakData, "init", self._config.id .. "AddMeleeUpgradesData", function(u_self)
        u_self.definitions[config.id] = {
            category = "melee_weapon",
            dlc = dlc
        }
        if config.unlock_level then
            u_self.level_tree[config.unlock_level] = u_self.level_tree[config.unlock_level] or {upgrades={}, name_id="weapons"}
            table.insert(u_self.level_tree[config.unlock_level].upgrades, config.id)
        end
    end)
end