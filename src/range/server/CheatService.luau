-- What an admin can switch on for themselves on the test range (the list is
-- RangeConfig.cheats), and the things the panel does to them on request: heal,
-- hurt, and send somewhere.
--
-- Everything is unlocked here simply because nothing locks it: the shop's
-- rules are never given to LoadoutService on the range, and armour and the
-- tactical item, which a match would not let a player change, are changed for
-- the asking.
--
-- None of the switches reaches into the combat code. Ammunition is topped
-- back up a few times a second, and god mode is a force field, which Roblox
-- itself makes proof against damage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RangeConfig = require(Shared.Config.RangeConfig)
local TacticalConfig = require(Shared.Config.TacticalConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Damage = require(Shared.Logic.Damage)
local Dummy = require(Shared.Logic.Dummy)
local Loadout = require(Shared.Logic.Loadout)

local CombatService = require(script.Parent.CombatService)
local Harm = require(script.Parent.Harm)
local LoadoutService = require(script.Parent.LoadoutService)
local SpawnService = require(script.Parent.SpawnService)

local CheatService = {}

local TOP_UP_EVERY = 0.2 -- seconds
local SOURCE = "THE RANGE" -- who the kill feed says did it, when it was the panel
local SHIELD = "GodMode"

local known = {} -- [name] = true for every switch there is
for _, cheat in RangeConfig.cheats do
	known[cheat.name] = true
end

local switched = {} -- [player] = { [name] = true }
local rearming = {} -- [player] = true while a loadout change is waiting to be put in their hands
local spots = {} -- where the panel can send a player, from the layout

local changed = Instance.new("BindableEvent")
-- Fires with (player) when one of their switches changes.
CheatService.Changed = changed.Event

-- { [name] = true } for each switch this player has on.
function CheatService.of(player)
	return switched[player] or {}
end

-- God mode: a force field nobody can see.
local function shield(player)
	local character = player.Character
	if not character then
		return
	end
	local worn = character:FindFirstChild(SHIELD)
	if CheatService.of(player).god then
		if not worn then
			local field = Instance.new("ForceField")
			field.Name = SHIELD
			field.Visible = false
			field.Parent = character
		end
	elseif worn then
		worn:Destroy()
	end
end

function CheatService.set(player, name, on)
	if not known[name] then
		return
	end
	local mine = switched[player] or {}
	switched[player] = mine
	mine[name] = if on then true else nil
	if name == "god" then
		shield(player)
	end
	changed:Fire(player)
end

-- Puts back what the switches say should never run out.
local function topUp(player, state)
	local mine = CheatService.of(player)
	local refilled = false
	if mine.reserve or mine.magazine then
		for name, ammo in state.ammo do
			local config = WeaponConfig.Weapons[name]
			if mine.reserve and ammo.reserve < config.reserve then
				ammo.reserve = config.reserve
				refilled = true
			end
			if mine.magazine and ammo.mag < config.magazine then
				ammo.mag = config.magazine
				refilled = true
			end
		end
	end
	if mine.tactical and not state.tacticalBusy then
		local uses = TacticalConfig.items[state.loadout.tactical].uses
		if state.tacticalUses < uses then
			state.tacticalUses = uses
			refilled = true
		end
	end
	if refilled then
		LoadoutService.push(player)
	end
	if mine.grenades then
		-- Whatever grenade this life started with goes back in its slot.
		local carried = Loadout.slots(WeaponConfig, state.loadout, state.stats)
		for _, slot in { Loadout.NADE, Loadout.NADE2 } do
			if carried[slot] and not state.slots[slot] then
				LoadoutService.addWeapon(player, slot, carried[slot], nil)
			end
		end
	end
end

-- Just in front of the player, so the mark on their screen points ahead.
local function before(root)
	return root.Position + root.CFrame.LookVector * 10
end

-- One shot from `weaponName` to where `aim` names, as if a player had fired
-- it: the same damage for the part, less what the admin's own armour stops.
function CheatService.hit(player, weaponName, aim)
	local config = type(weaponName) == "string" and WeaponConfig.Weapons[weaponName]
	local part = type(aim) == "string" and Dummy.aimPart(RangeConfig, aim)
	local state = LoadoutService.get(player)
	local _, _, root = CombatService.bodyOf(player)
	if not config or config.kind ~= "Gun" or not part or not state or not root then
		return
	end
	local zone = Damage.zoneForPart(part)
	local raw = Damage.gun(config, zone)
	Harm.deal(player, Loadout.damage(state.stats, config.class, zone, raw), before(root), SOURCE, weaponName, {
		zone = zone,
		raw = raw,
		headshot = zone == "Head",
		distance = 0,
	})
end

-- Takes a plain amount off, one of those in RangeConfig.hurt. No armour counts.
function CheatService.hurt(player, amount)
	local _, _, root = CombatService.bodyOf(player)
	if not root or table.find(RangeConfig.hurt, amount) == nil then
		return
	end
	Harm.deal(player, amount, before(root), SOURCE, "Plain", { zone = "Plain", raw = amount, headshot = false, distance = 0 })
end

function CheatService.heal(player)
	local _, humanoid = CombatService.bodyOf(player)
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
end

-- Sends the player to one of the layout's places, by its number in the list.
function CheatService.go(player, index)
	local spot = spots[index]
	local character = CombatService.bodyOf(player)
	if spot and character then
		character:PivotTo(CFrame.new(spot.pos[1], spot.pos[2], spot.pos[3]) * CFrame.Angles(0, math.rad(spot.yaw), 0))
	end
end

function CheatService.init(layout)
	spots = layout.spots

	SpawnService.Spawned:Connect(shield)

	-- Armour and the tactical item are not this service's to refuse.
	LoadoutService.PiecesRequested:Connect(function(player, loadout, fields)
		LoadoutService.setPieces(player, loadout, fields)
	end)
	-- With the switch on, what was just picked is in hand a moment later. One
	-- pick can be accepted in two steps (weapons, then armour), so wait for both.
	LoadoutService.Chosen:Connect(function(player)
		if not CheatService.of(player).instant or rearming[player] then
			return
		end
		rearming[player] = true
		task.defer(function()
			rearming[player] = nil
			if CombatService.bodyOf(player) then
				LoadoutService.reset(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		switched[player] = nil
		rearming[player] = nil
	end)

	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < TOP_UP_EVERY then
			return
		end
		since = 0
		for _, player in Players:GetPlayers() do
			local state = LoadoutService.get(player)
			if state and CombatService.bodyOf(player) then
				topUp(player, state)
			end
		end
	end)
end

return CheatService
