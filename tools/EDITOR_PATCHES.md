# Editor Patches

Some map objects live only inside the Roblox Studio place file, not in Rojo source.
Server scripts can change those objects during Play/Test, but those changes do not
permanently update the editor view.

When a change targets a Studio-saved object, add a one-time Command Bar patch here
and run it in Studio while editing the place. Save the place afterward.

Current patches:

- `apply_fountain_brick_plaza.lua` updates saved `FountainPlazaTile` parts to the brick style.
- `run_editor_patches.lua` runs all current editor patches in one paste, including the fountain brick style, fountain biome-warp trigger, shop wood spacing fixes, and the seaside shop fishmonger NPC.
