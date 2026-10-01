# Gunslinger VR — Business Brief

Briefing for business / pricing / go-to-market refinement.  
**Audience:** planning agents or humans. **Source of truth for features:** [`FEATURES.md`](FEATURES.md), [`../Roadmap.md`](../Roadmap.md), [`../README.md`](../README.md). **Ship checklist:** [`RELEASE_TODOS.md`](RELEASE_TODOS.md).  
**As of:** 2026-10-01 · **Code version:** `0.6.0-alpha` snapshot (see [`../VERSION`](../VERSION); file is now `0.7.0-alpha`)  
**$5.99 cash scenario:** 2026-09-25 · §6.1  
**US sales forecast, 30% US withholding, Remessa Online:** 2026-10-01 · §6.2

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
| Medium | Duel title cards; duel vs up to 3 NPCs; ragdoll and dismemberment |
| Hard | Horde |
| Very hard | Campaign; mod support |
| Ideas (not ready) | Airborne trick shots; more props and NPCs; train that crosses the lane; oil-field train; horseback duel; Mexican standoff (3 humans); 4-player MP; ranking / leaderboards (Steam only) |

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

At $9.99 the §6.1 discovery story (main Quest store, organic Shorts and Reels, no ads, 2–3 years) still applies. Each copy pays about **US$4** to the developer instead of ~US$2.50, about 1.6× the $5.99 receipt, before income tax and the transfer. Expect a modest dip in units, not a collapse: $9.99 is still an impulse price. Planning case is about **1.300–3.400** copies, of which about **600–1.500** are US sales (§6.2). Take-home after the 30% US withholding, Remessa Online, and IRPF is about **R$19.000–49.000** over those three years (year 1 about **R$11.000–29.000**), versus **R$14.500–36.000** at $5.99.

---

## 6. Revenue expectations (lifetime, rough)

Assumptions: premium paid; ~30% store cut; after tax/refunds/regional mix, developer often keeps **~55–65% of gross** before personal income tax, the 30% US withholding, and the Remessa spread. About **45% of copies** are US sales (§6.2).

Niche VR western duel (not a franchise hit). “Dev net” here is after the store cut only. US withholding, IRPF, and Remessa are not in that column; the cash you can spend is §6.2.

| Scenario | Copies (Quest + Steam, lifetime) | of which US (~45%) | Gross USD | Dev net before US tax, IRPF, Remessa |
|---|---|---|---|---|
| Weak | 500–2,500 | 200–1.100 | $8k–$40k | ~$5k–$25k |
| **Base (most likely if polished)** | 4,000–15,000 | 1.800–6.800 | $70k–$250k | **~$40k–$150k** |
| Strong | 20,000–50,000+ | 9.000–23.000+ | $350k–$900k+ | ~$200k–$550k+ |

**Plan around:** the **$9.99** line in §5 (about **R$19.000–49.000** kept over 2–3 years under the §6.1 discovery assumptions and the §6.2 tax path). The table above is the upside **if** the game later supports a $15–20 price. Quest carries volume; Steam is the smaller slice and the only online lobby.  
**Do not budget on** $1M+ Quest gross — rare (~100 apps cleared $1M gross on Quest in 2025 per Meta/public reporting).  
**Worked cheap model:** $5.99 copy counts, year split, and the same tax math are §6.1. That price is a sale floor, not the list. The US forecast is §6.2.

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
- Developer keeps about **US$2.50 per copy** after the 30% store cut, regional prices, tax inside the shelf price, and ~10–12% refunds. That figure is before US withholding, Remessa, and IRPF. FX used here: **~R$5.15 per USD** (Sep 2026).
- Selling life is **about 2–3 years**. Roughly 60% of copies fall in year 1 (mostly the first 3 months, following the clips), ~25% in year 2 (seasonal sales and the Quest catalog), ~15% in year 3. After year 3 the tail is too small to plan on. A clip that hits late moves that year’s share with it.
- About **60 net copies** cover the R$800 at the store receipt, before the taxes in §6.2. Valve credits the Steam Direct fee back after **US$1,000** adjusted gross revenue.
- Take-home uses the developer’s salary of **~R$6.300/month net** (~R$8.400 gross). That already sits in the 27,5% IRPF bracket, past the 2026 zero-tax line (R$5.000/month and R$60.000/year), so game payouts are taxed at **27,5%** on top of salary. About **45% of copies are US sales**, and those are about **65% of this receipt**. The US withholds **30%** of that US slice (no treaty). Remessa Online then takes about **2%** of what is wired (§6.2). The US tax is credited against the 27,5% on the annual return, so Brazil does not tax the US slice again. About **R$69 of every R$100** the stores owe stays with the developer. Set aside ~12% of what hits the bank for the Brazilian tax on the non-US slice.

**Copies and take-home, full 2–3 year life** (Quest + Steam combined). “Stores owe” is the developer receipt after the store cut, before US withholding, Remessa, and IRPF. “You keep” uses the §6.2 path.

| Outcome | Copies | of which US (~45%) | Stores owe | You keep |
|---|---|---|---|---|
| Clips stay small, no Quest featuring | 400–1,000 | 180–450 | R$5.000–13.000 | **R$3.500–9.000** |
| **Planning** | **1,500–4,000** | **700–1.800** | **R$21.000–52.000** | **R$14.500–36.000** |
| One short travels, or Quest shows the page for a week | 5,000–12,000 | 2.300–5.400 | R$62.000–155.000 | **R$43.000–107.000** |

**Planning case over time** (1,500–4,000 copies, about 700–1.800 of them US). Shares are a typical shape, not a month-by-month forecast.

| When | Share of copies | You keep |
|---|---|---|
| Year 1, mostly the first 3 months | ~60% | **R$9.000–22.000** |
| Year 2 | ~25% | **R$3.500–9.000** |
| Year 3 | ~15% | **R$2.000–5.500** |

A normal year inside the planning case is a few thousand to the low twenties of thousands of reais, not the whole lifecycle at once. The salary already fills the top bracket every year, so spreading the payouts across three years does not lower the rate.

### 6.2 US sales forecast and the path into Brazil

Modeled 2026-10-01. This is the planning forecast for **where copies sell**, and what is left after the US tax and the transfer. The list price in the tables is **$9.99**. The $5.99 rows in §6.1 use the same rates.

**Where the copies are assumed to sell**

English store page, Quest about two-thirds of units. No measured store data yet.

- About **45% of copies** are bought in the United States. The rest is Europe, the UK, Canada, Australia, Brazil, and a long tail.
- US buyers pay the full USD list. PPP regions pay less, and VAT sits inside many non-US shelf prices. So the US is about **65% of what the stores owe**, not 45%.
- Quest and Steam each apply their own 30% cut before this split. The 30% below is a second cut, taken only on the US slice, because the developer lives in Brazil.

**One US copy, expected value** (store cut already out, ~11% refunds). Brazil adds no further income tax on this copy when the credit below is claimed.

| List | Stores owe | US withholds 30% | Wired | After Remessa ~2% | In the bank |
|---|---|---|---|---|---|
| **$9.99** | ~US$6.20 | ~US$1.90 | ~US$4.35 | ~US$4.25 | **~R$22** |
| $5.99 | ~US$3.75 | ~US$1.10 | ~US$2.60 | ~US$2.55 | **~R$13** |

**$9.99 forecast, Quest + Steam, 2–3 years.** Copy counts are the §6.1 discovery case with the modest dip already in §5 (about 15% fewer copies than $5.99). US columns use 45% of copies and 65% of the receipt.

| Outcome | Copies | US copies | Stores owe | US slice | US tax 30% | You keep |
|---|---|---|---|---|---|---|
| Clips stay small | 350–850 | 150–400 | R$7.000–18.000 | R$5.000–12.000 | R$1.500–3.500 | **R$5.000–12.000** |
| **Planning** | **1.300–3.400** | **600–1.500** | **R$27.000–70.000** | **R$18.000–46.000** | **R$5.000–14.000** | **R$19.000–49.000** |
| One short travels, or Quest features the page | 4.300–10.200 | 1.900–4.600 | R$88.000–210.000 | R$57.000–137.000 | R$17.000–41.000 | **R$61.000–146.000** |

**Planning case over time** at $9.99 (1.300–3.400 copies, 600–1.500 of them US).

| When | Share of copies | You keep |
|---|---|---|
| Year 1, mostly the first 3 months | ~60% | **R$11.000–29.000** |
| Year 2 | ~25% | **R$5.000–12.000** |
| Year 3 | ~15% | **R$3.000–7.000** |

**Of every R$100 the stores owe** (both regions together):

| Step | Leaves | Still there |
|---|---|---|
| US withholds 30% of the US slice (65% of the receipt) | R$19,50 | R$80,50 wired |
| Remessa Online ~2% of the wire | R$1,60 | R$78,90 in the bank |
| Brazil IRPF 27,5% on the non-US slice only (35%) | R$9,60 | **R$69 kept** |

The US tax is credited against IRPF on the annual return, up to the Brazilian tax on that same income. 30% is more than 27,5%, so the credit uses up the Brazilian tax on US sales and the extra 2,5 points are not refunded. If that credit is not claimed, the same planning case keeps about **R$14.000–36.000** instead of **R$19.000–49.000**.

**Remessa Online** (rates on their site, 2026-10-01). The developer is pessoa física, same as the salary in §6.1. Payout destination is Remessa’s USD details, then a rescue into the Brazilian account.

- **IOF 0,38%** on money coming into Brazil. This is the tax. Source: Remessa help, “Taxas”.
- **Their fee is a spread, not a tax.** Pessoa física example on the For Creators page: **1,64% + R$39,90** on a US$100 receipt. The same page says the cost starts at **0,7%** as the amount grows.
- Tables use **~2%** of the wired amount (1,64% + 0,38% IOF) and leave out the R$39,90. That holds when each rescue is a few thousand reais. A US$100 rescue is closer to **10%** all-in, because R$39,90 dominates. Batch the rescues.
- A company would use the lower PJ “recebimento de serviços” schedule (from 0,99% down to 0,60%, plus R$16,90 on small USD receipts). That path is not in these numbers.

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
- [ ] Tax / company setup. Working path is pessoa física + Remessa Online, with the 30% US withholding credited on the annual return (§6.2). A CNPJ would change the Remessa spread and the Brazilian tax. Not decided.  
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
BRAZIL: Developer salaried ~R$6.3k/month net, pessoa física. Payouts via Remessa
      Online (~2% on a batched rescue: ~1.64% spread + 0.38% IOF). A US$100
      rescue is ~10% because of a R$39.90 tariff. $9.99 list ~R$23–28 PPP.
REVENUE: Plan $9.99: about R$19k–49k kept over 2–3 years. ~45% of copies are US
      (~600–1,500 in the planning case) and ~65% of the receipt; the US withholds
      30% of that slice before the wire. Credit it against IRPF so it does not
      stack. $5.99 sale case is ~R$14.5k–36k. The $70k–$250k gross band is only
      if priced at $15–20, and that column is before this tax path.
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
