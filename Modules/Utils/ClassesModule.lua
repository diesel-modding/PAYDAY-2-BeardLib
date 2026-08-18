ClassesModule = ClassesModule or BeardLib:ModuleClass("Classes", ModuleBase)
ClassesModule.type_name = "Classes"

function ClassesModule:Load(config, prev_dir)
	config = config or self._config

    local dir = self:GetPath(config.directory, prev_dir)
    for _, c in ipairs(config) do
        if not c.game or (BeardLib:GetGame() or "pd2") == c.game then
            if c._meta == "class" then
                local class_file = Path:Combine(dir, c.file)
                if FileIO:Exists(class_file) then
                    self._mod:Dofile(class_file)
                else
                    self:Err("Class file not readable by the lua state! File: %s", class_file)
                end
            elseif c._meta == "classes" then
                self:Load(c, dir)
            end
        end
    end
end