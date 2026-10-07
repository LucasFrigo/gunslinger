# Project documentation (mandatory)

Agents must keep these files accurate when shipping meaningful work. Do not invent features that are not in code.

## Canonical files

| File | Purpose |
|---|---|
| `docs/FEATURES.md` | What exists / in progress / planned; status + key paths |
| `docs/ARCHITECTURE.md` | How major systems work and where they live |
| `docs/BUGS.md` | Open / fixed defect tracker (`BUG-NNN`); screenshots in `docs/bugs/` |
| `docs/RELEASE_TODOS.md` | Pre-release TODOs and attention points (store cert, SKU split, test matrix, “do not ship until…”) |
| `Roadmap.md` | Future work, ordered easiest → hardest |
| `CHANGELOG.md` | User-facing history ([Keep a Changelog](https://keepachangelog.com)) |
| `VERSION` | Current SemVer string (single line, e.g. `0.1.0-alpha`) |

Also sync `project.godot` → `application/config/version` with `VERSION`.

## When to update (same PR / session as the code)

- **New or changed behavior** → `docs/FEATURES.md` status + one-line note; touch `docs/ARCHITECTURE.md` if control flow, ownership, or key files moved.
- **New or changed player-facing / shippable feature** → add or revise items in `docs/RELEASE_TODOS.md` (store cert, SKU split, test matrix, known polish, “do not ship until…”). Check off or remove a line only when it is actually done in code.
- **Finished a Roadmap item** → move the bullet to **Completed** at the bottom of `Roadmap.md` (do not leave strikethrough in the active lists) and set `FEATURES.md` to `done`. **Started but not done** → annotate in place and set `FEATURES.md` to `partial`.
- **Ideas** on `Roadmap.md` is a parking lot for concepts that are not ready to build. Add or move an item there only when the user asks. Do not implement from that list, and do not treat it as the active queue.
- **Player-visible or shippable change** → add a `CHANGELOG.md` entry under `[Unreleased]`.
- **New confirmed bug** → add `BUG-NNN` under Open in `docs/BUGS.md`. **Fixing a tracked bug** → move it to Fixed in the same session; changelog `Fixed` if player-visible.
- **Code landing on `main`** → bump `VERSION` + `config/version` in that commit (see `.claude/rules/version-bump.md`). Do not wait for the user to ask.
- **Named release** (only when the user asks to release) → move `[Unreleased]` into a dated `## [X.Y.Z]` section; drop `-alpha` only if they asked.

Skip doc churn for typos, formatting-only edits, or purely internal renames with no behavior change.

Keep this file in step with `.cursor/rules/project-docs.mdc` when the workflow changes.

## Changelog & SemVer

- Categories: `Added`, `Changed`, `Fixed`, `Removed`, `Deprecated`.
- **MAJOR**: breaking gameplay/API/net protocol. **MINOR**: new feature. **PATCH**: fixes/polish.
- Pre-1.0: breaking changes may bump MINOR; still document them under `Changed` / `Removed`.

## Style

- Prefer short bullets and real paths (`gauntlet/duel_manager.gd`) over essays.
- Status vocabulary in `FEATURES.md`: `done` | `partial` | `planned` | `blocked`.
- If unsure whether something is implemented, grep/read code before writing docs.
