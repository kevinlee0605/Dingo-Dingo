-- Retired compatibility shim.
--
-- The authored implementation now lives at:
-- StarterGui > AquariumFreePlacementGui > AquariumFreePlacementEditor
-- (`src/ui/AquariumFreePlacementGui`). Keep this file free of UI construction
-- so an old project mapping cannot create a second editor ScreenGui.

local Players = game:GetService("Players")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local authoredGui = playerGui:WaitForChild("AquariumFreePlacementGui", 30)
if not authoredGui or authoredGui:GetAttribute("AquariumPlacementUiV2") ~= true then
	warn("[AquariumFreePlacementEditor] Authored AquariumFreePlacementGui is missing")
end
