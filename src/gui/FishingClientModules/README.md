# FishingClient Modules

These files are editable Rojo source for `StarterGui > FishingGui > FishingClient`.

In Roblox Studio Explorer, expand `StarterGui > FishingGui > FishingClient` to see the synced ModuleScripts:

- `RemoteActions`
- `PanelMarkers`
- `PlayerGuiDebug`
- `LegacyRightUiCleanup`
- `IslandState`
- `GuiPrimitives`
- `BaitHelpers`
- `QuestHelpers`
- `LeaderboardHelpers`
- `HudControls`
- `ToolHotbarBinder`

- `RemoteActions.luau`: server remote helper functions for bait, quest, and shop actions.
- `PanelMarkers.luau`: creates `OpenFishingPanel`, `BagPanel`, and `FishdexPanel` markers used by hotbar tools.
- `PlayerGuiDebug.luau`: temporary PlayerGui/FishingGui debug print helpers.
- `LegacyRightUiCleanup.luau`: disables the old right-side access panel and removes the old Aquarium Viewer tool.
- `IslandState.luau`: island/biome id normalization and unlocked/current island helpers.
- `GuiPrimitives.luau`: reusable UI builder functions such as text, buttons, corners, strokes, gradients, fish icons, and rod icons.
- `BaitHelpers.luau`: bait count/display/effect helper functions.
- `QuestHelpers.luau`: quest period lookup and quest reward formatting.
- `LeaderboardHelpers.luau`: leaderboard stat lookup and compact number formatting.
- `HudControls.luau`: visible HUD layout. Edit this for the top Settings/Quests/Shop buttons, the AutoFish button, the Tap button, and the Settings popup.
- `ToolHotbarBinder.luau`: default Roblox hotbar bindings. Edit this for Bag/Fishdex tool activation behavior.
- `../FishingClient.client.luau`: main fishing flow, panels, cast meter, minigame, quests, shop rendering, and server remote handling.

Keep new UI work in these module files when possible. The main `FishingClient.client.luau` is intentionally thinner now so it is less likely to hit Luau's local-register limit.
