CORAL COAST ISLAND — COMPACT ROBLOX-READY VOXEL REVISION

Primary model:
- Coral_Coast_Island_Compact_V2.glb

REVISION GOALS
- Reduced horizontal footprint to approximately Riverbend Island scale
- Richer sand-dominant tropical decoration and stepped shoreline
- Small natural paths instead of a huge cross-shaped route
- Two opposite, level portal-placement pads on the exact Z=0 centerline
- No portals and absolutely no water geometry

FINAL DIMENSIONS
- X: 240.000 studs
- Y: 75.500 studs (Y-up)
- Z: 224.000 studs
- Root origin / pivot: (0, 0, 0), center-bottom of the complete asset
- Requested horizontal range met: True

GEOMETRY
- Objects: 10
- Vertices: 18,880
- Triangles: 9,440
- Under 20,000 triangles: True

OBJECTS
- IslandGround
- PortalPlacement_Left
- PortalPlacement_Right
- PalmTrees_Trunks
- PalmTrees_Leaves
- CoralFormations
- Rocks
- BushesAndPlants
- Flowers
- BeachDecorations

PORTAL PLACEMENT AREAS
- Left center: X=-100.000, Y=34.000, Z=0.000
- Right center: X=100.000, Y=34.000, Z=0.000
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
- File > Import 3D and select Coral_Coast_Island_Compact_V2.glb
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
- Isometric, top-down, and ground-level previews are included

SOURCE
- Coral_Coast_Island_Compact_V2_Build.py reproduces the package
