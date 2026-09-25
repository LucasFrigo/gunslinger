"""Vend MSC_Coin into assets/models/props/.

Builds a thin two-face coin (heads / tails) at real silver-dollar scale, saves
the authoring .blend, and exports a Y-up glTF 2.0 binary for Godot. Face
normal is local +Y so the held pose can lay it on the palm.

Run headless:
    blender -b --python dev/vend_coin_blender.py

Without Blender, `python dev/write_prop_glb.py` writes the same GLB.
"""
import os
import sys

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "models", "props")
OUT_BLEND = os.path.join(OUT_DIR, "msc_coin.blend")
OUT_GLB = os.path.join(OUT_DIR, "msc_coin.glb")
OBJ_NAME = "MSC_Coin"
RADIUS = 0.022
HEIGHT = 0.0024


def apply_transform(obj):
    import bpy
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def purge_unused():
    import bpy
    for block in (bpy.data.materials, bpy.data.meshes, bpy.data.images):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def make_material(name, color):
    import bpy
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = 0.85
    bsdf.inputs["Roughness"].default_value = 0.28
    mat.diffuse_color = color
    return mat


def main():
    import bpy
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=24, radius=RADIUS, depth=HEIGHT, location=(0.0, 0.0, 0.0))
    obj = bpy.context.active_object
    obj.name = OBJ_NAME
    obj.data.name = OBJ_NAME
    # Blender Z-up cylinder → rotate so the face normal is +Y for Godot Y-up export.
    obj.rotation_euler = (1.57079632679, 0.0, 0.0)
    apply_transform(obj)

    heads = make_material("heads", (0.83, 0.66, 0.22, 1.0))
    tails = make_material("tails", (0.75, 0.75, 0.72, 1.0))
    rim = make_material("rim", (0.55, 0.44, 0.18, 1.0))
    obj.data.materials.clear()
    obj.data.materials.append(heads)
    obj.data.materials.append(tails)
    obj.data.materials.append(rim)
    for poly in obj.data.polygons:
        poly.use_smooth = True
        n = poly.normal
        if n.y > 0.5:
            poly.material_index = 0
        elif n.y < -0.5:
            poly.material_index = 1
        else:
            poly.material_index = 2

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


if __name__ == "__main__":
    try:
        import bpy  # noqa: F401
    except ImportError:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from write_prop_glb import write_coin
        os.makedirs(OUT_DIR, exist_ok=True)
        write_coin(OUT_GLB)
        print("vend: blender not in this interpreter, wrote %s via write_prop_glb" % OUT_GLB)
        sys.exit(0)
    main()
