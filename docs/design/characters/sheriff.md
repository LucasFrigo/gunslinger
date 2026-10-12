# The Sheriff (Encarnado)

| | |
|---|---|
| Status | `partial` |
| Kind | Enemy NPC |
| In code | `ai/archetypes/sheriff.tres` — free-duel pick + gauntlet. Shared greybox `ai/duelist.tscn`. The designed look, name, voice, and story below are not in code |
| Design | [`../README.md`](../README.md) |

One man on both rungs. **Encarnado** is the sheriff on Main Street and rides the Train Rooftop rung as a deputy (1.5× HP). The game still only says "The Sheriff".

## Look

Ships today: placeholder capsule + hat, tinted blue-grey `Color(0.25, 0.3, 0.45)`. No unique mesh yet. One revolver.

Designed (`planned`):

- **Read at range:** A red post under a tall hat, arms held a little out from the body, long fringe swinging off both sleeves, and a heart of daylight in the hat crown. Three flat colours.
- **Colours:** Bright red jacket; ox-blood hat and trousers; gold yoke, fringe tips, and star. The blue-grey tint goes when the mesh lands.
- **Body:** In his forties, a lean dandy. Narrow waist, long thin legs, a dancer's posture. The tallest, narrowest outline in the roster, against the Drunk's bell.
- **Hat:** High sugarloaf crown with the brim tipped forward. A heart is punched clean through the crown, front to back, big enough to show sky.
- **Face:** Never seen. Everything under the brim is a black hole down to the chin.
- **Jacket:** Short and tight, bright red, with a metallic gold yoke across the shoulders and forearm-length fringe down both sleeves, gold at the tips.
- **Star:** Gold, on the left breast, with the same heart punched through it. Same shape as the hat, so the same punch cut both.
- **Legs and boots:** Ox-blood trousers cut close; red boots, placed heel to toe.
- **Gun:** One revolver with red grips and a fringe tassel on the butt.
- **Train Rooftop:** Nothing changes. Same mesh, same texture; the demotion is in the label and the lines.

## Personality / voice

- Gauntlet copy (ships): **The crooked sheriff** (Main Street); **Deputy on the 3:10** (Train Rooftop, 1.5× HP).
- A vain showman. He plays to a crowd whether or not there is one, talks about himself and the jacket, and is entirely for sale.
- Voice: a ringmaster introducing his own act.
- The vanity never cracks. He loses still performing, and worried about the jacket.
- Sample lines, written for later (no NPC speech ships):
  - Waiting: "Watch the feet, friend. Everybody watches the feet."
  - At the draw: "Mind the jacket. It cost a county."
  - Hit: "Not the fringe. Shoot me anywhere, not the fringe."
  - Winning: "Thank you. Thank you. He'll be here all week."
  - Train Rooftop, waiting: "On this train they call me Deputy. Don't you start."
  - Dying: "Lay me face up. The yoke shows better."

## Story

Human, with one odd fact: since he took the railroad's pass, the ground under his boots is company right-of-way. He walks an invisible rail wherever he goes and cannot step off it.

The railroad bought him with an annual pass, renewed each year he is useful, and the conductor who issued it punched his hat and his star the way a ticket is cancelled. In town the star still makes him the sheriff. On the train the company's own agent outranks him, so he rides the 3:10 as a deputy and hates it.

He pinned the tin fist on Lata, on the railroad's orders (see [The Drunk](drunk.md)).

He signed the paper that said the canyon was clear (see [The Ghost](ghost.md)).

## Combat (ships)

Strafes around the enemy spawn. Mid-pack: faster and tighter than the Drunk, slower than the Ghost. The design changes no knob; the last column is the fiction for what already ships.

| Knob | Value | Why |
|---|---|---|
| `reaction_time` | 0.45 (±0.12) | He waits until he is sure you are looking |
| `draw_time` | 0.45 | |
| `accuracy_angle_deg` | 4.0 | |
| `followup_interval` | 1.0 | |
| `reload_time` | 2.2 | A flourish he will not hurry |
| `bullet_speed` | 55 | |
| `health` | 3 | The Train Rooftop's 1.5× is him on real track at last |
| `move_style` | `STRAFE` (`strafe_speed` 0.8) | The rail walk: side to side along one line, heel to toe |

The tell for the strafe is the fringe swinging out before he turns back. That comes with the mesh; no new behaviour, hit effect, or sound is part of this design.

## References

- Board #26 (Astrud, "Weird Wild West") and #24: a red-on-red figure in fringe; glamour as menace.
- Board #09 (Araki sketch): a hat with holes cut in it.
- Nudie Cohn's leather jacket for Hank Thompson, 1950s: metallic yoke and rhinestone-studded fringe. <https://countrymusichalloffame.org/exhibit/suiting-the-sound/nudie-cohn-the-original-rhinestone-cowboy/nudie-suits-and-boots/>
- Railroad passes: railroads gave free passes to sheriffs, judges, district attorneys, and clerks who did them favours. <https://web.stanford.edu/group/spatialhistory/railroaded/footnotes/themes/corruption_page=16.html> · Debs, 1887: <https://www.marxists.org/archive/debs/works/1887/870300-debs-legislationlawfreetrans.pdf>
- Conductors' punches: each conductor's punch cut its own shape, so a cancelled ticket could be traced to him. <https://www.si.edu/object/nmah_1061199> · <https://www.nps.gov/museum/exhibits/stea/community/occupation/conductor/stea-3269-punch.html>
- Railroad police had no authority off railroad property unless appointed a deputy or special policeman. <https://sk.sagepub.com/ency/edvol/embed/lawenforcement/chpt/railroad-policing>
- Game facts: the shipped labels above and the stats in `ai/archetypes/sheriff.tres`.
