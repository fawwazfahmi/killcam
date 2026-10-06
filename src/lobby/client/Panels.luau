-- The lobby's own screens: the Play panel (pick a mode and queue), the Profile
-- panel (rank, points, rentals and standing with each class of weapon), the
-- Squad panel (team up with players in this penthouse), and the lines that
-- stay on screen while the player walks about: their queue and their squad.
-- The loadout and the shop are their own screens (LoadoutMenu, ShopMenu).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local ProgressConfig = require(Shared.Config.ProgressConfig)
local ShopConfig = require(Shared.Config.ShopConfig)
local Theme = require(Shared.Config.Theme)
local ArmorConfig = require(Shared.Config.ArmorConfig)
local TacticalConfig = require(Shared.Config.TacticalConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Catalog = require(Shared.Logic.Catalog)
local Prestige = require(Shared.Logic.Prestige)
local Queue = require(Shared.Logic.Queue)
local Rank = require(Shared.Logic.Rank)
local Remotes = require(Shared.Remotes)

local Panels = {}

local DISPLAY = Enum.Font[Theme.display]
local FONT = Enum.Font[Theme.body]
local SIZE = Theme.size
local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local INK = Color3.fromRGB(table.unpack(Theme.ink))
local PANEL = Color3.fromRGB(24, 26, 32)
local IDLE = Color3.fromRGB(44, 48, 58)
local WHITE = Color3.new(1, 1, 1)

local CATALOG = Catalog.fields(WeaponConfig, TacticalConfig, ArmorConfig)

local player = Players.LocalPlayer
local gui
local playPanel, profilePanel, squadPanel, invitePanel
local queueLine, playStatus, profileText
local squadLine, squadList, lobbyList, squadStatus, leaveButton, inviteText
local modeButtons = {}
local MUTED = Color3.fromRGB(table.unpack(Theme.muted))
local SUNKEN = Color3.fromRGB(table.unpack(Theme.sunken))

local queue = { status = "None" } -- the latest QueueUpdate
local profile = nil -- the latest ProfileUpdate
local squad = { members = {}, invites = {}, leading = true } -- the latest SquadUpdate
local invitedBy = nil -- the name on the invitation being shown
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
		TextColor3 = WHITE,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in properties do
		merged[key] = value
	end
	return make("TextLabel", merged, parent)
end

local function button(properties, parent, onClick)
	local merged = {
		BackgroundColor3 = IDLE,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = FONT,
		TextColor3 = WHITE,
		TextSize = 15,
	}
	for key, value in properties do
		merged[key] = value
	end
	local instance = make("TextButton", merged, parent)
	instance.MouseButton1Click:Connect(onClick)
	return instance
end

-- A centred panel over a modal backdrop, which frees the mouse while it is open.
local function panel(width, height, title)
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
	make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Modal = true,
	}, root)
	local body = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
	}, root)
	text({
		Position = UDim2.fromOffset(24, 16),
		Size = UDim2.fromOffset(width - 160, 26),
		Font = DISPLAY,
		Text = title,
		TextSize = SIZE.heading,
		TextColor3 = ACCENT,
	}, body)
	button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 16),
		Size = UDim2.fromOffset(100, 28),
		Text = "CLOSE",
	}, body, function()
		root.Visible = false
	end)
	return root, body
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

-- One line saying where the player's queue stands. Empty when not queued.
local function queueText()
	if queue.status == "Queued" then
		local title = LobbyConfig.modes[queue.mode].title
		return string.format("IN QUEUE   %s   %d / %d", string.upper(title), queue.waiting, queue.needed)
	elseif queue.status == "Launching" or queue.status == "Failed" then
		return string.upper(queue.message or "")
	end
	return ""
end

local function refreshQueue()
	local line = queueText()
	queueLine.Text = line
	playStatus.Text = if line ~= "" then line else "Pick a mode. You stay in the lobby until a match is found."
	for mode, entry in modeButtons do
		local queued = queue.status == "Queued" and queue.mode == mode
		entry.BackgroundColor3 = if queued then ACCENT else IDLE
		entry.TextColor3 = if queued then INK else WHITE
	end
end

local function refreshProfile()
	if not profile then
		profileText.Text = "Loading your profile..."
		return
	end
	local top = ShopConfig.levels.max
	local lines = {
		string.upper(Rank.of(ShopConfig.ranks, profile.level).title),
		string.format("Level %d of %d", profile.level, top),
		if profile.level >= top
			then "The highest rank there is"
			else string.format("Experience  %d / %d  to the next grade", profile.xp, profile.xpNeeded),
		string.format("%d points", profile.points),
		"",
		"WEAPONS",
	}
	-- Standing with each class of weapon, from kills and assists with it.
	local weapons = ProgressConfig.weapons
	for _, class in weapons.classes do
		local record = profile.weapons and profile.weapons[class]
		local standing = Prestige.standing(weapons.prestiges, record and record.xp or 0, record and record.peak)
		local progress = if standing.needed then string.format("%d / %d", standing.into, standing.needed) else "complete"
		table.insert(lines, string.format("%s   %s   %s", weapons.titles[class], string.upper(standing.title), progress))
	end
	table.insert(lines, "")
	table.insert(lines, "RENTALS")
	local now = os.time() + clockOffset
	local any = false
	for name, rental in profile.rentals do
		any = true
		local entry, item = Catalog.find(CATALOG, name)
		local byUse = entry ~= nil and ShopConfig.timing[entry.field] == "use"
		local left = if rental.expiresAt then rental.expiresAt - now else rental.seconds
		local suffix = if byUse then "of use" elseif rental.expiresAt then "left" else "unused"
		local title = if item then string.format("%s  (%s)", item.displayName, entry.title) else name
		table.insert(lines, string.format("%s   %s %s", title, duration(math.max(left, 0)), suffix))
	end
	if not any then
		table.insert(lines, "None. Rent weapons and armour at the Armoury.")
	end
	profileText.Text = table.concat(lines, "\n")
end

local function buildPlay()
	local width = 620
	local root, body = panel(width, 100 + #LobbyConfig.order * 70 + 80, "FIND A MATCH")
	playPanel = root

	for index, mode in LobbyConfig.order do
		local rules = LobbyConfig.modes[mode]
		local top = 64 + (index - 1) * 70
		modeButtons[mode] = button({
			Position = UDim2.fromOffset(24, top),
			Size = UDim2.fromOffset(width - 48, 58),
			TextSize = 13,
			Text = string.format(
				"%s\n%s   -   %d to %d players",
				string.upper(rules.title),
				rules.note,
				rules.min,
				Queue.capacity(rules)
			),
		}, body, function()
			Remotes.QueueJoin:FireServer(mode)
		end)
	end

	local bottom = 64 + #LobbyConfig.order * 70
	playStatus = text({
		Position = UDim2.fromOffset(24, bottom + 6),
		Size = UDim2.fromOffset(width - 48 - 150, 44),
		Text = "",
		TextSize = 15,
		TextColor3 = ACCENT,
		TextWrapped = true,
	}, body)
	button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, bottom + 10),
		Size = UDim2.fromOffset(130, 34),
		Text = "LEAVE QUEUE",
	}, body, function()
		Remotes.QueueLeave:FireServer()
	end)
end

local function buildProfile()
	local root, body = panel(520, 600, "PROFILE")
	profilePanel = root
	text({
		Position = UDim2.fromOffset(24, 60),
		Size = UDim2.fromOffset(472, 16),
		Text = string.upper(player.DisplayName),
		TextSize = 16,
	}, body)
	profileText = text({
		Position = UDim2.fromOffset(24, 90),
		Size = UDim2.fromOffset(472, 490),
		Text = "",
		TextSize = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}, body)
end

-- Squad ---------------------------------------------------------------------

local function clearRows(list)
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function row(list, order, name, tag, action, onClick)
	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = SUNKEN,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, list)
	text({
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -130, 1, 0),
		Text = name,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, frame)
	if action then
		button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(96, 28),
			BackgroundColor3 = ACCENT,
			TextColor3 = INK,
			Text = action,
			TextSize = 13,
		}, frame, onClick)
	elseif tag then
		text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.new(0, 100, 1, 0),
			Text = tag,
			TextSize = 13,
			TextColor3 = ACCENT,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, frame)
	end
end

local function refreshSquad()
	local size = LobbyConfig.squad.size
	local inSquad = {}
	local names = {}
	clearRows(squadList)
	for index, member in squad.members do
		inSquad[member.name] = true
		table.insert(names, string.upper(member.displayName))
		row(squadList, index, member.displayName, if member.leader then "LEADER" else nil)
	end

	-- Everybody else in this penthouse, each with a way to ask them in.
	clearRows(lobbyList)
	local full = #squad.members >= size
	local order = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and not inSquad[other.Name] then
			order += 1
			local canInvite = squad.leading and not full
			row(lobbyList, order, other.DisplayName, nil, if canInvite then "INVITE" else nil, function()
				Remotes.SquadInvite:FireServer(other.Name)
				squadStatus.Text = string.format("Invited %s. They have %d seconds to answer.", other.DisplayName, LobbyConfig.squad.inviteLasts)
			end)
		end
	end

	leaveButton.Visible = #squad.members > 1
	if #squad.members <= 1 then
		squadStatus.Text = string.format("Invite up to %d players. A squad queues together and is never split up.", size - 1)
	elseif not squad.leading then
		squadStatus.Text = "Your squad leader invites players and picks the mode."
	elseif full then
		squadStatus.Text = "Your squad is full."
	end
	squadLine.Text = if #squad.members > 1 then "SQUAD   " .. table.concat(names, "  -  ") else ""

	-- An invitation waits on top of everything until it is answered.
	local invite = squad.invites[1]
	invitedBy = invite and invite.name
	invitePanel.Visible = invite ~= nil
	if invite then
		inviteText.Text = string.format("%s has invited you to their squad.", invite.displayName)
	end
end

local function buildSquad()
	local width = 680
	local root, body = panel(width, 470, "SQUAD")
	squadPanel = root
	local half = (width - 48 - 16) / 2

	local function column(title, x)
		text({
			Position = UDim2.fromOffset(x, 60),
			Size = UDim2.fromOffset(half, 20),
			Text = title,
			TextSize = 13,
			TextColor3 = MUTED,
		}, body)
		local list = make("ScrollingFrame", {
			Position = UDim2.fromOffset(x, 86),
			Size = UDim2.fromOffset(half, 290),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, body)
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
		return list
	end
	squadList = column(string.format("YOUR SQUAD  (UP TO %d)", LobbyConfig.squad.size), 24)
	lobbyList = column("IN THIS PENTHOUSE", 24 + half + 16)

	squadStatus = text({
		Position = UDim2.fromOffset(24, 392),
		Size = UDim2.fromOffset(width - 48 - 160, 54),
		Text = "",
		TextColor3 = ACCENT,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, body)
	leaveButton = button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 396),
		Size = UDim2.fromOffset(140, 34),
		Text = "LEAVE SQUAD",
	}, body, function()
		Remotes.SquadLeave:FireServer()
	end)

	-- The invitation: its own small panel, over whatever else is open.
	local inviteRoot, inviteBody = panel(460, 190, "SQUAD INVITE")
	invitePanel = inviteRoot
	inviteRoot.ZIndex = 5
	inviteText = text({
		Position = UDim2.fromOffset(24, 64),
		Size = UDim2.fromOffset(412, 44),
		Text = "",
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, inviteBody)
	local function answer(accept)
		if invitedBy then
			Remotes.SquadAnswer:FireServer(invitedBy, accept)
		end
		invitePanel.Visible = false
	end
	button({
		Position = UDim2.fromOffset(24, 126),
		Size = UDim2.fromOffset(200, 40),
		BackgroundColor3 = ACCENT,
		TextColor3 = INK,
		Text = "JOIN",
	}, inviteBody, function()
		answer(true)
	end)
	button({
		Position = UDim2.fromOffset(236, 126),
		Size = UDim2.fromOffset(200, 40),
		Text = "NO THANKS",
	}, inviteBody, function()
		answer(false)
	end)
end

local function only(shown)
	for _, each in { playPanel, profilePanel, squadPanel } do
		each.Visible = each == shown
	end
end

function Panels.openPlay()
	only(playPanel)
end

function Panels.openProfile()
	refreshProfile() -- time left has moved on since it was last open
	only(profilePanel)
end

function Panels.openSquad()
	refreshSquad() -- people have come and gone since it was last open
	only(squadPanel)
end

function Panels.start()
	gui = make("ScreenGui", {
		Name = "Lobby",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
	}, player:WaitForChild("PlayerGui"))

	queueLine = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.fromOffset(700, 24),
		Text = "",
		TextSize = 16,
		TextColor3 = ACCENT,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, gui)
	text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(700, 20),
		Text = "Walk to a station to use it     [B] Loadout",
		TextSize = 13,
		TextTransparency = 0.3,
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, gui)

	squadLine = text({
		Position = UDim2.fromOffset(20, 48),
		Size = UDim2.fromOffset(700, 22),
		Text = "",
		TextSize = 13,
		TextColor3 = ACCENT,
		TextStrokeTransparency = 0.4,
	}, gui)

	buildPlay()
	buildProfile()
	buildSquad()
	refreshQueue()
	refreshProfile()
	refreshSquad()

	Remotes.SquadUpdate.OnClientEvent:Connect(function(update)
		squad = update
		refreshSquad()
	end)
	-- The list of who can be invited follows who is here.
	Players.PlayerAdded:Connect(refreshSquad)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshSquad)
	end)

	Remotes.QueueUpdate.OnClientEvent:Connect(function(update)
		queue = update
		refreshQueue()
	end)
	Remotes.ProfileUpdate.OnClientEvent:Connect(function(update)
		profile = update
		clockOffset = update.now - os.time()
		refreshProfile()
	end)
end

return Panels
