-- Input, firing, reloading, switching and the tactical item for the local
-- player. Everything here is a prediction: the server decides what actually
-- hit (see CombatService).
--
-- Slots: 1 primary, 2 handgun (or second primary), 3 knife, 4 a grenade, 5 the
-- bomb while carrying it. An empty slot holds `false`. Q uses the tactical
-- item and G drops the gun or bomb in hand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmorConfig = require(Shared.Config.ArmorConfig)
local TacticalConfig = require(Shared.Config.TacticalConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Ammo = require(Shared.Logic.Ammo)
local Loadout = require(Shared.Logic.Loadout)
local Recoil = require(Shared.Logic.Recoil)
local Spread = require(Shared.Logic.Spread)
local Remotes = require(Shared.Remotes)

local Effects = require(script.Parent.Effects)

local WeaponController = {}

local player = Players.LocalPlayer
local deps

-- What the player presses is in ControlsConfig, and reaches here as actions
-- (see Controls): the same ones from a keyboard, a controller or a touch screen.
local NUMBER_KEYS = 5 -- Slot1 to Slot5. Each reaches one or two slots (see Loadout.KEYS).

-- { slots, equipped, ammo, loadout, choice, tacticalUses } as last sent by the server
local loadout = nil
local stats = nil -- what the armour in loadout.loadout adds up to
local wasAlive = false
local lastSlot = nil -- the slot in hand before the current one, for the quick switch

local equipReadyAt = 0
local reloadEndsAt = nil
local nextShotAt = {} -- per weapon name
local lastShotAt = {} -- per weapon name
local lastShotAny = -math.huge
local shotIndex = 0
local bloom = 0
local lastSwing = -math.huge
local scoped = false

local triggerHeld = false
local triggerPressed = false
local scopeHeld = false

local function isAlive()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- The weapon in hand and its config, or nil if the slot is empty.
local function equippedWeapon()
	local name = loadout.slots[loadout.equipped] or nil
	return name, name and WeaponConfig.Weapons[name]
end

local function refreshHud()
	if not loadout then
		return
	end
	local name, config = equippedWeapon()
	if not config then
		return
	end
	local text = ""
	if config.kind == "Gun" then
		local ammo = loadout.ammo[name]
		text = reloadEndsAt and "Reloading" or string.format("%d / %d", ammo.mag, ammo.reserve)
	elseif config.kind == "Grenade" then
		text = "Click to throw"
	elseif config.kind == "Bomb" then
		text = "Hold fire on a site"
	end
	deps.hud.setWeapon(config.displayName, text)

	local item = TacticalConfig.items[loadout.loadout.tactical]
	local hint = deps.controls.hint("Tactical")
	local prefix = if hint ~= "" then "[" .. hint .. "] " else ""
	deps.hud.setTactical(string.format("%s%s  x%d", prefix, item.displayName, loadout.tacticalUses))
end

local function setScoped(value)
	if scoped == value then
		return
	end
	scoped = value
	local _, config = equippedWeapon()
	deps.camera.setScope(value and config and config.scope or nil)
	deps.viewmodel.setHidden(value)
	deps.hud.setScoped(value)
end

local function equip(slot, tellServer)
	local name = loadout.slots[slot]
	local config = name and WeaponConfig.Weapons[name]
	if not config then
		return
	end

	setScoped(false)
	if loadout.equipped ~= slot then
		lastSlot = loadout.equipped
	end
	loadout.equipped = slot
	local equipTime = config.equipTime * stats.equipScale -- gloves can shorten the draw
	equipReadyAt = os.clock() + equipTime
	reloadEndsAt = nil
	shotIndex = 0
	bloom = 0

	-- Drawing the sniper again skips the rest of its rechamber.
	if config.quickSwitchInterval and lastShotAt[name] then
		nextShotAt[name] = math.min(nextShotAt[name] or 0, lastShotAt[name] + config.quickSwitchInterval)
	end

	deps.viewmodel.equip(config.model, equipTime)
	deps.sounds.play("Equip")
	deps.movement.setSpeedScale(Loadout.speedScale(stats, config.class))
	deps.objective.setPlanting(false)
	if tellServer then
		Remotes.EquipSlot:FireServer(slot)
	end
	refreshHud()
end

-- The mouse wheel steps to the next slot that has something in it.
local function cycleSlot(direction)
	local slot = Loadout.nextSlot(loadout.slots, loadout.equipped, direction)
	if slot ~= loadout.equipped then
		equip(slot, true)
	end
end

-- Back to whatever was in hand before, if it is still there.
local function quickSwitch()
	if lastSlot and lastSlot ~= loadout.equipped and loadout.slots[lastSlot] then
		equip(lastSlot, true)
	end
end

local function tryReload()
	local name, config = equippedWeapon()
	if not config or config.kind ~= "Gun" or reloadEndsAt then
		return
	end
	if not Ammo.canReload(config, loadout.ammo[name]) then
		return
	end
	setScoped(false)
	reloadEndsAt = os.clock() + config.reloadTime
	deps.sounds.play("Reload")
	Remotes.Reload:FireServer()
	refreshHud()
end

local function finishReload()
	local name, config = equippedWeapon()
	Ammo.reload(config, loadout.ammo[name])
	reloadEndsAt = nil
	refreshHud()
end

local function useTactical()
	if loadout.tacticalUses <= 0 then
		return
	end
	loadout.tacticalUses -= 1 -- the server sends the true count straight back
	Remotes.UseTactical:FireServer()
	refreshHud()
end

local function throwGrenade()
	Remotes.ThrowGrenade:FireServer(workspace.CurrentCamera.CFrame.LookVector)
	loadout.slots[loadout.equipped] = false
	equip(Loadout.fallbackSlot(loadout.slots), false) -- the server switches us as well
end

-- Raycasts past things a bullet should ignore: our own body and viewmodel,
-- hats, and the invisible root part (which overlaps the torso).
local function cast(origin, direction, range)
	local ignore = { player.Character, workspace.CurrentCamera }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignore
		local result = workspace:Raycast(origin, direction * range, params)
		if not result then
			return nil
		end
		local hit = result.Instance
		if hit.Name == "HumanoidRootPart" or hit:FindFirstAncestorOfClass("Accessory") then
			table.insert(ignore, hit)
		else
			return result
		end
	end
	return nil
end

-- A body part directly inside another player's character, or inside one of
-- the test range's dummies, or nil.
local function characterPart(result)
	if not result then
		return nil
	end
	local character = result.Instance.Parent
	if character and (Players:GetPlayerFromCharacter(character) or character:GetAttribute("Dummy")) then
		return result.Instance
	end
	return nil
end

local function spreadDirection(cframe, degrees)
	local angle = math.rad(degrees) * math.sqrt(math.random())
	local roll = math.random() * math.pi * 2
	return (cframe * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

local function fireGun(name, config, now)
	local ammo = loadout.ammo[name]
	if ammo.mag <= 0 then
		tryReload()
		return
	end
	ammo.mag -= 1

	shotIndex = Recoil.nextShotIndex(config.recoil, shotIndex, now - lastShotAny)
	lastShotAny = now
	lastShotAt[name] = now
	-- Keep the cadence exact when a shot lands a frame late.
	local due = nextShotAt[name] or 0
	nextShotAt[name] = (now - due < 0.05 and due or now) + config.fireInterval

	local spread = Spread.current(config.spread, WeaponConfig.Stance, bloom, deps.movement.getState(), scoped)
	local cameraCFrame = workspace.CurrentCamera.CFrame
	local origin = cameraCFrame.Position
	local direction = spreadDirection(cameraCFrame, spread)

	local result = cast(origin, direction, config.range)
	local endPosition = result and result.Position or origin + direction * config.range
	local hitPart = characterPart(result)

	Remotes.FireShot:FireServer(origin, endPosition, hitPart)

	deps.sounds.shot(config)
	Effects.tracer(deps.viewmodel.muzzlePosition(), endPosition)
	if result and not hitPart then
		Effects.impact(result.Position)
	end

	bloom = Spread.addShot(config.spread, bloom)
	local pitch, yaw = Recoil.kickFor(config.recoil, shotIndex)
	deps.camera.kick(pitch, yaw, config.recoil.recovery, math.min(config.fireInterval + 0.03, 0.25))
	deps.viewmodel.kick(0.5)

	if config.scope then
		setScoped(false)
	end
	refreshHud()
end

local function swingKnife(config, now)
	lastSwing = now
	deps.sounds.play("Swing")
	local cameraCFrame = workspace.CurrentCamera.CFrame
	local result = cast(cameraCFrame.Position, cameraCFrame.LookVector, config.reach)
	Remotes.MeleeSwing:FireServer(characterPart(result))
	deps.viewmodel.swing()
end

local function onDeath()
	setScoped(false)
	reloadEndsAt = nil
	deps.viewmodel.clear()
	deps.camera.reset()
	deps.movement.setSpeedScale(1)
	deps.objective.setPlanting(false)
	deps.hud.setCrosshair(1, false)
end

local function update(dt)
	local alive = isAlive()
	if wasAlive and not alive and loadout then
		onDeath()
	end
	wasAlive = alive

	if not alive or not loadout then
		triggerPressed = false
		return
	end

	local now = os.clock()
	local name, config = equippedWeapon()
	if not config then
		triggerPressed = false
		return
	end
	local ready = now >= equipReadyAt

	if reloadEndsAt and now >= reloadEndsAt then
		finishReload()
	end

	if config.kind == "Gun" then
		bloom = Spread.decay(config.spread, bloom, dt)

		local wantsScope = scopeHeld and config.scope ~= nil and ready and not reloadEndsAt
		if wantsScope ~= scoped then
			setScoped(wantsScope)
		end

		local wantsFire = (config.automatic and triggerHeld) or triggerPressed
		if wantsFire and ready and not reloadEndsAt and now >= (nextShotAt[name] or 0) then
			fireGun(name, config, now)
		end

		local spread = Spread.current(config.spread, WeaponConfig.Stance, bloom, deps.movement.getState(), scoped)
		deps.hud.setCrosshair(spread, not scoped)
	elseif config.kind == "Melee" then
		if triggerHeld and ready and now - lastSwing >= config.swingInterval then
			swingKnife(config, now)
		end
		deps.hud.setCrosshair(0.4, true)
	elseif config.kind == "Grenade" then
		if triggerPressed and ready then
			throwGrenade()
		end
		deps.hud.setCrosshair(0.4, true)
	elseif config.kind == "Bomb" then
		-- Holding fire with the bomb out asks the server to plant.
		deps.objective.setPlanting(triggerHeld and ready)
		deps.hud.setCrosshair(0.4, true)
	end

	triggerPressed = false
end

local function onLoadout(payload)
	local previousSlot = loadout and loadout.equipped
	loadout = payload
	stats = Loadout.stats(ArmorConfig, payload.loadout)
	deps.footsteps.setHearing(stats.hearing)

	if payload.notice then
		deps.hud.addFeedLine(payload.notice) -- such as what changing weapons just cost
	end

	if payload.reset or not previousSlot then
		-- New life: start clean and draw the primary.
		lastSlot = nil
		nextShotAt, lastShotAt = {}, {}
		lastShotAny, lastSwing = -math.huge, -math.huge
		scopeHeld, triggerHeld, triggerPressed = false, false, false
		deps.controls.release("Fire")
		deps.controls.release("Scope") -- on a touch screen aiming is a switch, and a new life starts with it off
		equip(payload.equipped, false)
	else
		-- Mid-life update (reload finished, ammo corrected, something picked up,
		-- dropped or thrown): keep our own slot unless what was in it is gone.
		loadout.equipped = previousSlot
		if not loadout.slots[previousSlot] then
			equip(Loadout.fallbackSlot(loadout.slots), false)
		end
		refreshHud()
	end
end

-- Connects each action to what it does. An action only does anything while
-- the player is alive and has a loadout.
local function bindActions()
	local controls = deps.controls
	local function whenAlive(action, run)
		controls.on(action, function(down)
			if down and loadout and isAlive() then
				run()
			end
		end)
	end

	controls.on("Fire", function(down)
		triggerHeld = down
		if down then
			triggerPressed = true
		end
	end)
	controls.on("Scope", function(down)
		scopeHeld = down
	end)
	whenAlive("Reload", tryReload)
	whenAlive("Tactical", useTactical)
	whenAlive("QuickSwitch", quickSwitch)
	whenAlive("NextWeapon", function()
		cycleSlot(1)
	end)
	whenAlive("Drop", function()
		Remotes.DropWeapon:FireServer() -- the server answers with what we have left
	end)
	for key = 1, NUMBER_KEYS do
		whenAlive("Slot" .. key, function()
			local slot = Loadout.slotForKey(loadout.slots, loadout.equipped, key)
			if slot then
				equip(slot, true)
			end
		end)
	end
end

local function onInputChanged(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseWheel then
		return
	end
	if loadout and isAlive() then
		cycleSlot(input.Position.Z > 0 and -1 or 1)
	end
end

-- `shooter` is a player, or on the test range the dummy that fired.
local function onShotFired(shooter, origin, endPosition)
	local from = origin
	local character = shooter and (if shooter:IsA("Player") then shooter.Character else shooter)
	local held = character and character:FindFirstChild("HeldWeapon")
	if held and held.PrimaryPart then
		from = held.PrimaryPart.Position
	end
	Effects.tracer(from, endPosition)
end

-- Being hit throws the aim upward a little. The server sends 0 while a Cryo
-- Shot is active.
local function onDamaged(_amount, _position, flinch)
	if flinch and flinch > 0 and isAlive() then
		deps.camera.flinch(flinch, (math.random() - 0.5) * flinch)
	end
end

local function onExplosion(position, radius, knockback)
	Effects.explosion(position, radius)

	-- Our own character is simulated here, so the push has to be applied here.
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and isAlive() then
		local offset = root.Position - position
		local distance = offset.Magnitude
		if distance < radius and distance > 0.01 then
			local strength = knockback * (1 - distance / radius) * root.AssemblyMass
			root:ApplyImpulse((offset.Unit + Vector3.new(0, 0.5, 0)) * strength)
		end
	end
end

function WeaponController.start(dependencies)
	deps = dependencies

	Remotes.LoadoutUpdate.OnClientEvent:Connect(onLoadout)
	Remotes.ShotFired.OnClientEvent:Connect(onShotFired)
	Remotes.Damaged.OnClientEvent:Connect(onDamaged)
	Remotes.Explosion.OnClientEvent:Connect(onExplosion)

	bindActions()
	UserInputService.InputChanged:Connect(onInputChanged) -- the mouse wheel

	RunService:BindToRenderStep("TdmWeapons", Enum.RenderPriority.Camera.Value + 2, update)
end

return WeaponController
