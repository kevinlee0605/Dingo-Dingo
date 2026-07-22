RIVERBEND ISLAND VOXEL — CRISP TEXTURES / NO WATER GEOMETRY

PURPOSE
This package is a drop-in visual replacement for the supplied Riverbend voxel island.
The source layout, raw scale, root origin, silhouette, bridges, dock, paths, trees,
rocks, marker positions, and gameplay clearances are preserved. The changes are
limited to texture quality/UV density and removal of all water-preview meshes.

DELIVERABLES
- Riverbend_Island_Voxel_NoWater.blend
- Riverbend_Island_Voxel_NoWater.glb
- Riverbend_Island_Voxel_NoWater_Build.py
- Textures/ (embedded GLB texture sources)
- Riverbend_Island_Voxel_NoWater_Preview.png
- Riverbend_Island_Voxel_NoWater_Top.png
- README.txt
- verification.json

FINAL DIMENSIONS (BLENDER Z-UP / ROBLOX STUDS)
- X: 354.228
- Y: 308.000
- Z: 74.000
- Requested/source reference: 354.228 x 308.000 x 74.000
- Root: Riverbend_Island_ROOT at (0, 0, 0), center-bottom pivot.

GEOMETRY COUNTS
- Mesh objects: 157
- Triangles: 6,600
- Vertices after GLB re-import: 19,800
- Water meshes: 0
- Water materials: 0

WATER REMOVAL
- Removed WaterPreview_River
- Removed WaterPreview_SourcePool
- Removed WaterPreview_Waterfall
- Removed WaterPreview_WaterfallFoam
- Kept WaterPreview as an empty hierarchy group for compatibility.
- Riverbed_Main remains solid and below the former preview-water elevation.
- The river mouth remains physically open to the surrounding Roblox ocean.
- No water plane, transparent water material, water collision mesh, or hidden river
  cover is included.

TEXTURE / UV CHANGES
- Replaced the old blurred atlas appearance with original 256 x 256 seamless
  pixel-art source textures.
- Major surfaces use world-projected tiled UVs, so large grass, soil, stone, path,
  and bridge faces repeat at a consistent Roblox-stud density rather than stretching.
- Embedded material names:
  GrassTop, GrassSide, Dirt, Stone, Riverbed, Path, Gravel, Wood, DarkWood, Leaves, Sand, Flower, Mushroom, WoodEnd, FishingMarker_DEV, SpawnMarker_DEV
- All base-color, normal, and roughness PNGs used by the GLB are included under
  Textures/. No official Minecraft textures or proprietary artwork are used.
- GLB sampler requests nearest filtering and repeat wrapping for voxel clarity.

MARKERS — BLENDER Z-UP COORDINATES
- FishingSpotMarker_01: (-58.000, -63.000, 38.605)
- FishingSpotMarker_02: (-41.000, -25.000, 38.605)
- FishingSpotMarker_03: (-39.000, 58.000, 38.605)
- FishingSpotMarker_04: (54.000, -64.000, 38.605)
- FishingSpotMarker_05: (54.000, 28.000, 38.605)
- FishingSpotMarker_06: (42.000, 104.000, 38.605)
- FishingSpotMarker_07: (45.000, 151.000, 39.345)
- SpawnMarker: (-106.000, 104.000, 42.200)

HIERARCHY
- Riverbend_Island_ROOT
  - IslandGround
  - CliffSections
  - Riverbed
  - WaterPreview (empty compatibility group; no meshes)
  - Bridges
  - Dock
  - Paths
  - Trees
  - Rocks
  - Foliage
  - FishingSpotMarkers
  - SpawnMarker

ROBLOX IMPORT SETTINGS
- Import Only as a Model: ON
- Add to Workspace: ON
- Anchored: ON
- Merge Meshes: OFF
- Scale Unit: Stud
- Scale Factor: 1
- Set FishingSpotMarker_01 through FishingSpotMarker_07, SpawnMarker, and
  Riverbend_Island_ROOT_PivotMarker to CanCollide = false and Transparency = 1.
- Keep bridges, dock, terrain, cliff, and riverbed meshes anchored and collidable.
- Do not add a separate river water plane. Position the island so the existing ocean
  surface enters the open river mouth and occupies the recessed channel.

BLENDER SOURCE
- The GLB is the authoritative finished geometry/material asset.
- Riverbend_Island_Voxel_NoWater_Build.py rebuilds the supplied .blend from the GLB,
  applies transforms, enforces flat shading, hides development markers from renders,
  packs textures, and saves the final editable Blender file.
- Run with Blender 4.2+:
  blender --background --python Riverbend_Island_Voxel_NoWater_Build.py

DIFFERENCES FROM THE SUPPLIED VOXEL MODEL
- Water-preview geometry and water material removed.
- Crisp tiled pixel textures replace the blurred/stretched atlas appearance.
- SpawnMarker is explicitly referenced in the hierarchy; its coordinate is unchanged.
- No gameplay marker, bridge, dock, tree, path, rock, shoreline, or island-position
  redesign was performed.
