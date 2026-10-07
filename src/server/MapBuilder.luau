-- Builds a blockout map from a layout table (see Maps/NightYard).
--
-- Map contract, for any map built by hand in Studio instead:
--   Workspace.Map.Geometry      all collidable parts (hit validation raycasts against this)
--   Workspace.Map.Spawns.<Team> one part per spawn point
--   Workspace.Map.Bounds        a part enclosing the playable volume
--   Workspace.Map.Sites         optional: one flat part per objective site, named A, B, ...
--   Workspace.Map.Backdrop      optional: scenery beyond the playable area
--   Workspace.Map.Barriers      optional: invisible walls that keep players in
-- If Workspace.Map already exists, nothing is built.
--
-- Shapes: a box is a block unless it has `shape = "Cylinder"`, "Ball" or
-- "Wedge". Its size is still the box it fills. A cylinder stands upright
-- unless `axis` ("X" or "Z") lays it down along that direction. A wedge is the
-- box cut corner to corner: its upright face is on the box's own +Z side and
-- its slope runs down to nothing on the -Z side; `yaw` turns it.
--
-- Decoration: a box with `decor = true` is seen and nothing else. It goes in
-- Props, stops nobody and no shot, and the map tools leave it out of every
-- walking and wall check. Lanterns, shutters, roof tiles and trim are decor.
--
-- Signboards: `layout.signboards` is a list of boards with writing on them,
--   { pos = { x, y, z }, size = { width, height }, yaw = 0, text = "KEDAI KOPI",
--     color = { r, g, b }, ink = { r, g, b }, font = "GothamBold", lit = true }
-- The writing faces the board's own -Z, so `yaw = 0` is read from the north.
-- A `lit` board glows the same in shade and at night. Boards are decor.
--
-- Props: a box with a `prop` field is drawn as that model from
-- ReplicatedStorage.Assets.Props (see Tools.FitProps), stretched to the box.
-- The box stays in Geometry, invisible, as the collision. If the model has not
-- been imported the box is shown as before. Prop parts never collide and are
-- never hit by raycasts, so what the server validates is always the box.

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Carve = require(Shared.Logic.Carve)
local Theme = require(Shared.Config.Theme)

local MapBuilder = {}

local STYLES = {
	Floor = { Color3.fromRGB(60, 62, 68), Enum.Material.Concrete },
	Wall = { Color3.fromRGB(88, 92, 100), Enum.Material.Concrete },
	Building = { Color3.fromRGB(92, 78, 70), Enum.Material.Brick },
	Cover = { Color3.fromRGB(110, 92, 74), Enum.Material.Metal },
	Catwalk = { Color3.fromRGB(74, 80, 88), Enum.Material.DiamondPlate },
	Post = { Color3.fromRGB(30, 32, 38), Enum.Material.Metal },
	Glow = { Color3.fromRGB(255, 140, 60), Enum.Material.Neon },
	Regolith = { Color3.fromRGB(138, 140, 146), Enum.Material.Sand },
	Rim = { Color3.fromRGB(72, 74, 80), Enum.Material.Slate },
	Hull = { Color3.fromRGB(206, 210, 216), Enum.Material.Metal },
	Solar = { Color3.fromRGB(30, 44, 84), Enum.Material.Metal },
}

local DEFAULT_GRAVITY = 196.2

local LAMP_COLLAR = 0.95 -- studs from the centre of the LampHead prop to its mounting collar

local function vector(values, sign)
	return Vector3.new(values[1] * sign, values[2], values[3])
end

local function color(values)
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- A layout may carry its own `styles`, which win over STYLES for that map:
--   styles = { Kind = { color = { r, g, b }, material = "Name", mirrorColor = { r, g, b },
--                       transparency = 0.6, reflectance = 0.2 } }
-- `mirrorColor`, if given, is used on the mirrored half, so one kind can show
-- each team's colour on its own side.
local mapStyles = {}

local function styled(kind, sign)
	local part = Instance.new("Part")
	part.Name = kind
	part.Anchored = true

	local custom = mapStyles[kind]
	if custom then
		local mirrored = sign and sign < 0 and custom.mirrorColor
		part.Color = color(mirrored or custom.color)
		part.Material = Enum.Material[custom.material]
		part.Transparency = custom.transparency or 0
		part.Reflectance = custom.reflectance or 0
	else
		local style = STYLES[kind] or STYLES.Wall
		part.Color = style[1]
		part.Material = style[2]
	end
	return part
end

local function propSource(name)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local model = props and props:FindFirstChild(name)
	if model and model:IsA("Model") and model.PrimaryPart and typeof(model:GetAttribute("Size")) == "Vector3" then
		return model
	end
	return nil
end

-- Places a copy of a prop centred at `cframe`. With `size`, the prop is
-- stretched along its own axes to fill a box of that size. Returns false if
-- the prop has not been imported.
local function placeProp(parent, name, cframe, size)
	local source = propSource(name)
	if not source then
		return false
	end
	local model = source:Clone()
	local root = model.PrimaryPart
	local ratio = if size then size / source:GetAttribute("Size") else Vector3.one

	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		if part ~= root then
			local offset = root.CFrame:ToObjectSpace(part.CFrame)
			-- Parts sit at right angles to the root, so the stretch along each
			-- of the part's own axes is one component of `ratio`.
			local own = offset:VectorToObjectSpace(ratio)
			part.Size *= Vector3.new(math.abs(own.X), math.abs(own.Y), math.abs(own.Z))
			part.CFrame = cframe * CFrame.new(offset.Position * ratio) * offset.Rotation
		end
	end
	root.CFrame = cframe

	model.Parent = parent
	return true
end

-- Degrees about Y for a box or prop, reflected for the mirrored half.
local function facing(yaw, sign)
	yaw = yaw or 0
	return math.rad(if sign < 0 then 180 - yaw else yaw)
end

-- Gives a part the box's `shape`, filling the box `size` at `cframe`.
local function shape(part, box, size, cframe)
	if box.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif box.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
		-- A Roblox cylinder runs along its own X.
		if box.axis == "Z" then
			size = Vector3.new(size.Z, size.Y, size.X)
			cframe *= CFrame.Angles(0, math.rad(90), 0)
		elseif box.axis ~= "X" then
			size = Vector3.new(size.Y, size.X, size.Z)
			cframe *= CFrame.Angles(0, 0, math.rad(90))
		end
	elseif box.shape == "Wedge" then
		part.Shape = Enum.PartType.Wedge
	end
	part.Size = size
	part.CFrame = cframe
end

-- `sign` is 1 for the layout as written and -1 for its mirror image across X = 0.
local function addBox(parent, props, box, sign)
	local part = styled(box.kind, sign)
	local cframe = CFrame.new(vector(box.pos, sign)) * CFrame.Angles(0, facing(box.yaw, sign), 0)
	if box.shape then
		shape(part, box, vector(box.size, 1), cframe)
		cframe = CFrame.new(cframe.Position) * cframe.Rotation -- a prop is placed by the box, not the part
	else
		part.Size = vector(box.size, 1)
		if box.yaw then
			part.CFrame = cframe
		else
			part.Position = cframe.Position
		end
	end
	if box.decor then
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = props
		return
	end
	part.Parent = parent

	if box.prop then
		local size = part.Size
		if box.propTurn then -- the prop's long side runs along the box's Z
			cframe *= CFrame.Angles(0, math.rad(90), 0)
			size = Vector3.new(size.Z, size.Y, size.X)
		end
		if placeProp(props, box.prop, cframe, size) then
			part.Transparency = 1
		end
	end
end

-- A board with writing on it. Scenery: it stops nobody and no shot.
local SIGN_PIXELS_PER_STUD = 24
local SIGN_THICKNESS = 0.3

local function addSignboard(parent, board)
	local part = Instance.new("Part")
	part.Name = "Signboard"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.new(board.size[1], board.size[2], SIGN_THICKNESS)
	part.CFrame = CFrame.new(vector(board.pos, 1)) * CFrame.Angles(0, math.rad(board.yaw or 0), 0)
	part.Color = color(board.color)
	part.Material = Enum.Material.SmoothPlastic

	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Front
	face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	face.PixelsPerStud = SIGN_PIXELS_PER_STUD
	face.LightInfluence = if board.lit then 0 else 1
	if board.lit then
		face.Brightness = 1.2
	end
	face.Parent = part

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.BackgroundTransparency = 1
	label.Text = board.text
	label.TextScaled = true
	label.Font = Enum.Font[board.font or Theme.bodyBold]
	label.TextColor3 = color(board.ink)
	label.Parent = face

	part.Parent = parent
end

-- Far-off scenery: seen, but never touched, shot or walked on.
local function addBackdrop(parent, box)
	local part = styled(box.kind, 1)
	shape(part, box, vector(box.size, 1), CFrame.new(vector(box.pos, 1)) * CFrame.Angles(0, math.rad(box.yaw or 0), 0))
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
end

-- A walkable slab whose top surface runs from `from` up to `to`. With
-- `decor = true` it is a sloping piece of scenery instead (a canopy, a
-- rafter): `thick` sets how thick, and it goes in `props` and stops nothing.
local function addRamp(parent, props, ramp, sign)
	local from, to = vector(ramp.from, sign), vector(ramp.to, sign)
	local thick = ramp.thick or 1
	local part = styled(ramp.kind, sign)
	part.Size = Vector3.new(ramp.width, thick, (to - from).Magnitude)
	part.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.new(0, -thick / 2, 0)
	if ramp.decor then
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = props
		return
	end
	part.Parent = parent
end

-- The light itself is always a part in Props. With the LampHead prop imported
-- that part is hidden inside the fitting. `post = true` adds a pole to the
-- ground, which is real geometry. `bare = true` is a light with nothing to see.
local function addLamp(geometry, props, lamp, sign)
	local part = Instance.new("Part")
	part.Name = "Lamp"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.new(1, 0.4, 1)
	part.Material = Enum.Material.Neon
	part.Color = color(lamp.color)
	part.Position = vector(lamp.pos, sign)

	local light = Instance.new("PointLight")
	light.Color = color(lamp.color)
	light.Range = lamp.range
	light.Brightness = lamp.brightness
	light.Parent = part

	part.Parent = props

	if lamp.bare or placeProp(props, "LampHead", CFrame.new(part.Position) * CFrame.Angles(0, facing(0, sign), 0)) then
		part.Transparency = 1
	end

	if lamp.post then
		local height = part.Position.Y - 0.45 -- up to the underside of the collar
		local post = styled("Post")
		post.Size = Vector3.new(0.6, height, 0.6)
		post.Position = Vector3.new(part.Position.X - LAMP_COLLAR * sign, height / 2, part.Position.Z)
		post.Parent = geometry
	end
end

-- `lookAtCentre` is for maps that are not mirrored, where "towards X = 0" is
-- not necessarily towards the fight.
local function addSpawns(parent, teamName, points, sign, lookAtCentre)
	local folder = Instance.new("Folder")
	folder.Name = teamName
	for index, point in points do
		local position = vector(point, sign)
		local part = Instance.new("Part")
		part.Name = "Spawn" .. index
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(4, 1, 4)
		-- Face the middle of the map.
		local target = Vector3.new(0, position.Y, if lookAtCentre then 0 else position.Z)
		part.CFrame = CFrame.lookAt(position, target)
		part.Parent = folder
	end
	folder.Parent = parent
end

-- An objective site: a flat marker on the ground with its letter on it. It
-- does not collide or stop shots. A game mode finds sites under Map.Sites;
-- each part's footprint is the site's area.
local function addSite(parent, site)
	local part = Instance.new("Part")
	part.Name = site.name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.new(site.size[1], 0.2, site.size[2])
	part.Position = Vector3.new(site.pos[1], 0.1, site.pos[2])
	part.Color = color(Theme.accent)
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 0.5

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = site.name
	label.TextScaled = true
	label.Font = Enum.Font[Theme.display]
	label.TextColor3 = color(Theme.ink)
	label.Parent = gui

	part.Parent = parent
end

local function invisibleVolume(name, position, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size
	part.Position = position
	return part
end

function MapBuilder.build(layout)
	if workspace:FindFirstChild("Map") then
		return
	end

	-- A new Studio place ships with these; they would overlap the map.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local default = workspace:FindFirstChild(name)
		if default then
			default:Destroy()
		end
	end

	mapStyles = layout.styles or {}

	local map = Instance.new("Folder")
	map.Name = "Map"

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = map

	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = map

	-- A map may declare the space its players move through and have the solid
	-- between it generated, rather than placing that solid by hand.
	if layout.fill then
		for _, rect in Carve.solids(layout.fill.bounds, layout.fill.open) do
			addBox(geometry, props, {
				kind = layout.fill.kind,
				pos = { (rect[1] + rect[3]) / 2, layout.fill.height / 2, (rect[2] + rect[4]) / 2 },
				size = { rect[3] - rect[1], layout.fill.height, rect[4] - rect[2] },
			}, 1)
		end
	end

	for _, box in layout.boxes do
		addBox(geometry, props, box, 1)
		if box.mirror then
			addBox(geometry, props, box, -1)
		end
	end
	for _, ramp in layout.ramps do
		addRamp(geometry, props, ramp, 1)
		if ramp.mirror then
			addRamp(geometry, props, ramp, -1)
		end
	end
	for _, lamp in layout.lamps do
		addLamp(geometry, props, lamp, 1)
		if lamp.mirror then
			addLamp(geometry, props, lamp, -1)
		end
	end

	for _, board in layout.signboards or {} do
		addSignboard(props, board)
	end

	if layout.backdrop then
		-- A persistent model, so the skyline is there however far away it is.
		local backdrop = Instance.new("Model")
		backdrop.Name = "Backdrop"
		backdrop.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		for _, box in layout.backdrop do
			addBackdrop(backdrop, box)
		end
		backdrop.Parent = map
	end

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	if layout.spawns[1] then
		-- One list: the second team's spawns are the mirror image.
		addSpawns(spawns, layout.teams[1], layout.spawns, 1)
		addSpawns(spawns, layout.teams[2], layout.spawns, -1)
	else
		-- A list per team, for maps that are not mirrored.
		for _, teamName in layout.teams do
			addSpawns(spawns, teamName, layout.spawns[teamName], 1, true)
		end
	end
	spawns.Parent = map

	local sites = Instance.new("Folder")
	sites.Name = "Sites"
	for _, site in layout.sites or {} do
		addSite(sites, site)
	end
	sites.Parent = map

	invisibleVolume("Bounds", vector(layout.bounds.pos, 1), vector(layout.bounds.size, 1)).Parent = map

	-- Walls nobody can see: they stop a player and nothing else. Shots and the
	-- map tools ignore them.
	if layout.barriers then
		local barriers = Instance.new("Folder")
		barriers.Name = "Barriers"
		for _, barrier in layout.barriers do
			local wall = invisibleVolume("Barrier", vector(barrier.pos, 1), vector(barrier.size, 1))
			wall.CanCollide = true
			wall.Parent = barriers
		end
		barriers.Parent = map
	end

	-- Moving scenery (the lobby's street traffic) is drawn by each client; the
	-- routes are handed over as they are written in the layout.
	if layout.traffic then
		map:SetAttribute("Traffic", HttpService:JSONEncode(layout.traffic))
	end

	map.Parent = workspace
	workspace.Gravity = layout.gravity or DEFAULT_GRAVITY

	local lighting = layout.lighting
	Lighting.ClockTime = lighting.clockTime
	Lighting.Brightness = lighting.brightness
	Lighting.Ambient = color(lighting.ambient)
	Lighting.OutdoorAmbient = color(lighting.outdoorAmbient)
	if lighting.latitude then
		Lighting.GeographicLatitude = lighting.latitude -- how high the sun climbs
	end
	-- Below 0 the whole picture is darker, as a camera stopped down: for a map
	-- with many lamps on pale walls, which would otherwise burn out.
	Lighting.ExposureCompensation = lighting.exposure or 0
	if lighting.environment then
		-- How much of the sky shows in metal and glass.
		Lighting.EnvironmentDiffuseScale = lighting.environment
		Lighting.EnvironmentSpecularScale = lighting.environment
	end

	-- Optional finishing on the picture: a glow around bright things, and a
	-- grade over everything. Rebuilt with the map.
	for _, old in Lighting:GetChildren() do
		if old:GetAttribute("FromMap") then
			old:Destroy()
		end
	end
	local finish = layout.finish or {}
	if finish.bloom then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = finish.bloom.intensity
		bloom.Size = finish.bloom.size
		bloom.Threshold = finish.bloom.threshold
		bloom:SetAttribute("FromMap", true)
		bloom.Parent = Lighting
	end
	if finish.grade then
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Brightness = finish.grade.brightness or 0
		grade.Contrast = finish.grade.contrast or 0
		grade.Saturation = finish.grade.saturation or 0
		grade.TintColor = color(finish.grade.tint or { 255, 255, 255 })
		grade:SetAttribute("FromMap", true)
		grade.Parent = Lighting
	end
	if finish.sunRays then
		local rays = Instance.new("SunRaysEffect")
		rays.Intensity = finish.sunRays.intensity
		rays.Spread = finish.sunRays.spread
		rays:SetAttribute("FromMap", true)
		rays.Parent = Lighting
	end

	-- Haze. A map either uses Roblox's legacy fog, which thickens evenly from
	-- `fogStart` to `fogEnd`, or an Atmosphere, which is thicker further away
	-- and looks right over a city. Roblox ignores the fog properties while an
	-- Atmosphere is there, so only one of them is ever set up.
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if existing then
		existing:Destroy()
	end
	if layout.atmosphere then
		local air = layout.atmosphere
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = air.density
		atmosphere.Offset = air.offset or 0
		atmosphere.Color = color(air.color)
		atmosphere.Decay = color(air.decay)
		atmosphere.Glare = air.glare or 0
		atmosphere.Haze = air.haze or 0
		atmosphere.Parent = Lighting
	else
		Lighting.FogColor = color(lighting.fogColor)
		-- Nothing nearer than this is hazed at all, so the room you stand in
		-- stays clear while the distance goes soft.
		Lighting.FogStart = lighting.fogStart or 0
		Lighting.FogEnd = lighting.fogEnd
	end
end

return MapBuilder
