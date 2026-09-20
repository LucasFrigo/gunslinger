"""Build the Main Street greybox kit inside Blender (headless).

True metric scale, Z-up, 1 BU = 1 m. Street-facing facade toward +Y
(becomes -Z in Godot after Y-up glTF export). Collision proxies use the
``-convcolonly`` Godot import suffix.

Run:
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/build_main_street_blender.py
"""
from __future__ import annotations

import math
import os
import random
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
    join_into,
    mat,
    mesh_from_bm,
    purge_unused,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "models", "scenarios", "main_street")
OUT_BLEND = os.path.join(OUT_DIR, "main_street.blend")

# Flat greybox palette (no atlas / images).
COL_DIRT = (0.72, 0.55, 0.32, 1.0)
COL_DIRT_FAR = (0.48, 0.36, 0.22, 1.0)
COL_WOOD = (0.52, 0.38, 0.24, 1.0)
COL_WOOD_DARK = (0.32, 0.22, 0.14, 1.0)
COL_MASONRY = (0.55, 0.50, 0.45, 1.0)
COL_WHITEWASH = (0.88, 0.85, 0.78, 1.0)
COL_IRON = (0.28, 0.30, 0.32, 1.0)
COL_ROOF = (0.35, 0.28, 0.22, 1.0)
COL_COW = (0.42, 0.30, 0.20, 1.0)
COL_COW_DARK = (0.18, 0.12, 0.08, 1.0)
COL_CACTUS = (0.28, 0.48, 0.28, 1.0)
COL_CACTUS_DARK = (0.18, 0.34, 0.20, 1.0)
COL_SCRUB = (0.35, 0.40, 0.22, 1.0)
COL_SCRUB_DRY = (0.45, 0.38, 0.22, 1.0)
COL_YUCCA = (0.40, 0.48, 0.28, 1.0)

# Kit piece ids → builder callables (filled after defs).
PIECES: list[tuple[str, callable]] = []


def make_mats() -> dict:
    return {
        "dirt": mat("M_Dirt", COL_DIRT, 1.0),
        "dirt_far": mat("M_DirtFar", COL_DIRT_FAR, 1.0),
        "wood": mat("M_Wood", COL_WOOD, 0.95),
        "wood_dark": mat("M_WoodDark", COL_WOOD_DARK, 0.95),
        "masonry": mat("M_Masonry", COL_MASONRY, 0.92),
        "whitewash": mat("M_Whitewash", COL_WHITEWASH, 0.9),
        "iron": mat("M_Iron", COL_IRON, 0.55, metallic=0.4),
        "roof": mat("M_Roof", COL_ROOF, 0.95),
        "cow": mat("M_Cow", COL_COW, 0.95),
        "cow_dark": mat("M_CowDark", COL_COW_DARK, 0.95),
        "cactus": mat("M_Cactus", COL_CACTUS, 0.92),
        "cactus_dark": mat("M_CactusDark", COL_CACTUS_DARK, 0.92),
        "scrub": mat("M_Scrub", COL_SCRUB, 0.95),
        "scrub_dry": mat("M_ScrubDry", COL_SCRUB_DRY, 0.95),
        "yucca": mat("M_Yucca", COL_YUCCA, 0.9),
    }


def shade_all(objs):
    for o in objs:
        if o.type == "MESH":
            flat_shade(o)


def _collect_meshes(root):
    out = []
    stack = [root]
    while stack:
        o = stack.pop()
        if o.type == "MESH":
            out.append(o)
        stack.extend(list(o.children))
    return out


# ---------------------------------------------------------------------------
# Builders — origin at ground, centred on width (X), facade toward +Y.
# ---------------------------------------------------------------------------

def build_env_street_ground(mats):
    root = empty("env_street_ground")
    # Town dirt strip only — surrounding desert is env_terrain.
    ground = box("Street", (0, 0, -0.5), (28, 90, 1), root)
    assign(ground, mats["dirt"])
    flat_shade(ground)
    convcol("Street", (0, 0, -0.5), (28, 90, 1), root)
    return root


def build_env_terrain(mats):
    """Large flat desert apron. Top slightly above y=0 so building feet bury into dirt."""
    root = empty("env_terrain")
    size = 2000.0
    # Top at +0.12 buries kit origins (authored at z=0) and kills the float look.
    ground = box("TerrainFlat", (0, 0, -0.13), (size, size, 0.5), root)
    assign(ground, mats["dirt_far"])
    flat_shade(ground)
    convcol("TerrainPlayable", (0, 0, -0.13), (size, size, 0.5), root)
    return root


def build_env_rail_track_8m(mats):
    root = empty("env_rail_track_8m")
    # Ballast bed so the line reads from a distance.
    ballast = box("Ballast", (0, 0, 0.04), (8.0, 2.6, 0.1), root)
    assign(ballast, mats["dirt"])
    flat_shade(ballast)
    for y_off in (-0.7, 0.7):
        rail = box(f"Rail_{y_off}", (0, y_off, 0.14), (8.0, 0.14, 0.14), root)
        assign(rail, mats["iron"])
        flat_shade(rail)
    for i in range(-3, 4):
        tie = box(f"Tie_{i}", (i * 1.1, 0, 0.08), (0.22, 2.2, 0.1), root)
        assign(tie, mats["wood_dark"])
        flat_shade(tie)
    convcol("Track", (0, 0, 0.08), (8.0, 2.6, 0.28), root)
    return root


def build_prp_cow(mats):
    root = empty("prp_cow")
    # Facing +Y (street convention). Rough Longhorn-ish greybox.
    body = box("Body", (0, 0, 0.85), (0.55, 1.5, 0.7), root)
    assign(body, mats["cow"])
    head = box("Head", (0, 0.95, 1.15), (0.4, 0.45, 0.4), root)
    assign(head, mats["cow"])
    snout = box("Snout", (0, 1.25, 1.0), (0.28, 0.3, 0.25), root)
    assign(snout, mats["cow_dark"])
    for side, x in (("L", 0.22), ("R", -0.22)):
        horn = cyl(f"Horn_{side}", (x, 0.9, 1.35), (x * 2.2, 0.75, 1.55), 0.04, 0.02, 5, root)
        assign(horn, mats["cow_dark"])
        flat_shade(horn)
    for name, x, y in (
        ("FL", 0.2, 0.45), ("FR", -0.2, 0.45),
        ("BL", 0.2, -0.5), ("BR", -0.2, -0.5),
    ):
        leg = box(f"Leg_{name}", (x, y, 0.3), (0.14, 0.14, 0.6), root)
        assign(leg, mats["cow_dark"])
        flat_shade(leg)
    for o in (body, head, snout):
        flat_shade(o)
    convcol("Cow", (0, 0.1, 0.75), (0.7, 1.8, 1.5), root)
    return root


def _false_front(root, mats, width, body_h, front_h, depth, wood_key="wood"):
    """False-front parapet above the real storey — not a full-height slab over doors."""
    parts = []
    body = box("Body", (0, 0, body_h * 0.5), (width, depth, body_h), root)
    assign(body, mats[wood_key])
    parts.append(body)
    front_thickness = 0.22
    parapet_h = max(0.6, front_h - body_h)
    fy = depth * 0.5 + front_thickness * 0.5
    front = box(
        "FalseFront",
        (0, fy, body_h + parapet_h * 0.5),
        (width, front_thickness, parapet_h),
        root,
    )
    assign(front, mats[wood_key])
    parts.append(front)
    cornice = box(
        "Cornice",
        (0, fy + front_thickness * 0.5 + 0.08, front_h - 0.15),
        (width + 0.2, 0.28, 0.3),
        root,
    )
    assign(cornice, mats["wood_dark"])
    parts.append(cornice)
    roof_h = 0.3
    roof = box(
        "Roof",
        (0, -0.15, body_h + roof_h * 0.5),
        (width - 0.1, depth - 0.4, roof_h),
        root,
    )
    assign(roof, mats["roof"])
    parts.append(roof)
    shade_all(parts)
    convcol("Mass", (0, 0, front_h * 0.5), (width, depth + front_thickness, front_h), root)
    return parts


def _facade_y(depth, panel_d=0.08, gap=0.03):
    """Centre Y for a panel mounted proud of the street facade (avoids z-fight)."""
    return depth * 0.5 + gap + panel_d * 0.5


def _door_recess(root, mats, width, depth, door_w=1.2, door_h=2.1, recess=0.4):
    """Door leaf + frame mounted proud of the body wall."""
    _ = recess
    panel_d = 0.1
    frame_d = 0.12
    fy = _facade_y(depth, panel_d)
    door = box("Door", (0, fy, door_h * 0.5), (door_w, panel_d, door_h), root)
    assign(door, mats["wood_dark"])
    flat_shade(door)
    ffy = _facade_y(depth, frame_d, gap=0.02)
    frame_parts = [
        box("DoorFrameTop", (0, ffy, door_h + 0.1), (door_w + 0.28, frame_d, 0.2), root),
        box("DoorFrameL", (-door_w * 0.5 - 0.1, ffy, door_h * 0.5), (0.2, frame_d, door_h), root),
        box("DoorFrameR", (door_w * 0.5 + 0.1, ffy, door_h * 0.5), (0.2, frame_d, door_h), root),
    ]
    for p in frame_parts:
        assign(p, mats["wood"])
        flat_shade(p)
    return door


def _window(root, mats, x, depth, z, w=1.0, h=1.2, d=0.1):
    """Window pane mounted proud of the body wall."""
    fy = _facade_y(depth, d)
    win = box(f"Win_{x:.1f}_{z:.1f}", (x, fy, z), (w, d, h), root)
    assign(win, mats["iron"])
    flat_shade(win)
    return win


def build_bld_saloon(mats):
    root = empty("bld_saloon")
    width, depth = 9.0, 12.0
    body_h, front_h = 4.0, 5.5
    _false_front(root, mats, width, body_h, front_h, depth, "wood")
    _door_recess(root, mats, width, depth, door_w=1.8, door_h=2.2, recess=0.5)
    _window(root, mats, -2.5, depth, 2.8, 1.4, 1.4)
    _window(root, mats, 2.5, depth, 2.8, 1.4, 1.4)
    # Signboard on the parapet, not over the door.
    sign_d = 0.1
    sign = box("Sign", (0, _facade_y(depth, sign_d, gap=0.28), body_h + 0.85), (6.0, sign_d, 0.7), root)
    assign(sign, mats["wood_dark"])
    flat_shade(sign)
    return root


def build_bld_hotel(mats):
    root = empty("bld_hotel")
    width, depth = 11.0, 14.0
    body_h, front_h = 7.0, 8.0  # two real storeys
    _false_front(root, mats, width, body_h, front_h, depth, "wood")
    _door_recess(root, mats, width, depth, door_w=1.4, door_h=2.2)
    for x in (-3.5, -1.2, 1.2, 3.5):
        _window(root, mats, x, depth, 2.0, 1.1, 1.3)
        _window(root, mats, x, depth, 5.0, 1.1, 1.3)
    # Full-width second-floor gallery over the walk (projects +Y past facade).
    gallery_y = depth * 0.5 + 1.0
    deck = box("GalleryDeck", (0, gallery_y, 3.2), (width, 2.0, 0.15), root)
    assign(deck, mats["wood_dark"])
    flat_shade(deck)
    convcol("Gallery", (0, gallery_y, 3.2), (width, 2.0, 0.15), root)
    rail = box("GalleryRail", (0, gallery_y + 0.85, 4.0), (width, 0.1, 0.9), root)
    assign(rail, mats["wood"])
    flat_shade(rail)
    for x in (-4.5, -1.5, 1.5, 4.5):
        post = box(f"GalPost_{x}", (x, gallery_y + 0.85, 2.0), (0.15, 0.15, 4.0), root)
        assign(post, mats["wood_dark"])
        flat_shade(post)
        convcol(f"GalPost_{x}", (x, gallery_y + 0.85, 2.0), (0.2, 0.2, 4.0), root)
    return root


def build_bld_general_store(mats):
    root = empty("bld_general_store")
    width, depth = 9.0, 12.0
    body_h, front_h = 4.5, 5.5
    _false_front(root, mats, width, body_h, front_h, depth, "wood_dark")
    _door_recess(root, mats, width, depth)
    _window(root, mats, -2.4, depth, 2.2, 2.0, 1.6)
    _window(root, mats, 2.4, depth, 2.2, 2.0, 1.6)
    # Loading platform / shed awning projecting past facade.
    plat_y = depth * 0.5 + 1.4
    plat_w = width * 0.7
    plat = box("LoadingPlat", (0, plat_y, 0.35), (plat_w, 2.4, 0.7), root)
    assign(plat, mats["wood"])
    flat_shade(plat)
    convcol("LoadingPlat", (0, plat_y, 0.35), (plat_w, 2.4, 0.7), root)
    # Invisible street-side approach ramp (~30°): rise 0.7 m over 1.4 m run.
    plat_edge = plat_y + 1.2
    convcol_ramp(
        "LoadingRamp",
        root,
        x_min=-plat_w * 0.5,
        x_max=plat_w * 0.5,
        y_top=plat_edge,
        y_bottom=plat_edge + 1.4,
        z_top=0.7,
        z_bottom=0.0,
    )
    awning = box("ShedAwning", (0, plat_y, 2.9), (width * 0.75, 2.6, 0.12), root)
    assign(awning, mats["roof"])
    flat_shade(awning)
    return root


def build_bld_bank(mats):
    root = empty("bld_bank")
    width, depth = 8.0, 12.0
    # Masonry, real two storeys, parapet — no wood false front.
    body_h = 7.5
    body = box("Body", (0, 0, body_h * 0.5), (width, depth, body_h), root)
    assign(body, mats["masonry"])
    flat_shade(body)
    # Parapet lip.
    parapet = box("Parapet", (0, 0, body_h + 0.25), (width + 0.3, depth + 0.3, 0.5), root)
    assign(parapet, mats["masonry"])
    flat_shade(parapet)
    # Pilasters proud of the facade corners.
    pil_d = 0.35
    fy = _facade_y(depth, pil_d, gap=0.01)
    for x in (-width * 0.5 + 0.25, width * 0.5 - 0.25):
        pil = box(f"Pil_{x:.1f}", (x, fy, body_h * 0.5), (0.4, pil_d, body_h), root)
        assign(pil, mats["whitewash"])
        flat_shade(pil)
    _door_recess(root, mats, width, depth, door_w=1.5, door_h=2.4, recess=0.35)
    for x in (-2.0, 2.0):
        _window(root, mats, x, depth, 2.4, 1.2, 1.6)
        _window(root, mats, x, depth, 5.4, 1.2, 1.4)
    convcol("Mass", (0, 0, (body_h + 0.5) * 0.5), (width + 0.3, depth + 0.3, body_h + 0.5), root)
    return root


def build_bld_newspaper(mats):
    root = empty("bld_newspaper")
    width, depth = 5.0, 10.0
    body_h, front_h = 4.0, 5.0
    _false_front(root, mats, width, body_h, front_h, depth, "wood")
    _door_recess(root, mats, width, depth, door_w=1.0)
    # Big display window.
    _window(root, mats, 0.0, depth, 2.0, 2.8, 1.8, 0.1)
    return root


def build_bld_jail(mats):
    root = empty("bld_jail")
    width, depth = 6.0, 10.0
    body_h = 3.8  # squat, no false front
    body = box("Body", (0, 0, body_h * 0.5), (width, depth, body_h), root)
    assign(body, mats["masonry"])
    flat_shade(body)
    roof = box("Roof", (0, 0, body_h + 0.2), (width + 0.3, depth + 0.3, 0.4), root)
    assign(roof, mats["roof"])
    flat_shade(roof)
    _door_recess(root, mats, width, depth, door_w=1.1, door_h=2.1, recess=0.25)
    # Small barred openings.
    for x in (-1.6, 1.6):
        _window(root, mats, x, depth, 2.2, 0.7, 0.7, 0.08)
        bar = box(f"Bar_{x}", (x, _facade_y(depth, 0.06, gap=0.12), 2.2), (0.06, 0.06, 0.7), root)
        assign(bar, mats["iron"])
        flat_shade(bar)
    convcol("Mass", (0, 0, (body_h + 0.4) * 0.5), (width + 0.3, depth + 0.3, body_h + 0.4), root)
    return root


def build_bld_church(mats):
    root = empty("bld_church")
    width, depth = 8.0, 14.0
    wall_h = 5.0
    # Clapboard nave, gable toward +Y (street).
    nave = box("Nave", (0, 0, wall_h * 0.5), (width, depth, wall_h), root)
    assign(nave, mats["whitewash"])
    flat_shade(nave)
    # Simple gable prism as a pitched box (greybox).
    gable = box("Gable", (0, depth * 0.5 - 0.5, wall_h + 1.2), (width, 1.0, 2.4), root)
    assign(gable, mats["whitewash"])
    flat_shade(gable)
    roof = box("Roof", (0, 0, wall_h + 1.5), (width + 0.4, depth + 0.4, 0.35), root)
    assign(roof, mats["roof"])
    flat_shade(roof)
    # Steeple at the street end.
    steeple_y = depth * 0.5 - 1.5
    tower = box("Steeple", (0, steeple_y, 7.0), (2.2, 2.2, 4.0), root)
    assign(tower, mats["whitewash"])
    flat_shade(tower)
    spire = cone("Spire", (0, steeple_y, 9.0), 1.3, 3.0, root, segs=4)
    assign(spire, mats["wood_dark"])
    flat_shade(spire)
    _door_recess(root, mats, width, depth, door_w=1.6, door_h=2.6, recess=0.3)
    for x in (-2.2, 2.2):
        _window(root, mats, x, depth, 3.0, 1.0, 2.0)
    convcol("Mass", (0, 0, 5.5), (width + 0.4, depth + 0.4, 11.0), root)
    return root


def build_bld_depot(mats):
    root = empty("bld_depot")
    width, depth = 14.0, 8.0
    wall_h = 4.2
    roof_h = 0.4
    # Station hall — roof sits flush on the walls (no air gap).
    hall = box("Hall", (0, 0, wall_h * 0.5), (width, depth, wall_h), root)
    assign(hall, mats["wood"])
    flat_shade(hall)
    roof = box("Roof", (0, 0, wall_h + roof_h * 0.5), (width + 1.2, depth + 1.2, roof_h), root)
    assign(roof, mats["roof"])
    flat_shade(roof)
    # End gables sit on the roof deck.
    gable_h = 1.2
    gable_l = box(
        "GableL",
        (-width * 0.5 + 0.3, 0, wall_h + roof_h + gable_h * 0.5),
        (0.3, depth, gable_h),
        root,
    )
    gable_r = box(
        "GableR",
        (width * 0.5 - 0.3, 0, wall_h + roof_h + gable_h * 0.5),
        (0.3, depth, gable_h),
        root,
    )
    for g in (gable_l, gable_r):
        assign(g, mats["wood"])
        flat_shade(g)
    # Platform toward street.
    plat_y = depth * 0.5 + 1.5
    plat_w = width + 2.0
    plat = box("Platform", (0, plat_y, 0.4), (plat_w, 3.0, 0.8), root)
    assign(plat, mats["wood_dark"])
    flat_shade(plat)
    convcol("Platform", (0, plat_y, 0.4), (plat_w, 3.0, 0.8), root)
    # Invisible street-side approach ramp (~27°): rise 0.8 m over 1.6 m run.
    plat_edge = plat_y + 1.5
    convcol_ramp(
        "PlatformRamp",
        root,
        x_min=-plat_w * 0.5,
        x_max=plat_w * 0.5,
        y_top=plat_edge,
        y_bottom=plat_edge + 1.6,
        z_top=0.8,
        z_bottom=0.0,
    )
    # Water tower — legs dig slightly into the dirt so they don't hover.
    tower_x = width * 0.5 + 3.0
    legs = []
    for dx, dy in ((-0.8, -0.8), (0.8, -0.8), (-0.8, 0.8), (0.8, 0.8)):
        leg = cyl(
            f"Leg_{dx}_{dy}",
            (tower_x + dx, dy, -0.15),
            (tower_x + dx, dy, 6.0),
            0.12, 0.12, 6, root,
        )
        assign(leg, mats["iron"])
        legs.append(leg)
    tank = cyl("Tank", (tower_x, 0, 6.0), (tower_x, 0, 8.5), 1.6, 1.6, 8, root)
    assign(tank, mats["wood_dark"])
    flat_shade(tank)
    for leg in legs:
        flat_shade(leg)
    convcol("Hall", (0, 0, wall_h * 0.5), (width, depth, wall_h + roof_h), root)
    convcol("Tower", (tower_x, 0, 4.25), (3.5, 3.5, 8.5), root)
    _door_recess(root, mats, width, depth, door_w=1.4, door_h=2.4)
    return root


def build_env_boardwalk_4m(mats):
    root = empty("env_boardwalk_4m")
    # 4 m along X (street run after rotation), 2.5 m deep (Y), deck top at z=0.40.
    deck = box("Deck", (0, 0, 0.32), (4.0, 2.5, 0.16), root)
    assign(deck, mats["wood"])
    flat_shade(deck)
    convcol("Deck", (0, 0, 0.32), (4.0, 2.5, 0.16), root)
    # Joists under deck.
    for x in (-1.5, 0.0, 1.5):
        j = box(f"Joist_{x}", (x, 0, 0.18), (0.15, 2.4, 0.2), root)
        assign(j, mats["wood_dark"])
        flat_shade(j)
    # Invisible street-side step ramp (~22°): rise 0.40 m over 1.0 m run so
    # flat/VR walkers can step up without a cliff (meshes stay stepped).
    deck_edge_y = 1.25
    convcol_ramp(
        "StepRamp",
        root,
        x_min=-2.0,
        x_max=2.0,
        y_top=deck_edge_y,
        y_bottom=deck_edge_y + 1.0,
        z_top=0.40,
        z_bottom=0.0,
    )
    return root


def build_env_awning_post(mats):
    root = empty("env_awning_post")
    # Post from ground to awning underside (~2.8 m clear).
    post = box("Post", (0, 0, 1.5), (0.18, 0.18, 3.0), root)
    assign(post, mats["wood_dark"])
    flat_shade(post)
    convcol("Post", (0, 0, 1.5), (0.22, 0.22, 3.0), root)
    # Small awning beam stub toward +Y (street).
    beam = box("Beam", (0, 0.9, 2.85), (0.15, 1.8, 0.15), root)
    assign(beam, mats["wood"])
    flat_shade(beam)
    canopy = box("Canopy", (0, 0.9, 2.95), (1.2, 2.0, 0.08), root)
    assign(canopy, mats["roof"])
    flat_shade(canopy)
    return root


def build_env_cattle_fence_4m(mats):
    root = empty("env_cattle_fence_4m")
    # 4 m run along X, rails face +Y.
    for x in (-1.7, 0.0, 1.7):
        post = box(f"Post_{x}", (x, 0, 0.7), (0.12, 0.12, 1.4), root)
        assign(post, mats["wood_dark"])
        flat_shade(post)
        convcol(f"Post_{x}", (x, 0, 0.7), (0.18, 0.18, 1.4), root)
    for z in (0.35, 0.75, 1.15):
        rail = box(f"Rail_{z}", (0, 0, z), (4.0, 0.08, 0.1), root)
        assign(rail, mats["wood"])
        flat_shade(rail)
        convcol(f"Rail_{z}", (0, 0, z), (4.0, 0.16, 0.16), root)
    return root


def build_prp_trough(mats):
    root = empty("prp_trough")
    trough = box("Trough", (0, 0, 0.35), (0.6, 2.0, 0.7), root)
    assign(trough, mats["iron"])
    flat_shade(trough)
    convcol("Trough", (0, 0, 0.35), (0.6, 2.0, 0.7), root)
    return root


def build_prp_barrels(mats):
    root = empty("prp_barrels")
    for i, (x, y) in enumerate(((0.0, 0.0), (0.7, 0.15), (-0.55, 0.2))):
        b = cyl(f"Barrel_{i}", (x, y, 0), (x, y, 1.1), 0.4, 0.4, 8, root)
        assign(b, mats["wood_dark"])
        flat_shade(b)
    convcol("Barrels", (0, 0.1, 0.55), (1.6, 1.0, 1.1), root)
    return root


def build_prp_hitching_rail(mats):
    root = empty("prp_hitching_rail")
    for x in (-1.2, 1.2):
        post = box(f"Post_{x}", (x, 0, 0.5), (0.12, 0.12, 1.0), root)
        assign(post, mats["wood_dark"])
        flat_shade(post)
        convcol(f"Post_{x}", (x, 0, 0.5), (0.16, 0.16, 1.0), root)
    rail = box("Rail", (0, 0, 0.95), (2.6, 0.1, 0.1), root)
    assign(rail, mats["wood"])
    flat_shade(rail)
    return root


# ---------------------------------------------------------------------------
# Desert vegetation — random greybox cacti / scrub (scatter piece).
# ---------------------------------------------------------------------------

# Town footprint (Godot XZ ≈ Blender X/Y after layout) inflated keep-out in metres.
TOWN_KEEP_OUT = {
    "x_min": -33.0,
    "x_max": 24.0,
    "z_min": -42.0,
    "z_max": 40.0,
    "margin": 5.0,
}
SCATTER_COUNT = 160
SCATTER_RADIUS_MAX = 220.0
SCATTER_SEED = 1881


def _in_keep_out(x: float, z: float) -> bool:
    m = TOWN_KEEP_OUT["margin"]
    return (
        TOWN_KEEP_OUT["x_min"] - m <= x <= TOWN_KEEP_OUT["x_max"] + m
        and TOWN_KEEP_OUT["z_min"] - m <= z <= TOWN_KEEP_OUT["z_max"] + m
    )


def _plant_saguaro(parent, mats, rng, name):
    """Tall column cactus with 0–2 arms; height varies."""
    h = rng.uniform(1.8, 4.8)
    r = rng.uniform(0.18, 0.32)
    trunk = cyl(f"{name}_Trunk", (0, 0, 0), (0, 0, h), r, r * 0.92, 6, parent)
    assign(trunk, mats["cactus"])
    flat_shade(trunk)
    arms = rng.randint(0, 2)
    for i in range(arms):
        side = 1.0 if i % 2 == 0 else -1.0
        ah = rng.uniform(0.6, 1.4)
        attach_z = rng.uniform(h * 0.35, h * 0.7)
        arm = cyl(
            f"{name}_Arm{i}",
            (side * r * 0.2, 0, attach_z),
            (side * (r + rng.uniform(0.35, 0.7)), 0, attach_z + ah * 0.15),
            r * 0.7, r * 0.55, 5, parent,
        )
        assign(arm, mats["cactus_dark"])
        flat_shade(arm)
        tip = cyl(
            f"{name}_Tip{i}",
            (side * (r + rng.uniform(0.35, 0.7)), 0, attach_z + ah * 0.15),
            (side * (r + rng.uniform(0.35, 0.7)), 0, attach_z + ah),
            r * 0.55, r * 0.5, 5, parent,
        )
        assign(tip, mats["cactus"])
        flat_shade(tip)


def _plant_barrel(parent, mats, rng, name):
    h = rng.uniform(0.5, 1.3)
    r = rng.uniform(0.28, 0.55)
    body = cyl(f"{name}_Body", (0, 0, 0), (0, 0, h), r, r * 0.85, 8, parent)
    assign(body, mats["cactus"])
    flat_shade(body)


def _plant_opuntia(parent, mats, rng, name):
    """Prickly-pear: stacked flat pads."""
    pads = rng.randint(2, 5)
    z = 0.15
    for i in range(pads):
        w = rng.uniform(0.35, 0.7)
        t = rng.uniform(0.08, 0.14)
        h = rng.uniform(0.35, 0.6)
        x = rng.uniform(-0.15, 0.15)
        y = rng.uniform(-0.1, 0.1)
        pad = box(f"{name}_Pad{i}", (x, y, z + h * 0.5), (w, t, h), parent)
        assign(pad, mats["cactus"] if i % 2 == 0 else mats["cactus_dark"])
        flat_shade(pad)
        z += h * rng.uniform(0.55, 0.85)


def _plant_organ(parent, mats, rng, name):
    """Organ-pipe: several thin columns."""
    n = rng.randint(3, 6)
    for i in range(n):
        ang = (i / n) * math.tau + rng.uniform(-0.2, 0.2)
        rad = rng.uniform(0.12, 0.35)
        h = rng.uniform(1.2, 3.2)
        r = rng.uniform(0.08, 0.16)
        x, y = math.cos(ang) * rad, math.sin(ang) * rad
        col = cyl(f"{name}_Col{i}", (x, y, 0), (x, y, h), r, r * 0.9, 5, parent)
        assign(col, mats["cactus"] if i % 2 == 0 else mats["cactus_dark"])
        flat_shade(col)


def _plant_scrub(parent, mats, rng, name):
    """Low desert scrub / sagebrush cluster."""
    clumps = rng.randint(3, 7)
    for i in range(clumps):
        x = rng.uniform(-0.4, 0.4)
        y = rng.uniform(-0.4, 0.4)
        h = rng.uniform(0.25, 0.7)
        w = rng.uniform(0.2, 0.45)
        bush = box(f"{name}_Clump{i}", (x, y, h * 0.5), (w, w, h), parent)
        assign(bush, mats["scrub"] if i % 2 == 0 else mats["scrub_dry"])
        flat_shade(bush)


def _plant_yucca(parent, mats, rng, name):
    """Yucca / agave: short trunk + radiating leaf blades."""
    trunk_h = rng.uniform(0.15, 0.45)
    trunk = cyl(f"{name}_Trunk", (0, 0, 0), (0, 0, trunk_h), 0.08, 0.1, 5, parent)
    assign(trunk, mats["scrub_dry"])
    flat_shade(trunk)
    blades = rng.randint(5, 9)
    for i in range(blades):
        ang = (i / blades) * math.tau
        length = rng.uniform(0.5, 1.1)
        tip_x = math.cos(ang) * length
        tip_y = math.sin(ang) * length
        tip_z = trunk_h + rng.uniform(0.15, 0.55)
        blade = box(
            f"{name}_Blade{i}",
            (tip_x * 0.5, tip_y * 0.5, (trunk_h + tip_z) * 0.5),
            (0.06, length, 0.04),
            parent,
        )
        # Approximate radial orientation with a flat blade along length in XY.
        blade.rotation_euler = (0.0, 0.0, ang)
        assign(blade, mats["yucca"])
        flat_shade(blade)


def _plant_deadwood(parent, mats, rng, name):
    sticks = rng.randint(2, 4)
    for i in range(sticks):
        ang = rng.uniform(0, math.tau)
        length = rng.uniform(0.4, 1.0)
        x2 = math.cos(ang) * length * 0.5
        y2 = math.sin(ang) * length * 0.5
        stick = cyl(
            f"{name}_Stick{i}",
            (0, 0, rng.uniform(0.05, 0.2)),
            (x2, y2, rng.uniform(0.3, 0.8)),
            0.03, 0.02, 4, parent,
        )
        assign(stick, mats["scrub_dry"])
        flat_shade(stick)


_PLANT_KINDS = (
    (_plant_saguaro, 0.22),
    (_plant_barrel, 0.14),
    (_plant_opuntia, 0.16),
    (_plant_organ, 0.10),
    (_plant_scrub, 0.22),
    (_plant_yucca, 0.10),
    (_plant_deadwood, 0.06),
)


def _pick_plant(rng):
    roll = rng.random()
    acc = 0.0
    for fn, weight in _PLANT_KINDS:
        acc += weight
        if roll <= acc:
            return fn
    return _plant_scrub


def build_env_desert_scatter(mats):
    """Seeded random desert vegetation outside a 50 m keep-out around town."""
    root = empty("env_desert_scatter")
    rng = random.Random(SCATTER_SEED)
    placed = 0
    attempts = 0
    max_attempts = SCATTER_COUNT * 40
    while placed < SCATTER_COUNT and attempts < max_attempts:
        attempts += 1
        # Uniform in a disc, reject keep-out (starts ~50 m from structures).
        rad = math.sqrt(rng.uniform(0.0, 1.0)) * SCATTER_RADIUS_MAX
        ang = rng.uniform(0.0, math.tau)
        # Blender XY → Godot XZ after Y-up export (X stays X, Y → -Z).
        x = math.cos(ang) * rad
        y = math.sin(ang) * rad
        godot_z = -y
        if _in_keep_out(x, godot_z):
            continue
        plant = empty(f"Plant_{placed:03d}", root)
        # Slight negative Blender Z buries feet into terrain (top ≈ +0.12 Godot Y).
        plant.location = Vector((x, y, -0.08))
        plant.rotation_euler = (0.0, 0.0, rng.uniform(0.0, math.tau))
        scale = rng.uniform(0.75, 1.35)
        plant.scale = Vector((scale, scale, scale))
        _pick_plant(rng)(plant, mats, rng, f"P{placed:03d}")
        placed += 1
    print(f"scatter: placed {placed} plants (attempts={attempts})")
    return root


PIECES = [
    ("env_street_ground", build_env_street_ground),
    ("env_terrain", build_env_terrain),
    ("env_desert_scatter", build_env_desert_scatter),
    ("bld_saloon", build_bld_saloon),
    ("bld_hotel", build_bld_hotel),
    ("bld_general_store", build_bld_general_store),
    ("bld_bank", build_bld_bank),
    ("bld_newspaper", build_bld_newspaper),
    ("bld_jail", build_bld_jail),
    ("bld_church", build_bld_church),
    ("bld_depot", build_bld_depot),
    ("env_boardwalk_4m", build_env_boardwalk_4m),
    ("env_awning_post", build_env_awning_post),
    ("env_rail_track_8m", build_env_rail_track_8m),
    ("env_cattle_fence_4m", build_env_cattle_fence_4m),
    ("prp_trough", build_prp_trough),
    ("prp_barrels", build_prp_barrels),
    ("prp_hitching_rail", build_prp_hitching_rail),
    ("prp_cow", build_prp_cow),
]


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


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    clear_scene()
    setup_world()
    mats = make_mats()

    roots = []
    # Park each kit piece along +X so the .blend is browsable.
    for i, (name, builder) in enumerate(PIECES):
        root = builder(mats)
        root.name = name
        root.location = Vector((i * 20.0, 0.0, 0.0))
        roots.append((name, root))
        tris = sum(count_tris(m) for m in _collect_meshes(root) if "-convcolonly" not in m.name)
        print(f"built {name}: tris≈{tris} (excl. colliders)")

    purge_unused()
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print(f"saved {OUT_BLEND}")

    # Export each piece from the origin so Godot instances sit correctly.
    for name, root in roots:
        home = root.location.copy()
        root.location = Vector((0.0, 0.0, 0.0))
        bpy.context.view_layer.update()
        glb = os.path.join(OUT_DIR, f"{name}.glb")
        export_glb(root, glb)
        root.location = home
        print(f"exported {glb}")

    total = 0
    for _name, root in roots:
        for m in _collect_meshes(root):
            if "-convcolonly" not in m.name:
                total += count_tris(m)
    print(f"BUILD_OK total_visible_tris≈{total}")


main()
