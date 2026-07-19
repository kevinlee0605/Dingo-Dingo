-- IslandWarpModernClient
-- LocalScript location:
-- StarterGui > FishingGui > IslandWarpModernClient
--
-- This script creates the new Island Warp UI without replacing FishingClient.
-- It listens to the existing OpenBiomeWarp remote, uses the existing TeleportTo
-- remote for GO buttons, and permanently suppresses the old BiomeWarpOverlay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local screenGui = script.Parent

local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local OpenBiomeWarp = Remotes:WaitForChild("OpenBiomeWarp")
local TeleportTo = Remotes:WaitForChild("TeleportTo")

local ASSETS = {
	Backbone = "rbxassetid://139219110427433",
	LilyshoreIsland = "rbxassetid://94386681729236",
	RiverbendIsland = "rbxassetid://83913634264814",
	CoralCoastIsland = "rbxassetid://122703152321295",

	GoButton = "rbxassetid://111469265624538",
	TopLeftDecoration = "rbxassetid://81989089279793",
	CoinIcon = "rbxassetid://79109082679955",
	IslandCardBlank = "rbxassetid://135395684428311",
	CloseButton = "rbxassetid://94429518283822",

	ComingSoonIsland = "rbxassetid://97504855517031",
}

-- =========================
-- EASY UI TUNING VALUES
-- =========================

local BASE_WIDTH = 1211
local BASE_HEIGHT = 1299
local ISLAND_WARP_UI_SIZE_MULTIPLIER = 0.70

local ROOT_X = 0.5
local ROOT_Y = 0.4

-- Manual scrolling backup.
-- Increase SCROLL_WHEEL_STEP if one wheel movement should scroll farther.
local SCROLL_WHEEL_STEP = 135

local HEADER_TITLE_X = 200
local HEADER_TITLE_Y = 52
local HEADER_TITLE_WIDTH = 720
local HEADER_TITLE_HEIGHT = 100
local HEADER_TITLE_TEXT_SIZE = 70

local SCROLL_X = 43
local SCROLL_Y = 176
local SCROLL_WIDTH = 1125
local SCROLL_HEIGHT = 1060

local CARD_WIDTH = 1090
local CARD_HEIGHT = 300
local CARD_GAP = 26

local ISLAND_ICON_X = 18
local ISLAND_ICON_Y = 18
local ISLAND_ICON_WIDTH = 285
local ISLAND_ICON_HEIGHT = 258

local ISLAND_TITLE_X = 310
local ISLAND_TITLE_Y = 50
local ISLAND_TITLE_WIDTH = 490
local ISLAND_TITLE_HEIGHT = 70
local ISLAND_TITLE_TEXT_SIZE = 49

local REQUIREMENT_X = 315
local REQUIREMENT_Y = 142
local REQUIREMENT_TEXT_SIZE = 31

local GO_BUTTON_X = 790
local GO_BUTTON_Y = 74
local GO_BUTTON_WIDTH = 260
local GO_BUTTON_HEIGHT = 158
local GO_TEXT_SIZE = 57

-- Source image sizes and transparent-content crops.
local SOURCE_1211 = Vector2.new(1211, 1299)
local SOURCE_CLOSE = Vector2.new(1187, 1326)
local SOURCE_CARD = Vector2.new(1200, 420)

local CROPS = {
	LilyshoreIsland = {
		source = SOURCE_1211,
		offset = Vector2.new(462, 552),
		size = Vector2.new(254, 247),
	},
	RiverbendIsland = {
		source = SOURCE_1211,
		offset = Vector2.new(443, 527),
		size = Vector2.new(264, 237),
	},
	CoralCoastIsland = {
		source = SOURCE_1211,
		offset = Vector2.new(477, 515),
		size = Vector2.new(260, 268),
	},
	GoButton = {
		source = SOURCE_1211,
		offset = Vector2.new(459, 536),
		size = Vector2.new(279, 172),
	},
	TopLeftDecoration = {
		source = SOURCE_1211,
		offset = Vector2.new(534, 609),
		size = Vector2.new(139, 115),
	},
	CloseButton = {
		source = SOURCE_CLOSE,
		offset = Vector2.new(375, 422),
		size = Vector2.new(427, 439),
	},
	IslandCardBlank = {
		source = SOURCE_CARD,
		offset = Vector2.new(35, 56),
		size = Vector2.new(1130, 308),
	},
	ComingSoonIsland = {
		source = SOURCE_1211,
		offset = Vector2.new(345, 448),
		size = Vector2.new(473, 417),
	},
}

local ISLANDS = {
	{
		id = "LilyshoreIsland",
		title = "Lilyshore Island",
		iconKey = "LilyshoreIsland",
		level = nil,
		coins = nil,
	},
	{
		id = "RiverbendIsland",
		title = "Riverbend Island",
		iconKey = "RiverbendIsland",
		level = 10,
		coins = 5000,
	},
	{
		id = "CoralCoastIsland",
		title = "Coral Coast Island",
		iconKey = "CoralCoastIsland",
		level = 25,
		coins = 50000,
	},
}

local function addCorner(guiObject, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = guiObject
	return corner
end

local function makeText(parent, name, text, textSize, color, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font or Enum.Font.FredokaOne
	label.Text = text or ""
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextSize = textSize or 24
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.ZIndex = 205
	label.Parent = parent
	return label
end

local function makeCroppedArtwork(parent, imageId, crop, zIndex)
	local image = Instance.new("ImageLabel")
	image.Name = "Artwork"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = imageId
	image.ScaleType = Enum.ScaleType.Stretch
	image.ZIndex = zIndex or 200
	image.Parent = parent

	if crop then
		image.Position = UDim2.fromScale(
			-crop.offset.X / crop.size.X,
			-crop.offset.Y / crop.size.Y
		)
		image.Size = UDim2.fromScale(
			crop.source.X / crop.size.X,
			crop.source.Y / crop.size.Y
		)
	else
		image.Position = UDim2.fromScale(0, 0)
		image.Size = UDim2.fromScale(1, 1)
	end

	return image
end

local function makeImageHolder(parent, name, imageId, position, size, crop, zIndex)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Position = position
	holder.Size = size
	holder.ClipsDescendants = crop ~= nil
	holder.ZIndex = zIndex or 200
	holder.Parent = parent

	makeCroppedArtwork(holder, imageId, crop, zIndex)
	return holder
end

local function makeImageButton(parent, name, imageId, position, size, crop, zIndex)
	local button = Instance.new("ImageButton")
	button.Name = name
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.Image = ""
	button.AutoButtonColor = false
	button.ClipsDescendants = crop ~= nil
	button.ZIndex = zIndex or 205
	button.Parent = parent

	makeCroppedArtwork(button, imageId, crop, zIndex)
	return button
end

local function addPressFeedback(button)
	local artwork = button:FindFirstChild("Artwork")
	local originalPosition = button.Position
	local originalSize = button.Size

	local pressedPosition = UDim2.new(
		originalPosition.X.Scale,
		originalPosition.X.Offset + 4,
		originalPosition.Y.Scale,
		originalPosition.Y.Offset + 4
	)

	local pressedSize = UDim2.new(
		originalSize.X.Scale,
		originalSize.X.Offset - 8,
		originalSize.Y.Scale,
		originalSize.Y.Offset - 8
	)

	local currentButtonTween
	local currentArtworkTween

	local function setPressed(pressed)
		if currentButtonTween then
			currentButtonTween:Cancel()
		end
		if currentArtworkTween then
			currentArtworkTween:Cancel()
		end

		currentButtonTween = TweenService:Create(
			button,
			TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = pressed and pressedPosition or originalPosition,
				Size = pressed and pressedSize or originalSize,
			}
		)
		currentButtonTween:Play()

		if artwork then
			currentArtworkTween = TweenService:Create(
				artwork,
				TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					ImageTransparency = pressed and 0.16 or 0,
				}
			)
			currentArtworkTween:Play()
		end
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			setPressed(true)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			setPressed(false)
		end
	end)

	button.MouseLeave:Connect(function()
		setPressed(false)
	end)
end

-- Permanently suppress the old Island Warp overlay.
local legacyConnections = {}

local function suppressLegacyOverlay(instance)
	if not instance or instance.Name ~= "BiomeWarpOverlay" then
		return
	end
	if not instance:IsA("GuiObject") then
		return
	end

	instance.Visible = false

	if not legacyConnections[instance] then
		legacyConnections[instance] = instance:GetPropertyChangedSignal("Visible"):Connect(function()
			if instance.Parent and instance.Visible then
				instance.Visible = false
			end
		end)
	end
end

for _, descendant in ipairs(screenGui:GetDescendants()) do
	suppressLegacyOverlay(descendant)
end

screenGui.DescendantAdded:Connect(function(descendant)
	task.defer(suppressLegacyOverlay, descendant)
end)

-- Root UI
local root = Instance.new("ImageLabel")
root.Name = "ModernIslandWarp"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(ROOT_X, ROOT_Y)
root.Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)
root.BackgroundTransparency = 1
root.BorderSizePixel = 0
root.Image = ASSETS.Backbone
root.ScaleType = Enum.ScaleType.Stretch
root.Visible = false
root.ZIndex = 300
root.Parent = screenGui

local uiScale = Instance.new("UIScale")
uiScale.Name = "ResponsiveScale"
uiScale.Parent = root

local function updateResponsiveScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)

	local fit = math.min(
		(viewport.X * 0.97) / BASE_WIDTH,
		(viewport.Y * 0.95) / BASE_HEIGHT
	)

	uiScale.Scale = math.clamp(
		fit * ISLAND_WARP_UI_SIZE_MULTIPLIER,
		0.28,
		1
	)
end

updateResponsiveScale()

local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
end

local topDecoration = makeImageHolder(
	root,
	"TopLeftDecoration",
	ASSETS.TopLeftDecoration,
	UDim2.fromOffset(35, 31),
	UDim2.fromOffset(155, 128),
	CROPS.TopLeftDecoration,
	304
)

local title = makeText(
	root,
	"Title",
	"ISLAND WARP",
	HEADER_TITLE_TEXT_SIZE,
	Color3.fromRGB(255, 255, 255)
)
title.Position = UDim2.fromOffset(HEADER_TITLE_X, HEADER_TITLE_Y)
title.Size = UDim2.fromOffset(HEADER_TITLE_WIDTH, HEADER_TITLE_HEIGHT)
title.ZIndex = 304

local closeButton = makeImageButton(
	root,
	"CloseButton",
	ASSETS.CloseButton,
	UDim2.fromOffset(1052, 38),
	UDim2.fromOffset(108, 108),
	CROPS.CloseButton,
	310
)
addPressFeedback(closeButton)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "IslandList"
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.fromOffset(SCROLL_X, SCROLL_Y)
scroll.Size = UDim2.fromOffset(SCROLL_WIDTH, SCROLL_HEIGHT)
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
scroll.Active = true
scroll.ScrollingEnabled = true
scroll.Selectable = true
scroll.ScrollBarThickness = 8
scroll.ScrollBarImageColor3 = Color3.fromRGB(33, 137, 255)
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
scroll.ClipsDescendants = true
scroll.ZIndex = 302
scroll.Parent = root

local listHolder = Instance.new("Frame")
listHolder.Name = "Cards"
listHolder.BackgroundTransparency = 1
listHolder.Size = UDim2.new(1, -16, 0, 0)
listHolder.AutomaticSize = Enum.AutomaticSize.None
listHolder.ZIndex = 302
listHolder.Parent = scroll

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, CARD_GAP)
layout.Parent = listHolder

local function updateScrollCanvas()
	task.defer(function()
		-- Three real islands + one Coming Soon card.
		-- Use an explicit height so scrolling does not depend on
		-- UIListLayout resolving while the UI is still invisible.
		local cardCount = #ISLANDS + 1
		local contentHeight = (cardCount * CARD_HEIGHT)
			+ ((cardCount - 1) * CARD_GAP)
			+ 24

		listHolder.Size = UDim2.new(
			1,
			-16,
			0,
			contentHeight
		)

		scroll.CanvasSize = UDim2.fromOffset(
			0,
			contentHeight
		)
	end)
end

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(
	updateScrollCanvas
)

local function isPointInside(guiObject, point)
	local position = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize

	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

local function setCanvasY(newY)
	local maxY = math.max(
		0,
		scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y
	)

	scroll.CanvasPosition = Vector2.new(
		0,
		math.clamp(newY, 0, maxY)
	)
end

-- Native ScrollingFrame input can be blocked by overlapping GUI elements.
-- This mouse-wheel handler guarantees scrolling whenever the cursor is
-- over the island list.
UserInputService.InputChanged:Connect(function(input)
	if not root.Visible then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseWheel then
		return
	end

	local mousePosition = UserInputService:GetMouseLocation()
	if not isPointInside(scroll, mousePosition) then
		return
	end

	setCanvasY(
		scroll.CanvasPosition.Y
		- (input.Position.Z * SCROLL_WHEEL_STEP)
	)
end)

-- Touch-drag backup for phones and tablets.
local activeTouch = nil
local previousTouchY = 0

scroll.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		activeTouch = input
		previousTouchY = input.Position.Y
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input ~= activeTouch then
		return
	end

	local deltaY = input.Position.Y - previousTouchY
	previousTouchY = input.Position.Y
	setCanvasY(scroll.CanvasPosition.Y - deltaY)
end)

UserInputService.InputEnded:Connect(function(input)
	if input == activeTouch then
		activeTouch = nil
	end
end)

local function makeRequirement(card, island)
	if not island.level then
		local prefix = makeText(
			card,
			"RequirementLabel",
			"Requirement:",
			REQUIREMENT_TEXT_SIZE,
			Color3.fromRGB(172, 200, 255)
		)
		prefix.Position = UDim2.fromOffset(REQUIREMENT_X, REQUIREMENT_Y)
		prefix.Size = UDim2.fromOffset(235, 50)
		prefix.ZIndex = 307

		local free = makeText(
			card,
			"RequirementValue",
			"Free",
			REQUIREMENT_TEXT_SIZE,
			Color3.fromRGB(52, 231, 76)
		)
		free.Position = UDim2.fromOffset(REQUIREMENT_X + 180, REQUIREMENT_Y)
		free.Size = UDim2.fromOffset(220, 50)
		free.ZIndex = 307
		return
	end

	local levelText = makeText(
		card,
		"RequirementLabel",
		string.format("Requirement: Level %d +", island.level),
		REQUIREMENT_TEXT_SIZE,
		Color3.fromRGB(172, 200, 255)
	)
	levelText.Position = UDim2.fromOffset(REQUIREMENT_X, REQUIREMENT_Y - 16)
	levelText.Size = UDim2.fromOffset(480, 50)
	levelText.ZIndex = 307

	local coin = makeImageHolder(
		card,
		"CoinIcon",
		ASSETS.CoinIcon,
		UDim2.fromOffset(REQUIREMENT_X, REQUIREMENT_Y + 35),
		UDim2.fromOffset(58, 58),
		nil,
		307
	)

	local cost = makeText(
		card,
		"CoinRequirement",
		string.format("%s Coins", string.format("%d", island.coins):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")),
		34,
		Color3.fromRGB(255, 220, 31)
	)
	cost.Position = UDim2.fromOffset(REQUIREMENT_X + 68, REQUIREMENT_Y + 32)
	cost.Size = UDim2.fromOffset(380, 62)
	cost.ZIndex = 307
end

local function makeGoButton(card, islandId, enabled, labelText)
	local button = makeImageButton(
		card,
		"GoButton",
		ASSETS.GoButton,
		UDim2.fromOffset(GO_BUTTON_X, GO_BUTTON_Y),
		UDim2.fromOffset(GO_BUTTON_WIDTH, GO_BUTTON_HEIGHT),
		CROPS.GoButton,
		308
	)

	local buttonLabel = makeText(
		button,
		"Label",
		labelText or "GO",
		GO_TEXT_SIZE,
		Color3.fromRGB(255, 255, 255)
	)
	buttonLabel.Size = UDim2.fromScale(1, 1)
	buttonLabel.TextXAlignment = Enum.TextXAlignment.Center
	buttonLabel.ZIndex = 310

	if enabled then
		addPressFeedback(button)
		button.MouseButton1Click:Connect(function()
			root.Visible = false
			TeleportTo:FireServer(islandId)
		end)
	else
		button.Active = false
		button.Selectable = false
		local artwork = button:FindFirstChild("Artwork")
		if artwork then
			artwork.ImageColor3 = Color3.fromRGB(160, 175, 210)
		end
	end

	return button
end

local function makeIslandCard(island, layoutOrder)
	local card = makeImageHolder(
		listHolder,
		island.id .. "Card",
		ASSETS.IslandCardBlank,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
		CROPS.IslandCardBlank,
		303
	)
	card.LayoutOrder = layoutOrder

	makeImageHolder(
		card,
		"IslandIcon",
		ASSETS[island.iconKey],
		UDim2.fromOffset(
			ISLAND_ICON_X,
			ISLAND_ICON_Y
		),
		UDim2.fromOffset(
			ISLAND_ICON_WIDTH,
			ISLAND_ICON_HEIGHT
		),
		CROPS[island.iconKey],
		306
	)

	local islandTitle = makeText(
		card,
		"IslandTitle",
		island.title,
		ISLAND_TITLE_TEXT_SIZE,
		Color3.fromRGB(255, 255, 255)
	)
	islandTitle.Position = UDim2.fromOffset(
		ISLAND_TITLE_X,
		ISLAND_TITLE_Y
	)
	islandTitle.Size = UDim2.fromOffset(
		ISLAND_TITLE_WIDTH,
		ISLAND_TITLE_HEIGHT
	)
	islandTitle.ZIndex = 307

	makeRequirement(card, island)
	makeGoButton(card, island.id, true, "GO")

	return card
end

for index, island in ipairs(ISLANDS) do
	makeIslandCard(island, index)
end

-- Coming Soon card shown after scrolling down.
local comingCard = makeImageHolder(
	listHolder,
	"ComingSoonCard",
	ASSETS.IslandCardBlank,
	UDim2.fromOffset(0, 0),
	UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
	CROPS.IslandCardBlank,
	303
)
comingCard.LayoutOrder = #ISLANDS + 1

makeImageHolder(
	comingCard,
	"ComingSoonIsland",
	ASSETS.ComingSoonIsland,
	UDim2.fromOffset(8, 7),
	UDim2.fromOffset(300, 278),
	CROPS.ComingSoonIsland,
	306
)

local comingTitle = makeText(
	comingCard,
	"IslandTitle",
	"???",
	62,
	Color3.fromRGB(255, 255, 255)
)
comingTitle.Position = UDim2.fromOffset(ISLAND_TITLE_X, 43)
comingTitle.Size = UDim2.fromOffset(450, 82)
comingTitle.ZIndex = 307

local unavailable = makeText(
	comingCard,
	"Requirement",
	"Requirement: Unavailable",
	33,
	Color3.fromRGB(102, 200, 255)
)
unavailable.Position = UDim2.fromOffset(REQUIREMENT_X, 139)
unavailable.Size = UDim2.fromOffset(480, 58)
unavailable.ZIndex = 307

local comingDetail = makeText(
	comingCard,
	"Detail",
	"More islands on the way",
	31,
	Color3.fromRGB(255, 221, 35)
)
comingDetail.Position = UDim2.fromOffset(REQUIREMENT_X, 198)
comingDetail.Size = UDim2.fromOffset(470, 55)
comingDetail.ZIndex = 307

makeGoButton(comingCard, nil, false, "SOON")

updateScrollCanvas()

local function setVisible(visible)
	root.Visible = visible == true

	-- The old overlay must never remain visible behind the modern UI.
	for _, descendant in ipairs(screenGui:GetDescendants()) do
		suppressLegacyOverlay(descendant)
	end

	if visible then
		scroll.CanvasPosition = Vector2.new(0, 0)
		updateScrollCanvas()

		-- The legacy listener may run after this listener, so hide it again
		-- on the following frames.
		task.defer(function()
			for _, descendant in ipairs(screenGui:GetDescendants()) do
				suppressLegacyOverlay(descendant)
			end
		end)

		task.delay(0.08, function()
			for _, descendant in ipairs(screenGui:GetDescendants()) do
				suppressLegacyOverlay(descendant)
			end
		end)
	end
end

closeButton.MouseButton1Click:Connect(function()
	setVisible(false)
end)

OpenBiomeWarp.OnClientEvent:Connect(function()
	setVisible(true)
end)

print("[IslandWarpModernClient] Loaded.")
