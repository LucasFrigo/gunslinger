# The Ghost

| | |
|---|---|
| Status | `partial` |
| Kind | Enemy NPC |
| In code | `ai/archetypes/ghost.tres` — free-duel pick + gauntlet. Shared greybox `ai/duelist.tscn`. The designed look and story below are not in code |
| Design | [`../README.md`](../README.md) |

One figure on both rungs. The same Ghost holds the Canyon and then follows the Player into the Saloon (2× HP). He has no name; nobody alive remembers what he was called.

## Look

Ships today: placeholder capsule + hat, tinted near-white `Color(0.85, 0.88, 0.92)`. No unique mesh yet. One revolver.

Designed (`planned`):

- **Read at range:** A pale cone with no feet, hem wider than the shoulders, a hat lashed on top and strips trailing off the back. Two flat colours and two lit points where the face should be.
- **Colours:** Aquamarine duster and hat; bone-white bandages and gun grips. The aquamarine is pale and leans blue, well away from Lata's absinthe green. The near-white tint goes when the mesh lands.
- **Head:** Wrapped completely in bone-white bandages. The eyes are the whole face.
- **Eyes:** Aquamarine and lit. The only thing on him that glows.
- **Hat:** An ordinary hat, aquamarine, tied to the head by the same wrappings: over the crown and under the jaw, the way a corpse's jaw is tied shut. The loose ends trail behind.
- **Duster:** Floor-length and too long for him. The hem drags and no boots show. Sleeves cover the hands to the knuckles; the split back opens into two tails.
- **Gun:** One revolver with bone-white grips and a bandage strip wound round the butt.
- **Saloon:** Nothing changes. Same mesh, same texture; indoors the eyes read harder.

## Personality / voice

- Gauntlet copy (ships): **The Ghost of the canyon** (Canyon); **The Ghost, up close** (Saloon, 2× HP).
- Silent. He is the only duelist with no lines, on purpose.

## Story

Dead. The first one in the roster who is.

The railroad hired him to hold the canyon against a rival line. The companies settled it in court and nobody came to tell him. The railroad killed him; how is not said. [The Sheriff](sheriff.md) signed the paper that said the canyon was clear.

Nothing ever outdrew him, and that is not what killed him. He wants to be beaten in a fair draw, and he is too good.

The canyon is company right-of-way, where nothing is settled by guns. So he follows the Player to the Saloon, off company ground, to lose where it counts.

## Combat (ships)

Fast strafe, tight cone, short reload — hardest of the three shipped archetypes. The design changes no knob; the last column is the fiction for what already ships.

| Knob | Value | Why |
|---|---|---|
| `reaction_time` | 0.22 (±0.05) | He has been waiting for this since his post |
| `draw_time` | 0.28 | |
| `accuracy_angle_deg` | 1.5 | Eyes that do not blink |
| `followup_interval` | 0.7 | |
| `reload_time` | 1.4 | Nothing on him gets in the way |
| `bullet_speed` | 70 | |
| `health` | 2 | There is not much of him left. The Saloon's 2× is him off company ground, where it counts |
| `move_style` | `STRAFE` (`strafe_speed` 1.6) | No feet under the hem; he slides |

The tell for the strafe is the trailing strips and the duster tails streaming the other way before he turns back. That comes with the mesh, as does the emissive material for the eyes; no new behaviour, hit effect, or sound is part of this design.

## References

- Board #28: a head wrapped in bandages, the eyes as the whole face. Board #22: a figure shrouded head to foot, ghost as fabric.
- The Royal Gorge "Canyon War", 1878–79: two railroads fought over one canyon, built 17 stone forts in it, and hired gunmen under Bat Masterson; it was settled in court with very little bloodshed. <https://en.wikipedia.org/wiki/Railroad_Wars> · <https://en.wikipedia.org/wiki/Royal_Gorge_Route_Railroad>
- Linen dusters: long, loose riding coats with a slit up the back, off-white or tan in surviving examples. <https://grpmcollections.org/Detail/objects/5419>. His takes aquamarine to keep him to two colours.
- The jaw tie is the cloth Marley's ghost wears in *A Christmas Carol*; not checked against a period source.
- Game facts: the shipped labels above and the stats in `ai/archetypes/ghost.tres`.
