-- The test range's damage readout: the hits just landed, and what they add up
-- to. Pure rules.
--
-- A hit is { target, weapon, zone, raw, amount, left, lethal, distance }:
--   target    which dummy (or "you", for damage taken)
--   raw       what the weapon does there before armour
--   amount    what it did after armour
--   left      the target's health afterwards
--   lethal    whether it killed, or would have
--
-- Hits on one target with no long gap between them are a run. The totals are
-- for the run in progress, and a kill closes it.

local Readout = {}

function Readout.new()
	return { lines = {}, run = nil }
end

-- Adds a hit that landed at `now`. Returns the run it belongs to.
function Readout.add(rules, state, hit, now)
	local run = state.run
	if not run or run.closed or run.target ~= hit.target or now - run.lastAt > rules.runGap then
		run = { target = hit.target, weapon = hit.weapon, hits = 0, damage = 0, first = hit.amount, firstAt = now }
		state.run = run
	end
	run.hits += 1
	run.damage += hit.amount
	run.lastAt = now
	if hit.lethal then
		run.closed = true
		run.killHits = run.hits
		run.killTime = now - run.firstAt
	end

	table.insert(state.lines, hit)
	while #state.lines > rules.lines do
		table.remove(state.lines, 1)
	end
	return run
end

function Readout.clear(state)
	table.clear(state.lines)
	state.run = nil
end

-- What a run adds up to:
--   hits, damage  how many landed and what they took off in all
--   seconds       from the first hit to the last
--   perSecond     damage a second while it lasted, or nil for a single hit.
--                 The first hit starts the clock, so it is left out of the
--                 damage: four hits a tenth of a second apart are three
--                 tenths of a second of fire, and that is three hits' worth
--   killHits      hits it took to kill, or nil if it has not
--   killTime      seconds from the first hit to the kill
function Readout.totals(run)
	local seconds = run.lastAt - run.firstAt
	return {
		hits = run.hits,
		damage = run.damage,
		seconds = seconds,
		perSecond = if seconds > 0 then (run.damage - run.first) / seconds else nil,
		killHits = run.killHits,
		killTime = run.killTime,
	}
end

-- What the numbers say it should take to bring `health` down with hits of
-- `perHit`, `interval` seconds apart: how many hits, and how long from the
-- first to the last. Nil if the hits do nothing.
function Readout.onPaper(perHit, interval, health)
	if perHit <= 0 then
		return nil
	end
	local hits = math.ceil(health / perHit)
	return { hits = hits, seconds = (hits - 1) * interval }
end

return Readout
