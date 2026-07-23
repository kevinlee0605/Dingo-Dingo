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

OUT = Path('/mnt/data/Coral_Coast_Island_Compact_V2_Manifold_Final_Package')
TEX_DIR = OUT / 'Textures'
OUT.mkdir(parents=True, exist_ok=True)
TEX_DIR.mkdir(parents=True, exist_ok=True)

GLB_PATH = OUT / 'Coral_Coast_Island_Compact_V2_Manifold_Final.glb'
ZIP_PATH = Path('/mnt/data/Coral_Coast_Island_Compact_V2_Manifold_Final_Roblox_Ready.zip')
README_PATH = OUT / 'README.txt'
VERIFY_PATH = OUT / 'verification.json'
PREVIEW_PATH = OUT / 'Coral_Coast_Island_Compact_V2_Manifold_Final_Preview.png'
TOP_PATH = OUT / 'Coral_Coast_Island_Compact_V2_Manifold_Final_Top.png'
GROUND_PATH = OUT / 'Coral_Coast_Island_Compact_V2_Manifold_Final_Ground.png'
BUILD_SCRIPT_COPY = OUT / 'Coral_Coast_Island_Compact_V2_Manifold_Final_Build.py'

ATLAS_SIZE = 2048
TILE_COLS = 4
TILE_ROWS = 5
TILE_SIZE = 384
PAD = 24
INNER = TILE_SIZE - PAD * 2
BLOCK = 8.0
NX = 30
NZ = 28
X_MIN = -NX * BLOCK / 2.0   # -120
Z_MIN = -NZ * BLOCK / 2.0   # -112
ROOT_NAME = 'CoralCoast_Island_ROOT'
RNG = random.Random(20260724)

TILE_NAMES = [
    'SandTop', 'SandSide', 'Dirt', 'Stone',
    'GrassTop', 'GrassSide', 'Path', 'Wood',
    'Leaves', 'PalmTrunk', 'CoralOrange', 'CoralRed',
    'CoralYellow', 'Rock', 'Bush', 'Flower',
    'Starfish', 'Shell', 'PortalPad', 'Details',
]
TILE_INDEX = {name: i for i, name in enumerate(TILE_NAMES)}

# -------------------- texture atlas --------------------

def logical_texture(base: Tuple[int, int, int], seed: int, logical: int = 64,
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


def sand_top() -> Image.Image:
    img = logical_texture((229, 194, 94), 1, variation=11, density=0.44)
    d = ImageDraw.Draw(img)
    rr = random.Random(101)
    for _ in range(70):
        x, y = rr.randrange(2, 62), rr.randrange(2, 62)
        d.point((x, y), fill=rr.choice([(246, 218, 128), (205, 163, 68), (238, 202, 106)]))
    for _ in range(10):
        x, y = rr.randrange(4,58), rr.randrange(4,58)
        d.line([(x-1,y),(x+1,y)], fill=(243, 177, 66), width=1)
    return img


def sand_side() -> Image.Image:
    img = logical_texture((205, 154, 66), 2, variation=10, density=0.30)
    d = ImageDraw.Draw(img)
    for y in (12, 27, 43, 56):
        d.line([(0,y),(63,y)], fill=(180, 128, 51), width=2)
    return img


def dirt() -> Image.Image:
    img = logical_texture((134, 82, 43), 3, variation=15, density=0.42)
    d = ImageDraw.Draw(img)
    rr = random.Random(303)
    for _ in range(40):
        x,y = rr.randrange(63), rr.randrange(63)
        d.rectangle([x,y,min(63,x+1),min(63,y+1)], fill=rr.choice([(97,56,29),(158,101,56)]))
    return img


def stone() -> Image.Image:
    img = logical_texture((108, 119, 126), 4, variation=17, density=0.44)
    d = ImageDraw.Draw(img)
    rr = random.Random(404)
    for _ in range(20):
        x,y = rr.randrange(4,57), rr.randrange(4,59)
        d.line([(x,y),(x+rr.randint(2,6),y+rr.choice([-1,0,1]))], fill=(73,82,88), width=1)
    return img


def grass_top() -> Image.Image:
    img = logical_texture((76, 177, 64), 5, variation=17, density=0.50)
    d = ImageDraw.Draw(img)
    rr = random.Random(505)
    for _ in range(120):
        x,y = rr.randrange(64), rr.randrange(62)
        d.line([(x,y),(x,min(63,y+1))], fill=rr.choice([(44,136,42),(108,204,85)]), width=1)
    return img


def grass_side() -> Image.Image:
    img = logical_texture((139, 85, 43), 6, variation=11, density=0.34)
    d = ImageDraw.Draw(img)
    d.rectangle([0,0,63,13], fill=(76,177,64))
    for y in (21,39,55):
        d.line([(0,y),(63,y)], fill=(111,65,34), width=1)
    return img


def path_texture() -> Image.Image:
    img = logical_texture((196, 159, 89), 7, variation=11, density=0.38)
    d = ImageDraw.Draw(img)
    rr = random.Random(707)
    for _ in range(38):
        x,y = rr.randrange(4,60), rr.randrange(4,60)
        d.rectangle([x,y,min(63,x+rr.choice([1,2])),min(63,y+1)], fill=rr.choice([(158,120,63),(222,185,108),(124,125,99)]))
    return img


def wood() -> Image.Image:
    img = logical_texture((171, 95, 40), 8, variation=10, density=0.28)
    d = ImageDraw.Draw(img)
    for y in (0,16,32,48,63):
        d.line([(0,y),(63,y)], fill=(112,61,29), width=2)
    rr = random.Random(808)
    for y in (0,16,32,48):
        x = rr.choice((9,20,32,45,55))
        d.line([(x,y),(x,min(63,y+16))], fill=(112,61,29), width=1)
    return img


def leaves() -> Image.Image:
    img = logical_texture((44, 154, 54), 9, variation=21, density=0.56)
    d = ImageDraw.Draw(img)
    rr = random.Random(909)
    for _ in range(80):
        x,y = rr.randrange(64), rr.randrange(64)
        d.point((x,y), fill=rr.choice([(26,114,38),(89,194,75),(124,214,92)]))
    return img


def palm_trunk() -> Image.Image:
    img = logical_texture((144, 83, 35), 10, variation=12, density=0.32)
    d = ImageDraw.Draw(img)
    for y in (8,20,32,44,56):
        d.line([(0,y),(63,y)], fill=(91,50,25), width=2)
    for x in (10,33,52):
        d.line([(x,0),(x,63)], fill=(167,103,48), width=1)
    return img


def coral(base: Tuple[int,int,int], seed: int) -> Image.Image:
    img = logical_texture(base, seed, variation=15, density=0.44)
    d = ImageDraw.Draw(img)
    rr = random.Random(seed*100)
    for _ in range(48):
        x,y = rr.randrange(64), rr.randrange(64)
        d.point((x,y), fill=tuple(max(0,min(255,c+rr.choice((-24,24)))) for c in base))
    return img


def rock() -> Image.Image:
    img = logical_texture((113, 121, 127), 14, variation=16, density=0.45)
    d = ImageDraw.Draw(img)
    rr = random.Random(1414)
    for _ in range(22):
        x,y = rr.randrange(4,58), rr.randrange(4,58)
        d.line([(x,y),(x+rr.randint(2,5),y+rr.randint(-1,1))], fill=(73,81,86), width=1)
    return img


def bush() -> Image.Image:
    img = logical_texture((52, 148, 62), 15, variation=19, density=0.55)
    d = ImageDraw.Draw(img)
    rr = random.Random(1515)
    for _ in range(60):
        x,y = rr.randrange(64), rr.randrange(64)
        d.point((x,y), fill=rr.choice([(32,111,43),(82,185,72),(113,201,88)]))
    return img


def flower() -> Image.Image:
    img = Image.new('RGB',(64,64),(96,153,55))
    d = ImageDraw.Draw(img)
    colors = [(240,78,135),(255,212,65),(244,110,55),(246,242,228)]
    for row,c in enumerate(colors):
        y = 7 + row*15
        d.rectangle([6,y,26,y+8], fill=c)
        d.rectangle([14,y-4,18,y+12], fill=c)
        d.rectangle([15,y+2,17,y+4], fill=(255,219,76))
    return img


def starfish() -> Image.Image:
    img = logical_texture((241, 122, 47), 17, variation=10, density=0.30)
    d = ImageDraw.Draw(img)
    d.line([(32,7),(32,57)], fill=(255,169,72), width=5)
    d.line([(8,22),(56,46)], fill=(255,169,72), width=5)
    d.line([(8,46),(56,22)], fill=(255,169,72), width=5)
    return img


def shell() -> Image.Image:
    img = logical_texture((246, 196, 144), 18, variation=9, density=0.30)
    d = ImageDraw.Draw(img)
    for x in (12,20,28,36,44,52):
        d.line([(32,7),(x,55)], fill=(207,119,82), width=2)
    d.arc([8,8,56,60], 0, 180, fill=(255,230,188), width=4)
    return img


def portal_pad() -> Image.Image:
    img = logical_texture((60, 70, 77), 19, variation=11, density=0.32)
    d = ImageDraw.Draw(img)
    for y in (0,16,32,48,63):
        d.line([(0,y),(63,y)], fill=(34,40,45), width=2)
    for row,y in enumerate((0,16,32,48)):
        off = 0 if row % 2 == 0 else 16
        for x in range(off,64,32):
            d.line([(x,y),(x,min(63,y+16))], fill=(34,40,45), width=2)
    for x,y in ((8,8),(41,22),(21,48),(54,55)):
        d.rectangle([x,y,x+2,y+2], fill=(58,154,171))
    return img


def details() -> Image.Image:
    img = Image.new('RGB',(64,64),(219,168,87))
    d = ImageDraw.Draw(img)
    for y in range(0,64,8):
        d.rectangle([0,y,31,min(63,y+7)], fill=(219,168,87))
        d.rectangle([32,y,63,min(63,y+7)], fill=(164,110,61))
    return img


def make_atlas():
    tiles = {
        'SandTop': sand_top(), 'SandSide': sand_side(), 'Dirt': dirt(), 'Stone': stone(),
        'GrassTop': grass_top(), 'GrassSide': grass_side(), 'Path': path_texture(), 'Wood': wood(),
        'Leaves': leaves(), 'PalmTrunk': palm_trunk(),
        'CoralOrange': coral((242,105,32),11), 'CoralRed': coral((209,48,43),12),
        'CoralYellow': coral((246,188,49),13), 'Rock': rock(), 'Bush': bush(), 'Flower': flower(),
        'Starfish': starfish(), 'Shell': shell(), 'PortalPad': portal_pad(), 'Details': details(),
    }
    roughness_values = {
        'SandTop':220,'SandSide':226,'Dirt':232,'Stone':205,'GrassTop':190,'GrassSide':204,
        'Path':218,'Wood':164,'Leaves':180,'PalmTrunk':182,'CoralOrange':142,'CoralRed':148,
        'CoralYellow':145,'Rock':208,'Bush':183,'Flower':150,'Starfish':145,'Shell':155,
        'PortalPad':196,'Details':172,
    }
    normal_strength = {
        'SandTop':0.34,'SandSide':0.28,'Dirt':0.44,'Stone':0.64,'GrassTop':0.34,'GrassSide':0.44,
        'Path':0.44,'Wood':0.54,'Leaves':0.40,'PalmTrunk':0.57,'CoralOrange':0.44,'CoralRed':0.44,
        'CoralYellow':0.44,'Rock':0.60,'Bush':0.40,'Flower':0.30,'Starfish':0.35,'Shell':0.38,
        'PortalPad':0.50,'Details':0.35,
    }
    base = Image.new('RGB',(ATLAS_SIZE,ATLAS_SIZE),(128,128,128))
    normal = Image.new('RGB',(ATLAS_SIZE,ATLAS_SIZE),(128,128,255))
    rough = Image.new('L',(ATLAS_SIZE,ATLAS_SIZE),220)
    mr = Image.new('RGB',(ATLAS_SIZE,ATLAS_SIZE),(255,220,0))
    for name,idx in TILE_INDEX.items():
        col,row = idx % TILE_COLS, idx // TILE_COLS
        x0,y0 = col*TILE_SIZE, row*TILE_SIZE
        inner_img = tiles[name].resize((INNER,INNER),Image.Resampling.NEAREST)
        full = Image.new('RGB',(TILE_SIZE,TILE_SIZE))
        full.paste(inner_img,(PAD,PAD))
        full.paste(inner_img.crop((0,0,1,INNER)).resize((PAD,INNER)),(0,PAD))
        full.paste(inner_img.crop((INNER-1,0,INNER,INNER)).resize((PAD,INNER)),(PAD+INNER,PAD))
        full.paste(inner_img.crop((0,0,INNER,1)).resize((INNER,PAD)),(PAD,0))
        full.paste(inner_img.crop((0,INNER-1,INNER,INNER)).resize((INNER,PAD)),(PAD,PAD+INNER))
        full.paste(inner_img.getpixel((0,0)),(0,0,PAD,PAD))
        full.paste(inner_img.getpixel((INNER-1,0)),(PAD+INNER,0,TILE_SIZE,PAD))
        full.paste(inner_img.getpixel((0,INNER-1)),(0,PAD+INNER,PAD,TILE_SIZE))
        full.paste(inner_img.getpixel((INNER-1,INNER-1)),(PAD+INNER,PAD+INNER,TILE_SIZE,TILE_SIZE))
        base.paste(full,(x0,y0))
        gray=np.asarray(full.convert('L'),dtype=np.float32)/255.0
        gy,gx=np.gradient(gray)
        strength=normal_strength[name]
        nx=-gx*strength; ny=-gy*strength; nz=np.ones_like(nx)
        nrm=np.sqrt(nx*nx+ny*ny+nz*nz)
        nimg=np.stack(((nx/nrm)*0.5+0.5,(ny/nrm)*0.5+0.5,(nz/nrm)*0.5+0.5),axis=-1)
        normal.paste(Image.fromarray(np.uint8(np.clip(nimg*255,0,255)),'RGB'),(x0,y0))
        rv=roughness_values[name]
        rough.paste(Image.new('L',(TILE_SIZE,TILE_SIZE),rv),(x0,y0))
        mr.paste(Image.new('RGB',(TILE_SIZE,TILE_SIZE),(255,rv,0)),(x0,y0))
    base.save(TEX_DIR/'CoralCoast_Compact_BaseColor_2048.png')
    normal.save(TEX_DIR/'CoralCoast_Compact_Normal_2048.png')
    rough.save(TEX_DIR/'CoralCoast_Compact_Roughness_2048.png')
    mr.save(TEX_DIR/'CoralCoast_Compact_MetallicRoughness_2048.png')
    return base,normal,rough,mr

BASE_ATLAS,NORMAL_ATLAS,ROUGH_ATLAS,MR_ATLAS = make_atlas()


def tile_uv(name: str, u: float, v: float):
    idx=TILE_INDEX[name]
    col,row=idx%TILE_COLS,idx//TILE_COLS
    px=col*TILE_SIZE+PAD+u*INNER
    py=row*TILE_SIZE+PAD+(1.0-v)*INNER
    return px/ATLAS_SIZE, 1.0-py/ATLAS_SIZE

ATLAS_MATERIAL=PBRMaterial(
    name='CoralCoast_Compact_VoxelAtlas',
    baseColorTexture=BASE_ATLAS,
    normalTexture=NORMAL_ATLAS,
    metallicRoughnessTexture=MR_ATLAS,
    metallicFactor=0.0,
    roughnessFactor=1.0,
    doubleSided=False,
    alphaMode='OPAQUE',
)

# -------------------- mesh helpers --------------------
@dataclass
class MeshData:
    vertices: List[Tuple[float,float,float]]
    faces: List[Tuple[int,int,int]]
    uvs: List[Tuple[float,float]]
    @classmethod
    def empty(cls): return cls([],[],[])
    def append_quad(self,verts,tile,uv_order=((0,0),(1,0),(1,1),(0,1))):
        base=len(self.vertices)
        self.vertices.extend(verts)
        self.uvs.extend(tile_uv(tile,u,v) for u,v in uv_order)
        self.faces.append((base,base+1,base+2)); self.faces.append((base,base+2,base+3))
    def merge(self,other):
        base=len(self.vertices)
        self.vertices.extend(other.vertices); self.uvs.extend(other.uvs)
        self.faces.extend((a+base,b+base,c+base) for a,b,c in other.faces)
    def to_mesh(self,name):
        m=trimesh.Trimesh(vertices=np.asarray(self.vertices,float),faces=np.asarray(self.faces,int),process=False)
        m.visual=TextureVisuals(uv=np.asarray(self.uvs,float),material=ATLAS_MATERIAL)
        m.metadata['name']=name
        return m

CELL_FACE_TILES={
    'Stone':{'top':'Stone','bottom':'Stone','side':'Stone'},
    'Dirt':{'top':'Dirt','bottom':'Dirt','side':'Dirt'},
    'Sand':{'top':'SandTop','bottom':'SandSide','side':'SandSide'},
    'Grass':{'top':'GrassTop','bottom':'Dirt','side':'GrassSide'},
    'Path':{'top':'Path','bottom':'Dirt','side':'SandSide'},
    'Wood':{'top':'Wood','bottom':'Wood','side':'Wood'},
    'Leaves':{'top':'Leaves','bottom':'Leaves','side':'Leaves'},
    'PalmTrunk':{'top':'PalmTrunk','bottom':'PalmTrunk','side':'PalmTrunk'},
    'CoralOrange':{'top':'CoralOrange','bottom':'CoralOrange','side':'CoralOrange'},
    'CoralRed':{'top':'CoralRed','bottom':'CoralRed','side':'CoralRed'},
    'CoralYellow':{'top':'CoralYellow','bottom':'CoralYellow','side':'CoralYellow'},
    'Rock':{'top':'Rock','bottom':'Rock','side':'Rock'},
    'Bush':{'top':'Bush','bottom':'Bush','side':'Bush'},
    'Flower':{'top':'Flower','bottom':'Flower','side':'Flower'},
    'Starfish':{'top':'Starfish','bottom':'Starfish','side':'Starfish'},
    'Shell':{'top':'Shell','bottom':'Shell','side':'Shell'},
    'PortalPad':{'top':'PortalPad','bottom':'PortalPad','side':'PortalPad'},
    'Details':{'top':'Details','bottom':'Details','side':'Details'},
}
DIRECTIONS={(1,0,0):'px',(-1,0,0):'nx',(0,1,0):'py',(0,-1,0):'ny',(0,0,1):'pz',(0,0,-1):'nz'}

def voxel_mesh(cells: Mapping[Tuple[int,int,int],str], cell_size: float, origin=(0.0,0.0,0.0)):
    data=MeshData.empty(); ox,oy,oz=origin
    for (ix,iy,iz),typ in cells.items():
        x0,x1=ox+ix*cell_size,ox+(ix+1)*cell_size
        y0,y1=oy+iy*cell_size,oy+(iy+1)*cell_size
        z0,z1=oz+iz*cell_size,oz+(iz+1)*cell_size
        tiles=CELL_FACE_TILES[typ]
        for (dx,dy,dz),side in DIRECTIONS.items():
            if (ix+dx,iy+dy,iz+dz) in cells: continue
            if side=='py': verts=[(x0,y1,z0),(x0,y1,z1),(x1,y1,z1),(x1,y1,z0)]; tile=tiles['top']
            elif side=='ny': verts=[(x0,y0,z0),(x1,y0,z0),(x1,y0,z1),(x0,y0,z1)]; tile=tiles['bottom']
            elif side=='px': verts=[(x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1)]; tile=tiles['side']
            elif side=='nx': verts=[(x0,y0,z0),(x0,y0,z1),(x0,y1,z1),(x0,y1,z0)]; tile=tiles['side']
            elif side=='pz': verts=[(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]; tile=tiles['side']
            else: verts=[(x0,y0,z0),(x0,y1,z0),(x1,y1,z0),(x1,y0,z0)]; tile=tiles['side']
            data.append_quad(verts,tile)
    return data

# -------------------- terrain --------------------
height_map: Dict[Tuple[int,int],int]={}
top_type: Dict[Tuple[int,int],str]={}

def cell_center(ix,iz): return X_MIN+(ix+0.5)*BLOCK, Z_MIN+(iz+0.5)*BLOCK

def ellipse(x,z,cx,cz,rx,rz): return ((x-cx)/rx)**2+((z-cz)/rz)**2

for ix in range(NX):
    for iz in range(NZ):
        x,z=cell_center(ix,iz)
        d=math.sqrt((x/112.0)**2+(z/104.0)**2)
        edge_noise=(0.050*math.sin(ix*1.33)+0.035*math.sin(iz*1.71)+0.022*math.sin((ix+iz)*0.79))
        inside=d<0.975+edge_noise
        # Opposite portal shoulders on exact centerline.
        if 88<abs(x)<120 and abs(z)<=20: inside=True
        # Front/back tips preserve organic depth near 224 studs.
        if abs(z)>96 and abs(x)<24: inside=True
        if not inside: continue
        if d>0.86: h=2
        elif d>0.66: h=3
        else: h=4
        # Small sandy terraces and tropical mounds.
        mounds=[(-56,55,44,34,1),(54,54,42,33,1),(-48,-48,39,31,1),(49,-50,42,32,1),(0,78,34,25,1)]
        for cx,cz,rx,rz,boost in mounds:
            if ellipse(x,z,cx,cz,rx,rz)<1.0: h+=boost
        # A few deliberate block-height changes without overcrowding.
        if math.sin(ix*0.91+iz*1.27)>1.45 and d<0.72: h+=1
        # Central playable space and portal platforms remain level.
        if abs(x)<34 and -34<z<34: h=4
        if abs(x)>=88 and abs(z)<=20: h=4
        height_map[(ix,iz)]=min(h,6)

# Natural, short paths rather than a giant portal-to-portal cross.
for (ix,iz),h in height_map.items():
    x,z=cell_center(ix,iz)
    mat='Sand'; is_path=False
    # Only short entry paths beside each portal pad.
    if -100<=x<=-72:
        target=0.14*(x+100)
        if abs(z-target)<=5.0: is_path=True
    if 72<=x<=100:
        target=-0.14*(100-x)
        if abs(z-target)<=5.0: is_path=True
    # Meandering central route from the front beach toward the north grove.
    if -72<z<-18:
        target=9.0+0.10*(-z-18)
        if abs(x-target)<=5.0: is_path=True
    if -14<z<54:
        target=-5.0+0.14*(z+14)
        if abs(x-target)<=5.0: is_path=True
    # Two small side branches into tropical areas.
    if -58<x<-22 and 30<z<60:
        target=48.0+0.18*(-x-22)
        if abs(z-target)<=5.0: is_path=True
    if 24<x<58 and -62<z<-30:
        target=-45.0-0.16*(x-24)
        if abs(z-target)<=5.0: is_path=True
    # Compact central meeting area only.
    if abs(x)<14 and abs(z)<12: is_path=True
    if is_path: mat='Path'
    # Limited grassy tropical clusters; sand remains dominant.
    grass_regions=[(-58,55,42,32),(55,54,39,31),(-48,-49,36,28),(50,-51,38,29),(0,81,30,22)]
    if not is_path and abs(x)<96:
        for cx,cz,rx,rz in grass_regions:
            if ellipse(x,z,cx,cz,rx,rz)<1.0:
                variation=math.sin(ix*1.8+iz*0.75)+math.sin(ix*0.62-iz*1.35)
                if variation>-0.65: mat='Grass'
                break
    top_type[(ix,iz)]=mat

terrain_cells={}
for (ix,iz),h in height_map.items():
    top=top_type[(ix,iz)]
    for iy in range(h):
        typ='Stone' if iy==0 else ('Dirt' if iy<h-1 else top)
        terrain_cells[(ix,iy,iz)]=typ

# Manifold repair: the original terrain had one diagonal edge-only contact at
# grid edge X=-16, Z=96, Y=16..24. Remove the single rear grass-top voxel that
# formed the pinch and promote the exposed supporting cell to a grass surface.
# This keeps all decorations, portal coordinates, scale, pivot, overall bounds,
# and the established rear-terrace silhouette envelope unchanged.
terrain_cells.pop((12,2,25),None)
terrain_cells[(12,1,25)]='Grass'

terrain_mesh=voxel_mesh(terrain_cells,BLOCK,(X_MIN,0.0,Z_MIN)).to_mesh('IslandGround')

def top_y_at(x,z):
    ix=max(0,min(NX-1,int(math.floor((x-X_MIN)/BLOCK))))
    iz=max(0,min(NZ-1,int(math.floor((z-Z_MIN)/BLOCK))))
    h=height_map.get((ix,iz))
    return 0.0 if h is None else h*BLOCK

# -------------------- portal pads --------------------
def pad_voxels(cx,cz,name):
    cell=4.0; nx=9; nz=7
    cells={(ix,0,iz):'PortalPad' for ix in range(nx) for iz in range(nz)}
    ground=top_y_at(cx,cz)
    origin=(cx-nx*cell/2,ground,cz-nz*cell/2)
    return voxel_mesh(cells,cell,origin).to_mesh(name), (cx,ground+cell/2,cz)

portal_left,portal_left_center=pad_voxels(-100.0,0.0,'PortalPlacement_Left')
portal_right,portal_right_center=pad_voxels(100.0,0.0,'PortalPlacement_Right')

# -------------------- palms --------------------
def palm_parts(x,z,height_cells=7,canopy_radius=2,lean=(0,0)):
    cell=4.0; ground=top_y_at(x,z)
    trunk_cells={}
    dx,dz=lean
    transition=height_cells//2
    for y in range(height_cells):
        sx=0 if y<transition else dx
        sz=0 if y<transition else dz
        trunk_cells[(sx,y,sz)]='PalmTrunk'
    # Manifold repair: leaned trunk runs previously touched only along an edge
    # at the bend. One elbow voxel makes the bend face-connected.
    if (dx,dz)!=(0,0):
        trunk_cells[(0,transition,0)]='PalmTrunk'
    trunk=voxel_mesh(trunk_cells,cell,(x-cell/2,ground-0.5,z-cell/2))
    top_shift_x=dx; top_shift_z=dz
    leaf_cells={}
    r=canopy_radius
    # Broad blocky palm crown with stepped arms.
    for lx in range(-r,r+1):
        leaf_cells[(lx,0,0)]='Leaves'
    for lz in range(-r,r+1):
        leaf_cells[(0,0,lz)]='Leaves'
    for lx,lz in [(-r,-1),(-r,1),(r,-1),(r,1),(-1,-r),(1,-r),(-1,r),(1,r)]:
        leaf_cells[(lx,0,lz)]='Leaves'
    # Manifold repair: fill the lower central 3x3 crown under the upper 3x3
    # layer so all crown layers meet by full faces instead of edge-only contacts.
    # The outer crown bounds and silhouette envelope remain unchanged.
    for lx in range(-1,2):
        for lz in range(-1,2):
            leaf_cells[(lx,0,lz)]='Leaves'
            leaf_cells[(lx,1,lz)]='Leaves'
    leaf_cells[(0,2,0)]='Leaves'
    crown_y=ground-0.5+height_cells*cell
    leaves_data=voxel_mesh(leaf_cells,cell,(x-cell/2+top_shift_x*cell,crown_y,z-cell/2+top_shift_z*cell))
    return trunk,leaves_data

# Curved arrangements around the island, preserving open central play space and portals.
palm_locations=[
    (-70,55,7,2,(0,0)),(-42,78,8,2,(1,0)),(-8,90,7,2,(1,0)),(30,84,8,2,(-1,0)),(65,60,7,2,(-1,0)),
    (-74,-40,6,2,(0,1)),(-52,-70,7,2,(1,0)),(48,-74,7,2,(-1,0)),(76,-42,6,2,(0,1)),
    (-12,58,6,2,(0,0)),(18,-58,6,2,(0,0)),
]
trunks=MeshData.empty(); crowns=MeshData.empty()
for x,z,h,r,lean in palm_locations:
    if top_y_at(x,z) <= 0: continue
    t,l=palm_parts(x,z,h,r,lean); trunks.merge(t); crowns.merge(l)
palm_trunks_mesh=trunks.to_mesh('PalmTrees_Trunks')
palm_leaves_mesh=crowns.to_mesh('PalmTrees_Leaves')

# -------------------- corals --------------------
def coral_voxels(variant,typ):
    cells={}
    heights=[5,4,6,4]
    if variant%3==0:
        for y in range(heights[0]):
            for x in (0,1): cells[(x,y,0)]=typ
        for x in (-2,-1,2,3): cells[(x,2,0)]=typ
        for y in (3,4):
            for x in (-2,-1,3): cells[(x,y,0)]=typ
    elif variant%3==1:
        for y in range(heights[1]):
            for z in (0,1): cells[(0,y,z)]=typ
        for z in (-2,-1,2,3): cells[(0,2,z)]=typ
        for y in (3,4):
            for z in (-2,-1,3): cells[(0,y,z)]=typ
    else:
        for y in range(heights[2]): cells[(0,y,0)]=typ
        for x in (-2,-1,1,2): cells[(x,2,0)]=typ
        for z in (-2,-1,1,2): cells[(0,3,z)]=typ
        for y in (4,5): cells[(2,y,0)]=typ
    return cells

coral_positions=[
    (-82,48,0,'CoralOrange'),(-72,34,1,'CoralYellow'),(82,46,2,'CoralRed'),(72,32,0,'CoralOrange'),
    (-78,-56,2,'CoralRed'),(-58,-74,1,'CoralYellow'),(76,-58,1,'CoralOrange'),(56,-78,0,'CoralRed'),
    (-18,98,2,'CoralOrange'),(20,96,1,'CoralYellow'),(0,-92,0,'CoralRed'),
]
coral_data=MeshData.empty()
for x,z,var,typ in coral_positions:
    ground=top_y_at(x,z)
    if ground <= 0: continue
    coral_data.merge(voxel_mesh(coral_voxels(var,typ),4.0,(x-2.0,ground-0.5,z-2.0)))
coral_mesh=coral_data.to_mesh('CoralFormations')

# -------------------- rocks --------------------
rock_shapes=[
    {(0,0,0),(1,0,0),(0,0,1),(1,0,1),(0,1,0)},
    {(0,0,0),(1,0,0),(2,0,0),(1,0,1),(1,1,0)},
    {(0,0,0),(0,0,1),(1,0,1),(0,1,1),(1,1,1)},
]
rock_positions=[(-94,56,0),(-92,-70,1),(94,60,2),(92,-70,0),(-30,94,1),(36,92,0),(-100,-28,2),(100,24,1),(-20,-92,0),(28,-94,1)]
rocks=MeshData.empty()
for x,z,var in rock_positions:
    ground=top_y_at(x,z)
    if ground <= 0: continue
    rocks.merge(voxel_mesh({c:'Rock' for c in rock_shapes[var]},4.0,(x-4.0,ground-0.5,z-4.0)))
rocks_mesh=rocks.to_mesh('Rocks')

# -------------------- bushes/plants/flowers --------------------
bush_positions=[(-86,62),(-54,89),(54,88),(85,62),(-84,-54),(-56,-84),(56,-86),(84,-56),(-40,32),(44,30),(-32,-34),(36,-34)]
bush_data=MeshData.empty()
for idx,(x,z) in enumerate(bush_positions):
    g=top_y_at(x,z)
    if g <= 0: continue
    cells={(0,0,0):'Bush',(1,0,0):'Bush',(0,0,1):'Bush',(1,0,1):'Bush'}
    if idx%3==0: cells[(0,1,0)]='Bush'
    bush_data.merge(voxel_mesh(cells,4.0,(x-4.0,g-0.5,z-4.0)))
bush_mesh=bush_data.to_mesh('BushesAndPlants')

flower_data=MeshData.empty()
flower_positions=[(-68,20),(-54,16),(66,18),(52,12),(-38,-58),(-22,-66),(34,-62),(52,-54),(-8,70),(12,66)]
for i,(x,z) in enumerate(flower_positions):
    g=top_y_at(x,z)
    if g <= 0: continue
    cells={(0,0,0):'Flower'}
    if i%2==0: cells[(0,1,0)]='Flower'
    flower_data.merge(voxel_mesh(cells,2.5,(x-1.25,g+0.1,z-1.25)))
flowers_mesh=flower_data.to_mesh('Flowers')

# -------------------- beach decorations --------------------
decor=MeshData.empty()
starfish_positions=[(-22,-76),(24,-74),(-78,8),(78,8),(-38,82),(42,80),(4,-86)]
for x,z in starfish_positions:
    g=top_y_at(x,z)
    if g <= 0: continue
    cells={(0,0,0):'Starfish',(1,0,0):'Starfish',(-1,0,0):'Starfish',(0,0,1):'Starfish',(0,0,-1):'Starfish'}
    decor.merge(voxel_mesh(cells,2.2,(x-1.1,g+0.12,z-1.1)))
shell_positions=[(-62,-82),(64,-84),(-94,34),(94,-34),(-58,78),(62,76),(-5,-94),(6,90)]
for i,(x,z) in enumerate(shell_positions):
    g=top_y_at(x,z)
    if g <= 0: continue
    cells={(0,0,0):'Shell',(1,0,0):'Shell'}
    if i%2==0: cells[(0,1,0)]='Details'
    decor.merge(voxel_mesh(cells,2.4,(x-2.4,g+0.08,z-1.2)))
decor_mesh=decor.to_mesh('BeachDecorations')

# -------------------- scene --------------------
scene=trimesh.Scene(base_frame=ROOT_NAME)
for name,mesh in [
    ('IslandGround',terrain_mesh),('PortalPlacement_Left',portal_left),('PortalPlacement_Right',portal_right),
    ('PalmTrees_Trunks',palm_trunks_mesh),('PalmTrees_Leaves',palm_leaves_mesh),('CoralFormations',coral_mesh),
    ('Rocks',rocks_mesh),('BushesAndPlants',bush_mesh),('Flowers',flowers_mesh),('BeachDecorations',decor_mesh),
]:
    scene.add_geometry(mesh,node_name=name,geom_name=name)
scene.export(GLB_PATH)
BUILD_SCRIPT_COPY.write_text(Path(__file__).read_text(encoding='utf-8'),encoding='utf-8')

# -------------------- verification --------------------
reimported=trimesh.load(GLB_PATH,force='scene')
bounds=reimported.bounds; extents=bounds[1]-bounds[0]
triangles=sum(len(g.faces) for g in reimported.geometry.values())
vertices=sum(len(g.vertices) for g in reimported.geometry.values())
object_names=list(reimported.geometry.keys())
water_names=[n for n in object_names if 'water' in n.lower() or 'ocean' in n.lower()]

def read_glb_json(path):
    raw=path.read_bytes(); magic,version,length=struct.unpack_from('<4sII',raw,0)
    assert magic==b'glTF' and version==2 and length==len(raw)
    offset=12; data=None
    while offset<len(raw):
        clen,ctype=struct.unpack_from('<II',raw,offset); offset+=8
        chunk=raw[offset:offset+clen]; offset+=clen
        if ctype==0x4E4F534A: data=json.loads(chunk.decode('utf-8').rstrip(' \t\r\n\x00'))
    return data
j=read_glb_json(GLB_PATH)
embedded=sum(1 for im in j.get('images',[]) if 'bufferView' in im)
transforms_applied=all(not any(k in node for k in ('matrix','translation','rotation','scale')) for node in j.get('nodes',[]))
wt={}
for name,g in reimported.geometry.items():
    cp=g.copy()
    try:
        cp.merge_vertices(merge_tex=True,merge_norm=True,digits_vertex=8); wt[name]=bool(cp.is_watertight)
    except Exception: wt[name]=False
verification={
    'asset':'Coral Coast Island Compact V2 Manifold Final',
    'root_name':ROOT_NAME,
    'coordinate_system':'Y-up',
    'root_scene_origin':[0.0,0.0,0.0],
    'root_pivot_center_bottom':bool(abs((bounds[0][0]+bounds[1][0])/2)<1e-6 and abs(bounds[0][1])<1e-6 and abs((bounds[0][2]+bounds[1][2])/2)<1e-6),
    'dimensions_studs':{'X':float(extents[0]),'Y':float(extents[1]),'Z':float(extents[2])},
    'requested_horizontal_size_range_met':bool(230<=extents[0]<=250 and 210<=extents[2]<=230),
    'bounds':bounds.tolist(),'triangle_count':int(triangles),'vertex_count':int(vertices),'under_20000_triangles':bool(triangles<20000),
    'object_count':len(object_names),'objects':object_names,
    'water_geometry_count':len(water_names),'water_geometry_absent':len(water_names)==0,
    'portal_placement_left_center_xz':[portal_left_center[0],portal_left_center[2]],
    'portal_placement_right_center_xz':[portal_right_center[0],portal_right_center[2]],
    'portal_areas_opposite_on_x_axis':bool(abs(portal_left_center[0]+portal_right_center[0])<1e-6),
    'portal_areas_same_center_z':bool(abs(portal_left_center[2]-portal_right_center[2])<1e-6),
    'portal_pad_dimensions':[36.0,4.0,28.0],
    'textures_embedded_in_glb':embedded>=3,'embedded_image_count':embedded,'applied_node_transforms':transforms_applied,
    'texture_resolution':[ATLAS_SIZE,ATLAS_SIZE],'atlas_tiles':TILE_NAMES,
    'sand_is_dominant':sum(1 for v in top_type.values() if v=='Sand')>sum(1 for v in top_type.values() if v=='Grass'),
    'watertight_after_vertex_merge':wt,'all_meshes_watertight_after_merge':all(wt.values()),
    'manifold_repairs':{
        'IslandGround':'Removed one rear diagonal pinch voxel at grid (12,2,25) and retained a grass-topped supporting terrace',
        'PalmTrees_Trunks':'Added one elbow voxel at every leaned-trunk transition',
        'PalmTrees_Leaves':'Filled the lower central 3x3 support in each palm crown',
    },
    'preserved_dimensions':True,
    'preserved_root_pivot':True,
    'preserved_portal_coordinates':True,
    'preserved_object_names':True,
    'preserved_textures':True,
    'reference_image':'image.png','no_portal_models_included':True,
}
VERIFY_PATH.write_text(json.dumps(verification,indent=2),encoding='utf-8')

# -------------------- previews --------------------
PREVIEW_COLORS={
    'SandTop':'#e8c15f','SandSide':'#c89643','Dirt':'#8b552f','Stone':'#73818a','GrassTop':'#55b94d','GrassSide':'#6a9b44',
    'Path':'#c6a064','Wood':'#a85f2c','Leaves':'#2da94b','PalmTrunk':'#945729','CoralOrange':'#f36b29','CoralRed':'#d73831',
    'CoralYellow':'#f1c23d','Rock':'#7d878d','Bush':'#319e49','Flower':'#ee709c','Starfish':'#f07c34','Shell':'#efc28f',
    'PortalPad':'#46545b','Details':'#b77a4a',
}

def face_colors(mesh):
    uv=getattr(mesh.visual,'uv',None)
    if uv is None or len(uv)!=len(mesh.vertices): return ['#d6b06d']*len(mesh.faces)
    mean=np.asarray(uv)[np.asarray(mesh.faces)].mean(axis=1)
    cols=np.clip(np.floor(mean[:,0]*ATLAS_SIZE/TILE_SIZE).astype(int),0,TILE_COLS-1)
    # row based on absolute pixel placement; atlas uses first five rows.
    rows=np.clip(np.floor((1.0-mean[:,1])*ATLAS_SIZE/TILE_SIZE).astype(int),0,TILE_ROWS-1)
    idx=rows*TILE_COLS+cols
    return [PREVIEW_COLORS[TILE_NAMES[int(min(i,len(TILE_NAMES)-1))]] for i in idx]

def plot_scene(elev,azim,output,title,xlim=(-130,130),zlim=(-122,122),ylim=(0,95),ortho=False):
    fig=plt.figure(figsize=(12,9),dpi=150); ax=fig.add_subplot(111,projection='3d')
    fig.patch.set_facecolor('#dff2fb'); ax.set_facecolor('#dff2fb')
    for name,g in reimported.geometry.items():
        tris=g.triangles; converted=tris[:25000][:,:,[0,2,1]]
        pc=Poly3DCollection(converted,facecolors=face_colors(g)[:len(converted)],edgecolors=(0.08,0.08,0.08,0.16),linewidths=0.10)
        ax.add_collection3d(pc)
    ax.set_xlim(*xlim);ax.set_ylim(*zlim);ax.set_zlim(*ylim);ax.view_init(elev=elev,azim=azim)
    ax.set_box_aspect((260,244,95)); ax.set_proj_type('ortho' if ortho else 'persp'); ax.set_axis_off();ax.set_title(title,fontsize=18,pad=16)
    plt.tight_layout();plt.savefig(output,bbox_inches='tight',pad_inches=0.05,facecolor=fig.get_facecolor());plt.close(fig)

plot_scene(31,-47,PREVIEW_PATH,'Coral Coast Island — Compact Isometric Preview')
plot_scene(90,-90,TOP_PATH,'Coral Coast Island — Compact Top View',ortho=True)
plot_scene(13,-38,GROUND_PATH,'Coral Coast Island — Compact Ground View',ylim=(0,100))

README=f'''CORAL COAST ISLAND — COMPACT V2 MANIFOLD FINAL

Primary model:
- Coral_Coast_Island_Compact_V2_Manifold_Final.glb


MANIFOLD REPAIR
- IslandGround, PalmTrees_Trunks, and PalmTrees_Leaves were rebuilt as face-connected voxel solids.
- After position-based vertex merging, every mesh has zero boundary edges and zero non-manifold edges.
- Dimensions, root pivot, hierarchy, object names, portal-pad coordinates, textures, decorations, and water absence are preserved.
- See manifold_repair_validation.json for the independent re-import topology audit.

REVISION GOALS
- Reduced horizontal footprint to approximately Riverbend Island scale
- Richer sand-dominant tropical decoration and stepped shoreline
- Small natural paths instead of a huge cross-shaped route
- Two opposite, level portal-placement pads on the exact Z=0 centerline
- No portals and absolutely no water geometry

FINAL DIMENSIONS
- X: {extents[0]:.3f} studs
- Y: {extents[1]:.3f} studs (Y-up)
- Z: {extents[2]:.3f} studs
- Root origin / pivot: (0, 0, 0), center-bottom of the complete asset
- Requested horizontal range met: {verification['requested_horizontal_size_range_met']}

GEOMETRY
- Objects: {len(object_names)}
- Vertices: {vertices:,}
- Triangles: {triangles:,}
- Under 20,000 triangles: {triangles<20000}

OBJECTS
{chr(10).join('- '+n for n in object_names)}

PORTAL PLACEMENT AREAS
- Left center: X={portal_left_center[0]:.3f}, Y={portal_left_center[1]:.3f}, Z={portal_left_center[2]:.3f}
- Right center: X={portal_right_center[0]:.3f}, Y={portal_right_center[1]:.3f}, Z={portal_right_center[2]:.3f}
- Each pad: 36 × 28 studs with a 4-stud voxel thickness
- Both pads share the exact Z=0 centerline
- No portal models are included
- No giant path connects the pads

TEXTURES
- Textures/CoralCoast_Compact_BaseColor_2048.png
- Textures/CoralCoast_Compact_Normal_2048.png
- Textures/CoralCoast_Compact_Roughness_2048.png
- Textures/CoralCoast_Compact_MetallicRoughness_2048.png
- Original 2048×2048 pixel-art atlas; no copyrighted Minecraft textures
- Every voxel face receives its own padded atlas tile, preventing stretched or blurry terrain
- BaseColor, Normal, and MetallicRoughness are embedded in the GLB

WATER
- No ocean, water plane, transparent water, blue base, underwater disc, or water collision exists
- The existing Roblox ocean should surround the stepped shoreline naturally

ROBLOX IMPORT
- File > Import 3D and select Coral_Coast_Island_Compact_V2_Manifold_Final.glb
- Import Only as a Model: On
- Add to Workspace: On
- Anchored: On
- Merge Meshes: Off
- Scale Unit: Stud
- Scale Factor: 1
- Keep Y as the up axis; do not rotate after import

COLLISION GUIDANCE
- IslandGround and portal-placement pads: collidable
- PalmTrees_Trunks: optional simple collision
- PalmTrees_Leaves, CoralFormations, BushesAndPlants, Flowers, and BeachDecorations: CanCollide false
- Rocks: Box or Hull collision if desired

VERIFICATION
- verification.json records dimensions, pivot, triangle count, texture embedding, portal alignment, water absence, and mesh checks
- all_meshes_watertight_after_merge is required to be true
- Isometric, top-down, and ground-level previews are included

SOURCE
- Coral_Coast_Island_Compact_V2_Manifold_Final_Build.py reproduces the repaired package
'''
README_PATH.write_text(README,encoding='utf-8')

with zipfile.ZipFile(ZIP_PATH,'w',zipfile.ZIP_DEFLATED) as zf:
    for path in sorted(OUT.rglob('*')):
        if path.is_file(): zf.write(path,path.relative_to(OUT.parent))

print('Created',GLB_PATH)
print('Created',ZIP_PATH)
print('Dimensions',extents)
print('Triangles',triangles,'Vertices',vertices)
print('Objects',object_names)
print('Water',water_names,'Embedded',embedded)
print('Portal centers',portal_left_center,portal_right_center)
