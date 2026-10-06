-- The shop: browse what can be rented, and rent it. A separate screen from
-- the loadout, which is only for choosing between things already owned. It is
-- in the lobby only: nothing is sold during a match.
--
-- A category down the left, its items on the right. Each item shows what it
-- does, what it costs, and how long is left on it. Weapons are rented by the
-- hour of use, everything else by the day (see ShopConfig).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmorConfig = require(Shared.Config.ArmorConfig)
local ShopConfig = require(Shared.Config.ShopConfig)
local TacticalConfig = require(Shared.Config.TacticalConfig)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Catalog = require(Shared.Logic.Catalog)
local Economy = require(Shared.Logic.Economy)
local Rank = require(Shared.Logic.Rank)
local Remotes = require(Shared.Remotes)

local ShopMenu = {}

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

local WIDTH, HEIGHT = 980, 620
local SIDEBAR = 210
local ROW_HEIGHT = 74
local PAD = 20

local player = Players.LocalPlayer
local gui, body, itemList, pointsLabel, noteLabel
local categoryButtons = {}
local chosen = nil -- the category being shown
local profile = nil
local clockOffset = 0

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

local function button(properties, parent, onClick)
	local merged = {
		BackgroundColor3 = RAISED,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = FONT,
		TextColor3 = PAPER,
		TextSize = SIZE.body,
	}
	for key, value in properties do
		merged[key] = value
	end
	local instance = make("TextButton", merged, parent)
	instance.MouseButton1Click:Connect(onClick)
	return instance
end

-- Every category the shop sells, in the order the loadout uses them.
local CATEGORIES = Catalog.fields(WeaponConfig, TacticalConfig, ArmorConfig)

local function now()
	return os.time() + clockOffset
end

local function duration(seconds)
	seconds = math.floor(seconds)
	if seconds >= 86400 then
		return string.format("%dd %02dh", seconds // 86400, seconds % 86400 // 3600)
	elseif seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, seconds % 3600 // 60)
	end
	return string.format("%dm", math.max(seconds // 60, 1))
end

-- What a player already has of this item.
local function holding(field, key)
	if Economy.isFree(ShopConfig, field, key) then
		return "Owned", "Yours, always"
	end
	if not profile or not Economy.owns(ShopConfig, profile, field, key, now()) then
		return "None", nil
	end
	local rental = profile.rentals[Economy.key(field, key)]
	local left = duration(Economy.timeLeft(profile, field, key, now()))
	if ShopConfig.timing[field] == "use" then
		return "Owned", left .. " of use left"
	end
	return "Owned", if rental.expiresAt then left .. " left" else left .. ", not started"
end

local function showCategory(category)
	chosen = category
	for field, entry in categoryButtons do
		local picked = field == category.field
		entry.BackgroundColor3 = if picked then ACCENT else RAISED
		entry.TextColor3 = if picked then INK else PAPER
	end

	for _, child in itemList:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local terms = Economy.terms(ShopConfig, category.field)
	for index, key in category.order do
		local item = category.source[key]
		local state, detail = holding(category.field, key)
		local row = make("Frame", {
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundColor3 = SUNKEN,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, itemList)

		text({
			Position = UDim2.fromOffset(16, 10),
			Size = UDim2.fromOffset(300, 22),
			Font = BOLD,
			Text = item.displayName,
			TextSize = SIZE.label,
		}, row)
		text({
			Position = UDim2.fromOffset(16, 34),
			Size = UDim2.fromOffset(420, 20),
			Text = item.note or "",
			TextSize = SIZE.small,
			TextColor3 = MUTED,
		}, row)
		text({
			Position = UDim2.fromOffset(16, 52),
			Size = UDim2.fromOffset(420, 18),
			Text = detail or "",
			TextSize = SIZE.small,
			TextColor3 = if state == "Owned" then ACCENT else MUTED,
		}, row)

		if state ~= "Owned" or not Economy.isFree(ShopConfig, category.field, key) then
			local unit = ShopConfig.prices[category.field][key]
			text({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -16, 0, 10),
				Size = UDim2.fromOffset(200, 20),
				Text = string.format("%d points per %s", unit, if terms.label == "H" then "hour of use" else "day"),
				TextSize = SIZE.small,
				TextColor3 = MUTED,
				TextXAlignment = Enum.TextXAlignment.Right,
			}, row)

			local width, gap = 84, 8
			for place, length in terms.lengths do
				local price = Economy.price(ShopConfig, category.field, key, length.amount)
				local affordable = profile ~= nil and profile.points >= price
				button({
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -16 - (#terms.lengths - place) * (width + gap), 1, -10),
					Size = UDim2.fromOffset(width, 30),
					BackgroundColor3 = if affordable then ACCENT else RAISED,
					TextColor3 = if affordable then INK else MUTED,
					Text = string.format("%d%s   %d", length.amount, terms.label, price),
					TextSize = SIZE.small,
				}, row, function()
					Remotes.BuyRental:FireServer(category.field, key, length.amount)
					noteLabel.Text = string.format("Renting %s for %d%s...", item.displayName, length.amount, terms.label)
				end)
			end
		end
	end
end

local function refresh()
	if profile then
		pointsLabel.Text = string.format("%d POINTS      %s", profile.points, string.upper(Rank.of(ShopConfig.ranks, profile.level).title))
	end
	if chosen then
		showCategory(chosen)
	end
end

local function build()
	gui = make("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 22,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))

	-- Frees the mouse and swallows clicks while the shop is open.
	make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Modal = true,
	}, gui)

	body = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
	}, gui)

	text({
		Position = UDim2.fromOffset(PAD, 16),
		Size = UDim2.fromOffset(400, 30),
		Font = DISPLAY,
		Text = "SHOP",
		TextSize = SIZE.heading,
		TextColor3 = ACCENT,
	}, body)
	pointsLabel = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD - 110, 0, 20),
		Size = UDim2.fromOffset(400, 22),
		Text = "",
		TextSize = SIZE.label,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, body)
	button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD, 0, 16),
		Size = UDim2.fromOffset(100, 30),
		Text = "CLOSE",
	}, body, function()
		ShopMenu.setOpen(false)
	end)

	local sidebar = make("Frame", {
		Position = UDim2.fromOffset(PAD, 60),
		Size = UDim2.fromOffset(SIDEBAR, HEIGHT - 60 - 54),
		BackgroundTransparency = 1,
	}, body)
	make("UIListLayout", { Padding = UDim.new(0, 6) }, sidebar)

	for index, category in CATEGORIES do
		categoryButtons[category.field] = button({
			Size = UDim2.new(1, 0, 0, 34),
			Text = category.title,
			TextSize = SIZE.body,
			LayoutOrder = index,
		}, sidebar, function()
			showCategory(category)
		end)
	end

	itemList = make("ScrollingFrame", {
		Position = UDim2.fromOffset(PAD + SIDEBAR + 16, 60),
		Size = UDim2.fromOffset(WIDTH - SIDEBAR - PAD * 2 - 16, HEIGHT - 60 - 54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, body)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, itemList)

	noteLabel = text({
		Position = UDim2.fromOffset(PAD, HEIGHT - 44),
		Size = UDim2.fromOffset(WIDTH - PAD * 2, 24),
		Text = "Weapons are rented by the hour you spend using them. Everything else runs by the day from first use.",
		TextSize = SIZE.small,
		TextColor3 = MUTED,
	}, body)
end

-- `field`, if given, is the loadout field whose category to open at.
function ShopMenu.setOpen(open, field)
	gui.Enabled = open
	local category = field and Catalog.field(CATEGORIES, field)
	if open and category then
		showCategory(category)
	elseif open then
		refresh()
	end
end

function ShopMenu.isOpen()
	return gui ~= nil and gui.Enabled
end

function ShopMenu.start()
	build()
	showCategory(CATEGORIES[1])

	Remotes.ProfileUpdate.OnClientEvent:Connect(function(update)
		profile = update
		clockOffset = update.now - os.time()
		refresh()
	end)
end

return ShopMenu
