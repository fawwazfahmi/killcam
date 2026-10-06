-- Experience with each class of weapon (rules in Shared.Logic.Prestige,
-- numbers in ProgressConfig). A kill earns it for the class of the weapon
-- that made it, and an assist for the class of the weapon the helper last
-- hurt the victim with. Only kills that count for the match earn anything, so
-- the warm-up cannot be farmed.
--
-- It is kept on the profile as raw experience, and saved with it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressConfig = require(Shared.Config.ProgressConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Prestige = require(Shared.Logic.Prestige)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
local ProfileStore = require(script.Parent.ProfileStore)

local ProgressService = {}

local CONFIG = ProgressConfig.weapons

local function award(player, weaponName, amount)
	local profile = ProfileStore.get(player)
	local config = WeaponConfig.Weapons[weaponName]
	local class = config and Prestige.classOf(config)
	if not profile or not class then
		return
	end
	local record = profile.weapons[class]
	if type(record) ~= "table" or type(record.xp) ~= "number" then
		record = { xp = 0 }
		profile.weapons[class] = record
	end
	local standing, rose = Prestige.earn(CONFIG.prestiges, record, amount)
	if rose then
		Remotes.TierUp:FireClient(player, CONFIG.titles[class], standing.title)
	end
end

function ProgressService.init()
	CombatService.Killed:Connect(function(_victim, attacker, side, weaponName, assists)
		if not side then
			return -- the kill did not count for the match
		end
		award(attacker, weaponName, CONFIG.xp.kill)
		for _, assist in assists do
			award(assist.player, assist.weapon, CONFIG.xp.assist)
		end
	end)
end

return ProgressService
