local EconomyConfig = {}

EconomyConfig.IslandTiers = {
	LilyshoreIsland = 1,
	RiverbendIsland = 2,
	CoralCoastIsland = 3,
}

EconomyConfig.ExpectedWeightedFishValues = {
	LilyshoreIsland = 25.63,
	RiverbendIsland = 97.62,
	CoralCoastIsland = 231.2,
}

function EconomyConfig.EconomyValueForTier(tier)
	local normalizedTier = math.max(1, math.floor(tonumber(tier) or 1))
	return 25 * normalizedTier * normalizedTier
end

function EconomyConfig.GetIslandTier(islandId, islandConfig)
	local configuredTier = type(islandConfig) == "table" and islandConfig.economyTier or nil
	return math.max(1, math.floor(tonumber(configuredTier or EconomyConfig.IslandTiers[islandId]) or 1))
end

function EconomyConfig.GetHighestUnlockedTier(unlockedIslands, gameConfig)
	local highestTier = 1
	for _, islandId in ipairs(gameConfig.IslandOrder or gameConfig.BiomeOrder or {}) do
		if type(unlockedIslands) == "table" and unlockedIslands[islandId] == true then
			highestTier = math.max(highestTier, EconomyConfig.GetIslandTier(islandId, gameConfig.Biomes[islandId]))
		end
	end
	return highestTier
end

function EconomyConfig.CalculateWeightedFishValue(islandConfig)
	local chanceTotal = 0
	local weightedValueTotal = 0
	for _, fish in ipairs(islandConfig.fish or {}) do
		local chance = tonumber(fish.chance) or 0
		chanceTotal += chance
		weightedValueTotal += chance * (tonumber(fish.value) or 0)
	end

	local weightedAverage = chanceTotal > 0 and weightedValueTotal / chanceTotal or 0
	return chanceTotal, weightedAverage
end

function EconomyConfig.ValidateFishEconomy(gameConfig)
	local report = {}
	for _, islandId in ipairs(gameConfig.IslandOrder or gameConfig.BiomeOrder or {}) do
		local islandConfig = gameConfig.Biomes[islandId]
		assert(islandConfig, "Missing island configuration for " .. tostring(islandId))

		local chanceTotal, weightedAverage = EconomyConfig.CalculateWeightedFishValue(islandConfig)
		assert(math.abs(chanceTotal - 100) < 0.001, string.format("%s fish chances total %.4f instead of 100", islandId, chanceTotal))

		local expected = EconomyConfig.ExpectedWeightedFishValues[islandId]
		if expected then
			assert(math.abs(weightedAverage - expected) < 0.01, string.format("%s weighted value is %.4f instead of approximately %.2f", islandId, weightedAverage, expected))
		end

		report[islandId] = {
			tier = EconomyConfig.GetIslandTier(islandId, islandConfig),
			chanceTotal = chanceTotal,
			weightedAverage = weightedAverage,
		}
	end

	return report
end

return EconomyConfig
