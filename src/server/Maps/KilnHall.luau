-- Kiln Hall: an original compact arena inside a roofed foundry.
--
-- X runs between the two spawns (Alpha at -X, Bravo at +X); Z runs across.
-- Only Alpha's half (X <= 0) is written out. Entries marked `mirror` are
-- repeated on Bravo's side, reflected across X = 0.
--
-- A solid kiln fills the centre, so there is no line from spawn to spawn.
--
--   Z -50 .. -34   loading deck, 8 up, with an undercroft below it
--   Z -34 ..  18   casting floor around the kiln; the flue walls, sand hoppers
--                  and deck ramps break every long line across it
--   Z  18 ..  30   cart lane: the longest runs, with crouch cover only
--   Z  30 ..  50   tool crib: a zigzag of short rooms for close fighting
--
-- pos is the centre of a box, size its full extents, all in studs.

local WARM = { 255, 190, 120 }
local FIRE = { 255, 140, 60 }

return {
	name = "Kiln Hall",
	teams = { "Alpha", "Bravo" },

	lighting = {
		clockTime = 0,
		brightness = 0,
		ambient = { 46, 42, 48 },
		outdoorAmbient = { 30, 28, 32 },
		fogColor = { 22, 15, 12 },
		fogStart = 50,
		fogEnd = 320,
	},

	bounds = { pos = { 0, 12, 0 }, size = { 166, 30, 106 } },

	boxes = {
		-- Floor, outer walls and roof
		{ kind = "Floor", pos = { 0, -0.5, 0 }, size = { 160, 1, 100 } },
		{ kind = "Wall", pos = { 0, 12, -50.5 }, size = { 162, 24, 1 } },
		{ kind = "Wall", pos = { 0, 12, 50.5 }, size = { 162, 24, 1 } },
		{ kind = "Wall", pos = { -80.5, 12, 0 }, size = { 1, 24, 100 }, mirror = true },
		{ kind = "Building", pos = { 0, 24.5, 0 }, size = { 162, 1, 102 } },

		-- Spawn wall at X -64, with doors at Z -46..-38, -5..5 and 36..44
		{ kind = "Wall", pos = { -64, 6, -48 }, size = { 1, 12, 4 }, mirror = true },
		{ kind = "Wall", pos = { -64, 6, -21.5 }, size = { 1, 12, 33 }, mirror = true },
		{ kind = "Wall", pos = { -64, 6, 20.5 }, size = { 1, 12, 31 }, mirror = true },
		{ kind = "Wall", pos = { -64, 6, 47 }, size = { 1, 12, 6 }, mirror = true },

		-- The kiln, its chimney, a glowing mouth facing each team, and the flue walls
		{ kind = "Building", pos = { 0, 8, 0 }, size = { 24, 16, 22 } },
		{ kind = "Building", pos = { 0, 20, 0 }, size = { 8, 8, 8 } },
		{ kind = "Glow", pos = { -12.2, 3.5, 0 }, size = { 0.6, 5, 8 }, mirror = true },
		{ kind = "Building", pos = { 0, 5, -15.5 }, size = { 2, 10, 9 } },
		{ kind = "Building", pos = { 0, 5, 17.5 }, size = { 2, 10, 13 } },

		-- Sand hoppers: solid blocks that split each side of the casting floor
		{ kind = "Building", pos = { -28, 4.5, -8 }, size = { 10, 9, 8 }, mirror = true },

		-- Loading deck (top surface at Y 8) on piers, open underneath
		{ kind = "Catwalk", pos = { 0, 7.5, -42 }, size = { 80, 1, 16 } },
		{ kind = "Catwalk", pos = { -38, 3.5, -37 }, size = { 2, 7, 6 }, mirror = true },
		{ kind = "Catwalk", pos = { -12, 3.5, -37 }, size = { 2, 7, 6 }, mirror = true },
		-- Deck rails: crouch cover up top, with gaps where the ramps arrive
		{ kind = "Catwalk", pos = { -33.5, 9.5, -34.25 }, size = { 13, 3, 0.5 }, mirror = true },
		{ kind = "Catwalk", pos = { 0, 9.5, -34.25 }, size = { 42, 3, 0.5 } },
		{ kind = "Catwalk", pos = { -40.25, 9.5, -48 }, size = { 0.5, 3, 4 }, mirror = true },
		{ kind = "Catwalk", pos = { -40.25, 9.5, -36 }, size = { 0.5, 3, 4 }, mirror = true },
		{ kind = "Cover", pos = { -14, 10.5, -43 }, size = { 1, 5, 10 }, prop = "Screen", propTurn = true, mirror = true },

		-- Undercroft
		{ kind = "Cover", pos = { -30, 2, -44 }, size = { 6, 4, 4 }, prop = "Crate", mirror = true },
		{ kind = "Cover", pos = { 0, 3.5, -47 }, size = { 6, 7, 6 }, prop = "CrateStack" },

		-- Casting floor: 4 high is crouch cover, 7 high is standing cover
		{ kind = "Cover", pos = { -50, 3.5, 0 }, size = { 4, 7, 8 }, prop = "Container", propTurn = true, mirror = true },
		{ kind = "Cover", pos = { -40, 3.5, -22 }, size = { 6, 7, 6 }, prop = "CrateStack", yaw = 25, mirror = true },
		{ kind = "Cover", pos = { -34, 2, 8 }, size = { 10, 4, 3 }, prop = "Barrier", yaw = 60, mirror = true },
		{ kind = "Cover", pos = { -9, 2, -27 }, size = { 6, 4, 4 }, prop = "Crate", yaw = -15, mirror = true },

		-- Cart lane. The south flue wall narrows it at the centre and a wing
		-- wall narrows it at each end, so no line runs its full length.
		{ kind = "Building", pos = { -46, 7, 27 }, size = { 1, 14, 6 }, mirror = true },
		{ kind = "Cover", pos = { -36, 2, 26 }, size = { 10, 4, 3 }, prop = "Barrier", mirror = true },
		{ kind = "Cover", pos = { -12, 2, 21 }, size = { 10, 4, 3 }, prop = "Barrier", yaw = 90, mirror = true },
		{ kind = "Cover", pos = { -52, 2.5, 34 }, size = { 8, 5, 4 }, prop = "PalletLoad", mirror = true },

		-- Tool crib: wall at Z 30 with doors at X -34..-26 and -4..4, then
		-- cross walls that alternate sides so the way through zigzags
		{ kind = "Building", pos = { -40, 7, 30 }, size = { 12, 14, 1 }, mirror = true },
		{ kind = "Building", pos = { -15, 7, 30 }, size = { 22, 14, 1 }, mirror = true },
		{ kind = "Building", pos = { -16, 7, 35.25 }, size = { 1, 14, 9.5 }, mirror = true },
		{ kind = "Building", pos = { 0, 7, 45.25 }, size = { 1, 14, 9.5 } },
		{ kind = "Building", pos = { -40, 7, 45.5 }, size = { 10, 14, 9 }, mirror = true }, -- store room
		{ kind = "Cover", pos = { -30, 2, 46 }, size = { 6, 4, 4 }, prop = "Crate", mirror = true },
	},

	ramps = {
		-- From each north door up to the end of the deck
		{ kind = "Catwalk", from = { -58, 0, -42 }, to = { -40, 8, -42 }, width = 8, mirror = true },
		-- From the casting floor up to the deck's edge
		{ kind = "Catwalk", from = { -24, 0, -18 }, to = { -24, 8, -34 }, width = 6, mirror = true },
	},

	-- `bare = true` is a light with no fitting: the kiln mouths.
	lamps = {
		{ pos = { -14, 4, 0 }, color = FIRE, range = 44, brightness = 2.2, bare = true, mirror = true },
		{ pos = { -72, 22, -24 }, color = WARM, range = 40, brightness = 1.3, mirror = true },
		{ pos = { -72, 22, 24 }, color = WARM, range = 40, brightness = 1.3, mirror = true },
		{ pos = { -44, 22, -14 }, color = WARM, range = 44, brightness = 1.2, mirror = true },
		{ pos = { -26, 22, -42 }, color = WARM, range = 36, brightness = 1.3, mirror = true },
		{ pos = { -20, 6, -44 }, color = WARM, range = 22, brightness = 0.9, mirror = true },
		{ pos = { -40, 22, 24 }, color = WARM, range = 44, brightness = 1.2, mirror = true },
		{ pos = { 0, 22, 24 }, color = WARM, range = 40, brightness = 1.2 },
		{ pos = { -32, 22, 41 }, color = WARM, range = 36, brightness = 1.3, mirror = true },
		{ pos = { -8, 22, 38 }, color = WARM, range = 30, brightness = 1.2, mirror = true },
	},

	-- Alpha's spawn points; Bravo's are the mirror image.
	spawns = {
		{ -73, 3.5, -42 },
		{ -73, 3.5, -30 },
		{ -73, 3.5, -18 },
		{ -73, 3.5, -6 },
		{ -73, 3.5, 6 },
		{ -73, 3.5, 18 },
		{ -73, 3.5, 30 },
		{ -73, 3.5, 42 },
	},
}
