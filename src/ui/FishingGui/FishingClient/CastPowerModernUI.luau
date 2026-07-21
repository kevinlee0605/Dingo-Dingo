-- CastPowerModernUI_CURRENT_ACTIVE_NEW_IMAGES
--
-- This ModuleScript is actually required by the matching patched
-- FishingClient. It renders only the charge instruction, bar, green target,
-- and moving white marker. Input and server logic remain in FishingClient.

local CastPowerModernUI = {}
local UserInputService = game:GetService("UserInputService")

-- Instruction text styling
local RELEASE_TEXT_COLOR_HEX = "#043FD0"

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

-- =========================================================
-- EASY POSITION / SIZE CONTROLS
-- =========================================================
local UI_SCALE_MULTIPLIER = 0.55
local UI_X = 0.50
local UI_Y = 0.64
local MOBILE_UI_Y = 0.50
local DESKTOP_INSTRUCTION_Y = -640
local MOBILE_INSTRUCTION_Y = -190
local BASE_WIDTH = 1280
local BASE_HEIGHT = 340

local TRAVEL_START = 0.012
local TRAVEL_LENGTH = 0.976

local ui = {
	host = nil,
	content = nil,
	scale = nil,
	title = nil,
	targetIcon = nil,
	movingKnob = nil,
	sparkleLayer = nil,
	sparkleScale = nil,
	sparkleTemplate = nil,
	sparkleHolds = 0,
	castVisible = false,
	viewportConnection = nil,
	mountParent = nil,
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

local function requireAuthoredChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	if not (child and child:IsA(className)) then
		error(string.format(
			"[CastPowerModernUI] Authored node %s/%s must be a %s",
			parent and parent:GetFullName() or "<nil>",
			name,
			className
		), 2)
	end
	return child
end

local function refreshVisibility()
	local castVisible = ui.castVisible == true
	local sparkleVisible = (tonumber(ui.sparkleHolds) or 0) > 0

	if ui.content then
		ui.content.Visible = castVisible
	end
	if ui.sparkleLayer then
		ui.sparkleLayer.Visible = sparkleVisible
	end
	if ui.host and ui.host ~= ui.content then
		ui.host.Visible = castVisible or sparkleVisible
	end
end

function CastPowerModernUI.updateResponsiveScale()
	if not ui.scale or not ui.content then
		return
	end

	local camera = workspace.CurrentCamera
	local viewport = camera
		and camera.ViewportSize
		or Vector2.new(1920, 1080)
	local shortest = math.min(viewport.X, viewport.Y)
	local longest = math.max(viewport.X, viewport.Y)
	local isMobile = UserInputService.TouchEnabled
		and (shortest <= 600 or longest / math.max(shortest, 1) >= 1.75)

	local fit = math.min(
		(viewport.X * 0.92) / BASE_WIDTH,
		(viewport.Y * 0.42) / BASE_HEIGHT
	)

	local responsiveScale = math.clamp(
		fit * UI_SCALE_MULTIPLIER,
		0.34,
		1.08
	)
	ui.scale.Scale = responsiveScale
	if ui.sparkleScale then
		ui.sparkleScale.Scale = responsiveScale
	end

	local positionY = isMobile and MOBILE_UI_Y or UI_Y
	ui.content.Position = UDim2.fromScale(UI_X, positionY)
	if ui.sparkleLayer then
		ui.sparkleLayer.Position = UDim2.fromScale(UI_X, positionY)
	end
	if ui.title then
		ui.title.Position = UDim2.fromOffset(
			0,
			isMobile and MOBILE_INSTRUCTION_Y or DESKTOP_INSTRUCTION_Y
		)
	end
end

function CastPowerModernUI.build(parent)
	assert(
		parent,
		"CastPowerModernUI.build requires a parent"
	)

	if ui.content
		and ui.content.Parent
		and ui.mountParent == parent
	then
		return CastPowerModernUI
	end

	if ui.viewportConnection then
		ui.viewportConnection:Disconnect()
		ui.viewportConnection = nil
	end

	local screenGui = findScreenGui(parent)
	assert(
		screenGui and screenGui:GetAttribute("AuthoredUiV2") == true,
		"[CastPowerModernUI] AuthoredUiV2 ScreenGui is required"
	)
	local authoredHost = requireAuthoredChild(
		screenGui,
		"ModernCastPowerUI",
		"Frame"
	)
	local content = requireAuthoredChild(
		authoredHost,
		"CastPowerContent",
		"Frame"
	)
	local sparkleLayer = requireAuthoredChild(
		authoredHost,
		"SparkleLayer",
		"Frame"
	)
	ui.host = authoredHost

	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position =
		UDim2.fromScale(UI_X, UI_Y)
	content.Size = UDim2.fromOffset(
		BASE_WIDTH,
		BASE_HEIGHT
	)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ClipsDescendants = false
	content.Visible = false
	content.ZIndex = 140
	ui.content = content
	ui.mountParent = parent

	local scale = requireAuthoredChild(
		content,
		"CastPowerScale",
		"UIScale"
	)
	scale.Scale = 1
	ui.scale = scale

	local sparkleScale = requireAuthoredChild(
		sparkleLayer,
		"SparkleScale",
		"UIScale"
	)
	local sparkleTemplate = requireAuthoredChild(
		sparkleLayer,
		"PerfectCastSparkleTemplate",
		"Frame"
	)
	requireAuthoredChild(
		sparkleTemplate,
		"SparkleCorner",
		"UICorner"
	)
	sparkleLayer.Visible = false
	sparkleScale.Scale = 1
	sparkleTemplate.Visible = false
	ui.sparkleLayer = sparkleLayer
	ui.sparkleScale = sparkleScale
	ui.sparkleTemplate = sparkleTemplate
	ui.sparkleHolds = 0
	ui.castVisible = false

	local title = requireAuthoredChild(
		content,
		"ChargeInstruction",
		"TextLabel"
	)
	local track = requireAuthoredChild(
		content,
		"CastPowerTrack",
		"Frame"
	)
	local motionArea = requireAuthoredChild(
		track,
		"MotionArea",
		"Frame"
	)
	local targetIcon = requireAuthoredChild(
		motionArea,
		"TargetIcon",
		"Frame"
	)
	local movingKnob = requireAuthoredChild(
		motionArea,
		"MovingKnob",
		"Frame"
	)
	requireAuthoredChild(track, "HoldingBar", "Frame")
	requireAuthoredChild(title, "UITextSizeConstraint", "UITextSizeConstraint")

	ui.title = title
	ui.targetIcon = targetIcon
	ui.movingKnob = movingKnob
	refreshVisibility()

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
	print("[CastPowerModernUI] Bound authored full-height target")

	return CastPowerModernUI
end

function CastPowerModernUI.setVisible(visible)
	ui.castVisible = visible == true
	refreshVisibility()
end

function CastPowerModernUI.getSparkleTemplate()
	return ui.sparkleTemplate
end

function CastPowerModernUI.getSparkleParent()
	return ui.sparkleLayer
end

function CastPowerModernUI.retainSparkle()
	if not (ui.sparkleLayer and ui.sparkleTemplate) then
		return false
	end

	ui.sparkleHolds = (tonumber(ui.sparkleHolds) or 0) + 1
	refreshVisibility()
	return true
end

function CastPowerModernUI.releaseSparkle()
	ui.sparkleHolds = math.max(0, (tonumber(ui.sparkleHolds) or 0) - 1)
	refreshVisibility()
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

	ui.castVisible = false
	ui.sparkleHolds = 0
	if ui.content then
		ui.content.Visible = false
	end
	if ui.sparkleLayer then
		ui.sparkleLayer.Visible = false
	end
	if ui.host then
		ui.host.Visible = false
	end

	for key in pairs(ui) do
		ui[key] = nil
	end
end

return CastPowerModernUI
