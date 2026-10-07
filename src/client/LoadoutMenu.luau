-- The loadout: choosing between the things a player already owns. One row per
-- choice: primary, secondary, melee, grenade, tactical item and the four
-- armour slots, plus a second primary or second grenade while the gloves
-- picked carry one. The pick is sent to the server and takes effect at the
-- next spawn.
--
-- Only what the player owns is listed. In the lobby everything can be changed
-- freely, and a button opens the shop. In a match nothing can be bought:
--   weapons and grenades can be swapped, and each one not carried last life
--     costs a few points when the player spawns with it;
--   the tactical item and armour are locked, unless the game sells changes of
--     them for Robux (ShopConfig.matchSwap), in which case a click buys one.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmorConfig = require(Shared.Config.ArmorConfig)
local ShopConfig = require(Shared.Config.ShopConfig)
local Loadout = require(Shared.Logic.Loadout)
local TacticalConfig = require(Shared.Config.TacticalConfig)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Economy = require(Shared.Logic.Economy)
local Rank = require(Shared.Logic.Rank)
local Remotes = require(Shared.Remotes)

local LoadoutMenu = {}

local TOGGLE_KEY = Enum.KeyCode.B

local DISPLAY = Enum.Font[Theme.display]
local FONT = Enum.Font[Theme.body]
local SIZE = Theme.size
local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local INK = Color3.fromRGB(table.unpack(Theme.ink))
local PANEL = Color3.fromRGB(table.unpack(Theme.panel))
local IDLE = Color3.fromRGB(table.unpack(Theme.raised))
local LOCKED = Color3.fromRGB(table.unpack(Theme.sunken))
local WHITE = Color3.fromRGB(table.unpack(Theme.paper))
local GREY = Color3.fromRGB(table.unpack(Theme.muted))

local ROW_HEIGHT = 42
local ROW_GAP = 12
local TITLE_WIDTH = 200
local BUTTON_WIDTH = 136
local GAP = 8
local MOST_OPTIONS = 4
local HEADER, FOOTER = 70, 64
local SCREEN_MARGIN = 60 -- pixels of screen always left clear above and below the panel
local WIDTH = 24 + TITLE_WIDTH + MOST_OPTIONS * (BUTTON_WIDTH + GAP) + 16

local NONE = "" -- the key of "carry nothing here" in a second-weapon row

local SWAP_PRODUCT = ShopConfig.matchSwap.armourProductId
local LOBBY_ONLY = "Armour and tactical items are changed in the lobby"

local player = Players.LocalPlayer
local gui, panel, stack, stackLayout, noteLabel, profileLabel

local rows = {} -- { field, frame, second = Loadout.SECOND entry or nil, buttons = { [key] = { button, option } } }

local choice = nil -- the loadout picked for the next spawn, as the server last confirmed it
local profile = nil -- points, level and rentals, as the server last sent them
local clockOffset = 0 -- server clock minus ours
local inMatch = false
local shop = nil -- the shop screen, in the lobby
local swapPrice = nil -- Robux for one armour change, once Roblox has told us

-- In a match: true if this field cannot be changed at all.
local function locked(field)
	return inMatch and not Loadout.isWeaponField(field) and SWAP_PRODUCT == 0
end

-- In a match: true if changing this field costs a Robux purchase.
local function paid(field)
	return inMatch and not Loadout.isWeaponField(field) and SWAP_PRODUCT ~= 0
end

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
		TextColor3 = WHITE,
		TextSize = SIZE.body,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in properties do
		merged[key] = value
	end
	return make("TextLabel", merged, parent)
end

local function now()
	return os.time() + clockOffset
end

local function owns(field, key)
	if key == NONE then
		return true
	elseif profile then
		-- `held`: what was taken into this match stays usable until it ends.
		return Economy.owns(ShopConfig, profile, field, key, now(), profile.held)
	end
	return Economy.isFree(ShopConfig, field, key)
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

-- The second line under a rented option's name: the time left on it. Weapons
-- and grenades are rented by the hour of use, the rest by the day.
local function status(field, key)
	if key == NONE or Economy.isFree(ShopConfig, field, key) or not profile then
		return nil
	end
	local sold = Economy.shopField(ShopConfig, field)
	local rental = profile.rentals[Economy.key(sold, key)]
	local seconds = Economy.timeLeft(profile, sold, key, now())
	if not rental or seconds <= 0 then
		return "UNTIL THE MATCH ENDS" -- it ran out, and is held to the end of this match
	end
	local left = duration(seconds)
	if ShopConfig.timing[sold] == "use" then
		return left .. " OF USE"
	end
	return if rental.expiresAt then left .. " LEFT" else left .. " UNUSED"
end

-- { field, title, options = { { key, name, note } } } for every row, top to bottom.
local function describe()
	local function weapons(names, withNone)
		local options = {}
		if withNone then
			table.insert(options, { key = NONE, name = "None", note = "Carry nothing here" })
		end
		for _, key in names do
			local config = WeaponConfig.Weapons[key]
			table.insert(options, { key = key, name = config.displayName, note = config.note or "" })
		end
		return options
	end

	local function pieces(order, source)
		local options = {}
		for _, key in order do
			table.insert(options, { key = key, name = source[key].displayName, note = source[key].note })
		end
		return options
	end

	local list = {
		{ field = "primary", title = "Primary  [1]", options = weapons(WeaponConfig.PrimaryOrder) },
		{ field = "primary2", title = "Primary 2  [1 again]", options = weapons(WeaponConfig.PrimaryOrder, true) },
		{ field = "secondary", title = "Secondary  [2]", options = weapons(WeaponConfig.SecondaryOrder) },
		{ field = "melee", title = "Melee  [3]", options = weapons(WeaponConfig.MeleeOrder) },
		{ field = "nade", title = "Grenade  [4]", options = weapons(WeaponConfig.NadeOrder) },
		{ field = "nade2", title = "Grenade 2  [4 again]", options = weapons(WeaponConfig.NadeOrder, true) },
		{ field = "tactical", title = "Tactical  [E]", options = pieces(TacticalConfig.order, TacticalConfig.items) },
	}
	for _, slot in ArmorConfig.slots do
		table.insert(list, {
			field = slot,
			title = ArmorConfig.titles[slot],
			options = pieces(ArmorConfig.order[slot], ArmorConfig[slot]),
		})
	end
	return list
end

-- What it would cost to change a tactical item or armour piece here.
local function swapCost()
	local held = profile and profile.swaps or 0
	if held > 0 then
		return string.format("uses 1 of your %d armour changes", held)
	elseif swapPrice then
		return string.format("costs %d Robux to change here", swapPrice)
	end
	return "costs Robux to change here"
end

-- Makes the panel as tall as its rows, up to what the screen has room for;
-- past that the rows scroll.
local function fit()
	local camera = workspace.CurrentCamera
	local room = if camera then camera.ViewportSize.Y - SCREEN_MARGIN else math.huge
	local wanted = HEADER + stackLayout.AbsoluteContentSize.Y + FOOTER
	panel.Size = UDim2.fromOffset(WIDTH, math.min(wanted, math.max(room, HEADER + ROW_HEIGHT + FOOTER)))
end

local function refresh()
	if profile then
		profileLabel.Text = string.format(
			"%s     %d PTS     XP %d / %d",
			string.upper(Rank.of(ShopConfig.ranks, profile.level).title),
			profile.points,
			profile.xp,
			profile.xpNeeded
		)
	end

	local stats = choice and Loadout.stats(ArmorConfig, choice)
	for _, row in rows do
		-- A second primary or grenade is only offered while the gloves picked carry one.
		local offered = not row.second or (stats ~= nil and stats[row.second.stat])
		row.frame.Visible = offered
		if not offered then
			continue
		end

		for key, entry in row.buttons do
			local picked = choice ~= nil and (choice[row.field] or NONE) == key
			-- What is not owned is not here at all: it is in the shop. And the
			-- second of anything is never the same as the first.
			local same = row.second ~= nil and choice ~= nil and key == choice[row.second.first]
			entry.button.Visible = owns(row.field, key) and not same
			local line = status(row.field, key)
			entry.button.Text = if line then entry.option.name .. "\n" .. line else entry.option.name
			if locked(row.field) then
				-- Shown, so the player can see what they are wearing, but not changeable here.
				entry.button.BackgroundColor3 = if picked then IDLE else LOCKED
				entry.button.TextColor3 = if picked then WHITE else GREY
			else
				entry.button.BackgroundColor3 = if picked then ACCENT else IDLE
				entry.button.TextColor3 = if picked then INK else WHITE
			end
		end
	end
	fit()
end

local function describeOption(field, option)
	local line = string.format("%s  -  %s", option.name, option.note)
	if paid(field) and choice and choice[field] ~= option.key then
		line ..= "   (" .. swapCost() .. ")"
	end
	return line
end

local function pick(field, option)
	if not choice then
		return -- the server has not told us our loadout yet
	end
	if locked(field) then
		noteLabel.Text = LOBBY_ONLY
		return
	end
	if not owns(field, option.key) or (choice[field] or NONE) == option.key then
		return
	end

	local wanted = table.clone(choice)
	wanted[field] = if option.key == NONE then nil else option.key
	-- Picking as the first what is already the second swaps the two round.
	for second, rule in Loadout.SECOND do
		if rule.first == field and wanted[second] == wanted[field] then
			wanted[second] = choice[field]
		end
	end

	if paid(field) then
		-- Nothing changes until the server says the change is paid for.
		noteLabel.Text = if (profile and profile.swaps or 0) > 0
			then string.format("%s  -  using one of your armour changes", option.name)
			else string.format("%s  -  waiting for the purchase", option.name)
		Remotes.SelectLoadout:FireServer(wanted)
		return
	end

	choice = wanted
	noteLabel.Text = string.format("%s  -  %s", option.name, option.note)
	refresh()
	Remotes.SelectLoadout:FireServer(choice)
end

local function build()
	gui = make("ScreenGui", {
		Name = "LoadoutMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))

	-- A modal button behind everything frees the mouse while the menu is open,
	-- and swallows clicks so they do not fire the weapon.
	make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Modal = true,
	}, gui)

	panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, 400),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
	}, gui)

	text({
		Position = UDim2.fromOffset(24, 16),
		Size = UDim2.fromOffset(300, 26),
		Font = DISPLAY,
		Text = "LOADOUT",
		TextSize = SIZE.heading,
		TextColor3 = ACCENT,
	}, panel)
	profileLabel = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 20),
		Size = UDim2.fromOffset(420, 20),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
	}, panel)
	text({
		Position = UDim2.fromOffset(24, 42),
		Size = UDim2.fromOffset(WIDTH - 48, 18),
		Text = if inMatch
			then string.format(
				"Applies at your next spawn   -   a weapon you were not carrying costs %d points   -   [B] to close",
				ShopConfig.matchSwap.weaponPoints
			)
			else "Applies at your next spawn   -   [B] to close",
		TextSize = SIZE.small,
		TextColor3 = GREY,
	}, panel)

	-- The rows stack, and close up around any that are hidden. A player who
	-- owns a great deal gets a list that scrolls, not one that runs off the panel.
	stack = make("ScrollingFrame", {
		Position = UDim2.fromOffset(24, HEADER),
		Size = UDim2.new(1, -40, 1, -HEADER - FOOTER),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, panel)
	stackLayout = make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, ROW_GAP) }, stack)
	stackLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)

	for index, described in describe() do
		local frame = make("Frame", {
			Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = index,
		}, stack)
		text({ Size = UDim2.fromOffset(TITLE_WIDTH, ROW_HEIGHT), Text = described.title }, frame)

		-- The options sit in a grid that closes up around anything hidden, so
		-- a player only ever sees what they can actually take, and wraps onto
		-- as many lines as that needs.
		local shelf = make("Frame", {
			Position = UDim2.fromOffset(TITLE_WIDTH, 0),
			Size = UDim2.new(1, -TITLE_WIDTH, 0, ROW_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, frame)
		make("UIGridLayout", {
			CellSize = UDim2.fromOffset(BUTTON_WIDTH, ROW_HEIGHT),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			FillDirectionMaxCells = MOST_OPTIONS,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, shelf)

		local row = { field = described.field, frame = frame, second = Loadout.SECOND[described.field], buttons = {} }
		for position, option in described.options do
			local button = make("TextButton", {
				LayoutOrder = position,
				Size = UDim2.fromOffset(BUTTON_WIDTH, ROW_HEIGHT),
				BackgroundColor3 = IDLE,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = FONT,
				Text = option.name,
				TextSize = SIZE.small,
				TextColor3 = WHITE,
			}, shelf)
			button.MouseButton1Click:Connect(function()
				pick(row.field, option)
			end)
			button.MouseEnter:Connect(function()
				noteLabel.Text = if locked(row.field) then LOBBY_ONLY else describeOption(row.field, option)
			end)
			row.buttons[option.key] = { button = button, option = option }
		end
		table.insert(rows, row)
	end

	noteLabel = text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -16),
		Size = UDim2.new(1, if shop then -48 - 170 else -48, 0, 34),
		Text = "",
		TextColor3 = ACCENT,
		TextWrapped = true,
	}, panel)

	-- Renting is done on its own screen, and only in the lobby.
	if shop then
		local open = make("TextButton", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -24, 1, -16),
			Size = UDim2.fromOffset(150, 34),
			BackgroundColor3 = ACCENT,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = FONT,
			Text = "OPEN THE SHOP",
			TextSize = SIZE.small,
			TextColor3 = INK,
		}, panel)
		open.MouseButton1Click:Connect(function()
			shop.setOpen(true)
		end)
	end
end

-- Opens or closes the menu. Also bound to B.
function LoadoutMenu.setOpen(open)
	gui.Enabled = open
	if open then
		refresh() -- time left has moved on since it was last open
	end
end

-- `options.inMatch` is set in a match, where nothing can be bought and only
-- weapons change freely. `options.shop` is the shop screen, in the lobby.
function LoadoutMenu.start(options)
	options = options or {}
	inMatch = options.inMatch == true
	shop = options.shop
	build()
	refresh()

	if inMatch and SWAP_PRODUCT ~= 0 then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, SWAP_PRODUCT, Enum.InfoType.Product)
			if ok and info then
				swapPrice = info.PriceInRobux
			end
		end)
	end

	Remotes.LoadoutUpdate.OnClientEvent:Connect(function(payload)
		choice = table.clone(payload.choice)
		refresh()
	end)
	Remotes.ProfileUpdate.OnClientEvent:Connect(function(payload)
		profile = payload
		clockOffset = payload.now - os.time()
		refresh()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == TOGGLE_KEY and (not processed or gui.Enabled) then
			LoadoutMenu.setOpen(not gui.Enabled)
		end
	end)
end

return LoadoutMenu
