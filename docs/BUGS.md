# Bug tracker

Open gameplay / visual defects. Agents add new reports here and move items to **Fixed** when a change lands (same session as the code). Do not invent bugs.

Status: `open` | `investigating` | `fixed` | `wontfix`  
Severity: `blocker` | `major` | `minor` | `polish`

How to file: next unused `BUG-NNN`, repro steps, arena/mode if known, screenshot under `docs/bugs/` when useful.

---

## Open

### BUG-002 — NPC teleports at draw (countdown pose ≠ duel pose)

| | |
|---|---|
| Status | `open` |
| Severity | `major` |
| Filed | 2026-08-18 |
| Platforms | SP AI duels; map-dependent |
| Areas | `ai/duelist_ai.gd`, `autoload/game_manager.gd`, spawn markers in `scenarios/` |

**What:** During standoff / wait-for-bell the NPC stands at one spot; when the duel actually starts they snap closer or to a different position.

**Repro:**
1. Free duel or gauntlet on several arenas (especially ones with a long gap between `PlayerSpawn` and `EnemySpawn`: Canyon, Train Rooftop).
2. Watch the NPC through “Holster” / “Wait for the bell…”.
3. On DRAW, note whether they jump.

**Notes for fix:** `_spawn_position` is set in `DuelistAI._ready()` from local `position` (scene origin `0,0,0`) *before* `GameManager` assigns `get_enemy_spawn()`. Strafing archetypes (Sheriff, Ghost) then do `global_position = _spawn_position + right * sin(...)` once state leaves `IDLE` at the bell — that would snap them off the marker toward world origin / closer to the player. Drunk uses `STAND` and should not strafe; if they still teleport, look at spawn parent transforms vs `global_transform`. Recapture spawn after placement (`global_position` after `current_ai.global_transform = ...`).

---

## Fixed

### BUG-001 — Double / bent bullet traces

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-08-18 |
| Fixed | 2026-08-18 |
| Platforms | Player and NPC shots (seen in flat; VR unconfirmed) |
| Areas | `weapons/bullet_trail.gd`, `weapons/bullet.gd` |

**What:** One shot drew two glowing traces that met at a sharp angle (sideways V). The kink / split changed with look direction.

**Screenshot:** [`docs/bugs/BUG-001-double-trail.png`](bugs/BUG-001-double-trail.png)

**Fix:** Trails were recording the first point in `_ready` before the bullet was moved to the muzzle (kink from scene origin). The camera-facing ribbon also rebuilt a per-vertex `forward.cross(to_eye)` that flipped along the shot. First point is now taken after spawn placement; the ribbon uses one stable side vector for the whole strip.
