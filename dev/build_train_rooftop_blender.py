"""Build the Train Rooftop greybox inside Blender (headless).

True metric scale, Z-up, 1 BU = 1 m. Export is glTF Y-up, so Blender
(x, y, z) becomes Godot (x, z, -y). Roof tops stay at Godot y = 3.2 so
the spawns at z = ±10 still stand on them. Car centers are Godot z = ±6.6,
which leaves about 1.2 m between the bodies.

Horizon spans are 48 m along Blender Y (Godot Z) and centered on the
origin. ``scenarios/train_rooftop/scenery_belt.gd`` HORIZON_SPAN must
stay 48.

Collision proxies use the ``-convcolonly`` Godot import suffix. Invisible
walls ring the roofs (the shot lane along the cars stays open) and a thin
walk proxy covers the coupler gap. The horizon has no collision. Cliff
boxes do not share faces — overlapping coplanar fronts were z-fighting.

Run:
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/build_train_rooftop_blender.py
"""
from __future__ import annotations

import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_kit import (  # noqa: E402
    assign,
    box,
    clear_scene,
    convcol,
    count_tris,
    cyl,
    empty,
    flat_shade,
    mat,
    purge_unused,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "models", "scenarios", "train_rooftop")
OUT_BLEND = os.path.join(OUT_DIR, "train_rooftop.blend")

# Must match scenery_belt.gd HORIZON_SPAN.
HORIZON_SPAN = 48.0

COL_CAR = (0.48, 0.16, 0.12, 1.0)
COL_CAR_DARK = (0.30, 0.12, 0.09, 1.0)
COL_ROOF = (0.22, 0.18, 0.16, 1.0)
COL_WINDOW = (0.10, 0.12, 0.14, 1.0)
COL_IRON = (0.26, 0.27, 0.29, 1.0)
COL_WOOD = (0.40, 0.28, 0.16, 1.0)
COL_ROCK = (0.62, 0.40, 0.26, 1.0)
COL_ROCK_DARK = (0.42, 0.26, 0.18, 1.0)
COL_CAP = (0.72, 0.52, 0.34, 1.0)


def make_mats() -> dict:
    return {
        "car": mat("M_Car", COL_CAR, 0.72, metallic=0.15),
        "car_dark": mat("M_CarDark", COL_CAR_DARK, 0.8),
        "roof": mat("M_Roof", COL_ROOF, 0.9),
        "window": mat("M_Window", COL_WINDOW, 0.25, metallic=0.35, spec=0.4),
        "iron": mat("M_Iron", COL_IRON, 0.5, metallic=0.55),
        "wood": mat("M_Wood", COL_WOOD, 0.95),
        "rock": mat("M_Rock", COL_ROCK, 0.95),
        "rock_dark": mat("M_RockDark", COL_ROCK_DARK, 0.98),
        "cap": mat("M_Cap", COL_CAP, 0.92),
    }


def shade(obj):
    flat_shade(obj)
    return obj


def _collect_meshes(root):
    out = []
    stack = [root]
    while stack:
        o = stack.pop()
        if o.type == "MESH":
            out.append(o)
        stack.extend(list(o.children))
    return out


def _paint(obj, material):
    assign(obj, material)
    shade(obj)
    return obj


def build_truck(root, mats, name, y):
    """Two axles. Wheel radius 0.42 sits on a rail top near Godot y = 0.21."""
    frame = box(f"{name}_Frame", (0, y, 0.78), (1.7, 2.0, 0.28), root)
    _paint(frame, mats["iron"])
    bolster = box(f"{name}_Bolster", (0, y, 0.98), (0.7, 1.4, 0.18), root)
    _paint(bolster, mats["iron"])
    for i, axle_y in enumerate((y - 0.72, y + 0.72)):
        axle = cyl(
            f"{name}_Axle{i}",
            (-0.78, axle_y, 0.63),
            (0.78, axle_y, 0.63),
            0.06, 0.06, 6, root,
        )
        _paint(axle, mats["iron"])
        for side, x in (("L", -1), ("R", 1)):
            wheel = cyl(
                f"{name}_Wheel{i}{side}",
                (x * 0.62, axle_y, 0.63),
                (x * 0.82, axle_y, 0.63),
                0.42, 0.42, 8, root,
            )
            _paint(wheel, mats["iron"])


def build_ladder(root, mats, name, y):
    """End ladder, outside the body so it does not bridge the gap."""
    for side, x in (("L", -0.32), ("R", 0.32)):
        rail = cyl(
            f"{name}_Rail{side}",
            (x, y, 1.25),
            (x, y, 3.05),
            0.035, 0.035, 5, root,
        )
        _paint(rail, mats["iron"])
    for i, z in enumerate((1.55, 2.05, 2.55)):
        rung = box(f"{name}_Rung{i}", (0, y, z), (0.64, 0.05, 0.04), root)
        _paint(rung, mats["iron"])


def build_car(parent, mats, name, godot_z, outer_sign):
    """One passenger car. ``outer_sign`` is the local-Y sign of the end away from the gap."""
    root = empty(name, parent)
    # Godot z = -Blender y.
    root.location = Vector((0.0, -godot_z, 0.0))

    body = box(f"{name}_Body", (0, 0, 2.08), (2.9, 12.0, 1.86), root)
    _paint(body, mats["car"])
    # Unique convcol names — Blender's .001 suffix would break the Godot importer.
    convcol(f"{name}Body", (0, 0, 2.08), (2.9, 12.0, 1.86), root)

    band = box(f"{name}_Band", (0, 0, 2.55), (2.98, 12.0, 0.12), root)
    _paint(band, mats["car_dark"])

    under = box(f"{name}_Under", (0, 0, 1.12), (2.3, 11.0, 0.22), root)
    _paint(under, mats["wood"])

    roof = box(f"{name}_Roof", (0, 0, 3.11), (3.2, 12.3, 0.18), root)
    _paint(roof, mats["roof"])
    # Top face at z = 3.2 so the existing spawn markers sit on the roof.
    convcol(f"{name}Roof", (0, 0, 3.1), (3.05, 11.6, 0.2), root)

    for side, x in (("L", -1.52), ("R", 1.52)):
        lip = box(f"{name}_Lip{side}", (x, 0, 3.26), (0.08, 12.0, 0.12), root)
        _paint(lip, mats["roof"])

    for end_name, y in (("A", -5.85), ("B", 5.85)):
        bulk = box(f"{name}_Bulk{end_name}", (0, y, 2.15), (2.7, 0.16, 1.7), root)
        _paint(bulk, mats["car_dark"])

    # Side windows. Off the shot lane (the lane runs along Y at x = 0).
    for side, x in (("L", -1.48), ("R", 1.48)):
        for i, y in enumerate((-4.4, -2.7, -1.0, 1.0, 2.7, 4.4)):
            win = box(f"{name}_Win{side}{i}", (x, y, 2.15), (0.06, 0.72, 0.95), root)
            _paint(win, mats["window"])
            sill = box(f"{name}_Sill{side}{i}", (x, y, 1.62), (0.08, 0.86, 0.08), root)
            _paint(sill, mats["wood"])

    build_truck(root, mats, f"{name}T0", -3.7)
    build_truck(root, mats, f"{name}T1", 3.7)
    build_ladder(root, mats, f"{name}Ladder", outer_sign * 6.08)
    return root


def build_coupler(root, mats):
    """Short link in the ~1.2 m gap. Visual only; the walk proxy is separate."""
    draw = box("Coupler_Draw", (0, 0, 0.82), (0.22, 0.85, 0.16), root)
    _paint(draw, mats["iron"])
    for name, y in (("A", -0.4), ("B", 0.4)):
        head = box(f"Coupler_Head{name}", (0, y, 0.86), (0.42, 0.22, 0.32), root)
        _paint(head, mats["iron"])
    pin = cyl("Coupler_Pin", (0, 0, 0.68), (0, 0, 1.05), 0.06, 0.06, 6, root)
    _paint(pin, mats["iron"])


def build_guards(root):
    """Invisible walls around both roofs, plus a walk surface across the coupler.

    Side walls and the outer ends only. Nothing crosses the shot lane (x = 0
    between the duelists). Car bodies end near Blender y = ±0.6; roofs run to
    about ±12.75.
    """
    wall_h = 2.2
    z = 3.2 + wall_h * 0.5
    half = 6.6 + 6.15
    for name, x in (("L", -1.78), ("R", 1.78)):
        convcol(f"GuardSide{name}", (x, 0.0, z), (0.28, half * 2.0 + 0.5, wall_h), root)
    for name, y in (("A", -(half + 0.22)), ("B", half + 0.22)):
        convcol(f"GuardEnd{name}", (0.0, y, z), (3.5, 0.28, wall_h), root)
    # Overlaps each roof by ~0.3 m so there is no crack to fall through.
    convcol("GapWalk", (0.0, 0.0, 3.1), (2.9, 1.8, 0.2), root)


def build_train(mats):
    root = empty("train_rooftop")
    # Player car is Godot +Z. Its outer end points further +Z, which is Blender -Y.
    build_car(root, mats, "CarA", 6.6, outer_sign=-1.0)
    build_car(root, mats, "CarB", -6.6, outer_sign=1.0)
    build_coupler(root, mats)
    build_guards(root)
    return root


# A hair shorter than the belt spacing so neighboring spans do not share a face.
_SPAN_LEN = HORIZON_SPAN - 0.25


def build_canyon(mats):
    """One wall, a skirt, and a buttress that sits in front of the face."""
    root = empty("Canyon")
    talus = box("Talus", (0, 0, 1.0), (18.0, _SPAN_LEN, 2.0), root)
    _paint(talus, mats["rock_dark"])
    # Bottom buried in the talus. Front face is inside the skirt's width.
    wall = box("Wall", (0, 0, 9.6), (8.0, _SPAN_LEN - 0.05, 16.2), root)
    _paint(wall, mats["rock"])
    # Clear of the wall front (x = 4) so the two faces never meet.
    butt = box("Buttress", (5.3, 5.5, 6.2), (1.8, 4.5, 8.4), root)
    _paint(butt, mats["rock_dark"])
    # Bottom buried in the wall top (z = 17.7). Sides inset from the wall front.
    cap = box("Cap", (0, -6.0, 18.6), (6.0, 12.0, 2.2), root)
    _paint(cap, mats["cap"])
    return root


def build_mesa(mats):
    """Two steps. The upper one is inset, so its front is not the lower front."""
    root = empty("Mesa")
    talus = box("Talus", (0, 0, 1.0), (20.0, _SPAN_LEN, 2.0), root)
    _paint(talus, mats["rock_dark"])
    lower = box("Lower", (0, 0, 6.4), (12.0, _SPAN_LEN - 0.05, 10.2), root)
    _paint(lower, mats["rock"])
    # Lower top is z = 11.5. Upper bottom at 11.1, front at x = 4 vs lower x = 6.
    upper = box("Upper", (0, -1.5, 13.6), (8.0, 26.0, 5.0), root)
    _paint(upper, mats["cap"])
    return root


def build_butte(mats):
    """Towers standing on a skirt. Caps overhang instead of sharing a side face."""
    root = empty("Butte")
    talus = box("Talus", (0, 0, 1.1), (18.0, _SPAN_LEN, 2.2), root)
    _paint(talus, mats["rock_dark"])
    towers = (
        ("A", -12.0, 30.0, 5.0, "rock"),
        ("B", 1.0, 38.0, 4.2, "cap"),
        ("C", 13.5, 20.0, 6.0, "rock"),
    )
    for name, y, height, thick, key in towers:
        # Base buried in the talus (top z = 2.2).
        base = 1.7
        tower = box(
            f"Tower{name}",
            (0, y, base + height * 0.5),
            (thick, thick * 0.85, height),
            root,
        )
        _paint(tower, mats[key])
        top = base + height
        lip = box(
            f"Lip{name}",
            (0, y, top + 0.35),
            (thick + 1.6, thick * 0.85 + 1.4, 1.3),
            root,
        )
        _paint(lip, mats["cap"] if key == "rock" else mats["rock"])
    return root


def build_horizon(mats):
    root = empty("horizon_ridge")
    parts = (build_canyon(mats), build_mesa(mats), build_butte(mats))
    for part in parts:
        part.parent = root
    return root


def select_hierarchy(root):
    bpy.ops.object.select_all(action="DESELECT")

    def _sel(o):
        o.select_set(True)
        for c in o.children:
            _sel(c)

    _sel(root)
    bpy.context.view_layer.objects.active = root


def export_glb(root, path):
    select_hierarchy(root)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        use_selection=True,
        export_apply=True,
    )


def setup_world():
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.55, 0.62, 0.72, 1.0)
        bg.inputs["Strength"].default_value = 0.7


def _visible_tris(root) -> int:
    total = 0
    for m in _collect_meshes(root):
        if "-convcolonly" not in m.name:
            total += count_tris(m)
    return total


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    clear_scene()
    setup_world()
    mats = make_mats()
    train = build_train(mats)
    horizon = build_horizon(mats)
    # Park the ridges beside the train so the .blend is browsable.
    for i, part in enumerate(list(horizon.children)):
        part.location = Vector((40.0, i * (HORIZON_SPAN + 8.0), 0.0))
    purge_unused()
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print(f"saved {OUT_BLEND}")

    for part in horizon.children:
        part.location = Vector((0.0, 0.0, 0.0))
    bpy.context.view_layer.update()

    train_glb = os.path.join(OUT_DIR, "train_rooftop.glb")
    export_glb(train, train_glb)
    print(f"exported {train_glb}")

    horizon_glb = os.path.join(OUT_DIR, "horizon_ridge.glb")
    export_glb(horizon, horizon_glb)
    print(f"exported {horizon_glb}")

    print(f"BUILD_OK train_tris≈{_visible_tris(train)} horizon_tris≈{_visible_tris(horizon)}")


main()
