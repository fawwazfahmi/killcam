-- Every RemoteEvent in the game. The server creates them; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	-- client -> server
	"FireShot",
	"MeleeSwing",
	"Reload",
	"EquipSlot",
	"SelectLoadout", -- the loadout to use from the next spawn
	"UseTactical", -- Q was pressed
	"ThrowGrenade", -- carries the aim direction
	"DropWeapon", -- G was pressed: drop what is in hand
	"BombUse", -- true while planting or defusing is held, false when released
	"BuyRental", -- field, option, amount (hours of use, or days)
	"AckExpired", -- lobby: the notice of what ran out was closed
	"ReviveRequest", -- F was pressed on the revive offer
	"Aim", -- how far up or down the player is looking, so a teammate watching through their eyes sees it
	"QueueJoin", -- lobby: queue for a mode
	"QueueLeave", -- lobby: leave the queue
	"SquadInvite", -- lobby: ask a player in this penthouse to join your squad
	"SquadAnswer", -- lobby: accept or decline an invitation, naming who sent it
	"SquadLeave", -- lobby: leave your squad
	-- server -> client
	"MatchUpdate",
	"LoadoutUpdate",
	"HitConfirm",
	"Damaged",
	"ShotFired",
	"Explosion",
	"Flash", -- a flashbang went off in view: where, and the longest it can blind for
	"KillFeed",
	"Killcam", -- to one player who was just killed: who by, with what, a headshot or not, and the killer's health
	"BombUpdate", -- where the bomb is: status, carrier, position, site
	"BombProgress", -- to one player: they started ("Plant"/"Defuse", seconds) or stopped (nil)
	"ProfileUpdate", -- to one player: their points, level and rentals
	"Mvp", -- to everyone at the end of a match: the MVP's name and kills
	"Podium", -- to everyone: the end-of-match ceremony (where, who, their moods), or nil when it is over
	"ReviveOffer", -- to one player who died: a revive is on offer (see ReviveService), or nil when it is gone
	"Revived", -- to everyone: this player bought their way back
	"TierUp", -- to one player: the weapon class and the standing they have just reached with it
	"SquadUpdate", -- lobby, to one player: who is in their squad, and who has invited them
	"QueueUpdate", -- lobby, to one player: the mode they are queued for and how full it is
}

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in NAMES do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
