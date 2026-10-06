-- Points, levels and the shop. Players earn points from matches and spend them
-- renting loadout options. Plain Luau only, so the unit tests can load it.
-- Every number is a first guess.

-- Ranks, lowest first. A rank has `grades` levels in it: a player is "Private
-- 1", then "Private 2", and so on up. The top level is the last grade of the
-- last rank. Ranks can be added, renamed or given more grades at any time: a
-- player's level is what is saved, and their rank is read from it here.
local RANKS = {
	{ name = "Private", grades = 3 },
	{ name = "Private First Class", grades = 3 },
	{ name = "Corporal", grades = 4 },
	{ name = "Sergeant", grades = 5 },
	{ name = "Staff Sergeant", grades = 5 },
	{ name = "Sergeant First Class", grades = 5 },
	{ name = "Master Sergeant", grades = 5 },
	{ name = "Sergeant Major", grades = 5 },
	{ name = "Second Lieutenant", grades = 4 },
	{ name = "First Lieutenant", grades = 4 },
	{ name = "Captain", grades = 5 },
	{ name = "Major", grades = 5 },
	{ name = "Lieutenant Colonel", grades = 4 },
	{ name = "Colonel", grades = 4 },
	{ name = "Brigadier General", grades = 3 },
	{ name = "Major General", grades = 3 },
	{ name = "Lieutenant General", grades = 3 },
	{ name = "General", grades = 3 },
	{ name = "Commander in Chief", grades = 1 },
}

local topLevel = 0
for _, rank in RANKS do
	topLevel += rank.grades
end

return {
	-- Earned at the end of a match. Experience earned equals points earned.
	-- The match's top killer is its MVP and gets the bonus on top.
	--
	-- A player who took no part (no kills, deaths, assists or objectives: a
	-- late arrival to a match already ending, or somebody standing idle) earns
	-- nothing. One who was in the match for less than `shortStay` seconds
	-- earns `shortShare` of what they otherwise would.
	rewards = { perKill = 10, win = 100, loss = 40, mvp = 150, shortStay = 90, shortShare = 0.5 },

	-- Experience needed to go from level n to n + 1 is base + step * (n - 1).
	-- Each level gained also pays a bonus. `max` is the top level, where
	-- experience stops counting.
	levels = { base = 500, step = 250, bonus = 300, max = topLevel },
	ranks = RANKS,

	-- How a rental of each loadout field runs down:
	--   "use"       only while the item is in your loadout and you are alive in a match
	--   "calendar"  in real time, starting the first time you spawn with it
	timing = {
		primary = "use",
		secondary = "use",
		melee = "use",
		nade = "use",
		tactical = "calendar",
		helmet = "calendar",
		body = "calendar",
		gloves = "calendar",
		boots = "calendar",
	},

	-- The second primary and second grenade (which gloves unlock) are the same
	-- items as the first: owning one is owning it for either place.
	aliases = { primary2 = "primary", nade2 = "nade" },

	-- Nothing is rented during a match. What a player already owns can still be
	-- swapped there, at a price:
	matchSwap = {
		-- Points for each weapon or grenade taken into a life that was not
		-- carried in the one before. The first life of a match is free.
		weaponPoints = 15,
		-- The developer product that one change of armour or tactical item
		-- costs, in Robux. 0 keeps those locked for the whole match.
		armourProductId = 0,
	},

	-- What is on sale for each kind of timing. `unit` is one unit in seconds and
	-- `label` its short name. `price` multiplies the option's price for one unit.
	terms = {
		use = {
			unit = 3600,
			label = "H",
			lengths = {
				{ amount = 1, price = 1 },
				{ amount = 3, price = 2.5 },
				{ amount = 5, price = 4 },
			},
		},
		calendar = {
			unit = 86400,
			label = "D",
			lengths = {
				{ amount = 1, price = 1 },
				{ amount = 2, price = 1.8 },
				{ amount = 3, price = 2.5 },
				{ amount = 5, price = 3.8 },
				{ amount = 7, price = 5 },
			},
		},
	},

	-- Price in points for one unit (an hour of use, or a day), by loadout field
	-- then option. Anything not listed here is free for everyone.
	prices = {
		primary = { Smg = 200, Sniper = 300 },
		nade = { Smoke = 120, Gas = 150, Flash = 150 },
		tactical = { Cryo = 200 },
		helmet = { Listener = 250 },
		body = { Deflector = 250, Light = 250 },
		gloves = { Gunner = 400, Grenadier = 350, Trigger = 300 },
		boots = { Runner = 200, Marcher = 200, Cushion = 150 },
	},
}
