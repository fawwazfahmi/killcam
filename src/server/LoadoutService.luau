-- Owns what each player is carrying: their chosen loadout, slots, ammo, the
-- equipped weapon, tactical uses, reload state and the timing facts hit
-- validation needs.
--
-- Slots: 1 primary, 2 handgun, 3 knife, 4 a grenade, 5 the bomb while the
-- player carries it, and 6 and 7 the second primary and second grenade that
-- some gloves add. An empty slot holds `false`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmorConfig = require(Shared.Config.ArmorConfig)
local TacticalConfig = require(Shared.Config.TacticalConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Ammo = require(Shared.Logic.Ammo)
local Loadout = require(Shared.Logic.Loadout)
local WeaponModels = require(Shared.WeaponModels)
local Remotes = require(Shared.Remotes)


local LoadoutService = {}

local states = {}

-- What a player may use. ProfileService replaces this with the shop's rules;
-- until then everything is allowed.
--   owns(player, loadout)   may they pick every option in it?
--   equip(player, loadout)  the loadout they actually get at spawn
--   charge(player, previous, wanted)
--                           what changing from one life's loadout to the next
--                           costs them. Returns the loadout they get and a
--                           line to show them, or nil.
local gate = {
	owns = function(_player, _loadout)
		return true
	end,
	equip = function(_player, loadout)
		return loadout
	end,
	charge = function(_player, _previous, wanted)
		return wanted, nil
	end,
}

local PIECE_FIELDS = Loadout.pieceFields(ArmorConfig)

function LoadoutService.setGate(newGate)
	gate = newGate
end

local chosen = Instance.new("BindableEvent")
-- Fires with (player, loadout) when a player's pick for their next life is accepted.
LoadoutService.Chosen = chosen.Event

local piecesRequested = Instance.new("BindableEvent")
-- Fires with (player, loadout, fields) when a player asks, during a match, to
-- change their tactical item or armour. Nothing changes unless whoever is
-- listening calls LoadoutService.setPieces.
LoadoutService.PiecesRequested = piecesRequested.Event

-- Restores a pick saved from an earlier session or made in the lobby. It is
-- checked like any other, and used from the player's next spawn.
function LoadoutService.setChoice(player, loadout)
	local state = states[player]
	local clean = Loadout.sanitize(WeaponConfig, TacticalConfig, ArmorConfig, loadout)
	if state and clean and gate.owns(player, clean) then
		state.choice = clean
		LoadoutService.push(player)
	end
end

-- Changes the tactical item and armour picked for a player's next life to
-- those in `wanted`, for the listed fields. Returns whether it was allowed.
function LoadoutService.setPieces(player, wanted, fields)
	local state = states[player]
	if not state then
		return false
	end
	local merged = Loadout.withFieldsFrom(state.choice, wanted, fields)
	local allowed = gate.owns(player, merged)
	if allowed then
		state.choice = merged
		chosen:Fire(player, merged)
	end
	LoadoutService.push(player)
	return allowed
end

function LoadoutService.add(player)
	local loadout = Loadout.default(WeaponConfig, TacticalConfig, ArmorConfig)
	states[player] = {
		choice = loadout, -- what the next life will use
		loadout = loadout, -- what this life is using
		stats = Loadout.stats(ArmorConfig, loadout),
		life = 0, -- goes up at every spawn
		slots = {},
		ammo = {},
		equipped = 1,
		equippedAt = 0,
		nextShotAt = {},
		lastShotAt = {},
		reEquipped = {},
		reloading = false,
		reloadToken = 0,
		tacticalUses = 0,
		tacticalBusy = false,
		steadyUntil = 0, -- a Cryo Shot is active until this time
		lastSwing = -math.huge,
		protectedUntil = 0,
	}
end

function LoadoutService.remove(player)
	states[player] = nil
end

function LoadoutService.get(player)
	return states[player]
end

-- The name of the weapon in hand, or nil if that slot is empty.
function LoadoutService.weaponName(state)
	return state.slots[state.equipped] or nil
end

-- `notice` is one line for the player to read, such as what a change cost.
function LoadoutService.push(player, isReset, notice)
	local state = states[player]
	if not state then
		return
	end
	Remotes.LoadoutUpdate:FireClient(player, {
		reset = isReset == true,
		notice = notice,
		slots = state.slots,
		equipped = state.equipped,
		ammo = state.ammo,
		loadout = state.loadout,
		choice = state.choice,
		tacticalUses = state.tacticalUses,
	})
end

-- Puts the equipped weapon in the character's right hand for other players to see.
function LoadoutService.attachModel(player)
	local state = states[player]
	local character = player.Character
	if not state or not character then
		return
	end

	local config = WeaponConfig.Weapons[LoadoutService.weaponName(state)]
	-- A teammate watching through this player's eyes draws the same weapon.
	player:SetAttribute("Weapon", if config then config.model else nil)
	WeaponModels.hold(character, if config then config.model else nil)
end

-- Fresh loadout for a new life.
function LoadoutService.reset(player)
	local state = states[player]
	if not state then
		return
	end

	state.life += 1
	local previous = state.loadout
	local allowed = gate.equip(player, table.clone(state.choice))
	state.stats = Loadout.stats(ArmorConfig, allowed)
	-- Only what is actually carried counts: for what a change costs, and for
	-- whose rental runs down.
	local wanted = Loadout.carried(allowed, state.stats)
	local got, notice = gate.charge(player, previous, wanted)
	if got ~= wanted then
		-- A change they could not pay for: the menu goes back to what they have.
		state.choice = Loadout.withWeaponsFrom(state.choice, got)
	end
	state.loadout = Loadout.carried(got, state.stats)
	state.slots = Loadout.slots(WeaponConfig, state.loadout, state.stats)
	state.ammo = {}
	for _, name in state.slots do
		local config = name and WeaponConfig.Weapons[name]
		if config and config.kind == "Gun" then
			state.ammo[name] = Ammo.full(config)
		end
	end

	state.equipped = 1
	state.equippedAt = os.clock()
	state.nextShotAt = {}
	state.lastShotAt = {}
	state.reEquipped = {}
	state.reloading = false
	state.reloadToken += 1
	state.tacticalUses = TacticalConfig.items[state.loadout.tactical].uses
	state.tacticalBusy = false
	state.steadyUntil = 0
	state.lastSwing = -math.huge

	-- Other clients read this to decide how far this player's footsteps carry.
	player:SetAttribute("Footsteps", state.stats.footsteps)

	LoadoutService.attachModel(player)
	LoadoutService.push(player, true, notice)
end

function LoadoutService.equip(player, slot)
	local state = states[player]
	if not state or state.equipped == slot then
		return
	end
	local name = state.slots[slot]
	if not name then
		return
	end

	state.equipped = slot
	state.equippedAt = os.clock()
	state.reEquipped[name] = true
	-- Switching weapons cancels a reload in progress.
	state.reloading = false
	state.reloadToken += 1

	LoadoutService.attachModel(player)
end

-- Empties a slot and returns what was in it: the weapon's name and, for a
-- gun, its ammo. If it was in hand, the player switches to what they have left.
function LoadoutService.removeWeapon(player, slot)
	local state = states[player]
	local name = state and state.slots[slot]
	if not name then
		return nil
	end
	local ammo = state.ammo[name]
	state.slots[slot] = false
	state.ammo[name] = nil
	state.nextShotAt[name], state.lastShotAt[name], state.reEquipped[name] = nil, nil, nil

	if state.equipped == slot then
		state.equipped = Loadout.fallbackSlot(state.slots)
		state.equippedAt = os.clock()
		state.reloading = false
		state.reloadToken += 1
		LoadoutService.attachModel(player)
	end
	LoadoutService.push(player)
	return name, ammo
end

-- Puts a weapon in an empty slot. `ammo` is { mag, reserve } for a gun.
function LoadoutService.addWeapon(player, slot, name, ammo)
	local state = states[player]
	if not state or state.slots[slot] then
		return false
	end
	state.slots[slot] = name
	state.ammo[name] = ammo
	LoadoutService.push(player)
	return true
end

-- Search and Destroy: the bomb sits in slot 5 while this player carries it.
function LoadoutService.setBomb(player, carrying)
	if carrying then
		LoadoutService.addWeapon(player, Loadout.BOMB, "Bomb", nil)
	else
		LoadoutService.removeWeapon(player, Loadout.BOMB)
	end
end

-- A weapon's draw time for this player, after their gloves.
function LoadoutService.equipTime(state, config)
	return config.equipTime * state.stats.equipScale
end

-- True while a Cryo Shot is keeping this player's aim steady under fire.
function LoadoutService.isSteady(player)
	local state = states[player]
	return state ~= nil and state.steadyUntil > os.clock()
end

function LoadoutService.startReload(player)
	local state = states[player]
	if not state or state.reloading then
		return
	end
	local name = LoadoutService.weaponName(state)
	local config = WeaponConfig.Weapons[name]
	local ammo = state.ammo[name]
	if not config or config.kind ~= "Gun" or not ammo then
		return
	end
	if not Ammo.canReload(config, ammo) then
		return
	end

	state.reloading = true
	state.reloadToken += 1
	local token = state.reloadToken

	-- Finish slightly early so a shot sent the instant the client's own reload
	-- timer ends is not rejected.
	task.delay(config.reloadTime - WeaponConfig.Validation.jitterSlack, function()
		if states[player] ~= state or state.reloadToken ~= token then
			return
		end
		Ammo.reload(config, ammo)
		state.reloading = false
		LoadoutService.push(player)
	end)
end

function LoadoutService.endProtection(player)
	local state = states[player]
	if not state or state.protectedUntil == 0 then
		return
	end
	state.protectedUntil = 0
	local shield = player.Character and player.Character:FindFirstChild("SpawnProtection")
	if shield then
		shield:Destroy()
	end
end

function LoadoutService.isProtected(player)
	local state = states[player]
	return state ~= nil and state.protectedUntil > os.clock()
end

function LoadoutService.init()
	Remotes.EquipSlot.OnServerEvent:Connect(function(player, slot)
		if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > Loadout.SLOT_COUNT then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			LoadoutService.equip(player, slot)
		end
	end)

	Remotes.Reload.OnServerEvent:Connect(function(player)
		LoadoutService.startReload(player)
	end)

	Remotes.SelectLoadout.OnServerEvent:Connect(function(player, choice)
		local state = states[player]
		local clean = Loadout.sanitize(WeaponConfig, TacticalConfig, ArmorConfig, choice)
		if state and clean then
			-- Weapons the player owns can be swapped freely here; what it costs
			-- is settled when they spawn with them (see `gate.charge`).
			local merged = Loadout.withWeaponsFrom(state.choice, clean)
			if gate.owns(player, merged) then
				state.choice = merged
				chosen:Fire(player, merged)
			end
			-- The tactical item and armour are another matter, and not ours to decide.
			local pieces = Loadout.changed(state.choice, clean, PIECE_FIELDS)
			if #pieces > 0 then
				piecesRequested:Fire(player, clean, pieces)
			end
		end
		-- Always answer, so a refused pick snaps back in the menu.
		LoadoutService.push(player)
	end)
end

return LoadoutService
