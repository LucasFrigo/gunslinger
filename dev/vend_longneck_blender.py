"""Vend MSC_Longneck from the Blender sandbox into assets/models/props/.

Opens the authoring .blend, renames the object, bakes its transform, drops the
origin to the centre of the base, scales it to a real longneck (TARGET_HEIGHT),
assigns a green glass material (reads against the orange desert at range), then saves the cleaned .blend and exports a
Y-up glTF 2.0 binary for Godot. The practice-hub bottle stands on its origin.

Run headless:
    blender -b --python dev/vend_longneck_blender.py
"""
import os

import bpy
from mathutils import Vector

SRC_BLEND = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "blender-mcp-connection", "MSC_Longneck.blend")
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "models", "props")
OUT_BLEND = os.path.join(OUT_DIR, "msc_longneck.blend")
OUT_GLB = os.path.join(OUT_DIR, "msc_longneck.glb")

OBJ_NAME = "MSC_Longneck"
TARGET_HEIGHT = 0.23
GLASS_COLOR = (0.12, 0.5, 0.2, 1.0)


def apply_transform(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def purge_unused():
    for block in (bpy.data.materials, bpy.data.meshes, bpy.data.images):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def glass_material():
    mat = bpy.data.materials.new("glass_green")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = GLASS_COLOR
    bsdf.inputs["Roughness"].default_value = 0.12
    bsdf.inputs["Metallic"].default_value = 0.0
    mat.diffuse_color = GLASS_COLOR
    return mat


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=SRC_BLEND)

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError("expected one mesh in %s, found %s" % (SRC_BLEND, [o.name for o in meshes]))
    obj = meshes[0]
    obj.name = OBJ_NAME
    obj.data.name = OBJ_NAME
    apply_transform(obj)

    verts = [v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in verts), min(v.y for v in verts), min(v.z for v in verts)))
    hi = Vector((max(v.x for v in verts), max(v.y for v in verts), max(v.z for v in verts)))
    base = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z))
    factor = TARGET_HEIGHT / (hi.z - lo.z)
    for v in obj.data.vertices:
        v.co = (v.co - base) * factor
    obj.location = (0.0, 0.0, 0.0)
    obj.data.update()
    bpy.context.view_layer.update()

    obj.data.materials.clear()
    obj.data.materials.append(glass_material())
    for poly in obj.data.polygons:
        poly.use_smooth = True

    purge_unused()
    print("vend: %s dims=%s materials=%s" % (
        obj.name, tuple(round(d, 4) for d in obj.dimensions), [m.name for m in obj.data.materials]))

    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB,
        export_format="GLB",
        export_yup=True,
        use_selection=False,
        export_apply=True,
    )
    print("vend: wrote %s and %s" % (OUT_BLEND, OUT_GLB))


main()
