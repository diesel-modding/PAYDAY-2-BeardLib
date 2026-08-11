BeardLib.Items.Item = BeardLib.Items.Item or class()
local Item = BeardLib.Items.Item
function Item:init(params)
    if params and params.menu_type then
        self:Menuify()
    end
	table.careful_merge(self, params or {})
	self.type_name = self.type_name or "Button"
	self.private = self.private or {}
	local mitem = getmetatable(self)
	function mitem:__tostring() --STOP FUCKING RESETING
		return string.format("[%s][%s] %s", self:alive() and "Alive" or "Dead", tostring(self.type_name), tostring(self.name))
	end
	self:Init()
	self:PostInit()
	self.initialized = true
	if self.MENU then --Fixes 0 items menus not being set to 0 height.
		self:AlignItemsPost(0)
	end
end

function Item:Init(params)
	if not alive(self.parent_panel) then
		return
	end

	self:WorkParams(params)

	self._hidden_by_delay = self.parent.delay_align_items

	self.panel = self.parent_panel:panel({
		name = self.name,
		layer = self.layer or 1,
		visible = not self._hidden_by_delay and self.visible or false,
		alpha = self.enabled and self.enabled_alpha or self.disabled_alpha,
		w = self.w,
		h = self.h or self.size,
	})
	self.panel:script().menuui_item = self

	self:InitBasicItem()
	if self.divider_type and alive(self.title) then
		self.title:set_world_center_y(self.panel:world_center_y())
	end
	self:Reposition()
    if self.items then
		self._list = BeardLib.Items.ContextMenu:new(self, self.parent_panel:layer() + 1000)
    end
end

function Item:PostInit()
    self:SetEnabled(self.enabled)
    self:SetVisible(self.visible)
    if self.highlight then
        self:Highlight()
    else
        self:UnHighlight()
    end
end

function Item:InitBasicItem()
	self.title = self.panel:text({
		name = "title",
		align = self.text_align,
		vertical = self.text_vertical,
		wrap = not self.size_by_text,
		word_wrap = not self.size_by_text,
		text = self.text,
		layer = 3,
		x = self:TextOffsetX(),
		color = self:GetForeground(),
		font = self.font,
		font_size = self.font_size or self.size - self.text_shrink,
		kern = self.kerning
	})
	self:InitBGs()
	self:_SetText(self.text)
	self:MakeBorder()
end

function Item:InitBasicMenu()
	self._hidden_by_delay = self.parent.delay_align_items

	self.panel = self.parent_panel:panel({
        name = self.name .. "_panel",
        w = self.w,
        h = self.h,
		visible = not self._hidden_by_delay and self.visible or false,
        layer = self.layer or 1,
	})

    self.panel:script().menuui_item = self
    self.menubg = self.panel:bitmap({
        name = "background",
        halign = "grow",
        valign = "grow",
        visible = NotNil(self.full_bg_color) or self.background_visible,
        render_template = self.background_blur and "VertexColorTexturedBlur3D",
        texture = self.background_blur and "guis/textures/test_blur_df",
        color = self.full_bg_color or self.background_color,
        alpha = self.background_alpha,
        layer = 0
    })
end

function Item:InitBGs()
	local bgc = self.unhighlight_color or self.background_color
	self.bg = self.panel:rect({
		name = "background",
		color = bgc or bgc,
		visible = bgc ~= false,
		alpha = self.highlight and 0 or 1,
		h = self.HYBRID and self.size,
		halign = "grow",
		valign = not self.HYBRID and "grow",
		layer = 2
	})
	self.highlight_bg = self.panel:rect({
		name = "highlight",
		color = self.highlight_color,
		visible = self.highlight_color ~= false,
		alpha = self.highlight and 1 or 0,
		h = self.HYBRID and self.size,
		halign = "grow",
		valign = not self.HYBRID and "grow",
		layer = 1
	})
end

function Item:MakeBorder()
	if not self:alive() then
		return
	end

	for _, v in pairs({"left", "top", "right", "bottom"}) do
		local side = self.panel:child(v)
		if alive(side) then
			self.panel:remove(side)
		end
	end

	if self.color then
		self.border_left = NotNil(self.border_left, true)
		self.border_color = NotNil(self.border_color, self.color)
		self.border_lock_height = NotNil(self.border_lock_height, true)
		self.color = nil
	end

	local opt = {
		halign = "left",
		valign = "top",
		layer = 4,
		color = self.border_color,
	}
	opt.name = "left"
	local left = self.panel:bitmap(opt)
	opt.name = "bottom"
	opt.valign = "bottom"
	local bottom = self.panel:bitmap(opt)
	opt.name = "top"
	opt.halign = "right"
	local top = self.panel:bitmap(opt)
	opt.name = "right"
	opt.valign = "bottom"
	local right = self.panel:bitmap(opt)

	local vis = self.border_visible
	local w,h = self.border_size, self.border_lock_height and self:TextHeight() or self.panel:h()
    bottom:set_size(self.border_width or self.panel:w(), w)
    right:set_size(w, self.border_height or h)
    top:set_size(self.border_width or self.panel:w(), w)
    left:set_size(w, self.border_height or h)
    bottom:set_halign("grow")
    top:set_halign("grow")
    bottom:set_visible(vis or self.border_bottom)
    left:set_visible(vis or self.border_left)
    right:set_visible(vis or self.border_right)
    top:set_visible(vis or self.border_top)

	right:set_rightbottom(self.panel:size())
	top:set_right(self.panel:w())
	bottom:set_bottom(self.panel:h())

	if self.title then
		if self.border_center_as_title then
			left:set_center_y(self.title:center_y())
			right:set_center_y(self.title:center_y())
			top:set_center_x(self.title:center_x())
			bottom:set_center_x(self.title:center_x())
		end
		if self.border_position_below_title then
			bottom:set_top(self.title:bottom())
		end
	end
end

local ids_0 = Idstring("0")

function Item:WorkParams(params)
	params = params or {}
	self.enabled = NotNil(self.enabled, true)
	self.visible = NotNil(self.visible, true)

	self:WorkParam("unhighlight_color")
	self:WorkParam("highlight_color", Color.white:with_alpha(0.1))
	self:WorkParam("context_background_color", self.background_color, Color.black)
	self:WorkParam("background_color", Color.transparent)
	self:WorkParam("full_bg_color")

	local bg, bgh
	self:WorkParam("auto_foreground")

	if self.auto_foreground then
		bg = self:GetBackground()
		bgh = self:BestAlpha(self.highlight_color, bg)
	end

	self:WorkParam("foreground")
	if self.auto_foreground and self.foreground ~= false then
		self.foreground = bg:contrast()
	end
	self:WorkParam("foreground_highlight")
	if self.auto_foreground and self.foreground_highlight ~= false then
		self.foreground_highlight = bgh:contrast()
	end

	--Bad/Old names
	self:WorkParam("items_size", 18)
	--

	self:WorkParam("size", self.items_size)
	self:WorkParam("enabled_alpha", 1)
	self:WorkParam("disabled_alpha", 0.5)
	self:WorkParam("background_alpha")
	self:WorkParam("text_align", "left")
	self:WorkParam("text_vertical", "center")
	self:WorkParam("size_by_text")
	self:WorkParam("control_slice", 0.55)
	self:WorkParam("font", tweak_data.menu.pd2_large_font or tweak_data.menu.default_font)
	self:WorkParam("border_size", 2)
	--self:WorkParam("last_y_offset")
	self:WorkParam("accent_color")
	self:WorkParam("scroll_color", self.accent_color)
	self:WorkParam("border_color", self.accent_color)
	self:WorkParam("line_color", self.accent_color)
	self.ignore_align = NotNil(self.ignore_align, false)
	self:WorkParam("localized")
	self:WorkParam("help_localized", self.localized)
	self:WorkParam("animate_colors")
	self:WorkParam("context_screen_offset_y", 32)
	self:WorkParam("context_scroll_width", self.scroll_width)
	self:WorkParam("context_font_size", 20)

	self:WorkParam("font_size")
	self:WorkParam("text_shrink", 0)

	self:WorkParam("context_text_offset")
	self:WorkParam("delay_align_items")

	self:WorkParam("click_btn", ids_0)
	self:WorkParam("fit_text")

	--Specific items
	self:WorkParam("wheel_control")
	self:WorkParam("floats")
	self:WorkParam("focus_mode")
	self:WorkParam("supports_keyboard")
	self:WorkParam("supports_mouse")
	self:WorkParam("color_dialog")
	self:WorkParam("use_alpha")
	self:WorkParam("items_localized", self.localized)
	self:WorkParam("items_uppercase")
	self:WorkParam("items_lowercase")
	self:WorkParam("items_pretty")
	self:WorkParam("bg_callbacks")
	self:WorkParam("no_slide")
	self:WorkParam("round_sliding", false)
	self:WorkParam("highlight_image")
	self:WorkParam("offset_ignore_border", true)
	self:WorkParam("img_scale")
	self:WorkParam("slider_slice", 0.7)
	self:WorkParam("textbox_max_h", 75)
	self:WorkParam("textbox_scroll_color")
	self:WorkParam("scroll_speed", 48)
	self:WorkParam("allow_expressions", true)

	if not managers.menu:is_pc_controller() then
        self.scroll_speed = self.scroll_speed * 0.5
    end

    if not self.MENU then
        self:WorkParam("align_method", "grid_from_right")
    end

	self:WorkParam("auto_align", true)

	self.name = NotNil(self.name, self.text, "")
	self.text = NotNil(self.text, self.text ~= false and self.name)

	self:WorkParamPrivate("fit_width", self.parent.align_method == nil or self.parent.align_method == "normal" or self.parent.align_method == "reversed")
	self.click_btn = self.click_btn:id()

	if not self.offset then
		self:WorkParam("offset")
	end

	if not self.text_offset then
		self:WorkParam("text_offset")
	end

	self:WorkParam("shrink_width")
	self:WorkParamLimited("max_height")
	self:WorkParamLimited("min_height")
	self:WorkParamLimited("max_width")
	self:WorkParamLimited("min_width")

	self.offset = self:ConvertOffset(self.offset)
	self.text_offset = self:ConvertOffset(self.text_offset, true) or {4,4}

	self.text_offset[1] = self.text_offset_x or self.text_offset[1]
	self.text_offset[2] = self.text_offset_y or self.text_offset[2]
	self.offset[1] = self.offset_x or self.offset[1]
	self.offset[2] = self.offset_y or self.offset[2]

	if self.inherit_values then
		if self.inherit_values.offset then
			self.inherit_values.offset = self:ConvertOffset(self.inherit_values.offset)
		end
		if self.inherit_values.text_offset then
			self.inherit_values.text_offset = self:ConvertOffset(self.inherit_values.text_offset)
		end
	end

	self:WorkParamLimited("w")
	self:WorkParamLimited("h")
	self:WorkParamLimited("border_top")
	self:WorkParamLimited("border_bottom")
	self:WorkParamLimited("border_left")
	self:WorkParamLimited("boder_right")
	self:WorkParamLimited("border_color")
	self:WorkParamLimited("border_visible")
	self:WorkParamLimited("border_size")

	if not self.initialized then
		if self.parent ~= self.menu then
			if self.w ~= "half" and (not self.w or self.fit_width) then
				self.w = (self.w or self.parent_panel:w()) - ((self.size_by_text or self.type_name == "ImageButton") and 0 or (self.offset[1] * 2))
			end
		else
			self.w = self.w or self.parent_panel:w()
			self.h = self.h or self.parent_panel:h()
		end
		if self.w == "half" then
			self.w = self.parent_panel:w() / 2
		end
		if self.shrink_width then
			self.w = self.w * self.shrink_width
			self.shrink_width = nil
		end

		self.w = math.clamp(self.w, self.min_width or 0, self.max_width or self.w)
		self.orig_h = self.h
	end

	self.should_render = true
end


function Item:DoHighlight(highlight)
	local foreground = self:GetForeground(highlight)
	if self.animate_colors then
		if self.bg then play_anim(self.bg, {set = {alpha = highlight and self.highlight_bg and self.highlight_bg:visible() and 0 or 1}}) end
		if self.highlight_bg then play_anim(self.highlight_bg, {set = {alpha = highlight and 1 or 0}}) end
		if not self.range_color then
			if self.title then play_color(self.title, foreground) end
		end
		if self.border_highlight_color then
			for _, v in pairs({"left", "top", "right", "bottom"}) do
				local side = self.panel:child(v)
				if alive(side) and side:visible() then
					play_color(side, highlight and self.border_highlight_color or self.border_color or foreground)
				end
			end
		end
	else
		if self.bg then self.bg:set_alpha(highlight and self.highlight_bg and self.highlight_bg:visible() and 0 or 1) end
		if self.highlight_bg then self.highlight_bg:set_alpha(highlight and 1 or 0) end
		if not self.range_color then
			if self.title then self.title:set_color(foreground) end
		end
		if self.border_highlight_color then
			for _, v in pairs({"left", "top", "right", "bottom"}) do
				local side = self.panel:child(v)
				if alive(side) and side:visible() then
					side:set_color(highlight and self.border_highlight_color or self.border_color or foreground)
				end
			end
		end
	end
end

function Item:Highlight()
    if not self:alive() then
        return
    end
    self:DoHighlight(true)
    managers.mouse_pointer:set_pointer_image("link")
    if self.menu._highlighted and self.menu._highlighted ~= self then
        self.menu._highlighted:UnHighlight()
    end
    self.highlight = true
    self.menu._highlighted = self
    if self.help then
        self.menu:ShowDelayedHelp(self)
    end
end

function Item:UnHighlight()
	if self.menu._highlighted == self then
		if managers.mouse_pointer.set_pointer_image then
			managers.mouse_pointer:set_pointer_image("arrow")
		end
		self.menu._highlighted = nil
	end
	self.highlight = false
	if not self:alive() then
		return
	end
	self:DoHighlight(false)
end

--Item Creation--

function Item:Create(type, ...)
    return self[type](self, ...)
end

function Item:Group(params) return self:NewItem(BeardLib.Items.Group:new(self:ConfigureItem(params, true))) end
function Item:NoteBook(params) return self:NewItem(BeardLib.Items.NoteBook:new(self:ConfigureItem(params, true))) end
function Item:PopupMenu(params) return self:NewItem(BeardLib.Items.PopupMenu:new(self:ConfigureItem(params, true))) end
function Item:Menu(params) return self:NewItem(BeardLib.Items.Menu:new(self:ConfigureItem(params, true))) end
function Item:Holder(params) return self:NewItem(BeardLib.Items.Holder:new(self:ConfigureItem(params, true))) end
function Item:TextBox(params) return self:NewItem(BeardLib.Items.TextBox:new(self:ConfigureItem(params))) end
function Item:ComboBox(params) return self:NewItem(BeardLib.Items.ComboBox:new(self:ConfigureItem(params))) end
function Item:Slider(params) return self:NewItem(BeardLib.Items.Slider:new(self:ConfigureItem(params))) end
function Item:KeyBind(params) return self:NewItem(BeardLib.Items.KeyBindItem:new(self:ConfigureItem(params))) end
function Item:Toggle(params) return self:NewItem(BeardLib.Items.Toggle:new(self:ConfigureItem(params))) end
Item.ItemsGroup = Item.Group

function Item:Grid(params)
	params.align_method = "grid"
	return self:Holder(params)
end

function Item:GridMenu(params)
	params.align_method = "grid"
	return self:Menu(params)
end

function Item:ImageButton(params)
    local w = params.w or not params.icon_h and params.size
    local h = params.h or params.icon_h or params.size
    local _params = self:ConfigureItem(params)
    _params.w = w or _params.w
    _params.h = h or _params.h or _params.size
    return self:NewItem(BeardLib.Items.ImageButton:new(_params))
end

function Item:Button(params)
	local _params = self:ConfigureItem(params)
	_params.button_type = true
	return self:NewItem(BeardLib.Items.Item:new(_params))
end

function Item:NumberBox(params)
    local _params = self:ConfigureItem(params)
    _params.type_name = "NumberBox"
    _params.filter = "number"
    return self:NewItem(BeardLib.Items.TextBox:new(_params))
end

function Item:FitButton(params)
	params.size_by_text = true
    return self:Button(params)
end

function Item:FitDivider(params)
	params.size_by_text = true
    return self:Divider(params)
end

function Item:FitText(text, params)
    return self:Divider(table.merge({text = text, size_by_text = true}, params))
end

function Item:QuickText(text, params)
    return self:Divider(table.merge({text = text}, params))
end

function Item:Divider(params)
    local _params = self:ConfigureItem(params)
    _params.divider_type = true
    return self:NewItem(BeardLib.Items.Item:new(_params))
end

function Item:ToolBar(params)
    params.text = params.text or ""
    local _params = self:ConfigureItem(params)
	_params.align_method = _params.align_method or "grid"

    return self:NewItem(BeardLib.Items.Holder:new(_params))
end

function Item:Image(params)
    params.divider_type = true
    return self:ImageButton(params)
end

function Item:DivGroup(params)
    local _params = self:ConfigureItem(params)
    _params.divider_type = true
    return self:NewItem(BeardLib.Items.Group:new(_params))
end

function Item:ConfigureItem(item, menu)
    item = clone(item)
    if type(item) ~= "table" then
        log(tostring(debug.traceback()))
        return
    end
    local inherit = NotNil(item.inherit, self)
    item.inherit = inherit
    item.parent = self
    item.menu = self.menu
    item.parent_panel = item.use_main_panel and self.panel or self:ItemsPanel()
    if type(item.index) == "string" then
        local split = string.split(item.index, "|")
        local wanted_item = self:GetItem(split[2] or split[1])
        if wanted_item then
            item.index = wanted_item:Index() + (split[1] == "After" and 1 or split[1] == "Before" and -1 or 0)
        else
            BeardLib:log("Could not create index from string, %s, %s", tostring(item.index), tostring(item))
            item.index = nil
        end
    end
    item.indx = item.indx or item.index
    item.index = nil
    return item
end

function Item:Menuify(item)
	self._my_items = self._my_items or {}
	self._reachable_items = self._reachable_items or {}
	self._visible_items = self._visible_items or {}
	self.menu_type = true
end

function Item:NewItem(item)
    if not alive(self) then
        return
    end

	if self.override_panel then
		self.override_panel:Create(self.type_name, item)
		self.override_panel = nil
		return
	end

    self:Menuify()

    if item.indx then
        table.insert(self._my_items, item.indx, item)
    else
        table.insert(self._my_items, item)
	end

    local index = #self._my_items
    if item.reachable then
        table.insert(self._reachable_items, item)
	end

    item.indx = item.indx or index
    if self.auto_align then self:_AlignItems() end
	if managers.mouse_pointer then
		item:MouseMoved(managers.mouse_pointer:world_position())
	end
    return item
end

function Item:CheckItems()
    if self.menu_type then
        self._visible_items = {}
        for _, item in pairs(self._my_items) do
            if item:TryRendering() then
                table.insert(self._visible_items, item)
            end
            if item.CheckItems then
                item:CheckItems()
            end
        end
    end
end

function Item:Destroy()
	if not self:alive() then
		return
	end
	self.parent:RemoveItem(self)
end

function Item:RemoveItem(item)
    if not item then
        return
    end
    if item.menu_type then
        item:ClearItems()
    end

    if item._list then
        item._list:Destroy()
	end

	if item == self.menu._highlighted then
		self.menu:UnHighlight()
	end

    table.delete(self._reachable_items, item)
    table.delete(self._my_items, item)
    local panel = item:Panel()
	if alive(panel) then
        panel:parent():remove(panel)
    end
    if self.auto_align then
        self:_AlignItems()
    end
end

function Item:RecreateItem(item, align_items)
    if item.list then
        item.list:parent():remove(item.list)
    end
    local panel = item:Panel()
    if alive(panel) then
        panel:parent():remove(panel)
	end
	item.parent_panel = (alive(item.parent_panel) and item.parent_panel) or item.use_main_panel and self.panel or self:ItemsPanel()
    item:Init()
    item:PostInit()
    if item.menu_type then
        item:RecreateItems()
    end
    if align_items then
        self:_AlignItems()
    end
end

function Item:RecreateItems()
	if self.menu_type then
		for _, item in pairs(self._my_items) do
			self:RecreateItem(item)
		end
	end
    self:_AlignItems()
end

function Item:ClearItems(label)
	if not self.menu_type then
		return
	end

    local temp = clone(self._my_items)
    self._my_items = {}
    self._reachable_items = {}
    for _, item in pairs(temp) do
        if not label or type(label) == "table" or item.label == label then
            self:RemoveItem(item)
        elseif item:alive() then
            table.insert(self._my_items, item)
            if item.reachable then
                table.insert(self._reachable_items, item)
            end
        end
    end
    self.menu:CheckOpenedList()
    if self.auto_align then
        self:_AlignItems()
    end
end

--Get Funcs
function Item:ItemsPanel() return self.panel end
function Item:ItemsWidth(n_items, offset)
	if not alive(self) then
		return 0
	end
	if n_items then
		offset = offset or self.inherit_values and self.inherit_values.offset or not self.private.offset and self.offset or {6, 2}
		offset = self:ConvertOffset(offset)
		return (self:ItemsPanel():w() - offset[1] * (n_items + 1))
	else
		return self:ItemsPanel():w()
	end
end

function Item:ItemsHeight(n_items, offset)
	if not alive(self) then
		return 0
	end
	if n_items then
		offset = offset or self.inherit_values and self.inherit_values.offset or not self.private.offset and self.offset or {6, 2}
		offset = self:ConvertOffset(offset)
		return (self:ItemsPanel():h() - offset[2] * (n_items+1))
	else
		return self:ItemsPanel():h()
	end
end
function Item:Items() return self._my_items end

function Item:GetItemValue(name, shallow)
	local item = self:GetItem(name, shallow)
	if item then
		return item:Value()
	else
		BeardLib:DevLog("[ERROR] GetItemValue didn't find item named %s" , name)
		return nil
	end
end

function Item:ShouldClose()
	local should_close = not ((self._textbox and self._textbox.cantype) or self.CanEdit)
	if self.menu_type then
		for _, item in pairs(self._my_items) do
			if not item:ShouldClose() then
				return false
			end
		end
	end
	return should_close
end

function Item:GetMenus(match, deep, menus)
	menus = menus or {}
	if self.menu_type then
		for _, menu in pairs(self._my_items) do
			if menu.menu_type then
				if not match or menu.name:find(match) then
					table.insert(menus, menu)
				elseif deep then
					local item = menu:GetMenus(name, true, menus)
					if item and item.name then
						return item
					end
				end
			end
		end
	end
    return menus
end

function Item:GetMenu(name, shallow)
	if self.menu_type then
		for _, menu in pairs(self._my_items) do
			if menu.menu_type then
				if menu.name == name then
					return menu
				elseif not shallow then
					local item = menu:GetMenu(name)
					if item and item.name then
						return item
					end
				end
			end
		end
	end
    return false
end

function Item:GetItem(name, shallow)
	if self.menu_type then
		for _, item in pairs(self._my_items) do
			if item.name == name then
				return item
			elseif item.menu_type and not shallow then
				local i = item:GetItem(name)
				if i then
					return i
				end
			end
		end
	end
    return nil
end

function Item:GetItemWithType(name, type, shallow)
	if self.menu_type then
		for _, item in pairs(self._my_items) do
			if item.type_name == type and item.name == name then
				return item
			elseif item.menu_type and not shallow then
				local i = item:GetItem(name)
				if i then
					return i
				end
			end
		end
	end
    return nil
end

function Item:GetItemByLabel(label, shallow)
	if self.menu_type then
		for _, item in pairs(self._my_items) do
			if item.label == label then
				return item
			elseif item.menu_type and not shallow then
				local i = item:GetItemByLabel(label)
				if i then
					return i
				end
			end
		end
	end
    return nil
end

function Item:MouseCheck(press)
	if not self:alive() or not self.enabled or not self.visible or not self.should_render or (press and self.menu._highlighted ~= self) then
		return false
	end
	return not self.divider_type, true
end

function Item:GetIndex(item)
    return table.index_of(self._my_items, item)
end

function Item:GetForeground(highlight)
	highlight = highlight or self.highlight
	local fgcolor = highlight and self.foreground_highlight or self.foreground
	return NotNil(fgcolor) or (highlight and self.highlight_color or self.unhighlight_color or self.background_color or Color.black):contrast()
end

function Item:BestAlpha(...)
	local big

	for _, c in pairs({...}) do
		if c and c.a and (not big or c.a > big.a) then
			big = c
		end
	end
	return big or Color.white
end

--Hopefully this reaches the base MenuUI and not cause a stack overflow xd
function Item:GetBackground(not_me)
	local bg = (not not_me or not self.HYBRID) and self.background_color or nil
	local context_bg = not_me and self.type_name == BeardLib.Items.PopupMenu.type_name and self.context_background_color or nil
	return self:BestAlpha(self.full_bg_color, context_bg, bg, self.parent:GetBackground(true)) or Color.black
end

function Item:ConvertOffset(offset, no_default)
	if offset then
		local t = type(offset)
        if t == "number" then
            return {offset, offset}
		elseif t == "table" then
            return {offset[1], offset[2], offset[3], offset[4]}
		end
	end
    if not no_default then
        return {6,2}
    end
end

function Item:MouseFocused(x, y)
    if not x and not y then
        x,y = managers.mouse_pointer._mouse:world_position()
    end
    return self:alive() and self.panel:inside(x,y) and self:Visible()
end

function Item:ChildrenMouseFocused(x, y, excluded_label)
    if not x and not y then
        x,y = managers.mouse_pointer._mouse:world_position()
    end
	for _, item in pairs(self._my_items) do
		if (not excluded_label or item.label ~= excluded_label) and item:MouseFocused(x,y) then
			return true
		end
	end
	return false
end

function Item:Panel() return self.panel end
function Item:Parent() return self.parent end
function Item:ParentPanel() return self.panel:parent() end
	function Item:X() return alive(self) and self:Panel():x() or 0 end
	function Item:Y() return alive(self) and self:Panel():y() or 0 end
	function Item:W() return alive(self) and self:Panel():w() or 0 end
	function Item:H() return alive(self) and self:Panel():h() or 0 end
	function Item:Left() return alive(self) and self:Panel():x() or 0 end
	function Item:Top() return alive(self) and self:Panel():y() or 0 end
	function Item:Right() return alive(self) and self:Panel():right() or 0 end
	function Item:Bottom() return alive(self) and self:Panel():bottom() or 0 end
function Item:AdoptedItems() return {} end
function Item:Position() return self.position end
function Item:XY() return {self:X(), self:Y()} end
function Item:Location() return self:XY() end
function Item:LeftTop() return {self:Left(), self:Top()}  end
function Item:LeftBottom() return {self:Left(), self:Bottom()} end
function Item:RightTop() return {self:Right(), self:Top()} end
function Item:RightBottom() return {self:Right(), self:Bottom()} end
function Item:CenterX() return alive(self) and self:Panel():center_x() or 0  end
function Item:CenterY() return alive(self) and self:Panel():center_y() or 0 end
function Item:Center() return {self:CenterX(), self:CenterY()} end
function Item:Name() return self.name end
function Item:Label() return self.label end
function Item:Text() return type(self.text) == "string" and self.text or "" end
function Item:TextValue() return self:Text() end
function Item:Height() return self:H() end
function Item:OuterHeight() return self:Height() + self:Offset()[2] end
function Item:Width() return self:W() end
function Item:OuterWidth() return self:Width() + self:Offset()[1]  end
function Item:Offset() return self.offset end
function Item:OffsetX() return self.offset[1] end
function Item:OffsetY() return self.offset[2] end
function Item:TextOffset() return self.text_offset end
function Item:TextOffsetX() return self.text_offset[1] end
function Item:TextOffsetY() return self.text_offset[2] end
function Item:alive() return alive(self.panel) end
function Item:title_alive() return type_name(self.title) == "Text" and alive(self.title) end
function Item:Value() return self.value end
function Item:Enabled() return self.enabled end
function Item:Index() return self.parent:GetIndex(self) end
function Item:MouseInside(x, y) return self.panel:inside(x,y) end
function Item:Inside(x, y) return self.panel:inside(x,y) end
function Item:Visible() return self:alive() and self.visible and self.should_render end
function Item:_Visible() return self:alive() and self.visible end
function Item:TextHeight() return self:title_alive() and self.title:bottom() + self:TextOffsetY() or 0 end
function Item:Key() return self:Panel():key() end
--Set Funcs

function Item:SetItemValue(name, ...)
	local item = self:GetItem(name)
	if item then
		item:SetValue(...)
	else
		BeardLib:DevLog("[ERROR] SetItemValue didn't find item named %s", name)
	end
end

function Item:SetLayer(layer)
    self:Panel():set_layer(layer)
    self.layer = layer
end

function Item:SetEnabledAlpha(alpha)
	self.enabled_alpha = alpha
	self:SetEnabled(self.enabled)
end

function Item:SetDisabledAlpha(alpha)
	self.disabled_alpha = alpha
	self:SetEnabled(self.enabled)
end

function Item:SetEnabled(enabled)
    self.enabled = enabled == true
	if self:alive() then
		self.panel:set_alpha(self.enabled and self.enabled_alpha or self.disabled_alpha)
	end
	if self._list then
		self._list:hide()
	end
	if not self.enabled then
		self:UnHighlight()
	end
end

function Item:SetBorder(config)
	self.border_size = NotNil(config.size, self.border_size)
	self.border_visible = NotNil(config.visible, self.border_visible)
	self.border_color = NotNil(config.color, self.border_color)
	self.border_left = NotNil(config.left, self.border_left)
	self.border_right = NotNil(config.right, self.border_right)
	self.border_top = NotNil(config.top, self.border_top)
	self.border_bottom = NotNil(config.bottom, self.border_bottom)

	self:MakeBorder()
end

function Item:SetColor(color)
	self.border_left = NotNil(self.border_left, true)
	self:SetBorder({color = color})
	self:_SetText(self.text)
end

function Item:SetHelp(help)
	self.help = help
	if self.menu._showing_help == self then
		self.menu:ShowDelayedHelp(self)
	end
end

function Item:_SetText(text)
	if self:alive() and self:title_alive() then
		local title = self.title
        self.text = text
		title:set_text(self.localized and text and managers.localization:text(text) or text)
		if self.range_color then
			for _, setting in pairs(self.range_color) do
				if #setting == 2 then
					self.title:set_range_color(setting[1], text:len(), setting[2])
				else
					self.title:set_range_color(setting[1], setting[2], setting[3])
				end
			end
		end
		local border_x = self.border_left and (self.border_height or self.border_size) or 0
		local border_y = self.border_top and (self.border_width or self.border_size) or 0
		local border_r = self.border_right and (self.border_height or self.border_size) or 0
		local border_b = self.border_bottom and (self.border_width or self.border_size) or 0
		
		if self.offset_ignore_border then
			border_x, border_y, border_r, border_b = 0,0,0,0
		end

        local offset_x = self.text_offset[1] + border_x
		local offset_y = self.text_offset[2] + border_y
		local offset_r = (self.text_offset[3] or self.text_offset[1]) + border_r
		local offset_b = (self.text_offset[4] or self.text_offset[2]) + border_b

		title:set_position(offset_x, offset_y)
		title:set_w(self.panel:w() - offset_r - offset_x)
        local _,_,w,h = title:text_rect()
        if self.SetScrollPanelSize then
            title:set_size(self.panel:w() - offset_x - offset_r, h + offset_b)
            self:SetScrollPanelSize()
            if self.HYBRID then
                self.bg:set_h(title:h())
                self.highlight_bg:set_h(self.bg:h())
            end
		else
			if self.h and not self.size_by_text then
				title:set_h(self.panel:h() - offset_y - offset_b)
			else
				title:set_h(math.clamp(h, self.min_height or 0, self.max_height or h))
				local new_h = math.max(title:bottom(), self.size) + offset_b
				if self._textbox and alive(self._textbox.panel) then
					new_h = math.max(new_h, self._textbox.panel:h())
				end
				self.panel:set_h(math.clamp(new_h, self.min_height or 0, self.max_height or new_h))
				if self.size_by_text then
					local new_w = w + offset_x + offset_r + (self.type_name == "Toggle" and self.size + offset_r or 0)
					self.panel:set_w(math.clamp(new_w, self.min_width or 0, self.max_width or new_w))
				end
			end
			title:set_w(self.panel:w() - offset_x - offset_r)
        end
		
        return true
    end
    return false
end


function Item:SetTextLight(text)
	self.text = text
	self.title:set_text(self.localized and text and managers.localization:text(text) or text)
	if self.size_by_text then
		local _,_,w,h = self.title:text_rect()
		self.title:set_size(w,h)
		self.panel:set_size(w,h)
	end
end

function Item:SetText(text)
	self:_SetText(text)
	if self.parent.auto_align then
		self.parent:_AlignItems()
	end
	self:MakeBorder()
end

function Item:GetParentParams(param)
	if self.private[param] ~= nil then
		return self.private[param]
	elseif self.inherit.inherit_values and self.inherit.inherit_values[param] ~= nil then
		return  self.inherit.inherit_values[param]
	elseif self.inherit.private[param] == nil and self.inherit[param] ~= nil then
		return  self.inherit[param]
	end
	return nil
end

-- Makes param private if it's a default value. Useful for "computed" params.
function Item:WorkParamPrivate(param, ...)
	if self[param] == nil then
		local v = self:GetParentParams(param)
		if v == nil then
			self.private[param] = true
			v = NotNil(...)
		end
		if type(v) == "table" then
			v = clone(v)
		end
		self[param] = v
	end
end

function Item:WorkParam(param, ...)
	if self[param] == nil then
		local v = self:GetParentParams(param)
		if v == nil then
			v = NotNil(...)
		end
		if type(v) == "table" then
			v = clone(v)
		end
		self[param] = v
	end
end

--For values that shouldn't directly inherit like width, height, border stuff, etc.

function Item:WorkParamLimited(param, ...)
	if self[param] == nil then
		local v
		if self.private[param] ~= nil then
			v = self.private[param]
		elseif self.inherit.inherit_values and self.inherit.inherit_values[param] ~= nil then
			v = self.inherit.inherit_values[param]
		else
			v = NotNil(...)
		end
		if type(v) == "table" then
			v = clone(v)
		end
		self[param] = v
	end
end

function Item:SetX(x) return self:Panel():set_x(x) end
function Item:SetY(y) return self:Panel():set_y(y) end
function Item:SetRight(x) return self:Panel():set_right(x) end
function Item:SetBottom(y) return self:Panel():set_bottom(y) end
function Item:SetCenterX(x) return self:Panel():set_center_x(x) end
function Item:SetCenterY(y) return self:Panel():set_center_y(y) end
function Item:SetXY(x,y) return self:Panel():set_position(x,y) end
function Item:Move(x,y) return self:Panel():move(x,y) end
function Item:SetLocation(x,y) return self:Panel():set_position(x,y) end
function Item:SetRightBottom(x,y) return self:Panel():set_rightbottom(x,y) end
function Item:SetLeftBottom(x,y) return self:Panel():set_leftbottom(x,y) end
function Item:SetRightTop(x,y) return self:Panel():set_righttop(x,y) end
function Item:SetCenter(x,y) return self:Panel():set_center(x,y) end

function Item:SetPosition(x,y)
    if type(x) == "number" or type(y) == "number" then
        self.position = {x or self.panel:x(),y or self.panel:y()}
    else
        self.position = x
    end
    self:Reposition()
end

function Item:SetPointer(state) self.menu:SetPointer(state) end
function Item:SetCallback(callback) self.on_callback = callback end
function Item:SetLabel(label) self.label = label end
function Item:SetParam(k,v) self[k] = v end

function Item:Configure(params)
	table.careful_merge(self, params)
	self.parent:RecreateItem(self, true)
end

local pos_funcs = {
    ["Left"] = function(panel) panel:set_x(0) end,
    ["Top"] = function(panel) panel:set_y(0) end,
    ["Right"] = function(panel, parent) panel:set_world_right(parent:world_right()) end,
    ["Bottom"] = function(panel, parent) panel:set_world_bottom(parent:world_bottom()) end,
    ["Centerx"] = function(panel, parent) panel:set_world_center_x(parent:world_center_x()) end,
    ["Centery"] = function(panel, parent) panel:set_world_center_y(parent:world_center_y()) end,
    ["Center"] = function(panel, parent) panel:set_world_center(parent:world_center()) end,
    ["Offsetx"] = function(panel, parent, offset) panel:move(offset[1]) end,
    ["Offset-x"] = function(panel, parent, offset) panel:move(-offset[1]) end,
    ["Offsety"] = function(panel, parent, offset) panel:move(0, offset[2]) end,
    ["Offset-y"] = function(panel, parent, offset) panel:move(0, -offset[2]) end,
    ["Offset"] = function(panel, parent, offset) panel:move(offset[1], offset[2]) end,
    ["Offset-"] = function(panel, parent, offset) panel:move(-offset[1], -offset[2]) end,
    ["Offsetx-y"] = function(panel, parent, offset) panel:move(offset[1], -offset[2]) end,
    ["Offset-xy"] = function(panel, parent, offset) panel:move(-offset[1], offset[2]) end,
}
function Item:SetPositionByString(pos)
	if not pos then
		BeardLib:log("[ERROR] Position for item %s in parent %s is nil!", tostring(self.name), tostring(self.parent.name))
		return
	end
	local panel = self.panel
	local parent_panel = self.parent_panel
	local offset = self.offset
	for p in pos:gmatch("%u%U+") do
		if pos_funcs[p] then
			pos_funcs[p](panel, parent_panel, offset)
		end
	end
end

function Item:SetValue(value, run_callback)
	if not self:alive() then
		return false
	end
	if run_callback then
		run_callback = value ~= self.value
	end
	self.value = value
	if run_callback then
		self:RunCallback()
	end
	return true
end

function Item:SetIndex(index, no_align)
	table.delete(self.parent._my_items, self)
	table.insert(self.parent._my_items, index, self)
	if not no_align and self.parent.auto_align then
		self:_AlignItems()
	end
end

--function Item:SetVisible(visible, no_align)
function Item:SetVisible(visible, animate, no_align)
    local panel = self:Panel()
    if not alive(panel) then
        return
    end
	local was_visible = self.visible

	self.visible = visible == true
	visible = visible and not self._hidden_by_menu

	if self._hidden_by_delay then
		return
	end

	local function setvisible()
		self.panel:set_visible(visible)
		if not self.visible then
			if self:Enabled() then
				self._was_enabled = self.enabled
				self:SetEnabled(visible)
			end
		elseif self._was_enabled then
			self:SetEnabled(true)
		end
		if not no_align and self.parent.auto_align then
			self.parent:_AlignItems()
		end
	end
	self.menu:CheckOpenedList()

	if animate and visible ~= was_visible then
		if visible then
			panel:set_alpha(0)
			panel:set_visible(true)
		end
		play_value(panel, "alpha", visible and 1 or 0, {time = 0.2, callback = setvisible})
	else
		setvisible()
	end
end

function Item:SetChecked(name, checked, run_callback)
	local toggle = self:GetItemWithType(name, "Toggle", true)
	if toggle then
		toggle:SetValue(checked, run_callback)
	end
end

--Events
function Item:RunCallback(clbk, ...)
	clbk = clbk or self.on_callback
	local final
	if clbk then
		final = SimpleClbk(clbk, self, ...)
	else
		final = SimpleClbk(self.callback, self.parent, self, ...)
	end

	if final then
		if self.bg_callbacks then
			table.insert(self.menu._callbacks, final)
		else
			final()
		end
	end
end

function Item:Reposition(last_positioned_item, prev_item)
	if not self:alive() then
		return false
	end
    local t = type(self.position)
    if t == "table" then
        self.panel:set_position(unpack(self.position))
    elseif t == "function" then
        self:position(last_positioned_item, prev_item)
    elseif t == "string" then
        self:SetPositionByString(self.position)
	end
    return not not self.position
end

function Item:TryRendering()
	if not self.visible or self._hidden_by_delay or self._hidden_by_menu then
		return false
	end

	local p = self.parent

	local visible = false
	if alive(self.panel) then
		local y = self.panel:world_y()
		local b = self.panel:world_bottom()

		while p ~= nil do
			--local pan = p._scroll and p._scroll:scroll_panel() or self.parent_panel
			local pan = self.parent_panel
			if p.should_render and b > pan:world_y() and y < pan:world_bottom() then
				visible = true
				if p.parent == self.menu then
					p = nil
				else
					p = p.parent
				end
			else
				visible = false
				break
			end
		end

		self.panel:set_visible(visible)
		self.should_render = visible
	end
	return visible
end

function Item:MouseReleased(b, x, y)
	if self.menu_type then
		if not self.menu._highlighted then
			self:SetPointer()
		end
		for _, item in pairs(self._my_items) do
			if item:MouseReleased(b, x, y) then
				return true
			end
		end
	end

	if self._list then
		self._list:MouseReleased(b, x, y)
	end
end

local enter_ids = Idstring("enter")
function Item:KeyPressed(o, k)
	if self.menu_type then
		if self:Enabled() and (self:MouseFocused(x, y) or self.reach_ignore_focus) then
			local dir = k == Idstring("down") and 1 or k == Idstring("up") and -1
			local h = self.menu._highlighted
			local next_item
			if dir then
				local next_index = (h and table.get_key(self._reachable_items, h) or (dir == 1 and 0 or #self._reachable_items)) + dir
				if next_index > #self._reachable_items then
					next_index = 1
				elseif next_index < 1 then
					next_index = #self._reachable_items
				end
				next_item = self._reachable_items[next_index]
			end
			if next_item then
				next_item:Highlight()
				return true
			end
		end
	end
	if k == enter_ids and self.type_name == "Button" and self.menu._highlighted == self then
		if self.menu.active_textbox then
			self.menu.active_textbox:set_active(false)
		end
		self:RunCallback()
	end
	if self.on_key_press then
		if self.menu.active_textbox then
			self.menu.active_textbox:set_active(false)
		end
		self.on_key_press(self, k)
	end
end

local mouse_1 = Idstring("1")
Item.UNCLICKABLE = 1 --null is "unknown".
Item.CLICKABLE = 2
Item.INTERRUPTED = 3
function Item:MousePressed(b, x, y)
	if self.menu_type and self:MousePressedMenuEvent(b, x, y) then
		return true
	else
		return self:MousePressedSelfEvent(b, x, y)
	end
end

function Item:MousePressedSelfEvent(button, x, y)
    if not self:MouseCheck(true) then
        return false, self.UNCLICKABLE
	end

	if self:MouseInside(x,y) then
		if self.on_click then
			if self.on_click(self, button, x, y) == false then
				return false, self.INTERRUPTED
			end
		end
		if self.button_type and button == self.click_btn then
            self:RunCallback()
			return true
		end

		local right_click = button == mouse_1
		if self._list and not self.menu._openlist then
			if (not self.open_list_key and right_click) or (self.open_list_key and button == self.open_list_key:id()) then
				self._list:show()
				self._list:update_search()
				return true
			end
		end

		if (right_click and self.on_right_click) and (not self._list or self.open_list_key ~= mouse_1) then
			self:RunCallback(self.on_right_click)
		end
		return false, self.CLICKABLE
    else
		return false
    end
end

function Item:MousePressedMenuEvent(button, x, y)
    local menu = self.menu
    if self:Enabled() then
        for _, item in pairs(self._visible_items) do
            if item:MousePressed(button, x, y) then
                return true, item
            end
        end
        if alive(self._scroll) then
            if button == Idstring("0") then
                if self._scroll:mouse_pressed(button, x, y) then
                    menu._scroll_hold = self
                    self:CheckItems()
                    return true
                end
            elseif self._scroll:is_scrollable() then
                if button == Idstring("mouse wheel down") then
                    if self._scroll:scroll(x, y, -1) then
                        if menu._highlighted and menu._highlighted.parent == self then
                            menu._highlighted:MouseMoved(x,y)
                        end
                        self:CheckItems()
                        return true
                    end
                elseif button == Idstring("mouse wheel up") then
                    if self._scroll:scroll(x, y, 1) then
                        if menu._highlighted and menu._highlighted.parent == self then
                            menu._highlighted:MouseMoved(x,y)
                        end
                        self:CheckItems()
                        return true
                    end
                end
            end
        else
            self:CheckItems()
        end
    end
    return false
end

function Item:MouseMoved(x,y)
	return (self.menu_type and self:MouseMovedMenuEvent(x,y)) or self:MouseMovedSelfEvent(x,y)
end

function Item:MouseMovedSelfEvent(x, y)
    if not self:MouseCheck() then
        return false
    end
    if not self.menu._openlist and not self.menu._slider_hold then
        if self:MouseInside(x,y) then
            self:Highlight()
            return true
        elseif not self.parent.always_highlighting then
            self:UnHighlight()
            return false
        end
    end
end

function Item:MouseMovedMenuEvent(x, y)
    if self:Enabled() then
		if alive(self._scroll) then
			local hit = self._scroll:mouse_moved(nil, x, y)
			if hit then
				self:SetPointer("hand")
				return true
			else
				self:SetPointer("arrow")
			end
		end
		if self:MouseFocused(x, y) then
			for _, item in pairs(self._visible_items) do
				if item:MouseMoved(x, y) then
					return true
				end
			end
		end
    end
    return false
end

function Item:MouseDoubleClick(button, x, y)
	if self:Enabled() then
		if self.menu_type then
			for _, item in pairs(self._visible_items) do
				if item:MouseDoubleClick(button, x, y) then
					return true
				end
			end
		end

		if not self:MouseCheck(true) then
			return false
		end

		if self:MouseInside(x,y) and self.on_double_click then
			self.on_double_click(self, button, x, y)
			return true
		end
	end
end

Item.GrowHeight = Item.AlignItems
function Item:UpdateCanvas(h) end

--Other

function Item:AlignRight(last_item)
	if last_item then
		local p = last_item:Panel()
		self:Panel():set_righttop(p:x() - self:OffsetX(), p:y())
	else
		self:SetPositionByString("RightTop")
		self:Panel():move(-self:OffsetX(), self:OffsetY())
	end
end

function Item:AlignLeft(last_item)
	if last_item then
		local p = last_item:Panel()
		self:Panel():set_position(p:x() + self:OffsetX(), p:y())
	else
		self:SetPositionByString("LeftTop")
		self:Panel():move(self:OffsetX(), self:OffsetY())
	end
end