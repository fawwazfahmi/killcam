local Recoil = {}

-- Camera kick for the Nth shot of a burst, in degrees: pitch (up), yaw (right).
-- Past the end of the pattern, entries from `loopFrom` onward repeat.
function Recoil.kickFor(recoil, shotIndex)
	local pattern = recoil.pattern
	local count = #pattern
	if count == 0 then
		return 0, 0
	end

	local index = math.max(shotIndex, 1)
	if index > count then
		local loopFrom = math.clamp(recoil.loopFrom or count, 1, count)
		index = loopFrom + (index - count - 1) % (count - loopFrom + 1)
	end

	local kick = pattern[index]
	return kick[1], kick[2]
end

-- Pulls a recoil offset back toward zero at `rate` degrees per second, along
-- the straight line to where it started, so the view returns the way it came.
-- It never overshoots zero, and never grows.
function Recoil.settle(rate, pitch, yaw, dt)
	local magnitude = math.sqrt(pitch * pitch + yaw * yaw)
	if magnitude <= 0 then
		return 0, 0
	end
	local scale = math.max(magnitude - rate * dt, 0) / magnitude
	return pitch * scale, yaw * scale
end

-- A pause longer than `resetTime` starts a new burst.
function Recoil.nextShotIndex(recoil, previousIndex, timeSinceLastShot)
	if timeSinceLastShot > recoil.resetTime then
		return 1
	end
	return previousIndex + 1
end

return Recoil
