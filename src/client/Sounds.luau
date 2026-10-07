-- Plays the game's sounds (listed in SoundConfig). The player's own are heard
-- at once and flat; other players' shots and explosions come from where they
-- happened and fade with distance.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundConfig = require(Shared.Config.SoundConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Remotes = require(Shared.Remotes)

local Sounds = {}

local SPEED_WOBBLE = 0.05 -- each play is this much faster or slower, so a burst is not one note repeated
local HEARD_FULLY_WITHIN = 0.12 -- of a sound's range: nearer than this it is at full volume

local player = Players.LocalPlayer
local classOfModel = {} -- [weapon model name] = weapon class, for telling what another player fired

local function make(entry, parent)
	local sound = Instance.new("Sound")
	sound.SoundId = entry.id
	sound.Volume = entry.volume
	sound.PlaybackSpeed = entry.speed * (1 + (math.random() * 2 - 1) * SPEED_WOBBLE)
	sound.Parent = parent
	return sound
end

-- Plays a sound for this player only.
function Sounds.play(name)
	local entry = SoundConfig.sounds[name]
	if not entry or entry.id == "" then
		return
	end
	local sound = make(entry, SoundService)
	sound.PlayOnRemove = true
	sound:Destroy() -- plays as it goes, and leaves nothing behind
end

-- Plays a sound somewhere in the world.
function Sounds.playAt(name, position)
	local entry = SoundConfig.sounds[name]
	if not entry or entry.id == "" or not entry.range then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain
	local sound = make(entry, holder)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = entry.range * HEARD_FULLY_WITHIN
	sound.RollOffMaxDistance = entry.range
	sound:Play()
	Debris:AddItem(holder, 6)
end

-- The player's own gun going off. `config` is the weapon's.
function Sounds.shot(config)
	local name = SoundConfig.shots[config.class]
	if name then
		Sounds.play(name)
	end
end

function Sounds.start()
	for _, config in WeaponConfig.Weapons do
		if config.model and SoundConfig.shots[config.class] then
			classOfModel[config.model] = config.class
		end
	end

	-- Somebody else fired. The server says who and from where; what they are
	-- holding says what it sounds like.
	Remotes.ShotFired.OnClientEvent:Connect(function(shooter, origin)
		local class = typeof(shooter) == "Instance" and classOfModel[shooter:GetAttribute("Weapon")]
		if class and shooter ~= player then
			Sounds.playAt(SoundConfig.shots[class], origin)
		end
	end)
	Remotes.Explosion.OnClientEvent:Connect(function(position)
		Sounds.playAt("Explosion", position)
	end)
	Remotes.Flash.OnClientEvent:Connect(function()
		Sounds.play("Flash")
	end)
	Remotes.HitConfirm.OnClientEvent:Connect(function(headshot, killed)
		Sounds.play(if killed then "Kill" elseif headshot then "Headshot" else "Hit")
	end)
	Remotes.Damaged.OnClientEvent:Connect(function()
		Sounds.play("Hurt")
	end)
end

return Sounds
