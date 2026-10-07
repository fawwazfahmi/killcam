-- The writing on the test range: the boards the layout lists, and one on each
-- landing of the drop tower saying how far the fall is and what it costs. The
-- cost is worked out from the game's own fall rule, so the signs cannot fall
-- out of step with it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared.Config.MatchConfig)
local MovementConfig = require(Shared.Config.MovementConfig)
local Theme = require(Shared.Config.Theme)
local Damage = require(Shared.Logic.Damage)

local Signs = {}

local PIXELS_PER_STUD = 40
local THICKNESS = 0.2
local MARGIN = 0.08 -- of the board's height, left clear around the writing

local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local PAPER = Color3.fromRGB(table.unpack(Theme.paper))
local PANEL = Color3.fromRGB(table.unpack(Theme.panel))

local function writing(properties, parent)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextScaled = true
	for key, value in properties do
		label[key] = value
	end
	label.Parent = parent
	return label
end

-- A board with `text` on it and, if given, a smaller line under it. It is
-- scenery: it stops nobody and no shot. Its writing faces the board's own -Z.
local function board(parent, sign, text, sub)
	local part = Instance.new("Part")
	part.Name = "Sign"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.new(sign.size[1], sign.size[2], THICKNESS)
	part.CFrame = CFrame.new(sign.pos[1], sign.pos[2], sign.pos[3]) * CFrame.Angles(0, math.rad(sign.yaw), 0)
	part.Color = PANEL
	part.Material = Enum.Material.SmoothPlastic

	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Front
	face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	face.PixelsPerStud = PIXELS_PER_STUD
	face.LightInfluence = 0 -- readable in shade
	face.Parent = part

	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, 0, MARGIN, 0)
	strip.BackgroundColor3 = ACCENT
	strip.BorderSizePixel = 0
	strip.Parent = face

	local share = if sub then 0.5 else 1 - 3 * MARGIN -- of the board's height the main line gets
	writing({
		Position = UDim2.fromScale(0.04, 2 * MARGIN),
		Size = UDim2.fromScale(0.92, share),
		Font = Enum.Font[Theme.display],
		Text = text,
		TextColor3 = PAPER,
	}, face)
	if sub then
		writing({
			Position = UDim2.fromScale(0.04, 2.5 * MARGIN + share),
			Size = UDim2.fromScale(0.92, 1 - 4 * MARGIN - share),
			Font = Enum.Font[Theme.bodyBold],
			Text = sub,
			TextColor3 = ACCENT,
		}, face)
	end

	part.Parent = parent
	return part
end

-- What stepping off a landing `height` studs up costs somebody in ordinary boots.
local function fallCost(height)
	local speed = math.sqrt(2 * workspace.Gravity * height)
	local amount = math.floor(Damage.fall(MovementConfig.fall, speed, 1) + 0.5)
	if amount <= 0 then
		return "NO DAMAGE"
	elseif amount >= MatchConfig.maxHealth then
		return string.format("%d HP: FATAL", amount)
	end
	return string.format("ABOUT %d HP", amount)
end

-- Call after the map is built: the boards go in with its other scenery, and
-- the drop signs need the map's gravity.
function Signs.build(layout)
	local map = workspace:WaitForChild("Map")
	local parent = map:FindFirstChild("Props") or map
	for _, sign in layout.signs do
		board(parent, sign, sign.text, sign.sub)
	end
	for _, drop in layout.drops do
		board(parent, drop, drop.height .. " STUDS", fallCost(drop.height))
	end
end

return Signs
