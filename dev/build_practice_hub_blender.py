"""Build the Practice Hub greybox inside Blender (headless).

True metric scale, Z-up, 1 BU = 1 m. Export is glTF Y-up, so Blender
(x, y, z) becomes Godot (x, z, -y):

- Blender -Y is the porch (Godot +Z, PlayerSpawn at y = -4)
- Blender +Y is down the range (Godot -Z)

The player stands under a porch and faces three bottle rails at 6, 11, and
16 m. Each rail holds three bottles on the top board and one on a taller post.
A dirt berm behind the last rail catches misses, and a low fence keeps the
player in the lot. No duel lane, no EnemySpawn.

Empties carry positions for runtime spawns: ``BottleSpot*`` (bottle base) and
``SlotSpot`` (slot machine floor centre). ``scenarios/practice_hub`` reads them.

Collision proxies use the ``-convcolonly`` Godot import suffix. Names must
stay unique so Blender does not append ``.001`` and break the suffix.

Run:
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/build_practice_hub_blender.py
"""
from __future__ import annotations

import math
import os
import random
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
OUT_DIR = os.path.join(ROOT, "assets", "models", "scenarios", "practice_hub")
OUT_BLEND = os.path.join(OUT_DIR, "practice_hub.blend")

SPAWN_Y = -4.0
# Porch: 4 m wide, 3 m deep, ceiling underside at 2.6 m.
PORCH_HALF_X = 2.0
PORCH_Y0 = -5.5
PORCH_Y1 = -2.5
PORCH_CEIL = 2.6
# Rails at 6, 11, and 16 m from the spawn.
RAIL_DISTANCES = (6.0, 11.0, 16.0)
RAIL_TOP = 1.0
RAIL_HALF_X = 2.6
HIGH_POST_X = 3.2
HIGH_POST_TOP = 1.5
LOW_BOTTLE_XS = (-1.6, 0.0, 1.6)
# Lot fence.
LOT_HALF_X = 9.0
LOT_Y0 = -7.5
LOT_Y1 = 20.5
FENCE_H = 1.1
# Physics ground reaches past the fence so a thrown bottle lands somewhere.
GROUND_HALF = 40.0
# Standing room at the spawn, from the ankles up.
SPAWN_PAD = (-0.8, 0.8, SPAWN_Y - 0.8, SPAWN_Y + 0.8, 0.05, 2.2)

COL_SAND = (0.70, 0.52, 0.34, 1.0)
COL_WOOD = (0.42, 0.28, 0.17, 1.0)
COL_WOOD_DARK = (0.30, 0.20, 0.12, 1.0)
COL_ROOF = (0.36, 0.30, 0.26, 1.0)


def make_mats() -> dict:
    return {
        "sand": mat("M_Sand", COL_SAND, 0.95),
        "sand_far": mat("M_SandFar", (0.62, 0.45, 0.30, 1.0), 0.98),
        "dirt": mat("M_Dirt", (0.52, 0.36, 0.22, 1.0), 0.97),
        "wood": mat("M_Wood", COL_WOOD, 0.9),
        "wood_dark": mat("M_WoodDark", COL_WOOD_DARK, 0.92),
        "plank": mat("M_Plank", (0.50, 0.36, 0.22, 1.0), 0.9),
        "roof": mat("M_Roof", COL_ROOF, 0.85, 0.2),
        "hay": mat("M_Hay", (0.78, 0.64, 0.34, 1.0), 0.98),
        "rock": mat("M_Rock", (0.60, 0.36, 0.24, 1.0), 0.96),
        "rock_dark": mat("M_RockDark", (0.46, 0.27, 0.18, 1.0), 0.98),
        "cactus": mat("M_Cactus", (0.28, 0.48, 0.28, 1.0), 0.92),
        "cactus_dark": mat("M_CactusDark", (0.18, 0.34, 0.20, 1.0), 0.92),
        "scrub": mat("M_Scrub", (0.35, 0.40, 0.22, 1.0), 0.95),
        "scrub_dry": mat("M_ScrubDry", (0.45, 0.38, 0.22, 1.0), 0.95),
    }


def put(name, loc, size, parent, material):
    obj = box(name, loc, size, parent)
    assign(obj, material)
    flat_shade(obj)
    return obj


def _aabb_hits(loc, size, bounds) -> bool:
    hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
    bx0, bx1, by0, by1, bz0, bz1 = bounds
    if loc[0] + hx <= bx0 or loc[0] - hx >= bx1:
        return False
    if loc[1] + hy <= by0 or loc[1] - hy >= by1:
        return False
    if loc[2] + hz <= bz0 or loc[2] - hz >= bz1:
        return False
    return True


def col(name, loc, size, parent):
    if _aabb_hits(loc, size, SPAWN_PAD):
        raise RuntimeError(f"collider {name} blocks the spawn pad at {loc} size {size}")
    return convcol(name, loc, size, parent)


def solid(name, loc, size, parent, material):
    """Visible box plus a matching collision proxy."""
    put(name, loc, size, parent, material)
    col(name, loc, size, parent)


def post(name, x, y, top, parent, material, r=0.07):
    p = cyl(name, (x, y, 0.0), (x, y, top), r, r, 6, parent)
    assign(p, material)
    flat_shade(p)
    col(name, (x, y, top * 0.5), (r * 2.0, r * 2.0, top), parent)


def spot(name, loc, parent):
    e = empty(name, parent)
    e.location = Vector(loc)
    return e


def build_ground(root, mats):
    put("Lot", (0.0, 6.5, -0.1), (LOT_HALF_X * 2.0, LOT_Y1 - LOT_Y0, 0.2), root, mats["sand"])
    col("Ground", (0.0, 6.5, -0.5), (GROUND_HALF * 2.0, GROUND_HALF * 2.0, 1.0), root)
    # Horizon plain. Its edge sits deep in the fog. Top face is z = -0.12.
    put("Desert", (0.0, 0.0, -0.32), (6000.0, 6000.0, 0.4), root, mats["sand_far"])


def build_porch(root, mats):
    cy = (PORCH_Y0 + PORCH_Y1) * 0.5
    depth = PORCH_Y1 - PORCH_Y0
    width = PORCH_HALF_X * 2.0
    put("PorchDeck", (0.0, cy, 0.03), (width + 0.3, depth + 0.2, 0.06), root, mats["plank"])
    # Back wall with a false front above the roof.
    solid("PorchWall", (0.0, PORCH_Y0 - 0.12, 1.9), (width + 1.4, 0.24, 3.8), root, mats["wood_dark"])
    put("PorchSign", (0.0, PORCH_Y0 + 0.02, 3.25), (2.2, 0.06, 0.55), root, mats["plank"])
    for i, x in enumerate((-PORCH_HALF_X, PORCH_HALF_X)):
        post(f"PorchPostFront{i}", x, PORCH_Y1, PORCH_CEIL, root, mats["wood"], 0.08)
    roof_t = 0.12
    put(
        "PorchRoof",
        (0.0, cy + 0.15, PORCH_CEIL + roof_t * 0.5),
        (width + 0.6, depth + 0.7, roof_t),
        root,
        mats["roof"],
    )
    col("PorchRoof", (0.0, cy + 0.15, PORCH_CEIL + roof_t * 0.5), (width + 0.6, depth + 0.7, roof_t), root)
    put("PorchBeam", (0.0, PORCH_Y1, PORCH_CEIL - 0.08), (width + 0.3, 0.14, 0.16), root, mats["wood"])
    # Half wall on the right, clear of the slot machine on the left.
    solid("PorchRail", (PORCH_HALF_X + 0.05, cy, 0.5), (0.1, depth - 0.4, 1.0), root, mats["wood"])
    # Slot machine stands against the left side of the porch, facing +X.
    spot("SlotSpot", (-PORCH_HALF_X + 0.45, SPAWN_Y - 0.2, 0.06), root)


def build_rail(root, mats, index, distance):
    y = SPAWN_Y + distance
    tag = f"Rail{index}"
    for i, x in enumerate((-RAIL_HALF_X, 0.0, RAIL_HALF_X)):
        post(f"{tag}Post{i}", x, y + 0.08, RAIL_TOP - 0.05, root, mats["wood_dark"])
    board_t = 0.06
    solid(
        f"{tag}Board",
        (0.0, y, RAIL_TOP - board_t * 0.5),
        (RAIL_HALF_X * 2.0 + 0.3, 0.18, board_t),
        root,
        mats["wood"],
    )
    put(f"{tag}Lower", (0.0, y + 0.08, 0.45), (RAIL_HALF_X * 2.0 + 0.2, 0.06, 0.12), root, mats["wood_dark"])
    for i, x in enumerate(LOW_BOTTLE_XS):
        spot(f"BottleSpot{index}{i}", (x, y, RAIL_TOP + 0.002), root)
    # Tall post alternates sides so each rail reads differently.
    hx = HIGH_POST_X if index % 2 == 0 else -HIGH_POST_X
    post(f"{tag}HighPost", hx, y, HIGH_POST_TOP - 0.04, root, mats["wood_dark"], 0.08)
    solid(f"{tag}HighCap", (hx, y, HIGH_POST_TOP - 0.02), (0.26, 0.26, 0.04), root, mats["wood"])
    spot(f"BottleSpot{index}3", (hx, y, HIGH_POST_TOP + 0.002), root)


def build_berm(root, mats):
    y = SPAWN_Y + RAIL_DISTANCES[-1] + 3.0
    solid("Berm", (0.0, y, 1.2), (12.0, 2.4, 2.4), root, mats["dirt"])
    solid("BermCap", (0.0, y + 0.3, 2.6), (10.0, 1.6, 0.4), root, mats["dirt"])
    for i, x in enumerate((-5.2, 5.4)):
        solid(f"Hay{i}", (x, y - 1.8, 0.45), (1.2, 0.8, 0.9), root, mats["hay"])


def build_fence(root, mats):
    span_x = LOT_HALF_X * 2.0
    span_y = LOT_Y1 - LOT_Y0
    cy = (LOT_Y0 + LOT_Y1) * 0.5
    for name, x, y, sx, sy in (
        ("FenceBack", 0.0, LOT_Y0, span_x, 0.1),
        ("FenceFront", 0.0, LOT_Y1, span_x, 0.1),
        ("FenceWest", -LOT_HALF_X, cy, 0.1, span_y),
        ("FenceEast", LOT_HALF_X, cy, 0.1, span_y),
    ):
        for j, z in enumerate((0.45, FENCE_H - 0.1)):
            put(f"{name}Bar{j}", (x, y, z), (sx, sy, 0.1), root, mats["wood"])
        col(name, (x, y, FENCE_H * 0.5), (max(sx, 0.3), max(sy, 0.3), FENCE_H), root)
    n = 0
    for x in (-LOT_HALF_X, LOT_HALF_X):
        y = LOT_Y0
        while y <= LOT_Y1 + 0.01:
            p = cyl(f"FencePost{n}", (x, y, 0.0), (x, y, FENCE_H + 0.1), 0.06, 0.06, 5, root)
            assign(p, mats["wood_dark"])
            flat_shade(p)
            n += 1
            y += 3.5
    for y in (LOT_Y0, LOT_Y1):
        x = -LOT_HALF_X + 3.0
        while x < LOT_HALF_X - 0.5:
            p = cyl(f"FencePost{n}", (x, y, 0.0), (x, y, FENCE_H + 0.1), 0.06, 0.06, 5, root)
            assign(p, mats["wood_dark"])
            flat_shade(p)
            n += 1
            x += 3.0


def build_props(root, mats):
    solid("CrateA", (-6.5, 1.0, 0.4), (0.8, 0.8, 0.8), root, mats["wood"])
    solid("CrateB", (-6.1, 1.9, 0.3), (0.6, 0.6, 0.6), root, mats["wood_dark"])
    solid("BarrelA", (6.3, -1.5, 0.45), (0.6, 0.6, 0.9), root, mats["wood_dark"])
    solid("Trough", (6.0, 5.0, 0.3), (0.7, 2.0, 0.6), root, mats["wood"])


def _pick_plant(rng):
    roll = rng.random()
    if roll < 0.24:
        return _plant_saguaro
    if roll < 0.40:
        return _plant_barrel
    if roll < 0.56:
        return _plant_organ
    if roll < 0.74:
        return _plant_scrub
    return _plant_pads


def _plant_saguaro(parent, mats, rng, name):
    h = rng.uniform(2.2, 5.2)
    r = rng.uniform(0.22, 0.36)
    trunk = cyl(f"{name}Trunk", (0, 0, 0), (0, 0, h), r, r * 0.9, 6, parent)
    assign(trunk, mats["cactus"])
    flat_shade(trunk)
    if rng.random() < 0.65:
        side = 1.0 if rng.random() < 0.5 else -1.0
        arm = cyl(
            f"{name}Arm",
            (side * r, 0, h * 0.55),
            (side * (r + 0.7), 0, h * 0.75),
            r * 0.65, r * 0.5, 5, parent,
        )
        assign(arm, mats["cactus_dark"])
        flat_shade(arm)


def _plant_barrel(parent, mats, rng, name):
    h = rng.uniform(0.6, 1.4)
    r = rng.uniform(0.3, 0.55)
    body = cyl(f"{name}Body", (0, 0, 0), (0, 0, h), r, r * 0.82, 7, parent)
    assign(body, mats["cactus"])
    flat_shade(body)


def _plant_organ(parent, mats, rng, name):
    n = rng.randint(3, 5)
    for i in range(n):
        ang = (i / n) * math.tau
        rad = rng.uniform(0.12, 0.32)
        h = rng.uniform(1.4, 3.4)
        coln = cyl(
            f"{name}Col{i}",
            (math.cos(ang) * rad, math.sin(ang) * rad, 0),
            (math.cos(ang) * rad, math.sin(ang) * rad, h),
            0.1, 0.08, 5, parent,
        )
        assign(coln, mats["cactus"] if i % 2 == 0 else mats["cactus_dark"])
        flat_shade(coln)


def _plant_scrub(parent, mats, rng, name):
    for i in range(rng.randint(3, 5)):
        h = rng.uniform(0.3, 0.75)
        w = rng.uniform(0.25, 0.5)
        bush = box(
            f"{name}Clump{i}",
            (rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), h * 0.5),
            (w, w, h),
            parent,
        )
        assign(bush, mats["scrub"] if i % 2 == 0 else mats["scrub_dry"])
        flat_shade(bush)


def _plant_pads(parent, mats, rng, name):
    # First pad sits on the plant origin. Starting at 0.1 left a gap over the sand.
    z = 0.0
    for i in range(rng.randint(2, 4)):
        h = rng.uniform(0.4, 0.65)
        pad = box(
            f"{name}Pad{i}",
            (rng.uniform(-0.12, 0.12), rng.uniform(-0.08, 0.08), z + h * 0.5),
            (rng.uniform(0.35, 0.65), 0.1, h),
            parent,
        )
        assign(pad, mats["cactus"] if i % 2 == 0 else mats["cactus_dark"])
        flat_shade(pad)
        z += h * 0.7


def build_horizon(root, mats):
    """Visual only: mesas and cacti outside the fence."""
    mesas = (
        (70.0, 120.0, 36.0, 20.0, 30.0),
        (-110.0, 160.0, 28.0, 36.0, 44.0),
        (160.0, 20.0, 30.0, 22.0, 36.0),
        (-150.0, -40.0, 24.0, 28.0, 26.0),
        (20.0, 230.0, 60.0, 18.0, 22.0),
        (-40.0, -160.0, 40.0, 20.0, 30.0),
    )
    for i, (x, y, w, d, h) in enumerate(mesas):
        put(f"Mesa{i}", (x, y, h * 0.5 - 0.3), (w, d, h), root, mats["rock"] if i % 2 == 0 else mats["rock_dark"])
    rng = random.Random(1878)
    placed = 0
    while placed < 40:
        rad = rng.uniform(16.0, 120.0)
        ang = rng.uniform(0.0, math.tau)
        x, y = math.cos(ang) * rad, 6.5 + math.sin(ang) * rad
        if abs(x) < LOT_HALF_X + 3.0 and LOT_Y0 - 3.0 < y < LOT_Y1 + 3.0:
            continue
        plant = empty(f"Plant{placed:02d}", root)
        # Desert top is z = -0.12. Bury the origin 5 cm, same as Canyon.
        plant.location = Vector((x, y, -0.17))
        plant.rotation_euler = (0.0, 0.0, rng.uniform(0.0, math.tau))
        scale = rng.uniform(0.85, 1.35)
        plant.scale = Vector((scale, scale, scale))
        _pick_plant(rng)(plant, mats, rng, f"P{placed:02d}")
        placed += 1


def build_hub(mats):
    root = empty("practice_hub")
    build_ground(root, mats)
    build_porch(root, mats)
    for i, d in enumerate(RAIL_DISTANCES):
        build_rail(root, mats, i, d)
    build_berm(root, mats)
    build_fence(root, mats)
    build_props(root, mats)
    build_horizon(root, mats)
    return root


def _collect(root, kind=None):
    out = []
    stack = [root]
    while stack:
        obj = stack.pop()
        if kind is None or obj.type == kind:
            out.append(obj)
        stack.extend(list(obj.children))
    return out


def select_hierarchy(root):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in _collect(root):
        obj.select_set(True)
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
        bg.inputs["Strength"].default_value = 0.6


def _assert_names(root):
    seen = set()
    for obj in _collect(root):
        if "." in obj.name:
            raise RuntimeError(f"object name {obj.name} would break the Godot suffix")
        if obj.name in seen:
            raise RuntimeError(f"duplicate object name {obj.name}")
        seen.add(obj.name)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    clear_scene()
    setup_world()
    mats = make_mats()
    root = build_hub(mats)
    _assert_names(root)
    purge_unused()
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print(f"saved {OUT_BLEND}")

    glb = os.path.join(OUT_DIR, "practice_hub.glb")
    export_glb(root, glb)
    print(f"exported {glb}")

    total = 0
    proxies = 0
    for mesh in _collect(root, "MESH"):
        if "-convcolonly" in mesh.name:
            proxies += 1
        else:
            total += count_tris(mesh)
    spots = [o.name for o in _collect(root, "EMPTY") if o.name.startswith("BottleSpot")]
    print(f"BUILD_OK visible_tris≈{total} proxies={proxies} bottle_spots={len(spots)}")


main()
