# The Sheriff

| | |
|---|---|
| Status | `partial` |
| Kind | Enemy NPC |
| In code | `ai/archetypes/sheriff.tres` — free-duel pick + gauntlet. Shared greybox `ai/duelist.tscn` |
| Design | [`../README.md`](../README.md) |

## Look

- Placeholder capsule + hat, tinted blue-grey `Color(0.25, 0.3, 0.45)`. No unique mesh yet.
- One revolver.

## Personality / voice

- Gauntlet copy: **The crooked sheriff** (Main Street); **Deputy on the 3:10** (Train Rooftop, 1.5× HP).
- Voice not written.

## Combat (ships)

Strafes around the enemy spawn. Mid-pack: faster and tighter than the Drunk, slower than the Ghost.

| Knob | Value |
|---|---|
| `reaction_time` | 0.45 (±0.12) |
| `draw_time` | 0.45 |
| `accuracy_angle_deg` | 4.0 |
| `followup_interval` | 1.0 |
| `reload_time` | 2.2 |
| `bullet_speed` | 55 |
| `health` | 3 |
| `move_style` | `STRAFE` (`strafe_speed` 0.8) |
