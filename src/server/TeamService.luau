-- Teams, and who may hurt whom.
--
-- Before a match starts it is a free-for-all warm-up: players are already on
-- teams, but everyone can fight everyone. When the match starts the teams are
-- evened out, so it is never 3v1 when it could be 2v2.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local MatchConfig = require(Shared.Config.MatchConfig)
local Queue = require(Shared.Logic.Queue)

local MatchService = require(script.Parent.MatchService)
local MatchSettings = require(script.Parent.MatchSettings)

local TeamService = {}

local COLORS = { "Bright blue", "Bright red" }
local teams = {}
local pending = {} -- [player] = the Team they move to at their next spawn
local planned = {} -- [player] = the team (1 or 2) the lobby put them on
local mates = {} -- [player] = { [userId] = true } for everyone in their squad

-- True for a match with no teams at all.
local function noTeams()
	return MatchSettings.current().mode == "FFA"
end

-- A player's team, counting a move they are queued for.
local function teamOf(player)
	return pending[player] or player.Team
end

local function members(team)
	local list = {}
	for _, player in Players:GetPlayers() do
		if teamOf(player) == team then
			table.insert(list, player)
		end
	end
	return list
end

-- What the lobby sent along with a player: the side it planned for them, and
-- who they are in a squad with. It travels through the player's own game, so
-- nothing in it is trusted further than its shape can be checked; the worst a
-- forged one can do is choose a team.
local function readArrival(player)
	local ok, joined = pcall(player.GetJoinData, player)
	local sent = ok and type(joined) == "table" and joined.TeleportData
	if type(sent) ~= "table" then
		return
	end
	local side = type(sent.sides) == "table" and sent.sides[tostring(player.UserId)]
	if side == 1 or side == 2 then
		planned[player] = side
	end
	for _, squad in if type(sent.squads) == "table" then sent.squads else {} do
		if type(squad) == "table" and #squad <= LobbyConfig.squad.size and table.find(squad, player.UserId) then
			mates[player] = {}
			for _, userId in squad do
				if type(userId) == "number" then
					mates[player][userId] = true
				end
			end
		end
	end
end

-- The team a squad-mate of this player is already on, or nil.
local function squadTeam(player)
	for _, other in Players:GetPlayers() do
		if other ~= player and mates[player] and mates[player][other.UserId] and teamOf(other) then
			return teamOf(other)
		end
	end
	return nil
end

-- Evens the two teams to within one player. A player with a squad-mate on
-- their team is never the one moved: a squad is not split to even the sides,
-- and the place is left for the queue to fill. With `now`, players are moved at
-- once: only safe when everyone is about to respawn. Otherwise each move waits
-- for that player's next spawn, so nobody changes sides mid-fight.
local function balance(now)
	if #teams < 2 then
		return
	end
	local larger, smaller = teams[1], teams[2]
	if #members(larger) < #members(smaller) then
		larger, smaller = smaller, larger
	end
	local crowd = {}
	for _, player in members(larger) do
		if squadTeam(player) ~= larger then
			table.insert(crowd, player)
		end
	end
	for _ = 1, math.min(Queue.movesToBalance(#members(larger), #members(smaller)), #crowd) do
		local player = table.remove(crowd) -- whoever joined that team last
		if now then
			pending[player] = nil
			player.Team = smaller
		else
			pending[player] = smaller
		end
	end
end

function TeamService.init()
	if noTeams() then
		return
	end
	for index, name in MatchConfig.teams do
		local team = Instance.new("Team")
		team.Name = name
		team.TeamColor = BrickColor.new(COLORS[index])
		team.AutoAssignable = false
		team.Parent = Teams
		teams[index] = team
	end

	MatchService.Changed:Connect(function(event)
		-- Everyone respawns on these, so sides can change straight away.
		if event == "Started" or event == "RoundStarted" then
			balance(true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		planned[player] = nil
		mates[player] = nil
		-- Deferred, so the count no longer includes whoever is leaving.
		task.defer(balance, false)
	end)
end

-- Puts an arriving player on a team: the one the lobby planned for them, or
-- the one their squad is on, or whichever is smaller.
function TeamService.assign(player)
	if noTeams() then
		player.Neutral = true
		return
	end
	readArrival(player)
	local smallest = teams[1]
	for _, team in teams do
		if #members(team) < #members(smallest) then
			smallest = team
		end
	end
	player.Neutral = false
	player.Team = teams[planned[player]] or squadTeam(player) or smallest
end

-- Called as a player is about to spawn: a queued team move happens now.
function TeamService.beforeSpawn(player)
	local team = pending[player]
	if team then
		pending[player] = nil
		player.Team = team
	end
end

-- True when everyone is against everyone: a free-for-all match, or the
-- warm-up before any match.
function TeamService.isFreeForAll()
	return noTeams() or MatchService.phase() == "Waiting"
end

function TeamService.teamName(player)
	return player.Team and player.Team.Name or nil
end

-- What a player's kills are scored under: their team, or themselves in a free-for-all.
function TeamService.scoreKey(player)
	if noTeams() then
		return player.Name
	end
	return TeamService.teamName(player)
end

function TeamService.areEnemies(a, b)
	if TeamService.isFreeForAll() then
		return a ~= b
	end
	return a ~= b and a.Team ~= nil and b.Team ~= nil and a.Team ~= b.Team
end

return TeamService
