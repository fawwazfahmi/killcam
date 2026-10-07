-- The test range has no match: nothing starts, ends or is scored, and combat
-- is always allowed. The services the range shares with the match place
-- (combat, loadouts, grenades, spawning, drops) ask a MatchService what is
-- allowed; this one answers for the range. A unit test checks that it has
-- everything they ask for.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local MatchService = {}

local never = Instance.new("BindableEvent") -- nothing ever fires it

MatchService.Started = never.Event
MatchService.RoundStarted = never.Event
MatchService.Changed = never.Event

function MatchService.mode()
	return "RANGE"
end

function MatchService.phase()
	return "Playing"
end

function MatchService.combatAllowed()
	return true
end

function MatchService.canSpawn()
	return true
end

function MatchService.respawns()
	return true
end

function MatchService.spawnTeam(teamName)
	return teamName
end

-- No kill goes on a scoreboard here.
function MatchService.addKill(_side)
	return false
end

-- The head-up display reads the mode from this and shows the range's name
-- where the score would be.
function MatchService.sendTo(player)
	Remotes.MatchUpdate:FireClient(player, { mode = "RANGE", phase = "Playing", scores = {}, timeLeft = 0 })
end

return MatchService
