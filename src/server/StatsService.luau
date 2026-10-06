-- What each player did this match: kills, deaths, and the objectives they
-- completed. The one place those are counted, so the scoreboard, the payouts
-- and the podium never disagree.
--
-- Kills and deaths are also mirrored into leaderstats, which is what Roblox's
-- own player list (Tab) shows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared.Config.MatchConfig)
local Score = require(Shared.Logic.Score)

local MatchService = require(script.Parent.MatchService)

local StatsService = {}

local SHOWN = { kills = "Kills", deaths = "Deaths" }
local counts = {} -- [player] = { kills, deaths, assists, plants, defuses }

local function blank()
	return { kills = 0, deaths = 0, assists = 0, plants = 0, defuses = 0 }
end

-- The leaderstats folder Roblox's player list reads.
local function attach(player)
	counts[player] = blank()
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in SHOWN do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
end

function StatsService.record(player, field, amount)
	local held = counts[player]
	if not held or held[field] == nil then
		return
	end
	held[field] = math.max(held[field] + (amount or 1), 0) -- a revive can take one back

	local shown = SHOWN[field]
	local stats = shown and player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(shown)
	if value then
		value.Value = held[field]
	end
end

function StatsService.get(player)
	return counts[player] or blank()
end

-- Everyone's match so far, ready for Score. Players who left are not in it.
function StatsService.results()
	local results = {}
	for _, player in Players:GetPlayers() do
		local held = counts[player]
		if held then
			local result = table.clone(held)
			result.name = player.Name
			result.player = player
			table.insert(results, result)
		end
	end
	return results
end

-- How this match decides who did best.
function StatsService.weights()
	return MatchConfig.mvp[MatchService.mode()] or MatchConfig.mvp.TDM
end

function StatsService.top(count)
	return Score.top(StatsService.weights(), StatsService.results(), count)
end

function StatsService.mvp()
	return Score.mvp(StatsService.weights(), StatsService.results())
end

local function clear()
	for player, held in counts do
		counts[player] = blank()
		local stats = player:FindFirstChild("leaderstats")
		for _, name in SHOWN do
			local value = stats and stats:FindFirstChild(name)
			if value then
				value.Value = 0
			end
		end
	end
end

function StatsService.init()
	Players.PlayerAdded:Connect(attach)
	for _, player in Players:GetPlayers() do
		attach(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		counts[player] = nil
	end)

	-- A new match starts everyone at zero. Rounds within a match do not.
	MatchService.Started:Connect(clear)
end

return StatsService
