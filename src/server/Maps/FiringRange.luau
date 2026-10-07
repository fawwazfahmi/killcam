-- The Firing Range: the test place's one map, an original open-air range.
-- Only the test place builds it (see range.project.json).
--
-- X runs across the range and Z along it. Players arrive at the south end
-- (+Z) and shoot north (-Z). Nothing is mirrored.
--
--   Z 214 ..  244   where players arrive, with two dummies for the knife
--   Z 198 ..  212   the stalls, and the firing line at Z 200
--   Z -216 .. 198   six lanes, one dummy each, 15 to 400 studs from the line
--   east of X 54    the recoil wall: a board ruled in half studs, to shoot at
--                   from marks 10, 20 and 40 studs away
--   west of X -54   the grenade pit, ringed every 5 studs out to a frag's
--                   reach, and north of it the drop tower, a ramp up the west
--                   wall with a landing at each height worth falling from
--
-- Besides the usual lists, the layout carries what the range's own server
-- reads (see src/range/server):
--   dummies  where the fixed dummies stand: label, { x, z }, and `yaw`
--   spots    where the panel can send a player: name, { x, y, z }, and `yaw`
--   signs    boards of text: text, an optional smaller `sub`, { x, y, z },
--            { width, height } and `yaw`
--   drops    the drop tower's landings: height, and where its sign goes
-- `yaw` is in degrees about Y. At 0 a dummy, a player or a sign's text faces
-- north (-Z); at 180, south; at 90, west (-X); at -90, east (+X).
--
-- pos is the centre of a box, size its full extents, all in studs.

local ACCENT = { 255, 196, 30 }

local LINE = 200 -- the firing line's Z
local LANES = {
	{ x = -40, distance = 15 },
	{ x = -24, distance = 30 },
	{ x = -8, distance = 60 },
	{ x = 8, distance = 100 },
	{ x = 24, distance = 200 },
	{ x = 40, distance = 400 },
}

local BOARD = { x = 83, z = 150, left = 71, right = 95, bottom = 1, top = 17 } -- the ruled part of the recoil wall
local MARKS = { 10, 20, 40 } -- studs from the recoil wall to each mark on the floor

local PIT = { x = -84, z = 176 }
local RINGS = { 25, 20, 15, 10, 5 } -- studs from the middle, widest first
-- Each ring's dummy stands at a different angle, all on the far side, so that
-- none hides another from whoever is throwing.
local PIT_ANGLES = { [5] = -60, [10] = -30, [15] = 0, [20] = 30, [25] = 60 }

-- The drop tower: a ramp climbing north along the west wall. Each entry is a
-- landing: how high, and how long the ramp up to it is.
local TOWER = { x = -108, width = 8, start = 140, landing = 8 }
local CLIMB = {
	{ height = 9, run = 18 },
	{ height = 12, run = 6 },
	{ height = 18, run = 12 },
	{ height = 24, run = 12 },
	{ height = 32, run = 16 },
	{ height = 40, run = 16 },
}

local boxes = {
	-- Ground and the four outer walls
	{ kind = "Floor", pos = { 0, -0.5, 14 }, size = { 226, 1, 462 } },
	{ kind = "Wall", pos = { 0, 24, -216.5 }, size = { 226, 48, 1 } },
	{ kind = "Wall", pos = { 0, 24, 244.5 }, size = { 226, 48, 1 } },
	{ kind = "Wall", pos = { -112.5, 24, 14 }, size = { 1, 48, 460 } },
	{ kind = "Wall", pos = { 112.5, 24, 14 }, size = { 1, 48, 460 } },

	-- The firing line, and the beam the lane boards hang from
	{ kind = "Line", pos = { 0, 0.03, LINE }, size = { 96, 0.06, 0.5 } },
	{ kind = "Post", pos = { 0, 11.3, LINE - 2 }, size = { 99, 0.6, 0.6 } },
	{ kind = "Post", pos = { -49, 5.5, LINE - 2 }, size = { 0.8, 11, 0.8 } },
	{ kind = "Post", pos = { 49, 5.5, LINE - 2 }, size = { 0.8, 11, 0.8 } },

	-- Walls between the lanes and the bays either side, open at the south end
	{ kind = "Wall", pos = { -54, 6, 182 }, size = { 1, 12, 64 } },
	{ kind = "Wall", pos = { 54, 6, 182 }, size = { 1, 12, 64 } },

	-- The recoil wall
	{ kind = "Board", pos = { BOARD.x, 12, BOARD.z - 0.5 }, size = { 44, 24, 1 } },
	{ kind = "Line", pos = { BOARD.x, 5, BOARD.z + 0.04 }, size = { 0.5, 0.5, 0.08 } }, -- where to aim
}

local signs, dummies, spots, drops, ramps = {}, {}, {}, {}, {}

-- Lanes ------------------------------------------------------------------------

for index = 0, #LANES do
	-- A stall wall either side of every lane.
	table.insert(boxes, { kind = "Wall", pos = { -48 + index * 16, 2, 205 }, size = { 0.6, 4, 14 } })
end
for _, lane in LANES do
	local z = LINE - lane.distance
	table.insert(boxes, { kind = "Lane", pos = { lane.x, 0.01, -3 }, size = { 12, 0.02, 426 } })
	table.insert(boxes, { kind = "Line", pos = { lane.x, 0.03, z }, size = { 10, 0.06, 0.4 } })
	table.insert(dummies, { label = lane.distance .. " STUDS", pos = { lane.x, z }, yaw = 180 })
	table.insert(signs, {
		text = tostring(lane.distance),
		sub = "STUDS",
		pos = { lane.x, 9.4, LINE - 2 },
		size = { 9, 3.2 },
		yaw = 180,
	})
end

-- Recoil wall ------------------------------------------------------------------

-- Ruled every half stud, heavier every two, so a pattern can be read off it.
local function rule(offset, vertical)
	local heavy = offset % 2 == 0
	local kind = if heavy then "GridHeavy" else "Grid"
	local thick = if heavy then 0.1 else 0.05
	local width, height = BOARD.right - BOARD.left, BOARD.top - BOARD.bottom
	if vertical then
		return {
			kind = kind,
			pos = { BOARD.left + offset, (BOARD.bottom + BOARD.top) / 2, BOARD.z + 0.02 },
			size = { thick, height, 0.04 },
		}
	end
	return {
		kind = kind,
		pos = { (BOARD.left + BOARD.right) / 2, BOARD.bottom + offset, BOARD.z + 0.02 },
		size = { width, thick, 0.04 },
	}
end
for step = 0, (BOARD.right - BOARD.left) * 2 do
	table.insert(boxes, rule(step / 2, true))
end
for step = 0, (BOARD.top - BOARD.bottom) * 2 do
	table.insert(boxes, rule(step / 2, false))
end
for _, distance in MARKS do
	local z = BOARD.z + distance
	table.insert(boxes, { kind = "Line", pos = { BOARD.x, 0.03, z }, size = { 24, 0.06, 0.4 } })
	table.insert(signs, { text = distance .. " STUDS", pos = { 100, 1.6, z }, size = { 7, 2 }, yaw = 180 })
end
table.insert(signs, {
	text = "RECOIL WALL",
	sub = "HALF A STUD TO A SQUARE",
	pos = { BOARD.x, 21, BOARD.z + 0.1 },
	size = { 24, 4 },
	yaw = 180,
})

-- Grenade pit ------------------------------------------------------------------

for index, radius in RINGS do
	-- Each smaller ring sits a hair higher, so it shows on top of the last.
	local height = 0.02 + index * 0.02
	table.insert(boxes, {
		kind = if index % 2 == 1 then "RingDark" else "RingLight",
		shape = "Cylinder",
		pos = { PIT.x, height / 2, PIT.z },
		size = { radius * 2, height, radius * 2 },
	})
	local angle = math.rad(PIT_ANGLES[radius])
	table.insert(dummies, {
		label = "PIT " .. radius,
		pos = { PIT.x + radius * math.sin(angle), PIT.z - radius * math.cos(angle) },
		yaw = 180,
	})
end
table.insert(boxes, { kind = "Line", shape = "Cylinder", pos = { PIT.x, 0.08, PIT.z }, size = { 1.2, 0.16, 1.2 } })
table.insert(boxes, { kind = "Line", pos = { PIT.x, 0.03, PIT.z + 40 }, size = { 30, 0.06, 0.5 } })
table.insert(signs, {
	text = "GRENADE PIT",
	sub = "A RING EVERY 5 STUDS",
	pos = { PIT.x, 14, 150 },
	size = { 24, 4 },
	yaw = 180,
})
table.insert(boxes, { kind = "Post", pos = { PIT.x - 11, 8, 150 }, size = { 0.8, 16, 0.8 } })
table.insert(boxes, { kind = "Post", pos = { PIT.x + 11, 8, 150 }, size = { 0.8, 16, 0.8 } })

-- Drop tower -------------------------------------------------------------------

do
	local z, height = TOWER.start, 0
	for _, step in CLIMB do
		table.insert(ramps, {
			kind = "Catwalk",
			from = { TOWER.x, height, z },
			to = { TOWER.x, step.height, z - step.run },
			width = TOWER.width,
		})
		z -= step.run
		height = step.height
		-- A landing is a solid block from the ground up.
		local middle = z - TOWER.landing / 2
		table.insert(boxes, {
			kind = "Catwalk",
			pos = { TOWER.x, height / 2, middle },
			size = { TOWER.width, height, TOWER.landing },
		})
		table.insert(drops, { height = height, pos = { -111.9, height + 5, middle }, size = { 7, 2.6 }, yaw = -90 })
		table.insert(spots, { name = "Drop " .. height, pos = { TOWER.x, height + 3.5, middle }, yaw = -90 })
		z -= TOWER.landing
	end
end

-- Knife dummies ----------------------------------------------------------------

table.insert(dummies, { label = "FACING YOU", pos = { 28, 234 }, yaw = 90 })
table.insert(dummies, { label = "BACK TURNED", pos = { 28, 222 }, yaw = -90 })

-- In the order the panel lists them: the ground first, then the tower.
local places = {
	{ name = "Firing line", pos = { -8, 3.5, 207 }, yaw = 0 },
	{ name = "Far end", pos = { 0, 3.5, -190 }, yaw = 180 },
	{ name = "Recoil wall", pos = { BOARD.x, 3.5, BOARD.z + 40 }, yaw = 0 },
	{ name = "Grenade pit", pos = { PIT.x, 3.5, PIT.z + 40 }, yaw = 0 },
	{ name = "Knife dummies", pos = { 18, 3.5, 228 }, yaw = -90 },
}
for _, spot in spots do
	table.insert(places, spot)
end

return {
	name = "Firing Range",
	teams = { "Range" },

	lighting = {
		clockTime = 14,
		brightness = 2.2,
		ambient = { 118, 122, 130 },
		outdoorAmbient = { 132, 136, 144 },
		fogColor = { 190, 200, 214 },
		fogStart = 400,
		fogEnd = 2400,
	},

	bounds = { pos = { 0, 30, 14 }, size = { 238, 82, 474 } },

	styles = {
		Line = { color = ACCENT, material = "Neon" },
		Lane = { color = { 70, 73, 82 }, material = "Concrete" },
		Board = { color = { 24, 26, 32 }, material = "SmoothPlastic" },
		Grid = { color = { 58, 62, 74 }, material = "SmoothPlastic" },
		GridHeavy = { color = { 120, 126, 142 }, material = "SmoothPlastic" },
		RingDark = { color = { 52, 55, 62 }, material = "Concrete" },
		RingLight = { color = { 84, 88, 98 }, material = "Concrete" },
	},

	boxes = boxes,
	ramps = ramps,
	lamps = {},

	spawns = {
		Range = {
			{ -12, 3.5, 230 },
			{ -6, 3.5, 230 },
			{ 0, 3.5, 230 },
			{ 6, 3.5, 230 },
			{ 12, 3.5, 230 },
		},
	},

	dummies = dummies,
	spots = places,
	signs = signs,
	drops = drops,
}
