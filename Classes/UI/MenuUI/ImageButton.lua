BeardLib.Items.ImageButton = BeardLib.Items.ImageButton or class(BeardLib.Items.Item)
local ImageButton = BeardLib.Items.ImageButton
ImageButton.type_name = "ImageButton"
ImageButton.IMG = true
function ImageButton:InitBasicItem()
    self.h = self.h or self.w
    self.panel = self.parent_panel:panel({
        name = self.name,
        w = self.w,
        h = self.h,
	})
    self:InitBGs()
    local w = self.icon_w
    local h = self.icon_h
    if self.img_scale then
        w = w or self.w * self.img_scale
        h = h or self.h * self.img_scale
    else
        w = w or self.w - (self.img_offset[1] * 2)
        h = h or self.h - (self.img_offset[2] * 2)
    end

    self.img = self.panel:bitmap({
        name = "img",
        texture = self.texture,
        texture_rect = self.texture_rect,
        color = self.img_color or self.foreground,
        w = w,
        h = h,
        halign = "center",
        valign = "center",
        layer = 5,
        wrap_mode = self.wrap_mode,
        rotation = self.rotation
    })
    self.img:set_world_center(self.panel:world_center())
    self:MakeBorder()
end

function ImageButton:WorkParams(params)
    ImageButton.super.WorkParams(self, params)
    self.img_offset = self.img_offset and self:ConvertOffset(self.img_offset, true) or {0,0}
    self.img_offset[1] = self.img_offset_x or self.img_offset[1]
	self.img_offset[2] = self.img_offset_y or self.img_offset[2]
	self.button_type = true
end

function ImageButton:DoHighlight(highlight)
    ImageButton.super.DoHighlight(self, highlight)
    if self.highlight_image and self.img then
        if self.animate_colors then
            play_color(self.img, self:GetForeground(highlight))
        else
            self.img:set_color(self:GetForeground(highlight))
        end
    end
end

---Sets a texture and texture rectangle for the item
---@param texture string
---@param texture_rect? table @Optional, {x, y, w, h}
function ImageButton:SetImage(texture, texture_rect)
    texture_rect = texture_rect or {}
    self.img:set_image(texture, unpack(texture_rect))
end

---Sets the texture rectangle for the item.
---@param texture_rect table @{x, y, w, h}
function ImageButton:SetTextureRect(texture_rect)
    self.img:set_texture_rect(unpack(texture_rect))
end