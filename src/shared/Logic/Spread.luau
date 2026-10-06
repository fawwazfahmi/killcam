local Spread = {}

-- state: { moving: boolean, crouched: boolean, airborne: boolean }
function Spread.stanceFactor(stance, state)
	if state.airborne then
		return stance.airborne
	end
	local factor = state.moving and stance.moving or stance.still
	if state.crouched then
		factor *= stance.crouched
	end
	return factor
end

function Spread.addShot(spread, bloom)
	return math.min(bloom + spread.bloomPerShot, spread.maxBloom)
end

function Spread.decay(spread, bloom, dt)
	return math.max(bloom - spread.recovery * dt, 0)
end

-- Half-angle of the shot cone, in degrees.
function Spread.current(spread, stance, bloom, state, scoped)
	local base = spread.base
	if scoped and spread.scopedBase then
		local steady = not state.moving and not state.airborne
		base = steady and spread.scopedBase or (spread.scopedMovingBase or spread.scopedBase)
	end
	return (base + bloom) * Spread.stanceFactor(stance, state)
end

return Spread
