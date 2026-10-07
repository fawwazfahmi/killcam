-- The test range's dummies: what can be set on one, what a hit does to it, and
-- when one that shoots back fires. Pure rules; the configs are passed in.
--
-- A dummy's settings:
--   dies      whether a hit that would kill it does. If not, it is put back to
--             full health on the spot, so it can be shot again at once
--   helmet    a helmet from ArmorConfig, or BARE
--   body      body armour from ArmorConfig, or BARE
--   moves     whether it walks from side to side
--   crouched  whether it is crouching
--   weapon    the gun it shoots back with, or UNARMED
--   aim       where it aims, one of RangeConfig.aims

local Dummy = {}

Dummy.BARE = "" -- no helmet, or no body armour
Dummy.UNARMED = "" -- it does not shoot back

Dummy.FIELDS = { "dies", "helmet", "body", "moves", "crouched", "weapon", "aim" }

local LATE = 0.1 -- seconds a shot can be overdue and still keep to the cadence

-- A new dummy wears what a new player does, so the numbers are the ones met
-- in a match.
function Dummy.defaults(armor, config)
	return {
		dies = true,
		helmet = armor.defaults.helmet,
		body = armor.defaults.body,
		moves = false,
		crouched = false,
		weapon = Dummy.UNARMED,
		aim = config.defaultAim,
	}
end

-- The body part a dummy told to aim at `aim` goes for, or nil if there is no such aim.
function Dummy.aimPart(config, aim)
	for _, entry in config.aims do
		if entry.name == aim then
			return entry.part
		end
	end
	return nil
end

-- A copy of `settings` with `field` set to `value`, or nil if that is not
-- something a dummy can be set to. Both come from a client, so neither is
-- trusted.
function Dummy.changed(weapons, armor, config, settings, field, value)
	local valid = false
	if field == "dies" or field == "moves" or field == "crouched" then
		valid = type(value) == "boolean"
	elseif field == "helmet" or field == "body" then
		valid = type(value) == "string" and (value == Dummy.BARE or armor[field][value] ~= nil)
	elseif field == "weapon" then
		local gun = type(value) == "string" and weapons.Weapons[value]
		valid = value == Dummy.UNARMED or (type(gun) == "table" and gun.kind == "Gun")
	elseif field == "aim" then
		valid = type(value) == "string" and Dummy.aimPart(config, value) ~= nil
	end
	if not valid then
		return nil
	end
	local copy = table.clone(settings)
	copy[field] = value
	return copy
end

-- What a hit for `amount` does to a dummy with `health` left of `full`:
--   left    its health afterwards
--   lethal  whether the hit would have killed
--   died    whether it did
function Dummy.strike(settings, health, full, amount)
	if amount < health then
		return { left = health - amount, lethal = false, died = false }
	elseif settings.dies then
		return { left = 0, lethal = true, died = true }
	end
	return { left = full, lethal = true, died = false }
end

-- A gun in a dummy's hands: `config` is the gun's, from WeaponConfig.
function Dummy.newGun(config)
	return { mag = config.magazine, readyAt = 0 }
end

-- Whether the dummy fires at `now`. It fires as fast as the gun does, empties
-- the magazine and reloads, as a player holding the trigger would. A shot that
-- falls due between two looks is not made up for by firing late: the next one
-- is still timed from when this one was due.
function Dummy.pull(config, gun, now)
	if now < gun.readyAt then
		return false
	end
	local due = if now - gun.readyAt < LATE then gun.readyAt else now
	gun.mag -= 1
	if gun.mag <= 0 then
		gun.mag = config.magazine
		gun.readyAt = due + config.reloadTime
	else
		gun.readyAt = due + config.fireInterval
	end
	return true
end

return Dummy
