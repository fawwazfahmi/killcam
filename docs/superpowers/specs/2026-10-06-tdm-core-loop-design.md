# TDM Core Loop — Design

Date: 2026-10-06
Status: awaiting review

## Goal

A team deathmatch that can be playtested in Roblox Studio and that captures the
feel of fast, close-quarters arena shooters: weighted but quick movement,
hip-fire gunplay with learnable recoil, instant weapon switching and a low
time-to-kill. This is the first slice of a larger game; lobby, shop and
progression come later and are not designed here.

## Constraints

- **Original content only.** No models, maps, layouts, textures, animations,
  sounds, UI art, names or logos taken from BlackShot or any other commercial
  game. Placeholder weapon models come from CC0 packs or the Roblox Creator
  Store, with the licence checked before import. Weapon and map names are
  original.
- **Rojo workflow.** All code lives on disk as Luau and syncs into Studio.
- **Approach A.** Standard Roblox Humanoid characters with a custom movement
  controller, client-side hit detection and server-side validation.
- **Keyboard and mouse only** in this slice.

## Match rules

| Rule | Value |
|---|---|
| Teams | 2 (Alpha, Bravo), auto-balanced on join, no switching mid-match |
| Players | Up to 16 |
| Win condition | First team to 60 kills, or most kills after 10 minutes |
| Draw | Equal kills at time limit ends as a draw |
| Health | 100, no regeneration |
| Respawn | 3 seconds after death |
| Spawn protection | 2 seconds, ends early when the player fires |
| Friendly fire | Off (grenades still damage the thrower) |
| Minimum players to start | 2 (configurable to 1 for solo testing) |

Match states: `Waiting` (fewer than the minimum players) → `Playing` → `Ended`
(scoreboard shown for 8 seconds) → scores reset and the next match starts.

## Weapons

Four slots, selected with keys 1–4 and the mouse wheel. Each player carries one
primary (rifle or sniper, chosen in a picker shown on first join and while
dead), plus the pistol, knife and one grenade.

| | Assault rifle | Sniper rifle | Pistol |
|---|---|---|---|
| Slot | 1 | 1 | 2 |
| Fire mode | Automatic | Bolt-action | Semi-automatic |
| Fire interval | 0.10 s | 1.20 s | 0.15 s |
| Magazine / reserve | 30 / 90 | 5 / 20 | 12 / 36 |
| Reload | 2.2 s | 3.0 s | 1.6 s |
| Body damage | 28 | 100 upper torso, 85 lower torso | 22 |
| Head multiplier | ×4 | kills | ×2.5 |
| Limb multiplier | ×0.75 | 70 flat | ×0.75 |
| Equip time | 0.35 s | 0.35 s | 0.25 s |
| Aiming | Hip-fire only | Scope on right click (FOV 20) | Hip-fire only |

Resulting kills: rifle 1 head or 4 body; pistol 2 head or 5 body; sniper one
shot from the chest up.

- **Knife** (slot 3): 7 stud reach, 0.5 s between swings, 55 damage from the
  front, 100 from behind. "Behind" means the attacker is inside a 120° cone
  centred on the target's back.
- **Frag grenade** (slot 4): one per life. 2.5 s fuse from the throw, 25 stud
  radius, 120 damage at the centre falling linearly to 0 at the edge, blocked
  by geometry, applies a knockback impulse.
- **Sniper quick-switch**: switching away and back re-equips the rifle ready to
  fire, so the shortest time between two sniper shots is two equip times
  (0.70 s) instead of the 1.20 s rechamber.

### Recoil and spread

- **Recoil** is a per-weapon list of (pitch, yaw) kicks in degrees, indexed by
  the shot number in the current burst. After the list ends, the last few
  entries repeat. The camera kicks by the pattern and recovers toward the
  original aim when firing stops.
- **Spread** is a cone in degrees: `(base + bloom) × stance`.
  Bloom rises by a fixed amount per shot up to a cap and decays per second.
  Stance factors: crouched 0.7, standing still 1.0, moving 1.6, airborne 3.0.
  The unscoped sniper has a large base spread; scoped and still it is zero.
- The crosshair gap shows the current spread.

All numbers above live in `WeaponConfig` and are expected to change during
tuning.

## Movement

The Humanoid stays in charge of collisions, jumping and animation. A client
controller reads the raw input direction each frame and feeds the Humanoid a
smoothed direction, which produces acceleration and deceleration.

| Parameter | Value |
|---|---|
| Run speed | 20 studs/s |
| Crouch speed | 10 studs/s |
| Time to full speed | 0.12 s |
| Time to stop | 0.15 s |
| Air steering | 30% of ground steering |
| Jump height | 6 studs |
| Landing slowdown | Speed ×0.6 for 0.2 s after more than 0.3 s in the air |

No sprint and no stamina. Crouching (hold Ctrl) lowers the camera and the
character's hip height so the head drops behind cover; the third-person leg
pose is a placeholder in this slice.

The movement state (still, moving, crouched, airborne) is exposed to the weapon
controller for spread.

## Shooting and hit validation

1. The client raycasts from the camera along the aim direction plus recoil and
   spread, and immediately shows the tracer, impact and hit marker.
2. It sends the shot to the server: weapon, origin, direction, and the claimed
   hit (target part and position), or no hit.
3. The server rejects the shot unless all of these hold:
   - the weapon is the one the player has equipped, and it has ammo;
   - enough time has passed since the last shot (fire interval with 15%
     tolerance, or the quick-switch rule for the sniper);
   - the origin is within 8 studs of the shooter's head on the server;
   - the claimed hit position is within 10 studs of the target part's position
     on the server, and within the weapon's range;
   - a server raycast from origin to the claimed position, against map geometry
     only, is not blocked;
   - the target is alive, on the other team and not spawn-protected.
4. An accepted shot spends ammo, applies damage from `Damage` and notifies the
   shooter (hit confirm), the victim (damage direction) and everyone else
   (tracer and sound).

Knife swings follow the same pattern with a reach check instead of a raycast.
Grenades are simulated on the server: the client sends a throw direction, the
server spawns and owns the projectile and resolves the explosion.

Ammo, health, scores and match state exist only on the server. Every remote is
type-checked and rate-limited; invalid or excess calls are dropped silently.

**Known limitation of this approach:** the client controls its own position and
recoil, so speed and no-recoil cheats are not prevented in this slice. The hit
validation module is isolated so a stricter server-authoritative model can
replace it later.

## Camera, viewmodel and HUD

- Camera locked to first person. The player's own character is hidden.
- The viewmodel is the weapon model attached to the camera, moved procedurally:
  sway, walk bob, recoil kick, raise and lower on switch. No authored
  animations.
- Other players appear as standard R15 characters with the weapon model welded
  to the right hand.
- HUD: crosshair, ammo, health, team scores and timer, kill feed, hit marker,
  damage direction indicator, respawn countdown. The primary is swapped with
  the B key and applies on the next spawn. The scoreboard is Roblox's built-in
  player list (Tab), showing teams with Kills and Deaths.

## Map: Night Yard

An original layout. A ruined industrial compound at night: dim, cold ambient
light with warm lamps marking the main routes.

- **Size:** about 220 × 140 studs. Teams reach the middle in 5–6 seconds.
- **Routes:**
  - *Centre yard* — open ground with low cover, overlooked from both sides.
  - *Building side* — tight two-storey interior with corners and stairs.
  - *Long lane* — one straight run of about 150 studs with a few solid cover
    pieces.
  - Short connectors between routes for rotating.
- **Height:** the building's upper floor has windows over the centre yard, and
  a catwalk crosses the middle. Every high position has two ways up and is
  exposed to at least one angle from below.
- **Fairness:** the two halves are mirror images across the centre line. (A
  180° rotation was the first choice, but it cannot keep three distinct
  full-length routes.) Each spawn area sits behind a wall with three exits,
  one per route, and has 8 spawn points.

The blockout is described as data (a list of boxes for one half, plus lights
and spawns) and built at server start by `MapBuilder`, which mirrors it for the
other half.

### Map contract

Any map is a `Workspace.Map` folder containing:

- `Geometry` — all collidable parts. Hit validation raycasts against this only.
- `Spawns/Alpha` and `Spawns/Bravo` — spawn point parts.
- `Bounds` — a part enclosing the playable volume; leaving it kills the player.

If `Workspace.Map` already exists when the server starts, `MapBuilder` does
nothing. Replacing the blockout with a Studio-built map therefore needs no code
changes.

Respawns pick the team spawn point farthest from the nearest living enemy.

## Project structure

```
default.project.json
rokit.toml                       pins Rojo and Lune
src/
  shared/                        → ReplicatedStorage.Shared
    Config/
      WeaponConfig.luau
      MovementConfig.luau
      MatchConfig.luau
    Logic/                       pure functions, no Roblox services
      Recoil.luau
      Spread.luau
      Damage.luau
      MoveSmoothing.luau
      HitValidation.luau
      SpawnSelection.luau
      MatchState.luau
    Remotes.luau                 creates and exposes all remotes
    WeaponModels.luau            builds a weapon model, custom or placeholder
  server/                        → ServerScriptService.Server
    init.server.luau
    MatchService.luau
    TeamService.luau
    SpawnService.luau
    LoadoutService.luau
    CombatService.luau
    GrenadeService.luau
    MapBuilder.luau
    Maps/NightYard.luau
  client/                        → StarterPlayerScripts.Client
    init.client.luau
    MovementController.luau
    WeaponController.luau
    CameraController.luau
    ViewmodelController.luau
    Effects.luau
    Hud.luau
  character/Health.server.luau   → StarterCharacterScripts, disables health regen
tests/run.luau                   Lune unit tests for Logic/
```

Responsibilities:

- **Logic modules** take plain values and config and return plain values. They
  hold every rule that can be wrong in a subtle way, so they are the unit-tested
  part.
- **Services** (server) and **controllers** (client) own Roblox instances,
  events and remotes, and call into Logic for decisions.
- **Config** is the only place tuning numbers appear.
- Weapon models are looked up by the name given in `WeaponConfig` under
  `ReplicatedStorage.Assets.Weapons`. Until a CC0 pack is imported, simple
  block models are generated in code under those names.

### Remotes

| Direction | Remote | Purpose |
|---|---|---|
| Client → Server | `FireShot` | Shot with claimed hit |
| Client → Server | `MeleeSwing` | Knife swing with claimed target |
| Client → Server | `ThrowGrenade` | Throw direction |
| Client → Server | `Reload` | Start reload |
| Client → Server | `EquipSlot` | Weapon switch |
| Client → Server | `SelectPrimary` | Rifle or sniper for next spawn |
| Server → Client | `MatchUpdate` | State, scores, time remaining |
| Server → Client | `LoadoutUpdate` | Ammo and equipped slot |
| Server → Client | `HitConfirm` | Shooter's hit marker, with headshot flag |
| Server → Client | `Damaged` | Victim's damage direction |
| Server → Client | `ShotFired` | Tracers and sound for other players |
| Server → Client | `Explosion` | Grenade effect |
| Server → Client | `KillFeed` | Killer, victim, weapon, headshot |

## Edge cases

- A player leaving mid-match is removed from their team; scores stay. If the
  count drops below the minimum, the match returns to `Waiting`.
- A player joining mid-match goes to the smaller team and spawns immediately.
- Shots and throws arriving after the shooter died, or after the match ended,
  are dropped.
- A kill that lands as the score limit is reached still counts; later kills in
  the same frame do not.
- Reload is cancelled by switching weapons and must be restarted.
- A grenade held when the thrower dies is not dropped.

## Testing

**Unit tests (Lune, outside Studio)** for every Logic module:

- `Recoil` — pattern indexing, looping tail, burst reset.
- `Spread` — bloom growth, cap, decay, each stance factor.
- `Damage` — every hit zone for every weapon, knife front and back, grenade
  falloff at centre, mid-radius and edge.
- `MoveSmoothing` — reaches full speed and stops in the configured times, air
  steering factor, landing slowdown window.
- `HitValidation` — one accepting case, and one rejecting case per rule.
- `SpawnSelection` — picks the farthest point, handles no living enemies.
- `MatchState` — every transition, score limit, time limit, draw.

**Playtest checklist (Studio, two-player local server):** join and auto-balance;
each weapon fires, reloads and switches; kills register with the right damage;
headshots flagged; sniper quick-switch works and is not faster than 0.70 s;
grenade damages through open space and not through walls; respawn, protection
and spawn choice; score limit and time limit both end the match and restart it;
leaving mid-match does not break state.

## Not in this slice

Lobby and room list, shop, progression, saved data, other game modes, bots,
mobile and controller input, final art, final sound, authored animations,
anti-cheat beyond the hit validation above.
