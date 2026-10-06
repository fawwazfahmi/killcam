-- The bomb in Search and Destroy: who carries it, where it lies, planting,
-- defusing and the blast. The carrier has it in slot 5 and plants by holding
-- fire on a site with it out, or drops it with G; defenders defuse by holding
-- E beside it. The round rules live in Shared.Logic.BombRound; this service
-- owns the instances and decides whether a player's hold on the use key counts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared.Config.MatchConfig)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
local LoadoutService = require(script.Parent.LoadoutService)
local MatchService = require(script.Parent.MatchService)
local SpawnService = require(script.Parent.SpawnService)
local StatsService = require(script.Parent.StatsService)
local TeamService = require(script.Parent.TeamService)

local BombService = {}

local rules = MatchConfig.bomb
local DURATION = { Plant = rules.plantTime, Defuse = rules.defuseTime }

local bomb -- the Part; parented to workspace only while a round has a bomb
local status = "None" -- "None", "Carried", "Dropped", "Planted" or "Defused"
local carrier = nil
local site = nil -- name of the site it is planted at
local lastCarrierPosition = nil
local droppedBy, droppedAt = nil, 0 -- who last put it down on purpose, and when
local holds = {} -- [player] = { kind = "Plant" | "Defuse", since = clock, origin = Vector3 }

local function build()
	local part = Instance.new("Part")
	part.Name = "Bomb"
	part.Size = Vector3.new(1.6, 0.8, 1)
	part.Color = Color3.fromRGB(30, 32, 38)
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false -- shots pass through it
	part.CanTouch = false
	part.Massless = true

	local lamp = Instance.new("Part")
	lamp.Name = "Lamp"
	lamp.Size = Vector3.new(1.2, 0.12, 0.3)
	lamp.Color = Color3.fromRGB(255, 170, 60)
	lamp.Material = Enum.Material.Neon
	lamp.CanCollide = false
	lamp.CanQuery = false
	lamp.CanTouch = false
	lamp.Massless = true
	lamp.CFrame = part.CFrame * CFrame.new(0, 0.42, 0)
	lamp.Parent = part

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = lamp
	weld.Parent = lamp

	local light = Instance.new("PointLight")
	light.Color = lamp.Color
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = lamp

	return part
end

local function announce(target)
	local payload = {
		status = status,
		carrier = carrier,
		position = if bomb.Parent then bomb.Position else nil,
		site = site,
	}
	if target then
		Remotes.BombUpdate:FireClient(target, payload)
	else
		Remotes.BombUpdate:FireAllClients(payload)
	end
end

-- Takes the bomb off whoever has it, including out of their slot 5.
local function release()
	local weld = bomb:FindFirstChild("Carry")
	if weld then
		weld:Destroy()
	end
	if carrier then
		LoadoutService.setBomb(carrier, false)
	end
end

local function give(player)
	local character = CombatService.bodyOf(player)
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart"))
	if not torso then
		return false
	end
	release()
	bomb.Anchored = false
	bomb.CFrame = torso.CFrame * CFrame.new(0, 0, 0.9)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "Carry"
	weld.Part0 = torso
	weld.Part1 = bomb
	weld.Parent = bomb
	bomb.Parent = workspace

	status, carrier, site = "Carried", player, nil
	lastCarrierPosition = torso.Position
	LoadoutService.setBomb(player, true)
	announce()
	return true
end

-- The point on the map straight below `position`.
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

local function setDown(position, newStatus, siteName)
	release()
	bomb.Anchored = true
	bomb.CFrame = CFrame.new(groundBelow(position) + Vector3.new(0, 0.4, 0))
	bomb.Parent = workspace
	status, carrier, site = newStatus, nil, siteName
	announce()
end

local function remove()
	release()
	bomb.Parent = nil
	status, carrier, site = "None", nil, nil
	announce()
end

-- The site whose footprint contains `position`, if any.
local function siteAt(position)
	local map = workspace:FindFirstChild("Map")
	local sites = map and map:FindFirstChild("Sites")
	for _, area in (sites and sites:GetChildren() or {}) do
		local offset = area.CFrame:PointToObjectSpace(position)
		if math.abs(offset.X) <= area.Size.X / 2 and math.abs(offset.Z) <= area.Size.Z / 2 then
			return area
		end
	end
	return nil
end

-- If `player` may be planting or defusing right now, returns where they stand
-- (and, for a plant, the site). Otherwise nil.
local function holding(player, kind)
	local character, _, root = CombatService.bodyOf(player)
	if not character then
		return nil
	end
	if kind == "Plant" then
		if MatchService.phase() ~= "Live" or status ~= "Carried" or carrier ~= player then
			return nil
		end
		-- The bomb has to be in their hands.
		local state = LoadoutService.get(player)
		if not state or LoadoutService.weaponName(state) ~= "Bomb" then
			return nil
		end
		local area = siteAt(root.Position)
		return if area then root.Position else nil, area
	end
	local team = TeamService.teamName(player)
	if MatchService.phase() ~= "Planted" or status ~= "Planted" or not team or team == MatchService.attackers() then
		return nil
	end
	if (root.Position - bomb.Position).Magnitude > rules.defuseReach then
		return nil
	end
	return root.Position
end

local function stopHold(player)
	if holds[player] then
		holds[player] = nil
		Remotes.BombProgress:FireClient(player, nil)
	end
end

local function stopAllHolds()
	for player in holds do
		stopHold(player)
	end
end

local function onBombUse(player, held)
	if typeof(held) ~= "boolean" or not CombatService.allow(player, "BombUse", 10) then
		return
	end
	if not held then
		stopHold(player)
		return
	end
	if holds[player] then
		return
	end
	local kind = if status == "Carried" and carrier == player then "Plant" else "Defuse"
	local position = holding(player, kind)
	if position then
		holds[player] = { kind = kind, since = os.clock(), origin = position }
		Remotes.BombProgress:FireClient(player, kind, DURATION[kind])
	end
end

local function stepHolds()
	for player, hold in holds do
		local position, area = holding(player, hold.kind)
		if not position or (position - hold.origin).Magnitude > rules.holdSlack then
			stopHold(player)
		elseif os.clock() - hold.since >= DURATION[hold.kind] then
			stopHold(player)
			if hold.kind == "Plant" then
				if MatchService.plantBomb() then
					StatsService.record(player, "plants")
					setDown(position, "Planted", area.Name)
				end
			elseif MatchService.defuseBomb() then
				StatsService.record(player, "defuses")
				status = "Defused"
				announce()
			end
		end
	end
end

local function stepCarrier()
	if status == "Carried" then
		local _, _, root = CombatService.bodyOf(carrier)
		if root then
			lastCarrierPosition = root.Position
		else
			-- The carrier died or left: the bomb stays where they were.
			setDown(lastCarrierPosition or bomb.Position, "Dropped", nil)
		end
	elseif status == "Dropped" and MatchService.phase() == "Live" then
		for _, player in Players:GetPlayers() do
			-- Whoever dropped it has to walk away first.
			local tooSoon = player == droppedBy and os.clock() - droppedAt < MatchConfig.drops.rePickupDelay
			if TeamService.teamName(player) == MatchService.attackers() and not tooSoon then
				local _, _, root = CombatService.bodyOf(player)
				if root and (root.Position - bomb.Position).Magnitude <= rules.pickupReach then
					give(player)
					break
				end
			end
		end
	end
end

-- The carrier puts the bomb down on purpose, for a teammate to take.
function BombService.drop(player)
	local _, _, root = CombatService.bodyOf(player)
	if status ~= "Carried" or carrier ~= player or not root then
		return
	end
	droppedBy, droppedAt = player, os.clock()
	setDown(root.Position + root.CFrame.LookVector * 3, "Dropped", nil)
end

local function setFrozen(character, frozen)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = frozen
	end
end

local function unfreezeEveryone()
	for _, player in Players:GetPlayers() do
		setFrozen(player.Character, false)
	end
end

local function startRound()
	unfreezeEveryone()
	local attackers = {}
	for _, player in Players:GetPlayers() do
		if TeamService.teamName(player) == MatchService.attackers() and CombatService.bodyOf(player) then
			table.insert(attackers, player)
		end
	end
	if #attackers > 0 then
		give(attackers[math.random(#attackers)])
	end
end

local function explode()
	local position = bomb.Position
	Remotes.Explosion:FireAllClients(position, rules.blastRadius * 2, 0)
	for _, player in Players:GetPlayers() do
		local _, humanoid, root = CombatService.bodyOf(player)
		if humanoid and (root.Position - position).Magnitude <= rules.blastRadius then
			humanoid.Health = 0
		end
	end
	remove()
end

local function onMatchChanged(event)
	if event == "Started" or event == "RoundStarted" then
		stopAllHolds()
		remove()
	elseif event == "Live" then
		startRound()
	elseif event == "Exploded" then
		stopAllHolds()
		explode()
	elseif event == "RoundOver" or event == "MatchOver" then
		stopAllHolds()
	elseif event == "Reset" then
		stopAllHolds()
		remove()
		unfreezeEveryone()
	end
end

function BombService.init()
	if MatchService.mode() ~= "SND" then
		return
	end
	bomb = build()

	Remotes.BombUse.OnServerEvent:Connect(onBombUse)
	MatchService.Changed:Connect(onMatchChanged)

	-- Everyone is held at their spawn until the round goes live.
	SpawnService.Spawned:Connect(function(_player, character)
		if MatchService.phase() == "Prep" then
			setFrozen(character, true)
		end
	end)

	Players.PlayerAdded:Connect(announce)
	Players.PlayerRemoving:Connect(function(player)
		holds[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		stepCarrier()
		stepHolds()
	end)
end

return BombService
