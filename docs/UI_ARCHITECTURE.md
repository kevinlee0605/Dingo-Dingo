# UI architecture

Fishy Fish uses authored `StarterGui` hierarchies as the visual source of truth.
Controllers update existing objects and clone only declared templates for
variable-length content such as fish, shop products, quests, and reward days.

## Ownership

| Surface | Authored source | State/controller |
| --- | --- | --- |
| Fishing HUD, menus, quests, minigame | `src/ui/FishingGui` | `FishingClient` and its child modules |
| Always-on four-button top HUD | `src/ui/TopHudGui` | `TopButtonsHud`, `Phase3EconomyUI`, and `AuthoredUiController` |
| Daily/login rewards panel | `src/ui/Phase3EconomyGui` | `Phase3EconomyUI` |
| Daily/login rewards top button | `src/ui/TopHudGui` | `Phase3EconomyUI` |
| Aquarium placement editor | `src/ui/AquariumFreePlacementGui` | `AquariumFreePlacementEditor` |
| UTC clock | `src/ui/ServerUtcClockGui` | `src/starterplayer/ServerUtcClock.client.luau` |
| Early loading screens | `src/replicatedfirst/AuxiliaryUiTemplates.rbxmx` | `LoadingScreen.client.luau` |

The loading screen is the intentional exception to `StarterGui`: it must run
from `ReplicatedFirst` before the normal player UI is available.

## Runtime rules

- Never create or replace a whole ScreenGui from a controller.
- Bind named authored instances and preserve the compatibility names used by
  gameplay code (`CoinsHud`, `SeaStarsHud`, `MainPanel`, and similar names).
- Clone rows/cards from the hidden authored template folders; do not hand-build
  repeated visual trees in event handlers.
- Keep responsive scaling local to declared `UIScale` instances. Do not scan and
  resize every descendant in `PlayerGui`.
- A single controller owns each surface. Do not attach duplicate listeners for
  the same state transition inside one surface; cross-surface state currently
  comes from the shared `GetState`/`StateUpdated` protocol.
- Keep `TopHudGui` above feature modals. Its four authored buttons share one
  layout and one press treatment; the menu coordinator only changes visibility
  of conflicting authored roots and never reparents or rebuilds the row.

## Syncing

Use `ui-migration.project.json` for UI-only reconciliation with Studio. It does
not map `Workspace` or `ServerScriptService`. Once the UI has been tested, save
or publish the Team Create place so collaborators receive it without running
Rojo themselves.

The UI-only project declares the remote instances needed by the controllers,
but expects the target place to already contain compatible `GameConfig`,
`ResourceConfig`, `MonetizationConfig`, and server handlers from the deployed
game. Use `default.project.json` only for an intentional full-game deployment;
do not add gameplay configuration modules to the UI-only sync just to make a
standalone build self-contained.
