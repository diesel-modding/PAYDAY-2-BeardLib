function overwrite_meta_function(tbl, func_name, new_func)
	local old_func_name = "_" .. func_name
	local meta_table = getmetatable(tbl)

	if not meta_table[func_name] then
		log(string.format("[ERROR] Function with name '%s' could not be found in the meta table!", func_name))
		return
	end

	meta_table[old_func_name] = meta_table[old_func_name] or meta_table[func_name]
	meta_table[func_name] = new_func
end

local ids_unit = Idstring("unit")
local key_unit = ids_unit:key()
local Managers = BeardLib.Managers

overwrite_meta_function(World, "spawn_unit", function(self, unit_name, ...)
	if unit_name then
		local ukey = unit_name:key()
		if ukey == "0d8ea9bdcebaaf64" then
			Managers.File:LoadAsset(ids_unit, unit_name)
		elseif Global.fm.added_files[key_unit] then
			local file = Global.fm.added_files[key_unit][ukey]
			if file then
				Managers.File:LoadAsset(ids_unit, unit_name, file.file)
			end
		end
	end
	--STOP REPORTING THIS AS A BEARLID ISSUE PLEASE
	return self:_spawn_unit(unit_name, ...)
end)

local ids_effect = Idstring("effect")
local key_effect = ids_effect:key()
overwrite_meta_function(World:effect_manager(), "spawn", function(self, data, ...)
	if Global.fm.added_files[key_effect] then
		local file = Global.fm.added_files[key_effect][data.effect:key()]
		if file then
			Managers.File:LoadAsset(ids_effect, data.effect, file.file)
		end
	end
	return self:_spawn(data, ...)
end)

local ids_massunit = Idstring("massunit")
local key_massunit = ids_massunit:key()
overwrite_meta_function(MassUnitManager, "load", function(self, path, ...)
	if Global.fm.added_files[key_massunit] then
		local file = Global.fm.added_files[key_massunit][path:key()]
		if file then
			Managers.File:LoadAsset(ids_massunit, path, file.file)
		end
	end
	return self:_load(path, ...)
end)

overwrite_meta_function(PackageManager, "unit_data", function(self, unit_name, ...)
	if unit_name and Global.fm.added_files[key_unit] then
		local file = Global.fm.added_files[key_unit][tostring(unit_name:key())]
		if file then
			Managers.File:LoadAsset(ids_unit, unit_name, file.file)
		end
	end
	return self:_unit_data(unit_name, ...)
end)

overwrite_meta_function(PackageManager, "script_data", function(self, ext, path, name_mt)
	return Managers.File:Process(ext, path, name_mt)
end)

overwrite_meta_function(PackageManager, "has", function(self, ext, path)
    if Managers.File:Has(ext, path) or Managers.File:HasScriptMod(ext, path) then
        return true
    end

    return self:_has(ext, path)
end)

overwrite_meta_function(DB, "has", function(self, ext, path)
    if Managers.File:HasScriptMod(ext, path) then
        return true
    end

    return self:_has(ext, path)
end)

overwrite_meta_function(PackageManager, "load", function(self, pck, ...)
	if not pck then
		return true
	end

	BeardLib:DevLog("Load package: " .. tostring(pck))

	if Managers.Package:LoadPackage(pck) then
		return
	end

	return self:_load(pck, ...)
end)

overwrite_meta_function(PackageManager, "unload", function(self, pck)
	if not pck then
		return
	end

	if Managers.Package:HasPackage(pck) then
		Managers.Package:UnloadPackage(pck)
		return
	end

	return self:_unload(pck)
end)

overwrite_meta_function(PackageManager, "loaded", function(self, pck)
	if not pck then
		return false
	end

	if Managers.Package:HasPackage(pck) then
		return Managers.Package:PackageLoaded(pck)
	end

	return self:_loaded(pck)
end)

overwrite_meta_function(PackageManager, "package_exists", function(self, pck)
	if not pck then
		return false
	end

	if Managers.Package:HasPackage(pck) then
		return true
	end

	return self:_package_exists(pck)
end)