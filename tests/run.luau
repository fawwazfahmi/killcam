-- Unit tests for the pure game rules. Run outside Studio with:  lune run tests/run

local process = require("@lune/process")

local WeaponConfig = require("../src/shared/Config/WeaponConfig")
local MovementConfig = require("../src/shared/Config/MovementConfig")
local MatchConfig = require("../src/shared/Config/MatchConfig")
local Recoil = require("../src/shared/Logic/Recoil")
local Spread = require("../src/shared/Logic/Spread")
local Damage = require("../src/shared/Logic/Damage")
local MoveSmoothing = require("../src/shared/Logic/MoveSmoothing")
local HitValidation = require("../src/shared/Logic/HitValidation")
local SpawnSelection = require("../src/shared/Logic/SpawnSelection")
local MatchState = require("../src/shared/Logic/MatchState")
local BombRound = require("../src/shared/Logic/BombRound")
local ArmorConfig = require("../src/shared/Config/ArmorConfig")
local TacticalConfig = require("../src/shared/Config/TacticalConfig")
local Loadout = require("../src/shared/Logic/Loadout")
local Flash = require("../src/shared/Logic/Flash")
local Carve = require("../src/shared/Logic/Carve")
local ShopConfig = require("../src/shared/Config/ShopConfig")
local Economy = require("../src/shared/Logic/Economy")
local LobbyConfig = require("../src/shared/Config/LobbyConfig")
local Queue = require("../src/shared/Logic/Queue")
local Podium = require("../src/shared/Logic/Podium")
local Score = require("../src/shared/Logic/Score")
local Pose = require("../src/shared/Logic/Pose")
local Catalog = require("../src/shared/Logic/Catalog")
local Revive = require("../src/shared/Logic/Revive")
local Ammo = require("../src/shared/Logic/Ammo")
local Spectate = require("../src/shared/Logic/Spectate")
local Icons = require("../src/shared/Config/Icons")
local Backfill = require("../src/shared/Logic/Backfill")
local ProgressConfig = require("../src/shared/Config/ProgressConfig")
local Rank = require("../src/shared/Logic/Rank")
local Prestige = require("../src/shared/Logic/Prestige")
local Squad = require("../src/shared/Logic/Squad")
local Session = require("../src/shared/Logic/Session")
local ControlsConfig = require("../src/shared/Config/ControlsConfig")
local SoundConfig = require("../src/shared/Config/SoundConfig")

local Weapons = WeaponConfig.Weapons
local Validation = WeaponConfig.Validation

local passed, failed = 0, 0

local function test(name, body)
	local ok, message = pcall(body)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name)
		print("      " .. tostring(message))
	end
end

local function equal(actual, expected, what)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", what, tostring(expected), tostring(actual)), 2)
	end
end

local function near(actual, expected, tolerance, what)
	if math.abs(actual - expected) > tolerance then
		error(string.format("%s: expected about %s, got %s", what, tostring(expected), tostring(actual)), 2)
	end
end

local function v(x, y, z)
	return { X = x, Y = y, Z = z }
end

local function with(base, overrides)
	local copy = table.clone(base)
	for key, value in overrides do
		copy[key] = value
	end
	return copy
end

---------------------------------------------------------------- Recoil

test("recoil follows the pattern in order", function()
	local recoil = Weapons.M16.recoil
	for index, kick in recoil.pattern do
		local pitch, yaw = Recoil.kickFor(recoil, index)
		equal(pitch, kick[1], "pitch of shot " .. index)
		equal(yaw, kick[2], "yaw of shot " .. index)
	end
end)

test("recoil loops from loopFrom after the pattern ends", function()
	local recoil = Weapons.M16.recoil
	local count = #recoil.pattern
	local span = count - recoil.loopFrom + 1
	equal(Recoil.kickFor(recoil, count + 1), recoil.pattern[recoil.loopFrom][1], "first looped shot")
	equal(Recoil.kickFor(recoil, count + 2), recoil.pattern[recoil.loopFrom + 1][1], "second looped shot")
	equal(Recoil.kickFor(recoil, count + span + 1), recoil.pattern[recoil.loopFrom][1], "second lap")
end)

test("recoil burst resets after a pause", function()
	local recoil = Weapons.M16.recoil
	equal(Recoil.nextShotIndex(recoil, 5, 0.1), 6, "sustained fire")
	equal(Recoil.nextShotIndex(recoil, 5, recoil.resetTime + 0.01), 1, "after a pause")
	equal(Recoil.nextShotIndex(recoil, 0, math.huge), 1, "first shot ever")
end)

test("the view never keeps climbing once firing stops", function()
	local recoil = Weapons.M16.recoil
	local rate = recoil.recovery
	local delay = math.min(Weapons.M16.fireInterval + 0.03, 0.25)
	local frame = 1 / 60

	-- Hold the trigger for a mag's worth, applying each kick as the camera does.
	local pitch, yaw, index, sinceShot = 0, 0, 0, 0
	local history = {}
	for shot = 1, 20 do
		index = Recoil.nextShotIndex(recoil, index, Weapons.M16.fireInterval)
		local kickPitch, kickYaw = Recoil.kickFor(recoil, index)
		pitch, yaw = pitch + kickPitch, yaw + kickYaw
		sinceShot = 0
		-- The frames between this shot and the next.
		for _ = 1, math.floor(Weapons.M16.fireInterval / frame) do
			sinceShot += frame
			if sinceShot > delay then
				pitch, yaw = Recoil.settle(rate, pitch, yaw, frame)
			end
			table.insert(history, math.sqrt(pitch * pitch + yaw * yaw))
		end
	end
	local atRelease = math.sqrt(pitch * pitch + yaw * yaw)
	equal(atRelease > 0, true, "the burst moved the view")

	-- Let go. From here the view may hold, then come back, but never rise.
	local highest = atRelease
	for _ = 1, 180 do
		sinceShot += frame
		if sinceShot > delay then
			pitch, yaw = Recoil.settle(rate, pitch, yaw, frame)
		end
		local magnitude = math.sqrt(pitch * pitch + yaw * yaw)
		equal(magnitude <= highest + 1e-9, true, "the view rose after the last shot")
		highest = math.max(highest, magnitude)
	end
	equal(pitch, 0, "and it comes all the way back")
	equal(yaw, 0, "on both axes")
end)

test("settling returns the view the way it came, and stops at zero", function()
	local pitch, yaw = Recoil.settle(10, 3, 4, 0.1) -- magnitude 5, so one degree comes off
	near(math.sqrt(pitch * pitch + yaw * yaw), 4, 1e-9, "a degree per tenth of a second")
	near(pitch / yaw, 3 / 4, 1e-9, "straight back along the same line")

	equal(select(1, Recoil.settle(10, 1, 0, 1)), 0, "a long frame does not overshoot")
	equal(select(2, Recoil.settle(10, 0, 1, 1)), 0, "on either axis")
	local stillPitch, stillYaw = Recoil.settle(10, 0, 0, 0.1)
	equal(stillPitch, 0, "nothing to settle")
	equal(stillYaw, 0, "on either axis")
end)

---------------------------------------------------------------- Spread

local STILL = { moving = false, crouched = false, airborne = false }
local MOVING = { moving = true, crouched = false, airborne = false }
local CROUCHED = { moving = false, crouched = true, airborne = false }
local AIRBORNE = { moving = true, crouched = false, airborne = true }

test("spread stance factors", function()
	local stance = WeaponConfig.Stance
	equal(Spread.stanceFactor(stance, STILL), 1.0, "still")
	equal(Spread.stanceFactor(stance, MOVING), 1.6, "moving")
	equal(Spread.stanceFactor(stance, CROUCHED), 0.7, "crouched")
	equal(Spread.stanceFactor(stance, AIRBORNE), 3.0, "airborne")
end)

test("bloom grows per shot, caps and decays to zero", function()
	local spread = Weapons.M16.spread
	local bloom = 0
	bloom = Spread.addShot(spread, bloom)
	near(bloom, spread.bloomPerShot, 1e-9, "one shot")
	for _ = 1, 100 do
		bloom = Spread.addShot(spread, bloom)
	end
	equal(bloom, spread.maxBloom, "cap")
	near(Spread.decay(spread, bloom, 0.1), spread.maxBloom - spread.recovery * 0.1, 1e-9, "partial decay")
	equal(Spread.decay(spread, bloom, 100), 0, "full decay")
end)

test("current spread combines base, bloom and stance", function()
	local spread = Weapons.M16.spread
	near(Spread.current(spread, WeaponConfig.Stance, 1, MOVING, false), (spread.base + 1) * 1.6, 1e-9, "rifle moving")
end)

test("sniper is exact only when scoped and still", function()
	local spread = Weapons.MSR.spread
	local stance = WeaponConfig.Stance
	equal(Spread.current(spread, stance, 0, STILL, true), 0, "scoped and still")
	equal(Spread.current(spread, stance, 0, CROUCHED, true), 0, "scoped and crouched")
	equal(Spread.current(spread, stance, 0, STILL, false), spread.base, "unscoped")
	if Spread.current(spread, stance, 0, MOVING, true) <= 0 then
		error("scoped while moving should not be exact")
	end
end)

---------------------------------------------------------------- Damage

local function shotsToKill(weapon, zone)
	return math.ceil(MatchConfig.maxHealth / Damage.gun(weapon, zone))
end

test("damage zones from part names", function()
	equal(Damage.zoneForPart("Head"), "Head", "head")
	equal(Damage.zoneForPart("UpperTorso"), "UpperTorso", "upper torso")
	equal(Damage.zoneForPart("LowerTorso"), "LowerTorso", "lower torso")
	equal(Damage.zoneForPart("LeftFoot"), "Limb", "foot")
	equal(Damage.zoneForPart("RightUpperArm"), "Limb", "arm")
end)

test("rifle kills in 1 headshot or 4 body shots", function()
	equal(shotsToKill(Weapons.M16, "Head"), 1, "head")
	equal(shotsToKill(Weapons.M16, "UpperTorso"), 4, "upper torso")
	equal(shotsToKill(Weapons.M16, "LowerTorso"), 4, "lower torso")
	equal(Damage.gun(Weapons.M16, "Limb"), 21, "limb")
end)

test("pistol kills in 2 headshots or 5 body shots", function()
	equal(shotsToKill(Weapons.P2020, "Head"), 2, "head")
	equal(shotsToKill(Weapons.P2020, "UpperTorso"), 5, "body")
end)

test("sniper kills from the chest up only", function()
	equal(shotsToKill(Weapons.MSR, "Head"), 1, "head")
	equal(shotsToKill(Weapons.MSR, "UpperTorso"), 1, "upper torso")
	equal(shotsToKill(Weapons.MSR, "LowerTorso"), 2, "lower torso: not in one")
	equal(shotsToKill(Weapons.MSR, "Limb"), 2, "limb: not in one")
end)

test("knife backstab cone", function()
	local knife = Weapons.CombatKnife
	local target, look = v(0, 0, 0), v(0, 0, -1) -- target faces -Z, so its back is toward +Z
	equal(Damage.knife(knife, v(0, 0, 5), target, look), knife.backDamage, "directly behind")
	equal(Damage.knife(knife, v(0, 0, -5), target, look), knife.frontDamage, "in front")
	equal(Damage.knife(knife, v(5, 0, 0), target, look), knife.frontDamage, "from the side")

	local function at(degreesFromBehind)
		local angle = math.rad(degreesFromBehind)
		return v(math.sin(angle) * 5, 0, math.cos(angle) * 5)
	end
	equal(Damage.knife(knife, at(55), target, look), knife.backDamage, "55 degrees off the back")
	equal(Damage.knife(knife, at(65), target, look), knife.frontDamage, "65 degrees off the back")
end)

test("grenade damage falls off linearly", function()
	local grenade = Weapons.Frag
	equal(Damage.grenade(grenade, 0), grenade.maxDamage, "centre")
	near(Damage.grenade(grenade, grenade.radius / 2), grenade.maxDamage / 2, 1e-9, "half radius")
	equal(Damage.grenade(grenade, grenade.radius), 0, "edge")
	equal(Damage.grenade(grenade, grenade.radius + 5), 0, "outside")
end)

---------------------------------------------------------------- MoveSmoothing

local function simulate(x, z, tx, tz, seconds, airborne)
	local dt = 0.005
	for _ = 1, math.floor(seconds / dt + 0.5) do
		x, z = MoveSmoothing.step(MovementConfig, x, z, tx, tz, dt, airborne)
	end
	return x, z
end

test("reaches full speed in accelTime", function()
	near(simulate(0, 0, 1, 0, MovementConfig.accelTime / 2, false), 0.5, 0.05, "halfway")
	equal(simulate(0, 0, 1, 0, MovementConfig.accelTime + 0.01, false), 1, "full speed")
end)

test("stops in stopTime", function()
	near(simulate(1, 0, 0, 0, MovementConfig.stopTime / 2, false), 0.5, 0.05, "halfway")
	equal(simulate(1, 0, 0, 0, MovementConfig.stopTime + 0.01, false), 0, "stopped")
end)

test("air steering is reduced", function()
	local x = simulate(0, 0, 1, 0, MovementConfig.accelTime, true)
	near(x, MovementConfig.airControl, 0.03, "input reached in the air")
end)

test("landing slows only briefly and only after real air time", function()
	local config = MovementConfig
	equal(MoveSmoothing.landingFactor(config, 0.5, 0.1), config.landingSpeedFactor, "just landed")
	equal(MoveSmoothing.landingFactor(config, 0.5, config.landingDuration + 0.05), 1, "recovered")
	equal(MoveSmoothing.landingFactor(config, 0.1, 0.05), 1, "tiny hop")
end)

---------------------------------------------------------------- HitValidation

local SHOT = {
	now = 10,
	ammo = 5,
	reloading = false,
	equippedAt = 0,
	equipTime = 0.35,
	nextShotAt = 9,
	lastShotAt = 8.9,
	fireInterval = 0.1,
	reEquipped = false,
	origin = v(0, 5, 0),
	shooterHead = v(0, 5, 0),
}

local function fireReason(overrides)
	local ok, reason = HitValidation.canFire(Validation, with(SHOT, overrides))
	return ok and "ok" or reason
end

test("canFire accepts a normal shot", function()
	equal(fireReason({}), "ok", "result")
end)

test("canFire rejects each broken rule", function()
	equal(fireReason({ reloading = true }), "Reloading", "reloading")
	equal(fireReason({ ammo = 0 }), "NoAmmo", "empty magazine")
	equal(fireReason({ equippedAt = 9.9 }), "Equipping", "still drawing")
	equal(fireReason({ nextShotAt = 10.2 }), "TooFast", "too fast")
	equal(fireReason({ origin = v(20, 5, 0) }), "BadOrigin", "origin far from head")
end)

test("canFire tolerates a shot arriving slightly early", function()
	equal(fireReason({ nextShotAt = 10.04 }), "ok", "40 ms early")
end)

test("sniper quick-switch shortens the wait but not below its interval", function()
	local sniper = { fireInterval = 1.2, quickSwitchInterval = 0.7, nextShotAt = 10.4, equippedAt = 9.6 }
	equal(fireReason(with(sniper, { lastShotAt = 9.2, reEquipped = true })), "ok", "0.8 s after, re-equipped")
	equal(fireReason(with(sniper, { lastShotAt = 9.2, reEquipped = false })), "TooFast", "0.8 s after, not switched")
	equal(fireReason(with(sniper, { lastShotAt = 9.6, reEquipped = true })), "TooFast", "0.4 s after, re-equipped")
end)

test("advance keeps the average fire rate", function()
	near(HitValidation.advance(10, 9, 0.1), 10.1, 1e-9, "on time")
	near(HitValidation.advance(10, 10.04, 0.1), 10.14, 1e-9, "early shot does not bank time")
end)

local HIT = {
	targetAlive = true,
	sameTeam = false,
	protected = false,
	origin = v(0, 5, 0),
	hitPosition = v(50, 5, 0),
	targetPosition = v(51, 5, 0),
	range = 600,
	blocked = false,
}

local function hitReason(overrides)
	local ok, reason = HitValidation.validateHit(Validation, with(HIT, overrides))
	return ok and "ok" or reason
end

test("validateHit accepts a clean hit", function()
	equal(hitReason({}), "ok", "result")
end)

test("validateHit rejects each broken rule", function()
	equal(hitReason({ targetAlive = false }), "TargetDead", "dead target")
	equal(hitReason({ sameTeam = true }), "SameTeam", "teammate")
	equal(hitReason({ protected = true }), "Protected", "spawn protection")
	equal(hitReason({ range = 40 }), "OutOfRange", "beyond range")
	equal(hitReason({ targetPosition = v(80, 5, 0) }), "TargetMismatch", "target not where claimed")
	equal(hitReason({ blocked = true }), "Blocked", "wall in the way")
end)

---------------------------------------------------------------- SpawnSelection

test("spawn selection avoids enemies", function()
	local spawns = { v(0, 0, 0), v(100, 0, 0), v(50, 0, 0) }
	local function never()
		error("random should not be used when enemies exist")
	end
	equal(SpawnSelection.pick(spawns, { v(90, 0, 0) }, never), 1, "one enemy")
	equal(SpawnSelection.pick(spawns, { v(0, 0, 0), v(40, 0, 0) }, never), 2, "two enemies")
end)

test("spawn selection is random with no enemies, nil with no spawns", function()
	local spawns = { v(0, 0, 0), v(100, 0, 0) }
	equal(SpawnSelection.pick(spawns, {}, function(count)
		equal(count, 2, "count passed to random")
		return 2
	end), 2, "random pick")
	equal(SpawnSelection.pick({}, {}, math.random), nil, "no spawns")
end)

---------------------------------------------------------------- MatchState

local function playing()
	local state = MatchState.new(MatchConfig)
	MatchState.tick(MatchConfig, state, 0, MatchConfig.minPlayers)
	return state
end

test("match waits for enough players, then starts", function()
	local state = MatchState.new(MatchConfig)
	equal(state.phase, "Waiting", "initial phase")
	equal(MatchState.tick(MatchConfig, state, 1, MatchConfig.minPlayers - 1), nil, "too few players")
	equal(MatchState.tick(MatchConfig, state, 1, MatchConfig.minPlayers), "Started", "enough players")
	equal(state.phase, "Playing", "phase")
	equal(state.timeLeft, MatchConfig.timeLimit, "clock")
end)

test("kills only count while playing", function()
	local state = MatchState.new(MatchConfig)
	equal(MatchState.addKill(MatchConfig, state, "Alpha"), false, "while waiting")
	state = playing()
	equal(MatchState.addKill(MatchConfig, state, "Alpha"), true, "while playing")
	equal(state.scores.Alpha, 1, "score")
	equal(MatchState.addKill(MatchConfig, state, "Nobody"), false, "unknown team")
end)

test("score limit ends the match and later kills do not count", function()
	local state = playing()
	for _ = 1, MatchConfig.scoreLimit do
		MatchState.addKill(MatchConfig, state, "Bravo")
	end
	equal(state.phase, "Ended", "phase")
	equal(state.winner, "Bravo", "winner")
	equal(MatchState.addKill(MatchConfig, state, "Alpha"), false, "kill after the end")
	equal(state.scores.Alpha, 0, "score unchanged")
end)

test("time limit ends the match for the leader, or as a draw", function()
	local state = playing()
	MatchState.addKill(MatchConfig, state, "Alpha")
	equal(MatchState.tick(MatchConfig, state, MatchConfig.timeLimit, 2), "Ended", "event")
	equal(state.winner, "Alpha", "leader wins")

	state = playing()
	MatchState.tick(MatchConfig, state, MatchConfig.timeLimit, 2)
	equal(state.winner, "Draw", "equal scores")
end)

test("result screen times out into a fresh match", function()
	local state = playing()
	MatchState.addKill(MatchConfig, state, "Alpha")
	MatchState.tick(MatchConfig, state, MatchConfig.timeLimit, 2)
	equal(MatchState.tick(MatchConfig, state, MatchConfig.endDuration - 1, 2), nil, "still showing result")
	equal(MatchState.tick(MatchConfig, state, 1, 2), "Reset", "result finished")
	equal(state.phase, "Waiting", "phase")
	equal(state.scores.Alpha, 0, "scores cleared")
	equal(MatchState.tick(MatchConfig, state, 0, 2), "Started", "next match")
end)

test("match returns to waiting when players drop out", function()
	local state = playing()
	MatchState.addKill(MatchConfig, state, "Alpha")
	equal(MatchState.tick(MatchConfig, state, 1, MatchConfig.minPlayers - 1), "Reset", "event")
	equal(state.phase, "Waiting", "phase")
	equal(state.scores.Alpha, 0, "scores cleared")
end)

----------------------------------------------------------------

test("free-for-all: each player is a side, and the first to the limit wins", function()
	local rules = { teams = {}, minPlayers = 2, endDuration = 8, scoreLimit = 3, timeLimit = 60 }
	local state = MatchState.new(rules)
	MatchState.join(state, "Ann")
	MatchState.join(state, "Bo")
	equal(MatchState.tick(rules, state, 0, 2), "Started", "starts")
	equal(MatchState.addKill(rules, state, "Cy"), false, "someone who never joined")
	MatchState.join(state, "Cy")
	equal(state.scores.Cy, 0, "a late joiner starts on zero")
	MatchState.addKill(rules, state, "Bo")
	MatchState.join(state, "Bo")
	equal(state.scores.Bo, 1, "joining again keeps the score")
	MatchState.leave(state, "Cy")
	equal(state.scores.Cy, nil, "leaving removes the side")
	MatchState.addKill(rules, state, "Bo")
	MatchState.addKill(rules, state, "Bo")
	equal(state.phase, "Ended", "limit reached")
	equal(state.winner, "Bo", "winner")
end)

test("free-for-all: time running out goes to the leader, and a new match clears scores", function()
	local rules = { teams = {}, minPlayers = 2, endDuration = 8, scoreLimit = 30, timeLimit = 60 }
	local state = MatchState.new(rules)
	MatchState.join(state, "Ann")
	MatchState.join(state, "Bo")
	MatchState.tick(rules, state, 0, 2)
	MatchState.addKill(rules, state, "Ann")
	equal(MatchState.tick(rules, state, 60, 2), "Ended", "time up")
	equal(state.winner, "Ann", "leader wins")
	MatchState.tick(rules, state, 8, 2)
	equal(state.scores.Ann, 0, "scores cleared for the next match")
	equal(state.scores.Bo, 0, "for everyone")
end)

---------------------------------------------------------------- Loadout

local function loadoutWith(overrides)
	return with(Loadout.default(WeaponConfig, TacticalConfig, ArmorConfig), overrides or {})
end

local function statsWith(overrides)
	return Loadout.stats(ArmorConfig, loadoutWith(overrides))
end

test("every option in the configs is complete", function()
	for _, slot in ArmorConfig.slots do
		equal(ArmorConfig[slot][ArmorConfig.defaults[slot]] ~= nil, true, slot .. " default exists")
		equal(ArmorConfig.titles[slot] ~= nil, true, slot .. " has a title")
		local listed = 0
		for _, name in ArmorConfig.order[slot] do
			listed += 1
			local piece = ArmorConfig[slot][name]
			equal(piece ~= nil, true, slot .. "." .. name .. " exists")
			equal(type(piece.displayName), "string", slot .. "." .. name .. " name")
			equal(type(piece.note), "string", slot .. "." .. name .. " note")
		end
		local defined = 0
		for _ in ArmorConfig[slot] do
			defined += 1
		end
		equal(listed, defined, slot .. ": every piece is in the menu order")
	end
	for _, name in TacticalConfig.order do
		equal(TacticalConfig.items[name].uses > 0, true, name .. " has uses")
	end
	for _, name in WeaponConfig.NadeOrder do
		equal(WeaponConfig.Nades[name], true, name .. " is a grenade")
		equal(Weapons[name].kind, "Grenade", name .. " kind")
		equal(type(Weapons[name].effect), "string", name .. " effect")
	end
	for name in WeaponConfig.Primaries do
		equal(Weapons[name].kind, "Gun", name .. " is a gun")
	end
end)

test("a loadout from a client is checked field by field", function()
	local good = loadoutWith()
	local clean = Loadout.sanitize(WeaponConfig, TacticalConfig, ArmorConfig, good)
	equal(clean ~= nil and clean ~= good, true, "a valid loadout comes back as a copy")
	equal(clean.primary, good.primary, "primary kept")

	local function rejected(choice)
		return Loadout.sanitize(WeaponConfig, TacticalConfig, ArmorConfig, choice) == nil
	end
	equal(rejected(nil), true, "nothing")
	equal(rejected("Rifle"), true, "not a table")
	equal(rejected(loadoutWith({ primary = "CombatKnife" })), true, "a primary that is not one")
	equal(rejected(loadoutWith({ nade = "M16" })), true, "a grenade that is not one")
	equal(rejected(loadoutWith({ tactical = "Frag" })), true, "an unknown tactical item")
	equal(rejected(loadoutWith({ helmet = "Plate" })), true, "a piece from the wrong slot")
	equal(rejected(loadoutWith({ boots = 7 })), true, "a wrong type")
	local extra = loadoutWith({ cheat = true })
	equal(Loadout.sanitize(WeaponConfig, TacticalConfig, ArmorConfig, extra).cheat, nil, "extra fields are dropped")
end)

test("the helmet covers headshots and body armour covers the rest, by weapon class", function()
	local guard = statsWith({ helmet = "Guard", body = "Light" })
	local rifle, sniper = Weapons.M16, Weapons.MSR
	near(Loadout.damage(guard, "Rifle", "Head", rifle.damage.Head), rifle.damage.Head * 0.5, 1e-9, "guarded head")
	equal(Loadout.damage(guard, "Rifle", "UpperTorso", 28), 28, "no body armour")
	equal(Loadout.damage(guard, "Sniper", "Head", sniper.damage.Head) >= MatchConfig.maxHealth, true, "a sniper headshot still kills")

	local plate = statsWith({ helmet = "Listener", body = "Plate" })
	equal(Loadout.damage(plate, "Rifle", "Head", 112), 112, "no helmet protection")
	near(Loadout.damage(plate, "Rifle", "UpperTorso", 28), 21, 1e-9, "plate against a rifle")
	near(Loadout.damage(plate, "Handgun", "Limb", 16), 12, 1e-9, "plate against a handgun")
	equal(Loadout.damage(plate, "Sniper", "UpperTorso", 100), 100, "plate does nothing against a sniper")
	equal(Loadout.damage(plate, "Melee", "UpperTorso", 55), 55, "nor a knife")

	local deflector = statsWith({ body = "Deflector" })
	equal(Loadout.damage(deflector, "Sniper", "UpperTorso", sniper.damage.UpperTorso) < MatchConfig.maxHealth, true,
		"a sniper body shot no longer kills")
	equal(Loadout.damage(deflector, "Rifle", "UpperTorso", 28), 28, "deflector does nothing against a rifle")
end)

test("speed, draw time, tactical wind-up, footsteps and falls follow the pieces worn", function()
	local base = statsWith({ body = "Plate", gloves = "Gunner", boots = "Cushion", helmet = "Guard" })
	equal(Loadout.speedScale(base, "Rifle"), 1, "nothing worn changes speed")
	equal(base.equipScale, 1, "draw time")
	equal(base.tacticalScale, 1, "tactical wind-up")
	equal(base.footsteps, 1, "footsteps")
	equal(base.hearing, 1, "hearing")
	equal(base.fallScale < 1, true, "cushion boots soften falls")

	local light = statsWith({ body = "Light", boots = "Runner" })
	near(Loadout.speedScale(light, "Rifle"), 1.08, 1e-9, "light armour alone")
	near(Loadout.speedScale(light, "Melee"), 1.08 * 1.12, 1e-9, "stacks with runner boots, knife out")
	local marcher = statsWith({ boots = "Marcher" })
	equal(Loadout.speedScale(marcher, "Sniper") > 1, true, "marcher boots with a sniper")
	equal(Loadout.speedScale(marcher, "Melee"), 1, "but not with the knife")

	equal(statsWith({ gloves = "Quick" }).equipScale < 1, true, "quick gloves")
	equal(statsWith({ gloves = "Trigger" }).tacticalScale, 0, "trigger gloves make it instant")
	equal(statsWith({ boots = "Soft" }).footsteps < 1, true, "soft boots")
	equal(statsWith({ helmet = "Listener" }).hearing > 1, true, "listener helmet")
end)

-- Slots, in order: primary, secondary, melee, grenade, bomb, second primary, second grenade.
local function held(primary, secondary, melee, nade, primary2, nade2)
	return { primary or false, secondary or false, melee or false, nade or false, false, primary2 or false, nade2 or false }
end

local function slotsOf(loadout)
	return Loadout.slots(WeaponConfig, loadout, Loadout.stats(ArmorConfig, loadout))
end

test("one of each at spawn: primary, handgun, knife, grenade, and no bomb", function()
	local slots = slotsOf(loadoutWith({ primary = "MSR", nade = "Smoke", gloves = "Quick" }))
	equal(#slots, Loadout.SLOT_COUNT, "always seven entries")
	equal(slots[Loadout.PRIMARY], "MSR", "slot 1")
	equal(slots[Loadout.SECONDARY], "P2020", "slot 2")
	equal(slots[Loadout.MELEE], "CombatKnife", "slot 3")
	equal(slots[Loadout.NADE], "Smoke", "slot 4")
	equal(slots[Loadout.BOMB], false, "slot 5 is empty, not missing")
	equal(slots[Loadout.PRIMARY2], false, "no second primary")
	equal(slots[Loadout.NADE2], false, "no second grenade")
end)

test("a second primary or grenade is carried only with the gloves for it", function()
	local picks = { primary = "M16", primary2 = "MSR", nade = "Frag", nade2 = "Smoke" }

	local plain = slotsOf(loadoutWith(with(picks, { gloves = "Quick" })))
	equal(plain[Loadout.PRIMARY2], false, "picked, but not carried without the gloves")
	equal(plain[Loadout.NADE2], false, "nor the second grenade")

	local gunner = slotsOf(loadoutWith(with(picks, { gloves = "Gunner" })))
	equal(gunner[Loadout.PRIMARY2], "MSR", "gunner gloves carry the second primary")
	equal(gunner[Loadout.SECONDARY], "P2020", "and the handgun is kept")
	equal(gunner[Loadout.NADE2], false, "but not a second grenade")

	local grenadier = slotsOf(loadoutWith(with(picks, { gloves = "Grenadier" })))
	equal(grenadier[Loadout.NADE2], "Smoke", "grenadier gloves carry the second grenade")
	equal(grenadier[Loadout.PRIMARY2], false, "but not a second primary")

	-- Never two of the same, however the loadout arrives.
	local same = with(loadoutWith({ gloves = "Gunner" }), { primary = "M16", primary2 = "M16" })
	equal(slotsOf(same)[Loadout.PRIMARY2], false, "the same gun twice is one gun")
	local clean = Loadout.sanitize(WeaponConfig, TacticalConfig, ArmorConfig, same)
	equal(clean.primary2, nil, "and is dropped when a loadout is checked")

	local sent = loadoutWith(with(picks, { gloves = "Gunner" }))
	clean = Loadout.sanitize(WeaponConfig, TacticalConfig, ArmorConfig, sent)
	equal(clean.primary2, "MSR", "a real second primary is kept")
	equal(clean.nade2, "Smoke", "and a real second grenade")
	equal(Loadout.sanitize(WeaponConfig, TacticalConfig, ArmorConfig, with(sent, { primary2 = "P2020" })), nil, "a handgun is not a primary")
	equal(Loadout.sanitize(WeaponConfig, TacticalConfig, ArmorConfig, with(sent, { nade2 = 4 })), nil, "nor is a number a grenade")

	local carried = Loadout.carried(sent, Loadout.stats(ArmorConfig, sent))
	equal(carried.primary2, "MSR", "what is carried keeps what the gloves allow")
	equal(carried.nade2, nil, "and leaves out what they do not")
	equal(sent.nade2, "Smoke", "without touching the loadout it was given")
end)

test("a number key steps through its own slots, and goes to its first from anywhere else", function()
	local both = held("M16", "P2020", "CombatKnife", "Frag", "MSR", "Smoke")
	local function key(slots, equipped, number)
		return Loadout.slotForKey(slots, equipped, number)
	end

	equal(key(both, Loadout.SECONDARY, 1), Loadout.PRIMARY, "1 from the handgun: the primary")
	equal(key(both, Loadout.PRIMARY, 1), Loadout.PRIMARY2, "1 again: the second primary")
	equal(key(both, Loadout.PRIMARY2, 1), Loadout.PRIMARY, "and again: back to the first")
	equal(key(both, Loadout.MELEE, 4), Loadout.NADE, "4 from the knife: the grenade")
	equal(key(both, Loadout.NADE, 4), Loadout.NADE2, "4 again: the second grenade")
	equal(key(both, Loadout.PRIMARY, 2), Loadout.SECONDARY, "2 is the handgun")
	equal(key(both, Loadout.SECONDARY, 2), nil, "pressing the key of what is in hand does nothing")
	equal(key(both, Loadout.PRIMARY, 5), nil, "5 with no bomb")
	equal(key(both, Loadout.PRIMARY, 9), nil, "a key with no slots")

	local one = held("M16", "P2020", "CombatKnife", "Frag")
	equal(key(one, Loadout.PRIMARY, 1), nil, "1 again with only one primary")

	-- The first primary was dropped, or the first grenade thrown.
	local second = held(nil, "P2020", "CombatKnife", nil, "MSR", "Smoke")
	equal(key(second, Loadout.SECONDARY, 1), Loadout.PRIMARY2, "1 finds the primary that is left")
	equal(key(second, Loadout.SECONDARY, 4), Loadout.NADE2, "4 finds the grenade that is left")
end)

test("the mouse wheel steps through everything carried, in key order", function()
	local both = held("M16", "P2020", "CombatKnife", "Frag", "MSR", "Smoke")
	local order = {}
	local slot = Loadout.PRIMARY
	for _ = 1, 6 do
		table.insert(order, both[slot])
		slot = Loadout.nextSlot(both, slot, 1)
	end
	equal(table.concat(order, " "), "M16 MSR P2020 CombatKnife Frag Smoke", "forwards")
	equal(slot, Loadout.PRIMARY, "and round to the start")
	equal(Loadout.nextSlot(both, Loadout.PRIMARY, -1), Loadout.NADE2, "backwards wraps to the end")
	equal(Loadout.nextSlot(held(nil, nil, "CombatKnife"), Loadout.MELEE, 1), Loadout.MELEE, "nothing else to step to")
end)

test("picking up, falling back and dropping on death", function()
	local plain = statsWith({ gloves = "Quick" })
	local gunner = statsWith({ gloves = "Gunner" })
	local function pickup(slots, stats, name)
		return Loadout.slotForPickup(WeaponConfig, slots, stats, name)
	end

	equal(pickup(held("M16", "P2020", "CombatKnife"), plain, "MSR"), nil, "hands full")
	equal(pickup(held(nil, "P2020", "CombatKnife"), plain, "MSR"), Loadout.PRIMARY, "primary into an empty slot 1")
	equal(pickup(held("M16", nil, "CombatKnife"), plain, "P2020"), Loadout.SECONDARY, "handgun into an empty slot 2")
	equal(pickup(held("M16", nil, "CombatKnife"), plain, "MSR"), nil, "one primary without the gloves, even with no handgun")
	equal(pickup(held("M16", "P2020", "CombatKnife"), gunner, "MSR"), Loadout.PRIMARY2, "a second primary with them")
	equal(pickup(held("M16", "P2020", "CombatKnife", nil, "MSR"), gunner, "MSR"), nil, "never two of the same gun")
	equal(pickup(held("M16", "P2020", "CombatKnife", nil, "MSR"), gunner, "M16"), nil, "and never three primaries")

	equal(Loadout.fallbackSlot(held(nil, "P2020", "CombatKnife")), Loadout.SECONDARY, "next thing held")
	equal(Loadout.fallbackSlot(held(nil, "P2020", "CombatKnife", nil, "MSR")), Loadout.PRIMARY2, "the second primary before the handgun")
	equal(Loadout.fallbackSlot(held(nil, nil, "CombatKnife")), Loadout.MELEE, "down to the knife")

	local function dropped(slots)
		return Loadout.deathDropSlot(WeaponConfig, slots)
	end
	equal(dropped(held("M16", "P2020", "CombatKnife", "Frag")), Loadout.PRIMARY, "the primary is the best gun")
	equal(dropped(held(nil, "P2020", "CombatKnife", "Frag", "MSR")), Loadout.PRIMARY2, "then the second primary")
	equal(dropped(held(nil, "P2020", "CombatKnife", "Frag")), Loadout.SECONDARY, "otherwise the handgun")
	equal(dropped(held(nil, nil, "CombatKnife", "Frag")), nil, "a knife is not dropped")
end)

test("fall damage starts above the safe speed and boots scale it", function()
	local fall = MovementConfig.fall
	equal(Damage.fall(fall, fall.safeSpeed - 5, 1), 0, "a short drop")
	equal(Damage.fall(fall, fall.safeSpeed, 1), 0, "exactly safe")
	near(Damage.fall(fall, fall.safeSpeed + 10, 1), 10 * fall.damagePerSpeed, 1e-9, "above safe")
	near(Damage.fall(fall, fall.safeSpeed + 10, 0.3), 3 * fall.damagePerSpeed, 1e-9, "with cushion boots")
	-- A normal jump must never hurt: v = sqrt(2 g h) at Roblox's default gravity.
	local jumpLanding = math.sqrt(2 * 196.2 * MovementConfig.jumpHeight)
	equal(Damage.fall(fall, jumpLanding, 1), 0, "landing from a jump")
end)

test("secondary and melee are loadout choices, checked like the rest", function()
	local defaults = loadoutWith()
	equal(defaults.secondary, WeaponConfig.DefaultSecondary, "default secondary")
	equal(defaults.melee, WeaponConfig.DefaultMelee, "default melee")
	local function rejected(choice)
		return Loadout.sanitize(WeaponConfig, TacticalConfig, ArmorConfig, choice) == nil
	end
	equal(rejected(loadoutWith({ secondary = "M16" })), true, "a primary is not a secondary")
	equal(rejected(loadoutWith({ melee = "P2020" })), true, "a handgun is not a melee weapon")
	equal(rejected(with(defaults, { secondary = false })), true, "a missing secondary")
	for _, list in { WeaponConfig.PrimaryOrder, WeaponConfig.SecondaryOrder, WeaponConfig.MeleeOrder } do
		for _, name in list do
			equal(Weapons[name] ~= nil, true, name .. " is a real weapon")
		end
	end
end)

test("during a match only the weapons of a loadout can change", function()
	for _, field in { "primary", "secondary", "melee", "nade" } do
		equal(Loadout.isWeaponField(field), true, field .. " is a weapon choice")
	end
	for _, field in { "tactical", "helmet", "body", "gloves", "boots" } do
		equal(Loadout.isWeaponField(field), false, field .. " is set in the lobby")
	end

	local current = loadoutWith({ primary = "M16", nade = "Frag", tactical = "Stim", boots = "Soft" })
	local wanted = loadoutWith({ primary = "MSR", nade = "Smoke", tactical = "Cryo", boots = "Runner", helmet = "Listener" })
	local merged = Loadout.withWeaponsFrom(current, wanted)
	equal(merged.primary, "MSR", "the primary changes")
	equal(merged.nade, "Smoke", "the grenade changes")
	equal(merged.tactical, "Stim", "the tactical item does not")
	equal(merged.boots, "Soft", "nor the boots")
	equal(merged.helmet, current.helmet, "nor the helmet")
	equal(current.primary, "M16", "the loadout passed in is left alone")
end)

---------------------------------------------------------------- Flash

test("a flashbang is harsh when looked at and brief when turned away", function()
	local config = Weapons.Flash
	local seconds = 3

	local facing = Flash.effect(config, seconds, 1)
	equal(facing.opacity, 1, "fully white looking straight at it")
	near(facing.duration, seconds, 1e-9, "for the whole time")
	near(facing.hold, seconds * config.holdShare, 1e-9, "and held before it fades")

	local away = Flash.effect(config, seconds, -1)
	near(away.opacity, config.awayOpacity, 1e-9, "only a partial wash with your back to it")
	near(away.duration, seconds * config.awayDuration, 1e-9, "and short")
	equal(away.hold, 0, "fading from the first moment")

	equal(Flash.effect(config, seconds, config.facingFull).opacity, 1, "the full effect starts at facingFull")
	near(Flash.effect(config, seconds, config.facingNone).duration, away.duration, 1e-9, "and bottoms out at facingNone")

	-- Turning away always helps, on every measure, with no sudden steps.
	local previous = away
	for step = -9, 10 do
		local effect = Flash.effect(config, seconds, step / 10)
		equal(effect.opacity >= previous.opacity, true, "opacity never drops as you turn towards it")
		equal(effect.duration >= previous.duration, true, "nor duration")
		equal(effect.hold >= previous.hold, true, "nor hold")
		equal(effect.opacity - previous.opacity < 0.2, true, "and it changes gradually")
		equal(effect.hold <= effect.duration, true, "the hold fits inside the duration")
		previous = effect
	end

	equal(Flash.effect(config, 0, 1).duration, 0, "out of range, nothing")
end)

---------------------------------------------------------------- Economy

local HOUR, DAY = 3600, 86400

test("the default loadout is free, and everything priced exists and has terms", function()
	local defaults = Loadout.default(WeaponConfig, TacticalConfig, ArmorConfig)
	for field, option in defaults do
		equal(Economy.isFree(ShopConfig, field, option), true, field .. " default is free")
		equal(Economy.terms(ShopConfig, field) ~= nil, true, field .. " has a timing")
	end
	local known = {
		primary = WeaponConfig.Primaries,
		secondary = WeaponConfig.Secondaries,
		melee = WeaponConfig.Melees,
		nade = WeaponConfig.Nades,
		tactical = TacticalConfig.items,
	}
	for _, slot in ArmorConfig.slots do
		known[slot] = ArmorConfig[slot]
	end
	for field, prices in ShopConfig.prices do
		equal(known[field] ~= nil, true, field .. " is a loadout field")
		for option, price in prices do
			equal(known[field][option] ~= nil, true, field .. "." .. option .. " is a real option")
			equal(price > 0, true, field .. "." .. option .. " has a price")
		end
	end
	equal(ShopConfig.timing.primary, "use", "weapons run down with use")
	equal(ShopConfig.timing.nade, "use", "so do grenades")
	equal(ShopConfig.timing.helmet, "calendar", "armour runs on the calendar")
	equal(ShopConfig.timing.tactical, "calendar", "so do tactical items")
end)

test("matches pay points and experience, and levels pay a bonus", function()
	local rewards, levels = ShopConfig.rewards, ShopConfig.levels
	local function played(overrides)
		return with({ kills = 0, deaths = 0, assists = 0, objectives = 0, won = false, mvp = false, seconds = 600 }, overrides)
	end
	equal(Economy.matchReward(ShopConfig, played({ kills = 3, won = true })), 3 * rewards.perKill + rewards.win, "a win")
	equal(Economy.matchReward(ShopConfig, played({ deaths = 4 })), rewards.loss, "a loss still pays, if you were in it")
	equal(
		Economy.matchReward(ShopConfig, played({ kills = 3, mvp = true })),
		3 * rewards.perKill + rewards.loss + rewards.mvp,
		"the MVP gets a bonus, win or lose"
	)

	local profile = Economy.newProfile()
	equal(Economy.addReward(ShopConfig, profile, levels.base - 1), 0, "just short of a level")
	equal(profile.level, 1, "level")
	equal(Economy.addReward(ShopConfig, profile, 1), 1, "one more point tips it")
	equal(profile.level, 2, "level up")
	equal(profile.xp, 0, "experience carries over from zero")
	equal(profile.points, levels.base + levels.bonus, "points earned plus the level bonus")
	equal(Economy.xpForLevel(ShopConfig, 2) > Economy.xpForLevel(ShopConfig, 1), true, "later levels need more")

	local big = Economy.newProfile()
	local twoLevels = Economy.xpForLevel(ShopConfig, 1) + Economy.xpForLevel(ShopConfig, 2)
	equal(Economy.addReward(ShopConfig, big, twoLevels + 5), 2, "one payout can gain several levels")
	equal(big.xp, 5, "with the remainder kept")
end)


test("weapons are sold by the hour of use and armour by the day", function()
	local sniper = ShopConfig.prices.primary.MSR
	equal(Economy.price(ShopConfig, "primary", "MSR", 1), sniper, "one hour of a weapon")
	equal(Economy.price(ShopConfig, "primary", "MSR", 5) < sniper * 5, true, "longer is cheaper per hour")
	equal(Economy.price(ShopConfig, "primary", "MSR", 2), nil, "two hours is not on sale")
	equal(Economy.price(ShopConfig, "primary", "MSR", 7), nil, "nor are seven: days are for armour")

	local runner = ShopConfig.prices.boots.Runner
	equal(Economy.price(ShopConfig, "boots", "Runner", 1), runner, "one day of armour")
	for _, days in { 1, 2, 3, 5, 7 } do
		equal(Economy.price(ShopConfig, "boots", "Runner", days) ~= nil, true, days .. " days is on sale")
	end
	equal(Economy.price(ShopConfig, "boots", "Runner", 4), nil, "four days is not")
	equal(Economy.price(ShopConfig, "boots", "Runner", 7) < runner * 7, true, "a week is cheaper per day")

	equal(Economy.price(ShopConfig, "primary", "M16", 1), nil, "free things are not sold")
	equal(Economy.price(ShopConfig, "nonsense", "MSR", 1), nil, "unknown field")

	local profile = Economy.newProfile()
	local ok, reason = Economy.buy(ShopConfig, profile, "primary", "MSR", 1, 0)
	equal(ok, false, "cannot afford it")
	equal(reason, "NotEnoughPoints", "reason")
	equal(select(2, Economy.buy(ShopConfig, profile, "primary", "M16", 1, 0)), "NotForSale", "free item")

	profile.points = sniper + 7
	equal(Economy.buy(ShopConfig, profile, "primary", "MSR", 1, 0), true, "bought")
	equal(profile.points, 7, "points taken")
	equal(Economy.owns(ShopConfig, profile, "primary", "MSR", 0), true, "now owned")
	equal(Economy.timeLeft(profile, "primary", "MSR", 0), HOUR, "an hour of use")
end)

test("a weapon rental only runs down while it is used", function()
	local defaults = Loadout.default(WeaponConfig, TacticalConfig, ArmorConfig)
	local profile = Economy.newProfile()
	profile.points = 100000
	Economy.buy(ShopConfig, profile, "primary", "MSR", 1, 0)

	-- Spawning with it does not start a clock, and a month passing costs nothing.
	equal(Economy.use(ShopConfig, profile, "primary", "MSR", 0), true, "usable")
	local later = 30 * DAY
	equal(Economy.owns(ShopConfig, profile, "primary", "MSR", later), true, "still owned a month on")
	equal(Economy.timeLeft(profile, "primary", "MSR", later), HOUR, "nothing has run down")

	-- Time alive with it in the loadout is what it costs.
	Economy.consume(ShopConfig, profile, with(defaults, { primary = "MSR" }), 600)
	equal(Economy.timeLeft(profile, "primary", "MSR", later), HOUR - 600, "ten minutes used")
	Economy.consume(ShopConfig, profile, defaults, 600)
	equal(Economy.timeLeft(profile, "primary", "MSR", later), HOUR - 600, "playing without it costs nothing")

	Economy.consume(ShopConfig, profile, with(defaults, { primary = "MSR" }), HOUR)
	equal(Economy.owns(ShopConfig, profile, "primary", "MSR", later), false, "used up")
	equal(Economy.use(ShopConfig, profile, "primary", "MSR", later), false, "and unusable")
	Economy.prune(profile, later)
	equal(profile.rentals[Economy.key("primary", "MSR")], nil, "pruned")
end)

test("an armour rental's clock starts at first use, then runs in real time", function()
	local defaults = Loadout.default(WeaponConfig, TacticalConfig, ArmorConfig)
	local profile = Economy.newProfile()
	profile.points = 100000
	Economy.buy(ShopConfig, profile, "boots", "Runner", 1, 1000)

	-- Weeks later, still unused, the whole day is still there.
	local later = 1000 + 20 * DAY
	equal(Economy.owns(ShopConfig, profile, "boots", "Runner", later), true, "still owned while unused")
	equal(Economy.timeLeft(profile, "boots", "Runner", later), DAY, "nothing has run down")

	equal(Economy.use(ShopConfig, profile, "boots", "Runner", later), true, "first use")
	equal(Economy.timeLeft(profile, "boots", "Runner", later + HOUR), DAY - HOUR, "now it runs, played or not")
	equal(Economy.use(ShopConfig, profile, "boots", "Runner", later + 2 * HOUR), true, "a later use does not restart it")
	equal(Economy.timeLeft(profile, "boots", "Runner", later + 2 * HOUR), DAY - 2 * HOUR, "same clock")
	Economy.consume(ShopConfig, profile, with(defaults, { boots = "Runner" }), HOUR)
	equal(Economy.timeLeft(profile, "boots", "Runner", later + 2 * HOUR), DAY - 2 * HOUR, "use does not cost it extra")

	equal(Economy.owns(ShopConfig, profile, "boots", "Runner", later + DAY), false, "gone when the day is up")
	equal(Economy.use(ShopConfig, profile, "boots", "Runner", later + DAY), false, "and unusable")
	Economy.prune(profile, later + DAY)
	equal(profile.rentals[Economy.key("boots", "Runner")], nil, "pruned")
	equal(Economy.timeLeft(profile, "boots", "Runner", later + DAY), 0, "no time left")
end)

test("buying more of a rental adds time to it", function()
	local profile = Economy.newProfile()
	profile.points = 100000
	Economy.buy(ShopConfig, profile, "boots", "Runner", 1, 0)
	Economy.buy(ShopConfig, profile, "boots", "Runner", 3, 0)
	equal(Economy.timeLeft(profile, "boots", "Runner", 0), 4 * DAY, "unused days stack")

	Economy.use(ShopConfig, profile, "boots", "Runner", 0)
	Economy.buy(ShopConfig, profile, "boots", "Runner", 1, DAY)
	equal(Economy.timeLeft(profile, "boots", "Runner", DAY), 4 * DAY, "a running rental is extended")

	Economy.buy(ShopConfig, profile, "primary", "MSR", 1, 0)
	Economy.buy(ShopConfig, profile, "primary", "MSR", 3, 0)
	equal(Economy.timeLeft(profile, "primary", "MSR", 0), 4 * HOUR, "hours of use stack too")
end)

test("a loadout is checked against what the player owns", function()
	local defaults = Loadout.default(WeaponConfig, TacticalConfig, ArmorConfig)
	local wanted = with(defaults, { primary = "MSR", boots = "Runner", helmet = "Listener" })
	local profile = Economy.newProfile()
	profile.points = 100000

	equal(Economy.ownsAll(ShopConfig, profile, defaults, 0), true, "the defaults are always allowed")
	equal(Economy.ownsAll(ShopConfig, profile, wanted, 0), false, "unbought options are not")

	Economy.buy(ShopConfig, profile, "primary", "MSR", 1, 0)
	Economy.buy(ShopConfig, profile, "helmet", "Listener", 1, 0)
	local allowed = Economy.equip(ShopConfig, profile, wanted, defaults, 0)
	equal(allowed.primary, "MSR", "the rented weapon is kept")
	equal(allowed.helmet, "Listener", "and the rented helmet")
	equal(allowed.boots, defaults.boots, "the unrented boots fall back to the default")
	equal(allowed.body, defaults.body, "free options pass through")
	equal(Economy.timeLeft(profile, "helmet", "Listener", HOUR), DAY - HOUR, "equipping started the helmet's clock")
	equal(Economy.timeLeft(profile, "primary", "MSR", HOUR), HOUR, "but not the weapon's")

	local expired = Economy.equip(ShopConfig, profile, wanted, defaults, 2 * DAY)
	equal(expired.helmet, defaults.helmet, "once expired the helmet falls back too")
	equal(expired.primary, "MSR", "the unused weapon is still there")
end)

---------------------------------------------------------------- Queue

test("every lobby mode is complete and can actually launch", function()
	for _, name in LobbyConfig.order do
		local rules = LobbyConfig.modes[name]
		equal(rules ~= nil, true, name .. " exists")
		equal(type(rules.title), "string", name .. " title")
		equal(#rules.maps > 0, true, name .. " has a map")
		equal(rules.min <= Queue.capacity(rules), true, name .. " minimum fits in a match")
		if rules.teams then
			equal(rules.min % 2, 0, name .. " minimum is even")
			equal(rules.min >= 4, true, name .. " is at least 2v2")
		end
	end
end)

test("a queue waits for its minimum and its gather time, but a full one goes at once", function()
	local ffa = { min = 2, max = 8, teams = false }
	equal(Queue.launchSize(ffa, 1, true), 0, "one player is not a match")
	equal(Queue.launchSize(ffa, 3, false), 0, "enough, but still gathering")
	equal(Queue.launchSize(ffa, 3, true), 3, "enough and gathered")
	equal(Queue.launchSize(ffa, 8, false), 8, "full: no need to wait")
	equal(Queue.launchSize(ffa, 11, false), 8, "never more than the maximum")
end)

test("team modes only launch with two equal sides", function()
	local tdm = { min = 4, max = 10, teams = true }
	equal(Queue.launchSize(tdm, 3, true), 0, "three cannot make 2v2")
	equal(Queue.launchSize(tdm, 4, true), 4, "2v2")
	equal(Queue.launchSize(tdm, 5, true), 4, "the fifth waits rather than making it 3v2")
	equal(Queue.launchSize(tdm, 7, true), 6, "3v3, one waits")
	equal(Queue.launchSize(tdm, 10, false), 10, "full")

	local odd = { min = 4, max = 9, teams = true }
	equal(Queue.capacity(odd), 8, "an odd maximum is rounded down")
	equal(Queue.launchSize(odd, 9, false), 8, "and counts as full at eight")
end)

test("teams are balanced to within one player", function()
	equal(Queue.movesToBalance(2, 2), 0, "2v2 is fine")
	equal(Queue.movesToBalance(3, 2), 0, "3v2 cannot be improved")
	equal(Queue.movesToBalance(3, 1), 1, "3v1 becomes 2v2")
	equal(Queue.movesToBalance(5, 0), 2, "5v0 becomes 3v2")
	equal(Queue.movesToBalance(1, 3), 0, "never negative")
end)

---------------------------------------------------------------- Podium

---------------------------------------------------------------- Carve

local function area(rects)
	local total = 0
	for _, rect in rects do
		total += (rect[3] - rect[1]) * (rect[4] - rect[2])
	end
	return total
end

local function hits(rects, x, z)
	local count = 0
	for _, rect in rects do
		if x > rect[1] and x < rect[3] and z > rect[2] and z < rect[4] then
			count += 1
		end
	end
	return count
end

test("carving leaves solid exactly where the open space is not", function()
	local bounds = { 0, 0, 100, 100 }
	equal(area(Carve.solids(bounds, {})), 10000, "nothing open means all solid")
	equal(#Carve.solids(bounds, { bounds }), 0, "all open means no solid")

	local room = { 20, 20, 60, 60 }
	local solids = Carve.solids(bounds, { room })
	equal(area(solids), 10000 - 40 * 40, "the room is taken out of the total")
	equal(hits(solids, 40, 40), 0, "nothing solid inside the room")
	for _, point in { { 10, 10 }, { 80, 50 }, { 40, 90 }, { 90, 90 } } do
		equal(hits(solids, point[1], point[2]), 1, "solid outside the room, once over")
	end
end)

test("two rooms that touch leave no wall between them", function()
	local solids = Carve.solids({ 0, 0, 100, 100 }, { { 10, 10, 50, 50 }, { 50, 10, 90, 50 } })
	-- Walking from one room to the other crosses x = 50 and must stay clear.
	for z = 12, 48, 4 do
		equal(hits(solids, 50, z), 0, "the join at x 50 is open")
	end
	equal(hits(solids, 50, 60), 1, "below them is still solid")
end)

test("a doorway rectangle opens a wall, and only there", function()
	local left = { 10, 10, 46, 90 }
	local right = { 54, 10, 90, 90 }
	local door = { 46, 40, 54, 56 }
	local solids = Carve.solids({ 0, 0, 100, 100 }, { left, right, door })
	equal(hits(solids, 50, 48), 0, "the doorway is open")
	for _, z in { 20, 30, 70, 85 } do
		equal(hits(solids, 50, z), 1, "the wall either side of it is not")
	end
end)

test("the solid never overlaps itself, whatever the rooms do", function()
	local open = { { 10, 10, 50, 50 }, { 30, 30, 80, 70 }, { 0, 80, 100, 90 } }
	local solids = Carve.solids({ 0, 0, 100, 100 }, open)
	-- Half-stud steps, so a sample never lands exactly on a rectangle's edge.
	for x = 1.5, 98.5, 3 do
		for z = 1.5, 98.5, 3 do
			local inside = false
			for _, rect in open do
				if x > rect[1] and x < rect[3] and z > rect[2] and z < rect[4] then
					inside = true
				end
			end
			equal(hits(solids, x, z), if inside then 0 else 1, `point {x}, {z}`)
		end
	end
end)

---------------------------------------------------------------- Score

local function played(name, kills, deaths, plants, defuses)
	return { name = name, kills = kills, deaths = deaths, plants = plants or 0, defuses = defuses or 0 }
end

test("every mode has MVP weights, and a kill always counts", function()
	for _, mode in { "FFA", "TDM", "SND" } do
		local weights = MatchConfig.mvp[mode]
		equal(weights ~= nil, true, mode .. " has weights")
		equal(weights.kill > 0, true, mode .. " counts kills")
	end
	equal(MatchConfig.mvp.SND.plant > MatchConfig.mvp.SND.kill, true, "a plant is worth more than a kill in SND")
	equal(MatchConfig.mvp.SND.defuse > MatchConfig.mvp.SND.kill, true, "and so is a defuse")
	equal(MatchConfig.mvp.TDM.plant, nil, "a deathmatch has no objective to weigh")
end)

test("a deathmatch is scored on kills alone", function()
	local weights = MatchConfig.mvp.TDM
	equal(Score.of(weights, played("Ann", 7, 2, 3, 1)), 7, "plants and defuses do not count")
	local top = Score.top(weights, { played("Ann", 4, 9), played("Bo", 9, 3), played("Cy", 4, 2), played("Di", 1, 0) }, 3)
	equal(#top, 3, "three places")
	equal(top[1].name, "Bo", "most kills is first")
	equal(top[2].name, "Cy", "equal kills: fewer deaths takes the place")
	equal(top[3].name, "Ann", "then the rest")
	equal(top[1].score, 9, "the score is carried through")
end)

test("search and destroy counts the objective, so the bomb can beat the gun", function()
	local weights = MatchConfig.mvp.SND
	local shooter = played("Ann", 8, 4)
	local planter = played("Bo", 3, 2, 2, 1)
	equal(Score.of(weights, shooter), 8, "eight kills")
	equal(Score.of(weights, planter), 3 + 3 * weights.plant, "three kills, two plants and a defuse")
	equal(Score.mvp(weights, { shooter, planter }), "Bo", "the objective player takes it")
	equal(Score.mvp(MatchConfig.mvp.TDM, { shooter, planter }), "Ann", "in a deathmatch the shooter would have")
end)

test("the MVP is whoever did most, on either side, or nobody", function()
	local weights = MatchConfig.mvp.TDM
	equal(Score.mvp(weights, { played("Ann", 5, 2), played("Bo", 9, 7) }), "Bo", "a worse record can still be the MVP")
	equal(Score.mvp(weights, { played("Ann", 6, 4), played("Bo", 6, 2) }), "Bo", "same kills: fewer deaths")
	equal(Score.mvp(weights, { played("Ann", 6, 2), played("Bo", 6, 2) }), nil, "an exact tie has no MVP")
	equal(Score.mvp(weights, { played("Ann", 0, 0), played("Bo", 0, 3) }), nil, "nobody scored")
	equal(Score.mvp(weights, {}), nil, "an empty match")

	local results = { played("Ann", 4, 1) }
	Score.rank(weights, results)
	equal(results[1].score, nil, "ranking leaves the list it was given alone")
end)

test("the summary says what someone actually did", function()
	equal(Score.summary(played("Ann", 9, 2)), "9 kills", "kills alone")
	equal(Score.summary(played("Bo", 6, 2, 2, 0)), "6 kills, 2 plants", "with plants")
	equal(Score.summary(played("Cy", 1, 0, 1, 2)), "1 kills, 1 plants, 2 defuses", "and defuses")
end)

test("winners celebrate, a losing MVP cries, and other losers sulk", function()
	equal(Podium.mood(true, true, false), "Celebrate", "MVP on the winning side")
	equal(Podium.mood(true, false, false), "Celebrate", "a winner")
	equal(Podium.mood(false, true, false), "Cry", "MVP, but their team lost")
	equal(Podium.mood(false, false, false), "Sulk", "on the podium, on the losing side")
	equal(Podium.mood(false, true, true), "Celebrate", "nobody lost: a draw or a free-for-all")
	equal(Podium.mood(false, false, true), "Celebrate", "so nobody sulks")
end)

test("every mood poses every joint, smoothly and within reach", function()
	local moods = Pose.moods()
	equal(#moods, 3, "three moods")
	for _, mood in moods do
		local previous = nil
		for frame = 0, 60 do
			local t = frame / 12
			local pose = Pose.sample(mood, t)
			equal(math.abs(pose.root.lift) <= 2, true, mood .. " stays on its plinth")
			for _, joint in Pose.JOINTS do
				local angles = pose.joints[joint]
				equal(angles ~= nil, true, mood .. " poses " .. joint)
				for _, angle in angles do
					equal(angle == angle and math.abs(angle) <= 180, true, mood .. " " .. joint .. " is a sane angle")
				end
			end
			if previous then
				-- No jumps: a joint moves at most a few degrees in a twelfth of a second.
				for _, joint in Pose.JOINTS do
					for axis = 1, 3 do
						local step = math.abs(pose.joints[joint][axis] - previous.joints[joint][axis])
						equal(step < 30, true, mood .. " " .. joint .. " moves smoothly")
					end
				end
			end
			previous = pose
		end
	end
end)

test("each mood reads as what it is", function()
	-- Averaged over a few seconds, so a moment of the animation cannot mislead.
	local function average(mood, joint, axis)
		local total = 0
		for frame = 0, 48 do
			total += Pose.sample(mood, frame / 12).joints[joint][axis]
		end
		return total / 49
	end

	equal(average("Cry", "Neck", 1) > 25, true, "crying hangs the head")
	equal(average("Cry", "Waist", 1) > 25, true, "and doubles the body over")
	equal(average("Cry", "RightElbow", 1) < -80, true, "with the hands up at the face")
	equal(average("Sulk", "Neck", 1) > 15, true, "sulking looks down")
	equal(average("Sulk", "Waist", 1) < average("Cry", "Waist", 1), true, "but is not doubled over")
	equal(math.abs(average("Sulk", "RightShoulder", 3)) < 20, true, "with the arms hanging")
	equal(average("Celebrate", "RightShoulder", 3) > 100, true, "celebrating throws the arms up")
	equal(average("Celebrate", "Neck", 1) < 0, true, "and the head back")

	local still = Pose.sample("Nonsense", 3)
	equal(still.root.lift, 0, "an unknown mood just stands there")
	equal(still.joints.Neck[1], 0, "with every joint at rest")
end)

---------------------------------------------------------------- BombRound

local Bomb = MatchConfig.bomb
local ATTACK, DEFEND = MatchConfig.teams[1], MatchConfig.teams[2]

-- Both sides present and alive unless overridden.
local function sides(overrides)
	return with({ players = 2, attackers = 1, attackersAlive = 1, defenders = 1, defendersAlive = 1 }, overrides or {})
end

-- A match whose current round has just gone live.
local function liveRound()
	local state = BombRound.new(MatchConfig)
	BombRound.tick(MatchConfig, state, 0, sides())
	BombRound.tick(MatchConfig, state, Bomb.prepTime, sides())
	return state
end

-- Plays out the result screen; returns what follows it.
local function afterResult(state)
	return BombRound.tick(MatchConfig, state, Bomb.roundEndTime, sides())
end

test("bomb match waits for players, then holds everyone through prep", function()
	local state = BombRound.new(MatchConfig)
	equal(BombRound.tick(MatchConfig, state, 1, sides({ players = MatchConfig.minPlayers - 1 })), nil, "too few")
	equal(BombRound.tick(MatchConfig, state, 1, sides()), "Started", "enough players")
	equal(state.phase, "Prep", "phase")
	equal(state.round, 1, "round")
	equal(state.attackers, ATTACK, "first team attacks first")
	equal(BombRound.inPlay(state), false, "no fighting in prep")
	equal(BombRound.tick(MatchConfig, state, Bomb.prepTime - 1, sides()), nil, "still in prep")
	equal(BombRound.tick(MatchConfig, state, 1, sides()), "Live", "prep over")
	equal(state.timeLeft, Bomb.roundTime, "round clock")
	equal(BombRound.inPlay(state), true, "fighting once live")
end)

test("before the plant, wiping either side or running out the clock ends the round", function()
	local state = liveRound()
	equal(BombRound.tick(MatchConfig, state, 1, sides({ attackersAlive = 0 })), "RoundOver", "attackers dead")
	equal(state.roundWinner, DEFEND, "defenders take it")
	equal(state.reason, "Eliminated", "reason")

	state = liveRound()
	equal(BombRound.tick(MatchConfig, state, 1, sides({ defendersAlive = 0 })), "RoundOver", "defenders dead")
	equal(state.roundWinner, ATTACK, "attackers take it")

	state = liveRound()
	equal(BombRound.tick(MatchConfig, state, Bomb.roundTime, sides()), "RoundOver", "time up")
	equal(state.roundWinner, DEFEND, "no plant means defenders win")
	equal(state.reason, "TimeUp", "reason")
	equal(state.scores[DEFEND], 1, "score")
end)

test("a side with no members is never eliminated", function()
	local state = liveRound()
	local alone = sides({ players = 2, defenders = 0, defendersAlive = 0 })
	equal(BombRound.tick(MatchConfig, state, 1, alone), nil, "round carries on")
	equal(state.phase, "Live", "phase")
end)

test("planting only works while live and starts the fuse", function()
	local state = BombRound.new(MatchConfig)
	equal(BombRound.plant(MatchConfig, state), false, "while waiting")
	BombRound.tick(MatchConfig, state, 0, sides())
	equal(BombRound.plant(MatchConfig, state), false, "in prep")
	state = liveRound()
	equal(BombRound.plant(MatchConfig, state), true, "while live")
	equal(state.phase, "Planted", "phase")
	equal(state.timeLeft, Bomb.fuseTime, "fuse")
	equal(BombRound.plant(MatchConfig, state), false, "already planted")
end)

test("after the plant, killing the attackers is not enough", function()
	local state = liveRound()
	BombRound.plant(MatchConfig, state)
	equal(BombRound.tick(MatchConfig, state, 1, sides({ attackersAlive = 0 })), nil, "round carries on")
	equal(BombRound.tick(MatchConfig, state, Bomb.fuseTime, sides({ attackersAlive = 0 })), "Exploded", "fuse ran out")
	equal(state.roundWinner, ATTACK, "attackers take it")
	equal(state.reason, "Exploded", "reason")
end)

test("after the plant, defenders win only by defusing", function()
	local state = liveRound()
	equal(BombRound.defuse(MatchConfig, state), false, "nothing to defuse yet")
	BombRound.plant(MatchConfig, state)
	equal(BombRound.tick(MatchConfig, state, 1, sides({ defendersAlive = 0 })), "RoundOver", "defenders wiped")
	equal(state.roundWinner, ATTACK, "attackers take it")

	state = liveRound()
	BombRound.plant(MatchConfig, state)
	equal(BombRound.defuse(MatchConfig, state), true, "defuse")
	equal(state.phase, "RoundOver", "phase")
	equal(state.roundWinner, DEFEND, "defenders take it")
	equal(state.reason, "Defused", "reason")
	equal(BombRound.defuse(MatchConfig, state), false, "cannot defuse twice")
end)

test("rounds follow each other, sides swap once, and a team wins on rounds", function()
	local state = liveRound()
	for round = 1, Bomb.swapAfter do
		equal(state.attackers, ATTACK, "attackers in round " .. round)
		BombRound.tick(MatchConfig, state, Bomb.roundTime, sides()) -- defenders win on time
		equal(afterResult(state), "RoundStarted", "next round")
		BombRound.tick(MatchConfig, state, Bomb.prepTime, sides())
	end
	equal(state.round, Bomb.swapAfter + 1, "round number")
	equal(state.attackers, DEFEND, "sides have swapped")
	equal(BombRound.defenders(MatchConfig, state), ATTACK, "and so have the defenders")
	equal(state.scores[DEFEND], Bomb.swapAfter, "score carried over")

	-- The team now attacking needs one more round: wipe the new defenders.
	equal(Bomb.roundsToWin, Bomb.swapAfter + 1, "this test assumes one round short at the swap")
	BombRound.tick(MatchConfig, state, 1, sides({ defendersAlive = 0 }))
	equal(afterResult(state), "MatchOver", "match decided")
	equal(state.winner, DEFEND, "winner")
	equal(BombRound.tick(MatchConfig, state, MatchConfig.endDuration, sides()), "Reset", "result finished")
	equal(state.phase, "Waiting", "phase")
	equal(state.scores[DEFEND], 0, "scores cleared")
end)

test("a bomb match returns to waiting when players drop out", function()
	local state = liveRound()
	equal(BombRound.tick(MatchConfig, state, 1, sides({ players = MatchConfig.minPlayers - 1 })), "Reset", "event")
	equal(state.phase, "Waiting", "phase")
	equal(state.round, 0, "round")
end)

---------------------------------------------------------------- Backfill

local SEATS = LobbyConfig.backfill

test("a match that has lost a player asks for one for as long as it is being played", function()
	equal(Backfill.wanted({ mode = "TDM", phase = "Playing" }), true, "the middle of a match")
	equal(Backfill.wanted({ mode = "FFA", phase = "Playing" }), true, "a free-for-all too")
	equal(Backfill.wanted({ mode = "TDM", phase = "Waiting" }), false, "the warm-up is not a match yet")
	equal(Backfill.wanted({ mode = "TDM", phase = "Ended" }), false, "nor is the result screen")
	equal(Backfill.wanted({ mode = "SND", phase = "Live" }), true, "a round in progress: they spawn in the next")
	equal(Backfill.wanted({ mode = "SND", phase = "RoundOver" }), true, "between rounds, even the last")
	equal(Backfill.wanted({ mode = "SND", phase = "MatchOver" }), false, "over")
end)

test("a seat is claimed once, and frees itself if nobody turns up", function()
	local code = "access-code"
	local seat = Backfill.refresh(nil, code, 2, 1, 0, 1000, SEATS.transitTimeout)
	equal(Backfill.open(seat), 2, "two places open")

	-- Two lobbies each have a player queued, and a third has one too.
	local taken
	seat, taken = Backfill.claim(seat, 1, 1001)
	equal(taken, true, "the first lobby takes one")
	equal(Backfill.open(seat), 1, "one left")
	seat, taken = Backfill.claim(seat, 1, 1002)
	equal(taken, true, "the second takes the other")
	equal(seat.accessCode, code, "and is told where to send them")
	local unchanged, none = Backfill.claim(seat, 1, 1003)
	equal(none, false, "a third gets nothing")
	equal(unchanged, nil, "and changes nothing")
	equal(select(2, Backfill.claim(nil, 1, 1003)), false, "nor does a seat that has gone")

	-- The match renews its seats while both are still on their way.
	seat = Backfill.refresh(seat, code, 2, 1, 0, 1005, SEATS.transitTimeout)
	equal(Backfill.open(seat), 0, "still taken while they travel")

	-- One arrives.
	seat = Backfill.refresh(seat, code, 1, 1, 1, 1010, SEATS.transitTimeout)
	equal(seat.missing, 1, "one place still empty")
	equal(Backfill.open(seat), 0, "and its player is still on the way")

	-- The other never does: their teleport failed.
	seat = Backfill.refresh(seat, code, 1, 1, 0, 1002 + SEATS.transitTimeout + 1, SEATS.transitTimeout)
	equal(Backfill.open(seat), 1, "after a while the place is offered again")

	equal(Backfill.refresh(seat, code, 0, 0, 1, 2000, SEATS.transitTimeout), nil, "a full match advertises nothing")
end)

test("more players leaving opens more seats, without losing track of who is coming", function()
	local seat = Backfill.refresh(nil, "code", 1, 1, 0, 100, SEATS.transitTimeout)
	seat = Backfill.claim(seat, 1, 101)
	seat = Backfill.refresh(seat, "code", 3, 2, 0, 102, SEATS.transitTimeout)
	equal(Backfill.open(seat), 2, "two more left; the one already coming still counts")
end)

test("a squad is sent into a running match whole, on one team, or not at all", function()
	-- 4v4 that has lost two from Alpha and one from Bravo.
	equal(Backfill.gap({ Alpha = 2, Bravo = 3 }, 8), 2, "the most room on one team")
	equal(Backfill.gap({ Alpha = 4, Bravo = 3 }, 8), 1, "one place, on Bravo")
	equal(Backfill.gap({ Alpha = 4, Bravo = 4 }, 8), 0, "full")
	equal(Backfill.gap({}, 6), 6, "a free-for-all has no teams to split anybody between")

	local seat = Backfill.refresh(nil, "code", 3, 2, 0, 100, SEATS.transitTimeout)
	equal(select(2, Backfill.claim(seat, 3, 101)), false, "a squad of three does not fit on either team")
	equal(select(2, Backfill.claim(seat, 4, 101)), false, "nor do more than there are places")
	local claimed, went = Backfill.claim(seat, 2, 101)
	equal(went, true, "a squad of two does")
	equal(Backfill.open(claimed), 1, "leaving one place")

	-- While those two are on the way, nobody can say which team the last place is on.
	equal(select(2, Backfill.claim(claimed, 2, 102)), false, "so another squad waits")
	equal(select(2, Backfill.claim(claimed, 1, 102)), true, "but somebody alone can go anywhere")
end)

---------------------------------------------------------------- Sound

test("every gun has a shot to play, and every sound is complete", function()
	local count = 0
	for name, sound in SoundConfig.sounds do
		count += 1
		equal(type(sound.id), "string", name .. " names a sound file")
		local ours = string.sub(sound.id, 1, 11) == "rbxasset://" or string.sub(sound.id, 1, 13) == "rbxassetid://"
		equal(ours or sound.id == "", true, name .. " is a Roblox asset, or left empty to be silent")
		equal(sound.volume > 0 and sound.volume <= 2, true, name .. " has a sensible volume")
		equal(sound.speed > 0, true, name .. " has a playback speed")
	end
	equal(count >= 10, true, "the sounds are all there")

	for name, config in Weapons do
		if config.kind == "Gun" then
			local shot = SoundConfig.shots[config.class]
			equal(shot ~= nil, true, name .. ": its class has a shot sound")
			equal(SoundConfig.sounds[shot] ~= nil, true, name .. ": and that sound exists")
			equal(SoundConfig.sounds[shot].range ~= nil, true, name .. ": which other players can hear from a distance")
		end
	end
	-- A sniper should carry further than a handgun.
	local sounds, shots = SoundConfig.sounds, SoundConfig.shots
	equal(sounds[shots.Sniper].range > sounds[shots.Handgun].range, true, "the sniper is heard from furthest")
	for _, name in { "Hit", "Headshot", "Kill", "Hurt", "Explosion", "Flash", "Swing", "Reload", "Equip" } do
		equal(sounds[name] ~= nil, true, name .. " has a sound")
	end
end)

---------------------------------------------------------------- Controls

test("everything a player can do can be done on a keyboard, a controller and a touch screen", function()
	local keys, pads, labels = {}, {}, {}
	local count = 0
	for name, action in ControlsConfig.actions do
		count += 1
		equal(type(action.hold), "boolean", name .. " says whether it is held or pressed")
		for _, key in action.keys do
			equal(keys[key], nil, "the key " .. key .. " does one thing (" .. name .. ")")
			keys[key] = name
		end
		for _, button in action.pad do
			equal(pads[button], nil, "the button " .. button .. " does one thing (" .. name .. ")")
			pads[button] = name
		end
		if action.touch then
			equal(labels[action.touch.label], nil, "the touch button " .. action.touch.label .. " is one button")
			labels[action.touch.label] = name
			equal(action.touch.size >= 40, true, name .. " is big enough for a thumb")
		end
		if action.switch then
			equal(action.hold, true, name .. " can only be a switch if it is something held")
		end
	end
	equal(count >= 14, true, "the actions are all there")

	-- What the game needs in a fight has to be reachable on every kind of device.
	for _, name in { "Fire", "Scope", "Reload", "Tactical", "NextWeapon", "Crouch", "Use", "Loadout" } do
		local action = ControlsConfig.actions[name]
		equal(#action.pad > 0, true, name .. " is on a controller")
		equal(action.touch ~= nil, true, name .. " is on a touch screen")
	end
	for _, name in { "Fire", "Scope", "Reload", "Tactical", "Crouch", "Use" } do
		local action = ControlsConfig.actions[name]
		equal(#action.keys > 0 or action.mouse ~= nil, true, name .. " is on a keyboard or mouse")
	end
	for key = 1, 5 do
		equal(ControlsConfig.actions["Slot" .. key] ~= nil, true, "number key " .. key .. " has a slot action")
	end
	equal(pads.ButtonA, nil, "A is left alone: Roblox uses it to jump")
	equal(keys.Space, nil, "and so is the space bar")
end)

---------------------------------------------------------------- Saving across servers

test("a profile open on one server makes another wait, until it is closed or abandoned", function()
	local STALE = 150
	equal(Session.heldElsewhere(nil, "match", 1000, STALE), false, "a new player has nothing open anywhere")
	equal(Session.heldElsewhere({ points = 5 }, "match", 1000, STALE), false, "nor has a profile saved before sessions existed")

	local opened = { points = 5, session = Session.stamp("lobby", 1000) }
	equal(Session.heldElsewhere(opened, "match", 1001, STALE), true, "the lobby still has it: the match waits")
	equal(Session.heldElsewhere(opened, "lobby", 1001, STALE), false, "the lobby itself does not wait for itself")

	opened.session = nil -- the lobby's last save, as the player left
	equal(Session.heldElsewhere(opened, "match", 1002, STALE), false, "closed: the match can open it")

	local crashed = { points = 5, session = Session.stamp("lobby", 1000) }
	equal(Session.heldElsewhere(crashed, "match", 1000 + STALE - 1, STALE), true, "a quiet server may only be slow")
	equal(Session.heldElsewhere(crashed, "match", 1000 + STALE, STALE), false, "but after long enough it is taken to be gone")

	equal(Session.heldElsewhere({ session = "nonsense" }, "match", 0, STALE), false, "a damaged mark is no mark")
	equal(Session.heldElsewhere({ session = { server = "lobby" } }, "match", 5000, STALE), false, "nor is one with no time on it")
end)

test("a server that has lost a profile to another does not write over it", function()
	equal(Session.mayWrite(nil, "match"), true, "nothing saved yet: write")
	equal(Session.mayWrite({ points = 5 }, "match"), true, "nobody has it open: write")
	equal(Session.mayWrite({ session = Session.stamp("match", 10) }, "match"), true, "we have it open: write")
	equal(Session.mayWrite({ session = Session.stamp("lobby", 10) }, "match"), false, "another server has it: theirs is the newer")
end)

test("moving from lobby to match and back never loses what was earned", function()
	-- A tiny data store, with the same take-it-or-leave-it update the real one has.
	local STALE = 150
	local stored = nil
	local function update(change)
		local result = change(stored)
		if result ~= nil then
			stored = result
		end
	end
	local function open(server, now)
		local waiting = false
		update(function(found)
			waiting = Session.heldElsewhere(found, server, now, STALE)
			if waiting then
				return nil
			end
			local record = if type(found) == "table" then table.clone(found) else {}
			record.session = Session.stamp(server, now)
			return record
		end)
		return not waiting, stored
	end
	local function save(server, profile, now, closing)
		local written = false
		update(function(found)
			written = Session.mayWrite(found, server)
			if not written then
				return nil
			end
			local record = table.clone(profile)
			record.session = if closing then nil else Session.stamp(server, now)
			return record
		end)
		return written
	end

	equal(open("lobby", 100), true, "the lobby opens a new player's profile")
	local inLobby = { points = 500 } -- they rent something, buy a revive

	-- They are teleported. The match starts loading before the lobby has saved.
	equal(open("match", 101), false, "the match finds it open in the lobby, and waits")
	equal(save("lobby", inLobby, 101, true), true, "the lobby's last save goes through")
	local ok, loaded = open("match", 104)
	equal(ok, true, "now the match can open it")
	equal(loaded.points, 500, "and sees everything the lobby saved")

	-- The match pays out, then they go back to the lobby the same way.
	local inMatch = { points = 900 }
	equal(save("match", inMatch, 290, false), true, "the match saves as it goes, which keeps the profile marked as open")
	equal(open("lobby2", 300), false, "the next lobby waits for the match")
	equal(save("match", inMatch, 300, true), true, "the match's last save")
	ok, loaded = open("lobby2", 303)
	equal(ok, true, "opened")
	equal(loaded.points, 900, "with the match's payout in it")

	-- A server that froze, and comes back after its profile was taken as abandoned.
	equal(open("slow", 303 + STALE + 1), true, "an abandoned profile can be opened elsewhere")
	equal(save("lobby2", { points = 1 }, 303 + STALE + 2, true), false, "and the server that lost it cannot write over it")
	equal(stored.points, 900, "so nothing is overwritten")
end)

---------------------------------------------------------------- Squads

local SQUAD = LobbyConfig.squad

test("a squad forms by invitation, and the one who invited leads it", function()
	local state = Squad.new()
	equal(#Squad.members(state, "amy"), 1, "everybody starts on their own")
	equal(Squad.leader(state, "amy"), "amy", "leading only themselves")

	equal(Squad.invite(SQUAD, state, "amy", "amy", 0), false, "nobody invites themselves")
	equal(Squad.invite(SQUAD, state, "amy", "bo", 0), true, "an invitation")
	equal(#Squad.invitesFor(state, "bo", 1), 1, "which bo can see")
	equal(#Squad.members(state, "amy"), 1, "but nothing has changed until it is answered")

	local ok = Squad.answer(SQUAD, state, "bo", "amy", true, 5)
	equal(ok, true, "accepted")
	equal(table.concat(Squad.members(state, "bo"), " "), "amy bo", "both see the same squad, leader first")
	equal(Squad.leader(state, "bo"), "amy", "amy leads")
	equal(#Squad.invitesFor(state, "bo", 6), 0, "and the invitation is used up")

	equal(Squad.invite(SQUAD, state, "bo", "cy", 6), false, "only the leader invites")
	equal(Squad.invite(SQUAD, state, "amy", "bo", 6), false, "and not somebody already in")
end)

test("an invitation can be declined, and does not wait for ever", function()
	local state = Squad.new()
	Squad.invite(SQUAD, state, "amy", "bo", 0)
	equal(Squad.answer(SQUAD, state, "bo", "amy", false, 1), true, "declined")
	equal(#Squad.members(state, "amy"), 1, "nobody joined")
	equal(Squad.answer(SQUAD, state, "bo", "amy", true, 2), false, "and it cannot be accepted afterwards")

	Squad.invite(SQUAD, state, "amy", "bo", 10)
	equal(#Squad.invitesFor(state, "bo", 10 + SQUAD.inviteLasts + 1), 0, "an old invitation is gone")
	equal(Squad.answer(SQUAD, state, "bo", "amy", true, 10 + SQUAD.inviteLasts + 1), false, "and cannot be accepted")
	equal(Squad.answer(SQUAD, state, "cy", "amy", true, 0), false, "nor can one that was never sent")
end)

test("a squad holds four, and no more", function()
	local state = Squad.new()
	for _, name in { "b", "c", "d" } do
		Squad.invite(SQUAD, state, "a", name, 0)
		Squad.answer(SQUAD, state, name, "a", true, 1)
	end
	equal(#Squad.members(state, "a"), SQUAD.size, "full")
	equal(Squad.invite(SQUAD, state, "a", "e", 2), false, "no room to invite a fifth")

	-- Two invitations sent while there was one place left: only one gets it.
	local other = Squad.new()
	Squad.invite(SQUAD, other, "a", "b", 0)
	Squad.answer(SQUAD, other, "b", "a", true, 1)
	Squad.invite(SQUAD, other, "a", "c", 1)
	Squad.answer(SQUAD, other, "c", "a", true, 2)
	Squad.invite(SQUAD, other, "a", "d", 2)
	Squad.invite(SQUAD, other, "a", "e", 2)
	equal(Squad.answer(SQUAD, other, "d", "a", true, 3), true, "the first to answer is in")
	equal(Squad.answer(SQUAD, other, "e", "a", true, 3), false, "the second finds it full")
	equal(#Squad.members(other, "a"), SQUAD.size, "four")
end)

test("leaving a squad hands on the lead, and two is the fewest a squad can be", function()
	local state = Squad.new()
	for _, name in { "b", "c" } do
		Squad.invite(SQUAD, state, "a", name, 0)
		Squad.answer(SQUAD, state, name, "a", true, 1)
	end

	local touched = Squad.leave(state, "a")
	equal(#touched, 3, "everyone in it is told")
	equal(table.concat(Squad.members(state, "b"), " "), "b c", "the others stay together")
	equal(Squad.leader(state, "c"), "b", "and whoever joined first now leads")
	equal(#Squad.members(state, "a"), 1, "the one who left is on their own")
	equal(Squad.invite(SQUAD, state, "b", "d", 2), true, "the new leader can invite")

	Squad.leave(state, "c")
	equal(#Squad.members(state, "b"), 1, "a squad of one is no squad")
	equal(Squad.leader(state, "b"), "b", "just a player")
	equal(#Squad.leave(state, "b"), 0, "leaving nothing touches nobody")
end)

test("joining one squad leaves another, and going home cancels invitations", function()
	local state = Squad.new()
	Squad.invite(SQUAD, state, "a", "b", 0)
	Squad.answer(SQUAD, state, "b", "a", true, 1)
	Squad.invite(SQUAD, state, "x", "b", 1)
	local ok, _, touched = Squad.answer(SQUAD, state, "b", "x", true, 2)
	equal(ok, true, "b goes over to x")
	equal(table.concat(Squad.members(state, "x"), " "), "x b", "x's squad")
	equal(#Squad.members(state, "a"), 1, "and a is left on their own")
	equal(table.find(touched, "a") ~= nil, true, "which a is told about")

	Squad.invite(SQUAD, state, "x", "c", 2)
	Squad.remove(state, "x")
	equal(#Squad.invitesFor(state, "c", 3), 0, "an invitation from somebody who left is withdrawn")
	equal(#Squad.members(state, "b"), 1, "and their squad is over")
end)

---------------------------------------------------------------- Squads in the queue

test("a queue of players on their own launches as it always did", function()
	local tdm = LobbyConfig.modes.TDM
	local function solos(count)
		return table.create(count, 1)
	end
	equal(Queue.pick(tdm, solos(3), true), nil, "three is not enough for two teams")
	equal(#Queue.pick(tdm, solos(4), true).groups, 4, "four, once gathered, is 2v2")
	equal(Queue.pick(tdm, solos(4), false), nil, "but not before the gather time")
	equal(#Queue.pick(tdm, solos(5), true).groups, 4, "the fifth waits, so the sides are even")
	equal(#Queue.pick(tdm, solos(12), false).groups, Queue.capacity(tdm), "a full match goes at once")

	local pick = Queue.pick(tdm, solos(6), true)
	local ones, twos = 0, 0
	for _, side in pick.sides do
		ones += if side == 1 then 1 else 0
		twos += if side == 2 then 1 else 0
	end
	equal(ones, 3, "three on one side")
	equal(twos, 3, "three on the other")

	local ffa = LobbyConfig.modes.FFA
	equal(#Queue.pick(ffa, solos(3), true).groups, 3, "a free-for-all takes any number from its minimum")
	equal(Queue.pick(ffa, solos(3), true).sides, nil, "and has no sides")
	equal(Queue.pick(ffa, solos(1), true), nil, "one player is not a match")
end)

test("a squad is never split between matches or teams", function()
	local tdm = LobbyConfig.modes.TDM
	local function sideSizes(sizes, pick)
		local totals = { 0, 0 }
		for place, index in pick.groups do
			totals[pick.sides[place]] += sizes[index]
		end
		return totals[1], totals[2]
	end

	equal(Queue.pick(tdm, { 3, 1 }, true), nil, "3 against 1 is not a match: they wait for two more")

	local sizes = { 3, 1, 1, 1 }
	local pick = Queue.pick(tdm, sizes, true)
	equal(#pick.groups, 4, "the squad of three and three on their own")
	local a, b = sideSizes(sizes, pick)
	equal(a, 3, "three a side")
	equal(b, 3, "with the squad together")

	sizes = { 2, 2 }
	pick = Queue.pick(tdm, sizes, true)
	equal(pick.sides[1] ~= pick.sides[2], true, "two pairs play each other")

	sizes = { 4, 1, 1, 1, 1 }
	a, b = sideSizes(sizes, Queue.pick(tdm, sizes, true))
	equal(a + b, 8, "a squad of four against four others")
	equal(a, b, "evenly")

	-- A group that cannot fit is passed over, and keeps its place for later.
	sizes = { 1, 3, 1, 1, 1 }
	pick = Queue.pick(tdm, sizes, true)
	a, b = sideSizes(sizes, pick)
	equal(a, b, "even sides")
	equal(a + b, 6, "six of the seven: the squad of three, and three alone")

	equal(Queue.pick(tdm, { 3, 2 }, true), nil, "five who will not split: no match yet")
	equal(#Queue.pick(LobbyConfig.modes.FFA, { 3, 1 }, true).groups, 2, "a free-for-all just takes them all")
	equal(LobbyConfig.squad.size <= Queue.capacity(tdm) / 2, true, "a full squad fits on one team")
end)

---------------------------------------------------------------- Rewards for taking part

test("a player who did nothing earns nothing, and a short stay earns half", function()
	local rewards = ShopConfig.rewards
	local function played(overrides)
		return with({ kills = 0, deaths = 0, assists = 0, objectives = 0, won = true, mvp = false, seconds = 600 }, overrides)
	end
	equal(Economy.matchReward(ShopConfig, played({})), 0, "sent in as it ended, on the winning side: nothing")
	equal(Economy.matchReward(ShopConfig, played({ won = false })), 0, "nor for losing")
	equal(Economy.matchReward(ShopConfig, played({ seconds = 5 })), 0, "nor for being quick about it")
	equal(Economy.matchReward(ShopConfig, played({ deaths = 1 })), rewards.win, "one death is taking part")
	equal(Economy.matchReward(ShopConfig, played({ assists = 1 })), rewards.win, "so is an assist")
	equal(Economy.matchReward(ShopConfig, played({ objectives = 1 })), rewards.win, "and so is planting the bomb")

	local full = Economy.matchReward(ShopConfig, played({ kills = 4 }))
	local brief = Economy.matchReward(ShopConfig, played({ kills = 4, seconds = rewards.shortStay - 1 }))
	equal(brief, math.floor(full * rewards.shortShare + 0.5), "a few kills in a short stay pays a share")
	equal(Economy.matchReward(ShopConfig, played({ kills = 4, seconds = rewards.shortStay })), full, "from then on it pays in full")
end)

---------------------------------------------------------------- Ranks

test("ranks run from Private to Commander in Chief, a grade at a time", function()
	local ranks = ShopConfig.ranks
	local top = Rank.maxLevel(ranks)
	equal(ShopConfig.levels.max, top, "the level cap is the last grade of the last rank")
	equal(top >= 60, true, "a long climb")

	local first = Rank.of(ranks, 1)
	equal(first.name, "Private", "everybody starts a Private")
	equal(first.grade, 1, "grade 1")
	equal(first.title, "Private 1", "written out")
	equal(Rank.of(ranks, 2).title, "Private 2", "then the next grade")
	equal(Rank.of(ranks, ranks[1].grades + 1).title, ranks[2].name .. " 1", "then the next rank")

	local last = Rank.of(ranks, top)
	equal(last.name, "Commander in Chief", "the top")
	equal(last.title, "Commander in Chief", "a rank with one grade has no number")
	equal(Rank.of(ranks, top + 50).title, last.title, "a level past the end is still the top rank")
	equal(Rank.of(ranks, 0).title, "Private 1", "and one before the start is still the first")

	-- Every level has a rank, and each is at or above the one before.
	local index = 0
	for level = 1, top do
		local rank = Rank.of(ranks, level)
		equal(rank.index >= index, true, "level " .. level .. " does not go backwards")
		index = rank.index
	end
	equal(index, #ranks, "and the climb reaches every rank")
end)

test("experience stops counting at the top level", function()
	local profile = Economy.newProfile()
	profile.level = ShopConfig.levels.max - 1
	local gained = Economy.addReward(ShopConfig, profile, 10000000)
	equal(gained, 1, "one level to the top, and no further")
	equal(profile.level, ShopConfig.levels.max, "at the cap")
	equal(profile.xp, 0, "with nothing left over to earn towards")
	equal(Economy.addReward(ShopConfig, profile, 500), 0, "more play gains no level")
	equal(profile.level, ShopConfig.levels.max, "and does not pass the cap")
	equal(profile.points > 10000500, true, "but still pays points")
end)

---------------------------------------------------------------- Weapon prestige

local LADDER = ProgressConfig.weapons.prestiges

test("every weapon belongs to a class that earns experience", function()
	local known = {}
	for _, class in ProgressConfig.weapons.classes do
		known[class] = true
		equal(type(ProgressConfig.weapons.titles[class]), "string", class .. " has a title")
	end
	for name, config in Weapons do
		if config.kind ~= "Bomb" then
			equal(known[Prestige.classOf(config)], true, name .. " is in a class that is tracked")
		end
	end
	equal(Prestige.classOf(Weapons.Bomb), nil, "the bomb is not a weapon class")
	equal(Prestige.classOf(Weapons.MP5), "SMG", "an SMG has its own")
	equal(Prestige.classOf(Weapons.P2020), "Handgun", "and so does the handgun")
end)

test("weapon experience climbs through the materials a tier at a time", function()
	local start = Prestige.standing(LADDER, 0)
	equal(start.title, LADDER[1].name .. " 1", "everybody starts at the first tier of the first material")
	equal(start.needed, LADDER[1].xp, "with one tier's worth to go")

	local almost = Prestige.standing(LADDER, LADDER[1].xp - 1)
	equal(almost.tier, 1, "one short")
	equal(almost.into, LADDER[1].xp - 1, "nearly there")
	equal(Prestige.standing(LADDER, LADDER[1].xp).title, LADDER[1].name .. " 2", "the next tier")

	local wood = LADDER[1].xp * LADDER[1].tiers
	equal(Prestige.standing(LADDER, wood - 1).title, LADDER[1].name .. " " .. LADDER[1].tiers, "the last tier of the first material")
	equal(Prestige.standing(LADDER, wood).title, LADDER[2].name .. " 1", "then the next material")

	local top = Prestige.standing(LADDER, 1e12)
	equal(top.title, LADDER[#LADDER].name .. " " .. LADDER[#LADDER].tiers, "the top")
	equal(top.needed, nil, "with nothing further to earn")
	equal(top.step, top.steps, "at the last step")
	equal(top.steps, 25, "five materials of five tiers, to begin with")
end)

test("reworking the ladder never loses a player their experience or their standing", function()
	local xp = LADDER[1].xp * LADDER[1].tiers + LADDER[2].xp * 2 -- the second material, tier 3
	local before = Prestige.standing(LADDER, xp)
	local peak = Prestige.peak(before)
	equal(before.title, LADDER[2].name .. " 3", "where they stand today")

	-- Later the game makes every tier cost three times as much.
	local harder = {}
	for index, material in LADDER do
		harder[index] = { name = material.name, tiers = material.tiers, xp = material.xp * 3 }
	end
	equal(Prestige.standing(harder, xp).step < before.step, true, "by experience alone they would have dropped")
	local kept = Prestige.standing(harder, xp, peak)
	equal(kept.title, before.title, "but what they had reached is theirs")
	equal(Prestige.standing(harder, 1e12, peak).step, 25, "and they still climb from there")

	-- A new material is added on top, and a sixth tier to each: nobody moves down.
	local taller = {}
	for index, material in LADDER do
		taller[index] = { name = material.name, tiers = material.tiers + 1, xp = material.xp }
	end
	table.insert(taller, { name = "Obsidian", tiers = 6, xp = 20000 })
	equal(Prestige.standing(taller, xp, peak).step >= Prestige.standing(taller, 0, peak).step, true, "experience still counts")
	equal(Prestige.standing(taller, 0, peak).title, before.title, "and a standing is found by its name, wherever it now sits")

	-- A material is renamed away entirely: there is nothing to hold them to, so experience decides.
	local renamed = table.clone(LADDER)
	renamed[2] = { name = "Bronze", tiers = 5, xp = LADDER[2].xp }
	equal(Prestige.standing(renamed, xp, peak).title, "Bronze 3", "the same place under its new name")
	equal(Prestige.standing(LADDER, xp, { name = LADDER[2].name, tier = 99 }).title, LADDER[2].name .. " " .. LADDER[2].tiers,
		"a tier that no longer exists counts as the material's last")
end)

test("kills and assists earn experience for the class of weapon used", function()
	local record = { xp = 0 }
	local kill, assist = ProgressConfig.weapons.xp.kill, ProgressConfig.weapons.xp.assist
	equal(assist < kill, true, "an assist is worth less than a kill")

	local standing, rose = Prestige.earn(LADDER, record, kill)
	equal(record.xp, kill, "experience is what is kept")
	equal(rose, kill >= LADDER[1].xp, "one kill is not a tier, unless a tier is that cheap")
	equal(record.peak.name, standing.name, "and the standing reached is remembered by name")

	standing, rose = Prestige.earn(LADDER, record, LADDER[1].xp)
	equal(rose, true, "a tier's worth is a tier")
	equal(standing.tier, 2, "the second")
	equal(record.peak.tier, 2, "remembered")
end)

test("an SMG never kills in one shot, and gives way to the carbine at range", function()
	local carbine = Weapons[WeaponConfig.DefaultPrimary]
	local found = 0
	for name, config in Weapons do
		if config.class == "SMG" then
			found += 1
			equal(shotsToKill(config, "Head") >= 2, true, name .. " needs two to the head")
			equal(shotsToKill(config, "UpperTorso") >= shotsToKill(carbine, "UpperTorso"), true, name .. " needs no fewer body shots than the carbine")
			equal(config.range < carbine.range, true, name .. " has the shorter reach")
			equal(WeaponConfig.Primaries[name], true, name .. " is a primary")
		end
	end
	equal(found >= 3, true, "there are SMGs to choose from")
end)

test("every weapon but the three everybody starts with has to be rented", function()
	local slots = {
		primary = { order = WeaponConfig.PrimaryOrder, free = WeaponConfig.DefaultPrimary },
		secondary = { order = WeaponConfig.SecondaryOrder, free = WeaponConfig.DefaultSecondary },
		melee = { order = WeaponConfig.MeleeOrder, free = WeaponConfig.DefaultMelee },
	}
	for field, slot in slots do
		for _, name in slot.order do
			local free = Economy.isFree(ShopConfig, field, name)
			equal(free, name == slot.free, name .. (if free then " is free" else " is a rental"))
			equal(Weapons[name] ~= nil, true, name .. " exists")
			equal(type(Weapons[name].displayName), "string", name .. " has a name")
		end
	end
	equal(#WeaponConfig.PrimaryOrder >= 13, true, "the whole armoury is on the list")
	equal(#WeaponConfig.SecondaryOrder, 4, "four handguns")
	equal(#WeaponConfig.MeleeOrder, 4, "four knives")
end)

test("each handgun has its own job", function()
	local sidearm = Weapons[WeaponConfig.DefaultSecondary]
	for _, name in WeaponConfig.SecondaryOrder do
		local gun = Weapons[name]
		equal(gun.class, "Handgun", name .. " is a handgun")
		equal(gun.automatic, false, name .. " fires a shot a pull")
		equal(shotsToKill(gun, "UpperTorso") >= 2, true, name .. " never kills with one body shot")
	end
	equal(shotsToKill(Weapons.Deagle, "UpperTorso"), 2, "the Desert Eagle: two to the body")
	equal(shotsToKill(Weapons.Deagle, "Head"), 1, "one to the head")
	equal(shotsToKill(Weapons.Revolver, "Head"), 1, "the revolver: one to the head")
	equal(shotsToKill(Weapons.Revolver, "UpperTorso"), 3, "three to the body")
	equal(shotsToKill(Weapons.Glock21, "UpperTorso"), shotsToKill(sidearm, "UpperTorso") - 1, "the Glock: a body shot fewer than the sidearm")
	equal(WeaponConfig.DefaultSecondary, "P2020", "the P2020 is the sidearm everybody starts with")
	for _, name in WeaponConfig.SecondaryOrder do
		if name ~= WeaponConfig.DefaultSecondary then
			equal(Weapons[name].magazine < sidearm.magazine, true, name .. " carries fewer rounds than the sidearm")
		end
	end
	-- The hard hitters pay for it in how fast they fire.
	equal(Weapons.Deagle.fireInterval > 2 * sidearm.fireInterval, true, "the Desert Eagle is slow")
	equal(Weapons.Revolver.fireInterval > 2 * sidearm.fireInterval, true, "so is the revolver")
end)

test("each knife trades reach, speed and damage, and all of them backstab", function()
	local field = Weapons[WeaponConfig.DefaultMelee]
	for _, name in WeaponConfig.MeleeOrder do
		local knife = Weapons[name]
		equal(knife.kind, "Melee", name .. " is a melee weapon")
		equal(knife.backDamage >= MatchConfig.maxHealth, true, name .. " kills from behind")
		equal(knife.frontDamage < MatchConfig.maxHealth, true, name .. " does not kill in one from the front")
		equal(knife.backCos > 0 and knife.backCos < 1, true, name .. " has a real backstab cone")
	end
	equal(WeaponConfig.DefaultMelee, "CombatKnife", "the military knife is the one everybody starts with")
	for _, name in WeaponConfig.MeleeOrder do
		if name ~= WeaponConfig.DefaultMelee then
			equal(Weapons[name].frontDamage < field.frontDamage, true, name .. " hits less hard from the front than the military knife")
			equal(Weapons[name].swingInterval <= field.swingInterval, true, name .. " is no slower")
		end
	end
	equal(Weapons.Karambit.swingInterval < Weapons.Bayonet.swingInterval, true, "the karambit is the fastest")
	equal(Weapons.Karambit.reach < field.reach, true, "and the shortest")
	equal(Weapons.Bayonet.reach > field.reach, true, "the bayonet reaches furthest")
	equal(Weapons.Keris.backCos < field.backCos, true, "the keris backstabs from further round")
end)

test("a side left on its own wins, but only when it is truly alone", function()
	equal(Backfill.lastSide({ Alpha = 2, Bravo = 0 }), "Alpha", "the other team has gone")
	equal(Backfill.lastSide({ Alpha = 2, Bravo = 1 }), nil, "short-handed is not abandoned")
	equal(Backfill.lastSide({ Amy = 1, Bo = 0, Cy = 0 }), "Amy", "the last player in a free-for-all")
	equal(Backfill.lastSide({ Alpha = 0, Bravo = 0 }), nil, "nobody at all")
	equal(Backfill.lastSide({ Amy = 1 }), nil, "a match of one has nobody to have left")

	local state = playing()
	MatchState.addKill(MatchConfig, state, "Bravo")
	equal(MatchState.forfeit(MatchConfig, state, "Alpha"), "Ended", "a deathmatch is forfeited")
	equal(state.winner, "Alpha", "to whoever stayed, whatever the score")
	equal(MatchState.forfeit(MatchConfig, MatchState.new(MatchConfig), "Alpha"), nil, "there is nothing to forfeit while waiting")

	local bomb = BombRound.new(MatchConfig)
	equal(BombRound.forfeit(MatchConfig, bomb, "Alpha"), nil, "nor in Search and Destroy")
	BombRound.tick(MatchConfig, bomb, 0, { players = MatchConfig.minPlayers, attackers = 1, attackersAlive = 1, defenders = 1, defendersAlive = 1 })
	equal(BombRound.forfeit(MatchConfig, bomb, "Bravo"), "MatchOver", "a Search and Destroy match is forfeited")
	equal(bomb.winner, "Bravo", "to whoever stayed")
	equal(bomb.phase, "MatchOver", "and is over")
end)

---------------------------------------------------------------- Spectating

test("the dead watch living teammates, and nobody else", function()
	local others = {
		{ name = "Zed", team = "Alpha", alive = true },
		{ name = "Amy", team = "Alpha", alive = true },
		{ name = "Bo", team = "Alpha", alive = false },
		{ name = "Cy", team = "Bravo", alive = true },
		{ name = "Di", team = nil, alive = true },
	}
	local names = Spectate.targets("Alpha", others)
	equal(table.concat(names, " "), "Amy Zed", "living teammates, in a steady order")
	equal(#Spectate.targets("Bravo", others), 1, "the other team sees only its own")
	equal(#Spectate.targets(nil, others), 0, "with no team there is nobody to watch")
	equal(#Spectate.targets("Alpha", {}), 0, "nor with nobody else here")
end)

test("stepping through who to watch wraps round, and recovers when they are gone", function()
	local names = { "Amy", "Bo", "Cy" }
	equal(Spectate.step(names, "Amy", 1), "Bo", "next")
	equal(Spectate.step(names, "Cy", 1), "Amy", "past the end")
	equal(Spectate.step(names, "Amy", -1), "Cy", "back past the start")
	equal(Spectate.step(names, nil, 1), "Amy", "nobody yet: the first")
	equal(Spectate.step(names, "Gone", 1), "Amy", "whoever was watched has gone: the first")
	equal(Spectate.step({ "Amy" }, "Amy", 1), "Amy", "one teammate is all there is")
	equal(Spectate.step({}, "Amy", 1), nil, "nobody left")
end)

test("out for the round, the dead watch a teammate; about to respawn, only the killcam", function()
	local OUT, RESPAWNING = true, false

	-- Search and Destroy: out until the round ends.
	equal(Spectate.afterKillcam(OUT, 2, false, true), "Teammate", "the killcam ends: a teammate's eyes")
	equal(Spectate.afterKillcam(OUT, 2, true, true), "Teammate", "skipped: the same, sooner")
	equal(Spectate.afterKillcam(OUT, 0, false, true), "Body", "last one down: their own body")
	equal(Spectate.afterKillcam(OUT, 2, true, false), "Teammate", "a fall, with nobody to blame")

	-- Team Deathmatch and free-for-all: a respawn is coming, and there is no spectating.
	equal(Spectate.afterKillcam(RESPAWNING, 3, false, true), "Killcam", "left alone, the killcam holds until they are back")
	equal(Spectate.afterKillcam(RESPAWNING, 3, true, true), "Killer", "skipped: follow whoever killed them")
	equal(Spectate.afterKillcam(RESPAWNING, 0, true, true), "Killer", "the same in a free-for-all")
	equal(Spectate.afterKillcam(RESPAWNING, 3, true, false), "Body", "nobody killed them: their own body")
	equal(Spectate.afterKillcam(RESPAWNING, 3, false, false), "Body", "skipped or not")
end)

---------------------------------------------------------------- Icons

test("every icon is a clean grid in colours that are given", function()
	local count = 0
	for name, icon in Icons do
		count += 1
		equal(#icon.rows > 0, true, name .. " has rows")
		local width = #icon.rows[1]
		for index, row in icon.rows do
			equal(#row, width, name .. " row " .. index .. " is as wide as the first")
			for cell in string.gmatch(row, ".") do
				if cell ~= "." then
					equal(type(icon.colors[cell]), "table", name .. " has a colour for '" .. cell .. "'")
				end
			end
		end
	end
	equal(count >= 3, true, "the skull, the headshot skull and the body are all there")
	equal(#Icons.Skull.rows, #Icons.BrainSkull.rows, "the two skulls are the same height, so a row of them lines up")
	equal(#Icons.Skull.rows[1], #Icons.BrainSkull.rows[1], "and the same width")
end)

---------------------------------------------------------------- Ammo

test("every gun starts with a full magazine and three more in reserve", function()
	for name, config in Weapons do
		if config.kind == "Gun" then
			local ammo = Ammo.full(config)
			equal(ammo.mag, config.magazine, name .. " magazine")
			equal(ammo.reserve, 3 * config.magazine, name .. " reserve is three magazines")
		end
	end
	equal(Ammo.full(Weapons.M16).mag .. "/" .. Ammo.full(Weapons.M16).reserve, "30/90", "the rifle")
end)

test("a reload tops the magazine up and wastes nothing", function()
	local rifle = Weapons.M16
	local ammo = { mag = 12, reserve = 90 }
	equal(Ammo.canReload(rifle, ammo), true, "room in the magazine")
	equal(Ammo.reload(rifle, ammo), 18, "eighteen rounds move")
	equal(ammo.mag, 30, "magazine full")
	equal(ammo.reserve, 72, "only what went in left the reserve")
	equal(ammo.mag + ammo.reserve, 102, "nothing was thrown away")

	equal(Ammo.canReload(rifle, ammo), false, "a full magazine does not reload")
	equal(Ammo.reload(rifle, ammo), 0, "and nothing moves if it is tried")

	local low = { mag = 3, reserve = 10 }
	equal(Ammo.reload(rifle, low), 10, "a short reserve gives what it has")
	equal(low.mag, 13, "magazine part filled")
	equal(low.reserve, 0, "reserve empty")
	equal(Ammo.canReload(rifle, low), false, "and then there is nothing to reload with")
end)

test("shooting a gun dry over a life uses exactly four magazines", function()
	for name, config in Weapons do
		if config.kind == "Gun" then
			local ammo = Ammo.full(config)
			local fired = 0
			while ammo.mag > 0 do
				fired += ammo.mag
				ammo.mag = 0
				Ammo.reload(config, ammo)
			end
			equal(fired, 4 * config.magazine, name .. " rounds in a life")
		end
	end
end)

---------------------------------------------------------------- Rentals running out

test("a rental that runs out is noted until the player has been told", function()
	local profile = Economy.newProfile()
	profile.points = 100000
	Economy.buy(ShopConfig, profile, "boots", "Runner", 1, 0)
	Economy.use(ShopConfig, profile, "boots", "Runner", 0)
	local name = Economy.key("boots", "Runner")

	equal(Economy.prune(profile, HOUR), false, "nothing has run out yet")
	equal(next(profile.expired), nil, "so nothing is noted")

	equal(Economy.prune(profile, DAY), true, "the day is up")
	equal(profile.rentals[name], nil, "the rental is gone")
	equal(profile.expired[name], true, "and noted")
	equal(Economy.prune(profile, DAY + 1), false, "it is only reported once")
	equal(profile.expired[name], true, "but stays noted until acknowledged")

	Economy.acknowledge(profile)
	equal(next(profile.expired), nil, "acknowledged")
end)

test("renting something again clears the note that it ran out", function()
	local profile = Economy.newProfile()
	profile.points = 100000
	Economy.buy(ShopConfig, profile, "primary", "MSR", 1, 0)
	Economy.consume(ShopConfig, profile, { primary = "MSR" }, HOUR)
	Economy.prune(profile, 0)
	equal(profile.expired[Economy.key("primary", "MSR")], true, "noted")

	Economy.buy(ShopConfig, profile, "primary", "MSR", 1, 0)
	equal(profile.expired[Economy.key("primary", "MSR")], nil, "renewed, so nothing to tell them")
	equal(Economy.owns(ShopConfig, profile, "primary", "MSR", 0), true, "and owned again")
end)

test("what is taken into a match stays usable until that match is over", function()
	local defaults = Loadout.default(WeaponConfig, TacticalConfig, ArmorConfig)
	local wanted = with(defaults, { primary = "MSR", boots = "Runner" })
	local profile = Economy.newProfile()
	profile.points = 100000
	Economy.buy(ShopConfig, profile, "primary", "MSR", 1, 0)
	Economy.buy(ShopConfig, profile, "boots", "Runner", 1, 0)

	local held = {}
	local first = Economy.equip(ShopConfig, profile, wanted, defaults, 0, held)
	equal(first.primary, "MSR", "spawned with the rifle")
	equal(held[Economy.key("primary", "MSR")], true, "which is now held")
	equal(held[Economy.key("boots", "Runner")], true, "and so are the boots")
	equal(held[Economy.key("body", defaults.body)], nil, "free options are not rentals")

	-- Both run out mid-match: the rifle is used up, the boots' day ends.
	Economy.consume(ShopConfig, profile, first, 2 * HOUR)
	local later = 2 * DAY
	equal(Economy.owns(ShopConfig, profile, "primary", "MSR", later), false, "used up, as far as the shop goes")
	equal(Economy.owns(ShopConfig, profile, "primary", "MSR", later, held), true, "but still theirs in this match")
	equal(Economy.ownsAll(ShopConfig, profile, wanted, later, held), true, "so the loadout still passes")

	local nextLife = Economy.equip(ShopConfig, profile, wanted, defaults, later, held)
	equal(nextLife.primary, "MSR", "they respawn with it")
	equal(nextLife.boots, "Runner", "and with the boots")

	-- Saving in the middle of the match must not take it away either.
	Economy.prune(profile, later)
	local afterSave = Economy.equip(ShopConfig, profile, wanted, defaults, later, held)
	equal(afterSave.primary, "MSR", "still held after the rental is pruned")

	-- The match ends: nothing is held any more.
	local nextMatch = Economy.equip(ShopConfig, profile, wanted, defaults, later, {})
	equal(nextMatch.primary, defaults.primary, "next match it is the default rifle")
	equal(nextMatch.boots, defaults.boots, "and the default boots")
	equal(profile.expired[Economy.key("primary", "MSR")], true, "and the player is owed a notice")
end)

test("an unowned item cannot be slipped into a match through the held list", function()
	local defaults = Loadout.default(WeaponConfig, TacticalConfig, ArmorConfig)
	local profile = Economy.newProfile()
	local held = {}
	local got = Economy.equip(ShopConfig, profile, with(defaults, { primary = "MSR" }), defaults, 0, held)
	equal(got.primary, defaults.primary, "never rented, so not given")
	equal(next(held), nil, "and nothing is held")
end)

test("a saved loadout loses only what ran out", function()
	local defaults = Loadout.default(WeaponConfig, TacticalConfig, ArmorConfig)
	local saved = with(defaults, { primary = "MSR", helmet = "Listener" })
	local profile = Economy.newProfile()
	profile.points = 100000
	Economy.buy(ShopConfig, profile, "helmet", "Listener", 1, 0)

	local kept = Economy.fallback(ShopConfig, profile, saved, defaults, 0)
	equal(kept.helmet, "Listener", "the helmet they still have stays")
	equal(kept.primary, defaults.primary, "the rifle they do not goes back to the default")
	equal(profile.rentals[Economy.key("helmet", "Listener")].expiresAt, nil, "and looking starts no clock")
end)

---------------------------------------------------------------- Catalog

test("every rental on sale is something the catalogue can name", function()
	local fields = Catalog.fields(WeaponConfig, TacticalConfig, ArmorConfig)
	for field, prices in ShopConfig.prices do
		for option in prices do
			local entry, item = Catalog.find(fields, Economy.key(field, option))
			equal(entry ~= nil, true, field .. "/" .. option .. " is in the catalogue")
			equal(type(item.displayName), "string", field .. "/" .. option .. " has a name")
			equal(table.find(entry.order, option) ~= nil, true, field .. "/" .. option .. " is listed in its field")
		end
	end
	equal(Catalog.find(fields, "boots/Nothing"), nil, "an option that does not exist")
	equal(Catalog.find(fields, "nonsense"), nil, "a name that is not a rental")
end)

---------------------------------------------------------------- Revives

local REVIVE = with(MatchConfig.revive, { productId = 1 })

test("revives are off until a product is set, and never in a free-for-all", function()
	equal(MatchConfig.revive.productId, 0, "shipped switched off")
	equal(Revive.rules(MatchConfig.revive, "SND"), nil, "so nothing is offered")
	equal(Revive.rules(REVIVE, "SND") ~= nil, true, "Search and Destroy has them")
	equal(Revive.rules(REVIVE, "TDM") ~= nil, true, "Team Deathmatch has them")
	equal(Revive.rules(REVIVE, "FFA"), nil, "a free-for-all does not")
end)

test("a revive is limited per round in Search and Destroy, per match in Team Deathmatch", function()
	local snd, tdm = Revive.rules(REVIVE, "SND"), Revive.rules(REVIVE, "TDM")
	equal(Revive.available(snd, 0), true, "first of the round")
	equal(Revive.available(snd, snd.limit), false, "no more this round")
	equal(Revive.resetsOn(snd, "RoundStarted"), true, "a new round allows another")
	equal(Revive.resetsOn(tdm, "RoundStarted"), false, "Team Deathmatch counts by the match")
	equal(Revive.resetsOn(tdm, "Started"), true, "a new match starts the count again")
	equal(Revive.resetsOn(snd, "Planted"), false, "nothing else does")
	equal(Revive.available(nil, 0), false, "no rules, no revive")
end)

test("a revive undoes the kill in Team Deathmatch and not in Search and Destroy", function()
	local snd = Revive.undo(Revive.rules(REVIVE, "SND"), true)
	equal(snd.deaths, 0, "SND: the death stands")
	equal(snd.points, 0, "SND: nothing comes off the score")

	local tdm = Revive.undo(Revive.rules(REVIVE, "TDM"), true)
	equal(tdm.deaths, -1, "TDM: the death comes off")
	equal(tdm.points, -1, "TDM: and so does the other team's point")
	equal(tdm.kills, -1, "TDM: and the kill on the killer's own count")
	equal(snd.kills, 0, "SND: the killer keeps theirs")
	local unscored = Revive.undo(Revive.rules(REVIVE, "TDM"), false)
	equal(unscored.points, 0, "nothing comes off the score if the kill never counted")
	equal(unscored.kills, 0, "nor off the killer")
	equal(unscored.deaths, -1, "but the death still does")
end)

test("a point can be taken back, but never below zero or outside play", function()
	local state = MatchState.new(MatchConfig)
	equal(MatchState.removeKill(state, "Alpha"), false, "not while waiting")
	state = playing()
	equal(MatchState.removeKill(state, "Alpha"), false, "nothing to take back")
	MatchState.addKill(MatchConfig, state, "Alpha")
	MatchState.addKill(MatchConfig, state, "Alpha")
	equal(MatchState.removeKill(state, "Alpha"), true, "one comes off")
	equal(state.scores.Alpha, 1, "score")
	equal(MatchState.removeKill(state, "Nobody"), false, "a side that is not playing")
end)

test("a Robux purchase is counted once, however often it is reported", function()
	local profile = Economy.newProfile()
	equal(Economy.spend(profile, "revives"), false, "none to spend")
	equal(Economy.grant(profile, "revives", "purchase-1"), true, "first report")
	equal(Economy.grant(profile, "revives", "purchase-1"), false, "the same purchase again")
	equal(profile.revives, 1, "one revive")
	equal(Economy.grant(profile, "revives", "purchase-2"), true, "a second purchase")
	equal(profile.revives, 2, "two")
	equal(Economy.spend(profile, "revives"), true, "spent")
	equal(profile.revives, 1, "one left for next time")

	-- Armour changes are bought the same way and counted apart.
	equal(Economy.grant(profile, "swaps", "purchase-3"), true, "an armour change")
	equal(profile.swaps, 1, "one swap")
	equal(profile.revives, 1, "and the revives are untouched")
	equal(Economy.grant(profile, "swaps", "purchase-1"), false, "a receipt is never counted twice, whatever it was for")

	-- A profile saved before any of this existed has neither count nor receipts.
	local old = { points = 0, xp = 0, level = 1, rentals = {}, expired = {} }
	equal(Economy.spend(old, "swaps"), false, "an older profile has none")
	equal(Economy.grant(old, "swaps", "purchase-9"), true, "and is granted one")
	equal(old.swaps, 1, "which is counted")
end)

---------------------------------------------------------------- Changing a loadout in a match

test("a second primary is owned as a primary", function()
	local profile = Economy.newProfile()
	profile.points = 100000
	equal(Economy.owns(ShopConfig, profile, "primary2", "MSR", 0), false, "not rented")
	equal(Economy.owns(ShopConfig, profile, "primary2", WeaponConfig.DefaultPrimary, 0), true, "the free rifle is free in either place")
	Economy.buy(ShopConfig, profile, "primary", "MSR", 1, 0)
	equal(Economy.owns(ShopConfig, profile, "primary2", "MSR", 0), true, "renting it once covers both places")
	equal(Economy.owns(ShopConfig, profile, "nade2", "Smoke", 0), false, "a grenade not rented")

	-- Time alive with it as the second primary runs it down just the same.
	local loadout = with(Loadout.default(WeaponConfig, TacticalConfig, ArmorConfig), { primary2 = "MSR" })
	Economy.consume(ShopConfig, profile, loadout, 600)
	equal(Economy.timeLeft(profile, "primary", "MSR", 0), HOUR - 600, "ten minutes used")
end)

test("a weapon not carried last life costs points, and only that", function()
	local fee = ShopConfig.matchSwap.weaponPoints
	local fields = Loadout.WEAPON_FIELDS
	local before = { primary = "M16", secondary = "P2020", melee = "CombatKnife", nade = "Frag", boots = "Soft" }
	local function charge(points, wanted)
		local profile = Economy.newProfile()
		profile.points = points
		local got, cost, went = Economy.chargeSwaps(ShopConfig, profile, before, wanted, fields)
		return got, cost, went, profile.points
	end

	local got, cost, went, left = charge(100, table.clone(before))
	equal(cost, 0, "the same weapons cost nothing")
	equal(went, true, "and go through")
	equal(left, 100, "points untouched")

	got, cost, went, left = charge(100, with(before, { primary = "MSR" }))
	equal(cost, fee, "one new weapon")
	equal(got.primary, "MSR", "which they get")
	equal(left, 100 - fee, "and pay for")

	got, cost = charge(100, with(before, { primary = "MSR", nade = "Smoke" }))
	equal(cost, 2 * fee, "a new weapon and a new grenade")

	got, cost = charge(100, with(before, { primary2 = "MSR" }))
	equal(cost, fee, "a second primary is one more weapon")

	local two = with(before, { primary2 = "MSR" })
	local profile = Economy.newProfile()
	profile.points = 100
	local _, swapCost = Economy.chargeSwaps(ShopConfig, profile, two, with(before, { primary = "MSR", primary2 = "M16" }), fields)
	equal(swapCost, 0, "the same two guns the other way round are not new")
	_, swapCost = Economy.chargeSwaps(ShopConfig, profile, two, before, fields)
	equal(swapCost, 0, "nor is carrying fewer")

	got, cost, went, left = charge(100, with(before, { boots = "Runner" }))
	equal(cost, 0, "armour is not a weapon")
	equal(got.boots, "Runner", "and passes straight through")
end)

test("a weapon change that cannot be paid for does not happen at all", function()
	local fee = ShopConfig.matchSwap.weaponPoints
	local before = { primary = "M16", secondary = "P2020", melee = "CombatKnife", nade = "Frag", boots = "Soft" }
	local profile = Economy.newProfile()
	profile.points = 2 * fee - 1 -- enough for one new weapon, not two

	local wanted = with(before, { primary = "MSR", nade = "Smoke", boots = "Runner" })
	local got, cost, went = Economy.chargeSwaps(ShopConfig, profile, before, wanted, Loadout.WEAPON_FIELDS)
	equal(went, false, "refused")
	equal(cost, 0, "nothing charged")
	equal(profile.points, 2 * fee - 1, "points untouched")
	equal(got.primary, "M16", "the old primary stays")
	equal(got.nade, "Frag", "and the old grenade: it is all or nothing")
	equal(got.boots, "Runner", "but the rest of the loadout is as asked")
	equal(wanted.primary, "MSR", "and what was asked for is not altered")
end)

print(string.format("%d passed, %d failed", passed, failed))
process.exit(failed == 0 and 0 or 1)
