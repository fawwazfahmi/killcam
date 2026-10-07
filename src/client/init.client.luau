local Players = game:GetService("Players")

Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

local Controls = require(script.Controls)
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
local Sounds = require(script.Sounds)
local LoadoutMenu = require(script.LoadoutMenu)

-- Only the test range has this folder (see range.project.json).
local Range = script:FindFirstChild("Range")

-- Each controller runs once per frame, in this order:
-- movement, (Roblox camera), recoil, weapons, viewmodel.
Controls.start()
Sounds.start()
MovementController.start(Controls)
CameraController.start()
Hud.start()
WeaponController.start({
	movement = MovementController,
	camera = CameraController,
	viewmodel = ViewmodelController,
	hud = Hud,
	objective = ObjectiveController,
	controls = Controls,
	sounds = Sounds,
	footsteps = Footsteps,
})
ViewmodelController.start(MovementController)
ObjectiveController.start(Hud, Controls)
Footsteps.start()
PodiumController.start()
ReviveController.start(Controls)
SpectateController.start({ camera = CameraController, viewmodel = ViewmodelController })
KillMarks.start()
if Range then
	local Panel = require(Range.Panel)
	require(Range.Readout).start()
	Panel.start()
	LoadoutMenu.start({
		unlocked = true,
		-- Where there is no P key to press, the panel is reached from here.
		link = {
			label = "TEST PANEL",
			open = function()
				LoadoutMenu.setOpen(false)
				Panel.setOpen(true)
			end,
		},
	})
else
	LoadoutMenu.start({ inMatch = true }) -- nothing is sold in a match, so there is no shop here
end
Controls.on("Loadout", function(down)
	if down then
		LoadoutMenu.toggle()
	end
end)
