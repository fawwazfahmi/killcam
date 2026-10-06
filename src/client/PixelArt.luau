-- Draws an icon from Shared.Config.Icons as a block of plain frames.

local PixelArt = {}

-- The size in pixels of an icon drawn with cells `cell` wide.
function PixelArt.size(icon, cell)
	return Vector2.new(#icon.rows[1] * cell, #icon.rows * cell)
end

-- Draws `icon` inside `parent`, from its top left corner. `tint`, if given,
-- is used for every cell in place of the icon's own colours. Returns the
-- frame holding it.
function PixelArt.draw(parent, icon, cell, tint)
	local size = PixelArt.size(icon, cell)
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	holder.BackgroundTransparency = 1

	for y, row in icon.rows do
		-- One frame for each run of cells of the same colour, not one per cell.
		local x = 1
		while x <= #row do
			local kind = string.sub(row, x, x)
			local last = x
			while last < #row and string.sub(row, last + 1, last + 1) == kind do
				last += 1
			end
			if kind ~= "." then
				local run = Instance.new("Frame")
				run.BorderSizePixel = 0
				run.BackgroundColor3 = tint or Color3.fromRGB(table.unpack(icon.colors[kind]))
				run.Position = UDim2.fromOffset((x - 1) * cell, (y - 1) * cell)
				run.Size = UDim2.fromOffset((last - x + 1) * cell, cell)
				run.Parent = holder
			end
			x = last + 1
		end
	end

	holder.Parent = parent
	return holder
end

return PixelArt
