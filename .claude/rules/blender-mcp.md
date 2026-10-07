---
paths:
  - "assets/models/**/*"
---

# Blender MCP

The MCP client talks stdio to `uvx blender-mcp`. That process connects to the **Blender addon TCP socket** on `localhost:9876`. Port 9876 is not an HTTP MCP URL.

- Cursor: `.cursor/mcp.json`
- Claude Code: `.mcp.json`

Keep this file in step with `.cursor/rules/blender-mcp.mdc` when the workflow changes.

## Before modeling

- Blender must have **Interface: Blender MCP** enabled.
- In the 3D Viewport: `N` → **BlenderMCP** → **Start MCP Server** / Connect.
- Only one MCP client should own that socket.
- If tools fail with `spawn uvx ENOENT`, set `command` in `.mcp.json` to the full `uvx.exe` path (`where uvx`).

## Assets

- Source `.blend` + Godot `.glb` live under `assets/models/` (characters: `assets/models/characters/`).
- Export glTF 2.0 for Godot (Y-up). Keep Cloth unapplied in the `.blend`; apply the draped pose for the `.glb`.
- Do not add live Godot `SoftBody3D` cloth unless the user asks.
- Do not swap greybox AI / remote-avatar meshes unless the user asks.
