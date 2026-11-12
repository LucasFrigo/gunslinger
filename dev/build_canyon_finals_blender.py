"""Build the Canyon finals inside canyon.blend (headless). Design: docs/design/scenarios/canyon.md.

Opens nothing itself: run it with canyon.blend loaded. It rebuilds one asset group under the
`canyon` root and saves the .blend; export with dev/unwrap_per_glb_blender.py afterwards.

    --part cliffs   the hero (sheet B "Cliffs"): deletes the 62 greybox cliff visuals on the first
                    run, then deletes and rebuilds `CanyonCliffs` as four merged objects, one per
                    material (Cliffs_Rock, Cliffs_RockDark, Cliffs_CapDark, Cliffs_Cap). The 62
                    `-convcolonly` proxies are never touched. Also writes the six rock and ground
                    colours (sheet A, Palette; every part does).
    --part cover    sheet B "Cover rocks": deletes the 12 greybox cover visuals (`Cover*`, `*Chip`)
                    on the first run, then rebuilds `CanyonCover` as `Cover_CapDark` (bodies) and
                    `Cover_Cap` (lids). Each rock is a seeded fit of two tiers and a tilted lid inside
                    its untouched proxy, every lane-visible face within 0.15 m of it.
    --part floor    sheet B "Floor": deletes the greybox `Floor` visual, then rebuilds `CanyonFloor`
                    as `Floor_Sand`: one plane at z 0 with a notched rim edge, sand banks, and bedrock
                    steps. `Floor-convcolonly` is never touched; banks and steps have no collision.
    --part rim      sheet B "Rim": deletes the 12 greybox rim visuals (`*Face`, `*Lip*`) on the first
                    run, then rebuilds `CanyonRim` as `Rim_Rock` (south and east faces), `Rim_RockDark`
                    (north and west), `Rim_CapDark` (the band at -6.0 to -7.25) and `Rim_Cap` (the
                    eight lip stones). The faces are stacked strata over the butte's plan, their top
                    following the floor's notched edge 8 cm under its lip, stepping out in two ledges
                    to a skirt of 35 degree wedges on the plain at z -24. Collision follows the
                    faces: the four greybox face proxies move onto the upper drop, behind its faces,
                    and boxes flush with the strata that step out (U1, the band, both ledges, M1,
                    L1) are added (RIM_PX). The four `Rim*` walls and eight lip stones are never
                    touched.
    --part horizon  sheet B "Horizon": deletes the greybox horizon (`Desert`, `Mesa0`-`7` and their
                    caps, the 110 `Plant###` empties and their 289 parts) on the first run, then
                    rebuilds `CanyonHorizon`: `Horizon_Desert` (the plain, one face at z -24), the
                    backdrop butte (its field one flat face, its cap and shoulders broken into steps,
                    joints, and slopes beyond it) and the far mesas merged per material
                    (`Horizon_CapDark` the butte's violet faces, `Horizon_RockDark` its faces the sun never reaches,
                    `Horizon_Rock` the mesa bodies, `Horizon_Cap` the caps), and Main Street's final
                    plant kinds read from main_street.blend (never saved): rigid cacti merged into
                    `Horizon_Cactus` and `Horizon_CactusDark`, every swaying part its own plant's
                    mesh (`Horizon_Plant##_<part>`) with its origin at that plant's base. No collision.

Every wall is a set of closed prisms (slabs, blocks, wedges, pillars) placed by rule and seeded by
segment index, joined by one exact self-union per wall, then cut by its joint boxes. The union
deletes every buried face; this script then deletes what lies under the floor (z < 0). A fill under
the wall slabs closes the tunnels there; the walls' outer faces at x +/-15.5 stay, over the rim.
Never re-run dev/build_canyon_blender.py: it wipes the finals.

Run:
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b assets/models/scenarios/canyon/canyon.blend --python dev/build_canyon_finals_blender.py -- --part cliffs  (or cover, floor, rim, horizon)
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map canyon --relayout
"""
from __future__ import annotations

import math
import os
import random
import re
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_uv  # noqa: E402
from blender_kit import count_tris, empty, flat_shade, link, mesh_from_bm  # noqa: E402

ROOT_NAME = "canyon"
GROUP = "CanyonCliffs"

# Sheet A, Palette: Blender Base Color is linear. Roughness 0.9, metallic 0 (rule 23).
PALETTE = {
    "M_Rock": (0.694, 0.063, 0.024),  # vermilion #D9472B: west cliff
    "M_RockDark": (0.888, 0.381, 0.352),  # pink cliff #F2A6A0: east cliff
    "M_CapDark": (0.209, 0.105, 0.462),  # band violet #7E5BB5
    "M_Cap": (0.807, 0.723, 0.552),  # bone #E8DDC4 (Main Street's)
    # Main Street's desert dirt, the ground its street stands on: the decided street dirt (0.72,
    # 0.55, 0.32) draws white at noon on the floor (sheet H, Floor). Equal to M_SandFar.
    "M_Sand": (0.48, 0.36, 0.22),
    "M_SandFar": (0.48, 0.36, 0.22),  # Main Street's desert dirt
}

# The 62 greybox cliff visuals (sheet B). Their proxies keep these names plus `-convcolonly`.
GREYBOX = (
    [f"WestTalus{i}" for i in range(8)] + [f"WestWall{i}" for i in range(8)]
    + [f"WestCap{i}" for i in (0, 2, 4, 6)] + ["WestTooth1", "WestTooth7"]
    + [f"WestRubble{i}" for i in (0, 1, 2, 3, 5, 6, 7)] + ["WestBack"]
    + [f"EastTalus{i}" for i in range(8)] + [f"EastWall{i}" for i in range(8)]
    + [f"EastCap{i}" for i in (0, 2, 4, 6)] + ["EastTooth1", "EastTooth4", "EastTooth7"]
    + [f"EastRubble{i}" for i in range(8)] + ["EastBack"]
)

# Shot corridor and spawn pads (Blender), as in build_canyon_blender.py.
LANE = (-1.6, 1.6, -12.0, 12.0, 0.9, 1.9)
PADS = ((-1.5, 1.5, -12.5, -9.5, 0.05, 2.2), (-1.5, 1.5, 9.5, 12.5, 0.05, 2.2))

GRID = 0.25
X_BACK = 15.5  # every wall piece stops here, inside the butte's side faces (x +/-15.92)
Z_UNDER = -0.25  # pieces start under the floor; the build cuts everything below z 0
TAN35 = math.tan(math.radians(35.0))
SEED = 1873

# Bands (sheet A): the same heights on both walls.
LOWER_Z0, LOWER_Z1 = 2.5, 7.0
BAND_Z0, BAND_Z1 = 7.0, 8.25
# Lower body layers from 2.5 to 7.0 m, bottom up (0.75 to 1.5 m, F15); a segment may move one line
# by 0.25. Thick "saw" slabs carry the turned planes (a sawtooth plan) and a chamfered, lit top;
# thin straight "ledge" slabs sit back behind them. Where a segment's proxy window cannot hold that,
# the second pattern stands the ledges proud. Tried in order: (kinds, west, east, ledges sit back).
LOWER_PATTERNS = (
    (("saw", "ledge", "saw", "ledge"), (1.5, 0.75, 1.25, 1.0), (1.25, 1.0, 1.5, 0.75), True),
    (("saw", "ledge", "saw", "ledge", "saw"), (1.0, 0.75, 1.25, 0.75, 0.75), (1.25, 0.75, 1.0, 0.75, 0.75), False),
)
UPPER_SEQ = {-1: (1.5, 1.25, 1.5, 1.25, 1.5), 1: (1.25, 1.5, 1.25, 1.5, 1.25)}
# Skyline tops per segment index, both walls (sheet B: 11.75 to 17.5; neighbours >= 0.6 apart).
# Proxy tops: 13.99 (cap), 11.77, 17.54 (cap), 15.99, 14.09 (cap), 12.07, 16.12 (cap), 16.09.
TOPS = (14.0, 11.75, 17.5, 16.0, 14.0, 12.0, 16.25, 15.5)
# One wear accent per segment (sheet B, detail 9), west then east.
WEAR = {
    -1: ("chip", "fallen", "skyjoint", "undercut", "lean", "chip", "fallen", "undercut"),
    1: ("fallen", "chip", "lean", "skyjoint", "undercut", "fallen", "chip", "skyjoint"),
}
# Extra pillars (F19): one per segment except this one (it holds EastTooth7, behind the enemy).
NO_PILLAR = {(1, 7)}

MAT_BODY, MAT_BAND, MAT_BONE = 0, 1, 2
LEDGE_BACK = [True]  # set per segment from its lower pattern
# Rule 4's largest step (sheet: 1.2); 1.25 lets a 0.75 m tooth meet a ledge 0.5 m off its face.
MAX_STEP = 1.25
# Slack on the proxy window (0.5 proud, 1.0 inside): the grid lands up to 0.125 m off a proxy face.
WINDOW_TOL = 0.05


def g(v: float) -> float:
    """Snap to the 0.25 m grid."""
    return round(v / GRID) * GRID


# --------------------------------------------------------------------------------------
# Scene data
# --------------------------------------------------------------------------------------

def proxy_box(name: str):
    """World box (x0, x1, y0, y1, z0, z1) of a proxy, or None."""
    obj = bpy.data.objects.get(name + "-convcolonly")
    if obj is None:
        return None
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return (min(p.x for p in pts), max(p.x for p in pts), min(p.y for p in pts),
            max(p.y for p in pts), min(p.z for p in pts), max(p.z for p in pts))


def front(box, s: int) -> float:
    """The face of a box that looks at the lane: west (s -1) its max x, east its min x."""
    return box[1] if s < 0 else box[0]


def set_palette() -> None:
    for name, rgb in PALETTE.items():
        m = bpy.data.materials.get(name)
        if m is None:
            raise RuntimeError(f"material {name} missing from canyon.blend")
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.9
        bsdf.inputs["Metallic"].default_value = 0.0
        m.diffuse_color = (*rgb, 1.0)
        m.roughness = 0.9
        m.metallic = 0.0


# --------------------------------------------------------------------------------------
# Geometry kernel: closed prisms in one bmesh per wall
# --------------------------------------------------------------------------------------

def _area(pts) -> float:
    return 0.5 * sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
                     for i in range(len(pts)))


def _clean(pts, flags):
    """Drop repeated and collinear points. flags[i] belongs to edge pts[i] -> pts[i + 1]."""
    out_p, out_f = list(pts), list(flags)
    changed = True
    while changed and len(out_p) > 3:
        changed = False
        n = len(out_p)
        for i in range(n):
            a, b, c = out_p[i - 1], out_p[i], out_p[(i + 1) % n]
            if math.dist(a, b) < 1e-6:
                del out_p[i]
                del out_f[i]
                changed = True
                break
            cross = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])
            if abs(cross) < 1e-9 and (b[0] - a[0]) * (c[0] - b[0]) + (b[1] - a[1]) * (c[1] - b[1]) > 0:
                # b lies on a straight run: merge its two edges, keep the earlier edge's flag.
                del out_p[i]
                del out_f[i]
                changed = True
                break
    return out_p, out_f


def ccw(pts, flags=None):
    flags = list(flags) if flags is not None else [False] * len(pts)
    pts = list(pts)
    pts, flags = _clean(pts, flags)
    if _area(pts) < 0:
        n = len(pts)
        rp = pts[::-1]
        # Reversed edge rp[i] -> rp[i + 1] is the old edge (n - 2 - i) % n.
        rf = [flags[(n - 2 - i) % n] for i in range(n)]
        return rp, rf
    return pts, flags


def offset_polygon(pts, offs):
    """Moves each edge of a CCW polygon inward by offs[i]; corners are mitred."""
    n = len(pts)
    lines = []
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy)
        tx, ty = dx / ln, dy / ln
        nx, ny = -ty, tx  # inward (left) normal
        lines.append(((a[0] + nx * offs[i], a[1] + ny * offs[i]), (tx, ty)))
    out = []
    for i in range(n):
        (p0, d0), (p1, d1) = lines[i - 1], lines[i]
        den = d0[0] * d1[1] - d0[1] * d1[0]
        if abs(den) < 1e-9:
            out.append(p1)
            continue
        t = ((p1[0] - p0[0]) * d1[1] - (p1[1] - p0[1]) * d1[0]) / den
        out.append((p0[0] + d0[0] * t, p0[1] + d0[1] * t))
    return out


def _simple(pts) -> bool:
    """No two non-neighbouring edges cross."""
    n = len(pts)

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        for j in range(i + 2, n):
            if i == 0 and j == n - 1:
                continue
            c, d = pts[j], pts[(j + 1) % n]
            d1, d2 = cross(c, d, a), cross(c, d, b)
            d3, d4 = cross(a, b, c), cross(a, b, d)
            if ((d1 > 1e-9 and d2 < -1e-9) or (d1 < -1e-9 and d2 > 1e-9)) and \
                    ((d3 > 1e-9 and d4 < -1e-9) or (d3 < -1e-9 and d4 > 1e-9)):
                return False
    return True


class Wall:
    """Collects one wall's closed shells and cut boxes, with a material index per face."""

    def __init__(self, s: int):
        self.s = s
        self.bm = bmesh.new()
        self.cuts = bmesh.new()
        self.pieces = 0

    def _shell(self, bm, rings, mat, xform):
        verts = []
        for ring in rings:
            row = []
            for p in ring:
                v = Vector(p)
                if xform is not None:
                    v = xform @ v
                row.append(bm.verts.new(v))
            verts.append(row)
        n = len(verts[0])
        faces = [bm.faces.new(list(reversed(verts[0]))), bm.faces.new(verts[-1])]
        for lo, hi in zip(verts[:-1], verts[1:]):
            for i in range(n):
                j = (i + 1) % n
                faces.append(bm.faces.new((lo[i], lo[j], hi[j], hi[i])))
        for f in faces:
            f.material_index = mat
        self.pieces += 1

    def prism(self, plan, z0, z1, mat, chamfer=0.0, chamfer_edges=None, xform=None, cut=False):
        """Vertical prism over a plan polygon. chamfer_edges: per-edge flags for a 45 degree cut
        of `chamfer` metres along the top of those edges."""
        pts, flags = ccw(plan, chamfer_edges)
        if not _simple(pts):
            raise RuntimeError("self-intersecting plan %s" % (pts,))
        rings = [[(x, y, z0) for x, y in pts]]
        if chamfer > 0 and any(flags):
            top = offset_polygon(pts, [chamfer if f else 0.0 for f in flags])
            if not _simple(top) or _area(top) <= 0:
                raise RuntimeError("chamfer folds plan %s" % (pts,))
            rings.append([(x, y, z1 - chamfer) for x, y in pts])
            rings.append([(x, y, z1) for x, y in top])
        else:
            rings.append([(x, y, z1) for x, y in pts])
        self._shell(self.cuts if cut else self.bm, rings, mat, xform)

    def profile(self, loop_xz, y0, y1, mat, xform=None):
        """A prism along Y over an (x, z) profile: wedges."""
        a = [(x, y0, z) for x, z in loop_xz]
        b = [(x, y1, z) for x, z in loop_xz]
        self._shell(self.bm, [a, b], mat, xform)

    def box_cut(self, corners_xy, z0, z1):
        self.prism(corners_xy, z0, z1, 0, cut=True)


def tilt(pivot, axis: str, deg: float) -> Matrix:
    p = Vector(pivot)
    return Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-p)


def rect(x0, x1, y0, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def cut_corners(pts, idxs, c):
    """Replaces each corner in idxs by a 45 degree cut of c metres along both edges."""
    out = []
    n = len(pts)
    for i, p in enumerate(pts):
        if i not in idxs:
            out.append(p)
            continue
        a, b = pts[i - 1], pts[(i + 1) % n]
        la, lb = math.dist(a, p), math.dist(b, p)
        out.append((p[0] + (a[0] - p[0]) * c / la, p[1] + (a[1] - p[1]) * c / la))
        out.append((p[0] + (b[0] - p[0]) * c / lb, p[1] + (b[1] - p[1]) * c / lb))
    return out


# --------------------------------------------------------------------------------------
# Segment layout
# --------------------------------------------------------------------------------------

class Seg:
    """One cliff segment: proxies, snapped references, and the seeded choices."""

    def __init__(self, s: int, i: int):
        self.s, self.i = s, i
        tag = "West" if s < 0 else "East"
        self.tag = f"{tag}{i}"
        self.talus = proxy_box(f"{tag}Talus{i}")
        self.wall = proxy_box(f"{tag}Wall{i}")
        self.cap = proxy_box(f"{tag}Cap{i}")
        self.tooth = proxy_box(f"{tag}Tooth{i}")
        self.rubble = proxy_box(f"{tag}Rubble{i}")
        self.rng = random.Random(SEED + (0 if s < 0 else 100) + i)
        self.xf = front(self.wall, s)
        self.xfg = g(self.xf)
        self.eps = s * (self.xf - self.xfg)  # true proudness = lattice proudness + eps
        self.toe = front(self.talus, s)
        self.toeg = g(self.toe)
        self.ya, self.yb = g(self.wall[2]), g(self.wall[3])
        self.ta, self.tb = g(self.talus[2]), g(self.talus[3])
        self.ht = self.talus[5]
        self.htg = g(self.ht)
        self.top = TOPS[i]
        self.wear = WEAR[s][i]

    def x(self, p: float) -> float:
        """World x of a face p metres proud of the (snapped) wall front."""
        return self.xfg - self.s * p

    def xd(self, d: float) -> float:
        """World x d metres into the rock from the (snapped) talus toe."""
        return self.toeg + self.s * d


def sawtooth(seg: Seg, A: float, dy: float, teeth: int, first_flat: float):
    """Lower body plan line as (y, P): main planes rising from -A to 0 toward +Y (turned to
    the player end), each followed by a return that faces +Y."""
    pts = [(seg.ya, -A)]
    y = seg.ya + first_flat
    if first_flat > 0:
        pts.append((y, -A))
    for k in range(teeth):
        y += dy
        pts.append((y, 0.0))
        if k < teeth - 1 or y < seg.yb - 1e-6:
            pts.append((y, -A))
    if pts[-1][0] < seg.yb - 1e-6:
        pts.append((seg.yb, -A))
    return pts


def flutes(seg: Seg):
    """Upper body plan line: a straight front with vertical flutes, ridges every 1.0 m and
    valleys 0.25 m deep between them (faces about 27 degrees off the wall)."""
    pts = []
    y = seg.ya
    k = 0
    while y <= seg.yb + 1e-6:
        pts.append((y, 0.0 if k % 2 == 0 else -0.25))
        y += 0.5
        k += 1
    return pts


def clip_line(pts, y0, y1):
    """Clip a (y, P) line to [y0, y1], interpolating on the cut segments."""
    out = []
    for (ya, pa), (yb, pb) in zip(pts[:-1], pts[1:]):
        if yb < y0 - 1e-9 or ya > y1 + 1e-9:
            continue
        if ya < y0 < yb:
            out.append((y0, pa + (pb - pa) * (y0 - ya) / (yb - ya)))
        elif y0 - 1e-9 <= ya <= y1 + 1e-9:
            out.append((ya, pa))
        if ya < y1 < yb:
            out.append((y1, pa + (pb - pa) * (y1 - ya) / (yb - ya)))
    last = pts[-1]
    if y0 - 1e-9 <= last[0] <= y1 + 1e-9:
        out.append(last)
    dedup = []
    for p in out:
        if not dedup or abs(p[0] - dedup[-1][0]) > 1e-9 or abs(p[1] - dedup[-1][1]) > 1e-9:
            dedup.append(p)
    return dedup


def slab_plan(seg: Seg, line, o: float, y0=None, y1=None):
    """Closed plan of a slab whose front follows `line` shifted o metres proud, back at X_BACK.
    Returns (points, front-edge flags)."""
    if y0 is not None or y1 is not None:
        line = clip_line(line, seg.ya if y0 is None else y0, seg.yb if y1 is None else y1)
    fr = [(seg.x(o + P), y) for y, P in line]
    xb = X_BACK * seg.s
    pts = fr + [(xb, fr[-1][1]), (xb, fr[0][1])]
    flags = [True] * (len(fr) - 1) + [False, False, False]
    return pts, flags


def split_heights(seq, total):
    """Slabs 0.75 to 1.5 m from `seq` that add up to `total` (grid steps)."""
    out = []
    left = total
    for h in seq * 3:
        if left <= 1e-6:
            break
        if left - h >= 0.75 - 1e-6 or abs(left - h) < 1e-6:
            out.append(h)
            left -= h
        else:
            break
    if left > 1e-6:
        if 0.75 - 1e-6 <= left <= 1.5 + 1e-6:
            out.append(left)
        else:
            rest = left + (out.pop() if out else 0.0)
            n = max(1, math.ceil(rest / 1.5 - 1e-6))
            for k in range(n - 1):
                h = g(rest / (n - k))
                out.append(h)
                rest -= h
            out.append(rest)
    for h in out:
        if not (0.75 - 1e-6 <= h <= 1.5 + 1e-6):
            raise RuntimeError("slab height %.2f out of range in %s" % (h, out))
    return out


class Layer:
    """One stratum of a segment: its plan shape (P range of its front line) and height."""

    def __init__(self, kind, z0, z1, lo=0.0):
        self.kind, self.z0, self.z1, self.lo = kind, z0, z1, lo  # lo: the front line's deepest P


def windows(seg: Seg, layer: Layer):
    """(lowest, highest) true proudness allowed for a layer: 0.5 proud to 1.0 inside every proxy
    its height crosses (rule 5 listing), 0.15 below 2.2 m for the first slab."""
    tol = WINDOW_TOL
    lo, hi = -1.0 - tol, 0.5 + tol
    if layer.kind == "saw" and layer.z0 < 2.2 and seg.htg < 2.2:
        hi = 0.15 + 1e-6  # seen between the talus top and 2.2 m
    if seg.cap is not None and layer.z1 > seg.wall[5] + 1e-6:
        fc = seg.s * (seg.xf - front(seg.cap, seg.s))  # cap proxy front, proud of the wall front
        if layer.z0 >= seg.wall[5] - 1e-6:
            lo, hi = fc - 1.0 - tol, fc + 0.5 + tol
        else:
            lo, hi = max(lo, fc - 1.0 - tol), min(hi, fc + 0.5 + tol)
    return lo, hi


def step_ok(a: Layer, pa: float, b: Layer, pb: float) -> bool:
    """Every slab steps 0.3 to 1.2 m from the one below (rule 4), measured over its whole front."""
    if b.kind == "cap":
        return 0.5 - 1e-6 <= pb - pa <= 0.75 + 1e-6  # the cap overhangs the ridges 0.5 to 0.75
    if a.kind == b.kind and abs(a.lo - b.lo) < 1e-6:
        return 0.5 - 1e-6 <= abs(pb - pa) <= 1.0 + 1e-6
    a_lo, a_hi, b_lo, b_hi = pa + a.lo, pa, pb + b.lo, pb
    if b.kind == "band":
        return 0.3 - 1e-6 <= b_lo - a_hi <= 0.5 + 1e-6 and b_hi - a_lo <= MAX_STEP + 1e-6
    proud = b_lo >= a_hi + 0.3 - 1e-6
    back = b_hi <= a_lo - 0.3 + 1e-6
    if LEDGE_BACK[0]:
        if b.kind == "ledge":
            proud = False  # thin ledges sit back: the turned slab under them shows its lit top
        if a.kind == "ledge":
            back = False
    return (proud or back) and max(b_hi - a_lo, a_hi - b_lo) <= MAX_STEP + 1e-6


def solve_offsets(seg: Seg, layers: list):
    """Lattice proudness for every layer, bottom up, by a seeded depth-first search."""
    e = seg.eps
    lat = [round(-1.25 + 0.25 * k, 2) for k in range(9)]  # -1.25 .. 0.75
    rng = seg.rng
    wins = [windows(seg, L) for L in layers]
    out = []

    def dfs(seq):
        if out:
            return
        k = len(seq)
        if k == len(layers):
            out.append(list(seq))
            return
        L = layers[k]
        lo, hi = wins[k]
        cands = [p for p in lat if p + L.lo + e >= lo and p + e <= hi
                 and (k == 0 or step_ok(layers[k - 1], seq[-1], L, p))]
        rng.shuffle(cands)
        for p in cands:
            dfs(seq + [p])

    dfs([])
    return out[0] if out else None


# --------------------------------------------------------------------------------------
# Pieces
# --------------------------------------------------------------------------------------

def build_talus(wall: Wall, seg: Seg, counter: list):
    """Apron (F8): chamfered blocks on the talus proxy's front face, one in three a fallen bone
    cap block, and a 35 degree wedge behind them up to the wall foot."""
    s, rng = seg.s, seg.rng
    allowed = [h for h in (1.5, 1.75, 2.0, 2.25, 2.5)
               if abs(h - seg.ht) <= 0.15 + 1e-6 or (h > seg.ht and seg.ht >= 2.05 and h <= seg.ht + 0.5)]
    if not allowed:
        allowed = [seg.htg]
    length = seg.tb - seg.ta
    widths = []
    left = length
    while left > 1e-6:
        opts = [w for w in (1.0, 1.25, 1.5, 1.75) if abs(left - w) < 1e-6 or left - w >= 1.0 - 1e-6]
        w = rng.choice(opts) if opts else left
        widths.append(w)
        left -= w
    y = seg.ta
    prev_h = None
    for w in widths:
        h = rng.choice([a for a in allowed if a != prev_h] or allowed)
        prev_h = h
        y0, y1 = y, y + w
        y = y1
        d = rng.choice((0.75, 1.0))
        x0, x1 = sorted((seg.xd(0.0), seg.xd(d)))
        plan = rect(x0, x1, y0, y1)
        # Cut the two corners on the lane side (rect order: (x0,y0) (x1,y0) (x1,y1) (x0,y1)).
        lane = (1, 2) if s < 0 else (0, 3)
        plan = cut_corners(plan, lane, 0.25)
        counter[0] += 1
        bone = counter[0] % 3 == 0
        top_ch = rng.random() < 0.5
        flags = None
        if top_ch:
            pts, _ = ccw(plan)
            fx = seg.xd(0.0)
            flags = [abs(pts[k][0] - fx) < 1e-6 and abs(pts[(k + 1) % len(pts)][0] - fx) < 1e-6
                     for k in range(len(pts))]
            plan = pts
        xform = None
        if bone:
            # A fallen cap block leaning back 4 degrees about its bottom front edge.
            xform = tilt((seg.xd(0.0), (y0 + y1) / 2, Z_UNDER), "Y", 4.0 * s)
        wall.prism(plan, Z_UNDER, h, MAT_BONE if bone else MAT_BODY,
                   chamfer=0.25 if top_ch else 0.0, chamfer_edges=flags, xform=xform)
    # The wedge: from just under the blocks' tops, 35 degrees up into the wall foot.
    zw0 = seg.htg - 0.25
    ztop = 2.5 if seg.htg >= 2.0 else 2.25
    dtop = 0.5 + (ztop - zw0) / TAN35
    prof = [(seg.xd(0.5), Z_UNDER), (seg.xd(0.5), zw0), (seg.xd(dtop), ztop),
            (seg.xd(3.5), ztop), (seg.xd(3.5), Z_UNDER)]
    wall.profile(prof, seg.ta, seg.tb, MAT_BODY)
    seg.wedge = (zw0, ztop, dtop)


def fit_layers(seg: Seg, kinds, lower, uppers, back: bool):
    """Seeded tries of tooth size and upper split until solve_offsets finds proudness for every
    layer. Returns (A, dy, teeth, first flat, cap height, upper heights, layers, offsets)."""
    rng = seg.rng
    LEDGE_BACK[0] = back
    for attempt in range(60):
        # A 0.75 m tooth first; a 0.5 m tooth (planes 18 to 22 degrees) where the window is tight.
        A = 0.75 if attempt < 30 else 0.5
        dy = rng.choice((1.75, 2.0)) if A == 0.75 else rng.choice((1.25, 1.5))
        teeth = 2
        free = (seg.yb - seg.ya) - teeth * dy
        if free < -1e-6:
            continue
        need = 0.5 if (seg.i == 0 and free >= 0.5) else 0.0
        first = g(rng.uniform(need, free)) if free > 0 else 0.0
        first = min(max(first, need), free)
        if seg.i == 7 and free - first < 0.5 and free >= 0.5:
            first = free - 0.5
        for cap_h, upper in uppers:
            layers = []
            z = LOWER_Z0
            for k, h in enumerate(lower):
                layers.append(Layer(kinds[k], 1.0 if k == 0 else z, z + h, -A if kinds[k] == "saw" else 0.0))
                z += h
            layers.append(Layer("band", BAND_Z0, BAND_Z1, 0.0))
            z = BAND_Z1
            for h in upper:
                layers.append(Layer("flute", z, z + h, -0.25))
                z += h
            layers.append(Layer("cap", z, seg.top + 0.5, -0.75))
            sol = solve_offsets(seg, layers)
            if sol is not None:
                return A, dy, teeth, first, cap_h, upper, layers, sol
    return None


def build_body(wall: Wall, seg: Seg):
    """Lower body, band, upper body, and cap of one segment."""
    s, rng = seg.s, seg.rng
    # Lower body heights: the pattern's split, one line moved 0.25 on some segments.
    shift = rng.random() < 0.5
    k_shift = rng.randrange(3)
    dz_shift = rng.choice((-0.25, 0.25))
    cap_hs = [h for h in (1.25, 1.5, 1.75, 2.0) if 1.5 <= seg.top - h - BAND_Z1 <= 7.5]
    rng.shuffle(cap_hs)
    seq = UPPER_SEQ[s]
    uppers = []
    for cap_h in cap_hs:
        for rot in range(len(seq)):
            up = split_heights(seq[rot:] + seq[:rot], seg.top - cap_h - BAND_Z1)
            if 2 <= len(up) <= 5:
                uppers.append((cap_h, up))
    # Lower plan: two teeth whose main planes turn 20 to 23 degrees toward the player end (15
    # degrees would lie along the sun's azimuth and never light the east wall), 1.9 to 2.1 m long.
    fit = None
    for kinds, west, east, back in LOWER_PATTERNS:
        lower = list(west if s < 0 else east)
        if shift and 0.75 <= lower[k_shift] + dz_shift <= 1.5 and 0.75 <= lower[k_shift + 1] - dz_shift <= 1.5:
            lower[k_shift] += dz_shift
            lower[k_shift + 1] -= dz_shift
        fit = fit_layers(seg, kinds, lower, uppers, back)
        if fit is not None:
            break
    if fit is None:
        raise RuntimeError(f"{seg.tag}: no offsets fit the proxy window")
    A, dy, teeth, first, cap_h, upper, layers, sol = fit
    cap_base = seg.top - cap_h
    n_lo = len(lower)
    lo_off, band_off, up_off, cap_off = sol[:n_lo], sol[n_lo], sol[n_lo + 1:-1], sol[-1]
    line = sawtooth(seg, A, dy, teeth, first)
    straight = [(seg.ya, 0.0), (seg.yb, 0.0)]
    seg.line, seg.A, seg.lo_off, seg.band_off, seg.up_off, seg.cap_off = line, A, lo_off, band_off, up_off, cap_off
    seg.lower_lines = [line if kinds[k] == "saw" else straight for k in range(n_lo)]
    seg.pattern = "back" if LEDGE_BACK[0] else "proud"
    seg.lower_z, seg.upper_z, seg.cap_base = [], [], cap_base

    def ends(k):
        """Stepped canyon ends: every other slab stops 0.5 short at the open end."""
        if seg.i == 0 and k % 2 == 1:
            return seg.ya + 0.5, None
        if seg.i == 7 and k % 2 == 1:
            return None, seg.yb - 0.5
        return None, None

    def setback(k):
        """The layer above k sits behind all of k's front: k's top shows, so it gets the chamfer."""
        a, b = layers[k], layers[k + 1]
        return b.kind != "cap" and sol[k + 1] <= sol[k] + a.lo - 0.3 + 1e-6

    z = LOWER_Z0
    layer = 0
    for k, h in enumerate(lower):
        z0 = 1.0 if k == 0 else z
        z1 = z + h
        y0, y1 = ends(layer)
        plan, flags = slab_plan(seg, seg.lower_lines[k], lo_off[k], y0, y1)
        # A 45 degree chamfer on the top front edges where the slab above steps in: a lit ledge line.
        ch = 0.25 if setback(k) else 0.0
        wall.prism(plan, z0, z1, MAT_BODY, chamfer=ch, chamfer_edges=flags)
        seg.lower_z.append((z0, z1))
        z = z1
        layer += 1
    y0, y1 = ends(layer)
    plan, flags = slab_plan(seg, straight, band_off, y0, y1)
    wall.prism(plan, BAND_Z0, BAND_Z1, MAT_BAND, chamfer=0.25 if setback(n_lo) else 0.0, chamfer_edges=flags)
    layer += 1
    fl = flutes(seg)
    seg.fl = fl
    z = BAND_Z1
    for k, h in enumerate(upper):
        y0, y1 = ends(layer)
        plan, _ = slab_plan(seg, fl, up_off[k], y0, y1)
        wall.prism(plan, z, z + h, MAT_BODY)
        seg.upper_z.append((z, z + h))
        z += h
        layer += 1
    build_cap(wall, seg)


def build_cap(wall: Wall, seg: Seg):
    """Bone cap (F7): blocks 1.5 to 2.25 m long with sky gaps, each front turned toward the
    player end; one block raised or lowered as the skyline feature."""
    s, rng = seg.s, seg.rng
    ca, cb = seg.ya, seg.yb
    if seg.cap is not None:
        ca, cb = max(ca, g(seg.cap[2] - 0.5)), min(cb, g(seg.cap[3] + 0.5))
    length = cb - ca
    gap = 0.5
    # Two blocks 1.5 to 2.25 m long with one 0.5 m gap; one block when the cap is short.
    firsts = [L for L in (1.5, 1.75, 2.0, 2.25) if 1.5 - 1e-6 <= length - gap - L <= 2.25 + 1e-6]
    if firsts:
        L1 = rng.choice(firsts)
        lens = [L1, length - gap - L1]
    else:
        lens = [length]
    blocks = []
    y = ca
    for L in lens:
        blocks.append((y, y + L))
        y += L + gap
    # The skyline feature: one block 0.5 to 0.75 up or down, inside the proxy window and still
    # 0.6 m or more from both neighbours' tops (sheet A, rule 8).
    limit = (seg.cap[5] if seg.cap is not None else seg.wall[5]) + 0.5
    near = [TOPS[j] for j in (seg.i - 1, seg.i + 1) if 0 <= j < len(TOPS)]
    opts = [seg.top + d for d in (0.5, -0.5, 0.75, -0.75)
            if seg.top + d <= limit + 1e-6 and all(abs(seg.top + d - t) >= 0.6 - 1e-6 for t in near)]
    feature = rng.randrange(len(blocks))
    feature_top = rng.choice(opts) if opts else seg.top
    seg.cap_blocks = []
    for b, (y0, y1) in enumerate(blocks):
        top = seg.top
        if b == feature:
            top = feature_top
        A_c = 0.75 if (y1 - y0) >= 1.75 - 1e-6 else 0.5
        p_hi = seg.cap_off
        fr0, fr1 = seg.x(p_hi - A_c), seg.x(p_hi)
        xb = X_BACK * s
        plan = [(fr0, y0), (fr1, y1), (xb, y1), (xb, y0)]
        chamfer, flags = 0.0, None
        if seg.wear == "chip" and b == (0 if feature != 0 else len(blocks) - 1):
            # A chipped cap corner: the block's south top edge cut 0.5 m at 45 degrees.
            pts, _ = ccw(plan)
            flags = [abs(pts[k][1] - y0) < 1e-6 and abs(pts[(k + 1) % len(pts)][1] - y0) < 1e-6
                     for k in range(len(pts))]
            plan, chamfer = pts, 0.5
        wall.prism(plan, seg.cap_base, top, MAT_BONE, chamfer=chamfer, chamfer_edges=flags)
        seg.cap_blocks.append((y0, y1, top))
    seg.gaps = [(blocks[k][1], blocks[k + 1][0]) for k in range(len(blocks) - 1)]


def _plane_frame(seg: Seg, o: float, ya: float, Pa: float, yb: float, Pb: float):
    a = Vector((seg.x(o + Pa), ya, 0.0))
    b = Vector((seg.x(o + Pb), yb, 0.0))
    t = (b - a).normalized()
    n = Vector((-t.y, t.x, 0.0))
    if n.x * -seg.s < 0:  # point toward the lane
        n = -n
    return a, b, t, n


def joint_box(wall: Wall, seg: Seg, a, t, n, along, width, depth, z0, z1):
    c = a + t * along
    pts = [c - t * (width / 2) - n * depth, c + t * (width / 2) - n * depth,
           c + t * (width / 2) + n * 1.0, c - t * (width / 2) + n * 1.0]
    wall.box_cut([(p.x, p.y) for p in pts], z0, z1)


def frame_at(seg: Seg, line, o: float, y: float):
    """The front edge of a slab (line shifted o proud) that spans y: (point at y, tangent, normal
    toward the lane)."""
    for (ya, Pa), (yb, Pb) in zip(line[:-1], line[1:]):
        if yb - ya > 1e-6 and ya - 1e-6 <= y <= yb + 1e-6:
            a, b, t, n = _plane_frame(seg, o, ya, Pa, yb, Pb)
            return a + (b - a) * ((y - ya) / (yb - ya)), t, n
    return None


def build_joints(wall: Wall, seg: Seg, avoid):
    """Joints (detail 10): two to four vertical notches 0.5 wide and 0.5 deep through one to
    three lower slabs, clear of the returns, pillars, and segment ends."""
    rng = seg.rng
    returns = [y for (y, P), (y2, P2) in zip(seg.line[:-1], seg.line[1:]) if abs(y2 - y) < 1e-6]
    cands = [seg.ya + 0.25 * k for k in range(int((seg.yb - seg.ya) / 0.25) + 1)]
    cands = [y for y in cands if seg.ya + 0.5 <= y <= seg.yb - 0.5
             and all(abs(y - r) > 0.35 for r in returns)]
    rng.shuffle(cands)
    made = 0
    want = rng.choice((2, 3, 4))
    for mid in cands:
        if made >= want:
            break
        # Pillars, fallen blocks, and undercuts block a joint only up to their own tops.
        zmin = max([zt for lo, hi, zt in avoid if lo - 0.35 <= mid <= hi + 0.35] + [0.0])
        ok = [k for k in range(len(seg.lo_off)) if seg.lower_z[k][1] - max(seg.lower_z[k][0], zmin) >= 0.75 - 1e-6]
        if not ok:
            continue
        k0 = rng.choice(ok)
        run = [k for k in range(k0, k0 + 1 + rng.randrange(3)) if k in ok]
        for k in run:
            fr = frame_at(seg, seg.lower_lines[k], seg.lo_off[k], mid)
            if fr is None:
                continue
            c, t, n = fr
            z0, z1 = seg.lower_z[k]
            z0 = max(z0, zmin)
            if k == 0:
                z0 = max(z0, seg.wedge[1] + 0.25)
            pts = [c - t * 0.25 - n * 0.5, c + t * 0.25 - n * 0.5, c + t * 0.25 + n * 1.0, c - t * 0.25 + n * 1.0]
            wall.box_cut([(q.x, q.y) for q in pts], z0, z1)
        avoid.append((mid - 0.25, mid + 0.25, 99.0))
        made += 1
    seg.joints = made


def build_wear(wall: Wall, seg: Seg, avoid):
    s, rng = seg.s, seg.rng
    if seg.wear == "undercut":
        # A recess at the wall's foot, above the wedge, under the second slab.
        z0 = seg.wedge[1]
        z1 = min(seg.lower_z[0][1] - 0.25, z0 + 0.75)
        flat = [(seg.line[k], seg.line[k + 1]) for k in range(len(seg.line) - 1)
                if seg.line[k + 1][0] - seg.line[k][0] >= 1.0 - 1e-6]
        (ya, Pa), (yb, Pb) = max(flat, key=lambda e: e[1][0] - e[0][0])
        a, b, t, n = _plane_frame(seg, seg.lo_off[0], ya, Pa, yb, Pb)
        L = (b - a).length
        width = min(2.0, L - 0.25)
        joint_box(wall, seg, a, t, n, L / 2, width, 0.5, z0, z1)
        mid = (ya + yb) / 2
        avoid.append((mid - width / 2, mid + width / 2, z1 + 0.25))
    elif seg.wear == "skyjoint" and seg.gaps:
        # A joint open to the sky: the cap gap runs down through every upper slab.
        g0, g1 = seg.gaps[0]
        mid = (g0 + g1) / 2
        for k, (z0, z1) in enumerate(seg.upper_z):
            o = seg.up_off[k]
            xa, xb = seg.x(o - 0.5), seg.x(o + 1.0)
            wall.box_cut(rect(min(xa, xb), max(xa, xb), mid - 0.25, mid + 0.25), z0, z1)
    elif seg.wear == "fallen":
        # A fallen bone cap block lying on the wedge at the wall foot.
        zw0, ztop, dtop = seg.wedge
        opts = [g((seg.ta + seg.tb) / 2 + d) for d in (-1.25, -0.75, -0.25, 0.25, 0.75, 1.25)]
        opts = [y for y in opts if not any(a - 0.8 < y < b + 0.8 for a, b, _ in avoid)] or opts
        yc = rng.choice(opts)
        d0 = max(0.75, dtop - 0.75)
        x0, x1 = sorted((seg.xd(d0), seg.xd(d0 + 1.0)))
        zb = min(zw0 + d0 * TAN35, ztop) - 0.15
        plan = cut_corners(rect(x0, x1, yc - 0.625, yc + 0.625), (0, 1, 2, 3), 0.25)
        xform = tilt((seg.xd(d0 + 0.5), yc, zb), "Y", -s * 20.0)
        wall.prism(plan, zb, zb + 0.75, MAT_BONE, xform=xform)
        avoid.append((yc - 0.65, yc + 0.65, zb + 1.25))


def build_pillar(wall: Wall, seg: Seg, avoid):
    """An extra pillar (F19) rising from the talus against the wall: two chamfered blocks, the
    upper inset 0.25, under a bone cap block overhanging 0.25. Inside the talus and wall proxies;
    0.15 m proud of the wall proxy at most."""
    s, rng = seg.s, seg.rng
    w = rng.choice((1.25, 1.5))
    lo = max(seg.ya, seg.ta) + 0.5
    hi = min(seg.yb, seg.tb) - 0.5 - w
    # Prefer a recessed stretch of the lower body (the start of a main plane), then any clear spot.
    cands = [g(y) for y, P in seg.line if P < 0 and lo <= g(y) <= hi]
    cands += [g(lo + (hi - lo) * k / 8.0) for k in rng.sample(range(9), 9)] if hi >= lo else []
    cands = [y for y in cands if not any(a - 0.3 < y + w and y < b + 0.3 for a, b, _ in avoid)]
    if seg.tooth is not None:
        # Keep clear of the tooth standing in front where there is room; else stand behind it.
        clear = [y for y in cands if y + w < seg.tooth[2] - 0.1 or y > seg.tooth[3] + 0.1]
        cands = clear or cands
    if not cands:
        seg.pillar = None
        return
    y0 = cands[0]
    y1 = y0 + w
    d1 = 1.0
    z0 = seg.htg - 0.5
    z1 = g(rng.uniform(3.5, 4.25))
    z2 = min(z1 + rng.choice((1.25, 1.5, 1.75)), 6.0)
    z3 = z2 + rng.choice((0.5, 0.75))
    if z3 > 6.75:
        z3 = 6.75
    xb = seg.xd(3.0)
    x_front = seg.xd(d1)
    inset_side = rng.choice((0, 1))  # 0: the south side steps in, 1: the north side

    def plan(dfront, ya, yb):
        x0, x1 = sorted((seg.xd(dfront), xb))
        lane = (1, 2) if s < 0 else (0, 3)
        return cut_corners(rect(x0, x1, ya, yb), lane, 0.25)

    wall.prism(plan(d1, y0, y1), z0, z1, MAT_BODY)
    ya2, yb2 = (y0 + 0.25, y1) if inset_side == 0 else (y0, y1 - 0.25)
    lean = None
    if seg.wear == "lean":
        # A pillar block leaning 4 degrees toward the lane about its bottom front edge.
        lean = tilt((seg.xd(d1 + 0.25), (ya2 + yb2) / 2, z1), "Y", -s * 4.0)
    wall.prism(plan(d1 + 0.25, ya2, yb2), z1 - 0.01 if lean else z1, z2, MAT_BODY, xform=lean)
    wall.prism(plan(d1, ya2 - (0.25 if inset_side == 0 else 0.0), yb2 + (0.25 if inset_side == 1 else 0.0)),
               z2, z3, MAT_BONE, xform=lean)
    seg.pillar = (y0, y1, x_front, z3)
    avoid.append((y0, y1, z3 + 0.5))


def build_tooth(wall: Wall, seg: Seg):
    """A greybox tooth as a pillar on its own proxy: a block filling the proxy to 2.5 m, a block
    inset 0.25 on the lane and north sides to 4.0 m, a bone cap block to 4.75 m."""
    s = seg.s
    x0, x1, y0, y1 = g(seg.tooth[0]), g(seg.tooth[1]), g(seg.tooth[2]), g(seg.tooth[3])
    corners = (0, 1, 2, 3)
    wall.prism(cut_corners(rect(x0, x1, y0, y1), corners, 0.25), Z_UNDER, 2.5, MAT_BODY)
    xa, xb = (x0, x1 - 0.25) if s < 0 else (x0 + 0.25, x1)
    wall.prism(cut_corners(rect(xa, xb, y0, y1 - 0.25), corners, 0.25), 2.5, 4.0, MAT_BODY)
    wall.prism(cut_corners(rect(x0, x1, y0, y1), corners, 0.25), 4.0, 4.75, MAT_BONE)


def build_rubble(wall: Wall, seg: Seg, counter: list):
    """A rubble stone as a fallen block tilted 12 degrees inside its proxy, sunk 5 cm."""
    b = seg.rubble
    cx, cy = (b[0] + b[1]) / 2, (b[2] + b[3]) / 2
    plan = cut_corners(rect(cx - 0.25, cx + 0.25, cy - 0.15, cy + 0.15), (0, 1, 2, 3), 0.08)
    counter[0] += 1
    mat = MAT_BONE if counter[0] % 3 == 0 else MAT_BODY
    sign = 1.0 if seg.i % 2 else -1.0
    xform = tilt((cx, cy + sign * 0.15, -0.05), "X", sign * 12.0)
    wall.prism(plan, -0.05, 0.25, mat, xform=xform)


def build_fill(wall: Wall, seg: Seg):
    """Fills the tunnel under the wall slabs (z 0 to 1.0, the first slab's foot) from inside the
    talus wedge back to X_BACK, so the walls' ends and outer sides close (sheet H, Cliffs: the
    tunnel fix). Its front stands inside the wedge, so nothing the lane sees moves."""
    x0, x1 = sorted((seg.xd(3.0), X_BACK * seg.s))
    wall.prism(rect(x0, x1, seg.ya, seg.yb), Z_UNDER, 1.0, MAT_BODY)


def build_back(wall: Wall, s: int):
    """The buried back: only strips above the low segments show. Body colour, 12.5 m top."""
    b = proxy_box("WestBack" if s < 0 else "EastBack")
    xin = g(front(b, s))
    x0, x1 = sorted((xin, X_BACK * s))
    plan = rect(x0, x1, g(b[2]), g(b[3]))
    pts, _ = ccw(plan)
    flags = [abs(pts[k][0] - xin) < 1e-6 and abs(pts[(k + 1) % 4][0] - xin) < 1e-6 for k in range(4)]
    wall.prism(pts, Z_UNDER, 12.5, MAT_BODY, chamfer=0.5, chamfer_edges=flags)


# --------------------------------------------------------------------------------------
# Union, cleanup, objects
# --------------------------------------------------------------------------------------

def _bm_object(bm, name, mats):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for m in mats:
        obj.data.materials.append(m)
    return obj


def union_wall(wall: Wall, mats):
    """One exact self-union of all shells, then the joint cuts. Returns a cleaned bmesh."""
    bmesh.ops.recalc_face_normals(wall.bm, faces=wall.bm.faces)
    bmesh.ops.recalc_face_normals(wall.cuts, faces=wall.cuts.faces)
    pos = _bm_object(wall.bm, "_cliff_pos", mats)
    cut = _bm_object(wall.cuts, "_cliff_cut", mats)
    empty_col = bpy.data.collections.new("_cliff_ops")
    m1 = pos.modifiers.new("union", "BOOLEAN")
    m1.operation, m1.solver = "UNION", "EXACT"
    m1.operand_type, m1.collection, m1.use_self = "COLLECTION", empty_col, True
    if len(cut.data.polygons):
        m2 = pos.modifiers.new("joints", "BOOLEAN")
        m2.operation, m2.solver = "DIFFERENCE", "EXACT"
        m2.operand_type, m2.object, m2.use_self = "OBJECT", cut, True
    cut.hide_set(True)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(pos.evaluated_get(dg))
    for o in (pos, cut):
        mesh = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.meshes.remove(mesh)
    bpy.data.collections.remove(empty_col)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    # Under the floor: cut at z 0 and drop everything below (bottoms, buried feet).
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
    # The faces that look out over the drop at x +/-15.5 stay: the rim's faces (part rim) stand
    # under them, and from a rim corner they close the walls' outer sides.
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.05), use_dissolve_boundaries=False,
                             verts=bm.verts, edges=bm.edges, delimit={"MATERIAL"})
    bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges)
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    print(f"  sliver faces split into triangles: {fix_slivers(bm)}")
    return bm


def _degenerate_faces(bm):
    bad = set()
    for tri in bm.calc_loop_triangles():
        a, b, c = (l.vert.co for l in tri)
        if (b - a).cross(c - a).length < 2e-6:
            bad.add(tri[0].face)
    return bad


def fix_slivers(bm):
    """T-junction vertices on an n-gon's outline (where a neighbour's edge ends) make the
    tessellator emit zero-area triangles (saloon.md H, build lesson). Those faces alone are split
    into triangles with the beauty method, which flips the slivers away."""
    bad = _degenerate_faces(bm)
    if bad:
        bmesh.ops.triangulate(bm, faces=list(bad), quad_method="BEAUTY", ngon_method="BEAUTY")
    left = _degenerate_faces(bm)
    if left:
        bmesh.ops.beautify_fill(bm, faces=list(left), edges=list({e for f in left for e in f.edges}))
    return len(bad)


def split_by_material(bm, index):
    out = bm.copy()
    bmesh.ops.delete(out, geom=[f for f in out.faces if f.material_index != index], context="FACES")
    bmesh.ops.delete(out, geom=[v for v in out.verts if not v.link_faces], context="VERTS")
    for f in out.faces:
        f.material_index = 0
    return out


def _collect(root):
    out, stack = [], [root]
    while stack:
        o = stack.pop()
        out.append(o)
        stack.extend(o.children)
    return out


def _hits(box, band) -> bool:
    return not (box[1] <= band[0] or box[0] >= band[1] or box[3] <= band[2] or box[2] >= band[3]
                or box[5] <= band[4] or box[4] >= band[5])


def check_proxies(root) -> int:
    """G5: no proxy may overlap the shot band or a spawn pad."""
    bad = 0
    n = 0
    for o in _collect(root):
        if o.type != "MESH" or "-convcolonly" not in o.name:
            continue
        n += 1
        pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
        box = (min(p.x for p in pts), max(p.x for p in pts), min(p.y for p in pts),
               max(p.y for p in pts), min(p.z for p in pts), max(p.z for p in pts))
        if _hits(box, LANE) or any(_hits(box, p) for p in PADS):
            print(f"  PROXY IN LANE OR PAD: {o.name}")
            bad += 1
    print(f"proxy box test: {n} proxies, {bad} in the shot band or a pad")
    return bad


def build_cliffs():
    root = bpy.data.objects.get(ROOT_NAME)
    if root is None:
        raise RuntimeError("no `canyon` root: open canyon.blend")
    for name in GREYBOX:
        if bpy.data.objects.get(name + "-convcolonly") is None:
            raise RuntimeError(f"proxy {name}-convcolonly is missing")
    removed = 0
    for name in GREYBOX:
        obj = bpy.data.objects.get(name)
        if obj is not None:
            mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if mesh is not None and mesh.users == 0:
                bpy.data.meshes.remove(mesh)
            removed += 1
    old = bpy.data.objects.get(GROUP)
    if old is not None:
        for o in reversed(_collect(old)):
            mesh = o.data if o.type == "MESH" else None
            bpy.data.objects.remove(o, do_unlink=True)
            if mesh is not None and mesh.users == 0:
                bpy.data.meshes.remove(mesh)
    print(f"greybox cliff visuals removed: {removed}")

    mats = {n: bpy.data.materials[n] for n in PALETTE}
    parts = {MAT_BAND: [], MAT_BONE: []}
    body = {}
    report = []
    for s in (-1, 1):
        wall = Wall(s)
        counter = [0]
        rubble_counter = [1 if s > 0 else 0]
        wall_mats = [mats["M_Rock" if s < 0 else "M_RockDark"], mats["M_CapDark"], mats["M_Cap"]]
        segs = [Seg(s, i) for i in range(8)]
        for seg in segs:
            build_talus(wall, seg, counter)
            build_body(wall, seg)
            avoid = []
            if (s, seg.i) not in NO_PILLAR:
                build_pillar(wall, seg, avoid)
            else:
                seg.pillar = None
            build_wear(wall, seg, avoid)
            build_joints(wall, seg, avoid)
            if seg.tooth is not None:
                build_tooth(wall, seg)
            if seg.rubble is not None:
                build_rubble(wall, seg, rubble_counter)
            build_fill(wall, seg)
            report.append(seg)
        build_back(wall, s)
        print(f"{'west' if s < 0 else 'east'}: {wall.pieces} shells, union ...")
        bm = union_wall(wall, wall_mats)
        body[s] = split_by_material(bm, MAT_BODY)
        parts[MAT_BAND].append(split_by_material(bm, MAT_BAND))
        parts[MAT_BONE].append(split_by_material(bm, MAT_BONE))
        bm.free()

    group = empty(GROUP, root)
    group.location = (0.0, 0.0, 0.0)
    out = []
    for name, mat_name, bms in (
        ("Cliffs_Rock", "M_Rock", [body[-1]]),
        ("Cliffs_RockDark", "M_RockDark", [body[1]]),
        ("Cliffs_CapDark", "M_CapDark", parts[MAT_BAND]),
        ("Cliffs_Cap", "M_Cap", parts[MAT_BONE]),
    ):
        me = bpy.data.meshes.new(name)
        merged = bmesh.new()
        for b in bms:
            tmp = bpy.data.meshes.new("_tmp")
            b.to_mesh(tmp)
            merged.from_mesh(tmp)
            bpy.data.meshes.remove(tmp)
            b.free()
        merged.to_mesh(me)
        merged.free()
        obj = bpy.data.objects.new(name, me)
        link(obj, group)
        obj.location = (0.0, 0.0, 0.0)
        obj.rotation_euler = (0.0, 0.0, 0.0)
        obj.data.materials.append(mats[mat_name])
        flat_shade(obj)
        scenery_uv.unwrap_object(obj, scenery_uv.TILING)
        obj["uv_role"] = "tiling"
        out.append(obj)

    for seg in report:
        print("  %-6s talus %.2f->%.2f  A %.2f  lower %s band %+.2f upper %s cap %+.2f  top %.2f  "
              "%s wear %-8s pillar %s joints %d" % (
                  seg.tag, seg.ht, seg.htg, seg.A, ["%+.2f" % v for v in seg.lo_off], seg.band_off,
                  ["%+.2f" % v for v in seg.up_off], seg.cap_off, seg.top, seg.pattern, seg.wear,
                  "-" if seg.pillar is None else "y %.2f..%.2f top %.2f" % (seg.pillar[0], seg.pillar[1], seg.pillar[3]),
                  seg.joints))
        print("         cap blocks %s" % ", ".join("y %.2f..%.2f top %.2f" % b for b in seg.cap_blocks))
    total = 0
    for obj in out:
        n = count_tris(obj)
        total += n
        print(f"  {obj.name:16s} {obj.data.materials[0].name:11s} {n:6d} triangles {len(obj.data.polygons):5d} faces")
    print(f"cliffs: {len(out)} objects, {total} triangles (budget 16000)")
    names = [o.name for o in _collect(root)]
    dots = [n for n in names if "." in n]
    if dots or len(names) != len(set(names)):
        raise RuntimeError(f"bad names: {dots}")
    if check_proxies(root):
        raise RuntimeError("a proxy blocks the lane or a pad")
    if total > 16000:
        raise RuntimeError("over the cliffs' budget")


# --------------------------------------------------------------------------------------
# Shared by the cover rocks and the floor
# --------------------------------------------------------------------------------------

# Every marker stands on the floor's top at z 0 (Blender x, y): PlayerSpawn, EnemySpawn (and
# EnemySpawns3/B), EnemySpawns2/A and /B, EnemySpawns3/A and /C.
MARKERS = ((0.0, -11.0), (0.0, 11.0), (-3.3, 8.8), (4.6, 5.2), (-4.0, -2.5), (4.3, -3.0))
MARKER_CLEAR = 1.5  # the floor is one plane at z 0 this far round every marker (sheet B, Floor)
LANE_FLAT = 2.5  # ... and within |x| < 2.5


def remove_tree(name: str) -> None:
    old = bpy.data.objects.get(name)
    if old is None:
        return
    for o in reversed(_collect(old)):
        mesh = o.data if o.type == "MESH" else None
        bpy.data.objects.remove(o, do_unlink=True)
        if mesh is not None and mesh.users == 0:
            bpy.data.meshes.remove(mesh)


def remove_greybox(names, proxies) -> int:
    """Deletes greybox visuals; the proxies they leave behind must all be there."""
    removed = 0
    for name in proxies:
        if bpy.data.objects.get(name + "-convcolonly") is None:
            raise RuntimeError(f"proxy {name}-convcolonly is missing")
    for name in names:
        obj = bpy.data.objects.get(name)
        if obj is not None:
            mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if mesh is not None and mesh.users == 0:
                bpy.data.meshes.remove(mesh)
            removed += 1
    return removed


def finish_object(bm, name: str, mat_name: str, group):
    """A merged object at the canyon origin, zero rotation, flat, with 8 m tiling UVs (G2)."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    link(obj, group)
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.data.materials.append(bpy.data.materials[mat_name])
    flat_shade(obj)
    scenery_uv.unwrap_object(obj, scenery_uv.TILING)
    obj["uv_role"] = "tiling"
    return obj


def check_root(root, objs, budget: int, label: str) -> None:
    total = 0
    for obj in objs:
        n = count_tris(obj)
        total += n
        print(f"  {obj.name:16s} {obj.data.materials[0].name:11s} {n:6d} triangles {len(obj.data.polygons):5d} faces")
    print(f"{label}: {len(objs)} objects, {total} triangles (budget {budget})")
    names = [o.name for o in _collect(root)]
    dots = [n for n in names if "." in n]
    if dots or len(names) != len(set(names)):
        raise RuntimeError(f"bad names: {dots}")
    if check_proxies(root):
        raise RuntimeError("a proxy blocks the lane or a pad")
    if total > budget:
        raise RuntimeError(f"over the {label} budget")


def _meet(l1, l2):
    """Intersection of two plan lines, each given by two points."""
    (ax, ay), (bx, by) = l1
    (cx, cy), (dx, dy) = l2
    r = (bx - ax, by - ay)
    q = (dx - cx, dy - cy)
    den = r[0] * q[1] - r[1] * q[0]
    t = ((cx - ax) * q[1] - (cy - ay) * q[0]) / den
    return (ax + r[0] * t, ay + r[1] * t)


def clip_half(pts, a, b):
    """The part of a convex CCW polygon left of the directed line a -> b."""
    out = []
    n = len(pts)
    for i in range(n):
        p, q = pts[i], pts[(i + 1) % n]
        cp = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
        cq = (b[0] - a[0]) * (q[1] - a[1]) - (b[1] - a[1]) * (q[0] - a[0])
        if cp >= 0:
            out.append(p)
        if (cp >= 0) != (cq >= 0):
            t = cp / (cp - cq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def _seg_dist(p, a, b) -> float:
    ab = (b[0] - a[0], b[1] - a[1])
    L2 = ab[0] ** 2 + ab[1] ** 2
    t = 0.0 if L2 < 1e-12 else max(0.0, min(1.0, ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / L2))
    return math.dist(p, (a[0] + ab[0] * t, a[1] + ab[1] * t))


def _inside_poly(p, pts) -> bool:
    c = False
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        if (a[1] > p[1]) != (b[1] > p[1]):
            if p[0] < a[0] + (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]):
                c = not c
    return c


def poly_dist(p, pts) -> float:
    """Plan distance from a point to a polygon (0 inside)."""
    if _inside_poly(p, pts):
        return 0.0
    return min(_seg_dist(p, pts[i], pts[(i + 1) % len(pts)]) for i in range(len(pts)))


def _separated(a, b) -> bool:
    """Separating-axis test for two convex plan polygons: True when they do not overlap."""
    for poly in (a, b):
        n = len(poly)
        for i in range(n):
            p, q = poly[i], poly[(i + 1) % n]
            ax = (q[1] - p[1], p[0] - q[0])
            pa = [ax[0] * v[0] + ax[1] * v[1] for v in a]
            pb = [ax[0] * v[0] + ax[1] * v[1] for v in b]
            if max(pa) <= min(pb) + 1e-9 or max(pb) <= min(pa) + 1e-9:
                return True
    return False


def polys_apart(a, b, gap: float) -> bool:
    """True when two convex plan polygons do not overlap and stay `gap` apart (for disjoint
    convex polygons the nearest points include a vertex of one of them)."""
    if not _separated(a, b):
        return False
    return all(poly_dist(p, b) >= gap for p in a) and all(poly_dist(p, a) >= gap for p in b)


def box_poly(b, grow: float = 0.0):
    return rect(b[0] - grow, b[1] + grow, b[2] - grow, b[3] + grow)


# --------------------------------------------------------------------------------------
# Cover rocks (sheet B "Cover rocks")
# --------------------------------------------------------------------------------------

COVER_GROUP = "CanyonCover"
# name, chipped lid corner (detail 4), split by a joint (detail 6). Corners are named from the
# lane: the three rocks on each wall chip three different corners.
COVER_ROCKS = (
    ("CoverWPlayer", "lane_n", True),
    ("CoverEPlayer", "lane_s", False),
    ("CoverWMid", "lane_s", False),
    ("CoverEMid", "back_n", True),
    ("CoverWEnemy", "back_n", False),
    ("CoverEEnemy", "lane_n", False),
)
COVER_GREYBOX = [n + c for n, _, _ in COVER_ROCKS for c in ("", "Chip")]
COVER_SEED = 1880
COVER_STEP = 0.025  # insets and heights snap to 2.5 cm off the proxy faces (rule 6: 10 cm features)
COVER_NEAR = 0.15  # lane-visible faces below 1.7 m stay this close to the proxy's faces
CORNER = {"lane_s": 0, "lane_n": 1, "back_n": 2, "back_s": 3}
# Eyes for the lane-visible test: the shot band's edges and centre, 1.7 m up, every 2 m.
LANE_EYES = [(x, float(y), 1.7) for x in (-1.6, 0.0, 1.6) for y in range(-12, 13, 2)]


def cs(v: float) -> float:
    return round(v / COVER_STEP) * COVER_STEP


def inset_quad(box, s: int, ins):
    """Plan quad inside a proxy box. `ins` gives each face's inward inset at its two ends: lane
    and back (south end, north end), south and north (lane end, back end). Corners in order:
    lane-south, lane-north, back-north, back-south."""
    xl = box[1] if s < 0 else box[0]
    xb = box[0] if s < 0 else box[1]
    y0, y1 = box[2], box[3]
    lane = ((xl + s * ins["lane"][0], y0), (xl + s * ins["lane"][1], y1))
    back = ((xb - s * ins["back"][0], y0), (xb - s * ins["back"][1], y1))
    south = ((xl, y0 + ins["south"][0]), (xb, y0 + ins["south"][1]))
    north = ((xl, y1 - ins["north"][0]), (xb, y1 - ins["north"][1]))
    return [_meet(lane, south), _meet(lane, north), _meet(back, north), _meet(back, south)]


class CoverPiece:
    """A vertical prism over a chamfered plan, optionally tilted (the lid)."""

    def __init__(self, plan, z0, z1, mat, xform=None):
        self.plan, self.z0, self.z1, self.mat = ccw(plan)[0], z0, z1, mat
        self.xform = xform or Matrix.Identity(4)
        self.inv = self.xform.inverted()

    def contains(self, p, tol=1e-4) -> bool:
        q = self.inv @ Vector(p)
        if not (self.z0 - tol <= q.z <= self.z1 + tol):  # a face resting on this piece is hidden
            return False
        return poly_dist((q.x, q.y), self.plan) == 0.0 and all(
            _seg_dist((q.x, q.y), self.plan[i], self.plan[(i + 1) % len(self.plan)]) > tol
            for i in range(len(self.plan)))

    def corners(self):
        pts = []
        for x, y in self.plan:
            for z in (self.z0, self.z1):
                pts.append(self.xform @ Vector((x, y, z)))
        return pts

    def faces(self):
        """(sample points, outward normal) per side face and the top."""
        out = []
        n = len(self.plan)
        rot = self.xform.to_3x3()
        for i in range(n):
            a, b = self.plan[i], self.plan[(i + 1) % n]
            nrm = rot @ Vector((b[1] - a[1], -(b[0] - a[0]), 0.0)).normalized()
            pts = [self.xform @ Vector((a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u,
                                        self.z0 + (self.z1 - self.z0) * w))
                   for u in (0.02, 0.25, 0.5, 0.75, 0.98) for w in (0.02, 0.25, 0.5, 0.75, 0.98)]
            out.append((pts, nrm))
        cx = sum(p[0] for p in self.plan) / n
        cy = sum(p[1] for p in self.plan) / n
        top = []
        for p in self.plan:
            for f in (0.05, 0.2, 0.35, 0.5, 0.6, 0.7, 0.8, 0.9, 0.97):
                top.append(self.xform @ Vector((cx + (p[0] - cx) * f, cy + (p[1] - cy) * f, self.z1)))
        out.append((top, (rot @ Vector((0, 0, 1))).normalized()))
        return out


def box_gap(p, box) -> float:
    """Distance from a point inside a proxy box to its nearest side or top face (its buried
    bottom does not count); negative when the point lies outside the box."""
    d = (p.x - box[0], box[1] - p.x, p.y - box[2], box[3] - p.y, box[5] - p.z)
    return min(d)


def cover_ok(pieces, box, chip_pts=()):
    """Every piece inside its proxy, and every lane-visible face below 1.7 m within 0.15 m of
    the proxy's faces. Returns (ok, worst gap)."""
    for pc in pieces:
        for c in pc.corners():
            if box_gap(c, box) < -1e-4 and c.z > 0.0:
                return False, 9.0
    worst = 0.0
    for k, pc in enumerate(pieces):
        for pts, nrm in pc.faces():
            for p in pts:
                if p.z <= 0.0 or p.z >= 1.7:
                    continue
                if any(j != k and o.contains(p) for j, o in enumerate(pieces)):
                    continue
                if not any(nrm.dot(Vector(e) - p) > 0 for e in LANE_EYES):
                    continue
                if any((p - c).length < 0.3 for c in chip_pts):
                    continue  # cut away by the chip
                worst = max(worst, box_gap(p, box))
    return worst <= COVER_NEAR + 1e-6, worst


def chamfer_for(quad, box, rng, sizes=(0.1, 0.125, 0.15)):
    """A seeded 45 degree chamfer of 10 to 15 cm whose every cut face stays within 0.15 m of the
    proxy's sides, sampled along each cut. None if none fits."""
    fits = []
    for c in sizes:
        pts = cut_corners(quad, (0, 1, 2, 3), c)
        along = [(pts[2 * k][0] + (pts[2 * k + 1][0] - pts[2 * k][0]) * u / 10.0,
                  pts[2 * k][1] + (pts[2 * k + 1][1] - pts[2 * k][1]) * u / 10.0) for k in range(4) for u in range(11)]
        if all(min(x - box[0], box[1] - x, y - box[2], box[3] - y) <= COVER_NEAR + 1e-4 for x, y in along):
            fits.append(c)
    return rng.choice(fits) if fits else None


def plan_cover(name: str, chip: str, split: bool, k: int):
    """Seeded search for one rock's tiers and lid (sheet B, details 1 to 4 and 6)."""
    box = proxy_box(name)
    s = -1 if box[0] + box[1] < 0 else 1
    rng = random.Random(COVER_SEED + k)
    ylen, xlen = box[3] - box[2], box[1] - box[0]

    def pick(*vals):
        return rng.choice(vals)

    for attempt in range(400):
        # Lower tier: every face within 5 cm of its proxy face (the back stays snug for the bank).
        low = {f: (cs(rng.uniform(0.0, 0.05)), cs(rng.uniform(0.0, 0.05))) for f in ("lane", "back", "south", "north")}
        # Upper tier: one strata step of 5 to 10 cm on the lane and the ends (detail 3), at most
        # 10 cm off the proxy so its 10 cm chamfers stay within 0.15 m; the back turned 5 to 8
        # degrees, stepping in from one end.
        def st(v):
            return v + rng.choice([d for d in (0.05, 0.075, 0.1) if v + d <= 0.1 + 1e-6])

        # (A back turned past about 4 degrees leaves part of its ledge, seen past the rock's end
        # from far down the lane, more than 0.15 m inside the proxy.)
        back_far = pick(0.075, 0.1)
        deep = rng.choice(("south", "north"))  # the end where the back steps in farthest
        if deep == "south":
            bk = (low["back"][0] + 0.05 + back_far, low["back"][1] + 0.05)
        else:
            bk = (low["back"][0] + 0.05, low["back"][1] + 0.05 + back_far)
        up = {"back": bk}
        for f in ("lane", "south", "north"):
            up[f] = (st(low[f][0]), st(low[f][1]))
        # Lid: overhangs the upper tier 5 to 10 cm on the lane side (detail 2) and 2.5 to 5 cm
        # elsewhere (so no lid face shares the upper tier's plane), staying 2 cm inside the proxy (the tilt moves its high edge out about 2 cm).
        def lip(v, sizes):
            fits = [d for d in sizes if v - d >= 0.02 - 1e-6]
            return v - rng.choice(fits) if fits else None

        lid = {
            "lane": (lip(up["lane"][0], (0.05, 0.075, 0.1)), lip(up["lane"][1], (0.05, 0.075, 0.1))),
            "back": (lip(up["back"][0], (0.025, 0.05)), lip(up["back"][1], (0.025, 0.05))),
            "south": (lip(up["south"][0], (0.025, 0.05)), lip(up["south"][1], (0.025, 0.05))),
            "north": (lip(up["north"][0], (0.025, 0.05)), lip(up["north"][1], (0.025, 0.05))),
        }
        if any(v is None for f in lid.values() for v in f):
            continue
        t_lid = pick(0.25, 0.3, 0.35)
        z_top = box[5] - pick(0.0, 0.025, 0.05)
        z_lid0 = z_top - t_lid
        z_mid = cs(z_lid0 * rng.uniform(0.45, 0.6))
        # Lid tilt (inside the box): the low side sinks 5 to 8 cm, about the high side's foot.
        axis = pick("lane", "end")
        drop = pick(0.05, 0.065, 0.08)
        width = xlen if axis == "lane" else ylen
        deg = math.degrees(math.asin(drop / width))
        q_low = inset_quad(box, s, low)
        q_up = inset_quad(box, s, up)
        q_lid = inset_quad(box, s, lid)
        c_low, c_up, c_lid = chamfer_for(q_low, box, rng), chamfer_for(q_up, box, rng),             chamfer_for(q_lid, box, rng, (0.1, 0.125))
        if None in (c_low, c_up, c_lid):
            continue
        sink = 0.02  # the lid's foot sits 2 cm into the upper tier
        if axis == "lane":
            high_lane = rng.random() < 0.5
            ia, ib = (0, 1) if high_lane else (3, 2)  # the high side's edge
            pa, pb = q_lid[ia], q_lid[ib]
        else:
            high_south = rng.random() < 0.5
            ia, ib = (0, 3) if high_south else (1, 2)
            pa, pb = q_lid[ia], q_lid[ib]
        ax = Vector((pb[0] - pa[0], pb[1] - pa[1], 0.0)).normalized()
        piv = Vector((pa[0], pa[1], z_lid0 - sink))
        cen = Vector((sum(p[0] for p in q_lid) / 4, sum(p[1] for p in q_lid) / 4, piv.z))
        rot = Matrix.Rotation(math.radians(deg), 4, ax)
        if (rot @ (cen - piv)).z > 0:
            rot = Matrix.Rotation(-math.radians(deg), 4, ax)
        xform = Matrix.Translation(piv) @ rot @ Matrix.Translation(-piv)
        pieces = [
            CoverPiece(cut_corners(q_low, (0, 1, 2, 3), c_low), -0.05, z_mid, MAT_BODY),
            CoverPiece(cut_corners(q_up, (0, 1, 2, 3), c_up), z_mid, z_lid0, MAT_BODY),
            CoverPiece(cut_corners(q_lid, (0, 1, 2, 3), c_lid), z_lid0 - sink, z_top, MAT_BONE, xform),
        ]
        # The chipped corner (detail 4): a 45 degree cut of 15 to 25 cm off the lid's top corner.
        ci = CORNER[chip]
        cc = pick(0.15, 0.2, 0.25)
        P = q_lid[ci]
        e1, e2 = q_lid[ci - 1], q_lid[(ci + 1) % 4]
        d1 = Vector((e1[0] - P[0], e1[1] - P[1], 0.0)).normalized()
        d2 = Vector((e2[0] - P[0], e2[1] - P[1], 0.0)).normalized()
        Pv = Vector((P[0], P[1], z_top))
        chip_pts = [Pv + d1 * cc, Pv + d2 * cc, Pv - Vector((0, 0, cc))]
        if cc > t_lid - 0.05:
            continue
        ok, worst = cover_ok(pieces, box, [xform @ Pv])
        if not ok:
            continue
        # The joint (detail 6): two blocks 10 cm apart, across the rock, turned 0 or 15 degrees.
        joint = None
        if split:
            yj = cs(box[2] + ylen * rng.uniform(0.4, 0.6))
            ang = math.radians(pick(0.0, 15.0, -15.0))
            joint = (yj, ang)
        return {
            "box": box, "s": s, "pieces": pieces, "chip": (chip_pts, xform), "joint": joint,
            "worst": worst, "attempt": attempt, "deg": deg, "axis": axis, "t_lid": t_lid,
            "z": (z_mid, z_lid0, z_top), "c": (c_low, c_up, c_lid), "cc": cc,
            "turn_back": math.degrees(math.atan(back_far / ylen)),
        }
    raise RuntimeError(f"{name}: no tiers fit the proxy")


def _turns(plan_pts):
    """Plan angles of a tier's four long faces off the axes, in degrees."""
    out = []
    n = len(plan_pts)
    for i in range(n):
        a, b = plan_pts[i], plan_pts[(i + 1) % n]
        if math.dist(a, b) < 0.5:
            continue
        ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])) % 90.0
        out.append(min(ang, 90.0 - ang))
    return out


def add_cover(wall: Wall, plan) -> None:
    """Shells of one rock into the shared union; a split rock is built as two halves."""
    def halves(half_gap):
        if plan["joint"] is None:
            return [None]
        yj, ang = plan["joint"]
        box = plan["box"]
        cx = (box[0] + box[1]) / 2
        d = (math.cos(ang), math.sin(ang))
        nrm = (-d[1], d[0])
        cut = []
        for sgn in (1, -1):
            o = (cx + nrm[0] * half_gap * sgn, yj + nrm[1] * half_gap * sgn)
            cut.append(((o[0] - d[0] * 5 * sgn, o[1] - d[1] * 5 * sgn), (o[0] + d[0] * 5 * sgn, o[1] + d[1] * 5 * sgn)))
        return cut

    for pc in plan["pieces"]:
        # The body splits 10 cm apart; the lid overhangs the joint 1.25 cm a side, so no face of the
        # tilted lid coincides with the body's joint faces (no slivers in the union).
        for h in halves(0.0375 if pc.mat == MAT_BONE else 0.05):
            pts = pc.plan if h is None else clip_half(pc.plan, h[0], h[1])
            if len(pts) < 3:
                continue
            xform = None if pc.xform == Matrix.Identity(4) else pc.xform
            wall.prism(pts, pc.z0, pc.z1, pc.mat, xform=xform)
    # The chip: a convex wedge outside the cut plane, as bone.
    (p1, p2, p3), xform = plan["chip"]
    nrm = (p2 - p1).cross(p3 - p1).normalized()
    cen = (p1 + p2 + p3) / 3
    corner = p3 + Vector((0, 0, (p1.z - p3.z)))
    if nrm.dot(corner - cen) < 0:
        nrm = -nrm
    pts = [xform @ p for p in (p1, p2, p3, p1 + nrm * 0.6, p2 + nrm * 0.6, p3 + nrm * 0.6)]
    tmp = bmesh.new()
    vs = [tmp.verts.new(p) for p in pts]
    bmesh.ops.convex_hull(tmp, input=vs)
    for f in tmp.faces:
        f.material_index = MAT_BONE
    me = bpy.data.meshes.new("_chip")
    tmp.to_mesh(me)
    tmp.free()
    wall.cuts.from_mesh(me)
    bpy.data.meshes.remove(me)


def build_cover():
    root = bpy.data.objects.get(ROOT_NAME)
    if root is None:
        raise RuntimeError("no `canyon` root: open canyon.blend")
    print(f"greybox cover visuals removed: {remove_greybox(COVER_GREYBOX, [n for n, _, _ in COVER_ROCKS])}")
    remove_tree(COVER_GROUP)
    wall = Wall(1)
    mats = [bpy.data.materials["M_CapDark"], bpy.data.materials["M_CapDark"], bpy.data.materials["M_Cap"]]
    for k, (name, chip, split) in enumerate(COVER_ROCKS):
        plan = plan_cover(name, chip, split, k)
        add_cover(wall, plan)
        z_mid, z_lid0, z_top = plan["z"]
        turns = sorted({round(t, 1) for pc in plan["pieces"] for t in _turns(pc.plan)})
        print("  %-12s try %3d  tiers 0..%.3f..%.3f lid %.2f thick to %.3f (proxy top %.2f), lid tilt %.1f deg (%s), "
              "chamfers %s, chip %s %.2f, joint %s, worst lane-visible gap %.3f, face turns %s deg" % (
                  name, plan["attempt"], z_mid, z_lid0, plan["t_lid"], z_top, plan["box"][5], plan["deg"],
                  plan["axis"], plan["c"], chip, plan["cc"],
                  "-" if plan["joint"] is None else "y %.3f at %+.0f deg" % (plan["joint"][0], math.degrees(plan["joint"][1])),
                  plan["worst"], turns))
    print(f"cover: {wall.pieces} shells, union ...")
    bm = union_wall(wall, mats)
    body = split_by_material(bm, MAT_BODY)
    lids = split_by_material(bm, MAT_BONE)
    bm.free()
    group = empty(COVER_GROUP, root)
    group.location = (0.0, 0.0, 0.0)
    out = [finish_object(body, "Cover_CapDark", "M_CapDark", group),
           finish_object(lids, "Cover_Cap", "M_Cap", group)]
    check_root(root, out, 1500, "cover")


# --------------------------------------------------------------------------------------
# Floor (sheet B "Floor")
# --------------------------------------------------------------------------------------

FLOOR_GROUP = "CanyonFloor"
FLOOR_SEED = 1869
FLOOR_X, FLOOR_Y = 16.0, 14.6  # the greybox footprint; the top is z 0
FLOOR_EDGE = 0.24  # the rim edge's depth (the greybox slab's thickness); no bottom
FLOOR_UNDER = 1.0  # the floor's side edges run this far in under the talus fronts
FLOOR_FULL = 9.0  # beyond |y| 9 the floor runs to x +/-16: the tunnels under the end walls show it
STRAIGHT = 3.0  # the rim edge is straight within +/-3 m of the lane
NOTCH_MAX = 0.9  # deepest rim notch (sheet: 1.2): a body against the rim wall stays over the floor
TALUS = {s: [f"{'West' if s < 0 else 'East'}Talus{i}" for i in range(8)] for s in (-1, 1)}
LIPS = ("SouthLip0", "SouthLip1", "SouthLip2", "SouthLip3", "NorthLip0", "NorthLip1", "NorthLip2", "NorthLip3")
# Bedrock steps (detail 4): plan boxes beyond |x| 2.5, clear of markers, rocks, and talus; each
# gets two corners cut at 45 degrees. (x0, x1, y0, y1, height)
STEPS = (
    (-4.5, -2.75, -11.0, -8.75, 0.15),
    (2.75, 5.0, -7.25, -4.75, 0.1),
    (-4.25, -2.75, 2.25, 4.75, 0.125),
    (2.75, 4.5, 7.0, 10.0, 0.15),
)


def frontmost(s: int):
    """Per talus segment: (y0, y1, front x) where that segment's front is the one nearest the lane."""
    boxes = [proxy_box(n) for n in TALUS[s]]
    out = []
    for i, b in enumerate(boxes):
        f = front(b, s)
        y0, y1 = b[2], b[3]
        for j, o in enumerate(boxes):
            if j == i:
                continue
            fo = front(o, s)
            if s * (f - fo) > 0:  # the other front is nearer the lane over its range
                if o[2] <= y0 < o[3]:
                    y0 = max(y0, o[3])
                if o[2] < y1 <= o[3]:
                    y1 = min(y1, o[2])
        out.append((y0, y1, f, b))
    return out


def side_line(s: int):
    """The floor's edge under one wall from y -9 to 9: x = the frontmost talus front plus 1 m into
    the rock, stepping halfway along each overlap of two talus proxies."""
    boxes = [proxy_box(n) for n in TALUS[s]]
    cuts = [-FLOOR_FULL] + [(boxes[i][3] + boxes[i + 1][2]) / 2 for i in range(1, 6)] + [FLOOR_FULL]
    pts = []
    for k in range(len(cuts) - 1):
        ya, yb = cuts[k], cuts[k + 1]
        # At each y the rock starts at the nearest front covering it; the edge must sit behind
        # the deepest of those over the whole stretch.
        deepest = None
        for j in range(int(round((yb - ya) / 0.05)) + 1):
            y = ya + 0.05 * j
            fs = [front(b, s) for b in boxes if b[2] <= y <= b[3]]
            near = max(fs) if s < 0 else min(fs)
            deepest = near if deepest is None else (min(deepest, near) if s < 0 else max(deepest, near))
        x = g(deepest + s * FLOOR_UNDER)
        pts += [(x, ya), (x, yb)]
    return pts


def end_edge(sy: int, rng):
    """One end of the floor (sy -1 south, 1 north), west to east: straight within +/-3 m, notched
    outside it (0.3 to 0.9 m deep, sides at 45 to 90 degrees), corners chipped."""
    y = sy * FLOOR_Y
    lips = [proxy_box(n) for n in LIPS if (n.startswith("North") == (sy > 0))]
    blocked = [(b[0] - 0.35, b[1] + 0.35) for b in lips] + [(-STRAIGHT, STRAIGHT)]
    pts = [(-FLOOR_X, y)]
    notches = []
    for x0, x1 in ((-14.5, -STRAIGHT - 0.5), (STRAIGHT + 0.5, 14.5)):
        x = x0
        while x < x1:
            w = rng.choice((1.25, 1.5, 2.0, 2.5))
            gap = rng.choice((1.5, 2.0, 3.0))
            xa, xb = x + gap, x + gap + w
            if xb > x1:
                break
            if not any(xa < b1 and xb > b0 for b0, b1 in blocked):
                notches.append((xa, xb, rng.choice([d for d in (0.3, 0.45, 0.6, 0.75, 0.9) if d <= NOTCH_MAX]),
                                rng.choice((45.0, 60.0, 75.0, 90.0)), rng.choice((45.0, 60.0, 90.0)),
                                rng.choice((-1, 0, 1))))
                x = xb
            else:
                x = xa
    out = []
    for xa, xb, depth, a_left, a_right, chip in notches:
        yi = y - sy * depth  # the notch's bottom, inward
        ia = depth / math.tan(math.radians(a_left))
        ib = depth / math.tan(math.radians(a_right))
        if xb - xa - ia - ib < 0.5:
            ia = ib = 0.0
        seq = [(xa, y), (xa + ia, yi), (xb - ib, yi), (xb, y)]
        if chip:  # one mouth corner chipped 0.25 m at 45 degrees
            k = 0 if chip < 0 else 3
            p = seq[k]
            q = seq[1] if k == 0 else seq[2]
            L = math.dist(p, q)
            cut = (p[0] + (q[0] - p[0]) * 0.25 / L, p[1] + (q[1] - p[1]) * 0.25 / L)
            back = (p[0] - 0.25 if k == 0 else p[0] + 0.25, y)
            seq = [back, cut] + seq[1:] if k == 0 else seq[:3] + [cut, back]
        out += seq
    cc = rng.choice((0.5, 0.75, 1.0))
    head = [(-FLOOR_X, y - sy * cc), (-FLOOR_X + cc, y)]
    tail = [(FLOOR_X - cc, y), (FLOOR_X, y - sy * cc)]
    return head + out + tail, notches


def floor_outline(rng):
    south, n_s = end_edge(-1, rng)
    north, n_n = end_edge(1, rng)
    west = side_line(-1)
    east = side_line(1)
    pts = list(south)  # west to east along y -14.6
    pts += [(FLOOR_X, -FLOOR_FULL), (east[0][0], -FLOOR_FULL)] + east[1:-1] + [(east[-1][0], FLOOR_FULL), (FLOOR_X, FLOOR_FULL)]
    pts += list(reversed(north))  # east to west along y 14.6
    pts += [(-FLOOR_X, FLOOR_FULL), (west[-1][0], FLOOR_FULL)] + list(reversed(west[1:-1])) + [(west[0][0], -FLOOR_FULL), (-FLOOR_X, -FLOOR_FULL)]
    # Edge faces only where the floor's edge is seen: the two ends and x +/-16 beyond |y| 9.
    rim = set()
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        if abs(a[1]) > FLOOR_FULL + 1e-6 or abs(b[1]) > FLOOR_FULL + 1e-6 or \
                (abs(abs(a[0]) - FLOOR_X) < 1e-6 and abs(abs(b[0]) - FLOOR_X) < 1e-6):
            rim.add((a, b))
    return pts, rim, n_s + n_n


def bank_poly(xf, s, ya, yb, w, ta, tb):
    """A bank's plan: the ridge along x = xf from ya to yb, the toe w metres toward the lane,
    shortened by ta and tb at its ends."""
    xt = xf - s * w
    return [(xf, ya), (xt, ya + ta), (xt, yb - tb), (xf, yb)]


def plan_banks(rng, steps, covers):
    """Sand banks (detail 3): behind each cover rock, and along the talus fronts. None inside a
    proxy, within 1.5 m of a marker, or within 0.2 m of a rock, a step, or another bank."""
    banks = []
    keep_out = [box_poly(b, 0.2) for b in covers] + [st for st in steps]
    # Every other proxy footprint (teeth, rubble, lip stones, rim walls): no bank enters one.
    others, others_b = [], []
    for o in bpy.data.objects:
        n = o.name
        if o.type == "MESH" and n.endswith("-convcolonly") and n != "Floor-convcolonly"                 and "Talus" not in n and not n.startswith("Cover"):
            b = proxy_box(n[:-len("-convcolonly")])
            if b[4] < 0.3 and b[5] > 0.0:
                others.append(box_poly(b))
                others_b.append(b)

    def clear(poly, extra=()):
        if any(poly_dist(m, poly) < MARKER_CLEAR + 0.05 for m in MARKERS):
            return False
        if any(abs(x) < LANE_FLAT + 0.25 for x, _ in poly):
            return False
        if not all(polys_apart(poly, o, 0.05) for o in others):
            return False
        return all(polys_apart(poly, o, 0.2) for o in list(extra) + [b["poly"] for b in banks])

    # Behind each rock: from its proxy's far face toward the wall, down to the talus front.
    for name, _, _ in COVER_ROCKS:
        b = proxy_box(name)
        s = -1 if b[0] + b[1] < 0 else 1
        xf = b[0] if s < 0 else b[1]
        # Out to the nearest proxy behind the rock: the frontmost talus or a tooth or stone.
        # (The toe may meet a talus front; it stops 10 cm short of a tooth or a stone.)
        gaps = [abs(f - xf) for y0, y1, f, _ in frontmost(s) if y0 < b[3] and y1 > b[2]]
        gaps += [abs((o[1] if s < 0 else o[0]) - xf) - 0.1 for o in others_b
                 if o[2] < b[3] and o[3] > b[2] and s * (o[0] + o[1]) / 2 > s * xf]
        w = min([0.9] + gaps)
        h = 0.2 if w >= 0.8 else 0.15
        # The full length of the rock where the markers allow; else shortened at one end.
        fits = [(ya, yb, ta, tb) for trim in (0.0, 0.25, 0.5) for ya, yb in ((b[2], b[3] - trim), (b[2] + trim, b[3]))
                for ta, tb in ((0.25, 0.25), (0.25, 0.5), (0.5, 0.25), (0.5, 0.5))]
        for ya, yb, ta, tb in fits:
            if yb - ya - ta - tb < 0.5:
                continue  # keep a ridge
            poly = bank_poly(xf, -s, ya, yb, w, ta, tb)
            if any(poly_dist(m, poly) < MARKER_CLEAR + 0.05 for m in MARKERS):
                continue
            if not all(polys_apart(poly, o, 0.05) for o in others):
                continue
            banks.append({"poly": poly, "xf": xf, "s": -s, "y": (ya, yb), "w": w, "h": h, "t": (ta, tb),
                          "kind": name})
            break
        else:
            raise RuntimeError(f"no bank fits behind {name}")
    # Along the talus fronts: one bank per segment where one fits.
    for s in (-1, 1):
        for i, (y0, y1, f, box) in enumerate(frontmost(s)):
            lo, hi = max(y0 + 0.25, -FLOOR_Y + 1.0), min(y1 - 0.25, FLOOR_Y - 1.25)
            tries = []
            for L in (4.0, 3.5, 3.0, 2.5, 2.0, 1.5):
                for ya in [lo + 0.25 * k for k in range(math.floor((hi - lo - L) / 0.25 + 1e-6) + 1)]:
                    for w in (1.5, 1.25, 1.0):
                        tries.append((ya, ya + L, w))
            rng.shuffle(tries)
            tries.sort(key=lambda t: -(t[1] - t[0]))
            for ya, yb, w in tries:
                ta, tb = rng.choice((0.25, 0.5, 0.75)), rng.choice((0.25, 0.5, 0.75))
                if yb - ya - ta - tb < 0.5:
                    continue  # keep a ridge
                poly = bank_poly(f, s, ya, yb, w, ta, tb)
                if clear(poly, keep_out):
                    banks.append({"poly": poly, "xf": f, "s": s, "y": (ya, yb), "w": w,
                                  "h": rng.choice((0.15, 0.2, 0.25, 0.3)), "t": (ta, tb),
                                  "kind": f"{'West' if s < 0 else 'East'}Talus{i}"})
                    break
    return banks


def build_floor():
    root = bpy.data.objects.get(ROOT_NAME)
    if root is None:
        raise RuntimeError("no `canyon` root: open canyon.blend")
    print(f"greybox floor visual removed: {remove_greybox(['Floor'], ['Floor'])}")
    remove_tree(FLOOR_GROUP)
    rng = random.Random(FLOOR_SEED)
    pts, rim, notches = floor_outline(rng)
    pts, _ = _clean(pts, [False] * len(pts))
    if _area(pts) <= 0 or not _simple(pts):
        raise RuntimeError("the floor outline crosses itself")
    bm = bmesh.new()
    top = [bm.verts.new((x, y, 0.0)) for x, y in pts]
    bm.faces.new(top)
    low = {}
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        if (a, b) not in rim:
            continue
        for p in (a, b):
            if p not in low:
                low[p] = bm.verts.new((p[0], p[1], -FLOOR_EDGE))
        bm.faces.new((top[i], low[a], low[b], top[(i + 1) % n]))
    # Bedrock steps: a flat top and vertical sides, no bottom.
    steps = []
    for x0, x1, y0, y1, h in STEPS:
        k = rng.choice(((0, 2), (1, 3)))
        plan, _ = ccw(cut_corners(rect(x0, x1, y0, y1), k, rng.choice((0.5, 0.75))))
        steps.append(plan)
        vt = [bm.verts.new((x, y, h)) for x, y in plan]
        vb = [bm.verts.new((x, y, 0.0)) for x, y in plan]
        bm.faces.new(vt)
        for i in range(len(plan)):
            j = (i + 1) % len(plan)
            bm.faces.new((vt[i], vb[i], vb[j], vt[j]))
    covers = [proxy_box(nm) for nm, _, _ in COVER_ROCKS]
    talus = [proxy_box(nm) for s in (-1, 1) for nm in TALUS[s]]
    banks = plan_banks(rng, steps, covers)
    for bk in banks:
        xf, s, (ya, yb), w, h, (ta, tb) = bk["xf"], bk["s"], bk["y"], bk["w"], bk["h"], bk["t"]
        xt = xf - s * w
        r0, r1 = bm.verts.new((xf, ya + ta, h)), bm.verts.new((xf, yb - tb, h))
        t0, t1 = bm.verts.new((xt, ya + ta, 0.0)), bm.verts.new((xt, yb - tb, 0.0))
        e0, e1 = bm.verts.new((xf, ya, 0.0)), bm.verts.new((xf, yb, 0.0))
        for f in ((r0, r1, t1, t0), (e0, r0, t0), (e1, t1, r1)):
            face = bm.faces.new(f)
            face.normal_update()
            if face.normal.z < 0:
                face.normal_flip()
        for x, y in bk["poly"]:
            for b in covers + talus:
                if b[0] + 1e-6 < x < b[1] - 1e-6 and b[2] + 1e-6 < y < b[3] - 1e-6:
                    raise RuntimeError(f"bank {bk['kind']} enters a proxy")
    bm.normal_update()
    tris_bad = _degenerate_faces(bm)
    if tris_bad:
        raise RuntimeError(f"{len(tris_bad)} floor faces tessellate to zero-area triangles")
    group = empty(FLOOR_GROUP, root)
    group.location = (0.0, 0.0, 0.0)
    obj = finish_object(bm, "Floor_Sand", "M_Sand", group)
    print(f"  outline {len(pts)} points, {len(rim)} rim edge faces, {len(notches)} notches: " + ", ".join(
        "x %.2f..%.2f %.2f deep" % (a, b, d) for a, b, d, _, _, _ in notches))
    print(f"  {len(STEPS)} bedrock steps, {len(banks)} banks: " + ", ".join(
        "%s %.2f..%.2f h %.2f w %.2f" % (b["kind"], b["y"][0], b["y"][1], b["h"], b["w"]) for b in banks))
    check_root(root, [obj], 400, "floor")


# --------------------------------------------------------------------------------------
# Rim (sheet B "Rim")
# --------------------------------------------------------------------------------------

RIM_GROUP = "CanyonRim"
RIM_SEED = 1857
RIM_FACES = ("SouthFace", "NorthFace", "WestFace", "EastFace")
RIM_GREYBOX = list(RIM_FACES) + list(LIPS)
RIM_PROXIES = RIM_GREYBOX + ["RimSouth", "RimNorth", "RimWest", "RimEast"]
RIM_X, RIM_Y = 15.92, 14.52  # the face proxies' inner faces: the butte's sides
RIM_LIP = 0.08  # the floor's edge overhangs the faces by this much (sheet B, Floor)
RIM_TOP = -0.15  # the faces' top, hidden behind the floor's 0.24 m edge
PLAIN_Z = -24.0  # the plain's top (`Desert`); the build cuts everything below it
CREST_IN = 15.25  # beside the cliffs (|y| < 9, no floor) the top runs at z 0 from under their backs
TAN22 = math.tan(math.radians(22.5))
# Strata below the rim (sheet A, Bands "Below the rim"; sheet B, Rim details 1 and 2): (name, top,
# bottom, base proudness off the butte's side lines x +/-15.92 and y +/-14.52, kind). "top" follows
# the floor's edge and notches; the others are big slabs 0.5 m proud of ("out", "band") or behind
# ("in", "under") the slab above, or a ledge 2.25 m out ("ledge"). Each drop's layers share bays
# (RIM_DROP), so every step stays exact; the bays move the ledge widths to 1.75 to 2.75 m.
RIM_LAYERS = (
    ("U0", RIM_TOP, -2.25, 0.0, "top"),
    ("U1", -2.25, -4.25, 0.5, "out"),
    ("U2", -4.25, -6.0, 0.0, "in"),
    ("band", -6.0, -7.25, 0.5, "band"),
    ("U3", -7.25, -9.25, 0.0, "under"),
    ("M0", -9.25, -11.75, 2.25, "ledge"),
    ("M1", -11.75, -14.0, 2.75, "out"),
    ("M2", -14.0, -16.5, 2.25, "in"),
    ("L0", -16.5, -18.75, 4.5, "ledge"),
    ("L1", -18.75, PLAIN_Z - 0.25, 5.0, "out"),
)
# The four faces, counter-clockwise: (name, start corner, along, outward, length). Face k starts at
# corner k; the chamfer between face k and face k + 1 belongs to corner k + 1.
RIM_SIDES = (
    ("south", (-RIM_X, -RIM_Y), (1.0, 0.0), (0.0, -1.0), 2 * RIM_X),
    ("east", (RIM_X, -RIM_Y), (0.0, 1.0), (1.0, 0.0), 2 * RIM_Y),
    ("north", (RIM_X, RIM_Y), (-1.0, 0.0), (0.0, 1.0), 2 * RIM_X),
    ("west", (-RIM_X, RIM_Y), (0.0, -1.0), (-1.0, 0.0), 2 * RIM_Y),
)
CORNERS = ("SW", "SE", "NE", "NW")
# Skirt wedges (detail 2): toes 6 m out at the corners, 7 to 9 m between (10 would lift the
# wedge's buried back over the second ledge where the ledge face steps in).
SKIRT_W = (7.0, 8.0, 9.0)
SKIRT_END_W = 6.0
# The three drops (detail 2): each shares one set of bays down its layers.
RIM_DROP = {"U1": 0, "U2": 0, "band": 0, "U3": 0, "M0": 1, "M1": 1, "M2": 1, "L0": 2, "L1": 2}
LIP_GRID = 0.025
# Rim collision (sheet H, Rim; a listed collision change, rule 28): boxes that follow the faces you
# see, so a shot fired down past the edge stops on visible rock. Each box's outer face lies on one
# stratum's face, and every point of every box lies inside the rock, or at most RIM_PX_NEAR in front
# of it, at its own height. (name suffix, top layer, bottom layer, the layer whose face and bays it
# follows (None: the deepest face of its layers), one box per bay). "" keeps the greybox face
# proxy's name on the upper drop, from under the floor to U3's foot, flush with its deepest face (the
# notch backs on the ends); the bay boxes stand flush on the strata that step out: U1 and the band
# (0.5 m proud), the first ledge (M0 to M2, its top the ledge), M1 (0.5 m proud of it), the second
# ledge (L0 and L1) and L1 (0.5 m proud). Nothing else on the rim changes collision.
RIM_PX_NEAR = 0.15
RIM_PX_DEPTH = 2.4  # every box runs this far into the rock from its face (the greybox face proxies' thickness)
RIM_PX_BOTTOM = -24.35  # the greybox face proxies' foot
RIM_PX = (
    ("", 0, 4, None, False),
    ("U1Bay", 1, 1, 1, True),
    ("BandBay", 3, 3, 3, True),
    ("Ledge1Bay", 5, 7, 5, True),
    ("M1Bay", 6, 6, 6, True),
    ("Ledge2", 8, 9, 8, False),
    ("L1", 9, 9, 9, False),
)
RIM_FACE_NAME = {"south": "SouthFace", "east": "EastFace", "north": "NorthFace", "west": "WestFace"}
# The same strata round each corner's 45 degree chamfer: one box turned to the chamfer, flush with it.
RIM_PX_CORNER = ("U1", "Band", "Ledge1", "M1", "Ledge2", "L1")
RIM_PX_ADDED = re.compile(r"^((South|North|West|East)Face.+|(SW|SE|NE|NW)Corner.+)-convcolonly$")  # this script's own boxes


def side_pt(k: int, s: float, p: float):
    _, a, t, n, _ = RIM_SIDES[k]
    return (a[0] + t[0] * s + n[0] * p, a[1] + t[1] * s + n[1] * p)


def butte_top():
    """The faces' top edge (detail 4): the floor's rim outline (both ends with their notches, the
    chipped corners, x +/-16 beyond |y| 9), straight at x +/-16 in between, 8 cm inside."""
    pts, _, _ = floor_outline(random.Random(FLOOR_SEED))  # the floor's own seed: the same outline
    pts, _ = _clean(pts, [False] * len(pts))
    pts = [p for p in pts if abs(p[1]) > FLOOR_FULL + 1e-6 or abs(abs(p[0]) - FLOOR_X) < 1e-6]
    pts, _ = ccw(pts)
    out = offset_polygon(pts, [RIM_LIP] * len(pts))
    if not _simple(out) or _area(out) <= 0:
        raise RuntimeError("the rim's top outline crosses itself")
    return out


def runs_at(runs):
    def f(s):
        for a, b, d in runs:
            if a - 1e-9 <= s <= b + 1e-9:
                return d
        return 0.0
    return f


def plan_bays(rng, L, c0, c1, flat=False):
    """One drop's bays along one face: [(s0, s1, d)], d the bay's proudness off each layer's base,
    shared by every layer of the drop, so the drop reads as a few big blocks 7 to 11 m wide with
    joints running down it and the strata steps stay exact. The end bays keep d 0, so every corner
    chamfer stays at 45 degrees; neighbours differ by 0.25."""
    if flat:
        return [(c0, L - c1, 0.0)]
    cuts = [c0]
    s = c0
    while True:
        s = g(s + rng.choice((7.0, 8.0, 9.0, 10.0, 11.0)))
        if L - c1 - s < 6.0:
            break
        cuts.append(s)
    cuts.append(L - c1)
    n = len(cuts) - 1
    ds = [0.0]
    for j in range(1, n - 1):
        ds.append(rng.choice([d for d in (-0.25, 0.0, 0.25) if d != ds[-1] and not (j == n - 2 and d == 0.0)]))
    if n > 1:
        ds.append(0.0)
    return list(zip(cuts[:-1], cuts[1:], ds))


def layer_runs(bays, base):
    """A layer's runs from its drop's bays: the end points move along the chamfers with the base."""
    r = list(bays)
    r[0] = (r[0][0] - TAN22 * base, r[0][1], r[0][2])
    r[-1] = (r[-1][0], r[-1][1] + TAN22 * base, r[-1][2])
    return r


def layer_poly(base, runs4):
    """A layer's plan: each face's runs at base + d joined by returns; the run lines' ends meet on
    the 45 degree corner chamfers."""
    pts = []
    for k in range(4):
        for s0, s1, d in runs4[k]:
            pts.append(side_pt(k, s0, base + d))
            pts.append(side_pt(k, s1, base + d))
    pts, _ = ccw(pts)
    if not _simple(pts):
        raise RuntimeError("a rim layer's plan crosses itself")
    return pts


def corner_end(poly, corner: str):
    """The chamfer's end on the side whose colour differs from the chamfer's: its west end at SW
    (the chamfer is vermilion like the south face), its east end at NE (pink like the north)."""
    sx = -1 if corner == "SW" else 1
    best = None
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L > 0.2 and abs(abs(dx) - abs(dy)) < 1e-3 * L and mx * sx > 14.0 and my * sx > 12.0:
            best = min((a, b), key=lambda q: -q[0] * sx)
    return best


def rim_wedge(wall: Wall, k: int, sa, sb, p_face: float, w: float, p_flat: float, mitre_a: bool, mitre_b: bool):
    """A skirt wedge along face k from s sa to sb: a 35 degree slope from its toe on the plain, w
    metres out from the face, up into the rock to p_flat, where its buried top turns flat; its
    back 3 m inside the face. A mitred end lies on the corner's 45 degree bisector."""
    toe = p_face + w
    p_in = p_face - 3.0
    zb = PLAIN_Z - 0.25
    zf = PLAIN_Z + (toe - p_flat) * TAN35
    prof = [(p_in, zb), (toe + 0.25 / TAN35, zb), (p_flat, zf), (p_in, zf)]
    L = RIM_SIDES[k][4]
    rings = []
    for s, mitre, end in ((sa, mitre_a, 0), (sb, mitre_b, 1)):
        ring = []
        for p, z in prof:
            ss = (-p if end == 0 else L + p) if mitre else s
            x, y = side_pt(k, ss, p)
            ring.append((x, y, z))
        rings.append(ring)
    wall._shell(wall.bm, rings, MAT_BODY, None)


def rim_block(wall: Wall, k: int, s0: float, p0: float, z: float, ln: float, dep: float, h: float, deg: float):
    """A fallen block on a ledge (detail 6): chamfered 0.25, tilted about its inner bottom edge,
    sunk 0.25 so its lifted edge stays buried."""
    _, a, t, n, _ = RIM_SIDES[k]
    loc = [(s0, p0), (s0 + ln, p0), (s0 + ln, p0 + dep), (s0, p0 + dep)]
    plan = cut_corners([side_pt(k, s, p) for s, p in loc], (0, 1, 2, 3), 0.25)
    piv = Vector((*side_pt(k, s0 + ln / 2, p0), z - 0.25))
    axis = Vector((t[0], t[1], 0.0))
    xform = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-piv)
    wall.prism(plan, z - 0.25, z + h, MAT_BODY, xform=xform)


def rim_material(f, levels) -> int:
    """Rule 17 per face: the south and east faces take sun (vermilion, 0), the north and west never
    do (pink, 3). The chamfers follow the light: SW and SE vermilion, NE and NW pink."""
    c = f.calc_center_median()
    nrm = f.normal
    h = math.hypot(nrm.x, nrm.y)
    corner = abs(c.x) > 12.0 and abs(c.y) > 10.0
    if corner and abs(nrm.z) < 0.3 and abs(nrm.x) / h > 0.5 and abs(nrm.y) / h > 0.5:
        return 0 if c.y < 0 else 3  # a corner chamfer, or a skirt wedge's mitred end
    if 0.3 <= abs(nrm.z) <= 0.999 and h > 0.3 and c.z < RIM_LAYERS[-2][1] - 0.5:
        # A skirt slope: the side it faces.
        if abs(nrm.x) > abs(nrm.y) + 1e-6:
            return 0 if nrm.x > 0 else 3
        if abs(nrm.y) > abs(nrm.x) + 1e-6:
            return 0 if nrm.y < 0 else 3
    if nrm.z < -0.999 and corner and abs(abs(c.x) - RIM_X) < 1.0 and abs(abs(c.y) - RIM_Y) < 1.0:
        return 0 if c.y < 0 else 3  # an overhang under a corner chamfer takes the chamfer's colour
    if abs(nrm.z) > 0.999:
        for z, sw, ne in levels:
            if abs(c.z - z) > 1e-3:
                continue
            for line, sx in ((sw, -1), (ne, 1)):
                if line is None or not (c.x * sx > 12.0 and c.y * sx > 10.0):
                    continue
                (ax, ay), (bx, by) = line
                side = (bx - ax) * (c.y - ay) - (by - ay) * (c.x - ax)
                ref = (bx - ax) * (-sx) - (by - ay) * 0.0  # the point a + (0, -sx): on the W/E face
                if sx < 0:
                    return 3 if side * ref > 0 else 0  # SW: the west face's side is pink
                return 0 if side * ref > 0 else 3  # NE: the east face's side is vermilion
    ex, ey = abs(c.x) - RIM_X, abs(c.y) - RIM_Y
    if ey >= ex:
        return 0 if c.y < 0 else 3
    return 0 if c.x > 0 else 3


def face_edges(poly, k: int):
    """The edges of a CCW plan polygon that look out along face k, within a few metres of its line
    (not the notch sides on the next face): [(s0, s1, p)]."""
    _, a, t, n, _ = RIM_SIDES[k]
    out = []
    m = len(poly)
    for i in range(m):
        p0, p1 = poly[i], poly[(i + 1) % m]
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        L = math.hypot(dx, dy)
        if L < 0.2 or (dy * n[0] - dx * n[1]) / L < 0.999:
            continue
        s = sorted((q[0] - a[0]) * t[0] + (q[1] - a[1]) * t[1] for q in (p0, p1))
        p = (p0[0] - a[0]) * n[0] + (p0[1] - a[1]) * n[1]
        if -3.0 < p < 8.0:
            out.append((s[0], s[1], p))
    return out


def rim_box_misses(k: int, sa: float, sb: float, p_out: float, layers, polys):
    """The s of every sample of a box's plan (s sa..sb, p from p_out - RIM_PX_DEPTH to p_out) that
    lies more than RIM_PX_NEAR outside one of its layers' plans."""
    p_in = p_out - RIM_PX_DEPTH
    ns = max(2, int(round((sb - sa) / 0.05)) + 1)
    npp = int(round(RIM_PX_DEPTH / 0.05)) + 1
    pts = []
    for i in range(ns):
        s = sa + (sb - sa) * i / (ns - 1)
        pts += [(s, p_in), (s, p_out)]
        if i % 5 == 0:
            pts += [(s, p_in + RIM_PX_DEPTH * j / 8.0) for j in range(1, 8)]
    for j in range(npp):
        p = p_in + RIM_PX_DEPTH * j / (npp - 1)
        pts += [(sa, p), (sb, p)]
    bad = []
    for s, p in pts:
        xy = side_pt(k, s, p)
        if any(poly_dist(xy, polys[li]) > RIM_PX_NEAR + 1e-6 for li in layers):
            bad.append(s)
    return bad


def chamfer_edge(poly, corner: str):
    """A layer plan's 45 degree chamfer edge at a corner (CCW order), or None."""
    sx, sy = {"SW": (-1, -1), "SE": (1, -1), "NE": (1, 1), "NW": (-1, 1)}[corner]
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L > 0.5 and abs(abs(dx) - abs(dy)) < 1e-3 * L and (a[0] + b[0]) / 2 * sx > 12.0 \
                and (a[1] + b[1]) / 2 * sy > 10.0 and dy * sx - dx * sy > 0:
            return a, b
    return None


def quad_misses(quad, layers, polys):
    """Samples of a plan quad (and its inside) more than RIM_PX_NEAR outside one of its layers' plans."""
    bad = []
    for i in range(4):
        a, b = quad[i], quad[(i + 1) % 4]
        m = max(2, int(math.dist(a, b) / 0.05) + 1)
        for j in range(m):
            q = (a[0] + (b[0] - a[0]) * j / (m - 1), a[1] + (b[1] - a[1]) * j / (m - 1))
            if any(poly_dist(q, polys[li]) > RIM_PX_NEAR + 1e-6 for li in layers):
                bad.append(q)
    return bad


def _box_mesh(bm, b) -> None:
    """blender_kit.box's cube (same vertex order) over the world box b (x0, x1, y0, y1, z0, z1)."""
    bmesh.ops.create_cube(bm, size=1.0)
    size = (b[1] - b[0], b[3] - b[2], b[5] - b[4])
    loc = ((b[0] + b[1]) / 2, (b[2] + b[3]) / 2, (b[4] + b[5]) / 2)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
        v.co += Vector(loc)


def build_rim_proxies(root, polys, runs_all):
    """The rim's collision (RIM_PX): moves the four greybox face proxies onto the upper drop and adds
    the bay and ledge boxes, all directly under `canyon` like every other proxy. Returns the rows
    [(name, box, moved)] for the printout."""
    removed = 0
    for o in [o for o in bpy.data.objects if RIM_PX_ADDED.match(o.name)]:
        mesh = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if mesh is not None and mesh.users == 0:
            bpy.data.meshes.remove(mesh)
        removed += 1
    rows = []
    for k in range(4):
        side = RIM_SIDES[k][0]
        for suffix, top, bottom, follow, per_bay in RIM_PX:
            layers = list(range(top, bottom + 1))
            z1 = RIM_LAYERS[top][1]
            z0 = RIM_PX_BOTTOM if bottom == len(RIM_LAYERS) - 1 else RIM_LAYERS[bottom][2]
            if follow is None:
                edges = [e for li in layers for e in face_edges(polys[li], k)]
                p_out = min(e[2] for e in edges)
                span = face_edges(polys[bottom], k)
                spans = [(min(e[0] for e in span), max(e[1] for e in span), p_out)]
            else:
                base = RIM_LAYERS[follow][3]
                spans = [(s0, s1, base + d) for s0, s1, d in runs_all[follow][k]]
                if not per_bay:
                    spans = [(spans[0][0], spans[-1][1], spans[0][2])]
            for j, (sa, sb, p_out) in enumerate(spans):
                for _ in range(200):
                    bad = rim_box_misses(k, sa, sb, p_out, layers, polys)
                    if not bad:
                        break
                    mid = (sa + sb) / 2
                    if any(s < mid for s in bad):
                        sa += 0.05
                    if any(s >= mid for s in bad):
                        sb -= 0.05
                    if sb - sa < 1.0:
                        raise RuntimeError(f"no rim box fits {side} {suffix} {j}")
                else:
                    raise RuntimeError(f"no rim box fits {side} {suffix} {j}")
                xy = [side_pt(k, s, p) for s in (sa, sb) for p in (p_out - RIM_PX_DEPTH, p_out)]
                box = tuple(round(v, 4) for v in (min(q[0] for q in xy), max(q[0] for q in xy),
                                                   min(q[1] for q in xy), max(q[1] for q in xy), z0, z1))
                name = RIM_FACE_NAME[side] + (f"{suffix}{j}" if per_bay else suffix)
                bm = bmesh.new()
                _box_mesh(bm, box)
                if suffix == "":
                    obj = bpy.data.objects[name + "-convcolonly"]
                    bm.to_mesh(obj.data)
                    bm.free()
                    obj.data.update()
                else:
                    obj = mesh_from_bm(bm, name + "-convcolonly", root)
                    obj.hide_render = True
                    obj.display_type = "WIRE"
                rows.append((name, box, suffix == ""))
    groups = {suffix.replace("Bay", ""): (top, bottom, follow) for suffix, top, bottom, follow, _ in RIM_PX}
    for corner in CORNERS:
        for part in RIM_PX_CORNER:
            top, bottom, follow = groups[part]
            layers = list(range(top, bottom + 1))
            z1 = RIM_LAYERS[top][1]
            z0 = RIM_PX_BOTTOM if bottom == len(RIM_LAYERS) - 1 else RIM_LAYERS[bottom][2]
            edge = chamfer_edge(polys[follow], corner)
            if edge is None:
                raise RuntimeError(f"no chamfer at {corner} on {RIM_LAYERS[follow][0]}")
            a, b = edge
            L = math.dist(a, b)
            u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
            nrm = (u[1], -u[0])  # outward
            for _ in range(40):
                quad = [a, b, (b[0] - nrm[0] * RIM_PX_DEPTH, b[1] - nrm[1] * RIM_PX_DEPTH),
                        (a[0] - nrm[0] * RIM_PX_DEPTH, a[1] - nrm[1] * RIM_PX_DEPTH)]
                if not quad_misses(quad, layers, polys):
                    break
                a, b = (a[0] + u[0] * 0.05, a[1] + u[1] * 0.05), (b[0] - u[0] * 0.05, b[1] - u[1] * 0.05)
            else:
                raise RuntimeError(f"no rim box fits the {corner} chamfer, {part}")
            bm = bmesh.new()
            bm_verts = [bm.verts.new((x, y, z)) for z in (z0, z1) for x, y in quad]
            bm.faces.new(bm_verts[3::-1])
            bm.faces.new(bm_verts[4:])
            for i in range(4):
                j = (i + 1) % 4
                bm.faces.new((bm_verts[i], bm_verts[j], bm_verts[4 + j], bm_verts[4 + i]))
            name = f"{corner}Corner{part}"
            obj = mesh_from_bm(bm, name + "-convcolonly", root)
            obj.hide_render = True
            obj.display_type = "WIRE"
            rows.append((name, tuple(round(v, 4) for v in (quad[0][0], quad[0][1], quad[1][0], quad[1][1], z0, z1)), None))
    print(f"rim proxies: {removed} earlier boxes removed, 4 face proxies moved, {len(rows) - 4} boxes added")
    return rows


def build_lip(bm, name: str, k: int):
    """A lip stone (detail 5): a fallen bone cap block, vertical edges chamfered at 45 degrees, tilted
    6 to 14 degrees about a bottom edge and sunk so the lifted edge stays buried, inside its proxy."""
    box = proxy_box(name)
    rng = random.Random(RIM_SEED + 50 + k)
    sx, sy = box[1] - box[0], box[3] - box[2]
    cx, cy = (box[0] + box[1]) / 2, (box[2] + box[3]) / 2
    top = box[5]
    deg = rng.choice((6.0, 8.0, 10.0, 12.0, 14.0))
    along_x = k % 2 == 0  # tilt about a long (x) edge or a short (y) edge, alternating
    sign = rng.choice((-1.0, 1.0))
    sn, cs_ = math.sin(math.radians(deg)), math.cos(math.radians(deg))
    for shrink in range(60):
        a = round((sx - LIP_GRID * (shrink if along_x else shrink + 1)) / LIP_GRID) * LIP_GRID
        b = round((sy - LIP_GRID * (shrink + 1 if along_x else shrink)) / LIP_GRID) * LIP_GRID
        if min(a, b) < 0.25:
            break
        span = b if along_x else a
        sink = span * sn + 0.03
        h = (top - 0.01 + sink - span * sn) / cs_
        ch = max(0.05, round(min(a, b) / 5.0 / LIP_GRID) * LIP_GRID)
        plan, _ = ccw(cut_corners(rect(cx - a / 2, cx + a / 2, cy - b / 2, cy + b / 2), (0, 1, 2, 3), ch))
        if along_x:
            xform = tilt((cx, cy - sign * b / 2, -sink), "X", sign * deg)
        else:
            xform = tilt((cx - sign * a / 2, cy, -sink), "Y", -sign * deg)
        pts = [xform @ Vector((x, y, z)) for x, y in plan for z in (-sink, -sink + h)]
        up = [p for p in pts if p.z > 0.0]
        # Centre the tilted stone's footprint in the proxy.
        dx = cx - (min(p.x for p in up) + max(p.x for p in up)) / 2
        dy = cy - (min(p.y for p in up) + max(p.y for p in up)) / 2
        xform = Matrix.Translation((dx, dy, 0.0)) @ xform
        pts = [xform @ Vector((x, y, z)) for x, y in plan for z in (-sink, -sink + h)]
        up = [p for p in pts if p.z > 0.0]
        if all(box[0] + 0.005 <= p.x <= box[1] - 0.005 and box[2] + 0.005 <= p.y <= box[3] - 0.005
               and p.z <= top + 1e-4 for p in up):
            verts = [[bm.verts.new(xform @ Vector((x, y, z))) for x, y in plan] for z in (-sink, -sink + h)]
            m = len(plan)
            bm.faces.new(list(reversed(verts[0])))
            bm.faces.new(verts[1])
            for i in range(m):
                j = (i + 1) % m
                bm.faces.new((verts[0][i], verts[0][j], verts[1][j], verts[1][i]))
            gaps = (min(p.x for p in up) - box[0], box[1] - max(p.x for p in up),
                    min(p.y for p in up) - box[2], box[3] - max(p.y for p in up), top - max(p.z for p in up))
            return {"name": name, "size": (a, b, h), "deg": deg, "axis": "x" if along_x else "y",
                    "chamfer": ch, "gap": max(gaps)}
    raise RuntimeError(f"{name}: no lip stone fits its proxy")


def build_rim():
    root = bpy.data.objects.get(ROOT_NAME)
    if root is None:
        raise RuntimeError("no `canyon` root: open canyon.blend")
    print(f"greybox rim visuals removed: {remove_greybox(RIM_GREYBOX, RIM_PROXIES)}")
    remove_tree(RIM_GROUP)
    rng = random.Random(RIM_SEED)
    chamfer = {c: rng.choice((1.0, 1.25, 1.5, 1.75, 2.0)) for c in CORNERS}
    wall = Wall(1)
    polys, runs_all = [], []
    drop_bays = {}
    for li, (name, z0, z1, base, kind) in enumerate(RIM_LAYERS):
        if kind == "top":
            plan = butte_top()
            runs4 = [[(0.0, RIM_SIDES[k][4], 0.0)] for k in range(4)]
        else:
            drop = RIM_DROP[name]
            if drop not in drop_bays:
                # The lower drop stands mostly behind the skirt: one plane per face.
                drop_bays[drop] = [plan_bays(rng, RIM_SIDES[k][4], chamfer[CORNERS[k]], chamfer[CORNERS[(k + 1) % 4]],
                                             flat=drop == 2) for k in range(4)]
            runs4 = [layer_runs(drop_bays[drop][k], base) for k in range(4)]
            plan = layer_poly(base, runs4)
        wall.prism(plan, z1, z0, MAT_BAND if kind == "band" else MAT_BODY)
        polys.append(plan)
        runs_all.append(runs4)
    # Beside the cliffs (|y| < 9, no floor) the top rises to z 0 under the cliffs' backs.
    for s in (-1, 1):
        x0, x1 = sorted((s * CREST_IN, s * RIM_X))
        wall.prism(rect(x0, x1, -FLOOR_FULL, FLOOR_FULL), -0.5, 0.0, MAT_BODY)
    # The skirt (detail 2): wedges on the plain at the foot, mitred at the corners.
    skirt = []
    base_l = RIM_LAYERS[-1][3]
    for k in range(4):
        L = RIM_SIDES[k][4]
        cuts = [0.0]
        s = 0.0
        while True:
            s = g(s + rng.choice((4.0, 5.0, 6.0, 7.0)))
            if L - s < 4.0:
                break
            cuts.append(s)
        cuts.append(L)
        n = len(cuts) - 1
        ws = []
        for j in range(n):
            if j in (0, n - 1):
                ws.append(SKIRT_END_W)
            else:
                prev = ws[-1]
                nxt_end = j == n - 2
                ws.append(rng.choice([w for w in SKIRT_W if abs(w - prev) >= 1.0 - 1e-6
                                      and not (nxt_end and abs(w - SKIRT_END_W) < 1.0 - 1e-6)]))
        for j in range(n):
            # The buried top turns flat 1 m (corners: 2.5 m) inside the face, under the ledges.
            p_flat = base_l - (2.5 if j in (0, n - 1) else 1.0)
            rim_wedge(wall, k, cuts[j], cuts[j + 1], base_l, ws[j], p_flat, j == 0, j == n - 1)
        skirt.append(list(zip(cuts[:-1], cuts[1:], ws)))
    # Wear (detail 6): one fallen block on each ledge of each face.
    blocks = []
    for k in range(4):
        L = RIM_SIDES[k][4]
        for ua, lb in ((4, 5), (7, 8)):  # (layer above, ledge layer): the two ledges
            ra, rb = runs_at(runs_all[ua][k]), runs_at(runs_all[lb][k])
            pa, pb = RIM_LAYERS[ua][3], RIM_LAYERS[lb][3]
            for _ in range(60):
                ln = rng.choice((1.0, 1.25))
                dep = rng.choice((0.75, 1.0))
                s0 = g(rng.uniform(L * 0.25, L * 0.75 - ln))
                span = [s0 + 0.125 * j for j in range(int(ln / 0.125) + 1)]
                inner = max(pa + ra(x) for x in span)
                outer = min(pb + rb(x) for x in span)
                if outer - inner - dep >= 0.5 - 1e-6:
                    h = rng.choice((0.75, 1.0))
                    deg = rng.choice((10.0, 12.0, 15.0)) * rng.choice((-1, 1))
                    rim_block(wall, k, s0, inner + 0.25, RIM_LAYERS[lb][1], ln, dep, h, deg)
                    blocks.append((RIM_SIDES[k][0], RIM_LAYERS[lb][1], s0, ln, dep, h, deg))
                    break
            else:
                raise RuntimeError(f"no fallen block fits the {RIM_SIDES[k][0]} ledge at {RIM_LAYERS[lb][1]}")
    print(f"rim: {wall.pieces} shells, union ...")
    bmesh.ops.recalc_face_normals(wall.bm, faces=wall.bm.faces)
    mats = [bpy.data.materials[n] for n in ("M_Rock", "M_CapDark", "M_Cap", "M_RockDark")]
    pos = _bm_object(wall.bm, "_rim_pos", mats)
    empty_col = bpy.data.collections.new("_rim_ops")
    mod = pos.modifiers.new("union", "BOOLEAN")
    mod.operation, mod.solver = "UNION", "EXACT"
    mod.operand_type, mod.collection, mod.use_self = "COLLECTION", empty_col, True
    me = bpy.data.meshes.new_from_object(pos.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    mesh = pos.data
    bpy.data.objects.remove(pos, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    bpy.data.collections.remove(empty_col)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    # The plain: cut at its top and drop everything below.
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, PLAIN_Z), plane_no=(0, 0, 1), clear_inner=True)
    # Under the floor and the cliffs: the top at -0.15, the crest's inner sides and ends. The crest's
    # top (z 0) and the outer faces stay.
    hidden = []
    for f in bm.faces:
        c = f.calc_center_median()
        if c.z <= RIM_TOP - 0.01:
            continue
        crest_top = f.normal.z > 0.9 and abs(c.z) < 1e-3
        outer = abs(c.x) > RIM_X - 0.01 and f.normal.x * math.copysign(1.0, c.x) > 0.9
        if not (crest_top or outer):
            hidden.append(f)
    bmesh.ops.delete(bm, geom=hidden, context="FACES")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    # Colour per face (rule 17). The ledges are rings round the butte: cut each at the SE-NW
    # diagonal and at the SW and NE chamfers' ends first, so each piece takes one face's colour.
    levels = []
    for li in range(1, len(RIM_LAYERS)):
        z = RIM_LAYERS[li][1]
        cuts = [((0.0, 0.0), (RIM_Y, RIM_X))]
        lines = []
        for corner in ("SW", "NE"):
            a, b = corner_end(polys[li - 1], corner), corner_end(polys[li], corner)
            if a is not None and b is not None and math.dist(a, b) > 1e-3:
                cuts.append((a, (-(b[1] - a[1]), b[0] - a[0])))
                lines.append((a, b))
            else:
                lines.append(None)
        levels.append((z, lines[0], lines[1]))
        for co, no in cuts:
            faces = [f for f in bm.faces if abs(f.normal.z) > 0.999 and f.material_index == MAT_BODY
                     and abs(f.calc_center_median().z - z) < 1e-3]
            if faces:
                edges = list({e for f in faces for e in f.edges})
                verts = list({v for f in faces for v in f.verts})
                bmesh.ops.bisect_plane(bm, geom=faces + edges + verts, plane_co=(co[0], co[1], z),
                                       plane_no=(no[0], no[1], 0.0))
    bm.normal_update()
    for f in bm.faces:
        if f.material_index == MAT_BODY:
            f.material_index = rim_material(f, levels)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.05), use_dissolve_boundaries=False,
                             verts=bm.verts, edges=bm.edges, delimit={"MATERIAL"})
    bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    print(f"  sliver faces split into triangles: {fix_slivers(bm)}")
    skirt_tris = 0
    for f in bm.faces:
        c = f.calc_center_median()
        if c.z < RIM_LAYERS[-1][1] + 2.0 and poly_dist((c.x, c.y), polys[-1]) > 0.05:
            skirt_tris += len(f.verts) - 2
    # The lip stones: bone, on the floor, cut at z 0 (the floor hides their buried feet).
    lbm = bmesh.new()
    lips = [build_lip(lbm, n, k) for k, n in enumerate(LIPS)]
    bmesh.ops.recalc_face_normals(lbm, faces=lbm.faces)
    geom = list(lbm.verts) + list(lbm.edges) + list(lbm.faces)
    bmesh.ops.bisect_plane(lbm, geom=geom, plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
    group = empty(RIM_GROUP, root)
    group.location = (0.0, 0.0, 0.0)
    out = [finish_object(split_by_material(bm, 0), "Rim_Rock", "M_Rock", group),
           finish_object(split_by_material(bm, 3), "Rim_RockDark", "M_RockDark", group),
           finish_object(split_by_material(bm, MAT_BAND), "Rim_CapDark", "M_CapDark", group),
           finish_object(lbm, "Rim_Cap", "M_Cap", group)]
    bm.free()
    print("  corner chamfers " + ", ".join(f"{c} {chamfer[c]:.2f}" for c in CORNERS))
    for li, (name, z0, z1, base, kind) in enumerate(RIM_LAYERS):
        print("  %-4s z %6.2f..%6.2f base %+.2f %-6s %s" % (name, z1, z0, base, kind, " | ".join(
            RIM_SIDES[k][0][0] + " " + ",".join("%+.2f" % d for _, _, d in runs_all[li][k]) for k in range(4))))
    for k in range(4):
        print("  skirt %-5s %s" % (RIM_SIDES[k][0], ", ".join("%.2f..%.2f w %.0f" % w for w in skirt[k])))
    for b in blocks:
        print("  fallen block %-5s ledge z %.2f s %.2f %.2f x %.2f x %.2f tilt %+.0f" % b)
    for lp in lips:
        print("  %-10s %.3f x %.3f x %.3f tilt %.0f deg about %s, chamfer %.3f, largest gap to the proxy %.3f" % (
            lp["name"], *lp["size"], lp["deg"], lp["axis"], lp["chamfer"], lp["gap"]))
    faces_tris = sum(count_tris(o) for o in out[:3]) - skirt_tris
    print(f"  faces {faces_tris} triangles (budget 1300), skirt {skirt_tris} (400), lip stones {count_tris(out[3])} (300)")
    for name, b, moved in build_rim_proxies(root, polys, runs_all):
        if moved is None:  # a corner box: its chamfer face from (x, y) to (x, y), RIM_PX_DEPTH deep
            print("  proxy %-31s face (%6.2f, %6.2f) to (%6.2f, %6.2f), %.1f m deep, z %7.2f..%6.2f" % (
                name + "-convcolonly", *b[:4], RIM_PX_DEPTH, b[4], b[5]))
            continue
        print("  proxy %-31s x %7.2f..%7.2f  y %7.2f..%7.2f  z %7.2f..%6.2f%s" % (
            name + "-convcolonly", *b, "  (moved)" if moved else ""))
    check_root(root, out, 2000, "rim")


# --------------------------------------------------------------------------------------
# Horizon (sheet B "Horizon")
# --------------------------------------------------------------------------------------

HORIZON_GROUP = "CanyonHorizon"
HORIZON_SEED = 1892
# The greybox horizon: the plain, eight mesas and their caps, and 110 plant empties (289 parts).
HORIZON_GREYBOX = ["Desert"] + [f"Mesa{i}{c}" for i in range(8) for c in ("", "Cap")]
PLANT_GREYBOX = [f"Plant{i:03d}" for i in range(110)]
DESERT_HALF = 3000.0  # the plain: 6,000 m square, its top at PLAIN_Z (detail 4)
EYE_P = (0.0, -11.0, 1.7)  # PlayerSpawn's eye
EYE_E = (0.0, 11.0, 1.7)  # EnemySpawn's eye
EYE_O = (0.0, 0.0, 1.7)  # mid-lane: the rim panorama's mesas are placed from here
# Toward the sun in plan: the `Sun` in canyon.tscn stands 15 degrees off the lane toward +X from the
# player end, and TimeOfDay keeps that yaw. A face whose plan normal points away never takes sun.
TO_SUN = (math.sin(math.radians(15.0)), -math.cos(math.radians(15.0)))
HM_VIOLET, HM_PINK, HM_BONE, HM_VERM = 0, 1, 2, 3
HORIZON_MATS = ("M_CapDark", "M_RockDark", "M_Cap", "M_Rock")

# The backdrop butte (detail 1, F2). Its south face is one violet plane across the lane's axis, so
# every number is an angle from PlayerSpawn's eye and the butte holds its view at any distance.
# The face's plane: 150 m from the eye (F2 said about 80; F21 keeps 150). At 80 m the east cliff's shadow covers the
# face's west half at dawn and its lower west part at dusk, its edge right behind the enemy; from about
# 145 m out the shadow falls west of the field at every hour (sheet H, Horizon).
BUTTE_Y = 139.0
# The face's west and east edges, its top, and the cap's top (degrees). The cap's front is flush:
# an overhang would cast a shadow line across the face at noon.
BUTTE_FACE = (-6.4, 6.6, 4.3, 5.0)
# Shoulders stepping down beyond the field: (name, outer edge, top with its cap, setback in steps).
# The west one, its cap included, ends 1.4 degrees short of EnemySpawns2/A's body (9.5 degrees west,
# about 0.9 either side).
BUTTE_SHOULDERS = (("W1", -7.0, 2.0, 1), ("E1", 9.3, 2.2, 1), ("E2", 11.6, 0.25, 2))
BUTTE_DEPTH = 0.28  # the main block's depth, times the face's distance
# The roughened outline (sheet F, decision 23). The field, +/-6 degrees from below the rim line to 4
# degrees, stays the main block's one flat violet face; above it and beyond it the outline breaks into
# the vocabulary's steps, joints, and chipped corners, on the 0.25 m grid. Every block that steps down
# stands BUTTE_STEP behind its neighbour's front and back, so no two faces share a plane. The skirt and
# the plan outline (the plants keep clear of it) stay those of the blocks above (BUTTE_FACE,
# BUTTE_SHOULDERS), so the mesas and plants that follow in the seeded build do not move.
BUTTE_BODY = 6.1  # the main block's half-width (degrees): the field and a margin
BUTTE_STEP = 0.5
BUTTE_CHIP = 0.01  # a chipped cap corner: one 45 degree cut, times the face's distance (1.5 m at 150 m)
# The main cap, west to east: (west edge, east edge, top, chipped ends, setback in metres); edges and
# tops in degrees, None at the cap's own ends. Neighbours overlap, one of them set back, so the cap
# stays one broken band, 1.25 to 3.75 m thick; the gap at 0.4 degrees is a joint open to the sky
# (0.5 m). A chipped end is one 45 degree cut down to a lower neighbour, never through the whole cap,
# and every block's ends stay clear of the cap's back corner chamfers (a chip there would fold).
# Every front is flush with the face or behind it: no overhang casts a line onto the field.
BUTTE_CAP = (
    (None, -4.0, 4.85, "W", 0.0),
    (-4.2, -2.4, 5.35, "W", 0.5),
    (-2.6, 0.4, 5.0, "", 0.0),
    (0.6, 2.9, 5.75, "WE", 0.0),
    (2.7, 4.6, 5.2, "", 0.5),
    (4.4, None, 4.8, "E", 0.0),
)
# The main block's ends beyond BUTTE_BODY, a step down: (side, cap top in degrees, chipped).
BUTTE_ENDS = ((-1, 3.9, True), (1, 4.0, True))
# Shoulders split in two: (split, the inner part's cap top), in degrees. The outer part, set back,
# keeps the shoulder's top.
BUTTE_SPLITS = {"E1": (7.4, 3.1)}
# Every shoulder block breaks at its outer top edge: a 45 degree slope of this many metres times the
# face's distance (2.0 m at 150 m; W1, 2.5 m wide, takes 1.0 m) under a cap that stops where the slope
# starts, as a caprock stands over its talus. So the steps down read as broken rock, not stairs.
BUTTE_SLOPE = {"W1": 0.0067, "E1a": 0.0133, "E1b": 0.0133, "E2": 0.0133}

# Far mesas (details 2, 3, 5; F9; the vocabulary's "Far mesa"): (name, eye, bearing (0 north, 90
# east), distance, width, depth, top (degrees over the eye's horizon), chamfered local corners (0 SW,
# 1 SE, 2 NE, 3 NW), body levels (fractions of the height), insets per upper level by local side,
# notch (local x as a fraction of the width, width, depth) or None). Each faces its eye: its local
# south looks back at it and its local east is on the viewer's right.
MESAS = (
    # The north opening, from PlayerSpawn: west of 2/A's line, or east of and behind the butte.
    ("N1", EYE_P, -20.25, 128.0, 34.0, 18.0, 4.5, (2,), (0.5,), ({"E": 3.0},), (0.2, 3.0, 4.0)),
    ("N2", EYE_P, -21.0, 225.0, 52.0, 28.0, 6.25, (1,), (0.45, 0.8), ({"W": 5.0}, {"W": 9.0, "E": 3.0}), (0.15, 5.0, 5.0)),
    ("N3", EYE_P, 14.5, 235.0, 52.0, 24.0, 3.75, (0,), (0.55,), ({"W": 4.0},), (0.25, 4.0, 4.0)),
    # The south opening, from EnemySpawn: west of the lane only (the low sun stands 15 degrees east).
    ("S1", EYE_E, 197.0, 118.0, 34.0, 18.0, 4.0, (1,), (0.5,), ({"W": 3.0},), (-0.15, 3.0, 3.5)),
    ("S2", EYE_E, 199.0, 235.0, 54.0, 28.0, 5.25, (0,), (0.45, 0.8), ({"W": 5.0}, {"W": 9.0, "E": 4.0}), (0.1, 5.0, 5.0)),
    # The rim panorama, round the compass, all hidden from both spawns by the cliffs.
    ("P1", EYE_O, 38.0, 195.0, 50.0, 24.0, 4.5, (3,), (0.5,), ({"E": 4.0},), (-0.2, 4.0, 4.0)),
    ("P2", EYE_O, -47.0, 265.0, 55.0, 30.0, 5.0, (1,), (0.45, 0.8), ({"W": 5.0}, {"W": 9.0, "E": 4.0}), None),
    ("P3", EYE_O, 135.0, 215.0, 46.0, 24.0, 3.75, (2,), (0.55,), ({"W": 4.0},), (0.15, 4.0, 3.5)),
    ("P4", EYE_O, 212.0, 250.0, 52.0, 28.0, 4.75, (0,), (0.45, 0.8), ({"E": 5.0}, {"E": 8.0, "W": 4.0}), (-0.1, 4.0, 4.0)),
)
MESA_TRIS = 150  # the vocabulary's "Far mesa"
ROCK_BUDGET = 1600  # the butte and the mesas

# The plants (detail 6, F10): Main Street's final kinds, read from main_street.blend (never saved).
MAIN_STREET_BLEND = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "models",
                                 "scenarios", "main_street", "main_street.blend")
PLANT_MESH = re.compile(r"P(\d{3})_(Trunk|Arm|Tip|Body|Col[A-Z]?|Pad[A-Z]?|Clump[A-Z]?|Blade|Stick)$")
PLANT_RIGID = ("M_Cactus", "M_CactusDark")  # merged across plants, one object each
PLANT_SWAY = ("M_Scrub", "M_ScrubDry", "M_Yucca")  # the importer's sway names: one plant's own mesh each
# Main Street's seven kinds, cacti-heavy, so the swaying meshes (one draw call each) stay near 23 and
# the plants near the sheet's 25 draw calls (G6).
PLANT_MIX = (("saguaro", 14), ("saguaro_young", 8), ("barrel", 13), ("pear", 10), ("organ", 6),
             ("scrub", 6), ("yucca", 3), ("deadwood", 5))
PLANT_NEAR_BUTTE = 10  # round the backdrop butte's foot, for the look-down from the north rim
PLANT_R = (30.0, 200.0)  # the rest, on the plain this far from the canyon's origin (and clear of its skirt)
PLANT_GAP = 8.0
PLANT_SINK = 0.2  # Main Street's plants stand 0.2 m into its ground
PLANT_SCALE = (0.8, 1.4)
PLANT_BUDGET = 3400


def deg_len(d: float, deg: float) -> float:
    return d * math.tan(math.radians(deg))


def g_out(v: float) -> float:
    """Snap away from zero to the 0.25 m grid."""
    return math.copysign(math.ceil(abs(v) / GRID - 1e-9) * GRID, v)


def _corner_turns(pts):
    """The turn at each vertex of a CCW outline (radians; positive at a convex corner)."""
    n = len(pts)
    out = []
    for i in range(n):
        a, b, c = pts[i - 1], pts[i], pts[(i + 1) % n]
        t0 = math.atan2(b[1] - a[1], b[0] - a[0])
        t1 = math.atan2(c[1] - b[1], c[0] - b[0])
        out.append((t1 - t0 + math.pi) % (2.0 * math.pi) - math.pi)
    return out


def skirt_wedge(wall: Wall, a, t, nrm, sa: float, sb: float, w: float, turn_a, turn_b, mat: int, p_in: float):
    """A 35 degree wedge on the plain along one edge of a convex outline, from sa to sb: its toe w
    metres out from the edge, its slope running on into the rock to its back p_in (negative) inside.
    The profile is a triangle, so every face stays planar. At a corner (turn given) the whole end is
    mitred on the corner's bisector, so neighbours meet in a hip."""
    zb = PLAIN_Z - 0.25
    prof = [(p_in, zb), (w + 0.25 / TAN35, zb), (p_in, PLAIN_Z + (w - p_in) * TAN35)]
    rings = []
    for s, turn, sgn in ((sa, turn_a, -1.0), (sb, turn_b, 1.0)):
        ring = []
        for p, z in prof:
            ss = s if turn is None else s + sgn * p * math.tan(turn / 2.0)
            ring.append((a[0] + t[0] * ss + nrm[0] * p, a[1] + t[1] * ss + nrm[1] * p, z))
        rings.append(ring)
    wall._shell(wall.bm, rings, mat, None)


def skirt_ring(wall: Wall, outline, mat: int, rng, corner_w: float, widths, lengths) -> int:
    """A ring of skirt wedges round a convex CCW outline (detail 5, the rim's skirt): each edge cut
    into pieces of `lengths`, toes `widths` out with neighbours 1 m or more apart, the pieces at a
    corner `corner_w` out and mitred. The buried backs reach 2 m in, or less where a short mitred
    piece would fold. Returns the wedge count."""
    pts, _ = ccw(outline)
    n = len(pts)
    turn = _corner_turns(pts)
    if min(turn) < -1e-9:
        raise RuntimeError("skirt outline is not convex")
    plan = []
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        L = math.dist(a, b)
        cuts, s = [0.0], 0.0
        while True:
            s = g(s + rng.choice(lengths))
            if L - s < 0.75 * min(lengths):
                break
            cuts.append(s)
        cuts.append(L)
        m = len(cuts) - 1
        ws = []
        for j in range(m):
            if j in (0, m - 1):
                ws.append(corner_w)
                continue
            ok = [w for w in widths if abs(w - ws[-1]) >= 1.0 - 1e-6
                  and not (j == m - 2 and abs(w - corner_w) < 1.0 - 1e-6)]
            ws.append(rng.choice(ok))
        plan.append((a, b, L, cuts, ws))
    p_in = -2.0
    for i, (a, b, L, cuts, ws) in enumerate(plan):
        m = len(cuts) - 1
        for j in range(m):
            ta = math.tan(turn[i] / 2.0) if j == 0 else 0.0
            tb = math.tan(turn[(i + 1) % n] / 2.0) if j == m - 1 else 0.0
            if ta + tb > 1e-9:
                p_in = max(p_in, -(cuts[j + 1] - cuts[j] - 0.25) / (ta + tb))
    if p_in > -0.25:
        raise RuntimeError("skirt outline has an edge too short for its corners")
    count = 0
    for i, (a, b, L, cuts, ws) in enumerate(plan):
        t = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
        nrm = (t[1], -t[0])  # outward on a CCW outline
        m = len(cuts) - 1
        for j in range(m):
            # Neighbours along an edge overlap 0.25 m, so no two end faces coincide (the exact union
            # leaves coincident opposite faces inside the rock).
            sa = cuts[j] - (0.25 if j > 0 else 0.0)
            sb = cuts[j + 1] + (0.25 if j < m - 1 else 0.0)
            skirt_wedge(wall, a, t, nrm, sa, sb, ws[j], turn[i] if j == 0 else None,
                        turn[(i + 1) % n] if j == m - 1 else None, mat, p_in)
            count += 1
    return count


def union_horizon(wall: Wall, recolour=None, split=None):
    """One exact self-union of a rock's shells minus its notch boxes, cut at the plain's top (no face
    on the plain's plane), coplanar neighbours dissolved per material. `split` (material index, z)
    cuts that material's faces at z before `recolour` runs. Returns a bmesh."""
    mats = [bpy.data.materials[n] for n in HORIZON_MATS]
    bmesh.ops.recalc_face_normals(wall.bm, faces=wall.bm.faces)
    pos = _bm_object(wall.bm, "_hz_pos", mats)
    ops = bpy.data.collections.new("_hz_ops")
    mod = pos.modifiers.new("union", "BOOLEAN")
    mod.operation, mod.solver = "UNION", "EXACT"
    mod.operand_type, mod.collection, mod.use_self = "COLLECTION", ops, True
    temp = [pos]
    if len(wall.cuts.faces):
        bmesh.ops.recalc_face_normals(wall.cuts, faces=wall.cuts.faces)
        cut = _bm_object(wall.cuts, "_hz_cut", mats)
        m2 = pos.modifiers.new("notches", "BOOLEAN")
        m2.operation, m2.solver = "DIFFERENCE", "EXACT"
        m2.operand_type, m2.object, m2.use_self = "OBJECT", cut, True
        cut.hide_set(True)
        temp.append(cut)
    me = bpy.data.meshes.new_from_object(pos.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    for o in temp:
        mesh = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.meshes.remove(mesh)
    bpy.data.collections.remove(ops)
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, PLAIN_Z), plane_no=(0, 0, 1), clear_inner=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    if split is not None:
        faces = [f for f in bm.faces if f.material_index == split[0]]
        if faces:
            geom = faces + list({e for f in faces for e in f.edges}) + list({v for f in faces for v in f.verts})
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, split[1]), plane_no=(0, 0, 1))
    bm.normal_update()
    if recolour is not None:
        for f in bm.faces:
            f.material_index = recolour(f)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.05), use_dissolve_boundaries=False,
                             verts=bm.verts, edges=bm.edges, delimit={"MATERIAL"})
    bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    fix_slivers(bm)
    drop_needles(bm)
    return bm


def drop_needles(bm) -> int:
    """A needle (a face of collinear points) left where a cut meets a chamfer: merge it into the
    face across its long edge, then re-split any face that now tessellates to a zero-area triangle."""
    def needle(f):
        if len(f.verts) != 3:
            return False
        a, b, c = (v.co for v in f.verts)
        return (b - a).cross(c - a).length < 1e-6 * max(1.0, max(e.calc_length() for e in f.edges))

    needles = [f for f in bm.faces if needle(f)]  # BMFace.calc_area misreads exactly collinear points
    for f in needles:
        if not f.is_valid:
            continue
        e = max(f.edges, key=lambda e: e.calc_length())
        if len(e.link_faces) == 2:
            bmesh.ops.dissolve_edges(bm, edges=[e], use_verts=False)
        else:
            bmesh.ops.delete(bm, geom=[f], context="FACES_ONLY")
    if needles:
        fix_slivers(bm)
    return len(needles)


def butte_colour(f) -> int:
    """Rule 17 per face: the butte's faces the sun never reaches take the pink; the rest stay violet."""
    if f.material_index != HM_VIOLET:
        return f.material_index
    n = f.normal
    h = math.hypot(n.x, n.y)
    if h > 0.05 and (n.x * TO_SUN[0] + n.y * TO_SUN[1]) / h < -1e-3:
        return HM_PINK
    return HM_VIOLET


def butte_layout():
    """The butte's pieces [(name, body plan, body top, cap plan, cap top)] and its plan outline."""
    D = BUTTE_Y - EYE_P[1]
    west, east, top, cap = BUTTE_FACE
    xw, xe = g_out(-deg_len(D, -west)), g_out(deg_len(D, east))
    zt = g_out(EYE_P[2] + deg_len(D, top))
    zc = g(EYE_P[2] + deg_len(D, cap))
    y0, y1 = BUTTE_Y, BUTTE_Y + g(BUTTE_DEPTH * D)
    ch = g(0.04 * D)
    sb = max(2.0, g(0.03 * D))
    over = 0.5
    main = [(xw, y0), (xe, y0), (xe, y1 - ch), (xe - ch, y1), (xw + ch, y1), (xw, y1 - ch)]
    pieces = [("Main", main, zt, offset_polygon(main, [0.0] + [-over] * 5), zc)]
    t_cap = max(0.5, g(0.6 * (zc - zt)))
    inner = {"W": xw, "E": xe}
    back = {"W": y1 - ch - sb, "E": y1 - ch - sb}
    rows = {}
    for name, edge, top_deg, k in BUTTE_SHOULDERS:
        side = name[0]
        ys = y0 + sb * k
        dk = ys - EYE_P[1]
        xo = g(math.copysign(deg_len(dk, abs(edge)), edge))
        ztop = g(EYE_P[2] + deg_len(dk, top_deg))
        yb = back[side] - (sb * (k - 1) * 2 if k > 1 else 0.0)
        xi = inner[side]
        width = abs(xo - xi)
        c = g(min(0.03 * D, width - 1.5)) if width >= 3.0 else 0.0
        s = 1.0 if side == "E" else -1.0
        # Each shoulder runs 0.5 m into its neighbour, so no two faces share a plane.
        x_in = xi - s * 0.5
        pts = [(x_in, ys), (xo, ys)]
        pts += [(xo, yb - c), (xo - s * c, yb)] if c > 0 else [(xo, yb)]
        pts += [(x_in, yb)]
        plan, _ = ccw(pts)
        pieces.append((name, plan, ztop - t_cap, offset_polygon(plan, [-over] * len(plan)), ztop))
        rows[name] = (xi, xo, ys, yb, c)
        inner[side], back[side] = xo, yb
    # The outline round the foot, counter-clockwise from the face's west end.
    e1, e2, w1 = rows["E1"], rows["E2"], rows["W1"]
    out = [(xw, y0), (xe, y0), (xe, e1[2]), (e1[1], e1[2]), (e1[1], e2[2]), (e2[1], e2[2])]
    out += [(e2[1], e2[3] - e2[4]), (e2[1] - e2[4], e2[3])] if e2[4] else [(e2[1], e2[3])]
    out += [(e1[1], e2[3])]
    out += [(e1[1], e1[3] - e1[4]), (e1[1] - e1[4], e1[3])] if e1[4] else [(e1[1], e1[3])]
    out += [(xe, e1[3]), (xe, y1 - ch), (xe - ch, y1), (xw + ch, y1), (xw, y1 - ch), (xw, w1[3])]
    out += [(w1[1] + w1[4], w1[3]), (w1[1], w1[3] - w1[4])] if w1[4] else [(w1[1], w1[3])]
    out += [(w1[1], w1[2]), (xw, w1[2])]
    outline, _ = ccw(out)
    if not _simple(outline):
        raise RuntimeError("butte outline folds")
    return pieces, butte_blocks(pieces, rows, D, over, t_cap), outline, D


def _clip_x(plan, lo=None, hi=None):
    """A convex CCW plan cut to lo <= x <= hi."""
    pts = list(plan)
    if hi is not None:
        pts = clip_half(pts, (hi, 0.0), (hi, 1.0))
    if lo is not None:
        pts = clip_half(pts, (lo, 1.0), (lo, 0.0))
    pts, _ = ccw(pts)
    return pts


def _edge_offsets(plan, front, back, side, inner_x=None, inner=0.0):
    """Per-edge offsets for offset_polygon (positive inward): the front (facing -Y), the back edges
    (facing +Y, the chamfers too), the sides, and the inner side at x inner_x."""
    offs = []
    n = len(plan)
    for i in range(n):
        a, b = plan[i], plan[(i + 1) % n]
        L = math.dist(a, b)
        ny = -(b[0] - a[0]) / L  # outward normal's y on a CCW outline
        if inner_x is not None and abs(a[0] - inner_x) < 1e-6 and abs(b[0] - inner_x) < 1e-6:
            offs.append(inner)
        elif ny < -0.99:
            offs.append(front)
        elif ny > 0.3:
            offs.append(back)
        else:
            offs.append(side)
    return offs


def _side_flags(plan, x):
    """Chamfer flags: the plan's edge along x (a chipped cap corner)."""
    n = len(plan)
    return [abs(plan[i][0] - x) < 1e-6 and abs(plan[(i + 1) % n][0] - x) < 1e-6 for i in range(n)]


def butte_blocks(pieces, rows, D, over, t_cap):
    """The roughened butte (BUTTE_BODY, BUTTE_CAP, BUTTE_ENDS, BUTTE_SPLITS, BUTTE_SLOPE): [(name, body
    plan, body top, cap plan, cap top, cap chamfer flags, body chamfer flags, body chamfer)]. The main
    block keeps the field; its cap breaks into blocks and notches, its ends step down, and the
    shoulders split, each step set back BUTTE_STEP, their outer corners broken into slopes."""
    main, zt = pieces[0][1], pieces[0][2]
    y0 = BUTTE_Y
    xb = g_out(deg_len(D, BUTTE_BODY))
    body = _clip_x(main, -xb, xb)
    cap = offset_polygon(body, _edge_offsets(body, 0.0, -over, -over))
    blocks = [("Main", body, zt, None, None, None, None, 0.0)]
    for i, (w, e, top, chip, setback) in enumerate(BUTTE_CAP):
        plan = _clip_x(cap, None if w is None else g(deg_len(D, w)), None if e is None else g(deg_len(D, e)))
        if setback:
            plan, _ = ccw(clip_half(plan, (0.0, y0 + setback), (1.0, y0 + setback)))
        xs = [p[0] for p in plan]
        flags = [a or b for a, b in zip(_side_flags(plan, min(xs)) if "W" in chip else [False] * len(plan),
                                        _side_flags(plan, max(xs)) if "E" in chip else [False] * len(plan))]
        blocks.append((f"Cap{i}", None, zt, plan, g(EYE_P[2] + deg_len(D, top)), flags, None, 0.0))
    for s, top, chip in BUTTE_ENDS:
        cut = s * (xb - 0.5)  # runs 0.5 m into the main block
        plan = _clip_x(main, cut if s > 0 else None, cut if s < 0 else None)
        plan = offset_polygon(plan, _edge_offsets(plan, BUTTE_STEP, BUTTE_STEP, 0.0))
        z_cap = g(EYE_P[2] + deg_len(y0 + BUTTE_STEP - EYE_P[1], top))
        cplan = offset_polygon(plan, _edge_offsets(plan, 0.0, -over, -over, cut, 0.0))
        xs = [p[0] for p in cplan]
        flags = _side_flags(cplan, min(xs) if s < 0 else max(xs)) if chip else None
        blocks.append(("W0" if s < 0 else "E0", plan, z_cap - t_cap, cplan, z_cap, flags, None, 0.0))
    for name, plan, z_body, cap_plan, z_cap in pieces[1:]:
        s = 1.0 if name[0] == "E" else -1.0
        parts = [(name, plan, z_body, z_cap)]
        if name in BUTTE_SPLITS:
            split, top = BUTTE_SPLITS[name]
            dk = rows[name][2] - EYE_P[1]
            xs_ = g(s * deg_len(dk, split))
            z_in = g(EYE_P[2] + deg_len(dk, top))
            inner = _clip_x(plan, None if s > 0 else xs_, xs_ if s > 0 else None)
            outer = _clip_x(plan, xs_ - 0.5 if s > 0 else None, None if s > 0 else xs_ + 0.5)
            outer = offset_polygon(outer, _edge_offsets(outer, BUTTE_STEP, BUTTE_STEP, 0.0))
            parts = [(name + "a", inner, z_in - t_cap, z_in), (name + "b", outer, z_body, z_cap)]
        for pname, pplan, zb, zc in parts:
            # Its outer top edge breaks into a 45 degree slope; the cap stops on it.
            xs = [p[0] for p in pplan]
            xo = max(xs) if s > 0 else min(xs)
            c = g(BUTTE_SLOPE[pname] * D)
            bflags = _side_flags(pplan, xo)
            cplan = offset_polygon(pplan, [c if f else -over for f in bflags])
            blocks.append((pname, pplan, zb, cplan, zc, None, bflags, c))
    return blocks


def build_butte(rng):
    pieces, blocks, outline, D = butte_layout()
    wall = Wall(1)
    chip = g(BUTTE_CHIP * D)
    for name, plan, z_body, cap_plan, z_cap, flags, bflags, slope in blocks:
        if plan is not None:
            if slope > 0:
                wall.prism(plan, PLAIN_Z - 0.25, z_body, HM_VIOLET, chamfer=slope, chamfer_edges=bflags)
            else:
                wall.prism(plan, PLAIN_Z - 0.25, z_body, HM_VIOLET)
        if cap_plan is not None:
            if flags is not None and any(flags):
                # One cut, never through the whole cap: a 1.0 m cap keeps 0.25 m of its end.
                wall.prism(cap_plan, z_body, z_cap, HM_BONE, chamfer=min(chip, z_cap - z_body - GRID), chamfer_edges=flags)
            else:
                wall.prism(cap_plan, z_body, z_cap, HM_BONE)
    k = D / 80.0
    # The skirt's toes scale with the height, as on the mesas (the rim's: 6 to 9 m on a 24 m drop).
    corner_w = g(max(4.0, 0.15 * (pieces[0][4] - PLAIN_Z)))
    # One ring per piece, each convex: where pieces meet, the union keeps the higher slope, so the
    # skirt runs into valleys there and turns the outer corners in hips.
    wedges = 0
    for name, plan, z_body, cap_plan, z_cap in pieces:
        wedges += skirt_ring(wall, plan, HM_VIOLET, rng, corner_w, [corner_w + 1.0, corner_w + 2.0, corner_w + 3.0],
                             [g(v * k) for v in (5.0, 6.0, 7.0, 8.0)])
    bm = union_horizon(wall, butte_colour)
    for name, plan, z_body, cap_plan, z_cap, flags, bflags, slope in blocks:
        pl = plan if plan is not None else cap_plan
        xs = [p[0] for p in pl]
        az = [math.degrees(math.atan2(x, min(p[1] for p in pl) - EYE_P[1])) for x in (min(xs), max(xs))]
        print("  butte %-4s x %7.2f..%6.2f (%5.2f..%5.2f deg) y %6.2f..%6.2f body top %6.2f cap %s%s%s" % (
            name, min(xs), max(xs), az[0], az[1], min(p[1] for p in pl), max(p[1] for p in pl), z_body,
            "-" if cap_plan is None else "top %6.2f (%.2f deg)" % (z_cap, math.degrees(math.atan2(
                z_cap - EYE_P[2], min(p[1] for p in cap_plan) - EYE_P[1]))),
            ", cap chipped %.2f" % min(chip, z_cap - z_body - GRID) if flags is not None and any(flags) else "",
            ", outer corner sloped %.2f" % slope if slope > 0 else ""))
    for name, plan, z_body, cap_plan, z_cap in pieces:
        xs = [p[0] for p in plan]
        print("  skirt ring %-4s x %7.2f..%6.2f y %6.2f..%6.2f" % (
            name, min(xs), max(xs), min(p[1] for p in plan), max(p[1] for p in plan)))
    print(f"  butte skirt: {wedges} wedges, corner toes {corner_w:.2f} m")
    return bm, outline, corner_w + 3.0


def mesa_layout(spec):
    """World plans of one far mesa: (centre, base plan, level plans, cap plan, heights, notch box)."""
    name, eye, bearing, dist, W, D, top, chamfers, levels, insets, notch = spec
    b = math.radians(bearing)
    cx, cy = eye[0] + dist * math.sin(b), eye[1] + dist * math.cos(b)
    yaw = math.radians(-round(bearing / 15.0) * 15.0)
    cs_, sn = math.cos(yaw), math.sin(yaw)

    def world(p):
        return (cx + p[0] * cs_ - p[1] * sn, cy + p[0] * sn + p[1] * cs_)

    local = rect(-W / 2, W / 2, -D / 2, D / 2)
    if chamfers:
        local = cut_corners(local, set(chamfers), g(0.2 * min(W, D)))
    base, _ = ccw([(g(x), g(y)) for x, y in (world(p) for p in local)])
    # Each local side's outward normal in the world, for the insets.
    sides = {"S": (sn, -cs_), "E": (cs_, sn), "N": (-sn, cs_), "W": (-cs_, -sn)}
    z_top = g(eye[2] + deg_len(dist, top))
    H = z_top - PLAIN_Z
    t_cap = max(1.5, g(0.07 * H))
    plans, zs = [base], [PLAIN_Z - 0.25]
    for li, frac in enumerate(levels):
        zs.append(g(PLAIN_Z + frac * H))
        offs = []
        n = len(base)
        for i in range(n):
            a, c = base[i], base[(i + 1) % n]
            ln = math.dist(a, c)
            nx, ny = (c[1] - a[1]) / ln, -(c[0] - a[0]) / ln
            v = 0.5 * (li + 1)  # each level steps in 0.5 m more (rule 4), so no faces share a plane
            for s, d in insets[li].items():
                if nx * sides[s][0] + ny * sides[s][1] > 0.5:
                    v = max(v, d)
            offs.append(v)
        plans.append(offset_polygon(base, offs))
    zs.append(z_top - t_cap)
    cap = offset_polygon(plans[-1], [-0.75] * len(plans[-1]))
    box = None
    if notch is not None:
        fx, nw, nd = notch
        x0 = fx * W
        box = ([world(p) for p in rect(x0 - nw / 2, x0 + nw / 2, -D, D)], z_top - nd, z_top + 1.0)
    return (cx, cy), base, plans, zs, cap, z_top, box


def build_mesa(spec, rng):
    centre, base, plans, zs, cap, z_top, box = mesa_layout(spec)
    wall = Wall(1)
    for plan, z0, z1 in zip(plans, zs[:-1], zs[1:]):
        wall.prism(plan, z0, z1, HM_VERM)
    wall.prism(cap, zs[-1], z_top, HM_BONE)
    if box is not None:
        # The notch's cut faces take a spare index, then the colour of the band they cut: bone in the
        # cap, vermilion below it.
        wall.prism(box[0], box[1], box[2], HM_PINK, cut=True)
    H = z_top - PLAIN_Z
    corner_w = g(max(4.0, 0.12 * H))
    widths = [corner_w + 1.0, corner_w + 2.0, corner_w + 3.0]
    wedges = skirt_ring(wall, base, HM_VERM, rng, corner_w, widths, (12.0, 14.0, 16.0, 18.0))
    z_cap = zs[-1]

    def notch_colour(f):
        if f.material_index != HM_PINK:
            return f.material_index
        return HM_BONE if f.calc_center_median().z > z_cap else HM_VERM

    bm = union_horizon(wall, notch_colour, (HM_PINK, z_cap))
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    print("  mesa %s at (%7.1f, %7.1f), %3.0f m out, top z %5.2f (%2.0f m over the plain), %d levels, %d wedges, "
          "notch %s: %d triangles" % (spec[0], centre[0], centre[1], math.hypot(*centre), z_top, H, len(plans),
                                      wedges, "yes" if box else "no", tris))
    if tris > MESA_TRIS:
        raise RuntimeError(f"mesa {spec[0]}: {tris} triangles (vocabulary: {MESA_TRIS})")
    return bm, base, corner_w + 3.0


def _append_bm(dst, src) -> None:
    me = bpy.data.meshes.new("_hz_tmp")
    src.to_mesh(me)
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)


def _principled_values(mat):
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    return tuple(bsdf.inputs["Base Color"].default_value)[:3], bsdf.inputs["Roughness"].default_value


def plant_kind(parts) -> str:
    words = {p.rstrip("AB") for p in parts}
    for word, kind in (("Blade", "yucca"), ("Clump", "scrub"), ("Stick", "deadwood"), ("Body", "barrel"),
                       ("Pad", "pear"), ("Col", "organ"), ("Arm", "saguaro")):
        if word in words:
            return kind
    if words == {"Trunk"}:
        return "saguaro_young"
    raise RuntimeError(f"unknown plant parts {sorted(parts)}")


def load_main_street_plants():
    """Appends Main Street's final plant meshes (env_desert_scatter's `P###_<part>`) read-only; the
    source .blend is never written. Returns ({kind: [[(part, mesh, base material)]]}, loaded meshes)."""
    with bpy.data.libraries.load(MAIN_STREET_BLEND, link=False) as (src, dst):
        names = sorted(n for n in src.meshes if PLANT_MESH.match(n))
        dst.meshes = list(names)  # filled in place with the loaded meshes
    by_plant = {}
    for name, me in zip(names, dst.meshes):
        num, part = PLANT_MESH.match(name).groups()
        by_plant.setdefault(num, []).append((part, me, me.materials[0].name.split("__")[0]))
    pools = {}
    for num in sorted(by_plant):
        parts = by_plant[num]
        pools.setdefault(plant_kind([p for p, _, _ in parts]), []).append(parts)
    return pools, list(dst.meshes)


def plant_materials(loaded):
    """The canyon's per-GLB plant copies (`M_Cactus__canyon`), checked equal to Main Street's. A copy
    the greybox lacked (`M_Yucca__canyon`) is made from Main Street's."""
    source = {}
    for me in loaded:
        for m in me.materials:
            source[m.name.split("__")[0]] = m
    out = {}
    for base in PLANT_RIGID + PLANT_SWAY:
        ms = source[base]
        mine = bpy.data.materials.get(base + "__canyon")
        if mine is None:
            mine = ms.copy()
            mine.name = base + "__canyon"
            print(f"  made {mine.name} from {ms.name}")
        (c1, r1), (c2, r2) = _principled_values(mine), _principled_values(ms)
        if max(abs(a - b) for a, b in zip(c1, c2)) > 1e-4 or abs(r1 - r2) > 1e-4:
            raise RuntimeError(f"{mine.name} differs from Main Street's {ms.name}")
        out[base] = mine
    return out


def drop_main_street(loaded) -> None:
    mats = {m for me in loaded for m in me.materials if m is not None}
    for me in loaded:
        bpy.data.meshes.remove(me)
    for m in mats:
        if m.users == 0 and m.name.endswith("__env_desert_scatter"):
            bpy.data.materials.remove(m)
    for lib in list(bpy.data.libraries):
        if lib.filepath.replace("\\", "/").endswith("main_street/main_street.blend"):
            bpy.data.libraries.remove(lib)


def _hull(pts):
    pts = sorted(set(pts))

    def half(seq):
        h = []
        for p in seq:
            while len(h) >= 2 and (h[-1][0] - h[-2][0]) * (p[1] - h[-2][1]) - (h[-1][1] - h[-2][1]) * (p[0] - h[-2][0]) <= 0:
                h.pop()
            h.append(p)
        return h

    lo, hi = half(pts), half(reversed(pts))
    return lo[:-1] + hi[:-1]


def place_plants(rng, butte_hull, butte_toe, avoid):
    """Seeded spots: PLANT_NEAR_BUTTE round the butte's foot, the rest on the plain within
    PLANT_R of the canyon's origin, PLANT_GAP apart, clear of every skirt."""
    spots = []

    def free(p, gap):
        return all(math.dist(p, q) >= gap for q in spots) and all(poly_dist(p, poly) >= m for poly, m in avoid)

    n = len(butte_hull)
    edges = [(butte_hull[i], butte_hull[(i + 1) % n]) for i in range(n)]
    perim = sum(math.dist(a, b) for a, b in edges)
    for _ in range(4000):
        if len(spots) >= PLANT_NEAR_BUTTE:
            break
        s = rng.uniform(0.0, perim)
        for a, b in edges:
            ln = math.dist(a, b)
            if s <= ln:
                break
            s -= ln
        t = ((b[0] - a[0]) / ln, (b[1] - a[1]) / ln)
        out = rng.uniform(butte_toe + 1.5, butte_toe + 12.0)
        p = (a[0] + t[0] * s + t[1] * out, a[1] + t[1] * s - t[0] * out)
        if poly_dist(p, butte_hull) >= butte_toe + 1.5 and free(p, 5.0):
            spots.append(p)
    total = sum(c for _, c in PLANT_MIX)
    for _ in range(20000):
        if len(spots) >= total:
            break
        r = math.sqrt(rng.uniform(PLANT_R[0] ** 2, PLANT_R[1] ** 2))
        a = rng.uniform(0.0, 2.0 * math.pi)
        p = (r * math.cos(a), r * math.sin(a))
        if poly_dist(p, butte_hull) >= butte_toe + 1.5 and free(p, PLANT_GAP):
            spots.append(p)
    if len(spots) != total:
        raise RuntimeError(f"only {len(spots)} plant spots")
    return spots


def build_plants(rng, group, spots):
    """Rigid cactus parts merge across plants per material; every swaying part stays one plant's own
    mesh, its origin at that plant's base (the importer reads each sway mesh's own height)."""
    pools, loaded = load_main_street_plants()
    mats = plant_materials(loaded)
    kinds = [k for k, c in PLANT_MIX for _ in range(c)]
    rng.shuffle(kinds)
    rigid = {b: bmesh.new() for b in PLANT_RIGID}
    out, rows, tris = [], [], 0
    for i, (spot, kind) in enumerate(zip(spots, kinds)):
        parts = rng.choice(pools[kind])
        yaw = rng.uniform(0.0, 360.0)
        scale = rng.uniform(*PLANT_SCALE)
        base = Vector((spot[0], spot[1], PLAIN_Z - PLANT_SINK))
        turn = Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Scale(scale, 4)
        n_tris = 0
        for part, src, mat_base in parts:
            me = src.copy()
            me.materials.clear()
            if mat_base in PLANT_RIGID:
                me.transform(Matrix.Translation(base) @ turn)
                rigid[mat_base].from_mesh(me)
                n_tris += sum(len(p.vertices) - 2 for p in me.polygons)
                bpy.data.meshes.remove(me)
                continue
            if mat_base not in PLANT_SWAY:
                raise RuntimeError(f"plant material {mat_base} is neither rigid nor swaying")
            me.transform(turn)
            name = f"Horizon_Plant{i:02d}_{part}"
            me.name = name
            me.materials.append(mats[mat_base])
            obj = bpy.data.objects.new(name, me)
            link(obj, group)
            obj.location = base
            out.append(obj)
            n_tris += sum(len(p.vertices) - 2 for p in me.polygons)
        tris += n_tris
        rows.append((i, kind, spot, yaw, scale, n_tris))
    for b, bm in rigid.items():
        me = bpy.data.meshes.new("Horizon_" + b[2:])
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mats[b])
        obj = bpy.data.objects.new("Horizon_" + b[2:], me)
        link(obj, group)
        out.insert(0, obj)
    drop_main_street(loaded)
    counts = {}
    for _, kind, _, _, _, _ in rows:
        counts[kind] = counts.get(kind, 0) + 1
    print("  plants: " + ", ".join(f"{k} {counts.get(k, 0)}" for k, _ in PLANT_MIX))
    for i, kind, spot, yaw, scale, n_tris in rows:
        print("  plant %02d %-13s (%7.1f, %7.1f) %3.0f m out, yaw %5.1f, scale %.2f, %3d triangles" % (
            i, kind, spot[0], spot[1], math.hypot(*spot), yaw, scale, n_tris))
    print(f"  plants: {len(rows)}, {tris} triangles (budget {PLANT_BUDGET}), {len(out)} mesh objects (draw calls)")
    if tris > PLANT_BUDGET:
        raise RuntimeError("over the plants' budget")
    return out


def build_horizon():
    root = bpy.data.objects.get(ROOT_NAME)
    if root is None:
        raise RuntimeError("no `canyon` root: open canyon.blend")
    removed = remove_greybox(HORIZON_GREYBOX, [])
    plants = 0
    for name in PLANT_GREYBOX:
        if bpy.data.objects.get(name) is not None:
            remove_tree(name)
            plants += 1
    print(f"greybox horizon visuals removed: {removed}, plants {plants}")
    remove_tree(HORIZON_GROUP)
    group = empty(HORIZON_GROUP, root)
    group.location = (0.0, 0.0, 0.0)
    rng = random.Random(HORIZON_SEED)
    # The plain (detail 4): one face at z -24, Main Street's desert dirt; no bottom, no sides.
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, PLAIN_Z)) for x, y in rect(-DESERT_HALF, DESERT_HALF, -DESERT_HALF, DESERT_HALF)]
    bm.faces.new(vs)
    out = [finish_object(bm, "Horizon_Desert", "M_SandFar", group)]
    # The butte and the mesas, merged per material.
    acc = {m: bmesh.new() for m in (HM_VIOLET, HM_PINK, HM_BONE, HM_VERM)}
    bm, outline, butte_toe = build_butte(rng)
    rock_tris = sum(len(f.verts) - 2 for f in bm.faces)
    print(f"  butte: {rock_tris} triangles")
    for m, dst in acc.items():
        part = split_by_material(bm, m)
        _append_bm(dst, part)
        part.free()
    bm.free()
    avoid = [(box_poly((-16.0, 16.0, -14.6, 14.6)), 11.0)]
    for spec in MESAS:
        bm, base, toe = build_mesa(spec, rng)
        rock_tris += sum(len(f.verts) - 2 for f in bm.faces)
        for m, dst in acc.items():
            part = split_by_material(bm, m)
            _append_bm(dst, part)
            part.free()
        bm.free()
        avoid.append((base, toe + 2.0))
    print(f"  butte and mesas: {rock_tris} triangles (budget {ROCK_BUDGET})")
    if rock_tris > ROCK_BUDGET:
        raise RuntimeError("over the butte and mesas' budget")
    for m, name in ((HM_VIOLET, "Horizon_CapDark"), (HM_PINK, "Horizon_RockDark"), (HM_BONE, "Horizon_Cap"),
                    (HM_VERM, "Horizon_Rock")):
        bmesh.ops.remove_doubles(acc[m], verts=acc[m].verts, dist=1e-5)
        print(f"  {HORIZON_MATS[m]}: needles merged {drop_needles(acc[m])}")
        out.append(finish_object(acc[m], name, HORIZON_MATS[m], group))
    hull = _hull(outline)
    spots = place_plants(rng, hull, butte_toe, avoid)
    out += build_plants(rng, group, spots)
    check_root(root, out, 5000, "horizon")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    part = argv[argv.index("--part") + 1] if "--part" in argv else None
    if not bpy.data.filepath.replace("\\", "/").endswith("scenarios/canyon/canyon.blend"):
        raise RuntimeError("run with assets/models/scenarios/canyon/canyon.blend loaded")
    builds = {"cliffs": build_cliffs, "cover": build_cover, "floor": build_floor, "rim": build_rim,
              "horizon": build_horizon}
    if part not in builds:
        raise RuntimeError("--part cliffs | cover | floor | rim | horizon")
    set_palette()
    builds[part]()
    bpy.ops.wm.save_mainfile()
    print(f"saved {bpy.data.filepath}")
    print("BUILD_OK")


main()
