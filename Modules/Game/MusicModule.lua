MusicModule = MusicModule or BeardLib:ModuleClass("Music", ItemModuleBase)

function MusicModule:RegisterHook()
	self._config.id = self._config.id or "Err"

	local dir = self._config.directory
	local music = {
		menu = self._config.menu,
		heist = self._config.heist,
		volume = self._config.volume,
		allow_switch = NotNil(self._config.allow_switch, true),
		events = {}
	}

	for k,v in ipairs(self._config) do
		if type(v) == "table" and v._meta == "event" then
			local tracks = {}
			-- Track handling as part of child track tags
			for _,t in ipairs(v) do
				if type(t) == "table" and t._meta == "track" then
					local sauce = (t.source or v.source)
					local start_sauce = t.start_source or v.start_source
					table.insert(tracks, {
						start_source = start_sauce and (dir and Path:Combine(dir, start_sauce) or start_sauce),
						source = sauce and (dir and Path:Combine(dir, sauce) or sauce),
						weight = t.weight or v.weight or 1,
						volume = t.volume or v.volume or music.volume,
						allow_switch = NotNil(t.allow_switch, v.allow_switch, music.allow_switch)
					})
				end
			end
			-- Track handling as part of event tag
			if #tracks == 0 then
				table.insert(tracks, {
					start_source = v.start_source and (dir and Path:Combine(dir, v.start_source) or v.start_source),
					source = v.source and (dir and Path:Combine(dir, v.source) or v.source),
					weight = v.alt_chance and v.alt_chance * 100 or 1,
					volume = v.volume or music.volume,
					allow_switch = NotNil(v.allow_switch, music.allow_switch)
				})
				if v.alt_source then -- backwards compat for old alternate track system
					local sauce = v.alt_start_source or v.start_source
					table.insert(tracks, {
						start_source = (v.alt_start_source or v.start_source) and (dir and Path:Combine(dir, sauce) or sauce),
						source = dir and Path:Combine(dir, v.alt_source) or v.alt_source,
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

	if self._config.source and music.menu then
		self._config.preview_event = self._config.preview_event or self._config.source
		if not music.events[self._config.preview_event] then
			music.events[self._config.preview_event] = {
				tracks = {
					start_source = self._config.start_source and (dir and Path:Combine(dir, self._config.start_source) or self._config.start_source),
					source = dir and Path:Combine(dir, self._config.source) or self._config.source,
					volume = music.volume
				},
				volume = music.volume
			}
		end
	end

	if not self._mod._config.AddFiles then
		local add = {directory = self._config.assets_directory or "Assets"}
		for _, event in pairs(music.events) do
			for _, track in pairs(event.tracks) do
				table.insert(add, {_meta = "movie", path = track.source})
				if track.start_source then
					table.insert(add, {_meta = "movie", path = track.start_source})
				end
			end
		end
		self._mod._config.AddFiles = AddFilesModule:new(self._mod, add)
	end

	music.preview_event = music.events[self._config.preview_event or "assault"] or music.events[next(music.events)]

	BeardLib.MusicMods[self._config.id] = music
end