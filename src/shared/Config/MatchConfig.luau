return {
	map = "Stockyard", -- a module in ServerScriptService.Server.Maps: "NightYard", "KilnHall", "CraterStation", "Stockyard" or "LebuhLama"

	-- "FFA"  free-for-all: everyone for themselves, first to the kill limit
	-- "TDM"  team deathmatch: first team to the kill limit
	-- "SND"  search and destroy: attack and defend in rounds, no respawns.
	--        Needs a map with sites; on a map without any, the game runs TDM.
	mode = "SND",

	teams = { "Alpha", "Bravo" },
	minPlayers = 2, -- set to 1 to run a match alone while testing
	-- Until a match starts it is a free-for-all warm-up. It starts when
	-- everyone the lobby sent has arrived, or after this many seconds if at
	-- least minPlayers are here.
	warmupTime = 30,
	endDuration = 8, -- seconds the result stays up before the next match
	respawnDelay = 3,
	-- A match carries on short-handed when players leave, and their places are
	-- offered to the lobby's queue. If one side has nobody at all for this many
	-- seconds, the side still here wins.
	forfeitAfter = 45,
	-- When a match from the lobby is over, everyone is sent back there. Anybody
	-- still on the match server is sent again every `retryEvery` seconds, and
	-- after `giveUpAfter` seconds of that is removed with `message`.
	lobbyReturn = {
		retryEvery = 15,
		giveUpAfter = 60,
		message = "The match is over, but the lobby could not be reached. Join again to go back to it.",
	},
	spawnProtection = 2,
	maxHealth = 100,
	corpseTime = 5, -- seconds a body stays before it is removed

	-- Guns on the ground: dropped with G, or left by a player who died.
	drops = {
		reach = 4, -- studs from which a gun is picked up by walking over it
		lifetime = 45, -- seconds before a gun nobody took disappears
		rePickupDelay = 1.5, -- seconds before the player who dropped it can take it back
	},

	-- What the MVP and the podium are judged on, per mode. A kill counts
	-- everywhere; in Search and Destroy the objective counts for more, so
	-- whoever plants and defuses can take it from whoever only shoots.
	-- The MVP is whoever did most, on either side: a losing team can have one.
	mvp = {
		FFA = { kill = 1 },
		TDM = { kill = 1 },
		SND = { kill = 1, plant = 3, defuse = 3 },
	},

	-- Coming back to life for Robux. A revive is a developer product (create
	-- one in the Creator Dashboard and put its id here). One bought too late
	-- to use is kept for the next time. There are none in a free-for-all.
	revive = {
		productId = 0, -- 0 turns revives off
		window = 10, -- seconds after dying that a revive can still be taken
		promptTime = 25, -- seconds allowed for the purchase window once it is open
		modes = {
			-- `limit` revives for each player `per` "round" or "match". With
			-- `undo`, it is as if the kill never happened: the death comes off
			-- the player's count, the point comes off the other team's score,
			-- and the kill comes off the killer's own count.
			SND = { limit = 1, per = "round", undo = false },
			TDM = { limit = 3, per = "match", undo = true },
		},
	},

	-- TDM
	scoreLimit = 60,
	timeLimit = 600, -- seconds

	ffa = {
		scoreLimit = 25,
		timeLimit = 480,
	},

	-- SND. The first team in `teams` attacks first, from the map's first spawn.
	bomb = {
		roundsToWin = 7,
		swapAfter = 6, -- the teams swap sides once, after this many rounds
		prepTime = 6, -- seconds held at spawn before a round goes live
		roundTime = 100, -- seconds the attackers have to plant
		fuseTime = 40, -- seconds from plant to explosion
		plantTime = 3, -- seconds holding fire on a site with the bomb out
		defuseTime = 5, -- seconds holding E at the bomb
		roundEndTime = 5, -- seconds the round result stays up
		pickupReach = 6, -- studs from which an attacker picks up a dropped bomb
		defuseReach = 8, -- studs from the bomb a defender can defuse from
		holdSlack = 2.5, -- studs a player may drift while planting or defusing
		blastRadius = 35, -- studs; everyone inside dies when the bomb goes off
	},
}
