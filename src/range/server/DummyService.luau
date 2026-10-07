-- The test range's dummies: figures the size of a player that stand where the
-- layout puts them, or where an admin places one. Each can be told to die or
-- not, wear a helmet and body armour, walk from side to side, crouch, and
-- shoot back. What a dummy can be set to, and what a hit does to it, is in
-- Shared.Logic.Dummy.
--
-- A dummy is hit by the same code as a player: it is registered with
-- CombatService as a target (see CombatService.setTargets), so a shot at one
-- passes the same checks and its armour is added up by the same function.
-- Every hit is reported in full to whoever landed it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmorConfig = require(Shared.Config.ArmorConfig)
local MatchConfig = require(Shared.Config.MatchConfig)
local MovementConfig = require(Shared.Config.MovementConfig)
local RangeConfig = require(Shared.Config.RangeConfig)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Damage = require(Shared.Logic.Damage)
local Dummy = require(Shared.Logic.Dummy)
local Loadout = require(Shared.Logic.Loadout)
local WeaponModels = require(Shared.WeaponModels)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
local Harm = require(script.Parent.Harm)
local LoadoutService = require(script.Parent.LoadoutService)

local DummyService = {}

local RULES = RangeConfig.dummy
local FULL = MatchConfig.maxHealth
local ARRIVED = 1.5 -- studs from the end of its walk at which a dummy turns back
local TURN_SLACK = 1.5 -- seconds longer than a walk should take before a dummy gives up on it

local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local PAPER = Color3.fromRGB(table.unpack(Theme.paper))
local MUTED = Color3.fromRGB(table.unpack(Theme.muted))
local SUNKEN = Color3.fromRGB(table.unpack(Theme.sunken))

-- A dummy is painted by damage zone, so what was hit can be seen from the lane.
local ZONE_COLORS = {
	Head = Color3.fromRGB(table.unpack(Theme.danger)),
	UpperTorso = ACCENT,
	LowerTorso = Color3.fromRGB(204, 140, 24),
	Limb = Color3.fromRGB(150, 154, 164),
}

local folder = nil -- Workspace.Dummies
local template = nil -- the figure every dummy is a copy of
local hipHeight = 0 -- a standing dummy's
local standHeight = 0 -- studs from the ground to the middle of a standing dummy's root

local dummies = {} -- [id] = dummy
local order = {} -- every dummy, in the order they were made
local byModel = {} -- [Model] = dummy
local lastId = 0
local placedCount = 0 -- how many have ever been placed, for naming the next

local changed = Instance.new("BindableEvent")
-- Fires when a dummy is added, removed or set differently.
DummyService.Changed = changed.Event

-- The figure: a plain R15 character, which is what a player is.
local function buildTemplate()
	local model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	assert(humanoid and root and model:FindFirstChild("Head"), "the figure Roblox built is not a whole character")
	model.Name = "Dummy"
	model.PrimaryPart = root

	-- A character's scripts are for a player, and its BodyColors would repaint it.
	local unwanted = {}
	for _, child in model:GetDescendants() do
		if child:IsA("LuaSourceContainer") or child:IsA("BodyColors") then
			table.insert(unwanted, child)
		end
	end
	for _, child in unwanted do
		child:Destroy()
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= root then
			part.Color = ZONE_COLORS[Damage.zoneForPart(part.Name)]
			part.Material = Enum.Material.SmoothPlastic
		end
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = FULL
	humanoid.Health = FULL
	humanoid.AutoRotate = false -- a dummy walking sideways keeps facing the way it was put
	hipHeight = humanoid.HipHeight
	standHeight = hipHeight + root.Size.Y / 2
	return model
end

local function line(properties, parent)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font[Theme.bodyBold]
	label.TextSize = Theme.size.small
	label.TextColor3 = PAPER
	label.TextStrokeTransparency = 0.4
	for key, value in properties do
		label[key] = value
	end
	label.Parent = parent
	return label
end

-- What floats over a dummy: its name, its health and what it is wearing.
local function addTag(dummy)
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Adornee = dummy.model:FindFirstChild("Head")
	tag.Size = UDim2.fromOffset(170, 48)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.MaxDistance = 2000

	line({ Size = UDim2.new(1, 0, 0, 16), Text = dummy.label }, tag)
	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0.15, 0, 0, 20)
	bar.Size = UDim2.new(0.7, 0, 0, 6)
	bar.BackgroundColor3 = SUNKEN
	bar.BorderSizePixel = 0
	bar.Parent = tag
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	fill.Parent = bar
	dummy.wearing = line({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 16), TextColor3 = MUTED }, tag)

	dummy.humanoid.HealthChanged:Connect(function(health)
		fill.Size = UDim2.fromScale(math.clamp(health / FULL, 0, 1), 1)
	end)
	tag.Parent = dummy.model
end

local function pieceName(slot, key)
	local piece = ArmorConfig[slot][key]
	return string.upper(if piece then piece.displayName else "Bare")
end

-- Makes the dummy in the world match its settings.
local function apply(dummy)
	local settings, humanoid, root = dummy.settings, dummy.humanoid, dummy.root
	dummy.stats = Loadout.stats(ArmorConfig, { helmet = settings.helmet, body = settings.body })

	-- Crouching lowers the whole body, as it does a player's.
	local drop = if settings.crouched then MovementConfig.crouchHipDrop else 0
	if settings.moves then
		root.Anchored = false
		pcall(root.SetNetworkOwner, root, nil) -- the server walks it, not whoever stands nearest
		humanoid.HipHeight = hipHeight - drop
		humanoid.WalkSpeed = if settings.crouched then MovementConfig.crouchSpeed else MovementConfig.runSpeed
	else
		root.Anchored = true
		humanoid.HipHeight = hipHeight
		dummy.model:PivotTo(dummy.post * CFrame.new(0, standHeight - drop, 0))
		dummy.goal = nil
	end

	local config = WeaponConfig.Weapons[settings.weapon]
	local held = if config then config.model else nil
	if held ~= dummy.held then
		dummy.held = held
		dummy.gun = if config then Dummy.newGun(config) else nil
		WeaponModels.hold(dummy.model, held)
		-- What a shot from it sounds like to a player (see Sounds on the client).
		dummy.model:SetAttribute("Weapon", held)
	end

	dummy.wearing.Text = pieceName("helmet", settings.helmet) .. "  /  " .. pieceName("body", settings.body)
end

-- Stands the dummy at its post, whole and at full health.
local function stand(dummy)
	if dummy.model then
		byModel[dummy.model] = nil
		dummy.model:Destroy()
	end
	local model = template:Clone()
	model:SetAttribute("Dummy", dummy.id) -- how a client knows a shot at it is worth reporting
	dummy.model = model
	dummy.humanoid = model:FindFirstChildOfClass("Humanoid")
	dummy.root = model.PrimaryPart
	dummy.held = nil
	dummy.gun = nil
	dummy.goal = nil
	dummy.side = 1
	dummy.blows += 1
	byModel[model] = dummy

	addTag(dummy)
	dummy.root.Anchored = true
	model:PivotTo(dummy.post * CFrame.new(0, standHeight, 0))
	model.Parent = folder
	apply(dummy)
end

-- A hit that has passed every check (see CombatService).
local function hit(dummy, attacker, weaponName, amount, detail)
	local humanoid = dummy.humanoid
	local result = Dummy.strike(dummy.settings, humanoid.Health, FULL, amount)
	humanoid.Health = result.left
	dummy.blows += 1
	local blow = dummy.blows

	Remotes.HitConfirm:FireClient(attacker, detail.headshot, result.lethal)
	Remotes.RangeHit:FireClient(attacker, {
		target = dummy.id,
		label = dummy.label,
		weapon = weaponName,
		zone = detail.zone,
		raw = detail.raw,
		amount = amount,
		left = result.left,
		lethal = result.lethal,
		distance = detail.distance,
		at = detail.at,
	})

	if result.died then
		Remotes.KillFeed:FireAllClients(attacker.Name, dummy.label, weaponName, detail.headshot)
		task.delay(RULES.respawnAfter, function()
			if dummies[dummy.id] == dummy and dummy.blows == blow then
				stand(dummy)
			end
		end)
	elseif not result.lethal then
		-- Left alone for a while, it is back to full health.
		task.delay(RULES.healAfter, function()
			if dummies[dummy.id] == dummy and dummy.blows == blow then
				humanoid.Health = FULL
			end
		end)
	end
end

local function add(label, post, placed)
	lastId += 1
	local dummy = {
		id = lastId,
		label = label,
		post = post, -- where its feet go, and the way it faces
		placed = placed,
		settings = Dummy.defaults(ArmorConfig, RangeConfig),
		blows = 0, -- goes up at every hit and every time it is stood up, so that late timers know they are stale
	}
	-- What CombatService needs of a target.
	dummy.alive = function()
		return dummy.humanoid.Health > 0
	end
	dummy.hit = function(attacker, weaponName, amount, detail)
		hit(dummy, attacker, weaponName, amount, detail)
	end
	dummies[dummy.id] = dummy
	table.insert(order, dummy)
	stand(dummy)
	return dummy
end

local function take(dummy)
	dummies[dummy.id] = nil
	table.remove(order, table.find(order, dummy))
	byModel[dummy.model] = nil
	dummy.model:Destroy()
end

-- Walking from side to side: to one end of its walk, then back to the other.
local function walk(dummy, now)
	local speed = dummy.humanoid.WalkSpeed
	local arrived = dummy.goal ~= nil
		and ((dummy.root.Position - dummy.goal) * Vector3.new(1, 0, 1)).Magnitude < ARRIVED
	if dummy.goal and not arrived and now < dummy.turnAt then
		return
	end
	dummy.side = -dummy.side
	-- It turns a little short of where it is heading, so it heads that much further.
	dummy.goal = dummy.post.Position + dummy.post.RightVector * ((RULES.strafe + ARRIVED) * dummy.side)
	dummy.turnAt = now + 2 * (RULES.strafe + ARRIVED) / speed + TURN_SLACK
	dummy.humanoid:MoveTo(dummy.goal)
end

-- The nearest living player the dummy's gun reaches with nothing in the way,
-- and the part of them it is aiming for.
local function findVictim(dummy, config, from)
	local wanted = Dummy.aimPart(RangeConfig, dummy.settings.aim)
	local victim, aimed, nearest = nil, nil, config.range
	for _, player in Players:GetPlayers() do
		local character, _, root = CombatService.bodyOf(player)
		if character then
			local part = character:FindFirstChild(wanted) or root
			local distance = (part.Position - from).Magnitude
			if distance <= nearest and not CombatService.blocked(from, part.Position) then
				victim, aimed, nearest = player, part, distance
			end
		end
	end
	return victim, aimed, nearest
end

-- Shooting back. A dummy does not miss: it hits what it was told to aim at,
-- as fast as its gun fires, so what its victim takes is the same every time.
local function shoot(dummy, now)
	local config = WeaponConfig.Weapons[dummy.settings.weapon]
	local head = dummy.model:FindFirstChild("Head")
	if not config or not dummy.gun or not head then
		return
	end
	local victim, part, distance = findVictim(dummy, config, head.Position)
	if not victim then
		return
	end

	local at = dummy.root.Position
	local level = Vector3.new(part.Position.X, at.Y, part.Position.Z)
	if (level - at).Magnitude > 0.5 then
		dummy.root.CFrame = CFrame.lookAt(at, level)
	end

	if not Dummy.pull(config, dummy.gun, now) then
		return
	end
	Remotes.ShotFired:FireAllClients(dummy.model, head.Position, part.Position)
	local zone = Damage.zoneForPart(part.Name)
	local raw = Damage.gun(config, zone)
	local amount = Loadout.damage(LoadoutService.get(victim).stats, config.class, zone, raw)
	Harm.deal(victim, amount, head.Position, dummy.label, dummy.settings.weapon, {
		zone = zone,
		raw = raw,
		headshot = zone == "Head",
		distance = distance,
	})
end

local function step()
	local now = os.clock()
	for _, dummy in order do
		if dummy.humanoid.Health > 0 then
			if dummy.settings.moves then
				walk(dummy, now)
			end
			if dummy.gun then
				shoot(dummy, now)
			end
		end
	end
end

-- Every dummy and how it is set, for the admin panel.
function DummyService.list()
	local list = {}
	for _, dummy in order do
		table.insert(list, { id = dummy.id, label = dummy.label, placed = dummy.placed, settings = dummy.settings })
	end
	return list
end

-- Sets one thing on one dummy, or with `target` "all" on every one. `field`
-- and `value` come from a client. Returns whether anything was set.
function DummyService.set(target, field, value)
	local some = false
	for _, dummy in if target == "all" then table.clone(order) else { dummies[target] } do
		local settings = Dummy.changed(WeaponConfig, ArmorConfig, RangeConfig, dummy.settings, field, value)
		if settings then
			dummy.settings = settings
			if dummy.humanoid.Health > 0 then
				apply(dummy)
			end
			some = true
		end
	end
	if some then
		changed:Fire()
	end
	return some
end

-- Stands a new dummy on the ground under `position`, facing `player`.
function DummyService.place(player, position)
	local map = workspace:FindFirstChild("Map")
	local geometry = map and map:FindFirstChild("Geometry")
	local bounds = map and map:FindFirstChild("Bounds")
	local _, _, root = CombatService.bodyOf(player)
	if not template or not geometry or not bounds or not root then
		return nil
	end

	local placed = 0
	for _, dummy in order do
		placed += if dummy.placed then 1 else 0
	end
	local offset = bounds.CFrame:PointToObjectSpace(position)
	local half = bounds.Size / 2
	local outside = math.abs(offset.X) > half.X or math.abs(offset.Y) > half.Y or math.abs(offset.Z) > half.Z
	if placed >= RULES.most or outside or (position - root.Position).Magnitude > RULES.reach then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { geometry }
	local ground = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -80, 0), params)
	if not ground then
		return nil
	end

	local feet = ground.Position
	local toward = Vector3.new(root.Position.X, feet.Y, root.Position.Z)
	local post = if (toward - feet).Magnitude > 0.5 then CFrame.lookAt(feet, toward) else CFrame.new(feet)
	placedCount += 1
	local dummy = add("PLACED " .. placedCount, post, true)
	changed:Fire()
	return dummy
end

-- Takes away a dummy an admin placed. The layout's own stay.
function DummyService.remove(id)
	local dummy = dummies[id]
	if dummy and dummy.placed then
		take(dummy)
		changed:Fire()
	end
end

function DummyService.removePlaced()
	for _, dummy in table.clone(order) do
		if dummy.placed then
			take(dummy)
		end
	end
	changed:Fire()
end

-- Every dummy back on its feet at its post, at full health.
function DummyService.standAll()
	for _, dummy in order do
		stand(dummy)
	end
end

-- Builds the figure and stands one at each place the layout lists. Yields
-- while Roblox builds the figure.
function DummyService.init(layout)
	folder = Instance.new("Folder")
	folder.Name = "Dummies"
	folder.Parent = workspace

	local ok, built = pcall(buildTemplate)
	if not ok then
		warn(`DummyService: could not build a dummy, so the range has none: {built}`)
		return
	end
	template = built

	for _, place in layout.dummies do
		local post = CFrame.new(place.pos[1], 0, place.pos[2]) * CFrame.Angles(0, math.rad(place.yaw), 0)
		add(place.label, post, false)
	end

	CombatService.setTargets({
		find = function(part)
			local dummy = byModel[part.Parent]
			return if dummy and part ~= dummy.root then dummy else nil
		end,
		all = function()
			return order
		end,
	})
	RunService.Heartbeat:Connect(step)
	changed:Fire()
end

return DummyService
