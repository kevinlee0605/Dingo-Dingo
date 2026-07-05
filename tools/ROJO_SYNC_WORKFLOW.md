# Safe Rojo Sync Workflow

Use this when two people are editing Fishy Fish together.

## What Rojo Owns

Rojo currently syncs:

- `ReplicatedStorage`
- `ServerScriptService`
- `StarterGui`
- `StarterPack`
- `Lighting`
- `SoundService`

Rojo does **not** currently own most `Workspace` map objects. That means the visible map in Studio is saved in the Roblox place file, while game code lives in GitHub.

## Before Connecting Rojo

1. Save the Roblox Studio place.
2. Pull the latest GitHub changes.
3. Start Rojo from the same branch as your teammate.
4. Connect the Rojo plugin.

## For Map Changes

If you edit map objects in `Workspace`, those changes are not automatically stored in GitHub by Rojo. To avoid losing them:

1. Make map edits in Studio edit mode, not Play mode.
2. Save or publish the place after map edits.
3. Tell the other person to open the newest saved/published place before connecting Rojo.
4. If a map change is generated from source, add or run a focused editor bake script in `tools/`.

Current focused bake script:

- `tools/bake_beginner_pond_editor.lua`

Run it only in Studio edit mode, then save the place.

## Do Not

- Do not make permanent map edits while Play/Test is running.
- Do not edit generated runtime copies and expect them to save.
- Do not put regular map objects in `Workspace.Models`; the game only treats known rod source models there as tool templates.
- Do not let two people manually edit the same saved map area at the same time unless one person owns the final save.

## Safe Rule

Code changes go through GitHub/Rojo.

Map changes go through the saved Roblox place, or through a focused editor bake script that is committed to GitHub and run in Studio edit mode.
