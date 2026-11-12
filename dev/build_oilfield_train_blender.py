"""Build the Oil-field Train finals inside oilfield_train.blend (headless).
Design: docs/design/scenarios/oilfield_train.md (A Palette and Exceptions, B, C, E build lessons, F33, G).

Opens assets/models/scenarios/oilfield_train/oilfield_train.blend itself, creating it (empty) when it is missing.
Each part deletes its own GLB root and everything under it, rebuilds the root as a parentless empty at the origin
named as the GLB, writes that GLB's materials under their per-GLB names (`M_Iron__oil_pumpjack`) with the
Palette's linear values (roughness 0.9, metallic 0, Specular IOR Level 0.5, no emission), and saves the .blend.
Every other root is left untouched. Export with dev/unwrap_per_glb_blender.py afterwards. The script never calls
scenery_uv.process_scene() (G7). Nothing is random: a re-run gives the same mesh (the printed geometry hash).

    --part terrain    `oilfield_terrain` (C step 8, sheet B): `Oilfield_Ground`, env_terrain's box exactly (2,000 m
                      square, top +0.12, 0.5 m thick, 12 triangles) in `M_DirtFar__oilfield_terrain` (scorched
                      earth) on 8 m tiling UVs (`uv_role` `tiling`), zero rotation, origin at the root's; and its
                      proxy `Oilfield_Playable-convcolonly`, the same box. Godot strips `-convcolonly`, so the
                      proxy may not be called `Oilfield_Ground` too (E, the `Engine_Boiler` lesson).
    --part pumpjack   `oil_pumpjack`, the hero (C step 2, sheet B): three objects, 380 triangles at most.
                      `Pumpjack_Iron` (`M_Iron__oil_pumpjack`, 120 at most): the gear house with its sloped lid
                      and top slot, the crank guard on its -Y face, two tie straps across the skids, the bearing
                      saddle, the well's casing, stuffing box, and polished rod.
                      `Pumpjack_Plank` (`M_Plank__oil_pumpjack`, 150 at most): two skids (the -Y one lifted 8 cm
                      at its +X end: the wear), the Samson post's four legs and a cross brace a side, and the
                      ladder (two rails, four rungs) on the post's tail side.
                      `WalkingBeam` (`M_Plank__oil_pumpjack` only, 110 at most): the beam, the horsehead (four
                      flat facets on an arc about the bearing), the tail counterweight, the equalizer, and the two
                      pitmans. Its origin is the bearing, (0, 0, 4.0), its rest pose level, rotation zero, parent
                      the root only (G11). In Godot it rocks about its local z; +12 degrees raises the head.
                      The part prints the nod check (D, asset checks): the pitmans inside the gear house and the
                      lid's slot, the head clear of the rod, and the frame's distance from the pitmans' path.

    --part horizon    `oilfield_horizon`, the far tile: berms, pools, mouths, derricks, tanks, ridges, three anchors.
                      The smoke plumes were removed after the batch 3 review (HZ_PLUMES, off; Roadmap Ideas parks them).
    --part burning_well  `oil_burning_well` (C step 4, sheet B): `Well_Rock` (the 14 m berm ring, breach toward +X, one
                      slumped block), `Well_Dirt` (the spill apron), `Well_Iron` (the blown casing), `Well_Flame` (the
                      8 m pool), `Well_LampGlass` (the white-hot mouth), and the empty `Flame_Near` at the mouth's top
                      centre, (0, 0, 3.0). No plume.

    --part derrick    `oil_derrick` (C step 5, sheet B): `Derrick_Plank` (`M_Plank`: the 20.5 m tapering lattice of four
                      legs, five girt levels and a diagonal per bay per face, leaning 2 degrees away from its engine
                      house with one upper +X brace missing; platform and crown block; the walking beam on its Samson
                      post, the band wheel and pitman, the belt house, the engine house) and `Derrick_Iron` (`M_Iron`:
                      the crown sheave, the engine house's roof sheets, the stack). 600 triangles at most.
    --part tank       `oil_tank` (C step 5, sheet B): a battery of two 12-sided riveted tanks, 10 m by 7 m and 7 m by
                      5.5 m, 3 m apart along Y. `Tank_Sheet` (`M_Sheet`: walls and cone roofs, B's roof slumped 4
                      degrees), `Tank_Iron` (`M_Iron`: the rim angles, B's dented, A's course step, the header pipe),
                      `Tank_Plank` (`M_Plank`: the two-flight stair up A's +X face). 320 triangles at most.

    --part pylon      `oil_pylon` (C step 6, sheet B): `Pylon_Iron` (`M_Iron`, one object, 450 triangles at most): the 22 m
                      riveted-iron "man" tower (four tapering 3-sided legs, girts and a zigzag brace a bay a face, a cage
                      with a 6.0 m and a 4.0 m cross-arm, the lower arm's +X tip bent down 5 degrees), three insulator
                      blocks, and three wires of six straight pieces that sag 3.0 m and end 96 m along -Y on the same
                      tips of the next copy.
    --part pipe_run   `oil_pipe_run` (C step 7, sheet B): `Pipe_Iron` (`M_Iron`: the 16 m hex pipe with 8 cm of sag per
                      span, an elbow into the ground, a flange, three collars) and `Pipe_Plank` (`M_Plank`: four timber
                      A-trestles, the third leaning 6 degrees with the pipe kinked 3 over it).

    --part wellhead   `oil_wellhead` (C step 7, sheet B): `Wellhead_Iron` (`M_Iron`: the 0.40 m 8-sided casing to 1.1 m, a tee
                      stub, a 0.35 m gate valve body, its stem and 8-sided handwheel clear of it, and the 6-sided flow
                      line that runs out and dives into the pad's sloped edge, the leg kinked 4 degrees) and
                      `Wellhead_Dirt` (`M_Dirt`, tiling UVs: an irregular 6-sided pad, top 0.22, sloped sides). 120 at most.
    --part sump       `oil_sump` (C step 7, sheet B): `Sump_Dirt` (`M_Dirt`, tiling UVs: an octagonal ring berm of 7
                      blocks round one breach facing -Y, crest tops 0.60 to 0.72) and `Sump_Glass` (`M_Glass`: the pool at
                      0.35 and the tongue of spill, 0.24 to 0.20, through the breach). 70 at most.

Every part is built per part (F33). Each gets its own build function and its own root; none may touch another part's root.

In each asset's own Blender frame +X faces the train from the left-hand belt (sheet, preamble). Blender (x, y, z) is
Godot (x, z, -y).

Run:
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/build_oilfield_train_blender.py -- --part terrain  (or pumpjack)
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/unwrap_per_glb_blender.py -- --map oilfield_train --relayout
"""
from __future__ import annotations

import hashlib
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, geometry

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scenery_uv  # noqa: E402
from blender_kit import count_tris, flat_shade  # noqa: E402

BLEND = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "models", "scenarios",
                     "oilfield_train", "oilfield_train.blend")
SEP = "__"  # dev/unwrap_per_glb_blender.py: a GLB's own material is `<base>__<glb>`

# Sheet A, Palette: Blender Base Color is linear. Roughness 0.9, metallic 0 (rule 23). The later parts' flats are
# listed so they slot in; M_Flame and M_LampGlass are drawn self-lit by their names (Saloon G7), never by emission.
PALETTE = {
    "ink": (0.006, 0.004, 0.003),  # #120D0A  M_Glass
    "iron": (0.018, 0.020, 0.027),  # #24272E  M_Iron
    "raw_wood": (0.275, 0.262, 0.238),  # #8F8C86  M_Plank
    "sheet_iron": (0.144, 0.133, 0.114),  # #6A665F  M_Sheet
    "scorched": (0.024, 0.014, 0.010),  # #2B2019  M_DirtFar / M_Rock (tiling)
    "oil_soaked": (0.009, 0.006, 0.004),  # #17110D  M_Dirt (tiling)
    "far_iron": (0.018, 0.020, 0.027),  # #24272E  M_RockDark (tiling)
    "burning_oil": (1.000, 0.323, 0.027),  # #FF9A2E  M_Flame (self-lit)
    "white_hot": (1.000, 0.871, 0.578),  # #FFF0C8  M_LampGlass (self-lit)
}
TERRAIN_TOP = 0.12  # the terrain's top: no other piece may have a flat face within 0.08 m of it (A, Exceptions)


# --------------------------------------------------------------------------------------
# Scene: the .blend, roots, materials
# --------------------------------------------------------------------------------------

def open_blend() -> None:
    if os.path.isfile(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.read_homefile(use_empty=True, use_factory_startup=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print(f"created {BLEND}")


def material(base: str, glb: str, rgb) -> bpy.types.Material:
    """The GLB's own copy `<base>__<glb>`, made under that name from the start and recoloured on every run: the
    unwrap reuses a copy by name and never recolours it (E, build lessons)."""
    name = f"{base}{SEP}{glb}"
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    if m.name != name:
        raise RuntimeError(f"material name taken: wanted {name}, got {m.name}")
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
    if "Emission Strength" in bsdf.inputs:
        bsdf.inputs["Emission Strength"].default_value = 0.0
    if "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    m.diffuse_color = (*rgb, 1.0)
    m.roughness = 0.9
    m.metallic = 0.0
    return m


def _collect(root):
    out, stack = [], [root]
    while stack:
        o = stack.pop()
        out.append(o)
        stack.extend(o.children)
    return out


def fresh_root(name: str):
    """Deletes the GLB root `name` and everything under it, with their meshes, and returns a new parentless empty
    named `name` at the origin. No other root is touched."""
    removed = 0
    old = bpy.data.objects.get(name)
    if old is not None:
        if old.parent is not None:
            raise RuntimeError(f"`{name}` exists but is not a root")
        for o in reversed(_collect(old)):
            mesh = o.data if o.type == "MESH" else None
            bpy.data.objects.remove(o, do_unlink=True)
            if mesh is not None and mesh.users == 0:
                bpy.data.meshes.remove(mesh)
            removed += 1
    for me in [m for m in bpy.data.meshes if m.users == 0]:
        bpy.data.meshes.remove(me)
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    root.empty_display_type = "PLAIN_AXES"
    root.location = (0.0, 0.0, 0.0)
    if root.name != name:
        raise RuntimeError(f"root name taken: wanted {name}, got {root.name}")
    print(f"{name}: removed {removed} objects")
    return root


# --------------------------------------------------------------------------------------
# Geometry kernel: closed solids through rings of points, hidden faces dropped
# --------------------------------------------------------------------------------------

def tilt(pivot, axis: str, deg: float) -> Matrix:
    p = Vector(pivot)
    return Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-p)


def rect(x0, x1, y0, y1, z):
    return [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]


def ngon(centre, r, sides, axis: str, at: float, phase: float = 0.0):
    """A regular polygon of circumradius r: in the XY plane at z = at (axis "Z") or in the XZ plane at y = at
    (axis "Y"). centre is (x, y) or (x, z)."""
    pts = []
    for k in range(sides):
        a = math.radians(phase) + 2.0 * math.pi * k / sides
        u, v = centre[0] + r * math.cos(a), centre[1] + r * math.sin(a)
        pts.append((u, v, at) if axis == "Z" else (u, at, v))
    return pts


class Part:
    """One object's faces in one bmesh. Every piece is a closed solid built through rings of points (its normals
    recalculated outward), then its hidden faces are dropped (rule 27; G3)."""

    def __init__(self, name: str):
        self.name = name
        self.bm = bmesh.new()
        self.pieces = []  # (label, faces kept)

    def solid(self, label: str, rings, drop=None, xf=None) -> list:
        bm = self.bm
        rows = []
        for ring in rings:
            row = []
            for p in ring:
                v = Vector(p)
                row.append(bm.verts.new(xf @ v if xf is not None else v))
            rows.append(row)
        faces = [bm.faces.new(rows[0]), bm.faces.new(rows[-1])]
        n = len(rows[0])
        for lo, hi in zip(rows[:-1], rows[1:]):
            for i in range(n):
                j = (i + 1) % n
                faces.append(bm.faces.new((lo[i], lo[j], hi[j], hi[i])))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        for f in faces:
            f.normal_update()
        dead = [f for f in faces if drop is not None and drop(f)]
        if dead:
            bmesh.ops.delete(bm, geom=dead, context="FACES")
        kept = [f for f in faces if f.is_valid]
        self.pieces.append((label, kept))
        return kept

    def box(self, label, x0, x1, y0, y1, z0, z1, drop=None, xf=None):
        return self.solid(label, [rect(x0, x1, y0, y1, z0), rect(x0, x1, y0, y1, z1)], drop, xf)

    def faces(self, label, verts, polys, outward):
        """An open shell from explicit polygons; each face flipped to agree with its outward hint."""
        bm = self.bm
        vs = [bm.verts.new(Vector(p)) for p in verts]
        made = []
        for poly, out in zip(polys, outward):
            f = bm.faces.new([vs[i] for i in poly])
            f.normal_update()
            if f.normal.dot(Vector(out)) < 0.0:
                f.normal_flip()
            made.append(f)
        self.pieces.append((label, made))
        return made


def down(f) -> bool:
    return f.normal.z < -0.99


def up(f) -> bool:
    return f.normal.z > 0.99


def along_x(f) -> bool:
    return abs(f.normal.x) > 0.99


def along_y(f) -> bool:
    return abs(f.normal.y) > 0.99


def finish(part: Part, mat, root, origin=(0.0, 0.0, 0.0)):
    """The part as one object under the root, flat, zero rotation, its origin at `origin` (the vertices are moved
    so the object's location carries it). Names must come out exact: no dots."""
    bm = part.bm
    if Vector(origin).length > 0.0:
        bmesh.ops.translate(bm, verts=bm.verts, vec=-Vector(origin))
    me = bpy.data.meshes.new(part.name)
    bm.to_mesh(me)
    bm.free()
    me.update()
    obj = bpy.data.objects.new(part.name, me)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = root
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.location = origin
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    if mat is not None:
        me.materials.append(mat)
    flat_shade(obj)
    if obj.name != part.name or me.name != part.name:
        raise RuntimeError(f"name taken: wanted {part.name}, got {obj.name} / {me.name}")
    return obj


def geometry_hash(objs) -> str:
    h = hashlib.md5()
    for o in sorted(objs, key=lambda o: o.name):
        h.update(o.name.encode())
        h.update(("%.4f %.4f %.4f;" % tuple(o.location)).encode())
        for v in o.data.vertices:
            h.update(("%.4f %.4f %.4f;" % tuple(v.co)).encode())
        for p in o.data.polygons:
            h.update((",".join(str(i) for i in p.vertices) + ";").encode())
    return h.hexdigest()[:12]


def flat_faces_near_terrain(objs) -> int:
    """Flat faces within 0.08 m of the terrain's top (A, Exceptions: none allowed off the terrain)."""
    bad = 0
    for o in objs:
        mw = o.matrix_world
        for p in o.data.polygons:
            n = (mw.to_3x3() @ p.normal).normalized()
            if abs(n.z) > 0.9999 and abs((mw @ Vector(p.center)).z - TERRAIN_TOP) < 0.08 + 1e-6:
                bad += 1
    return bad


# --------------------------------------------------------------------------------------
# oilfield_terrain (sheet B; C step 8)
# --------------------------------------------------------------------------------------

TERRAIN_SIZE = 2000.0
TERRAIN_THICK = 0.5


def build_terrain() -> list:
    glb = "oilfield_terrain"
    root = fresh_root(glb)
    dirt = material("M_DirtFar", glb, PALETTE["scorched"])
    h = TERRAIN_SIZE / 2.0
    z0, z1 = TERRAIN_TOP - TERRAIN_THICK, TERRAIN_TOP
    ground = Part("Oilfield_Ground")
    ground.box("ground", -h, h, -h, h, z0, z1)
    g = finish(ground, dirt, root)
    scenery_uv.unwrap_object(g, scenery_uv.TILING)
    g["uv_role"] = "tiling"
    # The proxy: the same box, no material, never rendered. Named apart from the visual (E: Godot strips the suffix).
    proxy = Part("Oilfield_Playable-convcolonly")
    proxy.box("proxy", -h, h, -h, h, z0, z1)
    p = finish(proxy, None, root)
    p.hide_render = True
    p.display_type = "WIRE"
    print(f"oilfield_terrain: Oilfield_Ground {count_tris(g)} tris (budget 12), top {z1:.2f}, "
          f"proxy {p.name} {count_tris(p)} tris; geometry {geometry_hash([g, p])}")
    if count_tris(g) > 12:
        raise RuntimeError("oilfield_terrain over its 12 triangles")
    return [g, p]


# --------------------------------------------------------------------------------------
# oil_pumpjack (sheet B, the hero; C step 2)
# --------------------------------------------------------------------------------------

PJ_BUDGET = {"Pumpjack_Iron": 120, "Pumpjack_Plank": 150, "WalkingBeam": 110}
BEARING = Vector((0.0, 0.0, 4.0))  # the Samson post's bearing: WalkingBeam's origin
STROKE = 12.0  # degrees either side of level (F18)

# Skids: two timber sills 0.30 x 0.35 m the length of the 7.0 x 1.4 m base, foot at z 0 (12 cm under the terrain).
SKID_X = 3.5
SKID_Y = 0.55  # centre lines; 0.30 wide, so the base is 1.4 m across
SKID_W, SKID_TOP = 0.30, 0.35
SKID_LIFT = 0.08  # wear: the -Y skid's +X (outboard, well) end lifted 8 cm about its -X foot
STRAP_X = (-3.25, -0.80)  # iron tie straps across both skids, clear of the lifted end
STRAP_W, STRAP_Z0, STRAP_Z1, STRAP_Y = 0.12, 0.33, 0.45, 0.72

# Samson post: four 0.25 m legs from a 2.4 (X) x 1.4 (Y) m foot on the skids up into the bearing saddle.
LEG = 0.25
LEG_FOOT = (1.2, SKID_Y, 0.30)  # centre of the +X +Y leg's foot (sunk 5 cm into its skid)
LEG_HEAD = (0.15, 0.18, 3.45)  # its centre where it enters the saddle's base
LEG_TOP = 3.52  # inside the saddle's solid base, below where front and rear legs would meet (3.525)
BRACE_Z0, BRACE_Z1, BRACE_T = 1.52, 1.70, 0.12  # one cross brace a side (front leg to rear leg)

# Bearing saddle (iron): a U on the legs, cheeks either side of the beam, its floor clear of the beam's corners
# at +-12 degrees (the lowest corner over the saddle comes to 3.718).
SADDLE_X, SADDLE_Y, SADDLE_Z0, SADDLE_Z1 = 0.30, 0.32, 3.45, 4.15
SADDLE_SLOT, SADDLE_FLOOR = 0.19, 3.70

# Ladder on the post's tail side (-X): rails 0.10 m from the ground to under the beam, four rungs.
RAIL = 0.10
RAIL_Y = 0.20
RAIL_FOOT = (-1.32, 0.10)  # (x, z): 3 cm in front of the gear house, 2 cm under the terrain's top
RAIL_HEAD = (-0.53, 3.30)
RUNGS = (0.75, 1.40, 2.05, 2.70)

# Gear house (iron): 1.6 x 1.2 m at X -2.2, 2.2 m tall at its -X end (from 0.30, 5 cm down in the skids, to the lid
# at 2.50; the lid slopes to 2.30 at +X), with an open slot the pitmans pass through. The crank guard: an 8-sided iron disc 1.2 m across, 0.10 m proud (plus 1 cm
# into the wall), on the -Y face, static, its downward face dropped.
GH_X0, GH_X1, GH_Y, GH_Z0 = -3.0, -1.4, 0.6, 0.0
GH_TOP_X0, GH_TOP_X1 = 2.50, 2.30
SLOT_X0, SLOT_X1, SLOT_Y = -2.80, -1.70, 0.45
CRANK_C, CRANK_R, CRANK_Y0, CRANK_Y1 = (-2.2, 1.40), 0.60, -0.59, -0.70

# The well under the head at X +3.6: casing 0.35 m (8-sided) to 1.2 m, stuffing box, polished rod 10 cm to 2.2 m.
WELL_X = 3.6
CASING_R, CASING_TOP = 0.175, 1.20
STUFF_HALF, STUFF_Z0, STUFF_Z1 = 0.11, 1.15, 1.45
ROD_HALF, ROD_Z0, ROD_TOP = 0.05, 1.40, 2.20

# WalkingBeam, in the asset's frame (moved to the bearing at the end). Beam 0.35 x 0.45 m, X -3.0 to the head.
BEAM_X0, BEAM_X1, BEAM_W, BEAM_D = -3.0, 2.95, 0.35, 0.45
HEAD_R = 3.6  # the arc's radius about the bearing: its front at X 3.6, over the rod
HEAD_HALF_ANGLE = math.degrees(math.asin(0.8 / HEAD_R))  # z 3.2 to 4.8 at rest: 1.6 m
HEAD_BACK_X, HEAD_BACK_Z0, HEAD_BACK_Z1, HEAD_W = 2.85, 3.65, 4.35, 0.50
CW = (-3.1, -2.5, 0.30, 3.60, 4.40)  # tail counterweight: x0, x1, half width, z0, z1 (0.6 x 0.6 x 0.8 at X -2.8)
PITMAN_X, PITMAN_Y, PITMAN_HALF, PITMAN_FOOT, PITMAN_TOP = -2.2, 0.32, 0.06, 1.40, 3.70
EQ_HALF_X, EQ_Y, EQ_Z0, EQ_Z1 = 0.075, 0.42, 3.65, 3.80  # the equalizer the pitmans hang from, 2.5 cm into the beam


def lid_z(x: float) -> float:
    return GH_TOP_X0 + (GH_TOP_X1 - GH_TOP_X0) * (x - GH_X0) / (GH_X1 - GH_X0)


def leg_centre(sx: int, sy: int, z: float):
    fx, fy, fz = LEG_FOOT
    hx, hy, hz = LEG_HEAD
    t = (z - fz) / (hz - fz)
    return sx * (fx + (hx - fx) * t), sy * (fy + (hy - fy) * t)


def rail_x(z: float) -> float:
    (x0, z0), (x1, z1) = RAIL_FOOT, RAIL_HEAD
    return x0 + (x1 - x0) * (z - z0) / (z1 - z0)


def build_iron(p: Part) -> None:
    # Gear house: four walls and a lid ring round the slot; no bottom. The walls start at z 0, under the terrain's
    # top (the +-Y walls inside the skids), so no gap shows under the +-X walls between the skids.
    bot = [(GH_X0, -GH_Y, GH_Z0), (GH_X1, -GH_Y, GH_Z0), (GH_X1, GH_Y, GH_Z0), (GH_X0, GH_Y, GH_Z0)]
    top = [(x, y, lid_z(x)) for x, y, _ in bot]
    slot = [(x, y, lid_z(x)) for x, y, _ in rect(SLOT_X0, SLOT_X1, -SLOT_Y, SLOT_Y, 0.0)]
    verts = bot + top + slot  # 0-3 bottom, 4-7 top, 8-11 slot
    polys = [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),  # walls -Y, +X, +Y, -X
             (4, 5, 9, 8), (5, 6, 10, 9), (6, 7, 11, 10), (7, 4, 8, 11)]  # lid ring
    lid_n = Vector((-(GH_TOP_X1 - GH_TOP_X0) / (GH_X1 - GH_X0), 0.0, 1.0)).normalized()
    outward = [(0, -1, 0), (1, 0, 0), (0, 1, 0), (-1, 0, 0)] + [tuple(lid_n)] * 4
    p.faces("gear house", verts, polys, outward)
    # Crank guard: 8 sides, flat edges top and bottom; its inner face (on the wall) and its downward face dropped.
    disc = [ngon(CRANK_C, CRANK_R, 8, "Y", y, phase=22.5) for y in (CRANK_Y0, CRANK_Y1)]
    p.solid("crank guard", disc, drop=lambda f: down(f) or (along_y(f) and f.calc_center_median().y > CRANK_Y0 - 1e-4))
    # Tie straps across both skids: their undersides face the ground.
    for x in STRAP_X:
        p.box("tie strap", x - STRAP_W / 2, x + STRAP_W / 2, -STRAP_Y, STRAP_Y, STRAP_Z0, STRAP_Z1, drop=down)
    # Bearing saddle: a U profile along X; its underside (on the legs) and the cheeks' inner faces (against the
    # beam's sides, 1.5 cm off) dropped. The floor under the beam stays.
    u = [(-SADDLE_Y, SADDLE_Z0), (SADDLE_Y, SADDLE_Z0), (SADDLE_Y, SADDLE_Z1), (SADDLE_SLOT, SADDLE_Z1),
         (SADDLE_SLOT, SADDLE_FLOOR), (-SADDLE_SLOT, SADDLE_FLOOR), (-SADDLE_SLOT, SADDLE_Z1), (-SADDLE_Y, SADDLE_Z1)]
    rings = [[(x, y, z) for y, z in u] for x in (-SADDLE_X, SADDLE_X)]
    p.solid("bearing saddle", rings,
            drop=lambda f: down(f) or (along_y(f) and abs(f.calc_center_median().y) < SADDLE_SLOT + 1e-4))
    # The well: casing (bottom in the ground), stuffing box, polished rod.
    p.solid("casing", [ngon((WELL_X, 0.0), CASING_R, 8, "Z", z, phase=22.5) for z in (0.0, CASING_TOP)], drop=down)
    p.box("stuffing box", WELL_X - STUFF_HALF, WELL_X + STUFF_HALF, -STUFF_HALF, STUFF_HALF, STUFF_Z0, STUFF_Z1,
          drop=down)
    p.box("polished rod", WELL_X - ROD_HALF, WELL_X + ROD_HALF, -ROD_HALF, ROD_HALF, ROD_Z0, ROD_TOP, drop=down)


def build_plank(p: Part) -> None:
    # Skids, undersides dropped. The -Y skid's +X end is lifted 8 cm about its -X foot (wear, detail 8).
    lift = -math.degrees(math.asin(SKID_LIFT / (2.0 * SKID_X)))  # about +Y, negative raises +X
    for sy in (-1, 1):
        xf = tilt((-SKID_X, sy * SKID_Y, 0.0), "Y", lift) if sy < 0 else None
        p.box("skid", -SKID_X, SKID_X, sy * SKID_Y - SKID_W / 2, sy * SKID_Y + SKID_W / 2, 0.0, SKID_TOP,
              drop=down, xf=xf)
    # Samson post: four legs with horizontal square sections, foot in a skid, head in the saddle's base.
    h = LEG / 2.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            rings = []
            for z in (LEG_FOOT[2], LEG_TOP):
                cx, cy = leg_centre(sx, sy, z)
                rings.append(rect(cx - h, cx + h, cy - h, cy + h, z))
            p.solid("leg", rings, drop=lambda f: abs(f.normal.z) > 0.99)
    # One cross brace a side, front leg to rear leg; its ends are inside the legs.
    zc = (BRACE_Z0 + BRACE_Z1) / 2.0
    for sy in (-1, 1):
        cx, cy = leg_centre(1, sy, zc)
        p.box("cross brace", -cx, cx, cy - BRACE_T / 2, cy + BRACE_T / 2, BRACE_Z0, BRACE_Z1, drop=along_x)
    # Ladder: two rails (foot under the terrain's top, dropped) and four rungs whose ends sit inside the rails.
    r = RAIL / 2.0
    for sy in (-1, 1):
        rings = [rect(rail_x(z) - r, rail_x(z) + r, sy * RAIL_Y - r, sy * RAIL_Y + r, z)
                 for z in (RAIL_FOOT[1], RAIL_HEAD[1])]
        p.solid("ladder rail", rings, drop=down)
    for z in RUNGS:
        x = rail_x(z)
        p.box("ladder rung", x - r, x + r, -RAIL_Y, RAIL_Y, z - r, z + r, drop=along_y)


def build_beam(p: Part) -> None:
    """In the asset's frame; finish() moves it to the bearing."""
    hw, z0, z1 = BEAM_W / 2.0, BEARING.z - BEAM_D / 2.0, BEARING.z + BEAM_D / 2.0
    p.box("beam", BEAM_X0, BEAM_X1, -hw, hw, z0, z1, drop=along_x)  # both ends inside the counterweight and head
    # Horsehead: a flat back, four flat facets on an arc of radius 3.6 about the bearing (z 3.2 to 4.8 at rest).
    arc = []
    for k in range(5):
        a = math.radians(-HEAD_HALF_ANGLE + k * HEAD_HALF_ANGLE / 2.0)
        arc.append((BEARING.x + HEAD_R * math.cos(a), BEARING.z + HEAD_R * math.sin(a)))
    prof = [(HEAD_BACK_X, HEAD_BACK_Z0)] + arc + [(HEAD_BACK_X, HEAD_BACK_Z1)]
    p.solid("horsehead", [[(x, y, z) for x, z in prof] for y in (-HEAD_W / 2, HEAD_W / 2)])
    x0, x1, cw, cz0, cz1 = CW
    p.box("counterweight", x0, x1, -cw, cw, cz0, cz1)
    p.box("equalizer", PITMAN_X - EQ_HALF_X, PITMAN_X + EQ_HALF_X, -EQ_Y, EQ_Y, EQ_Z0, EQ_Z1)
    for sy in (-1, 1):
        y = sy * PITMAN_Y
        p.box("pitman", PITMAN_X - PITMAN_HALF, PITMAN_X + PITMAN_HALF, y - PITMAN_HALF, y + PITMAN_HALF,
              PITMAN_FOOT, PITMAN_TOP, drop=up)


def nod(deg: float) -> Matrix:
    """WalkingBeam's world matrix at `deg`: +deg raises the head (+X). In Godot that is +deg about local z."""
    return Matrix.Translation(BEARING) @ Matrix.Rotation(math.radians(-deg), 4, "Y")


def _tris(obj, mw=None):
    me = obj.data
    me.calc_loop_triangles()
    mw = obj.matrix_world if mw is None else mw
    out = []
    for t in me.loop_triangles:
        out.append(tuple(mw @ me.vertices[i].co for i in t.vertices))
    return out


def check_pumpjack(iron, plank, beam) -> None:
    """The asset check (sheet D) on the built objects. Raises on a failure."""
    me = beam.data
    local = [v.co.copy() for v in me.vertices]
    foot_local = [v for v in local if v.z < PITMAN_FOOT - BEARING.z + 1e-4]
    worst_wall, worst_slot, worst_floor = 9.0, 9.0, 9.0
    for deg in range(-int(STROKE), int(STROKE) + 1):
        mw = nod(deg)
        for v in local:
            w = mw @ v
            if w.z < lid_z(min(max(w.x, GH_X0), GH_X1)) and GH_X0 - 0.5 < w.x < GH_X1 + 0.5:
                # Below the lid: inside the gear house's walls.
                worst_wall = min(worst_wall, w.x - GH_X0, GH_X1 - w.x, GH_Y - abs(w.y))
                worst_floor = min(worst_floor, w.z - GH_Z0)
        # Where each pitman edge crosses the lid's plane, it must be inside the slot.
        for e in me.edges:
            a, b = mw @ me.vertices[e.vertices[0]].co, mw @ me.vertices[e.vertices[1]].co
            da, db = a.z - lid_z(a.x), b.z - lid_z(b.x)
            if da * db < 0.0:
                c = a + (b - a) * (da / (da - db))
                if GH_X0 <= c.x <= GH_X1 and abs(c.y) <= GH_Y:
                    worst_slot = min(worst_slot, c.x - SLOT_X0, SLOT_X1 - c.x, SLOT_Y - abs(c.y))
    feet = {d: [nod(d) @ v for v in foot_local] for d in (-STROKE, 0.0, STROKE)}
    print("  nod: pitman feet (centre) at -12/0/+12: " + ", ".join(
        "(%.3f, %.3f)" % (sum(v.x for v in vs) / len(vs), sum(v.z for v in vs) / len(vs)) for vs in feet.values()))
    print(f"  nod: below the lid, the beam's lowest margin to the gear house's walls {worst_wall:.3f} m, "
          f"to its foot {worst_floor:.3f} m; at the lid, margin inside the slot {worst_slot:.3f} m")
    if worst_wall <= 0.0 or worst_slot <= 0.0 or worst_floor <= 0.0:
        raise RuntimeError("a pitman leaves the gear house or misses the slot")
    # The head against the rod, over the whole stroke.
    rod_top = Vector((WELL_X, 0.0, ROD_TOP))
    clear_rod, hi_head = 9.0, -9.0
    head_lo = None
    for deg in range(-int(STROKE), int(STROKE) + 1):
        for a, b, c in _tris(beam, nod(deg)):
            q = geometry.closest_point_on_tri(rod_top, a, b, c)
            clear_rod = min(clear_rod, (q - rod_top).length)
        ws = [nod(deg) @ v for v in local]
        hi_head = max(hi_head, max(w.z for w in ws))
        if deg == -int(STROKE):
            head_lo = min((w for w in ws if w.x > 2.0), key=lambda w: w.z)
    front = {d: nod(d) @ (Vector((HEAD_R, 0.0, 0.0))) for d in (-STROKE, 0.0, STROKE)}
    print(f"  nod: head front (arc middle) z at -12/0/+12: " + ", ".join("%.3f" % v.z for v in front.values())
          + f"; highest point over the stroke {hi_head:.3f}; head's lowest at -12: ({head_lo.x:.3f}, {head_lo.z:.3f})")
    print(f"  nod: rod top (3.6, 2.2) to the beam, closest over the stroke {clear_rod:.3f} m")
    if clear_rod <= 0.1:
        raise RuntimeError("the head does not clear the rod")
    # The frame against the pitmans' path, outside the gear house (the house's own walls and crank guard excluded).
    frame = [t for t in _tris(plank)] + [t for t in _tris(iron)
                                         if not all(GH_X0 - 1e-3 <= v.x <= GH_X1 + 1e-3 and abs(v.y) <= 0.71 for v in t)]
    path_min, at = 9.0, None
    for deg in range(-int(STROKE), int(STROKE) + 1, 2):
        mw = nod(deg)
        for sy in (-1, 1):
            for k in range(25):
                z = PITMAN_FOOT + (EQ_Z0 - PITMAN_FOOT) * k / 24.0
                pt = mw @ (Vector((PITMAN_X, sy * PITMAN_Y, z)) - BEARING)
                for a, b, c in frame:
                    d = (geometry.closest_point_on_tri(pt, a, b, c) - pt).length
                    if d < path_min:
                        path_min, at = d, (deg, round(pt.z, 2))
    print(f"  nod: pitman centre line to the nearest frame surface outside the gear house {path_min:.3f} m "
          f"(at {at[0]} deg, z {at[1]}); minus the pitman's half width {path_min - PITMAN_HALF * math.sqrt(2):.3f} m")
    # Above the lid, the pitmans and equalizer against the frame.
    above = 9.0
    for deg in range(-int(STROKE), int(STROKE) + 1, 2):
        mw = nod(deg)
        for sy in (-1, 1):
            for k in range(13):
                z = 2.5 + (EQ_Z0 - 2.5) * k / 12.0
                pt = mw @ (Vector((PITMAN_X, sy * PITMAN_Y, z)) - BEARING)
                if pt.z < lid_z(pt.x):
                    continue
                for a, b, c in frame:
                    above = min(above, (geometry.closest_point_on_tri(pt, a, b, c) - pt).length)
    print(f"  nod: above the lid, pitman centre line to the nearest frame surface {above:.3f} m")


def build_pumpjack() -> list:
    glb = "oil_pumpjack"
    root = fresh_root(glb)
    m_iron = material("M_Iron", glb, PALETTE["iron"])
    m_plank = material("M_Plank", glb, PALETTE["raw_wood"])
    iron, plank, beam = Part("Pumpjack_Iron"), Part("Pumpjack_Plank"), Part("WalkingBeam")
    build_iron(iron)
    build_plank(plank)
    build_beam(beam)
    lines = {}
    for part in (iron, plank, beam):
        lines[part.name] = {}
        for label, faces in part.pieces:
            n = sum(len(f.verts) - 2 for f in faces if f.is_valid)
            lines[part.name][label] = lines[part.name].get(label, 0) + n
    o_iron = finish(iron, m_iron, root)
    o_plank = finish(plank, m_plank, root)
    o_beam = finish(beam, m_plank, root, origin=tuple(BEARING))
    objs = [o_iron, o_plank, o_beam]
    total = 0
    for o in objs:
        n = count_tris(o)
        total += n
        print(f"  {o.name}: {n} / {PJ_BUDGET[o.name]} tris, {len(o.data.polygons)} faces, "
              f"{sum(1 for p in o.data.polygons if len(p.vertices) > 4)} n-gons; "
              + ", ".join(f"{k} {v}" for k, v in lines[o.name].items()))
        if n > PJ_BUDGET[o.name]:
            raise RuntimeError(f"{o.name} over budget")
        if "." in o.name or o.parent != root:
            raise RuntimeError(f"{o.name}: bad name or parent")
    print(f"oil_pumpjack: {total} / 380 tris in {len(objs)} objects; geometry {geometry_hash(objs)}")
    if (o_beam.location - BEARING).length > 1e-6 or any(abs(a) > 1e-9 for a in o_beam.rotation_euler) \
            or o_beam.parent != root or root.parent is not None or len(o_beam.data.materials) != 1:
        raise RuntimeError("WalkingBeam contract broken")
    print(f"  WalkingBeam: origin {tuple(round(c, 4) for c in o_beam.location)}, rotation "
          f"{tuple(o_beam.rotation_euler)}, parent {o_beam.parent.name}, material {o_beam.data.materials[0].name}")
    near = flat_faces_near_terrain(objs)
    print(f"  flat faces within 0.08 m of the terrain's top: {near}")
    if near:
        raise RuntimeError("a flat face lies near the terrain's top")
    check_pumpjack(o_iron, o_plank, o_beam)
    return objs


# --------------------------------------------------------------------------------------
# oilfield_horizon (sheet B; C step 3): the far tile with its flame anchors and plumes
# --------------------------------------------------------------------------------------

HZ_SPAN = 48.0  # scenery_belt.gd's slot pitch
HZ_HALF_Y = (HZ_SPAN - 0.25) / 2.0  # 23.875: 47.75 m, 0.125 m clear of each neighbour slot
HZ_HALF_X = 30.0
TAN35 = math.tan(math.radians(35.0))
HZ_BUDGET = 460


class Loose:
    """One object's faces in one bmesh, welded by position. Every face is oriented outward by a reference point
    inside its solid (the whole tile is built without overlapping volumes, so no boolean is needed). Bottoms at z 0
    are left open: they lie 0.12 m under the terrain's top (rule 27)."""

    def __init__(self, name: str):
        self.name = name
        self.bm = bmesh.new()
        self.pieces = {}  # label -> triangles
        self._v = {}

    def _vert(self, p):
        key = tuple(round(c, 5) for c in p)
        v = self._v.get(key)
        if v is None:
            v = self.bm.verts.new(Vector(key))
            self._v[key] = v
        return v

    def poly(self, label, pts, ref):
        """A planar polygon, flipped so its normal points away from `ref` (a point inside the solid)."""
        f = self.bm.faces.new([self._vert(p) for p in pts])
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(c - Vector(ref)) < 0.0:
            f.normal_flip()
        self.pieces[label] = self.pieces.get(label, 0) + len(pts) - 2
        return f

    def tube(self, label, ring_a, ring_b, ref, cap_a=False, cap_b=False):
        """Side quads between two rings of equal length (parallel translations of one another: planar quads),
        with either end closed when asked. `ref` is a point inside the solid."""
        n = len(ring_a)
        for i in range(n):
            j = (i + 1) % n
            self.poly(label, (ring_a[i], ring_a[j], ring_b[j], ring_b[i]), ref)
        if cap_a:
            self.poly(label, ring_a, ref)
        if cap_b:
            self.poly(label, ring_b, ref)

    def tris(self):
        return sum(self.pieces.values())


def _ngon_pts(cx, cy, apothem, n, norm0, z, shift=None):
    """The n vertices of a regular polygon of the given apothem whose edge normals sit at norm0 + k * 360 / n."""
    r = apothem / math.cos(math.pi / n)
    out = []
    for j in range(n):
        a = math.radians(norm0 + (j + 0.5) * 360.0 / n)
        out.append((cx + r * math.cos(a), cy + r * math.sin(a), z))
    return out


def berm(m: Loose, label, cx, cy, n, norm0, breach_deg, a_in, a_crest, a_toe, h, slump=None, floor=0.0):
    """The mound's ring: a polygon swept with a trapezoid profile (inner wall, crest, 35 degree outer slope), one
    edge of the ring left out (the breach). Edge k has its normal at norm0 + k * 360 / n; vertex j lies between
    edge j and edge j + 1. The swept faces are planar trapezoids, so no wedge needs a boolean. `slump` maps an
    edge to a lower crest height: that block keeps the toe and the 35 degree slope, so its crest is wider, and the
    taller neighbour's end face closes the step (the burning well's wear). `floor` is the inner wall's bottom
    height: a pool at that height meets it exactly (the sump), 0 for the mounds and the well."""
    slump = slump or {}
    kb = round(((breach_deg - norm0) % 360.0) / (360.0 / n)) % n
    ring = {}

    def at(a, vi, z):
        if a not in ring:
            ring[a] = _ngon_pts(cx, cy, a, n, norm0, 0.0)
        x, y, _ = ring[a][vi % n]
        return (x, y, z)

    def prof(k):  # (crest apothem, height) of edge k
        if k in slump:
            return a_toe - slump[k] / TAN35, slump[k]
        return a_crest, h

    def refpt(k):  # inside the segment's trapezoid at the middle of edge k
        ac, hk = prof(k)
        phi = math.radians(norm0 + k * 360.0 / n)
        a_mid = (a_in + a_toe + ac) / 3.0 + 0.5
        return (cx + a_mid * math.cos(phi), cy + a_mid * math.sin(phi), hk * 0.4)

    def cap(vi, k):  # edge k's profile as a face standing on vertex vi
        ac, hk = prof(k)
        m.poly(label, (at(a_in, vi, 0.0), at(a_toe, vi, 0.0), at(ac, vi, hk), at(a_in, vi, hk)), refpt(k))

    edges = [(kb + 1 + i) % n for i in range(n - 1)]
    for k in edges:
        v0, v1 = k - 1, k  # the segment's two vertices
        ref = refpt(k)
        ac, hk = prof(k)
        for (pa, pz), (qa, qz) in (((a_toe, 0.0), (ac, hk)), ((ac, hk), (a_in, hk)), ((a_in, hk), (a_in, floor))):
            m.poly(label, (at(pa, v0, pz), at(pa, v1, pz), at(qa, v1, qz), at(qa, v0, qz)), ref)
    # End caps at the breach: vertex kb (after the breach edge) and vertex kb - 1 (before it).
    cap(kb, edges[0])
    cap(kb - 1, edges[-1])
    # Where a slumped block meets a taller one, the taller block's end face is the step.
    for a, b in zip(edges[:-1], edges[1:]):
        if prof(a)[1] != prof(b)[1]:
            cap(a, a if prof(a)[1] > prof(b)[1] else b)
    return kb


def frustum(m: Loose, label, rect0, rect1, z1):
    """A hipped ridge: the rectangle rect0 = (x0, x1, y0, y1) at z 0 rising to rect1 at z1; five faces, no bottom."""
    def ring(r, z):
        return [(r[0], r[2], z), (r[1], r[2], z), (r[1], r[3], z), (r[0], r[3], z)]
    ref = ((rect0[0] + rect0[1]) / 2.0, (rect0[2] + rect0[3]) / 2.0, z1 / 2.0)
    m.tube(label, ring(rect0, 0.0), ring(rect1, z1), ref, cap_b=True)


def mound_rows():
    """(name, centre, polygon sides, edge-normal start, breach direction, inner wall, crest outer, toe, berm height,
    pool apothem, pool height, mouth across, mouth sides, mouth height above the pool), sheet B's Contents. The mouths
    stand 2.6, 2.1, and 1.6 m taller than B's 1.8, 1.1, and 0.8 so each clears its berm's crest from the roof (H)."""
    return [
        # Mound A: a 20 m berm (mid-height), 13 m pool, 2.4 m mouth. The toe stays inside X -30.
        ("Flame_1", (-18.0, -8.0), 8, 0.0, 270.0, 6.0, 7.0, 12.0, 3.5, 6.5, 0.6, 2.4, 4, 4.4),
        ("Flame_2", (12.0, 10.0), 6, 0.0, 240.0, 3.25, 4.25, 4.25 + 2.2 / TAN35, 2.2, 3.5, 0.5, 1.2, 4, 2.7),
        ("Flame_3", (-2.0, -17.0), 6, 0.0, 300.0, 2.25, 3.0, 3.0 + 1.5 / TAN35, 1.5, 2.5, 0.4, 0.8, 4, 1.8),
    ]


# Plumes (F12, fix pass): smoke heads. Three or four stacked square frusta ("lumps"), each offset from the one
# below and wider at its top, so the stack widens into a mushroom head. The plume starts just under its column's
# ragged top (about 85% of the column) and leans toward -X with each lump. A lump is (z0, z1, top across, dx, dy,
# rotation in degrees); the first also gives its bottom across. A later lump's bottom is sized to sit inside the
# lump under it (no bottom face: the underside is the lower lump's top ring, which is open), so only the first lump
# has a bottom cap: 10 triangles for it, 8 for each other. Tops are not built (above 6.5 m, rule 27).
PLUMES = {
    "Flame_1": (10.0, [(52.0, 68.0, 13.0, 0.0, 0.0, 8.0), (64.0, 82.0, 17.0, -1.0, 1.5, -10.0),
                       (78.0, 98.0, 20.0, -1.0, -1.5, 0.0), (94.0, 112.0, 21.0, -0.5, 1.0, 5.0)]),
    "Flame_2": (6.0, [(30.0, 44.0, 8.0, 0.0, 0.0, 10.0), (40.0, 58.0, 11.0, -3.0, 1.2, -8.0),
                      (54.0, 72.0, 15.0, -7.0, -1.2, 6.0), (68.0, 86.0, 19.0, -11.0, 0.8, -4.0)]),
    "Flame_3": (3.5, [(12.5, 22.0, 5.0, 0.0, 0.0, 10.0), (19.0, 32.0, 7.5, -3.0, 1.0, -8.0),
                      (28.0, 44.0, 10.0, -6.0, -0.5, 5.0)]),
}


def _square(cx, cy, across, z, rot_deg):
    h = across / 2.0
    c, s = math.cos(math.radians(rot_deg)), math.sin(math.radians(rot_deg))
    return [(cx + c * x - s * y, cy + s * x + c * y, z) for x, y in ((-h, -h), (h, -h), (h, h), (-h, h))]


def plume(m: Loose, label, cx, cy, spec):
    """Stacks the lumps of `spec` = (first bottom across, [lump, ...]) over the mound at (cx, cy)."""
    a0, lumps = spec
    prev = None
    for k, (z0, z1, a1, dx, dy, rot) in enumerate(lumps):
        if prev is not None:
            pz0, pz1, pa0, pa1, pdx, pdy, prot = prev
            width = pa0 + (pa1 - pa0) * (z0 - pz0) / (pz1 - pz0)
            turn = math.radians(rot - prot)
            a0 = width / (math.cos(turn) + abs(math.sin(turn))) - 2.0 * max(abs(dx - pdx), abs(dy - pdy)) - 0.3
        lo = _square(cx + dx, cy + dy, a0, z0, rot)
        hi = _square(cx + dx, cy + dy, a1, z1, rot)
        m.tube(label, lo, hi, (cx + dx, cy + dy, (z0 + z1) / 2.0), cap_a=(k == 0))
        prev = (z0, z1, a0, a1, dx, dy, rot)
    return prev


def leg(m: Loose, label, base, top, z0, z1, r, outward_deg, sides=3):
    """A tapered, leaning leg: a prism of `sides` corners and circumradius r from `base` (x, y at z0) to `top` (at
    z1), the cross-section pointing outward at outward_deg. Sides only (open ends: the bottom is in the ground,
    the top is inside the crown or above every eye)."""
    def ring(c, z):
        return [(c[0] + r * math.cos(math.radians(outward_deg + 360.0 * k / sides)),
                 c[1] + r * math.sin(math.radians(outward_deg + 360.0 * k / sides)), z) for k in range(sides)]
    ref = ((base[0] + top[0]) / 2.0, (base[1] + top[1]) / 2.0, (z0 + z1) / 2.0)
    m.tube(label, ring(base, z0), ring(top, z1), ref)


def derrick(m: Loose, label, cx, cy, height, base_half, top_half, legs, lean=(0.0, 0.0), girts=(), crown=None,
            leg_r=0.35):
    """A derrick silhouette: tapered legs (4 at the corners of a square, or 3 on a triangle), open girt bands that
    wrap the legs, and an optional crown block (half width, height) the legs end under. `height` is the legs'
    height; `lean` is metres of plan shift per metre of height (x, y). Returns the legs' top centres."""
    if legs == 4:
        spots = [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)]
    else:
        spots = [(math.cos(math.radians(90.0 + 120.0 * k)), math.sin(math.radians(90.0 + 120.0 * k)))
                 for k in range(3)]
    tops = []
    for sx, sy in spots:
        b = (cx + sx * base_half, cy + sy * base_half)
        t = (cx + sx * top_half + lean[0] * height, cy + sy * top_half + lean[1] * height)
        leg(m, label, b, t, 0.0, height, leg_r, math.degrees(math.atan2(sy, sx)))
        tops.append(t)
    for gz in girts:
        hw = base_half + (top_half - base_half) * gz / height + leg_r + 0.05
        if legs == 3:
            hw += 0.2
        sh = (lean[0] * gz, lean[1] * gz)
        ring = lambda z: [(cx + sh[0] + sx * hw, cy + sh[1] + sy * hw, z) for sx, sy in spots]
        m.tube(label, ring(gz - 0.25), ring(gz + 0.25), (cx + sh[0], cy + sh[1], gz))
    if crown is not None:
        half, ch = crown
        sh = (lean[0] * height, lean[1] * height)
        k = 1.0 if legs == 4 else 1.2
        sq = lambda z: [(cx + sh[0] + sx * half * k, cy + sh[1] + sy * half * k, z) for sx, sy in spots]
        m.tube(label, sq(height), sq(height + ch), (cx + sh[0], cy + sh[1], height + ch / 2.0), cap_a=True)
    return tops


def tank(m: Loose, label, cx, cy, apothem, height, roof=None, zig=None):
    """An 8-sided tank: side quads (planar), a cone roof, or a zigzag top edge when gutted (alternate corners
    `zig` lower). Bottom open at z 0."""
    ring0 = _ngon_pts(cx, cy, apothem, 8, 0.0, 0.0)
    zs = [height + (zig if j % 2 else -zig) if zig else height for j in range(8)] if zig else [height] * 8
    ring1 = [(p[0], p[1], zs[j]) for j, p in enumerate(ring0)]
    ref = (cx, cy, height / 2.0)
    m.tube(label, ring0, ring1, ref)
    if roof is not None:
        apex = (cx, cy, height + roof)
        for j in range(8):
            m.poly(label, (ring1[j], ring1[(j + 1) % 8], apex), (cx, cy, height))


# The plumes were removed after the batch 3 review (sheet H, "Plumes removed"); Roadmap Ideas parks them. With
# HZ_PLUMES on, `Plume_1` to `Plume_3` come back as separate objects named as their anchors, in the world shader's
# M_Smoke (unlit at its own colour, fogged on a distance ramp: docs/SHADERS.md section 8).
HZ_PLUMES = False
HZ_PARTS = ("Horizon_Rock", "Horizon_RockDark", "Horizon_Flame", "Horizon_LampGlass")     + (("Plume_1", "Plume_2", "Plume_3") if HZ_PLUMES else ())


def _hz_geometry():
    """Fills the four Loose objects and returns (objects by name, anchor positions)."""
    rock, dark = Loose("Horizon_Rock"), Loose("Horizon_RockDark")
    flame, lamp = Loose("Horizon_Flame"), Loose("Horizon_LampGlass")
    plumes = {f"Plume_{k}": Loose(f"Plume_{k}") for k in (1, 2, 3)} if HZ_PLUMES else {}
    anchors = {}
    # Mounds: berm ring with a breach, burning pool (with the breach's glowing lip), wrecked casing, its white-hot top.
    for name, (cx, cy), n, norm0, breach, a_in, a_cr, a_toe, h, pa, ph, across, msides, mh in mound_rows():
        kb = berm(rock, f"berm {name}", cx, cy, n, norm0, breach, a_in, a_cr, a_toe, h)
        pool = _ngon_pts(cx, cy, pa, n, norm0, ph)
        flame.poly(f"pool {name}", pool, (cx, cy, ph - 1.0))
        lip = (pool[(kb - 1) % n], pool[kb % n])  # the breach edge's two pool corners
        flame.poly(f"pool lip {name}", (lip[0], lip[1], (lip[1][0], lip[1][1], 0.0), (lip[0][0], lip[0][1], 0.0)),
                   (cx, cy, ph / 2.0))
        r = across / 2.0 if msides == 6 else across / math.sqrt(2.0)
        ph0 = 0.0 if msides == 6 else 45.0
        c0 = [(cx + r * math.cos(math.radians(ph0 + 360.0 * k / msides)),
               cy + r * math.sin(math.radians(ph0 + 360.0 * k / msides)), ph) for k in range(msides)]
        c1 = [(p[0], p[1], ph + mh) for p in c0]
        lamp.tube(f"casing {name}", c0, c1, (cx, cy, ph + mh / 2.0), cap_b=True)
        anchors[name] = (cx, cy, ph + mh)
        if HZ_PLUMES:
            plume(plumes["Plume_" + name[-1]], f"plume {name}", cx, cy, PLUMES[name])
    # Ridges (the Canyon's hipped wedges at the 0.5 m floor): crest 1.5 m wide, 35 degree slopes all round.
    for label, x, y0, y1, h in (("ridge 1", 0.5, 4.5, 18.5, 1.5), ("ridge 2", 11.0, -20.0, -9.0, 2.5)):
        w = h / TAN35
        frustum(rock, label, (x - 0.75 - w, x + 0.75 + w, y0 - w, y1 + w), (x - 0.75, x + 0.75, y0, y1), h)
    # Derricks and tanks (far iron).
    derrick(dark, "derrick standing", 20.0, -14.0, 20.5, 2.5, 0.6, 4, girts=(7.0, 14.0), crown=(1.2, 1.5))
    derrick(dark, "derrick burnt", -25.0, 16.0, 18.0, 2.3, 0.6, 3, lean=(0.0, math.tan(math.radians(12.0))))
    derrick(dark, "derrick small", 26.0, 4.0, 13.0, 1.8, 0.5, 3, crown=(0.9, 1.0))
    # Folded: the lower 9 m stands, the upper 9 m is two legs kinked 60 degrees over toward -Y.
    derrick(dark, "derrick folded", 5.0, -2.0, 9.0, 2.2, 1.2, 4, girts=(4.5,))
    reach, rise = 9.0 * math.sin(math.radians(60.0)), 9.0 * math.cos(math.radians(60.0))
    for sx in (-1.0, 1.0):
        base, top = (5.0 + sx * 1.0, -2.0), (5.0 + sx * 0.5, -2.0 - reach)
        leg(dark, "derrick folded top", base, top, 9.0, 9.0 + rise, 0.35, 90.0 + sx * 90.0 + 90.0)
    tank(dark, "tank", -8.0, 8.0, 4.5, 6.0, roof=1.5)
    tank(dark, "tank gutted", 22.0, 18.0, 3.5, 5.0, zig=0.6)
    return {m.name: m for m in (rock, dark, flame, lamp, *plumes.values())}, anchors


def _tri_overlap_2d(a, b) -> bool:
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
    """Triangle pairs (any objects) lying in one plane and sharing area."""
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
            if _tri_overlap_2d([(u.dot(p), w.dot(p)) for p in vi], [(u.dot(p), w.dot(p)) for p in vj]):
                overlaps += 1
                print(f"    COPLANAR OVERLAP {oi}[{fi}] / {oj}[{fj}] at ({sum(p.x for p in vi) / 3:.2f}, {sum(p.y for p in vi) / 3:.2f}, {sum(p.z for p in vi) / 3:.2f}), normal ({ni.x:.2f}, {ni.y:.2f}, {ni.z:.2f})")
    return len(tris), pairs, overlaps


def check_horizon(objs, anchors) -> None:
    """Sheet D's asset checks on the built objects. Raises on a failure."""
    total = 0
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    zero = smooth = nonplanar = collinear = 0
    for o in objs:
        n = count_tris(o)
        total += n
        print(f"  {o.name}: {n} tris, {len(o.data.polygons)} faces, material {o.data.materials[0].name}")
        me = o.data
        for t in me.loop_triangles:
            if t.area < 1e-6:
                zero += 1
        for p in me.polygons:
            smooth += int(p.use_smooth)
            co = [me.vertices[i].co for i in p.vertices]
            d = p.normal.dot(co[0])
            if max(abs(p.normal.dot(c) - d) for c in co) > 1e-4:
                nonplanar += 1
            for i in range(len(co)):
                a, b, c = co[i - 1], co[i], co[(i + 1) % len(co)]
                if (b - a).cross(c - b).length < 1e-6 * max(1.0, (c - a).length):
                    collinear += 1
        for v in me.vertices:
            for k in range(3):
                lo[k] = min(lo[k], v.co[k])
                hi[k] = max(hi[k], v.co[k])
    print(f"oilfield_horizon: {total} / {HZ_BUDGET} tris in {len(objs)} objects; geometry {geometry_hash(objs)}")
    print("  extents x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f (tile box x +-%.0f, y +-%.3f)" % (
        lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, HZ_HALF_X, HZ_HALF_Y))
    print(f"  zero-area triangles {zero}, non-planar faces {nonplanar}, smooth faces {smooth}, "
          f"collinear outline points {collinear}")
    near = flat_faces_near_terrain(objs)
    print(f"  flat faces within 0.08 m of the terrain's top: {near}")
    ntri, pairs, overlaps = coplanar_overlaps(objs)
    print(f"  coplanar test: {ntri} triangles, {pairs} coplanar pairs, {overlaps} sharing area")
    # Open edges: only the ground (z 0), the legs' open ends, the plumes' tops, and the berms' inner crest edges stay open.
    opens = {}
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        for e in bm.edges:
            if len(e.link_faces) == 1:
                z = max(v.co.z for v in e.verts)
                key = "ground" if z < 1e-4 else ("above 6.5 m" if min(v.co.z for v in e.verts) > 6.5 else "low")
                opens[(o.name, key)] = opens.get((o.name, key), 0) + 1
        bm.free()
    print("  open edges: " + ", ".join(f"{k[0]} {k[1]} {v}" for k, v in sorted(opens.items())))
    bad = []
    if total > HZ_BUDGET:
        bad.append("over budget")
    if lo.x < -HZ_HALF_X - 1e-4 or hi.x > HZ_HALF_X + 1e-4 or lo.y < -HZ_HALF_Y - 1e-4 or hi.y > HZ_HALF_Y + 1e-4             or lo.z < -1e-4:
        bad.append("outside the tile's box")
    if zero or nonplanar or smooth or near or overlaps:
        bad.append("mesh")
    if any("." in o.name or o.parent is None or o.parent.name != "oilfield_horizon" for o in objs):
        bad.append("names or parents")
    for o in objs:
        if tuple(o.location) != (0.0, 0.0, 0.0) or tuple(o.rotation_euler) != (0.0, 0.0, 0.0)                 or tuple(o.scale) != (1.0, 1.0, 1.0):
            bad.append(f"{o.name} not at the origin")
    for o in objs[:2]:
        if o.get("uv_role") != "tiling" or len(o.data.uv_layers) != 1:
            bad.append(f"{o.name} UVs")
    if bad:
        raise RuntimeError("oilfield_horizon: " + "; ".join(bad))
    for name, pos in anchors.items():
        e = bpy.data.objects[name]
        print(f"  {name}: Blender ({e.location.x:.2f}, {e.location.y:.2f}, {e.location.z:.2f}), "
              f"Godot ({e.location.x:.2f}, {e.location.z:.2f}, {-e.location.y:.2f}), scale {tuple(e.scale)}, "
              f"rotation {tuple(e.rotation_euler)}, children {len(e.children)}, parent {e.parent.name}")


def build_horizon() -> list:
    glb = "oilfield_horizon"
    root = fresh_root(glb)
    mats = {
        "Horizon_Rock": material("M_Rock", glb, PALETTE["scorched"]),
        "Horizon_RockDark": material("M_RockDark", glb, PALETTE["far_iron"]),
        "Horizon_Flame": material("M_Flame", glb, PALETTE["burning_oil"]),
        "Horizon_LampGlass": material("M_LampGlass", glb, PALETTE["white_hot"]),
    }
    if HZ_PLUMES:
        for k in (1, 2, 3):
            mats[f"Plume_{k}"] = material("M_Smoke", glb, PALETTE["scorched"])
    loose, anchors = _hz_geometry()
    objs = []
    for name in HZ_PARTS:
        m = loose[name]
        print(f"  {name}: " + ", ".join(f"{k} {v}" for k, v in m.pieces.items()))
        objs.append(finish(m, mats[name], root))
    for o in objs[:2]:  # the rock objects: 8 m tiling UVs, zero rotation, origin at the tile's (Canyon G2, G3)
        scenery_uv.unwrap_object(o, scenery_uv.TILING)
        o["uv_role"] = "tiling"
    for name, pos in anchors.items():
        e = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(e)
        e.empty_display_type = "PLAIN_AXES"
        e.empty_display_size = 1.0
        e.parent = root
        e.matrix_parent_inverse = Matrix.Identity(4)
        e.location = pos
        e.rotation_euler = (0.0, 0.0, 0.0)
        e.scale = (1.0, 1.0, 1.0)
        if e.name != name:
            raise RuntimeError(f"anchor name taken: wanted {name}, got {e.name}")
    bpy.context.view_layer.update()
    check_horizon(objs, anchors)
    return objs


# --------------------------------------------------------------------------------------
# oil_burning_well (sheet B; C step 4): the horizon mound's vocabulary at the mid belt's 0.25 m floor
# --------------------------------------------------------------------------------------

BW_BUDGET = 300
BW_PARTS = ("Well_Rock", "Well_Dirt", "Well_Iron", "Well_Flame", "Well_LampGlass")
# Berm: an octagon, inner wall 4.4, crest 5.2 (0.8 wide), 2.2 tall, 35 degree outer slope to a toe at 8.34. Edge 0
# (normal +X, toward the train from the left belt) is the breach. Edge 7 (normal -45 degrees) is the slumped block.
BW_A_IN, BW_A_CREST, BW_H = 4.4, 5.2, 2.2
BW_A_TOE = BW_A_CREST + BW_H / TAN35
BW_SLUMP = {7: 1.1}
BW_POOL_APOTHEM, BW_POOL_Z = 4.0, 0.5  # a 12-sided pool 8 m across (flat to flat) at 0.5
BW_CASING_R, BW_CASING_Z0, BW_CASING_Z1 = 0.7, 0.4, 1.9  # iron, 8-sided, 1.4 m across, 1.4 m above the pool's top
BW_MOUTH_R, BW_MOUTH_TOP = 0.5, 3.0  # the white-hot mouth above it, 1.0 m across
# The spill apron: x from, x to, top z at each end, half width at each end.
BW_APRON = (3.5, 9.0, 0.26, 0.20, 1.6, 2.8)


def _bw_geometry():
    rock, dirt = Loose("Well_Rock"), Loose("Well_Dirt")
    iron, flame, lamp = Loose("Well_Iron"), Loose("Well_Flame"), Loose("Well_LampGlass")
    berm(rock, "berm", 0.0, 0.0, 8, 0.0, 0.0, BW_A_IN, BW_A_CREST, BW_A_TOE, BW_H, slump=BW_SLUMP)
    # The burning pool: a 12-gon cylinder from the ground to 0.5, its top and sides glowing.
    r = BW_POOL_APOTHEM / math.cos(math.pi / 12.0)
    pool0 = [(r * math.cos(math.radians(15.0 + 30.0 * k)), r * math.sin(math.radians(15.0 + 30.0 * k)), 0.0)
             for k in range(12)]
    pool1 = [(p[0], p[1], BW_POOL_Z) for p in pool0]
    flame.tube("pool", pool0, pool1, (0.0, 0.0, BW_POOL_Z / 2.0), cap_b=True)
    # The blown casing: iron, rising from inside the pool; a shoulder; the white-hot mouth on top.
    c0 = ngon((0.0, 0.0), BW_CASING_R, 8, "Z", BW_CASING_Z0, 22.5)
    c1 = [(p[0], p[1], BW_CASING_Z1) for p in c0]
    iron.tube("casing", c0, c1, (0.0, 0.0, (BW_CASING_Z0 + BW_CASING_Z1) / 2.0))
    m0 = ngon((0.0, 0.0), BW_MOUTH_R, 8, "Z", BW_CASING_Z1, 22.5)
    m1 = [(p[0], p[1], BW_MOUTH_TOP) for p in m0]
    for i in range(8):  # the shoulder between the casing's top rim and the mouth's foot
        j = (i + 1) % 8
        iron.poly("shoulder", (c1[i], c1[j], m0[j], m0[i]), (0.0, 0.0, BW_CASING_Z1 - 0.5))
    lamp.tube("mouth", m0, m1, (0.0, 0.0, (BW_CASING_Z1 + BW_MOUTH_TOP) / 2.0), cap_b=True)
    # The spill apron out of the breach: a sloped tongue of oil-soaked earth, 0.26 to 0.20, its inner end under
    # the pool.
    x0, x1, z0, z1, w0, w1 = BW_APRON
    ref = ((x0 + x1) / 2.0, 0.0, 0.1)
    a = [(x0, -w0, 0.0), (x0, w0, 0.0), (x0, w0, z0), (x0, -w0, z0)]
    b = [(x1, -w1, 0.0), (x1, w1, 0.0), (x1, w1, z1), (x1, -w1, z1)]
    dirt.poly("apron top", (a[3], a[2], b[2], b[3]), ref)
    dirt.poly("apron side +y", (a[1], b[1], b[2], a[2]), ref)
    dirt.poly("apron side -y", (a[0], b[0], b[3], a[3]), ref)
    dirt.poly("apron end", (b[0], b[1], b[2], b[3]), ref)
    dirt.poly("apron start", a, ref)
    anchor = (0.0, 0.0, BW_MOUTH_TOP)
    return {m.name: m for m in (rock, dirt, iron, flame, lamp)}, anchor


def check_well(objs, anchor) -> None:
    """Sheet D's asset checks on the built well. Raises on a failure."""
    total = 0
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    zero = smooth = nonplanar = collinear = 0
    for o in objs:
        n = count_tris(o)
        total += n
        print(f"  {o.name}: {n} tris, {len(o.data.polygons)} faces, material {o.data.materials[0].name}")
        me = o.data
        for t in me.loop_triangles:
            if t.area < 1e-6:
                zero += 1
        for p in me.polygons:
            smooth += int(p.use_smooth)
            co = [me.vertices[i].co for i in p.vertices]
            d = p.normal.dot(co[0])
            if max(abs(p.normal.dot(c) - d) for c in co) > 1e-4:
                nonplanar += 1
            for i in range(len(co)):
                a, b, c = co[i - 1], co[i], co[(i + 1) % len(co)]
                if (b - a).cross(c - b).length < 1e-6 * max(1.0, (c - a).length):
                    collinear += 1
        for v in me.vertices:
            for k in range(3):
                lo[k] = min(lo[k], v.co[k])
                hi[k] = max(hi[k], v.co[k])
    print(f"oil_burning_well: {total} / {BW_BUDGET} tris in {len(objs)} objects; geometry {geometry_hash(objs)}")
    print("  extents x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f" % (lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
    print(f"  zero-area triangles {zero}, non-planar faces {nonplanar}, smooth faces {smooth}, "
          f"collinear outline points {collinear}")
    near = flat_faces_near_terrain(objs)
    print(f"  flat faces within 0.08 m of the terrain's top: {near}")
    ntri, pairs, overlaps = coplanar_overlaps(objs)
    print(f"  coplanar test: {ntri} triangles, {pairs} coplanar pairs, {overlaps} sharing area")
    bad = []
    if total > BW_BUDGET:
        bad.append("over budget")
    if lo.z < -1e-4:
        bad.append("below z 0")
    if zero or nonplanar or smooth or near or overlaps:
        bad.append("mesh")
    if any("." in o.name or o.parent is None or o.parent.name != "oil_burning_well" for o in objs):
        bad.append("names or parents")
    for o in objs:
        if tuple(o.location) != (0.0, 0.0, 0.0) or tuple(o.rotation_euler) != (0.0, 0.0, 0.0) \
                or tuple(o.scale) != (1.0, 1.0, 1.0):
            bad.append(f"{o.name} not at the origin")
    for o in objs[:2]:
        if o.get("uv_role") != "tiling" or len(o.data.uv_layers) != 1:
            bad.append(f"{o.name} UVs")
    if bad:
        raise RuntimeError("oil_burning_well: " + "; ".join(bad))
    e = bpy.data.objects["Flame_Near"]
    print(f"  Flame_Near: Blender ({e.location.x:.2f}, {e.location.y:.2f}, {e.location.z:.2f}), "
          f"Godot ({e.location.x:.2f}, {e.location.z:.2f}, {-e.location.y:.2f}), scale {tuple(e.scale)}, "
          f"rotation {tuple(e.rotation_euler)}, children {len(e.children)}, parent {e.parent.name}")


def build_burning_well() -> list:
    glb = "oil_burning_well"
    root = fresh_root(glb)
    mats = {
        "Well_Rock": material("M_Rock", glb, PALETTE["scorched"]),
        "Well_Dirt": material("M_Dirt", glb, PALETTE["oil_soaked"]),
        "Well_Iron": material("M_Iron", glb, PALETTE["iron"]),
        "Well_Flame": material("M_Flame", glb, PALETTE["burning_oil"]),
        "Well_LampGlass": material("M_LampGlass", glb, PALETTE["white_hot"]),
    }
    loose, anchor = _bw_geometry()
    objs = []
    for name in BW_PARTS:
        m = loose[name]
        print(f"  {name}: " + ", ".join(f"{k} {v}" for k, v in m.pieces.items()))
        objs.append(finish(m, mats[name], root))
    for o in objs[:2]:  # rock and dirt: 8 m tiling UVs, zero rotation, origin at the root's
        scenery_uv.unwrap_object(o, scenery_uv.TILING)
        o["uv_role"] = "tiling"
    e = bpy.data.objects.new("Flame_Near", None)
    bpy.context.scene.collection.objects.link(e)
    e.empty_display_type = "PLAIN_AXES"
    e.empty_display_size = 1.0
    e.parent = root
    e.matrix_parent_inverse = Matrix.Identity(4)
    e.location = anchor
    e.rotation_euler = (0.0, 0.0, 0.0)
    e.scale = (1.0, 1.0, 1.0)
    if e.name != "Flame_Near":
        raise RuntimeError(f"anchor name taken: wanted Flame_Near, got {e.name}")
    bpy.context.view_layer.update()
    for o in objs:
        o.data.calc_loop_triangles()
    check_well(objs, anchor)
    return objs


# --------------------------------------------------------------------------------------
# Shared pieces for the mid belt's modules (oil_derrick, oil_tank)
# --------------------------------------------------------------------------------------

def prism(p: Part, label: str, a, b, r: float, sides: int, xf=None) -> list:
    """A `sides`-gon prism of circumradius r from a to b; its two end caps are dropped (they sit inside what it
    joins). `sides` must not be 4: the quads would be dropped with the caps."""
    a, b = Vector(a), Vector(b)
    axis = (b - a).normalized()
    ref = Vector((0.0, 0.0, 1.0)) if abs(axis.z) < 0.9 else Vector((1.0, 0.0, 0.0))
    u = axis.cross(ref).normalized()
    v = axis.cross(u)
    rings = []
    for c in (a, b):
        rings.append([tuple(c + r * (math.cos(2.0 * math.pi * k / sides) * u + math.sin(2.0 * math.pi * k / sides) * v))
                      for k in range(sides)])
    return p.solid(label, rings, drop=lambda f: len(f.verts) == sides, xf=xf)


def piece_counts(parts) -> dict:
    out = {}
    for part in parts:
        out[part.name] = {}
        for label, faces in part.pieces:
            n = sum(len(f.verts) - 2 for f in faces if f.is_valid)
            out[part.name][label] = out[part.name].get(label, 0) + n
    return out


def check_module(glb: str, objs, budget_total: int, names, extent_y: float, may_sink: bool = False) -> None:
    """Sheet D's asset checks on a built mid-belt module. Raises on a failure."""
    total = 0
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    zero = smooth = nonplanar = collinear = 0
    for o in objs:
        me = o.data
        me.calc_loop_triangles()
        n = count_tris(o)
        total += n
        print(f"  {o.name}: {n} tris, {len(me.polygons)} faces, {sum(1 for q in me.polygons if len(q.vertices) > 4)} "
              f"n-gons, material {me.materials[0].name}")
        for t in me.loop_triangles:
            if t.area < 1e-6:
                zero += 1
                print(f"    ZERO-AREA {o.name}[{t.polygon_index}] at {tuple(round(c, 2) for c in me.polygons[t.polygon_index].center)}")
        for q in me.polygons:
            smooth += int(q.use_smooth)
            co = [me.vertices[i].co for i in q.vertices]
            d = q.normal.dot(co[0])
            if max(abs(q.normal.dot(c) - d) for c in co) > 1e-4:
                nonplanar += 1
            for i in range(len(co)):
                a, b, c = co[i - 1], co[i], co[(i + 1) % len(co)]
                if (b - a).cross(c - b).length < 1e-6 * max(1.0, (c - a).length):
                    collinear += 1
        for vtx in me.vertices:
            for k in range(3):
                lo[k] = min(lo[k], vtx.co[k])
                hi[k] = max(hi[k], vtx.co[k])
    print(f"{glb}: {total} / {budget_total} tris in {len(objs)} objects; geometry {geometry_hash(objs)}")
    print("  extents x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f" % (lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
    print(f"  zero-area triangles {zero}, non-planar faces {nonplanar}, smooth faces {smooth}, "
          f"collinear outline points {collinear}")
    near = flat_faces_near_terrain(objs)
    print(f"  flat faces within 0.08 m of the terrain's top: {near}")
    ntri, pairs, overlaps = coplanar_overlaps(objs)
    print(f"  coplanar test: {ntri} triangles, {pairs} coplanar pairs, {overlaps} sharing area")
    bad = []
    if total > budget_total:
        bad.append("over budget")
    if lo.z < -1e-4 and not may_sink:
        bad.append("below z 0")
    if max(abs(lo.y), abs(hi.y)) > extent_y:
        bad.append("outside the slot")
    if zero or nonplanar or smooth or near or overlaps:
        bad.append("mesh")
    if [o.name for o in objs] != list(names):
        bad.append("object names")
    if any("." in o.name or o.parent is None or o.parent.name != glb for o in objs):
        bad.append("names or parents")
    for o in objs:
        if tuple(o.location) != (0.0, 0.0, 0.0) or tuple(o.rotation_euler) != (0.0, 0.0, 0.0) \
                or tuple(o.scale) != (1.0, 1.0, 1.0):
            bad.append(f"{o.name} not at the origin")
    if bad:
        raise RuntimeError(f"{glb}: " + "; ".join(bad))


# --------------------------------------------------------------------------------------
# oil_derrick (sheet B; C step 5): a standard rig of 1884 with its machinery beside it
# --------------------------------------------------------------------------------------

DK_BUDGET = 600
# The lattice: four legs 0.35 m on a tapering square (centre lines 3.0 m from the axis at the ground, 0.8 at the
# platform), girts at five levels, one diagonal per bay per face, the lowest two bays X-braced. The whole derrick
# leans 2 degrees away from its engine house (toward -Y), pivoting at the ground (the wear), and one upper brace on
# the +X face is missing (the gap shows the band).
DK_Y = -12.5  # the derrick's axis, Y; the machinery sits along +Y beside it
DK_BASE, DK_TOP, DK_LEG_H = 3.0, 0.8, 20.5
DK_LEG_T, DK_GIRT_T, DK_BRACE_R = 0.35, 0.25, 0.15
DK_GIRTS = (4.0, 8.0, 12.0, 16.0, 20.0)
DK_LEAN = 2.0
DK_MISSING = ("x", 1, 3)  # the +X face's fourth bay, 12 to 16 m


def dk_half(z: float) -> float:
    return DK_BASE + (DK_TOP - DK_BASE) * z / DK_LEG_H


def build_derrick_frame(p: Part, i: Part) -> None:
    xf = tilt((0.0, DK_Y, 0.0), "X", DK_LEAN)  # +X rotation: the top moves toward -Y, away from the engine house
    h = DK_LEG_T / 2.0
    # Legs, from 0.3 m under the ground (the lean lifts the +Y feet 0.1 m) to the platform.
    for sx in (-1, 1):
        for sy in (-1, 1):
            rings = []
            for z in (-0.3, DK_LEG_H):
                c = dk_half(z)
                rings.append(rect(sx * c - h, sx * c + h, DK_Y + sy * c - h, DK_Y + sy * c + h, z))
            p.solid("leg", rings, drop=lambda f: abs(f.normal.z) > 0.99, xf=xf)
    # Girts: a square ring of four boxes at each level, their ends inside the legs.
    g = DK_GIRT_T / 2.0
    for z in DK_GIRTS:
        c = dk_half(z)
        reach = c - h + 0.02  # each girt's ends stop 2 cm inside a leg, so the four never share a top or a bottom
        for s in (-1, 1):
            p.box("girt", -reach, reach, DK_Y + s * c - g, DK_Y + s * c + g, z - g, z + g, drop=along_x, xf=xf)
            p.box("girt", s * c - g, s * c + g, DK_Y - reach, DK_Y + reach, z - g, z + g, drop=along_y, xf=xf)
    # Braces: one diagonal per bay per face, alternating direction up the faces; the lowest two bays crossed.
    levels = (0.0,) + DK_GIRTS

    def corner(axis, sign, end, z):
        c = dk_half(z)
        return (sign * c, DK_Y + end * c, z) if axis == "x" else (end * c, DK_Y + sign * c, z)

    for axis in ("x", "y"):
        for sign in (-1, 1):
            for bay in range(5):
                if (axis, sign, bay) == DK_MISSING:
                    continue
                z0, z1 = levels[bay], levels[bay + 1]
                e = -1 if bay % 2 == 0 else 1
                prism(p, "brace", corner(axis, sign, e, z0), corner(axis, sign, -e, z1), DK_BRACE_R, 3, xf=xf)
                if bay < 2:  # the second diagonal stands 0.10 m proud of the face, so the two never share a plane
                    a, b = list(corner(axis, sign, -e, z0)), list(corner(axis, sign, e, z1))
                    k = 0 if axis == "x" else 1
                    a[k] += sign * 0.10
                    b[k] += sign * 0.10
                    prism(p, "brace x", a, b, DK_BRACE_R, 3, xf=xf)
    # Platform 2.4 m square, the crown block on it, and the crown sheave (iron) over that.
    zp = DK_LEG_H
    p.box("platform", -1.2, 1.2, DK_Y - 1.2, DK_Y + 1.2, zp - 0.10, zp + 0.15, xf=xf)
    p.box("crown block", -0.5, 0.5, DK_Y - 0.5, DK_Y + 0.5, zp + 0.15, zp + 1.0, drop=down, xf=xf)
    zc, rs = zp + 1.0 + 0.30, 0.35
    i.solid("crown sheave", [[(x, DK_Y + rs * math.cos(math.radians(30 + 60 * k)),
                               zc + rs * math.sin(math.radians(30 + 60 * k))) for k in range(6)]
                             for x in (-0.12, 0.12)], xf=xf)


# The machinery along +Y (the derrick's axis at DK_Y): walking beam 7.9 m on a Samson post 4.0 m, a band wheel
# 2.7 m, a belt house, and the engine house with its iron roof and stack.
DK_PY = -3.15  # the post's Y
DK_BEAM = (-7.1, 0.8, 0.35, 3.8, 4.2)  # y0, y1, width, z0, z1
DK_WHEEL = (3.3, 1.55, 1.35, 0.35)  # centre y, z, radius, thickness
DK_BELT = (5.0, 8.0, 0.9, 2.4)  # belt house: y0, y1, half width, height (its end is inside the engine house)
DK_ENG = (7.8, 13.8, 2.0, 3.5, 4.7)  # engine house: y0, y1, half width, eaves, ridge
DK_STACK = (0.6, 12.0, 0.28, 2.0, 8.0)  # x, y, circumradius, z0, z1


def build_derrick_machinery(p: Part, i: Part) -> None:
    y0, y1, w, z0, z1 = DK_BEAM
    p.box("walking beam", -w / 2, w / 2, y0, y1, z0, z1)
    # Samson post: two A-frames either side of the beam, the legs meeting under the bearing block.
    for sx in (-1, 1):
        for sy in (-1, 1):
            rings = []
            for z, dy in ((0.0, 1.2), (3.6, 0.14)):  # the legs stop 3 cm apart, so no two share a face
                cx, cy = sx * 0.40, DK_PY + sy * dy
                rings.append(rect(cx - 0.125, cx + 0.125, cy - 0.125, cy + 0.125, z))
            p.solid("post leg", rings, drop=lambda f: abs(f.normal.z) > 0.99)
    p.box("bearing block", -0.55, 0.55, DK_PY - 0.3, DK_PY + 0.3, 3.5, 3.85, drop=down)
    p.box("post brace", -0.40, 0.40, DK_PY + 0.7 - 0.10, DK_PY + 0.7 + 0.10, 1.5, 1.7, drop=along_x)
    # Band wheel: 8 sides, axis along X, and the pitman from the beam's tail to its crank pin.
    cy, cz, r, t = DK_WHEEL
    p.solid("band wheel", [[(x, cy + r * math.cos(math.radians(22.5 + 45 * k)),
                             cz + r * math.sin(math.radians(22.5 + 45 * k))) for k in range(8)]
                           for x in (-t / 2, t / 2)])
    pin = (0.35, cy + r * math.cos(math.radians(60)), cz + r * math.sin(math.radians(60)))
    prism(p, "pitman", (0.35, 0.2, 3.8), pin, 0.14, 3)
    # Belt house between the wheel and the engine house: a plain box, flat top.
    b0, b1, bw, bh = DK_BELT
    p.box("belt house", -bw, bw, b0, b1, 0.0, bh, drop=lambda f: down(f) or (along_y(f) and f.normal.y > 0))
    # Engine house: a gabled box (timber walls and gable ends; the roof slopes are the iron sheets').
    e0, e1, ew, eave, ridge = DK_ENG
    prof = [(-ew, 0.0), (ew, 0.0), (ew, eave), (0.0, ridge), (-ew, eave)]
    p.solid("engine house", [[(x, y, z) for x, z in prof] for y in (e0, e1)],
            drop=lambda f: down(f) or (len(f.verts) == 4 and abs(f.normal.z) > 0.3 and abs(f.normal.x) > 0.3))
    # Iron roof: two sheets 0.12 m thick with 0.3 m of eave and gable overhang, their undersides dropped.
    slope = Vector((ew, ridge - eave)).normalized()
    for s in (-1, 1):
        nrm = Vector((s * slope.y, 0.0, slope.x))  # the slope's outward normal
        low = (s * (ew + slope.x * 0.3), eave - slope.y * 0.3)
        high = (0.0, ridge)
        rings = []
        for off in (0.0, 0.12):
            q = [(x + nrm.x * off, yy, z + nrm.z * off) for yy in (e0 - 0.3, e1 + 0.3) for x, z in (low, high)]
            rings.append([q[0], q[1], q[3], q[2]])
        i.solid("roof sheet", rings, drop=lambda f, n=nrm: f.normal.dot(n) < -0.99)
    sx, sy_, sr, sz0, sz1 = DK_STACK
    i.solid("stack", [ngon((sx, sy_), sr, 6, "Z", z) for z in (sz0, sz1)], drop=down)


def build_derrick() -> list:
    glb = "oil_derrick"
    root = fresh_root(glb)
    m_plank = material("M_Plank", glb, PALETTE["raw_wood"])
    m_iron = material("M_Iron", glb, PALETTE["iron"])
    plank, iron = Part("Derrick_Plank"), Part("Derrick_Iron")
    build_derrick_frame(plank, iron)
    build_derrick_machinery(plank, iron)
    lines = piece_counts((plank, iron))
    objs = [finish(plank, m_plank, root), finish(iron, m_iron, root)]
    for o in objs:
        print(f"  {o.name}: " + ", ".join(f"{k} {v}" for k, v in lines[o.name].items()))
    bpy.context.view_layer.update()
    check_module(glb, objs, DK_BUDGET, ("Derrick_Plank", "Derrick_Iron"), HZ_HALF_Y, may_sink=True)
    return objs


# --------------------------------------------------------------------------------------
# oil_tank (sheet B; C step 5): a battery of two riveted sheet-iron tanks
# --------------------------------------------------------------------------------------

TK_BUDGET = 320
TK_PHASE = 15.0  # 12 sides with a flat facing each of +-X and +-Y
TK_APO = math.cos(math.radians(15.0))  # apothem / circumradius
TK_A = dict(R=5.0, H=7.0, roof=1.2)  # circumradius 5.0: 10 m across the corners
TK_B = dict(R=3.5, H=5.5, roof=0.9)
TK_GAP = 3.0  # between the two walls' facets, along Y
_TK_SPAN = (TK_A["R"] + TK_B["R"]) * 2.0 * TK_APO + TK_GAP
TK_YA = TK_A["R"] * TK_APO - _TK_SPAN / 2.0  # the battery centred on Y 0
TK_YB = TK_YA + (TK_A["R"] + TK_B["R"]) * TK_APO + TK_GAP
TK_RIM_H, TK_RIM_OUT = 0.30, 0.12  # the rim angle: 0.30 m tall, 0.12 m proud of the wall's facet
TK_STEP_Z, TK_STEP_H = 3.4, 0.25  # tank A's course step: 0.12 m proud, at mid-height
TK_SLUMP = 4.0  # B's roof, degrees, its +X edge down
TK_STAIR_X0, TK_STAIR_X1, TK_STAIR_N = 4.78, 5.78, 6
TK_PIPE_Z, TK_PIPE_R = 1.0, 0.15


def _ring(cx, cy, r, z):
    return ngon((cx, cy), r, 12, "Z", z, TK_PHASE)


def _radial(pts, cx, cy):
    m = sum((Vector(q) for q in pts), Vector()) / len(pts)
    return (m.x - cx, m.y - cy, 0.0)


def _tank_sheet(p: Part, cx, cy, spec, slump=0.0) -> None:
    R, H, rise = spec["R"], spec["H"], spec["roof"]
    p.solid("wall", [_ring(cx, cy, R, 0.0), _ring(cx, cy, R, H)], drop=lambda f: abs(f.normal.z) > 0.99)
    top = [Vector(q) for q in _ring(cx, cy, R, H)] + [Vector((cx, cy, H + rise))]
    if slump:
        xf = tilt((cx, cy, H), "Y", slump)  # +X edge down
        top = [xf @ q for q in top]
    verts = [tuple(q) for q in top]
    polys = [(k, (k + 1) % 12, 12) for k in range(12)]
    outward = []
    for poly in polys:
        o = _radial([verts[poly[0]], verts[poly[1]]], cx, cy)
        outward.append((o[0], o[1], R))
    p.faces("roof", verts, polys, outward)


def _tank_rim(p: Part, cx, cy, spec, z0, z1, dent=None) -> None:
    R = spec["R"]
    Rr = (R * TK_APO + TK_RIM_OUT) / TK_APO
    pts = [Vector(q) for q in ngon((cx, cy), Rr, 12, "Z", 0.0, TK_PHASE)]
    if dent is not None:  # one vertex replaced by a 0.6 m flat, pulled in 0.35 m
        v = pts[dent]
        radial = Vector((v.x - cx, v.y - cy, 0.0)).normalized()
        tang = Vector((-radial.y, radial.x, 0.0))
        pts = pts[:dent] + [v - tang * 0.30 - radial * 0.35, v + tang * 0.30 - radial * 0.35] + pts[dent + 1:]
    n = len(pts)
    verts = [(q.x, q.y, z0) for q in pts] + [(q.x, q.y, z1) for q in pts]
    polys = [(k, (k + 1) % n, n + (k + 1) % n, n + k) for k in range(n)]
    p.faces("rim", verts, polys, [_radial([verts[i] for i in poly], cx, cy) for poly in polys])


def _tank_step(p: Part, cx, cy, spec) -> None:
    R = spec["R"]
    Rs = (R * TK_APO + TK_RIM_OUT) / TK_APO
    z0, z1 = TK_STEP_Z, TK_STEP_Z + TK_STEP_H
    verts = _ring(cx, cy, Rs, z0) + _ring(cx, cy, Rs, z1) + _ring(cx, cy, R, z1)
    polys, outward = [], []
    for k in range(12):
        j = (k + 1) % 12
        polys.append((k, j, 12 + j, 12 + k))
        outward.append(_radial([verts[k], verts[j]], cx, cy))
        polys.append((12 + k, 12 + j, 24 + j, 24 + k))
        outward.append((0.0, 0.0, 1.0))
    p.faces("course step", verts, polys, outward)


def _stair(p: Part, cx, cy) -> None:
    """Two flights up tank A's +X face: the first climbs toward +Y to a landing at 3.5 m, the second comes back
    over it to the rim at 7.0 m. Each flight is one sawtooth slab of 6 steps."""
    x0, x1, n = TK_STAIR_X0, TK_STAIR_X1, TK_STAIR_N
    top = TK_A["H"]
    mid = top / 2.0

    def flight(label, s_a, s_b, z_a, z_b):
        run, rise = (s_b - s_a) / n, (z_b - z_a) / n
        prof = [(s_a, z_a)]
        for k in range(n):
            prof.append((s_a + k * run, z_a + (k + 1) * rise))
            prof.append((s_a + (k + 1) * run, z_a + (k + 1) * rise))
        prof.append((s_b, z_b - 0.35))
        # The sides' n-gons would triangulate with zero-area slivers along the collinear nose, so each side is
        # closed by one quad a step instead.
        p.solid(label, [[(x, cy + s, z) for s, z in prof] for x in (x0, x1)], drop=lambda f: len(f.verts) > 4)

        def under(s):
            return z_a + (z_b - 0.35 - z_a) * (s - s_a) / (s_b - s_a)

        for x, out in ((x0, -1.0), (x1, 1.0)):
            for k in range(n):
                sk, sk1 = s_a + k * run, s_a + (k + 1) * run
                top = z_a + (k + 1) * rise
                p.faces(label + " side", [(x, cy + sk, under(sk)), (x, cy + sk1, under(sk1)), (x, cy + sk1, top),
                                          (x, cy + sk, top)], [(0, 1, 2, 3)], [(out, 0.0, 0.0)])

    flight("stair flight 1", -1.6, 0.6, 0.0, mid)
    p.box("stair landing", x0, x1, cy + 0.6, cy + 1.8, mid - 0.2, mid,
          drop=lambda f: down(f) or (along_y(f) and f.normal.y < 0))
    flight("stair flight 2", 1.8, -0.4, mid, top)


def build_tank() -> list:
    glb = "oil_tank"
    root = fresh_root(glb)
    m_sheet = material("M_Sheet", glb, PALETTE["sheet_iron"])
    m_iron = material("M_Iron", glb, PALETTE["iron"])
    m_plank = material("M_Plank", glb, PALETTE["raw_wood"])
    sheet, iron, plank = Part("Tank_Sheet"), Part("Tank_Iron"), Part("Tank_Plank")
    _tank_sheet(sheet, 0.0, TK_YA, TK_A)
    _tank_sheet(sheet, 0.0, TK_YB, TK_B, slump=TK_SLUMP)
    lift = TK_B["R"] * math.sin(math.radians(TK_SLUMP))  # the raised (-X) edge of B's roof
    _tank_rim(iron, 0.0, TK_YA, TK_A, TK_A["H"] - TK_RIM_H, TK_A["H"])
    _tank_rim(iron, 0.0, TK_YB, TK_B, TK_B["H"] - 0.06, TK_B["H"] + lift, dent=3)
    _tank_step(iron, 0.0, TK_YA, TK_A)
    y_a = TK_YA + TK_A["R"] * TK_APO - 0.05
    y_b = TK_YB - TK_B["R"] * TK_APO + 0.05
    prism(iron, "header pipe", (0.0, y_a, TK_PIPE_Z), (0.0, y_b, TK_PIPE_Z), TK_PIPE_R, 6)
    _stair(plank, 0.0, TK_YA)
    lines = piece_counts((sheet, iron, plank))
    objs = [finish(sheet, m_sheet, root), finish(iron, m_iron, root), finish(plank, m_plank, root)]
    for o in objs:
        print(f"  {o.name}: " + ", ".join(f"{k} {v}" for k, v in lines[o.name].items()))
    bpy.context.view_layer.update()
    check_module(glb, objs, TK_BUDGET, ("Tank_Sheet", "Tank_Iron", "Tank_Plank"), HZ_HALF_Y)
    return objs


# --------------------------------------------------------------------------------------
# oil_pylon (sheet B; C step 6): a riveted-iron "man" tower with its span of wire to the next
# --------------------------------------------------------------------------------------

PY_BUDGET = 450
PY_PITCH = 96.0  # the belt's exact tower pitch: the wires end on the next tower's arm tips, 96 m along -Y
PY_BASE, PY_NECK, PY_HEAD = 2.0, 0.6, 0.45  # leg centre lines' distance from the axis at z 0, 16, and 22
PY_NECK_Z, PY_TOP_Z = 16.0, 22.0
PY_LEG_R, PY_BAR_R = 0.17, 0.145  # 3-sided members 0.30 m and 0.25 m a side
PY_GIRTS = (4.0, 8.0, 12.0, 16.0, 19.0)  # the four tower bays, then the cage bay to 19
PY_ARM_LO = (17.0, 3.0)  # z, half width: the 6.0 m cross-arm (its +X tip bent down 5 degrees)
PY_ARM_HI = (20.0, 2.0)  # the 4.0 m arm
PY_ARM_R = 0.15
PY_BEND_DEG, PY_BEND_FROM = 5.0, 1.5  # the lower arm's +X tip bends down from x 1.5
PY_INS_W, PY_INS_H = 0.25, 0.45  # insulator block hanging from an arm tip
PY_SAG = 3.0
PY_WIRE_R = 0.08 / math.sqrt(3.0)  # an 8 cm triangle
PY_SEGS = 6


def py_half(z: float) -> float:
    if z <= PY_NECK_Z:
        return PY_BASE + (PY_NECK - PY_BASE) * z / PY_NECK_Z
    return PY_NECK + (PY_HEAD - PY_NECK) * (z - PY_NECK_Z) / (PY_TOP_Z - PY_NECK_Z)


def py_arm_tips():
    """(x, z) of the three wire tips, z the arm's axis: lower -X, lower +X (bent), upper -X."""
    zl, hl = PY_ARM_LO
    zh, hh = PY_ARM_HI
    bent = zl - (hl - PY_BEND_FROM) * math.tan(math.radians(PY_BEND_DEG))
    return [(-hl, zl), (hl, bent), (-hh, zh)]


def py_anchor(tip) -> tuple:
    """Where a wire starts, inside its insulator block (x, z)."""
    return (tip[0], tip[1] - PY_ARM_R * 0.5 - PY_INS_H + 0.06)


def build_pylon_tower(p: Part) -> None:
    for sx in (-1, 1):
        for sy in (-1, 1):
            phase = math.degrees(math.atan2(sy, sx))
            rings = [ngon((sx * py_half(z), sy * py_half(z)), PY_LEG_R, 3, "Z", z, phase)
                     for z in (-0.2, PY_NECK_Z, PY_TOP_Z)]
            p.solid("leg", rings, drop=lambda f: len(f.verts) == 3)
    for z in PY_GIRTS:
        c = py_half(z)
        for s in (-1, 1):
            prism(p, "girt", (-c, s * c, z), (c, s * c, z), PY_BAR_R, 3)
            prism(p, "girt", (s * c, -c, z), (s * c, c, z), PY_BAR_R, 3)
    levels = (0.0,) + PY_GIRTS

    def corner(axis, sign, end, z):
        c = py_half(z)
        return (sign * c, end * c, z) if axis == "x" else (end * c, sign * c, z)

    for axis in ("x", "y"):
        for sign in (-1, 1):
            for bay in range(len(levels) - 1):
                e = -1 if bay % 2 == 0 else 1
                prism(p, "brace", corner(axis, sign, e, levels[bay]), corner(axis, sign, -e, levels[bay + 1]),
                      PY_BAR_R, 3)

    # Cross-arms: triangular bars, apex up. The lower arm's +X tip is bent down from x 1.5 (the wear).
    def arm_ring(x, z):
        return [(x, PY_ARM_R * math.cos(math.radians(a)), z + PY_ARM_R * math.sin(math.radians(a)))
                for a in (90.0, 210.0, 330.0)]

    zl, hl = PY_ARM_LO
    tips = py_arm_tips()
    p.solid("arm low", [arm_ring(-hl, zl), arm_ring(PY_BEND_FROM, zl), arm_ring(hl, tips[1][1])])
    zh, hh = PY_ARM_HI
    p.solid("arm high", [arm_ring(-hh, zh), arm_ring(hh, zh)])
    for tip in tips:
        bottom = tip[1] - PY_ARM_R * 0.5
        h = PY_INS_W / 2.0
        p.box("insulator", tip[0] - h, tip[0] + h, -h, h, bottom - PY_INS_H, bottom + 0.02, drop=up)


def build_pylon_wires(p: Part) -> list:
    """Three wires from this tower's insulators to the same tips PY_PITCH along -Y: six straight pieces a span
    through shared rings, sagging PY_SAG at mid-span. Returns each wire's (start, end) ring centres."""
    ends = []
    for tip in py_arm_tips():
        x, z0 = py_anchor(tip)
        rings = []
        for k in range(PY_SEGS + 1):
            t = k / PY_SEGS
            rings.append(ngon((x, z0 - 4.0 * PY_SAG * t * (1.0 - t)), PY_WIRE_R, 3, "Y", -PY_PITCH * t, 90.0))
        p.solid("wire", rings, drop=lambda f: len(f.verts) == 3)
        ends.append(((x, 0.0, z0), (x, -PY_PITCH, z0)))
    return ends


def build_pylon() -> list:
    glb = "oil_pylon"
    root = fresh_root(glb)
    m_iron = material("M_Iron", glb, PALETTE["iron"])
    iron = Part("Pylon_Iron")
    build_pylon_tower(iron)
    ends = build_pylon_wires(iron)
    lines = piece_counts((iron,))
    objs = [finish(iron, m_iron, root)]
    print("  Pylon_Iron: " + ", ".join(f"{k} {v}" for k, v in lines["Pylon_Iron"].items()))
    bpy.context.view_layer.update()
    # A wire's far ring lies on the same tip, one pitch along -Y, as the next copy's insulator.
    tips = [py_anchor(t) for t in py_arm_tips()]
    for (a, b), (x, z) in zip(ends, tips):
        if (b[0], b[2]) != (x, z) or b[1] != -PY_PITCH or a[1] != 0.0:
            raise RuntimeError("pylon wire does not end on the next tower's tip")
    low = min(v.co.z for v in objs[0].data.vertices if -56.0 < v.co.y < -40.0)
    print(f"  wires: three, sag {PY_SAG} m (lowest ring z {low:.2f}), ends on the next tower's tips at y {-PY_PITCH}; "
          f"tips (x, z) {[tuple(round(c, 3) for c in t) for t in py_arm_tips()]}")
    check_module(glb, objs, PY_BUDGET, ("Pylon_Iron",), PY_PITCH + 4.0, may_sink=True)
    return objs


# --------------------------------------------------------------------------------------
# oil_pipe_run (sheet B; C step 7): a 16 m flow line on four timber A-trestles
# --------------------------------------------------------------------------------------

PR_BUDGET = 140  # the sheet's figure: four trestles, 8 pipe pieces, an elbow, a flange, and collars cost 220 (H, batch 6)
PR_BUILT_MAX = 220
PR_Z = 1.125  # the pipe's axis over a trestle: pipe top at 1.25 m, under the 1.5 m rule
PR_R = 0.125  # 6-sided, 0.25 m across the corners
PR_SAG = 0.08
PR_TRESTLES = (-6.0, -2.0, 2.0, 6.0)
PR_LEAN_Y, PR_LEAN_DEG = 2.0, 6.0  # the third trestle leans 6 degrees toward +X; the pipe kinks 3 over it
PR_ELBOW_Y = -7.75
PR_FLANGE = (7.9, 8.0, 0.30)  # y0, y1, circumradius
PR_COLLARS = (-4.6, 0.0, 4.6)  # every 4.6 m (15 ft)
PR_COLLAR_R, PR_COLLAR_LEN = 0.165, 0.12
PR_LEG_R = 0.07
PR_LOW = (4.0, 0.0, -4.0)  # the sagging rings, mid-span


def pr_ring_y():
    return [PR_FLANGE[0], 6.0, 4.0, 2.0, 0.0, -2.0, -4.0, -6.0, PR_ELBOW_Y]


def pr_pipe_z(y: float) -> float:
    """The pipe axis' height at y: PR_Z at the trestles and the ends, PR_SAG lower at mid-span."""
    ys = pr_ring_y()
    for a, b in zip(ys[:-1], ys[1:]):
        if b <= y <= a:
            za = PR_Z - (PR_SAG if a in PR_LOW else 0.0)
            zb = PR_Z - (PR_SAG if b in PR_LOW else 0.0)
            return zb + (za - zb) * (y - b) / (a - b)
    return PR_Z


def build_pipe_iron(p: Part) -> None:
    kink = math.sin(math.radians(PR_LEAN_DEG)) * 1.0  # the leaning trestle's apex, 1.0 m up, moves this far
    rings = []
    for y in pr_ring_y():
        x = kink if y == PR_LEAN_Y else 0.0
        rings.append(ngon((x, pr_pipe_z(y)), PR_R, 6, "Y", y, 0.0))
    p.solid("pipe", rings, drop=lambda f: len(f.verts) == 6 or down(f))
    # The elbow into the ground: a vertical hex prism under the pipe's end, its top capped.
    elbow = p.solid("elbow", [ngon((0.0, PR_ELBOW_Y), PR_R, 6, "Z", z, 0.0) for z in (-0.1, PR_Z + PR_R)], drop=down)
    # The top cap is fanned into triangles: with the flange's cap this object would be exactly "two n-gons and
    # quads", which scenery_uv._is_cylinder unrolls as one cylinder (overlapping UVs).
    cap = bmesh.ops.triangulate(p.bm, faces=[f for f in elbow if f.is_valid and len(f.verts) == 6])["faces"]
    p.pieces.append(("elbow cap", cap))
    y0, y1, fr = PR_FLANGE
    p.solid("flange", [ngon((0.0, PR_Z), fr, 6, "Y", y, 0.0) for y in (y0, y1)],
            drop=lambda f: len(f.verts) == 6 and f.normal.y < 0.0)
    for yc in PR_COLLARS:
        z = pr_pipe_z(yc)
        p.solid("collar", [ngon((0.0, z), PR_COLLAR_R, 6, "Y", yc + s * PR_COLLAR_LEN / 2.0, 0.0) for s in (-1, 1)],
                drop=lambda f: len(f.verts) == 6)


def build_pipe_plank(p: Part) -> None:
    for yt in PR_TRESTLES:
        xf = tilt((0.0, yt, 0.0), "Y", PR_LEAN_DEG) if yt == PR_LEAN_Y else None
        for s in (-1, 1):
            rings = [ngon((s * 0.55, yt), PR_LEG_R, 3, "Z", -0.05, 90.0 - 90.0 * s),
                     ngon((s * 0.10, yt), PR_LEG_R, 3, "Z", PR_Z - PR_R + 0.03, 90.0 - 90.0 * s)]
            p.solid("trestle leg", rings, drop=lambda f: len(f.verts) == 3, xf=xf)
        prism(p, "saddle", (-0.32, yt, PR_Z - PR_R - 0.09), (0.32, yt, PR_Z - PR_R - 0.09), 0.08, 3, xf=xf)


def build_pipe_run() -> list:
    glb = "oil_pipe_run"
    root = fresh_root(glb)
    m_iron = material("M_Iron", glb, PALETTE["iron"])
    m_plank = material("M_Plank", glb, PALETTE["raw_wood"])
    iron, plank = Part("Pipe_Iron"), Part("Pipe_Plank")
    build_pipe_iron(iron)
    build_pipe_plank(plank)
    lines = piece_counts((iron, plank))
    objs = [finish(iron, m_iron, root), finish(plank, m_plank, root)]
    for o in objs:
        print(f"  {o.name}: " + ", ".join(f"{k} {v}" for k, v in lines[o.name].items()))
    bpy.context.view_layer.update()
    check_module(glb, objs, PR_BUILT_MAX, ("Pipe_Iron", "Pipe_Plank"), 8.5, may_sink=True)
    top = max(v.co.z for o in objs for v in o.data.vertices)
    print(f"  {sum(count_tris(o) for o in objs)} triangles against the sheet's {PR_BUDGET}")
    print(f"  tallest point {top:.3f} m (the near belt's limit inside x +-6.0 is 1.5 m)")
    return objs


# --------------------------------------------------------------------------------------
# oil_wellhead (sheet B; C step 7): a casinghead with a gate valve on a sloped pad
# --------------------------------------------------------------------------------------

WH_BUDGET = 120
WH_PAD_TOP = 0.22  # never within 0.08 m of the terrain's top (0.12)
WH_PAD_POLY = [(1.62, 0.10), (0.85, 1.38), (-0.72, 1.52), (-1.55, 0.20), (-0.90, -1.35), (0.78, -1.45)]
WH_PAD_OFFSET = 0.50  # the sloped sides run out this far by z 0
WH_CASING_R, WH_CASING_Z0, WH_CASING_Z1 = 0.20, 0.15, 1.10  # 0.40 m, 8-sided, 1.1 m
WH_TEE_Z, WH_TEE_R = 0.90, 0.13
WH_VALVE = (0.55, 0.90, 0.175, 0.725, 1.075)  # x0, x1, half width, z0, z1: a 0.35 m body
WH_STEM_X, WH_STEM_HALF, WH_STEM_Y0, WH_STEM_Y1 = 0.725, 0.05, -0.17, -0.62
WH_WHEEL_R, WH_WHEEL_Y0, WH_WHEEL_Y1 = 0.27, -0.70, -0.60  # 8-sided, 0.5 m across the flats, 0.10 m thick
WH_LINE_R = 0.10  # 6-sided, 0.20 m
WH_LINE_X0, WH_LINE_CORNER, WH_LINE_KINK_DEG, WH_LINE_END_Z = 0.88, 1.70, 4.0, 0.05


def _offset_poly(pts, d):
    """Each edge of the convex polygon `pts` moved outward by d, the corners where the moved edges meet: the
    bottom ring of a sloped side, so every side face is a planar trapezoid."""
    n = len(pts)
    lines = []
    for i in range(n):
        a, b = Vector(pts[i]), Vector(pts[(i + 1) % n])
        e = (b - a).normalized()
        nrm = Vector((e.y, -e.x))  # outward for a counter-clockwise polygon
        lines.append((a + nrm * d, e))
    out = []
    for i in range(n):
        p0, e0 = lines[i - 1]
        p1, e1 = lines[i]
        den = e0.x * e1.y - e0.y * e1.x
        t = ((p1.x - p0.x) * e1.y - (p1.y - p0.y) * e1.x) / den
        out.append(p0 + e0 * t)
    return out


def _bent_line(p: Part) -> None:
    """The flow line: from the valve's outlet along +X, a miter elbow at the corner, then down into the pad's
    sloped edge, the leg leaning WH_LINE_KINK_DEG off vertical (the wear). Two segments of six quads; both end caps
    are dropped (one inside the valve body, one under the pad)."""
    th = math.radians(WH_LINE_KINK_DEG)
    d0, d1 = Vector((1.0, 0.0, 0.0)), Vector((math.sin(th), 0.0, -math.cos(th)))
    ey = Vector((0.0, 1.0, 0.0))
    ez0, ez1 = d0.cross(ey), d1.cross(ey)
    corner = Vector((WH_LINE_CORNER, 0.0, WH_TEE_Z))
    miter = (d0 + d1).normalized()
    length = (WH_TEE_Z - WH_LINE_END_Z) / math.cos(th)
    end = corner + d1 * length
    start = Vector((WH_LINE_X0, 0.0, WH_TEE_Z))
    ring0, ring1, ring2 = [], [], []
    for k in range(6):
        a = math.radians(30.0 + 60.0 * k)
        o0 = WH_LINE_R * (math.cos(a) * ey + math.sin(a) * ez0)
        o1 = WH_LINE_R * (math.cos(a) * ey + math.sin(a) * ez1)
        s = -(o0.dot(miter)) / d0.dot(miter)
        ring0.append(tuple(start + o0))
        ring1.append(tuple(corner + o0 + d0 * s))
        ring2.append(tuple(end + o1))
    p.solid("flow line", [ring0, ring1], drop=lambda f: len(f.verts) == 6)
    p.solid("flow line dive", [ring1, ring2], drop=lambda f: len(f.verts) == 6)


def build_wellhead_iron(p: Part) -> None:
    # The casing: 8-sided, flats square to the axes; its foot is buried in the pad, the bottom dropped.
    p.solid("casing", [ngon((0.0, 0.0), WH_CASING_R, 8, "Z", z, 22.5) for z in (WH_CASING_Z0, WH_CASING_Z1)],
            drop=down)
    # The tee: a 6-sided stub from inside the casing to inside the valve body.
    prism(p, "tee", (0.10, 0.0, WH_TEE_Z), (WH_VALVE[0] + 0.05, 0.0, WH_TEE_Z), WH_TEE_R, 6)
    x0, x1, hw, z0, z1 = WH_VALVE
    p.box("valve body", x0, x1, -hw, hw, z0, z1, drop=lambda f: down(f) or f.normal.x < -0.99)
    sx, sh = WH_STEM_X, WH_STEM_HALF
    p.box("stem", sx - sh, sx + sh, WH_STEM_Y1, WH_STEM_Y0 + 0.005, WH_TEE_Z - sh, WH_TEE_Z + sh, drop=along_y)
    p.solid("handwheel", [ngon((sx, WH_TEE_Z), WH_WHEEL_R, 8, "Y", y, 22.5) for y in (WH_WHEEL_Y0, WH_WHEEL_Y1)])
    _bent_line(p)


def build_wellhead_pad(p: Part) -> None:
    top = [(x, y, WH_PAD_TOP) for x, y in WH_PAD_POLY]
    foot = [(v.x, v.y, 0.0) for v in _offset_poly(WH_PAD_POLY, WH_PAD_OFFSET)]
    p.solid("pad", [foot, top], drop=down)


def build_wellhead() -> list:
    glb = "oil_wellhead"
    root = fresh_root(glb)
    m_iron = material("M_Iron", glb, PALETTE["iron"])
    m_dirt = material("M_Dirt", glb, PALETTE["oil_soaked"])
    iron, pad = Part("Wellhead_Iron"), Part("Wellhead_Dirt")
    build_wellhead_iron(iron)
    build_wellhead_pad(pad)
    lines = piece_counts((iron, pad))
    objs = [finish(iron, m_iron, root), finish(pad, m_dirt, root)]
    scenery_uv.unwrap_object(objs[1], scenery_uv.TILING)  # the pad: 8 m tiling UVs, zero rotation, origin at the root's
    objs[1]["uv_role"] = "tiling"
    for o in objs:
        print(f"  {o.name}: " + ", ".join(f"{k} {v}" for k, v in lines[o.name].items()))
    bpy.context.view_layer.update()
    check_module("oil_wellhead", objs, WH_BUDGET, ("Wellhead_Iron", "Wellhead_Dirt"), 3.0, may_sink=True)
    top = max(v.co.z for o in objs for v in o.data.vertices)
    ext = [(min(v.co[k] for o in objs for v in o.data.vertices), max(v.co[k] for o in objs for v in o.data.vertices))
           for k in range(2)]
    print(f"  tallest point {top:.3f} m (the near belt's limit inside x +-6.0 is 1.5 m); pad top {WH_PAD_TOP}")
    print(f"  footprint x {ext[0][0]:.2f}..{ext[0][1]:.2f}, y {ext[1][0]:.2f}..{ext[1][1]:.2f}")
    if objs[1].get("uv_role") != "tiling" or len(objs[1].data.uv_layers) != 1:
        raise RuntimeError("oil_wellhead: the pad's UVs")
    return objs


# --------------------------------------------------------------------------------------
# oil_sump (sheet B; C step 7): an earth pit of oil in a ring berm, one breach, a tongue of spill
# --------------------------------------------------------------------------------------

SP_BUDGET = 70
SP_A_IN, SP_A_CREST, SP_H = 2.15, 2.60, 0.72  # inner wall, crest, tallest crest top (0.6 m over the ground at 0.12)
SP_A_TOE = SP_A_CREST + SP_H / TAN35
SP_BREACH = 270.0  # the edge whose normal is -Y (Godot +z): the tongue spills toward the player on approach
SP_SLUMP = {1: 0.62, 2: 0.66, 3: 0.66, 4: 0.60}  # crest tops by edge (edge 7 and 0 and 5 are 0.72): 10 to 15 cm a block
SP_POOL_Z = 0.35
SP_TONGUE = (0.24, 0.20, 3.0)  # top at the lip, top at the tip, metres beyond the berm's toe
SP_FLARE = 1.25  # the tongue's half width at its tip, against the pool's breach edge


def _sp_geometry():
    dirt, glass = Loose("Sump_Dirt"), Loose("Sump_Glass")
    berm(dirt, "berm", 0.0, 0.0, 8, 0.0, SP_BREACH, SP_A_IN, SP_A_CREST, SP_A_TOE, SP_H, slump=SP_SLUMP,
         floor=SP_POOL_Z)
    pool = _ngon_pts(0.0, 0.0, SP_A_IN, 8, 0.0, SP_POOL_Z)
    glass.poly("pool", pool, (0.0, 0.0, 0.1))
    w0 = SP_A_IN * math.tan(math.pi / 8.0)  # half the pool's breach edge
    w1 = w0 * SP_FLARE
    y0 = -SP_A_IN
    y1 = -(SP_A_TOE + SP_TONGUE[2])
    t0, t1 = SP_TONGUE[0], SP_TONGUE[1]
    ref = (0.0, (y0 + y1) / 2.0, 0.1)
    glass.poly("tongue top", [(-w0, y0, t0), (w0, y0, t0), (w1, y1, t1), (-w1, y1, t1)], ref)
    glass.poly("tongue side", [(w0, y0, 0.0), (w1, y1, 0.0), (w1, y1, t1), (w0, y0, t0)], ref)
    glass.poly("tongue side", [(-w0, y0, 0.0), (-w1, y1, 0.0), (-w1, y1, t1), (-w0, y0, t0)], ref)
    glass.poly("tongue end", [(-w1, y1, 0.0), (w1, y1, 0.0), (w1, y1, t1), (-w1, y1, t1)], ref)
    glass.poly("lip", [(-w0, y0, t0), (w0, y0, t0), (w0, y0, SP_POOL_Z), (-w0, y0, SP_POOL_Z)], (0.0, -1.0, 0.2))
    return {m.name: m for m in (dirt, glass)}


def build_sump() -> list:
    glb = "oil_sump"
    root = fresh_root(glb)
    mats = {"Sump_Dirt": material("M_Dirt", glb, PALETTE["oil_soaked"]),
            "Sump_Glass": material("M_Glass", glb, PALETTE["ink"])}
    loose = _sp_geometry()
    objs = []
    for name in ("Sump_Dirt", "Sump_Glass"):
        m = loose[name]
        print(f"  {name}: " + ", ".join(f"{k} {v}" for k, v in m.pieces.items()))
        objs.append(finish(m, mats[name], root))
    scenery_uv.unwrap_object(objs[0], scenery_uv.TILING)  # the berm: 8 m tiling UVs, zero rotation, origin at the root's
    objs[0]["uv_role"] = "tiling"
    bpy.context.view_layer.update()
    check_module("oil_sump", objs, SP_BUDGET, ("Sump_Dirt", "Sump_Glass"), 7.0, may_sink=True)
    top = max(v.co.z for o in objs for v in o.data.vertices)
    ext = [(min(v.co[k] for o in objs for v in o.data.vertices), max(v.co[k] for o in objs for v in o.data.vertices))
           for k in range(2)]
    print(f"  tallest point {top:.3f} m; pool at {SP_POOL_Z}; footprint x {ext[0][0]:.2f}..{ext[0][1]:.2f}, "
          f"y {ext[1][0]:.2f}..{ext[1][1]:.2f}")
    if objs[0].get("uv_role") != "tiling" or len(objs[0].data.uv_layers) != 1:
        raise RuntimeError("oil_sump: the berm's UVs")
    return objs


# --------------------------------------------------------------------------------------

PARTS = {"terrain": build_terrain, "pumpjack": build_pumpjack, "horizon": build_horizon,
         "burning_well": build_burning_well, "derrick": build_derrick, "tank": build_tank,
         "pylon": build_pylon, "pipe_run": build_pipe_run, "wellhead": build_wellhead, "sump": build_sump}
PLANNED = ()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    part = argv[argv.index("--part") + 1] if "--part" in argv else None
    if part in PLANNED:
        raise RuntimeError(f"--part {part} is not built yet (sheet C)")
    if part not in PARTS:
        raise RuntimeError("--part " + " | ".join(PARTS))
    open_blend()
    PARTS[part]()
    bpy.ops.wm.save_mainfile()
    print(f"saved {bpy.data.filepath}")
    print("BUILD_OK")


main()
