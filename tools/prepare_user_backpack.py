from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Vector


SOURCE = Path(r"C:\Users\Andrew\Downloads\Backpack_New.glb")
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "backpack_selected"
OUTPUT.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))

all_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
backpack_meshes = [
    obj
    for obj in all_meshes
    if "AWNING" not in obj.name.upper() and "ROOF" not in obj.name.upper()
]

for obj in all_meshes:
    if obj not in backpack_meshes:
        bpy.data.objects.remove(obj, do_unlink=True)

# Preserve world placement while removing the source's assembly hierarchy.
for obj in backpack_meshes:
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world

bpy.ops.object.select_all(action="DESELECT")
for obj in backpack_meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = backpack_meshes[0]
bpy.ops.object.join()

backpack = bpy.context.active_object
backpack.name = "FishingBackpack"

# Put the export pivot on the player-contact plane at the visual center.
points = [backpack.matrix_world @ Vector(corner) for corner in backpack.bound_box]
minimum = Vector(tuple(min(point[index] for point in points) for index in range(3)))
maximum = Vector(tuple(max(point[index] for point in points) for index in range(3)))
bpy.context.scene.cursor.location = (0.0, minimum.y, (minimum.z + maximum.z) * 0.5)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR", center="MEDIAN")

backpack["front_contact_axis"] = "-Y"
backpack["outer_face_axis"] = "+Y"
backpack["target_width_studs"] = 2.8
backpack["target_height_studs"] = 2.6

bpy.ops.object.select_all(action="DESELECT")
backpack.select_set(True)
bpy.context.view_layer.objects.active = backpack
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT / "Backpack_Optimized.glb"),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_yup=True,
)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "Backpack_Optimized.blend"))

backpack.data.calc_loop_triangles()
print(f"Optimized objects: 1")
print(f"Materials: {len(backpack.data.materials)}")
print(f"Vertices: {len(backpack.data.vertices)}")
print(f"Triangles: {len(backpack.data.loop_triangles)}")
