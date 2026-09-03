-- API Calls --
local orig_NetworkMatchMakingSTEAM_set_attributes = NetworkMatchMakingSTEAM.set_attributes

local seta_hook = "BeardLibSteamLobbySetAttributes"

Hooks:Register(seta_hook)

function NetworkMatchMakingSTEAM:set_attributes(settings, ...)
	if not self.lobby_handler then
		return
	end
	orig_NetworkMatchMakingSTEAM_set_attributes(self, settings, ...)

	local new_data = {}

	Hooks:Call(seta_hook, self, new_data, settings, ...)
	if table.size(new_data) > 0 then
		table.merge(self._lobby_attributes, new_data)
	    self.lobby_handler:set_lobby_data(new_data)
	end
end

local orig_NetworkMatchMakingSTEAM_lobby_to_numbers = NetworkMatchMakingSTEAM._lobby_to_numbers
function NetworkMatchMakingSTEAM:_lobby_to_numbers(lobby, ...)
	BeardLib:DevLog("Received level: " .. tostring(lobby:key_value("level_id")))
	BeardLib:DevLog("Received narrative: " .. tostring(lobby:key_value("job_key")))
	local data = {} --Init an empty table
    if not tonumber(lobby:key_value("job_id")) then -- Check for invalid job_id
        BeardLib:DevLog("Received invalid job_id:" .. tostring(lobby:key_value("job_id")) .. "... Patching data to prevent crash.")
        data = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0} --Patch 0 values to data to prevent errors in the lobby browser.
    else
        data = orig_NetworkMatchMakingSTEAM_lobby_to_numbers(self, lobby, ...) -- Call original function if job_id is valid
    end
	local is_key_valid = function(key) return key ~= "value_missing" and key ~= "value_pending" end
	if is_key_valid(lobby:key_value("level_id")) or is_key_valid(lobby:key_value("job_key")) then
		local _level_index = table.index_of(tweak_data.levels._level_index, lobby:key_value("level_id"))
		local _job_index = table.index_of(tweak_data.narrative._jobs_index, lobby:key_value("job_key"))
		if _level_index ~= -1 or _job_index ~= -1 then
			local level_index = _level_index == -1 and tonumber(lobby:key_value("level")) or _level_index
			local job_index = _job_index == -1 and tonumber(lobby:key_value("job_id")) or _job_index
			--log("level_index: " .. tostring(level_index))
			--log("job_index: " .. tostring(job_index))
			data[1] = level_index + 1000 * job_index
			return data
		end
	end
	local level_name = lobby:key_value("custom_level_name")
	local uid = lobby:key_value("level_update_key")
	local provider = lobby:key_value("level_update_provider")
	local url = lobby:key_value("level_update_download_url")
	if is_key_valid(level_name) then
		BeardLib:DevLog("Received level real name: " .. tostring(level_name))
		data["level_id"] = lobby:key_value("level_id")
		data["job_key"] = lobby:key_value("job_key")
		data["custom_level_name"] = level_name
		data["custom_map"] = 1
		data[1] = 1001
		if is_key_valid(uid) or is_key_valid(provider) or is_key_valid(url) then
			BeardLib:DevLog("Received custom map data, id: " .. tostring(uid))
			BeardLib:DevLog("provider: " .. tostring(provider))
			BeardLib:DevLog("download url: " .. tostring(url))
			data["level_update_key"] = uid
			data["level_update_provider"] = provider
			data["level_update_download_url"] = url
		elseif not tweak_data.narrative.jobs[data["job_key"]] then
			data[1] = 0 -- Ignore this custom heist
		end
	end
	return data
end

Hooks:PostHook(NetworkMatchMakingSTEAM, "_call_callback", "BeardLibSearchLobbyFix", function(self, name, info)
	if name == "search_lobby" then
		local attribute_list = info.attribute_list
		for i, room in ipairs(info.room_list) do
			local numbers = attribute_list[i].numbers
			local state_string_id = tweak_data:index_to_server_state(numbers[4])
			local state_name = state_string_id and managers.localization:text("menu_lobby_server_state_" .. state_string_id) or "UNKNOWN"
			if numbers.custom_map == 1 then
				local comp = managers.menu_component
				local cmgui = comp and comp._crimenet_gui
				if cmgui and cmgui._jobs and cmgui._jobs[room.room_id] then
					local job = cmgui._jobs[room.room_id]
					if numbers.level_update_key or numbers.provider or numbers.download_url then
						local update_data = {id = numbers.level_update_key, provider = numbers.level_update_provider, download_url = numbers.level_update_download_url}
						job.update_data = table.size(update_data) > 0 and update_data or nil
						job.level_name = tostring(numbers.custom_level_name)
						job.job_key = numbers.job_key
						job.state_name = state_name
						cmgui:change_to_custom_job_gui(job)
					else
						local job_tweak = tweak_data.narrative.jobs[numbers.job_key]
						if job_tweak then
							job.level_name = managers.localization:to_upper_text(job_tweak.name_id)
							job.job_key = numbers.job_key
						end
					end
				end
			end
		end
	end
end)

-- BEARDLIB API ADDITIONS --

Hooks:Add(seta_hook, "BeardLibCorrectCustomHeist", function(self, new_data, settings, ...)
	self.lobby_handler:delete_lobby_data("level_id")
	self.lobby_handler:delete_lobby_data("job_key")

	local level_index, job_index = self:_split_attribute_number(settings.numbers[1], 1000)
	local _level_id = tweak_data.levels._level_index[level_index]
	local _job_key = tweak_data.narrative._jobs_index[job_index]
	local level_id = (_level_id and tweak_data.levels[_level_id] and tweak_data.levels[_level_id].custom) and _level_id or nil
	local job_key = (_job_key and tweak_data.narrative.jobs[_job_key] and tweak_data.narrative.jobs[_job_key].custom) and _job_key or nil
	local mod = BeardLib.Utils:GetMapByJobId(_job_key)
	if mod and (level_id or job_key) then
		local mod_assets = mod:GetModule(ModAssetsModule.type_name)
		if mod_assets and mod_assets._data then
			local update = mod_assets._data
			--Localization might be an issue..
			table.merge(new_data, {
				custom_map = 1,
				custom_level_name = tweak_data.levels[level_id] and managers.localization:to_upper_text(tweak_data.levels[level_id].name_id) or "",
				level_id = level_id,
				job_key = job_key,
				level_update_key = update.id,
				level_update_provider = update.provider,
				level_update_download_url = update.download_url,
			})
		else
			table.merge(new_data, {
				custom_level_name = tweak_data.levels[level_id] and managers.localization:to_upper_text(tweak_data.levels[level_id].name_id) or "",
				custom_map = 1,
				level_id = level_id,
				job_key = job_key
			})
		end
	end
end)

-- Custom heists only filter
-- If they add any new interest keys, just make sure to update these.
-- If your mod adds any keys, you can extend this list.
NetworkMatchMakingSTEAM.DEFAULT_KEYS = {
	"owner_id", "owner_name", "level", "difficulty", "permission", "state", "num_players",
	"drop_in", "min_level", "kick_option", "job_class_min", "job_class_max", "allow_mods", 
	"custom_map"
}
Hooks:PostHook(NetworkMatchMakingSTEAM, "search_lobby", "CustomMapFilter", function(self, friends_only, no_filters)
    if Global.game_settings.custom_maps_only and self.browser then
		self.browser:set_interest_keys(self.DEFAULT_KEYS)
		self.browser:set_lobby_filter("custom_map", 1, "equalto_or_greater_than")
    end
end)