-- Keeps the test range to the game's developers. Whoever is not one is
-- removed as they arrive, and nothing the admin panel asks for is done for
-- anybody who has not been let in. The rule itself is Shared.Logic.Admin, and
-- the list of who else is allowed is in RangeConfig.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RangeConfig = require(Shared.Config.RangeConfig)
local Admin = require(Shared.Logic.Admin)

local AdminGate = {}

local MESSAGE = "This place is for the game's developers."

local admitted = {} -- [player] = true once they have been let in

local function facts(player)
	local owned = game.CreatorType == Enum.CreatorType.Group
	local rank = 0
	if owned then
		-- Asks Roblox, so it can take a moment and it can fail. Failing counts as no rank.
		local ok, found = pcall(player.GetRankInGroup, player, game.CreatorId)
		rank = if ok then found else 0
	end
	return {
		userId = player.UserId,
		studio = RunService:IsStudio(),
		creatorType = if owned then "Group" else "User",
		creatorId = game.CreatorId,
		groupRank = rank,
	}
end

local function admit(player)
	if Admin.allowed(RangeConfig, facts(player)) then
		admitted[player] = true
	else
		player:Kick(MESSAGE)
	end
end

function AdminGate.allowed(player)
	return admitted[player] == true
end

function AdminGate.init()
	Players.PlayerAdded:Connect(admit)
	for _, player in Players:GetPlayers() do
		task.spawn(admit, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		admitted[player] = nil
	end)
end

return AdminGate
