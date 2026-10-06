-- The match's side of player profiles: pays out at the end of a match,
-- restores the loadout picked in the lobby, tells LoadoutService what a player
-- may use, and charges for weapons changed mid-match. Nothing is rented here:
-- that is done in the lobby. Loading and saving are in ProfileStore.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmorConfig = require(Shared.Config.ArmorConfig)
local ShopConfig = require(Shared.Config.ShopConfig)
local TacticalConfig = require(Shared.Config.TacticalConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Economy = require(Shared.Logic.Economy)
local Loadout = require(Shared.Logic.Loadout)
local Score = require(Shared.Logic.Score)
local Remotes = require(Shared.Remotes)

local LoadoutService = require(script.Parent.LoadoutService)
local MatchService = require(script.Parent.MatchService)
local ProfileStore = require(script.Parent.ProfileStore)
local SpawnService = require(script.Parent.SpawnService)
local StatsService = require(script.Parent.StatsService)
local TeamService = require(script.Parent.TeamService)

local ProfileService = {}

local DEFAULTS = Loadout.default(WeaponConfig, TacticalConfig, ArmorConfig)

local aliveSince = {} -- [player] = when the life being charged for began
local settled = {} -- [player] = true once they have started a life in the match being played
local arrivedAt = {} -- [player] = when they joined this server
local matchStartedAt = os.clock()

-- Rented weapons and grenades run down only while they are used: takes the
-- time this player has just spent alive in a match off those in their loadout.
local function charge(player)
	local since = aliveSince[player]
	aliveSince[player] = nil
	local profile = ProfileStore.get(player)
	local state = LoadoutService.get(player)
	if since and profile and state then
		Economy.consume(ShopConfig, profile, state.loadout, os.clock() - since)
	end
end

-- Pays everyone for the match that just ended, and names its MVP. Who the MVP
-- is depends on the mode (see MatchConfig.mvp): kills in a deathmatch, kills
-- and objectives in Search and Destroy. Either way it is whoever did most on
-- either side, so a losing team can have one.
local function payOut()
	for _, player in Players:GetPlayers() do
		charge(player)
	end
	local ranked = Score.rank(StatsService.weights(), StatsService.results())
	local mvp = StatsService.mvp()
	local winner = MatchService.winner()

	for _, result in ranked do
		local player = result.player
		local profile = ProfileStore.get(player)
		if profile then
			local points = Economy.matchReward(ShopConfig, {
				kills = result.kills,
				deaths = result.deaths,
				assists = result.assists,
				objectives = result.plants + result.defuses,
				won = winner ~= nil and winner == TeamService.scoreKey(player),
				mvp = result.name == mvp,
				-- Somebody sent in part-way through has only been here since they arrived.
				seconds = os.clock() - math.max(matchStartedAt, arrivedAt[player] or matchStartedAt),
			})
			Economy.addReward(ShopConfig, profile, points)
			ProfileStore.push(player, points)
			task.spawn(ProfileStore.save, player)
		end
		if result.name == mvp then
			Remotes.Mvp:FireAllClients(result)
		end
	end
end

function ProfileService.init()
	-- A player without a loaded profile gets the free loadout.
	LoadoutService.setGate({
		owns = function(player, loadout)
			local profile = ProfileStore.get(player)
			return profile ~= nil
				and Economy.ownsAll(ShopConfig, profile, loadout, os.time(), ProfileStore.held(player))
		end,
		equip = function(player, loadout)
			local profile = ProfileStore.get(player)
			if not profile then
				return table.clone(DEFAULTS)
			end
			-- Whatever they take in is theirs until the match is over, even if
			-- its time runs out before then. The lobby tells them afterwards.
			local allowed = Economy.equip(ShopConfig, profile, loadout, DEFAULTS, os.time(), ProfileStore.held(player))
			ProfileStore.push(player) -- a rental's clock may just have started
			return allowed
		end,
		-- The loadout a player brings to a match is free, and so is anything
		-- during the warm-up. After that, each weapon or grenade they were not
		-- carrying in their last life costs points.
		charge = function(player, previous, wanted)
			local profile = ProfileStore.get(player)
			if not profile or MatchService.phase() == "Waiting" then
				return wanted, nil
			end
			if not settled[player] then
				settled[player] = true
				return wanted, nil
			end
			local got, cost, went = Economy.chargeSwaps(ShopConfig, profile, previous, wanted, Loadout.WEAPON_FIELDS)
			if not went then
				return got, "NOT ENOUGH POINTS TO CHANGE WEAPONS"
			elseif cost > 0 then
				ProfileStore.push(player)
				return got, string.format("WEAPONS CHANGED   -%d POINTS", cost)
			end
			return got, nil
		end,
	})

	-- The loadout picked last time, here or in the lobby, is used from the next spawn.
	ProfileStore.Loaded:Connect(function(player, profile)
		if profile.loadout then
			LoadoutService.setChoice(player, profile.loadout)
		end
	end)
	LoadoutService.Chosen:Connect(function(player, loadout)
		local profile = ProfileStore.get(player)
		if profile then
			profile.loadout = loadout
		end
	end)

	MatchService.Changed:Connect(function(event)
		-- "Ended" closes an FFA or TDM match, "MatchOver" a Search and Destroy one.
		if event == "Ended" or event == "MatchOver" then
			payOut()
		elseif event == "Reset" then
			ProfileStore.releaseHeld() -- that match is over: expired rentals end with it
		end
		-- A new match: everyone's first life in it is free again.
		if event == "Started" or event == "Reset" then
			table.clear(settled)
		end
		if event == "Started" then
			matchStartedAt = os.clock()
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		arrivedAt[player] = os.clock()
	end)
	for _, player in Players:GetPlayers() do
		arrivedAt[player] = os.clock()
	end
	Players.PlayerRemoving:Connect(function(player)
		settled[player] = nil
		arrivedAt[player] = nil
	end)

	-- Time alive is charged per life. The warm-up before a match is free.
	SpawnService.Spawned:Connect(function(player)
		charge(player) -- a round restart respawns the living without a death
		-- Not the warm-up, and not the ceremony after the match.
		local phase = MatchService.phase()
		if phase ~= "Waiting" and phase ~= "Ended" and phase ~= "MatchOver" then
			aliveSince[player] = os.clock()
		end
	end)
	SpawnService.Died:Connect(charge)
	-- Connected before ProfileStore's own handler, so the charge is saved.
	Players.PlayerRemoving:Connect(charge)

	ProfileStore.init()
end

return ProfileService
