-- How a flashbang looks to one player, from how directly they were facing it.
--
-- `facing` is the dot product of the player's view direction and the direction
-- to the flash: 1 looking straight at it, 0 side on, -1 with their back to it.
-- `seconds` is the longest this flash can blind for at the player's distance.
--
-- Looking at it: fully white, held, for the whole time. Turned away: a short,
-- partial wash that starts fading at once. In between it blends smoothly.

local Flash = {}

-- 0 turned away, 1 looking straight at it.
function Flash.exposure(config, facing)
	local t = (facing - config.facingNone) / (config.facingFull - config.facingNone)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t) -- smoothstep: no sudden jump at either end
end

-- Returns { opacity, duration, hold }:
--   opacity   how white the screen goes at its peak, 0 to 1
--   duration  seconds from the flash until the screen is clear again
--   hold      seconds it stays at the peak before it starts to fade
function Flash.effect(config, seconds, facing)
	local exposure = Flash.exposure(config, facing)
	local duration = seconds * (config.awayDuration + (1 - config.awayDuration) * exposure)
	return {
		opacity = config.awayOpacity + (1 - config.awayOpacity) * exposure,
		duration = duration,
		hold = duration * config.holdShare * exposure,
	}
end

return Flash
