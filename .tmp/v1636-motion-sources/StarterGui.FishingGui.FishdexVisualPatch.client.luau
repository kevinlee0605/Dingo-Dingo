-- FishdexVisualPatch_REDESIGN_v2
-- Replace your current FishdexVisualPatch.luau with this whole file.
-- StarterGui > FishingGui > FishdexVisualPatch

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local fishingGui = playerGui:WaitForChild("FishingGui")

local ASSETS = {
	FishdexIcon = "rbxassetid://126888363962311",
	AllTabSelected = "rbxassetid://74193356060798",
	AllTabUnselected = "rbxassetid://122642765846638",
	IslandTabSelected = "rbxassetid://119120751789446",
	IslandTabUnselected = "rbxassetid://74423157457349",
	AllIcon = "rbxassetid://104401098200678",
	LilyshoreIslandIcon = "rbxassetid://98205500611196",
	RiverbendIslandIcon = "rbxassetid://71447038153276",
	CoralCoastIslandIcon = "rbxassetid://118883751708776",
	CollectionTab = "rbxassetid://101419501637204",
	CheckedIcon = "rbxassetid://73430945226148",
	FishyBackGround = "rbxassetid://77909229815890",
	FishdexRealBackGround = "rbxassetid://89231191992466",
	YellowButton = "rbxassetid://87138802501328",
	XButton = "rbxassetid://119322438066977",
}

local TAB_CONFIG = {
	AllTab = {
		label = "All",
		icon = ASSETS.AllIcon,
		selectedImage = ASSETS.AllTabSelected,
		unselectedImage = ASSETS.AllTabUnselected,
		textX = 0.68,
		textWidth = 0.30,
		textSize = 31,
		iconX = 0.26,
		iconSize = UDim2.fromOffset(42, 42),
	},
	LilyshoreIslandTab = {
		label = "Lilyshore",
		icon = ASSETS.LilyshoreIslandIcon,
		selectedImage = ASSETS.IslandTabSelected,
		unselectedImage = ASSETS.IslandTabUnselected,
		textX = 0.64,
		textWidth = 0.44,
		textSize = 25,
		iconX = 0.18,
		iconSize = UDim2.fromOffset(54, 54),
	},
	RiverbendIslandTab = {
		label = "Riverbend",
		icon = ASSETS.RiverbendIslandIcon,
		selectedImage = ASSETS.IslandTabSelected,
		unselectedImage = ASSETS.IslandTabUnselected,
		textX = 0.65,
		textWidth = 0.44,
		textSize = 25,
		iconX = 0.18,
		iconSize = UDim2.fromOffset(54, 54),
	},
	CoralCoastIslandTab = {
		label = "Coral Coast",
		icon = ASSETS.CoralCoastIslandIcon,
		selectedImage = ASSETS.IslandTabSelected,
		unselectedImage = ASSETS.IslandTabUnselected,
		textX = 0.64,
		textWidth = 0.48,
		textSize = 25,
		iconX = 0.18,
		iconSize = UDim2.fromOffset(54, 54),
	},
}

local CARD_WIDTH = 390
local CARD_HEIGHT = 260
local CARD_GAP_X = 24
local CARD_GAP_Y = 20

local function findModernFishdex()
	for _, descendant in ipairs(fishingGui:GetDescendants()) do
		if descendant:IsA("ImageLabel") and descendant.Name == "ModernFishdex" then
			return descendant
		end
	end
	return nil
end

local function getOrCreate(parent, className, name)
	local child = parent:FindFirstChild(name)
	if child and child.ClassName == className then
		return child
	end
	if child then
		child:Destroy()
	end
	child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function removeTextConstraint(label)
	local c = label:FindFirstChildOfClass("UITextSizeConstraint")
	if c then
		c:Destroy()
	end
end

local function setTextConstraint(label, minSize, maxSize)
	local c = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not c then
		c = Instance.new("UITextSizeConstraint")
		c.Parent = label
	end
	c.MinTextSize = minSize
	c.MaxTextSize = maxSize
end

local function isTabSelected(button)
	local stroke = button:FindFirstChild("SelectedStroke")
	if stroke and stroke:IsA("UIStroke") then
		return stroke.Transparency < 0.5
	end
	return false
end

local function patchBase(modernRoot)
	modernRoot.ScaleType = Enum.ScaleType.Stretch
	modernRoot.BackgroundTransparency = 1
	modernRoot.Image = ASSETS.FishdexRealBackGround
	modernRoot.ZIndex = 200
end

local function patchHeader(modernRoot)
	local title = modernRoot:FindFirstChild("FishdexTitle")
	if title and title:IsA("TextLabel") then
		title.AnchorPoint = Vector2.new(0.5, 0)
		title.Position = UDim2.fromOffset(770, 22)
		title.Size = UDim2.fromOffset(500, 92)
		title.Text = "FISHDEX"
		title.TextScaled = false
		removeTextConstraint(title)
		title.TextSize = 72
		title.Font = Enum.Font.FredokaOne
		title.TextColor3 = Color3.fromRGB(255,255,255)
		title.TextStrokeColor3 = Color3.fromRGB(0,0,0)
		title.TextStrokeTransparency = 0
		setTextConstraint(title, 30, 72)
		title.ZIndex = 210
	end

	local book = getOrCreate(modernRoot, "ImageLabel", "FishdexHeaderIcon")
	book.BackgroundTransparency = 1
	book.AnchorPoint = Vector2.new(0.5, 0)
	book.Position = UDim2.fromOffset(510, 6)
	book.Size = UDim2.fromOffset(110, 110)
	book.Image = ASSETS.FishdexIcon
	book.ScaleType = Enum.ScaleType.Fit
	book.ZIndex = 210

	local leftBadge = getOrCreate(modernRoot, "ImageLabel", "HeaderYellowBadge")
	leftBadge.BackgroundTransparency = 1
	leftBadge.Position = UDim2.fromOffset(24, 34)
	leftBadge.Size = UDim2.fromOffset(62, 62)
	leftBadge.Image = ASSETS.YellowButton
	leftBadge.ScaleType = Enum.ScaleType.Fit
	leftBadge.ZIndex = 210

	local closeButton = modernRoot:FindFirstChild("CloseButton")
	if closeButton and closeButton:IsA("ImageButton") then
		closeButton.BackgroundTransparency = 1
		closeButton.Position = UDim2.fromOffset(1402, 30)
		closeButton.Size = UDim2.fromOffset(78, 78)
		closeButton.Image = ASSETS.YellowButton
		closeButton.ScaleType = Enum.ScaleType.Fit
		closeButton.ZIndex = 211

		local xIcon = getOrCreate(closeButton, "ImageLabel", "CloseIcon")
		xIcon.BackgroundTransparency = 1
		xIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		xIcon.Position = UDim2.fromScale(0.5, 0.5)
		xIcon.Size = UDim2.fromScale(0.55, 0.55)
		xIcon.Image = ASSETS.XButton
		xIcon.ScaleType = Enum.ScaleType.Fit
		xIcon.ZIndex = 212
		xIcon.Active = false
	end

	local divider = getOrCreate(modernRoot, "Frame", "TabsDivider")
	divider.AnchorPoint = Vector2.new(0.5, 0)
	divider.Position = UDim2.fromOffset(770, 262)
	divider.Size = UDim2.fromOffset(1368, 2)
	divider.BackgroundColor3 = Color3.fromRGB(68, 164, 255)
	divider.BackgroundTransparency = 0.35
	divider.BorderSizePixel = 0
	divider.ZIndex = 206
end

local function patchTab(button)
	if not button:IsA("ImageButton") then
		return
	end
	local cfg = TAB_CONFIG[button.Name]
	if not cfg then
		return
	end

	button.AutoButtonColor = false
	button.ScaleType = Enum.ScaleType.Stretch
	button.Image = isTabSelected(button) and cfg.selectedImage or cfg.unselectedImage
	button.ZIndex = 207

	local stroke = button:FindFirstChild("SelectedStroke")
	if stroke then
		stroke.Transparency = 1
	end

	local title = button:FindFirstChild("TabTitle")
	if title and title:IsA("TextLabel") then
		title.BackgroundTransparency = 1
		title.AnchorPoint = Vector2.new(0.5, 0.5)
		title.Position = UDim2.fromScale(cfg.textX, 0.50)
		title.Size = UDim2.fromScale(cfg.textWidth, 0.48)
		title.Font = Enum.Font.FredokaOne
		title.Text = cfg.label
		title.TextScaled = false
		removeTextConstraint(title)
		title.TextSize = cfg.textSize
		title.TextColor3 = Color3.fromRGB(255,255,255)
		title.TextStrokeColor3 = Color3.fromRGB(0,0,0)
		title.TextStrokeTransparency = 0
		setTextConstraint(title, 10, cfg.textSize)
		title.ZIndex = 208
	end

	local icon = getOrCreate(button, "ImageLabel", "TabIcon")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(cfg.iconX, 0.5)
	icon.Size = cfg.iconSize
	icon.Image = cfg.icon
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 208
	icon.Active = false
end

local function refreshTabs(modernRoot)
	for _, child in ipairs(modernRoot:GetChildren()) do
		patchTab(child)
	end
end

local function patchCollection(modernRoot)
	local panel = modernRoot:FindFirstChild("CollectionPanel")
	if not (panel and panel:IsA("ImageLabel")) then
		return
	end

	panel.Image = ASSETS.CollectionTab
	panel.Position = UDim2.fromOffset(1140, 904)
	panel.Size = UDim2.fromOffset(306, 84)
	panel.ScaleType = Enum.ScaleType.Stretch
	panel.ZIndex = 207

	local checked = getOrCreate(panel, "ImageLabel", "CheckedIcon")
	checked.BackgroundTransparency = 1
	checked.Position = UDim2.fromScale(0.07, 0.17)
	checked.Size = UDim2.fromOffset(44, 44)
	checked.Image = ASSETS.CheckedIcon
	checked.ScaleType = Enum.ScaleType.Fit
	checked.ZIndex = 208

	local title = panel:FindFirstChild("CollectionTitle")
	if title and title:IsA("TextLabel") then
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromScale(0.35, 0.08)
		title.Size = UDim2.fromScale(0.42, 0.24)
		title.Font = Enum.Font.FredokaOne
		title.Text = "Collection"
		title.TextScaled = false
		removeTextConstraint(title)
		title.TextSize = 20
		title.TextColor3 = Color3.fromRGB(50, 241, 255)
		title.TextStrokeColor3 = Color3.fromRGB(0,0,0)
		title.TextStrokeTransparency = 0
		setTextConstraint(title, 10, 20)
	end

	local count = panel:FindFirstChild("CollectionCount")
	if count and count:IsA("TextLabel") then
		count.BackgroundTransparency = 1
		count.Position = UDim2.fromScale(0.36, 0.34)
		count.Size = UDim2.fromScale(0.46, 0.42)
		count.Font = Enum.Font.FredokaOne
		count.TextScaled = false
		removeTextConstraint(count)
		count.TextSize = 24
		count.TextColor3 = Color3.fromRGB(255,255,255)
		count.TextStrokeColor3 = Color3.fromRGB(0,0,0)
		count.TextStrokeTransparency = 0
		setTextConstraint(count, 10, 24)
	end
end

local function patchFishCard(card)
	if not card:IsA("ImageLabel") or not string.match(card.Name, "Card$") then
		return
	end

	card.ScaleType = Enum.ScaleType.Stretch
	card.Image = ASSETS.FishyBackGround
	card.BackgroundTransparency = 1
	card.ZIndex = 206

	local fishImage = card:FindFirstChild("FishImage")
	if fishImage and fishImage:IsA("ImageLabel") then
		fishImage.BackgroundTransparency = 1
		fishImage.AnchorPoint = Vector2.new(0.5, 0)
		fishImage.Position = UDim2.new(0.5, 0, 0.06, 0)
		fishImage.Size = UDim2.new(0.60, 0, 0.42, 0)
		fishImage.ScaleType = Enum.ScaleType.Fit
		fishImage.ZIndex = 207
	end

	local fishName = card:FindFirstChild("FishName")
	if fishName and fishName:IsA("TextLabel") then
		fishName.Position = UDim2.new(0.5, 0, 0.63, 0)
		fishName.Size = UDim2.new(0.88, 0, 0.14, 0)
		fishName.Font = Enum.Font.FredokaOne
		fishName.TextColor3 = Color3.fromRGB(255,255,255)
		fishName.TextStrokeColor3 = Color3.fromRGB(0,0,0)
		fishName.TextStrokeTransparency = 0
		fishName.ZIndex = 207
	end

	local badge = card:FindFirstChild("RarityBadge")
	if badge and badge:IsA("ImageLabel") then
		badge.Position = UDim2.new(0.5, 0, 0.77, 0)
		badge.Size = UDim2.new(0.46, 0, 0.18, 0)
		badge.ZIndex = 207
		local rarityText = badge:FindFirstChild("RarityText")
		if rarityText and rarityText:IsA("TextLabel") then
			rarityText.Position = UDim2.fromScale(0.5, 0.5)
			rarityText.Size = UDim2.new(0.88, 0, 0.58, 0)
			rarityText.Font = Enum.Font.FredokaOne
			rarityText.TextStrokeColor3 = Color3.fromRGB(0,0,0)
			rarityText.TextStrokeTransparency = 0
			rarityText.ZIndex = 208
		end
	end
end

local function patchCards(modernRoot)
	local cardsScroll = modernRoot:FindFirstChild("FishCardsScroll")
	if not (cardsScroll and cardsScroll:IsA("ScrollingFrame")) then
		return
	end

	cardsScroll.Position = UDim2.fromOffset(130, 300)
	cardsScroll.Size = UDim2.fromOffset(1260, 580)
	cardsScroll.BackgroundTransparency = 1
	cardsScroll.ZIndex = 205
	cardsScroll.ScrollBarThickness = 6
	cardsScroll.ScrollBarImageColor3 = Color3.fromRGB(53, 156, 255)

	local cardsHolder = cardsScroll:FindFirstChild("CardsHolder")
	if not cardsHolder then
		return
	end

	local grid = cardsHolder:FindFirstChildOfClass("UIGridLayout")
	if grid then
		grid.CellSize = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
		grid.CellPadding = UDim2.fromOffset(CARD_GAP_X, CARD_GAP_Y)
	end

	for _, child in ipairs(cardsHolder:GetChildren()) do
		patchFishCard(child)
	end

	if not cardsHolder:GetAttribute("PatchedV2") then
		cardsHolder:SetAttribute("PatchedV2", true)
		cardsHolder.ChildAdded:Connect(function(child)
			task.defer(patchFishCard, child)
		end)
	end
end

local function hookTabs(modernRoot)
	for _, child in ipairs(modernRoot:GetChildren()) do
		if child:IsA("ImageButton") and TAB_CONFIG[child.Name] and not child:GetAttribute("HookedV2") then
			child:SetAttribute("HookedV2", true)
			local stroke = child:FindFirstChild("SelectedStroke")
			if stroke and stroke:IsA("UIStroke") then
				stroke:GetPropertyChangedSignal("Transparency"):Connect(function()
					refreshTabs(modernRoot)
				end)
			end
			child.MouseButton1Click:Connect(function()
				task.defer(function()
					refreshTabs(modernRoot)
				end)
			end)
		end
	end
end

local function patchModernFishdex(modernRoot)
	patchBase(modernRoot)
	patchHeader(modernRoot)
	patchCards(modernRoot)
	patchCollection(modernRoot)
	refreshTabs(modernRoot)
	hookTabs(modernRoot)

	if not modernRoot:GetAttribute("RootPatchedV2") then
		modernRoot:SetAttribute("RootPatchedV2", true)
		modernRoot.ChildAdded:Connect(function()
			task.defer(function()
				patchHeader(modernRoot)
				patchCards(modernRoot)
				patchCollection(modernRoot)
				refreshTabs(modernRoot)
				hookTabs(modernRoot)
			end)
		end)
	end
end

local modernRoot = findModernFishdex()
if modernRoot then
	patchModernFishdex(modernRoot)
else
	fishingGui.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ImageLabel") and descendant.Name == "ModernFishdex" then
			task.defer(patchModernFishdex, descendant)
		end
	end)
end

print("[FishdexVisualPatch_REDESIGN_v2] Loaded.")
