-- Grenades: frag, smoke, gas and flashbang. They are simulated on the server:
-- the thrower only says which way. A player carries one, in slot 4.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Damage = require(Shared.Logic.Damage)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
local LoadoutService = require(script.Parent.LoadoutService)
local MatchService = require(script.Parent.MatchService)
local TeamService = require(script.Parent.TeamService)

local GrenadeService = {}

local GAS_TICK = 0.5 -- seconds between gas damage ticks
local CLOUD_PUFFS = 14

-- Friendly fire is off, but a thrower can hurt themselves.
local function canHurt(thrower, victim)
	return victim == thrower or TeamService.areEnemies(thrower, victim)
end

-- A cloud made of overlapping balls. One big ball would be see-through from
-- the inside; a cluster is not. Shots and players pass through it.
local function cloud(position, radius, color, transparency, lifetime)
	local model = Instance.new("Model")
	model.Name = "Cloud"
	for _ = 1, CLOUD_PUFFS do
		local size = radius * (0.9 + math.random() * 0.5)
		local offset = Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 0.5, math.random() - 0.5) * radius
		local puff = Instance.new("Part")
		puff.Shape = Enum.PartType.Ball
		puff.Size = Vector3.new(size, size, size)
		puff.Position = position + offset + Vector3.new(0, radius * 0.25, 0)
		puff.Color = color
		puff.Material = Enum.Material.SmoothPlastic
		puff.Transparency = transparency
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CanTouch = false
		puff.CastShadow = false
		puff.Parent = model
	end
	model.Parent = workspace
	Debris:AddItem(model, lifetime)
end

local EFFECTS = {}

function EFFECTS.Frag(thrower, position, config)
	Remotes.Explosion:FireAllClients(position, config.radius, config.knockback)
	for _, victim in Players:GetPlayers() do
		local character, _, root = CombatService.bodyOf(victim)
		if character and canHurt(thrower, victim) and not LoadoutService.isProtected(victim) then
			local amount = Damage.grenade(config, (root.Position - position).Magnitude)
			if amount > 0 and not CombatService.blocked(position, root.Position) then
				CombatService.applyDamage(victim, amount, thrower, "Frag", false)
			end
		end
	end
end

function EFFECTS.Smoke(_thrower, position, config)
	cloud(position, config.radius, Color3.fromRGB(196, 198, 204), 0, config.duration)
end

function EFFECTS.Gas(thrower, position, config)
	cloud(position, config.radius, Color3.fromRGB(150, 190, 60), 0.55, config.duration)
	task.spawn(function()
		for _ = 1, math.floor(config.duration / GAS_TICK) do
			task.wait(GAS_TICK)
			if not MatchService.combatAllowed() or thrower.Parent ~= Players then
				return
			end
			for _, victim in Players:GetPlayers() do
				local character, _, root = CombatService.bodyOf(victim)
				local inside = character and (root.Position - position).Magnitude <= config.radius
				if inside and canHurt(thrower, victim) and not LoadoutService.isProtected(victim) then
					CombatService.applyDamage(victim, config.damagePerSecond * GAS_TICK, thrower, "Gas", false)
				end
			end
		end
	end)
end

-- Everyone with a clear line to it is told; each client works out how much of
-- it they were looking at. Flashbangs do not pick sides.
function EFFECTS.Flash(_thrower, position, config)
	for _, victim in Players:GetPlayers() do
		local character, _, _, head = CombatService.bodyOf(victim)
		if character then
			local distance = (head.Position - position).Magnitude
			if distance < config.radius and not CombatService.blocked(position, head.Position) then
				Remotes.Flash:FireClient(victim, position, config.duration * (1 - distance / config.radius))
			end
		end
	end
end

local function detonate(thrower, ball, config)
	if not ball.Parent then
		return
	end
	local position = ball.Position
	ball:Destroy()
	-- Nothing happens after the round ended or once the thrower has left.
	if MatchService.combatAllowed() and thrower.Parent == Players then
		EFFECTS[config.effect](thrower, position, config)
	end
end

local function onThrow(player, direction)
	if not CombatService.allow(player, "ThrowGrenade", 2) then
		return
	end
	if not CombatService.isVector(direction) or direction.Magnitude < 1e-3 then
		return
	end
	if not MatchService.combatAllowed() then
		return
	end

	local state = LoadoutService.get(player)
	local character, _, _, head = CombatService.bodyOf(player)
	if not state or not character then
		return
	end
	local config = WeaponConfig.Weapons[LoadoutService.weaponName(state)]
	if not config or config.kind ~= "Grenade" then
		return
	end
	local equipTime = LoadoutService.equipTime(state, config)
	if os.clock() - state.equippedAt < equipTime - WeaponConfig.Validation.jitterSlack then
		return
	end

	LoadoutService.endProtection(player)
	LoadoutService.removeWeapon(player, state.equipped) -- also switches them to another weapon

	local unit = direction.Unit
	local ball = Instance.new("Part")
	ball.Name = "Grenade"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1, 1, 1)
	ball.Color = Color3.fromRGB(74, 82, 96)
	ball.Material = Enum.Material.Metal
	ball.Position = head.Position + unit * 2.5
	ball.Parent = workspace
	ball:SetNetworkOwner(nil)
	ball.AssemblyLinearVelocity = unit * config.throwSpeed + Vector3.new(0, config.throwLift, 0)

	task.delay(config.fuse, detonate, player, ball, config)
end

function GrenadeService.init()
	Remotes.ThrowGrenade.OnServerEvent:Connect(onThrow)
end

return GrenadeService
