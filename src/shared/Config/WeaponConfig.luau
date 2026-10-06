-- All weapon tuning lives here. Plain Luau only (no Roblox types), so the unit
-- tests can load it outside Studio.

local WeaponConfig = {}

-- Slots 1 to 3: what can be picked for each, and the order the menu lists them in.
WeaponConfig.DefaultPrimary = "Rifle"
WeaponConfig.Primaries = { Rifle = true, Smg = true, Sniper = true }
WeaponConfig.PrimaryOrder = { "Rifle", "Smg", "Sniper" }

WeaponConfig.DefaultSecondary = "Pistol"
WeaponConfig.Secondaries = { Pistol = true }
WeaponConfig.SecondaryOrder = { "Pistol" }

WeaponConfig.DefaultMelee = "Knife"
WeaponConfig.Melees = { Knife = true }
WeaponConfig.MeleeOrder = { "Knife" }

-- Slot 4 holds one grenade of the type picked in the loadout.
WeaponConfig.DefaultNade = "Frag"
WeaponConfig.Nades = { Frag = true, Smoke = true, Gas = true, Flash = true }
WeaponConfig.NadeOrder = { "Frag", "Smoke", "Gas", "Flash" }

-- Spread multipliers by movement state.
WeaponConfig.Stance = {
	crouched = 0.7,
	still = 1.0,
	moving = 1.6,
	airborne = 3.0,
}

-- Server-side tolerances for accepting what a client claims.
WeaponConfig.Validation = {
	jitterSlack = 0.08, -- seconds a shot may arrive early because of network jitter
	originTolerance = 8, -- studs between claimed shot origin and the shooter's head
	targetTolerance = 10, -- studs between claimed hit position and the target part
	meleeTolerance = 4, -- extra studs of knife reach allowed for latency
}

-- Degrees the victim's aim is knocked up when hit. A Cryo Shot cancels it.
WeaponConfig.Flinch = { body = 1.2, head = 2.6 }

WeaponConfig.Weapons = {
	Rifle = {
		kind = "Gun",
		displayName = "KR-9 Carbine",
		class = "Rifle", -- what body armour sorts weapons by
		model = "Rifle",
		automatic = true,
		fireInterval = 0.10,
		magazine = 30,
		reserve = 90,
		reloadTime = 2.2,
		equipTime = 0.35,
		range = 600,
		damage = { Head = 112, UpperTorso = 28, LowerTorso = 28, Limb = 21 },
		spread = { base = 0.5, bloomPerShot = 0.3, maxBloom = 3.5, recovery = 7 },
		recoil = {
			resetTime = 0.3, -- seconds without firing before the pattern restarts
			recovery = 10, -- degrees per second the camera settles back
			loopFrom = 8, -- pattern index to continue from once the list runs out
			-- { pitch up, yaw right } in degrees per shot. The first seven shots
			-- climb about 2.5 degrees in total; after that it mostly weaves sideways.
			pattern = {
				{ 0.30, 0.00 },
				{ 0.34, 0.04 },
				{ 0.38, -0.04 },
				{ 0.42, 0.08 },
				{ 0.42, 0.12 },
				{ 0.38, 0.16 },
				{ 0.30, 0.18 },
				{ 0.16, -0.16 },
				{ 0.14, -0.22 },
				{ 0.14, -0.18 },
				{ 0.14, 0.16 },
				{ 0.14, 0.22 },
			},
		},
	},

	-- Kills up close as fast as the rifle and reloads sooner, but needs a fifth
	-- body shot and two to the head, and scatters badly held down at range.
	Smg = {
		kind = "Gun",
		displayName = "SR-5 Sprinter",
		note = "Fast and light: deadly up close, wild at range",
		class = "SMG",
		model = "Smg",
		automatic = true,
		fireInterval = 0.075,
		magazine = 30,
		reserve = 90,
		reloadTime = 1.8,
		equipTime = 0.28,
		range = 350,
		damage = { Head = 60, UpperTorso = 20, LowerTorso = 20, Limb = 15 },
		spread = { base = 0.8, bloomPerShot = 0.28, maxBloom = 4.5, recovery = 9 },
		recoil = {
			resetTime = 0.25,
			recovery = 12,
			loopFrom = 6,
			-- A short climb, then it wanders side to side more than the rifle does.
			pattern = {
				{ 0.22, 0.00 },
				{ 0.24, 0.06 },
				{ 0.26, -0.08 },
				{ 0.24, 0.12 },
				{ 0.20, -0.14 },
				{ 0.12, 0.20 },
				{ 0.10, 0.24 },
				{ 0.10, -0.22 },
				{ 0.10, -0.26 },
				{ 0.10, 0.18 },
			},
		},
	},

	Sniper = {
		kind = "Gun",
		displayName = "Vantage Bolt",
		class = "Sniper",
		model = "Sniper",
		automatic = false,
		fireInterval = 1.2,
		quickSwitchInterval = 0.7, -- shortest gap between shots when re-equipped in between
		magazine = 5,
		reserve = 15,
		reloadTime = 3.0,
		equipTime = 0.35,
		range = 1200,
		damage = { Head = 200, UpperTorso = 100, LowerTorso = 85, Limb = 70 },
		spread = {
			base = 5,
			scopedBase = 0,
			scopedMovingBase = 2,
			bloomPerShot = 0,
			maxBloom = 0,
			recovery = 1,
		},
		recoil = {
			resetTime = 0.1,
			recovery = 10,
			loopFrom = 1,
			pattern = { { 2.0, 0.0 } },
		},
		scope = { fov = 20, sensitivity = 0.3 },
	},

	Pistol = {
		kind = "Gun",
		displayName = "P-22 Sidearm",
		class = "Handgun",
		model = "Pistol",
		automatic = false,
		fireInterval = 0.15,
		magazine = 12,
		reserve = 36,
		reloadTime = 1.6,
		equipTime = 0.25,
		range = 400,
		damage = { Head = 55, UpperTorso = 22, LowerTorso = 22, Limb = 16.5 },
		spread = { base = 0.6, bloomPerShot = 0.6, maxBloom = 3, recovery = 8 },
		recoil = {
			resetTime = 0.35,
			recovery = 16,
			loopFrom = 1,
			pattern = { { 0.7, 0.05 }, { 0.7, -0.08 }, { 0.75, 0.1 } },
		},
	},

	Knife = {
		kind = "Melee",
		displayName = "Field Knife",
		class = "Melee",
		model = "Knife",
		equipTime = 0.2,
		reach = 7,
		swingInterval = 0.5,
		frontDamage = 55,
		backDamage = 100,
		backCos = 0.5, -- cos(60 degrees): a 120 degree cone centred on the target's back
	},

	-- The bomb, in slot 5 while a player carries it in Search and Destroy.
	Bomb = {
		kind = "Bomb",
		displayName = "Bomb",
		class = "Bomb",
		model = "Bomb",
		equipTime = 0.4,
	},

	-- Grenades. `effect` picks what happens when the fuse runs out (see GrenadeService).
	Smoke = {
		kind = "Grenade",
		effect = "Smoke",
		displayName = "Smoke",
		note = "A cloud that blocks sight",
		class = "Grenade",
		model = "Grenade",
		equipTime = 0.3,
		fuse = 1.5,
		radius = 14,
		duration = 12, -- seconds the cloud lasts
		throwSpeed = 70,
		throwLift = 12,
	},

	Gas = {
		kind = "Grenade",
		effect = "Gas",
		displayName = "Gas",
		note = "A toxic cloud that hurts anyone inside",
		class = "Grenade",
		model = "Grenade",
		equipTime = 0.3,
		fuse = 1.5,
		radius = 14,
		duration = 8,
		damagePerSecond = 12,
		throwSpeed = 70,
		throwLift = 12,
	},

	Flash = {
		kind = "Grenade",
		effect = "Flash",
		displayName = "Flashbang",
		note = "Blinds anyone who can see it go off",
		class = "Grenade",
		model = "Grenade",
		equipTime = 0.3,
		fuse = 1.5,
		radius = 60, -- no effect beyond this
		duration = 3.5, -- seconds blind at point-blank, looking straight at it
		-- How much of that a player gets depends on where they were looking
		-- (see Shared.Logic.Flash). Facing is 1 straight at it, -1 back to it.
		facingFull = 0.75, -- at or above this, the full effect
		facingNone = -0.25, -- at or below this, only the turned-away effect
		awayDuration = 0.2, -- share of the duration when turned away
		awayOpacity = 0.4, -- how white the screen goes when turned away
		holdShare = 0.55, -- share of the time held at full white when looking at it
		throwSpeed = 70,
		throwLift = 12,
	},

	Frag = {
		kind = "Grenade",
		effect = "Frag",
		displayName = "Frag",
		note = "Explodes",
		class = "Grenade",
		model = "Grenade",
		equipTime = 0.3,
		fuse = 2.5,
		radius = 25,
		maxDamage = 120,
		throwSpeed = 70,
		throwLift = 12,
		knockback = 60,
	},
}

return WeaponConfig
