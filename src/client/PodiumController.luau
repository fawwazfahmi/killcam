-- The ceremony on the client: the camera cuts to the stage and each of the top
-- three gets a label, with the MVP's picked out. The stage and the poses are
-- the server's (see PodiumService); this only looks at them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Score = require(Shared.Logic.Score)
local Remotes = require(Shared.Remotes)

local PodiumController = {}

local DISPLAY = Enum.Font[Theme.display]
local FONT = Enum.Font[Theme.body]
local SIZE = Theme.size
local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local WHITE = Color3.new(1, 1, 1)
local PLACE_NAMES = { "1ST", "2ND", "3RD" }
local LABEL_HEIGHT = 7 -- studs above where the player stands

local player = Players.LocalPlayer
local gui
local labels = {}
local ceremony = nil
local spin = 0

local function make(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in properties do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

-- One floating label above a player on the stage.
local function label(entry)
	local anchor = make("Part", {
		Name = "PodiumLabel",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		Position = entry.position + Vector3.new(0, LABEL_HEIGHT, 0),
	}, workspace)

	local billboard = make("BillboardGui", {
		Size = UDim2.fromOffset(if entry.mvp then 320 else 240, if entry.mvp then 76 else 58),
		AlwaysOnTop = true,
		Adornee = anchor,
	}, anchor)

	make("TextLabel", {
		Size = UDim2.new(1, 0, 0.45, 0),
		BackgroundTransparency = 1,
		Font = DISPLAY,
		Text = if entry.mvp then PLACE_NAMES[entry.place] .. "   -   MVP" else PLACE_NAMES[entry.place],
		TextScaled = true,
		TextColor3 = if entry.mvp then ACCENT else WHITE,
		TextStrokeTransparency = 0.3,
	}, billboard)
	make("TextLabel", {
		Position = UDim2.fromScale(0, 0.45),
		Size = UDim2.new(1, 0, 0.55, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = string.format("%s   %s", string.upper(entry.name), Score.summary(entry)),
		TextScaled = true,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.3,
	}, billboard)

	return anchor
end

-- A gold outline on the MVP, so they are the one the eye goes to.
local function highlight(entry)
	local other = Players:FindFirstChild(entry.name)
	local character = other and other.Character
	if not character then
		return nil
	end
	return make("Highlight", {
		Name = "MvpHighlight",
		FillColor = ACCENT,
		FillTransparency = 0.75,
		OutlineColor = ACCENT,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Adornee = character,
	}, character)
end

local function stop()
	ceremony = nil
	for _, instance in labels do
		instance:Destroy()
	end
	table.clear(labels)
	gui.Enabled = false

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	player.CameraMode = Enum.CameraMode.LockFirstPerson
end

local function start(update)
	stop()
	ceremony = update
	spin = 0

	-- Third person, so the player can see the stage.
	player.CameraMode = Enum.CameraMode.Classic
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	for _, entry in update.entries do
		table.insert(labels, label(entry))
		if entry.mvp then
			local outline = highlight(entry)
			if outline then
				table.insert(labels, outline)
			end
		end
	end

	gui.Enabled = true
	gui.Title.Text = if #update.entries > 0 then "MATCH OVER" else ""
end

-- The camera drifts slowly around the stage while the ceremony runs.
local function step(dt)
	if not ceremony then
		return
	end
	spin += dt * 0.12
	local offset = ceremony.camera - ceremony.look
	local turned = CFrame.Angles(0, spin, 0) * offset
	workspace.CurrentCamera.CFrame = CFrame.lookAt(ceremony.look + turned, ceremony.look + Vector3.new(0, 3, 0))
end

function PodiumController.start()
	gui = make("ScreenGui", {
		Name = "Podium",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	make("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(600, 40),
		BackgroundTransparency = 1,
		Font = DISPLAY,
		Text = "",
		TextSize = SIZE.title,
		TextColor3 = ACCENT,
		TextStrokeTransparency = 0.4,
	}, gui)

	Remotes.Podium.OnClientEvent:Connect(function(update)
		if update then
			start(update)
		else
			stop()
		end
	end)

	RunService:BindToRenderStep("TdmPodium", Enum.RenderPriority.Camera.Value + 4, step)
end

return PodiumController
