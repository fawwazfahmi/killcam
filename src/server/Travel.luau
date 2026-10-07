-- Sending players to another place, and trying again when it does not work.
-- Used by both places: the lobby sends players into matches, and a match sends
-- them back.
--
-- A teleport fails in two ways. The request can be refused outright, which
-- `send` sees and tries again. Or it is accepted and then fails for one
-- player a moment later, who is still here: that player is sent again, on
-- their own. When the tries run out, `GaveUp` fires for them.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local Travel = {}

local REQUEST_WAITS = { 1, 2, 4 } -- seconds before each further try at a request that was refused
local RESEND_WAITS = { 2, 4, 8 } -- seconds before each further try for a player whose teleport failed
local FLOODED_WAIT = 15 -- seconds to hold off when told there are too many teleports at once

local sent = {} -- [player] = { placeId, options, tries }: where they are meant to be going
local gaveUp = Instance.new("BindableEvent")

-- Fires with (player, placeId) for a player who could not be sent and is still here.
Travel.GaveUp = gaveUp.Event

local function request(placeId, players, options)
	local ok, problem = pcall(TeleportService.TeleportAsync, TeleportService, placeId, players, options)
	for _, wait in REQUEST_WAITS do
		if ok then
			break
		end
		task.wait(wait)
		-- Only those still here: asking for somebody who has left is an error.
		local here = {}
		for _, player in players do
			if player.Parent == Players then
				table.insert(here, player)
			end
		end
		if #here == 0 then
			return true
		end
		players = here
		ok, problem = pcall(TeleportService.TeleportAsync, TeleportService, placeId, players, options)
	end
	return ok, problem
end

-- Sends `players` to a place; `options` is a TeleportOptions, or nil. Yields.
-- Returns whether the request was accepted, and the problem if it was not.
-- Accepted is not arrived: see `GaveUp`.
function Travel.send(placeId, players, options)
	for _, player in players do
		sent[player] = { placeId = placeId, options = options, tries = 0 }
	end
	local ok, problem = request(placeId, players, options)
	if not ok then
		for _, player in players do
			sent[player] = nil
		end
	end
	return ok, problem
end

-- Players this server has sent somewhere who have not left yet.
function Travel.waiting()
	local players = {}
	for player in sent do
		table.insert(players, player)
	end
	return players
end

local function onFailed(player, result)
	local trip = sent[player]
	if not trip then
		return
	end
	trip.tries += 1
	local wait = RESEND_WAITS[trip.tries]
	if not wait then
		sent[player] = nil
		gaveUp:Fire(player, trip.placeId)
		return
	end
	task.wait(if result == Enum.TeleportResult.Flooded then FLOODED_WAIT else wait)
	if sent[player] ~= trip or player.Parent ~= Players then
		return -- they left, or have been sent somewhere else since
	end
	local ok, problem = pcall(TeleportService.TeleportAsync, TeleportService, trip.placeId, { player }, trip.options)
	if not ok then
		warn(`Travel: could not send {player.Name} again: {problem}`)
		onFailed(player, result)
	end
end

TeleportService.TeleportInitFailed:Connect(onFailed)
Players.PlayerRemoving:Connect(function(player)
	sent[player] = nil
end)

return Travel
