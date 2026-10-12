# The Drunk (Lata & Plata)

| | |
|---|---|
| Status | `partial` |
| Kind | Enemy NPC |
| In code | `ai/archetypes/drunk.tres` — free-duel pick + gauntlet. Shared greybox `ai/duelist.tscn`. The designed look, names, voice, and story below are not in code |
| Design | [`../README.md`](../README.md) |

Twins. **Lata** is the Main Street rung; **Plata** is the Saloon rung (1.5× HP). The game still only says "The Drunk".

## Look

Ships today: placeholder capsule + hat, tinted dusty tan `Color(0.55, 0.45, 0.3)`. No unique mesh yet. One revolver.

Designed (`planned`):

- **Read at range:** A wide bell with a small head on top, higher at one shoulder, with a handful of big pale shapes on it. Three flat colours.
- **Colours:** One mesh, two textures; the twins swap.

  | | Coat and hat crown | Lining, ribbons, hat brim | Charms |
  |---|---|---|---|
  | Lata | absinthe green | bile yellow | pale tin |
  | Plata | bile yellow | absinthe green | pale tin |

- **Body:** In his sixties and bloated. The gut pushes the coat out into the bell; thin legs show below the hem.
- **Shoulders:** One shoulder carries a thick pad under the coat, left over from his bearing days. Same side on both twins.
- **Hat:** Low and flat-crowned with a stiff, narrow brim, set dead level. The smallest hat in the roster.
- **Coat:** Knee-length and stiff, hanging open over the gut. Six oversized tin milagros, each hung from a ribbon bow big enough to read as a second shape:
  - a liver across the belly, the largest
  - a heart on the chest
  - a leg down the coat skirt
  - an arm along the gun-arm sleeve
  - a pair of eyes across the back
  - a fist over the padded shoulder
- **Face:** Bare. A tin eye twice life size is pinned over one eye socket and never blinks; the other eye is his own, small and wet. A tin mouth is pinned to the cheek beside his real one. The skin puckers around the pins. Same eye on both twins.
- **Gun:** One plain revolver, the dullest object on him, with a ribbon tied to the grip.

## Personality / voice

- Gauntlet copy (ships): **A drunk with a grudge** (Main Street); **His angrier brother** (Saloon, 1.5× HP).
- Not angry, or much of anything: a man carrying a full load who has been stopped in the street.
- Voice: a low, flat, continuous murmur that never rises. He recites the petitions pinned to him and never one of his own.
- Sample lines, written for later (no NPC speech ships):
  - Waiting: "For Anselmo's knee. For the widow Paz, her eyes. For the Ortega boy, whatever that was."
  - At the draw: "Hold still. I'm carrying forty people."
  - Hit: "That one was the baker's."
  - Winning: "For the stranger. Somebody pin him."
  - Plata, waiting: "For my brother's — for my — for mine."
  - Plata, dying: "Who takes them now."

## Story

Human, with one odd fact: whatever ailment is pinned to the twins, they take on.

They carried saints for a living, shouldering the litter in processions, where the saint is never set down and the whole thing sways as it goes. One feast day a woman pinned her charm to the bearer instead of the statue; her husband's leg healed and Lata's went bad. For eleven years every town has pinned its sickness to their coats, and they have been drunk the whole time on liquor other men swallowed.

Lata's grudge is not his own. [The Sheriff](sheriff.md) pinned it on him, as the tin fist, on the railroad's orders. Plata's is his: the Player shot his brother on Main Street, and it is the first thing in eleven years that he has felt for himself.

## Combat (ships)

Stands still. Slow draw, wide aim cone, long reload — the easy first rung. The design changes no knob; the last column is the fiction for what already ships.

| Knob | Value | Why |
|---|---|---|
| `reaction_time` | 0.9 (±0.35) | The arm charm hangs on his gun sleeve |
| `draw_time` | 0.9 | Same |
| `accuracy_angle_deg` | 9.0 | One working eye |
| `followup_interval` | 1.6 | |
| `reload_time` | 3.5 | He fumbles past the ribbons to reach his belt |
| `bullet_speed` | 40 | |
| `health` | 2 | Plata's 1.5× is him sober with anger |
| `move_style` | `STAND` | A bearer does not step out of line; he sways in place |

No new behaviour, hit effect, or sound is part of this design.

## References

- Board #23 (Atlas Sellman): votive metal worn on the chest of a western suit.
- Milagros: pressed tin charms shaped like the ailing body part, pinned to a saint's clothing or hung on ribbon; hearts and eyes are the most common forms. <https://en.wikipedia.org/wiki/Milagro_(votive)> · <https://lammuseum.wfu.edu/2024/10/mexican-milagros/>. Real ribbons are red; these take the swap colour to keep him to three colours.
- Processional andas: the litter is never set down and sways as it moves. <https://www.revuemag.com/?p=15619>. Bearers' shoulder pad: <https://catholicsstrivingforholiness.org/a-salute-to-the-hidden-heroes-of-the-holy-week-in-seville-the-costaleros/>
- Game facts: the shipped labels above and the stats in `ai/archetypes/drunk.tres`.
