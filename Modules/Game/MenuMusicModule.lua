MenuMusicModule = MenuMusicModule or BeardLib:ModuleClass("MenuMusic", HeistMusic)

function MenuMusicModule:RegisterHook()
	if not XAudio then
		self:Err("Menu music module requires the XAudio API!")
		return
	end

	self._config.id = self._config.id or "Err"
	if BeardLib.MusicMods[self._config.id] and not self._config.force then
		self:Err("Music with the id '%s' already exists!", self._config.id)
		return
	end

	if self._config.source then
		self._config.source = Path:Combine(self._mod.ModPath, self._config.source)
	else
		self:log("[Warning] No source was specified for the menu music %s", self._config.id)
	end

	if self._config.start_source then
		self._config.start_source = Path:Combine(self._mod.ModPath, self._config.start_source)
	end

	BeardLib.Utils:SetupXAudio()
	local music = {
		menu = true,
		xaudio = true,
		volume = self._config.volume,
		events = {
			menu = {
				tracks = {
					{
						source = self:MakeBuffer(self._config.source),
						start_source = self:MakeBuffer(self._config.start_source),
						volume = self._config.volume
					}
				}
			}
		}
	}

	music.preview_event = music.events.menu

	BeardLib.MusicMods[self._config.id] = music
end