PREMIUM AQUARIUM THEMES v4 — HIGH-QUALITY GLB PACK
===================================================

Included paid themes:
CoralReef, DeepOcean, JapaneseKoiPond, ModernGlass, PirateShip, AncientRuins

Classic is intentionally excluded because it uses the free existing DefaultFrame.

Each paid theme contains:
- Frames/: one high-detail 3D frame GLB with embedded premium front textures
- Backdrops/: one flat rear backdrop GLB with its high-resolution image embedded
- Complete/: combined frame + backdrop for visual testing only

No physical interior decorations are included. There are no rocks, plants, coral props, lanterns, treasure chests, shipwreck pieces, ruins props, or substrate meshes. Player custom decorations remain unobstructed.

AncientRuins uses aged masonry, stone columns, moss, weathering, and an aged-gold medallion. It contains no neon runes or futuristic technology styling.

Alignment:
- Interior reference: 40 x 15 x 14 studs
- ThemeAnchor: centre of the aquarium inside floor
- X = width, Y = height, Z = depth, front = -Z

Roblox import:
1. Import the six GLBs from Frames/ with Home > Import 3D.
2. Rename them exactly to the theme IDs and place them in ServerStorage/AquariumThemeFrames.
3. Import the six GLBs from Backdrops/.
4. Rename them exactly to the theme IDs and place them in ServerStorage/AquariumThemes.
5. Run Roblox/PrepareSelectedThemeModel.command.lua on every imported Model.
6. Put AquariumThemeService_HQ.lua in ServerScriptService.
7. Keep Glass, Water, collision parts, fish boundaries, and custom decorations outside DefaultFrame.
8. Use Complete/ only for quick testing; do not load Complete together with the separate Frame and Backdrop files.

All textures are embedded inside the GLB files. No separate image upload is required.
