-- Guns on the ground. G drops the gun in hand (or the bomb), a dying player
-- leaves their best gun at their body, and walking over a gun picks it up if
-- there is a free slot for it (see Loadout.slotForPickup).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared.Config.MatchConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Loadout = require(Shared.Logic.Loadout)
local WeaponModels = require(Shared.WeaponModels)
local Remotes = require(Shared.Remotes)

local BombService = require(script.Parent.BombService)
local CombatService = require(script.Parent.CombatService)
local LoadoutService = require(script.Parent.LoadoutService)
local MatchService = require(script.Parent.MatchService)
local SpawnService = require(script.Parent.SpawnService)

local DropService = {}

local rules = MatchConfig.drops

local folder
local drops = {} -- [model] = { name, ammo, position, droppedBy, at }

local function groundBelow(position)
	local map = workspace:FindFirstChild("Map")
	local geometry = map and map:FindFirstChild("Geometry")
	if geometry then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { geometry }
		local result = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), params)
		if result then
			return result.Position
		end
	end
	return position - Vector3.new(0, 3, 0)
end

-- Lays a gun on the ground under `position`.
local function place(name, ammo, position, droppedBy)
	local config = WeaponConfig.Weapons[name]
	local at = groundBelow(position) + Vector3.new(0, 0.3, 0)

	local model = WeaponModels.build(config.model)
	model.Name = name
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false -- shots pass through it
			part.CanTouch = false
		end
	end
	-- On its side, turned a random way.
	model:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.random() * math.pi * 2, math.rad(90)))
	model.Parent = folder

	drops[model] = { name = name, ammo = ammo, position = at, droppedBy = droppedBy, at = os.clock() }
end

local function clear()
	for model in drops do
		model:Destroy()
	end
	table.clear(drops)
end

-- Takes the gun out of `slot` and leaves it on the ground at `position`.
local function dropSlot(player, slot, position)
	local state = LoadoutService.get(player)
	local name = state and state.slots[slot]
	local config = name and WeaponConfig.Weapons[name]
	if not config or config.kind ~= "Gun" then
		return
	end
	local _, ammo = LoadoutService.removeWeapon(player, slot)
	place(name, ammo, position, player)
end

local function onDropWeapon(player)
	if not CombatService.allow(player, "DropWeapon", 4) then
		return
	end
	local state = LoadoutService.get(player)
	local character, _, root = CombatService.bodyOf(player)
	if not state or not character then
		return
	end
	if state.equipped == Loadout.BOMB then
		BombService.drop(player)
	else
		-- A little in front of them, so it is not underfoot.
		dropSlot(player, state.equipped, root.Position + root.CFrame.LookVector * 3)
	end
end

local function stepPickups()
	local now = os.clock()
	for model, drop in drops do
		if now - drop.at > rules.lifetime then
			drops[model] = nil
			model:Destroy()
			continue
		end
		for _, player in Players:GetPlayers() do
			local character, _, root = CombatService.bodyOf(player)
			local state = LoadoutService.get(player)
			-- Whoever dropped it has to walk away first, or they would pick it straight back up.
			local tooSoon = player == drop.droppedBy and now - drop.at < rules.rePickupDelay
			if character and state and not tooSoon and (root.Position - drop.position).Magnitude <= rules.reach then
				local slot = Loadout.slotForPickup(WeaponConfig, state.slots, state.stats, drop.name)
				if slot and LoadoutService.addWeapon(player, slot, drop.name, drop.ammo) then
					drops[model] = nil
					model:Destroy()
					break
				end
			end
		end
	end
end

function DropService.init()
	folder = Instance.new("Folder")
	folder.Name = "Drops"
	folder.Parent = workspace

	Remotes.DropWeapon.OnServerEvent:Connect(onDropWeapon)

	-- A dying player leaves their best gun where they fell.
	SpawnService.Died:Connect(function(player, position)
		local state = LoadoutService.get(player)
		local slot = state and Loadout.deathDropSlot(WeaponConfig, state.slots)
		if slot then
			dropSlot(player, slot, position)
		end
	end)

	-- A new match or round starts with a clean floor.
	MatchService.Changed:Connect(function(event)
		if event == "Started" or event == "RoundStarted" or event == "Reset" then
			clear()
		end
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceCheck += dt
		if sinceCheck >= 0.1 then
			sinceCheck = 0
			stepPickups()
		end
	end)
end

return DropService
