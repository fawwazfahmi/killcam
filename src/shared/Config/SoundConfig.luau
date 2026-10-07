-- Every sound the game plays. Plain Luau only, so the unit tests can load it.
--
--   id      "rbxassetid://<number>" for uploaded audio, "rbxasset://sounds/..."
--           for one that ships with Roblox, or "" for silence
--   volume  0 to 2
--   speed   playback speed: 2 is an octave up and half as long
--   range   studs it carries when it comes from somewhere in the world;
--           without one, it is only ever played for the player themselves
--
-- These are stand-ins made from the few sounds that ship with Roblox, played
-- faster or slower. Replace the ids with real audio as it is uploaded.

local EXPLOSION = "rbxasset://sounds/impact_explosion_03.mp3"
local LAND = "rbxasset://sounds/action_jump_land.mp3"
local GET_UP = "rbxasset://sounds/action_get_up.mp3"
local JUMP = "rbxasset://sounds/action_jump.mp3"
local TICK = "rbxasset://sounds/volume_slider.ogg"
local OUCH = "rbxasset://sounds/ouch.ogg"

return {
	sounds = {
		-- Gunshots: the sharper and faster, the lighter the gun.
		ShotRifle = { id = EXPLOSION, volume = 0.55, speed = 3.0, range = 320 },
		ShotSMG = { id = EXPLOSION, volume = 0.45, speed = 3.8, range = 240 },
		ShotSniper = { id = EXPLOSION, volume = 0.9, speed = 1.7, range = 520 },
		ShotHandgun = { id = EXPLOSION, volume = 0.5, speed = 3.4, range = 220 },

		Swing = { id = JUMP, volume = 0.5, speed = 1.8 },
		Reload = { id = GET_UP, volume = 0.5, speed = 1.5 },
		Equip = { id = TICK, volume = 0.4, speed = 0.7 },

		-- What your own shots did.
		Hit = { id = TICK, volume = 0.6, speed = 1.6 },
		Headshot = { id = TICK, volume = 0.8, speed = 2.4 },
		Kill = { id = LAND, volume = 0.7, speed = 1.9 },

		Hurt = { id = OUCH, volume = 0.5, speed = 1.1 },
		Explosion = { id = EXPLOSION, volume = 1.0, speed = 0.9, range = 420 },
		Flash = { id = EXPLOSION, volume = 0.7, speed = 2.2 },
	},

	-- The gunshot for each class of weapon (a weapon's `class` in WeaponConfig).
	shots = {
		Rifle = "ShotRifle",
		SMG = "ShotSMG",
		Sniper = "ShotSniper",
		Handgun = "ShotHandgun",
	},
}
