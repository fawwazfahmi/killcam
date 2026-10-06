-- Player lifecycle: joining, spawning, dying, respawning and leaving the map.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared.Config.MatchConfig)
local MovementConfig = require(Shared.Config.MovementConfig)
local Damage = require(Shared.Logic.Damage)
local SpawnSelection = require(Shared.Logic.SpawnSelection)

local CombatService = require(script.Parent.CombatService)
local LoadoutService = require(script.Parent.LoadoutService)
local MatchService = require(script.Parent.MatchService)
local StatsService = require(script.Parent.StatsService)
local TeamService = require(script.Parent.TeamService)

local SpawnService = {}

local spawning = {}
local generation = {}
local heldUntil = {} -- [player] = the clock time their automatic respawn waits for
local spawned = Instance.new("BindableEvent")

-- Fires with (player, character) once a player is standing at their spawn.
SpawnService.Spawned = spawned.Event

local died = Instance.new("BindableEvent")
-- Fires with (player, position) the moment a player dies, before anything is
-- taken from them.
SpawnService.Died = died.Event

local function pickSpawn(player)
	local map = workspace:FindFirstChild("Map")
	local spawns = map and map:FindFirstChild("Spawns")
	local points = {}
	if spawns and TeamService.isFreeForAll() then
		-- Everyone can appear at any spawn on the map.
		for _, folder in spawns:GetChildren() do
			for _, point in folder:GetChildren() do
				table.insert(points, point)
			end
		end
	elseif spawns then
		local folder = spawns:FindFirstChild(MatchService.spawnTeam(TeamService.teamName(player)) or "")
		points = folder and folder:GetChildren() or {}
	end
	if #points == 0 then
		return CFrame.new(0, 10, 0)
	end

	local positions = {}
	for index, point in points do
		positions[index] = point.Position
	end

	local enemies = {}
	for _, other in Players:GetPlayers() do
		if TeamService.areEnemies(player, other) then
			local character, _, root = CombatService.bodyOf(other)
			if character then
				table.insert(enemies, root.Position)
			end
		end
	end

	return points[SpawnSelection.pick(positions, enemies, math.random)].CFrame
end

-- Hurts the player when they land from a long drop. The fastest downward
-- speed since they last had their feet under them decides how much.
local function watchFalls(player, character, humanoid)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local fastest = 0
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not character.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			return
		end
		local falling = -root.AssemblyLinearVelocity.Y
		if falling > 1 then
			fastest = math.max(fastest, falling)
		elseif fastest > 0 then
			local state = LoadoutService.get(player)
			local amount = Damage.fall(MovementConfig.fall, fastest, state and state.stats.fallScale or 1)
			fastest = 0
			if amount > 0 and not LoadoutService.isProtected(player) then
				humanoid:TakeDamage(amount)
			end
		end
	end)
end

-- Keeps the automatic respawn from happening for `seconds` (a player who is
-- buying a revive should not be respawned from under the purchase window).
-- Zero lets it go ahead.
function SpawnService.hold(player, seconds)
	heldUntil[player] = os.clock() + seconds
end

-- `force` spawns the player even when the mode would normally make them wait
-- (the end-of-match ceremony and revives use it). `at`, if given, is where
-- they appear instead of one of their spawns.
function SpawnService.spawn(player, force, at)
	if player.Parent ~= Players or spawning[player] or (not force and not MatchService.canSpawn()) then
		return
	end
	spawning[player] = true
	generation[player] = (generation[player] or 0) + 1
	heldUntil[player] = nil
	local thisLife = generation[player]

	TeamService.beforeSpawn(player)
	local spawnCFrame = at or pickSpawn(player)
	player:LoadCharacter()
	spawning[player] = nil

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local state = LoadoutService.get(player)
	if not humanoid or not state then
		return
	end

	humanoid.MaxHealth = MatchConfig.maxHealth
	humanoid.Health = MatchConfig.maxHealth
	humanoid.WalkSpeed = MovementConfig.runSpeed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = MovementConfig.jumpHeight
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	character:PivotTo(spawnCFrame)

	local shield = Instance.new("ForceField")
	shield.Name = "SpawnProtection"
	shield.Parent = character
	Debris:AddItem(shield, MatchConfig.spawnProtection)
	state.protectedUntil = os.clock() + MatchConfig.spawnProtection

	LoadoutService.reset(player)
	watchFalls(player, character, humanoid)
	spawned:Fire(player, character)

	humanoid.Died:Once(function()
		local root = character:FindFirstChild("HumanoidRootPart")
		died:Fire(player, if root then root.Position else spawnCFrame.Position)

		-- The body is cleared away after a moment, unless a respawn already replaced it.
		task.delay(MatchConfig.corpseTime, function()
			if player.Character == character then
				character:Destroy()
			end
		end)

		StatsService.record(player, "deaths")
		task.delay(MatchConfig.respawnDelay, function()
			while generation[player] == thisLife and (heldUntil[player] or 0) > os.clock() do
				task.wait(0.2)
			end
			-- Skip if something else (a new match or round, or a revive) already
			-- respawned them, or if this mode keeps the dead out until the next round.
			if generation[player] == thisLife and MatchService.respawns() then
				SpawnService.spawn(player)
			end
		end)
	end)
end

local function addPlayer(player)
	LoadoutService.add(player)
	TeamService.assign(player)

	MatchService.sendTo(player)
	SpawnService.spawn(player)
end

local function removePlayer(player)
	LoadoutService.remove(player)
	spawning[player] = nil
	generation[player] = nil
	heldUntil[player] = nil
end

local function killOutOfBounds()
	-- Only while the match is being played: the podium is outside the map.
	if not MatchService.combatAllowed() then
		return
	end
	local map = workspace:FindFirstChild("Map")
	local bounds = map and map:FindFirstChild("Bounds")
	if not bounds then
		return
	end
	local half = bounds.Size / 2
	for _, player in Players:GetPlayers() do
		local character, humanoid, root = CombatService.bodyOf(player)
		if character then
			local offset = bounds.CFrame:PointToObjectSpace(root.Position)
			if math.abs(offset.X) > half.X or math.abs(offset.Y) > half.Y or math.abs(offset.Z) > half.Z then
				humanoid.Health = 0
			end
		end
	end
end

function SpawnService.init()
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(addPlayer, player)
	end

	-- A new match starts everyone fresh. StatsService clears the scores.
	MatchService.Started:Connect(function()
		for _, player in Players:GetPlayers() do
			task.spawn(SpawnService.spawn, player)
		end
	end)

	-- A new round puts everyone back at their spawn, alive, and keeps the stats.
	MatchService.RoundStarted:Connect(function()
		for _, player in Players:GetPlayers() do
			task.spawn(SpawnService.spawn, player)
		end
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceCheck += dt
		if sinceCheck >= 0.5 then
			sinceCheck = 0
			killOutOfBounds()
		end
	end)
end

return SpawnService
