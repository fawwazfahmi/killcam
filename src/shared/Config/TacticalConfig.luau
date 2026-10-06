-- Tactical items, used with Q. A player carries one kind per life. Plain Luau
-- only, so the unit tests can load it.

return {
	default = "Stim",
	order = { "Stim", "Cryo" }, -- the order the loadout menu lists them in
	useTime = 0.6, -- seconds between pressing Q and the effect; Trigger gloves remove it

	items = {
		Stim = {
			displayName = "Heal Stim",
			note = "Restores health over two seconds",
			uses = 1,
			heal = 60,
			healTime = 2,
		},
		Cryo = {
			displayName = "Cryo Shot",
			note = "Being hit does not throw your aim for a while",
			uses = 1,
			duration = 8,
		},

	},
}
