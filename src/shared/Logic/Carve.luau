-- Fills a rectangle with solid blocks everywhere a list of open rectangles
-- does not reach, so a map's walls are the exact complement of the space its
-- players move through. Placing the solid by hand is what leaves gaps between
-- blocks; carving it cannot.
--
-- Every rectangle is { x1, z1, x2, z2 } with x1 < x2 and z1 < z2. Pure rules.

local Carve = {}

-- The distinct edges along one axis, inside `low`..`high`, in order.
local function edges(low, high, rects, first, second)
	local seen = { [low] = true, [high] = true }
	for _, rect in rects do
		for _, value in { rect[first], rect[second] } do
			if value > low and value < high then
				seen[value] = true
			end
		end
	end
	local list = {}
	for value in seen do
		table.insert(list, value)
	end
	table.sort(list)
	return list
end

local function covered(open, x, z)
	for _, rect in open do
		if x > rect[1] and x < rect[3] and z > rect[2] and z < rect[4] then
			return true
		end
	end
	return false
end

-- The rectangles that fill `bounds` everywhere `open` does not.
function Carve.solids(bounds, open)
	local xs = edges(bounds[1], bounds[3], open, 1, 3)
	local zs = edges(bounds[2], bounds[4], open, 2, 4)

	-- A grid whose lines are those edges: every cell is wholly open or wholly solid.
	local fill = {}
	for i = 1, #xs - 1 do
		fill[i] = {}
		for j = 1, #zs - 1 do
			fill[i][j] = not covered(open, (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2)
		end
	end

	-- Run the solid cells together down each column...
	local columns = {}
	for i = 1, #xs - 1 do
		columns[i] = {}
		local j = 1
		while j <= #zs - 1 do
			if fill[i][j] then
				local last = j
				while last < #zs - 1 and fill[i][last + 1] do
					last += 1
				end
				table.insert(columns[i], { j, last })
				j = last + 1
			else
				j += 1
			end
		end
	end

	-- ...then join runs that line up across neighbouring columns, so the walls
	-- come out as a few long blocks instead of a grid of small ones.
	local solids = {}
	local used = {}
	for i = 1, #columns do
		used[i] = {}
	end
	for i = 1, #columns do
		for index, run in columns[i] do
			if not used[i][index] then
				local last = i
				while true do
					local next = last + 1
					local match = nil
					if columns[next] then
						for otherIndex, other in columns[next] do
							if not used[next][otherIndex] and other[1] == run[1] and other[2] == run[2] then
								match = otherIndex
								break
							end
						end
					end
					if not match then
						break
					end
					used[next][match] = true
					last = next
				end
				table.insert(solids, { xs[i], zs[run[1]], xs[last + 1], zs[run[2] + 1] })
			end
		end
	end
	return solids
end

return Carve
