-- Runs the match clock and score for whichever mode is configured, and tells
-- the other services what is allowed right now.
--
-- Modes: "FFA" and "TDM" use Shared.Logic.MatchState; "SND" uses BombRound.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local MatchConfig = require(Shared.Config.MatchConfig)
local Backfill = require(Shared.Logic.Backfill)
local BombRound = require(Shared.Logic.BombRound)
local MatchState = require(Shared.Logic.MatchState)
local Remotes = require(Shared.Remotes)

local MatchSettings = require(script.Parent.MatchSettings)
local Travel = require(script.Parent.Travel)

local MatchService = {}

-- MatchState reads its limits from a table shaped like MatchConfig. A
-- free-for-all has no teams and its own limits.
local FFA_RULES = {
	teams = {},
	minPlayers = MatchConfig.minPlayers,
	endDuration = MatchConfig.endDuration,
	scoreLimit = MatchConfig.ffa.scoreLimit,
	timeLimit = MatchConfig.ffa.timeLimit,
}

local mode = "TDM"
local rules = MatchConfig
local state = MatchState.new(MatchConfig)
local started = Instance.new("BindableEvent")
local roundStarted = Instance.new("BindableEvent")
local changed = Instance.new("BindableEvent")

-- The warm-up: while the match is Waiting, how long anyone has been here.
local waited = 0
local finished = false -- a match has been played to the end on this server
local abandonedFor = 0 -- seconds only one side has had anybody on it
local returning = false -- the lobby's match is over and this server is sending everyone back

-- Fires when a new match begins. SpawnService resets stats and respawns everyone.
MatchService.Started = started.Event
-- SND: fires when a round after the first begins. Everyone respawns.
MatchService.RoundStarted = roundStarted.Event
-- Fires with the name of every phase change (see MatchState.tick and BombRound.tick).
MatchService.Changed = changed.Event

local function snapshot()
	return {
		mode = mode,
		phase = state.phase,
		scores = state.scores,
		timeLeft = math.ceil(state.timeLeft),
		winner = state.winner,
		-- While waiting: how many are here, of how many the match wants.
		present = #Players:GetPlayers(),
		expected = MatchSettings.current().expected,
		-- SND only:
		round = state.round,
		attackers = state.attackers,
		roundWinner = state.roundWinner,
		reason = state.reason,
	}
end

function MatchService.mode()
	return mode
end

function MatchService.phase()
	return state.phase
end

-- Once a match is over: the winning team, the winning player's name in a
-- free-for-all, or "Draw".
function MatchService.winner()
	return state.winner
end

-- SND: the team attacking this round.
function MatchService.attackers()
	return state.attackers
end

-- False between rounds and on the result screen: shots, swings and throws are dropped.
function MatchService.combatAllowed()
	if mode == "SND" then
		return state.phase == "Waiting" or BombRound.inPlay(state)
	end
	return state.phase ~= "Ended"
end

-- What a match looks like to something deciding whether to send it a new
-- player (see Shared.Logic.Backfill).
function MatchService.describe()
	return {
		mode = mode,
		phase = state.phase,
		scores = state.scores,
		timeLeft = state.timeLeft,
		scoreLimit = rules.scoreLimit,
		roundsToWin = MatchConfig.bomb.roundsToWin,
	}
end

-- True while a match is actually being fought: not the warm-up, not between
-- rounds, not the result screen.
function MatchService.inPlay()
	if mode == "SND" then
		return BombRound.inPlay(state)
	end
	return state.phase == "Playing"
end

-- Whether a dead player comes back by themselves. In SND, only while waiting
-- for players.
function MatchService.respawns()
	return mode ~= "SND" or state.phase == "Waiting"
end

-- Whether a player may be put into the map right now. An SND round in
-- progress cannot be joined.
function MatchService.canSpawn()
	return mode ~= "SND" or state.phase == "Waiting" or state.phase == "Prep"
end

-- Which of the map's spawns a team uses. In SND the attackers always start
-- from the first team's spawn, whichever team is attacking.
function MatchService.spawnTeam(teamName)
	if mode ~= "SND" or not teamName then
		return teamName
	end
	return if teamName == state.attackers then MatchConfig.teams[1] else MatchConfig.teams[2]
end

function MatchService.broadcast()
	Remotes.MatchUpdate:FireAllClients(snapshot())
end

function MatchService.sendTo(player)
	Remotes.MatchUpdate:FireClient(player, snapshot())
end

-- `side` is what TeamService.scoreKey gives for the killer. Returns true when
-- the kill should go on the scoreboard.
function MatchService.addKill(side)
	if mode == "SND" then
		return side ~= nil and BombRound.inPlay(state)
	end
	if side and MatchState.addKill(rules, state, side) then
		MatchService.broadcast()
		return true
	end
	return false
end

-- Takes a point back from `side`: a revive has undone the kill that scored it.
function MatchService.removeKill(side)
	if mode ~= "SND" and side and MatchState.removeKill(state, side) then
		MatchService.broadcast()
		return true
	end
	return false
end

-- SND. Each returns true when it counted.
function MatchService.plantBomb()
	if mode == "SND" and BombRound.plant(MatchConfig, state) then
		changed:Fire("Planted")
		MatchService.broadcast()
		return true
	end
	return false
end

function MatchService.defuseBomb()
	if mode == "SND" and BombRound.defuse(MatchConfig, state) then
		changed:Fire("RoundOver")
		MatchService.broadcast()
		return true
	end
	return false
end

local function bombCounts()
	local counts = { players = 0, attackers = 0, attackersAlive = 0, defenders = 0, defendersAlive = 0 }
	for _, player in Players:GetPlayers() do
		counts.players += 1
		local team = player.Team and player.Team.Name
		if team then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local alive = humanoid ~= nil and humanoid.Health > 0
			local side = if team == state.attackers then "attackers" else "defenders"
			counts[side] += 1
			if alive then
				counts[side .. "Alive"] += 1
			end
		end
	end
	return counts
end

-- How many players the rules are told about. While waiting, that is nobody
-- until the warm-up is over: everyone the lobby sent has arrived, or the
-- warm-up time is up and there are enough to play.
local function playersCounted(dt)
	local present = #Players:GetPlayers()
	if state.phase ~= "Waiting" then
		waited = 0
		-- A match is not called off because somebody left: it carries on
		-- short-handed while their place is offered to the queue, and is
		-- settled by `abandoned` if a whole side goes. Only an empty server
		-- drops back to waiting.
		return if present > 0 then math.max(present, MatchConfig.minPlayers) else 0
	end
	if returning then
		return 0 -- whoever is still here is on their way out, not starting another match
	end
	waited = if present > 0 then waited + dt else 0
	local everyoneHere = present >= MatchSettings.current().expected
	local longEnough = waited >= MatchConfig.warmupTime and present >= MatchConfig.minPlayers
	return if everyoneHere or longEnough then present else 0
end

-- The side that wins because nobody else is left, once that has been so for
-- long enough for a replacement to have arrived. Nil otherwise, and always
-- nil when minPlayers allows a match of one: that is somebody testing alone.
local function abandoned(dt)
	local last = nil
	if MatchConfig.minPlayers < 2 then
		last = nil
	elseif mode == "FFA" then
		-- A player who leaves takes their side with them, so count heads.
		local here = Players:GetPlayers()
		last = if #here == 1 then here[1].Name else nil
	else
		local counts = {}
		for side in state.scores do
			counts[side] = 0
		end
		for _, player in Players:GetPlayers() do
			local side = player.Team and player.Team.Name
			if side and counts[side] then
				counts[side] += 1
			end
		end
		last = Backfill.lastSide(counts)
	end
	abandonedFor = if last then abandonedFor + dt else 0
	return if abandonedFor >= MatchConfig.forfeitAfter then last else nil
end

-- After a match the lobby set up, everyone goes back to the lobby, and the
-- server plays nothing more. It keeps sending for as long as anybody is here:
-- a teleport can fail, and somebody who was on their way in when the match
-- ended arrives after everyone else has gone. A player who still cannot be
-- sent after `giveUpAfter` is removed with a message, since joining the game
-- again puts them in the lobby, which is better than being left here.
local function returnToLobby()
	if returning or not MatchSettings.current().fromLobby or LobbyConfig.lobbyPlaceId == 0 then
		return
	end
	returning = true
	local back = MatchConfig.lobbyReturn
	local askedAt = {} -- [player] = when this server first tried to send them
	while true do
		local now = os.clock()
		local going, stillAsked = {}, {}
		for _, player in Players:GetPlayers() do
			stillAsked[player] = askedAt[player] or now
			if now - stillAsked[player] >= back.giveUpAfter then
				player:Kick(back.message)
			else
				table.insert(going, player)
			end
		end
		askedAt = stillAsked
		if #going > 0 then
			local ok, problem = Travel.send(LobbyConfig.lobbyPlaceId, going)
			if not ok then
				warn(`MatchService: could not send players back to the lobby: {problem}`)
			end
		end
		task.wait(back.retryEvery)
	end
end

local function chooseMode()
	local wanted = MatchSettings.current().mode
	if wanted == "FFA" then
		mode = "FFA"
		rules = FFA_RULES
		state = MatchState.new(FFA_RULES)
		-- Each player is a side.
		for _, player in Players:GetPlayers() do
			MatchState.join(state, player.Name)
		end
		Players.PlayerAdded:Connect(function(player)
			MatchState.join(state, player.Name)
		end)
		Players.PlayerRemoving:Connect(function(player)
			MatchState.leave(state, player.Name)
		end)
	elseif wanted == "SND" then
		local map = workspace:FindFirstChild("Map")
		local sites = map and map:FindFirstChild("Sites")
		if sites and #sites:GetChildren() > 0 then
			mode = "SND"
			state = BombRound.new(MatchConfig)
		else
			warn("MatchService: this map has no sites, so the match is TDM")
		end
	end
end

function MatchService.init()
	chooseMode()

	local sinceBroadcast = 0
	RunService.Heartbeat:Connect(function(dt)
		local counted = playersCounted(dt)
		local event
		if mode == "SND" then
			local counts = bombCounts()
			counts.players = counted
			event = BombRound.tick(MatchConfig, state, dt, counts)
		else
			event = MatchState.tick(rules, state, dt, counted)
		end

		-- Everyone on the other side has gone and nobody came to replace them.
		local winner = if event then nil else abandoned(dt)
		if winner then
			abandonedFor = 0
			event = if mode == "SND"
				then BombRound.forfeit(MatchConfig, state, winner)
				else MatchState.forfeit(rules, state, winner)
		end

		if event == "Ended" or event == "MatchOver" then
			finished = true
		elseif event == "Reset" and finished then
			finished = false
			task.spawn(returnToLobby)
		end

		sinceBroadcast += dt
		if event then
			changed:Fire(event)
			if event == "Started" then
				started:Fire()
			elseif event == "RoundStarted" then
				roundStarted:Fire()
			end
		end
		if event or sinceBroadcast >= 1 then
			sinceBroadcast = 0
			MatchService.broadcast()
		end
	end)
end

return MatchService
