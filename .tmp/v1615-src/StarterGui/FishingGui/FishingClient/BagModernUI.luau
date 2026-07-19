local BagModernUI = {}

local BASE_WIDTH = 1448
local BASE_HEIGHT = 1086

-- ============================================================
-- BAG 전체 UI 크기 조절
-- 1.00 = 기존 크기
-- 0.90 = 10% 작게
-- 0.80 = 20% 작게
-- 1.10 = 10% 크게
-- ============================================================
local BAG_UI_SCALE_MULTIPLIER = 0.87

-- ============================================================
-- TARGET LAYOUT TUNING
-- ============================================================
-- 상단 탭 4개를 같은 크기/간격으로 정확히 배치
-- 왼쪽 바깥 여백 = 오른쪽 바깥 여백 = 58px
local TOP_TAB_COUNT = 4
local TOP_TAB_SIDE_MARGIN = 40
local TOP_TAB_GAP = -15
local TOP_TAB_START_X = TOP_TAB_SIDE_MARGIN
local TOP_TAB_WIDTH = (
	BASE_WIDTH
	- (TOP_TAB_SIDE_MARGIN * 2)
	- (TOP_TAB_GAP * (TOP_TAB_COUNT - 1))
) / TOP_TAB_COUNT
local TOP_TAB_HEIGHT = 190
local TOP_TAB_Y = 133

local ITEM_ROW_HEIGHT = 150
local ITEM_ROW_GAP = -15

-- 아이템 행 내부 공통 정렬
-- 아이콘 프레임, 이름, 설명/스탯, 버튼이 같은 행의 중앙선에 맞도록 관리함.
local ITEM_FRAME_X = 28
local ITEM_FRAME_SIZE = 112
local ITEM_FRAME_Y = (ITEM_ROW_HEIGHT - ITEM_FRAME_SIZE) / 2

local ITEM_TEXT_X = ITEM_FRAME_X + ITEM_FRAME_SIZE + 34
local ITEM_NAME_Y = 23
local ITEM_NAME_HEIGHT = 46
local ITEM_STATS_Y = 80
local ITEM_STATS_HEIGHT = 38

local ITEM_BUTTON_WIDTH = 206
local ITEM_BUTTON_HEIGHT = 64
local ITEM_BUTTON_RIGHT_MARGIN = 34

-- Bait 전용 배치
-- 아이콘은 더 크게 보이도록 하고, 프레임보다 살짝 왼쪽으로 걸치게 배치한다.
local BAIT_FRAME_X = ITEM_FRAME_X
local BAIT_FRAME_SIZE = 94
-- 아래 간격이 더 좁아 보이던 문제를 줄이기 위해
-- 프레임을 조금 더 줄이고 살짝 위로 올림.
local BAIT_FRAME_Y = ((ITEM_ROW_HEIGHT - BAIT_FRAME_SIZE) / 2) - 3

local BAIT_ICON_SIZE = 90

-- 프레임 내부 기준 아이콘 위치
-- X 값을 키우면 오른쪽, Y 값을 키우면 아래로 이동
local BAIT_ICON_X_OFFSET = 2
local BAIT_ICON_Y_OFFSET = -2

local ASSETS = {
	Backbone = "rbxassetid://108283623894606",
	TabNormal = "rbxassetid://105953757083088",
	TabSelected = "rbxassetid://99455447655780",
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
	mountParent = nil,
	authoredUi = false,
	templates = nil,
	selectedTab = "Rods",
	context = nil,
	viewportConnection = nil,
	hiddenLegacyBaitIcons = {},
	legacyBaitWatcher = nil,
	legacyBaitSearchRoot = nil,
}

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
	if not template then
		return nil
	end

	return template:Clone()
end

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


local function normalizeAssetId(value)
	if type(value) ~= "string" then
		return ""
	end

	-- rbxassetid://123, rbxthumb://...id=123..., https://.../123/... 모두 대응
	local explicitId = string.match(value, "[?&]id=(%d+)")
	if explicitId then
		return explicitId
	end

	local assetId = string.match(value, "rbxassetid://(%d+)")
	if assetId then
		return assetId
	end

	local longest = ""
	for digits in string.gmatch(value, "%d+") do
		if #digits > #longest then
			longest = digits
		end
	end

	return longest
end

local function getBaitAssetIds(context)
	local baitAssetIds = {}

	for baitId, image in pairs(ASSETS.BaitImages) do
		local normalized = normalizeAssetId(image)
		if normalized ~= "" then
			baitAssetIds[normalized] = true
		end

		if context
			and context.GameConfig
			and context.GameConfig.getBaitImage
		then
			local configuredImage =
				context.GameConfig.getBaitImage(baitId) or ""

			local configuredId =
				normalizeAssetId(configuredImage)

			if configuredId ~= "" then
				baitAssetIds[configuredId] = true
			end
		end
	end

	return baitAssetIds
end

local function hasBagOrBaitAncestor(object, stopAt)
	local current = object

	while current and current ~= stopAt do
		local loweredName = string.lower(current.Name or "")

		if string.find(loweredName, "bag", 1, true)
			or string.find(loweredName, "bait", 1, true)
		then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isDuplicateBaitImage(object, context, searchRoot)
	if not object
		or not object.Parent
		or not (
			object:IsA("ImageLabel")
				or object:IsA("ImageButton")
		)
	then
		return false
	end

	-- 현재 파란 프레임 안에서 사용하는 유일한 아이콘은 절대 삭제하지 않음.
	if object.Name == "ModernBaitIcon"
		and ui.root
		and object:IsDescendantOf(ui.root)
	then
		return false
	end

	local baitAssetIds = getBaitAssetIds(context)
	local objectAssetId =
		normalizeAssetId(object.Image or "")

	if objectAssetId == ""
		or not baitAssetIds[objectAssetId]
	then
		return false
	end

	-- Bag/Bait UI 안에 있는 동일 bait 이미지에만 적용한다.
	return hasBagOrBaitAncestor(object, searchRoot.Parent)
		or object:IsDescendantOf(context.parent)
end

local function deleteDuplicateBaitImage(object, context, searchRoot)
	if isDuplicateBaitImage(object, context, searchRoot) then
		object:Destroy()
		return true
	end

	return false
end

local function purgeDuplicateBaitIcons(context)
	-- AuthoredUiV2 has one declared Bag owner. Do not scan PlayerGui or delete
	-- images owned by authored templates and sibling surfaces.
	if ui.authoredUi then
		if ui.legacyBaitWatcher then
			ui.legacyBaitWatcher:Disconnect()
			ui.legacyBaitWatcher = nil
		end
		return
	end

	if not context or not context.parent then
		return
	end

	local searchRoot =
		context.parent:FindFirstAncestorOfClass("PlayerGui")
		or context.parent:FindFirstAncestorOfClass("ScreenGui")
		or context.parent

	ui.legacyBaitSearchRoot = searchRoot

	-- 이미 화면에 존재하는 프레임 뒤 bait 아이콘 객체를 실제로 삭제한다.
	for _, object in ipairs(searchRoot:GetDescendants()) do
		deleteDuplicateBaitImage(object, context, searchRoot)
	end

	-- 다른 코드가 중복 아이콘을 다시 만들더라도 생성 즉시 삭제한다.
	if ui.legacyBaitWatcher then
		ui.legacyBaitWatcher:Disconnect()
		ui.legacyBaitWatcher = nil
	end

	ui.legacyBaitWatcher =
		searchRoot.DescendantAdded:Connect(function(object)
			if ui.selectedTab ~= "Bait"
				or not ui.root
				or not ui.root.Visible
			then
				return
			end

			task.defer(function()
				if object and object.Parent then
					deleteDuplicateBaitImage(
						object,
						ui.context,
						searchRoot
					)
				end
			end)
		end)

	-- 기존 UI 스크립트가 한 프레임 늦게 아이콘을 다시 만드는 경우까지 제거.
	for _, delayTime in ipairs({ 0, 0.05, 0.15, 0.4 }) do
		task.delay(delayTime, function()
			if ui.selectedTab == "Bait"
				and ui.root
				and ui.root.Visible
				and ui.context
			then
				for _, object in ipairs(searchRoot:GetDescendants()) do
					deleteDuplicateBaitImage(
						object,
						ui.context,
						searchRoot
					)
				end
			end
		end)
	end
end


local function updateScale()
	if not ui.scale then
		return
	end

	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize
		or Vector2.new(1920, 1080)

	-- 화면 크기에 따라 기본 반응형 크기 계산
	local widthScale = viewport.X * 0.80 / BASE_WIDTH
	local heightScale = viewport.Y * 0.76 / BASE_HEIGHT
	local responsiveScale = math.min(widthScale, heightScale)

	-- BAG_UI_SCALE_MULTIPLIER 값으로 전체 UI 크기 조절
	ui.scale.Scale = math.clamp(
		responsiveScale * BAG_UI_SCALE_MULTIPLIER,
		0.24,
		1.05
	)
end

local function buildBase(parent)
	if ui.root
		and ui.root.Parent
		and ui.mountParent == parent
	then
		return
	end

	if ui.viewportConnection then
		ui.viewportConnection:Disconnect()
		ui.viewportConnection = nil
	end

	if ui.root and not ui.authoredUi then
		ui.root:Destroy()
	end

	local screenGui = findScreenGui(parent)
	local authoredRoot = screenGui
		and screenGui:GetAttribute("AuthoredUiV2") == true
		and screenGui:FindFirstChild("ModernBagRoot")
	local authoredPanel = authoredRoot
		and authoredRoot:IsA("Frame")
		and authoredRoot:FindFirstChild("Panel")
	local useAuthored = authoredPanel
		and authoredPanel:IsA("Frame")

	local root
	local canvas
	local scale
	if useAuthored then
		root = authoredRoot
		canvas = authoredPanel

		for _, name in ipairs({
			"Backbone",
			"BagDecoration",
			"Title",
			"CloseButton",
			"ItemList",
			"RodsTab",
			"BaitTab",
			"FishTab",
			"MaterialsTab",
		}) do
			local runtimeChild = canvas:FindFirstChild(name)
			if runtimeChild then
				runtimeChild:Destroy()
			end
		end

		for _, scaffoldName in ipairs({ "Header", "Content" }) do
			local scaffold = canvas:FindFirstChild(scaffoldName)
			if scaffold and scaffold:IsA("GuiObject") then
				scaffold.Visible = false
			end
		end

		local authoredStroke = canvas:FindFirstChildOfClass("UIStroke")
		if authoredStroke then
			authoredStroke.Enabled = false
		end

		local sizeConstraint = canvas:FindFirstChildOfClass("UISizeConstraint")
		if sizeConstraint then
			sizeConstraint.MinSize = Vector2.new(0, 0)
			sizeConstraint.MaxSize = Vector2.new(10000, 10000)
		end

		scale = canvas:FindFirstChild("PanelScale")
		if not scale or not scale:IsA("UIScale") then
			scale = Instance.new("UIScale")
			scale.Name = "PanelScale"
			scale.Parent = canvas
		end
	else
		root = Instance.new("Frame")
		root.Name = "ModernBagRoot"
		root.Parent = parent

		canvas = Instance.new("Frame")
		canvas.Name = "Canvas"
		canvas.Parent = root

		scale = Instance.new("UIScale")
		scale.Name = "ResponsiveScale"
		scale.Parent = canvas
	end

	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Active = true
	root.Visible = false
	root.ZIndex = 300
	ui.root = root
	ui.mountParent = parent
	ui.authoredUi = useAuthored == true
	ui.templates = useAuthored
		and screenGui:FindFirstChild("Templates")
		or nil

	local BAG_UI_X_OFFSET = 0
	local BAG_UI_Y_OFFSET = -70

	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.new(
		0.5,
		BAG_UI_X_OFFSET,
		0.5,
		BAG_UI_Y_OFFSET
	)
	canvas.Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel = 0
	canvas.ClipsDescendants = false
	canvas.Visible = true
	canvas.ZIndex = 301
	ui.canvas = canvas

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
		UDim2.fromOffset(52, 2),
		UDim2.fromOffset(235, 198),
		305,
		Enum.ScaleType.Fit
	)

	local title = makeLabel(
		canvas,
		"Title",
		"Bag",
		UDim2.fromOffset(300, 24),
		UDim2.fromOffset(390, 130),
		86,
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
	layout.Padding = UDim.new(0, ITEM_ROW_GAP)
	layout.Parent = content

	local camera = workspace.CurrentCamera
	if camera then
		ui.viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()
end

local function makeTab(id, labelText, x)
	local selected = ui.selectedTab == id
	local button = makeImageButton(
		ui.canvas,
		id .. "Tab",
		selected and ASSETS.TabSelected or ASSETS.TabNormal,
		UDim2.fromOffset(x, TOP_TAB_Y),
		UDim2.fromOffset(TOP_TAB_WIDTH, TOP_TAB_HEIGHT),
		306,
		Enum.ScaleType.Stretch
	)

	-- No rod, bait, or fish picture beside the tab wording.
	local label = makeLabel(
		button,
		"Label",
		labelText,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		40,
		309,
		Color3.new(1, 1, 1),
		Enum.TextXAlignment.Center
	)
	label.TextScaled = true
	addTextConstraint(label, 14, 22)

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
	button.Position = UDim2.new(1, -ITEM_BUTTON_RIGHT_MARGIN, 0.5, 0)
	button.Size = UDim2.fromOffset(ITEM_BUTTON_WIDTH, ITEM_BUTTON_HEIGHT)
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
	-- 일반 Equip 버튼과 정확히 같은 함수/좌표계를 사용한다.
	-- 따라서 Rod/Bait/Fish 어디에서 사용해도 같은 자리에 고정된다.
	local button = makeNormalButton(parent, "Equipped", false, nil)
	button.Name = "EquippedButton"
	button.BackgroundColor3 = Color3.fromRGB(0, 126, 24)
	button.AutoButtonColor = false
	button.Active = false
	button.Selectable = false

	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.fromRGB(39, 255, 44)
		stroke.Thickness = 2
		stroke.Transparency = 0.04
	end

	return button
end

local function makeRow(height, equipped)
	local wrapper = cloneTemplate("InventoryRowTemplate")
		or Instance.new("Frame")
	wrapper.Name = "ItemRow"
	wrapper.Size = UDim2.new(1, -4, 0, height)
	wrapper.BackgroundTransparency = 1
	wrapper.LayoutOrder = 0
	wrapper.Visible = true
	wrapper.ZIndex = 304
	wrapper.Parent = ui.content

	if ui.authoredUi then
		for _, child in ipairs(wrapper:GetChildren()) do
			if child:IsA("GuiObject") then
				child.Visible = false
			elseif child:IsA("UIStroke") then
				child.Enabled = false
			end
		end
	end

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
		local selectedOutline = makeImage(
			background,
			"SelectedOutline",
			ASSETS.SelectedOutline,
			UDim2.fromScale(0, 0),
			UDim2.fromScale(1, 1),
			320,
			Enum.ScaleType.Stretch
		)
		selectedOutline.Active = false
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
			local row = makeRow(ITEM_ROW_HEIGHT, equipped)

			local frame = makeImage(
				row,
				"RodFrame",
				ASSETS.RodFrames[rodId] or ASSETS.RodFrames.WoodenRod,
				UDim2.fromOffset(ITEM_FRAME_X, ITEM_FRAME_Y),
				UDim2.fromOffset(ITEM_FRAME_SIZE, ITEM_FRAME_SIZE),
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
				UDim2.fromOffset(ITEM_TEXT_X, ITEM_NAME_Y),
				UDim2.fromOffset(650, ITEM_NAME_HEIGHT),
				32,
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
				UDim2.fromOffset(ITEM_TEXT_X, ITEM_STATS_Y),
				UDim2.fromOffset(260, ITEM_STATS_HEIGHT),
				25,
				309,
				Color3.fromRGB(0, 230, 255),
				Enum.TextXAlignment.Left
			)

			makeLabel(
				row,
				"Luck",
				"Luck: +" .. tostring(luckPercent) .. "%",
				UDim2.fromOffset(430, ITEM_STATS_Y),
				UDim2.fromOffset(270, ITEM_STATS_HEIGHT),
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
		local row = makeRow(ITEM_ROW_HEIGHT, false)
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
	-- 예전 Bag UI에서 뒤에 남아 있던 bait 아이콘을 숨긴다.
	-- 이제 화면에는 아래에서 만드는 ModernBaitIcon만 보인다.
	purgeDuplicateBaitIcons(context)

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
			local row = makeRow(ITEM_ROW_HEIGHT, equipped)

			local frame = Instance.new("Frame")
			frame.Name = "BaitFrame"
			frame.BackgroundColor3 = Color3.fromRGB(3, 18, 49)
			frame.BackgroundTransparency = 0
			frame.Position = UDim2.fromOffset(BAIT_FRAME_X, BAIT_FRAME_Y)
			frame.Size = UDim2.fromOffset(BAIT_FRAME_SIZE, BAIT_FRAME_SIZE)
			frame.ClipsDescendants = true
			frame.ZIndex = 307
			frame.Parent = row
			addCorner(frame, 10)
			addStroke(frame, Color3.fromRGB(0, 103, 255), 2, 0.05)

			local baitImage = ASSETS.BaitImages[baitId] or ""
			if gameConfig.getBaitImage then
				local configuredImage = gameConfig.getBaitImage(baitId) or ""
				if configuredImage ~= "" then
					baitImage = configuredImage
				end
			end

			-- 아이콘을 BaitFrame의 자식으로 넣어서
			-- 프레임 바깥으로 삐져나오는 부분을 완전히 잘라낸다.
			local centeredIconX =
				((BAIT_FRAME_SIZE - BAIT_ICON_SIZE) / 2)
				+ BAIT_ICON_X_OFFSET

			local centeredIconY =
				((BAIT_FRAME_SIZE - BAIT_ICON_SIZE) / 2)
				+ BAIT_ICON_Y_OFFSET

			local baitIcon = makeImage(
				frame,
				"ModernBaitIcon",
				baitImage,
				UDim2.fromOffset(centeredIconX, centeredIconY),
				UDim2.fromOffset(BAIT_ICON_SIZE, BAIT_ICON_SIZE),
				309,
				Enum.ScaleType.Fit
			)
			baitIcon.ClipsDescendants = true

			makeLabel(
				row,
				"BaitName",
				bait.displayName,
				UDim2.fromOffset(ITEM_TEXT_X, ITEM_NAME_Y),
				UDim2.fromOffset(650, ITEM_NAME_HEIGHT),
				32,
				309,
				Color3.new(1, 1, 1),
				Enum.TextXAlignment.Left
			)

			local quantity = isBasic and "Unlimited" or tostring(count)
			makeLabel(
				row,
				"Quantity",
				"Quantity: " .. quantity,
				UDim2.fromOffset(ITEM_TEXT_X, ITEM_STATS_Y),
				UDim2.fromOffset(320, ITEM_STATS_HEIGHT),
				25,
				309,
				equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(190, 204, 220),
				Enum.TextXAlignment.Left
			)

			makeLabel(
				row,
				"Description",
				bait.description or "",
				UDim2.fromOffset(470, ITEM_STATS_Y),
				UDim2.fromOffset(410, ITEM_STATS_HEIGHT),
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

	-- 아이템 생성이 끝난 뒤 다시 검사한다.
	-- 현재 앞쪽 ModernBaitIcon만 남기고 뒤에 겹친 bait 이미지는 전부 숨긴다.
	purgeDuplicateBaitIcons(context)

	if rendered == 0 then
		local row = makeRow(ITEM_ROW_HEIGHT, false)
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

	makeLabel(section, "Title", "Resources", UDim2.fromOffset(22, 6), UDim2.fromOffset(360, 42), 28, 306, Color3.fromRGB(235, 247, 255), Enum.TextXAlignment.Left)

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
		local row = makeRow(ITEM_ROW_HEIGHT, false)
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
		local row = makeRow(ITEM_ROW_HEIGHT, false)

		local frame = makeImage(
			row,
			"FishFrame",
			ASSETS.FishFrames[rarity] or ASSETS.FishFrames.Common,
			UDim2.fromOffset(ITEM_FRAME_X, ITEM_FRAME_Y),
			UDim2.fromOffset(ITEM_FRAME_SIZE, ITEM_FRAME_SIZE),
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
			UDim2.fromOffset(ITEM_TEXT_X, ITEM_NAME_Y),
			UDim2.fromOffset(650, ITEM_NAME_HEIGHT),
			32,
			309,
			Color3.new(1, 1, 1),
			Enum.TextXAlignment.Left
		)

		makeLabel(
			row,
			"Rarity",
			rarity,
			UDim2.fromOffset(ITEM_TEXT_X, ITEM_STATS_Y),
			UDim2.fromOffset(220, ITEM_STATS_HEIGHT),
			25,
			309,
			rarityColor,
			Enum.TextXAlignment.Left
		)

		makeLabel(
			row,
			"Value",
			"Value: " .. tostring(tonumber(fish.value) or 0),
			UDim2.fromOffset(410, ITEM_STATS_Y),
			UDim2.fromOffset(280, ITEM_STATS_HEIGHT),
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

	for _, name in ipairs({
		"RodsTab",
		"BaitTab",
		"FishTab",
		"MaterialsTab",
		}) do
		local old = ui.canvas:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	-- 4개 탭 모두 같은 크기이며, 탭 사이 간격과 양쪽 바깥 여백이 일정함.
	makeTab(
		"Rods",
		"Fishing Rods",
		TOP_TAB_START_X + ((TOP_TAB_WIDTH + TOP_TAB_GAP) * 0)
	)
	makeTab(
		"Bait",
		"Bait",
		TOP_TAB_START_X + ((TOP_TAB_WIDTH + TOP_TAB_GAP) * 1)
	)
	makeTab(
		"Fish",
		"Fish",
		TOP_TAB_START_X + ((TOP_TAB_WIDTH + TOP_TAB_GAP) * 2)
	)
	makeTab(
		"Materials",
		"Materials",
		TOP_TAB_START_X + ((TOP_TAB_WIDTH + TOP_TAB_GAP) * 3)
	)

	if ui.selectedTab == "Rods" then
		renderRods(ui.context)
	elseif ui.selectedTab == "Bait" then
		purgeDuplicateBaitIcons(ui.context)
		renderBait(ui.context)
	elseif ui.selectedTab == "Fish" then
		renderFish(ui.context)
	elseif ui.selectedTab == "Materials" then
		renderResources(ui.context)
		-- Materials 내부 내용은 추후 이 위치에 렌더링하면 됨.
		-- 현재는 탭만 생성하고 콘텐츠 영역은 비워 둠.
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
	if ui.legacyBaitWatcher then
		ui.legacyBaitWatcher:Disconnect()
		ui.legacyBaitWatcher = nil
	end

	if ui.root then
		ui.root.Visible = false
	end
end

print("[BagModernUI] Four-tab layout with Materials loaded.")

return BagModernUI
