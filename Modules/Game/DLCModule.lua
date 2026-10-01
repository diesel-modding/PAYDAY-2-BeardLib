DLCModule = DLCModule or BeardLib:ModuleClass("DLC", ModuleBase)

function DLCModule:init(...)
    self.required_params = table.add(clone(self.required_params), {"id"})
	return DLCModule.super.init(self, ...)
end

function DLCModule:Load()
    TweakDataHelper:ModifyTweak(table.merge({
		free = true,
        content = {loot_drops = {}, upgrades = {}}
    }, self._config), "dlc", self._config.id)
end