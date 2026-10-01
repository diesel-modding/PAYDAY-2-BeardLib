CrimeSpreeMissionModule = CrimeSpreeMissionModule or BeardLib:ModuleClass("CrimeSpreeMission", ItemModuleBase)

function CrimeSpreeMissionModule:AddMissionDataToTweak(c_self, tweak_data)
    local icon = self._config.icon and "mods_"..Path:GetFileNameWithoutExtension(self._config.icon)
    if icon then
        tweak_data.hud_icons[icon] = {texture = self._config.icon, texture_rect = self._config.icon_rect or false, custom = true}
    end
    local data = {
        id = self._config.id,
        add = self._config.add or 7,
        icon = icon or "pd2_question",
        level = tweak_data.narrative.stages[self._config.level],
        mod_path = self._mod.ModPath,
        custom = true
    }
    if self._config.merge_data then
        table.merge(data, BeardLib.Utils:RemoveMetas(self._config.merge_data, true))
    end
    local types = {["short"] = 1, ["medium"] = 2, ["long"] = 3} -- I guess
    table.insert(c_self.missions[types[self._config.type or "medium"]], data)
end

function CrimeSpreeMissionModule:RegisterHook()
    if tweak_data and tweak_data.crime_spree then
        self:AddMissionDataToTweak(tweak_data.crime_spree, tweak_data)
    else
        Hooks:PostHook(CrimeSpreeTweakData, "init_missions", self._config.id .. "AddMissionData", ClassClbk(self, "AddMissionDataToTweak"))
    end
end