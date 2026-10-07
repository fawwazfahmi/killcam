# TDM Core

A team deathmatch for Roblox: weighted fast movement, hip-fire gunplay with
recoil patterns, instant weapon switching and a low time-to-kill. All content
is original; weapon models are block placeholders and the map is a grey-box
blockout.

Design: [docs/superpowers/specs/2026-10-06-tdm-core-loop-design.md](docs/superpowers/specs/2026-10-06-tdm-core-loop-design.md)

## Setup (once)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then from this folder:

   ```
   rokit init
   rokit add rojo-rbx/rojo
   rokit add lune-org/lune
   rojo plugin install
   ```

2. Restart Roblox Studio so the Rojo plugin loads.

## Run

1. `rojo serve` in this folder.
2. In Studio, open a new Baseplate place, open the Rojo plugin and press Connect.
3. Test tab: set Clients and Servers to 2 players and press Start.

To play a match alone, set `minPlayers = 1` in `src/shared/Config/MatchConfig.luau`.

### Smoke test, without opening Studio yourself

```
rokit add rojo-rbx/run-in-roblox
rojo build default.project.json -o build/match.rbxl
run-in-roblox --place build/match.rbxl --script tools/studio/smoketest.luau
```

and the same for `lobby.project.json` and `range.project.json`. This opens
Studio, loads every module, builds every map, checks every font and material
the project names, and closes again, printing the results. It runs in edit
mode, so it cannot play the game: spawning, shooting and the match loop still
have to be tried by hand. The exception is the test range, which has a second
script that does play it (see The test range, below).

### First run, in order

The match place first, then the lobby. Keep the Output window open; everything
this project warns about names the service it came from.

1. **Weapons.** Import the models (see Models below) and run the two fit
   commands. Press Play: the five slots, reload, scope, the knife, a grenade,
   G to drop and walking back over it.
2. **One match of each mode.** Set `mode` in `MatchConfig` to `FFA`, then
   `TDM`, then `SND`, with `minPlayers = 1` to go alone. In SND check the
   round clock, pressing 5 and holding fire on a site to plant, and holding
   F to defuse.
3. **The end of a match.** The podium should lift the top three onto a stage
   with the camera on them. Alone you will always be first and celebrating;
   to see the sulking and the crying, use two players and lose as the MVP.
4. **The loadout menu** (B) in a match: the weapon rows change, the armour
   rows are greyed out.
5. **The lobby.** `rojo serve lobby.project.json` into a second place. Walk to
   each station, open each panel, queue for a mode. Without place ids the
   queue will say the match place is not set up; that is expected.

What cannot be tested in Studio at all: saved points, reserved servers and the
teleports between the two places. Those need both places published.

## Controls

| Input | Action |
|---|---|
| W A S D, Space | Move, jump |
| Ctrl or C (hold) | Crouch |
| Left mouse | Fire, swing, throw |
| Right mouse (hold) | Scope (sniper) |
| 1 2 3 4 5, mouse wheel | Primary, handgun, knife, grenade, bomb |
| 1 again, 4 again | The second primary or second grenade, with the gloves that carry one |
| Q | Back to the weapon you held before |
| R | Reload |
| E | Use the tactical item |
| G | Drop the gun or bomb in hand |
| B | Loadout menu (applies at the next spawn) |
| F (hold) | Defuse the bomb |
| F | When dead: take the revive on offer (Search and Destroy, Team Deathmatch) |
| Space | When dead: skip the killcam |
| A D, arrow keys, bumpers | When dead: watch the previous or next teammate |
| Tab | Scoreboard |

Walk over a gun on the ground to pick it up, if you have a free slot for it.
To plant, press 5 and hold fire on a site.

### Controller and touch

Everything above is an action in `src/shared/Config/ControlsConfig.luau`, with
a key, a controller button and a touch button, so nothing is possible on one
kind of device and missing on another. Moving, looking and jumping are
Roblox's own on all three.

| Action | Controller | Touch button |
|---|---|---|
| Fire | R2 | FIRE (hold, and drag to aim while holding) |
| Scope | L2 (hold) | AIM (tap on, tap off) |
| Reload | X | RELOAD |
| Tactical item | L1 | TAC |
| Next weapon | R1 | SWAP |
| Primary, handgun, knife, grenade | D-pad up, left, down, right | SWAP steps through them |
| Back to the last weapon | R3 | |
| Crouch | B (press on, press off) | CROUCH (tap on, tap off) |
| Defuse; when dead, revive | Y (hold) | USE |
| Drop | L3 | DROP |
| Loadout | View | KIT |

The touch buttons only appear while a touch screen is what is being used, and
are drawn larger on a tablet. In a menu, a controller moves between the
buttons and B closes it; the menus are drawn smaller on a small screen. The
head-up display itself (ammo, score, crosshair) is not yet resized for phones.

## Sound

Every sound in the game is listed in `src/shared/Config/SoundConfig.luau`:
gunshots by weapon class, the knife, reloading, drawing a weapon, hits,
headshots, kills, being hurt, explosions and the flashbang. Your own play
straight away; other players' shots and explosions come from where they
happened and fade with distance, a sniper carrying furthest.

**They are stand-ins.** Uploading audio cannot be done from here, so each one
is made from the handful of sounds that ship with Roblox, played faster or
slower: a gunshot is its explosion at three times the speed. To use real
audio, upload it and put its `rbxassetid://` in place of the `id`; an empty
`id` is silent. Volume, speed and how far a sound carries are per sound.
Footsteps and the sound of dying are Roblox's own.

## Tests

```
lune run tests/run
```

Covers the rules in `src/shared/Logic`: recoil, spread, damage, movement
smoothing, hit validation, spawn choice and match state.

```
lune run tests/matchmaking
```

Runs the lobby's real queue service on several pretend lobby servers sharing
one pretend store, including a thousand runs with the lobbies out of step and
every call taking a different time, and checks who is sent where. It stands in
for everything Roblox provides, so it shows the service asks for things in the
right order, not that the real store or teleports work.

## Tuning

Every number that affects feel is in `src/shared/Config`. Change a value, let
Rojo sync, and press Play again.

## Models

Weapons and map props are original designs written as code in
`tools/models/weapons.py` and `tools/models/props.py`, sharing the finishes in
`tools/models/palette.py`. To change one, edit it there and rebuild:

```
python tools/models/build.py
python tools/models/check.py
```

This writes `assets/weapons/*.glb` and `assets/props/*.glb`, a `preview.png` in
each folder, and the colour table the fit step uses. Needs Python with `numpy`
and `Pillow`.

To get them into the game:

1. With Rojo connected, use **File > Import 3D** on the `.glb` files. Keep
   **Merge Meshes** off and **Insert in Workspace** on.
2. In the command bar, run:

   ```
   require(game.ServerStorage.Tools.FitWeapons)()
   require(game.ServerStorage.Tools.FitProps)()
   ```

   These set scale, orientation and colours, then move each model to
   `ReplicatedStorage.Assets.Weapons` or `ReplicatedStorage.Assets.Props`.
3. Save the place. `Assets` lives in the place, not in this folder, so Rojo
   never overwrites it.

Without a model in `Assets` the game falls back to blocks: block weapons, and
plain boxes for cover.

### High-detail weapons

`tools/models/hd/` builds detailed weapons in Blender's Python module, modelled
from real dimensions in millimetres. Each design is one file in
`tools/models/hd/guns/`.

```
pip install bpy numpy pillow
python tools/models/hd/build.py            every weapon
python tools/models/hd/build.py AK47       one weapon
```

`bpy` is only published for the Python version Blender itself ships with
(3.11 for bpy 5.0), so run both lines with that Python: on Windows,
`py -3.11 -m pip install ...` and `py -3.11 tools/models/hd/build.py`.

There are twenty-one: six rifles, three SMGs, four sniper rifles, four
handguns and four knives. The knives go through the same pipeline, laid out with the
handle where a gun's grip would be and the tip as the "muzzle".

This writes `assets/weapons_hd/<Name>.glb`, a studio render `<Name>.png` and
`<Name>.json`, which lists the parts, their finish and the animation group each
moves with (`Magazine`, `Bolt`, `Trigger`, `Selector`, ...). Moving parts are
separate meshes, and every mesh is UV-unwrapped at one texture repeat per
100 mm so tiling skins land at the same size on every weapon.

## Maps

There are four maps, all original layouts. Choose one with `map` in
`src/shared/Config/MatchConfig.luau`.

| Map | What it is |
|---|---|
| `NightYard` | Open-air yard at night, three routes, mirrored |
| `KilnHall` | Compact roofed arena around a central kiln, mirrored |
| `CraterStation` | Small arena around a raised pad, lower gravity, mirrored |
| `Stockyard` | Two sites (A and B), attackers and defenders, not mirrored |

## Modes

Set `mode` in `src/shared/Config/MatchConfig.luau`.

- **FFA:** free-for-all. Everyone for themselves, spawning anywhere, first to
  the kill limit.
- **TDM:** team deathmatch. First team to the kill limit, with respawns.
- **SND:** search and destroy. Attack and defend in rounds, first to 7, with no
  respawns during a round. One attacker carries the bomb in slot 5 and plants
  it by holding fire on a site; defenders defuse it by holding E beside it.
  Attackers win a round by killing every defender or by the bomb going off.
  Defenders win by killing every attacker before the plant, by the clock
  running out before the plant, or by defusing. The teams swap sides once.
  Every number is in the `bomb` table in `MatchConfig`.

SND needs a map with sites, which today means `Stockyard`; on any other map
the game runs TDM. The first team in `teams` attacks first.

## When you die

First the **killcam**: the camera swings from where you fell to whoever killed
you, with a card naming them, the weapon, whether it was a headshot and how
much health they had left. It is a look, not a replay. Space, the SKIP button
or a controller's A skips it. What comes next depends on the mode.

- **Search and Destroy**, where you are out until the round ends: when the
  killcam finishes or is skipped, you see through a living teammate's eyes,
  their view and their weapon. The arrows on the bar, A and D, the arrow keys
  or a controller's bumpers move to the next one. **Teammates only**: the
  other team is never shown. If nobody on your team is left, the camera stays
  with your own body.
- **Team Deathmatch and free-for-all**, where you respawn: there is no
  spectating. The killcam holds until you are back. Skip it, and the camera
  follows your killer from behind instead. A figure at the bottom of the
  screen fills from the feet up; when it is full you respawn.

The rules are in `src/shared/Logic/Spectate.luau`.

**Kills.** Each kill pops a red skull under the crosshair; a headshot pops one
with its brain showing. A run of kills lines them up. The icons are drawn from
small grids in `src/shared/Config/Icons.luau`, so there are no images to upload.

## Loadouts and armour

Each life a player carries one primary, one secondary, one melee weapon, one
grenade and one tactical item, and wears four armour pieces. All of it is
picked in the loadout menu and checked by the server.

Two pairs of gloves carry more. **Gunner** gloves add a second primary, and
**Grenadier** gloves a second, different grenade; the loadout menu shows a row
for it while those gloves are picked. The handgun is kept either way. Press 1
again to switch between the primaries and 4 again between the grenades; from
any other weapon, 1 or 4 goes to the first.

**Nothing can be bought during a match.** What a player already owns can
still be changed there (`matchSwap` in `ShopConfig`):

- **Weapons and grenades** can be swapped freely in the menu. Each one you
  were not carrying in your last life costs a few points when you spawn with
  it. The loadout you bring to a match is free, and so is the warm-up. If you
  cannot pay for all of a change, none of it happens.
- **The tactical item and armour** are set in the lobby and locked in a match,
  greyed out so you can see what you are wearing. Give
  `matchSwap.armourProductId` a developer product and a player can instead pay
  Robux to change one piece; like revives, a change paid for and not used is
  kept on their profile.

- **Grenades** (`WeaponConfig`): frag, smoke, gas, flashbang.
- **Tactical items** (`TacticalConfig`): Heal Stim, and Cryo Shot, which stops
  hits from throwing your aim for a few seconds.
- **Armour** (`ArmorConfig`): one piece each for helmet, body, gloves and
  boots. A piece only changes numbers: damage taken to the head or from a
  weapon class, movement speed, draw time, the tactical item's wind-up, how
  far footsteps carry or are heard, fall damage, or carrying a second primary
  or grenade.
  To add a piece, add an entry to its slot and to that slot's `order`.

**Ammunition.** Every gun starts a life with a full magazine and three more in
reserve (the rifle is 30/90). A reload tops the magazine up from the reserve
and wastes nothing. There is no other way to get more: when a gun is dry, the
choices are the handgun or a gun picked up off the ground, which comes with
whatever its last owner left in it.

A gun dropped with G, or left by a player who died, lies on the ground until
someone with a free slot walks over it.

## Two places: lobby and match

The game is two places in one experience. (A third, the test range, is for
developers only and is not part of the game: see below.)

- **Lobby** (`lobby.project.json`): the Penthouse. Players walk in first
  person to a station and press E: the Armoury (loadout and shop), Play (pick
  a mode and queue), Profile or Squad. They stay in the lobby until a match is
  found.
  It is also where a player is told that a rental has run out.
- **Match** (`default.project.json`): everything else in this README.

```
rojo serve lobby.project.json
rojo serve
```

serve the lobby and the match (one at a time, each into its own place).

How a match is made:

1. A queue launches when it has enough players and has waited `gatherTime`
   for more, or as soon as it is full. Team modes only launch with an even
   number, so it is always 2v2, 3v3 and so on; an odd player out keeps their
   place for the next match.
2. The lobby reserves a private match server, leaves it its mode, map and
   player count, and teleports the group.
3. The match starts as a free-for-all warm-up. When everyone has arrived, or
   after `warmupTime`, teams are evened out and the real mode begins.
4. When the match ends, everyone is sent back to the lobby.

**When a player leaves mid-match** the match carries on short-handed and
advertises the empty place. Any lobby with players queued for that mode sends
them in, ahead of starting a new match; a seat is claimed in one step, so two
lobbies cannot both fill it, and it frees itself if the player never arrives.
The newcomer joins the smaller team, and in Search and Destroy spawns at the
next round (watching a teammate until then). A match asks for players for as
long as it is being played, however close to its end; somebody who arrives too
late to do anything earns nothing for it (see the payout rules below). If a
whole side has left and nobody replaces them within `forfeitAfter` seconds,
the side still there wins and is paid as usual. The numbers are `backfill` in
`LobbyConfig`; the rules are `src/shared/Logic/Backfill.luau`.

**Squads.** At the Squad station a player invites others standing in the same
penthouse, up to four in all. Whoever sent the invitations leads: only they
invite, and only they pick the mode. A squad queues as one and is never split:
not between matches, and in a team mode not between teams. So a queue only
launches when its groups can make two even sides (a squad of three waits for
three more players, not one), and a squad is only sent into a running match
that has room for all of it on one team. Any change to a squad takes it out of
the queue. The rules are `src/shared/Logic/Squad.luau` and `Queue.pick`.

To set it up, publish both places under one experience, switch on **Enable
Studio Access to API Services**, and put the two place ids in
`src/shared/Config/LobbyConfig.luau`. Until then the lobby works, but a full
queue reports that the match place is not set up. Teleports, reserved servers
and saved profiles do not work in a Studio test.

There are as many copies of the lobby as the players need, and players in
different copies are matched with each other. Each lobby lists who it has
queued in a record they all share, one per mode, and looks at it every couple
of seconds; whichever lobby sees that a match can be made reserves the server
and writes the match down, and every lobby sends its own players to it. A
lobby that stops looking is dropped from the record after 15 seconds. The
rules are `src/shared/Logic/Pool.luau`; the timings are `pool` in
`LobbyConfig.luau`.

A teleport that fails is tried again (`src/server/Travel.luau`). When a match
ends its server sends everyone to the lobby every 15 seconds until they have
gone, and after a minute removes whoever is left with a message, since joining
again puts them in the lobby. A server that is closing waits for every
profile to be stored before it goes, and tries a refused save again.

The Penthouse layout is `src/server/Maps/Penthouse.luau`: a runway of dark
stone from the arrival lift to the match lift, with the bar, the lounge, the
armoury wall and a model of the arena either side of it, and a planted terrace
beyond a glass front. The lobby server adds the three station kiosks and lays
the game's weapons on the armoury racks.

- `backdrop` is the city beyond the glass: scenery with no collision, in the
  manner of Kuala Lumpur's, as plain stylised shapes. The terrace looks down a
  park to the twin towers.
- `traffic` is the routes the cars, buses and cyclists follow in the streets
  below. Each player's own game draws and moves them
  (`src/lobby/client/StreetLife.luau`); they drive on the left.
- `barriers` are invisible walls. The room is closed by its own walls and
  glass, and the terrace has an invisible box over it, so nobody can jump off.
  Anyone who does get out is put back at the lift.
- `atmosphere` is the haze over the city (`density` is the one number to
  turn) and `finish` is the glow and colour grade over the whole picture.

A box in any layout can be a `shape = "Cylinder"` or `"Ball"` instead of a
block; `axis = "X"` or `"Z"` lays a cylinder down.

## The test range

A third place, for the game's developers and nobody else: every weapon, piece
of armour and tactical item unlocked, dummies to shoot, and a panel of
switches. It is where to find out what a weapon really does.

```
rojo serve range.project.json
```

into a third place of the same experience. Nothing in the lobby leads to it;
open it from its own page, or in Studio.

**Who gets in.** The owner of the experience (or, if a group owns it, the
group's owner), anybody whose Roblox user id is in `admins` in
`src/shared/Config/RangeConfig.luau`, and anybody at all in a Studio test.
Everyone else is removed as they arrive, and the server does nothing the panel
asks for unless an admin is asking. The rule is `src/shared/Logic/Admin.luau`.

**Nothing done there is saved or counted.** There are no profiles, points,
experience, weapon standing or rentals on the range, and no teams or score.
Admins there together cannot hurt each other.

**It is the match's own code.** The range runs the same combat, loadout,
grenade, tactical, drop and spawn services as a match, mapped in by
`range.project.json`, with its own stand-ins for the four a match has and the
range does not (`src/range/server`). A dummy is hit by the same function as a
player, after the same checks, and its armour is added up the same way, so the
numbers seen there are the numbers a match gives.

What is on it (`src/server/Maps/FiringRange.luau`):

| Where | What for |
|---|---|
| Six lanes | A dummy at 15, 30, 60, 100, 200 and 400 studs from the firing line |
| Recoil wall | A board ruled in half studs, with marks on the floor 10, 20 and 40 studs from it. Switch bullet marks to stay and a spray can be read off it |
| Grenade pit | Rings every 5 studs out to a frag's reach, with a dummy on each |
| Drop tower | A ramp with a landing at 9, 12, 18, 24, 32 and 40 studs. Each has a sign saying what stepping off costs, worked out from the fall rule itself |
| By the spawn | Two dummies for the knife, one facing you and one with its back turned |

**The loadout menu** (B) lists everything, owned or not, and armour and the
tactical item can be changed there as well as weapons.

**The panel** (P, or the TEST PANEL button at the foot of the loadout menu, for
a controller or a touch screen) has two pages.

*Dummies* changes every dummy at once, or only the one you were aiming at when
you opened it (failing that, the one you last hit):

- whether a killing hit kills it, or is counted and leaves it standing at full
  health;
- its helmet and body armour, or none. A new dummy wears what a new player does;
- whether it stands still or walks from side to side at a player's speed, and
  whether it crouches;
- which gun it shoots back with, and whether it aims for your head, chest,
  stomach or legs. It fires as fast as the gun does, reloads when the gun would,
  and never misses, so what you take is the same every time;
- placing a new dummy where the crosshair is, removing placed ones, and
  standing every dummy back up.

*You* has the switches in `RangeConfig.cheats` (endless reserve, no reloading,
endless grenades, endless tactical item, loadout changes at once, god mode),
bullet marks that stay, healing, taking a plain 10, 25 or 50 off your health,
being hit once by any gun in any place through your own armour, and going
straight to any part of the range. Under god mode a hit is still reported, and
still throws your aim; it just takes nothing off.

**The readout**, down the left of the screen, lists every hit landed and every
hit taken: the weapon, where it landed, from how far, the damage before armour
and after it, and the health left. Under the list are the totals for the run
of hits in progress: how many, how much, the damage a second, and once the
dummy is dead how many hits and how long it took. Until then it says what the
numbers give on paper for hits like the last one. A number also floats up off
each hit where it landed.

What the range does not do: a dummy that kills you shows no killcam, since the
killcam is of a player; a flashbang does not blind a dummy; and a dummy's aim
is perfect, which a player's is not.

### Playing it without touching it

```
rojo build range.project.json -o build/range.rbxl
run-in-roblox --place build/range.rbxl --script tools/studio/rangetest.luau
```

starts a real play session, with a server and a client, and has the client
send what a player's game sends: shots, a stab, a grenade, and every request
the panel can make. It checks what comes back: the damage through each piece
of armour, dummies dying, walking and shooting back at the right rate, each
switch, the readout, the panel, and that recoil moves the view by what it
should and brings it back. It also reports any error the game's own client
code threw along the way. It takes about a minute. **Leave the Studio window
alone while it runs**: a click in it is a shot, and the script's own shots
then arrive too fast and are refused.

It cannot look at the screen. How the range looks, how the controls feel and
how the panel is laid out still have to be seen by eye.

## Points, levels and the shop

When a match ends, the top three are lifted onto a podium and everyone
watches: the winners dance, while a losing MVP sobs and the other losers on
the podium sulk. The MVP is outlined in gold. The poses are built from joint
angles in `src/shared/Logic/Pose.luau`.

**Who is top depends on the mode** (`mvp` in `MatchConfig`). A kill counts
everywhere; in Search and Destroy a plant or a defuse counts for three, so the
player who carried the bomb can take it from the one who only shot. The MVP is
whoever did most on *either* side, so a losing team can have one — that is
when the crying happens. In a free-for-all the MVP is always the winner, since
the score and the win are the same thing.

Kills, deaths, plants and defuses are counted in one place, `StatsService`,
which also feeds the player list (Tab) and the end-of-match payouts.

A finished match pays every player points (per kill, plus a win or loss
amount), and its top killer, the MVP, a bonus. Two things cut that down
(`rewards` in `ShopConfig`):

- **Taking no part pays nothing.** No kills, deaths, assists, plants or
  defuses means no points and no experience, whichever side won. That is a
  player sent into a match as it ended, or one who stood idle.
- **A short stay pays half.** Under `shortStay` seconds in the match (90),
  whatever was earned is halved.

**Ranks.** Points also count as experience towards levels, and each level pays
a bonus. A level is a grade of a rank: everybody starts at Private 1 and
climbs a grade at a time (Private 2, Private 3, Private First Class 1, and so
on) to Commander in Chief, 74 levels in all. The ladder is `ranks` in
`ShopConfig`: ranks can be added, renamed or given more grades at any time,
because what is saved is the level and the rank is read from it. The rank is
shown in the profile, the loadout and the shop, and on the card when someone
kills you.

**Weapon standing.** Each class of weapon (rifle, SMG, sniper, handgun, knife,
grenades) earns its own experience: a kill with a weapon of that class, or an
assist, which is hurting someone within a few seconds of another player
killing them. Only kills that count for the match earn it. That experience
climbs a ladder of materials, five tiers each: Wood 1 to Wood 5, then Iron,
Gold, Diamond and Titanium. Nothing resets. The ladder is `prestiges` in
`ProgressConfig`, and it can be reworked without anybody losing anything:
what is saved is the experience itself and the *name* of the best standing
reached, so adding materials or tiers just gives more to climb, and making
tiers cost more never moves a player below where they had got to. The profile
lists every class; a line in the feed marks each tier gained.

Points rent loadout options in
the **shop**, which is its own screen in the lobby: the Armoury station, or
the button at the bottom of the loadout menu there. The **loadout** menu lists
only what you own. There is no shop in a match.

- **Weapons and grenades** are rented by the hour of use: 1, 3 or 5. The time
  only runs down while the item is in your loadout and you are alive in a
  match. The warm-up is free.
- **Armour and tactical items** are rented by the day: 1, 2, 3, 5 or 7. The
  clock starts the first time you spawn with the item, and then runs whether
  or not you are online.

The default loadout is free. The loadout you pick is saved, so a pick made in
the lobby is what you spawn with in the match.

**When a rental runs out.** Nothing is taken off you in the middle of a match:
whatever you spawned with stays yours until that match is over, even if its
time ends first. Back in the Penthouse a notice lists what ran out, with a
button to rent it again in the shop and a plain OK. That item goes back to the
free one in your loadout; the rest of your loadout is kept.

## Revives

A player who dies while a match is being fought can come back for Robux, by
pressing F on the offer that appears. `revive` in `MatchConfig` holds the rules:

| Mode | Limit | What it changes |
|---|---|---|
| Search and Destroy | 1 a round | You are back in the round. The death still counts. |
| Team Deathmatch | 3 a match | As if it never happened: your death comes off, the other team loses the point, and the killer loses the kill. |
| Free-for-all | none | |

You come back where you fell if another player killed you, and at your spawn
otherwise. The offer only stands while the fight is still going: when a round
ends it is withdrawn.

**It is switched off until you give it a product.** Create a developer product
in the Creator Dashboard and put its id in `revive.productId`. A revive bought
a moment too late to use is not lost: it is kept on the player's profile and
used, without another purchase, the next time they press F. Roblox is only
told a purchase is complete once the profile holding it has been saved.
Purchases can only be tried in a published place.

Prices and rewards are in `src/shared/Config/ShopConfig.luau`. Profiles are
saved in a data store named `Profiles_v1`, which only works in a published
place with API access switched on. Elsewhere, including an ordinary Studio
test, profiles last for the session and nothing is saved.

**A profile is open on one server at a time.** A player going from the lobby
to a match is still being saved by one as the other starts to load, which is
how points and purchases get lost. So loading a profile marks it as open on
that server; another server that finds it open waits for the last save, which
closes it; and a save that finds the profile has been opened elsewhere since
does not write over it. A server that crashes leaves its profiles open: after
two and a half minutes without a save they are taken as abandoned. Everybody
is also saved once a minute, so a crash costs a minute at most. The rules are
`src/shared/Logic/Session.luau`.

A map that is not mirrored gives `spawns` as one list per team, and may list
`sites` (name, centre and size on the ground), which become
`Workspace.Map.Sites`.

A layout may set `gravity` (studs per second squared; Roblox's default is 196.2)
and its own `styles`, which recolour its boxes without touching the layout; a
style's `mirrorColor` gives the mirrored half a different colour, for team ends.

```
python tools/maps/view.py CraterStation
```

renders a 3D preview of a map in those colours to `assets/maps`.

A map is a table of boxes in `src/server/Maps`. A box with `prop = "Name"` is
drawn as that prop, stretched to the box, while the box itself stays as the
invisible collision. `yaw` turns a box, `propTurn = true` lays the prop's long
side along Z, `post = true` stands a lamp on a pole, and `bare = true` is a
light with no fitting.

```
python tools/maps/plan.py KilnHall
```

draws `assets/maps/KilnHall_plan.png`, prints the map's measurements (floor
area, cover density, longest clear line, passage widths) and checks that no
spawn is blocked and that the two spawns connect at ground level.
## Replacing placeholders

- **Weapon models from elsewhere:** put a Model named after the weapon's
  `model` in `WeaponConfig` (`AK47`, `P2020`, `CombatKnife`, ...) in
  `ReplicatedStorage.Assets.Weapons`. Its PrimaryPart sits at the grip with
  the barrel along -Z, and may hold an Attachment named `Muzzle`. Until one
  is there, the weapon is drawn as the plain block shape for its kind.
- **Map:** build a `Workspace.Map` folder with `Geometry`, `Spawns/Alpha`,
  `Spawns/Bravo` and `Bounds`. When it exists, the blockout is not generated.

Only use assets you made or are licensed to use.
