-- Decides whether the server accepts what a client claims. Pure: every fact
-- about the world is passed in, so each rule can be unit-tested.

local HitValidation = {}

local function distance(a, b)
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

HitValidation.distance = distance

--[[
	shot = {
		now, ammo, reloading,
		equippedAt, equipTime,
		nextShotAt, lastShotAt, fireInterval, quickSwitchInterval?, reEquipped,
		origin, shooterHead,
	}
]]
function HitValidation.canFire(validation, shot)
	if shot.reloading then
		return false, "Reloading"
	end
	if shot.ammo <= 0 then
		return false, "NoAmmo"
	end

	local slack = math.min(validation.jitterSlack, shot.fireInterval * 0.6)
	if shot.now - shot.equippedAt < shot.equipTime - slack then
		return false, "Equipping"
	end

	-- Putting the weapon away and drawing it again skips the rest of the
	-- rechamber, down to the weapon's quick-switch interval.
	local readyAt = shot.nextShotAt
	if shot.reEquipped and shot.quickSwitchInterval then
		readyAt = math.min(readyAt, shot.lastShotAt + shot.quickSwitchInterval)
	end
	if shot.now < readyAt - slack then
		return false, "TooFast"
	end

	if distance(shot.origin, shot.shooterHead) > validation.originTolerance then
		return false, "BadOrigin"
	end
	return true, nil
end

-- Earliest time the next shot is due. Early arrivals within the slack are
-- accepted without letting the average fire rate creep up.
function HitValidation.advance(now, nextShotAt, fireInterval)
	return math.max(nextShotAt, now) + fireInterval
end

--[[
	hit = {
		targetAlive, sameTeam, protected,
		origin, hitPosition, targetPosition, range, blocked,
	}
]]
function HitValidation.validateHit(validation, hit)
	if not hit.targetAlive then
		return false, "TargetDead"
	end
	if hit.sameTeam then
		return false, "SameTeam"
	end
	if hit.protected then
		return false, "Protected"
	end
	if distance(hit.origin, hit.hitPosition) > hit.range then
		return false, "OutOfRange"
	end
	if distance(hit.hitPosition, hit.targetPosition) > validation.targetTolerance then
		return false, "TargetMismatch"
	end
	if hit.blocked then
		return false, "Blocked"
	end
	return true, nil
end

return HitValidation
