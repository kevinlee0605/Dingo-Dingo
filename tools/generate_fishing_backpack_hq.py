from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Euler, Vector


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "fishing_backpack_hq"
RENDER_DIR = OUTPUT_DIR / "renders"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
RENDER_DIR.mkdir(parents=True, exist_ok=True)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def new_collection(name: str) -> bpy.types.Collection:
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def move_to(obj: bpy.types.Object, target: bpy.types.Collection) -> None:
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    target.objects.link(obj)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float,
    metallic: float = 0.0,
    specular: float = 0.18,
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


BUILDERS: dict[str, dict[str, object]] = {}


def builder_for(target: bpy.types.Collection) -> dict[str, object]:
    return BUILDERS.setdefault(
        target.name,
        {"verts": [], "faces": [], "face_mats": [], "materials": [], "mat_index": {}},
    )


def cube(
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    mat: bpy.types.Material,
    target: bpy.types.Collection,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> None:
    del name
    builder = builder_for(target)
    verts: list[tuple[float, float, float]] = builder["verts"]  # type: ignore[assignment]
    faces: list[tuple[int, int, int, int]] = builder["faces"]  # type: ignore[assignment]
    face_mats: list[int] = builder["face_mats"]  # type: ignore[assignment]
    materials: list[bpy.types.Material] = builder["materials"]  # type: ignore[assignment]
    mat_index: dict[int, int] = builder["mat_index"]  # type: ignore[assignment]

    pointer = mat.as_pointer()
    if pointer not in mat_index:
        mat_index[pointer] = len(materials)
        materials.append(mat)
    material_slot = mat_index[pointer]

    x, y, z = location
    hx, hy, hz = (value / 2 for value in dimensions)
    local = [
        Vector((-hx, -hy, -hz)), Vector((hx, -hy, -hz)),
        Vector((hx, hy, -hz)), Vector((-hx, hy, -hz)),
        Vector((-hx, -hy, hz)), Vector((hx, -hy, hz)),
        Vector((hx, hy, hz)), Vector((-hx, hy, hz)),
    ]
    if rotation != (0.0, 0.0, 0.0):
        matrix = Euler(rotation, "XYZ").to_matrix()
        local = [matrix @ point for point in local]
    base = len(verts)
    verts.extend((point.x + x, point.y + y, point.z + z) for point in local)
    faces.extend(
        (base + a, base + b, base + c, base + d)
        for a, b, c, d in (
            (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6),
            (3, 0, 4, 7), (0, 3, 2, 1), (4, 5, 6, 7),
        )
    )
    face_mats.extend([material_slot] * 6)


def finalize_builder(target: bpy.types.Collection, name: str) -> bpy.types.Object:
    builder = BUILDERS.pop(target.name)
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    mesh.from_pydata(builder["verts"], [], builder["faces"])
    for mat in builder["materials"]:
        mesh.materials.append(mat)
    for polygon, material_index in zip(mesh.polygons, builder["face_mats"]):
        polygon.material_index = material_index
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    return obj


def rounded_mask(ix: int, iz: int, rx: int, rz: int, corner: int) -> bool:
    ax, az = abs(ix), abs(iz)
    if ax > rx or az > rz:
        return False
    if ax <= rx - corner or az <= rz - corner:
        return True
    return (ax - (rx - corner)) ** 2 + (az - (rz - corner)) ** 2 <= corner**2


def hash_int(*values: int) -> int:
    value = 2166136261
    for item in values:
        value ^= item + 0x9E3779B9 + (value << 6) + (value >> 2)
        value &= 0xFFFFFFFF
    return value


def frame_front(
    name: str,
    center: tuple[float, float, float],
    width: float,
    height: float,
    bar: float,
    depth: float,
    mats: tuple[bpy.types.Material, bpy.types.Material],
    target: bpy.types.Collection,
) -> None:
    x, y, z = center
    dark, light = mats
    cube(f"{name}_Top", (x, y, z + height / 2 - bar / 2), (width, depth, bar), light, target)
    cube(f"{name}_Bottom", (x, y, z - height / 2 + bar / 2), (width, depth, bar), dark, target)
    cube(f"{name}_Left", (x - width / 2 + bar / 2, y, z), (bar, depth, height), dark, target)
    cube(f"{name}_Right", (x + width / 2 - bar / 2, y, z), (bar, depth, height), light, target)


def fine_body(
    target: bpy.types.Collection,
    palette: list[bpy.types.Material],
) -> None:
    step = 0.021
    center_z = -0.025
    rx, rz, corner = 12, 9, 4
    for ix in range(-rx, rx + 1):
        for iz in range(-rz, rz + 1):
            if not rounded_mask(ix, iz, rx, rz, corner):
                continue
            nx, nz = ix / rx, iz / rz
            bulge = max(0.0, 1.0 - 0.62 * nx * nx - 0.48 * nz * nz)
            depth = 0.157 + 0.024 * bulge + (hash_int(ix, iz) % 3 - 1) * 0.0013
            is_edge = not all(
                rounded_mask(ix + dx, iz + dz, rx, rz, corner)
                for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))
            )
            if is_edge:
                mat = palette[0]
            else:
                light_bias = (-ix + iz + 22) / 44
                code = hash_int(ix * 3, iz * 7) % 10
                if light_bias > 0.61 and code < 3:
                    mat = palette[4]
                elif light_bias > 0.44 and code < 7:
                    mat = palette[3]
                elif code < 2:
                    mat = palette[1]
                else:
                    mat = palette[2]
            cube(
                f"Body_{ix:+03d}_{iz:+03d}",
                (ix * step, -depth / 2, center_z + iz * step),
                (step * 0.985, depth, step * 0.985),
                mat,
                target,
            )


def fine_flap(
    target: bpy.types.Collection,
    blues: list[bpy.types.Material],
    golds: list[bpy.types.Material],
) -> None:
    step = 0.018
    center_z = 0.115
    for ix in range(-13, 14):
        for iz in range(-4, 5):
            keep = abs(ix) <= 13 and abs(iz) <= 4
            if iz <= -3 and abs(ix) >= 11:
                keep = False
            if iz == -4 and abs(ix) >= 8:
                keep = False
            if not keep:
                continue
            front = -0.203 - 0.008 * max(0.0, 1.0 - (ix / 13) ** 2)
            is_edge = (
                abs(iz) == 4
                or abs(ix) == 13
                or (iz <= -3 and abs(ix) >= 10)
                or (iz == -4 and abs(ix) >= 7)
            )
            code = hash_int(ix, iz, 19) % 12
            if is_edge:
                mat = blues[0]
            elif code <= 1:
                mat = blues[4]
            elif code <= 4:
                mat = blues[3]
            elif code == 5:
                mat = blues[1]
            else:
                mat = blues[2]
            cube(
                f"Flap_{ix:+03d}_{iz:+03d}",
                (ix * step, front - 0.012, center_z + iz * step),
                (step * 0.97, 0.024, step * 0.97),
                mat,
                target,
            )
    # Tiny brass-thread stitches define the flap edge without smoothing it.
    stitch_points = [(ix, 4) for ix in range(-11, 12, 2)]
    stitch_points += [(-13, iz) for iz in range(-2, 4, 2)]
    stitch_points += [(13, iz) for iz in range(-2, 4, 2)]
    stitch_points += [(ix, -4) for ix in range(-6, 7, 2)]
    for index, (ix, iz) in enumerate(stitch_points):
        cube(
            f"FlapStitch_{index:02d}",
            (ix * step, -0.229, center_z + iz * step),
            (0.009, 0.007, 0.006),
            golds[2 if index % 4 == 0 else 1],
            target,
        )


def pocket(
    label: str,
    x_center: float,
    target: bpy.types.Collection,
    blues: list[bpy.types.Material],
    leathers: list[bpy.types.Material],
    golds: list[bpy.types.Material],
) -> None:
    step = 0.019
    for ix in range(-4, 5):
        for iz in range(-6, 7):
            if not rounded_mask(ix, iz, 4, 6, 2):
                continue
            depth = 0.135 + 0.016 * max(0.0, 1.0 - (ix / 4) ** 2 - 0.45 * (iz / 6) ** 2)
            front = -0.166 - depth / 2
            is_edge = not all(
                rounded_mask(ix + dx, iz + dz, 4, 6, 2)
                for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))
            )
            code = hash_int(ix, iz, 41 if x_center > 0 else 43) % 9
            mat = blues[0] if is_edge else blues[4 if code == 0 else 3 if code < 4 else 2]
            cube(
                f"{label}Pocket_{ix:+02d}_{iz:+02d}",
                (x_center + ix * step, front, -0.075 + iz * step),
                (step * 0.97, depth, step * 0.97),
                mat,
                target,
            )
    # Layered leather cap and inset clasp.
    for ix in range(-4, 5):
        for iz in range(-1, 2):
            if abs(ix) == 4 and iz == -1:
                continue
            mat = leathers[3] if iz == 1 and (ix + 4) % 3 == 0 else leathers[2 if ix % 3 else 1]
            cube(
                f"{label}PocketFlap_{ix:+02d}_{iz:+02d}",
                (x_center + ix * step, -0.252, 0.045 + iz * step),
                (step * 0.97, 0.018, step * 0.97),
                mat,
                target,
            )
    # Fine brass piping follows the stepped pocket silhouette.
    for iz in range(-4, 5):
        for side in (-1, 1):
            cube(
                f"{label}PipeSide_{side:+d}_{iz:+02d}",
                (x_center + side * 0.083, -0.248, -0.075 + iz * step),
                (0.008, 0.009, 0.014),
                golds[1 if iz % 3 else 2],
                target,
            )
    for ix in range(-3, 4):
        cube(
            f"{label}PipeBottom_{ix:+02d}",
            (x_center + ix * step, -0.248, -0.185),
            (0.014, 0.009, 0.008),
            golds[1 if ix % 3 else 2],
            target,
        )
    frame_front(
        f"{label}PocketClasp",
        (x_center, -0.268, 0.044),
        0.047,
        0.038,
        0.008,
        0.009,
        (golds[0], golds[2]),
        target,
    )


def front_strap(
    label: str,
    x: float,
    phase: int,
    target: bpy.types.Collection,
    leathers: list[bpy.types.Material],
    golds: list[bpy.types.Material],
    thread: bpy.types.Material,
) -> None:
    step = 0.017
    for iz in range(-13, 13):
        z = iz * step - 0.005
        for ix in (-1, 0, 1):
            code = hash_int(iz, ix, phase) % 8
            mat = leathers[3] if ix == -1 and code < 3 else leathers[1 if ix == 1 else 2]
            cube(
                f"{label}Strap_{iz:+03d}_{ix:+02d}",
                (x + ix * 0.014, -0.244, z),
                (0.0135, 0.022, step * 0.97),
                mat,
                target,
            )
        if iz % 2 == phase % 2:
            for sx in (-1, 1):
                cube(
                    f"{label}Stitch_{iz:+03d}_{sx:+02d}",
                    (x + sx * 0.0215, -0.258, z),
                    (0.0045, 0.006, 0.008),
                    thread,
                    target,
                )
    frame_front(f"{label}BuckleHigh", (x, -0.271, 0.108), 0.066, 0.055, 0.010, 0.011, (golds[0], golds[2]), target)
    frame_front(f"{label}BuckleLow", (x, -0.271, -0.105), 0.073, 0.060, 0.011, 0.011, (golds[0], golds[1]), target)
    cube(f"{label}BuckleTongue", (x, -0.278, -0.105), (0.008, 0.007, 0.036), golds[2], target)
    # Tapered hanging tab in three small steps.
    for index, width in enumerate((0.044, 0.036, 0.026)):
        cube(
            f"{label}Tab_{index}",
            (x, -0.249, -0.236 - index * 0.014),
            (width, 0.020, 0.014),
            leathers[2 - min(index, 1)],
            target,
        )


def center_closure(
    target: bpy.types.Collection,
    leathers: list[bpy.types.Material],
    golds: list[bpy.types.Material],
) -> None:
    for iz in range(-4, 5):
        width = 0.052 if iz >= -2 else 0.042
        cube(
            f"Closure_{iz:+02d}",
            (0.0, -0.251, 0.064 + iz * 0.017),
            (width, 0.024, 0.0165),
            leathers[[1, 2, 2, 3][hash_int(iz, 77) % 4]],
            target,
        )
    frame_front("CenterBuckle", (0.0, -0.278, 0.140), 0.094, 0.070, 0.012, 0.012, (golds[0], golds[2]), target)
    cube("CenterBuckleTongue", (0.0, -0.286, 0.140), (0.010, 0.008, 0.046), golds[1], target)
    # A stepped arc of brass stitches across the lower front.
    for ix in range(-11, 12):
        z = -0.100 - int(4.0 * (1.0 - abs(ix) / 11)) * 0.005
        cube(
            f"LowerSeam_{ix:+03d}",
            (ix * 0.017, -0.217, z),
            (0.010, 0.008, 0.006),
            golds[2 if ix % 5 == 0 else 1],
            target,
        )


def voxel_bedroll(
    target: bpy.types.Collection,
    canvases: list[bpy.types.Material],
    leathers: list[bpy.types.Material],
    golds: list[bpy.types.Material],
) -> None:
    step = 0.018
    roll_z = 0.286
    roll_y = -0.085
    rx = 17
    radius = 4
    spiral = {
        (0, 0), (1, 0), (1, 1), (0, 1), (-1, 1), (-2, 1), (-2, 0),
        (-2, -1), (-1, -2), (0, -2), (1, -2), (2, -2), (3, -1),
        (3, 0), (3, 1), (2, 2), (1, 3), (0, 3), (-1, 3),
    }
    for ix in range(-rx, rx + 1):
        x = ix * step
        in_band = abs(abs(x) - 0.178) <= step * 1.25
        is_end = abs(ix) == rx
        for iy in range(-radius, radius + 1):
            for iz in range(-radius, radius + 1):
                if iy * iy + iz * iz > radius * radius + 1:
                    continue
                edge = iy * iy + iz * iz >= (radius - 1) ** 2
                if in_band:
                    code = hash_int(ix, iy, iz) % 6
                    mat = leathers[3 if code == 0 else 2 if code < 4 else 1]
                elif is_end and (iy, iz) in spiral:
                    mat = golds[2 if (iy + iz) % 3 == 0 else 1]
                elif is_end and edge:
                    mat = canvases[0]
                else:
                    code = hash_int(ix * 7, iy * 5, iz * 11) % 13
                    if iz >= 2 and code < 5:
                        mat = canvases[3]
                    elif iy >= 2 or code < 3:
                        mat = canvases[2]
                    elif code == 4:
                        mat = canvases[0]
                    else:
                        mat = canvases[1]
                cube(
                    f"Roll_{ix:+03d}_{iy:+02d}_{iz:+02d}",
                    (x, roll_y + iy * step, roll_z + iz * step),
                    (step * 0.985, step * 0.985, step * 0.985),
                    mat,
                    target,
                )
    # Small square highlights make the rolled ends legible at game scale.
    for side in (-1, 1):
        x = side * (rx * step + 0.010)
        for index, (iy, iz) in enumerate(((0, 0), (1, 0), (-1, 1), (2, -1), (-2, -1))):
            cube(
                f"RollEndDetail_{side:+d}_{index}",
                (x, roll_y + iy * step, roll_z + iz * step),
                (0.010, 0.010, 0.010),
                golds[2 if index == 0 else 0],
                target,
            )
    # Leather cradles visibly seat the roll against the top of the bag.
    for side in (-1, 1):
        for index in range(3):
            cube(
                f"RollCradle_{side:+d}_{index}",
                (side * 0.178, -0.105, 0.184 + index * 0.017),
                (0.040, 0.040, 0.0165),
                leathers[1 if index == 0 else 2],
                target,
            )


def voxel_handle(
    target: bpy.types.Collection,
    leathers: list[bpy.types.Material],
    thread: bpy.types.Material,
) -> None:
    step = 0.018
    path: list[tuple[int, int]] = []
    for ix in range(-8, 9):
        height = 2 + int(round(3.5 * math.sqrt(max(0.0, 1.0 - (ix / 8) ** 2))))
        path.append((ix, height))
    for ix, iz in path:
        for thickness in (0, 1):
            code = hash_int(ix, iz, thickness) % 5
            cube(
                f"Handle_{ix:+03d}_{thickness}",
                (ix * step, -0.040 + thickness * 0.017, 0.360 + iz * step),
                (step * 0.98, 0.017, step * 0.98),
                leathers[3 if code == 0 else 2 if thickness == 0 else 1],
                target,
            )
        if ix % 2 == 0:
            cube(
                f"HandleStitch_{ix:+03d}",
                (ix * step, -0.051, 0.360 + iz * step + 0.006),
                (0.008, 0.005, 0.004),
                thread,
                target,
            )
    for side in (-1, 1):
        for iz in range(0, 5):
            cube(
                f"HandleRoot_{side:+d}_{iz}",
                (side * 0.145, -0.049, 0.341 + iz * step),
                (0.027, 0.035, step * 0.98),
                leathers[1 if iz == 0 else 2],
                target,
            )


def back_panel_and_harness(
    target: bpy.types.Collection,
    blues: list[bpy.types.Material],
    leathers: list[bpy.types.Material],
    golds: list[bpy.types.Material],
    thread: bpy.types.Material,
) -> None:
    step = 0.019
    # Raised breathable back pad, itself built from small upholstered voxels.
    for ix in range(-9, 10):
        for iz in range(-7, 8):
            if not rounded_mask(ix, iz, 9, 7, 3):
                continue
            is_edge = not all(
                rounded_mask(ix + dx, iz + dz, 9, 7, 3)
                for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))
            )
            code = hash_int(ix, iz, 113) % 11
            mat = blues[0] if is_edge else blues[1 if code < 2 else 3 if code < 5 else 2]
            cube(
                f"BackPad_{ix:+03d}_{iz:+03d}",
                (ix * step, 0.014, -0.035 + iz * step),
                (step * 0.965, 0.028, step * 0.965),
                mat,
                target,
            )
    # Leather yoke.
    for ix in range(-7, 8):
        for iz in range(-1, 2):
            cube(
                f"Yoke_{ix:+02d}_{iz:+02d}",
                (ix * step, 0.044, 0.145 + iz * step),
                (step * 0.97, 0.026, step * 0.97),
                leathers[3 if iz == 1 and ix % 3 == 0 else 2 if abs(ix) < 6 else 1],
                target,
            )
    for side in (-1, 1):
        # Broad shoulder straps follow a stepped S-shaped curve.
        for index in range(22):
            t = index / 21
            x = side * (0.090 + 0.105 * math.sin(t * math.pi * 0.78))
            z = 0.132 - t * 0.365
            for cross in (-1, 0, 1):
                xx = x + cross * 0.015
                code = hash_int(index, cross, side) % 7
                mat = leathers[3 if cross == -side and code < 3 else 2 if cross == 0 else 1]
                cube(
                    f"BackStrap_{side:+d}_{index:02d}_{cross:+d}",
                    (xx, 0.054, z),
                    (0.0145, 0.030, 0.018),
                    mat,
                    target,
                )
            if index % 2 == 0:
                cube(
                    f"BackStrapStitch_{side:+d}_{index:02d}",
                    (x, 0.072, z),
                    (0.024, 0.006, 0.0045),
                    thread,
                    target,
                )
        frame_front(
            f"BackBuckle_{side:+d}",
            (side * 0.160, 0.080, -0.225),
            0.062,
            0.050,
            0.009,
            0.010,
            (golds[0], golds[2]),
            target,
        )
        cube(f"YokeRivet_{side:+d}", (side * 0.105, 0.063, 0.145), (0.015, 0.010, 0.015), golds[2], target)


def rod_mounts(
    target: bpy.types.Collection,
    leathers: list[bpy.types.Material],
    golds: list[bpy.types.Material],
) -> None:
    for label, x, z in (("Upper", 0.263, 0.110), ("Lower", 0.235, -0.155)):
        # Open stepped loop, visibly separate from the bag in back/side views.
        for index, (dx, dz) in enumerate(((-2, 0), (-1, 1), (0, 1), (1, 1), (2, 0), (2, -1), (-2, -1))):
            cube(
                f"Rod{label}Loop_{index}",
                (x + dx * 0.014, 0.044, z + dz * 0.018),
                (0.014, 0.040, 0.018),
                golds[2 if index in (1, 2, 3) else 0],
                target,
            )
        cube(f"Rod{label}Leather", (x, 0.062, z - 0.025), (0.068, 0.030, 0.036), leathers[2], target)
        cube(f"Rod{label}Stitch", (x, 0.080, z - 0.025), (0.036, 0.005, 0.006), golds[1], target)


def join_asset(target: bpy.types.Collection) -> bpy.types.Object:
    result = finalize_builder(target, "FishingBackpack_HQ_Voxel")
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.objects.active = result
    result.select_set(True)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR", center="MEDIAN")
    return result


def add_empty(
    name: str,
    location: tuple[float, float, float],
    parent: bpy.types.Object,
    target: bpy.types.Collection,
) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.040
    obj.location = location
    obj.parent = parent
    target.objects.link(obj)
    return obj


def aim(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def render_setup(target: bpy.types.Collection) -> bpy.types.Object:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = -0.18
    if hasattr(scene, "render"):
        scene.render.image_settings.color_mode = "RGBA"

    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.020, 0.040, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.18

    ground_mat = make_material("Ground", (0.035, 0.052, 0.082, 1.0), 0.95)
    cube("Ground", (0.0, 0.0, -0.306), (3.0, 3.0, 0.018), ground_mat, target)
    finalize_builder(target, "Ground")

    bpy.ops.object.camera_add(location=(0.0, -1.8, 0.06))
    camera = bpy.context.active_object
    camera.name = "PreviewCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 0.86
    move_to(camera, target)
    scene.camera = camera

    lights = [
        ("Key", (1.25, -1.15, 1.55), 95.0, 1.35, (1.0, 0.84, 0.68)),
        ("Fill", (-1.20, -0.75, 0.70), 58.0, 1.65, (0.38, 0.56, 1.0)),
        ("Top", (-0.20, 0.10, 1.65), 75.0, 1.10, (0.76, 0.88, 1.0)),
        ("Rim", (0.75, 1.05, 1.05), 105.0, 1.00, (0.25, 0.50, 1.0)),
    ]
    for name, location, energy, size, color in lights:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.data.color = color
        aim(light, (0.0, -0.06, 0.05))
        move_to(light, target)
    return camera


def render_view(
    camera: bpy.types.Object,
    filename: str,
    location: tuple[float, float, float],
    target: tuple[float, float, float] = (0.0, -0.06, 0.055),
    scale: float = 0.86,
) -> None:
    camera.location = location
    camera.data.ortho_scale = scale
    aim(camera, target)
    bpy.context.scene.render.filepath = str(RENDER_DIR / filename)
    bpy.ops.render.render(write_still=True)


clear_scene()
asset = new_collection("FishingBackpackHQ")
rendering = new_collection("RenderSetup")

# Matte, hand-shaded palette in the same small-voxel language as the game's fish.
blues = [
    make_material("Blue 0 Ink", (0.004, 0.018, 0.060, 1.0), 0.94),
    make_material("Blue 1 Deep", (0.006, 0.052, 0.185, 1.0), 0.92),
    make_material("Blue 2 Royal", (0.010, 0.135, 0.455, 1.0), 0.91),
    make_material("Blue 3 Azure", (0.018, 0.265, 0.690, 1.0), 0.90),
    make_material("Blue 4 Highlight", (0.050, 0.410, 0.900, 1.0), 0.88),
]
leathers = [
    make_material("Leather 0 Ink", (0.052, 0.012, 0.003, 1.0), 0.95),
    make_material("Leather 1 Umber", (0.185, 0.035, 0.004, 1.0), 0.94),
    make_material("Leather 2 Saddle", (0.430, 0.085, 0.008, 1.0), 0.92),
    make_material("Leather 3 Warm Edge", (0.680, 0.185, 0.016, 1.0), 0.90),
]
golds = [
    make_material("Gold 0 Tarnish", (0.225, 0.092, 0.008, 1.0), 0.70, 0.24, 0.20),
    make_material("Gold 1 Brass", (0.630, 0.310, 0.018, 1.0), 0.64, 0.32, 0.22),
    make_material("Gold 2 Sunlit", (1.000, 0.600, 0.055, 1.0), 0.58, 0.36, 0.24),
]
canvases = [
    make_material("Canvas 0 Shadow", (0.255, 0.135, 0.035, 1.0), 0.97),
    make_material("Canvas 1 Ochre", (0.665, 0.410, 0.115, 1.0), 0.96),
    make_material("Canvas 2 Sand", (0.900, 0.650, 0.260, 1.0), 0.95),
    make_material("Canvas 3 Cream", (1.000, 0.835, 0.480, 1.0), 0.94),
]
thread = make_material("Waxed Thread", (0.940, 0.530, 0.140, 1.0), 0.96)

fine_body(asset, blues)
fine_flap(asset, blues, golds)
pocket("Left", -0.306, asset, blues, leathers, golds)
pocket("Right", 0.306, asset, blues, leathers, golds)
front_strap("Left", -0.125, 0, asset, leathers, golds, thread)
front_strap("Right", 0.125, 1, asset, leathers, golds, thread)
center_closure(asset, leathers, golds)
voxel_bedroll(asset, canvases, leathers, golds)
voxel_handle(asset, leathers, thread)
back_panel_and_harness(asset, blues, leathers, golds, thread)
rod_mounts(asset, leathers, golds)

backpack = join_asset(asset)
backpack["asset_type"] = "High-quality fine-voxel fishing backpack"
backpack["style"] = "Minecraft-inspired hand-shaded voxel construction"
backpack["front_direction"] = "Local -Y"
backpack["back_contact_plane"] = "Local Y = 0"
backpack["target_width_studs"] = 2.25
backpack["target_height_studs"] = 2.55
backpack.data.calc_loop_triangles()
backpack["vertex_count"] = len(backpack.data.vertices)
backpack["triangle_count"] = len(backpack.data.loop_triangles)

back_attachment = add_empty("BackAttachment", (0.0, 0.0, 0.0), backpack, asset)
rod_upper = add_empty("RodMountUpper", (0.263, 0.082, 0.110), backpack, asset)
rod_lower = add_empty("RodMountLower", (0.235, 0.082, -0.155), backpack, asset)

camera = render_setup(rendering)
render_view(camera, "backpack_hq_front.png", (0.0, -1.80, 0.055), scale=0.91)
render_view(camera, "backpack_hq_back.png", (0.0, 1.80, 0.055), target=(0.0, 0.025, 0.045), scale=0.91)
render_view(camera, "backpack_hq_right.png", (1.80, -0.02, 0.055), target=(0.0, -0.015, 0.045), scale=0.91)
render_view(camera, "backpack_hq_left.png", (-1.80, -0.02, 0.055), target=(0.0, -0.015, 0.045), scale=0.91)
render_view(camera, "backpack_hq_hero.png", (1.08, -1.46, 0.82), scale=0.92)

export_objects = [backpack, back_attachment, rod_upper, rod_lower]
bpy.ops.object.select_all(action="DESELECT")
for obj in export_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = backpack

bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_DIR / "FishingBackpack_HQ.glb"),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_yup=True,
)
bpy.ops.export_scene.fbx(
    filepath=str(OUTPUT_DIR / "FishingBackpack_HQ.fbx"),
    use_selection=True,
    object_types={"MESH", "EMPTY"},
    axis_forward="-Z",
    axis_up="Y",
    apply_unit_scale=True,
    add_leaf_bones=False,
    bake_anim=False,
)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_DIR / "FishingBackpack_HQ.blend"))

print(f"HQ backpack vertices: {len(backpack.data.vertices)}")
print(f"HQ backpack triangles: {len(backpack.data.loop_triangles)}")
