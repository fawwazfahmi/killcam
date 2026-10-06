-- A player's rank, read from their level. `ranks` is ShopConfig.ranks: a list
-- of { name, grades }, lowest first. Level 1 is the first grade of the first
-- rank, and each level after it is the next grade up. Pure rules.

local Rank = {}

-- The highest level there is: the last grade of the last rank.
function Rank.maxLevel(ranks)
	local total = 0
	for _, rank in ranks do
		total += rank.grades
	end
	return total
end

-- { index, name, grade, grades, title } for a level. `title` is how it is
-- written: "Sergeant 3", or just the name for a rank with a single grade.
-- A level outside the ladder counts as its nearest end.
function Rank.of(ranks, level)
	level = math.clamp(level, 1, Rank.maxLevel(ranks))
	local below = 0
	for index, rank in ranks do
		if level <= below + rank.grades then
			local grade = level - below
			return {
				index = index,
				name = rank.name,
				grade = grade,
				grades = rank.grades,
				title = if rank.grades > 1 then rank.name .. " " .. grade else rank.name,
			}
		end
		below += rank.grades
	end
	return nil
end

return Rank
