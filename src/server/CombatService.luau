-- Validates shots and knife swings claimed by clients, and applies all damage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressConfig = require(Shared.Config.ProgressConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Damage = require(Shared.Logic.Damage)
local HitValidation = require(Shared.Logic.HitValidation)
local Loadout = require(Shared.Logic.Loadout)
local Remotes = require(Shared.Remotes)

local LoadoutService = require(script.Parent.LoadoutService)
local MatchService = require(script.Parent.MatchService)
local StatsService = require(script.Parent.StatsService)
local TeamService = require(script.Parent.TeamService)

local CombatService = {}

local Validation = WeaponConfig.Validation
local buckets = {}

-- Simple per-player, per-remote limit. Excess calls are dropped.
function CombatService.allow(player, key, perSecond)
	local now = os.clock()
	local forPlayer = buckets[player]
	if not forPlayer then
		forPlayer = {}
		buckets[player] = forPlayer
	end
	local bucket = forPlayer[key]
	if not bucket or now - bucket.start >= 1 then
		forPlayer[key] = { start = now, count = 1 }
		return true
	end
	bucket.count += 1
	return bucket.count <= perSecond
end

function CombatService.isVector(value)
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and value.Magnitude < 1e5
end

-- Returns character, humanoid, root, head for a living player, or nil.
function CombatService.bodyOf(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if humanoid and root and head and humanoid.Health > 0 then
		return character, humanoid, root, head
	end
	return nil
end

-- True when map geometry sits between the two points.
function CombatService.blocked(from, to)
	local map = workspace:FindFirstChild("Map")
	local geometry = map and map:FindFirstChild("Geometry")
	if not geometry then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { geometry }

	local delta = to - from
	local result = workspace:Raycast(from, delta, params)
	return result ~= nil and (result.Position - from).Magnitude < delta.Magnitude - 1
end

local killedEvent = Instance.new("BindableEvent")
-- Fires with (victim, attacker, side, weaponName, assists) when one player's
-- damage kills another. `side` is the side whose score the kill went on, or
-- nil if it did not count. `assists` lists everybody else who had hurt the
-- victim just before: { { player, weapon } }.
CombatService.Killed = killedEvent.Event

local hurtBy = {} -- [victim] = { [attacker] = { at = clock, weapon = name } }: who has hurt them, and when last

-- Everybody but the killer who hurt `victim` recently enough to share in it.
local function assistsOn(victim, killer)
	local assists = {}
	local now = os.clock()
	for other, hit in hurtBy[victim] or {} do
		local recent = now - hit.at <= ProgressConfig.weapons.assistWindow
		if other ~= killer and other.Parent == Players and recent then
			table.insert(assists, { player = other, weapon = hit.weapon })
		end
	end
	hurtBy[victim] = nil
	return assists
end

function CombatService.applyDamage(victim, amount, attacker, weaponName, headshot)
	local _, humanoid = CombatService.bodyOf(victim)
	if not humanoid or amount <= 0 then
		return
	end

	humanoid:TakeDamage(amount)
	local killed = humanoid.Health <= 0
	if attacker ~= victim then
		local hits = hurtBy[victim] or {}
		hurtBy[victim] = hits
		hits[attacker] = { at = os.clock(), weapon = weaponName }
	end

	-- Being hit knocks the victim's aim, unless a Cryo Shot is holding it steady.
	local flinch = 0
	if attacker ~= victim and not LoadoutService.isSteady(victim) then
		flinch = if headshot then WeaponConfig.Flinch.head else WeaponConfig.Flinch.body
	end

	local attackerRoot = attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
	Remotes.Damaged:FireClient(victim, amount, attackerRoot and attackerRoot.Position or nil, flinch)
	if attacker ~= victim then
		Remotes.HitConfirm:FireClient(attacker, headshot, killed)
	end

	if killed then
		local side = TeamService.scoreKey(attacker)
		local counted = attacker ~= victim and MatchService.addKill(side)
		local assists = assistsOn(victim, attacker)
		if counted then
			StatsService.record(attacker, "kills")
			for _, assist in assists do
				StatsService.record(assist.player, "assists")
			end
		end
		killedEvent:Fire(victim, attacker, if counted then side else nil, weaponName, assists)
		if attacker ~= victim then
			local _, attackerHumanoid = CombatService.bodyOf(attacker)
			local left = if attackerHumanoid then math.ceil(attackerHumanoid.Health) else 0
			Remotes.Killcam:FireClient(victim, attacker, weaponName, headshot, left)
		end
		Remotes.KillFeed:FireAllClients(attacker.Name, victim.Name, weaponName, headshot)
	end
end

-- Finds the player a claimed body part belongs to.
local function victimOf(part, attacker)
	local character = part.Parent
	local victim = character and Players:GetPlayerFromCharacter(character)
	if not victim or victim == attacker or part.Name == "HumanoidRootPart" then
		return nil
	end
	return victim
end

local function onFireShot(player, origin, endPosition, hitPart)
	if not CombatService.allow(player, "FireShot", 30) then
		return
	end
	if not CombatService.isVector(origin) or not CombatService.isVector(endPosition) then
		return
	end
	if hitPart ~= nil and not (typeof(hitPart) == "Instance" and hitPart:IsA("BasePart")) then
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

	local name = LoadoutService.weaponName(state)
	local config = WeaponConfig.Weapons[name]
	local ammo = state.ammo[name]
	if not config or config.kind ~= "Gun" or not ammo then
		return
	end

	local now = os.clock()
	local nextShotAt = state.nextShotAt[name] or -math.huge
	local ok, reason = HitValidation.canFire(Validation, {
		now = now,
		ammo = ammo.mag,
		reloading = state.reloading,
		equippedAt = state.equippedAt,
		equipTime = LoadoutService.equipTime(state, config),
		nextShotAt = nextShotAt,
		lastShotAt = state.lastShotAt[name] or -math.huge,
		fireInterval = config.fireInterval,
		quickSwitchInterval = config.quickSwitchInterval,
		reEquipped = state.reEquipped[name] == true,
		origin = origin,
		shooterHead = head.Position,
	})
	if not ok then
		if reason == "NoAmmo" then
			LoadoutService.push(player) -- the client's ammo count has drifted
		end
		return
	end

	ammo.mag -= 1
	state.nextShotAt[name] = HitValidation.advance(now, nextShotAt, config.fireInterval)
	state.lastShotAt[name] = now
	state.reEquipped[name] = false
	LoadoutService.endProtection(player)

	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.ShotFired:FireClient(other, player, origin, endPosition)
		end
	end

	local victim = hitPart and victimOf(hitPart, player)
	if not victim then
		return
	end

	local valid = HitValidation.validateHit(Validation, {
		targetAlive = CombatService.bodyOf(victim) ~= nil,
		sameTeam = not TeamService.areEnemies(player, victim),
		protected = LoadoutService.isProtected(victim),
		origin = origin,
		hitPosition = endPosition,
		targetPosition = hitPart.Position,
		range = config.range,
		blocked = CombatService.blocked(origin, endPosition),
	})
	if not valid then
		return
	end

	local zone = Damage.zoneForPart(hitPart.Name)
	local amount = Loadout.damage(LoadoutService.get(victim).stats, config.class, zone, Damage.gun(config, zone))
	CombatService.applyDamage(victim, amount, player, name, zone == "Head")
end

local function onMeleeSwing(player, targetPart)
	if not CombatService.allow(player, "MeleeSwing", 6) then
		return
	end
	if targetPart ~= nil and not (typeof(targetPart) == "Instance" and targetPart:IsA("BasePart")) then
		return
	end
	if not MatchService.combatAllowed() then
		return
	end

	local state = LoadoutService.get(player)
	local character, _, root, head = CombatService.bodyOf(player)
	if not state or not character then
		return
	end

	local name = LoadoutService.weaponName(state)
	local config = WeaponConfig.Weapons[name]
	if not config or config.kind ~= "Melee" then
		return
	end

	local now = os.clock()
	local slack = Validation.jitterSlack
	local equipTime = LoadoutService.equipTime(state, config)
	if now - state.equippedAt < equipTime - slack or now - state.lastSwing < config.swingInterval - slack then
		return
	end
	state.lastSwing = now
	LoadoutService.endProtection(player)

	local victim = targetPart and victimOf(targetPart, player)
	if not victim then
		return
	end
	local victimCharacter, _, victimRoot = CombatService.bodyOf(victim)

	local valid = HitValidation.validateHit(Validation, {
		targetAlive = victimCharacter ~= nil,
		sameTeam = not TeamService.areEnemies(player, victim),
		protected = LoadoutService.isProtected(victim),
		origin = head.Position,
		hitPosition = targetPart.Position,
		targetPosition = targetPart.Position,
		range = config.reach + Validation.meleeTolerance,
		blocked = CombatService.blocked(head.Position, targetPart.Position),
	})
	if not valid then
		return
	end

	local amount = Damage.knife(config, root.Position, victimRoot.Position, victimRoot.CFrame.LookVector)
	CombatService.applyDamage(victim, amount, player, name, false)
end

function CombatService.init()
	Remotes.FireShot.OnServerEvent:Connect(onFireShot)
	Remotes.MeleeSwing.OnServerEvent:Connect(onMeleeSwing)
	-- Which way a character faces is already known to everyone; how far up or
	-- down they are looking is not. A dead teammate's view of them needs it.
	Remotes.Aim.OnServerEvent:Connect(function(player, pitch)
		if typeof(pitch) == "number" and pitch == pitch and CombatService.allow(player, "Aim", 12) then
			player:SetAttribute("AimPitch", math.clamp(pitch, -1.55, 1.55))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		hurtBy[player] = nil
	end)
end

return CombatService
