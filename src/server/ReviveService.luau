-- Revives for Robux (rules in Shared.Logic.Revive, numbers in MatchConfig.revive).
--
-- A player who dies while a match is being fought is offered a revive for a
-- few seconds. Taking it uses one they already hold, or opens Roblox's own
-- purchase window for one. They come back where they fell if another player
-- killed them, and at their spawn otherwise.
--
-- Money is involved, so a purchase always becomes a revive in the player's
-- profile first, and only then is it spent: one paid for a moment too late
-- (the round ended, they had already respawned) is kept for next time, never
-- lost. The purchase itself is handled by PurchaseService.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared.Config.MatchConfig)
local Economy = require(Shared.Logic.Economy)
local Revive = require(Shared.Logic.Revive)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
local MatchService = require(script.Parent.MatchService)
local ProfileStore = require(script.Parent.ProfileStore)
local PurchaseService = require(script.Parent.PurchaseService)
local SpawnService = require(script.Parent.SpawnService)
local StatsService = require(script.Parent.StatsService)

local ReviveService = {}

local CONFIG = MatchConfig.revive
local OFFER_DELAY = 0.25 -- seconds after a death before offering, in case that death ended the round
local RISE = 3 -- studs above where they fell that a revived player appears

local offers = {} -- [player] = { position = Vector3?, side = string?, attacker = Player?, deadline = number }
local used = {} -- [player] = revives taken this round or match
local killers = {} -- [player] = { side = string?, attacker = Player } for the life that just ended, if a player ended it
local price = nil -- Robux, once Roblox has told us

local function rules()
	return Revive.rules(CONFIG, MatchService.mode())
end

local function withdraw(player)
	if offers[player] then
		offers[player] = nil
		SpawnService.hold(player, 0)
		Remotes.ReviveOffer:FireClient(player, nil)
	end
end

local function withdrawAll()
	for player in offers do
		withdraw(player)
	end
end

local function send(player, offer, buying)
	local profile = ProfileStore.get(player)
	Remotes.ReviveOffer:FireClient(player, {
		seconds = offer.deadline - os.clock(),
		held = if profile then profile.revives else 0,
		price = price,
		undo = rules().undo,
		buying = buying == true, -- the purchase window is open
	})
end

local function bringBack(player, offer)
	local active = rules()
	offers[player] = nil
	used[player] = (used[player] or 0) + 1

	local undo = Revive.undo(active, offer.side ~= nil)
	if undo.deaths ~= 0 then
		StatsService.record(player, "deaths", undo.deaths)
	end
	if undo.points ~= 0 then
		MatchService.removeKill(offer.side)
	end
	-- The kill comes off whoever made it too, if they are still here.
	if undo.kills ~= 0 and offer.attacker and offer.attacker.Parent == Players then
		StatsService.record(offer.attacker, "kills", undo.kills)
	end

	Remotes.ReviveOffer:FireClient(player, nil)
	Remotes.Revived:FireAllClients(player.Name)
	local at = if offer.position then CFrame.new(offer.position + Vector3.new(0, RISE, 0)) else nil
	SpawnService.spawn(player, true, at)
end

-- Spends a revive the player holds, if their offer still stands.
local function tryRevive(player)
	local offer = offers[player]
	local profile = ProfileStore.get(player)
	if not offer or not profile or not rules() or not MatchService.inPlay() then
		return false
	end
	if not Economy.spend(profile, "revives") then
		return false
	end
	ProfileStore.push(player)
	bringBack(player, offer)
	return true
end

local function onDied(player, position)
	local killer = killers[player]
	killers[player] = nil
	local active = rules()
	if not active or not MatchService.inPlay() or not Revive.available(active, used[player] or 0) then
		return
	end

	task.delay(OFFER_DELAY, function()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local alive = humanoid ~= nil and humanoid.Health > 0
		if player.Parent ~= Players or alive or offers[player] or not MatchService.inPlay() then
			return
		end
		-- Where the dead respawn by themselves, the offer cannot outlast the wait
		-- for that; pressing F holds the respawn back while they buy.
		local window = CONFIG.window
		if MatchService.respawns() then
			window = math.min(window, MatchConfig.respawnDelay - OFFER_DELAY)
		end
		local offer = {
			position = if killer then position else nil,
			side = killer and killer.side,
			attacker = killer and killer.attacker,
			deadline = os.clock() + window,
		}
		offers[player] = offer
		send(player, offer)

		-- The deadline moves if they open the purchase window, so look again
		-- rather than trusting the first one.
		while offers[player] == offer and os.clock() < offer.deadline do
			task.wait(0.25)
		end
		if offers[player] == offer then
			withdraw(player)
		end
	end)
end

local function onRequest(player)
	local offer = offers[player]
	if not offer or offer.buying or not CombatService.allow(player, "ReviveRequest", 2) then
		return
	end
	if tryRevive(player) then
		return
	end
	-- Nothing held: ask Roblox to sell one, and wait for the answer.
	offer.buying = true
	offer.deadline = os.clock() + CONFIG.promptTime
	SpawnService.hold(player, CONFIG.promptTime)
	send(player, offer, true)
	MarketplaceService:PromptProductPurchase(player, CONFIG.productId)
end

function ReviveService.init()
	if CONFIG.productId == 0 then
		return -- switched off: nothing is offered and nothing is sold
	end

	PurchaseService.sell(CONFIG.productId, "revives", function(player)
		if not tryRevive(player) then
			ProfileStore.push(player) -- kept for next time
		end
	end)
	task.spawn(function()
		local ok, info =
			pcall(MarketplaceService.GetProductInfo, MarketplaceService, CONFIG.productId, Enum.InfoType.Product)
		if ok and info then
			price = info.PriceInRobux
		else
			warn(`ReviveService: could not read product {CONFIG.productId}: {info}`)
		end
	end)

	CombatService.Killed:Connect(function(victim, attacker, side)
		if attacker ~= victim then
			killers[victim] = { side = side, attacker = attacker }
		end
	end)
	SpawnService.Died:Connect(onDied)
	SpawnService.Spawned:Connect(function(player)
		killers[player] = nil
		withdraw(player) -- they are back some other way
	end)
	Remotes.ReviveRequest.OnServerEvent:Connect(onRequest)

	-- They closed the purchase window without buying: let them respawn.
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, bought)
		local player = Players:GetPlayerByUserId(userId)
		if player and productId == CONFIG.productId and not bought then
			withdraw(player)
		end
	end)

	MatchService.Changed:Connect(function(event)
		local active = rules()
		if active and Revive.resetsOn(active, event) then
			table.clear(used)
		end
		-- An offer only stands while the fight it belongs to is still going.
		if not MatchService.inPlay() then
			withdrawAll()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		offers[player] = nil
		used[player] = nil
		killers[player] = nil
	end)
end

return ReviveService
