-- Changing the tactical item or a piece of armour in the middle of a match.
-- Those are set in the lobby and normally locked here; a player can pay Robux
-- to change one (ShopConfig.matchSwap.armourProductId). It has to be something
-- they already own, and it takes effect at their next spawn, like any change.
--
-- One purchase changes one piece. As with revives, the purchase is added to
-- the profile first and spent from there, so one that arrives after the player
-- has changed their mind is kept for next time.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared.Config.ShopConfig)
local Economy = require(Shared.Logic.Economy)

local LoadoutService = require(script.Parent.LoadoutService)
local ProfileStore = require(script.Parent.ProfileStore)
local PurchaseService = require(script.Parent.PurchaseService)

local SwapService = {}

local PRODUCT = ShopConfig.matchSwap.armourProductId

local ASK_LASTS = 60 -- seconds a change waits for its purchase before it is forgotten

local asked = {} -- [player] = { wanted = loadout, field = string, at = number }: the change waiting to be paid for

-- Makes the change a player asked for, if they hold a swap to pay for it.
local function apply(player)
	local request = asked[player]
	local profile = ProfileStore.get(player)
	if not request or not profile or (profile.swaps or 0) <= 0 then
		return false
	end
	asked[player] = nil
	-- Checked before it is paid for: a piece they do not own costs them nothing.
	if LoadoutService.setPieces(player, request.wanted, { request.field }) then
		Economy.spend(profile, "swaps")
	end
	ProfileStore.push(player)
	return true
end

function SwapService.init()
	if PRODUCT == 0 then
		return -- switched off: armour and the tactical item stay locked in a match
	end

	PurchaseService.sell(PRODUCT, "swaps", function(player)
		if not apply(player) then
			ProfileStore.push(player) -- kept for next time
		end
	end)

	LoadoutService.PiecesRequested:Connect(function(player, wanted, fields)
		local waiting = asked[player]
		if #fields ~= 1 or (waiting and os.clock() - waiting.at < ASK_LASTS) then
			return -- one piece at a time, and one purchase at a time
		end
		asked[player] = { wanted = wanted, field = fields[1], at = os.clock() }
		if not apply(player) then
			MarketplaceService:PromptProductPurchase(player, PRODUCT)
		end
	end)

	-- They closed the purchase window without buying.
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, bought)
		local player = Players:GetPlayerByUserId(userId)
		if player and productId == PRODUCT and not bought then
			asked[player] = nil
			LoadoutService.push(player) -- the menu goes back to what they are wearing
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		asked[player] = nil
	end)
end

return SwapService
