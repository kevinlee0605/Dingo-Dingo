-- SeasideShopModernClient
-- Place this LocalScript at:
-- StarterGui > FishingGui > SeasideShopModernClient
--
-- Do not replace FishingClient or FishingServer.
-- This script listens to the existing OpenSellFish, SellFish,
-- StateUpdated, and GetState remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local screenGui = script:FindFirstAncestorOfClass("ScreenGui")

if not screenGui then
	error(
		"[SeasideShopModernClient] No ScreenGui ancestor found. "
			.. "Place this LocalScript inside StarterGui > FishingGui."
	)
end

local GameConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")
)

local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local OpenSellFish = Remotes:WaitForChild("OpenSellFish")
local SellFish = Remotes:WaitForChild("SellFish")
local StateUpdated = Remotes:WaitForChild("StateUpdated")
local GetState = Remotes:WaitForChild("GetState")

local ASSETS = {
	MainBackbone = "rbxassetid://77079984837491",
	Decoration = "rbxassetid://126541809567975",
	SelectedTab = "rbxassetid://135116059419917",
	UnselectedTab = "rbxassetid://104189399468619",
	SellAllButton = "rbxassetid://82571731099591",
	SellButton = "rbxassetid://87923116280754",
	SubMainBackbone = "rbxassetid://120182750042631",

	Rows = {
		Common = "rbxassetid://99716714580964",
		Uncommon = "rbxassetid://87915145459317",
		Rare = "rbxassetid://137344133997721",
		Epic = "rbxassetid://132952880657667",
		Legendary = "rbxassetid://90545223881408",
		Mythic = "rbxassetid://91583721145825",
	},

	ScrollThumb = "rbxassetid://73367138577137",
	CloseButton = "rbxassetid://119322438066977",
}

-- These Asset IDs were uploaded from large transparent canvases.
-- The visible artwork is mapped into each GUI slot using the exact source bounds.
local CROP = {
	MainBackbone = {
		source = Vector2.new(1448, 1086),

		-- Main Backbone(2).png has a small transparent margin.
		-- The visible artwork is approximately (33,24)-(1415,1043).
		-- Keep an 8px safety margin so all four corner glows remain clean.
		rect = Rect.new(25, 16, 1423, 1051),
	},
	Decoration = {
		source = Vector2.new(632, 432),
		rect = Rect.new(117, 97, 467, 355),
	},
	SelectedTab = {
		source = Vector2.new(632, 432),
		rect = Rect.new(50, 155, 548, 278),
	},
	UnselectedTab = {
		source = Vector2.new(1536, 1024),
		rect = Rect.new(205, 363, 1330, 656),
	},
	SellAllButton = {
		source = Vector2.new(632, 432),
		rect = Rect.new(63, 128, 559, 304),
	},
	SellButton = {
		source = Vector2.new(632, 432),
		rect = Rect.new(57, 145, 545, 294),
	},
	SubMainBackbone = {
		source = Vector2.new(1448, 1086),
		rect = Rect.new(43, 176, 1405, 939),
	},
	CommonRow = {
		source = Vector2.new(632, 432),
		rect = Rect.new(9, 188, 626, 272),
	},
	UncommonRow = {
		source = Vector2.new(632, 432),
		rect = Rect.new(9, 173, 626, 259),
	},
	RareRow = {
		source = Vector2.new(632, 432),
		rect = Rect.new(9, 174, 625, 259),
	},
	EpicRow = {
		source = Vector2.new(632, 432),
		rect = Rect.new(9, 174, 626, 259),
	},
	LegendaryRow = {
		source = Vector2.new(632, 432),
		rect = Rect.new(9, 174, 625, 258),
	},
	MythicRow = {
		source = Vector2.new(632, 432),
		rect = Rect.new(9, 174, 625, 259),
	},
	CloseButton = {
		source = Vector2.new(1187, 1326),
		rect = Rect.new(376, 422, 801, 859),
	},
}

-- =========================================================
-- EASY LAYOUT SETTINGS
-- =========================================================

local BASE_WIDTH = 1448
local BASE_HEIGHT = 1086

local UI_SIZE_MULTIPLIER = 0.7
local UI_X = 0.5
local UI_Y = 0.40

local TITLE_X = 245
local TITLE_Y = 30
local TITLE_WIDTH = 720
local TITLE_HEIGHT = 115
local TITLE_TEXT_SIZE = 72

local DECORATION_X = 48
local DECORATION_Y = 24
local DECORATION_WIDTH = 190
local DECORATION_HEIGHT = 145

local SELL_ALL_X = 995
local SELL_ALL_Y = 42
local SELL_ALL_WIDTH = 270
local SELL_ALL_HEIGHT = 104

local CLOSE_X = 1280
local CLOSE_Y = 38
local CLOSE_SIZE = 112

local TAB_Y = 158
local TAB_X = 72
local TAB_WIDTH = 370
local TAB_HEIGHT = 94
local TAB_GAP = 14

-- Matches the reference layout:
-- 54px inset from both Main Backbone sides, 235px below the top.
local SUB_PANEL_X = 54
local SUB_PANEL_Y = 235
local SUB_PANEL_WIDTH = 1340
local SUB_PANEL_HEIGHT = 810

local LIST_X = 72
local LIST_Y = 254
local LIST_WIDTH = 1238
local LIST_HEIGHT = 742

local ROW_WIDTH = 1228
local ROW_HEIGHT = 178
local ROW_GAP = 10

local FISH_ICON_X = 34
local FISH_ICON_Y = 18
local FISH_ICON_WIDTH = 155
local FISH_ICON_HEIGHT = 140

local FISH_NAME_X = 245
local FISH_NAME_Y = 25
local FISH_NAME_WIDTH = 650
local FISH_NAME_HEIGHT = 58

local FISH_VALUE_X = 245
local FISH_VALUE_Y = 88
local FISH_VALUE_WIDTH = 650
local FISH_VALUE_HEIGHT = 48

local SELL_BUTTON_X = 938
local SELL_BUTTON_Y = 43
local SELL_BUTTON_WIDTH = 244
local SELL_BUTTON_HEIGHT = 92

local SCROLL_TRACK_X = 1325
local SCROLL_TRACK_Y = 260
local SCROLL_TRACK_WIDTH = 28
local SCROLL_TRACK_HEIGHT = 742

-- =========================================================

local RARITY_RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
}

local FALLBACK_RARITY_COLORS = {
	Common = Color3.fromRGB(236, 242, 255),
	Uncommon = Color3.fromRGB(56, 235, 92),
	Rare = Color3.fromRGB(49, 157, 255),
	Epic = Color3.fromRGB(215, 88, 255),
	Legendary = Color3.fromRGB(255, 197, 35),
	Mythic = Color3.fromRGB(255, 70, 70),
}

local state = nil
local activeSortMode = "Rarity"
local sortDescending = true
local pendingSingleSales = {}
local sellAllPending = false
local setVisible

local function formatNumber(value)
	local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
	local result = text

	while true do
		local changed
		result, changed = result:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if changed == 0 then
			break
		end
	end

	return result
end

local function normalizeRarity(rarity)
	if rarity == "Mythical" then
		return "Mythic"
	end

	if RARITY_RANK[rarity] then
		return rarity
	end

	return "Common"
end

local function getRarityRank(rarity)
	return RARITY_RANK[normalizeRarity(rarity)] or 0
end

local function getRarityColor(rarity)
	rarity = normalizeRarity(rarity)

	local configured = GameConfig.RarityColors
		and GameConfig.RarityColors[rarity]

	return configured
		or FALLBACK_RARITY_COLORS[rarity]
		or Color3.new(1, 1, 1)
end

local function getFishImage(fish)
	local imageKey = fish and (fish.imageKey or fish.id or fish.name)
	local imageId

	if imageKey and GameConfig.getFishImage then
		imageId = GameConfig.getFishImage(imageKey)
	end

	return type(imageId) == "string" and imageId or ""
end

local function makeImage(
	parent,
	name,
	image,
	position,
	size,
	zIndex
)
	local object = Instance.new("ImageLabel")
	object.Name = name
	object.BackgroundTransparency = 1
	object.BorderSizePixel = 0
	object.Image = image
	object.Position = position
	object.Size = size
	object.ScaleType = Enum.ScaleType.Stretch
	object.ZIndex = zIndex
	object.Parent = parent
	return object
end

local function makeImageButton(
	parent,
	name,
	image,
	position,
	size,
	zIndex
)
	local button = Instance.new("ImageButton")
	button.Name = name
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Image = image
	button.Position = position
	button.Size = size
	button.ScaleType = Enum.ScaleType.Stretch
	button.AutoButtonColor = false
	button.ZIndex = zIndex
	button.Parent = parent
	return button
end

local function createMappedImageObject(
	parent,
	name,
	image,
	position,
	size,
	zIndex,
	crop,
	asButton
)
	local holder = Instance.new(asButton and "ImageButton" or "Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Position = position
	holder.Size = size
	holder.ClipsDescendants = true
	holder.ZIndex = zIndex
	holder.Parent = parent

	if asButton then
		holder.ImageTransparency = 1
		holder.AutoButtonColor = false
	end

	local source = crop.source
	local rect = crop.rect
	local rectWidth = rect.Max.X - rect.Min.X
	local rectHeight = rect.Max.Y - rect.Min.Y

	local targetWidth = size.X.Offset
	local targetHeight = size.Y.Offset

	local fullWidth = targetWidth * source.X / rectWidth
	local fullHeight = targetHeight * source.Y / rectHeight

	local imageObject = Instance.new("ImageLabel")
	imageObject.Name = "MappedImage"
	imageObject.BackgroundTransparency = 1
	imageObject.BorderSizePixel = 0
	imageObject.Image = image
	imageObject.Position = UDim2.fromOffset(
		-(rect.Min.X / source.X) * fullWidth,
		-(rect.Min.Y / source.Y) * fullHeight
	)
	imageObject.Size = UDim2.fromOffset(fullWidth, fullHeight)
	imageObject.ScaleType = Enum.ScaleType.Stretch
	imageObject.ZIndex = zIndex
	imageObject.Parent = holder

	return holder, imageObject
end

local function makeMappedImage(
	parent,
	name,
	image,
	position,
	size,
	zIndex,
	crop
)
	return createMappedImageObject(
		parent,
		name,
		image,
		position,
		size,
		zIndex,
		crop,
		false
	)
end

local function makeMappedButton(
	parent,
	name,
	image,
	position,
	size,
	zIndex,
	crop
)
	return createMappedImageObject(
		parent,
		name,
		image,
		position,
		size,
		zIndex,
		crop,
		true
	)
end

local function makeText(
	parent,
	name,
	text,
	textSize,
	color,
	font,
	zIndex
)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = text or ""
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextSize = textSize or 24
	label.Font = font or Enum.Font.FredokaOne
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.05
	label.ZIndex = zIndex or 610
	label.Parent = parent
	return label
end

local function addCorner(guiObject, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = guiObject
	return corner
end

local function addPressFeedback(button)
	local buttonScale = Instance.new("UIScale")
	buttonScale.Name = "PressScale"
	buttonScale.Scale = 1
	buttonScale.Parent = button

	local currentTween

	local function tweenTo(value)
		if currentTween then
			currentTween:Cancel()
		end

		currentTween = TweenService:Create(
			buttonScale,
			TweenInfo.new(
				0.08,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{ Scale = value }
		)
		currentTween:Play()
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tweenTo(0.95)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tweenTo(1)
		end
	end)

	button.MouseLeave:Connect(function()
		tweenTo(1)
	end)
end

local function pointInside(guiObject, point)
	if not guiObject or not guiObject.Visible then
		return false
	end

	local position = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize

	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

-- Remove an older copy if one is still present.
local oldRoot = screenGui:FindFirstChild("ModernSeasideShop")
if oldRoot then
	oldRoot:Destroy()
end

local root = Instance.new("Frame")
root.Name = "ModernSeasideShop"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(UI_X, UI_Y)
root.Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)
root.BackgroundTransparency = 1
root.BorderSizePixel = 0
root.ClipsDescendants = false
root.Visible = false
root.ZIndex = 600
root.Parent = screenGui

local responsiveScale = Instance.new("UIScale")
responsiveScale.Name = "ResponsiveScale"
responsiveScale.Parent = root

local function updateResponsiveScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize
		or Vector2.new(1920, 1080)

	local fit = math.min(
		(viewport.X * 0.98) / BASE_WIDTH,
		(viewport.Y * 0.98) / BASE_HEIGHT
	)

	responsiveScale.Scale = math.clamp(
		fit * UI_SIZE_MULTIPLIER,
		0.30,
		1
	)
end

updateResponsiveScale()

local currentCamera = workspace.CurrentCamera
if currentCamera then
	currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(
		updateResponsiveScale
	)
end

-- Expand the visible Main Backbone artwork to the full root while preserving
-- an 8px transparent safety margin around every edge. This makes the outer
-- frame line up with SubMainBackbone without cutting the corner glow.
local mainBackbone = makeMappedImage(
	root,
	"MainBackbone",
	ASSETS.MainBackbone,
	UDim2.fromOffset(0, 0),
	UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT),
	600,
	CROP.MainBackbone
)

makeMappedImage(
	root,
	"Decoration",
	ASSETS.Decoration,
	UDim2.fromOffset(DECORATION_X, DECORATION_Y),
	UDim2.fromOffset(DECORATION_WIDTH, DECORATION_HEIGHT),
	605,
	CROP.Decoration
)

local title = makeText(
	root,
	"Title",
	"SEASIDE SHOP",
	TITLE_TEXT_SIZE,
	Color3.fromRGB(255, 255, 255),
	Enum.Font.GothamBlack,
	606
)
title.Position = UDim2.fromOffset(TITLE_X, TITLE_Y)
title.Size = UDim2.fromOffset(TITLE_WIDTH, TITLE_HEIGHT)

local sellAllButton = makeMappedButton(
	root,
	"SellAllButton",
	ASSETS.SellAllButton,
	UDim2.fromOffset(SELL_ALL_X, SELL_ALL_Y),
	UDim2.fromOffset(SELL_ALL_WIDTH, SELL_ALL_HEIGHT),
	620,
	CROP.SellAllButton
)
addPressFeedback(sellAllButton)

local sellAllText = makeText(
	sellAllButton,
	"Label",
	"Sell All",
	41,
	Color3.fromRGB(255, 255, 255),
	Enum.Font.FredokaOne,
	621
)
sellAllText.Size = UDim2.fromScale(1, 1)
sellAllText.TextXAlignment = Enum.TextXAlignment.Center

local closeButton = makeMappedButton(
	root,
	"CloseButton",
	ASSETS.CloseButton,
	UDim2.fromOffset(CLOSE_X, CLOSE_Y),
	UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
	625,
	CROP.CloseButton
)
addPressFeedback(closeButton)

local tabHolder = Instance.new("Frame")
tabHolder.Name = "SortTabs"
tabHolder.BackgroundTransparency = 1
tabHolder.BorderSizePixel = 0
tabHolder.Position = UDim2.fromOffset(TAB_X, TAB_Y)
tabHolder.Size = UDim2.fromOffset(
	(TAB_WIDTH * 2) + TAB_GAP,
	TAB_HEIGHT
)
tabHolder.ZIndex = 610
tabHolder.Parent = root

local subMain = makeMappedImage(
	root,
	"SubMainBackbone",
	ASSETS.SubMainBackbone,
	UDim2.fromOffset(SUB_PANEL_X, SUB_PANEL_Y),
	UDim2.fromOffset(SUB_PANEL_WIDTH, SUB_PANEL_HEIGHT),
	608,
	CROP.SubMainBackbone
)

-- Rectangular safe area inside SubMainBackbone.
-- Rows and the custom scrollbar are clipped here, so nothing can protrude
-- through the right or bottom edge of the inner panel.
local subContentClip = Instance.new("Frame")
subContentClip.Name = "SubContentClip"
subContentClip.BackgroundTransparency = 1
subContentClip.BorderSizePixel = 0
subContentClip.Position = UDim2.fromOffset(
	SUB_PANEL_X + 8,
	SUB_PANEL_Y + 8
)
subContentClip.Size = UDim2.fromOffset(
	SUB_PANEL_WIDTH - 16,
	SUB_PANEL_HEIGHT - 16
)
subContentClip.ClipsDescendants = true
subContentClip.ZIndex = 611
subContentClip.Parent = root

local list = Instance.new("ScrollingFrame")
list.Name = "FishList"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(
	LIST_X - (SUB_PANEL_X + 8),
	LIST_Y - (SUB_PANEL_Y + 8)
)
list.Size = UDim2.fromOffset(LIST_WIDTH, LIST_HEIGHT)
list.CanvasSize = UDim2.fromOffset(0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.None
list.Active = true
list.ScrollingEnabled = true
list.ScrollingDirection = Enum.ScrollingDirection.Y

-- Completely hide Roblox's built-in white scrollbar.
-- The custom blue scrollbar below is the only scrollbar that should render.
list.ScrollBarThickness = 0
list.ScrollBarImageTransparency = 1
list.ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0)

list.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
list.ClipsDescendants = true
list.ZIndex = 612
list.Parent = subContentClip

local function forceNativeScrollbarHidden()
	if list.ScrollBarThickness ~= 0 then
		list.ScrollBarThickness = 0
	end

	if list.ScrollBarImageTransparency ~= 1 then
		list.ScrollBarImageTransparency = 1
	end
end

forceNativeScrollbarHidden()

list:GetPropertyChangedSignal("ScrollBarThickness"):Connect(
	forceNativeScrollbarHidden
)
list:GetPropertyChangedSignal("ScrollBarImageTransparency"):Connect(
	forceNativeScrollbarHidden
)

local listLayout = Instance.new("UIListLayout")
listLayout.Name = "ListLayout"
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, ROW_GAP)
listLayout.Parent = list

local scrollTrack = Instance.new("Frame")
scrollTrack.Name = "ScrollTrack"
scrollTrack.BackgroundColor3 = Color3.fromRGB(1, 17, 50)
scrollTrack.BackgroundTransparency = 0.04
scrollTrack.BorderSizePixel = 0
scrollTrack.Position = UDim2.fromOffset(
	SCROLL_TRACK_X - (SUB_PANEL_X + 8),
	SCROLL_TRACK_Y - (SUB_PANEL_Y + 8)
)
scrollTrack.Size = UDim2.fromOffset(
	SCROLL_TRACK_WIDTH,
	SCROLL_TRACK_HEIGHT
)
scrollTrack.Active = true
scrollTrack.ZIndex = 616
scrollTrack.Parent = subContentClip
addCorner(scrollTrack, SCROLL_TRACK_WIDTH)

local trackStroke = Instance.new("UIStroke")
trackStroke.Color = Color3.fromRGB(0, 102, 255)
trackStroke.Thickness = 2
trackStroke.Transparency = 0.02
trackStroke.Parent = scrollTrack

-- Code-drawn blue thumb guarantees visibility even if the uploaded image
-- is delayed, resized by Roblox, or unavailable on a specific client.
local scrollThumb = Instance.new("TextButton")
scrollThumb.Name = "ScrollThumb"
scrollThumb.Text = ""
scrollThumb.AutoButtonColor = false
scrollThumb.BackgroundColor3 = Color3.fromRGB(0, 92, 255)
scrollThumb.BackgroundTransparency = 0
scrollThumb.BorderSizePixel = 0
scrollThumb.Position = UDim2.fromOffset(2, 0)
scrollThumb.Size = UDim2.fromOffset(
	SCROLL_TRACK_WIDTH - 4,
	180
)
scrollThumb.Active = true
scrollThumb.Selectable = false
scrollThumb.ZIndex = 618
scrollThumb.Parent = scrollTrack

local thumbCorner = Instance.new("UICorner")
thumbCorner.CornerRadius = UDim.new(1, 0)
thumbCorner.Parent = scrollThumb

local thumbGradient = Instance.new("UIGradient")
thumbGradient.Rotation = 90
thumbGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(
		0,
		Color3.fromRGB(0, 213, 255)
	),
	ColorSequenceKeypoint.new(
		0.32,
		Color3.fromRGB(0, 130, 255)
	),
	ColorSequenceKeypoint.new(
		1,
		Color3.fromRGB(0, 48, 210)
	),
})
thumbGradient.Parent = scrollThumb

local thumbStroke = Instance.new("UIStroke")
thumbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
thumbStroke.Color = Color3.fromRGB(0, 220, 255)
thumbStroke.Thickness = 2
thumbStroke.Transparency = 0.05
thumbStroke.Parent = scrollThumb

-- Optional texture overlay from the supplied ScrollThumb asset.
-- The solid blue background above remains visible as a fallback.
local thumbTexture = Instance.new("ImageLabel")
thumbTexture.Name = "Texture"
thumbTexture.BackgroundTransparency = 1
thumbTexture.BorderSizePixel = 0
thumbTexture.Image = ASSETS.ScrollThumb
thumbTexture.ImageTransparency = 0
thumbTexture.Position = UDim2.fromScale(0, 0)
thumbTexture.Size = UDim2.fromScale(1, 1)
thumbTexture.ScaleType = Enum.ScaleType.Slice
thumbTexture.SliceCenter = Rect.new(8, 90, 28, 717)
thumbTexture.SliceScale = 1
thumbTexture.ZIndex = 619
thumbTexture.Parent = scrollThumb

local function clearList()
	for _, child in ipairs(list:GetChildren()) do
		if child ~= listLayout then
			child:Destroy()
		end
	end
end

local function getLogicalScale()
	return math.max(0.001, responsiveScale.Scale)
end

local function getViewportHeight()
	-- AbsoluteWindowSize is screen-scaled; CanvasSize and CanvasPosition use
	-- the unscaled UI coordinate system. Convert the viewport back to logical
	-- units before comparing them.
	return math.max(
		1,
		list.AbsoluteWindowSize.Y / getLogicalScale()
	)
end

local function getContentHeight()
	return math.max(
		list.CanvasSize.Y.Offset,
		listLayout.AbsoluteContentSize.Y
			/ getLogicalScale()
	)
end

local function getMaxCanvasY()
	return math.max(
		0,
		getContentHeight() - getViewportHeight()
	)
end

local function setCanvasY(value)
	list.CanvasPosition = Vector2.new(
		0,
		math.clamp(value, 0, getMaxCanvasY())
	)
end

local function updateScrollbar()
	forceNativeScrollbarHidden()

	local contentHeight = getContentHeight()
	local viewportHeight = getViewportHeight()
	local trackHeight = SCROLL_TRACK_HEIGHT
	local maxCanvas = math.max(
		0,
		contentHeight - viewportHeight
	)
	local isScrollable = maxCanvas > 1

	scrollTrack.Visible = isScrollable
	scrollThumb.Visible = isScrollable
	scrollThumb.Active = isScrollable

	if not isScrollable then
		scrollThumb.Position = UDim2.fromOffset(2, 0)
		scrollThumb.Size = UDim2.fromOffset(
			SCROLL_TRACK_WIDTH - 4,
			trackHeight
		)
		return
	end

	local visibleRatio = math.clamp(
		viewportHeight / math.max(1, contentHeight),
		0.12,
		1
	)
	local thumbHeight = math.clamp(
		math.floor(trackHeight * visibleRatio + 0.5),
		92,
		trackHeight
	)
	local maxTravel = math.max(
		0,
		trackHeight - thumbHeight
	)
	local scrollRatio = math.clamp(
		list.CanvasPosition.Y / math.max(1, maxCanvas),
		0,
		1
	)

	scrollThumb.Size = UDim2.fromOffset(
		SCROLL_TRACK_WIDTH - 4,
		thumbHeight
	)
	scrollThumb.Position = UDim2.fromOffset(
		2,
		math.floor(maxTravel * scrollRatio + 0.5)
	)
end

local function scheduleScrollbarUpdate()
	task.defer(updateScrollbar)
	task.delay(0.05, updateScrollbar)
	task.delay(0.15, updateScrollbar)
end

list:GetPropertyChangedSignal("CanvasPosition"):Connect(updateScrollbar)
list:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(
	scheduleScrollbarUpdate
)
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(
	scheduleScrollbarUpdate
)
responsiveScale:GetPropertyChangedSignal("Scale"):Connect(
	scheduleScrollbarUpdate
)

local thumbDragging = false
local thumbDragInput = nil
local thumbStartScreenY = 0
local thumbStartCanvasY = 0

scrollThumb.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		thumbDragging = true
		thumbDragInput = input
		thumbStartScreenY = input.Position.Y
		thumbStartCanvasY = list.CanvasPosition.Y
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not thumbDragging then
		return
	end

	local currentY

	if thumbDragInput
		and thumbDragInput.UserInputType == Enum.UserInputType.Touch
	then
		if input ~= thumbDragInput then
			return
		end
		currentY = input.Position.Y
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then
		currentY = input.Position.Y
	end

	if not currentY then
		return
	end

	local logicalScale = getLogicalScale()
	local trackHeight = SCROLL_TRACK_HEIGHT
	local thumbHeight = scrollThumb.Size.Y.Offset
	local maxTravel = math.max(
		1,
		trackHeight - thumbHeight
	)
	local deltaLogical =
		(currentY - thumbStartScreenY) / logicalScale

	setCanvasY(
		thumbStartCanvasY
			+ (
				(deltaLogical / maxTravel)
				* getMaxCanvasY()
			)
	)
end)

UserInputService.InputEnded:Connect(function(input)
	if input == thumbDragInput
		or input.UserInputType == Enum.UserInputType.MouseButton1
	then
		thumbDragging = false
		thumbDragInput = nil
	end
end)

scrollTrack.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch
	then
		return
	end

	if pointInside(scrollThumb, input.Position) then
		return
	end

	local relativeY = math.clamp(
		(
			input.Position.Y
			- scrollTrack.AbsolutePosition.Y
		) / getLogicalScale(),
		0,
		SCROLL_TRACK_HEIGHT
	)
	local ratio =
		relativeY / math.max(1, SCROLL_TRACK_HEIGHT)

	setCanvasY(getMaxCanvasY() * ratio)
end)

local render

local function createSortTab(mode, x)
	local selected = activeSortMode == mode
	local image = selected
		and ASSETS.SelectedTab
		or ASSETS.UnselectedTab

	local button = makeMappedButton(
		tabHolder,
		mode .. "Tab",
		image,
		UDim2.fromOffset(x, 0),
		UDim2.fromOffset(TAB_WIDTH, TAB_HEIGHT),
		615,
		selected and CROP.SelectedTab or CROP.UnselectedTab
	)
	addPressFeedback(button)

	local labelText = mode

	if selected then
		labelText = mode
			.. ": "
			.. (sortDescending and "High" or "Low")
	end

	local label = makeText(
		button,
		"Label",
		labelText,
		selected and 36 or 39,
		Color3.fromRGB(255, 255, 255),
		Enum.Font.FredokaOne,
		617
	)
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center

	button.Activated:Connect(function()
		if activeSortMode == mode then
			sortDescending = not sortDescending
		else
			activeSortMode = mode
			sortDescending = true
		end

		list.CanvasPosition = Vector2.new(0, 0)
		render()
	end)
end

local function renderTabs()
	for _, child in ipairs(tabHolder:GetChildren()) do
		child:Destroy()
	end

	createSortTab("Rarity", 0)
	createSortTab("Value", TAB_WIDTH + TAB_GAP)
end

local function makeRow(entry, layoutOrder)
	local fish = entry.fish
	local rarity = normalizeRarity(fish.rarity)
	local rowAsset = ASSETS.Rows[rarity] or ASSETS.Rows.Common
	local rowCrop = CROP[rarity .. "Row"] or CROP.CommonRow

	local row = makeMappedImage(
		list,
		"FishRow_" .. tostring(fish.serial or entry.index),
		rowAsset,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(ROW_WIDTH, ROW_HEIGHT),
		614,
		rowCrop
	)
	row.LayoutOrder = layoutOrder

	local fishImageId = getFishImage(fish)

	if fishImageId ~= "" then
		local icon = makeImage(
			row,
			"FishIcon",
			fishImageId,
			UDim2.fromOffset(FISH_ICON_X, FISH_ICON_Y),
			UDim2.fromOffset(FISH_ICON_WIDTH, FISH_ICON_HEIGHT),
			617
		)
		icon.ScaleType = Enum.ScaleType.Fit
	else
		local fallback = makeText(
			row,
			"MissingFishIcon",
			"FISH",
			29,
			Color3.fromRGB(210, 230, 255),
			Enum.Font.GothamBold,
			617
		)
		fallback.Position = UDim2.fromOffset(
			FISH_ICON_X,
			FISH_ICON_Y
		)
		fallback.Size = UDim2.fromOffset(
			FISH_ICON_WIDTH,
			FISH_ICON_HEIGHT
		)
		fallback.TextXAlignment = Enum.TextXAlignment.Center
	end

	local rarityColor = getRarityColor(rarity)
	local fishName = tostring(fish.name or fish.id or "Fish")

	local name = makeText(
		row,
		"FishName",
		fishName .. " [" .. rarity .. "]",
		42,
		rarityColor,
		Enum.Font.GothamBlack,
		618
	)
	name.Position = UDim2.fromOffset(FISH_NAME_X, FISH_NAME_Y)
	name.Size = UDim2.fromOffset(
		FISH_NAME_WIDTH,
		FISH_NAME_HEIGHT
	)

	local value = makeText(
		row,
		"FishValue",
		"Sell value: "
			.. formatNumber(fish.value)
			.. " coins",
		31,
		Color3.fromRGB(167, 198, 255),
		Enum.Font.GothamMedium,
		618
	)
	value.Position = UDim2.fromOffset(FISH_VALUE_X, FISH_VALUE_Y)
	value.Size = UDim2.fromOffset(
		FISH_VALUE_WIDTH,
		FISH_VALUE_HEIGHT
	)
	value.TextStrokeTransparency = 0.65

	local sellButton = makeMappedButton(
		row,
		"SellButton",
		ASSETS.SellButton,
		UDim2.fromOffset(SELL_BUTTON_X, SELL_BUTTON_Y),
		UDim2.fromOffset(
			SELL_BUTTON_WIDTH,
			SELL_BUTTON_HEIGHT
		),
		620,
		CROP.SellButton
	)
	addPressFeedback(sellButton)

	local sellText = makeText(
		sellButton,
		"Label",
		"Sell",
		43,
		Color3.fromRGB(255, 255, 255),
		Enum.Font.FredokaOne,
		621
	)
	sellText.Size = UDim2.fromScale(1, 1)
	sellText.TextXAlignment = Enum.TextXAlignment.Center

	local pendingKey = tostring(fish.serial or entry.index)
	local pending = pendingSingleSales[pendingKey] == true
	sellButton.Active = not pending
	sellButton.Selectable = not pending
	sellButton.ImageTransparency = pending and 0.35 or 0
	sellText.Text = pending and "Selling..." or "Sell"
	sellText.TextTransparency = pending and 0.2 or 0

	sellButton.Activated:Connect(function()
		if pendingSingleSales[pendingKey] then
			return
		end

		pendingSingleSales[pendingKey] = true
		sellButton.Active = false
		sellButton.Selectable = false
		sellButton.ImageTransparency = 0.35
		sellText.Text = "Selling..."

		SellFish:FireServer(
			"Single",
			fish.serial,
			entry.index
		)

		task.delay(4, function()
			if pendingSingleSales[pendingKey] then
				pendingSingleSales[pendingKey] = nil
				if root.Visible then
					render()
				end
			end
		end)
	end)
end

local function getSortedEntries()
	local entries = {}

	if not state or type(state.Inventory) ~= "table" then
		return entries
	end

	for index, fish in ipairs(state.Inventory) do
		table.insert(entries, {
			fish = fish,
			index = index,
		})
	end

	table.sort(entries, function(left, right)
		local leftFish = left.fish
		local rightFish = right.fish
		local leftRank = getRarityRank(leftFish.rarity)
		local rightRank = getRarityRank(rightFish.rarity)
		local leftValue = tonumber(leftFish.value) or 0
		local rightValue = tonumber(rightFish.value) or 0

		if activeSortMode == "Rarity" then
			if leftRank ~= rightRank then
				if sortDescending then
					return leftRank > rightRank
				end
				return leftRank < rightRank
			end

			if leftValue ~= rightValue then
				if sortDescending then
					return leftValue > rightValue
				end
				return leftValue < rightValue
			end
		else
			if leftValue ~= rightValue then
				if sortDescending then
					return leftValue > rightValue
				end
				return leftValue < rightValue
			end

			if leftRank ~= rightRank then
				if sortDescending then
					return leftRank > rightRank
				end
				return leftRank < rightRank
			end
		end

		local leftSerial = tonumber(leftFish.serial) or left.index
		local rightSerial = tonumber(rightFish.serial) or right.index

		if sortDescending then
			return leftSerial > rightSerial
		end

		return leftSerial < rightSerial
	end)

	return entries
end

local function updateSellAllState()
	local hasFish = state
		and type(state.Inventory) == "table"
		and #state.Inventory > 0

	local enabled = hasFish and not sellAllPending

	sellAllButton.Active = enabled
	sellAllButton.Selectable = enabled
	sellAllButton.ImageTransparency = enabled and 0 or 0.38
	sellAllText.TextTransparency = enabled and 0 or 0.2
	sellAllText.Text = sellAllPending and "Selling..." or "Sell All"
end

render = function()
	local oldCanvasY = list.CanvasPosition.Y

	renderTabs()
	clearList()
	updateSellAllState()

	if not state then
		local loading = makeText(
			list,
			"Loading",
			"Loading fish...",
			42,
			Color3.fromRGB(255, 255, 255),
			Enum.Font.GothamBlack,
			616
		)
		loading.Size = UDim2.fromOffset(ROW_WIDTH, 140)
		loading.TextXAlignment = Enum.TextXAlignment.Center
		loading.LayoutOrder = 1
		list.CanvasSize = UDim2.fromOffset(0, 140)
		scheduleScrollbarUpdate()
		return
	end

	local entries = getSortedEntries()

	if #entries == 0 then
		local empty = makeText(
			list,
			"Empty",
			"No fish in your bag.",
			42,
			Color3.fromRGB(190, 210, 240),
			Enum.Font.GothamBlack,
			616
		)
		empty.Size = UDim2.fromOffset(ROW_WIDTH, 150)
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty.LayoutOrder = 1

		list.CanvasSize = UDim2.fromOffset(0, 150)
		list.CanvasPosition = Vector2.new(0, 0)
		scheduleScrollbarUpdate()
		return
	end

	for layoutOrder, entry in ipairs(entries) do
		makeRow(entry, layoutOrder)
	end

	local contentHeight = (#entries * ROW_HEIGHT)
		+ (math.max(0, #entries - 1) * ROW_GAP)
		+ 12

	list.CanvasSize = UDim2.fromOffset(0, contentHeight)

	task.defer(function()
		setCanvasY(oldCanvasY)
		scheduleScrollbarUpdate()
	end)
end

local function refreshState()
	local success, result = pcall(function()
		return GetState:InvokeServer()
	end)

	if success and type(result) == "table" then
		state = result
		table.clear(pendingSingleSales)
		sellAllPending = false
		render()
	elseif not success then
		warn(
			"[SeasideShopModernClient] GetState failed:",
			result
		)
	end
end

sellAllButton.Activated:Connect(function()
	if sellAllPending
		or not state
		or type(state.Inventory) ~= "table"
		or #state.Inventory == 0
	then
		return
	end

	sellAllPending = true
	updateSellAllState()
	SellFish:FireServer()

	task.delay(4, function()
		if sellAllPending then
			sellAllPending = false
			if root.Visible then
				refreshState()
			end
		end
	end)
end)

closeButton.Activated:Connect(function()
	setVisible(false)
end)

-- Permanently suppress only the old fishmonger popup.
local legacyConnections = {}
local legacyOpenDebounce = false

local function openModernFromLegacyAttempt()
	if legacyOpenDebounce then
		return
	end

	legacyOpenDebounce = true

	task.defer(function()
		if setVisible then
			setVisible(true)
		end

		task.delay(0.15, function()
			legacyOpenDebounce = false
		end)
	end)
end

local function suppressLegacyFishmonger(instance)
	if not instance
		or instance == root
		or not instance:IsA("GuiObject")
		or instance.Name ~= "FishmongerSellOverlay"
	then
		return
	end

	if instance.Visible then
		instance.Visible = false
	end

	if not legacyConnections[instance] then
		legacyConnections[instance] =
			instance:GetPropertyChangedSignal("Visible"):Connect(function()
				if not instance.Parent or not instance.Visible then
					return
				end

				instance.Visible = false
				openModernFromLegacyAttempt()
			end)
	end
end

local function suppressAllLegacyFishmongers()
	for _, descendant in ipairs(screenGui:GetDescendants()) do
		suppressLegacyFishmonger(descendant)
	end
end

screenGui.DescendantAdded:Connect(function(descendant)
	task.defer(suppressLegacyFishmonger, descendant)
end)

suppressAllLegacyFishmongers()

setVisible = function(visible)
	root.Visible = visible == true

	if visible then
		list.CanvasPosition = Vector2.new(0, 0)
		list.ClipsDescendants = true
		refreshState()
		render()
		scheduleScrollbarUpdate()

		task.defer(suppressAllLegacyFishmongers)
		task.delay(0.05, suppressAllLegacyFishmongers)
		task.delay(0.15, suppressAllLegacyFishmongers)
	else
		thumbDragging = false
		thumbDragInput = nil
	end
end

OpenSellFish.OnClientEvent:Connect(function()
	setVisible(true)
end)

StateUpdated.OnClientEvent:Connect(function(newState)
	state = newState
	table.clear(pendingSingleSales)
	sellAllPending = false

	if root.Visible then
		render()
	end
end)

-- Extra protection because the legacy listener may run after this script.
local legacySuppressElapsed = 0

RunService.RenderStepped:Connect(function(deltaTime)
	if not root.Visible then
		return
	end

	legacySuppressElapsed += deltaTime

	if legacySuppressElapsed >= 0.10 then
		legacySuppressElapsed = 0
		suppressAllLegacyFishmongers()
	end
end)

print(
	"[SeasideShopModernClient] Loaded successfully. "
		.. "Modern Seaside Shop is ready."
)
