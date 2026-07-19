local MinigameController = {}

--[[
IMAGE PART MINIGAME CONTROLLER V8 HEADER_LEFT_SAFE

Replace this ModuleScript:
StarterGui/FishingGui/FishingClientModules/Fishing/MinigameController

Changes in V8:
- Header text shifted left and narrowed so the two-line 'Keep the fish inside the green bar!' text does not overlap the vertical gauge UI.
- Bait text size/box adjusted to visually match Cast text while preserving spacing.
- WaterPanel movement area remains clamped so CatchBar cannot leave the water image.
- Water panel, fish marker, catch bar, and progress track are repositioned to match the reference layout.
- After bite starts, header text becomes: "Keep the fish inside the green bar!"
- Status bubble is moved upward and kept inside the backbone.
- Vertical progress track is resized/moved so it does not stick outside the backbone.
- FishingBarSkin stays hidden while this minigame UI is visible.
]]

local UserInputService = game:GetService("UserInputService")

local FISH_MARKER_CIRCLE_IMAGE = "rbxassetid://124714933908063"
local MINIGAME_BACKBONE_IMAGE = "rbxassetid://140008030569826"
local MINIGAME_CATCH_BAR_IMAGE = "rbxassetid://72935006096854"
local MINIGAME_HEADER_BUBBLE_IMAGE = "rbxassetid://94478830162984"
local MINIGAME_PROGRESS_TRACK_IMAGE = "rbxassetid://120249292898820"
local MINIGAME_STATUS_BUBBLE_IMAGE = "rbxassetid://136580421866122"
local MINIGAME_WATER_PANEL_IMAGE = "rbxassetid://93175836051188"

local PANEL_ASPECT = 1182 / 1331

-- Device sizing. Adjust only these if needed.
local DESKTOP_WIDTH_LIMIT = 0.46
local DESKTOP_HEIGHT_LIMIT = 0.70

local TABLET_WIDTH_LIMIT = 0.50
local TABLET_HEIGHT_LIMIT = 0.72

local PHONE_WIDTH_LIMIT = 0.56
local PHONE_HEIGHT_LIMIT = 0.78

local WHITE = Color3.fromRGB(255, 255, 255)
local PROGRESS_BLUE = Color3.fromRGB(19, 153, 255)
local PROGRESS_BLUE_LIGHT = Color3.fromRGB(102, 225, 255)

local function addCorner(obj, radiusScale, radiusOffset)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radiusScale or 0, radiusOffset or 12)
	corner.Parent = obj
	return corner
end

local function addGradient(obj, topColor, bottomColor, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topColor),
		ColorSequenceKeypoint.new(1, bottomColor),
	})
	gradient.Rotation = rotation or 90
	gradient.Parent = obj
	return gradient
end

local function makeImage(parent, name, image, position, size, zIndex)
	local img = Instance.new("ImageLabel")
	img.Name = name
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = position
	img.Size = size
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = image
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = zIndex or 1
	img.Parent = parent
	return img
end

local function makeText(parent, name, text, position, size, maxTextSize, color, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = text or ""
	label.TextColor3 = color or WHITE
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.10
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextWrapped = true
	label.ZIndex = zIndex or 1
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 9
	constraint.MaxTextSize = maxTextSize or 28
	constraint.Parent = label

	return label
end

local function makeRichText(parent, name, text, position, size, maxTextSize, zIndex)
	local label = makeText(parent, name, text, position, size, maxTextSize, WHITE, zIndex)
	label.RichText = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	return label
end

local function getDeviceKind(viewport)
	local width = viewport.X
	local height = viewport.Y
	local shortest = math.min(width, height)
	local longest = math.max(width, height)
	local aspect = longest / math.max(shortest, 1)

	local isTouch = UserInputService.TouchEnabled

	if isTouch and (shortest <= 520 or aspect >= 1.75) then
		return "phone"
	end

	if isTouch or shortest <= 900 then
		return "tablet"
	end

	return "desktop"
end

local function getSizingForDevice(deviceKind)
	if deviceKind == "phone" then
		return PHONE_WIDTH_LIMIT, PHONE_HEIGHT_LIMIT
	elseif deviceKind == "tablet" then
		return TABLET_WIDTH_LIMIT, TABLET_HEIGHT_LIMIT
	else
		return DESKTOP_WIDTH_LIMIT, DESKTOP_HEIGHT_LIMIT
	end
end

local function attachResponsivePanelLayout(panel)
	local function updateLayout()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)

		local screenWidth = math.max(viewport.X, 1)
		local screenHeight = math.max(viewport.Y, 1)

		local deviceKind = getDeviceKind(viewport)
		local widthLimit, heightLimit = getSizingForDevice(deviceKind)

		local widthFromScreen = screenWidth * widthLimit
		local widthFromHeight = screenHeight * heightLimit * PANEL_ASPECT

		local finalWidth = math.min(widthFromScreen, widthFromHeight)
		finalWidth = math.clamp(finalWidth, math.min(340, screenWidth * 0.86), screenWidth * 0.92)

		local finalHeight = finalWidth / PANEL_ASPECT

		panel.Size = UDim2.fromOffset(finalWidth, finalHeight)
		panel.Position = UDim2.fromScale(0.5, 0.47)
	end

	updateLayout()

	task.defer(function()
		updateLayout()

		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
		end
	end)

	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		task.defer(updateLayout)
	end)
end

local function setFishingBarsVisible(ctx, visible)
	local ui = ctx.ui
	local root = ui and ui.root

	if ui and ui.centerControls then
		ui.centerControls.Visible = visible
	end

	if root then
		local names = {
			LayeredFishingBar = true,
			FishingBar = true,
			FishingCenterControls = true,
			CenterControls = true,
			CenterActionBar = true,
		}

		for _, obj in ipairs(root:GetDescendants()) do
			if names[obj.Name] and obj:IsA("GuiObject") then
				obj.Visible = visible
			end
		end
	end
end

local function getFishImage(ctx, fish)
	if not fish then
		return ""
	end

	if fish.image then
		return fish.image
	end
	if fish.imageId then
		return fish.imageId
	end
	if fish.icon then
		return fish.icon
	end

	local fishId = fish.imageKey or fish.id or fish.fishId
	if not fishId then
		return ""
	end

	local ok, image = pcall(function()
		return ctx.GameConfig.getFishImage(fishId)
	end)

	if ok and image then
		return image
	end

	return ""
end

local function ensureUi(ctx)
	local ui = ctx.ui
	local root = ui.root

	if ui.customFishingMinigame then
		return ui.customFishingMinigame
	end

	local panel = Instance.new("Frame")
	panel.Name = "CustomFishingMinigame"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 120
	panel.Parent = root

	attachResponsivePanelLayout(panel)

	local backbone = makeImage(
		panel,
		"MinigameBackbone",
		MINIGAME_BACKBONE_IMAGE,
		UDim2.fromScale(0.5, 0.5),
		UDim2.fromScale(1, 1),
		120
	)

	-- Header is now inside the big backbone, not hanging over the top edge.
	-- Header bubble image removed.
	-- This is now text-only, placed directly inside the Minigame_Backbone like the reference image.
	-- Header text safety zone (V8):
	-- Shifted left so the two-line header does not touch the vertical gauge.
	-- Kept fully inside the backbone and clear of the gold corner / water panel.
	local headerText = makeText(
		panel,
		"HeaderText",
		"Waiting for a bite...",
		UDim2.fromScale(0.278, 0.245),
		UDim2.fromScale(0.300, 0.060),
		15,
		WHITE,
		140
	)
	headerText.TextXAlignment = Enum.TextXAlignment.Center

	local waterPanel = makeImage(
		panel,
		"WaterPanel",
		MINIGAME_WATER_PANEL_IMAGE,
		UDim2.fromScale(0.258, 0.505),
		UDim2.fromScale(0.350, 0.575),
		130
	)
	waterPanel.ClipsDescendants = true

	local waterInner = Instance.new("Frame")
	waterInner.Name = "WaterInnerMovementArea"
	waterInner.AnchorPoint = Vector2.new(0.5, 0.5)
	waterInner.Position = UDim2.fromScale(0.5, 0.500)
	waterInner.Size = UDim2.fromScale(0.765, 0.735)
	waterInner.BackgroundTransparency = 1
	waterInner.BorderSizePixel = 0
	waterInner.ClipsDescendants = true
	waterInner.ZIndex = 132
	waterInner.Parent = waterPanel

	local catchBar = makeImage(
		waterInner,
		"CatchBar",
		MINIGAME_CATCH_BAR_IMAGE,
		UDim2.fromScale(0.5, 0.70),
		UDim2.fromScale(0.82, 0.22),
		138
	)
	catchBar.AnchorPoint = Vector2.new(0.5, 0)

	local fishMarker = makeImage(
		waterInner,
		"FishMarkerCircle",
		FISH_MARKER_CIRCLE_IMAGE,
		UDim2.fromScale(0.5, 0.36),
		UDim2.fromScale(0.245, 0.160),
		142
	)

	local fishImage = Instance.new("ImageLabel")
	fishImage.Name = "FishImage"
	fishImage.AnchorPoint = Vector2.new(0.5, 0.5)
	fishImage.Position = UDim2.fromScale(0.5, 0.5)
	fishImage.Size = UDim2.fromScale(0.74, 0.74)
	fishImage.BackgroundTransparency = 1
	fishImage.BorderSizePixel = 0
	fishImage.ScaleType = Enum.ScaleType.Fit
	fishImage.ZIndex = 145
	fishImage.Parent = fishMarker

	-- Progress track is smaller and shifted inward so it stays inside the backbone.
	local progressTrack = makeImage(
		panel,
		"ProgressTrack",
		MINIGAME_PROGRESS_TRACK_IMAGE,
		UDim2.fromScale(0.505, 0.505),
		UDim2.fromScale(0.066, 0.535),
		130
	)
	progressTrack.ClipsDescendants = true

	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.AnchorPoint = Vector2.new(0.5, 1)
	progressFill.Position = UDim2.fromScale(0.5, 0.890)
	progressFill.Size = UDim2.fromScale(0.58, 0)
	progressFill.BackgroundColor3 = PROGRESS_BLUE
	progressFill.BorderSizePixel = 0
	progressFill.ZIndex = 134
	progressFill.Parent = progressTrack
	addCorner(progressFill, 0, 12)
	addGradient(progressFill, PROGRESS_BLUE_LIGHT, PROGRESS_BLUE, 90)

	-- Status bubble moved upward but still inside the backbone.
	local statusBubble = makeImage(
		panel,
		"StatusBubble",
		MINIGAME_STATUS_BUBBLE_IMAGE,
		UDim2.fromScale(0.755, 0.300),
		UDim2.fromScale(0.370, 0.080),
		135
	)

	local statusText = makeText(
		statusBubble,
		"StatusText",
		"Something is biting...",
		UDim2.fromScale(0.52, 0.50),
		UDim2.fromScale(0.86, 0.72),
		22,
		WHITE,
		140
	)

	local progressText = makeText(
		panel,
		"ProgressText",
		"Progress --",
		UDim2.fromScale(0.742, 0.410),
		UDim2.fromScale(0.32, 0.055),
		24,
		WHITE,
		140
	)

	local baitText = makeRichText(
		panel,
		"BaitText",
		'<font color="#38D9FF">Bait:</font> Basic Bait (Unlimited)',
		UDim2.fromScale(0.768, 0.505),
		UDim2.fromScale(0.390, 0.078),
		18,
		140
	)

	local castText = makeRichText(
		panel,
		"CastText",
		'<font color="#38D9FF">Cast:</font> Perfect!',
		UDim2.fromScale(0.768, 0.590),
		UDim2.fromScale(0.390, 0.052),
		18,
		140
	)

	local instructionText = makeText(
		panel,
		"InstructionText",
		"Hold mouse, tap, or Space to lift the green bar. Release to let it fall.",
		UDim2.fromScale(0.765, 0.680),
		UDim2.fromScale(0.390, 0.090),
		13,
		Color3.fromRGB(204, 226, 255),
		140
	)
	instructionText.TextStrokeTransparency = 0.42

	ui.customFishingMinigame = {
		panel = panel,
		backbone = backbone,
		headerText = headerText,
		waterPanel = waterPanel,
		waterInner = waterInner,
		catchBar = catchBar,
		fishMarker = fishMarker,
		fishImage = fishImage,
		progressTrack = progressTrack,
		progressFill = progressFill,
		statusBubble = statusBubble,
		statusText = statusText,
		progressText = progressText,
		baitText = baitText,
		castText = castText,
		instructionText = instructionText,
	}

	return ui.customFishingMinigame
end

function MinigameController.build(ctx)
	return ensureUi(ctx)
end

return MinigameController

