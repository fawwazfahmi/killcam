-- The test range has no teams. Admins there together cannot hurt each other;
-- everything they do is done to the dummies, or to themselves. This answers
-- for the range what the match place's TeamService answers there.

local TeamService = {}

function TeamService.assign(player)
	player.Neutral = true
end

function TeamService.beforeSpawn(_player) end

-- True, so that a player appears at any of the range's spawns.
function TeamService.isFreeForAll()
	return true
end

function TeamService.teamName(_player)
	return nil
end

function TeamService.scoreKey(player)
	return player.Name
end

function TeamService.areEnemies(_a, _b)
	return false
end

return TeamService
