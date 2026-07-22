# Riverbend Island Voxel source builder
# Run with Blender 5.x: blender --background --python Riverbend_Island_Voxel_Build.py
import bpy, os
from mathutils import Vector
BASE=os.path.dirname(os.path.abspath(__file__))
GLB=os.path.join(BASE,'Riverbend_Island_Voxel.glb')
OUT=os.path.join(BASE,'Riverbend_Island_Voxel.blend')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
# Blender imports glTF Y-up into a Z-up scene. Apply all transforms.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
# Flat shading and hard edges on all visible mesh objects.
for obj in bpy.context.scene.objects:
    if obj.type=='MESH':
        for poly in obj.data.polygons: poly.use_smooth=False
# Ensure the root is an Empty at exact origin and parent any top-level group nodes.
root=bpy.data.objects.get('Riverbend_Island_ROOT')
if root:
    root.location=(0,0,0); root.rotation_euler=(0,0,0); root.scale=(1,1,1)
# Mark developer-only markers as wire display and non-rendering while preserving them.
for obj in bpy.context.scene.objects:
    if obj.name.startswith('FishingSpotMarker_') or obj.name=='SpawnMarker' or obj.name.endswith('PivotMarker'):
        obj.display_type='WIRE'; obj.hide_render=True
# Pack all texture files into the blend.
bpy.ops.file.pack_all()
bpy.context.scene.unit_settings.system='NONE'
bpy.context.scene.unit_settings.scale_length=1.0
bpy.ops.wm.save_as_mainfile(filepath=OUT,compress=True)
print('Saved',OUT)
