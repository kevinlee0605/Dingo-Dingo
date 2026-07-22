RIVERBEND ISLAND VOXEL — ROBLOX-READY REPLACEMENT

DELIVERABLES
- Riverbend_Island_Voxel.blend
- Riverbend_Island_Voxel.glb
- Riverbend_Island_Voxel_Build.py
- Textures/Riverbend_Voxel_BaseColor.png
- Textures/Riverbend_Voxel_Normal.png
- Textures/Riverbend_Voxel_Roughness.png
- Riverbend_Island_Voxel_Preview.png
- Riverbend_Island_Voxel_Top.png
- verification.json

DESIGN
- Hand-built block/voxel environment with hard edges and flat shading.
- Original 16-pixel-style texture tiles packed in a 512 x 512 atlas.
- Raised source pool, stepped waterfall, winding river, main bridge, lower crossing, river-mouth dock, paths, pine forest, rocks, logs, stumps, bushes, flowers and mushrooms.
- WaterPreview, markers and collision-sensitive gameplay objects remain modular and separate.

FINAL VERIFIED METRICS
- Dimensions after clean GLB re-import: X 354.228 x Y 308.000 x Z 74.000 studs.
- Requested raw dimensions: X 354.228 x Y 308.000 x Z 74.000 studs.
- Triangle count: 8,844 (requested maximum: 20,000).
- Vertex count after GLB re-import: 17,688.
- Mesh objects after GLB re-import: 129.
- Root: Riverbend_Island_ROOT at (0, 0, 0).

HIERARCHY
- IslandGround
- CliffSections
- Riverbed
- WaterPreview
- Bridges
- Dock
- Paths
- Trees
- Rocks
- Foliage
- FishingSpotMarkers
- SpawnMarker

GAMEPLAY MARKERS (Blender Z-up coordinates)
- FishingSpotMarker_01: (-58.000, 63.000, 38.605)
- FishingSpotMarker_02: (-41.000, 25.000, 38.605)
- FishingSpotMarker_03: (-39.000, -58.000, 38.605)
- FishingSpotMarker_04: (54.000, 64.000, 38.605)
- FishingSpotMarker_05: (54.000, -28.000, 38.605)
- FishingSpotMarker_06: (42.000, -104.000, 38.605)
- FishingSpotMarker_07: (45.000, -151.000, 39.345)
- SpawnMarker: (-106.000, -104.000, 42.200)

MATERIALS / TEXTURES
- Riverbend_Voxel_Atlas: BaseColor, Normal, and packed Metallic-Roughness atlases.
- Riverbend_WaterPreview_Atlas: same embedded atlas, transparent water material.
- FishingMarker_DEV and SpawnMarker_DEV: translucent development-only marker materials.
- Atlas dimensions: 512 x 512, with original pixel-art tiles; no official Minecraft textures are used.
- All three atlas images are embedded in the GLB and supplied externally in Textures/.

ROBLOX IMPORT SETTINGS
- Import Only as a Model: ON
- Add to Workspace: ON
- Anchored: ON
- Merge Meshes: OFF
- Scale Unit: Stud
- Scale Factor: 1
- Set WaterPreview, FishingSpotMarker_01..07 and SpawnMarker to CanCollide = false.
- Use Box/Hull collision on small props; use tested Hull/PreciseConvexDecomposition only on terrain, bridges and dock.

GLB EXPORT / VERIFICATION
- Binary glTF (.glb), embedded PNG textures.
- Geometry vertices and transforms are baked before export.
- glTF is Y-up as required by the format; Blender clean re-import restores Z-up.
- Normals and UVs included.
- No cameras, lights, rigs or animations.
- GLB cleanly re-imported with trimesh; hierarchy, markers, dimensions, materials and embedded images were checked in verification.json.

BLENDER SOURCE NOTE
- This runtime did not expose Blender/bpy. The included .blend is the prior valid Riverbend source scaffold; run Riverbend_Island_Voxel_Build.py in Blender 5.x to overwrite it with the exact verified voxel GLB scene. The GLB is the authoritative Roblox-ready replacement.
