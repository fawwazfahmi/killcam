-- Weighted ground movement. The Humanoid still does the walking; this feeds it
-- a smoothed direction so starts, stops and turns take a moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MovementConfig = require(Shared.Config.MovementConfig)
local MoveSmoothing = require(Shared.Logic.MoveSmoothing)

local MovementController = {}

local player = Players.LocalPlayer

local smoothX, smoothZ = 0, 0
local trackedHumanoid = nil
local baseHipHeight = 0
local airTime = 0
local lastAirTime = 0
local sinceLanding = math.huge

local state = { moving = false, crouched = false, airborne = false }
local speedScale = 1

-- Set by the weapon controller: what the player's armour and the weapon in
-- hand do to movement speed.
function MovementController.setSpeedScale(scale)
	speedScale = scale
end

-- Read by the weapon controller (spread) and the viewmodel (bob).
function MovementController.getState()
	return state
end

local function keyAxis(negative, positive)
	local value = 0
	if UserInputService:IsKeyDown(negative) then
		value -= 1
	end
	if UserInputService:IsKeyDown(positive) then
		value += 1
	end
	return value
end

local function step(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		smoothX, smoothZ = 0, 0
		state.moving, state.crouched, state.airborne = false, false, false
		return
	end

	if humanoid ~= trackedHumanoid then
		trackedHumanoid = humanoid
		baseHipHeight = humanoid.HipHeight
		smoothX, smoothZ = 0, 0
		airTime, lastAirTime, sinceLanding = 0, 0, math.huge
		state.crouched = false
	end

	local typing = UserInputService:GetFocusedTextBox() ~= nil
	local strafe = typing and 0 or keyAxis(Enum.KeyCode.A, Enum.KeyCode.D)
	local forward = typing and 0 or keyAxis(Enum.KeyCode.S, Enum.KeyCode.W)

	-- Camera-relative input to a flat world direction.
	local look = workspace.CurrentCamera.CFrame.LookVector
	local fx, fz = look.X, look.Z
	local length = math.sqrt(fx * fx + fz * fz)
	if length < 1e-4 then
		fx, fz = 0, -1
	else
		fx, fz = fx / length, fz / length
	end
	local rx, rz = -fz, fx

	local tx = rx * strafe + fx * forward
	local tz = rz * strafe + fz * forward
	local targetLength = math.sqrt(tx * tx + tz * tz)
	if targetLength > 1 then
		tx, tz = tx / targetLength, tz / targetLength
	end

	local humanoidState = humanoid:GetState()
	local airborne = humanoidState == Enum.HumanoidStateType.Freefall
		or humanoidState == Enum.HumanoidStateType.Jumping
	if airborne then
		airTime += dt
	elseif state.airborne then
		lastAirTime = airTime
		airTime = 0
		sinceLanding = 0
	else
		sinceLanding += dt
	end
	state.airborne = airborne

	smoothX, smoothZ = MoveSmoothing.step(MovementConfig, smoothX, smoothZ, tx, tz, dt, airborne)
	-- Runs after Roblox's control script each frame, so this call is the one that counts.
	humanoid:Move(Vector3.new(smoothX, 0, smoothZ), false)
	state.moving = (smoothX * smoothX + smoothZ * smoothZ) > 0.04

	local wantsCrouch = not typing
		and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C))
	if wantsCrouch ~= state.crouched then
		state.crouched = wantsCrouch
		humanoid.HipHeight = wantsCrouch and (baseHipHeight - MovementConfig.crouchHipDrop) or baseHipHeight
	end

	local speed = state.crouched and MovementConfig.crouchSpeed or MovementConfig.runSpeed
	humanoid.WalkSpeed = speed * speedScale * MoveSmoothing.landingFactor(MovementConfig, lastAirTime, sinceLanding)
end

function MovementController.start()
	RunService:BindToRenderStep("TdmMovement", Enum.RenderPriority.Input.Value + 1, step)
end

return MovementController
