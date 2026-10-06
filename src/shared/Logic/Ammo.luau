-- Ammunition. A gun starts each life with a full magazine and its reserve,
-- and that is all there is: nothing in the game refills it. A reload tops the
-- magazine up from the reserve and wastes nothing, so rounds left in the
-- magazine are kept. Pure rules; `config` is a gun from WeaponConfig and
-- `ammo` is { mag, reserve }.

local Ammo = {}

function Ammo.full(config)
	return { mag = config.magazine, reserve = config.reserve }
end

function Ammo.canReload(config, ammo)
	return ammo.mag < config.magazine and ammo.reserve > 0
end

-- Moves rounds from the reserve into the magazine. Returns how many moved.
function Ammo.reload(config, ammo)
	local moved = math.max(math.min(config.magazine - ammo.mag, ammo.reserve), 0)
	ammo.mag += moved
	ammo.reserve -= moved
	return moved
end

return Ammo
