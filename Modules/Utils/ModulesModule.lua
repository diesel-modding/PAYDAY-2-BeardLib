ModulesModule = ModulesModule or BeardLib:ModuleClass("Modules", ModuleBase)
ModulesModule._loose = true

function ModulesModule:Load(config, prev_dir)
	config = config or self._config
	local dir = self:GetPath(config.directory, prev_dir)
	for _, moodule in ipairs(config) do
		if moodule._meta == "module" then
			if moodule.file then
				self._mod:Dofile(Path:Combine(dir, moodule.file))
				local type_name = moodule.type_name
				local object_name = moodule.name or type_name.."Module"

				if object_name then
					if type_name then
						if _G[object_name] then
							_G[object_name].type_name = type_name
							BeardLib:RegisterModule(type_name, _G[object_name])
						else
							self:Err("'%s' tried to create module '%s' with a global class that doesn't exist!", self._mod.Name, type_name)
						end
					else
						self:Err("'%s' tried to create module '%s' without a 'type_name'!", self._mod.Name, type_name)
					end
				else
					self:Err("'%s' tried to create module with no 'name' specified!", self._mod.Name)
				end
			else
				self:Err("'%s' tried to create module with no 'file' specified!", self._mod.Name)
			end
		elseif moodule._meta == "modules" then
			self:Load(moodule, dir)
		end
	end
end