HeistMusic = HeistMusic or BeardLib:ModuleClass("HeistMusic", ItemModuleBase)
StealthMusic = StealthMusic or BeardLib:ModuleClass("StealthMusic", HeistMusic)
StealthMusic.is_stealth = true

-- Resume buffer loading coroutine
Hooks:Add("GameSetupUpdate", "GameSetupUpdateBeardLibMusicLoad", function ()
	if HeistMusic.buffer_load_co and not coroutine.resume(HeistMusic.buffer_load_co) then
		HeistMusic.buffer_load_id = nil
		HeistMusic.buffer_load_co = nil
	end
end)

function HeistMusic:LoadBuffers(wanted_source)
	-- Load wanted source first
	if wanted_source and wanted_source.module and not wanted_source.buffer then
		wanted_source.buffer = XAudio.Buffer:new(wanted_source.path)
	end

	-- If we are already loading tracks for this music id, return
	if HeistMusic.buffer_load_id == self._config.id then
		return
	end

	-- Create a coroutine that loads one source each time it is resumed so loading stutter and resulting issues are reduced
	HeistMusic.buffer_load_id = self._config.id
	HeistMusic.buffer_load_co = coroutine.create(function ()
		for _, event in pairs(BeardLib.MusicMods[self._config.id].events) do
			for _, track in pairs(event.tracks) do
				if track.start_source and track.start_source.module and not track.start_source.buffer then
					track.start_source.buffer = XAudio.Buffer:new(track.start_source.path)
					coroutine.yield()
				end
				if track.source and track.source.module and not track.source.buffer then
					track.source.buffer = XAudio.Buffer:new(track.source.path)
					coroutine.yield()
				end
			end
		end
	end)
end

function HeistMusic:UnloadBuffers()
	-- If for some reason we are still loading tracks of the current music id, stop loading them
	if HeistMusic.buffer_load_id == self._config.id then
		HeistMusic.buffer_load_id = nil
		HeistMusic.buffer_load_co = nil
	end

	for _, event in pairs(BeardLib.MusicMods[self._config.id].events) do
		for _, track in pairs(event.tracks) do
			if track.start_source and track.start_source.module then
					if track.start_source.buffer then
						track.start_source.buffer:close(true)
					end
					track.start_source.buffer = nil
			end
			if track.source and track.source.module then
				if track.source.buffer then
					track.source.buffer:close(true)
				end
				track.source.buffer = nil
			end
		end
	end
end

function HeistMusic:MakeBuffer(source)
	if source then
		if FileIO:Exists(source) then
			return BeardLib.OptimizedMusicLoad and {path = source, module = self} or XAudio.Buffer:new(source)
		else
			self:Err("Source file '%s' does not exist, music id '%s'", tostring(source), tostring(self._config.id))
			return nil
		end
	end
end

function HeistMusic:RegisterHook()
	if not XAudio then
		self:Err("Heist music module requires the XAudio API!")
		return
	end

	self._config.id = self._config.id or "Err"
	if BeardLib.MusicMods[self._config.id] then
		self:Err("Music with the id '%s' already exists!", self._config.id)
		return
	end

	local dir = self._config.directory
	if dir then
		dir = Path:Combine(self._mod.ModPath, dir)
	else
		dir = self._mod.ModPath
	end
	local music = {
		[self.is_stealth and "stealth" or "heist"] = true,
		volume = self._config.volume,
		allow_switch = NotNil(self._config.allow_switch, true),
		xaudio = true,
		events = {}
	}
	BeardLib.Utils:SetupXAudio()

	for k,v in ipairs(self._config) do
		if type(v) == "table" and v._meta == "event" then
			local tracks = {}
			-- Track handling as part of child track tags
			for _,t in ipairs(v) do
				if type(t) == "table" and t._meta == "track" then
					table.insert(tracks, {
						start_source = (t.start_source or v.start_source) and self:MakeBuffer(Path:Combine(dir, (t.start_source or v.start_source))),
						source = (t.source or v.source) and self:MakeBuffer(Path:Combine(dir, (t.source or v.source))),
						weight = t.weight or v.weight or 1,
						volume = t.volume or v.volume or music.volume,
						allow_switch = NotNil(t.allow_switch, v.allow_switch, music.allow_switch)
					})
				end
			end
			-- Track handling as part of event tag
			if #tracks == 0 then
				table.insert(tracks, {
					start_source = v.start_source and self:MakeBuffer(Path:Combine(dir, v.start_source)),
					source = v.source and self:MakeBuffer(Path:Combine(dir, v.source)),
					weight = v.alt_chance and (1 - v.alt_chance) * 100 or 1,
					volume = v.volume or music.volume,
					allow_switch = NotNil(v.allow_switch, music.allow_switch)
				})
				if v.alt_source then -- backwards compat for old alternate track system
					table.insert(tracks, {
						start_source = (v.alt_start_source or v.start_source) and self:MakeBuffer(Path:Combine(dir, (v.alt_start_source or v.start_source))),
						source = v.alt_source and self:MakeBuffer(Path:Combine(dir, v.alt_source)),
						weight = v.alt_chance and v.alt_chance * 100 or 1,
						volume = v.volume or music.volume,
						allow_switch = NotNil(v.allow_switch, music.allow_switch)
					})
				end
			end
			for i,t in ipairs(tracks) do
				if not t.start_source and not t.source then
					self:Err("Event named %s in heist music %s has no defined source for track %i", tostring(self._config.id), tostring(v.name), i)
					return
				end
			end
			music.events[v.name] = {
				tracks = tracks,
				volume = v.volume or music.volume,
				allow_switch = NotNil(v.allow_switch, music.allow_switch),
				play_order = NotNil(v.play_order, music.play_order, "random")
			}
		end
	end

	music.preview_event = music.events[self._config.preview_event or (self.is_stealth and "suspense_4" or "assault")] or music.events[next(music.events)]

	BeardLib.MusicMods[self._config.id] = music
end