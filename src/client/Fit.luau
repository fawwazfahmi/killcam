-- Keeps a screen drawn for a desktop readable on a phone: everything in it is
-- scaled down, never up, to suit the height of the screen it is on.

local Fit = {}

local DESIGNED_FOR = 900 -- the screen height, in pixels, the HUD is drawn for
local SMALLEST = 0.55

function Fit.attach(gui)
	local scale = Instance.new("UIScale")
	scale.Parent = gui

	local function update()
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.Y / DESIGNED_FOR, SMALLEST, 1)
		end
	end
	local watched = nil
	local function follow()
		if watched then
			watched:Disconnect()
		end
		local camera = workspace.CurrentCamera
		watched = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) else nil
		update()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(follow)
	follow()
	return scale
end

return Fit
