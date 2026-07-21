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
local LIST_WIDTH = 1304
local LIST_HEIGHT = 742

local ROW_WIDTH = 1294
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

local SELL_BUTTON_X = 1004
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

local function requireAuthoredChild(parent, name, className)
	local child = parent:FindFirstChild(name)
	if not child or (className and not child:IsA(className)) then
		error(string.format(
			"[SeasideShopModernClient] Authored UI is missing %s.%s (%s)",
			parent:GetFullName(),
			name,
			className or "Instance"
		))
	end
	return child
end

local function applyMappedArtwork(holder, image, crop)
	local imageObject = requireAuthoredChild(holder, "MappedImage", "ImageLabel")
	local source = crop.source
	local rect = crop.rect
	local rectWidth = rect.Max.X - rect.Min.X
	local rectHeight = rect.Max.Y - rect.Min.Y
	local targetWidth = holder.Size.X.Offset
	local targetHeight = holder.Size.Y.Offset
	local fullWidth = targetWidth * source.X / rectWidth
	local fullHeight = targetHeight * source.Y / rectHeight

	imageObject.Image = image
	imageObject.Position = UDim2.fromOffset(
		-(rect.Min.X / source.X) * fullWidth,
		-(rect.Min.Y / source.Y) * fullHeight
	)
	imageObject.Size = UDim2.fromOffset(fullWidth, fullHeight)
end

local function addPressFeedback(button)
	local buttonScale = requireAuthoredChild(
		button,
		"PressScale",
		"UIScale"
	)
	buttonScale.Scale = 1
	local originalPosition = button.Position
	local originalSize = button.Size
	local artwork = button:FindFirstChild("MappedImage")

	local currentTween
	local currentArtworkTween

	local function tweenTo(pressed)
		if currentTween then
			currentTween:Cancel()
		end
		if currentArtworkTween then
			currentArtworkTween:Cancel()
		end

		currentTween = TweenService:Create(
			button,
			TweenInfo.new(
				0.07,
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
		currentTween:Play()

		if artwork and artwork:IsA("ImageLabel") then
			currentArtworkTween = TweenService:Create(
				artwork,
				TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ ImageTransparency = pressed and 0.16 or 0 }
			)
			currentArtworkTween:Play()
		end
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tweenTo(true)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tweenTo(false)
		end
	end)

	button.MouseLeave:Connect(function()
		tweenTo(false)
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

local root = requireAuthoredChild(
	screenGui,
	"ModernSeasideShop",
	"Frame"
)
local responsiveScale = requireAuthoredChild(
	root,
	"ResponsiveScale",
	"UIScale"
)

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

local sellAllButton = requireAuthoredChild(
	root,
	"SellAllButton",
	"ImageButton"
)
addPressFeedback(sellAllButton)
local sellAllText = requireAuthoredChild(
	sellAllButton,
	"Label",
	"TextLabel"
)
local closeButton = requireAuthoredChild(
	root,
	"CloseButton",
	"ImageButton"
)
addPressFeedback(closeButton)
local tabHolder = requireAuthoredChild(root, "SortTabs", "Frame")
local rarityTab = requireAuthoredChild(tabHolder, "RarityTab", "ImageButton")
local valueTab = requireAuthoredChild(tabHolder, "ValueTab", "ImageButton")
addPressFeedback(rarityTab)
addPressFeedback(valueTab)

local subContentClip = requireAuthoredChild(
	root,
	"SubContentClip",
	"Frame"
)
local list = requireAuthoredChild(
	subContentClip,
	"FishList",
	"ScrollingFrame"
)
list.Position = UDim2.fromOffset(10, 11)
list.Size = UDim2.fromOffset(LIST_WIDTH, LIST_HEIGHT)
local listLayout = requireAuthoredChild(list, "ListLayout", "UIListLayout")
local rowTemplate = requireAuthoredChild(list, "FishRowTemplate", "Frame")
local statusLabel = requireAuthoredChild(list, "StatusLabel", "TextLabel")

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

local scrollTrack = requireAuthoredChild(
	subContentClip,
	"ScrollTrack",
	"Frame"
)
local scrollThumb = requireAuthoredChild(
	scrollTrack,
	"ScrollThumb",
	"TextButton"
)

local function clearList()
	for _, child in ipairs(list:GetChildren()) do
		if child.Name:sub(1, 8) == "FishRow_" then
			child:Destroy()
		end
	end
	statusLabel.Visible = false
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

	scrollTrack.Visible = true
	scrollThumb.Visible = true
	scrollThumb.Active = isScrollable

	if not isScrollable then
		scrollThumb.Position = UDim2.fromOffset(
			math.floor((SCROLL_TRACK_WIDTH - 14) * 0.5),
			0
		)
		scrollThumb.Size = UDim2.fromOffset(
			14,
			math.clamp(math.floor(trackHeight * 0.72), 90, trackHeight)
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
		90,
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
		14,
		thumbHeight
	)
	scrollThumb.Position = UDim2.fromOffset(
		math.floor((SCROLL_TRACK_WIDTH - 14) * 0.5),
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

local function updateSortTab(mode, button)
	local selected = activeSortMode == mode
	local image = selected
		and ASSETS.SelectedTab
		or ASSETS.UnselectedTab
	applyMappedArtwork(
		button,
		image,
		selected and CROP.SelectedTab or CROP.UnselectedTab
	)

	local labelText = mode
	if selected then
		labelText = mode
			.. ": "
			.. (sortDescending and "High" or "Low")
	end
	local label = requireAuthoredChild(
		button,
		"Label",
		"TextLabel"
	)
	label.Text = labelText
	label.TextSize = selected and 36 or 39
end

local function bindSortTab(mode, button)
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
	updateSortTab("Rarity", rarityTab)
	updateSortTab("Value", valueTab)
end

bindSortTab("Rarity", rarityTab)
bindSortTab("Value", valueTab)

local function makeRow(entry, layoutOrder)
	local fish = entry.fish
	local rarity = normalizeRarity(fish.rarity)
	local rowAsset = ASSETS.Rows[rarity] or ASSETS.Rows.Common
	local rowCrop = CROP[rarity .. "Row"] or CROP.CommonRow

	local row = rowTemplate:Clone()
	row.Name = "FishRow_" .. tostring(fish.serial or entry.index)
	row.Visible = true
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.fromOffset(ROW_WIDTH, ROW_HEIGHT)
	row.Parent = list
	applyMappedArtwork(row, rowAsset, rowCrop)

	local fishImageId = getFishImage(fish)
	local icon = requireAuthoredChild(row, "FishIcon", "ImageLabel")
	local fallback = requireAuthoredChild(
		row,
		"MissingFishIcon",
		"TextLabel"
	)
	icon.Image = fishImageId
	icon.Visible = fishImageId ~= ""
	fallback.Visible = fishImageId == ""

	local rarityColor = getRarityColor(rarity)
	local fishName = tostring(fish.name or fish.id or "Fish")
	local name = requireAuthoredChild(row, "FishName", "TextLabel")
	name.Text = fishName .. " [" .. rarity .. "]"
	name.TextColor3 = rarityColor
	local value = requireAuthoredChild(row, "FishValue", "TextLabel")
	value.Text = "Sell value: "
		.. formatNumber(fish.value)
		.. " coins"

	local sellButton = requireAuthoredChild(
		row,
		"SellButton",
		"ImageButton"
	)
	sellButton.Position = UDim2.fromOffset(SELL_BUTTON_X, SELL_BUTTON_Y)
	sellButton.Size = UDim2.fromOffset(SELL_BUTTON_WIDTH, SELL_BUTTON_HEIGHT)
	addPressFeedback(sellButton)
	local sellText = requireAuthoredChild(
		sellButton,
		"Label",
		"TextLabel"
	)

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
		statusLabel.Text = "Loading fish..."
		statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		statusLabel.Size = UDim2.fromOffset(ROW_WIDTH, 140)
		statusLabel.LayoutOrder = 1
		statusLabel.Visible = true
		list.CanvasSize = UDim2.fromOffset(0, 140)
		scheduleScrollbarUpdate()
		return
	end

	local entries = getSortedEntries()

	if #entries == 0 then
		statusLabel.Text = "No fish in your bag."
		statusLabel.TextColor3 = Color3.fromRGB(190, 210, 240)
		statusLabel.Size = UDim2.fromOffset(ROW_WIDTH, 150)
		statusLabel.LayoutOrder = 1
		statusLabel.Visible = true
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
