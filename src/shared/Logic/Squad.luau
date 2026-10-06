-- Squads: small groups who queue together and are never split up. Pure rules.
-- `config` is LobbyConfig.squad. Players are whatever the caller uses to tell
-- them apart (the lobby passes the Player objects themselves), and `now` is a
-- clock in seconds.
--
-- A player on their own is not in a squad: they simply lead themselves. A
-- squad comes into being when an invitation is accepted, is led by whoever
-- sent it, and ends when it is down to one.

local Squad = {}

function Squad.new()
	return {
		leaderOf = {}, -- [member] = their leader, for everybody in a squad (a leader leads themselves)
		members = {}, -- [leader] = everybody in their squad, leader first
		invites = {}, -- [player] = { [who invited them] = when it lapses }
	}
end

function Squad.leader(state, who)
	return state.leaderOf[who] or who
end

-- Everybody who goes where `who` goes, leader first. Just them, if alone.
function Squad.members(state, who)
	local list = state.members[Squad.leader(state, who)]
	return if list then table.clone(list) else { who }
end

-- `from` asks `to` to join their squad. Returns whether the invitation was
-- sent, and if not, why: "Self", "NotLeader", "Full" or "Already".
function Squad.invite(config, state, from, to, now)
	if from == to then
		return false, "Self"
	elseif Squad.leader(state, from) ~= from then
		return false, "NotLeader"
	elseif #Squad.members(state, from) >= config.size then
		return false, "Full"
	elseif Squad.leader(state, to) == from then
		return false, "Already"
	end
	local invites = state.invites[to] or {}
	state.invites[to] = invites
	invites[from] = now + config.inviteLasts
	return true
end

-- Who has an invitation waiting for `to`. Ones that have lapsed are dropped.
function Squad.invitesFor(state, to, now)
	local from = {}
	for sender, lapses in state.invites[to] or {} do
		if lapses > now then
			table.insert(from, sender)
		else
			state.invites[to][sender] = nil
		end
	end
	return from
end

-- `who` leaves their squad. If they led it, whoever joined first takes over;
-- if that leaves one player, the squad is over. Returns everybody whose squad
-- has changed, `who` included; nobody if they were not in one.
function Squad.leave(state, who)
	local leader = state.leaderOf[who]
	if not leader then
		return {}
	end
	local list = state.members[leader]
	local touched = table.clone(list)
	table.remove(list, table.find(list, who))
	state.leaderOf[who] = nil
	state.members[leader] = nil

	if #list > 1 then
		local newLeader = list[1]
		state.members[newLeader] = list
		for _, member in list do
			state.leaderOf[member] = newLeader
		end
	else
		for _, member in list do
			state.leaderOf[member] = nil
		end
	end
	return touched
end

-- `to` answers the invitation `from` sent them. Returns whether the answer
-- stood, why not if it did not ("NoInvite", "NotLeader" or "Full"), and
-- everybody whose squad has changed. Accepting leaves any squad they were in.
function Squad.answer(config, state, to, from, accept, now)
	local invites = state.invites[to]
	local lapses = invites and invites[from]
	if invites then
		invites[from] = nil
	end
	if not lapses or lapses <= now then
		return false, "NoInvite", {}
	elseif not accept then
		return true, nil, {}
	elseif Squad.leader(state, from) ~= from then
		return false, "NotLeader", {} -- they have since joined somebody else's
	elseif #Squad.members(state, from) >= config.size then
		return false, "Full", {}
	end

	local touched = Squad.leave(state, to)
	local list = state.members[from] or { from }
	state.members[from] = list
	state.leaderOf[from] = from
	table.insert(list, to)
	state.leaderOf[to] = from
	for _, member in list do
		if not table.find(touched, member) then
			table.insert(touched, member)
		end
	end
	return true, nil, touched
end

-- `who` has gone altogether: out of their squad, and out of every invitation.
-- Returns everybody whose squad has changed.
function Squad.remove(state, who)
	local touched = Squad.leave(state, who)
	state.invites[who] = nil
	for _, invites in state.invites do
		invites[who] = nil
	end
	return touched
end

return Squad
