-- CastPowerModernUI_CURRENT_ACTIVE_NEW_IMAGES
--
-- This ModuleScript is actually required by the matching patched
-- FishingClient. It renders only the charge instruction, bar, green target,
-- and moving white marker. Input and server logic remain in FishingClient.

local CastPowerModernUI = {}

-- Instruction text styling
local RELEASE_TEXT_COLOR_HEX = "#043FD0"
local DEFAULT_INSTRUCTION = "Hold to charge. Release to cast."

local function styleInstructionText(text)
	local plainText = tostring(text or "")

	-- Keep "Hold to charge." white, and color only
	-- "Release to cast." dark blue.
	return plainText:gsub(
		"Release to cast%.",
		'<font color="'
			.. RELEASE_TEXT_COLOR_HEX
			.. '">Release to cast.</font>'
	)
end

local ASSETS = {
	HoldingBar = "rbxassetid://94855129831884",
	TargetIcon = "rbxassetid://117292116385823",
	MovingKnob = "rbxassetid://126560428939799",
}

-- Roblox resizes the original uploaded textures to these dimensions.
-- The rects are the visible artwork bounds after that resize.
local CROPS = {
	HoldingBar = {
		source = Vector2.new(1024, 256),
		rect = Rect.new(73, 73, 955, 187),
	},
	TargetIcon = {
		source = Vector2.new(1024, 1024),
		rect = Rect.new(235, 202, 789, 787),
	},
	MovingKnob = {
		source = Vector2.new(410, 1024),
		rect = Rect.new(131, 189, 279, 797),
	},
}

-- =========================================================
-- EASY POSITION / SIZE CONTROLS
-- =========================================================
local UI_SCALE_MULTIPLIER = 0.55
local UI_X = 0.50
local UI_Y = 0.64
local BASE_WIDTH = 1280
local BASE_HEIGHT = 340

local BAR_X = 90
local BAR_Y = 130
local BAR_WIDTH = 1100
local BAR_HEIGHT = 142

local MOTION_X = 38
local MOTION_Y = 4
local MOTION_WIDTH = BAR_WIDTH - 76
local MOTION_HEIGHT = BAR_HEIGHT - 8

local TARGET_WIDTH = 106
-- Taller target so the green zone touches the bar's top and bottom edges.
local TARGET_HEIGHT = 166

local KNOB_WIDTH = 38
local KNOB_HEIGHT = 142

local TRAVEL_START = 0.012
local TRAVEL_LENGTH = 0.976

local ui = {
	content = nil,
	scale = nil,
	title = nil,
	targetIcon = nil,
	movingKnob = nil,
	viewportConnection = nil,
}

local function createMappedImage(
	parent,
	name,
	imageId,
	position,
	size,
	zIndex,
	crop
)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Position = position
	holder.Size = size
	holder.ClipsDescendants = true
	holder.ZIndex = zIndex
	holder.Parent = parent

	local cropWidth =
		crop.rect.Max.X - crop.rect.Min.X
	local cropHeight =
		crop.rect.Max.Y - crop.rect.Min.Y

	local targetWidth = size.X.Offset
	local targetHeight = size.Y.Offset

	local fullWidth =
		targetWidth * crop.source.X / cropWidth
	local fullHeight =
		targetHeight * crop.source.Y / cropHeight

	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = imageId
	image.Position = UDim2.fromOffset(
		-(crop.rect.Min.X / crop.source.X)
			* fullWidth,
		-(crop.rect.Min.Y / crop.source.Y)
			* fullHeight
	)
	image.Size = UDim2.fromOffset(
		fullWidth,
		fullHeight
	)
	image.ScaleType = Enum.ScaleType.Stretch
	image.ResampleMode =
		Enum.ResamplerMode.Default
	image.ZIndex = zIndex
	image.Parent = holder

	return holder
end

function CastPowerModernUI.updateResponsiveScale()
	if not ui.scale or not ui.content then
		return
	end

	local camera = workspace.CurrentCamera
	local viewport = camera
		and camera.ViewportSize
		or Vector2.new(1920, 1080)

	local fit = math.min(
		(viewport.X * 0.92) / BASE_WIDTH,
		(viewport.Y * 0.42) / BASE_HEIGHT
	)

	ui.scale.Scale = math.clamp(
		fit * UI_SCALE_MULTIPLIER,
		0.34,
		1.08
	)

	ui.content.Position =
		UDim2.fromScale(UI_X, UI_Y)
end

function CastPowerModernUI.build(parent)
	assert(
		parent,
		"CastPowerModernUI.build requires a parent"
	)

	if ui.content
		and ui.content.Parent == parent
	then
		return CastPowerModernUI
	end

	if ui.viewportConnection then
		ui.viewportConnection:Disconnect()
		ui.viewportConnection = nil
	end

	if ui.content then
		ui.content:Destroy()
	end

	local existing =
		parent:FindFirstChild(
			"ModernCastPowerUI"
		)
	if existing then
		existing:Destroy()
	end

	local content = Instance.new("Frame")
	content.Name = "ModernCastPowerUI"
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position =
		UDim2.fromScale(UI_X, UI_Y)
	content.Size = UDim2.fromOffset(
		BASE_WIDTH,
		BASE_HEIGHT
	)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Visible = false
	content.ZIndex = 140
	content.Parent = parent
	ui.content = content

	local scale = Instance.new("UIScale")
	scale.Name = "ResponsiveScale"
	scale.Scale = 1
	scale.Parent = content
	ui.scale = scale

	local title = Instance.new("TextLabel")
	title.Name = "ChargeInstruction"
	title.BackgroundTransparency = 1
	title.BorderSizePixel = 0
	title.Position = UDim2.fromOffset(
		0,
		-640
	)
	title.Size = UDim2.fromOffset(
		BASE_WIDTH,
		78
	)
	title.Font = Enum.Font.FredokaOne
	title.RichText = true
	title.Text = styleInstructionText(
		DEFAULT_INSTRUCTION
	)
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeColor3 =
		Color3.new(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.TextScaled = true
	title.TextXAlignment =
		Enum.TextXAlignment.Center
	title.TextYAlignment =
		Enum.TextYAlignment.Center
	title.ZIndex = 145
	title.Parent = content
	ui.title = title

	local titleConstraint =
		Instance.new("UITextSizeConstraint")
	titleConstraint.MinTextSize = 24
	titleConstraint.MaxTextSize = 30
	titleConstraint.Parent = title

	local track = Instance.new("Frame")
	track.Name = "CastPowerTrack"
	track.Position = UDim2.fromOffset(
		BAR_X,
		BAR_Y
	)
	track.Size = UDim2.fromOffset(
		BAR_WIDTH,
		BAR_HEIGHT
	)
	track.BackgroundTransparency = 1
	track.BorderSizePixel = 0
	track.ClipsDescendants = false
	track.ZIndex = 142
	track.Parent = content

	createMappedImage(
		track,
		"HoldingBar",
		ASSETS.HoldingBar,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(
			BAR_WIDTH,
			BAR_HEIGHT
		),
		142,
		CROPS.HoldingBar
	)

	local motionArea = Instance.new("Frame")
	motionArea.Name = "MotionArea"
	motionArea.Position = UDim2.fromOffset(
		MOTION_X,
		MOTION_Y
	)
	motionArea.Size = UDim2.fromOffset(
		MOTION_WIDTH,
		MOTION_HEIGHT
	)
	motionArea.BackgroundTransparency = 1
	motionArea.BorderSizePixel = 0
	motionArea.ClipsDescendants = false
	motionArea.ZIndex = 143
	motionArea.Parent = track

	local targetIcon = createMappedImage(
		motionArea,
		"TargetIcon",
		ASSETS.TargetIcon,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(
			TARGET_WIDTH,
			TARGET_HEIGHT
		),
		146,
		CROPS.TargetIcon
	)
	targetIcon.AnchorPoint =
		Vector2.new(0.5, 0.5)
	targetIcon.Position =
		UDim2.fromScale(0.72, 0.5)
	ui.targetIcon = targetIcon

	local movingKnob = createMappedImage(
		motionArea,
		"MovingKnob",
		ASSETS.MovingKnob,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(
			KNOB_WIDTH,
			KNOB_HEIGHT
		),
		148,
		CROPS.MovingKnob
	)
	movingKnob.AnchorPoint =
		Vector2.new(0.5, 0.5)
	movingKnob.Position =
		UDim2.fromScale(
			TRAVEL_START,
			0.5
		)
	ui.movingKnob = movingKnob

	local camera = workspace.CurrentCamera
	if camera then
		ui.viewportConnection =
			camera:GetPropertyChangedSignal(
				"ViewportSize"
			):Connect(
			CastPowerModernUI
				.updateResponsiveScale
		)
	end

	CastPowerModernUI.updateResponsiveScale()

	print(
		"[CastPowerModernUI] Full-height target built"
	)

	return CastPowerModernUI
end

function CastPowerModernUI.setVisible(visible)
	if ui.content then
		ui.content.Visible = visible == true
	end
end

function CastPowerModernUI.setInstruction(text)
	if ui.title then
		ui.title.RichText = true
		ui.title.Text = styleInstructionText(text)
	end
end

function CastPowerModernUI.updateVisual(
	power,
	targetPower
)
	if not ui.movingKnob
		or not ui.targetIcon
	then
		return
	end

	local clampedPower = math.clamp(
		tonumber(power) or 0,
		0,
		1
	)

	local clampedTarget = math.clamp(
		tonumber(targetPower) or 0.72,
		0,
		1
	)

	ui.movingKnob.Position =
		UDim2.fromScale(
			TRAVEL_START
			+ clampedPower
			* TRAVEL_LENGTH,
			0.5
		)

	ui.targetIcon.Position =
		UDim2.fromScale(
			TRAVEL_START
			+ clampedTarget
			* TRAVEL_LENGTH,
			0.5
		)
end

function CastPowerModernUI.destroy()
	if ui.viewportConnection then
		ui.viewportConnection:Disconnect()
		ui.viewportConnection = nil
	end

	if ui.content then
		ui.content:Destroy()
	end

	for key in pairs(ui) do
		ui[key] = nil
	end
end

return CastPowerModernUI
