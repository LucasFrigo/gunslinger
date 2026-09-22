# Sound design

Living SFX checklist. Code already plays every **Catalog** cue; most are still procedural placeholders. Check a box only when a real file is in `assets/audio/` and wired through `AudioCatalog` (see [Swap](#swap)). Do not invent cues that have no call site.

Feature wiring: [`FEATURES.md`](FEATURES.md) · Playback: [`ARCHITECTURE.md`](ARCHITECTURE.md) · Ship: [`RELEASE_TODOS.md`](RELEASE_TODOS.md) · Drop path: [`../assets/audio/README.md`](../assets/audio/README.md)

Status: **real** (checked) · **placeholder** (unchecked catalog row) · **silent** (gameplay exists, no cue yet) · **planned** (feature not in code)

Authoring DAW: **Ableton Live 12**. Layer, edit, and bounce cues there, then drop the files into `assets/audio/` (see [Swap](#swap)).

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
| Scenario wind bed (loop) | Roadmap **Wind bed + gusts**. Slot is `ScenarioResource.ambience` (`scenario_base.gd`); no `.tres` assigns a stream. Mix per outdoor arena: still Main Street, drier Canyon, more air on Train Rooftop. Saloon is interior — do not use the outdoor bed |
| `wind_gust` | Same item. One-shot that plays **only** when a visual gust spawns (`VfxCatalog`). Not a second loop |
| Menu / standoff music | No music player |
| Practice-hub bottles / slots | Planned mode |
| Extra props | Radial is cigarette-only |

## Household Foley

Low-budget reference. A phone in a quiet closet, 5–20 cm from the object, is enough for mechanical cues. Airplane mode; 48 kHz WAV if the app allows. Clothes/duvet around the phone, fridge and AC off. Do ~20 takes; keep 2. Layer in Ableton 12, export dry mono — do not bake reverb into clicks.

Do **not** record live gunfire for `gunshot`. Build it from a licensed crack (library / GDC pack / Freesound CC0 or CC-BY) plus your mechanical click, a low thump (door slam or bounced ball, pitched down), and a short quiet tail.

| Cue | Household stand-in |
|---|---|
| `click` / `dry_fire` / `chamber` | Bike lock, stapler, metal lighter, old scissors, padlock, wrench on a bolt |
| `shell_eject` | Coins, screws, or spent brass dropped on wood, then on a plate |
| `gate_close` / cylinder index / spin | Small tin, Altoids box, folding knife, toy revolver |
| `holster` | Belt, jacket, leather bag, wallet against jeans |
| `gun_catch` / `gun_drop` | Tool clack on a table (sharp take + a duller take) |
| `impact_world` | Fist or hammer into dirt, sandbag, dry wood, brick — the hit, not the room |
| `impact_flesh` / `hurt` | Wet towel slap, cabbage/melon, leather jacket punch. Keep it short |
| `ricochet` | Spoon on a steel bowl, then pitch up |
| `whizz` / `near_miss_whoosh` | Stick or jacket swung past the phone, then pitch/stretch. Ableton noise is also fine |
| `bell` | Small bell, glass + spoon, bicycle bell. One clean note, long tail |
| `ui_click` | Same metal-click pile as `click`, quieter / shorter |
| `cig_throw` / `cig_catch` | Light whoosh + a small object landing in the palm |
| `footstep_dirt` | Shoes in dirt, sandbox, or a tray of cat litter / dry rice on a towel |
| Outdoor air / gusts | Night rooftop or open window; sock or foam on the capsule; sheltered take for the bed, exposed take for gusts. City noise will be edited out |

Outdoor wind is source material, not a finished desert loop. Same gust library, different mix per arena: still/quiet for Main Street, drier for Canyon, more height/air for Train Rooftop. Do not use it in the Saloon.

Legal libraries for holes you cannot Foley: Sonniss GDC packs (read the license), Freesound CC0 or CC-BY with a credits file, BBC Sound Effects if the license allows a paid ship. No YouTube rips.

## Priority

Replace in this order so the duel reads as a gunfight, not a synth demo:

1. `gunshot`
2. `click` (hammer) + `dry_fire`
3. `bell`
4. `impact_flesh` / `impact_world` / `hurt`
5. `shell_eject` / `chamber`
6. `whizz` + `near_miss_whoosh` + `ricochet`
7. Silent weapon/prop cues (holster, catch, gate close)
8. Wind bed + gusts, then other ambience and UI

## Notes for a mix pass

- Layer gunshots (body, crack, snap, mechanical, tail). Pure noise bursts are what `PlaceholderAudio` already is.
- Mechanical close-ups (cock, gate, chamber, brass) benefit more from recordings than synthesis.
- Spatial cues are one-shots spawned at the event origin (`ImpactFeedback`) or on the gun (`WeaponBase._shot_audio`). Do not bake a huge outdoor tail into every gunshot if arenas will get ambience later.
- `duel_end` is 2D. Keep it a sting, not another gunshot.
- Buses (`assets/audio/default_bus_layout.tres`): **Master** carries every cue in this document. **Voice** is incoming proximity voice only, on its own player slider. **Mic** is the muted local capture bus. Leave new SFX on Master — a cue routed to Voice would be dragged around by the voice volume setting. Voice is 16 kHz mono speech, so leave headroom for it around 300 Hz–3.4 kHz when mixing gunshot tails; a duel is meant to stay intelligible.
