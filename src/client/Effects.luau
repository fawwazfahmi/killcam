-- Short-lived visuals. None of these can be hit by raycasts.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}

local DEFAULT_IMPACT_LIFE = 0.08

local impactLife = DEFAULT_IMPACT_LIFE -- seconds a bullet mark lasts
local impacts = Instance.new("Folder") -- only this player's game has it
impacts.Name = "Impacts"
impacts.Parent = workspace

local function ghostPart()
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	return part
end

function Effects.tracer(from, to)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local part = ghostPart()
	part.Name = "Tracer"
	part.Color = Color3.fromRGB(255, 220, 150)
	part.Size = Vector3.new(0.06, 0.06, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Parent = workspace
	Debris:AddItem(part, 0.05)
end

function Effects.impact(position)
	local part = ghostPart()
	part.Name = "Impact"
	part.Color = Color3.fromRGB(255, 240, 200)
	part.Size = Vector3.new(0.3, 0.3, 0.3)
	part.Position = position
	part.Parent = impacts
	Debris:AddItem(part, impactLife)
end

-- How long a bullet mark lasts: a blink, unless told otherwise. The test
-- range makes them stay, so a spray can be read off a wall. Nil puts it back.
function Effects.setImpactLife(seconds)
	impactLife = seconds or DEFAULT_IMPACT_LIFE
end

function Effects.clearImpacts()
	impacts:ClearAllChildren()
end

function Effects.explosion(position, radius)
	local part = ghostPart()
	part.Name = "Explosion"
	part.Shape = Enum.PartType.Ball
	part.Color = Color3.fromRGB(255, 150, 60)
	part.Size = Vector3.new(2, 2, 2)
	part.Position = position
	part.Parent = workspace

	local size = radius * 0.8
	TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(size, size, size),
		Transparency = 1,
	}):Play()
	Debris:AddItem(part, 0.4)
end

return Effects
