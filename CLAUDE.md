# Gunslinger VR

Godot 4.6+ / 4.7 GDScript duel game: Quest 3, PCVR, and a flat harness (`--flat` or no OpenXR runtime).

Standing workflows live in `.claude/rules/` and load every session. Follow them. Gameplay changes also load `.claude/skills/gunslinger-gameplay/`. Do not invent features that are not in code.

## Docs

- Status: `docs/FEATURES.md`
- Systems: `docs/ARCHITECTURE.md`
- Bugs: `docs/BUGS.md` (`BUG-NNN`; shots in `docs/bugs/`)
- Ship checklist: `docs/RELEASE_TODOS.md`
- Future work: `Roadmap.md` (easiest → hardest). **Ideas** is not the build queue.
- History: `CHANGELOG.md` · version string: `VERSION` (mirrored in `project.godot` → `application/config/version`)
- Design / lore: `docs/design/README.md`

## Run

Headless smoke tests (`dev/autotest.gd`). Each prints `AUTOTEST PASS` or `AUTOTEST FAIL` and sets the process exit code.

`godot` is not on `PATH`. The editor lives in `C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\` (the folder name includes `.exe`). Use the console binary inside it:

```powershell
& "C:\Users\lukeg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path . -- --autotest=duel
```

Suites: `duel`, `gauntlet`, `multi`, `horde`, `load`, `props`, `practice`, `ragdoll`, `chunks`, `i18n`, `host`, `join`, `steam`, `steamcycle`. For multiplayer, start `host` before `join`.

Blender mesh work uses the `blender` MCP server (`.mcp.json` → addon socket `localhost:9876`). The workflow loads with `assets/models/**`.
