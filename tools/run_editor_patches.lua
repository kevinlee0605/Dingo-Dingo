-- Run this once in Roblox Studio's Command Bar while editing the place.
-- It applies all current saved-editor map patches. Save the place afterward.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function isInsideFishyFishWorld(instance)
	local current = instance.Parent
	while current do
		if current.Name == "FishyFishWorld" then
			return true
		end
		current = current.Parent
	end

	return false
end

local function findSavedModel(modelName)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == modelName and not isInsideFishyFishWorld(descendant) then
			return descendant
		end
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == modelName then
			return descendant
		end
	end

	return nil
end

local function findSavedLobbyArea()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "LobbyArea" and not isInsideFishyFishWorld(descendant) then
			return descendant
		end
	end

	local lobby = Workspace:FindFirstChild("LobbyArea", true)
	if lobby and lobby:IsA("Model") then
		return lobby
	end

	return nil
end

local function getModelBaseCFrame(model, patchName)
	local primary = model.PrimaryPart or model:FindFirstChild("ShopPrimaryPart", true)
	if primary and primary:IsA("BasePart") then
		return primary.CFrame * CFrame.new(0, -4, 0)
	end

	local success, pivot = pcall(function()
		return model:GetPivot()
	end)

	if not success then
		warn(patchName .. ": could not calculate " .. model.Name .. " position.")
		return nil
	end

	return pivot * CFrame.new(0, -4, 0)
end

local function createSurfaceLabel(part, textValue)
	local oldGui = part:FindFirstChildOfClass("SurfaceGui")
	if oldGui then
		oldGui:Destroy()
	end

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

local solidSmallDecorFolders = {
	LimestoneLobbySmallBeachDecor = true,
	LimestoneLobbySmallAnimalDecor = true,
	LimestoneLobbyOnePieceBeachDecor = true,
}

local function makeSmallDecorSolid(root)
	local function makeAnimalBlocker(target)
		local cframe
		local size
		if target:IsA("Model") then
			cframe, size = target:GetBoundingBox()
		elseif target:IsA("BasePart") then
			cframe = target.CFrame
			size = target.Size
		else
			return
		end

		local blockerName = target.Name .. "_CollisionBlocker"
		local blocker = root:FindFirstChild(blockerName)
		if not blocker then
			blocker = Instance.new("Part")
			blocker.Name = blockerName
			blocker.Parent = root
		end

		local blockerHeight = 5
		local bottomY = cframe.Position.Y - (size.Y / 2)
		blocker.Anchored = true
		blocker.Size = Vector3.new(math.max(size.X + 1.2, 4), blockerHeight, math.max(size.Z + 1.2, 4))
		blocker.CFrame = CFrame.new(cframe.Position.X, bottomY + (blockerHeight / 2), cframe.Position.Z)
		blocker.Transparency = 1
		blocker.Color = Color3.fromRGB(255, 0, 255)
		blocker.Material = Enum.Material.SmoothPlastic
		blocker.CanCollide = true
		blocker.CanTouch = false
		blocker.CanQuery = true
		pcall(function()
			blocker.CollisionGroup = "Default"
		end)
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local helperPart = descendant.Name == "PrimaryPart"
				or string.find(descendant.Name, "_CollisionBlocker") ~= nil
				or descendant.Transparency >= 0.95
				or descendant.Material == Enum.Material.ForceField

			descendant.CanCollide = not helperPart
			descendant.CanTouch = false
			descendant.CanQuery = true
			pcall(function()
				descendant.CollisionGroup = "Default"
			end)
		end
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == "SmallCrab"
			or descendant.Name == "SmallTurtle"
			or descendant.Name == "OnePieceSmallCrab"
			or descendant.Name == "OnePieceSmallTurtle" then
			makeAnimalBlocker(descendant)
		end
	end
end

local function applySmallDecorCollision()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if (descendant:IsA("Folder") or descendant:IsA("Model")) and solidSmallDecorFolders[descendant.Name] then
			makeSmallDecorSolid(descendant)
		end
	end

	print("Small decor collision patch: visible beach and animal decor parts are solid.")
end

local function applyLimestoneLobbySpawn()
	local target = Vector3.new(-147, 10, -492)
	local definition = Workspace:FindFirstChild("LobbyDefinition")
	if not definition then
		definition = Instance.new("Folder")
		definition.Name = "LobbyDefinition"
		definition.Parent = Workspace
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { definition }

	local result = Workspace:Raycast(Vector3.new(target.X, 220, target.Z), Vector3.new(0, -500, 0), params)
	local groundY = result and result.Position.Y or 5
	local spawnPosition = Vector3.new(target.X, groundY + 0.6, target.Z)

	local spawn = definition:FindFirstChild("LobbySpawn")
	if spawn and not spawn:IsA("SpawnLocation") then
		spawn:Destroy()
		spawn = nil
	end
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "LobbySpawn"
		spawn.Parent = definition
	end

	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = spawnPosition
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(80, 180, 255)
	spawn:SetAttribute("Purpose", "Player lobby spawn")

	for _, descendant in ipairs(spawn:GetDescendants()) do
		if descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant:Destroy()
		end
	end

	local marker = definition:FindFirstChild("LimestoneLobbySpawn")
	if marker and not marker:IsA("BasePart") then
		marker:Destroy()
		marker = nil
	end
	if not marker then
		marker = Instance.new("Part")
		marker.Name = "LimestoneLobbySpawn"
		marker.Parent = definition
	end

	marker.Size = Vector3.new(8, 0.4, 8)
	marker.Position = spawnPosition
	marker.Anchored = true
	marker.Transparency = 1
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = true
	marker.Material = Enum.Material.SmoothPlastic
	marker.Color = Color3.fromRGB(80, 180, 255)
	marker:SetAttribute("Purpose", "Lobby teleport marker")

	print(("Limestone lobby spawn patch: moved spawn to %.1f, %.1f, %.1f."):format(spawnPosition.X, spawnPosition.Y, spawnPosition.Z))
end

local function applySoftLightingProfile()
	Lighting.Ambient = Color3.fromRGB(118, 116, 108)
	Lighting.Brightness = 1.35
	Lighting.EnvironmentDiffuseScale = 0.62
	Lighting.EnvironmentSpecularScale = 0.02
	Lighting.ExposureCompensation = -0.18
	Lighting.GlobalShadows = false
	Lighting.OutdoorAmbient = Color3.fromRGB(142, 138, 125)

	for _, effect in ipairs(Lighting:GetChildren()) do
		if effect:IsA("BloomEffect") then
			effect.Enabled = false
			effect.Intensity = 0.02
			effect.Size = 8
			effect.Threshold = 2.25
		elseif effect:IsA("SunRaysEffect") then
			effect.Enabled = false
			effect.Intensity = 0.02
			effect.Spread = 0.05
		end
	end

	local bloom = Lighting:FindFirstChild("MapBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "MapBloom"
		bloom.Parent = Lighting
	end
	bloom.Enabled = false
	bloom.Intensity = 0.02
	bloom.Size = 8
	bloom.Threshold = 2.25

	local sunRays = Lighting:FindFirstChild("MapSunRays")
	if not sunRays then
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = "MapSunRays"
		sunRays.Parent = Lighting
	end
	sunRays.Enabled = false
	sunRays.Intensity = 0.02
	sunRays.Spread = 0.05

	local function isBeachPathLight(light)
		local lowerName = string.lower(light.Name)
		local lowerFullName = string.lower(light:GetFullName())

		return lowerName == "warmbeachpathlight"
			or string.find(lowerFullName, "beachpathlightpost") ~= nil
			or string.find(lowerFullName, "warmglasslantern") ~= nil
	end

	local function shouldSoftenNeonPart(part)
		local lowerName = string.lower(part.Name)
		local lowerFullName = string.lower(part:GetFullName())

		if string.find(lowerFullName, "personalaquariums") or string.find(lowerFullName, "fishmodel") then
			return false
		end

		return string.find(lowerName, "lantern") ~= nil
			or string.find(lowerName, "light") ~= nil
			or string.find(lowerName, "lamp") ~= nil
			or string.find(lowerName, "glow") ~= nil
	end

	local lightCount = 0
	local neonCount = 0
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
			if isBeachPathLight(descendant) then
				descendant.Brightness = 0.05
				descendant.Range = 6
			else
				descendant.Brightness = math.min(descendant.Brightness, 0.18)
				descendant.Range = math.min(descendant.Range, 9)
			end
			descendant.Shadows = false
			lightCount += 1
		elseif descendant:IsA("BasePart") and descendant.Material == Enum.Material.Neon then
			if shouldSoftenNeonPart(descendant) then
				descendant.Material = Enum.Material.Glass
				descendant.Transparency = math.max(descendant.Transparency, 0.3)
				neonCount += 1
			end
		end
	end

	print(("Soft lighting patch: evened lobby light and softened %d local lights / %d neon lamp parts."):format(lightCount, neonCount))
end

local function applyBeginnerPondArea()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local builderModule = shared and shared:FindFirstChild("BeginnerPondBuilder")
	if not builderModule then
		warn("Beginner Pond editor patch: BeginnerPondBuilder is not synced yet. Connect Rojo, sync source, then run this patch again.")
		return
	end

	local world = Workspace:FindFirstChild("FishyFishWorld")
	if not world then
		world = Instance.new("Folder")
		world.Name = "FishyFishWorld"
		world.Parent = Workspace
	end

	local ok, builder = pcall(require, builderModule)
	if not ok or type(builder) ~= "table" or type(builder.build) ~= "function" then
		warn("Beginner Pond editor patch: could not load BeginnerPondBuilder.")
		return
	end

	builder.build(world, {
		position = Vector3.new(0, 8, 0),
		color = Color3.fromRGB(74, 163, 104),
	})

	print("Beginner Pond editor patch: rebuilt BeginnerPondArea to match Play mode.")
end

local function applyLimestoneLobbySafetyBorder()
	local lobby = findSavedLobbyArea()
	if not lobby then
		warn("Limestone lobby safety border patch: could not find LobbyArea.")
		return
	end

	local ignoredAncestors = {
		LimestoneLobbySafetyBorder = true,
		LimestoneLobbyPathLights = true,
		LimestoneLobbySmallBeachDecor = true,
		LimestoneLobbySmallAnimalDecor = true,
		LimestoneLobbyOnePieceBeachDecor = true,
	}

	local function hasIgnoredAncestor(instance)
		local current = instance
		while current and current ~= lobby do
			if ignoredAncestors[current.Name] then
				return true
			end
			current = current.Parent
		end

		return false
	end

	local function isFloorCandidate(part)
		if hasIgnoredAncestor(part) then
			return false
		end

		local lowerName = string.lower(part.Name)
		if string.find(lowerName, "trigger")
			or string.find(lowerName, "zone")
			or string.find(lowerName, "sign")
			or string.find(lowerName, "roof")
			or string.find(lowerName, "awning")
			or string.find(lowerName, "wall")
			or string.find(lowerName, "border")
			or string.find(lowerName, "lantern")
		then
			return false
		end

		if part.Transparency >= 0.95 and part.Material == Enum.Material.ForceField then
			return false
		end

		if part.Position.Y > 12 or part.Size.Y > 4 then
			return false
		end

		if part.Size.X < 2 or part.Size.Z < 2 then
			return false
		end

		return (part.Size.X * part.Size.Z) >= 16
	end

	local minX = math.huge
	local maxX = -math.huge
	local minZ = math.huge
	local maxZ = -math.huge
	local lowestY = math.huge
	local candidateCount = 0

	for _, descendant in ipairs(lobby:GetDescendants()) do
		if descendant:IsA("BasePart") and isFloorCandidate(descendant) then
			candidateCount += 1
			lowestY = math.min(lowestY, descendant.Position.Y - (descendant.Size.Y / 2))

			for _, xSign in ipairs({ -1, 1 }) do
				for _, zSign in ipairs({ -1, 1 }) do
					local corner = descendant.CFrame:PointToWorldSpace(Vector3.new(
						xSign * descendant.Size.X / 2,
						0,
						zSign * descendant.Size.Z / 2
					))
					minX = math.min(minX, corner.X)
					maxX = math.max(maxX, corner.X)
					minZ = math.min(minZ, corner.Z)
					maxZ = math.max(maxZ, corner.Z)
				end
			end
		end
	end

	if candidateCount == 0 then
		warn("Limestone lobby safety border patch: no floor parts found for LobbyArea.")
		return
	end

	local borderFolder = lobby:FindFirstChild("LimestoneLobbySafetyBorder")
	if borderFolder and not borderFolder:IsA("Folder") then
		warn("Limestone lobby safety border patch: LimestoneLobbySafetyBorder exists but is not a Folder.")
		return
	end

	if not borderFolder then
		borderFolder = Instance.new("Folder")
		borderFolder.Name = "LimestoneLobbySafetyBorder"
		borderFolder.Parent = lobby
	end

	local edgeInset = 4
	local wallHeight = 64
	local wallThickness = 8
	local centerX = (minX + maxX) / 2
	local centerZ = (minZ + maxZ) / 2
	local width = (maxX - minX) + (wallThickness * 2)
	local depth = (maxZ - minZ) + (wallThickness * 2)
	local bottomY = lowestY - 2
	local wallY = bottomY + (wallHeight / 2)

	local function makeWall(name, size, position)
		local wall = borderFolder:FindFirstChild(name)
		if wall and not wall:IsA("BasePart") then
			warn("Limestone lobby safety border patch: " .. name .. " exists but is not a BasePart.")
			return nil
		end

		if not wall then
			wall = Instance.new("Part")
			wall.Name = name
			wall.Parent = borderFolder
		end

		wall.Anchored = true
		wall.Size = size
		wall.Position = position
		wall.Color = Color3.fromRGB(80, 210, 255)
		wall.Material = Enum.Material.ForceField
		wall.Transparency = 1
		wall.CanCollide = true
		wall.CanTouch = false
		wall.CanQuery = true
		wall.TopSurface = Enum.SurfaceType.Smooth
		wall.BottomSurface = Enum.SurfaceType.Smooth
		pcall(function()
			wall.CollisionGroup = "Default"
		end)
		return wall
	end

	makeWall("LimestoneLobbySafetyWall_North", Vector3.new(width, wallHeight, wallThickness), Vector3.new(centerX, wallY, minZ + edgeInset - wallThickness / 2))
	makeWall("LimestoneLobbySafetyWall_South", Vector3.new(width, wallHeight, wallThickness), Vector3.new(centerX, wallY, maxZ - edgeInset + wallThickness / 2))
	makeWall("LimestoneLobbySafetyWall_West", Vector3.new(wallThickness, wallHeight, depth), Vector3.new(minX + edgeInset - wallThickness / 2, wallY, centerZ))
	makeWall("LimestoneLobbySafetyWall_East", Vector3.new(wallThickness, wallHeight, depth), Vector3.new(maxX - edgeInset + wallThickness / 2, wallY, centerZ))

	print(("Limestone lobby safety border patch: placed transparent border from %d floor parts."):format(candidateCount))
end

local function applyLimestoneLobbyPathLights()
	local lobby = findSavedLobbyArea()
	if not lobby then
		warn("Limestone lobby path lights patch: could not find LobbyArea.")
		return
	end

	local lightsFolder = lobby:FindFirstChild("LimestoneLobbyPathLights")
	if lightsFolder and not lightsFolder:IsA("Folder") then
		warn("Limestone lobby path lights patch: LimestoneLobbyPathLights exists but is not a Folder.")
		return
	end

	if not lightsFolder then
		lightsFolder = Instance.new("Folder")
		lightsFolder.Name = "LimestoneLobbyPathLights"
		lightsFolder.Parent = lobby
	end

	local borderFolder = lobby:FindFirstChild("LimestoneLobbySafetyBorder")
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = borderFolder and { lightsFolder, borderFolder } or { lightsFolder }

	local pathBoundsByName = {}
	local function extendBounds(key, part)
		local bounds = pathBoundsByName[key]
		if not bounds then
			bounds = {
				minX = math.huge,
				maxX = -math.huge,
				minZ = math.huge,
				maxZ = -math.huge,
				topY = -math.huge,
				count = 0,
			}
			pathBoundsByName[key] = bounds
		end

		bounds.count += 1
		bounds.topY = math.max(bounds.topY, part.Position.Y + (part.Size.Y / 2))

		for _, xSign in ipairs({ -1, 1 }) do
			for _, zSign in ipairs({ -1, 1 }) do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(
					xSign * part.Size.X / 2,
					0,
					zSign * part.Size.Z / 2
				))
				bounds.minX = math.min(bounds.minX, corner.X)
				bounds.maxX = math.max(bounds.maxX, corner.X)
				bounds.minZ = math.min(bounds.minZ, corner.Z)
				bounds.maxZ = math.max(bounds.maxZ, corner.Z)
			end
		end
	end

	local exactPathNames = {
		FountainPlazaTile = true,
		SpawnToFountainPath = true,
		FountainToBiomePath = true,
		LeftRightPath = true,
		FishShopPath = true,
		RodShopPath = true,
	}

	for _, descendant in ipairs(lobby:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if exactPathNames[descendant.Name] then
				extendBounds(descendant.Name, descendant)
			else
				local lowerName = string.lower(descendant.Name)
				if string.find(lowerName, "path")
					and not string.find(lowerName, "wood")
					and not string.find(lowerName, "deck")
					and descendant.Size.X >= 2
					and descendant.Size.Z >= 2
					and descendant.Position.Y < 8
				then
					extendBounds("OtherBrickPath", descendant)
				end
			end
		end
	end

	local lightSpecs = {}
	local function addLight(name, x, z, fallbackY, yawDegrees)
		table.insert(lightSpecs, {
			name = name,
			x = x,
			z = z,
			fallbackY = fallbackY,
			yaw = yawDegrees or 0,
		})
	end

	local function addCornerLights(bounds)
		if not bounds then
			return
		end

		local offset = 7
		addLight("FountainCornerNW", bounds.minX - offset, bounds.minZ - offset, bounds.topY, 45)
		addLight("FountainCornerNE", bounds.maxX + offset, bounds.minZ - offset, bounds.topY, -45)
		addLight("FountainCornerSW", bounds.minX - offset, bounds.maxZ + offset, bounds.topY, 135)
		addLight("FountainCornerSE", bounds.maxX + offset, bounds.maxZ + offset, bounds.topY, -135)
	end

	local function addPerimeterLights(bounds)
		if not bounds then
			return
		end

		local offset = 7
		local width = bounds.maxX - bounds.minX
		local depth = bounds.maxZ - bounds.minZ

		for index, fraction in ipairs({ 0.22, 0.5, 0.78 }) do
			local x = bounds.minX + (width * fraction)
			addLight("PlazaNorthLight_" .. tostring(index), x, bounds.minZ - offset, bounds.topY, 0)
			addLight("PlazaSouthLight_" .. tostring(index), x, bounds.maxZ + offset, bounds.topY, 180)
		end

		for index, fraction in ipairs({ 0.34, 0.66 }) do
			local z = bounds.minZ + (depth * fraction)
			addLight("PlazaWestLight_" .. tostring(index), bounds.minX - offset, z, bounds.topY, 90)
			addLight("PlazaEastLight_" .. tostring(index), bounds.maxX + offset, z, bounds.topY, -90)
		end
	end

	local function addAlongPath(pathName, lightPrefix, fractions)
		local bounds = pathBoundsByName[pathName]
		if not bounds then
			return
		end

		local width = bounds.maxX - bounds.minX
		local depth = bounds.maxZ - bounds.minZ
		local sideOffset = 6

		for index, fraction in ipairs(fractions) do
			local side = (index % 2 == 0) and 1 or -1
			if width >= depth then
				local x = bounds.minX + (width * fraction)
				local z = (side < 0) and (bounds.minZ - sideOffset) or (bounds.maxZ + sideOffset)
				addLight(lightPrefix .. tostring(index), x, z, bounds.topY, side < 0 and 0 or 180)
			else
				local x = (side < 0) and (bounds.minX - sideOffset) or (bounds.maxX + sideOffset)
				local z = bounds.minZ + (depth * fraction)
				addLight(lightPrefix .. tostring(index), x, z, bounds.topY, side < 0 and 90 or -90)
			end
		end
	end

	addCornerLights(pathBoundsByName.FountainPlazaTile)
	addPerimeterLights(pathBoundsByName.FountainPlazaTile)
	addAlongPath("SpawnToFountainPath", "SpawnPathLight_", { 0.28, 0.68 })
	addAlongPath("FountainToBiomePath", "BiomePathLight_", { 0.32, 0.72 })
	addAlongPath("LeftRightPath", "CrossPathLight_", { 0.18, 0.38, 0.62, 0.82 })
	addAlongPath("FishShopPath", "FishShopPathLight_", { 0.45 })
	addAlongPath("RodShopPath", "RodShopPathLight_", { 0.55 })

	if #lightSpecs == 0 then
		warn("Limestone lobby path lights patch: could not find brick path parts.")
		return
	end

	local function groundYAt(x, z, fallbackY)
		local result = Workspace:Raycast(Vector3.new(x, 180, z), Vector3.new(0, -260, 0), raycastParams)
		if result then
			return result.Position.Y
		end

		return fallbackY or 3
	end

	local function getOrCreatePart(parent, name)
		local part = parent:FindFirstChild(name)
		if part and not part:IsA("BasePart") then
			warn("Limestone lobby path lights patch: " .. name .. " exists but is not a BasePart.")
			return nil
		end

		if not part then
			part = Instance.new("Part")
			part.Name = name
			part.Parent = parent
		end

		return part
	end

	local function setPart(part, origin, localPosition, size, color, material, transparency, canCollide)
		if not part then
			return nil
		end

		part.Anchored = true
		part.Size = size
		part.CFrame = origin * CFrame.new(localPosition)
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Transparency = transparency or 0
		part.CanCollide = canCollide == true
		part.CanTouch = false
		part.CanQuery = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		pcall(function()
			part.CollisionGroup = "Default"
		end)
		return part
	end

	local function getOrCreateModel(name)
		local model = lightsFolder:FindFirstChild(name)
		if model and not model:IsA("Model") then
			warn("Limestone lobby path lights patch: " .. name .. " exists but is not a Model.")
			return nil, false
		end

		if not model then
			model = Instance.new("Model")
			model.Name = name
			model.Parent = lightsFolder
			return model, true
		end

		return model, false
	end

	local woodDark = Color3.fromRGB(86, 56, 35)
	local woodLight = Color3.fromRGB(154, 101, 54)
	local rope = Color3.fromRGB(212, 185, 126)
	local shell = Color3.fromRGB(242, 235, 199)
	local shellBlue = Color3.fromRGB(116, 205, 230)
	local lanternGlass = Color3.fromRGB(145, 104, 56)
	local glow = Color3.fromRGB(255, 206, 120)
	local metal = Color3.fromRGB(48, 54, 60)
	local lampBrightness = 0.05
	local lampRange = 6

	local function dimExistingPathLightModel(model)
		local lantern = model:FindFirstChild("WarmGlassLantern", true)
		if lantern and lantern:IsA("BasePart") then
			lantern.Color = lanternGlass
			lantern.Material = Enum.Material.Glass
			lantern.Transparency = 0.32

			local pointLight = lantern:FindFirstChild("WarmBeachPathLight")
			if not pointLight then
				pointLight = Instance.new("PointLight")
				pointLight.Name = "WarmBeachPathLight"
				pointLight.Parent = lantern
			end
		end

		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("PointLight") then
				descendant.Brightness = lampBrightness
				descendant.Range = lampRange
				descendant.Color = glow
				descendant.Shadows = false
			end
		end
	end

	local function makePathLight(spec, index)
		local model, created = getOrCreateModel(string.format("BeachPathLightPost_%02d_%s", index, spec.name))
		if not model then
			return
		end

		if not created then
			dimExistingPathLightModel(model)
			return
		end

		local groundY = groundYAt(spec.x, spec.z, spec.fallbackY)
		local origin = CFrame.new(spec.x, groundY, spec.z) * CFrame.Angles(0, math.rad(spec.yaw), 0)

		local base = setPart(getOrCreatePart(model, "SandstoneBase"), origin, Vector3.new(0, 0.24, 0), Vector3.new(3.2, 0.48, 3.2), shell, Enum.Material.Sandstone, 0, true)
		setPart(getOrCreatePart(model, "WoodenPost"), origin, Vector3.new(0, 4.05, 0), Vector3.new(0.85, 7.6, 0.85), woodDark, Enum.Material.Wood, 0, true)
		setPart(getOrCreatePart(model, "LowerRopeWrap"), origin, Vector3.new(0, 2.2, 0), Vector3.new(1.08, 0.28, 1.08), rope, Enum.Material.Fabric, 0, false)
		setPart(getOrCreatePart(model, "UpperRopeWrap"), origin, Vector3.new(0, 6.45, 0), Vector3.new(1.1, 0.3, 1.1), rope, Enum.Material.Fabric, 0, false)
		setPart(getOrCreatePart(model, "ShellCap"), origin, Vector3.new(0, 8.18, 0), Vector3.new(2.3, 0.42, 2.3), shell, Enum.Material.Sandstone, 0, false)
		setPart(getOrCreatePart(model, "ShellBlueStripe"), origin, Vector3.new(0, 8.45, 0), Vector3.new(1.45, 0.18, 1.45), shellBlue, Enum.Material.SmoothPlastic, 0, false)
		setPart(getOrCreatePart(model, "LanternArm"), origin, Vector3.new(1.8, 7.5, 0), Vector3.new(4.8, 0.48, 0.48), woodLight, Enum.Material.Wood, 0, false)
		setPart(getOrCreatePart(model, "LanternHook"), origin, Vector3.new(3.85, 6.75, 0), Vector3.new(0.2, 1.35, 0.2), metal, Enum.Material.Metal, 0, false)

		local lantern = setPart(getOrCreatePart(model, "WarmGlassLantern"), origin, Vector3.new(3.85, 5.65, 0), Vector3.new(1.75, 1.75, 1.75), lanternGlass, Enum.Material.Glass, 0.32, false)
		setPart(getOrCreatePart(model, "LanternTopFrame"), origin, Vector3.new(3.85, 6.62, 0), Vector3.new(2.05, 0.22, 2.05), metal, Enum.Material.Metal, 0, false)
		setPart(getOrCreatePart(model, "LanternBottomFrame"), origin, Vector3.new(3.85, 4.68, 0), Vector3.new(2.05, 0.22, 2.05), metal, Enum.Material.Metal, 0, false)

		if lantern then
			local pointLight = lantern:FindFirstChild("WarmBeachPathLight")
			if not pointLight then
				pointLight = Instance.new("PointLight")
				pointLight.Name = "WarmBeachPathLight"
				pointLight.Parent = lantern
			end
			for _, light in ipairs(lantern:GetChildren()) do
				if light:IsA("PointLight") then
					light.Brightness = lampBrightness
					light.Range = lampRange
					light.Color = glow
					light.Shadows = false
				end
			end
		end

		model.PrimaryPart = base
	end

	for index, spec in ipairs(lightSpecs) do
		makePathLight(spec, index)
	end

	print(("Limestone lobby path lights patch: placed %d beach light posts along the brick path."):format(#lightSpecs))
end

local function applyFountainBrickPlaza()
	local brickColors = {
		Color3.fromRGB(150, 78, 58),
		Color3.fromRGB(172, 88, 64),
		Color3.fromRGB(122, 61, 49),
	}

	local changed = 0

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "FountainPlazaTile" then
			local colorIndex = (math.floor(descendant.Position.X / 4) + (math.floor(descendant.Position.Z / 4) * 2)) % #brickColors
			descendant.Material = Enum.Material.Brick
			descendant.Color = brickColors[colorIndex + 1]
			descendant.TopSurface = Enum.SurfaceType.Smooth
			descendant.BottomSurface = Enum.SurfaceType.Smooth
			changed += 1
		end
	end

	print(("Fountain brick plaza patch: updated %d saved editor tiles."):format(changed))
end

local function getLobbyRoot(instance)
	local current = instance
	while current and current ~= Workspace do
		if current:IsA("Model") and current.Name == "LobbyArea" then
			return current
		end
		current = current.Parent
	end

	return Workspace
end

local function applyFountainWarpTrigger()
	local fountainParts = {}
	local root = nil
	local topPart = nil

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local lowerName = string.lower(descendant.Name)
			if string.find(lowerName, "fountain")
				and not string.find(lowerName, "plaza")
				and not string.find(lowerName, "path")
				and not string.find(lowerName, "trigger")
				and not string.find(lowerName, "effect")
			then
				descendant.CanTouch = true
				table.insert(fountainParts, descendant)
				root = root or getLobbyRoot(descendant)
				if string.find(lowerName, "topwater") then
					topPart = descendant
				elseif not topPart or descendant.Position.Y > topPart.Position.Y then
					topPart = descendant
				end
			end
		end
	end

	if #fountainParts == 0 then
		warn("Fountain warp patch: could not find fountain water parts.")
		return
	end

	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, part in ipairs(fountainParts) do
		local halfSize = part.Size / 2
		minX = math.min(minX, part.Position.X - halfSize.X)
		minY = math.min(minY, part.Position.Y - halfSize.Y)
		minZ = math.min(minZ, part.Position.Z - halfSize.Z)
		maxX = math.max(maxX, part.Position.X + halfSize.X)
		maxY = math.max(maxY, part.Position.Y + halfSize.Y)
		maxZ = math.max(maxZ, part.Position.Z + halfSize.Z)
	end

	local trigger = root:FindFirstChild("FountainBiomeWarpTrigger", true)
	if trigger then
		trigger:Destroy()
	end

	for _, part in ipairs(fountainParts) do
		local lowerName = string.lower(part.Name)
		if string.find(lowerName, "water") then
			part.CanTouch = true
			part:SetAttribute("TargetArea", "BiomeWarp")
			part:SetAttribute("PortalName", "Biome Warp")
			part:SetAttribute("RequiredLevel", 1)
		end
	end

	local effects = root:FindFirstChild("AnimatedFountainEffects")
	if effects then
		effects:Destroy()
	end
	effects = Instance.new("Folder")
	effects.Name = "AnimatedFountainEffects"
	effects.Parent = root

	if topPart then
		local basinY = minY + 1.6
		local sheetDrop = math.max(4, topPart.Position.Y - basinY)
		local sheetCenterY = (topPart.Position.Y + basinY) / 2

		local function makeWaterSheet(name, size, position)
			local sheet = Instance.new("Part")
			sheet.Name = name
			sheet.Size = size
			sheet.Position = position
			sheet.Anchored = true
			sheet.CanCollide = false
			sheet.CanTouch = false
			sheet.CanQuery = false
			sheet.Material = Enum.Material.Glass
			sheet.Color = Color3.fromRGB(90, 205, 255)
			sheet.Transparency = 0.38
			sheet.TopSurface = Enum.SurfaceType.Smooth
			sheet.BottomSurface = Enum.SurfaceType.Smooth
			sheet.Parent = effects
		end

		makeWaterSheet("FallingWaterSheet_North", Vector3.new(topPart.Size.X + 2.4, sheetDrop, 0.28), Vector3.new(topPart.Position.X, sheetCenterY, topPart.Position.Z - (topPart.Size.Z / 2) - 0.25))
		makeWaterSheet("FallingWaterSheet_South", Vector3.new(topPart.Size.X + 2.4, sheetDrop, 0.28), Vector3.new(topPart.Position.X, sheetCenterY, topPart.Position.Z + (topPart.Size.Z / 2) + 0.25))
		makeWaterSheet("FallingWaterSheet_West", Vector3.new(0.28, sheetDrop, topPart.Size.Z + 2.4), Vector3.new(topPart.Position.X - (topPart.Size.X / 2) - 0.25, sheetCenterY, topPart.Position.Z))
		makeWaterSheet("FallingWaterSheet_East", Vector3.new(0.28, sheetDrop, topPart.Size.Z + 2.4), Vector3.new(topPart.Position.X + (topPart.Size.X / 2) + 0.25, sheetCenterY, topPart.Position.Z))
	end

	print("Fountain warp patch: connected the saved fountain water and removed the oversized trigger.")
end

local function applyShopWoodSpacing()
	local roofDeckNames = {
		RooftopDeck = true,
		RoofDeck = true,
	}

	local adjusted = 0
	for _, shop in ipairs(Workspace:GetDescendants()) do
		if shop:IsA("Model") and (shop.Name == "SeasideLShop" or shop.Name == "SeasideRodShop") then
			for _, descendant in ipairs(shop:GetDescendants()) do
				if descendant:IsA("BasePart") then
					if roofDeckNames[descendant.Name] and descendant.Position.Y > 23.05 then
						descendant.Position = Vector3.new(descendant.Position.X, 22.95, descendant.Position.Z)
						adjusted += 1
					end
				end
			end
		end
	end

	print(("Shop wood spacing patch: adjusted %d wood parts."):format(adjusted))
end

local function applySeasideRodShopMirror()
	local shop = nil

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "SeasideRodShop" and not isInsideFishyFishWorld(descendant) then
			shop = descendant
			break
		end
	end

	if not shop then
		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if descendant:IsA("Model") and descendant.Name == "SeasideRodShop" then
				shop = descendant
				break
			end
		end
	end

	if not shop then
		warn("Rod shop mirror patch: could not find SeasideRodShop.")
		return
	end

	if shop:GetAttribute("FishyFishMirroredRodShop") then
		print("Rod shop mirror patch: SeasideRodShop is already mirrored.")
		return
	end

	local primary = shop.PrimaryPart or shop:FindFirstChild("ShopPrimaryPart", true)
	local pivot = nil
	if primary and primary:IsA("BasePart") then
		pivot = primary.CFrame
	else
		local success, result = pcall(function()
			return shop:GetPivot()
		end)
		if not success then
			warn("Rod shop mirror patch: could not calculate SeasideRodShop position.")
			return
		end
		pivot = result
	end

	local mirrored = 0
	for _, descendant in ipairs(shop:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local localCFrame = pivot:ToObjectSpace(descendant.CFrame)
			local localPosition = localCFrame.Position
			local localRotation = localCFrame - localPosition
			descendant.CFrame = pivot * CFrame.new(-localPosition.X, localPosition.Y, localPosition.Z) * localRotation
			mirrored += 1
		end
	end

	shop:SetAttribute("FishyFishMirroredRodShop", true)
	print(("Rod shop mirror patch: mirrored %d saved rod shop parts."):format(mirrored))
end

local function applySeasideShopFishmonger()
	local shop = nil

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "SeasideLShop" and not isInsideFishyFishWorld(descendant) then
			shop = descendant
			break
		end
	end

	if not shop then
		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if descendant:IsA("Model") and descendant.Name == "SeasideLShop" then
				shop = descendant
				break
			end
		end
	end

	if not shop then
		warn("Seaside shop patch: could not find SeasideLShop.")
		return
	end

	local primary = shop.PrimaryPart or shop:FindFirstChild("ShopPrimaryPart", true)
	local baseCFrame = nil
	if primary and primary:IsA("BasePart") then
		baseCFrame = primary.CFrame * CFrame.new(0, -4, 0)
	else
		local success, pivot = pcall(function()
			return shop:GetPivot()
		end)
		if not success then
			warn("Seaside shop patch: could not calculate SeasideLShop position.")
			return
		end
		baseCFrame = pivot * CFrame.new(0, -4, 0)
	end

	local existing = shop:FindFirstChild("FishmongerNPC")
	if existing then
		existing:Destroy()
	end

	local npc = Instance.new("Model")
	npc.Name = "FishmongerNPC"
	npc.Parent = shop

	local folder = Instance.new("Folder")
	folder.Name = "EditableParts"
	folder.Parent = npc

	local function makePart(name, size, localPosition, color, material, transparency, canCollide)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = baseCFrame * CFrame.new(localPosition)
		part.Anchored = true
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Transparency = transparency or 0
		part.CanCollide = canCollide == true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = folder
		return part
	end

	local apronBlue = Color3.fromRGB(45, 105, 150)
	local shirtWhite = Color3.fromRGB(235, 238, 232)
	local skin = Color3.fromRGB(226, 178, 132)
	local pants = Color3.fromRGB(42, 62, 82)
	local capRed = Color3.fromRGB(190, 45, 38)
	local bootDark = Color3.fromRGB(35, 28, 22)
	local wood = Color3.fromRGB(135, 85, 45)
	local bottleBlue = Color3.fromRGB(50, 125, 210)
	local npcBase = Vector3.new(0, 0, -3.4)

	local body = makePart("FishmongerBody", Vector3.new(3.2, 4.2, 1.6), npcBase + Vector3.new(0, 10.8, 0), apronBlue)
	makePart("FishmongerShirt", Vector3.new(3.45, 1.2, 1.7), npcBase + Vector3.new(0, 12.25, -0.05), shirtWhite)
	makePart("FishmongerHead", Vector3.new(2.4, 2.4, 2.4), npcBase + Vector3.new(0, 14.3, 0), skin)
	makePart("FishmongerCap", Vector3.new(2.7, 0.7, 2.7), npcBase + Vector3.new(0, 15.75, 0), capRed)
	makePart("FishmongerCapBill", Vector3.new(2.1, 0.3, 1.2), npcBase + Vector3.new(0, 15.45, -1.1), capRed)
	makePart("FishmongerLeftArm", Vector3.new(0.9, 3.4, 0.9), npcBase + Vector3.new(-2.2, 10.8, 0), skin)
	makePart("FishmongerRightArm", Vector3.new(0.9, 3.4, 0.9), npcBase + Vector3.new(2.2, 10.8, 0), skin)
	makePart("FishmongerLeftLeg", Vector3.new(1.1, 2.6, 1), npcBase + Vector3.new(-0.9, 7.4, 0), pants)
	makePart("FishmongerRightLeg", Vector3.new(1.1, 2.6, 1), npcBase + Vector3.new(0.9, 7.4, 0), pants)
	makePart("FishmongerLeftBoot", Vector3.new(1.2, 0.6, 1.2), npcBase + Vector3.new(-0.9, 5.9, -0.1), bootDark)
	makePart("FishmongerRightBoot", Vector3.new(1.2, 0.6, 1.2), npcBase + Vector3.new(0.9, 5.9, -0.1), bootDark)
	makePart("FishmongerLeftEye", Vector3.new(0.3, 0.3, 0.12), npcBase + Vector3.new(-0.45, 14.55, -1.22), Color3.fromRGB(20, 20, 20))
	makePart("FishmongerRightEye", Vector3.new(0.3, 0.3, 0.12), npcBase + Vector3.new(0.45, 14.55, -1.22), Color3.fromRGB(20, 20, 20))
	makePart("FishmongerFishCrate", Vector3.new(5, 2, 3), npcBase + Vector3.new(-5.2, 6.2, 0.6), wood, Enum.Material.WoodPlanks, 0, true)
	makePart("CrateFishBlue", Vector3.new(2.8, 0.7, 0.9), npcBase + Vector3.new(-5.3, 7.55, 0.35), bottleBlue)
	makePart("CrateFishTail", Vector3.new(0.8, 1.2, 0.8), npcBase + Vector3.new(-6.1, 7.55, 0.35), bottleBlue)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellFishPrompt"
	prompt.ActionText = "Choose Fish"
	prompt.ObjectText = "Fishmonger"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	npc.PrimaryPart = body
	print("Seaside shop patch: placed FishmongerNPC behind the counter in " .. shop:GetFullName() .. ".")
end

local function applySeasideRodShopKeeper()
	local shop = findSavedModel("SeasideRodShop")
	if not shop then
		warn("Rod shop patch: could not find SeasideRodShop.")
		return
	end

	local baseCFrame = getModelBaseCFrame(shop, "Rod shop patch")
	if not baseCFrame then
		return
	end

	local existing = shop:FindFirstChild("RodShopKeeperNPC")
	if existing then
		existing:Destroy()
	end

	local npc = Instance.new("Model")
	npc.Name = "RodShopKeeperNPC"
	npc.Parent = shop

	local folder = Instance.new("Folder")
	folder.Name = "EditableParts"
	folder.Parent = npc

	local function makePart(name, size, localPosition, color, material, transparency, canCollide)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = baseCFrame * CFrame.new(localPosition)
		part.Anchored = true
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Transparency = transparency or 0
		part.CanCollide = canCollide == true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = folder
		return part
	end

	local vestBlue = Color3.fromRGB(44, 92, 170)
	local shirtCream = Color3.fromRGB(236, 230, 205)
	local skin = Color3.fromRGB(224, 176, 126)
	local pants = Color3.fromRGB(45, 59, 78)
	local capBlue = Color3.fromRGB(32, 78, 150)
	local bootDark = Color3.fromRGB(35, 30, 26)
	local wood = Color3.fromRGB(135, 85, 45)
	local reelMetal = Color3.fromRGB(48, 52, 60)
	local lineWhite = Color3.fromRGB(235, 240, 242)
	local npcBase = Vector3.new(0, 0, -3.4)

	local body = makePart("RodSellerBody", Vector3.new(3.2, 4.2, 1.6), npcBase + Vector3.new(0, 10.8, 0), vestBlue)
	makePart("RodSellerShirt", Vector3.new(3.45, 1.2, 1.7), npcBase + Vector3.new(0, 12.25, -0.05), shirtCream)
	makePart("RodSellerHead", Vector3.new(2.4, 2.4, 2.4), npcBase + Vector3.new(0, 14.3, 0), skin)
	makePart("RodSellerCap", Vector3.new(2.7, 0.7, 2.7), npcBase + Vector3.new(0, 15.75, 0), capBlue)
	makePart("RodSellerCapBill", Vector3.new(2.1, 0.3, 1.2), npcBase + Vector3.new(0, 15.45, -1.1), capBlue)
	makePart("RodSellerLeftArm", Vector3.new(0.9, 3.4, 0.9), npcBase + Vector3.new(-2.2, 10.8, 0), skin)
	makePart("RodSellerRightArm", Vector3.new(0.9, 3.4, 0.9), npcBase + Vector3.new(2.2, 10.8, 0), skin)
	makePart("RodSellerLeftLeg", Vector3.new(1.1, 2.6, 1), npcBase + Vector3.new(-0.9, 7.4, 0), pants)
	makePart("RodSellerRightLeg", Vector3.new(1.1, 2.6, 1), npcBase + Vector3.new(0.9, 7.4, 0), pants)
	makePart("RodSellerLeftBoot", Vector3.new(1.2, 0.6, 1.2), npcBase + Vector3.new(-0.9, 5.9, -0.1), bootDark)
	makePart("RodSellerRightBoot", Vector3.new(1.2, 0.6, 1.2), npcBase + Vector3.new(0.9, 5.9, -0.1), bootDark)
	makePart("RodSellerLeftEye", Vector3.new(0.3, 0.3, 0.12), npcBase + Vector3.new(-0.45, 14.55, -1.22), Color3.fromRGB(20, 20, 20))
	makePart("RodSellerRightEye", Vector3.new(0.3, 0.3, 0.12), npcBase + Vector3.new(0.45, 14.55, -1.22), Color3.fromRGB(20, 20, 20))
	makePart("DisplayRodPole", Vector3.new(0.28, 9, 0.28), npcBase + Vector3.new(4.2, 11.2, -0.1), wood, Enum.Material.Wood, 0, false)
	makePart("DisplayRodHandle", Vector3.new(0.55, 2.2, 0.55), npcBase + Vector3.new(4.2, 7.4, -0.1), wood, Enum.Material.Wood, 0, false)
	makePart("DisplayRodReel", Vector3.new(1.1, 0.45, 1.1), npcBase + Vector3.new(3.65, 8.6, -0.1), reelMetal, Enum.Material.Metal, 0, false)
	makePart("DisplayRodLine", Vector3.new(0.06, 4.2, 0.06), npcBase + Vector3.new(4.65, 12.7, -0.1), lineWhite, Enum.Material.SmoothPlastic, 0, false)
	makePart("RodSellerCrate", Vector3.new(4.8, 1.8, 2.6), npcBase + Vector3.new(-5.2, 6.15, 0.55), wood, Enum.Material.WoodPlanks, 0, true)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyRodPrompt"
	prompt.ActionText = "Browse Supplies"
	prompt.ObjectText = "Supply Seller"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	npc.PrimaryPart = body
	print("Rod shop patch: placed RodShopKeeperNPC behind the counter in " .. shop:GetFullName() .. ".")
end

local function applySupplyShopAndLeaderboardLabels()
	local shop = findSavedModel("SeasideRodShop")
	if shop then
		for _, descendant in ipairs(shop:GetDescendants()) do
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
				if descendant.Text == "ROD SHOP" or descendant.Text == "Rod & Bait Shop" then
					descendant.Text = "SUPPLY SHOP"
				elseif descendant.Text == "RODS\nBAIT\nTACKLE" then
					descendant.Text = "RODS\nBAIT\nSUPPLIES"
				end
			elseif descendant:IsA("ProximityPrompt") and descendant.Name == "BuyRodPrompt" then
				descendant.ActionText = "Browse Supplies"
				descendant.ObjectText = "Supply Seller"
			elseif descendant:IsA("BasePart") and descendant:GetAttribute("InteractText") == "Open Rod Shop" then
				descendant:SetAttribute("InteractText", "Open Supply Shop")
			end
		end
	end

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("TextLabel") and (descendant.Text:match("^Leaderboard") or descendant.Text:match("^TOP FISH CAUGHT")) then
			local rows = descendant.Text:match("\n.*") or ""
			descendant.Text = "Leaderboard - Most Fish Caught" .. rows
		end
	end

	print("Shop label patch: renamed rod shop visuals to Supply Shop and updated leaderboard title.")
end

local function applyCastleShop()
	local serviceScript = game:GetService("ServerScriptService"):FindFirstChild("CastleShopService")
	if not serviceScript then
		warn("Castle shop patch: CastleShopService is not synced into ServerScriptService yet.")
		return
	end

	local success, service = pcall(require, serviceScript)
	if not success or type(service) ~= "table" or type(service.build) ~= "function" then
		warn("Castle shop patch: could not load CastleShopService.")
		return
	end

	service.build()
	print("Castle shop patch: built CastleShop.")
end

local function applySeasideShopDisplayAquarium()
	local shop = findSavedModel("SeasideLShop")
	if not shop then
		warn("Display aquarium patch: could not find SeasideLShop.")
		return
	end

	local baseCFrame = getModelBaseCFrame(shop, "Display aquarium patch")
	if not baseCFrame then
		return
	end

	local rootPreview = Workspace:FindFirstChild("DisplayAquariumTank")
	if rootPreview and rootPreview.Parent ~= shop then
		rootPreview:Destroy()
	end

	local existing = shop:FindFirstChild("DisplayAquariumTank")
	if existing then
		existing:Destroy()
	end

	local aquarium = Instance.new("Model")
	aquarium.Name = "DisplayAquariumTank"
	aquarium:SetAttribute("DisplayOnly", true)
	aquarium:SetAttribute("PlayerLinked", false)
	aquarium.Parent = shop

	local tankFolder = Instance.new("Folder")
	tankFolder.Name = "TankParts"
	tankFolder.Parent = aquarium

	local fishFolder = Instance.new("Folder")
	fishFolder.Name = "DisplayFish"
	fishFolder.Parent = aquarium

	local originOffset = Vector3.new(-19, 3, 4)
	local dimensions = {
		tankWidth = 14,
		tankHeight = 7,
		tankDepth = 7,
		baseWidth = 18,
		baseDepth = 10,
		glassY = 4.5,
		waterY = 6.46,
		topY = 8.3,
	}
	local halfWidth = dimensions.tankWidth / 2
	local halfDepth = dimensions.tankDepth / 2

	local function tankPart(parent, name, size, offset, color, material, transparency, canCollide)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = baseCFrame * CFrame.new(originOffset + offset)
		part.Anchored = true
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Transparency = transparency or 0
		part.CanCollide = canCollide == true
		part.CanTouch = false
		part.CanQuery = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parent
		return part
	end

	local base = tankPart(tankFolder, "AquariumDisplayBase", Vector3.new(dimensions.baseWidth, 1, dimensions.baseDepth), Vector3.new(0, 0.8, 0), Color3.fromRGB(72, 82, 88), Enum.Material.Metal, 0, true)
	tankPart(tankFolder, "AquariumDisplayBaseTop", Vector3.new(dimensions.baseWidth - 1.2, 0.18, dimensions.baseDepth - 1.2), Vector3.new(0, 1.39, 0), Color3.fromRGB(132, 142, 150), Enum.Material.Metal)

	for _, glassPanel in ipairs({
		{ name = "DisplayGlassFront", size = Vector3.new(dimensions.tankWidth, dimensions.tankHeight, 0.22), offset = Vector3.new(0, dimensions.glassY, -halfDepth - 0.14) },
		{ name = "DisplayGlassBack", size = Vector3.new(dimensions.tankWidth, dimensions.tankHeight, 0.22), offset = Vector3.new(0, dimensions.glassY, halfDepth + 0.14) },
		{ name = "DisplayGlassLeft", size = Vector3.new(0.22, dimensions.tankHeight, dimensions.tankDepth), offset = Vector3.new(-halfWidth - 0.14, dimensions.glassY, 0) },
		{ name = "DisplayGlassRight", size = Vector3.new(0.22, dimensions.tankHeight, dimensions.tankDepth), offset = Vector3.new(halfWidth + 0.14, dimensions.glassY, 0) },
	}) do
		tankPart(tankFolder, glassPanel.name, glassPanel.size, glassPanel.offset, Color3.fromRGB(75, 165, 220), Enum.Material.Glass, 0.68)
	end

	tankPart(tankFolder, "DisplayWaterSurface", Vector3.new(dimensions.tankWidth - 1.4, 0.18, dimensions.tankDepth - 1.4), Vector3.new(0, dimensions.waterY, 0), Color3.fromRGB(50, 145, 220), Enum.Material.Glass, 0.48)

	for _, corner in ipairs({
		Vector3.new(-halfWidth, dimensions.glassY, -halfDepth),
		Vector3.new(halfWidth, dimensions.glassY, -halfDepth),
		Vector3.new(-halfWidth, dimensions.glassY, halfDepth),
		Vector3.new(halfWidth, dimensions.glassY, halfDepth),
	}) do
		tankPart(tankFolder, "DisplayAquariumFramePost", Vector3.new(0.38, dimensions.tankHeight + 0.4, 0.38), corner, Color3.fromRGB(38, 52, 68), Enum.Material.Metal)
	end

	local function makeFrameRails(prefix, y)
		tankPart(tankFolder, prefix .. "Front", Vector3.new(dimensions.tankWidth + 0.8, 0.38, 0.38), Vector3.new(0, y, -halfDepth - 0.22), Color3.fromRGB(38, 52, 68), Enum.Material.Metal)
		tankPart(tankFolder, prefix .. "Back", Vector3.new(dimensions.tankWidth + 0.8, 0.38, 0.38), Vector3.new(0, y, halfDepth + 0.22), Color3.fromRGB(38, 52, 68), Enum.Material.Metal)
		tankPart(tankFolder, prefix .. "Left", Vector3.new(0.38, 0.38, dimensions.tankDepth + 0.8), Vector3.new(-halfWidth - 0.22, y, 0), Color3.fromRGB(38, 52, 68), Enum.Material.Metal)
		tankPart(tankFolder, prefix .. "Right", Vector3.new(0.38, 0.38, dimensions.tankDepth + 0.8), Vector3.new(halfWidth + 0.22, y, 0), Color3.fromRGB(38, 52, 68), Enum.Material.Metal)
	end

	makeFrameRails("DisplayTopFrame", dimensions.topY)
	makeFrameRails("DisplayBottomFrame", 1.05)

	local lightPart = tankPart(tankFolder, "DisplayTankGlow", Vector3.new(1, 1, 1), Vector3.new(0, dimensions.topY + 0.2, 0), Color3.fromRGB(85, 210, 255), Enum.Material.Neon, 1)
	local light = Instance.new("PointLight")
	light.Brightness = 0.18
	light.Range = 9
	light.Color = Color3.fromRGB(115, 220, 255)
	light.Parent = lightPart

	local function fishPart(parentModel, rootCFrame, name, size, localPosition, color, material, localRotation, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = rootCFrame * CFrame.new(localPosition) * CFrame.Angles(
			math.rad(localRotation and localRotation.X or 0),
			math.rad(localRotation and localRotation.Y or 0),
			math.rad(localRotation and localRotation.Z or 0)
		)
		part.Anchored = true
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			part.Shape = shape
		end
		part.Parent = parentModel
		return part
	end

	local function makeDisplayFish(fish)
		local model = Instance.new("Model")
		model.Name = "DisplayFish_" .. fish.name
		model.Parent = fishFolder

		local rootCFrame = baseCFrame * CFrame.new(originOffset + fish.offset) * CFrame.Angles(0, math.rad(fish.yaw or 0), 0)
		local root = fishPart(model, rootCFrame, "FishRoot", Vector3.new(0.2, 0.2, 0.2), Vector3.new(), fish.body, Enum.Material.ForceField)
		root.Transparency = 1

		local scale = fish.scale or 1
		local function scaled(x, y, z)
			return Vector3.new(x * scale, y * scale, z * scale)
		end

		local body = fishPart(model, rootCFrame, "RoundedBody", scaled(1.55, 0.58, 0.46), Vector3.new(0, 0, 0), fish.body, fish.material, nil, Enum.PartType.Ball)
		fishPart(model, rootCFrame, "Head", scaled(0.5, 0.48, 0.42), Vector3.new(0.74 * scale, 0.02 * scale, 0), fish.head or fish.body, fish.material, nil, Enum.PartType.Ball)
		fishPart(model, rootCFrame, "Belly", scaled(1.1, 0.16, 0.34), Vector3.new(-0.08 * scale, -0.27 * scale, 0), fish.belly, Enum.Material.SmoothPlastic)
		fishPart(model, rootCFrame, "BackStripe", scaled(1.1, 0.12, 0.2), Vector3.new(-0.04 * scale, 0.29 * scale, 0), fish.back or fish.body, fish.material)
		fishPart(model, rootCFrame, "TailTop", scaled(0.46, 0.22, 0.16), Vector3.new(-0.95 * scale, 0.18 * scale, 0), fish.tail, fish.material, Vector3.new(0, 0, 22))
		fishPart(model, rootCFrame, "TailBottom", scaled(0.46, 0.22, 0.16), Vector3.new(-0.95 * scale, -0.18 * scale, 0), fish.tail, fish.material, Vector3.new(0, 0, -22))
		fishPart(model, rootCFrame, "TailCenter", scaled(0.36, 0.22, 0.16), Vector3.new(-0.82 * scale, 0, 0), fish.tailDark or fish.tail, fish.material)
		fishPart(model, rootCFrame, "LeftFin", scaled(0.12, 0.24, 0.34), Vector3.new(0.12 * scale, -0.1 * scale, -0.31 * scale), fish.fin or fish.tail, fish.material, Vector3.new(0, -18, -18))
		fishPart(model, rootCFrame, "RightFin", scaled(0.12, 0.24, 0.34), Vector3.new(0.12 * scale, -0.1 * scale, 0.31 * scale), fish.fin or fish.tail, fish.material, Vector3.new(0, 18, 18))
		fishPart(model, rootCFrame, "LeftEye", scaled(0.08, 0.08, 0.06), Vector3.new(0.98 * scale, 0.11 * scale, -0.19 * scale), Color3.fromRGB(12, 12, 12), Enum.Material.SmoothPlastic, nil, Enum.PartType.Ball)
		fishPart(model, rootCFrame, "RightEye", scaled(0.08, 0.08, 0.06), Vector3.new(0.98 * scale, 0.11 * scale, 0.19 * scale), Color3.fromRGB(12, 12, 12), Enum.Material.SmoothPlastic, nil, Enum.PartType.Ball)

		if fish.stripes then
			for index, x in ipairs({ -0.38, -0.08, 0.22 }) do
				fishPart(model, rootCFrame, "BodyStripe_" .. index, scaled(0.08, 0.48, 0.48), Vector3.new(x * scale, 0.03 * scale, 0), fish.stripes, Enum.Material.SmoothPlastic)
			end
		end

		if fish.patches then
			for index, patch in ipairs(fish.patches) do
				fishPart(model, rootCFrame, "ColorPatch_" .. index, scaled(patch.size.X, patch.size.Y, patch.size.Z), patch.offset * scale, patch.color, patch.material or Enum.Material.SmoothPlastic, patch.rotation)
			end
		end

		if fish.glow then
			local light = Instance.new("PointLight")
			light.Brightness = 0.45
			light.Range = 5
			light.Color = fish.glow
			light.Parent = body
		end

		model.PrimaryPart = root
	end

	for _, fish in ipairs({
		{
			name = "SmallFish",
			offset = Vector3.new(-3.6, 4.4, -1.2),
			yaw = -8,
			scale = 0.95,
			body = Color3.fromRGB(72, 145, 230),
			head = Color3.fromRGB(95, 170, 245),
			belly = Color3.fromRGB(170, 220, 245),
			back = Color3.fromRGB(42, 96, 170),
			tail = Color3.fromRGB(58, 120, 210),
			tailDark = Color3.fromRGB(34, 80, 150),
			fin = Color3.fromRGB(90, 160, 235),
		},
		{
			name = "Bluegill",
			offset = Vector3.new(2, 5.1, 1),
			yaw = 18,
			scale = 1,
			body = Color3.fromRGB(218, 152, 68),
			head = Color3.fromRGB(83, 109, 119),
			belly = Color3.fromRGB(229, 204, 144),
			back = Color3.fromRGB(56, 75, 84),
			tail = Color3.fromRGB(83, 109, 119),
			tailDark = Color3.fromRGB(56, 75, 84),
			fin = Color3.fromRGB(120, 145, 120),
			stripes = Color3.fromRGB(58, 93, 103),
		},
		{
			name = "Koi",
			offset = Vector3.new(-1.2, 5.65, 2.1),
			yaw = -24,
			scale = 1.04,
			body = Color3.fromRGB(245, 242, 232),
			head = Color3.fromRGB(238, 82, 26),
			belly = Color3.fromRGB(255, 250, 242),
			back = Color3.fromRGB(238, 82, 26),
			tail = Color3.fromRGB(246, 244, 236),
			tailDark = Color3.fromRGB(239, 77, 28),
			fin = Color3.fromRGB(247, 244, 236),
			patches = {
				{ offset = Vector3.new(-0.15, 0.18, -0.18), size = Vector3.new(0.42, 0.1, 0.18), color = Color3.fromRGB(60, 62, 64) },
				{ offset = Vector3.new(0.26, 0.06, 0.18), size = Vector3.new(0.36, 0.12, 0.18), color = Color3.fromRGB(255, 96, 48) },
			},
		},
		{
			name = "GoldenCarp",
			offset = Vector3.new(4.2, 3.9, -1.6),
			yaw = 32,
			scale = 1.08,
			body = Color3.fromRGB(255, 184, 0),
			head = Color3.fromRGB(236, 169, 0),
			belly = Color3.fromRGB(255, 226, 58),
			back = Color3.fromRGB(223, 137, 0),
			tail = Color3.fromRGB(237, 145, 0),
			tailDark = Color3.fromRGB(201, 103, 0),
			fin = Color3.fromRGB(238, 130, 0),
			material = Enum.Material.SmoothPlastic,
			glow = Color3.fromRGB(255, 220, 55),
			patches = {
				{ offset = Vector3.new(-0.08, 0.09, 0), size = Vector3.new(0.18, 0.12, 0.5), color = Color3.fromRGB(255, 240, 54), material = Enum.Material.Neon },
			},
		},
	}) do
		makeDisplayFish(fish)
	end

	aquarium.PrimaryPart = base
	print("Display aquarium patch: placed DisplayAquariumTank inside " .. shop:GetFullName() .. ".")
end

local function applyLimestoneLobbySmallBeachDecor()
	local lobby = findSavedLobbyArea()
	local parent = lobby or Workspace

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant.Name == "LimestoneLobbySmallBeachDecor" then
			descendant:Destroy()
		end
	end

	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "LimestoneLobbySmallBeachDecor"
	decorFolder.Parent = parent

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { decorFolder }

	local function groundY(x, z)
		local result = Workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -220, 0), raycastParams)
		if result then
			return result.Position.Y
		end

		return 2.5
	end

	local function makePart(parentModel, name, size, origin, localPosition, color, material, transparency, canCollide, localRotation)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = origin * CFrame.new(localPosition) * CFrame.Angles(
			math.rad(localRotation and localRotation.X or 0),
			math.rad(localRotation and localRotation.Y or 0),
			math.rad(localRotation and localRotation.Z or 0)
		)
		part.Anchored = true
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Transparency = transparency or 0
		part.CanCollide = canCollide == true
		part.CanTouch = false
		part.CanQuery = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parentModel
		return part
	end

	local function makeFolder(parentModel, name)
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parentModel
		return folder
	end

	local function makeModel(name, position, yawDegrees)
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = decorFolder

		local origin = CFrame.new(position) * CFrame.Angles(0, math.rad(yawDegrees or 0), 0)
		return model, origin
	end

	local white = Color3.fromRGB(245, 245, 235)
	local blue = Color3.fromRGB(40, 130, 230)
	local yellow = Color3.fromRGB(245, 210, 65)
	local darkLine = Color3.fromRGB(40, 40, 45)
	local sandColor = Color3.fromRGB(221, 196, 135)
	local sandShadow = Color3.fromRGB(188, 158, 95)

	local volleyballPosition = Vector3.new(-182, groundY(-182, -540), -540)
	local volleyball, volleyballOrigin = makeModel("SmallBeachVolleyball", volleyballPosition, -18)
	local ballFolder = makeFolder(volleyball, "Ball")
	local panelFolder = makeFolder(volleyball, "RoundedColorPanels")
	local primaryFolder = makeFolder(volleyball, "PrimaryPartFolder")

	local ball = makePart(ballFolder, "BallBody", Vector3.new(1.8, 1.8, 1.8), volleyballOrigin, Vector3.new(0, 1.1, 0), white, Enum.Material.SmoothPlastic, 0, false)
	ball.Shape = Enum.PartType.Ball

	for _, panel in ipairs({
		{ name = "BluePanelFrontLeft", size = Vector3.new(0.62, 0.62, 0.12), offset = Vector3.new(-0.38, 1.35, -0.9), color = blue, rotation = Vector3.new(0, 0, -18) },
		{ name = "YellowPanelFrontRight", size = Vector3.new(0.62, 0.62, 0.12), offset = Vector3.new(0.38, 0.87, -0.9), color = yellow, rotation = Vector3.new(0, 0, 18) },
		{ name = "BluePanelLeft", size = Vector3.new(0.12, 0.58, 0.58), offset = Vector3.new(-0.9, 0.95, 0.28), color = blue, rotation = Vector3.new(0, 20, 0) },
		{ name = "YellowPanelRight", size = Vector3.new(0.12, 0.58, 0.58), offset = Vector3.new(0.9, 1.3, -0.25), color = yellow, rotation = Vector3.new(0, -20, 0) },
	}) do
		local colorPanel = makePart(panelFolder, panel.name, panel.size, volleyballOrigin, panel.offset, panel.color, Enum.Material.SmoothPlastic, 0, false, panel.rotation)
		colorPanel.Shape = Enum.PartType.Ball
	end

	local frontSeam = makePart(panelFolder, "SoftFrontSeam", Vector3.new(0.12, 0.12, 0.08), volleyballOrigin, Vector3.new(0, 1.1, -0.94), darkLine, Enum.Material.SmoothPlastic, 0, false)
	frontSeam.Shape = Enum.PartType.Ball
	local sideSeam = makePart(panelFolder, "SoftSideSeam", Vector3.new(0.1, 0.1, 0.1), volleyballOrigin, Vector3.new(-0.94, 1.1, 0), darkLine, Enum.Material.SmoothPlastic, 0, false)
	sideSeam.Shape = Enum.PartType.Ball
	volleyball.PrimaryPart = makePart(primaryFolder, "PrimaryPart", Vector3.new(0.4, 0.4, 0.4), volleyballOrigin, Vector3.new(0, 1.1, 0), Color3.fromRGB(255, 0, 255), Enum.Material.ForceField, 1, false)

	local sandcastlePosition = Vector3.new(-208, groundY(-208, -548), -548)
	local sandcastle, sandcastleOrigin = makeModel("SmallSandcastle", sandcastlePosition, 8)
	local castleFolder = makeFolder(sandcastle, "Castle")
	primaryFolder = makeFolder(sandcastle, "PrimaryPartFolder")

	makePart(castleFolder, "CastleBase", Vector3.new(4.8, 0.75, 3.8), sandcastleOrigin, Vector3.new(0, 0.38, 0), sandShadow, Enum.Material.Sand, 0, false)
	makePart(castleFolder, "MainKeep", Vector3.new(2.1, 1.8, 1.8), sandcastleOrigin, Vector3.new(0, 1.35, 0), sandColor, Enum.Material.Sand, 0, false)
	makePart(castleFolder, "KeepTop", Vector3.new(2.35, 0.35, 2.05), sandcastleOrigin, Vector3.new(0, 2.42, 0), sandShadow, Enum.Material.Sand, 0, false)
	makePart(castleFolder, "LeftTower", Vector3.new(1.05, 2.1, 1.05), sandcastleOrigin, Vector3.new(-1.85, 1.45, -0.85), sandColor, Enum.Material.Sand, 0, false)
	makePart(castleFolder, "RightTower", Vector3.new(1.05, 2.1, 1.05), sandcastleOrigin, Vector3.new(1.85, 1.45, -0.85), sandColor, Enum.Material.Sand, 0, false)
	makePart(castleFolder, "BackTower", Vector3.new(1.0, 1.9, 1.0), sandcastleOrigin, Vector3.new(0, 1.3, 1.25), sandColor, Enum.Material.Sand, 0, false)
	makePart(castleFolder, "LeftTowerCap", Vector3.new(1.25, 0.3, 1.25), sandcastleOrigin, Vector3.new(-1.85, 2.65, -0.85), sandShadow, Enum.Material.Sand, 0, false)
	makePart(castleFolder, "RightTowerCap", Vector3.new(1.25, 0.3, 1.25), sandcastleOrigin, Vector3.new(1.85, 2.65, -0.85), sandShadow, Enum.Material.Sand, 0, false)
	makePart(castleFolder, "BackTowerCap", Vector3.new(1.18, 0.3, 1.18), sandcastleOrigin, Vector3.new(0, 2.38, 1.25), sandShadow, Enum.Material.Sand, 0, false)
	for notchIndex, notchX in ipairs({ -0.75, 0, 0.75 }) do
		makePart(castleFolder, "KeepCrenel" .. tostring(notchIndex), Vector3.new(0.38, 0.42, 0.38), sandcastleOrigin, Vector3.new(notchX, 2.78, -0.78), sandColor, Enum.Material.Sand, 0, false)
	end
	makePart(castleFolder, "Door", Vector3.new(0.62, 0.95, 0.18), sandcastleOrigin, Vector3.new(0, 0.95, -0.92), sandShadow, Enum.Material.Sand, 0, false)
	makePart(castleFolder, "FlagPole", Vector3.new(0.12, 1.05, 0.12), sandcastleOrigin, Vector3.new(0, 3.28, 0), Color3.fromRGB(95, 76, 52), Enum.Material.Wood, 0, false)
	makePart(castleFolder, "Flag", Vector3.new(0.85, 0.42, 0.08), sandcastleOrigin, Vector3.new(0.46, 3.48, 0), Color3.fromRGB(240, 70, 55), Enum.Material.SmoothPlastic, 0, false)
	sandcastle.PrimaryPart = makePart(primaryFolder, "PrimaryPart", Vector3.new(0.4, 0.4, 0.4), sandcastleOrigin, Vector3.new(0, 1.3, 0), Color3.fromRGB(255, 0, 255), Enum.Material.ForceField, 1, false)

	local bucketColor = Color3.fromRGB(240, 70, 55)
	local bucketDark = Color3.fromRGB(185, 45, 38)
	local rimColor = Color3.fromRGB(255, 220, 85)
	local handleColor = Color3.fromRGB(235, 235, 225)

	local bucketPosition = Vector3.new(-196, groundY(-196, -548), -548)
	local bucket, bucketOrigin = makeModel("SmallBeachBucket", bucketPosition, 12)
	local bucketFolder = makeFolder(bucket, "Bucket")
	local handleFolder = makeFolder(bucket, "Handle")
	primaryFolder = makeFolder(bucket, "PrimaryPartFolder")

	makePart(bucketFolder, "BucketBottom", Vector3.new(1.45, 0.45, 1.45), bucketOrigin, Vector3.new(0, 0.45, 0), bucketDark, Enum.Material.SmoothPlastic, 0, false)
	makePart(bucketFolder, "BucketMiddle", Vector3.new(1.75, 0.65, 1.75), bucketOrigin, Vector3.new(0, 0.95, 0), bucketColor, Enum.Material.SmoothPlastic, 0, false)
	makePart(bucketFolder, "BucketTop", Vector3.new(2.05, 0.55, 2.05), bucketOrigin, Vector3.new(0, 1.55, 0), bucketColor, Enum.Material.SmoothPlastic, 0, false)
	makePart(bucketFolder, "FrontRim", Vector3.new(2.25, 0.18, 0.2), bucketOrigin, Vector3.new(0, 1.9, -1.05), rimColor, Enum.Material.SmoothPlastic, 0, false)
	makePart(bucketFolder, "BackRim", Vector3.new(2.25, 0.18, 0.2), bucketOrigin, Vector3.new(0, 1.9, 1.05), rimColor, Enum.Material.SmoothPlastic, 0, false)
	makePart(bucketFolder, "LeftRim", Vector3.new(0.2, 0.18, 2.25), bucketOrigin, Vector3.new(-1.05, 1.9, 0), rimColor, Enum.Material.SmoothPlastic, 0, false)
	makePart(bucketFolder, "RightRim", Vector3.new(0.2, 0.18, 2.25), bucketOrigin, Vector3.new(1.05, 1.9, 0), rimColor, Enum.Material.SmoothPlastic, 0, false)
	makePart(bucketFolder, "SandInside", Vector3.new(1.45, 0.15, 1.45), bucketOrigin, Vector3.new(0, 1.95, 0), sandColor, Enum.Material.Sand, 0, false)
	makePart(handleFolder, "HandleLeftPost", Vector3.new(0.14, 0.95, 0.14), bucketOrigin, Vector3.new(-1.15, 2.2, 0), handleColor, Enum.Material.SmoothPlastic, 0, false)
	makePart(handleFolder, "HandleRightPost", Vector3.new(0.14, 0.95, 0.14), bucketOrigin, Vector3.new(1.15, 2.2, 0), handleColor, Enum.Material.SmoothPlastic, 0, false)
	makePart(handleFolder, "HandleTop", Vector3.new(2.3, 0.14, 0.14), bucketOrigin, Vector3.new(0, 2.75, 0), handleColor, Enum.Material.SmoothPlastic, 0, false)
	makePart(handleFolder, "LeftPeg", Vector3.new(0.25, 0.25, 0.25), bucketOrigin, Vector3.new(-1.15, 1.75, 0), rimColor, Enum.Material.SmoothPlastic, 0, false)
	makePart(handleFolder, "RightPeg", Vector3.new(0.25, 0.25, 0.25), bucketOrigin, Vector3.new(1.15, 1.75, 0), rimColor, Enum.Material.SmoothPlastic, 0, false)
	bucket.PrimaryPart = makePart(primaryFolder, "PrimaryPart", Vector3.new(0.4, 0.4, 0.4), bucketOrigin, Vector3.new(0, 1, 0), Color3.fromRGB(255, 0, 255), Enum.Material.ForceField, 1, false)

	local gripColor = Color3.fromRGB(235, 80, 65)
	local bladeColor = Color3.fromRGB(60, 150, 230)
	local bladeDark = Color3.fromRGB(35, 100, 180)
	local shovelPosition = Vector3.new(-186, groundY(-186, -553) + 0.14, -553)
	local shovel, shovelOrigin = makeModel("SmallBeachShovel", shovelPosition, -24)
	local shovelFolder = makeFolder(shovel, "Shovel")
	primaryFolder = makeFolder(shovel, "PrimaryPartFolder")

	local function shovelSegment(name, startLocal, endLocal, thickness, color, material)
		local startWorld = shovelOrigin:PointToWorldSpace(startLocal)
		local endWorld = shovelOrigin:PointToWorldSpace(endLocal)
		local middle = (startWorld + endWorld) / 2
		local length = (endWorld - startWorld).Magnitude
		local segment = Instance.new("Part")
		segment.Name = name
		segment.Size = Vector3.new(thickness, thickness, length)
		segment.CFrame = CFrame.lookAt(middle, endWorld)
		segment.Anchored = true
		segment.Color = color
		segment.Material = material or Enum.Material.SmoothPlastic
		segment.CanCollide = false
		segment.CanTouch = false
		segment.CanQuery = true
		segment.TopSurface = Enum.SurfaceType.Smooth
		segment.BottomSurface = Enum.SurfaceType.Smooth
		segment.Parent = shovelFolder
		return segment
	end

	shovelSegment("HandleShaft", Vector3.new(-1.1, 0, 0), Vector3.new(0.8, 0, 0), 0.18, yellow)
	shovelSegment("TopGrip", Vector3.new(-1.45, 0, -0.42), Vector3.new(-1.45, 0, 0.42), 0.22, gripColor)
	makePart(shovelFolder, "GripConnector", Vector3.new(0.28, 0.14, 0.28), shovelOrigin, Vector3.new(-1.18, 0, 0), gripColor, Enum.Material.SmoothPlastic, 0, false)
	makePart(shovelFolder, "BladeConnector", Vector3.new(0.32, 0.16, 0.42), shovelOrigin, Vector3.new(0.9, 0, 0), bladeDark, Enum.Material.SmoothPlastic, 0, false)
	makePart(shovelFolder, "BladeBody", Vector3.new(0.9, 0.18, 0.95), shovelOrigin, Vector3.new(1.34, 0, 0), bladeColor, Enum.Material.SmoothPlastic, 0, false)
	makePart(shovelFolder, "BladePoint", Vector3.new(0.5, 0.18, 0.62), shovelOrigin, Vector3.new(1.82, 0, 0), bladeDark, Enum.Material.SmoothPlastic, 0, false, Vector3.new(0, 0, 45))
	makePart(shovelFolder, "BladeShine", Vector3.new(0.12, 0.2, 0.48), shovelOrigin, Vector3.new(1.23, 0.02, -0.18), Color3.fromRGB(140, 210, 255), Enum.Material.SmoothPlastic, 0, false)
	shovel.PrimaryPart = makePart(primaryFolder, "PrimaryPart", Vector3.new(0.4, 0.4, 0.4), shovelOrigin, Vector3.new(0.3, 0, 0), Color3.fromRGB(255, 0, 255), Enum.Material.ForceField, 1, false)

	print("Limestone lobby beach decor patch: placed volleyball, sandcastle, bucket, and shovel.")
end

local function applyLimestoneLobbySmallAnimalDecor()
	local lobby = findSavedLobbyArea()
	local parent = lobby or Workspace

	for _, descendant in ipairs(parent:GetDescendants()) do
		if descendant:IsA("Model") and (descendant.Name == "SmallTurtle" or descendant.Name == "SmallCrab") then
			descendant:Destroy()
		end
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant.Name == "LimestoneLobbySmallAnimalDecor" then
			descendant:Destroy()
		end
	end

	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "LimestoneLobbySmallAnimalDecor"
	decorFolder.Parent = parent

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { decorFolder }

	local function groundY(x, z)
		local result = Workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -220, 0), raycastParams)
		if result then
			return result.Position.Y
		end

		return 2.5
	end

	local function makeFolder(parentModel, name)
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parentModel
		return folder
	end

	local function makeModel(name, position, yawDegrees)
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = decorFolder
		return model, CFrame.new(position) * CFrame.Angles(0, math.rad(yawDegrees or 0), 0)
	end

	local function makePart(parentModel, name, size, origin, localPosition, color, material, transparency, canCollide, localRotation)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = origin * CFrame.new(localPosition) * CFrame.Angles(
			math.rad(localRotation and localRotation.X or 0),
			math.rad(localRotation and localRotation.Y or 0),
			math.rad(localRotation and localRotation.Z or 0)
		)
		part.Anchored = true
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Transparency = transparency or 0
		part.CanCollide = canCollide == true
		part.CanTouch = false
		part.CanQuery = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parentModel
		return part
	end

	local function makeSegment(parentModel, name, origin, startLocal, endLocal, thickness, color, material)
		local startWorld = origin:PointToWorldSpace(startLocal)
		local endWorld = origin:PointToWorldSpace(endLocal)
		local middle = (startWorld + endWorld) / 2
		local segment = Instance.new("Part")
		segment.Name = name
		segment.Size = Vector3.new(thickness, thickness, (endWorld - startWorld).Magnitude)
		segment.CFrame = CFrame.lookAt(middle, endWorld)
		segment.Anchored = true
		segment.Color = color
		segment.Material = material or Enum.Material.SmoothPlastic
		segment.CanCollide = false
		segment.CanTouch = false
		segment.CanQuery = true
		segment.TopSurface = Enum.SurfaceType.Smooth
		segment.BottomSurface = Enum.SurfaceType.Smooth
		segment.Parent = parentModel
		return segment
	end

	local turtle, turtleOrigin = makeModel("SmallTurtle", Vector3.new(-286, groundY(-286, -520) + 0.05, -520), 22)
	local turtleBody = makeFolder(turtle, "CompactBody")
	local turtlePrimary = makeFolder(turtle, "PrimaryPartFolder")
	local shellColor = Color3.fromRGB(85, 120, 70)
	local shellDark = Color3.fromRGB(55, 88, 52)
	local shellLight = Color3.fromRGB(105, 145, 82)
	local turtleSkin = Color3.fromRGB(130, 170, 95)
	local eyeColor = Color3.fromRGB(30, 30, 30)

	local shell = makePart(turtleBody, "ShellBody", Vector3.new(2.15, 0.78, 1.65), turtleOrigin, Vector3.new(0, 0.68, 0), shellColor, Enum.Material.SmoothPlastic, 0, false)
	shell.Shape = Enum.PartType.Ball
	local shellTop = makePart(turtleBody, "ShellTopPatch", Vector3.new(1.35, 0.28, 0.95), turtleOrigin, Vector3.new(0, 0.93, 0), shellDark, Enum.Material.SmoothPlastic, 0, false)
	shellTop.Shape = Enum.PartType.Ball
	makePart(turtleBody, "ShellCenterMark", Vector3.new(0.2, 0.08, 0.95), turtleOrigin, Vector3.new(0, 1.08, 0), shellLight, Enum.Material.SmoothPlastic, 0, false)
	local head = makePart(turtleBody, "HeadBuiltIntoShell", Vector3.new(0.72, 0.5, 0.5), turtleOrigin, Vector3.new(0.78, 0.68, 0), turtleSkin, Enum.Material.SmoothPlastic, 0, false)
	head.Shape = Enum.PartType.Ball
	makePart(turtleBody, "NeckFilledConnection", Vector3.new(0.58, 0.32, 0.44), turtleOrigin, Vector3.new(0.55, 0.62, 0), turtleSkin, Enum.Material.SmoothPlastic, 0, false)
	makePart(turtleBody, "EyeLeft", Vector3.new(0.07, 0.07, 0.07), turtleOrigin, Vector3.new(1.03, 0.76, -0.11), eyeColor, Enum.Material.SmoothPlastic, 0, false).Shape = Enum.PartType.Ball
	makePart(turtleBody, "EyeRight", Vector3.new(0.07, 0.07, 0.07), turtleOrigin, Vector3.new(1.03, 0.76, 0.11), eyeColor, Enum.Material.SmoothPlastic, 0, false).Shape = Enum.PartType.Ball
	makePart(turtleBody, "LeftSideColorPatch", Vector3.new(0.75, 0.08, 0.2), turtleOrigin, Vector3.new(0, 0.55, -0.72), turtleSkin, Enum.Material.SmoothPlastic, 0, false)
	makePart(turtleBody, "RightSideColorPatch", Vector3.new(0.75, 0.08, 0.2), turtleOrigin, Vector3.new(0, 0.55, 0.72), turtleSkin, Enum.Material.SmoothPlastic, 0, false)
	turtle.PrimaryPart = makePart(turtlePrimary, "PrimaryPart", Vector3.new(0.45, 0.45, 0.45), turtleOrigin, Vector3.new(0, 0.68, 0), Color3.fromRGB(255, 0, 255), Enum.Material.ForceField, 1, false)

	local crab, crabOrigin = makeModel("SmallCrab", Vector3.new(-300, groundY(-300, -538) + 0.05, -538), -16)
	local crabBody = makeFolder(crab, "CompactBody")
	local crabPrimary = makeFolder(crab, "PrimaryPartFolder")
	local crabColor = Color3.fromRGB(205, 85, 55)
	local crabDark = Color3.fromRGB(165, 60, 40)

	local body = makePart(crabBody, "BodyShell", Vector3.new(1.65, 0.58, 1.12), crabOrigin, Vector3.new(0, 0.55, 0), crabColor, Enum.Material.SmoothPlastic, 0, false)
	body.Shape = Enum.PartType.Ball
	local bodyTop = makePart(crabBody, "BodyTopPatch", Vector3.new(0.95, 0.16, 0.62), crabOrigin, Vector3.new(0, 0.77, 0), crabDark, Enum.Material.SmoothPlastic, 0, false)
	bodyTop.Shape = Enum.PartType.Ball
	makePart(crabBody, "EyeLeft", Vector3.new(0.12, 0.12, 0.12), crabOrigin, Vector3.new(0.34, 0.92, -0.18), eyeColor, Enum.Material.SmoothPlastic, 0, false).Shape = Enum.PartType.Ball
	makePart(crabBody, "EyeRight", Vector3.new(0.12, 0.12, 0.12), crabOrigin, Vector3.new(0.34, 0.92, 0.18), eyeColor, Enum.Material.SmoothPlastic, 0, false).Shape = Enum.PartType.Ball
	makePart(crabBody, "LeftClawColorPatch", Vector3.new(0.52, 0.1, 0.24), crabOrigin, Vector3.new(0.5, 0.76, -0.46), crabDark, Enum.Material.SmoothPlastic, 0, false, Vector3.new(0, -10, 0))
	makePart(crabBody, "RightClawColorPatch", Vector3.new(0.52, 0.1, 0.24), crabOrigin, Vector3.new(0.5, 0.76, 0.46), crabDark, Enum.Material.SmoothPlastic, 0, false, Vector3.new(0, 10, 0))
	makePart(crabBody, "FrontSmileMark", Vector3.new(0.5, 0.06, 0.08), crabOrigin, Vector3.new(0.58, 0.76, 0), crabDark, Enum.Material.SmoothPlastic, 0, false)
	crab.PrimaryPart = makePart(crabPrimary, "PrimaryPart", Vector3.new(0.45, 0.45, 0.45), crabOrigin, Vector3.new(0, 0.55, 0), Color3.fromRGB(255, 0, 255), Enum.Material.ForceField, 1, false)

	print("Limestone lobby animal decor patch: replaced crab and turtle with assembled versions.")
end

local function applyLimestoneLobbyOnePieceBeachDecor()
	local lobby = findSavedLobbyArea()
	local parent = lobby or Workspace

	local defaults = {
		OnePieceSmallCrab = Vector3.new(-300, 3, -538),
		OnePieceSmallTurtle = Vector3.new(-286, 3, -520),
		OnePieceSmallBeachVolleyball = Vector3.new(-182, 3, -540),
	}

	local function savedPosition(names, fallback)
		for _, name in ipairs(names) do
			local existing = Workspace:FindFirstChild(name, true)
			if existing and existing:IsA("Model") then
				local ok, pivot = pcall(function()
					return existing:GetPivot()
				end)
				if ok and pivot.Position.X >= -325 and pivot.Position.X <= -15 and pivot.Position.Z >= -605 and pivot.Position.Z <= -300 then
					return pivot.Position
				end
			elseif existing and existing:IsA("BasePart") then
				if existing.Position.X >= -325 and existing.Position.X <= -15 and existing.Position.Z >= -605 and existing.Position.Z <= -300 then
					return existing.Position
				end
			end
		end

		return fallback
	end

	local positions = {
		OnePieceSmallCrab = savedPosition({ "OnePieceSmallCrab", "SmallCrab" }, defaults.OnePieceSmallCrab),
		OnePieceSmallTurtle = savedPosition({ "OnePieceSmallTurtle", "SmallTurtle" }, defaults.OnePieceSmallTurtle),
		OnePieceSmallBeachVolleyball = savedPosition({ "OnePieceSmallBeachVolleyball", "SmallBeachVolleyball" }, defaults.OnePieceSmallBeachVolleyball),
	}

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant.Name == "OnePieceSmallCrab"
			or descendant.Name == "OnePieceSmallCrab_TempParts"
			or descendant.Name == "OnePieceSmallTurtle"
			or descendant.Name == "OnePieceSmallTurtle_TempParts"
			or descendant.Name == "OnePieceSmallBeachVolleyball"
			or descendant.Name == "OnePieceSmallBeachVolleyball_TempParts"
			or descendant.Name == "SmallCrab"
			or descendant.Name == "SmallTurtle"
			or descendant.Name == "SmallBeachVolleyball" then
			descendant:Destroy()
		end
	end

	local old = parent:FindFirstChild("LimestoneLobbyOnePieceBeachDecor")
	if old then
		old:Destroy()
	end

	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "LimestoneLobbyOnePieceBeachDecor"
	decorFolder.Parent = parent

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { decorFolder }

	local function groundY(x, z)
		local result = Workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -220, 0), raycastParams)
		if result then
			return result.Position.Y
		end

		return 2.5
	end

	local function makePart(parentModel, name, size, origin, localPosition, color, material, transparency, canCollide, shape, localRotation)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = origin * CFrame.new(localPosition) * CFrame.Angles(
			math.rad(localRotation and localRotation.X or 0),
			math.rad(localRotation and localRotation.Y or 0),
			math.rad(localRotation and localRotation.Z or 0)
		)
		part.Anchored = true
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Transparency = transparency or 0
		part.CanCollide = canCollide == true
		part.CanTouch = false
		part.CanQuery = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			part.Shape = shape
		end
		part.Parent = parentModel
		return part
	end

	local function unionIntoOne(tempModel, finalName)
		local parts = {}
		for _, obj in ipairs(tempModel:GetDescendants()) do
			if obj:IsA("BasePart") then
				table.insert(parts, obj)
			end
		end

		if #parts < 2 then
			warn(finalName .. ": not enough parts to union.")
			tempModel.Parent = decorFolder
			return tempModel
		end

		local main = parts[1]
		local others = {}
		for i = 2, #parts do
			table.insert(others, parts[i])
		end

		local success, union = pcall(function()
			return main:UnionAsync(others)
		end)

		if success and union then
			union.Name = finalName
			union.Anchored = true
			union.CanCollide = false
			union.CanTouch = false
			union.CanQuery = true
			union.Parent = decorFolder
			pcall(function()
				union.UsePartColor = false
			end)
			tempModel:Destroy()
			return union
		end

		tempModel.Name = finalName .. "_UnionFailedParts"
		tempModel.Parent = decorFolder
		warn(finalName .. ": UnionAsync failed, so grouped parts were left in the lobby.")
		return tempModel
	end

	local function makeTemp(name, worldPosition, yawDegrees)
		local temp = Instance.new("Model")
		temp.Name = name .. "_TempParts"
		temp.Parent = Workspace
		local origin = CFrame.new(Vector3.new(worldPosition.X, groundY(worldPosition.X, worldPosition.Z), worldPosition.Z)) * CFrame.Angles(0, math.rad(yawDegrees or 0), 0)
		return temp, origin
	end

	do
		local temp, origin = makeTemp("OnePieceSmallCrab", positions.OnePieceSmallCrab, -16)
		local crabColor = Color3.fromRGB(205, 85, 55)
		local crabDark = Color3.fromRGB(165, 60, 40)
		local eyeColor = Color3.fromRGB(20, 20, 20)

		makePart(temp, "Body", Vector3.new(1.9, 0.7, 1.3), origin, Vector3.new(0, 0.95, 0), crabColor, Enum.Material.SmoothPlastic, 0, false, Enum.PartType.Ball)
		makePart(temp, "BodyTop", Vector3.new(1.2, 0.18, 0.8), origin, Vector3.new(0, 1.18, 0), crabDark, Enum.Material.SmoothPlastic, 0, false)
		makePart(temp, "EyeStemLeft", Vector3.new(0.07, 0.38, 0.07), origin, Vector3.new(0.45, 1.35, -0.2), crabDark, Enum.Material.SmoothPlastic, 0, false)
		makePart(temp, "EyeStemRight", Vector3.new(0.07, 0.38, 0.07), origin, Vector3.new(0.45, 1.35, 0.2), crabDark, Enum.Material.SmoothPlastic, 0, false)
		makePart(temp, "EyeLeft", Vector3.new(0.12, 0.12, 0.12), origin, Vector3.new(0.45, 1.57, -0.2), eyeColor, Enum.Material.SmoothPlastic, 0, false)
		makePart(temp, "EyeRight", Vector3.new(0.12, 0.12, 0.12), origin, Vector3.new(0.45, 1.57, 0.2), eyeColor, Enum.Material.SmoothPlastic, 0, false)
		makePart(temp, "LeftClawBase", Vector3.new(0.55, 0.15, 0.15), origin, Vector3.new(1.05, 1.02, -0.52), crabColor, Enum.Material.SmoothPlastic, 0, false, nil, Vector3.new(0, 0, 25))
		makePart(temp, "LeftClawTop", Vector3.new(0.22, 0.12, 0.12), origin, Vector3.new(1.35, 1.12, -0.64), crabDark, Enum.Material.SmoothPlastic, 0, false)
		makePart(temp, "LeftClawBottom", Vector3.new(0.22, 0.12, 0.12), origin, Vector3.new(1.35, 0.92, -0.44), crabDark, Enum.Material.SmoothPlastic, 0, false)
		makePart(temp, "RightClawBase", Vector3.new(0.55, 0.15, 0.15), origin, Vector3.new(1.05, 1.02, 0.52), crabColor, Enum.Material.SmoothPlastic, 0, false, nil, Vector3.new(0, 0, -25))
		makePart(temp, "RightClawTop", Vector3.new(0.22, 0.12, 0.12), origin, Vector3.new(1.35, 1.12, 0.44), crabDark, Enum.Material.SmoothPlastic, 0, false)
		makePart(temp, "RightClawBottom", Vector3.new(0.22, 0.12, 0.12), origin, Vector3.new(1.35, 0.92, 0.64), crabDark, Enum.Material.SmoothPlastic, 0, false)

		for i, item in ipairs({
			{ Vector3.new(0.35, 0.78, -0.72), 20 },
			{ Vector3.new(0, 0.75, -0.82), 8 },
			{ Vector3.new(-0.35, 0.72, -0.72), -8 },
			{ Vector3.new(0.35, 0.78, 0.72), -20 },
			{ Vector3.new(0, 0.75, 0.82), -8 },
			{ Vector3.new(-0.35, 0.72, 0.72), 8 },
		}) do
			makePart(temp, "Leg_" .. i, Vector3.new(0.55, 0.08, 0.08), origin, item[1], crabDark, Enum.Material.SmoothPlastic, 0, false, nil, Vector3.new(0, 0, item[2]))
		end

		unionIntoOne(temp, "OnePieceSmallCrab")
	end

	do
		local temp, origin = makeTemp("OnePieceSmallBeachVolleyball", positions.OnePieceSmallBeachVolleyball, -18)
		local white = Color3.fromRGB(245, 245, 235)
		local blue = Color3.fromRGB(40, 130, 230)
		local yellow = Color3.fromRGB(245, 210, 65)
		local darkLine = Color3.fromRGB(40, 40, 45)

		makePart(temp, "BallBody", Vector3.new(1.8, 1.8, 1.8), origin, Vector3.new(0, 1.1, 0), white, Enum.Material.SmoothPlastic, 0, false, Enum.PartType.Ball)
		makePart(temp, "BlueStripeFront", Vector3.new(0.35, 1.6, 0.12), origin, Vector3.new(-0.38, 1.1, -0.86), blue, Enum.Material.SmoothPlastic, 0, false, nil, Vector3.new(0, 0, -18))
		makePart(temp, "YellowStripeFront", Vector3.new(0.35, 1.6, 0.12), origin, Vector3.new(0.38, 1.1, -0.86), yellow, Enum.Material.SmoothPlastic, 0, false, nil, Vector3.new(0, 0, 18))
		makePart(temp, "BlueStripeSide", Vector3.new(0.12, 1.45, 0.35), origin, Vector3.new(-0.86, 1.1, 0.35), blue, Enum.Material.SmoothPlastic, 0, false, nil, Vector3.new(0, 20, 0))
		makePart(temp, "YellowStripeSide", Vector3.new(0.12, 1.45, 0.35), origin, Vector3.new(0.86, 1.1, -0.35), yellow, Enum.Material.SmoothPlastic, 0, false, nil, Vector3.new(0, -20, 0))
		makePart(temp, "CenterSeam", Vector3.new(0.08, 1.75, 0.1), origin, Vector3.new(0, 1.1, -0.92), darkLine, Enum.Material.SmoothPlastic, 0, false)
		makePart(temp, "SideSeam", Vector3.new(0.1, 1.55, 0.08), origin, Vector3.new(-0.92, 1.1, 0), darkLine, Enum.Material.SmoothPlastic, 0, false)

		unionIntoOne(temp, "OnePieceSmallBeachVolleyball")
	end

	do
		local temp, origin = makeTemp("OnePieceSmallTurtle", positions.OnePieceSmallTurtle, 22)
		local shellColor = Color3.fromRGB(85, 120, 70)
		local shellDark = Color3.fromRGB(65, 95, 55)
		local skinColor = Color3.fromRGB(130, 170, 95)
		local eyeColor = Color3.fromRGB(30, 30, 30)

		makePart(temp, "Shell", Vector3.new(2.4, 0.9, 1.9), origin, Vector3.new(0, 1.2, 0), shellColor, Enum.Material.SmoothPlastic, 0, false, Enum.PartType.Ball)
		makePart(temp, "ShellTop", Vector3.new(1.7, 0.3, 1.25), origin, Vector3.new(0, 1.55, 0), shellDark, Enum.Material.SmoothPlastic, 0, false)
		makePart(temp, "Head", Vector3.new(0.75, 0.55, 0.6), origin, Vector3.new(1.35, 1.05, 0), skinColor, Enum.Material.SmoothPlastic, 0, false)
		makePart(temp, "EyeLeft", Vector3.new(0.08, 0.08, 0.08), origin, Vector3.new(1.72, 1.15, -0.14), eyeColor, Enum.Material.SmoothPlastic, 0, false)
		makePart(temp, "EyeRight", Vector3.new(0.08, 0.08, 0.08), origin, Vector3.new(1.72, 1.15, 0.14), eyeColor, Enum.Material.SmoothPlastic, 0, false)

		for i, pos in ipairs({
			Vector3.new(0.6, 0.72, -0.62),
			Vector3.new(0.6, 0.72, 0.62),
			Vector3.new(-0.6, 0.72, -0.62),
			Vector3.new(-0.6, 0.72, 0.62),
		}) do
			makePart(temp, "Leg_" .. i, Vector3.new(0.45, 0.22, 0.32), origin, pos, skinColor, Enum.Material.SmoothPlastic, 0, false, Enum.PartType.Cylinder, Vector3.new(0, 0, 90))
		end
		makePart(temp, "Tail", Vector3.new(0.25, 0.18, 0.18), origin, Vector3.new(-1.25, 0.95, 0), skinColor, Enum.Material.SmoothPlastic, 0, false)

		unionIntoOne(temp, "OnePieceSmallTurtle")
	end

	print("Limestone lobby one-piece beach decor patch: placed crab, turtle, and volleyball.")
end

applySoftLightingProfile()
applyBeginnerPondArea()
applyFountainBrickPlaza()
applyFountainWarpTrigger()
applyShopWoodSpacing()
applySeasideRodShopMirror()
applySeasideShopFishmonger()
applySeasideRodShopKeeper()
applySupplyShopAndLeaderboardLabels()
applyCastleShop()
applySeasideShopDisplayAquarium()
applyLimestoneLobbySafetyBorder()
applyLimestoneLobbyPathLights()
applyLimestoneLobbySmallBeachDecor()
applySmallDecorCollision()
applyLimestoneLobbySpawn()

print("Editor patches complete. Save the place to keep these changes in Studio.")
