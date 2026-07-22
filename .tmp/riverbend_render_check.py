import math
import os
import sys

import bpy
from mathutils import Vector


def look_at(camera, point):
    camera.rotation_euler = (Vector(point) - camera.location).to_track_quat("-Z", "Y").to_euler()


args = sys.argv[sys.argv.index("--") + 1 :]
source_path, output_dir = args
os.makedirs(output_dir, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source_path)

for obj in bpy.context.scene.objects:
    if obj.type != "MESH":
        continue
    if obj.name.startswith("FishingSpotMarker") or obj.name.startswith("SpawnMarker"):
        obj.hide_render = True

mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and not obj.hide_render]
corners = [obj.matrix_world @ Vector(corner) for obj in mesh_objects for corner in obj.bound_box]
minimum = Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)))
maximum = Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)))
center = (minimum + maximum) * 0.5
extent = maximum - minimum

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1200
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
if scene.world is None:
    scene.world = bpy.data.worlds.new("VerificationWorld")
scene.world.color = (0.12, 0.24, 0.36)

camera_data = bpy.data.cameras.new("VerificationCamera")
camera = bpy.data.objects.new("VerificationCamera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"
camera_data.ortho_scale = max(extent.x, extent.y) * 1.25

sun_data = bpy.data.lights.new("VerificationSun", type="SUN")
sun_data.energy = 3.0
sun = bpy.data.objects.new("VerificationSun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(28), math.radians(-18), math.radians(32))

area_data = bpy.data.lights.new("VerificationFill", type="AREA")
area_data.energy = 1400
area_data.shape = "DISK"
area_data.size = max(extent.x, extent.y)
area = bpy.data.objects.new("VerificationFill", area_data)
scene.collection.objects.link(area)
area.location = center + Vector((-extent.x * 0.3, -extent.y * 0.2, extent.z * 2.4))
look_at(area, center)

camera.location = center + Vector((extent.x * 0.95, -extent.y * 1.05, extent.z * 3.2))
look_at(camera, center + Vector((0, 0, extent.z * 0.05)))
scene.render.filepath = os.path.join(output_dir, "riverbend_isometric_check.png")
bpy.ops.render.render(write_still=True)

camera.location = center + Vector((0, 0, max(extent.x, extent.y) * 1.4))
camera_data.ortho_scale = max(extent.x, extent.y) * 1.12
look_at(camera, center)
scene.render.filepath = os.path.join(output_dir, "riverbend_top_check.png")
bpy.ops.render.render(write_still=True)

print(
    "RIVERBEND_CHECK",
    {
        "mesh_count": len(mesh_objects),
        "bounds_min": tuple(round(v, 3) for v in minimum),
        "bounds_max": tuple(round(v, 3) for v in maximum),
        "dimensions": tuple(round(v, 3) for v in extent),
    },
)
