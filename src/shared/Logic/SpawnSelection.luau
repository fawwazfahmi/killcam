local SpawnSelection = {}

-- Returns the index of the spawn point farthest from its nearest enemy.
-- Positions are anything with X, Y and Z fields. `randomIndex(n)` returns an
-- integer from 1 to n and is used when there are no enemies to avoid.
function SpawnSelection.pick(spawns, enemies, randomIndex)
	local count = #spawns
	if count == 0 then
		return nil
	end
	if #enemies == 0 then
		return randomIndex(count)
	end

	local bestIndex, bestDistance = 1, -1
	for index, spawn in spawns do
		local nearest = math.huge
		for _, enemy in enemies do
			local dx, dy, dz = spawn.X - enemy.X, spawn.Y - enemy.Y, spawn.Z - enemy.Z
			nearest = math.min(nearest, math.sqrt(dx * dx + dy * dy + dz * dz))
		end
		if nearest > bestDistance then
			bestIndex, bestDistance = index, nearest
		end
	end
	return bestIndex
end

return SpawnSelection
