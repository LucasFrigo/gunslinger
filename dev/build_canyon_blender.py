"""Build the Canyon at Dusk greybox inside Blender (headless).

True metric scale, Z-up, 1 BU = 1 m. Export is glTF Y-up, so Blender
(x, y, z) becomes Godot (x, z, -y):

- Blender -Y is the player end (Godot +Z, PlayerSpawn at y = -11)
- Blender +Y is the enemy end (Godot -Z, EnemySpawn at y = 11)

The shot lane (|x| < 1.6, |y| < 12, chest-to-head height) stays free of
collision, and so does a pad around each spawn. Cliffs are stepped segments
whose inner face wanders along Y. Past each spawn the mesa top ends and the
ground falls away; an invisible rim keeps you on the rock. Floor top is z = 0.

Collision proxies use the ``-convcolonly`` Godot import suffix. Names must
stay unique so Blender does not append ``.001`` and break the suffix.

Run:
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/build_canyon_blender.py
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
OUT_DIR = os.path.join(ROOT, "assets", "models", "scenarios", "canyon")
OUT_BLEND = os.path.join(OUT_DIR, "canyon.blend")

# Shot corridor (Blender). Anything overlapping this band is a build error.
LANE = (-1.6, 1.6, -12.0, 12.0, 0.9, 1.9)
# Standing room at each spawn, from the ankles up.
PADS = (
    (-1.5, 1.5, -12.5, -9.5, 0.05, 2.2),
    (-1.5, 1.5, 9.5, 12.5, 0.05, 2.2),
)

COL_SAND = (0.70, 0.50, 0.32, 1.0)
COL_ROCK = (0.60, 0.32, 0.20, 1.0)
COL_ROCK_DARK = (0.45, 0.24, 0.16, 1.0)
COL_CAP = (0.72, 0.52, 0.34, 1.0)
COL_CAP_DARK = (0.55, 0.36, 0.22, 1.0)


def make_mats() -> dict:
    return {
        "sand": mat("M_Sand", COL_SAND, 0.95),
        "rock": mat("M_Rock", COL_ROCK, 0.96),
        "rock_dark": mat("M_RockDark", COL_ROCK_DARK, 0.98),
        "cap": mat("M_Cap", COL_CAP, 0.94),
        "cap_dark": mat("M_CapDark", COL_CAP_DARK, 0.96),
        "sand_far": mat("M_SandFar", (0.55, 0.38, 0.24, 1.0), 0.98),
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
    x0, x1 = loc[0] - hx, loc[0] + hx
    y0, y1 = loc[1] - hy, loc[1] + hy
    z0, z1 = loc[2] - hz, loc[2] + hz
    bx0, bx1, by0, by1, bz0, bz1 = bounds
    if x1 <= bx0 or x0 >= bx1:
        return False
    if y1 <= by0 or y0 >= by1:
        return False
    if z1 <= bz0 or z0 >= bz1:
        return False
    return True


def col(name, loc, size, parent):
    if _aabb_hits(loc, size, LANE):
        raise RuntimeError(f"collider {name} blocks the shot lane at {loc} size {size}")
    for pad in PADS:
        if _aabb_hits(loc, size, pad):
            raise RuntimeError(f"collider {name} blocks a spawn pad at {loc} size {size}")
    return convcol(name, loc, size, parent)


def solid(name, loc, size, parent, material):
    """Visible box plus a matching collision proxy."""
    put(name, loc, size, parent, material)
    col(name, loc, size, parent)


def _collect_meshes(root):
    out = []
    stack = [root]
    while stack:
        obj = stack.pop()
        if obj.type == "MESH":
            out.append(obj)
        stack.extend(list(obj.children))
    return out


# Mesa top. Narrower than the old shelf so the rim is close behind each spawn.
FLOOR_HALF_X = 16.0
FLOOR_HALF_Y = 14.6
# Desert under the butte. The cliff is vertical down to this height.
DESERT_Z = -24.0
# Segment centers. Half-length below; neighbors overlap, fronts stay apart.
SEG_YS = (-10.6, -7.4, -4.2, -1.0, 2.2, 5.4, 8.6, 11.4)
SEG_HALF_Y = 2.2

# Cover footprints (x0, x1, y0, y1), matching build_cover.
COVERS = (
    (-4.85, -2.75, -7.05, -5.35),
    (3.10, 4.95, -1.55, 0.35),
    (-5.20, -3.20, 5.60, 7.20),
    (2.80, 4.40, 2.25, 3.75),
    (3.65, 5.35, -9.40, -7.80),
    (-4.05, -2.55, 0.25, 1.75),
)


def _toe(y, side):
    """Inner face before cover clearance. Positive side is east."""
    flare = max(0.0, abs(y) - 10.5) * 1.05
    if side < 0:
        wave = 1.65 * math.sin(y * 0.38) + 0.9 * math.sin(y * 0.16 + 1.3)
        return -6.5 + wave - flare
    wave = 1.45 * math.sin(y * 0.31 + 0.7) + 0.95 * math.sin(y * 0.13 + 2.1)
    return 6.2 + wave + flare


def _push_out(x, y, side, half_y):
    """Keep a segment face off the cover rocks and out of the lane margin."""
    y0, y1 = y - half_y, y + half_y
    margin = 0.6
    for cx0, cx1, cy0, cy1 in COVERS:
        if y1 <= cy0 or y0 >= cy1:
            continue
        if side < 0:
            x = min(x, cx0 - margin)
        else:
            x = max(x, cx1 + margin)
    if side < 0:
        return min(x, -3.8)
    return max(x, 3.8)


def _overlaps_cover(loc, size) -> bool:
    hx, hy = size[0] * 0.5, size[1] * 0.5
    x0, x1 = loc[0] - hx, loc[0] + hx
    y0, y1 = loc[1] - hy, loc[1] + hy
    for cx0, cx1, cy0, cy1 in COVERS:
        if x1 <= cx0 or x0 >= cx1 or y1 <= cy0 or y0 >= cy1:
            continue
        return True
    return False


def build_floor(root, mats):
    # Top at z = 0. Ends at the mesa rim; the drop is past this.
    put(
        "Floor",
        (0.0, 0.0, -0.12),
        (FLOOR_HALF_X * 2.0, FLOOR_HALF_Y * 2.0, 0.24),
        root,
        mats["sand"],
    )
    col(
        "Floor",
        (0.0, 0.0, -0.5),
        (FLOOR_HALF_X * 2.0, FLOOR_HALF_Y * 2.0, 1.0),
        root,
    )


def _segment(root, mats, side, index, y, toe, prev_toe):
    """One bend of cliff. ``toe`` is the inner face; mass extends outward."""
    tag = "West" if side < 0 else "East"
    rock = mats["rock"] if side < 0 else mats["rock_dark"]
    cap_mat = mats["cap"] if side < 0 else mats["cap_dark"]
    if prev_toe is not None and abs(toe - prev_toe) < 0.6:
        # Step outward so neighboring fronts are not the same plane.
        toe = prev_toe + 0.65 * side
        toe = _push_out(toe, y, side, SEG_HALF_Y)

    talus_h = 2.15 + 0.35 * math.sin(y * 0.5 + index)
    talus_d = 2.5
    # ``side`` points outward: west mass grows toward -X, east toward +X.
    talus_c = toe + side * talus_d * 0.5
    solid(
        f"{tag}Talus{index}",
        (talus_c, y, talus_h * 0.5 - 0.2),
        (talus_d, SEG_HALF_Y * 2.0, talus_h),
        root,
        rock,
    )

    # Wall face sits behind the talus toe so the two fronts never meet.
    wall_h = 12.4 + 2.4 * math.sin(y * 0.23 + index * 0.8)
    wall_d = 9.0
    wall_toe = toe + side * 0.85
    wall_c = wall_toe + side * wall_d * 0.5
    wall_bot = (talus_h - 0.2) - 0.55
    solid(
        f"{tag}Wall{index}",
        (wall_c, y + 0.15 * side, wall_bot + wall_h * 0.5),
        (wall_d, SEG_HALF_Y * 2.0 - 0.35, wall_h),
        root,
        rock,
    )

    if index % 2 == 0:
        cap_h = 1.8 + (index % 3) * 0.45
        cap_d = 4.6
        cap_toe = wall_toe + side * 0.55
        cap_c = cap_toe + side * cap_d * 0.5
        cap_bot = wall_bot + wall_h - 0.35
        solid(
            f"{tag}Cap{index}",
            (cap_c, y - 0.4, cap_bot + cap_h * 0.5),
            (cap_d, 3.2, cap_h),
            root,
            cap_mat,
        )

    # A tooth proud of this bend, skipped when it would meet a cover rock.
    if index % 3 == 1:
        tooth_d = 1.35
        inner = toe - side * 1.2
        if abs(inner) >= 3.5:
            tooth_c = inner + side * tooth_d * 0.5
            tooth_loc = (tooth_c, y + 0.7, 2.3)
            tooth_size = (tooth_d, 1.7, 4.8)
            if not _overlaps_cover(tooth_loc, tooth_size):
                other = mats["rock_dark"] if side < 0 else mats["rock"]
                solid(f"{tag}Tooth{index}", tooth_loc, tooth_size, root, other)

    rubble_c = toe - side * 0.45
    rubble_loc = (rubble_c, y - 0.8, 0.16)
    rubble_size = (0.55, 0.4, 0.42)
    if abs(rubble_c) > 4.0 and not _overlaps_cover(rubble_loc, rubble_size):
        solid(f"{tag}Rubble{index}", rubble_loc, rubble_size, root, cap_mat)
    return toe


def build_cliffs(root, mats):
    """Winding walls. A buried backdrop fills gaps the steps leave behind."""
    for side, name, mat_key, back_x in (
        (-1, "West", "rock", -12.2),
        (1, "East", "rock_dark", 12.0),
    ):
        # ``back_x`` is the inner face. The mass continues outward from there.
        depth = 8.0
        center = back_x + side * depth * 0.5
        solid(
            f"{name}Back",
            (center, 0.2, 6.5),
            (depth, 24.0, 14.0),
            root,
            mats[mat_key],
        )
        prev = None
        for index, y in enumerate(SEG_YS):
            toe = _push_out(_toe(y, side), y, side, SEG_HALF_Y)
            prev = _segment(root, mats, side, index, y, toe, prev)


def build_ends(root, mats):
    """Sheer rim around the butte, then a desert that runs to the horizon."""
    span_x = FLOOR_HALF_X * 2.0 + 4.0
    span_y = FLOOR_HALF_Y * 2.0 + 4.0
    thick = 2.4
    # Top stays under the floor so the rim is an edge, not a ledge or a slope.
    cliff_top = -0.15
    cliff_bot = DESERT_Z - 0.35
    cliff_h = cliff_top - cliff_bot
    cliff_z = (cliff_top + cliff_bot) * 0.5
    # Near face sits just under the floor lip. The mass falls straight down.
    for name, sign in (("South", -1.0), ("North", 1.0)):
        face = sign * (FLOOR_HALF_Y - 0.08)
        solid(
            f"{name}Face",
            (0.0, face + sign * thick * 0.5, cliff_z),
            (span_x, thick, cliff_h),
            root,
            mats["rock"] if sign < 0 else mats["rock_dark"],
        )
        col(
            f"Rim{name}",
            (0.0, sign * (FLOOR_HALF_Y - 0.45), 1.05),
            (span_x, 0.45, 2.1),
            root,
        )
    for name, sign in (("West", -1.0), ("East", 1.0)):
        face = sign * (FLOOR_HALF_X - 0.08)
        solid(
            f"{name}Face",
            (face + sign * thick * 0.5, 0.0, cliff_z),
            (thick, span_y, cliff_h),
            root,
            mats["rock_dark"] if sign < 0 else mats["rock"],
        )
        col(
            f"Rim{name}",
            (sign * (FLOOR_HALF_X - 0.45), 0.0, 1.05),
            (0.45, span_y, 2.1),
            root,
        )
    _lip(root, mats, "South", -1.0)
    _lip(root, mats, "North", 1.0)
    build_horizon(root, mats)


def _lip(root, mats, tag, sign):
    """Broken stones along the rim, on the mesa, not a wall across the view."""
    stones = (
        (-6.5, 0.7, 0.9, 0.55),
        (-2.2, 0.45, 0.6, 0.4),
        (3.4, 0.6, 0.8, 0.5),
        (7.2, 0.4, 0.55, 0.35),
    )
    y = sign * (FLOOR_HALF_Y - 1.3)
    for i, (x, h, sx, sy) in enumerate(stones):
        key = "rock" if i % 2 == 0 else "rock_dark"
        solid(
            f"{tag}Lip{i}",
            (x, y + sign * (i % 2) * 0.3, h * 0.5 - 0.02),
            (sx, sy, h),
            root,
            mats[key],
        )


def build_horizon(root, mats):
    """Visual only. The plain is large enough that its edge sits in the fog."""
    # Half-extent is 3 km. The canyon fog is opaque well before that, so the
    # border never draws as a horizon line.
    put("Desert", (0.0, 0.0, DESERT_Z - 0.4), (6000.0, 6000.0, 0.8), root, mats["sand_far"])
    # (x, y, width, depth, height) — height rises off the desert.
    mesas = (
        (78.0, -96.0, 34.0, 18.0, 38.0),
        (-96.0, -130.0, 22.0, 40.0, 52.0),
        (48.0, 150.0, 46.0, 16.0, 32.0),
        (-150.0, 70.0, 18.0, 28.0, 58.0),
        (180.0, 24.0, 40.0, 22.0, 44.0),
        (-36.0, 210.0, 54.0, 20.0, 28.0),
        (120.0, -190.0, 26.0, 26.0, 64.0),
        (-190.0, -36.0, 32.0, 14.0, 36.0),
    )
    for i, (x, y, w, d, h) in enumerate(mesas):
        put(
            f"Mesa{i}",
            (x, y, DESERT_Z + h * 0.5),
            (w, d, h),
            root,
            mats["rock"] if i % 2 == 0 else mats["rock_dark"],
        )
        cap_h = 2.2 + (i % 3) * 0.6
        put(
            f"Mesa{i}Cap",
            (x, y - 1.5, DESERT_Z + h + cap_h * 0.35),
            (w * 0.72, d * 0.62, cap_h),
            root,
            mats["cap"] if i % 2 == 0 else mats["cap_dark"],
        )
    _scatter(root, mats)


def _scatter(root, mats):
    """Cacti and scrub on the desert, outside the butte. Same kinds as Main Street."""
    rng = random.Random(1902)
    keep = FLOOR_HALF_X + 8.0
    keep_y = FLOOR_HALF_Y + 8.0
    placed = 0
    attempts = 0
    while placed < 110 and attempts < 4000:
        attempts += 1
        rad = math.sqrt(rng.uniform(0.04, 1.0)) * 300.0
        ang = rng.uniform(0.0, math.tau)
        x = math.cos(ang) * rad
        y = math.sin(ang) * rad
        if abs(x) < keep and abs(y) < keep_y:
            continue
        plant = empty(f"Plant{placed:03d}", root)
        plant.location = Vector((x, y, DESERT_Z - 0.05))
        plant.rotation_euler = (0.0, 0.0, rng.uniform(0.0, math.tau))
        scale = rng.uniform(0.8, 1.4)
        plant.scale = Vector((scale, scale, scale))
        _pick_plant(rng)(plant, mats, rng, f"P{placed:03d}")
        placed += 1
    print(f"scatter: placed {placed} plants")


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
    z = 0.1
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


def build_cover(root, mats):
    """Rocks off the centerline. A chip sits on each mass, inside its footprint."""
    rocks = (
        # name, x, y, sx, sy, h, material
        ("CoverWPlayer", -3.8, -6.2, 2.0, 1.6, 1.50, "rock_dark"),
        ("CoverEMid", 4.0, -0.6, 1.7, 1.8, 1.65, "rock"),
        ("CoverWEnemy", -4.2, 6.4, 1.9, 1.5, 1.40, "rock"),
        ("CoverEEnemy", 3.6, 3.0, 1.5, 1.4, 1.20, "rock_dark"),
        ("CoverEPlayer", 4.5, -8.6, 1.6, 1.5, 1.55, "rock_dark"),
        ("CoverWMid", -3.3, 1.0, 1.4, 1.4, 1.15, "rock"),
    )
    for name, x, y, sx, sy, h, key in rocks:
        bury = 0.05
        put(name, (x, y, h * 0.5 - bury), (sx, sy, h), root, mats[key])
        chip_h = 0.32
        chip_s = (sx * 0.55, sy * 0.5, chip_h)
        # Stay inside the main footprint so one proxy covers both.
        chip_xy = (sx * 0.12, sy * 0.1)
        top = h - bury
        put(
            f"{name}Chip",
            (x + chip_xy[0], y - chip_xy[1], top + chip_h * 0.5 - 0.06),
            chip_s,
            root,
            mats["cap"] if key == "rock" else mats["rock"],
        )
        full_h = h + chip_h - 0.06
        col(name, (x, y, full_h * 0.5 - bury), (sx, sy, full_h), root)


def build_canyon(mats):
    root = empty("canyon")
    build_floor(root, mats)
    build_cliffs(root, mats)
    build_ends(root, mats)
    build_cover(root, mats)
    return root


def select_hierarchy(root):
    bpy.ops.object.select_all(action="DESELECT")

    def _sel(obj):
        obj.select_set(True)
        for child in obj.children:
            _sel(child)

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
        bg.inputs["Color"].default_value = (0.45, 0.28, 0.22, 1.0)
        bg.inputs["Strength"].default_value = 0.6


def _assert_names(root):
    seen = set()
    for mesh in _collect_meshes(root):
        if "." in mesh.name:
            raise RuntimeError(f"object name {mesh.name} would break the Godot suffix")
        if mesh.name in seen:
            raise RuntimeError(f"duplicate object name {mesh.name}")
        seen.add(mesh.name)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    clear_scene()
    setup_world()
    mats = make_mats()
    root = build_canyon(mats)
    _assert_names(root)
    purge_unused()
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print(f"saved {OUT_BLEND}")

    glb = os.path.join(OUT_DIR, "canyon.glb")
    export_glb(root, glb)
    print(f"exported {glb}")

    total = 0
    proxies = 0
    for mesh in _collect_meshes(root):
        if "-convcolonly" in mesh.name:
            proxies += 1
        else:
            total += count_tris(mesh)
    print(f"BUILD_OK visible_tris≈{total} proxies={proxies}")


main()
