QuickMenuPlus = QuickMenuPlus or class(QuickMenu)
QuickMenuPlus._menu_id_key = "quick_menu_p_id_"
QuickMenuPlus._menu_id_index = 0
function QuickMenuPlus:new( ... )
    return self:init( ... )
end

function QuickMenuPlus:init(title, text, options, dialog_merge)
    options = options or {}
    for _, opt in pairs(options) do
        if not opt.callback then
            opt.is_cancel_button = true
        end
    end
    QuickMenuPlus.super.init(self, title, text, options)
    if dialog_merge then
        table.merge(self.dialog_data, dialog_merge)
    end
    self.show = nil
    self.Show = nil
    self.visible = true
    managers.system_menu:show_custom(self.dialog_data)
    return self
end
