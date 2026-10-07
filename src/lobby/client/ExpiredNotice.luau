-- Tells a player, when they walk into the penthouse, which of their rentals
-- have run out. A rental that ends in the middle of a match stays usable until
-- that match is over (see Economy), so this is the first they hear of it.
--
-- Two ways out: straight to the shop to rent it again, or just "OK". Either
-- one tells the server it has been seen, so it is not shown twice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmorConfig = require(Shared.Config.ArmorConfig)
local TacticalConfig = require(Shared.Config.TacticalConfig)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Catalog = require(Shared.Logic.Catalog)
local Remotes = require(Shared.Remotes)

local Fit = require(script.Parent.Fit)
local Focus = require(script.Parent.Focus)
local ShopMenu = require(script.Parent.ShopMenu)

local ExpiredNotice = {}

local DISPLAY = Enum.Font[Theme.display]
local FONT = Enum.Font[Theme.body]
local BOLD = Enum.Font[Theme.bodyBold]
local SIZE = Theme.size

local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local INK = Color3.fromRGB(table.unpack(Theme.ink))
local PAPER = Color3.fromRGB(table.unpack(Theme.paper))
local MUTED = Color3.fromRGB(table.unpack(Theme.muted))
local PANEL = Color3.fromRGB(table.unpack(Theme.panel))
local RAISED = Color3.fromRGB(table.unpack(Theme.raised))
local SUNKEN = Color3.fromRGB(table.unpack(Theme.sunken))

local CATALOG = Catalog.fields(WeaponConfig, TacticalConfig, ArmorConfig)

local WIDTH = 520
local ROW_HEIGHT = 44
local MOST_ROWS = 5 -- more than this and the list scrolls

local player = Players.LocalPlayer
local gui, body, list, renewButton, okButton
local firstField = nil -- the loadout field of the first thing listed

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

-- What ran out, in the order the shop lists things: { { entry, item } }.
local function lapsed(expired)
	local found = {}
	for _, entry in CATALOG do
		for _, option in entry.order do
			if expired[entry.field .. "/" .. option] then
				table.insert(found, { entry = entry, item = entry.source[option] })
			end
		end
	end
	return found
end

local function close()
	if gui.Enabled then
		gui.Enabled = false
		Focus.off(body)
		Remotes.AckExpired:FireServer()
	end
end

local function show(items)
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	for index, found in items do
		local row = make("Frame", {
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT - 6),
			BackgroundColor3 = SUNKEN,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, list)
		text({
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -150, 1, 0),
			Font = BOLD,
			Text = found.item.displayName,
			TextSize = SIZE.label,
		}, row)
		text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 0),
			Size = UDim2.new(0, 130, 1, 0),
			Text = found.entry.title,
			TextSize = SIZE.small,
			TextColor3 = MUTED,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, row)
	end

	local shown = math.min(#items, MOST_ROWS)
	local listHeight = shown * ROW_HEIGHT
	list.Size = UDim2.fromOffset(WIDTH - 48, listHeight)
	body.Size = UDim2.fromOffset(WIDTH, 118 + listHeight + 70)
	renewButton.Position = UDim2.fromOffset(24, 118 + listHeight + 16)
	okButton.Position = UDim2.fromOffset(24 + 250 + 12, 118 + listHeight + 16)

	firstField = items[1].entry.field
	if not gui.Enabled then
		gui.Enabled = true
		Focus.on(body, close)
	end
end

local function build()
	gui = make("ScreenGui", {
		Name = "ExpiredNotice",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30, -- over the loadout and the shop
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))

	Fit.attach(gui)

	-- Frees the mouse, and keeps clicks off whatever is behind.
	make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Modal = true,
		Selectable = false,
	}, gui)

	body = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, 300),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
	}, gui)
	make("Frame", { -- a rule across the top, in the accent colour
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
	}, body)

	text({
		Position = UDim2.fromOffset(24, 24),
		Size = UDim2.fromOffset(WIDTH - 48, 26),
		Font = DISPLAY,
		Text = "RENTAL ENDED",
		TextSize = SIZE.heading,
		TextColor3 = ACCENT,
	}, body)
	text({
		Position = UDim2.fromOffset(24, 58),
		Size = UDim2.fromOffset(WIDTH - 48, 44),
		Text = "Your time on these has run out, so they are no longer in your loadout. Rent them again to carry on using them.",
		TextSize = SIZE.body,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, body)

	list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(24, 112),
		Size = UDim2.fromOffset(WIDTH - 48, ROW_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, body)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	renewButton = make("TextButton", {
		Size = UDim2.fromOffset(250, 40),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = BOLD,
		Text = "RENEW IN THE SHOP",
		TextSize = SIZE.body,
		TextColor3 = INK,
	}, body)
	renewButton.MouseButton1Click:Connect(function()
		close()
		ShopMenu.setOpen(true, firstField)
	end)

	okButton = make("TextButton", {
		Size = UDim2.fromOffset(WIDTH - 48 - 250 - 12, 40),
		BackgroundColor3 = RAISED,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = FONT,
		Text = "OK",
		TextSize = SIZE.body,
		TextColor3 = PAPER,
	}, body)
	okButton.MouseButton1Click:Connect(close)
end

function ExpiredNotice.start()
	build()
	Remotes.ProfileUpdate.OnClientEvent:Connect(function(profile)
		local items = lapsed(profile.expired or {})
		if #items > 0 then
			show(items)
		elseif gui.Enabled then
			gui.Enabled = false -- acknowledged from somewhere else
			Focus.off(body)
		end
	end)
end

return ExpiredNotice
