local MoveSmoothing = {}

-- Moves the current input vector (cx, cz) toward the wanted one (tx, tz).
-- Both have a length of at most 1, where 1 means full speed. The Humanoid is
-- fed the result, which is what gives movement its acceleration and slide.
function MoveSmoothing.step(config, cx, cz, tx, tz, dt, airborne)
	local dx, dz = tx - cx, tz - cz
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1e-5 then
		return tx, tz
	end

	local stopping = (tx * tx + tz * tz) < 1e-6
	local rate = 1 / (stopping and config.stopTime or config.accelTime)
	if airborne then
		rate *= config.airControl
	end

	local maxStep = rate * dt
	if distance <= maxStep then
		return tx, tz
	end
	return cx + dx / distance * maxStep, cz + dz / distance * maxStep
end

-- Speed multiplier just after touching down from a long enough fall or jump.
function MoveSmoothing.landingFactor(config, airTime, timeSinceLanding)
	if airTime > config.landingMinAirTime and timeSinceLanding < config.landingDuration then
		return config.landingSpeedFactor
	end
	return 1
end

return MoveSmoothing
