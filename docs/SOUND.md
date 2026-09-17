# Sound design

Living SFX checklist. Code already plays every **Catalog** cue; most are still procedural placeholders. Check a box only when a real file is in `assets/audio/` and wired through `AudioCatalog` (see [Swap](#swap)). Do not invent cues that have no call site.

Feature wiring: [`FEATURES.md`](FEATURES.md) · Playback: [`ARCHITECTURE.md`](ARCHITECTURE.md) · Ship: [`RELEASE_TODOS.md`](RELEASE_TODOS.md) · Drop path: [`../assets/audio/README.md`](../assets/audio/README.md)

Status: **real** (checked) · **placeholder** (unchecked catalog row) · **silent** (gameplay exists, no cue yet) · **planned** (feature not in code)

## Swap

1. Drop `cue.ogg` (or `.wav`) into `assets/audio/` using the filename in the table.
2. Assign it:

```gdscript
AudioCatalog.OVERRIDES[&"gunshot"] = preload("res://assets/audio/gunshot.ogg")
```

   or `preload` inside `AudioCatalog.get_stream()`.
3. Check the box here. Gameplay must keep calling `AudioCatalog.get_stream(&"cue")` — never `PlaceholderAudio.*`.

Export: 48 kHz. Mono for spatial one-shots (`AudioStreamPlayer3D`). Stereo only when the asset is inherently stereo (`duel_end`, maybe gunshot tail). Keep peaks under clipping; match loudness across combat cues more than you chase a limiter.

## Catalog (plays today)

Check when the placeholder is replaced. Call sites in parentheses.

### Weapon

| Done | Cue | File | Plays when |
|---|---|---|---|
| [ ] | `gunshot` | `gunshot.ogg` | Live round leaves the barrel (`weapons/weapon_base.gd` `try_fire`) |
| [ ] | `click` | `click.ogg` | Hammer cock; also **reused** for gate open and jam clear |
| [ ] | `dry_fire` | `dry_fire.ogg` | Empty / uncocked / jammed trigger (`try_fire`) |
| [ ] | `shell_eject` | `shell_eject.ogg` | Gravity-drop dump (`dump_rounds`) |
| [ ] | `chamber` | `chamber.ogg` | Round seated, or AI `fill_cylinder` (one click for a full cylinder) |

`click` covering cock + gate + jam-clear is a placeholder compromise. Distinct `gate_open` / `jam_clear` files need new catalog keys and call sites — do not check `click` done until the cock sound itself is real.

### Combat / impact

| Done | Cue | File | Plays when |
|---|---|---|---|
| [ ] | `whizz` | `whizz.ogg` | Bullet near-miss (`ImpactFeedback.near_miss`) |
| [ ] | `near_miss_whoosh` | `near_miss_whoosh.ogg` | Soft layer under `whizz` (same call, −4 dB) |
| [ ] | `impact_flesh` | `impact_flesh.ogg` | Body hit (any region) |
| [ ] | `impact_world` | `impact_world.ogg` | Environment hit |
| [ ] | `ricochet` | `ricochet.ogg` | ~35% of world hits, quieter tick |
| [ ] | `hurt` | `hurt.ogg` | Local player took a hit (`player_hurt`; 2D, not spatial) |

Flesh vs world is the only material split today. Head/torso/arm/leg share `impact_flesh`.

### Duel / sting

| Done | Cue | File | Plays when |
|---|---|---|---|
| [ ] | `bell` | `bell.ogg` | Draw signal (`DuelManager._ring_bell`) |
| [x] | `duel_end` | `duel_end.wav` | Lethal hit / kill-cam start (`notify_kill_shot`). Not on fouls. Pitch stays concert under slow-mo |

`duel_end` is the only real file in the folder. Revisit if the sting should change with a full mix pass.

## Silent (code, no cue)

These already happen in gameplay with haptics or VFX but no `AudioCatalog` key. Add a cue + call site when designing them; then move the row into Catalog.

| Done | Working name | Suggested file | Plays when |
|---|---|---|---|
| [ ] | Holster / draw leather | `holster.ogg` | Snap to hip or pull (`holster_to` / draw) |
| [ ] | Catch gun | `gun_catch.ogg` | Hand grabs tossed or held revolver (`Player`; haptic `catch_gun` exists) |
| [ ] | Gun hits world | `gun_drop.ogg` | Tossed revolver collides |
| [ ] | Gate close | `gate_close.ogg` | Bump / swing / flat close (`close_gate` is silent; open uses `click`) |
| [ ] | Cylinder index | `cylinder_index.ogg` | 60° tick per shot (`weapons/revolver/revolver.gd`) |
| [ ] | Ocelot spin | `spin.ogg` | Finger-hinge spin loop or start/stop |
| [ ] | Cigarette throw | `cig_throw.ogg` | Release of the boomerang |
| [ ] | Cigarette catch | `cig_catch.ogg` | Return to hand |
| [ ] | Foul | `foul.ogg` | Early draw DQ (message only today) |
| [ ] | Gauntlet cleared / over | `gauntlet_win.ogg` / `gauntlet_lose.ogg` | End-of-run HUD lines |
| [ ] | UI confirm / back | `ui_click.ogg` | Menu / pause / settings |
| [ ] | Footsteps | `footstep_dirt.ogg` (variants) | Locomotion. XR Tools has a footstep player; not wired on the rigs |

## Planned (no feature yet)

Do not produce files until the feature exists. Tracked in [`FEATURES.md`](FEATURES.md) / [`../Roadmap.md`](../Roadmap.md).

| Cue | Depends on |
|---|---|
| Scenario ambience loops | Slot is `ScenarioResource.ambience` (`scenario_base.gd`); no `.tres` assigns a stream. One loop per arena: Main Street, Saloon, Train Rooftop, Canyon |
| Menu / standoff music | No music player |
| Proximity voice | Planned MP feature |
| Practice-hub bottles / slots | Planned mode |
| Extra props | Radial is cigarette-only |

## Priority

Replace in this order so the duel reads as a gunfight, not a synth demo:

1. `gunshot`
2. `click` (hammer) + `dry_fire`
3. `bell`
4. `impact_flesh` / `impact_world` / `hurt`
5. `shell_eject` / `chamber`
6. `whizz` + `near_miss_whoosh` + `ricochet`
7. Silent weapon/prop cues (holster, catch, gate close)
8. Ambience and UI

## Notes for a mix pass

- Layer gunshots (body, crack, snap, mechanical, tail). Pure noise bursts are what `PlaceholderAudio` already is.
- Mechanical close-ups (cock, gate, chamber, brass) benefit more from recordings than synthesis.
- Spatial cues are one-shots spawned at the event origin (`ImpactFeedback`) or on the gun (`WeaponBase._shot_audio`). Do not bake a huge outdoor tail into every gunshot if arenas will get ambience later.
- `duel_end` is 2D. Keep it a sting, not another gunshot.
