-- Attack and defend rules as a state machine.
--
--   Waiting -> Prep -> Live -> (Planted ->) RoundOver -> Prep ... -> MatchOver -> Waiting
--
-- One team attacks and must plant the bomb at a site and keep it there until
-- it goes off. The other defends. Nobody respawns during a round.
--
-- A round goes to the attackers if every defender is dead or the bomb goes
-- off, and to the defenders if every attacker is dead before the plant, the
-- clock runs out before the plant, or the bomb is defused. Once the bomb is
-- down, killing the attackers is not enough: it still has to be defused.
--
-- `counts` passed to tick is { players, attackers, attackersAlive, defenders,
-- defendersAlive }. A side with no members at all is never "eliminated", so a
-- match can be run alone while testing.

local BombRound = {}

local function reset(config, state)
	state.phase = "Waiting"
	state.timeLeft = 0
	state.round = 0
	state.attackers = config.teams[1]
	state.winner = nil
	state.roundWinner = nil
	state.reason = nil
	for _, team in config.teams do
		state.scores[team] = 0
	end
end

local function beginRound(config, state)
	state.round += 1
	state.phase = "Prep"
	state.timeLeft = config.bomb.prepTime
	state.roundWinner = nil
	state.reason = nil
	-- Sides swap once, after `swapAfter` rounds.
	state.attackers = if state.round > config.bomb.swapAfter then config.teams[2] else config.teams[1]
end

local function endRound(config, state, winner, reason)
	state.scores[winner] += 1
	state.roundWinner = winner
	state.reason = reason
	state.phase = "RoundOver"
	state.timeLeft = config.bomb.roundEndTime
end

function BombRound.new(config)
	local state = { scores = {} }
	reset(config, state)
	return state
end

function BombRound.defenders(config, state)
	return if state.attackers == config.teams[1] then config.teams[2] else config.teams[1]
end

-- True while players can shoot, plant and defuse.
function BombRound.inPlay(state)
	return state.phase == "Live" or state.phase == "Planted"
end

-- Advances time. Returns the name of what just happened, or nil:
--   "Started"       a match began; its first round is in Prep
--   "RoundStarted"  a later round is in Prep
--   "Live"          Prep ended
--   "Exploded"      the bomb went off; the round is over
--   "RoundOver"     the round ended any other way
--   "MatchOver"     a team reached the rounds needed
--   "Reset"         back to Waiting
function BombRound.tick(config, state, dt, counts)
	local rules = config.bomb
	if state.phase == "Waiting" then
		if counts.players >= config.minPlayers then
			reset(config, state)
			beginRound(config, state)
			return "Started"
		end
		return nil
	end
	if counts.players < config.minPlayers then
		reset(config, state)
		return "Reset"
	end

	local attackersOut = counts.attackers > 0 and counts.attackersAlive == 0
	local defendersOut = counts.defenders > 0 and counts.defendersAlive == 0

	if state.phase == "Prep" then
		state.timeLeft -= dt
		if state.timeLeft <= 0 then
			state.phase = "Live"
			state.timeLeft = rules.roundTime
			return "Live"
		end
	elseif state.phase == "Live" then
		if attackersOut then
			endRound(config, state, BombRound.defenders(config, state), "Eliminated")
			return "RoundOver"
		elseif defendersOut then
			endRound(config, state, state.attackers, "Eliminated")
			return "RoundOver"
		end
		state.timeLeft -= dt
		if state.timeLeft <= 0 then
			endRound(config, state, BombRound.defenders(config, state), "TimeUp")
			return "RoundOver"
		end
	elseif state.phase == "Planted" then
		if defendersOut then
			endRound(config, state, state.attackers, "Eliminated")
			return "RoundOver"
		end
		state.timeLeft -= dt
		if state.timeLeft <= 0 then
			endRound(config, state, state.attackers, "Exploded")
			return "Exploded"
		end
	elseif state.phase == "RoundOver" then
		state.timeLeft -= dt
		if state.timeLeft <= 0 then
			if state.scores[state.roundWinner] >= rules.roundsToWin then
				state.phase = "MatchOver"
				state.winner = state.roundWinner
				state.timeLeft = config.endDuration
				return "MatchOver"
			end
			beginRound(config, state)
			return "RoundStarted"
		end
	else -- MatchOver
		state.timeLeft -= dt
		if state.timeLeft <= 0 then
			reset(config, state)
			return "Reset"
		end
	end
	return nil
end

-- Ends a match in progress with `winner` taking it (the other team has left).
-- Returns "MatchOver", or nil if no match was being played.
function BombRound.forfeit(config, state, winner)
	if state.phase == "Waiting" or state.phase == "MatchOver" then
		return nil
	end
	state.phase = "MatchOver"
	state.winner = winner
	state.reason = "Forfeit"
	state.timeLeft = config.endDuration
	return "MatchOver"
end

-- Returns true when the plant counted.
function BombRound.plant(config, state)
	if state.phase ~= "Live" then
		return false
	end
	state.phase = "Planted"
	state.timeLeft = config.bomb.fuseTime
	return true
end

-- Returns true when the defuse counted.
function BombRound.defuse(config, state)
	if state.phase ~= "Planted" then
		return false
	end
	endRound(config, state, BombRound.defenders(config, state), "Defused")
	return true
end

return BombRound
