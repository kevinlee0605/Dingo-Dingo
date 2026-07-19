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
local SEA_STAR_ICON = "rbxassetid://139079837785295"

-- v1636 used a different, correctly fitted illustration for each Sea Star
-- product.  Keep those exact assets and icon sizes while cloning the authored
-- product-row template below.
local SEA_STAR_PACK_VISUALS = {
	{ image = "rbxassetid://102284604663190", iconSize = 132 },
	{ image = "rbxassetid://117069470404695", iconSize = 146 },
	{ image = "rbxassetid://100112305279375", iconSize = 148 },
	{ image = "rbxassetid://106402461053554", iconSize = 152 },
	{ image = "rbxassetid://133154316279120", iconSize = 154 },
}

local SEA_STAR_ROW_HEIGHT = 154
local SEA_STAR_ICON_AREA_WIDTH = 196
local SEA_STAR_TEXT_X = 228

local VALID_SHOP_TABS = {
	Passes = true,
	Items = true,
	Coins = true,
	Upgrades = true,
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

	-- The product images are complete row strips, not plain icons.
	-- Cropping the whole visible strip makes each row match the reference image.
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
	authoredUi = false,
	canvas = nil,
	templates = nil,
}

local function boundChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	if child and child:IsA(className) then
		return child
	end
	if ui.authoredUi then
		error(string.format(
			"[ShopModernUI] Missing authored node %s.%s (%s)",
			parent and parent:GetFullName() or "nil",
			name,
			className
		))
	end
	return nil
end

local function findScreenGui(instance)
	local current = instance
	while current do
		if current:IsA("ScreenGui") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function cloneTemplate(name)
	if not ui.authoredUi or not ui.templates then
		return nil
	end

	local template = ui.templates:FindFirstChild(name)
	assert(template, "[ShopModernUI] Missing authored template " .. name)

	return template:Clone()
end

local function disconnect(connection)
	if connection then
		connection:Disconnect()
	end
end

local function makeArtwork(parent, imageId, crop, zIndex)
	local artwork = boundChild(parent, "Artwork", "ImageLabel")
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
	local holder = boundChild(parent, name, "Frame")
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
	local button = boundChild(parent, name, "ImageButton")
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

local function addPressFeedback(button)
	if button:GetAttribute("ShopPressFeedbackBound") == true then
		return
	end
	button:SetAttribute("ShopPressFeedbackBound", true)

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
	local contentLayout = content:FindFirstChildOfClass("UIListLayout")
	local contentPadding = content:FindFirstChildOfClass("UIPadding")

	ui.original = {
		panel = panel,
		content = content,
		contentParent = content.Parent,
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
		contentCanvasPosition = content.CanvasPosition,
		contentBackgroundTransparency = content.BackgroundTransparency,
		contentClipsDescendants = content.ClipsDescendants,
		contentActive = content.Active,
		contentScrollingEnabled = content.ScrollingEnabled,
		contentScrollingDirection = content.ScrollingDirection,
		contentLayout = contentLayout,
		contentPadding = contentPadding,
		panelTitleVisible = context.panelTitle and context.panelTitle.Visible,
		panelCloseVisible = context.panelClose and context.panelClose.Visible,
		strokes = {},
		scales = {},
	}

	if constraint then
		ui.original.constraintMinSize = constraint.MinSize
		ui.original.constraintMaxSize = constraint.MaxSize
	end

	if contentLayout then
		ui.original.layoutFillDirection = contentLayout.FillDirection
		ui.original.layoutHorizontalAlignment = contentLayout.HorizontalAlignment
		ui.original.layoutVerticalAlignment = contentLayout.VerticalAlignment
		ui.original.layoutSortOrder = contentLayout.SortOrder
		ui.original.layoutPadding = contentLayout.Padding
	end

	if contentPadding then
		ui.original.paddingTop = contentPadding.PaddingTop
		ui.original.paddingBottom = contentPadding.PaddingBottom
		ui.original.paddingLeft = contentPadding.PaddingLeft
		ui.original.paddingRight = contentPadding.PaddingRight
	end

	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("UIStroke") then
			ui.original.strokes[child] = child.Transparency
		elseif child:IsA("UIScale") then
			ui.original.scales[child] = child.Scale
		end
	end
end

local function updateScale()
	if not ui.scale then
		return
	end

	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize
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

	disconnect(ui.viewportConnection)
	disconnect(ui.titleConnection)
	disconnect(ui.panelVisibleConnection)
	disconnect(ui.canvasConnection)
	disconnect(ui.canvasSizeConnection)
	disconnect(ui.windowSizeConnection)
	disconnect(ui.layoutConnection)
	disconnect(ui.thumbDragChangedConnection)
	disconnect(ui.thumbDragEndedConnection)

	if ui.skin and not ui.authoredUi then
		ui.skin:Destroy()
	end
	if ui.scale and not ui.authoredUi then
		ui.scale:Destroy()
	end
	if ui.authoredUi and ui.canvas then
		ui.canvas.Visible = false
	end

	local original = ui.original
	local panel = original.panel
	local content = original.content

	if panel and panel.Parent then
		panel.AnchorPoint = original.panelAnchorPoint
		panel.Position = original.panelPosition
		panel.Size = original.panelSize
		panel.BackgroundColor3 = original.panelBackgroundColor3
		panel.BackgroundTransparency = original.panelBackgroundTransparency
		panel.ClipsDescendants = original.panelClipsDescendants
		panel.ZIndex = original.panelZIndex
	end

	if content and content.Parent then
		if original.contentParent and original.contentParent.Parent then
			content.Parent = original.contentParent
		end
		content.Position = original.contentPosition
		content.Size = original.contentSize
		content.ZIndex = original.contentZIndex
		content.ScrollBarThickness = original.contentScrollBarThickness
		content.ScrollBarImageColor3 = original.contentScrollBarImageColor3
		content.ScrollBarImageTransparency = original.contentScrollBarImageTransparency
		content.VerticalScrollBarInset = original.contentVerticalScrollBarInset
		content.AutomaticCanvasSize = original.contentAutomaticCanvasSize
		content.CanvasSize = original.contentCanvasSize
		content.CanvasPosition = original.contentCanvasPosition
		content.BackgroundTransparency = original.contentBackgroundTransparency
		content.ClipsDescendants = original.contentClipsDescendants
		content.Active = original.contentActive
		content.ScrollingEnabled = original.contentScrollingEnabled
		content.ScrollingDirection = original.contentScrollingDirection
	end

	if original.contentLayout and original.contentLayout.Parent then
		original.contentLayout.FillDirection = original.layoutFillDirection
		original.contentLayout.HorizontalAlignment = original.layoutHorizontalAlignment
		original.contentLayout.VerticalAlignment = original.layoutVerticalAlignment
		original.contentLayout.SortOrder = original.layoutSortOrder
		original.contentLayout.Padding = original.layoutPadding
	end

	if original.contentPadding and original.contentPadding.Parent then
		original.contentPadding.PaddingTop = original.paddingTop
		original.contentPadding.PaddingBottom = original.paddingBottom
		original.contentPadding.PaddingLeft = original.paddingLeft
		original.contentPadding.PaddingRight = original.paddingRight
	elseif ui.padding and ui.padding.Parent then
		ui.padding:Destroy()
	end

	if original.constraint and original.constraint.Parent then
		original.constraint.MinSize = original.constraintMinSize
		original.constraint.MaxSize = original.constraintMaxSize
	end

	if ui.context and ui.context.panelTitle then
		ui.context.panelTitle.Visible = original.panelTitleVisible
	end
	if ui.context and ui.context.panelClose then
		ui.context.panelClose.Visible = original.panelCloseVisible
	end

	for stroke, transparency in pairs(original.strokes) do
		if stroke and stroke.Parent then
			stroke.Transparency = transparency
		end
	end
	for scale, value in pairs(original.scales) do
		if scale and scale.Parent then
			scale.Scale = value
		end
	end

	ui.skin = nil
	ui.scale = nil
	ui.canvas = nil
	ui.templates = nil
	ui.authoredUi = false
	ui.tabs = nil
	ui.scrollTrack = nil
	ui.scrollThumb = nil
	ui.layout = nil
	ui.padding = nil
	ui.context = nil
	ui.original = nil
	ui.draggingThumb = false
end

function ShopModernUI.hide()
	restoreOriginal()
end

function ShopModernUI.setSelectedTab(tabName)
	if type(tabName) ~= "string" or not VALID_SHOP_TABS[tabName] then
		return false
	end

	local changed = ui.selectedTab ~= tabName
	ui.selectedTab = tabName

	if changed and ui.active and ui.context then
		ui.context.parent.CanvasPosition = Vector2.new(0, 0)
		ShopModernUI.render(ui.context)
	end

	return true
end

local function getMaxCanvasY()
	if not ui.context then
		return 0
	end
	local content = ui.context.parent
	local layoutHeight = ui.layout and ui.layout.AbsoluteContentSize.Y or 0
	local canvasHeight = math.max(
		content.AbsoluteCanvasSize.Y,
		layoutHeight + 28
	)
	return math.max(0, canvasHeight - content.AbsoluteWindowSize.Y)
end

local function setCanvasY(value)
	if not ui.context then
		return
	end
	local content = ui.context.parent
	content.CanvasPosition = Vector2.new(
		0,
		math.clamp(value, 0, getMaxCanvasY())
	)
end

local function updateScrollbar()
	if not ui.context or not ui.scrollTrack or not ui.scrollThumb then
		return
	end

	local content = ui.context.parent
	local maxCanvasY = getMaxCanvasY()
	local trackHeight = ui.scrollTrack.AbsoluteSize.Y

	if maxCanvasY <= 1 then
		if ALWAYS_SHOW_SCROLLBAR then
			ui.scrollThumb.Visible = true
			ui.scrollThumb.Active = false
			ui.scrollThumb.Selectable = false

			local idleHeight = math.clamp(
				math.floor(trackHeight * IDLE_SCROLL_THUMB_RATIO),
				90,
				math.max(90, trackHeight)
			)

			ui.scrollThumb.Position = UDim2.fromOffset(1, 0)
			ui.scrollThumb.Size = UDim2.fromOffset(26, idleHeight)
		else
			ui.scrollThumb.Visible = false
		end
		return
	end

	ui.scrollThumb.Visible = true
	ui.scrollThumb.Active = true
	ui.scrollThumb.Selectable = true
	local contentHeight = maxCanvasY + content.AbsoluteWindowSize.Y
	local ratio = math.clamp(
		content.AbsoluteWindowSize.Y / math.max(1, contentHeight),
		0.12,
		1
	)
	local thumbHeight = math.max(90, math.floor(trackHeight * ratio))
	local maxTravel = math.max(0, trackHeight - thumbHeight)
	local scrollRatio = math.clamp(
		content.CanvasPosition.Y / maxCanvasY,
		0,
		1
	)

	ui.scrollThumb.Position = UDim2.fromOffset(
		1,
		math.floor(maxTravel * scrollRatio)
	)
	ui.scrollThumb.Size = UDim2.fromOffset(
		26,
		thumbHeight
	)
end

local function setupScrollbarInteractions()
	local content = ui.context.parent

	ui.canvasConnection = content:GetPropertyChangedSignal(
		"CanvasPosition"
	):Connect(updateScrollbar)
	ui.canvasSizeConnection = content:GetPropertyChangedSignal(
		"AbsoluteCanvasSize"
	):Connect(updateScrollbar)
	ui.windowSizeConnection = content:GetPropertyChangedSignal(
		"AbsoluteWindowSize"
	):Connect(updateScrollbar)
	ui.layoutConnection = ui.layout:GetPropertyChangedSignal(
		"AbsoluteContentSize"
	):Connect(function()
		task.defer(updateScrollbar)
	end)

	if ui.scrollThumb:GetAttribute("ShopThumbInputBound") ~= true then
		ui.scrollThumb:SetAttribute("ShopThumbInputBound", true)
		ui.scrollThumb.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				ui.draggingThumb = true
				ui.dragInput = input
				ui.dragStartY = input.Position.Y
				ui.dragStartCanvasY = content.CanvasPosition.Y
			end
		end)
	end

	ui.thumbDragChangedConnection = UserInputService.InputChanged:Connect(
		function(input)
			if not ui.draggingThumb then
				return
			end

			local currentY
			if ui.dragInput
				and ui.dragInput.UserInputType == Enum.UserInputType.Touch
			then
				if input ~= ui.dragInput then
					return
				end
				currentY = input.Position.Y
			elseif input.UserInputType == Enum.UserInputType.MouseMovement then
				currentY = input.Position.Y
			end

			if not currentY then
				return
			end

			local trackHeight = math.max(1, ui.scrollTrack.AbsoluteSize.Y)
			local thumbHeight = math.max(1, ui.scrollThumb.AbsoluteSize.Y)
			local maxTravel = math.max(1, trackHeight - thumbHeight)
			local deltaY = currentY - ui.dragStartY
			setCanvasY(
				ui.dragStartCanvasY
					+ ((deltaY / maxTravel) * getMaxCanvasY())
			)
		end
	)

	ui.thumbDragEndedConnection = UserInputService.InputEnded:Connect(
		function(input)
			if input == ui.dragInput
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				ui.draggingThumb = false
				ui.dragInput = nil
			end
		end
	)

	if ui.scrollTrack:GetAttribute("ShopTrackInputBound") ~= true then
		ui.scrollTrack:SetAttribute("ShopTrackInputBound", true)
		ui.scrollTrack.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			if ui.draggingThumb then
				return
			end
			local localY = input.Position.Y - ui.scrollTrack.AbsolutePosition.Y
			local ratio = math.clamp(
				localY / math.max(1, ui.scrollTrack.AbsoluteSize.Y),
				0,
				1
			)
			setCanvasY(getMaxCanvasY() * ratio)
		end)
	end
end

local function buildShell(context)
	captureOriginal(context)
	ui.context = context
	ui.active = true

	local panel = context.panel
	local content = context.parent
	local screenGui = findScreenGui(panel)
	ui.authoredUi = screenGui
		and screenGui:GetAttribute("AuthoredUiV2") == true
		and screenGui:FindFirstChild("MainPanel") == panel
	assert(ui.authoredUi, "[ShopModernUI] The authored MainPanel hierarchy is required")
	ui.templates = panel:FindFirstChild("ShopTemplates")
	assert(ui.templates and ui.templates:IsA("Folder"), "[ShopModernUI] MainPanel.ShopTemplates is missing")
	local constraint = context.panelConstraint
		or panel:FindFirstChildOfClass("UISizeConstraint")

	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.fromScale(0, 0)
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundTransparency = 1
	panel.ClipsDescendants = false
	panel.ZIndex = 200

	if constraint then
		constraint.MinSize = Vector2.new(0, 0)
		constraint.MaxSize = Vector2.new(5000, 5000)
	end

	for stroke in pairs(ui.original.strokes) do
		if stroke and stroke.Parent then
			stroke.Transparency = 1
		end
	end
	for panelScale in pairs(ui.original.scales) do
		if panelScale and panelScale.Parent then
			panelScale.Scale = 1
		end
	end

	if context.panelTitle then
		context.panelTitle.Text = "SHOP"
		context.panelTitle.Visible = false
	end
	if context.panelClose then
		context.panelClose.Visible = false
	end

	local canvas = boundChild(panel, "ShopCanvas", "Frame")
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(SHOP_X, SHOP_Y)
	canvas.Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel = 0
	canvas.ClipsDescendants = false
	canvas.Visible = true
	canvas.ZIndex = 200
	ui.canvas = canvas
	ui.scale = boundChild(canvas, "ModernShopScale", "UIScale")
	content.Parent = canvas
	updateScale()

	local camera = Workspace.CurrentCamera
	if camera then
		ui.viewportConnection = camera:GetPropertyChangedSignal(
			"ViewportSize"
		):Connect(updateScale)
	end

	ui.skin = boundChild(ui.canvas, "ModernShopSkin", "Frame")
	ui.skin.Name = "ModernShopSkin"
	ui.skin.BackgroundTransparency = 1
	ui.skin.Size = UDim2.fromScale(1, 1)
	ui.skin.ZIndex = 201
	ui.skin.Parent = ui.canvas

	makeImageHolder(
		ui.skin,
		"MainBackbone",
		ASSETS.MainBackbone,
		CROPS.MainBackbone,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT),
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

	local title = boundChild(ui.skin, "Title", "TextLabel")
	title.Text = "SHOP"
	title.TextSize = 72
	title.Position = UDim2.fromOffset(252, 34)
	title.Size = UDim2.fromOffset(560, 100)
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
	if closeButton:GetAttribute("ShopCloseBound") ~= true then
		closeButton:SetAttribute("ShopCloseBound", true)
		closeButton.MouseButton1Click:Connect(function()
			local closeCallback = ui.context and ui.context.close
			restoreOriginal()
			if closeCallback then
				closeCallback()
			elseif panel and panel.Parent then
				panel.Visible = false
			end
		end)
	end

	ui.tabs = boundChild(ui.skin, "ModernShopTabs", "Frame")
	ui.tabs.Name = "ModernShopTabs"
	ui.tabs.BackgroundTransparency = 1
	ui.tabs.Position = UDim2.fromOffset(63, 166)
	ui.tabs.Size = UDim2.fromOffset(1297, 82)
	ui.tabs.ZIndex = 208
	ui.tabs.Parent = ui.skin

	ui.scrollTrack = boundChild(ui.skin, "ModernShopScrollTrack", "Frame")
	ui.scrollTrack.Name = "ModernShopScrollTrack"
	ui.scrollTrack.BackgroundColor3 = Color3.fromRGB(1, 19, 55)
	ui.scrollTrack.BackgroundTransparency = 0.04
	ui.scrollTrack.BorderSizePixel = 0
	ui.scrollTrack.Position = UDim2.fromOffset(1333, 264)
	ui.scrollTrack.Size = UDim2.fromOffset(28, 738)
	ui.scrollTrack.Active = true
	ui.scrollTrack.ZIndex = 210
	ui.scrollTrack.Parent = ui.skin
	local trackCorner = ui.scrollTrack:FindFirstChildOfClass("UICorner")
	assert(trackCorner, "[ShopModernUI] ModernShopScrollTrack.UICorner is missing")
	trackCorner.CornerRadius = UDim.new(0, 14)
	local trackStroke = ui.scrollTrack:FindFirstChildOfClass("UIStroke")
	assert(trackStroke, "[ShopModernUI] ModernShopScrollTrack.UIStroke is missing")
	if trackStroke then
		trackStroke.Color = Color3.fromRGB(0, 82, 190)
		trackStroke.Thickness = 2
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

	content.Position = UDim2.fromOffset(58, 260)
	content.Size = UDim2.fromOffset(1260, 750)
	content.BackgroundTransparency = 1
	content.ZIndex = 205
	content.ScrollBarThickness = 0
	content.ScrollBarImageTransparency = 1
	content.VerticalScrollBarInset = Enum.ScrollBarInset.None
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.fromOffset(0, 0)
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.Active = true
	content.ScrollingEnabled = true
	content.ClipsDescendants = true

	ui.layout = content:FindFirstChildOfClass("UIListLayout")
	assert(ui.layout, "[ShopModernUI] Authored Content.UIListLayout is missing")
	ui.layout.FillDirection = Enum.FillDirection.Vertical
	ui.layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ui.layout.SortOrder = Enum.SortOrder.LayoutOrder
	ui.layout.Padding = UDim.new(0, 10)

	ui.padding = content:FindFirstChildOfClass("UIPadding")
	assert(ui.padding, "[ShopModernUI] Authored Content.UIPadding is missing")
	ui.padding.PaddingTop = UDim.new(0, 2)
	ui.padding.PaddingBottom = UDim.new(0, 24)
	ui.padding.PaddingLeft = UDim.new(0, 0)
	ui.padding.PaddingRight = UDim.new(0, 4)

	setupScrollbarInteractions()

	if context.panelTitle then
		ui.titleConnection = context.panelTitle:GetPropertyChangedSignal(
			"Text"
		):Connect(function()
			local value = string.lower(context.panelTitle.Text or "")
			if ui.active and value ~= "shop" then
				task.defer(restoreOriginal)
			end
		end)
	end

	ui.panelVisibleConnection = panel:GetPropertyChangedSignal(
		"Visible"
	):Connect(function()
		if ui.active and not panel.Visible then
			task.defer(restoreOriginal)
		end
	end)
end

local function renderTabs(context)
	for _, child in ipairs(ui.tabs:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local layout = boundChild(ui.tabs, "UIListLayout", "UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 11)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = ui.tabs

	for order, tabName in ipairs({
		"Passes",
		"Items",
		"Coins",
		"Upgrades",
		}) do
		local selected = ui.selectedTab == tabName
		local imageKey = selected
			and "SectionTabSelected"
			or "SectionTab"
		local button = cloneTemplate("ShopTabTemplate")
		button.Name = tabName .. "Tab"
		button.Visible = true
		button.Parent = ui.tabs
		makeArtwork(button, ASSETS[imageKey], CROPS[imageKey], 210)
		button.LayoutOrder = order
		addPressFeedback(button)

		local label = boundChild(button, "Label", "TextLabel")
		label.Text = tabName
		label.TextSize = 34
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.new(1, -28, 1, -20)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.ZIndex = 215

		button.MouseButton1Click:Connect(function()
			local changed = ui.selectedTab ~= tabName
			ShopModernUI.setSelectedTab(tabName)
			if changed and type(context.onSelectedTabChanged) == "function" then
				context.onSelectedTabChanged(tabName)
			end
		end)
	end
end

local function makeActionButton(context, parent, action)
	local imageKey = action.type or "BlueButton"
	local textSize = 34
	if action.text == "Unavailable" then
		textSize = 27
	elseif action.text == "Claimed" then
		textSize = 31
	end

	local button = boundChild(parent, "ActionButton", "ImageButton")
	button.Name = action.text .. "ActionButton"
	button.Active = action.enabled == true
	button.Selectable = action.enabled == true
	makeArtwork(button, ASSETS[imageKey], CROPS[imageKey], 214)
	button.AutoButtonColor = false

	local label = boundChild(button, "Label", "TextLabel")
	label.Text = action.text
	label.TextSize = textSize
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(1, -32, 1, -18)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = 218

	if action.enabled and action.onClick then
		addPressFeedback(button)
		button.MouseButton1Click:Connect(action.onClick)
	end

	return button
end

local function createImageRow(context, options)
	local holder = cloneTemplate("ShopItemCardTemplate")
	holder.Name = options.key .. "Row"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.new(1, -6, 0, options.height or 176)
	holder.LayoutOrder = options.layoutOrder or 1
	holder.Visible = true
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

	local title = boundChild(holder, "Title", "TextLabel")
	title.Text = options.title
	title.TextSize = options.titleSize or 38
	title.Visible = true
	title.Position = UDim2.fromOffset(228, 24)
	title.Size = UDim2.new(1, -520, 0, 48)
	title.ZIndex = 216

	local detailY = 74
	local description = boundChild(holder, "Description", "TextLabel")
	if options.description and options.description ~= "" then
		description.Text = options.description
		description.TextSize = 23
		description.Position = UDim2.fromOffset(228, detailY)
		description.Size = UDim2.new(1, -520, 0, options.descriptionLines == 2 and 56 or 32)
		description.TextWrapped = options.descriptionLines == 2
		description.Visible = true
		description.ZIndex = 216
		detailY += options.descriptionLines == 2 and 58 or 36
	elseif description then
		description.Visible = false
	end

	local price = boundChild(holder, "Price", "TextLabel")
	if options.priceText and options.priceText ~= "" then
		price.Text = options.priceText
		price.TextSize = 24
		price.Position = UDim2.fromOffset(228, detailY)
		price.Size = UDim2.new(1, -520, 0, 32)
		price.Visible = true
		price.ZIndex = 216
	elseif price then
		price.Visible = false
	end

	makeActionButton(context, holder, options.action)
	return holder
end

local function createProductCard(context, options)
	-- Use the authored Shop item row so the action button stays identical to the
	-- Coins tab, but restore the fitted v1636 Sea Star card geometry.  The Coins
	-- artwork has a much narrower icon compartment and was the reason the stars
	-- appeared trapped inside an undersized box.
	local holder = cloneTemplate("ShopItemCardTemplate")
	holder.Name = options.key .. "ProductCard"
	holder.BackgroundColor3 = Color3.fromRGB(3, 18, 52)
	holder.BackgroundTransparency = 0.02
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = false
	holder.Size = UDim2.new(1, -6, 0, SEA_STAR_ROW_HEIGHT)
	holder.LayoutOrder = options.layoutOrder or 1
	holder.Visible = true
	holder.ZIndex = 207
	holder.Parent = context.parent

	local rowArtwork = holder:FindFirstChild("RowArtwork")
	if rowArtwork and rowArtwork:IsA("GuiObject") then
		rowArtwork.Visible = false
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 17)
	corner.Parent = holder

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 78, 205)
	stroke.Thickness = 2
	stroke.Transparency = 0.56
	stroke.Parent = holder

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(
		Color3.fromRGB(5, 28, 72),
		Color3.fromRGB(1, 12, 38)
	)
	gradient.Rotation = 0
	gradient.Parent = holder

	local iconArea = Instance.new("Frame")
	iconArea.Name = "IconArea"
	iconArea.BackgroundColor3 = Color3.fromRGB(1, 15, 43)
	iconArea.BackgroundTransparency = 0.08
	iconArea.BorderSizePixel = 0
	iconArea.Position = UDim2.fromOffset(0, 0)
	iconArea.Size = UDim2.fromOffset(SEA_STAR_ICON_AREA_WIDTH, SEA_STAR_ROW_HEIGHT)
	iconArea.ZIndex = 208
	iconArea.Parent = holder

	local iconAreaCorner = Instance.new("UICorner")
	iconAreaCorner.CornerRadius = UDim.new(0, 17)
	iconAreaCorner.Parent = iconArea

	local iconAreaStroke = Instance.new("UIStroke")
	iconAreaStroke.Color = Color3.fromRGB(0, 65, 172)
	iconAreaStroke.Thickness = 1
	iconAreaStroke.Transparency = 0.78
	iconAreaStroke.Parent = iconArea

	local productTemplate = ui.templates:FindFirstChild("ProductCardTemplate")
	local iconTemplate = productTemplate and productTemplate:FindFirstChild("Icon")
	assert(iconTemplate and iconTemplate:IsA("ImageLabel"), "[ShopModernUI] ProductCardTemplate.Icon is missing")
	local icon = iconTemplate:Clone()
	local iconSize = options.iconSize or 142
	icon.Name = "SeaStarIcon"
	icon.Parent = iconArea
	icon.AnchorPoint = Vector2.new(0, 0)
	icon.Position = UDim2.fromOffset(
		math.floor((SEA_STAR_ICON_AREA_WIDTH - iconSize) / 2),
		math.floor((SEA_STAR_ROW_HEIGHT - iconSize) / 2)
	)
	icon.Size = UDim2.fromOffset(iconSize, iconSize)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Image = options.iconImage or SEA_STAR_ICON
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Visible = true
	icon.ZIndex = 212

	local function getTextLabel(name, textSize, color)
		local label = boundChild(holder, name, "TextLabel")
		label.TextSize = textSize
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.TextColor3 = color
		label.TextTransparency = 0
		label.TextStrokeColor3 = Color3.fromRGB(3, 18, 44)
		label.TextStrokeTransparency = 0.15
		label.TextWrapped = true
		label.Visible = true
		label.ZIndex = 213
		return label
	end

	local title = getTextLabel(
		"Title",
		36,
		Color3.fromRGB(255, 255, 255)
	)
	title.Position = UDim2.fromOffset(SEA_STAR_TEXT_X, 18)
	title.Size = UDim2.new(1, -520, 0, 45)
	title.Text = tostring(options.title or options.key)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center

	local description = getTextLabel(
		"Description",
		23,
		Color3.fromRGB(178, 194, 235)
	)
	description.Position = UDim2.fromOffset(SEA_STAR_TEXT_X, 65)
	description.Size = UDim2.new(1, -520, 0, 31)
	description.Text = tostring(options.description or "")
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top

	local value = getTextLabel(
		"Price",
		24,
		Color3.fromRGB(255, 216, 59)
	)
	value.Position = UDim2.fromOffset(SEA_STAR_TEXT_X, 104)
	value.Size = UDim2.new(1, -520, 0, 31)
	value.Text = tostring(options.priceText or "")
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextYAlignment = Enum.TextYAlignment.Center

	makeActionButton(context, holder, {
		text = "Buy",
		type = "GreenButton",
		enabled = true,
		onClick = options.onClick,
	})

	return holder
end

local function createSummaryRow(context, titleText, detailText, layoutOrder)
	local holder = cloneTemplate("StatRowTemplate")
	holder.Name = "ShopSummaryRow"
	holder.BackgroundColor3 = Color3.fromRGB(4, 23, 57)
	holder.BackgroundTransparency = 0.10
	holder.BorderSizePixel = 0
	holder.Size = UDim2.new(1, -6, 0, 122)
	holder.LayoutOrder = layoutOrder
	holder.Visible = true
	holder.ZIndex = 207
	holder.Parent = context.parent
	local summaryCorner = holder:FindFirstChildOfClass("UICorner")
	assert(summaryCorner, "[ShopModernUI] StatRowTemplate.UICorner is missing")
	summaryCorner.CornerRadius = UDim.new(0, 17)
	local stroke = holder:FindFirstChildOfClass("UIStroke")
	assert(stroke, "[ShopModernUI] StatRowTemplate.UIStroke is missing")
	if stroke then
		stroke.Color = Color3.fromRGB(0, 105, 238)
		stroke.Thickness = 2
		stroke.Transparency = 0.18
	end

	local title = boundChild(holder, "Title", "TextLabel")
	title.Text = titleText
	title.Visible = true
	title.Position = UDim2.fromOffset(28, 18)
	title.Size = UDim2.new(1, -56, 0, 44)

	local detail = boundChild(holder, "Detail", "TextLabel")
	detail.Text = detailText
	detail.Visible = true
	detail.Position = UDim2.fromOffset(28, 67)
	detail.Size = UDim2.new(1, -56, 0, 34)
end

local function ownsGamePass(state, passKey)
	local monetization = state and state.Monetization or {}
	local owned = monetization.OwnedGamePasses or {}
	return owned[passKey] == true
end

local robuxPriceCache = {}

local function formatRobux(item, infoType)
	local itemId = tonumber(item.id) or tonumber(item.Id)
	local fallbackPrice = tonumber(item.priceRobux) or tonumber(item.Price)
	if not itemId or itemId <= 0 then
		return tostring(fallbackPrice or "?") .. " Robux"
	end
	infoType = infoType or Enum.InfoType.GamePass
	local cacheKey = tostring(infoType) .. ":" .. tostring(itemId)
	local cachedPrice = robuxPriceCache[cacheKey]
	if cachedPrice == nil then
		local success, productInfo = pcall(function()
			return MarketplaceService:GetProductInfo(itemId, infoType)
		end)
		cachedPrice = success and type(productInfo) == "table" and tonumber(productInfo.PriceInRobux) or fallbackPrice
		robuxPriceCache[cacheKey] = cachedPrice
	end
	return tostring(cachedPrice or "?") .. " Robux"
end

local function gamePassAction(context, passKey)
	if ownsGamePass(context.state, passKey) then
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
	local monetization = context.state
		and context.state.Monetization
		or {}

	if not ownsGamePass(context.state, "VipAngler") then
		return {
			text = "Unavailable",
			type = "RedButton",
			enabled = false,
		}
	end

	if monetization.VipRewardAvailable == true then
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
		description = "5 Fresh Bait + 2 Lucky Bait once per day.",
		action = vipRewardAction(context),
	})
	order += 1

	local passImages = {
		VipAngler = "VipAnglerPass",
		AquariumDesigner = "AquariumDesignerPass",
	}

	for _, passKey in ipairs({
		"VipAngler",
		"AquariumDesigner",
		}) do
		local pass = context.MonetizationConfig.GamePasses[passKey]
		if pass then
			createImageRow(context, {
				key = passImages[passKey],
				layoutOrder = order,
				height = 190,
				title = pass.name,
				description = pass.description,
				descriptionLines = 2,
				priceText = formatRobux(pass, Enum.InfoType.GamePass),
				action = gamePassAction(context, passKey),
			})
			order += 1
		end
	end
end

local function renderItems(context)
	local imageKeys = {
		SmallLuckyBaitPack = "SmallLuckyBaitPack",
		MediumLuckyBaitPack = "MediumLuckyBaitPack",
		LargeLuckyBaitPack = "LargeLuckyBaitPack",
	}
	local order = 1

	for _, productKey in ipairs(
		context.MonetizationConfig.DeveloperProductOrder or {}
		) do
		local product = context.MonetizationConfig
			.DeveloperProducts[productKey]
		if product then
			createImageRow(context, {
				key = imageKeys[productKey],
				layoutOrder = order,
				height = 190,
				title = product.name,
				description = product.description,
				priceText = formatRobux(product, Enum.InfoType.Product),
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

	for productIndex, productKey in ipairs(
		context.MonetizationConfig.SeaStarProductOrder or {}
		) do
		local product = context.MonetizationConfig
			.DeveloperProducts[productKey]
		if product then
			local visual = SEA_STAR_PACK_VISUALS[productIndex] or {}
			createProductCard(context, {
				key = productKey,
				layoutOrder = order,
				iconImage = visual.image,
				iconSize = visual.iconSize,
				title = product.name,
				description = product.description,
				priceText = formatRobux(product, Enum.InfoType.Product),
				onClick = function()
					context.fireShopAction(
						"PromptProduct",
						"Product",
						productKey
					)
				end,
			})
			order += 1
		end
	end
end

local function renderCoins(context)
	local imageKeys = {
		StarterCoinPack = "StarterCoinPack",
		SmallCoinPack = "SmallCoinPack",
		MediumCoinPack = "MediumCoinPack",
		LargeCoinPack = "LargeCoinPack",
		HugeCoinPack = "HugeCoinPack",
	}
	local order = 1

	for _, productKey in ipairs(
		context.MonetizationConfig.CoinProductOrder or {}
		) do
		local product = context.MonetizationConfig
			.DeveloperProducts[productKey]
		if product then
			createImageRow(context, {
				key = imageKeys[productKey],
				layoutOrder = order,
				height = 158,
				title = product.name,
				description = product.description,
				priceText = formatRobux(product, Enum.InfoType.Product),
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
			context.state and context.state.BackpackSize or 0
		),
		1
	)

	local imageKeys = {
		SmallBag = "SmallBagUpgrade",
		MediumBag = "MediumBagUpgrade",
		LargeBag = "LargeBagUpgrade",
	}
	local order = 2

	for _, passKey in ipairs({
		"SmallBag",
		"MediumBag",
		"LargeBag",
		}) do
		local pass = context.MonetizationConfig.GamePasses[passKey]
		if pass then
			createImageRow(context, {
				key = imageKeys[passKey],
				layoutOrder = order,
				height = 178,
				title = pass.name,
				description = pass.description,
				priceText = formatRobux(pass, Enum.InfoType.GamePass),
				action = gamePassAction(context, passKey),
			})
			order += 1
		end
	end
end

function ShopModernUI.render(context)
	assert(type(context) == "table", "ShopModernUI.render needs context")
	assert(context.parent, "ShopModernUI.render needs parent")
	assert(context.panel, "ShopModernUI.render needs panel")
	assert(context.MonetizationConfig, "ShopModernUI.render needs MonetizationConfig")
	assert(context.fireShopAction, "ShopModernUI.render needs fireShopAction")

	if not ui.active or ui.context ~= context then
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

	clearRenderedChildren(context.parent)
	ui.layout = context.parent:FindFirstChildOfClass("UIListLayout")
	ui.padding = context.parent:FindFirstChildOfClass("UIPadding")
	assert(ui.layout and ui.padding, "[ShopModernUI] Authored Content layout/padding is missing")

	renderTabs(context)

	if ui.selectedTab == "Passes" then
		renderPasses(context)
	elseif ui.selectedTab == "Items" then
		renderItems(context)
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
