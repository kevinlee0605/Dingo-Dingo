# Fishy Fish

Roblox fishing game project built with Rojo.

## Getting Started

Start the Rojo server from this folder:

```bash
bin/rojo serve default.project.json --port 34872
```

Then open Roblox Studio, open the Rojo plugin, and connect to:

```text
localhost:34872
```

### Authored UI and safe Studio sync

The UI hierarchy is authored in `src/ui` and mapped into `StarterGui`. Visual
instances live in Explorer; LocalScripts and ModuleScripts bind state, remotes,
navigation, and dynamic lists to those instances.

For a UI-only Studio sync, serve `ui-migration.project.json` instead of the full
project. It owns the migrated ScreenGuis but does not map `Workspace` or server
scripts, so it cannot replace the map:

```bash
bin/rojo serve ui-migration.project.json --port 34874
```

After syncing, save or publish the Team Create place. Collaborators do not need
Rojo; they receive the authored StarterGui hierarchy from the shared place when
they reopen or rejoin Studio.

Run the structural UI checks before syncing:

```bash
python tools/validate_ui_migration.py
```

To build a place file from scratch:

```bash
bin/rojo build --output FishyFish.rbxlx
```

## Working Together

Before starting work, get the newest version:

```bash
git pull
```

After making changes:

```bash
git add .
git commit -m "Describe your change"
git push
```

For more help, check out [the Rojo documentation](https://rojo.space/docs).
