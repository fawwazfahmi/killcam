-- Damage that comes from the range itself, not from a player: a dummy
-- shooting back, or the panel's "hit me" buttons. The victim flinches and is
-- told about it exactly as when a player hits them (see
-- CombatService.applyDamage), but there is nobody to score it and nobody to
-- show in a killcam.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local CombatService = require(script.Parent.CombatService)

local Harm = {}

-- `from` is where it came from, `source` the name for the kill feed, and
-- `detail` is { zone, raw, headshot, distance }, as for a hit on a dummy.
function Harm.deal(victim, amount, from, source, weaponName, detail)
	local character, humanoid = CombatService.bodyOf(victim)
	if not humanoid or amount <= 0 then
		return
	end
	-- Spawn protection and god mode are both force fields, and a force field
	-- stops TakeDamage. The hit is still reported, marked as stopped.
	local shielded = character:FindFirstChildOfClass("ForceField") ~= nil
	humanoid:TakeDamage(amount)

	local knock = CombatService.flinchFor(victim, weaponName, detail.headshot)
	Remotes.Damaged:FireClient(victim, amount, from, knock)
	Remotes.RangeHit:FireClient(victim, {
		taken = true,
		label = source,
		weapon = weaponName,
		zone = detail.zone,
		raw = detail.raw,
		amount = amount,
		left = humanoid.Health,
		lethal = humanoid.Health <= 0,
		shielded = shielded,
		knock = knock, -- degrees their aim was thrown
		distance = detail.distance,
	})
	if humanoid.Health <= 0 then
		Remotes.KillFeed:FireAllClients(source, victim.Name, weaponName, detail.headshot)
	end
end

return Harm
