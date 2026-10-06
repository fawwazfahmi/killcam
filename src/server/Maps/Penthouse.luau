-- The Penthouse: the lobby. An original layout, not a match map.
--
-- The top floor of the company's tower, where players wait between matches.
-- You step out of the lift on the west side onto a dark stone runway that
-- crosses the whole floor to the match lift on the east. Everything else is
-- arranged either side of that line:
--
--   north-west  the bar                north-east  a model of the arena, under glass
--   north       the armoury wall       (Armoury station: loadout and shop)
--   centre      the lounge
--   south-west  a quiet corner         (Profile station: rank, points, rentals)
--   south-east  by the sofa            (Squad station: team up before queueing)
--   east end    the match lift         (Play station: pick a mode and queue)
--   south       the terrace, beyond a glass front
--
-- The terrace looks south down a park to a pair of twin towers, in the manner
-- of Kuala Lumpur: a telecom tower on its hill beside them, a very tall spired
-- tower and a finance-district tower further off, and a city of ordinary
-- blocks around. They are plain stylised shapes with no names or signs. The
-- streets below carry traffic, which each player's own game draws (see
-- `traffic`, and StreetLife in the lobby client).
--
-- Nobody can leave: the room is closed, and `barriers` puts an invisible box
-- over the terrace.
--
-- X runs west to east, Z north to south. A box's pos is its centre and its
-- size its full extents, in studs.

local WARM = { 255, 226, 186 }

local boxes = {}

local function put(kind, x, y, z, sx, sy, sz, extra)
	local box = { kind = kind, pos = { x, y, z }, size = { sx, sy, sz } }
	for key, value in extra or {} do
		box[key] = value
	end
	table.insert(boxes, box)
end

local ROUND = { shape = "Cylinder" }
local BALL = { shape = "Ball" }

local lamps = {}

-- A light with nothing to see: the fitting it belongs to is drawn as boxes.
local function light(x, y, z, range, brightness)
	table.insert(lamps, { pos = { x, y, z }, color = WARM, range = range, brightness = brightness, bare = true })
end

-- Shell ---------------------------------------------------------------------

-- Floors: pale stone inside (Z -40..22), boards on the terrace (Z 22..40.5).
put("Floor", 0, -0.5, -9, 112, 1, 62)
put("Deck", 0, -0.5, 31.25, 112, 1, 18.5)

-- The runway from lift to lift, edged in brass, and a threshold at the glass.
put("Stone", 0, 0.02, 0, 108, 0.08, 8)
put("Brass", 0, 0.03, -4.15, 108, 0.1, 0.3)
put("Brass", 0, 0.03, 4.15, 108, 0.1, 0.3)
put("Stone", 0, 0.02, 22, 112, 0.08, 1.4)

-- Ceiling, with three lines of light let into it, and a canopy over the
-- first few studs of the terrace.
put("Ceiling", 0, 14.5, -9, 112, 1, 64)
put("Frame", 0, 14.6, 26.5, 112, 0.8, 7)
put("Brass", 0, 14.15, 29.9, 112, 0.1, 0.2)
for _, z in { -31, 0, 16 } do
	put("Light", 0, 13.96, z, 100, 0.08, 0.5)
end
for _, x in { -40, -20, 0, 20, 40 } do
	light(x, 13.2, 0, 30, 0.7)
end
for _, x in { -22, 0, 22 } do
	light(x, 13.2, -31, 30, 0.9)
end
for _, x in { -36, 0, 36 } do
	light(x, 13.2, 16, 28, 0.6)
end

-- North wall: timber behind the armoury, and slats in the bays either side.
put("Wall", 0, 7, -40.5, 112, 14, 1)
put("Timber", 0, 7, -39.85, 78, 14, 0.3)
for step = 0, 11 do
	local x = 40.6 + step * 1.2
	put("Slat", -x, 7, -39.75, 0.5, 14, 0.5)
	put("Slat", x, 7, -39.75, 0.5, 14, 0.5)
end

-- A lift: two door leaves in a deep steel portal, a light bar over them and a
-- call panel beside. `inward` is +1 where the room is on the +X side.
local function lift(x, inward)
	put("Frame", x, 6, -7, 1.6, 12, 2)
	put("Frame", x, 6, 7, 1.6, 12, 2)
	put("Frame", x, 13, 0, 1.6, 2, 16)
	put("Door", x, 6, -3, 0.6, 12, 6)
	put("Door", x, 6, 3, 0.6, 12, 6)
	put("Frame", x + inward * 0.32, 6, 0, 0.06, 12, 0.14) -- the seam between the leaves
	put("Glow", x + inward * 0.85, 12.6, 0, 0.12, 0.35, 6)
	put("Brass", x + inward * 0.56, 4.4, 9, 0.12, 1.6, 0.8)
	put("Brass", x + inward * 2.4, 0.03, 0, 3.2, 0.1, 12) -- threshold plate
end

-- West wall: solid either side of the arrival lift.
put("Wall", -55.5, 7, -24, 1, 14, 32)
put("Wall", -55.5, 7, 15, 1, 14, 14)
lift(-55.5, 1)

-- East wall: glass either side of the match lift.
put("Glass", 55.5, 7, -24, 0.4, 14, 32)
put("Glass", 55.5, 7, 15, 0.4, 14, 14)
lift(55.5, -1)
for _, z in { -39.6, -32, -24, -16, 15, 21.6 } do
	put("Frame", 55.5, 7, z, 0.7, 14, 0.5)
end
for _, y in { 0.3, 13.7 } do
	put("Frame", 55.5, y, -24, 0.7, 0.6, 32)
	put("Frame", 55.5, y, 15, 0.7, 0.6, 14)
end

-- Glass front onto the terrace, with a wide opening in the middle (X -14..14).
for _, side in { -1, 1 } do
	put("Glass", side * 34.5, 7, 22, 41, 14, 0.4)
	put("Frame", side * 34.5, 0.3, 22, 41, 0.6, 0.7)
	put("Frame", side * 34.5, 13.7, 22, 41, 0.6, 0.7)
	put("Frame", side * 14, 7, 22, 1, 14, 1)
	for _, x in { 22.2, 30.4, 38.6, 46.8, 55 } do
		put("Frame", side * x, 7, 22, 0.5, 14, 0.7)
	end
end
put("Frame", 0, 13.5, 22, 28, 1, 1)

-- Four round columns, each on a dark base with a brass collar under the ceiling.
for _, at in { { -30, -20 }, { 30, -20 }, { -30, 14 }, { 30, 14 } } do
	put("Column", at[1], 7, at[2], 2.4, 14, 2.4, ROUND)
	put("Frame", at[1], 0.3, at[2], 3.2, 0.6, 3.2, ROUND)
	put("Brass", at[1], 13.6, at[2], 3, 0.3, 3, ROUND)
end

-- Furniture -----------------------------------------------------------------

-- A sofa `length` long, lying along X and facing `toward` (+1 is south).
local function sofa(x, z, toward, length)
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			put("Frame", x + dx * (length / 2 - 0.6), 0.25, z + dz * 1.5, 0.4, 0.5, 0.4)
		end
		put("Seat", x + dx * (length / 2 - 0.5), 2.3, z + toward * 0.2, 1, 1.2, 3.6) -- arm
	end
	put("Seat", x, 1.1, z, length, 1.2, 4)
	put("Seat", x, 2.6, z - toward * 1.6, length, 3, 0.9)
	local width = (length - 2.4) / 3
	for index = -1, 1 do
		put("Cushion", x + index * width, 2, z + toward * 0.35, width - 0.15, 0.6, 2.9)
		put("Cushion", x + index * width, 3, z - toward * 0.95, width - 0.15, 1.6, 0.6)
	end
end

-- An armchair facing along X (`toward` +1 is east).
local function armchair(x, z, toward)
	put("Seat", x, 1.1, z, 3.6, 1.2, 3.6)
	put("Seat", x - toward * 1.5, 2.6, z, 0.9, 3, 3.6)
	put("Seat", x + toward * 0.2, 2.2, z - 1.5, 3.2, 1, 0.7)
	put("Seat", x + toward * 0.2, 2.2, z + 1.5, 3.2, 1, 0.7)
	put("Cushion", x + toward * 0.35, 1.95, z, 2.5, 0.5, 2.2)
end

-- A low table: a stone top on two brass frames.
local function lowTable(x, z, length, depth)
	put("Stone", x, 1.55, z, length, 0.3, depth)
	put("Brass", x - length / 2 + 0.9, 0.7, z, 0.3, 1.4, depth - 0.6)
	put("Brass", x + length / 2 - 0.9, 0.7, z, 0.3, 1.4, depth - 0.6)
end

-- A panel of dark timber hung under the ceiling, with light spilling round it.
local function raft(x, z, length, depth)
	put("Timber", x, 13.3, z, length, 0.4, depth)
	put("Light", x, 13.62, z, length - 1, 0.08, depth - 1)
	light(x, 12.6, z, 26, 0.8)
end

-- Shrubs in a row along X, as balls of two greens.
local function shrubs(x, y, z, sizes)
	local across = #sizes * 2.9
	for index, size in sizes do
		local kind = if index % 2 == 0 then "Leaf2" else "Leaf"
		put(kind, x - across / 2 + (index - 0.5) * 2.9, y + size * 0.3, z, size, size, size, BALL)
	end
end

-- The lounge: two sofas across a table on a rug, an armchair closing the east end.
put("Rug", -18, 0.05, -16, 30, 0.1, 20)
sofa(-18, -22.5, 1, 16)
sofa(-18, -9.5, -1, 16)
lowTable(-18, -16, 9, 4)
put("Brass", -19.6, 1.85, -16, 1.3, 0.3, 1.3, ROUND)
armchair(-5.6, -16, -1)
raft(-18, -16, 26, 16)
-- A floor lamp at the west end.
put("Frame", -29, 0.15, -9.5, 1.6, 0.3, 1.6, ROUND)
put("Frame", -29, 3.5, -9.5, 0.25, 6.6, 0.25, ROUND)
put("Light", -29, 7.4, -9.5, 2, 1.6, 2, ROUND)
light(-29, 7.4, -9.5, 16, 0.7)

-- The arena, as a model under glass: what the company built, on show.
put("Stone", 22, 1.5, -16, 12, 3, 9)
put("Brass", 22, 3.05, -16, 12.2, 0.1, 9.2)
put("Wall", 22, 3.25, -16, 10, 0.3, 7)
for _, block in {
	{ -3.4, -2, 2.2, 1.2, 1.6 }, { -3.4, 1.8, 2.6, 0.8, 2 }, { -0.4, 0, 1.4, 1.6, 3 },
	{ 2.6, -2.2, 3, 0.9, 1.4 }, { 3.2, 1.6, 2, 1.3, 2.2 }, { 0.2, 2.6, 1.8, 0.6, 1 },
} do
	put("Ceiling", 22 + block[1], 3.4 + block[4] / 2, -16 + block[2], block[3], block[4], block[5])
end
put("Glow", 18, 3.44, -13.4, 1.4, 0.08, 1.4) -- its two sites
put("Glow", 25.6, 3.44, -18.4, 1.4, 0.08, 1.4)
put("Glass", 22, 4.7, -16, 11, 2.8, 8)
raft(22, -16, 20, 14)

-- The bar: a timber counter with a stone top and a brass foot rail, four
-- stools, and lit shelves of bottles on the wall behind.
put("Timber", -42, 1.9, -26, 3.4, 3.8, 16)
put("Stone", -42, 3.95, -26, 4.2, 0.3, 16.6)
put("Brass", -40, 0.6, -26, 0.25, 0.25, 15, { shape = "Cylinder", axis = "Z" })
for _, z in { -32, -28, -24, -20 } do
	put("Frame", -38.4, 0.1, z, 1.5, 0.2, 1.5, ROUND)
	put("Frame", -38.4, 1.35, z, 0.3, 2.3, 0.3, ROUND)
	put("Seat", -38.4, 2.75, z, 1.9, 0.5, 1.9, ROUND)
end
put("Timber", -54, 1.9, -26, 2, 3.8, 15)
put("Stone", -54, 3.95, -26, 2.2, 0.3, 15.2)
put("Timber", -54.85, 8, -26, 0.3, 8, 15)
for row, y in { 6, 8.4, 10.8 } do
	put("Stone", -54.1, y, -26, 1.4, 0.2, 14.6)
	put("Light", -54.6, y - 0.18, -26, 0.15, 0.1, 14)
	for index = 0, 7 do
		local kind = ({ "BottleAmber", "BottleGreen", "BottleClear" })[(index + row) % 3 + 1]
		local height = 1.2 + ((index * 7 + row * 3) % 4) * 0.12
		put(kind, -54.1, y + 0.1 + height / 2, -31.6 + index * 1.6, 0.5, height, 0.5, ROUND)
	end
end
for _, z in { -31, -26, -21 } do
	put("Frame", -42, 11.6, z, 0.12, 4.8, 0.12)
	put("Brass", -42, 8.7, z, 1.6, 1.2, 1.6, ROUND)
	put("Light", -42, 8.05, z, 1, 0.2, 1, ROUND)
	light(-42, 7.6, z, 14, 0.7)
end

-- The armoury wall: two lit racks either side of a bay of brass fins, where
-- the station stands, and a glass-topped case in front of each rack.
local displays = {}
for _, x in { -22, 22 } do
	put("Stone", x, 0.5, -38.9, 26.6, 1, 2.2)
	put("Rack", x, 5.5, -39.5, 26, 9, 0.5)
	for _, y in { 2.2, 5, 7.8 } do
		put("Rack", x, y, -38.8, 26, 0.25, 1.8)
	end
	put("Frame", x - 13, 5.5, -38.9, 0.5, 9, 2)
	put("Frame", x + 13, 5.5, -38.9, 0.5, 9, 2)
	put("Glow", x, 10.15, -38.9, 26, 0.12, 0.3)
	for _, y in { 5, 7.8 } do
		for _, dx in { -8.5, 0, 8.5 } do
			table.insert(displays, { x + dx, y + 0.65, -38.8 })
		end
	end
	put("Timber", x, 1.4, -33, 18, 2.8, 3)
	put("Glass", x, 3.3, -33, 18, 1, 3)
	put("Brass", x, 2.82, -33, 18.2, 0.06, 3.2)
end
for _, x in { -6, -3, 0, 3, 6 } do
	put("Brass", x, 7, -39.55, 0.3, 12, 0.3)
end

-- A sofa and table by the match lift.
put("Rug", 18, 0.05, 10.5, 20, 0.1, 10)
sofa(18, 13, -1, 16)
lowTable(18, 8.4, 8, 3)

-- The quiet corner: two armchairs across a small round table.
put("Rug", -40, 0.05, 10.5, 14, 0.1, 9)
armchair(-45, 10.5, 1)
armchair(-35, 10.5, -1)
put("Brass", -40, 0.9, 10.5, 0.4, 1.6, 0.4, ROUND)
put("Stone", -40, 1.8, 10.5, 2.6, 0.2, 2.6, ROUND)

-- A long bench under the east glass, and a tall plant in the corner beyond it.
put("Seat", 51.5, 1.3, -24, 3, 0.8, 16)
put("Brass", 51.5, 0.45, -30.5, 2.4, 0.9, 0.3)
put("Brass", 51.5, 0.45, -17.5, 2.4, 0.9, 0.3)
put("Planter", 50, 1.3, -36, 3.6, 2.6, 3.6, ROUND)
put("Trunk", 50, 4.4, -36, 0.5, 3.8, 0.5, ROUND)
put("Leaf", 50, 7.4, -36, 4.2, 4.2, 4.2, BALL)
put("Leaf2", 51, 5.9, -35, 2.6, 2.6, 2.6, BALL)

-- Indoor planters by the glass.
for _, x in { -46, 46 } do
	put("Planter", x, 1.25, 18.5, 10, 2.5, 4)
	put("Soil", x, 2.55, 18.5, 9.4, 0.2, 3.4)
	shrubs(x, 2.6, 18.5, { 2.6, 3.4, 2.4 })
end

-- Terrace -------------------------------------------------------------------

-- A glass balustrade with a steel rail and a post every few studs.
put("Glass", 0, 2, 40.3, 110, 4, 0.3)
put("Frame", 0, 4.15, 40.3, 111, 0.3, 0.6)
for _, side in { -1, 1 } do
	put("Glass", side * 55.3, 2, 31.2, 0.3, 4, 18)
	put("Frame", side * 55.3, 4.15, 31.2, 0.6, 0.3, 18.6)
end
for step = -5, 5 do
	put("Frame", step * 11, 2.1, 40.3, 0.4, 4.2, 0.5)
end

-- A tree: a round trunk and a crown of three balls.
local function tree(x, z, ground, height, crown)
	put("Trunk", x, ground + height / 2, z, 1.2, height, 1.2, ROUND)
	local top = ground + height
	put("Leaf", x, top + crown * 0.3, z, crown, crown, crown, BALL)
	put("Leaf2", x + crown * 0.38, top - crown * 0.05, z + crown * 0.2, crown * 0.7, crown * 0.7, crown * 0.7, BALL)
	put("Leaf", x - crown * 0.36, top, z - crown * 0.22, crown * 0.62, crown * 0.62, crown * 0.62, BALL)
end

-- Two planted beds, each with a tree, and a water channel between them.
for _, side in { -1, 1 } do
	local x = side * 38
	put("Planter", x, 1, 33, 22, 2, 8)
	put("Soil", x, 2.05, 33, 21.4, 0.2, 7.4)
	tree(x + side * 5, 33, 2.1, 7.5, 7.5)
	shrubs(x - side * 4.5, 2.1, 34.5, { 2.4, 3, 2.2, 2.8 })
	shrubs(x - side * 5, 2.1, 31, { 2, 2.6 })
end
put("Planter", 0, 0.75, 37, 30, 1.5, 4)
put("Water", 0, 1.4, 37, 29, 0.3, 3)

-- Slatted benches, and four low lights along the deck.
for _, x in { -18, 18 } do
	for _, dz in { -0.8, 0, 0.8 } do
		put("Slat", x, 1.7, 30 + dz, 8, 0.25, 0.65)
	end
	put("Frame", x - 3.2, 0.8, 30, 0.4, 1.6, 2.2)
	put("Frame", x + 3.2, 0.8, 30, 0.4, 1.6, 2.2)
end
for _, at in { { -24, 38.8 }, { 24, 38.8 }, { -8, 25 }, { 8, 25 } } do
	put("Frame", at[1], 1.1, at[2], 0.6, 2.2, 0.6, ROUND)
	put("Light", at[1], 2.3, at[2], 0.7, 0.2, 0.7, ROUND)
	light(at[1], 2.6, at[2], 12, 0.5)
end

-- The city --------------------------------------------------------------------
-- The penthouse floor is at Y 0; the streets are far below it.
local STREET = -150

local city = {}

local function scenery(kind, x, y, z, sx, sy, sz, extra)
	local box = { kind = kind, pos = { x, y, z }, size = { sx, sy, sz } }
	for key, value in extra or {} do
		box[key] = value
	end
	table.insert(city, box)
end

-- Something flat on the ground between two corners. `lift` is how far its top
-- stands above the street, which also keeps one surface from fighting another.
local function flat(kind, x1, z1, x2, z2, lift)
	scenery(kind, (x1 + x2) / 2, STREET + lift / 2, (z1 + z2) / 2, x2 - x1, lift, z2 - z1)
end

-- A tower in stepped tiers, each one a square with a second turned across it:
-- an eight-pointed star in plan. `tiers` is { width, height }, widest first.
-- Returns the height reached.
local function starTower(kind, x, z, tiers)
	local top = STREET
	for _, tier in tiers do
		scenery(kind, x, top + tier[2] / 2, z, tier[1], tier[2], tier[1])
		scenery(kind, x, top + tier[2] / 2, z, tier[1] * 0.94, tier[2], tier[1] * 0.94, { yaw = 45 })
		top += tier[2]
	end
	return top
end

-- Two stepped towers with a bridge between them, about 265 tall: the nearest
-- and biggest thing in the view, at the far end of the park.
local function twinTowers(x, z)
	local tiers = { { 44, 88 }, { 39, 56 }, { 33, 44 }, { 27, 31 }, { 19, 19 }, { 11, 12 } }
	for _, offset in { -40, 40 } do
		local top = starTower("Steel", x + offset, z, tiers)
		scenery("Steel", x + offset, top + 3, z, 6, 6, 6, BALL)
		scenery("Spire", x + offset, top + 19, z, 2.4, 30, 2.4, ROUND)
	end
	scenery("Steel", x, STREET + 106, z, 38, 6, 8) -- the bridge
	scenery("Steel", x, STREET + 98, z, 4, 10, 4)
end

-- A slim round shaft on a green hill, with a pod near the top and a mast.
local function telecomTower(x, z)
	scenery("Hill", x, STREET + 22, z, 110, 44, 110, { yaw = 20 })
	scenery("Hill", x + 8, STREET + 40, z - 6, 70, 16, 70, { yaw = 50 })
	local base = STREET + 48
	scenery("Concrete", x, base + 65, z, 9, 130, 9, ROUND)
	scenery("Concrete", x, base + 132, z, 20, 7, 20, ROUND)
	scenery("Pod", x, base + 139, z, 27, 8, 27, ROUND)
	scenery("Concrete", x, base + 146, z, 19, 6, 19, ROUND)
	scenery("Concrete", x, base + 151, z, 11, 4, 11, ROUND)
	scenery("Spire", x, base + 173, z, 2.6, 40, 2.6, ROUND)
end

-- The tallest: faceted tiers turned against each other, and a long spire.
local function spireTower(x, z)
	local top = STREET
	for index, tier in { { 46, 95 }, { 42, 75 }, { 35, 55 }, { 27, 38 }, { 18, 25 } } do
		scenery("Glass2", x, top + tier[2] / 2, z, tier[1], tier[2], tier[1], { yaw = if index % 2 == 0 then 45 else 0 })
		top += tier[2]
	end
	scenery("Spire", x, top + 28, z, 4, 56, 4, ROUND)
end

-- A broad glass slab with a lit crown.
local function financeTower(x, z)
	scenery("Glass2", x, STREET + 95, z, 44, 190, 40, { yaw = 15 })
	scenery("Pod", x, STREET + 197, z, 34, 14, 30, { yaw = 15 })
end

-- A street tree.
local function streetTree(x, z, scale, index)
	scenery("Trunk", x, STREET + 3.5 * scale, z, 1.6, 7 * scale, 1.6, ROUND)
	local crown = 13 * scale
	scenery(if index % 2 == 0 then "Leaf" else "Leaf2", x, STREET + 7 * scale + crown * 0.4, z, crown, crown, crown, BALL)
end

-- The same sequence of numbers every time, so the city never changes.
local seed = 118
local function random()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

-- The ground of the city, and the tower this floor is the top of.
scenery("Streets", 0, STREET - 2, 0, 2400, 4, 2400)
scenery("Glass2", 0, STREET + 74.5, -9, 110, 149, 80)
scenery("Concrete", 0, STREET + 10, -4, 150, 20, 104)

-- The district below the terrace. An avenue passes the foot of the tower; on
-- its far side a park runs south to a second avenue, with a road down each
-- side, and the twin towers stand at the end of it.
local AVENUE, FAR_AVENUE = 150, 395 -- the centre lines of the two avenues
local SIDE_ROAD = 100 -- the roads beside the park are at X -100 and 100
flat("Pavement", -130, -80, 130, 412, 0.2)
flat("Asphalt", -700, AVENUE - 17, 700, AVENUE + 17, 0.4)
flat("Asphalt", -700, FAR_AVENUE - 12, 700, FAR_AVENUE + 12, 0.4)
for _, side in { -1, 1 } do
	flat("Asphalt", side * SIDE_ROAD - 11, AVENUE + 17, side * SIDE_ROAD + 11, FAR_AVENUE - 12, 0.4)
	-- A planted strip down the middle of the avenue, broken at the junctions.
	flat("Lawn", if side < 0 then -700 else 116, AVENUE - 1, if side < 0 then -116 else 700, AVENUE + 1, 0.7)
end
flat("Lawn", -84, AVENUE - 1, 84, AVENUE + 1, 0.7)
-- A crossing from the tower's plaza to the park.
for step = 0, 10 do
	if step ~= 5 then
		flat("Line", -4, AVENUE - 15.2 + step * 2.9, 4, AVENUE - 13.8 + step * 2.9, 0.5)
	end
end

-- The park: lawn, two round lakes, and a path all the way round.
flat("Lawn", -84, 171, 84, 379, 0.3)
scenery("Lake", 14, STREET + 0.4, 290, 76, 0.2, 76, ROUND)
scenery("Lake", -24, STREET + 0.4, 246, 44, 0.2, 44, ROUND)
flat("Pavement", -65, 177, 65, 183, 0.5)
flat("Pavement", -65, 369, 65, 375, 0.5)
flat("Pavement", -65, 183, -59, 369, 0.5)
flat("Pavement", 59, 183, 65, 369, 0.5)
flat("Pavement", -3, 167, 3, 177, 0.5)

local treeCount = 0
local function plant(x, z, scale)
	treeCount += 1
	streetTree(x, z, scale, treeCount)
end
for step = 0, 8 do
	plant(-75, 184 + step * 23, 0.9 + (step % 3) * 0.12)
	plant(75, 190 + step * 23, 1 + (step % 2) * 0.15)
end
for _, at in {
	{ -42, 198 }, { -30, 214 }, { 40, 204 }, { 50, 222 }, { -46, 342 }, { -30, 354 },
	{ 34, 352 }, { 50, 340 }, { -48, 296 }, { -10, 356 }, { 0, 200 }, { 22, 196 },
} do
	plant(at[1], at[2], 0.85 + random() * 0.4)
end
for step = -10, 10 do
	if math.abs(step) > 0 then
		plant(step * 30, AVENUE - 21, 0.9 + random() * 0.25)
	end
end

-- Lower buildings either side of the park and the plaza, tallest furthest out.
for _, side in { -1, 1 } do
	for column, x in { 172, 252 } do
		for _, z in { 20, 92, 216, 302 } do
			local width = 54 + random() * 14
			local depth = 52 + random() * 12
			local height = 22 + random() * 26 + column * 14
			local kind = ({ "Block1", "Block2", "Block3" })[1 + math.floor(random() * 3)]
			scenery(kind, side * x, STREET + height / 2, z, width, height, depth)
			-- Something on each roof: plant, or a garden.
			if random() < 0.5 then
				scenery("Block3", side * x + 8, STREET + height + 3, z - 6, width * 0.35, 6, depth * 0.3)
			else
				scenery("Lawn", side * x, STREET + height + 0.4, z, width * 0.7, 0.8, depth * 0.6)
			end
		end
	end
end

-- Seen from the terrace, looking south (+Z): east is to the left.
local landmarks = {
	{ build = twinTowers, x = 0, z = 440 },
	{ build = telecomTower, x = 220, z = 540 },
	{ build = spireTower, x = 430, z = 860 },
	{ build = financeTower, x = -420, z = 800 },
}
for _, landmark in landmarks do
	landmark.build(landmark.x, landmark.z)
end

-- Ordinary blocks in a ring around all of that, taller towards the centre of
-- the view, and kept off the avenues and clear of the landmarks.
for _ = 1, 280 do
	local angle = random() * math.pi * 2
	local distance = 380 + random() * 520
	local x, z = math.sin(angle) * distance, math.cos(angle) * distance
	local width = 26 + random() * 34
	local height = 45 + random() * 85 + (if z > 300 then random() * 40 else 0)
	local kind = ({ "Block1", "Block2", "Block3" })[1 + math.floor(random() * 3)]
	local depth = width * (0.6 + random() * 0.7)
	local yaw = math.floor(random() * 4) * 15

	local clear = math.abs(z - AVENUE) > 52 and math.abs(z - FAR_AVENUE) > 48
	if z > 100 and z < 420 and math.abs(x) < 130 then
		clear = false -- the park
	end
	for _, landmark in landmarks do
		-- Nothing right beside a landmark, and nothing standing in front of it.
		local beside = math.abs(x - landmark.x) < 110 and math.abs(z - landmark.z) < 110
		local inFront = z > 0 and z < landmark.z and math.abs(x - landmark.x * z / landmark.z) < 55
		if beside or inFront then
			clear = false
		end
	end
	if clear then
		scenery(kind, x, STREET + height / 2, z, width, height, depth, { yaw = yaw })
	end
end

-- Traffic -------------------------------------------------------------------
-- Each route is a line of { x, z } points that vehicles follow at one speed,
-- evenly spread. `loop` routes join back to their start; the others run off
-- into the haze and come round again. They drive on the left, as in Malaysia:
-- heading east you keep to the north side of the road.
local ROAD = STREET + 0.4
local traffic = {
	-- Straight through on the avenue, in its two middle lanes.
	{ kinds = { "Car", "Car", "Van", "Car", "Bus", "Car" }, speed = 40, count = 7, y = ROAD, path = { { -560, AVENUE - 4.5 }, { 560, AVENUE - 4.5 } } },
	{ kinds = { "Car", "Van", "Car", "Car", "Car", "Bus" }, speed = 44, count = 7, y = ROAD, path = { { 560, AVENUE + 4.5 }, { -560, AVENUE + 4.5 } } },
	-- Round the park, one way in the lanes nearest it and the other way outside.
	{
		kinds = { "Car", "Car", "Van" }, speed = 30, count = 6, y = ROAD, loop = true,
		path = { { -95, AVENUE + 12 }, { -95, FAR_AVENUE - 6 }, { 95, FAR_AVENUE - 6 }, { 95, AVENUE + 12 } },
	},
	{
		kinds = { "Car", "Car", "Car", "Van" }, speed = 32, count = 6, y = ROAD, loop = true,
		path = { { -105, FAR_AVENUE + 6 }, { -105, AVENUE - 12 }, { 105, AVENUE - 12 }, { 105, FAR_AVENUE + 6 } },
	},
	-- Cyclists on the park path, both ways.
	{ kinds = { "Bicycle" }, speed = 13, count = 4, y = STREET + 0.5, loop = true, path = { { -63.5, 178.5 }, { 63.5, 178.5 }, { 63.5, 373.5 }, { -63.5, 373.5 } } },
	{ kinds = { "Bicycle" }, speed = 11, count = 3, y = STREET + 0.5, loop = true, path = { { -60.5, 370.5 }, { 60.5, 370.5 }, { 60.5, 181.5 }, { -60.5, 181.5 } } },
}

return {
	name = "Penthouse",
	teams = {},
	spawns = {},

	-- Where players appear, and what they can walk up to. Built by the lobby
	-- server, not by MapBuilder.
	arrival = { -46, 3, 0 },
	stations = {
		{ name = "Armoury", title = "ARMOURY", action = "Loadout and shop", pos = { 0, -30 }, facing = 180 },
		{ name = "Play", title = "FIND A MATCH", action = "Choose a mode", pos = { 42, 0 }, facing = 90 },
		{ name = "Profile", title = "PROFILE", action = "View profile", pos = { -18, 12 }, facing = 0 },
		{ name = "Squad", title = "SQUAD", action = "Team up", pos = { 38, 10 }, facing = 0 },
	},
	-- Where a weapon lies on the armoury racks: the lobby server puts one on each.
	displays = displays,

	lighting = {
		clockTime = 15.5,
		brightness = 3,
		ambient = { 150, 152, 160 },
		outdoorAmbient = { 178, 184, 194 },
		fogColor = { 205, 220, 240 },
		fogEnd = 3000,
		latitude = 3, -- Kuala Lumpur: the sun passes almost overhead
		environment = 1,
	},

	-- Afternoon haze over the city. Thick enough that the far towers wash out
	-- and the near ones do not, so the skyline has depth; the room itself is
	-- too close to be touched by it. `density` is the one number to turn.
	atmosphere = {
		density = 0.34,
		offset = 0.25,
		color = { 206, 218, 232 },
		decay = { 112, 124, 142 },
		glare = 0.25,
		haze = 2,
	},

	-- A soft glow round the lights, and a slightly warm, slightly richer picture.
	finish = {
		bloom = { intensity = 0.55, size = 26, threshold = 1.3 },
		grade = { contrast = 0.06, saturation = 0.08, tint = { 255, 250, 243 } },
		sunRays = { intensity = 0.06, spread = 0.7 },
	},

	styles = {
		-- The room
		Floor = { color = { 236, 234, 228 }, material = "Marble" },
		Stone = { color = { 52, 53, 58 }, material = "Granite" },
		Brass = { color = { 208, 166, 62 }, material = "Metal", reflectance = 0.25 },
		Deck = { color = { 150, 122, 92 }, material = "WoodPlanks" },
		Ceiling = { color = { 244, 244, 240 }, material = "Plaster" },
		Wall = { color = { 238, 236, 230 }, material = "Plaster" },
		Timber = { color = { 88, 62, 44 }, material = "Wood" },
		Slat = { color = { 122, 90, 62 }, material = "Wood" },
		Column = { color = { 226, 224, 218 }, material = "Concrete" },
		Frame = { color = { 34, 36, 42 }, material = "Metal" },
		Door = { color = { 168, 174, 182 }, material = "Metal", reflectance = 0.2 },
		Glass = { color = { 190, 220, 240 }, material = "Glass", transparency = 0.75, reflectance = 0.1 },
		Glow = { color = { 255, 196, 30 }, material = "Neon" },
		Light = { color = { 255, 232, 196 }, material = "Neon" },
		Seat = { color = { 50, 52, 60 }, material = "Leather" },
		Cushion = { color = { 74, 78, 90 }, material = "Fabric" },
		Rug = { color = { 98, 100, 110 }, material = "Carpet" },
		Rack = { color = { 30, 32, 38 }, material = "Metal" },
		BottleAmber = { color = { 190, 120, 40 }, material = "Glass", transparency = 0.25 },
		BottleGreen = { color = { 60, 120, 80 }, material = "Glass", transparency = 0.25 },
		BottleClear = { color = { 220, 230, 235 }, material = "Glass", transparency = 0.45 },
		-- Planting
		Planter = { color = { 168, 168, 164 }, material = "Concrete" },
		Soil = { color = { 70, 56, 44 }, material = "Ground" },
		Trunk = { color = { 104, 82, 60 }, material = "Wood" },
		Leaf = { color = { 62, 126, 64 }, material = "LeafyGrass" },
		Leaf2 = { color = { 92, 148, 72 }, material = "LeafyGrass" },
		Water = { color = { 70, 150, 200 }, material = "Glass", transparency = 0.35 },

		-- The city. Pale, so the haze takes it.
		Steel = { color = { 196, 204, 214 }, material = "Metal" },
		Concrete = { color = { 222, 222, 218 }, material = "Concrete" },
		Glass2 = { color = { 120, 160, 186 }, material = "SmoothPlastic", reflectance = 0.15 },
		Pod = { color = { 236, 214, 150 }, material = "SmoothPlastic" },
		Spire = { color = { 230, 232, 236 }, material = "Metal" },
		Hill = { color = { 86, 128, 82 }, material = "Grass" },
		Block1 = { color = { 176, 184, 194 }, material = "SmoothPlastic" },
		Block2 = { color = { 150, 164, 180 }, material = "SmoothPlastic" },
		Block3 = { color = { 204, 204, 200 }, material = "Concrete" },
		Streets = { color = { 132, 146, 138 }, material = "Concrete" },
		Asphalt = { color = { 56, 58, 62 }, material = "Asphalt" },
		Pavement = { color = { 176, 174, 166 }, material = "Pavement" },
		Line = { color = { 236, 236, 228 }, material = "SmoothPlastic" },
		Lawn = { color = { 98, 150, 86 }, material = "Grass" },
		Lake = { color = { 84, 150, 188 }, material = "SmoothPlastic", reflectance = 0.3 },
	},

	bounds = { pos = { 0, 20, 0 }, size = { 130, 80, 100 } },

	boxes = boxes,
	ramps = {},

	-- Invisible walls. The room is closed by its own walls and glass; the
	-- terrace is open to the sky, so it gets a box of its own: three sides, a
	-- lid above the trees, and the line of the roof so nobody climbs onto it.
	barriers = {
		{ pos = { 0, 13.5, 41.2 }, size = { 116, 27, 1 } },
		{ pos = { -56.4, 13.5, 31.5 }, size = { 1, 27, 20.4 } },
		{ pos = { 56.4, 13.5, 31.5 }, size = { 1, 27, 20.4 } },
		{ pos = { 0, 26.5, 31.5 }, size = { 116, 1, 20.4 } },
		{ pos = { 0, 21, 22.2 }, size = { 116, 11, 1 } },
	},

	-- Scenery only: built without collision, and ignored by the map tools' checks.
	backdrop = city,
	traffic = traffic,

	lamps = lamps,
}
