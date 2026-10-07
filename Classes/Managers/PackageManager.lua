BeardLibPackageManager = BeardLibPackageManager or BeardLib:ManagerClass("Package")
Global.cmp = Global.cmp or {custom_loaded_packages = {}}

local Managers = BeardLib.Managers

function BeardLibPackageManager:init()
    self.custom_packages = {}
    self.unload_on_restart = {}
    self.unload_on_restart_packages = {}

     -- Deprecated, try not to use.
    CustomPackageManager = self
    BeardLib.managers.package = self
end

function BeardLibPackageManager:RegisterPackage(id, directory, config)
    local schema = {
        func_name = "BeardLibPackageManager:RegisterPackage",
        params = {
            {type="string", allow_nil = false},
            {type="string", allow_nil = false},
            {type="table", allow_nil = false}
        }
    }
    if not BeardLib.Utils:CheckParamsValidity({id, directory, config}, schema) then
        return false
    end

    local id_key = id:key()
    if self.custom_packages[id_key] then
        self:Err("Package with ID '%s' already exists! Returning...", id)
        return false
    end

    self.custom_packages[id_key] = {dir = directory, config = config, id = id}

    return true
end

function BeardLibPackageManager:LoadPackage(id)
    id = id:key()
    if self.custom_packages[id] then
        local pck = self.custom_packages[id]
        self:LoadConfig(pck.dir, pck.config)
        Global.cmp.custom_loaded_packages[id] = true
        return true
    end
    return false
end

function BeardLibPackageManager:UnloadPackage(id)
    id = id:key()
    if self.custom_packages[id] then
        local pck = self.custom_packages[id]
        self:UnloadConfig(pck.config)
        Global.cmp.custom_loaded_packages[id] = false
        return true
    end
    return false
end

function BeardLibPackageManager:PackageLoaded(id)
    return Global.cmp.custom_loaded_packages[id:key()]
end

function BeardLibPackageManager:HasPackage(id)
    return not not self.custom_packages[id:key()]
end

local UNIT_LOAD = "unit_load"
local ADD = "add"

local UNIT = "unit"
local MODEL = "model"
local OBJECT = "object"
local TEXTURE = "texture"
local MAT_CONFIG = "material_config"
local SEQ_MANAGER = "sequence_manager"
local COOKED_PHYSICS = "cooked_physics"

local UNIT_IDS = UNIT:id()
local MODEL_IDS = MODEL:id()
local OBJECT_IDS = OBJECT:id()
local TEXTURE_IDS = TEXTURE:id()
local MAT_CONFIG_IDS = MAT_CONFIG:id()
local SEQ_MANAGER_IDS = SEQ_MANAGER:id()
local COOKED_PHYSICS_IDS = COOKED_PHYSICS:id()

--Default: unit, cooked phyiscs, model, object.

--tex: Adds material_config and textures.
--mat: Adds material_config.
--mat_seq: Adds material_config and sequence_manager.
--seq: Adds material_config, textures and sequence_manager.
--obj_seq: Adds sequence manager.
--obj: Adds nothing.

--thq: Adds _thq, material config and textures.
--mat_thq: Adds _thq and material_config.
--npc: Adds _npc unit.
--cc: Adds _thq, _cc, _cc_thq material_config, textures and cc texture.
--mat_cc: Adds _thq, _cc, _cc_thq and material_config.

BeardLibPackageManager.UNIT_SHORTCUTS = {
    unit_obj = {},
    unit_tex = {texture = {"_df", "_nm"}, material_config = true},
    unit_mat = {material_config = true},
    unit_seq = {sequence_manager = true, material_config = true, texture = {"_df", "_nm"}},
    unit_mat_seq = {sequence_manager = true, material_config = true},
    unit_thq = {material_config = {"_thq"}, texture = {"_df", "_nm"}},
    unit_npc = {unit = {"_npc"}},
    unit_cc = {material_config = {"_thq", "_cc", "_cc_thq"}, texture = {"_df", "_nm", "_df_cc"}},
    unit_mat_cc = {material_config = {"_thq", "_cc", "_cc_thq"}},
    unit_mat_thq = {material_config = {"_thq"}},
    unit_obj_seq = {sequence_manager = true}
}

BeardLibPackageManager.TEXTURE_SHORTCUTS = {
    df_nm = {"_df", "_nm"},
    df_op = {"_df", "_op"},
    df_il = {"_df", "_il"},
    df_nm_mask = {"_df", "_nm", "_mask"},
    df_nm_il = {"_df", "_nm", "_il"},
    df_nm_op = {"_df", "_nm", "_op"},
    df_nm_cc = {"_df", "_nm", "_df_cc"},
    df_nm_cc_gsma = {"_df", "_nm", "_df_cc", "_gsma"},
    df_nm_gsma = {"_df", "_nm", "_gsma"},
    df_nm_gsma_op = {"_df", "_nm", "_gsma", "_op"},
    df_nm_gsma_il = {"_df", "_nm", "_gsma", "_il"},
}

BeardLibPackageManager.EXT_CONVERT = {dds = "texture", png = "texture", tga = "texture", jpg = "texture", bik = "movie"}

local CP_DEFAULT = BeardLib:GetPath() .. "Assets/units/default_cp.cooked_physics"
function BeardLibPackageManager:LoadConfig(directory, config, mod, settings)
    local skip_use_clbk, temp = false, false
    if type(settings) == "table" then
        skip_use_clbk = settings.skip_use_clbk
        temp = settings.temp
    end

    if not skip_use_clbk then
        local use_clbk = config.use_clbk or config.load_clbk
        if use_clbk and mod then
            use_clbk = mod:StringToCallback(use_clbk) or nil
        end
        if use_clbk and type(use_clbk) == "function" and not use_clbk(config) then
            return
        end
    end

    local game = BeardLib:GetGame() or "pd2"

    local loading = {}
    for _, child in ipairs(config) do
        if type(child) == "table" then
            local typ = child._meta
            local path = child.path
            local use_clbk = child.use_clbk or child.load_clbk
            local c_game = child.game or config.game

            if use_clbk and mod then
                use_clbk = mod:StringToCallback(use_clbk) or nil
            end

            if (not c_game or c_game == game) and (not use_clbk or use_clbk(path, typ)) then
                if typ == UNIT_LOAD or typ == ADD then
                    local next_dir = child.directory and Path:Combine(directory, child.directory) or directory
                    self:LoadConfig(next_dir, child, mod, {
                        skip_use_clbk = true,
                        temp = temp
                    })
                elseif BeardLibPackageManager.UNIT_SHORTCUTS[typ] then
                    self:LoadConfigUnitShortcutNode(child, directory, config)
                elseif BeardLibPackageManager.TEXTURE_SHORTCUTS[typ] then
                    self:LoadConfigTextureShortcutNode(child, directory, config)
                elseif typ and path then
                    self:LoadConfigNode(child, directory, config, loading)
                elseif typ ~= "auto_generate" then
                    self:Err("Node in %s does not contain a definition for both type and path", tostring(directory))
                end
            end
        end
    end

    if temp and not skip_use_clbk then
        table.insert(self.unload_on_restart, config)
    end

    -- Since added files could contain dependecies that aren't loaded yet,
    -- we want to ensure they are first all added and then try to dyn resource load them
    for _, file in pairs(loading) do
        Managers.File:LoadAsset(unpack(file))
    end
end

function BeardLibPackageManager:LoadConfigNode(node, directory, config, loading)
    local typ = node._meta
    local path = node.path
    local ingame = Global.level_data and Global.level_data.level_id ~= nil
    local inmenu = not ingame
    local from_db = NotNil(node.from_db, config.from_db)
    local script_data_type = NotNil(node.script_data_type, config.script_data_type)

    path = Path:Normalize(path) or path
    local ids_ext = Idstring(BeardLibPackageManager.EXT_CONVERT[typ] or typ)
    local inner_directory = config.inner_directory
    local ids_path = inner_directory and Idstring(Path:Combine(inner_directory, path)) or Idstring(path)
    local file_path = node.full_path or Path:Combine(directory, config.file_path or path)
    local file_path_ext = file_path.."."..typ
    local auto_cp = NotNil(node.auto_cp, config.auto_cp, false)
    local force = NotNil(node.force, config.force, true)
    local reload = NotNil(node.reload, config.reload, false)
    node.unload = NotNil(node.unload, config.unload, true)
    local dyn_load_game = NotNil(node.load_in_game, config.load_in_game, false)
    local dyn_load_menu = NotNil(node.load_in_menu, config.load_in_menu, false)
    local dyn_load = NotNil(node.load, config.load, false)

    local is_unit = ids_ext == UNIT_IDS
    local language
    if typ == "bnk" and from_db and not DB:has(path, typ) then 
        language = "english" -- has_file requires language for localized soundbanks. As of U240.6, base game soundbanks are only in english.
    end

    if (from_db and DB:has(typ, path, language and {language = language})) or (not from_db and FileIO:Exists(file_path_ext)) then
        local load = force
        if not load then
            local force_if_not_loaded = NotNil(node.force_if_not_loaded, config.force_if_not_loaded, false)
            if force_if_not_loaded then
                load = not PackageManager:has(ids_ext, ids_path)
            else
                load = not DB:has(ids_ext, ids_path)
            end
        end
        if load then
            if is_unit then
                if node.include_default then --Old
                    Managers.File:AddFileWithCheck(MODEL_IDS, ids_path, file_path.."."..MODEL)
                    Managers.File:AddFileWithCheck(OBJECT_IDS, ids_path, file_path.."."..OBJECT)
                    Managers.File:AddFileWithCheck(MAT_CONFIG_IDS, ids_path, file_path.."."..MAT_CONFIG)
                    Managers.File:AddFile(COOKED_PHYSICS_IDS, ids_path, CP_DEFAULT)
                end
                if auto_cp then
                    Managers.File:AddFile(COOKED_PHYSICS_IDS, ids_path, CP_DEFAULT)
                end
            end

            if typ == "bnk" and not DB:has(ids_ext, ids_path) then
                if blt.asset_db.register_custom_soundbank then
                    blt.asset_db.register_custom_soundbank(path)
                end
            end
            if typ == "stream" and not DB:has(ids_ext, ids_path) then
                if blt.asset_db.register_custom_streamed_wem then
                    local wem_id = node.wem_id or path:match("[^/]*$")

                    if wem_id then
                    blt.asset_db.register_custom_streamed_wem(wem_id, path)
                    end
                end
            end

            if from_db then
                Managers.File:LoadFileFromDB(typ, path)
            elseif script_data_type then
                Managers.File:ScriptReplaceFile(ids_ext, ids_path, file_path_ext, {type = script_data_type, add = true})
            else
                Managers.File:AddFile(ids_ext, ids_path, file_path_ext)
            end
            if reload then
                PackageManager:reload(ids_ext, ids_path)
            end
            if dyn_load or (dyn_load_game and ingame) or (dyn_load_menu and not inmenu) then
                table.insert(loading, {ids_ext, ids_path, file_path_ext})
            end
            if node.early_load then
                Managers.File:ForceEarlyLoad(ids_ext, ids_path, file_path_ext)
            end
        end
    elseif from_db then
        self:Err("File does not exist in database! %s", tostring(path))
    else
        self:Err("File does not exist! %s", tostring(file_path_ext))
    end
end

function BeardLibPackageManager:LoadConfigUnitShortcutNode(node, directory, config)
    local typ = node._meta
    local path = node.path
    local ids_path = path:id()

    local file_path = node.full_path or Path:Combine(directory, node.file_path or path)
    local auto_cp = NotNil(node.auto_cp, config.auto_cp, true)
    self:AddFileWithCheck(UNIT_IDS, ids_path, file_path.."."..UNIT)
    if auto_cp then
        self:AddFileWithCheck(COOKED_PHYSICS_IDS, ids_path, CP_DEFAULT)
    end

    self:AddFileWithCheck(MODEL_IDS, ids_path, file_path.."."..MODEL)
    self:AddFileWithCheck(OBJECT_IDS, ids_path, file_path.."."..OBJECT)

    for load_type, load in pairs(BeardLibPackageManager.UNIT_SHORTCUTS[typ]) do
        local type_ids = load_type:id()
        if load_type ~= TEXTURE then
            self:AddFileWithCheck(type_ids, ids_path, file_path.."."..load_type)
        end
        if type(load) == "table" then
            for _, suffix in pairs(load) do
                self:AddFileWithCheck(type_ids, Idstring(path..suffix), file_path..suffix.."."..load_type)
            end
        end
    end
end

function BeardLibPackageManager:LoadConfigTextureShortcutNode(node, directory, config)
    local typ = node._meta
    local path = node.path

    path = Path:Normalize(path)
    local file_path = node.full_path or Path:Combine(directory, config.file_path or path)
    for _, suffix in pairs(BeardLibPackageManager.TEXTURE_SHORTCUTS[typ]) do
        Managers.File:AddFileWithCheck(TEXTURE_IDS, Idstring(path..suffix), file_path..suffix.."."..TEXTURE)
    end
end

function BeardLibPackageManager:LoadPackageConfig(directory, config, temp, skip_use_clbk)
    self:LoadConfig(directory, config, nil, {temp = temp, skip_use_clbk = skip_use_clbk})
end

function BeardLibPackageManager:Err(...)
    BeardLib:Err(...)
end

function BeardLibPackageManager:AddFileWithCheck(ext, path, file)
	if FileIO:Exists(file) then
		Managers.File:AddFile(ext, path, file)
	else
		self:Err("File does not exist! %s", tostring(file))
	end
end

function BeardLibPackageManager:UnloadConfig(config)
    for _, child in ipairs(config) do
        if type(child) == "table" then
            local typ = child._meta
            local path = child.path

            if typ == UNIT_LOAD or typ == ADD then
                self:UnloadConfig(child)
            elseif BeardLibPackageManager.UNIT_SHORTCUTS[typ] then
                self:UnloadConfigUnitShortcutNode(child, config)
            elseif BeardLibPackageManager.TEXTURE_SHORTCUTS[typ] then
                self:UnloadConfigTextureShortcutNode(child, config)
            elseif typ and path then
                self:UnloadConfigNode(child)
            else
                self:Err("Some node does not contain a definition for both type and path")
            end
        end
    end
end

function BeardLibPackageManager:UnloadConfigUnitShortcutNode(node, config)
    local typ = node._meta
    local path = node.path
    local ids_path = Idstring(path)
    local auto_cp = NotNil(node.auto_cp, node.auto_cp, true)

    path = Path:Normalize(path) or path

    local function unload(ids_ext, ids_path)
        if DB:has(ids_ext, ids_path) then
            if node.unload ~= false then
                Managers.File:UnloadAsset(ids_ext, ids_path)
            end
            Managers.File:RemoveFile(ids_ext, ids_path)
        end
    end

    unload(UNIT_IDS, ids_path)
    if auto_cp then
        unload(COOKED_PHYSICS_IDS, ids_path)
    end

    unload(MODEL_IDS, ids_path)
    unload(OBJECT_IDS, ids_path)

    for load_type, load in pairs(BeardLibPackageManager.UNIT_SHORTCUTS[typ]) do
        local type_ids = load_type:id()
        if load_type ~= TEXTURE then
            unload(type_ids, Idstring(path))
        end
        if type(load) == "table" then
            for _, suffix in pairs(load) do
                unload(type_ids, Idstring(path..suffix))
            end
        end
    end
end

function BeardLibPackageManager:UnloadConfigTextureShortcutNode(node, config)
    local typ = node._meta
    local path = node.path

    path = Path:Normalize(path) or path

    for _, suffix in pairs(BeardLibPackageManager.TEXTURE_SHORTCUTS[typ]) do
        local ids_path = Idstring(path..suffix)
        if DB:has(TEXTURE_IDS, ids_path) then
            if node.unload ~= false then
                Managers.File:UnloadAsset(TEXTURE_IDS, ids_path)
            end
            Managers.File:RemoveFile(TEXTURE_IDS, ids_path)
        end
    end
end

function BeardLibPackageManager:UnloadConfigNode(node, config)
    local typ = node._meta
    local path = node.path

    path = Path:Normalize(path) or path

    if typ == "bnk" and blt.asset_db.unregister_custom_soundbank then
        blt.asset_db.unregister_custom_soundbank(path)
    end
    if typ == "stream" and blt.asset_db.unregister_custom_streamed_wem then
        local wem_id = node.wem_id or path:match("[^/]*$")
        if wem_id then
        blt.asset_db.unregister_custom_streamed_wem(wem_id)
        end
    end
    local ids_ext = Idstring(self.EXT_CONVERT[typ] or typ)
    local ids_path = Idstring(path)
    if DB:has(ids_ext, ids_path) then
        if node.unload ~= false then
            Managers.File:UnloadAsset(ids_ext, ids_path)
        end
        Managers.File:RemoveFile(ids_ext, ids_path)
    end
end

BeardLibPackageManager.UnloadPackageConfig = BeardLibPackageManager.UnloadConfig

--- Registers a package to unload on restart
---@param package PackageModule
function BeardLibPackageManager:AddUnloadOnRestart(package)
    table.insert(self.unload_on_restart_packages, package)
end

--- Unregisters a package that was supposed to unload on restart
---@param package PackageModule
function BeardLibPackageManager:RemoveUnloadOnRestart(package)
    table.delete(self.unload_on_restart_packages, package)
end

function BeardLibPackageManager:Unload()
    for _, v in pairs(self.unload_on_restart) do
        self:UnloadConfig(v)
    end

    for _, package in pairs(self.unload_on_restart_packages) do
        package:Unload()
    end
end