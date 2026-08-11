--Based off of the works by Wilko for the 'MenuHelper' in the base of BLT. Thanks to him for the basis of this code

_G.MenuHelperPlus = _G.MenuHelperPlus or {}
MenuHelperPlus.Menus = MenuHelperPlus.Menus or {}

function MenuHelperPlus:NewMenu(params)
	self.Menus = self.Menus or {}
	local callback_handler = CoreSerialize.string_to_classtable(params.callback_handler or "MenuCallbackHandler")
	self.Menus[params.id] = {
		menu_data = {
			_meta = "menues",
			[1] = {
				_meta = "menu",
				id = params.id,
				[1] = {
					_meta = "default_node",
					name = params.init_node.name
				},
				[2] = {
					_meta = "node",
					align_line = params.init_node.align_line or 0.75,
					back_callback = params.init_node.back_callback,
					gui_class = params.init_node.gui_class or "MenuNodeMainGui",
					menu_components = params.init_node.menu_components or "",
					modifier = params.init_node.modifier,
					name = params.init_node.name,
					refresh = params.init_node.refresh,
					topic_id = params.init_node.topic_id
				}
			}
		},
		register_data = {
			name = params.name,
			id = params.id,
			content_file = params.fake_path,
			callback_handler = callback_handler,
			input = params.input or "MenuInput",
			renderer = params.renderer or "MenuRenderer"
		},
		fake_path = params.fake_path
	}
	BeardLib.ScriptExceptions[Idstring(params.fake_path):key()] = BeardLib.ScriptExceptions[Idstring(params.fake_path):key()] or {}
	BeardLib.ScriptExceptions[Idstring(params.fake_path):key()][Idstring("menu"):key()] = true

	if params.init_node.legends then
		for _, legend in pairs(params.init_node.legends) do
			self:CreateAndInsertLegendData(self.Menus[params.id].menu_data[1][2], legend)
		end
	end

	if params.init_node.merge_data then
		table.merge(self.Menus[params.id].menu_data[1][2], params.init_node.merge_data)
	end

	if params.merge_data then
		table.merge(self.Menus[params.id].menu_data, params.merge_data)
	end
end

function MenuHelperPlus:NewNode(Menuname, params)
	local RegisteredMenu = managers.menu._registered_menus[Menuname or managers.menu._is_start_menu and "menu_main" or "menu_pause"]
	if not RegisteredMenu then
		return
	end
	local nodes = RegisteredMenu.logic._data._nodes

	local parameters = table.merge({
		_meta = "node",
		align_line = 0.75,
		gui_class = "MenuNodeGui",
		menu_components = "",
		stencil_align = "right",
		stencil_image = "bg_creategame",
		type = "CoreMenuNode.MenuNode",
	}, params)

	if params.legends then
		for i, legend in pairs(params.legends) do
			self:CreateAndInsertLegendData(parameters, legend)
		end
	end

	local node_class = CoreMenuNode.MenuNode
    if parameters.type then
        node_class = CoreSerialize.string_to_classtable(parameters.type)
    end
	local new_node = node_class:new(parameters)

	local callback_handler = CoreSerialize.string_to_classtable(params.callback_handler or "MenuCallbackHandler")
	new_node:set_callback_handler(params.callback_handler and callback_handler or RegisteredMenu.callback_handler)

	nodes[params.name] = new_node

    return new_node
end

function MenuHelperPlus:AddLegend(Menuid, nodename, params)
	local node = MenuHelperPlus:GetNode(Menuid, nodename)
    if not node then
        return
    end

    table.insert(node._legends, {
		string_id = params.name,
		pc = params.pc or false,
		visible_callback = params.visible_callback or nil
	})
end

function MenuHelperPlus:CreateAndInsertLegendData(nodeData, params)
	local max_val = table.maxn(nodeData)
	nodeData[max_val + 1] = {
		_meta = "legend",
		name = params.name,
		pc = params.pc or false,
		visible_callback = params.visible_callback or nil
	}
end

function MenuHelperPlus:GetNode(menu_name, node_name)
	menu_name = menu_name or managers.menu._is_start_menu and "menu_main" or "menu_pause"
	node_name = node_name or managers.menu._is_start_menu and "main" or "pause"
    return managers.menu._registered_menus[menu_name] and managers.menu._registered_menus[menu_name].logic._data._nodes[node_name] or nil
end

function MenuHelperPlus:AddButton(params)
	local node = params.node or self:GetNode(params.menu, params.node_name)
	if not node then
        (params.mod or BeardLib):Err("Unable to find node " .. tostring(params.node_name))
        return
    end

	local item = node:create_item({type = "CoreMenuItem.Item"}, table.merge({
		name = params.id,
		text_id = params.title,
		help_id = params.desc,
		callback = params.callback,
		disabled_color = params.disabled_colour or Color(0.25, 1, 1, 1),
		next_node = params.next_node,
		localize = params.localized,
		localize_help = params.localized_help,
	}, params.merge_data))

    return self:PostAdd(node, item, params)
end

function MenuHelperPlus:AddDivider(params)
    local node = params.node or self:GetNode(params.menu, params.node_name)
	if not node then
        (params.mod or BeardLib):Err("Unable to find node " .. params.node_name)
        return
    end

	local data = {
		type = "MenuItemDivider",
		size = params.size or 8,
		no_text = params.no_text or true,
	}

	local item = node:create_item(data, table.merge({
		name = params.id,
	}, params.merge_data))

    return self:PostAdd(node, item, params)
end

function MenuHelperPlus:AddToggle(params)
	local node = params.node or self:GetNode(params.menu, params.node_name)
	if not node then
        (params.mod or BeardLib):Err("Unable to find node " .. params.node_name)
        return
    end

	local data = {
		type = "CoreMenuItemToggle.ItemToggle",
		{
			_meta = "option",
			icon = "guis/textures/menu_tickbox",
			value = "on",
			x = 24,
			y = 0,
			w = 24,
			h = 24,
			s_icon = "guis/textures/menu_tickbox",
			s_x = 24,
			s_y = 24,
			s_w = 24,
			s_h = 24
		},
		{
			_meta = "option",
			icon = "guis/textures/menu_tickbox",
			value = "off",
			x = 0,
			y = 0,
			w = 24,
			h = 24,
			s_icon = "guis/textures/menu_tickbox",
			s_x = 0,
			s_y = 24,
			s_w = 24,
			s_h = 24
		}
	}

	local item = node:create_item(data, table.merge({
		name = params.id,
		text_id = params.title,
		help_id = params.desc,
		callback = params.callback,
		disabled_color = params.disabled_colour or Color(0.25, 1, 1, 1),
		icon_by_text = params.icon_by_text or false,
		localize = params.localized,
		localize_help = params.localized_help,
	}, params.merge_data))
	item:set_value(params.value and "on" or "off")

    return self:PostAdd(node, item, params)
end

function MenuHelperPlus:AddSlider(params)
	local node = params.node or self:GetNode(params.menu, params.node_name)
	if not node then
        (params.mod or BeardLib):Err("Unable to find node " .. params.node_name)
        return
    end

	local data = {
		type = "CoreMenuItemSlider.ItemSlider",
		min = params.min or math.min(params.value, 0),
		max = params.max or math.max(params.value, 10),
		step = params.step or 1,
		show_value = params.show_value or false
	}

	local item = node:create_item(data, table.merge({
		name = params.id,
		text_id = params.title,
		help_id = params.desc,
		callback = params.callback,
		disabled_color = params.disabled_colour or Color(0.25, 1, 1, 1),
		localize = params.localized,
		localize_help = params.localized_help,
	}, params.merge_data))
	item:set_value(math.clamp(params.value, data.min, data.max) or data.min)
	if params.decimal_count then
		item:set_decimal_count(params.decimal_count)
	end

    return self:PostAdd(node, item, params)
end

function MenuHelperPlus:AddMultipleChoice(params)
	local node = params.node or self:GetNode(params.menu, params.node_name)
	if not node then
        (params.mod or BeardLib):Err("Unable to find node " .. params.node_name)
        return
    end

	local data = {type = "MenuItemMultiChoice"}

	for k, v in ipairs(params.items or {}) do
		if type(v) == "table" then
			v._meta = "option"
			v.localize = NotNil(v.localize, params.localized_items)
			v.value = NotNil(v.value, k)
			table.insert(data, v)
		else
			table.insert(data, {_meta = "option", text_id = tostring(v), value = params.use_value and tostring(v) or k, localize = params.localized_items})
		end
	end

	local item = node:create_item(data, table.merge({
		name = params.id,
		text_id = params.title,
		help_id = params.desc,
		callback = params.callback,
		filter = true,
		localize = params.localized,
		localize_help = params.localized_help,
	}, params.merge_data))
	item:set_value(params.value or 1)

    return self:PostAdd(node, item, params)
end

function MenuHelperPlus:AddKeybinding(params)
	local node = params.node or self:GetNode(params.menu, params.node_name)
	if not node then
        (params.mod or BeardLib):Err("Unable to find node " .. params.node_name)
        return
    end

	local item = node:create_item({type = "MenuItemCustomizeController"}, table.merge({
		name = params.id,
		text_id = params.title,
		help_id = params.desc,
		connection_name = params.connection_name,
		binding = params.binding,
		button = params.button,
		callback = params.callback,
		localize = params.localized,
		localize_help = params.help_localized,
		is_custom_keybind = true,
	}, params.merge_data))

    return self:PostAdd(node, item, params)
end

function MenuHelperPlus:AddColorButton(params)
	local node = params.node or self:GetNode(params.menu, params.node_name)
	if not node then
        (params.mod or BeardLib):Err("Unable to find node " .. params.node_name)
        return
    end

	local item = node:create_item({type = "MenuItemColorButton"}, table.merge({
		name = params.id,
		text_id = params.title,
		help_id = params.desc,
		callback = params.callback,
		disabled_color = params.disabled_color or Color(0.25, 1, 1, 1),
		localize = params.localized,
		localize_help = params.localized_help,
	}, params.merge_data or {}))

	item:set_value(params.value or Color.white)

    return self:PostAdd(node, item, params)
end

function MenuHelperPlus:AddInput(params)
	local node = params.node or self:GetNode(params.menu, params.node_name)
	if not node then
        (params.mod or BeardLib):Err("Unable to find node " .. params.node_name)
        return
    end

	local item = node:create_item({type = "MenuItemInput"}, table.merge({
		name = params.id,
		text_id = params.title,
		help_id = params.desc,
		callback = params.callback,
		disabled_color = params.disabled_color or Color(0.25, 1, 1, 1),
		localize = params.localized,
		localize_help = params.localized_help,
	}, params.merge_data or {}))

	item:set_value(params.value or "")

    return self:PostAdd(node, item, params)
end

function MenuHelperPlus:PostAdd(node, item, params)
	item._priority = params.priority

	if params.desc and not managers.localization:modded_exists(params.desc) then
		LocalizationManager:add_localized_strings({
			[params.desc] = "",
		})
	end

	if params.disabled then
		item:set_enabled(not params.disabled)
	end

	if params.position then
        node:insert_item(item, params.position)
    else
        node:add_item(item)
    end
	return item
end

function MenuHelperPlus:GetMenus()
	return self.Menus
end

function MenuHelperPlus:GetMenuDataFromFilepath(FilePath)
	for id, Data in pairs(self.Menus) do
		if Data.fake_path == FilePath then
			return Data.menu_data
		end
	end
	return nil
end

function MenuHelperPlus:GetMenuDataFromHashedFilepath(HashedFilePath)
	if self.Menus then
		for id, Data in pairs(self.Menus) do
			if Data.fake_path:key() == HashedFilePath then
				return Data.menu_data
			end
		end
	end
	return nil
end

Hooks:Register("BeardLibMenuHelperPlusInitMenus")

Hooks:Add("BeardLibMenuHelperPlusInitMenus", "MenuHelperPlusCreateMenus", function(menu_manager)
	for id, Menu in pairs(MenuHelperPlus:GetMenus()) do
		menu_manager:register_menu(Menu.register_data)
	end
end)
