"""Automatic trim-sheet UVs for the scenario `.blend` files (Blender 4.x / 5.x).

This module gives every built object a UV map laid on the 512x1024 trim sheet at 64 px per
metre (strips in the top 512 rows, 16 photo cells below), writes a placeholder sheet, previews
it on the materials, and exports GLBs that keep their Base Color and no image. The layout
tables live in `dev/trim_layout.py`; rules: `docs/TEXTURING.md`.

Import from a build script::

    import scenery_uv
    scenery_uv.process_scene()        # UVs + sheet preview, before saving the .blend
    scenery_uv.export_glb(root, path) # drop-in for the build scripts' export_glb

An object with the custom property ``uv_lock`` is never touched. After a run each object
carries ``uv_role`` (strip name, ``cell:<name>``, ``tiling``, or ``skip``), ``uv_cell`` (the
cell slot, cell objects only), and, when it needs a look, ``uv_review`` (the reason).
"""
from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trim_layout as TL  # noqa: E402

ROOT = TL.ROOT
SHEET_PATH = TL.SHEET_PATH
MANIFEST_PATH = TL.MANIFEST_PATH
SHEET_PX = TL.SHEET_W  # width; every U is divided by this
SHEET_H = TL.SHEET_H  # height; every V is divided by this
PX_PER_M = TL.PX_PER_M
UV_NAME = "UVMap"
TILE_M = SHEET_PX / PX_PER_M  # metres covered by the full sheet width: 8
PREVIEW_NODE = "TrimSheetPreview"
# A face this much taller than its strip is squeezed to fit; anything taller is cut into bands.
STRETCH_MAX = 1.3

STRIP_ROWS = TL.STRIP_ROWS
STRIPS = TL.STRIPS
# Flat fills: texel density is irrelevant, so a face is scaled to fit instead of cut.
FLAT = {"Glass", "Blank"}
TILING = "tiling"
SKIP = "skip"
CELL_PREFIX = "cell:"
# A face is a "large" face of a cell object when it is at least this share of the biggest face.
CELL_LARGE_FACE = 0.5
# A round part shorter than this share of its diameter is a disc (a table top): its caps carry
# the picture. A taller one (barrel, tank) wraps the picture once around its side.
CELL_DISC = 0.25
CELL_SLIVER_PX = 2.0  # how far into the picture a thin edge face samples

# Plants, animals, and small decorative materials keep their flat color and get no UVs.
SKIP_MATERIALS = {
    "M_Cactus", "M_CactusDark", "M_Scrub", "M_ScrubDry", "M_Yucca", "M_Hay", "M_Cow",
    "M_CowDark", "M_Bottle", "M_BottleAmber", "M_Candle", "M_Flame", "M_Glass", "M_Mirror",
    "M_Brass", "M_Cloth", "M_Ivory", "M_Lamp",
}
# Ground and rock: plain tiling UVs, one tile per 8 m. A later tiling texture, not the sheet.
TILING_MATERIALS = {
    "M_Sand", "M_SandFar", "M_Dirt", "M_DirtFar", "M_Rock", "M_RockDark", "M_Cap", "M_CapDark",
}
# Wood-like materials: strip comes from the object's proportions.
WOODLIKE = {"M_Wood", "M_WoodDark", "M_Whitewash", "M_Car", "M_CarDark", "M_Trim"}
# Always Boards (or Beam when it is a stick).
BOARDY = {"M_Bar", "M_BarTop", "M_Floor", "M_FloorAlt", "M_Plank"}
STICK_MAX = 0.4  # both smaller dimensions at or under this: a post, rail, or frame
THIN_MAX = 0.4  # one dimension at or under this: a slab (wall, door, deck)
BEAM_CYL_MAX_DIA = 0.35
CYL_ROUND = 0.8  # smallest cap radius over the largest for a round part; a square is 0.71

_AXES = ((1, 2), (0, 2), (0, 1))  # projected components for a dominant normal axis x, y, z


# --------------------------------------------------------------------------------------
# Classification
# --------------------------------------------------------------------------------------

def _is_collision(obj) -> bool:
    return "convcolonly" in obj.name


def _scaled(v: Vector, sc: Vector) -> Vector:
    return Vector((v.x * sc.x, v.y * sc.y, v.z * sc.z))


def _dims(me, sc) -> Vector:
    xs = [_scaled(v.co, sc) for v in me.vertices]
    lo = Vector((min(p.x for p in xs), min(p.y for p in xs), min(p.z for p in xs)))
    hi = Vector((max(p.x for p in xs), max(p.y for p in xs), max(p.z for p in xs)))
    return hi - lo


def _is_cylinder(me, sc: Vector | None = None) -> bool:
    """Two round caps and quads between them. A box that band cutting gave a 20-vertex top and
    bottom has the same face counts, so the cap corners must also sit on a circle."""
    caps = [p for p in me.polygons if len(p.vertices) > 4]
    quads = sum(1 for p in me.polygons if len(p.vertices) == 4)
    if len(caps) != 2 or quads + 2 != len(me.polygons):
        return False
    sc = sc if sc is not None else Vector((1.0, 1.0, 1.0))
    for cap in caps:
        pts = [_scaled(me.vertices[i].co, sc) for i in cap.vertices]
        centre = sum(pts, Vector()) / len(pts)
        radii = [(p - centre).length for p in pts]
        if min(radii) < CYL_ROUND * max(radii):
            return False
    return True


def classify(obj) -> tuple[str, str]:
    """Returns (role, note). Role is a strip name, TILING, or SKIP."""
    if obj.type != "MESH" or _is_collision(obj) or len(obj.data.polygons) == 0:
        return SKIP, ""
    mat = obj.data.materials[0].name if obj.data.materials and obj.data.materials[0] else ""
    base = mat.split(".")[0]
    if base in SKIP_MATERIALS:
        return SKIP, ""
    if base in TILING_MATERIALS:
        return TILING, ""
    name = obj.name
    sc = Vector(obj.scale)
    d = _dims(obj.data, sc)
    ds = sorted(d)
    cyl = _is_cylinder(obj.data, sc)
    if base == "M_Window" or (base == "M_Iron" and name.startswith("Win_")):
        return "Glass", ""
    if base == "M_Masonry":
        return "Masonry", ""
    if base == "M_Roof":
        return "Shingles", ""
    if base in ("M_Iron", "M_Boiler"):
        return "Metal", ""
    if "Cornice" in name or "Moulding" in name:
        return "Moulding", ""
    if base in BOARDY or base in WOODLIKE:
        if cyl:
            # A cylinder's two equal dimensions are its diameter, so the middle one is it
            # whether the axis is the longest or the shortest.
            dia = ds[1]
            if dia <= BEAM_CYL_MAX_DIA:
                return "Beam", ""
            return "Boards", ""
        if ds[1] <= STICK_MAX:
            return "Beam", ""
        if base in BOARDY:
            return "Boards", ""
        if ds[0] <= THIN_MAX:
            thin_axis = [d.x, d.y, d.z].index(ds[0])
            return ("Boards" if thin_axis == 2 else "Siding"), ""
        return "Siding", ""
    return SKIP, "unknown material %s" % (mat or "(none)")


# --------------------------------------------------------------------------------------
# Unwrapping
# --------------------------------------------------------------------------------------

def _strip_geom(strip: str) -> tuple[float, float]:
    """(height in metres, V of the strip's bottom edge)."""
    r0, r1 = STRIPS[strip]
    return (r1 - r0) / PX_PER_M, 1.0 - r1 / SHEET_H


def _face_axis(face) -> int:
    n = face.normal
    ax = [abs(n.x), abs(n.y), abs(n.z)]
    return ax.index(max(ax))


def _face_extents(face, sc: Vector, p: int, q: int):
    pv = [v.co[p] * sc[p] for v in face.verts]
    qv = [v.co[q] * sc[q] for v in face.verts]
    return min(pv), max(pv) - min(pv), min(qv), max(qv) - min(qv)


def _box_cuts(bm, sc: Vector, h: float) -> int:
    """Cuts every face taller than its strip into bands. Returns the cut count."""
    cuts = 0
    for _ in range(4000):
        target = None
        for f in bm.faces:
            p, q = _AXES[_face_axis(f)]
            _, ep, _, eq = _face_extents(f, sc, p, q)
            vi, vext = (p, ep) if ep <= eq else (q, eq)
            if vext > h * STRETCH_MAX:
                vmin = min(v.co[vi] * sc[vi] for v in f.verts)
                target = (f, vi, vmin)
                break
        if target is None:
            return cuts
        f, vi, vmin = target
        no, co = Vector((0, 0, 0)), Vector((0, 0, 0))
        no[vi] = 1.0
        co[vi] = (vmin + h) / sc[vi]
        geom = [f] + list(f.edges) + list(f.verts)
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=co, plane_no=no)
        bm.faces.ensure_lookup_table()
        bm.normal_update()
        cuts += 1
    return -1  # did not settle


def _layout_box(bm, uv, sc: Vector, strip: str) -> dict:
    h, v_bottom = _strip_geom(strip)
    flat = strip in FLAT
    info = {"cuts": 0, "slanted": 0}
    if not flat:
        info["cuts"] = _box_cuts(bm, sc, h)
    for f in bm.faces:
        axis = _face_axis(f)
        n = f.normal
        if max(abs(n.x), abs(n.y), abs(n.z)) < 0.95:
            info["slanted"] += 1
        p, q = _AXES[axis]
        pmin, ep, qmin, eq = _face_extents(f, sc, p, q)
        if ep >= eq:
            ui, vi, umin, vmin, vext = p, q, pmin, qmin, eq
        else:
            ui, vi, umin, vmin, vext = q, p, qmin, pmin, ep
        vscale = 1.0
        if vext > 1e-6 and (flat or vext > h):
            vscale = h / vext
        u_base = round(umin * PX_PER_M) % SHEET_PX
        for loop in f.loops:
            co = loop.vert.co
            u_pix = (co[ui] * sc[ui] - umin) * PX_PER_M + u_base
            v_pix = (co[vi] * sc[vi] - vmin) * vscale * PX_PER_M
            loop[uv].uv = (u_pix / SHEET_PX, v_bottom + v_pix / SHEET_H)
    return info


def _layout_tiling(bm, uv, sc: Vector) -> dict:
    for f in bm.faces:
        p, q = _AXES[_face_axis(f)]
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = (co[p] * sc[p] / TILE_M, co[q] * sc[q] / TILE_M)
    return {"cuts": 0, "slanted": 0}


class _Cyl:
    """A round part's frame: its axis, the position of each vertex along and around it."""

    def __init__(self, bm, sc: Vector):
        self.pos = {v: _scaled(v.co, sc) for v in bm.verts}
        caps = [f for f in bm.faces if len(f.verts) > 4]
        p0, p1, p2 = (self.pos[caps[0].verts[i]] for i in range(3))
        self.axis = (p1 - p0).cross(p2 - p0).normalized()
        self.e1 = self.axis.cross(Vector((1, 0, 0)) if abs(self.axis.x) < 0.9 else Vector((0, 1, 0))).normalized()
        self.e2 = self.axis.cross(self.e1).normalized()
        self.centre = sum(self.pos.values(), Vector()) / len(self.pos)
        self.ts = {v: (self.pos[v] - self.centre).dot(self.axis) for v in bm.verts}
        self.tmin, tmax = min(self.ts.values()), max(self.ts.values())
        self.length = max(tmax - self.tmin, 1e-6)
        radii = []
        for v in bm.verts:
            d = self.pos[v] - self.centre
            radial = (d - self.axis * d.dot(self.axis)).length
            if radial > 1e-5:
                radii.append(radial)
        self.r_mean = sum(radii) / len(radii) if radii else 0.01
        # The seam sits at the smallest angle, so a face crossing it ends exactly at 2 pi.
        self.theta0 = min(self.theta(v) for v in bm.verts)

    def theta(self, v) -> float:
        d = self.pos[v] - self.centre
        return math.atan2(d.dot(self.e2), d.dot(self.e1))

    def side_angles(self, f) -> list[float]:
        """The angle of each corner of a side quad, 0 to 2 pi, with no jump across the seam."""
        ths = [(self.theta(v) - self.theta0) % (2.0 * math.pi) for v in f.verts]
        if max(ths) - min(ths) > math.pi:
            ths = [t + 2.0 * math.pi if t < math.pi else t for t in ths]
        return ths


def _layout_cyl(bm, uv, sc: Vector, strip: str) -> dict:
    h, v_bottom = _strip_geom(strip)
    cyl = _Cyl(bm, sc)
    pos, centre, e1, e2, ts, tmin = cyl.pos, cyl.centre, cyl.e1, cyl.e2, cyl.ts, cyl.tmin
    length, r_mean = cyl.length, cyl.r_mean
    circ = 2.0 * math.pi * r_mean
    swap = length > h * STRETCH_MAX
    review = ""
    squash = 1.0
    if swap:
        squash = h / circ
        if squash < 0.6 or squash > 1.7:
            review = "cylinder wrapped once on a %.2f m strip, texels x%.2f around" % (h, squash)

    for f in bm.faces:
        if len(f.verts) > 4:
            # Cap: planar. Same strip when it fits, else the Blank strip, scaled down.
            xs = [(pos[v] - centre).dot(e1) for v in f.verts]
            ys = [(pos[v] - centre).dot(e2) for v in f.verts]
            xmin, ymin = min(xs), min(ys)
            dia = max(max(xs) - xmin, max(ys) - ymin, 1e-6)
            cap_strip = strip if (strip in FLAT or dia <= h * STRETCH_MAX) else "Blank"
            ch, cv_bottom = _strip_geom(cap_strip)
            s = min(1.0, ch / dia)
            for loop in f.loops:
                d = pos[loop.vert] - centre
                u = (d.dot(e1) - xmin) * s * PX_PER_M
                v = (d.dot(e2) - ymin) * s * PX_PER_M
                loop[uv].uv = (u / SHEET_PX, cv_bottom + v / SHEET_H)
            continue
        for loop, t in zip(f.loops, cyl.side_angles(f)):
            along = (ts[loop.vert] - tmin) * PX_PER_M
            if swap:
                u_pix = along
                v_pix = t / (2.0 * math.pi) * h * PX_PER_M
            else:
                u_pix = t * r_mean * PX_PER_M
                v_pix = along * (min(1.0, h / length))
            loop[uv].uv = (u_pix / SHEET_PX, v_bottom + v_pix / SHEET_H)
    return {"cuts": 0, "slanted": 0, "review": review}


# --------------------------------------------------------------------------------------
# Cells: one photo of one thing, never cut into bands
# --------------------------------------------------------------------------------------

def _picture_px(slot: int) -> tuple[int, int, int, int]:
    """The cell's picture in sheet px (y from the top), inside its repeated border."""
    x0, y0, x1, y1 = TL.cell_rect(slot)
    p = TL.CELL_PAD
    return x0 + p, y0 + p, x1 - p, y1 - p


def _px_uv(x: float, y_top: float) -> tuple[float, float]:
    return x / SHEET_PX, 1.0 - y_top / SHEET_H


def _face_area(face, sc: Vector) -> float:
    pts = [_scaled(v.co, sc) for v in face.verts]
    total = Vector()
    for i in range(1, len(pts) - 1):
        total += (pts[i] - pts[0]).cross(pts[i + 1] - pts[0])
    return total.length * 0.5


def _right_sign(normal_axis: int, normal_sign: float, u_axis: int) -> float:
    """+1 when picture-right, seen from outside a face with this normal, is +u_axis."""
    n = Vector((0.0, 0.0, 0.0))
    n[normal_axis] = normal_sign
    return 1.0 if (-n).cross(Vector((0.0, 0.0, 1.0)))[u_axis] > 0 else -1.0


def _frac(face, sc: Vector, axis: int, flip: bool) -> "callable":
    vals = [v.co[axis] * sc[axis] for v in face.verts]
    lo, ext = min(vals), max(vals) - min(vals)

    def at(v) -> float:
        t = 0.5 if ext < 1e-6 else (v.co[axis] * sc[axis] - lo) / ext
        return 1.0 - t if flip else t

    return at


def _layout_cell_box(bm, uv, sc: Vector, slot: int) -> dict:
    """Large faces show the whole picture, corner to corner. A thin edge face samples a 2 px
    sliver just inside the picture's matching edge, so it takes the border colour."""
    ix0, iy0, ix1, iy1 = _picture_px(slot)
    areas = {f: _face_area(f, sc) for f in bm.faces}
    biggest = max(areas.values())
    f_axis = _face_axis(max(bm.faces, key=lambda f: areas[f]))
    if f_axis == 2:
        ua, va, ref_us = 0, 1, 1.0
    else:
        va = 2
        ua = 1 if f_axis == 0 else 0
        ref_us = _right_sign(f_axis, -1.0, ua)
    slanted = 0
    for f in bm.faces:
        a = _face_axis(f)
        sg = 1.0 if f.normal[a] >= 0 else -1.0
        if max(abs(f.normal.x), abs(f.normal.y), abs(f.normal.z)) < 0.95:
            slanted += 1
        if areas[f] >= CELL_LARGE_FACE * biggest or a == f_axis:
            if a == 2:
                u_ax, v_ax, us, vs = 0, 1, 1.0, sg
            else:
                v_ax, u_ax, vs = 2, (1 if a == 0 else 0), 1.0
                us = _right_sign(a, sg, u_ax)
            fu = _frac(f, sc, u_ax, us < 0)
            fv = _frac(f, sc, v_ax, vs < 0)
            for loop in f.loops:
                x = ix0 + fu(loop.vert) * (ix1 - ix0)
                y = iy1 - fv(loop.vert) * (iy1 - iy0)
                loop[uv].uv = _px_uv(x, y)
            continue
        depth = _frac(f, sc, f_axis, False)
        along_ax = va if a == ua else ua
        along = _frac(f, sc, along_ax, along_ax == ua and ref_us < 0)
        for loop in f.loops:
            inset = 0.5 + (CELL_SLIVER_PX - 0.5) * depth(loop.vert)
            t = along(loop.vert)
            if a == ua:
                x = ix1 - inset if sg * ref_us > 0 else ix0 + inset
                y = iy1 - t * (iy1 - iy0)
            else:
                x = ix0 + t * (ix1 - ix0)
                y = iy0 + inset if sg > 0 else iy1 - inset
            loop[uv].uv = _px_uv(x, y)
    return {"cuts": 0, "slanted": slanted}


def _layout_cell_cyl(bm, uv, sc: Vector, slot: int, cyl: "_Cyl") -> dict:
    """The side wraps the picture once, axis along the picture's height. The caps sit on the
    picture's top border, one texel, so they take the border colour."""
    ix0, iy0, ix1, iy1 = _picture_px(slot)
    dominant = max(range(3), key=lambda i: abs(cyl.axis[i]))
    up = cyl.axis[dominant] > 0
    cap = _px_uv((ix0 + ix1) * 0.5, iy0 + 1.0)
    for f in bm.faces:
        if len(f.verts) > 4:
            for loop in f.loops:
                loop[uv].uv = cap
            continue
        for loop, t in zip(f.loops, cyl.side_angles(f)):
            fv = (cyl.ts[loop.vert] - cyl.tmin) / cyl.length
            if not up:
                fv = 1.0 - fv
            loop[uv].uv = _px_uv(ix0 + t / (2.0 * math.pi) * (ix1 - ix0), iy1 - fv * (iy1 - iy0))
    return {"cuts": 0, "slanted": 0}


def unwrap_object(obj, role: str, cell_slot: int | None = None) -> dict:
    """Replaces the object's UV maps with one UVMap laid out for `role`.

    `cell_slot` lays the object on that photo cell instead of a strip.
    """
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    for layer in list(bm.loops.layers.uv):
        bm.loops.layers.uv.remove(layer)
    uv = bm.loops.layers.uv.new(UV_NAME)
    bm.normal_update()
    sc = Vector(obj.scale)
    if role == TILING:
        info = _layout_tiling(bm, uv, sc)
    elif cell_slot is not None:
        cyl = _Cyl(bm, sc) if _is_cylinder(me, sc) else None
        if cyl is not None and cyl.length >= CELL_DISC * 2.0 * cyl.r_mean:
            info = _layout_cell_cyl(bm, uv, sc, cell_slot, cyl)
        else:
            info = _layout_cell_box(bm, uv, sc, cell_slot)
    elif _is_cylinder(me, sc):
        info = _layout_cyl(bm, uv, sc, role)
    else:
        info = _layout_box(bm, uv, sc, role)
    if cell_slot is not None and _is_cylinder(me, sc):
        info["slanted"] = 0  # a disc's rim faces are round, not slanted
    if info.get("slanted") and not info.get("review"):
        info["review"] = "%d slanted faces projected along their dominant axis" % info["slanted"]
    if info.get("cuts", 0) < 0:
        info["review"] = "band cutting did not settle"
    bm.to_mesh(me)
    bm.free()
    me.update()
    return info


def _root_of(obj):
    while obj.parent is not None:
        obj = obj.parent
    return obj


def _tri_count(obj) -> int:
    me = obj.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def process_scene(only=None) -> dict:
    """UV-unwraps every scenery object in the open file, then wires the sheet preview.

    `only` limits the pass to objects whose name is in the set. Returns a stats dict.
    """
    ensure_sheet()
    manifest = TL.load_manifest(MANIFEST_PATH)
    stats = {"objects": 0, "unwrapped": 0, "tiling": 0, "skipped": 0, "locked": 0, "cells": 0,
             "review": [], "tris_before": 0, "tris_after": 0, "cuts": 0}
    wired = set()
    for obj in sorted(bpy.data.objects, key=lambda o: o.name):
        if obj.type != "MESH" or _is_collision(obj):
            continue
        if only is not None and obj.name not in only:
            continue
        stats["objects"] += 1
        if obj.get("uv_lock"):
            stats["locked"] += 1
            continue
        role, note = classify(obj)
        if role == SKIP:
            obj["uv_role"] = SKIP
            obj.pop("uv_cell", None)
            if note:
                obj["uv_review"] = note
                stats["review"].append((obj.name, note))
            else:
                obj.pop("uv_review", None)
            stats["skipped"] += 1
            continue
        cell_slot = None
        cell = TL.cell_for_name(obj.name) if role != TILING else None
        if cell is not None:
            cell_slot = manifest.slot_for(cell, TL.building_key(_root_of(obj).name))
        before = _tri_count(obj)
        info = unwrap_object(obj, role, cell_slot)
        after = _tri_count(obj)
        if cell_slot is not None:
            role = CELL_PREFIX + cell
            obj["uv_cell"] = cell_slot
            stats["cells"] += 1
        else:
            obj.pop("uv_cell", None)
        stats["tris_before"] += before
        stats["tris_after"] += after
        stats["cuts"] += max(info.get("cuts", 0), 0)
        obj["uv_role"] = role
        review = info.get("review", "")
        if review:
            obj["uv_review"] = review
            stats["review"].append((obj.name, review))
        else:
            obj.pop("uv_review", None)
        if role == TILING:
            stats["tiling"] += 1
        else:
            stats["unwrapped"] += 1
            for slot in obj.material_slots:
                if slot.material:
                    wired.add(slot.material)
    wire_preview(wired)
    return stats


def check_scene() -> list[str]:
    """Every sheet-role object has a UV map with each corner inside its strip's rows, or its
    cell's rectangle (the 4 px repeated border included)."""
    problems = []
    eps = 0.01 / SHEET_PX
    for obj in bpy.data.objects:
        if obj.type != "MESH" or _is_collision(obj):
            continue
        role = obj.get("uv_role")
        is_cell = isinstance(role, str) and role.startswith(CELL_PREFIX)
        if (role not in STRIPS and role != TILING and not is_cell) or obj.get("uv_lock"):
            continue
        me = obj.data
        layer = me.uv_layers.get(UV_NAME)
        if layer is None:
            problems.append("%s: no UV map" % obj.name)
            continue
        if role == TILING:
            continue
        if is_cell:
            slot = obj.get("uv_cell")
            if slot is None or not 0 <= int(slot) < len(TL.CELLS):
                problems.append("%s: %s has no valid uv_cell slot" % (obj.name, role))
                continue
            x0, y0, x1, y1 = TL.cell_rect(int(slot))
            u_lo, u_hi = x0 / SHEET_PX - eps, x1 / SHEET_PX + eps
            lo, hi = 1.0 - y1 / SHEET_H - eps, 1.0 - y0 / SHEET_H + eps
            for poly in me.polygons:
                bad = next((layer.data[li].uv for li in poly.loop_indices
                            if not (u_lo <= layer.data[li].uv[0] <= u_hi and lo <= layer.data[li].uv[1] <= hi)), None)
                if bad is not None:
                    problems.append("%s: uv (%.4f, %.4f) outside %s (slot %d)" % (
                        obj.name, bad[0], bad[1], role, int(slot)))
                    break
            continue
        r0, r1 = STRIPS[role]
        lo, hi = 1.0 - r1 / SHEET_H - eps, 1.0 - r0 / SHEET_H + eps
        for poly in me.polygons:
            for li in poly.loop_indices:
                u, v = layer.data[li].uv
                if v < lo or v > hi:
                    # Cylinder caps on a big object sit on Blank, a different strip.
                    brow = STRIPS["Blank"]
                    if len(poly.vertices) > 4 and 1.0 - brow[1] / SHEET_H - eps <= v <= 1.0 - brow[0] / SHEET_H + eps:
                        continue
                    problems.append("%s: v %.4f outside %s" % (obj.name, v, role))
                    break
            else:
                continue
            break
    return problems


# --------------------------------------------------------------------------------------
# Placeholder sheet and Blender preview
# --------------------------------------------------------------------------------------

_FONT = {
    "A": ".###.|#...#|#...#|#####|#...#|#...#|#...#", "B": "####.|#...#|#...#|####.|#...#|#...#|####.",
    "D": "####.|#...#|#...#|#...#|#...#|#...#|####.", "E": "#####|#....|#....|####.|#....|#....|#####",
    "G": ".###.|#...#|#....|#.###|#...#|#...#|.###.", "H": "#...#|#...#|#...#|#####|#...#|#...#|#...#",
    "I": "#####|..#..|..#..|..#..|..#..|..#..|#####", "K": "#...#|#..#.|#.#..|##...|#.#..|#..#.|#...#",
    "L": "#....|#....|#....|#....|#....|#....|#####", "M": "#...#|##.##|#.#.#|#.#.#|#...#|#...#|#...#",
    "N": "#...#|##..#|#.#.#|#..##|#...#|#...#|#...#", "O": ".###.|#...#|#...#|#...#|#...#|#...#|.###.",
    "R": "####.|#...#|#...#|####.|#.#..|#..#.|#...#", "S": ".####|#....|#....|.###.|....#|....#|####.",
    "T": "#####|..#..|..#..|..#..|..#..|..#..|..#..", "U": "#...#|#...#|#...#|#...#|#...#|#...#|.###.",
    "Y": "#...#|#...#|.#.#.|..#..|..#..|..#..|..#..",
    "C": ".###.|#...#|#....|#....|#....|#...#|.###.", "F": "#####|#....|#....|####.|#....|#....|#....",
    "P": "####.|#...#|#...#|####.|#....|#....|#....", "W": "#...#|#...#|#...#|#.#.#|#.#.#|##.##|#...#",
}
_TINTS = TL.DEBUG_TINTS
_NEUTRAL_TINTS = TL.NEUTRAL_TINTS


def ensure_sheet(force: bool = False, neutral: bool = True) -> str:
    """Writes a placeholder sheet to assets/textures/trim_sheet.png when it is missing.

    The real one comes from `dev/build_trim_sheet.py`; this is the fallback for a clone that
    has not run it. neutral: one flat color per strip and cell and a faint metre line on the
    strips, the sheet the game wears. False writes the labelled debug sheet (strip and cell
    borders, texel grid, names).
    """
    if os.path.exists(SHEET_PATH) and not force:
        return SHEET_PATH
    os.makedirs(os.path.dirname(SHEET_PATH), exist_ok=True)
    px = [0.0] * (SHEET_PX * SHEET_H * 4)
    tints = _NEUTRAL_TINTS if neutral else _TINTS

    def put(x, y_top, rgb, k=1.0):
        if 0 <= x < SHEET_PX and 0 <= y_top < SHEET_H:
            i = ((SHEET_H - 1 - y_top) * SHEET_PX + x) * 4
            px[i:i + 4] = [rgb[0] * k, rgb[1] * k, rgb[2] * k, 1.0]

    def label(text, x0, y_top, tint):
        cx = x0
        for ch in text.upper():
            rows = _FONT.get(ch)
            if rows is not None:
                for ry, line in enumerate(rows.split("|")):
                    for rx, c in enumerate(line):
                        if c == "#":
                            put(cx + rx, y_top + ry, tint, 0.3)
            cx += 6

    for name, (r0, r1) in STRIPS.items():
        tint = tints[name]
        for y in range(r0, r1):
            for x in range(SHEET_PX):
                k = 1.0
                if neutral:
                    if x % 64 == 0 and name != "Blank":
                        k = 0.93  # one metre
                elif y == r0 or y == r1 - 1:
                    k = 0.55  # strip borders
                elif x % 64 == 0:
                    k = 0.8  # one metre
                elif (x % 8 == 0 or y % 8 == 0):
                    k = 0.94  # texel grid, every eighth texel
                put(x, y, tint, k)
        if not neutral:
            for x0 in (4, 260):
                label(name, x0, r0 + max(1, (r1 - r0 - 7) // 2), tint)
    for slot, name in enumerate(TL.CELLS):
        tint = tints[TL.CELL_STRIP[name]]
        x0, y0, x1, y1 = TL.cell_rect(slot)
        for y in range(y0, y1):
            for x in range(x0, x1):
                k = 1.0
                if not neutral:
                    edge = min(x - x0, x1 - 1 - x, y - y0, y1 - 1 - y)
                    k = 0.55 if edge == 0 else (0.8 if edge == TL.CELL_PAD else 1.0)
                put(x, y, tint, k)
        if not neutral:
            label(name.replace("_", " "), x0 + 8, y0 + 8, tint)
    img = bpy.data.images.new("trim_sheet_placeholder", SHEET_PX, SHEET_H, alpha=False)
    img.pixels = px
    img.filepath_raw = SHEET_PATH
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return SHEET_PATH


def _principled(mat):
    return next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)


def wire_preview(materials) -> None:
    """Shows the sheet on the given materials, Closest filtered, in place of Base Color.

    The Base Color value stays on the socket, so `set_preview(False)` restores the export.
    """
    img = None
    for m in materials:
        if m is None or not m.use_nodes:
            continue
        bsdf = _principled(m)
        if bsdf is None:
            continue
        if img is None:
            img = next((i for i in bpy.data.images
                        if os.path.normcase(bpy.path.abspath(i.filepath)) == os.path.normcase(SHEET_PATH)), None)
            if img is None:
                img = bpy.data.images.load(SHEET_PATH)
        nodes = m.node_tree.nodes
        tex = nodes.get(PREVIEW_NODE)
        if tex is None:
            tex = nodes.new("ShaderNodeTexImage")
            tex.name = PREVIEW_NODE
            tex.label = "Trim sheet preview"
            tex.location = (bsdf.location.x - 320, bsdf.location.y)
        tex.image = img
        tex.interpolation = "Closest"
        tex.extension = "REPEAT"
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])


def set_preview(on: bool) -> None:
    """Links (on) or unlinks (off) the sheet from Base Color on every preview material."""
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        tex = m.node_tree.nodes.get(PREVIEW_NODE)
        bsdf = _principled(m)
        if tex is None or bsdf is None:
            continue
        socket = bsdf.inputs["Base Color"]
        if on:
            m.node_tree.links.new(tex.outputs["Color"], socket)
        else:
            for link in list(socket.links):
                m.node_tree.links.remove(link)


# --------------------------------------------------------------------------------------
# Export
# --------------------------------------------------------------------------------------

def select_hierarchy(root) -> None:
    for o in bpy.context.view_layer.objects:
        o.select_set(False)

    def _sel(o):
        o.select_set(True)
        for c in o.children:
            _sel(c)

    _sel(root)
    bpy.context.view_layer.objects.active = root


def export_glb(root, path: str) -> None:
    """glTF 2.0 binary, Y up, with UVs and no images: the sheet is unhooked while it runs."""
    select_hierarchy(root)
    set_preview(False)
    try:
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            export_yup=True,
            use_selection=True,
            export_apply=True,
            export_texcoords=True,
            export_image_format="NONE",
        )
    finally:
        set_preview(True)
