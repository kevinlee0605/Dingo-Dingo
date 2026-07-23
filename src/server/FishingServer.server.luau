local Services = {
	Players = game:GetService("Players"),
	DataStoreService = game:GetService("DataStoreService"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerStorage = game:GetService("ServerStorage"),
	StarterPack = game:GetService("StarterPack"),
	CollectionService = game:GetService("CollectionService"),
	RunService = game:GetService("RunService"),
	TweenService = game:GetService("TweenService"),
}
Services.AquariumDirectory = require(script.Parent:WaitForChild("AquariumDirectoryService"))
Services.AquariumFishAnimator = require(script.Parent:WaitForChild("AquariumFishAnimator"))

local AQUARIUM_DECOR_TEMPLATE_FOLDER_NAME = "AquariumDecorationTemplates"
local AQUARIUM_DECOR_TEMPLATE_LARGEST_AXIS = {
	Coral = 4.2,
	Seaweed = 4.2,
	TreasureChest = 3.8,
	Rocks = 3.4,
	ShipwreckPiece = 4,
	BubbleMachine = 3.4,
	Clams = 3,
	Driftwood = 4.2,
}

require(script.Parent:WaitForChild("EarlyModelMigrationService")).start()
local GameConfig = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local EconomyConfig = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EconomyConfig"))
local ResourceConfig = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ResourceConfig"))
local IslandConfig = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IslandConfig"))
local LoginRewardConfig = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LoginRewardConfig"))
local DailyQuestConfig = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DailyQuestConfig"))
local WeeklyQuestConfig = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeeklyQuestConfig"))
local MonthlyQuestConfig = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonthlyQuestConfig"))

ResourceConfig.Validate(GameConfig)
LoginRewardConfig.Validate()

if Services.RunService:IsStudio() then
	local success, report = pcall(EconomyConfig.ValidateFishEconomy, GameConfig)
	if success then
		for _, islandId in ipairs(GameConfig.IslandOrder) do
			local result = report[islandId]
			print(string.format("[FishyFish Economy] %s tier %d: chances %.2f, weighted value %.2f", islandId, result.tier, result.chanceTotal, result.weightedAverage))
		end
	else
		warn("[FishyFish Economy] Validation failed:", report)
	end
end

local FishingResources = {}

function FishingResources.getRating(castResult)
	local rating = type(castResult) == "table" and castResult.rating or nil
	if ResourceConfig.DropChances[rating] then
		return rating
	end
	return "Weak"
end

function FishingResources.rollForCatch(data, isAutoFish, castResult, dropRoll, resourceRoll)
	if type(data) ~= "table" or not ResourceConfig.GetIslandDropTable(data.CurrentBiome) then
		return nil
	end

	data.ResourceInventory = ResourceConfig.NormalizeInventory(data.ResourceInventory)
	data.ResourcePity = ResourceConfig.NormalizePity(data.ResourcePity)

	local chance = ResourceConfig.GetDropChance(FishingResources.getRating(castResult), isAutoFish)
	local guaranteed = data.ResourcePity >= ResourceConfig.PityMissesBeforeGuarantee
	local resolvedDropRoll = tonumber(dropRoll)
	if resolvedDropRoll == nil then
		resolvedDropRoll = Random.new():NextNumber()
	end

	if not guaranteed and resolvedDropRoll >= chance then
		data.ResourcePity += 1
		return nil
	end

	local resolvedResourceRoll = tonumber(resourceRoll)
	if resolvedResourceRoll == nil then
		resolvedResourceRoll = Random.new():NextNumber()
	end
	local resourceId = ResourceConfig.SelectResource(data.CurrentBiome, resolvedResourceRoll)
	if not resourceId then
		return nil
	end

	data.ResourceInventory[resourceId] += 1
	data.ResourcePity = 0
	return resourceId
end

local Remote = {
	Folder = Services.ReplicatedStorage:WaitForChild("FishingRemotes"),
}

function Remote.getOrCreateEvent(name)
	local remote = Remote.Folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = Remote.Folder
	return remote
end

Remote.StartFishing = Remote.Folder:WaitForChild("StartFishing")
Remote.FinishMinigame = Remote.Folder:WaitForChild("FinishMinigame")
Remote.SellFish = Remote.Folder:WaitForChild("SellFish")
Remote.BuyRod = Remote.Folder:WaitForChild("BuyRod")
Remote.BaitAction = Remote.getOrCreateEvent("BaitAction")
Remote.QuestAction = Remote.getOrCreateEvent("QuestAction")
Remote.LoginRewardAction = Remote.getOrCreateEvent("LoginRewardAction")
Remote.UnlockBiome = Remote.Folder:WaitForChild("UnlockBiome")
Remote.TeleportTo = Remote.Folder:WaitForChild("TeleportTo")
Remote.OpenBiomeWarp = Remote.getOrCreateEvent("OpenBiomeWarp")
Remote.OpenSellFish = Remote.getOrCreateEvent("OpenSellFish")
Remote.OpenRodShop = Remote.getOrCreateEvent("OpenRodShop")
Remote.OpenShop = Remote.getOrCreateEvent("OpenShop")
Remote.OpenAquariumHub = Remote.getOrCreateEvent("OpenAquariumHub")
Remote.AquariumAction = Remote.Folder:WaitForChild("AquariumAction")
Remote.ToggleAutoFish = Remote.Folder:WaitForChild("ToggleAutoFish")
Remote.StateUpdated = Remote.Folder:WaitForChild("StateUpdated")
Remote.FishingPrompt = Remote.Folder:WaitForChild("FishingPrompt")
Remote.Notice = Remote.Folder:WaitForChild("Notice")
Remote.GetState = Remote.Folder:WaitForChild("GetState")

local SAVE_STORE = "FishyFish_v1"
local saveStore = Services.DataStoreService:GetDataStore(SAVE_STORE)

local playerData = {}
playerData.SaveLocks = {}
playerData.SaveScheduled = {}
playerData.SaveRevision = {}
playerData.AquariumLikeCooldowns = {}
playerData.AquariumLikeLocks = {}

function playerData.copyForSave(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, childValue in pairs(value) do
		copy[playerData.copyForSave(key)] = playerData.copyForSave(childValue)
	end
	return copy
end

local pendingFishing = {}
local fishSerial = 0
local getPlayerFishingBiome
local getPlayerTravelLocation
local getAquariumVisitorsState
local playerAquariumSlots = {}
local FishCaughtLeaderboard = require(script.Parent:WaitForChild("FishCaughtLeaderboardService"))
local CastConfigService = require(script.Parent:WaitForChild("CastConfigService"))
FishCaughtLeaderboard.configure({
	playerData = playerData,
})

local AquariumLayout = {
	AreaOrigin = Vector3.new(-150, 0, -705),
	ViewOffset = Vector3.new(0, 24.7, 36.94),
	HubTeleportOffset = Vector3.new(0, 19, -32.4),
	LandTileSize = 180,
}

local RuntimeConfig = {
	autoFishMinWait = 11,
	autoFishMaxWait = 18,
	studioTestOverridesEnabled = false,
	studioTestingStartCoins = 0,
	studioTestingStartLevel = GameConfig.MAX_LEVEL,
	studioGiveBeginnerFishInBag = false,
	ownerUsername = "Wingdisk00",
	ownerCoinGrant = 100000,
}
local Travel

-- Optional fallback: paste a single uploaded rod MeshId here if you prefer an asset-id based rod.
local RodVisual = {
	WoodenMeshId = "",
	TemplateFolderName = "FishyFishModelTemplates",
	VisualLength = 3.9,
	MaxTemplateScale = 2,
	GripInset = 0.82,
	VisualOffset = Vector3.new(0, -0.34, -0.18),
	VisualRotation = CFrame.Angles(math.rad(-18), math.rad(10), math.rad(16)),
	ReelFacingRotation = CFrame.Angles(0, math.rad(90), 0),
	UseWoodenShapeForAllRods = false,
	ToolsEnabled = true,
	Visuals3DEnabled = true,
	ImportedModelsEnabled = true,
	KeepImportedAppearance = true,
	AutoColorUntexturedImports = true,
	LineLength = 2.2,
}
local IMPORTED_ROD_TOOL_GRIP = CFrame.new(RodVisual.VisualOffset) * RodVisual.VisualRotation
local FALLBACK_ROD_TOOL_GRIP = CFrame.new(0, -0.04, -0.05) * CFrame.Angles(math.rad(6), math.rad(2), math.rad(-4))
local ROD_TEMPLATE_NAMES_BY_ROD = {
	WoodenRod = { "WoodenRod_Split2", "WoodenRod_split", "woodenrodsplit2", "woodenrodsplit", "woodenrodmk411", "WoodenRodMk411", "woodenrodmk4", "WoodenRodMk4", "WoodenRodMk3", "woodenrodmk3", "WoodenRod", "woodenrod", "wooden_rod" },
	IronRod = { "IronRod_Split", "IronRod_Split2", "ironrodsplit", "ironrodsplit2", "ironrod11", "IronRod11", "IronRod", "ironrod", "Iron Rod", "iron rod", "iron_rod" },
	GoldenRod = { "GoldenRod_Split", "GoldenRod_Split2", "goldenrodsplit", "goldenrodsplit2", "goldenrod11", "GoldenRod11", "GoldenRod", "goldenrod", "Golden Rod", "golden rod", "golden_rod" },
	EmeraldRod = { "EmeraldRod_Split", "EmeraldRod_Split2", "emeraldrodsplit", "emeraldrodsplit2", "emeraldrod11", "EmeraldRod11", "EmeraldRod", "emeraldrod", "Emerald Rod", "emerald rod", "emerald_rod" },
	OceanRod = { "OceanRod_Split", "OceanRod_Split2", "oceanrodsplit", "oceanrodsplit2", "ocean rod11", "Ocean Rod11", "oceanrod11", "OceanRod11", "OceanRod", "oceanrod", "Ocean Rod", "ocean rod", "ocean_rod" },
}

local rarityLuckWeight = {
	Common = -0.15,
	Uncommon = 0.15,
	Rare = 0.65,
	Epic = 1.35,
	Legendary = 2.25,
	Mythic = 3.25,
}

function playerData.copyArray(source)
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

function playerData.shallowCopyMap(source)
	local result = {}

	for key, value in pairs(source) do
		result[key] = value
	end

	return result
end

function RodVisual.getRodData(data)
	return GameConfig.Rods[data.EquippedRod] or GameConfig.Rods.WoodenRod
end

local DEFAULT_FISHING_ISLAND_ID = "LilyshoreIsland"

function IslandConfig.normalizeBiomeId(biomeId)
	if GameConfig.normalizeIslandId then
		return GameConfig.normalizeIslandId(biomeId)
	end

	if GameConfig.Biomes[biomeId] then
		return biomeId
	end

	return nil
end

function IslandConfig.normalizeTravelTarget(target)
	if type(target) ~= "string" then
		return nil
	end

	local normalized = IslandConfig.normalizeIslandId(target)
	if normalized == IslandConfig.SeasideIslandId
		or normalized == IslandConfig.AquariumHubId
		or GameConfig.Biomes[normalized]
	then
		return normalized
	end

	return nil
end

function IslandConfig.normalizeUnlockedBiomes(unlockedBiomes)
	local result = {}
	if type(unlockedBiomes) == "table" then
		for biomeId, unlocked in pairs(unlockedBiomes) do
			if unlocked == true then
				local normalized = IslandConfig.normalizeBiomeId(biomeId)
				if normalized then
					result[normalized] = true
				end
			end
		end
	end
	result[DEFAULT_FISHING_ISLAND_ID] = true
	return result
end

function IslandConfig.getBiomeData(data)
	local biomeId = IslandConfig.normalizeBiomeId(data.CurrentBiome) or DEFAULT_FISHING_ISLAND_ID
	data.CurrentBiome = biomeId
	return GameConfig.Biomes[biomeId] or GameConfig.Biomes[DEFAULT_FISHING_ISLAND_ID]
end

function IslandConfig.isBiomeUnlocked(data, biomeId)
	biomeId = IslandConfig.normalizeBiomeId(biomeId)
	return biomeId ~= nil and data.UnlockedBiomes[biomeId] == true
end

function RodVisual.ownsRod(data, rodId)
	return data.OwnedRods[rodId] == true
end

local Bait = {
	BasicId = GameConfig.BasicBaitId or "BasicBait",
}

function Bait.normalizeId(baitId)
	if baitId and GameConfig.Baits[baitId] then
		return baitId
	end

	if type(baitId) == "string" then
		local normalized = string.lower(baitId):gsub("[%s_%-]", "")
		for _, configuredBaitId in ipairs(GameConfig.BaitOrder) do
			local bait = GameConfig.Baits[configuredBaitId]
			local configuredNormalized = string.lower(configuredBaitId):gsub("[%s_%-]", "")
			local displayNormalized = string.lower(bait.displayName or configuredBaitId):gsub("[%s_%-]", "")
			if normalized == configuredNormalized or normalized == displayNormalized then
				return configuredBaitId
			end
		end
	end

	return Bait.BasicId
end

function Bait.normalizeInventory(inventory)
	local result = {}

	for _, baitId in ipairs(GameConfig.BaitOrder) do
		if baitId ~= Bait.BasicId then
			local amount = type(inventory) == "table" and tonumber(inventory[baitId]) or 0
			result[baitId] = math.max(0, math.floor(amount or 0))
		end
	end

	return result
end

function Bait.getCount(data, baitId)
	baitId = Bait.normalizeId(baitId)
	if baitId == Bait.BasicId then
		return math.huge
	end

	data.BaitInventory = Bait.normalizeInventory(data.BaitInventory)
	return math.max(0, math.floor(tonumber(data.BaitInventory[baitId]) or 0))
end

function Bait.ensureState(data)
	data.BaitInventory = Bait.normalizeInventory(data.BaitInventory)
	data.EquippedBait = Bait.normalizeId(data.EquippedBait)

	if data.EquippedBait ~= Bait.BasicId and Bait.getCount(data, data.EquippedBait) <= 0 then
		data.EquippedBait = Bait.BasicId
	end
end

function Bait.getEquippedId(data)
	Bait.ensureState(data)
	return data.EquippedBait
end

function Bait.getData(baitId)
	return GameConfig.getBait(Bait.normalizeId(baitId))
end

function Bait.getRemainingForClient(data, baitId)
	baitId = Bait.normalizeId(baitId)
	if baitId == Bait.BasicId then
		return -1
	end

	return Bait.getCount(data, baitId)
end

function Bait.consumeForCast(data)
	Bait.ensureState(data)

	local baitId = data.EquippedBait
	if baitId ~= Bait.BasicId then
		local count = Bait.getCount(data, baitId)
		if count <= 0 then
			data.EquippedBait = Bait.BasicId
			return Bait.BasicId, Bait.getData(Bait.BasicId)
		end

		data.BaitInventory[baitId] = count - 1
		if data.BaitInventory[baitId] <= 0 then
			data.EquippedBait = Bait.BasicId
		end
	end

	return baitId, Bait.getData(baitId)
end

local Monetization = {
	Config = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonetizationConfig")),
	MarketplaceService = game:GetService("MarketplaceService"),
}

do
	local resolved, resolutionError = Monetization.Config.ResolveDeveloperProductIds(Monetization.MarketplaceService)
	if not resolved then
		warn("[FishyFish] Sea Star product discovery failed:", resolutionError)
	end
end

local SeaStars = {
	TransactionLocks = {},
}

function SeaStars.normalizeBalance(value)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		return 0
	end
	return math.max(0, math.floor(number))
end

function SeaStars.normalizeUnlocks(unlocks)
	local result = {}
	if type(unlocks) ~= "table" then
		return result
	end
	for themeId, theme in pairs(Monetization.Config.AquariumDesigner.themes or {}) do
		if theme.free ~= true and unlocks[themeId] == true then
			result[themeId] = true
		end
	end
	return result
end

function playerData.normalizeAquariumLikes(aquarium)
	if type(aquarium) ~= "table" then
		return {}, 0
	end

	local normalized = {}
	for rawUserId, liked in pairs(type(aquarium.LikedBy) == "table" and aquarium.LikedBy or {}) do
		local userId = math.floor(tonumber(rawUserId) or 0)
		if liked == true and userId > 0 then
			normalized[tostring(userId)] = true
		end
	end

	local count = 0
	for _ in pairs(normalized) do
		count += 1
	end

	aquarium.LikedBy = normalized
	aquarium.LikeCount = math.max(count, math.max(0, math.floor(tonumber(aquarium.LikeCount) or 0)))
	return normalized, aquarium.LikeCount
end

function SeaStars.ensureState(data)
	data.SeaStars = SeaStars.normalizeBalance(data.SeaStars)
	data.SeaStarUnlocks = SeaStars.normalizeUnlocks(data.SeaStarUnlocks)
end

function SeaStars.ownsTheme(data, themeId)
	SeaStars.ensureState(data)
	local theme = Monetization.Config.AquariumDesigner.themes[themeId]
	return theme ~= nil and (theme.free == true or data.SeaStarUnlocks[themeId] == true)
end

function SeaStars.tryAcquire(player)
	if SeaStars.TransactionLocks[player] then
		return false
	end
	SeaStars.TransactionLocks[player] = true
	return true
end

function SeaStars.release(player)
	SeaStars.TransactionLocks[player] = nil
end

function SeaStars.normalizeDecorations(decorations)
	local result = {}
	local source = type(decorations) == "table" and decorations or {}
	for decorationId, decoration in pairs(Monetization.Config.AquariumDesigner.decorations or {}) do
		if decorationId ~= "None" then
			result[decorationId] = decoration.free == true
				and 1
				or math.max(0, math.floor(tonumber(source[decorationId]) or 0))
		end
	end
	return result
end

function SeaStars.ownsDecoration(data, decorationId)
	local decoration = Monetization.Config.AquariumDesigner.decorations[decorationId]
	if not decoration or decorationId == "None" then
		return false
	end
	if decoration.free == true then
		return true
	end
	data.AquariumDecorations = SeaStars.normalizeDecorations(data.AquariumDecorations)
	return (data.AquariumDecorations[decorationId] or 0) > 0
end

function SeaStars.getDecorationOwnershipError(data, design)
	local normalized = Monetization.normalizeAquariumDesign(design)
	for _, decorationId in pairs(normalized.decorations or {}) do
		if not SeaStars.ownsDecoration(data, decorationId) then
			return "You do not own the " .. tostring(decorationId) .. " decoration."
		end
	end
	for _, item in ipairs(normalized.freeDecorations or {}) do
		if not SeaStars.ownsDecoration(data, item.decorationId) then
			return "You do not own the " .. tostring(item.decorationId) .. " decoration."
		end
	end
	return nil
end

function Monetization.normalizeOwnedPasses(ownedPasses)
	local result = {}
	if type(ownedPasses) == "table" then
		for passKey in pairs(Monetization.Config.GamePasses) do
			result[passKey] = ownedPasses[passKey] == true
		end
	end
	return result
end

function Monetization.ownsPass(data, passKey)
	data.OwnedGamePasses = Monetization.normalizeOwnedPasses(data.OwnedGamePasses)
	return data.OwnedGamePasses[passKey] == true
end

function Monetization.getBagCapacity(data)
	for _, passKey in ipairs({ "LargeBag", "MediumBag", "SmallBag" }) do
		local pass = Monetization.Config.GamePasses[passKey]
		if pass and Monetization.ownsPass(data, passKey) then
			return math.max(GameConfig.BASE_BACKPACK_SIZE, math.floor(tonumber(pass.TotalSlots) or tonumber(pass.totalSlots) or GameConfig.BASE_BACKPACK_SIZE))
		end
	end
	return GameConfig.BASE_BACKPACK_SIZE
end

function Monetization.updateBackpackSize(data)
	data.BackpackSize = Monetization.getBagCapacity(data)
end

function Monetization.getTodayKey()
	local now = os.date("!*t")
	return string.format("%04d-%02d-%02d", now.year, now.month, now.day)
end

function Monetization.canClaimVipReward(data)
	return Monetization.ownsPass(data, "VipAngler") and data.LastVipRewardDate ~= Monetization.getTodayKey()
end

function Monetization.addBait(data, baitId, amount)
	baitId = Bait.normalizeId(baitId)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 or baitId == Bait.BasicId then
		return
	end

	data.BaitInventory = Bait.normalizeInventory(data.BaitInventory)
	data.BaitInventory[baitId] = (tonumber(data.BaitInventory[baitId]) or 0) + amount
	Bait.ensureState(data)
end

function Monetization.applyVipDailyReward(data)
	if not Monetization.canClaimVipReward(data) then
		return false
	end

	for baitId, amount in pairs(Monetization.Config.Vip.dailyReward.bait or {}) do
		Monetization.addBait(data, baitId, amount)
	end
	data.LastVipRewardDate = Monetization.getTodayKey()
	return true
end

function Monetization.getSellValue(data, baseValue)
	local value = math.max(0, math.floor(tonumber(baseValue) or 0))
	if Monetization.ownsPass(data, "VipAngler") then
		value = math.floor(value * (tonumber(Monetization.Config.Vip.sellBonusMultiplier) or 1) + 0.5)
	end
	return value
end

function Monetization.normalizeAquariumDesign(design)
	local config = Monetization.Config.AquariumDesigner
	local defaults = config.defaultDesign
	local result = {
		theme = defaults.theme,
		backdropEnabled = defaults.backdropEnabled ~= false,
		backgroundColor = defaults.backgroundColor,
		lightingColor = defaults.lightingColor,
		signText = "",
		decorations = {},
		freeDecorations = {},
	}

	if type(design) ~= "table" then
		return result
	end

	if config.themes[design.theme] then
		result.theme = design.theme
	end
	if type(design.backdropEnabled) == "boolean" then
		result.backdropEnabled = design.backdropEnabled
	end
	if config.backgroundColors[design.backgroundColor] then
		result.backgroundColor = design.backgroundColor
	end
	if config.lightingColors[design.lightingColor] then
		result.lightingColor = design.lightingColor
	end
	if type(design.signText) == "string" then
		result.signText = string.sub(design.signText:gsub("[%c]", ""), 1, 28)
	end

	if type(design.decorations) == "table" then
		for _, slotId in ipairs(config.slotOrder) do
			local decorationId = design.decorations[slotId]
			if decorationId and decorationId ~= "None" and config.decorations[decorationId] then
				result.decorations[slotId] = decorationId
			end
		end
	end

	local placement = config.freePlacement or {}
	local bounds = placement.bounds or {}
	local maxFreeDecorations = 12
	for _, maxForLevel in pairs(placement.maxByLevel or {}) do
		maxFreeDecorations = math.max(maxFreeDecorations, math.floor(tonumber(maxForLevel) or 0))
	end

	if type(design.freeDecorations) == "table" then
		for _, item in ipairs(design.freeDecorations) do
			if #result.freeDecorations >= maxFreeDecorations then
				break
			end

			if type(item) == "table" then
				local decorationId = item.decorationId or item.id or item.decoration
				if decorationId and decorationId ~= "None" and config.decorations[decorationId] then
					local depth = item.z
					if depth == nil then
						depth = item.depth
					end
					table.insert(result.freeDecorations, {
						decorationId = decorationId,
						x = math.clamp(tonumber(item.x) or 0, tonumber(bounds.xMin) or -0.42, tonumber(bounds.xMax) or 0.42),
						y = math.clamp(tonumber(item.y) or 0.16, tonumber(bounds.yMin) or 0.08, tonumber(bounds.yMax) or 0.82),
						z = math.clamp(tonumber(depth) or 0, tonumber(bounds.zMin) or -0.42, tonumber(bounds.zMax) or 0.42),
						scale = math.clamp(tonumber(item.scale) or 1, tonumber(bounds.scaleMin) or 0.55, tonumber(bounds.scaleMax) or 1.35),
					})
				end
			end
		end
	end

	return result
end

function Monetization.limitAquariumDesignForLevel(design, aquariumLevel)
	local result = Monetization.normalizeAquariumDesign(design)
	local maxByLevel = ((Monetization.Config.AquariumDesigner.freePlacement or {}).maxByLevel or {})
	local maxFreeDecorations = math.max(0, math.floor(tonumber(maxByLevel[tonumber(aquariumLevel) or 1]) or 0))
	while #result.freeDecorations > maxFreeDecorations do
		table.remove(result.freeDecorations)
	end
	return result
end

function Monetization.getAquariumFreeDecorationValidationError(design)
	if type(design) ~= "table" then
		return "payload is not a table"
	end

	if design.freeDecorations ~= nil and type(design.freeDecorations) ~= "table" then
		return "freeDecorations is not a table"
	end

	for index, item in ipairs(design.freeDecorations or {}) do
		if type(item) ~= "table" then
			return "decoration #" .. tostring(index) .. " is not a table"
		end

		local decorationId = item.decorationId or item.id or item.decoration
		if not decorationId or decorationId == "None" or not Monetization.Config.AquariumDesigner.decorations[decorationId] then
			return "decoration #" .. tostring(index) .. " has an invalid decorationId"
		end

		local depth = item.z
		if depth == nil then
			depth = item.depth
		end

		if tonumber(item.x) == nil or tonumber(item.y) == nil or tonumber(depth) == nil or tonumber(item.scale) == nil then
			return "decoration #" .. tostring(index) .. " has invalid position/depth/scale data"
		end
	end

	return nil
end

function Monetization.aquariumDesignUsesPremium(design)
	local config = Monetization.Config.AquariumDesigner
	design = Monetization.normalizeAquariumDesign(design)
	local theme = config.themes[design.theme]
	local backgroundColor = config.backgroundColors[design.backgroundColor]
	local lightingColor = config.lightingColors[design.lightingColor]

	if theme and theme.premium then
		return true
	end
	if backgroundColor and backgroundColor.premium then
		return true
	end
	if lightingColor and lightingColor.premium then
		return true
	end
	if design.signText ~= "" then
		return true
	end

	for _, decorationId in pairs(design.decorations) do
		local decoration = config.decorations[decorationId]
		if decoration and decoration.premium then
			return true
		end
	end

	for _, item in ipairs(design.freeDecorations or {}) do
		local decoration = config.decorations[item.decorationId]
		if decoration and decoration.premium then
			return true
		end
	end

	return false
end

function Monetization.aquariumDesignUsesFixedDecorations(design)
	design = Monetization.normalizeAquariumDesign(design)
	return next(design.decorations) ~= nil or #design.freeDecorations > 0
end

function Monetization.ensureState(data)
	data.OwnedGamePasses = Monetization.normalizeOwnedPasses(data.OwnedGamePasses)
	data.ProcessedReceipts = type(data.ProcessedReceipts) == "table" and data.ProcessedReceipts or {}
	data.LastVipRewardDate = type(data.LastVipRewardDate) == "string" and data.LastVipRewardDate or ""
	SeaStars.ensureState(data)
	data.AquariumDecorations = SeaStars.normalizeDecorations(data.AquariumDecorations)
	data.AquariumDesign = Monetization.normalizeAquariumDesign(data.AquariumDesign)
	if not SeaStars.ownsTheme(data, data.AquariumDesign.theme) then
		data.AquariumDesign.theme = "Classic"
	end
	data.AquariumPreviewDesign = type(data.AquariumPreviewDesign) == "table" and Monetization.normalizeAquariumDesign(data.AquariumPreviewDesign) or nil
	Monetization.updateBackpackSize(data)
end

function Monetization.tryMarkReceipt(data, purchaseId)
	Monetization.ensureState(data)
	purchaseId = tostring(purchaseId or "")
	if purchaseId == "" or data.ProcessedReceipts[purchaseId] then
		return false
	end
	data.ProcessedReceipts[purchaseId] = true
	return true
end

function Monetization.getActiveAquariumDesign(data)
	Monetization.ensureState(data)
	return data.AquariumPreviewDesign or data.AquariumDesign
end

function Monetization.getClientState(data)
	Monetization.ensureState(data)
	local developerProductIds = {}
	for _, productKey in ipairs(Monetization.Config.SeaStarProductOrder or {}) do
		local product = Monetization.Config.DeveloperProducts[productKey]
		local productId = product and (tonumber(product.id) or tonumber(product.Id))
		if productId and productId > 0 then
			developerProductIds[productKey] = productId
		end
	end
	return {
		OwnedGamePasses = table.clone(data.OwnedGamePasses),
		VipRewardAvailable = Monetization.canClaimVipReward(data),
		LastVipRewardDate = data.LastVipRewardDate,
		AquariumEditorFree = true,
		AquariumDesign = Monetization.normalizeAquariumDesign(data.AquariumDesign),
		AquariumPreviewActive = data.AquariumPreviewDesign ~= nil,
		AquariumPreviewDesign = data.AquariumPreviewDesign and Monetization.normalizeAquariumDesign(data.AquariumPreviewDesign) or nil,
		DeveloperProductIds = developerProductIds,
	}
end

function Monetization.syncGamePassOwnership(player, data)
	Monetization.ensureState(data)

	for passKey, pass in pairs(Monetization.Config.GamePasses) do
		if pass.purchasable == false then
			data.OwnedGamePasses[passKey] = false
			continue
		end

		local success, ownsPass = pcall(function()
			return Monetization.MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
		end)
		if success and ownsPass then
			data.OwnedGamePasses[passKey] = true
		elseif not success then
			warn("Game pass ownership check failed", player.Name, passKey, ownsPass)
		end
	end

	Monetization.updateBackpackSize(data)
	player:SetAttribute("FishyFishVip", Monetization.ownsPass(data, "VipAngler"))
	player:SetAttribute("FishyFishChatTag", Monetization.ownsPass(data, "VipAngler") and "VIP" or "")
	player:SetAttribute("FishyFishTitle", Monetization.ownsPass(data, "VipAngler") and Monetization.Config.Vip.title or "")
end

local LoginRewards = {
	ClaimLocks = {},
}

function LoginRewards.ensureState(data, now)
	now = now or LoginRewardConfig.UtcNow()
	data.LoginRewards = LoginRewardConfig.Normalize(data.LoginRewards, now)
	SeaStars.ensureState(data)
	data.ResourceInventory = ResourceConfig.NormalizeInventory(data.ResourceInventory)
	data.AquariumDecorations = SeaStars.normalizeDecorations(data.AquariumDecorations)
	return data.LoginRewards
end

function LoginRewards.getHighestResourceIsland(data)
	local highest = nil
	for _, islandId in ipairs(GameConfig.IslandOrder or GameConfig.BiomeOrder or {}) do
		if data.UnlockedBiomes and data.UnlockedBiomes[islandId] == true and ResourceConfig.GetIslandDropTable(islandId) then
			highest = islandId
		end
	end
	return highest
end

function LoginRewards.selectResources(data, count, guaranteeUncommon, randomObject)
	local islandId = LoginRewards.getHighestResourceIsland(data)
	if not islandId or count <= 0 then
		return {}, islandId
	end

	randomObject = randomObject or Random.new()
	local selected = {}
	if guaranteeUncommon then
		local guaranteedId = islandId == "RiverbendIsland" and "OceanShard" or "EmeraldShard"
		selected[guaranteedId] = 1
		count -= 1
	end

	for _ = 1, count do
		local resourceId = ResourceConfig.SelectResource(islandId, randomObject:NextNumber())
		if resourceId then
			selected[resourceId] = (selected[resourceId] or 0) + 1
		end
	end
	return selected, islandId
end

function LoginRewards.selectFinalDecoration(data, randomObject)
	data.AquariumDecorations = SeaStars.normalizeDecorations(data.AquariumDecorations)
	local unowned = {}
	for _, decorationId in ipairs(LoginRewardConfig.FinalDecorationPool) do
		local decoration = Monetization.Config.AquariumDesigner.decorations[decorationId]
		if decoration
			and decoration.free ~= true
			and (data.AquariumDecorations[decorationId] or 0) <= 0
		then
			table.insert(unowned, decorationId)
		end
	end
	if #unowned == 0 then
		return nil
	end
	randomObject = randomObject or Random.new()
	return unowned[randomObject:NextInteger(1, #unowned)]
end

function LoginRewards.makeReward(data, day, daysInCycle, randomObject)
	local tier = EconomyConfig.GetHighestUnlockedTier(data.UnlockedBiomes, GameConfig)
	local economyValue = EconomyConfig.EconomyValueForTier(tier)
	local reward = LoginRewardConfig.GetReward(day, daysInCycle, economyValue)
	reward.rewardTier = tier
	reward.resources, reward.resourceIslandId = LoginRewards.selectResources(
		data,
		reward.resourceCount or 0,
		reward.guaranteeUncommon == true,
		randomObject
	)
	if reward.decorationReward then
		reward.decorationId = LoginRewards.selectFinalDecoration(data, randomObject)
		if not reward.decorationId then
			reward.decorationFallbackSeaStars = 10
		end
	end
	reward.summary = LoginRewardConfig.FormatReward(reward)
	return reward
end

function LoginRewards.applyReward(data, reward)
	data.Coins = math.max(0, math.floor(tonumber(data.Coins) or 0)) + math.max(0, math.floor(tonumber(reward.coins) or 0))
	for baitId, amount in pairs(reward.bait or {}) do
		Monetization.addBait(data, baitId, amount)
	end

	SeaStars.ensureState(data)
	local seaStarGrant = math.max(0, math.floor(tonumber(reward.seaStars) or 0))
		+ math.max(0, math.floor(tonumber(reward.cycleSeaStars) or 0))
		+ math.max(0, math.floor(tonumber(reward.decorationFallbackSeaStars) or 0))
	data.SeaStars = SeaStars.normalizeBalance(data.SeaStars + seaStarGrant)

	data.ResourceInventory = ResourceConfig.NormalizeInventory(data.ResourceInventory)
	for resourceId, amount in pairs(reward.resources or {}) do
		if ResourceConfig.Resources[resourceId] then
			data.ResourceInventory[resourceId] += math.max(0, math.floor(tonumber(amount) or 0))
		end
	end

	if reward.decorationId then
		data.AquariumDecorations = SeaStars.normalizeDecorations(data.AquariumDecorations)
		if (data.AquariumDecorations[reward.decorationId] or 0) > 0 then
			return false, "Decoration reward was already owned."
		end
		data.AquariumDecorations[reward.decorationId] = 1
	end
	return true
end

function LoginRewards.claim(data, now, randomObject)
	now = now or LoginRewardConfig.UtcNow()
	local login = LoginRewards.ensureState(data, now)
	local today = LoginRewardConfig.DateKey(now)
	if login.LastClaimDate == today then
		return false, "Today's login reward was already claimed."
	end

	local claimedDay = login.CurrentDay
	local reward = LoginRewards.makeReward(data, claimedDay, login.DaysInCycle, randomObject)
	local granted, grantError = LoginRewards.applyReward(data, reward)
	if not granted then
		return false, grantError or "The login reward could not be granted."
	end

	login.LastClaimDate = today
	if claimedDay >= login.DaysInCycle then
		login.CompletedCycles += 1
		login.CurrentDay = 1
		login.DaysInCycle = LoginRewardConfig.DaysInMonth(now.year, now.month)
		login.CycleMonthKey = LoginRewardConfig.MonthKey(now)
	else
		login.CurrentDay = claimedDay + 1
	end
	data.LoginRewards = login
	return true, "Claimed Day " .. tostring(claimedDay) .. ": " .. reward.summary, reward
end

function LoginRewards.getClientState(data)
	local now = LoginRewardConfig.UtcNow()
	local login = LoginRewards.ensureState(data, now)
	local today = LoginRewardConfig.DateKey(now)
	local tier = EconomyConfig.GetHighestUnlockedTier(data.UnlockedBiomes, GameConfig)
	local economyValue = EconomyConfig.EconomyValueForTier(tier)
	local track = {}
	for day = 1, login.DaysInCycle do
		local reward = LoginRewardConfig.GetReward(day, login.DaysInCycle, economyValue)
		table.insert(track, {
			Day = day,
			IsMilestone = reward.isMilestone == true,
			IsFinal = reward.isFinal == true,
			Summary = LoginRewardConfig.FormatReward(reward),
		})
	end
	local secondsIntoDay = now.hour * 3600 + now.min * 60 + now.sec
	return {
		CurrentDay = login.CurrentDay,
		DaysInCycle = login.DaysInCycle,
		CycleMonthKey = login.CycleMonthKey,
		LastClaimDate = login.LastClaimDate,
		CompletedCycles = login.CompletedCycles,
		ClaimAvailable = login.LastClaimDate ~= today,
		TodayUtc = today,
		SecondsUntilNextUtcClaim = login.LastClaimDate == today and math.max(1, 86400 - secondsIntoDay) or 0,
		RewardTrack = track,
	}
end

local Quest = {
	Configs = {
		Daily = DailyQuestConfig,
		Weekly = WeeklyQuestConfig,
		Monthly = MonthlyQuestConfig,
	},
	PeriodOrder = { "Daily", "Weekly", "Monthly" },
}

function Quest.copyReward(reward)
	local result = {}
	if type(reward) ~= "table" then
		return result
	end

	result.coins = math.max(0, math.floor(tonumber(reward.coins) or 0))
	result.xp = math.max(0, math.floor(tonumber(reward.xp) or 0))

	if type(reward.bait) == "table" then
		result.bait = {}
		for baitId, amount in pairs(reward.bait) do
			if GameConfig.Baits[baitId] and baitId ~= Bait.BasicId then
				result.bait[baitId] = math.max(0, math.floor(tonumber(amount) or 0))
			end
		end
	end

	if type(reward.decorations) == "table" then
		result.decorations = {}
		for decorationId, amount in pairs(reward.decorations) do
			if type(decorationId) == "string" then
				result.decorations[decorationId] = math.max(0, math.floor(tonumber(amount) or 0))
			end
		end
	end

	return result
end

function Quest.getPeriodKey(periodName, now)
	now = now or os.time()
	local date = os.date("*t", now)

	if periodName == "Daily" then
		return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
	elseif periodName == "Weekly" then
		local midnight = os.time({
			year = date.year,
			month = date.month,
			day = date.day,
			hour = 0,
			min = 0,
			sec = 0,
		})
		local daysSinceMonday = (date.wday + 5) % 7
		local monday = os.date("*t", midnight - (daysSinceMonday * 86400))
		return string.format("%04d-W%02d-%02d", monday.year, monday.month, monday.day)
	elseif periodName == "Monthly" then
		return string.format("%04d-%02d", date.year, date.month)
	end

	return "unknown"
end

function Quest.getUnlockedBiomeIds(data)
	local result = {}
	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		if IslandConfig.isBiomeUnlocked(data, biomeId) then
			table.insert(result, biomeId)
		end
	end

	if #result == 0 then
		table.insert(result, DEFAULT_FISHING_ISLAND_ID)
	end

	return result
end

function Quest.getRewardTier(data)
	return EconomyConfig.GetHighestUnlockedTier(data.UnlockedBiomes, GameConfig)
end

function Quest.findFishById(fishId)
	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		for _, fish in ipairs(GameConfig.Biomes[biomeId].fish) do
			if fish.id == fishId or fish.name == fishId then
				return fish, biomeId
			end
		end
	end

	return nil, nil
end

function Quest.pickFromList(list)
	if type(list) ~= "table" or #list == 0 then
		return nil
	end

	return list[Random.new():NextInteger(1, #list)]
end

function Quest.pickSpecificFish(data, template)
	local candidates = {}
	local unlockedBiomes = Quest.getUnlockedBiomeIds(data)

	if type(template.specificFishPools) == "table" then
		for _, biomeId in ipairs(unlockedBiomes) do
			for _, fishId in ipairs(template.specificFishPools[biomeId] or {}) do
				local fish = Quest.findFishById(fishId)
				if fish then
					table.insert(candidates, {
						fish = fish,
						biomeId = biomeId,
					})
				end
			end
		end
	elseif template.rarity then
		for _, biomeId in ipairs(unlockedBiomes) do
			for _, fish in ipairs(GameConfig.Biomes[biomeId].fish) do
				if fish.rarity == template.rarity then
					table.insert(candidates, {
						fish = fish,
						biomeId = biomeId,
					})
				end
			end
		end
	end

	local choice = Quest.pickFromList(candidates)
	if choice then
		return choice.fish, choice.biomeId
	end

	return GameConfig.Biomes[DEFAULT_FISHING_ISLAND_ID].fish[1], DEFAULT_FISHING_ISLAND_ID
end

function Quest.makeQuest(data, template)
	local rewardTier = Quest.getRewardTier(data)
	local economyValue = EconomyConfig.EconomyValueForTier(rewardTier)
	local coinMultiplier = math.max(0, tonumber(template.coinMultiplier) or 0)
	local quest = {
		id = template.id,
		title = template.title,
		description = template.description,
		objectiveType = template.objectiveType,
		target = math.max(1, math.floor(tonumber(template.target) or 1)),
		progress = 0,
		completed = false,
		claimed = false,
		reward = Quest.copyReward(template.reward),
		rewardTier = rewardTier,
	}
	quest.reward.coins = math.round(economyValue * coinMultiplier)

	if template.objectiveType == "catch_specific_fish" then
		local fish, biomeId = Quest.pickSpecificFish(data, template)
		quest.fishId = fish.id
		quest.fishName = fish.name
		quest.biomeId = biomeId
		quest.biomeName = GameConfig.Biomes[biomeId] and GameConfig.Biomes[biomeId].displayName or biomeId
		quest.description = string.format("Catch %d %s.", quest.target, fish.name)
	elseif template.objectiveType == "catch_rarity" then
		quest.rarity = template.rarity
		quest.description = string.format("Catch %d %s fish.", quest.target, template.rarity or "Rare")
	elseif template.objectiveType == "discover_biome_species" then
		local biomeId = Quest.pickFromList(Quest.getUnlockedBiomeIds(data)) or DEFAULT_FISHING_ISLAND_ID
		local biome = GameConfig.Biomes[biomeId] or GameConfig.Biomes[DEFAULT_FISHING_ISLAND_ID]
		quest.biomeId = biomeId
		quest.biomeName = biome.displayName
		quest.speciesIds = {}
		for _, fish in ipairs(biome.fish) do
			table.insert(quest.speciesIds, fish.id)
		end
		quest.target = #quest.speciesIds
		quest.description = "Catch every fish species on " .. biome.displayName .. "."
	end

	return quest
end

function Quest.getSpeciesProgress(data, quest)
	local progress = 0
	for _, fishId in ipairs(quest.speciesIds or {}) do
		if (data.Fishdex[fishId] or 0) > 0 then
			progress += 1
		end
	end

	return progress
end

function Quest.generatePeriod(data, periodName)
	local config = Quest.Configs[periodName]
	local quests = {}

	for _, template in ipairs(config.quests or {}) do
		local quest = Quest.makeQuest(data, template)
		if quest.objectiveType == "discover_biome_species" then
			quest.progress = Quest.getSpeciesProgress(data, quest)
			quest.completed = quest.progress >= quest.target
		end
		table.insert(quests, quest)
	end

	return {
		periodKey = Quest.getPeriodKey(periodName),
		quests = quests,
	}
end

function Quest.normalizePeriod(data, periodName)
	local period = data.QuestState[periodName]
	local currentKey = Quest.getPeriodKey(periodName)

	if type(period) ~= "table" or period.periodKey ~= currentKey or type(period.quests) ~= "table" then
		data.QuestState[periodName] = Quest.generatePeriod(data, periodName)
		return
	end

	for _, quest in ipairs(period.quests) do
		quest.progress = math.max(0, math.floor(tonumber(quest.progress) or 0))
		quest.target = math.max(1, math.floor(tonumber(quest.target) or 1))
		quest.completed = quest.completed == true or quest.progress >= quest.target
		quest.claimed = quest.claimed == true
		quest.reward = Quest.copyReward(quest.reward)
		quest.rewardTier = math.max(1, math.floor(tonumber(quest.rewardTier) or 1))
	end
end

function Quest.ensureState(data)
	data.QuestState = type(data.QuestState) == "table" and data.QuestState or {}
	data.AquariumDecorations = type(data.AquariumDecorations) == "table" and data.AquariumDecorations or {}

	for _, periodName in ipairs(Quest.PeriodOrder) do
		Quest.normalizePeriod(data, periodName)
	end
end

function Quest.getClientState(data)
	Quest.ensureState(data)
	local result = {}

	for _, periodName in ipairs(Quest.PeriodOrder) do
		local period = data.QuestState[periodName]
		result[periodName] = {
			periodKey = period.periodKey,
			quests = {},
		}

		for _, quest in ipairs(period.quests) do
			table.insert(result[periodName].quests, {
				id = quest.id,
				title = quest.title,
				description = quest.description,
				objectiveType = quest.objectiveType,
				target = quest.target,
				progress = quest.progress,
				completed = quest.completed == true,
				claimed = quest.claimed == true,
				reward = Quest.copyReward(quest.reward),
				rewardTier = quest.rewardTier,
				fishId = quest.fishId,
				fishName = quest.fishName,
				biomeId = quest.biomeId,
				biomeName = quest.biomeName,
				rarity = quest.rarity,
			})
		end
	end

	return result
end

function Quest.getUnclaimedCount(data)
	Quest.ensureState(data)
	local count = 0

	for _, periodName in ipairs(Quest.PeriodOrder) do
		for _, quest in ipairs(data.QuestState[periodName].quests) do
			if quest.completed == true and quest.claimed ~= true then
				count += 1
			end
		end
	end

	return count
end

function Quest.addProgress(quest, amount)
	if quest.claimed or quest.completed then
		return false
	end

	local target = math.max(1, math.floor(tonumber(quest.target) or 1))
	quest.progress = math.clamp((tonumber(quest.progress) or 0) + (amount or 1), 0, target)
	if quest.progress >= target then
		quest.completed = true
	end

	return true
end

function Quest.recordPerfectCast(data)
	Quest.ensureState(data)
	for _, periodName in ipairs(Quest.PeriodOrder) do
		for _, quest in ipairs(data.QuestState[periodName].quests) do
			if quest.objectiveType == "perfect_cast" then
				Quest.addProgress(quest, 1)
			end
		end
	end
end

function Quest.recordCatch(data, fish)
	Quest.ensureState(data)

	for _, periodName in ipairs(Quest.PeriodOrder) do
		for _, quest in ipairs(data.QuestState[periodName].quests) do
			if quest.objectiveType == "catch_any" then
				Quest.addProgress(quest, 1)
			elseif quest.objectiveType == "catch_specific_fish" and quest.fishId == fish.id then
				Quest.addProgress(quest, 1)
			elseif quest.objectiveType == "catch_rarity" and quest.rarity == fish.rarity then
				Quest.addProgress(quest, 1)
			elseif quest.objectiveType == "discover_biome_species" and not quest.completed then
				quest.progress = math.clamp(Quest.getSpeciesProgress(data, quest), 0, quest.target)
				if quest.progress >= quest.target then
					quest.completed = true
				end
			end
		end
	end
end

function Quest.findQuest(data, periodName, questId)
	Quest.ensureState(data)
	local period = data.QuestState[periodName]
	if not period then
		return nil
	end

	for _, quest in ipairs(period.quests) do
		if quest.id == questId then
			return quest
		end
	end

	return nil
end

function Quest.applyReward(data, reward)
	reward = Quest.copyReward(reward)
	data.Coins += reward.coins or 0
	data.XP = GameConfig.clampXP(data.XP + (reward.xp or 0))

	if type(reward.bait) == "table" then
		data.BaitInventory = Bait.normalizeInventory(data.BaitInventory)
		for baitId, amount in pairs(reward.bait) do
			data.BaitInventory[baitId] = math.max(0, math.floor(tonumber(data.BaitInventory[baitId]) or 0)) + amount
		end
	end

	if type(reward.decorations) == "table" then
		data.AquariumDecorations = type(data.AquariumDecorations) == "table" and data.AquariumDecorations or {}
		for decorationId, amount in pairs(reward.decorations) do
			data.AquariumDecorations[decorationId] = math.max(0, math.floor(tonumber(data.AquariumDecorations[decorationId]) or 0)) + amount
		end
	end
end

function Quest.claim(data, periodName, questId)
	local quest = Quest.findQuest(data, periodName, questId)
	if not quest then
		return false, "Quest not found."
	end

	if not quest.completed then
		return false, "Quest is not complete yet."
	end

	if quest.claimed then
		return false, "Reward already claimed."
	end

	Quest.applyReward(data, quest.reward)
	quest.claimed = true
	return true, "Quest reward claimed."
end

local function normalizeRodId(rodId)
	return rodId
end

local function normalizeOwnedRods(ownedRods)
	if type(ownedRods) ~= "table" then
		return ownedRods
	end

	return ownedRods
end

local function recalcLevel(data)
	data.XP = GameConfig.clampXP(data.XP)
	local level, progressXP, nextXP = GameConfig.getLevelFromXP(data.XP)
	data.Level = level
	data.LevelProgressXP = progressXP
	data.NextLevelXP = nextXP
end

local function getTotalXPForLevel(level)
	return GameConfig.getTotalXPForLevel(level)
end

function RuntimeConfig.getDefaultCoins()
	if Services.RunService:IsStudio() and RuntimeConfig.studioTestOverridesEnabled then
		return math.max(0, math.floor(tonumber(RuntimeConfig.studioTestingStartCoins) or 0))
	end
	return 0
end

function RuntimeConfig.getDefaultXP()
	if Services.RunService:IsStudio() and RuntimeConfig.studioTestOverridesEnabled then
		return GameConfig.clampXP(getTotalXPForLevel(RuntimeConfig.studioTestingStartLevel))
	end
	return 0
end

local function getInventoryValue(data)
	local total = 0

	for _, fish in ipairs(data.Inventory) do
		total += fish.value
	end

	return Monetization.getSellValue(data, total)
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

local function makeInventoryFishEntry(fish, biomeId, score)
	fishSerial += 1

	return {
		serial = fishSerial,
		id = fish.id,
		name = fish.name,
		rarity = fish.rarity,
		imageKey = fish.imageKey or fish.id,
		value = fish.value,
		baseValue = fish.value,
		biome = biomeId,
		score = score or 100,
	}
end

local function giveStudioBeginnerFishInBag(data)
	if not RuntimeConfig.studioGiveBeginnerFishInBag or not Services.RunService:IsStudio() then
		return false
	end

	local lilyshoreIsland = GameConfig.Biomes[DEFAULT_FISHING_ISLAND_ID]
	if not lilyshoreIsland then
		return false
	end

	local ownedById = {}
	for _, fish in ipairs(data.Inventory) do
		if fish.id then
			ownedById[fish.id] = true
		end
	end
	for _, fish in ipairs(data.Aquarium.Fish) do
		if fish.id then
			ownedById[fish.id] = true
		end
	end

	local missingFish = {}
	for _, fish in ipairs(lilyshoreIsland.fish) do
		if not ownedById[fish.id] then
			table.insert(missingFish, fish)
		end
	end

	if #missingFish == 0 then
		return false
	end

	data.BackpackSize = math.max(data.BackpackSize, #data.Inventory + #missingFish)
	for _, fish in ipairs(missingFish) do
		local entry = makeInventoryFishEntry(fish, DEFAULT_FISHING_ISLAND_ID, 100)
		table.insert(data.Inventory, entry)
		if not data.BestCatch or entry.value > data.BestCatch.value then
			data.BestCatch = entry
		end
	end

	return true
end

local function findInventoryFishIndex(data, fishSerial, fishIndex)
	local requestedSerial = tonumber(fishSerial)
	local requestedIndex = tonumber(fishIndex)

	if requestedIndex and data.Inventory[requestedIndex] then
		local fish = data.Inventory[requestedIndex]
		if not requestedSerial or tonumber(fish.serial) == requestedSerial then
			return requestedIndex
		end
	end

	if requestedSerial then
		for index, fish in ipairs(data.Inventory) do
			if tonumber(fish.serial) == requestedSerial then
				return index
			end
		end
	end

	return nil
end

local function getLoadedAquariumViewState(player)
	-- FishyFishWorld is nested inside the authored map.  The aquarium itself was
	-- being built correctly under that world, but this direct lookup reported it
	-- as unloaded, so AquariumView.CanEdit stayed false and hid Decor Editor.
	local world = workspace:FindFirstChild("FishyFishWorld", true)
	local folder = world and world:FindFirstChild("PersonalAquariums")
	local aquarium = folder and folder:FindFirstChild("AquariumViewerTank")
	local ownerUserId = aquarium and tonumber(aquarium:GetAttribute("OccupantUserId")) or nil
	local ownerName = aquarium and aquarium:GetAttribute("OccupantName") or nil
	local canEdit = ownerUserId ~= nil and ownerUserId == player.UserId
	local assignedOk, hasAssignedBay = pcall(function()
		return require(script.Parent:WaitForChild("AquariumGalleryPrototypeService"))
			.playerHasAssignedBay(player)
	end)
	if assignedOk and hasAssignedBay then
		canEdit = true
		ownerUserId = player.UserId
		ownerName = player.DisplayName
	end

	return {
		OwnerUserId = ownerUserId,
		OwnerName = ownerName,
		CanEdit = canEdit,
		IsViewingOwn = canEdit,
		IsLoaded = ownerUserId ~= nil,
	}
end

local function makeClientState(player, data)
	recalcLevel(data)
	Bait.ensureState(data)
	Monetization.ensureState(data)
	Quest.ensureState(data)
	LoginRewards.ensureState(data)
	data.ResourceInventory = ResourceConfig.NormalizeInventory(data.ResourceInventory)
	data.ResourcePity = ResourceConfig.NormalizePity(data.ResourcePity)

	local aquarium = type(data.Aquarium) == "table" and data.Aquarium or {}
	local aquariumLevel = math.clamp(tonumber(aquarium.Level) or 1, 1, 4)
	local aquariumFish = type(aquarium.Fish) == "table" and aquarium.Fish or {}
	local _, aquariumLikeCount = playerData.normalizeAquariumLikes(aquarium)
	aquariumLikeCount = Services.AquariumDirectory.getLikeCount(player.UserId, aquariumLikeCount)
	aquarium.LikeCount = aquariumLikeCount
	local aquariumVisitors = {}
	local equippedBait = Bait.getEquippedId(data)

	if getAquariumVisitorsState then
		local success, result = pcall(getAquariumVisitorsState, player)
		if success and type(result) == "table" then
			aquariumVisitors = result
		elseif not success then
			warn("Aquarium visitor state failed for", player.Name, result)
		end
	end

	return {
		Coins = data.Coins,
		XP = data.XP,
		Level = data.Level,
		LevelProgressXP = data.LevelProgressXP,
		NextLevelXP = data.NextLevelXP,
		Inventory = playerData.copyArray(data.Inventory),
		BackpackSize = data.BackpackSize,
		InventoryValue = getInventoryValue(data),
		ResourceInventory = playerData.shallowCopyMap(data.ResourceInventory),
		ResourcePity = data.ResourcePity,
		SeaStars = data.SeaStars,
		SeaStarUnlocks = playerData.shallowCopyMap(data.SeaStarUnlocks),
		OwnedRods = playerData.shallowCopyMap(data.OwnedRods),
		EquippedRod = data.EquippedRod,
		BaitInventory = playerData.shallowCopyMap(data.BaitInventory),
		EquippedBait = equippedBait,
		EquippedBaitRemaining = Bait.getRemainingForClient(data, equippedBait),
		UnlockedBiomes = playerData.shallowCopyMap(data.UnlockedBiomes),
		UnlockedIslands = playerData.shallowCopyMap(data.UnlockedBiomes),
		CurrentBiome = data.CurrentBiome,
		CurrentIsland = data.CurrentBiome,
		ActualBiome = getPlayerFishingBiome and getPlayerFishingBiome(player) or nil,
		ActualLocation = getPlayerTravelLocation and getPlayerTravelLocation(player) or nil,
		AutoFishEnabled = data.AutoFishEnabled,
		Fishdex = playerData.shallowCopyMap(data.Fishdex),
		FishdexTotal = GameConfig.getFishCount(),
		TotalFishCaught = data.TotalFishCaught or 0,
		Quests = Quest.getClientState(data),
		QuestUnclaimedCount = Quest.getUnclaimedCount(data),
		LoginRewards = LoginRewards.getClientState(data),
		Monetization = Monetization.getClientState(data),
		Aquarium = {
			Level = aquariumLevel,
			Capacity = GameConfig.AquariumCapacities[aquariumLevel] or GameConfig.AquariumCapacities[1],
			UsedCapacity = GameConfig.getAquariumUsedSpace(aquariumFish),
			Fish = playerData.copyArray(aquariumFish),
			LikeCount = aquariumLikeCount,
		},
		AquariumVisitors = aquariumVisitors,
		AquariumView = getLoadedAquariumViewState(player),
		AquariumDecorations = playerData.shallowCopyMap(data.AquariumDecorations),
		BestCatch = data.BestCatch,
	}
end

local function sendState(player)
	local data = playerData[player]
	if not data then
		return
	end

	local success, clientState = pcall(makeClientState, player, data)
	if not success then
		warn("Client state failed for", player.Name, clientState)
		return
	end

	Remote.StateUpdated:FireClient(player, clientState)
end

local function sendStateToAll()
	for _, player in ipairs(Services.Players:GetPlayers()) do
		sendState(player)
	end
end

Services.AquariumDirectory.configure({
	onChanged = function()
		sendStateToAll()
		-- Directory changes can alter the authoritative top-five pool or advance
		-- its rotation. Keep the physical centerpiece and Viewer data in sync.
		if playerData.refreshFeaturedAquarium then
			task.defer(playerData.refreshFeaturedAquarium)
		end
	end,
})
Services.AquariumDirectory.start()

function playerData.makeAquariumSnapshot(player, data)
	if not player or type(data) ~= "table" or type(data.Aquarium) ~= "table" then
		return nil
	end

	local level = math.clamp(tonumber(data.Aquarium.Level) or 1, 1, 4)
	local fish = type(data.Aquarium.Fish) == "table" and data.Aquarium.Fish or {}
	local totalValue = 0
	for _, displayedFish in ipairs(fish) do
		totalValue += math.max(0, tonumber(displayedFish.value) or 0)
	end

	return {
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = player.DisplayName,
		AquariumLevel = level,
		FishCount = #fish,
		UsedCapacity = GameConfig.getAquariumUsedSpace(fish),
		Capacity = GameConfig.AquariumCapacities[level] or GameConfig.AquariumCapacities[1],
		TotalValue = totalValue,
		LikeCount = math.max(0, math.floor(tonumber(data.Aquarium.LikeCount) or 0)),
		BestCatch = data.BestCatch and playerData.copyForSave(data.BestCatch) or nil,
		Aquarium = {
			Level = level,
			Fish = playerData.copyArray(fish),
			LikeCount = math.max(0, math.floor(tonumber(data.Aquarium.LikeCount) or 0)),
		},
		AquariumDesign = playerData.copyForSave(data.AquariumDesign),
		SeaStars = SeaStars.normalizeBalance(data.SeaStars),
		SeaStarUnlocks = playerData.shallowCopyMap(data.SeaStarUnlocks),
	}
end

local function notify(player, message)
	Remote.Notice:FireClient(player, message)
end

local function makeDefaultData()
	local data = {
		Coins = RuntimeConfig.getDefaultCoins(),
		XP = RuntimeConfig.getDefaultXP(),
		Level = 1,
		LevelProgressXP = 0,
		NextLevelXP = GameConfig.getXPForNextLevel(1),
		Inventory = {},
		BackpackSize = GameConfig.BASE_BACKPACK_SIZE,
		ResourceInventory = ResourceConfig.NormalizeInventory(nil),
		ResourcePity = 0,
		SeaStars = 0,
		SeaStarUnlocks = {},
		OwnedRods = {
			WoodenRod = true,
		},
		EquippedRod = "WoodenRod",
		BaitInventory = Bait.normalizeInventory(nil),
		EquippedBait = Bait.BasicId,
		OwnedGamePasses = Monetization.normalizeOwnedPasses(nil),
		ProcessedReceipts = {},
		LastVipRewardDate = "",
		LoginRewards = LoginRewardConfig.MakeDefault(),
		UnlockedBiomes = {
			[DEFAULT_FISHING_ISLAND_ID] = true,
		},
		CurrentBiome = DEFAULT_FISHING_ISLAND_ID,
		AutoFishEnabled = false,
		Fishdex = {},
		QuestState = {},
		Aquarium = {
			Level = 1,
			Fish = {},
			LikedBy = {},
			LikeCount = 0,
		},
		AquariumLikedTargets = {},
		AquariumDecorations = {},
		AquariumDesign = Monetization.normalizeAquariumDesign(nil),
		AquariumPreviewDesign = nil,
		BestCatch = nil,
		TotalFishCaught = 0,
	}

	Monetization.ensureState(data)
	Quest.ensureState(data)
	LoginRewards.ensureState(data)
	recalcLevel(data)
	return data
end

local function sanitizeLoadedData(loaded)
	local data = makeDefaultData()

	if type(loaded) ~= "table" then
		return data
	end

	data.Coins = math.max(0, math.floor(tonumber(loaded.Coins) or data.Coins))
	data.XP = GameConfig.clampXP(loaded.XP ~= nil and loaded.XP or data.XP)
	data.Inventory = type(loaded.Inventory) == "table" and loaded.Inventory or data.Inventory
	syncFishSerials(data)
	data.ResourceInventory = ResourceConfig.NormalizeInventory(loaded.ResourceInventory)
	data.ResourcePity = ResourceConfig.NormalizePity(loaded.ResourcePity)
	data.SeaStars = SeaStars.normalizeBalance(loaded.SeaStars)
	data.SeaStarUnlocks = SeaStars.normalizeUnlocks(loaded.SeaStarUnlocks)
	data.OwnedRods = normalizeOwnedRods(type(loaded.OwnedRods) == "table" and loaded.OwnedRods or data.OwnedRods)
	data.BaitInventory = Bait.normalizeInventory(loaded.BaitInventory)
	data.EquippedBait = Bait.normalizeId(loaded.EquippedBait)
	data.OwnedGamePasses = Monetization.normalizeOwnedPasses(loaded.OwnedGamePasses)
	data.ProcessedReceipts = type(loaded.ProcessedReceipts) == "table" and loaded.ProcessedReceipts or data.ProcessedReceipts
	data.LastVipRewardDate = type(loaded.LastVipRewardDate) == "string" and loaded.LastVipRewardDate or data.LastVipRewardDate
	data.LoginRewards = LoginRewardConfig.Normalize(loaded.LoginRewards)

	local equippedRod = normalizeRodId(loaded.EquippedRod)
	data.EquippedRod = GameConfig.Rods[equippedRod] and equippedRod or data.EquippedRod
	data.UnlockedBiomes = IslandConfig.normalizeUnlockedBiomes(loaded.UnlockedIslands or loaded.UnlockedBiomes or data.UnlockedBiomes)
	data.CurrentBiome = IslandConfig.normalizeBiomeId(loaded.CurrentIsland or loaded.CurrentBiome) or data.CurrentBiome
	data.AutoFishEnabled = loaded.AutoFishEnabled == true
	data.Fishdex = type(loaded.Fishdex) == "table" and loaded.Fishdex or data.Fishdex
	data.QuestState = type(loaded.QuestState) == "table" and loaded.QuestState or data.QuestState
	data.Aquarium = type(loaded.Aquarium) == "table" and loaded.Aquarium or data.Aquarium
	data.Aquarium.Level = math.clamp(tonumber(data.Aquarium.Level) or 1, 1, 4)
	data.Aquarium.Fish = type(data.Aquarium.Fish) == "table" and data.Aquarium.Fish or {}
	playerData.normalizeAquariumLikes(data.Aquarium)
	data.AquariumLikedTargets = {}
	if type(loaded.AquariumLikedTargets) == "table" then
		for rawTargetUserId, liked in pairs(loaded.AquariumLikedTargets) do
			local targetUserId = tonumber(rawTargetUserId)
			if liked == true
				and targetUserId
				and targetUserId == targetUserId
				and targetUserId > 0
				and targetUserId < math.huge
			then
				data.AquariumLikedTargets[tostring(math.floor(targetUserId))] = true
			end
		end
	end
	data.AquariumDecorations = type(loaded.AquariumDecorations) == "table" and loaded.AquariumDecorations or data.AquariumDecorations
	data.AquariumDesign = Monetization.normalizeAquariumDesign(loaded.AquariumDesign)
	data.AquariumPreviewDesign = nil
	data.BestCatch = type(loaded.BestCatch) == "table" and loaded.BestCatch or nil
	data.TotalFishCaught = math.max(0, math.floor(tonumber(loaded.TotalFishCaught) or 0))

	if not data.OwnedRods.WoodenRod then
		data.OwnedRods.WoodenRod = true
	end

	if not data.UnlockedBiomes[DEFAULT_FISHING_ISLAND_ID] then
		data.UnlockedBiomes[DEFAULT_FISHING_ISLAND_ID] = true
	end

	if not RodVisual.ownsRod(data, data.EquippedRod) then
		data.EquippedRod = "WoodenRod"
	end

	Bait.ensureState(data)
	Monetization.ensureState(data)
	Quest.ensureState(data)
	LoginRewards.ensureState(data)

	if not IslandConfig.isBiomeUnlocked(data, data.CurrentBiome) then
		data.CurrentBiome = DEFAULT_FISHING_ISLAND_ID
	end

	recalcLevel(data)
	return data
end

local function loadData(player)
	local lastError
	for attempt = 1, 3 do
		local success, loaded = pcall(function()
			return saveStore:GetAsync(tostring(player.UserId))
		end)
		if success then
			return sanitizeLoadedData(loaded)
		end
		lastError = loaded
		warn("Fishy Fish save load attempt failed for", player.UserId, attempt, loaded)
		if attempt < 3 then
			task.wait(attempt)
		end
	end

	if Services.RunService:IsStudio() then
		warn("Fishy Fish save load unavailable in Studio; using isolated Studio defaults for", player.UserId, lastError)
		return makeDefaultData()
	end

	warn("Fishy Fish save load failed; refusing to overwrite stored data for", player.UserId, lastError)
	player:Kick("Your fishing data could not be loaded safely. Please rejoin in a moment.")
	return nil
end

local function applyOwnerGrants(player, data)
	if not Services.RunService:IsStudio() or player.Name ~= RuntimeConfig.ownerUsername then
		return false
	end

	local currentCoins = tonumber(data.Coins) or 0
	if currentCoins >= RuntimeConfig.ownerCoinGrant then
		return false
	end

	data.Coins = RuntimeConfig.ownerCoinGrant
	return true
end

function RuntimeConfig.runEconomyPhaseStudioTests()
	local freshData = makeDefaultData()
	assert(freshData.Coins == 0, "Fresh Coins must be 0")
	assert(freshData.XP == 0 and freshData.Level == 1, "Fresh progression must be Level 1 with 0 XP")
	assert(freshData.EquippedRod == "WoodenRod", "WoodenRod must be equipped by default")
	assert(freshData.OwnedRods.WoodenRod == true and next(freshData.OwnedRods, "WoodenRod") == nil, "WoodenRod must be the only default rod")
	assert(freshData.UnlockedBiomes.LilyshoreIsland == true, "LilyshoreIsland must be unlocked by default")
	assert(freshData.UnlockedBiomes.RiverbendIsland ~= true and freshData.UnlockedBiomes.CoralCoastIsland ~= true, "Only LilyshoreIsland may be unlocked by default")
	assert(RuntimeConfig.studioTestOverridesEnabled == false and RuntimeConfig.studioGiveBeginnerFishInBag == false, "Studio overrides must be disabled by default")
	assert(GameConfig.clampXP(GameConfig.getMaxXP() + 100000) == GameConfig.getMaxXP(), "XP must clamp at the Level 30 threshold")
	assert(GameConfig.AquariumUpgradeCosts[2] == 1500 and GameConfig.AquariumUpgradeCosts[3] == 10000 and GameConfig.AquariumUpgradeCosts[4] == 40000, "Aquarium upgrade costs are incorrect")

	local function setOwnedBagPasses(smallOwned, mediumOwned, largeOwned)
		freshData.OwnedGamePasses = Monetization.normalizeOwnedPasses({
			SmallBag = smallOwned,
			MediumBag = mediumOwned,
			LargeBag = largeOwned,
		})
		Monetization.updateBackpackSize(freshData)
		return freshData.BackpackSize
	end

	assert(setOwnedBagPasses(false, false, false) == 30, "No bag pass must give 30 slots")
	assert(setOwnedBagPasses(true, false, false) == 60, "SmallBag must give 60 total slots")
	assert(setOwnedBagPasses(true, true, false) == 90, "MediumBag must override SmallBag at 90 total slots")
	assert(setOwnedBagPasses(true, true, true) == 150, "LargeBag must override all lower tiers at 150 total slots")

	local expectedCoinGrants = {
		StarterCoinPack = 1500,
		SmallCoinPack = 5000,
		MediumCoinPack = 15000,
		LargeCoinPack = 35000,
		HugeCoinPack = 80000,
	}
	for productKey, expectedAmount in pairs(expectedCoinGrants) do
		local product = Monetization.Config.DeveloperProducts[productKey]
		assert(product and product.coinAmount == expectedAmount, productKey .. " Coin grant is incorrect")
		assert(Monetization.Config.DeveloperProductById[product.id] == productKey, productKey .. " receipt mapping is missing")
	end
	assert(#Monetization.Config.DeveloperProductOrder == 0, "Lucky Bait products must be hidden from the normal shop")
	for _, productKey in ipairs({ "SmallLuckyBaitPack", "MediumLuckyBaitPack", "LargeLuckyBaitPack" }) do
		local product = Monetization.Config.DeveloperProducts[productKey]
		assert(product and product.shopVisible == false, productKey .. " must be hidden")
		assert(Monetization.Config.DeveloperProductById[product.id] == productKey, productKey .. " outstanding receipts must remain compatible")
	end
	local receiptTestData = { ProcessedReceipts = {} }
	assert(Monetization.tryMarkReceipt(receiptTestData, "economy-phase-test") == true, "First receipt attempt must be accepted")
	assert(Monetization.tryMarkReceipt(receiptTestData, "economy-phase-test") == false, "Duplicate receipt attempt must be rejected")

	local function verifyGeneratedQuestRewards(expectedTier)
		for _, periodName in ipairs(Quest.PeriodOrder) do
			local period = Quest.generatePeriod(freshData, periodName)
			local config = Quest.Configs[periodName]
			for index, quest in ipairs(period.quests) do
				local template = config.quests[index]
				local expectedCoins = math.round(EconomyConfig.EconomyValueForTier(expectedTier) * template.coinMultiplier)
				assert(quest.rewardTier == expectedTier and quest.reward.coins == expectedCoins, quest.id .. " generated the wrong tier reward")
			end
		end
	end

	freshData.UnlockedBiomes = { LilyshoreIsland = true }
	verifyGeneratedQuestRewards(1)
	local fixedDaily = Quest.generatePeriod(freshData, "Daily")
	local fixedReward = fixedDaily.quests[1].reward.coins
	freshData.QuestState.Daily = fixedDaily
	freshData.UnlockedBiomes.RiverbendIsland = true
	Quest.ensureState(freshData)
	assert(freshData.QuestState.Daily.quests[1].reward.coins == fixedReward, "Generated quest rewards must remain fixed")
	verifyGeneratedQuestRewards(2)
	freshData.UnlockedBiomes.CoralCoastIsland = true
	verifyGeneratedQuestRewards(3)

	freshData.OwnedGamePasses = Monetization.normalizeOwnedPasses({ VipAngler = true })
	freshData.Inventory = { { value = 40 }, { value = 60 } }
	assert(getInventoryValue(freshData) == 110, "VIP must apply one 10% bonus to the displayed and granted NPC fish-sale total")

	print("[FishyFish Economy Test] PASS: clean defaults, XP cap, fish values, quest snapshots, products, bag tiers, and VIP sale bonus")
end

if Services.RunService:IsStudio() then
	RuntimeConfig.runEconomyPhaseStudioTests()
end

function RuntimeConfig.runEconomyPhase3StudioTests()
	local freshData = makeDefaultData()
	assert(freshData.SeaStars == 0 and next(freshData.SeaStarUnlocks) == nil, "Sea Star defaults are incorrect")
	assert(SeaStars.normalizeBalance(-100) == 0, "Sea Stars must never sanitize below zero")
	assert(Monetization.Config.GamePasses.AquariumDesigner == nil, "Aquarium Designer Pass must be removed")
	for _, passKey in ipairs(Monetization.Config.GamePassOrder) do
		assert(passKey ~= "AquariumDesigner", "Aquarium Designer Pass order entry must be removed")
	end

	local expectedSeaStarProducts = {
		StarterSeaStars = { amount = 60, price = 49 },
		SmallSeaStars = { amount = 130, price = 99 },
		MediumSeaStars = { amount = 300, price = 199 },
		LargeSeaStars = { amount = 700, price = 399 },
		HugeSeaStars = { amount = 1500, price = 799 },
	}
	for productKey, expected in pairs(expectedSeaStarProducts) do
		local product = Monetization.Config.DeveloperProducts[productKey]
		assert(product and product.seaStarAmount == expected.amount and product.priceRobux == expected.price, productKey .. " configuration is incorrect")
		assert(product.catalogName == product.name, productKey .. " catalog discovery name is missing")
		if tonumber(product.id) then
			assert(product.id > 0 and Monetization.Config.DeveloperProductById[product.id] == productKey, productKey .. " resolved receipt mapping is missing")
		end
	end

	local expectedThemePrices = {
		Classic = 0,
		CoralReef = 60,
		ModernGlass = 60,
		DeepOcean = 100,
		JapaneseKoiPond = 140,
		PirateShip = 180,
		AncientRuins = 180,
	}
	for themeId, price in pairs(expectedThemePrices) do
		local theme = Monetization.Config.AquariumDesigner.themes[themeId]
		assert(theme and theme.id == themeId and theme.seaStarPrice == price, themeId .. " theme price is incorrect")
	end
	assert(SeaStars.ownsTheme(freshData, "Classic"), "Classic must be free")

	local themePlayer = { Name = "Phase3ThemeTest" }
	freshData.SeaStars = 60
	assert(SeaStars.tryAcquire(themePlayer), "Theme transaction lock must acquire")
	assert(not SeaStars.tryAcquire(themePlayer), "Theme transaction lock must reject concurrent work")
	local coralPrice = Monetization.Config.AquariumDesigner.themes.CoralReef.seaStarPrice
	freshData.SeaStars -= coralPrice
	freshData.SeaStarUnlocks.CoralReef = true
	SeaStars.release(themePlayer)
	assert(freshData.SeaStars == 0 and SeaStars.ownsTheme(freshData, "CoralReef"), "Theme purchase must deduct exactly once and unlock permanently")

	local marchState = LoginRewardConfig.Normalize({ CurrentDay = 11, DaysInCycle = 31, CycleMonthKey = "2026-03", LastClaimDate = "2026-03-10" }, { year = 2026, month = 4, day = 2, hour = 0, min = 0, sec = 0 })
	assert(marchState.CurrentDay == 11 and marchState.DaysInCycle == 31, "A March cycle must remain locked at 31 days")

	local loginData = makeDefaultData()
	loginData.LoginRewards = marchState
	local claimed, _, dayElevenReward = LoginRewards.claim(loginData, { year = 2026, month = 4, day = 2, hour = 12, min = 0, sec = 0 }, Random.new(3))
	assert(claimed and dayElevenReward.day == 11 and loginData.LoginRewards.CurrentDay == 12, "Missing dates must not reset, skip, or advance sequential progress")
	assert(not LoginRewards.claim(loginData, { year = 2026, month = 4, day = 2, hour = 20, min = 0, sec = 0 }, Random.new(4)), "Only one login claim is allowed per UTC date")

	local dayTwentyOneData = makeDefaultData()
	dayTwentyOneData.UnlockedBiomes.RiverbendIsland = true
	dayTwentyOneData.LoginRewards.CurrentDay = 21
	local dayTwentyOneClaimed, _, dayTwentyOneReward = LoginRewards.claim(dayTwentyOneData, { year = 2026, month = 7, day = 21, hour = 1, min = 0, sec = 0 }, Random.new(5))
	assert(dayTwentyOneClaimed and (dayTwentyOneReward.resources.OceanShard or 0) >= 1, "Riverbend Day 21 must guarantee an Ocean Shard")

	local finalData = makeDefaultData()
	finalData.LoginRewards.CurrentDay = finalData.LoginRewards.DaysInCycle
	local seaStarsBeforeFinal = finalData.SeaStars
	local finalClaimed, _, finalReward = LoginRewards.claim(finalData, { year = 2026, month = 7, day = 31, hour = 1, min = 0, sec = 0 }, Random.new(6))
	assert(finalClaimed and finalReward.isFinal and finalData.SeaStars == seaStarsBeforeFinal + 115, "Final claim must grant its Sea Stars plus the free-decoration fallback")
	assert(finalReward.decorationId == nil and finalReward.decorationFallbackSeaStars == 10, "Free decorations must not be granted as unlock rewards")
	for decorationId, decoration in pairs(Monetization.Config.AquariumDesigner.decorations) do
		if decorationId ~= "None" then
			assert(decoration.free == true and SeaStars.ownsDecoration(finalData, decorationId), decorationId .. " must be free for every player")
		end
	end
	assert(finalData.LoginRewards.CurrentDay == 1 and finalData.LoginRewards.LastClaimDate == "2026-07-31", "Completed cycle must reset sequential day but block a same-date claim")

	print("[FishyFish Economy Phase 3 Test] PASS: Sea Stars, products, free decor, theme ownership, UTC cycles, milestones, and resource guarantees")
end

if Services.RunService:IsStudio() then
	RuntimeConfig.runEconomyPhase3StudioTests()
end

function playerData.buildSavePayload(data)
	recalcLevel(data)
	Bait.ensureState(data)
	Monetization.ensureState(data)
	Quest.ensureState(data)
	LoginRewards.ensureState(data)

	return playerData.copyForSave({
		Coins = data.Coins,
		XP = data.XP,
		Inventory = data.Inventory,
		BackpackSize = data.BackpackSize,
		ResourceInventory = ResourceConfig.NormalizeInventory(data.ResourceInventory),
		ResourcePity = ResourceConfig.NormalizePity(data.ResourcePity),
		SeaStars = SeaStars.normalizeBalance(data.SeaStars),
		SeaStarUnlocks = SeaStars.normalizeUnlocks(data.SeaStarUnlocks),
		OwnedRods = data.OwnedRods,
		EquippedRod = data.EquippedRod,
		BaitInventory = data.BaitInventory,
		EquippedBait = data.EquippedBait,
		OwnedGamePasses = data.OwnedGamePasses,
		ProcessedReceipts = data.ProcessedReceipts,
		LastVipRewardDate = data.LastVipRewardDate,
		LoginRewards = LoginRewardConfig.Normalize(data.LoginRewards),
		UnlockedBiomes = data.UnlockedBiomes,
		UnlockedIslands = data.UnlockedBiomes,
		CurrentBiome = data.CurrentBiome,
		CurrentIsland = data.CurrentBiome,
		AutoFishEnabled = data.AutoFishEnabled,
		Fishdex = data.Fishdex,
		QuestState = data.QuestState,
		Aquarium = data.Aquarium,
		AquariumLikedTargets = data.AquariumLikedTargets,
		AquariumDecorations = data.AquariumDecorations,
		AquariumDesign = data.AquariumDesign,
		BestCatch = data.BestCatch,
		TotalFishCaught = data.TotalFishCaught,
	})
end

local function saveData(player)
	if Services.RunService:IsStudio() then
		return true
	end

	while playerData.SaveLocks[player] do
		task.wait()
	end
	local data = playerData[player]
	if not data then
		return false
	end
	playerData.SaveLocks[player] = true
	local success, err = xpcall(function()
		local savePayload = playerData.buildSavePayload(data)
		saveStore:UpdateAsync(tostring(player.UserId), function()
			return savePayload
		end)
	end, debug.traceback)
	playerData.SaveLocks[player] = nil

	if not success then
		warn("Fishy Fish save failed for", player.UserId, err)
	end
	return success
end

function playerData.queueSave(player)
	if Services.RunService:IsStudio() or not playerData[player] then
		return
	end

	playerData.SaveRevision[player] = (playerData.SaveRevision[player] or 0) + 1
	if playerData.SaveScheduled[player] then
		return
	end

	playerData.SaveScheduled[player] = true
	task.delay(5, function()
		playerData.SaveScheduled[player] = nil
		if not playerData[player] then
			return
		end

		local targetRevision = playerData.SaveRevision[player] or 0
		local saved = saveData(player)
		if playerData[player] and (not saved or (playerData.SaveRevision[player] or 0) > targetRevision) then
			playerData.queueSave(player)
		end
	end)
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
	local fishCaught = leaderstats:FindFirstChild("Fish Caught")

	if coins then
		coins.Value = data.Coins
	end

	if level then
		level.Value = data.Level
	end

	if fishCaught then
		fishCaught.Value = data.TotalFishCaught or 0
	end
end

local function sellAllFishForPlayer(player)
	local data = playerData[player]
	if not data then
		return false
	end

	local total = getInventoryValue(data)
	if total <= 0 then
		notify(player, "No fish to sell.")
		return false
	end

	data.Inventory = {}
	data.Coins += total

	updateLeaderstats(player)
	sendState(player)
	playerData.queueSave(player)
	notify(player, "Sold fish for " .. total .. " coins.")
	return true
end

local function connectSellFishPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") or prompt.Name ~= "SellFishPrompt" then
		return
	end

	prompt.Enabled = true

	if prompt:GetAttribute("FishyFishSellConnected") then
		return
	end

	prompt:SetAttribute("FishyFishSellConnected", true)
	prompt.Triggered:Connect(function(player)
		Remote.OpenSellFish:FireClient(player)
	end)
end

local function connectSellFishPrompts()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		connectSellFishPrompt(descendant)
	end
end

workspace.DescendantAdded:Connect(connectSellFishPrompt)

local function connectRodShopPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") or prompt.Name ~= "BuyRodPrompt" then
		return
	end

	prompt.ActionText = "Browse Supplies"
	prompt.ObjectText = "Supply Seller"
	prompt.Enabled = true

	if prompt:GetAttribute("FishyFishRodShopConnected") then
		return
	end

	prompt:SetAttribute("FishyFishRodShopConnected", true)
	prompt.Triggered:Connect(function(player)
		Remote.OpenRodShop:FireClient(player)
	end)
end

local function connectRodShopPrompts()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		connectRodShopPrompt(descendant)
	end
end

workspace.DescendantAdded:Connect(connectRodShopPrompt)

local biomeWarpTouchCooldowns = {}

local function openBiomeWarpForPlayer(player)
	local now = os.clock()
	if biomeWarpTouchCooldowns[player] and now - biomeWarpTouchCooldowns[player] < 1.5 then
		return
	end

	biomeWarpTouchCooldowns[player] = now
	Remote.OpenBiomeWarp:FireClient(player, getPlayerFishingBiome and getPlayerFishingBiome(player) or nil)
end

local function connectBiomeWarpTouch(part)
	if not part:IsA("BasePart") then
		return
	end

	local lowerName = string.lower(part.Name)
	local isExplicitBiomeWarp = part:GetAttribute("TargetArea") == "BiomeWarp"
		or part.Name == "IslandWarpTrigger"
	local isFountainWater = string.find(lowerName, "fountain")
		and string.find(lowerName, "water")
		and not string.find(lowerName, "plaza")
		and not string.find(lowerName, "path")
		and not string.find(lowerName, "effect")
		and not string.find(lowerName, "trigger")
	if not isExplicitBiomeWarp and not isFountainWater then
		return
	end

	if part:GetAttribute("FishyFishBiomeWarpConnected") then
		return
	end

	part:SetAttribute("FishyFishBiomeWarpConnected", true)
	part.CanTouch = true
	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Services.Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		openBiomeWarpForPlayer(player)
	end)
end

local function connectBiomeWarpTouches()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		connectBiomeWarpTouch(descendant)
	end
end

workspace.DescendantAdded:Connect(connectBiomeWarpTouch)

local function ensureFountainBiomeWarpTrigger()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "FountainBiomeWarpTrigger" then
			descendant:Destroy()
		end
	end

	connectBiomeWarpTouches()
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

	local fishCaught = Instance.new("IntValue")
	fishCaught.Name = "Fish Caught"
	fishCaught.Parent = leaderstats
end

local function applyCharacterMonetizationVisuals(player)
	local data = playerData[player]
	local character = player.Character
	if not data or not character then
		return
	end

	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

	local existing = head:FindFirstChild("FishyFishVipTag")
	if existing then
		existing:Destroy()
	end

	if not Monetization.ownsPass(data, "VipAngler") then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FishyFishVipTag"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	-- The owner does not need their own overhead title obstructing the camera;
	-- every other client still sees the VIP Angler tag normally.
	billboard.PlayerToHideFrom = player
	billboard.Size = UDim2.new(0, 130, 0, 42)
	billboard.StudsOffset = Vector3.new(0, 2.45, 0)
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = "VIP Angler"
	label.TextColor3 = Color3.fromRGB(255, 219, 82)
	label.TextStrokeColor3 = Color3.fromRGB(65, 42, 0)
	label.TextStrokeTransparency = 0.1
	label.TextScaled = true
	label.Parent = billboard
end

local function getRodTemplateFolder()
	local folder = Services.ServerStorage:FindFirstChild(RodVisual.TemplateFolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = RodVisual.TemplateFolderName
		folder.Parent = Services.ServerStorage
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

function RodVisual.getTemplatePriority(template)
	local normalized = normalizeTemplateName(template.Name)
	if string.find(normalized, "split") or normalized == "bluegillnew" or normalized == "bassnew" then
		return 100
	end

	return 0
end

local function storeRodTemplate(template, rodId, priority)
	local folder = getRodTemplateFolder()
	local stored = folder:FindFirstChild(rodId)
	priority = tonumber(priority) or RodVisual.getTemplatePriority(template)
	if stored and stored ~= template then
		local storedPriority = tonumber(stored:GetAttribute("TemplatePriority")) or 0
		if storedPriority > priority then
			return stored
		end

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
	model:SetAttribute("TemplatePriority", priority)
	prepareStoredRodTemplate(model)
	model.Parent = folder
	model:PivotTo(CFrame.new(0, -1000, 0))
	return model
end

function RodVisual.cloneTemplateIntoCache(template, rodId, priority)
	local folder = getRodTemplateFolder()
	local stored = folder:FindFirstChild(rodId)
	priority = tonumber(priority) or RodVisual.getTemplatePriority(template)
	if stored then
		local storedPriority = tonumber(stored:GetAttribute("TemplatePriority")) or 0
		if storedPriority > priority then
			return stored
		end

		stored:Destroy()
	end

	local model
	if template:IsA("Model") then
		model = template:Clone()
	elseif template:IsA("BasePart") then
		model = Instance.new("Model")
		template:Clone().Parent = model
	else
		return nil
	end

	model.Name = rodId
	model:SetAttribute("TemplatePriority", priority)
	model:SetAttribute("SourceTemplateName", template.Name)
	prepareStoredRodTemplate(model)
	model.Parent = folder
	model:PivotTo(CFrame.new(0, -1000, 0))
	return model
end

local function cacheRodTemplates()
	local folder = getRodTemplateFolder()

	for _, container in ipairs({ workspace, Services.ReplicatedStorage }) do
		for _, descendant in ipairs(container:GetDescendants()) do
			local splitTemplateName = require(script.Parent:WaitForChild("EarlyModelMigrationService"))
				.getImportedSplitRodTemplateName(descendant)
			if splitTemplateName then
				local rodId = getRodIdForTemplate({ Name = splitTemplateName })
				if rodId then
					RodVisual.cloneTemplateIntoCache(descendant, rodId, 100)
				end
			end
		end

		for rodId, templateNames in pairs(ROD_TEMPLATE_NAMES_BY_ROD) do
			if not folder:FindFirstChild(rodId) then
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
	end

	return folder
end

local function watchRodTemplateModels()
	local function tryStore(instance)
		if instance.Name == "RodVisual" or instance:FindFirstAncestorOfClass("Tool") then
			return
		end

		-- Keep the separate one-piece asset collection intact, but do not use it
		-- for equipped tools. The restored v1636 split wrappers are the intended
		-- in-hand rod visuals for all five rods.
		local assets = Services.ReplicatedStorage:FindFirstChild("Assets")
		local authoredRods = assets and assets:FindFirstChild("Rods")
		if authoredRods and instance:IsDescendantOf(authoredRods) then
			return
		end

		local template = getRodTemplateCandidate(instance)
		if not template then
			return
		end

		local rodId = getRodIdForTemplate(template) or getRodIdForTemplate(instance)
		if rodId then
			local splitTemplateName = require(script.Parent:WaitForChild("EarlyModelMigrationService"))
				.getImportedSplitRodTemplateName(template)
			if splitTemplateName then
				RodVisual.cloneTemplateIntoCache(template, rodId, 100)
			else
				storeRodTemplate(template, rodId)
			end
		end
	end

	for _, container in ipairs({ workspace, Services.ReplicatedStorage }) do
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
	local stored = folder:FindFirstChild(rodId)

	if rodId == "WoodenRod" then
		for _, container in ipairs({ workspace, Services.ReplicatedStorage, Services.ServerStorage }) do
			for _, templateName in ipairs({ "WoodenRod_Split2", "WoodenRod_split", "woodenrodsplit2", "woodenrodsplit" }) do
				local candidate = container:FindFirstChild(templateName, true)
				local template = candidate and getRodTemplateCandidate(candidate)
				if template then
					return RodVisual.cloneTemplateIntoCache(template, rodId, 1000)
				end
			end
		end
	end

	if rodId == "IronRod" then
		for _, container in ipairs({ workspace, Services.ReplicatedStorage, Services.ServerStorage }) do
			for _, templateName in ipairs({ "IronRod_Split", "IronRod_Split2", "ironrodsplit", "ironrodsplit2" }) do
				local candidate = container:FindFirstChild(templateName, true)
				local template = candidate and getRodTemplateCandidate(candidate)
				if template then
					return RodVisual.cloneTemplateIntoCache(template, rodId, 1000)
				end
			end
		end
	end

	if rodId == "GoldenRod" then
		for _, container in ipairs({ workspace, Services.ReplicatedStorage, Services.ServerStorage }) do
			for _, templateName in ipairs({ "GoldenRod_Split", "GoldenRod_Split2", "goldenrodsplit", "goldenrodsplit2" }) do
				local candidate = container:FindFirstChild(templateName, true)
				local template = candidate and getRodTemplateCandidate(candidate)
				if template then
					return RodVisual.cloneTemplateIntoCache(template, rodId, 1000)
				end
			end
		end
	end

	if rodId == "EmeraldRod" then
		for _, container in ipairs({ workspace, Services.ReplicatedStorage, Services.ServerStorage }) do
			for _, templateName in ipairs({ "EmeraldRod_Split", "EmeraldRod_Split2", "emeraldrodsplit", "emeraldrodsplit2" }) do
				local candidate = container:FindFirstChild(templateName, true)
				local template = candidate and getRodTemplateCandidate(candidate)
				if template then
					return RodVisual.cloneTemplateIntoCache(template, rodId, 1000)
				end
			end
		end
	end

	if rodId == "OceanRod" then
		for _, container in ipairs({ workspace, Services.ReplicatedStorage, Services.ServerStorage }) do
			for _, templateName in ipairs({ "OceanRod_Split", "OceanRod_Split2", "oceanrodsplit", "oceanrodsplit2" }) do
				local candidate = container:FindFirstChild(templateName, true)
				local template = candidate and getRodTemplateCandidate(candidate)
				if template then
					return RodVisual.cloneTemplateIntoCache(template, rodId, 1000)
				end
			end
		end
	end

	cacheRodTemplates()

	for _, container in ipairs({ Services.ServerStorage, Services.ReplicatedStorage, workspace }) do
		for _, templateName in ipairs(ROD_TEMPLATE_NAMES_BY_ROD[rodId] or {}) do
			local candidate = container:FindFirstChild(templateName, true)
			local template = candidate and getRodTemplateCandidate(candidate)
			if template then
				return storeRodTemplate(template, rodId)
			end
		end
	end

	stored = folder:FindFirstChild(rodId)
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
		return Vector3.new(minPoint.X + math.min(RodVisual.GripInset, size.X * 0.25), center.Y, center.Z), size.X
	elseif size.Y >= size.X and size.Y >= size.Z then
		return Vector3.new(center.X, minPoint.Y + math.min(RodVisual.GripInset, size.Y * 0.25), center.Z), size.Y
	else
		return Vector3.new(center.X, center.Y, minPoint.Z + math.min(RodVisual.GripInset, size.Z * 0.25)), size.Z
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

local function getBoundsCenter(minPoint, maxPoint)
	return (minPoint + maxPoint) * 0.5
end

local function getLongestBoundsAxis(minPoint, maxPoint)
	local size = maxPoint - minPoint
	return math.max(size.X, size.Y, size.Z)
end

local function getRodAlignmentPartGroups(baseParts)
	local handleParts = {}
	local bodyParts = {}

	for _, part in ipairs(baseParts) do
		local normalizedName = normalizeTemplateName(part.Name)
		if normalizedName == "rodhandle" or string.find(normalizedName, "handle") or string.find(normalizedName, "grip") then
			table.insert(handleParts, part)
		elseif normalizedName == "rodbody" or string.find(normalizedName, "body") or string.find(normalizedName, "shaft") then
			table.insert(bodyParts, part)
		end
	end

	return handleParts, bodyParts
end

local function isRodSwayPart(part, visualRoot)
	local current = part
	while current and current ~= visualRoot do
		local normalizedName = normalizeTemplateName(current.Name)
		if string.find(normalizedName, "bobber") or string.find(normalizedName, "string") then
			return true
		end
		current = current.Parent
	end
	return false
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
	elseif rodId == "GoldenRod" then
		return Color3.fromRGB(255, 191, 57), Enum.Material.Metal
	elseif rodId == "EmeraldRod" then
		return Color3.fromRGB(36, 190, 135), Enum.Material.Glass
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
	GoldenRod = {
		primary = Color3.fromRGB(255, 193, 45),
		secondary = Color3.fromRGB(164, 98, 20),
		accent = Color3.fromRGB(255, 236, 127),
		metal = Color3.fromRGB(70, 52, 30),
		material = Enum.Material.Metal,
	},
	EmeraldRod = {
		primary = Color3.fromRGB(26, 198, 139),
		secondary = Color3.fromRGB(10, 98, 77),
		accent = Color3.fromRGB(130, 255, 210),
		metal = Color3.fromRGB(38, 52, 55),
		material = Enum.Material.Glass,
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
	return RodVisual.AutoColorUntexturedImports
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
	local handleParts, bodyParts = getRodAlignmentPartGroups(baseParts)
	local sizeParts = #bodyParts > 0 and bodyParts or baseParts
	local gripParts = #handleParts > 0 and handleParts or sizeParts
	local tipParts = #bodyParts > 0 and bodyParts or baseParts

	local sizeMinPoint, sizeMaxPoint = getTemplateLocalBounds(sizeParts, pivot)
	local gripMinPoint, gripMaxPoint = getTemplateLocalBounds(gripParts, pivot)
	local tipMinPoint, tipMaxPoint = getTemplateLocalBounds(tipParts, pivot)
	local fallbackGripPoint = nil
	local fallbackLargestAxis = nil
	fallbackGripPoint, fallbackLargestAxis = getRodGripPoint(sizeMinPoint, sizeMaxPoint)
	local gripPoint = #handleParts > 0 and getBoundsCenter(gripMinPoint, gripMaxPoint) or fallbackGripPoint
	local largestAxis = getLongestBoundsAxis(sizeMinPoint, sizeMaxPoint)
	if largestAxis <= 0 then
		largestAxis = fallbackLargestAxis
	end
	local tipPoint = getRodTipPoint(tipMinPoint, tipMaxPoint)
	local scale = 1
	if largestAxis > 0 then
		scale = math.clamp(RodVisual.VisualLength / largestAxis, 0.01, RodVisual.MaxTemplateScale)
	end

	-- Rotate the imported model around its shaft independently of Tool.Grip so
	-- the reel faces the character's left without changing the hand placement.
	local targetPivot = handle.CFrame
		* CFrame.new(RodVisual.VisualOffset)
		* RodVisual.VisualRotation
		* RodVisual.ReelFacingRotation
	local tipWorldPosition = targetPivot:PointToWorldSpace((tipPoint - gripPoint) * scale)

	visual:ScaleTo(scale)
	visual:PivotTo(targetPivot * CFrame.new(gripPoint * -scale))

	local swayParts = {}
	for _, part in ipairs(baseParts) do
		if isRodSwayPart(part, visual) then
			swayParts[part] = true
		end
	end

	-- Imported GLTF models can contain their own rigid joints. Remove only
	-- joints attached to the string/bobber so the dedicated tip-pivot motors
	-- below are the sole constraints controlling those two visual parts.
	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("WeldConstraint") then
			if swayParts[descendant.Part0] or swayParts[descendant.Part1] then
				descendant:Destroy()
			end
		elseif descendant:IsA("JointInstance") then
			if swayParts[descendant.Part0] or swayParts[descendant.Part1] then
				descendant:Destroy()
			end
		end
	end

	local swayPivot = CFrame.new(tipWorldPosition) * targetPivot.Rotation

	for _, part in ipairs(baseParts) do
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true
		part.CanTouch = false
		part.CanQuery = false
		part.Transparency = 0
		if RodVisual.KeepImportedAppearance then
			if shouldAutoColorImportedRodPart(part) then
				autoColorImportedRodPart(part, rodId)
			end
		else
			styleRodPart(part, rodId)
		end

		if swayParts[part] then
			local swayJoint = Instance.new("Motor6D")
			swayJoint.Name = "FishingRodSwayJoint"
			swayJoint.Part0 = handle
			swayJoint.Part1 = part
			swayJoint.C0 = handle.CFrame:ToObjectSpace(swayPivot)
			swayJoint.C1 = part.CFrame:ToObjectSpace(swayPivot)
			swayJoint:SetAttribute("FishingRodSwayJoint", true)
			swayJoint.Parent = part
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
		end
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
	local lineEnd = lineStart + Vector3.new(0, -RodVisual.LineLength, -0.15)
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
	tool.Grip = FALLBACK_ROD_TOOL_GRIP

	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end

	clearFishingRodVisual(tool)

	if not RodVisual.Visuals3DEnabled then
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

	local templateRodId = RodVisual.UseWoodenShapeForAllRods and "WoodenRod" or rodId
	local template = RodVisual.ImportedModelsEnabled and findRodTemplate(templateRodId) or nil
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

	if attached then
		-- Match the imported model's real handle frame to the character's
		-- RightGripAttachment. Roblox applies Tool.Grip inversely, so using the
		-- same transform that places the visual handle cancels its model offset.
		tool.Grip = IMPORTED_ROD_TOOL_GRIP
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
	local existing = Services.StarterPack:FindFirstChild("Fishing Rod")
	if existing then
		existing:Destroy()
	end

	if not RodVisual.ToolsEnabled then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = "Fishing Rod"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Use the UI to fish on unlocked islands."
	tool.Grip = FALLBACK_ROD_TOOL_GRIP

	local handle
	if RodVisual.WoodenMeshId ~= "" then
		handle = Instance.new("MeshPart")
		handle.MeshId = RodVisual.WoodenMeshId
	else
		handle = Instance.new("Part")
		handle.Shape = Enum.PartType.Cylinder
	end

	handle.Name = "Handle"
	handle.CFrame = CFrame.Angles(0, 0, math.rad(90))
	handle.Parent = tool

	applyFishingRodVisual(tool, "WoodenRod")
	tool.Parent = Services.StarterPack
end

local HUD_ACCESS_TOOL_DEFINITIONS = {
	{
		name = "Bag",
		tooltip = "Open Bag",
		textureId = "rbxasset://textures/ui/Backpack/Backpack.png",
	},
	{
		name = "Fishdex",
		tooltip = "Open Fishdex",
		textureId = GameConfig.getFishImage("SmallFish") or "",
	},
}

local function makeHudAccessTool(definition)
	local tool = Instance.new("Tool")
	tool.Name = definition.name
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = definition.tooltip
	tool.TextureId = definition.textureId
	return tool
end

local function removeToolByName(container, toolName)
	if not container then
		return
	end

	local existing = container:FindFirstChild(toolName)
	if existing and existing:IsA("Tool") then
		existing:Destroy()
	end
end

local function createHudAccessTools()
	removeToolByName(Services.StarterPack, "Aquarium Viewer")

	for _, definition in ipairs(HUD_ACCESS_TOOL_DEFINITIONS) do
		removeToolByName(Services.StarterPack, definition.name)
		makeHudAccessTool(definition).Parent = Services.StarterPack
	end
end

local function playerHasHudAccessTool(player, toolName)
	for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		if container then
			local tool = container:FindFirstChild(toolName)
			if tool and tool:IsA("Tool") then
				return true
			end
		end
	end

	return false
end

local function ensureHudAccessToolsForPlayer(player)
	for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		removeToolByName(container, "Aquarium Viewer")
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return
	end

	for _, definition in ipairs(HUD_ACCESS_TOOL_DEFINITIONS) do
		if not playerHasHudAccessTool(player, definition.name) then
			local template = Services.StarterPack:FindFirstChild(definition.name)
			if not template or not template:IsA("Tool") then
				createHudAccessTools()
				template = Services.StarterPack:FindFirstChild(definition.name)
			end

			if template and template:IsA("Tool") then
				template:Clone().Parent = backpack
			else
				makeHudAccessTool(definition).Parent = backpack
			end
		end
	end
end

local function refreshFishingRodForPlayer(player, data)
	if not RodVisual.ToolsEnabled then
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

	local updatedTool = false
	for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		if container then
			local tool = container:FindFirstChild("Fishing Rod")
			if tool and tool:IsA("Tool") then
				applyFishingRodVisual(tool, rodId)
				updatedTool = true
			end
		end
	end

	if not updatedTool then
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			local template = Services.StarterPack:FindFirstChild("Fishing Rod")
			if not template then
				createFishingRodTool()
				template = Services.StarterPack:FindFirstChild("Fishing Rod")
			end

			if template and template:IsA("Tool") then
				local tool = template:Clone()
				tool.Parent = backpack
				applyFishingRodVisual(tool, rodId)
			end
		end
	end
end

function RodVisual.equipFishingRodToolForPlayer(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChild("Backpack")
	if not character or not humanoid or not backpack then
		return false
	end

	-- Re-equipping is intentional even when the rod was already held. Rebuilding
	-- an equipped Tool's visual does not always refresh its grip immediately,
	-- while the Bag access Tool also unequips everything when it opens.
	humanoid:UnequipTools()

	local tool = backpack:FindFirstChild("Fishing Rod")
	if not tool or not tool:IsA("Tool") then
		return false
	end

	humanoid:EquipTool(tool)
	return tool.Parent == character
end

function RodVisual.getHeldFishingRodTool(player, data)
	local character = player.Character
	local tool = character and character:FindFirstChild("Fishing Rod")
	if not tool or not tool:IsA("Tool") then
		return nil
	end

	local expectedRodId = data and data.EquippedRod
	if expectedRodId and tool:GetAttribute("RodId") ~= expectedRodId then
		return nil
	end

	return tool
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

local EditorVisuals = {
	folderNames = {
		RodshopTile = true,
		RodShopTile = true,
		SeasideshopTile = true,
		SeasideShopTile = true,
		["Left Wood Path"] = true,
		["Right Wood Path"] = true,
		LeftWoodPath = true,
		RightWoodPath = true,
	},
	solidDecorFolderNames = {
		LimestoneLobbySmallBeachDecor = true,
		LimestoneLobbySmallAnimalDecor = true,
		LimestoneLobbyOnePieceBeachDecor = true,
	},
	snapshots = {},
}

function EditorVisuals.getInstancePathKey(instance)
	local names = {}
	local current = instance
	while current and current ~= workspace do
		table.insert(names, 1, current.Name)
		current = current.Parent
	end

	return table.concat(names, "/")
end

function EditorVisuals.safeGetProperty(instance, propertyName)
	local success, value = pcall(function()
		return instance[propertyName]
	end)

	if success then
		return value
	end

	return nil
end

function EditorVisuals.safeSetProperty(instance, propertyName, value)
	if value == nil then
		return
	end

	pcall(function()
		instance[propertyName] = value
	end)
end

function EditorVisuals.capture()
	table.clear(EditorVisuals.snapshots)

	for _, folder in ipairs(workspace:GetDescendants()) do
		if (folder:IsA("Folder") or folder:IsA("Model")) and EditorVisuals.folderNames[folder.Name] then
			for _, descendant in ipairs(folder:GetDescendants()) do
				local key = EditorVisuals.getInstancePathKey(descendant)

				if descendant:IsA("BasePart") then
					EditorVisuals.snapshots[key] = {
						color = descendant.Color,
						material = descendant.Material,
						materialVariant = EditorVisuals.safeGetProperty(descendant, "MaterialVariant"),
						transparency = descendant.Transparency,
						reflectance = descendant.Reflectance,
					}
				elseif descendant:IsA("Texture") or descendant:IsA("Decal") then
					EditorVisuals.snapshots[key] = {
						color3 = descendant.Color3,
						texture = descendant.Texture,
						transparency = descendant.Transparency,
						studsPerTileU = EditorVisuals.safeGetProperty(descendant, "StudsPerTileU"),
						studsPerTileV = EditorVisuals.safeGetProperty(descendant, "StudsPerTileV"),
					}
				elseif descendant:IsA("SurfaceAppearance") then
					EditorVisuals.snapshots[key] = {
						colorMap = descendant.ColorMap,
						metalnessMap = descendant.MetalnessMap,
						normalMap = descendant.NormalMap,
						roughnessMap = descendant.RoughnessMap,
					}
				end
			end
		end
	end
end

function EditorVisuals.restore()
	for _, folder in ipairs(workspace:GetDescendants()) do
		if (folder:IsA("Folder") or folder:IsA("Model")) and EditorVisuals.folderNames[folder.Name] then
			for _, descendant in ipairs(folder:GetDescendants()) do
				local snapshot = EditorVisuals.snapshots[EditorVisuals.getInstancePathKey(descendant)]
				if snapshot then
					if descendant:IsA("BasePart") then
						descendant.Color = snapshot.color
						descendant.Material = snapshot.material
						EditorVisuals.safeSetProperty(descendant, "MaterialVariant", snapshot.materialVariant)
						descendant.Transparency = snapshot.transparency
						descendant.Reflectance = snapshot.reflectance
					elseif descendant:IsA("Texture") or descendant:IsA("Decal") then
						descendant.Color3 = snapshot.color3
						descendant.Texture = snapshot.texture
						descendant.Transparency = snapshot.transparency
						EditorVisuals.safeSetProperty(descendant, "StudsPerTileU", snapshot.studsPerTileU)
						EditorVisuals.safeSetProperty(descendant, "StudsPerTileV", snapshot.studsPerTileV)
					elseif descendant:IsA("SurfaceAppearance") then
						descendant.ColorMap = snapshot.colorMap
						descendant.MetalnessMap = snapshot.metalnessMap
						descendant.NormalMap = snapshot.normalMap
						descendant.RoughnessMap = snapshot.roughnessMap
					end
				end
			end
		end
	end
end

function EditorVisuals.ensureSmallDecorCollision()
	local function makeAnimalBlocker(root, target)
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

	for _, root in ipairs(workspace:GetDescendants()) do
		if (root:IsA("Folder") or root:IsA("Model")) and EditorVisuals.solidDecorFolderNames[root.Name] then
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
					makeAnimalBlocker(root, descendant)
				end
			end
		end
	end
end

function EditorVisuals.removeLegacyFishingHotspots()
	local world = workspace:FindFirstChild("FishyFishWorld")
	local worldFolder = world and world:FindFirstChild("FishingHotspots")
	if worldFolder then
		worldFolder:Destroy()
	end

	local workspaceFolder = workspace:FindFirstChild("FishingHotspots")
	if workspaceFolder then
		workspaceFolder:Destroy()
	end
end

local function ensureLobbyInvisibleBoundaries()
	-- Lobby boundaries are made in Studio so they stay visible/editable in the editor.
	-- Runtime only repairs collision settings on the saved boundary parts.
	for _, root in ipairs(workspace:GetDescendants()) do
		if (root:IsA("Folder") or root:IsA("Model")) and root.Name == "LimestoneLobbySafetyBorder" then
			for _, descendant in ipairs(root:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Transparency = 1
					descendant.CanCollide = true
					descendant.CanTouch = false
					descendant.CanQuery = true
					pcall(function()
						descendant.CollisionGroup = "Default"
					end)
				end
			end
		end
	end
end

local function getAquariumsFolder()
	-- The authored world is nested under 04_MiscMapObjects in the saved place.
	-- Looking only at Workspace's direct children caused Play mode to create a
	-- second FishyFishWorld and a second aquarium island.
	local world = workspace:FindFirstChild("FishyFishWorld", true)
	if not world then
		return nil
	end

	local folder = world:FindFirstChild("PersonalAquariums")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PersonalAquariums"
		folder.Parent = world
	end

	return folder
end

local function getAquariumSlotName(slot)
	return "AquariumViewerTank"
end

local function getAquariumSlotOrigin(slot)
	return AquariumLayout.AreaOrigin + AquariumLayout.ViewOffset
end

local function getPlayerAquariumSlot(player)
	playerAquariumSlots[player] = 1
	return 1
end

local function getPlayerAquariumOrigin(player)
	return getAquariumSlotOrigin(getPlayerAquariumSlot(player))
end

local function getPlayerAquariumTeleportPosition(player)
	local data = playerData[player]
	local level = data and data.Aquarium and data.Aquarium.Level or 1
	local tankDepth = 10 + ((level - 1) * 4)
	return getPlayerAquariumOrigin(player) + Vector3.new(0, 5, -(tankDepth / 2 + 16))
end

local function getAquariumHubTeleportPosition()
	return AquariumLayout.AreaOrigin + AquariumLayout.HubTeleportOffset
end

function AquariumLayout.findSpawnPart(names)
	if type(names) == "string" then
		names = { names }
	end

	local folder = getAquariumsFolder()
	if folder then
		for _, name in ipairs(names) do
			local part = folder:FindFirstChild(name, true)
			if part and part:IsA("BasePart") then
				return part
			end
		end
	end

	for _, name in ipairs(names) do
		local part = workspace:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end

	return nil
end

function AquariumLayout.getSpawnPosition(names, fallbackPosition, lift)
	local spawnPart = AquariumLayout.findSpawnPart(names)
	if spawnPart then
		return spawnPart.Position + Vector3.new(0, (spawnPart.Size.Y / 2) + (lift or 4), 0)
	end

	return fallbackPosition
end

function AquariumLayout.getHubSpawnPosition()
	return AquariumLayout.getSpawnPosition({ "AquariumHubSpawn", "HomeAquariumSpawn" }, getAquariumHubTeleportPosition(), 4)
end

function AquariumLayout.getViewerSpawnPosition(player)
	return AquariumLayout.getSpawnPosition({ "MyAquariumSpawn", "HomeAquariumSpawn" }, getPlayerAquariumTeleportPosition(player), 4)
end

function AquariumLayout.safePivotPlayer(player, cframe)
	local character = player.Character
	local timeoutAt = os.clock() + 5
	while player.Parent and not character and os.clock() < timeoutAt do
		task.wait(0.1)
		character = player.Character
	end

	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return false
	end

	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 4)
	end)

	root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	local pivotOk = pcall(function()
		character:PivotTo(cframe)
	end)
	if not pivotOk then
		root.CFrame = cframe
	end

	root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	task.defer(function()
		if root.Parent then
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
	end)

	return true
end

function AquariumLayout.startFallSafety()
	if AquariumLayout.FallSafetyStarted then
		return
	end

	AquariumLayout.FallSafetyStarted = true
	AquariumLayout.FallSafetyCooldowns = AquariumLayout.FallSafetyCooldowns or {}

	Services.RunService.Heartbeat:Connect(function()
		local bounds = AquariumLayout.FallSafetyBounds
		if not bounds then
			return
		end

		local now = os.clock()
		for _, player in ipairs(Services.Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local position = root.Position
				local withinAquariumArea = position.X >= bounds.minX
					and position.X <= bounds.maxX
					and position.Z >= bounds.minZ
					and position.Z <= bounds.maxZ

				if withinAquariumArea and position.Y < bounds.fallY then
					local lastTeleport = AquariumLayout.FallSafetyCooldowns[player] or 0
					if now - lastTeleport > 1.5 then
						AquariumLayout.FallSafetyCooldowns[player] = now
						Travel.teleportPlayer(player, "AquariumHub")
					end
				end
			end
		end
	end)
end

getAquariumVisitorsState = function(requestingPlayer)
	local visitors = {}
	local requestingData = playerData[requestingPlayer]
	local likedTargets = requestingData and requestingData.AquariumLikedTargets or {}

	for _, otherPlayer in ipairs(Services.Players:GetPlayers()) do
		local otherData = playerData[otherPlayer]
		if otherData and otherData.Aquarium then
			local level = otherData.Aquarium.Level or 1
			local capacity = GameConfig.AquariumCapacities[level] or GameConfig.AquariumCapacities[1]
			local fish = otherData.Aquarium.Fish or {}
			local _, likeCount = playerData.normalizeAquariumLikes(otherData.Aquarium)
			likeCount = Services.AquariumDirectory.getLikeCount(otherPlayer.UserId, likeCount)
			otherData.Aquarium.LikeCount = likeCount
			local totalValue = 0
			for _, displayedFish in ipairs(fish) do
				totalValue += math.max(0, tonumber(displayedFish.value) or 0)
			end
			table.insert(visitors, {
				UserId = otherPlayer.UserId,
				Name = otherPlayer.Name,
				DisplayName = otherPlayer.DisplayName,
				IsSelf = otherPlayer == requestingPlayer,
				Online = true,
				AquariumLevel = level,
				FishCount = #fish,
				UsedCapacity = GameConfig.getAquariumUsedSpace(fish),
				Capacity = capacity,
				TotalValue = totalValue,
				LikeCount = likeCount,
				LikedByViewer = likedTargets[tostring(otherPlayer.UserId)] == true,
				BestCatch = otherData.BestCatch and {
					id = otherData.BestCatch.id,
					imageKey = otherData.BestCatch.imageKey,
					name = otherData.BestCatch.name,
					value = otherData.BestCatch.value,
					rarity = otherData.BestCatch.rarity,
				} or nil,
			})
		end
	end

	table.sort(visitors, function(left, right)
		if left.IsSelf ~= right.IsSelf then
			return left.IsSelf
		end

		return string.lower(left.DisplayName or left.Name or "") < string.lower(right.DisplayName or right.Name or "")
	end)

	local success, directory = pcall(
		Services.AquariumDirectory.getDirectory,
		requestingPlayer,
		likedTargets,
		visitors
	)
	if success and type(directory) == "table" then
		return directory
	end
	if not success then
		warn("Aquarium directory state failed for", requestingPlayer.Name, directory)
	end
	return visitors
end

local function getAquariumDimensions(level)
	level = math.clamp(tonumber(level) or 1, 1, 4)
	local tankWidth = 24 + ((level - 1) * 8)
	local tankHeight = 10 + ((level - 1) * 2.5)
	local tankDepth = 10 + ((level - 1) * 4)

	return {
		level = level,
		tankWidth = tankWidth,
		tankHeight = tankHeight,
		tankDepth = tankDepth,
		baseWidth = tankWidth + 8,
		baseDepth = tankDepth + 8,
		glassY = 1 + (tankHeight / 2),
		waterY = 1 + (tankHeight * 0.78),
		topY = 1 + tankHeight + 0.3,
	}
end

local function ensureAquariumSharedLand(folder, minimumSlots)
	local activeGallery = workspace:FindFirstChild("AquariumGalleryPrototypeVisual")
	if activeGallery and activeGallery:IsA("Model") then
		AquariumLayout.FallSafetyBounds = nil
		return activeGallery
	end

	-- SharedAquariumShowcase is a Studio-authored map model. Reuse it exactly as
	-- saved instead of generating another showcase inside PersonalAquariums.
	local authoredShowcase = workspace:FindFirstChild("SharedAquariumShowcase", true)
	if authoredShowcase and not authoredShowcase:IsDescendantOf(folder) then
		AquariumLayout.FallSafetyBounds = nil
		return authoredShowcase
	end

	local center = AquariumLayout.AreaOrigin
	local viewOrigin = getAquariumSlotOrigin(1)
	local landWidth = 200
	local northEdge = center.Z - 88
	local southEdge = center.Z + 88
	local boundsDepth = southEdge - northEdge
	local boundsCenter = Vector3.new(center.X, 0, northEdge + (boundsDepth / 2))

	local function updateFallSafetyBounds()
		AquariumLayout.FallSafetyBounds = {
			minX = boundsCenter.X - (landWidth / 2),
			maxX = boundsCenter.X + (landWidth / 2),
			minZ = northEdge,
			maxZ = southEdge,
			fallY = -24,
		}
		AquariumLayout.startFallSafety()
	end

	local existing = folder:FindFirstChild("SharedAquariumShowcase")
	-- The saved Workspace model is authoritative. Do not regenerate the island
	-- just because an authored part was intentionally removed in Studio.
	if existing then
		local openPrompt = existing:FindFirstChild("OpenAquariumHubPrompt", true)
		if openPrompt and openPrompt:IsA("ProximityPrompt") then
			openPrompt.Enabled = false
		end
		updateFallSafetyBounds()
		return existing
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child.Name:match("^AquariumSlot_") or child.Name == "AquariumViewerTank" then
			child:Destroy()
		end
	end

	local showroom = Instance.new("Model")
	showroom.Name = "SharedAquariumShowcase"
	showroom:SetAttribute("HubVersion", 9)
	showroom.Parent = folder

	local sandColor = Color3.fromRGB(238, 224, 158)
	local grassColor = Color3.fromRGB(82, 164, 94)
	local stoneColor = Color3.fromRGB(102, 112, 116)
	local dockColor = Color3.fromRGB(126, 82, 44)
	local waterColor = Color3.fromRGB(24, 118, 184)

	local ocean = makePart(showroom, "AquariumIslandOcean", Vector3.new(200, 0.45, 180), center + Vector3.new(0, -1.35, 12), waterColor, Enum.Material.Water)
	ocean.Transparency = 0.08
	ocean.CanCollide = false
	ocean.CanTouch = false
	ocean.CanQuery = false

	local floor = makePart(showroom, "AquariumHubFloor", Vector3.new(1, 1, 1), center + Vector3.new(0, -8, 0), sandColor, Enum.Material.Sand)
	floor.Transparency = 1
	floor.CanCollide = false
	floor.CanTouch = false
	floor.CanQuery = false

	local function makeIslandRows(prefix, rows)
		for index, row in ipairs(rows) do
			makePart(showroom, prefix .. "Sand_" .. index, Vector3.new(row[3], 1.2, row[4]), center + Vector3.new(row[1], 0, row[2]), sandColor, Enum.Material.Sand)
		end
	end

	local function makeGrassPatch(name, offset, size)
		local patch = makePart(showroom, name, size, center + offset, grassColor, Enum.Material.Grass)
		patch.CanCollide = false
		return patch
	end

	makeIslandRows("AquariumViewerIsland", {
		{ 0, -50, 102, 12 },
		{ 0, -38, 136, 12 },
		{ 0, -26, 148, 12 },
		{ 0, -14, 152, 12 },
		{ 0, -2, 148, 12 },
		{ 0, 10, 140, 12 },
		{ 0, 22, 124, 12 },
		{ 0, 34, 100, 12 },
		{ 0, 46, 70, 12 },
	})
	makeGrassPatch("AquariumIslandGrass_Left", Vector3.new(-40, 0.72, -18), Vector3.new(34, 0.24, 24))
	makeGrassPatch("AquariumIslandGrass_Right", Vector3.new(40, 0.72, -14), Vector3.new(34, 0.24, 22))
	makeGrassPatch("AquariumIslandGrass_TankLeft", Vector3.new(-48, 0.72, 30), Vector3.new(22, 0.24, 18))
	makeGrassPatch("AquariumIslandGrass_TankRight", Vector3.new(48, 0.72, 30), Vector3.new(22, 0.24, 18))

	makePart(showroom, "AquariumIslandNorthStoneEdge", Vector3.new(90, 1.1, 3), center + Vector3.new(0, 0.35, -54), stoneColor, Enum.Material.Slate)
	makePart(showroom, "AquariumIslandWestStoneEdge", Vector3.new(3, 1.1, 64), center + Vector3.new(-76, 0.35, -16), stoneColor, Enum.Material.Slate)
	makePart(showroom, "AquariumIslandEastStoneEdge", Vector3.new(3, 1.1, 64), center + Vector3.new(76, 0.35, -16), stoneColor, Enum.Material.Slate)
	makePart(showroom, "AquariumIslandSouthStoneEdge", Vector3.new(70, 1.1, 3), center + Vector3.new(0, 0.35, 52), stoneColor, Enum.Material.Slate)

	local viewingDeck = makePart(showroom, "MainAquariumViewingDeck", Vector3.new(82, 0.55, 50), viewOrigin + Vector3.new(0, 0.95, -2), dockColor, Enum.Material.WoodPlanks)
	makePart(showroom, "MainAquariumViewingDeckTrim", Vector3.new(88, 0.25, 54), viewOrigin + Vector3.new(0, 1.24, -2), Color3.fromRGB(154, 101, 55), Enum.Material.WoodPlanks)
	makePart(showroom, "MainAquariumLeftRail", Vector3.new(1, 1.4, 48), viewOrigin + Vector3.new(-44, 2, -2), Color3.fromRGB(86, 58, 36), Enum.Material.Wood)
	makePart(showroom, "MainAquariumRightRail", Vector3.new(1, 1.4, 48), viewOrigin + Vector3.new(44, 2, -2), Color3.fromRGB(86, 58, 36), Enum.Material.Wood)
	makePart(showroom, "MainAquariumBackRail", Vector3.new(88, 1.4, 1), viewOrigin + Vector3.new(0, 2, 24), Color3.fromRGB(86, 58, 36), Enum.Material.Wood)

	local path = makePart(showroom, "AquariumHubToDisplayPath", Vector3.new(16, 0.28, 52), center + Vector3.new(0, 1.25, -13), Color3.fromRGB(150, 96, 52), Enum.Material.WoodPlanks)
	path.CanCollide = false

	local hubSpawn = makePart(showroom, "AquariumHubSpawn", Vector3.new(16, 1, 14), center + Vector3.new(0, 1.1, -28), Color3.fromRGB(80, 180, 255), Enum.Material.ForceField)
	hubSpawn.Transparency = 1
	hubSpawn.CanCollide = true
	hubSpawn.CanTouch = false
	hubSpawn.CanQuery = true
	local viewerSpawn = makePart(showroom, "MyAquariumSpawn", Vector3.new(16, 1, 14), center + Vector3.new(0, 1.1, -20), Color3.fromRGB(80, 180, 255), Enum.Material.ForceField)
	viewerSpawn.Transparency = 1
	viewerSpawn.CanCollide = true
	viewerSpawn.CanTouch = false
	viewerSpawn.CanQuery = true

	local kiosk = Instance.new("Model")
	kiosk.Name = "AquariumHubKiosk"
	kiosk.Parent = showroom

	local kioskBase = makePart(kiosk, "KioskStoneBase", Vector3.new(58, 1.2, 9), center + Vector3.new(0, 2.1, -42), Color3.fromRGB(82, 91, 96), Enum.Material.Slate)
	local kioskBoard = makePart(kiosk, "KioskMainBoard", Vector3.new(56, 15, 0.8), center + Vector3.new(0, 11, -46), Color3.fromRGB(10, 44, 76), Enum.Material.SmoothPlastic)
	kioskBoard.CFrame = CFrame.new(kioskBoard.Position) * CFrame.Angles(0, math.rad(180), 0)
	createLabel(kioskBoard, "Aquarium Viewer\nPress E or tap to open")

	local kioskHint = makePart(kiosk, "KioskHintPanel", Vector3.new(42, 3.2, 0.45), center + Vector3.new(0, 5.2, -45.35), Color3.fromRGB(35, 138, 190), Enum.Material.Glass)
	kioskHint.CFrame = CFrame.new(kioskHint.Position) * CFrame.Angles(0, math.rad(180), 0)
	kioskHint.Transparency = 0.08
	kioskHint.CanCollide = false
	createLabel(kioskHint, "Choose one aquarium at a time")

	local kioskPromptPart = makePart(kiosk, "AquariumHubKioskPrompt", Vector3.new(68, 14, 24), center + Vector3.new(0, 7, -30), Color3.fromRGB(45, 180, 240), Enum.Material.ForceField)
	kioskPromptPart.Transparency = 1
	kioskPromptPart.CanCollide = false
	kioskPromptPart.CanTouch = false
	kioskPromptPart.CanQuery = true
	kiosk.PrimaryPart = kioskBase

	local returnPortal = makePart(showroom, "ReturnToSeasideIslandPortal", Vector3.new(18, 6, 10), center + Vector3.new(50, 3.4, -42), Color3.fromRGB(78, 198, 245), Enum.Material.ForceField)
	returnPortal.Transparency = 0.55
	returnPortal.CanCollide = false
	returnPortal:SetAttribute("TargetArea", "Lobby")
	returnPortal:SetAttribute("PortalName", "Return to Seaside Island")
	Services.CollectionService:AddTag(returnPortal, "AreaPortal")
	local returnSign = makePart(showroom, "ReturnToSeasideIslandSign", Vector3.new(23, 4, 0.6), center + Vector3.new(50, 7.6, -48), Color3.fromRGB(12, 58, 86), Enum.Material.SmoothPlastic)
	returnSign.CFrame = CFrame.new(returnSign.Position) * CFrame.Angles(0, math.rad(180), 0)
	createLabel(returnSign, "Return to\nSeaside Island")

	local function makeLamp(name, position)
		local post = makePart(showroom, name .. "Post", Vector3.new(1, 8, 1), position + Vector3.new(0, 4, 0), Color3.fromRGB(86, 58, 36), Enum.Material.Wood)
		local lamp = makePart(showroom, name .. "Light", Vector3.new(2.4, 2.4, 2.4), position + Vector3.new(0, 8.6, 0), Color3.fromRGB(170, 235, 255), Enum.Material.Glass)
		lamp.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Brightness = 0.7
		glow.Range = 24
		glow.Color = Color3.fromRGB(120, 220, 255)
		glow.Parent = lamp
		return post
	end

	makeLamp("AquariumHubLamp_BackLeft", center + Vector3.new(-54, 0, -42))
	makeLamp("AquariumHubLamp_BackRight", center + Vector3.new(54, 0, -42))
	makeLamp("AquariumHubLamp_TankLeft", viewOrigin + Vector3.new(-50, 0, 14))
	makeLamp("AquariumHubLamp_TankRight", viewOrigin + Vector3.new(50, 0, 14))

	local function makePalm(name, origin)
		local trunk = makePart(showroom, name .. "Trunk", Vector3.new(2.2, 13, 2.2), origin + Vector3.new(0, 7, 0), Color3.fromRGB(111, 70, 39), Enum.Material.Wood)
		for index, leafSpec in ipairs({
			{ Vector3.new(0, 14.2, -4), Vector3.new(3, 0.8, 9), 0 },
			{ Vector3.new(0, 14.2, 4), Vector3.new(3, 0.8, 9), 0 },
			{ Vector3.new(-4, 14.2, 0), Vector3.new(9, 0.8, 3), 0 },
			{ Vector3.new(4, 14.2, 0), Vector3.new(9, 0.8, 3), 0 },
			{ Vector3.new(-3, 14.7, -3), Vector3.new(7, 0.8, 3), 45 },
			{ Vector3.new(3, 14.7, 3), Vector3.new(7, 0.8, 3), 45 },
		}) do
			local leaf = makePart(showroom, name .. "Leaf_" .. index, leafSpec[2], origin + leafSpec[1], grassColor, Enum.Material.Grass)
			leaf.CFrame = CFrame.new(leaf.Position) * CFrame.Angles(0, math.rad(leafSpec[3]), 0)
			leaf.CanCollide = false
		end
		trunk.CanCollide = true
	end

	makePalm("AquariumViewerPalmLeft", center + Vector3.new(-62, 0.6, 20))
	makePalm("AquariumViewerPalmRight", center + Vector3.new(62, 0.6, 6))

	local function makeInvisibleWall(name, size, position)
		local wall = makePart(showroom, name, size, position, Color3.fromRGB(255, 255, 255), Enum.Material.ForceField)
		wall.Transparency = 1
		wall.CanCollide = true
		wall.CanTouch = false
		wall.CanQuery = false
		return wall
	end

	updateFallSafetyBounds()
	local wallHeight = 42
	local wallThickness = 4
	local halfWidth = landWidth / 2
	makeInvisibleWall("InvisibleWall_North", Vector3.new(landWidth, wallHeight, wallThickness), Vector3.new(boundsCenter.X, wallHeight / 2, northEdge))
	makeInvisibleWall("InvisibleWall_South", Vector3.new(landWidth, wallHeight, wallThickness), Vector3.new(boundsCenter.X, wallHeight / 2, southEdge))
	makeInvisibleWall("InvisibleWall_West", Vector3.new(wallThickness, wallHeight, boundsDepth), Vector3.new(boundsCenter.X - halfWidth, wallHeight / 2, boundsCenter.Z))
	makeInvisibleWall("InvisibleWall_East", Vector3.new(wallThickness, wallHeight, boundsDepth), Vector3.new(boundsCenter.X + halfWidth, wallHeight / 2, boundsCenter.Z))
	local safetyFloor = makePart(showroom, "AquariumHubSafetyFloor", Vector3.new(landWidth, 2, boundsDepth), boundsCenter + Vector3.new(0, -5, 0), Color3.fromRGB(255, 255, 255), Enum.Material.ForceField)
	safetyFloor.Transparency = 1
	safetyFloor.CanCollide = true
	safetyFloor.CanTouch = false
	safetyFloor.CanQuery = false

	showroom.PrimaryPart = floor
	return showroom
end

local function getAquariumFishColor(fish)
	return GameConfig.RarityColors[fish.rarity] or Color3.fromRGB(110, 190, 255)
end

local function weldFishPart(root, part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function makeFishBlock(parent, root, name, size, localCFrame, color, scale, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Size = size * scale
	part.CFrame = root.CFrame * CFrame.new(localCFrame.Position * scale) * localCFrame.Rotation
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	weldFishPart(root, part)
	return part
end

local function getAquariumFishModelSpec(fish)
	local fishId = fish.id or fish.imageKey or ""
	if fishId == "" and type(fish.name) == "string" then
		fishId = fish.name:gsub("%s", "")
	end

	local specs = {
		SmallFish = {
			modelScale = 0.72,
			width = 0.72,
			height = 0.72,
			length = 0.8,
			head = Color3.fromRGB(55, 132, 160),
			mouth = Color3.fromRGB(230, 232, 226),
			back = Color3.fromRGB(18, 86, 112),
			side = Color3.fromRGB(83, 157, 188),
			shine = Color3.fromRGB(164, 209, 222),
			belly = Color3.fromRGB(218, 221, 213),
			bellyLight = Color3.fromRGB(242, 241, 233),
			tail = Color3.fromRGB(25, 91, 122),
			tailDark = Color3.fromRGB(18, 70, 96),
			fin = Color3.fromRGB(83, 157, 188),
			bottomFin = Color3.fromRGB(150, 176, 180),
			dorsal = "tall",
		},
		Carp = {
			modelScale = 1.08,
			width = 1.04,
			height = 0.95,
			length = 1.08,
			head = Color3.fromRGB(135, 121, 55),
			mouth = Color3.fromRGB(231, 205, 132),
			back = Color3.fromRGB(104, 86, 31),
			side = Color3.fromRGB(172, 145, 55),
			shine = Color3.fromRGB(213, 181, 74),
			belly = Color3.fromRGB(224, 203, 130),
			bellyLight = Color3.fromRGB(242, 228, 171),
			tail = Color3.fromRGB(202, 127, 34),
			tailDark = Color3.fromRGB(163, 93, 25),
			fin = Color3.fromRGB(200, 126, 36),
			bottomFin = Color3.fromRGB(137, 83, 28),
			barbels = true,
			scaleChecks = true,
		},
		Bluegill = {
			modelScale = 1,
			width = 1,
			height = 1,
			length = 1,
			head = Color3.fromRGB(95, 102, 54),
			mouth = Color3.fromRGB(229, 204, 144),
			back = Color3.fromRGB(62, 70, 42),
			side = Color3.fromRGB(90, 139, 154),
			shine = Color3.fromRGB(141, 180, 183),
			belly = Color3.fromRGB(206, 174, 91),
			bellyLight = Color3.fromRGB(229, 204, 144),
			tail = Color3.fromRGB(83, 109, 119),
			tailDark = Color3.fromRGB(56, 75, 84),
			fin = Color3.fromRGB(83, 109, 119),
			bottomFin = Color3.fromRGB(56, 75, 84),
			bluegillStripes = true,
		},
		Bass = {
			modelScale = 1.18,
			width = 1.02,
			height = 0.92,
			length = 1.18,
			head = Color3.fromRGB(92, 99, 49),
			mouth = Color3.fromRGB(232, 218, 151),
			back = Color3.fromRGB(49, 58, 31),
			side = Color3.fromRGB(126, 134, 61),
			shine = Color3.fromRGB(165, 164, 79),
			belly = Color3.fromRGB(221, 211, 147),
			bellyLight = Color3.fromRGB(244, 234, 180),
			tail = Color3.fromRGB(91, 99, 48),
			tailDark = Color3.fromRGB(57, 67, 37),
			fin = Color3.fromRGB(127, 126, 74),
			bottomFin = Color3.fromRGB(91, 99, 48),
			verticalBars = Color3.fromRGB(58, 66, 35),
			dorsal = "tall",
		},
		Catfish = {
			modelScale = 1.34,
			width = 1.03,
			height = 0.76,
			length = 1.42,
			head = Color3.fromRGB(62, 67, 72),
			mouth = Color3.fromRGB(206, 198, 184),
			back = Color3.fromRGB(43, 48, 54),
			side = Color3.fromRGB(83, 86, 89),
			shine = Color3.fromRGB(107, 109, 111),
			belly = Color3.fromRGB(169, 160, 144),
			bellyLight = Color3.fromRGB(220, 211, 197),
			tail = Color3.fromRGB(63, 68, 75),
			tailDark = Color3.fromRGB(42, 46, 51),
			fin = Color3.fromRGB(86, 89, 94),
			bottomFin = Color3.fromRGB(67, 69, 72),
			barbels = true,
			longBarbels = true,
			dorsal = "short",
		},
		GoldenCarp = {
			modelScale = 1.28,
			width = 1.06,
			height = 0.98,
			length = 1.14,
			head = Color3.fromRGB(236, 169, 0),
			mouth = Color3.fromRGB(255, 235, 118),
			back = Color3.fromRGB(223, 137, 0),
			side = Color3.fromRGB(255, 184, 0),
			shine = Color3.fromRGB(255, 226, 58),
			belly = Color3.fromRGB(255, 209, 75),
			bellyLight = Color3.fromRGB(255, 239, 137),
			tail = Color3.fromRGB(237, 145, 0),
			tailDark = Color3.fromRGB(201, 103, 0),
			fin = Color3.fromRGB(238, 130, 0),
			bottomFin = Color3.fromRGB(184, 92, 0),
			barbels = true,
			scaleChecks = true,
			goldGlow = true,
		},
		Koi = {
			modelScale = 1.25,
			width = 1.06,
			height = 0.98,
			length = 1.18,
			head = Color3.fromRGB(238, 82, 26),
			mouth = Color3.fromRGB(252, 228, 180),
			back = Color3.fromRGB(238, 82, 26),
			side = Color3.fromRGB(245, 242, 232),
			shine = Color3.fromRGB(255, 96, 48),
			belly = Color3.fromRGB(247, 244, 235),
			bellyLight = Color3.fromRGB(255, 250, 242),
			tail = Color3.fromRGB(246, 244, 236),
			tailDark = Color3.fromRGB(239, 77, 28),
			fin = Color3.fromRGB(247, 244, 236),
			bottomFin = Color3.fromRGB(227, 218, 205),
			barbels = true,
			koiPatches = true,
		},
		PondGuardian = {
			modelScale = 1.68,
			width = 1.12,
			height = 1.05,
			length = 1.42,
			head = Color3.fromRGB(25, 92, 94),
			mouth = Color3.fromRGB(202, 211, 198),
			back = Color3.fromRGB(14, 67, 70),
			side = Color3.fromRGB(35, 111, 114),
			shine = Color3.fromRGB(76, 151, 153),
			belly = Color3.fromRGB(143, 166, 158),
			bellyLight = Color3.fromRGB(206, 220, 210),
			tail = Color3.fromRGB(27, 104, 112),
			tailDark = Color3.fromRGB(16, 70, 78),
			fin = Color3.fromRGB(32, 111, 121),
			bottomFin = Color3.fromRGB(21, 83, 91),
			barbels = true,
			longBarbels = true,
			guardian = true,
			neon = Color3.fromRGB(85, 245, 255),
			gold = Color3.fromRGB(187, 151, 75),
		},
	}

	return specs[fishId] or specs.Bluegill
end

local function buildAquariumFishModel(model, root, fish, scale)
	local spec = getAquariumFishModelSpec(fish)
	local finalScale = scale * (spec.modelScale or 1)
	local width = spec.width or 1
	local height = spec.height or 1
	local length = spec.length or 1
	local rarityGlow = getAquariumFishColor(fish)

	local function size(x, y, z)
		return Vector3.new(x * width, y * height, z * length)
	end

	local function cf(x, y, z)
		return CFrame.new(x * width, y * height, z * length)
	end

	makeFishBlock(model, root, "Head", size(0.95, 0.9, 0.55), cf(0, 0.03, -0.92), spec.head, finalScale)
	makeFishBlock(model, root, "Mouth", size(0.55, 0.38, 0.3), cf(0, -0.16, -1.32), spec.mouth, finalScale)
	makeFishBlock(model, root, "Back", size(0.9, 0.36, 1.72), cf(0, 0.42, -0.08), spec.back, finalScale)
	makeFishBlock(model, root, "Side", size(0.98, 0.38, 1.82), cf(0, 0.05, 0.02), spec.side, finalScale)
	makeFishBlock(model, root, "SideShine", size(1.02, 0.16, 0.9), cf(0, 0.18, -0.14), spec.shine, finalScale)
	makeFishBlock(model, root, "Belly", size(0.82, 0.32, 1.62), cf(0, -0.35, 0), spec.belly, finalScale)
	makeFishBlock(model, root, "BellyLight", size(0.62, 0.18, 0.95), cf(0, -0.52, -0.14), spec.bellyLight, finalScale)

	if spec.bluegillStripes then
		for stripeIndex, stripeZ in ipairs({ -0.56, -0.18, 0.2, 0.58 }) do
			local stripeHeight = 0.42 - (stripeIndex * 0.03)
			makeFishBlock(model, root, "BluegillStripe", size(1.04, stripeHeight, 0.08), cf(0, 0.13, stripeZ), Color3.fromRGB(58, 93, 103), finalScale)
		end
	end

	if spec.verticalBars then
		for _, stripeZ in ipairs({ -0.72, -0.28, 0.16, 0.56, 0.9 }) do
			makeFishBlock(model, root, "BodyBar", size(1.04, 0.55, 0.09), cf(0, 0.08, stripeZ), spec.verticalBars, finalScale)
		end
	end

	if spec.scaleChecks then
		for row, y in ipairs({ 0.18, 0.02, -0.14 }) do
			for column, z in ipairs({ -0.48, -0.15, 0.18, 0.51, 0.84 }) do
				local color = (row + column) % 2 == 0 and spec.shine or spec.side
				makeFishBlock(model, root, "ScalePatch", size(0.26, 0.16, 0.12), cf(-0.01, y, z), color, finalScale)
			end
		end
	end

	if spec.koiPatches then
		for _, patch in ipairs({
			{ color = spec.head, x = 0, y = 0.3, z = -0.45, sx = 0.95, sy = 0.22, sz = 0.42 },
			{ color = spec.head, x = -0.08, y = 0.03, z = -0.08, sx = 1.03, sy = 0.3, sz = 0.36 },
			{ color = Color3.fromRGB(59, 61, 62), x = 0, y = 0.12, z = 0.28, sx = 1.04, sy = 0.32, sz = 0.22 },
			{ color = spec.head, x = 0.1, y = -0.18, z = 0.66, sx = 0.8, sy = 0.25, sz = 0.28 },
			{ color = Color3.fromRGB(50, 52, 54), x = 0, y = 0.03, z = 0.86, sx = 0.85, sy = 0.28, sz = 0.2 },
		}) do
			makeFishBlock(model, root, "KoiPatch", size(patch.sx, patch.sy, patch.sz), cf(patch.x, patch.y, patch.z), patch.color, finalScale)
		end
	end

	local dorsalBlocks = {
		Vector3.new(-0.25, 0.72, -0.55),
		Vector3.new(-0.1, 0.82, -0.22),
		Vector3.new(0.04, 0.77, 0.12),
		Vector3.new(0.17, 0.67, 0.46),
	}
	local dorsalHeight = spec.dorsal == "short" and 0.16 or 0.28
	if spec.dorsal == "tall" then
		dorsalHeight = 0.34
	end
	for _, ridge in ipairs(dorsalBlocks) do
		makeFishBlock(model, root, "DorsalBlock", size(0.42, dorsalHeight, 0.22), cf(ridge.X, ridge.Y, ridge.Z), spec.back, finalScale)
	end

	makeFishBlock(model, root, "TailStem", size(0.45, 0.46, 0.38), cf(0, -0.01, 1.02), spec.tail, finalScale)
	makeFishBlock(model, root, "TailTop", size(0.7, 0.42, 0.24), cf(0, 0.36, 1.32), spec.tail, finalScale)
	makeFishBlock(model, root, "TailMiddle", size(0.82, 0.38, 0.24), cf(0, 0, 1.42), spec.tailDark, finalScale)
	makeFishBlock(model, root, "TailBottom", size(0.7, 0.42, 0.24), cf(0, -0.36, 1.32), spec.tail, finalScale)
	makeFishBlock(model, root, "LeftFin", size(0.14, 0.3, 0.65), cf(-0.58, -0.18, -0.22) * CFrame.Angles(0, 0, math.rad(-18)), spec.fin, finalScale)
	makeFishBlock(model, root, "RightFin", size(0.14, 0.3, 0.65), cf(0.58, -0.18, -0.22) * CFrame.Angles(0, 0, math.rad(18)), spec.fin, finalScale)
	makeFishBlock(model, root, "BottomFin", size(0.42, 0.18, 0.48), cf(0, -0.7, 0.28), spec.bottomFin, finalScale)
	makeFishBlock(model, root, "LeftEye", size(0.16, 0.2, 0.08), cf(-0.42, 0.18, -1.17), Color3.fromRGB(12, 13, 12), finalScale)
	makeFishBlock(model, root, "RightEye", size(0.16, 0.2, 0.08), cf(0.42, 0.18, -1.17), Color3.fromRGB(12, 13, 12), finalScale)

	if spec.barbels then
		local barbelColor = spec.guardian and (spec.neon or spec.mouth) or spec.mouth
		local barbelLength = spec.longBarbels and 0.9 or 0.55
		makeFishBlock(model, root, "LeftBarbel", size(0.06, 0.06, barbelLength), cf(-0.36, -0.25, -1.5) * CFrame.Angles(math.rad(8), math.rad(24), 0), barbelColor, finalScale, spec.guardian and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		makeFishBlock(model, root, "RightBarbel", size(0.06, 0.06, barbelLength), cf(0.36, -0.25, -1.5) * CFrame.Angles(math.rad(8), math.rad(-24), 0), barbelColor, finalScale, spec.guardian and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		makeFishBlock(model, root, "LowerBarbel", size(0.05, 0.05, barbelLength * 0.8), cf(-0.18, -0.48, -1.44) * CFrame.Angles(math.rad(-15), math.rad(12), 0), barbelColor, finalScale)
		makeFishBlock(model, root, "LowerBarbel", size(0.05, 0.05, barbelLength * 0.8), cf(0.18, -0.48, -1.44) * CFrame.Angles(math.rad(-15), math.rad(-12), 0), barbelColor, finalScale)
	end

	if spec.goldGlow then
		makeFishBlock(model, root, "GoldGlowScale", size(0.25, 0.14, 0.22), cf(0, 0.26, 0.04), Color3.fromRGB(255, 240, 54), finalScale, Enum.Material.Neon)
	end

	if spec.guardian then
		local neon = spec.neon
		local gold = spec.gold
		for _, crystal in ipairs({
			Vector3.new(-0.25, 1.05, -0.32),
			Vector3.new(0, 1.17, 0.05),
			Vector3.new(0.22, 1.02, 0.42),
		}) do
			makeFishBlock(model, root, "GlowCrystal", size(0.25, 0.55, 0.2), cf(crystal.X, crystal.Y, crystal.Z), neon, finalScale, Enum.Material.Neon)
		end
		for _, lightSpot in ipairs({
			Vector3.new(-0.36, 0.04, -0.2),
			Vector3.new(0.36, 0.02, 0.2),
			Vector3.new(-0.24, -0.22, 0.62),
			Vector3.new(0.22, 0.28, 0.82),
		}) do
			makeFishBlock(model, root, "GuardianGlow", size(0.16, 0.16, 0.16), cf(lightSpot.X, lightSpot.Y, lightSpot.Z), neon, finalScale, Enum.Material.Neon)
		end
		makeFishBlock(model, root, "GoldHeadBand", size(1.02, 0.12, 0.12), cf(0, 0.42, -0.75), gold, finalScale, Enum.Material.Metal)
		makeFishBlock(model, root, "GoldSideLine", size(0.08, 0.08, 1.38), cf(-0.56, 0.16, 0.25), gold, finalScale, Enum.Material.Metal)
		makeFishBlock(model, root, "GoldSideLine", size(0.08, 0.08, 1.38), cf(0.56, 0.16, 0.25), gold, finalScale, Enum.Material.Metal)
	end

	makeFishBlock(model, root, "RarityScale", size(0.2, 0.12, 0.2), cf(0, 0.26, -0.04), rarityGlow, finalScale, Enum.Material.Neon)
	return rarityGlow
end

local function getAquariumFishSwimLane(origin, index, dimensions)
	dimensions = dimensions or getAquariumDimensions(1)
	return Services.AquariumFishAnimator.getSwimLane(origin, index, dimensions)
end

local function animateAquariumFish(part, origin, index, seed, dimensions)
	dimensions = dimensions or getAquariumDimensions(1)
	return Services.AquariumFishAnimator.start(part, origin, index, seed, dimensions)
end

-- Maximum model dimension in studs for each storage tier. Aquarium fish are
-- normalized once, after their complete species model has been assembled.
local AQUARIUM_FISH_SIZE_BY_STORAGE = {
	[1] = 2.2,
	[2] = 3,
	[3] = 3.8,
	[4] = 4.6,
	[5] = 5.4,
	[10] = 12.5,
}

local function scaleAquariumFishToStorageSize(model, fish)
	local fishStorageSpace = GameConfig.getAquariumFishSpace(fish)
	local targetDimension = AQUARIUM_FISH_SIZE_BY_STORAGE[fishStorageSpace]
		or AQUARIUM_FISH_SIZE_BY_STORAGE[math.clamp(fishStorageSpace, 1, 5)]
		or AQUARIUM_FISH_SIZE_BY_STORAGE[1]
	local boundingSize = model:GetExtentsSize()
	local largestDimension = math.max(boundingSize.X, boundingSize.Y, boundingSize.Z)
	if largestDimension <= 0 then
		return 1
	end

	local uniformScale = targetDimension / largestDimension
	model:ScaleTo(model:GetScale() * uniformScale)
	model:SetAttribute("AquariumStorageSpace", fishStorageSpace)
	model:SetAttribute("AquariumTargetDimension", targetDimension)
	model:SetAttribute("AquariumUniformScaleMultiplier", uniformScale)
	return uniformScale
end

local function makeAquariumFish(parent, fish, origin, index, ownerUserId, dimensions)
	local lane = getAquariumFishSwimLane(origin, index, dimensions)

	local model = Instance.new("Model")
	model.Name = "AquariumFish_" .. tostring(fish.id or index)
	model.Parent = parent

	local startPosition = lane.center
	local root = Instance.new("Part")
	root.Name = "FishRoot"
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Transparency = 1
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.lookAt(startPosition, startPosition + Vector3.new(1, 0, 0))
	root.Parent = model

	local rarityGlow = nil
	local fishVisualId = tostring(fish.id or fish.imageKey or "")
	if fishVisualId == "SmallFish" then
		local overrideFolder = Services.ServerStorage:FindFirstChild("AquariumFishOverrides")
		local smallFishTemplate = if overrideFolder then overrideFolder:FindFirstChild("SmallFish") else nil
		if smallFishTemplate and smallFishTemplate:IsA("Model") then
			local visual = smallFishTemplate:Clone()
			visual.Name = "FishVisual"
			visual.Parent = model

			local parts = {}
			local largestPart = nil
			local largestVolume = 0
			for _, descendant in ipairs(visual:GetDescendants()) do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
					local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
					if volume > largestVolume then
						largestVolume = volume
						largestPart = descendant
					end
				end
			end

			if #parts > 0 then
				visual.PrimaryPart = visual.PrimaryPart or largestPart or parts[1]
				local yawDegrees = tonumber(smallFishTemplate:GetAttribute("FishVisualYawDegrees")) or 90
				visual:PivotTo(root.CFrame * CFrame.Angles(0, math.rad(yawDegrees), 0))
				for _, part in ipairs(parts) do
					part.Anchored = false
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					part.Massless = true
					weldFishPart(root, part)
				end
				rarityGlow = getAquariumFishColor(fish)
			else
				visual:Destroy()
			end
		end
	elseif fishVisualId == "Carp" then
		local visual = Instance.new("Model")
		visual.Name = "FishVisual"
		visual:SetAttribute("AquariumOnlyTemplate", true)
		visual.Parent = model

		local body = Instance.new("Part")
		body.Name = "Carp_Roblox_Baked"
		body.Anchored = false
		body.CanCollide = false
		body.CanTouch = false
		body.CanQuery = false
		body.Massless = true
		body.Size = Vector3.new(1, 1, 1)
		body.Color = Color3.new(1, 1, 1)
		body.Material = Enum.Material.SmoothPlastic
		body.CFrame = root.CFrame * CFrame.Angles(0, math.rad(90), 0)
		body.Parent = visual

		local mesh = Instance.new("SpecialMesh")
		mesh.Name = "CarpBakedMesh"
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = "rbxassetid://111989793998660"
		mesh.TextureId = "rbxassetid://93915793213981"
		local importedLongestAxis = 6.760799884796143
		local importedScale = 1 / importedLongestAxis
		mesh.Scale = Vector3.new(importedScale, importedScale, importedScale)
		mesh.Parent = body

		visual.PrimaryPart = body
		weldFishPart(root, body)
		rarityGlow = getAquariumFishColor(fish)
	elseif fishVisualId == "GoldenCarp" then
		local overrideFolder = Services.ServerStorage:FindFirstChild("AquariumFishOverrides")
		local goldenCarpTemplate = if overrideFolder then overrideFolder:FindFirstChild("GoldenCarp") else nil
		if goldenCarpTemplate and goldenCarpTemplate:IsA("Model") then
			local visual = goldenCarpTemplate:Clone()
			visual.Name = "FishVisual"
			visual.Parent = model

			local parts = {}
			local largestPart = nil
			local largestVolume = 0
			for _, descendant in ipairs(visual:GetDescendants()) do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
					local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
					if volume > largestVolume then
						largestVolume = volume
						largestPart = descendant
					end
				end
			end

			if #parts > 0 then
				visual.PrimaryPart = visual.PrimaryPart or largestPart or parts[1]
				local yawDegrees = tonumber(goldenCarpTemplate:GetAttribute("FishVisualYawDegrees")) or 90
				visual:PivotTo(root.CFrame * CFrame.Angles(0, math.rad(yawDegrees), 0))
				for _, part in ipairs(parts) do
					part.Anchored = false
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					part.Massless = true
					weldFishPart(root, part)
				end
				rarityGlow = getAquariumFishColor(fish)
			else
				visual:Destroy()
			end
		end
	elseif fishVisualId == "Koi" then
		local overrideFolder = Services.ServerStorage:FindFirstChild("AquariumFishOverrides")
		local koiTemplate = if overrideFolder then overrideFolder:FindFirstChild("Koi") else nil
		if koiTemplate and koiTemplate:IsA("Model") then
			local visual = koiTemplate:Clone()
			visual.Name = "FishVisual"
			visual.Parent = model

			local parts = {}
			local largestPart = nil
			local largestVolume = 0
			for _, descendant in ipairs(visual:GetDescendants()) do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
					local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
					if volume > largestVolume then
						largestVolume = volume
						largestPart = descendant
					end
				end
			end

			if #parts > 0 then
				visual.PrimaryPart = visual.PrimaryPart or largestPart or parts[1]
				local yawDegrees = tonumber(koiTemplate:GetAttribute("FishVisualYawDegrees")) or 90
				visual:PivotTo(root.CFrame * CFrame.Angles(0, math.rad(yawDegrees), 0))
				for _, part in ipairs(parts) do
					part.Anchored = false
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					part.Massless = true
					weldFishPart(root, part)
				end
				rarityGlow = getAquariumFishColor(fish)
			else
				visual:Destroy()
			end
		end
	elseif fishVisualId == "PondGuardian" then
		local overrideFolder = Services.ServerStorage:FindFirstChild("AquariumFishOverrides")
		local pondGuardianTemplate = if overrideFolder then overrideFolder:FindFirstChild("PondGuardian") else nil
		if not pondGuardianTemplate then
			pondGuardianTemplate = workspace:FindFirstChild("PondGuardian_New")
		end
		if pondGuardianTemplate and pondGuardianTemplate:IsA("Model") then
			local visual = pondGuardianTemplate:Clone()
			visual.Name = "FishVisual"
			visual.Parent = model

			local parts = {}
			local largestPart = nil
			local largestVolume = 0
			for _, descendant in ipairs(visual:GetDescendants()) do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
					local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
					if volume > largestVolume then
						largestVolume = volume
						largestPart = descendant
					end
				end
			end

			if #parts > 0 then
				visual.PrimaryPart = visual.PrimaryPart or largestPart or parts[1]
				local yawDegrees = tonumber(pondGuardianTemplate:GetAttribute("FishVisualYawDegrees")) or 90
				visual:PivotTo(root.CFrame * CFrame.Angles(0, math.rad(yawDegrees), 0))
				for _, part in ipairs(parts) do
					part.Anchored = false
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					part.Massless = true
					weldFishPart(root, part)
				end
				rarityGlow = getAquariumFishColor(fish)
			else
				visual:Destroy()
			end
		end
	elseif fishVisualId == "Catfish" then
		local overrideFolder = Services.ServerStorage:FindFirstChild("AquariumFishOverrides")
		local catfishTemplate = if overrideFolder then overrideFolder:FindFirstChild("Catfish") else nil
		if catfishTemplate and catfishTemplate:IsA("Model") then
			local visual = catfishTemplate:Clone()
			visual.Name = "FishVisual"
			visual.Parent = model

			local parts = {}
			local largestPart = nil
			local largestVolume = 0
			for _, descendant in ipairs(visual:GetDescendants()) do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
					local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
					if volume > largestVolume then
						largestVolume = volume
						largestPart = descendant
					end
				end
			end

			if #parts > 0 then
				visual.PrimaryPart = visual.PrimaryPart or largestPart or parts[1]
				local yawDegrees = tonumber(catfishTemplate:GetAttribute("FishVisualYawDegrees")) or 90
				visual:PivotTo(root.CFrame * CFrame.Angles(0, math.rad(yawDegrees), 0))
				for _, part in ipairs(parts) do
					part.Anchored = false
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					part.Massless = true
					weldFishPart(root, part)
				end
				rarityGlow = getAquariumFishColor(fish)
			else
				visual:Destroy()
			end
		end
	end

	local templateRoot = Services.ServerStorage:FindFirstChild(RodVisual.TemplateFolderName)
	local fishTemplate = if not rarityGlow and templateRoot then templateRoot:FindFirstChild(fishVisualId) else nil
	if not rarityGlow and fishTemplate and fishTemplate:IsA("Model") then
		local visual = fishTemplate:Clone()
		visual.Name = "FishVisual"
		visual.Parent = model

		local parts = {}
		local primaryPart = visual.PrimaryPart
		local largestPart = nil
		local largestVolume = 0
		for _, descendant in ipairs(visual:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
				local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
				if volume > largestVolume then
					largestVolume = volume
					largestPart = descendant
				end
			end
		end

		if #parts > 0 then
			visual.PrimaryPart = primaryPart or largestPart or parts[1]
			local yawDegrees = tonumber(fishTemplate:GetAttribute("FishVisualYawDegrees")) or 90
			visual:PivotTo(root.CFrame * CFrame.Angles(0, math.rad(yawDegrees), 0))
			for _, part in ipairs(parts) do
				part.Anchored = false
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
				weldFishPart(root, part)
			end
			rarityGlow = getAquariumFishColor(fish)
		else
			visual:Destroy()
		end
	end

	if not rarityGlow then
		if tostring(fish.id or fish.imageKey or "") == "Bass" then
			warn("[FishyFish] Bass template is missing; skipped deprecated procedural Bass fallback.")
			model:Destroy()
			return nil
		end
		rarityGlow = buildAquariumFishModel(model, root, fish, 1)
	end

	scaleAquariumFishToStorageSize(model, fish)
	model.PrimaryPart = root

	local light = Instance.new("PointLight")
	light.Brightness = 0.18
	light.Range = 4.5
	light.Color = rarityGlow
	light.Parent = root

	local animationSeed = ownerUserId + (index * 997)
	root:SetAttribute("AquariumFishIndex", index)
	root:SetAttribute("AquariumAnimationSeed", animationSeed)
	animateAquariumFish(root, origin, index, animationSeed, dimensions)
	return model
end

local function buildAquariumSlotModel(slot, ownerPlayer, ownerData, buildOffscreen)
	local folder
	if buildOffscreen then
		folder = Services.ServerStorage:FindFirstChild("AquariumRuntimeSources")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "AquariumRuntimeSources"
			folder.Parent = Services.ServerStorage
		end
	else
		folder = getAquariumsFolder()
	end
	if not folder then
		return
	end

	if not buildOffscreen then
		ensureAquariumSharedLand(folder, slot)
	end

	local modelName = getAquariumSlotName(slot)
	local existing = folder:FindFirstChild(modelName)
	if existing then
		existing:Destroy()
	end

	local origin = buildOffscreen and Vector3.zero or getAquariumSlotOrigin(slot)
	local aquariumLevel = ownerData and ownerData.Aquarium and ownerData.Aquarium.Level or 1
	local dimensions = getAquariumDimensions(aquariumLevel)
	local aquariumDesign = ownerData and Monetization.getActiveAquariumDesign(ownerData) or Monetization.normalizeAquariumDesign(nil)
	local designerConfig = Monetization.Config.AquariumDesigner
	local theme = designerConfig.themes[aquariumDesign.theme] or designerConfig.themes.Classic
	local backgroundOption = designerConfig.backgroundColors[aquariumDesign.backgroundColor]
	local lightingOption = designerConfig.lightingColors[aquariumDesign.lightingColor]
	local frameColor = theme.frameColor or Color3.fromRGB(38, 52, 68)
	local waterColor = theme.waterColor or Color3.fromRGB(50, 145, 220)
	local backgroundColor = (backgroundOption and backgroundOption.color) or theme.backgroundColor or Color3.fromRGB(95, 180, 210)
	local lightColor = (lightingOption and lightingOption.color) or Color3.fromRGB(255, 248, 216)
	local model = Instance.new("Model")
	model.Name = modelName
	model:SetAttribute("GalleryRuntimeSource", buildOffscreen == true)
	model:SetAttribute("SlotNumber", slot)
	model:SetAttribute("AquariumLevel", aquariumLevel)
	model:SetAttribute("AquariumTankWidth", dimensions.tankWidth)
	model:SetAttribute("AquariumTankHeight", dimensions.tankHeight)
	model:SetAttribute("AquariumTankDepth", dimensions.tankDepth)
	model:SetAttribute("AquariumFishOriginYOffsetFromBase", 2)
	model:SetAttribute("BackdropEnabled", aquariumDesign.backdropEnabled ~= false)
	if ownerPlayer then
		model:SetAttribute("OccupantUserId", ownerPlayer.UserId)
		model:SetAttribute("OccupantName", ownerPlayer.DisplayName)
	end
	model.Parent = folder

	local baseDrop = 2.8
	local base = makePart(model, "AquariumBase", Vector3.new(dimensions.baseWidth, 1, dimensions.baseDepth), origin + Vector3.new(0, 0.8 - baseDrop, 0), Color3.fromRGB(74, 82, 88), Enum.Material.Metal)
	makePart(model, "AquariumBaseTopPlate", Vector3.new(dimensions.tankWidth + 1, 0.24, dimensions.tankDepth + 1), origin + Vector3.new(0, 1.36, 0), Color3.fromRGB(132, 142, 150), Enum.Material.Metal)

	local halfWidth = dimensions.tankWidth / 2
	local halfDepth = dimensions.tankDepth / 2
	for _, glassPanel in ipairs({
		{ name = "GlassFront", size = Vector3.new(dimensions.tankWidth, dimensions.tankHeight, 0.25), offset = Vector3.new(0, dimensions.glassY, -halfDepth - 0.15) },
		{ name = "GlassBack", size = Vector3.new(dimensions.tankWidth, dimensions.tankHeight, 0.25), offset = Vector3.new(0, dimensions.glassY, halfDepth + 0.15) },
		{ name = "GlassLeft", size = Vector3.new(0.25, dimensions.tankHeight, dimensions.tankDepth), offset = Vector3.new(-halfWidth - 0.15, dimensions.glassY, 0) },
		{ name = "GlassRight", size = Vector3.new(0.25, dimensions.tankHeight, dimensions.tankDepth), offset = Vector3.new(halfWidth + 0.15, dimensions.glassY, 0) },
	}) do
		local panel = makePart(model, glassPanel.name, glassPanel.size, origin + glassPanel.offset, Color3.fromRGB(75, 165, 220), Enum.Material.Glass)
		panel.Transparency = 0.72
		panel.CanCollide = true
	end

	local background = makePart(model, "AquariumDesignerBackground", Vector3.new(dimensions.tankWidth - 1.2, dimensions.tankHeight - 1, 0.16), origin + Vector3.new(0, dimensions.glassY, halfDepth - 0.18), backgroundColor, Enum.Material.SmoothPlastic)
	background.Transparency = aquariumDesign.backdropEnabled ~= false and 0.08 or 1
	background.CanCollide = false

	local waterSurface = makePart(model, "AquariumWaterSurface", Vector3.new(dimensions.tankWidth - 2, 0.18, dimensions.tankDepth - 2), origin + Vector3.new(0, dimensions.waterY, 0), waterColor, Enum.Material.Glass)
	waterSurface.Transparency = 0.55
	waterSurface.CanCollide = false

	local aquariumLight = Instance.new("PointLight")
	aquariumLight.Name = "AquariumDesignerLight"
	aquariumLight.Brightness = 0.75
	aquariumLight.Range = math.max(dimensions.tankWidth, dimensions.tankDepth)
	aquariumLight.Color = lightColor
	aquariumLight.Parent = waterSurface

	for _, corner in ipairs({
		Vector3.new(-halfWidth, dimensions.glassY, -halfDepth), Vector3.new(halfWidth, dimensions.glassY, -halfDepth),
		Vector3.new(-halfWidth, dimensions.glassY, halfDepth), Vector3.new(halfWidth, dimensions.glassY, halfDepth),
	}) do
		makePart(model, "AquariumFramePost", Vector3.new(0.5, dimensions.tankHeight + 0.5, 0.5), origin + corner, frameColor, Enum.Material.Metal)
	end

	local function makeFrameRails(prefix, y)
		makePart(model, prefix .. "Front", Vector3.new(dimensions.tankWidth + 1, 0.5, 0.5), origin + Vector3.new(0, y, -halfDepth - 0.25), frameColor, Enum.Material.Metal)
		makePart(model, prefix .. "Back", Vector3.new(dimensions.tankWidth + 1, 0.5, 0.5), origin + Vector3.new(0, y, halfDepth + 0.25), frameColor, Enum.Material.Metal)
		makePart(model, prefix .. "Left", Vector3.new(0.5, 0.5, dimensions.tankDepth + 1), origin + Vector3.new(-halfWidth - 0.25, y, 0), frameColor, Enum.Material.Metal)
		makePart(model, prefix .. "Right", Vector3.new(0.5, 0.5, dimensions.tankDepth + 1), origin + Vector3.new(halfWidth + 0.25, y, 0), frameColor, Enum.Material.Metal)
	end

	makeFrameRails("AquariumTopFrame", dimensions.topY)
	makeFrameRails("AquariumBottomFrame", 1.05)
	require(script.Parent:WaitForChild("AquariumThemeService")).apply(
		model,
		aquariumDesign.theme,
		origin,
		dimensions,
		aquariumDesign.backdropEnabled ~= false
	)

	local sign = makePart(model, "AquariumOwnerSign", Vector3.new(math.min(dimensions.tankWidth, 30), 3.5, 0.5), origin + Vector3.new(0, dimensions.topY + 2.6, -halfDepth - 1.2), Color3.fromRGB(34, 40, 46), Enum.Material.SmoothPlastic)
	local signText = ownerPlayer and (ownerPlayer.DisplayName .. "'s Aquarium") or "Available Aquarium"
	if ownerPlayer and aquariumDesign.signText ~= "" then
		signText = aquariumDesign.signText
	end
	createLabel(sign, signText)

	local decorationsFolder = Instance.new("Folder")
	decorationsFolder.Name = "DesignerDecorations"
	decorationsFolder.Parent = model

	local function getDesignerSlotCenter(slotConfig)
		if slotConfig.offset then
			return origin + slotConfig.offset
		end

		local x = math.clamp(tonumber(slotConfig.x) or 0, -0.42, 0.42) * dimensions.tankWidth
		local y = 1 + (math.clamp(tonumber(slotConfig.y) or 0.12, 0.08, 0.82) * dimensions.tankHeight)
		local z = math.clamp(tonumber(slotConfig.z) or 0, -0.42, 0.42) * dimensions.tankDepth
		return origin + Vector3.new(x, y, z)
	end

	local function getDesignerSlotScale(slotConfig)
		local sizeScale = math.clamp(dimensions.tankWidth / 32, 0.72, 1.28)
		return sizeScale * math.clamp(tonumber(slotConfig.scale) or 1, 0.55, 1.35)
	end

	local function makeDesignerDecorationAt(decorationId, center, scale)
		local decoration = designerConfig.decorations[decorationId]
		if not decoration or decorationId == "None" then
			return
		end

		local color = decoration.color or Color3.fromRGB(160, 180, 190)
		local function addBubbleEmitter(parent)
			local bubbles = Instance.new("ParticleEmitter")
			bubbles.Name = "Bubbles"
			bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			bubbles.Rate = 8
			bubbles.Lifetime = NumberRange.new(1.8, 3.2)
			bubbles.Speed = NumberRange.new(0.5, 1.2)
			bubbles.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
			bubbles.Parent = parent
		end

		local function cloneImportedDecoration()
			local templateFolder = Services.ServerStorage:FindFirstChild(AQUARIUM_DECOR_TEMPLATE_FOLDER_NAME)
			local template = templateFolder and templateFolder:FindFirstChild(decorationId)
			if not template or not template:IsA("Model") then
				return false
			end

			local visual = template:Clone()
			visual.Name = decorationId
			visual:SetAttribute("DesignerDecorationTemplate", decorationId)
			visual.Parent = decorationsFolder

			local parts = {}
			for _, descendant in ipairs(visual:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
					descendant.CanCollide = false
					descendant.CanTouch = false
					descendant.CanQuery = true
					descendant.Massless = true
					table.insert(parts, descendant)
				end
			end

			if #parts == 0 then
				visual:Destroy()
				return false
			end

			local _, sourceSize = visual:GetBoundingBox()
			local largestAxis = math.max(sourceSize.X, sourceSize.Y, sourceSize.Z)
			local targetLargestAxis = AQUARIUM_DECOR_TEMPLATE_LARGEST_AXIS[decorationId] or 3.4
			if largestAxis <= 0 then
				visual:Destroy()
				return false
			end

			local scaled = pcall(function()
				visual:ScaleTo(visual:GetScale() * ((targetLargestAxis * scale) / largestAxis))
			end)
			if not scaled then
				visual:Destroy()
				return false
			end

			local boundsCFrame = visual:GetBoundingBox()
			visual:PivotTo(visual:GetPivot() + (center - boundsCFrame.Position))
			visual:PivotTo(
				CFrame.new(center)
					* CFrame.Angles(0, math.pi, 0)
					* CFrame.new(-center)
					* visual:GetPivot()
			)
			if decorationId == "Coral" then
				visual:PivotTo(
					CFrame.new(center)
						* CFrame.Angles(math.rad(43.92915394888073), 0, 0)
						* CFrame.new(-center)
						* visual:GetPivot()
				)
				local correctedBoundsCFrame = visual:GetBoundingBox()
				visual:PivotTo(visual:GetPivot() + (center - correctedBoundsCFrame.Position))
			end

			if decorationId == "BubbleMachine" then
				addBubbleEmitter(visual.PrimaryPart or parts[1])
			end
			return true
		end

		if cloneImportedDecoration() then
			return
		end

		local function placePart(name, size, offset, partColor, material)
			local position = center + (offset or Vector3.zero)
			local part = makePart(decorationsFolder, name, size, position, partColor or color, material or Enum.Material.SmoothPlastic)
			part.CanCollide = false
			return part
		end

		if decorationId == "Seaweed" then
			for stem = 1, 3 do
				placePart("Seaweed", Vector3.new(0.35, 3.2 + stem * 0.35, 0.35) * scale, Vector3.new((stem - 2) * 0.55 * scale, 1.2 * scale, 0), color, Enum.Material.Grass)
			end
		elseif decorationId == "TreasureChest" then
			placePart("TreasureChest", Vector3.new(3.6, 1.8, 2.4) * scale, Vector3.new(0, 0.5 * scale, 0), color, Enum.Material.Wood)
			placePart("TreasureBand", Vector3.new(3.8, 0.25, 0.3) * scale, Vector3.new(0, 1.1 * scale, -0.3 * scale), Color3.fromRGB(255, 210, 80), Enum.Material.Metal)
		elseif decorationId == "BubbleMachine" then
			local part = placePart("BubbleMachine", Vector3.new(2.2, 1.4, 2.2) * scale, Vector3.zero, color, Enum.Material.Metal)
			addBubbleEmitter(part)
		else
			placePart(decorationId, Vector3.new(2.8, 1.6, 2.2) * scale, Vector3.zero, color, Enum.Material.SmoothPlastic)
		end
	end

	local function makeDesignerDecoration(slotId, decorationId)
		local slotConfig = designerConfig.slots[slotId]
		if not slotConfig or (tonumber(slotConfig.level) or 1) > aquariumLevel then
			return
		end

		makeDesignerDecorationAt(decorationId, getDesignerSlotCenter(slotConfig), getDesignerSlotScale(slotConfig), 0)
	end

	local function getFreeDecorationCenter(item)
		local placement = designerConfig.freePlacement or {}
		local bounds = placement.bounds or {}
		-- The editor is a front-facing view, while the aquarium's world X axis is
		-- viewed from the opposite direction. Mirror X so screen-left stays left.
		local x = -math.clamp(tonumber(item.x) or 0, tonumber(bounds.xMin) or -0.42, tonumber(bounds.xMax) or 0.42) * dimensions.tankWidth
		local y = 1 + (math.clamp(tonumber(item.y) or 0.16, tonumber(bounds.yMin) or 0.08, tonumber(bounds.yMax) or 0.82) * dimensions.tankHeight)
		local z = math.clamp(tonumber(item.z) or 0, tonumber(bounds.zMin) or -0.42, tonumber(bounds.zMax) or 0.42) * dimensions.tankDepth
		return origin + Vector3.new(x, y, z)
	end

	local function getFreeDecorationScale(item)
		local sizeScale = math.clamp(dimensions.tankWidth / 32, 0.72, 1.28)
		return sizeScale * math.clamp(tonumber(item.scale) or 1, 0.55, 1.35)
	end

	local canShowSavedDecorations = ownerData ~= nil
	local canShowPreviewDecorations = ownerData and ownerData.AquariumPreviewDesign ~= nil
	if canShowSavedDecorations or canShowPreviewDecorations then
		for slotId, decorationId in pairs(aquariumDesign.decorations or {}) do
			makeDesignerDecoration(slotId, decorationId)
		end

		local maxFreeDecorations = (((designerConfig.freePlacement or {}).maxByLevel or {})[aquariumLevel]) or 0
		for index, item in ipairs(aquariumDesign.freeDecorations or {}) do
			if index > maxFreeDecorations then
				break
			end

			makeDesignerDecorationAt(item.decorationId, getFreeDecorationCenter(item), getFreeDecorationScale(item))
		end
	end

	local fishFolder = Instance.new("Folder")
	fishFolder.Name = "Fish"
	fishFolder.Parent = model

	if ownerData then
		local maxVisualFish = 24
		for index, fish in ipairs(ownerData.Aquarium.Fish) do
			if index > maxVisualFish then
				break
			end
			makeAquariumFish(fishFolder, fish, origin, index, ownerPlayer.UserId, dimensions)
		end
	end

	model.PrimaryPart = base
	return model
end

local function ensurePrebuiltAquariumSlots()
	local folder = getAquariumsFolder()
	if not folder then
		return
	end

	ensureAquariumSharedLand(folder, 1)
end

function playerData.showAquariumSnapshotInCenter(snapshot, labelPrefix)
	if type(snapshot) ~= "table" or type(snapshot.Aquarium) ~= "table" then
		return false
	end

	local userId = math.floor(tonumber(snapshot.UserId) or 0)
	if userId <= 0 then
		return false
	end
	local displayName = tostring(snapshot.DisplayName or snapshot.Name or ("Player " .. userId))
	local identity = {
		UserId = userId,
		Name = tostring(snapshot.Name or displayName),
		DisplayName = displayName,
	}
	local snapshotData = {
		Aquarium = playerData.copyForSave(snapshot.Aquarium),
		AquariumDesign = playerData.copyForSave(snapshot.AquariumDesign),
		SeaStars = SeaStars.normalizeBalance(snapshot.SeaStars),
		SeaStarUnlocks = type(snapshot.SeaStarUnlocks) == "table"
			and playerData.shallowCopyMap(snapshot.SeaStarUnlocks)
			or {},
		AquariumDecorations = {},
		BackpackSize = GameConfig.BASE_BACKPACK_SIZE,
	}
	local model = buildAquariumSlotModel(1, identity, snapshotData, true)
	if not model then
		return false
	end

	local displayed, displayError = pcall(function()
		return require(script.Parent:WaitForChild("AquariumGalleryPrototypeService"))
			.displayFeaturedAquarium(
				model,
				userId,
				string.upper(tostring(labelPrefix or "FEATURED")) .. " • " .. displayName
			)
	end)
	if not displayed or displayError ~= true then
		warn("Aquarium gallery featured display failed", displayError)
		return false
	end
	playerData.FeaturedCenterUserId = userId
	playerData.FeaturedCenterUpdatedAt = tonumber(snapshot.UpdatedAt) or 0
	return true
end

function playerData.refreshFeaturedAquarium(forceRefresh)
	local now = os.clock()
	local snapshot
	local labelPrefix = "FEATURED"
	if playerData.ManualFeaturedSnapshot and now < (playerData.ManualFeaturedUntil or 0) then
		snapshot = playerData.ManualFeaturedSnapshot
		labelPrefix = "NOW VIEWING"
	else
		playerData.ManualFeaturedSnapshot = nil
		playerData.ManualFeaturedUntil = nil
		snapshot = Services.AquariumDirectory.getFeaturedSnapshot()
	end
	if not snapshot then
		return false
	end

	local userId = math.floor(tonumber(snapshot.UserId) or 0)
	local updatedAt = tonumber(snapshot.UpdatedAt) or 0
	if not forceRefresh
		and userId == playerData.FeaturedCenterUserId
		and updatedAt == playerData.FeaturedCenterUpdatedAt
	then
		return true
	end
	return playerData.showAquariumSnapshotInCenter(snapshot, labelPrefix)
end

local function refreshPlayerAquarium(player)
	local data = playerData[player]
	if not data then
		return
	end

	ensurePrebuiltAquariumSlots()
	local slot = getPlayerAquariumSlot(player)
	local model = buildAquariumSlotModel(slot, player, data, true)
	if model then
		local galleryUpdated, galleryError = pcall(function()
			require(script.Parent:WaitForChild("AquariumGalleryPrototypeService"))
				.displayPlayerAquarium(player, model)
		end)
		if not galleryUpdated then
			warn("Aquarium gallery player display failed", galleryError)
		end

		local snapshot = playerData.makeAquariumSnapshot(player, data)
		if snapshot then
			local published, likeCount = Services.AquariumDirectory.publish(player, snapshot)
			if likeCount ~= nil then
				data.Aquarium.LikeCount = likeCount
			end
			if published == false and not Services.RunService:IsStudio() then
				warn("Aquarium directory publish failed for", player.Name)
			end
		end
		playerData.refreshFeaturedAquarium(true)
	end
	return model ~= nil
end

local function playerOwnsAssignedAquarium(player)
	local galleryOk, hasAssignedBay = pcall(function()
		return require(script.Parent:WaitForChild("AquariumGalleryPrototypeService"))
			.playerHasAssignedBay(player)
	end)
	if galleryOk and hasAssignedBay then
		return true
	end

	local folder = getAquariumsFolder()
	local slot = getPlayerAquariumSlot(player)
	local aquarium = folder and folder:FindFirstChild(getAquariumSlotName(slot))
	if not aquarium then
		return false
	end

	if aquarium:GetAttribute("OccupantUserId") ~= player.UserId then
		return false
	end

	return true
end

local function playerCanEditLoadedAquarium(player)
	return playerOwnsAssignedAquarium(player)
end

local function rejectAquariumEditIfViewOnly(player)
	if playerCanEditLoadedAquarium(player) then
		return false
	end

	notify(player, "This aquarium is view-only. Select My Aquarium to edit.")
	sendState(player)
	return true
end

local function buildCleanLobby(world)
	local block = 4
	local center = Vector3.new(-420, -2, 0)
	local minX = -40
	local maxX = 40
	local minZ = -34
	local maxZ = 34
	local portalCooldowns = {}

	local lobby = Instance.new("Model")
	lobby.Name = "LobbyArea"
	lobby.Parent = world

	local blocksFolder = Instance.new("Folder")
	blocksFolder.Name = "Blocks"
	blocksFolder.Parent = lobby

	local pathsFolder = Instance.new("Folder")
	pathsFolder.Name = "Paths"
	pathsFolder.Parent = lobby

	local structuresFolder = Instance.new("Folder")
	structuresFolder.Name = "Structures"
	structuresFolder.Parent = lobby

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = lobby

	local function makeStructureModel(name)
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = structuresFolder
		return model
	end

	local fountainModel = makeStructureModel("FountainBiomeWarp")
	local leaderboardModel = makeStructureModel("Leaderboard")
	local aquariumWarpModel = makeStructureModel("AquariumWarp")
	local spawnAreaModel = makeStructureModel("SpawnArea")
	local lanternsFolder = Instance.new("Folder")
	lanternsFolder.Name = "Lanterns"
	lanternsFolder.Parent = structuresFolder

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
		gui.CanvasSize = Vector2.new(800, 300)
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
	local aquariumColor = Color3.fromRGB(0, 190, 255)

	local function makeLantern(position, index)
		local lanternModel = makeStructureModel("Lantern_" .. tostring(index))
		lanternModel.Parent = lanternsFolder

		makeLobbyPart(lanternModel, "LanternPost", Vector3.new(0.8, 5, 0.8), position, woodDark, Enum.Material.Wood)

		local lantern = makeLobbyPart(
			lanternModel,
			"Lantern",
			Vector3.new(1.4, 1.4, 1.4),
			position + Vector3.new(0, 3.2, 0),
			Color3.fromRGB(210, 170, 95),
			Enum.Material.Glass,
			0.35,
			false
		)

		local light = Instance.new("PointLight")
		light.Brightness = 0.18
		light.Range = 9
		light.Color = Color3.fromRGB(255, 225, 160)
		light.Parent = lantern
		lanternModel.PrimaryPart = lantern
	end

	local function makeShopBuilding(name, gridX, gridZ, title, roofColor)
		local shopModel = Instance.new("Model")
		shopModel.Name = name
		shopModel.Parent = structuresFolder

		local footprint = {
			{ -2, -1 }, { -1, -1 }, { 0, -1 }, { 1, -1 }, { 2, -1 },
			{ -2, 0 }, { -1, 0 }, { 0, 0 }, { 1, 0 }, { 2, 0 },
			{ -2, 1 }, { -1, 1 }, { 0, 1 },
			{ -2, 2 }, { -1, 2 }, { 0, 2 },
		}

		for _, cell in ipairs(footprint) do
			makeLobbyPart(
				shopModel,
				name .. "_Floor",
				Vector3.new(block, 0.6, block),
				Vector3.new((gridX + cell[1]) * block, 3.1, (gridZ + cell[2]) * block),
				woodColor,
				Enum.Material.WoodPlanks
			)
		end

		makeLobbyPart(shopModel, name .. "_BackWall", Vector3.new(30, 12, 1), Vector3.new(gridX * block, 8.5, (gridZ + 2.9) * block), woodDark, Enum.Material.Wood)
		makeLobbyPart(shopModel, name .. "_SideWall", Vector3.new(1, 12, 22), Vector3.new((gridX - 3.1) * block, 8.5, (gridZ + 0.5) * block), woodDark, Enum.Material.Wood)
		local counter = makeLobbyPart(shopModel, name .. "_Counter", Vector3.new(24, 5, 4), Vector3.new(gridX * block, 5.5, (gridZ - 1.9) * block), woodColor, Enum.Material.WoodPlanks)
		makeLobbyPart(shopModel, name .. "_Roof", Vector3.new(34, 2, 30), Vector3.new(gridX * block, 15, (gridZ + 0.5) * block), roofColor, Enum.Material.SmoothPlastic)
		makeSign(shopModel, name .. "_Sign", Vector3.new(gridX * block, 11.5, (gridZ - 2.9) * block), Vector3.new(22, 4, 0.5), title, roofColor, Enum.NormalId.Front)
		shopModel.PrimaryPart = counter
	end

	local function makeSeasideLShop(gridX, gridZ)
		local shopModel = makeStructureModel("SeasideLShop")
		local shopBlock = block
		local origin = Vector3.new(gridX * shopBlock, 0, gridZ * shopBlock)

		local function makeFolder(name)
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = shopModel
			return folder
		end

		local structureFolder = makeFolder("Structure")
		local awningFolder = makeFolder("RedWhiteAwning")
		local counterFolder = makeFolder("Counters")
		local decorFolder = makeFolder("Decorations")
		local shelfFolder = makeFolder("Shelves")
		local lightFolder = makeFolder("Lights")
		local signFolder = makeFolder("Signs")
		local propFolder = makeFolder("BeachProps")

		local stone = Color3.fromRGB(170, 165, 150)
		local stoneLight = Color3.fromRGB(205, 200, 185)
		local wood = Color3.fromRGB(135, 85, 45)
		local woodDarkLocal = Color3.fromRGB(85, 50, 28)
		local woodLight = Color3.fromRGB(175, 115, 55)
		local red = Color3.fromRGB(190, 45, 38)
		local white = Color3.fromRGB(235, 235, 225)
		local sand = Color3.fromRGB(224, 196, 128)
		local beachGrass = Color3.fromRGB(70, 155, 65)
		local darkMetal = Color3.fromRGB(45, 45, 50)
		local fishOrange = Color3.fromRGB(230, 145, 60)
		local bottleGreen = Color3.fromRGB(70, 160, 85)
		local bottleBlue = Color3.fromRGB(50, 125, 210)
		local bottlePurple = Color3.fromRGB(140, 90, 200)
		local lanternYellow = Color3.fromRGB(255, 220, 120)

		local function shopPart(parent, name, size, position, color, material, transparency, canCollide)
			return makeLobbyPart(parent, name, size, origin + position, color, material, transparency, canCollide)
		end

		local function shopBlockPart(parent, name, x, y, z, color, material)
			return shopPart(parent, name, Vector3.new(shopBlock, shopBlock, shopBlock), Vector3.new(x * shopBlock, y * shopBlock, z * shopBlock), color, material)
		end

		local function shopCylinder(parent, name, size, position, color, material, orientation)
			local part = shopPart(parent, name, size, position, color, material)
			part.Shape = Enum.PartType.Cylinder
			part.Orientation = orientation or Vector3.new(0, 0, 90)
			return part
		end

		local function shopTextSign(parent, name, position, size, textValue, boardColor, textColor, face)
			local board = shopPart(parent, name, size, position, boardColor, Enum.Material.Wood)
			local gui = Instance.new("SurfaceGui")
			gui.Name = name .. "_SurfaceGui"
			gui.Face = face or Enum.NormalId.Front
			gui.CanvasSize = Vector2.new(700, 300)
			gui.Parent = board

			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Text = textValue
			text.TextScaled = true
			text.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
			text.TextStrokeTransparency = 0
			text.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
			text.Font = Enum.Font.FredokaOne
			text.Parent = gui

			return board
		end

		local function shopLantern(position)
			shopPart(lightFolder, "LanternChain", Vector3.new(0.25, 2.4, 0.25), position + Vector3.new(0, 2, 0), darkMetal, Enum.Material.Metal, 0, false)
			local lantern = shopPart(lightFolder, "HangingLantern", Vector3.new(1.4, 1.4, 1.4), position, lanternYellow, Enum.Material.Glass, 0.35, false)
			shopPart(lightFolder, "LanternFrameTop", Vector3.new(1.7, 0.25, 1.7), position + Vector3.new(0, 0.82, 0), darkMetal, Enum.Material.Metal, 0, false)
			shopPart(lightFolder, "LanternFrameBottom", Vector3.new(1.7, 0.25, 1.7), position + Vector3.new(0, -0.82, 0), darkMetal, Enum.Material.Metal, 0, false)

			local light = Instance.new("PointLight")
			light.Brightness = 0.18
			light.Range = 9
			light.Color = Color3.fromRGB(255, 225, 155)
			light.Parent = lantern
		end

		local function makeFishmongerNPC()
			local npc = Instance.new("Model")
			npc.Name = "FishmongerNPC"
			npc.Parent = shopModel

			local npcFolder = Instance.new("Folder")
			npcFolder.Name = "EditableParts"
			npcFolder.Parent = npc

			local apronBlue = Color3.fromRGB(45, 105, 150)
			local shirtWhite = Color3.fromRGB(235, 238, 232)
			local skin = Color3.fromRGB(226, 178, 132)
			local pants = Color3.fromRGB(42, 62, 82)
			local capRed = Color3.fromRGB(190, 45, 38)
			local bootDark = Color3.fromRGB(35, 28, 22)
			local npcBase = Vector3.new(0, 0, -0.85 * shopBlock)

			local body = shopPart(npcFolder, "FishmongerBody", Vector3.new(3.2, 4.2, 1.6), npcBase + Vector3.new(0, 10.8, 0), apronBlue, Enum.Material.SmoothPlastic, 0, false)
			shopPart(npcFolder, "FishmongerShirt", Vector3.new(3.45, 1.2, 1.7), npcBase + Vector3.new(0, 12.25, -0.05), shirtWhite, Enum.Material.SmoothPlastic, 0, false)
			shopPart(npcFolder, "FishmongerHead", Vector3.new(2.4, 2.4, 2.4), npcBase + Vector3.new(0, 14.3, 0), skin, Enum.Material.SmoothPlastic, 0, false)
			shopPart(npcFolder, "FishmongerCap", Vector3.new(2.7, 0.7, 2.7), npcBase + Vector3.new(0, 15.75, 0), capRed, Enum.Material.SmoothPlastic, 0, false)
			shopPart(npcFolder, "FishmongerCapBill", Vector3.new(2.1, 0.3, 1.2), npcBase + Vector3.new(0, 15.45, -1.1), capRed, Enum.Material.SmoothPlastic, 0, false)
			shopPart(npcFolder, "FishmongerLeftArm", Vector3.new(0.9, 3.4, 0.9), npcBase + Vector3.new(-2.2, 10.8, 0), skin, Enum.Material.SmoothPlastic, 0, false)
			shopPart(npcFolder, "FishmongerRightArm", Vector3.new(0.9, 3.4, 0.9), npcBase + Vector3.new(2.2, 10.8, 0), skin, Enum.Material.SmoothPlastic, 0, false)
			shopPart(npcFolder, "FishmongerLeftLeg", Vector3.new(1.1, 2.6, 1), npcBase + Vector3.new(-0.9, 7.4, 0), pants, Enum.Material.SmoothPlastic, 0, false)
			shopPart(npcFolder, "FishmongerRightLeg", Vector3.new(1.1, 2.6, 1), npcBase + Vector3.new(0.9, 7.4, 0), pants, Enum.Material.SmoothPlastic, 0, false)
			shopPart(npcFolder, "FishmongerLeftBoot", Vector3.new(1.2, 0.6, 1.2), npcBase + Vector3.new(-0.9, 5.9, -0.1), bootDark, Enum.Material.SmoothPlastic, 0, false)
			shopPart(npcFolder, "FishmongerRightBoot", Vector3.new(1.2, 0.6, 1.2), npcBase + Vector3.new(0.9, 5.9, -0.1), bootDark, Enum.Material.SmoothPlastic, 0, false)

			local leftEye = shopPart(npcFolder, "FishmongerLeftEye", Vector3.new(0.3, 0.3, 0.12), npcBase + Vector3.new(-0.45, 14.55, -1.22), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, 0, false)
			local rightEye = shopPart(npcFolder, "FishmongerRightEye", Vector3.new(0.3, 0.3, 0.12), npcBase + Vector3.new(0.45, 14.55, -1.22), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, 0, false)
			leftEye.CanQuery = false
			rightEye.CanQuery = false

			shopPart(npcFolder, "FishmongerFishCrate", Vector3.new(5, 2, 3), npcBase + Vector3.new(-5.2, 6.2, 0.6), wood, Enum.Material.WoodPlanks, 0, true)
			shopPart(npcFolder, "CrateFishBlue", Vector3.new(2.8, 0.7, 0.9), npcBase + Vector3.new(-5.3, 7.55, 0.35), bottleBlue, Enum.Material.SmoothPlastic, 0, false)
			shopPart(npcFolder, "CrateFishTail", Vector3.new(0.8, 1.2, 0.8), npcBase + Vector3.new(-6.1, 7.55, 0.35), bottleBlue, Enum.Material.SmoothPlastic, 0, false)

			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "SellFishPrompt"
			prompt.ActionText = "Choose Fish"
			prompt.ObjectText = "Fishmonger"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0.25
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = body
			connectSellFishPrompt(prompt)

			npc.PrimaryPart = body
		end

		for x = -10, 12 do
			for z = -8, 10 do
				shopBlockPart(structureFolder, "BeachSandBlock", x, -1, z, sand, Enum.Material.Sand)
			end
		end

		for x = -7, 8 do
			for z = -5, -2 do
				shopPart(structureFolder, "WoodenFrontDeck", Vector3.new(shopBlock, 0.55, shopBlock), Vector3.new(x * shopBlock, 2.15, z * shopBlock), woodLight, Enum.Material.WoodPlanks)
			end
		end

		local floorCells = {}
		for x = -7, 8 do
			for z = -1, 2 do
				table.insert(floorCells, { x, z })
			end
		end
		for x = 5, 8 do
			for z = -1, 7 do
				table.insert(floorCells, { x, z })
			end
		end
		for _, cell in ipairs(floorCells) do
			shopPart(structureFolder, "ShopWoodFloor", Vector3.new(shopBlock, 0.65, shopBlock), Vector3.new(cell[1] * shopBlock, 2.25, cell[2] * shopBlock), woodLight, Enum.Material.WoodPlanks)
		end

		for x = -8, 9 do
			for y = 0, 3 do
				local color = ((x + y) % 2 == 0) and stoneLight or stone
				shopBlockPart(structureFolder, "BackStoneWall", x, y, 3, color, Enum.Material.Cobblestone)
			end
		end
		for z = 3, 8 do
			for y = 0, 3 do
				local color = ((z + y) % 2 == 0) and stoneLight or stone
				shopBlockPart(structureFolder, "RightStoneWall", 9, y, z, color, Enum.Material.Cobblestone)
			end
		end
		for _, column in ipairs({
			{ name = "LeftFrontStoneColumn", x = -8, z = -1 },
			{ name = "InnerCornerStoneColumn", x = 9, z = -1 },
			{ name = "RightFrontStoneColumn", x = 9, z = 8 },
		}) do
			for y = 0, 4 do
				shopBlockPart(structureFolder, column.name, column.x, y, column.z, stoneLight, Enum.Material.Cobblestone)
			end
		end

		for x = -8, 9 do
			shopPart(structureFolder, "TopStoneTrimFront", Vector3.new(shopBlock, 1, shopBlock), Vector3.new(x * shopBlock, 18.5, -shopBlock), stoneLight, Enum.Material.Cobblestone)
		end
		for z = -1, 8 do
			shopPart(structureFolder, "TopStoneTrimRight", Vector3.new(shopBlock, 1, shopBlock), Vector3.new(9 * shopBlock, 18.5, z * shopBlock), stoneLight, Enum.Material.Cobblestone)
		end

		for x = -7, 8 do
			for y = 0, 1 do
				shopPart(counterFolder, "FrontCounterStone", Vector3.new(shopBlock, shopBlock, shopBlock), Vector3.new(x * shopBlock, y * shopBlock + 4, -2 * shopBlock), stone, Enum.Material.Cobblestone)
			end
			shopPart(counterFolder, "FrontWoodCounterTop", Vector3.new(shopBlock, 0.65, shopBlock), Vector3.new(x * shopBlock, 10.45, -2 * shopBlock), woodLight, Enum.Material.WoodPlanks)
		end
		for z = -1, 6 do
			for y = 0, 1 do
				shopPart(counterFolder, "RightCounterStone", Vector3.new(shopBlock, shopBlock, shopBlock), Vector3.new(8 * shopBlock, y * shopBlock + 4, z * shopBlock), stone, Enum.Material.Cobblestone)
			end
			shopPart(counterFolder, "RightWoodCounterTop", Vector3.new(shopBlock, 0.65, shopBlock), Vector3.new(8 * shopBlock, 10.45, z * shopBlock), woodLight, Enum.Material.WoodPlanks)
		end
		shopPart(counterFolder, "FrontCounterDarkTrim", Vector3.new(68, 1, 0.7), Vector3.new(0.5 * shopBlock, 8.5, -2.55 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		shopPart(counterFolder, "RightCounterDarkTrim", Vector3.new(0.7, 1, 32), Vector3.new(8.55 * shopBlock, 8.5, 2.5 * shopBlock), woodDarkLocal, Enum.Material.Wood)

		for i = 0, 17 do
			local x = -8 + i
			local stripeColor = (i % 2 == 1) and white or red
			shopPart(awningFolder, "FrontAwningStripe", Vector3.new(shopBlock, 3.2, 7), Vector3.new(x * shopBlock, 20.5, -2.5 * shopBlock), stripeColor, Enum.Material.Fabric)
		end
		for i = 0, 9 do
			local z = -1 + i
			local stripeColor = (i % 2 == 1) and white or red
			shopPart(awningFolder, "RightAwningStripe", Vector3.new(7, 3.2, shopBlock), Vector3.new(9.5 * shopBlock, 20.5, z * shopBlock), stripeColor, Enum.Material.Fabric)
		end
		shopPart(awningFolder, "FrontAwningUnderside", Vector3.new(72, 0.6, 8), Vector3.new(0.5 * shopBlock, 18.6, -2.5 * shopBlock), Color3.fromRGB(95, 45, 45), Enum.Material.Fabric)
		shopPart(awningFolder, "RightAwningUnderside", Vector3.new(8, 0.6, 42), Vector3.new(9.5 * shopBlock, 18.6, 3.5 * shopBlock), Color3.fromRGB(95, 45, 45), Enum.Material.Fabric)

		for x = -8, 9 do
			shopPart(awningFolder, "RooftopWoodRailFront", Vector3.new(shopBlock, 1, 0.8), Vector3.new(x * shopBlock, 24, -4 * shopBlock), woodDarkLocal, Enum.Material.Wood)
			for z = -1, 8 do
				shopPart(awningFolder, "RooftopDeck", Vector3.new(shopBlock, 0.5, shopBlock), Vector3.new(x * shopBlock, 23.15, z * shopBlock), wood, Enum.Material.WoodPlanks)
			end
		end
		for z = -4, 8 do
			shopPart(awningFolder, "RooftopWoodRailRight", Vector3.new(0.8, 1, shopBlock), Vector3.new(11 * shopBlock, 24, z * shopBlock), woodDarkLocal, Enum.Material.Wood)
		end

		for y = 0, 1 do
			shopPart(shelfFolder, "LeftShelfFrame", Vector3.new(6, 0.7, 1.2), Vector3.new(-7 * shopBlock, 5.5 + y * 3, -3.5 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		end
		for i = 0, 3 do
			shopPart(shelfFolder, "LeftShelfBooks", Vector3.new(0.8, 2, 1), Vector3.new((-7.7 + i * 0.55) * shopBlock, 6.4, -3.4 * shopBlock), ({ red, bottleBlue, bottleGreen, bottlePurple })[i + 1], Enum.Material.SmoothPlastic)
		end
		shopPart(shelfFolder, "RightShelfBack", Vector3.new(12, 7, 1), Vector3.new(6.5 * shopBlock, 8, 5.5 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		for y = 0, 2 do
			shopPart(shelfFolder, "RightShelfLayer", Vector3.new(12, 0.6, 1.2), Vector3.new(6.5 * shopBlock, 5 + y * 2.5, 5 * shopBlock), woodLight, Enum.Material.Wood)
		end
		local bottleColors = { bottleGreen, bottleBlue, bottlePurple, red, Color3.fromRGB(230, 190, 60) }
		for i = 1, 10 do
			local row = math.floor((i - 1) / 5)
			local column = (i - 1) % 5
			shopPart(shelfFolder, "PotionBottle", Vector3.new(0.9, 1.7, 0.9), Vector3.new((4.6 + column * 0.9) * shopBlock, 5.9 + row * 2.5, 4.65 * shopBlock), bottleColors[(column % #bottleColors) + 1], Enum.Material.Glass, 0.05, false)
		end

		for _, pos in ipairs({
			Vector3.new(-2 * shopBlock, 11.5, -1.7 * shopBlock),
			Vector3.new(4 * shopBlock, 11.5, -1.7 * shopBlock),
			Vector3.new(7.8 * shopBlock, 11.5, 2 * shopBlock),
		}) do
			shopPart(decorFolder, "SmallCrate", Vector3.new(3, 3, 3), pos, wood, Enum.Material.WoodPlanks)
		end

		shopPart(decorFolder, "FishPaintingFrame", Vector3.new(12, 7, 0.6), Vector3.new(-2 * shopBlock, 10, 2.45 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		shopPart(decorFolder, "FishPaintingCanvas", Vector3.new(10, 5, 0.5), Vector3.new(-2 * shopBlock, 10, 2.15 * shopBlock), Color3.fromRGB(210, 180, 120), Enum.Material.SmoothPlastic)
		shopPart(decorFolder, "FishPaintingBody", Vector3.new(4, 1.5, 0.6), Vector3.new(-2 * shopBlock, 10, 1.8 * shopBlock), fishOrange, Enum.Material.SmoothPlastic)
		shopPart(decorFolder, "FishPaintingTail", Vector3.new(1.2, 2, 0.6), Vector3.new(-3.3 * shopBlock, 10, 1.8 * shopBlock), fishOrange, Enum.Material.SmoothPlastic)
		shopPart(decorFolder, "FishPaintingEye", Vector3.new(0.4, 0.4, 0.65), Vector3.new(-1.15 * shopBlock, 10.2, 1.45 * shopBlock), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic)

		for i = 0, 3 do
			local rod = shopPart(decorFolder, "WallFishingRod", Vector3.new(0.35, 9, 0.35), Vector3.new((1.5 + i * 1.2) * shopBlock, 9.5, 2.2 * shopBlock), woodDarkLocal, Enum.Material.Wood)
			rod.Orientation = Vector3.new(0, 0, -15)
		end

		shopPart(propFolder, "AnchorStem", Vector3.new(0.8, 6, 0.8), Vector3.new(11.5 * shopBlock, 5, -3 * shopBlock), darkMetal, Enum.Material.Metal)
		shopPart(propFolder, "AnchorCross", Vector3.new(5, 0.8, 0.8), Vector3.new(11.5 * shopBlock, 2.5, -3 * shopBlock), darkMetal, Enum.Material.Metal)
		shopCylinder(propFolder, "AnchorRing", Vector3.new(0.8, 3, 3), Vector3.new(11.5 * shopBlock, 8.5, -3 * shopBlock), darkMetal, Enum.Material.Metal, Vector3.new(0, 0, 90))

		for _, pos in ipairs({
			Vector3.new(-9 * shopBlock, 3.5, -5 * shopBlock),
			Vector3.new(11 * shopBlock, 3.5, 7 * shopBlock),
		}) do
			shopPart(propFolder, "PlantBox", Vector3.new(5, 2, 4), pos, wood, Enum.Material.WoodPlanks)
			for i = -1, 1 do
				shopPart(propFolder, "BeachGrass", Vector3.new(0.5, 4 + i, 0.5), pos + Vector3.new(i * 1.1, 2.8, 0), beachGrass, Enum.Material.Grass, 0, false)
			end
		end

		shopPart(signFolder, "ChalkboardPostLeft", Vector3.new(0.5, 4, 0.5), Vector3.new(-9.5 * shopBlock, 4, -4.8 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		shopPart(signFolder, "ChalkboardPostRight", Vector3.new(0.5, 4, 0.5), Vector3.new(-7.5 * shopBlock, 4, -4.8 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		shopTextSign(signFolder, "FishMenuChalkboard", Vector3.new(-8.5 * shopBlock, 6, -4.9 * shopBlock), Vector3.new(8, 5, 0.5), "FISH\nSHOP", Color3.fromRGB(35, 55, 45), Color3.fromRGB(245, 245, 235), Enum.NormalId.Front)
		shopTextSign(signFolder, "MainShopSign", Vector3.new(0, 23, -4.4 * shopBlock), Vector3.new(24, 4, 0.6), "SEASIDE SHOP", red, Color3.fromRGB(255, 255, 255), Enum.NormalId.Front)

		shopLantern(Vector3.new(-5 * shopBlock, 15.5, -3.5 * shopBlock))
		shopLantern(Vector3.new(0, 15.5, -3.5 * shopBlock))
		shopLantern(Vector3.new(5 * shopBlock, 15.5, -3.5 * shopBlock))
		shopLantern(Vector3.new(8.7 * shopBlock, 15.5, 3 * shopBlock))
		makeFishmongerNPC()

		local trigger = shopPart(structureFolder, "ShopTrigger", Vector3.new(60, 10, 18), Vector3.new(0, 7, -4 * shopBlock), Color3.fromRGB(0, 255, 255), Enum.Material.ForceField, 1, false)
		trigger:SetAttribute("ShopType", "SeasideShop")
		trigger:SetAttribute("InteractText", "Open Shop")

		local primary = shopPart(structureFolder, "ShopPrimaryPart", Vector3.new(2, 2, 2), Vector3.new(0, 4, 0), Color3.fromRGB(255, 0, 255), Enum.Material.ForceField, 1, false)
		shopModel.PrimaryPart = primary
	end

	local function makeSeasideRodShop(gridX, gridZ, yawDegrees)
		local shopModel = makeStructureModel("SeasideRodShop")
		shopModel:SetAttribute("FishyFishMirroredRodShop", true)
		local shopBlock = block
		local origin = Vector3.new(gridX * shopBlock, 0, gridZ * shopBlock)
		local yaw = CFrame.Angles(0, math.rad(yawDegrees or 0), 0)

		local function makeFolder(name)
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = shopModel
			return folder
		end

		local structureFolder = makeFolder("Structure")
		local awningFolder = makeFolder("BlueWhiteAwning")
		local counterFolder = makeFolder("Counters")
		local shelfFolder = makeFolder("Shelves")
		local decorFolder = makeFolder("Decorations")
		local propFolder = makeFolder("RodProps")
		local lightFolder = makeFolder("Lights")
		local signFolder = makeFolder("Signs")

		local stone = Color3.fromRGB(170, 165, 150)
		local stoneDarkLocal = Color3.fromRGB(110, 110, 105)
		local stoneLight = Color3.fromRGB(205, 200, 185)
		local wood = Color3.fromRGB(135, 85, 45)
		local woodDarkLocal = Color3.fromRGB(85, 50, 28)
		local woodLight = Color3.fromRGB(185, 145, 95)
		local blue = Color3.fromRGB(45, 110, 220)
		local white = Color3.fromRGB(235, 235, 225)
		local sand = Color3.fromRGB(224, 196, 128)
		local grass = Color3.fromRGB(75, 155, 65)
		local darkMetal = Color3.fromRGB(45, 45, 52)
		local lanternYellow = Color3.fromRGB(255, 220, 120)
		local accentBlue = Color3.fromRGB(75, 150, 255)
		local accentRed = Color3.fromRGB(220, 80, 70)
		local accentGreen = Color3.fromRGB(70, 190, 110)
		local accentYellow = Color3.fromRGB(240, 200, 70)
		local chalkboardGreen = Color3.fromRGB(40, 60, 50)
		local chalkWhite = Color3.fromRGB(245, 245, 235)

		local function shopCFrame(position, orientation)
			local rotation = orientation or CFrame.identity
			local mirroredPosition = Vector3.new(-position.X, position.Y, position.Z)
			return CFrame.new(localPosition(origin)) * yaw * CFrame.new(mirroredPosition) * rotation
		end

		local function shopPart(parent, name, size, position, color, material, transparency, canCollide, rotation)
			local part = makePart(parent, name, size, localPosition(origin), color, material)
			part.CFrame = shopCFrame(position, rotation)
			part.Transparency = transparency or 0
			part.CanCollide = canCollide ~= false
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			return part
		end

		local function shopBlockPart(parent, name, x, y, z, color, material)
			return shopPart(parent, name, Vector3.new(shopBlock, shopBlock, shopBlock), Vector3.new(x * shopBlock, y * shopBlock, z * shopBlock), color, material)
		end

		local function angles(orientation)
			return CFrame.Angles(math.rad(orientation.X), math.rad(orientation.Y), math.rad(orientation.Z))
		end

		local function shopCylinder(parent, name, size, position, color, material, orientation)
			local part = shopPart(parent, name, size, position, color, material, 0, true, angles(orientation or Vector3.new(0, 0, 90)))
			part.Shape = Enum.PartType.Cylinder
			return part
		end

		local function shopTextSign(parent, name, position, size, textValue, boardColor, textColor, face)
			local board = shopPart(parent, name, size, position, boardColor, Enum.Material.Wood)
			local gui = Instance.new("SurfaceGui")
			gui.Name = name .. "_SurfaceGui"
			gui.Face = face or Enum.NormalId.Front
			gui.CanvasSize = Vector2.new(800, 300)
			gui.Parent = board

			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Text = textValue
			text.TextScaled = true
			text.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
			text.TextStrokeTransparency = 0
			text.TextStrokeColor3 = Color3.fromRGB(35, 25, 15)
			text.Font = Enum.Font.FredokaOne
			text.Parent = gui
			return board
		end

		local function makeRod(parent, name, position, height, rodColor, handleColor)
			local model = Instance.new("Model")
			model.Name = name
			model.Parent = parent

			local pole = shopPart(model, "Pole", Vector3.new(0.25, height, 0.25), position + Vector3.new(0, height / 2, 0), rodColor, Enum.Material.Wood, 0, false, angles(Vector3.new(0, 0, -6)))
			local handle = shopPart(model, "Handle", Vector3.new(0.4, 2.2, 0.4), position + Vector3.new(-0.12, 1.1, 0), handleColor, Enum.Material.Wood, 0, false, angles(Vector3.new(0, 0, -6)))
			shopCylinder(model, "Reel", Vector3.new(0.75, 0.55, 0.75), position + Vector3.new(0.3, 1.8, 0), darkMetal, Enum.Material.Metal, Vector3.new(0, 0, 90))
			shopPart(model, "Line", Vector3.new(0.06, height * 0.45, 0.06), position + Vector3.new(0.42, height * 0.62, 0), white, Enum.Material.SmoothPlastic, 0, false)
			model.PrimaryPart = pole
			return model
		end

		local function makeLureRow(parent, basePosition)
			local colors = { accentRed, accentBlue, accentGreen, accentYellow, white }
			for i = 0, 4 do
				shopPart(parent, "Lure_" .. tostring(i), Vector3.new(0.45, 1.5, 0.35), basePosition + Vector3.new(i * 1.1, 0, 0), colors[(i % #colors) + 1], Enum.Material.SmoothPlastic, 0, false)
			end
		end

		local function shopLantern(position)
			shopPart(lightFolder, "LanternChain", Vector3.new(0.25, 2.2, 0.25), position + Vector3.new(0, 2, 0), darkMetal, Enum.Material.Metal, 0, false)
			local lantern = shopPart(lightFolder, "HangingLantern", Vector3.new(1.4, 1.4, 1.4), position, lanternYellow, Enum.Material.Glass, 0.35, false)
			shopPart(lightFolder, "LanternTopFrame", Vector3.new(1.7, 0.25, 1.7), position + Vector3.new(0, 0.82, 0), darkMetal, Enum.Material.Metal, 0, false)
			shopPart(lightFolder, "LanternBottomFrame", Vector3.new(1.7, 0.25, 1.7), position + Vector3.new(0, -0.82, 0), darkMetal, Enum.Material.Metal, 0, false)

			local light = Instance.new("PointLight")
			light.Brightness = 0.18
			light.Range = 9
			light.Color = Color3.fromRGB(255, 225, 155)
			light.Parent = lantern
		end

		for x = -10, 12 do
			for z = -8, 10 do
				shopBlockPart(structureFolder, "BeachSandBlock", x, -1, z, sand, Enum.Material.Sand)
			end
		end

		for x = -7, 8 do
			for z = -5, -2 do
				shopPart(structureFolder, "FrontDeck", Vector3.new(shopBlock, 0.55, shopBlock), Vector3.new(x * shopBlock, 2.15, z * shopBlock), woodLight, Enum.Material.WoodPlanks)
			end
		end

		local floorCells = {}
		for x = -7, 8 do
			for z = -1, 2 do
				table.insert(floorCells, { x, z })
			end
		end
		for x = 5, 8 do
			for z = -1, 7 do
				table.insert(floorCells, { x, z })
			end
		end
		for _, cell in ipairs(floorCells) do
			shopPart(structureFolder, "ShopFloor", Vector3.new(shopBlock, 0.65, shopBlock), Vector3.new(cell[1] * shopBlock, 2.25, cell[2] * shopBlock), woodLight, Enum.Material.WoodPlanks)
		end

		for x = -8, 9 do
			for y = 0, 3 do
				local color = ((x + y) % 2 == 0) and stoneLight or stone
				shopBlockPart(structureFolder, "BackStoneWall", x, y, 3, color, Enum.Material.Cobblestone)
			end
		end
		for z = 3, 8 do
			for y = 0, 3 do
				local color = ((z + y) % 2 == 0) and stoneLight or stone
				shopBlockPart(structureFolder, "RightStoneWall", 9, y, z, color, Enum.Material.Cobblestone)
			end
		end
		for _, column in ipairs({
			{ name = "LeftFrontColumn", x = -8, z = -1 },
			{ name = "InnerCornerColumn", x = 9, z = -1 },
			{ name = "RightFrontColumn", x = 9, z = 8 },
		}) do
			for y = 0, 4 do
				shopBlockPart(structureFolder, column.name, column.x, y, column.z, stoneLight, Enum.Material.Cobblestone)
			end
		end

		for x = -8, 9 do
			shopPart(structureFolder, "FrontTopTrim", Vector3.new(shopBlock, 1, shopBlock), Vector3.new(x * shopBlock, 18.5, -shopBlock), stoneLight, Enum.Material.Cobblestone)
		end
		for z = -1, 8 do
			shopPart(structureFolder, "RightTopTrim", Vector3.new(shopBlock, 1, shopBlock), Vector3.new(9 * shopBlock, 18.5, z * shopBlock), stoneLight, Enum.Material.Cobblestone)
		end
		shopPart(structureFolder, "BackWindowFrameTop", Vector3.new(12, 1, 1), Vector3.new(0, 13.8, 2.52 * shopBlock), stoneDarkLocal, Enum.Material.Cobblestone)

		for x = -7, 8 do
			for y = 0, 1 do
				shopPart(counterFolder, "FrontCounterBase", Vector3.new(shopBlock, shopBlock, shopBlock), Vector3.new(x * shopBlock, y * shopBlock + 4, -2 * shopBlock), wood, Enum.Material.WoodPlanks)
			end
			shopPart(counterFolder, "FrontCounterTop", Vector3.new(shopBlock, 0.65, shopBlock), Vector3.new(x * shopBlock, 10.45, -2 * shopBlock), woodLight, Enum.Material.WoodPlanks)
		end
		for z = -1, 6 do
			for y = 0, 1 do
				shopPart(counterFolder, "RightCounterBase", Vector3.new(shopBlock, shopBlock, shopBlock), Vector3.new(8 * shopBlock, y * shopBlock + 4, z * shopBlock), wood, Enum.Material.WoodPlanks)
			end
			shopPart(counterFolder, "RightCounterTop", Vector3.new(shopBlock, 0.65, shopBlock), Vector3.new(8 * shopBlock, 10.45, z * shopBlock), woodLight, Enum.Material.WoodPlanks)
		end
		shopPart(counterFolder, "FrontCounterTrim", Vector3.new(68, 1, 0.7), Vector3.new(0.5 * shopBlock, 8.5, -2.55 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		shopPart(counterFolder, "RightCounterTrim", Vector3.new(0.7, 1, 32), Vector3.new(8.55 * shopBlock, 8.5, 2.5 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		shopPart(decorFolder, "RegisterBase", Vector3.new(2.1, 0.8, 1.4), Vector3.new(0, 11.1, -2 * shopBlock), darkMetal, Enum.Material.Metal)
		shopPart(decorFolder, "RegisterScreen", Vector3.new(1.4, 0.7, 0.25), Vector3.new(0.15, 11.7, -2.25 * shopBlock), accentBlue, Enum.Material.Glass)

		for i = 0, 17 do
			local x = -8 + i
			local stripeColor = (i % 2 == 1) and white or blue
			shopPart(awningFolder, "FrontAwningStripe", Vector3.new(shopBlock, 3.2, 7), Vector3.new(x * shopBlock, 20.5, -2.5 * shopBlock), stripeColor, Enum.Material.Fabric)
		end
		for i = 0, 9 do
			local z = -1 + i
			local stripeColor = (i % 2 == 1) and white or blue
			shopPart(awningFolder, "RightAwningStripe", Vector3.new(7, 3.2, shopBlock), Vector3.new(9.5 * shopBlock, 20.5, z * shopBlock), stripeColor, Enum.Material.Fabric)
		end
		shopPart(awningFolder, "FrontAwningUnderside", Vector3.new(72, 0.6, 8), Vector3.new(0.5 * shopBlock, 18.6, -2.5 * shopBlock), Color3.fromRGB(55, 75, 125), Enum.Material.Fabric)
		shopPart(awningFolder, "RightAwningUnderside", Vector3.new(8, 0.6, 42), Vector3.new(9.5 * shopBlock, 18.6, 3.5 * shopBlock), Color3.fromRGB(55, 75, 125), Enum.Material.Fabric)
		for x = -8, 9 do
			for z = -1, 8 do
				shopPart(awningFolder, "RoofDeck", Vector3.new(shopBlock, 0.5, shopBlock), Vector3.new(x * shopBlock, 23.15, z * shopBlock), wood, Enum.Material.WoodPlanks)
			end
			shopPart(awningFolder, "RoofFrontRail", Vector3.new(shopBlock, 1, 0.8), Vector3.new(x * shopBlock, 24, -4 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		end
		for z = -4, 8 do
			shopPart(awningFolder, "RoofRightRail", Vector3.new(0.8, 1, shopBlock), Vector3.new(11 * shopBlock, 24, z * shopBlock), woodDarkLocal, Enum.Material.Wood)
		end

		for y = 0, 1 do
			shopPart(shelfFolder, "LeftShelfBoard", Vector3.new(6, 0.7, 1.2), Vector3.new(-7 * shopBlock, 5.5 + y * 3, -3.5 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		end
		for i = 0, 3 do
			shopPart(shelfFolder, "LeftShelfBox", Vector3.new(1.2, 1.4, 1), Vector3.new((-7.7 + i * 0.75) * shopBlock, 6.3, -3.4 * shopBlock), ({ accentBlue, accentGreen, accentYellow, accentRed })[i + 1], Enum.Material.SmoothPlastic)
		end
		shopPart(shelfFolder, "RightShelfBack", Vector3.new(12, 7, 1), Vector3.new(6.5 * shopBlock, 8, 5.5 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		for y = 0, 2 do
			shopPart(shelfFolder, "RightShelfLevel", Vector3.new(12, 0.6, 1.2), Vector3.new(6.5 * shopBlock, 5 + y * 2.5, 5 * shopBlock), woodLight, Enum.Material.Wood)
		end
		makeLureRow(shelfFolder, Vector3.new(5 * shopBlock, 5.9, 4.65 * shopBlock))
		makeLureRow(shelfFolder, Vector3.new(5 * shopBlock, 8.4, 4.65 * shopBlock))

		for x = -3, 3 do
			shopPart(propFolder, "BackRodRackBase", Vector3.new(0.4, 9, 0.4), Vector3.new(x * 1.8, 9.5, 2 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		end
		for i, rodX in ipairs({ -10, -6, -2, 2, 6, 10 }) do
			makeRod(propFolder, "BackRod_" .. tostring(i), Vector3.new(rodX, 4.2, 7.6), 8.8 + (i * 0.25), woodDarkLocal, wood)
		end

		shopPart(propFolder, "StandingRodCrate", Vector3.new(6, 4, 6), Vector3.new(12.3 * shopBlock, 4.1, 6.5 * shopBlock), wood, Enum.Material.WoodPlanks)
		for i = 0, 4 do
			makeRod(propFolder, "StandingRod_" .. tostring(i), Vector3.new((11.3 + i * 0.4) * shopBlock, 4.2, 6.5 * shopBlock), 10 + i * 0.4, woodDarkLocal, wood)
		end
		shopPart(decorFolder, "TackleCrate", Vector3.new(3.5, 2.2, 2.6), Vector3.new(7.7 * shopBlock, 11.3, 1.5 * shopBlock), wood, Enum.Material.WoodPlanks)
		shopPart(decorFolder, "TackleBoxBlue", Vector3.new(0.9, 0.7, 1.3), Vector3.new(7.1 * shopBlock, 12.2, 1.4 * shopBlock), accentBlue, Enum.Material.SmoothPlastic)
		shopPart(decorFolder, "TackleBoxRed", Vector3.new(0.9, 0.7, 1.3), Vector3.new(7.8 * shopBlock, 12.2, 1.4 * shopBlock), accentRed, Enum.Material.SmoothPlastic)
		shopPart(decorFolder, "TackleBoxGreen", Vector3.new(0.9, 0.7, 1.3), Vector3.new(8.5 * shopBlock, 12.2, 1.4 * shopBlock), accentGreen, Enum.Material.SmoothPlastic)
		shopPart(decorFolder, "PlantPot", Vector3.new(2, 1.6, 2), Vector3.new(-4.3 * shopBlock, 10.9, -1.6 * shopBlock), wood, Enum.Material.WoodPlanks)
		for i = -1, 1 do
			shopPart(decorFolder, "PlantLeaf", Vector3.new(0.35, 3 + i, 0.35), Vector3.new(-4.3 * shopBlock + i * 0.6, 12.2, -1.6 * shopBlock), grass, Enum.Material.Grass, 0, false)
		end

		shopTextSign(signFolder, "MainRodShopSign", Vector3.new(0, 23, -4.4 * shopBlock), Vector3.new(24, 4, 0.6), "SUPPLY SHOP", blue, Color3.fromRGB(255, 255, 255), Enum.NormalId.Front)
		shopTextSign(signFolder, "LeftChalkboard", Vector3.new(-7.7 * shopBlock, 8.3, -4.8 * shopBlock), Vector3.new(7.5, 10, 0.5), "CAST IT.\nREEL IT.\nCATCH IT.", chalkboardGreen, chalkWhite, Enum.NormalId.Front)
		shopTextSign(signFolder, "RightBoard", Vector3.new(7.9 * shopBlock, 10, 2.2 * shopBlock), Vector3.new(8, 9, 0.5), "RODS\nBAIT\nSUPPLIES", chalkboardGreen, chalkWhite, Enum.NormalId.Front)
		shopPart(signFolder, "SmallDisplayFrame", Vector3.new(6, 4, 0.5), Vector3.new(7.5 * shopBlock, 5.2, -2.7 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		makeLureRow(signFolder, Vector3.new(6.7 * shopBlock, 5.3, -2.42 * shopBlock))

		shopLantern(Vector3.new(-5 * shopBlock, 15.5, -3.5 * shopBlock))
		shopLantern(Vector3.new(0, 15.5, -3.5 * shopBlock))
		shopLantern(Vector3.new(5 * shopBlock, 15.5, -3.5 * shopBlock))
		shopLantern(Vector3.new(8.7 * shopBlock, 15.5, 3 * shopBlock))
		shopLantern(Vector3.new(11.2 * shopBlock, 10.5, 6.8 * shopBlock))

		local trigger = shopPart(structureFolder, "ShopTrigger", Vector3.new(60, 10, 18), Vector3.new(0, 7, -4 * shopBlock), Color3.fromRGB(0, 255, 255), Enum.Material.ForceField, 1, false)
		trigger:SetAttribute("ShopType", "RodShop")
		trigger:SetAttribute("InteractText", "Open Supply Shop")

		local primary = shopPart(structureFolder, "ShopPrimaryPart", Vector3.new(2, 2, 2), Vector3.new(0, 4, 0), Color3.fromRGB(255, 0, 255), Enum.Material.ForceField, 1, false)
		shopModel.PrimaryPart = primary
	end

	local onlyGenerateSeasideShop = true
	if onlyGenerateSeasideShop then
		lobby:Destroy()
		return nil
	else

	local function connectPortal(trigger, targetArea)
		trigger.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Services.Players:GetPlayerFromCharacter(character)
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

			local root = character:FindFirstChild("HumanoidRootPart")
			if targetArea == "BiomeWarp" then
				Remote.OpenBiomeWarp:FireClient(player, getPlayerFishingBiome and getPlayerFishingBiome(player) or nil)
				return
			end

			if targetArea == "Home" then
				Travel.teleportPlayer(player, "Home")
				return
			end

			if targetArea == "AquariumHub" then
				Travel.teleportPlayer(player, "AquariumHub")
				return
			end

			if GameConfig.Biomes[targetArea] and not IslandConfig.isBiomeUnlocked(data, targetArea) then
				notify(player, "Unlock that island first.")
				return
			end

			local target = GameConfig.Biomes[targetArea]
			if root and target then
				data.CurrentBiome = targetArea
				root.CFrame = CFrame.new(target.position)
				sendState(player)
			end
		end)
	end

	local function makeWarpPad(name, position, color, textValue, targetArea, requiredLevel)
		makeLobbyPart(aquariumWarpModel, name .. "_Base", Vector3.new(20, 1, 14), position - Vector3.new(0, 0.45, 0), Color3.fromRGB(75, 75, 75), Enum.Material.Cobblestone)
		makeLobbyPart(aquariumWarpModel, name .. "_Pad", Vector3.new(17, 0.5, 11), position, color, Enum.Material.Neon, 0.08, false)

		local trigger = makeLobbyPart(aquariumWarpModel, name .. "_Trigger", Vector3.new(17, 9, 11), position + Vector3.new(0, 4.5, 0), color, Enum.Material.ForceField, 1, false)
		trigger:SetAttribute("TargetArea", targetArea)
		trigger:SetAttribute("RequiredLevel", requiredLevel)
		trigger:SetAttribute("PortalName", textValue)
		Services.CollectionService:AddTag(trigger, "AreaPortal")
		connectPortal(trigger, targetArea)

		makeSign(aquariumWarpModel, name .. "_SmallSign", position + Vector3.new(0, 5.2, -7.3), Vector3.new(15, 3.6, 0.5), textValue .. "\nLv. " .. tostring(requiredLevel) .. "+", color, Enum.NormalId.Front)
		return trigger
	end

	for x = minX, maxX do
		for z = minZ, maxZ do
			makeBlock(blocksFolder, "GrassBlock", x, 0, z, grassColor, Enum.Material.Grass)
			makeBlock(blocksFolder, "DirtBlock", x, -1, z, dirtColor, Enum.Material.Ground)
		end
	end

	for x = minX, maxX do
		makeLobbyPart(blocksFolder, "OuterFenceNorth", Vector3.new(block, 3, 1), Vector3.new(x * block, 4, minZ * block), woodDark, Enum.Material.Wood)
		makeLobbyPart(blocksFolder, "OuterFenceSouth", Vector3.new(block, 3, 1), Vector3.new(x * block, 4, maxZ * block), woodDark, Enum.Material.Wood)
	end

	for z = minZ, maxZ do
		makeLobbyPart(blocksFolder, "OuterFenceWest", Vector3.new(1, 3, block), Vector3.new(minX * block, 4, z * block), woodDark, Enum.Material.Wood)
		makeLobbyPart(blocksFolder, "OuterFenceEast", Vector3.new(1, 3, block), Vector3.new(maxX * block, 4, z * block), woodDark, Enum.Material.Wood)
	end

	for x = -12, 12 do
		for z = -10, 10 do
			if not (math.abs(x) <= 4 and math.abs(z) <= 4) then
				makeLobbyPart(pathsFolder, "FountainPlazaTile", Vector3.new(block, 0.45, block), Vector3.new(x * block, 2.45, z * block), Color3.fromRGB(150, 78, 58), Enum.Material.Brick)
			end
		end
	end

	for x = -4, 4 do
		for z = -4, 4 do
			makeLobbyPart(fountainModel, "FountainWater", Vector3.new(block, 0.55, block), Vector3.new(x * block, 2.8, z * block), waterColor, Enum.Material.Glass, 0.35, false)
		end
	end

	for x = -5, 5 do
		for z = -5, 5 do
			if math.abs(x) == 5 or math.abs(z) == 5 then
				makeLobbyPart(fountainModel, "FountainBorder", Vector3.new(block, 1.2, block), Vector3.new(x * block, 3.1, z * block), stoneColor, Enum.Material.Cobblestone)
			end
		end
	end

	local fountainCore = makeLobbyPart(fountainModel, "FountainCore", Vector3.new(7, 9, 7), Vector3.new(0, 7, 0), stoneDark, Enum.Material.Cobblestone)
	local fountainTop = makeLobbyPart(fountainModel, "FountainTopWater", Vector3.new(4, 4, 4), Vector3.new(0, 13, 0), waterColor, Enum.Material.Neon, 0.15, false)
	local fountainLight = Instance.new("PointLight")
	fountainLight.Brightness = 0.2
	fountainLight.Range = 10
	fountainLight.Color = Color3.fromRGB(80, 190, 255)
	fountainLight.Parent = fountainTop
	fountainModel.PrimaryPart = fountainCore

	local fountainWarpTrigger = makeLobbyPart(
		fountainModel,
		"FountainBiomeWarpTrigger",
		Vector3.new(42, 12, 42),
		Vector3.new(0, 7, 0),
		blueUI,
		Enum.Material.ForceField,
		1,
		false
	)
	fountainWarpTrigger:SetAttribute("TargetArea", "BiomeWarp")
	fountainWarpTrigger:SetAttribute("PortalName", "Island Warp")
	fountainWarpTrigger:SetAttribute("RequiredLevel", 1)
	Services.CollectionService:AddTag(fountainWarpTrigger, "AreaPortal")
	connectPortal(fountainWarpTrigger, "BiomeWarp")

	local lobbyZone = makeLobbyPart(
		zonesFolder,
		"LobbyZone",
		Vector3.new((maxX - minX) * block, 20, (maxZ - minZ) * block),
		Vector3.new(0, 8, 0),
		Color3.fromRGB(0, 255, 255),
		Enum.Material.ForceField,
		1,
		false
	)
	lobbyZone:SetAttribute("AreaName", "Lobby")
	Services.CollectionService:AddTag(lobbyZone, "LobbyZone")

	for z = -28, -11 do
		for x = -2, 2 do
			makeLobbyPart(pathsFolder, "SpawnToFountainPath", Vector3.new(block, 0.25, block), Vector3.new(x * block, 2.6, z * block), pathColor, Enum.Material.Ground)
		end
	end

	for z = 11, 28 do
		for x = -2, 2 do
			makeLobbyPart(pathsFolder, "FountainToBiomePath", Vector3.new(block, 0.25, block), Vector3.new(x * block, 2.6, z * block), pathColor, Enum.Material.Ground)
		end
	end

	for x = -30, 30 do
		for z = -1, 1 do
			makeLobbyPart(pathsFolder, "LeftRightPath", Vector3.new(block, 0.25, block), Vector3.new(x * block, 2.6, z * block), pathColor, Enum.Material.Ground)
		end
	end

	for x = -32, -14 do
		for z = -26, -23 do
			makeLobbyPart(pathsFolder, "FishShopPath", Vector3.new(block, 0.25, block), Vector3.new(x * block, 2.6, z * block), pathColor, Enum.Material.Ground)
		end
	end

	for x = 14, 32 do
		for z = -26, -23 do
			makeLobbyPart(pathsFolder, "RodShopPath", Vector3.new(block, 0.25, block), Vector3.new(x * block, 2.6, z * block), pathColor, Enum.Material.Ground)
		end
	end

	local leaderboardBoard = makeSign(leaderboardModel, "LeaderboardBoard", Vector3.new(0, 13.5, 27 * block), Vector3.new(56, 25, 0.8), "Leaderboard - Most Fish Caught\n\n1. ---\n2. ---\n3. ---\n4. ---\n5. ---", blueUI, Enum.NormalId.Front)
	makeLobbyPart(leaderboardModel, "LeaderboardLeftPost", Vector3.new(1.4, 22, 1.4), Vector3.new(-7 * block, 12, 27 * block), woodDark, Enum.Material.Wood)
	makeLobbyPart(leaderboardModel, "LeaderboardRightPost", Vector3.new(1.4, 22, 1.4), Vector3.new(7 * block, 12, 27 * block), woodDark, Enum.Material.Wood)
	leaderboardModel.PrimaryPart = leaderboardBoard

	makeSign(aquariumWarpModel, "AquariumWarpSign", Vector3.new(31 * block, 11, 10 * block), Vector3.new(22, 15, 0.7), "Aquarium\nHub", aquariumColor, Enum.NormalId.Front)
	makeWarpPad("AquariumWarp", Vector3.new(31 * block, 3.2, 10 * block), aquariumColor, "Aquarium Hub", "AquariumHub", 1)

	makeShopBuilding("FishShop", -24, -24, "FISH SHOP", blueUI)
	makeShopBuilding("RodShop", 24, -24, "SUPPLY SHOP", goldUI)

	local spawnPad = makeLobbyPart(spawnAreaModel, "SpawnPointPad", Vector3.new(64, 0.5, 24), Vector3.new(0, 3, -30 * block), Color3.fromRGB(145, 95, 50), Enum.Material.WoodPlanks)
	makeSign(spawnAreaModel, "SpawnPointSign", Vector3.new(0, 7, -33 * block), Vector3.new(24, 4, 0.5), "Spawn Point", greenUI, Enum.NormalId.Back)
	spawnAreaModel.PrimaryPart = spawnPad

	for index, pos in ipairs({
		Vector3.new(-12 * block, 5, -12 * block), Vector3.new(12 * block, 5, -12 * block),
		Vector3.new(-12 * block, 5, 12 * block), Vector3.new(12 * block, 5, 12 * block),
		Vector3.new(-31 * block, 5, 3 * block), Vector3.new(31 * block, 5, 3 * block),
		Vector3.new(-18 * block, 5, -29 * block), Vector3.new(18 * block, 5, -29 * block),
		Vector3.new(-22 * block, 5, 26 * block), Vector3.new(22 * block, 5, 26 * block),
	}) do
		makeLantern(pos, index)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(24, 1, 16)
	spawn.Position = localPosition(Vector3.new(0, 3.7, -30 * block))
	spawn.Anchored = true
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Color = Color3.fromRGB(145, 95, 50)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Parent = spawnAreaModel
	for _, descendant in ipairs(spawn:GetDescendants()) do
		if descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant:Destroy()
		end
	end

	lobby.PrimaryPart = lobbyZone
	return lobby
	end
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
	local lamp = makePart(parent, name .. " Light", Vector3.new(2.2, 2.2, 2.2), position + Vector3.new(0, 8.7, 0), lightColor, Enum.Material.Glass)
	lamp.Transparency = 0.35

	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0.18
	pointLight.Range = 9
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

local function hasAncestorNamed(instance, ancestorName)
	local current = instance.Parent
	while current do
		if current.Name == ancestorName then
			return true
		end
		current = current.Parent
	end

	return false
end

local function shouldUsePartForFountainAnimation(part)
	local lowerName = string.lower(part.Name)
	return string.find(lowerName, "fountain")
		and not string.find(lowerName, "path")
		and not string.find(lowerName, "plaza")
		and not string.find(lowerName, "trigger")
		and not hasAncestorNamed(part, "AnimatedFountainEffects")
end

local function getFountainAnimationRoot(part)
	local current = part
	local lobbyRoot = nil

	while current and current ~= workspace do
		if current:IsA("Model") and string.find(string.lower(current.Name), "fountain") then
			return current
		end

		if current:IsA("Model") and current.Name == "LobbyArea" then
			lobbyRoot = current
		end

		current = current.Parent
	end

	return lobbyRoot or part
end

local function makeFountainEffectPart(parent, name, position)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.4, 0.4, 0.4)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function addAnimatedFountainEffects(root, fountainParts)
	if #fountainParts == 0 then
		return
	end

	local existing = root:FindFirstChild("AnimatedFountainEffects")
	if existing then
		existing:Destroy()
	end

	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	local topPart = nil

	for _, part in ipairs(fountainParts) do
		local halfSize = part.Size / 2
		minX = math.min(minX, part.Position.X - halfSize.X)
		minY = math.min(minY, part.Position.Y - halfSize.Y)
		minZ = math.min(minZ, part.Position.Z - halfSize.Z)
		maxX = math.max(maxX, part.Position.X + halfSize.X)
		maxY = math.max(maxY, part.Position.Y + halfSize.Y)
		maxZ = math.max(maxZ, part.Position.Z + halfSize.Z)

		local lowerName = string.lower(part.Name)
		if string.find(lowerName, "topwater") then
			topPart = part
		elseif not topPart or part.Position.Y > topPart.Position.Y then
			topPart = part
		end
	end

	local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
	local width = maxX - minX
	local depth = maxZ - minZ
	local basinY = minY + math.max(1.6, (maxY - minY) * 0.18)
	local radius = math.max(8, math.min(width, depth) * 0.38)
	local nozzlePosition = topPart.Position + Vector3.new(0, (topPart.Size.Y / 2) + 0.3, 0)

	local effects = Instance.new("Folder")
	effects.Name = "AnimatedFountainEffects"
	effects.Parent = root

	local nozzle = makeFountainEffectPart(effects, "SprayNozzle", nozzlePosition)
	local nozzleAttachment = Instance.new("Attachment")
	nozzleAttachment.Name = "SprayAttachment"
	nozzleAttachment.Parent = nozzle

	local spray = Instance.new("ParticleEmitter")
	spray.Name = "WaterSpray"
	spray.Color = ColorSequence.new(Color3.fromRGB(120, 220, 255), Color3.fromRGB(235, 250, 255))
	spray.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.75, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	spray.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	spray.Rate = 28
	spray.Lifetime = NumberRange.new(0.55, 1.0)
	spray.Speed = NumberRange.new(7, 12)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.Acceleration = Vector3.new(0, -34, 0)
	spray.Drag = 2.5
	spray.LightEmission = 0.45
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = nozzleAttachment

	local mistPart = makeFountainEffectPart(effects, "BasinMistEmitter", Vector3.new(center.X, basinY + 0.6, center.Z))
	local mistAttachment = Instance.new("Attachment")
	mistAttachment.Name = "BasinMistAttachment"
	mistAttachment.Parent = mistPart

	local mist = Instance.new("ParticleEmitter")
	mist.Name = "BasinMist"
	mist.Color = ColorSequence.new(Color3.fromRGB(150, 225, 255))
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.8),
		NumberSequenceKeypoint.new(1, 3.2),
	})
	mist.Rate = 26
	mist.Lifetime = NumberRange.new(1.2, 2.2)
	mist.Speed = NumberRange.new(0.6, 1.8)
	mist.SpreadAngle = Vector2.new(180, 15)
	mist.LightEmission = 0.2
	mist.Parent = mistAttachment

	local sheetDrop = math.max(4, nozzlePosition.Y - (basinY + 0.6))
	local sheetCenterY = (nozzlePosition.Y + basinY + 0.6) / 2
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
		return sheet
	end

	makeWaterSheet(
		"FallingWaterSheet_North",
		Vector3.new(topPart.Size.X + 2.4, sheetDrop, 0.28),
		Vector3.new(topPart.Position.X, sheetCenterY, topPart.Position.Z - (topPart.Size.Z / 2) - 0.25)
	)
	makeWaterSheet(
		"FallingWaterSheet_South",
		Vector3.new(topPart.Size.X + 2.4, sheetDrop, 0.28),
		Vector3.new(topPart.Position.X, sheetCenterY, topPart.Position.Z + (topPart.Size.Z / 2) + 0.25)
	)
	makeWaterSheet(
		"FallingWaterSheet_West",
		Vector3.new(0.28, sheetDrop, topPart.Size.Z + 2.4),
		Vector3.new(topPart.Position.X - (topPart.Size.X / 2) - 0.25, sheetCenterY, topPart.Position.Z)
	)
	makeWaterSheet(
		"FallingWaterSheet_East",
		Vector3.new(0.28, sheetDrop, topPart.Size.Z + 2.4),
		Vector3.new(topPart.Position.X + (topPart.Size.X / 2) + 0.25, sheetCenterY, topPart.Position.Z)
	)

	local cascadeDirections = {
		{ name = "North", direction = Vector3.new(0, 0, -1) },
		{ name = "South", direction = Vector3.new(0, 0, 1) },
		{ name = "West", direction = Vector3.new(-1, 0, 0) },
		{ name = "East", direction = Vector3.new(1, 0, 0) },
	}

	for _, stream in ipairs(cascadeDirections) do
		local sideOffset = Vector3.new(stream.direction.X * ((topPart.Size.X / 2) + 0.15), 0, stream.direction.Z * ((topPart.Size.Z / 2) + 0.15))
		local startPart = makeFountainEffectPart(effects, "CascadeStart_" .. stream.name, topPart.Position + sideOffset + Vector3.new(0, topPart.Size.Y * 0.18, 0))
		local startAttachment = Instance.new("Attachment")
		startAttachment.Name = "CascadeStartAttachment_" .. stream.name
		startAttachment.Parent = startPart

		local endPosition = Vector3.new(center.X, basinY + 0.55, center.Z) + (stream.direction * math.max(5, radius * 0.55))
		local endPart = makeFountainEffectPart(effects, "CascadeEnd_" .. stream.name, endPosition)
		local endAttachment = Instance.new("Attachment")
		endAttachment.Name = "CascadeEndAttachment_" .. stream.name
		endAttachment.Parent = endPart

		local cascade = Instance.new("Beam")
		cascade.Name = "FallingWater_" .. stream.name
		cascade.Attachment0 = startAttachment
		cascade.Attachment1 = endAttachment
		cascade.Color = ColorSequence.new(Color3.fromRGB(90, 205, 255), Color3.fromRGB(230, 250, 255))
		cascade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.8, 0.18),
			NumberSequenceKeypoint.new(1, 0.52),
		})
		cascade.Width0 = 2.4
		cascade.Width1 = 1.25
		cascade.CurveSize0 = -1.4
		cascade.CurveSize1 = 1.6
		cascade.Segments = 16
		cascade.Texture = "rbxasset://textures/particles/smoke_main.dds"
		cascade.TextureLength = 1.4
		cascade.TextureSpeed = -1.8
		cascade.LightEmission = 0.25
		cascade.FaceCamera = true
		cascade.Parent = startAttachment
	end

	local streamDirections = {
		{ name = "North", direction = Vector3.new(0, 0, -1) },
		{ name = "South", direction = Vector3.new(0, 0, 1) },
		{ name = "West", direction = Vector3.new(-1, 0, 0) },
		{ name = "East", direction = Vector3.new(1, 0, 0) },
	}

	for _, stream in ipairs(streamDirections) do
		local endPosition = Vector3.new(center.X, basinY + 0.4, center.Z) + (stream.direction * radius)
		local endPart = makeFountainEffectPart(effects, "WaterStreamEnd_" .. stream.name, endPosition)
		local endAttachment = Instance.new("Attachment")
		endAttachment.Name = "WaterStreamAttachment_" .. stream.name
		endAttachment.Parent = endPart

		local beam = Instance.new("Beam")
		beam.Name = "FlowingWater_" .. stream.name
		beam.Attachment0 = nozzleAttachment
		beam.Attachment1 = endAttachment
		beam.Color = ColorSequence.new(Color3.fromRGB(95, 210, 255), Color3.fromRGB(210, 245, 255))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.82, 0.28),
			NumberSequenceKeypoint.new(1, 0.75),
		})
		beam.Width0 = 0.7
		beam.Width1 = 1.8
		beam.CurveSize0 = 7
		beam.CurveSize1 = -2
		beam.Segments = 18
		beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		beam.TextureLength = 2
		beam.TextureSpeed = 1.6
		beam.LightEmission = 0.35
		beam.FaceCamera = true
		beam.Parent = nozzleAttachment
	end
end

local function ensureFountainAnimations()
	local groupedParts = {}

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and shouldUsePartForFountainAnimation(descendant) then
			local root = getFountainAnimationRoot(descendant)
			if not groupedParts[root] then
				groupedParts[root] = {}
			end
			table.insert(groupedParts[root], descendant)
		end
	end

	for root, fountainParts in pairs(groupedParts) do
		addAnimatedFountainEffects(root, fountainParts)
	end
end

local function ensureFountainPlazaBrickStyle()
	local brickColors = {
		Color3.fromRGB(150, 78, 58),
		Color3.fromRGB(172, 88, 64),
		Color3.fromRGB(122, 61, 49),
	}

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "FountainPlazaTile" then
			local colorIndex = (math.floor(descendant.Position.X / 4) + (math.floor(descendant.Position.Z / 4) * 2)) % #brickColors
			descendant.Material = Enum.Material.Brick
			descendant.Color = brickColors[colorIndex + 1]
			descendant.TopSurface = Enum.SurfaceType.Smooth
			descendant.BottomSurface = Enum.SurfaceType.Smooth
		end
	end
end

local function ensureShopWoodPartSpacing()
	local roofDeckNames = {
		RooftopDeck = true,
		RoofDeck = true,
	}

	for _, shop in ipairs(workspace:GetDescendants()) do
		if shop:IsA("Model") and (shop.Name == "SeasideLShop" or shop.Name == "SeasideRodShop") then
			for _, descendant in ipairs(shop:GetDescendants()) do
				if descendant:IsA("BasePart") then
					if roofDeckNames[descendant.Name] then
						if descendant.Position.Y > 23.05 then
							descendant.Position = Vector3.new(descendant.Position.X, 22.95, descendant.Position.Z)
						end
						descendant:SetAttribute("FishyFishWoodSpacingFixed", true)
					end
				end
			end
		end
	end
end

local function isInFishyFishWorld(instance)
	local current = instance.Parent
	while current do
		if current.Name == "FishyFishWorld" then
			return true
		end
		current = current.Parent
	end

	return false
end

local function findSeasideShop()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "SeasideLShop" and not isInFishyFishWorld(descendant) then
			return descendant
		end
	end

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "SeasideLShop" then
			return descendant
		end
	end

	return nil
end

local function findSeasideRodShop()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "SeasideRodShop" and not isInFishyFishWorld(descendant) then
			return descendant
		end
	end

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "SeasideRodShop" then
			return descendant
		end
	end

	return nil
end

local function ensureSeasideRodShopMirrored()
	local shop = findSeasideRodShop()
	if not shop or shop:GetAttribute("FishyFishMirroredRodShop") then
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
			return
		end
		pivot = result
	end

	for _, descendant in ipairs(shop:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local localCFrame = pivot:ToObjectSpace(descendant.CFrame)
			local localPosition = localCFrame.Position
			local localRotation = localCFrame - localPosition
			descendant.CFrame = pivot * CFrame.new(-localPosition.X, localPosition.Y, localPosition.Z) * localRotation
		end
	end

	shop:SetAttribute("FishyFishMirroredRodShop", true)
end

local function ensureSeasideShopFishmonger()
	local shop = findSeasideShop()
	if not shop then
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
			return
		end
		baseCFrame = pivot * CFrame.new(0, -4, 0)
	end

	local existing = shop:FindFirstChild("FishmongerNPC")
	if existing then
		local prompt = existing:FindFirstChild("SellFishPrompt", true)
		if not prompt or not prompt:IsA("ProximityPrompt") then
			local promptParent = existing.PrimaryPart or existing:FindFirstChildWhichIsA("BasePart", true)
			if promptParent then
				prompt = Instance.new("ProximityPrompt")
				prompt.Name = "SellFishPrompt"
				prompt.Parent = promptParent
			end
		end
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.ActionText = "Choose Fish"
			prompt.ObjectText = "Fishmonger"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0.25
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			connectSellFishPrompt(prompt)
		end
		return
	end

	local npc = Instance.new("Model")
	npc.Name = "FishmongerNPC"
	npc.Parent = shop

	local folder = Instance.new("Folder")
	folder.Name = "EditableParts"
	folder.Parent = npc

	local function makeNpcPart(name, size, localPosition, color, material, transparency, canCollide)
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

	local body = makeNpcPart("FishmongerBody", Vector3.new(3.2, 4.2, 1.6), npcBase + Vector3.new(0, 10.8, 0), apronBlue)
	makeNpcPart("FishmongerShirt", Vector3.new(3.45, 1.2, 1.7), npcBase + Vector3.new(0, 12.25, -0.05), shirtWhite)
	makeNpcPart("FishmongerHead", Vector3.new(2.4, 2.4, 2.4), npcBase + Vector3.new(0, 14.3, 0), skin)
	makeNpcPart("FishmongerCap", Vector3.new(2.7, 0.7, 2.7), npcBase + Vector3.new(0, 15.75, 0), capRed)
	makeNpcPart("FishmongerCapBill", Vector3.new(2.1, 0.3, 1.2), npcBase + Vector3.new(0, 15.45, -1.1), capRed)
	makeNpcPart("FishmongerLeftArm", Vector3.new(0.9, 3.4, 0.9), npcBase + Vector3.new(-2.2, 10.8, 0), skin)
	makeNpcPart("FishmongerRightArm", Vector3.new(0.9, 3.4, 0.9), npcBase + Vector3.new(2.2, 10.8, 0), skin)
	makeNpcPart("FishmongerLeftLeg", Vector3.new(1.1, 2.6, 1), npcBase + Vector3.new(-0.9, 7.4, 0), pants)
	makeNpcPart("FishmongerRightLeg", Vector3.new(1.1, 2.6, 1), npcBase + Vector3.new(0.9, 7.4, 0), pants)
	makeNpcPart("FishmongerLeftBoot", Vector3.new(1.2, 0.6, 1.2), npcBase + Vector3.new(-0.9, 5.9, -0.1), bootDark)
	makeNpcPart("FishmongerRightBoot", Vector3.new(1.2, 0.6, 1.2), npcBase + Vector3.new(0.9, 5.9, -0.1), bootDark)
	makeNpcPart("FishmongerLeftEye", Vector3.new(0.3, 0.3, 0.12), npcBase + Vector3.new(-0.45, 14.55, -1.22), Color3.fromRGB(20, 20, 20))
	makeNpcPart("FishmongerRightEye", Vector3.new(0.3, 0.3, 0.12), npcBase + Vector3.new(0.45, 14.55, -1.22), Color3.fromRGB(20, 20, 20))
	makeNpcPart("FishmongerFishCrate", Vector3.new(5, 2, 3), npcBase + Vector3.new(-5.2, 6.2, 0.6), wood, Enum.Material.WoodPlanks, 0, true)
	makeNpcPart("CrateFishBlue", Vector3.new(2.8, 0.7, 0.9), npcBase + Vector3.new(-5.3, 7.55, 0.35), bottleBlue)
	makeNpcPart("CrateFishTail", Vector3.new(0.8, 1.2, 0.8), npcBase + Vector3.new(-6.1, 7.55, 0.35), bottleBlue)

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
	connectSellFishPrompt(prompt)
end

local function ensureSeasideRodShopKeeper()
	local shop = findSeasideRodShop()
	if not shop then
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
			return
		end
		baseCFrame = pivot * CFrame.new(0, -4, 0)
	end

	local existing = shop:FindFirstChild("RodShopKeeperNPC")
	if existing then
		local prompt = existing:FindFirstChild("BuyRodPrompt", true)
		if not prompt or not prompt:IsA("ProximityPrompt") then
			local promptParent = existing.PrimaryPart or existing:FindFirstChildWhichIsA("BasePart", true)
			if promptParent then
				prompt = Instance.new("ProximityPrompt")
				prompt.Name = "BuyRodPrompt"
				prompt.Parent = promptParent
			end
		end
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.ActionText = "Browse Supplies"
			prompt.ObjectText = "Supply Seller"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0.25
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			connectRodShopPrompt(prompt)
		end
		return
	end

	local npc = Instance.new("Model")
	npc.Name = "RodShopKeeperNPC"
	npc.Parent = shop

	local folder = Instance.new("Folder")
	folder.Name = "EditableParts"
	folder.Parent = npc

	local function makeNpcPart(name, size, localPosition, color, material, transparency, canCollide)
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

	local body = makeNpcPart("RodSellerBody", Vector3.new(3.2, 4.2, 1.6), npcBase + Vector3.new(0, 10.8, 0), vestBlue)
	makeNpcPart("RodSellerShirt", Vector3.new(3.45, 1.2, 1.7), npcBase + Vector3.new(0, 12.25, -0.05), shirtCream)
	makeNpcPart("RodSellerHead", Vector3.new(2.4, 2.4, 2.4), npcBase + Vector3.new(0, 14.3, 0), skin)
	makeNpcPart("RodSellerCap", Vector3.new(2.7, 0.7, 2.7), npcBase + Vector3.new(0, 15.75, 0), capBlue)
	makeNpcPart("RodSellerCapBill", Vector3.new(2.1, 0.3, 1.2), npcBase + Vector3.new(0, 15.45, -1.1), capBlue)
	makeNpcPart("RodSellerLeftArm", Vector3.new(0.9, 3.4, 0.9), npcBase + Vector3.new(-2.2, 10.8, 0), skin)
	makeNpcPart("RodSellerRightArm", Vector3.new(0.9, 3.4, 0.9), npcBase + Vector3.new(2.2, 10.8, 0), skin)
	makeNpcPart("RodSellerLeftLeg", Vector3.new(1.1, 2.6, 1), npcBase + Vector3.new(-0.9, 7.4, 0), pants)
	makeNpcPart("RodSellerRightLeg", Vector3.new(1.1, 2.6, 1), npcBase + Vector3.new(0.9, 7.4, 0), pants)
	makeNpcPart("RodSellerLeftBoot", Vector3.new(1.2, 0.6, 1.2), npcBase + Vector3.new(-0.9, 5.9, -0.1), bootDark)
	makeNpcPart("RodSellerRightBoot", Vector3.new(1.2, 0.6, 1.2), npcBase + Vector3.new(0.9, 5.9, -0.1), bootDark)
	makeNpcPart("RodSellerLeftEye", Vector3.new(0.3, 0.3, 0.12), npcBase + Vector3.new(-0.45, 14.55, -1.22), Color3.fromRGB(20, 20, 20))
	makeNpcPart("RodSellerRightEye", Vector3.new(0.3, 0.3, 0.12), npcBase + Vector3.new(0.45, 14.55, -1.22), Color3.fromRGB(20, 20, 20))
	makeNpcPart("DisplayRodPole", Vector3.new(0.28, 9, 0.28), npcBase + Vector3.new(4.2, 11.2, -0.1), wood, Enum.Material.Wood, 0, false)
	makeNpcPart("DisplayRodHandle", Vector3.new(0.55, 2.2, 0.55), npcBase + Vector3.new(4.2, 7.4, -0.1), wood, Enum.Material.Wood, 0, false)
	makeNpcPart("DisplayRodReel", Vector3.new(1.1, 0.45, 1.1), npcBase + Vector3.new(3.65, 8.6, -0.1), reelMetal, Enum.Material.Metal, 0, false)
	makeNpcPart("DisplayRodLine", Vector3.new(0.06, 4.2, 0.06), npcBase + Vector3.new(4.65, 12.7, -0.1), lineWhite, Enum.Material.SmoothPlastic, 0, false)
	makeNpcPart("RodSellerCrate", Vector3.new(4.8, 1.8, 2.6), npcBase + Vector3.new(-5.2, 6.15, 0.55), wood, Enum.Material.WoodPlanks, 0, true)

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
	connectRodShopPrompt(prompt)
end

local function ensureSeasideShopDisplayAquarium()
	local shop = findSeasideShop()
	if not shop then
		return
	end

	local editorPreview = workspace:FindFirstChild("DisplayAquariumTank")
	if editorPreview and editorPreview.Parent ~= shop then
		editorPreview:Destroy()
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
		return
	end
		baseCFrame = pivot * CFrame.new(0, -4, 0)
	end

	local function populateRestoredTankWithGameFish(tank)
		local fishFolder = tank:FindFirstChild("DisplayFish", true)
		if not fishFolder then
			fishFolder = Instance.new("Folder")
			fishFolder.Name = "DisplayFish"
			fishFolder.Parent = tank
		end

		for _, child in ipairs(fishFolder:GetChildren()) do
			child:Destroy()
		end

		local tankCFrame, tankSize = tank:GetBoundingBox()
		local dimensions = {
			level = 1,
			tankWidth = math.max(6, tankSize.X - 4),
			tankHeight = math.max(5, tankSize.Y - 1.7),
			tankDepth = math.max(5, tankSize.Z - 3),
			baseWidth = tankSize.X,
			baseDepth = tankSize.Z,
		}
		local origin = tankCFrame.Position - Vector3.new(0, tankSize.Y / 2, 0)

		for index, fish in ipairs({
			{ id = "SmallFish", name = "Small Fish", rarity = "Common", value = 5 },
			{ id = "Bluegill", name = "Bluegill", rarity = "Common", value = 12 },
			{ id = "Koi", name = "Koi", rarity = "Rare", value = 75 },
			{ id = "GoldenCarp", name = "Golden Carp", rarity = "Epic", value = 160 },
		}) do
			makeAquariumFish(fishFolder, fish, origin, index, 604200, dimensions)
		end

		tank:SetAttribute("UsesPersonalAquariumFish", true)
		tank:SetAttribute("LiveGameFishPopulated", true)
	end

	local function displayTankHasDetailedFish(tank)
		if tank:GetAttribute("UsesPersonalAquariumFish") ~= true then
			return false
		end

		local fishFolder = tank:FindFirstChild("DisplayFish", true)
		if not fishFolder then
			return false
		end

		for _, child in ipairs(fishFolder:GetChildren()) do
			if child:IsA("Model") and string.sub(child.Name, 1, 12) == "AquariumFish" then
				return true
			end
		end

		return false
	end

	local existing = shop:FindFirstChild("DisplayAquariumTank")
	if existing then
		existing:SetAttribute("DisplayOnly", true)
		existing:SetAttribute("PlayerLinked", false)
		if existing:GetAttribute("RestoredFromTransferBackup") == true then
			if existing:GetAttribute("LiveGameFishPopulated") ~= true then
				populateRestoredTankWithGameFish(existing)
			end
			return
		end
		if displayTankHasDetailedFish(existing) then
			return
		end

		existing:Destroy()
	end

	local aquarium = Instance.new("Model")
	aquarium.Name = "DisplayAquariumTank"
	aquarium:SetAttribute("DisplayOnly", true)
	aquarium:SetAttribute("PlayerLinked", false)
	aquarium:SetAttribute("UsesPersonalAquariumFish", true)
	aquarium.Parent = shop

	local tankFolder = Instance.new("Folder")
	tankFolder.Name = "TankParts"
	tankFolder.Parent = aquarium

	local fishFolder = Instance.new("Folder")
	fishFolder.Name = "DisplayFish"
	fishFolder.Parent = aquarium

	local originOffset = Vector3.new(-19, 3, 4)
	local origin = (baseCFrame * CFrame.new(originOffset)).Position
	local dimensions = {
		level = 1,
		tankWidth = 14,
		tankHeight = 7,
		tankDepth = 7,
		baseWidth = 18,
		baseDepth = 10,
		glassY = 1 + (7 / 2),
		waterY = 1 + (7 * 0.78),
		topY = 1 + 7 + 0.3,
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

	local base = tankPart(
		tankFolder,
		"AquariumDisplayBase",
		Vector3.new(dimensions.baseWidth, 1, dimensions.baseDepth),
		Vector3.new(0, 0.8, 0),
		Color3.fromRGB(72, 82, 88),
		Enum.Material.Metal,
		0,
		true
	)
	tankPart(tankFolder, "AquariumDisplayBaseTop", Vector3.new(dimensions.baseWidth - 1.2, 0.18, dimensions.baseDepth - 1.2), Vector3.new(0, 1.39, 0), Color3.fromRGB(132, 142, 150), Enum.Material.Metal)

	for _, glassPanel in ipairs({
		{ name = "DisplayGlassFront", size = Vector3.new(dimensions.tankWidth, dimensions.tankHeight, 0.22), offset = Vector3.new(0, dimensions.glassY, -halfDepth - 0.14) },
		{ name = "DisplayGlassBack", size = Vector3.new(dimensions.tankWidth, dimensions.tankHeight, 0.22), offset = Vector3.new(0, dimensions.glassY, halfDepth + 0.14) },
		{ name = "DisplayGlassLeft", size = Vector3.new(0.22, dimensions.tankHeight, dimensions.tankDepth), offset = Vector3.new(-halfWidth - 0.14, dimensions.glassY, 0) },
		{ name = "DisplayGlassRight", size = Vector3.new(0.22, dimensions.tankHeight, dimensions.tankDepth), offset = Vector3.new(halfWidth + 0.14, dimensions.glassY, 0) },
	}) do
		tankPart(tankFolder, glassPanel.name, glassPanel.size, glassPanel.offset, Color3.fromRGB(75, 165, 220), Enum.Material.Glass, 0.68, true)
	end

	tankPart(
		tankFolder,
		"DisplayWaterSurface",
		Vector3.new(dimensions.tankWidth - 1.4, 0.18, dimensions.tankDepth - 1.4),
		Vector3.new(0, dimensions.waterY, 0),
		Color3.fromRGB(50, 145, 220),
		Enum.Material.Glass,
		0.48
	)

	for _, corner in ipairs({
		Vector3.new(-halfWidth, dimensions.glassY, -halfDepth), Vector3.new(halfWidth, dimensions.glassY, -halfDepth),
		Vector3.new(-halfWidth, dimensions.glassY, halfDepth), Vector3.new(halfWidth, dimensions.glassY, halfDepth),
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

	for index, fish in ipairs({
		{ id = "SmallFish", name = "Small Fish", rarity = "Common", value = 5 },
		{ id = "Bluegill", name = "Bluegill", rarity = "Common", value = 12 },
		{ id = "Koi", name = "Koi", rarity = "Rare", value = 75 },
		{ id = "GoldenCarp", name = "Golden Carp", rarity = "Epic", value = 160 },
	}) do
		makeAquariumFish(fishFolder, fish, origin, index, 604200, dimensions)
	end

	aquarium.PrimaryPart = base
end

local function removeGeneratedBiomePlaceholders(world)
	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		for _, name in ipairs({
			biome.displayName .. " Island",
			biome.displayName .. " Water",
			biomeId .. "Dock",
			biome.displayName .. " Sign",
		}) do
			local placeholder = world:FindFirstChild(name)
			if placeholder then
				placeholder:Destroy()
			end
		end
	end
end

local function removeAllGeneratedBiomePlaceholders()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == "FishyFishWorld"
			and (descendant:IsA("Folder") or descendant:IsA("Model"))
		then
			removeGeneratedBiomePlaceholders(descendant)
		end
	end
end

local function buildWorld()
	-- The entire visible map is authored in Studio. Runtime startup may attach
	-- gameplay behavior, but it must never destroy, reparent, rebuild, mirror, or
	-- restyle authored geometry. Find the nested authored world before creating
	-- a bookkeeping folder for genuinely empty development places.
	local world = workspace:FindFirstChild("FishyFishWorld", true)
	if not world then
		world = Instance.new("Folder")
		world.Name = "FishyFishWorld"
		world.Parent = workspace
	end

	local galleryPrepared, galleryError = pcall(function()
		local galleryService = require(script.Parent:WaitForChild("AquariumGalleryPrototypeService"))
		galleryService.ensure()
		galleryService.applyAuthoredMigration()
	end)
	if not galleryPrepared then
		warn("Aquarium gallery prototype preparation failed", galleryError)
	end
	ensurePrebuiltAquariumSlots()
	ensureFountainAnimations()
	ensureFountainBiomeWarpTrigger()
	connectBiomeWarpTouches()
	connectSellFishPrompts()
	connectRodShopPrompts()
	ensureLobbyInvisibleBoundaries()

	do
		local castleScript = game:GetService("ServerScriptService"):FindFirstChild("CastleShopService")
		if castleScript then
			local ok, castleService = pcall(require, castleScript)
			if ok and type(castleService) == "table" and type(castleService.ensure) == "function" then
				castleService.ensure()
			end
		end
	end
end

local function ensureWorld()
	buildWorld()
end

local function safeEnsureWorld(context)
	local success, err = pcall(ensureWorld)
	if not success then
		warn("World setup failed", context or "", err)
	end

	EditorVisuals.restore()

	local lilyshoreSuccess, lilyshoreError = pcall(function()
		require(script.Parent:WaitForChild("LilyshoreIslandService")).ensure()
	end)
	if not lilyshoreSuccess then
		warn("Lilyshore Island setup failed", context or "", lilyshoreError)
	end
end

function Bait.calculateCatchValue(fish, baitId)
	local bait = Bait.getData(baitId)
	local multiplier = tonumber(bait.valueMultiplier) or 1
	return math.max(1, math.floor((tonumber(fish.value) or 1) * multiplier + 0.5))
end

function Bait.calculateCatchXP(fish, baitId, isAutoFish)
	local bait = Bait.getData(baitId)
	local xp = GameConfig.RarityXP[fish.rarity] or 10
	xp = math.max(1, math.floor(xp * (tonumber(bait.xpMultiplier) or 1) + 0.5))

	if isAutoFish then
		xp = math.max(1, math.floor(xp * 0.75))
	end

	return xp
end

local FishingRuntime = {
	MinigameValidationService = require(script.Parent:WaitForChild("MinigameValidationService")),
	Water = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishingWater")),
}

function FishingRuntime.chooseFish(data, isAutoFish, baitId, extraRareChanceBonus)
	local biome = IslandConfig.getBiomeData(data)
	local rod = RodVisual.getRodData(data)
	local bait = Bait.getData(baitId)
	local luck = (rod.luck or 0) + (tonumber(bait.rareChanceBonus) or 0) + (tonumber(extraRareChanceBonus) or 0)

	if isAutoFish then
		luck = (luck * 0.45) - 0.12
	end

	local totalWeight = 0
	local weights = {}

	for index, fish in ipairs(biome.fish) do
		local rarityWeight = rarityLuckWeight[fish.rarity] or 0
		local adjusted = fish.chance * math.max(0.05, 1 + (luck * rarityWeight))
		if tostring(fish.id or fish.imageKey or "") == tostring(bait.targetFishId or "") then
			adjusted *= math.max(1, tonumber(bait.targetFishChanceMultiplier) or 1)
		end
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

function FishingRuntime.awardCatch(player, fish, isAutoFish, baitId, castResult)
	local data = playerData[player]
	if not data then
		return
	end

	if not fish then
		notify(player, "The fish escaped.")
		return
	end

	if #data.Inventory >= data.BackpackSize then
		notify(player, "Backpack full. Sell fish first.")
		return
	end

	local bait = Bait.getData(baitId)
	local value = Bait.calculateCatchValue(fish, baitId)
	local xp = Bait.calculateCatchXP(fish, baitId, isAutoFish)

	fishSerial += 1

	local entry = {
		serial = fishSerial,
		id = fish.id,
		name = fish.name,
		rarity = fish.rarity,
		imageKey = fish.imageKey or fish.id,
		value = value,
		baseValue = fish.value,
		bait = Bait.normalizeId(baitId),
		biome = data.CurrentBiome,
		score = 100,
	}

	table.insert(data.Inventory, entry)
	data.Fishdex[fish.id] = (data.Fishdex[fish.id] or 0) + 1
	data.TotalFishCaught = (data.TotalFishCaught or 0) + 1
	local xpBefore = GameConfig.clampXP(data.XP)
	data.XP = GameConfig.clampXP(xpBefore + xp)
	local awardedXP = data.XP - xpBefore
	Quest.recordCatch(data, fish)
	local resourceId = FishingResources.rollForCatch(data, isAutoFish, castResult)

	if not data.BestCatch or value > data.BestCatch.value then
		data.BestCatch = entry
	end

	updateLeaderstats(player)
	sendState(player)
	FishCaughtLeaderboard.publish(player, data)
	playerData.queueSave(player)

	local prefix = isAutoFish and "Auto caught" or "Caught"
	local baitText = bait and bait.displayName and bait.displayName ~= "Basic Bait" and (" using " .. bait.displayName) or ""
	local message = string.format("%s %s [%s]%s Value: %d +%d XP", prefix, fish.name, fish.rarity, baitText, value, awardedXP)
	if resourceId then
		local resource = ResourceConfig.Resources[resourceId]
		message ..= "\nBonus: " .. resource.displayName .. " x1"
	end
	notify(player, message)
end

function FishingRuntime.makeMinigamePrompt(biomeId, biteDelay, fish, rodId, sessionId, isAutoFish, baitId, remainingBait, castResult, minigameSeed)
	local bait = Bait.getData(baitId)
	local xp = Bait.calculateCatchXP(fish, baitId, isAutoFish)
	local value = Bait.calculateCatchValue(fish, baitId)
	local minigame = GameConfig.getFishingMinigameConfig(fish.rarity, rodId)

	if castResult and not isAutoFish then
		minigame.progressGainPerSecond *= tonumber(castResult.progressGainMultiplier) or 1
	end

	return {
		biomeId = biomeId,
		biteDelay = biteDelay,
		autoFish = isAutoFish == true,
		sessionId = sessionId,
		minigameSeed = minigameSeed,
		fish = {
			id = fish.id,
			name = fish.name,
			rarity = fish.rarity,
			value = value,
			xp = xp,
			imageKey = fish.imageKey or fish.id,
		},
		bait = {
			id = Bait.normalizeId(baitId),
			name = bait.displayName,
			remaining = remainingBait,
		},
		cast = castResult and {
			power = castResult.power,
			rating = castResult.rating,
			displayName = castResult.displayName,
			accuracy = castResult.accuracy,
			progressGainMultiplier = castResult.progressGainMultiplier,
			sparkle = castResult.sparkle == true,
		} or nil,
		minigame = minigame,
	}
end

Travel = {}
Travel.Lilyshore = require(script.Parent:WaitForChild("LilyshoreIslandService"))

function Travel.getPlayerRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

function Travel.getCastResult(castPower)
	return CastConfigService.getCastResult(castPower)
end

function Travel.getLobbyConfig()
	return GameConfig.Lobby or {
		spawnPosition = Vector3.new(-147, 10, -492),
		bounds = {
			minX = -325,
			maxX = -15,
			minZ = -605,
			maxZ = -300,
		},
	}
end

function Travel.isLobbyPosition(position)
	local bounds = Travel.getLobbyConfig().bounds
	if not bounds then
		return false
	end

	return position.X >= bounds.minX
		and position.X <= bounds.maxX
		and position.Z >= bounds.minZ
		and position.Z <= bounds.maxZ
end

function Travel.findLobbySpawnLocation()
	local definition = workspace:FindFirstChild("LobbyDefinition")
	if definition then
		local spawn = definition:FindFirstChild("LobbySpawn", true)
		if spawn and spawn:IsA("SpawnLocation") then
			return spawn
		end
	end

	local spawn = workspace:FindFirstChild("LobbySpawn", true)
	if spawn and spawn:IsA("SpawnLocation") then
		return spawn
	end

	return nil
end

function Travel.isBeginnerPondInstance(instance)
	if Travel.Lilyshore.isIslandInstance(instance) then
		return true
	end

	while instance do
		if instance.Name == "LilyshoreIsland"
			or instance.Name == "BeginnerPondArea"
			or instance.Name == "BeginnerPond_ExtraLarge"
			or instance.Name == "Beginner Pond"
		then
			return true
		end
		instance = instance.Parent
	end

	return false
end

function Travel.getGroundBiomeAtPosition(position, ignoreInstances)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreInstances or {}

	local result = workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -90, 0), params)
	if result then
		if Travel.isBeginnerPondInstance(result.Instance) then
			return DEFAULT_FISHING_ISLAND_ID
		end

		local ancestor = result.Instance
		while ancestor and ancestor ~= workspace do
			local configuredBiomeId = ancestor:GetAttribute("BiomeId") or ancestor:GetAttribute("IslandId")
			local biomeId = if type(configuredBiomeId) == "string"
				then IslandConfig.normalizeBiomeId(configuredBiomeId)
				else nil
			biomeId = biomeId or IslandConfig.normalizeBiomeId(ancestor.Name)
			if biomeId then
				return biomeId
			end
			ancestor = ancestor.Parent
		end
	end

	return nil
end

function Travel.getBiomeAtPosition(position, ignoreInstances)
	local groundBiomeId = Travel.getGroundBiomeAtPosition(position, ignoreInstances)
	if groundBiomeId then
		return groundBiomeId
	end

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		local center = biome.position
		local dx = math.abs(position.X - center.X)
		local dz = math.abs(position.Z - center.Z)
		local rangeX = 58
		local rangeZ = 54

		if dx <= rangeX and dz <= rangeZ then
			return biomeId
		end
	end

	return nil
end

function Travel.getLobbyTeleportPosition()
	local generatedWorld = workspace:FindFirstChild("FishyFishWorld")
	local exactNames = {
		"LimestoneLobbySpawn",
		"LimestoneSpawn",
		"LobbyTeleport",
		"LobbyTeleportPoint",
		"LobbySpawnPoint",
		"LobbySpawn",
	}

	local function getTeleportPositionFromInstance(instance, lift)
		if instance:IsA("BasePart") then
			return instance.Position + Vector3.new(0, (instance.Size.Y / 2) + lift, 0)
		end

		if instance:IsA("Model") then
			local primary = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
			if primary then
				return primary.Position + Vector3.new(0, (primary.Size.Y / 2) + lift, 0)
			end
		end

		return nil
	end

	local lobbyDefinition = workspace:FindFirstChild("LobbyDefinition")
	if lobbyDefinition then
		for _, name in ipairs(exactNames) do
			local marker = lobbyDefinition:FindFirstChild(name, true)
			if marker then
				local position = getTeleportPositionFromInstance(marker, 4)
				if position then
					return position
				end
			end
		end
	end

	local fishingAreas = workspace:FindFirstChild("FishingAreas")
	local savedLobby = fishingAreas and fishingAreas:FindFirstChild("LobbyArea")
	if savedLobby then
		for _, name in ipairs(exactNames) do
			local marker = savedLobby:FindFirstChild(name, true)
			if marker then
				local position = getTeleportPositionFromInstance(marker, 4)
				if position then
					return position
				end
			end
		end
	end

	for _, name in ipairs(exactNames) do
		local marker = workspace:FindFirstChild(name, true)
		if marker then
			local lowerName = string.lower(marker.Name)
			local isGenerated = generatedWorld and marker:IsDescendantOf(generatedWorld)
			if not isGenerated or string.find(lowerName, "limestone") then
				local position = getTeleportPositionFromInstance(marker, 4)
				if position then
					return position
				end
			end
		end
	end

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("SpawnLocation") and (not generatedWorld or not descendant:IsDescendantOf(generatedWorld)) then
			return getTeleportPositionFromInstance(descendant, 4)
		end
	end

	for _, descendant in ipairs(workspace:GetDescendants()) do
		local lowerName = string.lower(descendant.Name)
		if string.find(lowerName, "limestone") and string.find(lowerName, "lobby") then
			local position = getTeleportPositionFromInstance(descendant, 5)
			if position then
				return position
			end
		end
	end

	return Travel.getLobbyConfig().spawnPosition or Vector3.new(-147, 10, -492)
end

getPlayerFishingBiome = function(player)
	local root = Travel.getPlayerRoot(player)
	if not root then
		return nil
	end

	local biomeId = Travel.getBiomeAtPosition(root.Position, { player.Character })
	if not biomeId
		or not FishingRuntime.Water.isNearWater(root.Position, { player.Character })
	then
		return nil
	end

	return biomeId
end

getPlayerTravelLocation = function(player)
	local root = Travel.getPlayerRoot(player)
	if not root then
		return nil
	end

	local biomeId = Travel.getBiomeAtPosition(root.Position, { player.Character })
	if biomeId then
		return biomeId
	end

	if Travel.isLobbyPosition(root.Position) then
		return "Lobby"
	end

	local hubPosition = getAquariumHubTeleportPosition()
	local aquariumPosition = getPlayerAquariumTeleportPosition(player)
	if (root.Position - hubPosition).Magnitude <= 125 or (root.Position - aquariumPosition).Magnitude <= 90 then
		return "AquariumHub"
	end

	return "Lobby"
end

function FishingRuntime.startAutoFish(player)
	local data = playerData[player]
	if not data or data.AutoFishRunning then
		return
	end

	data.AutoFishRunning = true

	task.spawn(function()
		while player.Parent and playerData[player] == data and data.AutoFishEnabled do
			if not RodVisual.getHeldFishingRodTool(player, data) then
				data.AutoFishEnabled = false
				data.AutoFishRunning = false
				pendingFishing[player] = nil
				sendState(player)
				notify(player, "AutoFish stopped. Hold your fishing rod to fish.")
				return
			end

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

			local rod = RodVisual.getRodData(data)
			local baitPreview = Bait.getData(Bait.getEquippedId(data))
			local waitTime = Random.new():NextNumber(RuntimeConfig.autoFishMinWait, RuntimeConfig.autoFishMaxWait)
				* math.max(0.85, rod.speed)
				* math.max(0.75, tonumber(baitPreview.biteSpeedMultiplier) or 1)
			task.wait(waitTime)

			if not player.Parent or playerData[player] ~= data or not data.AutoFishEnabled then
				break
			end

			if not RodVisual.getHeldFishingRodTool(player, data) then
				data.AutoFishEnabled = false
				data.AutoFishRunning = false
				pendingFishing[player] = nil
				sendState(player)
				notify(player, "AutoFish stopped. Hold your fishing rod to fish.")
				return
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
					notify(player, "AutoFish stopped. Move closer to the water to fish.")
					return
				end

				if not IslandConfig.isBiomeUnlocked(data, locationBiomeId) then
					data.AutoFishEnabled = false
					data.AutoFishRunning = false
					sendState(player)
					notify(player, "AutoFish stopped. Unlock this island first.")
					return
				end

				data.CurrentBiome = locationBiomeId

				local rodId = data.EquippedRod or "WoodenRod"
				local baitId, bait = Bait.consumeForCast(data)
				local biteDelay = 0.2 * math.max(0.75, tonumber(bait.biteSpeedMultiplier) or 1)
				local fish = FishingRuntime.chooseFish(data, true, baitId)
				local visualTime = 3
				pendingFishing[player] = {
					autoFish = true,
					biomeId = locationBiomeId,
					fish = fish,
					baitId = baitId,
				}
				sendState(player)

				local prompt = FishingRuntime.makeMinigamePrompt(locationBiomeId, biteDelay, fish, rodId, nil, true, baitId, Bait.getRemainingForClient(data, baitId))
				prompt.visualTime = visualTime
				Remote.FishingPrompt:FireClient(player, prompt)

				task.wait(visualTime + 0.25)

				if not player.Parent or playerData[player] ~= data or not data.AutoFishEnabled then
					pendingFishing[player] = nil
					break
				end

				if not RodVisual.getHeldFishingRodTool(player, data) then
					data.AutoFishEnabled = false
					data.AutoFishRunning = false
					pendingFishing[player] = nil
					sendState(player)
					notify(player, "AutoFish stopped. Hold your fishing rod to fish.")
					return
				end

				pendingFishing[player] = nil
				FishingRuntime.awardCatch(player, fish, true, baitId, nil)
			end
		end

		if playerData[player] == data then
			data.AutoFishRunning = false
			sendState(player)
		end
	end)
end

local RodPurchase = {
	Locks = {},
}

function RodPurchase.validate(data, rodId)
	local rod = GameConfig.Rods[rodId]
	if not rod then
		return false, "Unknown rod."
	end
	if RodVisual.ownsRod(data, rodId) then
		return false, "Already owned."
	end
	if rod.previousRod and not RodVisual.ownsRod(data, rod.previousRod) then
		return false, "Need " .. GameConfig.Rods[rod.previousRod].displayName .. "."
	end
	if data.Level < rod.unlockLevel then
		return false, "Need level " .. rod.unlockLevel .. "."
	end

	local inventory = ResourceConfig.NormalizeInventory(data.ResourceInventory)
	for _, resourceId in ipairs(ResourceConfig.ResourceOrder) do
		local required = tonumber(rod.resourceCosts and rod.resourceCosts[resourceId]) or 0
		if required > 0 and inventory[resourceId] < required then
			local resource = ResourceConfig.Resources[resourceId]
			return false, string.format("Need %d %s (%d/%d).", required, resource.displayName, inventory[resourceId], required)
		end
	end
	if data.Coins < rod.cost then
		return false, "Need " .. rod.cost .. " coins."
	end
	return true, nil, rod
end

function RodPurchase.revalidateBudget(data, rod)
	local inventory = ResourceConfig.NormalizeInventory(data.ResourceInventory)
	for _, resourceId in ipairs(ResourceConfig.ResourceOrder) do
		local required = tonumber(rod.resourceCosts and rod.resourceCosts[resourceId]) or 0
		if required > 0 and inventory[resourceId] < required then
			return false, "Resources changed. Purchase canceled."
		end
	end
	if data.Coins < rod.cost then
		return false, "Coins changed. Purchase canceled."
	end
	return true
end

function RodPurchase.deductAndGrant(data, rodId, rod)
	data.ResourceInventory = ResourceConfig.NormalizeInventory(data.ResourceInventory)
	data.Coins -= rod.cost
	for _, resourceId in ipairs(ResourceConfig.ResourceOrder) do
		local required = tonumber(rod.resourceCosts and rod.resourceCosts[resourceId]) or 0
		if required > 0 then
			data.ResourceInventory[resourceId] -= required
		end
	end
	data.OwnedRods[rodId] = true
	data.EquippedRod = rodId
end

local IslandPurchase = {
	Locks = {},
}

function IslandPurchase.validate(data, biomeId)
	biomeId = IslandConfig.normalizeBiomeId(biomeId)
	local biome = GameConfig.Biomes[biomeId]
	if not biome then
		return false, "Unknown island."
	end
	if IslandConfig.isBiomeUnlocked(data, biomeId) then
		return false, "Already unlocked."
	end
	if data.Level < biome.unlockLevel then
		return false, "Need level " .. biome.unlockLevel .. "."
	end
	if biome.requiredRod and not RodVisual.ownsRod(data, biome.requiredRod) then
		return false, "Need " .. GameConfig.Rods[biome.requiredRod].displayName .. "."
	end
	if data.Coins < biome.cost then
		return false, "Need " .. biome.cost .. " coins."
	end
	return true, nil, biomeId, biome
end

local function canUnlockBiome(data, biomeId)
	return IslandPurchase.validate(data, biomeId)
end

function Travel.teleportPlayer(player, target)
	target = IslandConfig.normalizeTravelTarget(target)
	if not target then
		return false
	end

	local position
	local destination
	local sourceArea = getPlayerTravelLocation and getPlayerTravelLocation(player) or nil
	if player:GetAttribute("FishyFishTravelTarget") == target then
		sourceArea = player:GetAttribute("FishyFishTravelSource") or sourceArea
	end

	if target == IslandConfig.SeasideIslandId then
		position = Travel.getLobbyTeleportPosition()
	elseif target == IslandConfig.AquariumHubId then
		refreshPlayerAquarium(player)
		sendStateToAll()
		position = AquariumLayout.getHubSpawnPosition()
	elseif target == DEFAULT_FISHING_ISLAND_ID then
		destination = Travel.Lilyshore.getSpawnCFrame(sourceArea)
		if not destination then
			position = GameConfig.Biomes[target].position
		end
	elseif GameConfig.Biomes[target] then
		position = GameConfig.Biomes[target].position
	end

	if position or destination then
		if target == IslandConfig.AquariumHubId then
			destination = CFrame.lookAt(position, AquariumLayout.AreaOrigin + Vector3.new(0, 4, 0))
		elseif not destination then
			destination = CFrame.new(position)
		end

		local moved = AquariumLayout.safePivotPlayer(player, destination)
		if not moved then
			return false
		end

		player:SetAttribute("FishyFishTravelTarget", target)
		player:SetAttribute("FishyFishTravelSource", sourceArea or IslandConfig.SeasideIslandId)
		return true
	end

	return false
end

function Travel.teleportPlayerToAquariumOwner(player, ownerPlayer)
	if not ownerPlayer or not ownerPlayer.Parent then
		notify(player, "That player is no longer online.")
		return false
	end

	local ownerData = playerData[ownerPlayer]
	if not ownerData then
		notify(player, "That aquarium is not ready yet.")
		return false
	end

	print("Loading aquarium:", ownerPlayer.DisplayName or ownerPlayer.Name)
	refreshPlayerAquarium(ownerPlayer)

	local galleryCFrame
	pcall(function()
		galleryCFrame = require(script.Parent:WaitForChild("AquariumGalleryPrototypeService"))
			.getPlayerViewCFrame(ownerPlayer.UserId, (player.UserId % 4) + 1)
	end)
	local destination = galleryCFrame
	if not destination then
		local position = AquariumLayout.getViewerSpawnPosition(ownerPlayer)
		local lookAt = getAquariumSlotOrigin(getPlayerAquariumSlot(ownerPlayer)) + Vector3.new(0, 5, 0)
		destination = CFrame.lookAt(position, lookAt)
	end
	local moved = AquariumLayout.safePivotPlayer(player, destination)
	if not moved then
		return false
	end

	sendStateToAll()
	notify(player, "Visiting " .. ownerPlayer.DisplayName .. "'s aquarium.")
	return true
end

function Travel.teleportPlayerToAquariumUserId(player, ownerUserId)
	ownerUserId = tonumber(ownerUserId)
	if not ownerUserId then
		return false
	end

	local ownerPlayer = Services.Players:GetPlayerByUserId(ownerUserId)
	if ownerPlayer then
		return Travel.teleportPlayerToAquariumOwner(player, ownerPlayer)
	end

	local snapshot = Services.AquariumDirectory.getSnapshot(ownerUserId)
	if type(snapshot) ~= "table" or type(snapshot.Aquarium) ~= "table" then
		notify(player, "That aquarium is not available yet.")
		return false
	end

	playerData.ManualFeaturedSnapshot = snapshot
	playerData.ManualFeaturedUntil = os.clock() + 120
	if not playerData.showAquariumSnapshotInCenter(snapshot, "NOW VIEWING") then
		notify(player, "That aquarium could not be displayed.")
		return false
	end

	local destination
	pcall(function()
		destination = require(script.Parent:WaitForChild("AquariumGalleryPrototypeService"))
			.getFeaturedViewCFrame((player.UserId % 4) + 1)
	end)
	if not destination then
		local position = AquariumLayout.getViewerSpawnPosition(player)
		local lookAt = getAquariumSlotOrigin(1) + Vector3.new(0, 5, 0)
		destination = CFrame.lookAt(position, lookAt)
	end
	if not AquariumLayout.safePivotPlayer(player, destination) then
		return false
	end

	sendStateToAll()
	notify(player, "Viewing " .. tostring(snapshot.DisplayName or snapshot.Name or "this player") .. "'s read-only aquarium.")
	return true
end

local areaPortalTouchCooldowns = {}
local remoteTravelRequests = {}
local REMOTE_TRAVEL_DEBOUNCE_SECONDS = 1

function Travel.tryBeginRemoteTravel(player)
	local now = os.clock()
	local request = remoteTravelRequests[player]
	if request and (request.inFlight or now - request.lastStarted < REMOTE_TRAVEL_DEBOUNCE_SECONDS) then
		return false
	end

	remoteTravelRequests[player] = {
		inFlight = true,
		lastStarted = now,
	}
	return true
end

function Travel.finishRemoteTravel(player)
	local request = remoteTravelRequests[player]
	if request then
		request.inFlight = false
	end
end

function Travel.connectAreaPortalTrigger(part)
	if not part:IsA("BasePart") then
		return
	end

	local targetArea = part:GetAttribute("TargetArea")
	if not targetArea and part.Name == "AquariumWarpTrigger" and part:FindFirstAncestor("LobbyAquariumWarp") then
		targetArea = "AquariumHub"
		part:SetAttribute("TargetArea", targetArea)
	end

	if not targetArea and not Services.CollectionService:HasTag(part, "AreaPortal") then
		return
	end

	if targetArea == "BiomeWarp" then
		connectBiomeWarpTouch(part)
		return
	end

	if part:GetAttribute("FishyFishAreaPortalConnected") then
		return
	end

	part:SetAttribute("FishyFishAreaPortalConnected", true)
	part.CanTouch = true
	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Services.Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local now = os.clock()
		if areaPortalTouchCooldowns[player] and now - areaPortalTouchCooldowns[player] < 1.5 then
			return
		end
		areaPortalTouchCooldowns[player] = now

		local data = playerData[player]
		local target = part:GetAttribute("TargetArea")
		if not target and part.Name == "AquariumWarpTrigger" and part:FindFirstAncestor("LobbyAquariumWarp") then
			target = "AquariumHub"
		end
		if not data or not target then
			return
		end

		if target == "BiomeWarp" then
			openBiomeWarpForPlayer(player)
			return
		end

		target = IslandConfig.normalizeTravelTarget(target)
		if not target then
			return
		end

		if GameConfig.Biomes[target] and not IslandConfig.isBiomeUnlocked(data, target) then
			notify(player, "Unlock that island first.")
			return
		end

		local moved = Travel.teleportPlayer(player, target)
		if moved then
			if GameConfig.Biomes[target] then
				data.CurrentBiome = target
			end
			sendState(player)
		end
	end)
end

function Travel.connectAreaPortalTriggers()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		Travel.connectAreaPortalTrigger(descendant)
	end
end

workspace.DescendantAdded:Connect(function(descendant)
	task.defer(Travel.connectAreaPortalTrigger, descendant)
end)

function RuntimeConfig.setupPlayer(player)
	if playerData[player] then
		return
	end

	local loadedData = loadData(player)
	if not loadedData or not player.Parent then
		return
	end
	playerData[player] = loadedData
	Services.AquariumDirectory.markOnline(player)
	local appliedOwnerGrant = applyOwnerGrants(player, playerData[player])
	Monetization.syncGamePassOwnership(player, playerData[player])
	local addedStudioFish = giveStudioBeginnerFishInBag(playerData[player])
	local studioFishNoticeSent = false
	safeEnsureWorld("player setup")
	local lobbySpawn = Travel.findLobbySpawnLocation()
	if lobbySpawn then
		player.RespawnLocation = lobbySpawn
	end
	Travel.connectAreaPortalTriggers()
	ensureHudAccessToolsForPlayer(player)
	setupLeaderstats(player)
	updateLeaderstats(player)
	FishCaughtLeaderboard.publish(player, playerData[player])

	player.CharacterAdded:Connect(function()
		task.defer(function()
			safeEnsureWorld("character added")
			ensureHudAccessToolsForPlayer(player)
			local data = playerData[player]
			if data then
				refreshFishingRodForPlayer(player, data)
				applyCharacterMonetizationVisuals(player)
			end

			local respawnTarget = player:GetAttribute("FishyFishTravelTarget")
			if respawnTarget and respawnTarget ~= IslandConfig.SeasideIslandId then
				task.wait(0.2)
				Travel.teleportPlayer(player, respawnTarget)
			end
		end)
	end)

	task.defer(function()
		local data = playerData[player]
		safeEnsureWorld("deferred player setup")
		if data then
			refreshPlayerAquarium(player)
			applyCharacterMonetizationVisuals(player)
		end
		sendState(player)
		if addedStudioFish and not studioFishNoticeSent then
			studioFishNoticeSent = true
			notify(player, "Added beginner pond fish to your Bag for testing.")
		end
		if data then
			refreshFishingRodForPlayer(player, data)
		end
		if appliedOwnerGrant then
			saveData(player)
			notify(player, "Owner grant applied: 100000 coins.")
		end
		if data and data.AutoFishEnabled then
			FishingRuntime.startAutoFish(player)
		end
		sendStateToAll()
		FishCaughtLeaderboard.refresh(true)
	end)
end

CastConfigService.configure({
	getPlayerData = function(player)
		return playerData[player]
	end,
	getPlayerFishingBiome = function(player)
		return getPlayerFishingBiome and getPlayerFishingBiome(player) or nil
	end,
	isBiomeUnlocked = IslandConfig.isBiomeUnlocked,
})

Remote.GetState.OnServerInvoke = function(player)
	local data = playerData[player]
	if not data then
		return nil
	end

	local success, clientState = pcall(makeClientState, player, data)
	if not success then
		warn("GetState failed for", player.Name, clientState)
		return nil
	end

	return clientState
end

function FishingRuntime.awardPendingFishing(player, expectedSessionId, reason)
	local data = playerData[player]
	local pending = pendingFishing[player]
	if not data
		or not pending
		or pending.autoFish
		or pending.sessionId ~= expectedSessionId
	then
		return false
	end

	-- Clear the exact session before awarding so the client completion packet,
	-- timeout watchdog, and recovery cast can never award the same fish twice.
	pendingFishing[player] = nil
	if reason then
		warn("[FishingSession] Awarding guaranteed catch", player.Name, reason)
	end

	data.CurrentBiome = pending.biomeId
	FishingRuntime.awardCatch(player, pending.fish, false, pending.baitId, pending.castResult)
	return true
end

Remote.StartFishing.OnServerEvent:Connect(function(player, requestedBiome)
	local data = playerData[player]
	if not data then
		return
	end

	if not RodVisual.getHeldFishingRodTool(player, data) then
		notify(player, "Hold your fishing rod before fishing.")
		return
	end

	local castRequest = type(requestedBiome) == "table" and requestedBiome or nil
	local requestedBiomeId = IslandConfig.normalizeBiomeId(castRequest and castRequest.biomeId or requestedBiome)
	local biomeId = GameConfig.Biomes[requestedBiomeId] and requestedBiomeId or data.CurrentBiome
	local locationBiomeId = getPlayerFishingBiome(player)

	if not locationBiomeId then
		notify(player, "Move closer to the water before fishing.")
		return
	end

	local rootPart = Travel.getPlayerRoot(player)
	local castSurface = rootPart and FishingRuntime.Water.findCastSurface(
		rootPart.Position,
		rootPart.CFrame.LookVector,
		rootPart.CFrame.RightVector,
		{ player.Character }
	)
	if not castSurface then
		notify(player, "Face the nearby water before casting.")
		return
	end

	if requestedBiomeId and requestedBiomeId ~= locationBiomeId then
		notify(player, "You can only cast on the island you are standing on.")
		return
	end

	biomeId = locationBiomeId

	local existingPending = pendingFishing[player]
	if existingPending then
		if existingPending.autoFish then
			return
		end

		if os.clock() >= (existingPending.expiresAt or math.huge) then
			FishingRuntime.awardPendingFishing(player, existingPending.sessionId, "stale session recovered on cast")
		else
			-- The client can lose its local UI during a respawn or script refresh while
			-- the server still owns the hook. Re-open that exact catch instead of
			-- trapping the player behind an "Already fishing" message.
			local resumePrompt = FishingRuntime.makeMinigamePrompt(
				existingPending.biomeId,
				0,
				existingPending.fish,
				existingPending.rodId or data.EquippedRod or "WoodenRod",
				existingPending.sessionId,
				false,
				existingPending.baitId,
				Bait.getRemainingForClient(data, existingPending.baitId),
				existingPending.castResult,
				existingPending.minigameSeed
			)
			Remote.FishingPrompt:FireClient(player, resumePrompt)
			return
		end
	end

	if pendingFishing[player] then
		return
	end

	if not IslandConfig.isBiomeUnlocked(data, biomeId) then
		notify(player, "Unlock that island first.")
		return
	end

	if #data.Inventory >= data.BackpackSize then
		notify(player, "Backpack full. Sell fish first.")
		return
	end

	data.CurrentBiome = biomeId
	local rod = RodVisual.getRodData(data)
	local rodId = data.EquippedRod or "WoodenRod"
	local baitId, bait = Bait.consumeForCast(data)
	local castPower = castRequest and (castRequest.castPower or castRequest.power) or nil
	local hasCastPower = tonumber(castPower) ~= nil
	local castResult = hasCastPower and CastConfigService.consume(player, castRequest, data, biomeId) or nil
	if castResult and castResult.countsAsPerfect then
		Quest.recordPerfectCast(data)
	end
	local biteDelay = Random.new():NextNumber(2, 5)
		* rod.speed
		* math.max(0.65, tonumber(bait.biteSpeedMultiplier) or 1)
		* math.max(0.75, tonumber(castResult and castResult.biteSpeedMultiplier) or 1)
	local fish = FishingRuntime.chooseFish(data, false, baitId)
	local requestedAt = os.clock()
	local sessionId = tostring(math.floor(requestedAt * 1000)) .. ":" .. tostring(Random.new():NextInteger(100000, 999999))
	local minigameSeed = Random.new():NextInteger(1, 2147483646)
	local minigameConfig = GameConfig.getFishingMinigameConfig(fish.rarity, rodId)
	local minigameDifficulty = minigameConfig.difficulty or GameConfig.FishingMinigame.RarityDifficulty.Common
	if fish.rarity == "Uncommon" then
		minigameDifficulty = GameConfig.FishingMinigame.RarityDifficulty.Common
	end
	if castResult then
		minigameConfig.progressGainPerSecond *= tonumber(castResult.progressGainMultiplier) or 1
	end

	pendingFishing[player] = {
		biomeId = biomeId,
		requestedAt = requestedAt,
		biteDelay = biteDelay,
		fish = fish,
		baitId = baitId,
		castResult = castResult,
		rodId = rodId,
		sessionId = sessionId,
		minigameSeed = minigameSeed,
		expiresAt = requestedAt
			+ biteDelay
			+ (tonumber(minigameConfig.maxDuration) or 35)
			+ 5,
		validation = FishingRuntime.MinigameValidationService.newSession({
			sessionId = sessionId,
			requestedAt = requestedAt,
			biteDelay = biteDelay,
			seed = minigameSeed,
			rarity = fish.rarity,
			config = minigameConfig,
			difficulty = minigameDifficulty,
		}),
	}

	sendState(player)
	playerData.queueSave(player)
	Remote.FishingPrompt:FireClient(player, FishingRuntime.makeMinigamePrompt(biomeId, biteDelay, fish, rodId, sessionId, false, baitId, Bait.getRemainingForClient(data, baitId), castResult, minigameSeed))

	local completionDelay = math.max(0, pendingFishing[player].expiresAt - os.clock())
	task.delay(completionDelay, function()
		FishingRuntime.awardPendingFishing(player, sessionId, "client completion timeout")
	end)
end)

Remote.FinishMinigame.OnServerEvent:Connect(function(player, result)
	local data = playerData[player]
	local pending = pendingFishing[player]
	if not data or not pending then
		return
	end

	if pending.autoFish then
		return
	end

	local action = type(result) == "table" and result.action or nil
	if type(result) == "table"
		and action == nil
		and result.sessionId == pending.sessionId
		and (result.success == nil or type(result.success) == "boolean")
	then
		action = "Complete"
	end

	if type(result) == "table" and action == "Input" then
		FishingRuntime.MinigameValidationService.recordInput(pending.validation, result, os.clock())
		return
	end

	if type(result) ~= "table"
		or action ~= "Complete"
		or result.sessionId ~= pending.sessionId
	then
		return
	end

	if not RodVisual.getHeldFishingRodTool(player, data) then
		warn("[FishingValidation] Awarding catch after held-rod state changed", player.Name)
	end

	local valid, validationReason = FishingRuntime.MinigameValidationService.evaluate(
		pending.validation,
		result,
		os.clock()
	)
	if not valid then
		warn("[FishingValidation] Awarding guaranteed catch", player.Name, validationReason)
	end

	-- A hooked fish is guaranteed. Validation remains useful for diagnostics,
	-- but a late input packet, clock difference, or rod-state race must never
	-- turn a completed minigame into an escaped fish.
	FishingRuntime.awardPendingFishing(player, pending.sessionId)
end)

Remote.SellFish.OnServerEvent:Connect(function(player, action, fishSerialToSell, fishIndexToSell)
	local data = playerData[player]
	if not data then
		return
	end

	if action == "Single" then
		local targetIndex = findInventoryFishIndex(data, fishSerialToSell, fishIndexToSell)

		if not targetIndex then
			notify(player, "That fish is no longer in your inventory.")
			sendState(player)
			return
		end

		local fish = table.remove(data.Inventory, targetIndex)
		local value = Monetization.getSellValue(data, fish.value)
		data.Coins += value

		updateLeaderstats(player)
		sendState(player)
		playerData.queueSave(player)
		notify(player, "Sold " .. fish.name .. " for " .. value .. " coins.")
		return
	end

	sellAllFishForPlayer(player)
end)

Remote.BuyRod.OnServerEvent:Connect(function(player, rodId, action)
	local data = playerData[player]
	local rod = GameConfig.Rods[rodId]
	if not data then
		return
	end
	if not rod then
		notify(player, "Unknown rod.")
		return
	end

	if action == "Equip" then
		if not RodVisual.ownsRod(data, rodId) then
			notify(player, "You do not own " .. rod.displayName .. ".")
			return
		end
		data.EquippedRod = rodId
		refreshFishingRodForPlayer(player, data)
		RodVisual.equipFishingRodToolForPlayer(player)
		task.delay(0.15, function()
			local latestData = playerData[player]
			if latestData and latestData.EquippedRod == rodId then
				RodVisual.equipFishingRodToolForPlayer(player)
			end
		end)
		sendState(player)
		playerData.queueSave(player)
		return
	end

	if RodPurchase.Locks[player] then
		notify(player, "Rod purchase already processing.")
		return
	end

	local valid, reason = RodPurchase.validate(data, rodId)
	if not valid then
		notify(player, reason)
		return
	end

	RodPurchase.Locks[player] = true
	local coinsBefore = data.Coins
	local resourcesBefore = ResourceConfig.NormalizeInventory(data.ResourceInventory)
	local equippedBefore = data.EquippedRod
	local purchased = false
	local canceledReason = nil
	local success, purchaseError = xpcall(function()
		local budgetValid, budgetReason = RodPurchase.revalidateBudget(data, rod)
		if not budgetValid then
			canceledReason = budgetReason
			return
		end
		if RodVisual.ownsRod(data, rodId) then
			canceledReason = "Already owned."
			return
		end
		RodPurchase.deductAndGrant(data, rodId, rod)
		purchased = true
	end, debug.traceback)
	RodPurchase.Locks[player] = nil

	if not success then
		data.Coins = coinsBefore
		data.ResourceInventory = resourcesBefore
		data.OwnedRods[rodId] = nil
		data.EquippedRod = equippedBefore
		warn("Rod purchase failed for", player.Name, rodId, purchaseError)
		notify(player, "Rod purchase failed. Nothing was deducted.")
		return
	end
	if not purchased then
		notify(player, canceledReason or "Rod purchase canceled.")
		return
	end

	updateLeaderstats(player)
	refreshFishingRodForPlayer(player, data)
	sendState(player)
	playerData.queueSave(player)
	notify(player, "Bought " .. rod.displayName .. ".")
end)

Remote.BaitAction.OnServerEvent:Connect(function(player, action, baitId)
	local data = playerData[player]
	if not data then
		return
	end

	local requestedBaitId = baitId
	baitId = Bait.normalizeId(baitId)
	local bait = GameConfig.Baits[baitId]
	if not bait then
		print("[BaitPurchase] invalid bait", player.Name, tostring(requestedBaitId), "normalized", tostring(baitId))
		return
	end

	Bait.ensureState(data)
	print("[BaitPurchase] request", player.Name, "action", tostring(action), "baitId", tostring(requestedBaitId), "normalized", baitId)

	if action == "Equip" then
		if baitId ~= Bait.BasicId and Bait.getCount(data, baitId) <= 0 then
			notify(player, "You do not have any " .. bait.displayName .. ".")
			sendState(player)
			return
		end

		data.EquippedBait = baitId
		sendState(player)
		playerData.queueSave(player)
		return
	end

	if action ~= "Buy" then
		return
	end

	if bait.unlimited or baitId == Bait.BasicId then
		data.EquippedBait = Bait.BasicId
		sendState(player)
		playerData.queueSave(player)
		notify(player, "Basic Bait is always free.")
		return
	end

	if data.Level < (bait.unlockLevel or 1) then
		notify(player, "Need level " .. tostring(bait.unlockLevel or 1) .. ".")
		return
	end

	if bait.requiredBiome and not IslandConfig.isBiomeUnlocked(data, bait.requiredBiome) then
		local biome = GameConfig.Biomes[bait.requiredBiome]
		notify(player, "Unlock " .. (biome and biome.displayName or "that island") .. " first.")
		return
	end

	local cost = tonumber(bait.cost) or 0
	if data.Coins < cost then
		notify(player, "Need " .. tostring(cost) .. " coins.")
		return
	end

	local amount = math.max(1, math.floor(tonumber(bait.purchaseAmount) or 1))
	local coinsBefore = data.Coins
	local countBefore = Bait.getCount(data, baitId)
	local countAfter = countBefore + amount
	print("[BaitPurchase] before", player.Name, baitId, "price", cost, "coins", coinsBefore, "count", countBefore)

	data.Coins -= cost
	data.BaitInventory[baitId] = countAfter
	Bait.ensureState(data)
	local verifiedCount = Bait.getCount(data, baitId)
	print("[BaitPurchase] after", player.Name, baitId, "coins", data.Coins, "count", verifiedCount)

	updateLeaderstats(player)
	sendState(player)
	playerData.queueSave(player)
	print("[BaitPurchase] sent inventory", player.Name, baitId, verifiedCount)
	notify(player, "Bought " .. tostring(amount) .. " " .. bait.displayName .. ".")
end)

Remote.QuestAction.OnServerEvent:Connect(function(player, action, periodName, questId)
	local data = playerData[player]
	if not data then
		return
	end

	if action ~= "Claim" then
		return
	end

	if periodName ~= "Daily" and periodName ~= "Weekly" and periodName ~= "Monthly" then
		return
	end

	if type(questId) ~= "string" then
		return
	end

	local success, message = Quest.claim(data, periodName, questId)
	if success then
		updateLeaderstats(player)
		sendState(player)
		saveData(player)
	end

	notify(player, message)
end)

Remote.getOrCreateEvent("ShopAction").OnServerEvent:Connect(function(player, action, category, itemKey, payload)
	local data = playerData[player]
	if not data then
		return
	end

	Monetization.ensureState(data)

	if action == "PromptGamePass" then
		local pass = Monetization.Config.GamePasses[itemKey]
		if not pass then
			return
		end
		if Monetization.ownsPass(data, itemKey) then
			notify(player, "You already own " .. pass.name .. ".")
			sendState(player)
			return
		end
		if pass.purchasable == false then
			notify(player, pass.name .. " is coming soon.")
			sendState(player)
			return
		end
		local success, err = pcall(function()
			print("Prompting purchase:", pass.name or itemKey, pass.id)
			if itemKey == "VipAngler" then
				print("Prompting VIP Angler Pass purchase:", pass.id)
			elseif itemKey == "SmallBag" then
				print("Prompting Small Bag Upgrade purchase:", pass.id)
			elseif itemKey == "MediumBag" then
				print("Prompting Medium Bag Upgrade purchase:", pass.id)
			elseif itemKey == "LargeBag" then
				print("Prompting Large Bag Upgrade purchase:", pass.id)
			end
			Monetization.MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)
		if not success then
			warn("Game pass prompt failed", player.Name, itemKey, err)
			notify(player, "Purchase prompt failed. Check the placeholder ID before publishing.")
		end
	elseif action == "PromptProduct" then
		local product = Monetization.Config.DeveloperProducts[itemKey]
		if not product then
			return
		end
		if product.shopVisible == false then
			notify(player, (product.name or "That product") .. " is not currently sold in the shop.")
			return
		end
		local productId = tonumber(product.id) or tonumber(product.Id)
		if product.purchasable == false or not productId or productId <= 0 then
			notify(player, (product.name or "That product") .. " is coming soon.")
			sendState(player)
			return
		end
		local success, err = pcall(function()
			print("Prompting purchase:", product.name or itemKey, productId)
			Monetization.MarketplaceService:PromptProductPurchase(player, productId)
		end)
		if not success then
			warn("Product prompt failed", player.Name, itemKey, err)
			notify(player, "Purchase prompt failed. Check the placeholder product ID before publishing.")
		end
	elseif action == "ClaimVipReward" then
		if Monetization.applyVipDailyReward(data) then
			sendState(player)
			saveData(player)
			notify(player, "Claimed VIP daily reward: 5 Fresh Bait and 2 Lucky Bait.")
		else
			notify(player, Monetization.ownsPass(data, "VipAngler") and "VIP reward already claimed today." or "VIP Angler Pass required.")
		end
	elseif action == "PurchaseAquariumTheme" then
		local theme = type(itemKey) == "string" and Monetization.Config.AquariumDesigner.themes[itemKey] or nil
		if not theme then
			notify(player, "Aquarium theme not found.")
			return
		end
		if theme.free == true or theme.purchasable ~= true then
			notify(player, theme.free == true and "That aquarium theme is already free." or "That aquarium theme is not purchasable.")
			return
		end
		if SeaStars.ownsTheme(data, itemKey) then
			notify(player, "You already own " .. theme.name .. ".")
			sendState(player)
			return
		end
		local price = SeaStars.normalizeBalance(theme.seaStarPrice)
		if data.SeaStars < price then
			notify(player, "Need " .. tostring(price) .. " Sea Stars to unlock " .. theme.name .. ".")
			return
		end
		if not SeaStars.tryAcquire(player) then
			notify(player, "A Sea Star transaction is already in progress.")
			return
		end

		local balanceBefore = data.SeaStars
		local unlocksBefore = SeaStars.normalizeUnlocks(data.SeaStarUnlocks)
		local purchaseOk, purchaseError = pcall(function()
			SeaStars.ensureState(data)
			assert(not SeaStars.ownsTheme(data, itemKey), "Theme is already owned")
			assert(data.SeaStars >= price, "Sea Star balance changed")
			data.SeaStars = SeaStars.normalizeBalance(data.SeaStars - price)
			data.SeaStarUnlocks[itemKey] = true
		end)
		SeaStars.release(player)
		if not purchaseOk then
			data.SeaStars = balanceBefore
			data.SeaStarUnlocks = unlocksBefore
			notify(player, "Theme purchase failed: " .. tostring(purchaseError))
			return
		end
		if not saveData(player) then
			data.SeaStars = balanceBefore
			data.SeaStarUnlocks = unlocksBefore
			sendState(player)
			notify(player, "Theme purchase could not be saved. No Sea Stars were spent.")
			return
		end
		sendState(player)
		notify(player, "Unlocked " .. theme.name .. " for " .. tostring(price) .. " Sea Stars.")
	elseif action == "PreviewAquariumDesign" then
		if rejectAquariumEditIfViewOnly(player) then
			return
		end

		if category ~= "Aquarium" then
			warn("Aquarium preview failed for", player.Name, "invalid category", tostring(category))
			return
		end

		if Monetization.getAquariumFreeDecorationValidationError(payload) then
			warn("Aquarium preview failed for", player.Name, "invalid decoration data:", Monetization.getAquariumFreeDecorationValidationError(payload))
			notify(player, "Preview failed: invalid decoration data.")
			return
		end
		local ownershipError = SeaStars.getDecorationOwnershipError(data, payload)
		if ownershipError then
			notify(player, "Preview failed: " .. ownershipError)
			return
		end

		data.AquariumPreviewDesign = Monetization.limitAquariumDesignForLevel(payload, data.Aquarium and data.Aquarium.Level or 1)
		local refreshed = refreshPlayerAquarium(player)
		if not refreshed then
			warn("Aquarium preview failed for", player.Name, "no aquarium found or rebuilt")
			notify(player, "Preview failed: no aquarium found.")
			sendState(player)
			return
		end

		sendStateToAll()
		notify(player, "Previewing aquarium design.")
	elseif action == "CancelAquariumPreview" then
		if rejectAquariumEditIfViewOnly(player) then
			return
		end

		data.AquariumPreviewDesign = nil
		refreshPlayerAquarium(player)
		sendStateToAll()
		notify(player, "Aquarium preview canceled.")
	elseif action == "ApplyAquariumDesign" then
		if rejectAquariumEditIfViewOnly(player) then
			return
		end

		if Monetization.getAquariumFreeDecorationValidationError(payload) then
			warn("Aquarium apply failed for", player.Name, "invalid decoration data:", Monetization.getAquariumFreeDecorationValidationError(payload))
			notify(player, "Apply failed: invalid decoration data.")
			return
		end

		local design = Monetization.limitAquariumDesignForLevel(payload, data.Aquarium and data.Aquarium.Level or 1)
		local ownershipError = SeaStars.getDecorationOwnershipError(data, design)
		if ownershipError then
			notify(player, "Apply failed: " .. ownershipError)
			return
		end
		if not SeaStars.ownsTheme(data, design.theme) then
			local theme = Monetization.Config.AquariumDesigner.themes[design.theme]
			notify(player, "Unlock " .. (theme and theme.name or tostring(design.theme)) .. " with Sea Stars before applying it.")
			return
		end

		data.AquariumDesign = design
		data.AquariumPreviewDesign = nil
		refreshPlayerAquarium(player)
		sendStateToAll()
		saveData(player)
		notify(player, "Aquarium design applied.")
	end
end)

Remote.LoginRewardAction.OnServerEvent:Connect(function(player, action)
	local data = playerData[player]
	if not data or action ~= "Claim" then
		return
	end
	if LoginRewards.ClaimLocks[player] then
		Remote.LoginRewardAction:FireClient(player, { Success = false, Message = "A login reward claim is already in progress." })
		return
	end
	if not SeaStars.tryAcquire(player) then
		Remote.LoginRewardAction:FireClient(player, { Success = false, Message = "A Sea Star transaction is already in progress." })
		return
	end
	LoginRewards.ClaimLocks[player] = true

	local snapshot = {
		Coins = data.Coins,
		BaitInventory = playerData.shallowCopyMap(data.BaitInventory),
		ResourceInventory = playerData.shallowCopyMap(data.ResourceInventory),
		SeaStars = data.SeaStars,
		AquariumDecorations = playerData.shallowCopyMap(data.AquariumDecorations),
		LoginRewards = playerData.shallowCopyMap(data.LoginRewards),
	}
	local function restoreSnapshot()
		data.Coins = snapshot.Coins
		data.BaitInventory = snapshot.BaitInventory
		data.ResourceInventory = snapshot.ResourceInventory
		data.SeaStars = snapshot.SeaStars
		data.AquariumDecorations = snapshot.AquariumDecorations
		data.LoginRewards = snapshot.LoginRewards
	end

	local callOk, claimed, message, reward = pcall(LoginRewards.claim, data)
	if not callOk then
		local claimError = claimed
		restoreSnapshot()
		claimed = false
		message = "Login reward grant failed. Progress was not advanced."
		warn("Login reward claim failed for", player.Name, claimError)
	elseif claimed and not saveData(player) then
		restoreSnapshot()
		claimed = false
		message = "Login reward could not be saved. Progress was not advanced."
	end

	LoginRewards.ClaimLocks[player] = nil
	SeaStars.release(player)
	if claimed then
		updateLeaderstats(player)
	end
	sendState(player)
	Remote.LoginRewardAction:FireClient(player, {
		Success = claimed == true,
		Message = message,
		Reward = claimed and reward or nil,
	})
end)

Remote.UnlockBiome.OnServerEvent:Connect(function(player, biomeId)
	local data = playerData[player]
	if not data then
		return
	end

	if IslandPurchase.Locks[player] then
		notify(player, "Island unlock already processing.")
		return
	end

	local canUnlock, reason, normalizedBiomeId, biome = IslandPurchase.validate(data, biomeId)
	if not canUnlock then
		notify(player, reason)
		return
	end

	IslandPurchase.Locks[player] = true
	local coinsBefore = data.Coins
	local currentBiomeBefore = data.CurrentBiome
	local unlocked = false
	local canceledReason = nil
	local success, unlockError = xpcall(function()
		local stillValid, stillReason = IslandPurchase.validate(data, normalizedBiomeId)
		if not stillValid then
			canceledReason = stillReason
			return
		end
		data.Coins -= biome.cost
		data.UnlockedBiomes[normalizedBiomeId] = true
		data.CurrentBiome = normalizedBiomeId
		unlocked = true
	end, debug.traceback)
	IslandPurchase.Locks[player] = nil

	if not success then
		data.Coins = coinsBefore
		data.UnlockedBiomes[normalizedBiomeId] = nil
		data.CurrentBiome = currentBiomeBefore
		warn("Island unlock failed for", player.Name, normalizedBiomeId, unlockError)
		notify(player, "Island unlock failed. Nothing was deducted.")
		return
	end
	if not unlocked then
		notify(player, canceledReason or "Island unlock canceled.")
		return
	end

	updateLeaderstats(player)
	sendState(player)
	playerData.queueSave(player)
	notify(player, "Unlocked " .. biome.displayName .. ".")
end)

function RuntimeConfig.runResourcePhaseStudioTests()
	ResourceConfig.Validate(GameConfig)

	local expectedResources = {
		IronScrap = { "Iron Scrap", "Metals", 1, "IronRod" },
		GoldNugget = { "Gold Nugget", "Metals", 2, "GoldenRod" },
		EmeraldShard = { "Emerald Shard", "Gems", 3, "EmeraldRod" },
		OceanShard = { "Ocean Shard", "Gems", 4, "OceanRod" },
	}
	local resourceCount = 0
	for resourceId, expected in pairs(expectedResources) do
		local resource = ResourceConfig.Resources[resourceId]
		assert(resource.id == resourceId and resource.displayName == expected[1], resourceId .. " identity is incorrect")
		assert(resource.category == expected[2] and resource.displayOrder == expected[3], resourceId .. " category/order is incorrect")
		assert(resource.bazaarEligible == true and resource.loginEligible == true and resource.usedFor == expected[4], resourceId .. " future-use fields are incorrect")
		resourceCount += 1
	end
	assert(resourceCount == 4, "Exactly four resources are required")
	assert(ResourceConfig.DropChances.Weak == 0.22 and ResourceConfig.DropChances.Good == 0.22, "Weak/Good resource odds are incorrect")
	assert(ResourceConfig.DropChances.Great == 0.26 and ResourceConfig.DropChances.Perfect == 0.30, "Great/Perfect resource odds are incorrect")
	assert(ResourceConfig.DropChances.AutoFish == 0.11, "AutoFish resource odds are incorrect")
	local lilyDrops = ResourceConfig.IslandDropTables.LilyshoreIsland
	local riverDrops = ResourceConfig.IslandDropTables.RiverbendIsland
	assert(#lilyDrops == 3 and lilyDrops[1].resourceId == "IronScrap" and lilyDrops[1].weight == 60, "Lilyshore Iron weight is incorrect")
	assert(lilyDrops[2].resourceId == "GoldNugget" and lilyDrops[2].weight == 30, "Lilyshore Gold weight is incorrect")
	assert(lilyDrops[3].resourceId == "EmeraldShard" and lilyDrops[3].weight == 10, "Lilyshore Emerald weight is incorrect")
	assert(#riverDrops == 2 and riverDrops[1].resourceId == "EmeraldShard" and riverDrops[1].weight == 70, "Riverbend Emerald weight is incorrect")
	assert(riverDrops[2].resourceId == "OceanShard" and riverDrops[2].weight == 30, "Riverbend Ocean weight is incorrect")
	assert(ResourceConfig.SelectResource("LilyshoreIsland", 0) == "IronScrap", "Lilyshore Iron weight is incorrect")
	assert(ResourceConfig.SelectResource("LilyshoreIsland", 0.60) == "GoldNugget", "Lilyshore Gold weight is incorrect")
	assert(ResourceConfig.SelectResource("LilyshoreIsland", 0.90) == "EmeraldShard", "Lilyshore Emerald weight is incorrect")
	assert(ResourceConfig.SelectResource("LilyshoreIsland", 0.999) ~= "OceanShard", "Lilyshore must not drop Ocean Shard")
	assert(ResourceConfig.SelectResource("RiverbendIsland", 0.69) == "EmeraldShard", "Riverbend Emerald weight is incorrect")
	assert(ResourceConfig.SelectResource("RiverbendIsland", 0.70) == "OceanShard", "Riverbend Ocean weight is incorrect")
	assert(ResourceConfig.SelectResource("CoralCoastIsland", 0) == nil, "Coral Coast must not roll resources")

	local sanitizedInventory = ResourceConfig.NormalizeInventory({
		IronScrap = 4.9,
		GoldNugget = -10,
		EmeraldShard = "7",
		OceanShard = math.huge,
		SeaStar = 999,
	})
	local sanitizedCount = 0
	for resourceId, count in pairs(sanitizedInventory) do
		assert(expectedResources[resourceId] ~= nil, "Unexpected resource survived sanitization")
		assert(count >= 0 and count < math.huge and count == math.floor(count), resourceId .. " must sanitize to a finite nonnegative integer")
		sanitizedCount += 1
	end
	assert(sanitizedCount == 4 and sanitizedInventory.IronScrap == 4 and sanitizedInventory.GoldNugget == 0 and sanitizedInventory.EmeraldShard == 7, "Resource inventory sanitization is incorrect")
	assert(ResourceConfig.NormalizePity(-4) == 0 and ResourceConfig.NormalizePity(3.8) == 3, "Resource pity sanitization is incorrect")

	local pityData = makeDefaultData()
	pityData.CurrentBiome = "LilyshoreIsland"
	local backpackBefore = pityData.BackpackSize
	for expectedPity = 1, 5 do
		assert(FishingResources.rollForCatch(pityData, false, { rating = "Perfect" }, 0.99, 0) == nil, "Eligible miss should not award a resource")
		assert(pityData.ResourcePity == expectedPity, "Eligible miss did not increment pity")
	end
	assert(FishingResources.rollForCatch(pityData, false, { rating = "Weak" }, 0.99, 0) == "IronScrap", "Sixth eligible catch must be guaranteed")
	assert(pityData.ResourcePity == 0 and pityData.ResourceInventory.IronScrap == 1, "Resource award must reset pity and add one stack")
	assert(pityData.BackpackSize == backpackBefore, "Resources must not consume fish backpack capacity")

	local autoData = makeDefaultData()
	autoData.CurrentBiome = "RiverbendIsland"
	assert(FishingResources.rollForCatch(autoData, true, nil, 0.109, 0.71) == "OceanShard", "AutoFish must use the 11% server roll")
	assert(FishingResources.rollForCatch(autoData, true, { rating = "Perfect" }, 0.11, 0) == nil and autoData.ResourcePity == 1, "AutoFish must ignore cast rating and miss at 11% or above")

	local coralData = makeDefaultData()
	coralData.CurrentBiome = "CoralCoastIsland"
	coralData.ResourcePity = 4
	coralData.ResourceInventory.IronScrap = 3
	assert(FishingResources.rollForCatch(coralData, false, { rating = "Perfect" }, 0, 0) == nil, "Coral Coast must not award a resource")
	assert(coralData.ResourcePity == 4 and coralData.ResourceInventory.IronScrap == 3, "Coral Coast must not change pity or inventory")

	local recipes = {
		IronRod = { "WoodenRod", 5, 1500, "IronScrap", 12 },
		GoldenRod = { "IronRod", 12, 5000, "GoldNugget", 18 },
		EmeraldRod = { "GoldenRod", 20, 15000, "EmeraldShard", 24 },
		OceanRod = { "EmeraldRod", 25, 35000, "OceanShard", 20 },
	}
	for rodId, expected in pairs(recipes) do
		local rod = GameConfig.Rods[rodId]
		assert(rod.previousRod == expected[1] and rod.unlockLevel == expected[2] and rod.cost == expected[3], rodId .. " purchase requirements are incorrect")
		assert(rod.resourceCosts[expected[4]] == expected[5], rodId .. " recipe is incorrect")
		local recipeResourceCount = 0
		for resourceId in pairs(rod.resourceCosts) do
			assert(resourceId == expected[4], rodId .. " contains an extra resource requirement")
			recipeResourceCount += 1
		end
		assert(recipeResourceCount == 1, rodId .. " must require exactly one resource type")
		assert(rod.requiredBiome == nil and rod.requiredCatches == nil and rod.catchRequirement == nil, rodId .. " has an unrelated purchase requirement")
	end

	local failedPurchaseData = makeDefaultData()
	failedPurchaseData.Level = 30
	failedPurchaseData.Coins = 99999
	local coinsBeforeFailedPurchase = failedPurchaseData.Coins
	local valid, reason = RodPurchase.validate(failedPurchaseData, "IronRod")
	assert(valid == false and string.find(reason, "Iron Scrap", 1, true), "Missing resource must block the rod purchase")
	assert(failedPurchaseData.Coins == coinsBeforeFailedPurchase and failedPurchaseData.ResourceInventory.IronScrap == 0, "Failed rod validation must not deduct anything")

	local orderData = makeDefaultData()
	orderData.Level = 1
	orderData.Coins = 0
	local orderValid, orderReason = RodPurchase.validate(orderData, "GoldenRod")
	assert(orderValid == false and string.find(orderReason, "Iron Rod", 1, true), "Previous rod must validate before level/resources/coins")

	local successPurchaseData = makeDefaultData()
	successPurchaseData.Level = 5
	successPurchaseData.Coins = 1500
	successPurchaseData.ResourceInventory.IronScrap = 12
	assert(RodPurchase.validate(successPurchaseData, "IronRod") == true, "Exact Iron Rod requirements should pass")
	RodPurchase.deductAndGrant(successPurchaseData, "IronRod", GameConfig.Rods.IronRod)
	assert(successPurchaseData.Coins == 0 and successPurchaseData.ResourceInventory.IronScrap == 0, "Successful rod purchase must deduct exact costs")
	assert(successPurchaseData.OwnedRods.IronRod == true and successPurchaseData.EquippedRod == "IronRod", "Successful rod purchase must own and equip the rod")

	assert(GameConfig.Biomes.LilyshoreIsland.unlockLevel == 1 and GameConfig.Biomes.LilyshoreIsland.cost == 0 and GameConfig.Biomes.LilyshoreIsland.requiredRod == nil, "Lilyshore unlock config is incorrect")
	assert(GameConfig.Biomes.RiverbendIsland.unlockLevel == 10 and GameConfig.Biomes.RiverbendIsland.cost == 4000 and GameConfig.Biomes.RiverbendIsland.requiredRod == "IronRod", "Riverbend unlock config is incorrect")
	assert(GameConfig.Biomes.CoralCoastIsland.unlockLevel == 25 and GameConfig.Biomes.CoralCoastIsland.cost == 25000 and GameConfig.Biomes.CoralCoastIsland.requiredRod == "OceanRod", "Coral Coast unlock config is incorrect")
	for _, islandId in ipairs(GameConfig.IslandOrder) do
		local biome = GameConfig.Biomes[islandId]
		assert(biome.requiredCatches == nil and biome.catchRequirement == nil and biome.catchCountRequirement == nil, islandId .. " has a catch-count requirement")
	end
	assert(makeDefaultData().IslandCatchCounts == nil, "Island catch counts must not be added")

	print("[FishyFish Resource Test] PASS: config, weights, odds, pity, Coral exclusion, persistence sanitizers, recipes, atomic deductions, and island gates")
end

if Services.RunService:IsStudio() then
	RuntimeConfig.runResourcePhaseStudioTests()
end

Remote.TeleportTo.OnServerEvent:Connect(function(player, target)
	local data = playerData[player]
	if not data then
		return
	end

	local aquariumOwnerUserId = nil
	local normalizedTarget = nil
	if type(target) == "table" then
		if target.kind ~= "PlayerAquarium" then
			return
		end

		aquariumOwnerUserId = tonumber(target.userId)
		if not aquariumOwnerUserId
			or aquariumOwnerUserId <= 0
			or math.floor(aquariumOwnerUserId) ~= aquariumOwnerUserId
		then
			return
		end
	else
		normalizedTarget = IslandConfig.normalizeTravelTarget(target)
		if not normalizedTarget then
			return
		end
	end

	if normalizedTarget and GameConfig.Biomes[normalizedTarget] and not IslandConfig.isBiomeUnlocked(data, normalizedTarget) then
		notify(player, "Unlock that island first.")
		return
	end

	local character = player.Character
	if not (character and character:FindFirstChild("HumanoidRootPart")) then
		return
	end

	if not Travel.tryBeginRemoteTravel(player) then
		return
	end

	local success, movedOrError = pcall(function()
		if aquariumOwnerUserId then
			return Travel.teleportPlayerToAquariumUserId(player, aquariumOwnerUserId)
		end

		return Travel.teleportPlayer(player, normalizedTarget)
	end)
	Travel.finishRemoteTravel(player)

	if not success then
		warn("Travel failed for", player.Name, movedOrError)
		return
	end

	if movedOrError ~= true then
		return
	end

	if normalizedTarget and GameConfig.Biomes[normalizedTarget] then
		data.CurrentBiome = normalizedTarget
	end

	sendState(player)
end)

Remote.AquariumAction.OnServerEvent:Connect(function(player, action, fishSerial, fishIndex)
	local data = playerData[player]
	local changed = false
	if not data then
		return
	end

	if action == "ToggleLike" then
		local numericTargetUserId = tonumber(fishSerial)
		if not numericTargetUserId
			or numericTargetUserId ~= numericTargetUserId
			or numericTargetUserId <= 0
			or numericTargetUserId == math.huge
		then
			return
		end
		local targetUserId = math.floor(numericTargetUserId)
		if targetUserId == player.UserId then
			notify(player, "You cannot like your own aquarium.")
			return
		end
		if playerData.AquariumLikeLocks[player] then
			return
		end

		local now = os.clock()
		if now - (playerData.AquariumLikeCooldowns[player] or 0) < 0.35 then
			return
		end
		playerData.AquariumLikeCooldowns[player] = now

		data.AquariumLikedTargets = type(data.AquariumLikedTargets) == "table"
			and data.AquariumLikedTargets
			or {}
		playerData.AquariumLikeLocks[player] = true
		local callSucceeded, toggled, isNowLiked, newCount, toggleWarning = pcall(
			Services.AquariumDirectory.toggleLike,
			player,
			targetUserId,
			data.AquariumLikedTargets
		)
		playerData.AquariumLikeLocks[player] = nil
		if not callSucceeded then
			warn("Aquarium like request failed for", player.UserId, toggled)
			notify(player, "That like could not be saved. Please try again.")
			return
		end
		if not toggled then
			notify(player, toggleWarning or "That aquarium is not available.")
			return
		end

		local targetPlayer = Services.Players:GetPlayerByUserId(targetUserId)
		local targetData = targetPlayer and playerData[targetPlayer]
		if targetData and type(targetData.Aquarium) == "table" then
			targetData.Aquarium.LikeCount = newCount
			playerData.queueSave(targetPlayer)
		end
		playerData.queueSave(player)
		sendStateToAll()

		local targetName = targetPlayer and targetPlayer.DisplayName
		if not targetName then
			local snapshot = Services.AquariumDirectory.getSnapshot(targetUserId)
			targetName = snapshot and (snapshot.DisplayName or snapshot.Name) or "that player"
		end
		notify(
			player,
			isNowLiked
				and ("Liked " .. targetName .. "'s aquarium.")
				or ("Removed your like from " .. targetName .. "'s aquarium.")
		)
		if toggleWarning and Services.RunService:IsStudio() then
			warn("Aquarium like persistence:", toggleWarning)
		end
		return
	end

	if rejectAquariumEditIfViewOnly(player) then
		return
	end

	if action == "DisplayFish" then
		local targetIndex = findInventoryFishIndex(data, fishSerial, fishIndex)
		if not targetIndex then
			notify(player, "That fish is no longer in your Bag.")
			return
		end

		local fish = data.Inventory[targetIndex]
		local capacity = GameConfig.AquariumCapacities[data.Aquarium.Level]
		local usedCapacity = GameConfig.getAquariumUsedSpace(data.Aquarium.Fish)
		local fishSpace = GameConfig.getAquariumFishSpace(fish)
		if usedCapacity + fishSpace > capacity then
			notify(player, "Aquarium needs " .. fishSpace .. " space. Upgrade it or remove fish first.")
			return
		end

		fish = table.remove(data.Inventory, targetIndex)
		table.insert(data.Aquarium.Fish, fish)
		changed = true
		refreshPlayerAquarium(player)
		sendStateToAll()
		notify(player, "Displayed " .. fish.name .. " in your aquarium.")
	elseif action == "RemoveFish" then
		local requestedSerial = tonumber(fishSerial)
		local requestedIndex = tonumber(fishIndex)
		local targetIndex = nil

		if requestedIndex and data.Aquarium.Fish[requestedIndex] then
			local fish = data.Aquarium.Fish[requestedIndex]
			if not requestedSerial or tonumber(fish.serial) == requestedSerial then
				targetIndex = requestedIndex
			end
		end

		if not targetIndex and requestedSerial then
			for index, fish in ipairs(data.Aquarium.Fish) do
				if tonumber(fish.serial) == requestedSerial then
					targetIndex = index
					break
				end
			end
		end

		if not targetIndex then
			notify(player, "That fish is no longer in your aquarium.")
			sendState(player)
			return
		end

		if #data.Inventory >= data.BackpackSize then
			notify(player, "Bag full. Make room first.")
			return
		end

		local fish = table.remove(data.Aquarium.Fish, targetIndex)
		table.insert(data.Inventory, fish)
		changed = true
		refreshPlayerAquarium(player)
		sendStateToAll()
		notify(player, "Moved " .. fish.name .. " back to your Bag.")
	elseif action == "DisplayBest" then
		if not data.BestCatch then
			notify(player, "Catch a fish first.")
			return
		end

		local targetIndex = findInventoryFishIndex(data, data.BestCatch.serial)
		if not targetIndex then
			notify(player, "Your best fish is not in your Bag anymore.")
			return
		end

		local fish = data.Inventory[targetIndex]
		local capacity = GameConfig.AquariumCapacities[data.Aquarium.Level]
		local usedCapacity = GameConfig.getAquariumUsedSpace(data.Aquarium.Fish)
		local fishSpace = GameConfig.getAquariumFishSpace(fish)
		if usedCapacity + fishSpace > capacity then
			notify(player, "Aquarium needs " .. fishSpace .. " space. Upgrade it or remove fish first.")
			return
		end

		fish = table.remove(data.Inventory, targetIndex)
		table.insert(data.Aquarium.Fish, fish)
		changed = true
		refreshPlayerAquarium(player)
		sendStateToAll()
		notify(player, "Displayed " .. fish.name .. " in your aquarium.")
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
		changed = true

		updateLeaderstats(player)
		refreshPlayerAquarium(player)
		sendStateToAll()
		notify(player, "Aquarium upgraded to level " .. nextLevel .. ".")
	end

	if changed then
		playerData.queueSave(player)
	end
end)

Monetization.MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then
		return
	end

	local data = playerData[player]
	local passKey = Monetization.Config.GamePassById[gamePassId]
	if not data or not passKey then
		return
	end

	data.OwnedGamePasses = Monetization.normalizeOwnedPasses(data.OwnedGamePasses)
	data.OwnedGamePasses[passKey] = true
	Monetization.syncGamePassOwnership(player, data)
	updateLeaderstats(player)
	applyCharacterMonetizationVisuals(player)
	refreshPlayerAquarium(player)
	sendStateToAll()
	saveData(player)
	notify(player, "Purchase unlocked: " .. Monetization.Config.GamePasses[passKey].name .. ".")
end)

Monetization.MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Services.Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = playerData[player]
	local productKey = Monetization.Config.DeveloperProductById[receiptInfo.ProductId]
	local product = productKey and Monetization.Config.DeveloperProducts[productKey]
	if not data or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId or "")
	if purchaseId == "" then
		warn("[DeveloperProductReceipt] Missing PurchaseId for product", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Monetization.ensureState(data)
	if data.ProcessedReceipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local amount = math.max(0, math.floor(tonumber(product.amount) or tonumber(product.Amount) or 0))
	print("[DeveloperProductReceipt] Product ID purchased:", receiptInfo.ProductId)
	print("[DeveloperProductReceipt] Player name:", player.Name)

	local coinAmount = math.max(0, math.floor(tonumber(product.coinAmount) or tonumber(product.CoinAmount) or 0))
	if coinAmount > 0 then
		local coinsBefore = data.Coins
		data.Coins += coinAmount
		assert(Monetization.tryMarkReceipt(data, purchaseId), "Receipt was marked concurrently")
		if not saveData(player) then
			data.Coins = coinsBefore
			data.ProcessedReceipts[purchaseId] = nil
			updateLeaderstats(player)
			sendState(player)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		print("[DeveloperProductReceipt] Coins granted:", coinAmount)
		print("[DeveloperProductReceipt] Coin count before purchase:", coinsBefore)
		print("[DeveloperProductReceipt] Coin count after purchase:", data.Coins)
		updateLeaderstats(player)
		sendState(player)
		notify(player, "Added " .. tostring(coinAmount) .. " Coins.")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local seaStarAmount = SeaStars.normalizeBalance(product.seaStarAmount)
	if seaStarAmount > 0 then
		if not SeaStars.tryAcquire(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		Monetization.ensureState(data)
		if data.ProcessedReceipts[purchaseId] then
			SeaStars.release(player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local seaStarsBefore = data.SeaStars
		data.SeaStars = SeaStars.normalizeBalance(data.SeaStars + seaStarAmount)
		assert(Monetization.tryMarkReceipt(data, purchaseId), "Receipt was marked concurrently")
		if not saveData(player) then
			data.SeaStars = seaStarsBefore
			data.ProcessedReceipts[purchaseId] = nil
			SeaStars.release(player)
			sendState(player)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		SeaStars.release(player)
		print("[DeveloperProductReceipt] Sea Stars granted:", seaStarAmount)
		sendState(player)
		notify(player, "Added " .. tostring(seaStarAmount) .. " Sea Stars.")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local baitId = product.baitId or product.BaitId
	if not baitId or amount <= 0 then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local countBefore = Bait.getCount(data, baitId)
	print("[DeveloperProductReceipt] Lucky Bait amount granted:", amount)
	print("[DeveloperProductReceipt] Lucky Bait count before purchase:", countBefore)
	Monetization.addBait(data, baitId, amount)
	assert(Monetization.tryMarkReceipt(data, purchaseId), "Receipt was marked concurrently")
	if not saveData(player) then
		data.BaitInventory[baitId] = countBefore
		data.ProcessedReceipts[purchaseId] = nil
		Bait.ensureState(data)
		sendState(player)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	print("[DeveloperProductReceipt] Lucky Bait count after purchase:", Bait.getCount(data, baitId))
	sendState(player)
	notify(player, "Added " .. tostring(amount) .. " " .. GameConfig.Baits[baitId].displayName .. ".")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

Remote.ToggleAutoFish.OnServerEvent:Connect(function(player)
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

	if not RodVisual.getHeldFishingRodTool(player, data) then
		notify(player, "Hold your fishing rod before turning on AutoFish.")
		return
	end

	if #data.Inventory >= data.BackpackSize then
		notify(player, "Backpack full. Sell fish first.")
		return
	end

	data.AutoFishEnabled = true
	sendState(player)
	notify(player, "AutoFish turned on. It is slower and has lower rare-fish luck.")
	FishingRuntime.startAutoFish(player)
end)

Services.Players.PlayerAdded:Connect(RuntimeConfig.setupPlayer)
for _, player in ipairs(Services.Players:GetPlayers()) do
	task.spawn(RuntimeConfig.setupPlayer, player)
end

Services.Players.PlayerRemoving:Connect(function(player)
	Services.AquariumDirectory.markOffline(player)
	pcall(function()
		require(script.Parent:WaitForChild("AquariumGalleryPrototypeService")).releasePlayer(player)
	end)
	saveData(player)
	local data = playerData[player]
	if data then
		FishCaughtLeaderboard.publish(player, data)
	end
	local slot = playerAquariumSlots[player]
	if slot then
		local folder = getAquariumsFolder()
		local aquarium = folder and folder:FindFirstChild(getAquariumSlotName(slot))
		if aquarium and aquarium:GetAttribute("OccupantUserId") == player.UserId then
			aquarium:Destroy()
		end
	end

	playerData[player] = nil
	playerData.SaveLocks[player] = nil
	playerData.SaveScheduled[player] = nil
	playerData.SaveRevision[player] = nil
	playerData.AquariumLikeCooldowns[player] = nil
	playerData.AquariumLikeLocks[player] = nil
	pendingFishing[player] = nil
	RodPurchase.Locks[player] = nil
	IslandPurchase.Locks[player] = nil
	SeaStars.TransactionLocks[player] = nil
	LoginRewards.ClaimLocks[player] = nil
	CastConfigService.clearPlayer(player)
	biomeWarpTouchCooldowns[player] = nil
	areaPortalTouchCooldowns[player] = nil
	remoteTravelRequests[player] = nil
	if AquariumLayout.FallSafetyCooldowns then
		AquariumLayout.FallSafetyCooldowns[player] = nil
	end
	playerAquariumSlots[player] = nil
end)

game:BindToClose(function()
	local players = Services.Players:GetPlayers()
	local remaining = #players
	for _, player in ipairs(players) do
		task.spawn(function()
			local success, err = pcall(saveData, player)
			if not success then
				warn("Fishy Fish shutdown save crashed for", player.UserId, err)
			end
			remaining -= 1
		end)
	end
	while remaining > 0 do
		task.wait()
	end
end)

watchRodTemplateModels()
cacheRodTemplates()
EditorVisuals.capture()
safeEnsureWorld("startup")
createFishingRodTool()
createHudAccessTools()
FishCaughtLeaderboard.ensureBoard()
FishCaughtLeaderboard.refresh(true)

task.spawn(function()
	while true do
		task.wait(60)
		FishCaughtLeaderboard.refresh(true)
		playerData.refreshFeaturedAquarium(false)
	end
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Services.Players:GetPlayers()) do
			playerData.queueSave(player)
		end
	end
end)
