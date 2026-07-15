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

### Studio UI safety

`StarterGui` is intentionally not mapped in `default.project.json`. The Roblox
Studio version of the UI is authoritative, so connecting Rojo will not replace
or delete UI work. Export the current Studio UI before adding `StarterGui` back
to the Rojo project.

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
