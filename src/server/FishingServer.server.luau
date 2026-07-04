local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

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
local function getOrCreateRemoteEvent(name)
	local remote = Remotes:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = Remotes
	return remote
end

local StartFishing = Remotes:WaitForChild("StartFishing")
local FinishMinigame = Remotes:WaitForChild("FinishMinigame")
local SellFish = Remotes:WaitForChild("SellFish")
local BuyRod = Remotes:WaitForChild("BuyRod")
local BaitAction = getOrCreateRemoteEvent("BaitAction")
local UnlockBiome = Remotes:WaitForChild("UnlockBiome")
local TeleportTo = Remotes:WaitForChild("TeleportTo")
local OpenBiomeWarp = getOrCreateRemoteEvent("OpenBiomeWarp")
local OpenSellFish = getOrCreateRemoteEvent("OpenSellFish")
local OpenRodShop = getOrCreateRemoteEvent("OpenRodShop")
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
local getPlayerFishingBiome
local getPlayerTravelLocation
local getAquariumVisitorsState
local playerAquariumSlots = {}
local FishCaughtLeaderboard = require(script.Parent:WaitForChild("FishCaughtLeaderboardService"))
FishCaughtLeaderboard.configure({
	playerData = playerData,
})

local AQUARIUM_AREA_ORIGIN = Vector3.new(6000, 0, 6000)
local AQUARIUM_COLUMNS = 12
local AQUARIUM_SLOT_SPACING_X = 110
local AQUARIUM_SLOT_SPACING_Z = 90
local AQUARIUM_LAND_MARGIN = 180
local AQUARIUM_MIN_SHOWCASE_SLOTS = 1000
local AQUARIUM_LAND_TILE_SIZE = 180

local AUTO_FISH_MIN_WAIT = 11
local AUTO_FISH_MAX_WAIT = 18
local TESTING_START_COINS = 100000
local TESTING_START_LEVEL = GameConfig.MAX_LEVEL
local STUDIO_GIVE_BEGINNER_FISH_IN_BAG = true

-- Optional fallback: paste a single uploaded rod MeshId here if you prefer an asset-id based rod.
local WOODEN_ROD_MESH_ID = ""
local ROD_TEMPLATE_FOLDER_NAME = "FishyFishModelTemplates"
local ROD_TEMPLATE_NAMES_BY_ROD = {
	WoodenRod = { "woodenrodmk411", "WoodenRodMk411", "woodenrodmk4", "WoodenRodMk4", "WoodenRodMk3", "woodenrodmk3", "WoodenRod", "woodenrod", "wooden_rod" },
	IronRod = { "ironrod11", "IronRod11", "IronRod", "ironrod", "Iron Rod", "iron rod", "iron_rod" },
	GoldenRod = { "goldenrod11", "GoldenRod11", "GoldenRod", "goldenrod", "Golden Rod", "golden rod", "golden_rod" },
	EmeraldRod = { "emeraldrod11", "EmeraldRod11", "EmeraldRod", "emeraldrod", "Emerald Rod", "emerald rod", "emerald_rod" },
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
	if not STUDIO_GIVE_BEGINNER_FISH_IN_BAG or not RunService:IsStudio() then
		return false
	end

	local beginnerPond = GameConfig.Biomes.BeginnerPond
	if not beginnerPond then
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
	for _, fish in ipairs(beginnerPond.fish) do
		if not ownedById[fish.id] then
			table.insert(missingFish, fish)
		end
	end

	if #missingFish == 0 then
		return false
	end

	data.BackpackSize = math.max(data.BackpackSize, #data.Inventory + #missingFish)
	for _, fish in ipairs(missingFish) do
		local entry = makeInventoryFishEntry(fish, "BeginnerPond", 100)
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

local function makeClientState(player, data)
	recalcLevel(data)
	Bait.ensureState(data)

	local aquarium = type(data.Aquarium) == "table" and data.Aquarium or {}
	local aquariumLevel = math.clamp(tonumber(aquarium.Level) or 1, 1, 4)
	local aquariumFish = type(aquarium.Fish) == "table" and aquarium.Fish or {}
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
		Inventory = copyArray(data.Inventory),
		BackpackSize = data.BackpackSize,
		InventoryValue = getInventoryValue(data),
		OwnedRods = shallowCopyMap(data.OwnedRods),
		EquippedRod = data.EquippedRod,
		BaitInventory = shallowCopyMap(data.BaitInventory),
		EquippedBait = equippedBait,
		EquippedBaitRemaining = Bait.getRemainingForClient(data, equippedBait),
		UnlockedBiomes = shallowCopyMap(data.UnlockedBiomes),
		CurrentBiome = data.CurrentBiome,
		ActualBiome = getPlayerFishingBiome and getPlayerFishingBiome(player) or nil,
		ActualLocation = getPlayerTravelLocation and getPlayerTravelLocation(player) or nil,
		AutoFishEnabled = data.AutoFishEnabled,
		Fishdex = shallowCopyMap(data.Fishdex),
		FishdexTotal = GameConfig.getFishCount(),
		TotalFishCaught = data.TotalFishCaught or 0,
		Aquarium = {
			Level = aquariumLevel,
			Capacity = GameConfig.AquariumCapacities[aquariumLevel] or GameConfig.AquariumCapacities[1],
			UsedCapacity = GameConfig.getAquariumUsedSpace(aquariumFish),
			Fish = copyArray(aquariumFish),
		},
		AquariumVisitors = aquariumVisitors,
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

	StateUpdated:FireClient(player, clientState)
end

local function sendStateToAll()
	for _, player in ipairs(Players:GetPlayers()) do
		sendState(player)
	end
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
		BaitInventory = Bait.normalizeInventory(nil),
		EquippedBait = Bait.BasicId,
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
		TotalFishCaught = 0,
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
	data.BaitInventory = Bait.normalizeInventory(loaded.BaitInventory)
	data.EquippedBait = Bait.normalizeId(loaded.EquippedBait)

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
	data.TotalFishCaught = math.max(0, math.floor(tonumber(loaded.TotalFishCaught) or 0))

	if not data.OwnedRods.WoodenRod then
		data.OwnedRods.WoodenRod = true
	end

	if not data.UnlockedBiomes.BeginnerPond then
		data.UnlockedBiomes.BeginnerPond = true
	end

	if not ownsRod(data, data.EquippedRod) then
		data.EquippedRod = "WoodenRod"
	end

	Bait.ensureState(data)

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
	Bait.ensureState(data)

	local savePayload = {
		Coins = data.Coins,
		XP = data.XP,
		Inventory = data.Inventory,
		BackpackSize = data.BackpackSize,
		OwnedRods = data.OwnedRods,
		EquippedRod = data.EquippedRod,
		BaitInventory = data.BaitInventory,
		EquippedBait = data.EquippedBait,
		UnlockedBiomes = data.UnlockedBiomes,
		CurrentBiome = data.CurrentBiome,
		AutoFishEnabled = data.AutoFishEnabled,
		Fishdex = data.Fishdex,
		Aquarium = data.Aquarium,
		BestCatch = data.BestCatch,
		TotalFishCaught = data.TotalFishCaught,
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
		OpenSellFish:FireClient(player)
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

	prompt.ActionText = "Browse Rods & Bait"
	prompt.ObjectText = "Rod & Bait Seller"
	prompt.Enabled = true

	if prompt:GetAttribute("FishyFishRodShopConnected") then
		return
	end

	prompt:SetAttribute("FishyFishRodShopConnected", true)
	prompt.Triggered:Connect(function(player)
		OpenRodShop:FireClient(player)
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
	OpenBiomeWarp:FireClient(player, getPlayerFishingBiome and getPlayerFishingBiome(player) or nil)
end

local function connectBiomeWarpFountainTouch(part)
	if not part:IsA("BasePart") then
		return
	end

	local lowerName = string.lower(part.Name)
	local isFountainWater = string.find(lowerName, "fountain")
		and string.find(lowerName, "water")
		and not string.find(lowerName, "plaza")
		and not string.find(lowerName, "path")
		and not string.find(lowerName, "effect")
		and not string.find(lowerName, "trigger")
	if not isFountainWater then
		return
	end

	if part:GetAttribute("FishyFishBiomeWarpConnected") then
		return
	end

	part:SetAttribute("FishyFishBiomeWarpConnected", true)
	part.CanTouch = true
	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		openBiomeWarpForPlayer(player)
	end)
end

local function connectBiomeWarpFountainTouches()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		connectBiomeWarpFountainTouch(descendant)
	end
end

workspace.DescendantAdded:Connect(connectBiomeWarpFountainTouch)

local function ensureFountainBiomeWarpTrigger()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "FountainBiomeWarpTrigger" then
			descendant:Destroy()
		end
	end

	connectBiomeWarpFountainTouches()
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

local AquariumViewerTool = {}

function AquariumViewerTool.make()
	local tool = Instance.new("Tool")
	tool.Name = "Aquarium Viewer"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "View player aquariums."
	return tool
end

function AquariumViewerTool.createStarterTool()
	local existing = StarterPack:FindFirstChild("Aquarium Viewer")
	if existing then
		existing:Destroy()
	end

	AquariumViewerTool.make().Parent = StarterPack
end

function AquariumViewerTool.ensureForPlayer(player)
	for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
		if container and container:FindFirstChild("Aquarium Viewer") then
			return
		end
	end

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		AquariumViewerTool.make().Parent = backpack
	end
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
			local template = StarterPack:FindFirstChild("Fishing Rod")
			if not template then
				createFishingRodTool()
				template = StarterPack:FindFirstChild("Fishing Rod")
			end

			if template and template:IsA("Tool") then
				local tool = template:Clone()
				tool.Parent = backpack
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
	for _, root in ipairs(workspace:GetDescendants()) do
		if (root:IsA("Folder") or root:IsA("Model")) and EditorVisuals.solidDecorFolderNames[root.Name] then
			for _, descendant in ipairs(root:GetDescendants()) do
				if descendant:IsA("BasePart") then
					local helperPart = descendant.Name == "PrimaryPart"
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
		end
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
	local world = workspace:FindFirstChild("FishyFishWorld")
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
	return string.format("AquariumSlot_%03d", slot)
end

local function getAquariumSlotOrigin(slot)
	local slotIndex = slot - 1
	local column = slotIndex % AQUARIUM_COLUMNS
	local row = math.floor(slotIndex / AQUARIUM_COLUMNS)
	return AQUARIUM_AREA_ORIGIN + Vector3.new(column * AQUARIUM_SLOT_SPACING_X, 0, row * AQUARIUM_SLOT_SPACING_Z)
end

local function getPlayerAquariumSlot(player)
	if playerAquariumSlots[player] then
		return playerAquariumSlots[player]
	end

	local folder = getAquariumsFolder()
	for slot = 1, AQUARIUM_MIN_SHOWCASE_SLOTS do
		local aquarium = folder and folder:FindFirstChild(getAquariumSlotName(slot))
		local occupantUserId = aquarium and aquarium:GetAttribute("OccupantUserId")
		if occupantUserId == nil or occupantUserId == player.UserId then
			playerAquariumSlots[player] = slot
			if aquarium then
				aquarium:SetAttribute("OccupantUserId", player.UserId)
				aquarium:SetAttribute("OccupantName", player.DisplayName)
			end
			return slot
		end
	end

	local overflowSlot = AQUARIUM_MIN_SHOWCASE_SLOTS + #Players:GetPlayers()
	playerAquariumSlots[player] = overflowSlot
	return overflowSlot
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

local function getAquariumTeleportPositionForOwner(ownerPlayer)
	local ownerData = playerData[ownerPlayer]
	local level = ownerData and ownerData.Aquarium and ownerData.Aquarium.Level or 1
	local tankDepth = 10 + ((level - 1) * 4)
	return getAquariumSlotOrigin(getPlayerAquariumSlot(ownerPlayer)) + Vector3.new(0, 5, -(tankDepth / 2 + 16))
end

getAquariumVisitorsState = function(requestingPlayer)
	local visitors = {}

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		local otherData = playerData[otherPlayer]
		if otherData and otherData.Aquarium then
			local level = otherData.Aquarium.Level or 1
			local capacity = GameConfig.AquariumCapacities[level] or GameConfig.AquariumCapacities[1]
			local fish = otherData.Aquarium.Fish or {}
			table.insert(visitors, {
				UserId = otherPlayer.UserId,
				Name = otherPlayer.Name,
				DisplayName = otherPlayer.DisplayName,
				IsSelf = otherPlayer == requestingPlayer,
				AquariumLevel = level,
				FishCount = #fish,
				UsedCapacity = GameConfig.getAquariumUsedSpace(fish),
				Capacity = capacity,
				BestCatch = otherData.BestCatch and {
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
	local slotCount = math.max(minimumSlots or 1, #Players:GetPlayers(), AQUARIUM_MIN_SHOWCASE_SLOTS)
	local rows = math.max(1, math.ceil(slotCount / AQUARIUM_COLUMNS))
	local existing = folder:FindFirstChild("SharedAquariumShowcase")

	if existing and existing:GetAttribute("Rows") == rows then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local showcase = Instance.new("Model")
	showcase.Name = "SharedAquariumShowcase"
	showcase:SetAttribute("Rows", rows)
	showcase.Parent = folder

	local landWidth = ((AQUARIUM_COLUMNS - 1) * AQUARIUM_SLOT_SPACING_X) + AQUARIUM_LAND_MARGIN
	local landDepth = ((rows - 1) * AQUARIUM_SLOT_SPACING_Z) + AQUARIUM_LAND_MARGIN
	local center = AQUARIUM_AREA_ORIGIN + Vector3.new(
		((AQUARIUM_COLUMNS - 1) * AQUARIUM_SLOT_SPACING_X) / 2,
		0,
		((rows - 1) * AQUARIUM_SLOT_SPACING_Z) / 2
	)

	local firstLandTile = nil
	local tileColumns = math.ceil(landWidth / AQUARIUM_LAND_TILE_SIZE)
	local tileRows = math.ceil(landDepth / AQUARIUM_LAND_TILE_SIZE)
	local landMinX = center.X - (landWidth / 2)
	local landMinZ = center.Z - (landDepth / 2)

	for tileX = 0, tileColumns - 1 do
		for tileZ = 0, tileRows - 1 do
			local tileWidth = math.min(AQUARIUM_LAND_TILE_SIZE, landWidth - (tileX * AQUARIUM_LAND_TILE_SIZE))
			local tileDepth = math.min(AQUARIUM_LAND_TILE_SIZE, landDepth - (tileZ * AQUARIUM_LAND_TILE_SIZE))
			local tileCenter = Vector3.new(
				landMinX + (tileX * AQUARIUM_LAND_TILE_SIZE) + (tileWidth / 2),
				0,
				landMinZ + (tileZ * AQUARIUM_LAND_TILE_SIZE) + (tileDepth / 2)
			)
			local tile = makePart(showcase, "WhiteQuartzFloorTile", Vector3.new(tileWidth, 1, tileDepth), tileCenter, Color3.fromRGB(236, 240, 238), Enum.Material.Marble)
			firstLandTile = firstLandTile or tile
		end
	end

	local carpetColor = Color3.fromRGB(190, 34, 45)
	for row = 0, rows - 1 do
		local z = AQUARIUM_AREA_ORIGIN.Z + (row * AQUARIUM_SLOT_SPACING_Z) - 30
		makePart(showcase, "RedCarpet_Row_" .. tostring(row + 1), Vector3.new(landWidth - 34, 0.18, 10), Vector3.new(center.X, 0.62, z), carpetColor, Enum.Material.Fabric)
	end

	if rows > 1 then
		for column = 0, AQUARIUM_COLUMNS - 1 do
			local x = AQUARIUM_AREA_ORIGIN.X + (column * AQUARIUM_SLOT_SPACING_X) - 34
			makePart(showcase, "RedCarpet_Column_" .. tostring(column + 1), Vector3.new(10, 0.18, landDepth - 40), Vector3.new(x, 0.63, center.Z), carpetColor, Enum.Material.Fabric)
		end
	end

	local function makeInvisibleWall(name, size, position)
		local wall = makePart(showcase, name, size, position, Color3.fromRGB(255, 255, 255), Enum.Material.ForceField)
		wall.Transparency = 1
		wall.CanCollide = true
		wall.CanTouch = false
		wall.CanQuery = false
		return wall
	end

	local wallHeight = 42
	local wallThickness = 4
	local segmentLength = AQUARIUM_LAND_TILE_SIZE
	local halfWidth = landWidth / 2
	local halfDepth = landDepth / 2

	for index = 0, math.ceil(landWidth / segmentLength) - 1 do
		local segmentWidth = math.min(segmentLength, landWidth - (index * segmentLength))
		local x = center.X - halfWidth + (index * segmentLength) + (segmentWidth / 2)
		makeInvisibleWall("InvisibleWall_North_" .. tostring(index + 1), Vector3.new(segmentWidth, wallHeight, wallThickness), Vector3.new(x, wallHeight / 2, center.Z - halfDepth - (wallThickness / 2)))
		makeInvisibleWall("InvisibleWall_South_" .. tostring(index + 1), Vector3.new(segmentWidth, wallHeight, wallThickness), Vector3.new(x, wallHeight / 2, center.Z + halfDepth + (wallThickness / 2)))
	end

	for index = 0, math.ceil(landDepth / segmentLength) - 1 do
		local segmentDepth = math.min(segmentLength, landDepth - (index * segmentLength))
		local z = center.Z - halfDepth + (index * segmentLength) + (segmentDepth / 2)
		makeInvisibleWall("InvisibleWall_West_" .. tostring(index + 1), Vector3.new(wallThickness, wallHeight, segmentDepth), Vector3.new(center.X - halfWidth - (wallThickness / 2), wallHeight / 2, z))
		makeInvisibleWall("InvisibleWall_East_" .. tostring(index + 1), Vector3.new(wallThickness, wallHeight, segmentDepth), Vector3.new(center.X + halfWidth + (wallThickness / 2), wallHeight / 2, z))
	end

	local sign = makePart(showcase, "ShowcaseSign", Vector3.new(42, 5, 0.6), center + Vector3.new(0, 4.5, -(landDepth / 2) + 8), Color3.fromRGB(34, 40, 46), Enum.Material.SmoothPlastic)
	createLabel(sign, "Aquarium Showcase")
	showcase.PrimaryPart = firstLandTile

	return showcase
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
	local lane = (index - 1) % 24
	local layer = lane % 4

	return {
		center = origin + Vector3.new(0, 3.6 + (layer * math.max(1.1, dimensions.tankHeight * 0.11)), 0),
		xRadius = math.max(5.5, (dimensions.tankWidth / 2) - 4 - (layer * 0.35)),
		zRadius = math.max(2.4, (dimensions.tankDepth / 2) - 2.4 - ((layer % 2) * 0.25)),
		heightDrift = math.max(0.24, dimensions.tankHeight * 0.035),
	}
end

local function animateAquariumFish(part, origin, index, seed, dimensions)
	local random = Random.new(seed)
	local lane = getAquariumFishSwimLane(origin, index, dimensions)
	local phase = random:NextNumber(0, math.pi * 2)
	local direction = random:NextInteger(0, 1) == 0 and -1 or 1
	local angularSpeed = random:NextNumber(0.5, 0.75) * direction
	local swaySpeed = random:NextNumber(0.8, 1.3)
	local heightPhase = random:NextNumber(0, math.pi * 2)
	local sidePhase = random:NextNumber(0, math.pi * 2)
	local sideDrift = random:NextNumber(0.22, 0.46)

	task.spawn(function()
		local startedAt = os.clock()
		local lastPosition = part.Position
		local lookVector = Vector3.new(direction, 0, 0)
		local lastTick = os.clock()

		while part.Parent do
			local now = os.clock()
			local deltaTime = math.clamp(now - lastTick, 0.016, 0.12)
			lastTick = now

			local elapsed = now - startedAt
			local currentPhase = phase + (elapsed * angularSpeed)
			local position = lane.center + Vector3.new(
				math.cos(currentPhase) * lane.xRadius,
				math.sin((elapsed * swaySpeed) + heightPhase) * lane.heightDrift,
				(math.sin(currentPhase) * lane.zRadius) + (math.sin((elapsed * 0.7) + sidePhase) * sideDrift)
			)

			local moveDirection = position - lastPosition
			if moveDirection.Magnitude > 0.01 then
				local turnAlpha = math.clamp(deltaTime * 2.8, 0, 1)
				lookVector = lookVector:Lerp(moveDirection.Unit, turnAlpha)
				if lookVector.Magnitude < 0.01 then
					lookVector = moveDirection.Unit
				else
					lookVector = lookVector.Unit
				end
			end

			part.CFrame = CFrame.lookAt(position, position + lookVector)
			lastPosition = position
			task.wait(0.05)
		end
	end)
end

local function makeAquariumFish(parent, fish, origin, index, ownerUserId, dimensions)
	local rarityScale = {
		Common = 0.85,
		Uncommon = 0.95,
		Rare = 1.08,
		Epic = 1.22,
		Legendary = 1.42,
		Mythic = 1.65,
	}
	local scale = rarityScale[fish.rarity] or 1
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

	local rarityGlow = buildAquariumFishModel(model, root, fish, scale)

	local light = Instance.new("PointLight")
	light.Brightness = 0.18
	light.Range = 4.5
	light.Color = rarityGlow
	light.Parent = root

	model.PrimaryPart = root
	animateAquariumFish(root, origin, index, ownerUserId + (index * 997), dimensions)
	return model
end

local function buildAquariumSlotModel(slot, ownerPlayer, ownerData)
	local folder = getAquariumsFolder()
	if not folder then
		return
	end

	ensureAquariumSharedLand(folder, slot)

	local modelName = getAquariumSlotName(slot)
	local existing = folder:FindFirstChild(modelName)
	if existing then
		existing:Destroy()
	end

	local origin = getAquariumSlotOrigin(slot)
	local aquariumLevel = ownerData and ownerData.Aquarium and ownerData.Aquarium.Level or 1
	local dimensions = getAquariumDimensions(aquariumLevel)
	local model = Instance.new("Model")
	model.Name = modelName
	model:SetAttribute("SlotNumber", slot)
	if ownerPlayer then
		model:SetAttribute("OccupantUserId", ownerPlayer.UserId)
		model:SetAttribute("OccupantName", ownerPlayer.DisplayName)
	end
	model.Parent = folder

	local base = makePart(model, "AquariumBase", Vector3.new(dimensions.baseWidth, 1, dimensions.baseDepth), origin + Vector3.new(0, 0.8, 0), Color3.fromRGB(74, 82, 88), Enum.Material.Metal)
	makePart(model, "AquariumBaseTopPlate", Vector3.new(dimensions.baseWidth - 1.4, 0.18, dimensions.baseDepth - 1.4), origin + Vector3.new(0, 1.39, 0), Color3.fromRGB(132, 142, 150), Enum.Material.Metal)

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
		panel.CanCollide = false
	end

	local waterSurface = makePart(model, "AquariumWaterSurface", Vector3.new(dimensions.tankWidth - 2, 0.18, dimensions.tankDepth - 2), origin + Vector3.new(0, dimensions.waterY, 0), Color3.fromRGB(50, 145, 220), Enum.Material.Glass)
	waterSurface.Transparency = 0.55
	waterSurface.CanCollide = false

	for _, corner in ipairs({
		Vector3.new(-halfWidth, dimensions.glassY, -halfDepth), Vector3.new(halfWidth, dimensions.glassY, -halfDepth),
		Vector3.new(-halfWidth, dimensions.glassY, halfDepth), Vector3.new(halfWidth, dimensions.glassY, halfDepth),
	}) do
		makePart(model, "AquariumFramePost", Vector3.new(0.5, dimensions.tankHeight + 0.5, 0.5), origin + corner, Color3.fromRGB(38, 52, 68), Enum.Material.Metal)
	end

	local function makeFrameRails(prefix, y)
		makePart(model, prefix .. "Front", Vector3.new(dimensions.tankWidth + 1, 0.5, 0.5), origin + Vector3.new(0, y, -halfDepth - 0.25), Color3.fromRGB(38, 52, 68), Enum.Material.Metal)
		makePart(model, prefix .. "Back", Vector3.new(dimensions.tankWidth + 1, 0.5, 0.5), origin + Vector3.new(0, y, halfDepth + 0.25), Color3.fromRGB(38, 52, 68), Enum.Material.Metal)
		makePart(model, prefix .. "Left", Vector3.new(0.5, 0.5, dimensions.tankDepth + 1), origin + Vector3.new(-halfWidth - 0.25, y, 0), Color3.fromRGB(38, 52, 68), Enum.Material.Metal)
		makePart(model, prefix .. "Right", Vector3.new(0.5, 0.5, dimensions.tankDepth + 1), origin + Vector3.new(halfWidth + 0.25, y, 0), Color3.fromRGB(38, 52, 68), Enum.Material.Metal)
	end

	makeFrameRails("AquariumTopFrame", dimensions.topY)
	makeFrameRails("AquariumBottomFrame", 1.05)

	local sign = makePart(model, "AquariumOwnerSign", Vector3.new(math.min(dimensions.tankWidth, 30), 3.5, 0.5), origin + Vector3.new(0, dimensions.topY + 2.6, -halfDepth - 1.2), Color3.fromRGB(34, 40, 46), Enum.Material.SmoothPlastic)
	local signText = ownerPlayer and (ownerPlayer.DisplayName .. "'s Aquarium") or "Available Aquarium"
	createLabel(sign, signText)

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

	ensureAquariumSharedLand(folder, AQUARIUM_MIN_SHOWCASE_SLOTS)
	for slot = 1, AQUARIUM_MIN_SHOWCASE_SLOTS do
		if not folder:FindFirstChild(getAquariumSlotName(slot)) then
			buildAquariumSlotModel(slot, nil, nil)
		end
	end
end

local function refreshPlayerAquarium(player)
	local data = playerData[player]
	if not data then
		return
	end

	ensurePrebuiltAquariumSlots()
	local slot = getPlayerAquariumSlot(player)
	buildAquariumSlotModel(slot, player, data)
end

local function playerOwnsAssignedAquarium(player)
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

		shopTextSign(signFolder, "MainRodShopSign", Vector3.new(0, 23, -4.4 * shopBlock), Vector3.new(24, 4, 0.6), "ROD SHOP", blue, Color3.fromRGB(255, 255, 255), Enum.NormalId.Front)
		shopTextSign(signFolder, "LeftChalkboard", Vector3.new(-7.7 * shopBlock, 8.3, -4.8 * shopBlock), Vector3.new(7.5, 10, 0.5), "CAST IT.\nREEL IT.\nCATCH IT.", chalkboardGreen, chalkWhite, Enum.NormalId.Front)
		shopTextSign(signFolder, "RightBoard", Vector3.new(7.9 * shopBlock, 10, 2.2 * shopBlock), Vector3.new(8, 9, 0.5), "RODS\nBAIT\nTACKLE", chalkboardGreen, chalkWhite, Enum.NormalId.Front)
		shopPart(signFolder, "SmallDisplayFrame", Vector3.new(6, 4, 0.5), Vector3.new(7.5 * shopBlock, 5.2, -2.7 * shopBlock), woodDarkLocal, Enum.Material.Wood)
		makeLureRow(signFolder, Vector3.new(6.7 * shopBlock, 5.3, -2.42 * shopBlock))

		shopLantern(Vector3.new(-5 * shopBlock, 15.5, -3.5 * shopBlock))
		shopLantern(Vector3.new(0, 15.5, -3.5 * shopBlock))
		shopLantern(Vector3.new(5 * shopBlock, 15.5, -3.5 * shopBlock))
		shopLantern(Vector3.new(8.7 * shopBlock, 15.5, 3 * shopBlock))
		shopLantern(Vector3.new(11.2 * shopBlock, 10.5, 6.8 * shopBlock))

		local trigger = shopPart(structureFolder, "ShopTrigger", Vector3.new(60, 10, 18), Vector3.new(0, 7, -4 * shopBlock), Color3.fromRGB(0, 255, 255), Enum.Material.ForceField, 1, false)
		trigger:SetAttribute("ShopType", "RodShop")
		trigger:SetAttribute("InteractText", "Open Rod Shop")

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

			local root = character:FindFirstChild("HumanoidRootPart")
			if targetArea == "BiomeWarp" then
				OpenBiomeWarp:FireClient(player, getPlayerFishingBiome and getPlayerFishingBiome(player) or nil)
				return
			end

			if targetArea == "Home" then
				if root then
					refreshPlayerAquarium(player)
					root.CFrame = CFrame.new(getPlayerAquariumTeleportPosition(player))
				end
				return
			end

			if GameConfig.Biomes[targetArea] and not isBiomeUnlocked(data, targetArea) then
				notify(player, "Unlock that area first.")
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
		CollectionService:AddTag(trigger, "AreaPortal")
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
	fountainWarpTrigger:SetAttribute("PortalName", "Biome Warp")
	fountainWarpTrigger:SetAttribute("RequiredLevel", 1)
	CollectionService:AddTag(fountainWarpTrigger, "AreaPortal")
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
	CollectionService:AddTag(lobbyZone, "LobbyZone")

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

	local leaderboardBoard = makeSign(leaderboardModel, "LeaderboardBoard", Vector3.new(0, 13.5, 27 * block), Vector3.new(56, 25, 0.8), "Leaderboard\n\n1. ---\n2. ---\n3. ---\n4. ---\n5. ---", blueUI, Enum.NormalId.Front)
	makeLobbyPart(leaderboardModel, "LeaderboardLeftPost", Vector3.new(1.4, 22, 1.4), Vector3.new(-7 * block, 12, 27 * block), woodDark, Enum.Material.Wood)
	makeLobbyPart(leaderboardModel, "LeaderboardRightPost", Vector3.new(1.4, 22, 1.4), Vector3.new(7 * block, 12, 27 * block), woodDark, Enum.Material.Wood)
	leaderboardModel.PrimaryPart = leaderboardBoard

	makeSign(aquariumWarpModel, "AquariumWarpSign", Vector3.new(31 * block, 11, 10 * block), Vector3.new(22, 15, 0.7), "Aquarium\nWarp", aquariumColor, Enum.NormalId.Front)
	makeWarpPad("AquariumWarp", Vector3.new(31 * block, 3.2, 10 * block), aquariumColor, "Aquarium", "Home", 1)

	makeShopBuilding("FishShop", -24, -24, "FISH SHOP", blueUI)
	makeShopBuilding("RodShop", 24, -24, "ROD SHOP", goldUI)

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
			Enum.Material.Glass,
			0.35,
			false
		)

		local light = Instance.new("PointLight")
		light.Brightness = 0.18
		light.Range = 9
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

	local reedBaseY = 1.05
	for _, basePos in ipairs({
		Vector3.new(-58, reedBaseY, -36), Vector3.new(-58, reedBaseY, 36),
		Vector3.new(58, reedBaseY, -36), Vector3.new(58, reedBaseY, 36),
		Vector3.new(-36, reedBaseY, -46), Vector3.new(36, reedBaseY, -46),
		Vector3.new(-36, reedBaseY, 46), Vector3.new(36, reedBaseY, 46),
		Vector3.new(0, reedBaseY, -46), Vector3.new(0, reedBaseY, 46),
		Vector3.new(-58, reedBaseY, 0), Vector3.new(58, reedBaseY, 0),
		Vector3.new(-48, reedBaseY, -16), Vector3.new(48, reedBaseY, 16),
		Vector3.new(-16, reedBaseY, 40), Vector3.new(16, reedBaseY, -40),
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

	pond.PrimaryPart = fishZone
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
			prompt.ActionText = "Browse Rods & Bait"
			prompt.ObjectText = "Rod & Bait Seller"
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
	prompt.ActionText = "Browse Rods & Bait"
	prompt.ObjectText = "Rod & Bait Seller"
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
		tankPart(tankFolder, glassPanel.name, glassPanel.size, glassPanel.offset, Color3.fromRGB(75, 165, 220), Enum.Material.Glass, 0.68)
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

local function buildWorld()
	local existing = workspace:FindFirstChild("FishyFishWorld")
	if existing then
		existing:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "FishyFishWorld"
	world.Parent = workspace

	makePart(world, "WorldGroundPondToRiver", Vector3.new(29.5, 2, 95), Vector3.new(112.75, -1, 0), Color3.fromRGB(74, 126, 66), Enum.Material.Grass)
	makePart(world, "WorldGroundRiverToOcean", Vector3.new(75, 2, 95), Vector3.new(270, -1, 0), Color3.fromRGB(74, 126, 66), Enum.Material.Grass)
	makePart(world, "WorldGroundBeginnerNorth", Vector3.new(196, 2, 30), Vector3.new(0, -1, -105), Color3.fromRGB(74, 126, 66), Enum.Material.Grass)
	makePart(world, "WorldGroundBeginnerSouth", Vector3.new(196, 2, 30), Vector3.new(0, -1, 105), Color3.fromRGB(74, 126, 66), Enum.Material.Grass)

	ensureLobbyInvisibleBoundaries()

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

	ensurePrebuiltAquariumSlots()
	ensureFountainPlazaBrickStyle()
	ensureFountainAnimations()
	ensureFountainBiomeWarpTrigger()
	connectBiomeWarpFountainTouches()
	ensureShopWoodPartSpacing()
	ensureSeasideRodShopMirrored()
	ensureSeasideRodShopKeeper()
	ensureSeasideShopFishmonger()
	ensureSeasideShopDisplayAquarium()
	EditorVisuals.ensureSmallDecorCollision()
	connectSellFishPrompts()
	connectRodShopPrompts()
end

local function ensureWorld()
	if not workspace:FindFirstChild("FishyFishWorld") then
		buildWorld()
	else
		ensureFountainPlazaBrickStyle()
		ensureFountainAnimations()
		ensureFountainBiomeWarpTrigger()
		connectBiomeWarpFountainTouches()
		ensureShopWoodPartSpacing()
		ensureSeasideRodShopMirrored()
		ensureSeasideRodShopKeeper()
		ensureSeasideShopFishmonger()
		ensureSeasideShopDisplayAquarium()
		EditorVisuals.ensureSmallDecorCollision()
		connectSellFishPrompts()
		connectRodShopPrompts()
		ensureLobbyInvisibleBoundaries()
	end
end

local function safeEnsureWorld(context)
	local success, err = pcall(ensureWorld)
	if not success then
		warn("World setup failed", context or "", err)
	end

	EditorVisuals.restore()
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

local function chooseFish(data, isAutoFish, baitId)
	local biome = getBiomeData(data)
	local rod = getRodData(data)
	local bait = Bait.getData(baitId)
	local luck = (rod.luck or 0) + (tonumber(bait.rareChanceBonus) or 0)

	if isAutoFish then
		luck = (luck * 0.45) - 0.12
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

local function awardCatch(player, fish, isAutoFish, baitId)
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
	data.XP += xp

	if not data.BestCatch or value > data.BestCatch.value then
		data.BestCatch = entry
	end

	updateLeaderstats(player)
	sendState(player)
	FishCaughtLeaderboard.publish(player, data)

	local prefix = isAutoFish and "Auto caught" or "Caught"
	local baitText = bait and bait.displayName and bait.displayName ~= "Basic Bait" and (" using " .. bait.displayName) or ""
	local message = string.format("%s %s [%s]%s Value: %d +%d XP", prefix, fish.name, fish.rarity, baitText, value, xp)
	notify(player, message)
end

local function makeFishingMinigamePrompt(biomeId, biteDelay, fish, rodId, sessionId, isAutoFish, baitId, remainingBait)
	local bait = Bait.getData(baitId)
	local xp = Bait.calculateCatchXP(fish, baitId, isAutoFish)
	local value = Bait.calculateCatchValue(fish, baitId)

	return {
		biomeId = biomeId,
		biteDelay = biteDelay,
		autoFish = isAutoFish == true,
		sessionId = sessionId,
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
		minigame = GameConfig.getFishingMinigameConfig(fish.rarity, rodId),
	}
end

local function getPlayerRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local LOBBY_DEFINITION_FOLDER_NAME = "LobbyDefinition"
local LOBBY_SPAWN_NAME = "LobbySpawn"
local Travel = {}

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
	local definition = workspace:FindFirstChild(LOBBY_DEFINITION_FOLDER_NAME)
	if definition then
		local spawn = definition:FindFirstChild(LOBBY_SPAWN_NAME, true)
		if spawn and spawn:IsA("SpawnLocation") then
			return spawn
		end
	end

	local spawn = workspace:FindFirstChild(LOBBY_SPAWN_NAME, true)
	if spawn and spawn:IsA("SpawnLocation") then
		return spawn
	end

	return nil
end

function Travel.isBeginnerPondInstance(instance)
	while instance do
		if instance.Name == "BeginnerPond_ExtraLarge" or instance.Name == "Beginner Pond" then
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
	if result and Travel.isBeginnerPondInstance(result.Instance) then
		return "BeginnerPond"
	end

	return nil
end

function Travel.getBiomeAtPosition(position, ignoreInstances)
	local groundBiomeId = Travel.getGroundBiomeAtPosition(position, ignoreInstances)
	if groundBiomeId then
		return groundBiomeId
	end

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		if biomeId == "BeginnerPond" then
			continue
		end

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

	local lobbyDefinition = workspace:FindFirstChild(LOBBY_DEFINITION_FOLDER_NAME)
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
	local root = getPlayerRoot(player)
	if not root then
		return nil
	end

	return Travel.getBiomeAtPosition(root.Position, { player.Character })
end

getPlayerTravelLocation = function(player)
	local root = getPlayerRoot(player)
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

	local aquariumPosition = getPlayerAquariumTeleportPosition(player)
	if (root.Position - aquariumPosition).Magnitude <= 70 then
		return "Home"
	end

	return "Lobby"
end

function startAutoFish(player)
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
			local baitPreview = Bait.getData(Bait.getEquippedId(data))
			local waitTime = Random.new():NextNumber(AUTO_FISH_MIN_WAIT, AUTO_FISH_MAX_WAIT)
				* math.max(0.85, rod.speed)
				* math.max(0.75, tonumber(baitPreview.biteSpeedMultiplier) or 1)
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

				local rodId = data.EquippedRod or "WoodenRod"
				local baitId, bait = Bait.consumeForCast(data)
				local biteDelay = 0.2 * math.max(0.75, tonumber(bait.biteSpeedMultiplier) or 1)
				local fish = chooseFish(data, true, baitId)
				local visualTime = 3
				pendingFishing[player] = {
					autoFish = true,
					biomeId = locationBiomeId,
					fish = fish,
					baitId = baitId,
				}
				sendState(player)

				local prompt = makeFishingMinigamePrompt(locationBiomeId, biteDelay, fish, rodId, nil, true, baitId, Bait.getRemainingForClient(data, baitId))
				prompt.visualTime = visualTime
				FishingPrompt:FireClient(player, prompt)

				task.wait(visualTime + 0.25)

				if not player.Parent or playerData[player] ~= data or not data.AutoFishEnabled then
					pendingFishing[player] = nil
					break
				end

				pendingFishing[player] = nil
				awardCatch(player, fish, true, baitId)
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

function teleportPlayer(player, target)
	local root = getPlayerRoot(player)
	if not root then
		return
	end

	local position

	if target == "Lobby" then
		position = Travel.getLobbyTeleportPosition()
	elseif target == "Home" then
		refreshPlayerAquarium(player)
		position = getPlayerAquariumTeleportPosition(player)
	elseif GameConfig.Biomes[target] then
		position = GameConfig.Biomes[target].position
	end

	if position then
		if target == "Home" then
			root.CFrame = CFrame.lookAt(position, getPlayerAquariumOrigin(player) + Vector3.new(0, 5, 0))
		else
			root.CFrame = CFrame.new(position)
		end
	end
end

function teleportPlayerToAquariumOwner(player, ownerPlayer)
	if not ownerPlayer or not ownerPlayer.Parent then
		notify(player, "That player is no longer online.")
		return
	end

	local ownerData = playerData[ownerPlayer]
	if not ownerData then
		notify(player, "That aquarium is not ready yet.")
		return
	end

	refreshPlayerAquarium(ownerPlayer)

	local root = getPlayerRoot(player)
	if not root then
		return
	end

	local position = getAquariumTeleportPositionForOwner(ownerPlayer)
	local lookAt = getAquariumSlotOrigin(getPlayerAquariumSlot(ownerPlayer)) + Vector3.new(0, 5, 0)
	root.CFrame = CFrame.lookAt(position, lookAt)
	notify(player, "Visiting " .. ownerPlayer.DisplayName .. "'s aquarium.")
end

function teleportPlayerToAquariumUserId(player, ownerUserId)
	ownerUserId = tonumber(ownerUserId)
	if not ownerUserId then
		return
	end

	local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
	if ownerPlayer then
		teleportPlayerToAquariumOwner(player, ownerPlayer)
		return
	end

	notify(player, "That player is not online.")
end

areaPortalTouchCooldowns = {}

function connectAreaPortalTrigger(part)
	if not part:IsA("BasePart") then
		return
	end

	local targetArea = part:GetAttribute("TargetArea")
	if not targetArea and part.Name == "AquariumWarpTrigger" and part:FindFirstAncestor("LobbyAquariumWarp") then
		targetArea = "Home"
		part:SetAttribute("TargetArea", targetArea)
	end

	if not targetArea and not CollectionService:HasTag(part, "AreaPortal") then
		return
	end

	if targetArea == "BiomeWarp" then
		connectBiomeWarpFountainTouch(part)
		return
	end

	if part:GetAttribute("FishyFishAreaPortalConnected") then
		return
	end

	part:SetAttribute("FishyFishAreaPortalConnected", true)
	part.CanTouch = true
	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
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
			target = "Home"
		end

		if not data or not target then
			return
		end

		if target == "BiomeWarp" then
			openBiomeWarpForPlayer(player)
			return
		end

		if GameConfig.Biomes[target] and not isBiomeUnlocked(data, target) then
			notify(player, "Unlock that area first.")
			return
		end

		if target == "Lobby" or target == "Home" or GameConfig.Biomes[target] then
			if GameConfig.Biomes[target] then
				data.CurrentBiome = target
			end
			teleportPlayer(player, target)
			sendState(player)
		end
	end)
end

function connectAreaPortalTriggers()
	for _, descendant in ipairs(workspace:GetDescendants()) do
		connectAreaPortalTrigger(descendant)
	end
end

workspace.DescendantAdded:Connect(function(descendant)
	task.defer(connectAreaPortalTrigger, descendant)
end)

function setupPlayer(player)
	playerData[player] = loadData(player)
	local addedStudioFish = giveStudioBeginnerFishInBag(playerData[player])
	local studioFishNoticeSent = false
	safeEnsureWorld("player setup")
	local lobbySpawn = Travel.findLobbySpawnLocation()
	if lobbySpawn then
		player.RespawnLocation = lobbySpawn
	end
	connectAreaPortalTriggers()
	AquariumViewerTool.ensureForPlayer(player)
	setupLeaderstats(player)
	updateLeaderstats(player)
	FishCaughtLeaderboard.publish(player, playerData[player])

	player.CharacterAdded:Connect(function()
		task.defer(function()
			safeEnsureWorld("character added")
			AquariumViewerTool.ensureForPlayer(player)
			local data = playerData[player]
			if data then
				refreshFishingRodForPlayer(player, data)
			end
		end)
	end)

	task.defer(function()
		local data = playerData[player]
		safeEnsureWorld("deferred player setup")
		if data then
			refreshPlayerAquarium(player)
		end
		teleportPlayer(player, "Lobby")
		sendState(player)
		if addedStudioFish and not studioFishNoticeSent then
			studioFishNoticeSent = true
			notify(player, "Added beginner pond fish to your Bag for testing.")
		end
		if data then
			refreshFishingRodForPlayer(player, data)
		end
		if data and data.AutoFishEnabled then
			startAutoFish(player)
		end
		sendStateToAll()
		FishCaughtLeaderboard.refresh(true)
	end)
end

GetState.OnServerInvoke = function(player)
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
	local rodId = data.EquippedRod or "WoodenRod"
	local baitId, bait = Bait.consumeForCast(data)
	local biteDelay = Random.new():NextNumber(2, 5) * rod.speed * math.max(0.65, tonumber(bait.biteSpeedMultiplier) or 1)
	local fish = chooseFish(data, false, baitId)
	local sessionId = tostring(math.floor(os.clock() * 1000)) .. ":" .. tostring(Random.new():NextInteger(100000, 999999))
	local minigameConfig = GameConfig.getFishingMinigameConfig(fish.rarity, rodId)

	data.CurrentBiome = biomeId
	pendingFishing[player] = {
		biomeId = biomeId,
		requestedAt = os.clock(),
		biteDelay = biteDelay,
		fish = fish,
		baitId = baitId,
		sessionId = sessionId,
		minSuccessDuration = minigameConfig.minSuccessDuration,
		maxDuration = minigameConfig.maxDuration,
	}

	sendState(player)
	FishingPrompt:FireClient(player, makeFishingMinigamePrompt(biomeId, biteDelay, fish, rodId, sessionId, false, baitId, Bait.getRemainingForClient(data, baitId)))
end)

FinishMinigame.OnServerEvent:Connect(function(player, result)
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

	local success = type(result) == "table" and result.success == true
	local sessionId = type(result) == "table" and result.sessionId or nil

	if pending.sessionId and sessionId ~= pending.sessionId then
		notify(player, "The fish escaped.")
		sendState(player)
		return
	end

	if not success then
		notify(player, "The fish escaped.")
		sendState(player)
		return
	end

	local minSuccessDuration = pending.minSuccessDuration or 1.5
	if elapsed < pending.biteDelay + minSuccessDuration - 0.35 then
		notify(player, "The fish escaped.")
		sendState(player)
		return
	end

	if elapsed > pending.biteDelay + (pending.maxDuration or 35) + 5 then
		notify(player, "The fish escaped.")
		sendState(player)
		return
	end

	data.CurrentBiome = pending.biomeId
	awardCatch(player, pending.fish, false, pending.baitId)
end)

SellFish.OnServerEvent:Connect(function(player, action, fishSerialToSell, fishIndexToSell)
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
		local value = tonumber(fish.value) or 0
		data.Coins += value

		updateLeaderstats(player)
		sendState(player)
		notify(player, "Sold " .. fish.name .. " for " .. value .. " coins.")
		return
	end

	sellAllFishForPlayer(player)
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

BaitAction.OnServerEvent:Connect(function(player, action, baitId)
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
		notify(player, "Equipped " .. bait.displayName .. ".")
		return
	end

	if action ~= "Buy" then
		return
	end

	if bait.unlimited or baitId == Bait.BasicId then
		data.EquippedBait = Bait.BasicId
		sendState(player)
		notify(player, "Basic Bait is always free.")
		return
	end

	if data.Level < (bait.unlockLevel or 1) then
		notify(player, "Need level " .. tostring(bait.unlockLevel or 1) .. ".")
		return
	end

	if bait.requiredBiome and not isBiomeUnlocked(data, bait.requiredBiome) then
		local biome = GameConfig.Biomes[bait.requiredBiome]
		notify(player, "Unlock " .. (biome and biome.displayName or "that biome") .. " first.")
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
	print("[BaitPurchase] sent inventory", player.Name, baitId, verifiedCount)
	notify(player, "Bought " .. tostring(amount) .. " " .. bait.displayName .. ".")
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

	if type(target) == "table" and target.kind == "PlayerAquarium" then
		local userId = tonumber(target.userId)
		if not userId then
			return
		end

		teleportPlayerToAquariumUserId(player, userId)
		sendState(player)
		return
	end

	if GameConfig.Biomes[target] and not isBiomeUnlocked(data, target) then
		notify(player, "Unlock that teleport first.")
		return
	end

	if GameConfig.Biomes[target] then
		data.CurrentBiome = target
	end

	teleportPlayer(player, target)
	sendState(player)
end)

AquariumAction.OnServerEvent:Connect(function(player, action, fishSerial, fishIndex)
	local data = playerData[player]
	if not data then
		return
	end

	if not playerOwnsAssignedAquarium(player) then
		refreshPlayerAquarium(player)
		notify(player, "Use your own aquarium.")
		sendState(player)
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

		updateLeaderstats(player)
		refreshPlayerAquarium(player)
		sendStateToAll()
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
	local data = playerData[player]
	if data then
		FishCaughtLeaderboard.publish(player, data)
	end
	local slot = playerAquariumSlots[player]
	if slot then
		buildAquariumSlotModel(slot, nil, nil)
	end

	playerData[player] = nil
	pendingFishing[player] = nil
	playerAquariumSlots[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

watchRodTemplateModels()
cacheRodTemplates()
EditorVisuals.capture()
safeEnsureWorld("startup")
createFishingRodTool()
AquariumViewerTool.createStarterTool()
FishCaughtLeaderboard.ensureBoard()
FishCaughtLeaderboard.refresh(true)

task.spawn(function()
	while true do
		task.wait(60)
		FishCaughtLeaderboard.refresh(true)
	end
end)
