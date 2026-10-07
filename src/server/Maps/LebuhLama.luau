-- Lebuh Lama ("Old Street"): a two-site map in an invented Malaysian heritage
-- quarter at dusk. A covered market street in the manner of Kuala Lumpur's
-- Chinatown, George Town style shophouses and back lanes around it, and an old
-- colonial savings bank in the middle. No real street, shop or bank is copied
-- or named.
--
-- Not mirrored. X runs west to east, Z north to south. Attackers (Alpha) spawn
-- in a lorry yard in the north-west; defenders (Bravo) in the bank's rear
-- compound in the south-east. Site A is a car park that doubles as a hawker
-- lot, in the north-east. Site B is the bank's vault.
--
-- Attackers leave their yard four ways:
--   1. north: the top lane, North Lane, North Street, through the godown
--      (a market storehouse) and into A
--   2. middle: North Lane, through the kopitiam (a coffee shop built round an
--      open air-well), then down the middle lane to the market, or out of its
--      side door and along the back lane to Pasar Lane and A's south gate
--   3. main: West Street down to the market, then the bank's front door
--   4. west: Back Lane, then either through to West Street and the Square, or
--      up the stairs to the verandah, a first-floor perch over the Square.
--      From the Square the bank has two west doors, the second round the
--      back by the south-west lane.
--
-- Defenders leave theirs three ways:
--   1. west through the bank's east wing to the hall and the vault
--   2. north through the bank yard, across the market, up Pasar Lane to A
--   3. west along the market to meet attackers at the bank front
--
-- The structure is carved (see `fill`): everything that is not a street, a
-- lane or a room is solid shophouse. Shop fronts, shutters, roofs, lanterns
-- and signs are decoration hung on those solids, and stop nobody and no shot.
-- What is cover is real: stalls, vehicles, piers, counters, pillars.
--
-- pos is the centre of a box, size its full extents, all in studs.

local WARM = { 255, 196, 130 }
local LANTERN = { 255, 120, 70 }
local COOL = { 214, 228, 255 }

local boxes, ramps, lamps, signboards, doors = {}, {}, {}, {}, {}

local function put(kind, x, y, z, sx, sy, sz, extra)
	local box = { kind = kind, pos = { x, y, z }, size = { sx, sy, sz } }
	for key, value in extra or {} do
		box[key] = value
	end
	table.insert(boxes, box)
	return box
end

-- For a box that stands in the open (a column, a post, a rack), so that
-- tools/maps/walls.py does not read the space round it as a doorway.
local FREE = { freestanding = true }

-- Decoration: seen, and nothing else.
local function trim(kind, x, y, z, sx, sy, sz, extra)
	local box = put(kind, x, y, z, sx, sy, sz, extra)
	box.decor = true
	return box
end

-- A box by its corners.
local function slab(kind, x1, z1, x2, z2, y1, y2, extra)
	return put(kind, (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2, x2 - x1, y2 - y1, z2 - z1, extra)
end

-- A lamp's brightness is written as it reads against the others, then scaled
-- down as a whole: at full strength the pale walls burn out.
local LAMP_STRENGTH = 0.38

local function light(x, y, z, range, brightness, colour)
	table.insert(lamps, {
		pos = { x, y, z },
		color = colour or WARM,
		range = range,
		brightness = brightness * LAMP_STRENGTH,
		bare = true,
	})
end

-- Board and ink for a signboard.
local SCHEMES = {
	red = { { 142, 30, 28 }, { 244, 206, 96 } },
	green = { { 30, 78, 56 }, { 240, 232, 214 } },
	black = { { 28, 26, 26 }, { 236, 196, 88 } },
	white = { { 236, 230, 214 }, { 150, 34, 30 } },
	blue = { { 34, 64, 120 }, { 240, 236, 226 } },
	yellow = { { 232, 190, 64 }, { 36, 30, 26 } },
	stone = { { 208, 198, 178 }, { 54, 46, 40 } },
}

local function board(x, y, z, yaw, width, height, text, scheme, lit)
	local colours = SCHEMES[scheme]
	table.insert(signboards, {
		pos = { x, y, z },
		size = { width, height },
		yaw = yaw,
		text = text,
		color = colours[1],
		ink = colours[2],
		lit = lit or nil,
	})
end

-- A wall with openings in it. `axis` is the way it runs: "X" for a wall across
-- the map at z = `at`, "Z" for one down the map at x = `at`. `gaps` are
-- { from, to, note } in order along it; one with a note is a doorway the
-- design promises, and is listed for tools/maps/walls.py to check.
local function wall(kind, axis, at, from, to, gaps, o)
	o = o or {}
	local thick, height, doorHeight = o.thick or 2, o.height or 24, o.door or 9
	local function piece(a, b, y1, y2)
		if b - a <= 0 or y2 - y1 <= 0 then
			return
		end
		if axis == "X" then
			slab(kind, a, at - thick / 2, b, at + thick / 2, y1, y2)
		else
			slab(kind, at - thick / 2, a, at + thick / 2, b, y1, y2)
		end
	end
	local cursor = from
	for _, gap in gaps or {} do
		piece(cursor, gap[1], 0, height)
		if not o.open then
			piece(gap[1], gap[2], doorHeight, height) -- over the door
		end
		if gap[3] then
			local middle = (gap[1] + gap[2]) / 2
			if axis == "X" then
				table.insert(doors, { middle, at, gap[2] - gap[1], gap[3] })
			else
				table.insert(doors, { at, middle, gap[2] - gap[1], gap[3] })
			end
		end
		cursor = gap[2]
	end
	piece(cursor, to, 0, height)
end

-- Things that hang on a wall --------------------------------------------------
--
-- A wall faces north, south, east or west. A piece is placed by how far along
-- the wall it is (`u`) and how far out from it (`out`), so one description of
-- a shop front serves all four ways. `yaw` turns a wedge so that its tall side
-- is against the wall, and a signboard so that its writing faces away from it.

local FACES = {
	N = { nx = 0, nz = -1, yaw = 0 },
	S = { nx = 0, nz = 1, yaw = 180 },
	E = { nx = 1, nz = 0, yaw = -90 },
	W = { nx = -1, nz = 0, yaw = 90 },
}

local function onWall(face, at, u, out)
	local f = FACES[face]
	if f.nx == 0 then
		return u, at + f.nz * out
	end
	return at + f.nx * out, u
end

-- `along` is the piece's size along the wall, `deep` its size out from it.
local function hung(fn, kind, face, at, u, y, out, along, height, deep, extra)
	local x, z = onWall(face, at, u, out)
	if FACES[face].nx == 0 then
		return fn(kind, x, y, z, along, height, deep, extra)
	end
	return fn(kind, x, y, z, deep, height, along, extra)
end

-- A wedge with its tall side to the wall: a roof slope, or an awning.
local function slope(kind, face, at, u, y, out, along, height, deep)
	local x, z = onWall(face, at, u, out)
	return trim(kind, x, y, z, along, height, deep, { shape = "Wedge", yaw = FACES[face].yaw })
end

local function hungBoard(face, at, u, y, out, width, height, text, scheme, lit)
	local x, z = onWall(face, at, u, out)
	board(x, y, z, FACES[face].yaw, width, height, text, scheme, lit)
end

-- Shophouse fronts --------------------------------------------------------------

local WALLS = { "Cream", "Butter", "Mint", "Rose", "Sky", "Chalk" }
local SHUTTERS = { "Teal", "Forest", "Umber", "Slate", "Oxblood" }
local AWNINGS = { "AwningRed", "AwningGreen", "AwningBlue", "AwningYellow" }
local STOCK = { "FruitOrange", "Sack", "FruitRed", "Sky", "Gold", "FruitGreen", "Chalk", "Rose" } -- what is on a shop's shelves
local SHOPS = {
	{ "KEDAI KOPI", "茶\n室", "open", "red" },
	{ "KEDAI EMAS", "金\n鋪", "roller", "black" },
	{ "KEDAI UBAT", "藥\n行", "timber", "green" },
	{ "KEDAI KAIN", "布\n莊", "open", "blue" },
	{ "TUKANG JAHIT", "洋\n服", "timber", "white" },
	{ "KEDAI JAM", "鐘\n錶", "roller", "yellow" },
	{ "KEDAI BUKU", "書\n局", "open", "green" },
	{ "KEDAI RUNCIT", "雜\n貨", "open", "red" },
	{ "RUMAH TUMPANGAN", "旅\n社", "timber", "black" },
	{ "KEDAI GAMBAR", "相\n館", "roller", "blue" },
	{ "BENGKEL BASIKAL", "腳\n車", "open", "yellow" },
	{ "KEDAI TEH", "茶\n莊", "timber", "red" },
	{ "PAJAK GADAI", "當", "roller", "white" },
	{ "KEDAI MAKAN", "飯\n店", "open", "green" },
	{ "KEDAI KASUT", "鞋\n店", "roller", "black" },
	{ "KEDAI GUNTING", "理\n髮", "open", "blue" },
	{ "KEDAI BUNGA", "花\n店", "timber", "white" },
	{ "KEDAI ROTI", "餅\n家", "open", "yellow" },
}

-- Every front is different, but the same every time the map is built: the
-- choices step through the lists above at different paces.
local fronts = 0

local function nextLook()
	fronts += 1
	local shop = SHOPS[(fronts * 7) % #SHOPS + 1]
	return {
		wall = WALLS[(fronts * 5) % #WALLS + 1],
		shutter = SHUTTERS[(fronts * 3) % #SHUTTERS + 1],
		awning = if fronts % 3 == 0 then AWNINGS[(fronts * 3) % #AWNINGS + 1] else nil,
		name = shop[1],
		mark = if fronts % 2 == 0 then shop[2] else nil, -- the trade in Chinese, on a hanging board
		shop = shop[3],
		scheme = shop[4],
		lit = fronts % 5 ~= 0, -- somebody is home upstairs
		litSign = fronts % 4 == 1,
	}
end

-- One upstairs window, 3.6 wide and 7 tall: lit from inside with its shutters
-- folded back, or dark with them closed.
local function window(face, at, u, y, out, look, lit)
	hung(trim, "Trim", face, at, u, y, out + 0.12, 3.6, 7, 0.24)
	hung(trim, "Trim", face, at, u, y - 3.7, out + 0.35, 4.2, 0.4, 0.7) -- sill
	if lit then
		hung(trim, "WindowGlow", face, at, u, y, out + 0.3, 2.8, 6.2, 0.16)
		for _, side in { -1, 1 } do
			hung(trim, look.shutter, face, at, u + side * 2.5, y, out + 0.2, 1.3, 6.4, 0.2)
		end
	else
		for _, side in { -1, 1 } do
			hung(trim, look.shutter, face, at, u + side * 0.72, y, out + 0.32, 1.36, 6.2, 0.2)
		end
	end
end

-- The upper storey and roof of one front, `width` wide and centred at `u`.
-- `out` moves the whole of it off the wall, for a storey that overhangs.
local function upstairs(face, at, u, width, look, out)
	out = out or 0
	hung(trim, look.wall, face, at, u, 17.4, out + 0.1, width - 1.6, 11.4, 0.2)
	for _, side in { -1, 1 } do
		hung(trim, "Trim", face, at, u + side * (width / 2 - 0.4), 17.6, out + 0.3, 0.8, 12.8, 0.6) -- pilaster
	end
	hung(trim, "Trim", face, at, u, 11.5, out + 0.4, width, 0.7, 0.8) -- string course
	hung(trim, "Trim", face, at, u, 23.5, out + 0.5, width, 1, 1) -- cornice
	local count = if width >= 17 then 3 elseif width >= 11 then 2 else 1
	local pitch = (width - 2) / count
	for index = 1, count do
		local lit = look.lit and (index + fronts) % 2 == 0
		window(face, at, u - (width - 2) / 2 + (index - 0.5) * pitch, 17, out + 0.2, look, lit)
	end
	slope("RoofTile", face, at, u, 26.6, out - 3.4, width, 5.2, 9)
end

-- The ground floor of one front: the shop, and the board with its name.
local function shopfront(face, at, u, width, look)
	local span = width - 2.4
	for _, side in { -1, 1 } do
		hung(trim, "Trim", face, at, u + side * (width / 2 - 0.5), 5.6, 0.25, 1, 11.2, 0.5)
	end
	if look.shop == "roller" then
		hung(trim, "RollerShutter", face, at, u, 4.3, 0.12, span, 8.6, 0.24)
		hung(trim, "Steel", face, at, u, 8.9, 0.3, span, 0.6, 0.6)
		hung(trim, "Steel", face, at, u, 0.3, 0.2, span, 0.6, 0.4)
	elseif look.shop == "timber" then
		local leaf = span / 4
		for index = 1, 4 do
			local kind = if index % 2 == 0 then "Timber" else "DarkTimber"
			hung(trim, kind, face, at, u - span / 2 + (index - 0.5) * leaf, 4.3, 0.14, leaf - 0.12, 8.6, 0.28)
		end
		hung(trim, "DarkTimber", face, at, u, 8.9, 0.2, span, 0.6, 0.4)
	else
		-- Open and lit: the inside of the shop, warm under its tube light, with
		-- the counter in front and stock on the shelves behind.
		hung(trim, "ShopGlow", face, at, u, 4.3, 0.08, span, 8.6, 0.16)
		for _, side in { -1, 1 } do
			hung(trim, "DarkTimber", face, at, u + side * (span / 2 - 0.25), 4.3, 0.2, 0.5, 8.6, 0.4)
		end
		hung(trim, "DarkTimber", face, at, u, 8.75, 0.2, span, 0.5, 0.4)
		hung(trim, "LampGlow", face, at, u, 7.9, 0.22, span * 0.6, 0.22, 0.14)
		hung(trim, "CounterWood", face, at, u - span * 0.16, 1.6, 0.4, span * 0.5, 3.2, 0.6)
		hung(trim, "MarbleTop", face, at, u - span * 0.16, 3.25, 0.42, span * 0.52, 0.14, 0.7)
		for index, shelf in { 4.9, 6.3 } do
			hung(trim, "DarkTimber", face, at, u, shelf, 0.22, span - 1.4, 0.2, 0.3)
			for item = 0, 3 do
				local kind = STOCK[(index * 3 + item + fronts) % #STOCK + 1]
				local wide = 1 + ((item + index + fronts) % 3) * 0.5
				hung(trim, kind, face, at, u - (span - 3) / 2 + item * (span - 3) / 3, shelf + 0.55, 0.24, wide, 0.9, 0.2)
			end
		end
	end
end

-- One whole shophouse front on a solid wall, with its strip of pavement.
-- Pavements on walls that face north or south sit a hair higher than the
-- others, so that where two meet in a corner neither flickers through.
local function front(face, at, u, width, look)
	local lift = if FACES[face].nx == 0 then 0.12 else 0.1
	hung(put, "Pave", face, at, u, lift / 2, 2.2, width, lift, 4.4)
	shopfront(face, at, u, width, look)
	upstairs(face, at, u, width, look)
	hungBoard(face, at, u, 10.25, 0.75, width - 3.4, 1.7, look.name, look.scheme, look.litSign)
	if look.awning then
		slope(look.awning, face, at, u, 8.7, 2.3, width - 2.6, 1.1, 3.8)
		hung(trim, "AwningWhite", face, at, u, 8.0, 4.15, width - 2.6, 0.5, 0.1)
	end
	if look.mark then
		hungBoard(face, at, u + width / 2 - 0.5, 6, 0.66, 1.5, 5.4, look.mark, look.scheme, look.litSign)
	end
end

-- A front with a five-foot way: the upper storey comes out over the pavement
-- on piers, and people walk underneath, past the shop. The piers are cover.
local ARCADE = 5.8

local function arcadeFront(face, at, u, width, look)
	shopfront(face, at, u, width, look)
	hung(put, "Chalk", face, at, u, 17.9, ARCADE / 2, width, 12.2, ARCADE) -- the storey overhead
	hung(trim, "Trim", face, at, u, 11.2, ARCADE - 0.7, width, 1.2, 1.4) -- beam on the piers
	upstairs(face, at, u, width, look, ARCADE)
	hungBoard(face, at, u, 11.2, ARCADE + 0.2, width - 4, 1.7, look.name, look.scheme, look.litSign)
	if look.mark then
		hungBoard(face, at, u + width / 2 - 2.6, 7.6, 0.66, 1.5, 5, look.mark, look.scheme, look.litSign)
	end
	hung(put, "Pave", face, at, u, 0.06, ARCADE / 2, width, 0.12, ARCADE)
end

local function pier(face, at, u)
	hung(put, "Trim", face, at, u, 5.3, ARCADE - 0.8, 1.6, 10.6, 1.6, FREE)
	hung(trim, "Trim", face, at, u, 0.5, ARCADE - 0.8, 2, 1, 2)
end

-- The back of a shophouse: a door, a pipe, an air conditioner, small windows.
local function backFront(face, at, u, width, look)
	hung(trim, "Timber", face, at, u - width * 0.22, 4, 0.12, 3.6, 8, 0.24)
	hung(trim, "Trim", face, at, u - width * 0.22, 8.2, 0.2, 4.2, 0.4, 0.4)
	hung(trim, "Pipe", face, at, u + width / 2 - 1, 12, 0.35, 0.5, 24, 0.5)
	hung(trim, "AirCon", face, at, u + width * 0.2, 14.4, 0.7, 3, 2, 1.4)
	hung(trim, "Steel", face, at, u + width * 0.2, 13.2, 0.6, 3.4, 0.2, 1.2)
	hung(trim, "Trim", face, at, u, 23.5, 0.4, width, 1, 0.8)
	local lit = look.lit
	hung(trim, "Trim", face, at, u - width * 0.2, 17.5, 0.12, 3, 4, 0.24)
	hung(trim, if lit then "WindowGlow" else look.shutter, face, at, u - width * 0.2, 17.5, 0.26, 2.4, 3.4, 0.16)
	slope("RoofTile", face, at, u, 26.6, -3.4, width, 5.2, 9)
end

-- A run of fronts filling a wall from `from` to `to`.
local function row(face, at, from, to, count, style)
	local width = (to - from) / count
	for index = 1, count do
		local u = from + (index - 0.5) * width
		local look = nextLook()
		if style == "arcade" then
			arcadeFront(face, at, u, width, look)
			pier(face, at, from + (index - 1) * width + 0.8)
		elseif style == "back" then
			backFront(face, at, u, width, look)
		elseif style == "upstairs" then
			upstairs(face, at, u, width, look)
		else
			front(face, at, u, width, look)
		end
	end
	if style == "arcade" then
		pier(face, at, to - 0.8)
	end
end

-- A frame round a doorway in a wall.
local function doorFrame(face, at, from, to, height)
	for _, u in { from - 0.4, to + 0.4 } do
		hung(trim, "Trim", face, at, u, height / 2, 0.2, 0.8, height, 0.4)
	end
	hung(trim, "Trim", face, at, (from + to) / 2, height + 0.4, 0.25, to - from + 1.6, 0.8, 0.5)
end

-- Corrugated sheet over a wall, as round a yard.
local function zinc(face, at, from, to)
	hung(trim, "Zinc", face, at, (from + to) / 2, 7, 0.15, to - from, 14, 0.3)
	for u = from + 1, to - 1, 6 do
		hung(trim, "Steel", face, at, u, 7, 0.4, 0.5, 14, 0.3)
	end
	hung(trim, "Steel", face, at, (from + to) / 2, 14.2, 0.3, to - from, 0.4, 0.6)
end

-- Things that stand in the street -------------------------------------------------
--
-- Each is built round its own middle and turned as one. `yaw` is in degrees,
-- as a box's is. A stall's front, where its customers stand, is its own -Z:
-- yaw 0 faces north, 180 south, 90 west, -90 east.

local function group(x, z, yaw)
	local c, s = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
	local function place(dx, dz)
		return x + dx * c + dz * s, z - dx * s + dz * c
	end
	local function add(fn, kind, dx, y, dz, sx, sy, sz, extra)
		local px, pz = place(dx, dz)
		local box = fn(kind, px, y, pz, sx, sy, sz, extra)
		if yaw ~= 0 then
			box.yaw = (box.yaw or 0) + yaw
		end
		return box
	end
	return add, place
end

local function lantern(x, y, z)
	trim("Lantern", x, y, z, 1.7, 1.9, 1.7, { shape = "Ball" })
	trim("Gold", x, y + 0.95, z, 0.8, 0.3, 0.8, { shape = "Cylinder" })
	trim("Gold", x, y - 1.2, z, 0.16, 0.9, 0.16)
end

-- A wire with lanterns on it, and one real light for the lot.
local function lanternLine(x1, z1, x2, z2, y, count)
	local length = math.max(math.abs(x2 - x1), math.abs(z2 - z1))
	if x1 == x2 then
		trim("Wire", x1, y + 1.2, (z1 + z2) / 2, 0.08, 0.08, length)
	else
		trim("Wire", (x1 + x2) / 2, y + 1.2, z1, length, 0.08, 0.08)
	end
	for index = 1, count do
		local t = (index - 0.5) / count
		lantern(x1 + (x2 - x1) * t, y, z1 + (z2 - z1) * t)
	end
	light((x1 + x2) / 2, y - 1.5, (z1 + z2) / 2, 26, 0.9, LANTERN)
end

-- A hawker stall: a counter under a striped awning, with a board of hanging
-- goods behind it. From the front or back it hides a standing player; from
-- either end there is only the counter to crouch behind.
local function stall(x, z, yaw, awning, name, goods)
	local add, place = group(x, z, yaw)
	add(put, "CounterWood", 0, 1.75, 0, 8, 3.5, 3.2)
	add(put, "DarkTimber", 0, 3.75, 1.85, 8, 7.5, 0.5)
	for index = 0, 4 do
		add(trim, if index % 2 == 0 then goods else "Sack", -3 + index * 1.5, 6.2 - (index % 3) * 0.3, 1.5, 0.8, 1.4, 0.3)
	end
	add(trim, "SteelTop", 0, 3.57, 0, 8.3, 0.14, 3.5)
	for _, dx in { -3.95, 3.95 } do
		for _, dz in { -1.55, 1.55 } do
			add(trim, "Steel", dx, 4.4, dz, 0.24, 8.8, 0.24)
		end
	end
	add(trim, awning, 0, 9.3, 0, 9.4, 1, 5.4, { shape = "Wedge" })
	add(trim, "AwningWhite", 0, 8.55, -2.72, 9.4, 0.5, 0.1)
	-- What is for sale: a tray of it, and a pile.
	add(trim, "DarkTimber", -2.2, 3.85, 0.3, 3, 0.4, 2.2)
	for index, offset in { { -3, 0.2 }, { -2.2, -0.2 }, { -1.5, 0.5 }, { -2.4, 0.8 } } do
		add(trim, goods, offset[1], 4.45 + (index % 2) * 0.1, offset[2], 0.9, 0.9, 0.9, { shape = "Ball" })
	end
	add(trim, "SteelTop", 2.2, 4.2, 0, 1.8, 1.1, 1.8, { shape = "Cylinder" })
	add(trim, "Timber", 0.2, 4, 0.4, 1.2, 0.7, 1.6)
	local bx, bz = place(0, -2.8)
	board(bx, 7.7, bz, yaw, 6, 1.2, name, "yellow", true)
	-- Two stools behind, for whoever runs it.
	for _, dx in { -1.5, 1.8 } do
		add(put, "StoolRed", dx, 0.7, 3.2, 1.1, 1.4, 1.1, { shape = "Cylinder" })
	end
	local lx, lz = place(0, 0)
	light(lx, 7.6, lz, 16, 0.8)
end

-- A drinks kiosk: taller than a player, with a serving hatch.
local function kiosk(x, z, yaw, paint, name)
	local add, place = group(x, z, yaw)
	add(put, paint, 0, 3.75, 0, 6, 7.5, 5)
	add(trim, "Trim", 0, 7.8, 0, 7.2, 0.5, 6.4)
	add(trim, "ShopGlow", 0, 4.6, -2.52, 4, 2.6, 0.1)
	add(trim, "SteelTop", 0, 3.2, -2.8, 4.6, 0.2, 0.9)
	add(trim, "DarkTimber", 0, 1.5, -2.52, 5.2, 3, 0.1)
	local bx, bz = place(0, -3.3)
	board(bx, 7.0, bz, yaw, 5.4, 1.1, name, "red", true)
	local lx, lz = place(0, -4)
	light(lx, 6, lz, 14, 0.8)
end

local function wheels(add, positions, radius, halfWidth)
	for _, dx in positions do
		for _, dz in { -halfWidth, halfWidth } do
			add(trim, "Tyre", dx, radius, dz, radius * 2, radius * 2, 0.9, { shape = "Cylinder", axis = "Z" })
			add(trim, "Steel", dx, radius, dz + (if dz > 0 then 0.42 else -0.42), radius, radius, 0.1, { shape = "Cylinder", axis = "Z" })
		end
	end
end

-- A saloon car, its nose towards its own +X. The body is cover to crouch
-- behind and the cabin just hides a standing player.
local function car(x, z, yaw, paint)
	local add = group(x, z, yaw)
	add(put, paint, 0, 2.3, 0, 13, 2.6, 5.6)
	add(put, paint, -0.8, 4.7, 0, 6.8, 2.2, 5.2)
	add(trim, "CarGlass", -0.8, 4.75, 0, 5.8, 1.5, 5.32)
	add(trim, "CarGlass", -0.8, 4.75, 0, 6.92, 1.5, 4.5)
	add(trim, "Steel", 6.55, 1.5, 0, 0.3, 0.6, 5.4)
	add(trim, "Steel", -6.55, 1.5, 0, 0.3, 0.6, 5.4)
	for _, dz in { -1.9, 1.9 } do
		add(trim, "Headlamp", 6.52, 2.7, dz, 0.12, 0.6, 1.1)
		add(trim, "TailLamp", -6.52, 2.7, dz, 0.12, 0.6, 1.1)
	end
	wheels(add, { -4, 4 }, 1.1, 2.5)
end

-- A box van, nose to +X. Hides a standing player along its whole length.
local function van(x, z, yaw, paint, band)
	local add = group(x, z, yaw)
	add(put, paint, -1.5, 4.3, 0, 12, 6.6, 6.4)
	add(put, paint, 6, 3.2, 0, 3, 4.4, 6.2)
	add(trim, "CarGlass", 6.4, 4.5, 0, 2.3, 1.6, 6.3)
	add(trim, "CarGlass", 7.52, 4.5, 0, 0.1, 1.6, 5.4)
	if band then
		add(trim, band, -1.5, 4.4, 0, 12.06, 1.2, 6.46)
	end
	add(trim, "Steel", 7.6, 1.5, 0, 0.3, 0.7, 6.2)
	add(trim, "Steel", -7.6, 1.5, 0, 0.3, 0.7, 6.2)
	for _, dz in { -2.2, 2.2 } do
		add(trim, "Headlamp", 7.52, 2.6, dz, 0.12, 0.6, 1.1)
		add(trim, "TailLamp", -7.52, 2.6, dz, 0.12, 0.8, 0.8)
	end
	wheels(add, { -5, 4.6 }, 1.2, 2.9)
end

-- A lorry with a canvas back, nose to +X.
local function lorry(x, z, yaw, paint)
	local add = group(x, z, yaw)
	add(put, paint, 7.4, 4.6, 0, 5.2, 6.8, 7.4)
	add(trim, "CarGlass", 9.6, 6, 0, 0.9, 2, 6.8)
	add(trim, "CarGlass", 8, 6, 0, 2.6, 2, 7.5)
	add(put, "DarkTimber", -3, 2.6, 0, 15.6, 1.2, 7.6)
	add(put, "Tarp", -3, 6.2, 0, 15.2, 6, 7.4)
	for dx = -9, 3, 3 do
		add(trim, "DarkTimber", dx, 6.2, 0, 0.3, 6.1, 7.5)
	end
	add(trim, "Steel", 10.1, 1.6, 0, 0.3, 0.8, 7.2)
	for _, dz in { -2.6, 2.6 } do
		add(trim, "Headlamp", 10.02, 3, dz, 0.12, 0.7, 1.2)
		add(trim, "TailLamp", -10.82, 2.6, dz, 0.12, 0.7, 0.9)
	end
	wheels(add, { -7.5, -3.5, 7 }, 1.4, 3.3)
end

-- A town minibus, nose to +X: the biggest thing in the street.
local function minibus(x, z, yaw)
	local add = group(x, z, yaw)
	add(put, "BusPink", 0, 4.8, 0, 22, 7.4, 7)
	add(trim, "AwningWhite", 0, 3.4, 0, 22.06, 0.8, 7.06)
	add(trim, "CarGlass", -0.6, 6.2, 0, 18, 2.2, 7.1)
	add(trim, "CarGlass", 10.4, 6, 0, 1.3, 2.6, 6.4)
	add(trim, "Chalk", 0, 8.6, 0, 20.6, 0.3, 6.2)
	add(trim, "Steel", 11.1, 1.6, 0, 0.3, 0.8, 6.8)
	add(trim, "Steel", -11.1, 1.6, 0, 0.3, 0.8, 6.8)
	for _, dz in { -2.5, 2.5 } do
		add(trim, "Headlamp", 11.02, 2.8, dz, 0.12, 0.8, 1.2)
		add(trim, "TailLamp", -11.02, 2.8, dz, 0.12, 0.8, 0.9)
	end
	wheels(add, { -7, 7 }, 1.3, 3.1)
end

-- A trishaw: a bicycle with a hooded seat for two. Cover to crouch behind.
local function trishaw(x, z, yaw, hood)
	local add = group(x, z, yaw)
	add(put, "Oxblood", 1.2, 2.1, 0, 3.4, 2.6, 3.4)
	add(trim, hood, 1, 4.9, 0, 3.6, 0.3, 3.8)
	add(trim, hood, -0.6, 4.1, 0, 0.3, 1.9, 3.8)
	add(trim, "Steel", -2.6, 2.2, 0, 2.8, 0.25, 0.25)
	add(trim, "DarkTimber", -3, 3.2, 0, 1.2, 0.3, 0.8)
	for _, spot in { { 1.2, -1.9 }, { 1.2, 1.9 }, { -3.8, 0 } } do
		add(trim, "Tyre", spot[1], 1.3, spot[2], 2.6, 2.6, 0.25, { shape = "Cylinder", axis = "Z" })
	end
end

local function drum(x, z, paint)
	put(paint, x, 1.75, z, 2.3, 3.5, 2.3, { shape = "Cylinder" })
	trim("Steel", x, 3.55, z, 2.4, 0.12, 2.4, { shape = "Cylinder" })
end

local function bin(x, z)
	put("BinGreen", x, 1.7, z, 2.2, 3.4, 2.2)
	trim("Steel", x, 3.5, z, 2.5, 0.25, 2.5)
end

-- A skip: long enough to hide two, tall enough to stand behind.
local function skip(x, z, yaw)
	local add = group(x, z, yaw)
	add(put, "SkipBlue", 0, 2.9, 0, 9, 5.8, 5)
	add(trim, "Steel", 0, 5.9, 0, 9.4, 0.3, 5.4)
	for _, dx in { -3, 0, 3 } do
		add(trim, "Steel", dx, 2.9, 0, 0.3, 5.6, 5.1)
	end
end

-- A round marble table and its stools.
local function tableSet(x, z, stools)
	put("DarkTimber", x, 1.3, z, 0.8, 2.6, 0.8, { shape = "Cylinder" })
	put("MarbleTop", x, 2.75, z, 3.4, 0.3, 3.4, { shape = "Cylinder" })
	for index = 1, stools do
		local angle = (index / stools) * math.pi * 2 + 0.4
		put("StoolRed", x + math.cos(angle) * 2.6, 0.7, z + math.sin(angle) * 2.6, 1.1, 1.4, 1.1, { shape = "Cylinder" })
	end
end

-- A sack pile to crouch behind.
local function sacks(x, z, yaw)
	local add = group(x, z, yaw)
	add(put, "Sack", 0, 1.1, 0, 7, 2.2, 4)
	add(put, "Sack", 0.3, 2.9, 0, 5.4, 1.4, 3.2)
	add(trim, "Sack", -0.4, 3.9, 0.2, 3, 0.8, 2.4)
end

local function lampPost(x, z, height)
	put("Steel", x, height / 2, z, 0.6, height, 0.6, FREE)
	trim("Steel", x, height + 0.1, z, 2.4, 0.3, 0.8)
	trim("LampGlow", x, height - 0.2, z, 1.6, 0.3, 0.6)
	light(x, height - 1.2, z, 34, 1.1)
end

-- ==============================================================================
-- The ground
-- ==============================================================================

put("Floor", 0, -0.5, 0, 280, 1, 208)

-- ==============================================================================
-- The attackers' lorry yard, and the top lane out of it
-- ==============================================================================

zinc("E", -134, -98, -70)
zinc("S", -98, -134, -98)
zinc("N", -70, -134, -112)
lorry(-123.5, -75, 0, "LorryBlue")
drum(-131.5, -81.5, "DrumBlue")
drum(-128.8, -81, "DrumRed")
drum(-100.5, -72.5, "DrumBlue")
put("Cover", -101.5, 2, -96, 6, 4, 4, { prop = "Crate" })
lampPost(-116, -97, 16)

row("S", -94, -98, -62, 2)
row("N", -78, -98, -82, 1, "back")
row("W", -62, -94, -78, 1, "back")
drum(-64.5, -92, "DrumRed")
drum(-67, -92.4, "DrumBlue")
put("Cover", -88, 2, -80.5, 6, 4, 4, { prop = "Crate" })
lanternLine(-80, -94, -80, -78, 15, 4)

-- ==============================================================================
-- West Street
-- ==============================================================================

row("E", -82, -78, -34, 3)
row("E", -82, -22, 22, 3)
row("W", -62, -52, -10, 3)
row("W", -62, -78, -70, 1, "back")
car(-76, -53, 90, "CarWhite")
stall(-66.4, -24, 0, "AwningGreen", "ROJAK", "FruitGreen")
put("Cover", -78.5, 3.5, -70, 6, 7, 6, { prop = "CrateStack" })
trishaw(-66, 9, 75, "AwningYellow")
lanternLine(-82, -30, -62, -30, 15, 5)
lanternLine(-82, -62, -62, -62, 15, 5)

-- The gate at the foot of the street, where it meets the market.
for _, x in { -80.4, -63.6 } do
	put("GateRed", x, 8, -8, 2.2, 16, 2.2, { shape = "Cylinder", freestanding = true })
	trim("Trim", x, 0.6, -8, 3, 1.2, 3)
	trim("Gold", x, 15.6, -8, 2.6, 0.8, 2.6)
end
trim("GateRed", -72, 17, -8, 20, 2, 1.6)
trim("Gold", -72, 15.8, -8, 19.4, 0.3, 1.8)
trim("RoofGreen", -72, 19.2, -9.6, 24, 2.4, 3.2, { shape = "Wedge", yaw = 0 })
trim("RoofGreen", -72, 19.2, -6.4, 24, 2.4, 3.2, { shape = "Wedge", yaw = 180 })
trim("Gold", -72, 20.6, -8, 24.6, 0.5, 0.6)
board(-72, 17, -8.9, 0, 12, 1.8, "LEBUH LAMA  老街", "red", true)
board(-72, 17, -7.1, 180, 12, 1.8, "LEBUH LAMA  老街", "red", true)
for _, x in { -78, -66 } do
	lantern(x, 13.4, -8)
end
light(-72, 12, -8, 24, 1, LANTERN)

-- ==============================================================================
-- Back Lane, the passage through, and the verandah
-- ==============================================================================

row("E", -112, -70, 40, 6, "back")
row("W", -98, -70, -34, 2, "back")
row("W", -98, -22, 16, 2, "back")
skip(-107, -46, 0) -- across the lane: the way past is the gap at its east end
bin(-99.6, -60)
bin(-99.6, -57.4)
put("Cover", -109.5, 2, 6, 4, 4, 6, { prop = "Crate", propTurn = true })
-- A spiral back stair, the kind every lane has: its drum is cover.
put("Steel", -100.5, 6.5, -8, 5, 13, 5, { shape = "Cylinder", freestanding = true })
for step = 0, 11 do
	local angle = step * 0.55
	trim("Steel", -100.5 + math.cos(angle) * 2.9, 1 + step, -8 + math.sin(angle) * 2.9, 1.6, 0.2, 1.6)
end
trim("Steel", -100.5, 13.2, -8, 6.4, 0.3, 6.4, { shape = "Cylinder" })
bin(-90, -23.4)
light(-105, 12, -40, 30, 0.7)
light(-105, 12, -4, 30, 0.7)
light(-90, 9, -28, 20, 0.7)

-- The verandah stands on its own solid, 10 up, at the head of the lane's stair.
slab("Chalk", -112, 40, -62, 56, 0, 10)
put("Boards", -87, 10.06, 48, 50, 0.12, 16)
put("Ceiling", -87, 22.5, 48, 50, 1, 16)
put("Chalk", -62.5, 22.5, 48, 1, 3, 16) -- head of the opening over the Square
put("Rail", -62.4, 11.75, 48, 0.8, 3.5, 14.4)
trim("Trim", -62.4, 13.6, 48, 1.2, 0.3, 14.8)
for _, z in { 40.6, 55.4 } do
	put("Trim", -62.4, 16, z, 1.2, 12, 1.2)
end
put("DarkTimber", -72, 13.75, 54.2, 6, 7.5, 2.4) -- a cupboard: the perch's one piece of cover
put("Cover", -90, 12, 42.5, 6, 4, 4, { prop = "Crate" })
-- Washing on poles over the Square.
for index, z in { 43, 48, 53 } do
	trim("DarkTimber", -59.6, 14.2, z, 5, 0.2, 0.2)
	trim(({ "Rose", "Sky", "Chalk" })[index], -59, 13.1, z, 2.2, 2, 0.1)
	trim(({ "Butter", "Chalk", "Mint" })[index], -57.6, 13.3, z, 1.2, 1.6, 0.1)
end
light(-80, 20, 48, 30, 0.8)
light(-66, 20, 48, 18, 0.6)
-- Under it, facing the Square, an ordinary shop.
shopfront("E", -62, 48, 16, nextLook())
hung(trim, "Trim", "E", -62, 48, 10.3, 0.5, 16, 0.6, 1)

-- ==============================================================================
-- North Lane and North Street
-- ==============================================================================

row("S", -70, -62, -26, 2)
row("N", -52, -62, -12, 3, "back")
put("Cover", -44, 3.5, -55.5, 6, 7, 6, { prop = "CrateStack" })
trishaw(-30, -66.4, 8, "AwningRed")
bin(-20, -53.6)
light(-40, 12, -61, 30, 0.7)

row("S", -92, -26, 34, 4)
row("E", -26, -92, -70, 1)
car(-6, -88, 0, "CarRed")
stall(21, -88.6, 180, "AwningRed", "NASI LEMAK", "FruitGreen")
lampPost(8, -90.6, 16)
lanternLine(-18, -92, -18, -70, 15, 5)
lanternLine(14, -92, 14, -70, 15, 5)

-- ==============================================================================
-- The kopitiam: a coffee shop round an open air-well
-- ==============================================================================

wall("KopiWall", "Z", -12, -70, -52, { { -66, -56, "kopitiam: west door from North Lane" } })
wall("KopiWall", "X", -70, -12, 24, { { 1, 11, "kopitiam: front door on North Street" } })
wall("KopiWall", "X", -36, -12, 2, { { -10, 0, "kopitiam: back door to the middle lane" } })
wall("KopiWall", "Z", 24, -70, -36, { { -52, -44, "kopitiam: side door to the back lane" } })
row("N", -71, -12, 24, 2, "upstairs")
row("W", -13, -70, -52, 1, "upstairs")
row("E", 25, -70, -36, 2, "upstairs")
row("S", -35, -12, 2, 1, "upstairs")
doorFrame("N", -71, 1, 11, 9)
doorFrame("W", -13, -66, -56, 9)
doorFrame("E", 25, -52, -44, 9)
doorFrame("S", -35, -10, 0, 9)
-- Its windows on the street: lit, behind timber bars.
for _, spot in { { "N", -71, -6 }, { "N", -71, 18 }, { "E", 25, -62 } } do
	local face, at, u = spot[1], spot[2], spot[3]
	hung(trim, "DarkTimber", face, at, u, 5, 0.1, 5.6, 6.4, 0.2)
	hung(trim, "ShopGlow", face, at, u, 5, 0.22, 4.8, 5.6, 0.1)
	for bar = -2, 2 do
		hung(trim, "DarkTimber", face, at, u + bar * 0.95, 5, 0.32, 0.22, 5.6, 0.12)
	end
end
board(6, 10.4, -71.4, 0, 14, 1.9, "KEDAI KOPI LEBUH LAMA", "green", true)
board(-13.4, 10.4, -61, 90, 8, 1.6, "KOPI  ·  TEH  ·  ROTI BAKAR", "white", true)

put("Tile", 6, 0.06, -53, 34, 0.12, 32)
trim("Cobble", 6, 0.14, -54, 12, 0.06, 12) -- the air-well's floor, open to the sky
-- Ceiling at 14 everywhere but the air-well, and the shaft above it.
slab("Ceiling", -11, -69, 23, -60, 14, 15)
slab("Ceiling", -11, -48, 23, -37, 14, 15)
slab("Ceiling", -11, -60, 0, -48, 14, 15)
slab("Ceiling", 12, -60, 23, -48, 14, 15)
slab("KopiWall", 0, -60.5, 12, -60, 15, 24)
slab("KopiWall", 0, -48, 12, -47.5, 15, 24)
slab("KopiWall", -0.5, -60, 0, -48, 15, 24)
slab("KopiWall", 12, -60, 12.5, -48, 15, 24)
for _, corner in { { 0, -60 }, { 12, -60 }, { 0, -48 }, { 12, -48 } } do
	put("Trim", corner[1], 7, corner[2], 1.6, 14, 1.6, FREE)
	trim("Trim", corner[1], 0.5, corner[2], 2.2, 1, 2.2)
end
-- The counter, with the shelves behind it.
put("CounterWood", 15, 2, -39.6, 14, 4, 2.8)
trim("MarbleTop", 15, 4.08, -39.6, 14.4, 0.16, 3.2)
for _, y in { 6, 8, 10 } do
	trim("DarkTimber", 15, y, -37.3, 14, 0.25, 1)
	for jar = 0, 5 do
		trim(if (jar + y) % 4 == 0 then "Gold" else "Sack", 9.5 + jar * 2.2, y + 0.65, -37.4, 0.9, 1, 0.9, { shape = "Cylinder" })
	end
end
put("DarkTimber", -8.4, 3.75, -44, 3.2, 7.5, 8) -- the crockery cupboard
trim("WindowGlow", -6.7, 5, -44, 0.12, 4.4, 6.4)
tableSet(18, -65, 3)
tableSet(-6, -49, 4)
tableSet(16.5, -57, 3)
tableSet(6, -54, 4)
put("PlantPot", 1.6, 1, -58.4, 2, 2, 2, { shape = "Cylinder" })
trim("Leaf", 1.6, 3.4, -58.4, 3.2, 3.2, 3.2, { shape = "Ball" })
put("PlantPot", 10.4, 1, -49.6, 2, 2, 2, { shape = "Cylinder" })
trim("Leaf", 10.4, 3.4, -49.6, 3.2, 3.2, 3.2, { shape = "Ball" })
-- Ceiling fans, and the light under each.
for _, spot in { { -5, -58 }, { 18, -56 }, { 6, -41.5 }, { 6, -65 } } do
	trim("DarkTimber", spot[1], 13.2, spot[2], 0.3, 1.6, 0.3)
	trim("DarkTimber", spot[1], 12.4, spot[2], 7, 0.12, 0.8)
	trim("DarkTimber", spot[1], 12.4, spot[2], 0.8, 0.12, 7)
	trim("LampGlow", spot[1], 11.9, spot[2], 0.9, 0.5, 0.9, { shape = "Ball" })
	light(spot[1], 11, spot[2], 24, 0.8)
end

-- ==============================================================================
-- The middle lane and the back lane
-- ==============================================================================

row("E", -12, -36, -10, 1, "back")
row("W", 2, -36, -10, 1, "back")
put("Cover", -8.8, 2, -22, 6, 4, 4, { prop = "Crate" })
bin(0.6, -31)
light(-5, 12, -23, 22, 0.7)

row("N", -36, 24, 68, 3, "back")
bin(40, -37.3)
bin(42.6, -37.3)
-- Stacked against the godown, so the lane cannot be seen down from end to end.
put("Cover", 53, 3.5, -43, 6, 7, 6, { prop = "CrateStack" })
put("Cover", 26.2, 2, -49, 4, 4, 6, { prop = "Crate", propTurn = true })
light(29, 12, -58, 22, 0.6)
light(48, 12, -41, 26, 0.6)

-- ==============================================================================
-- The godown: a market storehouse, the short way into A
-- ==============================================================================

wall("GodownWall", "Z", 34, -92, -46, { { -90, -78, "godown: west door on North Street" } }, { door = 10 })
wall("GodownWall", "Z", 68, -92, -46, {
	{ -72, -62, "godown: north door into the car park" },
	{ -58, -50, "godown: south door into the car park" },
}, { door = 10 })
wall("GodownWall", "X", -46, 34, 68)
slab("Ceiling", 35, -91, 67, -47, 16, 17)
doorFrame("W", 33, -90, -78, 10)
doorFrame("E", 69, -72, -62, 10)
doorFrame("E", 69, -58, -50, 10)
board(32.6, 13, -81, 90, 16, 2.6, "GUDANG PASAR", "stone")
for u = -74, -50, 8 do -- vents high on the lane side
	hung(trim, "DarkTimber", "W", 33, u, 19, 0.15, 4, 2, 0.3)
end
hung(trim, "Trim", "W", 33, -69, 23.5, 0.4, 46, 1, 0.8)
hung(trim, "Trim", "E", 69, -69, 23.5, 0.4, 46, 1, 0.8)
slope("Zinc", "W", 33, -69, 26, -3.4, 46, 4, 9)
slope("Zinc", "E", 69, -69, 26, -3.4, 46, 4, 9)
put("Concrete", 51, 0.06, -69, 32, 0.12, 44)
-- Racking, taller than a player, and sacks and crates to crouch behind.
for _, rack in { { 45.5, -66, 18 }, { 56.5, -85, 14 } } do
	put("DarkTimber", rack[1], 4.5, rack[2], 3, 9, rack[3], FREE)
	for _, y in { 3, 6, 9 } do
		trim("Steel", rack[1], y, rack[2], 3.3, 0.25, rack[3] + 0.3)
	end
	for index = 0, 2 do
		trim("Sack", rack[1], 9.8, rack[2] - rack[3] / 2 + 3 + index * (rack[3] - 6) / 2, 2.6, 1.3, 3.4)
	end
end
sacks(40.5, -58, 90)
sacks(62, -54.5, 0)
sacks(51, -50, 0)
put("Cover", 62.5, 3.5, -87, 6, 7, 6, { prop = "CrateStack" })
put("Cover", 41, 2.5, -71, 8, 5, 4, { prop = "PalletLoad" })
light(42, 14, -80, 30, 0.9)
light(60, 14, -66, 30, 0.9)
light(50, 14, -52, 24, 0.8)
for _, spot in { { 42, -80 }, { 60, -66 }, { 50, -52 } } do
	trim("Steel", spot[1], 15.2, spot[2], 0.2, 1.6, 0.2)
	trim("LampGlow", spot[1], 14.2, spot[2], 1.6, 0.4, 1.6, { shape = "Cylinder" })
end

-- ==============================================================================
-- The car park (site A) and Pasar Lane
-- ==============================================================================

row("S", -92, 68, 134, 4)
row("W", 134, -92, -48, 3)
row("N", -48, 104, 134, 2, "back")
wall("YardWall", "X", -48, 68, 104, { { 82, 98, "car park: the south gate" } }, { height = 12, open = true })
for _, x in { 81, 99 } do
	put("YardWall", x, 7, -48, 2.6, 14, 2.6, FREE)
	trim("Trim", x, 14.3, -48, 3.2, 0.6, 3.2)
	trim("LampGlow", x, 15.2, -48, 1.4, 1.4, 1.4, { shape = "Ball" })
	light(x, 15, -48, 22, 0.8)
end
trim("Trim", 74.5, 12.3, -48, 13, 0.6, 2.6)
board(74.5, 9.6, -46.9, 180, 10, 2, "TEMPAT LETAK KERETA", "blue")
board(74.5, 9.6, -49.1, 0, 10, 2, "MEDAN SELERA  ·  MALAM", "yellow", true)

-- Painted bays along the north side.
for x = 70, 96, 9.5 do
	trim("Paint", x, 0.03, -84.5, 0.4, 0.06, 14)
end
car(75, -84.5, 90, "CarSilver")
car(84.5, -84.5, 90, "CarBlue")
car(128.5, -83, -90, "CarWhite")
car(128, -66, 90, "CarBlack")
car(95.5, -63.5, 25, "CarRed")
van(116, -53.2, 180, "Chalk", "AwningGreen")
stall(101, -89.4, 180, "AwningYellow", "MEE GORENG", "FruitOrange")
stall(114, -89.4, 180, "AwningBlue", "AIS KACANG", "FruitRed")
put("Barrier", 109, 1.5, -77, 2, 3, 8) -- a concrete block, on the site
trim("PaintYellow", 109, 2.4, -77, 2.06, 0.6, 8.06)
tableSet(120, -76, 4)
-- The attendant's booth, by the gate.
put("Chalk", 77, 4, -52.6, 5, 8, 5)
trim("RoofGreen", 77, 8.3, -52.6, 6.4, 0.6, 6.4)
trim("WindowGlow", 77, 5, -55.14, 3, 2.4, 0.1)
lampPost(90, -70, 18)
lampPost(119, -64, 18)
lanternLine(100, -91, 122, -91, 13, 6)

row("E", 68, -36, -10, 2)
row("W", 104, -48, -10, 2)
kiosk(86, -27, 180, "Teal", "TEH TARIK")
stall(93.6, -31, 0, "AwningBlue", "ROTI CANAI", "FruitOrange")
stall(72.4, -21, -90, "AwningRed", "LAKSA", "FruitRed")
tableSet(97, -17, 4)
tableSet(78, -40, 3)
put("Cover", 101, 2, -44.6, 4, 4, 6, { prop = "Crate", propTurn = true })
lanternLine(68, -36, 104, -36, 15, 8)
lanternLine(68, -18, 104, -18, 15, 8)

-- ==============================================================================
-- Market Street
-- ==============================================================================

row("S", -10, -62, -12, 3, "arcade")
row("S", -10, 2, 48, 3)
row("W", 48, -10, 8, 1)
row("S", 8, 48, 66, 1)
row("E", 66, -10, 8, 1)
row("S", -10, 104, 128, 2)
row("N", 22, 104, 128, 2)
row("W", 128, -10, 22, 2)

-- The market's roof: green glass on steel, strung with lanterns. It rests on
-- the shophouses on the north side and on posts where the Square opens.
table.insert(ramps, { kind = "CanopyGlass", from = { -25, 27, -4.2 }, to = { -25, 31, 9 }, width = 70, thick = 0.3, decor = true })
table.insert(ramps, { kind = "CanopyGlass", from = { -25, 27, 22 }, to = { -25, 31, 9 }, width = 70, thick = 0.3, decor = true })
trim("Steel", -25, 31, 9, 70, 0.5, 0.5)
trim("Steel", -25, 26.6, 21.6, 70, 0.6, 0.6)
trim("Steel", -25, 26.6, -3.8, 70, 0.6, 0.6)
for x = -58, 8, 11 do
	table.insert(ramps, { kind = "Steel", from = { x, 26.9, -4.2 }, to = { x, 30.9, 9 }, width = 0.5, thick = 0.4, decor = true })
	table.insert(ramps, { kind = "Steel", from = { x, 26.9, 22 }, to = { x, 30.9, 9 }, width = 0.5, thick = 0.4, decor = true })
	trim("Steel", x, 26.6, 8.9, 0.3, 0.3, 25.6)
end
for _, x in { -58, -40, -22 } do
	put("Steel", x, 13.5, 21, 1.2, 27, 1.2, FREE)
	trim("Steel", x, 0.6, 21, 2, 1.2, 2)
end
for x = -52, 4, 14 do
	lanternLine(x, -3, x, 21, 21, 6)
end
lanternLine(-58, 9, 8, 9, 24, 9)

-- The stalls stand across the street, not along it, and no two in line: from
-- either end nobody sees the market's whole length.
stall(-48, 2, 90, "AwningRed", "DURIAN", "FruitGreen")
kiosk(-36, 13, 180, "Oxblood", "AIR TEBU")
stall(-22, 16.5, 90, "AwningYellow", "SATAY", "FruitOrange")
stall(-10, 5, -90, "AwningBlue", "CENDOL", "FruitGreen")
stall(6, 12, 90, "AwningGreen", "KUIH", "FruitRed")
kiosk(-4, 18.4, 0, "Slate", "AKHBAR  ·  MAJALAH")
tableSet(-33, -0.5, 3)
tableSet(13, 4, 3)
minibus(30, -4.6, 180)
kiosk(57, 10.6, 180, "Teal", "BUAH")
kiosk(71.2, 16.5, -90, "Forest", "KOPI O")
stall(92, 17, 90, "AwningYellow", "APAM BALIK", "FruitOrange")
lorry(116, -4.2, 180, "LorryGreen")
trishaw(45.5, 14.5, 20, "AwningGreen")
-- Roadworks close the street's east end.
for _, z in { 0, 8, 16 } do
	put("Barrier", 125, 1.5, z, 2, 3, 6)
	trim("PaintYellow", 125, 2.4, z, 2.06, 0.6, 6.06)
end
board(123.9, 5, 8, 90, 8, 2, "JALAN DITUTUP", "yellow")
put("Steel", 123.8, 2, 8, 0.4, 4, 0.4)
lampPost(100, 20.4, 18)
lampPost(64, -8.6, 18)
lanternLine(76, -10, 76, 22, 17, 6)
lanternLine(110, -10, 110, 22, 17, 6)

-- ==============================================================================
-- The Square, and the lane round the back of the bank
-- ==============================================================================

put("Cobble", -39, 0.06, 47, 46, 0.12, 50)
row("E", -62, 22, 40, 1)
row("E", -62, 56, 72, 1)
row("N", 72, -46, -16, 2)

-- The old rain tree, in a round planter with a seat's height of wall.
put("Planter", -40, 1.6, 46, 12, 3.2, 12, { shape = "Cylinder" })
trim("Soil", -40, 3.25, 46, 10.8, 0.1, 10.8, { shape = "Cylinder" })
put("Trunk", -40, 11, 46, 3.4, 16, 3.4, { shape = "Cylinder" })
for _, bough in { { 0, 27, 0, 16 }, { -6, 25, 3, 11 }, { 6, 25.5, -3, 12 }, { 2, 24.5, 6, 10 }, { -3, 25, -6, 10 } } do
	trim("Leaf", -40 + bough[1], bough[2], 46 + bough[3], bough[4], bough[4] * 0.7, bough[4], { shape = "Ball" })
end
for index, branch in { { -3, 3 }, { 4, -2 }, { 1, 5 } } do
	lantern(-40 + branch[1] * 1.6, 17.5 - index * 0.6, 46 + branch[2] * 1.6)
end
light(-40, 15, 46, 30, 0.9, LANTERN)

car(-56.4, 30.5, 90, "CarSilver")
kiosk(-50, 64, 0, "Butter", "AIS KRIM")
trishaw(-30, 27.5, 30, "AwningBlue")
trishaw(-26, 24.8, 30, "AwningRed")
stall(-28, 68.2, 0, "AwningGreen", "PISANG GORENG", "FruitOrange")
lampPost(-58, 70, 16)

row("S", 82, -46, -16, 2, "back")
row("E", -70, 82, 102, 1, "back")
row("N", 102, -70, -16, 3, "back")
skip(-42, 99, 0)
put("Cover", -66.5, 2, 85, 6, 4, 4, { prop = "Crate" })
bin(-18.6, 84.6)
bin(-21.2, 84.6)
light(-54, 12, 80, 22, 0.7)
light(-40, 12, 92, 30, 0.7)

-- ==============================================================================
-- The bank
-- ==============================================================================

-- Outer walls.
wall("BankStone", "X", 22, -16, 68, { { 16, 36, "bank: the front door" } }, { door = 12 })
wall("BankStone", "Z", -16, 22, 72, { { 31, 41, "bank: north-west door from the Square" } })
wall("BankStone", "Z", -16, 82, 102, { { 90, 100, "bank: south-west door from the back lane" } })
wall("BankStone", "Z", 68, 22, 88, { { 78, 88, "bank: east door from the defenders' compound" } })
slab("Ceiling", -15, 23, 67, 102, 24, 25)
put("MarbleFloor", 26, 0.06, 62, 82, 0.12, 78)

-- The wings: a side aisle each, with two doors into the hall at ground level
-- and, 10 up, a gallery that looks over it.
wall("BankStone", "Z", 2, 22, 102, {
	{ 44, 54, "bank: west wing into the hall" },
	{ 80, 88, "bank: west wing to the vault corridor" },
}, { thick = 1.5, height = 10 })
wall("BankStone", "Z", 48, 22, 102, {
	{ 30, 40, "bank: east wing into the hall, by the front" },
	{ 66, 76, "bank: east wing into the hall, by the vault" },
}, { thick = 1.5, height = 10 })
-- Above the doors the wing walls are solid, but for the gallery openings.
slab("BankStone", 1.25, 22, 2.75, 54, 10, 24)
slab("BankStone", 1.25, 80, 2.75, 102, 10, 24)
slab("BankStone", 1.25, 54, 2.75, 80, 20, 24)
put("Rail", 2, 11.75, 67, 0.8, 3.5, 26)
slab("BankStone", 47.25, 22, 48.75, 52, 10, 24)
slab("BankStone", 47.25, 78, 48.75, 102, 10, 24)
slab("BankStone", 47.25, 52, 48.75, 78, 20, 24)
put("Rail", 48, 11.75, 65, 0.8, 3.5, 26)

-- West gallery: up the stair along the outer wall to a landing, then along.
table.insert(ramps, { kind = "Stair", from = { -12, 0, 78 }, to = { -12, 10, 54 }, width = 6 })
slab("Gallery", -15, 44, 1.25, 54, 9, 10)
slab("Gallery", -6, 54, 1.25, 80, 9, 10)
put("Rail", -6.2, 11.5, 67, 0.4, 3, 26)
put("Rail", -7.5, 11.5, 54.2, 3, 3, 0.4)
put("Rail", -6.9, 11.5, 44.2, 16.2, 3, 0.4)
for _, z in { 56, 68, 79 } do
	put("Brass", -5.6, 4.5, z, 0.6, 9, 0.6)
end
-- East gallery, the same the other way round.
table.insert(ramps, { kind = "Stair", from = { 64, 0, 76 }, to = { 64, 10, 52 }, width = 6 })
slab("Gallery", 48.75, 42, 67, 52, 9, 10)
slab("Gallery", 48.75, 52, 56, 78, 9, 10)
put("Rail", 56.2, 11.5, 65, 0.4, 3, 26)
put("Rail", 58.5, 11.5, 52.2, 5, 3, 0.4)
put("Rail", 57.9, 11.5, 42.2, 18.2, 3, 0.4)
for _, z in { 54, 64, 77 } do
	put("Brass", 55.6, 4.5, z, 0.6, 9, 0.6)
end

-- The vault: a room at the head of the hall, behind its round door, with a
-- narrower door in each side wall.
wall("VaultWall", "X", 78, 10, 40, { { 19, 31, "vault: the round door" } }, { door = 10 })
wall("VaultWall", "Z", 10, 78, 102, { { 90, 98, "vault: west door" } })
wall("VaultWall", "Z", 40, 78, 102, { { 88, 96, "vault: east door" } })
slab("VaultWall", 11, 79, 39, 102, 13.5, 14.5)
put("VaultFloor", 25, 0.07, 90.5, 28, 0.14, 23)
-- The door itself stands open, swung back into the hall: cover.
put("VaultSteel", 32.2, 5.4, 71.8, 1.6, 10.4, 10.4, { shape = "Cylinder", axis = "X", freestanding = true })
trim("VaultDark", 31.2, 5.4, 71.8, 0.5, 4, 4, { shape = "Cylinder", axis = "X" })
trim("Brass", 30.9, 5.4, 71.8, 0.3, 5.6, 0.4)
trim("Brass", 30.9, 5.4, 71.8, 0.3, 0.4, 5.6)
for _, bolt in { { 2.6, 3.6 }, { 8.2, 3.6 }, { 2.6, -3.6 }, { 8.2, -3.6 } } do
	trim("Brass", 31.3, bolt[1], 71.8 + bolt[2], 0.4, 0.8, 0.8, { shape = "Cylinder", axis = "X" })
end
-- Its frame.
trim("VaultDark", 25, 10.6, 76.8, 14, 1.2, 0.5)
for _, x in { 18.4, 31.6 } do
	trim("VaultDark", x, 5, 76.8, 1.2, 10, 0.5)
end
board(25, 12.6, 76.7, 0, 9, 1.4, "BILIK KEBAL  ·  VAULT", "stone")
-- Inside: walls of deposit boxes, and trolleys to crouch behind.
for _, z in { 80.6, 100.9 } do
	for tier = 0, 2 do
		for column = 0, 5 do
			if not (z < 81 and column >= 2 and column <= 3) then
				trim("VaultSteel", 13.5 + column * 4.6, 2.2 + tier * 3.6, z, 4.2, 3.2, 0.3)
				trim("Brass", 13.5 + column * 4.6, 2.2 + tier * 3.6, z + (if z < 81 then 0.2 else -0.2), 0.5, 0.5, 0.1)
			end
		end
	end
end
for _, cart in { { 15.5, 84.5 }, { 34.5, 97 } } do
	put("VaultDark", cart[1], 1.7, cart[2], 5, 3.4, 3)
	trim("Gold", cart[1] - 1, 3.7, cart[2], 2, 0.6, 2)
	trim("Gold", cart[1] + 1.2, 3.6, cart[2] + 0.2, 1.6, 0.4, 1.8)
	trim("Sack", cart[1] + 0.3, 3.9, cart[2] - 0.8, 1.6, 1, 1)
end
light(25, 12, 90, 30, 1.1, COOL)
trim("LampGlow", 25, 13.2, 90, 6, 0.3, 1.2)

-- The hall: pillars to stand behind, counters to crouch behind.
for _, x in { 9.6, 40.4 } do
	for _, z in { 32, 48, 64 } do
		put("BankStone", x, 12, z, 2.4, 24, 2.4, FREE)
		trim("BankTrim", x, 0.7, z, 3.2, 1.4, 3.2)
		trim("BankTrim", x, 23.2, z, 3.4, 1.6, 3.4)
	end
end
for _, side in { { 13, 1 }, { 37, -1 } } do
	local x = side[1]
	for _, run in { { 34, 47 }, { 51, 64 } } do
		put("CounterDark", x, 2, (run[1] + run[2]) / 2, 2.4, 4, run[2] - run[1])
		trim("MarbleTop", x, 4.08, (run[1] + run[2]) / 2, 2.9, 0.16, run[2] - run[1] + 0.4)
		-- The tellers' brass grille.
		trim("Brass", x, 7.2, (run[1] + run[2]) / 2, 0.2, 0.3, run[2] - run[1])
		for z = run[1] + 0.5, run[2] - 0.4, 3 do
			trim("Brass", x, 5.7, z, 0.2, 3, 0.2)
		end
	end
	board(x + side[2] * 1.3, 8.4, 40.5, side[2] * -90, 5, 1, "JURUWANG  ·  TELLER", "stone")
end
-- In the middle: the clock on its plinth, two writing desks, benches.
put("CounterDark", 25, 2, 50, 7, 4, 7)
put("BankStone", 25, 8.5, 50, 3, 9, 3, FREE)
for _, face in { { 0, -1.56, 0 }, { 0, 1.56, 180 } } do
	trim("Chalk", 25 + face[1], 10.8, 50 + face[2], 2.2, 2.2, 0.12)
	trim("Ink", 25 + face[1], 11.2, 50 + face[2] * 1.04, 0.14, 0.9, 0.06)
	trim("Ink", 25 + face[1] + 0.3, 10.8, 50 + face[2] * 1.04, 0.7, 0.14, 0.06)
end
trim("Brass", 25, 13.3, 50, 3.6, 0.6, 3.6)
put("CounterDark", 19, 1.75, 38, 6, 3.5, 2.6)
put("CounterDark", 31, 1.75, 62, 6, 3.5, 2.6)
for _, bench in { { 20, 68 }, { 30, 30 } } do
	put("DarkTimber", bench[1], 0.9, bench[2], 6, 1.8, 2)
end
trim("Carpet", 25, 0.15, 36, 8, 0.06, 20)
trim("Carpet", 25, 0.15, 65.5, 8, 0.06, 23)
-- Chandeliers.
for _, z in { 34, 50, 66 } do
	trim("Brass", 25, 21.5, z, 0.3, 4, 0.3)
	trim("Brass", 25, 19.4, z, 5, 0.4, 5, { shape = "Cylinder" })
	for _, arm in { { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } } do
		trim("LampGlow", 25 + arm[1], 20, z + arm[2], 0.8, 0.8, 0.8, { shape = "Ball" })
	end
	light(25, 18, z, 40, 1)
end
for _, spot in { { -7, 32 }, { -7, 92 }, { 58, 32 }, { 58, 92 }, { 5.5, 92 }, { 44.5, 92 } } do
	trim("LampGlow", spot[1], 23.6, spot[2], 1.6, 0.4, 1.6, { shape = "Cylinder" })
	light(spot[1], 21, spot[2], 30, 0.8)
end
light(-3, 20, 62, 26, 0.7)
light(52, 20, 62, 26, 0.7)
-- Desks in the wings.
put("CounterDark", -8, 1.75, 26.5, 8, 3.5, 3)
put("CounterDark", -3, 1.75, 96.5, 3, 3.5, 6)
put("CounterDark", 60, 1.75, 26.5, 8, 3.5, 3)
put("DarkTimber", 51.5, 3.75, 96, 3, 7.5, 8)

-- The front: a portico of four columns on the market, and the name over it.
for _, x in { 12, 21, 31, 40 } do
	put("BankStone", x, 10, 17, 2.4, 18, 2.4, { shape = "Cylinder", freestanding = true })
	put("BankTrim", x, 0.5, 17, 3.4, 1, 3.4)
	trim("BankTrim", x, 19.5, 17, 3.4, 1, 3.4)
end
put("BankTrim", 26, 21.5, 18.5, 34, 3, 6) -- entablature
trim("BankStone", 26, 23.4, 18.5, 35, 0.8, 7)
trim("BankStone", 17.25, 25.9, 18.5, 6, 4.2, 17.5, { shape = "Wedge", yaw = 90 }) -- the pediment: two slopes
trim("BankStone", 34.75, 25.9, 18.5, 6, 4.2, 17.5, { shape = "Wedge", yaw = -90 }) -- that meet in the middle
board(26, 21.5, 15.3, 0, 30, 2.2, "BANK SIMPANAN TANJUNG  ·  1921", "stone")
put("Pave", 26, 0.06, 18, 36, 0.12, 8)
doorFrame("N", 21, 16, 36, 12)
for _, run in { { -16, 9 }, { 43, 68 } } do
	local middle, length = (run[1] + run[2]) / 2, run[2] - run[1]
	hung(trim, "BankTrim", "N", 21, middle, 1.5, 0.3, length, 3, 0.6) -- plinth
	hung(trim, "BankTrim", "N", 21, middle, 23.4, 0.5, length, 1.2, 1)
	hung(trim, "BankTrim", "N", 21, middle, 12, 0.3, length, 0.6, 0.6)
	for u = run[1] + 4.5, run[2] - 3, 8 do
		hung(trim, "BankTrim", "N", 21, u, 7.5, 0.15, 3.8, 7, 0.3)
		hung(trim, "WindowGlow", "N", 21, u, 7.5, 0.34, 3, 6.2, 0.1)
		hung(trim, "VaultDark", "N", 21, u, 7.5, 0.44, 0.2, 6.2, 0.1)
		hung(trim, "VaultDark", "N", 21, u, 7.5, 0.44, 3, 0.2, 0.1)
		hung(trim, "BankTrim", "N", 21, u, 17.5, 0.15, 3.8, 6, 0.3)
		hung(trim, "Slate", "N", 21, u, 17.5, 0.34, 3, 5.2, 0.1)
	end
end
for _, x in { 14, 38 } do
	lantern(x, 16, 20)
end
light(26, 16, 18, 30, 1)

-- The sides, in the same stone.
for _, side in { { "W", -17, 22, 72, { 31, 41 } }, { "W", -17, 82, 102, { 90, 100 } }, { "E", 69, 22, 88, { 78, 88 } } } do
	local face, at, from, to, door = side[1], side[2], side[3], side[4], side[5]
	hung(trim, "BankTrim", face, at, (from + to) / 2, 23.4, 0.5, to - from, 1.2, 1)
	hung(trim, "BankTrim", face, at, (from + to) / 2, 12, 0.3, to - from, 0.6, 0.6)
	doorFrame(face, at, door[1], door[2], 9)
	for u = from + 5, to - 4, 9 do
		if u < door[1] - 3 or u > door[2] + 3 then
			hung(trim, "BankTrim", face, at, u, 6.5, 0.15, 3.4, 6, 0.3)
			hung(trim, "Slate", face, at, u, 6.5, 0.32, 2.6, 5.2, 0.1)
		end
		hung(trim, "BankTrim", face, at, u, 17.5, 0.15, 3.4, 6, 0.3)
		hung(trim, "Slate", face, at, u, 17.5, 0.32, 2.6, 5.2, 0.1)
	end
end

-- ==============================================================================
-- The bank yard and the defenders' compound
-- ==============================================================================

wall("YardWall", "X", 50, 68, 104, { { 70, 82, "defender compound: the yard gate" } }, { height = 12, open = true })
for _, x in { 83, 69.2 } do
	put("YardWall", x, 7, 50, 2.6, 14, 2.6, FREE)
	trim("Trim", x, 14.3, 50, 3.2, 0.6, 3.2)
end
trim("Trim", 94, 12.3, 50, 20, 0.6, 2.6)
row("W", 104, 22, 50, 2, "back")
row("W", 106, 50, 88, 2, "back")
row("N", 88, 68, 106, 2, "back")
van(81, 33, 0, "VanGrey", "PaintYellow") -- the cash van, across the way out of the gate
put("Planter", 97, 1.5, 41, 3, 3, 8)
trim("Leaf", 97, 3.9, 39, 2.4, 2, 2.6, { shape = "Ball" })
trim("Leaf", 97, 4, 43, 2.4, 2.2, 2.8, { shape = "Ball" })
-- The guard's booth, inside the gate.
put("Chalk", 86.5, 4, 54.5, 5, 8, 5)
trim("RoofGreen", 86.5, 8.3, 54.5, 6.4, 0.6, 6.4)
trim("WindowGlow", 86.5, 5, 57.04, 3, 2.4, 0.1)
van(99, 80, 90, "VanGrey", "PaintYellow")
put("Cover", 73, 3.5, 56, 6, 7, 6, { prop = "CrateStack" })
put("Cover", 80, 2, 72, 10, 4, 3, { prop = "Barrier" })
lampPost(104, 52.4, 16)
lampPost(70, 86.4, 16)

-- ==============================================================================
-- Beyond the walls
-- ==============================================================================
--
-- Nobody goes there. From a street the shophouses hide everything near, so
-- what shows is what stands tall along a street's line: a pagoda beyond the
-- west end of the market, against the low sun; towers beyond the east end; a
-- hill with a mast to the north. Round them, the newer town: plain blocks, no
-- names, no signs.

local backdrop = {}

local function far(kind, x, y, z, sx, sy, sz, extra)
	local box = { kind = kind, pos = { x, y, z }, size = { sx, sy, sz } }
	for key, value in extra or {} do
		box[key] = value
	end
	table.insert(backdrop, box)
end

-- The same town every time: a fixed sequence stands in for chance.
local seed = 20261007
local function chance()
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end

local FAR_BLOCKS = { "FarGrey", "FarWarm", "FarPale", "FarBlue" }

-- A row of blocks along `axis` at `at`, between `from` and `to`.
local function skyline(axis, at, from, to, depth, low, high)
	local u = from
	while u < to do
		local width = 22 + chance() * 20
		local height = low + chance() * (high - low)
		local kind = FAR_BLOCKS[math.floor(chance() * #FAR_BLOCKS) + 1]
		local middle = u + width / 2
		local cap = middle + (chance() - 0.5) * width * 0.4
		if axis == "X" then
			far(kind, middle, height / 2, at, width - 4, height, depth)
			far("FarCap", cap, height + 3, at, 8, 6, 8)
		else
			far(kind, at, height / 2, middle, depth, height, width - 4)
			far("FarCap", at, height + 3, cap, 8, 6, 8)
		end
		u += width
	end
end

skyline("X", -152, -230, 230, 28, 36, 70)
skyline("X", -214, -280, 280, 34, 70, 140)
skyline("X", 152, -230, 230, 28, 36, 70)
skyline("X", 214, -280, 280, 34, 70, 150)
skyline("Z", -214, -110, -40, 28, 36, 64)
skyline("Z", -214, 50, 110, 28, 36, 64)
skyline("Z", -262, -180, 180, 34, 60, 110)
skyline("Z", 190, -110, -30, 28, 36, 70)
skyline("Z", 190, 44, 110, 28, 36, 70)
skyline("Z", 300, -180, 180, 34, 70, 130)

-- The pagoda, seven tiers, west along the market's line.
for tier = 0, 6 do
	local width = 30 - tier * 3
	local base = tier * 13
	far("FarCream", -190, base + 5, 6, width, 10, width)
	far("FarRoofGreen", -190, base + 10.9, 6, width + 9, 1.8, width + 9)
	far("FarRed", -190, base + 12.4, 6, width - 2, 1.2, width - 2)
end
far("FarGold", -190, 97, 6, 3, 14, 3, { shape = "Cylinder" })
far("FarGold", -190, 105, 6, 5, 5, 5, { shape = "Ball" })

-- Two towers of the newer town, east along it.
far("FarBlue", 236, 95, -8, 34, 190, 34)
far("FarPale", 236, 196, -8, 24, 12, 24)
far("FarCap", 236, 212, -8, 3, 20, 3, { shape = "Cylinder" })
far("FarGrey", 262, 75, 34, 30, 150, 30)
far("FarPale", 262, 154, 34, 20, 8, 20)

-- The hill to the north, with its mast.
far("FarHill", -72, -10, -360, 420, 170, 220, { shape = "Ball" })
far("FarHill", 90, -20, -400, 380, 130, 200, { shape = "Ball" })
far("FarPale", -72, 110, -360, 7, 90, 7, { shape = "Cylinder" })
far("FarPale", -72, 150, -360, 22, 14, 22, { shape = "Cylinder" })
far("FarCap", -72, 180, -360, 2, 50, 2, { shape = "Cylinder" })

return {
	name = "Lebuh Lama",
	teams = { "Alpha", "Bravo" },

	-- Dusk in the tropics: the sun is on the horizon and does little; the sky
	-- lights the streets evenly, and the lanterns and shop lights show.
	lighting = {
		clockTime = 17.9,
		latitude = 12,
		brightness = 1.4,
		exposure = -0.35,
		ambient = { 86, 80, 98 },
		outdoorAmbient = { 126, 112, 124 },
		environment = 0.5,
	},
	atmosphere = {
		density = 0.3,
		offset = 0.15,
		color = { 255, 196, 150 },
		decay = { 150, 96, 104 },
		glare = 0.2,
		haze = 1.4,
	},
	finish = {
		bloom = { intensity = 0.3, size = 22, threshold = 2.2 },
		grade = { contrast = 0.06, saturation = 0.06, tint = { 255, 242, 230 } },
		sunRays = { intensity = 0.03, spread = 0.7 },
	},

	styles = {
		-- Ground
		Floor = { color = { 56, 56, 60 }, material = "Asphalt" },
		Pave = { color = { 150, 144, 134 }, material = "Pavement" },
		Cobble = { color = { 124, 114, 104 }, material = "Cobblestone" },
		Tile = { color = { 198, 182, 152 }, material = "CeramicTiles" },
		Concrete = { color = { 128, 128, 126 }, material = "Concrete" },
		MarbleFloor = { color = { 222, 214, 200 }, material = "Marble" },
		VaultFloor = { color = { 92, 96, 104 }, material = "DiamondPlate" },
		Carpet = { color = { 128, 34, 36 }, material = "Carpet" },
		Boards = { color = { 122, 84, 54 }, material = "WoodPlanks" },
		Paint = { color = { 230, 226, 210 }, material = "SmoothPlastic" },
		PaintYellow = { color = { 236, 190, 40 }, material = "SmoothPlastic" },
		-- Shophouses
		Mass = { color = { 210, 196, 168 }, material = "Plaster" },
		Trim = { color = { 240, 234, 222 }, material = "Plaster" },
		Cream = { color = { 234, 216, 178 }, material = "Plaster" },
		Butter = { color = { 238, 206, 128 }, material = "Plaster" },
		Mint = { color = { 170, 206, 186 }, material = "Plaster" },
		Rose = { color = { 226, 160, 144 }, material = "Plaster" },
		Sky = { color = { 156, 194, 212 }, material = "Plaster" },
		Chalk = { color = { 232, 226, 212 }, material = "Plaster" },
		Teal = { color = { 34, 104, 100 }, material = "Wood" },
		Forest = { color = { 48, 94, 68 }, material = "Wood" },
		Umber = { color = { 104, 66, 42 }, material = "Wood" },
		Slate = { color = { 62, 80, 100 }, material = "Wood" },
		Oxblood = { color = { 132, 44, 40 }, material = "Wood" },
		Timber = { color = { 116, 74, 46 }, material = "WoodPlanks" },
		DarkTimber = { color = { 62, 42, 30 }, material = "Wood" },
		RollerShutter = { color = { 118, 122, 128 }, material = "Metal" },
		RoofTile = { color = { 172, 86, 56 }, material = "ClayRoofTiles" },
		RoofGreen = { color = { 40, 112, 82 }, material = "ClayRoofTiles" },
		Zinc = { color = { 132, 140, 146 }, material = "Metal" },
		Pipe = { color = { 96, 100, 104 }, material = "Metal" },
		AirCon = { color = { 206, 206, 200 }, material = "SmoothPlastic" },
		Ceiling = { color = { 226, 218, 202 }, material = "Plaster" },
		KopiWall = { color = { 206, 222, 204 }, material = "Plaster" },
		GodownWall = { color = { 150, 96, 76 }, material = "Brick" },
		YardWall = { color = { 160, 104, 82 }, material = "Brick" },
		-- Light
		-- Lit rooms, not lamps: dim enough that a wall of them does not glare.
		WindowGlow = { color = { 168, 98, 48 }, material = "Neon" },
		ShopGlow = { color = { 112, 78, 50 }, material = "Neon" },
		LampGlow = { color = { 255, 226, 170 }, material = "Neon" },
		Lantern = { color = { 236, 54, 36 }, material = "Neon" },
		Headlamp = { color = { 236, 232, 214 }, material = "SmoothPlastic" },
		TailLamp = { color = { 150, 28, 26 }, material = "SmoothPlastic" },
		-- The market
		CanopyGlass = { color = { 96, 176, 128 }, material = "Glass", transparency = 0.6 },
		Steel = { color = { 66, 70, 76 }, material = "Metal" },
		SteelTop = { color = { 178, 182, 186 }, material = "Metal" },
		Wire = { color = { 22, 22, 24 }, material = "SmoothPlastic" },
		Gold = { color = { 218, 174, 72 }, material = "Metal", reflectance = 0.2 },
		Brass = { color = { 188, 148, 70 }, material = "Metal", reflectance = 0.15 },
		GateRed = { color = { 170, 38, 34 }, material = "Wood" },
		AwningRed = { color = { 188, 46, 42 }, material = "Fabric" },
		AwningGreen = { color = { 44, 122, 86 }, material = "Fabric" },
		AwningBlue = { color = { 42, 88, 156 }, material = "Fabric" },
		AwningYellow = { color = { 228, 182, 62 }, material = "Fabric" },
		AwningWhite = { color = { 238, 234, 224 }, material = "Fabric" },
		CounterWood = { color = { 138, 94, 60 }, material = "WoodPlanks" },
		CounterDark = { color = { 74, 48, 36 }, material = "Wood" },
		MarbleTop = { color = { 232, 228, 220 }, material = "Marble" },
		StoolRed = { color = { 204, 44, 38 }, material = "SmoothPlastic" },
		FruitGreen = { color = { 128, 150, 60 }, material = "SmoothPlastic" },
		FruitOrange = { color = { 232, 142, 44 }, material = "SmoothPlastic" },
		FruitRed = { color = { 204, 60, 68 }, material = "SmoothPlastic" },
		Sack = { color = { 198, 178, 134 }, material = "Fabric" },
		Tarp = { color = { 72, 104, 82 }, material = "Fabric" },
		BinGreen = { color = { 44, 96, 70 }, material = "SmoothPlastic" },
		SkipBlue = { color = { 46, 84, 130 }, material = "Metal" },
		DrumBlue = { color = { 40, 88, 142 }, material = "Metal" },
		DrumRed = { color = { 158, 50, 40 }, material = "Metal" },
		Barrier = { color = { 168, 166, 160 }, material = "Concrete" },
		Planter = { color = { 158, 150, 138 }, material = "Concrete" },
		PlantPot = { color = { 164, 96, 66 }, material = "Slate" },
		Soil = { color = { 74, 56, 42 }, material = "Ground" },
		Trunk = { color = { 92, 72, 54 }, material = "Wood" },
		Leaf = { color = { 58, 112, 62 }, material = "LeafyGrass" },
		-- Vehicles
		CarWhite = { color = { 226, 226, 222 }, material = "SmoothPlastic", reflectance = 0.1 },
		CarSilver = { color = { 164, 170, 176 }, material = "SmoothPlastic", reflectance = 0.15 },
		CarRed = { color = { 164, 40, 38 }, material = "SmoothPlastic", reflectance = 0.1 },
		CarBlue = { color = { 40, 70, 126 }, material = "SmoothPlastic", reflectance = 0.1 },
		CarBlack = { color = { 34, 36, 40 }, material = "SmoothPlastic", reflectance = 0.15 },
		VanGrey = { color = { 88, 94, 102 }, material = "Metal" },
		LorryBlue = { color = { 44, 92, 150 }, material = "SmoothPlastic" },
		LorryGreen = { color = { 52, 110, 78 }, material = "SmoothPlastic" },
		BusPink = { color = { 228, 124, 152 }, material = "SmoothPlastic" },
		CarGlass = { color = { 26, 32, 40 }, material = "SmoothPlastic", reflectance = 0.25 },
		Tyre = { color = { 24, 24, 26 }, material = "SmoothPlastic" },
		-- The bank
		BankStone = { color = { 214, 204, 184 }, material = "Limestone" },
		BankTrim = { color = { 232, 226, 210 }, material = "Limestone" },
		Gallery = { color = { 84, 56, 40 }, material = "WoodPlanks" },
		Stair = { color = { 96, 64, 44 }, material = "WoodPlanks" },
		Rail = { color = { 70, 46, 34 }, material = "Wood" },
		VaultWall = { color = { 120, 124, 132 }, material = "Concrete" },
		VaultSteel = { color = { 156, 162, 170 }, material = "Metal", reflectance = 0.2 },
		VaultDark = { color = { 58, 62, 70 }, material = "Metal" },
		Ink = { color = { 24, 22, 22 }, material = "SmoothPlastic" },
		-- Beyond the walls
		FarGrey = { color = { 138, 140, 150 }, material = "SmoothPlastic" },
		FarWarm = { color = { 170, 154, 140 }, material = "SmoothPlastic" },
		FarPale = { color = { 196, 192, 186 }, material = "SmoothPlastic" },
		FarBlue = { color = { 116, 134, 158 }, material = "SmoothPlastic" },
		FarCap = { color = { 96, 98, 106 }, material = "SmoothPlastic" },
		FarCream = { color = { 226, 208, 176 }, material = "SmoothPlastic" },
		FarRoofGreen = { color = { 44, 108, 84 }, material = "SmoothPlastic" },
		FarRed = { color = { 160, 46, 40 }, material = "SmoothPlastic" },
		FarGold = { color = { 214, 172, 76 }, material = "SmoothPlastic" },
		FarHill = { color = { 54, 84, 66 }, material = "SmoothPlastic" },
	},

	bounds = { pos = { 0, 20, 0 }, size = { 286, 90, 214 } },

	-- The space players move through; everything else inside the map is solid
	-- shophouse (see Shared.Logic.Carve). Rectangles are { x1, z1, x2, z2 }.
	-- Two that touch are open to each other. Where a wall with a door in it
	-- is wanted between two, the wall is placed above with `wall`.
	fill = {
		kind = "Mass",
		height = 24,
		bounds = { -140, -104, 140, 104 },
		open = {
			-- North-west: the attackers
			{ -134, -98, -98, -70 }, -- lorry yard
			{ -98, -94, -62, -78 }, -- top lane
			{ -82, -78, -62, 22 }, -- West Street
			{ -112, -70, -98, 40 }, -- Back Lane
			{ -98, -34, -82, -22 }, -- the passage from Back Lane through to West Street
			{ -112, 40, -62, 56 }, -- the verandah, on its own solid
			-- North
			{ -62, -70, -12, -52 }, -- North Lane
			{ -26, -92, 34, -70 }, -- North Street
			{ -12, -70, 24, -36 }, -- kopitiam
			{ -12, -36, 2, -10 }, -- middle lane
			{ 24, -70, 34, -46 }, -- back lane, the leg beside the kopitiam
			{ 24, -46, 68, -36 }, -- back lane, the leg behind the godown
			{ 34, -92, 68, -46 }, -- godown
			-- North-east: site A
			{ 68, -92, 134, -48 }, -- car park
			{ 68, -48, 104, -10 }, -- Pasar Lane
			-- The market, round the shophouse that juts into it at x 48..66
			{ -62, -10, 48, 22 },
			{ 48, 8, 66, 22 },
			{ 66, -10, 128, 22 },
			-- South-west
			{ -62, 22, -16, 72 }, -- the Square
			{ -62, 72, -46, 82 }, -- the way round the back
			{ -70, 82, -16, 102 }, -- south-west lane
			-- South: the bank and the defenders
			{ -16, 22, 68, 102 }, -- bank
			{ 68, 22, 104, 50 }, -- bank yard
			{ 68, 50, 106, 88 }, -- defenders' compound
		},
	},

	-- Every doorway in a wall, gathered as the walls above were placed.
	doors = doors,

	sites = {
		{ name = "A", pos = { 104, -72 }, size = { 24, 24 } },
		{ name = "B", pos = { 25, 91 }, size = { 24, 16 } },
	},

	boxes = boxes,
	ramps = ramps,
	lamps = lamps,
	signboards = signboards,
	backdrop = backdrop,

	spawns = {
		Alpha = {
			{ -128, 3.5, -92 },
			{ -120, 3.5, -92 },
			{ -112, 3.5, -92 },
			{ -105, 3.5, -90 },
			{ -128, 3.5, -85 },
			{ -120, 3.5, -85 },
			{ -112, 3.5, -85 },
			{ -105, 3.5, -83 },
		},
		Bravo = {
			{ 88, 3.5, 62 },
			{ 96, 3.5, 62 },
			{ 78, 3.5, 62 },
			{ 88, 3.5, 70 },
			{ 80, 3.5, 78 },
			{ 88, 3.5, 78 },
			{ 80, 3.5, 84 },
			{ 88, 3.5, 84 },
		},
	},
}
