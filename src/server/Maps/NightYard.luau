-- Night Yard: an original three-route blockout.
--
-- X runs between the two spawns (Alpha at -X, Bravo at +X); Z runs across.
-- Only Alpha's half (X <= 0) is written out. Entries marked `mirror` are
-- repeated on Bravo's side, reflected across X = 0.
--
--   Z -70 .. -30   building side: two-storey interior, stairs, tight corners
--   Z -30 ..  42   centre yard: open, low cover, catwalk overhead
--   Z  42 ..  70   long lane: one straight 170 stud sightline
--
-- pos is the centre of a box, size its full extents, all in studs.

local WARM = { 255, 190, 120 }

return {
	name = "Night Yard",
	teams = { "Alpha", "Bravo" },

	lighting = {
		clockTime = 0,
		brightness = 1,
		ambient = { 58, 66, 92 },
		outdoorAmbient = { 64, 74, 104 },
		fogColor = { 14, 17, 28 },
		fogStart = 70,
		fogEnd = 420,
	},

	bounds = { pos = { 0, 20, 0 }, size = { 226, 90, 146 } },

	boxes = {
		-- Ground and outer walls
		{ kind = "Floor", pos = { 0, -0.5, 0 }, size = { 220, 1, 140 } },
		{ kind = "Wall", pos = { 0, 12, -70.5 }, size = { 222, 24, 1 } },
		{ kind = "Wall", pos = { 0, 12, 70.5 }, size = { 222, 24, 1 } },
		{ kind = "Wall", pos = { -110.5, 12, 0 }, size = { 1, 24, 140 }, mirror = true },

		-- Spawn wall at X -85, with one exit per route (Z -58..-46, -6..6, 50..62)
		{ kind = "Wall", pos = { -85, 7, -64 }, size = { 1, 14, 12 }, mirror = true },
		{ kind = "Wall", pos = { -85, 7, -26 }, size = { 1, 14, 40 }, mirror = true },
		{ kind = "Wall", pos = { -85, 7, 28 }, size = { 1, 14, 44 }, mirror = true },
		{ kind = "Wall", pos = { -85, 7, 66 }, size = { 1, 14, 8 }, mirror = true },

		-- Wall between the building approach and the yard, open from X -64 to -50
		{ kind = "Wall", pos = { -74.5, 7, -30 }, size = { 21, 14, 1 }, mirror = true },

		-- Wall between the yard and the long lane, with a connector at X -58..-44
		{ kind = "Wall", pos = { -71.5, 7, 42 }, size = { 27, 14, 1 }, mirror = true },
		{ kind = "Wall", pos = { -22, 7, 42 }, size = { 44, 14, 1 }, mirror = true },

		-- Building, west wall at X -50 with a door at Z -56..-48
		{ kind = "Building", pos = { -50, 12, -63 }, size = { 1, 24, 14 }, mirror = true },
		{ kind = "Building", pos = { -50, 12, -39 }, size = { 1, 24, 18 }, mirror = true },
		{ kind = "Building", pos = { -50, 16.5, -52 }, size = { 1, 15, 8 }, mirror = true },

		-- Building, south wall at Z -30: ground floor with a door at X -34..-26
		{ kind = "Building", pos = { -42, 6, -30 }, size = { 16, 12, 1 }, mirror = true },
		{ kind = "Building", pos = { -13, 6, -30 }, size = { 26, 12, 1 }, mirror = true },
		{ kind = "Building", pos = { -30, 10.5, -30 }, size = { 8, 3, 1 }, mirror = true },

		-- South wall, upper floor: windows over the yard at X -44..-36 and -20..-8,
		-- and a doorway onto the catwalk at X -4..4
		{ kind = "Building", pos = { -27, 13.5, -30 }, size = { 46, 3, 1 }, mirror = true },
		{ kind = "Building", pos = { -25, 22, -30 }, size = { 50, 4, 1 }, mirror = true },
		{ kind = "Building", pos = { -47, 17.5, -30 }, size = { 6, 5, 1 }, mirror = true },
		{ kind = "Building", pos = { -28, 17.5, -30 }, size = { 16, 5, 1 }, mirror = true },
		{ kind = "Building", pos = { -6, 17.5, -30 }, size = { 4, 5, 1 }, mirror = true },

		-- Upper floor (top surface at Y 12), leaving a stairwell at X -46..-22, Z -70..-63
		{ kind = "Building", pos = { -25, 11.5, -46.5 }, size = { 50, 1, 33 }, mirror = true },
		{ kind = "Building", pos = { -11, 11.5, -66.5 }, size = { 22, 1, 7 }, mirror = true },
		{ kind = "Building", pos = { -48, 11.5, -66.5 }, size = { 4, 1, 7 }, mirror = true },

		-- Roof
		{ kind = "Building", pos = { -25, 24.5, -50 }, size = { 50, 1, 40 }, mirror = true },

		-- Interior walls and cover
		{ kind = "Building", pos = { -18, 5.5, -49 }, size = { 1, 11, 22 }, mirror = true },
		{ kind = "Building", pos = { -6, 5.5, -50 }, size = { 12, 11, 1 }, mirror = true },
		{ kind = "Cover", pos = { -36, 2, -40 }, size = { 6, 4, 4 }, prop = "Crate", mirror = true },
		{ kind = "Cover", pos = { -30, 14.5, -45 }, size = { 1, 5, 10 }, prop = "Screen", propTurn = true, mirror = true },

		-- Catwalk across the yard, from the building's upper floor to the lane wall
		{ kind = "Catwalk", pos = { 0, 11.5, 6 }, size = { 8, 1, 72 } },
		{ kind = "Catwalk", pos = { -4.25, 13.25, 2 }, size = { 0.5, 2.5, 64 }, mirror = true },
		{ kind = "Catwalk", pos = { 0, 5.5, -18 }, size = { 2, 11, 2 } },
		{ kind = "Catwalk", pos = { 0, 5.5, 6 }, size = { 2, 11, 2 } },
		{ kind = "Catwalk", pos = { 0, 5.5, 30 }, size = { 2, 11, 2 } },

		-- Yard cover: 4 high is crouch cover, 7 high is standing cover.
		-- `prop` names the model drawn over the box (see MapBuilder); `propTurn`
		-- lays the prop's long side along Z. `yaw` turns box and prop together,
		-- so the open yard does not read as a grid.
		{ kind = "Cover", pos = { -72, 3.5, 30 }, size = { 8, 7, 4 }, prop = "Container", mirror = true },
		{ kind = "Cover", pos = { -60, 3.5, -10 }, size = { 6, 7, 6 }, prop = "CrateStack", yaw = 20, mirror = true },
		{ kind = "Cover", pos = { -60, 2, 14 }, size = { 10, 4, 3 }, prop = "Barrier", mirror = true },
		{ kind = "Cover", pos = { -35, 2, 2 }, size = { 4, 4, 12 }, prop = "Barrier", propTurn = true, mirror = true },
		{ kind = "Cover", pos = { -20, 3.5, 22 }, size = { 6, 7, 6 }, prop = "CrateStack", yaw = -25, mirror = true },
		{ kind = "Cover", pos = { -14, 2, -16 }, size = { 12, 4, 3 }, prop = "Barrier", mirror = true },

		-- Long lane cover. A square turned 45 degrees is still its own mirror image.
		{ kind = "Cover", pos = { -65, 3.5, 50 }, size = { 4, 7, 8 }, prop = "Container", propTurn = true, mirror = true },
		{ kind = "Cover", pos = { -30, 2.5, 62 }, size = { 8, 5, 4 }, prop = "PalletLoad", mirror = true },
		{ kind = "Cover", pos = { 0, 3.5, 56 }, size = { 6, 7, 6 }, prop = "CrateStack", yaw = 45 },
	},

	ramps = {
		-- Stairs inside the building, along its north wall
		{ kind = "Building", from = { -46, 0, -66 }, to = { -22, 12, -66 }, width = 6, mirror = true },
		-- Yard ramp up to the south end of the catwalk
		{ kind = "Catwalk", from = { -28, 0, 38 }, to = { -4, 12, 38 }, width = 6, mirror = true },
	},

	-- `post = true` stands the lamp on a pole, which players and shots collide with.
	lamps = {
		{ pos = { -98, 14, 0 }, color = WARM, range = 45, brightness = 1.2, post = true, mirror = true },
		{ pos = { -85, 13, -52 }, color = WARM, range = 36, brightness = 1.5, mirror = true },
		{ pos = { -85, 13, 0 }, color = WARM, range = 36, brightness = 1.5, mirror = true },
		{ pos = { -85, 13, 56 }, color = WARM, range = 36, brightness = 1.5, mirror = true },
		{ pos = { -35, 10, -45 }, color = WARM, range = 30, brightness = 1.4, mirror = true },
		{ pos = { -25, 23, -50 }, color = WARM, range = 34, brightness = 1.4, mirror = true },
		{ pos = { -45, 13, -5 }, color = WARM, range = 40, brightness = 1.3, post = true, mirror = true },
		{ pos = { -45, 13, 56 }, color = WARM, range = 40, brightness = 1.3, mirror = true },
		{ pos = { 0, 18, 6 }, color = WARM, range = 40, brightness = 1.3 },
	},

	-- Alpha's spawn points; Bravo's are the mirror image.
	spawns = {
		{ -98, 3.5, -50 },
		{ -98, 3.5, -36 },
		{ -98, 3.5, -22 },
		{ -98, 3.5, -8 },
		{ -98, 3.5, 8 },
		{ -98, 3.5, 22 },
		{ -98, 3.5, 36 },
		{ -98, 3.5, 50 },
	},
}
