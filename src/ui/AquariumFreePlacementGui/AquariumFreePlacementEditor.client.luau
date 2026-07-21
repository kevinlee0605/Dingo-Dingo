-- AquariumFreePlacementEditor_MODERN_FINAL
-- Replace the Source of the existing AquariumFreePlacementEditor LocalScript.
-- Recommended location: StarterPlayer > StarterPlayerScripts
-- This is a standalone LocalScript and does not modify FishingClient.

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local ShopAction = Remotes:WaitForChild("ShopAction", 10)
local StateUpdated = Remotes:WaitForChild("StateUpdated", 10)
local GetState = Remotes:WaitForChild("GetState", 10)
local MonetizationConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonetizationConfig")
)

-- =============================================================
-- WHOLE UI SIZE / POSITION
-- =============================================================
local EDITOR_SCALE_MULTIPLIER = 1
local EDITOR_X = 0.50
local EDITOR_Y = 0.50

local BASE_WIDTH = 1672
local BASE_HEIGHT = 941

local COLORS = {
	ThemeSelected = Color3.fromRGB(58, 163, 56),
	ThemeUnselected = Color3.fromRGB(13, 46, 120),
	DecorSelected = Color3.fromRGB(44, 150, 57),
	DecorUnselected = Color3.fromRGB(12, 44, 118),
	ButtonStroke = Color3.fromRGB(35, 203, 255),
	ButtonStrokeSelected = Color3.fromRGB(125, 255, 134),
	DotSelected = Color3.fromRGB(50, 178, 255),
	DotUnselected = Color3.fromRGB(8, 28, 92),
	ArrowFill = Color3.fromRGB(9, 58, 132),
}
local DEPTH_LEVEL_COUNT = 7
local BUTTON_LABEL_TEXT_SIZE = 18

local WHEEL_CAPTURE_ACTION = "ModernAquariumEditorWheelCapture"
local PINCH_CAPTURE_ACTION = "ModernAquariumEditorPinchCapture"

-- =============================================================
-- PROVIDED ROBLOX ASSET IDS
-- =============================================================
local ASSETS = {
	-- Approved 1672x941 reference uploaded as one atlas. Roblox downsizes it
	-- to 1024x576, so the reference pieces below share this source image.
	ReferenceTopBorder = "rbxassetid://78119100190793",
	ReferenceHeaderDivider = "rbxassetid://78119100190793",
	ReferenceLeftRail = "rbxassetid://78119100190793",
	ReferenceRightRail = "rbxassetid://78119100190793",
	ReferenceBottomRail = "rbxassetid://78119100190793",
	ReferencePreview = "rbxassetid://78119100190793",
	ReferenceThemesPanel = "rbxassetid://78119100190793",
	ReferenceDecorPanel = "rbxassetid://78119100190793",
	ReferenceAdjustmentsPanel = "rbxassetid://78119100190793",
	ReferenceThemeUnselected = "rbxassetid://78119100190793",
	ReferenceThemeSelected = "rbxassetid://78119100190793",
	ReferenceDecorUnselected = "rbxassetid://78119100190793",
	ReferenceDecorSelected = "rbxassetid://78119100190793",
	ReferenceDepthLeft = "rbxassetid://78119100190793",
	ReferenceDepthRight = "rbxassetid://78119100190793",
	ReferencePreviewButton = "rbxassetid://78119100190793",
	ReferenceRemoveButton = "rbxassetid://78119100190793",
	ReferenceApplyButton = "rbxassetid://78119100190793",
	MainDisplay = "rbxassetid://73798557079455",
	-- Same source, cropped/zoomed to represent the server's real X/Y bounds.
	MappedMainDisplay = "rbxassetid://73798557079455",
	LeftMainDecoration = "rbxassetid://91056388997818",
	CloseButton = "rbxassetid://119322438066977",

	ThemesPanel = "rbxassetid://93391070554478",
	ThemeTabUnselected = "rbxassetid://77785584261234",
	ThemeTabSelected = "rbxassetid://127696915567136",

	DecorPanel = "rbxassetid://122540568649709",
	DecorTabUnselected = "rbxassetid://81143457443906",
	DecorTabSelected = "rbxassetid://85830007659101",
	Backdrop = "rbxassetid://119386888334158",
	CheckButton = "rbxassetid://71278219091534",

	AdjustmentsBig = "rbxassetid://89729513198581",
	AdjustmentsSmall = "rbxassetid://100275421759931",
	CircleUnselected = "rbxassetid://84469227464999",
	CircleSelected = "rbxassetid://92868306166582",
	LeftDirection = "rbxassetid://94712658264920",
	RightDirection = "rbxassetid://89030652498895",

	PreviewButton = "rbxassetid://110797697720551",
	RemoveButton = "rbxassetid://97923557167562",
	ApplyButton = "rbxassetid://96038949706970",
	BackToEditorButton = "rbxassetid://102092913278079",

	Coral = "rbxassetid://79407993106959",
	Seaweed = "rbxassetid://110865882368376",
	TreasureChest = "rbxassetid://127765798387214",
	Rocks = "rbxassetid://139922070260010",
	ShipwreckPiece = "rbxassetid://127119531270705",
	BubbleMachine = "rbxassetid://84552525898427",
	Driftwood = "rbxassetid://100343703109944",
	Clams = "rbxassetid://112167960169518",
}

-- The uploaded PNGs contain transparent margins. These ImageRect values make
-- each asset fill its intended Roblox UI element without being tiny or offset.
local CROPS = {
	-- Exact crops from the approved 1672x941 reference after Roblox's
	-- proportional 1024x576 texture conversion.
	ReferenceTopBorder = { 0, 0, 1024, 20 },
	ReferenceHeaderDivider = { 0, 73, 1024, 6 },
	ReferenceLeftRail = { 0, 0, 25, 576 },
	ReferenceRightRail = { 999, 0, 25, 576 },
	ReferenceBottomRail = { 0, 548, 1024, 28 },
	ReferencePreview = { 22, 76, 523, 462 },
	ReferenceThemesPanel = { 551, 73, 448, 96 },
	ReferenceDecorPanel = { 551, 173, 448, 227 },
	ReferenceAdjustmentsPanel = { 551, 407, 448, 82 },
	-- Reusable button rims and fixed action buttons cut directly from the same
	-- approved reference atlas as the editor shell.
	ReferenceThemeUnselected = { 668, 95, 101, 32 },
	ReferenceThemeSelected = { 562, 95, 101, 32 },
	ReferenceDecorUnselected = { 772, 199, 105, 64 },
	ReferenceDecorSelected = { 662, 199, 106, 64 },
	ReferenceDepthLeft = { 562, 439, 35, 35 },
	ReferenceDepthRight = { 948, 439, 35, 35 },
	ReferencePreviewButton = { 552, 499, 141, 45 },
	ReferenceRemoveButton = { 704, 499, 141, 45 },
	ReferenceApplyButton = { 855, 499, 141, 45 },

	MainDisplay = { 41, 57, 941, 870 },
	-- The real placement limits are x=-0.42..0.42 and y=0.08..0.82.
	-- This zooms the picture to that exact reachable region while the full
	-- MainDisplay underneath keeps the original blue frame visible.
	MappedMainDisplay = { 106, 180, 815, 665 },

	LeftMainDecoration = { 170, 56, 78, 83 },
	-- Source PNG: 1187x1326 -> Roblox texture: about 917x1024
	CloseButton = { 290, 326, 330, 339 },

	ThemesPanel = { 132, 162, 367, 88 },
	-- Source PNGs are 1447x1087 and are resized by Roblox to 1024px wide.
	ThemeTabUnselected = { 396, 329, 219, 91 },
	ThemeTabSelected = { 400, 330, 218, 90 },

	DecorPanel = { 131, 103, 366, 226 },
	DecorTabUnselected = { 168, 66, 83, 69 },
	-- Source PNG is 1828x860 and is resized by Roblox to 1024px wide.
	-- This crop removes the opaque black outer canvas.
	DecorTabSelected = { 414, 159, 196, 164 },
	Backdrop = { 175, 72, 64, 50 },
	CheckButton = { 371, 346, 510, 517 },

	AdjustmentsBig = { 130, 173, 370, 84 },
	AdjustmentsSmall = { 131, 190, 367, 52 },
	CircleUnselected = { 189, 82, 30, 31 },
	-- Source PNGs: 1536x1024 -> Roblox textures: 1024x683.
	-- The selected dot uses a tight square crop so it does not look oversized.
	CircleSelected = { 344, 176, 320, 320 },
	LeftDirection = { 339, 155, 346, 339 },
	RightDirection = { 339, 155, 346, 339 },

	-- Source PNGs: 2172x724 -> Roblox textures: 1024x341
	PreviewButton = { 215, 53, 595, 210 },
	RemoveButton = { 182, 42, 661, 248 },
	-- NewApplyButton source: 1536x1024 -> Roblox texture: 1024x683.
	ApplyButton = { 317, 248, 389, 131 },

	Coral = { 402, 272, 212, 199 },
	Seaweed = { 188, 73, 44, 46 },
	TreasureChest = { 192, 65, 43, 38 },
	Rocks = { 183, 80, 46, 41 },
	ShipwreckPiece = { 191, 69, 52, 44 },
	BubbleMachine = { 192, 72, 36, 45 },
	Driftwood = { 185, 72, 49, 45 },
	Clams = { 271, 190, 94, 64 },
}

local DECOR_BASE_SIZE = {
	Coral = Vector2.new(205, 155),
	Seaweed = Vector2.new(125, 170),
	TreasureChest = Vector2.new(165, 135),
	Rocks = Vector2.new(175, 125),
	ShipwreckPiece = Vector2.new(195, 135),
	BubbleMachine = Vector2.new(135, 165),
	Clams = Vector2.new(150, 105),
	Driftwood = Vector2.new(190, 135),
}

local designerConfig = MonetizationConfig.AquariumDesigner
local placementConfig = designerConfig.freePlacement or {}
local bounds = placementConfig.bounds or {}

local LIMITS = {
	xMin = tonumber(bounds.xMin) or -0.42,
	xMax = tonumber(bounds.xMax) or 0.42,
	yMin = tonumber(bounds.yMin) or 0.08,
	yMax = tonumber(bounds.yMax) or 0.82,
	zMin = tonumber(bounds.zMin) or -0.42,
	zMax = tonumber(bounds.zMax) or 0.42,
	scaleMin = tonumber(bounds.scaleMin) or 0.55,
	scaleMax = tonumber(bounds.scaleMax) or 1.35,
}

local existingGui = script.Parent
if not existingGui:IsA("ScreenGui") then
	warn("[AquariumFreePlacementEditor] Expected AquariumFreePlacementGui ScreenGui parent")
	return
end

local runtime = {
	state = nil,
	items = {},
	savedInstalled = {},
	selectedIndex = nil,
	selectedDecorationId = nil,
	selectedThemeId = designerConfig.defaultDesign.theme,
	backdropEnabled = designerConfig.defaultDesign.backdropEnabled ~= false,
	savedBackdropEnabled = designerConfig.defaultDesign.backdropEnabled ~= false,
	lastPointer = { x = 0, y = 0.16 },
	dragging = false,
	previewMode = false,
	nearOwnAquarium = false,
	pinchActive = false,
	pinchStartScale = 1,
	lastInputType = UserInputService:GetLastInputType(),
	statusToken = 0,
}

local ui = {
	themeButtons = {},
	decorButtons = {},
	depthButtons = {},
}

local function isAquariumViewerOpen()
	local viewerGui = playerGui:FindFirstChild("AquariumViewerGui")
	if not viewerGui or not viewerGui:IsA("ScreenGui") or not viewerGui.Enabled then
		return false
	end

	local viewerRoot = viewerGui:FindFirstChild("Root") or viewerGui:FindFirstChild("Interface")
	return viewerRoot ~= nil
		and viewerRoot:IsA("GuiObject")
		and viewerRoot.Visible
end

local function hideAquariumViewerAccessButton()
	local fishingGui = playerGui:FindFirstChild("FishingGui")
	local viewerButton = fishingGui
		and fishingGui:FindFirstChild("AquariumViewerFallbackButton", true)
	if viewerButton and viewerButton:IsA("GuiObject") then
		viewerButton.Visible = false
	end
end

local function applyCrop(imageObject, crop)
	if crop then
		imageObject.ImageRectOffset = Vector2.new(crop[1], crop[2])
		imageObject.ImageRectSize = Vector2.new(crop[3], crop[4])
	else
		imageObject.ImageRectOffset = Vector2.new(0, 0)
		imageObject.ImageRectSize = Vector2.new(0, 0)
	end
end

local function setImageAsset(imageObject, assetKey)
	imageObject.Image = ASSETS[assetKey] or ""
	applyCrop(imageObject, CROPS[assetKey])
end

local function makeImage(parent, name, assetKey, position, size, zIndex)
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Position = position
	image.Size = size
	image.ScaleType = Enum.ScaleType.Stretch
	image.ZIndex = zIndex or 1
	setImageAsset(image, assetKey)
	image.Parent = parent
	return image
end

local function makeImageButton(parent, name, assetKey, position, size, zIndex)
	local button = Instance.new("ImageButton")
	button.Name = name
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.ScaleType = Enum.ScaleType.Stretch
	button.AutoButtonColor = false
	button.ZIndex = zIndex or 1
	setImageAsset(button, assetKey)
	button.Parent = parent
	return button
end

local MODERN_BUTTON_GRADIENTS = {
	Unselected = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 76, 176)),
		ColorSequenceKeypoint.new(0.48, Color3.fromRGB(5, 42, 111)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 20, 61)),
	}),
	Selected = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 153, 61)),
		ColorSequenceKeypoint.new(0.48, Color3.fromRGB(4, 100, 39)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(1, 49, 23)),
	}),
}

local function addModernButtonInterior(button, cornerRadius)
	local interior = Instance.new("Frame")
	interior.Name = "ModernButtonInterior"
	interior.BackgroundColor3 = Color3.new(1, 1, 1)
	interior.BorderSizePixel = 0
	interior.Position = UDim2.fromOffset(5, 5)
	interior.Size = UDim2.new(1, -10, 1, -10)
	interior.ZIndex = button.ZIndex + 1
	interior.Parent = button
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, cornerRadius)
	corner.Parent = interior

	local gradient = Instance.new("UIGradient")
	gradient.Name = "ModernGradient"
	gradient.Color = MODERN_BUTTON_GRADIENTS.Unselected
	gradient.Rotation = 90
	gradient.Parent = interior

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Name = "ModernInnerStroke"
	innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	innerStroke.Color = Color3.fromRGB(67, 178, 255)
	innerStroke.Thickness = 1
	innerStroke.Transparency = 0.35
	innerStroke.Parent = interior
	return interior
end

local function setModernButtonSelected(button, selected, kind)
	setImageAsset(
		button,
		if kind == "Theme"
			then (selected and "ReferenceThemeSelected" or "ReferenceThemeUnselected")
			else (selected and "ReferenceDecorSelected" or "ReferenceDecorUnselected")
	)

	local interior = button:FindFirstChild("ModernButtonInterior")
	local gradient = interior and interior:FindFirstChild("ModernGradient")
	local innerStroke = interior and interior:FindFirstChild("ModernInnerStroke")
	if gradient and gradient:IsA("UIGradient") then
		gradient.Color = selected
			and MODERN_BUTTON_GRADIENTS.Selected
			or MODERN_BUTTON_GRADIENTS.Unselected
	end
	if innerStroke and innerStroke:IsA("UIStroke") then
		innerStroke.Color = selected
			and Color3.fromRGB(128, 255, 125)
			or Color3.fromRGB(67, 178, 255)
		innerStroke.Transparency = selected and 0.12 or 0.35
	end
end

local function addPressedButtonFeedback(button, pressYOffset)
	local originalPosition = button.Position
	local originalSize = button.Size
	local originalImageTransparency = button.ImageTransparency
	local activeTween = nil
	local isPressed = false

	local function makePosition(pressed)
		return UDim2.new(
			originalPosition.X.Scale,
			originalPosition.X.Offset + (pressed and 3 or 0),
			originalPosition.Y.Scale,
			originalPosition.Y.Offset + (pressed and 3 or 0)
		)
	end

	local function makeSize(shrink)
		return UDim2.new(
			originalSize.X.Scale,
			originalSize.X.Offset - shrink,
			originalSize.Y.Scale,
			originalSize.Y.Offset - shrink
		)
	end

	local function setPressed(pressed)
		if pressed and not button.Active then
			return
		end

		isPressed = pressed

		if activeTween then
			activeTween:Cancel()
		end

		activeTween = TweenService:Create(
			button,
			TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = makePosition(pressed),
				Size = pressed
					and makeSize(6)
					or originalSize,
				ImageTransparency = pressed and 0.16 or originalImageTransparency,
			}
		)
		activeTween:Play()
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			setPressed(true)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			setPressed(false)
		end
	end)

	button.MouseLeave:Connect(function()
		if isPressed then
			setPressed(false)
		end
	end)

	button.Activated:Connect(function()
		setPressed(false)
	end)

	button:GetPropertyChangedSignal("Active"):Connect(function()
		if not button.Active and isPressed then
			setPressed(false)
		end
	end)
end

local function makeLabel(parent, name, text, position, size, textSize, color, alignment, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize or 20
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.35
	label.TextWrapped = true
	label.ZIndex = zIndex or 10
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
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function clearChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		child:Destroy()
	end
end

local function setTemporaryStatus(text, color, duration)
	runtime.statusToken = runtime.statusToken + 1
	local token = runtime.statusToken
	ui.subtitle.Text = text
	ui.subtitle.TextColor3 = color or Color3.fromRGB(47, 236, 255)

	if duration then
		task.delay(duration, function()
			if runtime.statusToken == token then
				ui.subtitle.Text = UserInputService.TouchEnabled and "Pinch to Scale" or "Scroll to Scale"
				ui.subtitle.TextColor3 = Color3.fromRGB(47, 236, 255)
			end
		end)
	end
end

local function refreshState()
	if not GetState then
		return
	end

	local success, result = pcall(function()
		return GetState:InvokeServer()
	end)

	if success and type(result) == "table" then
		runtime.state = result
	end
end

if StateUpdated then
	StateUpdated.OnClientEvent:Connect(function(newState)
		if type(newState) == "table" then
			runtime.state = newState
		end
	end)
end

task.defer(refreshState)

local function getOwnedPasses()
	local monetization = runtime.state and runtime.state.Monetization
	return monetization and monetization.OwnedGamePasses or {}
end

local function ownsDesignerPass()
	return getOwnedPasses().AquariumDesigner == true
end

local function canEditLoadedAquarium()
	return runtime.state
		and runtime.state.AquariumView
		and runtime.state.AquariumView.CanEdit == true
end

local function getAquariumLevel()
	return math.clamp(
		tonumber(runtime.state and runtime.state.Aquarium and runtime.state.Aquarium.Level) or 1,
		1,
		4
	)
end

local function getMaxFreeDecorations()
	local maxByLevel = placementConfig.maxByLevel or {}
	return math.max(0, math.floor(tonumber(maxByLevel[getAquariumLevel()]) or 0))
end

local function findOwnAquarium()
	-- The authored world is nested under the saved map hierarchy.  A direct
	-- Workspace lookup made the editor button disappear even though the loaded
	-- AquariumViewerTank still existed in Play mode.
	local world = workspace:FindFirstChild("FishyFishWorld", true)
	local folder = world and world:FindFirstChild("PersonalAquariums")
	if not folder then
		return nil
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("OccupantUserId") == player.UserId then
			return child
		end
	end

	return nil
end

local function getModelPosition(model)
	local base = model and model:FindFirstChild("AquariumBase", true)
	if base and base:IsA("BasePart") then
		return base.Position
	end
	if model and model.PrimaryPart then
		return model.PrimaryPart.Position
	end
	if model then
		return model:GetPivot().Position
	end
	return nil
end

local function getRootPosition()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function updateNearAquarium()
	if not canEditLoadedAquarium() then
		runtime.nearOwnAquarium = false
		return false
	end

	local aquariumPosition = getModelPosition(findOwnAquarium())
	local rootPosition = getRootPosition()
	runtime.nearOwnAquarium = aquariumPosition ~= nil
		and rootPosition ~= nil
		and (rootPosition - aquariumPosition).Magnitude <= 72
	return runtime.nearOwnAquarium
end

local function clampItem(item)
	if type(item) ~= "table" then
		return nil
	end

	local decorationId = item.decorationId or item.id or item.decoration
	if decorationId == "None" or not designerConfig.decorations[decorationId] then
		return nil
	end

	local depth = item.z
	if depth == nil then
		depth = item.depth
	end

	return {
		decorationId = decorationId,
		x = math.clamp(tonumber(item.x) or 0, LIMITS.xMin, LIMITS.xMax),
		y = math.clamp(tonumber(item.y) or 0.16, LIMITS.yMin, LIMITS.yMax),
		z = math.clamp(tonumber(depth) or 0, LIMITS.zMin, LIMITS.zMax),
		scale = math.clamp(tonumber(item.scale) or 1, LIMITS.scaleMin, LIMITS.scaleMax),
	}
end

local function getCurrentAquariumDesign()
	local monetization = runtime.state and runtime.state.Monetization
	local current = monetization
		and (monetization.AquariumPreviewDesign or monetization.AquariumDesign)
		or nil
	current = current or designerConfig.defaultDesign

	local design = {
		theme = current.theme or designerConfig.defaultDesign.theme,
		backdropEnabled = current.backdropEnabled ~= false,
		backgroundColor = current.backgroundColor or designerConfig.defaultDesign.backgroundColor,
		lightingColor = current.lightingColor or designerConfig.defaultDesign.lightingColor,
		signText = current.signText or "",
		decorations = {},
		freeDecorations = {},
	}

	for slotId, decorationId in pairs(current.decorations or {}) do
		if designerConfig.slots[slotId] and designerConfig.decorations[decorationId] then
			design.decorations[slotId] = decorationId
		end
	end

	for _, item in ipairs(current.freeDecorations or {}) do
		local normalized = clampItem(item)
		if normalized then
			table.insert(design.freeDecorations, normalized)
		end
	end

	return design
end

local function loadEditorItemsFromState()
	local design = getCurrentAquariumDesign()
	local found = {}
	local maxItems = getMaxFreeDecorations()

	runtime.items = {}
	runtime.savedInstalled = {}
	runtime.selectedThemeId = design.theme or designerConfig.defaultDesign.theme
	runtime.backdropEnabled = design.backdropEnabled ~= false
	runtime.savedBackdropEnabled = runtime.backdropEnabled

	local function addSavedItem(item)
		local normalized = clampItem(item)
		if not normalized or found[normalized.decorationId] or #runtime.items >= maxItems then
			return
		end
		found[normalized.decorationId] = true
		runtime.savedInstalled[normalized.decorationId] = true
		table.insert(runtime.items, normalized)
	end

	for _, item in ipairs(design.freeDecorations or {}) do
		addSavedItem(item)
	end

	-- Convert older fixed-slot decorations into free-placement items so they can
	-- be selected, dragged, scaled, moved in depth, removed, and saved.
	for _, slotId in ipairs(designerConfig.slotOrder or {}) do
		local decorationId = design.decorations[slotId]
		local slot = designerConfig.slots[slotId]
		if decorationId and slot then
			addSavedItem({
				decorationId = decorationId,
				x = slot.x,
				y = slot.y,
				z = slot.z,
				scale = slot.scale,
			})
		end
	end

	runtime.selectedIndex = nil
	runtime.selectedDecorationId = nil
	runtime.lastPointer.x = 0
	runtime.lastPointer.y = 0.16
end

local function buildDesignFromEditor()
	local current = getCurrentAquariumDesign()
	local design = {
		theme = runtime.selectedThemeId or current.theme,
		backdropEnabled = runtime.backdropEnabled,
		backgroundColor = current.backgroundColor,
		lightingColor = current.lightingColor,
		signText = current.signText or "",
		-- All editable decor is saved as free placement.
		decorations = {},
		freeDecorations = {},
	}

	local included = {}
	for _, item in ipairs(runtime.items) do
		local normalized = clampItem(item)
		if normalized and not included[normalized.decorationId] then
			included[normalized.decorationId] = true
			table.insert(design.freeDecorations, normalized)
		end
	end

	return design
end

local function validateEditorItems()
	local seen = {}
	for index, item in ipairs(runtime.items) do
		local normalized = clampItem(item)
		if not normalized then
			return false, "Invalid decoration data at #" .. tostring(index)
		end
		if seen[normalized.decorationId] then
			return false, "Duplicate decoration type: " .. tostring(normalized.decorationId)
		end
		seen[normalized.decorationId] = true
	end
	return true
end

-- =============================================================
-- BUILD UI SHELL
-- =============================================================
local gui = existingGui
for _, child in ipairs(gui:GetChildren()) do
	if child ~= script then
		child:Destroy()
	end
end
gui.Name = "AquariumFreePlacementGui"
gui.DisplayOrder = 5000
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
ui.gui = gui

local dimmer = Instance.new("Frame")
dimmer.Name = "BackdropDimmer"
dimmer.BackgroundColor3 = Color3.fromRGB(0, 5, 18)
dimmer.BackgroundTransparency = 0.30
dimmer.BorderSizePixel = 0
dimmer.Size = UDim2.fromScale(1, 1)
dimmer.Visible = false
dimmer.ZIndex = 1
dimmer.Parent = gui
ui.dimmer = dimmer

local panel = Instance.new("Frame")
panel.Name = "ModernAquariumEditor"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(EDITOR_X, EDITOR_Y)
panel.Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)
panel.BackgroundTransparency = 1
panel.BorderSizePixel = 0
panel.Active = true
panel.Visible = false
panel.ZIndex = 10
panel.Parent = gui
ui.panel = panel

local panelScale = Instance.new("UIScale")
panelScale.Name = "ResponsiveScale"
panelScale.Scale = 1
panelScale.Parent = panel
ui.panelScale = panelScale

local shellFill = Instance.new("Frame")
shellFill.Name = "ShellFill"
shellFill.BackgroundColor3 = Color3.fromRGB(0, 14, 38)
shellFill.BorderSizePixel = 0
shellFill.Position = UDim2.fromOffset(27, 18)
shellFill.Size = UDim2.fromOffset(1618, 904)
shellFill.ZIndex = 9
shellFill.Parent = panel
addCorner(shellFill, 22)

-- The old backbone belonged to a different mockup. These atlas slices retain
-- the approved end caps and border geometry without baking the controls.
makeImage(panel, "ReferenceTopBorder", "ReferenceTopBorder", UDim2.fromOffset(0, 0), UDim2.fromOffset(1672, 31), 11)
makeImage(panel, "ReferenceHeaderDivider", "ReferenceHeaderDivider", UDim2.fromOffset(0, 118), UDim2.fromOffset(1672, 10), 11)
makeImage(panel, "ReferenceLeftRail", "ReferenceLeftRail", UDim2.fromOffset(0, 0), UDim2.fromOffset(40, 941), 12)
makeImage(panel, "ReferenceRightRail", "ReferenceRightRail", UDim2.fromOffset(1632, 0), UDim2.fromOffset(40, 941), 12)
makeImage(panel, "ReferenceBottomRail", "ReferenceBottomRail", UDim2.fromOffset(0, 895), UDim2.fromOffset(1672, 46), 12)
makeImage(panel, "LeftDecoration", "LeftMainDecoration", UDim2.fromOffset(51, 29), UDim2.fromOffset(82, 88), 20)

ui.title = makeLabel(
	panel,
	"Title",
	"Aquarium Decor Editor",
	UDim2.fromOffset(150, 31),
	UDim2.fromOffset(700, 54),
	43,
	Color3.fromRGB(255, 255, 255),
	Enum.TextXAlignment.Left,
	25
)

ui.subtitle = makeLabel(
	panel,
	"Subtitle",
	UserInputService.TouchEnabled and "Pinch to Scale" or "Scroll to Scale",
	UDim2.fromOffset(151, 82),
	UDim2.fromOffset(620, 32),
	22,
	Color3.fromRGB(47, 236, 255),
	Enum.TextXAlignment.Left,
	25
)
ui.subtitle.TextStrokeTransparency = 0.6

ui.closeButton = makeImageButton(
	panel,
	"CloseButton",
	"CloseButton",
	UDim2.fromOffset(1548, 31),
	UDim2.fromOffset(68, 68),
	30
)

ui.mainDisplay = makeImage(
	panel,
	"ReferencePreview",
	"ReferencePreview",
	UDim2.fromOffset(36, 124),
	UDim2.fromOffset(854, 755),
	18
)

-- Visual coordinate map: the full frame stays unchanged, but the water image
-- inside it is zoomed so the editor edges correspond to the existing server
-- limits. No world/server coordinate was changed.
ui.mappedMainDisplay = makeImage(
	panel,
	"MappedMainDisplay",
	"MappedMainDisplay",
	UDim2.fromOffset(47, 134),
	UDim2.fromOffset(832, 735),
	20
)
ui.mappedMainDisplay.ScaleType = Enum.ScaleType.Stretch
addCorner(ui.mappedMainDisplay, 18)

ui.decorStage = Instance.new("Frame")
ui.decorStage.Name = "DecorStage"
ui.decorStage.BackgroundTransparency = 1
ui.decorStage.BorderSizePixel = 0
-- Exact editable area inside the blue aquarium picture.
-- Decorations are now constrained fully inside this rectangle.
ui.decorStage.Position = UDim2.fromOffset(47, 134)
ui.decorStage.Size = UDim2.fromOffset(832, 735)
ui.decorStage.ClipsDescendants = true
ui.decorStage.Active = true
ui.decorStage.ZIndex = 22
ui.decorStage.Parent = panel
addCorner(ui.decorStage, 18)

-- Whole authored section slices preserve the exact approved rims, headings,
-- spacing, and dark-blue surface. Functional buttons remain separate above.
makeImage(panel, "ThemesPanel", "ReferenceThemesPanel", UDim2.fromOffset(899, 119), UDim2.fromOffset(732, 156), 17)
makeImage(panel, "DecorPanel", "ReferenceDecorPanel", UDim2.fromOffset(899, 283), UDim2.fromOffset(732, 371), 17)
makeImage(panel, "AdjustmentsPanel", "ReferenceAdjustmentsPanel", UDim2.fromOffset(899, 664), UDim2.fromOffset(732, 134), 17)

-- The reference atlas contains example controls. Mask only those content
-- regions so the real interactive controls do not render over baked copies.
local themesContentMask = Instance.new("Frame")
themesContentMask.Name = "ThemesContentMask"
themesContentMask.BackgroundColor3 = Color3.fromRGB(1, 15, 42)
themesContentMask.BorderSizePixel = 0
themesContentMask.Position = UDim2.fromOffset(908, 151)
themesContentMask.Size = UDim2.fromOffset(714, 116)
themesContentMask.ZIndex = 18
themesContentMask.Parent = panel
addCorner(themesContentMask, 10)

local decorContentMask = Instance.new("Frame")
decorContentMask.Name = "DecorContentMask"
decorContentMask.BackgroundColor3 = Color3.fromRGB(1, 16, 44)
decorContentMask.BorderSizePixel = 0
decorContentMask.Position = UDim2.fromOffset(908, 322)
decorContentMask.Size = UDim2.fromOffset(714, 324)
decorContentMask.ZIndex = 18
decorContentMask.Parent = panel
addCorner(decorContentMask, 10)

ui.themeGrid = Instance.new("Frame")
ui.themeGrid.Name = "ThemeGrid"
ui.themeGrid.BackgroundTransparency = 1
ui.themeGrid.Position = UDim2.fromOffset(919, 155)
ui.themeGrid.Size = UDim2.fromOffset(690, 110)
ui.themeGrid.ZIndex = 25
ui.themeGrid.Parent = panel

local themeGridLayout = Instance.new("UIGridLayout")
themeGridLayout.FillDirection = Enum.FillDirection.Horizontal
themeGridLayout.FillDirectionMaxCells = 4
themeGridLayout.CellSize = UDim2.fromOffset(160, 50)
themeGridLayout.CellPadding = UDim2.fromOffset(10, 8)
themeGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
themeGridLayout.Parent = ui.themeGrid

ui.decorGrid = Instance.new("Frame")
ui.decorGrid.Name = "DecorGrid"
ui.decorGrid.BackgroundTransparency = 1
ui.decorGrid.Position = UDim2.fromOffset(914, 327)
ui.decorGrid.Size = UDim2.fromOffset(696, 318)
ui.decorGrid.ZIndex = 25
ui.decorGrid.Parent = panel

local decorGridLayout = Instance.new("UIGridLayout")
decorGridLayout.FillDirection = Enum.FillDirection.Horizontal
decorGridLayout.FillDirectionMaxCells = 4
decorGridLayout.CellSize = UDim2.fromOffset(168, 100)
decorGridLayout.CellPadding = UDim2.fromOffset(8, 9)
decorGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
decorGridLayout.Parent = ui.decorGrid

ui.depthLeftButton = makeImageButton(
	panel,
	"DepthLeft",
	"ReferenceDepthLeft",
	UDim2.fromOffset(918, 716),
	UDim2.fromOffset(56, 56),
	29
)
ui.depthLeftButton.ScaleType = Enum.ScaleType.Stretch

ui.depthRightButton = makeImageButton(
	panel,
	"DepthRight",
	"ReferenceDepthRight",
	UDim2.fromOffset(1548, 716),
	UDim2.fromOffset(56, 56),
	29
)
ui.depthRightButton.ScaleType = Enum.ScaleType.Stretch

ui.depthTrackLine = Instance.new("Frame")
ui.depthTrackLine.Name = "DepthTrackLine"
ui.depthTrackLine.BackgroundColor3 = Color3.fromRGB(108, 172, 255)
ui.depthTrackLine.BackgroundTransparency = 0.38
ui.depthTrackLine.BorderSizePixel = 0
ui.depthTrackLine.Position = UDim2.fromOffset(1001, 744)
ui.depthTrackLine.Size = UDim2.fromOffset(515, 2)
ui.depthTrackLine.ZIndex = 28
ui.depthTrackLine.Parent = panel

ui.depthDots = Instance.new("Frame")
ui.depthDots.Name = "DepthDots"
ui.depthDots.BackgroundTransparency = 1
ui.depthDots.Position = UDim2.fromOffset(1001, 730)
ui.depthDots.Size = UDim2.fromOffset(515, 32)
ui.depthDots.ZIndex = 29
ui.depthDots.Parent = panel

for level = 1, DEPTH_LEVEL_COUNT do
	local xScale = (level - 1) / (DEPTH_LEVEL_COUNT - 1)
	local dot = makeImageButton(
		ui.depthDots,
		"DepthLevel" .. tostring(level),
		"CircleUnselected",
		UDim2.new(xScale, -11, 0, 5),
		UDim2.fromOffset(22, 22),
		30
	)
	dot.ScaleType = Enum.ScaleType.Stretch
	ui.depthButtons[level] = dot
end

ui.previewButton = makeImageButton(
	panel,
	"PreviewButton",
	"ReferencePreviewButton",
	UDim2.fromOffset(903, 815),
	UDim2.fromOffset(228, 72),
	29
)
ui.removeButton = makeImageButton(
	panel,
	"RemoveButton",
	"ReferenceRemoveButton",
	UDim2.fromOffset(1150, 815),
	UDim2.fromOffset(228, 72),
	29
)
ui.applyButton = makeImageButton(
	panel,
	"ApplyButton",
	"ReferenceApplyButton",
	UDim2.fromOffset(1397, 815),
	UDim2.fromOffset(228, 72),
	29
)

addPressedButtonFeedback(ui.closeButton, 4)
addPressedButtonFeedback(ui.previewButton, 4)
addPressedButtonFeedback(ui.removeButton, 4)
addPressedButtonFeedback(ui.applyButton, 4)

-- The small access button is intentionally independent from the editor artwork.
ui.openButton = Instance.new("TextButton")
ui.openButton.Name = "OpenAquariumDecorEditor"
ui.openButton.AnchorPoint = Vector2.new(1, 1)
ui.openButton.Position = UDim2.new(1, -18, 1, -24)
ui.openButton.Size = UserInputService.TouchEnabled and UDim2.fromOffset(240, 60) or UDim2.fromOffset(300, 75)
ui.openButton.BackgroundColor3 = Color3.fromRGB(14, 94, 190)
ui.openButton.BorderSizePixel = 0
ui.openButton.Font = Enum.Font.GothamBlack
ui.openButton.Text = "Decor Editor"
ui.openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ui.openButton.TextSize = 18
ui.openButton.Visible = false
ui.openButton.ZIndex = 100
ui.openButton.Parent = gui

ui.backButton = ui.openButton:Clone()
ui.backButton.Name = "BackToAquariumEditor"
ui.backButton.AutoButtonColor = false
ui.backButton.BackgroundTransparency = 1
ui.backButton.Text = ""
ui.backButton.Size = UDim2.fromOffset(168, 48)
ui.backButton.Visible = false
ui.backButton.Parent = gui

local backButtonArtwork = Instance.new("ImageLabel")
backButtonArtwork.Name = "ButtonArtwork"
backButtonArtwork.Active = false
backButtonArtwork.BackgroundTransparency = 1
backButtonArtwork.BorderSizePixel = 0
backButtonArtwork.Position = UDim2.fromScale(0, 0)
backButtonArtwork.Size = UDim2.fromScale(1, 1)
backButtonArtwork.Image = ASSETS.BackToEditorButton
-- Crop the transparent padding retained by Roblox around the uploaded artwork.
backButtonArtwork.ImageRectOffset = Vector2.new(52, 57)
backButtonArtwork.ImageRectSize = Vector2.new(919, 288)
backButtonArtwork.ScaleType = Enum.ScaleType.Stretch
backButtonArtwork.ZIndex = ui.backButton.ZIndex
backButtonArtwork.Parent = ui.backButton

ui.openButton.AutoButtonColor = false
ui.openButton.BackgroundTransparency = 1
ui.openButton.Text = ""

local openButtonArtwork = Instance.new("ImageLabel")
openButtonArtwork.Name = "ButtonArtwork"
openButtonArtwork.Active = false
openButtonArtwork.BackgroundTransparency = 1
openButtonArtwork.BorderSizePixel = 0
openButtonArtwork.Position = UDim2.fromScale(0, 0)
openButtonArtwork.Size = UDim2.fromScale(1, 1)
openButtonArtwork.Image = "rbxassetid://109693126647431"
openButtonArtwork.ScaleType = Enum.ScaleType.Fit
openButtonArtwork.ZIndex = ui.openButton.ZIndex
openButtonArtwork.Parent = ui.openButton

local function updateAquariumAccessButtonLayout(viewport)
	local compactLayout = UserInputService.TouchEnabled
		or math.min(viewport.X, viewport.Y) <= 700
	local buttonWidth = compactLayout and 168 or 210
	local buttonHeight = compactLayout and 42 or 53
	local fishingGui = playerGui:FindFirstChild("FishingGui")
	local seaStarsHud = fishingGui and fishingGui:FindFirstChild("SeaStarsHud")

	ui.openButton.AnchorPoint = Vector2.new(1, 0)
	ui.openButton.Size = UDim2.fromOffset(buttonWidth, buttonHeight)
	if seaStarsHud and seaStarsHud:IsA("GuiObject") then
		local origin = ui.dimmer.AbsolutePosition
		local rightEdge = seaStarsHud.AbsolutePosition.X + seaStarsHud.AbsoluteSize.X - origin.X
		local topEdge = seaStarsHud.AbsolutePosition.Y
			+ seaStarsHud.AbsoluteSize.Y
			+ 6
			+ buttonHeight
			+ 6
			- origin.Y
		ui.openButton.Position = UDim2.fromOffset(
			math.floor(rightEdge + 0.5),
			math.floor(topEdge + 0.5)
		)
	else
		ui.openButton.Position = UDim2.new(1, -18, 0, 219)
	end
end

local function updateResponsiveScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local scaleX = math.max(0.1, (viewport.X - 18) / BASE_WIDTH)
	local scaleY = math.max(0.1, (viewport.Y - 18) / BASE_HEIGHT)
	ui.panelScale.Scale = math.clamp(math.min(scaleX, scaleY) * EDITOR_SCALE_MULTIPLIER, 0.35, 1.20)
	ui.panel.Position = UDim2.fromScale(EDITOR_X, EDITOR_Y)
	updateAquariumAccessButtonLayout(viewport)
end

-- =============================================================
-- BUILD THEME BUTTONS
-- =============================================================
for order, themeId in ipairs(designerConfig.themeOrder or {}) do
	local theme = designerConfig.themes[themeId]
	if theme then
		local button = makeImageButton(
			ui.themeGrid,
			themeId .. "ThemeButton",
			"ReferenceThemeUnselected",
			UDim2.fromOffset(0, 0),
			UDim2.fromScale(1, 1),
			27
		)
		button.LayoutOrder = order
		button.BackgroundTransparency = 1
		button.ImageColor3 = Color3.new(1, 1, 1)
		button.ScaleType = Enum.ScaleType.Stretch
		addModernButtonInterior(button, 7)
		local label = makeLabel(button, "Label", theme.name, UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.90, 0.84), BUTTON_LABEL_TEXT_SIZE, Color3.fromRGB(255, 255, 255), Enum.TextXAlignment.Center, 30)
		label.TextScaled = false
		ui.themeButtons[themeId] = {
			button = button,
			label = label,
		}
	end
end

-- =============================================================
-- BUILD DECOR BUTTONS
-- =============================================================
local function createDecorButton(decorationId, layoutOrder, displayName, assetKey)
	local button = makeImageButton(
		ui.decorGrid,
		decorationId .. "DecorButton",
		"ReferenceDecorUnselected",
		UDim2.fromOffset(0, 0),
		UDim2.fromScale(1, 1),
		27
	)
	button.LayoutOrder = layoutOrder
	button.BackgroundTransparency = 1
	button.ImageColor3 = Color3.new(1, 1, 1)
	button.ScaleType = Enum.ScaleType.Stretch
	addModernButtonInterior(button, 8)

	local icon = makeImage(button, "Icon", assetKey, UDim2.fromScale(0.23, 0.08), UDim2.fromScale(0.54, 0.56), 30)
	icon.ScaleType = Enum.ScaleType.Fit

	local label = makeLabel(button, "Label", displayName, UDim2.fromScale(0.04, 0.60), UDim2.fromScale(0.92, 0.34), BUTTON_LABEL_TEXT_SIZE, Color3.fromRGB(255, 255, 255), Enum.TextXAlignment.Center, 31)
	label.TextScaled = false

	local check = Instance.new("Frame")
	check.Name = "InstalledCheck"
	check.AnchorPoint = Vector2.new(1, 0)
	check.Position = UDim2.new(1, -6, 0, 5)
	check.Size = UDim2.fromOffset(29, 29)
	check.BackgroundColor3 = Color3.fromRGB(24, 111, 18)
	check.BackgroundTransparency = 0.01
	check.BorderSizePixel = 0
	check.Visible = false
	check.ZIndex = 33
	check.Parent = button
	addCorner(check, 999)
	addStroke(
		check,
		Color3.fromRGB(192, 255, 82),
		2,
		0
	)

	-- Thick two-piece check mark, matching the visual weight of Apply.
	local checkShadowShort = Instance.new("Frame")
	checkShadowShort.Name = "CheckShadowShort"
	checkShadowShort.AnchorPoint = Vector2.new(0.5, 0.5)
	checkShadowShort.Position = UDim2.fromOffset(10.5, 17.5)
	checkShadowShort.Size = UDim2.fromOffset(6, 13)
	checkShadowShort.Rotation = -43
	checkShadowShort.BackgroundColor3 = Color3.fromRGB(7, 48, 8)
	checkShadowShort.BackgroundTransparency = 0.1
	checkShadowShort.BorderSizePixel = 0
	checkShadowShort.ZIndex = 34
	checkShadowShort.Parent = check
	addCorner(checkShadowShort, 4)

	local checkShadowLong = Instance.new("Frame")
	checkShadowLong.Name = "CheckShadowLong"
	checkShadowLong.AnchorPoint = Vector2.new(0.5, 0.5)
	checkShadowLong.Position = UDim2.fromOffset(19, 13)
	checkShadowLong.Size = UDim2.fromOffset(6, 20)
	checkShadowLong.Rotation = 43
	checkShadowLong.BackgroundColor3 = Color3.fromRGB(7, 48, 8)
	checkShadowLong.BackgroundTransparency = 0.1
	checkShadowLong.BorderSizePixel = 0
	checkShadowLong.ZIndex = 34
	checkShadowLong.Parent = check
	addCorner(checkShadowLong, 4)

	local checkShort = Instance.new("Frame")
	checkShort.Name = "CheckShort"
	checkShort.AnchorPoint = Vector2.new(0.5, 0.5)
	checkShort.Position = UDim2.fromOffset(9.5, 16.5)
	checkShort.Size = UDim2.fromOffset(5, 13)
	checkShort.Rotation = -43
	checkShort.BackgroundColor3 = Color3.fromRGB(255, 255, 215)
	checkShort.BorderSizePixel = 0
	checkShort.ZIndex = 35
	checkShort.Parent = check
	addCorner(checkShort, 4)

	local checkLong = Instance.new("Frame")
	checkLong.Name = "CheckLong"
	checkLong.AnchorPoint = Vector2.new(0.5, 0.5)
	checkLong.Position = UDim2.fromOffset(18, 12)
	checkLong.Size = UDim2.fromOffset(5, 20)
	checkLong.Rotation = 43
	checkLong.BackgroundColor3 = Color3.fromRGB(255, 255, 215)
	checkLong.BorderSizePixel = 0
	checkLong.ZIndex = 35
	checkLong.Parent = check
	addCorner(checkLong, 4)

	ui.decorButtons[decorationId] = {
		button = button,
		icon = icon,
		label = label,
		check = check,
	}

	return ui.decorButtons[decorationId]
end

local backdropEntry = createDecorButton("Backdrop", 1, "Backdrop Off", "Backdrop")
backdropEntry.status = makeLabel(
	backdropEntry.button,
	"Status",
	"ON",
	UDim2.fromScale(0.64, 0.02),
	UDim2.fromScale(0.31, 0.28),
	14,
	Color3.fromRGB(90, 255, 110),
	Enum.TextXAlignment.Center,
	34
)
backdropEntry.status.TextScaled = true
backdropEntry.status.Visible = false

local decorLayoutOrder = 2
for _, decorationId in ipairs(designerConfig.decorationOrder or {}) do
	if decorationId ~= "None" and designerConfig.decorations[decorationId] and ASSETS[decorationId] then
		createDecorButton(
			decorationId,
			decorLayoutOrder,
			designerConfig.decorations[decorationId].name,
			decorationId
		)
		decorLayoutOrder = decorLayoutOrder + 1
	end
end

-- =============================================================
-- SELECTION / PREVIEW RENDERING
-- =============================================================
local function findEditorItemIndex(decorationId)
	for index, item in ipairs(runtime.items) do
		if item.decorationId == decorationId then
			return index
		end
	end
	return nil
end

local function getSelectedItem()
	if runtime.selectedIndex then
		return runtime.items[runtime.selectedIndex]
	end
	return nil
end

local function getDecorationPixelSize(item)
	local base = DECOR_BASE_SIZE[item and item.decorationId]
		or Vector2.new(160, 130)
	local scale = math.clamp(
		tonumber(item and item.scale) or 1,
		LIMITS.scaleMin,
		LIMITS.scaleMax
	)

	return Vector2.new(
		base.X * scale,
		base.Y * scale
	)
end

local function getScaleMarginsForItem(item)
	local stageWidth = math.max(
		1,
		tonumber(ui.decorStage.Size.X.Offset) or 814
	)
	local stageHeight = math.max(
		1,
		tonumber(ui.decorStage.Size.Y.Offset) or 665
	)
	local markerSize = getDecorationPixelSize(item)

	-- These margins keep the complete decoration image inside the blue picture.
	local halfX = math.clamp(
		(markerSize.X * 0.5 + 4) / stageWidth,
		0,
		0.47
	)
	local halfY = math.clamp(
		(markerSize.Y * 0.5 + 4) / stageHeight,
		0,
		0.47
	)

	return halfX, halfY
end

local function clampScalePositionForItem(px, py, item)
	local halfX, halfY = getScaleMarginsForItem(item)

	return math.clamp(px, halfX, 1 - halfX),
	math.clamp(py, halfY, 1 - halfY)
end

local function scalePositionToRelative(px, py, item)
	local halfX, halfY = getScaleMarginsForItem(item)

	-- Important: the visual center only moves between halfX and 1-halfX,
	-- but that entire visual range must map to the server's full X/Y range.
	-- Therefore, when the decoration image touches the left edge, x becomes
	-- exactly xMin; when it touches the right edge, x becomes exactly xMax.
	local usableWidth = math.max(0.001, 1 - (halfX * 2))
	local usableHeight = math.max(0.001, 1 - (halfY * 2))

	local xAlpha = math.clamp(
		(px - halfX) / usableWidth,
		0,
		1
	)
	local yAlpha = math.clamp(
		(py - halfY) / usableHeight,
		0,
		1
	)

	return LIMITS.xMin
		+ xAlpha * (LIMITS.xMax - LIMITS.xMin),
	LIMITS.yMax
	- yAlpha * (LIMITS.yMax - LIMITS.yMin)
end

local function relativeToScalePosition(x, y, item)
	local halfX, halfY = getScaleMarginsForItem(item)
	local usableWidth = math.max(0.001, 1 - (halfX * 2))
	local usableHeight = math.max(0.001, 1 - (halfY * 2))

	local xAlpha = (
		math.clamp(x, LIMITS.xMin, LIMITS.xMax)
		- LIMITS.xMin
	) / math.max(
		0.001,
		LIMITS.xMax - LIMITS.xMin
	)
	local yAlpha = (
		LIMITS.yMax
		- math.clamp(y, LIMITS.yMin, LIMITS.yMax)
	) / math.max(
		0.001,
		LIMITS.yMax - LIMITS.yMin
	)

	local px = halfX + (xAlpha * usableWidth)
	local py = halfY + (yAlpha * usableHeight)

	return clampScalePositionForItem(px, py, item)
end

local function pointerToRelative(position)
	local absolutePosition = ui.decorStage.AbsolutePosition
	local absoluteSize = ui.decorStage.AbsoluteSize
	if absoluteSize.X <= 0 or absoluteSize.Y <= 0 then
		return runtime.lastPointer.x, runtime.lastPointer.y
	end

	local px = (
		position.X - absolutePosition.X
	) / absoluteSize.X
	local py = (
		position.Y - absolutePosition.Y
	) / absoluteSize.Y

	px, py = clampScalePositionForItem(
		px,
		py,
		getSelectedItem()
	)

	return scalePositionToRelative(
		px,
		py,
		getSelectedItem()
	)
end

local function depthLevelToZ(level)
	-- Leftmost is FRONT (zMin), rightmost is BACK (zMax).
	local alpha = (math.clamp(level, 1, DEPTH_LEVEL_COUNT) - 1) / (DEPTH_LEVEL_COUNT - 1)
	return LIMITS.zMin + ((LIMITS.zMax - LIMITS.zMin) * alpha)
end

local function zToDepthLevel(z)
	local alpha = (math.clamp(tonumber(z) or 0, LIMITS.zMin, LIMITS.zMax) - LIMITS.zMin)
		/ math.max(0.001, LIMITS.zMax - LIMITS.zMin)
	return math.clamp(
		math.floor(alpha * (DEPTH_LEVEL_COUNT - 1) + 0.5) + 1,
		1,
		DEPTH_LEVEL_COUNT
	)
end

local refreshDecorButtons
local refreshDepthGauge
local refreshPreviewMarkers

local function refreshThemeButtons()
	for themeId, entry in pairs(ui.themeButtons) do
		local isSelected = (themeId == runtime.selectedThemeId)
		setModernButtonSelected(entry.button, isSelected, "Theme")
		entry.button.BackgroundTransparency = 1
		entry.label.TextColor3 = Color3.fromRGB(255, 255, 255)
		entry.label.TextStrokeTransparency = isSelected and 0.05 or 0.28
	end
end

refreshDecorButtons = function()
	local backdrop = ui.decorButtons.Backdrop
	setModernButtonSelected(backdrop.button, runtime.backdropEnabled, "Decor")
	backdrop.button.BackgroundTransparency = 1
	backdrop.label.Text = runtime.backdropEnabled and "Backdrop On" or "Backdrop Off"
	backdrop.label.TextColor3 = Color3.fromRGB(255, 255, 255)
	backdrop.check.Visible = false

	for decorationId, entry in pairs(ui.decorButtons) do
		if decorationId ~= "Backdrop" then
			local workingIndex = findEditorItemIndex(decorationId)
			local workingPlaced = workingIndex ~= nil
			setModernButtonSelected(entry.button, workingPlaced, "Decor")
			entry.button.BackgroundTransparency = 1

			-- Applied decorations show their installed check immediately, including
			-- the decoration that remains selected for editing.
			entry.check.Visible = workingPlaced
				and runtime.savedInstalled[decorationId] == true
		end
	end
end

refreshDepthGauge = function()
	local item = getSelectedItem()
	local selectedLevel = item and zToDepthLevel(item.z) or nil

	for level, dot in ipairs(ui.depthButtons) do
		local isSelected = selectedLevel == level
		setImageAsset(
			dot,
			isSelected and "CircleSelected" or "CircleUnselected"
		)
		dot.Size = isSelected
			and UDim2.fromOffset(23, 23)
			or UDim2.fromOffset(16, 16)
		dot.Position = UDim2.new(
			(level - 1) / (DEPTH_LEVEL_COUNT - 1),
			isSelected and -11 or -8,
			0,
			isSelected and 5 or 8
		)
		dot.Active = item ~= nil
		dot.ImageTransparency = item and 0 or 0.45
	end

	ui.depthLeftButton.Active = item ~= nil
	ui.depthRightButton.Active = item ~= nil
	ui.depthLeftButton.ImageTransparency = item and 0 or 0.55
	ui.depthRightButton.ImageTransparency = item and 0 or 0.55
	ui.removeButton.Active = item ~= nil
	ui.removeButton.ImageTransparency = item and 0 or 0.55
end

refreshPreviewMarkers = function()
	clearChildren(ui.decorStage)

	if runtime.selectedIndex and not runtime.items[runtime.selectedIndex] then
		runtime.selectedIndex = nil
		runtime.selectedDecorationId = nil
	end

	for index, item in ipairs(runtime.items) do
		local base = DECOR_BASE_SIZE[item.decorationId] or Vector2.new(160, 130)
		local scale = math.clamp(tonumber(item.scale) or 1, LIMITS.scaleMin, LIMITS.scaleMax)
		local px, py = relativeToScalePosition(
			item.x,
			item.y,
			item
		)

		-- Keep the saved X/Y values synchronized with the visual boundary.
		item.x, item.y = scalePositionToRelative(
			px,
			py,
			item
		)

		local frontAmount = 1 - ((math.clamp(item.z, LIMITS.zMin, LIMITS.zMax) - LIMITS.zMin)
			/ math.max(0.001, LIMITS.zMax - LIMITS.zMin))
		local zIndex = 40 + math.floor(frontAmount * 40 + 0.5)

		local marker = makeImageButton(
			ui.decorStage,
			"Placed_" .. item.decorationId,
			item.decorationId,
			UDim2.fromScale(px, py),
			UDim2.fromOffset(base.X * scale, base.Y * scale),
			zIndex
		)
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.ScaleType = Enum.ScaleType.Fit
		marker.ClipsDescendants = false

		local selected = index == runtime.selectedIndex
		local selectionStroke = addStroke(
			marker,
			Color3.fromRGB(75, 255, 125),
			selected and 3 or 1,
			selected and 0 or 1
		)
		selectionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		addCorner(marker, 12)

		marker.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				runtime.selectedIndex = index
				runtime.selectedDecorationId = item.decorationId
				runtime.lastPointer.x = item.x
				runtime.lastPointer.y = item.y
				runtime.dragging = true
				refreshPreviewMarkers()
				refreshDecorButtons()
			end
		end)
	end

	refreshDecorButtons()
	refreshDepthGauge()
end

local function setSelectedItemPosition(position)
	local item = getSelectedItem()
	if not item then
		return
	end

	local x, y = pointerToRelative(position)
	item.x = x
	item.y = y
	runtime.lastPointer.x = x
	runtime.lastPointer.y = y
	refreshPreviewMarkers()
end

local function scaleSelectedDecoration(newScale)
	local item = getSelectedItem()
	if not item then
		return
	end
	item.scale = math.clamp(newScale, LIMITS.scaleMin, LIMITS.scaleMax)
	refreshPreviewMarkers()
end

local function setSelectedDepthLevel(level)
	local item = getSelectedItem()
	if not item then
		return
	end
	item.z = depthLevelToZ(level)
	refreshPreviewMarkers()
end

-- =============================================================
-- BUTTON EVENTS
-- =============================================================
for themeId, entry in pairs(ui.themeButtons) do
	entry.button.MouseButton1Click:Connect(function()
		runtime.selectedThemeId = themeId
		refreshThemeButtons()
		setTemporaryStatus("Theme selected: " .. designerConfig.themes[themeId].name, Color3.fromRGB(47, 236, 255), 1.2)
	end)
end

ui.decorButtons.Backdrop.button.MouseButton1Click:Connect(function()
	runtime.backdropEnabled = not runtime.backdropEnabled
	refreshDecorButtons()
	setTemporaryStatus(
		runtime.backdropEnabled and "Backdrop ON" or "Backdrop OFF",
		runtime.backdropEnabled and Color3.fromRGB(90, 255, 110) or Color3.fromRGB(255, 85, 85),
		1.2
	)
end)

for decorationId, entry in pairs(ui.decorButtons) do
	if decorationId ~= "Backdrop" then
		entry.button.MouseButton1Click:Connect(function()
			local existingIndex = findEditorItemIndex(decorationId)
			if existingIndex then
				runtime.selectedIndex = existingIndex
			else
				if #runtime.items >= getMaxFreeDecorations() then
					setTemporaryStatus(
						"No free decoration slots at this aquarium level.",
						Color3.fromRGB(255, 90, 90),
						2.2
					)
					return
				end

				table.insert(runtime.items, {
					decorationId = decorationId,
					x = runtime.lastPointer.x,
					y = runtime.lastPointer.y,
					z = 0,
					scale = 1,
				})
				runtime.selectedIndex = #runtime.items
			end

			runtime.selectedDecorationId = decorationId
			local selected = getSelectedItem()
			if selected then
				runtime.lastPointer.x = selected.x
				runtime.lastPointer.y = selected.y
			end
			refreshPreviewMarkers()
		end)
	end
end

ui.removeButton.MouseButton1Click:Connect(function()
	if runtime.selectedIndex and runtime.items[runtime.selectedIndex] then
		local removed = runtime.items[runtime.selectedIndex].decorationId
		table.remove(runtime.items, runtime.selectedIndex)
		runtime.selectedIndex = nil
		runtime.selectedDecorationId = nil
		setTemporaryStatus("Removed: " .. tostring(removed), Color3.fromRGB(255, 120, 100), 1.4)
		refreshPreviewMarkers()
	end
end)

ui.depthLeftButton.MouseButton1Click:Connect(function()
	local item = getSelectedItem()
	if item then
		setSelectedDepthLevel(zToDepthLevel(item.z) - 1)
	end
end)

ui.depthRightButton.MouseButton1Click:Connect(function()
	local item = getSelectedItem()
	if item then
		setSelectedDepthLevel(zToDepthLevel(item.z) + 1)
	end
end)

for level, dot in ipairs(ui.depthButtons) do
	dot.MouseButton1Click:Connect(function()
		setSelectedDepthLevel(level)
	end)
end

-- =============================================================
-- DRAG / WHEEL / PINCH
-- =============================================================
local function isPointInsideStage(position)
	local absolutePosition = ui.decorStage.AbsolutePosition
	local absoluteSize = ui.decorStage.AbsoluteSize
	return position.X >= absolutePosition.X
		and position.X <= absolutePosition.X + absoluteSize.X
		and position.Y >= absolutePosition.Y
		and position.Y <= absolutePosition.Y + absoluteSize.Y
end

local function sinkInput()
	return Enum.ContextActionResult.Sink
end

local function captureWheelInsideStage()
	if ui.panel.Visible and isPointInsideStage(UserInputService:GetMouseLocation()) then
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function setWheelCapture(enabled)
	ContextActionService:UnbindAction(WHEEL_CAPTURE_ACTION)
	if enabled and ui.panel.Visible then
		ContextActionService:BindActionAtPriority(
			WHEEL_CAPTURE_ACTION,
			captureWheelInsideStage,
			false,
			Enum.ContextActionPriority.High.Value + 100,
			Enum.UserInputType.MouseWheel
		)
	end
end

local function setPinchCapture(enabled)
	ContextActionService:UnbindAction(PINCH_CAPTURE_ACTION)
	if enabled and ui.panel.Visible then
		ContextActionService:BindActionAtPriority(
			PINCH_CAPTURE_ACTION,
			sinkInput,
			false,
			Enum.ContextActionPriority.High.Value + 100,
			Enum.UserInputType.Touch
		)
	end
end

local function releaseInputCapture()
	setWheelCapture(false)
	setPinchCapture(false)
	runtime.pinchActive = false
	runtime.dragging = false
end

ui.decorStage.InputBegan:Connect(function(input)
	if runtime.pinchActive or not getSelectedItem() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		runtime.dragging = true
		setSelectedItemPosition(input.Position)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if not ui.panel.Visible or not getSelectedItem() then
			return
		end
		if not isPointInsideStage(UserInputService:GetMouseLocation()) then
			return
		end
		local direction = math.sign(input.Position.Z)
		if direction ~= 0 then
			local item = getSelectedItem()
			scaleSelectedDecoration((tonumber(item.scale) or 1) + direction * 0.06)
		end
		return
	end

	if runtime.dragging and not runtime.pinchActive then
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			setSelectedItemPosition(input.Position)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		runtime.dragging = false
	end
end)

UserInputService.TouchPinch:Connect(function(touchPositions, pinchScale, _velocity, inputState)
	if inputState == Enum.UserInputState.Begin then
		if not ui.panel.Visible or not getSelectedItem() or type(touchPositions) ~= "table" or #touchPositions < 2 then
			return
		end
		local center = (touchPositions[1] + touchPositions[2]) / 2
		if not isPointInsideStage(center) then
			return
		end
		runtime.pinchActive = true
		runtime.dragging = false
		runtime.pinchStartScale = tonumber(getSelectedItem().scale) or 1
		setPinchCapture(true)
	elseif inputState == Enum.UserInputState.Change then
		if runtime.pinchActive and ui.panel.Visible and getSelectedItem() then
			scaleSelectedDecoration(runtime.pinchStartScale * math.max(0.01, tonumber(pinchScale) or 1))
		end
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		if runtime.pinchActive then
			runtime.pinchActive = false
			setPinchCapture(false)
			refreshPreviewMarkers()
		end
	end
end)

UserInputService.LastInputTypeChanged:Connect(function(inputType)
	runtime.lastInputType = inputType
	if ui.panel.Visible then
		setTemporaryStatus(
			inputType == Enum.UserInputType.Touch and "Pinch to Scale" or "Scroll to Scale",
			Color3.fromRGB(47, 236, 255)
		)
	end
end)

-- =============================================================
-- SERVER PREVIEW / APPLY / CANCEL
-- =============================================================
local function sendAquariumDesign(actionName)
	if not canEditLoadedAquarium() then
		setTemporaryStatus("This aquarium is view-only.", Color3.fromRGB(255, 90, 90), 2)
		return false
	end

	if not ShopAction or not ShopAction.Parent then
		ShopAction = Remotes:FindFirstChild("ShopAction")
	end
	if not ShopAction then
		setTemporaryStatus("ShopAction remote is missing.", Color3.fromRGB(255, 90, 90), 2)
		return false
	end
	if not findOwnAquarium() then
		setTemporaryStatus("No personal aquarium found.", Color3.fromRGB(255, 90, 90), 2)
		return false
	end

	local valid, reason = validateEditorItems()
	if not valid then
		setTemporaryStatus(tostring(reason), Color3.fromRGB(255, 90, 90), 2)
		return false
	end

	ShopAction:FireServer(actionName, "Aquarium", "freeDecorations", buildDesignFromEditor())
	return true
end

local function showEditorWithoutReload()
	hideAquariumViewerAccessButton()
	ui.panel.Visible = true
	ui.dimmer.Visible = true
	ui.openButton.Visible = false
	ui.backButton.Visible = false
	setWheelCapture(true)
	refreshThemeButtons()
	refreshPreviewMarkers()
	setTemporaryStatus(UserInputService.TouchEnabled and "Pinch to Scale" or "Scroll to Scale", Color3.fromRGB(47, 236, 255))
end

local function openEditor()
	refreshState()
	updateNearAquarium()
	if not runtime.nearOwnAquarium then
		warn("Aquarium decor editor cannot open: no editable personal aquarium nearby.")
		return
	end

	runtime.previewMode = false
	loadEditorItemsFromState()
	showEditorWithoutReload()
end

local function cancelPreviewIfNeeded()
	if runtime.previewMode and ShopAction then
		ShopAction:FireServer("CancelAquariumPreview", "Aquarium", "freeDecorations")
	end
	runtime.previewMode = false
end

local function closeEditor()
	releaseInputCapture()
	cancelPreviewIfNeeded()
	ui.panel.Visible = false
	ui.dimmer.Visible = false
	ui.backButton.Visible = false
	runtime.selectedIndex = nil
	runtime.selectedDecorationId = nil
	refreshPreviewMarkers()
end

ui.previewButton.MouseButton1Click:Connect(function()
	if sendAquariumDesign("PreviewAquariumDesign") then
		runtime.previewMode = true
		releaseInputCapture()
		ui.panel.Visible = false
		ui.dimmer.Visible = false
		ui.openButton.Visible = false
		ui.backButton.Visible = runtime.nearOwnAquarium
	end
end)

ui.applyButton.MouseButton1Click:Connect(function()
	if sendAquariumDesign("ApplyAquariumDesign") then
		runtime.previewMode = false
		runtime.savedInstalled = {}
		for _, item in ipairs(runtime.items) do
			runtime.savedInstalled[item.decorationId] = true
		end
		runtime.savedBackdropEnabled = runtime.backdropEnabled
		refreshDecorButtons()
		setTemporaryStatus("Aquarium design applied.", Color3.fromRGB(90, 255, 120), 2)
		task.delay(0.5, refreshState)
	end
end)

ui.openButton.MouseButton1Click:Connect(openEditor)
ui.backButton.MouseButton1Click:Connect(showEditorWithoutReload)
ui.closeButton.MouseButton1Click:Connect(closeEditor)

-- Initial render.
updateResponsiveScale()
refreshThemeButtons()
refreshDecorButtons()
refreshPreviewMarkers()

local visibilityAccumulator = 0
RunService.RenderStepped:Connect(function(deltaTime)
	visibilityAccumulator = visibilityAccumulator + deltaTime
	if visibilityAccumulator < 0.20 then
		return
	end
	visibilityAccumulator = 0

	updateResponsiveScale()
	updateNearAquarium()

	if not runtime.nearOwnAquarium then
		if ui.panel.Visible or runtime.previewMode then
			closeEditor()
		end
		ui.openButton.Visible = false
		ui.backButton.Visible = false
		return
	end

	local viewerOpen = isAquariumViewerOpen()
	ui.backButton.Visible = not viewerOpen
		and runtime.previewMode
		and not ui.panel.Visible
	ui.openButton.Visible = not viewerOpen
		and not ui.panel.Visible
		and not ui.backButton.Visible
end)

print("[AquariumFreePlacementEditor] Modern image UI v13 UI-coordinate match loaded.")
