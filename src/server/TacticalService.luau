-- Tactical items, used with Q. The client only says "now"; uses, timing and
-- effects are decided here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TacticalConfig = require(Shared.Config.TacticalConfig)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
local LoadoutService = require(script.Parent.LoadoutService)
local MatchService = require(script.Parent.MatchService)

local TacticalService = {}

local HEAL_STEPS = 10

local EFFECTS = {}

-- Restores health in small steps, stopping if the player dies or respawns.
function EFFECTS.Stim(player, state, item)
	local life = state.life
	task.spawn(function()
		for _ = 1, HEAL_STEPS do
			task.wait(item.healTime / HEAL_STEPS)
			local _, humanoid = CombatService.bodyOf(player)
			if not humanoid or state.life ~= life then
				return
			end
			humanoid.Health = math.min(humanoid.Health + item.heal / HEAL_STEPS, humanoid.MaxHealth)
		end
	end)
end

function EFFECTS.Cryo(_player, state, item)
	state.steadyUntil = os.clock() + item.duration
end


local function onUse(player)
	if not CombatService.allow(player, "UseTactical", 4) then
		return
	end
	if not MatchService.combatAllowed() then
		return
	end

	local state = LoadoutService.get(player)
	if not state or not CombatService.bodyOf(player) or state.tacticalUses <= 0 or state.tacticalBusy then
		return
	end

	local name = state.loadout.tactical
	local item = TacticalConfig.items[name]
	local life = state.life
	state.tacticalUses -= 1
	state.tacticalBusy = true
	LoadoutService.endProtection(player)
	LoadoutService.push(player)

	local function apply()
		-- The wind-up is wasted if they died or respawned during it.
		if LoadoutService.get(player) ~= state or state.life ~= life then
			return
		end
		state.tacticalBusy = false
		if CombatService.bodyOf(player) then
			EFFECTS[name](player, state, item)
		end
	end

	local windUp = TacticalConfig.useTime * state.stats.tacticalScale
	if windUp > 0 then
		task.delay(windUp, apply)
	else
		apply()
	end
end

function TacticalService.init()
	Remotes.UseTactical.OnServerEvent:Connect(onUse)
end

return TacticalService
