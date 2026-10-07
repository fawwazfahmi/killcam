-- Matching players who are waiting in different copies of the lobby.
--
-- Every lobby server lists the groups it has queued for a mode in one shared
-- record, the pool. Any lobby may make a match out of what is listed there,
-- whoever's groups they are; each lobby then finds its own groups in that
-- match and sends them. There is one pool per mode.
--
--   pool = {
--     lobbies = { [lobby] = { seen = number, groups = { { n, size, since }, ... } } },
--     gathering = number?,  -- when there were first enough listed for a match
--     matches = { { code, at, groups = { { lobby, n, side }, ... } }, ... },
--   }
--
-- `lobby` names one lobby server. `n` is a number that server gave the group
-- when it queued and never uses again, `size` how many players are in it and
-- `since` when it queued. A lobby that stops looking (it crashed, or emptied)
-- is dropped once it has not been `seen` for a while. A match is kept for a
-- while after it is made, so that every lobby has the time to read it: `code`
-- is what sends players to its server, and `side` the team (1 or 2) a group
-- is to be on, or nil where there are no teams.
--
-- Pure rules. `now` is a clock in seconds that every server agrees on, such
-- as os.time(). Nothing here changes the pool it is given. `pick` is the
-- mode's matchmaking rule: given the sizes of the waiting groups, longest
-- wait first, and whether they have had their gather time, it returns which
-- of them make a match (see Queue.pick), or nil.

local Pool = {}

-- Every group listed, the longest-waiting first: { lobby, n, size, since }.
function Pool.waiting(pool)
	local waiting = {}
	for lobby, block in (type(pool) == "table" and pool.lobbies) or {} do
		for _, group in block.groups do
			table.insert(waiting, { lobby = lobby, n = group.n, size = group.size, since = group.since })
		end
	end
	-- Ties are broken the same way on every server, so that they all plan the same match.
	table.sort(waiting, function(a, b)
		if a.since ~= b.since then
			return a.since < b.since
		elseif a.lobby ~= b.lobby then
			return a.lobby < b.lobby
		end
		return a.n < b.n
	end)
	return waiting
end

-- How many players are listed, in every lobby together.
function Pool.count(pool)
	local players = 0
	for _, group in Pool.waiting(pool) do
		players += group.size
	end
	return players
end

local function sizesOf(waiting)
	local sizes = {}
	for index, group in waiting do
		sizes[index] = group.size
	end
	return sizes
end

-- A lobby looking at the pool, which it does every couple of seconds while it
-- has anybody queued. `groups` is what that lobby has waiting now, as
-- { n, size, since }: this replaces whatever it listed before, so a group
-- that has left the queue is simply no longer in it. Lobbies that have
-- stopped looking are dropped, and so are matches every lobby has had the
-- time to read. `config` is LobbyConfig.pool. Returns the pool as it should
-- be stored.
function Pool.refresh(pool, lobby, groups, now, config, pick)
	pool = if type(pool) == "table" then pool else {}

	-- A group that has been put in a match is not waiting any more, even
	-- though its lobby has not sent it yet.
	local matches, matched = {}, {}
	for _, match in pool.matches or {} do
		if now - match.at <= config.matchLasts then
			table.insert(matches, match)
			for _, group in match.groups do
				if group.lobby == lobby then
					matched[group.n] = true
				end
			end
		end
	end

	local lobbies = {}
	for name, block in pool.lobbies or {} do
		if name ~= lobby and #block.groups > 0 and now - block.seen <= config.lobbyLasts then
			lobbies[name] = block
		end
	end
	local mine = {}
	for _, group in groups do
		if not matched[group.n] then
			table.insert(mine, { n = group.n, size = group.size, since = group.since })
		end
	end
	if #mine > 0 then
		lobbies[lobby] = { seen = now, groups = mine }
	end

	local updated = { lobbies = lobbies, matches = matches }
	-- The gather time runs from when there were first enough for a match, and
	-- starts again if there stop being.
	if pick(sizesOf(Pool.waiting(updated)), true) then
		updated.gathering = pool.gathering or now
	end
	return updated
end

-- The match that could be made out of the pool now, or nil to keep waiting:
-- { groups = { { lobby, n, size, side }, ... }, players = how many that is }.
-- A full match goes at once and anything smaller waits out `gatherTime`.
function Pool.plan(pool, pick, now, gatherTime)
	if type(pool) ~= "table" then
		return nil
	end
	local waiting = Pool.waiting(pool)
	local gathered = pool.gathering ~= nil and now - pool.gathering >= gatherTime
	local picked = pick(sizesOf(waiting), gathered)
	if not picked then
		return nil
	end
	local plan = { groups = {}, players = 0 }
	for place, index in picked.groups do
		local group = waiting[index]
		plan.groups[place] = {
			lobby = group.lobby,
			n = group.n,
			size = group.size,
			side = if picked.sides then picked.sides[place] else nil,
		}
		plan.players += group.size
	end
	return plan
end

-- Whether any of a plan's groups are waiting in this lobby.
function Pool.involves(plan, lobby)
	for _, group in plan.groups do
		if group.lobby == lobby then
			return true
		end
	end
	return false
end

-- Turning a plan into a match, for which a server has been reserved with
-- access code `code`. Two lobbies may have planned with the same groups, so
-- this is all or nothing: it only goes through if every group in the plan is
-- still listed. Returns the pool as it should be stored and true; or nil and
-- false, in which case nothing should be stored.
function Pool.commit(pool, plan, code, now)
	if type(pool) ~= "table" or type(pool.lobbies) ~= "table" then
		return nil, false
	end
	local taken = {} -- [lobby] = { [n] = true }
	for _, group in plan.groups do
		local block = pool.lobbies[group.lobby]
		local listed = false
		for _, other in (block and block.groups) or {} do
			if other.n == group.n then
				listed = true
				break
			end
		end
		if not listed then
			return nil, false
		end
		taken[group.lobby] = taken[group.lobby] or {}
		taken[group.lobby][group.n] = true
	end

	local lobbies = {}
	for name, block in pool.lobbies do
		local left = {}
		for _, group in block.groups do
			if not (taken[name] and taken[name][group.n]) then
				table.insert(left, group)
			end
		end
		if #left > 0 then
			lobbies[name] = { seen = block.seen, groups = left }
		end
	end

	local match = { code = code, at = now, groups = {} }
	for place, group in plan.groups do
		match.groups[place] = { lobby = group.lobby, n = group.n, side = group.side }
	end
	local matches = table.clone(pool.matches or {})
	table.insert(matches, match)
	-- Whoever is left starts their gather time again.
	return { lobbies = lobbies, matches = matches }, true
end

-- The matches that have groups of this lobby in them, for it to send:
-- { { code, at, groups = { { n, side }, ... } }, ... }.
function Pool.mine(pool, lobby)
	local found = {}
	for _, match in (type(pool) == "table" and pool.matches) or {} do
		local groups = {}
		for _, group in match.groups do
			if group.lobby == lobby then
				table.insert(groups, { n = group.n, side = group.side })
			end
		end
		if #groups > 0 then
			table.insert(found, { code = match.code, at = match.at, groups = groups })
		end
	end
	return found
end

return Pool
