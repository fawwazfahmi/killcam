-- Small pictures drawn from grids, so the game needs no image uploads. Each
-- row is a line of cells: "." is empty, and any other character is a cell in
-- the colour `colors` gives it. Plain Luau only, so the unit tests can load it.
--
-- PixelArt in the client draws them.

local RED = { 255, 70, 60 }

return {
	-- A kill.
	Skull = {
		colors = { X = RED },
		rows = {
			"...XXXXXXX...",
			"..XXXXXXXXX..",
			".XXXXXXXXXXX.",
			".XXXXXXXXXXX.",
			".XXXXXXXXXXX.",
			".XX...X...XX.",
			".XX...X...XX.",
			".XXXXX.XXXXX.",
			"..XXXXXXXXX..",
			"...X.X.X.X...",
			"...XXXXXXX...",
		},
	},

	-- A kill by headshot: the same skull with the top off and the brain out.
	BrainSkull = {
		colors = { X = RED, B = { 255, 158, 178 }, b = { 222, 104, 134 } },
		rows = {
			"....BBbBB....",
			"..BBbBBBbBB..",
			".BBbBBbBBbBB.",
			".XBBbBBBbBBX.",
			".XXBXXBXXBXX.",
			".XX...X...XX.",
			".XX...X...XX.",
			".XXXXX.XXXXX.",
			"..XXXXXXXXX..",
			"...X.X.X.X...",
			"...XXXXXXX...",
		},
	},

	-- A standing figure. It fills from the feet up as a respawn approaches.
	Body = {
		colors = { X = { 255, 255, 255 } },
		rows = {
			"....XXX....",
			"...XXXXX...",
			"...XXXXX...",
			"....XXX....",
			".....X.....",
			"..XXXXXXX..",
			".XXXXXXXXX.",
			"XXXXXXXXXXX",
			"XX.XXXXX.XX",
			"XX.XXXXX.XX",
			"XX.XXXXX.XX",
			"XX.XXXXX.XX",
			"XX.XXXXX.XX",
			"...XXXXX...",
			"...XXXXX...",
			"...XX.XX...",
			"...XX.XX...",
			"...XX.XX...",
			"...XX.XX...",
			"...XX.XX...",
			"...XX.XX...",
			"..XXX.XXX..",
		},
	},
}
