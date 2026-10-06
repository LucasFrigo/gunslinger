"""Cut mannequin fingertips into a thumb and four fingers, two bones each.

Both hands get the same local layout. Bone +X points out the back of the hand
so a positive local-Z rotation curls toward the palm. Poses are glTF actions:

Open, Pistol, PistolTrigger, Bottle, Pinch, Fist.

Run:
    & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" -b --python dev/rig_dummy_fingers.py
"""
from __future__ import annotations

import math
import os

import bpy
import bmesh
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BLEND = os.path.join(ROOT, "assets", "models", "characters", "dummy.blend")
GLB = os.path.join(ROOT, "assets", "models", "characters", "dummy.glb")

# The palm stump, in the hand bone's space, ends near local Y = 0.05 and is
# about 3 cm thick (X) by 7.5 cm wide (Z). -Z is the index side.
PALM_CUT = 0.042
SEG1 = 0.036
SEG2 = 0.032
# Stump at the cut (hand local): X about -0.019..0.010, Z about -0.040..0.035.
FINGER_HX = 0.0142
FINGER_HZ = 0.0088
FINGERS = (
    ("Pinky", 0.025),
    ("Ring", 0.0065),
    ("Middle", -0.012),
    ("Index", -0.031),
)
POSES = ("Open", "Pistol", "PistolTrigger", "Bottle", "Pinch", "Fist")

# Curl degrees, local Z, bone 1 then bone 2. Positive curls into the palm.
CURL = {
    "Open": {},
    "Pistol": {
        "Index": (8.0, 6.0),
        "Middle": (68.0, 80.0),
        "Ring": (70.0, 82.0),
        "Pinky": (72.0, 84.0),
        "Thumb": (42.0, 38.0),
    },
    "PistolTrigger": {
        "Index": (48.0, 58.0),
        "Middle": (68.0, 80.0),
        "Ring": (70.0, 82.0),
        "Pinky": (72.0, 84.0),
        "Thumb": (42.0, 38.0),
    },
    "Bottle": {
        "Index": (42.0, 50.0),
        "Middle": (46.0, 54.0),
        "Ring": (48.0, 56.0),
        "Pinky": (50.0, 58.0),
        "Thumb": (36.0, 32.0),
    },
    "Pinch": {
        "Index": (28.0, 34.0),
        "Middle": (72.0, 84.0),
        "Ring": (74.0, 86.0),
        "Pinky": (76.0, 88.0),
        "Thumb": (34.0, 30.0),
    },
    "Fist": {
        "Index": (74.0, 86.0),
        "Middle": (76.0, 88.0),
        "Ring": (78.0, 90.0),
        "Pinky": (80.0, 92.0),
        "Thumb": (48.0, 44.0),
    },
}


def hand_matrix(arm, bone_name):
    return arm.matrix_world @ arm.data.bones[bone_name].matrix_local


def dominant_hand(obj, vert, groups):
    best = None
    best_w = 0.0
    for g in vert.groups:
        name = groups.get(g.group)
        if name in ("Hand.L", "Hand.R") and g.weight > best_w:
            best = name
            best_w = g.weight
    if best_w < 0.5:
        return None
    return best


def cut_fingertips(obj, arm):
    groups = {g.index: g.name for g in obj.vertex_groups}
    world_inv = {name: hand_matrix(arm, name).inverted() for name in ("Hand.L", "Hand.R")}
    owner_of = {}
    local_y = {}
    for vert in obj.data.vertices:
        owner = dominant_hand(obj, vert, groups)
        owner_of[vert.index] = owner
        if owner is None:
            continue
        world = obj.matrix_world @ vert.co
        local_y[vert.index] = (world_inv[owner] @ world).y
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    smooth = any(f.smooth for f in bm.faces)
    drop = []
    for face in bm.faces:
        owners = []
        locals_y = []
        for corner in face.verts:
            owner = owner_of.get(corner.index)
            if owner is None:
                owners.append(None)
                continue
            owners.append(owner)
            locals_y.append(local_y[corner.index])
        if not locals_y or any(o is None for o in owners):
            continue
        if len(set(owners)) != 1:
            continue
        if sum(locals_y) / len(locals_y) > PALM_CUT:
            drop.append(face)
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    boundary = [e for e in bm.edges if e.is_boundary]
    if boundary:
        bmesh.ops.holes_fill(bm, edges=boundary, sides=12)
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.object.mode_set(mode="OBJECT")
    print(f"cut {len(drop)} fingertip faces, smooth={smooth}")
    return smooth


def aim_x(eb, hint: Vector) -> None:
    along = eb.vector.normalized()
    hint = hint - along * hint.dot(along)
    if hint.length < 1e-8:
        raise RuntimeError(f"{eb.name} has no roll perpendicular to the back of the hand")
    hint = hint.normalized()
    best_dot = -2.0
    best_roll = eb.roll
    for step in range(72):
        eb.roll = math.radians(step * 5.0)
        dot = eb.x_axis.dot(hint)
        if dot > best_dot:
            best_dot = dot
            best_roll = eb.roll
    eb.roll = best_roll
    if best_dot < 0.95:
        raise RuntimeError(f"{eb.name} roll only reached {best_dot:.3f}")


def add_bone(arm_obj, name, parent_name, head_w: Vector, tail_w: Vector, x_hint: Vector):
    arm = arm_obj.data
    inv = arm_obj.matrix_world.inverted()
    eb = arm.edit_bones.new(name)
    parent = arm.edit_bones[parent_name]
    eb.parent = parent
    eb.use_connect = False
    eb.use_deform = True
    eb.head = inv @ head_w
    eb.tail = inv @ tail_w
    aim_x(eb, x_hint)
    return eb


def build_bones(arm):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    created = []
    for suffix, palm_sign in (("L", -1.0), ("R", 1.0)):
        bone = arm.data.bones[f"Hand.{suffix}"]
        m = hand_matrix(arm, f"Hand.{suffix}")
        # Edit-mode bones are not the same object; use the rest matrix from data.
        back = (m.col[0].xyz * (-1.0 if suffix == "R" else 1.0)).normalized()
        along = m.col[1].xyz.normalized()
        across = m.col[2].xyz.normalized()
        palm = -back

        def at(x, y, z):
            return m @ Vector((x, y, z))

        parent = f"Hand.{suffix}"
        # Match the fingertip stump, which is thicker on the back than the palm.
        x_center = -0.0045 * palm_sign
        for fname, z_off in FINGERS:
            h1 = at(x_center, PALM_CUT, z_off)
            h2 = h1 + along * SEG1
            tip = h2 + along * SEG2
            n1 = f"{fname}1.{suffix}"
            n2 = f"{fname}2.{suffix}"
            add_bone(arm, n1, parent, h1, h2, back)
            add_bone(arm, n2, n1, h2, tip, back)
            created.append((n1, n2, h1, h2, tip, back, across))
        # Thumb rides the index edge: mostly forward, a little out, a little proud of the palm.
        thumb_dir = (along * 0.90 - across * 0.38 + palm * 0.18).normalized()
        t1 = at(x_center + palm_sign * 0.006, 0.008, -0.034)
        t2 = t1 + thumb_dir * 0.028
        t3 = t2 + thumb_dir * 0.022
        add_bone(arm, f"Thumb1.{suffix}", parent, t1, t2, back)
        add_bone(arm, f"Thumb2.{suffix}", f"Thumb1.{suffix}", t2, t3, back)
        created.append((f"Thumb1.{suffix}", f"Thumb2.{suffix}", t1, t2, t3, back, thumb_dir.cross(back).normalized()))
    bpy.ops.object.mode_set(mode="OBJECT")
    print(f"bones {len(created) * 1} chains")
    return created


def add_box(bm, head, tail, x_axis, z_axis, hx, hz):
    y_axis = tail - head
    length = y_axis.length
    if length < 1e-6:
        return []
    y_axis /= length
    x_axis = x_axis.normalized()
    z_axis = z_axis.normalized()
    verts = []
    for t in (0.0, 1.0):
        center = head.lerp(tail, t)
        shrink = 1.0 if t < 0.5 else 0.86
        for sx in (-1.0, 1.0):
            for sz in (-1.0, 1.0):
                co = center + x_axis * (sx * hx * shrink) + z_axis * (sz * hz * shrink)
                verts.append(bm.verts.new(co))
    bm.verts.ensure_lookup_table()
    # 0-3 at head, 4-7 at tail. Order: (-x,-z), (+x,-z), (-x,+z), (+x,+z)
    faces = [
        (0, 2, 3, 1),
        (4, 5, 7, 6),
        (0, 1, 5, 4),
        (1, 3, 7, 5),
        (3, 2, 6, 7),
        (2, 0, 4, 6),
    ]
    made = []
    for loop in faces:
        made.append(bm.faces.new([verts[i] for i in loop]))
    return verts


def build_mesh(reto, arm, smooth):
    me = bpy.data.meshes.new("Fingers")
    bm = bmesh.new()
    spans = []
    for suffix in ("L", "R"):
        for fname, z_off in list(FINGERS) + [("Thumb", 0.0)]:
            for seg, hx, hz in ((1, FINGER_HX, FINGER_HZ), (2, FINGER_HX * 0.86, FINGER_HZ * 0.86)):
                bone = arm.data.bones[f"{fname}{seg}.{suffix}"]
                head = arm.matrix_world @ bone.head_local
                tail = arm.matrix_world @ bone.tail_local
                # Bone.z_axis is not the bone's local Z on this Blender. The
                # rest matrix columns are. Using z_axis flattened every finger
                # into a spike along the bone.
                axes = bone.matrix_local.to_3x3()
                world = arm.matrix_world.to_3x3()
                x_axis = (world @ axes.col[0]).normalized()
                z_axis = (world @ axes.col[2]).normalized()
                before = len(bm.verts)
                add_box(bm, head, tail, x_axis, z_axis, hx, hz if fname != "Thumb" else hz * 1.15)
                after = len(bm.verts)
                spans.append((f"{fname}{seg}.{suffix}", before, after))
    for face in bm.faces:
        face.smooth = smooth
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(me)
    bm.free()
    finger_obj = bpy.data.objects.new("Fingers", me)
    bpy.context.collection.objects.link(finger_obj)
    finger_obj.parent = reto.parent
    finger_obj.matrix_world = reto.matrix_world
    # Boxes were built in world space; convert into the object's local space.
    inv = finger_obj.matrix_world.inverted()
    for v in me.vertices:
        v.co = inv @ v.co
    mat = reto.data.materials[0]
    me.materials.append(mat)
    for name, start, end in spans:
        vg = finger_obj.vertex_groups.new(name=name)
        vg.add(list(range(start, end)), 1.0, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    finger_obj.select_set(True)
    reto.select_set(True)
    bpy.context.view_layer.objects.active = reto
    bpy.ops.object.join()
    print(f"joined finger verts groups={len(spans)}")


def key_poses(arm):
    if arm.animation_data is None:
        arm.animation_data_create()
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    actions = []
    for pose_name in POSES:
        action = bpy.data.actions.new(pose_name)
        arm.animation_data.action = action
        if hasattr(arm.animation_data, "action_slot"):
            slot = action.slots.new(id_type="OBJECT", name="Armature") if hasattr(action, "slots") else None
            if slot is not None:
                arm.animation_data.action_slot = slot
        curls = CURL[pose_name]
        for pb in arm.pose.bones:
            if pb.bone.name[:1] not in "TIRMP" and not any(pb.bone.name.startswith(p) for p in ("Thumb", "Index", "Middle", "Ring", "Pinky")):
                continue
            if not any(pb.bone.name.startswith(p) for p in ("Thumb", "Index", "Middle", "Ring", "Pinky")):
                continue
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0.0, 0.0, 0.0)
            fname = pb.bone.name.split("1")[0].split("2")[0]
            seg = 1 if pb.bone.name.split(".")[0].endswith("1") else 2
            pair = curls.get(fname, (0.0, 0.0))
            pb.rotation_euler.z = math.radians(pair[seg - 1])
            pb.keyframe_insert(data_path="rotation_euler", frame=1)
        action.use_fake_user = True
        actions.append(action)
        track = arm.animation_data.nla_tracks.new()
        track.name = pose_name
        strip = track.strips.new(pose_name, 1, action)
        strip.action_slot = action.slots[0]
        # Stacked unmuted strips all evaluate at once and splay the viewport.
        track.mute = True
    if hasattr(arm.animation_data, "use_nla"):
        arm.animation_data.use_nla = False
    arm.data.pose_position = "POSE"
    # Prove a fist curl moves the index tip toward the palm, then clear.
    arm.animation_data.action = bpy.data.actions["Fist"]
    bpy.context.view_layer.update()
    for suffix, palm_local in (("L", Vector((-1.0, 0.0, 0.0))), ("R", Vector((1.0, 0.0, 0.0)))):
        rest = arm.data.bones[f"Index2.{suffix}"].tail_local
        posed = arm.pose.bones[f"Index2.{suffix}"].tail
        delta = posed - rest
        palm = (arm.data.bones[f"Hand.{suffix}"].matrix_local.to_3x3() @ palm_local).normalized()
        dot = delta.normalized().dot(palm) if delta.length > 1e-6 else -1.0
        print(f"curl {suffix} dot={dot:.3f} delta={tuple(round(c, 4) for c in delta)}")
        if dot < 0.2:
            raise RuntimeError(f"Index2.{suffix} curled away from the palm ({dot:.3f})")
    open_action = bpy.data.actions["Open"]
    arm.animation_data.action = open_action
    if open_action.slots:
        arm.animation_data.action_slot = open_action.slots[0]
    bpy.ops.pose.transforms_clear()
    # POSE, not REST: REST makes bone.matrix ignore the action on export.
    arm.data.pose_position = "POSE"
    print("actions", [a.name for a in actions])


def export():
    bpy.ops.export_scene.gltf(
        filepath=GLB,
        export_format="GLB",
        export_yup=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_skins=True,
        export_morph=False,
        export_apply=False,
        use_selection=False,
    )
    bpy.ops.wm.save_mainfile(filepath=BLEND)
    print("exported", GLB)


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    reto = bpy.data.objects["Reto"]
    if arm.data.bones.get("Index1.R") is not None:
        raise RuntimeError("finger bones already exist; restore dummy.blend before re-running")
    smooth = cut_fingertips(reto, arm)
    build_bones(arm)
    reto = bpy.data.objects["Reto"]
    build_mesh(reto, arm, smooth)
    key_poses(arm)
    export()


if __name__ == "__main__":
    main()
