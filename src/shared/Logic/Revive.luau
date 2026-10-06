-- Coming back to life for Robux: who may, and what it changes. Pure rules over
-- MatchConfig.revive; the buying and the respawning are in ReviveService.

local Revive = {}

-- The rules for `mode`, or nil when revives are switched off or the mode has none.
function Revive.rules(config, mode)
	if config.productId == 0 then
		return nil
	end
	return config.modes[mode]
end

-- `used` is how many revives this player has taken in the current round or
-- match, whichever the rules count by.
function Revive.available(rules, used)
	return rules ~= nil and used < rules.limit
end

-- True if the count of revives used starts again at this match event.
function Revive.resetsOn(rules, event)
	return event == "Started" or (event == "RoundStarted" and rules.per == "round")
end

-- What taking a revive does to the scoreboard, each 0 or -1:
--   deaths  the revived player's own count
--   points  the score of the side that killed them
--   kills   the killer's own count
-- `scored` is whether the kill had counted for the other side.
function Revive.undo(rules, scored)
	if not rules.undo then
		return { deaths = 0, points = 0, kills = 0 }
	end
	local taken = if scored then -1 else 0
	return { deaths = -1, points = taken, kills = taken }
end

return Revive
