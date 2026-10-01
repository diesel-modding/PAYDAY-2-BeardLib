MenuModule = MenuModule or BeardLib:ModuleClass("Menu", ModuleBase)

function MenuModule:init(...)
    self.required_params = table.add(clone(self.required_params), {"menu"})
    return MenuModule.super.init(self, ...)
end

function MenuModule:Load()
    Hooks:Add("MenuManagerSetupCustomMenus", self._mod.Name .. "Build" .. self._name .. "Menu", function(self_menu, nodes)
        self:BuildNode(self._config.menu or self._config, nodes.lua_mod_options_menu or nodes.blt_options)
    end)
end

function MenuModule:BuildNodeItems(node, data)
    for i, sub_item in ipairs(data) do
        if sub_item._meta == "sub_menu" or sub_item._meta == "menu" then
            if sub_item.key then
                if self._mod[sub_item.key] and self._mod[sub_item.key].BuildMenu then
                    self._mod[sub_item.key]:BuildMenu(node)
                else
                    self:Err("Cannot find module of id '%s' in mod", sub_item.key)
                end
            else
                self:BuildNode(sub_item, node)
            end
        elseif sub_item._meta == "item_group" then
            if sub_item.key then
                if self._mod[sub_item.key] and self._mod[sub_item.key].InitializeNode then
                    self._mod[sub_item.key]:InitializeNode(node)
                else
                    self:Err("Cannot find module of id '%s' in mod", sub_item.key)
                end
            else
                self:Err("item_group must contain a definition for the parameter 'key'")
            end
        elseif sub_item._meta == "divider" then
            self:CreateDivider(node, sub_item)
        end
    end
end

function MenuModule:CreateDivider(parent_node, tbl)
    local merge_data = tbl.merge_data or {}
    merge_data = BeardLib.Utils:RemoveAllNumberIndexes(merge_data)
    MenuHelperPlus:AddDivider(table.merge({
        id = tbl.name,
        node = parent_node,
        size = tbl.size
    }, merge_data))
end

function MenuModule:BuildNode(node_data, parent_node)
    parent_node = node_data.parent_node and MenuHelperPlus:GetNode(node_data.parent_node) or parent_node
    local base_name = node_data.name or self._mod.Name .. self._name
    local menu_name = node_data.node_name or base_name .. "Node"

    local merge_data = node_data.merge_data or {}
    merge_data = BeardLib.Utils:RemoveAllNumberIndexes(merge_data)
    local main_node = MenuHelperPlus:NewNode(nil, table.merge({
        name = menu_name
    }, merge_data))

    self:BuildNodeItems(main_node, node_data)

    MenuHelperPlus:AddButton({
        id = base_name .. "Button",
        title = node_data.title_id or base_name .. "ButtonTitleID",
        desc = node_data.desc_id or base_name .. "ButtonDescID",
        node = parent_node,
        next_node = menu_name
    })

    managers.menu:add_back_button(main_node)
end