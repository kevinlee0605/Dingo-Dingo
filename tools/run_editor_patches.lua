-- Run this once in Roblox Studio's Command Bar while editing the place.
-- It applies all current saved-editor map patches. Save the place afterward.

local Workspace = game:GetService("Workspace")

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
	if trigger and not trigger:IsA("BasePart") then
		trigger:Destroy()
		trigger = nil
	end

	if not trigger then
		trigger = Instance.new("Part")
		trigger.Name = "FountainBiomeWarpTrigger"
		trigger.Parent = root
	end

	trigger.Anchored = true
	trigger.Size = Vector3.new((maxX - minX) + 8, math.max(10, (maxY - minY) + 6), (maxZ - minZ) + 8)
	trigger.Position = Vector3.new((minX + maxX) / 2, minY + (trigger.Size.Y / 2), (minZ + maxZ) / 2)
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger.CanTouch = true
	trigger.CanQuery = false
	trigger.Material = Enum.Material.ForceField
	trigger:SetAttribute("TargetArea", "BiomeWarp")
	trigger:SetAttribute("PortalName", "Biome Warp")
	trigger:SetAttribute("RequiredLevel", 1)

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

	print("Fountain warp patch: added/updated saved fountain biome warp trigger.")
end

local function applyShopWoodSpacing()
	local topNames = {
		FrontWoodCounterTop = true,
		RightWoodCounterTop = true,
		FrontCounterTop = true,
		RightCounterTop = true,
	}

	local roofDeckNames = {
		RooftopDeck = true,
		RoofDeck = true,
	}

	local adjusted = 0
	for _, shop in ipairs(Workspace:GetDescendants()) do
		if shop:IsA("Model") and (shop.Name == "SeasideLShop" or shop.Name == "SeasideRodShop") then
			local seenParts = {}
			for _, descendant in ipairs(shop:GetDescendants()) do
				if descendant:IsA("BasePart") then
					local key = string.format(
						"%s|%s|%.1f|%.1f|%.1f|%.1f|%.1f|%.1f",
						descendant.Name,
						descendant.Material.Name,
						descendant.Position.X,
						descendant.Position.Y,
						descendant.Position.Z,
						descendant.Size.X,
						descendant.Size.Y,
						descendant.Size.Z
					)
					if seenParts[key] then
						descendant:Destroy()
						adjusted += 1
						continue
					end
					seenParts[key] = true

					if topNames[descendant.Name] and descendant.Position.Y < 10.55 then
						descendant.Position = Vector3.new(descendant.Position.X, 10.55, descendant.Position.Z)
						adjusted += 1
					elseif roofDeckNames[descendant.Name] and descendant.Position.Y > 23.05 then
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

applyFountainBrickPlaza()
applyFountainWarpTrigger()
applyShopWoodSpacing()
applySeasideRodShopMirror()
applySeasideShopFishmonger()

print("Editor patches complete. Save the place to keep these changes in Studio.")
