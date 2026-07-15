local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))
local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local GetState = Remotes:WaitForChild("GetState")
local StateUpdated = Remotes:WaitForChild("StateUpdated")
local ShopAction = Remotes:WaitForChild("ShopAction")
local LoginRewardAction = Remotes:WaitForChild("LoginRewardAction")
local OpenShop = Remotes:WaitForChild("OpenShop", 10)

local COLORS = {
	panel = Color3.fromRGB(18, 22, 29),
	card = Color3.fromRGB(29, 36, 47),
	cardAlt = Color3.fromRGB(38, 45, 57),
	stroke = Color3.fromRGB(71, 85, 105),
	muted = Color3.fromRGB(190, 204, 220),
	blue = Color3.fromRGB(53, 130, 246),
	green = Color3.fromRGB(28, 160, 92),
	gold = Color3.fromRGB(255, 181, 36),
	sea = Color3.fromRGB(58, 174, 205),
	disabled = Color3.fromRGB(86, 98, 115),
}

local state = nil
local stateReceivedAt = os.clock()
local activeShopTab = "Sea Stars"
local autoOpenEvaluated = false
local loginOpenedAutomatically = false
local requestedMidnightRefresh = false

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or COLORS.stroke
	stroke.Thickness = thickness or 1
	stroke.Parent = instance
	return stroke
end

local function makeText(parent, text, size, color, bold)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextSize = size or 14
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function makeButton(parent, text, color)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or COLORS.blue
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 13
	button.TextWrapped = true
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	addCorner(button, 7)
	return button
end

local function clearContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local existing = playerGui:FindFirstChild("FishyFishPhase3Gui")
if existing then
	existing:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "FishyFishPhase3Gui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local hud = Instance.new("Frame")
hud.Name = "SeaStarLoginHud"
hud.AnchorPoint = Vector2.new(1, 0)
hud.Position = UDim2.new(1, -18, 0, 18)
hud.Size = UDim2.fromOffset(176, 86)
hud.BackgroundTransparency = 1
hud.Parent = gui

local seaStarButton = makeButton(hud, "Sea Stars: 0", COLORS.sea)
seaStarButton.Size = UDim2.new(1, 0, 0, 40)
local loginButton = makeButton(hud, "Login Rewards", COLORS.gold)
loginButton.Position = UDim2.new(0, 0, 0, 46)
loginButton.Size = UDim2.new(1, 0, 0, 40)

local function makeOverlay(name)
	local overlay = Instance.new("Frame")
	overlay.Name = name
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(7, 10, 15)
	overlay.BackgroundTransparency = 0.34
	overlay.Visible = false
	overlay.Parent = gui
	return overlay
end

local shopOverlay = makeOverlay("SeaStarShopOverlay")
local shopPanel = Instance.new("Frame")
shopPanel.AnchorPoint = Vector2.new(0.5, 0.5)
shopPanel.Position = UDim2.fromScale(0.5, 0.52)
shopPanel.Size = UDim2.new(0.72, 0, 0.78, 0)
shopPanel.BackgroundColor3 = COLORS.panel
shopPanel.Parent = shopOverlay
addCorner(shopPanel, 10)
addStroke(shopPanel)
local shopConstraint = Instance.new("UISizeConstraint")
shopConstraint.MinSize = Vector2.new(350, 400)
shopConstraint.MaxSize = Vector2.new(780, 650)
shopConstraint.Parent = shopPanel

local shopTitle = makeText(shopPanel, "Sea Star Shop", 22, Color3.new(1, 1, 1), true)
shopTitle.Position = UDim2.new(0, 18, 0, 10)
shopTitle.Size = UDim2.new(1, -80, 0, 34)
local shopBalance = makeText(shopPanel, "0 Sea Stars", 14, Color3.fromRGB(130, 231, 255), true)
shopBalance.Position = UDim2.new(0, 18, 0, 42)
shopBalance.Size = UDim2.new(1, -80, 0, 24)
local shopClose = makeButton(shopPanel, "X", COLORS.disabled)
shopClose.Position = UDim2.new(1, -50, 0, 12)
shopClose.Size = UDim2.fromOffset(34, 32)

local shopTabs = Instance.new("Frame")
shopTabs.Position = UDim2.new(0, 16, 0, 72)
shopTabs.Size = UDim2.new(1, -32, 0, 38)
shopTabs.BackgroundTransparency = 1
shopTabs.Parent = shopPanel
local shopTabLayout = Instance.new("UIListLayout")
shopTabLayout.FillDirection = Enum.FillDirection.Horizontal
shopTabLayout.Padding = UDim.new(0, 8)
shopTabLayout.Parent = shopTabs

local shopContent = Instance.new("ScrollingFrame")
shopContent.Position = UDim2.new(0, 16, 0, 118)
shopContent.Size = UDim2.new(1, -32, 1, -134)
shopContent.BackgroundTransparency = 1
shopContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopContent.CanvasSize = UDim2.new()
shopContent.ScrollBarThickness = 6
shopContent.Parent = shopPanel
local shopContentLayout = Instance.new("UIListLayout")
shopContentLayout.Padding = UDim.new(0, 8)
shopContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopContentLayout.Parent = shopContent

local loginOverlay = makeOverlay("LoginRewardOverlay")
local loginPanel = Instance.new("Frame")
loginPanel.AnchorPoint = Vector2.new(0.5, 0.5)
loginPanel.Position = UDim2.fromScale(0.5, 0.52)
loginPanel.Size = UDim2.new(0.76, 0, 0.82, 0)
loginPanel.BackgroundColor3 = COLORS.panel
loginPanel.Parent = loginOverlay
addCorner(loginPanel, 10)
addStroke(loginPanel)
local loginConstraint = Instance.new("UISizeConstraint")
loginConstraint.MinSize = Vector2.new(360, 430)
loginConstraint.MaxSize = Vector2.new(820, 680)
loginConstraint.Parent = loginPanel

local loginTitle = makeText(loginPanel, "Sequential Login Rewards", 22, Color3.new(1, 1, 1), true)
loginTitle.Position = UDim2.new(0, 18, 0, 10)
loginTitle.Size = UDim2.new(1, -80, 0, 34)
local loginClose = makeButton(loginPanel, "X", COLORS.disabled)
loginClose.Position = UDim2.new(1, -50, 0, 12)
loginClose.Size = UDim2.fromOffset(34, 32)
local loginInfo = makeText(loginPanel, "Missing dates never resets or skips your progress.", 13, COLORS.muted, false)
loginInfo.Position = UDim2.new(0, 18, 0, 46)
loginInfo.Size = UDim2.new(1, -36, 0, 24)
loginInfo.TextWrapped = true
local loginTimer = makeText(loginPanel, "", 13, Color3.fromRGB(130, 231, 255), true)
loginTimer.Position = UDim2.new(0, 18, 0, 70)
loginTimer.Size = UDim2.new(1, -36, 0, 24)

local loginGrid = Instance.new("ScrollingFrame")
loginGrid.Position = UDim2.new(0, 18, 0, 100)
loginGrid.Size = UDim2.new(1, -36, 1, -190)
loginGrid.BackgroundTransparency = 1
loginGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
loginGrid.CanvasSize = UDim2.new()
loginGrid.ScrollBarThickness = 6
loginGrid.Parent = loginPanel
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.25, -7, 0, 104)
gridLayout.CellPadding = UDim2.fromOffset(8, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = loginGrid

local loginStatus = makeText(loginPanel, "", 13, COLORS.muted, false)
loginStatus.Position = UDim2.new(0, 18, 1, -84)
loginStatus.Size = UDim2.new(1, -180, 0, 58)
loginStatus.TextWrapped = true
local claimButton = makeButton(loginPanel, "Claim", COLORS.green)
claimButton.Position = UDim2.new(1, -150, 1, -72)
claimButton.Size = UDim2.fromOffset(132, 44)

local function currentDesignWith(changes)
	local monetization = state and state.Monetization or {}
	local source = monetization.AquariumPreviewDesign or monetization.AquariumDesign or MonetizationConfig.AquariumDesigner.defaultDesign
	local result = {
		theme = source.theme or "Classic",
		backdropEnabled = source.backdropEnabled ~= false,
		backgroundColor = source.backgroundColor or "Aqua",
		lightingColor = source.lightingColor or "SoftWhite",
		signText = source.signText or "",
		decorations = {},
		freeDecorations = {},
	}
	for slotId, decorationId in pairs(source.decorations or {}) do
		result.decorations[slotId] = decorationId
	end
	for _, item in ipairs(source.freeDecorations or {}) do
		table.insert(result.freeDecorations, {
			decorationId = item.decorationId,
			x = item.x,
			y = item.y,
			z = item.z,
			scale = item.scale,
		})
	end
	for key, value in pairs(changes or {}) do
		result[key] = value
	end
	return result
end

local function makeSectionHeading(text)
	local heading = makeText(shopContent, text, 17, Color3.new(1, 1, 1), true)
	heading.Size = UDim2.new(1, -8, 0, 30)
	return heading
end

local function makeShopCard(height)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, height or 104)
	card.BackgroundColor3 = COLORS.card
	card.Parent = shopContent
	addCorner(card, 8)
	addStroke(card, Color3.fromRGB(60, 72, 90), 1)
	return card
end

local robuxPriceCache = {}
local function getProductPrice(product)
	local productId = tonumber(product.id) or tonumber(product.Id)
	local fallback = tonumber(product.priceRobux) or tonumber(product.Price)
	if not productId or productId <= 0 then
		return fallback
	end
	if robuxPriceCache[productId] ~= nil then
		return robuxPriceCache[productId]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	end)
	local price = ok and type(info) == "table" and tonumber(info.PriceInRobux) or fallback
	robuxPriceCache[productId] = price
	return price
end

local renderShop

local function renderSeaStarProducts()
	makeSectionHeading("Sea Star Packs")
	local note = makeText(shopContent, "Sea Stars are cosmetic only and permanently unlock aquarium themes.", 13, COLORS.muted, false)
	note.Size = UDim2.new(1, -8, 0, 40)
	note.TextWrapped = true
	for _, productKey in ipairs(MonetizationConfig.SeaStarProductOrder or {}) do
		local product = MonetizationConfig.DeveloperProducts[productKey]
		if product then
			local card = makeShopCard(104)
			local title = makeText(card, product.name, 15, Color3.new(1, 1, 1), true)
			title.Position = UDim2.new(0, 14, 0, 10)
			title.Size = UDim2.new(1, -134, 0, 24)
			local detail = makeText(card, tostring(product.seaStarAmount or 0) .. " Sea Stars", 13, Color3.fromRGB(130, 231, 255), true)
			detail.Position = UDim2.new(0, 14, 0, 38)
			detail.Size = UDim2.new(1, -134, 0, 22)
			local productId = tonumber(product.id) or tonumber(product.Id)
			local available = product.purchasable ~= false and productId and productId > 0
			local price = getProductPrice(product)
			local priceLabel = makeText(card, tostring(price or "?") .. " Robux", 12, COLORS.gold, true)
			priceLabel.Position = UDim2.new(0, 14, 0, 66)
			priceLabel.Size = UDim2.new(1, -134, 0, 20)
			local buy = makeButton(card, available and "Buy" or "Coming Soon", available and COLORS.green or COLORS.disabled)
			buy.Position = UDim2.new(1, -116, 0, 33)
			buy.Size = UDim2.fromOffset(100, 38)
			buy.AutoButtonColor = available == true
			buy.Active = available == true
			buy.MouseButton1Click:Connect(function()
				if available then
					ShopAction:FireServer("PromptProduct", "Product", productKey)
				end
			end)
		end
	end
end

local function renderThemes()
	makeSectionHeading("Aquarium Themes")
	local note = makeText(shopContent, "Locked themes can always be previewed. Unlocking is permanent and costs Sea Stars only.", 13, COLORS.muted, false)
	note.Size = UDim2.new(1, -8, 0, 42)
	note.TextWrapped = true
	local unlocks = state and state.SeaStarUnlocks or {}
	for _, themeId in ipairs(MonetizationConfig.AquariumDesigner.themeOrder or {}) do
		local theme = MonetizationConfig.AquariumDesigner.themes[themeId]
		if theme then
			local owned = theme.free == true or unlocks[themeId] == true
			local card = makeShopCard(124)
			local title = makeText(card, theme.displayName or theme.name or themeId, 15, Color3.new(1, 1, 1), true)
			title.Position = UDim2.new(0, 14, 0, 8)
			title.Size = UDim2.new(1, -28, 0, 24)
			local priceText = theme.free == true and "Free" or (tostring(theme.seaStarPrice or 0) .. " Sea Stars")
			local price = makeText(card, priceText, 13, theme.free == true and Color3.fromRGB(112, 255, 156) or COLORS.gold, true)
			price.Position = UDim2.new(0, 14, 0, 34)
			price.Size = UDim2.new(1, -28, 0, 22)
			local ownedText = makeText(card, owned and "Owned" or "Locked", 12, owned and Color3.fromRGB(112, 255, 156) or COLORS.muted, true)
			ownedText.Position = UDim2.new(0, 14, 0, 58)
			ownedText.Size = UDim2.new(1, -28, 0, 20)

			local preview = makeButton(card, "Preview", COLORS.blue)
			preview.Position = UDim2.new(0, 14, 1, -38)
			preview.Size = UDim2.fromOffset(90, 30)
			preview.MouseButton1Click:Connect(function()
				ShopAction:FireServer("PreviewAquariumDesign", "Aquarium", themeId, currentDesignWith({ theme = themeId }))
			end)

			local apply = makeButton(card, "Apply", owned and COLORS.green or COLORS.disabled)
			apply.Position = UDim2.new(0, 112, 1, -38)
			apply.Size = UDim2.fromOffset(80, 30)
			apply.Active = owned
			apply.AutoButtonColor = owned
			apply.MouseButton1Click:Connect(function()
				if owned then
					ShopAction:FireServer("ApplyAquariumDesign", "Aquarium", themeId, currentDesignWith({ theme = themeId }))
				end
			end)

			local unlock = makeButton(card, owned and "Owned" or "Unlock", owned and COLORS.disabled or COLORS.gold)
			unlock.Position = UDim2.new(1, -108, 1, -38)
			unlock.Size = UDim2.fromOffset(94, 30)
			unlock.Active = not owned
			unlock.AutoButtonColor = not owned
			unlock.MouseButton1Click:Connect(function()
				if not owned then
					ShopAction:FireServer("PurchaseAquariumTheme", "AquariumTheme", themeId)
				end
			end)
		end
	end
end

local function makePresetCard(kind, optionId, option)
	local card = makeShopCard(88)
	local title = makeText(card, option.name or optionId, 14, Color3.new(1, 1, 1), true)
	title.Position = UDim2.new(0, 14, 0, 10)
	title.Size = UDim2.new(1, -220, 0, 24)
	local freeText = makeText(card, "Free editor preset", 12, Color3.fromRGB(112, 255, 156), false)
	freeText.Position = UDim2.new(0, 14, 0, 38)
	freeText.Size = UDim2.new(1, -220, 0, 20)
	local preview = makeButton(card, "Preview", COLORS.blue)
	preview.Position = UDim2.new(1, -196, 0, 27)
	preview.Size = UDim2.fromOffset(84, 32)
	preview.MouseButton1Click:Connect(function()
		ShopAction:FireServer("PreviewAquariumDesign", "Aquarium", kind, currentDesignWith({ [kind] = optionId }))
	end)
	local apply = makeButton(card, "Apply", COLORS.green)
	apply.Position = UDim2.new(1, -104, 0, 27)
	apply.Size = UDim2.fromOffset(88, 32)
	apply.MouseButton1Click:Connect(function()
		ShopAction:FireServer("ApplyAquariumDesign", "Aquarium", kind, currentDesignWith({ [kind] = optionId }))
	end)
end

local function renderEditorControls()
	makeSectionHeading("Free Aquarium Editor Controls")
	local note = makeText(shopContent, "Placement, move, rotate, scale, remove, owned decorations, precision controls, presets, backgrounds, lighting, and sign text are all free.", 13, COLORS.muted, false)
	note.Size = UDim2.new(1, -8, 0, 58)
	note.TextWrapped = true

	makeSectionHeading("Background Presets")
	for _, optionId in ipairs(MonetizationConfig.AquariumDesigner.backgroundColorOrder or {}) do
		makePresetCard("backgroundColor", optionId, MonetizationConfig.AquariumDesigner.backgroundColors[optionId])
	end
	makeSectionHeading("Lighting Presets")
	for _, optionId in ipairs(MonetizationConfig.AquariumDesigner.lightingColorOrder or {}) do
		makePresetCard("lightingColor", optionId, MonetizationConfig.AquariumDesigner.lightingColors[optionId])
	end

	makeSectionHeading("Display Sign")
	local signCard = makeShopCard(104)
	local signBox = Instance.new("TextBox")
	signBox.Position = UDim2.new(0, 14, 0, 14)
	signBox.Size = UDim2.new(1, -224, 0, 34)
	signBox.BackgroundColor3 = COLORS.cardAlt
	signBox.TextColor3 = Color3.new(1, 1, 1)
	signBox.PlaceholderText = "Aquarium sign text"
	signBox.Text = currentDesignWith().signText
	signBox.ClearTextOnFocus = false
	signBox.TextSize = 13
	signBox.Font = Enum.Font.Gotham
	signBox.Parent = signCard
	addCorner(signBox, 6)
	local preview = makeButton(signCard, "Preview", COLORS.blue)
	preview.Position = UDim2.new(1, -196, 0, 14)
	preview.Size = UDim2.fromOffset(84, 34)
	preview.MouseButton1Click:Connect(function()
		ShopAction:FireServer("PreviewAquariumDesign", "Aquarium", "signText", currentDesignWith({ signText = signBox.Text }))
	end)
	local save = makeButton(signCard, "Save", COLORS.green)
	save.Position = UDim2.new(1, -104, 0, 14)
	save.Size = UDim2.fromOffset(88, 34)
	save.MouseButton1Click:Connect(function()
		ShopAction:FireServer("ApplyAquariumDesign", "Aquarium", "signText", currentDesignWith({ signText = signBox.Text }))
	end)
	local cancel = makeButton(signCard, "Cancel Preview", COLORS.disabled)
	cancel.Position = UDim2.new(0, 14, 0, 58)
	cancel.Size = UDim2.fromOffset(130, 32)
	cancel.MouseButton1Click:Connect(function()
		ShopAction:FireServer("CancelAquariumPreview", "Aquarium")
	end)
end

renderShop = function()
	clearContainer(shopTabs)
	clearContainer(shopContent)
	shopBalance.Text = tostring(state and state.SeaStars or 0) .. " Sea Stars"
	for _, tabName in ipairs({ "Sea Stars", "Themes", "Free Editor" }) do
		local tab = makeButton(shopTabs, tabName, activeShopTab == tabName and COLORS.blue or COLORS.cardAlt)
		tab.Size = UDim2.new(0.333, -6, 1, 0)
		tab.MouseButton1Click:Connect(function()
			activeShopTab = tabName
			renderShop()
		end)
	end
	if activeShopTab == "Sea Stars" then
		renderSeaStarProducts()
	elseif activeShopTab == "Themes" then
		renderThemes()
	else
		renderEditorControls()
	end
end

local function renderLogin()
	clearContainer(loginGrid)
	local login = state and state.LoginRewards
	if not login then
		loginStatus.Text = "Loading server reward data..."
		claimButton.Active = false
		claimButton.AutoButtonColor = false
		claimButton.BackgroundColor3 = COLORS.disabled
		return
	end

	loginTitle.Text = string.format("Sequential Login Rewards • %d Days", login.DaysInCycle or 28)
	loginStatus.Text = login.ClaimAvailable and ("Day " .. tostring(login.CurrentDay) .. " is ready.") or "Today's reward has been claimed."
	claimButton.Text = login.ClaimAvailable and ("Claim Day " .. tostring(login.CurrentDay)) or "Claimed"
	claimButton.Active = login.ClaimAvailable == true
	claimButton.AutoButtonColor = login.ClaimAvailable == true
	claimButton.BackgroundColor3 = login.ClaimAvailable and COLORS.green or COLORS.disabled

	for _, slot in ipairs(login.RewardTrack or {}) do
		local day = slot.Day
		local claimed = day < (login.CurrentDay or 1)
		local current = day == (login.CurrentDay or 1)
		local color = claimed and Color3.fromRGB(36, 104, 72) or COLORS.card
		if current then
			color = login.ClaimAvailable and COLORS.blue or Color3.fromRGB(60, 86, 126)
		elseif slot.IsFinal then
			color = Color3.fromRGB(118, 78, 32)
		elseif slot.IsMilestone then
			color = Color3.fromRGB(63, 55, 108)
		end
		local card = Instance.new("Frame")
		card.LayoutOrder = day
		card.BackgroundColor3 = color
		card.Parent = loginGrid
		addCorner(card, 8)
		addStroke(card, current and Color3.fromRGB(130, 231, 255) or COLORS.stroke, current and 2 or 1)
		local dayLabel = makeText(card, "Day " .. tostring(day), 13, Color3.new(1, 1, 1), true)
		dayLabel.Position = UDim2.new(0, 8, 0, 4)
		dayLabel.Size = UDim2.new(1, -16, 0, 20)
		local statusText = claimed and "Claimed" or (current and (login.ClaimAvailable and "Available" or "Next") or "Upcoming")
		if slot.IsFinal then
			statusText = statusText .. " • Grand"
		elseif slot.IsMilestone then
			statusText = statusText .. " • Milestone"
		end
		local statusLabel = makeText(card, statusText, 10, claimed and Color3.fromRGB(155, 255, 190) or COLORS.gold, true)
		statusLabel.Position = UDim2.new(0, 8, 0, 24)
		statusLabel.Size = UDim2.new(1, -16, 0, 18)
		local rewardLabel = makeText(card, slot.Summary or "", 9, COLORS.muted, false)
		rewardLabel.Position = UDim2.new(0, 8, 0, 43)
		rewardLabel.Size = UDim2.new(1, -16, 1, -47)
		rewardLabel.TextWrapped = true
		rewardLabel.TextYAlignment = Enum.TextYAlignment.Top
	end
end

local function enforceOwnedDecorationButtons()
	local editorGui = playerGui:FindFirstChild("AquariumFreePlacementGui")
	if not editorGui then
		return
	end
	local owned = state and state.AquariumDecorations or {}
	for decorationId, decoration in pairs(MonetizationConfig.AquariumDesigner.decorations or {}) do
		if decorationId ~= "None" then
			for _, descendant in ipairs(editorGui:GetDescendants()) do
				if descendant:IsA("TextButton") then
					local taggedId = descendant:GetAttribute("Phase3DecorationId")
					if taggedId == decorationId or (taggedId == nil and descendant.Text == decoration.name) then
						descendant:SetAttribute("Phase3DecorationId", decorationId)
						local isOwned = (owned[decorationId] or 0) > 0
						descendant.Active = isOwned
						descendant.AutoButtonColor = isOwned
						descendant.Text = isOwned and decoration.name or (decoration.name .. "\nLocked")
						if not isOwned then
							descendant.BackgroundColor3 = COLORS.disabled
						end
					end
				end
			end
		end
	end
end

local function updateTimer()
	local login = state and state.LoginRewards
	if not login then
		loginTimer.Text = ""
		return
	end
	if login.ClaimAvailable then
		loginTimer.Text = "Available now • eligibility is determined by the server's UTC date"
		return
	end
	local remaining = math.max(0, math.floor((login.SecondsUntilNextUtcClaim or 0) - (os.clock() - stateReceivedAt)))
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	local seconds = remaining % 60
	loginTimer.Text = string.format("Next UTC claim in %02d:%02d:%02d", hours, minutes, seconds)
	if remaining <= 0 and not requestedMidnightRefresh then
		requestedMidnightRefresh = true
		task.spawn(function()
			local ok, result = pcall(function()
				return GetState:InvokeServer()
			end)
			if ok and type(result) == "table" then
				state = result
				stateReceivedAt = os.clock()
				requestedMidnightRefresh = false
				renderLogin()
				updateTimer()
			end
		end)
	end
end

local function showShop(tabName)
	activeShopTab = tabName or activeShopTab
	loginOverlay.Visible = false
	shopOverlay.Visible = true
	renderShop()
end

local function showLogin()
	shopOverlay.Visible = false
	loginOverlay.Visible = true
	renderLogin()
	updateTimer()
end

local function receiveState(newState)
	if type(newState) ~= "table" then
		return
	end
	state = newState
	stateReceivedAt = os.clock()
	requestedMidnightRefresh = false
	seaStarButton.Text = "Sea Stars: " .. tostring(state.SeaStars or 0)
	local login = state.LoginRewards
	loginButton.Text = login and login.ClaimAvailable and ("Login Day " .. tostring(login.CurrentDay) .. " Ready") or "Login Rewards"
	if shopOverlay.Visible then
		renderShop()
	end
	if loginOverlay.Visible then
		renderLogin()
		updateTimer()
	end
	task.defer(enforceOwnedDecorationButtons)
	if not autoOpenEvaluated then
		autoOpenEvaluated = true
		if login and login.ClaimAvailable and not loginOpenedAutomatically then
			loginOpenedAutomatically = true
			showLogin()
		end
	end
end

seaStarButton.MouseButton1Click:Connect(function()
	showShop("Sea Stars")
end)
loginButton.MouseButton1Click:Connect(showLogin)
shopClose.MouseButton1Click:Connect(function()
	shopOverlay.Visible = false
end)
loginClose.MouseButton1Click:Connect(function()
	loginOverlay.Visible = false
end)
claimButton.MouseButton1Click:Connect(function()
	if state and state.LoginRewards and state.LoginRewards.ClaimAvailable then
		claimButton.Active = false
		claimButton.AutoButtonColor = false
		claimButton.BackgroundColor3 = COLORS.disabled
		claimButton.Text = "Claiming..."
		LoginRewardAction:FireServer("Claim")
	end
end)

StateUpdated.OnClientEvent:Connect(receiveState)
LoginRewardAction.OnClientEvent:Connect(function(result)
	if type(result) == "table" then
		loginStatus.Text = result.Message or (result.Success and "Reward claimed." or "Reward unavailable.")
	end
end)
if OpenShop then
	OpenShop.OnClientEvent:Connect(function(tabName)
		if tabName == "SeaStars" or tabName == "Sea Stars" or tabName == "Themes" then
			showShop(tabName == "Themes" and "Themes" or "Sea Stars")
		end
	end)
end

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("TextButton") or descendant.Name == "AquariumFreePlacementGui" then
		task.defer(enforceOwnedDecorationButtons)
	end
	if descendant:IsA("LocalScript") and descendant.Name == "AquariumDesignerShopCleanup" then
		descendant.Disabled = true
	end
end)

task.defer(function()
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("LocalScript") and descendant.Name == "AquariumDesignerShopCleanup" then
			descendant.Disabled = true
		end
	end
	local ok, initialState = pcall(function()
		return GetState:InvokeServer()
	end)
	if ok then
		receiveState(initialState)
	end
end)

local timerAccumulator = 0
RunService.RenderStepped:Connect(function(deltaTime)
	timerAccumulator += deltaTime
	if timerAccumulator >= 1 then
		timerAccumulator = 0
		if loginOverlay.Visible then
			updateTimer()
		end
	end
end)
