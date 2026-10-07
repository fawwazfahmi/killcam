-- The test range's admin panel: two pages of switches, opened with P or from
-- the foot of the loadout menu.
--
--   Dummies  how the dummies behave: whether they die, what they wear,
--            whether they walk, crouch or shoot back, and placing more. It
--            changes every dummy, or only the one that was being aimed at
--            when the panel was opened (failing that, the one last hit).
--   You      the admin's own switches (RangeConfig.cheats), bullet marks,
--            healing, being hit on purpose, and going somewhere on the range.
--
-- Nothing here decides anything. Each button asks the server, which checks
-- who is asking and what for, and the panel shows what the server says back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmorConfig = require(Shared.Config.ArmorConfig)
local RangeConfig = require(Shared.Config.RangeConfig)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Dummy = require(Shared.Logic.Dummy)
local Remotes = require(Shared.Remotes)

local Client = script.Parent.Parent
local Effects = require(Client.Effects)
local Fit = require(Client.Fit)
local Focus = require(Client.Focus)
local Readout = require(script.Parent.Readout)

local Panel = {}

local TOGGLE_KEY = Enum.KeyCode.P
local ALL = "all"
local PAGES = { "Dummies", "You" }

local DISPLAY = Enum.Font[Theme.display]
local FONT = Enum.Font[Theme.body]
local SIZE = Theme.size
local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local INK = Color3.fromRGB(table.unpack(Theme.ink))
local PANEL = Color3.fromRGB(table.unpack(Theme.panel))
local IDLE = Color3.fromRGB(table.unpack(Theme.raised))
local WHITE = Color3.fromRGB(table.unpack(Theme.paper))
local GREY = Color3.fromRGB(table.unpack(Theme.muted))

local ROW_HEIGHT = 36
local ROW_GAP = 12
local TITLE_WIDTH = 170
local BUTTON_WIDTH = 140
local GAP = 8
local MOST_OPTIONS = 4
local HEADER, FOOTER = 70, 56
local SCREEN_MARGIN = 60 -- pixels of screen always left clear above and below the panel
local WIDTH = 24 + TITLE_WIDTH + MOST_OPTIONS * (BUTTON_WIDTH + GAP) + 16

local player = Players.LocalPlayer

-- As the server last sent them: every dummy and its settings, this player's
-- switches, and the places they can be sent.
local range = { dummies = {}, cheats = {}, spots = {} }

local scope = ALL -- which dummies a change is for: all of them, or the id of one
local offered = nil -- the id of the one dummy that can be changed alone
local aim = RangeConfig.defaultAim -- where "hit me with" lands
local marksStay = false
local page = PAGES[1]

local gui, panel, noteLabel, statusLabel, screenScale
local pages = {} -- [name] = { tab, stack, layout, rows = number }
local buttons = {} -- { button, option } for every button on either page
local placesListed = false

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

local function ask(...)
	Remotes.RangeCommand:FireServer(...)
end

local function say(line)
	noteLabel.Text = line
end

local function dummyOf(id)
	for _, dummy in range.dummies do
		if dummy.id == id then
			return dummy
		end
	end
	return nil
end

-- What `field` is set to on the dummies a change is for, or nil where they differ.
local function setting(field)
	if scope ~= ALL then
		local dummy = dummyOf(scope)
		return dummy and dummy.settings[field]
	end
	local value = nil
	for index, dummy in range.dummies do
		if index == 1 then
			value = dummy.settings[field]
		elseif dummy.settings[field] ~= value then
			return nil
		end
	end
	return value
end

-- The dummy under the crosshair, by its id, or nil.
local function aimedAt()
	local camera = workspace.CurrentCamera
	local ignore = { camera }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * RangeConfig.dummy.reach, params)
	local model = result and result.Instance:FindFirstAncestorOfClass("Model")
	local id = model and model:GetAttribute("Dummy")
	return if type(id) == "number" then id else nil
end

-- Asks for a dummy on the ground where the crosshair is.
local function place()
	local map = workspace:FindFirstChild("Map")
	local geometry = map and map:FindFirstChild("Geometry")
	if not geometry then
		return
	end
	local camera = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { geometry }
	local result = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * RangeConfig.dummy.reach, params)
	if result then
		ask("Place", result.Position)
		say("Placed where you were looking. Close this and aim at it to change it alone")
	else
		say("Close this, look at the ground where you want one, and try again")
	end
end

-- Options -------------------------------------------------------------------
--
-- A row is a title and its options. An option is { name, note, lit, run }:
-- `name` is its label, or a function giving it; `lit` says whether it is
-- picked or switched on; `run` is what pressing it does.

local function never()
	return false
end

-- An option that sets `field` to `value` on the dummies a change is for.
local function sets(field, value, name, note)
	return {
		name = name,
		note = note,
		lit = function()
			return setting(field) == value
		end,
		run = function()
			ask("Dummy", scope, field, value)
		end,
	}
end

local function armourOptions(slot, bare)
	local options = { sets(slot, Dummy.BARE, "BARE", bare) }
	for _, key in ArmorConfig.order[slot] do
		local piece = ArmorConfig[slot][key]
		table.insert(options, sets(slot, key, string.upper(piece.displayName), piece.note))
	end
	return options
end

-- One option per gun in the game, made by `build(name, config)`.
local function gunOptions(build)
	local options = {}
	for _, list in { WeaponConfig.PrimaryOrder, WeaponConfig.SecondaryOrder } do
		for _, name in list do
			table.insert(options, build(name, WeaponConfig.Weapons[name]))
		end
	end
	return options
end

local function dummyRows()
	local guns = gunOptions(function(name, config)
		return sets("weapon", name, string.upper(config.displayName), "Fires this at you, as fast as it fires, and does not miss")
	end)
	table.insert(guns, 1, sets("weapon", Dummy.UNARMED, "NOTHING", "Does not shoot back"))

	local aims = {}
	for _, entry in RangeConfig.aims do
		table.insert(aims, sets("aim", entry.name, string.upper(entry.name), "Where a dummy that shoots back hits you"))
	end

	return {
		{
			title = "Change",
			options = {
				{
					name = "ALL DUMMIES",
					note = "What you set below goes for every dummy",
					lit = function()
						return scope == ALL
					end,
					run = function()
						scope = ALL
					end,
				},
				{
					name = function()
						local dummy = offered and dummyOf(offered)
						return if dummy then dummy.label else "NONE AIMED AT"
					end,
					note = "Only the dummy you were aiming at when you opened this, or failing that the one you last hit",
					lit = function()
						return scope ~= ALL
					end,
					run = function()
						if offered and dummyOf(offered) then
							scope = offered
						end
					end,
				},
			},
		},
		{
			title = "When killed",
			options = {
				sets("dies", true, "DIES", "Falls, and is back on its feet a moment later"),
				sets("dies", false, "STAYS UP", "A killing hit is counted as one, and it is at full health again at once"),
			},
		},
		{ title = "Helmet", options = armourOptions("helmet", "No helmet: headshots do all their damage") },
		{ title = "Body armour", options = armourOptions("body", "No body armour: every weapon does all its damage") },
		{
			title = "Movement",
			options = {
				sets("moves", false, "STANDS STILL", "Stays where it was put"),
				sets("moves", true, "WALKS", "Walks from side to side at a player's speed, still facing the same way"),
			},
		},
		{
			title = "Stance",
			options = {
				sets("crouched", false, "STANDING", "At a player's full height"),
				sets("crouched", true, "CROUCHED", "As low as a crouching player, and as slow if it walks"),
			},
		},
		{ title = "Shoots back with", options = guns },
		{ title = "Aims at your", options = aims },
		{
			title = "Place and clear",
			options = {
				{ name = "PLACE ONE", note = "Stands a new dummy on the ground where your crosshair is", lit = never, run = place },
				{
					name = "REMOVE THIS ONE",
					note = "Takes away the one dummy picked above, if you placed it",
					lit = never,
					run = function()
						if scope ~= ALL then
							ask("Remove", scope)
						end
					end,
				},
				{
					name = "REMOVE PLACED",
					note = "Takes away every dummy that was placed. The range's own stay",
					lit = never,
					run = function()
						ask("Remove", "placed")
					end,
				},
				{
					name = "STAND ALL UP",
					note = "Every dummy back at its post, on its feet and at full health",
					lit = never,
					run = function()
						ask("StandAll")
					end,
				},
			},
		},
	}
end

local function youRows()
	local switches = {}
	for _, cheat in RangeConfig.cheats do
		table.insert(switches, {
			name = string.upper(cheat.title),
			note = cheat.note,
			lit = function()
				return range.cheats[cheat.name] == true
			end,
			run = function()
				ask("Cheat", cheat.name, range.cheats[cheat.name] ~= true)
			end,
		})
	end

	local amounts = {}
	for _, amount in RangeConfig.hurt do
		table.insert(amounts, {
			name = amount .. " HEALTH",
			note = "Takes exactly that off you. Armour does nothing about it",
			lit = never,
			run = function()
				ask("Hurt", amount)
			end,
		})
	end

	local aims = {}
	for _, entry in RangeConfig.aims do
		table.insert(aims, {
			name = string.upper(entry.name),
			note = "Where the guns in the next row hit you",
			lit = function()
				return aim == entry.name
			end,
			run = function()
				aim = entry.name
			end,
		})
	end

	return {
		{ title = "Switches", options = switches },
		{
			title = "On the range",
			options = {
				{
					name = "MARKS STAY",
					note = string.format("Bullet marks last %d seconds, to read a spray off the recoil wall", RangeConfig.marks),
					lit = function()
						return marksStay
					end,
					run = function()
						marksStay = not marksStay
						Effects.setImpactLife(if marksStay then RangeConfig.marks else nil)
					end,
				},
				{ name = "CLEAR MARKS", note = "Wipes the bullet marks", lit = never, run = Effects.clearImpacts },
				{ name = "CLEAR READOUT", note = "Empties the list of hits and its totals", lit = never, run = Readout.clear },
				{
					name = "HEAL ME",
					note = "Back to full health",
					lit = never,
					run = function()
						ask("Heal")
					end,
				},
			},
		},
		{ title = "Take off", options = amounts },
		{ title = "Hit me in the", options = aims },
		{
			title = "Hit me with",
			options = gunOptions(function(name, config)
				return {
					name = string.upper(config.displayName),
					note = "One shot from it, where the row above says, less what your armour stops",
					lit = never,
					run = function()
						ask("Hit", name, aim)
					end,
				}
			end),
		},
	}
end

-- The places on the range, once the server has listed them.
local function placeRow()
	local options = {}
	for index, spot in range.spots do
		table.insert(options, {
			name = string.upper(spot.name),
			note = "Puts you there",
			lit = never,
			run = function()
				ask("Go", index)
				-- In first person the body follows the view, so the view is what has to turn.
				local camera = workspace.CurrentCamera
				camera.CFrame = CFrame.new(camera.CFrame.Position) * CFrame.Angles(0, math.rad(spot.yaw), 0)
				Panel.setOpen(false)
			end,
		})
	end
	return { title = "Go to", options = options }
end

-- Screen ------------------------------------------------------------------------

-- Makes the panel as tall as the page showing, up to what the screen has room
-- for; past that the page scrolls.
local function fit()
	local camera = workspace.CurrentCamera
	local room = if camera then camera.ViewportSize.Y / screenScale.Scale - SCREEN_MARGIN else math.huge
	local wanted = HEADER + pages[page].layout.AbsoluteContentSize.Y + FOOTER
	panel.Size = UDim2.fromOffset(WIDTH, math.min(wanted, math.max(room, HEADER + ROW_HEIGHT + FOOTER)))
end

-- The line under the score: how to open the panel, and what is switched on.
local function status()
	local parts = { if UserInputService.KeyboardEnabled then "[P] TEST PANEL" else "TEST PANEL: AT THE FOOT OF THE LOADOUT MENU" }
	for _, cheat in RangeConfig.cheats do
		if range.cheats[cheat.name] then
			table.insert(parts, string.upper(cheat.title))
		end
	end
	statusLabel.Text = table.concat(parts, "     ")
end

local function refresh()
	if scope ~= ALL and not dummyOf(scope) then
		scope = ALL -- the one being changed has been removed
	end
	for name, entry in pages do
		entry.stack.Visible = name == page
		entry.tab.BackgroundColor3 = if name == page then ACCENT else IDLE
		entry.tab.TextColor3 = if name == page then INK else WHITE
	end
	for _, entry in buttons do
		local option = entry.option
		local lit = option.lit()
		if type(option.name) == "function" then
			entry.button.Text = option.name()
		end
		entry.button.BackgroundColor3 = if lit then ACCENT else IDLE
		entry.button.TextColor3 = if lit then INK else WHITE
	end
	status()
	fit()
end

local function addRow(name, row)
	local entry = pages[name]
	entry.rows += 1
	local frame = make("Frame", {
		Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = entry.rows,
	}, entry.stack)
	text({ Size = UDim2.fromOffset(TITLE_WIDTH, ROW_HEIGHT), Text = row.title }, frame)

	-- The options wrap onto as many lines as they need.
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

	for position, option in row.options do
		local label = if type(option.name) == "function" then option.name() else option.name
		local button = make("TextButton", {
			LayoutOrder = position,
			Size = UDim2.fromOffset(BUTTON_WIDTH, ROW_HEIGHT),
			BackgroundColor3 = IDLE,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = FONT,
			Text = label,
			TextSize = SIZE.small,
			TextColor3 = WHITE,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, shelf)
		button.MouseButton1Click:Connect(function()
			say(string.format("%s  -  %s", button.Text, option.note))
			option.run()
			refresh()
		end)
		button.MouseEnter:Connect(function()
			say(string.format("%s  -  %s", button.Text, option.note))
		end)
		table.insert(buttons, { button = button, option = option })
	end
end

local function build()
	local playerGui = player:WaitForChild("PlayerGui")

	-- Always there, under where a match shows its score.
	local hud = make("ScreenGui", {
		Name = "RangeStatus",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
	}, playerGui)
	Fit.attach(hud)
	statusLabel = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(900, 20),
		Text = "",
		TextSize = SIZE.small,
		TextColor3 = ACCENT,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, hud)

	gui = make("ScreenGui", {
		Name = "RangePanel",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 21,
		Enabled = false,
	}, playerGui)
	screenScale = Fit.attach(gui)
	screenScale:GetPropertyChangedSignal("Scale"):Connect(function()
		if panel then
			fit()
		end
	end)

	-- A modal button behind everything frees the mouse while the panel is
	-- open, and swallows clicks so they do not fire the weapon.
	make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Modal = true,
		Selectable = false,
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
		Text = "TEST RANGE",
		TextSize = SIZE.heading,
		TextColor3 = ACCENT,
	}, panel)
	text({
		Position = UDim2.fromOffset(24, 42),
		Size = UDim2.fromOffset(WIDTH - 48, 18),
		Text = "Nothing done here is saved or counted   -   [P] to close",
		TextSize = SIZE.small,
		TextColor3 = GREY,
	}, panel)

	for index, name in PAGES do
		local tab = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -24 - (#PAGES - index) * (BUTTON_WIDTH + GAP), 0, 12),
			Size = UDim2.fromOffset(BUTTON_WIDTH, 28),
			BackgroundColor3 = IDLE,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = FONT,
			Text = string.upper(name),
			TextSize = SIZE.small,
			TextColor3 = WHITE,
		}, panel)
		local stack = make("ScrollingFrame", {
			Position = UDim2.fromOffset(24, HEADER),
			Size = UDim2.new(1, -40, 1, -HEADER - FOOTER),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
		}, panel)
		local layout = make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, ROW_GAP) }, stack)
		pages[name] = { tab = tab, stack = stack, layout = layout, rows = 0 }
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			if name == page then
				fit()
			end
		end)
		tab.MouseButton1Click:Connect(function()
			page = name
			refresh()
		end)
	end

	noteLabel = text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -12),
		Size = UDim2.new(1, -48, 0, 34),
		Text = "",
		TextColor3 = ACCENT,
		TextWrapped = true,
	}, panel)

	for _, row in dummyRows() do
		addRow("Dummies", row)
	end
	for _, row in youRows() do
		addRow("You", row)
	end
end

-- Opens or closes the panel. Also bound to P.
function Panel.setOpen(open)
	if gui.Enabled == open then
		return
	end
	if open then
		-- Before the mouse comes free, while the crosshair still means something.
		local aimed = aimedAt()
		offered = aimed or Readout.lastTarget()
		scope = aimed or ALL
		say(if aimed then "Changing only the dummy you are aiming at" else "Changing every dummy")
	end
	gui.Enabled = open
	if open then
		refresh()
		Focus.on(panel, function()
			Panel.setOpen(false)
		end)
	else
		Focus.off(panel)
	end
end

function Panel.start()
	build()
	refresh()

	Remotes.RangeUpdate.OnClientEvent:Connect(function(update)
		range = update
		if not placesListed then
			placesListed = true
			addRow("You", placeRow())
		end
		refresh()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == TOGGLE_KEY and (not processed or gui.Enabled) then
			Panel.setOpen(not gui.Enabled)
		end
	end)
end

return Panel
