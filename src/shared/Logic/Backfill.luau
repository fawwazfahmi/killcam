-- Filling the place of a player who left a match in progress. A short-handed
-- match advertises a "seat": a record that lobbies read and claim from.
--
--   seat = {
--     accessCode = string,  -- what a lobby needs to send players to the match
--     missing = number,     -- places empty right now
--     gap = number,         -- the most of them that are on any one team
--     transit = number,     -- of those, how many have a player on the way
--     transitAt = number?,  -- when the latest of them was sent
--   }
--
-- Pure rules. `now` is a clock in seconds that every server agrees on, such
-- as os.time().

local Backfill = {}

local ROUND_PHASES = { Prep = true, Live = true, Planted = true, RoundOver = true }

-- Whether a match should be sent anybody: always, while it is being played,
-- however close to its end. Somebody who arrives too late to do anything
-- earns nothing for it (see Economy.matchReward). `match` is { mode, phase }.
function Backfill.wanted(match)
	if match.mode == "SND" then
		return ROUND_PHASES[match.phase] == true
	end
	return match.phase == "Playing"
end

-- Places a lobby may still claim.
function Backfill.open(seat)
	return math.max(seat.missing - seat.transit, 0)
end

-- The most places empty on any one team, which is the biggest squad that
-- could be sent in without splitting it. `counts` is how many players each
-- team has and `expected` how many the match started with. With no teams (a
-- free-for-all) pass an empty `counts`: every empty place will do.
function Backfill.gap(counts, expected)
	local teams, present, widest = 0, 0, 0
	for _, count in counts do
		teams += 1
		present += count
	end
	if teams == 0 then
		return expected
	end
	for _, count in counts do
		widest = math.max(widest, expected // teams - count)
	end
	return math.min(widest, math.max(expected - present, 0))
end

-- The match renewing its seat. `missing` is how many places are empty now,
-- `gap` the most on one team, and `arrived` how many players have joined
-- since it last renewed. Players a lobby sent who have not arrived within
-- `transitTimeout` are given up on, so their places are offered again.
-- Returns the seat, or nil if the match is full.
function Backfill.refresh(old, accessCode, missing, gap, arrived, now, transitTimeout)
	if missing <= 0 then
		return nil
	end
	local transit = math.max((old and old.transit or 0) - arrived, 0)
	local transitAt = old and old.transitAt
	if transit > 0 and transitAt and now - transitAt > transitTimeout then
		transit = 0
	end
	return {
		accessCode = accessCode,
		missing = missing,
		gap = math.min(gap, missing),
		transit = math.min(transit, missing),
		transitAt = if transit > 0 then transitAt else nil,
	}
end

-- A lobby claiming places for a group of `size` who must stay together: one
-- player, or a squad. All of them get in or none do. A squad needs room on a
-- single team, and is only sent while nobody else is on the way, because
-- until they land the seat cannot say which team the room is on.
--
-- Returns the seat as it should be stored and true; or nil and false, in
-- which case nothing should be stored.
function Backfill.claim(seat, size, now)
	if not seat or size > Backfill.open(seat) then
		return nil, false
	end
	if size > 1 and (size > seat.gap or seat.transit > 0) then
		return nil, false
	end
	return {
		accessCode = seat.accessCode,
		missing = seat.missing,
		gap = seat.gap,
		transit = seat.transit + size,
		transitAt = now,
	}, true
end

-- `counts` is how many players each side of a match has. Returns the one side
-- that still has anybody, if every other side is empty; otherwise nil. A
-- match with a single side has nobody who could have left.
function Backfill.lastSide(counts)
	local sides, last = 0, nil
	for side, count in counts do
		sides += 1
		if count > 0 then
			if last then
				return nil
			end
			last = side
		end
	end
	return if sides > 1 then last else nil
end

return Backfill
