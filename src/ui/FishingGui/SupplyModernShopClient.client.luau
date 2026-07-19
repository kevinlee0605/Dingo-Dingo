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

local function requireAuthoredChild(parent, name, className)
	local child = parent:FindFirstChild(name)
	if not child or (className and not child:IsA(className)) then
		error(string.format(
			"[SupplyShopModernClient] Authored UI is missing %s.%s (%s)",
			parent:GetFullName(),
			name,
			className or "Instance"
		))
	end
	return child
end

local function getArtwork(guiObject)
	return guiObject
		and requireAuthoredChild(guiObject, "Artwork", "ImageLabel")
end

local function applyCropArtwork(holder, imageId, crop)
	local artwork = getArtwork(holder)
	artwork.Image = imageId
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
		if child:IsA("GuiObject")
			and child.Name ~= "RodCardTemplate"
			and child.Name ~= "BaitCardTemplate"
			and child.Name ~= "LoadingLabel"
		then
			child:Destroy()
		end
	end
	local loadingLabel = list:FindFirstChild("LoadingLabel")
	if loadingLabel and loadingLabel:IsA("TextLabel") then
		loadingLabel.Visible = false
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

local root = requireAuthoredChild(
	screenGui,
	"ModernSupplyShop",
	"Frame"
)
local scale = requireAuthoredChild(root, "ResponsiveScale", "UIScale")

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

local closeButton = requireAuthoredChild(
	root,
	"CloseButton",
	"ImageButton"
)
addPressFeedback(closeButton)

local tabHolder = requireAuthoredChild(root, "Tabs", "Frame")
local rodsTab = requireAuthoredChild(tabHolder, "RodsTab", "ImageButton")
local baitTab = requireAuthoredChild(tabHolder, "BaitTab", "ImageButton")
local list = requireAuthoredChild(
	root,
	"SupplyShopList",
	"ScrollingFrame"
)
local listLayout = requireAuthoredChild(list, "ListLayout", "UIListLayout")
local rodCardTemplate = requireAuthoredChild(
	list,
	"RodCardTemplate",
	"Frame"
)
local baitCardTemplate = requireAuthoredChild(
	list,
	"BaitCardTemplate",
	"Frame"
)
local loadingLabel = requireAuthoredChild(list, "LoadingLabel", "TextLabel")
local scrollTrack = requireAuthoredChild(root, "ScrollTrack", "Frame")
local scrollThumb = requireAuthoredChild(
	scrollTrack,
	"ScrollThumb",
	"ImageButton"
)

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

local render

local function updateTab(tabName, button)
	local selected = activeTab == tabName
	local imageKey = selected
		and "SectionTabSelected"
		or "SectionTab"
	applyCropArtwork(button, ASSETS[imageKey], CROPS[imageKey])
end

local function bindTab(tabName, button)
	addPressFeedback(button)
	button.MouseButton1Click:Connect(function()
		activeTab = tabName
		list.CanvasPosition = Vector2.new(0, 0)
		render()
	end)
end

local function renderTabs()
	updateTab("Rods", rodsTab)
	updateTab("Bait", baitTab)
end

bindTab("Rods", rodsTab)
bindTab("Bait", baitTab)

local function makeItemIcon(
	card,
	imageId
)
	local holder = requireAuthoredChild(
		card,
		"ItemIconHolder",
		"Frame"
	)
	local image = requireAuthoredChild(holder, "ItemIcon", "ImageLabel")
	image.Image = imageId
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

	local button = requireAuthoredChild(
		card,
		"StatusButton",
		"ImageButton"
	)
	applyCropArtwork(button, ASSETS[imageKey], CROPS[imageKey])
	button.Active = active
	button.Selectable = active
	local label = requireAuthoredChild(
		button,
		"Label",
		"TextLabel"
	)
	label.Text = statusName
	label.TextSize = statusName == "Not Enough" and 29 or 36

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
	local template = activeTab == "Rods"
		and rodCardTemplate
		or baitCardTemplate
	local card = template:Clone()
	card.Name = itemId .. "Card"
	card.Visible = true
	card.LayoutOrder = layoutOrder
	card.Parent = list
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

		local name = requireAuthoredChild(card, "ItemName", "TextLabel")
		name.Text = rod.displayName or rodId

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

		local info = requireAuthoredChild(card, "Info", "TextLabel")
		info.Text = infoText

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
		local requirements = requireAuthoredChild(
			card,
			"Requirements",
			"TextLabel"
		)
		requirements.Text = requirementText
		requirements.TextColor3 = previousOkay
			and resourcesOkay
			and Color3.fromRGB(98, 255, 83)
			or Color3.fromRGB(255, 117, 117)

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

		local status = requireAuthoredChild(card, "Status", "TextLabel")
		status.Text = statusText
		status.TextColor3 = statusColor

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

		local name = requireAuthoredChild(card, "ItemName", "TextLabel")
		name.Text = bait.displayName or baitId

		local description = requireAuthoredChild(
			card,
			"Description",
			"TextLabel"
		)
		description.Text = bait.description or ""

		local detailText = string.format(
			"%s left"
				.. "   |   <font color='#FFD51E'>%s coins / %d</font>"
				.. "   |   Lv %d",
			formatNumber(count),
			formatNumber(cost),
			amount,
			unlockLevel
		)

		local detail = requireAuthoredChild(card, "Detail", "TextLabel")
		detail.Text = detailText

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

render = function()
	renderTabs()
	clearList(list, listLayout)

	if not state then
		loadingLabel.Text = "Loading supplies..."
		loadingLabel.LayoutOrder = 1
		loadingLabel.Visible = true
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
