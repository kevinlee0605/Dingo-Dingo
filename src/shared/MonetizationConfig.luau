local MonetizationConfig = {}

MonetizationConfig.GamePasses = {
	VipAngler = {
		id = 1899255488,
		name = "VIP Angler Pass",
		priceRobux = 399,
		purchasable = true,
		description = "Gold VIP tag, 10% fish sell bonus, daily bait reward, and VIP Angler title.",
	},
	AquariumDesigner = {
		id = 1904724486,
		name = "Aquarium Designer Pass",
		priceRobux = 299,
		purchasable = true,
		description = "Premium aquarium themes, decorations, lighting colors, background colors, and display sign text.",
	},
	SmallBag = {
		id = 1904640504,
		Id = 1904640504,
		name = "Small Bag Upgrade",
		priceRobux = 99,
		Price = 99,
		purchasable = true,
		description = "+25 fish inventory slots forever.",
		bonusSlots = 25,
		ExtraSlots = 25,
	},
	MediumBag = {
		id = 1903062870,
		Id = 1903062870,
		name = "Medium Bag Upgrade",
		priceRobux = 199,
		Price = 199,
		purchasable = true,
		description = "+50 fish inventory slots forever.",
		bonusSlots = 50,
		ExtraSlots = 50,
	},
	LargeBag = {
		id = 1905030494,
		Id = 1905030494,
		name = "Large Bag Upgrade",
		priceRobux = 349,
		Price = 349,
		purchasable = true,
		description = "+100 fish inventory slots forever.",
		bonusSlots = 100,
		ExtraSlots = 100,
	},
}

MonetizationConfig.GamePassOrder = {
	"VipAngler",
	"AquariumDesigner",
	"SmallBag",
	"MediumBag",
	"LargeBag",
}

MonetizationConfig.DeveloperProducts = {
	StarterCoinPack = {
		id = 3609444402,
		Id = 3609444402,
		name = "Starter Coin Pack",
		priceRobux = 29,
		Price = 29,
		purchasable = true,
		description = "Adds 2,500 Coins.",
		coinAmount = 2500,
		CoinAmount = 2500,
	},
	SmallCoinPack = {
		id = 3609446421,
		Id = 3609446421,
		name = "Small Coin Pack",
		priceRobux = 79,
		Price = 79,
		purchasable = true,
		description = "Adds 7,500 Coins.",
		coinAmount = 7500,
		CoinAmount = 7500,
	},
	MediumCoinPack = {
		id = 3609447480,
		Id = 3609447480,
		name = "Medium Coin Pack",
		priceRobux = 179,
		Price = 179,
		purchasable = true,
		description = "Adds 20,000 Coins.",
		coinAmount = 20000,
		CoinAmount = 20000,
	},
	LargeCoinPack = {
		id = 3609447619,
		Id = 3609447619,
		name = "Large Coin Pack",
		priceRobux = 349,
		Price = 349,
		purchasable = true,
		description = "Adds 50,000 Coins.",
		coinAmount = 50000,
		CoinAmount = 50000,
	},
	HugeCoinPack = {
		id = 3609449084,
		Id = 3609449084,
		name = "Huge Coin Pack",
		priceRobux = 699,
		Price = 699,
		purchasable = true,
		description = "Adds 120,000 Coins.",
		coinAmount = 120000,
		CoinAmount = 120000,
	},
	SmallLuckyBaitPack = {
		id = 3608759454,
		Id = 3608759454,
		name = "Small Lucky Bait Pack",
		priceRobux = 79,
		Price = 79,
		purchasable = true,
		description = "Adds 25 Lucky Bait.",
		baitId = "LuckyBait",
		BaitId = "LuckyBait",
		amount = 25,
		Amount = 25,
	},
	MediumLuckyBaitPack = {
		id = 3608759498,
		Id = 3608759498,
		name = "Medium Lucky Bait Pack",
		priceRobux = 199,
		Price = 199,
		purchasable = true,
		description = "Adds 75 Lucky Bait.",
		baitId = "LuckyBait",
		BaitId = "LuckyBait",
		amount = 75,
		Amount = 75,
	},
	LargeLuckyBaitPack = {
		id = 3608759535,
		Id = 3608759535,
		name = "Large Lucky Bait Pack",
		priceRobux = 399,
		Price = 399,
		purchasable = true,
		description = "Adds 200 Lucky Bait.",
		baitId = "LuckyBait",
		BaitId = "LuckyBait",
		amount = 200,
		Amount = 200,
	},
}

MonetizationConfig.DeveloperProductOrder = {
	"SmallLuckyBaitPack",
	"MediumLuckyBaitPack",
	"LargeLuckyBaitPack",
}

MonetizationConfig.CoinProductOrder = {
	"StarterCoinPack",
	"SmallCoinPack",
	"MediumCoinPack",
	"LargeCoinPack",
	"HugeCoinPack",
}

MonetizationConfig.Vip = {
	title = "VIP Angler",
	sellBonusMultiplier = 1.10,
	dailyReward = {
		bait = {
			FreshBait = 5,
			LuckyBait = 2,
		},
	},
}

MonetizationConfig.AquariumDesigner = {
	defaultDesign = {
		theme = "Classic",
		backdropEnabled = true,
		backgroundColor = "Aqua",
		lightingColor = "SoftWhite",
		signText = "",
		decorations = {},
		freeDecorations = {},
	},
	themes = {
		Classic = {
			name = "Classic",
			premium = false,
			waterColor = Color3.fromRGB(50, 145, 220),
			backgroundColor = Color3.fromRGB(95, 180, 210),
			frameColor = Color3.fromRGB(38, 52, 68),
		},
		CoralReef = {
			name = "Coral Reef",
			premium = true,
			waterColor = Color3.fromRGB(42, 185, 220),
			backgroundColor = Color3.fromRGB(255, 148, 116),
			frameColor = Color3.fromRGB(30, 83, 102),
		},
		DeepOcean = {
			name = "Deep Ocean",
			premium = true,
			waterColor = Color3.fromRGB(25, 82, 156),
			backgroundColor = Color3.fromRGB(18, 38, 82),
			frameColor = Color3.fromRGB(12, 25, 48),
		},
		JapaneseKoiPond = {
			name = "Japanese Koi Pond",
			premium = true,
			waterColor = Color3.fromRGB(84, 166, 190),
			backgroundColor = Color3.fromRGB(180, 70, 68),
			frameColor = Color3.fromRGB(72, 38, 30),
		},
		ModernGlass = {
			name = "Modern Glass",
			premium = true,
			waterColor = Color3.fromRGB(132, 216, 255),
			backgroundColor = Color3.fromRGB(210, 230, 238),
			frameColor = Color3.fromRGB(185, 195, 205),
		},
		PirateShip = {
			name = "Pirate Ship",
			premium = true,
			waterColor = Color3.fromRGB(38, 117, 168),
			backgroundColor = Color3.fromRGB(112, 74, 45),
			frameColor = Color3.fromRGB(56, 34, 25),
		},
		AncientRuins = {
			name = "Ancient Ruins",
			premium = true,
			waterColor = Color3.fromRGB(62, 151, 142),
			backgroundColor = Color3.fromRGB(120, 132, 112),
			frameColor = Color3.fromRGB(74, 82, 74),
		},
	},
	themeOrder = { "Classic", "CoralReef", "DeepOcean", "JapaneseKoiPond", "ModernGlass", "PirateShip", "AncientRuins" },
	backgroundColors = {
		Aqua = { name = "Aqua", premium = false, color = Color3.fromRGB(95, 180, 210) },
		Sunset = { name = "Sunset", premium = true, color = Color3.fromRGB(255, 158, 105) },
		Midnight = { name = "Midnight", premium = true, color = Color3.fromRGB(22, 34, 72) },
		Sandstone = { name = "Sandstone", premium = true, color = Color3.fromRGB(194, 164, 116) },
	},
	backgroundColorOrder = { "Aqua", "Sunset", "Midnight", "Sandstone" },
	lightingColors = {
		SoftWhite = { name = "Soft White", premium = false, color = Color3.fromRGB(255, 248, 216) },
		CoralGlow = { name = "Coral Glow", premium = true, color = Color3.fromRGB(255, 148, 116) },
		DeepBlue = { name = "Deep Blue", premium = true, color = Color3.fromRGB(86, 142, 255) },
		KelpGreen = { name = "Kelp Green", premium = true, color = Color3.fromRGB(104, 222, 151) },
	},
	lightingColorOrder = { "SoftWhite", "CoralGlow", "DeepBlue", "KelpGreen" },
	slots = {
		LeftBottom = { name = "Left Bottom", level = 1, x = -0.34, y = 0.12, z = 0.18, scale = 0.82 },
		MiddleBottom = { name = "Middle Bottom", level = 1, x = 0, y = 0.12, z = 0.24, scale = 0.9 },
		RightBottom = { name = "Right Bottom", level = 1, x = 0.34, y = 0.12, z = 0.18, scale = 0.82 },
		BackWall = { name = "Back Wall", level = 2, x = 0, y = 0.55, z = 0.42, scale = 0.88 },
		FloatingLeft = { name = "Floating Left", level = 2, x = -0.32, y = 0.56, z = 0, scale = 0.78 },
		FloatingRight = { name = "Floating Right", level = 3, x = 0.32, y = 0.56, z = 0, scale = 0.78 },
		BackLeft = { name = "Back Left", level = 3, x = -0.28, y = 0.28, z = 0.38, scale = 0.76 },
		BackRight = { name = "Back Right", level = 3, x = 0.28, y = 0.28, z = 0.38, scale = 0.76 },
		UpperBackLeft = { name = "Upper Back Left", level = 4, x = -0.34, y = 0.72, z = 0.34, scale = 0.72 },
		UpperBackRight = { name = "Upper Back Right", level = 4, x = 0.34, y = 0.72, z = 0.34, scale = 0.72 },
		CenterFeature = { name = "Center Feature", level = 4, x = 0, y = 0.24, z = -0.08, scale = 1.08 },
		FrontAccent = { name = "Front Accent", level = 4, x = 0, y = 0.12, z = -0.34, scale = 0.8 },
	},
	slotOrder = { "LeftBottom", "MiddleBottom", "RightBottom", "BackWall", "FloatingLeft", "FloatingRight", "BackLeft", "BackRight", "UpperBackLeft", "UpperBackRight", "CenterFeature", "FrontAccent" },
	freePlacement = {
		maxByLevel = {
			[1] = 3,
			[2] = 5,
			[3] = 8,
			[4] = 12,
		},
		bounds = {
			xMin = -0.42,
			xMax = 0.42,
			yMin = 0.08,
			yMax = 0.82,
			zMin = -0.42,
			zMax = 0.42,
			scaleMin = 0.55,
			scaleMax = 1.35,
		},
	},
	decorations = {
		None = { name = "None", premium = false },
		Coral = { name = "Coral", premium = true, color = Color3.fromRGB(255, 112, 96) },
		Seaweed = { name = "Seaweed", premium = true, color = Color3.fromRGB(55, 166, 89) },
		TreasureChest = { name = "Treasure Chest", premium = true, color = Color3.fromRGB(136, 82, 38) },
		Rocks = { name = "Rocks", premium = true, color = Color3.fromRGB(115, 122, 126) },
		ShipwreckPiece = { name = "Shipwreck Piece", premium = true, color = Color3.fromRGB(98, 67, 42) },
		BubbleMachine = { name = "Bubble Machine", premium = true, color = Color3.fromRGB(135, 210, 255) },
		Clams = { name = "Clams", premium = true, color = Color3.fromRGB(235, 205, 168) },
		Driftwood = { name = "Driftwood", premium = true, color = Color3.fromRGB(116, 78, 47) },
	},
	decorationOrder = { "None", "Coral", "Seaweed", "TreasureChest", "Rocks", "ShipwreckPiece", "BubbleMachine", "Clams", "Driftwood" },
}

local gamePassById = {}
for key, pass in pairs(MonetizationConfig.GamePasses) do
	gamePassById[pass.id] = key
end
MonetizationConfig.GamePassById = gamePassById

local developerProductById = {}
for key, product in pairs(MonetizationConfig.DeveloperProducts) do
	local productId = tonumber(product.id) or tonumber(product.Id)
	if productId and productId > 0 then
		developerProductById[productId] = key
	end
end
MonetizationConfig.DeveloperProductById = developerProductById

return MonetizationConfig
