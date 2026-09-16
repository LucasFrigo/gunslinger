"""Vend MSC_Cigarette from the Blender sandbox into assets/models/props/.

Opens the authoring .blend, renames the object, applies scale and shrinks it to
1/10 (the source is authored 10x VR size), purges unused datablocks, then saves
the cleaned .blend and exports a Y-up glTF 2.0 binary for Godot.

Run headless:
    blender -b --python dev/vend_cigarette_blender.py
"""
import os

import bpy

SRC_BLEND = r"C:\Users\lukeg\Projetos\blender-mcp-connection\MSC_Cigarette.blend"
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "models", "props")
OUT_BLEND = os.path.join(OUT_DIR, "msc_cigarette.blend")
OUT_GLB = os.path.join(OUT_DIR, "msc_cigarette.glb")

OBJ_NAME = "MSC_Cigarette"
VR_SHRINK = 0.1


def apply_transform(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


def purge_unused():
    for block in (bpy.data.materials, bpy.data.meshes, bpy.data.images):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


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
    obj.scale = (VR_SHRINK, VR_SHRINK, VR_SHRINK)
    apply_transform(obj)

    purge_unused()
    print("vend: %s dims=%s scale=%s materials=%s" % (
        obj.name, tuple(obj.dimensions), tuple(obj.scale), [m.name for m in obj.data.materials]))

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
