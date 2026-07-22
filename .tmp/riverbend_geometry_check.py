import sys

import bpy
from mathutils import Vector


source_path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source_path)


def world_bounds(objects):
    corners = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    minimum = Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)))
    maximum = Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)))
    return minimum, maximum


mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
for prefix in ("IslandGround", "CliffSections", "Riverbed", "WaterPreview", "FishingSpotMarker", "SpawnMarker"):
    matches = [obj for obj in mesh_objects if obj.name.startswith(prefix)]
    if not matches:
        continue
    minimum, maximum = world_bounds(matches)
    print(
        "GROUP",
        prefix,
        "COUNT",
        len(matches),
        "MIN",
        tuple(round(v, 3) for v in minimum),
        "MAX",
        tuple(round(v, 3) for v in maximum),
    )

for obj in mesh_objects:
    if obj.name.startswith("SpawnMarker") or obj.name.startswith("FishingSpotMarker"):
        minimum, maximum = world_bounds([obj])
        print(
            "MARKER",
            obj.name,
            "CENTER",
            tuple(round(v, 3) for v in ((minimum + maximum) * 0.5)),
            "SIZE",
            tuple(round(v, 3) for v in (maximum - minimum)),
        )
