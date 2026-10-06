-- Everything a player can pick for a loadout, as one list: the weapon fields,
-- the tactical item, then each armour slot. The shop, the profile and the
-- notice that a rental has run out all read it, so an item is named the same
-- way everywhere. Pure rules; the configs are passed in.

local Catalog = {}

-- { { field, title, source, order } } in the order the menus show them.
-- `source[option]` is the option's config, and `order` lists its options.
function Catalog.fields(weapons, tactical, armor)
	local list = {
		{ field = "primary", title = "Primary", source = weapons.Weapons, order = weapons.PrimaryOrder },
		{ field = "secondary", title = "Secondary", source = weapons.Weapons, order = weapons.SecondaryOrder },
		{ field = "melee", title = "Melee", source = weapons.Weapons, order = weapons.MeleeOrder },
		{ field = "nade", title = "Grenades", source = weapons.Weapons, order = weapons.NadeOrder },
		{ field = "tactical", title = "Tactical", source = tactical.items, order = tactical.order },
	}
	for _, slot in armor.slots do
		table.insert(list, { field = slot, title = armor.titles[slot], source = armor[slot], order = armor.order[slot] })
	end
	return list
end

-- The entry of `fields` for a loadout field, or nil.
function Catalog.field(fields, field)
	for _, entry in fields do
		if entry.field == field then
			return entry
		end
	end
	return nil
end

-- A rental's name ("field/option") as its field entry and the option's
-- config. Both nil if the game no longer has it.
function Catalog.find(fields, name)
	local field, option = string.match(name, "^(%w+)/(%w+)$")
	local entry = field and Catalog.field(fields, field)
	local item = entry and entry.source[option]
	if not item then
		return nil, nil
	end
	return entry, item
end

return Catalog
