# Riverbend Island Voxel No-Water Blender source generator
# Run in Blender 4.2+ from this package directory:
# blender --background --python Riverbend_Island_Voxel_NoWater_Build.py
import bpy, os
BASE = os.path.dirname(os.path.abspath(__file__))
GLB = os.path.join(BASE, 'Riverbend_Island_Voxel_NoWater.glb')
OUT = os.path.join(BASE, 'Riverbend_Island_Voxel_NoWater.blend')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        for poly in obj.data.polygons:
            poly.use_smooth = False
        obj.data.update()
    if obj.name.startswith('FishingSpotMarker_') or obj.name in {'SpawnMarker', 'Riverbend_Island_ROOT_PivotMarker'}:
        obj.display_type = 'WIRE'
        obj.hide_render = True
root = bpy.data.objects.get('Riverbend_Island_ROOT')
if root:
    root.location = (0, 0, 0)
    root.rotation_euler = (0, 0, 0)
    root.scale = (1, 1, 1)
bpy.context.scene.unit_settings.system = 'NONE'
bpy.context.scene.unit_settings.scale_length = 1.0
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=OUT, compress=True)
print('Saved', OUT)
