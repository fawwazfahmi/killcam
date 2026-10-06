-- Builds the model for a weapon, used for both the first-person viewmodel and
-- the weapon other players see in your hand.
--
-- To use real art, put a Model named after the weapon's `model` field in
-- ReplicatedStorage.Assets.Weapons. Its PrimaryPart must sit at the grip with
-- the barrel pointing along -Z, and may carry an Attachment named "Muzzle".
-- Without one, the block placeholder below is generated instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponModels = {}

local DARK = { 38, 38, 42 }
local STEEL = { 70, 73, 80 }
local WOOD = { 78, 62, 46 }
local OLIVE = { 66, 78, 52 }

-- The first block is the grip and becomes the PrimaryPart. Offsets are relative to it.
local PLACEHOLDERS = {
	Rifle = {
		muzzle = { 0, 0.55, -3.1 },
		blocks = {
			{ "Handle", { 0.3, 0.9, 0.4 }, { 0, 0, 0 }, DARK },
			{ "Body", { 0.35, 0.5, 2.2 }, { 0, 0.55, -0.6 }, STEEL },
			{ "Barrel", { 0.16, 0.16, 1.4 }, { 0, 0.6, -2.4 }, DARK },
			{ "Stock", { 0.3, 0.45, 1.0 }, { 0, 0.5, 1.0 }, WOOD },
			{ "Magazine", { 0.25, 0.8, 0.4 }, { 0, -0.05, -0.9 }, DARK },
		},
	},
	Smg = {
		muzzle = { 0, 0.5, -2.0 },
		blocks = {
			{ "Handle", { 0.3, 0.85, 0.4 }, { 0, 0, 0 }, DARK },
			{ "Body", { 0.36, 0.5, 1.7 }, { 0, 0.5, -0.45 }, DARK },
			{ "Barrel", { 0.18, 0.18, 0.7 }, { 0, 0.55, -1.65 }, STEEL },
			{ "Magazine", { 0.22, 1.1, 0.3 }, { 0, -0.15, -0.75 }, STEEL },
			{ "Stock", { 0.12, 0.3, 0.9 }, { 0, 0.55, 0.85 }, STEEL },
		},
	},
	Sniper = {
		muzzle = { 0, 0.55, -4.4 },
		blocks = {
			{ "Handle", { 0.3, 0.9, 0.4 }, { 0, 0, 0 }, DARK },
			{ "Body", { 0.35, 0.45, 2.6 }, { 0, 0.55, -0.7 }, OLIVE },
			{ "Barrel", { 0.14, 0.14, 2.4 }, { 0, 0.6, -3.2 }, DARK },
			{ "Stock", { 0.3, 0.5, 1.2 }, { 0, 0.45, 1.2 }, OLIVE },
			{ "Scope", { 0.25, 0.25, 1.2 }, { 0, 1.0, -0.6 }, DARK },
		},
	},
	Pistol = {
		muzzle = { 0, 0.5, -1.0 },
		blocks = {
			{ "Handle", { 0.28, 0.8, 0.35 }, { 0, 0, 0 }, DARK },
			{ "Slide", { 0.3, 0.35, 1.2 }, { 0, 0.5, -0.35 }, STEEL },
		},
	},
	Knife = {
		muzzle = { 0, 0.1, -1.2 },
		blocks = {
			{ "Handle", { 0.2, 0.25, 0.6 }, { 0, 0, 0 }, DARK },
			{ "Blade", { 0.06, 0.3, 1.0 }, { 0, 0.05, -0.8 }, STEEL },
		},
	},
	Bomb = {
		muzzle = { 0, 0, -0.8 },
		blocks = {
			{ "Handle", { 1.0, 0.7, 1.4 }, { 0, 0, 0 }, DARK },
			{ "Lamp", { 0.3, 0.12, 1.0 }, { 0, 0.4, 0 }, WOOD },
		},
	},
	Grenade = {
		muzzle = { 0, 0, -0.5 },
		blocks = {
			{ "Handle", { 0.6, 0.7, 0.6 }, { 0, 0, 0 }, OLIVE },
			{ "Cap", { 0.25, 0.25, 0.25 }, { 0, 0.45, 0 }, STEEL },
		},
	},
}

local function customModel(name)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weapons = assets and assets:FindFirstChild("Weapons")
	local model = weapons and weapons:FindFirstChild(name)
	if model and model:IsA("Model") and model.PrimaryPart then
		return model:Clone()
	end
	return nil
end

-- Returns an anchored Model with a PrimaryPart. Callers decide physics settings.
function WeaponModels.build(name)
	local custom = customModel(name)
	if custom then
		return custom
	end

	local definition = PLACEHOLDERS[name]
	local model = Instance.new("Model")
	model.Name = name

	for index, block in definition.blocks do
		local part = Instance.new("Part")
		part.Name = block[1]
		part.Size = Vector3.new(table.unpack(block[2]))
		part.CFrame = CFrame.new(table.unpack(block[3]))
		part.Color = Color3.fromRGB(table.unpack(block[4]))
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.Parent = model
		if index == 1 then
			model.PrimaryPart = part
		end
	end

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(table.unpack(definition.muzzle))
	muzzle.Parent = model.PrimaryPart

	return model
end

return WeaponModels
