WeaponSkinExtension = WeaponSkinExtension or class()
WeaponSkinExtension.TEXTURE_FILE_TYPE = "texture"

function WeaponSkinExtension:init(asset_path, skin_id)
    if not asset_path or not SystemFS:exists(asset_path) then
        BeardLib:Err("[WeaponSkinModule] Asset directory at '%s' doesn't exist.", asset_path)
        return
    end

    self._id = skin_id
    self._item = UGCItem:new(asset_path)
    self._item:load()
    self._path = self._item:path()
    self:load_assets()
end

function WeaponSkinExtension:load_assets()
    local textures = {}

    if self._path then
        for k, dir in pairs(FileIO:GetFolders(self._path)) do
            for _, file in pairs(FileIO:GetFiles(self._path .. dir)) do
                local game_path = string.gsub(self._path .. dir .. "/" .. file, ".tga", "")
                if not DB:has(Idstring(WeaponSkinExtension.TEXTURE_FILE_TYPE), game_path) then
                    table.insert(textures, Idstring(game_path))
                    DB:create_entry(Idstring(WeaponSkinExtension.TEXTURE_FILE_TYPE), Idstring(game_path), self._path .. dir .. "/" .. file)
                end
            end
        end
    end

    if #textures > 0 then
        Application:reload_textures(textures)
    end
end

function WeaponSkinExtension:get_base_gradient()
    if not self._item:config().data.base_gradient_name then
        return nil
    end

    return string.gsub(self._path .. "base_gradient/" .. self._item:config().data.base_gradient_name, ".tga", "")
end

function WeaponSkinExtension:get_pattern_gradient()
    if not self._item:config().data.pattern_gradient_name then
        return nil
    end

    return string.gsub(self._path .. "pattern_gradient/" .. self._item:config().data.pattern_gradient_name, ".tga", "")
end

function WeaponSkinExtension:get_pattern()
    if not self._item:config().data.pattern_name then
        return nil
    end

    return string.gsub(self._path .. "pattern/" .. self._item:config().data.pattern_name, ".tga", "")
end

function WeaponSkinExtension:get_sticker()
    if not self._item:config().data.sticker_name then
        return nil
    end

    return string.gsub(self._path .. "sticker/" .. self._item:config().data.sticker_name, ".tga", "")
end

function WeaponSkinExtension:get_pattern_tweak()
    return self._item:config().data.pattern_tweak
end

function WeaponSkinExtension:get_pattern_pos()
    return self._item:config().data.pattern_pos
end

function WeaponSkinExtension:get_uv_scale()
    return self._item:config().data.uv_scale
end

function WeaponSkinExtension:get_uv_offset_rot()
    return self._item:config().data.uv_offset_rot
end

function WeaponSkinExtension:get_cubemap_pattern_control()
    return self._item:config().data.cubemap_pattern_control
end

function WeaponSkinExtension:get_types()
    if not self._item:config().data.types then
        return nil
    end

    for k, table in pairs(self._item:config().data.types) do
        for key, data in pairs(table) do
            if key == "base_gradient_name" or key == "pattern_gradient_name" or key == "pattern_name" or key == "sticker_name" then
                local texture_name = string.gsub(data, ".tga", "")
                local texture_folder = string.gsub(key, "_name", "")
                self._item:config().data.types[k][texture_folder] = self._path .. texture_folder .. "/" .. texture_name
            end
        end
    end

    return self._item:config().data.types
end

function WeaponSkinExtension:get_parts()
    if not self._item:config().data.parts then
        return nil
    end

    for kay, table in pairs(self._item:config().data.parts) do
        for k, ids in pairs(table) do
            for key, data in pairs(ids) do
                if key == "base_gradient_name" or key == "pattern_gradient_name" or key == "pattern_name" or key == "sticker_name" then
                    local texture_name = string.gsub(data, ".tga", "")
                    local texture_folder = string.gsub(key, "_name", "")
                    self._item:config().data.parts[kay][k][texture_folder] = self._path .. texture_folder .. "/" .. texture_name
                end
            end
        end
    end

    return self._item:config().data.parts
end