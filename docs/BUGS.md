# Bug tracker

Open gameplay / visual defects. Agents add new reports here and move items to **Fixed** when a change lands (same session as the code). Do not invent bugs.

Status: `open` | `investigating` | `fixed` | `wontfix`  
Severity: `blocker` | `major` | `minor` | `polish`

How to file: next unused `BUG-NNN`, repro steps, arena/mode if known, screenshot under `docs/bugs/` when useful.

---

## Open

*(none)*

---

## Fixed

### BUG-002 — NPC teleports at draw (countdown pose ≠ duel pose)

| | |
|---|---|
| Status | `fixed` |
| Severity | `major` |
| Filed | 2026-08-18 |
| Fixed | 2026-08-18 |
| Platforms | SP AI duels; map-dependent |
| Areas | `ai/duelist_ai.gd`, `autoload/game_manager.gd`, spawn markers in `scenarios/` |

**What:** During standoff / wait-for-bell the NPC stands at one spot; when the duel actually starts they snap closer or to a different position.

**Repro:**
1. Free duel or gauntlet on several arenas (especially ones with a long gap between `PlayerSpawn` and `EnemySpawn`: Canyon, Train Rooftop).
2. Watch the NPC through “Holster” / “Wait for the bell…”.
3. On DRAW, note whether they jump.

**Fix:** `_spawn_position` was captured in `_ready` from local `position` (packed-scene origin) before `GameManager` applied `get_enemy_spawn()`. Sheriff/Ghost strafe then wrote `global_position = _spawn_position + right * sin(...)` and snapped toward world origin. Spawn is now recaptured as `global_position` after placement, and again when the bell rings.

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
