-- Who a dead player may watch: living teammates, and nobody else, so the dead
-- cannot scout the other team for the living. Pure rules.

local Spectate = {}

-- `others` is { { name, team, alive } } for every other player. Returns the
-- names that a viewer on `team` may watch, in a steady order. With no team
-- (a free-for-all, or the warm-up) there is nobody.
function Spectate.targets(team, others)
	local names = {}
	if team == nil then
		return names
	end
	for _, other in others do
		if other.alive and other.team == team then
			table.insert(names, other.name)
		end
	end
	table.sort(names)
	return names
end

-- What a dead player sees when the killcam is over, or was skipped:
--   "Teammate"  through a living teammate's eyes
--   "Killer"    whoever killed them, followed from behind
--   "Body"      their own body, from outside
--   "Killcam"   nothing new: it stays up until they respawn
--
-- It turns on whether they are `out` until the round ends (Search and
-- Destroy) or about to respawn (everything else). Out, they watch a teammate
-- for the rest of the round, or their own body if none is left. About to
-- respawn, there is no spectating: the killcam holds until they are back,
-- and skipping it follows the killer instead. `killer` is whether another
-- player killed them at all.
function Spectate.afterKillcam(out, teammates, skipped, killer)
	if out then
		return if teammates > 0 then "Teammate" else "Body"
	elseif not killer then
		return "Body"
	end
	return if skipped then "Killer" else "Killcam"
end

-- The name to watch after `current`, going forwards (1) or back (-1) through
-- `names`. The first if `current` is nobody, or no longer in the list; nil if
-- there is nobody at all.
function Spectate.step(names, current, direction)
	if #names == 0 then
		return nil
	end
	local at = table.find(names, current)
	if not at then
		return names[1]
	end
	return names[(at - 1 + direction) % #names + 1]
end

return Spectate
