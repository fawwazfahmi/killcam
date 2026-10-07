-- Points, levels and rentals. Pure rules over a player's profile:
--
--   profile = {
--     points = number, xp = number, level = number,
--     rentals = { ["field/option"] = { seconds = number, expiresAt = number? } },
--     expired = { ["field/option"] = true },  -- ran out, and the player has not been told yet
--     revives = number,                       -- revives paid for and not yet used
--     swaps = number,                         -- mid-match armour changes paid for and not yet used
--     weapons = { [class] = { xp = number, peak = { name, tier } } },  -- see Prestige
--   }
--
-- A rental holds `seconds` of time, and runs down in one of two ways,
-- depending on its loadout field (ShopConfig.timing):
--
--   "use"       `seconds` drops only as the item is used (see Economy.consume).
--               `expiresAt` is never set.
--   "calendar"  `expiresAt` is nil until the option is first taken into a
--               match; from then it runs out at that time whether or not the
--               player is online.
--
-- A rental that runs out in the middle of a match is not taken away there and
-- then. Every function that asks "may they use this?" takes an optional `held`:
-- the set of rental names the player has already taken into the match they are
-- in. Anything in it stays usable until that match is over.
--
-- `now` is always a clock in seconds, such as os.time().

local Economy = {}

function Economy.key(field, option)
	return field .. "/" .. option
end

function Economy.newProfile()
	return { points = 0, xp = 0, level = 1, rentals = {}, expired = {}, revives = 0, swaps = 0, weapons = {} }
end

-- Experience needed to leave `level`.
function Economy.xpForLevel(config, level)
	return config.levels.base + config.levels.step * (level - 1)
end

-- Points for one finished match. `result` is
--   { kills, deaths, assists, objectives, won, mvp, seconds }
-- where `objectives` is plants and defuses together and `seconds` is how long
-- the player was in the match.
--
-- Somebody who did nothing at all earns nothing, whichever side won: that is
-- a player sent into a match as it ended, or one who stood idle. Somebody who
-- was only there briefly earns a share.
function Economy.matchReward(config, result)
	local rewards = config.rewards
	if result.kills + result.deaths + result.assists + result.objectives == 0 then
		return 0
	end
	local points = result.kills * rewards.perKill + (if result.won then rewards.win else rewards.loss)
	if result.mvp then
		points += rewards.mvp
	end
	if result.seconds < rewards.shortStay then
		points = math.floor(points * rewards.shortShare + 0.5)
	end
	return points
end


-- Pays `points` into the profile as both points and experience. Returns how
-- many levels were gained; each one pays the level bonus as well.
function Economy.addReward(config, profile, points)
	profile.points += points
	profile.xp += points
	local gained = 0
	while profile.level < config.levels.max and profile.xp >= Economy.xpForLevel(config, profile.level) do
		profile.xp -= Economy.xpForLevel(config, profile.level)
		profile.level += 1
		profile.points += config.levels.bonus
		gained += 1
	end
	if profile.level >= config.levels.max then
		profile.xp = 0 -- there is nothing further to earn it towards
	end
	return gained
end

-- The field an option is sold and owned under. A second primary is the same
-- item as a first, so it is owned as a primary (see ShopConfig.aliases).
function Economy.shopField(config, field)
	return config.aliases and config.aliases[field] or field
end

-- The lengths an option is rented for with Robux, { { amount, productId } },
-- or nil if it is not one of the premium ones (see ShopConfig.robux).
function Economy.robuxOffers(config, field, option)
	local offers = config.robux and config.robux[Economy.shopField(config, field)]
	return offers and offers[option] or nil
end

-- True if nobody has to pay for this option, in points or in Robux.
function Economy.isFree(config, field, option)
	local prices = config.prices[Economy.shopField(config, field)]
	return not (prices and prices[option]) and Economy.robuxOffers(config, field, option) == nil
end

-- How rentals of this field run down and what lengths are sold: an entry of
-- ShopConfig.terms. Nil for an unknown field.
function Economy.terms(config, field)
	return config.terms[config.timing[field]]
end

-- Points to rent an option for `amount` units (hours of use, or days), or nil
-- if that is not on sale.
function Economy.price(config, field, option, amount)
	local prices = config.prices[field]
	local unitPrice = prices and prices[option]
	local terms = Economy.terms(config, field)
	if not unitPrice or not terms then
		return nil
	end
	for _, length in terms.lengths do
		if length.amount == amount then
			return math.floor(unitPrice * length.price + 0.5)
		end
	end
	return nil
end

local function expired(rental, now)
	return rental.seconds <= 0 or (rental.expiresAt ~= nil and rental.expiresAt <= now)
end

-- Takes away rentals that have run out, and notes each one in
-- `profile.expired` so the player can be told. Returns whether any did.
function Economy.prune(profile, now)
	local any = false
	for name, rental in profile.rentals do
		if expired(rental, now) then
			profile.rentals[name] = nil
			profile.expired[name] = true
			any = true
		end
	end
	return any
end

-- The player has seen what ran out.
function Economy.acknowledge(profile)
	profile.expired = {}
end

-- True if the player may put this option in a loadout right now.
function Economy.owns(config, profile, field, option, now, held)
	if Economy.isFree(config, field, option) then
		return true
	end
	local name = Economy.key(Economy.shopField(config, field), option)
	if held and held[name] then
		return true
	end
	local rental = profile.rentals[name]
	return rental ~= nil and not expired(rental, now)
end

-- Seconds left on a rental: of use, or until it expires. For a calendar
-- rental whose clock has not started, the whole unused time. Zero if none.
function Economy.timeLeft(profile, field, option, now)
	local rental = profile.rentals[Economy.key(field, option)]
	if not rental then
		return 0
	elseif not rental.expiresAt then
		return math.max(rental.seconds, 0)
	end
	return math.max(rental.expiresAt - now, 0)
end

-- Puts `amount` units of rental (hours of use, or days) on an option. More of
-- something already held adds to it.
local function addTime(config, profile, field, option, amount)
	local seconds = amount * Economy.terms(config, field).unit
	local name = Economy.key(field, option)
	local rental = profile.rentals[name]
	profile.expired[name] = nil -- renewed, so there is nothing left to tell them
	if not rental then
		profile.rentals[name] = { seconds = seconds }
	elseif rental.expiresAt then
		rental.expiresAt += seconds -- already running: push the end back
	else
		rental.seconds += seconds
	end
end

-- Rents an option with points. Returns true, or false and why: "NotForSale"
-- (which is what a premium option is, for points) or "NotEnoughPoints".
function Economy.buy(config, profile, field, option, amount, now)
	local cost = Economy.price(config, field, option, amount)
	if not cost then
		return false, "NotForSale"
	end
	if profile.points < cost then
		return false, "NotEnoughPoints"
	end
	Economy.prune(profile, now)
	profile.points -= cost
	addTime(config, profile, field, option, amount)
	return true
end

-- Called when an option is taken into a match. Starts a calendar rental's
-- clock if this is its first use, and adds it to `held`. Returns whether the
-- player may use it.
function Economy.use(config, profile, field, option, now, held)
	if Economy.isFree(config, field, option) then
		return true
	end
	field = Economy.shopField(config, field)
	local name = Economy.key(field, option)
	if held and held[name] then
		return true
	end
	local rental = profile.rentals[name]
	if not rental or expired(rental, now) then
		return false
	end
	if config.timing[field] == "calendar" and not rental.expiresAt then
		rental.expiresAt = now + rental.seconds
	end
	if held then
		held[name] = true
	end
	return true
end

-- The player was alive in a match with `loadout` for `seconds`: takes that off
-- every "use" rental in it. Calendar rentals are untouched.
function Economy.consume(config, profile, loadout, seconds)
	for field, option in loadout do
		field = Economy.shopField(config, field)
		if config.timing[field] == "use" then
			local rental = profile.rentals[Economy.key(field, option)]
			if rental then
				rental.seconds = math.max(rental.seconds - seconds, 0)
			end
		end
	end
end

-- True if the player may pick every option in `loadout`.
function Economy.ownsAll(config, profile, loadout, now, held)
	for field, option in loadout do
		if not Economy.owns(config, profile, field, option, now, held) then
			return false
		end
	end
	return true
end

-- A copy of `loadout` with anything the player may not use swapped for the
-- default. Nothing else changes: no clock is started.
function Economy.fallback(config, profile, loadout, defaults, now)
	local allowed = {}
	for field, option in loadout do
		allowed[field] = if Economy.owns(config, profile, field, option, now) then option else defaults[field]
	end
	return allowed
end

-- The loadout a player spawns with: `loadout` with anything they may not use
-- swapped for the default, the clock started on every calendar rental left in
-- it, and all of it held for the rest of the match.
function Economy.equip(config, profile, loadout, defaults, now, held)
	local allowed = {}
	for field, option in loadout do
		allowed[field] = if Economy.use(config, profile, field, option, now, held) then option else defaults[field]
	end
	return allowed
end

-- Changing weapons in a match ---------------------------------------------------

-- A player is about to start a life with `wanted` after one with `previous`.
-- Each weapon or grenade in `wanted` that they were not carrying before costs
-- ShopConfig.matchSwap.weaponPoints; moving the same weapons between slots,
-- or carrying fewer, costs nothing.
--
-- Returns the loadout they get, what it cost, and whether the change went
-- through. If they cannot pay for all of it, none of it happens: they keep
-- the weapons they had, and whatever else `wanted` holds.
function Economy.chargeSwaps(config, profile, previous, wanted, weaponFields)
	local had = {}
	for _, field in weaponFields do
		if previous[field] then
			had[previous[field]] = true
		end
	end
	local new = 0
	for _, field in weaponFields do
		if wanted[field] and not had[wanted[field]] then
			new += 1
		end
	end

	local cost = new * config.matchSwap.weaponPoints
	if cost > profile.points then
		local kept = table.clone(wanted)
		for _, field in weaponFields do
			kept[field] = previous[field]
		end
		return kept, 0, false
	end
	profile.points -= cost
	return wanted, cost, true
end

-- Things paid for with Robux ----------------------------------------------------
-- A purchase becomes a count on the profile ("revives" or "swaps") and is
-- spent from there, so one that arrives too late to use is kept, not lost. Or
-- it is a rental of one of the premium options, and becomes time on that.

local RECEIPTS_KEPT = 30

-- Notes that the purchase `receipt` names has been paid for. Returns whether
-- it was new: the same one is only ever counted once, however often Roblox
-- reports it.
local function record(profile, receipt)
	local receipts = profile.receipts or {}
	profile.receipts = receipts
	if table.find(receipts, receipt) then
		return false
	end
	table.insert(receipts, receipt)
	while #receipts > RECEIPTS_KEPT do
		table.remove(receipts, 1)
	end
	return true
end

-- A purchase of one `kind` has been paid for. Returns whether it was new.
function Economy.grant(profile, kind, receipt)
	if not record(profile, receipt) then
		return false
	end
	profile[kind] = (profile[kind] or 0) + 1
	return true
end

-- What developer product `productId` rents: { field, option, amount }, or nil
-- if it is not one of the premium rentals. Product 0 is nothing's.
function Economy.offerFor(config, productId)
	if productId == 0 then
		return nil
	end
	for field, options in config.robux or {} do
		for option, offers in options do
			for _, offer in offers do
				if offer.productId == productId then
					return { field = field, option = option, amount = offer.amount }
				end
			end
		end
	end
	return nil
end

-- A premium rental has been paid for: `offer` is what Economy.offerFor gave
-- for the product. Puts the time on the profile. Returns whether the purchase
-- was new.
function Economy.grantRental(config, profile, offer, receipt, now)
	if not record(profile, receipt) then
		return false
	end
	Economy.prune(profile, now)
	addTime(config, profile, offer.field, offer.option, offer.amount)
	return true
end

-- Uses up one of `kind`. Returns false if the player has none.
function Economy.spend(profile, kind)
	if (profile[kind] or 0) <= 0 then
		return false
	end
	profile[kind] -= 1
	return true
end

return Economy
