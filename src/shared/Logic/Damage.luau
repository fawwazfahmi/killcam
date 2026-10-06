local Damage = {}

local ZONES = {
	Head = "Head",
	UpperTorso = "UpperTorso",
	LowerTorso = "LowerTorso",
	HumanoidRootPart = "UpperTorso",
}

-- Maps an R15 body part name to a damage zone. Arms, legs, hands and feet are limbs.
function Damage.zoneForPart(partName)
	return ZONES[partName] or "Limb"
end

function Damage.gun(weapon, zone)
	return weapon.damage[zone] or weapon.damage.Limb
end

-- Positions and look vector are anything with X and Z fields. A hit counts as
-- a backstab when the attacker stands inside the cone behind the target.
function Damage.knife(knife, attackerPosition, targetPosition, targetLook)
	local dx = targetPosition.X - attackerPosition.X
	local dz = targetPosition.Z - attackerPosition.Z
	local distance = math.sqrt(dx * dx + dz * dz)
	local lookLength = math.sqrt(targetLook.X * targetLook.X + targetLook.Z * targetLook.Z)
	if distance < 1e-4 or lookLength < 1e-4 then
		return knife.frontDamage
	end

	local dot = (dx * targetLook.X + dz * targetLook.Z) / (distance * lookLength)
	if dot >= knife.backCos then
		return knife.backDamage
	end
	return knife.frontDamage
end

function Damage.grenade(grenade, distance)
	if distance >= grenade.radius then
		return 0
	end
	return grenade.maxDamage * (1 - distance / grenade.radius)
end

-- `speed` is how fast the player was falling, in studs per second, when they
-- landed. `scale` is their boots' multiplier.
function Damage.fall(rules, speed, scale)
	return math.max(speed - rules.safeSpeed, 0) * rules.damagePerSpeed * scale
end

return Damage
