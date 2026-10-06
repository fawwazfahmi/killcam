-- How far footsteps carry. Roblox's own character sounds already play a
-- "Running" sound on every character; this only sets how far away each one can
-- be heard: the walker's boots times the listener's helmet.

local Players = game:GetService("Players")

local Footsteps = {}

local BASE_RANGE = 70 -- studs at which ordinary footsteps fade to nothing
local CHECK_EVERY = 0.5 -- seconds

local player = Players.LocalPlayer
local hearing = 1

-- Set by the weapon controller from the local player's helmet.
function Footsteps.setHearing(scale)
	hearing = scale
end

local function apply()
	for _, other in Players:GetPlayers() do
		local root = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		local sound = root and root:FindFirstChild("Running")
		if sound and sound:IsA("Sound") then
			-- The server publishes each player's boots as this attribute.
			local carry = other:GetAttribute("Footsteps") or 1
			sound.RollOffMode = Enum.RollOffMode.Linear
			sound.RollOffMinDistance = 6
			sound.RollOffMaxDistance = BASE_RANGE * carry * hearing
		end
	end
end

function Footsteps.start()
	task.spawn(function()
		while true do
			apply()
			task.wait(CHECK_EVERY)
		end
	end)
end

return Footsteps
