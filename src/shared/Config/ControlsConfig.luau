-- What the player presses for each thing they can do in a match. One table
-- for all three kinds of device, so nothing is possible on one and missing on
-- another. Plain Luau only, so the unit tests can load it; the names are those
-- of Enum.KeyCode and Enum.UserInputType.
--
--   keys    keyboard keys
--   mouse   a mouse button
--   pad     controller buttons
--   touch   the button drawn on a touch screen: its label, its size in pixels,
--           and where its middle sits, measured from the bottom right corner
--           of the screen (or from the top right, with `top = true`)
--   hold    true if it is something held down (fire), false if pressed (reload)
--   switch  for something held: the devices on which it is a switch instead,
--           one press on and the next off, because holding it is awkward there
--
-- Moving, looking and jumping are not here: Roblox handles those on every
-- device already, and the space bar and the controller's A are left to it.

local SWITCH_OFF_KEYBOARD = { pad = true, touch = true }

return {
	actions = {
		Fire = {
			hold = true, keys = {}, mouse = "MouseButton1", pad = { "ButtonR2" },
			touch = { label = "FIRE", size = 84, at = { -96, -196 } },
		},
		Scope = {
			hold = true, switch = { touch = true }, keys = {}, mouse = "MouseButton2", pad = { "ButtonL2" },
			touch = { label = "AIM", size = 62, at = { -200, -170 } },
		},
		Reload = {
			hold = false, keys = { "R" }, pad = { "ButtonX" },
			touch = { label = "RELOAD", size = 56, at = { -194, -86 } },
		},
		Tactical = {
			hold = false, keys = { "E" }, pad = { "ButtonL1" },
			touch = { label = "TAC", size = 52, at = { -150, -272 } },
		},
		-- Back to the weapon held before this one.
		QuickSwitch = { hold = false, keys = { "Q" }, pad = { "ButtonR3" } },
		-- On to the next weapon carried. The mouse wheel does this too.
		NextWeapon = {
			hold = false, keys = {}, pad = { "ButtonR1" },
			touch = { label = "SWAP", size = 52, at = { -60, -296 } },
		},
		Drop = {
			hold = false, keys = { "G" }, pad = { "ButtonL3" },
			touch = { label = "DROP", size = 44, at = { -252, -232 } },
		},
		Crouch = {
			hold = true, switch = SWITCH_OFF_KEYBOARD, keys = { "LeftControl", "C" }, pad = { "ButtonB" },
			touch = { label = "CROUCH", size = 52, at = { -268, -60 } },
		},
		-- Held to defuse the bomb; pressed, when dead, to take a revive.
		Use = {
			hold = true, keys = { "F" }, pad = { "ButtonY" },
			touch = { label = "USE", size = 52, at = { -272, -144 } },
		},
		-- The loadout menu. On a keyboard that is B, which the menu handles itself.
		Loadout = {
			hold = false, keys = {}, pad = { "ButtonSelect" },
			touch = { label = "KIT", size = 46, at = { -44, 108 }, top = true },
		},
		-- The number keys: 1 again reaches a second primary, 4 again a second grenade.
		Slot1 = { hold = false, keys = { "One" }, pad = { "DPadUp" } },
		Slot2 = { hold = false, keys = { "Two" }, pad = { "DPadLeft" } },
		Slot3 = { hold = false, keys = { "Three" }, pad = { "DPadDown" } },
		Slot4 = { hold = false, keys = { "Four" }, pad = { "DPadRight" } },
		Slot5 = { hold = false, keys = { "Five" }, pad = {} },
	},

	-- How a key or button is written in a prompt, where its own name is too long.
	short = {
		MouseButton1 = "LMB", MouseButton2 = "RMB", LeftControl = "CTRL",
		One = "1", Two = "2", Three = "3", Four = "4", Five = "5",
		ButtonR2 = "R2", ButtonL2 = "L2", ButtonR1 = "R1", ButtonL1 = "L1", ButtonR3 = "R3", ButtonL3 = "L3",
		ButtonX = "X", ButtonY = "Y", ButtonB = "B", ButtonSelect = "VIEW",
		DPadUp = "D-UP", DPadLeft = "D-LEFT", DPadDown = "D-DOWN", DPadRight = "D-RIGHT",
	},
}
