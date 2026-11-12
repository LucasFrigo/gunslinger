"""Build the horizon_ridge span finals inside train_rooftop.blend (headless).
Design: docs/design/scenarios/train_rooftop.md, B "`horizon_ridge`: rules for all three spans", `Canyon`, `Mesa`, and
`Butte`; decisions F15 (closed ends), F16, F17 (budgets), and F19 (this script).

Opens assets/models/scenarios/train_rooftop/train_rooftop.blend itself, rebuilds the asked spans under the
`horizon_ridge` root, writes the four rock colours (sheet A, Palette), and saves. Export with
dev/unwrap_per_glb_blender.py afterwards. Every other root (the train GLBs) is left untouched, and the script never
calls scenery_uv.process_scene() (F19, G7). Never re-run dev/build_train_rooftop_blender.py: it wipes the finals.

    --part canyon   deletes every child of the `Canyon` span (the greybox `Talus`, `Wall`, `Buttress`, `Cap`, or an
                    earlier final) and builds four merged objects under it: `Canyon_Rock` (faces the sun reaches),
                    `Canyon_RockDark` (faces it never reaches), `Canyon_CapDark` (the violet band) and `Canyon_Cap`
                    (the bone cap blocks and the fallen blocks). A ridge on a 35 degree apron, turned planes on its
                    +X face, a lit sawtooth on its -X face, a violet band, five skyline segments (four bone cap
                    blocks and a saddle), two pillars a face, wear, and closed ends that step down twice.
    --part mesa     the same for the `Mesa` span (`Mesa_Rock`, `Mesa_RockDark`, `Mesa_CapDark`, `Mesa_Cap`): a wide
                    lower tier carrying the band, the turned planes, and the sawtooth under a broken bone rim, and
                    an upper tier set back 2.25 m on both faces under its own broken rim with a notch.
    --part butte    the same for the `Butte` span (`Butte_Rock`, `Butte_RockDark`, `Butte_Cap`; no band): three
                    pillars of two chamfered blocks each under an overhanging bone cap block, 31, 39, and 20 m tall,
                    each on its own skirt of 35 degree wedges, one top block leaning 3 degrees. Its up-facing faces
                    over 6.5 m are deleted (rule 27: no eye in the game reaches them).
    --part all      canyon, mesa, and butte in turn.

The span roots keep their names and their parked places beside the train (`PARKED_CHILDREN` in
dev/unwrap_scenery_blender.py: the export moves them to the origin). Every object sits at its span's origin with zero
rotation and carries 8 m tiling UVs (`uv_role` `tiling`), so the tiles run level across pieces.

Every span is a set of closed prisms placed by explicit tables on the 0.25 m grid (slabs, blocks, 35 degree wedges,
pillars, fallen blocks), each slab's foot sunk 0.25 m into the slab under it, joined by one exact self-union, cut at
z 0 (the terrain's top is at 0.12, so no face lies there), coloured per face by this scene's sun (colour()), and
dissolved into one planar n-gon per flat region per material. Nothing is random: a re-run gives the same mesh (the
printed geometry hash). The triangle budgets (sheet B, F17) are hard, because the belt draws 20 copies of each.

Run:
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/build_horizon_ridge_finals_blender.py -- --part canyon  (or mesa, butte, all)
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map train_rooftop --glb horizon_ridge
"""
from __future__ import annotations

import hashlib
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_uv  # noqa: E402
from blender_kit import count_tris, flat_shade  # noqa: E402

BLEND = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "models", "scenarios",
                     "train_rooftop", "train_rooftop.blend")
ROOT_NAME = "horizon_ridge"

# Sheet A, Palette: the Canyon's four rock values (linear Base Color). Roughness 0.9, metallic 0 (rule 23).
# Tiling names: one shared material each, no per-GLB copies.
PALETTE = {
    "M_Rock": (0.694, 0.063, 0.024),  # vermilion #D9472B: faces the sun reaches
    "M_RockDark": (0.888, 0.381, 0.352),  # pink cliff #F2A6A0: faces it never reaches
    "M_CapDark": (0.209, 0.105, 0.462),  # band violet #7E5BB5
    "M_Cap": (0.807, 0.723, 0.552),  # bone #E8DDC4: caps and fallen cap blocks
}
# Material slots while building. BODY faces are split into ROCK and DARK by their normal after the union.
M_ROCK, M_BAND, M_BONE, M_DARK = 0, 1, 2, 3
M_BODY = M_ROCK
SLOT_MATS = ("M_Rock", "M_CapDark", "M_Cap", "M_RockDark")
SLOT_SUFFIX = ("Rock", "CapDark", "Cap", "RockDark")
OBJECT_ORDER = (M_ROCK, M_DARK, M_BAND, M_BONE)

HORIZON_SPAN = 48.0  # scenery_belt.gd and the greybox script; the belt's slot pitch
HALF = (HORIZON_SPAN - 0.25) / 2.0  # 23.875: 47.75 m long, 0.125 m clear of each neighbour slot
GRID = 0.25
Z_UNDER = -0.25  # every piece starts under the span's base; the build cuts at z 0
SINK = 0.25  # each piece runs this far into the one under it (no coincident faces)
TERRAIN_TOP = 0.12  # env_terrain's top in the span's frame: no face may lie on it
TAN35 = math.tan(math.radians(35.0))
BAND_Z0, BAND_Z1 = 7.0, 8.25  # sheet B: one violet slab from 7.0 to 8.25 over the span's foot
# This scene's sun in Blender plan: Godot yaw toward +x and +z, so toward Blender +X and -Y. TimeOfDay keeps the
# yaw and sets the elevation: dawn 8, noon 70, late afternoon 32, dusk 12 degrees.
TO_SUN = (math.sqrt(0.5), -math.sqrt(0.5))
SUN_ELEVATIONS = (8.0, 70.0, 32.0, 12.0)
UP_FACE = 0.9  # a face whose normal's z is above this is a top (the 35 degree apron slopes are 0.82)
SIDE_LEAN = 0.3  # a vertical face whose plan normal's x passes this belongs to that long face


# --------------------------------------------------------------------------------------
# Scene
# --------------------------------------------------------------------------------------

def set_palette() -> None:
    for name, rgb in PALETTE.items():
        m = bpy.data.materials.get(name)
        if m is None:
            m = bpy.data.materials.new(name)
        if m.node_tree is None:
            m.use_nodes = True
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            raise RuntimeError(f"{name} has no Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.9
        bsdf.inputs["Metallic"].default_value = 0.0
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.5
        m.diffuse_color = (*rgb, 1.0)
        m.roughness = 0.9
        m.metallic = 0.0


def _collect(root):
    out, stack = [], [root]
    while stack:
        o = stack.pop()
        out.append(o)
        stack.extend(o.children)
    return out


def span_root(name: str):
    root = bpy.data.objects.get(ROOT_NAME)
    if root is None:
        raise RuntimeError("no `horizon_ridge` root in train_rooftop.blend")
    span = bpy.data.objects.get(name)
    if span is None or span.parent != root or span.type != "EMPTY":
        raise RuntimeError(f"`{name}` is not an empty under `horizon_ridge`")
    return span


def clear_span(span) -> int:
    """Deletes every child of a span (greybox or an earlier final) and its unused meshes. The span stays."""
    removed = 0
    for child in list(span.children):
        for o in reversed(_collect(child)):
            mesh = o.data if o.type == "MESH" else None
            bpy.data.objects.remove(o, do_unlink=True)
            if mesh is not None and mesh.users == 0:
                bpy.data.meshes.remove(mesh)
            removed += 1
    return removed


# --------------------------------------------------------------------------------------
# Geometry kernel: closed prisms in one bmesh per span (the Canyon finals' kernel)
# --------------------------------------------------------------------------------------

def _area(pts) -> float:
    return 0.5 * sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
                     for i in range(len(pts)))


def _clean(pts):
    """Drops repeated points and points on a straight run."""
    out = list(pts)
    changed = True
    while changed and len(out) > 3:
        changed = False
        n = len(out)
        for i in range(n):
            a, b, c = out[i - 1], out[i], out[(i + 1) % n]
            if math.dist(a, b) < 1e-6:
                del out[i]
                changed = True
                break
            cross = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])
            if abs(cross) < 1e-9 and (b[0] - a[0]) * (c[0] - b[0]) + (b[1] - a[1]) * (c[1] - b[1]) > 0:
                del out[i]
                changed = True
                break
    return out


def ccw(pts):
    pts = _clean(list(pts))
    return pts[::-1] if _area(pts) < 0 else pts


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


def rect(x0, x1, y0, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def tilt(pivot, axis: str, deg: float) -> Matrix:
    p = Vector(pivot)
    return Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-p)


class Shells:
    """One span's closed shells (unioned) and cut boxes (subtracted), with a material index per face."""

    def __init__(self):
        self.bm = bmesh.new()
        self.cuts = bmesh.new()
        self.pieces = 0

    def shell(self, rings, mat, xform=None, cut=False):
        bm = self.cuts if cut else self.bm
        verts = [[bm.verts.new(xform @ Vector(p) if xform is not None else Vector(p)) for p in ring] for ring in rings]
        n = len(verts[0])
        faces = [bm.faces.new(list(reversed(verts[0]))), bm.faces.new(verts[-1])]
        for lo, hi in zip(verts[:-1], verts[1:]):
            for i in range(n):
                j = (i + 1) % n
                faces.append(bm.faces.new((lo[i], lo[j], hi[j], hi[i])))
        for f in faces:
            f.material_index = mat
        self.pieces += 1

    def prism(self, plan, z0, z1, mat, xform=None, cut=False):
        """A vertical prism over a plan polygon."""
        pts = ccw(plan)
        if not _simple(pts):
            raise RuntimeError("self-intersecting plan %s" % (pts,))
        self.shell([[(x, y, z0) for x, y in pts], [(x, y, z1) for x, y in pts]], mat, xform, cut)


# --------------------------------------------------------------------------------------
# Plan lines
# --------------------------------------------------------------------------------------

def face_points(base: float, side: int, y0: float, y1: float, notches=(), flutes=()):
    """One long face as (x, y) points with y rising from y0 to y1, at x = base.

    notches: (y, run, depth) turned planes. On the +X face (side 1) the plane comes forward `depth` over `run` and
    returns square: its normal turns atan(depth / run) toward -Y. On the -X face (side -1) the same shape is the
    sawtooth: run 1.0 and depth 1.5 turn it 56.3 degrees toward -Y. Every return faces +Y.
    flutes: (y, ridges, pitch, depth) a fluted stretch: V grooves `depth` deep between ridges `pitch` apart."""
    pts = [(base, y0)]
    feats = [("n", f) for f in notches] + [("f", f) for f in flutes]
    for kind, f in sorted(feats, key=lambda kf: kf[1][0]):
        if kind == "n":
            y, run, depth = f
            pts += [(base, y), (base + side * depth, y + run), (base, y + run)]
        else:
            y, ridges, pitch, depth = f
            pts.append((base, y))
            for k in range(ridges + 1):
                pts.append((base - side * depth, y + pitch * (k + 0.5)))
                pts.append((base, y + pitch * (k + 1)))
    pts.append((base, y1))
    return pts


def slab_plan(pos_pts, neg_pts):
    """The closed plan of a slab: its +X face rising in y, its -X face back down, square ends."""
    pts = ccw(list(pos_pts) + list(reversed(neg_pts)))
    if not _simple(pts):
        raise RuntimeError("slab plan folds")
    return pts


def _corner_turns(pts):
    n = len(pts)
    out = []
    for i in range(n):
        a, b, c = pts[i - 1], pts[i], pts[(i + 1) % n]
        t0 = math.atan2(b[1] - a[1], b[0] - a[0])
        t1 = math.atan2(c[1] - b[1], c[0] - b[0])
        out.append((t1 - t0 + math.pi) % (2.0 * math.pi) - math.pi)
    return out


def apron(sh: Shells, outline, w: float, mat=M_BODY) -> int:
    """The apron (sheet B): one 35 degree wedge along each edge of a convex outline (the lower body's base), its toe
    w metres out on the span's base at z 0 and its back buried inside the outline. Each wedge is mitred on its
    corners' bisectors, so the apron turns every corner in a hip and closes round the span's ends. This is the
    Canyon's skirt_ring with one piece an edge: every extra piece costs a valley and an end face (about 8 triangles
    a junction, measured). Returns the wedge count."""
    pts = ccw(outline)
    n = len(pts)
    turn = _corner_turns(pts)
    if min(turn) < -1e-9:
        raise RuntimeError("apron outline is not convex")
    p_in = -2.0  # the buried back, inside the outline; shallower where a short edge's mitres would fold
    for i in range(n):
        span = math.tan(turn[i] / 2.0) + math.tan(turn[(i + 1) % n] / 2.0)
        p_in = max(p_in, -(math.dist(pts[i], pts[(i + 1) % n]) - 0.25) / span)
    if p_in > -0.5:
        raise RuntimeError("apron outline has an edge too short for its corners")
    prof = [(p_in, Z_UNDER), (w - Z_UNDER / TAN35, Z_UNDER), (p_in, (w - p_in) * TAN35)]
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        L = math.dist(a, b)
        t = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
        nrm = (t[1], -t[0])  # outward on a CCW outline
        rings = []
        for s, tn, sgn in ((0.0, turn[i], -1.0), (L, turn[(i + 1) % n], 1.0)):
            rings.append([(a[0] + t[0] * (s + sgn * p * math.tan(tn / 2.0)) + nrm[0] * p,
                           a[1] + t[1] * (s + sgn * p * math.tan(tn / 2.0)) + nrm[1] * p, z) for p, z in prof])
        sh.shell(rings, mat)
    return n


def fallen_block(sh: Shells, side: int, toe: float, y: float, w: float, d: float, h: float, deg: float):
    """A fallen bone cap block (wear) lying across the apron's toe at x = toe: w along Y, d across, h tall, half on
    the plain and half in the slope, tilted `deg` toward the plain about its outer bottom edge. Sitting across the
    toe keeps the slope one face with a notch, not a face with a hole."""
    x0, x1 = sorted((toe - side * d / 2.0, toe + side * d / 2.0))
    xform = tilt((toe + side * d / 2.0, y, 0.0), "Y", side * deg)
    sh.prism(rect(x0, x1, y - w / 2.0, y + w / 2.0), Z_UNDER, h, M_BONE, xform=xform)


def pillar(sh: Shells, side: int, x_in: float, y: float, w: float, d: float, top: float):
    """A pillar (the greybox buttress made two-sided, sheet B detail 5): a free-standing block w along Y and d across,
    its inner face at x = x_in, clear of the wall, rising from under the base to `top`."""
    x0, x1 = sorted((x_in, x_in + side * d))
    sh.prism(rect(x0, x1, y, y + w), Z_UNDER, top, M_BODY)


# --------------------------------------------------------------------------------------
# Union, colour, objects
# --------------------------------------------------------------------------------------

def _bm_object(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for m in SLOT_MATS:
        obj.data.materials.append(bpy.data.materials[m])
    return obj


def colour(f) -> int:
    """Rule 17 by this scene's sun (sheet B). Bone and violet stay. A body face:
    - a top (or an underside) takes the colour of the side its centre lies on (x >= 0 vermilion, x < 0 pink); the
      7.0 m ledge ring is split at x 0 first, and the tops above it (above the eye) cross x 0 whole;
    - a vertical face or slope whose plan normal leans to +X (x 0.3 or more) is vermilion and to -X pink, so the -X
      face's sawtooth, turned 56 degrees toward -Y, stays pink with lit teeth (B's squint);
    - one that faces along the span is vermilion toward -Y (the end the sun reaches) and pink toward +Y (never)."""
    if f.material_index != M_BODY:
        return f.material_index
    n = f.normal
    if abs(n.z) > UP_FACE:
        return M_ROCK if f.calc_center_median().x >= 0.0 else M_DARK
    h = math.hypot(n.x, n.y)
    hx, hy = n.x / h, n.y / h
    if hx >= SIDE_LEAN:
        return M_ROCK
    if hx <= -SIDE_LEAN:
        return M_DARK
    return M_ROCK if hy < 0.0 else M_DARK


def _degenerate_faces(bm):
    bad = set()
    for tri in bm.calc_loop_triangles():
        a, b, c = (lp.vert.co for lp in tri)
        if (b - a).cross(c - a).length < 2e-6:
            bad.add(tri[0].face)
    return bad


def fix_slivers(bm) -> int:
    """T-junctions on an n-gon's outline make the tessellator emit zero-area triangles (saloon.md H): split only
    those faces, with the beauty method."""
    bad = _degenerate_faces(bm)
    if bad:
        bmesh.ops.triangulate(bm, faces=list(bad), quad_method="BEAUTY", ngon_method="BEAUTY")
    left = _degenerate_faces(bm)
    if left:
        bmesh.ops.beautify_fill(bm, faces=list(left), edges=list({e for f in left for e in f.edges}))
    return len(bad)


def drop_needles(bm) -> int:
    """A needle (three collinear points) left where a cut meets a slope: merge it into its neighbour."""
    def needle(f):
        if len(f.verts) != 3:
            return False
        a, b, c = (v.co for v in f.verts)
        return (b - a).cross(c - a).length < 1e-6 * max(1.0, max(e.calc_length() for e in f.edges))

    needles = [f for f in bm.faces if needle(f)]
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


def union_span(sh: Shells):
    """One exact self-union of every shell minus the cut boxes, cut at z 0 (bottoms and buried feet dropped),
    coloured by colour(), and dissolved into one n-gon per flat region per material. Returns a bmesh."""
    bmesh.ops.recalc_face_normals(sh.bm, faces=sh.bm.faces)
    pos = _bm_object(sh.bm, "_hr_pos")
    ops = bpy.data.collections.new("_hr_ops")
    mod = pos.modifiers.new("union", "BOOLEAN")
    mod.operation, mod.solver = "UNION", "EXACT"
    mod.operand_type, mod.collection, mod.use_self = "COLLECTION", ops, True
    temp = [pos]
    if len(sh.cuts.faces):
        bmesh.ops.recalc_face_normals(sh.cuts, faces=sh.cuts.faces)
        cut = _bm_object(sh.cuts, "_hr_cut")
        m2 = pos.modifiers.new("cuts", "BOOLEAN")
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
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    # Merge the union's fragments into whole flat regions first, so each top is coloured as one region.
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.05), use_dissolve_boundaries=False,
                             verts=bm.verts, edges=bm.edges, delimit={"MATERIAL"})
    bm.normal_update()
    # The lower body's ledge ring runs round both long faces: split it at x 0 so each side takes its own colour.
    def crosses_x0(f):
        xs = [v.co.x for v in f.verts]
        return min(xs) < -1e-4 and max(xs) > 1e-4

    ring = [f for f in bm.faces if f.material_index == M_BODY and f.normal.z > UP_FACE
            and f.calc_center_median().z < BAND_Z1 and crosses_x0(f)]
    if ring:
        geom = ring + list({e for f in ring for e in f.edges}) + list({v for f in ring for v in f.verts})
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, 0), plane_no=(1, 0, 0))
    bm.normal_update()
    for f in bm.faces:
        f.material_index = colour(f)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.05), use_dissolve_boundaries=False,
                             verts=bm.verts, edges=bm.edges, delimit={"MATERIAL"})
    bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    fix_slivers(bm)
    drop_needles(bm)
    return bm


def split_by_material(bm, index):
    out = bm.copy()
    bmesh.ops.delete(out, geom=[f for f in out.faces if f.material_index != index], context="FACES")
    bmesh.ops.delete(out, geom=[v for v in out.verts if not v.link_faces], context="VERTS")
    for f in out.faces:
        f.material_index = 0
    return out


def finish_span(span, bm) -> list:
    """One object per material under the span, at its origin, zero rotation, flat, with 8 m tiling UVs (G8)."""
    coll = span.users_collection[0] if span.users_collection else bpy.context.scene.collection
    out = []
    for slot in OBJECT_ORDER:
        part = split_by_material(bm, slot)
        if not part.faces:
            part.free()
            continue
        name = f"{span.name}_{SLOT_SUFFIX[slot]}"
        me = bpy.data.meshes.new(name)
        part.to_mesh(me)
        part.free()
        obj = bpy.data.objects.new(name, me)
        coll.objects.link(obj)
        obj.parent = span
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.location = (0.0, 0.0, 0.0)
        obj.rotation_euler = (0.0, 0.0, 0.0)
        obj.scale = (1.0, 1.0, 1.0)
        obj.data.materials.append(bpy.data.materials[SLOT_MATS[slot]])
        flat_shade(obj)
        scenery_uv.unwrap_object(obj, scenery_uv.TILING)
        obj["uv_role"] = "tiling"
        if obj.name != name or me.name != name:
            raise RuntimeError(f"name taken: wanted {name}, got {obj.name} / {me.name}")
        out.append(obj)
    bm.free()
    return out


# --------------------------------------------------------------------------------------
# Checks (printed; a failure raises)
# --------------------------------------------------------------------------------------

def _tri_overlap_2d(a, b) -> bool:
    """Two triangles in a plane share area (separating axis, with a 1 mm tolerance)."""
    for tri, other in ((a, b), (b, a)):
        for i in range(3):
            p, q = tri[i], tri[(i + 1) % 3]
            nx, ny = q[1] - p[1], p[0] - q[0]
            ln = math.hypot(nx, ny)
            if ln < 1e-12:
                return False
            nx, ny = nx / ln, ny / ln
            pa = [nx * v[0] + ny * v[1] for v in tri]
            pb = [nx * v[0] + ny * v[1] for v in other]
            if max(pa) <= min(pb) + 1e-3 or max(pb) <= min(pa) + 1e-3:
                return False
    return True


def coplanar_overlaps(objs):
    """Pairs of triangles (any objects of the span) that lie in one plane and share area."""
    tris = []
    for o in objs:
        me = o.data
        me.calc_loop_triangles()
        for t in me.loop_triangles:
            vs = [me.vertices[i].co.copy() for i in t.vertices]
            n = (vs[1] - vs[0]).cross(vs[2] - vs[0])
            if n.length < 1e-9:
                continue
            n.normalize()
            tris.append((o.name, t.polygon_index, n, n.dot(vs[0]), vs))
    pairs = overlaps = 0
    for i in range(len(tris)):
        oi, fi, ni, di, vi = tris[i]
        for j in range(i + 1, len(tris)):
            oj, fj, nj, dj, vj = tris[j]
            if oi == oj and fi == fj:
                continue
            c = ni.dot(nj)
            if abs(c) < 0.99999 or abs(di - math.copysign(1.0, c) * dj) > 1e-4:
                continue
            pairs += 1
            u = (vi[1] - vi[0]).normalized()
            w = ni.cross(u)
            a = [(u.dot(p), w.dot(p)) for p in vi]
            b = [(u.dot(p), w.dot(p)) for p in vj]
            if _tri_overlap_2d(a, b):
                overlaps += 1
                print(f"    COPLANAR OVERLAP {oi}[{fi}] / {oj}[{fj}]")
    return len(tris), pairs, overlaps


def mesh_checks(objs) -> dict:
    out = {"zero": 0, "nonplanar": 0, "smooth": 0, "collinear": 0, "z012": 0, "z0": 0, "verts": 0, "grid": 0}
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        me = o.data
        me.calc_loop_triangles()
        for t in me.loop_triangles:
            if t.area < 1e-6:
                out["zero"] += 1
        for p in me.polygons:
            if p.use_smooth:
                out["smooth"] += 1
            co = [me.vertices[i].co for i in p.vertices]
            n = p.normal
            d = n.dot(co[0])
            if max(abs(n.dot(c) - d) for c in co) > 1e-4:
                out["nonplanar"] += 1
            k = len(co)
            for i in range(k):
                a, b, c = co[i - 1], co[i], co[(i + 1) % k]
                if (b - a).cross(c - b).length < 1e-6 * max(1.0, (c - a).length):
                    out["collinear"] += 1
            if abs(n.z) > 0.9999:
                if abs(co[0].z - TERRAIN_TOP) < 1e-3:
                    out["z012"] += 1
                if abs(co[0].z) < 1e-4:
                    out["z0"] += 1
        for v in me.vertices:
            out["verts"] += 1
            if all(abs(c / GRID - round(c / GRID)) < 1e-4 for c in v.co):
                out["grid"] += 1
            for k in range(3):
                lo[k] = min(lo[k], v.co[k])
                hi[k] = max(hi[k], v.co[k])
    out["lo"], out["hi"] = lo, hi
    return out


def geometry_hash(objs) -> str:
    h = hashlib.md5()
    for o in sorted(objs, key=lambda o: o.name):
        h.update(o.name.encode())
        for v in o.data.vertices:
            h.update(("%.4f %.4f %.4f;" % tuple(v.co)).encode())
        for p in o.data.polygons:
            h.update((",".join(str(i) for i in p.vertices) + ";").encode())
    return h.hexdigest()[:12]


def check_span(span, objs, budget: int, tops) -> None:
    total = 0
    for obj in objs:
        n = count_tris(obj)
        total += n
        print(f"  {obj.name:18s} {obj.data.materials[0].name:11s} {n:5d} triangles {len(obj.data.polygons):4d} faces")
    print(f"{span.name}: {len(objs)} objects, {total} triangles (budget {budget})")
    m = mesh_checks(objs)
    print("  extents x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f" % (m["lo"].x, m["hi"].x, m["lo"].y, m["hi"].y,
                                                               m["lo"].z, m["hi"].z))
    print("  zero-area triangles %d, non-planar faces %d, smooth faces %d, collinear outline points %d, "
          "faces at z 0.12 %d, faces at z 0 %d, vertices on the 0.25 m grid %d of %d (%.0f%%)" % (
              m["zero"], m["nonplanar"], m["smooth"], m["collinear"], m["z012"], m["z0"], m["grid"], m["verts"],
              100.0 * m["grid"] / max(1, m["verts"])))
    lit = []
    for o in objs:
        if o.data.materials[0].name != "M_RockDark":
            continue
        for p in o.data.polygons:
            n = p.normal
            if abs(n.z) < 0.1 and n.x < -0.3 and n.y < -0.3:  # the -X face's planes turned toward -Y
                lit.append(min(math.cos(math.radians(e)) * (n.x * TO_SUN[0] + n.y * TO_SUN[1]) for e in SUN_ELEVATIONS))
    if lit:
        print("  sawtooth planes: %d, the least sunlight on any at any hour N.L %.3f (the middle step needs > 0)" % (
            len(lit), min(lit)))
    ntri, pairs, overlaps = coplanar_overlaps(objs)
    print(f"  coplanar test: {ntri} triangles, {pairs} coplanar pairs, {overlaps} sharing area")
    steps = [abs(a - b) for a, b in zip(tops[:-1], tops[1:])]
    print("  skyline tops along the span: " + ", ".join("%.2f" % t for t in tops)
          + "  (smallest step between neighbours %.2f)" % min(steps))
    print(f"  geometry hash {geometry_hash(objs)}")
    names = [o.name for o in _collect(span)]
    bad = []
    if any("." in n for n in names) or len(names) != len(set(names)):
        bad.append("names")
    if total > budget:
        bad.append("over budget")
    if m["lo"].y < -HALF - 1e-4 or m["hi"].y > HALF + 1e-4 or m["lo"].z < -1e-4:
        bad.append("outside the span's box")
    if m["zero"] or m["nonplanar"] or m["smooth"] or m["z012"] or m["z0"]:
        bad.append("mesh")
    if overlaps:
        bad.append("coplanar faces")
    if min(steps) < 0.6 - 1e-6:
        bad.append("skyline neighbours closer than 0.6 m")
    if lit and min(lit) <= 0.03:
        bad.append("a sawtooth plane goes dark")
    for o in objs:
        if tuple(o.location) != (0.0, 0.0, 0.0) or tuple(o.rotation_euler) != (0.0, 0.0, 0.0) or o.parent != span:
            bad.append(f"{o.name} not at the span's origin")
        if o.get("uv_role") != "tiling" or len(o.data.uv_layers) != 1:
            bad.append(f"{o.name} UVs")
    if bad:
        raise RuntimeError(f"{span.name}: " + "; ".join(bad))


# --------------------------------------------------------------------------------------
# Shared span pieces
# --------------------------------------------------------------------------------------

class Body:
    """A span's shells and its skyline: the upper-body segments under their bone cap blocks."""

    def __init__(self):
        self.sh = Shells()
        self.tops = []  # skyline tops along +Y, for the 0.6 m check

    def segments(self, segs, xp: float, xn: float, z0: float, cap_over: float, cap_inset: float, chip=None,
                 flutes=None):
        """Upper-body segments [(y0, y1, cap_top, cap_h)] side by side along Y, each under one bone cap block.

        Neighbouring segments whose caps sit at one height share one body prism (its long faces stay one plane);
        where the height changes, the taller body runs 0.25 m into the shorter so no two end faces coincide. Each
        cap block sits on its body (cap_h tall, so its top is the skyline top), overhangs it cap_over on both long
        faces, and stops cap_inset short of the nearest body end face or block, so the sky shows between
        neighbouring blocks. cap_h 0 leaves a segment uncapped (its top is rock: an end step or a saddle).
        chip: (segment index, corner) cuts one cap block's vertical corner 0.75 m at 45 degrees (rect order).
        flutes: [(side, y, ridges, pitch, depth)] fluted stretches of the bodies' long faces (face_points)."""
        sh = self.sh
        n = len(segs)
        body = [top - cap_h for _, _, top, cap_h in segs]
        # Body runs: consecutive segments at one body height.
        runs = []
        for k, (y0, y1, _, _) in enumerate(segs):
            if runs and abs(runs[-1][2] - body[k]) < 1e-6:
                runs[-1][1] = y1
                runs[-1][3].append(k)
            else:
                runs.append([y0, y1, body[k], [k]])
        # Where each boundary's visible end face stands (the taller body runs 0.25 into the shorter).
        face_at = {}
        for r in range(len(runs) - 1):
            b = runs[r][1]
            face_at[r] = b + 0.25 if runs[r][2] > runs[r + 1][2] else b - 0.25
        placed = 0
        for r, (ya, yb, top, ks) in enumerate(runs):
            if r > 0 and runs[r - 1][2] < top:
                ya -= 0.25
            if r < len(runs) - 1 and runs[r + 1][2] < top:
                yb += 0.25
            inside = [f for f in flutes or () if ya + 0.5 <= f[1] and f[1] + f[3] * (f[2] + 1) <= yb - 0.5]
            placed += len(inside)
            fp = [f[1:] for f in inside if f[0] > 0]
            fn = [f[1:] for f in inside if f[0] < 0]
            sh.prism(slab_plan(face_points(xp, 1, ya, yb, flutes=fp), face_points(xn, -1, ya, yb, flutes=fn)),
                     z0, top, M_BODY)
        if placed != len(flutes or ()):
            raise RuntimeError("a flute stretch runs past its body's ends")
        run_of = {k: r for r, run in enumerate(runs) for k in run[3]}
        for k, (y0, y1, top, cap_h) in enumerate(segs):
            self.tops.append(top)
            if cap_h <= 0:
                continue
            r = run_of[k]
            if k > 0 and run_of[k - 1] == r:
                lo = y0 + cap_inset  # a block on the same body: the gap is centred on the boundary
            elif k > 0:
                lo = face_at[r - 1] + cap_inset
            else:
                lo = y0 + cap_inset
            if k < n - 1 and run_of[k + 1] == r:
                hi = y1 - cap_inset
            elif k < n - 1:
                hi = face_at[r] - cap_inset
            else:
                hi = y1 - cap_inset
            plan = rect(xn - cap_over, xp + cap_over, lo, hi)
            if chip is not None and chip[0] == k:
                plan = cut_corners(plan, {chip[1]}, 0.75)
            sh.prism(plan, top - cap_h, top, M_BONE)


# --------------------------------------------------------------------------------------
# Canyon (sheet B: the mid band's even slots, the tallest and nearest walls)
# --------------------------------------------------------------------------------------

CANYON_BUDGET = 300
CANYON_APRON = 3.375  # the apron's toe, out from the lower body's base
# Lower body faces: (y, run, depth) planes, see face_points(). +X: a run of two main planes turned 20.6 degrees toward
# -Y (1.5 m forward over 4.0 m, each with a square return). -X: a sawtooth run of three planes turned 56.3 degrees
# toward -Y (1.5 m out over 1.0 m): the middle light step at every hour, the lit teeth a span shows as it comes in.
CANYON_TURNED = [(-13.0, 4.0, 1.5), (-9.0, 4.0, 1.5)]
CANYON_TEETH = [(3.0, 1.0, 1.5), (4.0, 1.0, 1.5), (5.0, 1.0, 1.5)]
# Skyline segments (y0, y1, top, cap height), 7 m long; cap height 0 is an uncapped saddle. Tops 14.25 to 19.25
# (sheet B: 14 to 19.7), neighbours 0.75 m or more apart; the bodies stand at three heights (13.0, 12.5, 15.5).
CANYON_SEGS = [
    (-17.5, -10.5, 14.25, 1.25),
    (-10.5, -3.5, 15.0, 2.0),
    (-3.5, 3.5, 12.5, 0.0),
    (3.5, 10.5, 17.5, 2.0),
    (10.5, 17.5, 16.75, 1.25),
]
CANYON_CHIP = (3, 1)  # wear: the -Y, +X corner of the block over segment 3
# Flutes on the upper body (side, y, ridges, pitch, depth): none fit the budget (see the sheet, H).
CANYON_FLUTES = []
# Pillars (side, gap off the lower body's face, y, w, d, top): on each face one buttress standing in the lower body
# (gap -0.5) at the end of its plane run, and one free pillar on the apron's toe, 2.625 m clear of the face.
CANYON_PILLARS = [(1, -0.5, -5.0, 1.5, 2.0, 7.0), (1, 2.625, 12.0, 1.5, 1.5, 7.5),
                  (-1, -0.5, 6.0, 1.5, 2.0, 7.0), (-1, 2.625, -15.0, 1.5, 1.5, 7.5)]
# Fallen cap blocks (side, y, w, d, h, tilt) across the apron's toe, one a side (wear).
CANYON_FALLEN = [(1, -1.0, 1.5, 1.25, 1.0, 12.0), (-1, 10.0, 1.75, 1.25, 1.0, 15.0)]


def build_canyon() -> None:
    span = span_root("Canyon")
    print(f"Canyon: removed {clear_span(span)} children")
    b = Body()
    sh = b.sh
    # Plan (Blender, the span's frame): the +X face looks at the train from its left, the -X face from its right.
    # Lower body (under the apron to 7.0): a ridge 9.25 m thick, its ends 3.375 m inside the span's ends, its long
    # faces carrying the turned planes and the sawtooth (CANYON_TURNED, CANYON_TEETH).
    xp, xn = 4.5, -4.75
    ly = HALF - CANYON_APRON
    lb = slab_plan(face_points(xp, 1, -ly, ly, notches=CANYON_TURNED), face_points(xn, -1, -ly, ly, notches=CANYON_TEETH))
    sh.prism(lb, Z_UNDER, BAND_Z0, M_BODY)
    # Apron: a 35 degree wedge along each side of the lower body's base, mitred at the corners, its toe 3.375 m out:
    # x 7.875 and -8.125, y +-23.875 (the span's ends). The slope meets the faces at 2.36 m.
    wedges = apron(sh, rect(xn, xp, -ly, ly), CANYON_APRON)
    # Band: 7.0 to 8.25 (its foot sunk into the lower body), 0.5 m behind the lower body's faces, running on 0.5 m
    # past the upper body at each end.
    bx_p, bx_n = xp - 0.5, xn + 0.5
    sh.prism(rect(bx_n, bx_p, -18.0, 18.0), BAND_Z0 - SINK, BAND_Z1, M_BAND)
    # Upper body, 0.5 m behind the band (its foot sunk into it), in five skyline segments under bone cap blocks that
    # overhang it 0.75 m with 1.0 m of sky between them (CANYON_SEGS). It ends at y +-17.5, so each end steps down
    # twice within its last 6.375 m: cap to the lower body's top (past the band's 0.5 m lip), then to the apron.
    ux_p, ux_n = bx_p - 0.5, bx_n + 0.5
    b.segments(CANYON_SEGS, ux_p, ux_n, BAND_Z1 - SINK, 0.75, 0.5, chip=CANYON_CHIP, flutes=CANYON_FLUTES)
    for side, gap, y, w, d, top in CANYON_PILLARS:
        pillar(sh, side, (xp if side > 0 else xn) + side * gap, y, w, d, top)
    for side, y, w, d, h, deg in CANYON_FALLEN:
        fallen_block(sh, side, (xp + CANYON_APRON) if side > 0 else (xn - CANYON_APRON), y, w, d, h, deg)
    print(f"Canyon: {sh.pieces} shells ({wedges} apron wedges), union ...")
    bm = union_span(sh)
    objs = finish_span(span, bm)
    check_span(span, objs, CANYON_BUDGET, b.tops)


# --------------------------------------------------------------------------------------
# Mesa (sheet B: the mid band's odd slots, the lower, wider table between the walls)
# --------------------------------------------------------------------------------------

MESA_BUDGET = 240
MESA_APRON = 3.375
# Lower tier faces (y, run, depth): +X a run of two main planes turned 20.6 degrees toward -Y ending at the +Y end,
# -X a sawtooth run of three planes turned 56.3 degrees toward -Y starting at the -Y end (the end a span shows as it
# comes toward the train). Runs that meet the lower body's ends share its corners.
MESA_TURNED = [(12.5, 4.0, 1.5), (16.5, 4.0, 1.5)]
MESA_TEETH = [(-20.5, 1.0, 1.5), (-19.5, 1.0, 1.5), (-18.5, 1.0, 1.5)]
# Lower tier's rim (y0, y1, top, cap height) on a 1.0 m upper body (8.25 to 9.25): two blocks, the sky between them
# past the upper tier's +Y end.
MESA_LOWER = [(-17.5, 12.25, 10.5, 1.25), (12.25, 17.0, 11.25, 2.0)]
# Upper tier, set back 2.25 m behind the lower rim's front on both faces, on the long rim block: two blocks.
MESA_UPPER = [(-11.0, -0.5, 15.0, 1.25), (-0.5, 10.5, 15.75, 2.0)]
# Wear: a notch out of the upper rim (side, y, length, depth into the rim, depth down): a bite 1.0 m into the +X
# face and 1.0 m down at the +Y end of the taller block.
MESA_NOTCH = (1, 8.5, 2.5, 1.0, 1.0)
MESA_FALLEN = [(-1, 2.0, 1.5, 1.25, 1.0, 14.0)]  # wear: one fallen block on the -X skirt


def build_mesa() -> None:
    span = span_root("Mesa")
    print(f"Mesa: removed {clear_span(span)} children")
    b = Body()
    sh = b.sh
    # Lower tier: 11.75 m wide (the greybox's 12), its ends 3.375 m inside the span's ends.
    xp, xn = 6.0, -5.75
    ly = HALF - MESA_APRON
    lb = slab_plan(face_points(xp, 1, -ly, ly, notches=MESA_TURNED), face_points(xn, -1, -ly, ly, notches=MESA_TEETH))
    sh.prism(lb, Z_UNDER, BAND_Z0, M_BODY)
    wedges = apron(sh, rect(xn, xp, -ly, ly), MESA_APRON)
    # Band 0.5 m behind the lower body, running 0.5 m past the lower tier's upper body at each end.
    bx_p, bx_n = xp - 0.5, xn + 0.5
    sh.prism(rect(bx_n, bx_p, -18.0, 17.5), BAND_Z0 - SINK, BAND_Z1, M_BAND)
    # The lower tier's upper body, 0.5 m behind the band, under its bone rim (overhang 0.75 m). The tier ends at
    # y -17.5 and 17.0, so each end steps down twice within its last 6.4 to 6.9 m.
    ux_p, ux_n = bx_p - 0.5, bx_n + 0.5
    b.segments(MESA_LOWER, ux_p, ux_n, BAND_Z1 - SINK, 0.75, 0.5)
    lower_tops = list(b.tops)
    # Upper tier: its body 2.25 m behind the lower rim's front (3.0 m behind the lower body) on both faces, its foot
    # sunk into the long rim block, under its own rim (overhang 0.75 m).
    rim_p, rim_n = ux_p + 0.75, ux_n - 0.75
    tx_p, tx_n = rim_p - 2.25, rim_n + 2.25
    b.tops = []
    b.segments(MESA_UPPER, tx_p, tx_n, MESA_LOWER[0][2] - SINK, 0.75, 0.5)
    upper_tops = list(b.tops)
    # Wear: the notch, cut from the upper rim (its cut faces are bone), and a fallen block on one skirt.
    side, y, length, depth_in, depth_down = MESA_NOTCH
    top = next(sg[2] for sg in MESA_UPPER if sg[0] <= y < sg[1])
    face = (tx_p + 0.75) if side > 0 else (tx_n - 0.75)
    x0, x1 = sorted((face - side * depth_in, face + side * 1.0))
    sh.prism(rect(x0, x1, y, y + length), top - depth_down, top + 0.5, M_BONE, cut=True)
    for side, y, w, d, h, deg in MESA_FALLEN:
        fallen_block(sh, side, (xp + MESA_APRON) if side > 0 else (xn - MESA_APRON), y, w, d, h, deg)
    print(f"Mesa: {sh.pieces} shells ({wedges} apron wedges), union ...")
    bm = union_span(sh)
    objs = finish_span(span, bm)
    print("  lower rim tops " + ", ".join("%.2f" % t for t in lower_tops))
    check_span(span, objs, MESA_BUDGET, upper_tops)
    steps = [abs(a - c) for a, c in zip(lower_tops[:-1], lower_tops[1:])]
    if steps and min(steps) < 0.6 - 1e-6:
        raise RuntimeError("Mesa: lower rim neighbours closer than 0.6 m")


# --------------------------------------------------------------------------------------
# Butte (sheet B: the far band, x +-70 to +-100 at 2.4 m/s, 44 copies)
# --------------------------------------------------------------------------------------

BUTTE_BUDGET = 150
BUTTE_APRON = 3.0  # each pillar's skirt toe, out from its foot: 35 degree wedges 2.1 m tall at the foot
# The highest eye in the game: the death cam's orbit tops out near 6.1 m, a VR player on the cab roof near 5.2 m.
BUTTE_UNSEEN_TOP = 6.5
# Chamfers (sheet B: chamfered blocks, 0.5 m or more): one vertical edge a block, always a -Y corner, the end the sun
# reaches and the one a span shows as it comes toward the train. On the +X corner a 45 degree cut (1.0 x 1.0 m). On
# the -X corner the cut is turned 56.3 degrees toward -Y (1.5 m across, 1.0 m along), so it keeps the middle light
# step at every hour: the pink face's lit tooth.
CH_POS = ("pos", 1.0, 1.0)
CH_NEG = ("neg", 1.5, 1.0)
# Pillars: (centre x, centre y, blocks, cap, lean). Each block is (width across X, length along Y, top, chamfer);
# each one stands on the block under it (its foot sunk 0.25 m) and steps in 0.5 to 1.0 m on every side. The cap is
# (top, height, overhang): a bone block on the top body block, overhanging it on all four sides; the top body block
# runs 0.25 m into it, so its own top value is only the cap's foot. lean: the top body
# block and its cap tilt this many degrees toward -Y about the block's +Y foot (wear, sheet B detail 4).
# Heights 31, 39, and 20 m; widths 6.5, 5.5, and 8.0 m across X. Spacing 12.0 and 17.0 m inside the span and 19.0 m
# across the belt's 48 m pitch; the skirts stand apart, 0.25 m between the first two toes. Two blocks a pillar: a third
# on the tallest cost 19 triangles (sheet H).
BUTTE_PILLARS = [
    (0.0, -17.0, [(6.5, 6.5, 17.0, CH_NEG), (5.0, 5.0, 29.25, CH_POS)], (31.0, 1.75, 0.75), 3.0),
    (0.25, -5.0, [(5.5, 5.0, 23.0, CH_POS), (4.0, 3.5, 37.0, CH_NEG)], (39.0, 2.0, 0.75), 0.0),
    (-0.25, 12.0, [(8.0, 8.5, 12.0, CH_POS), (6.5, 6.5, 18.5, CH_NEG)], (20.0, 1.5, 0.75), 0.0),
]


def chamfered_rect(x0, x1, y0, y1, ch):
    """A block's plan: a rectangle with one -Y vertical edge cut (CH_POS on the +X corner, CH_NEG on the -X)."""
    side, across, along = ch
    if side == "pos":
        return [(x0, y0), (x1 - across, y0), (x1, y0 + along), (x1, y1), (x0, y1)]
    return [(x0, y0 + along), (x0 + across, y0), (x1, y0), (x1, y1), (x0, y1)]


def build_butte() -> None:
    span = span_root("Butte")
    print(f"Butte: removed {clear_span(span)} children")
    b = Body()
    sh = b.sh
    wedges = 0
    for cx, cy, blocks, (cap_top, cap_h, cap_over), lean in BUTTE_PILLARS:
        z0 = Z_UNDER
        last = len(blocks) - 1
        xform = None
        for k, (wx, wy, top, ch) in enumerate(blocks):
            x0, x1, y0, y1 = cx - wx / 2.0, cx + wx / 2.0, cy - wy / 2.0, cy + wy / 2.0
            z1 = (cap_top - cap_h + SINK) if k == last else top
            if k == last and lean:
                xform = tilt((cx, y1, z0), "X", lean)
            sh.prism(chamfered_rect(x0, x1, y0, y1, ch), z0, z1, M_BODY, xform=xform)
            if k == 0:
                # The skirt: 35 degree wedges round the pillar's foot, mitred at every corner (apron()).
                wedges += apron(sh, chamfered_rect(x0, x1, y0, y1, ch), BUTTE_APRON)
            z0 = top - SINK
        wx, wy = blocks[-1][0], blocks[-1][1]
        sh.prism(rect(cx - wx / 2.0 - cap_over, cx + wx / 2.0 + cap_over, cy - wy / 2.0 - cap_over,
                      cy + wy / 2.0 + cap_over), cap_top - cap_h, cap_top, M_BONE, xform=xform)
        b.tops.append(cap_top)
    print(f"Butte: {sh.pieces} shells ({wedges} skirt wedges), union ...")
    bm = union_span(sh)
    # Rule 27: delete faces nobody can see. Every up-facing face over BUTTE_UNSEEN_TOP (the pillars' ledges and the
    # caps' tops) lies above every eye in the game, 70 to 100 m out, so they cost triangles and nothing else.
    hidden = [f for f in bm.faces if f.normal.z > UP_FACE and f.calc_center_median().z > BUTTE_UNSEEN_TOP]
    bmesh.ops.delete(bm, geom=hidden, context="FACES_ONLY")
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context="EDGES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # The union's cut points that only the deleted ledges used now sit on a straight wall foot: dissolve them.
    loose = [v for v in bm.verts if len(v.link_edges) == 2 and
             (v.link_edges[0].other_vert(v).co - v.co).normalized().dot(
                 (v.link_edges[1].other_vert(v).co - v.co).normalized()) < -0.99999]
    bmesh.ops.dissolve_verts(bm, verts=loose)
    print(f"Butte: deleted {len(hidden)} unseen tops over {BUTTE_UNSEEN_TOP} m ({len(loose)} cut points dissolved)")
    objs = finish_span(span, bm)
    check_span(span, objs, BUTTE_BUDGET, b.tops)


# --------------------------------------------------------------------------------------

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    part = argv[argv.index("--part") + 1] if "--part" in argv else None
    builds = {"canyon": [build_canyon], "mesa": [build_mesa], "butte": [build_butte],
              "all": [build_canyon, build_mesa, build_butte]}
    if part not in builds:
        raise RuntimeError("--part canyon | mesa | butte | all")
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    set_palette()
    for build in builds[part]:
        build()
    bpy.ops.wm.save_mainfile()
    print(f"saved {bpy.data.filepath}")
    print("BUILD_OK")


main()
