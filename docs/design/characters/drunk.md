# The Drunk

| | |
|---|---|
| Status | `partial` |
| Kind | Enemy NPC |
| In code | `ai/archetypes/drunk.tres` — free-duel pick + gauntlet. Shared greybox `ai/duelist.tscn` |
| Design | [`../README.md`](../README.md) |

## Look

- Placeholder capsule + hat, tinted dusty tan `Color(0.55, 0.45, 0.3)`. No unique mesh yet.
- One revolver.

## Personality / voice

- Gauntlet copy: **A drunk with a grudge** (Main Street); **His angrier brother** (Saloon, 1.5× HP).
- Voice not written.

## Combat (ships)

Stands still. Slow draw, wide aim cone, long reload — the easy first rung.

| Knob | Value |
|---|---|
| `reaction_time` | 0.9 (±0.35) |
| `draw_time` | 0.9 |
| `accuracy_angle_deg` | 9.0 |
| `followup_interval` | 1.6 |
| `reload_time` | 3.5 |
| `bullet_speed` | 40 |
| `health` | 2 |
| `move_style` | `STAND` |
