-- The test range's damage readout. Every hit landed on a dummy, and every hit
-- taken, is listed down the left of the screen in full: the weapon, where it
-- landed, from how far, what it does before armour and what it did after, and
-- the health left. Under the list are the totals for the run of hits in
-- progress, and a number floats up off each hit where it landed. The sums are
-- Shared.Logic.Readout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared.Config.MatchConfig)
local RangeConfig = require(Shared.Config.RangeConfig)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Logic = require(Shared.Logic.Readout)
local Remotes = require(Shared.Remotes)

local Fit = require(script.Parent.Parent.Fit)

local Readout = {}

local RULES = RangeConfig.readout
local YOU = "you" -- the run that damage taken is counted in

local FONT = Enum.Font[Theme.body]
local BOLD = Enum.Font[Theme.bodyBold]
local SIZE = Theme.size

local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local PAPER = Color3.fromRGB(table.unpack(Theme.paper))
local MUTED = Color3.fromRGB(table.unpack(Theme.muted))
local PANEL = Color3.fromRGB(table.unpack(Theme.panel))
local DANGER = Color3.fromRGB(table.unpack(Theme.danger))

local ROW = 20
local PAD = 10
-- The columns of the list: what is at the head of each, and how wide it is.
local COLUMNS = {
	{ key = "weapon", head = "WEAPON", width = 118 },
	{ key = "zone", head = "WHERE", width = 78 },
	{ key = "distance", head = "STUDS", width = 52 },
	{ key = "damage", head = "DAMAGE", width = 104 },
	{ key = "left", head = "LEFT", width = 64 },
}
local WIDTH = PAD * 2
for _, column in COLUMNS do
	WIDTH += column.width
end

local NUMBER_RISE = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local player = Players.LocalPlayer
local state = Logic.new()
local gui, card, totalLine, verdictLine
local rows = {} -- one per line of the list: { [key] = TextLabel }

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
		TextSize = SIZE.small,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}
	for key, value in properties do
		merged[key] = value
	end
	return make("TextLabel", merged, parent)
end

-- A whole number as one, anything else to one place: armour leaves fractions.
local function number(value)
	return if value == math.floor(value) then string.format("%d", value) else string.format("%.1f", value)
end

local function weaponName(name)
	local config = WeaponConfig.Weapons[name]
	return string.upper(if config then config.displayName else name)
end

-- What each column says for a hit.
local function cells(hit)
	local left
	if hit.shielded then
		left = "SHIELDED" -- spawn protection or god mode stopped it
	elseif hit.lethal then
		left = "KILL"
	else
		left = number(math.ceil(hit.left)) .. " HP"
	end
	return {
		weapon = weaponName(hit.weapon),
		zone = string.upper(hit.zone),
		distance = if hit.distance > 0 then string.format("%d", math.floor(hit.distance + 0.5)) else "-",
		-- Before armour, then after it, where the two differ.
		damage = if hit.raw ~= hit.amount then number(hit.raw) .. "  >  " .. number(hit.amount) else number(hit.amount),
		left = left,
	}
end

local function redraw()
	for index, row in rows do
		local hit = state.lines[index]
		local shown = hit and cells(hit)
		for _, column in COLUMNS do
			local label = row[column.key]
			label.Text = if shown then shown[column.key] else ""
			-- What was done to you is in red; a kill stands out either way.
			label.TextColor3 = if hit and hit.taken then DANGER elseif hit and hit.lethal then ACCENT else PAPER
		end
	end

	local run = state.run
	if not run then
		totalLine.Text = "Shoot a dummy"
		verdictLine.Text = ""
		return
	end
	local totals = Logic.totals(run)
	local line = string.format("%s     %d %s     %s DAMAGE", run.label, totals.hits, if totals.hits == 1 then "HIT" else "HITS", number(totals.damage))
	if totals.perSecond then
		line ..= string.format("     %d A SECOND", math.floor(totals.perSecond + 0.5))
	end
	totalLine.Text = line

	if totals.killHits then
		verdictLine.Text = string.format("KILLED IN %d %s,  %.2f S", totals.killHits, if totals.killHits == 1 then "HIT" else "HITS", totals.killTime)
		return
	end
	-- What it would take if every hit were like the last one.
	local last = state.lines[#state.lines]
	local config = WeaponConfig.Weapons[last.weapon]
	local interval = config and (config.fireInterval or config.swingInterval)
	local paper = interval and Logic.onPaper(last.amount, interval, MatchConfig.maxHealth)
	verdictLine.Text = if paper
		then string.format("ON PAPER: %d LIKE THAT TO KILL,  %.2f S", paper.hits, paper.seconds)
		else ""
end

-- The damage, rising from where it landed and fading.
local function float(hit)
	local anchor = make("Attachment", { WorldPosition = hit.at }, workspace.Terrain)
	local board = make("BillboardGui", {
		Adornee = anchor,
		Size = UDim2.fromOffset(120, 34),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
	}, player.PlayerGui) -- beside the readout, not inside it: one screen cannot hold another
	local label = text({
		Size = UDim2.fromScale(1, 1),
		Font = BOLD,
		Text = number(hit.amount),
		TextSize = if hit.lethal then 26 else SIZE.heading,
		TextColor3 = if hit.lethal or hit.zone == "Head" then DANGER else ACCENT,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, board)

	TweenService:Create(board, NUMBER_RISE, { StudsOffset = Vector3.new(0, 2.5, 0) }):Play()
	local fade = TweenService:Create(label, NUMBER_RISE, { TextTransparency = 1, TextStrokeTransparency = 1 })
	fade.Completed:Once(function()
		board:Destroy()
		anchor:Destroy()
	end)
	fade:Play()
end

local function onHit(hit)
	hit.target = if hit.taken then YOU else hit.target
	local run = Logic.add(RULES, state, hit, os.clock())
	run.label = if hit.taken then "TAKEN" else hit.label
	redraw()
	if not hit.taken and typeof(hit.at) == "Vector3" then
		float(hit)
	end
end

local function build()
	gui = make("ScreenGui", {
		Name = "RangeReadout",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
	}, player:WaitForChild("PlayerGui"))
	Fit.attach(gui)

	local height = PAD + ROW * (RULES.lines + 1) + 8 + ROW * 2 + PAD
	card = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 24, 0.46, 0),
		Size = UDim2.fromOffset(WIDTH, height),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, gui)
	make("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = ACCENT, BorderSizePixel = 0 }, card)

	local x = PAD
	for _, column in COLUMNS do
		text({
			Position = UDim2.fromOffset(x, PAD),
			Size = UDim2.fromOffset(column.width, ROW),
			Font = BOLD,
			Text = column.head,
			TextColor3 = MUTED,
		}, card)
		x += column.width
	end
	for index = 1, RULES.lines do
		local row = {}
		x = PAD
		for _, column in COLUMNS do
			row[column.key] = text({
				Position = UDim2.fromOffset(x, PAD + ROW * index),
				Size = UDim2.fromOffset(column.width, ROW),
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, card)
			x += column.width
		end
		rows[index] = row
	end

	local below = PAD + ROW * (RULES.lines + 1) + 8
	make("Frame", {
		Position = UDim2.fromOffset(PAD, below - 5),
		Size = UDim2.new(1, -PAD * 2, 0, 1),
		BackgroundColor3 = MUTED,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
	}, card)
	totalLine = text({
		Position = UDim2.fromOffset(PAD, below),
		Size = UDim2.new(1, -PAD * 2, 0, ROW),
		Font = BOLD,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)
	verdictLine = text({
		Position = UDim2.fromOffset(PAD, below + ROW),
		Size = UDim2.new(1, -PAD * 2, 0, ROW),
		Font = BOLD,
		TextColor3 = ACCENT,
	}, card)
end

-- Empties the list and the totals.
function Readout.clear()
	Logic.clear(state)
	redraw()
end

-- The dummy last hit, by its id, or nil: the panel offers it as the one to change.
function Readout.lastTarget()
	for index = #state.lines, 1, -1 do
		if not state.lines[index].taken then
			return state.lines[index].target
		end
	end
	return nil
end

function Readout.start()
	build()
	redraw()
	Remotes.RangeHit.OnClientEvent:Connect(onHit)
end

return Readout
