# Audio assets

Real sounds go here. Until then, `placeholder_audio.gd` generates procedural
stand-ins and `audio_catalog.gd` is the only call-site API.

## Swap path

1. Drop files into this folder using the expected names below.
2. Either assign them in code:

```gdscript
AudioCatalog.OVERRIDES[&"gunshot"] = preload("res://assets/audio/gunshot.ogg")
```

   or edit `AudioCatalog.get_stream()` to `preload` the file for that cue.

Do **not** call `PlaceholderAudio.*` from gameplay code — use `AudioCatalog.get_stream(&"cue")`.

## Cue → expected filename

| Cue | Placeholder role | Expected file |
|---|---|---|
| `gunshot` | Weapon fire | `gunshot.ogg` |
| `click` | Hammer cock | `click.ogg` |
| `dry_fire` | Empty / uncocked | `dry_fire.ogg` |
| `bell` | Draw signal | `bell.ogg` |
| `whizz` | Near-miss pass-by | `whizz.ogg` |
| `impact_flesh` | Body hit | `impact_flesh.ogg` |
| `impact_world` | Environment hit | `impact_world.ogg` |
| `ricochet` | Occasional world tick | `ricochet.ogg` |
| `hurt` | Local player hurt/death | `hurt.ogg` |
| `near_miss_whoosh` | Soft near-miss layer | `near_miss_whoosh.ogg` |

VFX placeholders live under `assets/vfx/` — swap via `VfxCatalog.OVERRIDES`.
Haptic events live under `assets/haptics/*.tres`.
