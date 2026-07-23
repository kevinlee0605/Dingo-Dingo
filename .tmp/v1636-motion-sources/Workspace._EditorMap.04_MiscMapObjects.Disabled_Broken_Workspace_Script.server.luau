-- Extra Large Beginner Pond Generator
-- Put this Script in ServerScriptService, press Play once, then keep/edit the generated model.
-- Style: Minecraft/blocky Roblox fishing pond area.
-- Extra large version designed for many players.
-- Sign text: "Beginner Pond"

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

-- ============================================================
-- SETTINGS
-- ============================================================

local BLOCK = 4
local AREA_NAME = "Beginner Pond"

-- Extra large dimensions
local GROUND_RADIUS_X = 24
local GROUND_RADIUS_Z = 22

local WATER_RADIUS_X = 14
local WATER_RADIUS_Z = 11

local BORDER_RADIUS_X = WATER_RADIUS_X + 1
local BORDER_RADIUS_Z = WATER_RADIUS_Z + 1

-- Delete old generated pond if it exists
local oldAreas = Workspace:FindFirstChild("FishingAreas")
if oldAreas then
	oldAreas:Destroy()
end

-- ============================================================
-- FOLDER SETUP
-- ============================================================

local fishingAreas = Instance.new("Folder")
fishingAreas.Name = "FishingAreas"
fishingAreas.Parent = Workspace

local pond = Instance.new("Model")
pond.Name = "BeginnerPond_ExtraLarge"
pond.Parent = fishingAreas

local blocksFolder = Instance.new("Folder")
blocksFolder.Name = "Blocks"
blocksFolder.Parent = pond

local waterFolder = Instance.new("Folder")
waterFolder.Name = "Water"
waterFolder.Parent = pond

local dockFolder = Instance.new("Folder")
dockFolder.Name = "Docks"
dockFolder.Parent = pond

local decorFolder = Instance.new("Folder")
decorFolder.Name = "Decorations"
decorFolder.Parent = pond

local zonesFolder = Instance.new("Folder")
zonesFolder.Name = "Zones"
zonesFolder.Parent = pond

local spotsFolder = Instance.new("Folder")
spotsFolder.Name = "FishingSpots"
spotsFolder.Parent = pond

-- ============================================================
-- HELPERS
-- ============================================================

local function makePart(parent, name, size, position, color, material, transparency, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.CanCollide = canCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeBlock(parent, name, gridX, gridY, gridZ, color, material)
	return makePart(
		parent,
		name,
		Vector3.new(BLOCK, BLOCK, BLOCK),
		Vector3.new(gridX * BLOCK, gridY * BLOCK, gridZ * BLOCK),
		color,
		material
	)
end

local function makeLantern(position)
	local woodDark = Color3.fromRGB(90, 55, 28)

	makePart(
		decorFolder,
		"LanternPost",
		Vector3.new(0.8, 4, 0.8),
		position,
		woodDark,
		Enum.Material.Wood
	)

	local lantern = makePart(
		decorFolder,
		"Lantern",
		Vector3.new(1.3, 1.3, 1.3),
		position + Vector3.new(0, 2.6, 0),
		Color3.fromRGB(255, 215, 120),
		Enum.Material.Neon,
		0.1,
		false
	)

	local light = Instance.new("PointLight")
	light.Brightness = 1.15
	light.Range = 15
	light.Color = Color3.fromRGB(255, 220, 150)
	light.Parent = lantern
end

local function addFishingSpot(name, position, facingDirection)
	local spot = makePart(
		spotsFolder,
		name,
		Vector3.new(4, 1, 4),
		position,
		Color3.fromRGB(0, 255, 120),
		Enum.Material.ForceField,
		1,
		false
	)

	spot:SetAttribute("AreaName", AREA_NAME)
	spot:SetAttribute("FishPool", "Beginner")
	spot:SetAttribute("FacingDirection", facingDirection)

	CollectionService:AddTag(spot, "FishingSpot")
	return spot
end

-- ============================================================
-- COLORS
-- ============================================================

local grassColor = Color3.fromRGB(95, 170, 65)
local grassDark = Color3.fromRGB(68, 135, 50)
local dirtColor = Color3.fromRGB(105, 72, 42)
local stoneColor = Color3.fromRGB(125, 125, 125)
local stoneDark = Color3.fromRGB(88, 88, 88)
local waterColor = Color3.fromRGB(50, 145, 220)
local deepWaterColor = Color3.fromRGB(35, 110, 180)
local woodColor = Color3.fromRGB(135, 85, 45)
local woodDark = Color3.fromRGB(90, 55, 28)
local leafColor = Color3.fromRGB(65, 150, 55)
local reedColor = Color3.fromRGB(75, 145, 55)
local flowerWhite = Color3.fromRGB(245, 245, 220)
local flowerYellow = Color3.fromRGB(245, 210, 65)
local flowerPurple = Color3.fromRGB(150, 95, 230)
local flowerBlue = Color3.fromRGB(80, 140, 255)

-- ============================================================
-- 1. EXTRA LARGE BLOCKY GROUND
-- ============================================================

for x = -GROUND_RADIUS_X, GROUND_RADIUS_X do
	for z = -GROUND_RADIUS_Z, GROUND_RADIUS_Z do
		local isPondWater = math.abs(x) <= WATER_RADIUS_X and math.abs(z) <= WATER_RADIUS_Z

		if isPondWater then
			makeBlock(blocksFolder, "PondFloor", x, -1, z, dirtColor, Enum.Material.Ground)
		else
			makeBlock(blocksFolder, "GrassBlock", x, 0, z, grassColor, Enum.Material.Grass)
			makeBlock(blocksFolder, "DirtBlock", x, -1, z, dirtColor, Enum.Material.Ground)
		end
	end
end

-- Raised blocky terrain
local raisedGrass = {
	{-23,-21}, {-22,-21}, {-23,-20}, {-21,-21}, {-22,-20},
	{23,-21}, {22,-21}, {23,-20}, {21,-21}, {22,-20},
	{-23,21}, {-22,21}, {-23,20}, {-21,21}, {-22,20},
	{23,21}, {22,21}, {23,20}, {21,21}, {22,20},
	{-12,21}, {-11,21}, {11,21}, {12,21},
	{-12,-21}, {-11,-21}, {11,-21}, {12,-21},
	{-23,0}, {-23,1}, {23,0}, {23,-1}
}

for _, pos in ipairs(raisedGrass) do
	makeBlock(blocksFolder, "RaisedGrassBlock", pos[1], 1, pos[2], grassDark, Enum.Material.Grass)
end

-- ============================================================
-- 2. EXTRA LARGE WATER AREA
-- ============================================================

for x = -WATER_RADIUS_X, WATER_RADIUS_X do
	for z = -WATER_RADIUS_Z, WATER_RADIUS_Z do
		local water = makePart(
			waterFolder,
			"WaterBlock",
			Vector3.new(BLOCK, 1.1, BLOCK),
			Vector3.new(x * BLOCK, 0.55, z * BLOCK),
			waterColor,
			Enum.Material.Glass,
			0.35,
			false
		)
		water.Reflectance = 0.08
	end
end

-- Deeper center
for x = -8, 8 do
	for z = -6, 6 do
		makePart(
			waterFolder,
			"DeepWaterBlock",
			Vector3.new(BLOCK, 0.35, BLOCK),
			Vector3.new(x * BLOCK, 0.95, z * BLOCK),
			deepWaterColor,
			Enum.Material.Glass,
			0.5,
			false
		)
	end
end

-- ============================================================
-- 3. STONE BORDER AROUND POND
-- ============================================================

for x = -BORDER_RADIUS_X, BORDER_RADIUS_X do
	for z = -BORDER_RADIUS_Z, BORDER_RADIUS_Z do
		local onBorder = math.abs(x) == BORDER_RADIUS_X or math.abs(z) == BORDER_RADIUS_Z

		if onBorder then
			local color = stoneColor
			if (x + z) % 2 == 0 then
				color = stoneDark
			end

			makePart(
				blocksFolder,
				"StonePondBorder",
				Vector3.new(BLOCK, 1.5, BLOCK),
				Vector3.new(x * BLOCK, 2.75, z * BLOCK),
				color,
				Enum.Material.Cobblestone
			)
		end
	end
end

-- ============================================================
-- 4. EXTRA LARGE DOCKS
-- ============================================================

-- East dock
for x = 12, 17 do
	for z = -3, 3 do
		makePart(
			dockFolder,
			"EastDockPlank",
			Vector3.new(BLOCK, 0.6, BLOCK),
			Vector3.new(x * BLOCK, 3.35, z * BLOCK),
			woodColor,
			Enum.Material.WoodPlanks
		)
	end
end

-- West dock
for x = -17, -12 do
	for z = -3, 3 do
		makePart(
			dockFolder,
			"WestDockPlank",
			Vector3.new(BLOCK, 0.6, BLOCK),
			Vector3.new(x * BLOCK, 3.35, z * BLOCK),
			woodColor,
			Enum.Material.WoodPlanks
		)
	end
end

-- North dock
for x = -3, 3 do
	for z = -16, -11 do
		makePart(
			dockFolder,
			"NorthDockPlank",
			Vector3.new(BLOCK, 0.6, BLOCK),
			Vector3.new(x * BLOCK, 3.35, z * BLOCK),
			woodColor,
			Enum.Material.WoodPlanks
		)
	end
end

-- South dock
for x = -3, 3 do
	for z = 11, 16 do
		makePart(
			dockFolder,
			"SouthDockPlank",
			Vector3.new(BLOCK, 0.6, BLOCK),
			Vector3.new(x * BLOCK, 3.35, z * BLOCK),
			woodColor,
			Enum.Material.WoodPlanks
		)
	end
end

-- Small corner fishing platforms
local cornerPlatforms = {
	{12, 9, "NEPlatform"},
	{-12, 9, "NWPlatform"},
	{12, -9, "SEPlatform"},
	{-12, -9, "SWPlatform"},
}

for _, data in ipairs(cornerPlatforms) do
	local centerX, centerZ, prefix = data[1], data[2], data[3]
	for dx = -1, 1 do
		for dz = -1, 1 do
			makePart(
				dockFolder,
				prefix .. "_Plank",
				Vector3.new(BLOCK, 0.6, BLOCK),
				Vector3.new((centerX + dx) * BLOCK, 3.35, (centerZ + dz) * BLOCK),
				woodColor,
				Enum.Material.WoodPlanks
			)
		end
	end
end

-- Dock posts
local dockPosts = {}

local function addPost(x, z)
	table.insert(dockPosts, Vector3.new(x * BLOCK, 1.5, z * BLOCK))
end

-- East/West dock posts
for _, x in ipairs({12, 17, -12, -17}) do
	for _, z in ipairs({-3, 0, 3}) do
		addPost(x, z)
	end
end

-- North/South dock posts
for _, z in ipairs({-16, -11, 11, 16}) do
	for _, x in ipairs({-3, 0, 3}) do
		addPost(x, z)
	end
end

-- Corner platform posts
for _, data in ipairs(cornerPlatforms) do
	local centerX, centerZ = data[1], data[2]
	addPost(centerX - 1, centerZ - 1)
	addPost(centerX + 1, centerZ - 1)
	addPost(centerX - 1, centerZ + 1)
	addPost(centerX + 1, centerZ + 1)
end

for _, pos in ipairs(dockPosts) do
	makePart(dockFolder, "DockPost", Vector3.new(1, 4.5, 1), pos, woodDark, Enum.Material.Wood)
end

-- ============================================================
-- 5. DESIGNATED FISHING SPOTS
-- ============================================================

-- East dock spots: 12
for i = -3, 3 do
	addFishingSpot("FishingSpot_East_North_" .. i, Vector3.new(13 * BLOCK, 4.1, i * BLOCK), "West")
	addFishingSpot("FishingSpot_East_South_" .. i, Vector3.new(16 * BLOCK, 4.1, i * BLOCK), "West")
end

-- West dock spots: 12
for i = -3, 3 do
	addFishingSpot("FishingSpot_West_North_" .. i, Vector3.new(-13 * BLOCK, 4.1, i * BLOCK), "East")
	addFishingSpot("FishingSpot_West_South_" .. i, Vector3.new(-16 * BLOCK, 4.1, i * BLOCK), "East")
end

-- North dock spots: 12
for i = -3, 3 do
	addFishingSpot("FishingSpot_North_Left_" .. i, Vector3.new(i * BLOCK, 4.1, -12 * BLOCK), "South")
	addFishingSpot("FishingSpot_North_Right_" .. i, Vector3.new(i * BLOCK, 4.1, -15 * BLOCK), "South")
end

-- South dock spots: 12
for i = -3, 3 do
	addFishingSpot("FishingSpot_South_Left_" .. i, Vector3.new(i * BLOCK, 4.1, 12 * BLOCK), "North")
	addFishingSpot("FishingSpot_South_Right_" .. i, Vector3.new(i * BLOCK, 4.1, 15 * BLOCK), "North")
end

-- Corner platform spots: 8
addFishingSpot("FishingSpot_NE_1", Vector3.new(12 * BLOCK, 4.1, 9 * BLOCK), "SouthWest")
addFishingSpot("FishingSpot_NE_2", Vector3.new(13 * BLOCK, 4.1, 9 * BLOCK), "SouthWest")
addFishingSpot("FishingSpot_NW_1", Vector3.new(-12 * BLOCK, 4.1, 9 * BLOCK), "SouthEast")
addFishingSpot("FishingSpot_NW_2", Vector3.new(-13 * BLOCK, 4.1, 9 * BLOCK), "SouthEast")
addFishingSpot("FishingSpot_SE_1", Vector3.new(12 * BLOCK, 4.1, -9 * BLOCK), "NorthWest")
addFishingSpot("FishingSpot_SE_2", Vector3.new(13 * BLOCK, 4.1, -9 * BLOCK), "NorthWest")
addFishingSpot("FishingSpot_SW_1", Vector3.new(-12 * BLOCK, 4.1, -9 * BLOCK), "NorthEast")
addFishingSpot("FishingSpot_SW_2", Vector3.new(-13 * BLOCK, 4.1, -9 * BLOCK), "NorthEast")

-- Total suggested spots: 56

-- ============================================================
-- 6. WIDE PATHS
-- ============================================================

local pathTiles = {}

-- Big rectangular outer path
for x = -20, 20 do
	table.insert(pathTiles, {x, 19})
	table.insert(pathTiles, {x, -19})
end

for z = -19, 19 do
	table.insert(pathTiles, {20, z})
	table.insert(pathTiles, {-20, z})
end

-- Paths to each dock
for x = -4, 4 do
	for _, z in ipairs({18, 17, -18, -17}) do
		table.insert(pathTiles, {x, z})
	end
end

for z = -4, 4 do
	for _, x in ipairs({18, 17, -18, -17}) do
		table.insert(pathTiles, {x, z})
	end
end

for _, p in ipairs(pathTiles) do
	makePart(
		decorFolder,
		"DirtPath",
		Vector3.new(BLOCK, 0.25, BLOCK),
		Vector3.new(p[1] * BLOCK, 2.15, p[2] * BLOCK),
		Color3.fromRGB(150, 105, 60),
		Enum.Material.Ground
	)
end

-- ============================================================
-- 7. REEDS / CATTAILS
-- ============================================================

local reedGroups = {
	Vector3.new(-58, 4, -36), Vector3.new(-58, 4, 36),
	Vector3.new(58, 4, -36), Vector3.new(58, 4, 36),
	Vector3.new(-36, 4, -46), Vector3.new(36, 4, -46),
	Vector3.new(-36, 4, 46), Vector3.new(36, 4, 46),
	Vector3.new(0, 4, -46), Vector3.new(0, 4, 46),
	Vector3.new(-58, 4, 0), Vector3.new(58, 4, 0),
	Vector3.new(-48, 4, -16), Vector3.new(48, 4, 16),
	Vector3.new(-16, 4, 40), Vector3.new(16, 4, -40),
}

for _, basePos in ipairs(reedGroups) do
	for i = 1, 3 do
		local height = 3 + i
		local pos = basePos + Vector3.new((i - 2) * 0.7, height / 2, 0)

		makePart(
			decorFolder,
			"Reed",
			Vector3.new(0.45, height, 0.45),
			pos,
			reedColor,
			Enum.Material.Grass
		)

		makePart(
			decorFolder,
			"CattailHead",
			Vector3.new(0.55, 1.1, 0.55),
			pos + Vector3.new(0, height / 2 + 0.35, 0),
			Color3.fromRGB(105, 65, 35),
			Enum.Material.Wood
		)
	end
end

-- ============================================================
-- 8. LILY PADS
-- ============================================================

local lilyPads = {
	Vector3.new(-40, 1.25, -28),
	Vector3.new(-32, 1.25, 20),
	Vector3.new(-20, 1.25, -32),
	Vector3.new(-8, 1.25, 8),
	Vector3.new(0, 1.25, 0),
	Vector3.new(8, 1.25, -8),
	Vector3.new(20, 1.25, 32),
	Vector3.new(32, 1.25, -20),
	Vector3.new(40, 1.25, 28),
	Vector3.new(28, 1.25, 8),
	Vector3.new(-28, 1.25, -8),
	Vector3.new(12, 1.25, 24),
	Vector3.new(-12, 1.25, -24),
}

for _, pos in ipairs(lilyPads) do
	makePart(
		decorFolder,
		"LilyPad",
		Vector3.new(3, 0.18, 2.2),
		pos,
		Color3.fromRGB(45, 150, 55),
		Enum.Material.Grass,
		0,
		false
	)

	makePart(
		decorFolder,
		"LilyFlower",
		Vector3.new(0.8, 0.25, 0.8),
		pos + Vector3.new(0.4, 0.2, 0),
		flowerWhite,
		Enum.Material.SmoothPlastic,
		0,
		false
	)
end

-- ============================================================
-- 9. FLOWERS / TALL GRASS
-- ============================================================

local flowerPositions = {
	{-20, -16, flowerWhite}, {-19, -16, flowerYellow}, {-21, -14, flowerPurple},
	{20, -16, flowerYellow}, {21, -14, flowerPurple},
	{-20, 16, flowerPurple}, {-19, 17, flowerWhite},
	{20, 16, flowerWhite}, {21, 17, flowerYellow},
	{-8, 20, flowerPurple}, {8, -20, flowerWhite},
	{-22, 5, flowerYellow}, {22, -5, flowerPurple},
	{-15, 18, flowerBlue}, {15, -18, flowerBlue},
	{-18, -3, flowerWhite}, {18, 3, flowerYellow},
}

for _, f in ipairs(flowerPositions) do
	local x, z, color = f[1], f[2], f[3]

	makePart(
		decorFolder,
		"FlowerStem",
		Vector3.new(0.35, 1.2, 0.35),
		Vector3.new(x * BLOCK, 3.0, z * BLOCK),
		reedColor,
		Enum.Material.Grass
	)

	makePart(
		decorFolder,
		"FlowerTop",
		Vector3.new(1.0, 0.35, 1.0),
		Vector3.new(x * BLOCK, 3.8, z * BLOCK),
		color,
		Enum.Material.SmoothPlastic
	)
end

local grassClumps = {
	{-22,-6}, {-22,6}, {-18,0}, {-6,-20}, {6,-20},
	{18,0}, {22,6}, {-6,20}, {6,20},
	{-18,-18}, {18,-18}, {-18,18}, {18,18},
	{-12,15}, {12,-15}, {-15,-12}, {15,12}
}

for _, g in ipairs(grassClumps) do
	makePart(
		decorFolder,
		"TallGrass",
		Vector3.new(0.8, 2.2, 0.8),
		Vector3.new(g[1] * BLOCK, 3.2, g[2] * BLOCK),
		grassDark,
		Enum.Material.Grass,
		0,
		false
	)
end

-- ============================================================
-- 10. BLOCK TREES
-- ============================================================

local function makeTree(x, z)
	makePart(
		decorFolder,
		"TreeTrunk",
		Vector3.new(3, 12, 3),
		Vector3.new(x, 8, z),
		Color3.fromRGB(100, 65, 35),
		Enum.Material.Wood
	)

	makePart(
		decorFolder,
		"TreeLeaves",
		Vector3.new(10, 8, 10),
		Vector3.new(x, 18, z),
		leafColor,
		Enum.Material.Grass
	)

	makePart(
		decorFolder,
		"TreeLeavesTop",
		Vector3.new(7, 5, 7),
		Vector3.new(x, 24, z),
		leafColor,
		Enum.Material.Grass
	)
end

makeTree(-88, -76)
makeTree(88, -76)
makeTree(-88, 76)
makeTree(88, 76)
makeTree(-52, -78)
makeTree(52, 78)
makeTree(0, -82)
makeTree(0, 82)

-- ============================================================
-- 11. LANTERNS
-- ============================================================

local lanternPositions = {
	Vector3.new(-70, 5, -54),
	Vector3.new(70, 5, -54),
	Vector3.new(-70, 5, 54),
	Vector3.new(70, 5, 54),

	Vector3.new(62, 5, 14),
	Vector3.new(62, 5, -14),
	Vector3.new(-62, 5, 14),
	Vector3.new(-62, 5, -14),

	Vector3.new(-14, 5, -62),
	Vector3.new(14, 5, -62),
	Vector3.new(-14, 5, 62),
	Vector3.new(14, 5, 62),

	Vector3.new(80, 5, 0),
	Vector3.new(-80, 5, 0),
	Vector3.new(0, 5, 72),
	Vector3.new(0, 5, -72),
}

for _, pos in ipairs(lanternPositions) do
	makeLantern(pos)
end

-- ============================================================
-- 12. SIGN - EXACT TEXT: Beginner Pond
-- ============================================================

makePart(
	decorFolder,
	"SignPost",
	Vector3.new(1, 5, 1),
	Vector3.new(-8, 4.5, 86),
	woodDark,
	Enum.Material.Wood
)

local signBoard = makePart(
	decorFolder,
	"BeginnerPondSign",
	Vector3.new(12, 5, 0.5),
	Vector3.new(-8, 8, 85.5),
	woodColor,
	Enum.Material.Wood
)

local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "SignGui"
surfaceGui.Face = Enum.NormalId.Front
surfaceGui.CanvasSize = Vector2.new(500, 220)
surfaceGui.Parent = signBoard

local text = Instance.new("TextLabel")
text.Size = UDim2.fromScale(1, 1)
text.BackgroundTransparency = 1
text.Text = "Beginner\nPond"
text.TextScaled = true
text.TextColor3 = Color3.fromRGB(40, 25, 10)
text.Font = Enum.Font.FredokaOne
text.Parent = surfaceGui

-- ============================================================
-- 13. INVISIBLE FISHING ZONE
-- ============================================================

local fishZone = makePart(
	zonesFolder,
	"FishZone",
	Vector3.new((WATER_RADIUS_X * 2 + 4) * BLOCK, 12, (WATER_RADIUS_Z * 2 + 4) * BLOCK),
	Vector3.new(0, 5, 0),
	Color3.fromRGB(0, 255, 255),
	Enum.Material.ForceField,
	1,
	false
)

fishZone:SetAttribute("AreaName", AREA_NAME)
fishZone:SetAttribute("MinLevel", 1)
fishZone:SetAttribute("FishPool", "Beginner")
fishZone:SetAttribute("CommonChance", 75)
fishZone:SetAttribute("UncommonChance", 20)
fishZone:SetAttribute("RareChance", 5)
fishZone:SetAttribute("MaxPlayersSuggested", 56)

CollectionService:AddTag(fishZone, "FishingZone")

-- ============================================================
-- 14. MULTIPLE SPAWN POINTS
-- ============================================================
da
local spawnPositions = {
	Vector3.new(-24, 3.2, 90),
	Vector3.new(-12, 3.2, 90),
	Vector3.new(0, 3.2, 90),
	Vector3.new(12, 3.2, 90),
	Vector3.new(24, 3.2, 90),

	Vector3.new(90, 3.2, 0),
	Vector3.new(-90, 3.2, 0),
	Vector3.new(0, 3.2, -90),
}

for i, pos in ipairs(spawnPositions) do
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BeginnerPondSpawn_" .. i
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = pos
	spawn.Anchored = true
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Color = Color3.fromRGB(145, 95, 50)
	spawn.Parent = pond
end

pond.PrimaryPart = fishZone

print("Extra Large Beginner Pond generated successfully.")
print("Sign text is: Beginner Pond.")
print("Fishing spots created:", #spotsFolder:GetChildren())
print("FishZone tagged as FishingZone.")
