-- The first-person weapon. All motion is procedural: sway, walk bob, recoil
-- kick, the raise when a weapon is drawn and the knife swing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local WeaponModels = require(ReplicatedStorage:WaitForChild("Shared").WeaponModels)

local ViewmodelController = {}

local REST = CFrame.new(0.9, -1.0, -1.6) -- grip position relative to the camera

local movement = nil
local model = nil
local hidden = false

local lowered = 0 -- 1 = fully down, 0 = raised
local raiseTime = 0.3
local kick = 0
local swing = 0
local swayX, swayY = 0, 0
local bobClock = 0

function ViewmodelController.equip(modelName, equipTime)
	ViewmodelController.clear()
	model = WeaponModels.build(modelName)
	model.Name = "Viewmodel"
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	model.Parent = workspace.CurrentCamera
	lowered = 1
	raiseTime = math.max(equipTime, 0.05)
	kick, swing = 0, 0
end

function ViewmodelController.clear()
	if model then
		model:Destroy()
		model = nil
	end
end

function ViewmodelController.kick(amount)
	kick = math.min(kick + amount, 1.5)
end

function ViewmodelController.swing()
	swing = 1
end

-- Used while scoped, when the scope overlay replaces the weapon.
function ViewmodelController.setHidden(value)
	hidden = value
end

-- Where tracers start.
function ViewmodelController.muzzlePosition()
	local camera = workspace.CurrentCamera
	if model and not hidden and model.PrimaryPart then
		local muzzle = model.PrimaryPart:FindFirstChild("Muzzle")
		if muzzle and muzzle:IsA("Attachment") then
			return muzzle.WorldPosition
		end
	end
	return (camera.CFrame * CFrame.new(0.4, -0.4, -2)).Position
end

local function approach(current, target, dt, speed)
	return current + (target - current) * math.min(dt * speed, 1)
end

local function step(dt)
	if not model then
		return
	end
	local camera = workspace.CurrentCamera

	if hidden then
		model:PivotTo(camera.CFrame * CFrame.new(0, -60, 0))
		return
	end

	lowered = math.max(lowered - dt / raiseTime, 0)
	kick = math.max(kick - dt * 8, 0)
	swing = math.max(swing - dt * 5, 0)

	local delta = UserInputService:GetMouseDelta()
	swayX = approach(swayX, math.clamp(-delta.X * 0.002, -0.08, 0.08), dt, 10)
	swayY = approach(swayY, math.clamp(delta.Y * 0.002, -0.08, 0.08), dt, 10)

	local moveState = movement.getState()
	local walking = moveState.moving and not moveState.airborne
	if walking then
		bobClock += dt * 11
	end
	local bobSize = walking and 0.035 or 0

	model:PivotTo(
		camera.CFrame
			* REST
			* CFrame.new(
				swayX + math.sin(bobClock) * bobSize,
				swayY + math.abs(math.cos(bobClock)) * bobSize - lowered * 0.8,
				kick * 0.25 - swing * 0.6
			)
			* CFrame.Angles(math.rad(kick * 6) - lowered * 1.1 - swing * 0.9, swayX * 2, 0)
	)
end

function ViewmodelController.start(movementController)
	movement = movementController
	RunService:BindToRenderStep("TdmViewmodel", Enum.RenderPriority.Camera.Value + 3, step)
end

return ViewmodelController
