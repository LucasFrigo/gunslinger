# Gunslinger VR — Business Brief

Briefing for business / pricing / go-to-market refinement.  
**Audience:** planning agents or humans. **Source of truth for features:** [`FEATURES.md`](FEATURES.md), [`../Roadmap.md`](../Roadmap.md), [`../README.md`](../README.md).  
**As of:** 2026-08-20 · **Code version:** `0.1.0-alpha` (see [`../VERSION`](../VERSION))

---

## 1. Elevator pitch

**Gunslinger VR** is a Godot 4.x Wild West gun-dueling game for VR: single-player gauntlet vs AI gunslingers and 1v1 multiplayer. Bullets are real slow projectiles with visible trajectories; Superhot-style slow motion is tunable. The fantasy is the classic standoff — draw, shoot, dodge — not an open-world western.

---

## 2. Product snapshot

| Field | Value |
|---|---|
| Working title | Gunslinger VR |
| Genre | VR action / duel shooter / Wild West |
| Engine | Godot 4.6+ (dev against 4.7), GDScript |
| Primary platforms (shipping intent) | **Meta Quest Store** (Quest 3 standalone) + **Steam** (PCVR; Steam lobbies for MP) |
| Secondary / harness | Flat desktop test mode (`--flat`); OpenXR PCVR (SteamVR / Quest Link) |
| Monetization (assumed) | Premium paid (no IAP planned today) |
| Multiplayer | 1v1 LAN (done); 1v1 Steam lobbies (partial — GodotSteam optional) |
| Studio context | Solo / small indie; developer based in **Brazil** |
| Language / storefront | Product English today; localized **prices** planned (esp. BRL) |

### Core loop

1. Standoff → bell → draw → fire → first **lethal** hit resolves (head instakill; torso/limb HP).  
2. Early draw = foul.  
3. Holster / draw / cock / fire on a single-action revolver feel.  
4. Optional slow-mo modes (SP only): CONSTANT, ON_DRAW, MOVEMENT (Superhot), NEAR_MISS.  
5. SP: free duel or 6-rung gauntlet (3 lives, session score).  
6. MP: 1v1 over LAN or Steam; gameplay slow-mo hard-disabled in network sessions (kill-cam burst still plays after a lethal hit).

### Differentiators (marketing hooks)

- Visible bullet trajectories + tunable bullet-time (SUPERHOT-adjacent fantasy in a western).  
- Physical VR gunplay: hip draw/holster, interactive reload (B open, belt feed, bump/swing close; dump/close thresholds tunable).  
- Kill cam: cinematic trail fly-along (flat `Camera3D` / VR spectator origin); SP and 1v1 MP.  
- Data-driven AI archetypes and arenas (easy to expand content without rewrites).  
- Dual ship: Quest standalone volume + Steam PCVR / lobby culture.

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

- Core duel state machine (standoff → bell → draw → resolve, early-draw foul).  
- Holster / draw / fire / cock; projectile bullets + trails; head/torso/arm/leg hitboxes with regional rules (head instakill, arm disarm, leg slow).  
- Free duel (arena + AI pick); gauntlet (6 rungs, 3 lives, session score).  
- AI archetypes: Drunk / Sheriff / Ghost.  
- 1v1 LAN multiplayer + UDP discovery.  
- Slow-mo modes (SP); near-miss hook; kill cam (SP + 1v1 MP, VR spectator ride).  
- Duel-end sting on lethal hit (`duel_end.wav`). 
- Impact feedback stubs (SFX / VFX / haptics).  
- Quest 3 / PCVR / flat harness.  
- Debug panel + presets; headless autotests.

### Partial (needs polish before “premium” price)

- Interactive reload (B open / sustained shake dump / torso belt physical rounds / bump-swing close; HUD status; dump/close live-tunable; flip polish TBD).  
- Arenas: Main Street, Saloon, Train Rooftop, Canyon — **greybox CSG**; real art TBD.  
- Steam lobbies transport (addon optional / may be absent; app ID 480 until owned).  
- Audio/VFX catalogs are stub-swap paths (placeholders → final assets).

### Planned (roadmap — not required for thin v1, raise price if shipped)

| Priority band | Items |
|---|---|
| Medium | Reload polish; moving train set piece; gun release / trick shots |
| Hard | Horde mode; Mexican standoff (3P); ranking / leaderboards |
| Very hard | Campaign; mod support |

### Content depth implication for pricing

- **Thin / Early Access-ish v1:** duel loop + gauntlet + MP, greybox or light art → lean **$9.99–$14.99**.  
- **Polished niche v1:** strong gun feel, art/audio, sticky SP+MP → **$14.99–$19.99**.  
- **Premium showcase:** depth closer to SUPERHOT / big western shooters (more modes, set pieces, campaign-lite) → only then **$24.99**.

---

## 4. Target platforms & distribution

| Platform | Role | Notes |
|---|---|---|
| **Meta Quest Store** | Primary **volume** | Quest 3 export; App Lab vs full store TBD (certification / featuring). ~30% platform fee. |
| **Steam** | PCVR + wishlist / MP lobbies | GodotSteam for lobbies; own App ID needed. ~30% Valve cut. |
| Flat / Link | Dev + accessibility | Flat is harness; not a primary SKU unless positioned later. |

Cross-buy / Quest↔Steam entitlement: **not defined** — decide in go-to-market (separate SKUs vs key linking).

---

## 5. Pricing recommendation (USD base)

| Scenario | Quest + Steam USD list | When |
|---|---|---|
| Thin / EA | $9.99–$14.99 | Limited art, short content |
| **Recommended center** | **$14.99–$19.99** | Focused duel game, polished feel |
| Practical default | **$16.99 or $19.99** | If ship quality supports “real game” not toy |
| Premium ceiling | $24.99 | Only with SUPERHOT-level polish + content promise |
| Avoid | &lt;$9.99 (Quest) unless EA; ≥$29.99 without campaign/big content | Signals wrong tier |

**Parity:** keep the same USD base on Quest and Steam.

**Sales strategy (suggested):** launch −20–30%; seasonal floors around **$9.99**; lifetime revenue often improved by discount cadence vs never-sale high price.

### Brazil / regional localization

Developer is in Brazil; players need fair **BRL** (and other PPP regions). Prefer Steam **multi-variable / PPP** conversion, not raw FX; round to clean `.99` shelf prices.

| USD base | Typical BRL ballpark (PPP-ish) | Example clean tags |
|---|---|---|
| $14.99 | ~45–55% of USD “effort” | **R$ 36,99 – R$ 46,99** |
| $19.99 | same logic | **R$ 46,99 – R$ 59,99** |
| Sale floor ~$9.99 | — | **~R$ 27,99** |

Brazil is price-sensitive and large on Steam — slight underpricing in BRL usually beats lost volume. Mirror PPP feel on Meta localization too.

---

## 6. Revenue expectations (lifetime, rough)

Assumptions: premium paid; ~30% store cut; after tax/refunds/regional mix, developer often keeps **~55–65% of gross** before personal/corporate income tax in Brazil.

Niche VR western duel (not a franchise hit):

| Scenario | Copies (Quest + Steam, lifetime) | Gross USD | Dev net (ballpark) |
|---|---|---|---|
| Weak | 500–2,500 | $8k–$40k | ~$5k–$25k |
| **Base (most likely if polished)** | 4,000–15,000 | $70k–$250k | **~$40k–$150k** |
| Strong | 20,000–50,000+ | $350k–$900k+ | ~$200k–$550k+ |

**Plan around:** low five-figures to low six-figures **gross** for v1; Quest carries volume; Steam smaller but useful.  
**Do not budget on** $1M+ Quest gross — rare (~100 apps cleared $1M gross on Quest in 2025 per Meta/public reporting).

### Levers that move outcomes

1. Reviews / ratings quality and a strong trailer (more than ±$2 list price).  
2. Meta featuring / influencer seeding of the slow-mo + draw fantasy.  
3. Art/audio polish justifying $19.99 vs looking greybox at $14.99.  
4. Post-launch free content (arenas, modes) extending the sales curve.  
5. Wishlist + launch week + seasonal sales.

---

## 7. Open business decisions (for the refining agent)

Use these as questions to resolve; do not invent answers as shipped fact.

- [ ] Exact launch SKU: Early Access vs 1.0; App Lab vs full Quest store.  
- [ ] Final list price: $14.99 / $16.99 / $19.99 (and BRL tags).  
- [ ] Cross-platform entitlement / price parity / regional matrix (Steam currencies + Meta).  
- [ ] Marketing budget and channel mix (Meta ads, YouTubers, Steam Next Fest, etc.).  
- [ ] Whether campaign / horde / 3P ship in v1 or post-launch roadmap for DLC vs free updates.  
- [ ] Publisher vs self-publish; funding / runway assumptions.  
- [ ] Age rating, content descriptors (violence), localization of UI/text beyond EN.  
- [ ] Tax / company setup for BR developer receiving USD from Steam + Meta.  
- [ ] Competitive teardown of current Quest western + duel titles (live prices, ratings, review counts).

---

## 8. One-pager for another agent (copy block)

```text
PRODUCT: Gunslinger VR — Godot 4 Wild West VR duel game.
HOOK: Standoff gunfights with real projectile bullets, visible trails, Superhot-style
      tunable slow-mo; physical revolver draw/reload; SP gauntlet + 1v1 MP.
PLATFORMS: Meta Quest Store (Quest 3) + Steam PCVR; premium paid assumed.
STATUS (v0.1.0): Core duel, gauntlet, LAN MP done; Steam MP partial; arenas greybox;
      reload/AV partial; campaign/horde/3P/leaderboards planned.
PRICE REC: USD $14.99–$19.99 center ($16.99 or $19.99 if polished); avoid <$9.99
      unless EA; $24.99 only if premium depth. Same USD on both stores.
BRAZIL: PPP/local BRL ~R$37–R$60 for that USD band; sale floor ~R$28; developer in BR.
REVENUE: Base case ~$70k–$250k gross / ~$40k–$150k net lifetime if polished;
      weak <$40k gross; strong is upside not baseline. Quest = volume.
COMPS: SUPERHOT VR ~$25 aspirational; Quest westerns mostly $8–$20.
ASK: Refine GTM, exact price ladder, regional matrix, launch format, and financial model.
```

---

## 9. Related project docs

| File | Use |
|---|---|
| [`FEATURES.md`](FEATURES.md) | What exists / partial / planned |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Systems ownership |
| [`../Roadmap.md`](../Roadmap.md) | Future work by difficulty |
| [`../CHANGELOG.md`](../CHANGELOG.md) | User-facing history |
| [`../README.md`](../README.md) | Controls, run instructions, structure |
