import json
import math
import struct
import sys


def mat_mul(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def node_matrix(node):
    if "matrix" in node:
        m = node["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    tx, ty, tz = node.get("translation", [0.0, 0.0, 0.0])
    sx, sy, sz = node.get("scale", [1.0, 1.0, 1.0])
    x, y, z, w = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    rotation = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0],
        [0, 0, 0, 1],
    ]
    scale = [[sx, 0, 0, 0], [0, sy, 0, 0], [0, 0, sz, 0], [0, 0, 0, 1]]
    result = mat_mul(rotation, scale)
    result[0][3], result[1][3], result[2][3] = tx, ty, tz
    return result


def transform_point(m, p):
    x, y, z = p
    return tuple(sum(m[r][k] * (x, y, z, 1)[k] for k in range(4)) for r in range(3))


def corners(mn, mx):
    return [(x, y, z) for x in (mn[0], mx[0]) for y in (mn[1], mx[1]) for z in (mn[2], mx[2])]


path = sys.argv[1]
with open(path, "rb") as handle:
    magic, version, total = struct.unpack("<4sII", handle.read(12))
    if magic != b"glTF" or version != 2:
        raise SystemExit("Not a GLB 2.0 file")
    json_length, json_type = struct.unpack("<II", handle.read(8))
    if json_type != 0x4E4F534A:
        raise SystemExit("First GLB chunk is not JSON")
    data = json.loads(handle.read(json_length).rstrip(b"\x00 \t\r\n"))

identity = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
world = {}


def visit(index, parent):
    current = mat_mul(parent, node_matrix(data["nodes"][index]))
    world[index] = current
    for child in data["nodes"][index].get("children", []):
        visit(child, current)


scene = data["scenes"][data.get("scene", 0)]
for root in scene.get("nodes", []):
    visit(root, identity)

all_points = []
named_bounds = []
mesh_nodes = 0
triangle_count = 0
for node_index, node in enumerate(data.get("nodes", [])):
    if "mesh" not in node or node_index not in world:
        continue
    mesh_nodes += 1
    node_points = []
    mesh = data["meshes"][node["mesh"]]
    for primitive in mesh.get("primitives", []):
        accessor = data["accessors"][primitive["attributes"]["POSITION"]]
        mn, mx = accessor.get("min"), accessor.get("max")
        if mn is not None and mx is not None:
            pts = [transform_point(world[node_index], p) for p in corners(mn, mx)]
            node_points.extend(pts)
            all_points.extend(pts)
        if "indices" in primitive:
            triangle_count += data["accessors"][primitive["indices"]]["count"] // 3
        else:
            triangle_count += accessor["count"] // 3
    if node_points:
        mn = tuple(min(p[i] for p in node_points) for i in range(3))
        mx = tuple(max(p[i] for p in node_points) for i in range(3))
        name = node.get("name", mesh.get("name", f"Node{node_index}"))
        if name.startswith(("FishingSpotMarker", "SpawnMarker", "WaterPreview")):
            named_bounds.append((name, mn, mx))

mn = tuple(min(p[i] for p in all_points) for i in range(3))
mx = tuple(max(p[i] for p in all_points) for i in range(3))
size = tuple(mx[i] - mn[i] for i in range(3))
center = tuple((mx[i] + mn[i]) / 2 for i in range(3))
print("asset", data.get("asset"))
print("scenes", len(data.get("scenes", [])), "nodes", len(data.get("nodes", [])), "mesh_nodes", mesh_nodes)
print("meshes", len(data.get("meshes", [])), "materials", len(data.get("materials", [])), "triangles", triangle_count)
print("roots", [(i, data["nodes"][i].get("name")) for i in scene.get("nodes", [])])
print("bounds_min", tuple(round(v, 4) for v in mn))
print("bounds_max", tuple(round(v, 4) for v in mx))
print("bounds_center", tuple(round(v, 4) for v in center))
print("bounds_size", tuple(round(v, 4) for v in size))
for name, lower, upper in sorted(named_bounds):
    ncenter = tuple((lower[i] + upper[i]) / 2 for i in range(3))
    nsize = tuple(upper[i] - lower[i] for i in range(3))
    print("named", name, "center", tuple(round(v, 3) for v in ncenter), "size", tuple(round(v, 3) for v in nsize))
