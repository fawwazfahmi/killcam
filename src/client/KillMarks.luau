-- A skull pops up under the crosshair for each kill: a red one, or one with
-- its brain out for a headshot. A run of kills lines them up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Icons = require(Shared.Config.Icons)
local Remotes = require(Shared.Remotes)

local Fit = require(script.Parent.Fit)
local PixelArt = require(script.Parent.PixelArt)

local KillMarks = {}

local CELL = 4 -- pixels to a cell of the icon
local BELOW_CROSSHAIR = 120
local MARK_LASTS = 2.6 -- seconds before a skull fades
local MOST = 5 -- skulls in the row at once

local POP = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local row
local marks = {} -- oldest first
local count = 0

local function remove(mark)
	local at = table.find(marks, mark)
	if at then
		table.remove(marks, at)
		mark:Destroy()
	end
end

local function pop(headshot)
	local icon = if headshot then Icons.BrainSkull else Icons.Skull
	local size = PixelArt.size(icon, CELL)

	count += 1
	local mark = Instance.new("CanvasGroup")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromOffset(size.X, size.Y)
	mark.LayoutOrder = count
	PixelArt.draw(mark, icon, CELL)

	-- It bursts out of nothing, a little past full size, and settles.
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = mark
	mark.Parent = row
	TweenService:Create(scale, POP, { Scale = 1 }):Play()

	table.insert(marks, mark)
	while #marks > MOST do
		remove(marks[1])
	end

	task.delay(MARK_LASTS, function()
		if mark.Parent then
			local fade = TweenService:Create(mark, FADE, { GroupTransparency = 1 })
			fade.Completed:Once(function()
				remove(mark)
			end)
			fade:Play()
		end
	end)
end

function KillMarks.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KillMarks"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9
	Fit.attach(gui)

	row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0.5, BELOW_CROSSHAIR)
	row.Size = UDim2.fromOffset(400, PixelArt.size(Icons.Skull, CELL).Y)
	row.BackgroundTransparency = 1
	row.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.HitConfirm.OnClientEvent:Connect(function(headshot, killed)
		if killed then
			pop(headshot == true)
		end
	end)
end

return KillMarks
