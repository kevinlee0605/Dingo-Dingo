local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local MonetizationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
local Remotes = ReplicatedStorage:FindFirstChild("FishingRemotes")
local Notice = Remotes and Remotes:FindFirstChild("Notice")
local OpenShop = Remotes and Remotes:FindFirstChild("OpenShop")

local CastleShopService = {}

local MODEL_NAME = "CastleShop"
local LEGACY_MODEL_NAME = "CastleShopArea"
local DEFAULT_ORIGIN = Vector3.new(-420, 0, 260)
local currentOrigin = DEFAULT_ORIGIN

local LIMESTONE = Color3.fromRGB(222, 218, 180)
local LIMESTONE_SHADOW = Color3.fromRGB(194, 190, 152)
local SAFETY_BLUE = Color3.fromRGB(80, 210, 255)
local STONE_DARK = Color3.fromRGB(74, 78, 84)
local STONE = Color3.fromRGB(104, 109, 116)
local STONE_LIGHT = Color3.fromRGB(156, 160, 166)
local STONE_TRIM = Color3.fromRGB(184, 186, 190)
local WOOD = Color3.fromRGB(94, 61, 38)
local WOOD_DARK = Color3.fromRGB(54, 37, 27)
local GOLD = Color3.fromRGB(238, 186, 64)
local BLUE = Color3.fromRGB(42, 96, 190)
local RED = Color3.fromRGB(176, 46, 52)
local GREEN = Color3.fromRGB(38, 150, 86)
local PURPLE = Color3.fromRGB(112, 72, 170)

local promptConnections = {}
local connectedPrompts = {}

local function makeFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function notify(player, message)
	if player and Notice then
		Notice:FireClient(player, message)
	end
end

local function getOpenShopRemote()
	if OpenShop and OpenShop.Parent then
		return OpenShop
	end

	Remotes = ReplicatedStorage:FindFirstChild("FishingRemotes")
	if not Remotes then
		return nil
	end

	OpenShop = Remotes:FindFirstChild("OpenShop")
	if not OpenShop then
		OpenShop = Instance.new("RemoteEvent")
		OpenShop.Name = "OpenShop"
		OpenShop.Parent = Remotes
	end

	return OpenShop
end

local function makePart(parent, name, size, position, color, material, transparency, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.Slate
	part.Transparency = transparency or 0
	part.CanCollide = canCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addText(part, textValue, face, textColor, textSize)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CastleShopText"
	gui.Face = face or Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(900, 360)
	gui.Parent = part

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = textValue
	text.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(18, 20, 24)
	text.TextScaled = true
	text.TextWrapped = true
	text.Font = Enum.Font.FredokaOne
	text.Parent = gui

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 10
	constraint.MaxTextSize = textSize or 38
	constraint.Parent = text
end

local function makeSign(parent, name, position, size, textValue, color, face, textColor, textSize)
	local sign = makePart(parent, name, size, position, color, Enum.Material.Wood)
	addText(sign, textValue, face or Enum.NormalId.Front, textColor, textSize)
	return sign
end

local function makePromptPart(parent, name, position, size, purchaseKind, purchaseKey, actionText, objectText)
	local promptPart = makePart(parent, name, size, position, Color3.fromRGB(0, 255, 255), Enum.Material.ForceField, 1, false)
	promptPart:SetAttribute("PurchaseKind", purchaseKind)
	promptPart:SetAttribute("PurchaseKey", purchaseKey)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CastleShopPurchasePrompt"
	prompt.ActionText = actionText or "Purchase"
	prompt.ObjectText = objectText or "Castle Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart
	return prompt
end

local function makeOpenShopPromptPart(parent, name, position, size, shopTab, actionText, objectText)
	local promptPart = makePart(parent, name, size, position, Color3.fromRGB(0, 255, 255), Enum.Material.ForceField, 1, false)
	promptPart:SetAttribute("CastleShopAction", "OpenShop")
	promptPart:SetAttribute("ShopTab", shopTab or "Passes")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CastleShopOpenPrompt"
	prompt.ActionText = actionText or "Open Shop"
	prompt.ObjectText = objectText or "Castle Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Parent = promptPart
	return prompt
end

local function makeSafetyWall(parent, name, size, offset)
	local wall = makePart(parent, name, size, currentOrigin + offset, SAFETY_BLUE, Enum.Material.ForceField, 1, true)
	wall.CanTouch = false
	wall.CanQuery = true
	pcall(function()
		wall.CollisionGroup = "Default"
	end)
	return wall
end

local function makeBattlements(parent, prefix, z, xStart, xEnd, y)
	local index = 0
	for x = xStart, xEnd, 10 do
		index += 1
		makePart(parent, prefix .. "_Battlement_" .. tostring(index), Vector3.new(5, 5, 5), currentOrigin + Vector3.new(x, y, z), STONE_TRIM, Enum.Material.Slate)
	end
end

local function makeSideBattlements(parent, prefix, x, zStart, zEnd, y)
	local index = 0
	for z = zStart, zEnd, 10 do
		index += 1
		makePart(parent, prefix .. "_Battlement_" .. tostring(index), Vector3.new(5, 5, 5), currentOrigin + Vector3.new(x, y, z), STONE_TRIM, Enum.Material.Slate)
	end
end

local function makeTower(parent, name, x, z)
	local tower = Instance.new("Model")
	tower.Name = name
	tower.Parent = parent

	local base = makePart(tower, "TowerBase", Vector3.new(24, 34, 24), currentOrigin + Vector3.new(x, 16, z), STONE_DARK, Enum.Material.Slate)
	makePart(tower, "TowerLightTrim", Vector3.new(26, 3, 26), currentOrigin + Vector3.new(x, 31.5, z), STONE_LIGHT, Enum.Material.Slate)
	makePart(tower, "TowerTop", Vector3.new(28, 4, 28), currentOrigin + Vector3.new(x, 36, z), STONE, Enum.Material.Slate)

	for dx = -10, 10, 10 do
		for dz = -10, 10, 10 do
			if math.abs(dx) == 10 or math.abs(dz) == 10 then
				makePart(tower, "TowerCrenel", Vector3.new(5, 5, 5), currentOrigin + Vector3.new(x + dx, 40.5, z + dz), STONE_TRIM, Enum.Material.Slate)
			end
		end
	end

	tower.PrimaryPart = base
end

local function makeBanner(parent, name, x, z, color)
	makePart(parent, name .. "_Pole", Vector3.new(0.5, 11, 0.5), currentOrigin + Vector3.new(x, 19, z), WOOD_DARK, Enum.Material.Wood, 0, false)
	makePart(parent, name .. "_Cloth", Vector3.new(5, 9, 0.5), currentOrigin + Vector3.new(x, 16.5, z - 0.15), color, Enum.Material.Fabric, 0, false)
	makePart(parent, name .. "_Tip", Vector3.new(1.3, 1.3, 1.3), currentOrigin + Vector3.new(x, 25, z), GOLD, Enum.Material.Metal, 0, false)
end

local function makeBooth(parent, name, x, z, boothColor, title, description, options)
	local booth = Instance.new("Model")
	booth.Name = name
	booth.Parent = parent

	makePart(booth, "BoothFloor", Vector3.new(30, 1, 18), currentOrigin + Vector3.new(x, 1.2, z), STONE, Enum.Material.Slate)
	makePart(booth, "BoothCounter", Vector3.new(25, 5, 4), currentOrigin + Vector3.new(x, 4.2, z - 6), WOOD, Enum.Material.WoodPlanks)
	makePart(booth, "BoothBack", Vector3.new(28, 16, 2), currentOrigin + Vector3.new(x, 10, z + 8), STONE_DARK, Enum.Material.Slate)
	makePart(booth, "BoothTrim", Vector3.new(30, 2, 3), currentOrigin + Vector3.new(x, 17.2, z + 7.5), boothColor, Enum.Material.SmoothPlastic)
	makeBanner(booth, "BannerLeft", x - 11, z + 6.6, boothColor)
	makeBanner(booth, "BannerRight", x + 11, z + 6.6, boothColor)

	makeSign(
		booth,
		"BoothSign",
		currentOrigin + Vector3.new(x, 11.2, z + 6.35),
		Vector3.new(25, 11, 0.6),
		title .. "\n" .. description,
		Color3.fromRGB(35, 42, 54),
		Enum.NormalId.Front,
		Color3.fromRGB(255, 255, 255),
		24
	)

	local optionCount = math.max(1, #options)
	local spacing = optionCount > 1 and 8 or 0
	local startX = x - ((optionCount - 1) * spacing / 2)
	for index, option in ipairs(options) do
		local optionX = startX + ((index - 1) * spacing)
		local optionSign = makeSign(
			booth,
			option.key .. "_OptionSign",
			currentOrigin + Vector3.new(optionX, 6.6, z - 8.4),
			Vector3.new(optionCount > 1 and 7.2 or 18, 3.5, 0.5),
			option.label,
			boothColor,
			Enum.NormalId.Front,
			Color3.fromRGB(255, 255, 255),
			18
		)
		if option.kind == "OpenShop" then
			makeOpenShopPromptPart(
				booth,
				option.key .. "_PromptPart",
				optionSign.Position + Vector3.new(0, -0.5, -2.2),
				Vector3.new(optionCount > 1 and 8 or 20, 5, 4),
				option.shopTab or option.key,
				option.actionText or "Open Shop",
				option.objectText or title
			)
		else
			makePromptPart(
				booth,
				option.key .. "_PromptPart",
				optionSign.Position + Vector3.new(0, -0.5, -2.2),
				Vector3.new(optionCount > 1 and 8 or 20, 5, 4),
				option.kind,
				option.key,
				option.actionText or "Purchase",
				option.objectText or title
			)
		end
	end
end

function CastleShopService.clear()
	for _, connection in ipairs(promptConnections) do
		connection:Disconnect()
	end
	table.clear(promptConnections)
	table.clear(connectedPrompts)

	for _, modelName in ipairs({ MODEL_NAME, LEGACY_MODEL_NAME }) do
		local existing = workspace:FindFirstChild(modelName, true)
		while existing do
			existing:Destroy()
			existing = workspace:FindFirstChild(modelName, true)
		end
	end
end

function CastleShopService.promptPurchase(player, purchaseKind, purchaseKey)
	if purchaseKind == "GamePass" then
		local pass = MonetizationConfig.GamePasses[purchaseKey]
		if not pass then
			return
		end
		if pass.purchasable == false then
			notify(player, pass.name .. " is coming soon.")
			return
		end

		local ownsPass = false
		local ownsSuccess = pcall(function()
			ownsPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
		end)
		if ownsSuccess and ownsPass then
			notify(player, "You already own " .. pass.name .. ".")
			return
		end

		local success, err = pcall(function()
			print("Prompting purchase:", pass.name or purchaseKey, pass.id)
			if purchaseKey == "VipAngler" then
				print("Prompting VIP Angler Pass purchase:", pass.id)
			elseif purchaseKey == "SmallBag" then
				print("Prompting Small Bag Upgrade purchase:", pass.id)
			elseif purchaseKey == "MediumBag" then
				print("Prompting Medium Bag Upgrade purchase:", pass.id)
			elseif purchaseKey == "LargeBag" then
				print("Prompting Large Bag Upgrade purchase:", pass.id)
			end
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)
		if not success then
			warn("Castle shop game pass prompt failed", player.Name, purchaseKey, err)
			notify(player, "Purchase prompt failed. Check the game pass ID before publishing.")
		end
	elseif purchaseKind == "Product" then
		local product = MonetizationConfig.DeveloperProducts[purchaseKey]
		if not product then
			return
		end
		local productId = tonumber(product.id) or tonumber(product.Id)
		if product.purchasable == false or not productId or productId <= 0 then
			notify(player, (product.name or "That product") .. " is coming soon.")
			return
		end

		local success, err = pcall(function()
			print("Prompting purchase:", product.name or purchaseKey, productId)
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		if not success then
			warn("Castle shop product prompt failed", player.Name, purchaseKey, err)
			notify(player, "Purchase prompt failed. Check the product ID before publishing.")
		end
	end
end

function CastleShopService.openShop(player, shopTab)
	local remote = getOpenShopRemote()
	if not remote then
		warn("Castle shop could not open Shop UI because OpenShop remote is missing.")
		notify(player, "Shop is not ready yet. Try again in a moment.")
		return
	end

	print("Opening shop from castle")
	remote:FireClient(player, shopTab or "Passes")
end

function CastleShopService.connectPrompts(root)
	for _, descendant in ipairs((root or workspace):GetDescendants()) do
		if descendant:IsA("ProximityPrompt")
			and (descendant.Name == "CastleShopPurchasePrompt" or descendant.Name == "CastleShopOpenPrompt")
			and not connectedPrompts[descendant]
		then
			connectedPrompts[descendant] = true
			descendant.Enabled = true
			descendant.RequiresLineOfSight = false
			descendant:SetAttribute("CastleShopConnected", true)
			table.insert(promptConnections, descendant.Triggered:Connect(function(player)
				print("Castle shop interaction triggered")
				local promptPart = descendant.Parent
				if promptPart and promptPart:IsA("BasePart") then
					local action = promptPart:GetAttribute("CastleShopAction")
					if action == "OpenShop" then
						CastleShopService.openShop(player, promptPart:GetAttribute("ShopTab"))
						return
					end

					local purchaseKind = promptPart:GetAttribute("PurchaseKind")
					local purchaseKey = promptPart:GetAttribute("PurchaseKey")
					if purchaseKind == "GamePass" or purchaseKind == "Product" then
						CastleShopService.promptPurchase(player, purchaseKind, purchaseKey)
					else
						CastleShopService.openShop(player, "Passes")
					end
				end
			end))
			descendant.Destroying:Connect(function()
				connectedPrompts[descendant] = nil
			end)
		end
	end
end

local function ensureCastleOpenShopPrompt(castle)
	if castle:FindFirstChild("CastleShopOpenPrompt", true) then
		return
	end

	local pivot, size = castle:GetBoundingBox()
	local promptFolder = castle:FindFirstChild("Prompts")
	if not promptFolder then
		promptFolder = Instance.new("Folder")
		promptFolder.Name = "Prompts"
		promptFolder.Parent = castle
	end

	makeOpenShopPromptPart(
		promptFolder,
		"CastleShopOpenPromptPart",
		pivot.Position + Vector3.new(0, 5, -size.Z / 2 - 8),
		Vector3.new(math.max(24, math.min(52, size.X * 0.28)), 10, 10),
		"Passes",
		"Open Shop",
		"Castle Shop"
	)
end

local function findExistingCastle()
	for _, modelName in ipairs({ MODEL_NAME, LEGACY_MODEL_NAME }) do
		local existing = workspace:FindFirstChild(modelName, true)
		if existing and existing:IsA("Model") then
			return existing
		end
	end

	return nil
end

local function repairExistingCastle(castle)
	-- The castle is authored in Studio. Runtime startup must not delete booths,
	-- rewrite collision, add geometry, or otherwise make Play differ from Edit.
	-- Existing authored prompts only need their handlers connected.
	CastleShopService.connectPrompts(castle)
	return castle
end

local function findLobbyArea()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "LobbyArea" and not descendant:FindFirstAncestor(MODEL_NAME) then
			return descendant
		end
	end

	return nil
end

local function isFloorCandidate(part)
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

local function calculateOrigin()
	local lobby = findLobbyArea()
	if not lobby then
		return DEFAULT_ORIGIN
	end

	local minX = math.huge
	local maxX = -math.huge
	local minZ = math.huge
	local maxZ = -math.huge
	local topY = -math.huge
	local candidateCount = 0

	for _, descendant in ipairs(lobby:GetDescendants()) do
		if descendant:IsA("BasePart") and isFloorCandidate(descendant) then
			candidateCount += 1
			topY = math.max(topY, descendant.Position.Y + descendant.Size.Y / 2)

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
		local success, pivot, size = pcall(function()
			local modelCFrame, modelSize = lobby:GetBoundingBox()
			return modelCFrame, modelSize
		end)

		if success and pivot and size then
			return Vector3.new(pivot.Position.X, DEFAULT_ORIGIN.Y, pivot.Position.Z + size.Z / 2 + 128)
		end

		return DEFAULT_ORIGIN
	end

	return Vector3.new((minX + maxX) / 2, topY - 0.4, maxZ + 128)
end

function CastleShopService.build()
	CastleShopService.clear()
	currentOrigin = calculateOrigin()

	local world = workspace:FindFirstChild("FishyFishWorld") or workspace
	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	model.Parent = world

	local platformFolder = makeFolder(model, "Platform")
	local borderFolder = makeFolder(model, "AntiFallBorder")
	local mainWallsFolder = makeFolder(model, "MainWalls")
	local leftTowerFolder = makeFolder(model, "LeftTower")
	local rightTowerFolder = makeFolder(model, "RightTower")
	local entranceArchFolder = makeFolder(model, "EntranceArch")
	local battlementsFolder = makeFolder(model, "Battlements")
	local stairsFolder = makeFolder(model, "Stairs")
	local interiorFolder = makeFolder(model, "Interior")
	local boothsFolder = makeFolder(model, "Booths")
	local signsFolder = makeFolder(model, "Signs")
	local decorationsFolder = makeFolder(model, "Decorations")

	makePart(platformFolder, "LimestoneCastlePlatform", Vector3.new(220, 1.2, 184), currentOrigin + Vector3.new(0, -0.2, 0), LIMESTONE, Enum.Material.Sandstone)
	makePart(platformFolder, "LimestoneConnectorToLobby", Vector3.new(64, 1.2, 72), currentOrigin + Vector3.new(0, -0.2, -128), LIMESTONE, Enum.Material.Sandstone)
	makePart(platformFolder, "LimestonePlatformShadowTrim", Vector3.new(224, 1, 188), currentOrigin + Vector3.new(0, -1.25, 0), LIMESTONE_SHADOW, Enum.Material.Sandstone)
	makePart(platformFolder, "LimestoneConnectorShadowTrim", Vector3.new(68, 1, 76), currentOrigin + Vector3.new(0, -1.25, -128), LIMESTONE_SHADOW, Enum.Material.Sandstone)
	makePart(interiorFolder, "CastleShopInnerFloor", Vector3.new(118, 1, 76), currentOrigin + Vector3.new(0, 1.1, 5), STONE, Enum.Material.Slate)

	local wallY = 28
	makeSafetyWall(borderFolder, "CastlePlatformSafetyWall_Back", Vector3.new(228, 64, 8), Vector3.new(0, wallY, 96))
	makeSafetyWall(borderFolder, "CastlePlatformSafetyWall_Left", Vector3.new(8, 64, 192), Vector3.new(-114, wallY, 0))
	makeSafetyWall(borderFolder, "CastlePlatformSafetyWall_Right", Vector3.new(8, 64, 192), Vector3.new(114, wallY, 0))
	makeSafetyWall(borderFolder, "CastlePlatformSafetyWall_FrontLeft", Vector3.new(84, 64, 8), Vector3.new(-72, wallY, -96))
	makeSafetyWall(borderFolder, "CastlePlatformSafetyWall_FrontRight", Vector3.new(84, 64, 8), Vector3.new(72, wallY, -96))
	makeSafetyWall(borderFolder, "CastleConnectorSafetyWall_Left", Vector3.new(8, 64, 76), Vector3.new(-36, wallY, -128))
	makeSafetyWall(borderFolder, "CastleConnectorSafetyWall_Right", Vector3.new(8, 64, 76), Vector3.new(36, wallY, -128))

	makePart(mainWallsFolder, "FrontWallLeft", Vector3.new(44, 26, 5), currentOrigin + Vector3.new(-38, 14, -44), STONE_DARK, Enum.Material.Slate)
	makePart(mainWallsFolder, "FrontWallRight", Vector3.new(44, 26, 5), currentOrigin + Vector3.new(38, 14, -44), STONE_DARK, Enum.Material.Slate)
	makePart(entranceArchFolder, "EntranceArchTop", Vector3.new(29, 8, 5.2), currentOrigin + Vector3.new(0, 25, -44), STONE_DARK, Enum.Material.Slate)
	makePart(entranceArchFolder, "EntranceArchLeftTrim", Vector3.new(5, 24, 6), currentOrigin + Vector3.new(-15.5, 13, -46), STONE_TRIM, Enum.Material.Slate)
	makePart(entranceArchFolder, "EntranceArchRightTrim", Vector3.new(5, 24, 6), currentOrigin + Vector3.new(15.5, 13, -46), STONE_TRIM, Enum.Material.Slate)
	makePart(entranceArchFolder, "EntranceArchCurveLeft", Vector3.new(9, 5, 6), currentOrigin + Vector3.new(-9, 25, -46), STONE_TRIM, Enum.Material.Slate)
	makePart(entranceArchFolder, "EntranceArchCurveRight", Vector3.new(9, 5, 6), currentOrigin + Vector3.new(9, 25, -46), STONE_TRIM, Enum.Material.Slate)
	makePart(mainWallsFolder, "BackWall", Vector3.new(116, 24, 5), currentOrigin + Vector3.new(0, 13, 46), STONE_DARK, Enum.Material.Slate)
	makePart(mainWallsFolder, "LeftWall", Vector3.new(5, 24, 90), currentOrigin + Vector3.new(-60, 13, 0), STONE_DARK, Enum.Material.Slate)
	makePart(mainWallsFolder, "RightWall", Vector3.new(5, 24, 90), currentOrigin + Vector3.new(60, 13, 0), STONE_DARK, Enum.Material.Slate)
	makePart(mainWallsFolder, "BackTrim", Vector3.new(120, 3, 6), currentOrigin + Vector3.new(0, 25.5, 46), STONE_LIGHT, Enum.Material.Slate)
	makePart(mainWallsFolder, "LeftTrim", Vector3.new(6, 3, 94), currentOrigin + Vector3.new(-60, 25.5, 0), STONE_LIGHT, Enum.Material.Slate)
	makePart(mainWallsFolder, "RightTrim", Vector3.new(6, 3, 94), currentOrigin + Vector3.new(60, 25.5, 0), STONE_LIGHT, Enum.Material.Slate)

	makeBattlements(battlementsFolder, "Front", -47, -52, 52, 31)
	makeBattlements(battlementsFolder, "Back", 48, -52, 52, 31)
	makeSideBattlements(battlementsFolder, "Left", -62, -34, 34, 31)
	makeSideBattlements(battlementsFolder, "Right", 62, -34, 34, 31)

	makeTower(leftTowerFolder, "FrontLeftTower", -70, -52)
	makeTower(leftTowerFolder, "BackLeftTower", -70, 52)
	makeTower(rightTowerFolder, "FrontRightTower", 70, -52)
	makeTower(rightTowerFolder, "BackRightTower", 70, 52)

	for step = 1, 4 do
		makePart(stairsFolder, "EntranceStep_" .. tostring(step), Vector3.new(36 + step * 6, 1, 6), currentOrigin + Vector3.new(0, 0.4 + step * 0.4, -66 + step * 5), STONE_TRIM, Enum.Material.Slate)
	end

	makeBanner(decorationsFolder, "FrontBannerLeft", -27, -47, RED)
	makeBanner(decorationsFolder, "FrontBannerRight", 27, -47, BLUE)

	makeSign(signsFolder, "CastleShopMainSign", currentOrigin + Vector3.new(0, 31.5, -48.2), Vector3.new(44, 7, 0.8), "Castle Shop", WOOD_DARK, Enum.NormalId.Front, GOLD, 38)
	makeSign(signsFolder, "CastleShopSubtitleSign", currentOrigin + Vector3.new(0, 24, -48.4), Vector3.new(42, 4.5, 0.8), "Passes, Upgrades, Bait & Items", WOOD, Enum.NormalId.Front, Color3.fromRGB(255, 255, 255), 24)
	makeOpenShopPromptPart(signsFolder, "CastleShopOpenPromptPart", currentOrigin + Vector3.new(0, 6, -62), Vector3.new(36, 10, 12), "Passes", "Open Shop", "Castle Shop")

	makeBooth(boothsFolder, "VipAnglerBooth", -42, 18, GOLD, "VIP Angler Pass", "VIP tag, +10% coin boost, daily bait reward, exclusive lobby title.", {
		{ kind = "GamePass", key = "VipAngler", label = "Buy VIP", actionText = "Buy VIP", objectText = "VIP Angler Pass" },
	})
	makeBooth(boothsFolder, "BiggerBagBooth", 14, 18, GREEN, "Bigger Bag", "Increase your fish storage.", {
		{ kind = "GamePass", key = "SmallBag", label = "+25 slots", actionText = "Buy +25", objectText = "Bigger Bag" },
		{ kind = "GamePass", key = "MediumBag", label = "+50 slots", actionText = "Buy +50", objectText = "Bigger Bag" },
		{ kind = "GamePass", key = "LargeBag", label = "+100 slots", actionText = "Buy +100", objectText = "Bigger Bag" },
	})
	makeBooth(boothsFolder, "LuckyBaitBooth", 42, 18, PURPLE, "Lucky Bait Packs", "Temporary bait that improves fishing luck.", {
		{ kind = "Product", key = "SmallLuckyBaitPack", label = "Small Pack", actionText = "Buy Small", objectText = "Lucky Bait Packs" },
		{ kind = "Product", key = "MediumLuckyBaitPack", label = "Medium Pack", actionText = "Buy Medium", objectText = "Lucky Bait Packs" },
		{ kind = "Product", key = "LargeLuckyBaitPack", label = "Large Pack", actionText = "Buy Large", objectText = "Lucky Bait Packs" },
	})

	model.PrimaryPart = model:FindFirstChild("CastleShopInnerFloor", true)
	CastleShopService.connectPrompts(model)
	return model
end

function CastleShopService.ensure()
	local existing = findExistingCastle()
	if existing then
		return repairExistingCastle(existing)
	end

	-- Older builds generated a second castle whenever the authored castle did
	-- not use CastleShop/CastleShopArea as its model name. The production map's
	-- castle is nested under the authored map hierarchy, so never synthesize a
	-- replacement here. Connecting tagged/attributed prompts across Workspace is
	-- sufficient and leaves the saved map untouched.
	CastleShopService.connectPrompts(workspace)
	return nil
end

function CastleShopService.start()
	CastleShopService.ensure()

	if not CastleShopService._workspaceConnection then
		CastleShopService._workspaceConnection = workspace.ChildAdded:Connect(function(child)
			task.defer(function()
				CastleShopService.connectPrompts(child)
			end)
		end)
	end
end

return CastleShopService
