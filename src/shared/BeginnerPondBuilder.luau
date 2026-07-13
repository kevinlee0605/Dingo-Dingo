local CollectionService = game:GetService("CollectionService")

local BeginnerPondBuilder = {}

local function createLabel(part, textValue)
	local gui = Instance.new("SurfaceGui")
	gui.Name = part.Name .. "_SurfaceGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(800, 300)
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = textValue
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(25, 30, 35)
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui
end

local function removeExistingBeginnerPond()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if (descendant:IsA("Model") or descendant:IsA("Folder")) and (descendant.Name == "BeginnerPondArea" or descendant.Name == "BeginnerPond_ExtraLarge" or descendant.Name == "Beginner Pond") then
			descendant:Destroy()
		end
	end
end

function BeginnerPondBuilder.build(parent, biome)
	local block = 4
	local biomePosition = (biome and biome.position) or Vector3.new(0, 8, 0)
	local center = Vector3.new(biomePosition.X, -2, biomePosition.Z)
	local areaName = (biome and biome.displayName) or "Lilyshore Island"

	local groundRadiusX = 32
	local groundRadiusZ = 29
	local waterRadiusX = 22
	local waterRadiusZ = 17
	local borderRadiusX = waterRadiusX + 1
	local borderRadiusZ = waterRadiusZ + 1
	local dockHalfWidth = 4
	local eastDockInnerX = waterRadiusX - 2
	local eastDockOuterX = waterRadiusX + 3
	local westDockInnerX = -eastDockInnerX
	local westDockOuterX = -eastDockOuterX
	local northDockInnerZ = -waterRadiusZ
	local northDockOuterZ = -(waterRadiusZ + 5)
	local southDockInnerZ = waterRadiusZ
	local southDockOuterZ = waterRadiusZ + 5
	local cornerPlatformX = waterRadiusX - 2
	local cornerPlatformZ = waterRadiusZ - 2
	local pathRadiusX = groundRadiusX - 4
	local pathRadiusZ = groundRadiusZ - 3

	removeExistingBeginnerPond()

	local pond = Instance.new("Model")
	pond.Name = "BeginnerPondArea"
	pond.Parent = parent

	local function makeFolder(parentObject, name, className)
		local folder = Instance.new(className or "Folder")
		folder.Name = name
		folder.Parent = parentObject
		return folder
	end

	local groundFolder = makeFolder(pond, "Ground")
	local pondFolder = makeFolder(pond, "Pond")
	local waterFolder = makeFolder(pondFolder, "Water")
	local deepWaterFolder = makeFolder(pondFolder, "DeepWater")
	local pondBorderFolder = makeFolder(pondFolder, "PondBorder")
	local lilyPadsFolder = makeFolder(pondFolder, "LilyPads")
	local fishingZoneFolder = makeFolder(pondFolder, "FishingZone")
	local dockFolder = makeFolder(pond, "Docks")
	local eastDockFolder = makeFolder(dockFolder, "Dock_East", "Model")
	local westDockFolder = makeFolder(dockFolder, "Dock_West", "Model")
	local northDockFolder = makeFolder(dockFolder, "Dock_North", "Model")
	local southDockFolder = makeFolder(dockFolder, "Dock_South", "Model")
	local platformDockFolder = makeFolder(dockFolder, "Dock_CornerPlatforms", "Model")
	local dockPostsFolder = makeFolder(dockFolder, "Posts")
	local pathsFolder = makeFolder(pond, "Paths")
	local lampsFolder = makeFolder(pond, "Lamps")
	local signsFolder = makeFolder(pond, "Signs")
	local treesFolder = makeFolder(pond, "Trees")
	makeFolder(pond, "Benches")
	local spotsFolder = makeFolder(pond, "FishingSpots")
	local barriersFolder = makeFolder(pond, "InvisibleBorders")
	local decorFolder = makeFolder(pond, "Decorations")

	local function localPosition(position)
		return center + position
	end

	local function makePondPart(parentObject, name, size, position, color, material, transparency, canCollide)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Position = localPosition(position)
		part.Anchored = true
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Transparency = transparency or 0
		part.CanCollide = canCollide ~= false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parentObject
		return part
	end

	local function makeBlock(parentObject, name, gridX, gridY, gridZ, color, material)
		return makePondPart(parentObject, name, Vector3.new(block, block, block), Vector3.new(gridX * block, gridY * block, gridZ * block), color, material)
	end

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

	for x = -groundRadiusX, groundRadiusX do
		for z = -groundRadiusZ, groundRadiusZ do
			if math.abs(x) <= waterRadiusX and math.abs(z) <= waterRadiusZ then
				makeBlock(groundFolder, "PondFloor", x, -1, z, dirtColor, Enum.Material.Ground)
			else
				makeBlock(groundFolder, "GrassBlock", x, 0, z, grassColor, Enum.Material.Grass)
				makeBlock(groundFolder, "DirtBlock", x, -1, z, dirtColor, Enum.Material.Ground)
			end
		end
	end

	for _, pos in ipairs({
		{ -groundRadiusX + 1, -groundRadiusZ + 1 }, { -groundRadiusX + 2, -groundRadiusZ + 1 }, { -groundRadiusX + 1, -groundRadiusZ + 2 }, { -groundRadiusX + 3, -groundRadiusZ + 1 }, { -groundRadiusX + 2, -groundRadiusZ + 2 },
		{ groundRadiusX - 1, -groundRadiusZ + 1 }, { groundRadiusX - 2, -groundRadiusZ + 1 }, { groundRadiusX - 1, -groundRadiusZ + 2 }, { groundRadiusX - 3, -groundRadiusZ + 1 }, { groundRadiusX - 2, -groundRadiusZ + 2 },
		{ -groundRadiusX + 1, groundRadiusZ - 1 }, { -groundRadiusX + 2, groundRadiusZ - 1 }, { -groundRadiusX + 1, groundRadiusZ - 2 }, { -groundRadiusX + 3, groundRadiusZ - 1 }, { -groundRadiusX + 2, groundRadiusZ - 2 },
		{ groundRadiusX - 1, groundRadiusZ - 1 }, { groundRadiusX - 2, groundRadiusZ - 1 }, { groundRadiusX - 1, groundRadiusZ - 2 }, { groundRadiusX - 3, groundRadiusZ - 1 }, { groundRadiusX - 2, groundRadiusZ - 2 },
		{ -14, groundRadiusZ - 1 }, { -13, groundRadiusZ - 1 }, { 13, groundRadiusZ - 1 }, { 14, groundRadiusZ - 1 },
		{ -14, -groundRadiusZ + 1 }, { -13, -groundRadiusZ + 1 }, { 13, -groundRadiusZ + 1 }, { 14, -groundRadiusZ + 1 },
		{ -groundRadiusX + 1, 0 }, { -groundRadiusX + 1, 1 }, { groundRadiusX - 1, 0 }, { groundRadiusX - 1, -1 },
	}) do
		makeBlock(groundFolder, "RaisedGrassBlock", pos[1], 1, pos[2], grassDark, Enum.Material.Grass)
	end

	for x = -waterRadiusX, waterRadiusX do
		for z = -waterRadiusZ, waterRadiusZ do
			local water = makePondPart(waterFolder, "WaterBlock", Vector3.new(block, 1.1, block), Vector3.new(x * block, 0.55, z * block), waterColor, Enum.Material.Glass, 0.35, false)
			water.Reflectance = 0.08
		end
	end

	for x = -math.floor(waterRadiusX * 0.6), math.floor(waterRadiusX * 0.6) do
		for z = -math.floor(waterRadiusZ * 0.6), math.floor(waterRadiusZ * 0.6) do
			makePondPart(deepWaterFolder, "DeepWaterBlock", Vector3.new(block, 0.35, block), Vector3.new(x * block, 0.95, z * block), deepWaterColor, Enum.Material.Glass, 0.5, false)
		end
	end

	for x = -borderRadiusX, borderRadiusX do
		for z = -borderRadiusZ, borderRadiusZ do
			if math.abs(x) == borderRadiusX or math.abs(z) == borderRadiusZ then
				makePondPart(pondBorderFolder, "StonePondBorder", Vector3.new(block, 1.5, block), Vector3.new(x * block, 2.75, z * block), ((x + z) % 2 == 0) and stoneDark or stoneColor, Enum.Material.Cobblestone)
			end
		end
	end

	local function addFishingSpot(name, position, facingDirection)
		local spot = makePondPart(spotsFolder, name, Vector3.new(4, 1, 4), position, Color3.fromRGB(0, 255, 120), Enum.Material.ForceField, 1, false)
		spot:SetAttribute("AreaName", areaName)
		spot:SetAttribute("FishPool", "Beginner")
		spot:SetAttribute("FacingDirection", facingDirection)
		CollectionService:AddTag(spot, "FishingSpot")
		return spot
	end

	local function makeDockPlanks(folder, name, xMin, xMax, zMin, zMax)
		for x = xMin, xMax do
			for z = zMin, zMax do
				makePondPart(folder, name, Vector3.new(block, 0.6, block), Vector3.new(x * block, 3.35, z * block), woodColor, Enum.Material.WoodPlanks)
			end
		end
	end

	makeDockPlanks(eastDockFolder, "EastDockPlank", eastDockInnerX, eastDockOuterX, -dockHalfWidth, dockHalfWidth)
	makeDockPlanks(westDockFolder, "WestDockPlank", westDockOuterX, westDockInnerX, -dockHalfWidth, dockHalfWidth)
	makeDockPlanks(northDockFolder, "NorthDockPlank", -dockHalfWidth, dockHalfWidth, northDockOuterZ, northDockInnerZ)
	makeDockPlanks(southDockFolder, "SouthDockPlank", -dockHalfWidth, dockHalfWidth, southDockInnerZ, southDockOuterZ)

	local cornerPlatforms = {
		{ cornerPlatformX, cornerPlatformZ, "NEPlatform" },
		{ -cornerPlatformX, cornerPlatformZ, "NWPlatform" },
		{ cornerPlatformX, -cornerPlatformZ, "SEPlatform" },
		{ -cornerPlatformX, -cornerPlatformZ, "SWPlatform" },
	}

	for _, data in ipairs(cornerPlatforms) do
		local centerX, centerZ, prefix = data[1], data[2], data[3]
		for dx = -1, 1 do
			for dz = -1, 1 do
				makePondPart(platformDockFolder, prefix .. "_Plank", Vector3.new(block, 0.6, block), Vector3.new((centerX + dx) * block, 3.35, (centerZ + dz) * block), woodColor, Enum.Material.WoodPlanks)
			end
		end
	end

	local dockPosts = {}
	local function addPost(x, z)
		table.insert(dockPosts, Vector3.new(x * block, 1.5, z * block))
	end

	for _, x in ipairs({ eastDockInnerX, eastDockOuterX, westDockInnerX, westDockOuterX }) do
		for _, z in ipairs({ -dockHalfWidth, 0, dockHalfWidth }) do
			addPost(x, z)
		end
	end
	for _, z in ipairs({ northDockOuterZ, northDockInnerZ, southDockInnerZ, southDockOuterZ }) do
		for _, x in ipairs({ -dockHalfWidth, 0, dockHalfWidth }) do
			addPost(x, z)
		end
	end
	for _, data in ipairs(cornerPlatforms) do
		local centerX, centerZ = data[1], data[2]
		addPost(centerX - 1, centerZ - 1)
		addPost(centerX + 1, centerZ - 1)
		addPost(centerX - 1, centerZ + 1)
		addPost(centerX + 1, centerZ + 1)
	end
	for _, pos in ipairs(dockPosts) do
		makePondPart(dockPostsFolder, "DockPost", Vector3.new(1, 4.5, 1), pos, woodDark, Enum.Material.Wood)
	end

	for i = -dockHalfWidth, dockHalfWidth do
		addFishingSpot("FishingSpot_East_Inner_" .. i, Vector3.new((waterRadiusX - 1) * block, 4.1, i * block), "West")
		addFishingSpot("FishingSpot_East_Outer_" .. i, Vector3.new((waterRadiusX + 2) * block, 4.1, i * block), "West")
		addFishingSpot("FishingSpot_West_Inner_" .. i, Vector3.new(-(waterRadiusX - 1) * block, 4.1, i * block), "East")
		addFishingSpot("FishingSpot_West_Outer_" .. i, Vector3.new(-(waterRadiusX + 2) * block, 4.1, i * block), "East")
		addFishingSpot("FishingSpot_North_Inner_" .. i, Vector3.new(i * block, 4.1, -(waterRadiusZ + 1) * block), "South")
		addFishingSpot("FishingSpot_North_Outer_" .. i, Vector3.new(i * block, 4.1, -(waterRadiusZ + 4) * block), "South")
		addFishingSpot("FishingSpot_South_Inner_" .. i, Vector3.new(i * block, 4.1, (waterRadiusZ + 1) * block), "North")
		addFishingSpot("FishingSpot_South_Outer_" .. i, Vector3.new(i * block, 4.1, (waterRadiusZ + 4) * block), "North")
	end

	addFishingSpot("FishingSpot_NE_1", Vector3.new(cornerPlatformX * block, 4.1, cornerPlatformZ * block), "SouthWest")
	addFishingSpot("FishingSpot_NE_2", Vector3.new((cornerPlatformX + 1) * block, 4.1, cornerPlatformZ * block), "SouthWest")
	addFishingSpot("FishingSpot_NW_1", Vector3.new(-cornerPlatformX * block, 4.1, cornerPlatformZ * block), "SouthEast")
	addFishingSpot("FishingSpot_NW_2", Vector3.new(-(cornerPlatformX + 1) * block, 4.1, cornerPlatformZ * block), "SouthEast")
	addFishingSpot("FishingSpot_SE_1", Vector3.new(cornerPlatformX * block, 4.1, -cornerPlatformZ * block), "NorthWest")
	addFishingSpot("FishingSpot_SE_2", Vector3.new((cornerPlatformX + 1) * block, 4.1, -cornerPlatformZ * block), "NorthWest")
	addFishingSpot("FishingSpot_SW_1", Vector3.new(-cornerPlatformX * block, 4.1, -cornerPlatformZ * block), "NorthEast")
	addFishingSpot("FishingSpot_SW_2", Vector3.new(-(cornerPlatformX + 1) * block, 4.1, -cornerPlatformZ * block), "NorthEast")

	local pathTiles = {}
	for x = -pathRadiusX, pathRadiusX do
		table.insert(pathTiles, { x, pathRadiusZ })
		table.insert(pathTiles, { x, -pathRadiusZ })
	end
	for z = -pathRadiusZ, pathRadiusZ do
		table.insert(pathTiles, { pathRadiusX, z })
		table.insert(pathTiles, { -pathRadiusX, z })
	end
	for x = -5, 5 do
		for _, z in ipairs({ pathRadiusZ - 1, pathRadiusZ - 2, -pathRadiusZ + 1, -pathRadiusZ + 2 }) do
			table.insert(pathTiles, { x, z })
		end
	end
	for z = -5, 5 do
		for _, x in ipairs({ pathRadiusX - 1, pathRadiusX - 2, -pathRadiusX + 1, -pathRadiusX + 2 }) do
			table.insert(pathTiles, { x, z })
		end
	end
	for _, p in ipairs(pathTiles) do
		makePondPart(pathsFolder, "DirtPath", Vector3.new(block, 0.28, block), Vector3.new(p[1] * block, 2.35, p[2] * block), Color3.fromRGB(150, 105, 60), Enum.Material.Ground)
	end

	local reedBaseY = 1.05
	for _, basePos in ipairs({
		Vector3.new(-(waterRadiusX * block + 2), reedBaseY, -44), Vector3.new(-(waterRadiusX * block + 2), reedBaseY, 44),
		Vector3.new(waterRadiusX * block + 2, reedBaseY, -44), Vector3.new(waterRadiusX * block + 2, reedBaseY, 44),
		Vector3.new(-48, reedBaseY, -(waterRadiusZ * block + 2)), Vector3.new(48, reedBaseY, -(waterRadiusZ * block + 2)),
		Vector3.new(-48, reedBaseY, waterRadiusZ * block + 2), Vector3.new(48, reedBaseY, waterRadiusZ * block + 2),
		Vector3.new(0, reedBaseY, -(waterRadiusZ * block + 2)), Vector3.new(0, reedBaseY, waterRadiusZ * block + 2),
		Vector3.new(-(waterRadiusX * block + 2), reedBaseY, 0), Vector3.new(waterRadiusX * block + 2, reedBaseY, 0),
		Vector3.new(-60, reedBaseY, -20), Vector3.new(60, reedBaseY, 20),
		Vector3.new(-20, reedBaseY, 52), Vector3.new(20, reedBaseY, -52),
	}) do
		for i = 1, 3 do
			local height = 3 + i
			local pos = basePos + Vector3.new((i - 2) * 0.7, height / 2, 0)
			makePondPart(decorFolder, "Reed", Vector3.new(0.45, height, 0.45), pos, reedColor, Enum.Material.Grass)
			makePondPart(decorFolder, "CattailHead", Vector3.new(0.55, 1.1, 0.55), pos + Vector3.new(0, height / 2 + 0.35, 0), Color3.fromRGB(105, 65, 35), Enum.Material.Wood)
		end
	end

	for _, pos in ipairs({
		Vector3.new(-50, 1.25, -36), Vector3.new(-40, 1.25, 24), Vector3.new(-26, 1.25, -40),
		Vector3.new(-10, 1.25, 10), Vector3.new(0, 1.25, 0), Vector3.new(10, 1.25, -10),
		Vector3.new(26, 1.25, 40), Vector3.new(40, 1.25, -24), Vector3.new(50, 1.25, 36),
		Vector3.new(34, 1.25, 10), Vector3.new(-34, 1.25, -10), Vector3.new(16, 1.25, 30),
		Vector3.new(-16, 1.25, -30),
	}) do
		makePondPart(lilyPadsFolder, "LilyPad", Vector3.new(3, 0.18, 2.2), pos, Color3.fromRGB(45, 150, 55), Enum.Material.Grass, 0, false)
		makePondPart(lilyPadsFolder, "LilyFlower", Vector3.new(0.8, 0.25, 0.8), pos + Vector3.new(0.4, 0.2, 0), flowerWhite, Enum.Material.SmoothPlastic, 0, false)
	end

	for _, f in ipairs({
		{ -20, -16, flowerWhite }, { -19, -16, flowerYellow }, { -21, -14, flowerPurple },
		{ 20, -16, flowerYellow }, { 21, -14, flowerPurple }, { -20, 16, flowerPurple },
		{ -19, 17, flowerWhite }, { 20, 16, flowerWhite }, { 21, 17, flowerYellow },
		{ -8, 20, flowerPurple }, { 8, -20, flowerWhite }, { -22, 5, flowerYellow },
		{ 22, -5, flowerPurple }, { -15, 18, flowerBlue }, { 15, -18, flowerBlue },
		{ -18, -3, flowerWhite }, { 18, 3, flowerYellow }, { -27, -19, flowerWhite },
		{ -26, 19, flowerYellow }, { 27, -19, flowerPurple }, { 26, 19, flowerWhite },
		{ -24, 9, flowerBlue }, { 24, -9, flowerBlue },
	}) do
		makePondPart(decorFolder, "FlowerStem", Vector3.new(0.35, 1.2, 0.35), Vector3.new(f[1] * block, 3, f[2] * block), reedColor, Enum.Material.Grass)
		makePondPart(decorFolder, "FlowerTop", Vector3.new(1, 0.35, 1), Vector3.new(f[1] * block, 3.8, f[2] * block), f[3], Enum.Material.SmoothPlastic)
	end

	for _, g in ipairs({
		{ -22, -6 }, { -22, 6 }, { -18, 0 }, { -6, -20 }, { 6, -20 },
		{ 18, 0 }, { 22, 6 }, { -6, 20 }, { 6, 20 }, { -18, -18 },
		{ 18, -18 }, { -18, 18 }, { 18, 18 }, { -12, 15 }, { 12, -15 },
		{ -15, -12 }, { 15, 12 }, { -27, -10 }, { -27, 10 }, { 27, -10 },
		{ 27, 10 }, { -10, -24 }, { 10, -24 }, { -10, 24 }, { 10, 24 },
	}) do
		makePondPart(decorFolder, "TallGrass", Vector3.new(0.8, 2.2, 0.8), Vector3.new(g[1] * block, 3.2, g[2] * block), grassDark, Enum.Material.Grass, 0, false)
	end

	local function makeTree(x, z)
		makePondPart(treesFolder, "TreeTrunk", Vector3.new(3, 12, 3), Vector3.new(x, 8, z), Color3.fromRGB(100, 65, 35), Enum.Material.Wood)
		makePondPart(treesFolder, "TreeLeaves", Vector3.new(10, 8, 10), Vector3.new(x, 18, z), leafColor, Enum.Material.Grass)
		makePondPart(treesFolder, "TreeLeavesTop", Vector3.new(7, 5, 7), Vector3.new(x, 24, z), leafColor, Enum.Material.Grass)
	end

	for _, treePos in ipairs({
		Vector3.new(-112, 0, -96), Vector3.new(112, 0, -96), Vector3.new(-112, 0, 96), Vector3.new(112, 0, 96),
		Vector3.new(-68, 0, -98), Vector3.new(68, 0, 98), Vector3.new(0, 0, -100), Vector3.new(0, 0, 100),
		Vector3.new(-112, 0, 0), Vector3.new(112, 0, 0),
	}) do
		makeTree(treePos.X, treePos.Z)
	end

	local function makeLantern(position)
		makePondPart(lampsFolder, "LanternPost", Vector3.new(0.8, 4, 0.8), position, woodDark, Enum.Material.Wood)
		local lantern = makePondPart(lampsFolder, "Lantern", Vector3.new(1.3, 1.3, 1.3), position + Vector3.new(0, 2.6, 0), Color3.fromRGB(255, 215, 120), Enum.Material.Glass, 0.35, false)
		local light = Instance.new("PointLight")
		light.Brightness = 0.18
		light.Range = 9
		light.Color = Color3.fromRGB(255, 220, 150)
		light.Parent = lantern
	end

	for _, pos in ipairs({
		Vector3.new(-86, 5, -66), Vector3.new(86, 5, -66), Vector3.new(-86, 5, 66), Vector3.new(86, 5, 66),
		Vector3.new(78, 5, 18), Vector3.new(78, 5, -18), Vector3.new(-78, 5, 18), Vector3.new(-78, 5, -18),
		Vector3.new(-18, 5, -78), Vector3.new(18, 5, -78), Vector3.new(-18, 5, 78), Vector3.new(18, 5, 78),
		Vector3.new(104, 5, 0), Vector3.new(-104, 5, 0), Vector3.new(0, 5, 92), Vector3.new(0, 5, -92),
	}) do
		makeLantern(pos)
	end

	makePondPart(signsFolder, "SignPost", Vector3.new(1, 5, 1), Vector3.new(-8, 4.5, 104), woodDark, Enum.Material.Wood)
	local signBoard = makePondPart(signsFolder, "BeginnerPondSign", Vector3.new(12, 5, 0.5), Vector3.new(-8, 8, 103.5), woodColor, Enum.Material.Wood)
	createLabel(signBoard, "Beginner\nPond")

	local barrierHeight = 36
	local barrierThickness = 4
	local outerX = (groundRadiusX * block) + (block / 2)
	local outerZ = (groundRadiusZ * block) + (block / 2)
	local barrierY = 14
	for _, barrier in ipairs({
		{ "BeginnerAreaBarrier_North", Vector3.new((outerX * 2) + barrierThickness, barrierHeight, barrierThickness), Vector3.new(0, barrierY, -outerZ - (barrierThickness / 2)) },
		{ "BeginnerAreaBarrier_South", Vector3.new((outerX * 2) + barrierThickness, barrierHeight, barrierThickness), Vector3.new(0, barrierY, outerZ + (barrierThickness / 2)) },
		{ "BeginnerAreaBarrier_West", Vector3.new(barrierThickness, barrierHeight, (outerZ * 2) + barrierThickness), Vector3.new(-outerX - (barrierThickness / 2), barrierY, 0) },
		{ "BeginnerAreaBarrier_East", Vector3.new(barrierThickness, barrierHeight, (outerZ * 2) + barrierThickness), Vector3.new(outerX + (barrierThickness / 2), barrierY, 0) },
	}) do
		local wall = makePondPart(barriersFolder, barrier[1], barrier[2], barrier[3], Color3.fromRGB(0, 210, 255), Enum.Material.ForceField, 1, true)
		wall.CanTouch = false
		wall.CanQuery = true
	end

	local fishZone = makePondPart(fishingZoneFolder, "FishZone", Vector3.new((waterRadiusX * 2 + 4) * block, 12, (waterRadiusZ * 2 + 4) * block), Vector3.new(0, 5, 0), Color3.fromRGB(0, 255, 255), Enum.Material.ForceField, 1, false)
	fishZone:SetAttribute("AreaName", areaName)
	fishZone:SetAttribute("MinLevel", 1)
	fishZone:SetAttribute("FishPool", "Beginner")
	fishZone:SetAttribute("CommonChance", 75)
	fishZone:SetAttribute("UncommonChance", 20)
	fishZone:SetAttribute("RareChance", 5)
	fishZone:SetAttribute("MaxPlayersSuggested", 56)
	CollectionService:AddTag(fishZone, "FishingZone")

	pond.PrimaryPart = fishZone
	return pond
end

return BeginnerPondBuilder
