-- What a player takes into a life: a primary, a secondary, a melee weapon, a
-- grenade, a tactical item and four armour pieces. One of each, unless their
-- gloves add a second primary (`primary2`) or a second grenade (`nade2`);
-- those two fields are optional and nil when nothing is picked. Pure rules;
-- the configs are passed in.

local Loadout = {}

-- The weapon choices, and the rest ("pieces": the tactical item and armour).
Loadout.WEAPON_FIELDS = { "primary", "primary2", "secondary", "melee", "nade", "nade2" }

function Loadout.pieceFields(armor)
	local fields = { "tactical" }
	for _, slot in armor.slots do
		table.insert(fields, slot)
	end
	return fields
end

-- The optional weapon fields: which field each must differ from, and the
-- armour stat that lets it be carried.
Loadout.SECOND = {
	primary2 = { first = "primary", stat = "secondPrimary" },
	nade2 = { first = "nade", stat = "secondNade" },
}

-- Slot numbers. An empty slot holds `false`, never nil, so the list always
-- has seven entries and survives being sent to the client.
Loadout.PRIMARY, Loadout.SECONDARY, Loadout.MELEE, Loadout.NADE, Loadout.BOMB = 1, 2, 3, 4, 5
Loadout.PRIMARY2, Loadout.NADE2 = 6, 7
Loadout.SLOT_COUNT = 7

-- The slots each number key reaches. Pressing a key again steps to its next
-- slot, so 1 goes to the primary and 1 again to the second primary.
Loadout.KEYS = {
	{ Loadout.PRIMARY, Loadout.PRIMARY2 },
	{ Loadout.SECONDARY },
	{ Loadout.MELEE },
	{ Loadout.NADE, Loadout.NADE2 },
	{ Loadout.BOMB },
}

-- The order the slots come in when stepping through them all.
Loadout.ORDER = {
	Loadout.PRIMARY,
	Loadout.PRIMARY2,
	Loadout.SECONDARY,
	Loadout.MELEE,
	Loadout.NADE,
	Loadout.NADE2,
	Loadout.BOMB,
}

function Loadout.default(weapons, tactical, armor)
	local loadout = {
		primary = weapons.DefaultPrimary,
		secondary = weapons.DefaultSecondary,
		melee = weapons.DefaultMelee,
		nade = weapons.DefaultNade,
		tactical = tactical.default,
	}
	for _, slot in armor.slots do
		loadout[slot] = armor.defaults[slot]
	end
	return loadout
end

-- Returns a clean copy of `choice` if every field names a real option,
-- otherwise nil. `choice` comes from a client, so nothing about it is trusted.
function Loadout.sanitize(weapons, tactical, armor, choice)
	if type(choice) ~= "table" then
		return nil
	end
	if type(choice.primary) ~= "string" or not weapons.Primaries[choice.primary] then
		return nil
	end
	if type(choice.secondary) ~= "string" or not weapons.Secondaries[choice.secondary] then
		return nil
	end
	if type(choice.melee) ~= "string" or not weapons.Melees[choice.melee] then
		return nil
	end
	if type(choice.nade) ~= "string" or not weapons.Nades[choice.nade] then
		return nil
	end
	if type(choice.tactical) ~= "string" or not tactical.items[choice.tactical] then
		return nil
	end
	-- The second primary and grenade are optional, but if given must be real.
	if choice.primary2 ~= nil and (type(choice.primary2) ~= "string" or not weapons.Primaries[choice.primary2]) then
		return nil
	end
	if choice.nade2 ~= nil and (type(choice.nade2) ~= "string" or not weapons.Nades[choice.nade2]) then
		return nil
	end
	local clean = {
		primary = choice.primary,
		-- Never two of the same: a second that matches the first is dropped.
		primary2 = if choice.primary2 ~= choice.primary then choice.primary2 else nil,
		secondary = choice.secondary,
		melee = choice.melee,
		nade = choice.nade,
		nade2 = if choice.nade2 ~= choice.nade then choice.nade2 else nil,
		tactical = choice.tactical,
	}
	for _, slot in armor.slots do
		local name = choice[slot]
		if type(name) ~= "string" or not armor[slot][name] then
			return nil
		end
		clean[slot] = name
	end
	return clean
end

-- Combines the four pieces into one table of numbers. Multipliers multiply.
-- A slot with nothing in it adds nothing: a player always wears all four, but
-- one of the test range's dummies can go bare.
function Loadout.stats(armor, loadout)
	local stats = {
		headScale = 1,
		classScale = {},
		speed = 1,
		speedWith = {},
		equipScale = 1,
		tacticalScale = 1,
		footsteps = 1,
		hearing = 1,
		fallScale = 1,
		steady = false,
		secondPrimary = false,
		secondNade = false,
	}
	for _, slot in armor.slots do
		local piece = armor[slot][loadout[slot]] or {}
		stats.headScale *= piece.headScale or 1
		stats.speed *= piece.speed or 1
		stats.equipScale *= piece.equipScale or 1
		stats.tacticalScale *= piece.tacticalScale or 1
		stats.footsteps *= piece.footsteps or 1
		stats.hearing *= piece.hearing or 1
		stats.fallScale *= piece.fallScale or 1
		stats.steady = stats.steady or piece.steady == true
		stats.steady = stats.steady or piece.steady == true
		stats.secondPrimary = stats.secondPrimary or piece.secondPrimary == true
		stats.secondNade = stats.secondNade or piece.secondNade == true
		for class, scale in piece.classScale or {} do
			stats.classScale[class] = (stats.classScale[class] or 1) * scale
		end
		for class, scale in piece.speedWith or {} do
			stats.speedWith[class] = (stats.speedWith[class] or 1) * scale
		end
	end
	return stats
end

function Loadout.isWeaponField(field)
	return table.find(Loadout.WEAPON_FIELDS, field) ~= nil
end

-- A copy of `current` with only its weapon choices taken from `wanted`.
function Loadout.withWeaponsFrom(current, wanted)
	local merged = table.clone(current)
	for _, field in Loadout.WEAPON_FIELDS do
		merged[field] = wanted[field]
	end
	return merged
end

-- A copy of `current` with only the listed fields taken from `wanted`.
function Loadout.withFieldsFrom(current, wanted, fields)
	local merged = table.clone(current)
	for _, field in fields do
		merged[field] = wanted[field]
	end
	return merged
end

-- Which of `fields` differ between two loadouts.
function Loadout.changed(a, b, fields)
	local different = {}
	for _, field in fields do
		if a[field] ~= b[field] then
			table.insert(different, field)
		end
	end
	return different
end

-- A copy of `loadout` holding only what is actually carried: a second primary
-- or grenade is left out unless the gloves worn allow it.
function Loadout.carried(loadout, stats)
	local carried = table.clone(loadout)
	for field, second in Loadout.SECOND do
		if not stats[second.stat] or carried[field] == carried[second.first] then
			carried[field] = nil
		end
	end
	return carried
end

-- The seven slots at spawn: primary, secondary, melee weapon, grenade, no
-- bomb, and the second primary and second grenade if the gloves carry them.
function Loadout.slots(_weapons, loadout, stats)
	local carried = Loadout.carried(loadout, stats)
	return {
		carried.primary,
		carried.secondary,
		carried.melee,
		carried.nade,
		false,
		carried.primary2 or false,
		carried.nade2 or false,
	}
end

-- The slot a number key (1 to 5) switches to, or nil if it has nothing to
-- offer. From another weapon it is the key's first filled slot; pressed again
-- while holding one of the key's own, it is the next.
function Loadout.slotForKey(slots, equipped, key)
	local group = Loadout.KEYS[key]
	if not group then
		return nil
	end
	local at = table.find(group, equipped)
	if not at then
		for _, slot in group do
			if slots[slot] then
				return slot
			end
		end
		return nil
	end
	for step = 1, #group - 1 do
		local slot = group[(at - 1 + step) % #group + 1]
		if slots[slot] then
			return slot
		end
	end
	return nil
end

-- The next filled slot after `equipped`, stepping forwards (1) or back (-1)
-- through all of them. Returns `equipped` if it is the only one.
function Loadout.nextSlot(slots, equipped, direction)
	local at = table.find(Loadout.ORDER, equipped) or 1
	for step = 1, #Loadout.ORDER - 1 do
		local slot = Loadout.ORDER[(at - 1 + step * direction) % #Loadout.ORDER + 1]
		if slots[slot] then
			return slot
		end
	end
	return equipped
end

-- The slot a gun picked up off the ground would go in, or nil if this player
-- cannot take it: one primary (two with the gloves for it), one handgun, and
-- never two of the same gun.
function Loadout.slotForPickup(weapons, slots, stats, name)
	for _, held in slots do
		if held == name then
			return nil
		end
	end
	if weapons.Primaries[name] then
		if not slots[Loadout.PRIMARY] then
			return Loadout.PRIMARY
		elseif stats.secondPrimary and not slots[Loadout.PRIMARY2] then
			return Loadout.PRIMARY2
		end
		return nil
	end
	return if not slots[Loadout.SECONDARY] then Loadout.SECONDARY else nil
end

-- The slot to switch to when the one in hand becomes empty.
function Loadout.fallbackSlot(slots)
	for _, slot in Loadout.ORDER do
		if slots[slot] then
			return slot
		end
	end
	return Loadout.MELEE
end

-- The gun left at a player's body when they die: a primary if they still
-- have one, otherwise the handgun. Returns the slot, or nil.
function Loadout.deathDropSlot(weapons, slots)
	for _, slot in { Loadout.PRIMARY, Loadout.PRIMARY2, Loadout.SECONDARY } do
		local name = slots[slot]
		if name and weapons.Weapons[name].kind == "Gun" then
			return slot
		end
	end
	return nil
end

-- Damage after the victim's armour. The helmet covers the head and body
-- armour everything else.
function Loadout.damage(stats, class, zone, amount)
	if zone == "Head" then
		return amount * stats.headScale
	end
	return amount * (stats.classScale[class] or 1)
end

-- How far a hit knocks the victim's aim, in degrees. `rules` is
-- WeaponConfig.Flinch. Armour that covers the hit takes the edge off: a
-- helmet that protects the head, for a headshot, and for anything else body
-- armour that protects against that class of weapon. Whether a piece covers a
-- hit is read from whether it takes damage off it, so the two cannot disagree.
-- Armour that covers nothing, or the wrong weapon, leaves the whole knock; a
-- helmet that keeps the aim steady leaves none.
function Loadout.flinch(rules, stats, class, headshot)
	if stats.steady then
		return 0
	end
	if headshot then
		return if stats.headScale < 1 then rules.head * rules.covered else rules.head
	end
	return if (stats.classScale[class] or 1) < 1 then rules.body * rules.covered else rules.body
end

-- How far a hit knocks the victim's aim, in degrees. `rules` is
-- WeaponConfig.Flinch. Armour that covers the hit takes the edge off: a
-- helmet that protects the head, for a headshot, and for anything else body
-- armour that protects against that class of weapon. Whether a piece covers a
-- hit is read from whether it takes damage off it, so the two cannot disagree.
-- Armour that covers nothing, or the wrong weapon, leaves the whole knock; a
-- helmet that keeps the aim steady leaves none.
function Loadout.flinch(rules, stats, class, headshot)
	if stats.steady then
		return 0
	end
	if headshot then
		return if stats.headScale < 1 then rules.head * rules.covered else rules.head
	end
	return if (stats.classScale[class] or 1) < 1 then rules.body * rules.covered else rules.body
end

-- Movement speed multiplier while holding a weapon of `class`.
function Loadout.speedScale(stats, class)
	return stats.speed * (stats.speedWith[class] or 1)
end

return Loadout
