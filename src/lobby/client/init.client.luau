-- The lobby on the client: first person, and a panel for each station.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

local ShopMenu = require(script.ShopMenu)
local LoadoutMenu = require(script.LoadoutMenu)
local Panels = require(script.Panels)
local ExpiredNotice = require(script.ExpiredNotice)
local StreetLife = require(script.StreetLife)

ShopMenu.start()
LoadoutMenu.start({ shop = ShopMenu })
Panels.start()
ExpiredNotice.start()
StreetLife.start()

-- Each station's prompt is named after it (see the lobby server).
local OPEN = {
	Armoury = function()
		LoadoutMenu.setOpen(true)
	end,
	Play = Panels.openPlay,
	Profile = Panels.openProfile,
	Squad = Panels.openSquad,
}

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local open = OPEN[prompt.Name]
	if open then
		open()
	end
end)
