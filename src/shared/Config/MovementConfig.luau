return {
	runSpeed = 20, -- studs per second
	crouchSpeed = 10,
	accelTime = 0.12, -- seconds from standstill to full speed
	stopTime = 0.15, -- seconds from full speed to standstill
	airControl = 0.3, -- fraction of ground steering available in the air
	jumpHeight = 6, -- studs
	landingMinAirTime = 0.3, -- air time needed before a landing slows you
	landingDuration = 0.2,
	landingSpeedFactor = 0.6,
	crouchHipDrop = 1.0, -- studs the body lowers while crouched

	-- Landing faster than safeSpeed hurts. At normal gravity a 9 stud drop is
	-- safe, 12 studs costs about 14 health and 24 studs about 59.
	fall = { safeSpeed = 60, damagePerSpeed = 1.6 },
}
