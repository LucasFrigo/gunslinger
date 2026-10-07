---
name: gunslinger-gameplay
description: >-
  Implement and change Gunslinger VR gameplay in Godot 4.6+ / 4.7 GDScript.
  Use when editing .gd or .tscn files, adding or fixing combat, VR, flat,
  AI, multiplayer, scenarios, props, or VFX, or when working a Roadmap.md
  item. Keeps code concise, on the existing harnesses, and inside the files
  the feature already names.
---

# Gunslinger gameplay

Godot **4.6+ / 4.7**, GDScript, GL Compatibility. No C#, no Godot 3 APIs, no new GDExtension unless the user asks.

Read the `docs/FEATURES.md` row and the matching `docs/ARCHITECTURE.md` section before editing. `docs/design/` is fiction until a code path exists. Standing rules in `.claude/rules/` still apply (ask before locking a plan, update docs, git confirmation, version bump).

## Write concise GDScript

Match the scripts already in the repo (`weapons/weapon_base.gd`, `combat/combat_rules.gd`):

- Static types on variables, arguments, and returns. `class_name` when another script needs the type.
- Tabs. `##` one line on the class. Comment only an invariant the next reader would get wrong.
- `StringName` literals as `&"head"`. Named constants for tunables, not magic numbers inline.
- Extend the owner that already does the job. Do not add a parallel system.

| Need | Extend |
|---|---|
| Gun, fire, cock, reload, toss | `weapons/weapon_base.gd` / `weapons/revolver/revolver.gd` |
| Duel states | `gauntlet/duel_manager.gd` |
| Hits | `combat/combat_rules.gd`, `player/hitbox.gd` |
| Shot / impact / haptic | `autoload/impact_feedback.gd` plus `AudioCatalog` / `VfxCatalog` |
| Off-hand prop | `props/prop_controller.gd` `ITEMS` + one `OffhandProp` script |
| New enemy | `ai/archetypes/*.tres` (`AIArchetype`). No new AI script |
| New arena | `scenarios/` folder, `ScenarioBase` markers, path on `GameManager.SCENARIOS` |
| New gauntlet rung | `DuelEncounter` .tres |
| Live tuning | `GameManager.tuning` and the F3 panel, persisted under `user://` |

## Who the change applies to

Name VR, flat, AI, and multiplayer before editing. If the spec leaves one unchanged, do not touch that path.

- **Flat** aims with the camera ray (`player/flat_rig.gd`). **VR** uses the controllers (`player/vr_rig.gd`). **AI** passes its own aim. A VR-only feel (aim steady, jam-free) stays off the other two.
- Fire, cock, and reload require `held`. `drawn` stays true while the gun is in the air.
- Hits apply only in `DRAW`. Head kills; a surviving arm hit tosses the gun; a leg hit slows. Gun-hand self-hit grace skips only that arm. AI bullets still exclude the shooter.
- Multiplayer is **1v1 and host-authoritative**. Do not pause the tree in MP. Visuals the peer must see go on the pose stream. LAN is every SKU. Steam is desktop only. The Quest APK is LAN-only.
- Slow-mo is single-player. The kill-cam burst is the multiplayer exception.
- Practice has no `DuelManager` and no HP.
- Do not swap AI or remote-avatar meshes, and do not add `SoftBody3D` cloth, unless the user asks.

## Roadmap

`Roadmap.md` is ordered cheapest → costliest. **Ideas is not the queue.** Do not implement from it, and do not add to it unless asked. A "maybe" in a bullet stays uncoded until the user picks.

- **Low:** the named file only. Do not explore the repo.
- **Moderate:** the writeup is the plan. Edit the files it names.
- **High / Very high:** list the files and what must stay put, and ask the design questions, before editing. Hitboxes-follow-mesh comes before ragdoll; ragdoll comes before dismemberment.

## After the edit

Update `docs/FEATURES.md`. Move a finished roadmap bullet to **Completed**. Add a `CHANGELOG.md` line under `[Unreleased]` when a player would notice. Then run the headless suite that covers the change:

```powershell
godot --headless --path . -- --autotest=duel
```

Suites: `duel`, `gauntlet`, `load`, `props`, `practice`, `host`, `join`, `steam`, `steamcycle`. Start `host` before `join`.
