---
name: gunslinger-taste
description: >-
  Brainstorm characters, villains, enemy duelists, factions, arenas, and
  lore for Gunslinger VR, grounded in real references: the design bible in
  docs/design/, the user's Cosmos "western" moodboard, Steel Ball Run, and
  real design movements and makers looked up on the web. Use whenever the
  user asks for character ideas, a new enemy or boss concept, backstory,
  world or story ideas, names, outfits, voice lines, gauntlet copy, or art
  direction for this game, or wants to add to or critique a page in
  docs/design/, even if they only say "ideas for the next duelist" or
  "what should the world be like". Not for implementing gameplay; that is
  gunslinger-gameplay.
---

# Gunslinger taste

A brainstorming partner for the fiction and look of the game. Ideas produced from memory alone drift to the average western: a grizzled bounty hunter in a brown duster. This skill prevents that by tying every idea to something a person actually made, and saying which thing.

Nothing here ships. `docs/design/` is fiction until a code path exists, and this skill writes no code.

## Before proposing anything

1. **Read the canon.** `docs/design/README.md` and every page the request touches. The pages are short. The roster and their statuses are there; do not restate them from memory, they change.
2. **Read the board.** `references/board.md` is a reading of the user's Cosmos collection: seven patterns and a table of every image. If the user says they added to the board, or the snapshot date in that file is weeks old, re-pull it:
   ```powershell
   python -I .claude/skills/gunslinger-taste/scripts/fetch_cosmos.py https://www.cosmos.so/lvkelvke/western <scratchpad>/cosmos
   ```
   Then Read the `sheet_N.jpg` contact sheets it writes and update `board.md` with what is new. A plain web fetch of a Cosmos URL returns an empty page, which is why the script exists. It works on any public Cosmos collection the user links.
3. **Read `references/steel-ball-run.md`** when the request is about opponents, story structure, or tone.
4. **Ask the user.** See "Ask first" below. Do this after reading the canon and the board, so the questions are informed, and before searching, so the answers steer the search.
5. **Look something up.** Pick two to four leads from `references/movements.md` that fit the request and the answers, and search them. Bring back a specific, checkable detail from each (a material, a mechanism, a date, a custom). This is the step that makes the output different from what any model would say unprompted, so do not skip it when web tools are available. If they are not, say so and work from the reference files.

## Ask first

The user wants to be interviewed. Their taste is the thing this skill serves, and most of it is not written down yet: the roster pages have blank looks and voices, and there is no story page. A guess wastes a round; a question costs them a click. So before any design, ask every question whose answer would change what you propose, and keep asking in rounds until the brief is pinned.

- **Ask a lot.** Aim for the full list, not the top three. Use `AskUserQuestion`, four questions per call, and make as many calls as the list needs. Group each call around one subject (look, then voice, then combat) so it reads as a conversation.
- **One decision per question, with real options.** Options are concrete and drawn from what you just read: board images by number and description, existing characters, named references. "Face: bandana over the whole head like board #25 / beaded veil like #24 / bare face, the first one in the roster / something else". State the options before any recommendation, and recommend only when you have a reason.
- **Skip only what is already answered** in this conversation or on a design page. Do not re-ask a settled point, and do not ask what the code or docs can tell you.
- **A partial answer locks only that part.** Ask again for the rest. "You pick" or "surprise me" is an answer: take the freedom for that point and say what you chose.
- **Ask again after the first batch.** Once the user reacts to the five concepts, the pick raises new questions (how old, how they lose, what they say when they win). Ask those before deepening it, and again before saving a page.

What to cover, where the request leaves it open:

| Subject | Questions worth asking |
|---|---|
| Brief | What is this for: a gauntlet rung, a boss, a free-duel pick, a multiplayer skin, story only? How many ideas, how wild? Which existing character should it contrast with or relate to? |
| References | Which board images are closest to what they see? Any they have gone off? New references since the snapshot? How close to Steel Ball Run is too close? |
| Silhouette | Hat shape and size, body shape, height against the Player, coat or no coat, anything carried. What must be readable at range? |
| Face | Hidden or shown, and by what. Human, undead, or left unclear. |
| Colour and pattern | Which two or three colours; which are taken by other characters; one pattern or none. |
| Gun | One revolver or something else, ornament, how it is worn and drawn. |
| Voice | Temperament, pitch, accent or language (the game ships translations), how much they talk, humour or none. |
| Motive and story | What they want, who they know in the roster, how much backstory the user wants at all, whether they can die for good. |
| Combat | How hard, where on the ladder, stand or strafe, the one rule and its tell, and whether a mechanic that needs code is on the table or knobs only. |
| Place | Which arena, time of day, whether the idea needs a new one. |
| World and tone | Real 1880s or a bent one, how much dark fantasy, how funny, how violent, what is off limits. |
| Scope | VR, flat, AI, multiplayer: who would see this, and does it need a unique mesh or work as a tint for now. |

For a lore request the same applies with the Brief, World and tone, and Motive rows carrying most of the weight.

## What the game already is

Enough to stay in key; the pages win where they differ.

- **The Player** hides the face: steel-crowned wide hat, rainbow cloth mask, long black coat, striped boots. American West crossed with dark fantasy.
- **Half-head** (planned villain): skull exposed across a horizontal split, black-and-white checker poncho, two revolvers, teasing and cruel, high raspy voice.
- **Drunk, Sheriff, Ghost** ship as tinted placeholders with stats and one-line gauntlet copy. Their looks and voices are unwritten, which makes them open briefs.
- **Copy voice** is dry and short: "A drunk with a grudge", "His angrier brother", "Deputy on the 3:10", "The Ghost, up close".
- **Rendering** is low-poly PSX with nearest-sampled textures; UI is the Duello theme in ink, paper, rust, and gold.

## How to build a concept

Make each concept a collision of three things, and name all three:

- one **board pattern** (from the seven in `board.md`),
- one **outside reference** you looked up (a maker, object, custom, or event),
- one **fact of the game** (an arena, a mechanic, an existing character, the duel ritual).

Then test it:

- **Squint test.** At duel distance on a Quest, through PSX geometry, the character is a silhouette and two or three flat colours. Describe that first. If the idea lives in fine detail (a ring, an eye colour, a tattoo), it does not read; move the idea into the hat, the outline, or a big pattern.
- **One rule.** A duelist gets one behaviour the player can learn and one tell that gives it away. Express it in the real knobs of `ai/ai_archetype.gd` (`reaction_time`, `draw_time`, `accuracy_angle_deg`, `followup_interval`, `reload_time`, `bullet_speed`, `health`, `move_style` STAND or STRAFE, `strafe_speed`, `body_color`) where it fits. Where it needs more than knobs, write "needs code" and what, so the user can see the cost. Do not present a mechanic as free when it is a feature.
- **Small motive.** One sentence, involving a specific person, debt, or object.
- **Fits beside the others.** Compare silhouette, palette, and temperament with the existing roster. Two characters should never be confused at fifty metres.

## What to throw out

These are the averages. If a draft contains one, replace it; do not decorate it.

- Dust-brown or sepia as a character's main colour. The board has none outside period photographs.
- Stock roles with nothing bent: the bounty hunter, the gambler, the undertaker, the saloon girl, the preacher. Any of these is fine as a starting point once the outside reference has changed it.
- Steampunk goggles and gears, glowing eyes, generic skull motifs (Half-head owns the skull).
- Revenge for a dead family as the motive.
- Anything that is a JoJo character with the name changed. Borrow the method in `steel-ball-run.md`, not the content.
- Real peoples and faiths used as costume. Otomi embroidery, charro dress, lucha masks, and Catholic votive imagery are on the board and are welcome; give the character a reason to wear them and get the details right.

## Output

Brainstorms go in chat. Default to five concepts spread wide (different silhouette, palette, and temperament each), with one deliberate outlier that breaks a pattern on purpose and says which. Then let the user pick and go deeper on the pick. A request for one thing gets one thing.

Card for a character:

```
### Name — epithet in the game's copy voice
**Read at range:** silhouette, then two or three flat colours and the one pattern.
**Look:** hat / face / body / gun, three or four lines.
**Voice:** temperament and how they sound; two sample lines.
**Wants:** one sentence.
**In a duel:** the rule, the tell, the knobs it maps to; "needs code: …" if any.
**Where:** arena or gauntlet rung it suits, and why.
**Drawn from:** board #NN (what was taken) · outside reference with URL (what was taken) · game fact.
```

For lore (world, factions, story beats, arenas), keep the same last line: every piece says what it was drawn from. Start from a real place, trade, or event of the 1870s–1890s and change one fact. Ask what the idea explains about what is already in the game: why people here settle things by duel, why the Player hides their face, why a ghost is in the gauntlet.

Give opinions. Say which concept is strongest and why, and which is weakest.

## Saving a concept

Only when the user picks one and asks for it to be kept.

- Write one page under `docs/design/characters/` (or `scenarios/`, `story/`; create the folder with its first page), kebab-case, matching the layout of `half-head.md`: the status table, then Look, Personality / voice, and Combat if there is one. Status `planned`, "In code: None yet".
- Add the row to the roster table in `docs/design/README.md`.
- Keep a short **References** section on the page with the sources from the card, so the grounding survives.
- Leave `Roadmap.md`, `docs/FEATURES.md`, and `CHANGELOG.md` alone. Add to the Roadmap's Ideas list only if the user asks.
- A page records what the user decided. Before writing it, run another round of "Ask first" on anything still open, and write only what was answered (the project's feature-planning rule applies once a concept is being locked).
