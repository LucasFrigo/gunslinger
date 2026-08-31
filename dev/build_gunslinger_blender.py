"""Build the low-poly A-pose gunslinger inside Blender (run via MCP execute_code)."""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT_DIR = r"e:\Projetos\gunslinger\assets\models\characters"
os.makedirs(OUT_DIR, exist_ok=True)

COL_BLACK = (0.035, 0.032, 0.038, 1.0)
COL_HAT = (0.12, 0.06, 0.03, 1.0)
COL_METAL = (0.12, 0.12, 0.14, 1.0)
COL_BOOT = (0.28, 0.16, 0.08, 1.0)
COL_SPUR = (0.45, 0.38, 0.28, 1.0)
COL_SCARF = (0.75, 0.18, 0.16, 1.0)
COL_EYE = (0.02, 0.02, 0.02, 1.0)
COL_SCLERA = (0.92, 0.90, 0.85, 1.0)


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def mat(name, color, roughness=0.9, metallic=0.0, spec=0.15):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = spec
    m.diffuse_color = color
    return m


def link(obj, parent=None):
    if obj.name not in bpy.context.collection.objects:
        bpy.context.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj


def mesh_from_bm(bm, name, parent=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.update()
    obj = bpy.data.objects.new(name, me)
    return link(obj, parent)


def box(name, loc, size, parent=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
        v.co += Vector(loc)
    return mesh_from_bm(bm, name, parent)


def cyl(name, start, end, r1, r2=None, segs=8, parent=None):
    if r2 is None:
        r2 = r1
    start, end = Vector(start), Vector(end)
    d = end - start
    length = d.length
    if length < 1e-6:
        length = 1e-6
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=segs,
        radius1=r1, radius2=r2, depth=length,
    )
    quat = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)), matrix=quat.to_matrix().to_4x4())
    bmesh.ops.translate(bm, verts=bm.verts, vec=(start + end) * 0.5)
    return mesh_from_bm(bm, name, parent)


def cone(name, loc, radius, depth, parent=None, segs=4):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=segs,
        radius1=radius, radius2=0.002, depth=depth,
    )
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(loc) + Vector((0, 0, depth * 0.5)))
    return mesh_from_bm(bm, name, parent)


def disc(name, loc, radius, height, segs=12, parent=None):
    return cyl(name, (loc[0], loc[1], loc[2] - height * 0.5), (loc[0], loc[1], loc[2] + height * 0.5), radius, radius, segs, parent)


def assign(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)


def join_into(target, others):
    if not others:
        return target
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    for o in others:
        o.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target


def make_poncho_image(path):
    w = h = 512
    stripes = [
        (0.95, 0.78, 0.18),
        (0.82, 0.12, 0.10),
        (0.12, 0.72, 0.78),
        (0.42, 0.82, 0.18),
        (0.90, 0.38, 0.55),
        (0.96, 0.82, 0.40),
    ]
    pixels = [0.0] * (w * h * 4)

    def setp(x, y, rgb, a=1.0):
        i = (y * w + x) * 4
        pixels[i:i + 4] = [rgb[0], rgb[1], rgb[2], a]

    def in_cross(u, v, cx, cy, s):
        return (abs(u - cx) < s * 0.18 and abs(v - cy) < s) or (abs(v - cy) < s * 0.18 and abs(u - cx) < s)

    def in_diamond(u, v, cx, cy, s):
        return abs(u - cx) + abs(v - cy) < s

    def in_sun(u, v, cx, cy, s):
        dx, dy = u - cx, v - cy
        r = math.hypot(dx, dy)
        if r < s * 0.35:
            return True
        ang = math.atan2(dy, dx)
        spoke = abs((ang / (math.pi / 4)) % 2 - 1)
        return r < s and spoke < 0.22

    for y in range(h):
        v = y / (h - 1)
        stripe_i = min(len(stripes) - 1, int(v * 12) % len(stripes))
        base = stripes[stripe_i]
        for x in range(w):
            u = x / (w - 1)
            if u < 0.5:
                rgb = list(base)
                # stamps in local stripe UV
                su, sv = (u * 2.0) * 6.0, v * 8.0
                cell_u, cell_v = su % 1.0, sv % 1.0
                kind = (int(su) + int(sv) * 3) % 3
                if kind == 0 and in_cross(cell_u, cell_v, 0.5, 0.5, 0.28):
                    rgb = [min(1, c + 0.25) for c in rgb]
                elif kind == 1 and in_diamond(cell_u, cell_v, 0.5, 0.5, 0.22):
                    rgb = [min(1, c * 0.55 + 0.2) for c in rgb]
                elif kind == 2 and in_sun(cell_u, cell_v, 0.5, 0.5, 0.32):
                    rgb = [min(1, rgb[0] + 0.18), min(1, rgb[1] + 0.1), rgb[2] * 0.7]
                setp(x, y, rgb)
            else:
                setp(x, y, (0.04, 0.035, 0.04))
    img = bpy.data.images.new("poncho_albedo", w, h, alpha=False)
    img.pixels = pixels
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def make_fringe_image(path):
    w, h = 64, 128
    pixels = [0.0] * (w * h * 4)
    for y in range(h):
        for x in range(w):
            # vertical tassels
            tassel = (x % 8) < 5
            fade = 1.0 - (y / (h - 1))
            a = 1.0 if tassel and fade > 0.05 else 0.0
            i = (y * w + x) * 4
            pixels[i:i + 4] = [0.92, 0.80, 0.42, a]
    img = bpy.data.images.new("poncho_fringe", w, h, alpha=True)
    img.pixels = pixels
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def poncho_mat(img):
    m = bpy.data.materials.new("M_Poncho")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return m


def fringe_mat(img):
    m = bpy.data.materials.new("M_Fringe")
    m.use_nodes = True
    m.blend_method = "CLIP"
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.9
    return m


def build_body(root, mats):
    # Torso under the duster
    torso = box("Torso", (0, 0, 1.12), (0.32, 0.18, 0.52), root)
    pelvis = box("Pelvis", (0, 0, 0.84), (0.30, 0.16, 0.18), root)
    neck = cyl("Neck", (0, 0, 1.36), (0, 0, 1.50), 0.055, 0.06, 6, root)

    # A-pose arms ~45° from vertical, empty hands
    arm_len = 0.58
    s = math.sin(math.radians(45))
    c = math.cos(math.radians(45))
    shoulder_z = 1.38
    shoulder_x = 0.20
    # character left = +X
    l_sh = Vector((shoulder_x, 0, shoulder_z))
    r_sh = Vector((-shoulder_x, 0, shoulder_z))
    l_hand = l_sh + Vector((s, 0, -c)) * arm_len
    r_hand = r_sh + Vector((-s, 0, -c)) * arm_len
    l_arm = cyl("Arm_L", l_sh, l_hand, 0.045, 0.038, 6, root)
    r_arm = cyl("Arm_R", r_sh, r_hand, 0.045, 0.038, 6, root)
    l_hand_m = box("Hand_L", tuple(l_hand + Vector((0.02, 0, -0.02))), (0.07, 0.045, 0.09), root)
    r_hand_m = box("Hand_R", tuple(r_hand + Vector((-0.02, 0, -0.02))), (0.07, 0.045, 0.09), root)

    # Legs slightly apart
    l_leg = cyl("Leg_L", (0.09, 0, 0.78), (0.11, 0, 0.18), 0.07, 0.055, 6, root)
    r_leg = cyl("Leg_R", (-0.09, 0, 0.78), (-0.11, 0, 0.18), 0.07, 0.055, 6, root)

    body_parts = [torso, pelvis, neck, l_arm, r_arm, l_hand_m, r_hand_m, l_leg, r_leg]
    for p in body_parts:
        assign(p, mats["black"])
    body = join_into(torso, body_parts[1:])
    body.name = "Body"
    body.modifiers.new("Collision", "COLLISION")
    body.collision.thickness_outer = 0.02
    return body, l_hand, r_hand


def build_coat(root, mats):
    # Open flared duster (no top cap) so the poncho can fall off the shoulders.
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=8,
        radius1=0.32, radius2=0.16, depth=1.22,
    )
    bm.faces.ensure_lookup_table()
    caps = [f for f in bm.faces if abs(f.normal.z) > 0.8]
    bmesh.ops.delete(bm, geom=caps, context="FACES")
    for v in bm.verts:
        v.co.y *= 0.58
        v.co.z += 0.70
    coat = mesh_from_bm(bm, "Coat", root)

    s = math.sin(math.radians(45))
    c = math.cos(math.radians(45))
    arm_len = 0.50
    l_sh = Vector((0.17, 0, 1.34))
    r_sh = Vector((-0.17, 0, 1.34))
    sl_l = cyl("Sleeve_L", l_sh, l_sh + Vector((s, 0, -c)) * arm_len, 0.062, 0.052, 6, root)
    sl_r = cyl("Sleeve_R", r_sh, r_sh + Vector((-s, 0, -c)) * arm_len, 0.062, 0.052, 6, root)
    for o in (coat, sl_l, sl_r):
        assign(o, mats["black"])
        for p in o.data.polygons:
            p.use_smooth = False
    coat = join_into(coat, [sl_l, sl_r])
    coat.name = "Coat"
    coat.modifiers.new("Collision", "COLLISION")
    coat.collision.thickness_outer = 0.015
    coat.collision.thickness_inner = 0.01
    return coat


def build_headgear(root, mats):
    head = box("Head", (0, 0.01, 1.62), (0.18, 0.20, 0.22), root)
    assign(head, mats["black"])

    scarf = cyl("Scarf", (0, 0.02, 1.52), (0, 0.04, 1.64), 0.12, 0.10, 8, root)
    assign(scarf, mats["scarf"])

    eye_l = box("Eye_L", (0.045, -0.10, 1.66), (0.035, 0.02, 0.028), root)
    eye_r = box("Eye_R", (-0.045, -0.10, 1.66), (0.035, 0.02, 0.028), root)
    pupil_l = box("Pupil_L", (0.045, -0.112, 1.66), (0.016, 0.012, 0.016), root)
    pupil_r = box("Pupil_R", (-0.045, -0.112, 1.66), (0.016, 0.012, 0.016), root)
    assign(eye_l, mats["sclera"])
    assign(eye_r, mats["sclera"])
    assign(pupil_l, mats["eye"])
    assign(pupil_r, mats["eye"])

    brim = disc("HatBrim", (0, 0, 1.76), 0.32, 0.03, 12, root)
    crown = cyl("HatCrown", (0, 0, 1.77), (0, 0, 1.92), 0.12, 0.11, 8, root)
    assign(brim, mats["hat"])
    assign(crown, mats["hat"])
    hat = join_into(brim, [crown])
    hat.name = "Hat"

    band = disc("CrownBand", (0, 0, 1.925), 0.13, 0.035, 8, root)
    assign(band, mats["metal"])
    spikes = []
    for i, x in enumerate((-0.075, 0.0, 0.075)):
        sp = cone(f"Spike_{i}", (x, 0, 1.93), 0.032, 0.16, root, segs=4)
        assign(sp, mats["metal"])
        spikes.append(sp)
    crown_metal = join_into(band, spikes)
    crown_metal.name = "HatCrownSpikes"

    face = join_into(head, [scarf, eye_l, eye_r, pupil_l, pupil_r])
    face.name = "Head"
    return face, hat, crown_metal


def build_boots(root, mats):
    boots = []
    for side, x in (("L", 0.11), ("R", -0.11)):
        boot = box(f"Boot_{side}", (x, 0.03, 0.10), (0.12, 0.22, 0.20), root)
        assign(boot, mats["boot"])
        heel = box(f"Heel_{side}", (x, 0.08, 0.03), (0.10, 0.10, 0.06), root)
        assign(heel, mats["boot"])
        spur = box(f"Spur_{side}", (x, 0.16, 0.05), (0.03, 0.10, 0.03), root)
        assign(spur, mats["spur"])
        rowel = disc(f"Rowel_{side}", (x, 0.22, 0.05), 0.035, 0.012, 6, root)
        assign(rowel, mats["spur"])
        b = join_into(boot, [heel, spur, rowel])
        b.name = f"Boot_{side}"
        boots.append(b)
    return boots


def build_poncho(root, pmat, fmat):
    nx, ny = 10, 12
    sx, sy = 1.00, 0.88
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=nx, y_segments=ny, size=1.0)
    for v in bm.verts:
        v.co.x *= sx * 0.5
        v.co.y *= sy * 0.5
        v.co.z = 0.0

    bm.verts.ensure_lookup_table()
    to_del = [v for v in bm.verts if (v.co.x ** 2 + v.co.y ** 2) < 0.05 ** 2]
    bmesh.ops.delete(bm, geom=to_del, context="VERTS")

    # Sawtooth fringe on front/back hems (same mesh, cloth-simmed together)
    bm.edges.ensure_lookup_table()
    bm.verts.ensure_lookup_table()
    hem = []
    y_lim = sy * 0.5 - 0.002
    for e in bm.edges:
        if abs(e.verts[0].co.y) > y_lim - 0.02 and abs(e.verts[1].co.y) > y_lim - 0.02:
            if e.verts[0].co.y * e.verts[1].co.y > 0:
                hem.append(e)
    geom = bmesh.ops.extrude_edge_only(bm, edges=hem)["geom"]
    extruded_verts = [g for g in geom if isinstance(g, bmesh.types.BMVert)]
    for i, v in enumerate(extruded_verts):
        drop = 0.10 if i % 2 == 0 else 0.055
        v.co.z -= drop

    uv_layer = bm.loops.layers.uv.new("UVMap")
    fringe_faces = []
    for face in bm.faces:
        zs = [loop.vert.co.z for loop in face.loops]
        is_fringe = min(zs) < -0.01
        if is_fringe:
            fringe_faces.append(face)
            face.material_index = 1
        for loop in face.loops:
            p = loop.vert.co
            if is_fringe:
                u = 0.25 if p.x < 0 else 0.75
                v = 0.95 if p.z > -0.02 else 0.05
                loop[uv_layer].uv = (u, v)
            else:
                u = (p.x / sx) + 0.5
                v = (p.y / sy) + 0.5
                loop[uv_layer].uv = (u, v)

    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((0, 0, 1.46)))

    poncho = mesh_from_bm(bm, "Poncho", root)
    poncho.data.materials.clear()
    poncho.data.materials.append(pmat)
    poncho.data.materials.append(fmat)
    for p in poncho.data.polygons:
        p.use_smooth = False

    vg = poncho.vertex_groups.new(name="PIN")
    pin_idxs = []
    for v in poncho.data.vertices:
        dist_xy = math.hypot(v.co.x, v.co.y)
        # Only the neck ring, not the whole shoulder sheet
        if dist_xy < 0.11 and abs(v.co.z - 1.46) < 0.04:
            pin_idxs.append(v.index)
    vg.add(pin_idxs, 1.0, "REPLACE")
    print("fringe faces", len(fringe_faces))
    return poncho, pin_idxs


def add_cloth(obj, pin_name="PIN"):
    cloth = obj.modifiers.new("Cloth", "CLOTH")
    s = cloth.settings
    s.quality = 8
    s.mass = 0.2
    s.air_damping = 1.0
    s.tension_stiffness = 8
    s.compression_stiffness = 8
    s.shear_stiffness = 3
    s.bending_stiffness = 0.25
    s.vertex_group_mass = pin_name
    s.pin_stiffness = 20
    s.use_pressure = False
    s.time_scale = 1.0
    cs = cloth.collision_settings
    cs.use_collision = True
    cs.distance_min = 0.018
    cs.self_distance_min = 0.01
    cs.collision_quality = 4
    cs.use_self_collision = False
    cache = cloth.point_cache
    cache.frame_start = 1
    cache.frame_end = 60
    return cloth


def setup_world():
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.48, 0.50, 0.32, 1.0)
        bg.inputs["Strength"].default_value = 0.55

    def lamp(name, typ, loc, energy, color=(1, 0.95, 0.85)):
        data = bpy.data.lights.new(name, typ)
        data.energy = energy
        data.color = color
        obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = loc
        return obj

    lamp("Key", "AREA", (2.2, -1.8, 3.2), 400)
    lamp("Fill", "AREA", (-2.5, -1.2, 2.0), 140, (0.7, 0.8, 1.0))
    lamp("Rim", "POINT", (0.2, 2.4, 2.2), 180, (1.0, 0.85, 0.55))

    cam_data = bpy.data.cameras.new("Camera")
    cam_data.lens = 45
    cam = bpy.data.objects.new("Camera", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (2.15, -3.55, 1.25)
    target = Vector((0.0, 0.0, 1.05))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in dir(bpy.types) else "BLENDER_EEVEE"
    # Fallback if enum missing
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 1024
    scene.render.filepath = os.path.join(OUT_DIR, "preview.png")
    scene.frame_start = 1
    scene.frame_end = 60
    scene.frame_set(1)
    scene.unit_settings.system = "METRIC"
    scene.gravity = (0.0, 0.0, -9.81)


def bake_cloth(obj, frames=60):
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = frames
    scene.frame_set(1)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    try:
        bpy.ops.ptcache.free_bake_all()
    except Exception as e:
        print("free_bake", e)
    try:
        bpy.ops.ptcache.bake_all(bake=True)
        print("ptcache bake_all ok")
    except Exception as e:
        print("bake_all failed", e, "falling back to frame_set")
        for f in range(1, frames + 1):
            scene.frame_set(f)
            bpy.context.view_layer.update()
    scene.frame_set(frames)
    bpy.context.view_layer.update()
    print(f"cloth at frame {scene.frame_current}")


def main():
    clear_scene()
    setup_world()
    mats = {
        "black": mat("M_Black", COL_BLACK, 0.92),
        "hat": mat("M_Hat", COL_HAT, 0.88),
        "metal": mat("M_Metal", COL_METAL, 0.35, metallic=0.85),
        "boot": mat("M_Boot", COL_BOOT, 0.9),
        "spur": mat("M_Spur", COL_SPUR, 0.45, metallic=0.55),
        "scarf": mat("M_Scarf", COL_SCARF, 0.8),
        "eye": mat("M_Eye", COL_EYE, 0.4),
        "sclera": mat("M_Sclera", COL_SCLERA, 0.5),
    }
    root = bpy.data.objects.new("Gunslinger", None)
    bpy.context.collection.objects.link(root)

    body, _lh, _rh = build_body(root, mats)
    coat = build_coat(root, mats)
    head, hat, spikes = build_headgear(root, mats)
    boots = build_boots(root, mats)

    tex_path = os.path.join(OUT_DIR, "poncho_albedo.png")
    fringe_path = os.path.join(OUT_DIR, "poncho_fringe.png")
    pimg = make_poncho_image(tex_path)
    fimg = make_fringe_image(fringe_path)
    poncho, pin_idxs = build_poncho(root, poncho_mat(pimg), fringe_mat(fimg))
    add_cloth(poncho)
    bake_cloth(poncho, 60)

    print("built", [o.name for o in bpy.data.objects])
    print("poncho pin verts", len(pin_idxs))
    print("body", body.name, "coat", coat.name, "hat", hat.name, "spikes", spikes.name)
    print("boots", [b.name for b in boots])
    # report poncho z after sim
    zs = [(poncho.matrix_world @ v.co).z for v in poncho.data.vertices]
    # evaluated
    dg = bpy.context.evaluated_depsgraph_get()
    ev = poncho.evaluated_get(dg)
    ezs = [v.co.z for v in ev.data.vertices]
    print("poncho rest z", min(zs), max(zs), "eval z", min(ezs), max(ezs))


main()
print("BUILD_OK")
