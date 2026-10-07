-- Runs the lobby's real QueueService on several pretend lobby servers at once,
-- sharing one pretend store, and checks who ends up where. Run outside Studio
-- with:  lune run tests/matchmaking
--
-- The rules of matchmaking are unit-tested in tests/run. This is for what
-- those cannot show: that the service asks for things in the right order when
-- several lobbies do it at the same time. Everything Roblox provides is
-- stood in for here, so it says nothing about the real store or teleports.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local LobbyConfig = require("../src/shared/Config/LobbyConfig")
local Backfill = require("../src/shared/Logic/Backfill")
local Pool = require("../src/shared/Logic/Pool")
local Queue = require("../src/shared/Logic/Queue")

local SOURCE = fs.readFile("src/lobby/server/QueueService.luau")
local LATENCY = 0.08 -- seconds a call to the store or the teleport service takes, unless a world says otherwise
local START = 1700000000 -- what os.time() says when a world begins

---------------------------------------------------------------- A clock that only moves when told to

local clock = 0
local sleeping = {} -- { thread, at, asked }

local function resume(thread, ...)
	local ok, problem = coroutine.resume(thread, ...)
	if not ok then
		error(debug.traceback(thread, tostring(problem)), 0)
	end
end

local scheduler = {
	spawn = function(body, ...)
		local thread = coroutine.create(body)
		resume(thread, ...)
		return thread
	end,
	wait = function(seconds)
		table.insert(sleeping, { thread = coroutine.running(), at = clock + (seconds or 0), asked = clock })
		return coroutine.yield()
	end,
}

-- Lets `seconds` pass, waking whatever was waiting, in the order it is due.
local function advance(seconds)
	local stop = clock + seconds
	while true do
		local soonest = nil
		for index, sleeper in sleeping do
			if sleeper.at <= stop and (not soonest or sleeper.at < sleeping[soonest].at) then
				soonest = index
			end
		end
		if not soonest then
			break
		end
		local sleeper = table.remove(sleeping, soonest)
		clock = math.max(clock, sleeper.at)
		resume(sleeper.thread, clock - sleeper.asked)
	end
	clock = stop
end

---------------------------------------------------------------- Stand-ins

local function signal()
	local listeners = {}
	return {
		Connect = function(_, listener)
			table.insert(listeners, listener)
		end,
		fire = function(...)
			for _, listener in listeners do
				scheduler.spawn(listener, ...)
			end
		end,
	}
end

-- What the store keeps is JSON, so what comes out is never the table that went in.
local function kept(value)
	if value == nil then
		return nil
	end
	return serde.decode("json", serde.encode("json", value))
end

-- A world: one store, one teleport service, and the lobbies that share them.
local function newWorld()
	clock = 0
	sleeping = {}

	local world = {
		maps = {}, -- [name] = { [key] = value }
		reserved = 0,
		trips = {}, -- every group of players sent somewhere: { lobby, code, players, data }
		warnings = {},
		nextUserId = 100,
		-- How long the next call to the store or the teleport service takes.
		latency = function()
			return LATENCY
		end,
	}

	local function map(name)
		world.maps[name] = world.maps[name] or {}
		local data = world.maps[name]
		return {
			UpdateAsync = function(_, key, transform)
				scheduler.wait(world.latency())
				local updated = transform(kept(data[key]))
				if updated == nil then
					return nil
				end
				data[key] = kept(updated)
				return updated
			end,
			SetAsync = function(_, key, value)
				scheduler.wait(world.latency())
				data[key] = kept(value)
			end,
			GetRangeAsync = function()
				scheduler.wait(world.latency())
				local items = {}
				for key, value in data do
					table.insert(items, { key = key, value = kept(value) })
				end
				table.sort(items, function(a, b)
					return a.key < b.key
				end)
				return items
			end,
		}
	end

	world.memory = {
		GetHashMap = function(_, name)
			return map(name)
		end,
		GetSortedMap = function(_, name)
			return map(name)
		end,
	}
	world.teleports = {
		ReserveServer = function()
			scheduler.wait(world.latency())
			world.reserved += 1
			return "code-" .. world.reserved, "server-" .. world.reserved
		end,
	}
	return world
end

-- A lobby server in `world`, running the real QueueService.
local function newLobby(world, name)
	local lobby = { name = name, updates = {}, squadOf = {} }
	local Players = { PlayerRemoving = signal() }
	local remotes = {
		QueueJoin = { OnServerEvent = signal() },
		QueueLeave = { OnServerEvent = signal() },
		QueueUpdate = {
			FireClient = function(_, player, update)
				lobby.updates[player] = update
			end,
		},
	}
	local travel = {
		GaveUp = signal(),
		send = function(_, players, options)
			scheduler.wait(world.latency())
			table.insert(world.trips, {
				lobby = name,
				code = options.ReservedServerAccessCode,
				players = table.clone(players),
				data = options.data,
			})
			for _, player in players do
				player.Parent = nil
				Players.PlayerRemoving.fire(player)
			end
			return true
		end,
	}

	local config = table.clone(LobbyConfig)
	config.matchPlaceId = 1 -- as if both places were published
	config.lobbyPlaceId = 2

	local tokens = {
		config = {}, backfill = {}, pool = {}, queue = {}, remotes = {}, travel = {},
	}
	local modules = {
		[tokens.config] = config,
		[tokens.backfill] = Backfill,
		[tokens.pool] = Pool,
		[tokens.queue] = Queue,
		[tokens.remotes] = remotes,
		[tokens.travel] = travel,
	}
	local shared = {
		Config = { LobbyConfig = tokens.config },
		Logic = { Backfill = tokens.backfill, Pool = tokens.pool, Queue = tokens.queue },
		Remotes = tokens.remotes,
	}
	local services = {
		HttpService = {},
		MemoryStoreService = world.memory,
		Players = Players,
		ReplicatedStorage = {
			WaitForChild = function()
				return shared
			end,
		},
		TeleportService = world.teleports,
	}

	local service = luau.load(SOURCE, {
		debugName = "QueueService@" .. name,
		environment = {
			game = {
				JobId = name,
				GetService = function(_, wanted)
					return services[wanted]
				end,
			},
			script = { Parent = { Travel = tokens.travel } },
			require = function(token)
				return modules[token]
			end,
			task = scheduler,
			os = {
				time = function()
					return START + math.floor(clock)
				end,
				clock = function()
					return clock
				end,
			},
			warn = function(message)
				table.insert(world.warnings, name .. ": " .. tostring(message))
			end,
			Enum = { SortDirection = { Ascending = "Ascending" } },
			Instance = {
				new = function()
					return {
						SetTeleportData = function(self, data)
							self.data = data
						end,
					}
				end,
			},
		},
	})()

	local squadsChanged = signal()
	service.init({ save = function() end }, {
		Changed = squadsChanged,
		leads = function(player)
			local squad = lobby.squadOf[player]
			return squad == nil or squad[1] == player
		end,
		groupOf = function(player)
			local squad = lobby.squadOf[player]
			return if squad then table.clone(squad) else { player }
		end,
	})

	function lobby.player()
		world.nextUserId += 1
		return { Name = name .. "-" .. world.nextUserId, UserId = world.nextUserId, Parent = Players }
	end

	-- `count` players who each queue alone. Returns them.
	function lobby.queue(mode, count)
		local players = {}
		for index = 1, count do
			players[index] = lobby.player()
			remotes.QueueJoin.OnServerEvent.fire(players[index], mode)
		end
		return players
	end

	-- A squad of `count`, whose leader queues it. Returns them.
	function lobby.queueSquad(mode, count)
		local squad = {}
		for index = 1, count do
			squad[index] = lobby.player()
			lobby.squadOf[squad[index]] = squad
		end
		remotes.QueueJoin.OnServerEvent.fire(squad[1], mode)
		return squad
	end

	function lobby.leaveQueue(player)
		remotes.QueueLeave.OnServerEvent.fire(player)
	end

	return lobby
end

---------------------------------------------------------------- Checks

local passed, failed = 0, 0

local function equal(actual, expected, what)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", what, tostring(expected), tostring(actual)), 2)
	end
end

local function test(name, body)
	local ok, message = pcall(body)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name)
		print("      " .. tostring(message))
	end
end

-- Where each player was sent, and that nobody was sent twice.
local function destinations(world)
	local went = {} -- [player] = trip
	for _, trip in world.trips do
		for _, player in trip.players do
			equal(went[player], nil, player.Name .. " is only ever sent once")
			went[player] = trip
		end
	end
	return went
end

local function count(set)
	local total = 0
	for _ in set do
		total += 1
	end
	return total
end

-- Every match players were sent to was told what to run, and for how many.
local function settingsFor(world, code)
	local number = string.match(code, "^code%-(%d+)$")
	return world.maps[LobbyConfig.settingsStore] and world.maps[LobbyConfig.settingsStore]["server-" .. number]
end

local function quiet(world)
	equal(#world.warnings, 0, "nothing went wrong on the way: " .. tostring(world.warnings[1]))
end

---------------------------------------------------------------- Scenarios

test("four players in three lobbies, none of which could make a match alone, play together", function()
	local world = newWorld()
	local east, west, north = newLobby(world, "east"), newLobby(world, "west"), newLobby(world, "north")
	local players = {}
	for _, lobby in { east, west } do
		for _, player in lobby.queue("TDM", 1) do
			table.insert(players, player)
		end
	end
	advance(5) -- long enough for each lobby to have looked again since the other listed its player
	equal(#world.trips, 0, "two is not a match")
	equal(east.updates[players[1]].waiting, 2, "each is shown how many are waiting everywhere")

	for _, player in north.queue("TDM", 2) do
		table.insert(players, player)
	end
	advance(LobbyConfig.gatherTime - 2)
	equal(#world.trips, 0, "four is enough, but the gather time has not run")
	equal(west.updates[players[2]].waiting, 4, "the count follows the other lobbies")

	advance(8)
	local went = destinations(world)
	equal(count(went), 4, "all four are sent")
	local code = went[players[1]].code
	local sides = { 0, 0 }
	for _, player in players do
		equal(went[player].code, code, player.Name .. " goes to the same server as the rest")
		local side = went[player].data.sides[tostring(player.UserId)]
		sides[side] += 1
	end
	equal(sides[1], 2, "two on one side")
	equal(sides[2], 2, "two on the other")
	equal(settingsFor(world, code).mode, "TDM", "the server is told the mode")
	equal(settingsFor(world, code).expected, 4, "and how many to wait for")
	equal(settingsFor(world, code).accessCode, code, "and how more can be sent to it")
	quiet(world)
end)

test("a full match goes at once, and whoever queued last waits for the next", function()
	local world = newWorld()
	local east, west = newLobby(world, "east"), newLobby(world, "west")
	local capacity = Queue.capacity(LobbyConfig.modes.FFA)
	local first = east.queue("FFA", capacity - 3)
	advance(1.2)
	local second = west.queue("FFA", 3)
	advance(1.2)
	local late = west.queue("FFA", 1)[1]
	advance(5)

	local went = destinations(world)
	equal(count(went), capacity, "a full match, long before the gather time is up")
	for _, group in { first, second } do
		for _, player in group do
			equal(went[player] ~= nil, true, player.Name .. " is in it")
		end
	end
	equal(went[late], nil, "the last to queue is not")
	equal(west.updates[late].status, "Queued", "and is still queued")
	equal(west.updates[late].waiting, 1, "alone")
	quiet(world)
end)

test("many lobbies queueing at the same moment make whole matches and strand nobody", function()
	local world = newWorld()
	local capacity = Queue.capacity(LobbyConfig.modes.TDM)
	local lobbies, players = {}, {}
	for index = 1, 6 do
		lobbies[index] = newLobby(world, "lobby-" .. index)
	end
	-- Three full matches' worth, five from each lobby, all in the same instant.
	for _, lobby in lobbies do
		for _, player in lobby.queue("TDM", capacity * 3 / #lobbies) do
			table.insert(players, player)
		end
	end
	advance(LobbyConfig.gatherTime + 20)

	local went = destinations(world)
	equal(count(went), #players, "everybody is sent somewhere")
	local sizes = {} -- [code] = players sent to it
	for _, trip in world.trips do
		sizes[trip.code] = (sizes[trip.code] or 0) + #trip.players
	end
	equal(count(sizes), 3, "into three matches")
	for code, size in sizes do
		equal(size, capacity, code .. " is full")
		equal(settingsFor(world, code).expected, size, code .. " waits for exactly who was sent")
	end
	quiet(world)
end)

test("a squad travels whole and on one side, with players from another lobby against it", function()
	local world = newWorld()
	local east, west = newLobby(world, "east"), newLobby(world, "west")
	local squad = east.queueSquad("TDM", 3)
	local others = west.queue("TDM", 3)
	advance(LobbyConfig.gatherTime + 6)

	local went = destinations(world)
	equal(count(went), 6, "3v3")
	local trip = went[squad[1]]
	local side = trip.data.sides[tostring(squad[1].UserId)]
	for _, member in squad do
		equal(went[member], trip, member.Name .. " travels with the squad")
		equal(trip.data.sides[tostring(member.UserId)], side, member.Name .. " is on its side")
	end
	equal(#trip.data.squads, 1, "the match is told they are a squad")
	equal(#trip.data.squads[1], 3, "of three")
	for _, player in others do
		equal(went[player].code, trip.code, player.Name .. " is in the same match")
		equal(went[player].data.sides[tostring(player.UserId)] ~= side, true, player.Name .. " is against the squad")
	end
	quiet(world)
end)

test("a player who leaves the queue is not matched, and nobody waits for them", function()
	local world = newWorld()
	local east, west = newLobby(world, "east"), newLobby(world, "west")
	local stays = east.queue("FFA", 1)[1]
	local leaves = west.queue("FFA", 1)[1]
	advance(3)
	west.leaveQueue(leaves)
	advance(LobbyConfig.gatherTime + 10)
	equal(#world.trips, 0, "one player is not a match")
	equal(west.updates[leaves].status, "None", "the one who left is told they are out")
	equal(east.updates[stays].waiting, 1, "the one who stayed sees only themselves waiting")

	-- Somebody new arrives, and the two of them play.
	local arrives = west.queue("FFA", 1)[1]
	advance(LobbyConfig.gatherTime + 6)
	local went = destinations(world)
	equal(went[stays] ~= nil and went[arrives] ~= nil, true, "the two who are queued are matched")
	equal(went[leaves], nil, "the one who left stays in the lobby")
	quiet(world)
end)

test("a place in a running match is taken before any new match is made, by one lobby only", function()
	local world = newWorld()
	local east, west = newLobby(world, "east"), newLobby(world, "west")
	-- A running match that has lost one player.
	local seats = LobbyConfig.backfill.seatStore .. "_TDM"
	world.maps[seats] = { running = Backfill.refresh(nil, "running-code", 1, 1, 0, START, LobbyConfig.backfill.transitTimeout) }

	-- Four are queued: enough for a new 2v2, if the running match were ignored.
	local first = east.queue("TDM", 2)
	local second = west.queue("TDM", 2)
	advance(LobbyConfig.gatherTime + 30)

	local went = destinations(world)
	local filled = 0
	for _, group in { first, second } do
		for _, player in group do
			if went[player] and went[player].code == "running-code" then
				filled += 1
			end
		end
	end
	equal(filled, 1, "exactly one player takes the one place")
	equal(count(went), 1, "and three cannot make even sides, so the rest keep waiting")
	equal(Backfill.open(world.maps[seats].running), 0, "the place is no longer on offer")

	-- A fourth joins them and the new match is made.
	west.queue("TDM", 1)
	advance(LobbyConfig.gatherTime + 6)
	equal(count(destinations(world)), 5, "the other three and the newcomer are sent")
	quiet(world)
end)

test("a lobby that cannot reach the store keeps its players queued and says so once", function()
	local world = newWorld()
	local east = newLobby(world, "east")
	local working = world.memory.GetHashMap
	world.memory.GetHashMap = function()
		return {
			UpdateAsync = function()
				scheduler.wait(LATENCY)
				error("the store is down")
			end,
		}
	end
	local players = east.queue("FFA", 2)
	advance(30)
	equal(#world.trips, 0, "nobody is sent anywhere")
	equal(east.updates[players[1]].status, "Queued", "they are still queued")
	equal(#world.warnings, 1, "one warning, not one every look")

	world.memory.GetHashMap = working
	advance(LobbyConfig.gatherTime + 6)
	equal(count(destinations(world)), 2, "when it is back, they are matched")
	equal(#world.warnings, 2, "and that is said once too")
end)

---------------------------------------------------------------- Many worlds, at random

-- The scenarios above each happen one way. What goes wrong between servers
-- goes wrong in the gaps: one lobby reads while another is half way through
-- writing. So this plays many worlds with the lobbies out of step with each
-- other and every call taking a different time, and checks what must be true
-- however it falls out. Each world is made from its number, so one that fails
-- can be played again.

-- Enough of them to catch a mistake that needs two lobbies to act within a
-- fraction of a second of each other.
local WORLDS = 1000
local RUNNING = "running-code" -- the match that has lost players, in worlds that have one

local function playWorld(seed)
	math.randomseed(seed)
	local world = newWorld()
	world.latency = function()
		return 0.02 + math.random() * 0.4
	end

	local mode = if math.random() < 0.5 then "TDM" else "FFA"
	local rules = LobbyConfig.modes[mode]
	local lobbies = {}
	for index = 1, math.random(2, 5) do
		lobbies[index] = newLobby(world, "lobby-" .. index)
	end

	-- Some worlds have a match in progress with places to fill.
	local places = if math.random() < 0.5 then math.random(1, 2) else 0
	local seats = LobbyConfig.backfill.seatStore .. "_" .. mode
	if places > 0 then
		local offered = Backfill.refresh(nil, RUNNING, places, 1, 0, START, LobbyConfig.backfill.transitTimeout)
		world.maps[seats] = { running = offered }
	end

	-- Players and squads queue at moments of their own over the first while.
	local groups = {} -- every group that queued, as a list of players
	for _ = 1, math.random(2, 14) do
		local lobby = lobbies[math.random(#lobbies)]
		local size = if math.random() < 0.25 then math.random(2, LobbyConfig.squad.size) else 1
		scheduler.spawn(function()
			scheduler.wait(math.random() * 25)
			table.insert(groups, if size > 1 then lobby.queueSquad(mode, size) else lobby.queue(mode, 1))
		end)
	end
	advance(25 + LobbyConfig.gatherTime + 60)

	local went = destinations(world) -- nobody is sent twice
	equal(#world.warnings, 0, "nothing went wrong on the way: " .. tostring(world.warnings[1]))

	local sentTo = {} -- [code] = players sent there
	for _, group in groups do
		local trip = went[group[1]]
		for _, member in group do
			equal(went[member], trip, member.Name .. " goes where the rest of their group goes, or stays with them")
		end
		if trip then
			sentTo[trip.code] = (sentTo[trip.code] or 0) + #group
			if rules.teams and #group > 1 and trip.code ~= RUNNING then
				local side = trip.data.sides[tostring(group[1].UserId)]
				for _, member in group do
					equal(trip.data.sides[tostring(member.UserId)], side, member.Name .. " is on their squad's side")
				end
			end
		end
	end

	local waiting = {}
	for _, group in groups do
		if not went[group[1]] then
			table.insert(waiting, #group)
		end
	end

	for code, players in sentTo do
		if code == RUNNING then
			equal(players <= places, true, "no more are sent into the running match than it has places")
		else
			local settings = settingsFor(world, code)
			equal(settings ~= nil, true, code .. " was told what to run")
			equal(players, settings.expected, code .. " gets every player it was told to wait for")
			equal(players >= rules.min and players <= Queue.capacity(rules), true, code .. " is a match the mode allows")
			if rules.teams then
				local sides = { 0, 0 }
				for player, trip in went do
					if trip.code == code then
						sides[trip.data.sides[tostring(player.UserId)]] += 1
					end
				end
				equal(sides[1], sides[2], code .. " has two even sides")
			end
		end
	end

	-- Nobody is left waiting who could have been playing.
	equal(Queue.pick(rules, waiting, true), nil, "those still waiting could not make a match between them")
end

test(WORLDS .. " worlds with the lobbies out of step and every call taking its own time", function()
	for seed = 1, WORLDS do
		local ok, problem = pcall(playWorld, seed)
		if not ok then
			error(string.format("world %d: %s", seed, tostring(problem)), 0)
		end
	end
end)

print(string.format("%d passed, %d failed", passed, failed))
process.exit(failed == 0 and 0 or 1)
