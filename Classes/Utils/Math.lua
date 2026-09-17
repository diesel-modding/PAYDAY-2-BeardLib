--Includes utility functions for math, color, vector and rotation classes.

--As dumb as it is, it's the only way I found to make it work.
function math.rot_to_quat(rot)
	local t = ScriptSerializer:to_custom_xml({x = rot})
	local tbl = t:match('x="(.+)"'):split(" ")
    return {
        tonumber(tbl[1]),
        tonumber(tbl[2]),
        tonumber(tbl[3]),
        tonumber(tbl[4]),
    }
end

function math.quat_to_rot(x, y, z, w)
	local t = ScriptSerializer:from_custom_xml('<table x="'..x.." "..y.." "..z.." "..w..'"/>')
	return t.x
end

function mrotation.copy(rot)
    if rot then
        return Rotation(rot:yaw(), rot:pitch(), rot:roll())
    end
    return Rotation()
end

function mrotation.set_yaw(rot, yaw)
    return mrotation.set_yaw_pitch_roll(rot, yaw, rot:pitch(), rot:roll())
end

function mrotation.set_pitch(rot, pitch)
    return mrotation.set_yaw_pitch_roll(rot, rot:yaw(), pitch, rot:roll())
end

function mrotation.set_roll(rot, roll)
    return mrotation.set_yaw_pitch_roll(rot, rot:yaw(), rot:pitch(), roll)
end

--Not sure about these 2 functions. Any help with these would be appreicated
function mrotation.step(rot, rot_a, rot_b, t)
	mrotation.set_yaw_pitch_roll(
		rot,
		math.step(rot_a:yaw(), rot_b:yaw(), t),
		math.step(rot_a:pitch(), rot_b:pitch(), t),
		math.step(rot_a:roll(), rot_b:roll(), t)
	)
	return rot
end

function mrotation.add(rot, rot_a, rot_b)
	mrotation.set_yaw_pitch_roll(rot, rot_a:yaw() + rot_b:yaw(), rot_a:pitch() + rot_b:pitch(), rot_a:roll() + rot_b:roll())
end

function Color:color()
	return self
end

function Color:vector()
	return Vector3(self.r, self.g, self.b)
end

function Vector3:vector()
	return self
end

function Vector3:color()
	return Color(self:unpack())
end

---Color() Just adds support for #
function Color:from_hex(hex)
    if type_name(hex) == "Color" then
        return hex
    end
    if not hex or type(hex) ~= "string" then
        return Color()
    end
    if hex:find("#") then
        hex = hex:sub(2)
    end
    return Color(hex)
end

function Color:to_hex()
    local s = "%x"
    local result = ""
    for _, v in pairs({self.a < 1 and self.a or nil,self.r,self.g,self.b}) do
        local hex = s:format(255*v)
        if hex:len() == 0 then hex = "00" end
        if hex:len() == 1 then hex = "0"..hex end
        result = result .. hex
    end
    return result
end

function Color:contrast(white, black)
    local col = {r = self.r, g = self.g, b = self.b}

    for k, c in pairs(col) do
        if c <= 0.03928 then
            col[k] = c/12.92
        else
            col[k] = ((c+0.055)/1.055) ^ 2.4
        end
    end
    local L = 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b
    local color = white or Color.white
    if L > 0.179 and self.a > 0.5 then
        color = black or Color.black
    end
    return color
end

--Animating
local mstep = math.step
require("lib/utils/Easing")
function Easing.step(a, b, t)
	return mstep(a, b, t)
end

function anim_dt(dont_pause)
    local dt = coroutine.yield()
    if Application:paused() and not dont_pause then
        dt = TimerManager:main():delta_time()
    end
    return dt
end

function anim_over(seconds, f, dont_pause)
	local t = 0

	while true do
		local dt = anim_dt(dont_pause)
		t = t + dt

		if seconds <= t then
			break
		end

		f(t / seconds, t)
	end

	f(1, seconds)
end

function anim_wait(seconds, dont_pause)
	local t = 0

	while t < seconds do
		local dt = anim_dt(dont_pause)
		t = t + dt
	end
end

function play_anim_thread(params, o)
	o:script().animating = true

    local easing = Easing[params.easing or "_linear"]
    local time = params.time or 0.25
    local clbk = params.callback
    local wait_time = params.wait
	local after = params.after
    local set = params.set or params

    if wait_time then
        time = time + wait_time
        anim_wait(wait_time)
    end

    for param, value in pairs(set) do
        if type(value) ~= "table" then
            set[param] = {value = value}
        end
        set[param].old_value = set[param].old_value or o[param](o)
    end

	anim_over(time, function (t)
        for param, anim in pairs(set) do
            local ov = anim.old_value
            local v = anim.value
            local typ = type_name(v)
            if typ == "Color" then
                o:set_color(Color(easing(ov.a, v.a, t), easing(ov.r, v.r, t), easing(ov.g, v.g, t), easing(ov.b, v.b, t)))
            else
                o["set_"..param](o, anim.sticky and v or easing(ov, v, t))
            end
            if after then after() end
        end
    end)
    --last loop
    for param, anim in pairs(set) do
        local v = anim.value
        local typ = type_name(v)
        if typ == "Color" then
            o:set_color(v)
        else
            o["set_"..param](o, v)
        end
        if after then after() end
    end

    o:script().animating = nil
    if clbk then
        clbk()
    end
end

function playing_anim(o)
    if not alive(o) then
        return false
    end
    return o:script().animating
end

function stop_anim(o)
    if not alive(o) then
        return
    end
    o:stop()
    o:script().animating = nil
end

function play_anim(o, params)
    if not alive(o) then
        return
    end
    if playing_anim(o) and params.stop ~= false then
        stop_anim(o)
    end
    o:animate(SimpleClbk(play_anim_thread, params))
end

-- just more lightweight
function play_color(o, color, params)
    if not alive(o) then
        return
    end
    params = params or {}
    if playing_anim(o) and params.stop ~= false then
        stop_anim(o)
    end
    local easing = Easing[params.easing or "_linear"]
    local time = params.time or 0.25
    local clbk = params.callback
    local wait_time = params.wait
    local ov = o:color()
    if color then
        o:animate(function()
            o:script().animating = true
            if wait_time then
                time = time + wait_time
                anim_wait(wait_time)
            end
            anim_over(time, function (t)
                o:set_color(Color(easing(ov.a, color.a, t), easing(ov.r, color.r, t), easing(ov.g, color.g, t), easing(ov.b, color.b, t)))
            end)
            o:set_color(color)
            o:script().animating = nil
            if clbk then clbk() end
        end)
    end
end

function play_value(o, value_name, value, params)
    if not alive(o) then
        return
    end
    params = params or {}
    if playing_anim(o) and params.stop ~= false then
        stop_anim(o)
    end
    local easing = Easing[params.easing or "_linear"]
    local time = params.time or 0.25
    local clbk = params.callback
    local wait_time = params.wait
    local ov = o[value_name](o)
    local func = ClassClbk(o, "set_"..value_name)
    if value then
        o:animate(function()
            o:script().animating = true
            if wait_time then
                time = time + wait_time
                anim_wait(wait_time)
            end
            anim_over(time, function (t)
                func(easing(ov, value, t))
            end)
            func(value)
            o:script().animating = nil
            if clbk then clbk() end
        end)
    end
end