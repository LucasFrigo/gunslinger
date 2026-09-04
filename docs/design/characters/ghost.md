# The Ghost

| | |
|---|---|
| Status | `partial` |
| Kind | Enemy NPC |
| In code | `ai/archetypes/ghost.tres` — free-duel pick + gauntlet. Shared greybox `ai/duelist.tscn` |
| Design | [`../README.md`](../README.md) |

## Look

- Placeholder capsule + hat, tinted near-white `Color(0.85, 0.88, 0.92)`. No unique mesh yet.
- One revolver.

## Personality / voice

- Gauntlet copy: **The Ghost of the canyon** (Canyon); **The Ghost, up close** (Saloon, 2× HP).
- Voice not written.

## Combat (ships)

Fast strafe, tight cone, short reload — hardest of the three shipped archetypes.

| Knob | Value |
|---|---|
| `reaction_time` | 0.22 (±0.05) |
| `draw_time` | 0.28 |
| `accuracy_angle_deg` | 1.5 |
| `followup_interval` | 0.7 |
| `reload_time` | 1.4 |
| `bullet_speed` | 70 |
| `health` | 2 |
| `move_style` | `STRAFE` (`strafe_speed` 1.6) |
