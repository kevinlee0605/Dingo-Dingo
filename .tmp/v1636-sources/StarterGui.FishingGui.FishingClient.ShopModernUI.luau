-- ShopModernUI_VISUAL_FIXED
-- ModuleScript location:
-- StarterGui > FishingGui > FishingClient > ShopModernUI
--
-- This module owns only the Shop visual layer. It stays outside FishingClient
-- so FishingClient remains below Luau's 200-local-per-function limit.

local ShopModernUI = {}

local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BASE_WIDTH = 1448
local BASE_HEIGHT = 1086
local SHOP_SIZE_MULTIPLIER = 0.67
local SHOP_X = 0.50
local SHOP_Y = 0.4

-- Keep the custom blue scrollbar thumb visible even when a tab's contents
-- already fit inside the window.
local ALWAYS_SHOW_SCROLLBAR = true
local IDLE_SCROLL_THUMB_RATIO = 0.72

-- ============================================================
-- ITEMS / SEA STAR PACK LAYOUT TUNING
-- ============================================================

local SEA_STAR_ROW_HEIGHT = 154
local SEA_STAR_ICON_AREA_WIDTH = 196
local SEA_STAR_ICON_SIZE = 142
local SEA_STAR_TEXT_X = 228
local SEA_STAR_TITLE_Y = 18
local SEA_STAR_DESCRIPTION_Y = 65
local SEA_STAR_PRICE_Y = 104

local SEA_STAR_PACK_VISUALS = {
	{
		assetKey = "SeaStar1",
		title = "Starter Sea Star Pack",
		description = "Adds 60 Sea Stars.",
		iconSize = 132,
	},
	{
		assetKey = "SeaStar2",
		title = "Small Sea Star Pack",
		description = "Adds 130 Sea Stars.",
		iconSize = 146,
	},
	{
		assetKey = "SeaStar3",
		title = "Medium Sea Star Pack",
		description = "Adds 300 Sea Stars.",
		iconSize = 148,
	},
	{
		assetKey = "SeaStar4",
		title = "Large Sea Star Pack",
		description = "Adds 700 Sea Stars.",
		iconSize = 152,
	},
	{
		assetKey = "SeaStar5",
		title = "Huge Sea Star Pack",
		description = "Adds 1,500 Sea Stars.",
		iconSize = 154,
	},
}

local ASSETS = {
	MainBackbone = "rbxassetid://77079984837491",
	SubMainBackbone = "rbxassetid://120182750042631",
	IndividualUITab = "rbxassetid://127925036253260",
	SectionTab = "rbxassetid://131015417525927",
	SectionTabSelected = "rbxassetid://83228267224190",
	BlueButton = "rbxassetid://125521996931477",
	GreenButton = "rbxassetid://137614054152455",
	RedButton = "rbxassetid://79554836514436",
	ScrollBar = "rbxassetid://73367138577137",
	CloseButton = "rbxassetid://119322438066977",
	DecorationCastle = "rbxassetid://120613246130409",

	VipDailyReward = "rbxassetid://96068622781673",
	VipAnglerPass = "rbxassetid://138061692418651",
	AquariumDesignerPass = "rbxassetid://134252679867634",

	SmallLuckyBaitPack = "rbxassetid://96266529771108",
	MediumLuckyBaitPack = "rbxassetid://139023229463150",
	LargeLuckyBaitPack = "rbxassetid://78982257234804",

	-- Items 탭 Sea Star 단계별 이미지
	SeaStar1 = "rbxassetid://102284604663190",
	SeaStar2 = "rbxassetid://117069470404695",
	SeaStar3 = "rbxassetid://100112305279375",
	SeaStar4 = "rbxassetid://106402461053554",
	SeaStar5 = "rbxassetid://133154316279120",

	StarterCoinPack = "rbxassetid://119755475927257",
	SmallCoinPack = "rbxassetid://84487201357535",
	MediumCoinPack = "rbxassetid://120340267245808",
	LargeCoinPack = "rbxassetid://117952324689348",
	HugeCoinPack = "rbxassetid://81048476941918",

	SmallBagUpgrade = "rbxassetid://80091101944926",
	MediumBagUpgrade = "rbxassetid://111407932652412",
	LargeBagUpgrade = "rbxassetid://101921318471224",
}

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
	DecorationCastle = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(173, 66),
		size = Vector2.new(255, 250),
	},

	VipDailyReward = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 157),
		size = Vector2.new(614, 88),
	},
	VipAnglerPass = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 157),
		size = Vector2.new(614, 88),
	},
	AquariumDesignerPass = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 157),
		size = Vector2.new(614, 88),
	},
	SmallLuckyBaitPack = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 157),
		size = Vector2.new(614, 88),
	},
	MediumLuckyBaitPack = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 157),
		size = Vector2.new(614, 88),
	},
	LargeLuckyBaitPack = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 157),
		size = Vector2.new(614, 88),
	},
	SmallBagUpgrade = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 157),
		size = Vector2.new(614, 88),
	},
	MediumBagUpgrade = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 157),
		size = Vector2.new(614, 88),
	},
	LargeBagUpgrade = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 157),
		size = Vector2.new(614, 88),
	},
	StarterCoinPack = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(9, 174),
		size = Vector2.new(618, 98),
	},
	SmallCoinPack = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 172),
		size = Vector2.new(614, 99),
	},
	MediumCoinPack = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 170),
		size = Vector2.new(614, 85),
	},
	LargeCoinPack = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 176),
		size = Vector2.new(614, 88),
	},
	HugeCoinPack = {
		source = Vector2.new(632, 432),
		offset = Vector2.new(13, 180),
		size = Vector2.new(611, 90),
	},
}

local ui = {
	selectedTab = "Passes",
	active = false,

	itemsCleanupToken = 0,
	contentChildConnection = nil,
	legacyItemsConnection = nil,
}

local function disconnect(connection)
	if connection then
		connection:Disconnect()
	end
end

local function makeArtwork(parent, imageId, crop, zIndex)
	local artwork = Instance.new("ImageLabel")
	artwork.Name = "Artwork"
	artwork.BackgroundTransparency = 1
	artwork.BorderSizePixel = 0
	artwork.Image = imageId or ""
	artwork.ScaleType = Enum.ScaleType.Stretch
	artwork.ZIndex = zIndex or 202
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
	crop,
	position,
	size,
	zIndex
)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Position = position or UDim2.fromScale(0, 0)
	holder.Size = size or UDim2.fromScale(1, 1)
	holder.ClipsDescendants = crop ~= nil
	holder.ZIndex = zIndex or 202
	holder.Parent = parent

	makeArtwork(holder, imageId, crop, zIndex)

	return holder
end

local function makePlainImage(
	parent,
	name,
	imageId,
	position,
	size,
	zIndex
)
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = imageId or ""
	image.Position = position or UDim2.fromScale(0, 0)
	image.Size = size or UDim2.fromScale(1, 1)
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = zIndex or 210
	image.Parent = parent

	return image
end

local function makeImageButton(
	parent,
	name,
	imageId,
	crop,
	position,
	size,
	zIndex,
	active
)
	local button = Instance.new("ImageButton")
	button.Name = name
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Image = ""
	button.AutoButtonColor = false
	button.Active = active ~= false
	button.Selectable = active ~= false
	button.Position = position or UDim2.fromScale(0, 0)
	button.Size = size or UDim2.fromScale(1, 1)
	button.ClipsDescendants = crop ~= nil
	button.ZIndex = zIndex or 210
	button.Parent = parent

	makeArtwork(button, imageId, crop, zIndex)

	return button
end

local function makeText(
	context,
	parent,
	text,
	size,
	color,
	bold
)
	local label = context.makeText(
		parent,
		text,
		size,
		color,
		bold
	)

	label.ZIndex = 216

	return label
end

local function addPressFeedback(button)
	local originalPosition = button.Position
	local originalSize = button.Size
	local artwork = button:FindFirstChild("Artwork")

	button.InputBegan:Connect(function(input)
		if not button.Active then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			TweenService:Create(
				button,
				TweenInfo.new(0.06),
				{
					Position = UDim2.new(
						originalPosition.X.Scale,
						originalPosition.X.Offset + 3,
						originalPosition.Y.Scale,
						originalPosition.Y.Offset + 3
					),
					Size = UDim2.new(
						originalSize.X.Scale,
						originalSize.X.Offset - 6,
						originalSize.Y.Scale,
						originalSize.Y.Offset - 6
					),
				}
			):Play()

			if artwork then
				artwork.ImageTransparency = 0.12
			end
		end
	end)

	local function release()
		TweenService:Create(
			button,
			TweenInfo.new(0.06),
			{
				Position = originalPosition,
				Size = originalSize,
			}
		):Play()

		if artwork then
			artwork.ImageTransparency = 0
		end
	end

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			release()
		end
	end)

	button.MouseLeave:Connect(release)
end

local function clearRenderedChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout")
			and not child:IsA("UIPadding")
		then
			child:Destroy()
		end
	end
end

local function captureOriginal(context)
	if ui.original then
		return
	end

	local panel = context.panel
	local content = context.parent

	local constraint = context.panelConstraint
		or panel:FindFirstChildOfClass("UISizeConstraint")

	ui.original = {
		panel = panel,
		content = content,
		constraint = constraint,

		panelAnchorPoint = panel.AnchorPoint,
		panelPosition = panel.Position,
		panelSize = panel.Size,
		panelBackgroundColor3 = panel.BackgroundColor3,
		panelBackgroundTransparency = panel.BackgroundTransparency,
		panelClipsDescendants = panel.ClipsDescendants,
		panelZIndex = panel.ZIndex,

		contentPosition = content.Position,
		contentSize = content.Size,
		contentZIndex = content.ZIndex,
		contentScrollBarThickness = content.ScrollBarThickness,
		contentScrollBarImageColor3 = content.ScrollBarImageColor3,
		contentScrollBarImageTransparency = content.ScrollBarImageTransparency,
		contentVerticalScrollBarInset = content.VerticalScrollBarInset,
		contentAutomaticCanvasSize = content.AutomaticCanvasSize,
		contentCanvasSize = content.CanvasSize,
		contentBackgroundTransparency = content.BackgroundTransparency,

		panelTitleVisible =
			context.panelTitle
			and context.panelTitle.Visible,

		panelCloseVisible =
			context.panelClose
			and context.panelClose.Visible,

		strokes = {},
	}

	if constraint then
		ui.original.constraintMinSize = constraint.MinSize
		ui.original.constraintMaxSize = constraint.MaxSize
	end

	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("UIStroke") then
			ui.original.strokes[child] =
				child.Transparency
		end
	end
end

local function updateScale()
	if not ui.scale then
		return
	end

	local camera = Workspace.CurrentCamera

	local viewport =
		camera
		and camera.ViewportSize
		or Vector2.new(1920, 1080)

	local fit = math.min(
		(viewport.X * 0.985) / BASE_WIDTH,
		(viewport.Y * 0.975) / BASE_HEIGHT
	)

	ui.scale.Scale = math.clamp(
		fit * SHOP_SIZE_MULTIPLIER,
		0.30,
		1.00
	)
end

local function restoreOriginal()
	if not ui.original then
		return
	end

	ui.active = false

	ui.itemsCleanupToken =
		(ui.itemsCleanupToken or 0) + 1

	disconnect(ui.viewportConnection)
	disconnect(ui.titleConnection)
	disconnect(ui.panelVisibleConnection)
	disconnect(ui.canvasConnection)
	disconnect(ui.canvasSizeConnection)
	disconnect(ui.windowSizeConnection)
	disconnect(ui.layoutConnection)
	disconnect(ui.thumbDragChangedConnection)
	disconnect(ui.thumbDragEndedConnection)
	disconnect(ui.contentChildConnection)
	disconnect(ui.legacyItemsConnection)

	ui.contentChildConnection = nil
	ui.legacyItemsConnection = nil

	if ui.skin then
		ui.skin:Destroy()
	end

	if ui.scale then
		ui.scale:Destroy()
	end

	local original = ui.original
	local panel = original.panel
	local content = original.content

	if panel and panel.Parent then
		panel.AnchorPoint = original.panelAnchorPoint
		panel.Position = original.panelPosition
		panel.Size = original.panelSize
		panel.BackgroundColor3 =
			original.panelBackgroundColor3
		panel.BackgroundTransparency =
			original.panelBackgroundTransparency
		panel.ClipsDescendants =
			original.panelClipsDescendants
		panel.ZIndex = original.panelZIndex
	end

	if content and content.Parent then
		content.Position = original.contentPosition
		content.Size = original.contentSize
		content.ZIndex = original.contentZIndex
		content.ScrollBarThickness =
			original.contentScrollBarThickness
		content.ScrollBarImageColor3 =
			original.contentScrollBarImageColor3
		content.ScrollBarImageTransparency =
			original.contentScrollBarImageTransparency
		content.VerticalScrollBarInset =
			original.contentVerticalScrollBarInset
		content.AutomaticCanvasSize =
			original.contentAutomaticCanvasSize
		content.CanvasSize =
			original.contentCanvasSize
		content.BackgroundTransparency =
			original.contentBackgroundTransparency
	end

	if original.constraint
		and original.constraint.Parent
	then
		original.constraint.MinSize =
			original.constraintMinSize

		original.constraint.MaxSize =
			original.constraintMaxSize
	end

	if ui.context
		and ui.context.panelTitle
	then
		ui.context.panelTitle.Visible =
			original.panelTitleVisible
	end

	if ui.context
		and ui.context.panelClose
	then
		ui.context.panelClose.Visible =
			original.panelCloseVisible
	end

	for stroke, transparency in pairs(
		original.strokes
		) do
		if stroke and stroke.Parent then
			stroke.Transparency = transparency
		end
	end

	ui.skin = nil
	ui.scale = nil
	ui.tabs = nil
	ui.scrollTrack = nil
	ui.scrollThumb = nil
	ui.layout = nil
	ui.padding = nil
	ui.context = nil
	ui.original = nil
	ui.draggingThumb = false
	ui.contentChildConnection = nil
	ui.legacyItemsConnection = nil
end

function ShopModernUI.hide()
	restoreOriginal()
end

local function getMaxCanvasY()
	if not ui.context then
		return 0
	end

	local content = ui.context.parent

	local layoutHeight =
		ui.layout
		and ui.layout.AbsoluteContentSize.Y
		or 0

	local canvasHeight = math.max(
		content.AbsoluteCanvasSize.Y,
		layoutHeight + 28
	)

	return math.max(
		0,
		canvasHeight - content.AbsoluteWindowSize.Y
	)
end

local function setCanvasY(value)
	if not ui.context then
		return
	end

	local content = ui.context.parent

	content.CanvasPosition = Vector2.new(
		0,
		math.clamp(
			value,
			0,
			getMaxCanvasY()
		)
	)
end

local function updateScrollbar()
	if not ui.context
		or not ui.scrollTrack
		or not ui.scrollThumb
	then
		return
	end

	local content = ui.context.parent
	local maxCanvasY = getMaxCanvasY()
	local trackHeight =
		ui.scrollTrack.AbsoluteSize.Y

	if maxCanvasY <= 1 then
		if ALWAYS_SHOW_SCROLLBAR then
			ui.scrollThumb.Visible = true
			ui.scrollThumb.Active = false
			ui.scrollThumb.Selectable = false

			local idleHeight = math.clamp(
				math.floor(
					trackHeight
						* IDLE_SCROLL_THUMB_RATIO
				),
				90,
				math.max(90, trackHeight)
			)

			ui.scrollThumb.Position =
				UDim2.fromOffset(1, 0)

			ui.scrollThumb.Size =
				UDim2.fromOffset(
					26,
					idleHeight
				)
		else
			ui.scrollThumb.Visible = false
		end

		return
	end

	ui.scrollThumb.Visible = true
	ui.scrollThumb.Active = true
	ui.scrollThumb.Selectable = true

	local contentHeight =
		maxCanvasY
		+ content.AbsoluteWindowSize.Y

	local ratio = math.clamp(
		content.AbsoluteWindowSize.Y
			/ math.max(1, contentHeight),
		0.12,
		1
	)

	local thumbHeight = math.max(
		90,
		math.floor(trackHeight * ratio)
	)

	local maxTravel = math.max(
		0,
		trackHeight - thumbHeight
	)

	local scrollRatio = math.clamp(
		content.CanvasPosition.Y / maxCanvasY,
		0,
		1
	)

	ui.scrollThumb.Position =
		UDim2.fromOffset(
			1,
			math.floor(
				maxTravel * scrollRatio
			)
		)

	ui.scrollThumb.Size =
		UDim2.fromOffset(
			26,
			thumbHeight
		)
end

local function setupScrollbarInteractions()
	local content = ui.context.parent

	ui.canvasConnection =
		content:GetPropertyChangedSignal(
			"CanvasPosition"
		):Connect(updateScrollbar)

	ui.canvasSizeConnection =
		content:GetPropertyChangedSignal(
			"AbsoluteCanvasSize"
		):Connect(updateScrollbar)

	ui.windowSizeConnection =
		content:GetPropertyChangedSignal(
			"AbsoluteWindowSize"
		):Connect(updateScrollbar)

	ui.layoutConnection =
		ui.layout:GetPropertyChangedSignal(
			"AbsoluteContentSize"
		):Connect(function()
		task.defer(updateScrollbar)
	end)

	ui.scrollThumb.InputBegan:Connect(
		function(input)
			if input.UserInputType
				== Enum.UserInputType.MouseButton1
				or input.UserInputType
				== Enum.UserInputType.Touch
			then
				ui.draggingThumb = true
				ui.dragInput = input
				ui.dragStartY = input.Position.Y

				ui.dragStartCanvasY =
					content.CanvasPosition.Y
			end
		end
	)

	ui.thumbDragChangedConnection =
		UserInputService.InputChanged:Connect(
			function(input)
				if not ui.draggingThumb then
					return
				end

				local currentY

				if ui.dragInput
					and ui.dragInput.UserInputType
					== Enum.UserInputType.Touch
				then
					if input ~= ui.dragInput then
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

				local activeTrackHeight =
				math.max(
					1,
					ui.scrollTrack.AbsoluteSize.Y
				)

				local thumbHeight =
				math.max(
					1,
					ui.scrollThumb.AbsoluteSize.Y
				)

				local maxTravel =
				math.max(
					1,
					activeTrackHeight
					- thumbHeight
				)

				local deltaY =
				currentY - ui.dragStartY

				setCanvasY(
					ui.dragStartCanvasY
					+ (
						(deltaY / maxTravel)
						* getMaxCanvasY()
					)
				)
			end
		)

	ui.thumbDragEndedConnection =
		UserInputService.InputEnded:Connect(
			function(input)
				if input == ui.dragInput
					or input.UserInputType
					== Enum.UserInputType.MouseButton1
				then
					ui.draggingThumb = false
					ui.dragInput = nil
				end
			end
		)

	ui.scrollTrack.InputBegan:Connect(
		function(input)
			if input.UserInputType
				~= Enum.UserInputType.MouseButton1
				and input.UserInputType
				~= Enum.UserInputType.Touch
			then
				return
			end

			if ui.draggingThumb then
				return
			end

			local localY =
				input.Position.Y
			- ui.scrollTrack.AbsolutePosition.Y

			local ratio = math.clamp(
				localY
					/ math.max(
						1,
						ui.scrollTrack.AbsoluteSize.Y
					),
				0,
				1
			)

			setCanvasY(
				getMaxCanvasY() * ratio
			)
		end
	)
end

local function buildShell(context)
	captureOriginal(context)

	ui.context = context
	ui.active = true

	local panel = context.panel
	local content = context.parent

	local constraint =
		context.panelConstraint
		or panel:FindFirstChildOfClass(
			"UISizeConstraint"
		)

	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(
		SHOP_X,
		SHOP_Y
	)
	panel.Size = UDim2.fromOffset(
		BASE_WIDTH,
		BASE_HEIGHT
	)
	panel.BackgroundTransparency = 1
	panel.ClipsDescendants = false
	panel.ZIndex = 200

	if constraint then
		constraint.MinSize = Vector2.new(0, 0)
		constraint.MaxSize =
			Vector2.new(5000, 5000)
	end

	for stroke in pairs(
		ui.original.strokes
		) do
		if stroke and stroke.Parent then
			stroke.Transparency = 1
		end
	end

	if context.panelTitle then
		context.panelTitle.Text = "SHOP"
		context.panelTitle.Visible = false
	end

	if context.panelClose then
		context.panelClose.Visible = false
	end

	ui.scale = Instance.new("UIScale")
	ui.scale.Name = "ModernShopScale"
	ui.scale.Parent = panel

	updateScale()

	local camera = Workspace.CurrentCamera

	if camera then
		ui.viewportConnection =
			camera:GetPropertyChangedSignal(
				"ViewportSize"
			):Connect(updateScale)
	end

	ui.skin = Instance.new("Frame")
	ui.skin.Name = "ModernShopSkin"
	ui.skin.BackgroundTransparency = 1
	ui.skin.Size = UDim2.fromScale(1, 1)
	ui.skin.ZIndex = 201
	ui.skin.Parent = panel

	makeImageHolder(
		ui.skin,
		"MainBackbone",
		ASSETS.MainBackbone,
		CROPS.MainBackbone,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(
			BASE_WIDTH,
			BASE_HEIGHT
		),
		201
	)

	makeImageHolder(
		ui.skin,
		"SubMainBackbone",
		ASSETS.SubMainBackbone,
		CROPS.SubMainBackbone,
		UDim2.fromOffset(34, 148),
		UDim2.fromOffset(1380, 890),
		202
	)

	makeImageHolder(
		ui.skin,
		"DecorationCastle",
		ASSETS.DecorationCastle,
		CROPS.DecorationCastle,
		UDim2.fromOffset(50, 18),
		UDim2.fromOffset(184, 132),
		206
	)

	local title = makeText(
		context,
		ui.skin,
		"SHOP",
		72,
		Color3.fromRGB(255, 255, 255),
		true
	)

	title.Position =
		UDim2.fromOffset(252, 34)

	title.Size =
		UDim2.fromOffset(560, 100)

	title.ZIndex = 207

	local closeButton = makeImageButton(
		ui.skin,
		"ModernShopClose",
		ASSETS.CloseButton,
		CROPS.CloseButton,
		UDim2.fromOffset(1285, 35),
		UDim2.fromOffset(105, 105),
		212,
		true
	)

	addPressFeedback(closeButton)

	closeButton.MouseButton1Click:Connect(
		function()
			local closeCallback =
				ui.context
				and ui.context.close

			restoreOriginal()

			if closeCallback then
				closeCallback()
			elseif panel and panel.Parent then
				panel.Visible = false
			end
		end
	)

	ui.tabs = Instance.new("Frame")
	ui.tabs.Name = "ModernShopTabs"
	ui.tabs.BackgroundTransparency = 1
	ui.tabs.Position =
		UDim2.fromOffset(63, 166)
	ui.tabs.Size =
		UDim2.fromOffset(1297, 82)
	ui.tabs.ZIndex = 208
	ui.tabs.Parent = ui.skin

	ui.scrollTrack = Instance.new("Frame")
	ui.scrollTrack.Name =
		"ModernShopScrollTrack"
	ui.scrollTrack.BackgroundColor3 =
		Color3.fromRGB(1, 19, 55)
	ui.scrollTrack.BackgroundTransparency =
		0.04
	ui.scrollTrack.BorderSizePixel = 0
	ui.scrollTrack.Position =
		UDim2.fromOffset(1333, 264)
	ui.scrollTrack.Size =
		UDim2.fromOffset(28, 738)
	ui.scrollTrack.Active = true
	ui.scrollTrack.ZIndex = 210
	ui.scrollTrack.Parent = ui.skin

	context.addCorner(
		ui.scrollTrack,
		14
	)

	local trackStroke = context.addStroke(
		ui.scrollTrack,
		Color3.fromRGB(0, 82, 190),
		2
	)

	if trackStroke then
		trackStroke.Transparency = 0.25
	end

	ui.scrollThumb = makeImageButton(
		ui.scrollTrack,
		"ModernShopScrollThumb",
		ASSETS.ScrollBar,
		CROPS.ScrollBar,
		UDim2.fromOffset(1, 0),
		UDim2.fromOffset(26, 210),
		213,
		true
	)

	content.Position =
		UDim2.fromOffset(58, 260)

	content.Size =
		UDim2.fromOffset(1260, 750)

	content.BackgroundTransparency = 1
	content.ZIndex = 205
	content.ScrollBarThickness = 0
	content.ScrollBarImageTransparency = 1
	content.VerticalScrollBarInset =
		Enum.ScrollBarInset.None
	content.AutomaticCanvasSize =
		Enum.AutomaticSize.Y
	content.CanvasSize =
		UDim2.fromOffset(0, 0)
	content.ScrollingDirection =
		Enum.ScrollingDirection.Y
	content.Active = true
	content.ScrollingEnabled = true
	content.ClipsDescendants = true

	ui.layout =
		content:FindFirstChildOfClass(
			"UIListLayout"
		)

	if not ui.layout then
		ui.layout =
			Instance.new("UIListLayout")

		ui.layout.Parent = content
	end

	ui.layout.FillDirection =
		Enum.FillDirection.Vertical

	ui.layout.HorizontalAlignment =
		Enum.HorizontalAlignment.Center

	ui.layout.SortOrder =
		Enum.SortOrder.LayoutOrder

	ui.layout.Padding =
		UDim.new(0, 10)

	ui.padding =
		content:FindFirstChildOfClass(
			"UIPadding"
		)

	if not ui.padding then
		ui.padding =
			Instance.new("UIPadding")

		ui.padding.Parent = content
	end

	ui.padding.PaddingTop =
		UDim.new(0, 2)

	ui.padding.PaddingBottom =
		UDim.new(0, 24)

	ui.padding.PaddingLeft =
		UDim.new(0, 0)

	ui.padding.PaddingRight =
		UDim.new(0, 4)

	setupScrollbarInteractions()

	if context.panelTitle then
		ui.titleConnection =
			context.panelTitle:
			GetPropertyChangedSignal(
				"Text"
			):Connect(function()
			local value = string.lower(
				context.panelTitle.Text
					or ""
			)

			if ui.active
				and value ~= "shop"
			then
				task.defer(
					restoreOriginal
				)
			end
		end)
	end

	ui.panelVisibleConnection =
		panel:GetPropertyChangedSignal(
			"Visible"
		):Connect(function()
		if ui.active
			and not panel.Visible
		then
			task.defer(
				restoreOriginal
			)
		end
	end)
end

local function renderTabs(context)
	for _, child in ipairs(
		ui.tabs:GetChildren()
		) do
		child:Destroy()
	end

	local layout =
		Instance.new("UIListLayout")

	layout.FillDirection =
		Enum.FillDirection.Horizontal

	layout.HorizontalAlignment =
		Enum.HorizontalAlignment.Left

	layout.VerticalAlignment =
		Enum.VerticalAlignment.Center

	layout.Padding =
		UDim.new(0, 11)

	layout.SortOrder =
		Enum.SortOrder.LayoutOrder

	layout.Parent = ui.tabs

	for order, tabName in ipairs({
		"Passes",
		"Items",
		"Coins",
		"Upgrades",
		}) do
		local selected =
			ui.selectedTab == tabName

		local imageKey =
			selected
			and "SectionTabSelected"
			or "SectionTab"

		local button = makeImageButton(
			ui.tabs,
			tabName .. "Tab",
			ASSETS[imageKey],
			CROPS[imageKey],
			UDim2.fromOffset(0, 0),
			UDim2.fromOffset(316, 78),
			210,
			true
		)

		button.LayoutOrder = order

		addPressFeedback(button)

		local label = makeText(
			context,
			button,
			tabName,
			34,
			Color3.fromRGB(
				255,
				255,
				255
			),
			true
		)

		label.AnchorPoint =
			Vector2.new(0.5, 0.5)

		label.Position =
			UDim2.fromScale(0.5, 0.5)

		label.Size =
			UDim2.new(1, -28, 1, -20)

		label.TextXAlignment =
			Enum.TextXAlignment.Center

		label.ZIndex = 215

		button.MouseButton1Click:Connect(
			function()
				if ui.selectedTab
					== tabName
				then
					return
				end

				ui.selectedTab = tabName

				context.parent.CanvasPosition =
					Vector2.new(0, 0)

				ShopModernUI.render(context)
			end
		)
	end
end

local function makeActionButton(
	context,
	parent,
	action
)
	local imageKey =
		action.type or "BlueButton"

	local textSize = 34

	if action.text == "Unavailable" then
		textSize = 27
	elseif action.text == "Claimed" then
		textSize = 31
	end

	local button = makeImageButton(
		parent,
		action.text .. "ActionButton",
		ASSETS[imageKey],
		CROPS[imageKey],
		UDim2.new(1, -258, 0.5, -43),
		UDim2.fromOffset(235, 86),
		214,
		action.enabled == true
	)

	button.AutoButtonColor = false

	local label = makeText(
		context,
		button,
		action.text,
		textSize,
		Color3.fromRGB(255, 255, 255),
		true
	)

	label.AnchorPoint =
		Vector2.new(0.5, 0.5)

	label.Position =
		UDim2.fromScale(0.5, 0.5)

	label.Size =
		UDim2.new(1, -32, 1, -18)

	label.TextXAlignment =
		Enum.TextXAlignment.Center

	label.ZIndex = 218

	if action.enabled
		and action.onClick
	then
		addPressFeedback(button)

		button.MouseButton1Click:Connect(
			action.onClick
		)
	end

	return button
end

local function createImageRow(
	context,
	options
)
	local holder = Instance.new("Frame")
	holder.Name = options.key .. "Row"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.new(
		1,
		-6,
		0,
		options.height or 176
	)
	holder.LayoutOrder =
		options.layoutOrder or 1
	holder.ZIndex = 207
	holder.Parent = context.parent

	makeImageHolder(
		holder,
		"RowArtwork",
		ASSETS[options.key],
		CROPS[options.key],
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		207
	)

	local title = makeText(
		context,
		holder,
		options.title,
		options.titleSize or 38,
		Color3.fromRGB(255, 255, 255),
		true
	)

	title.Position =
		UDim2.fromOffset(228, 24)

	title.Size =
		UDim2.new(1, -520, 0, 48)

	title.ZIndex = 216

	local detailY = 74

	if options.description
		and options.description ~= ""
	then
		local description = makeText(
			context,
			holder,
			options.description,
			23,
			Color3.fromRGB(
				178,
				194,
				235
			),
			false
		)

		description.Position =
			UDim2.fromOffset(
				228,
				detailY
			)

		description.Size = UDim2.new(
			1,
			-520,
			0,
			options.descriptionLines == 2
				and 56
				or 32
		)

		description.TextWrapped =
			options.descriptionLines == 2

		description.ZIndex = 216

		detailY +=
			options.descriptionLines == 2
			and 58
			or 36
	end

	if options.priceText
		and options.priceText ~= ""
	then
		local price = makeText(
			context,
			holder,
			options.priceText,
			24,
			Color3.fromRGB(
				255,
				216,
				59
			),
			true
		)

		price.Position =
			UDim2.fromOffset(
				228,
				detailY
			)

		price.Size =
			UDim2.new(1, -520, 0, 32)

		price.ZIndex = 216
	end

	makeActionButton(
		context,
		holder,
		options.action
	)

	return holder
end

local function createSeaStarRow(
	context,
	options
)
	local holder = Instance.new("Frame")
	holder.Name = options.assetKey .. "Row"
	holder.BackgroundColor3 =
		Color3.fromRGB(3, 18, 52)
	holder.BackgroundTransparency = 0.02
	holder.BorderSizePixel = 0
	holder.Size = UDim2.new(
		1,
		-6,
		0,
		SEA_STAR_ROW_HEIGHT
	)
	holder.LayoutOrder =
		options.layoutOrder or 1
	holder.ZIndex = 207

	holder:SetAttribute(
		"ModernShopOwned",
		true
	)

	holder.Parent = context.parent

	context.addCorner(holder, 17)

	local rowStroke = context.addStroke(
		holder,
		Color3.fromRGB(0, 78, 205),
		2
	)

	if rowStroke then
		rowStroke.Transparency = 0.56
	end

	local rowGradient =
		Instance.new("UIGradient")

	rowGradient.Color = ColorSequence.new(
		Color3.fromRGB(5, 28, 72),
		Color3.fromRGB(1, 12, 38)
	)

	rowGradient.Rotation = 0
	rowGradient.Parent = holder

	local iconArea = Instance.new("Frame")
	iconArea.Name = "IconArea"
	iconArea.BackgroundColor3 =
		Color3.fromRGB(1, 15, 43)
	iconArea.BackgroundTransparency = 0.08
	iconArea.BorderSizePixel = 0
	iconArea.Position =
		UDim2.fromOffset(0, 0)
	iconArea.Size = UDim2.fromOffset(
		SEA_STAR_ICON_AREA_WIDTH,
		SEA_STAR_ROW_HEIGHT
	)
	iconArea.ZIndex = 208
	iconArea.Parent = holder

	context.addCorner(iconArea, 17)

	local iconStroke = context.addStroke(
		iconArea,
		Color3.fromRGB(0, 65, 172),
		1
	)

	if iconStroke then
		iconStroke.Transparency = 0.78
	end

	local iconSize =
		options.iconSize
		or SEA_STAR_ICON_SIZE

	local icon = makePlainImage(
		iconArea,
		"SeaStarIcon",
		ASSETS[options.assetKey],
		UDim2.fromOffset(
			math.floor(
				(
					SEA_STAR_ICON_AREA_WIDTH
					- iconSize
				) / 2
			),
			math.floor(
				(
					SEA_STAR_ROW_HEIGHT
					- iconSize
				) / 2
			)
		),
		UDim2.fromOffset(
			iconSize,
			iconSize
		),
		212
	)

	icon.ImageTransparency = 0

	local title = makeText(
		context,
		holder,
		options.title,
		36,
		Color3.fromRGB(255, 255, 255),
		true
	)

	title.Position = UDim2.fromOffset(
		SEA_STAR_TEXT_X,
		SEA_STAR_TITLE_Y
	)

	title.Size =
		UDim2.new(1, -520, 0, 45)

	title.TextXAlignment =
		Enum.TextXAlignment.Left

	title.ZIndex = 216

	local description = makeText(
		context,
		holder,
		options.description,
		23,
		Color3.fromRGB(178, 194, 235),
		false
	)

	description.Position =
		UDim2.fromOffset(
			SEA_STAR_TEXT_X,
			SEA_STAR_DESCRIPTION_Y
		)

	description.Size =
		UDim2.new(1, -520, 0, 31)

	description.TextXAlignment =
		Enum.TextXAlignment.Left

	description.ZIndex = 216

	local price = makeText(
		context,
		holder,
		options.priceText,
		24,
		Color3.fromRGB(255, 216, 59),
		true
	)

	price.Position =
		UDim2.fromOffset(
			SEA_STAR_TEXT_X,
			SEA_STAR_PRICE_Y
		)

	price.Size =
		UDim2.new(1, -520, 0, 31)

	price.TextXAlignment =
		Enum.TextXAlignment.Left

	price.ZIndex = 216

	makeActionButton(
		context,
		holder,
		options.action
	)

	return holder
end

local function createSummaryRow(
	context,
	titleText,
	detailText,
	layoutOrder
)
	local holder = Instance.new("Frame")
	holder.Name = "ShopSummaryRow"
	holder.BackgroundColor3 =
		Color3.fromRGB(4, 23, 57)
	holder.BackgroundTransparency = 0.10
	holder.BorderSizePixel = 0
	holder.Size =
		UDim2.new(1, -6, 0, 122)
	holder.LayoutOrder = layoutOrder
	holder.ZIndex = 207
	holder.Parent = context.parent

	context.addCorner(holder, 17)

	local stroke = context.addStroke(
		holder,
		Color3.fromRGB(0, 105, 238),
		2
	)

	if stroke then
		stroke.Transparency = 0.18
	end

	local title = makeText(
		context,
		holder,
		titleText,
		34,
		Color3.fromRGB(255, 255, 255),
		true
	)

	title.Position =
		UDim2.fromOffset(28, 18)

	title.Size =
		UDim2.new(1, -56, 0, 44)

	local detail = makeText(
		context,
		holder,
		detailText,
		25,
		Color3.fromRGB(181, 197, 235),
		false
	)

	detail.Position =
		UDim2.fromOffset(28, 67)

	detail.Size =
		UDim2.new(1, -56, 0, 34)
end

local function ownsGamePass(
	state,
	passKey
)
	local monetization =
		state
		and state.Monetization
		or {}

	local owned =
		monetization.OwnedGamePasses
		or {}

	return owned[passKey] == true
end

local robuxPriceCache = {}

local function formatRobux(
	item,
	infoType
)
	local itemId =
		tonumber(item.id)
		or tonumber(item.Id)

	local fallbackPrice =
		tonumber(item.priceRobux)
		or tonumber(item.Price)

	if not itemId or itemId <= 0 then
		return tostring(
			fallbackPrice or "?"
		) .. " Robux"
	end

	infoType =
		infoType
		or Enum.InfoType.GamePass

	local cacheKey =
		tostring(infoType)
		.. ":"
		.. tostring(itemId)

	local cachedPrice =
		robuxPriceCache[cacheKey]

	if cachedPrice == nil then
		local success, productInfo =
			pcall(function()
				return MarketplaceService:
				GetProductInfo(
					itemId,
					infoType
				)
			end)

		cachedPrice =
			success
			and type(productInfo) == "table"
			and tonumber(
				productInfo.PriceInRobux
			)
			or fallbackPrice

		robuxPriceCache[cacheKey] =
			cachedPrice
	end

	return tostring(
		cachedPrice or "?"
	) .. " Robux"
end

local function gamePassAction(
	context,
	passKey
)
	if ownsGamePass(
		context.state,
		passKey
		) then
		return {
			text = "Owned",
			type = "BlueButton",
			enabled = false,
		}
	end

	return {
		text = "Buy",
		type = "GreenButton",
		enabled = true,

		onClick = function()
			context.fireShopAction(
				"PromptGamePass",
				"GamePass",
				passKey
			)
		end,
	}
end

local function vipRewardAction(context)
	local monetization =
		context.state
		and context.state.Monetization
		or {}

	if not ownsGamePass(
		context.state,
		"VipAngler"
		) then
		return {
			text = "Unavailable",
			type = "RedButton",
			enabled = false,
		}
	end

	if monetization.VipRewardAvailable
		== true
	then
		return {
			text = "Claim",
			type = "GreenButton",
			enabled = true,

			onClick = function()
				context.fireShopAction(
					"ClaimVipReward",
					"GamePass",
					"VipAngler"
				)
			end,
		}
	end

	return {
		text = "Claimed",
		type = "BlueButton",
		enabled = false,
	}
end

local function renderPasses(context)
	local order = 1

	createImageRow(context, {
		key = "VipDailyReward",
		layoutOrder = order,
		height = 172,
		title = "VIP Daily Reward",

		description =
			"5 Fresh Bait + 2 Lucky Bait once per day.",

		action = vipRewardAction(context),
	})

	order += 1

	local passImages = {
		VipAngler = "VipAnglerPass",

		AquariumDesigner =
			"AquariumDesignerPass",
	}

	for _, passKey in ipairs({
		"VipAngler",
		"AquariumDesigner",
		}) do
		local pass =
			context.MonetizationConfig
			.GamePasses[passKey]

		if pass then
			createImageRow(context, {
				key = passImages[passKey],
				layoutOrder = order,
				height = 190,
				title = pass.name,
				description = pass.description,
				descriptionLines = 2,

				priceText = formatRobux(
					pass,
					Enum.InfoType.GamePass
				),

				action =
					gamePassAction(
						context,
						passKey
					),
			})

			order += 1
		end
	end
end

local function getProductText(
	productKey,
	product
)
	return string.lower(
		tostring(productKey)
			.. " "
			.. tostring(
				product
				and (
					product.name
					or product.Name
				)
				or ""
			)
			.. " "
			.. tostring(
				product
				and (
					product.description
					or product.Description
				)
				or ""
			)
			.. " "
			.. tostring(
				product
				and (
					product.amount
					or product.Amount
					or product.rewardAmount
					or product.RewardAmount
					or product.seaStars
					or product.SeaStars
				)
				or ""
			)
	)
end

local function isSeaStarText(text)
	return string.find(
		text,
		"sea star",
		1,
		true
	) ~= nil
		or string.find(
			text,
			"seastar",
			1,
			true
		) ~= nil
		or string.find(
			text,
			"sea_star",
			1,
			true
		) ~= nil
end

local function getSeaStarTierIndex(
	productKey,
	product
)
	local text =
		getProductText(
			productKey,
			product
		)

	local compact =
		string.gsub(text, ",", "")

	local amount = tonumber(
		string.match(
			compact,
			"(%d+)%s*sea%s*stars"
		)
			or string.match(
				compact,
				"(%d+)%s*seastars"
			)
	)

	if string.find(
		text,
		"starter",
		1,
		true
		) or amount == 60 then
		return 1
	elseif string.find(
		text,
		"small",
		1,
		true
		) or amount == 130 then
		return 2
	elseif string.find(
		text,
		"medium",
		1,
		true
		) or amount == 300 then
		return 3
	elseif string.find(
		text,
		"large",
		1,
		true
		) or amount == 700 then
		return 4
	elseif string.find(
		text,
		"huge",
		1,
		true
		) or amount == 1500 then
		return 5
	end

	return nil
end

local function collectSeaStarProducts(
	context
)
	local config =
		context.MonetizationConfig or {}

	local candidates = {}
	local seenKeys = {}

	local function addCandidate(
		productKey,
		product,
		forceSeaStar
	)
		if productKey == nil
			or type(product) ~= "table"
		then
			return
		end

		local resolvedKey =
			product.productKey
			or product.ProductKey
			or product.key
			or product.Key
			or productKey

		local identity =
			tostring(resolvedKey)

		if seenKeys[identity] then
			return
		end

		local text =
			getProductText(
				resolvedKey,
				product
			)

		if not forceSeaStar
			and not isSeaStarText(text)
		then
			return
		end

		seenKeys[identity] = true

		table.insert(candidates, {
			key = resolvedKey,
			product = product,

			tier =
				getSeaStarTierIndex(
					resolvedKey,
					product
				),
		})
	end

	local productTables = {
		config.DeveloperProducts,
		config.SeaStarProducts,
		config.SeaStarPacks,
		config.ItemProducts,
	}

	local function findProduct(productKey)
		for _, productTable in ipairs(
			productTables
			) do
			if type(productTable) == "table"
				and type(
					productTable[productKey]
				) == "table"
			then
				return productTable[
				productKey
				]
			end
		end

		return nil
	end

	for _, orderName in ipairs({
		"SeaStarProductOrder",
		"SeaStarsProductOrder",
		"SeaStarPackOrder",
		"SeaStarsPackOrder",
		}) do
		local orderList =
			config[orderName]

		if type(orderList) == "table" then
			for _, productKey in ipairs(
				orderList
				) do
				addCandidate(
					productKey,
					findProduct(productKey),
					true
				)
			end
		end
	end

	for _, productKey in ipairs(
		config.DeveloperProductOrder
			or {}
		) do
		addCandidate(
			productKey,
			findProduct(productKey),
			false
		)
	end

	for _, productTable in ipairs(
		productTables
		) do
		if type(productTable) == "table" then
			for productKey, product in pairs(
				productTable
				) do
				addCandidate(
					productKey,
					product,
					false
				)
			end
		end
	end

	local visited = {}

	local function scanNested(
		value,
		depth
	)
		if type(value) ~= "table"
			or visited[value]
			or depth > 5
		then
			return
		end

		visited[value] = true

		for productKey, product in pairs(
			value
			) do
			if type(product) == "table" then
				local looksLikeProduct =
					product.id ~= nil
					or product.Id ~= nil
					or product.priceRobux ~= nil
					or product.Price ~= nil
					or product.productKey ~= nil
					or product.ProductKey ~= nil

				if looksLikeProduct then
					addCandidate(
						productKey,
						product,
						false
					)
				end

				scanNested(
					product,
					depth + 1
				)
			end
		end
	end

	scanNested(config, 0)
	scanNested(context, 0)

	local tierEntries = {}
	local unassigned = {}

	for _, candidate in ipairs(
		candidates
		) do
		if candidate.tier
			and not tierEntries[
			candidate.tier
			]
		then
			tierEntries[
			candidate.tier
			] = candidate
		else
			table.insert(
				unassigned,
				candidate
			)
		end
	end

	local unassignedIndex = 1

	for tierIndex = 1,
		#SEA_STAR_PACK_VISUALS
	do
		if not tierEntries[tierIndex]
			and unassigned[
			unassignedIndex
			]
		then
			tierEntries[tierIndex] =
				unassigned[
			unassignedIndex
			]

			unassignedIndex += 1
		end
	end

	return tierEntries
end

local function renderItems(context)
	local tierEntries =
		collectSeaStarProducts(context)

	for index, visual in ipairs(
		SEA_STAR_PACK_VISUALS
		) do
		local entry =
			tierEntries[index]

		local productKey =
			entry and entry.key or nil

		local product =
			entry and entry.product or nil

		local available =
			productKey ~= nil
			and product ~= nil

		createSeaStarRow(context, {
			assetKey = visual.assetKey,
			layoutOrder = index,
			title = visual.title,
			description = visual.description,
			iconSize = visual.iconSize,

			priceText =
				available
				and formatRobux(
					product,
					Enum.InfoType.Product
				)
				or "Product not configured",

			action = {
				text =
					available
					and "Buy"
					or "Unavailable",

				type =
					available
					and "GreenButton"
					or "RedButton",

				enabled = available,

				onClick =
					available
					and function()
						context.fireShopAction(
							"PromptProduct",
							"Product",
							productKey
						)
					end
					or nil,
			},
		})
	end
end

local function isAllowedItemsChild(
	child
)
	return child:IsA("UIListLayout")
		or child:IsA("UIPadding")
		or child:GetAttribute(
			"ModernShopOwned"
		) == true
end

-- 기존 FishingClient가 만드는 옛날 Sea Star UI 문구
local LEGACY_SEA_STAR_TEXT = {
	["sea star packs"] = true,
	["starter sea stars"] = true,
	["small sea stars"] = true,
	["medium sea stars"] = true,
	["large sea stars"] = true,
	["huge sea stars"] = true,
}

local function normalizeLegacyText(value)
	local text =
		string.lower(
			tostring(value or "")
		)

	text =
		string.gsub(
			text,
			"^%s+",
			""
		)

	text =
		string.gsub(
			text,
			"%s+$",
			""
		)

	return text
end

local function isLegacySeaStarTextObject(
	object
)
	if not object:IsA("TextLabel")
		and not object:IsA("TextButton")
		and not object:IsA("TextBox")
	then
		return false
	end

	return LEGACY_SEA_STAR_TEXT[
	normalizeLegacyText(
		object.Text
	)
	] == true
end

local function findLegacyRowRoot(
	object,
	context
)
	local current = object

	while current
		and current ~= context.panel
	do
		local parent = current.Parent

		if not parent then
			break
		end

		if parent == context.parent
			or parent:IsA("ScrollingFrame")
		then
			if current:IsA("GuiObject")
				and current ~= context.parent
			then
				return current
			end

			break
		end

		if parent == context.panel then
			if current:IsA("GuiObject")
				and current ~= ui.skin
			then
				return current
			end

			break
		end

		current = parent
	end

	return nil
end

-- ============================================================
-- OLD ITEMS UI SAFE SUPPRESSION
-- ============================================================

local function restoreItemsListLayout(
	context
)
	local layout =
		context.parent:
		FindFirstChildOfClass(
			"UIListLayout"
		)

	if layout then
		layout.FillDirection =
			Enum.FillDirection.Vertical

		layout.HorizontalAlignment =
			Enum.HorizontalAlignment.Center

		layout.SortOrder =
			Enum.SortOrder.LayoutOrder

		layout.Padding =
			UDim.new(0, 10)

		ui.layout = layout
	end

	local padding =
		context.parent:
		FindFirstChildOfClass(
			"UIPadding"
		)

	if padding then
		padding.PaddingTop =
			UDim.new(0, 2)

		padding.PaddingBottom =
			UDim.new(0, 24)

		padding.PaddingLeft =
			UDim.new(0, 0)

		padding.PaddingRight =
			UDim.new(0, 4)

		ui.padding = padding
	end
end

local function suppressLegacyGuiObject(
	object
)
	if not object
		or not object.Parent
		or not object:IsA("GuiObject")
		or object:GetAttribute(
			"ModernShopOwned"
		) == true
	then
		return
	end

	-- Destroy하지 않고 화면과 레이아웃에서만 제거한다.
	-- 기존 렌더러와 삭제/재생성 반복이 발생하지 않는다.
	object.Visible = false
	object.Active = false
	object.Selectable = false
	object.AutomaticSize =
		Enum.AutomaticSize.None
	object.Size =
		UDim2.fromOffset(0, 0)
	object.LayoutOrder = 1000000

	object:SetAttribute(
		"LegacySeaStarUISuppressed",
		true
	)
end

local function suppressLegacyItemsChild(
	child
)
	if not child
		or not child.Parent
		or isAllowedItemsChild(child)
	then
		return
	end

	suppressLegacyGuiObject(child)
end

local function suppressLegacyFromTextObject(
	object,
	context
)
	if not object
		or not object.Parent
		or not isLegacySeaStarTextObject(
			object
		)
	then
		return
	end

	local root =
		findLegacyRowRoot(
			object,
			context
		)

	if root then
		suppressLegacyGuiObject(root)
	else
		suppressLegacyGuiObject(object)
	end
end

local function purgeLegacyItemsContent(
	context
)
	if not ui.active
		or ui.selectedTab ~= "Items"
		or ui.context ~= context
		or not context.parent
	then
		return
	end

	-- 현재 Items ScrollingFrame에 들어온
	-- ModernShopOwned가 아닌 예전 자식들을 숨긴다.
	for _, child in ipairs(
		context.parent:GetChildren()
		) do
		suppressLegacyItemsChild(child)
	end

	-- 옛 UI가 다른 컨테이너나 중첩 Frame에 생성된 경우도
	-- 정확한 옛 문구를 기준으로 찾아 숨긴다.
	if context.panel
		and context.panel.Parent
	then
		for _, object in ipairs(
			context.panel:GetDescendants()
			) do
			if isLegacySeaStarTextObject(
				object
				) then
				suppressLegacyFromTextObject(
					object,
					context
				)
			end
		end
	end

	restoreItemsListLayout(context)
end

local function guardItemsContent(
	context
)
	disconnect(ui.contentChildConnection)
	disconnect(ui.legacyItemsConnection)

	ui.contentChildConnection = nil
	ui.legacyItemsConnection = nil

	ui.itemsCleanupToken =
		(ui.itemsCleanupToken or 0) + 1

	local cleanupToken =
		ui.itemsCleanupToken

	local function guardStillValid()
		return cleanupToken
			== ui.itemsCleanupToken
			and ui.active
			and ui.selectedTab == "Items"
			and ui.context == context
			and context.parent
			and context.parent.Parent
	end

	-- 이미 존재하는 옛 UI를 즉시 숨긴다.
	purgeLegacyItemsContent(context)

	-- 실제 목록의 직접 자식으로 늦게 추가되는
	-- 예전 Section/Row를 삭제하지 않고 숨긴다.
	ui.contentChildConnection =
		context.parent.ChildAdded:Connect(
			function(child)
				if not guardStillValid() then
					return
				end

				if isAllowedItemsChild(child) then
					return
				end

				suppressLegacyItemsChild(child)

				for _, delayTime in ipairs({
					0.03,
					0.10,
					0.30,
					0.75,
					1.50,
					3.00,
					}) do
					task.delay(
						delayTime,
						function()
							if not guardStillValid()
								or not child
								or not child.Parent
							then
								return
							end

							suppressLegacyItemsChild(
								child
							)

							restoreItemsListLayout(
								context
							)

							task.defer(
								updateScrollbar
							)
						end
					)
				end
			end
		)

	-- 옛 UI가 별도의 중첩 Frame이나 다른 컨테이너에
	-- 생성되는 경우, 정확한 옛 텍스트가 추가될 때만 처리한다.
	--
	-- 객체를 Destroy하지 않기 때문에 재생성 무한 반복이 없다.
	ui.legacyItemsConnection =
		context.panel.DescendantAdded:Connect(
			function(object)
				if not guardStillValid() then
					return
				end

				if not isLegacySeaStarTextObject(
					object
					) then
					return
				end

				suppressLegacyFromTextObject(
					object,
					context
				)

				for _, delayTime in ipairs({
					0.03,
					0.10,
					0.30,
					0.75,
					1.50,
					3.00,
					}) do
					task.delay(
						delayTime,
						function()
							if not guardStillValid()
								or not object
								or not object.Parent
							then
								return
							end

							suppressLegacyFromTextObject(
								object,
								context
							)

							task.defer(
								updateScrollbar
							)
						end
					)
				end
			end
		)

	-- 같은 프레임 경계에서 생성됐거나
	-- 외부 코드가 Visible/Size를 다시 설정하는 경우를
	-- 제한된 횟수로 다시 정리한다.
	for _, delayTime in ipairs({
		0,
		0.05,
		0.20,
		0.60,
		1.20,
		2.50,
		5.00,
		}) do
		task.delay(
			delayTime,
			function()
				if not guardStillValid() then
					return
				end

				purgeLegacyItemsContent(
					context
				)

				task.defer(
					updateScrollbar
				)
			end
		)
	end
end

local function renderCoins(context)
	local imageKeys = {
		StarterCoinPack =
			"StarterCoinPack",

		SmallCoinPack =
			"SmallCoinPack",

		MediumCoinPack =
			"MediumCoinPack",

		LargeCoinPack =
			"LargeCoinPack",

		HugeCoinPack =
			"HugeCoinPack",
	}

	local order = 1

	for _, productKey in ipairs(
		context.MonetizationConfig
			.CoinProductOrder
			or {}
		) do
		local product =
			context.MonetizationConfig
			.DeveloperProducts[
		productKey
		]

		if product then
			createImageRow(context, {
				key = imageKeys[
				productKey
				],

				layoutOrder = order,
				height = 158,
				title = product.name,

				description =
					product.description,

				priceText = formatRobux(
					product,
					Enum.InfoType.Product
				),

				action = {
					text = "Buy",
					type = "GreenButton",
					enabled = true,

					onClick = function()
						context.fireShopAction(
							"PromptProduct",
							"Product",
							productKey
						)
					end,
				},
			})

			order += 1
		end
	end
end

local function renderUpgrades(context)
	createSummaryRow(
		context,
		"Fish Bag Storage",
		string.format(
			"Current capacity: %d fish",
			context.state
				and context.state.BackpackSize
				or 0
		),
		1
	)

	local imageKeys = {
		SmallBag =
			"SmallBagUpgrade",

		MediumBag =
			"MediumBagUpgrade",

		LargeBag =
			"LargeBagUpgrade",
	}

	local order = 2

	for _, passKey in ipairs({
		"SmallBag",
		"MediumBag",
		"LargeBag",
		}) do
		local pass =
			context.MonetizationConfig
			.GamePasses[
		passKey
		]

		if pass then
			createImageRow(context, {
				key = imageKeys[passKey],
				layoutOrder = order,
				height = 178,
				title = pass.name,

				description =
					pass.description,

				priceText = formatRobux(
					pass,
					Enum.InfoType.GamePass
				),

				action =
					gamePassAction(
						context,
						passKey
					),
			})

			order += 1
		end
	end
end

function ShopModernUI.render(context)
	assert(
		type(context) == "table",
		"ShopModernUI.render needs context"
	)

	assert(
		context.parent,
		"ShopModernUI.render needs parent"
	)

	assert(
		context.panel,
		"ShopModernUI.render needs panel"
	)

	assert(
		context.MonetizationConfig,
		"ShopModernUI.render needs MonetizationConfig"
	)

	assert(
		context.fireShopAction,
		"ShopModernUI.render needs fireShopAction"
	)

	assert(
		context.makeText,
		"ShopModernUI.render needs makeText"
	)

	assert(
		context.addCorner,
		"ShopModernUI.render needs addCorner"
	)

	assert(
		context.addStroke,
		"ShopModernUI.render needs addStroke"
	)

	if not ui.active
		or ui.context ~= context
	then
		if ui.active then
			restoreOriginal()
		end

		buildShell(context)
	else
		ui.context = context
	end

	if context.panelTitle then
		context.panelTitle.Text = "SHOP"
	end

	disconnect(ui.contentChildConnection)
	disconnect(ui.legacyItemsConnection)

	ui.contentChildConnection = nil
	ui.legacyItemsConnection = nil

	ui.itemsCleanupToken =
		(ui.itemsCleanupToken or 0) + 1

	clearRenderedChildren(
		context.parent
	)

	ui.layout =
		context.parent:
		FindFirstChildOfClass(
			"UIListLayout"
		)

	ui.padding =
		context.parent:
		FindFirstChildOfClass(
			"UIPadding"
		)

	renderTabs(context)

	if ui.selectedTab == "Passes" then
		renderPasses(context)

	elseif ui.selectedTab == "Items" then
		renderItems(context)
		guardItemsContent(context)

	elseif ui.selectedTab == "Coins" then
		renderCoins(context)

	elseif ui.selectedTab == "Upgrades" then
		renderUpgrades(context)
	end

	task.defer(updateScrollbar)
	task.delay(0.05, updateScrollbar)
	task.delay(0.15, updateScrollbar)
end

return ShopModernUI