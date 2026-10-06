-- Turns map props brought in with Studio's Import 3D into the form MapBuilder
-- expects and files them under ReplicatedStorage.Assets.Props.
--
-- Run from the command bar after importing assets/props/*.glb:
--   require(game.ServerStorage.Tools.FitProps)()
--
-- A fitted prop is a Model whose PrimaryPart "Root" sits at the centre of the
-- prop, with a Vector3 attribute "Size" holding the box the prop fills.
-- MapBuilder stretches the prop from that size to each box it dresses.

local Fit = require(script.Parent.Fit)

-- A prop is an import without a muzzle marker.
local function fit(imported)
	if Fit.marker(imported, "MarkMuzzle") then
		return nil
	end
	local frame, problem = Fit.frame(imported)
	if not frame then
		return nil, problem
	end

	local model, root = Fit.assemble(imported, "Root", frame)

	-- Bounds of the visible parts, measured in the root's space.
	local low = Vector3.one * math.huge
	local high = Vector3.one * -math.huge
	for _, part in model:GetChildren() do
		if part == root or not part:IsA("BasePart") then
			continue
		end
		local offset = frame:ToObjectSpace(part.CFrame)
		local half = part.Size / 2
		local x, y, z = offset.XVector * half.X, offset.YVector * half.Y, offset.ZVector * half.Z
		local reach = Vector3.new(
			math.abs(x.X) + math.abs(y.X) + math.abs(z.X),
			math.abs(x.Y) + math.abs(y.Y) + math.abs(z.Y),
			math.abs(x.Z) + math.abs(y.Z) + math.abs(z.Z)
		)
		low = low:Min(offset.Position - reach)
		high = high:Max(offset.Position + reach)
	end
	if low.X > high.X then
		return nil, "it has no visible parts"
	end
	if ((low + high) / 2).Magnitude > 0.05 then
		warn(`FitProps: {imported.Name} is not centred on its origin; it will sit off its box`)
	end
	model:SetAttribute("Size", high - low)
	return model
end

return function()
	return Fit.run("FitProps", "Props", fit)
end
