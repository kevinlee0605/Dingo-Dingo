# Editor Patches

Some map objects live only inside the Roblox Studio place file, not in Rojo source.
Server scripts can change those objects during Play/Test, but those changes do not
permanently update the editor view.

When a change targets a Studio-saved object, add a one-time Command Bar patch here
and run it in Studio while editing the place. Save the place afterward.

Standing rule: anything added for gameplay should also be visible in the editor.
Prefer Rojo-synced Workspace instances in `default.project.json`; if the object must
be generated during Play, also add an editor preview or an editor patch here.

Current patches:

- `apply_fountain_brick_plaza.lua` updates saved `FountainPlazaTile` parts to the brick style.
- `bake_beginner_pond_editor.lua` bakes the generated Beginner Pond into real editable Workspace parts in Studio edit mode. Use it after pulling source if the editor pond does not match Play/Test.
- `run_editor_patches.lua` runs all current editor patches in one paste, including the fountain brick style, fountain biome-warp trigger, shop wood spacing fixes, the seaside shop fishmonger NPC, the rod shop NPC, and the seaside shop display aquarium.
- `add_lobby_aquarium_warp.lua` is a one-off fallback patch for creating the aquarium warp in Studio if Rojo syncing is not available. The current aquarium warp is also Rojo-synced as `Workspace.LobbyAquariumWarp`.
