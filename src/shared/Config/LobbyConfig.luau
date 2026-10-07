-- The lobby place and how it sends players into matches. Plain Luau only, so
-- the unit tests can load it.

return {
	-- Place ids, from the Creator Dashboard, once both places are published
	-- under one experience. While either is 0, queues fill and matches are
	-- made, but nobody is sent, and this lobby is matched only with itself.
	matchPlaceId = 0,
	lobbyPlaceId = 0,

	-- Once a queue has enough players it waits this long for more before it
	-- launches. A full queue launches at once.
	gatherTime = 10,

	-- There are as many copies of the lobby as the players need, and those in
	-- different copies are matched with each other. Each lobby lists who it
	-- has queued in a shared record, one per mode (see Shared.Logic.Pool).
	pool = {
		store = "MatchPool",
		lifetime = 300, -- seconds a pool is kept after the last lobby looked at it
		checkEvery = 2, -- seconds between a lobby with players queued looking at the pool
		lobbyLasts = 15, -- seconds a lobby's list is believed after it last looked
		matchLasts = 45, -- seconds a match stays in the pool for its lobbies to read
	},

	-- Where the lobby leaves a match's settings for the match server to read,
	-- and how long they are kept (seconds).
	settingsStore = "MatchSettings",
	settingsLifetime = 900,

	-- Filling the place of a player who left a match in progress. The match
	-- advertises its empty seats; a lobby with players queued for that mode
	-- sends them in, before it starts any new match.
	backfill = {
		seatStore = "OpenSeats", -- one list per mode: "OpenSeats_TDM" and so on
		seatLifetime = 20, -- seconds an advertised seat lasts unless the match renews it
		refreshEvery = 6, -- seconds between a short-handed match renewing its seats
		checkEvery = 3, -- seconds between a lobby looking for seats to fill
		transitTimeout = 30, -- seconds a seat stays taken while its new player is on the way
	},

	-- A squad is a group who queue together and are never put in different
	-- matches, or on different teams. They form in the lobby: one player
	-- invites another who is standing in the same penthouse.
	squad = {
		size = 4,
		inviteLasts = 30, -- seconds an invitation waits for an answer
	},

	order = { "FFA", "TDM", "SND" }, -- the order the Play station lists them in

	-- `teams = true` means the match needs two equal sides, so it only ever
	-- launches with an even number of players.
	modes = {
		FFA = {
			title = "Free-for-all",
			note = "Everyone for themselves",
			min = 2,
			max = 8,
			teams = false,
			maps = { "NightYard", "KilnHall", "CraterStation" },
		},
		TDM = {
			title = "Team deathmatch",
			note = "Two teams, first to the kill limit",
			min = 4,
			max = 10,
			teams = true,
			maps = { "NightYard", "KilnHall", "CraterStation" },
		},
		SND = {
			title = "Search and destroy",
			note = "Attack and defend, no respawns, first to 7",
			min = 4,
			max = 10,
			teams = true,
			maps = { "Stockyard", "LebuhLama" },
		},
	},
}
