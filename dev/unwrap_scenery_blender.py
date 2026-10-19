"""UV-unwrap the scenario `.blend` files onto the trim sheet and re-export their GLBs.

PAUSED: the game now uses a hand-painted image per GLB (`dev/unwrap_per_glb_blender.py`), and
those GLBs carry per-GLB UVs with `uv_lock`, which this script skips. Running it on an unlocked
object would put strip UVs back and export with no image, so only use it to revive the trim sheet.

Opens each scenario `.blend`, runs `scenery_uv.process_scene()`, saves it, and exports
every root empty to `<root name>.glb` beside it. An object whose name matches a photo cell
that has an image (`assets/texture_src/cells_manifest.json`, written by
`dev/build_trim_sheet.py`) is laid on that cell; the rest go on their strip. Objects with
the custom property `uv_lock` are skipped. See `docs/TEXTURING.md`.

Run:
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/unwrap_scenery_blender.py
    ... -- --map saloon            one map (main_street, saloon, train_rooftop, practice_hub, canyon)
    ... -- --dry                   unwrap and check in memory; save and export nothing
"""
from __future__ import annotations

import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_uv  # noqa: E402

SCENARIOS = os.path.join(scenery_uv.ROOT, "assets", "models", "scenarios")
MAPS = {
    "main_street": "main_street/main_street.blend",
    "saloon": "saloon/saloon.blend",
    "train_rooftop": "train_rooftop/train_rooftop.blend",
    "practice_hub": "practice_hub/practice_hub.blend",
    "canyon": "canyon/canyon.blend",
}
# Parked beside the train in the .blend so it is browsable; exported from the origin.
PARKED_CHILDREN = {"horizon_ridge"}


def _args() -> tuple[list[str], bool]:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    maps = []
    if "--map" in argv:
        maps = [argv[argv.index("--map") + 1]]
    return maps or list(MAPS), "--dry" in argv


def export_roots(directory: str) -> list[str]:
    exported = []
    roots = [o for o in bpy.data.objects if o.parent is None and o.type == "EMPTY"]
    for root in sorted(roots, key=lambda o: o.name):
        homes = {root: root.location.copy()}
        root.location = Vector((0.0, 0.0, 0.0))
        if root.name in PARKED_CHILDREN:
            for child in root.children:
                homes[child] = child.location.copy()
                child.location = Vector((0.0, 0.0, 0.0))
        bpy.context.view_layer.update()
        path = os.path.join(directory, root.name + ".glb")
        scenery_uv.export_glb(root, path)
        for obj, home in homes.items():
            obj.location = home
        bpy.context.view_layer.update()
        exported.append(path)
    return exported


def run(name: str, dry: bool) -> bool:
    blend = os.path.join(SCENARIOS, MAPS[name])
    bpy.ops.wm.open_mainfile(filepath=blend)
    stats = scenery_uv.process_scene()
    problems = scenery_uv.check_scene()
    print("UNWRAP %s: %d objects, %d on the sheet (%d on cells), %d tiling, %d skipped, "
          "%d locked, %d cuts, tris %d -> %d" % (
              name, stats["objects"], stats["unwrapped"], stats["cells"], stats["tiling"],
              stats["skipped"], stats["locked"], stats["cuts"], stats["tris_before"],
              stats["tris_after"]))
    for obj_name, why in stats["review"]:
        print("  REVIEW %s: %s" % (obj_name, why))
    for problem in problems:
        print("  PROBLEM %s" % problem)
    if problems:
        return False
    if not dry:
        bpy.ops.wm.save_mainfile()
        for path in export_roots(os.path.dirname(blend)):
            print("  exported %s" % path)
    return True


def main() -> None:
    maps, dry = _args()
    ok = True
    for name in maps:
        ok = run(name, dry) and ok
    print("UNWRAP_OK" if ok else "UNWRAP_FAILED")
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
