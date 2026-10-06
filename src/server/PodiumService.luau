-- The ceremony after a match: the top three are lifted onto a stage above the
-- map and posed according to how the match went for them (see Shared.Logic.
-- Podium and Shared.Logic.Pose). Everyone's camera is sent to the stage by the
-- client (see PodiumController); this service owns the stage and the poses.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Podium = require(Shared.Logic.Podium)
local Pose = require(Shared.Logic.Pose)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
local MatchService = require(script.Parent.MatchService)
local SpawnService = require(script.Parent.SpawnService)
local StatsService = require(script.Parent.StatsService)
local TeamService = require(script.Parent.TeamService)

local PodiumService = {}

local PLACES = 3
local HEIGHT = 70 -- studs above the top of the map's bounds
local PLINTH = { 7, 7, 7 } -- the middle plinth; the others are lower
local STEP = 2.5 -- studs each place down from the one above
local SPACING = 9 -- studs between plinth centres
-- Where each place stands, in order: the winner in the middle.
local ORDER = { 0, -1, 1 }

local stage = nil -- the Model, while a ceremony is running
local posed = {} -- [player] = { character, mood, joints = { [Motor6D] = rest C0 } }
local startedAt = 0

-- Stops a character's own animations, so the pose is the only thing moving it.
local function freezeAnimations(character)
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate.Disabled = true
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end
end

local function collectJoints(character)
	local found = {}
	for _, name in Pose.JOINTS do
		local motor = character:FindFirstChild(name, true)
		if motor and motor:IsA("Motor6D") then
			found[motor] = motor.C0
		end
	end
	return found
end

-- Where the stage sits: above the middle of the map.
local function stageCFrame()
	local map = workspace:FindFirstChild("Map")
	local bounds = map and map:FindFirstChild("Bounds")
	local centre = if bounds then bounds.Position else Vector3.new(0, 0, 0)
	local top = if bounds then bounds.Position.Y + bounds.Size.Y / 2 else 60
	return CFrame.new(centre.X, top + HEIGHT, centre.Z)
end

local function block(parent, name, size, offset, base, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = base * CFrame.new(offset)
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

-- Builds the stage and returns where each place stands, highest first.
local function buildStage(base)
	stage = Instance.new("Model")
	stage.Name = "Podium"

	local accent = Color3.fromRGB(table.unpack(Theme.accent))
	local floor = Color3.fromRGB(32, 34, 42)
	block(stage, "Floor", Vector3.new(44, 1, 26), Vector3.new(0, -0.5, 0), base, floor, Enum.Material.SmoothPlastic)
	block(stage, "Backdrop", Vector3.new(44, 24, 1), Vector3.new(0, 11.5, -13), base, floor, Enum.Material.SmoothPlastic)
	block(stage, "Trim", Vector3.new(44, 0.4, 1.2), Vector3.new(0, 23.5, -13), base, accent, Enum.Material.Neon)

	local stands = {}
	for place = 1, PLACES do
		local height = PLINTH[2] - (place - 1) * STEP
		local offset = Vector3.new(ORDER[place] * SPACING, height / 2, 0)
		block(stage, "Plinth" .. place, Vector3.new(PLINTH[1], height, PLINTH[3]), offset, base, floor, Enum.Material.Metal)
		block(
			stage,
			"Edge" .. place,
			Vector3.new(PLINTH[1] + 0.3, 0.3, PLINTH[3] + 0.3),
			offset + Vector3.new(0, height / 2, 0),
			base,
			accent,
			Enum.Material.Neon
		)
		-- Where the player's feet go, facing out of the stage.
		stands[place] = base * CFrame.new(ORDER[place] * SPACING, height, 0)
	end

	stage.Parent = workspace
	return stands
end

-- Puts a player on the stage: alive, anchored, animations off.
local function place(player, stand, mood)
	if not CombatService.bodyOf(player) then
		SpawnService.spawn(player, true) -- they died during the match
		task.wait() -- let the character load
	end
	local character, humanoid, root = CombatService.bodyOf(player)
	if not character or not root then
		return false
	end

	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	freezeAnimations(character)
	-- Standing on the plinth, facing the crowd.
	character:PivotTo(stand * CFrame.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0))
	root.Anchored = true
	-- The server poses them, so it must own them: otherwise the owning client
	-- keeps simulating the character and fights the pose.
	pcall(root.SetNetworkOwner, root, nil)

	posed[player] = { character = character, mood = mood, stand = stand, joints = collectJoints(character) }
	return true
end

local function release(player)
	local entry = posed[player]
	posed[player] = nil
	if not entry or not entry.character.Parent then
		return
	end
	for motor, rest in entry.joints do
		if motor.Parent then
			motor.C0 = rest
		end
	end
	local animate = entry.character:FindFirstChild("Animate")
	if animate then
		animate.Disabled = false
	end
	local humanoid = entry.character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
	end
	local root = entry.character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = false
		pcall(root.SetNetworkOwnershipAuto, root)
	end
end

local function clear()
	for player in posed do
		release(player)
	end
	if stage then
		stage:Destroy()
		stage = nil
	end
	Remotes.Podium:FireAllClients(nil)
end

-- Drives the poses, every frame, for as long as the ceremony lasts.
local function step()
	local t = os.clock() - startedAt
	for _, entry in posed do
		if entry.character.Parent then
			local pose = Pose.sample(entry.mood, t)
			local root = entry.character:FindFirstChild("HumanoidRootPart")
			local humanoid = entry.character:FindFirstChildOfClass("Humanoid")
			if root and humanoid then
				root.CFrame = entry.stand
					* CFrame.new(0, root.Size.Y / 2 + humanoid.HipHeight + pose.root.lift, 0)
					* CFrame.Angles(0, math.rad(pose.root.turn), 0)
			end
			for motor, rest in entry.joints do
				local angles = pose.joints[motor.Name]
				if angles then
					motor.C0 = rest * CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
				end
			end
		end
	end
end

-- The podium is the top three by whatever this mode counts (see
-- MatchConfig.mvp), not always by kills.
local function begin()
	clear()

	local top = StatsService.top(PLACES)
	if #top == 0 then
		return
	end

	local winner = MatchService.winner()
	local nobodyLost = winner == nil or winner == "Draw"
	local mvp = StatsService.mvp()
	local base = stageCFrame()
	local stands = buildStage(base)

	local entries = {}
	for index, result in top do
		local player = result.player
		if player.Parent == Players then
			local won = not nobodyLost and winner == TeamService.scoreKey(player)
			local isMvp = result.name == mvp
			local mood = Podium.mood(won, isMvp, nobodyLost)
			if place(player, stands[index], mood) then
				table.insert(entries, {
					name = player.Name,
					place = index,
					kills = result.kills,
					plants = result.plants,
					defuses = result.defuses,
					score = result.score,
					mood = mood,
					mvp = isMvp,
					position = stands[index].Position,
				})
			end
		end
	end

	startedAt = os.clock()
	Remotes.Podium:FireAllClients({ camera = (base * CFrame.new(0, 7, 26)).Position, look = base.Position, entries = entries })
end

function PodiumService.init()
	MatchService.Changed:Connect(function(event)
		if event == "Ended" or event == "MatchOver" then
			-- After ProfileService, so the MVP and payouts are already worked out.
			task.defer(begin)
		elseif event == "Started" or event == "RoundStarted" or event == "Reset" then
			clear()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		posed[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		if stage then
			step()
		end
	end)
end

return PodiumService
