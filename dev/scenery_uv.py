"""Automatic trim-sheet UVs for the scenario `.blend` files (Blender 4.x / 5.x).

The scenario GLBs carry no UVs. This module gives every built object a UV map laid on
a 512 px trim sheet at 64 px per metre, writes a placeholder sheet, previews it on the
materials, and exports GLBs that keep their Base Color and no image. Layout and rules:
`docs/TEXTURING.md`.

Import from a build script::

    import scenery_uv
    scenery_uv.process_scene()        # UVs + sheet preview, before saving the .blend
    scenery_uv.export_glb(root, path) # drop-in for the build scripts' export_glb

An object with the custom property ``uv_lock`` is never touched. After a run each object
carries ``uv_role`` (strip name, ``tiling``, or ``skip``) and, when it needs a look,
``uv_review`` (the reason).
"""
from __future__ import annotations

import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET_PATH = os.path.join(ROOT, "assets", "textures", "trim_sheet.png")
SHEET_PX = 512
PX_PER_M = 64.0
UV_NAME = "UVMap"
TILE_M = SHEET_PX / PX_PER_M  # metres covered by the full sheet width: 8
PREVIEW_NODE = "TrimSheetPreview"
# A face this much taller than its strip is squeezed to fit; anything taller is cut into bands.
STRETCH_MAX = 1.3

# Strip name, height in px, top to bottom. Same table as docs/TEXTURING.md.
STRIP_ROWS = [
    ("Siding", 128), ("Masonry", 128), ("Shingles", 64), ("Boards", 64), ("Beam", 32),
    ("Metal", 32), ("Glass", 32), ("Moulding", 16), ("Blank", 16),
]
STRIPS: dict[str, tuple[int, int]] = {}
_row = 0
for _name, _h in STRIP_ROWS:
    STRIPS[_name] = (_row, _row + _h)
    _row += _h
assert _row == SHEET_PX
# Flat fills: texel density is irrelevant, so a face is scaled to fit instead of cut.
FLAT = {"Glass", "Blank"}
TILING = "tiling"
SKIP = "skip"

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


def _is_cylinder(me) -> bool:
    caps = [p for p in me.polygons if len(p.vertices) > 4]
    quads = sum(1 for p in me.polygons if len(p.vertices) == 4)
    return len(caps) == 2 and quads + 2 == len(me.polygons)


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
    cyl = _is_cylinder(obj.data)
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
    return (r1 - r0) / PX_PER_M, 1.0 - r1 / SHEET_PX


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
            loop[uv].uv = (u_pix / SHEET_PX, v_bottom + v_pix / SHEET_PX)
    return info


def _layout_tiling(bm, uv, sc: Vector) -> dict:
    for f in bm.faces:
        p, q = _AXES[_face_axis(f)]
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = (co[p] * sc[p] / TILE_M, co[q] * sc[q] / TILE_M)
    return {"cuts": 0, "slanted": 0}


def _layout_cyl(bm, uv, sc: Vector, strip: str) -> dict:
    h, v_bottom = _strip_geom(strip)
    pos = {v: _scaled(v.co, sc) for v in bm.verts}
    caps = [f for f in bm.faces if len(f.verts) > 4]
    p0, p1, p2 = (pos[caps[0].verts[i]] for i in range(3))
    axis = (p1 - p0).cross(p2 - p0).normalized()
    e1 = axis.cross(Vector((1, 0, 0)) if abs(axis.x) < 0.9 else Vector((0, 1, 0))).normalized()
    e2 = axis.cross(e1).normalized()
    centre = sum(pos.values(), Vector()) / len(pos)
    ts = {v: (pos[v] - centre).dot(axis) for v in bm.verts}
    tmin, tmax = min(ts.values()), max(ts.values())
    length = max(tmax - tmin, 1e-6)
    radii = []
    for v in bm.verts:
        d = pos[v] - centre
        radial = (d - axis * d.dot(axis)).length
        if radial > 1e-5:
            radii.append(radial)
    r_mean = sum(radii) / len(radii) if radii else 0.01
    circ = 2.0 * math.pi * r_mean
    swap = length > h * STRETCH_MAX
    review = ""
    squash = 1.0
    if swap:
        squash = h / circ
        if squash < 0.6 or squash > 1.7:
            review = "cylinder wrapped once on a %.2f m strip, texels x%.2f around" % (h, squash)

    def theta(v):
        d = pos[v] - centre
        return math.atan2(d.dot(e2), d.dot(e1))

    # The seam sits at the smallest angle, so a face crossing it ends exactly at 2 pi.
    theta0 = min(theta(v) for v in bm.verts)
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
                loop[uv].uv = (u / SHEET_PX, cv_bottom + v / SHEET_PX)
            continue
        ths = [(theta(v) - theta0) % (2.0 * math.pi) for v in f.verts]
        if max(ths) - min(ths) > math.pi:
            ths = [t + 2.0 * math.pi if t < math.pi else t for t in ths]
        for loop, t in zip(f.loops, ths):
            along = (ts[loop.vert] - tmin) * PX_PER_M
            if swap:
                u_pix = along
                v_pix = t / (2.0 * math.pi) * h * PX_PER_M
            else:
                u_pix = t * r_mean * PX_PER_M
                v_pix = along * (min(1.0, h / length))
            loop[uv].uv = (u_pix / SHEET_PX, v_bottom + v_pix / SHEET_PX)
    return {"cuts": 0, "slanted": 0, "review": review}


def unwrap_object(obj, role: str) -> dict:
    """Replaces the object's UV maps with one UVMap laid out for `role`."""
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
    elif _is_cylinder(me):
        info = _layout_cyl(bm, uv, sc, role)
    else:
        info = _layout_box(bm, uv, sc, role)
    if info.get("slanted") and not info.get("review"):
        info["review"] = "%d slanted faces projected along their dominant axis" % info["slanted"]
    if info.get("cuts", 0) < 0:
        info["review"] = "band cutting did not settle"
    bm.to_mesh(me)
    bm.free()
    me.update()
    return info


def _tri_count(obj) -> int:
    me = obj.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def process_scene(only=None) -> dict:
    """UV-unwraps every scenery object in the open file, then wires the sheet preview.

    `only` limits the pass to objects whose name is in the set. Returns a stats dict.
    """
    ensure_sheet()
    stats = {"objects": 0, "unwrapped": 0, "tiling": 0, "skipped": 0, "locked": 0,
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
            if note:
                obj["uv_review"] = note
                stats["review"].append((obj.name, note))
            else:
                obj.pop("uv_review", None)
            stats["skipped"] += 1
            continue
        before = _tri_count(obj)
        info = unwrap_object(obj, role)
        after = _tri_count(obj)
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
    """Every strip-role object has a UV map with each corner inside its strip's rows."""
    problems = []
    eps = 1.0 / SHEET_PX * 0.01
    for obj in bpy.data.objects:
        if obj.type != "MESH" or _is_collision(obj):
            continue
        role = obj.get("uv_role")
        if role not in STRIPS and role != TILING or obj.get("uv_lock"):
            continue
        me = obj.data
        layer = me.uv_layers.get(UV_NAME)
        if layer is None:
            problems.append("%s: no UV map" % obj.name)
            continue
        if role == TILING:
            continue
        r0, r1 = STRIPS[role]
        lo, hi = 1.0 - r1 / SHEET_PX - eps, 1.0 - r0 / SHEET_PX + eps
        for poly in me.polygons:
            for li in poly.loop_indices:
                u, v = layer.data[li].uv
                if v < lo or v > hi:
                    # Cylinder caps on a big object sit on Blank, a different strip.
                    brow = STRIPS["Blank"]
                    if len(poly.vertices) > 4 and 1.0 - brow[1] / SHEET_PX - eps <= v <= 1.0 - brow[0] / SHEET_PX + eps:
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
}
_TINTS = {
    "Siding": (0.80, 0.62, 0.40), "Masonry": (0.62, 0.58, 0.54), "Shingles": (0.45, 0.30, 0.24),
    "Boards": (0.66, 0.50, 0.32), "Beam": (0.40, 0.28, 0.18), "Metal": (0.42, 0.46, 0.52),
    "Glass": (0.60, 0.78, 0.88), "Moulding": (0.88, 0.82, 0.68), "Blank": (1.0, 1.0, 1.0),
}


def ensure_sheet(force: bool = False) -> str:
    """Writes the placeholder sheet to assets/textures/trim_sheet.png when it is missing."""
    if os.path.exists(SHEET_PATH) and not force:
        return SHEET_PATH
    os.makedirs(os.path.dirname(SHEET_PATH), exist_ok=True)
    px = [0.0] * (SHEET_PX * SHEET_PX * 4)

    def put(x, y_top, rgb, k=1.0):
        if 0 <= x < SHEET_PX and 0 <= y_top < SHEET_PX:
            i = ((SHEET_PX - 1 - y_top) * SHEET_PX + x) * 4
            px[i:i + 4] = [rgb[0] * k, rgb[1] * k, rgb[2] * k, 1.0]

    for name, (r0, r1) in STRIPS.items():
        tint = _TINTS[name]
        for y in range(r0, r1):
            for x in range(SHEET_PX):
                k = 1.0
                if y == r0 or y == r1 - 1:
                    k = 0.55  # strip borders
                elif x % 64 == 0:
                    k = 0.8  # one metre
                elif (x % 8 == 0 or y % 8 == 0):
                    k = 0.94  # texel grid, every eighth texel
                put(x, y, tint, k)
        for x0 in (4, 260):
            cx = x0
            for ch in name.upper():
                rows = _FONT.get(ch)
                if rows is None:
                    continue
                top = r0 + max(1, (r1 - r0 - 7) // 2)
                for ry, line in enumerate(rows.split("|")):
                    for rx, c in enumerate(line):
                        if c == "#":
                            put(cx + rx, top + ry, tint, 0.3)
                cx += 6
    img = bpy.data.images.new("trim_sheet_placeholder", SHEET_PX, SHEET_PX, alpha=False)
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
    bpy.ops.object.select_all(action="DESELECT")

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
