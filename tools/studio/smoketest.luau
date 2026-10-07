-- Runs inside Roblox Studio, against any of the three built places, through
-- run-in-roblox (see the README). The unit tests cover the rules; this covers
-- what only Roblox can answer: do the fonts, materials and properties this
-- project asks for exist, does every module load, and does every map build.
--
-- It runs in edit mode, so it cannot play the game: spawning, shooting and
-- the match loop still have to be tried by hand.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local passed, failed = 0, 0

local function check(name, body)
	local ok, problem = pcall(body)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name)
		print("      " .. tostring(problem))
	end
end

local function expect(condition, message)
	if not condition then
		error(message, 2)
	end
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
-- The match place keeps its code under Server, the lobby under Lobby and the
-- test range under Range.
local Server = ServerScriptService:FindFirstChild("Server")
local Lobby = ServerScriptService:FindFirstChild("Lobby")
local Range = ServerScriptService:FindFirstChild("Range")
local code = Server or Lobby or Range
expect(code ~= nil, "no place's server code is here")
local place = if Server then "match" elseif Lobby then "lobby" else "range"

print(`=== studio smoke test: the {place} place`)

local Theme = require(Shared.Config.Theme)
local MapBuilder = require(code:FindFirstChild("MapBuilder", true))

-- 1. The font the HUD and every sign is drawn in.
for _, face in { "display", "body", "bodyBold" } do
	check(`the {face} font exists`, function()
		expect(Enum.Font[Theme[face]] ~= nil, `Enum.Font.{Theme[face]} does not exist`)
	end)
end
check("nothing in the type scale is too small to read", function()
	for name, size in Theme.size do
		expect(size >= 13, `{name} is {size}px`)
	end
end)

-- 1b. Every key and button the controls name is a real one.
check("every control names a real key, button or mouse button", function()
	local ControlsConfig = require(Shared.Config.ControlsConfig)
	for name, action in ControlsConfig.actions do
		for _, key in action.keys do
			expect(Enum.KeyCode[key] ~= nil, `{name}: no key called {key}`)
		end
		for _, button in action.pad do
			expect(Enum.KeyCode[button] ~= nil, `{name}: no controller button called {button}`)
		end
		if action.mouse then
			expect(Enum.UserInputType[action.mouse] ~= nil, `{name}: no mouse button called {action.mouse}`)
		end
	end
end)

-- 1c. Every sound that is not left silent loads as a Sound.
check("every sound has an id Roblox accepts", function()
	local SoundConfig = require(Shared.Config.SoundConfig)
	for name, entry in SoundConfig.sounds do
		if entry.id ~= "" then
			local sound = Instance.new("Sound")
			local ok, problem = pcall(function()
				sound.SoundId = entry.id
				sound.Volume = entry.volume
				sound.PlaybackSpeed = entry.speed
			end)
			sound:Destroy()
			expect(ok, `{name}: {problem}`)
		end
	end
end)

-- 2. Every module loads. This runs each one's top-level code, which is where
--    a bad service name or a missing sibling would bite on the first run.
local function loadAll(root, label)
	for _, module in root:GetDescendants() do
		if module:IsA("ModuleScript") then
			check(`{label}.{module.Name} loads`, function()
				require(module)
			end)
		end
	end
end
loadAll(Shared, "Shared")
loadAll(code, if Server then "Server" elseif Lobby then "Lobby" else "Range")
if ServerStorage:FindFirstChild("Tools") then
	loadAll(ServerStorage.Tools, "Tools")
end

-- 3. Every material named anywhere in the project.
local function materialsIn(name, source)
	for key, entry in source do
		if type(entry) == "table" and type(entry.material) == "string" then
			check(`material {entry.material} ({name}.{key})`, function()
				expect(Enum.Material[entry.material] ~= nil, `Enum.Material.{entry.material} does not exist`)
			end)
		end
	end
end
if ServerStorage:FindFirstChild("Tools") then
	materialsIn("Palette", require(ServerStorage.Tools.Palette))
end

-- 4. Every weapon's block placeholder builds, and carries what the game wants.
if Server or Range then
	local WeaponConfig = require(Shared.Config.WeaponConfig)
	local WeaponModels = require(Shared.WeaponModels)
	for name, config in WeaponConfig.Weapons do
		check(`the {name} placeholder model builds`, function()
			local model = WeaponModels.build(config.model)
			expect(model ~= nil, "no model")
			expect(model.PrimaryPart ~= nil, "no PrimaryPart")
			expect(model.PrimaryPart:FindFirstChild("Muzzle") ~= nil, "no Muzzle attachment")
			model:Destroy()
		end)
	end
end

-- 5. Every map builds, with the folders the rest of the game looks for.
-- The match place keeps its layouts in a Maps folder; the lobby and the range
-- have only the one each, beside their own code.
local layouts = {}
local folder = code:FindFirstChild("Maps")
if folder then
	layouts = folder:GetChildren()
elseif code:FindFirstChild("Penthouse") then
	layouts = { code.Penthouse }
elseif code:FindFirstChild("FiringRange") then
	layouts = { code.FiringRange }
end
local function buildMap(name, layout)
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	if layout.styles then
		materialsIn(name, layout.styles)
	end
	MapBuilder.build(layout)
	local map = workspace:FindFirstChild("Map")
	expect(map ~= nil, "no Map folder")
	return map
end

for _, module in layouts do
	local layout = require(module)
	check(`the map {module.Name} builds`, function()
		local map = buildMap(module.Name, layout)
		for _, folder in { "Geometry", "Props", "Spawns", "Bounds" } do
			expect(map:FindFirstChild(folder) ~= nil, `no {folder}`)
		end
		local parts = 0
		for _, part in map:GetDescendants() do
			if part:IsA("BasePart") then
				parts += 1
			end
		end
		expect(parts > 20, `only {parts} parts`)
		print(`      {module.Name}: {parts} parts`)
	end)

	-- Haze that starts at the camera would fog the room you stand in.
	if not layout.atmosphere then
		check(`{module.Name} does not fog the room you are standing in`, function()
			expect(layout.lighting.fogStart ~= nil, "no fogStart, so haze begins at the camera")
			expect(layout.lighting.fogStart < layout.lighting.fogEnd, "fogStart is past fogEnd")
		end)
	end

	if layout.sites then
		check(`the sites of {module.Name} are built`, function()
			local sites = workspace.Map:FindFirstChild("Sites")
			expect(sites ~= nil, "no Sites folder")
			expect(#sites:GetChildren() == #layout.sites, "a site is missing")
		end)
	end

	if layout.barriers then
		check(`{module.Name} keeps its players in`, function()
			local barriers = workspace.Map:FindFirstChild("Barriers")
			expect(barriers ~= nil, "no Barriers folder")
			expect(#barriers:GetChildren() == #layout.barriers, "a barrier is missing")
			for _, wall in barriers:GetChildren() do
				expect(wall.CanCollide, "a barrier does not collide")
				expect(wall.Transparency == 1, "a barrier can be seen")
				expect(not wall.CanQuery, "a barrier would stop shots")
			end
		end)
	end

	if layout.traffic then
		check(`the traffic routes of {module.Name} reach the client`, function()
			local encoded = workspace.Map:GetAttribute("Traffic")
			expect(type(encoded) == "string", "no Traffic attribute")
			local routes = game:GetService("HttpService"):JSONDecode(encoded)
			expect(#routes == #layout.traffic, "a route is missing")
			for _, route in routes do
				expect(#route.path >= 2 and route.count > 0 and route.speed > 0, "a route is incomplete")
			end
		end)
	end

	if layout.finish then
		check(`the picture finishing of {module.Name}`, function()
			expect(Lighting:FindFirstChildOfClass("BloomEffect") ~= nil, "no bloom")
			expect(Lighting:FindFirstChildOfClass("ColorCorrectionEffect") ~= nil, "no grade")
		end)
	end

	check(`every shaped piece of {module.Name} is the shape it asks for`, function()
		local wanted = 0
		for _, list in { layout.boxes, layout.backdrop or {} } do
			for _, box in list do
				if box.shape then
					wanted += 1
					expect(Enum.PartType[box.shape] ~= nil, `no such shape as {box.shape}`)
				end
			end
		end
		local built = 0
		for _, part in workspace.Map:GetDescendants() do
			if part:IsA("Part") and part.Shape ~= Enum.PartType.Block then
				built += 1
			end
		end
		expect(built == wanted, `{wanted} shaped pieces asked for, {built} built`)
	end)

	if layout.backdrop then
		check(`the skyline and haze of {module.Name}`, function()
			local backdrop = workspace.Map:FindFirstChild("Backdrop")
			expect(backdrop ~= nil, "no Backdrop")
			expect(#backdrop:GetChildren() > 100, "the skyline is nearly empty")
			expect(Lighting:FindFirstChildOfClass("Atmosphere") ~= nil, "no Atmosphere")
			print(`      {module.Name}: {#backdrop:GetChildren()} skyline parts`)
		end)
	end
end

-- 6. The test range: its signs, its dummies, and what a hit does to one. No
--    player is here to shoot, so the hits are handed to a dummy directly, the
--    way CombatService hands it one that has passed every check, and what it
--    would have sent to the shooter is caught and read.
if Range then
	local layout = require(Range.FiringRange)
	local ArmorConfig = require(Shared.Config.ArmorConfig)
	local MatchConfig = require(Shared.Config.MatchConfig)
	local MovementConfig = require(Shared.Config.MovementConfig)
	local RangeConfig = require(Shared.Config.RangeConfig)
	local WeaponConfig = require(Shared.Config.WeaponConfig)
	local Damage = require(Shared.Logic.Damage)
	local Loadout = require(Shared.Logic.Loadout)
	local Remotes = require(Shared.Remotes)
	local CombatService = require(Range.CombatService)
	local DummyService = require(Range.DummyService)
	local Signs = require(Range.Signs)

	check("the range's signs are written", function()
		Signs.build(layout)
		local written = 0
		for _, sign in workspace.Map.Props:GetChildren() do
			if sign.Name == "Sign" then
				local face = sign:FindFirstChildOfClass("SurfaceGui")
				expect(face ~= nil, "a sign has no face")
				local words = face:FindFirstChildOfClass("TextLabel")
				expect(words ~= nil and #words.Text > 0, "a sign says nothing")
				expect(not sign.CanCollide and not sign.CanQuery, "a sign would stop a player or a shot")
				written += 1
			end
		end
		expect(written == #layout.signs + #layout.drops, `{#layout.signs + #layout.drops} signs asked for, {written} written`)
	end)

	check("each landing of the drop tower says what the fall costs", function()
		local costs = {}
		for _, sign in workspace.Map.Props:GetChildren() do
			local words = sign.Name == "Sign" and sign.SurfaceGui:GetChildren()
			for _, label in words or {} do
				if label:IsA("TextLabel") and (string.find(label.Text, "HP") or label.Text == "NO DAMAGE") then
					table.insert(costs, label.Text)
				end
			end
		end
		expect(#costs == #layout.drops, `{#layout.drops} landings, {#costs} costs`)
		print("      drops: " .. table.concat(costs, " | "))
	end)

	-- Catches what a dummy would send to players.
	local sent = {}
	for _, name in { "HitConfirm", "RangeHit", "KillFeed", "ShotFired" } do
		Remotes[name] = {
			FireClient = function(_, _who, ...)
				table.insert(sent, { name = name, args = { ... } })
			end,
			FireAllClients = function(_, ...)
				table.insert(sent, { name = name, args = { ... } })
			end,
		}
	end
	local function last(name)
		for index = #sent, 1, -1 do
			if sent[index].name == name then
				return sent[index].args
			end
		end
		return nil
	end

	local built = false
	check("a dummy stands at every post, the size of a player", function()
		DummyService.init(layout)
		local folder = workspace:FindFirstChild("Dummies")
		expect(folder ~= nil, "no Dummies folder")
		expect(#folder:GetChildren() == #layout.dummies, `{#layout.dummies} posts, {#folder:GetChildren()} dummies`)
		for _, model in folder:GetChildren() do
			for _, name in { "Humanoid", "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "RightHand", "Tag" } do
				expect(model:FindFirstChild(name) ~= nil, `a dummy has no {name}`)
			end
			for _, entry in RangeConfig.aims do
				expect(model:FindFirstChild(entry.part) ~= nil, `a dummy has no {entry.part} to aim at`)
			end
			expect(type(model:GetAttribute("Dummy")) == "number", "a dummy is not marked as one")
			expect(model.HumanoidRootPart.Anchored, "a dummy standing still is not held in place")
			expect(model.Humanoid.Health == MatchConfig.maxHealth, "a dummy is not at full health")
			-- Feet on the ground, head where a player's is.
			local low, high = math.huge, -math.huge
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					low = math.min(low, part.Position.Y - part.Size.Y / 2)
					high = math.max(high, part.Position.Y + part.Size.Y / 2)
				end
			end
			expect(math.abs(low) < 0.4, `a dummy's feet are {low} studs off the ground`)
			expect(high > 4.5 and high < 6.5, `a dummy is {high} studs tall`)
		end
		local one = folder:GetChildren()[1]
		print(`      a dummy: root {one.HumanoidRootPart.Position.Y} up, {#one:GetChildren()} children`)
		built = true
	end)

	if built then
		local shooter = { Name = "Tester" }
		local rifle = WeaponConfig.Weapons.M16
		local target = CombatService.targets()[1]
		local id = target.id
		local function strike(zone, amount)
			local raw = if amount then amount else Damage.gun(rifle, zone)
			local dealt = if amount then amount else Loadout.damage(target.stats, rifle.class, zone, raw)
			target.hit(shooter, "M16", dealt, { zone = zone, raw = raw, headshot = zone == "Head", distance = 15, at = target.root.Position })
			return raw, dealt
		end

		check("every dummy is registered as something to shoot", function()
			expect(#CombatService.targets() == #layout.dummies, "the dummies are not all targets")
			expect(target.root ~= nil and target.root.Name == "HumanoidRootPart", "a target has no root")
			expect(target.alive(), "a fresh dummy is not alive")
		end)

		check("a hit takes health off, is reported in full, and heeds armour", function()
			local raw, dealt = strike("Head")
			local helmet = ArmorConfig.helmet[ArmorConfig.defaults.helmet]
			expect(dealt == raw * (helmet.headScale or 1), `a headshot of {raw} became {dealt}`)
			expect(target.humanoid.Health == MatchConfig.maxHealth - dealt, `health is {target.humanoid.Health}`)
			local report = last("RangeHit")[1]
			expect(report.target == id and report.weapon == "M16" and report.zone == "Head", "the report names the wrong thing")
			expect(report.raw == raw and report.amount == dealt, "the report has the wrong damage")
			expect(report.left == target.humanoid.Health and not report.lethal, "the report has the wrong health")
			local confirm = last("HitConfirm")
			expect(confirm[1] == true and confirm[2] == false, "the hit marker was not told of a headshot")
			print(`      M16 to the head of a new dummy: {raw} before armour, {dealt} after`)
		end)

		check("a dummy can be stripped, and only set to what exists", function()
			expect(DummyService.set(id, "helmet", ""), "taking the helmet off was refused")
			expect(target.stats.headScale == 1, "a bare head is still protected")
			expect(not DummyService.set(id, "helmet", "Plate"), "body armour was accepted as a helmet")
			expect(not DummyService.set(id, "weapon", "Frag"), "a grenade was accepted as a gun")
			expect(DummyService.set("all", "body", "Deflector"), "setting every dummy was refused")
			for _, other in CombatService.targets() do
				expect(other.stats.classScale.Sniper == ArmorConfig.body.Deflector.classScale.Sniper, "a dummy did not change")
			end
			expect(string.find(target.wearing.Text, "DEFLECTOR") ~= nil, "the tag does not say what it wears")
		end)

		check("a dummy told to stay up takes a killing hit and is whole again", function()
			DummyService.set(id, "dies", false)
			strike("Plain", 500)
			expect(last("RangeHit")[1].lethal, "the hit was not reported as a kill")
			expect(last("HitConfirm")[2] == true, "no kill mark for it")
			expect(target.humanoid.Health == MatchConfig.maxHealth, "it is not back at full health")
			expect(target.alive(), "it died")
		end)

		check("a dummy told to die does, and is in the kill feed", function()
			DummyService.set(id, "dies", true)
			strike("Plain", 500)
			expect(target.humanoid.Health == 0 and not target.alive(), "it is still alive")
			local feed = last("KillFeed")
			expect(feed ~= nil and feed[1] == "Tester" and feed[3] == "M16", "the kill feed was not told")
		end)

		check("standing them all up brings a dead dummy back", function()
			DummyService.standAll()
			expect(target.alive() and target.humanoid.Health == MatchConfig.maxHealth, "it is not back")
			expect(target.model.Parent == workspace.Dummies, "its new body is not on the range")
			expect(#workspace.Dummies:GetChildren() == #layout.dummies, "a body was left behind")
		end)

		check("a dummy crouches, walks and takes up a gun", function()
			local standing = target.root.Position.Y
			DummyService.set(id, "crouched", true)
			expect(math.abs(standing - target.root.Position.Y - MovementConfig.crouchHipDrop) < 0.01, "it did not get lower")
			DummyService.set(id, "crouched", false)

			DummyService.set(id, "moves", true)
			expect(not target.root.Anchored, "a walking dummy is still held in place")
			expect(target.humanoid.WalkSpeed == MovementConfig.runSpeed, "it does not walk at a player's speed")
			DummyService.set(id, "moves", false)
			expect(target.root.Anchored, "it did not stop")

			DummyService.set(id, "weapon", "AK47")
			local held = target.model:FindFirstChild("HeldWeapon")
			expect(held ~= nil and held.PrimaryPart ~= nil, "it holds nothing")
			expect(target.model:GetAttribute("Weapon") == WeaponConfig.Weapons.AK47.model, "its shots would make no sound")
			expect(target.gun ~= nil and target.gun.mag == WeaponConfig.Weapons.AK47.magazine, "its gun is not loaded")
			DummyService.set(id, "weapon", "")
			expect(target.model:FindFirstChild("HeldWeapon") == nil and target.gun == nil, "it did not put the gun down")
		end)

		check("every dummy setting on the panel is one the server accepts", function()
			local fields = { helmet = { "" }, body = { "" }, weapon = { "" }, aim = {}, dies = { true, false }, moves = { true, false }, crouched = { true, false } }
			for _, slot in { "helmet", "body" } do
				for _, key in ArmorConfig.order[slot] do
					table.insert(fields[slot], key)
				end
			end
			for _, list in { WeaponConfig.PrimaryOrder, WeaponConfig.SecondaryOrder } do
				for _, name in list do
					table.insert(fields.weapon, name)
				end
			end
			for _, entry in RangeConfig.aims do
				table.insert(fields.aim, entry.name)
			end
			local tried = 0
			for field, values in fields do
				for _, value in values do
					expect(DummyService.set(id, field, value), `{field} = {tostring(value)} was refused`)
					tried += 1
				end
			end
			for field, value in { weapon = "", moves = false, crouched = false, dies = true } do
				DummyService.set(id, field, value)
			end
			print(`      {tried} settings tried on a dummy`)
		end)
	end
end

print(string.format("=== %d passed, %d failed", passed, failed))
