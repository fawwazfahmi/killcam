-- Loads and saves player profiles: points, level, rentals and the loadout last
-- picked. Used by both places, so a pick made in the lobby is what the player
-- spawns with in the match. The rules are in Shared.Logic.Economy.
--
-- Profiles are kept in a data store. Where that is not available (Studio
-- without API access, or an unpublished place) they last for the session only
-- and nothing is saved.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared.Config.ShopConfig)
local Economy = require(Shared.Logic.Economy)
local Remotes = require(Shared.Remotes)

local ProfileStore = {}

local STORE_NAME = "Profiles_v1"

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
-- safely stored; false as well when there is nowhere to store it.
function ProfileStore.save(player)
	local profile = profiles[player]
	if not store or not profile or not canSave[player] then
		return false
	end
	Economy.prune(profile, os.time())
	local ok, problem = pcall(store.SetAsync, store, keyFor(player), profile)
	if not ok then
		warn(`ProfileStore: could not save {player.Name}: {problem}`)
	end
	return ok
end

-- True if profiles are kept between sessions here.
function ProfileStore.persists()
	return store ~= nil
end

local function load(player)
	local profile = Economy.newProfile()
	if store then
		local ok, saved = pcall(store.GetAsync, store, keyFor(player))
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
		ProfileStore.save(player)
		profiles[player] = nil
		canSave[player] = nil
		held[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			ProfileStore.save(player)
		end
	end)
end

return ProfileStore
