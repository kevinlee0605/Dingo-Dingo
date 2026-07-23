CORAL COAST ISLAND — ROBLOX-READY VOXEL ENVIRONMENT

Primary model:
- Coral_Coast_Island.glb

Visual direction:
- Original Minecraft-inspired voxel/block art for Fishy Fish
- Sand-dominant tropical island with stepped shoreline cliffs
- Blocky palms, coral formations, rocks, bushes, starfish, and shells
- No ocean, water plane, transparent water, underwater disc, or water collision geometry

FINAL DIMENSIONS
- X: 352.000 studs
- Y: 83.500 studs (Y-up)
- Z: 304.000 studs
- Root origin / pivot: (0, 0, 0), center-bottom of the complete asset

GEOMETRY
- Objects: 9
- Vertices: 23,920
- Triangles: 11,960
- Requested triangle budget met: True

OBJECTS
- IslandGround
- PortalPlacement_Left
- PortalPlacement_Right
- PalmTrees_Trunks
- PalmTrees_Leaves
- CoralFormations
- Rocks
- BushesAndPlants
- BeachDecorations

PORTAL PLACEMENT AREAS
- PortalPlacement_Left center: X=-148.000, Y=33.250, Z=0.000
- PortalPlacement_Right center: X=148.000, Y=33.250, Z=0.000
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
