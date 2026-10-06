-- The traffic in the streets below the penthouse: cars, vans, the odd bus, and
-- cyclists in the park. It is scenery, so each player's own game draws and
-- moves it; nothing here is sent over the network or can be touched.
--
-- The routes come from the layout (see `traffic` in the Penthouse map), which
-- the server leaves on Workspace.Map as an attribute.

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local StreetLife = {}

local LOOK_AHEAD = 6 -- studs along the route a vehicle points at, which rounds its corners

local DARK = Color3.fromRGB(26, 28, 32)
local WINDOW = Color3.fromRGB(34, 40, 50)
local HEADLIGHT = Color3.fromRGB(255, 244, 214)
local TAILLIGHT = Color3.fromRGB(255, 62, 50)
local SHUTTLE = Color3.fromRGB(255, 196, 30) -- the company's own buses
local PAINT = {
	Color3.fromRGB(236, 236, 232),
	Color3.fromRGB(40, 42, 48),
	Color3.fromRGB(150, 156, 164),
	Color3.fromRGB(176, 40, 40),
	Color3.fromRGB(38, 70, 130),
	Color3.fromRGB(196, 190, 170),
}
local SHIRTS = {
	Color3.fromRGB(230, 90, 60),
	Color3.fromRGB(60, 140, 210),
	Color3.fromRGB(240, 220, 80),
	Color3.fromRGB(236, 236, 236),
}

local random = Random.new(118) -- the same streets for everyone

-- Adds a piece to a vehicle. `offset` is from the middle of the vehicle at
-- road level; a vehicle faces its own -Z.
local function piece(model, size, offset, colour, material, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = if typeof(offset) == "CFrame" then offset else CFrame.new(offset)
	part.Color = colour
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = model
	return part
end

-- Wheels at each of `axles` (distances along the vehicle), `track` apart.
local function wheels(model, track, axles, diameter)
	for _, z in axles do
		for _, side in { -1, 1 } do
			piece(
				model,
				Vector3.new(0.9, diameter, diameter),
				Vector3.new(side * track / 2, diameter / 2, z),
				DARK,
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
		end
	end
end

local function lights(model, width, height, half)
	for _, side in { -1, 1 } do
		piece(model, Vector3.new(1.3, 0.45, 0.2), Vector3.new(side * width, height, -half), HEADLIGHT, Enum.Material.Neon)
		piece(model, Vector3.new(1.3, 0.45, 0.2), Vector3.new(side * width, height, half), TAILLIGHT, Enum.Material.Neon)
	end
end

local BUILD = {}

function BUILD.Car(model)
	local paint = PAINT[random:NextInteger(1, #PAINT)]
	piece(model, Vector3.new(6.4, 2, 14.4), Vector3.new(0, 2, 0), paint, Enum.Material.Metal)
	piece(model, Vector3.new(5.8, 1.9, 7.6), Vector3.new(0, 3.9, 0.6), WINDOW)
	piece(model, Vector3.new(5.4, 0.15, 6.6), Vector3.new(0, 4.9, 0.6), paint, Enum.Material.Metal)
	wheels(model, 5.9, { -4.5, 4.5 }, 2.6)
	lights(model, 2.2, 2.3, 7.25)
end

function BUILD.Van(model)
	local paint = PAINT[random:NextInteger(1, 3)]
	piece(model, Vector3.new(6.8, 4.6, 15.6), Vector3.new(0, 3.3, 0), paint, Enum.Material.Metal)
	piece(model, Vector3.new(6.9, 1.7, 3.4), Vector3.new(0, 4.4, -5.8), WINDOW)
	wheels(model, 6.3, { -5, 5 }, 2.8)
	lights(model, 2.4, 2, 7.85)
end

function BUILD.Bus(model)
	piece(model, Vector3.new(8, 7, 34), Vector3.new(0, 4.7, 0), SHUTTLE, Enum.Material.Metal)
	piece(model, Vector3.new(8.1, 2.3, 30), Vector3.new(0, 5.7, 0), WINDOW)
	piece(model, Vector3.new(5, 0.8, 12), Vector3.new(0, 8.6, 4), Color3.fromRGB(226, 226, 222))
	wheels(model, 7.5, { -11, 9, 12.5 }, 3.2)
	lights(model, 2.8, 2.2, 17.05)
end

function BUILD.Bicycle(model)
	local frame = PAINT[random:NextInteger(1, #PAINT)]
	local shirt = SHIRTS[random:NextInteger(1, #SHIRTS)]
	for _, z in { -1.9, 1.9 } do
		piece(model, Vector3.new(0.2, 2.4, 2.4), Vector3.new(0, 1.2, z), DARK, nil, Enum.PartType.Cylinder)
	end
	piece(model, Vector3.new(0.2, 0.2, 3.8), Vector3.new(0, 2.2, 0), frame)
	piece(model, Vector3.new(0.2, 1.4, 0.2), Vector3.new(0, 2.6, 1), frame)
	piece(model, Vector3.new(1.6, 0.2, 0.2), Vector3.new(0, 3.3, -1.7), DARK) -- handlebars
	-- The rider, leaning over the bars.
	piece(model, Vector3.new(1, 1.7, 0.6), Vector3.new(0, 2.9, 0.6), DARK)
	piece(model, Vector3.new(1.1, 2, 0.8), CFrame.new(0, 4.3, 0) * CFrame.Angles(math.rad(-32), 0, 0), shirt)
	piece(model, Vector3.new(1.1, 1.1, 1.1), Vector3.new(0, 5.5, -0.8), Color3.fromRGB(232, 232, 228), nil, Enum.PartType.Ball)
end

local function build(kind, parent)
	local model = Instance.new("Model")
	model.Name = kind
	-- An unseen piece at road level that the rest is placed around.
	local root = piece(model, Vector3.new(0.2, 0.2, 0.2), Vector3.zero, DARK)
	root.Transparency = 1
	model.PrimaryPart = root
	BUILD[kind](model)
	model.Parent = parent
	return model
end

-- A route as points in the world, with how far along each one is.
local function measure(route)
	local points, along, total = {}, { 0 }, 0
	for _, point in route.path do
		table.insert(points, Vector3.new(point[1], route.y, point[2]))
	end
	if route.loop then
		table.insert(points, points[1])
	end
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
		along[index] = total
	end
	return { points = points, along = along, total = total, loop = route.loop == true, speed = route.speed }
end

-- The point `distance` along a route. Past the end, a loop carries on round
-- and any other route carries straight on.
local function pointAt(route, distance)
	if route.loop then
		distance %= route.total
	end
	local last = #route.points
	for index = 2, last do
		if distance <= route.along[index] or index == last then
			local from, to = route.points[index - 1], route.points[index]
			local span = route.along[index] - route.along[index - 1]
			return from + (to - from) * ((distance - route.along[index - 1]) / span)
		end
	end
	return route.points[last]
end

function StreetLife.start()
	local map = workspace:WaitForChild("Map")
	local encoded = map:GetAttribute("Traffic")
	if type(encoded) ~= "string" then
		return -- this map has no streets
	end

	local folder = Instance.new("Folder")
	folder.Name = "StreetLife"
	folder.Parent = workspace

	local vehicles = {}
	for _, described in HttpService:JSONDecode(encoded) do
		local route = measure(described)
		local spacing = route.total / described.count
		for index = 1, described.count do
			local kind = described.kinds[(index - 1) % #described.kinds + 1]
			table.insert(vehicles, {
				model = build(kind, folder),
				route = route,
				-- Evenly spread, but not so evenly that it looks drilled.
				distance = (index - 1) * spacing + random:NextNumber(0, spacing * 0.3),
			})
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		for _, vehicle in vehicles do
			local route = vehicle.route
			vehicle.distance = (vehicle.distance + route.speed * dt) % route.total
			local here = pointAt(route, vehicle.distance)
			local ahead = pointAt(route, vehicle.distance + LOOK_AHEAD)
			vehicle.model:PivotTo(CFrame.lookAt(here, ahead))
		end
	end)
end

return StreetLife
