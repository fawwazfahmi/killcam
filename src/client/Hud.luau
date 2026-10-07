-- The whole HUD, built in code. The scoreboard is Roblox's own player list
-- (Tab), which shows teams plus the Kills and Deaths leaderstats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared.Config.MatchConfig)
local ShopConfig = require(Shared.Config.ShopConfig)
local Rank = require(Shared.Logic.Rank)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Flash = require(Shared.Logic.Flash)
local Score = require(Shared.Logic.Score)
local Remotes = require(Shared.Remotes)

local Hud = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(255, 70, 60)
local ACCENT = Color3.fromRGB(table.unpack(Theme.accent))
local FONT = Enum.Font[Theme.body]
local LINE_LENGTH = 9
local LINE_THICKNESS = 2

-- Why a bomb-mode round ended, as shown under the score.
local REASONS = {
	Eliminated = "team eliminated",
	TimeUp = "time ran out",
	Exploded = "bomb detonated",
	Defused = "bomb defused",
}

local gui
local crosshair = {}
local hitMarker, damageBar, scopeOverlay
local ammoLabel, weaponLabel, healthLabel, scoreLabel, statusLabel, centerLabel, primaryLabel
local objectiveLabel, progressFrame, progressFill, progressLabel
local tacticalLabel, flashFrame, rewardLabel
local rewardToken = 0
local mvpLine, rewardLine = "", "" -- the two lines of the end-of-match message
local flashToken, flashTween = 0, nil
local feed
local match = nil -- the latest MatchUpdate
local progressTween = nil

local hitToken, damageToken, respawnToken = 0, 0, 0
local feedCount = 0

local function make(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in properties do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function label(properties, parent)
	local merged = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.4,
		TextSize = 20,
		Text = "",
	}
	for key, value in properties do
		merged[key] = value
	end
	return make("TextLabel", merged, parent)
end

local function bar(properties, parent)
	local merged = { BackgroundColor3 = WHITE, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5) }
	for key, value in properties do
		merged[key] = value
	end
	return make("Frame", merged, parent)
end

local function build()
	gui = make("ScreenGui", {
		Name = "TdmHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
	}, player:WaitForChild("PlayerGui"))

	crosshair.Top = bar({ Size = UDim2.fromOffset(LINE_THICKNESS, LINE_LENGTH) }, gui)
	crosshair.Bottom = bar({ Size = UDim2.fromOffset(LINE_THICKNESS, LINE_LENGTH) }, gui)
	crosshair.Left = bar({ Size = UDim2.fromOffset(LINE_LENGTH, LINE_THICKNESS) }, gui)
	crosshair.Right = bar({ Size = UDim2.fromOffset(LINE_LENGTH, LINE_THICKNESS) }, gui)

	hitMarker = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		Text = "X",
		TextSize = 26,
		Visible = false,
	}, gui)

	damageBar = bar({ BackgroundColor3 = RED, Size = UDim2.fromOffset(90, 8), Visible = false }, gui)

	-- Scope: black bars either side of a square view, with fine cross lines.
	scopeOverlay = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, gui)
	make("Frame", { Name = "Left", BackgroundColor3 = Color3.new(), BorderSizePixel = 0 }, scopeOverlay)
	make("Frame", {
		Name = "Right",
		BackgroundColor3 = Color3.new(),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
	}, scopeOverlay)
	bar({
		BackgroundColor3 = Color3.new(),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 1, 1, 0),
	}, scopeOverlay)
	bar({
		BackgroundColor3 = Color3.new(),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
	}, scopeOverlay)

	scoreLabel = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(420, 28),
		TextSize = 22,
	}, gui)
	statusLabel = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(420, 24),
		TextSize = 18,
	}, gui)
	centerLabel = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(520, 40),
		TextSize = 28,
	}, gui)

	-- Bomb mode: what to do right now, and the plant or defuse bar.
	objectiveLabel = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(620, 22),
		TextSize = 15,
		TextColor3 = ACCENT,
	}, gui)
	progressFrame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(280, 10),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	progressFill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
	}, progressFrame)
	progressLabel = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(280, 20),
		TextSize = 15,
	}, progressFrame)

	healthLabel = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -24),
		Size = UDim2.fromOffset(200, 44),
		TextSize = 38,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, gui)
	ammoLabel = label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -24),
		Size = UDim2.fromOffset(260, 44),
		TextSize = 38,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, gui)
	weaponLabel = label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -70),
		Size = UDim2.fromOffset(260, 22),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, gui)
	tacticalLabel = label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -96),
		Size = UDim2.fromOffset(320, 22),
		TextSize = 15,
		TextColor3 = ACCENT,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, gui)
	primaryLabel = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(420, 20),
		TextSize = 15,
		TextTransparency = 0.3,
		Text = "[B] Loadout     [G] Drop",
	}, gui)

	-- What the match just paid, shown for a few seconds when it ends.
	rewardLabel = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(620, 56),
		TextSize = 18,
		TextColor3 = ACCENT,
	}, gui)

	-- A flashbang whites the whole screen out, then fades.
	flashFrame = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
	}, gui)

	feed = make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 110),
		Size = UDim2.fromOffset(360, 200),
	}, gui)
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 2),
	}, feed)
end

-- Gap between the crosshair lines shows the current spread cone.
function Hud.setCrosshair(spreadDegrees, visible)
	local camera = workspace.CurrentCamera
	local halfHeight = camera.ViewportSize.Y / 2
	local gap = math.tan(math.rad(spreadDegrees)) / math.tan(math.rad(camera.FieldOfView / 2)) * halfHeight
	gap = math.clamp(gap, 3, 220) + LINE_LENGTH / 2

	crosshair.Top.Position = UDim2.new(0.5, 0, 0.5, -gap)
	crosshair.Bottom.Position = UDim2.new(0.5, 0, 0.5, gap)
	crosshair.Left.Position = UDim2.new(0.5, -gap, 0.5, 0)
	crosshair.Right.Position = UDim2.new(0.5, gap, 0.5, 0)
	for _, line in crosshair do
		line.Visible = visible
	end
end

function Hud.setWeapon(displayName, ammoText)
	weaponLabel.Text = displayName
	ammoLabel.Text = ammoText
end

-- The tactical item and how many uses are left.
function Hud.setTactical(text)
	tacticalLabel.Text = text
end

-- A flashbang went off at `position`. Looking straight at it whites the
-- screen out and holds it; turned away, it is a brief partial wash that eases
-- straight back out (see Shared.Logic.Flash).
local function onFlash(position, seconds)
	local camera = workspace.CurrentCamera
	local toFlash = position - camera.CFrame.Position
	local facing = if toFlash.Magnitude > 0.1 then toFlash.Unit:Dot(camera.CFrame.LookVector) else 1
	local effect = Flash.effect(WeaponConfig.Weapons.Flash, seconds, facing)
	if effect.duration < 0.1 then
		return
	end

	flashToken += 1
	local token = flashToken
	if flashTween then
		flashTween:Cancel()
	end
	-- A weaker flash never clears a stronger one that is still on screen.
	flashFrame.BackgroundTransparency = math.min(flashFrame.BackgroundTransparency, 1 - effect.opacity)

	task.delay(effect.hold, function()
		if flashToken ~= token then
			return -- a newer flash took over
		end
		local fade = TweenInfo.new(effect.duration - effect.hold, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		flashTween = TweenService:Create(flashFrame, fade, { BackgroundTransparency = 1 })
		flashTween:Play()
	end)
end

function Hud.setScoped(scoped)
	if scoped then
		local size = workspace.CurrentCamera.ViewportSize
		local side = math.max((size.X - size.Y) / 2, 0)
		scopeOverlay.Left.Size = UDim2.new(0, side, 1, 0)
		scopeOverlay.Right.Size = UDim2.new(0, side, 1, 0)
	end
	scopeOverlay.Visible = scoped
end

function Hud.showHit(headshot, killed)
	hitToken += 1
	local token = hitToken
	hitMarker.TextColor3 = (headshot or killed) and RED or WHITE
	hitMarker.TextSize = killed and 34 or 26
	hitMarker.Visible = true
	task.delay(0.12, function()
		if hitToken == token then
			hitMarker.Visible = false
		end
	end)
end

-- Points a red bar toward whoever hurt you.
function Hud.showDamageFrom(position)
	damageToken += 1
	local token = damageToken
	local angle = 0
	if position then
		local relative = workspace.CurrentCamera.CFrame:PointToObjectSpace(position)
		angle = math.atan2(relative.X, -relative.Z)
	end
	damageBar.Position = UDim2.new(0.5, math.sin(angle) * 130, 0.5, -math.cos(angle) * 130)
	damageBar.Rotation = math.deg(angle)
	damageBar.Visible = true
	task.delay(0.7, function()
		if damageToken == token then
			damageBar.Visible = false
		end
	end)
end

function Hud.addKill(killerName, victimName, weaponName, headshot)
	local text
	if killerName == victimName then
		text = string.format("%s  [%s]", victimName, weaponName)
	else
		text = string.format("%s  [%s%s]  %s", killerName, weaponName, headshot and " HS" or "", victimName)
	end
	Hud.addFeedLine(text)
end

-- One line in the feed at the top right, gone after a few seconds.
function Hud.addFeedLine(text)
	feedCount += 1
	local entry = label({
		Size = UDim2.fromOffset(360, 20),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = text,
		LayoutOrder = feedCount,
	}, feed)
	task.delay(5, function()
		entry:Destroy()
	end)
end

-- Search and Destroy: one line telling the player what to do. Empty to clear it.
function Hud.setObjective(text)
	objectiveLabel.Text = text
end

-- Search and Destroy: a bar that fills over `seconds`, labelled `text`. Nil hides it.
function Hud.setProgress(text, seconds)
	if progressTween then
		progressTween:Cancel()
		progressTween = nil
	end
	progressFrame.Visible = text ~= nil
	if text then
		progressLabel.Text = text
		progressFill.Size = UDim2.fromScale(0, 1)
		progressTween = TweenService:Create(progressFill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(1, 1),
		})
		progressTween:Play()
	end
end

-- Before a match starts it is a free-for-all while players arrive.
local function warmupStatus(snapshot)
	return string.format("Warm-up  -  free-for-all until everyone is in   %d / %d", snapshot.present or 0, snapshot.expected or 0)
end

local function bombStatus(snapshot)
	if snapshot.phase == "Waiting" then
		return warmupStatus(snapshot)
	elseif snapshot.phase == "Prep" then
		return string.format("Round %d  -  %s attack", snapshot.round, tostring(snapshot.attackers))
	elseif snapshot.phase == "Planted" then
		return "Bomb planted"
	elseif snapshot.phase == "RoundOver" then
		return string.format("%s take the round  -  %s", tostring(snapshot.roundWinner), REASONS[snapshot.reason] or "")
	elseif snapshot.phase == "MatchOver" then
		return string.format("%s win the match", tostring(snapshot.winner))
	end
	return ""
end

local function setMatch(snapshot)
	match = snapshot
	if snapshot.mode == "RANGE" then
		-- The test range keeps no score and has no clock.
		scoreLabel.Text = "TEST RANGE"
		statusLabel.Text = ""
		return
	end
	local minutes = math.floor(snapshot.timeLeft / 60)
	local seconds = snapshot.timeLeft % 60
	if snapshot.mode == "FFA" then
		-- Everyone is their own side: show yours against the best of the rest.
		local best, bestName = 0, nil
		for name, score in snapshot.scores do
			if name ~= player.Name and score >= best then
				best, bestName = score, name
			end
		end
		scoreLabel.Text = string.format(
			"YOU %d    %d:%02d    %d %s",
			snapshot.scores[player.Name] or 0,
			minutes,
			seconds,
			best,
			string.upper(bestName or "-")
		)
	else
		local teams = MatchConfig.teams
		scoreLabel.Text = string.format(
			"%s %d    %d:%02d    %d %s",
			string.upper(teams[1]),
			snapshot.scores[teams[1]] or 0,
			minutes,
			seconds,
			snapshot.scores[teams[2]] or 0,
			string.upper(teams[2])
		)
	end

	if snapshot.mode == "SND" then
		statusLabel.Text = bombStatus(snapshot)
	elseif snapshot.phase == "Waiting" then
		statusLabel.Text = warmupStatus(snapshot)
	elseif snapshot.phase == "Ended" then
		statusLabel.Text = snapshot.winner == "Draw" and "Draw" or string.format("%s wins", tostring(snapshot.winner))
	else
		statusLabel.Text = ""
	end
end

local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	respawnToken += 1
	centerLabel.Text = ""
	healthLabel.Text = tostring(math.ceil(humanoid.Health))

	humanoid.HealthChanged:Connect(function(health)
		healthLabel.Text = tostring(math.max(math.ceil(health), 0))
	end)

	humanoid.Died:Once(function()
		respawnToken += 1
		local token = respawnToken
		if match and match.mode == "SND" and match.phase ~= "Waiting" then
			centerLabel.Text = "Eliminated  -  back next round"
			return
		end
		-- Otherwise they are coming back: SpectateController shows how soon.
		if respawnToken == token then
			centerLabel.Text = ""
		end
	end)
end

function Hud.start()
	build()
	Hud.setCrosshair(1, false)

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	Remotes.MatchUpdate.OnClientEvent:Connect(setMatch)
	Remotes.KillFeed.OnClientEvent:Connect(Hud.addKill)
	Remotes.TierUp.OnClientEvent:Connect(function(class, standing)
		Hud.addFeedLine(string.format("%s  [%s]", string.upper(class), string.upper(standing)))
	end)
	Remotes.Revived.OnClientEvent:Connect(function(name)
		Hud.addFeedLine(string.format("%s  [REVIVED]", name))
	end)
	Remotes.Flash.OnClientEvent:Connect(onFlash)
	-- The MVP and the player's own payout arrive separately at the end of a
	-- match; they are shown together for a few seconds.
	local function showResult()
		rewardToken += 1
		local token = rewardToken
		rewardLabel.Text = if mvpLine ~= "" and rewardLine ~= "" then mvpLine .. "\n" .. rewardLine else mvpLine .. rewardLine
		task.delay(8, function()
			if rewardToken == token then
				mvpLine, rewardLine = "", ""
				rewardLabel.Text = ""
			end
		end)
	end
	Remotes.Mvp.OnClientEvent:Connect(function(result)
		mvpLine = string.format("MVP   %s   -   %s", string.upper(result.name), Score.summary(result))
		showResult()
	end)
	Remotes.ProfileUpdate.OnClientEvent:Connect(function(profile)
		if profile.earned then
			rewardLine = string.format("+%d points   -   %s", profile.earned, Rank.of(ShopConfig.ranks, profile.level).title)
			showResult()
		end
	end)
	Remotes.HitConfirm.OnClientEvent:Connect(Hud.showHit)
	Remotes.Damaged.OnClientEvent:Connect(function(_amount, position)
		Hud.showDamageFrom(position)
	end)

	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
end

return Hud
