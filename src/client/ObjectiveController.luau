-- Search and Destroy on the client: asking to plant or defuse, the progress
-- bar, the line that says what to do, and the marker over the bomb. Does
-- nothing in other modes. The server decides everything; this only asks and
-- displays.
--
-- Planting is asked for by the weapon controller, while fire is held with the
-- bomb out. Defusing is asked for here, while E is held.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Remotes = require(Shared.Remotes)

local ObjectiveController = {}

local controls -- Controls: the Use action is held to defuse. The same action takes a revive, but only when dead.

local player = Players.LocalPlayer
local hud
local match = nil -- the latest MatchUpdate
local bomb = { status = "None" } -- the latest BombUpdate
local marker
local planting, defusing = false, false
local holding = false -- what the server was last told

-- "Attack", "Defend", or nil outside bomb mode.
local function side()
	if not match or match.mode ~= "SND" or not player.Team then
		return nil
	end
	return if player.Team.Name == match.attackers then "Attack" else "Defend"
end

local function objective(role)
	if not role then
		return ""
	end
	if match.phase == "Prep" or match.phase == "Live" then
		if role == "Defend" then
			return "Defend the sites"
		elseif bomb.status == "Carried" and bomb.carrier == player then
			return "You have the bomb  -  press 5, then hold fire on a site"
		elseif bomb.status == "Dropped" then
			return "The bomb is down  -  pick it up"
		end
		return "Attack  -  get the bomb to a site"
	elseif match.phase == "Planted" then
		local where = if bomb.site then " at " .. bomb.site else ""
		if role == "Attack" then
			return "Bomb planted" .. where .. "  -  keep them off it"
		end
		return "Bomb planted" .. where .. "  -  defuse it  [hold " .. controls.hint("Use") .. "]"
	end
	return ""
end

local function refresh()
	local role = side()
	hud.setObjective(objective(role))

	-- Everyone sees a planted bomb; only attackers see a dropped one.
	local part = workspace:FindFirstChild("Bomb")
	local show = part ~= nil and (bomb.status == "Planted" or (bomb.status == "Dropped" and role == "Attack"))
	marker.Adornee = if show then part else nil
	marker.Enabled = show
end

local function buildMarker()
	marker = Instance.new("BillboardGui")
	marker.Name = "BombMarker"
	marker.AlwaysOnTop = true
	marker.Size = UDim2.fromOffset(70, 22)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	marker.ResetOnSpawn = false
	marker.Enabled = false

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font[Theme.body]
	text.Text = "BOMB"
	text.TextSize = 14
	text.TextColor3 = Color3.fromRGB(table.unpack(Theme.accent))
	text.TextStrokeTransparency = 0.3
	text.Parent = marker

	marker.Parent = player:WaitForChild("PlayerGui")
end

local function sync()
	local value = planting or defusing
	if holding ~= value then
		holding = value
		Remotes.BombUse:FireServer(value)
	end
end

-- Called by the weapon controller every frame the bomb is in hand.
function ObjectiveController.setPlanting(value)
	if planting ~= value then
		planting = value
		sync()
	end
end

-- `controlsModule` is Controls.
function ObjectiveController.start(hudModule, controlsModule)
	hud = hudModule
	controls = controlsModule
	buildMarker()

	Remotes.MatchUpdate.OnClientEvent:Connect(function(snapshot)
		match = snapshot
		refresh()
	end)
	Remotes.BombUpdate.OnClientEvent:Connect(function(update)
		bomb = update
		refresh()
	end)
	Remotes.BombProgress.OnClientEvent:Connect(function(kind, seconds)
		if kind then
			hud.setProgress(if kind == "Plant" then "Planting" else "Defusing", seconds)
		else
			hud.setProgress(nil)
		end
	end)

	controls.on("Use", function(down)
		if down and side() == "Defend" then
			defusing = true
			sync()
		elseif not down and defusing then
			defusing = false
			sync()
		end
	end)
end

return ObjectiveController
