# Gunslinger VR — Business Brief

Briefing for business / pricing / go-to-market refinement.  
**Audience:** planning agents or humans. **Source of truth for features:** [`FEATURES.md`](FEATURES.md), [`../Roadmap.md`](../Roadmap.md), [`../README.md`](../README.md). **Ship checklist:** [`RELEASE_TODOS.md`](RELEASE_TODOS.md).  
**As of:** 2026-09-25 · **Code version:** `0.6.0-alpha` (see [`../VERSION`](../VERSION))  
**$5.99 cash scenario:** 2026-09-25 · §6.1

---

## 1. Elevator pitch

**Duello!** (repo and Godot project name: Gunslinger VR) is a Godot 4.x Wild West gun-dueling game for VR: single-player gauntlet vs AI gunslingers, a practice range, and 1v1 multiplayer with proximity voice. Bullets are real slow projectiles with visible trajectories; Superhot-style slow motion is tunable. The fantasy is the classic standoff — draw, shoot, dodge — plus off-hand tricks (cigarette, coin, ace, bottle), not an open-world western.

---

## 2. Product snapshot

| Field | Value |
|---|---|
| Player-facing name | **Duello!** on the Quest package, the Steam store page, the loading screen, and the main menu. Godot `config/name` is still `Gunslinger VR` |
| Genre | VR action / duel shooter / Wild West |
| Engine | Godot 4.7, GDScript |
| Primary platforms (shipping intent) | **Main Meta Quest store** (Quest 3 standalone) + **Steam** page **Duello!** (PCVR and flat) |
| Flat on Steam | Ships inside the Steam app (flat launch option + PCVR), not as a second full-price game. `--flat` is that mode |
| Monetization (assumed) | Premium paid (no IAP planned today) |
| Multiplayer | 1v1 LAN + proximity voice (all SKUs). 1v1 Steam lobbies + voice on desktop only (GodotSteam 4.22; App ID **480** until owned). Quest build is LAN-only |
| Studio context | Solo indie; developer in **Brazil**, salaried (~R$6.300/month net). Cash plan for fee + art ~R$800 (§6.1) |
| Language / storefront | Product English today; localized **prices** planned (esp. BRL) |

### Core loop

1. Standoff → bell → draw → fire → first **lethal** hit resolves (head instakill; torso/limb HP). An arm hit flings the revolver; a leg hit slows you.  
2. Early draw = foul. Shooting yourself loses the duel.  
3. Holster / draw / cock / fire. VR: hold to hold, toss and catch, Ocelot spin. Flat: rapid-fire can jam.  
4. Interactive reload: swing the cylinder out, dump, feed a round from the belt, bump or swing shut.  
5. Optional slow-mo modes (SP only): CONSTANT, ON_DRAW, MOVEMENT (Superhot), NEAR_MISS.  
6. SP: free duel, 6-rung gauntlet (3 lives, session score), or the practice hub (bottles, slot machine, tutorial board).  
7. Off-hand radial: cigarette boomerang, coin toss, ace, bottle. Local only; remote avatars show an empty off-hand.  
8. MP: 1v1 over LAN (Quest and desktop) or Steam (desktop). Proximity voice. Gameplay slow-mo is off in network sessions; the kill-cam burst still plays. Mismatched versions cannot join.

### Differentiators (marketing hooks)

- Visible bullet trajectories + tunable bullet-time (SUPERHOT-adjacent fantasy in a western).  
- Physical VR gunplay: hip draw, toss/catch, finger-spin, interactive cylinder reload, arm-shot disarm.  
- Off-hand tricks that read in a 15-second clip: cigarette boomerang, coin flip, ace, shatterable bottle.  
- Kill cam: trail fly-along (flat camera / VR spectator); SP and 1v1 MP.  
- 1v1 proximity voice, so a standoff can be talked through. Quest hears LAN peers only.  
- Dual ship: Quest standalone volume + one Steam app that does PCVR, flat, and Steam lobbies. Online matchmaking is Steam-only. A Quest headset and a flat PC on the same LAN can already duel.

### Comps (price / positioning reference)

| Title | Role vs Gunslinger | Typical USD list |
|---|---|---|
| SUPERHOT VR | Aspirational polish + bullet-time brand | ~$24.99 |
| Mid-tier Quest shooters / westerns | Shelf neighborhood | ~$8–$20 (many $9–$15) |
| HARD BULLET / Thrill of the Fight 2 class | “Real feel” premium niche VR | ~$20 |
| Thin western Quest experiments | Floor / avoid looking like these | ~$1–$8 |

---

## 3. Feature & content status (ship readiness)

Status vocabulary: `done` | `partial` | `planned`. Full detail: [`FEATURES.md`](FEATURES.md).

### Done (playable today)

- Core duel (standoff → bell → draw → resolve, early-draw foul, self-damage).  
- Holster / draw / fire / cock; VR hold-to-hold, toss/catch, Ocelot spin; flat rapid-fire jam.  
- Projectile bullets and trails. Regional hits: head instakill, arm flings the gun, leg slows.  
- Interactive reload (gate, dump, belt feed, bump or swing close) for the player and for AI.  
- Free duel; gauntlet (6 rungs, 3 lives, session score, not saved).  
- Practice hub: breakable bottles, porch slot machine, tutorial billboard. VR boots there; flat menu uses a frozen arena backdrop.  
- Off-hand radial: cigarette boomerang, coin, ace of spades, bottle. Local only.  
- AI: Drunk, Sheriff, Ghost.  
- 1v1 LAN (Quest + desktop) and 1v1 Steam lobbies (desktop). Proximity voice on both transports. Version mismatch refuses the join.  
- Slow-mo (SP); kill cam (SP + 1v1, including VR). Random time of day on outdoor maps.  
- Revolver mesh (`wpn_psx_blaster.glb`). Settings, control remap, pause. Boot loading screen.  
- Quest 3 / PCVR / flat harness. Headless autotests.

### Partial (blocks a paid listing)

- Four duel arenas are **Blender greyboxes**, not CSG and not final art: Main Street, Saloon, Train Rooftop (stopped train, scrolling desert), Canyon. Practice hub is greybox too. Detail meshes are still the art pass.  
- Gunslinger mesh is a low-poly A-pose. Not on AI or the remote avatar (those are still greybox bodies).  
- Audio / VFX: wiring is in; the only real cue is `duel_end.wav`. Everything else is placeholder. Checklist: [`SOUND.md`](SOUND.md).  
- The $9.99 list assumes this art and audio pass is done before the store page. It is not done in `0.6.0-alpha`.

### Planned (roadmap — raise price if a chunk of this ships)

| Priority band | Items |
|---|---|
| Polish | Shorter bullet trails, real SFX, barrel smoke, wind |
| Medium | Airborne trick shots; more props and NPCs (first design: Half-head); duel vs up to 3 NPCs; death cam; ragdoll and dismemberment; train that crosses the lane; oil-field train; horseback duel |
| Hard | Horde; duel replay; Mexican standoff (3 humans); 4-player MP; ranking / leaderboards (Steam only) |
| Very hard | Campaign; mod support |

### Content depth implication for pricing

- **What exists now:** a full duel toy (gun feel, props, practice, 1v1 voice) in greybox arenas with placeholder sound. Not the “finished indie look” in §6.1, and not a $19.99 page.  
- **Ship this scope** once the look and the gunshot are real → **$9.99** (§5).  
- **Polished niche v1:** more gunslingers, set pieces, or a campaign-lite, plus art that can sit next to a $15 thumbnail → **$14.99–$19.99**.  
- **Premium showcase:** depth closer to SUPERHOT / big western shooters (more modes, set pieces, campaign-lite) → only then **$24.99**.

---

## 4. Target platforms & distribution

| Platform | Role | Notes |
|---|---|---|
| **Meta Quest Store** | Primary **volume** | **Main store**, not App Lab. Quest 3 export; launcher name **Duello!**. ~30% platform fee. **MP is LAN-only** on this SKU (no Steam, no Meta online). Voice works on that LAN link. Certification and featuring are still ahead. |
| **Steam** | PCVR + flat + lobbies | One app, store name **Duello!**. Flat and PCVR are launch options on this SKU. GodotSteam lobbies + voice; own App ID still needed (code is Spacewar **480**). ~30% Valve cut. |

A Quest owner and a flat friend on Steam do **not** meet in an online lobby. The Quest build cannot join Steam. They can duel if the headset and the PC are on the same LAN, and both people own the game on their own platform. A second Steam copy for Quest owners is only useful so that person can also play on PC (flat or PCVR) and use Steam lobbies. If that PC copy is sold, price it as a cheap add-on for people who already bought Quest, not as another full game. Cross-buy (one purchase unlocks both stores) is still undefined.

---

## 5. Pricing recommendation (USD base)

**Working recommendation: $9.99** on Quest and on Steam, same USD, for the game as scoped now.

That scope is a short, dense duel: real revolver, three gunslingers, four arenas, a gauntlet, a practice range, off-hand tricks, and 1v1 voice. It is not a campaign, and the art budget in §6.1 cannot carry a $19.99 page. $5.99 undersells a finished stylized version and sits in the “thin experiment” shelf. $14.99 and up asks the buyer to compare Duello! with SUPERHOT-class games and refunds harder when a session is short.

| Scenario | Quest + Steam USD list | When |
|---|---|---|
| **Working recommendation** | **$9.99** | Stylized indie look, real gunshot audio, current scope |
| Thin / still greybox | Do not charge yet | Main Quest store will not carry an obvious greybox |
| If content grows | $14.99–$19.99 | Several more gunslingers, set pieces, or a campaign-lite, and art that can stand next to a $15 thumbnail |
| Premium ceiling | $24.99 | Only with SUPERHOT-level polish + content promise |
| Avoid | $5.99 as the identity of the game; ≥$29.99 | $5.99 is a sale price, not the list |

**Parity:** same USD on Quest and on the Steam app (flat and VR are one purchase there).

**Sales strategy:** do not launch $9.99 at −20–30%. The list is already an impulse price. Seasonal floor around **$6.99**.

### Brazil / regional localization

Developer is in Brazil; players need fair **BRL** (and other PPP regions). Prefer Steam **multi-variable / PPP** conversion, not raw FX; round to clean `.99` shelf prices.

| USD base | Typical BRL ballpark (PPP-ish) | Example clean tags |
|---|---|---|
| **$9.99 (list)** | ~45–55% of a raw FX conversion | **R$ 22,99 – R$ 27,99** |
| $14.99 (only if content grows) | same logic | **R$ 36,99 – R$ 46,99** |
| $19.99 (only if content grows) | same logic | **R$ 46,99 – R$ 59,99** |
| Sale floor ~$6.99 | — | **~R$ 18,99** |

Brazil is price-sensitive and large on Steam — slight underpricing in BRL usually beats lost volume. Mirror PPP feel on Meta localization too.

At $9.99 the §6.1 discovery story (main Quest store, organic Shorts and Reels, no ads, 2–3 years) still applies. Each copy pays about **US$4** to the developer instead of ~US$2.50, about 1.7× the $5.99 receipt. Expect a modest dip in units, not a collapse: $9.99 is still an impulse price. Planning take-home after the same 27,5% salary tax is about **R$19.000–51.000** over those three years (year 1 about **R$11.000–31.000**), versus **R$15.000–38.000** at $5.99. §6.1 keeps the worked $5.99 tables.

---

## 6. Revenue expectations (lifetime, rough)

Assumptions: premium paid; ~30% store cut; after tax/refunds/regional mix, developer often keeps **~55–65% of gross** before personal/corporate income tax in Brazil.

Niche VR western duel (not a franchise hit):

| Scenario | Copies (Quest + Steam, lifetime) | Gross USD | Dev net (ballpark) |
|---|---|---|---|
| Weak | 500–2,500 | $8k–$40k | ~$5k–$25k |
| **Base (most likely if polished)** | 4,000–15,000 | $70k–$250k | **~$40k–$150k** |
| Strong | 20,000–50,000+ | $350k–$900k+ | ~$200k–$550k+ |

**Plan around:** the **$9.99** line in §5 (about **R$19.000–51.000** kept over 2–3 years under the §6.1 discovery assumptions). The table below is the upside **if** the game later supports a $15–20 price. Quest carries volume; Steam is the smaller slice and the only online lobby.  
**Do not budget on** $1M+ Quest gross — rare (~100 apps cleared $1M gross on Quest in 2025 per Meta/public reporting).  
**Worked cheap model:** $5.99 copy counts, year split, and tax math are §6.1. That price is a sale floor, not the list.

### Levers that move outcomes

1. Reviews / ratings quality and a strong trailer (more than ±$2 list price).  
2. Meta featuring / influencer seeding of the slow-mo + draw fantasy.  
3. Art/audio polish justifying $19.99 vs looking greybox at $14.99.  
4. Post-launch free content (arenas, modes) extending the sales curve.  
5. Wishlist + launch week + seasonal sales.

### 6.1 $5.99 cash-budget scenario (2–3 year life)

Modeled 2026-09-25. This is the outcome if the game ships at **US$5.99** instead of the **$9.99** list in §5. The `0.6.0-alpha` build is still greybox arenas and placeholder audio (§3); both prices count only if that art pass actually lands.

**Assumptions**

- Same USD list on both stores. Separate SKUs; cross-buy is still undefined (§4).
- Cash outlay **~R$800**: Steam Direct fee (US$100) plus art. No ad spend.
- Store page shows a finished indie look, not greybox. Discovery is organic YouTube Shorts and Reels posted around launch.
- Planning and upside rows assume the **main Quest store**, not App Lab only. Quest is about two-thirds of units; SteamVR is the rest.
- Developer keeps about **US$2.50 per copy** after the 30% store cut, regional prices, tax inside the shelf price, and ~10–12% refunds. FX used here: **~R$5.15 per USD** (Sep 2026).
- Selling life is **about 2–3 years**. Roughly 60% of copies fall in year 1 (mostly the first 3 months, following the clips), ~25% in year 2 (seasonal sales and the Quest catalog), ~15% in year 3. After year 3 the tail is too small to plan on. A clip that hits late moves that year’s share with it.
- About **60 net copies** cover the R$800. Valve credits the Steam Direct fee back after **US$1,000** adjusted gross revenue.
- Take-home uses the developer’s salary of **~R$6.300/month net** (~R$8.400 gross). That already sits in the 27,5% IRPF bracket, past the 2026 zero-tax line (R$5.000/month and R$60.000/year), so game payouts are taxed at **27,5%** on top of salary. Brazil and the US have no income-tax treaty: Steam withholds 30% of the US-sourced slice only (often ~10–15% of the whole payout); Meta can do the same. That US tax is credited against the 27,5%, so it does not stack. About **R$72–73 of every R$100** the stores owe stays with the developer. Brazil’s share is settled on the annual return, not taken from the deposit — set aside ~15% of what hits the bank.

**Copies and take-home, full 2–3 year life** (Quest + Steam combined). “Stores owe” is the developer receipt after the store cut, before income tax.

| Outcome | Copies | Stores owe | You keep |
|---|---|---|---|
| Clips stay small, no Quest featuring | 400–1,000 | R$5.000–13.000 | **R$3.500–9.500** |
| **Planning** | **1,500–4,000** | **R$21.000–52.000** | **R$15.000–38.000** |
| One short travels, or Quest shows the page for a week | 5,000–12,000 | R$62.000–155.000 | **R$45.000–112.000** |

**Planning case over time** (1,500–4,000 copies). Shares are a typical shape, not a month-by-month forecast.

| When | Share of copies | You keep |
|---|---|---|
| Year 1, mostly the first 3 months | ~60% | **R$9.000–23.000** |
| Year 2 | ~25% | **R$4.000–10.000** |
| Year 3 | ~15% | **R$2.000–6.000** |

A normal year inside the planning case is a few thousand to the low twenties of thousands of reais, not the whole lifecycle at once. The salary already fills the top bracket every year, so spreading the payouts across three years does not lower the rate.

---

## 7. Open business decisions (for the refining agent)

Use these as questions to resolve; do not invent answers as shipped fact.

- [ ] Early Access vs 1.0. Main Quest store is decided (not App Lab). Store name on Quest and Steam is **Duello!**.  
- [ ] Lock the list: working recommendation is **$9.99** / about **R$ 22,99–27,99**, not yet confirmed.  
- [ ] Cross-buy / Quest↔Steam entitlement. Flat ships inside the Steam app. A second cheap Steam key for Quest owners is optional; it does not connect Quest online to Steam (§4).  
- [ ] Marketing budget and channel mix (Meta ads, YouTubers, Steam Next Fest, etc.).  
- [ ] Whether campaign / horde / 3P ship in v1 or post-launch roadmap for DLC vs free updates.  
- [ ] Publisher vs self-publish; funding / runway assumptions.  
- [ ] Age rating, content descriptors (violence), localization of UI/text beyond EN.  
- [ ] Tax / company setup for BR developer receiving USD from Steam + Meta.  
- [ ] Competitive teardown of current Quest western + duel titles (live prices, ratings, review counts).

---

## 8. One-pager for another agent (copy block)

```text
PRODUCT: Duello! (repo: Gunslinger VR) — Godot 4.7 Wild West VR duel game.
HOOK: Standoff gunfights with real projectile bullets, visible trails, Superhot-style
      tunable slow-mo; physical revolver draw/reload/spin; off-hand tricks;
      SP gauntlet + practice range + 1v1 with proximity voice.
PLATFORMS: Main Quest store (name Duello!, LAN-only MP) + one Steam app named Duello!
      with flat and PCVR launch options. Quest and Steam online do not cross.
      Same-LAN Quest + flat PC already can. App ID still Spacewar 480.
STATUS (v0.6.0-alpha): Duel, reload, gauntlet, practice hub, props, LAN + Steam 1v1,
      and voice are in. Arenas and the hub are Blender greyboxes (detail art open).
      Character mesh is not on AI or the remote avatar. Audio is placeholder except
      the duel-end sting. Campaign/horde/3P/4P/leaderboards planned.
PRICE REC: $9.99 list on Quest and Steam (~R$23–28 PPP). $14.99–$19.99 only if
      content and art grow. $5.99 is a sale price; worked model in §6.1.
BRAZIL: Developer salaried ~R$6.3k/month net. $9.99 list ~R$23–28 PPP; sale floor ~R$19.
      $15–20 shelf (~R$37–60) only if content grows.
REVENUE: Plan the $9.99 list: about R$19k–51k kept over 2–3 years after IRPF,
      same discovery as §6.1 (main Quest store, organic clips, no ads).
      $5.99 sale case is ~R$15k–38k. The $70k–$250k gross band is only if priced at $15–20.
COMPS: SUPERHOT VR ~$25 aspirational; Quest westerns mostly $8–$20. Duello! sits at $9.99.
ASK: Lock $9.99 or not; Early Access vs 1.0; cross-buy; age rating.
```

---

## 9. Related project docs

| File | Use |
|---|---|
| [`FEATURES.md`](FEATURES.md) | What exists / partial / planned |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Systems ownership |
| [`RELEASE_TODOS.md`](RELEASE_TODOS.md) | Pre-release TODOs and attention points |
| [`../Roadmap.md`](../Roadmap.md) | Future work by difficulty |
| [`../CHANGELOG.md`](../CHANGELOG.md) | User-facing history |
| [`../README.md`](../README.md) | Controls, run instructions, structure |
