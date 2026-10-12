# Half-head

| | |
|---|---|
| Status | `planned` |
| Kind | Main antagonist / final gauntlet boss |
| In code | None yet — not an `AIArchetype`; roster today is Drunk / Sheriff / Ghost (`ai/archetypes/*.tres`). No dual-wield, no giant duelist, and no oil-field arena exist |
| Design | [`../README.md`](../README.md) |

He owns the railroad. He is the last rung of the gauntlet, after **The Ghost, up close**, and is met only there. He has no other name; nobody says one.

Listed as the first design under **More enemy NPCs** in the Ideas section of [`Roadmap.md`](../../../Roadmap.md).

## Look

- **Read at range:** A checkered wall, taller and wider than anyone else in the roster, with a ring above it and a pale dome coming up through the ring. One black gun, one white gun. No colour at all.
- **Colours:** Black, white, and bone. No third colour. He is the one colourless figure in a loud roster.
- **Body:** A giant. The Drunk is a bell, the Sheriff a post, the Ghost a cone; he is a wall.
- **Head:** Split **horizontally**. The top half is bare bone: skull dome and eye sockets. The bottom half is living flesh: nose, mouth, and jaw. He talks and grins with a real mouth. The wound stays readable at duel distance.
- **Hat:** A wide brim with no crown. The skull dome rises through it. The only hat in the roster with nothing to cover.
- **Clothes:** Long poncho, big black-and-white checker. The pattern is the body silhouette; do not mute it.
- **Weapons:** Two revolvers, one black and one white. Dual-wield; not a single-gun duelist.

## Personality / voice

- Teasing. Needles the player; enjoys the standoff.
- Visceral and violent. Mean in how he talks and how he kills.
- Voice: raspy and high-pitched, out of a giant.
- A businessman under the teasing. Everything is a ledger: fares, prices, what a man cost him. The cruelty is accounting.
- Few lines, well chosen. He comes straight after the silent Ghost and does not fill the quiet; he says one cutting thing and lets the wait work.
- No gauntlet copy or lines are written yet.

## Story

Human, with one odd fact: he owns half of everything. Half of any man who takes company money is his, and he can call it in. His own missing half is the one thing he does not own.

He sold the top of his head for the railroad. Who bought it is not said.

[The Player](player.md) was in the room. What part the Player took is not said. It is why the Player hides their face.

The company men below him on the ladder are his: the railroad bought [the Sheriff](sheriff.md), hired and killed [the Ghost](ghost.md), and ordered the fist pinned on [Lata](drunk.md).

When the Player wins, he dies for good. It is the only final death in the gauntlet.

## Combat

Nothing ships. Decided so far:

| Point | Decision | Cost |
|---|---|---|
| Rung | Last, after the Ghost's Saloon rung | New ladder entry |
| Guns | Two revolvers fired in turn: left, right, left, right. Identical stats; the colours are only look | Needs code: dual-wield in the AI and the duelist scene, each gun with its own cylinder |
| `move_style` | `STRAFE` | Existing knob |
| Size | Giant | Needs a mesh or a scale, and the hitboxes with it |

The tell is the colour of the gun that comes up. No stat values are set, and no boss phase or second rule is part of this design.

## Where

The **Oil-field train** idea in [`Roadmap.md`](../../../Roadmap.md): a train crosses the lane through open desert, pumpjacks on both sides of the track, flame columns on the horizon. The oil is under his squares and the train is his. The flames are the only colour in his fight.

This page adds nothing to that idea. It depends on the crossing train (**Train Map Concept**), which is also still an idea.

## References

- Board #30 (deimos art): giants in houndstooth over a town; a checked suit as the villain and the boss drawn as landscape.
- Board #09 (Araki sketch): a hat with pieces cut out of it.
- Board #27: a rider firing a pistol from each hand.
- Checkerboard land grants: the Pacific Railway Act of 1862 gave the railroad the odd-numbered square-mile sections beside the track, five per mile on each side, and the 1864 amendment doubled it to ten within twenty miles. The even sections stayed public, so company land and public land alternated like a board. <https://www.govinfo.gov/content/pkg/CRPT-108srpt305/html/CRPT-108srpt305.htm> · <https://www.law.cornell.edu/supremecourt/text/440/668>
- Game facts: the railroad as the power behind the Sheriff, Ghost, and Drunk pages; the Oil-field train and Train Map Concept entries in `Roadmap.md`.
