from __future__ import annotations

import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


SOURCE = Path(os.environ.get("FISHY_FISH_BACKPACK_SOURCE", Path.home() / "Downloads" / "Backpack_New.glb")).expanduser()
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "backpack_selected"
RENDERS = OUTPUT / "renders"
OUTPUT.mkdir(parents=True, exist_ok=True)
RENDERS.mkdir(parents=True, exist_ok=True)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def aim(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def world_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    return (
        Vector(tuple(min(point[index] for point in points) for index in range(3))),
        Vector(tuple(max(point[index] for point in points) for index in range(3))),
    )


def make_material(name: str, color: tuple[float, float, float, float], roughness: float) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    return result


def render_view(
    camera: bpy.types.Object,
    center: Vector,
    extent: float,
    filename: str,
    direction: Vector,
) -> None:
    camera.location = center + direction.normalized() * extent * 2.8
    camera.data.ortho_scale = extent * 1.28
    aim(camera, center)
    bpy.context.scene.render.filepath = str(RENDERS / filename)
    bpy.ops.render.render(write_still=True)


clear_scene()
bpy.ops.import_scene.gltf(filepath=str(SOURCE))

all_meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
meshes = [
    obj
    for obj in all_meshes
    if "AWNING" not in obj.name.upper() and "ROOF" not in obj.name.upper()
]
for obj in all_meshes:
    if obj not in meshes:
        obj.hide_render = True
if not meshes:
    raise RuntimeError("No mesh objects were imported")

minimum, maximum = world_bounds(meshes)
center = (minimum + maximum) * 0.5
dimensions = maximum - minimum
extent = max(dimensions.x, dimensions.y, dimensions.z)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = -0.1

world = scene.world or bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.018, 0.028, 0.050, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22

# A neutral floor makes scale/orientation problems obvious without changing the asset.
ground_mat = make_material("Preview Ground", (0.045, 0.065, 0.095, 1.0), 0.94)
bpy.ops.mesh.primitive_cube_add(location=(center.x, center.y, minimum.z - extent * 0.015))
ground = bpy.context.active_object
ground.name = "Preview Ground"
ground.dimensions = (extent * 3.0, extent * 3.0, extent * 0.03)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
ground.data.materials.append(ground_mat)

bpy.ops.object.camera_add()
camera = bpy.context.active_object
camera.name = "Preview Camera"
camera.data.type = "ORTHO"
scene.camera = camera

lights = [
    (Vector((1.4, -1.6, 2.0)), 1000.0, 4.0, (1.0, 0.86, 0.72)),
    (Vector((-1.6, -0.6, 1.0)), 650.0, 5.0, (0.42, 0.62, 1.0)),
    (Vector((0.8, 1.4, 1.6)), 900.0, 4.0, (0.36, 0.56, 1.0)),
]
for index, (direction, energy, size_factor, color) in enumerate(lights):
    bpy.ops.object.light_add(type="AREA", location=center + direction.normalized() * extent * 1.9)
    light = bpy.context.active_object
    light.name = f"Preview Light {index + 1}"
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = extent * size_factor
    light.data.color = color
    aim(light, center)

render_view(camera, center, extent, "source_front.png", Vector((0.0, -1.0, 0.08)))
render_view(camera, center, extent, "source_back.png", Vector((0.0, 1.0, 0.08)))
render_view(camera, center, extent, "source_right.png", Vector((1.0, 0.0, 0.08)))
render_view(camera, center, extent, "source_hero.png", Vector((1.05, -1.4, 0.75)))

# Package the source and linked textures into one portable GLB without changing geometry.
bpy.ops.object.select_all(action="DESELECT")
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT / "Backpack_Selected_Source.glb"),
    export_format="GLB",
    use_selection=True,
    export_apply=False,
    export_yup=True,
)

with (OUTPUT / "source_report.txt").open("w", encoding="utf-8") as report:
    report.write(f"Source: {SOURCE}\n")
    report.write(f"Mesh objects: {len(meshes)}\n")
    report.write(f"Materials: {len(bpy.data.materials) - 1}\n")
    report.write(f"Minimum XYZ: {tuple(round(value, 6) for value in minimum)}\n")
    report.write(f"Maximum XYZ: {tuple(round(value, 6) for value in maximum)}\n")
    report.write(f"Dimensions XYZ: {tuple(round(value, 6) for value in dimensions)}\n")
    report.write(f"Triangles: {sum(len(obj.data.loop_triangles) for obj in meshes)}\n")

print(f"Imported meshes: {len(meshes)}")
print(f"Bounds min: {tuple(minimum)}")
print(f"Bounds max: {tuple(maximum)}")
print(f"Dimensions: {tuple(dimensions)}")
