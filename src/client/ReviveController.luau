-- The revive offer a player sees when they die (see ReviveService): what it
-- costs, what it does in this mode, and how long is left to take it. F takes it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Remotes = require(Shared.Remotes)

local ReviveController = {}

local REVIVE_KEY = Enum.KeyCode.F

local DISPLAY = Enum.Font[Theme.display]
local FONT = Enum.Font[Theme.body]
local BOLD = Enum.Font[Theme.bodyBold]
local SIZE = Theme.size

local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local INK = Color3.fromRGB(table.unpack(Theme.ink))
local PAPER = Color3.fromRGB(table.unpack(Theme.paper))
local MUTED = Color3.fromRGB(table.unpack(Theme.muted))
local PANEL = Color3.fromRGB(table.unpack(Theme.panel))
local SUNKEN = Color3.fromRGB(table.unpack(Theme.sunken))

local WIDTH = 440

local gui, keyLabel, costLabel, effectLabel, timeBar
local offer = nil -- the latest offer, or nil
local total = 1 -- seconds the offer started with
local endsAt = 0

local function make(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in properties do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function text(properties, parent)
	local merged = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = PAPER,
		TextSize = SIZE.body,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in properties do
		merged[key] = value
	end
	return make("TextLabel", merged, parent)
end

local function build()
	gui = make("ScreenGui", {
		Name = "Revive",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 12,
		Enabled = false,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))

	local body = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(WIDTH, 104),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, gui)

	-- The time left, running down across the top.
	local track = make("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = SUNKEN,
		BorderSizePixel = 0,
	}, body)
	timeBar = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
	}, track)

	keyLabel = make("TextLabel", {
		Position = UDim2.fromOffset(20, 24),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
		Font = DISPLAY,
		Text = REVIVE_KEY.Name,
		TextSize = SIZE.heading,
		TextColor3 = INK,
	}, body)
	text({
		Position = UDim2.fromOffset(80, 20),
		Size = UDim2.fromOffset(200, 26),
		Font = DISPLAY,
		Text = "REVIVE",
		TextSize = SIZE.heading,
		TextColor3 = ACCENT,
	}, body)
	costLabel = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 22),
		Size = UDim2.fromOffset(190, 24),
		Font = BOLD,
		Text = "",
		TextSize = SIZE.label,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, body)
	effectLabel = text({
		Position = UDim2.fromOffset(80, 50),
		Size = UDim2.fromOffset(WIDTH - 100, 40),
		Text = "",
		TextSize = SIZE.small,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, body)
end

local function show(update)
	offer = update
	gui.Enabled = update ~= nil
	if not update then
		return
	end
	-- A fresh offer starts the bar full; opening the purchase window restarts it.
	total = math.max(update.seconds, 0.1)
	endsAt = os.clock() + update.seconds

	if update.buying then
		costLabel.Text = "WAITING FOR PURCHASE"
	elseif update.held > 0 then
		costLabel.Text = string.format("USES 1 OF YOUR %d", update.held)
	elseif update.price then
		costLabel.Text = string.format("%d ROBUX", update.price)
	else
		costLabel.Text = "COSTS ROBUX"
	end
	keyLabel.BackgroundTransparency = if update.buying then 0.6 else 0
	effectLabel.Text = if update.undo
		then "Back where you fell. Your death is wiped and their point is taken back."
		else "Back into this round. Your death still counts."
end

function ReviveController.start()
	build()
	Remotes.ReviveOffer.OnClientEvent:Connect(show)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == REVIVE_KEY and not processed and offer and not offer.buying then
			Remotes.ReviveRequest:FireServer()
		end
	end)

	RunService.RenderStepped:Connect(function()
		if offer then
			timeBar.Size = UDim2.fromScale(math.clamp((endsAt - os.clock()) / total, 0, 1), 1)
		end
	end)
end

return ReviveController
