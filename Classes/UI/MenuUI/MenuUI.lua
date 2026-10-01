MenuUI = MenuUI or class()
function MenuUI:init(params)
    local UniqueID = tostring(self)
    if not managers.gui_data then
        Hooks:Add("MenuManagerInitialize", "CreateMenuUI"..UniqueID, function()
            self:init(params)
        end)
        return
    end
    table.merge(self, params)
    self.type_name = "MenuUI"
    self.layer = self.layer or 200 --Some fucking layer that is higher than most vanilla menus
    self._ws = managers.gui_data:create_fullscreen_workspace()
	self._ws:connect_keyboard(Input:keyboard())
    tweak_data.gui.MOUSE_LAYER = 9999999999 --nothing should have a layer that is bigger than mouse tbh
    self._panel = self._ws:panel():panel({
        name = self.name or self.type_name,
        alpha = 0, layer = self.layer
    })
    self._panel:key_press(ClassClbk(self, "KeyPressed"))
    self._panel:key_release(ClassClbk(self, "KeyReleased"))

    self._panel:bitmap({
        name = "bg",
        halign = "grow",
        valign = "grow",
        visible = self.background_blur ~= nil or self.background_color ~= nil,
        render_template = self.background_blur and "VertexColorTexturedBlur3D",
        texture = self.background_blur and "guis/textures/test_blur_df",
        w = self.background_blur and self._panel:w(),
        h = self.background_blur and self._panel:h(),
        color = self.background_color,
    })

    self._help = self._panel:panel({name = "help", alpha = 0, w = self.help_width or 300})
    self.help_background_color = NotNil(self.help_background_color, Color.white)
    self._help:rect({
        name = "bg",
        halign ="grow",
        valign ="grow",
        color = self.help_background_color,
    })
    self._help:text({
        name = "text",
        font = self.help_font or tweak_data.menu.pd2_large_font,
        font_size = self.help_font_size or 16,
        layer = 2,
        wrap = true,
        word_wrap = true,
        text = "",
        color = self.help_color or Color.black
    })

    self._menus = {}
    self.private = {}
    self._callbacks = {}
    self._align_items_funcs = {}

    Hooks:Add("SetupPreUpdate", "MenuUIUpdate"..UniqueID, ClassClbk(self, "Update"))
    Hooks:Add("GameSetupPrePausedUpdate", "MenuUIUpdate"..UniqueID, ClassClbk(self, "Update"))

    BeardLib.Managers.MenuUI:AddMenu(self)

    --Deprecated values
    self.pre_key_press = self.pre_key_press or self.always_key_press
    self.pre_key_release = self.pre_key_release or self.always_key_released
    self.pre_mouse_press = self.pre_mouse_press or self.always_mouse_press
    self.pre_mouse_move = self.pre_mouse_move or self.always_mouse_move

    if self.use_default_close_key then
        self.close_key = Idstring("esc")
    end

    if self.create_items then self:create_items() end

    local enabled = self.enabled or self.visible
    if enabled then
        if managers.mouse_pointer then
            self:SetEnabled(enabled)
        else
            Hooks:Add("SetupInitManagers", "SetEnabledMenuUI"..UniqueID, function()
                self:SetEnabled(enabled)
            end)
        end
    end
end

function MenuUI:ReloadInterface(params, shallow)
    table.merge(self, params or {})
    self._panel:child("bg"):configure({
        visible = not not self.background_blur or not not self.background_color,
        render_template = self.background_blur and "VertexColorTexturedBlur3D" or "VertexColorTextured",
        texture = self.background_blur and "guis/textures/test_blur_df",
        w = self.background_blur and self._panel:w(),
        h = self.background_blur and self._panel:h(),
        color = self.background_color,
        alpha = self.background_alpha,
    })
    self._help:child("bg"):configure({
        color = self.help_background_color or self.background_color,
        alpha = self.help_background_alpha or self.background_alpha,
    })
    self._help:child("text"):configure({
        font = self.help_font or tweak_data.menu.pd2_large_font,
        font_size = self.help_font_size or 16,
        color = self.help_color or Color.black
    })
    if not shallow then
        for _, menu in pairs(self._menus) do
            menu:ReloadInterface()
        end
    end
end

function MenuUI:ShowDelayedHelp(item, force)
    BeardLib:AddDelayedCall("ShowItemHelp"..tostring(self), (force and 0 or nil) or self.show_help_time or 0.8, function()
        if not alive(item) then
            self:HideHelp()
            return
        end
        if self._showing_help and self._showing_help ~= item then
            self:HideHelp()
        end
        if self._highlighted == item then
            self._help:set_layer(item:Panel():parent():layer() + 50000)
            local help_text = self._help:child("text")
            help_text:set_w(300)
            help_text:set_text(item.help_localized and managers.localization:text(item.help) or item.help)
            local _,_,w,h  = help_text:text_rect()
            w = math.min(w, 300)
            self._help:set_size(w + 8, h + 8)
            help_text:set_shape(4, 4, w + 4, h + 4)

            local mouse = managers.mouse_pointer:mouse()
            local mouse_p = mouse:parent()
            local bottom_h = (mouse_p:world_bottom() - mouse:world_bottom())
            local top_h = (mouse:world_y() - mouse_p:world_y())
            local normal_pos = h <= bottom_h or bottom_h >= top_h
            local x_pos = mouse:world_x() + 7
            if normal_pos then
                self._help:set_world_y(mouse:world_bottom() - 5)
            else
                self._help:set_world_bottom(mouse:world_y() - 5)
            end
            if x_pos + self._help:w() < self._panel:w() + 4 then
                self._help:set_world_x(x_pos)
            else
                self._help:set_world_right(x_pos)
            end
            play_anim(self._help, {set = {alpha = 1}})
            self._showing_help = item
            self._saved_help_x = self._old_x
            self._saved_help_y = self._old_y
        end
    end, true)
end

function MenuUI:HideHelp()
    if self._showing_help then
        stop_anim(self._help)
        if alive(self._help) then
            self._help:set_alpha(0)
        end
    end
end

function MenuUI:Group(params)
    return self:AddMenu(BeardLib.Items.Group:new(self:ConfigureMenu(params)))
end

function MenuUI:DivGroup(params)
    local _params = self:ConfigureMenu(params)
    _params.divider_type = true
    return self:AddMenu(BeardLib.Items.Group:new(_params))
end

function MenuUI:Menu(params)
    return self:AddMenu(BeardLib.Items.Menu:new(self:ConfigureMenu(params)))
end

function MenuUI:Holder(params)
    return self:AddMenu(BeardLib.Items.Holder:new(self:ConfigureMenu(params)))
end

function MenuUI:NoteBook(params)
    return self:AddMenu(BeardLib.Items.NoteBook:new(self:ConfigureMenu(params)))
end

function MenuUI:PopupMenu(params)
    return self:AddMenu(BeardLib.Items.PopupMenu:new(self:ConfigureMenu(params)))
end

function MenuUI:Grid(params)
	params.align_method = "grid"
	return self:Holder(params)
end

function MenuUI:GridMenu(params)
	params.align_method = "grid"
	return self:Menu(params)
end

function MenuUI:ConfigureMenu(params)
    local _params = clone(params)
    _params.parent_panel = self._panel
    _params.parent = self
    _params.menu = self
    _params.inherit = NotNil(_params.inherit, self)
    return _params
end

function MenuUI:AddMenu(menu)
    table.insert(self._menus, menu)
    return menu
end

function MenuUI:Enabled() return self._enabled end
function MenuUI:Disabled() return not self._enabled end

function MenuUI:IsMouseActive()
	if BeardLib.Managers.MenuUI:InputDisabled() then
        return false
	end
	if self:Disabled() then
		return false
	end
    local mc = managers.mouse_pointer._mouse_callbacks
    return mc[#mc] and mc[#mc].menu_ui_object == self
end

function MenuUI:SetEnabled(enabled)
    if enabled then
        self:Enable()
    else
        self:Disable()
    end
end

function MenuUI:Enable()
    if self:Enabled() then
        return
    end
    if self.animate_toggle then
        play_anim(self._panel, {set = {alpha = 1}, time = 0.2})
    else
        self._panel:set_alpha(1)
    end
    if self.disable_player_controls and game_state_machine then
      game_state_machine:current_state():set_controller_enabled(not managers.player:player_unit())
    end
	self._enabled = true
    self._mouse_id = self._mouse_id or managers.mouse_pointer:get_id()
    local active_menu = managers.menu:active_menu()
    if active_menu and not managers.menu:is_pc_controller() then
        active_menu.input:activate_controller_mouse()
    end
	managers.mouse_pointer:use_mouse({
		mouse_move = ClassClbk(self, "MouseMoved"),
		mouse_press = ClassClbk(self, "MousePressed"),
		mouse_double_click = ClassClbk(self, "MouseDoubleClick"),
		mouse_release = ClassClbk(self, "MouseReleased"),
		id = self._mouse_id,
        menu_ui_object = self
	})
	self:RunToggleClbk()
end

function MenuUI:Disable()
    if not self:Enabled() then
        return
    end
    if self.animate_toggle then
        play_anim(self._panel, {set = {alpha = 0}, time = 0.2})
    else
        self._panel:set_alpha(0)
    end
    if self.disable_player_controls and game_state_machine then
      game_state_machine:current_state():set_controller_enabled(true)
    end
	self._enabled = false
	if self._highlighted then self._highlighted:UnHighlight() end
    self:CheckOpenedList()
    local active_menu = managers.menu:active_menu()
    if active_menu and not managers.menu:is_pc_controller() then
        active_menu.input:deactivate_controller_mouse()
    end
    managers.mouse_pointer:remove_mouse(self._mouse_id)
	BeardLib.Managers.MenuUI:CloseMenuEvent()
	self:RunToggleClbk()
end

function MenuUI:RunToggleClbk()
    if self.toggle_clbk then
        self.toggle_clbk(self, self:Enabled())
    end
end

function MenuUI:CloseLastList()
	if self._openlist then
		self._openlist:hide()
    end
end

function MenuUI:CheckOpenedList()
	if self._openlist and not self._openlist.parent:Enabled() then
		self._openlist:hide()
    end
    if self._popupmenu and not self._popupmenu:Enabled() then
        self._popupmenu:Close()
    end
end

function MenuUI:Toggle()
    if not self:Enabled() then
        self:Enable()
    elseif self:ShouldClose() then
        self:Disable()
    end
end

function MenuUI:RunCallbackNextUpdate(clbk)
    table.insert(self._callbacks, clbk)
end

function MenuUI:Update(t, dt)
    local x,y = managers.mouse_pointer:world_position()
    if self._slider_hold then self._slider_hold:SetValueByMouseXPos(x) end
    self._old_x = x
    self._old_y = y
    -- Lazy controller support
    if not managers.menu:is_pc_controller() and self:IsMouseActive()then
        if BeardLib.Utils.ControllerInput:Pressed("b") then
            self:Disable()
        elseif BeardLib.Utils.ControllerInput:Pressed("a") then
            self:MousePressed(nil, Idstring("0"), managers.mouse_pointer:world_position())
        elseif BeardLib.Utils.ControllerInput:Released("a") then
            self:MouseReleased(nil, Idstring("0"), managers.mouse_pointer:world_position())
        elseif BeardLib.Utils.ControllerInput:Pressed("x") then
            self:MousePressed(nil, Idstring("1"), managers.mouse_pointer:world_position())
        elseif BeardLib.Utils.ControllerInput:Released("x") then
            self:MouseReleased(nil, Idstring("1"), managers.mouse_pointer:world_position())
        elseif BeardLib.Utils.ControllerInput:Down("right_trigger") then
            self:MousePressed(nil, Idstring("mouse wheel down"), managers.mouse_pointer:world_position())
        elseif BeardLib.Utils.ControllerInput:Down("left_trigger") then
            self:MousePressed(nil, Idstring("mouse wheel up"), managers.mouse_pointer:world_position())
        end
    end
    if self._showing_help and (not alive(self._showing_help) or not self._showing_help:MouseInside(x, y)) then
        self:HideHelp()
	end
	if self._highlighted and not alive(self._highlighted) then
		self:UnHighlight()
		return
    end
    for _, clbk in pairs(self._callbacks) do
        clbk()
    end
    self._callbacks = {}
    for _, delayed in pairs(self._align_items_funcs) do
        delayed.clbk()
    end
    self._align_items_funcs = {}
end

function MenuUI:UnHighlight()
	self._highlighted = nil
	self:SetPointer()
end

function MenuUI:SetPointer(state)
	if managers.mouse_pointer.set_pointer_image then
		managers.mouse_pointer:set_pointer_image(state or "arrow")
	end
end

function MenuUI:InputAllowed()
    return self:Enabled() or not (managers.hud and managers.hud:chat_focus() or (managers.menu_component and managers.menu_component:input_focut_game_chat_gui()))
end

function MenuUI:KeyReleased(o, k)
    if not self:InputAllowed() then
        return
    end
    if self.pre_key_released then
        if self.pre_key_released(o, k) == false then
            return
        end
    end
    self._scroll_hold = nil
    self._key_pressed = nil
    if not self:Enabled() then
        return
    end
    if self.key_released then self.key_release(o, k) end
end

function MenuUI:MouseInside(excluded_label)
    for _, menu in pairs(self._menus) do
        if (not excluded_label or menu.label ~= excluded_label) and menu:MouseFocused() then
            return true
        end
    end
end

function MenuUI:KeyPressed(o, k)
    if not self:InputAllowed() then
        return
    end
    if self.pre_key_press then
        if self.pre_key_press(o, k) == false then
            return
        end
    end
    self._key_pressed = k
    if self.toggle_key and k == self.toggle_key:id() then
        self:toggle()
    end
	if self:IsMouseActive() then
		if self.active_textbox then
			self.active_textbox:KeyPressed(o, k)
		end

		if self._openlist then
			self._openlist:KeyPressed(o, k)
		end

        if alive(self._popupmenu) then
			self._popupmenu:KeyPressed(o, k)
        end

        if self._highlighted and self._highlighted.parent:Enabled() and self._highlighted:KeyPressed(o, k) then
            return
        end
        if self.close_key and k == self.close_key:id() then
            self:Disable()
        end
        for _, menu in pairs(self._menus) do
            if menu:KeyPressed(o, k) then
                return
            end
        end
        if self.key_press then self.key_press(o, k) end
    end
end

function MenuUI:Param(param)
    return self[param]
end

function MenuUI:SetParam(param, value)
    self[param] = value
end

function MenuUI:MouseReleased(o, button, x, y)
    if self.pre_mouse_release then
        if self.pre_mouse_release(button, x, y) == false then
            return
        end
    end

    self._scroll_hold = nil
	self._slider_hold = nil
    for _, menu in pairs(self._menus) do
        if menu:MouseReleased(button, x, y) then
            return
        end
    end
    if self.mouse_release then
        self.mouse_release(button, x, y)
    end
end

function MenuUI:MouseDoubleClick(o, button, x, y)
    if self.pre_mouse_double_click then
        if self.pre_mouse_double_click(button, x, y) == false then
            return
        end
    end
    for _, menu in pairs(self._menus) do
        if menu:MouseDoubleClick(button, x, y) then
            return
		end
	end
    if self.mouse_double_click then self.mouse_double_click(button, x, y) end
end

local scroll_up = Idstring("mouse wheel up")
local scroll_down = Idstring("mouse wheel down")

function MenuUI:MousePressed(o, button, x, y)
    if self.pre_mouse_press then
        if self.pre_mouse_press(button, x, y) == false then
            return
        end
    end

    self:HideHelp()
    if self.active_textbox and button ~= scroll_down and button ~= scroll_up then
        if self.active_textbox:MousePressed(button, x, y) then
            return
        elseif self.active_textbox then
            self.active_textbox:set_active(false)
        end
    end
    if self._openlist then
        if self._openlist.parent:Enabled() then
            if self._openlist:MousePressed(button, x, y) then
                return
            end
        else
            self._openlist:hide()
        end
    else
        if alive(self._popupmenu) then
           if self._popupmenu:MousePressed(button, x, y) then
                return
           end
        end
    	for _, menu in pairs(self._menus) do
            if menu:MouseFocused() then
        		if menu:MousePressed(button, x, y) then
                    return
        		end
            end
    	end
    end
    if self.mouse_press then self.mouse_press(button, x, y) end
end

function MenuUI:ShouldClose()
	if not self._slider_hold and not self._grabbed_scroll_bar then
		for _, menu in pairs(self._menus) do
            if not menu:ShouldClose() then
                return false
            end
		end
		return true
	end
	return false
end

function MenuUI:MouseMoved(o, x, y)
    if self._scroll_hold and alive(self._scroll_hold._scroll) then
        local scroll = self._scroll_hold._scroll
        local _, pointer = scroll:mouse_moved(nil, x, y)
        if pointer then
            if self._scroll_hold.CheckItems then
                self._scroll_hold:CheckItems()
            end
            self:SetPointer(pointer)
            return true
        else
            self:SetPointer()
        end
    end

    if self.pre_mouse_move then
        if self.pre_mouse_move(x, y) == false then
            return
        end
    end

    if self.active_textbox and not self.active_textbox:MouseMoved(x, y) then
        if self.active_textbox then
            self.active_textbox:set_active(false)
        end
    end

    if self._openlist then
        if self._openlist.parent:Enabled() then
            if self._openlist:MouseMoved(x, y) then
                return
            end
        else
            self._openlist:hide()
        end
    else
        if self._highlighted and not self._highlighted:MouseFocused() and not self._scroll_hold and not self._highlighted.parent.always_highlighting then
            self._highlighted:UnHighlight()
        else
            if alive(self._popupmenu) then
                if self._popupmenu:MouseMoved(x, y) then
                    return
                end
             end
            for _, menu in pairs(self._menus) do
                if menu:MouseMoved(x, y) then
                    return
                end
            end
        end
    end
    if self.mouse_move then self.mouse_move(x, y) end
end

function MenuUI:GetMenu(name, shallow)
    for _, menu in pairs(self._menus) do
        if menu.name == name then
            return menu
        elseif not shallow then
            local item = menu:GetMenu(name)
            if item and item.name then
                return item
            end
        end
    end
    return false
end

function MenuUI:GetItem(name, shallow)
    for _, menu in pairs(self._menus) do
        if menu.name == name then
            return menu
        elseif not shallow then
            local item = menu:GetItem(name)
            if item and item.name then
                return item
            end
        end
    end
    return false
end

function MenuUI:GetItemByLabel(label, shallow)
    for _, item in pairs(self._menus) do
        if item.label == label then
            return item
        elseif item.menu_type and not shallow then
            local i = item:GetItemByLabel(label)
            if i then
                return i
            end
        end
    end
    return nil
end

function MenuUI:Focused()
    if self:Typing() then
        return true
	end
	local x,y = managers.mouse_pointer:world_position()
	for _, menu in pairs(self._menus) do
		if menu:Visible() and menu:MouseInside(x,y) then
            return self._highlighted
        end
	end
    return false
end

function MenuUI:GetBackground()
    return self.background_color
end

function MenuUI:Typing()
    return alive(self.active_textbox) and self.active_textbox.cantype
end

function MenuUI:Destroy()
    if alive(self._ws) then
        self:Disable()
        local UniqueID = tostring(self)
        managers.gui_data:destroy_workspace(self._ws)
        BeardLib.Managers.MenuUI:RemoveMenu(self)
        Hooks:Remove("MenuUIUpdate"..UniqueID)
        Hooks:Remove("CreateMenuUI"..UniqueID)
    end
end

function MenuUI:alive()
    return alive(self._panel)
end

function MenuUI:RemoveItem(item)
    if not item then
        return
    end
    if item.menu_type then
        item:ClearItems()
    end

    if item._list then
        item._list:Destroy()
	end

	if item == self._highlighted then
		self:UnHighlight()
	end

    table.delete(self._menus, item)
    local panel = item:Panel()
	if alive(panel) then
        panel:parent():remove(panel)
    end
end

function MenuUI:ItemsWidth(n_items, offset)
	if not alive(self) then
		return 0
	end
	if n_items then
		offset = self.offset or {6, 2}
		offset = BeardLib.Items.Item.ConvertOffset(self, offset)
		return (self._panel:w() - offset[1] * n_items)
	else
		return self._panel:w()
	end
end

function MenuUI:ItemsHeight(n_items, offset)
	if not alive(self) then
		return 0
	end
	if n_items then
		offset = self.offset or {6, 2}
		offset = BeardLib.Items.Item.ConvertOffset(self, offset)
		return (self._panel:h() - offset[2] * (n_items+1))
	else
		return self._panel:h()
	end
end

function MenuUI:enable() return self:Enable() end
function MenuUI:disable() return self:Disable() end
function MenuUI:toggle() return self:Toggle() end