local Players = game:GetService("Players")

Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

local MovementController = require(script.MovementController)
local CameraController = require(script.CameraController)
local ViewmodelController = require(script.ViewmodelController)
local Hud = require(script.Hud)
local WeaponController = require(script.WeaponController)
local ObjectiveController = require(script.ObjectiveController)
local Footsteps = require(script.Footsteps)
local PodiumController = require(script.PodiumController)
local ReviveController = require(script.ReviveController)
local SpectateController = require(script.SpectateController)
local KillMarks = require(script.KillMarks)
local LoadoutMenu = require(script.LoadoutMenu)

-- Each controller runs once per frame, in this order:
-- movement, (Roblox camera), recoil, weapons, viewmodel.
MovementController.start()
CameraController.start()
Hud.start()
WeaponController.start({
	movement = MovementController,
	camera = CameraController,
	viewmodel = ViewmodelController,
	hud = Hud,
	objective = ObjectiveController,
	footsteps = Footsteps,
})
ViewmodelController.start(MovementController)
ObjectiveController.start(Hud)
Footsteps.start()
PodiumController.start()
ReviveController.start()
SpectateController.start({ camera = CameraController, viewmodel = ViewmodelController })
KillMarks.start()
LoadoutMenu.start({ inMatch = true }) -- nothing is sold in a match, so there is no shop here
