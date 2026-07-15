from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "fishing_backpack"
RENDER_DIR = OUTPUT_DIR / "renders"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
RENDER_DIR.mkdir(parents=True, exist_ok=True)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def collection(name: str) -> bpy.types.Collection:
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def move_to(obj: bpy.types.Object, target: bpy.types.Collection) -> None:
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    target.objects.link(obj)


def material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float,
    metallic: float = 0.0,
    specular: float = 0.22,
) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    result.diffuse_color = color
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in shader.inputs:
        shader.inputs["Specular IOR Level"].default_value = specular
    if "Coat Weight" in shader.inputs:
        shader.inputs["Coat Weight"].default_value = 0.0
    return result


def box(
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    mat: bpy.types.Material,
    target: bpy.types.Collection,
    bevel: float = 0.002,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        modifier = obj.modifiers.new(name="Voxel Edge", type="BEVEL")
        modifier.width = min(bevel, min(dimensions) * 0.18)
        modifier.segments = 1
        modifier.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    move_to(obj, target)
    return obj


def frame_xy(
    name: str,
    center: tuple[float, float, float],
    width: float,
    height: float,
    thickness: float,
    depth: float,
    mat: bpy.types.Material,
    target: bpy.types.Collection,
) -> None:
    x, y, z = center
    box(f"{name}_Top", (x, y, z + height / 2 - thickness / 2), (width, depth, thickness), mat, target)
    box(f"{name}_Bottom", (x, y, z - height / 2 + thickness / 2), (width, depth, thickness), mat, target)
    box(f"{name}_Left", (x - width / 2 + thickness / 2, y, z), (thickness, depth, height), mat, target)
    box(f"{name}_Right", (x + width / 2 - thickness / 2, y, z), (thickness, depth, height), mat, target)


def frame_yz(
    name: str,
    center: tuple[float, float, float],
    width_y: float,
    height_z: float,
    thickness: float,
    depth_x: float,
    mat: bpy.types.Material,
    target: bpy.types.Collection,
) -> None:
    x, y, z = center
    box(f"{name}_Top", (x, y, z + height_z / 2 - thickness / 2), (depth_x, width_y, thickness), mat, target)
    box(f"{name}_Bottom", (x, y, z - height_z / 2 + thickness / 2), (depth_x, width_y, thickness), mat, target)
    box(f"{name}_Front", (x, y - width_y / 2 + thickness / 2, z), (depth_x, thickness, height_z), mat, target)
    box(f"{name}_Back", (x, y + width_y / 2 - thickness / 2, z), (depth_x, thickness, height_z), mat, target)


def pixel_patch(
    name: str,
    x: float,
    y: float,
    z: float,
    size: float,
    mat: bpy.types.Material,
    target: bpy.types.Collection,
) -> None:
    box(name, (x, y, z), (size, 0.005, size), mat, target, bevel=0.0007)


def join_meshes(target: bpy.types.Collection) -> bpy.types.Object:
    meshes = [obj for obj in target.objects if obj.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    result = bpy.context.active_object
    result.name = "FishingBackpack_Voxel"
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR", center="MEDIAN")
    return result


def empty(
    name: str,
    location: tuple[float, float, float],
    parent: bpy.types.Object,
    target: bpy.types.Collection,
) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.045
    obj.location = location
    obj.parent = parent
    target.objects.link(obj)
    return obj


def aim(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def render_setup(target: bpy.types.Collection) -> bpy.types.Object:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 800
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = -0.15

    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.025, 0.035, 0.055, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.16

    ground_mat = material("Ground", (0.055, 0.072, 0.105, 1.0), 0.92)
    ground = box("Ground", (0.0, 0.0, -0.315), (3.0, 3.0, 0.025), ground_mat, target, bevel=0.0)
    ground.visible_shadow = True

    bpy.ops.object.camera_add(location=(0.0, -1.7, 0.06))
    camera = bpy.context.active_object
    camera.name = "PreviewCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 0.94
    move_to(camera, target)
    scene.camera = camera

    lights = [
        ("Key", (1.1, -1.2, 1.5), 82.0, 1.6, (1.0, 0.86, 0.72)),
        ("Fill", (-1.2, -0.6, 0.8), 50.0, 1.8, (0.46, 0.62, 1.0)),
        ("Rim", (0.3, 1.0, 1.25), 90.0, 1.2, (0.35, 0.58, 1.0)),
    ]
    for name, location, energy, size, color in lights:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.data.color = color
        aim(light, (0.0, -0.08, 0.03))
        move_to(light, target)
    return camera


def render(
    camera: bpy.types.Object,
    filename: str,
    location: tuple[float, float, float],
    target: tuple[float, float, float] = (0.0, -0.08, 0.04),
    scale: float = 0.94,
) -> None:
    camera.location = location
    camera.data.ortho_scale = scale
    aim(camera, target)
    bpy.context.scene.render.filepath = str(RENDER_DIR / filename)
    bpy.ops.render.render(write_still=True)


clear_scene()
asset = collection("VoxelBackpackAsset")
rendering = collection("RenderSetup")

# Matte voxel palette sampled from the game's block-built fish and rods.
blue_0 = material("Blue 0 - Outline", (0.006, 0.025, 0.085, 1.0), 0.9)
blue_1 = material("Blue 1 - Shadow", (0.008, 0.065, 0.24, 1.0), 0.88)
blue_2 = material("Blue 2 - Canvas", (0.018, 0.17, 0.56, 1.0), 0.86)
blue_3 = material("Blue 3 - Light", (0.025, 0.31, 0.78, 1.0), 0.84)
blue_4 = material("Blue 4 - Highlight", (0.055, 0.46, 0.95, 1.0), 0.82)
leather_0 = material("Leather 0 - Dark", (0.075, 0.018, 0.004, 1.0), 0.9)
leather_1 = material("Leather 1 - Brown", (0.28, 0.06, 0.008, 1.0), 0.88)
leather_2 = material("Leather 2 - Warm", (0.56, 0.13, 0.012, 1.0), 0.86)
leather_3 = material("Leather 3 - Edge", (0.78, 0.25, 0.025, 1.0), 0.83)
gold_0 = material("Gold 0 - Tarnish", (0.30, 0.13, 0.015, 1.0), 0.62, 0.38, 0.32)
gold_1 = material("Gold 1 - Brass", (0.72, 0.36, 0.025, 1.0), 0.55, 0.44, 0.36)
gold_2 = material("Gold 2 - Edge", (1.0, 0.62, 0.075, 1.0), 0.48, 0.48, 0.4)
canvas_0 = material("Canvas 0 - Shadow", (0.30, 0.18, 0.055, 1.0), 0.95)
canvas_1 = material("Canvas 1 - Tan", (0.75, 0.48, 0.16, 1.0), 0.93)
canvas_2 = material("Canvas 2 - Cream", (0.95, 0.72, 0.32, 1.0), 0.92)
canvas_3 = material("Canvas 3 - Highlight", (1.0, 0.86, 0.53, 1.0), 0.91)
thread = material("Stitching", (0.95, 0.62, 0.20, 1.0), 0.94)

# Layered voxel silhouette with stepped corners and dark edge blocks.
box("BodyCore", (0.0, -0.105, -0.025), (0.46, 0.20, 0.36), blue_2, asset, 0.006)
box("BodyTopStep", (0.0, -0.105, 0.175), (0.38, 0.20, 0.05), blue_1, asset, 0.004)
box("BodyBottomStep", (0.0, -0.105, -0.225), (0.38, 0.20, 0.04), blue_1, asset, 0.003)
box("LeftEdge", (-0.225, -0.11, -0.025), (0.035, 0.19, 0.29), blue_1, asset, 0.003)
box("RightEdge", (0.225, -0.11, -0.025), (0.035, 0.19, 0.29), blue_1, asset, 0.003)
box("LowerFrontPanel", (0.0, -0.213, -0.115), (0.40, 0.03, 0.17), blue_3, asset, 0.003)
box("LowerPanelShadow", (0.0, -0.218, -0.205), (0.36, 0.026, 0.025), blue_0, asset, 0.002)

# Canvas-like pixel color variation across the exposed front panel.
front_palette = [blue_1, blue_2, blue_3, blue_2, blue_4]
for ix in range(-5, 6):
    for iz in range(-2, 3):
        code = abs(ix * 37 + iz * 19 + ix * iz * 7)
        if code % 4 in (0, 1):
            x = ix * 0.039
            z = -0.11 + iz * 0.038
            if abs(x - 0.135) > 0.035 and abs(x + 0.135) > 0.035:
                pixel_patch(f"FrontPixel_{ix}_{iz}", x, -0.232, z, 0.036, front_palette[code % len(front_palette)], asset)

# Block-built flap: three layers instead of one rounded plastic shell.
box("FlapOutline", (0.0, -0.218, 0.115), (0.47, 0.045, 0.16), blue_0, asset, 0.004)
box("FlapMain", (0.0, -0.242, 0.125), (0.43, 0.035, 0.13), blue_3, asset, 0.003)
box("FlapTopHighlight", (0.0, -0.263, 0.173), (0.35, 0.012, 0.032), blue_4, asset, 0.001)
box("FlapBottomLip", (0.0, -0.265, 0.065), (0.35, 0.018, 0.025), blue_1, asset, 0.002)
for ix in range(-4, 5):
    if ix not in (-3, 3):
        mat = blue_4 if ix % 3 == 0 else blue_2
        pixel_patch(f"FlapPixel_{ix}", ix * 0.043, -0.266, 0.13, 0.038, mat, asset)

# Side pockets with stepped shoulders, pixel faces, and blocky gold piping.
for label, x in (("Left", -0.285), ("Right", 0.285)):
    box(f"{label}PocketShadow", (x, -0.105, -0.08), (0.15, 0.18, 0.235), blue_0, asset, 0.004)
    box(f"{label}PocketCore", (x, -0.125, -0.075), (0.13, 0.17, 0.205), blue_2, asset, 0.003)
    box(f"{label}PocketFace", (x, -0.221, -0.09), (0.105, 0.025, 0.16), blue_3, asset, 0.002)
    box(f"{label}PocketPixelTop", (x - 0.025, -0.236, -0.045), (0.05, 0.006, 0.04), blue_4, asset, 0.0007)
    box(f"{label}PocketPixelBottom", (x + 0.025, -0.236, -0.125), (0.05, 0.006, 0.04), blue_1, asset, 0.0007)
    box(f"{label}PocketFlapDark", (x, -0.244, 0.005), (0.115, 0.025, 0.065), leather_0, asset, 0.002)
    box(f"{label}PocketFlap", (x, -0.259, 0.01), (0.105, 0.018, 0.052), leather_2, asset, 0.002)
    box(f"{label}PocketRivet", (x, -0.273, 0.01), (0.018, 0.012, 0.018), gold_2, asset, 0.001)
    box(f"{label}TrimLeft", (x - 0.058, -0.244, -0.09), (0.011, 0.012, 0.17), gold_1, asset, 0.001)
    box(f"{label}TrimRight", (x + 0.058, -0.244, -0.09), (0.011, 0.012, 0.17), gold_1, asset, 0.001)
    box(f"{label}TrimBottom", (x, -0.244, -0.17), (0.125, 0.012, 0.011), gold_1, asset, 0.001)

# Front leather straps are mosaics of blocks with visible pixel stitching.
for label, x in (("Left", -0.135), ("Right", 0.135)):
    for index in range(10):
        z = -0.19 + index * 0.043
        strap_mat = [leather_1, leather_2, leather_2, leather_3][(index + (1 if x > 0 else 0)) % 4]
        box(f"{label}Strap_{index}", (x, -0.282, z), (0.047, 0.025, 0.041), strap_mat, asset, 0.0015)
        if index % 2 == 0:
            box(f"{label}StitchL_{index}", (x - 0.017, -0.298, z), (0.005, 0.008, 0.012), thread, asset, 0.0005)
            box(f"{label}StitchR_{index}", (x + 0.017, -0.298, z), (0.005, 0.008, 0.012), thread, asset, 0.0005)
    frame_xy(f"{label}UpperBuckle", (x, -0.307, 0.09), 0.072, 0.062, 0.012, 0.014, gold_2, asset)
    frame_xy(f"{label}LowerBuckle", (x, -0.307, -0.105), 0.082, 0.07, 0.013, 0.014, gold_1, asset)
    box(f"{label}TabA", (x, -0.294, -0.225), (0.047, 0.022, 0.045), leather_2, asset, 0.001)
    box(f"{label}TabB", (x, -0.294, -0.255), (0.031, 0.022, 0.022), leather_1, asset, 0.001)

# Central closure and stepped gold seam.
box("CenterClosureDark", (0.0, -0.285, 0.065), (0.072, 0.026, 0.16), leather_0, asset, 0.002)
for index, z in enumerate((0.125, 0.085, 0.045, 0.005)):
    width = 0.06 if index < 3 else 0.04
    box(f"CenterClosure_{index}", (0.0, -0.302, z), (width, 0.018, 0.038), [leather_3, leather_2, leather_1, leather_2][index], asset, 0.001)
frame_xy("CenterBuckle", (0.0, -0.316, 0.13), 0.108, 0.082, 0.014, 0.014, gold_2, asset)
for index, x in enumerate((-0.20, -0.16, -0.12, -0.08, -0.04, 0.0, 0.04, 0.08, 0.12, 0.16, 0.20)):
    z = -0.075 - (0.012 if abs(x) < 0.10 else 0.0)
    box(f"GoldSeam_{index}", (x, -0.253, z), (0.038, 0.009, 0.009), gold_1 if index % 3 else gold_2, asset, 0.0008)

# Voxel bedroll: stepped square cross-section, patchwork canvas, square spiral end caps.
box("BedrollCore", (0.0, -0.095, 0.315), (0.62, 0.135, 0.11), canvas_2, asset, 0.003)
box("BedrollTopStep", (0.0, -0.095, 0.385), (0.55, 0.105, 0.035), canvas_3, asset, 0.002)
box("BedrollBottomStep", (0.0, -0.095, 0.245), (0.55, 0.105, 0.035), canvas_1, asset, 0.002)
for index in range(14):
    x = -0.275 + index * 0.042
    mat = [canvas_1, canvas_2, canvas_3, canvas_2][(index * 5) % 4]
    box(f"BedrollPixel_{index}", (x, -0.166, 0.318), (0.038, 0.006, 0.045), mat, asset, 0.0006)
for label, x in (("Left", -0.175), ("Right", 0.175)):
    box(f"{label}BedrollBandFront", (x, -0.171, 0.315), (0.052, 0.018, 0.17), leather_2, asset, 0.002)
    box(f"{label}BedrollBandBack", (x, -0.019, 0.315), (0.052, 0.018, 0.17), leather_1, asset, 0.002)
    box(f"{label}BedrollBandTop", (x, -0.095, 0.402), (0.052, 0.15, 0.018), leather_3, asset, 0.002)
    box(f"{label}BedrollBandBottom", (x, -0.095, 0.228), (0.052, 0.15, 0.018), leather_0, asset, 0.002)
for label, x, outward in (("Left", -0.318, -1.0), ("Right", 0.318, 1.0)):
    box(f"{label}EndCap", (x, -0.095, 0.315), (0.016, 0.13, 0.13), canvas_1, asset, 0.001)
    frame_yz(f"{label}EndFrame", (x + outward * 0.01, -0.095, 0.315), 0.105, 0.105, 0.014, 0.012, gold_1, asset)
    frame_yz(f"{label}EndSpiral", (x + outward * 0.017, -0.095, 0.315), 0.055, 0.055, 0.012, 0.01, gold_2, asset)
    box(f"{label}EndCenter", (x + outward * 0.024, -0.095, 0.315), (0.01, 0.018, 0.018), gold_0, asset, 0.0008)

# Squared carry handle.
box("HandleLeft", (-0.13, -0.06, 0.425), (0.035, 0.045, 0.10), leather_2, asset, 0.002)
box("HandleRight", (0.13, -0.06, 0.425), (0.035, 0.045, 0.10), leather_2, asset, 0.002)
box("HandleTop", (0.0, -0.06, 0.475), (0.26, 0.045, 0.035), leather_3, asset, 0.002)
box("HandleInset", (0.0, -0.085, 0.455), (0.18, 0.01, 0.022), leather_0, asset, 0.001)

# Back padding is a blue pixel mosaic; shoulder straps use stair-step blocks.
box("BackPaddingDark", (0.0, 0.012, -0.03), (0.40, 0.03, 0.34), blue_0, asset, 0.004)
box("BackPadding", (0.0, 0.032, -0.03), (0.36, 0.025, 0.30), blue_2, asset, 0.003)
for ix in range(-4, 5):
    for iz in range(-3, 4):
        code = abs(ix * 23 + iz * 11)
        if code % 3 == 0:
            pixel_patch(f"BackPixel_{ix}_{iz}", ix * 0.038, 0.048, -0.03 + iz * 0.038, 0.035, [blue_1, blue_3, blue_2][code % 3], asset)
box("HarnessTopDark", (0.0, 0.064, 0.17), (0.25, 0.035, 0.075), leather_0, asset, 0.002)
box("HarnessTop", (0.0, 0.083, 0.17), (0.22, 0.025, 0.055), leather_2, asset, 0.002)
for label, sign in (("Left", -1.0), ("Right", 1.0)):
    path = [
        (0.11 * sign, 0.077, 0.14),
        (0.14 * sign, 0.077, 0.095),
        (0.17 * sign, 0.077, 0.05),
        (0.19 * sign, 0.077, 0.005),
        (0.19 * sign, 0.077, -0.04),
        (0.18 * sign, 0.077, -0.085),
        (0.17 * sign, 0.077, -0.13),
        (0.16 * sign, 0.077, -0.175),
        (0.15 * sign, 0.077, -0.22),
    ]
    for index, position in enumerate(path):
        mat = [leather_1, leather_2, leather_3][(index + (1 if sign > 0 else 0)) % 3]
        box(f"{label}BackStrap_{index}", position, (0.055, 0.028, 0.052), mat, asset, 0.0015)
        if index % 2 == 1:
            box(f"{label}BackStitch_{index}", (position[0], 0.094, position[2]), (0.026, 0.007, 0.005), thread, asset, 0.0005)
    frame_xy(f"{label}BackBuckle", (0.15 * sign, 0.104, -0.225), 0.075, 0.06, 0.012, 0.012, gold_1, asset)
for x in (-0.09, 0.09):
    box(f"HarnessRivet_{x:+.2f}", (x, 0.101, 0.17), (0.018, 0.012, 0.018), gold_2, asset, 0.001)

# Block-built rod brackets remain visible and double as alignment landmarks.
for label, x, z in (("Upper", 0.255, 0.13), ("Lower", 0.21, -0.16)):
    box(f"RodHolster{label}Gold", (x, 0.055, z), (0.075, 0.035, 0.095), gold_0, asset, 0.002)
    box(f"RodHolster{label}Leather", (x, 0.08, z), (0.053, 0.026, 0.071), leather_1, asset, 0.001)
    box(f"RodHolster{label}Highlight", (x - 0.014, 0.096, z + 0.018), (0.022, 0.006, 0.022), leather_3, asset, 0.0005)

backpack = join_meshes(asset)
backpack["asset_type"] = "High-detail voxel fishing backpack"
backpack["back_contact_plane"] = "Local Y = 0"
backpack["front_direction"] = "Local -Y"
backpack["target_width_studs"] = 2.2
backpack["target_height_studs"] = 2.45
back_attachment = empty("BackAttachment", (0.0, 0.0, 0.0), backpack, asset)
rod_upper = empty("RodMountUpper", (0.255, 0.10, 0.13), backpack, asset)
rod_lower = empty("RodMountLower", (0.21, 0.10, -0.16), backpack, asset)

camera = render_setup(rendering)
render(camera, "backpack_front.png", (0.0, -1.7, 0.07))
render(camera, "backpack_back.png", (0.0, 1.7, 0.07), target=(0.0, 0.02, 0.04))
render(camera, "backpack_right.png", (1.7, -0.02, 0.07))
render(camera, "backpack_left.png", (-1.7, -0.02, 0.07))
render(camera, "backpack_hero.png", (1.05, -1.4, 0.78), scale=1.0)

export_objects = [backpack, back_attachment, rod_upper, rod_lower]
bpy.ops.object.select_all(action="DESELECT")
for obj in export_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = backpack

bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_DIR / "FishingBackpack.glb"),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_yup=True,
)
bpy.ops.export_scene.fbx(
    filepath=str(OUTPUT_DIR / "FishingBackpack.fbx"),
    use_selection=True,
    object_types={"MESH", "EMPTY"},
    axis_forward="-Z",
    axis_up="Y",
    apply_unit_scale=True,
    add_leaf_bones=False,
    bake_anim=False,
)

backpack.data.calc_loop_triangles()
backpack["vertex_count"] = len(backpack.data.vertices)
backpack["triangle_count"] = len(backpack.data.loop_triangles)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_DIR / "FishingBackpack.blend"))

print(f"Voxel backpack vertices: {len(backpack.data.vertices)}")
print(f"Voxel backpack triangles: {len(backpack.data.loop_triangles)}")
