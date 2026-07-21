local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BottomControlsHud = {}

local BUTTON_BACKBONE_IMAGE = "rbxassetid://97792879182918"

local AUTOFISH_ON_COLOR = Color3.fromRGB(99, 255, 24)
local AUTOFISH_ON_STROKE = Color3.fromRGB(20, 91, 0)
local AUTOFISH_OFF_COLOR = Color3.fromRGB(255, 70, 70)
local AUTOFISH_OFF_STROKE = Color3.fromRGB(115, 0, 0)

local PRESS_SCALE = 0.93
local PRESS_TIME = 0.07
local RELEASE_TIME = 0.11

local function requiredChild(parent, name, className)
	local child = parent:FindFirstChild(name)
	assert(
		child and child:IsA(className),
		string.format(
			"[BottomControlsHud] Expected %s.%s to be a %s",
			parent:GetFullName(),
			name,
			className
		)
	)
	return child
end

function BottomControlsHud.create(deps, refs)
	assert(deps.authoredUiV2, "[BottomControlsHud] AuthoredUiV2 is required")
	assert(deps.findAuthoredHost, "[BottomControlsHud] findAuthoredHost is required")

	local centerControls = deps.findAuthoredHost("BottomButtonsFrame", "GuiObject")
	assert(centerControls, "[BottomControlsHud] Missing authored BottomButtonsFrame")

	-- Every fixed descendant is authored in Explorer. These bindings are
	-- intentionally strict so a partial Rojo sync cannot silently recreate a
	-- different HUD at runtime.
	requiredChild(centerControls, "BottomHudScale", "UIScale")

	local autoButton = requiredChild(centerControls, "AutoFishButton", "TextButton")
	local autoPressScale = requiredChild(autoButton, "PressScale", "UIScale")
	local autoImage = requiredChild(autoButton, "ButtonImage", "ImageLabel")
	requiredChild(autoButton, "AutoFishSizeConstraint", "UISizeConstraint")
	requiredChild(autoButton, "ButtonAspectRatio", "UIAspectRatioConstraint")
	local autoTitleText = requiredChild(autoButton, "AutoFishTitleText", "TextLabel")
	requiredChild(autoTitleText, "UITextSizeConstraint", "UITextSizeConstraint")
	requiredChild(autoTitleText, "TextOutline", "UIStroke")
	local autoStateText = requiredChild(autoButton, "AutoFishStateText", "TextLabel")
	requiredChild(autoStateText, "UITextSizeConstraint", "UITextSizeConstraint")
	local autoStateOutline = requiredChild(autoStateText, "TextOutline", "UIStroke")
	local autoGradient = requiredChild(autoButton, "StateGradient", "UIGradient")
	local autoVisual = requiredChild(autoButton, "ModernAutoFishVisual", "Frame")
	local autoVisualScale = requiredChild(autoVisual, "PressScale", "UIScale")
	local autoCircle = requiredChild(autoVisual, "Circle", "Frame")
	local autoOuterStroke = requiredChild(autoCircle, "OuterStroke", "UIStroke")
	local autoInnerRing = requiredChild(autoCircle, "InnerRing", "Frame")
	local autoInnerStroke = requiredChild(autoInnerRing, "InnerStroke", "UIStroke")
	local autoVisualText = requiredChild(autoCircle, "AutoText", "TextLabel")
	local autoVisualTextConstraint = requiredChild(
		autoVisualText,
		"UITextSizeConstraint",
		"UITextSizeConstraint"
	)

	local tapButton = requiredChild(centerControls, "TapButton", "TextButton")
	local tapPressScale = requiredChild(tapButton, "PressScale", "UIScale")
	local tapImage = requiredChild(tapButton, "ButtonImage", "ImageLabel")
	requiredChild(tapButton, "TapSizeConstraint", "UISizeConstraint")
	requiredChild(tapButton, "ButtonAspectRatio", "UIAspectRatioConstraint")
	local tapStateText = requiredChild(tapButton, "TapText", "TextLabel")
	requiredChild(tapStateText, "UITextSizeConstraint", "UITextSizeConstraint")
	requiredChild(tapStateText, "TextOutline", "UIStroke")
	local tapVisual = requiredChild(tapButton, "CodeCircleVisual", "Frame")
	local tapVisualScale = requiredChild(tapVisual, "PressScale", "UIScale")
	local tapVisualCenter = requiredChild(tapVisual, "TranslucentCenter", "Frame")
	local tapVisualText = requiredChild(tapVisualCenter, "TapText", "TextLabel")
	local tapVisualTextConstraint = requiredChild(
		tapVisualText,
		"UITextSizeConstraint",
		"UITextSizeConstraint"
	)

	local centerTitle = requiredChild(centerControls, "CenterTitle", "TextLabel")
	requiredChild(centerTitle, "UITextSizeConstraint", "UITextSizeConstraint")
	local centerBaitText = requiredChild(centerControls, "CenterBaitText", "TextLabel")
	requiredChild(centerBaitText, "UITextSizeConstraint", "UITextSizeConstraint")

	refs.centerControls = centerControls
	refs.centerAutoButton = autoButton
	refs.centerCastButton = tapButton
	refs.centerAutoImage = autoImage
	refs.centerCastImage = tapImage
	refs.centerAutoPressScale = autoPressScale
	refs.centerCastPressScale = tapPressScale
	refs.centerAutoTitleText = autoTitleText
	refs.centerAutoStateText = autoStateText
	refs.centerCastStateText = tapStateText
	refs.centerAutoGradient = autoGradient
	refs.centerTitle = centerTitle
	refs.centerBaitText = centerBaitText

	autoTitleText.Font = Enum.Font.GothamBlack
	autoStateText.Font = Enum.Font.GothamBlack
	tapStateText.Font = Enum.Font.GothamBlack

	autoImage.Image = BUTTON_BACKBONE_IMAGE
	tapImage.Image = BUTTON_BACKBONE_IMAGE
	autoImage.Visible = false
	tapImage.Visible = false
	autoTitleText.Visible = false
	autoStateText.Visible = false
	tapStateText.Visible = false
	autoVisual.Visible = true
	tapVisual.Visible = true
	tapImage.ImageTransparency = 0.2
	autoButton.TextTransparency = 1
	tapButton.TextTransparency = 1
	autoButton.BackgroundTransparency = 1
	tapButton.BackgroundTransparency = 1
	autoButton.AutoButtonColor = false
	tapButton.AutoButtonColor = false
	autoGradient.Transparency = NumberSequence.new(1)

	centerTitle.Text = "Lilyshore Island"
	centerTitle.Visible = false
	centerBaitText.Text = "Bait: Basic Bait (Unlimited)"
	centerBaitText.Visible = false

	local function tweenScale(scaleObject, target, duration)
		TweenService:Create(
			scaleObject,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = target }
		):Play()
	end

	local function bindPress(button, pressScale)
		button.MouseButton1Down:Connect(function()
			tweenScale(pressScale, PRESS_SCALE, PRESS_TIME)
		end)

		local function release()
			tweenScale(pressScale, 1, RELEASE_TIME)
		end

		button.MouseButton1Up:Connect(release)
		button.MouseLeave:Connect(release)
	end

	-- The original root scales remain for hierarchy compatibility; the final
	-- v1615 circular artwork owns the pressed animation.
	autoPressScale.Scale = 1
	tapPressScale.Scale = 1
	bindPress(autoButton, autoVisualScale)
	bindPress(tapButton, tapVisualScale)

	local positioningAuto = false
	local function positionAutoButton()
		if positioningAuto or not autoButton.Parent or not tapButton.Parent then
			return
		end
		local tapSize = tapButton.AbsoluteSize
		if tapSize.X <= 0 or tapSize.Y <= 0 then
			return
		end

		positioningAuto = true
		-- Keep the two interaction areas identical to their responsive layout.
		autoButton.Size = tapButton.Size
		local autoSize = autoButton.AbsoluteSize
		local gap = math.clamp(tapSize.Y * 0.08, 8, 20)
		local targetCenterX = tapButton.AbsolutePosition.X + tapSize.X * 0.5 + tapSize.X * 0.38
		local targetBottomY = tapButton.AbsolutePosition.Y - gap
		local targetTopLeft = Vector2.new(targetCenterX - autoSize.X * 0.5, targetBottomY - autoSize.Y)
		local difference = targetTopLeft - autoButton.AbsolutePosition
		if math.abs(difference.X) >= 0.5 or math.abs(difference.Y) >= 0.5 then
			local current = autoButton.Position
			autoButton.Position = UDim2.new(
				current.X.Scale,
				current.X.Offset + math.round(difference.X),
				current.Y.Scale,
				current.Y.Offset + math.round(difference.Y)
			)
		end
		autoButton.ZIndex = math.max(autoButton.ZIndex, tapButton.ZIndex + 10)
		positioningAuto = false
	end

	local viewportConnection = nil
	local function updateResponsiveButtonLayout()
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local isMobile = math.min(viewport.X, viewport.Y) <= 600

		local visualSize = isMobile and 108 or 140
		local buttonWidth = isMobile and 220 or 268
		local buttonHeight = isMobile and 115 or 140
		local textSize = isMobile and 20 or 28

		tapButton.Size = UDim2.fromOffset(buttonWidth, buttonHeight)
		autoButton.Size = UDim2.fromOffset(buttonWidth, buttonHeight)
		tapVisual.Size = UDim2.fromOffset(visualSize, visualSize)
		autoVisual.Size = UDim2.fromOffset(visualSize, visualSize)

		-- On phones, move the whole pair above and to the right of the hotbar.
		tapButton.Position = if isMobile
			then UDim2.new(0.87, 0, 0.22, 0)
			else UDim2.new(0.68, 0, 0.50, 0)

		for _, label in ipairs({ tapVisualText, autoVisualText }) do
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromScale(0.5, 0.5)
			label.Size = UDim2.fromScale(0.86, 0.48)
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = false
			label.TextSize = textSize
			label.TextWrapped = false
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextYAlignment = Enum.TextYAlignment.Center
		end
		autoVisualTextConstraint.MinTextSize = 16
		autoVisualTextConstraint.MaxTextSize = textSize
		tapVisualTextConstraint.MinTextSize = 16
		tapVisualTextConstraint.MaxTextSize = textSize

		task.defer(positionAutoButton)
	end

	for _, object in ipairs({ centerControls, tapButton, autoButton }) do
		object:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			task.defer(positionAutoButton)
		end)
		object:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			task.defer(positionAutoButton)
		end)
	end
	local function bindViewport()
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		local camera = Workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(
				updateResponsiveButtonLayout
			)
		end
		updateResponsiveButtonLayout()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		bindViewport()
	end)
	bindViewport()

	local function setAutoFishVisual(isOn)
		if isOn then
			autoStateText.Text = "ON"
			autoStateText.TextColor3 = AUTOFISH_ON_COLOR
			autoStateText.TextStrokeColor3 = AUTOFISH_ON_STROKE
			autoStateOutline.Color = AUTOFISH_ON_STROKE
			autoCircle.BackgroundColor3 = Color3.fromRGB(101, 205, 74)
			autoOuterStroke.Color = Color3.fromRGB(151, 255, 105)
			autoInnerStroke.Color = Color3.fromRGB(35, 112, 22)
		else
			autoStateText.Text = "OFF"
			autoStateText.TextColor3 = AUTOFISH_OFF_COLOR
			autoStateText.TextStrokeColor3 = AUTOFISH_OFF_STROKE
			autoStateOutline.Color = AUTOFISH_OFF_STROKE
			autoCircle.BackgroundColor3 = Color3.fromRGB(226, 65, 72)
			autoOuterStroke.Color = Color3.fromRGB(255, 104, 108)
			autoInnerStroke.Color = Color3.fromRGB(135, 17, 25)
		end

		autoButton.TextTransparency = 1
		autoButton.BackgroundTransparency = 1
		autoVisualText.Text = "AUTO"
		autoVisualText.Visible = true
	end

	local function updateAutoFishVisualFromButtonText()
		local text = string.lower(tostring(autoButton.Text or ""))
		local containsOff = string.find(text, "off", 1, true) ~= nil
		local containsOn = string.find(text, "on", 1, true) ~= nil
		setAutoFishVisual(containsOn and not containsOff)
	end

	refs.setAutoFishVisual = setAutoFishVisual
	autoButton:GetPropertyChangedSignal("Text"):Connect(updateAutoFishVisualFromButtonText)
	updateAutoFishVisualFromButtonText()

	local function updateTapVisualFromButtonText()
		tapVisualText.Text = "TAP"
		tapVisualText.Visible = true
		tapButton.TextTransparency = 1
		tapButton.BackgroundTransparency = 1
	end

	tapButton:GetPropertyChangedSignal("Text"):Connect(updateTapVisualFromButtonText)
	updateTapVisualFromButtonText()

	if autoButton.Text == "" then
		autoButton.Text = "AutoFish OFF"
	end
	if tapButton.Text == "" then
		tapButton.Text = "Tap"
	end
end

return BottomControlsHud
