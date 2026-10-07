-- All weapon tuning lives here. Plain Luau only (no Roblox types), so the unit
-- tests can load it outside Studio.

local WeaponConfig = {}

-- Slots 1 to 3: what can be picked for each, and the order the menu lists them in.
WeaponConfig.DefaultPrimary = "M16"
WeaponConfig.Primaries = {
	M16 = true,
	AK47 = true,
	HK416 = true,
	SCAR = true,
	FAMAS = true,
	ASVal = true,
	MP5 = true,
	MAC10 = true,
	MP7 = true,
	Dragunov = true,
	Scout = true,
	AWP = true,
	MSR = true,
}
WeaponConfig.PrimaryOrder = {
	"M16",
	"AK47",
	"HK416",
	"SCAR",
	"FAMAS",
	"ASVal",
	"MP5",
	"MAC10",
	"MP7",
	"Dragunov",
	"Scout",
	"AWP",
	"MSR",
}

WeaponConfig.DefaultSecondary = "P2020"
WeaponConfig.Secondaries = { P2020 = true, Glock21 = true, Revolver = true, Deagle = true }
WeaponConfig.SecondaryOrder = { "P2020", "Glock21", "Revolver", "Deagle" }

WeaponConfig.DefaultMelee = "CombatKnife"
WeaponConfig.Melees = { CombatKnife = true, Bayonet = true, Keris = true, Karambit = true }
WeaponConfig.MeleeOrder = { "CombatKnife", "Bayonet", "Keris", "Karambit" }

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

-- Degrees the victim's aim is knocked up when hit. Armour that covers the hit
-- (a helmet that protects the head, for a headshot; body armour that protects
-- against that class of weapon, for anything else) leaves `covered` of it. A
-- Cryo Shot cancels it, and so does a helmet that keeps the aim steady.
WeaponConfig.Flinch = { body = 1.2, head = 2.6, covered = 0.5 }

WeaponConfig.Weapons = {
	-- The rifle everybody starts with, and the one the others are measured against.
	M16 = {
		kind = "Gun",
		displayName = "M16",
		note = "Steady and dependable",
		class = "Rifle", -- what body armour sorts weapons by
		model = "M16",
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

	-- Hits harder than the M16 and fires a touch slower; the climb is steeper.
	AK47 = {
		kind = "Gun",
		displayName = "AK-47",
		note = "Hard-hitting, with a steep climb",
		class = "Rifle",
		model = "AK47",
		automatic = true,
		fireInterval = 0.105,
		magazine = 30,
		reserve = 90,
		reloadTime = 2.4,
		equipTime = 0.38,
		range = 600,
		damage = { Head = 120, UpperTorso = 31, LowerTorso = 31, Limb = 23 },
		spread = { base = 0.55, bloomPerShot = 0.34, maxBloom = 3.8, recovery = 7 },
		recoil = {
			resetTime = 0.3,
			recovery = 10,
			loopFrom = 8,
			pattern = {
				{ 0.36, 0.00 },
				{ 0.40, 0.05 },
				{ 0.44, -0.05 },
				{ 0.48, 0.10 },
				{ 0.46, 0.14 },
				{ 0.42, 0.18 },
				{ 0.34, 0.20 },
				{ 0.18, -0.18 },
				{ 0.16, -0.24 },
				{ 0.16, -0.20 },
				{ 0.16, 0.18 },
				{ 0.16, 0.24 },
			},
		},
	},

	-- Faster and flatter than the AK-47, for a little less damage per hit.
	HK416 = {
		kind = "Gun",
		displayName = "HK416",
		note = "Fast and steady",
		class = "Rifle",
		model = "HK416",
		automatic = true,
		fireInterval = 0.09,
		magazine = 30,
		reserve = 90,
		reloadTime = 2.1,
		equipTime = 0.33,
		range = 600,
		damage = { Head = 104, UpperTorso = 26, LowerTorso = 26, Limb = 19.5 },
		spread = { base = 0.45, bloomPerShot = 0.26, maxBloom = 3.2, recovery = 8 },
		recoil = {
			resetTime = 0.3,
			recovery = 11,
			loopFrom = 8,
			pattern = {
				{ 0.26, 0.00 },
				{ 0.30, 0.03 },
				{ 0.33, -0.03 },
				{ 0.36, 0.06 },
				{ 0.36, 0.10 },
				{ 0.32, 0.12 },
				{ 0.26, 0.14 },
				{ 0.13, -0.12 },
				{ 0.12, -0.18 },
				{ 0.12, -0.14 },
				{ 0.12, 0.12 },
				{ 0.12, 0.18 },
			},
		},
	},

	-- Heavy and accurate: the AK-47's damage with less spread, but slower to bring up.
	SCAR = {
		kind = "Gun",
		displayName = "SCAR-L",
		note = "Heavy hitter, slower to fire",
		class = "Rifle",
		model = "SCAR",
		automatic = true,
		fireInterval = 0.1,
		magazine = 30,
		reserve = 90,
		reloadTime = 2.5,
		equipTime = 0.4,
		range = 650,
		damage = { Head = 116, UpperTorso = 30, LowerTorso = 30, Limb = 22.5 },
		spread = { base = 0.45, bloomPerShot = 0.3, maxBloom = 3.4, recovery = 7 },
		recoil = {
			resetTime = 0.3,
			recovery = 10,
			loopFrom = 8,
			pattern = {
				{ 0.33, 0.00 },
				{ 0.37, 0.04 },
				{ 0.42, -0.04 },
				{ 0.46, 0.09 },
				{ 0.46, 0.13 },
				{ 0.42, 0.18 },
				{ 0.33, 0.20 },
				{ 0.18, -0.18 },
				{ 0.15, -0.24 },
				{ 0.15, -0.20 },
				{ 0.15, 0.18 },
				{ 0.15, 0.24 },
			},
		},
	},

	-- Bullpup with the fastest fire rate and the smallest magazine of the rifles.
	FAMAS = {
		kind = "Gun",
		displayName = "FAMAS",
		note = "Very fast fire, small magazine",
		class = "Rifle",
		model = "FAMAS",
		automatic = true,
		fireInterval = 0.065,
		magazine = 25,
		reserve = 75,
		reloadTime = 2.6,
		equipTime = 0.32,
		range = 550,
		damage = { Head = 96, UpperTorso = 22, LowerTorso = 22, Limb = 16.5 },
		spread = { base = 0.55, bloomPerShot = 0.24, maxBloom = 4.0, recovery = 8 },
		recoil = {
			resetTime = 0.3,
			recovery = 10,
			loopFrom = 8,
			pattern = {
				{ 0.26, 0.00 },
				{ 0.29, 0.03 },
				{ 0.32, -0.03 },
				{ 0.36, 0.07 },
				{ 0.36, 0.10 },
				{ 0.32, 0.14 },
				{ 0.26, 0.15 },
				{ 0.14, -0.14 },
				{ 0.12, -0.19 },
				{ 0.12, -0.15 },
				{ 0.12, 0.14 },
				{ 0.12, 0.19 },
			},
		},
	},

	-- Suppressed: quick and hard-hitting up close, falls off at range.
	ASVal = {
		kind = "Gun",
		displayName = "AS Val",
		note = "Quiet and fast, short range",
		class = "Rifle",
		model = "ASVal",
		automatic = true,
		fireInterval = 0.075,
		magazine = 20,
		reserve = 60,
		reloadTime = 2.0,
		equipTime = 0.3,
		range = 380,
		damage = { Head = 104, UpperTorso = 27, LowerTorso = 27, Limb = 20 },
		spread = { base = 0.6, bloomPerShot = 0.26, maxBloom = 3.6, recovery = 9 },
		recoil = {
			resetTime = 0.3,
			recovery = 10,
			loopFrom = 8,
			pattern = {
				{ 0.27, 0.00 },
				{ 0.31, 0.04 },
				{ 0.34, -0.04 },
				{ 0.38, 0.07 },
				{ 0.38, 0.11 },
				{ 0.34, 0.14 },
				{ 0.27, 0.16 },
				{ 0.14, -0.14 },
				{ 0.13, -0.20 },
				{ 0.13, -0.16 },
				{ 0.13, 0.14 },
				{ 0.13, 0.20 },
			},
		},
	},

	-- The steadiest SMG: a little less spray, a little more reach.
	MP5 = {
		kind = "Gun",
		displayName = "MP5",
		note = "Steady and accurate",
		class = "SMG",
		model = "MP5",
		automatic = true,
		fireInterval = 0.075,
		magazine = 30,
		reserve = 90,
		reloadTime = 1.9,
		equipTime = 0.28,
		range = 380,
		damage = { Head = 62, UpperTorso = 21, LowerTorso = 21, Limb = 15.5 },
		spread = { base = 0.7, bloomPerShot = 0.24, maxBloom = 4.0, recovery = 9 },
		recoil = {
			resetTime = 0.25,
			recovery = 12,
			loopFrom = 6,
			pattern = {
				{ 0.20, 0.00 },
				{ 0.22, 0.05 },
				{ 0.23, -0.07 },
				{ 0.22, 0.11 },
				{ 0.18, -0.13 },
				{ 0.11, 0.18 },
				{ 0.09, 0.22 },
				{ 0.09, -0.20 },
				{ 0.09, -0.23 },
				{ 0.09, 0.16 },
			},
		},
	},

	-- Empties its magazine in under two seconds; only good up close.
	MAC10 = {
		kind = "Gun",
		displayName = "MAC-10",
		note = "Fastest fire, wild spread",
		class = "SMG",
		model = "MAC10",
		automatic = true,
		fireInterval = 0.05,
		magazine = 32,
		reserve = 96,
		reloadTime = 1.7,
		equipTime = 0.22,
		range = 260,
		damage = { Head = 52, UpperTorso = 17, LowerTorso = 17, Limb = 12.5 },
		spread = { base = 1.1, bloomPerShot = 0.34, maxBloom = 5.5, recovery = 10 },
		recoil = {
			resetTime = 0.25,
			recovery = 12,
			loopFrom = 6,
			pattern = {
				{ 0.26, 0.00 },
				{ 0.29, 0.07 },
				{ 0.31, -0.10 },
				{ 0.29, 0.14 },
				{ 0.24, -0.17 },
				{ 0.14, 0.24 },
				{ 0.12, 0.29 },
				{ 0.12, -0.26 },
				{ 0.12, -0.31 },
				{ 0.12, 0.22 },
			},
		},
	},

	-- Big magazine and a high rate of fire for less damage per hit.
	MP7 = {
		kind = "Gun",
		displayName = "MP7",
		note = "Fast and light, 40 rounds",
		class = "SMG",
		model = "MP7",
		automatic = true,
		fireInterval = 0.063,
		magazine = 40,
		reserve = 120,
		reloadTime = 2.0,
		equipTime = 0.25,
		range = 340,
		damage = { Head = 58, UpperTorso = 18, LowerTorso = 18, Limb = 13.5 },
		spread = { base = 0.75, bloomPerShot = 0.25, maxBloom = 4.2, recovery = 9 },
		recoil = {
			resetTime = 0.25,
			recovery = 12,
			loopFrom = 6,
			pattern = {
				{ 0.19, 0.00 },
				{ 0.20, 0.05 },
				{ 0.22, -0.07 },
				{ 0.20, 0.10 },
				{ 0.17, -0.12 },
				{ 0.10, 0.17 },
				{ 0.09, 0.20 },
				{ 0.09, -0.19 },
				{ 0.09, -0.22 },
				{ 0.09, 0.15 },
			},
		},
	},

	-- Semi-automatic: no one-shot to the body, but it fires as fast as you can click.
	Dragunov = {
		kind = "Gun",
		displayName = "SVD Dragunov",
		note = "Semi-auto: fast follow-up shots",
		class = "Sniper",
		model = "Dragunov",
		automatic = false,
		fireInterval = 0.35,
		quickSwitchInterval = 0.35,
		magazine = 10,
		reserve = 30,
		reloadTime = 2.6,
		equipTime = 0.4,
		range = 1200,
		damage = { Head = 160, UpperTorso = 72, LowerTorso = 62, Limb = 48 },
		spread = {
			base = 4,
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
			pattern = { { 1.4, 0.0 } },
		},
		scope = { fov = 30, sensitivity = 0.4 },
	},

	-- Light bolt-action: fastest to bring up and to move with, a body shot does not kill.
	Scout = {
		kind = "Gun",
		displayName = "Scout",
		note = "Light and quick to handle",
		class = "Sniper",
		model = "Scout",
		automatic = false,
		fireInterval = 1.0,
		quickSwitchInterval = 0.6,
		magazine = 5,
		reserve = 15,
		reloadTime = 2.4,
		equipTime = 0.3,
		range = 1200,
		damage = { Head = 180, UpperTorso = 88, LowerTorso = 76, Limb = 60 },
		spread = {
			base = 3.5,
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
			pattern = { { 1.6, 0.0 } },
		},
		scope = { fov = 25, sensitivity = 0.35 },
	},

	-- Heaviest hitter: kills with one shot anywhere but the legs, slowest to handle.
	AWP = {
		kind = "Gun",
		displayName = "AWP",
		note = "One shot to the body",
		class = "Sniper",
		model = "AWP",
		automatic = false,
		fireInterval = 1.45,
		quickSwitchInterval = 0.8,
		magazine = 5,
		reserve = 15,
		reloadTime = 3.4,
		equipTime = 0.45,
		range = 1200,
		damage = { Head = 250, UpperTorso = 115, LowerTorso = 100, Limb = 85 },
		spread = {
			base = 6,
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
			pattern = { { 2.4, 0.0 } },
		},
		scope = { fov = 18, sensitivity = 0.28 },
	},

	-- Between the Scout and the AWP: kills with one shot to the chest.
	MSR = {
		kind = "Gun",
		displayName = "MSR",
		note = "One shot to the chest",
		class = "Sniper",
		model = "MSR",
		automatic = false,
		fireInterval = 1.25,
		quickSwitchInterval = 0.75,
		magazine = 5,
		reserve = 15,
		reloadTime = 3.0,
		equipTime = 0.42,
		range = 1200,
		damage = { Head = 220, UpperTorso = 100, LowerTorso = 88, Limb = 72 },
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
			pattern = { { 2.1, 0.0 } },
		},
		scope = { fov = 20, sensitivity = 0.3 },
	},

	-- The sidearm everybody starts with: quick, steady, fifteen rounds.
	P2020 = {
		kind = "Gun",
		displayName = "P2020",
		note = "Quick and steady",
		class = "Handgun",
		model = "P2020",
		automatic = false,
		fireInterval = 0.14,
		magazine = 15,
		reserve = 45,
		reloadTime = 1.5,
		equipTime = 0.25,
		range = 400,
		damage = { Head = 58, UpperTorso = 23, LowerTorso = 23, Limb = 17 },
		spread = { base = 0.55, bloomPerShot = 0.55, maxBloom = 3, recovery = 8 },
		recoil = {
			resetTime = 0.35,
			recovery = 16,
			loopFrom = 1,
			pattern = { { 0.65, 0.05 }, { 0.65, -0.08 }, { 0.7, 0.1 } },
		},
	},

	-- A heavier round: a body shot fewer than the sidearm, and more kick for it.
	Glock21 = {
		kind = "Gun",
		displayName = "Glock 21",
		note = "Hits harder, kicks more",
		class = "Handgun",
		model = "Glock21",
		automatic = false,
		fireInterval = 0.17,
		magazine = 13,
		reserve = 39,
		reloadTime = 1.7,
		equipTime = 0.25,
		range = 380,
		damage = { Head = 64, UpperTorso = 26, LowerTorso = 26, Limb = 19 },
		spread = { base = 0.7, bloomPerShot = 0.75, maxBloom = 3.5, recovery = 7 },
		recoil = {
			resetTime = 0.4,
			recovery = 14,
			loopFrom = 1,
			pattern = { { 1.0, 0.08 }, { 1.0, -0.12 }, { 1.05, 0.14 } },
		},
	},

	-- Six shots, each one exact if you take your time; slow to fire, slower to reload.
	Revolver = {
		kind = "Gun",
		displayName = "Revolver",
		note = "Six shots, dead accurate, slow to reload",
		class = "Handgun",
		model = "Revolver",
		automatic = false,
		fireInterval = 0.42,
		magazine = 6,
		reserve = 18,
		reloadTime = 2.6,
		equipTime = 0.3,
		range = 500,
		damage = { Head = 100, UpperTorso = 40, LowerTorso = 40, Limb = 30 },
		spread = { base = 0.25, bloomPerShot = 1.6, maxBloom = 4, recovery = 5 },
		recoil = {
			resetTime = 0.5,
			recovery = 12,
			loopFrom = 1,
			pattern = { { 2.2, 0.1 }, { 2.2, -0.15 } },
		},
	},

	-- The hand cannon: two to the body, one to an unhelmeted head, seven rounds.
	Deagle = {
		kind = "Gun",
		displayName = "Desert Eagle",
		note = "Slow and brutal: two to the body",
		class = "Handgun",
		model = "Deagle",
		automatic = false,
		fireInterval = 0.36,
		magazine = 7,
		reserve = 21,
		reloadTime = 2.1,
		equipTime = 0.32,
		range = 500,
		damage = { Head = 110, UpperTorso = 50, LowerTorso = 50, Limb = 36 },
		spread = { base = 0.5, bloomPerShot = 1.9, maxBloom = 5, recovery = 5 },
		recoil = {
			resetTime = 0.5,
			recovery = 11,
			loopFrom = 1,
			pattern = { { 2.8, 0.2 }, { 2.8, -0.3 }, { 3.0, 0.25 } },
		},
	},

	-- The knife everybody starts with, and the hardest hitter from the front.
	CombatKnife = {
		kind = "Melee",
		displayName = "Military Knife",
		note = "A heavy blade: the hardest hit from the front",
		class = "Melee",
		model = "CombatKnife",
		equipTime = 0.22,
		reach = 7,
		swingInterval = 0.58,
		frontDamage = 65,
		backDamage = 100,
		backCos = 0.5, -- cos(60 degrees): a 120 degree cone centred on the target's back
	},

	-- Longest reach of the knives.
	Bayonet = {
		kind = "Melee",
		displayName = "Bayonet",
		note = "The longest reach",
		class = "Melee",
		model = "Bayonet",
		equipTime = 0.22,
		reach = 8.2,
		swingInterval = 0.55,
		frontDamage = 55,
		backDamage = 100,
		backCos = 0.5,
	},

	-- A backstab counts from further round to the side.
	Keris = {
		kind = "Melee",
		displayName = "Keris",
		note = "Backstabs land from further round the side",
		class = "Melee",
		model = "Keris",
		equipTime = 0.2,
		reach = 7,
		swingInterval = 0.5,
		frontDamage = 50,
		backDamage = 100,
		backCos = 0.17, -- cos(80 degrees): a 160 degree cone centred on the target's back
	},

	-- Fast and close.
	Karambit = {
		kind = "Melee",
		displayName = "Karambit",
		note = "The fastest slash, the shortest reach",
		class = "Melee",
		model = "Karambit",
		equipTime = 0.16,
		reach = 6.2,
		swingInterval = 0.38,
		frontDamage = 45,
		backDamage = 100,
		backCos = 0.5,
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
