-- Who may be in the test range. Pure rules; the facts about the player and the
-- experience are passed in.

local Admin = {}

--[[
	facts = {
		userId,
		studio,       true when this is a Studio test, where there is no owner to compare with
		creatorType,  "User" or "Group": who owns the experience
		creatorId,    that user's id, or that group's
		groupRank,    the player's rank in the owning group, if a group owns it
	}
]]
function Admin.allowed(config, facts)
	if facts.studio then
		return true
	end
	if table.find(config.admins, facts.userId) ~= nil then
		return true
	end
	if facts.creatorType == "Group" then
		return (facts.groupRank or 0) >= config.groupRank
	end
	-- An experience that has never been published has no owner: its id is 0.
	return facts.creatorId ~= 0 and facts.userId == facts.creatorId
end

return Admin
