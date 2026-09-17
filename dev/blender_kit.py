"""Shared low-poly Blender primitives for headless / MCP build scripts.

Import from sibling scripts with::

    import os, sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from blender_kit import box, cyl, disc, cone, mat, assign, join_into, ...
"""
from __future__ import annotations

import bpy
import bmesh
from mathutils import Vector


def clear_scene() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def purge_unused() -> None:
    for block in (bpy.data.materials, bpy.data.meshes, bpy.data.images):
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
    """Axis-aligned box. ``size`` is full extents (x, y, z); ``loc`` is centre."""
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
    return cyl(
        name,
        (loc[0], loc[1], loc[2] - height * 0.5),
        (loc[0], loc[1], loc[2] + height * 0.5),
        radius, radius, segs, parent,
    )


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


def empty(name, parent=None):
    obj = bpy.data.objects.new(name, None)
    return link(obj, parent)


def apply_scale(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


def convcol(name, loc, size, parent=None):
    """Invisible convex-collision proxy. Godot suffix ``-convcolonly``."""
    obj = box(f"{name}-convcolonly", loc, size, parent)
    obj.hide_render = True
    obj.display_type = "WIRE"
    return obj


def convcol_ramp(name, parent, *, x_min, x_max, y_top, y_bottom, z_top, z_bottom=0.0):
    """Invisible wedge ramp. Slopes down along +Y from ``y_top``/``z_top`` to ``y_bottom``/``z_bottom``.

    Godot ``CharacterBody3D`` default floor angle is 45° — keep run ≥ rise.
    """
    bm = bmesh.new()
    coords = [
        Vector((x_min, y_top, z_bottom)),
        Vector((x_max, y_top, z_bottom)),
        Vector((x_max, y_bottom, z_bottom)),
        Vector((x_min, y_bottom, z_bottom)),
        Vector((x_min, y_top, z_top)),
        Vector((x_max, y_top, z_top)),
    ]
    verts = [bm.verts.new(c) for c in coords]
    bm.verts.ensure_lookup_table()
    faces = (
        (0, 1, 2, 3),  # bottom
        (4, 5, 1, 0),  # back (under step lip)
        (3, 2, 5, 4),  # slope (walkable)
        (0, 3, 4),  # -X end
        (1, 5, 2),  # +X end
    )
    for f in faces:
        bm.faces.new([verts[i] for i in f])
    obj = mesh_from_bm(bm, f"{name}-convcolonly", parent)
    obj.hide_render = True
    obj.display_type = "WIRE"
    return obj


def flat_shade(obj):
    for p in obj.data.polygons:
        p.use_smooth = False


def count_tris(obj) -> int:
    me = obj.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)
