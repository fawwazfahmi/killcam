-- Runs inside Roblox Studio, against either built place, through
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
-- The match place keeps its code under Server, the lobby under Lobby.
local Server = ServerScriptService:FindFirstChild("Server")
local Lobby = ServerScriptService:FindFirstChild("Lobby")
local code = Server or Lobby
expect(code ~= nil, "neither place's server code is here")

print(`=== studio smoke test: the {if Server then "match" else "lobby"} place`)

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
loadAll(code, if Server then "Server" else "Lobby")
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
if Server then
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
-- The match place keeps its layouts in a Maps folder; the lobby has only the
-- one, beside its own code.
local layouts = {}
local folder = code:FindFirstChild("Maps")
if folder then
	layouts = folder:GetChildren()
elseif code:FindFirstChild("Penthouse") then
	layouts = { code.Penthouse }
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

print(string.format("=== %d passed, %d failed", passed, failed))
