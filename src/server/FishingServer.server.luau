local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")
local CollectionService = game:GetService("CollectionService")

local EARLY_ROD_TEMPLATE_FOLDER_NAME = "FishyFishModelTemplates"

local function normalizeEarlyRodName(name)
	return string.lower(name):gsub("[%s_%-]", "")
end

local function shouldStoreEarlyRodModel(name)
	local normalized = normalizeEarlyRodName(name)
	return normalized == "woodenrodmk411"
		or normalized == "woodenrodmk4"
		or normalized == "woodenrodmk3"
		or normalized == "woodenrod"
		or normalized == "wooden"
		or normalized == "ironrod11"
		or normalized == "ironrod"
		or normalized == "iron"
		or normalized == "emeraldrod11"
		or normalized == "emeraldrod"
		or normalized == "emerald"
		or normalized == "steelrod"
		or normalized == "goldenrod11"
		or normalized == "goldenrod"
		or normalized == "goldrod"
		or normalized == "golden"
		or normalized == "oceanrod11"
		or normalized == "oceanrod"
		or normalized == "ocean"
end

local function disablePhysicsForSourceModel(instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.Massless = true
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end
end

local function removeWorkspaceModelsFolder()
	local models = workspace:FindFirstChild("Models")
	if not models then
		return
	end

	local storage = ServerStorage:FindFirstChild(EARLY_ROD_TEMPLATE_FOLDER_NAME)
	if not storage then
		storage = Instance.new("Folder")
		storage.Name = EARLY_ROD_TEMPLATE_FOLDER_NAME
		storage.Parent = ServerStorage
	end

	local moved = {}
	local function moveRodSource(instance)
		if moved[instance] or not shouldStoreEarlyRodModel(instance.Name) then
			return
		end

		if instance:IsA("Model") or instance:IsA("BasePart") then
			moved[instance] = true
			disablePhysicsForSourceModel(instance)
			instance.Parent = storage
		end
	end

	for _, descendant in ipairs(models:GetDescendants()) do
		moveRodSource(descendant)
	end

	for _, child in ipairs(models:GetChildren()) do
		moveRodSource(child)
	end

	models:Destroy()
end

removeWorkspaceModelsFolder()
workspace.ChildAdded:Connect(function(child)
	if child.Name == "Models" then
		task.defer(removeWorkspaceModelsFolder)
	end
end)

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local StartFishing = Remotes:WaitForChild("StartFishing")
local FinishMinigame = Remotes:WaitForChild("FinishMinigame")
local SellFish = Remotes:WaitForChild("SellFish")
local BuyRod = Remotes:WaitForChild("BuyRod")
local UnlockBiome = Remotes:WaitForChild("UnlockBiome")
local TeleportTo = Remotes:WaitForChild("TeleportTo")
local AquariumAction = Remotes:WaitForChild("AquariumAction")
local ToggleAutoFish = Remotes:WaitForChild("ToggleAutoFish")
local StateUpdated = Remotes:WaitForChild("StateUpdated")
local FishingPrompt = Remotes:WaitForChild("FishingPrompt")
local Notice = Remotes:WaitForChild("Notice")
local GetState = Remotes:WaitForChild("GetState")

local SAVE_STORE = "FishyFish_v1"
local saveStore = DataStoreService:GetDataStore(SAVE_STORE)

local playerData = {}
local pendingFishing = {}
local fishSerial = 0

local AUTO_FISH_MIN_WAIT = 11
local AUTO_FISH_MAX_WAIT = 18
local AUTO_FISH_MIN_SCORE = 0.42
local AUTO_FISH_MAX_SCORE = 0.62
local TESTING_START_COINS = 100000
local TESTING_START_LEVEL = GameConfig.MAX_LEVEL

-- Optional fallback: paste a single uploaded rod MeshId here if you prefer an asset-id based rod.
local WOODEN_ROD_MESH_ID = ""
local ROD_TEMPLATE_FOLDER_NAME = "FishyFishModelTemplates"
local ROD_TEMPLATE_NAMES_BY_ROD = {
	WoodenRod = { "woodenrodmk411", "WoodenRodMk411", "woodenrodmk4", "WoodenRodMk4", "WoodenRodMk3", "woodenrodmk3", "WoodenRod", "woodenrod", "wooden_rod" },
	IronRod = { "ironrod11", "IronRod11", "IronRod", "ironrod", "Iron Rod", "iron rod", "iron_rod" },
	EmeraldRod = { "emeraldrod11", "EmeraldRod11", "EmeraldRod", "emeraldrod", "Emerald Rod", "emerald rod", "emerald_rod", "SteelRod", "steelrod", "Steel Rod" },
	GoldenRod = { "goldenrod11", "GoldenRod11", "GoldenRod", "goldenrod", "Golden Rod", "golden rod", "golden_rod" },
	OceanRod = { "ocean rod11", "Ocean Rod11", "oceanrod11", "OceanRod11", "OceanRod", "oceanrod", "Ocean Rod", "ocean rod", "ocean_rod" },
}
local ROD_VISUAL_LENGTH = 3.9
local ROD_MAX_TEMPLATE_SCALE = 2
local ROD_GRIP_INSET = 0.82
local ROD_VISUAL_OFFSET = Vector3.new(0, -0.34, -0.18)
local ROD_VISUAL_ROTATION = CFrame.Angles(math.rad(-18), math.rad(10), math.rad(16))
local USE_WOODEN_ROD_SHAPE_FOR_ALL_RODS = false
local FISHING_ROD_TOOLS_ENABLED = true
local FISHING_ROD_3D_VISUALS_ENABLED = true
local FISHING_ROD_IMPORTED_MODELS_ENABLED = true
local FISHING_ROD_KEEP_IMPORTED_APPEARANCE = true
local FISHING_ROD_AUTO_COLOR_UNTEXTURED_IMPORTS = true
local LINE_LENGTH = 2.2

local rarityLuckWeight = {
	Common = -0.15,
	Uncommon = 0.15,
	Rare = 0.65,
	Epic = 1.35,
	Legendary = 2.25,
	Mythic = 3.25,
}

local function copyArray(source)
	local result = {}

	for index, value in ipairs(source) do
		if type(value) == "table" then
			local nested = {}
			for key, nestedValue in pairs(value) do
				nested[key] = nestedValue
			end
			result[index] = nested
		else
			result[index] = value
		end
	end

	return result
end

local function shallowCopyMap(source)
	local result = {}

	for key, value in pairs(source) do
		result[key] = value
	end

	return result
end

local function getRodData(data)
	return GameConfig.Rods[data.EquippedRod] or GameConfig.Rods.WoodenRod
end

local function getBiomeData(data)
	return GameConfig.Biomes[data.CurrentBiome] or GameConfig.Biomes.BeginnerPond
end

local function isBiomeUnlocked(data, biomeId)
	return data.UnlockedBiomes[biomeId] == true
end

local function ownsRod(data, rodId)
	return data.OwnedRods[rodId] == true
end

local function normalizeRodId(rodId)
	if rodId == "SteelRod" then
		return "EmeraldRod"
	end

	return rodId
end

local function normalizeOwnedRods(ownedRods)
	if type(ownedRods) ~= "table" then
		return ownedRods
	end

	if ownedRods.SteelRod then
		ownedRods.EmeraldRod = true
		ownedRods.SteelRod = nil
	end

	return ownedRods
end

local function recalcLevel(data)
	local level, progressXP, nextXP = GameConfig.getLevelFromXP(data.XP)
	data.Level = level
	data.LevelProgressXP = progressXP
	data.NextLevelXP = nextXP
end

local function getTotalXPForLevel(level)
	local total = 0
	local targetLevel = math.clamp(level, 1, GameConfig.MAX_LEVEL)

	for currentLevel = 1, targetLevel - 1 do
		total += GameConfig.getXPForNextLevel(currentLevel)
	end

	return total
end

local function getInventoryValue(data)
	local total = 0

	for _, fish in ipairs(data.Inventory) do
		total += fish.value
	end

	return total
end

local function syncFishSerials(data)
	for _, fish in ipairs(data.Inventory) do
		local serial = tonumber(fish.serial)
		if serial then
			fishSerial = math.max(fishSerial, serial)
		else
			fishSerial += 1
			fish.serial = fishSerial
		end
	end
end

local function makeClientState(data)
	recalcLevel(data)

	return {
		Coins = data.Coins,
		XP = data.XP,
		Level = data.Level,
		LevelProgressXP = data.LevelProgressXP,
		NextLevelXP = data.NextLevelXP,
		Inventory = copyArray(data.Inventory),
		BackpackSize = data.BackpackSize,
		InventoryValue = getInventoryValue(data),
		OwnedRods = shallowCopyMap(data.OwnedRods),
		EquippedRod = data.EquippedRod,
		UnlockedBiomes = shallowCopyMap(data.UnlockedBiomes),
		CurrentBiome = data.CurrentBiome,
		AutoFishEnabled = data.AutoFishEnabled,
		Fishdex = shallowCopyMap(data.Fishdex),
		FishdexTotal = GameConfig.getFishCount(),
		Aquarium = {
			Level = data.Aquarium.Level,
			Capacity = GameConfig.AquariumCapacities[data.Aquarium.Level],
			Fish = copyArray(data.Aquarium.Fish),
		},
		BestCatch = data.BestCatch,
	}
end

local function sendState(player)
	local data = playerData[player]
	if not data then
		return
	end

	StateUpdated:FireClient(player, makeClientState(data))
end

local function notify(player, message)
	Notice:FireClient(player, message)
end

local function makeDefaultData()
	local data = {
		Coins = TESTING_START_COINS,
		XP = getTotalXPForLevel(TESTING_START_LEVEL),
		Level = 1,
		LevelProgressXP = 0,
		NextLevelXP = GameConfig.getXPForNextLevel(1),
		Inventory = {},
		BackpackSize = GameConfig.BASE_BACKPACK_SIZE,
		OwnedRods = {
			WoodenRod = true,
		},
		EquippedRod = "WoodenRod",
		UnlockedBiomes = {
			BeginnerPond = true,
		},
		CurrentBiome = "BeginnerPond",
		AutoFishEnabled = false,
		Fishdex = {},
		Aquarium = {
			Level = 1,
			Fish = {},
		},
		BestCatch = nil,
	}

	recalcLevel(data)
	return data
end

local function sanitizeLoadedData(loaded)
	local data = makeDefaultData()

	if type(loaded) ~= "table" then
		return data
	end

	data.Coins = math.max(tonumber(loaded.Coins) or data.Coins, TESTING_START_COINS)
	data.XP = math.max(tonumber(loaded.XP) or data.XP, getTotalXPForLevel(TESTING_START_LEVEL))
	data.Inventory = type(loaded.Inventory) == "table" and loaded.Inventory or data.Inventory
	syncFishSerials(data)
	data.BackpackSize = tonumber(loaded.BackpackSize) or data.BackpackSize
	data.OwnedRods = normalizeOwnedRods(type(loaded.OwnedRods) == "table" and loaded.OwnedRods or data.OwnedRods)

	local equippedRod = normalizeRodId(loaded.EquippedRod)
	data.EquippedRod = GameConfig.Rods[equippedRod] and equippedRod or data.EquippedRod
	data.UnlockedBiomes = type(loaded.UnlockedBiomes) == "table" and loaded.UnlockedBiomes or data.UnlockedBiomes
	data.CurrentBiome = GameConfig.Biomes[loaded.CurrentBiome] and loaded.CurrentBiome or data.CurrentBiome
	data.AutoFishEnabled = loaded.AutoFishEnabled == true
	data.Fishdex = type(loaded.Fishdex) == "table" and loaded.Fishdex or data.Fishdex
	data.Aquarium = type(loaded.Aquarium) == "table" and loaded.Aquarium or data.Aquarium
	data.Aquarium.Level = math.clamp(tonumber(data.Aquarium.Level) or 1, 1, 4)
	data.Aquarium.Fish = type(data.Aquarium.Fish) == "table" and data.Aquarium.Fish or {}
	data.BestCatch = type(loaded.BestCatch) == "table" and loaded.BestCatch or nil

	if not data.OwnedRods.WoodenRod then
		data.OwnedRods.WoodenRod = true
	end

	if not data.UnlockedBiomes.BeginnerPond then
		data.UnlockedBiomes.BeginnerPond = true
	end

	if not ownsRod(data, data.EquippedRod) then
		data.EquippedRod = "WoodenRod"
	end

	if not isBiomeUnlocked(data, data.CurrentBiome) then
		data.CurrentBiome = "BeginnerPond"
	end

	recalcLevel(data)
	return data
end

local function loadData(player)
	local success, loaded = pcall(function()
		return saveStore:GetAsync(tostring(player.UserId))
	end)

	if success then
		return sanitizeLoadedData(loaded)
	end

	warn("Fishy Fish save load failed for", player.UserId, loaded)
	return makeDefaultData()
end

local function saveData(player)
	local data = playerData[player]
	if not data then
		return
	end

	local savePayload = {
		Coins = data.Coins,
		XP = data.XP,
		Inventory = data.Inventory,
		BackpackSize = data.BackpackSize,
		OwnedRods = data.OwnedRods,
		EquippedRod = data.EquippedRod,
		UnlockedBiomes = data.UnlockedBiomes,
		CurrentBiome = data.CurrentBiome,
		AutoFishEnabled = data.AutoFishEnabled,
		Fishdex = data.Fishdex,
		Aquarium = data.Aquarium,
		BestCatch = data.BestCatch,
	}

	local success, err = pcall(function()
		saveStore:SetAsync(tostring(player.UserId), savePayload)
	end)

	if not success then
		warn("Fishy Fish save failed for", player.UserId, err)
	end
end

local function updateLeaderstats(player)
	local data = playerData[player]
	if not data then
		return
	end

	recalcLevel(data)

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local coins = leaderstats:FindFirstChild("Coins")
	local level = leaderstats:FindFirstChild("Level")

	if coins then
		coins.Value = data.Coins
	end

	if level then
		level.Value = data.Level
	end
end

local function setupLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats
end

local function getRodTemplateFolder()
	local folder = ServerStorage:FindFirstChild(ROD_TEMPLATE_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = ROD_TEMPLATE_FOLDER_NAME
		folder.Parent = ServerStorage
	end

	return folder
end

local function prepareStoredRodTemplate(model)
	if model:IsA("BasePart") then
		model.Anchored = true
		model.CanCollide = false
		model.Massless = true
		model.Transparency = 1
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.Massless = true
			descendant.Transparency = 1
		end
	end
end

local function normalizeTemplateName(name)
	return string.lower(name):gsub("[%s_%-]", "")
end

local function getRodIdForTemplate(instance)
	local modelName = normalizeTemplateName(instance.Name)

	for rodId, templateNames in pairs(ROD_TEMPLATE_NAMES_BY_ROD) do
		for _, templateName in ipairs(templateNames) do
			if modelName == normalizeTemplateName(templateName) then
				return rodId
			end
		end
	end

	return nil
end

local function getRodTemplateCandidate(instance)
	if instance:IsA("Model") then
		return instance
	end

	if instance:IsA("BasePart") then
		local ancestor = instance:FindFirstAncestorOfClass("Model")
		if ancestor and getRodIdForTemplate(ancestor) then
			return ancestor
		end

		return instance
	end

	return nil
end

local function storeRodTemplate(template, rodId)
	local folder = getRodTemplateFolder()
	local stored = folder:FindFirstChild(rodId)
	if stored and stored ~= template then
		stored:Destroy()
	end

	local model = template
	if template:IsA("BasePart") then
		model = Instance.new("Model")
		model.Name = rodId
		model.Parent = folder
		template.Parent = model
	end

	model.Name = rodId
	prepareStoredRodTemplate(model)
	model.Parent = folder
	model:PivotTo(CFrame.new(0, -1000, 0))
	return model
end

local function cacheRodTemplates()
	local folder = getRodTemplateFolder()

	for _, container in ipairs({ workspace, ReplicatedStorage }) do
		for rodId, templateNames in pairs(ROD_TEMPLATE_NAMES_BY_ROD) do
			for _, templateName in ipairs(templateNames) do
				local candidate = container:FindFirstChild(templateName, true)
				local template = candidate and getRodTemplateCandidate(candidate)
				if template then
					storeRodTemplate(template, rodId)
					break
				end
			end
		end
	end

	return folder
end

local function watchRodTemplateModels()
	local function tryStore(instance)
		if instance.Name == "RodVisual" or instance:FindFirstAncestorOfClass("Tool") then
			return
		end

		local template = getRodTemplateCandidate(instance)
		if not template then
			return
		end

		local rodId = getRodIdForTemplate(template) or getRodIdForTemplate(instance)
		if rodId then
			storeRodTemplate(template, rodId)
		end
	end

	for _, container in ipairs({ workspace, ReplicatedStorage }) do
		for _, descendant in ipairs(container:GetDescendants()) do
			tryStore(descendant)
		end

		container.DescendantAdded:Connect(function(instance)
			task.defer(tryStore, instance)
		end)
	end
end

local function findRodTemplate(rodId)
	local folder = getRodTemplateFolder()
	cacheRodTemplates()

	for _, container in ipairs({ ServerStorage, ReplicatedStorage, workspace }) do
		for _, templateName in ipairs(ROD_TEMPLATE_NAMES_BY_ROD[rodId] or {}) do
			local candidate = container:FindFirstChild(templateName, true)
			local template = candidate and getRodTemplateCandidate(candidate)
			if template then
				return storeRodTemplate(template, rodId)
			end
		end
	end

	local stored = folder:FindFirstChild(rodId)
	if stored and stored:IsA("Model") then
		return stored
	end

	return nil
end

local function getTemplateLocalBounds(baseParts, pivot)
	local minPoint = Vector3.new(math.huge, math.huge, math.huge)
	local maxPoint = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, part in ipairs(baseParts) do
		local relative = pivot:ToObjectSpace(part.CFrame)
		local halfSize = part.Size * 0.5

		for _, xSign in ipairs({ -1, 1 }) do
			for _, ySign in ipairs({ -1, 1 }) do
				for _, zSign in ipairs({ -1, 1 }) do
					local corner = relative:PointToWorldSpace(Vector3.new(halfSize.X * xSign, halfSize.Y * ySign, halfSize.Z * zSign))
					minPoint = Vector3.new(
						math.min(minPoint.X, corner.X),
						math.min(minPoint.Y, corner.Y),
						math.min(minPoint.Z, corner.Z)
					)
					maxPoint = Vector3.new(
						math.max(maxPoint.X, corner.X),
						math.max(maxPoint.Y, corner.Y),
						math.max(maxPoint.Z, corner.Z)
					)
				end
			end
		end
	end

	return minPoint, maxPoint
end

local function getRodGripPoint(minPoint, maxPoint)
	local size = maxPoint - minPoint
	local center = (minPoint + maxPoint) * 0.5

	if size.X >= size.Y and size.X >= size.Z then
		return Vector3.new(minPoint.X + math.min(ROD_GRIP_INSET, size.X * 0.25), center.Y, center.Z), size.X
	elseif size.Y >= size.X and size.Y >= size.Z then
		return Vector3.new(center.X, minPoint.Y + math.min(ROD_GRIP_INSET, size.Y * 0.25), center.Z), size.Y
	else
		return Vector3.new(center.X, center.Y, minPoint.Z + math.min(ROD_GRIP_INSET, size.Z * 0.25)), size.Z
	end
end

local function getRodTipPoint(minPoint, maxPoint)
	local size = maxPoint - minPoint
	local center = (minPoint + maxPoint) * 0.5

	if size.X >= size.Y and size.X >= size.Z then
		return Vector3.new(maxPoint.X, center.Y, center.Z)
	elseif size.Y >= size.X and size.Y >= size.Z then
		return Vector3.new(center.X, maxPoint.Y, center.Z)
	else
		return Vector3.new(center.X, center.Y, maxPoint.Z)
	end
end

local function getClosestRodPart(baseParts, position)
	local closestPart = nil
	local closestDistance = math.huge

	for _, part in ipairs(baseParts) do
		local distance = (part.Position - position).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closestPart = part
		end
	end

	return closestPart
end

local function getFallbackRodColor(rodId)
	if rodId == "IronRod" then
		return Color3.fromRGB(130, 139, 148), Enum.Material.Metal
	elseif rodId == "EmeraldRod" then
		return Color3.fromRGB(36, 190, 135), Enum.Material.Glass
	elseif rodId == "GoldenRod" then
		return Color3.fromRGB(255, 191, 57), Enum.Material.Metal
	elseif rodId == "OceanRod" then
		return Color3.fromRGB(42, 150, 220), Enum.Material.Glass
	end

	return Color3.fromRGB(126, 78, 42), Enum.Material.Wood
end

local ROD_AUTO_COLOR_PALETTES = {
	WoodenRod = {
		primary = Color3.fromRGB(134, 79, 39),
		secondary = Color3.fromRGB(72, 43, 27),
		accent = Color3.fromRGB(218, 151, 70),
		metal = Color3.fromRGB(42, 46, 50),
		material = Enum.Material.Wood,
	},
	IronRod = {
		primary = Color3.fromRGB(150, 158, 168),
		secondary = Color3.fromRGB(87, 96, 106),
		accent = Color3.fromRGB(205, 215, 225),
		metal = Color3.fromRGB(45, 49, 54),
		material = Enum.Material.Metal,
	},
	EmeraldRod = {
		primary = Color3.fromRGB(26, 198, 139),
		secondary = Color3.fromRGB(10, 98, 77),
		accent = Color3.fromRGB(130, 255, 210),
		metal = Color3.fromRGB(38, 52, 55),
		material = Enum.Material.Glass,
	},
	GoldenRod = {
		primary = Color3.fromRGB(255, 193, 45),
		secondary = Color3.fromRGB(164, 98, 20),
		accent = Color3.fromRGB(255, 236, 127),
		metal = Color3.fromRGB(70, 52, 30),
		material = Enum.Material.Metal,
	},
	OceanRod = {
		primary = Color3.fromRGB(35, 161, 231),
		secondary = Color3.fromRGB(15, 72, 137),
		accent = Color3.fromRGB(112, 237, 255),
		metal = Color3.fromRGB(34, 51, 68),
		material = Enum.Material.Glass,
	},
}

local function hasImportedTexture(part)
	if part:IsA("MeshPart") and part.TextureID ~= "" then
		return true
	end

	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Decal") or child:IsA("Texture") then
			return true
		end

		if child:IsA("SurfaceAppearance") then
			return child.ColorMap ~= ""
				or child.MetalnessMap ~= ""
				or child.NormalMap ~= ""
				or child.RoughnessMap ~= ""
		end
	end

	return false
end

local function isFlatImportedColor(color)
	local maxChannel = math.max(color.R, color.G, color.B)
	local minChannel = math.min(color.R, color.G, color.B)

	return maxChannel - minChannel < 0.045
end

local function shouldAutoColorImportedRodPart(part)
	return FISHING_ROD_AUTO_COLOR_UNTEXTURED_IMPORTS
		and not hasImportedTexture(part)
		and isFlatImportedColor(part.Color)
end

local function autoColorImportedRodPart(part, rodId)
	local palette = ROD_AUTO_COLOR_PALETTES[rodId] or ROD_AUTO_COLOR_PALETTES.WoodenRod
	local name = string.lower(part.Name)

	if string.find(name, "ring") or string.find(name, "reel") or string.find(name, "metal") or string.find(name, "torus") then
		part.Color = palette.metal
		part.Material = Enum.Material.Metal
	elseif string.find(name, "handle") or string.find(name, "grip") then
		part.Color = rodId == "WoodenRod" and palette.accent or Color3.fromRGB(92, 54, 32)
		part.Material = Enum.Material.SmoothPlastic
	elseif string.find(name, "tip") or string.find(name, "line") or string.find(name, "hook") then
		part.Color = palette.accent
		part.Material = Enum.Material.SmoothPlastic
	elseif string.find(name, "dark") or string.find(name, "black") or string.find(name, "base") then
		part.Color = palette.secondary
		part.Material = palette.material
	else
		part.Color = palette.primary
		part.Material = palette.material
	end

	if rodId == "GoldenRod" then
		part.Reflectance = 0.1
	elseif rodId == "EmeraldRod" or rodId == "OceanRod" then
		part.Reflectance = 0.05
	end
end

local function styleRodPart(part, rodId)
	local name = string.lower(part.Name)
	local isUpgradeRod = rodId ~= "WoodenRod"

	part.Transparency = 0
	part.Reflectance = 0

	if string.find(name, "torus") or string.find(name, "ring") or string.find(name, "metal") then
		part.Color = Color3.fromRGB(45, 49, 52)
		part.Material = Enum.Material.Metal
	elseif string.find(name, "sphere") or string.find(name, "handle") or string.find(name, "grip") then
		part.Color = Color3.fromRGB(148, 92, 48)
		part.Material = Enum.Material.SmoothPlastic
	elseif isUpgradeRod then
		local color, material = getFallbackRodColor(rodId)
		part.Color = color
		part.Material = material
		if rodId == "EmeraldRod" or rodId == "OceanRod" then
			part.Reflectance = 0.06
		elseif rodId == "GoldenRod" then
			part.Reflectance = 0.12
		end
	elseif name == "cylinder.001" or name == "cylinder.003" then
		part.Color = Color3.fromRGB(64, 38, 27)
		part.Material = Enum.Material.Wood
	elseif string.find(name, "cylinder") then
		part.Color = Color3.fromRGB(139, 83, 42)
		part.Material = Enum.Material.Wood
	else
		part.Color = Color3.fromRGB(126, 78, 42)
		part.Material = Enum.Material.Wood
	end
end

local function attachRodTemplateToTool(tool, handle, template, rodId)
	local visual = template:Clone()
	visual.Name = "RodVisual"
	visual.Parent = tool

	local baseParts = {}
	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(baseParts, descendant)
		end
	end

	if #baseParts == 0 then
		visual:Destroy()
		return false
	end

	local pivot = visual:GetPivot()
	local minPoint, maxPoint = getTemplateLocalBounds(baseParts, pivot)
	local gripPoint, largestAxis = getRodGripPoint(minPoint, maxPoint)
	local tipPoint = getRodTipPoint(minPoint, maxPoint)
	local scale = 1
	if largestAxis > 0 then
		scale = math.clamp(ROD_VISUAL_LENGTH / largestAxis, 0.01, ROD_MAX_TEMPLATE_SCALE)
	end

	local targetPivot = handle.CFrame * CFrame.new(ROD_VISUAL_OFFSET) * ROD_VISUAL_ROTATION
	local tipWorldPosition = targetPivot:PointToWorldSpace((tipPoint - gripPoint) * scale)

	visual:ScaleTo(scale)
	visual:PivotTo(targetPivot * CFrame.new(gripPoint * -scale))

	for _, part in ipairs(baseParts) do
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true
		part.CanTouch = false
		part.CanQuery = false
		part.Transparency = 0
		if FISHING_ROD_KEEP_IMPORTED_APPEARANCE then
			if shouldAutoColorImportedRodPart(part) then
				autoColorImportedRodPart(part, rodId)
			end
		else
			styleRodPart(part, rodId)
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
	end

	return true, tipWorldPosition, getClosestRodPart(baseParts, tipWorldPosition)
end

local function clearFishingRodVisual(tool)
	for _, child in ipairs(tool:GetChildren()) do
		if
			child.Name == "RodVisual"
			or child.Name == "RodHead"
			or child.Name == "Line"
			or child.Name == "LineConnector"
			or child.Name == "RodTipAnchor"
			or child.Name == "Bobber"
		then
			child:Destroy()
		end
	end
end

local function makeWeld(part0, part1)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part1
	return weld
end

local function addLineAndBobber(tool, handle, rodTipPosition, rodTipPart)
	local lineStart = rodTipPosition or (handle.CFrame * CFrame.new(2.15, -0.3, -0.75)).Position
	local lineEnd = lineStart + Vector3.new(0, -LINE_LENGTH, -0.15)
	local lineDirection = lineEnd - lineStart
	local lineCenter = lineStart + (lineDirection * 0.5)

	local anchor = Instance.new("Part")
	anchor.Name = "RodTipAnchor"
	anchor.Anchored = false
	anchor.CanCollide = false
	anchor.Massless = true
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.12, 0.12, 0.12)
	anchor.CFrame = CFrame.new(lineStart)
	anchor.Parent = tool
	makeWeld(rodTipPart or handle, anchor)

	local connector = Instance.new("Part")
	connector.Name = "LineConnector"
	connector.Anchored = false
	connector.CanCollide = false
	connector.Massless = true
	connector.Shape = Enum.PartType.Ball
	connector.Size = Vector3.new(0.12, 0.12, 0.12)
	connector.Color = Color3.fromRGB(235, 235, 235)
	connector.Material = Enum.Material.SmoothPlastic
	connector.Transparency = 0.05
	connector.CFrame = CFrame.new(lineStart)
	connector.Parent = tool
	makeWeld(anchor, connector)

	local line = Instance.new("Part")
	line.Name = "Line"
	line.Anchored = false
	line.CanCollide = false
	line.Massless = true
	line.Size = Vector3.new(0.035, 0.035, lineDirection.Magnitude)
	line.Color = Color3.fromRGB(235, 235, 235)
	line.Material = Enum.Material.SmoothPlastic
	line.Transparency = 0.12
	line.CFrame = CFrame.lookAt(lineCenter, lineEnd)
	line.Parent = tool
	makeWeld(anchor, line)

	local bobber = Instance.new("Part")
	bobber.Name = "Bobber"
	bobber.Shape = Enum.PartType.Ball
	bobber.Size = Vector3.new(0.3, 0.3, 0.3)
	bobber.Color = Color3.fromRGB(235, 66, 66)
	bobber.Material = Enum.Material.SmoothPlastic
	bobber.CanCollide = false
	bobber.Massless = true
	bobber.CFrame = CFrame.new(lineEnd)
	bobber.Parent = tool
	makeWeld(anchor, bobber)
end

local function applyFishingRodVisual(tool, rodId)
	local rod = GameConfig.Rods[rodId] or GameConfig.Rods.WoodenRod
	tool.TextureId = GameConfig.getRodImage(rodId) or GameConfig.getRodImage("WoodenRod") or ""

	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end

	clearFishingRodVisual(tool)

	if not FISHING_ROD_3D_VISUALS_ENABLED then
		handle.Transparency = 1
		handle.Size = Vector3.new(0.1, 0.1, 0.1)
		handle.CanCollide = false
		handle.CanTouch = false
		handle.CanQuery = false
		handle.Massless = true
		tool:SetAttribute("RodId", rodId)
		tool.ToolTip = rod.displayName
		return
	end

	local templateRodId = USE_WOODEN_ROD_SHAPE_FOR_ALL_RODS and "WoodenRod" or rodId
	local template = FISHING_ROD_IMPORTED_MODELS_ENABLED and findRodTemplate(templateRodId) or nil
	local rodTipPosition = nil
	local rodTipPart = nil
	local attached = false

	handle.Size = Vector3.new(0.3, 3.9, 0.3)
	handle.CanCollide = false
	handle.Massless = true

	if template then
		handle.Transparency = 1
		attached, rodTipPosition, rodTipPart = attachRodTemplateToTool(tool, handle, template, rodId)
	end

	if not attached then
		local color, material = getFallbackRodColor(rodId)
		handle.Transparency = 0
		handle.Size = Vector3.new(0.22, 4.35, 0.22)
		handle.Color = color
		handle.Material = material
		handle.CanTouch = false
		handle.CanQuery = false
		if handle:IsA("Part") then
			handle.Shape = Enum.PartType.Cylinder
		end
	end

	tool:SetAttribute("RodId", rodId)
	tool.ToolTip = rod.displayName
end

local function createFishingRodTool()
	local existing = StarterPack:FindFirstChild("Fishing Rod")
	if existing then
		existing:Destroy()
	end

	if not FISHING_ROD_TOOLS_ENABLED then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = "Fishing Rod"
	tool.RequiresHandle = true
	tool.ToolTip = "Use the UI to fish in unlocked biomes."
	tool.Grip = CFrame.new(0, -0.04, -0.05) * CFrame.Angles(math.rad(6), math.rad(2), math.rad(-4))

	local handle
	if WOODEN_ROD_MESH_ID ~= "" then
		handle = Instance.new("MeshPart")
		handle.MeshId = WOODEN_ROD_MESH_ID
	else
		handle = Instance.new("Part")
		handle.Shape = Enum.PartType.Cylinder
	end

	handle.Name = "Handle"
	handle.CFrame = CFrame.Angles(0, 0, math.rad(90))
	handle.Parent = tool

	applyFishingRodVisual(tool, "WoodenRod")
	tool.Parent = StarterPack
end

local function refreshFishingRodForPlayer(player, data)
	if not FISHING_ROD_TOOLS_ENABLED then
		for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
			if container then
				local tool = container:FindFirstChild("Fishing Rod")
				if tool then
					tool:Destroy()
				end
			end
		end
		return
	end

	local rodId = data.EquippedRod
	if not GameConfig.Rods[rodId] then
		rodId = "WoodenRod"
	end

	for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		if container then
			local tool = container:FindFirstChild("Fishing Rod")
			if tool and tool:IsA("Tool") then
				applyFishingRodVisual(tool, rodId)
			end
		end
	end
end

local function createLabel(part, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 45
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

local function makePart(parent, name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function buildCleanLobby(world)
	local block = 4
	local center = Vector3.new(-180, 0, 0)
	local portalCooldowns = {}

	local lobby = Instance.new("Model")
	lobby.Name = "CleanFishingLobby"
	lobby.Parent = world

	local blocksFolder = Instance.new("Folder")
	blocksFolder.Name = "Blocks"
	blocksFolder.Parent = lobby

	local pathFolder = Instance.new("Folder")
	pathFolder.Name = "Paths"
	pathFolder.Parent = lobby

	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decorations"
	decorFolder.Parent = lobby

	local portalFolder = Instance.new("Folder")
	portalFolder.Name = "Portals"
	portalFolder.Parent = lobby

	local shopFolder = Instance.new("Folder")
	shopFolder.Name = "Shops"
	shopFolder.Parent = lobby

	local spawnFolder = Instance.new("Folder")
	spawnFolder.Name = "Spawn"
	spawnFolder.Parent = lobby

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = lobby

	local function localPosition(position)
		return center + position
	end

	local function makeLobbyPart(parent, name, size, position, color, material, transparency, canCollide)
		local part = makePart(parent, name, size, localPosition(position), color, material)
		part.Transparency = transparency or 0
		part.CanCollide = canCollide ~= false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		return part
	end

	local function makeBlock(parent, name, gridX, gridY, gridZ, color, material)
		return makeLobbyPart(
			parent,
			name,
			Vector3.new(block, block, block),
			Vector3.new(gridX * block, gridY * block, gridZ * block),
			color,
			material
		)
	end

	local function makeSign(parent, name, position, size, textValue, boardColor, face)
		local sign = makeLobbyPart(parent, name, size, position, boardColor, Enum.Material.Wood)

		local gui = Instance.new("SurfaceGui")
		gui.Name = name .. "_Gui"
		gui.Face = face or Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(600, 260)
		gui.Parent = sign

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = textValue
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.TextStrokeTransparency = 0
		text.TextStrokeColor3 = Color3.fromRGB(20, 40, 90)
		text.Font = Enum.Font.FredokaOne
		text.Parent = gui

		return sign
	end

	local grassColor = Color3.fromRGB(92, 172, 64)
	local grassDark = Color3.fromRGB(65, 135, 50)
	local dirtColor = Color3.fromRGB(105, 72, 42)
	local pathColor = Color3.fromRGB(155, 108, 62)
	local stoneColor = Color3.fromRGB(120, 120, 120)
	local stoneDark = Color3.fromRGB(84, 84, 84)
	local waterColor = Color3.fromRGB(45, 145, 225)
	local woodColor = Color3.fromRGB(135, 85, 45)
	local woodDark = Color3.fromRGB(90, 55, 28)
	local blueUI = Color3.fromRGB(20, 130, 255)
	local greenUI = Color3.fromRGB(35, 220, 75)
	local goldUI = Color3.fromRGB(255, 190, 45)
	local cyanUI = Color3.fromRGB(0, 220, 255)
	local purpleUI = Color3.fromRGB(150, 95, 230)

	local function makeLantern(position)
		makeLobbyPart(decorFolder, "LanternPost", Vector3.new(0.8, 5, 0.8), position, woodDark, Enum.Material.Wood)

		local lantern = makeLobbyPart(
			decorFolder,
			"Lantern",
			Vector3.new(1.4, 1.4, 1.4),
			position + Vector3.new(0, 3.2, 0),
			Color3.fromRGB(255, 220, 120),
			Enum.Material.Neon,
			0.05,
			false
		)

		local light = Instance.new("PointLight")
		light.Brightness = 1.3
		light.Range = 16
		light.Color = Color3.fromRGB(255, 225, 160)
		light.Parent = lantern
	end

	local function makeTree(x, z)
		makeLobbyPart(decorFolder, "TreeTrunk", Vector3.new(3, 12, 3), Vector3.new(x, 8, z), Color3.fromRGB(105, 65, 35), Enum.Material.Wood)
		makeLobbyPart(decorFolder, "TreeLeaves", Vector3.new(11, 8, 11), Vector3.new(x, 18, z), Color3.fromRGB(60, 150, 55), Enum.Material.Grass)
		makeLobbyPart(decorFolder, "TreeLeavesTop", Vector3.new(7, 5, 7), Vector3.new(x, 24, z), Color3.fromRGB(60, 150, 55), Enum.Material.Grass)
	end

	local function connectPortal(trigger, targetArea)
		trigger.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end

			local now = os.clock()
			if portalCooldowns[player] and now - portalCooldowns[player] < 1.5 then
				return
			end
			portalCooldowns[player] = now

			local data = playerData[player]
			if not data then
				return
			end

			if GameConfig.Biomes[targetArea] and not isBiomeUnlocked(data, targetArea) then
				notify(player, "Unlock that area first.")
				return
			end

			local root = character:FindFirstChild("HumanoidRootPart")
			local target = GameConfig.Biomes[targetArea]
			if root and target then
				data.CurrentBiome = targetArea
				sendState(player)
				root.CFrame = CFrame.new(target.position)
			end
		end)
	end

	local function makePortal(name, position, color, textValue, targetArea, requiredLevel)
		makeLobbyPart(portalFolder, name .. "_Base", Vector3.new(14, 1, 8), position, Color3.fromRGB(75, 75, 75), Enum.Material.Cobblestone)
		makeLobbyPart(portalFolder, name .. "_Pad", Vector3.new(11, 0.35, 5), position + Vector3.new(0, 0.7, 0), color, Enum.Material.Neon, 0.1, false)
		makeLobbyPart(portalFolder, name .. "_LeftPost", Vector3.new(1.2, 8, 1.2), position + Vector3.new(-6, 4.3, 0), Color3.fromRGB(25, 70, 150), Enum.Material.SmoothPlastic)
		makeLobbyPart(portalFolder, name .. "_RightPost", Vector3.new(1.2, 8, 1.2), position + Vector3.new(6, 4.3, 0), Color3.fromRGB(25, 70, 150), Enum.Material.SmoothPlastic)
		makeLobbyPart(portalFolder, name .. "_TopBeam", Vector3.new(14, 1.2, 1.2), position + Vector3.new(0, 8.4, 0), Color3.fromRGB(25, 70, 150), Enum.Material.SmoothPlastic)

		local trigger = makeLobbyPart(portalFolder, name .. "_Trigger", Vector3.new(12, 8, 6), position + Vector3.new(0, 4, 0), color, Enum.Material.ForceField, 1, false)
		trigger:SetAttribute("TargetArea", targetArea)
		trigger:SetAttribute("RequiredLevel", requiredLevel)
		trigger:SetAttribute("PortalName", textValue)
		CollectionService:AddTag(trigger, "AreaPortal")
		connectPortal(trigger, targetArea)

		makeSign(portalFolder, name .. "_Sign", position + Vector3.new(0, 10.4, -0.8), Vector3.new(14, 4, 0.5), textValue .. "\nLv. " .. tostring(requiredLevel) .. "+", blueUI, Enum.NormalId.Front)
		return trigger
	end

	local function makeShopStand(name, position, titleText, color)
		makeLobbyPart(shopFolder, name .. "_Counter", Vector3.new(16, 4, 8), position, woodColor, Enum.Material.WoodPlanks)
		makeLobbyPart(shopFolder, name .. "_BackWall", Vector3.new(18, 10, 1), position + Vector3.new(0, 5, 4.5), woodDark, Enum.Material.Wood)
		makeLobbyPart(shopFolder, name .. "_Roof", Vector3.new(20, 1.5, 11), position + Vector3.new(0, 10.8, 0), color, Enum.Material.SmoothPlastic)
		makeSign(shopFolder, name .. "_Sign", position + Vector3.new(0, 8.2, -4.3), Vector3.new(15, 3, 0.5), titleText, color, Enum.NormalId.Front)
	end

	for x = -18, 18 do
		for z = -18, 18 do
			makeBlock(blocksFolder, "GrassBlock", x, 0, z, grassColor, Enum.Material.Grass)
			makeBlock(blocksFolder, "DirtBlock", x, -1, z, dirtColor, Enum.Material.Ground)
		end
	end

	for _, p in ipairs({
		{ -18, -18 }, { -17, -18 }, { -18, -17 }, { 18, -18 }, { 17, -18 }, { 18, -17 },
		{ -18, 18 }, { -17, 18 }, { -18, 17 }, { 18, 18 }, { 17, 18 }, { 18, 17 },
		{ -10, 17 }, { 10, 17 }, { -10, -17 }, { 10, -17 },
	}) do
		makeBlock(blocksFolder, "RaisedGrassBlock", p[1], 1, p[2], grassDark, Enum.Material.Grass)
	end

	for x = -6, 6 do
		for z = -6, 6 do
			local color = stoneColor
			if (x + z) % 2 == 0 then
				color = stoneDark
			end
			makeLobbyPart(blocksFolder, "SpawnPlazaTile", Vector3.new(block, 0.5, block), Vector3.new(x * block, 2.25, z * block), color, Enum.Material.Cobblestone)
		end
	end

	for x = -2, 2 do
		for z = -2, 2 do
			makeLobbyPart(decorFolder, "LobbyFountainWater", Vector3.new(block, 0.5, block), Vector3.new(x * block, 2.75, z * block), waterColor, Enum.Material.Glass, 0.35, false)
		end
	end

	for x = -3, 3 do
		for z = -3, 3 do
			if math.abs(x) == 3 or math.abs(z) == 3 then
				makeLobbyPart(decorFolder, "FountainStoneBorder", Vector3.new(block, 1.2, block), Vector3.new(x * block, 3, z * block), stoneColor, Enum.Material.Cobblestone)
			end
		end
	end

	makeLobbyPart(decorFolder, "FountainCore", Vector3.new(4, 6, 4), Vector3.new(0, 5.5, 0), stoneDark, Enum.Material.Cobblestone)
	local fountainTop = makeLobbyPart(decorFolder, "FountainTopWater", Vector3.new(2.5, 2.5, 2.5), Vector3.new(0, 9.8, 0), waterColor, Enum.Material.Neon, 0.2, false)
	local fountainLight = Instance.new("PointLight")
	fountainLight.Brightness = 1
	fountainLight.Range = 20
	fountainLight.Color = Color3.fromRGB(80, 190, 255)
	fountainLight.Parent = fountainTop

	local lobbyZone = makeLobbyPart(zonesFolder, "LobbyZone", Vector3.new(70, 20, 70), Vector3.new(0, 8, 0), Color3.fromRGB(0, 255, 255), Enum.Material.ForceField, 1, false)
	lobbyZone:SetAttribute("AreaName", "Lobby")
	CollectionService:AddTag(lobbyZone, "LobbyZone")

	for x = -18, 18 do
		for z = -1, 1 do
			makeLobbyPart(pathFolder, "MainPathEastWest", Vector3.new(block, 0.25, block), Vector3.new(x * block, 2.55, z * block), pathColor, Enum.Material.Ground)
		end
	end

	for z = -18, 18 do
		for x = -1, 1 do
			makeLobbyPart(pathFolder, "MainPathNorthSouth", Vector3.new(block, 0.25, block), Vector3.new(x * block, 2.55, z * block), pathColor, Enum.Material.Ground)
		end
	end

	for x = -15, 15 do
		makeLobbyPart(pathFolder, "OuterPathNorth", Vector3.new(block, 0.25, block), Vector3.new(x * block, 2.55, -15 * block), pathColor, Enum.Material.Ground)
		makeLobbyPart(pathFolder, "OuterPathSouth", Vector3.new(block, 0.25, block), Vector3.new(x * block, 2.55, 15 * block), pathColor, Enum.Material.Ground)
	end

	for z = -15, 15 do
		makeLobbyPart(pathFolder, "OuterPathWest", Vector3.new(block, 0.25, block), Vector3.new(-15 * block, 2.55, z * block), pathColor, Enum.Material.Ground)
		makeLobbyPart(pathFolder, "OuterPathEast", Vector3.new(block, 0.25, block), Vector3.new(15 * block, 2.55, z * block), pathColor, Enum.Material.Ground)
	end

	makePortal("BeginnerPondPortal", Vector3.new(0, 3, -16 * block), greenUI, "Beginner Pond", "BeginnerPond", 1)
	makePortal("RiverPortal", Vector3.new(16 * block, 3, 0), blueUI, "River", "River", GameConfig.Biomes.River.unlockLevel)
	makePortal("OceanPortal", Vector3.new(0, 3, 16 * block), cyanUI, "Ocean", "Ocean", GameConfig.Biomes.Ocean.unlockLevel)
	makePortal("ComingSoonPortal", Vector3.new(-16 * block, 3, 0), purpleUI, "Coming Soon", "ComingSoon", 999)

	makeShopStand("RodShop", Vector3.new(-11 * block, 4, -10 * block), "ROD SHOP", goldUI)
	makeShopStand("SellFishStand", Vector3.new(11 * block, 4, -10 * block), "SELL FISH", blueUI)

	makeLobbyPart(decorFolder, "LeaderboardLeftPost", Vector3.new(1, 8, 1), Vector3.new(-9 * block, 6, 15.5 * block), woodDark, Enum.Material.Wood)
	makeLobbyPart(decorFolder, "LeaderboardRightPost", Vector3.new(1, 8, 1), Vector3.new(-3 * block, 6, 15.5 * block), woodDark, Enum.Material.Wood)
	makeSign(decorFolder, "LeaderboardBoard", Vector3.new(-6 * block, 8.5, 15.5 * block), Vector3.new(24, 10, 0.7), "TOP FISHERS\n1. ---\n2. ---\n3. ---", blueUI, Enum.NormalId.Front)

	makeLobbyPart(decorFolder, "TutorialLeftPost", Vector3.new(1, 8, 1), Vector3.new(3 * block, 6, 15.5 * block), woodDark, Enum.Material.Wood)
	makeLobbyPart(decorFolder, "TutorialRightPost", Vector3.new(1, 8, 1), Vector3.new(9 * block, 6, 15.5 * block), woodDark, Enum.Material.Wood)
	makeSign(decorFolder, "TutorialBoard", Vector3.new(6 * block, 8.5, 15.5 * block), Vector3.new(24, 10, 0.7), "HOW TO FISH\n1. Equip Rod\n2. Cast Rod\n3. Click Catch!", greenUI, Enum.NormalId.Front)

	for _, pos in ipairs({
		Vector3.new(-7 * block, 5, -7 * block), Vector3.new(7 * block, 5, -7 * block),
		Vector3.new(-7 * block, 5, 7 * block), Vector3.new(7 * block, 5, 7 * block),
		Vector3.new(0, 5, -12 * block), Vector3.new(12 * block, 5, 0),
		Vector3.new(0, 5, 12 * block), Vector3.new(-12 * block, 5, 0),
	}) do
		makeLantern(pos)
	end

	makeTree(-68, -68)
	makeTree(68, -68)
	makeTree(-68, 68)
	makeTree(68, 68)
	makeTree(-36, -70)
	makeTree(36, -70)
	makeTree(-36, 70)
	makeTree(36, 70)

	for _, flower in ipairs({
		{ -13, -5, Color3.fromRGB(245, 245, 230) }, { -12, -5, Color3.fromRGB(245, 210, 65) },
		{ 13, -5, Color3.fromRGB(245, 245, 230) }, { 12, -5, Color3.fromRGB(245, 210, 65) },
		{ -13, 5, Color3.fromRGB(245, 210, 65) }, { -12, 5, Color3.fromRGB(245, 245, 230) },
		{ 13, 5, Color3.fromRGB(245, 210, 65) }, { 12, 5, Color3.fromRGB(245, 245, 230) },
		{ -5, -13, Color3.fromRGB(245, 245, 230) }, { 5, -13, Color3.fromRGB(245, 210, 65) },
		{ -5, 13, Color3.fromRGB(245, 210, 65) }, { 5, 13, Color3.fromRGB(245, 245, 230) },
	}) do
		local x, z, color = flower[1], flower[2], flower[3]
		makeLobbyPart(decorFolder, "FlowerStem", Vector3.new(0.35, 1.2, 0.35), Vector3.new(x * block, 3.25, z * block), grassDark, Enum.Material.Grass, 0, false)
		makeLobbyPart(decorFolder, "FlowerTop", Vector3.new(1, 0.35, 1), Vector3.new(x * block, 4, z * block), color, Enum.Material.SmoothPlastic, 0, false)
	end

	for _, bench in ipairs({
		{ 0, -10, 0 }, { 0, 10, 180 }, { -10, 0, 90 }, { 10, 0, -90 },
	}) do
		local x, z, rotY = bench[1], bench[2], bench[3]
		local seat = makeLobbyPart(decorFolder, "BenchSeat", Vector3.new(10, 1, 2), Vector3.new(x * block, 3.4, z * block), woodColor, Enum.Material.Wood)
		seat.Orientation = Vector3.new(0, rotY, 0)
		local back = makeLobbyPart(decorFolder, "BenchBack", Vector3.new(10, 3, 1), Vector3.new(x * block, 5, z * block + 1.6), woodDark, Enum.Material.Wood)
		back.Orientation = Vector3.new(0, rotY, 0)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = localPosition(Vector3.new(0, 3.2, 8))
	spawn.Anchored = true
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Color = Color3.fromRGB(145, 95, 50)
	spawn.Neutral = true
	spawn.Parent = spawnFolder

	makeLobbyPart(decorFolder, "MainSignPost", Vector3.new(1, 6, 1), Vector3.new(0, 5, -8 * block), woodDark, Enum.Material.Wood)
	makeSign(decorFolder, "MainLobbySign", Vector3.new(0, 9, -8.2 * block), Vector3.new(22, 5, 0.5), "FISHING LOBBY", blueUI, Enum.NormalId.Front)

	lobby.PrimaryPart = lobbyZone
	return lobby
end

local function makeRotatedPart(parent, name, size, cframe, color, material)
	local part = makePart(parent, name, size, cframe.Position, color, material)
	part.CFrame = cframe
	return part
end

local function makeCylinder(parent, name, size, cframe, color, material)
	local part = makeRotatedPart(parent, name, size, cframe, color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function makePondWall(parent, name, center, size)
	local stone = Color3.fromRGB(210, 216, 222)
	local thickness = 2
	local height = 3

	makePart(parent, name .. " NorthWall", Vector3.new(size.X + thickness, height, thickness), center + Vector3.new(0, height / 2, -size.Z / 2), stone, Enum.Material.Slate)
	makePart(parent, name .. " SouthWall", Vector3.new(size.X + thickness, height, thickness), center + Vector3.new(0, height / 2, size.Z / 2), stone, Enum.Material.Slate)
	makePart(parent, name .. " WestWall", Vector3.new(thickness, height, size.Z + thickness), center + Vector3.new(-size.X / 2, height / 2, 0), stone, Enum.Material.Slate)
	makePart(parent, name .. " EastWall", Vector3.new(thickness, height, size.Z + thickness), center + Vector3.new(size.X / 2, height / 2, 0), stone, Enum.Material.Slate)
end

local function makeBench(parent, name, position, rotationY)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(rotationY or 0), 0)
	local wood = Color3.fromRGB(151, 104, 58)
	local dark = Color3.fromRGB(74, 55, 38)

	makeRotatedPart(parent, name .. " Seat", Vector3.new(9, 0.6, 2), base, wood, Enum.Material.WoodPlanks)
	makeRotatedPart(parent, name .. " Back", Vector3.new(9, 2, 0.6), base * CFrame.new(0, 1.15, 1), wood, Enum.Material.WoodPlanks)
	makeRotatedPart(parent, name .. " LeftLeg", Vector3.new(0.45, 1.2, 0.45), base * CFrame.new(-3.5, -0.8, -0.55), dark, Enum.Material.Wood)
	makeRotatedPart(parent, name .. " RightLeg", Vector3.new(0.45, 1.2, 0.45), base * CFrame.new(3.5, -0.8, -0.55), dark, Enum.Material.Wood)
end

local function makeLamp(parent, name, position)
	local postColor = Color3.fromRGB(80, 82, 86)
	local lightColor = Color3.fromRGB(255, 235, 170)
	makePart(parent, name .. " Post", Vector3.new(1, 8, 1), position + Vector3.new(0, 4, 0), postColor, Enum.Material.Metal)
	local lamp = makePart(parent, name .. " Light", Vector3.new(2.2, 2.2, 2.2), position + Vector3.new(0, 8.7, 0), lightColor, Enum.Material.Neon)

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 1.5
	pointLight.Range = 20
	pointLight.Color = lightColor
	pointLight.Parent = lamp
end

local function makeLily(parent, name, position, scale)
	local size = scale or 1
	local pad = makeCylinder(parent, name .. " Pad", Vector3.new(0.22, 2.4 * size, 2.4 * size), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(55, 150, 66), Enum.Material.Grass)
	pad.Transparency = 0.03

	local flower = makePart(parent, name .. " Flower", Vector3.new(0.7 * size, 0.25, 0.7 * size), position + Vector3.new(0, 0.3, 0), Color3.fromRGB(245, 142, 210), Enum.Material.Neon)
	flower.Shape = Enum.PartType.Ball
end

local function makeHedge(parent, name, position, size)
	local hedge = makePart(parent, name, size, position, Color3.fromRGB(42, 116, 56), Enum.Material.Grass)
	hedge.TopSurface = Enum.SurfaceType.Smooth
	hedge.BottomSurface = Enum.SurfaceType.Smooth
	return hedge
end

local function buildBeginnerPond(parent, biome)
	local pos = biome.position
	local center = Vector3.new(pos.X, 0, pos.Z)

	makePart(parent, "Beginner Pond Park Grass", Vector3.new(118, 2, 104), center + Vector3.new(0, -1, 0), Color3.fromRGB(96, 166, 92), Enum.Material.Grass)

	local pathColor = Color3.fromRGB(183, 101, 84)
	makePart(parent, "Beginner Pond Front Brick Path", Vector3.new(118, 0.4, 8), center + Vector3.new(0, 0.18, -43), pathColor, Enum.Material.Brick)
	makePart(parent, "Beginner Pond Center Brick Path", Vector3.new(8, 0.4, 62), center + Vector3.new(-26, 0.2, -13), pathColor, Enum.Material.Brick)

	local mainWaterCenter = center + Vector3.new(16, 0.15, 8)
	local mainWaterSize = Vector3.new(70, 1, 48)
	local water = makePart(parent, "Beginner Pond Water", mainWaterSize, mainWaterCenter, biome.color, Enum.Material.Water)
	water.Transparency = 0.14
	makePondWall(parent, "Beginner Pond", mainWaterCenter, Vector3.new(74, 0, 52))

	local smallWaterCenter = center + Vector3.new(-26, 0.18, 12)
	local smallWater = makePart(parent, "Beginner Side Pond Water", Vector3.new(24, 1, 28), smallWaterCenter, Color3.fromRGB(83, 170, 178), Enum.Material.Water)
	smallWater.Transparency = 0.16
	makePondWall(parent, "Beginner Side Pond", smallWaterCenter, Vector3.new(28, 0, 32))

	local pavilionBase = center + Vector3.new(-32, 0, -24)
	makePart(parent, "Beginner Pavilion Floor", Vector3.new(26, 2, 20), pavilionBase + Vector3.new(0, 1, 0), Color3.fromRGB(166, 100, 54), Enum.Material.WoodPlanks)
	makePart(parent, "Beginner Pavilion Step 1", Vector3.new(12, 1, 4), pavilionBase + Vector3.new(0, 0.5, 12), Color3.fromRGB(183, 135, 82), Enum.Material.WoodPlanks)
	makePart(parent, "Beginner Pavilion Step 2", Vector3.new(16, 0.8, 4), pavilionBase + Vector3.new(0, 0.4, 16), Color3.fromRGB(183, 135, 82), Enum.Material.WoodPlanks)

	local pillarColor = Color3.fromRGB(206, 98, 58)
	for _, offset in ipairs({
		Vector3.new(-10, 0, -7),
		Vector3.new(10, 0, -7),
		Vector3.new(-10, 0, 7),
		Vector3.new(10, 0, 7),
	}) do
		makePart(parent, "Beginner Pavilion Pillar", Vector3.new(2.4, 12, 2.4), pavilionBase + offset + Vector3.new(0, 8, 0), pillarColor, Enum.Material.Wood)
	end

	makePart(parent, "Beginner Pavilion Rail Left", Vector3.new(2, 3, 14), pavilionBase + Vector3.new(-13, 5, 0), Color3.fromRGB(76, 48, 35), Enum.Material.Wood)
	makePart(parent, "Beginner Pavilion Rail Right", Vector3.new(2, 3, 14), pavilionBase + Vector3.new(13, 5, 0), Color3.fromRGB(76, 48, 35), Enum.Material.Wood)
	makePart(parent, "Beginner Pavilion Rail Back", Vector3.new(24, 3, 2), pavilionBase + Vector3.new(0, 5, -10), Color3.fromRGB(76, 48, 35), Enum.Material.Wood)

	local roofColor = Color3.fromRGB(36, 43, 57)
	makePart(parent, "Beginner Pavilion Roof Lower", Vector3.new(34, 2, 28), pavilionBase + Vector3.new(0, 15, 0), roofColor, Enum.Material.Slate)
	makePart(parent, "Beginner Pavilion Roof Mid", Vector3.new(28, 2, 22), pavilionBase + Vector3.new(0, 17, 0), roofColor, Enum.Material.Slate)
	makePart(parent, "Beginner Pavilion Roof Top", Vector3.new(20, 2, 14), pavilionBase + Vector3.new(0, 19, 0), roofColor, Enum.Material.Slate)
	makePart(parent, "Beginner Pavilion Roof Cap", Vector3.new(10, 1.4, 6), pavilionBase + Vector3.new(0, 21, 0), roofColor, Enum.Material.Slate)

	makePart(parent, "Beginner Pond Dock", Vector3.new(14, 1, 24), center + Vector3.new(0, 1.1, -25), Color3.fromRGB(132, 88, 48), Enum.Material.WoodPlanks)
	makePart(parent, "Beginner Fishing Platform", Vector3.new(16, 1, 8), center + Vector3.new(0, 1.2, -10), Color3.fromRGB(132, 88, 48), Enum.Material.WoodPlanks)

	for index, lilyPosition in ipairs({
		Vector3.new(-5, 1, 7),
		Vector3.new(8, 1, 14),
		Vector3.new(22, 1, 2),
		Vector3.new(34, 1, 17),
		Vector3.new(-33, 1, 8),
		Vector3.new(-20, 1, 20),
		Vector3.new(41, 1, -5),
		Vector3.new(16, 1, 26),
	}) do
		makeLily(parent, "Beginner Lily " .. index, center + lilyPosition, index % 2 == 0 and 0.8 or 1)
	end

	makeBench(parent, "Beginner Bench Left", center + Vector3.new(24, 1.2, -39), 0)
	makeBench(parent, "Beginner Bench Right", center + Vector3.new(42, 1.2, -39), 0)
	makeLamp(parent, "Beginner Lamp Left", center + Vector3.new(-48, 0, -38))
	makeLamp(parent, "Beginner Lamp Right", center + Vector3.new(52, 0, -38))

	makeHedge(parent, "Beginner Hedge Left", center + Vector3.new(-52, 2, -10), Vector3.new(4, 4, 38))
	makeHedge(parent, "Beginner Hedge Front", center + Vector3.new(12, 2, -50), Vector3.new(64, 4, 4))
	makeHedge(parent, "Beginner Flower Bush A", center + Vector3.new(-42, 1, 28), Vector3.new(12, 2, 5))
	makeHedge(parent, "Beginner Flower Bush B", center + Vector3.new(50, 1, 28), Vector3.new(11, 2, 5))

	for index, flowerPos in ipairs({
		Vector3.new(-45, 1.5, -23),
		Vector3.new(-39, 1.5, -18),
		Vector3.new(-48, 1.5, 18),
		Vector3.new(47, 1.5, -18),
		Vector3.new(50, 1.5, 10),
		Vector3.new(38, 1.5, 30),
	}) do
		local flower = makePart(parent, "Beginner Flower " .. index, Vector3.new(1.3, 0.8, 1.3), center + flowerPos, index % 2 == 0 and Color3.fromRGB(245, 214, 88) or Color3.fromRGB(236, 96, 135), Enum.Material.Neon)
		flower.Shape = Enum.PartType.Ball
	end

	local sign = makePart(parent, "Beginner Pond Sign", Vector3.new(22, 8, 1), center + Vector3.new(0, 6, -52), Color3.fromRGB(35, 45, 55), Enum.Material.SmoothPlastic)
	createLabel(sign, "Beginner Pond")
end

local function buildExtraLargeBeginnerPond(parent, biome)
	local block = 4
	local center = Vector3.new(biome.position.X, -2, biome.position.Z)
	local areaName = "Beginner Pond"

	local groundRadiusX = 24
	local groundRadiusZ = 22
	local waterRadiusX = 14
	local waterRadiusZ = 11
	local borderRadiusX = waterRadiusX + 1
	local borderRadiusZ = waterRadiusZ + 1

	local pond = Instance.new("Model")
	pond.Name = "BeginnerPond_ExtraLarge"
	pond.Parent = parent

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
		return makePondPart(
			parentObject,
			name,
			Vector3.new(block, block, block),
			Vector3.new(gridX * block, gridY * block, gridZ * block),
			color,
			material
		)
	end

	local function makeLantern(position)
		local woodDark = Color3.fromRGB(90, 55, 28)

		makePondPart(decorFolder, "LanternPost", Vector3.new(0.8, 4, 0.8), position, woodDark, Enum.Material.Wood)
		local lantern = makePondPart(
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
		local spot = makePondPart(
			spotsFolder,
			name,
			Vector3.new(4, 1, 4),
			position,
			Color3.fromRGB(0, 255, 120),
			Enum.Material.ForceField,
			1,
			false
		)

		spot:SetAttribute("AreaName", areaName)
		spot:SetAttribute("FishPool", "Beginner")
		spot:SetAttribute("FacingDirection", facingDirection)
		CollectionService:AddTag(spot, "FishingSpot")
		return spot
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
			local isPondWater = math.abs(x) <= waterRadiusX and math.abs(z) <= waterRadiusZ

			if isPondWater then
				makeBlock(blocksFolder, "PondFloor", x, -1, z, dirtColor, Enum.Material.Ground)
			else
				makeBlock(blocksFolder, "GrassBlock", x, 0, z, grassColor, Enum.Material.Grass)
				makeBlock(blocksFolder, "DirtBlock", x, -1, z, dirtColor, Enum.Material.Ground)
			end
		end
	end

	for _, pos in ipairs({
		{ -23, -21 }, { -22, -21 }, { -23, -20 }, { -21, -21 }, { -22, -20 },
		{ 23, -21 }, { 22, -21 }, { 23, -20 }, { 21, -21 }, { 22, -20 },
		{ -23, 21 }, { -22, 21 }, { -23, 20 }, { -21, 21 }, { -22, 20 },
		{ 23, 21 }, { 22, 21 }, { 23, 20 }, { 21, 21 }, { 22, 20 },
		{ -12, 21 }, { -11, 21 }, { 11, 21 }, { 12, 21 },
		{ -12, -21 }, { -11, -21 }, { 11, -21 }, { 12, -21 },
		{ -23, 0 }, { -23, 1 }, { 23, 0 }, { 23, -1 },
	}) do
		makeBlock(blocksFolder, "RaisedGrassBlock", pos[1], 1, pos[2], grassDark, Enum.Material.Grass)
	end

	for x = -waterRadiusX, waterRadiusX do
		for z = -waterRadiusZ, waterRadiusZ do
			local water = makePondPart(
				waterFolder,
				"WaterBlock",
				Vector3.new(block, 1.1, block),
				Vector3.new(x * block, 0.55, z * block),
				waterColor,
				Enum.Material.Glass,
				0.35,
				false
			)
			water.Reflectance = 0.08
		end
	end

	for x = -8, 8 do
		for z = -6, 6 do
			makePondPart(
				waterFolder,
				"DeepWaterBlock",
				Vector3.new(block, 0.35, block),
				Vector3.new(x * block, 0.95, z * block),
				deepWaterColor,
				Enum.Material.Glass,
				0.5,
				false
			)
		end
	end

	for x = -borderRadiusX, borderRadiusX do
		for z = -borderRadiusZ, borderRadiusZ do
			local onBorder = math.abs(x) == borderRadiusX or math.abs(z) == borderRadiusZ
			if onBorder then
				makePondPart(
					blocksFolder,
					"StonePondBorder",
					Vector3.new(block, 1.5, block),
					Vector3.new(x * block, 2.75, z * block),
					((x + z) % 2 == 0) and stoneDark or stoneColor,
					Enum.Material.Cobblestone
				)
			end
		end
	end

	for x = 12, 17 do
		for z = -3, 3 do
			makePondPart(dockFolder, "EastDockPlank", Vector3.new(block, 0.6, block), Vector3.new(x * block, 3.35, z * block), woodColor, Enum.Material.WoodPlanks)
		end
	end

	for x = -17, -12 do
		for z = -3, 3 do
			makePondPart(dockFolder, "WestDockPlank", Vector3.new(block, 0.6, block), Vector3.new(x * block, 3.35, z * block), woodColor, Enum.Material.WoodPlanks)
		end
	end

	for x = -3, 3 do
		for z = -16, -11 do
			makePondPart(dockFolder, "NorthDockPlank", Vector3.new(block, 0.6, block), Vector3.new(x * block, 3.35, z * block), woodColor, Enum.Material.WoodPlanks)
		end
	end

	for x = -3, 3 do
		for z = 11, 16 do
			makePondPart(dockFolder, "SouthDockPlank", Vector3.new(block, 0.6, block), Vector3.new(x * block, 3.35, z * block), woodColor, Enum.Material.WoodPlanks)
		end
	end

	local cornerPlatforms = {
		{ 12, 9, "NEPlatform" },
		{ -12, 9, "NWPlatform" },
		{ 12, -9, "SEPlatform" },
		{ -12, -9, "SWPlatform" },
	}

	for _, data in ipairs(cornerPlatforms) do
		local centerX, centerZ, prefix = data[1], data[2], data[3]
		for dx = -1, 1 do
			for dz = -1, 1 do
				makePondPart(
					dockFolder,
					prefix .. "_Plank",
					Vector3.new(block, 0.6, block),
					Vector3.new((centerX + dx) * block, 3.35, (centerZ + dz) * block),
					woodColor,
					Enum.Material.WoodPlanks
				)
			end
		end
	end

	local dockPosts = {}
	local function addPost(x, z)
		table.insert(dockPosts, Vector3.new(x * block, 1.5, z * block))
	end

	for _, x in ipairs({ 12, 17, -12, -17 }) do
		for _, z in ipairs({ -3, 0, 3 }) do
			addPost(x, z)
		end
	end

	for _, z in ipairs({ -16, -11, 11, 16 }) do
		for _, x in ipairs({ -3, 0, 3 }) do
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
		makePondPart(dockFolder, "DockPost", Vector3.new(1, 4.5, 1), pos, woodDark, Enum.Material.Wood)
	end

	for i = -3, 3 do
		addFishingSpot("FishingSpot_East_North_" .. i, Vector3.new(13 * block, 4.1, i * block), "West")
		addFishingSpot("FishingSpot_East_South_" .. i, Vector3.new(16 * block, 4.1, i * block), "West")
		addFishingSpot("FishingSpot_West_North_" .. i, Vector3.new(-13 * block, 4.1, i * block), "East")
		addFishingSpot("FishingSpot_West_South_" .. i, Vector3.new(-16 * block, 4.1, i * block), "East")
		addFishingSpot("FishingSpot_North_Left_" .. i, Vector3.new(i * block, 4.1, -12 * block), "South")
		addFishingSpot("FishingSpot_North_Right_" .. i, Vector3.new(i * block, 4.1, -15 * block), "South")
		addFishingSpot("FishingSpot_South_Left_" .. i, Vector3.new(i * block, 4.1, 12 * block), "North")
		addFishingSpot("FishingSpot_South_Right_" .. i, Vector3.new(i * block, 4.1, 15 * block), "North")
	end

	addFishingSpot("FishingSpot_NE_1", Vector3.new(12 * block, 4.1, 9 * block), "SouthWest")
	addFishingSpot("FishingSpot_NE_2", Vector3.new(13 * block, 4.1, 9 * block), "SouthWest")
	addFishingSpot("FishingSpot_NW_1", Vector3.new(-12 * block, 4.1, 9 * block), "SouthEast")
	addFishingSpot("FishingSpot_NW_2", Vector3.new(-13 * block, 4.1, 9 * block), "SouthEast")
	addFishingSpot("FishingSpot_SE_1", Vector3.new(12 * block, 4.1, -9 * block), "NorthWest")
	addFishingSpot("FishingSpot_SE_2", Vector3.new(13 * block, 4.1, -9 * block), "NorthWest")
	addFishingSpot("FishingSpot_SW_1", Vector3.new(-12 * block, 4.1, -9 * block), "NorthEast")
	addFishingSpot("FishingSpot_SW_2", Vector3.new(-13 * block, 4.1, -9 * block), "NorthEast")

	local pathTiles = {}
	for x = -20, 20 do
		table.insert(pathTiles, { x, 19 })
		table.insert(pathTiles, { x, -19 })
	end

	for z = -19, 19 do
		table.insert(pathTiles, { 20, z })
		table.insert(pathTiles, { -20, z })
	end

	for x = -4, 4 do
		for _, z in ipairs({ 18, 17, -18, -17 }) do
			table.insert(pathTiles, { x, z })
		end
	end

	for z = -4, 4 do
		for _, x in ipairs({ 18, 17, -18, -17 }) do
			table.insert(pathTiles, { x, z })
		end
	end

	for _, p in ipairs(pathTiles) do
		makePondPart(decorFolder, "DirtPath", Vector3.new(block, 0.28, block), Vector3.new(p[1] * block, 2.35, p[2] * block), Color3.fromRGB(150, 105, 60), Enum.Material.Ground)
	end

	for _, basePos in ipairs({
		Vector3.new(-58, 4, -36), Vector3.new(-58, 4, 36),
		Vector3.new(58, 4, -36), Vector3.new(58, 4, 36),
		Vector3.new(-36, 4, -46), Vector3.new(36, 4, -46),
		Vector3.new(-36, 4, 46), Vector3.new(36, 4, 46),
		Vector3.new(0, 4, -46), Vector3.new(0, 4, 46),
		Vector3.new(-58, 4, 0), Vector3.new(58, 4, 0),
		Vector3.new(-48, 4, -16), Vector3.new(48, 4, 16),
		Vector3.new(-16, 4, 40), Vector3.new(16, 4, -40),
	}) do
		for i = 1, 3 do
			local height = 3 + i
			local pos = basePos + Vector3.new((i - 2) * 0.7, height / 2, 0)
			makePondPart(decorFolder, "Reed", Vector3.new(0.45, height, 0.45), pos, reedColor, Enum.Material.Grass)
			makePondPart(decorFolder, "CattailHead", Vector3.new(0.55, 1.1, 0.55), pos + Vector3.new(0, height / 2 + 0.35, 0), Color3.fromRGB(105, 65, 35), Enum.Material.Wood)
		end
	end

	for _, pos in ipairs({
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
	}) do
		makePondPart(decorFolder, "LilyPad", Vector3.new(3, 0.18, 2.2), pos, Color3.fromRGB(45, 150, 55), Enum.Material.Grass, 0, false)
		makePondPart(decorFolder, "LilyFlower", Vector3.new(0.8, 0.25, 0.8), pos + Vector3.new(0.4, 0.2, 0), flowerWhite, Enum.Material.SmoothPlastic, 0, false)
	end

	for _, f in ipairs({
		{ -20, -16, flowerWhite }, { -19, -16, flowerYellow }, { -21, -14, flowerPurple },
		{ 20, -16, flowerYellow }, { 21, -14, flowerPurple },
		{ -20, 16, flowerPurple }, { -19, 17, flowerWhite },
		{ 20, 16, flowerWhite }, { 21, 17, flowerYellow },
		{ -8, 20, flowerPurple }, { 8, -20, flowerWhite },
		{ -22, 5, flowerYellow }, { 22, -5, flowerPurple },
		{ -15, 18, flowerBlue }, { 15, -18, flowerBlue },
		{ -18, -3, flowerWhite }, { 18, 3, flowerYellow },
	}) do
		makePondPart(decorFolder, "FlowerStem", Vector3.new(0.35, 1.2, 0.35), Vector3.new(f[1] * block, 3, f[2] * block), reedColor, Enum.Material.Grass)
		makePondPart(decorFolder, "FlowerTop", Vector3.new(1, 0.35, 1), Vector3.new(f[1] * block, 3.8, f[2] * block), f[3], Enum.Material.SmoothPlastic)
	end

	for _, g in ipairs({
		{ -22, -6 }, { -22, 6 }, { -18, 0 }, { -6, -20 }, { 6, -20 },
		{ 18, 0 }, { 22, 6 }, { -6, 20 }, { 6, 20 },
		{ -18, -18 }, { 18, -18 }, { -18, 18 }, { 18, 18 },
		{ -12, 15 }, { 12, -15 }, { -15, -12 }, { 15, 12 },
	}) do
		makePondPart(decorFolder, "TallGrass", Vector3.new(0.8, 2.2, 0.8), Vector3.new(g[1] * block, 3.2, g[2] * block), grassDark, Enum.Material.Grass, 0, false)
	end

	local function makeTree(x, z)
		makePondPart(decorFolder, "TreeTrunk", Vector3.new(3, 12, 3), Vector3.new(x, 8, z), Color3.fromRGB(100, 65, 35), Enum.Material.Wood)
		makePondPart(decorFolder, "TreeLeaves", Vector3.new(10, 8, 10), Vector3.new(x, 18, z), leafColor, Enum.Material.Grass)
		makePondPart(decorFolder, "TreeLeavesTop", Vector3.new(7, 5, 7), Vector3.new(x, 24, z), leafColor, Enum.Material.Grass)
	end

	for _, treePos in ipairs({
		Vector3.new(-88, 0, -76),
		Vector3.new(88, 0, -76),
		Vector3.new(-88, 0, 76),
		Vector3.new(88, 0, 76),
		Vector3.new(-52, 0, -78),
		Vector3.new(52, 0, 78),
		Vector3.new(0, 0, -82),
		Vector3.new(0, 0, 82),
	}) do
		makeTree(treePos.X, treePos.Z)
	end

	for _, pos in ipairs({
		Vector3.new(-70, 5, -54), Vector3.new(70, 5, -54),
		Vector3.new(-70, 5, 54), Vector3.new(70, 5, 54),
		Vector3.new(62, 5, 14), Vector3.new(62, 5, -14),
		Vector3.new(-62, 5, 14), Vector3.new(-62, 5, -14),
		Vector3.new(-14, 5, -62), Vector3.new(14, 5, -62),
		Vector3.new(-14, 5, 62), Vector3.new(14, 5, 62),
		Vector3.new(80, 5, 0), Vector3.new(-80, 5, 0),
		Vector3.new(0, 5, 72), Vector3.new(0, 5, -72),
	}) do
		makeLantern(pos)
	end

	makePondPart(decorFolder, "SignPost", Vector3.new(1, 5, 1), Vector3.new(-8, 4.5, 86), woodDark, Enum.Material.Wood)
	local signBoard = makePondPart(decorFolder, "BeginnerPondSign", Vector3.new(12, 5, 0.5), Vector3.new(-8, 8, 85.5), woodColor, Enum.Material.Wood)
	createLabel(signBoard, "Beginner\nPond")

	local fishZone = makePondPart(
		zonesFolder,
		"FishZone",
		Vector3.new((waterRadiusX * 2 + 4) * block, 12, (waterRadiusZ * 2 + 4) * block),
		Vector3.new(0, 5, 0),
		Color3.fromRGB(0, 255, 255),
		Enum.Material.ForceField,
		1,
		false
	)

	fishZone:SetAttribute("AreaName", areaName)
	fishZone:SetAttribute("MinLevel", 1)
	fishZone:SetAttribute("FishPool", "Beginner")
	fishZone:SetAttribute("CommonChance", 75)
	fishZone:SetAttribute("UncommonChance", 20)
	fishZone:SetAttribute("RareChance", 5)
	fishZone:SetAttribute("MaxPlayersSuggested", 56)
	CollectionService:AddTag(fishZone, "FishingZone")

	for index, pos in ipairs({
		Vector3.new(-24, 3.2, 90),
		Vector3.new(-12, 3.2, 90),
		Vector3.new(0, 3.2, 90),
		Vector3.new(12, 3.2, 90),
		Vector3.new(24, 3.2, 90),
		Vector3.new(90, 3.2, 0),
		Vector3.new(-90, 3.2, 0),
		Vector3.new(0, 3.2, -90),
	}) do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "BeginnerPondSpawn_" .. index
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = localPosition(pos)
		spawn.Anchored = true
		spawn.Material = Enum.Material.WoodPlanks
		spawn.Color = Color3.fromRGB(145, 95, 50)
		spawn.Parent = pond
	end

	pond.PrimaryPart = fishZone
end

local function buildWorld()
	local existing = workspace:FindFirstChild("FishyFishWorld")
	if existing then
		existing:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "FishyFishWorld"
	world.Parent = workspace

	makePart(world, "WorldGroundLobbyToPond", Vector3.new(37, 2, 90), Vector3.new(-116.5, -1, 0), Color3.fromRGB(74, 126, 66), Enum.Material.Grass)
	makePart(world, "WorldGroundPondToRiver", Vector3.new(29.5, 2, 95), Vector3.new(112.75, -1, 0), Color3.fromRGB(74, 126, 66), Enum.Material.Grass)
	makePart(world, "WorldGroundRiverToOcean", Vector3.new(75, 2, 95), Vector3.new(270, -1, 0), Color3.fromRGB(74, 126, 66), Enum.Material.Grass)
	makePart(world, "WorldGroundBeginnerNorth", Vector3.new(196, 2, 30), Vector3.new(0, -1, -105), Color3.fromRGB(74, 126, 66), Enum.Material.Grass)
	makePart(world, "WorldGroundBeginnerSouth", Vector3.new(196, 2, 30), Vector3.new(0, -1, 105), Color3.fromRGB(74, 126, 66), Enum.Material.Grass)

	buildCleanLobby(world)

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		local pos = biome.position

		if biomeId == "BeginnerPond" then
			buildExtraLargeBeginnerPond(world, biome)
			continue
		end

		makePart(world, biome.displayName .. " Island", Vector3.new(105, 2, 95), Vector3.new(pos.X, -1, pos.Z), Color3.fromRGB(92, 150, 86), Enum.Material.Grass)

		local water = makePart(world, biome.displayName .. " Water", Vector3.new(72, 1, 56), Vector3.new(pos.X, 0.2, pos.Z + 8), biome.color, Enum.Material.Water)
		water.Transparency = 0.2

		local dock = makePart(world, biome.displayName .. " Dock", Vector3.new(16, 1, 28), Vector3.new(pos.X, 1, pos.Z - 29), Color3.fromRGB(121, 79, 43), Enum.Material.WoodPlanks)
		dock.Name = biomeId .. "Dock"

		local sign = makePart(world, biome.displayName .. " Sign", Vector3.new(22, 8, 1), Vector3.new(pos.X, 6, pos.Z - 42), Color3.fromRGB(35, 45, 55), Enum.Material.SmoothPlastic)
		createLabel(sign, biome.displayName)
	end
end

local function ensureWorld()
	if not workspace:FindFirstChild("FishyFishWorld") then
		buildWorld()
	end
end

local function chooseFish(data, timingScore, isAutoFish)
	local biome = getBiomeData(data)
	local rod = getRodData(data)
	local luck = rod.luck + (math.clamp(timingScore, 0, 1) * 0.25)

	if isAutoFish then
		luck = (rod.luck * 0.45) + (math.clamp(timingScore, 0, 1) * 0.06) - 0.12
	end

	local totalWeight = 0
	local weights = {}

	for index, fish in ipairs(biome.fish) do
		local rarityWeight = rarityLuckWeight[fish.rarity] or 0
		local adjusted = fish.chance * math.max(0.05, 1 + (luck * rarityWeight))
		weights[index] = adjusted
		totalWeight += adjusted
	end

	local roll = Random.new():NextNumber(0, totalWeight)
	local current = 0

	for index, fish in ipairs(biome.fish) do
		current += weights[index]
		if roll <= current then
			return fish
		end
	end

	return biome.fish[1]
end

local function awardCatch(player, timingScore, isAutoFish)
	local data = playerData[player]
	if not data then
		return
	end

	if #data.Inventory >= data.BackpackSize then
		notify(player, "Backpack full. Sell fish first.")
		return
	end

	local fish = chooseFish(data, timingScore, isAutoFish)
	local perfectBonus = not isAutoFish and timingScore >= 0.92
	local value = fish.value
	local xp = GameConfig.RarityXP[fish.rarity] or 10

	if perfectBonus then
		value = math.floor(value * 1.15)
		xp = math.floor(xp * 1.35)
	elseif not isAutoFish and timingScore >= 0.7 then
		xp = math.floor(xp * 1.15)
	elseif isAutoFish then
		xp = math.max(1, math.floor(xp * 0.75))
	end

	fishSerial += 1

	local entry = {
		serial = fishSerial,
		id = fish.id,
		name = fish.name,
		rarity = fish.rarity,
		imageKey = fish.imageKey or fish.id,
		value = value,
		baseValue = fish.value,
		biome = data.CurrentBiome,
		score = math.floor(timingScore * 100),
	}

	table.insert(data.Inventory, entry)
	data.Fishdex[fish.id] = (data.Fishdex[fish.id] or 0) + 1
	data.XP += xp

	if not data.BestCatch or value > data.BestCatch.value then
		data.BestCatch = entry
	end

	updateLeaderstats(player)
	sendState(player)

	local prefix = isAutoFish and "Auto caught" or "Caught"
	local message = string.format("%s %s [%s] +%d XP", prefix, fish.name, fish.rarity, xp)
	if perfectBonus then
		message ..= " Perfect!"
	end
	notify(player, message)
end

local function getPlayerRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getBiomeAtPosition(position)
	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		local center = biome.position
		local dx = math.abs(position.X - center.X)
		local dz = math.abs(position.Z - center.Z)
		local rangeX = biomeId == "BeginnerPond" and 100 or 58
		local rangeZ = biomeId == "BeginnerPond" and 96 or 54

		if dx <= rangeX and dz <= rangeZ then
			return biomeId
		end
	end

	return nil
end

local function getPlayerFishingBiome(player)
	local root = getPlayerRoot(player)
	if not root then
		return nil
	end

	return getBiomeAtPosition(root.Position)
end

local function startAutoFish(player)
	local data = playerData[player]
	if not data or data.AutoFishRunning then
		return
	end

	data.AutoFishRunning = true

	task.spawn(function()
		while player.Parent and playerData[player] == data and data.AutoFishEnabled do
			if #data.Inventory >= data.BackpackSize then
				data.AutoFishEnabled = false
				data.AutoFishRunning = false
				pendingFishing[player] = nil
				sendState(player)
				notify(player, "AutoFish stopped. Backpack full.")
				return
			end

			if pendingFishing[player] then
				task.wait(1)
				continue
			end

			local rod = getRodData(data)
			local waitTime = Random.new():NextNumber(AUTO_FISH_MIN_WAIT, AUTO_FISH_MAX_WAIT) * math.max(0.85, rod.speed)
			task.wait(waitTime)

			if not player.Parent or playerData[player] ~= data or not data.AutoFishEnabled then
				break
			end

			if pendingFishing[player] then
				continue
			end

			if #data.Inventory < data.BackpackSize then
				local locationBiomeId = getPlayerFishingBiome(player)
				if not locationBiomeId then
					data.AutoFishEnabled = false
					data.AutoFishRunning = false
					sendState(player)
					notify(player, "AutoFish stopped. Move to Beginner Pond, River, or Ocean to fish.")
					return
				end

				if not isBiomeUnlocked(data, locationBiomeId) then
					data.AutoFishEnabled = false
					data.AutoFishRunning = false
					sendState(player)
					notify(player, "AutoFish stopped. Unlock this biome first.")
					return
				end

				data.CurrentBiome = locationBiomeId

				local score = Random.new():NextNumber(AUTO_FISH_MIN_SCORE, AUTO_FISH_MAX_SCORE)
				local visualTime = 2.4
				pendingFishing[player] = {
					autoFish = true,
					biomeId = locationBiomeId,
				}

				FishingPrompt:FireClient(player, {
					biomeId = locationBiomeId,
					biteDelay = 0.2,
					zoneSize = 0.18,
					markerSpeed = 0.95,
					autoFish = true,
					autoScore = score,
					visualTime = visualTime,
				})

				task.wait(visualTime + 0.25)

				if not player.Parent or playerData[player] ~= data or not data.AutoFishEnabled then
					pendingFishing[player] = nil
					break
				end

				pendingFishing[player] = nil
				awardCatch(player, score, true)
			end
		end

		if playerData[player] == data then
			data.AutoFishRunning = false
			sendState(player)
		end
	end)
end

local function canUnlockBiome(data, biomeId)
	local biome = GameConfig.Biomes[biomeId]
	if not biome then
		return false, "Unknown biome."
	end

	if isBiomeUnlocked(data, biomeId) then
		return false, "Already unlocked."
	end

	if data.Level < biome.unlockLevel then
		return false, "Need level " .. biome.unlockLevel .. "."
	end

	if data.Coins < biome.cost then
		return false, "Need " .. biome.cost .. " coins."
	end

	if biome.requiredRod and not ownsRod(data, biome.requiredRod) then
		return false, "Need " .. GameConfig.Rods[biome.requiredRod].displayName .. "."
	end

	return true, nil
end

local function teleportPlayer(player, target)
	local root = getPlayerRoot(player)
	if not root then
		return
	end

	local position

	if target == "Lobby" then
		position = Vector3.new(-180, 8, 0)
	elseif target == "Home" then
		position = Vector3.new(-205, 8, 18)
	elseif GameConfig.Biomes[target] then
		position = GameConfig.Biomes[target].position
	end

	if position then
		root.CFrame = CFrame.new(position)
	end
end

local function setupPlayer(player)
	ensureWorld()

	playerData[player] = loadData(player)
	setupLeaderstats(player)
	updateLeaderstats(player)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			ensureWorld()
			local data = playerData[player]
			if data then
				refreshFishingRodForPlayer(player, data)
			end
		end)
	end)

	task.defer(function()
		local data = playerData[player]
		ensureWorld()
		sendState(player)
		teleportPlayer(player, "Lobby")
		if data then
			refreshFishingRodForPlayer(player, data)
		end
		if data and data.AutoFishEnabled then
			startAutoFish(player)
		end
	end)
end

GetState.OnServerInvoke = function(player)
	local data = playerData[player]
	if not data then
		return nil
	end

	return makeClientState(data)
end

StartFishing.OnServerEvent:Connect(function(player, requestedBiome)
	local data = playerData[player]
	if not data then
		return
	end

	local biomeId = GameConfig.Biomes[requestedBiome] and requestedBiome or data.CurrentBiome
	local locationBiomeId = getPlayerFishingBiome(player)

	if not locationBiomeId then
		notify(player, "Move to Beginner Pond, River, or Ocean to fish.")
		return
	end

	if requestedBiome and requestedBiome ~= locationBiomeId then
		notify(player, "You can only cast in the biome you are standing in.")
		return
	end

	biomeId = locationBiomeId

	if pendingFishing[player] then
		notify(player, "Already fishing.")
		return
	end

	if not isBiomeUnlocked(data, biomeId) then
		notify(player, "Unlock that biome first.")
		return
	end

	if #data.Inventory >= data.BackpackSize then
		notify(player, "Backpack full. Sell fish first.")
		return
	end

	local rod = getRodData(data)
	local biteDelay = Random.new():NextNumber(2, 5) * rod.speed
	local zoneSize = math.clamp(0.18 + rod.zoneBonus, 0.16, 0.36)

	data.CurrentBiome = biomeId
	pendingFishing[player] = {
		biomeId = biomeId,
		requestedAt = os.clock(),
		biteDelay = biteDelay,
	}

	sendState(player)
	FishingPrompt:FireClient(player, {
		biomeId = biomeId,
		biteDelay = biteDelay,
		zoneSize = zoneSize,
		markerSpeed = math.clamp(1.15 - rod.zoneBonus, 0.8, 1.15),
	})
end)

FinishMinigame.OnServerEvent:Connect(function(player, timingScore)
	local data = playerData[player]
	local pending = pendingFishing[player]
	if not data or not pending then
		return
	end

	if pending.autoFish then
		return
	end

	pendingFishing[player] = nil

	local elapsed = os.clock() - pending.requestedAt
	if elapsed < pending.biteDelay - 0.75 then
		notify(player, "Too early. Wait for the bite.")
		return
	end

	timingScore = math.clamp(tonumber(timingScore) or 0, 0, 1)

	if timingScore <= 0 then
		notify(player, "The fish escaped.")
		sendState(player)
		return
	end

	data.CurrentBiome = pending.biomeId
	awardCatch(player, timingScore)
end)

SellFish.OnServerEvent:Connect(function(player, action, fishSerialToSell, fishIndexToSell)
	local data = playerData[player]
	if not data then
		return
	end

	if action == "Single" then
		local requestedSerial = tonumber(fishSerialToSell)
		local requestedIndex = tonumber(fishIndexToSell)
		local targetIndex = nil

		if requestedIndex and data.Inventory[requestedIndex] then
			local fish = data.Inventory[requestedIndex]
			if not requestedSerial or tonumber(fish.serial) == requestedSerial then
				targetIndex = requestedIndex
			end
		end

		if not targetIndex and requestedSerial then
			for index, fish in ipairs(data.Inventory) do
				if tonumber(fish.serial) == requestedSerial then
					targetIndex = index
					break
				end
			end
		end

		if not targetIndex then
			notify(player, "That fish is no longer in your inventory.")
			sendState(player)
			return
		end

		local fish = table.remove(data.Inventory, targetIndex)
		local value = tonumber(fish.value) or 0
		data.Coins += value

		updateLeaderstats(player)
		sendState(player)
		notify(player, "Sold " .. fish.name .. " for " .. value .. " coins.")
		return
	end

	local total = getInventoryValue(data)
	if total <= 0 then
		notify(player, "No fish to sell.")
		return
	end

	data.Inventory = {}
	data.Coins += total

	updateLeaderstats(player)
	sendState(player)
	notify(player, "Sold fish for " .. total .. " coins.")
end)

BuyRod.OnServerEvent:Connect(function(player, rodId)
	local data = playerData[player]
	local rod = GameConfig.Rods[rodId]
	if not data or not rod then
		return
	end

	if ownsRod(data, rodId) then
		data.EquippedRod = rodId
		refreshFishingRodForPlayer(player, data)
		sendState(player)
		notify(player, "Equipped " .. rod.displayName .. ".")
		return
	end

	if data.Level < rod.unlockLevel then
		notify(player, "Need level " .. rod.unlockLevel .. ".")
		return
	end

	if rod.requiredBiome and not isBiomeUnlocked(data, rod.requiredBiome) then
		notify(player, "Unlock " .. GameConfig.Biomes[rod.requiredBiome].displayName .. " first.")
		return
	end

	if data.Coins < rod.cost then
		notify(player, "Need " .. rod.cost .. " coins.")
		return
	end

	data.Coins -= rod.cost
	data.OwnedRods[rodId] = true
	data.EquippedRod = rodId

	updateLeaderstats(player)
	refreshFishingRodForPlayer(player, data)
	sendState(player)
	notify(player, "Bought " .. rod.displayName .. ".")
end)

UnlockBiome.OnServerEvent:Connect(function(player, biomeId)
	local data = playerData[player]
	if not data then
		return
	end

	local canUnlock, reason = canUnlockBiome(data, biomeId)
	if not canUnlock then
		notify(player, reason)
		return
	end

	local biome = GameConfig.Biomes[biomeId]
	data.Coins -= biome.cost
	data.UnlockedBiomes[biomeId] = true
	data.CurrentBiome = biomeId

	updateLeaderstats(player)
	sendState(player)
	notify(player, "Unlocked " .. biome.displayName .. ".")
end)

TeleportTo.OnServerEvent:Connect(function(player, target)
	local data = playerData[player]
	if not data then
		return
	end

	if GameConfig.Biomes[target] and not isBiomeUnlocked(data, target) then
		notify(player, "Unlock that teleport first.")
		return
	end

	if GameConfig.Biomes[target] then
		data.CurrentBiome = target
		sendState(player)
	end

	teleportPlayer(player, target)
end)

AquariumAction.OnServerEvent:Connect(function(player, action)
	local data = playerData[player]
	if not data then
		return
	end

	if action == "DisplayBest" then
		if not data.BestCatch then
			notify(player, "Catch a fish first.")
			return
		end

		local capacity = GameConfig.AquariumCapacities[data.Aquarium.Level]
		if #data.Aquarium.Fish >= capacity then
			notify(player, "Aquarium full. Upgrade it first.")
			return
		end

		table.insert(data.Aquarium.Fish, data.BestCatch)
		sendState(player)
		notify(player, "Displayed " .. data.BestCatch.name .. " in your aquarium.")
	elseif action == "Upgrade" then
		local nextLevel = data.Aquarium.Level + 1
		local cost = GameConfig.AquariumUpgradeCosts[nextLevel]

		if not cost then
			notify(player, "Aquarium already maxed.")
			return
		end

		if data.Coins < cost then
			notify(player, "Need " .. cost .. " coins.")
			return
		end

		data.Coins -= cost
		data.Aquarium.Level = nextLevel

		updateLeaderstats(player)
		sendState(player)
		notify(player, "Aquarium upgraded to level " .. nextLevel .. ".")
	end
end)

ToggleAutoFish.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then
		return
	end

	if data.AutoFishEnabled then
		data.AutoFishEnabled = false
		pendingFishing[player] = nil
		sendState(player)
		notify(player, "AutoFish turned off.")
		return
	end

	if #data.Inventory >= data.BackpackSize then
		notify(player, "Backpack full. Sell fish first.")
		return
	end

	data.AutoFishEnabled = true
	sendState(player)
	notify(player, "AutoFish turned on. It is slower and has lower rare-fish luck.")
	startAutoFish(player)
end)

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerData[player] = nil
	pendingFishing[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

watchRodTemplateModels()
cacheRodTemplates()
buildWorld()
createFishingRodTool()
