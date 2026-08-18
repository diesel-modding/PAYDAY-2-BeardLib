---@class MissionElementsModule : ModuleBase
---Adds missions elemnets to the game
---The editor taps in to allow mod creators to add their own editor class for it without needing to edit the code
MissionElementsModule = MissionElementsModule or BeardLib:ModuleClass("Elements", ModuleBase)

Hooks:Register("BeardLibAddElement")
function MissionElementsModule:Load()
    local directory = Path:Combine(self._mod.ModPath, self._config.directory)

    for _, element in ipairs(self._config) do
        if type(element) == "table" and element._meta == "element" then
            element.file = element.file or (element.name .. "Element.lua")
            self._mod:Dofile(Path:Combine(directory, element.file))
            Hooks:Call("BeardLibAddElement", self, directory, element)
        end
    end
end