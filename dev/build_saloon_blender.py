"""Build the Saloon interior greybox inside Blender (headless).

True metric scale, Z-up, 1 BU = 1 m. Export is glTF Y-up, so Blender
(x, y, z) becomes Godot (x, z, -y):

- Blender -X is the west bar wall (Godot -X)
- Blender -Y is the street/player wall (Godot +Z, PlayerSpawn)
- Blender +Y is the north/enemy wall (Godot -Z, EnemySpawn)

The shot lane (|x| < 1.5, |y| < 6, chest-to-head height) stays free of
collision. Ceiling underside is 4.2 m so a standing VR player clears it.

Collision proxies use the ``-convcolonly`` Godot import suffix.

Run:
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/build_saloon_blender.py
"""
from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_kit import (  # noqa: E402
    assign,
    box,
    clear_scene,
    cone,
    convcol,
    convcol_ramp,
    count_tris,
    cyl,
    disc,
    empty,
    flat_shade,
    mat,
    mesh_from_bm,
    purge_unused,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "models", "scenarios", "saloon")
OUT_BLEND = os.path.join(OUT_DIR, "saloon.blend")

# Outer shell. Inner faces sit WALL_T in from these halves.
HALF_X = 7.0
HALF_Y = 9.0
WALL_T = 0.30
INNER_X = HALF_X - WALL_T  # 6.70
INNER_Y = HALF_Y - WALL_T  # 8.70
CEIL = 4.20  # underside
CEIL_T = 0.25
WALL_H = CEIL + CEIL_T

# Bar along the west wall, stopped short of the north stair.
BAR_Y0 = -4.0
BAR_Y1 = 3.4
BAR_LEN = BAR_Y1 - BAR_Y0
BAR_CY = (BAR_Y0 + BAR_Y1) * 0.5
# Counter occupies x in [-5.54, -4.86]; backbar is against the wall.
COUNTER_X = -5.20
COUNTER_D = 0.68
COUNTER_H = 1.05

# North balcony: floor at 3.0 m, front edge clear of the enemy (y = 5).
BALC_DEPTH = 1.45
BALC_FRONT = INNER_Y - BALC_DEPTH  # 7.25
BALC_Z = 3.0
# Stair run is longer than the rise so the slope stays under 45°.
STAIR_X0 = -6.55
STAIR_X1 = -4.70
STAIR_Y0 = 3.65
STAIR_Y1 = BALC_FRONT

# Shot corridor (Blender). Anything overlapping this band is a build error.
LANE_X = 1.5
LANE_Y = 6.0
LANE_Z0 = 0.30
LANE_Z1 = 2.20


def make_mats() -> dict:
    return {
        "floor": mat("M_Floor", (0.45, 0.30, 0.16, 1.0), 0.9),
        "floor_alt": mat("M_FloorAlt", (0.38, 0.25, 0.14, 1.0), 0.92),
        "wood": mat("M_Wood", (0.52, 0.36, 0.20, 1.0), 0.94),
        "wood_dark": mat("M_WoodDark", (0.30, 0.18, 0.10, 1.0), 0.9),
        "bar": mat("M_Bar", (0.24, 0.14, 0.08, 1.0), 0.72),
        "bar_top": mat("M_BarTop", (0.40, 0.26, 0.14, 1.0), 0.55),
        "trim": mat("M_Trim", (0.22, 0.13, 0.07, 1.0), 0.88),
        "iron": mat("M_Iron", (0.22, 0.22, 0.24, 1.0), 0.45, metallic=0.55),
        "brass": mat("M_Brass", (0.72, 0.52, 0.22, 1.0), 0.38, metallic=0.75),
        "glass": mat("M_Glass", (0.06, 0.08, 0.10, 1.0), 0.12, metallic=0.15),
        "mirror": mat("M_Mirror", (0.55, 0.60, 0.62, 1.0), 0.08, metallic=0.9),
        "bottle": mat("M_Bottle", (0.15, 0.38, 0.22, 1.0), 0.25),
        "bottle_amber": mat("M_BottleAmber", (0.55, 0.32, 0.10, 1.0), 0.28),
        "candle": mat("M_Candle", (0.90, 0.82, 0.62, 1.0), 0.7),
        "flame": mat("M_Flame", (0.95, 0.55, 0.15, 1.0), 0.4),
        "cloth": mat("M_Cloth", (0.35, 0.12, 0.10, 1.0), 0.95),
        "ivory": mat("M_Ivory", (0.85, 0.80, 0.68, 1.0), 0.45),
    }


def put(name, loc, size, parent, material):
    obj = box(name, loc, size, parent)
    assign(obj, material)
    flat_shade(obj)
    return obj


def put_cyl(name, start, end, r1, parent, material, r2=None, segs=8):
    obj = cyl(name, start, end, r1, r2, segs, parent)
    assign(obj, material)
    flat_shade(obj)
    return obj


def _hits_lane(loc, size) -> bool:
    hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
    x0, x1 = loc[0] - hx, loc[0] + hx
    y0, y1 = loc[1] - hy, loc[1] + hy
    z0, z1 = loc[2] - hz, loc[2] + hz
    if x1 < -LANE_X or x0 > LANE_X:
        return False
    if y1 < -LANE_Y or y0 > LANE_Y:
        return False
    if z1 < LANE_Z0 or z0 > LANE_Z1:
        return False
    return True


def col(name, loc, size, parent):
    if _hits_lane(loc, size):
        raise RuntimeError(f"collider {name} blocks the shot lane at {loc} size {size}")
    return convcol(name, loc, size, parent)


def _collect_meshes(root):
    out = []
    stack = [root]
    while stack:
        o = stack.pop()
        if o.type == "MESH":
            out.append(o)
        stack.extend(list(o.children))
    return out


def wood_ramp(name, parent, material, *, x_min, x_max, y_top, y_bottom, z_top, z_bottom=0.0):
    """Visible wedge. Same layout as ``convcol_ramp`` (high at y_top)."""
    bm = bmesh.new()
    coords = [
        Vector((x_min, y_top, z_bottom)),
        Vector((x_max, y_top, z_bottom)),
        Vector((x_max, y_bottom, z_bottom)),
        Vector((x_min, y_bottom, z_bottom)),
        Vector((x_min, y_top, z_top)),
        Vector((x_max, y_top, z_top)),
    ]
    verts = [bm.verts.new(c) for c in coords]
    bm.verts.ensure_lookup_table()
    faces = (
        (0, 1, 2, 3),
        (4, 5, 1, 0),
        (3, 2, 5, 4),
        (0, 3, 4),
        (1, 5, 2),
    )
    for f in faces:
        bm.faces.new([verts[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_from_bm(bm, name, parent)
    assign(obj, material)
    flat_shade(obj)
    return obj


def build_shell(root, mats):
    wall_cz = WALL_H * 0.5
    # Planks run the length of the room. Top sits on z = 0.
    span_y = INNER_Y * 2.0 - 0.08
    n_planks = 16
    plank_w = (INNER_X * 2.0 - 0.08) / n_planks
    for i in range(n_planks):
        x = -INNER_X + 0.04 + plank_w * (i + 0.5)
        tone = mats["floor"] if i % 2 == 0 else mats["floor_alt"]
        put(f"Plank_{i}", (x, 0, -0.03), (plank_w - 0.01, span_y, 0.06), root, tone)
    col("Floor", (0, 0, -0.20), (HALF_X * 2.0, HALF_Y * 2.0, 0.40), root)

    put("WallWest", (-HALF_X + WALL_T * 0.5, 0, wall_cz), (WALL_T, HALF_Y * 2.0, WALL_H), root, mats["wood"])
    put("WallEast", (HALF_X - WALL_T * 0.5, 0, wall_cz), (WALL_T, HALF_Y * 2.0, WALL_H), root, mats["wood"])
    put("WallNorth", (0, HALF_Y - WALL_T * 0.5, wall_cz), (HALF_X * 2.0, WALL_T, WALL_H), root, mats["wood"])
    put("WallSouth", (0, -HALF_Y + WALL_T * 0.5, wall_cz), (HALF_X * 2.0, WALL_T, WALL_H), root, mats["wood"])
    col("WallWest", (-HALF_X + WALL_T * 0.5, 0, wall_cz), (WALL_T, HALF_Y * 2.0, WALL_H), root)
    col("WallEast", (HALF_X - WALL_T * 0.5, 0, wall_cz), (WALL_T, HALF_Y * 2.0, WALL_H), root)
    col("WallNorth", (0, HALF_Y - WALL_T * 0.5, wall_cz), (HALF_X * 2.0, WALL_T, WALL_H), root)
    col("WallSouth", (0, -HALF_Y + WALL_T * 0.5, wall_cz), (HALF_X * 2.0, WALL_T, WALL_H), root)

    # Wainscot + baseboard on the inner faces, proud of the wall so they don't z-fight.
    # Skips the bar wall (the backbar covers it).
    _trim_wall(root, mats, "East", (INNER_X - 0.04, 0, 0), (0.05, INNER_Y * 2.0 - 0.2, 1))
    _trim_wall(root, mats, "North", (0, INNER_Y - 0.04, 0), (INNER_X * 2.0 - 0.2, 0.05, 1))
    _trim_wall(root, mats, "South", (0, -INNER_Y + 0.04, 0), (INNER_X * 2.0 - 0.2, 0.05, 1))

    put(
        "Ceiling",
        (0, 0, CEIL + CEIL_T * 0.5),
        (HALF_X * 2.0, HALF_Y * 2.0, CEIL_T),
        root,
        mats["wood_dark"],
    )
    col(
        "Ceiling",
        (0, 0, CEIL + CEIL_T * 0.5),
        (HALF_X * 2.0, HALF_Y * 2.0, CEIL_T),
        root,
    )
    # Beams hang under the ceiling and stay above 3.4 m. None cross the chandelier at y = 0.
    for i, y in enumerate((-6.2, -2.8, 2.8, 6.6)):
        put(
            f"Beam_{i}",
            (0, y, 3.86),
            (INNER_X * 2.0 - 0.1, 0.22, 0.68),
            root,
            mats["trim"],
        )


def _trim_wall(root, mats, tag, face, size_xyz):
    """Baseboard, wainscot, and chair rail proud of an inner wall face."""
    sx, sy, _sz = size_xyz
    x, y, _z = face
    put(f"Base_{tag}", (x, y, 0.09), (sx, sy, 0.18), root, mats["trim"])
    # Wainscot is slightly thinner than the base so the base reads as a lip.
    inset = 0.008
    if sx < sy:
        wx, wy = sx - inset, sy
    else:
        wx, wy = sx, sy - inset
    put(f"Wainscot_{tag}", (x, y, 0.66), (wx, wy, 0.92), root, mats["wood_dark"])
    put(f"Rail_{tag}", (x, y, 1.16), (sx, sy, 0.07), root, mats["trim"])


def build_bar(root, mats):
    put(
        "Counter",
        (COUNTER_X, BAR_CY, COUNTER_H * 0.5),
        (COUNTER_D, BAR_LEN, COUNTER_H),
        root,
        mats["bar"],
    )
    # Overhanging top.
    put(
        "CounterTop",
        (COUNTER_X + 0.04, BAR_CY, COUNTER_H + 0.025),
        (COUNTER_D + 0.12, BAR_LEN + 0.06, 0.06),
        root,
        mats["bar_top"],
    )
    col(
        "Counter",
        (COUNTER_X + 0.02, BAR_CY, (COUNTER_H + 0.05) * 0.5),
        (COUNTER_D + 0.16, BAR_LEN, COUNTER_H + 0.05),
        root,
    )
    # Foot rail on the customer side.
    rail_x = COUNTER_X + COUNTER_D * 0.5 + 0.16
    put_cyl(
        "FootRail",
        (rail_x, BAR_Y0 + 0.15, 0.16),
        (rail_x, BAR_Y1 - 0.15, 0.16),
        0.035,
        root,
        mats["brass"],
        segs=8,
    )
    for y in (BAR_Y0 + 0.3, BAR_CY, BAR_Y1 - 0.3):
        put_cyl(f"FootPost_{y:.1f}", (rail_x, y, 0.0), (rail_x, y, 0.16), 0.02, root, mats["brass"], segs=6)

    # Backbar against the west wall, with a walkable aisle behind the counter.
    back_x = -INNER_X + 0.19
    back_d = 0.38
    put("Backbar", (back_x, BAR_CY, 1.25), (back_d, BAR_LEN, 2.5), root, mats["wood_dark"])
    col("Backbar", (back_x, BAR_CY, 1.25), (back_d, BAR_LEN, 2.5), root)
    put(
        "Mirror",
        (-INNER_X + 0.02, BAR_CY, 1.85),
        (0.03, BAR_LEN - 0.8, 0.7),
        root,
        mats["mirror"],
    )
    for i, z in enumerate((1.42, 1.95, 2.40)):
        put(
            f"Shelf_{i}",
            (back_x, BAR_CY, z),
            (back_d + 0.04, BAR_LEN - 0.3, 0.04),
            root,
            mats["bar_top"],
        )
    _bottles(root, mats, back_x, 1.46, BAR_CY)
    # A few bottles on the counter itself.
    for i, y in enumerate((-2.4, -0.6, 1.6)):
        tone = mats["bottle"] if i % 2 == 0 else mats["bottle_amber"]
        put_cyl(
            f"BarBottle_{i}",
            (COUNTER_X - 0.05, y, COUNTER_H + 0.05),
            (COUNTER_X - 0.05, y, COUNTER_H + 0.28),
            0.045,
            root,
            tone,
            r2=0.03,
            segs=6,
        )


def _bottles(root, mats, x, z, y_center):
    for i, yoff in enumerate((-2.6, -1.9, -1.2, -0.4, 0.5, 1.3, 2.0, 2.7)):
        tone = mats["bottle"] if i % 2 == 0 else mats["bottle_amber"]
        put_cyl(
            f"ShelfBottle_{i}",
            (x, y_center + yoff, z),
            (x, y_center + yoff, z + 0.22),
            0.04,
            root,
            tone,
            r2=0.025,
            segs=6,
        )


def build_table(root, mats, tag, x, y):
    """Round table plus four chairs. ``x`` must stay east of the shot lane."""
    put_cyl(f"Pedestal_{tag}", (x, y, 0.0), (x, y, 0.72), 0.08, root, mats["wood_dark"], segs=8)
    top = disc(f"TableTop_{tag}", (x, y, 0.75), 0.62, 0.06, 12, root)
    assign(top, mats["bar_top"])
    flat_shade(top)
    col(f"Table_{tag}", (x, y, 0.40), (1.24, 1.24, 0.80), root)
    # Chairs sit ~0.95 out; the -X chair of the westernmost table stays past |x| = 1.5.
    chairs = (
        (x + 0.95, y, math.pi * 0.5),
        (x - 0.95, y, -math.pi * 0.5),
        (x, y + 0.95, math.pi),
        (x, y - 0.95, 0.0),
    )
    for i, (cx, cy, yaw) in enumerate(chairs):
        _chair(root, mats, f"{tag}_{i}", cx, cy, yaw)


def _chair(root, mats, name, x, y, yaw):
    pivot = empty(f"Chair_{name}", root)
    pivot.location = Vector((x, y, 0.0))
    pivot.rotation_euler = (0.0, 0.0, yaw)
    put("Seat", (0, 0, 0.46), (0.42, 0.42, 0.06), pivot, mats["wood"])
    put("Back", (0, -0.19, 0.78), (0.42, 0.05, 0.55), pivot, mats["wood_dark"])
    put("Cushion", (0, 0.02, 0.50), (0.34, 0.34, 0.04), pivot, mats["cloth"])
    for tag, lx, ly in (("FR", 0.16, 0.16), ("FL", 0.16, -0.16), ("BR", -0.16, 0.16), ("BL", -0.16, -0.16)):
        put(f"Leg_{name}_{tag}", (lx, ly, 0.22), (0.05, 0.05, 0.44), pivot, mats["trim"])
    # Local -Y is the back. Name must end in -convcolonly (no Blender .001 suffix).
    convcol(f"Chair_{name}", (0, -0.02, 0.50), (0.46, 0.48, 1.00), pivot)


def build_doors(root, mats):
    """Swinging leaves on the player-end (south) wall, hinged just inside the room."""
    hinge_y = -INNER_Y + 0.05
    angle = math.radians(32)
    _leaf(root, mats, "DoorL", (-0.84, hinge_y, 0.0), 0.40, angle)
    _leaf(root, mats, "DoorR", (0.84, hinge_y, 0.0), -0.40, -angle)
    fy = -INNER_Y + 0.06
    put("DoorJambL", (-1.05, fy, 1.15), (0.16, 0.10, 2.30), root, mats["trim"])
    put("DoorJambR", (1.05, fy, 1.15), (0.16, 0.10, 2.30), root, mats["trim"])
    put("DoorHead", (0, fy, 2.32), (2.26, 0.10, 0.16), root, mats["trim"])


def _leaf(root, mats, name, hinge, local_x, rot_z):
    leaf = put(name, (local_x, 0.0, 1.10), (0.78, 0.045, 2.15), root, mats["wood"])
    leaf.location = Vector(hinge)
    leaf.rotation_euler = (0.0, 0.0, rot_z)
    # Brace so the leaf reads as a swinging door, not a slab.
    brace = put(f"{name}Brace", (local_x, 0.03, 1.05), (0.62, 0.02, 0.07), root, mats["trim"])
    brace.location = Vector(hinge)
    brace.rotation_euler = (0.0, 0.0, rot_z)


def build_windows(root, mats):
    # East wall, looking into the room (-X).
    for i, y in enumerate((-4.6, 0.0, 4.6)):
        _window(root, mats, f"E{i}", (INNER_X - 0.03, y, 1.90), (0.04, 1.05, 1.40), east=True)
    # South wall, flanking the doors.
    for i, x in enumerate((-3.5, 3.5)):
        _window(root, mats, f"S{i}", (x, -INNER_Y + 0.03, 1.90), (1.05, 0.04, 1.40), east=False)


def _window(root, mats, tag, center, pane, east):
    put(f"Pane_{tag}", center, pane, root, mats["glass"])
    cx, cy, cz = center
    pw, pd, ph = pane
    frame_t = 0.08
    if east:
        fx = cx - 0.015
        put(f"WinTop_{tag}", (fx, cy, cz + ph * 0.5 + frame_t * 0.4), (0.06, pw + 0.16, frame_t), root, mats["trim"])
        put(f"WinBot_{tag}", (fx, cy, cz - ph * 0.5 - frame_t * 0.4), (0.06, pw + 0.16, frame_t), root, mats["trim"])
        put(f"WinL_{tag}", (fx, cy - pd * 0.5 - 0.06, cz), (0.06, frame_t, ph), root, mats["trim"])
        put(f"WinR_{tag}", (fx, cy + pd * 0.5 + 0.06, cz), (0.06, frame_t, ph), root, mats["trim"])
    else:
        fy = cy + 0.015
        put(f"WinTop_{tag}", (cx, fy, cz + ph * 0.5 + frame_t * 0.4), (pw + 0.16, 0.06, frame_t), root, mats["trim"])
        put(f"WinBot_{tag}", (cx, fy, cz - ph * 0.5 - frame_t * 0.4), (pw + 0.16, 0.06, frame_t), root, mats["trim"])
        put(f"WinL_{tag}", (cx - pw * 0.5 - 0.06, fy, cz), (frame_t, 0.06, ph), root, mats["trim"])
        put(f"WinR_{tag}", (cx + pw * 0.5 + 0.06, fy, cz), (frame_t, 0.06, ph), root, mats["trim"])


def build_piano(root, mats):
    """Upright piano in the south-east corner, keyboard facing into the room."""
    px, py = 5.45, -7.20
    put("PianoBody", (px, py, 0.62), (0.62, 1.40, 1.15), root, mats["wood_dark"])
    put("PianoKeys", (px - 0.40, py, 0.74), (0.20, 1.15, 0.07), root, mats["ivory"])
    put("PianoMusic", (px - 0.22, py, 1.28), (0.04, 0.55, 0.32), root, mats["wood"])
    put("PianoBench", (px - 0.85, py, 0.28), (0.36, 0.70, 0.08), root, mats["wood"])
    for ly in (-0.28, 0.28):
        put(f"BenchLeg_{ly}", (px - 0.85, py + ly, 0.13), (0.06, 0.06, 0.26), root, mats["trim"])
    col("Piano", (px - 0.15, py, 0.62), (1.15, 1.50, 1.24), root)


def build_stove(root, mats):
    """Potbelly stove in the north-east, in front of the balcony."""
    sx, sy = 5.55, 6.35
    put_cyl("StoveBody", (sx, sy, 0.12), (sx, sy, 0.90), 0.28, root, mats["iron"], segs=8)
    put_cyl("StoveBelly", (sx, sy, 0.38), (sx, sy, 0.72), 0.40, root, mats["iron"], segs=8)
    put_cyl("StovePipe", (sx, sy, 0.85), (sx, sy, 2.55), 0.07, root, mats["iron"], segs=6)
    put("StoveDoor", (sx - 0.36, sy, 0.48), (0.04, 0.22, 0.22), root, mats["trim"])
    col("Stove", (sx, sy, 0.55), (0.85, 0.85, 1.10), root)


def build_barrels(root, mats):
    """Cluster at the south end of the bar, off the shot lane."""
    spots = ((-4.35, -5.15, 0.42), (-4.85, -5.55, 0.36), (-3.90, -5.60, 0.32))
    for i, (x, y, h) in enumerate(spots):
        put_cyl(f"Barrel_{i}", (x, y, 0.0), (x, y, h), 0.28, root, mats["wood"], r2=0.26, segs=8)
        put_cyl(
            f"Hoop_{i}",
            (x, y, h * 0.45 - 0.015),
            (x, y, h * 0.45 + 0.015),
            0.30,
            root,
            mats["iron"],
            segs=8,
        )
        col(f"Barrel_{i}", (x, y, h * 0.5), (0.60, 0.60, h), root)


def build_spittoons(root, mats):
    for i, y in enumerate((-1.6, 1.8)):
        put_cyl(f"Spittoon_{i}", (-4.55, y, 0.0), (-4.55, y, 0.10), 0.10, root, mats["brass"], r2=0.13, segs=8)


def build_chandelier(root, mats):
    """Hangs on the existing Godot light (Blender z = 3.4, Godot y = 3.4). No collision."""
    put_cyl("Chain", (0, 0, 3.55), (0, 0, CEIL - 0.02), 0.015, root, mats["iron"], segs=6)
    ring = disc("ChandelierRing", (0, 0, 3.42), 0.55, 0.04, 12, root)
    assign(ring, mats["brass"])
    flat_shade(ring)
    for i in range(6):
        ang = i * math.tau / 6.0
        x = math.cos(ang) * 0.42
        y = math.sin(ang) * 0.42
        put_cyl(f"Candle_{i}", (x, y, 3.44), (x, y, 3.58), 0.025, root, mats["candle"], segs=6)
        flame = cone(f"Flame_{i}", (x, y, 3.58), 0.018, 0.06, root, segs=4)
        assign(flame, mats["flame"])
        flat_shade(flame)


def build_balcony(root, mats):
    """Shallow north mezzanine. Underside ~2.86 m; front edge at y = 7.25 (enemy is y = 5)."""
    slab_y = (BALC_FRONT + INNER_Y) * 0.5
    slab_d = INNER_Y - BALC_FRONT
    slab_w = INNER_X * 2.0 - 0.15
    put("Balcony", (0, slab_y, BALC_Z - 0.07), (slab_w, slab_d, 0.14), root, mats["wood"])
    col("Balcony", (0, slab_y, BALC_Z - 0.07), (slab_w, slab_d, 0.14), root)

    # Rail along the front, with a gap where the stair arrives.
    rail_z = BALC_Z + 0.48
    rail_x0 = STAIR_X1 + 0.15
    rail_w = (INNER_X - 0.15) - rail_x0
    rail_cx = rail_x0 + rail_w * 0.5
    put("BalconyRail", (rail_cx, BALC_FRONT + 0.04, rail_z), (rail_w, 0.08, 0.08), root, mats["trim"])
    col("BalconyRail", (rail_cx, BALC_FRONT + 0.04, BALC_Z + 0.45), (rail_w, 0.10, 0.90), root)
    x = rail_x0
    i = 0
    while x <= INNER_X - 0.2:
        put(f"BalPost_{i}", (x, BALC_FRONT + 0.04, BALC_Z + 0.45), (0.08, 0.08, 0.90), root, mats["wood_dark"])
        x += 1.55
        i += 1

    run = STAIR_Y1 - STAIR_Y0
    rise = BALC_Z
    if run < rise:
        raise RuntimeError(f"stair is steeper than 45° (run {run:.2f} < rise {rise:.2f})")
    wood_ramp(
        "Stair",
        root,
        mats["wood"],
        x_min=STAIR_X0,
        x_max=STAIR_X1,
        y_top=STAIR_Y1,
        y_bottom=STAIR_Y0,
        z_top=BALC_Z,
        z_bottom=0.0,
    )
    convcol_ramp(
        "Stair",
        root,
        x_min=STAIR_X0,
        x_max=STAIR_X1,
        y_top=STAIR_Y1,
        y_bottom=STAIR_Y0,
        z_top=BALC_Z,
        z_bottom=0.0,
    )
    put_cyl(
        "StairRail",
        (STAIR_X1 + 0.04, STAIR_Y0 + 0.15, 0.95),
        (STAIR_X1 + 0.04, STAIR_Y1 - 0.05, BALC_Z + 0.85),
        0.035,
        root,
        mats["brass"],
        segs=6,
    )
    for i, t in enumerate((0.15, 0.55, 0.9)):
        y = STAIR_Y0 + (STAIR_Y1 - STAIR_Y0) * t
        z = BALC_Z * t
        put(f"StairPost_{i}", (STAIR_X1 + 0.04, y, z * 0.5 + 0.4), (0.07, 0.07, z + 0.8), root, mats["wood_dark"])


def build_interior(mats):
    root = empty("saloon_interior")
    build_shell(root, mats)
    build_bar(root, mats)
    # Godot (3.5, _, 2.5) and (4.0, _, -3.0) — east of the lane.
    build_table(root, mats, "A", 3.5, -2.5)
    build_table(root, mats, "B", 4.0, 3.0)
    build_doors(root, mats)
    build_windows(root, mats)
    build_piano(root, mats)
    build_stove(root, mats)
    build_barrels(root, mats)
    build_spittoons(root, mats)
    build_chandelier(root, mats)
    build_balcony(root, mats)
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
        bg.inputs["Color"].default_value = (0.08, 0.05, 0.03, 1.0)
        bg.inputs["Strength"].default_value = 0.35


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    clear_scene()
    setup_world()
    mats = make_mats()
    root = build_interior(mats)
    purge_unused()
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print(f"saved {OUT_BLEND}")

    glb = os.path.join(OUT_DIR, "saloon_interior.glb")
    export_glb(root, glb)
    print(f"exported {glb}")

    total = 0
    for m in _collect_meshes(root):
        if "-convcolonly" not in m.name:
            total += count_tris(m)
    print(f"BUILD_OK visible_tris≈{total}")


main()
