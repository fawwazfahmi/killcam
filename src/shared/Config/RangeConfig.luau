-- The test range: a third place, for the game's developers only, where
-- everything is unlocked and dummies stand in for players. Plain Luau only, so
-- the unit tests can load it.

return {
	-- Who is let in. The owner of the experience always is (in an experience
	-- owned by a group, anybody of `groupRank` or above in it), and so is
	-- anybody testing in Studio. Put the Roblox user id of anyone else here.
	-- Everybody not on the list is removed as they arrive.
	admins = {},
	groupRank = 255, -- 255 is a group's owner

	dummy = {
		healAfter = 4, -- seconds without being hit before a dummy is back to full health
		respawnAfter = 2, -- seconds a dummy that died stays down
		strafe = 8, -- studs a moving dummy goes either side of where it stands
		most = 24, -- dummies an admin can have placed at once, besides the fixed ones
		reach = 500, -- studs away, at most, that a dummy can be placed
	},

	-- Where a dummy that shoots back can be told to aim: the name on the panel
	-- and the body part it goes for. The damage zone follows from the part, the
	-- same way it does for a player's shot (Damage.zoneForPart).
	aims = {
		{ name = "Head", part = "Head" },
		{ name = "Chest", part = "UpperTorso" },
		{ name = "Stomach", part = "LowerTorso" },
		{ name = "Legs", part = "RightUpperLeg" },
	},
	defaultAim = "Chest",

	-- The switches on the panel's "You" page, in the order they are listed.
	cheats = {
		{ name = "reserve", title = "Endless reserve", note = "Spare ammunition never runs down; you still reload" },
		{ name = "magazine", title = "No reloading", note = "The magazine never runs down" },
		{ name = "grenades", title = "Endless grenades", note = "A grenade thrown is back in its slot at once" },
		{ name = "tactical", title = "Endless tactical", note = "The tactical item can be used again and again" },
		{ name = "instant", title = "Loadout at once", note = "A loadout change takes effect now, not at the next spawn" },
		{ name = "god", title = "God mode", note = "Nothing takes your health. Hits are still reported" },
	},

	hurt = { 10, 25, 50 }, -- the plain amounts the panel can take off your health

	readout = {
		runGap = 3, -- seconds without a hit before the totals start again
		lines = 8, -- hits listed at once
	},

	marks = 12, -- seconds a bullet mark stays on the range, when they are set to stay
}
