local BagModernUI = {}

local BASE_WIDTH = 1448
local BASE_HEIGHT = 1086

local ASSETS = {
	Backbone = "rbxassetid://108283623894606",
	TabNormal = "rbxassetid://101135473927300",
	TabSelected = "rbxassetid://106120450577925",
	RodTabIcon = "rbxassetid://77887294460644",
	BaitTabIcon = "rbxassetid://126189479051414",
	FishTabIcon = "rbxassetid://116369556818073",
	CloseButton = "rbxassetid://74437026548245",
	EquippedButton = "rbxassetid://97877042422133",
	SelectedOutline = "rbxassetid://78993001328940",
	ItemRowBackground = "rbxassetid://78930126580653",
	FishStorageHeader = "rbxassetid://94190047330110",
	BaitItemFrame = "rbxassetid://131578062209953",
	LeftDecoration = "rbxassetid://94493748436318",
	RightDecoration = "rbxassetid://107757008760729",

	FishFrames = {
		Common = "rbxassetid://82476012961179",
		Uncommon = "rbxassetid://109344755835178",
		Rare = "rbxassetid://134980793266582",
		Epic = "rbxassetid://78420747823288",
		Legendary = "rbxassetid://108344811627544",
		Mythic = "rbxassetid://128483019144117",
	},

	RodFrames = {
		WoodenRod = "rbxassetid://115934227658772",
		IronRod = "rbxassetid://71831440264510",
		GoldenRod = "rbxassetid://76246999880343",
		EmeraldRod = "rbxassetid://110828755102690",
		OceanRod = "rbxassetid://130788881686757",
	},

	BaitImages = {
		BasicBait = "rbxassetid://87143554943451",
		FreshBait = "rbxassetid://114397365249536",
		TastyBait = "rbxassetid://89693745580563",
		LuckyBait = "rbxassetid://90876615894262",
		GlowBait = "rbxassetid://140507231143381",
		MysticBait = "rbxassetid://91652408607528",
		PondGuardianBait = "rbxassetid://117293437837187",
	},
}

local ui = {
	root = nil,
	canvas = nil,
	scale = nil,
	content = nil,
	selectedTab = "Rods",
	context = nil,
	viewportConnection = nil,
}

local function makeImage(parent, name, image, position, size, zIndex, scaleType)
	local object = Instance.new("ImageLabel")
	object.Name = name
	object.BackgroundTransparency = 1
	object.Position = position
	object.Size = size
	object.Image = image or ""
	object.ScaleType = scaleType or Enum.ScaleType.Fit
	object.ZIndex = zIndex or 302
	object.Parent = parent
	return object
end

local function makeImageButton(parent, name, image, position, size, zIndex, scaleType)
	local object = Instance.new("ImageButton")
	object.Name = name
	object.BackgroundTransparency = 1
	object.Position = position
	object.Size = size
	object.Image = image or ""
	object.ScaleType = scaleType or Enum.ScaleType.Fit
	object.AutoButtonColor = false
	object.ZIndex = zIndex or 304
	object.Parent = parent
	return object
end

local function makeLabel(parent, name, text, position, size, textSize, zIndex, color, alignment)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.Text = text or ""
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextSize = textSize or 28
	label.TextScaled = false
	label.TextWrapped = false
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.35
	label.ZIndex = zIndex or 306
	label.Parent = parent
	return label
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function addTextConstraint(label, minSize, maxSize)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
	return constraint
end

local function clear(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function updateScale()
	if not ui.scale then
		return
	end

	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	-- Keep the Bag clearly smaller than the full screen.
	local widthScale = viewport.X * 0.80 / BASE_WIDTH
	local heightScale = viewport.Y * 0.76 / BASE_HEIGHT
	ui.scale.Scale = math.clamp(math.min(widthScale, heightScale), 0.28, 0.82)
end

local function buildBase(parent)
	if ui.root and ui.root.Parent == parent then
		return
	end

	if ui.viewportConnection then
		ui.viewportConnection:Disconnect()
		ui.viewportConnection = nil
	end

	if ui.root then
		ui.root:Destroy()
	end

	local root = Instance.new("Frame")
	root.Name = "ModernBagRoot"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Active = true
	root.Visible = false
	root.ZIndex = 300
	root.Parent = parent
	ui.root = root

	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)
	canvas.BackgroundTransparency = 1
	canvas.ZIndex = 301
	canvas.Parent = root
	ui.canvas = canvas

	local scale = Instance.new("UIScale")
	scale.Name = "ResponsiveScale"
	scale.Parent = canvas
	ui.scale = scale

	makeImage(
		canvas,
		"Backbone",
		ASSETS.Backbone,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT),
		301,
		Enum.ScaleType.Stretch
	)

	makeImage(
		canvas,
		"BagDecoration",
		ASSETS.LeftDecoration,
		UDim2.fromOffset(72, 18),
		UDim2.fromOffset(195, 165),
		305,
		Enum.ScaleType.Fit
	)

	local title = makeLabel(
		canvas,
		"Title",
		"Bag",
		UDim2.fromOffset(305, 42),
		UDim2.fromOffset(300, 105),
		70,
		306,
		Color3.new(1, 1, 1),
		Enum.TextXAlignment.Left
	)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(14, 20, 30)

	local closeButton = makeImageButton(
		canvas,
		"CloseButton",
		ASSETS.CloseButton,
		UDim2.fromOffset(1278, 42),
		UDim2.fromOffset(92, 92),
		310,
		Enum.ScaleType.Fit
	)
	closeButton.MouseButton1Click:Connect(function()
		BagModernUI.hide()
		if ui.context and ui.context.onClose then
			ui.context.onClose()
		end
	end)

	local content = Instance.new("ScrollingFrame")
	content.Name = "ItemList"
	content.Position = UDim2.fromOffset(62, 286)
	content.Size = UDim2.fromOffset(1316, 712)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollBarThickness = 18
	content.ScrollBarImageColor3 = Color3.fromRGB(0, 112, 255)
	content.ScrollBarImageTransparency = 0
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	content.ZIndex = 304
	content.Parent = canvas
	ui.content = content

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 2)
	padding.PaddingRight = UDim.new(0, 30)
	padding.PaddingTop = UDim.new(0, 2)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.Parent = content

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = content

	local camera = workspace.CurrentCamera
	if camera then
		ui.viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()
end

local function makeTab(id, labelText, icon, x)
	local selected = ui.selectedTab == id
	local button = makeImageButton(
		ui.canvas,
		id .. "Tab",
		selected and ASSETS.TabSelected or ASSETS.TabNormal,
		UDim2.fromOffset(x, 170),
		UDim2.fromOffset(350, 110),
		306,
		Enum.ScaleType.Stretch
	)

	makeImage(
		button,
		"Icon",
		icon,
		UDim2.fromOffset(24, 10),
		UDim2.fromOffset(88, 90),
		308,
		Enum.ScaleType.Fit
	)

	local label = makeLabel(
		button,
		"Label",
		labelText,
		UDim2.fromOffset(108, 10),
		UDim2.fromOffset(224, 88),
		36,
		309,
		Color3.new(1, 1, 1),
		Enum.TextXAlignment.Center
	)
	label.TextScaled = true
	addTextConstraint(label, 18, 36)

	button.MouseButton1Click:Connect(function()
		if ui.selectedTab ~= id then
			ui.selectedTab = id
			BagModernUI.refresh()
		end
	end)
end

local function makeNormalButton(parent, text, enabled, callback)
	local button = Instance.new("TextButton")
	button.Name = "ActionButton"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -34, 0.5, 0)
	button.Size = UDim2.fromOffset(206, 72)
	button.BackgroundColor3 = enabled and Color3.fromRGB(4, 35, 78) or Color3.fromRGB(45, 55, 70)
	button.AutoButtonColor = enabled
	button.Font = Enum.Font.FredokaOne
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 28
	button.TextStrokeColor3 = Color3.new(0, 0, 0)
	button.TextStrokeTransparency = 0.35
	button.ZIndex = 310
	button.Parent = parent
	addCorner(button, 14)
	addStroke(button, enabled and Color3.fromRGB(0, 112, 255) or Color3.fromRGB(90, 105, 125), 2, 0.08)

	if enabled and callback then
		button.MouseButton1Click:Connect(callback)
	end

	return button
end

local function makeEquippedButton(parent)
	local button = makeImage(
		parent,
		"EquippedButton",
		ASSETS.EquippedButton,
		UDim2.new(1, -240, 0.5, -36),
		UDim2.fromOffset(206, 72),
		310,
		Enum.ScaleType.Stretch
	)

	local label = makeLabel(
		button,
		"Label",
		"Equipped",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		27,
		311,
		Color3.new(1, 1, 1),
		Enum.TextXAlignment.Center
	)
	label.TextScaled = true
	addTextConstraint(label, 18, 28)
end

local function makeRow(height, equipped)
	local wrapper = Instance.new("Frame")
	wrapper.Name = "ItemRow"
	wrapper.Size = UDim2.new(1, -4, 0, height)
	wrapper.BackgroundTransparency = 1
	wrapper.ZIndex = 304
	wrapper.Parent = ui.content

	local background = makeImage(
		wrapper,
		"Background",
		ASSETS.ItemRowBackground,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		305,
		Enum.ScaleType.Stretch
	)

	if equipped then
		makeImage(
			background,
			"SelectedOutline",
			ASSETS.SelectedOutline,
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			306,
			Enum.ScaleType.Stretch
		)
	end

	return background
end

local function renderRods(context)
	local state = context.state or {}
	local gameConfig = context.GameConfig
	local ownedRods = state.OwnedRods or {}
	local rendered = 0

	for _, rodId in ipairs(gameConfig.RodOrder or {}) do
		if ownedRods[rodId] then
			rendered += 1
			local rod = gameConfig.Rods[rodId]
			local equipped = state.EquippedRod == rodId
			local row = makeRow(142, equipped)

			local frame = makeImage(
				row,
				"RodFrame",
				ASSETS.RodFrames[rodId] or ASSETS.RodFrames.WoodenRod,
				UDim2.fromOffset(28, 7),
				UDim2.fromOffset(128, 128),
				307,
				Enum.ScaleType.Fit
			)

			local rodImage = gameConfig.getRodImage and gameConfig.getRodImage(rodId) or ""
			makeImage(
				frame,
				"RodIcon",
				rodImage,
				UDim2.fromScale(0.10, 0.10),
				UDim2.fromScale(0.80, 0.80),
				308,
				Enum.ScaleType.Fit
			)

			makeLabel(
				row,
				"RodName",
				rod and rod.displayName or rodId,
				UDim2.fromOffset(190, 18),
				UDim2.fromOffset(650, 52),
				34,
				309,
				Color3.new(1, 1, 1),
				Enum.TextXAlignment.Left
			)

			local speedPercent = math.floor((1 / math.max(tonumber(rod and rod.speed) or 1, 0.001)) * 100 + 0.5)
			local luckPercent = math.floor((tonumber(rod and rod.luck) or 0) * 100 + 0.5)

			makeLabel(
				row,
				"Speed",
				"Speed: " .. tostring(speedPercent) .. "%",
				UDim2.fromOffset(190, 79),
				UDim2.fromOffset(260, 38),
				25,
				309,
				Color3.fromRGB(0, 230, 255),
				Enum.TextXAlignment.Left
			)

			makeLabel(
				row,
				"Luck",
				"Luck: +" .. tostring(luckPercent) .. "%",
				UDim2.fromOffset(470, 79),
				UDim2.fromOffset(270, 38),
				25,
				309,
				Color3.fromRGB(180, 255, 0),
				Enum.TextXAlignment.Left
			)

			if equipped then
				makeEquippedButton(row)
			else
				makeNormalButton(row, "Equip", true, function()
					if context.equipRod then
						context.equipRod(rodId)
					end
				end)
			end
		end
	end

	if rendered == 0 then
		local row = makeRow(142, false)
		local empty = makeLabel(
			row,
			"Empty",
			"No fishing rods owned.",
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			30,
			309,
			Color3.fromRGB(190, 204, 220),
			Enum.TextXAlignment.Center
		)
		empty.TextScaled = true
		addTextConstraint(empty, 18, 30)
	end
end

local function renderBait(context)
	local state = context.state or {}
	local gameConfig = context.GameConfig
	local rendered = 0

	for _, baitId in ipairs(gameConfig.BaitOrder or {}) do
		local bait = gameConfig.Baits and gameConfig.Baits[baitId]
		local count = context.getBaitCount and context.getBaitCount(baitId) or 0
		local isBasic = baitId == gameConfig.BasicBaitId
		local owned = isBasic or count > 0

		if bait and owned then
			rendered += 1
			local equipped = state.EquippedBait == baitId
			local row = makeRow(142, equipped)

			local frame = Instance.new("Frame")
			frame.Name = "BaitFrame"
			frame.BackgroundColor3 = Color3.fromRGB(3, 18, 49)
			frame.BackgroundTransparency = 0.05
			frame.Position = UDim2.fromOffset(28, 7)
			frame.Size = UDim2.fromOffset(128, 128)
			frame.ClipsDescendants = true
			frame.ZIndex = 307
			frame.Parent = row
			addCorner(frame, 10)
			addStroke(frame, Color3.fromRGB(0, 103, 255), 2, 0.05)

			local baitImage = ""
			if gameConfig.getBaitImage then
				baitImage = gameConfig.getBaitImage(baitId) or ""
			end
			if baitImage == "" then
				baitImage = ASSETS.BaitImages[baitId] or ""
			end

			local baitIcon = makeImage(
				frame,
				"BaitIcon",
				baitImage,
				UDim2.fromScale(0.06, 0.06),
				UDim2.fromScale(0.88, 0.88),
				308,
				Enum.ScaleType.Fit
			)
			baitIcon.ClipsDescendants = true

			makeLabel(
				row,
				"BaitName",
				bait.displayName,
				UDim2.fromOffset(190, 18),
				UDim2.fromOffset(650, 52),
				34,
				309,
				Color3.new(1, 1, 1),
				Enum.TextXAlignment.Left
			)

			local quantity = isBasic and "Unlimited" or tostring(count)
			makeLabel(
				row,
				"Quantity",
				"Quantity: " .. quantity,
				UDim2.fromOffset(190, 77),
				UDim2.fromOffset(320, 38),
				25,
				309,
				equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(190, 204, 220),
				Enum.TextXAlignment.Left
			)

			makeLabel(
				row,
				"Description",
				bait.description or "",
				UDim2.fromOffset(500, 77),
				UDim2.fromOffset(410, 38),
				21,
				309,
				Color3.fromRGB(150, 175, 205),
				Enum.TextXAlignment.Left
			)

			if equipped then
				makeEquippedButton(row)
			else
				makeNormalButton(row, "Equip", true, function()
					if context.equipBait then
						context.equipBait(baitId)
					end
				end)
			end
		end
	end

	if rendered == 0 then
		local row = makeRow(142, false)
		local empty = makeLabel(
			row,
			"Empty",
			"No bait owned.",
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			30,
			309,
			Color3.fromRGB(190, 204, 220),
			Enum.TextXAlignment.Center
		)
		empty.TextScaled = true
		addTextConstraint(empty, 18, 30)
	end
end

local function renderResources(context)
	local resourceConfig = context.ResourceConfig
	local inventory = context.state and context.state.ResourceInventory or {}
	local section = Instance.new("Frame")
	section.Name = "ResourceInventory"
	section.Size = UDim2.new(1, -4, 0, 166)
	section.BackgroundColor3 = Color3.fromRGB(8, 28, 58)
	section.BackgroundTransparency = 0.04
	section.ZIndex = 304
	section.Parent = ui.content
	addCorner(section, 16)
	addStroke(section, Color3.fromRGB(48, 132, 218), 2, 0.15)

	makeLabel(
		section,
		"Title",
		"Resources",
		UDim2.fromOffset(22, 6),
		UDim2.fromOffset(360, 42),
		28,
		306,
		Color3.fromRGB(235, 247, 255),
		Enum.TextXAlignment.Left
	)

	for index, resourceId in ipairs(resourceConfig.ResourceOrder or {}) do
		local resource = resourceConfig.Resources[resourceId]
		local count = math.max(0, math.floor(tonumber(inventory[resourceId]) or 0))
		local metal = resource.category == "Metals"
		local card = Instance.new("Frame")
		card.Name = resourceId
		card.Position = UDim2.fromOffset(20 + ((index - 1) * 308), 52)
		card.Size = UDim2.fromOffset(292, 94)
		card.BackgroundColor3 = metal and Color3.fromRGB(39, 68, 98) or Color3.fromRGB(25, 86, 82)
		card.BackgroundTransparency = 0.04
		card.ZIndex = 306
		card.Parent = section
		addCorner(card, 12)
		addStroke(card, metal and Color3.fromRGB(118, 172, 224) or Color3.fromRGB(70, 218, 174), 2, 0.12)

		local iconId = resource.iconId
		if iconId then
			local iconText = tostring(iconId)
			if tonumber(iconText) then
				iconText = "rbxassetid://" .. tostring(math.floor(tonumber(iconText)))
			end
			makeImage(card, "Icon", iconText, UDim2.fromOffset(10, 13), UDim2.fromOffset(66, 66), 308, Enum.ScaleType.Fit)
		else
			local badge = Instance.new("Frame")
			badge.Name = "FallbackIcon"
			badge.Position = UDim2.fromOffset(10, 13)
			badge.Size = UDim2.fromOffset(66, 66)
			badge.BackgroundColor3 = metal and Color3.fromRGB(103, 147, 190) or Color3.fromRGB(35, 178, 135)
			badge.ZIndex = 308
			badge.Parent = card
			addCorner(badge, 12)
			local initials = string.gsub(resource.displayName, "^(%a)%a*%s+(%a).*$", "%1%2")
			makeLabel(badge, "Initials", string.upper(initials), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 26, 309, Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
		end

		makeLabel(card, "Name", resource.displayName, UDim2.fromOffset(86, 8), UDim2.fromOffset(196, 34), 21, 309, Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
		makeLabel(card, "Count", "x" .. tostring(count), UDim2.fromOffset(86, 38), UDim2.fromOffset(100, 42), 28, 309, Color3.fromRGB(255, 225, 106), Enum.TextXAlignment.Left)
		makeLabel(card, "Category", resource.category, UDim2.fromOffset(176, 43), UDim2.fromOffset(104, 30), 17, 309, Color3.fromRGB(190, 214, 232), Enum.TextXAlignment.Right)
	end
end

local function renderFish(context)
	local state = context.state or {}
	local gameConfig = context.GameConfig
	local inventory = state.Inventory or {}
	local canEdit = state.AquariumView and state.AquariumView.CanEdit == true

	renderResources(context)

	local header = Instance.new("Frame")
	header.Name = "FishStorageHeader"
	header.Size = UDim2.new(1, -4, 0, 104)
	header.BackgroundTransparency = 1
	header.ZIndex = 304
	header.Parent = ui.content

	local headerImage = makeImage(
		header,
		"Background",
		ASSETS.FishStorageHeader,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		305,
		Enum.ScaleType.Stretch
	)

	makeLabel(
		headerImage,
		"Storage",
		string.format("Fish Storage: %d / %d", #inventory, tonumber(state.BackpackSize) or 0),
		UDim2.fromOffset(34, 10),
		UDim2.fromOffset(600, 84),
		31,
		307,
		Color3.new(1, 1, 1),
		Enum.TextXAlignment.Left
	)

	makeLabel(
		headerImage,
		"Value",
		string.format("Bag Value: %d Coins", tonumber(state.InventoryValue) or 0),
		UDim2.new(1, -600, 0, 10),
		UDim2.fromOffset(550, 84),
		29,
		307,
		Color3.fromRGB(255, 220, 80),
		Enum.TextXAlignment.Right
	)

	if #inventory == 0 then
		local row = makeRow(142, false)
		local empty = makeLabel(
			row,
			"Empty",
			"No fish stored in your bag.",
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			30,
			309,
			Color3.fromRGB(190, 204, 220),
			Enum.TextXAlignment.Center
		)
		empty.TextScaled = true
		addTextConstraint(empty, 18, 30)
		return
	end

	for index = #inventory, 1, -1 do
		local fish = inventory[index]
		local rarity = fish.rarity or "Common"
		if rarity == "Mythical" then
			rarity = "Mythic"
		end
		local rarityColor = (gameConfig.RarityColors and gameConfig.RarityColors[rarity]) or Color3.new(1, 1, 1)
		local row = makeRow(142, false)

		local frame = makeImage(
			row,
			"FishFrame",
			ASSETS.FishFrames[rarity] or ASSETS.FishFrames.Common,
			UDim2.fromOffset(28, 7),
			UDim2.fromOffset(128, 128),
			307,
			Enum.ScaleType.Fit
		)

		local fishImage = gameConfig.getFishImage and gameConfig.getFishImage(fish.imageKey or fish.id) or ""
		makeImage(
			frame,
			"FishIcon",
			fishImage,
			UDim2.fromScale(0.12, 0.12),
			UDim2.fromScale(0.76, 0.76),
			308,
			Enum.ScaleType.Fit
		)

		makeLabel(
			row,
			"FishName",
			fish.name or tostring(fish.id),
			UDim2.fromOffset(190, 18),
			UDim2.fromOffset(650, 52),
			34,
			309,
			Color3.new(1, 1, 1),
			Enum.TextXAlignment.Left
		)

		makeLabel(
			row,
			"Rarity",
			rarity,
			UDim2.fromOffset(190, 79),
			UDim2.fromOffset(220, 38),
			25,
			309,
			rarityColor,
			Enum.TextXAlignment.Left
		)

		makeLabel(
			row,
			"Value",
			"Value: " .. tostring(tonumber(fish.value) or 0),
			UDim2.fromOffset(430, 79),
			UDim2.fromOffset(280, 38),
			25,
			309,
			Color3.fromRGB(255, 220, 80),
			Enum.TextXAlignment.Left
		)

		makeNormalButton(
			row,
			canEdit and "Display" or "View Only",
			canEdit,
			function()
				if canEdit and context.displayFish then
					context.displayFish(fish, index)
				end
			end
		)
	end
end

function BagModernUI.refresh()
	if not ui.root or not ui.content or not ui.context then
		return
	end

	clear(ui.content)

	for _, name in ipairs({ "RodsTab", "BaitTab", "FishTab" }) do
		local old = ui.canvas:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	-- 350px tabs with only 16px between them, centered on the 1448px canvas.
	makeTab("Rods", "Fishing Rods", ASSETS.RodTabIcon, 183)
	makeTab("Bait", "Bait", ASSETS.BaitTabIcon, 549)
	makeTab("Fish", "Fish", ASSETS.FishTabIcon, 915)

	if ui.selectedTab == "Rods" then
		renderRods(ui.context)
	elseif ui.selectedTab == "Bait" then
		renderBait(ui.context)
	else
		renderFish(ui.context)
	end

	ui.content.CanvasPosition = Vector2.new(0, 0)
end

function BagModernUI.show(context)
	assert(type(context) == "table", "BagModernUI.show requires a context table")
	assert(context.parent, "BagModernUI.show requires context.parent")
	assert(context.GameConfig, "BagModernUI.show requires context.GameConfig")
	assert(context.ResourceConfig, "BagModernUI.show requires context.ResourceConfig")

	buildBase(context.parent)
	ui.context = context
	ui.root.Visible = true

	-- Never fall back to the old Bag panel if one malformed item causes a
	-- rendering error. Keep the modern window open and show the error in Output.
	local ok, err = xpcall(BagModernUI.refresh, debug.traceback)
	if not ok then
		warn("[BagModernUI] Modern Bag render failed:\n" .. tostring(err))
		clear(ui.content)

		local errorRow = Instance.new("Frame")
		errorRow.Name = "ModernBagError"
		errorRow.Size = UDim2.new(1, -4, 0, 130)
		errorRow.BackgroundColor3 = Color3.fromRGB(35, 15, 24)
		errorRow.BackgroundTransparency = 0.08
		errorRow.ZIndex = 304
		errorRow.Parent = ui.content
		addCorner(errorRow, 16)
		addStroke(errorRow, Color3.fromRGB(255, 80, 100), 2, 0.08)

		local errorLabel = makeLabel(
			errorRow,
			"ErrorText",
			"Modern Bag could not render. Check Output for [BagModernUI].",
			UDim2.fromOffset(24, 18),
			UDim2.new(1, -48, 1, -36),
			24,
			309,
			Color3.fromRGB(255, 210, 220),
			Enum.TextXAlignment.Center
		)
		errorLabel.TextWrapped = true
	end
end

function BagModernUI.hide()
	if ui.root then
		ui.root.Visible = false
	end
end

return BagModernUI
