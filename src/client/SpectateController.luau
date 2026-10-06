-- What a player sees while dead.
--
-- First the killcam: the camera swings from where they fell to whoever killed
-- them, with a card saying who it was, what with, and how much health the
-- killer had left. It is a look, not a replay.
--
-- What follows depends on whether they are coming back (Shared.Logic.Spectate):
--
--   Out until the round ends (Search and Destroy): a living teammate's eyes,
--   their view and their weapon, with the others to step through. Teammates
--   only. Skipping the killcam gets there sooner. With no teammate left, their
--   own body from outside.
--
--   About to respawn (Team Deathmatch, free-for-all): no spectating. The
--   killcam holds until they are back, and skipping it follows the killer
--   from behind instead. A figure at the bottom fills from the feet up as the
--   respawn approaches.
--
-- Everything here works without a keyboard: skip and the arrows are buttons
-- big enough for a thumb, and a controller has its own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Icons = require(Shared.Config.Icons)
local MatchConfig = require(Shared.Config.MatchConfig)
local ShopConfig = require(Shared.Config.ShopConfig)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Rank = require(Shared.Logic.Rank)
local Spectate = require(Shared.Logic.Spectate)
local Remotes = require(Shared.Remotes)

local Fit = require(script.Parent.Fit)
local PixelArt = require(script.Parent.PixelArt)

local SpectateController = {}

local KILLCAM_TIME = 2.6 -- seconds on the killer before moving on, where there is anything to move on to
local KILLCAM_FOV = 52
local KILLCAM_TURN = 5 -- how quickly the camera swings round, per second
local KILL_NEWS_LASTS = 1.5 -- seconds a kill report stays usable while waiting for the death
local KILL_NEWS_WAIT = 0.4 -- seconds to wait for one after dying
local BODY_DISTANCE = 12 -- studs from your own body, or from your killer, when looking at one from outside
local EYE_HEIGHT = 0.25 -- studs above the middle of a teammate's head
local PITCH_EASE = 14 -- how quickly the view follows a teammate looking up or down, per second
local JOIN_WAIT = 2 -- seconds after arriving without a body before starting to watch
local AIM_EVERY = 0.12 -- seconds between telling the server where we are looking
local AIM_CHANGE = 0.02 -- radians it has to have moved by to be worth telling
local FIGURE_CELL = 5 -- pixels to a cell of the respawn figure

local PREVIOUS = { [Enum.KeyCode.A] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.ButtonL1] = true }
local NEXT = { [Enum.KeyCode.D] = true, [Enum.KeyCode.Right] = true, [Enum.KeyCode.ButtonR1] = true }
local SKIP = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.ButtonA] = true }

local DISPLAY = Enum.Font[Theme.display]
local FONT = Enum.Font[Theme.body]
local BOLD = Enum.Font[Theme.bodyBold]
local SIZE = Theme.size

local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local PAPER = Color3.fromRGB(table.unpack(Theme.paper))
local MUTED = Color3.fromRGB(table.unpack(Theme.muted))
local PANEL = Color3.fromRGB(table.unpack(Theme.panel))
local RAISED = Color3.fromRGB(table.unpack(Theme.raised))
local DANGER = Color3.fromRGB(table.unpack(Theme.danger))

local player = Players.LocalPlayer
local cameraController, viewmodel

local gui
local killCard, killerLabel, rankLabel, weaponLabel, healthLabel
local watchBar, watchLabel, watchHealth, previousButton, nextButton
local figure, figureFill, figureLabel

local state = "Alive" -- "Alive", "Killcam", "Teammate", "Killer" or "Body"
local life = 0 -- goes up at every spawn and every death, so late timers know they are stale
local ceremony = false -- the end-of-match podium has the camera
local match = nil -- the latest MatchUpdate
local diedAt = 0

local kill = nil -- { killer, weapon, headshot, health, at } as last reported
local eye = nil -- where the killcam looks from
local outline = nil -- the highlight on the killer

local watching = nil -- the name of the teammate whose eyes we are behind
local hidden = nil -- their character, hidden from us so we are not looking at the inside of a head
local shownWeapon = nil -- the weapon of theirs we are drawing
local pitch = 0 -- how far up or down we are showing them to be looking

local savedMin, savedMax

local function make(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in properties do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function text(properties, parent)
	local merged = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = PAPER,
		TextSize = SIZE.body,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in properties do
		merged[key] = value
	end
	return make("TextLabel", merged, parent)
end

local function humanoidOf(who)
	return who and who.Character and who.Character:FindFirstChildOfClass("Humanoid")
end

local function isAlive(who)
	local humanoid = humanoidOf(who)
	return humanoid ~= nil and humanoid.Health > 0
end

-- True if a dead player stays out until the round ends, rather than
-- respawning by themselves. Mirrors MatchService.respawns on the server.
local function isOut()
	return match ~= nil and match.mode == "SND" and match.phase ~= "Waiting"
end

-- Seconds until this player respawns, or nil if they are out.
local function respawnIn()
	return if isOut() then nil else diedAt + MatchConfig.respawnDelay - os.clock()
end

-- Cameras ---------------------------------------------------------------------

-- A camera we place ourselves, with the mouse left free for the buttons.
local function ownCamera()
	player.CameraMode = Enum.CameraMode.Classic
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
end

-- Roblox's own camera, a fixed distance from somebody. It already turns with
-- the mouse, a thumb or a stick.
local function follow(humanoid)
	local camera = workspace.CurrentCamera
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = BODY_DISTANCE
	player.CameraMaxZoomDistance = BODY_DISTANCE
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

-- Undoes the fixed distance that following somebody sets.
local function freeZoom()
	player.CameraMinZoomDistance = savedMin
	player.CameraMaxZoomDistance = savedMax
end

-- Back to the player's own eyes.
local function firstPerson()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoidOf(player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	freeZoom()
end

local function setHidden(character, value)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.LocalTransparencyModifier = if value then 1 else 0
		end
	end
end

-- Stops looking through a teammate's eyes. `keepWeapon` leaves the weapon
-- being drawn alone: on a respawn it is about to be replaced by our own, and
-- may already have been.
local function leaveTeammate(keepWeapon)
	if hidden then
		setHidden(hidden, false)
		hidden = nil
	end
	if shownWeapon and not keepWeapon then
		viewmodel.clear()
	end
	shownWeapon = nil
	watching = nil
end

local function leaveKillcam()
	killCard.Visible = false
	eye = nil
	if outline then
		outline:Destroy()
		outline = nil
	end
	cameraController.zoom(nil)
end

-- Killcam -------------------------------------------------------------------

local function headOf(who)
	return who and who.Character and who.Character:FindFirstChild("Head")
end

local function startKillcam(from)
	state = "Killcam"
	eye = from

	local config = WeaponConfig.Weapons[kill.weapon]
	killerLabel.Text = string.upper(kill.killer.DisplayName)
	local level = kill.killer:GetAttribute("Level")
	rankLabel.Text = if level then string.upper(Rank.of(ShopConfig.ranks, level).title) else "KILLED BY"
	weaponLabel.Text = string.upper(if config then config.displayName else kill.weapon)
		.. (if kill.headshot then "     HEADSHOT" else "")
	weaponLabel.TextColor3 = if kill.headshot then ACCENT else MUTED
	healthLabel.Text = string.format("%d HP LEFT", kill.health)
	healthLabel.TextColor3 = if kill.health <= 30 then DANGER else PAPER
	killCard.Visible = true

	-- Picks the killer out, but never through a wall. Made here, so no other
	-- player sees it.
	if kill.killer.Character then
		outline = make("Highlight", {
			FillTransparency = 1,
			OutlineColor = DANGER,
			DepthMode = Enum.HighlightDepthMode.Occluded,
			Adornee = kill.killer.Character,
		}, kill.killer.Character)
	end

	-- Start from where they were already looking, so the view swings round
	-- rather than jumping.
	local camera = workspace.CurrentCamera
	local rotation = camera.CFrame.Rotation
	ownCamera()
	camera.CFrame = CFrame.new(eye) * rotation
	cameraController.zoom(KILLCAM_FOV)
end

-- A teammate's eyes, or your own body ------------------------------------------

local function teammates()
	-- Teams only mean something once the match itself is being played.
	local teamsPlay = match ~= nil and match.mode ~= "FFA" and match.phase ~= "Waiting"
	local team = if teamsPlay and player.Team then player.Team.Name else nil
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(others, { name = other.Name, team = other.Team and other.Team.Name, alive = isAlive(other) })
		end
	end
	return Spectate.targets(team, others)
end

-- Your own body, from outside.
local function startBody()
	state = "Body"
	leaveKillcam()
	leaveTeammate()
	watchBar.Visible = false
	follow(humanoidOf(player))
end

-- Whoever killed you, from behind, until you are back.
local function startKiller()
	if not isAlive(kill.killer) then
		startBody() -- they did not outlive you by much
		return
	end
	state = "Killer"
	leaveKillcam()
	leaveTeammate()
	watchLabel.Text = "FOLLOWING   " .. string.upper(kill.killer.DisplayName)
	previousButton.Visible = false
	nextButton.Visible = false
	watchBar.Visible = true
	follow(humanoidOf(kill.killer))
end

local function watch(name)
	local target = name and Players:FindFirstChild(name)
	if not isAlive(target) then
		startBody()
		return
	end
	if watching ~= name then
		leaveTeammate()
		watching = name
		pitch = target:GetAttribute("AimPitch") or 0
	end
	watchLabel.Text = "WATCHING   " .. string.upper(target.DisplayName)
	local several = #teammates() > 1
	previousButton.Visible = several
	nextButton.Visible = several
end

local function startTeammate()
	state = "Teammate"
	leaveKillcam()
	freeZoom()
	ownCamera()
	watchBar.Visible = true
	watch(Spectate.step(teammates(), nil, 1))
end

local function step(direction)
	if state == "Teammate" then
		watch(Spectate.step(teammates(), watching, direction))
	end
end

-- The killcam is over, or was skipped. `killed` is whether anybody did it.
local function afterKillcam(skipped, killed)
	local view = Spectate.afterKillcam(isOut(), #teammates(), skipped, killed)
	if view == "Teammate" then
		startTeammate()
	elseif view == "Killer" then
		startKiller()
	elseif view == "Body" then
		startBody()
	end
end

local function skip()
	if state == "Killcam" then
		afterKillcam(true, true)
	end
end

-- Puts the camera where a teammate's eyes are, and draws what they hold.
local function throughEyes(target, dt)
	local character = target.Character
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not head or not root then
		return
	end
	if hidden ~= character then
		if hidden then
			setHidden(hidden, false)
		end
		hidden = character
	end
	setHidden(character, true) -- every frame: what they hold changes

	-- Which way they face is theirs; how far up or down comes from the server.
	local facing = root.CFrame.LookVector
	local yaw = math.atan2(-facing.X, -facing.Z)
	pitch += ((target:GetAttribute("AimPitch") or 0) - pitch) * math.min(dt * PITCH_EASE, 1)

	local camera = workspace.CurrentCamera
	local from = head.Position + Vector3.new(0, EYE_HEIGHT, 0)
	camera.CFrame = CFrame.new(from) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	camera.Focus = CFrame.new(from)

	local weapon = target:GetAttribute("Weapon")
	if weapon ~= shownWeapon then
		shownWeapon = weapon
		if weapon then
			viewmodel.equip(weapon, 0.15)
		else
			viewmodel.clear()
		end
	end
	watchHealth.Text = string.format("%d HP", math.ceil(humanoidOf(target).Health))
end

-- Life and death --------------------------------------------------------------

local function onDied(character)
	life += 1
	local thisLife = life
	diedAt = os.clock()
	if ceremony then
		return
	end
	local head = character:FindFirstChild("Head")
	local from = if head then head.Position else workspace.CurrentCamera.CFrame.Position

	task.spawn(function()
		-- The report of who did it and the death itself arrive separately.
		local function reported()
			return kill ~= nil and os.clock() - kill.at < KILL_NEWS_LASTS and kill.killer.Parent == Players
		end
		local waited = 0
		while not reported() and waited < KILL_NEWS_WAIT do
			waited += task.wait()
		end
		if life ~= thisLife or ceremony then
			return
		end
		if not reported() then
			afterKillcam(false, false) -- nobody killed them: there is nothing to show
			return
		end

		startKillcam(from)
		task.wait(KILLCAM_TIME)
		if life == thisLife and not ceremony and state == "Killcam" then
			afterKillcam(false, true)
		end
	end)
end

-- Alive again: a respawn, a new round or a revive.
local function onAlive()
	if state == "Alive" then
		return
	end
	life += 1
	kill = nil
	state = "Alive"
	leaveKillcam()
	leaveTeammate(true)
	watchBar.Visible = false
	if not ceremony then
		firstPerson()
	end
end

local function onCharacter(character)
	state = "Dead" -- so that onAlive runs whatever came before
	onAlive()
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Once(function()
			onDied(character)
		end)
	end
end

local function render(dt)
	local left = if state ~= "Alive" and not ceremony then respawnIn() else nil
	figure.Visible = left ~= nil
	if left then
		figureFill.Size = UDim2.fromScale(1, math.clamp(1 - left / MatchConfig.respawnDelay, 0, 1))
		figureLabel.Text = string.format("%.1f", math.max(left, 0))
	end

	if ceremony then
		return
	end
	if state == "Killcam" and eye then
		local camera = workspace.CurrentCamera
		local head = headOf(kill.killer)
		if head then
			local goal = CFrame.lookAt(eye, head.Position)
			camera.CFrame = camera.CFrame:Lerp(goal, math.min(dt * KILLCAM_TURN, 1))
		end
	elseif state == "Teammate" then
		local target = watching and Players:FindFirstChild(watching)
		if isAlive(target) then
			throughEyes(target, dt)
		else
			watch(Spectate.step(teammates(), watching, 1)) -- they fell too: on to the next, or to our own body
		end
	elseif state == "Killer" then
		if isAlive(kill.killer) then
			watchHealth.Text = string.format("%d HP", math.ceil(humanoidOf(kill.killer).Health))
		else
			startBody() -- somebody got them
		end
	end
end

-- So that a teammate watching through our eyes sees where we look.
local function reportAim()
	local sent = 0
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < AIM_EVERY or state ~= "Alive" or not isAlive(player) then
			return
		end
		since = 0
		local now = math.asin(math.clamp(workspace.CurrentCamera.CFrame.LookVector.Y, -1, 1))
		if math.abs(now - sent) > AIM_CHANGE then
			sent = now
			Remotes.Aim:FireServer(now)
		end
	end)
end

local function build()
	gui = make("ScreenGui", {
		Name = "Spectate",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 11,
	}, player:WaitForChild("PlayerGui"))
	Fit.attach(gui)

	-- Who killed you.
	killCard = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(400, 150),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	make("Frame", { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = DANGER, BorderSizePixel = 0 }, killCard)
	text({
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.fromOffset(100, 16),
		Text = "KILLED BY",
		TextSize = SIZE.small,
		TextColor3 = MUTED,
	}, killCard)
	rankLabel = text({ -- the killer's rank
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 16),
		Size = UDim2.fromOffset(240, 16),
		Text = "",
		TextSize = SIZE.small,
		TextColor3 = ACCENT,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, killCard)
	killerLabel = text({
		Position = UDim2.fromOffset(20, 34),
		Size = UDim2.new(1, -40, 0, 28),
		Font = DISPLAY,
		Text = "",
		TextSize = SIZE.heading,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, killCard)
	weaponLabel = text({
		Position = UDim2.fromOffset(20, 70),
		Size = UDim2.new(1, -170, 0, 20),
		Font = BOLD,
		Text = "",
		TextSize = SIZE.small,
	}, killCard)
	healthLabel = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 70),
		Size = UDim2.fromOffset(130, 20),
		Font = BOLD,
		Text = "",
		TextSize = SIZE.small,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, killCard)
	local skipButton = make("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -12),
		Size = UDim2.fromOffset(150, 40), -- big enough for a thumb
		BackgroundColor3 = RAISED,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = BOLD,
		Text = "SKIP   [SPACE]",
		TextSize = SIZE.small,
		TextColor3 = PAPER,
	}, killCard)
	skipButton.MouseButton1Click:Connect(skip)

	-- Whose eyes you are behind.
	watchBar = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(460, 48),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	local function arrow(symbol, anchor, direction)
		local button = make("TextButton", {
			AnchorPoint = Vector2.new(anchor, 0),
			Position = UDim2.fromScale(anchor, 0),
			Size = UDim2.fromOffset(48, 48),
			BackgroundColor3 = RAISED,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = BOLD,
			Text = symbol,
			TextSize = SIZE.heading,
			TextColor3 = PAPER,
		}, watchBar)
		button.MouseButton1Click:Connect(function()
			step(direction)
		end)
		return button
	end
	previousButton = arrow("<", 0, -1)
	nextButton = arrow(">", 1, 1)
	watchLabel = text({
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(1, -220, 1, 0),
		Font = BOLD,
		Text = "",
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, watchBar)
	watchHealth = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -64, 0, 0),
		Size = UDim2.fromOffset(90, 48),
		Font = BOLD,
		Text = "",
		TextColor3 = ACCENT,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, watchBar)

	-- How soon you are back: a figure that fills from the feet up. The bright
	-- one sits in a window that grows from the bottom, over a dim one.
	local size = PixelArt.size(Icons.Body, FIGURE_CELL)
	figure = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -300, 1, -52),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	PixelArt.draw(figure, Icons.Body, FIGURE_CELL, RAISED)
	figureFill = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, figure)
	local bright = PixelArt.draw(figureFill, Icons.Body, FIGURE_CELL, ACCENT)
	bright.AnchorPoint = Vector2.new(0, 1)
	bright.Position = UDim2.fromScale(0, 1)
	figureLabel = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(80, 20),
		Font = BOLD,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
	}, figure)
end

-- `deps` is { camera = CameraController, viewmodel = ViewmodelController }.
function SpectateController.start(deps)
	cameraController = deps.camera
	viewmodel = deps.viewmodel
	savedMin, savedMax = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
	build()
	reportAim()

	Remotes.Killcam.OnClientEvent:Connect(function(killer, weapon, headshot, health)
		if typeof(killer) == "Instance" and killer:IsA("Player") then
			kill = { killer = killer, weapon = weapon, headshot = headshot == true, health = health, at = os.clock() }
		end
	end)
	Remotes.MatchUpdate.OnClientEvent:Connect(function(snapshot)
		match = snapshot
	end)
	-- A fresh loadout is the server saying we are alive again. It and the new
	-- character arrive in either order, and both are listened for.
	Remotes.LoadoutUpdate.OnClientEvent:Connect(function(payload)
		if payload.reset then
			onAlive()
		end
	end)
	-- The podium takes the camera for itself, and hands it back when it is done.
	Remotes.Podium.OnClientEvent:Connect(function(update)
		ceremony = update ~= nil
		if ceremony then
			leaveKillcam()
			leaveTeammate()
			watchBar.Visible = false
			freeZoom()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if UserInputService:GetFocusedTextBox() then
			return
		elseif SKIP[input.KeyCode] then
			skip() -- even if the jump it is usually bound to took it
		elseif processed then
			return
		elseif PREVIOUS[input.KeyCode] then
			step(-1)
		elseif NEXT[input.KeyCode] then
			step(1)
		end
	end)

	-- After the recoil step, which eases the field of view, and before the
	-- viewmodel, which is drawn where the camera ends up.
	RunService:BindToRenderStep("Spectate", Enum.RenderPriority.Camera.Value + 2, render)

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	else
		-- Someone sent into a Search and Destroy round already under way is not
		-- spawned until the next one. Until then they watch, like the dead.
		task.delay(JOIN_WAIT, function()
			if not player.Character and state == "Alive" and isOut() and not ceremony then
				diedAt = os.clock()
				startTeammate()
			end
		end)
	end
end

return SpectateController
