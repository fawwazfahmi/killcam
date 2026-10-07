-- Turns whatever the player is using into actions: the same "Fire", "Reload"
-- and so on from a keyboard and mouse, a controller, or a touch screen.
-- ControlsConfig says which key, button and touch button each one is.
--
-- Moving, looking and jumping are Roblox's own on every device; `move` just
-- reads which way its controls say the player wants to go.
--
-- The touch buttons are not real buttons. A real one swallows the touch, and
-- then a thumb holding FIRE could not also drag to aim. These are pictures,
-- and a touch that lands on one is still the camera's to follow.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ControlsConfig = require(Shared.Config.ControlsConfig)
local Theme = require(Shared.Config.Theme)

local Focus = require(script.Parent.Focus)

local Controls = {}

local ACTIONS = ControlsConfig.actions
local REACH = 1.15 -- a touch this many radii from a button's middle still counts
local TABLET = 600 -- screens at least this many pixels on their short side get bigger buttons
local TABLET_SCALE = 1.35

local PAPER = Color3.fromRGB(table.unpack(Theme.paper))
local PANEL = Color3.fromRGB(table.unpack(Theme.panel))
local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local INK = Color3.fromRGB(table.unpack(Theme.ink))

local player = Players.LocalPlayer

local listeners = {} -- [action] = { function(down) }
local down = {} -- [action] = true while a held action is down
local byKey, byMouse, byPad = {}, {}, {} -- what each input does
local device = "keyboard" -- "keyboard", "pad" or "touch": whichever was used last

local touchGui = nil
local touchButtons = {} -- [action] = Frame
local fingers = {} -- [touch InputObject] = the action it is holding
local moveControls = nil -- Roblox's own controls, once they have loaded

for name in ACTIONS do
	listeners[name] = {}
end

local function tell(action, value)
	for _, listener in listeners[action] do
		task.spawn(listener, value)
	end
end

local function paint(action)
	local button = touchButtons[action]
	if button then
		button.BackgroundColor3 = if down[action] then ACCENT else PANEL
		button.Label.TextColor3 = if down[action] then INK else PAPER
	end
end

local function set(action, value)
	if (down[action] == true) ~= value then
		down[action] = value or nil
		paint(action)
		tell(action, value)
	end
end

-- An input for `action` went down or came up on `from` ("keyboard", "pad" or "touch").
local function feed(action, began, from)
	local config = ACTIONS[action]
	if not config.hold then
		if began then
			tell(action, true)
		end
	elseif config.switch and config.switch[from] then
		if began then
			set(action, not down[action])
		end
	else
		set(action, began)
	end
end

-- Calls `listener(down)` when the action happens. For something held, `down`
-- is true as it goes down and false as it comes up; for something pressed it
-- is always true.
function Controls.on(action, listener)
	table.insert(listeners[action], listener)
end

function Controls.isDown(action)
	return down[action] == true
end

-- Lets go of a held action, as if the player had: for a new life, where a
-- switch left on would be a surprise.
function Controls.release(action)
	set(action, false)
end

-- Which way the player wants to go: how far right, and how far forward, each
-- from -1 to 1. From the keys, a stick or the touch thumbstick alike.
function Controls.move()
	if not moveControls then
		return 0, 0
	end
	local vector = moveControls:GetMoveVector()
	return vector.X, -vector.Z
end

-- How to tell the player what to press for an action, on what they are using
-- now: "F", "Y", or the touch button's own label.
function Controls.hint(action)
	local config = ACTIONS[action]
	local name
	if device == "touch" then
		return if config.touch then config.touch.label else ""
	elseif device == "pad" then
		name = config.pad[1]
	else
		name = config.keys[1] or config.mouse
	end
	return if name then ControlsConfig.short[name] or name else ""
end

-- Touch buttons -------------------------------------------------------------

local function layOut()
	local camera = workspace.CurrentCamera
	if not touchGui or not camera then
		return
	end
	local view = camera.ViewportSize
	local scale = if math.min(view.X, view.Y) >= TABLET then TABLET_SCALE else 1
	for action, button in touchButtons do
		local touch = ACTIONS[action].touch
		local size = touch.size * scale
		button.Size = UDim2.fromOffset(size, size)
		button.Position = UDim2.new(1, touch.at[1] * scale, if touch.top then 0 else 1, touch.at[2] * scale)
		button.Label.TextSize = math.clamp(size * 0.22, 11, 18)
	end
end

local function buildTouch()
	touchGui = Instance.new("ScreenGui")
	touchGui.Name = "TouchControls"
	touchGui.ResetOnSpawn = false
	touchGui.DisplayOrder = 5
	touchGui.Enabled = false

	for action, config in ACTIONS do
		if config.touch then
			local button = Instance.new("Frame")
			button.Name = action
			button.AnchorPoint = Vector2.new(0.5, 0.5)
			button.BackgroundColor3 = PANEL
			button.BackgroundTransparency = 0.35
			button.BorderSizePixel = 0
			button.Active = false -- a picture, not a button: see the top of this file
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = button
			local outline = Instance.new("UIStroke")
			outline.Color = PAPER
			outline.Transparency = 0.6
			outline.Thickness = 1.5
			outline.Parent = button
			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font[Theme.bodyBold]
			label.Text = config.touch.label
			label.TextColor3 = PAPER
			label.Parent = button
			button.Parent = touchGui
			touchButtons[action] = button
		end
	end
	layOut()
	touchGui.Parent = player:WaitForChild("PlayerGui")
end

-- The action whose button a touch at `position` is on, if any.
local function buttonAt(position)
	for action, button in touchButtons do
		local radius = button.AbsoluteSize.X / 2
		local middle = button.AbsolutePosition + button.AbsoluteSize / 2
		if (Vector2.new(position.X, position.Y) - middle).Magnitude <= radius * REACH then
			return action
		end
	end
	return nil
end

local function useDevice(kind)
	if device ~= kind then
		device = kind
		if touchGui then
			touchGui.Enabled = kind == "touch"
		end
	end
end

local KINDS = {
	[Enum.UserInputType.Touch] = "touch",
	[Enum.UserInputType.Keyboard] = "keyboard",
	[Enum.UserInputType.MouseButton1] = "keyboard",
	[Enum.UserInputType.MouseButton2] = "keyboard",
	[Enum.UserInputType.MouseMovement] = "keyboard",
	[Enum.UserInputType.Gamepad1] = "pad",
}

function Controls.start()
	for name, config in ACTIONS do
		for _, key in config.keys do
			byKey[Enum.KeyCode[key]] = name
		end
		for _, button in config.pad do
			byPad[Enum.KeyCode[button]] = name
		end
		if config.mouse then
			byMouse[Enum.UserInputType[config.mouse]] = name
		end
	end

	if UserInputService.TouchEnabled then
		buildTouch()
		workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(layOut)
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layOut)
	end
	useDevice(KINDS[UserInputService:GetLastInputType()] or (if UserInputService.TouchEnabled then "touch" else "keyboard"))
	UserInputService.LastInputTypeChanged:Connect(function(kind)
		if KINDS[kind] then
			useDevice(KINDS[kind])
		end
	end)

	-- Roblox's controls load in their own time.
	task.spawn(function()
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 15)
		if module then
			moveControls = require(module):GetControls()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			local action = not processed and buttonAt(input.Position)
			if action then
				fingers[input] = action
				feed(action, true, "touch")
			end
			return
		end
		-- A key typed into a text box, or a click on a menu, is not for the game.
		local pad = byPad[input.KeyCode]
		if pad then
			-- While a menu is open the controller is steering that, all but
			-- the button that opens and closes the loadout.
			if not Focus.active() or pad == "Loadout" then
				feed(pad, true, "pad")
			end
		elseif not processed then
			local action = byKey[input.KeyCode] or byMouse[input.UserInputType]
			if action then
				feed(action, true, "keyboard")
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			local action = fingers[input]
			if action then
				fingers[input] = nil
				feed(action, false, "touch")
			end
			return
		end
		local pad = byPad[input.KeyCode]
		if pad then
			feed(pad, false, "pad")
		else
			local action = byKey[input.KeyCode] or byMouse[input.UserInputType]
			if action then
				feed(action, false, "keyboard")
			end
		end
	end)
end

return Controls
