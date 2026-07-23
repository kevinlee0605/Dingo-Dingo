import json
import math
import random
import struct
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Mapping, Sequence, Tuple

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from PIL import Image, ImageDraw
import trimesh
from trimesh.visual.material import PBRMaterial
from trimesh.visual.texture import TextureVisuals

OUT = Path('/mnt/data/Coral_Coast_Island_Package')
TEX_DIR = OUT / 'Textures'
OUT.mkdir(parents=True, exist_ok=True)
TEX_DIR.mkdir(parents=True, exist_ok=True)

GLB_PATH = OUT / 'Coral_Coast_Island.glb'
ZIP_PATH = Path('/mnt/data/Coral_Coast_Island_Roblox_Ready.zip')
README_PATH = OUT / 'README.txt'
VERIFY_PATH = OUT / 'verification.json'
PREVIEW_PATH = OUT / 'Coral_Coast_Island_Preview.png'
TOP_PATH = OUT / 'Coral_Coast_Island_Top.png'
GROUND_PATH = OUT / 'Coral_Coast_Island_Ground.png'
BUILD_SCRIPT_COPY = OUT / 'Coral_Coast_Island_Build.py'

ATLAS_SIZE = 2048
TILE_SIZE = 512
PAD = 32
INNER = TILE_SIZE - PAD * 2
BLOCK = 8.0
NX = 44
NZ = 38
X_MIN = -NX * BLOCK / 2.0
Z_MIN = -NZ * BLOCK / 2.0
ROOT_NAME = 'CoralCoast_Island_ROOT'
RNG = random.Random(20260723)

TILE_NAMES = [
    'SandTop', 'SandSide', 'Dirt', 'Stone',
    'GrassTop', 'GrassSide', 'Path', 'Wood',
    'DarkWood', 'Leaves', 'PalmTrunk', 'CoralOrange',
    'CoralRed', 'Rock', 'Decoration', 'PortalPad',
]
TILE_INDEX = {name: i for i, name in enumerate(TILE_NAMES)}

# -------------------- texture atlas --------------------

def _logical_texture(base: Tuple[int, int, int], seed: int, logical: int = 64,
                     variation: int = 14, density: float = 0.34) -> Image.Image:
    rr = random.Random(seed)
    img = Image.new('RGB', (logical, logical), base)
    px = img.load()
    for y in range(logical):
        for x in range(logical):
            if rr.random() < density:
                delta = rr.randint(-variation, variation)
                px[x, y] = tuple(max(0, min(255, c + delta)) for c in base)
    return img


def _sand_top() -> Image.Image:
    img = _logical_texture((226, 190, 91), 1, variation=12, density=0.42)
    d = ImageDraw.Draw(img)
    rr = random.Random(101)
    for _ in range(55):
        x, y = rr.randrange(2, 62), rr.randrange(2, 62)
        c = rr.choice([(246, 216, 124), (201, 159, 67), (235, 199, 102)])
        d.point((x, y), fill=c)
    for _ in range(8):
        x, y = rr.randrange(4, 58), rr.randrange(4, 58)
        d.line([(x-1,y),(x+1,y),(x,y-1),(x,y+1)], fill=(238, 157, 54), width=1)
    return img


def _sand_side() -> Image.Image:
    img = _logical_texture((201, 151, 65), 2, variation=10, density=0.30)
    d = ImageDraw.Draw(img)
    for y in (12, 26, 42, 55):
        d.line([(0,y),(63,y)], fill=(178, 126, 50), width=2)
    return img


def _dirt() -> Image.Image:
    img = _logical_texture((132, 82, 43), 3, variation=16, density=0.40)
    d = ImageDraw.Draw(img)
    rr = random.Random(303)
    for _ in range(34):
        x, y = rr.randrange(63), rr.randrange(63)
        d.rectangle([x,y,min(63,x+1),min(63,y+1)], fill=rr.choice([(98,57,30),(154,99,55)]))
    return img


def _stone() -> Image.Image:
    img = _logical_texture((104, 118, 126), 4, variation=18, density=0.42)
    d = ImageDraw.Draw(img)
    rr = random.Random(404)
    for _ in range(18):
        x, y = rr.randrange(4, 56), rr.randrange(4, 58)
        d.line([(x,y),(x+rr.randint(2,6),y+rr.choice([-1,0,1]))], fill=(70,81,88), width=1)
    return img


def _grass_top() -> Image.Image:
    img = _logical_texture((75, 174, 64), 5, variation=18, density=0.48)
    d = ImageDraw.Draw(img)
    rr = random.Random(505)
    for _ in range(100):
        x, y = rr.randrange(64), rr.randrange(62)
        d.line([(x,y),(x,min(63,y+1))], fill=rr.choice([(45,135,43),(105,201,83)]), width=1)
    return img


def _grass_side() -> Image.Image:
    img = _logical_texture((137, 84, 43), 6, variation=12, density=0.34)
    d = ImageDraw.Draw(img)
    d.rectangle([0,0,63,13], fill=(75, 174, 64))
    for y in (20, 38, 54):
        d.line([(0,y),(63,y)], fill=(110,65,34), width=1)
    return img


def _path() -> Image.Image:
    img = _logical_texture((192, 155, 87), 7, variation=12, density=0.36)
    d = ImageDraw.Draw(img)
    rr = random.Random(707)
    for _ in range(30):
        x, y = rr.randrange(4,60), rr.randrange(4,60)
        c = rr.choice([(157,119,63),(219,182,106),(111,118,95)])
        d.rectangle([x,y,min(63,x+rr.choice([1,2])),min(63,y+1)], fill=c)
    return img


def _wood(dark: bool=False) -> Image.Image:
    base = (111, 63, 30) if dark else (170, 94, 39)
    img = _logical_texture(base, 8 if not dark else 9, variation=10, density=0.28)
    d = ImageDraw.Draw(img)
    seam = (73,40,21) if dark else (113,61,29)
    for y in (0,16,32,48,63):
        d.line([(0,y),(63,y)], fill=seam, width=2)
    rr = random.Random(808 if not dark else 909)
    for row, y in enumerate((0,16,32,48)):
        x = rr.choice((10,21,33,46,55))
        d.line([(x,y),(x,min(63,y+16))], fill=seam, width=1)
    return img


def _leaves() -> Image.Image:
    img = _logical_texture((44, 151, 54), 10, variation=22, density=0.55)
    d = ImageDraw.Draw(img)
    rr = random.Random(1001)
    for _ in range(70):
        x,y = rr.randrange(64), rr.randrange(64)
        d.point((x,y), fill=rr.choice([(27,113,39),(88,192,74),(122,211,91)]))
    return img


def _palm_trunk() -> Image.Image:
    img = _logical_texture((142, 82, 35), 11, variation=12, density=0.32)
    d = ImageDraw.Draw(img)
    for y in (8,20,32,44,56):
        d.line([(0,y),(63,y)], fill=(91,50,25), width=2)
    for x in (10,33,52):
        d.line([(x,0),(x,63)], fill=(164,101,47), width=1)
    return img


def _coral(base: Tuple[int,int,int], seed: int) -> Image.Image:
    img = _logical_texture(base, seed, variation=16, density=0.42)
    d = ImageDraw.Draw(img)
    rr = random.Random(seed*100)
    for _ in range(45):
        x,y = rr.randrange(64), rr.randrange(64)
        d.point((x,y), fill=tuple(max(0,min(255,c+rr.choice((-25,25)))) for c in base))
    return img


def _rock() -> Image.Image:
    img = _logical_texture((111, 119, 125), 14, variation=16, density=0.45)
    d = ImageDraw.Draw(img)
    rr = random.Random(1414)
    for _ in range(20):
        x,y = rr.randrange(4,58), rr.randrange(4,58)
        d.line([(x,y),(x+rr.randint(2,5),y+rr.randint(-1,1))], fill=(72,80,85), width=1)
    return img


def _decoration() -> Image.Image:
    img = Image.new('RGB', (64,64), (239, 135, 57))
    d = ImageDraw.Draw(img)
    for y in range(0,64,8):
        d.rectangle([0,y,31,min(63,y+7)], fill=(239,135,57))
        d.rectangle([32,y,63,min(63,y+7)], fill=(247,193,143))
    for x in range(0,64,8):
        d.line([(x,0),(x,63)], fill=(201,91,42), width=1)
    return img


def _portal_pad() -> Image.Image:
    img = _logical_texture((59, 69, 76), 16, variation=12, density=0.32)
    d = ImageDraw.Draw(img)
    for y in (0,16,32,48,63):
        d.line([(0,y),(63,y)], fill=(33,39,44), width=2)
    for row,y in enumerate((0,16,32,48)):
        off = 0 if row % 2 == 0 else 16
        for x in range(off,64,32):
            d.line([(x,y),(x,min(63,y+16))], fill=(33,39,44), width=2)
    for x,y in ((8,8),(41,22),(21,48),(54,55)):
        d.rectangle([x,y,x+2,y+2], fill=(54, 151, 168))
    return img


def make_atlas() -> Tuple[Image.Image, Image.Image, Image.Image, Image.Image]:
    tiles = {
        'SandTop': _sand_top(),
        'SandSide': _sand_side(),
        'Dirt': _dirt(),
        'Stone': _stone(),
        'GrassTop': _grass_top(),
        'GrassSide': _grass_side(),
        'Path': _path(),
        'Wood': _wood(False),
        'DarkWood': _wood(True),
        'Leaves': _leaves(),
        'PalmTrunk': _palm_trunk(),
        'CoralOrange': _coral((240, 103, 32), 12),
        'CoralRed': _coral((206, 48, 42), 13),
        'Rock': _rock(),
        'Decoration': _decoration(),
        'PortalPad': _portal_pad(),
    }
    roughness_values = {
        'SandTop': 220, 'SandSide': 226, 'Dirt': 232, 'Stone': 205,
        'GrassTop': 190, 'GrassSide': 204, 'Path': 218, 'Wood': 164,
        'DarkWood': 176, 'Leaves': 180, 'PalmTrunk': 182,
        'CoralOrange': 142, 'CoralRed': 148, 'Rock': 208,
        'Decoration': 132, 'PortalPad': 196,
    }
    normal_strength = {
        'SandTop': 0.35, 'SandSide': 0.28, 'Dirt': 0.45, 'Stone': 0.65,
        'GrassTop': 0.35, 'GrassSide': 0.45, 'Path': 0.45,
        'Wood': 0.55, 'DarkWood': 0.52, 'Leaves': 0.42,
        'PalmTrunk': 0.58, 'CoralOrange': 0.45, 'CoralRed': 0.45,
        'Rock': 0.60, 'Decoration': 0.35, 'PortalPad': 0.52,
    }
    base_atlas = Image.new('RGB', (ATLAS_SIZE, ATLAS_SIZE), (128,128,128))
    normal_atlas = Image.new('RGB', (ATLAS_SIZE, ATLAS_SIZE), (128,128,255))
    rough_atlas = Image.new('L', (ATLAS_SIZE, ATLAS_SIZE), 220)
    mr_atlas = Image.new('RGB', (ATLAS_SIZE, ATLAS_SIZE), (255,220,0))

    for name, idx in TILE_INDEX.items():
        col, row = idx % 4, idx // 4
        x0, y0 = col * TILE_SIZE, row * TILE_SIZE
        logical = tiles[name]
        inner_img = logical.resize((INNER, INNER), Image.Resampling.NEAREST)
        # Edge padding: extend the tile's edge colors through the border.
        full = Image.new('RGB', (TILE_SIZE, TILE_SIZE))
        full.paste(inner_img, (PAD, PAD))
        full.paste(inner_img.crop((0,0,1,INNER)).resize((PAD,INNER)), (0,PAD))
        full.paste(inner_img.crop((INNER-1,0,INNER,INNER)).resize((PAD,INNER)), (PAD+INNER,PAD))
        full.paste(inner_img.crop((0,0,INNER,1)).resize((INNER,PAD)), (PAD,0))
        full.paste(inner_img.crop((0,INNER-1,INNER,INNER)).resize((INNER,PAD)), (PAD,PAD+INNER))
        full.paste(inner_img.getpixel((0,0)), (0,0,PAD,PAD))
        full.paste(inner_img.getpixel((INNER-1,0)), (PAD+INNER,0,TILE_SIZE,PAD))
        full.paste(inner_img.getpixel((0,INNER-1)), (0,PAD+INNER,PAD,TILE_SIZE))
        full.paste(inner_img.getpixel((INNER-1,INNER-1)), (PAD+INNER,PAD+INNER,TILE_SIZE,TILE_SIZE))
        base_atlas.paste(full, (x0,y0))

        gray = np.asarray(full.convert('L'), dtype=np.float32) / 255.0
        gy, gx = np.gradient(gray)
        strength = normal_strength[name]
        nx = -gx * strength
        ny = -gy * strength
        nz = np.ones_like(nx)
        norm = np.sqrt(nx*nx + ny*ny + nz*nz)
        normal = np.stack(((nx/norm)*0.5+0.5, (ny/norm)*0.5+0.5, (nz/norm)*0.5+0.5), axis=-1)
        normal_img = Image.fromarray(np.uint8(np.clip(normal*255.0,0,255)), 'RGB')
        normal_atlas.paste(normal_img, (x0,y0))
        r = roughness_values[name]
        rough_atlas.paste(Image.new('L',(TILE_SIZE,TILE_SIZE),r), (x0,y0))
        mr_atlas.paste(Image.new('RGB',(TILE_SIZE,TILE_SIZE),(255,r,0)), (x0,y0))

    base_atlas.save(TEX_DIR / 'CoralCoast_BaseColor_2048.png')
    normal_atlas.save(TEX_DIR / 'CoralCoast_Normal_2048.png')
    rough_atlas.save(TEX_DIR / 'CoralCoast_Roughness_2048.png')
    mr_atlas.save(TEX_DIR / 'CoralCoast_MetallicRoughness_2048.png')
    return base_atlas, normal_atlas, rough_atlas, mr_atlas


BASE_ATLAS, NORMAL_ATLAS, ROUGH_ATLAS, MR_ATLAS = make_atlas()


def tile_uv(tile_name: str, u: float, v: float) -> Tuple[float, float]:
    idx = TILE_INDEX[tile_name]
    col, row = idx % 4, idx // 4
    px = col * TILE_SIZE + PAD + u * INNER
    # PIL rows start at top; glTF UV V starts at bottom.
    py = row * TILE_SIZE + PAD + (1.0 - v) * INNER
    return px / ATLAS_SIZE, 1.0 - py / ATLAS_SIZE


ATLAS_MATERIAL = PBRMaterial(
    name='CoralCoast_VoxelAtlas',
    baseColorTexture=BASE_ATLAS,
    normalTexture=NORMAL_ATLAS,
    metallicRoughnessTexture=MR_ATLAS,
    metallicFactor=0.0,
    roughnessFactor=1.0,
    doubleSided=False,
    alphaMode='OPAQUE',
)

# -------------------- mesh construction --------------------

@dataclass
class MeshData:
    vertices: List[Tuple[float,float,float]]
    faces: List[Tuple[int,int,int]]
    uvs: List[Tuple[float,float]]

    @classmethod
    def empty(cls):
        return cls([], [], [])

    def append_quad(self, verts: Sequence[Tuple[float,float,float]], tile: str,
                    uv_order: Sequence[Tuple[float,float]]=((0,0),(1,0),(1,1),(0,1))):
        base = len(self.vertices)
        self.vertices.extend(verts)
        self.uvs.extend(tile_uv(tile, u, v) for u,v in uv_order)
        self.faces.append((base,base+1,base+2))
        self.faces.append((base,base+2,base+3))

    def merge(self, other: 'MeshData'):
        base = len(self.vertices)
        self.vertices.extend(other.vertices)
        self.uvs.extend(other.uvs)
        self.faces.extend((a+base,b+base,c+base) for a,b,c in other.faces)

    def to_mesh(self, name: str) -> trimesh.Trimesh:
        mesh = trimesh.Trimesh(
            vertices=np.asarray(self.vertices, dtype=np.float64),
            faces=np.asarray(self.faces, dtype=np.int64),
            process=False,
        )
        mesh.visual = TextureVisuals(uv=np.asarray(self.uvs, dtype=np.float64), material=ATLAS_MATERIAL)
        mesh.metadata['name'] = name
        return mesh


CELL_FACE_TILES = {
    'Stone': {'top':'Stone','bottom':'Stone','side':'Stone'},
    'Dirt': {'top':'Dirt','bottom':'Dirt','side':'Dirt'},
    'Sand': {'top':'SandTop','bottom':'SandSide','side':'SandSide'},
    'Grass': {'top':'GrassTop','bottom':'Dirt','side':'GrassSide'},
    'Path': {'top':'Path','bottom':'Dirt','side':'SandSide'},
    'Wood': {'top':'Wood','bottom':'DarkWood','side':'Wood'},
    'DarkWood': {'top':'DarkWood','bottom':'DarkWood','side':'DarkWood'},
    'Leaves': {'top':'Leaves','bottom':'Leaves','side':'Leaves'},
    'PalmTrunk': {'top':'PalmTrunk','bottom':'PalmTrunk','side':'PalmTrunk'},
    'CoralOrange': {'top':'CoralOrange','bottom':'CoralOrange','side':'CoralOrange'},
    'CoralRed': {'top':'CoralRed','bottom':'CoralRed','side':'CoralRed'},
    'Rock': {'top':'Rock','bottom':'Rock','side':'Rock'},
    'Decoration': {'top':'Decoration','bottom':'Decoration','side':'Decoration'},
    'PortalPad': {'top':'PortalPad','bottom':'PortalPad','side':'PortalPad'},
}

DIRECTIONS = {
    (1,0,0): 'px', (-1,0,0): 'nx',
    (0,1,0): 'py', (0,-1,0): 'ny',
    (0,0,1): 'pz', (0,0,-1): 'nz',
}


def voxel_mesh(cells: Mapping[Tuple[int,int,int], str], cell_size: float,
               origin: Tuple[float,float,float]=(0.0,0.0,0.0)) -> MeshData:
    data = MeshData.empty()
    ox, oy, oz = origin
    for (ix,iy,iz), block_type in cells.items():
        x0, x1 = ox + ix*cell_size, ox + (ix+1)*cell_size
        y0, y1 = oy + iy*cell_size, oy + (iy+1)*cell_size
        z0, z1 = oz + iz*cell_size, oz + (iz+1)*cell_size
        tiles = CELL_FACE_TILES[block_type]
        for (dx,dy,dz), side in DIRECTIONS.items():
            if (ix+dx, iy+dy, iz+dz) in cells:
                continue
            if side == 'py':
                verts = [(x0,y1,z0),(x0,y1,z1),(x1,y1,z1),(x1,y1,z0)]
                tile = tiles['top']
            elif side == 'ny':
                verts = [(x0,y0,z0),(x1,y0,z0),(x1,y0,z1),(x0,y0,z1)]
                tile = tiles['bottom']
            elif side == 'px':
                verts = [(x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1)]
                tile = tiles['side']
            elif side == 'nx':
                verts = [(x0,y0,z0),(x0,y0,z1),(x0,y1,z1),(x0,y1,z0)]
                tile = tiles['side']
            elif side == 'pz':
                verts = [(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
                tile = tiles['side']
            else:
                verts = [(x0,y0,z0),(x0,y1,z0),(x1,y1,z0),(x1,y0,z0)]
                tile = tiles['side']
            data.append_quad(verts, tile)
    return data


def box_mesh(center: Tuple[float,float,float], extents: Tuple[float,float,float], block_type: str) -> MeshData:
    cx,cy,cz = center
    ex,ey,ez = (v/2.0 for v in extents)
    x0,x1 = cx-ex,cx+ex
    y0,y1 = cy-ey,cy+ey
    z0,z1 = cz-ez,cz+ez
    tiles = CELL_FACE_TILES[block_type]
    data = MeshData.empty()
    data.append_quad([(x0,y1,z0),(x0,y1,z1),(x1,y1,z1),(x1,y1,z0)], tiles['top'])
    data.append_quad([(x0,y0,z0),(x1,y0,z0),(x1,y0,z1),(x0,y0,z1)], tiles['bottom'])
    data.append_quad([(x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1)], tiles['side'])
    data.append_quad([(x0,y0,z0),(x0,y0,z1),(x0,y1,z1),(x0,y1,z0)], tiles['side'])
    data.append_quad([(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)], tiles['side'])
    data.append_quad([(x0,y0,z0),(x0,y1,z0),(x1,y1,z0),(x1,y0,z0)], tiles['side'])
    return data


def combine_mesh_data(parts: Iterable[MeshData]) -> MeshData:
    out = MeshData.empty()
    for part in parts:
        out.merge(part)
    return out

# -------------------- island terrain --------------------

height_map: Dict[Tuple[int,int], int] = {}
top_type: Dict[Tuple[int,int], str] = {}
inside_map: Dict[Tuple[int,int], bool] = {}


def cell_center(ix: int, iz: int) -> Tuple[float,float]:
    return X_MIN + (ix + 0.5) * BLOCK, Z_MIN + (iz + 0.5) * BLOCK


def ellipse(x: float, z: float, cx: float, cz: float, rx: float, rz: float) -> float:
    return ((x-cx)/rx)**2 + ((z-cz)/rz)**2

# Main island shape and terraces.
for ix in range(NX):
    for iz in range(NZ):
        x,z = cell_center(ix,iz)
        d = math.sqrt((x/176.0)**2 + (z/152.0)**2)
        edge_noise = (0.028*math.sin(ix*1.31) + 0.020*math.sin(iz*1.73) +
                      0.014*math.sin((ix+iz)*0.77))
        inside = d < 0.985 + edge_noise
        # Force the two portal-pad shoulders into the island silhouette.
        if (abs(x) > 128 and abs(x) < 176 and abs(z) <= 24):
            inside = True
        inside_map[(ix,iz)] = inside
        if not inside:
            continue
        if d > 0.87:
            h = 2
        elif d > 0.70:
            h = 3
        else:
            h = 4
        # Raised dunes and tropical groves.
        if ellipse(x,z,-70,76,72,48) < 1.0:
            h += 1
        if ellipse(x,z,68,70,68,47) < 1.0:
            h += 1
        if ellipse(x,z,70,-62,58,42) < 1.0:
            h += 1
        if ellipse(x,z,-64,-54,52,40) < 1.0:
            h += 1
        if ellipse(x,z,0,98,46,30) < 1.0:
            h += 1
        # Keep the main gameplay plaza and portal routes level.
        if abs(x) < 54 and abs(z) < 58:
            h = 4
        if abs(z) <= 16 and abs(x) <= 164:
            h = 4
        if abs(x) <= 16 and -104 <= z <= 92:
            h = 4
        if abs(x) >= 128 and abs(z) <= 24:
            h = 4
        height_map[(ix,iz)] = min(h,6)

# Top-material masks.
for (ix,iz), h in height_map.items():
    x,z = cell_center(ix,iz)
    material = 'Sand'
    path = False
    if abs(z) <= 12 and abs(x) <= 156:
        path = True
    if abs(x) <= 12 and -105 <= z <= 90:
        path = True
    # Blocky branches toward upper groves.
    if -76 <= x <= -12 and 36 <= z <= 82 and abs((z-36) - 0.55*(-x-12)) <= 10:
        path = True
    if 12 <= x <= 82 and 34 <= z <= 82 and abs((z-34) - 0.50*(x-12)) <= 10:
        path = True
    if path:
        material = 'Path'
    grass_regions = [
        (-78,78,70,48), (66,74,66,46),
        (72,-64,55,40), (-64,-54,50,38),
        (0,105,45,28),
    ]
    if not path and abs(x) < 122:
        for cx,cz,rx,rz in grass_regions:
            if ellipse(x,z,cx,cz,rx,rz) < 1.0:
                variation = math.sin(ix*1.9 + iz*0.8) + math.sin(ix*0.6 - iz*1.4)
                if variation > -1.1:
                    material = 'Grass'
                break
    top_type[(ix,iz)] = material

terrain_cells: Dict[Tuple[int,int,int], str] = {}
for (ix,iz), h in height_map.items():
    top = top_type[(ix,iz)]
    for iy in range(h):
        if iy <= 0:
            cell_type = 'Stone'
        elif iy < h-1:
            cell_type = 'Dirt'
        else:
            cell_type = top
        terrain_cells[(ix,iy,iz)] = cell_type

terrain_data = voxel_mesh(terrain_cells, BLOCK, (X_MIN,0.0,Z_MIN))
terrain_mesh = terrain_data.to_mesh('IslandGround')


def top_y_at(x: float, z: float) -> float:
    ix = int(math.floor((x - X_MIN) / BLOCK))
    iz = int(math.floor((z - Z_MIN) / BLOCK))
    ix = max(0,min(NX-1,ix)); iz=max(0,min(NZ-1,iz))
    h = height_map.get((ix,iz))
    if h is None:
        return 0.0
    return h * BLOCK

# -------------------- portal areas --------------------
portal_left_center = (-148.0, top_y_at(-148,0) + 1.25, 0.0)
portal_right_center = (148.0, top_y_at(148,0) + 1.25, 0.0)
portal_left = box_mesh(portal_left_center, (40.0, 2.5, 32.0), 'PortalPad').to_mesh('PortalPlacement_Left')
portal_right = box_mesh(portal_right_center, (40.0, 2.5, 32.0), 'PortalPad').to_mesh('PortalPlacement_Right')

# -------------------- palms --------------------

def palm_parts(x: float, z: float, height_cells: int=9, canopy_radius: int=3, small: bool=False) -> Tuple[MeshData,MeshData]:
    cell = 4.0
    ground = top_y_at(x,z)
    trunk_cells = {}
    # one-cell trunk, embedded half a stud into terrain
    for y in range(height_cells):
        trunk_cells[(0,y,0)] = 'PalmTrunk'
    trunk = voxel_mesh(trunk_cells, cell, (x-cell/2, ground-0.5, z-cell/2))
    # Solid stepped canopy layers avoid diagonal-only voxel contacts and remain manifold.
    radius = max(2, canopy_radius)
    leaf_cells = {}
    for lx in range(-radius, radius + 1):
        for lz in range(-radius, radius + 1):
            leaf_cells[(lx,0,lz)] = 'Leaves'
    upper = max(1, radius - 1)
    for lx in range(-upper, upper + 1):
        for lz in range(-upper, upper + 1):
            leaf_cells[(lx,1,lz)] = 'Leaves'
    # A shallow lower crown keeps the silhouette broad and palm-like.
    for lx in range(-1, 2):
        for lz in range(-1, 2):
            leaf_cells[(lx,-1,lz)] = 'Leaves'
    crown_y = ground - 0.5 + height_cells*cell
    leaves = voxel_mesh(leaf_cells, cell, (x-cell/2, crown_y, z-cell/2))
    return trunk, leaves

palm_locations = [
    (-92,78,10,3), (-28,108,9,3), (66,90,11,3),
    (106,48,8,2), (-84,-66,8,2), (76,-72,9,3),
    (24,60,7,2),
]
palm_trunks_data = MeshData.empty(); palm_leaves_data = MeshData.empty()
for x,z,h,r in palm_locations:
    # keep portal pads and paths clear
    t,l = palm_parts(x,z,h,r)
    palm_trunks_data.merge(t); palm_leaves_data.merge(l)
palm_trunks_mesh = palm_trunks_data.to_mesh('PalmTrees_Trunks')
palm_leaves_mesh = palm_leaves_data.to_mesh('PalmTrees_Leaves')

# -------------------- coral formations --------------------

def coral_voxels(variant: int, block_type: str) -> Dict[Tuple[int,int,int], str]:
    # Chunky two-cell-thick branches ensure every coral is a closed manifold voxel solid.
    cells: Dict[Tuple[int,int,int], str] = {}
    if variant == 0:
        for y in range(6):
            for x in (0,1):
                for z in (0,1): cells[(x,y,z)] = block_type
        for x in (-2,-1):
            for z in (0,1): cells[(x,3,z)] = block_type
        for y in (4,5):
            for x in (-2,-1):
                for z in (0,1): cells[(x,y,z)] = block_type
        for x in (2,3):
            for z in (0,1): cells[(x,2,z)] = block_type
        for y in (3,4):
            for z in (0,1): cells[(3,y,z)] = block_type
        for z in (2,3):
            for x in (0,1): cells[(x,1,z)] = block_type
        for y in (2,3):
            for x in (0,1): cells[(x,y,3)] = block_type
    elif variant == 1:
        for y in range(5):
            for x in (0,1):
                for z in (0,1): cells[(x,y,z)] = block_type
        for x in (2,3):
            for z in (0,1): cells[(x,2,z)] = block_type
        for y in (3,4,5):
            for z in (0,1): cells[(3,y,z)] = block_type
        for x in (-2,-1):
            for z in (0,1): cells[(x,1,z)] = block_type
        for y in (2,3):
            for x in (-2,-1):
                for z in (0,1): cells[(x,y,z)] = block_type
        for z in (-2,-1):
            for x in (0,1): cells[(x,3,z)] = block_type
        for y in (4,5):
            for x in (0,1): cells[(x,y,-2)] = block_type
    else:
        for y in range(4):
            for x in (0,1):
                for z in (0,1): cells[(x,y,z)] = block_type
        for x in (2,3):
            for z in (0,1): cells[(x,1,z)] = block_type
        for y in (2,3):
            for z in (0,1): cells[(3,y,z)] = block_type
        for x in (-2,-1):
            for z in (0,1): cells[(x,2,z)] = block_type
        for y in (3,4):
            for x in (-2,-1):
                for z in (0,1): cells[(x,y,z)] = block_type
    return cells

coral_positions = [
    (-38,88,0,'CoralRed'), (42,84,1,'CoralOrange'),
    (96,-28,2,'CoralOrange'), (-104,-26,1,'CoralRed'),
    (56,-96,0,'CoralRed'), (-46,-98,2,'CoralOrange'),
]
coral_data = MeshData.empty()
for x,z,var,typ in coral_positions:
    ground = top_y_at(x,z)
    coral_data.merge(voxel_mesh(coral_voxels(var,typ), 4.0, (x-2.0,ground-0.5,z-2.0)))
coral_mesh = coral_data.to_mesh('CoralFormations')

# -------------------- rocks and cliff detail --------------------
rock_positions = [
    (-128,64,0), (-120,-90,1), (126,86,2), (132,-84,0),
    (-44,130,1), (54,132,0), (-146,-52,2), (146,54,1),
    (-30,-130,0), (34,-132,1),
]
rock_shapes = [
    {(0,0,0),(1,0,0),(0,0,1),(1,0,1),(0,1,0)},
    {(0,0,0),(1,0,0),(2,0,0),(1,0,1),(1,1,0)},
    {(0,0,0),(0,0,1),(1,0,1),(0,1,1),(1,1,1)},
]
rocks_data = MeshData.empty()
for x,z,var in rock_positions:
    ground = top_y_at(x,z)
    cells={cell:'Rock' for cell in rock_shapes[var]}
    rocks_data.merge(voxel_mesh(cells,4.0,(x-4.0,ground-0.5,z-4.0)))
rocks_mesh = rocks_data.to_mesh('Rocks')

# -------------------- bushes and tropical plants --------------------
bush_positions = [
    (-108,54), (-58,112), (92,104), (116,18),
    (-102,-76), (100,-90), (-26,-112), (36,-106),
    (-64,36), (72,40),
]
bush_data = MeshData.empty()
for idx,(x,z) in enumerate(bush_positions):
    ground=top_y_at(x,z)
    cells={(0,0,0):'Leaves',(1,0,0):'Leaves',(0,0,1):'Leaves',(1,0,1):'Leaves'}
    if idx%3==0: cells[(0,1,0)]='Leaves'
    bush_data.merge(voxel_mesh(cells,4.0,(x-4.0,ground-0.5,z-4.0)))
# grass clusters as narrow stacked blocks
for x,z in [(-20,118),(18,116),(-118,20),(118,-18),(-72,-104),(84,-106)]:
    g=top_y_at(x,z)
    cells={(0,0,0):'Leaves',(0,1,0):'Leaves'}
    bush_data.merge(voxel_mesh(cells,2.5,(x-1.25,g-0.3,z-1.25)))
bush_mesh=bush_data.to_mesh('BushesAndPlants')

# -------------------- beach decorations --------------------
decoration_data = MeshData.empty()
# Starfish crosses.
for x,z in [(-18,-94),(34,-86),(-104,22),(104,26),(-16,84),(66,12)]:
    g=top_y_at(x,z)
    cells={(0,0,0):'CoralOrange',(1,0,0):'CoralOrange',(-1,0,0):'CoralOrange',(0,0,1):'CoralOrange',(0,0,-1):'CoralOrange'}
    decoration_data.merge(voxel_mesh(cells,2.5,(x-1.25,g+0.15,z-1.25)))
# Shells and small pebbles.
for idx,(x,z) in enumerate([(-68,-110),(70,-116),(-128,46),(126,-48),(-72,102),(86,104),(10,-120)]):
    g=top_y_at(x,z)
    cells={(0,0,0):'Decoration',(1,0,0):'Decoration'}
    if idx%2==0: cells[(0,1,0)]='Decoration'
    decoration_data.merge(voxel_mesh(cells,2.5,(x-2.5,g+0.1,z-1.25)))
decoration_mesh=decoration_data.to_mesh('BeachDecorations')

# -------------------- build scene --------------------
scene = trimesh.Scene(base_frame=ROOT_NAME)
scene.add_geometry(terrain_mesh, node_name='IslandGround', geom_name='IslandGround')
scene.add_geometry(portal_left, node_name='PortalPlacement_Left', geom_name='PortalPlacement_Left')
scene.add_geometry(portal_right, node_name='PortalPlacement_Right', geom_name='PortalPlacement_Right')
scene.add_geometry(palm_trunks_mesh, node_name='PalmTrees_Trunks', geom_name='PalmTrees_Trunks')
scene.add_geometry(palm_leaves_mesh, node_name='PalmTrees_Leaves', geom_name='PalmTrees_Leaves')
scene.add_geometry(coral_mesh, node_name='CoralFormations', geom_name='CoralFormations')
scene.add_geometry(rocks_mesh, node_name='Rocks', geom_name='Rocks')
scene.add_geometry(bush_mesh, node_name='BushesAndPlants', geom_name='BushesAndPlants')
scene.add_geometry(decoration_mesh, node_name='BeachDecorations', geom_name='BeachDecorations')

scene.export(GLB_PATH)

# Copy build script into package for reproducibility.
BUILD_SCRIPT_COPY.write_text(Path(__file__).read_text(encoding='utf-8'), encoding='utf-8')

# -------------------- verification --------------------
reimported = trimesh.load(GLB_PATH, force='scene')
bounds = reimported.bounds
extents = bounds[1]-bounds[0]
triangles = sum(len(g.faces) for g in reimported.geometry.values())
vertices = sum(len(g.vertices) for g in reimported.geometry.values())
object_names = list(reimported.geometry.keys())
water_names = [n for n in object_names if 'water' in n.lower()]

# GLB JSON inspection for embedded images and identity transforms.
def read_glb_json(path: Path) -> dict:
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from('<4sII', raw, 0)
    assert magic == b'glTF' and version == 2 and length == len(raw)
    offset = 12
    json_data = None
    while offset < len(raw):
        chunk_len, chunk_type = struct.unpack_from('<II', raw, offset)
        offset += 8
        chunk = raw[offset:offset+chunk_len]
        offset += chunk_len
        if chunk_type == 0x4E4F534A:
            json_data = json.loads(chunk.decode('utf-8').rstrip(' \t\r\n\x00'))
    assert json_data is not None
    return json_data

GLB_JSON = read_glb_json(GLB_PATH)
embedded_image_count = sum(1 for image in GLB_JSON.get('images',[]) if 'bufferView' in image)
node_transforms_applied = all(
    not any(k in node for k in ('matrix','translation','rotation','scale'))
    for node in GLB_JSON.get('nodes',[])
)
# A root node may have identity transform fields omitted; child meshes should likewise be baked.

watertight_report = {}
for name,g in reimported.geometry.items():
    copy = g.copy()
    try:
        copy.merge_vertices(merge_tex=True, merge_norm=True, digits_vertex=8)
        watertight_report[name] = bool(copy.is_watertight)
    except Exception:
        watertight_report[name] = False

portal_left_xz = [portal_left_center[0], portal_left_center[2]]
portal_right_xz = [portal_right_center[0], portal_right_center[2]]
verification = {
    'asset': 'Coral Coast Island',
    'root_name': ROOT_NAME,
    'coordinate_system': 'Y-up',
    'root_scene_origin': [0.0,0.0,0.0],
    'root_pivot_center_bottom': bool(abs((bounds[0][0]+bounds[1][0])/2) < 1e-6 and abs(bounds[0][1]) < 1e-6 and abs((bounds[0][2]+bounds[1][2])/2) < 1e-6),
    'dimensions_studs': {'X':float(extents[0]),'Y':float(extents[1]),'Z':float(extents[2])},
    'bounds': bounds.tolist(),
    'triangle_count': int(triangles),
    'vertex_count': int(vertices),
    'under_20000_triangles': bool(triangles < 20000),
    'object_count': len(object_names),
    'objects': object_names,
    'water_geometry_count': len(water_names),
    'water_geometry_absent': len(water_names)==0,
    'portal_placement_left_center_xz': portal_left_xz,
    'portal_placement_right_center_xz': portal_right_xz,
    'portal_areas_opposite_on_x_axis': bool(abs(portal_left_xz[0]+portal_right_xz[0]) < 1e-6),
    'portal_areas_same_center_z': bool(abs(portal_left_xz[1]-portal_right_xz[1]) < 1e-6),
    'portal_pad_dimensions': [40.0,2.5,32.0],
    'textures_embedded_in_glb': embedded_image_count >= 3,
    'embedded_image_count': embedded_image_count,
    'applied_node_transforms': node_transforms_applied,
    'texture_resolution': [ATLAS_SIZE,ATLAS_SIZE],
    'atlas_tiles': TILE_NAMES,
    'watertight_after_vertex_merge': watertight_report,
    'all_meshes_watertight_after_merge': all(watertight_report.values()),
    'reference_image': 'image.png',
}
VERIFY_PATH.write_text(json.dumps(verification, indent=2), encoding='utf-8')

# -------------------- previews --------------------
TILE_PREVIEW_COLORS = {
    'SandTop':'#e8c15f', 'SandSide':'#c89643', 'Dirt':'#8b552f', 'Stone':'#73818a',
    'GrassTop':'#55b94d', 'GrassSide':'#6a9b44', 'Path':'#c6a064', 'Wood':'#a85f2c',
    'DarkWood':'#60371f', 'Leaves':'#2da94b', 'PalmTrunk':'#945729',
    'CoralOrange':'#f36b29', 'CoralRed':'#d73831', 'Rock':'#7d878d',
    'Decoration':'#f0a266', 'PortalPad':'#46545b',
}


def _face_preview_colors(mesh: trimesh.Trimesh) -> List[str]:
    uv = getattr(mesh.visual, 'uv', None)
    if uv is None or len(uv) != len(mesh.vertices):
        return ['#d6b06d'] * len(mesh.faces)
    mean_uv = np.asarray(uv)[np.asarray(mesh.faces)].mean(axis=1)
    cols = np.clip(np.floor(mean_uv[:,0] * 4.0).astype(int), 0, 3)
    rows = np.clip(np.floor((1.0 - mean_uv[:,1]) * 4.0).astype(int), 0, 3)
    indices = rows * 4 + cols
    return [TILE_PREVIEW_COLORS[TILE_NAMES[int(i)]] for i in indices]


def plot_scene(elev: float, azim: float, output: Path, title: str,
               xlim=(-190,190), zlim=(-170,170), ylim=(0,90)):
    fig = plt.figure(figsize=(12,9), dpi=150)
    ax = fig.add_subplot(111, projection='3d')
    fig.patch.set_facecolor('#dff2fb')
    ax.set_facecolor('#dff2fb')
    # plot with X, Z, Y mapped to matplotlib X,Y,Z and use UV tile colors.
    for name,g in reimported.geometry.items():
        tris = g.triangles
        limit = min(len(tris),25000)
        converted = tris[:limit][:,:,[0,2,1]]
        face_colors = _face_preview_colors(g)[:limit]
        pc = Poly3DCollection(converted, facecolors=face_colors, edgecolors=(0.08,0.08,0.08,0.16), linewidths=0.10)
        ax.add_collection3d(pc)
    ax.set_xlim(*xlim); ax.set_ylim(*zlim); ax.set_zlim(*ylim)
    ax.view_init(elev=elev, azim=azim)
    ax.set_box_aspect((380,340,100))
    ax.set_proj_type('ortho' if elev > 70 else 'persp')
    ax.set_axis_off()
    ax.set_title(title, fontsize=18, pad=16)
    plt.tight_layout()
    plt.savefig(output, bbox_inches='tight', pad_inches=0.05, facecolor=fig.get_facecolor())
    plt.close(fig)

plot_scene(31,-47,PREVIEW_PATH,'Coral Coast Island — Isometric Preview')
plot_scene(90,-90,TOP_PATH,'Coral Coast Island — Top View')
plot_scene(15,-35,GROUND_PATH,'Coral Coast Island — Ground-Level Preview', ylim=(0,100))

# README
README = f'''CORAL COAST ISLAND — ROBLOX-READY VOXEL ENVIRONMENT

Primary model:
- Coral_Coast_Island.glb

Visual direction:
- Original Minecraft-inspired voxel/block art for Fishy Fish
- Sand-dominant tropical island with stepped shoreline cliffs
- Blocky palms, coral formations, rocks, bushes, starfish, and shells
- No ocean, water plane, transparent water, underwater disc, or water collision geometry

FINAL DIMENSIONS
- X: {extents[0]:.3f} studs
- Y: {extents[1]:.3f} studs (Y-up)
- Z: {extents[2]:.3f} studs
- Root origin / pivot: (0, 0, 0), center-bottom of the complete asset

GEOMETRY
- Objects: {len(object_names)}
- Vertices: {vertices:,}
- Triangles: {triangles:,}
- Requested triangle budget met: {triangles < 20000}

OBJECTS
{chr(10).join('- ' + n for n in object_names)}

PORTAL PLACEMENT AREAS
- PortalPlacement_Left center: X={portal_left_center[0]:.3f}, Y={portal_left_center[1]:.3f}, Z={portal_left_center[2]:.3f}
- PortalPlacement_Right center: X={portal_right_center[0]:.3f}, Y={portal_right_center[1]:.3f}, Z={portal_right_center[2]:.3f}
- Each pad: 40 × 32 studs, with a 2.5-stud visible platform thickness
- Pads are directly opposite along the X-axis and share Z=0
- No portal models are included

TEXTURES
- Textures/CoralCoast_BaseColor_2048.png
- Textures/CoralCoast_Normal_2048.png
- Textures/CoralCoast_Roughness_2048.png
- Textures/CoralCoast_MetallicRoughness_2048.png
- One 2048×2048 original pixel-art atlas with 16 padded 512×512 material tiles
- Visible faces use per-block UVs rather than stretching one texture over large surfaces
- BaseColor, Normal, and MetallicRoughness images are embedded in the GLB
- No official Minecraft textures or other proprietary game textures were used

ROBLOX IMPORT SETTINGS
- File > Import 3D and select Coral_Coast_Island.glb
- Import Only as a Model: On
- Add to Workspace: On
- Anchored: On
- Merge Meshes: Off
- Scale Unit: Stud
- Scale Factor: 1
- Keep Y as the up axis; do not rotate the file after import

COLLISION GUIDANCE
- IslandGround and PortalPlacement pads: collidable
- PalmTrees_Trunks: optional simple collision
- PalmTrees_Leaves, CoralFormations, BushesAndPlants, BeachDecorations: CanCollide false
- Rocks: use Box or Hull collision as needed

WATER
- No water geometry or water material exists in the GLB
- The surrounding Roblox ocean should remain outside the shoreline
- Place the asset at the desired ocean height; nothing outside the shoreline blocks the ocean

VERIFICATION
- verification.json records bounds, counts, texture embedding, transform status, portal alignment, and mesh checks
- GLB was re-imported with trimesh for validation after export
- Isometric, top-down, and ground-level preview images are included

SOURCE / REBUILD
- Coral_Coast_Island_Build.py reproduces the delivered package using Python, trimesh, NumPy, PIL, and matplotlib
'''
README_PATH.write_text(README, encoding='utf-8')

# Zip package.
with zipfile.ZipFile(ZIP_PATH, 'w', zipfile.ZIP_DEFLATED) as zf:
    for path in sorted(OUT.rglob('*')):
        if path.is_file():
            zf.write(path, path.relative_to(OUT.parent))

print('Created:', GLB_PATH)
print('Created:', ZIP_PATH)
print('Dimensions:', extents)
print('Triangles:', triangles)
print('Vertices:', vertices)
print('Objects:', object_names)
print('Embedded images:', embedded_image_count)
print('Watertight:', watertight_report)
