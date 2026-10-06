-- Match rules as a small state machine: Waiting -> Playing -> Ended -> Waiting.
--
-- Scores are kept per side. In a team match the sides are config.teams. In a
-- free-for-all config.teams is empty and each player is a side, added with
-- join and removed with leave.

local MatchState = {}

local function reset(config, state)
	state.phase = "Waiting"
	state.timeLeft = 0
	state.endTimer = 0
	state.winner = nil
	for side in state.scores do
		state.scores[side] = 0
	end
	for _, team in config.teams do
		state.scores[team] = 0
	end
end

local function finish(config, state, winner)
	state.phase = "Ended"
	state.winner = winner
	state.endTimer = config.endDuration
end

local function leader(state)
	local best, bestScore, tied = nil, -1, false
	for side, score in state.scores do
		if score > bestScore then
			best, bestScore, tied = side, score, false
		elseif score == bestScore then
			tied = true
		end
	end
	return (tied or not best) and "Draw" or best
end

-- Free-for-all: a player arrives or leaves. A new side starts on zero.
function MatchState.join(state, side)
	if state.scores[side] == nil then
		state.scores[side] = 0
	end
end

function MatchState.leave(state, side)
	state.scores[side] = nil
end

function MatchState.new(config)
	local state = { scores = {} }
	reset(config, state)
	return state
end

-- Advances time. Returns "Started", "Ended" or "Reset" when the phase changes.
function MatchState.tick(config, state, dt, playerCount)
	if state.phase == "Waiting" then
		if playerCount >= config.minPlayers then
			reset(config, state)
			state.phase = "Playing"
			state.timeLeft = config.timeLimit
			return "Started"
		end
	elseif state.phase == "Playing" then
		if playerCount < config.minPlayers then
			reset(config, state)
			return "Reset"
		end
		state.timeLeft -= dt
		if state.timeLeft <= 0 then
			state.timeLeft = 0
			finish(config, state, leader(state))
			return "Ended"
		end
	else
		state.endTimer -= dt
		if state.endTimer <= 0 then
			reset(config, state)
			return "Reset"
		end
	end
	return nil
end

-- Returns true when the kill counted.
function MatchState.addKill(config, state, team)
	if state.phase ~= "Playing" or state.scores[team] == nil then
		return false
	end
	state.scores[team] += 1
	if state.scores[team] >= config.scoreLimit then
		finish(config, state, team)
	end
	return true
end

-- Ends a match in progress with `winner` taking it (everyone else has left).
-- Returns "Ended", or nil if no match was being played.
function MatchState.forfeit(config, state, winner)
	if state.phase ~= "Playing" then
		return nil
	end
	finish(config, state, winner)
	return "Ended"
end

-- Takes back a point (a revive undoing the kill that scored it). Returns
-- true if it came off.
function MatchState.removeKill(state, team)
	if state.phase ~= "Playing" or not state.scores[team] or state.scores[team] <= 0 then
		return false
	end
	state.scores[team] -= 1
	return true
end

return MatchState
