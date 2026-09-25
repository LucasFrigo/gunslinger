"""Vend MSC_Ace into assets/models/props/.

Builds a thin poker card whose +Y face reads as the ace of spades, saves the
authoring .blend, and exports a Y-up glTF 2.0 binary for Godot. The same attach
that points the cigarette filter at the player shows this face.

Run headless:
    blender -b --python dev/vend_ace_blender.py

Without Blender, `python dev/write_prop_glb.py` writes the same GLB.
"""
import os
import sys

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "models", "props")
OUT_BLEND = os.path.join(OUT_DIR, "msc_ace.blend")
OUT_GLB = os.path.join(OUT_DIR, "msc_ace.glb")
OBJ_NAME = "MSC_Ace"
WIDTH = 0.0635
HEIGHT = 0.0016
DEPTH = 0.0889


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
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Metallic"].default_value = 0.0
    mat.diffuse_color = color
    return mat


def main():
    import bpy

    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.0))
    obj = bpy.context.active_object
    obj.name = OBJ_NAME
    obj.data.name = OBJ_NAME
    obj.scale = (WIDTH, HEIGHT, DEPTH)
    apply_transform(obj)

    face = make_material("ace_face", (0.95, 0.92, 0.84, 1.0))
    back = make_material("ace_back", (0.45, 0.08, 0.1, 1.0))
    ink = make_material("ace_ink", (0.05, 0.05, 0.06, 1.0))
    obj.data.materials.clear()
    obj.data.materials.append(face)
    obj.data.materials.append(back)
    for poly in obj.data.polygons:
        poly.use_smooth = False
        if poly.normal.y > 0.5:
            poly.material_index = 0
        elif poly.normal.y < -0.5:
            poly.material_index = 1

    # Flat spade + corner A on the +Y face, slightly proud so it reads.
    bpy.ops.mesh.primitive_circle_add(vertices=3, radius=0.018, fill_type="NGON", location=(0.0, HEIGHT * 0.5 + 0.0004, 0.004))
    spade = bpy.context.active_object
    spade.name = "MSC_Ace_Spade"
    spade.rotation_euler = (1.57079632679, 0.0, 0.0)
    apply_transform(spade)
    # Stem
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, HEIGHT * 0.5 + 0.0004, -0.018))
    stem = bpy.context.active_object
    stem.scale = (0.004, 0.0003, 0.016)
    apply_transform(stem)
    bpy.ops.object.select_all(action="DESELECT")
    spade.select_set(True)
    stem.select_set(True)
    bpy.context.view_layer.objects.active = spade
    bpy.ops.object.join()
    mark = bpy.context.active_object
    mark.name = "MSC_Ace_Pip"
    mark.data.materials.clear()
    mark.data.materials.append(ink)

    # Parent the pip to the card so one glTF node tree exports.
    mark.parent = obj

    purge_unused()
    print("vend: %s dims=%s" % (obj.name, tuple(round(d, 4) for d in obj.dimensions)))
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
        from write_prop_glb import write_ace
        os.makedirs(OUT_DIR, exist_ok=True)
        write_ace(OUT_GLB)
        print("vend: blender not in this interpreter, wrote %s via write_prop_glb" % OUT_GLB)
        sys.exit(0)
    main()
