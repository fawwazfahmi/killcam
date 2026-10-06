-- Turns weapon models brought in with Studio's Import 3D into the form the game
-- expects (see Shared.WeaponModels) and files them under
-- ReplicatedStorage.Assets.Weapons.
--
-- Run from the command bar after importing assets/weapons/*.glb:
--   require(game.ServerStorage.Tools.FitWeapons)()

local Fit = require(script.Parent.Fit)

-- A weapon is an import that carries a muzzle marker.
local function fit(imported)
	local muzzle = Fit.marker(imported, "MarkMuzzle")
	if not muzzle then
		return nil
	end
	local frame, problem = Fit.frame(imported)
	if not frame then
		return nil, problem
	end

	local model, grip = Fit.assemble(imported, "Grip", frame)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Muzzle"
	attachment.Position = frame:PointToObjectSpace(muzzle.Position)
	attachment.Parent = grip
	return model
end

return function()
	return Fit.run("FitWeapons", "Weapons", fit)
end
