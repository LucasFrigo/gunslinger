"""Hand-painted texture per GLB: fresh 0-1 UVs, per-GLB materials, image hookup, GLB export.

For each GLB root in the scenario `.blend` files this script
  1. gives the GLB its own copy of every non-tiling material it uses (`M_Wood__bld_bank`),
  2. unwraps every non-tiling, non-collision mesh into ONE 256x256 layout at one texel density
     (`uv_role = "glb"`, `uv_lock = 1`, one UV map named `UVMap`),
  3. points each of those materials at one shared Image Texture node (Closest) reading
     `<map>/tex/<glb>.png`, linked to Base Color only when that PNG exists,
  4. saves the `.blend` and exports the GLB, embedding the image when one is linked.

Ground and rock (`TILING_MATERIALS` in `scenery_uv.py`) and collision proxies are not touched.
A GLB whose meshes already carry `uv_role = "glb"` keeps its UVs, so hand work survives a re-run;
`--relayout` throws them away. See `docs/TEXTURING.md` ("Hand-painted texture per GLB").

Run:
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/unwrap_per_glb_blender.py
    ... -- --map saloon          one map (main_street, saloon, train_rooftop, practice_hub, canyon)
    ... -- --glb bld_bank        one GLB
    ... -- --link --glb bld_bank after saving tex/bld_bank.png: link it, save, re-export (no unwrap)
    ... -- --dry                 compute and report; save and export nothing
    ... -- --relayout           redo the UVs of GLBs that already have them (loses hand work)
    ... -- --rotate             let the packer turn islands 90 degrees (denser, harder to paint)
"""
from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_uv as SU  # noqa: E402
from unwrap_scenery_blender import MAPS, PARKED_CHILDREN, SCENARIOS  # noqa: E402

TEX_PX = 256
PAD_PX = 2  # empty px on every side of an island: 4 px between neighbours, 2 from the edge
ROLE = "glb"
TEX_NODE = "GlbTexture"
SEP = "__"
CHART_COS = math.cos(math.radians(66.0))  # Smart UV Project's default angle limit
TINY_PX2 = 16.0  # a mesh with less texture area than this cannot be painted
PAD_KEEP = 0.75  # a pad is kept while it costs less than a quarter of the no-pad density


# --------------------------------------------------------------------------------------
# Names and materials
# --------------------------------------------------------------------------------------

def base_name(material_name: str) -> str:
    """`M_Wood__bld_bank.001` -> `M_Wood`."""
    return material_name.split(SEP)[0].split(".")[0]


def glb_meshes(root) -> list:
    out = []

    def walk(o):
        if o.type == "MESH" and not SU._is_collision(o):
            out.append(o)
        for c in o.children:
            walk(c)

    walk(root)
    return out


def is_tiling(obj) -> bool:
    mat = obj.data.materials[0] if obj.data.materials else None
    return mat is not None and base_name(mat.name) in SU.TILING_MATERIALS


def per_glb_materials(root, glb: str) -> int:
    """Gives every non-tiling slot a copy named `<base>__<glb>`. Returns the copies made."""
    made = 0
    for obj in glb_meshes(root):
        for slot in obj.material_slots:
            mat = slot.material
            if mat is None:
                continue
            base = base_name(mat.name)
            if base in SU.TILING_MATERIALS:
                continue
            want = base + SEP + glb
            if mat.name == want:
                continue
            new = bpy.data.materials.get(want)
            if new is None:
                new = mat.copy()
                new.name = want
                made += 1
            slot.material = new
    return made


# --------------------------------------------------------------------------------------
# Unwrap: islands in metres
# --------------------------------------------------------------------------------------

class Island:
    """Faces' loops with (u, v) in metres, shifted so the bounding box starts at 0."""

    def __init__(self, obj_index: int, loops: list, uvs: list):
        us = [p[0] for p in uvs]
        vs = [p[1] for p in uvs]
        u0, v0 = min(us), min(vs)
        self.obj_index = obj_index
        self.loops = loops
        self.uvs = [(u - u0, v - v0) for u, v in uvs]
        self.w = max(max(us) - u0, 1e-4)
        self.h = max(max(vs) - v0, 1e-4)


def _newell(pts: list) -> Vector:
    n = Vector((0.0, 0.0, 0.0))
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


def _basis(n: Vector) -> tuple[Vector, Vector]:
    """(u, v) axes of a plane seen from outside along its normal: v up, u right."""
    ref = Vector((0.0, 0.0, 1.0))
    if abs(n.z) > 0.99:
        ref = Vector((0.0, 1.0, 0.0))
    v = (ref - n * ref.dot(n)).normalized()
    return v.cross(n).normalized(), v


def _chart_islands(bm, mw, obj_index: int) -> list:
    """Region-grown charts (a face joins when its normal is within 66 degrees of the seed's),
    each projected flat in world metres."""
    bm.faces.ensure_lookup_table()
    world = {v: mw @ v.co for v in bm.verts}
    normal, area = {}, {}
    for f in bm.faces:
        pts = [world[v] for v in f.verts]
        n = _newell(pts)
        area[f] = n.length * 0.5
        normal[f] = n.normalized() if n.length > 1e-12 else Vector((0.0, 0.0, 1.0))
    seen = set()
    islands = []
    for seed in sorted(bm.faces, key=lambda f: -area[f]):
        if seed in seen:
            continue
        seen.add(seed)
        region = [seed]
        queue = [seed]
        while queue:
            f = queue.pop()
            for e in f.edges:
                for nb in e.link_faces:
                    if nb not in seen and normal[nb].dot(normal[seed]) >= CHART_COS:
                        seen.add(nb)
                        region.append(nb)
                        queue.append(nb)
        total = Vector((0.0, 0.0, 0.0))
        for f in region:
            total += normal[f] * max(area[f], 1e-9)
        n = total.normalized() if total.length > 1e-12 else normal[seed]
        ub, vb = _basis(n)
        loops, uvs = [], []
        for f in region:
            for loop in f.loops:
                p = world[loop.vert]
                loops.append(loop)
                uvs.append((p.dot(ub), p.dot(vb)))
        islands.append(Island(obj_index, loops, uvs))
    return islands


def _cylinder_islands(bm, sc: Vector, obj_index: int) -> list:
    """Side unrolled into one rectangle, each cap flat."""
    cyl = SU._Cyl(bm, sc)
    flip = cyl.axis.z < -1e-3  # keep the picture upright: axis up
    circ = 2.0 * math.pi * cyl.r_mean
    loops, uvs = [], []
    islands = []
    for f in bm.faces:
        if len(f.verts) > 4:
            pts = [cyl.pos[v] for v in f.verts]
            outward = (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(cyl.axis) >= 0.0
            cl, cu = [], []
            for loop in f.loops:
                d = cyl.pos[loop.vert] - cyl.centre
                x = d.dot(cyl.e1)
                cl.append(loop)
                cu.append((x if outward else -x, d.dot(cyl.e2)))
            islands.append(Island(obj_index, cl, cu))
            continue
        for loop, t in zip(f.loops, cyl.side_angles(f)):
            u = t * cyl.r_mean
            v = cyl.ts[loop.vert] - cyl.tmin
            loops.append(loop)
            uvs.append((circ - u, cyl.length - v) if flip else (u, v))
    if loops:
        islands.append(Island(obj_index, loops, uvs))
    return islands


# --------------------------------------------------------------------------------------
# Packing
# --------------------------------------------------------------------------------------

def _pack(sizes: list, side: int, rotate: bool):
    """Bottom-left first fit on a pixel grid (holes get filled). sizes: [(w, h)] whole px.
    Returns [(x, y, turned)] or None when something does not fit."""
    grid = np.zeros((side, side), dtype=np.int32)
    table = np.zeros((side + 1, side + 1), dtype=np.int32)  # summed-area table of grid
    out = [None] * len(sizes)
    for i in sorted(range(len(sizes)), key=lambda k: (-max(sizes[k]), -min(sizes[k]))):
        best = None
        for turned, (w, h) in ((False, sizes[i]), (True, sizes[i][::-1])):
            if (turned and not rotate) or w > side or h > side:
                continue
            win = table[h:, w:] - table[:-h, w:] - table[h:, :-w] + table[:-h, :-w]
            hit = np.flatnonzero(win == 0)
            if hit.size == 0:
                continue
            y, x = divmod(int(hit[0]), win.shape[1])
            if best is None or (y, x) < best[:2]:
                best = (y, x, w, h, turned)
        if best is None:
            return None
        y, x, w, h, turned = best
        out[i] = (x, y, turned)
        grid[y:y + h, x:x + w] = 1
        table[1:, 1:] = grid.cumsum(0).cumsum(1)
    return out


def _sizes(islands: list, s: float, pad: int) -> list:
    return [(math.ceil(i.w * s) + 2 * pad, math.ceil(i.h * s) + 2 * pad) for i in islands]


def _search(islands: list, pad: int, rotate: bool, s_hi: float):
    lo, found = 0.0, None
    hi = s_hi
    for _ in range(11):
        mid = (lo + hi) * 0.5
        spots = _pack(_sizes(islands, mid, pad), TEX_PX, rotate)
        if spots is None:
            hi = mid
        else:
            lo, found = mid, (mid, pad, spots)
    return found


def pack_islands(islands: list, rotate: bool):
    """Largest uniform px-per-metre that fits every island in 256x256, with a pad of 2 px on
    each side of an island unless that costs a quarter of the density; then 1, then 0.
    Returns (px per metre, pad, [(x, y, turned)])."""
    area = sum(i.w * i.h for i in islands)
    s_hi = math.sqrt(TEX_PX * TEX_PX / max(area, 1e-9))
    tight = _search(islands, 0, rotate, s_hi)
    for pad in (PAD_PX, 1):
        found = _search(islands, pad, rotate, s_hi)
        if found is not None and found[0] >= PAD_KEEP * tight[0]:
            return found
    return tight


# --------------------------------------------------------------------------------------
# Unwrap a GLB
# --------------------------------------------------------------------------------------

def unwrap_glb(root, rotate: bool) -> dict:
    targets = [o for o in glb_meshes(root) if not is_tiling(o) and len(o.data.polygons)]
    bms, islands = [], []
    for idx, obj in enumerate(targets):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        for layer in list(bm.loops.layers.uv):
            bm.loops.layers.uv.remove(layer)
        bm.loops.layers.uv.new(SU.UV_NAME)
        bms.append(bm)
        mw = obj.matrix_world
        sc = Vector(mw.to_scale())
        if SU._is_cylinder(obj.data, sc):
            islands += _cylinder_islands(bm, sc, idx)
        else:
            islands += _chart_islands(bm, mw, idx)
    stats = {"meshes": len(targets), "islands": len(islands), "tiling": len(glb_meshes(root)) - len(targets),
             "density": 0.0, "pad": PAD_PX, "coverage": 0.0, "tiny": []}
    if not islands:
        for bm in bms:
            bm.free()
        return stats
    s, pad, spots = pack_islands(islands, rotate)
    share = [0.0] * len(targets)
    for isl, (x, y, turned) in zip(islands, spots):
        w, h = isl.w, isl.h
        ox, oy = x + pad, y + pad
        uv = bms[isl.obj_index].loops.layers.uv[SU.UV_NAME]
        for loop, (u, v) in zip(isl.loops, isl.uvs):
            if turned:
                u, v = h - v, u
            px = ox + u * s
            py = oy + ((w if turned else h) - v) * s
            loop[uv].uv = (px / TEX_PX, 1.0 - py / TEX_PX)
        share[isl.obj_index] += w * h * s * s
    for obj, bm, px2 in zip(targets, bms, share):
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        obj["uv_role"] = ROLE
        obj["uv_lock"] = 1
        obj.pop("uv_cell", None)
        obj.pop("uv_review", None)
        if px2 < TINY_PX2:
            stats["tiny"].append((obj.name, px2))
    stats["density"] = s
    stats["pad"] = pad
    stats["coverage"] = sum(share) / (TEX_PX * TEX_PX)
    return stats


# --------------------------------------------------------------------------------------
# Image hookup
# --------------------------------------------------------------------------------------

def _principled(mat):
    return next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)


def glb_materials(root) -> list:
    seen, out = set(), []
    for obj in glb_meshes(root):
        if is_tiling(obj):
            continue
        for slot in obj.material_slots:
            m = slot.material
            if m is not None and m.name not in seen:
                seen.add(m.name)
                out.append(m)
    return out


def hookup(root, glb: str, directory: str) -> bool:
    """One Image Texture node per material, Closest, linked to Base Color when the PNG exists.
    Returns whether an image is linked."""
    png = os.path.join(directory, "tex", glb + ".png")
    img = None
    if os.path.isfile(png):
        img = bpy.data.images.load(png, check_existing=True)
        img.reload()
        img.filepath = bpy.path.relpath(png)
        img.colorspace_settings.name = "sRGB"
        if tuple(img.size) != (TEX_PX, TEX_PX):
            print("  WARNING %s is %dx%d, expected %dx%d" % (png, img.size[0], img.size[1], TEX_PX, TEX_PX))
    for m in glb_materials(root):
        if m.node_tree is None:
            continue
        nodes = m.node_tree.nodes
        old = nodes.get(SU.PREVIEW_NODE)  # the paused trim-sheet preview
        if old is not None:
            nodes.remove(old)
        bsdf = _principled(m)
        if bsdf is None:
            continue
        tex = nodes.get(TEX_NODE)
        if tex is None:
            tex = nodes.new("ShaderNodeTexImage")
            tex.name = TEX_NODE
            tex.location = (bsdf.location.x - 320, bsdf.location.y)
        tex.label = "tex/%s.png%s" % (glb, "" if img else " (not saved yet)")
        tex.image = img
        tex.interpolation = "Closest"
        tex.extension = "EXTEND"
        socket = bsdf.inputs["Base Color"]
        for link in list(socket.links):
            m.node_tree.links.remove(link)
        if img is not None:
            m.node_tree.links.new(tex.outputs["Color"], socket)
    return img is not None


# --------------------------------------------------------------------------------------
# Export
# --------------------------------------------------------------------------------------

def export_glb(root, directory: str, with_images: bool) -> str:
    homes = {root: root.location.copy()}
    root.location = Vector((0.0, 0.0, 0.0))
    if root.name in PARKED_CHILDREN:
        for child in root.children:
            homes[child] = child.location.copy()
            child.location = Vector((0.0, 0.0, 0.0))
    bpy.context.view_layer.update()
    path = os.path.join(directory, root.name + ".glb")
    SU.select_hierarchy(root)
    try:
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            export_yup=True,
            use_selection=True,
            export_apply=True,
            export_texcoords=True,
            export_image_format="AUTO" if with_images else "NONE",
        )
    finally:
        for obj, home in homes.items():
            obj.location = home
        bpy.context.view_layer.update()
    return path


# --------------------------------------------------------------------------------------
# Driver
# --------------------------------------------------------------------------------------

def _args() -> dict:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

    def value(flag):
        return argv[argv.index(flag) + 1] if flag in argv else None

    return {"map": value("--map"), "glb": value("--glb"), "dry": "--dry" in argv,
            "link": "--link" in argv, "relayout": "--relayout" in argv, "rotate": "--rotate" in argv}


def run_map(name: str, opt: dict) -> bool:
    blend = os.path.join(SCENARIOS, MAPS[name])
    directory = os.path.dirname(blend)
    bpy.ops.wm.open_mainfile(filepath=blend)
    roots = sorted((o for o in bpy.data.objects if o.parent is None and o.type == "EMPTY"),
                   key=lambda o: o.name)
    if opt["glb"]:
        roots = [r for r in roots if r.name == opt["glb"]]
    if not roots:
        return True
    os.makedirs(os.path.join(directory, "tex"), exist_ok=True)
    gdignore = os.path.join(directory, "tex", ".gdignore")
    if not os.path.exists(gdignore):
        open(gdignore, "w").close()
    exports = []
    for root in roots:
        glb = root.name
        made = 0 if opt["link"] else per_glb_materials(root, glb)
        line = ""
        targets = [o for o in glb_meshes(root) if not is_tiling(o) and len(o.data.polygons)]
        done = [o for o in targets if o.get("uv_role") == ROLE]
        if opt["link"]:
            line = "link only"
        elif done and not opt["relayout"]:
            line = "kept %d/%d existing UVs" % (len(done), len(targets))
            if len(done) != len(targets):
                line += " (WARNING %d meshes have no per-GLB UVs: use --relayout)" % (len(targets) - len(done))
        else:
            st = unwrap_glb(root, opt["rotate"])
            line = ("%d meshes, %d islands, %.1f px/m at %d px (pad %d, %.0f%% covered, %d tiling meshes untouched)" % (
                st["meshes"], st["islands"], st["density"], TEX_PX, st["pad"], st["coverage"] * 100.0, st["tiling"]))
            if st["tiny"]:
                names = ", ".join("%s %.1fpx2" % t for t in st["tiny"][:6])
                line += "\n    TINY share (<%d px2): %d meshes: %s%s" % (
                    TINY_PX2, len(st["tiny"]), names, " ..." if len(st["tiny"]) > 6 else "")
        linked = hookup(root, glb, directory)
        print("GLB %s [%s]: %s; %d materials copied; image %s" % (
            glb, name, line, made, "linked" if linked else "none (flat colour)"))
        exports.append((root, linked))
    if opt["dry"]:
        return True
    bpy.ops.wm.save_mainfile()
    for root, linked in exports:
        print("  exported %s" % export_glb(root, directory, linked))
    return True


def main() -> None:
    opt = _args()
    names = [opt["map"]] if opt["map"] else list(MAPS)
    ok = True
    for name in names:
        ok = run_map(name, opt) and ok
    print("PER_GLB_OK" if ok else "PER_GLB_FAILED")
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
