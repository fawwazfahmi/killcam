-- The four armour slots. A player picks one piece per slot; each piece changes
-- a few numbers and nothing else. Plain Luau only, so the unit tests can load it.
--
-- Being hit throws a player's aim (WeaponConfig.Flinch). A piece that takes
-- damage off a hit takes some of the knock off it too: nothing here says so,
-- it follows from `headScale` and `classScale` (see Loadout.flinch).
--
-- Being hit throws a player's aim (WeaponConfig.Flinch). A piece that takes
-- damage off a hit takes some of the knock off it too: nothing here says so,
-- it follows from `headScale` and `classScale` (see Loadout.flinch).
--
-- What a piece may carry (see Shared.Logic.Loadout for how they combine):
--   headScale      damage taken from headshots is multiplied by this
--   classScale     damage taken to the body from a weapon class is multiplied by this
--   steady         being hit never throws this player's aim
--   steady         being hit never throws this player's aim
--   speed          movement speed is multiplied by this
--   speedWith      extra speed multiplier while holding a weapon of a class
--   equipScale     weapon draw time is multiplied by this
--   tacticalScale  the tactical item's wind-up is multiplied by this (0 = instant)
--   footsteps      how far away this player's footsteps carry, as a multiplier
--   hearing        how far away this player hears other footsteps, as a multiplier
--   fallScale      fall damage is multiplied by this
--   secondPrimary  a second primary is carried as well: key 1 switches between the two
--   secondNade     a second, different grenade is carried as well: key 4 switches between the two

return {
	-- The order the loadout menu lists things in.
	slots = { "helmet", "body", "gloves", "boots" },
	titles = { helmet = "Helmet", body = "Body armour", gloves = "Gloves", boots = "Boots" },
	order = {
		helmet = { "Guard", "Listener", "Subzero" },
		body = { "Plate", "Deflector", "Light" },
		gloves = { "Quick", "Gunner", "Grenadier", "Trigger" },
		boots = { "Soft", "Runner", "Marcher", "Cushion" },
	},
	defaults = { helmet = "Guard", body = "Plate", gloves = "Quick", boots = "Soft" },

	helmet = {
		Guard = { displayName = "Guard", note = "Headshots do half damage", headScale = 0.5 },
		Listener = { displayName = "Listener", note = "Hear footsteps from further away", hearing = 1.6 },
		-- The premium helmet: rented with Robux, not points (see ShopConfig.robux).
		Subzero = {
			displayName = "Subzero",
			note = "Headshots do half damage, and being hit never throws your aim",
			headScale = 0.5,
			steady = true,
		},
		-- The premium helmet: rented with Robux, not points (see ShopConfig.robux).
		Subzero = {
			displayName = "Subzero",
			note = "Headshots do half damage, and being hit never throws your aim",
			headScale = 0.5,
			steady = true,
		},
	},

	body = {
		Plate = {
			displayName = "Plate",
			note = "Less body damage from rifles, SMGs and handguns",
			classScale = { Rifle = 0.75, SMG = 0.75, Handgun = 0.75 },
		},
		Deflector = {
			displayName = "Deflector",
			note = "Less body damage from snipers",
			classScale = { Sniper = 0.7 },
		},
		Light = { displayName = "Light", note = "No protection, but you move faster", speed = 1.08 },
	},

	gloves = {
		Gunner = {
			displayName = "Gunner",
			note = "Carry a second primary: press 1 again to switch to it",
			secondPrimary = true,
		},
		Grenadier = {
			displayName = "Grenadier",
			note = "Carry a second, different grenade: press 4 again to switch to it",
			secondNade = true,
		},
		Quick = { displayName = "Quick", note = "Draw weapons faster", equipScale = 0.6 },
		Trigger = { displayName = "Trigger", note = "Your tactical item works instantly", tacticalScale = 0 },
	},

	boots = {
		Soft = { displayName = "Soft", note = "Your footsteps carry less far", footsteps = 0.4 },
		Runner = { displayName = "Runner", note = "Move faster with the knife out", speedWith = { Melee = 1.12 } },
		Marcher = {
			displayName = "Marcher",
			note = "Move faster with a rifle or sniper out",
			speedWith = { Rifle = 1.06, Sniper = 1.06 },
		},
		Cushion = { displayName = "Cushion", note = "Take far less fall damage", fallScale = 0.3 },
	},
}
