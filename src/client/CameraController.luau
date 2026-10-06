-- Recoil and scope zoom, layered on top of Roblox's first-person camera.
--
-- Recoil is an offset in degrees added to wherever the player is aiming,
-- re-applied on top of the camera every frame. A shot moves the view at once,
-- the offset holds while they keep firing, and it settles back to nothing once
-- they stop. It does not move the mouse, so after a burst the player has to
-- re-aim: pulling down against the climb is the skill.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Recoil = require(ReplicatedStorage:WaitForChild("Shared").Logic.Recoil)

local CameraController = {}

local BASE_FOV = 80

-- The offset the camera is currently carrying.
local pitch, yaw = 0, 0
local lastKick = 0
local recoveryRate = 12 -- degrees per second, set by the weapon that fired
local recoveryDelay = 0.12 -- seconds after the last shot before it settles back

local targetFov = BASE_FOV
local baseSensitivity = UserInputService.MouseDeltaSensitivity

function CameraController.kick(pitchDegrees, yawDegrees, recovery, delay)
	-- Applied at once, not eased into. Easing was what made the view carry on
	-- climbing for a moment after the last shot of a burst.
	pitch += pitchDegrees
	yaw += yawDegrees
	lastKick = os.clock()
	recoveryRate = recovery
	recoveryDelay = delay
end

-- Pass a weapon's scope table to zoom in, or nil to zoom out.
function CameraController.setScope(scope)
	if scope then
		targetFov = scope.fov
		UserInputService.MouseDeltaSensitivity = baseSensitivity * scope.sensitivity
	else
		targetFov = BASE_FOV
		UserInputService.MouseDeltaSensitivity = baseSensitivity
	end
end

function CameraController.reset()
	pitch, yaw = 0, 0
	lastKick = 0
	CameraController.setScope(nil)
end

-- Eases the view to `fov` degrees, or back to normal with nil. For cameras
-- that are not the player's own aim, such as the killcam.
function CameraController.zoom(fov)
	targetFov = fov or BASE_FOV
end

local function step(dt)
	local camera = workspace.CurrentCamera

	-- While firing, the gap between shots is shorter than the delay, so the
	-- offset only ever climbs. It settles once the player stops.
	if os.clock() - lastKick > recoveryDelay then
		pitch, yaw = Recoil.settle(recoveryRate, pitch, yaw, dt)
	end

	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(dt * 18, 1)

	if pitch ~= 0 or yaw ~= 0 then
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(pitch), math.rad(-yaw), 0)
	end
end

function CameraController.start()
	workspace.CurrentCamera.FieldOfView = BASE_FOV
	-- After Roblox's own camera update, so this is an offset on top of it, and
	-- before the weapon controller, so shots follow the recoiled view.
	RunService:BindToRenderStep("TdmRecoil", Enum.RenderPriority.Camera.Value + 1, step)
end

return CameraController
