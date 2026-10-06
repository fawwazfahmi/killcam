-- What a player did in a match, turned into one number, so the podium and the
-- MVP can be decided the same way everywhere. Pure rules.
--
-- `weights` is one mode's entry in MatchConfig.mvp: how much a kill, a plant
-- and a defuse are each worth. A mode without objectives simply has no weight
-- for them, so its score is its kills.
--
-- A player's `stats` is { kills, deaths, plants, defuses }.

local Score = {}

local COUNTED = { kill = "kills", plant = "plants", defuse = "defuses" }

function Score.of(weights, stats)
	local total = 0
	for weight, field in COUNTED do
		total += (stats[field] or 0) * (weights[weight] or 0)
	end
	return total
end

-- `results` is a list of stats tables, each with a `name`. Returns a sorted
-- copy, best first, with a `score` added to each: highest score, then fewest
-- deaths, then by name so the order never wobbles.
function Score.rank(weights, results)
	local sorted = {}
	for index, result in results do
		local copy = table.clone(result)
		copy.score = Score.of(weights, result)
		sorted[index] = copy
	end
	table.sort(sorted, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		elseif a.deaths ~= b.deaths then
			return a.deaths < b.deaths
		end
		return a.name < b.name
	end)
	return sorted
end

-- The best `count` of them.
function Score.top(weights, results, count)
	local sorted = Score.rank(weights, results)
	local top = {}
	for index = 1, math.min(count, #sorted) do
		top[index] = sorted[index]
	end
	return top
end

-- The match's most valuable player, whichever side they were on. Nil if
-- nobody scored at all, or if the top place is an exact tie.
function Score.mvp(weights, results)
	local sorted = Score.rank(weights, results)
	local best, second = sorted[1], sorted[2]
	if not best or best.score <= 0 then
		return nil
	end
	if second and second.score == best.score and second.deaths == best.deaths then
		return nil
	end
	return best.name
end

-- A short summary of what a player did, for the end-of-match screens:
-- "9 kills", or "6 kills, 2 plants" when the objective counted too.
function Score.summary(stats)
	local parts = { string.format("%d kills", stats.kills or 0) }
	for _, pair in { { "plants", "plants" }, { "defuses", "defuses" } } do
		local count = stats[pair[1]] or 0
		if count > 0 then
			table.insert(parts, string.format("%d %s", count, pair[2]))
		end
	end
	return table.concat(parts, ", ")
end

return Score
