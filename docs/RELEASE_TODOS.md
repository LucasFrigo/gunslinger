# Pre-release TODOs and attention points

Living ship checklist. Not a changelog and not the business brief.

**What already ships:** [`FEATURES.md`](FEATURES.md) · **How it works:** [`ARCHITECTURE.md`](ARCHITECTURE.md) · **SFX checklist:** [`SOUND.md`](SOUND.md) · **GTM / pricing:** [`BUSINESS_BRIEF.md`](BUSINESS_BRIEF.md) · **Roadmap:** [`../Roadmap.md`](../Roadmap.md)

Agents **must add or revise items here in the same session** as a new player-facing / shippable feature (store cert, SKU split, test matrix, known polish, “do not ship until…”). Check off or remove a line only when it is actually done in code. Do not invent work that is not in the change.

Status in FEATURES is `done` | `partial` | `planned` | `blocked`. Items below are **release blockers or gotchas**, not the full backlog.

## Must-fix

- [ ] Own Steam App ID — code still uses Spacewar **480** (`netcode/steam_transport.gd`, `steam_appid.txt`). Do not ship the Steam SKU on 480. Drop `steam_appid.txt` from store depots (Steam already knows the App ID). `from:` 1v1 Steam lobbies
- [x] GodotSteam 4.22 GDExtension + Steamworks redistributables in `addons/godotsteam/` for desktop editor and Windows/Linux/macOS export. Quest APK still excludes the addon. `from:` 1v1 Steam lobbies
- [x] Player-facing Settings on `ui/main_menu.tscn` (audio, comfort/turn, holster). Debug F3 is not a settings screen. `from:` main-menu settings
- [ ] Arenas: Main Street greybox kit is in (`assets/models/scenarios/main_street/`); Saloon interior greybox is in (`assets/models/scenarios/saloon/saloon_interior.glb`); Train Rooftop greybox is in (`assets/models/scenarios/train_rooftop/`); Canyon greybox is in (`assets/models/scenarios/canyon/canyon.glb`). Detail meshes for all four before a paid listing (Roadmap art items). Manual: walk Main Street boardwalks via the invisible street-side slope colliders, take cover behind awning posts, confirm the 16 m duel lane is clear and bullets hit world collision. Saloon: walk the room (including the balcony stair), take cover behind the bar and the east tables, confirm the 10 m lane is clear, and confirm a standing VR height does not clip the 4.2 m ceiling. Train Rooftop: walk both roofs and across the coupler, confirm the invisible walls keep you on the train, confirm the 20 m lane is clear (a shot still reaches the other roof), confirm cliff faces do not flicker, and confirm you cannot see tracks, cacti, or canyons pop in at the far end. Canyon: walk the wash, take cover behind the rocks, confirm the 22 m lane is clear, confirm bullets hit the cliffs, and confirm the rim is a sheer drop (no wide slope), you cannot walk off it, and the desert, plants, and distant mesas read out to the horizon. `from:` arenas (partial)
- [ ] Gunslinger mesh is A-pose only and not on AI or the remote avatar. `from:` character mesh (partial)
- [ ] Audio / VFX catalogs are stub-swap paths; replace placeholders before a paid listing. SFX boxes: [`SOUND.md`](SOUND.md). `from:` impact / AV polish

## Platform / store

- [ ] Decide Meta Store vs App Lab; Quest certification / featuring. `from:` Quest 3 SKU
- [ ] Steam store page, depots, OpenXR / SteamVR launch options, age rating, violence descriptors.
- [ ] **Meta Store / Quest APK stays LAN-only.** Never enable GodotSteam or Steam lobby UI on Android (`NetworkManager.steam_available()`, `export_presets.cfg` `exclude_filter=addons/godotsteam/*`). `from:` 1v1 Steam lobbies
- [ ] Cross-buy / Quest↔Steam entitlement is undefined — GTM decision, see [`BUSINESS_BRIEF.md`](BUSINESS_BRIEF.md).

## Multiplayer

- [ ] Two-PC Steam NAT test: Steam client running on both, **HOST (STEAM)** / auto-refresh list / join, duel + rematch, leave/rejoin. Invite is Esc → **Invite friends** (or Shift+Tab), not auto-opened on host. `from:` 1v1 Steam lobbies
- [ ] Confirm Steam Datagram Relay (`initRelayNetworkAccess` + `SteamMultiplayerPeer.server_relay`) across a hard NAT; LAN ENet is a different path. `from:` 1v1 Steam lobbies
- [ ] Do not advertise 4-player or ranked matchmaking — those are still planned. `from:` 4-player MP / ranking
- [ ] **Two-machine voice test, LAN and Steam.** Talk both ways, confirm distance falloff across the 16 m lane (and that walking off makes the peer fade), mute each side and confirm the **X over the mouth** appears on the other screen, toggle push-to-talk, and leave/rejoin with voice still working. `from:` proximity voice
- [ ] **Quest mic on a sideloaded APK.** First MP session must show the Android mic prompt (`RECORD_AUDIO` comes from `addons/gunslinger_lan_permissions/`, not the export checkbox); granting it mid-session should start voice without a restart. Deny it and confirm the duel still plays, silently. `from:` proximity voice
- [ ] Flat desktop with speakers will echo — there is no acoustic echo cancellation. Decide before launch whether that is a headphones-recommended note, a default-on push-to-talk, or real AEC. `from:` proximity voice
- [ ] Voice is unencrypted PCM over the gameplay channel. Fine for LAN and Steam Datagram Relay; revisit if a direct-IP WAN path is ever offered. `from:` proximity voice
- [ ] No per-player mute of the *other* side yet — mute only gags your own mic. Add a "mute them" control before any public lobby matchmaking. `from:` proximity voice
- [x] Reject MP join when `application/config/version` differs (Steam lobby metadata + LAN beacon + handshake; both versions shown). [BUG-008](BUGS.md). `from:` MP version check
- [x] Steam leave then HOST / JOIN in the same process. [BUG-009](BUGS.md). `from:` Steam leave / rejoin
- [ ] **Re-run the two-PC Steam test after the BUG-009 fix.** Host and joiner now connect through `create_host` / `create_client` on an advertised virtual port instead of `host_with_lobby` / `connect_to_lobby`; only the single-process create/leave/create cycle could be verified locally. `from:` Steam leave / rejoin
- [ ] Known edge: a client that already spent a host's virtual port in this session cannot rejoin that same lobby until the host re-hosts (it refuses with a message instead of failing silently). `from:` Steam leave / rejoin
- [ ] Manual: two builds with different `VERSION` — Steam list disabled + refuse, LAN list disabled + refuse, typed IP handshake refuse; same-version still starts a duel. `from:` MP version check

## Content / polish

- [ ] Time of day: on Canyon and Train Rooftop, scrub F3 `time_of_day` through dawn and dusk and confirm the desert edge and the belt wrap still dissolve into the sky (no horizon line, no shadow seam in front of the mesas, no popping tracks). Saloon stays lamp-lit. `from:` random time of day
- [ ] Shorter bullet-trail fade (`weapons/bullet_trail.gd` `FADE_TIME` 1.6s). `from:` shorter bullet trails (planned)
- [x] Main menu: Singleplayer / Multiplayer buttons that open the current SP and MP UIs. `from:` main menu SP / MP split
- [ ] Lingering barrel smoke (stub `muzzle_smoke` is a short puff). `from:` barrel smoke (planned)
- [ ] Outdoor wind bed per arena + visual gusts that play a gust SFX. Saloon is interior (no outdoor bed). `from:` wind bed + gusts (planned)
- [ ] Persistent gauntlet high scores (session-only today). `from:` gauntlet scores (planned)
- [ ] Reload mesh-fit / cylinder-flip polish can land later; volumes exist on layer `reload`. `from:` interactive reload
- [x] VR default: gun-hand stick down cocks; A is trick-shot / spin. `from:` VR cock on stick-down
- [x] Button remapping in Settings (`user://settings.cfg`). `from:` button remapping

## Attention

- Voice chat needs `audio/driver/enable_input=true`, and Godot opens the input device when the audio driver initialises — so the OS "microphone in use" indicator can light up at launch even in single-player. `VoiceChat` still only *streams* during a session (and only while the gate is open), but expect the question in reviews, and check the Quest mic indicator behaviour on device.
- Pause overlay: confirm ESC (flat) and VR menu in free duel, gauntlet, and 1v1. SP must freeze AI/bullets; MP overlay must not freeze the peer. Host-only restart; Quit returns to the main menu and drops the session.
- Main menu landing: Singleplayer / Multiplayer pages, plus Settings / Quit. Esc or Back returns to landing. LAN/Steam host lists only refresh while the Multiplayer page is open.
- Steam lobby testing needs the **Steam client** running; `steamInitEx` fails otherwise (`Steam is not running or failed to initialize.`).
- After cloning, **restart the Godot editor** so `addons/godotsteam/` loads. If you use the Steam-store Godot editor on Windows, its bundled `steam_api64.dll` can be older than GodotSteam 4.22 — replace it with `addons/godotsteam/win64/steam_api64.dll` if the extension fails to load.
- Two editors on one Steam account will not look like two players; use two accounts (Spacewar 480 is fine for that).
- Steam Link + Godot editor is **Windows PCVR**, not the Quest APK. Quest LAN must be tested with a sideloaded export (`addons/gunslinger_lan_permissions/`).
- Host Steam overlay invite is opt-in (pause **Invite friends** or Shift+Tab); it no-ops if overlay is disabled or the GodotSteam method is missing. Do not auto-open it on HOST — that steals the click and can stick the overlay.
- Flat `--flat` harness is not a store SKU unless positioned later.
- Confirm the first shot after a fresh launch no longer hitchs (boot loading screen in `ImpactFeedback`; [BUG-010](BUGS.md)). VR and flat; editor and export. The hitch should land on Loading, not the first round.
- Drop `-alpha` from `VERSION` only when cutting a named release (see `.cursor/rules/version-bump.mdc`).
