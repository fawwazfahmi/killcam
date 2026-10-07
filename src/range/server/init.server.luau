-- The test range: a place for the game's developers and nobody else, with
-- everything unlocked, dummies to shoot, and a panel of switches. It runs the
-- match place's own combat, loadout, grenade, tactical, drop and spawn code,
-- so what is tried here is what a match does, and leaves out everything a
-- match is besides: no teams, score, profiles, shop, points or experience.
-- Nothing done here is saved.
--
-- The services shared with the match place are mapped in beside this script
-- by range.project.json. MatchService, TeamService, StatsService and
-- BombService here are the range's own, in place of the match's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Creates the remotes before any client asks for them.
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local AdminGate = require(script.AdminGate)
local MapBuilder = require(script.MapBuilder)
local Signs = require(script.Signs)
local LoadoutService = require(script.LoadoutService)
local CombatService = require(script.CombatService)
local GrenadeService = require(script.GrenadeService)
local TacticalService = require(script.TacticalService)
local DropService = require(script.DropService)
local SpawnService = require(script.SpawnService)
local DummyService = require(script.DummyService)
local CheatService = require(script.CheatService)

local layout = require(script.FiringRange)

local COMMANDS_A_SECOND = 20

-- First, so that nobody is let in while the rest is still being set up.
AdminGate.init()

MapBuilder.build(layout)
Signs.build(layout)

LoadoutService.init()
CombatService.init()
GrenadeService.init()
TacticalService.init()
DropService.init()
CheatService.init(layout)

-- What the admin panel can ask for, by name. Everything after the name comes
-- from a client, so each of these checks what it is given, or hands it to
-- something that does.
local COMMANDS = {}

-- One setting of one dummy, or of all of them.
function COMMANDS.Dummy(_player, target, field, value)
	if target == "all" or type(target) == "number" then
		DummyService.set(target, field, value)
	end
end

function COMMANDS.Place(player, position)
	if CombatService.isVector(position) then
		DummyService.place(player, position)
	end
end

function COMMANDS.Remove(_player, target)
	if target == "placed" then
		DummyService.removePlaced()
	elseif type(target) == "number" then
		DummyService.remove(target)
	end
end

function COMMANDS.StandAll()
	DummyService.standAll()
end

function COMMANDS.Cheat(player, name, on)
	if type(name) == "string" then
		CheatService.set(player, name, on == true)
	end
end

function COMMANDS.Hit(player, weaponName, aim)
	CheatService.hit(player, weaponName, aim)
end

function COMMANDS.Hurt(player, amount)
	CheatService.hurt(player, amount)
end

function COMMANDS.Heal(player)
	CheatService.heal(player)
end

function COMMANDS.Go(player, index)
	CheatService.go(player, index)
end

Remotes.RangeCommand.OnServerEvent:Connect(function(player, name, ...)
	if not AdminGate.allowed(player) or not CombatService.allow(player, "RangeCommand", COMMANDS_A_SECOND) then
		return
	end
	local run = type(name) == "string" and COMMANDS[name]
	if run then
		run(player, ...)
	end
end)

-- What the panel shows: every dummy and how it is set, this player's own
-- switches, and the places they can be sent.
local places = {}
for index, spot in layout.spots do
	places[index] = { name = spot.name, yaw = spot.yaw }
end

local function send(player)
	Remotes.RangeUpdate:FireClient(player, {
		dummies = DummyService.list(),
		cheats = CheatService.of(player),
		spots = places,
	})
end

DummyService.Changed:Connect(function()
	for _, player in Players:GetPlayers() do
		send(player)
	end
end)
CheatService.Changed:Connect(send)
Players.PlayerAdded:Connect(send)
for _, player in Players:GetPlayers() do
	send(player)
end

SpawnService.init()

-- Last, because it waits on Roblox to build the dummy's figure, and players
-- should not be kept from spawning meanwhile.
DummyService.init(layout)
