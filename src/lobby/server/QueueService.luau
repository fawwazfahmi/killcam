-- Matchmaking in the lobby. Players queue for a mode and stay in the lobby
-- until there is a match for them.
--
-- What waits in a queue is a group: one player, or a squad. A group is never
-- split between matches, or between teams.
--
-- There are as many copies of the lobby as the players need, and those in
-- different copies are matched with each other. Each lobby lists its queued
-- groups in a record all of them share, one per mode (see Shared.Logic.Pool).
-- Whichever lobby sees that a match can be made reserves a private server for
-- it, leaves the mode and map where that server will look, and writes the
-- match into the record; every lobby then sends its own groups to it.
--
-- Matches already running that have lost a player are filled first (see
-- Shared.Logic.Backfill).
--
-- A group is listed in the shared record or on its way somewhere, never both:
-- it is taken off the list before a place in a running match is claimed for it.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local Backfill = require(Shared.Logic.Backfill)
local Pool = require(Shared.Logic.Pool)
local Queue = require(Shared.Logic.Queue)
local Remotes = require(Shared.Remotes)

local Travel = require(script.Parent.Travel)

local QueueService = {}

local POOL = LobbyConfig.pool
local SEATS = LobbyConfig.backfill
-- What this lobby server calls itself in the shared record. A Studio test has
-- no job id, so it makes one up.
local LOBBY = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
-- Until the match place has an id nobody can be sent anywhere. The queues
-- still work, against a record kept in this server alone, so they can be tried.
local PUBLISHED = LobbyConfig.matchPlaceId ~= 0
local SOONEST = 1 -- seconds between looks at the shared record, however much is happening
local POLL = 0.25 -- seconds between checks for a reason to look sooner than usual

local profileStore, squads
local queues = {} -- [mode] = groups in the order they joined; a group is a list of players
local queuedFor = {} -- [player] = mode
local tags = {} -- [group] = { n, since, busy }: its number here, when it queued, and whether it is being sent somewhere
local numbered = 0 -- the last group number given out
local pickers = {} -- [mode] = that mode's matchmaking rule (see Pool)
local listed = {} -- [mode] = true while the shared record has groups of this lobby in it
local elsewhere = {} -- [mode] = players waiting for the mode in other lobbies, when last looked
local hurry = {} -- [mode] = true when something has changed and the record should be looked at soon
local filledAt = {} -- [mode] = when this lobby last looked for places in running matches
local unreachable = {} -- [mode] = true while the shared record cannot be read
local ownPools = {} -- [mode] = the record, while it is kept here (see PUBLISHED)

for mode, rules in LobbyConfig.modes do
	queues[mode] = {}
	elsewhere[mode] = 0
	pickers[mode] = function(sizes, gathered)
		return Queue.pick(rules, sizes, gathered)
	end
end

local function tell(player, update)
	if player.Parent == Players then
		Remotes.QueueUpdate:FireClient(player, update)
	end
end

local function tellAll(players, status, message)
	for _, player in players do
		tell(player, { status = status, message = message })
	end
end

-- Tells everyone here who is queued for a mode how many are waiting for it,
-- in every lobby together.
local function announce(mode)
	local rules = LobbyConfig.modes[mode]
	local waiting = elsewhere[mode]
	for _, group in queues[mode] do
		waiting += #group
	end
	for _, group in queues[mode] do
		for _, player in group do
			tell(player, { status = "Queued", mode = mode, waiting = waiting, needed = rules.min })
		end
	end
end

-- Takes a group out of its queue and returns it.
local function take(mode, index)
	local group = table.remove(queues[mode], index)
	tags[group] = nil
	for _, player in group do
		queuedFor[player] = nil
	end
	hurry[mode] = true
	return group
end

-- Takes a player's whole group out of the queue: a squad queues and leaves as one.
local function leave(player, say)
	local mode = queuedFor[player]
	if not mode then
		return
	end
	for index, group in queues[mode] do
		if table.find(group, player) then
			take(mode, index)
			if say then
				tellAll(group, "None")
			end
			break
		end
	end
	queuedFor[player] = nil
	announce(mode)
end

local function join(player, mode)
	if type(mode) ~= "string" or not LobbyConfig.modes[mode] or queuedFor[player] == mode then
		return
	end
	if not squads.leads(player) then
		tell(player, { status = "Failed", message = "Your squad leader picks the mode" })
		return
	end
	local group = squads.groupOf(player)
	for _, member in group do
		leave(member, false)
	end
	for _, member in group do
		queuedFor[member] = mode
	end
	numbered += 1
	tags[group] = { n = numbered, since = os.time(), busy = false }
	table.insert(queues[mode], group)
	hurry[mode] = true
	announce(mode)
end

-- What travels with the players: who is in a squad with whom, and the side
-- each of them has been put on. The match reads it as they arrive. `sides`
-- is the side of each group, by its place in `groups`; it may be nil or empty.
local function travelData(groups, sides)
	local data = { squads = {}, sides = {} }
	for place, group in groups do
		local ids = {}
		for _, player in group do
			table.insert(ids, player.UserId)
			if sides then
				data.sides[tostring(player.UserId)] = sides[place]
			end
		end
		if #ids > 1 then
			table.insert(data.squads, ids)
		end
	end
	return data
end

local function flatten(groups)
	local players = {}
	for _, group in groups do
		for _, player in group do
			table.insert(players, player)
		end
	end
	return players
end

-- Saves what each player picked and bought here, then sends them to the
-- match server `accessCode` opens. Yields; made to be run with task.spawn.
local function depart(players, accessCode, data)
	if not PUBLISHED then
		tellAll(players, "Failed", "Match found, but the match place is not set up yet")
		return
	end
	local here = {}
	for _, player in players do
		if player.Parent == Players then
			profileStore.save(player)
			table.insert(here, player)
		end
	end
	if #here == 0 then
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData(data)
	local ok, problem = Travel.send(LobbyConfig.matchPlaceId, here, options)
	if not ok then
		warn(`QueueService: could not send players to their match: {problem}`)
		tellAll(here, "Failed", "Could not join the match. Queue again to retry.")
	end
end

-- Changes a mode's shared record in one step: `transform` is given what is
-- stored and returns what should be, or nil to leave it alone. It may be run
-- more than once. Yields. Returns whether the record could be reached, and
-- what it now holds (nil if it was left alone).
local function update(mode, transform)
	if not PUBLISHED then
		local updated = transform(ownPools[mode])
		if updated ~= nil then
			ownPools[mode] = updated
		end
		return true, updated
	end
	local pools = MemoryStoreService:GetHashMap(POOL.store)
	return pcall(pools.UpdateAsync, pools, mode, transform, POOL.lifetime)
end

-- Sends this lobby's groups to the matches they have been put in.
local function deliver(mode, pool)
	for _, match in Pool.mine(pool, LOBBY) do
		local groups, sides = {}, {}
		for _, entry in match.groups do
			for index, group in queues[mode] do
				if tags[group].n == entry.n then
					table.insert(groups, take(mode, index))
					sides[#groups] = entry.side
					break
				end
			end
		end
		-- A group that is not found was sent on an earlier look, or left the queue.
		if #groups > 0 then
			local players = flatten(groups)
			tellAll(players, "Launching", "Match found")
			task.spawn(depart, players, match.code, travelData(groups, sides))
		end
	end
end

-- Tells the shared record who this lobby has waiting, and acts on what it
-- says back. Yields. Returns the record, or nil if it could not be reached.
local function sync(mode)
	local groups = {}
	for _, group in queues[mode] do
		local tag = tags[group]
		if not tag.busy then
			table.insert(groups, { n = tag.n, size = #group, since = tag.since })
		end
	end
	local ok, pool = update(mode, function(old)
		return Pool.refresh(old, LOBBY, groups, os.time(), POOL, pickers[mode])
	end)
	if not ok or type(pool) ~= "table" then
		if not unreachable[mode] then
			unreachable[mode] = true
			warn(`QueueService: cannot reach the {mode} matchmaking record; players queued for it wait until it is back: {pool}`)
		end
		return nil
	end
	if unreachable[mode] then
		unreachable[mode] = nil
		warn(`QueueService: the {mode} matchmaking record can be reached again`)
	end

	local mine = pool.lobbies[LOBBY]
	listed[mode] = mine ~= nil
	local here = 0
	for _, group in if mine then mine.groups else {} do
		here += group.size
	end
	elsewhere[mode] = Pool.count(pool) - here

	deliver(mode, pool)
	announce(mode)
	return pool
end

-- Sends queued groups into matches of `mode` that have lost somebody. They go
-- before any new match is made. Yields.
local function fill(mode)
	local seats = MemoryStoreService:GetSortedMap(SEATS.seatStore .. "_" .. mode)
	local ok, found = pcall(seats.GetRangeAsync, seats, Enum.SortDirection.Ascending, 20)
	if not ok then
		warn(`QueueService: could not look for open {mode} seats: {found}`)
		return
	end
	for _, item in found do
		local seat = item.value
		-- Whoever has waited longest and fits goes first. A squad only goes
		-- where all of it can, on one team.
		local index = 1
		while index <= #queues[mode] do
			local group = queues[mode][index]
			local tag = tags[group]
			-- A look at the seat as it was listed saves asking for one the group could not have.
			if not tag.busy and select(2, Backfill.claim(seat, #group, os.time())) then
				-- Off the shared list first, so that no other lobby puts the
				-- group in a new match while it is on its way to this one.
				tag.busy = true
				if not sync(mode) then
					tag.busy = false
					return
				end
				if table.find(queues[mode], group) then
					-- Two lobbies may be after the same seat, so it is claimed in
					-- one step: whichever asks second finds it taken.
					local went = false
					local claimed, record = pcall(seats.UpdateAsync, seats, item.key, function(advertised)
						local updated, taken = Backfill.claim(advertised, #group, os.time())
						went = taken
						return updated
					end, SEATS.seatLifetime)

					-- The queue may have moved while that was being asked.
					local at = table.find(queues[mode], group)
					if claimed and went and record and at then
						seat = record
						take(mode, at)
						announce(mode)
						tellAll(group, "Launching", "Joining a match in progress")
						-- If they do not arrive, the seat frees itself (see Backfill.refresh).
						task.spawn(depart, group, record.accessCode, travelData({ group }, nil))
					elseif at then
						tag.busy = false -- back on the list at the next look, with the wait it had
					end
				end
			end
			if queues[mode][index] == group then
				index += 1
			end
		end
	end
end

-- Reserves a server for a planned match, leaves its settings where it will
-- look for them, and writes the match into the shared record. Yields. Returns
-- the record with the match in it, or nil if it was not made: another lobby
-- made one out of the same groups first, or something could not be reached.
-- A server reserved for a match that is not made is never started.
local function launch(mode, plan)
	local rules = LobbyConfig.modes[mode]
	local accessCode = "none"
	if PUBLISHED then
		local reserved, code, serverId = pcall(TeleportService.ReserveServer, TeleportService, LobbyConfig.matchPlaceId)
		if not reserved then
			warn(`QueueService: could not reserve a server for a {mode} match: {code}`)
			return nil
		end
		accessCode = code
		local settings = {
			mode = mode,
			map = rules.maps[math.random(#rules.maps)],
			expected = plan.players,
			accessCode = accessCode, -- so the match can ask for replacements if players leave
		}
		local store = MemoryStoreService:GetHashMap(LobbyConfig.settingsStore)
		local stored, problem = pcall(store.SetAsync, store, serverId, settings, LobbyConfig.settingsLifetime)
		if not stored then
			warn(`QueueService: could not leave the settings for a {mode} match: {problem}`)
			return nil
		end
	end

	local made = false
	local ok, pool = update(mode, function(old)
		local updated, went = Pool.commit(old, plan, accessCode, os.time())
		made = went
		return updated
	end)
	return if ok and made then pool else nil
end

-- One look at a mode: list who is waiting here, fill running matches, and
-- make a new match if there are the players for one. Yields.
local function look(mode)
	local pool = sync(mode)
	if not pool then
		return
	end

	local now = os.clock()
	if PUBLISHED and #queues[mode] > 0 and now - (filledAt[mode] or 0) >= SEATS.checkEvery then
		filledAt[mode] = now
		fill(mode)
		pool = sync(mode) -- whoever went is off the list; whoever could not go is back on it
		if not pool then
			return
		end
	end

	-- Any lobby with a group in the match may make it. If two try at once,
	-- one finds the groups already taken.
	local plan = Pool.plan(pool, pickers[mode], os.time(), LobbyConfig.gatherTime)
	if plan and Pool.involves(plan, LOBBY) then
		local made = launch(mode, plan)
		if made then
			deliver(mode, made)
			announce(mode) -- anyone left over keeps their place
			hurry[mode] = true -- and there may be enough of them for another match
		end
	end
end

-- Looks at a mode every couple of seconds for as long as this lobby has
-- anybody queued for it, or anything still listed for it. Never returns.
local function run(mode)
	while true do
		hurry[mode] = nil
		if #queues[mode] > 0 or listed[mode] then
			local ok, problem = pcall(look, mode)
			if not ok then
				warn(`QueueService: a look at the {mode} queue failed: {problem}`)
			end
		else
			elsewhere[mode] = 0
		end
		local waited = task.wait(SOONEST)
		while waited < POOL.checkEvery and not hurry[mode] do
			waited += task.wait(POLL)
		end
	end
end

-- `store` is the ProfileStore and `squadService` the SquadService.
function QueueService.init(store, squadService)
	profileStore = store
	squads = squadService

	Remotes.QueueJoin.OnServerEvent:Connect(join)
	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leave(player, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		leave(player, true)
	end)
	-- A squad that changes while it waits has to queue again, as what it now is.
	squads.Changed:Connect(function(players)
		for _, player in players do
			leave(player, true)
		end
	end)

	-- A player whose trip failed, however often it was tried, is still here and no longer queued.
	Travel.GaveUp:Connect(function(player)
		tell(player, { status = "Failed", message = "Could not join the match. Queue again to retry." })
	end)

	for mode in LobbyConfig.modes do
		task.spawn(run, mode)
	end
end

return QueueService
