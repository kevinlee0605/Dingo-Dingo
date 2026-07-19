local ResourceConfig = {}

ResourceConfig.Resources = {
	IronScrap = {
		id = "IronScrap",
		displayName = "Iron Scrap",
		iconId = 128007393002011,
		category = "Metals",
		bazaarEligible = true,
		loginEligible = true,
		displayOrder = 1,
		usedFor = "IronRod",
	},
	GoldNugget = {
		id = "GoldNugget",
		displayName = "Gold Nugget",
		iconId = 116221692129501,
		category = "Metals",
		bazaarEligible = true,
		loginEligible = true,
		displayOrder = 2,
		usedFor = "GoldenRod",
	},
	EmeraldShard = {
		id = "EmeraldShard",
		displayName = "Emerald Shard",
		iconId = 123106154920942,
		category = "Gems",
		bazaarEligible = true,
		loginEligible = true,
		displayOrder = 3,
		usedFor = "EmeraldRod",
	},
	OceanShard = {
		id = "OceanShard",
		displayName = "Ocean Shard",
		iconId = 138640826275063,
		category = "Gems",
		bazaarEligible = true,
		loginEligible = true,
		displayOrder = 4,
		usedFor = "OceanRod",
	},
}

ResourceConfig.ResourceOrder = {
	"IronScrap",
	"GoldNugget",
	"EmeraldShard",
	"OceanShard",
}

ResourceConfig.IslandDropTables = {
	LilyshoreIsland = {
		{ resourceId = "IronScrap", weight = 60 },
		{ resourceId = "GoldNugget", weight = 30 },
		{ resourceId = "EmeraldShard", weight = 10 },
	},
	RiverbendIsland = {
		{ resourceId = "EmeraldShard", weight = 70 },
		{ resourceId = "OceanShard", weight = 30 },
	},
}

ResourceConfig.DropChances = {
	Weak = 0.22,
	Good = 0.22,
	Great = 0.26,
	Perfect = 0.30,
	AutoFish = 0.11,
}

ResourceConfig.PityMissesBeforeGuarantee = 5

ResourceConfig.RodRecipes = {
	IronRod = {
		previousRod = "WoodenRod",
		level = 5,
		coins = 1500,
		resources = { IronScrap = 12 },
	},
	GoldenRod = {
		previousRod = "IronRod",
		level = 12,
		coins = 5000,
		resources = { GoldNugget = 18 },
	},
	EmeraldRod = {
		previousRod = "GoldenRod",
		level = 20,
		coins = 15000,
		resources = { EmeraldShard = 24 },
	},
	OceanRod = {
		previousRod = "EmeraldRod",
		level = 25,
		coins = 35000,
		resources = { OceanShard = 20 },
	},
}

local function sanitizeNonnegativeInteger(value)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		return 0
	end
	return math.max(0, math.floor(number))
end

function ResourceConfig.NormalizeInventory(inventory)
	local normalized = {}
	for _, resourceId in ipairs(ResourceConfig.ResourceOrder) do
		normalized[resourceId] = sanitizeNonnegativeInteger(type(inventory) == "table" and inventory[resourceId])
	end
	return normalized
end

function ResourceConfig.NormalizePity(value)
	return sanitizeNonnegativeInteger(value)
end

function ResourceConfig.GetIslandDropTable(islandId)
	return ResourceConfig.IslandDropTables[islandId]
end

function ResourceConfig.GetDropChance(rating, isAutoFish)
	if isAutoFish then
		return ResourceConfig.DropChances.AutoFish
	end
	return ResourceConfig.DropChances[rating] or ResourceConfig.DropChances.Weak
end

function ResourceConfig.SelectResource(islandId, unitRoll)
	local dropTable = ResourceConfig.GetIslandDropTable(islandId)
	if not dropTable then
		return nil
	end

	local roll = math.clamp(tonumber(unitRoll) or 0, 0, 0.999999999) * 100
	local cumulative = 0
	for _, entry in ipairs(dropTable) do
		cumulative += entry.weight
		if roll < cumulative then
			return entry.resourceId
		end
	end

	return dropTable[#dropTable] and dropTable[#dropTable].resourceId or nil
end

function ResourceConfig.Validate(gameConfig)
	local seenResources = {}
	for order, resourceId in ipairs(ResourceConfig.ResourceOrder) do
		local resource = ResourceConfig.Resources[resourceId]
		assert(resource, "Missing resource " .. resourceId)
		assert(resource.id == resourceId, resourceId .. " must expose its stable id")
		assert(type(resource.displayName) == "string" and resource.displayName ~= "", resourceId .. " needs a display name")
		assert(resource.category == "Metals" or resource.category == "Gems", resourceId .. " has an invalid category")
		assert(resource.bazaarEligible == true and resource.loginEligible == true, resourceId .. " eligibility flags are incorrect")
		assert(resource.displayOrder == order, resourceId .. " has an invalid display order")
		assert(type(resource.usedFor) == "string" and resource.usedFor ~= "", resourceId .. " needs a usedFor rod id")
		assert(resource.iconId == nil or type(resource.iconId) == "string" or type(resource.iconId) == "number", resourceId .. " iconId must be optional")
		assert(resource.npcFloorValue == nil or tonumber(resource.npcFloorValue) ~= nil, resourceId .. " npcFloorValue must be optional")
		seenResources[resourceId] = true
	end

	local resourceCount = 0
	for resourceId in pairs(ResourceConfig.Resources) do
		resourceCount += 1
		assert(seenResources[resourceId] == true, "Unexpected resource " .. tostring(resourceId))
	end
	assert(resourceCount == 4, "ResourceConfig must contain exactly four resources")

	for islandId, dropTable in pairs(ResourceConfig.IslandDropTables) do
		local totalWeight = 0
		for _, entry in ipairs(dropTable) do
			assert(ResourceConfig.Resources[entry.resourceId], islandId .. " references an unknown resource")
			totalWeight += tonumber(entry.weight) or 0
		end
		assert(totalWeight == 100, islandId .. " resource weights must total 100")
	end
	assert(ResourceConfig.IslandDropTables.CoralCoastIsland == nil, "Coral Coast must not have a resource drop table")

	if gameConfig then
		for rodId, recipe in pairs(ResourceConfig.RodRecipes) do
			local rod = gameConfig.Rods and gameConfig.Rods[rodId]
			assert(rod, "Missing configured rod " .. rodId)
			assert(rod.previousRod == recipe.previousRod, rodId .. " previous rod is incorrect")
			assert(rod.unlockLevel == recipe.level, rodId .. " level requirement is incorrect")
			assert(rod.cost == recipe.coins, rodId .. " coin requirement is incorrect")
			for resourceId, amount in pairs(recipe.resources) do
				assert(rod.resourceCosts and rod.resourceCosts[resourceId] == amount, rodId .. " resource requirement is incorrect")
			end
		end
	end

	return true
end

return ResourceConfig
