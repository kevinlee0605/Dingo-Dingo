-- Run this once in Roblox Studio's Command Bar while editing the place.
-- It updates the saved/editor fountain plaza tiles, not just the Play/Test copy.

local Workspace = game:GetService("Workspace")

local brickColors = {
	Color3.fromRGB(150, 78, 58),
	Color3.fromRGB(172, 88, 64),
	Color3.fromRGB(122, 61, 49),
}

local function styleBrickTile(part)
	local colorIndex = (math.floor(part.Position.X / 4) + (math.floor(part.Position.Z / 4) * 2)) % #brickColors
	part.Material = Enum.Material.Brick
	part.Color = brickColors[colorIndex + 1]
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local changed = 0

for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant.Name == "FountainPlazaTile" then
		styleBrickTile(descendant)
		changed += 1
	end
end

print(("Updated %d fountain plaza tiles to brick style. Save the place to keep this in the editor."):format(changed))
