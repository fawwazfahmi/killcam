-- Robux purchases in a match. Roblox reports every purchase to one function
-- per server, so this is the one place that hears them; a service that sells
-- something registers its product here.
--
-- Two rules, because money is involved. A purchase is first added to the
-- player's profile as a count ("revives", "swaps") and only then used, so one
-- that cannot be used straight away is kept. And Roblox is only told a
-- purchase is done once the profile holding it has been saved: until then it
-- reports the purchase again, in this session or a later one, and
-- Economy.grant counts each purchase once however often that happens.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Logic.Economy)

local ProfileStore = require(script.Parent.ProfileStore)

local PurchaseService = {}

local products = {} -- [product id] = { kind = string, bought = function }

-- Sells developer product `productId` as one of `kind` on the buyer's
-- profile. `bought(player)` runs once it has been added, to use it at once if
-- that is still possible.
function PurchaseService.sell(productId, kind, bought)
	products[productId] = { kind = kind, bought = bought }
end

local function processReceipt(receipt)
	local product = products[receipt.ProductId]
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- not sold here
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and ProfileStore.get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- try again when they are here
	end

	Economy.grant(profile, product.kind, receipt.PurchaseId)
	product.bought(player)

	if ProfileStore.persists() and not ProfileStore.save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PurchaseService.init()
	MarketplaceService.ProcessReceipt = processReceipt
end

return PurchaseService
