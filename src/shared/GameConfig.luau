local GameConfig = {}

GameConfig.MAX_LEVEL = 30
GameConfig.BASE_BACKPACK_SIZE = 30

GameConfig.RarityColors = {
	Common = Color3.fromRGB(238, 238, 238),
	Uncommon = Color3.fromRGB(80, 210, 120),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(175, 100, 255),
	Legendary = Color3.fromRGB(255, 156, 56),
	Mythic = Color3.fromRGB(255, 70, 90),
}

GameConfig.RarityXP = {
	Common = 8,
	Uncommon = 16,
	Rare = 32,
	Epic = 70,
	Legendary = 180,
	Mythic = 500,
}

GameConfig.FishingMinigame = {
	Defaults = {
		baseBarSize = 0.24,
		progressGainPerSecond = 0.34,
		progressDrainPerSecond = 0.16,
		gravity = 1.8,
		lift = 2.75,
		damping = 0.90,
		bounceDamping = 0.36,
		maxBarVelocity = 1.65,
		startProgress = 0.34,
		minSuccessDuration = 1.75,
		maxDuration = 35,
	},
	RodBonuses = {
		WoodenRod = {
			barSizeMultiplier = 1,
			progressGainMultiplier = 1,
			progressDrainMultiplier = 1,
		},
		IronRod = {
			barSizeMultiplier = 1.10,
			progressGainMultiplier = 1.05,
			progressDrainMultiplier = 0.94,
		},
		GoldenRod = {
			barSizeMultiplier = 1.20,
			progressGainMultiplier = 1.08,
			progressDrainMultiplier = 0.90,
		},
		EmeraldRod = {
			barSizeMultiplier = 1.35,
			progressGainMultiplier = 1.14,
			progressDrainMultiplier = 0.84,
		},
		OceanRod = {
			barSizeMultiplier = 1.50,
			progressGainMultiplier = 1.20,
			progressDrainMultiplier = 0.78,
		},
	},
	RarityDifficulty = {
		Common = {
			moveSpeed = 0.16,
			acceleration = 4.2,
			turnIntervalMin = 2.2,
			turnIntervalMax = 3.4,
			jitter = 0.01,
			pauseChance = 0.55,
			pauseMin = 0.35,
			pauseMax = 0.9,
			jumpChance = 0,
			targetSlack = 0.035,
		},
		Uncommon = {
			moveSpeed = 0.22,
			acceleration = 5.2,
			turnIntervalMin = 1.5,
			turnIntervalMax = 2.4,
			jitter = 0.025,
			pauseChance = 0.25,
			pauseMin = 0.2,
			pauseMax = 0.55,
			jumpChance = 0.18,
			jumpMin = 0.10,
			jumpMax = 0.18,
			targetSlack = 0.03,
		},
		Rare = {
			moveSpeed = 0.31,
			acceleration = 6.6,
			turnIntervalMin = 0.95,
			turnIntervalMax = 1.55,
			jitter = 0.04,
			pauseChance = 0.16,
			pauseMin = 0.12,
			pauseMax = 0.38,
			jumpChance = 0.28,
			jumpMin = 0.18,
			jumpMax = 0.32,
			targetSlack = 0.026,
		},
		Epic = {
			moveSpeed = 0.43,
			acceleration = 8.5,
			turnIntervalMin = 0.62,
			turnIntervalMax = 1.08,
			jitter = 0.065,
			pauseChance = 0.18,
			pauseMin = 0.08,
			pauseMax = 0.24,
			jumpChance = 0.38,
			jumpMin = 0.28,
			jumpMax = 0.44,
			targetSlack = 0.022,
		},
		Legendary = {
			moveSpeed = 0.54,
			acceleration = 10.5,
			turnIntervalMin = 0.42,
			turnIntervalMax = 0.78,
			jitter = 0.085,
			pauseChance = 0.08,
			pauseMin = 0.05,
			pauseMax = 0.16,
			jumpChance = 0.50,
			jumpMin = 0.35,
			jumpMax = 0.58,
			burstChance = 0.18,
			burstMultiplier = 1.35,
			burstMin = 0.25,
			burstMax = 0.45,
			targetSlack = 0.018,
		},
		Mythic = {
			moveSpeed = 0.62,
			acceleration = 12.5,
			turnIntervalMin = 0.28,
			turnIntervalMax = 0.58,
			jitter = 0.11,
			pauseChance = 0.05,
			pauseMin = 0.04,
			pauseMax = 0.12,
			jumpChance = 0.58,
			jumpMin = 0.42,
			jumpMax = 0.68,
			burstChance = 0.30,
			burstMultiplier = 1.55,
			burstMin = 0.18,
			burstMax = 0.38,
			targetSlack = 0.014,
		},
	},
}

function GameConfig.getFishingMinigameConfig(rarity, rodId)
	local defaults = GameConfig.FishingMinigame.Defaults
	local difficulty = GameConfig.FishingMinigame.RarityDifficulty[rarity] or GameConfig.FishingMinigame.RarityDifficulty.Common
	local rodBonus = GameConfig.FishingMinigame.RodBonuses[rodId] or GameConfig.FishingMinigame.RodBonuses.WoodenRod

	return {
		barSize = math.clamp(defaults.baseBarSize * rodBonus.barSizeMultiplier, 0.16, 0.58),
		progressGainPerSecond = defaults.progressGainPerSecond * rodBonus.progressGainMultiplier,
		progressDrainPerSecond = defaults.progressDrainPerSecond * rodBonus.progressDrainMultiplier,
		gravity = defaults.gravity,
		lift = defaults.lift,
		damping = defaults.damping,
		bounceDamping = defaults.bounceDamping,
		maxBarVelocity = defaults.maxBarVelocity,
		startProgress = defaults.startProgress,
		minSuccessDuration = defaults.minSuccessDuration,
		maxDuration = defaults.maxDuration,
		difficulty = difficulty,
	}
end

GameConfig.Casting = {
	chargeSpeed = 1.05,
	bounceSpeed = 1.15,
	defaultPower = 0.5,
	minDistance = 18,
	maxDistance = 72,
	perfectCenter = 0.72,
	perfectRadius = 0.045,
	perfectRadiusMin = 0.035,
	perfectRadiusMax = 0.058,
	perfectEdgeMargin = 0.08,
	minPerfectCenterShift = 0.08,
	greatExtraRadius = 0.065,
	goodExtraRadius = 0.20,
	castConfigLifetime = 20,
	greatRadius = 0.11,
	goodRadius = 0.24,
	meterSpeeds = {
		{ name = "Slow", min = 0.62, max = 0.78 },
		{ name = "Medium", min = 0.86, max = 1.04 },
		{ name = "Fast", min = 1.10, max = 1.28 },
	},
	RodPerfectZoneBonuses = {
		WoodenRod = 0,
		IronRod = 0.05,
		GoldenRod = 0.10,
		EmeraldRod = 0.15,
		OceanRod = 0.20,
	},
	Ratings = {
		Perfect = {
			displayName = "Perfect!",
			biteSpeedMultiplier = 0.85,
			progressGainMultiplier = 1.10,
			countsAsPerfect = true,
			sparkle = true,
		},
		Great = {
			displayName = "Great!",
			biteSpeedMultiplier = 0.92,
			progressGainMultiplier = 1.05,
		},
		Good = {
			displayName = "Good",
			biteSpeedMultiplier = 1,
			progressGainMultiplier = 1,
		},
		Weak = {
			displayName = "Weak",
			biteSpeedMultiplier = 1.10,
			progressGainMultiplier = 1,
		},
	},
}

GameConfig.FishImageIds = {
	SmallFish = "rbxassetid://92425635797325",
	Carp = "rbxassetid://85530716090863",
	Bluegill = "rbxassetid://139664436647833",
	Bass = "rbxassetid://124462000894673",
	Catfish = "rbxassetid://84885381823789",
	GoldenCarp = "rbxassetid://138971721449676",
	Koi = "rbxassetid://135595232171014",
	PondGuardian = "rbxassetid://86635246735309",
}

GameConfig.FishImageFiles = {
	SmallFish = "assets/fish_icons/SmallFish.png",
	Carp = "assets/fish_icons/Carp.png",
	Bluegill = "assets/fish_icons/Bluegill.png",
	Bass = "assets/fish_icons/Bass.png",
	Catfish = "assets/fish_icons/Catfish.png",
	GoldenCarp = "assets/fish_icons/GoldenCarp.png",
	Koi = "assets/fish_icons/Koi.png",
	PondGuardian = "assets/fish_icons/PondGuardian.png",
}

GameConfig.RodImageIds = {
	WoodenRod = "rbxassetid://105149981299569",
	IronRod = "rbxassetid://101448937429933",
	GoldenRod = "rbxassetid://106139724127905",
	EmeraldRod = "rbxassetid://70525367176824",
	OceanRod = "rbxassetid://113063482139117",
}

GameConfig.RodImageFiles = {
	WoodenRod = "assets/rod_icons_transparent/WoodenRod.png",
	IronRod = "assets/rod_icons_transparent/IronRod.png",
	GoldenRod = "assets/rod_icons_transparent/GoldenRod.png",
	EmeraldRod = "assets/rod_icons_transparent/EmeraldRod.png",
	OceanRod = "assets/rod_icons_transparent/OceanRod.png",
}

GameConfig.AquariumCapacities = {
	[1] = 18,
	[2] = 40,
	[3] = 80,
	[4] = 140,
}

GameConfig.AquariumUpgradeCosts = {
	[2] = 3000,
	[3] = 15000,
	[4] = 60000,
}

GameConfig.FishAquariumSpace = {
	SmallFish = 1,
	Carp = 2,
	Bluegill = 2,
	Bass = 3,
	Catfish = 4,
	GoldenCarp = 5,
	Koi = 5,
	PondGuardian = 10,
}

function GameConfig.getAquariumFishSpace(fishOrId)
	local fishId = fishOrId
	local rarity = nil

	if type(fishOrId) == "table" then
		fishId = fishOrId.id or fishOrId.imageKey
		rarity = fishOrId.rarity
	end

	if fishId and GameConfig.FishAquariumSpace[fishId] then
		return GameConfig.FishAquariumSpace[fishId]
	end

	local raritySpace = {
		Common = 1,
		Uncommon = 3,
		Rare = 5,
		Epic = 5,
		Legendary = 10,
		Mythic = 14,
	}

	return raritySpace[rarity] or 2
end

function GameConfig.getAquariumUsedSpace(fishList)
	local total = 0
	for _, fish in ipairs(fishList or {}) do
		total += GameConfig.getAquariumFishSpace(fish)
	end
	return total
end

GameConfig.Rods = {
	WoodenRod = {
		displayName = "Wooden Rod",
		cost = 0,
		unlockLevel = 1,
		luck = 0,
		speed = 1,
		zoneBonus = 0,
		order = 1,
	},
	IronRod = {
		displayName = "Iron Rod",
		cost = 2500,
		unlockLevel = 5,
		luck = 0.10,
		speed = 0.92,
		zoneBonus = 0.04,
		order = 2,
	},
	GoldenRod = {
		displayName = "Golden Rod",
		cost = 10000,
		unlockLevel = 12,
		luck = 0.20,
		speed = 0.84,
		zoneBonus = 0.07,
		order = 3,
	},
	EmeraldRod = {
		displayName = "Emerald Rod",
		cost = 30000,
		unlockLevel = 20,
		luck = 0.35,
		speed = 0.76,
		zoneBonus = 0.10,
		order = 4,
	},
	OceanRod = {
		displayName = "Ocean Rod",
		cost = 75000,
		unlockLevel = 25,
		requiredBiome = "Ocean",
		luck = 0.50,
		speed = 0.68,
		zoneBonus = 0.14,
		order = 5,
	},
}

GameConfig.BasicBaitId = "BasicBait"

GameConfig.Baits = {
	BasicBait = {
		displayName = "Basic Bait",
		cost = 0,
		purchaseAmount = 0,
		unlockLevel = 1,
		unlimited = true,
		biteSpeedMultiplier = 1,
		rareChanceBonus = 0,
		xpMultiplier = 1,
		valueMultiplier = 1,
		order = 1,
		description = "Default fishing.",
	},
	FreshBait = {
		displayName = "Fresh Bait",
		cost = 80,
		purchaseAmount = 10,
		unlockLevel = 1,
		biteSpeedMultiplier = 0.88,
		rareChanceBonus = 0,
		xpMultiplier = 1,
		valueMultiplier = 1,
		order = 2,
		description = "Slightly faster bites.",
	},
	TastyBait = {
		displayName = "Tasty Bait",
		cost = 140,
		purchaseAmount = 10,
		unlockLevel = 3,
		biteSpeedMultiplier = 1,
		rareChanceBonus = 0,
		xpMultiplier = 1,
		valueMultiplier = 1.15,
		order = 3,
		description = "Fish sell for slightly more.",
	},
	LuckyBait = {
		displayName = "Lucky Bait",
		cost = 220,
		purchaseAmount = 10,
		unlockLevel = 5,
		biteSpeedMultiplier = 1,
		rareChanceBonus = 0.15,
		xpMultiplier = 1,
		valueMultiplier = 1,
		order = 4,
		description = "Slightly better rare fish odds.",
	},
	GlowBait = {
		displayName = "Glow Bait",
		cost = 300,
		purchaseAmount = 10,
		unlockLevel = 8,
		biteSpeedMultiplier = 1,
		rareChanceBonus = 0,
		xpMultiplier = 1.20,
		valueMultiplier = 1,
		order = 5,
		description = "Fish give more Fishing XP.",
	},
	MysticBait = {
		displayName = "Mystic Bait",
		cost = 500,
		purchaseAmount = 10,
		unlockLevel = 12,
		biteSpeedMultiplier = 0.92,
		rareChanceBonus = 0.10,
		xpMultiplier = 1.12,
		valueMultiplier = 1.10,
		order = 6,
		description = "Small boost to bites, luck, XP, and value.",
	},
}

GameConfig.BaitOrder = { "BasicBait", "FreshBait", "TastyBait", "LuckyBait", "GlowBait", "MysticBait" }

function GameConfig.getBait(baitId)
	return GameConfig.Baits[baitId] or GameConfig.Baits[GameConfig.BasicBaitId]
end

GameConfig.Lobby = {
	displayName = "Lobby",
	center = Vector3.new(-170, 8, -452),
	spawnPosition = Vector3.new(-147, 10, -492),
	bounds = {
		minX = -325,
		maxX = -15,
		minZ = -605,
		maxZ = -300,
	},
}

GameConfig.Biomes = {
	BeginnerPond = {
		displayName = "Beginner Pond",
		icon = "Pond",
		unlockLevel = 1,
		cost = 0,
		position = Vector3.new(0, 8, 0),
		color = Color3.fromRGB(74, 163, 104),
		fish = {
			{ id = "SmallFish", name = "Small Fish", rarity = "Common", chance = 35, value = 5, imageKey = "SmallFish" },
			{ id = "Carp", name = "Carp", rarity = "Common", chance = 25, value = 8, imageKey = "Carp" },
			{ id = "Bluegill", name = "Bluegill", rarity = "Common", chance = 18, value = 12, imageKey = "Bluegill" },
			{ id = "Bass", name = "Bass", rarity = "Uncommon", chance = 10, value = 20, imageKey = "Bass" },
			{ id = "Catfish", name = "Catfish", rarity = "Uncommon", chance = 7, value = 35, imageKey = "Catfish" },
			{ id = "GoldenCarp", name = "Golden Carp", rarity = "Rare", chance = 4, value = 80, imageKey = "GoldenCarp" },
			{ id = "Koi", name = "Koi", rarity = "Epic", chance = 0.9, value = 250, imageKey = "Koi" },
			{ id = "PondGuardian", name = "Pond Guardian", rarity = "Legendary", chance = 0.1, value = 2000, imageKey = "PondGuardian" },
		},
	},
	River = {
		displayName = "River",
		icon = "River",
		unlockLevel = 10,
		cost = 5000,
		position = Vector3.new(180, 8, 0),
		color = Color3.fromRGB(70, 135, 190),
		fish = {
			{ id = "Trout", name = "Trout", rarity = "Common", chance = 28, value = 18 },
			{ id = "Perch", name = "Perch", rarity = "Common", chance = 22, value = 22 },
			{ id = "Salmon", name = "Salmon", rarity = "Uncommon", chance = 18, value = 40 },
			{ id = "Pike", name = "Pike", rarity = "Uncommon", chance = 12, value = 70 },
			{ id = "Sturgeon", name = "Sturgeon", rarity = "Rare", chance = 8, value = 180 },
			{ id = "Eel", name = "Eel", rarity = "Rare", chance = 6, value = 250 },
			{ id = "RainbowSalmon", name = "Rainbow Salmon", rarity = "Epic", chance = 5, value = 600 },
			{ id = "RiverDragon", name = "River Dragon", rarity = "Legendary", chance = 1, value = 5000 },
		},
	},
	Ocean = {
		displayName = "Ocean",
		icon = "Ocean",
		unlockLevel = 25,
		cost = 50000,
		position = Vector3.new(360, 8, 0),
		color = Color3.fromRGB(45, 105, 210),
		fish = {
			{ id = "Sardine", name = "Sardine", rarity = "Common", chance = 25, value = 30 },
			{ id = "Mackerel", name = "Mackerel", rarity = "Common", chance = 20, value = 45 },
			{ id = "Tuna", name = "Tuna", rarity = "Uncommon", chance = 18, value = 80 },
			{ id = "Octopus", name = "Octopus", rarity = "Uncommon", chance = 12, value = 150 },
			{ id = "Swordfish", name = "Swordfish", rarity = "Rare", chance = 10, value = 350 },
			{ id = "Stingray", name = "Stingray", rarity = "Rare", chance = 7, value = 500 },
			{ id = "Dolphin", name = "Dolphin", rarity = "Epic", chance = 5, value = 1500 },
			{ id = "Shark", name = "Shark", rarity = "Legendary", chance = 2.5, value = 4000 },
			{ id = "Whale", name = "Whale", rarity = "Mythic", chance = 0.5, value = 20000 },
		},
	},
}

GameConfig.BiomeOrder = { "BeginnerPond", "River", "Ocean" }
GameConfig.RodOrder = { "WoodenRod", "IronRod", "GoldenRod", "EmeraldRod", "OceanRod" }

function GameConfig.getLevelFromXP(xp)
	local level = 1
	local remaining = math.max(0, xp)

	while level < GameConfig.MAX_LEVEL do
		local needed = GameConfig.getXPForNextLevel(level)
		if remaining < needed then
			break
		end

		remaining -= needed
		level += 1
	end

	return level, remaining, GameConfig.getXPForNextLevel(level)
end

function GameConfig.getXPForNextLevel(level)
	if level >= GameConfig.MAX_LEVEL then
		return 0
	end

	return 100 + ((level - 1) * 45)
end

function GameConfig.getFishCount()
	local total = 0

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		total += #GameConfig.Biomes[biomeId].fish
	end

	return total
end

function GameConfig.findFish(fishId)
	for biomeId, biome in pairs(GameConfig.Biomes) do
		for _, fish in ipairs(biome.fish) do
			if fish.id == fishId then
				return fish, biomeId
			end
		end
	end

	return nil, nil
end

function GameConfig.getFishImage(fishId)
	local imageId = GameConfig.FishImageIds[fishId]
	if type(imageId) == "string" and imageId ~= "" then
		return imageId
	end

	return nil
end

function GameConfig.getRodImage(rodId)
	local imageId = GameConfig.RodImageIds[rodId]
	if type(imageId) == "string" and imageId ~= "" then
		return imageId
	end

	return nil
end

function GameConfig.getBiomeUnlockText(biomeId)
	local biome = GameConfig.Biomes[biomeId]
	if not biome then
		return "Unknown"
	end

	if biome.cost == 0 then
		return "Free"
	end

	return string.format("Level %d + %d Coins", biome.unlockLevel, biome.cost)
end

return GameConfig
