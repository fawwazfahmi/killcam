-- Plays the test range, without anybody at the keyboard. Run it against the
-- built range place through run-in-roblox (see the README):
--
--   rojo build range.project.json -o build/range.rbxl
--   run-in-roblox --place build/range.rbxl --script tools/studio/rangetest.luau
--
-- The smoke test only loads the code. This starts a real play session, with a
-- real server and a real client, and has the client do what a player's game
-- does: it sends the same shots, swings, throws and panel requests over the
-- same remotes, and checks what the server sends back. So it covers what the
-- smoke test cannot: spawning, hit validation, damage through armour, dummies
-- dying and walking and shooting back, every switch on the panel, and whether
-- any of the game's own client code throws an error on the way.
--
-- What it still cannot do is look at the screen or press a key: the picture,
-- the feel of the controls and the layout of the panel have to be seen by eye.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

-- run-in-roblox starts this script again inside the play session it begins.
-- That copy has only to stay out of the way until the session is over.
if RunService:IsRunning() then
	task.wait(900)
	return
end

local TIME_ALLOWED = 150 -- seconds before the session is ended whatever has happened

-- On the server of the play session: gathers what the client reports, and
-- ends the session with it.
local SERVER = [==[
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")

local lines = {}
local over = false

local function finish(verdict)
	if over then
		return
	end
	over = true
	-- Anything the server itself complained of while the range was played.
	for _, entry in LogService:GetLogHistory() do
		if entry.messageType == Enum.MessageType.MessageError or entry.messageType == Enum.MessageType.MessageWarning then
			table.insert(lines, "SERVER " .. entry.messageType.Name .. "  " .. entry.message)
		end
	end
	table.insert(lines, verdict)
	StudioTestService:EndTest(table.concat(lines, "\n"))
end

local probe = Instance.new("RemoteEvent")
probe.Name = "RangeProbe"
probe.OnServerEvent:Connect(function(_player, kind, text)
	if kind == "log" then
		table.insert(lines, tostring(text))
	elseif kind == "done" then
		finish(tostring(text))
	end
end)
probe.Parent = ReplicatedStorage

task.delay(StudioTestService:GetTestArgs(), function()
	finish("=== ran out of time before the client finished")
end)
]==]

-- On the client: plays the range.
local CLIENT = [==[
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local probe = ReplicatedStorage:WaitForChild("RangeProbe")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmorConfig = require(Shared.Config.ArmorConfig)
local MatchConfig = require(Shared.Config.MatchConfig)
local MovementConfig = require(Shared.Config.MovementConfig)
local RangeConfig = require(Shared.Config.RangeConfig)
local Theme = require(Shared.Config.Theme)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local Remotes = require(Shared.Remotes)

local Weapons = WeaponConfig.Weapons
local FULL = MatchConfig.maxHealth
local passed, failed = 0, 0

local function say(text)
	probe:FireServer("log", text)
end

local function expect(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function check(name, body)
	local ok, problem = pcall(body)
	if ok then
		passed += 1
		say("ok    " .. name)
	else
		failed += 1
		say("FAIL  " .. name .. "\n      " .. tostring(problem))
	end
end

local function waitFor(what, condition, seconds)
	local started = os.clock()
	while os.clock() - started < (seconds or 4) do
		local result = condition()
		if result then
			return result
		end
		task.wait(0.03)
	end
	error("waited in vain for " .. what, 2)
end

local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 0.01)
end

-- Everything the server sends, kept to be read.
local range, loadout = nil, nil
local hits, feed, hurts, confirms = {}, {}, {}, {}
local pushes = 0
Remotes.RangeUpdate.OnClientEvent:Connect(function(update)
	range = update
end)
Remotes.LoadoutUpdate.OnClientEvent:Connect(function(payload)
	loadout = payload
	pushes += 1
end)
Remotes.RangeHit.OnClientEvent:Connect(function(hit)
	table.insert(hits, hit)
end)
Remotes.KillFeed.OnClientEvent:Connect(function(killer, victim, weapon)
	table.insert(feed, { killer = killer, victim = victim, weapon = weapon })
end)
Remotes.Damaged.OnClientEvent:Connect(function(amount, _from, flinch)
	table.insert(hurts, { amount = amount, flinch = flinch })
end)
Remotes.HitConfirm.OnClientEvent:Connect(function(headshot, killed)
	table.insert(confirms, { headshot = headshot, killed = killed })
end)

local function ask(...)
	Remotes.RangeCommand:FireServer(...)
end

local function humanoid()
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end

local function root()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function dummyNamed(label)
	for _, dummy in range.dummies do
		if dummy.label == label then
			return dummy
		end
	end
	return nil
end

-- The living body of a dummy, by its id.
local function bodyOf(id)
	for _, model in workspace.Dummies:GetChildren() do
		local being = model:FindFirstChildOfClass("Humanoid")
		if model:GetAttribute("Dummy") == id and being and being.Health > 0 then
			return model
		end
	end
	return nil
end

-- Asks for something that changes the dummies and waits for the server to say so.
local function setDummy(target, field, value)
	ask("Dummy", target, field, value)
	waitFor("the dummy to be set", function()
		for _, dummy in range.dummies do
			if (target == "all" or dummy.id == target) and dummy.settings[field] ~= value then
				return false
			end
		end
		return true
	end)
end

local function setCheat(name, on)
	ask("Cheat", name, on)
	waitFor("the switch " .. name, function()
		return (range.cheats[name] == true) == on
	end)
end

-- The server answers any loadout request, even an empty one, with the state it holds.
local function freshLoadout()
	local before = pushes
	Remotes.SelectLoadout:FireServer({})
	waitFor("the loadout", function()
		return pushes > before
	end)
	return loadout
end

-- One shot at `part`, sent as the weapon controller sends it. Returns the report.
local function shoot(part)
	local before = #hits
	Remotes.FireShot:FireServer(player.Character.Head.Position, part.Position, part)
	waitFor("the hit to be reported", function()
		return #hits > before
	end)
	task.wait(0.16) -- no faster than the gun
	return hits[#hits]
end

local function taken(since)
	local list = {}
	for index = since + 1, #hits do
		if hits[index].taken then
			table.insert(list, hits[index])
		end
	end
	return list
end

-- Arrival ---------------------------------------------------------------------

check("the player is let in and spawned", function()
	waitFor("a living character", function()
		local being = humanoid()
		return being and being.Health > 0 and root() ~= nil
	end, 20)
	expect(humanoid().Health == FULL, "not at full health")
end)

check("every screen is built", function()
	local playerGui = player:WaitForChild("PlayerGui")
	for _, name in { "TdmHud", "LoadoutMenu", "Spectate", "KillMarks", "RangeReadout", "RangePanel", "RangeStatus" } do
		waitFor("the screen " .. name, function()
			return playerGui:FindFirstChild(name)
		end, 10)
	end
	waitFor("the range's name where the score goes", function()
		for _, label in playerGui.TdmHud:GetDescendants() do
			if label:IsA("TextLabel") and label.Text == "TEST RANGE" then
				return true
			end
		end
		return false
	end, 10)
end)

check("the server lists the dummies, the switches and the places", function()
	ask("Cheat", "god", false) -- any request is answered with the whole state
	waitFor("the range's state", function()
		return range ~= nil and #range.dummies > 0
	end, 20)
	for _, label in { "15 STUDS", "400 STUDS", "PIT 25", "FACING YOU", "BACK TURNED" } do
		expect(dummyNamed(label) ~= nil, "no dummy called " .. label)
	end
	expect(#workspace.Dummies:GetChildren() == #range.dummies, "the dummies listed are not the dummies standing")
	expect(next(range.cheats) == nil, "a switch is on before anybody touched one")
	expect(#range.spots >= 5 and range.spots[1].name == "Firing line", "the places are missing")
	say(string.format("      %d dummies, %d places", #range.dummies, #range.spots))
end)

freshLoadout()
local gun = loadout.slots[1]
local rifle = Weapons[gun]
local facing = dummyNamed("FACING YOU")
local turned = dummyNamed("BACK TURNED")
task.wait(0.6) -- the draw

-- Shooting --------------------------------------------------------------------

check("everything is unlocked: the loadout is the default and nothing is refused", function()
	expect(gun == WeaponConfig.DefaultPrimary, "the primary is " .. tostring(gun))
	expect(loadout.ammo[gun].mag == rifle.magazine, "the magazine is not full")
end)

check("a headshot on a new dummy is halved by its helmet, and reported in full", function()
	local body = bodyOf(facing.id)
	local hit = shoot(body.Head)
	local helmet = ArmorConfig.helmet[ArmorConfig.defaults.helmet]
	expect(not hit.taken and hit.target == facing.id and hit.label == "FACING YOU", "the report names the wrong target")
	expect(hit.weapon == gun and hit.zone == "Head", "the report names the wrong weapon or place")
	expect(hit.raw == rifle.damage.Head, "raw damage is " .. tostring(hit.raw))
	expect(near(hit.amount, rifle.damage.Head * helmet.headScale), "damage after the helmet is " .. tostring(hit.amount))
	expect(near(hit.left, FULL - hit.amount) and not hit.lethal, "health left is " .. tostring(hit.left))
	expect(near(hit.distance, (body.Head.Position - player.Character.Head.Position).Magnitude, 1), "the distance is " .. tostring(hit.distance))
	expect(typeof(hit.at) == "Vector3", "the report does not say where it landed")
	expect(near(body.Humanoid.Health, hit.left), "the dummy's own health disagrees")
	expect(confirms[#confirms].headshot == true and confirms[#confirms].killed == false, "the hit marker was not told")
	say(string.format("      %s to the head: %s before armour, %s after, %s left", gun, hit.raw, hit.amount, hit.left))
end)

check("body armour takes its share off a chest shot and a leg shot", function()
	local body = bodyOf(facing.id)
	local plate = ArmorConfig.body[ArmorConfig.defaults.body].classScale[rifle.class] or 1
	local chest = shoot(body.UpperTorso)
	expect(chest.zone == "UpperTorso" and near(chest.amount, rifle.damage.UpperTorso * plate), "chest: " .. tostring(chest.amount))
	local leg = shoot(body.LeftFoot)
	expect(leg.zone == "Limb" and near(leg.amount, rifle.damage.Limb * plate), "leg: " .. tostring(leg.amount))
	say(string.format("      chest %s > %s, leg %s > %s", chest.raw, chest.amount, leg.raw, leg.amount))
end)

check("a dummy that dies falls, is in the kill feed, and is back in a moment", function()
	local body = bodyOf(facing.id)
	local last
	for _ = 1, 6 do
		last = shoot(body.UpperTorso)
		if last.lethal then
			break
		end
	end
	expect(last.lethal and last.left == 0, "it never died")
	expect(confirms[#confirms].killed == true, "no kill mark")
	waitFor("the kill feed", function()
		local line = feed[#feed]
		return line and line.killer == player.Name and line.victim == "FACING YOU"
	end)
	expect(bodyOf(facing.id) == nil, "its body is still alive")
	local again = waitFor("the dummy to stand up again", function()
		return bodyOf(facing.id)
	end, RangeConfig.dummy.respawnAfter + 3)
	expect(again ~= body and again.Humanoid.Health == FULL, "it is not whole")
end)

check("the readout lists the hits and adds them up", function()
	local words = {}
	for _, label in player.PlayerGui.RangeReadout:GetDescendants() do
		if label:IsA("TextLabel") and label.Text ~= "" then
			table.insert(words, label.Text)
		end
	end
	local all = table.concat(words, " | ")
	say("      readout: " .. all)
	expect(string.find(all, "HEAD") and string.find(all, "UPPERTORSO") and string.find(all, "KILL"), "a hit is missing from the list")
	expect(string.find(all, "KILLED IN %d+ HITS"), "the kill is not added up")
	expect(string.find(all, "FACING YOU"), "the totals do not name the dummy")
end)

check("a dummy told to stay up counts the kill and is whole again at once", function()
	setDummy(facing.id, "dies", false)
	local body = bodyOf(facing.id)
	local last
	for _ = 1, 6 do
		last = shoot(body.UpperTorso)
		if last.lethal then
			break
		end
	end
	expect(last.lethal, "the killing hit was not counted as one")
	expect(last.left == FULL and body.Humanoid.Health == FULL, "it is not back at full health")
	expect(bodyOf(facing.id) == body, "it fell anyway")
end)

check("a bare dummy takes all of it, and each dummy can be set alone", function()
	setDummy(facing.id, "helmet", "")
	setDummy(facing.id, "body", "")
	local hit = shoot(bodyOf(facing.id).Head)
	expect(hit.amount == rifle.damage.Head and hit.raw == hit.amount, "a bare head took " .. tostring(hit.amount))
	local chest = shoot(bodyOf(facing.id).UpperTorso)
	expect(chest.amount == rifle.damage.UpperTorso, "a bare chest took " .. tostring(chest.amount))
	expect(dummyNamed("BACK TURNED").settings.helmet == ArmorConfig.defaults.helmet, "another dummy lost its helmet too")
	local other = shoot(bodyOf(turned.id).Head)
	expect(near(other.amount, rifle.damage.Head * ArmorConfig.helmet[ArmorConfig.defaults.helmet].headScale), "the other dummy is not armoured")
	setDummy("all", "helmet", "Listener")
	for _, dummy in range.dummies do
		expect(dummy.settings.helmet == "Listener", dummy.label .. " did not change with the rest")
	end
	setDummy("all", "helmet", ArmorConfig.defaults.helmet)
	setDummy("all", "body", ArmorConfig.defaults.body)
end)

check("what a dummy cannot be set to is refused", function()
	ask("Dummy", facing.id, "helmet", "Plate")
	ask("Dummy", facing.id, "weapon", "Frag")
	ask("Dummy", facing.id, "dies", "no")
	ask("Dummy", "everyone", "dies", false)
	ask("Nonsense")
	ask("Go", "somewhere")
	ask("Hurt", 7)
	task.wait(0.5)
	local now = dummyNamed("FACING YOU").settings
	expect(now.helmet == ArmorConfig.defaults.helmet and now.weapon == "" and now.dies == false, "a bad setting got through")
	expect(humanoid().Health == FULL, "an amount not on the panel was taken off")
end)

-- The admin's own switches ------------------------------------------------------

check("the panel can take health off, heal, and hit with any gun through armour", function()
	local before = #hits
	ask("Hurt", RangeConfig.hurt[2])
	waitFor("the health to drop", function()
		return humanoid().Health == FULL - RangeConfig.hurt[2]
	end)
	local plain = taken(before)[1]
	expect(plain and plain.zone == "Plain" and plain.amount == RangeConfig.hurt[2], "the plain hit was not reported")
	ask("Heal")
	waitFor("the heal", function()
		return humanoid().Health == FULL
	end)

	before = #hits
	local flinches = #hurts
	ask("Hit", "M16", "Chest")
	local hit = waitFor("the hit", function()
		return taken(before)[1]
	end)
	local plate = ArmorConfig.body[loadout.loadout.body].classScale.Rifle or 1
	expect(near(hit.amount, Weapons.M16.damage.UpperTorso * plate), "through armour it did " .. tostring(hit.amount))
	expect(near(humanoid().Health, FULL - hit.amount), "health is " .. tostring(humanoid().Health))
	-- The armour that took damage off the hit takes the edge off the knock too.
	local knock = WeaponConfig.Flinch.body * (if plate < 1 then WeaponConfig.Flinch.covered else 1)
	expect(#hurts > flinches and hurts[#hurts].flinch == knock, "being hit threw the aim " .. tostring(hurts[#hurts] and hurts[#hurts].flinch))
	ask("Heal")
end)

check("god mode stops the damage and still reports it", function()
	waitFor("full health", function()
		return humanoid().Health == FULL
	end)
	setCheat("god", true)
	waitFor("the shield", function()
		return player.Character:FindFirstChild("GodMode")
	end)
	local before = #hits
	ask("Hit", "AWP", "Head")
	local hit = waitFor("the hit", function()
		return taken(before)[1]
	end)
	expect(hit.shielded == true and hit.raw == Weapons.AWP.damage.Head, "the hit was not marked as stopped")
	task.wait(0.2)
	expect(humanoid().Health == FULL, "god mode let damage through")
end)

check("the ammunition switches keep the magazine and the reserve full", function()
	local body = bodyOf(facing.id)
	setCheat("magazine", true)
	for _ = 1, 4 do
		shoot(body.LeftFoot)
	end
	task.wait(0.5)
	expect(freshLoadout().ammo[gun].mag == rifle.magazine, "the magazine ran down")
	setCheat("magazine", false)
	shoot(body.LeftFoot)
	shoot(body.LeftFoot)
	local left = freshLoadout().ammo[gun].mag
	expect(left == rifle.magazine - 2, "without the switch, two shots left " .. tostring(left) .. " in the magazine")

	Remotes.Reload:FireServer()
	waitFor("the reload", function()
		return freshLoadout().ammo[gun].mag == rifle.magazine
	end, rifle.reloadTime + 2)
	expect(loadout.ammo[gun].reserve == rifle.reserve - 2, "after the reload the reserve is " .. tostring(loadout.ammo[gun].reserve))
	setCheat("reserve", true)
	task.wait(0.5)
	expect(freshLoadout().ammo[gun].reserve == rifle.reserve, "the reserve was not topped up")
	setCheat("reserve", false)
end)

check("the tactical item comes back with its switch on", function()
	Remotes.UseTactical:FireServer()
	waitFor("the tactical item to be used", function()
		return freshLoadout().tacticalUses == 0
	end)
	setCheat("tactical", true)
	waitFor("it to come back", function()
		return freshLoadout().tacticalUses > 0
	end)
	setCheat("tactical", false)
end)

check("a loadout change waits for the next spawn, or with the switch on happens at once", function()
	local wanted = table.clone(freshLoadout().choice)
	wanted.primary = "MP5"
	Remotes.SelectLoadout:FireServer(wanted)
	task.wait(0.4)
	expect(freshLoadout().choice.primary == "MP5", "a weapon nobody owns was refused")
	expect(loadout.slots[1] == gun, "the weapon in hand changed without the switch")

	setCheat("instant", true)
	wanted.primary = "AK47"
	wanted.helmet = "Listener"
	wanted.gloves = "Gunner"
	wanted.primary2 = "AWP"
	Remotes.SelectLoadout:FireServer(wanted)
	waitFor("the new loadout to be in hand", function()
		return loadout.slots[1] == "AK47" and loadout.slots[6] == "AWP"
	end)
	expect(loadout.loadout.helmet == "Listener" and loadout.loadout.gloves == "Gunner", "armour did not change on the range")
	expect(humanoid().Health > 0, "changing loadout killed the player")
	setCheat("instant", false)
	task.wait(0.6) -- the draw
end)

check("how far a hit throws the aim follows the armour worn, and the Subzero stops it", function()
	local rules = WeaponConfig.Flinch
	local whole, less = rules.body, rules.body * rules.covered
	setCheat("instant", true)

	local function wear(helmet, body)
		local wanted = table.clone(freshLoadout().choice)
		wanted.helmet, wanted.body = helmet, body
		Remotes.SelectLoadout:FireServer(wanted)
		waitFor("the armour to be on", function()
			return loadout.loadout.helmet == helmet and loadout.loadout.body == body
		end)
	end
	-- One hit from the panel. Returns how far it threw the aim, and the hit.
	local function knockFrom(weapon, aim)
		local before, felt = #hits, #hurts
		ask("Hit", weapon, aim)
		local hit = waitFor("the hit", function()
			return taken(before)[1]
		end)
		waitFor("the knock to reach the view", function()
			return #hurts > felt
		end)
		expect(hurts[#hurts].flinch == hit.knock, "the readout says " .. tostring(hit.knock) .. " and the view was thrown " .. tostring(hurts[#hurts].flinch))
		task.wait(0.08)
		return hit.knock, hit
	end
	local function same(got, wanted, what)
		expect(got == wanted, string.format("%s: thrown %s, should be %s", what, tostring(got), tostring(wanted)))
	end

	wear("Guard", "Plate")
	same(knockFrom("M16", "Chest"), less, "a rifle against Plate")
	same(knockFrom("MP5", "Stomach"), less, "an SMG against Plate")
	same(knockFrom("AWP", "Chest"), whole, "a sniper against Plate, which does not cover it")
	same(knockFrom("M16", "Head"), rules.head * rules.covered, "a headshot against the Guard")

	wear("Listener", "Deflector")
	same(knockFrom("AWP", "Chest"), less, "a sniper against Deflector")
	same(knockFrom("M16", "Chest"), whole, "a rifle against Deflector, which does not cover it")
	same(knockFrom("M16", "Head"), rules.head, "a headshot against the Listener, which does not protect the head")

	wear("Listener", "Light")
	same(knockFrom("M16", "Legs"), whole, "a rifle against no protection")
	same(knockFrom("AWP", "Chest"), whole, "a sniper against no protection")

	wear("Subzero", "Light")
	local knock, head = knockFrom("AWP", "Head")
	same(knock, 0, "a sniper to the head of a Subzero")
	expect(head.amount == Weapons.AWP.damage.Head * ArmorConfig.helmet.Subzero.headScale, "the Subzero let a headshot do " .. tostring(head.amount))
	same(knockFrom("M16", "Chest"), 0, "a rifle to the chest under a Subzero")
	same(knockFrom("Deagle", "Legs"), 0, "a handgun to the legs under a Subzero")
	say(string.format("      knock: %.1f uncovered, %.1f covered, head %.1f or %.1f, Subzero 0", whole, less, rules.head, rules.head * rules.covered))

	wear("Listener", "Plate")
	setCheat("instant", false)
end)

-- Places, placing, the knife and the grenade -----------------------------------

check("the panel sends the player to a place", function()
	local index
	for at, spot in range.spots do
		if spot.name == "Knife dummies" then
			index = at
		end
	end
	ask("Go", #range.spots) -- the top of the drop tower
	waitFor("to be up the tower", function()
		return root().Position.Y > 30
	end)
	ask("Go", index)
	waitFor("to be back on the ground", function()
		return root().Position.Y < 8 and math.abs(root().Position.Z - 228) < 6
	end)
end)

local placed = nil
check("a dummy can be placed where asked, facing whoever placed it", function()
	local count = #range.dummies
	local at = root().Position + Vector3.new(0, 0, -6)
	ask("Place", at)
	waitFor("the new dummy", function()
		return #range.dummies == count + 1
	end)
	placed = range.dummies[#range.dummies]
	expect(placed.placed == true and string.find(placed.label, "PLACED"), "it is not marked as placed")
	local body = waitFor("its body", function()
		return bodyOf(placed.id)
	end)
	local stands = body.HumanoidRootPart
	expect(near(stands.Position.X, at.X, 0.5) and near(stands.Position.Z, at.Z, 0.5), "it is not where it was asked for")
	local toPlayer = ((root().Position - stands.Position) * Vector3.new(1, 0, 1)).Unit
	expect(stands.CFrame.LookVector:Dot(toPlayer) > 0.9, "it is not facing the player")
	ask("Place", Vector3.new(0, 0, 5000))
	task.wait(0.3)
	expect(#range.dummies == count + 1, "one was placed off the map")
end)

check("the knife hits a dummy for its front damage, whatever it wears", function()
	local knife = Weapons[loadout.slots[3]]
	Remotes.EquipSlot:FireServer(3)
	task.wait(knife.equipTime + 0.2)
	local before = #hits
	Remotes.MeleeSwing:FireServer(bodyOf(placed.id).UpperTorso)
	waitFor("the stab to be reported", function()
		return #hits > before
	end)
	local hit = hits[#hits]
	expect(hit.zone == "Front" and hit.amount == knife.frontDamage, "the stab did " .. tostring(hit.amount) .. " to the " .. tostring(hit.zone))
	say(string.format("      %s from the front: %s", loadout.slots[3], hit.amount))
end)

check("a frag hurts a dummy by how near it lands, and the grenade switch gives it back", function()
	setCheat("grenades", true)
	Remotes.EquipSlot:FireServer(4)
	task.wait(Weapons.Frag.equipTime + 0.2)
	local before = #hits
	Remotes.ThrowGrenade:FireServer(Vector3.new(0, -1, -0.2))
	waitFor("the grenade to come back", function()
		return freshLoadout().slots[4] == "Frag"
	end)
	local blast = waitFor("the blast to be reported", function()
		for index = before + 1, #hits do
			if hits[index].zone == "Blast" then
				return hits[index]
			end
		end
		return nil
	end, Weapons.Frag.fuse + 3)
	local expected = Weapons.Frag.maxDamage * (1 - blast.distance / Weapons.Frag.radius)
	expect(near(blast.amount, expected, 0.5), string.format("%.1f at %.1f studs, where the rule gives %.1f", blast.amount, blast.distance, expected))
	expect(humanoid().Health == FULL, "god mode did not hold against the player's own grenade")
	say(string.format("      frag on %s: %.1f at %.1f studs", blast.label, blast.amount, blast.distance))
	setCheat("grenades", false)
	Remotes.EquipSlot:FireServer(1)
end)

check("a placed dummy can be removed, and the range's own cannot", function()
	local count = #range.dummies
	ask("Remove", facing.id)
	ask("Remove", placed.id)
	waitFor("it to go", function()
		return #range.dummies == count - 1
	end)
	expect(dummyNamed("FACING YOU") ~= nil, "one of the range's own was removed")
	expect(#workspace.Dummies:GetChildren() == count - 1, "its body was left behind")
end)

-- Dummies that do things ---------------------------------------------------------

check("a dummy shoots back as fast as its gun, where it is told to aim", function()
	local m16 = Weapons.M16
	local body = waitFor("the dummy to be on its feet", function()
		return bodyOf(turned.id)
	end)
	setDummy(turned.id, "weapon", "M16")
	waitFor("it to take up the gun", function()
		return body:FindFirstChild("HeldWeapon")
	end)
	task.wait(0.5)
	local before = #hits
	task.wait(2)
	local chest = taken(before)
	local due = 2 / m16.fireInterval
	expect(math.abs(#chest - due) <= 3, string.format("%d hits in two seconds, where the gun fires %d", #chest, due))
	local plate = ArmorConfig.body[loadout.loadout.body].classScale.Rifle or 1
	expect(chest[1].zone == "UpperTorso" and near(chest[1].amount, m16.damage.UpperTorso * plate), "a chest hit did " .. tostring(chest[1].amount))
	expect(chest[1].label == "BACK TURNED" and chest[1].shielded, "the hit does not say who fired, or that god mode stopped it")

	setDummy(turned.id, "aim", "Head")
	before = #hits
	-- Its magazine may be empty by now: like a player's gun, it has to reload.
	local head = waitFor("a shot to the head", function()
		for _, hit in taken(before) do
			if hit.zone == "Head" then
				return hit
			end
		end
		return nil
	end, m16.reloadTime + 2)
	local helmet = ArmorConfig.helmet[loadout.loadout.helmet].headScale or 1
	expect(near(head.amount, m16.damage.Head * helmet), "a headshot did " .. tostring(head.amount))
	-- It has turned to face whoever it is shooting.
	local toPlayer = ((root().Position - body.HumanoidRootPart.Position) * Vector3.new(1, 0, 1)).Unit
	expect(body.HumanoidRootPart.CFrame.LookVector:Dot(toPlayer) > 0.9, "it is not facing its target")
	say(string.format("      a dummy with an M16: %d hits in 2 s, chest %s, head %s", #chest, chest[1].amount, head.amount))

	setDummy(turned.id, "weapon", "")
	task.wait(0.4)
	before = #hits
	task.wait(0.8)
	expect(#taken(before) == 0, "it went on shooting unarmed")
	expect(body:FindFirstChild("HeldWeapon") == nil, "it is still holding the gun")
	expect(humanoid().Health == FULL, "god mode let a shot through")
	setDummy(turned.id, "aim", RangeConfig.defaultAim)
end)

-- Whatever became of that, nothing is left shooting while the rest is tried.
ask("Dummy", "all", "weapon", "")
ask("Dummy", "all", "aim", RangeConfig.defaultAim)
task.wait(0.5)

check("a dummy walks from side to side, crouches, and goes back to its post", function()
	local body = bodyOf(facing.id)
	local stands = body.HumanoidRootPart
	local post = stands.Position
	local right = stands.CFrame.RightVector
	setDummy(facing.id, "moves", true)
	local least, most, turnedAway = 0, 0, 0
	local started = os.clock()
	while os.clock() - started < 5 do
		local along = (stands.Position - post):Dot(right)
		least, most = math.min(least, along), math.max(most, along)
		turnedAway = math.max(turnedAway, 1 - stands.CFrame.RightVector:Dot(right))
		task.wait(0.05)
	end
	local reach = RangeConfig.dummy.strafe
	expect(most > reach - 1.5 and least < -(reach - 1.5), string.format("it only went from %.1f to %.1f", least, most))
	expect(most < reach + 1.5 and least > -(reach + 1.5), string.format("it wandered from %.1f to %.1f", least, most))
	expect(turnedAway < 0.05, "it turned as it walked")
	say(string.format("      a walking dummy went from %.1f to %.1f studs either side", least, most))

	-- It can still be shot while it walks.
	local hit = shoot(body.UpperTorso)
	expect(hit.target == facing.id, "a walking dummy could not be hit")

	setDummy(facing.id, "moves", false)
	waitFor("it to be back at its post", function()
		return (stands.Position - post).Magnitude < 0.5
	end)
	setDummy(facing.id, "crouched", true)
	waitFor("it to crouch", function()
		return near(post.Y - stands.Position.Y, MovementConfig.crouchHipDrop, 0.05)
	end)
	setDummy(facing.id, "crouched", false)
end)

check("standing them all up puts a shot dummy back to full health", function()
	local body = bodyOf(turned.id)
	shoot(body.UpperTorso)
	expect(body.Humanoid.Health < FULL, "the shot did nothing")
	ask("StandAll")
	waitFor("a fresh body", function()
		local now = bodyOf(turned.id)
		return now and now ~= body and now.Humanoid.Health == FULL
	end)
end)

-- The view ----------------------------------------------------------------------

check("recoil moves the view by what it should and brings it back, and hits do not pile up", function()
	local CameraController = require(player.PlayerScripts.Client.CameraController)
	local camera = workspace.CurrentCamera
	local function pitch()
		return math.deg(math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)))
	end
	task.wait(0.5) -- anything left over from being shot at has settled
	local start = pitch()

	CameraController.kick(1, 0, 10, 0.2)
	task.wait(0.12)
	local held = pitch() - start
	expect(near(held, 1, 0.2), string.format("a kick of 1 degree moved the view %.2f", held))
	task.wait(0.6)
	local after = pitch() - start
	expect(near(after, 0, 0.2), string.format("after settling the view is %.2f degrees from where it began", after))

	-- A burst: the kicks add up while it lasts, and all of it comes back.
	local burst = 0
	for _ = 1, 7 do
		CameraController.kick(0.4, 0, 10, 0.13)
		burst += 0.4
		task.wait(0.1)
	end
	local top = pitch() - start
	expect(near(top, burst, 0.3), string.format("seven kicks of 0.4 moved the view %.2f", top))
	task.wait(0.8)
	expect(near(pitch(), start, 0.2), string.format("after the burst the view is %.2f degrees off", pitch() - start))

	-- Ten hits a tenth of a second apart, as from a dummy's rifle.
	local knock = WeaponConfig.Flinch.body
	local highest = 0
	for _ = 1, 10 do
		CameraController.flinch(knock, 0)
		task.wait(0.1)
		highest = math.max(highest, pitch() - start)
	end
	expect(highest <= knock + 0.2, string.format("ten hits of %.1f knocked the view up %.2f", knock, highest))
	task.wait(0.6)
	expect(near(pitch(), start, 0.2), string.format("after being hit the view is %.2f degrees off", pitch() - start))
	say(string.format("      a 1 degree kick: %.2f held, %.2f after; a burst of %.1f: %.2f; ten hits: %.2f at most", held, after, burst, top, highest))
end)

-- The screens -------------------------------------------------------------------

check("the panel opens on both pages and shows what is switched on", function()
	local Panel = require(player.PlayerScripts.Client.Range.Panel)
	local screen = player.PlayerGui.RangePanel
	Panel.setOpen(true)
	expect(screen.Enabled, "it did not open")
	local shown, lit, all = 0, {}, 0
	local accent = Color3.fromRGB(table.unpack(Theme.accent))
	for _, button in screen:GetDescendants() do
		if button:IsA("TextButton") and button.Text ~= "" then
			all += 1
			local visible = true
			local parent = button.Parent
			while parent and parent ~= screen do
				visible = visible and (not parent:IsA("GuiObject") or parent.Visible)
				parent = parent.Parent
			end
			if visible then
				shown += 1
				if button.BackgroundColor3 == accent then
					table.insert(lit, button.Text)
				end
			end
		end
	end
	say(string.format("      panel: %d buttons, %d on the first page, lit: %s", all, shown, table.concat(lit, ", ")))
	expect(all > 70, "buttons are missing")
	expect(table.find(lit, "DUMMIES"), "the page showing is not marked")
	if table.find(lit, "ALL DUMMIES") then
		-- One dummy was told to stay up and the rest were not, so neither is picked for all.
		expect(table.find(lit, "STAYS UP") == nil and table.find(lit, "DIES") == nil, "dummies set differently are shown as all the same")
	else
		-- The crosshair happened to be on a dummy, so the panel opened on that one.
		expect(table.find(lit, "STAYS UP") or table.find(lit, "DIES"), "the one dummy's setting is not shown")
	end
	expect(table.find(lit, "STANDS STILL") and table.find(lit, "STANDING") and table.find(lit, "NOTHING"), "settings every dummy shares are not shown")
	local go = 0
	for _, button in screen:GetDescendants() do
		if button:IsA("TextButton") and button.Text == "FIRING LINE" then
			go += 1
		end
	end
	expect(go == 1, "the places are not listed on the panel")
	local status = player.PlayerGui.RangeStatus:FindFirstChildOfClass("TextLabel").Text
	expect(string.find(status, "GOD MODE"), "the status line does not show god mode: " .. status)
	Panel.setOpen(false)
	expect(not screen.Enabled, "it did not close")
end)

check("the loadout menu lists every weapon and piece of armour", function()
	local screen = player.PlayerGui.LoadoutMenu
	local hidden, total = {}, 0
	for _, button in screen:GetDescendants() do
		if button:IsA("TextButton") and button.Text ~= "" and button.Parent:IsA("Frame") and button.Parent.Parent.Parent:IsA("ScrollingFrame") then
			total += 1
			-- A second primary or grenade is rightly left out where it matches the first.
			if not button.Visible and button.Parent.Parent.Visible then
				table.insert(hidden, button.Text)
			end
		end
	end
	say(string.format("      loadout menu: %d options, hidden: %s", total, table.concat(hidden, ", ")))
	expect(total > 50, "options are missing")
	expect(#hidden <= 2, "options are hidden that should be unlocked")
end)

-- What the game's own client code complained of along the way.
local complaints = 0
for _, entry in LogService:GetLogHistory() do
	if entry.messageType == Enum.MessageType.MessageError or entry.messageType == Enum.MessageType.MessageWarning then
		complaints += 1
		say("CLIENT " .. entry.messageType.Name .. "  " .. entry.message)
	end
end

probe:FireServer("done", string.format("=== played the range: %d passed, %d failed, %d complaints from the client", passed, failed, complaints))
]==]

local function add(className, name, source, parent)
	local script = Instance.new(className)
	script.Name = name
	script.Source = source
	script.Parent = parent
	return script
end

if not ServerScriptService:FindFirstChild("Range") then
	error("this is not the range place: build range.project.json and run against that")
end

local server = add("Script", "RangeProbe", SERVER, ServerScriptService)
local client = add("LocalScript", "RangeProbe", CLIENT, StarterPlayer.StarterPlayerScripts)

print("=== playing the range")
local ok, result = pcall(function()
	return game:GetService("StudioTestService"):ExecutePlayModeAsync(TIME_ALLOWED)
end)
server:Destroy()
client:Destroy()
print(if ok then result else "the play session could not be run: " .. tostring(result))
