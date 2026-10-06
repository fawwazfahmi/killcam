-- Matchmaking arithmetic. Pure rules; `rules` is one mode's entry in
-- LobbyConfig.modes: { min, max, teams }.

local Queue = {}

-- The most players one match of this mode takes. A team mode needs two equal
-- sides, so an odd maximum is rounded down.
function Queue.capacity(rules)
	return if rules.teams then rules.max - rules.max % 2 else rules.max
end

-- How many of the `waiting` players should be sent into a match now: 0 to keep
-- waiting. `gathered` is true once the queue has had its time to collect more.
--
-- A full match goes at once. Otherwise the queue needs its minimum and its
-- gather time. A team mode only ever sends an even number, so whoever joined
-- last waits for the next match rather than making the teams lopsided.
function Queue.launchSize(rules, waiting, gathered)
	local size = math.min(waiting, Queue.capacity(rules))
	if rules.teams then
		size -= size % 2
	end
	if size < rules.min then
		return 0
	end
	if size >= Queue.capacity(rules) or gathered then
		return size
	end
	return 0
end

local MOST_GROUPS = 16 -- only this many groups at the front of a queue are considered

-- A way to make `total` out of some of `sizes`, taking earlier groups first.
-- Returns the indices used, or nil. `from` is where to start looking.
local function choose(sizes, total, from)
	if total == 0 then
		return {}
	end
	for index = from, math.min(#sizes, MOST_GROUPS) do
		if sizes[index] <= total then
			local rest = choose(sizes, total - sizes[index], index + 1)
			if rest then
				table.insert(rest, 1, index)
				return rest
			end
		end
	end
	return nil
end

-- Every way to make `total` out of some of `sizes`, earliest groups first,
-- handed one at a time to `try` until it returns something.
local function eachChoice(sizes, total, from, picked, try)
	if total == 0 then
		return try(picked)
	end
	for index = from, math.min(#sizes, MOST_GROUPS) do
		if sizes[index] <= total then
			table.insert(picked, index)
			local found = eachChoice(sizes, total - sizes[index], index + 1, picked, try)
			table.remove(picked)
			if found then
				return found
			end
		end
	end
	return nil
end

-- Which of the waiting groups to send into a match now, or nil to keep
-- waiting. `sizes` is how many players are in each group, in the order they
-- queued: 1 for somebody alone, more for a squad. A group is never split
-- between matches, and in a team mode never between teams.
--
-- Returns { groups = indices into `sizes`, sides = the team (1 or 2) of each
-- of those groups, or nil when the mode has no teams }.
--
-- As with launchSize, a full match goes at once and anything smaller needs
-- the queue's minimum and its gather time. A team mode only launches when
-- the groups can make two sides of the same size.
function Queue.pick(rules, sizes, gathered)
	local capacity = Queue.capacity(rules)
	local smallest = if gathered then rules.min else capacity
	for total = capacity, smallest, -1 do
		if not rules.teams then
			local groups = choose(sizes, total, 1)
			if groups then
				return { groups = groups }
			end
		elseif total % 2 == 0 then
			local found = eachChoice(sizes, total, 1, {}, function(picked)
				-- Can these groups stand as two equal sides?
				local chosen = {}
				for place, index in picked do
					chosen[place] = sizes[index]
				end
				local first = choose(chosen, total / 2, 1)
				if not first then
					return nil
				end
				local sides = table.create(#picked, 2)
				for _, place in first do
					sides[place] = 1
				end
				return { groups = table.clone(picked), sides = sides }
			end)
			if found then
				return found
			end
		end
	end
	return nil
end

-- How many players have to move from the bigger side to the smaller one for
-- two teams to be as even as they can be (a difference of at most one).
function Queue.movesToBalance(larger, smaller)
	return math.max((larger - smaller) // 2, 0)
end

return Queue
