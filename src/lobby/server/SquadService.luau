-- Squads in the lobby (rules in Shared.Logic.Squad). A player invites another
-- who is standing in the same penthouse; a squad queues as one and is never
-- put in different matches, or on different teams (see QueueService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LobbyConfig = require(Shared.Config.LobbyConfig)
local Squad = require(Shared.Logic.Squad)
local Remotes = require(Shared.Remotes)

local SquadService = {}

local CONFIG = LobbyConfig.squad
local SAY_EVERY = 1 -- seconds between requests one player may make

local state = Squad.new()
local lastAsked = {} -- [player] = when they last invited, answered or left

local changed = Instance.new("BindableEvent")
-- Fires with a list of the players whose squad has just changed.
SquadService.Changed = changed.Event

-- Everybody who queues with this player, leader first.
function SquadService.groupOf(player)
	return Squad.members(state, player)
end

-- True if this player may queue: they are alone, or lead their squad.
function SquadService.leads(player)
	return Squad.leader(state, player) == player
end

local function describe(who)
	return { name = who.Name, displayName = who.DisplayName }
end

-- Tells a player who is in their squad and who has invited them.
local function send(player)
	if player.Parent ~= Players then
		return
	end
	local leader = Squad.leader(state, player)
	local members = {}
	for _, member in Squad.members(state, player) do
		local entry = describe(member)
		entry.leader = member == leader
		table.insert(members, entry)
	end
	local invites = {}
	for _, from in Squad.invitesFor(state, player, os.clock()) do
		table.insert(invites, describe(from))
	end
	Remotes.SquadUpdate:FireClient(player, { members = members, invites = invites, leading = leader == player })
end

local function sendAll(players)
	for _, player in players do
		send(player)
	end
	if #players > 0 then
		changed:Fire(players)
	end
end

local function allowed(player)
	local now = os.clock()
	if now - (lastAsked[player] or 0) < SAY_EVERY then
		return false
	end
	lastAsked[player] = now
	return true
end

-- A player named by a client, if they are really here.
local function named(name)
	local found = type(name) == "string" and Players:FindFirstChild(name)
	return if found and found:IsA("Player") then found else nil
end

function SquadService.init()
	Remotes.SquadInvite.OnServerEvent:Connect(function(player, name)
		local target = named(name)
		if target and allowed(player) and Squad.invite(CONFIG, state, player, target, os.clock()) then
			send(target)
			-- When it lapses, the invitation comes off their screen.
			task.delay(CONFIG.inviteLasts + 0.5, send, target)
		end
	end)

	Remotes.SquadAnswer.OnServerEvent:Connect(function(player, name, accept)
		local from = named(name)
		if not from or not allowed(player) then
			return
		end
		local _, _, touched = Squad.answer(CONFIG, state, player, from, accept == true, os.clock())
		send(player) -- the invitation is gone from their screen, whatever came of it
		sendAll(touched)
	end)

	Remotes.SquadLeave.OnServerEvent:Connect(function(player)
		if allowed(player) then
			sendAll(Squad.leave(state, player))
		end
	end)

	Players.PlayerAdded:Connect(send)
	for _, player in Players:GetPlayers() do
		send(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
		sendAll(Squad.remove(state, player))
	end)
end

return SquadService
