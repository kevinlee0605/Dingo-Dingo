local MonetizationConfig = {}

MonetizationConfig.GamePasses = {
	VipAngler = {
		id = 1899255488,
		name = "VIP Angler Pass",
		priceRobux = 399,
		purchasable = true,
		description = "Gold VIP tag, 10% fish sell bonus, daily bait reward, and VIP Angler title.",
	},
	SmallBag = {
		id = 1904640504,
		Id = 1904640504,
		name = "Small Bag Upgrade",
		priceRobux = 99,
		Price = 99,
		purchasable = true,
		description = "60 total fish slots.",
		totalSlots = 60,
		TotalSlots = 60,
	},
	MediumBag = {
		id = 1903062870,
		Id = 1903062870,
		name = "Medium Bag Upgrade",
		priceRobux = 199,
		Price = 199,
		purchasable = true,
		description = "90 total fish slots.",
		totalSlots = 90,
		TotalSlots = 90,
	},
	LargeBag = {
		id = 1905030494,
		Id = 1905030494,
		name = "Large Bag Upgrade",
		priceRobux = 349,
		Price = 349,
		purchasable = true,
		description = "150 total fish slots.",
		totalSlots = 150,
		TotalSlots = 150,
	},
}

MonetizationConfig.GamePassOrder = {
	"VipAngler",
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
		description = "Adds 1,500 Coins.",
		coinAmount = 1500,
		CoinAmount = 1500,
	},
	SmallCoinPack = {
		id = 3609446421,
		Id = 3609446421,
		name = "Small Coin Pack",
		priceRobux = 79,
		Price = 79,
		purchasable = true,
		description = "Adds 5,000 Coins.",
		coinAmount = 5000,
		CoinAmount = 5000,
	},
	MediumCoinPack = {
		id = 3609447480,
		Id = 3609447480,
		name = "Medium Coin Pack",
		priceRobux = 179,
		Price = 179,
		purchasable = true,
		description = "Adds 15,000 Coins.",
		coinAmount = 15000,
		CoinAmount = 15000,
	},
	LargeCoinPack = {
		id = 3609447619,
		Id = 3609447619,
		name = "Large Coin Pack",
		priceRobux = 349,
		Price = 349,
		purchasable = true,
		description = "Adds 35,000 Coins.",
		coinAmount = 35000,
		CoinAmount = 35000,
	},
	HugeCoinPack = {
		id = 3609449084,
		Id = 3609449084,
		name = "Huge Coin Pack",
		priceRobux = 699,
		Price = 699,
		purchasable = true,
		description = "Adds 80,000 Coins.",
		coinAmount = 80000,
		CoinAmount = 80000,
	},
	StarterSeaStars = {
		id = 3610135094,
		Id = 3610135094,
		name = "Starter Sea Stars",
		catalogName = "Starter Sea Stars",
		priceRobux = 49,
		Price = 49,
		purchasable = true,
		description = "Adds 60 Sea Stars.",
		seaStarAmount = 60,
	},
	SmallSeaStars = {
		id = 3610135575,
		Id = 3610135575,
		name = "Small Sea Stars",
		catalogName = "Small Sea Stars",
		priceRobux = 99,
		Price = 99,
		purchasable = true,
		description = "Adds 130 Sea Stars.",
		seaStarAmount = 130,
	},
	MediumSeaStars = {
		id = 3610135828,
		Id = 3610135828,
		name = "Medium Sea Stars",
		catalogName = "Medium Sea Stars",
		priceRobux = 199,
		Price = 199,
		purchasable = true,
		description = "Adds 300 Sea Stars.",
		seaStarAmount = 300,
	},
	LargeSeaStars = {
		id = 3610136115,
		Id = 3610136115,
		name = "Large Sea Stars",
		catalogName = "Large Sea Stars",
		priceRobux = 399,
		Price = 399,
		purchasable = true,
		description = "Adds 700 Sea Stars.",
		seaStarAmount = 700,
	},
	HugeSeaStars = {
		id = 3610136418,
		Id = 3610136418,
		name = "Huge Sea Stars",
		catalogName = "Huge Sea Stars",
		priceRobux = 799,
		Price = 799,
		purchasable = true,
		description = "Adds 1,500 Sea Stars.",
		seaStarAmount = 1500,
	},
	SmallLuckyBaitPack = {
		id = 3608759454,
		Id = 3608759454,
		name = "Small Lucky Bait Pack",
		priceRobux = 79,
		Price = 79,
		purchasable = true,
		shopVisible = false,
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
		shopVisible = false,
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
		shopVisible = false,
		description = "Adds 200 Lucky Bait.",
		baitId = "LuckyBait",
		BaitId = "LuckyBait",
		amount = 200,
		Amount = 200,
	},
}

MonetizationConfig.DeveloperProductOrder = {}

MonetizationConfig.CoinProductOrder = {
	"StarterCoinPack",
	"SmallCoinPack",
	"MediumCoinPack",
	"LargeCoinPack",
	"HugeCoinPack",
}

MonetizationConfig.SeaStarProductOrder = {
	"StarterSeaStars",
	"SmallSeaStars",
	"MediumSeaStars",
	"LargeSeaStars",
	"HugeSeaStars",
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
			id = "Classic",
			name = "Classic",
			displayName = "Classic",
			free = true,
			purchasable = false,
			seaStarPrice = 0,
			displayOrder = 1,
			premium = false,
			waterColor = Color3.fromRGB(50, 145, 220),
			backgroundColor = Color3.fromRGB(95, 180, 210),
			frameColor = Color3.fromRGB(38, 52, 68),
		},
		CoralReef = {
			id = "CoralReef",
			name = "Coral Reef",
			displayName = "Coral Reef",
			free = false,
			purchasable = true,
			seaStarPrice = 60,
			displayOrder = 2,
			premium = true,
			waterColor = Color3.fromRGB(42, 185, 220),
			backgroundColor = Color3.fromRGB(255, 148, 116),
			frameColor = Color3.fromRGB(30, 83, 102),
		},
		DeepOcean = {
			id = "DeepOcean",
			name = "Deep Ocean",
			displayName = "Deep Ocean",
			free = false,
			purchasable = true,
			seaStarPrice = 100,
			displayOrder = 4,
			premium = true,
			waterColor = Color3.fromRGB(25, 82, 156),
			backgroundColor = Color3.fromRGB(18, 38, 82),
			frameColor = Color3.fromRGB(12, 25, 48),
		},
		JapaneseKoiPond = {
			id = "JapaneseKoiPond",
			name = "Japanese Koi Pond",
			displayName = "Japanese Koi Pond",
			free = false,
			purchasable = true,
			seaStarPrice = 140,
			displayOrder = 5,
			premium = true,
			waterColor = Color3.fromRGB(84, 166, 190),
			backgroundColor = Color3.fromRGB(180, 70, 68),
			frameColor = Color3.fromRGB(72, 38, 30),
		},
		ModernGlass = {
			id = "ModernGlass",
			name = "Modern Glass",
			displayName = "Modern Glass",
			free = false,
			purchasable = true,
			seaStarPrice = 60,
			displayOrder = 3,
			premium = true,
			waterColor = Color3.fromRGB(132, 216, 255),
			backgroundColor = Color3.fromRGB(210, 230, 238),
			frameColor = Color3.fromRGB(185, 195, 205),
		},
		PirateShip = {
			id = "PirateShip",
			name = "Pirate Ship",
			displayName = "Pirate Ship",
			free = false,
			purchasable = true,
			seaStarPrice = 180,
			displayOrder = 6,
			premium = true,
			waterColor = Color3.fromRGB(38, 117, 168),
			backgroundColor = Color3.fromRGB(112, 74, 45),
			frameColor = Color3.fromRGB(56, 34, 25),
		},
		AncientRuins = {
			id = "AncientRuins",
			name = "Ancient Ruins",
			displayName = "Ancient Ruins",
			free = false,
			purchasable = true,
			seaStarPrice = 180,
			displayOrder = 7,
			premium = true,
			waterColor = Color3.fromRGB(62, 151, 142),
			backgroundColor = Color3.fromRGB(120, 132, 112),
			frameColor = Color3.fromRGB(74, 82, 74),
		},
	},
	themeOrder = { "Classic", "CoralReef", "ModernGlass", "DeepOcean", "JapaneseKoiPond", "PirateShip", "AncientRuins" },
	backgroundColors = {
		Aqua = { name = "Aqua", premium = false, color = Color3.fromRGB(95, 180, 210) },
		Sunset = { name = "Sunset", premium = false, color = Color3.fromRGB(255, 158, 105) },
		Midnight = { name = "Midnight", premium = false, color = Color3.fromRGB(22, 34, 72) },
		Sandstone = { name = "Sandstone", premium = false, color = Color3.fromRGB(194, 164, 116) },
	},
	backgroundColorOrder = { "Aqua", "Sunset", "Midnight", "Sandstone" },
	lightingColors = {
		SoftWhite = { name = "Soft White", premium = false, color = Color3.fromRGB(255, 248, 216) },
		CoralGlow = { name = "Coral Glow", premium = false, color = Color3.fromRGB(255, 148, 116) },
		DeepBlue = { name = "Deep Blue", premium = false, color = Color3.fromRGB(86, 142, 255) },
		KelpGreen = { name = "Kelp Green", premium = false, color = Color3.fromRGB(104, 222, 151) },
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
		Coral = { name = "Coral", free = true, premium = false, color = Color3.fromRGB(255, 112, 96) },
		Seaweed = { name = "Seaweed", free = true, premium = false, color = Color3.fromRGB(55, 166, 89) },
		TreasureChest = { name = "Treasure Chest", free = true, premium = false, color = Color3.fromRGB(136, 82, 38) },
		Rocks = { name = "Rocks", free = true, premium = false, color = Color3.fromRGB(115, 122, 126) },
		ShipwreckPiece = { name = "Shipwreck Piece", free = true, premium = false, color = Color3.fromRGB(98, 67, 42) },
		BubbleMachine = { name = "Bubble Machine", free = true, premium = false, color = Color3.fromRGB(135, 210, 255) },
		Clams = { name = "Clams", free = true, premium = false, color = Color3.fromRGB(235, 205, 168) },
		Driftwood = { name = "Driftwood", free = true, premium = false, color = Color3.fromRGB(116, 78, 47) },
	},
	decorationOrder = { "None", "Coral", "Seaweed", "TreasureChest", "Rocks", "ShipwreckPiece", "BubbleMachine", "Clams", "Driftwood" },
}

local gamePassById = {}
for key, pass in pairs(MonetizationConfig.GamePasses) do
	gamePassById[pass.id] = key
end
MonetizationConfig.GamePassById = gamePassById

local function rebuildDeveloperProductIndex()
	local developerProductById = {}
	for key, product in pairs(MonetizationConfig.DeveloperProducts) do
		local productId = tonumber(product.id) or tonumber(product.Id)
		if productId and productId > 0 then
			developerProductById[productId] = key
		end
	end
	MonetizationConfig.DeveloperProductById = developerProductById
end

rebuildDeveloperProductIndex()

local function normalizeCatalogName(value)
	return string.lower(tostring(value or "")):gsub("%s+", " "):match("^%s*(.-)%s*$")
end

function MonetizationConfig.ApplyDeveloperProductCatalog(products)
	if type(products) ~= "table" then
		return 0
	end

	local configuredByName = {}
	for productKey, product in pairs(MonetizationConfig.DeveloperProducts) do
		local catalogName = normalizeCatalogName(product.catalogName or product.name)
		if catalogName ~= "" then
			configuredByName[catalogName] = { key = productKey, product = product }
		end
	end

	local resolvedCount = 0
	for _, catalogProduct in ipairs(products) do
		local productId = tonumber(catalogProduct.ProductId)
			or tonumber(catalogProduct.productId)
			or tonumber(catalogProduct.Id)
			or tonumber(catalogProduct.id)
		local catalogName = normalizeCatalogName(catalogProduct.Name or catalogProduct.name)
		local configured = configuredByName[catalogName]
		local catalogPrice = tonumber(catalogProduct.PriceInRobux)
			or tonumber(catalogProduct.priceInRobux)
			or tonumber(catalogProduct.Price)
		if configured and productId and productId > 0 then
			local expectedPrice = tonumber(configured.product.priceRobux or configured.product.Price)
			if not expectedPrice or not catalogPrice or expectedPrice == catalogPrice then
				configured.product.id = productId
				configured.product.Id = productId
				resolvedCount += 1
			end
		end
	end

	rebuildDeveloperProductIndex()
	return resolvedCount
end

function MonetizationConfig.ApplyResolvedProductIds(productIds)
	if type(productIds) ~= "table" then
		return 0
	end

	local applied = 0
	for productKey, productIdValue in pairs(productIds) do
		local product = MonetizationConfig.DeveloperProducts[productKey]
		local productId = tonumber(productIdValue)
		if product and productId and productId > 0 then
			product.id = productId
			product.Id = productId
			applied += 1
		end
	end
	rebuildDeveloperProductIndex()
	return applied
end

function MonetizationConfig.ResolveDeveloperProductIds(marketplaceService)
	if not marketplaceService or type(marketplaceService.GetDeveloperProductsAsync) ~= "function" then
		return false, "MarketplaceService:GetDeveloperProductsAsync is unavailable"
	end

	local success, pagesOrError = pcall(function()
		return marketplaceService:GetDeveloperProductsAsync()
	end)
	if not success then
		return false, pagesOrError
	end

	local pages = pagesOrError
	local allProducts = {}
	while pages do
		for _, product in ipairs(pages:GetCurrentPage()) do
			table.insert(allProducts, product)
		end
		if pages.IsFinished then
			break
		end

		local advanced, advanceError = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not advanced then
			return false, advanceError
		end
	end
	local resolvedCount = MonetizationConfig.ApplyDeveloperProductCatalog(allProducts)

	local missing = {}
	for _, productKey in ipairs(MonetizationConfig.SeaStarProductOrder) do
		local product = MonetizationConfig.DeveloperProducts[productKey]
		if not product or (tonumber(product.id) or 0) <= 0 then
			table.insert(missing, productKey)
		end
	end

	if #missing > 0 then
		return false, "Missing catalog products: " .. table.concat(missing, ", ")
	end

	return true, resolvedCount
end

return MonetizationConfig
