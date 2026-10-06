-- Crater Station: an original small arena on the lunar surface.
--
-- X runs between the two spawns (Alpha at -X, Bravo at +X); Z runs across.
-- Only Alpha's half (X <= 0) is written out. Entries marked `mirror` are
-- repeated on Bravo's side, reflected across X = 0.
--
-- There is no loose cover: the station's own structures are the cover.
--
--   centre         the Pad: a landing mesa 8 up. A ramp from each team and two
--                  from each side. A mast in the middle stops a line straight
--                  across the top.
--   connector      a tunnel under the Pad along X = 0, joining the north yard
--                  to the solar field
--   Z -48 .. -36   habitat tube: a roofed corridor with three doors
--   Z -36 .. -14   north yard: the long open run, with a fuel tank by each door
--   Z  14 ..  48   solar field: tall panels set at angles, and a comms bunker
--   heaven         the bunker's roof, 10 up: the highest position, looking
--                  over the Pad and the solar field, with a ramp from each side
--
-- pos is the centre of a box, size its full extents, all in studs.

local WARM = { 255, 190, 120 }

return {
	name = "Crater Station",
	teams = { "Alpha", "Bravo" },

	-- Studs per second squared. Roblox's default is 196.2; this gives longer
	-- hang time. Jump height is unchanged (see MovementConfig).
	gravity = 150,

	-- Bright show-arena look: daylight, white structures, one bold accent, and
	-- each team's end in its own colour.
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
		Regolith = { color = { 196, 198, 202 }, material = "Concrete" },
		Rim = { color = { 44, 46, 54 }, material = "SmoothPlastic" },
		Hull = { color = { 240, 241, 244 }, material = "SmoothPlastic" },
		Ramp = { color = { 62, 66, 76 }, material = "DiamondPlate" },
		Solar = { color = { 255, 196, 30 }, material = "SmoothPlastic" },
		Team = { color = { 214, 58, 58 }, mirrorColor = { 52, 110, 224 }, material = "SmoothPlastic" },
	},

	bounds = { pos = { 0, 20, 0 }, size = { 136, 80, 102 } },

	boxes = {
		-- Ground and the crater rim
		{ kind = "Regolith", pos = { 0, -0.5, 0 }, size = { 130, 1, 96 } },
		{ kind = "Rim", pos = { 0, 11, -48.5 }, size = { 132, 22, 1 } },
		{ kind = "Rim", pos = { 0, 11, 48.5 }, size = { 132, 22, 1 } },
		{ kind = "Rim", pos = { -65.5, 11, 0 }, size = { 1, 22, 96 }, mirror = true },

		-- Airlock wall at X -52, with doors at Z -40..-32, -4..4 and 32..40
		{ kind = "Team", pos = { -52, 5, -44 }, size = { 1, 10, 8 }, mirror = true },
		{ kind = "Team", pos = { -52, 5, -18 }, size = { 1, 10, 28 }, mirror = true },
		{ kind = "Team", pos = { -52, 5, 18 }, size = { 1, 10, 28 }, mirror = true },
		{ kind = "Team", pos = { -52, 5, 44 }, size = { 1, 10, 8 }, mirror = true },
		-- A baffle outside each side door, so no line runs from spawn to spawn
		{ kind = "Team", pos = { -46, 5, -36 }, size = { 1, 10, 12 }, mirror = true },
		{ kind = "Team", pos = { -46, 5, 36 }, size = { 1, 10, 12 }, mirror = true },

		-- The Pad (top surface at Y 8): two solid halves with the connector
		-- between them, 8 wide and 7 high, under a deck slab. Then the mast and
		-- a pylon at each corner.
		{ kind = "Hull", pos = { -9, 4, 0 }, size = { 10, 8, 28 }, mirror = true },
		{ kind = "Hull", pos = { 0, 7.5, 0 }, size = { 8, 1, 28 } },
		{ kind = "Hull", pos = { 0, 14, 0 }, size = { 6, 12, 6 } },
		{ kind = "Hull", pos = { -12.5, 10.5, -12.5 }, size = { 3, 5, 3 }, mirror = true },
		{ kind = "Hull", pos = { -12.5, 10.5, 12.5 }, size = { 3, 5, 3 }, mirror = true },
		-- Pylons either side of each team's ramp
		{ kind = "Hull", pos = { -36, 4, -8 }, size = { 3, 8, 3 }, mirror = true },
		{ kind = "Hull", pos = { -36, 4, 8 }, size = { 3, 8, 3 }, mirror = true },

		-- Habitat tube: south wall at Z -36 with doors at X -31..-25 and -5..5,
		-- a roof, and a bulkhead stub on each side
		{ kind = "Hull", pos = { -35.5, 5, -36 }, size = { 9, 10, 1 }, mirror = true },
		{ kind = "Hull", pos = { -15, 5, -36 }, size = { 20, 10, 1 }, mirror = true },
		{ kind = "Hull", pos = { 0, 10.5, -42 }, size = { 80, 1, 13 } },
		{ kind = "Hull", pos = { -12, 5, -45.5 }, size = { 1, 10, 5 }, mirror = true },

		-- North yard: a fuel tank in front of each tube door
		{ kind = "Hull", pos = { -30, 4.5, -24 }, size = { 10, 9, 10 }, mirror = true },

		-- Solar field: panels at angles, and the comms bunker
		{ kind = "Solar", pos = { -36, 4, 24 }, size = { 12, 8, 1 }, yaw = 35, mirror = true },
		{ kind = "Solar", pos = { -22, 4, 38 }, size = { 12, 8, 1 }, yaw = -35, mirror = true },
		{ kind = "Hull", pos = { 0, 5, 43 }, size = { 20, 10, 10 } },
		-- Heaven: the bunker roof, with a rail to crouch behind
		{ kind = "Hull", pos = { 0, 11.5, 38.25 }, size = { 20, 3, 0.5 } },
	},

	ramps = {
		-- Each team's ramp onto the Pad
		{ kind = "Ramp", from = { -32, 0, 0 }, to = { -14, 8, 0 }, width = 8, mirror = true },
		-- From the north yard and from the solar field, either side of the connector
		{ kind = "Ramp", from = { -8, 0, -32 }, to = { -8, 8, -14 }, width = 6, mirror = true },
		{ kind = "Ramp", from = { -8, 0, 32 }, to = { -8, 8, 14 }, width = 6, mirror = true },
		-- Up to heaven, along the south rim
		{ kind = "Ramp", from = { -34, 0, 45.5 }, to = { -10, 10, 45.5 }, width = 5, mirror = true },
	},

	lamps = {
		{ pos = { -59, 14, 0 }, color = WARM, range = 40, brightness = 1.3, post = true, mirror = true },
		{ pos = { -44, 14, -22 }, color = WARM, range = 40, brightness = 1.2, post = true, mirror = true },
		{ pos = { -44, 14, 16 }, color = WARM, range = 40, brightness = 1.2, post = true, mirror = true },
		{ pos = { -30, 9.3, -42 }, color = WARM, range = 26, brightness = 1.2, mirror = true },
		{ pos = { 0, 9.3, -42 }, color = WARM, range = 26, brightness = 1.2 },
		{ pos = { -4.2, 18, 0 }, color = WARM, range = 44, brightness = 1.4, mirror = true },
		{ pos = { 0, 6.5, -8 }, color = WARM, range = 20, brightness = 1.0 }, -- connector
		{ pos = { 0, 6.5, 8 }, color = WARM, range = 20, brightness = 1.0 },
		{ pos = { 0.95, 16, 47 }, color = WARM, range = 34, brightness = 1.2, post = true }, -- heaven
	},

	-- Alpha's spawn points; Bravo's are the mirror image.
	spawns = {
		{ -59, 3.5, -42 },
		{ -59, 3.5, -30 },
		{ -59, 3.5, -18 },
		{ -59, 3.5, -8 },
		{ -59, 3.5, 8 },
		{ -59, 3.5, 18 },
		{ -59, 3.5, 30 },
		{ -59, 3.5, 42 },
	},
}
