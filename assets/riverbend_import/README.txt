RIVERBEND ISLAND — ROBLOX-READY ENVIRONMENT ASSET

DELIVERABLES
- Riverbend_Island.blend
- Riverbend_Island.glb
- Textures/Riverbend_Environment_BaseColor.png
- Textures/Riverbend_Environment_Normal.png
- Textures/Riverbend_Environment_Roughness.png
- Riverbend_Island_Preview.png
- Riverbend_Island_Top.png
- GLB_Verification.json

SCENE SCALE / PIVOT
- 1 Blender unit = 1 Roblox stud.
- Root/pivot object: Riverbend_Island_ROOT.
- Root is located at center-bottom of the island: (0, 0, 0).
- Approximate exported dimensions including the dock and source details:
  X 354.2 × Y 308.0 × Z 74.0 studs.
- Intended playable island footprint is approximately 350 × 300 studs.

OBJECT GROUPS / COLLECTIONS
1. IslandGround
   - IslandGround_LeftGrass / IslandGround_RightGrass
   - IslandGround_LeftPath / IslandGround_RightPath
   - IslandGround_FishingLedge_*
2. CliffSections
   - CliffSections_RockBase
   - CliffSections_SoilBand
   - CliffSections_LeftUpperBank / RightUpperBank
   - CliffSections_SourceShelf
3. Riverbed
   - Riverbed_Main
   - Riverbed_InnerChannel
4. Bridge
   - Bridge_Deck, beams, supports, rails, posts
5. Dock
   - Dock_Deck, beams, posts, rails
6. PineTrees
   - PineTree_*_Trunk / PineTree_*_Foliage
7. Rocks
   - Rock_*
8. LogsAndStumps
   - FallenLog_* / TreeStump_*
9. BushesAndPlants
   - Bush_* / Grass_* / Mushroom_* / Flower_*
10. WaterPreview
   - WaterPreview_River
   - WaterPreview_SourcePool
   - WaterPreview_Waterfall
   - WaterPreview_WaterfallFoam
11. FishingSpotMarkers
   - FishingSpotMarker_*
12. SpawnMarker
   - SpawnMarker_Main

TEXTURE ATLAS ASSIGNMENTS
- Grass: IslandGround grass slabs
- Dirt: upper banks, soil cliffs
- Rock: lower cliff base, rocks, source shelf
- Riverbed: riverbed and pebble channel
- Wood: bridge deck, dock deck, signs, stumps
- DarkWood: supports, rails, trunks, logs
- PineDark / PineLight: pine foliage variants
- Bush: bushes and grass clusters
- Path: walking paths and fishing ledges
- Water: river, source pool, waterfall, foam preview
- Flower: flowers
- Mushroom: mushrooms
- Lantern: lantern glow props
- FishingMarker: fishing placeholder markers
- SpawnMarker: spawn placeholder marker

TEXTURES
- Atlas resolution: 2048 × 2048 maximum.
- BaseColor: sRGB PNG.
- Normal: non-color PNG.
- Roughness: non-color grayscale PNG.
- The GLB embeds the same atlas maps; the external PNG files are supplied for Roblox SurfaceAppearance workflows and future edits.
- No Blender procedural material is required by the exported GLB.

GEOMETRY / OPTIMIZATION
- Mesh objects: 195
- Approximate triangle count: 16,476
- Approximate vertex count: 8,928
- Reusable low-poly tree, rock, bush, log, stump, flower, mushroom, and grass shapes are duplicated throughout the map.
- All scale and rotation transforms are applied before export.
- No unapplied Blender modifiers are used.
- Primary paths are approximately 12 studs wide.
- Bridge deck is approximately 18 studs wide.
- Dock deck is approximately 16 studs wide.
- WaterPreview is separate from walkable terrain and should not be used as collision.

ROBLOX IMPORT SETTINGS
- Import Only as a Model: ON
- Add to Workspace: ON
- Anchored: ON
- Merge Meshes: OFF
- Scale Unit: Stud
- Scale Factor: 1
- Recommended CollisionFidelity:
  - Main terrain, bridge, and dock: PreciseConvexDecomposition or Hull after testing.
  - Small props: Box or Hull.
  - WaterPreview, FishingSpotMarkers, SpawnMarker: CanCollide = false.
- Hide or remove WaterPreview after replacing it with Roblox Terrain water or your existing water system.
- FishingSpotMarkers and SpawnMarker are placeholders and can be made transparent after scripting.

EXPORT SETTINGS
- glTF Binary (.glb)
- Y Up: enabled
- Apply modifiers/transforms: enabled
- Normals and UVs: enabled
- Materials and textures: exported/embedded
- Cameras, lights, animations: excluded
- Root hierarchy and object names: preserved

CLEAN RE-IMPORT VERIFICATION
- Imported mesh object count: 195
- Materials loaded: 5
- Images loaded: 3
- All images have data: True
- Re-import dimensions: [354.228, 308.0, 74.0]
- Not flattened into one mesh: True
- Root present: True
- WaterPreview present: True
- Required group object prefixes present: True
- Textures embedded and loaded: True
- All exported geometry reported watertight by trimesh: False

NOTES
- The scene is optimized for a bright stylized Roblox fishing simulator rather than photorealism.
- The two elevated grassy banks are divided by a winding recessed river that widens at the front river mouth.
- The rear source pool and waterfall are visual environment elements; WaterPreview remains replaceable.
- No characters, fish, UI, gameplay scripts, or blocking buildings are included.
