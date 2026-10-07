-- Loads and saves player profiles: points, level, rentals and the loadout last
-- picked. Used by both places, so a pick made in the lobby is what the player
-- spawns with in the match. The rules are in Shared.Logic.Economy.
--
-- Profiles are kept in a data store. Where that is not available (Studio
-- without API access, or an unpublished place) they last for the session only
-- and nothing is saved.
--
-- A player moves between servers (lobby to match and back), and the one they
-- leave is still saving as the one they join starts loading. So a profile is
-- only ever open on one server at a time (rules in Shared.Logic.Session):
-- loading it marks it as open here, a server that finds it open elsewhere
-- waits for it to be closed, and a save that finds the profile has since been
-- opened somewhere else does not write. Nothing is lost between the two.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared.Config.ShopConfig)
local Economy = require(Shared.Logic.Economy)
local Session = require(Shared.Logic.Session)
local Remotes = require(Shared.Remotes)

local ProfileStore = {}

local STORE_NAME = "Profiles_v1"
-- What this server calls itself when it opens a profile. A Studio test has no
-- job id, so it makes one up.
local SERVER = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
local RETRY_EVERY = 3 -- seconds between tries at a profile that is open on another server
local SAVE_EVERY = 60 -- seconds between saves of everybody here, which also keeps their profiles marked as open
-- A profile left open by a server that has not saved it for this long is
-- taken to be abandoned (the server crashed), and can be opened elsewhere.
local STALE_AFTER = SAVE_EVERY * 2 + 30

local store = nil
local profiles = {} -- [player] = profile
local canSave = {} -- [player] = true once their profile was read, or found not to exist
local held = {} -- [player] = the rentals they have taken into the match they are in (see Economy)
local loaded = Instance.new("BindableEvent")

-- Fires with (player, profile) when a player's profile is ready.
ProfileStore.Loaded = loaded.Event

local function keyFor(player)
	return "player_" .. player.UserId
end

function ProfileStore.get(player)
	return profiles[player]
end

-- The rentals this player has taken into the current match. They stay usable
-- until it is over, even if they run out. Never saved.
function ProfileStore.held(player)
	local set = held[player]
	if not set then
		set = {}
		held[player] = set
	end
	return set
end

-- The match is over: what ran out during it is now gone for everyone.
function ProfileStore.releaseHeld()
	table.clear(held)
	for player in profiles do
		ProfileStore.push(player)
	end
end

-- Sends the player their profile. `earned` is the points a match just paid.
function ProfileStore.push(player, earned)
	local profile = profiles[player]
	if not profile then
		return
	end
	player:SetAttribute("Level", profile.level) -- so anybody can be shown this player's rank
	Remotes.ProfileUpdate:FireClient(player, {
		points = profile.points,
		level = profile.level,
		xp = profile.xp,
		xpNeeded = Economy.xpForLevel(ShopConfig, profile.level),
		rentals = profile.rentals,
		held = held[player] or {},
		expired = profile.expired, -- ran out, and not yet acknowledged
		revives = profile.revives,
		swaps = profile.swaps,
		weapons = profile.weapons,
		now = os.time(), -- so the client can show time left against the server's clock
		earned = earned,
	})
end

-- Yields. Safe to call from task.spawn. Returns whether the profile is now
-- safely stored; false as well when there is nowhere to store it. `closing`
-- is for the last save as a player leaves: it marks the profile as no longer
-- open here, so the server they are going to can open it at once.
function ProfileStore.save(player, closing)
	local profile = profiles[player]
	if not store or not profile or not canSave[player] then
		return false
	end
	Economy.prune(profile, os.time())
	local written = false
	local ok, problem = pcall(store.UpdateAsync, store, keyFor(player), function(saved)
		written = Session.mayWrite(saved, SERVER)
		if not written then
			return nil -- it has been opened on another server since: theirs is the newer one
		end
		local record = table.clone(profile)
		record.session = if closing then nil else Session.stamp(SERVER, os.time())
		return record
	end)
	if not ok then
		warn(`ProfileStore: could not save {player.Name}: {problem}`)
	elseif not written then
		warn(`ProfileStore: {player.Name}'s profile is open on another server; this one will not save it again`)
		canSave[player] = nil
	end
	return ok and written
end

-- True if profiles are kept between sessions here.
function ProfileStore.persists()
	return store ~= nil
end

-- Opens a player's saved profile on this server. Returns whether it worked,
-- and what was saved (nil for a new player). If the profile is open on another
-- server, which is usual for a moment after a teleport, this waits for that
-- server to finish with it. Yields.
local function open(player)
	while player.Parent == Players do
		local elsewhere = false
		local ok, saved = pcall(store.UpdateAsync, store, keyFor(player), function(found)
			elsewhere = Session.heldElsewhere(found, SERVER, os.time(), STALE_AFTER)
			if elsewhere then
				return nil -- leave it exactly as it is
			end
			local record = if type(found) == "table" then found else {}
			record.session = Session.stamp(SERVER, os.time())
			return record
		end)
		if not ok then
			return false, saved
		elseif not elsewhere then
			return true, saved
		end
		task.wait(RETRY_EVERY)
	end
	return false, "they left before it could be opened"
end

-- Marks a profile as no longer open here without otherwise touching it: for a
-- player who left while it was still being opened.
local function close(player)
	pcall(store.UpdateAsync, store, keyFor(player), function(saved)
		if type(saved) ~= "table" or not Session.mayWrite(saved, SERVER) then
			return nil
		end
		saved.session = nil
		return saved
	end)
end

local function load(player)
	local profile = Economy.newProfile()
	if store then
		local ok, saved = open(player)
		if not ok then
			-- Never save over a profile that could not be read.
			warn(`ProfileStore: could not load {player.Name}; this session will not be saved: {saved}`)
		else
			canSave[player] = true
			if type(saved) == "table" then
				profile.points = tonumber(saved.points) or 0
				profile.xp = tonumber(saved.xp) or 0
				profile.level = tonumber(saved.level) or 1
				profile.rentals = if type(saved.rentals) == "table" then saved.rentals else {}
				profile.expired = if type(saved.expired) == "table" then saved.expired else {}
				profile.revives = tonumber(saved.revives) or 0
				profile.swaps = tonumber(saved.swaps) or 0
				profile.weapons = if type(saved.weapons) == "table" then saved.weapons else {}
				profile.receipts = if type(saved.receipts) == "table" then saved.receipts else nil
				profile.loadout = if type(saved.loadout) == "table" then saved.loadout else nil
			end
		end
	end
	if player.Parent ~= Players then
		if canSave[player] then
			canSave[player] = nil
			close(player) -- or the next server would wait for one that is not coming
		end
		return -- they left while it was loading
	end
	Economy.prune(profile, os.time())
	profiles[player] = profile
	ProfileStore.push(player)
	loaded:Fire(player, profile)
end

-- Rents an option for the player if they can afford it. Returns whether it was bought.
function ProfileStore.buy(player, field, option, hours)
	local profile = profiles[player]
	if not profile or type(field) ~= "string" or type(option) ~= "string" or type(hours) ~= "number" then
		return false
	end
	local bought = Economy.buy(ShopConfig, profile, field, option, hours, os.time())
	if bought then
		task.spawn(ProfileStore.save, player)
	end
	ProfileStore.push(player)
	return bought
end

-- The player has been shown what ran out.
function ProfileStore.acknowledge(player)
	local profile = profiles[player]
	if profile and next(profile.expired) then
		Economy.acknowledge(profile)
		ProfileStore.push(player)
	end
end

-- Takes away anything that has run out since the last look. Returns the
-- players who lost something, each of whom has been sent their profile.
function ProfileStore.sweep()
	local changed = {}
	for player, profile in profiles do
		if Economy.prune(profile, os.time()) then
			ProfileStore.push(player)
			table.insert(changed, player)
		end
	end
	return changed
end

function ProfileStore.init()
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
	if ok then
		store = result
	else
		warn(`ProfileStore: no data store, so profiles last for this session only: {result}`)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ProfileStore.save(player, true)
		profiles[player] = nil
		canSave[player] = nil
		held[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(ProfileStore.save, player, true)
		end
		task.wait(2) -- give those saves a moment before the server goes
	end)

	-- Saving everybody now and then loses less if the server dies, and is what
	-- keeps their profiles from looking abandoned to other servers.
	if store then
		task.spawn(function()
			while true do
				task.wait(SAVE_EVERY)
				for player in profiles do
					task.spawn(ProfileStore.save, player)
				end
			end
		end)
	end
end

return ProfileStore
