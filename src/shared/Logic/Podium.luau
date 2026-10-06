-- How each of the top three feels about how the match went. Who they are is
-- Shared.Logic.Score. Pure rules.

local Podium = {}

-- How a player on the podium behaves:
--   "Celebrate"  they won, or nobody lost (a draw, or a free-for-all podium)
--   "Cry"        they were the match's MVP and their team still lost
--   "Sulk"       they made the podium on the losing side
function Podium.mood(won, isMvp, nobodyLost)
	if won or nobodyLost then
		return "Celebrate"
	elseif isMvp then
		return "Cry"
	end
	return "Sulk"
end

return Podium
