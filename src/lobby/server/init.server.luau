-- The lobby place. Builds the Penthouse, runs the stations' server side
-- (loadout, shop, profile), and queues players for matches.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmorConfig = require(Shared.Config.ArmorConfig)
local ShopConfig = require(Shared.Config.ShopConfig)
local TacticalConfig = require(Shared.Config.TacticalConfig)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Economy = require(Shared.Logic.Economy)
local Loadout = require(Shared.Logic.Loadout)
local Remotes = require(Shared.Remotes) -- creates the remotes before any client asks
local WeaponModels = require(Shared.WeaponModels)

local MapBuilder = require(script.MapBuilder)
local ProfileStore = require(script.ProfileStore)
local PurchaseService = require(script.PurchaseService)
local QueueService = require(script.QueueService)
local SquadService = require(script.SquadService)

local layout = require(script.Penthouse)
local DEFAULTS = Loadout.default(WeaponConfig, TacticalConfig, ArmorConfig)
local SWEEP_EVERY = 20 -- seconds between looks for rentals that have run out

MapBuilder.build(layout)

-- Where players appear.
local arrival = Instance.new("SpawnLocation")
arrival.Name = "Arrival"
arrival.Anchored = true
arrival.CanCollide = false
arrival.Transparency = 1
arrival.Neutral = true
arrival.Duration = 0
arrival.Size = Vector3.new(8, 1, 8)
arrival.CFrame = CFrame.new(layout.arrival[1], layout.arrival[2], layout.arrival[3]) * CFrame.Angles(0, math.rad(-90), 0)
arrival.Parent = workspace

local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local STEEL = Color3.fromRGB(34, 36, 42)
local SCREEN = Color3.fromRGB(14, 15, 20)
local SCREEN_TILT = 18 -- degrees the screen leans back, to face whoever stands at it
local PIXELS_PER_STUD = 40

local function block(name, size, cframe, colour, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = material
	part.Parent = parent
	return part
end

local function label(properties, parent)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	for key, value in properties do
		text[key] = value
	end
	text.Parent = parent
	return text
end

-- A station is a kiosk to walk up to: a plinth, a post, and a screen leaning
-- back to face you, with a line of light on the floor where you stand. The
-- prompt's name tells the client which panel to open. A station faces its
-- own -Z.
local stations = Instance.new("Folder")
stations.Name = "Stations"
for _, station in layout.stations do
	local base = CFrame.new(station.pos[1], 0, station.pos[2]) * CFrame.Angles(0, math.rad(station.facing), 0)
	local kiosk = Instance.new("Model")
	kiosk.Name = station.name

	block("Plinth", Vector3.new(5.6, 0.4, 2.4), base * CFrame.new(0, 0.2, 0.2), STEEL, Enum.Material.Metal, kiosk)
	block("Post", Vector3.new(1.4, 2.8, 0.7), base * CFrame.new(0, 1.8, 0.5), STEEL, Enum.Material.Metal, kiosk)
	local screen = block(
		"Screen",
		Vector3.new(5.2, 2.6, 0.3),
		base * CFrame.new(0, 3.9, 0.2) * CFrame.Angles(math.rad(SCREEN_TILT), 0, 0),
		SCREEN,
		Enum.Material.SmoothPlastic,
		kiosk
	)
	for name, cframe in
		{
			Edge = screen.CFrame * CFrame.new(0, -1.37, -0.02),
			FloorLine = base * CFrame.new(0, 0.06, -2.6),
		}
	do
		local glow = block(name, Vector3.new(5.2, 0.12, 0.34), cframe, ACCENT, Enum.Material.Neon, kiosk)
		glow.CanCollide = false
	end

	-- What the station is, on its screen.
	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Front
	face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	face.PixelsPerStud = PIXELS_PER_STUD
	face.LightInfluence = 0 -- a screen lights itself
	face.Parent = screen
	label({
		Position = UDim2.fromOffset(12, 14),
		Size = UDim2.new(1, -24, 0, 30),
		Font = Enum.Font[Theme.display],
		Text = station.title,
		TextSize = 19,
		TextColor3 = ACCENT,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, face)
	label({
		Position = UDim2.fromOffset(12, 50),
		Size = UDim2.new(1, -24, 0, 20),
		Font = Enum.Font[Theme.body],
		Text = station.action,
		TextSize = Theme.size.body,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, face)
	label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 0,
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
		Font = Enum.Font[Theme.bodyBold],
		Text = "E",
		TextSize = Theme.size.body,
		TextColor3 = Color3.fromRGB(table.unpack(Theme.ink)),
	}, face)

	-- And over it, for finding the station from across the room.
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(260, 30)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	sign.MaxDistance = 90
	sign.Parent = screen
	label({
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font[Theme.display],
		Text = station.title,
		TextSize = Theme.size.label,
		TextColor3 = ACCENT,
		TextStrokeTransparency = 0.4,
	}, sign)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = station.name
	prompt.ObjectText = station.title
	prompt.ActionText = station.action
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = screen

	kiosk.Parent = stations
end
stations.Parent = workspace

-- The armoury racks carry the game's weapons, one on each mount, lying along
-- the wall. They are for looking at: nothing collides with them.
local DISPLAY_SCALE = 1.4
local onShow, seen = {}, {}
for _, order in { WeaponConfig.PrimaryOrder, WeaponConfig.SecondaryOrder, WeaponConfig.MeleeOrder, WeaponConfig.NadeOrder } do
	for _, name in order do
		local model = WeaponConfig.Weapons[name].model
		if not seen[model] then
			seen[model] = true
			table.insert(onShow, model)
		end
	end
end
local rack = Instance.new("Folder")
rack.Name = "Displays"
for index, mount in layout.displays do
	local model = WeaponModels.build(onShow[(index - 1) % #onShow + 1])
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	model:ScaleTo(DISPLAY_SCALE)
	model:PivotTo(CFrame.new(mount[1], mount[2], mount[3]) * CFrame.Angles(0, math.rad(90), 0))
	model.Parent = rack
end
rack.Parent = workspace

-- A small per-player limit on how often a remote may be used.
local lastUse = {}
local function allow(player, key, interval)
	local forPlayer = lastUse[player]
	if not forPlayer then
		forPlayer = {}
		lastUse[player] = forPlayer
	end
	local now = os.clock()
	if now - (forPlayer[key] or 0) < interval then
		return false
	end
	forPlayer[key] = now
	return true
end

-- The loadout saved in a profile. Anything in it that has since run out is
-- swapped for the free option, and the rest is kept.
local function loadoutOf(profile)
	local saved = Loadout.sanitize(WeaponConfig, TacticalConfig, ArmorConfig, profile.loadout)
	if not saved then
		return table.clone(DEFAULTS)
	end
	return Economy.fallback(ShopConfig, profile, saved, DEFAULTS, os.time())
end

-- The loadout menu listens for this to learn what is currently picked.
local function sendLoadout(player)
	local profile = ProfileStore.get(player)
	if profile then
		profile.loadout = loadoutOf(profile)
		Remotes.LoadoutUpdate:FireClient(player, { choice = profile.loadout })
	end
end

ProfileStore.Loaded:Connect(sendLoadout)

Remotes.SelectLoadout.OnServerEvent:Connect(function(player, choice)
	if not allow(player, "SelectLoadout", 0.1) then
		return
	end
	local profile = ProfileStore.get(player)
	local clean = Loadout.sanitize(WeaponConfig, TacticalConfig, ArmorConfig, choice)
	if profile and clean and Economy.ownsAll(ShopConfig, profile, clean, os.time()) then
		profile.loadout = clean -- saved when they leave or are sent to a match
	end
	sendLoadout(player) -- always answer, so a refused pick snaps back
end)

Remotes.BuyRental.OnServerEvent:Connect(function(player, field, option, amount)
	if allow(player, "BuyRental", 0.25) then
		ProfileStore.buy(player, field, option, amount)
	end
end)

-- The player has closed the notice telling them what ran out.
Remotes.AckExpired.OnServerEvent:Connect(function(player)
	if allow(player, "AckExpired", 0.5) then
		ProfileStore.acknowledge(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastUse[player] = nil
end)

-- Nobody should be able to leave the floor (see the layout's barriers). If
-- someone finds a way, they are put back where they arrived rather than left
-- to fall through the city.
local FALLEN_BELOW = -12
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and root.Position.Y < FALLEN_BELOW then
				root.AssemblyLinearVelocity = Vector3.zero
				player.Character:PivotTo(arrival.CFrame + Vector3.new(0, 3, 0))
			end
		end
	end
end)

-- A rental can run out while its owner is standing here.
task.spawn(function()
	while true do
		task.wait(SWEEP_EVERY)
		for _, player in ProfileStore.sweep() do
			sendLoadout(player)
		end
	end
end)

ProfileStore.init()
PurchaseService.init() -- the shop's premium rentals are paid for in Robux
SquadService.init()
QueueService.init(ProfileStore, SquadService)
