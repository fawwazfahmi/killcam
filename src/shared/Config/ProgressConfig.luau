-- Experience with each class of weapon, and the materials it climbs through.
-- Plain Luau only, so the unit tests can load it. Every number is a first guess.
--
-- What is saved for a player is two things per class: the experience itself,
-- and the name of the highest standing they have reached ("Iron", tier 3).
-- Neither refers to this table by position, so it can be reworked freely:
--   add a material, or tiers to one, and everybody keeps climbing;
--   change what a tier costs, and nobody is moved below what they had reached;
--   rename a material, and standings in it are worked out afresh from experience.

return {
	weapons = {
		xp = { kill = 100, assist = 40 },
		-- Hurting somebody within this many seconds of another player killing
		-- them is an assist.
		assistWindow = 8,

		-- The classes, in the order the profile lists them. A weapon's class
		-- is its `class` in WeaponConfig.
		classes = { "Rifle", "SMG", "Sniper", "Handgun", "Melee", "Grenade" },
		titles = {
			Rifle = "Rifle",
			SMG = "SMG",
			Sniper = "Sniper",
			Handgun = "Handgun",
			Melee = "Knife",
			Grenade = "Grenades",
		},

		-- The ladder, lowest first. Each material has `tiers` steps, and `xp`
		-- is what it costs to climb one of them.
		prestiges = {
			{ name = "Wood", tiers = 5, xp = 500 },
			{ name = "Iron", tiers = 5, xp = 1000 },
			{ name = "Gold", tiers = 5, xp = 2000 },
			{ name = "Diamond", tiers = 5, xp = 4000 },
			{ name = "Titanium", tiers = 5, xp = 8000 },
		},
	},
}
