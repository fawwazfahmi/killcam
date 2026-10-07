-- Which server may read and write a saved profile. A player's profile is kept
-- open on one server at a time: the saved record carries a mark,
-- `session = { server, at }`, naming the server that has it open and when
-- that server last saved it. Pure rules; `saved` is whatever the data store
-- holds (nil for a new player) and `now` a clock in seconds.

local Session = {}

-- The mark a server puts on a profile it has open.
function Session.stamp(server, now)
	return { server = server, at = now }
end

local function markOf(saved)
	local session = type(saved) == "table" and saved.session
	if type(session) == "table" and type(session.server) == "string" and type(session.at) == "number" then
		return session
	end
	return nil
end

-- True if another server has this profile open and has saved it recently
-- enough to be believed. A server that wants to open the profile waits. One
-- that has not saved it for `staleAfter` seconds is taken to have crashed.
function Session.heldElsewhere(saved, server, now, staleAfter)
	local session = markOf(saved)
	return session ~= nil and session.server ~= server and now - session.at < staleAfter
end

-- True if `server` may save over what is stored: nobody has it open, or this
-- server does. If another server has opened it since, theirs is the newer.
function Session.mayWrite(saved, server)
	local session = markOf(saved)
	return session == nil or session.server == server
end

return Session
