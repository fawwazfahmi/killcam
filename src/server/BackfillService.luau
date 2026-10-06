-- The match's side of filling a leaver's place (rules in Shared.Logic.Backfill).
-- While the match is short of the players it started with, and not nearly
-- over, it keeps a seat advertised for the lobbies to claim from. Only a match
-- the lobby set up does this: nothing else has anywhere to be sent players from.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local Backfill = require(Shared.Logic.Backfill)

local MatchService = require(script.Parent.MatchService)
local MatchSettings = require(script.Parent.MatchSettings)

local BackfillService = {}

local CONFIG = LobbyConfig.backfill

local seats = nil -- the list this match advertises in
local advertised = false
local arrived = 0 -- players who have joined since the seat was last renewed
local renewing = false

-- Places empty right now that somebody should be sent to fill.
local function missing()
	if not Backfill.wanted(MatchService.describe()) then
		return 0
	end
	return math.max(MatchSettings.current().expected - #Players:GetPlayers(), 0)
end

-- Brings the advertised seat up to date. Yields.
local function renew()
	if renewing then
		return
	end
	renewing = true
	local empty = missing()
	local joined = arrived
	arrived = 0
	local key = game.PrivateServerId

	if empty > 0 then
		-- The most room on any one team is the biggest squad that can come in whole.
		local counts = {}
		for _, team in Teams:GetTeams() do
			counts[team.Name] = #team:GetPlayers()
		end
		local settings = MatchSettings.current()
		local gap = Backfill.gap(counts, settings.expected)
		local ok, problem = pcall(seats.UpdateAsync, seats, key, function(old)
			return Backfill.refresh(old, settings.accessCode, empty, gap, joined, os.time(), CONFIG.transitTimeout)
		end, CONFIG.seatLifetime)
		if ok then
			advertised = true
		else
			warn(`BackfillService: could not advertise an open seat: {problem}`)
		end
	elseif advertised then
		advertised = false
		pcall(seats.RemoveAsync, seats, key)
	end
	renewing = false
end

function BackfillService.init()
	local settings = MatchSettings.current()
	if not settings.fromLobby or not settings.accessCode then
		return
	end
	seats = MemoryStoreService:GetSortedMap(CONFIG.seatStore .. "_" .. settings.mode)

	Players.PlayerAdded:Connect(function()
		arrived += 1
	end)
	-- Somebody leaving is what opens a seat: do not wait for the next renewal,
	-- only for them to be gone from the count.
	Players.PlayerRemoving:Connect(function()
		task.delay(1, renew)
	end)
	task.spawn(function()
		while true do
			task.wait(CONFIG.refreshEvery)
			renew()
		end
	end)
	game:BindToClose(function()
		if advertised then
			pcall(seats.RemoveAsync, seats, game.PrivateServerId)
		end
	end)
end

return BackfillService
