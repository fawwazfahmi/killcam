-- Matchmaking in the lobby. Players queue for a mode and stay in the lobby.
-- When a queue can make a match (see Shared.Logic.Queue) a private match
-- server is reserved, told which mode and map to run, and the players are sent.
--
-- What waits in a queue is a group: one player, or a squad. A group is never
-- split between matches, or between teams. Matches already running that have
-- lost a player are filled first (see Shared.Logic.Backfill).
--
-- Queues are per lobby server: players in different lobby servers are not
-- matched with each other.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local Backfill = require(Shared.Logic.Backfill)
local Queue = require(Shared.Logic.Queue)
local Remotes = require(Shared.Remotes)

local QueueService = {}

local CHECK_EVERY = 0.5 -- seconds

local profileStore, squads
local queues = {} -- [mode] = groups in the order they joined; a group is a list of players
local queuedFor = {} -- [player] = mode
local gatheringSince = {} -- [mode] = when the queue first had enough for a match
local filling = {} -- [mode] = true while this lobby is looking for seats in running matches
local sinceFill = 0

for mode in LobbyConfig.modes do
	queues[mode] = {}
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

local function sizesOf(queue)
	local sizes = {}
	for index, group in queue do
		sizes[index] = #group
	end
	return sizes
end

-- Tells everyone in a queue how full it is.
local function announce(mode)
	local rules = LobbyConfig.modes[mode]
	local waiting = 0
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
	for _, player in group do
		queuedFor[player] = nil
	end
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
	table.insert(queues[mode], group)
	announce(mode)
end

-- What travels with the players: who is in a squad with whom, and the side
-- the lobby has put each of them on. The match reads it as they arrive.
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

-- Saves what each player picked and bought here, then sends them. Yields, and
-- errors if they could not be sent.
local function send(players, accessCode, data)
	for _, player in players do
		profileStore.save(player)
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData(data)
	TeleportService:TeleportAsync(LobbyConfig.matchPlaceId, players, options)
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

-- Reserves a match server, leaves its settings where it will look for them,
-- and sends the groups. Yields.
local function launch(mode, groups, sides)
	local rules = LobbyConfig.modes[mode]
	local players = flatten(groups)
	if LobbyConfig.matchPlaceId == 0 then
		tellAll(players, "Failed", "Match found, but the match place is not set up yet")
		return
	end
	tellAll(players, "Launching", "Match found")

	local ok, problem = pcall(function()
		local accessCode, serverId = TeleportService:ReserveServer(LobbyConfig.matchPlaceId)
		local settings = {
			mode = mode,
			map = rules.maps[math.random(#rules.maps)],
			expected = #players,
			accessCode = accessCode, -- so the match can ask for replacements if players leave
		}
		MemoryStoreService
			:GetHashMap(LobbyConfig.settingsStore)
			:SetAsync(serverId, settings, LobbyConfig.settingsLifetime)
		send(players, accessCode, travelData(groups, sides))
	end)
	if not ok then
		warn(`QueueService: could not start a {mode} match: {problem}`)
		tellAll(players, "Failed", "Could not start the match. Queue again to retry.")
	end
end

-- Sends queued groups into matches of `mode` that have lost somebody. They go
-- before any new match is started. Yields.
local function fill(mode)
	local seats = MemoryStoreService:GetSortedMap(LobbyConfig.backfill.seatStore .. "_" .. mode)
	local ok, listed = pcall(seats.GetRangeAsync, seats, Enum.SortDirection.Ascending, 20)
	if not ok then
		warn(`QueueService: could not look for open {mode} seats: {listed}`)
		return
	end
	for _, item in listed do
		-- Whoever has waited longest and fits goes first. A squad only goes
		-- where all of it can, on one team.
		local index = 1
		while index <= #queues[mode] do
			local group = queues[mode][index]
			-- Two lobbies may be after the same seat, so it is claimed in one
			-- step: whichever asks second finds it taken.
			local went = false
			local claimed, record = pcall(seats.UpdateAsync, seats, item.key, function(advertised)
				local updated, taken = Backfill.claim(advertised, #group, os.time())
				went = taken
				return updated
			end, LobbyConfig.backfill.seatLifetime)

			-- The queue may have moved while that was being asked.
			local at = table.find(queues[mode], group)
			if claimed and went and record and at then
				take(mode, at)
				announce(mode)
				tellAll(group, "Launching", "Joining a match in progress")
				local sent, problem = pcall(send, group, record.accessCode, travelData({ group }, nil))
				if not sent then
					-- The seat frees itself when nobody turns up (see Backfill.refresh).
					warn(`QueueService: could not send players into a running {mode} match: {problem}`)
					tellAll(group, "Failed", "Could not join the match. Queue again to retry.")
				end
			else
				index += 1
			end
		end
	end
end

local function step()
	local now = os.clock()
	for mode, queue in queues do
		local rules = LobbyConfig.modes[mode]
		local sizes = sizesOf(queue)
		-- The gather time starts when there are first enough players for a match.
		if Queue.pick(rules, sizes, true) then
			gatheringSince[mode] = gatheringSince[mode] or now
		else
			gatheringSince[mode] = nil
		end
		local gathered = gatheringSince[mode] ~= nil and now - gatheringSince[mode] >= LobbyConfig.gatherTime

		local pick = Queue.pick(rules, sizes, gathered)
		if pick then
			local groups = {}
			for place, index in pick.groups do
				groups[place] = queue[index]
			end
			-- From the back, so the earlier positions are still right.
			for place = #pick.groups, 1, -1 do
				take(mode, pick.groups[place])
			end
			gatheringSince[mode] = nil
			announce(mode) -- anyone left over keeps their place
			task.spawn(launch, mode, groups, pick.sides)
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

	-- If a teleport fails after it was accepted, the player is still here and no longer queued.
	TeleportService.TeleportInitFailed:Connect(function(player)
		tell(player, { status = "Failed", message = "Could not join the match. Queue again to retry." })
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceFill += dt
		if sinceFill >= LobbyConfig.backfill.checkEvery and LobbyConfig.matchPlaceId ~= 0 then
			sinceFill = 0
			for mode, queue in queues do
				if #queue > 0 and not filling[mode] then
					filling[mode] = true
					task.spawn(function()
						fill(mode)
						filling[mode] = nil
					end)
				end
			end
		end
		sinceCheck += dt
		if sinceCheck >= CHECK_EVERY then
			sinceCheck = 0
			step()
		end
	end)
end

return QueueService
