-- Recoil and scope zoom, layered on top of Roblox's first-person camera.
--
-- Recoil is an offset in degrees from wherever the player is aiming. A shot
-- moves the view at once, the offset holds while they keep firing, and it
-- settles back to nothing once they stop. It does not move the mouse, so
-- during a burst the player has to pull down against the climb: that is the
-- skill.
--
-- Roblox's camera has no aim of its own to go back to: each frame it carries
-- on from wherever the camera was left pointing. So the offset is not added
-- again every frame, which would turn a one degree kick into a climb of a
-- degree a frame for as long as it was held. Only the change in the offset
-- since the last frame is turned through: up as a shot lands, back down as it
-- settles.
--
-- Being hit knocks the aim as well. That is kept apart from recoil, and does
-- not pile up: a second hit while the first is still wearing off knocks the
-- aim back out to where one hit puts it, no further.

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

-- The knock from being hit.
local FLINCH_RECOVERY = 14 -- degrees per second
local FLINCH_DELAY = 0.05 -- seconds it holds before settling
local flinchPitch, flinchYaw = 0, 0
local lastFlinch = 0

-- How much of the two offsets the camera has already been turned through.
local turnedPitch, turnedYaw = 0, 0

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

-- Being hit: the aim is knocked up by `pitchDegrees` and aside by
-- `yawDegrees`. Hits in quick succession do not add up.
function CameraController.flinch(pitchDegrees, yawDegrees)
	if pitchDegrees >= flinchPitch then
		flinchPitch, flinchYaw = pitchDegrees, yawDegrees
	end
	lastFlinch = os.clock()
end

-- For a new life or a death: whatever offset was left is dropped where it
-- stands, not turned back through.
function CameraController.reset()
	pitch, yaw = 0, 0
	flinchPitch, flinchYaw = 0, 0
	turnedPitch, turnedYaw = 0, 0
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
	local now = os.clock()
	if now - lastKick > recoveryDelay then
		pitch, yaw = Recoil.settle(recoveryRate, pitch, yaw, dt)
	end
	if now - lastFlinch > FLINCH_DELAY then
		flinchPitch, flinchYaw = Recoil.settle(FLINCH_RECOVERY, flinchPitch, flinchYaw, dt)
	end

	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(dt * 18, 1)

	-- Turn through what has changed since the last frame, and no more.
	local wantedPitch, wantedYaw = pitch + flinchPitch, yaw + flinchYaw
	local morePitch, moreYaw = wantedPitch - turnedPitch, wantedYaw - turnedYaw
	if morePitch ~= 0 or moreYaw ~= 0 then
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(morePitch), math.rad(-moreYaw), 0)
		turnedPitch, turnedYaw = wantedPitch, wantedYaw
	end
end

function CameraController.start()
	workspace.CurrentCamera.FieldOfView = BASE_FOV
	-- After Roblox's own camera update, so this is an offset on top of it, and
	-- before the weapon controller, so shots follow the recoiled view.
	RunService:BindToRenderStep("TdmRecoil", Enum.RenderPriority.Camera.Value + 1, step)
end

return CameraController
