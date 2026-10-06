-- What this match server is running: mode, map and how many players the lobby
-- sent. A server the lobby reserved reads these from where the lobby left
-- them, keyed by its private server id. Any other server (a Studio test, or a
-- place opened directly) uses MatchConfig.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local MatchConfig = require(Shared.Config.MatchConfig)

local MatchSettings = {}

local settings = {
	mode = MatchConfig.mode,
	map = MatchConfig.map,
	expected = MatchConfig.minPlayers, -- players the match waits for before it starts
	fromLobby = false, -- true when the lobby set this match up, so players return there
	accessCode = nil, -- what a lobby needs to send more players to this server
}

-- Reads the lobby's settings if there are any. Yields. Call once, before
-- anything reads `current`.
function MatchSettings.load()
	if game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 then
		return settings -- not a server the lobby reserved
	end
	local ok, saved = pcall(function()
		return MemoryStoreService:GetHashMap(LobbyConfig.settingsStore):GetAsync(game.PrivateServerId)
	end)
	if not ok then
		warn(`MatchSettings: could not read the lobby's settings, using MatchConfig: {saved}`)
		return settings
	end
	-- Nothing the lobby wrote is trusted further than it can be checked.
	if type(saved) == "table" and LobbyConfig.modes[saved.mode] and type(saved.map) == "string" then
		settings.mode = saved.mode
		settings.map = saved.map
		settings.expected = math.max(tonumber(saved.expected) or 0, MatchConfig.minPlayers)
		settings.fromLobby = true
		settings.accessCode = if type(saved.accessCode) == "string" then saved.accessCode else nil
	end
	return settings
end

function MatchSettings.current()
	return settings
end

return MatchSettings
