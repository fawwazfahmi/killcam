-- Stockyard: a two-site map built from the owner's own sketch and brief.
--
-- Not mirrored. X runs west to east, Z north to south. Attackers (Alpha) spawn
-- in the north-east, defenders (Bravo) in the south-west. Site A is in the
-- south-east, a short run from the attackers; site B is in the west, next to
-- the defenders.
--
-- Attackers leave their spawn four ways:
--   1. south, through the storage room, into the north side of A
--   2. down the house corridor into the two-storey house in the centre, which
--      opens west onto mid and south towards A
--   3. the long way round: further along the top hall, then south into mid
--   4. to the end of the top hall and up a ramp to attacker heaven, a terrace
--      10 up that looks down into B
--
-- Defenders leave theirs three ways:
--   1. east across the south end of mid to A. A wall across mid leaves only a
--      16 stud gap, so attackers up mid see the crossing through a tight angle.
--   2. up a ramp to defender heaven, a deck 10 up inside B that faces attacker
--      heaven across the site
--   3. along the south lane to the lobby outside A. From the lobby, A's big
--      entrance is ahead; the store on the right has its own door into A.
--
-- Most of the map's walls are the faces of solid blocks ("Mass") that fill the
-- space between the routes. pos is the centre of a box, size its full extents,
-- all in studs.

return {
	name = "Stockyard",
	teams = { "Alpha", "Bravo" },

	lighting = {
		clockTime = 14,
		brightness = 2.5,
		ambient = { 150, 155, 165 },
		outdoorAmbient = { 170, 175, 185 },
		fogColor = { 200, 215, 235 },
		fogStart = 400,
		fogEnd = 2000,
	},

	styles = {
		Floor = { color = { 190, 192, 196 }, material = "Concrete" },
		Mass = { color = { 236, 237, 240 }, material = "SmoothPlastic" },
		Wall = { color = { 208, 210, 216 }, material = "SmoothPlastic" },
		House = { color = { 255, 196, 30 }, material = "SmoothPlastic" },
		Deck = { color = { 62, 66, 76 }, material = "DiamondPlate" },
		Terrace = { color = { 214, 58, 58 }, material = "SmoothPlastic" }, -- attacker heaven, attackers' colour
		Balcony = { color = { 52, 110, 224 }, material = "SmoothPlastic" }, -- defender heaven, defenders' colour
	},

	bounds = { pos = { 0, 20, 0 }, size = { 246, 80, 198 } },

	-- The space players move through. Everything inside the map that is not
	-- listed here is filled in solid (see Shared.Logic.Carve), so there is no
	-- way for two hand-placed blocks to miss each other and leave a hole.
	-- Rectangles are { x1, z1, x2, z2 }. Two that touch are open to each
	-- other; a thin one bridging two rooms is a doorway. Where a wall with a
	-- door in it is wanted instead, the rooms touch and a Wall box below
	-- stands in the opening.
	fill = {
		kind = "Mass",
		height = 24,
		bounds = { -120, -96, 120, 96 },
		open = {
			-- Attacker side
			{ 56, -88, 104, -60 }, -- spawn
			{ -68, -88, 56, -72 }, -- top hall
			-- Route 1, the short one: storage
			{ 72, -60, 104, -32 }, -- approach
			{ 60, -32, 112, 32 }, -- storage room
			{ 76, 32, 92, 52 }, -- the passage down into A
			-- Route 2: the two-storey house
			{ 36, -72, 48, -14 }, -- corridor
			{ 24, -14, 54, 16 }, -- the house itself
			-- Route 3: the long way round to mid
			{ -4, -72, 12, -40 },
			-- Centre
			{ -28, -40, 24, 50 }, -- mid
			{ 24, 16, 48, 52 }, -- the link from mid and the house down to A
			-- West: site B and the defenders
			{ -112, -30, -32, 32 }, -- B
			{ -32, -10, -28, 6 }, -- B's east door onto mid
			{ -112, 32, -76, 72 }, -- defender spawn
			{ -76, 32, -28, 50 }, -- defender yard
			-- South
			{ -76, 54, 48, 76 }, -- south lane
			{ 16, 52, 50, 92 }, -- lobby, and the store behind it
			{ 50, 52, 112, 92 }, -- site A
			-- Attacker heaven stands on its own solid, so nothing is filled under it
			{ -100, -90, -68, -72 },
			{ -100, -72, -36, -30 },
		},
	},

	-- Every way through the map's structure, as the design intends it: the
	-- middle of the opening and how wide it should be. tools/maps/walls.py
	-- reads this and fails on anything the geometry has that is not here, or
	-- anything here the geometry has not got.
	doors = {
		-- Only holes in a wall are listed. Where a corridor simply opens into
		-- a room there is no wall to have a hole in, so it is not a door.
		{ 56, -80, 16, "top hall: out of the attacker spawn" },
		{ 24, 1, 10, "house: west door onto mid" },
		{ 31, 16, 10, "house: south door towards A" },
		{ 16, 30, 16, "mid: the gap the defenders cross" },
		{ 24, 41, 10, "mid: door into the A link" },
		{ -30, -2, 16, "B: east door onto mid" },
		{ -104, 31, 8, "B: the heaven ramp" },
		{ -64, 31, 12, "B: south door to the yard" },
		{ -76, 44, 12, "defender spawn: out to the yard" },
		{ -76, 64, 12, "defender spawn: out to the south lane" },
		{ 36, 52, 24, "A link: down into the lobby" },
		{ 50, 64, 20, "A: the big entrance" },
		{ 50, 86, 8, "A: the store door" },
		{ 32, 77, 8, "lobby: through to the store" },
	},

	sites = {
		{ name = "A", pos = { 88, 72 }, size = { 24, 24 } },
		{ name = "B", pos = { -74, 0 }, size = { 24, 24 } },
	},

	boxes = {
		{ kind = "Floor", pos = { 0, -0.5, 0 }, size = { 240, 1, 192 } },


		-- Attacker heaven: a terrace 10 up, north of B -------------------------
		{ kind = "Terrace", pos = { -68, 5, -51 }, size = { 64, 10, 42 } },
		{ kind = "Terrace", pos = { -84, 5, -81 }, size = { 32, 10, 18 } },
		-- Rail along the edge over B, with a gap at the ramp down
		{ kind = "Deck", pos = { -64, 11.5, -30.5 }, size = { 56, 3, 1 } },
		{ kind = "Cover", pos = { -60, 12, -50 }, size = { 6, 4, 4 }, prop = "Crate" },
		{ kind = "Cover", pos = { -80, 12.5, -42 }, size = { 10, 5, 1 }, prop = "Screen" },

		-- Top hall
		{ kind = "Cover", pos = { 22, 2, -86 }, size = { 6, 4, 4 }, prop = "Crate" },
		{ kind = "Cover", pos = { -20, 2, -77 }, size = { 6, 4, 4 }, prop = "Crate", yaw = 20 },
		{ kind = "Cover", pos = { 39, 2, -44 }, size = { 6, 4, 4 }, prop = "Crate", propTurn = true },

		-- The house: two storeys, 30 x 30 --------------------------------------
		-- North wall with the door from the corridor at X 36..48
		{ kind = "House", pos = { 30, 10, -14 }, size = { 12, 20, 1 } },
		{ kind = "House", pos = { 51, 10, -14 }, size = { 6, 20, 1 } },
		{ kind = "House", pos = { 42, 14, -14 }, size = { 12, 12, 1 } },
		-- West wall: door onto mid at Z -4..6, and an upstairs window above it
		{ kind = "House", pos = { 24, 10, -9 }, size = { 1, 20, 10 } },
		{ kind = "House", pos = { 24, 10, 11 }, size = { 1, 20, 10 } },
		{ kind = "House", pos = { 24, 10.5, 1 }, size = { 1, 5, 10 } },
		-- South wall: door towards A at X 26..36, and an upstairs window above it
		{ kind = "House", pos = { 25, 10, 16 }, size = { 2, 20, 1 } },
		{ kind = "House", pos = { 45, 10, 16 }, size = { 18, 20, 1 } },
		{ kind = "House", pos = { 31, 10.5, 16 }, size = { 10, 5, 1 } },
		-- Upper floor (top surface at Y 10), open over the stairs, and the roof
		{ kind = "Deck", pos = { 35.5, 9.5, 1 }, size = { 23, 1, 30 } },
		{ kind = "Deck", pos = { 50.5, 9.5, -12 }, size = { 7, 1, 4 } },
		{ kind = "House", pos = { 39, 20.5, 1 }, size = { 30, 1, 30 } },
		{ kind = "Cover", pos = { 41, 2, -6 }, size = { 6, 4, 4 }, prop = "Crate" },
		{ kind = "Cover", pos = { 31, 12, -8 }, size = { 6, 4, 4 }, prop = "Crate" },

		-- Mid --------------------------------------------------------------------
		-- The wall that makes the defenders' crossing a tight angle: gap at X 8..24
		{ kind = "Wall", pos = { -10, 7, 30 }, size = { 36, 14, 1 } },
		-- Doorway from the defender yard (Z 36..46)
		{ kind = "Wall", pos = { -28, 7, 33 }, size = { 1, 14, 6 } }, -- down to z 30, to close the corner with B's south wall
		{ kind = "Wall", pos = { -28, 7, 48 }, size = { 1, 14, 4 } },
		-- Wall to the A link, with the door the crossing ends at (Z 36..46)
		{ kind = "Wall", pos = { 24, 7, 26 }, size = { 1, 14, 20 } },
		{ kind = "Wall", pos = { 24, 7, 48 }, size = { 1, 14, 4 } },
		{ kind = "Cover", pos = { -10, 2, -18 }, size = { 6, 4, 4 }, prop = "Crate", yaw = 20 },
		{ kind = "Cover", pos = { 10, 3.5, 2 }, size = { 6, 7, 6 }, prop = "CrateStack", yaw = -15 },
		{ kind = "Cover", pos = { -12, 2, 14 }, size = { 10, 4, 3 }, prop = "Barrier" },
		{ kind = "Cover", pos = { 14, 2, 41 }, size = { 6, 4, 4 }, prop = "Crate" },

		-- Storage room, on the attackers' short route to A ---------------------
		{ kind = "Cover", pos = { 78, 3.5, -10 }, size = { 8, 7, 4 }, prop = "Container" },
		{ kind = "Cover", pos = { 100, 3.5, 4 }, size = { 4, 7, 8 }, prop = "Container", propTurn = true },
		{ kind = "Cover", pos = { 84, 3.5, 14 }, size = { 6, 7, 6 }, prop = "CrateStack", yaw = 20 },
		{ kind = "Cover", pos = { 104, 2.5, -16 }, size = { 8, 5, 4 }, prop = "PalletLoad" },
		{ kind = "Cover", pos = { 74, 2.5, 26 }, size = { 10, 5, 1 }, prop = "Screen" },
		{ kind = "Cover", pos = { 96, 2.5, 26 }, size = { 1, 5, 10 }, prop = "Screen", propTurn = true },
		{ kind = "Cover", pos = { 108, 2, 30 }, size = { 6, 4, 4 }, prop = "Crate" },

		-- Site A -----------------------------------------------------------------
		-- West wall: big entrance at Z 54..74, the store's door at Z 82..90
		{ kind = "Wall", pos = { 50, 7, 52 }, size = { 1, 14, 4 } },
		{ kind = "Wall", pos = { 50, 7, 78 }, size = { 1, 14, 8 } },
		{ kind = "Wall", pos = { 50, 7, 91 }, size = { 1, 14, 2 } },
		{ kind = "Cover", pos = { 82, 2, 57 }, size = { 6, 4, 4 }, prop = "Crate" },
		{ kind = "Cover", pos = { 72, 3.5, 64 }, size = { 6, 7, 6 }, prop = "CrateStack", yaw = -20 },
		{ kind = "Cover", pos = { 104, 3.5, 86 }, size = { 8, 7, 4 }, prop = "Container" },
		{ kind = "Cover", pos = { 62, 2, 86 }, size = { 10, 4, 3 }, prop = "Barrier" },
		{ kind = "Cover", pos = { 106, 2, 60 }, size = { 10, 4, 3 }, prop = "Barrier", yaw = 90 },

		-- Lobby and store outside A's west side ----------------------------------
		{ kind = "Wall", pos = { 22, 7, 77 }, size = { 12, 14, 2 } },
		{ kind = "Wall", pos = { 43, 7, 77 }, size = { 14, 14, 2 } },
		{ kind = "Cover", pos = { 30, 2, 68 }, size = { 6, 4, 4 }, prop = "Crate" },
		{ kind = "Cover", pos = { 41, 2.5, 88 }, size = { 8, 5, 4 }, prop = "PalletLoad" },

		-- South lane and defender yard --------------------------------------------
		-- Two overlapping stubs put a bend in the lane, so nobody in the
		-- defender spawn can see straight through the big entrance into A
		{ kind = "Wall", pos = { -10, 7, 60 }, size = { 1, 14, 12 } },
		{ kind = "Wall", pos = { 10, 7, 70 }, size = { 1, 14, 12 } },
		{ kind = "Cover", pos = { -30, 2.5, 60 }, size = { 8, 5, 4 }, prop = "PalletLoad" },
		{ kind = "Cover", pos = { -4, 2, 72 }, size = { 6, 4, 4 }, prop = "Crate" },
		{ kind = "Cover", pos = { -54, 2, 70 }, size = { 10, 4, 3 }, prop = "Barrier" },
		{ kind = "Cover", pos = { -48, 2, 44 }, size = { 6, 4, 4 }, prop = "Crate" },

		-- Defender spawn: east wall with doors to the yard (Z 38..50) and the lane (Z 58..70)
		{ kind = "Wall", pos = { -76, 7, 35 }, size = { 1, 14, 6 } },
		{ kind = "Wall", pos = { -76, 7, 54 }, size = { 1, 14, 8 } },
		{ kind = "Wall", pos = { -76, 7, 71 }, size = { 1, 14, 2 } },

		-- Site B -----------------------------------------------------------------
		-- South wall: a gap for the heaven ramp at X -108..-100, a door at X -70..-58
		{ kind = "Wall", pos = { -110, 7, 31 }, size = { 4, 14, 2 } },
		{ kind = "Wall", pos = { -85, 7, 31 }, size = { 30, 14, 2 } },
		{ kind = "Wall", pos = { -43, 7, 31 }, size = { 30, 14, 2 } }, -- reaches the carved solid at x -28
		-- Defender heaven: a deck 10 up in the south-west corner, with rails
		{ kind = "Balcony", pos = { -98, 9.5, 22 }, size = { 28, 1, 16 } },
		{ kind = "Balcony", pos = { -85, 4.5, 15 }, size = { 2, 9, 2 } },
		{ kind = "Balcony", pos = { -98, 11.5, 14.5 }, size = { 28, 3, 1 } },
		{ kind = "Balcony", pos = { -84.5, 11.5, 22.5 }, size = { 1, 3, 15 } },
		{ kind = "Cover", pos = { -50, 3.5, -16 }, size = { 8, 7, 4 }, prop = "Container" },
		{ kind = "Cover", pos = { -58, 3.5, 18 }, size = { 4, 7, 8 }, prop = "Container", propTurn = true },
		{ kind = "Cover", pos = { -84, 3.5, -18 }, size = { 6, 7, 6 }, prop = "CrateStack", yaw = 25 },
		{ kind = "Cover", pos = { -72, 3.5, 21 }, size = { 6, 7, 6 }, prop = "CrateStack", yaw = -10 },
		{ kind = "Cover", pos = { -44, 2, 2 }, size = { 10, 4, 3 }, prop = "Barrier", yaw = 90 },
		{ kind = "Cover", pos = { -68, 2, -24 }, size = { 10, 4, 3 }, prop = "Barrier" },
		{ kind = "Cover", pos = { -106, 2, -14 }, size = { 6, 4, 4 }, prop = "Crate", propTurn = true },
	},

	ramps = {
		-- Top hall up to attacker heaven
		{ kind = "Deck", from = { -40, 0, -78 }, to = { -68, 10, -78 }, width = 8 },
		-- Attacker heaven down into B
		{ kind = "Deck", from = { -96, 0, -6 }, to = { -96, 10, -30 }, width = 8 },
		-- Defender spawn up to defender heaven
		{ kind = "Deck", from = { -104, 0, 58 }, to = { -104, 10, 32 }, width = 8 },
		-- Stairs inside the house
		{ kind = "Deck", from = { 50, 0, 12 }, to = { 50, 10, -10 }, width = 6 },
	},

	lamps = {
		{ pos = { 36, 8.3, 0 }, color = { 255, 190, 120 }, range = 28, brightness = 1.2 },
		{ pos = { 36, 19.3, 0 }, color = { 255, 190, 120 }, range = 28, brightness = 1.2 },
	},

	spawns = {
		Alpha = {
			{ 64, 3.5, -84 },
			{ 76, 3.5, -84 },
			{ 88, 3.5, -84 },
			{ 98, 3.5, -84 },
			{ 64, 3.5, -68 },
			{ 76, 3.5, -68 },
			{ 88, 3.5, -68 },
			{ 98, 3.5, -68 },
		},
		Bravo = {
			{ -96, 3.5, 42 },
			{ -88, 3.5, 42 },
			{ -80, 3.5, 42 },
			{ -96, 3.5, 54 },
			{ -88, 3.5, 54 },
			{ -80, 3.5, 54 },
			{ -92, 3.5, 66 },
			{ -82, 3.5, 66 },
		},
	},
}
