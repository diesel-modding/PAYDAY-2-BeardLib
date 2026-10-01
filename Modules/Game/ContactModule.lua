ContactModule = ContactModule or BeardLib:ModuleClass("contact", ItemModuleBase)
ContactModule._loose = true

BeardLib:RegisterModule("Contact", ContactModule)

function ContactModule:AddContactData(narr_self)
    if not self._config.id then
        self:Err("Contact does not contain a definition for id!")
        return
    end
    if not self.force and narr_self.contacts[self._config.id] then
        return
    end

    local data = {
        name_id = self._config.name_id,
        description_id = self._config.desc_id,
        package = self._config.package,
        assets_gui = self._config.assets_gui and self._config.assets_gui:id(),
        hidden = self._config.hidden
    }
    if self._config.merge_data then
        table.merge(data, BeardLib.Utils:RemoveMetas(self._config.merge_data, true))
    end
    narr_self.contacts[self._config.id] = data
end

function ContactModule:RegisterHook()
    if tweak_data and tweak_data.narrative then
        self:AddContactData(tweak_data.narrative)
    else
        Hooks:PostHook(NarrativeTweakData, "init", self._config.id .. "AddContactData", ClassClbk(self, "AddContactData"))
    end
end