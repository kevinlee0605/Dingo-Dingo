-- SupplyShopModernClient
-- LocalScript location:
-- StarterGui > FishingGui > SupplyShopModernClient
--
-- This script does NOT replace FishingClient.
-- It opens from the existing OpenRodShop remote, uses the current BuyRod and
-- BaitAction remotes, listens for StateUpdated, and suppresses only the old
-- RodShopOverlay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local screenGui = script:FindFirstAncestorOfClass("ScreenGui")

if not screenGui then
	error(
		"[SupplyShopModernClient] No ScreenGui ancestor found. "
			.. "Place this LocalScript anywhere inside StarterGui > FishingGui."
	)
end

print(
	"[SupplyShopModernClient] Starting from:",
	script:GetFullName(),
	"| ScreenGui:",
	screenGui:GetFullName()
)

local GameConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")
)
local ResourceConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ResourceConfig")
)

local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local OpenRodShop = Remotes:WaitForChild("OpenRodShop")
local BuyRod = Remotes:WaitForChild("BuyRod")
local BaitAction = Remotes:WaitForChild("BaitAction")
local StateUpdated = Remotes:WaitForChild("StateUpdated")
local GetState = Remotes:WaitForChild("GetState")

local ASSETS = {
	MainBackbone = "rbxassetid://77079984837491",
	SubMainBackbone = "rbxassetid://120182750042631",
	IndividualUITab = "rbxassetid://127925036253260",

	SectionTab = "rbxassetid://131015417525927",
	SectionTabSelected = "rbxassetid://83228267224190",

	ShopIcon = "rbxassetid://96250612796056",
	FishingRodIcon = "rbxassetid://100331440979418",
	BaitIcon = "rbxassetid://88745847129808",

	BlueButton = "rbxassetid://125521996931477",
	GreenButton = "rbxassetid://137614054152455",
	RedButton = "rbxassetid://79554836514436",

	ScrollBar = "rbxassetid://73367138577137",
	CloseButton = "rbxassetid://119322438066977",

	RodImages = {
		WoodenRod = "rbxassetid://105149981299569",
		IronRod = "rbxassetid://101448937429933",
		GoldenRod = "rbxassetid://106139724127905",
		EmeraldRod = "rbxassetid://70525367176824",
		OceanRod = "rbxassetid://113063482139117",
	},

	BaitImages = {
		FreshBait = "rbxassetid://114397365249536",
		TastyBait = "rbxassetid://89693745580563",
		LuckyBait = "rbxassetid://90876615894262",
		GlowBait = "rbxassetid://140507231143381",
		MysticBait = "rbxassetid://91652408607528",
		PondGuardianBait = "rbxassetid://117293437837187",
	},
}

-- Source image sizes and visible-content crops.
-- These remove the large transparent margins from the uploaded PNGs.
local CROPS = {
	MainBackbone = {
		source = Vector2.new(1448, 1086),
		offset = Vector2.new(33, 24),
		size = Vector2.new(1382, 1019),
	},
	SubMainBackbone = {
		source = Vector2.new(1448, 1086),
		offset = Vector2.new(43, 176),
		size = Vector2.new(1362, 763),
	},
	IndividualUITab = {
		source = Vector2.new(1448, 1086),
		offset = Vector2.new(10, 355),
		size = Vector2.new(1428, 277),
	},
	SectionTab = {
		source = Vector2.new(1254, 1254),
		offset = Vector2.new(70, 460),
		size = Vector2.new(1115, 353),
	},
	SectionTabSelected = {
		source = Vector2.new(1254, 1254),
		offset = Vector2.new(49, 468),
		size = Vector2.new(1156, 328),
	},
	ShopIcon = {
		source = Vector2.new(1254, 1254),
		offset = Vector2.new(119, 216),
		size = Vector2.new(1009, 751),
	},
	FishingRodIcon = {
		source = Vector2.new(1254, 1254),
		offset = Vector2.new(371, 354),
		size = Vector2.new(469, 532),
	},
	BaitIcon = {
		source = Vector2.new(1254, 1254),
		offset = Vector2.new(402, 317),
		size = Vector2.new(415, 609),
	},
	BlueButton = {
		source = Vector2.new(1254, 1254),
		offset = Vector2.new(117, 480),
		size = Vector2.new(1015, 372),
	},
	GreenButton = {
		source = Vector2.new(1254, 1254),
		offset = Vector2.new(117, 480),
		size = Vector2.new(1015, 372),
	},
	RedButton = {
		source = Vector2.new(1254, 1254),
		offset = Vector2.new(119, 479),
		size = Vector2.new(1011, 375),
	},
	ScrollBar = {
		source = Vector2.new(1448, 1086),
		offset = Vector2.new(683, 29),
		size = Vector2.new(65, 1021),
	},
	CloseButton = {
		source = Vector2.new(1187, 1326),
		offset = Vector2.new(375, 422),
		size = Vector2.new(427, 439),
	},
}

-- =========================
-- EASY UI TUNING VALUES
-- =========================

local BASE_WIDTH = 1448
local BASE_HEIGHT = 1086

-- Whole UI size and position.
local SUPPLY_UI_SIZE_MULTIPLIER = 0.7
local SUPPLY_UI_X = 0.5
local SUPPLY_UI_Y = 0.43

local TAB_Y = 165
local TAB_WIDTH = 355
local TAB_HEIGHT = 80
local TAB_GAP = 14
local TAB_START_X = 92

-- Rod/Bait tab icon placement.
-- The actual icon width is calculated from each PNG's original aspect ratio,
-- so the fishing rod and bait icons are no longer stretched or squashed.
local TAB_ICON_SLOT_X = 42
local TAB_ICON_SLOT_WIDTH = 84
local TAB_ICON_Y = 7
local TAB_ICON_HEIGHT = 66

local LIST_X = 70
local LIST_Y = 248
local LIST_WIDTH = 1252
local LIST_HEIGHT = 780

local CARD_WIDTH = 1238
local CARD_HEIGHT = 164
local CARD_GAP = 8

local SCROLL_TRACK_X = 1332
local SCROLL_TRACK_Y = 246
local SCROLL_TRACK_WIDTH = 27
local SCROLL_TRACK_HEIGHT = 778
local SCROLL_WHEEL_STEP = 145

local BUTTON_X = 930
local BUTTON_Y = 38
local BUTTON_WIDTH = 252
local BUTTON_HEIGHT = 88

-- Rod/Bait image placement inside the left item box.
-- Changing these values moves or resizes every item image at once.
local ITEM_ICON_BOX_X = 28
local ITEM_ICON_BOX_Y = 14
local ITEM_ICON_BOX_WIDTH = 160
local ITEM_ICON_BOX_HEIGHT = 136
local ITEM_ICON_INNER_SCALE = 0.84

local state = nil
local activeTab = "Rods"
local pendingRodPurchases = {}
local setVisible
local pendingBaitPurchases = {}

local backpackWasEnabled = nil

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

local function normalizeAssetId(value)
	if value == nil then
		return ""
	end

	local text = tostring(value)
	if text == "" then
		return ""
	end

	if text:find("rbxassetid://", 1, true)
		or text:find("rbxasset://", 1, true)
	then
		return text
	end

	if tonumber(text) then
		return "rbxassetid://" .. text
	end

	return text
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

local function addCorner(guiObject, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = guiObject
	return corner
end

local function makeText(
	parent,
	name,
	text,
	textSize,
	color,
	font
)
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
	label.TextStrokeTransparency = 0.05
	label.ZIndex = 505
	label.Parent = parent
	return label
end

local function makeCropArtwork(parent, imageId, crop, zIndex)
	local artwork = Instance.new("ImageLabel")
	artwork.Name = "Artwork"
	artwork.BackgroundTransparency = 1
	artwork.BorderSizePixel = 0
	artwork.Image = imageId
	artwork.ScaleType = Enum.ScaleType.Stretch
	artwork.ZIndex = zIndex or 500
	artwork.Parent = parent

	if crop then
		artwork.Position = UDim2.fromScale(
			-crop.offset.X / crop.size.X,
			-crop.offset.Y / crop.size.Y
		)
		artwork.Size = UDim2.fromScale(
			crop.source.X / crop.size.X,
			crop.source.Y / crop.size.Y
		)
	else
		artwork.Position = UDim2.fromScale(0, 0)
		artwork.Size = UDim2.fromScale(1, 1)
	end

	return artwork
end

local function makeImageHolder(
	parent,
	name,
	imageId,
	position,
	size,
	crop,
	zIndex
)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Position = position
	holder.Size = size
	holder.ClipsDescendants = crop ~= nil
	holder.ZIndex = zIndex or 500
	holder.Parent = parent

	makeCropArtwork(holder, imageId, crop, zIndex)
	return holder
end

local function makeImageButton(
	parent,
	name,
	imageId,
	position,
	size,
	crop,
	zIndex
)
	local button = Instance.new("ImageButton")
	button.Name = name
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.Image = ""
	button.AutoButtonColor = false
	button.ClipsDescendants = crop ~= nil
	button.ZIndex = zIndex or 505
	button.Parent = parent

	makeCropArtwork(button, imageId, crop, zIndex)
	return button
end

local function getArtwork(guiObject)
	return guiObject and guiObject:FindFirstChild("Artwork")
end

local function addPressFeedback(button)
	local originalPosition = button.Position
	local originalSize = button.Size
	local artwork = getArtwork(button)

	local activeTween
	local activeArtworkTween

	local function apply(pressed)
		if not button.Active then
			return
		end

		if activeTween then
			activeTween:Cancel()
		end
		if activeArtworkTween then
			activeArtworkTween:Cancel()
		end

		activeTween = TweenService:Create(
			button,
			TweenInfo.new(
				0.075,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				Position = UDim2.new(
					originalPosition.X.Scale,
					originalPosition.X.Offset + (pressed and 3 or 0),
					originalPosition.Y.Scale,
					originalPosition.Y.Offset + (pressed and 3 or 0)
				),
				Size = UDim2.new(
					originalSize.X.Scale,
					originalSize.X.Offset - (pressed and 6 or 0),
					originalSize.Y.Scale,
					originalSize.Y.Offset - (pressed and 6 or 0)
				),
			}
		)
		activeTween:Play()

		if artwork then
			activeArtworkTween = TweenService:Create(
				artwork,
				TweenInfo.new(
					0.075,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),
				{
					ImageTransparency = pressed and 0.14 or 0,
				}
			)
			activeArtworkTween:Play()
		end
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			apply(true)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			apply(false)
		end
	end)

	button.MouseLeave:Connect(function()
		apply(false)
	end)
end

local function clearList(list, layout)
	for _, child in ipairs(list:GetChildren()) do
		if child ~= layout then
			child:Destroy()
		end
	end
end

local function getOrderedIds(orderTable, dataTable)
	local result = {}

	if type(orderTable) == "table" then
		for _, itemId in ipairs(orderTable) do
			if dataTable[itemId] then
				table.insert(result, itemId)
			end
		end
	end

	for itemId in pairs(dataTable or {}) do
		if not table.find(result, itemId) then
			table.insert(result, itemId)
		end
	end

	table.sort(result, function(leftId, rightId)
		local left = dataTable[leftId] or {}
		local right = dataTable[rightId] or {}
		local leftOrder = tonumber(left.order) or math.huge
		local rightOrder = tonumber(right.order) or math.huge

		if leftOrder ~= rightOrder then
			return leftOrder < rightOrder
		end

		return tostring(left.displayName or leftId)
			< tostring(right.displayName or rightId)
	end)

	return result
end

local function getRodImage(rodId)
	local imageId = ASSETS.RodImages[rodId]

	if not imageId and GameConfig.getRodImage then
		imageId = GameConfig.getRodImage(rodId)
	end

	return normalizeAssetId(imageId)
end

local function getBaitImage(baitId)
	local imageId = ASSETS.BaitImages[baitId]

	if not imageId and GameConfig.getBaitImage then
		imageId = GameConfig.getBaitImage(baitId)
	end

	return normalizeAssetId(imageId)
end

local function getUnlockedMap()
	if not state then
		return {}
	end

	return state.UnlockedIslands
		or state.UnlockedBiomes
		or {}
end

local function requiredBiomeUnlocked(itemData)
	local requiredBiome = itemData and itemData.requiredBiome
	if not requiredBiome then
		return true
	end

	return getUnlockedMap()[requiredBiome] == true
end

-- Permanently suppress only the old Supply Shop overlay.
-- The current FishingClient creates this exact object and opens it after the
-- OpenRodShop event. Watching Visible makes the replacement reliable even if
-- event-listener order changes or this script starts slightly later.
local legacyConnections = {}
local legacyOpenDebounce = false

local function openModernFromLegacyAttempt()
	if legacyOpenDebounce then
		return
	end

	legacyOpenDebounce = true
	task.defer(function()
		if setVisible then
			print(
				"[SupplyShopModernClient] Old RodShopOverlay tried to open; "
					.. "opening ModernSupplyShop instead."
			)
			setVisible(true)
		end

		task.delay(0.15, function()
			legacyOpenDebounce = false
		end)
	end)
end

local function suppressLegacyRodShop(instance)
	if not instance
		or instance.Name ~= "RodShopOverlay"
		or not instance:IsA("GuiObject")
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

		print(
			"[SupplyShopModernClient] Watching legacy overlay:",
			instance:GetFullName()
		)
	end
end

local function suppressAllLegacyRodShops()
	for _, descendant in ipairs(screenGui:GetDescendants()) do
		suppressLegacyRodShop(descendant)
	end
end

suppressAllLegacyRodShops()

screenGui.DescendantAdded:Connect(function(descendant)
	task.defer(suppressLegacyRodShop, descendant)
end)

task.delay(1, suppressAllLegacyRodShops)
task.delay(3, suppressAllLegacyRodShops)

-- Root UI
local root = Instance.new("Frame")
root.Name = "ModernSupplyShop"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(SUPPLY_UI_X, SUPPLY_UI_Y)
root.Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)
root.BackgroundTransparency = 1
root.BorderSizePixel = 0
root.Visible = false
root.ZIndex = 500
root.Parent = screenGui

local scale = Instance.new("UIScale")
scale.Name = "ResponsiveScale"
scale.Parent = root

local function updateResponsiveScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize
		or Vector2.new(1920, 1080)

	local fit = math.min(
		(viewport.X * 0.98) / BASE_WIDTH,
		(viewport.Y * 0.96) / BASE_HEIGHT
	)

	scale.Scale = math.clamp(
		fit * SUPPLY_UI_SIZE_MULTIPLIER,
		0.30,
		1
	)
end

updateResponsiveScale()

local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(
		updateResponsiveScale
	)
end

makeImageHolder(
	root,
	"MainBackbone",
	ASSETS.MainBackbone,
	UDim2.fromOffset(0, 0),
	UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT),
	CROPS.MainBackbone,
	500
)

makeImageHolder(
	root,
	"SubMainBackbone",
	ASSETS.SubMainBackbone,
	UDim2.fromOffset(35, 146),
	UDim2.fromOffset(1378, 884),
	CROPS.SubMainBackbone,
	501
)

makeImageHolder(
	root,
	"ShopIcon",
	ASSETS.ShopIcon,
	UDim2.fromOffset(52, 27),
	UDim2.fromOffset(178, 123),
	CROPS.ShopIcon,
	505
)

local title = makeText(
	root,
	"Title",
	"SUPPLY SHOP",
	78,
	Color3.fromRGB(255, 255, 255)
)
title.Position = UDim2.fromOffset(250, 36)
title.Size = UDim2.fromOffset(760, 108)
title.ZIndex = 506

local closeButton = makeImageButton(
	root,
	"CloseButton",
	ASSETS.CloseButton,
	UDim2.fromOffset(1282, 36),
	UDim2.fromOffset(104, 104),
	CROPS.CloseButton,
	520
)
addPressFeedback(closeButton)

local tabHolder = Instance.new("Frame")
tabHolder.Name = "Tabs"
tabHolder.BackgroundTransparency = 1
tabHolder.Position = UDim2.fromOffset(TAB_START_X, TAB_Y)
tabHolder.Size = UDim2.fromOffset(
	(TAB_WIDTH * 2) + TAB_GAP,
	TAB_HEIGHT
)
tabHolder.ZIndex = 507
tabHolder.Parent = root

-- Scroll area
local list = Instance.new("ScrollingFrame")
list.Name = "SupplyShopList"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(LIST_X, LIST_Y)
list.Size = UDim2.fromOffset(LIST_WIDTH, LIST_HEIGHT)
list.CanvasSize = UDim2.fromOffset(0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.None
list.Active = true
list.ScrollingEnabled = true
list.Selectable = true
list.ScrollBarThickness = 0
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
list.ClipsDescendants = true
list.ZIndex = 506
list.Parent = root

local listLayout = Instance.new("UIListLayout")
listLayout.Name = "ListLayout"
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, CARD_GAP)
listLayout.Parent = list

-- Custom scrollbar.
local scrollTrack = Instance.new("Frame")
scrollTrack.Name = "ScrollTrack"
scrollTrack.BackgroundColor3 = Color3.fromRGB(1, 19, 54)
scrollTrack.BackgroundTransparency = 0.08
scrollTrack.BorderSizePixel = 0
scrollTrack.Position = UDim2.fromOffset(
	SCROLL_TRACK_X,
	SCROLL_TRACK_Y
)
scrollTrack.Size = UDim2.fromOffset(
	SCROLL_TRACK_WIDTH,
	SCROLL_TRACK_HEIGHT
)
scrollTrack.Active = true
scrollTrack.ZIndex = 509
scrollTrack.Parent = root
addCorner(scrollTrack, SCROLL_TRACK_WIDTH)

-- No UIStroke here: its anti-aliased left edge could appear as a thin
-- white vertical line beside the custom scrollbar.
local scrollThumb = makeImageButton(
	scrollTrack,
	"ScrollThumb",
	ASSETS.ScrollBar,
	UDim2.fromOffset(1, 0),
	UDim2.fromOffset(
		SCROLL_TRACK_WIDTH - 2,
		220
	),
	CROPS.ScrollBar,
	511
)
scrollThumb.Active = true

-- Hide the thin pale edge created where the item cards are clipped by
-- the ScrollingFrame. This does not cover the blue scrollbar thumb.
local listRightEdgeMask = Instance.new("Frame")
listRightEdgeMask.Name = "ListRightEdgeMask"
listRightEdgeMask.BackgroundColor3 = Color3.fromRGB(1, 18, 54)
listRightEdgeMask.BorderSizePixel = 0
listRightEdgeMask.Position = UDim2.fromOffset(
	LIST_X + LIST_WIDTH - 5,
	LIST_Y
)
listRightEdgeMask.Size = UDim2.fromOffset(7, LIST_HEIGHT)
listRightEdgeMask.ZIndex = 508
listRightEdgeMask.Parent = root

local function getContentHeight()
	return math.max(
		list.CanvasSize.Y.Offset,
		listLayout.AbsoluteContentSize.Y
	)
end

local function getMaxCanvasY()
	return math.max(
		0,
		getContentHeight() - list.AbsoluteWindowSize.Y
	)
end

local function setCanvasY(newY)
	list.CanvasPosition = Vector2.new(
		0,
		math.clamp(newY, 0, getMaxCanvasY())
	)
end

local function updateScrollbar()
	local contentHeight = getContentHeight()
	local viewportHeight = math.max(1, list.AbsoluteWindowSize.Y)
	local trackHeight = math.max(1, scrollTrack.AbsoluteSize.Y)

	if contentHeight <= viewportHeight + 1 then
		scrollThumb.Visible = false
		return
	end

	scrollThumb.Visible = true

	local ratio = math.clamp(
		viewportHeight / contentHeight,
		0.10,
		1
	)
	local thumbHeight = math.max(
		82,
		math.floor(trackHeight * ratio)
	)
	local maxTravel = math.max(
		0,
		trackHeight - thumbHeight
	)
	local maxCanvasY = math.max(
		1,
		contentHeight - viewportHeight
	)
	local scrollRatio = math.clamp(
		list.CanvasPosition.Y / maxCanvasY,
		0,
		1
	)

	scrollThumb.Position = UDim2.fromOffset(
		1,
		math.floor(maxTravel * scrollRatio)
	)
	scrollThumb.Size = UDim2.fromOffset(
		SCROLL_TRACK_WIDTH - 2,
		thumbHeight
	)
end

list:GetPropertyChangedSignal("CanvasPosition"):Connect(
	updateScrollbar
)
list:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(
	updateScrollbar
)

local function setListCanvasForCount(itemCount)
	local contentHeight = 0

	if itemCount > 0 then
		contentHeight = (itemCount * CARD_HEIGHT)
			+ ((itemCount - 1) * CARD_GAP)
			+ 16
	end

	list.CanvasSize = UDim2.fromOffset(
		0,
		contentHeight
	)
	task.defer(updateScrollbar)
end

-- Guaranteed mouse wheel scrolling.
UserInputService.InputChanged:Connect(function(input)
	if not root.Visible then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseWheel then
		return
	end

	local mousePosition = UserInputService:GetMouseLocation()
	if not pointInside(list, mousePosition)
		and not pointInside(scrollTrack, mousePosition)
	then
		return
	end

	setCanvasY(
		list.CanvasPosition.Y
		- (input.Position.Z * SCROLL_WHEEL_STEP)
	)
end)

-- Touch drag scrolling.
local activeTouch = nil
local touchStartY = 0
local touchStartCanvasY = 0

UserInputService.InputBegan:Connect(function(input)
	if not root.Visible
		or input.UserInputType ~= Enum.UserInputType.Touch
		or not pointInside(list, input.Position)
	then
		return
	end

	activeTouch = input
	touchStartY = input.Position.Y
	touchStartCanvasY = list.CanvasPosition.Y
end)

UserInputService.InputChanged:Connect(function(input)
	if input ~= activeTouch then
		return
	end

	setCanvasY(
		touchStartCanvasY
		- (input.Position.Y - touchStartY)
	)
end)

UserInputService.InputEnded:Connect(function(input)
	if input == activeTouch then
		activeTouch = nil
	end
end)

-- Drag the custom scrollbar thumb.
local activeThumbInput = nil
local thumbDragStartY = 0
local thumbDragStartCanvasY = 0

scrollThumb.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		activeThumbInput = input
		thumbDragStartY = input.Position.Y
		thumbDragStartCanvasY = list.CanvasPosition.Y
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not activeThumbInput then
		return
	end

	local currentY

	if activeThumbInput.UserInputType
		== Enum.UserInputType.Touch
	then
		if input ~= activeThumbInput then
			return
		end
		currentY = input.Position.Y
	elseif input.UserInputType
		== Enum.UserInputType.MouseMovement
	then
		currentY = input.Position.Y
	end

	if not currentY then
		return
	end

	local trackHeight = math.max(
		1,
		scrollTrack.AbsoluteSize.Y
	)
	local thumbHeight = math.max(
		1,
		scrollThumb.AbsoluteSize.Y
	)
	local maxTravel = math.max(
		1,
		trackHeight - thumbHeight
	)
	local deltaY = currentY - thumbDragStartY

	setCanvasY(
		thumbDragStartCanvasY
			+ (
				(deltaY / maxTravel)
				* getMaxCanvasY()
			)
	)
end)

UserInputService.InputEnded:Connect(function(input)
	if input == activeThumbInput
		or input.UserInputType
		== Enum.UserInputType.MouseButton1
	then
		activeThumbInput = nil
	end
end)

local function createTab(
	tabName,
	xPosition,
	iconKey
)
	local selected = activeTab == tabName
	local imageKey = selected
		and "SectionTabSelected"
		or "SectionTab"

	local button = makeImageButton(
		tabHolder,
		tabName .. "Tab",
		ASSETS[imageKey],
		UDim2.fromOffset(xPosition, 0),
		UDim2.fromOffset(TAB_WIDTH, TAB_HEIGHT),
		CROPS[imageKey],
		510
	)
	addPressFeedback(button)

	local iconCrop = CROPS[iconKey]
	local iconWidth = TAB_ICON_HEIGHT

	if iconCrop and iconCrop.size.Y > 0 then
		iconWidth = math.floor(
			(TAB_ICON_HEIGHT * iconCrop.size.X / iconCrop.size.Y)
				+ 0.5
		)
	end

	iconWidth = math.clamp(
		iconWidth,
		1,
		TAB_ICON_SLOT_WIDTH
	)

	local iconX = TAB_ICON_SLOT_X
		+ math.floor(
			(TAB_ICON_SLOT_WIDTH - iconWidth) / 2
		)

	makeImageHolder(
		button,
		"Icon",
		ASSETS[iconKey],
		UDim2.fromOffset(iconX, TAB_ICON_Y),
		UDim2.fromOffset(iconWidth, TAB_ICON_HEIGHT),
		iconCrop,
		513
	)

	local text = makeText(
		button,
		"Label",
		tabName,
		40,
		Color3.fromRGB(255, 255, 255)
	)
	text.Position = UDim2.fromOffset(130, 8)
	text.Size = UDim2.fromOffset(185, 66)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.ZIndex = 514

	button.MouseButton1Click:Connect(function()
		activeTab = tabName
		list.CanvasPosition = Vector2.new(0, 0)
	end)

	return button
end

local function renderTabs()
	tabHolder:ClearAllChildren()

	local rodsTab = createTab(
		"Rods",
		0,
		"FishingRodIcon"
	)
	local baitTab = createTab(
		"Bait",
		TAB_WIDTH + TAB_GAP,
		"BaitIcon"
	)

	rodsTab.MouseButton1Click:Connect(function()
		activeTab = "Rods"
	end)
	baitTab.MouseButton1Click:Connect(function()
		activeTab = "Bait"
	end)
end

local function makeItemIcon(
	card,
	imageId
)
	-- The holder always matches the left image box.
	local holder = Instance.new("Frame")
	holder.Name = "ItemIconHolder"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Position = UDim2.fromOffset(
		ITEM_ICON_BOX_X,
		ITEM_ICON_BOX_Y
	)
	holder.Size = UDim2.fromOffset(
		ITEM_ICON_BOX_WIDTH,
		ITEM_ICON_BOX_HEIGHT
	)
	holder.ClipsDescendants = true
	holder.ZIndex = 513
	holder.Parent = card

	-- Anchor the actual image to the exact center of the holder.
	-- ScaleType.Fit preserves the original aspect ratio for both rods and bait.
	local image = Instance.new("ImageLabel")
	image.Name = "ItemIcon"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(
		ITEM_ICON_INNER_SCALE,
		ITEM_ICON_INNER_SCALE
	)
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = imageId
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = 514
	image.Parent = holder

	return image
end

local function makeStatusButton(
	card,
	statusName,
	clickCallback
)
	local imageKey
	local active = false

	if statusName == "Buy"
		or statusName:find("Buy +", 1, true)
	then
		imageKey = "GreenButton"
		active = true
	elseif statusName == "Owned" then
		imageKey = "BlueButton"
	else
		imageKey = "RedButton"
	end

	local button = makeImageButton(
		card,
		"StatusButton",
		ASSETS[imageKey],
		UDim2.fromOffset(
			BUTTON_X,
			BUTTON_Y
		),
		UDim2.fromOffset(
			BUTTON_WIDTH,
			BUTTON_HEIGHT
		),
		CROPS[imageKey],
		516
	)

	button.Active = active
	button.Selectable = active

	local label = makeText(
		button,
		"Label",
		statusName,
		statusName == "Not Enough" and 29 or 36,
		Color3.fromRGB(255, 255, 255)
	)
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = 518

	if active then
		addPressFeedback(button)
		button.MouseButton1Click:Connect(function()
			if clickCallback then
				clickCallback(button, label)
			end
		end)
	end

	return button
end

local function makeCard(itemId, layoutOrder)
	local card = makeImageHolder(
		list,
		itemId .. "Card",
		ASSETS.IndividualUITab,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(
			CARD_WIDTH,
			CARD_HEIGHT
		),
		CROPS.IndividualUITab,
		508
	)
	card.LayoutOrder = layoutOrder
	return card
end

local function renderRods()
	local rodIds = getOrderedIds(
		GameConfig.RodOrder,
		GameConfig.Rods
	)

	for index, rodId in ipairs(rodIds) do
		local rod = GameConfig.Rods[rodId]
		local owned = state
			and state.OwnedRods
			and state.OwnedRods[rodId] == true
		local equipped = owned and state.EquippedRod == rodId
		local cost = tonumber(rod.cost) or 0
		local unlockLevel = tonumber(rod.unlockLevel) or 1
		local canAfford = state
			and (tonumber(state.Coins) or 0) >= cost
		local levelOkay = state
			and (tonumber(state.Level) or 1) >= unlockLevel
		local previousOkay = not rod.previousRod
			or (state and state.OwnedRods and state.OwnedRods[rod.previousRod] == true)

		local resourcesOkay = true
		local resourceText = "Resources: None (Met)"
		local resourceInventory = state and state.ResourceInventory or {}
		for _, resourceId in ipairs(ResourceConfig.ResourceOrder) do
			local required = tonumber(rod.resourceCosts and rod.resourceCosts[resourceId]) or 0
			if required > 0 then
				local current = math.max(0, math.floor(tonumber(resourceInventory[resourceId]) or 0))
				resourcesOkay = current >= required
				resourceText = string.format(
					"%s: %d/%d (%s)",
					ResourceConfig.Resources[resourceId].displayName,
					current,
					required,
					resourcesOkay and "Met" or "Unmet"
				)
				break
			end
		end

		local canBuy = not owned
			and previousOkay
			and levelOkay
			and resourcesOkay
			and canAfford
			and not pendingRodPurchases[rodId]

		local card = makeCard(rodId, index)
		makeItemIcon(card, getRodImage(rodId))

		local name = makeText(
			card,
			"ItemName",
			rod.displayName or rodId,
			39,
			Color3.fromRGB(255, 255, 255)
		)
		name.Position = UDim2.fromOffset(240, 10)
		name.Size = UDim2.fromOffset(650, 46)
		name.ZIndex = 513

		local infoText = string.format(
			"Level %d (<font color='%s'>%s</font>)"
				.. "   |   <font color='#FFD51E'>%s Coins</font> (<font color='%s'>%s</font>)",
			unlockLevel,
			levelOkay and "#62FF53" or "#FF7575",
			levelOkay and "Met" or "Unmet",
			formatNumber(cost),
			canAfford and "#62FF53" or "#FF7575",
			canAfford and "Met" or "Unmet"
		)

		local info = makeText(
			card,
			"Info",
			infoText,
			23,
			Color3.fromRGB(160, 194, 255),
			Enum.Font.GothamMedium
		)
		info.RichText = true
		info.Position = UDim2.fromOffset(240, 55)
		info.Size = UDim2.fromOffset(675, 28)
		info.TextStrokeTransparency = 0.65
		info.ZIndex = 513

		local previousName = rod.previousRod
			and GameConfig.Rods[rod.previousRod]
			and GameConfig.Rods[rod.previousRod].displayName
			or "None"
		local requirementText = string.format(
			"Previous: %s (%s)   |   %s",
			previousName,
			previousOkay and "Met" or "Unmet",
			resourceText
		)
		local requirements = makeText(
			card,
			"Requirements",
			requirementText,
			21,
			previousOkay and resourcesOkay and Color3.fromRGB(98, 255, 83) or Color3.fromRGB(255, 117, 117),
			Enum.Font.GothamMedium
		)
		requirements.Position = UDim2.fromOffset(240, 86)
		requirements.Size = UDim2.fromOffset(680, 28)
		requirements.TextStrokeTransparency = 0.7
		requirements.ZIndex = 513

		local statusText
		local statusColor
		if equipped then
			statusText = "Currently equipped."
			statusColor = Color3.fromRGB(98, 255, 83)
		elseif owned then
			statusText = "Owned."
			statusColor = Color3.fromRGB(136, 178, 255)
		elseif not previousOkay then
			statusText = "Previous rod required."
			statusColor = Color3.fromRGB(255, 117, 117)
		elseif not levelOkay then
			statusText = "Reach level " .. tostring(unlockLevel) .. " to buy."
			statusColor = Color3.fromRGB(255, 117, 117)
		elseif not resourcesOkay then
			statusText = "More crafting resources required."
			statusColor = Color3.fromRGB(255, 117, 117)
		elseif not canAfford then
			statusText = "Need "
				.. formatNumber(cost - (tonumber(state.Coins) or 0))
				.. " more coins."
			statusColor = Color3.fromRGB(255, 117, 117)
		else
			statusText = "Available for purchase."
			statusColor = Color3.fromRGB(136, 178, 255)
		end

		local status = makeText(
			card,
			"Status",
			statusText,
			21,
			statusColor,
			Enum.Font.GothamMedium
		)
		status.Position = UDim2.fromOffset(240, 119)
		status.Size = UDim2.fromOffset(680, 28)
		status.TextStrokeTransparency = 0.7
		status.ZIndex = 513

		if owned then
			makeStatusButton(card, equipped and "Equipped" or "Owned", nil)
		elseif canBuy then
			makeStatusButton(
				card,
				"Buy",
				function(button)
					if pendingRodPurchases[rodId] then
						return
					end

					pendingRodPurchases[rodId] = true
					button.Active = false
					BuyRod:FireServer(rodId)

					task.delay(4, function()
						pendingRodPurchases[rodId] = nil
					end)
				end
			)
		else
			makeStatusButton(card, "Not Enough", nil)
		end
	end

	setListCanvasForCount(#rodIds)
end
local function renderBaits()
	local allBaitIds = getOrderedIds(
		GameConfig.BaitOrder,
		GameConfig.Baits
	)
	local baitIds = {}

	for _, baitId in ipairs(allBaitIds) do
		if baitId ~= (GameConfig.BasicBaitId or "BasicBait") then
			table.insert(baitIds, baitId)
		end
	end

	for index, baitId in ipairs(baitIds) do
		local bait = GameConfig.Baits[baitId]
		local cost = tonumber(bait.cost) or 0
		local amount = math.max(
			1,
			math.floor(
				tonumber(bait.purchaseAmount) or 1
			)
		)
		local unlockLevel = tonumber(bait.unlockLevel) or 1
		local count = state
			and state.BaitInventory
			and math.max(
				0,
				math.floor(
					tonumber(
						state.BaitInventory[baitId]
					) or 0
				)
			)
			or 0

		local canAfford = state
			and (tonumber(state.Coins) or 0) >= cost
		local levelOkay = state
			and (tonumber(state.Level) or 1) >= unlockLevel
		local biomeOkay = requiredBiomeUnlocked(bait)
		local canBuy = canAfford
			and levelOkay
			and biomeOkay
			and not pendingBaitPurchases[baitId]

		local card = makeCard(baitId, index)
		makeItemIcon(card, getBaitImage(baitId))

		local name = makeText(
			card,
			"ItemName",
			bait.displayName or baitId,
			43,
			Color3.fromRGB(255, 255, 255)
		)
		name.Position = UDim2.fromOffset(240, 18)
		name.Size = UDim2.fromOffset(650, 50)
		name.ZIndex = 513

		local description = makeText(
			card,
			"Description",
			bait.description or "",
			25,
			Color3.fromRGB(154, 190, 255),
			Enum.Font.GothamMedium
		)
		description.Position = UDim2.fromOffset(240, 68)
		description.Size = UDim2.fromOffset(675, 34)
		description.TextStrokeTransparency = 0.72
		description.ZIndex = 513

		local detailText = string.format(
			"%s left"
				.. "   |   <font color='#FFD51E'>%s coins / %d</font>"
				.. "   |   Lv %d",
			formatNumber(count),
			formatNumber(cost),
			amount,
			unlockLevel
		)

		local detail = makeText(
			card,
			"Detail",
			detailText,
			25,
			Color3.fromRGB(160, 194, 255),
			Enum.Font.GothamMedium
		)
		detail.RichText = true
		detail.Position = UDim2.fromOffset(240, 106)
		detail.Size = UDim2.fromOffset(675, 36)
		detail.TextStrokeTransparency = 0.72
		detail.ZIndex = 513

		if canBuy then
			makeStatusButton(
				card,
				"Buy +" .. tostring(amount),
				function(button)
					if pendingBaitPurchases[baitId] then
						return
					end

					pendingBaitPurchases[baitId] = true
					button.Active = false
					BaitAction:FireServer("Buy", baitId)

					task.delay(4, function()
						pendingBaitPurchases[baitId] = nil
					end)
				end
			)
		else
			makeStatusButton(card, "Not Enough", nil)
		end
	end

	setListCanvasForCount(#baitIds)
end

local function render()
	renderTabs()
	clearList(list, listLayout)

	if not state then
		local loading = makeText(
			list,
			"Loading",
			"Loading supplies...",
			36,
			Color3.fromRGB(255, 255, 255)
		)
		loading.Size = UDim2.fromOffset(
			CARD_WIDTH,
			100
		)
		loading.TextXAlignment = Enum.TextXAlignment.Center
		loading.LayoutOrder = 1
		setListCanvasForCount(1)
		return
	end

	if activeTab == "Rods" then
		renderRods()
	else
		renderBaits()
	end

	task.defer(updateScrollbar)
end

-- Re-render after selecting a tab.
tabHolder.ChildAdded:Connect(function(child)
	if not child:IsA("GuiButton") then
		return
	end

	child.MouseButton1Click:Connect(function()
		task.defer(render)
	end)
end)

local function refreshState()
	local success, result = pcall(function()
		return GetState:InvokeServer()
	end)

	if success and type(result) == "table" then
		state = result
		table.clear(pendingRodPurchases)
		table.clear(pendingBaitPurchases)
		render()
	elseif not success then
		warn(
			"[SupplyShopModernClient] GetState failed:",
			result
		)
	end
end

setVisible = function(visible)
	root.Visible = visible == true
	suppressAllLegacyRodShops()

	if visible then
		if backpackWasEnabled == nil then
			local success, enabled = pcall(function()
				return StarterGui:GetCoreGuiEnabled(
					Enum.CoreGuiType.Backpack
				)
			end)
			backpackWasEnabled = success and enabled or false
		end

		pcall(function()
			StarterGui:SetCoreGuiEnabled(
				Enum.CoreGuiType.Backpack,
				false
			)
		end)

		-- Do not hide any custom FishingGui objects here.
		-- Bag and Fishdex may share the same parent container as the hotbar.
		list.CanvasPosition = Vector2.new(0, 0)
		refreshState()
		render()

		-- The old FishingClient listener may open its panel after this one.
		task.defer(suppressAllLegacyRodShops)
		task.delay(0.08, suppressAllLegacyRodShops)
	else
		activeTouch = nil
		activeThumbInput = nil

		if backpackWasEnabled ~= nil then
			pcall(function()
				StarterGui:SetCoreGuiEnabled(
					Enum.CoreGuiType.Backpack,
					backpackWasEnabled
				)
			end)
			backpackWasEnabled = nil
		end
	end
end

closeButton.MouseButton1Click:Connect(function()
	setVisible(false)
end)

OpenRodShop.OnClientEvent:Connect(function()
	print("[SupplyShopModernClient] OpenRodShop event received.")
	setVisible(true)
end)

StateUpdated.OnClientEvent:Connect(function(newState)
	state = newState
	table.clear(pendingRodPurchases)
	table.clear(pendingBaitPurchases)

	if root.Visible then
		render()
	end
end)

-- Additional protection in case the old overlay is rebuilt repeatedly.
local legacySuppressElapsed = 0
RunService.RenderStepped:Connect(function(deltaTime)
	if not root.Visible then
		return
	end

	legacySuppressElapsed += deltaTime
	if legacySuppressElapsed >= 0.10 then
		legacySuppressElapsed = 0
		suppressAllLegacyRodShops()
	end
end)

print(
	"[SupplyShopModernClient] Loaded successfully. "
		.. "ModernSupplyShop is ready."
)
