-- Standing with a class of weapon: the material and tier a player's
-- experience with it has earned. `prestiges` is the ladder from
-- ProgressConfig: a list of { name, tiers, xp }, lowest first. Pure rules.
--
-- A standing is never stored as a position on the ladder, only worked out
-- here, so the ladder can change shape without anybody's progress being lost.

local Prestige = {}

-- The class a weapon earns experience for, or nil if it earns none.
function Prestige.classOf(weaponConfig)
	if weaponConfig.kind == "Bomb" then
		return nil
	end
	return weaponConfig.class
end

-- The ladder as one list of steps: { name, tier, cost }, where `cost` is the
-- experience it takes to climb off that step.
local function stepsOf(prestiges)
	local steps = {}
	for _, material in prestiges do
		for tier = 1, material.tiers do
			table.insert(steps, { name = material.name, tier = tier, cost = material.xp })
		end
	end
	return steps
end

-- Where a remembered standing sits on today's ladder, or nil if its material
-- is no longer there. A tier the material no longer has counts as its last.
local function find(steps, peak)
	local found = nil
	for index, step in steps do
		if step.name == peak.name and step.tier <= peak.tier then
			found = index
		end
	end
	return found
end

-- A player's standing: { step, steps, name, tier, title, into, needed }.
-- `into` is experience earned towards the next step and `needed` what that
-- step costs, or nil at the top. `peak` is the highest standing they have
-- held, as Prestige.peak gave it; they are never shown lower than that.
function Prestige.standing(prestiges, xp, peak)
	local steps = stepsOf(prestiges)
	local at, spent = 1, 0
	while at < #steps and xp - spent >= steps[at].cost do
		spent += steps[at].cost
		at += 1
	end
	local into = xp - spent

	local held = peak and find(steps, peak)
	if held and held > at then
		at, into = held, 0 -- theirs already; experience has to catch up before it counts again
	end

	local step = steps[at]
	return {
		step = at,
		steps = #steps,
		name = step.name,
		tier = step.tier,
		title = step.name .. " " .. step.tier,
		into = into,
		needed = if at < #steps then step.cost else nil,
	}
end

-- What to remember of a standing, so that it survives the ladder changing.
function Prestige.peak(standing)
	return { name = standing.name, tier = standing.tier }
end

-- Adds experience to a class. `record` is what is saved for it: { xp, peak }.
-- Returns the new standing, and whether it is higher than before.
function Prestige.earn(prestiges, record, amount)
	local before = Prestige.standing(prestiges, record.xp, record.peak)
	record.xp += amount
	local after = Prestige.standing(prestiges, record.xp, record.peak)
	record.peak = Prestige.peak(after)
	return after, after.step > before.step
end

return Prestige
