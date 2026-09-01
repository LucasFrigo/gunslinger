# Pre-release TODOs and attention points

Living ship checklist. Not a changelog and not the business brief.

**What already ships:** [`FEATURES.md`](FEATURES.md) · **How it works:** [`ARCHITECTURE.md`](ARCHITECTURE.md) · **GTM / pricing:** [`BUSINESS_BRIEF.md`](BUSINESS_BRIEF.md) · **Roadmap:** [`../Roadmap.md`](../Roadmap.md)

Agents **must add or revise items here in the same session** as a new player-facing / shippable feature (store cert, SKU split, test matrix, known polish, “do not ship until…”). Check off or remove a line only when it is actually done in code. Do not invent work that is not in the change.

Status in FEATURES is `done` | `partial` | `planned` | `blocked`. Items below are **release blockers or gotchas**, not the full backlog.

## Must-fix

- [ ] Own Steam App ID — code still uses Spacewar **480** (`netcode/steam_transport.gd`, `steam_appid.txt`). Do not ship the Steam SKU on 480. Drop `steam_appid.txt` from store depots (Steam already knows the App ID). `from:` 1v1 Steam lobbies
- [x] GodotSteam 4.22 GDExtension + Steamworks redistributables in `addons/godotsteam/` for desktop editor and Windows/Linux/macOS export. Quest APK still excludes the addon. `from:` 1v1 Steam lobbies
- [x] Player-facing Settings on `ui/main_menu.tscn` (audio, comfort/turn, holster). Debug F3 is not a settings screen. `from:` main-menu settings
- [ ] Arenas are greybox CSG — not premium-shelf art. `from:` arenas (partial)
- [ ] Gunslinger mesh is A-pose only and not on AI or the remote avatar. `from:` character mesh (partial)
- [ ] Audio / VFX catalogs are stub-swap paths; replace placeholders before a paid listing. `from:` impact / AV polish

## Platform / store

- [ ] Decide Meta Store vs App Lab; Quest certification / featuring. `from:` Quest 3 SKU
- [ ] Steam store page, depots, OpenXR / SteamVR launch options, age rating, violence descriptors.
- [ ] **Meta Store / Quest APK stays LAN-only.** Never enable GodotSteam or Steam lobby UI on Android (`NetworkManager.steam_available()`, `export_presets.cfg` `exclude_filter=addons/godotsteam/*`). `from:` 1v1 Steam lobbies
- [ ] Cross-buy / Quest↔Steam entitlement is undefined — GTM decision, see [`BUSINESS_BRIEF.md`](BUSINESS_BRIEF.md).

## Multiplayer

- [ ] Two-PC Steam NAT test: Steam client running on both, **HOST (STEAM)** / auto-refresh list / join, duel + rematch, leave/rejoin. Overlay invite opens on host if GodotSteam exposes `activateGameOverlayInviteDialog`. `from:` 1v1 Steam lobbies
- [ ] Confirm Steam Datagram Relay (`initRelayNetworkAccess` + `SteamMultiplayerPeer.server_relay`) across a hard NAT; LAN ENet is a different path. `from:` 1v1 Steam lobbies
- [ ] Do not advertise 4-player, ranked matchmaking, or proximity voice — those are still planned. `from:` 4-player MP / ranking / voice
- [ ] Mismatched `gunslinger_version` lobby metadata is stored but not rejected on join — decide whether to block or warn. `from:` 1v1 Steam lobbies

## Content / polish

- [ ] Shorter bullet-trail fade (`weapons/bullet_trail.gd` `FADE_TIME` 1.6s). `from:` shorter bullet trails (planned)
- [ ] Lingering barrel smoke (stub `muzzle_smoke` is a short puff). `from:` barrel smoke (planned)
- [ ] Persistent gauntlet high scores (session-only today). `from:` gauntlet scores (planned)
- [ ] Reload mesh-fit / cylinder-flip polish can land later; volumes exist on layer `reload`. `from:` interactive reload

## Attention

- Pause overlay: confirm ESC (flat) and VR menu in free duel, gauntlet, and 1v1. SP must freeze AI/bullets; MP overlay must not freeze the peer. Host-only restart; Quit returns to the main menu and drops the session.
- Steam lobby testing needs the **Steam client** running; `steamInitEx` fails otherwise (`Steam is not running or failed to initialize.`).
- After cloning, **restart the Godot editor** so `addons/godotsteam/` loads. If you use the Steam-store Godot editor on Windows, its bundled `steam_api64.dll` can be older than GodotSteam 4.22 — replace it with `addons/godotsteam/win64/steam_api64.dll` if the extension fails to load.
- Two editors on one Steam account will not look like two players; use two accounts (Spacewar 480 is fine for that).
- Steam Link + Godot editor is **Windows PCVR**, not the Quest APK. Quest LAN must be tested with a sideloaded export (`addons/gunslinger_lan_permissions/`).
- Host Steam overlay invite is best-effort; it no-ops if overlay is disabled or the GodotSteam method is missing. Do not treat a missing overlay as a transport failure.
- Flat `--flat` harness is not a store SKU unless positioned later.
- Drop `-alpha` from `VERSION` only when cutting a named release (see `.cursor/rules/version-bump.mdc`).
