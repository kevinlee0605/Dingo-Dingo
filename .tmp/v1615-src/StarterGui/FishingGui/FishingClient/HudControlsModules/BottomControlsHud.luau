local TweenService = game:GetService("TweenService")

local BottomControlsHud = {}

function BottomControlsHud.create(deps, refs)
	local screenGui = deps.screenGui
	local makeText = deps.makeText
	local limitTextSize = deps.limitTextSize

	-- Asset Manager에 업로드한 '글자 없는 버튼 배경(Backbone.png)'의 ID만 넣으면 됩니다.
	-- Tap과 AutoFish는 같은 배경 이미지를 사용하고, 글자는 코드로 표시됩니다.
	local BUTTON_BACKBONE_IMAGE = "rbxassetid://97792879182918"

	-- Backbone.png 전체를 사용하되, 원본의 투명 여백만큼 ImageLabel을 확대합니다.
	-- 이렇게 하면 실제 버튼의 보이는 크기는 유지하면서 위/아래 테두리가 잘리지 않습니다.
	local BUTTON_CANVAS_WIDTH = 1447
	local BUTTON_CANVAS_HEIGHT = 1087
	local BUTTON_VISIBLE_WIDTH = 1267
	local BUTTON_VISIBLE_HEIGHT = 661
	local BUTTON_IMAGE_SCALE_X = BUTTON_CANVAS_WIDTH / BUTTON_VISIBLE_WIDTH
	local BUTTON_IMAGE_SCALE_Y = BUTTON_CANVAS_HEIGHT / BUTTON_VISIBLE_HEIGHT
	local BUTTON_ASPECT_RATIO = BUTTON_VISIBLE_WIDTH / BUTTON_VISIBLE_HEIGHT

	-- AutoFish 상태 글자 색
	local AUTOFISH_ON_COLOR = Color3.fromRGB(99, 255, 24)
	local AUTOFISH_ON_STROKE = Color3.fromRGB(20, 91, 0)
	local AUTOFISH_OFF_COLOR = Color3.fromRGB(255, 70, 70)
	local AUTOFISH_OFF_STROKE = Color3.fromRGB(115, 0, 0)
	local AUTOFISH_ON_COLOR = Color3.fromRGB(99, 255, 24)

	-- 글자 크기 비율은 제공된 AutoFish/Tap 참고 이미지에 맞춰 크게 조정되어 있습니다.
	-- 버튼 크기와 위치는 유지하고, 글자 레이아웃만 변경합니다.

	-- 버튼 공통 글자 색
	local MAIN_TEXT_COLOR = Color3.fromRGB(255, 255, 255)
	local MAIN_TEXT_STROKE = Color3.fromRGB(6, 39, 111)
	local MAIN_TEXT_COLOR = Color3.fromRGB(255, 255, 255)

	-- AutoFish / Tap 전체 묶음 위치와 크기
	local CENTER_CONTROLS_POSITION = UDim2.fromScale(0.6, 0.68)
	local CENTER_CONTROLS_SIZE = UDim2.fromScale(1, 0.28)

	-- AutoFish / Tap 버튼은 같은 크기로 맞춥니다.
	local AUTO_BUTTON_POSITION = UDim2.fromScale(0.15, 0.5)
	local AUTO_BUTTON_SIZE = UDim2.new(0.17, 0, 0, 145)
	local AUTO_BUTTON_MIN_SIZE = Vector2.new(220, 115)
	local AUTO_BUTTON_MAX_SIZE = Vector2.new(300, 157)

	local TAP_BUTTON_POSITION = UDim2.fromScale(0.65, 0.5)
	local TAP_BUTTON_SIZE = UDim2.new(0.17, 0, 0, 145)
	local TAP_BUTTON_MIN_SIZE = Vector2.new(220, 115)
	local TAP_BUTTON_MAX_SIZE = Vector2.new(300, 157)

	local PRESS_SCALE = 0.93
	local PRESS_TIME = 0.07
	local RELEASE_TIME = 0.11

	-- 글자 외곽선 두께. 더 두껍게 하려면 2.8~3.2 정도로 올리면 됩니다.
	local TEXT_OUTLINE_THICKNESS = 2.4

	if deps.authoredUiV2 and deps.findAuthoredHost then
		local centerControls = deps.findAuthoredHost("BottomButtonsFrame", "GuiObject")
		local autoButton = centerControls and centerControls:FindFirstChild("AutoFishButton")
		local tapButton = centerControls and centerControls:FindFirstChild("TapButton")

		if centerControls
			and autoButton and autoButton:IsA("TextButton")
			and tapButton and tapButton:IsA("TextButton")
		then
			refs.centerControls = centerControls
			refs.centerAutoButton = autoButton
			refs.centerCastButton = tapButton
			refs.centerAutoImage = autoButton:FindFirstChild("ButtonImage")
			refs.centerCastImage = tapButton:FindFirstChild("ButtonImage")
			refs.centerAutoPressScale = autoButton:FindFirstChild("PressScale")
			refs.centerCastPressScale = tapButton:FindFirstChild("PressScale")

			-- FishingClient still changes this gradient when the fishing island
			-- changes. It is a behavior-owned effect, not a second HUD surface.
			local autoGradient = autoButton:FindFirstChild("StateGradient")
				or autoButton:FindFirstChildOfClass("UIGradient")
			if not autoGradient then
				autoGradient = Instance.new("UIGradient")
				autoGradient.Name = "StateGradient"
				autoGradient.Transparency = NumberSequence.new(1)
				autoGradient.Parent = autoButton
			end
			refs.centerAutoGradient = autoGradient

			local function compatibilityLabel(name, parent)
				local existing = centerControls:FindFirstChild(name, true)
				if existing and existing:IsA("TextLabel") then
					return existing
				end

				local label = Instance.new("TextLabel")
				label.Name = name
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromOffset(0, 0)
				label.Text = ""
				label.TextTransparency = 1
				label.Visible = false
				label.Parent = parent
				return label
			end

			refs.centerTitle = compatibilityLabel("CenterTitle", autoButton)
			refs.centerTitle.Text = "Lilyshore Island"
			refs.centerBaitText = compatibilityLabel("CenterBaitText", tapButton)
			refs.centerBaitText.Text = "Bait: Basic Bait (Unlimited)"
			refs.centerAutoTitleText = autoButton
			refs.centerAutoStateText = autoButton
			refs.centerCastStateText = tapButton

			local function setAutoFishVisual(isOn)
				local desiredText = isOn and "AutoFish ON" or "AutoFish OFF"
				if autoButton.Text ~= desiredText then
					autoButton.Text = desiredText
				end
				autoButton.TextColor3 = isOn and AUTOFISH_ON_COLOR or MAIN_TEXT_COLOR
			end

			local function updateAutoFishVisualFromButtonText()
				local text = string.lower(tostring(autoButton.Text or ""))
				local containsOff = string.find(text, "off", 1, true) ~= nil
				local containsOn = string.find(text, "on", 1, true) ~= nil
				autoButton.TextColor3 = containsOn and not containsOff
					and AUTOFISH_ON_COLOR
					or MAIN_TEXT_COLOR
			end

			refs.setAutoFishVisual = setAutoFishVisual
			autoButton:GetPropertyChangedSignal("Text"):Connect(updateAutoFishVisualFromButtonText)
			updateAutoFishVisualFromButtonText()

			if autoButton.Text == "" then
				autoButton.Text = "AutoFish OFF"
			end
			if tapButton.Text == "" then
				tapButton.Text = "Tap"
			end

			-- BottomHudScale/DeviceScale is authored under the frame. Leave it
			-- untouched so AuthoredUiController is the only device-scale writer.
			return
		end

		warn("[BottomControlsHud] Authored BottomButtonsFrame is incomplete; using the legacy fallback")
	end

	local function addTextLimit(label, minSize, maxSize)
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MinTextSize = minSize
		constraint.MaxTextSize = maxSize
		constraint.Parent = label
		return constraint
	end

	local function tweenScale(scaleObject, target, duration)
		TweenService:Create(
			scaleObject,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = target }
		):Play()
	end

	local function makeImageButton(parent, name, position, size, minSize, maxSize)
		local button = Instance.new("TextButton")
		button.Name = name
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = position
		button.Size = size
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.Text = ""
		button.TextTransparency = 1
		button.AutoButtonColor = false
		button.ClipsDescendants = false
		button.Visible = true
		button.ZIndex = 1001
		button.Parent = parent

		local scale = Instance.new("UIScale")
		scale.Name = "PressScale"
		scale.Scale = 1
		scale.Parent = button

		local image = Instance.new("ImageLabel")
		image.Name = "ButtonImage"
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(BUTTON_IMAGE_SCALE_X, BUTTON_IMAGE_SCALE_Y)
		image.BackgroundTransparency = 1
		image.Image = BUTTON_BACKBONE_IMAGE
		image.ScaleType = Enum.ScaleType.Fit
		image.ImageRectOffset = Vector2.zero
		image.ImageRectSize = Vector2.zero
		image.ZIndex = 1002
		image.Parent = button

		local sizeConstraint = Instance.new("UISizeConstraint")
		sizeConstraint.MinSize = minSize
		sizeConstraint.MaxSize = maxSize
		sizeConstraint.Parent = button

		local aspectConstraint = Instance.new("UIAspectRatioConstraint")
		aspectConstraint.AspectRatio = BUTTON_ASPECT_RATIO
		aspectConstraint.DominantAxis = Enum.DominantAxis.Width
		aspectConstraint.Parent = button

		button.MouseButton1Down:Connect(function()
			tweenScale(scale, PRESS_SCALE, PRESS_TIME)
		end)

		local function release()
			tweenScale(scale, 1, RELEASE_TIME)
		end

		button.MouseButton1Up:Connect(release)
		button.MouseLeave:Connect(release)

		-- FishingClient가 Text를 상태 저장용으로 바꿔도 실제 기본 글자는 보이지 않게 유지합니다.
		button:GetPropertyChangedSignal("TextTransparency"):Connect(function()
			if button.TextTransparency ~= 1 then
				button.TextTransparency = 1
			end
		end)

		button:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
			if button.BackgroundTransparency ~= 1 then
				button.BackgroundTransparency = 1
			end
		end)

		return button, image, scale
	end

	local function makeOutlinedText(parent, name, position, size, text, color, strokeColor, minTextSize, maxTextSize)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = position
		label.Size = size
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.ZIndex = 1003
		label.Parent = parent
		addTextLimit(label, minTextSize, maxTextSize)

		local outline = Instance.new("UIStroke")
		outline.Name = "TextOutline"
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		outline.Color = strokeColor
		outline.Thickness = TEXT_OUTLINE_THICKNESS
		outline.Transparency = 0
		outline.LineJoinMode = Enum.LineJoinMode.Round
		outline.Parent = label

		return label
	end

	refs.centerControls = Instance.new("Frame")
	refs.centerControls.Name = "BottomButtonsFrame"
	refs.centerControls.AnchorPoint = Vector2.new(0.5, 0.5)
	refs.centerControls.Position = CENTER_CONTROLS_POSITION
	refs.centerControls.Size = CENTER_CONTROLS_SIZE
	refs.centerControls.BackgroundTransparency = 1
	refs.centerControls.ClipsDescendants = false
	refs.centerControls.Visible = false
	refs.centerControls.ZIndex = 1000
	refs.centerControls.Parent = screenGui

	local centerControlsScale = Instance.new("UIScale")
	centerControlsScale.Scale = 1
	centerControlsScale.Parent = refs.centerControls

	refs.centerTitle = makeText(refs.centerControls, "Lilyshore Island", 15, Color3.fromRGB(230, 238, 248), true)
	refs.centerTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	refs.centerTitle.Position = UDim2.fromScale(0.55, 0.10)
	refs.centerTitle.Size = UDim2.new(0.28, 0, 0, 22)
	refs.centerTitle.BackgroundTransparency = 1
	refs.centerTitle.ZIndex = 1001
	refs.centerTitle.Visible = false
	refs.centerTitle.TextXAlignment = Enum.TextXAlignment.Center
	limitTextSize(refs.centerTitle, 12, 16)

	-- AutoFish 버튼
	refs.centerAutoButton, refs.centerAutoImage, refs.centerAutoPressScale = makeImageButton(
		refs.centerControls,
		"AutoFishButton",
		AUTO_BUTTON_POSITION,
		AUTO_BUTTON_SIZE,
		AUTO_BUTTON_MIN_SIZE,
		AUTO_BUTTON_MAX_SIZE
	)

	-- 실제 기능 상태는 기존 FishingClient가 이 Text를 "AutoFish ON/OFF"로 변경하며 관리합니다.
	refs.centerAutoButton.Text = "AutoFish OFF"

	refs.centerAutoTitleText = makeOutlinedText(
		refs.centerAutoButton,
		"AutoFishTitleText",
		UDim2.fromScale(0.5, 0.35),
		UDim2.fromScale(0.84, 0.27),
		"AutoFish",
		MAIN_TEXT_COLOR,
		MAIN_TEXT_STROKE,
		18,
		42
	)

	refs.centerAutoStateText = makeOutlinedText(
		refs.centerAutoButton,
		"AutoFishStateText",
		UDim2.fromScale(0.5, 0.64),
		UDim2.fromScale(0.58, 0.32),
		"OFF",
		AUTOFISH_OFF_COLOR,
		AUTOFISH_OFF_STROKE,
		28,
		58
	)

	-- FishingClient에서 centerAutoGradient를 변경하는 기존 코드와 호환되도록 남겨둡니다.
	refs.centerAutoGradient = Instance.new("UIGradient")
	refs.centerAutoGradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	refs.centerAutoGradient.Transparency = NumberSequence.new(1)
	refs.centerAutoGradient.Parent = refs.centerAutoButton

	local function setAutoFishVisual(isOn)
		if isOn then
			refs.centerAutoStateText.Text = "ON"
			refs.centerAutoStateText.TextColor3 = AUTOFISH_ON_COLOR
			refs.centerAutoStateText.TextStrokeColor3 = AUTOFISH_ON_STROKE
			local outline = refs.centerAutoStateText:FindFirstChild("TextOutline")
			if outline and outline:IsA("UIStroke") then
				outline.Color = AUTOFISH_ON_STROKE
			end
		else
			refs.centerAutoStateText.Text = "OFF"
			refs.centerAutoStateText.TextColor3 = AUTOFISH_OFF_COLOR
			refs.centerAutoStateText.TextStrokeColor3 = AUTOFISH_OFF_STROKE
			local outline = refs.centerAutoStateText:FindFirstChild("TextOutline")
			if outline and outline:IsA("UIStroke") then
				outline.Color = AUTOFISH_OFF_STROKE
			end
		end

		refs.centerAutoButton.TextTransparency = 1
		refs.centerAutoButton.BackgroundTransparency = 1
	end

	local function updateAutoFishVisualFromButtonText()
		local text = string.lower(tostring(refs.centerAutoButton.Text or ""))
		local containsOff = string.find(text, "off", 1, true) ~= nil
		local containsOn = string.find(text, "on", 1, true) ~= nil
		setAutoFishVisual(containsOn and not containsOff)
	end

	-- 외부 코드에서 직접 호출할 수도 있도록 제공
	refs.setAutoFishVisual = setAutoFishVisual

	-- 기존 AutoFish 기능이 Text를 바꾸면 시각 상태도 자동으로 ON/OFF 변경됩니다.
	refs.centerAutoButton:GetPropertyChangedSignal("Text"):Connect(updateAutoFishVisualFromButtonText)
	updateAutoFishVisualFromButtonText()

	-- Tap 버튼
	refs.centerCastButton, refs.centerCastImage, refs.centerCastPressScale = makeImageButton(
		refs.centerControls,
		"TapButton",
		TAP_BUTTON_POSITION,
		TAP_BUTTON_SIZE,
		TAP_BUTTON_MIN_SIZE,
		TAP_BUTTON_MAX_SIZE
	)
	local function keepTapImageSlightlyTransparent(image)
		if not image:IsA("ImageLabel") and not image:IsA("ImageButton") then
			return
		end

		image.ImageTransparency = 0.2
		image:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
			if image.ImageTransparency ~= 0.2 then
				image.ImageTransparency = 0.2
			end
		end)
	end

	keepTapImageSlightlyTransparent(refs.centerCastImage)
	refs.centerCastButton.DescendantAdded:Connect(keepTapImageSlightlyTransparent)
	refs.centerCastButton.Text = "Tap"

	refs.centerCastStateText = makeOutlinedText(
		refs.centerCastButton,
		"TapText",
		UDim2.fromScale(0.5, 0.47),
		UDim2.fromScale(0.78, 0.54),
		"Tap",
		MAIN_TEXT_COLOR,
		MAIN_TEXT_STROKE,
		42,
		88
	)

	local function updateTapVisualFromButtonText()
		local text = tostring(refs.centerCastButton.Text or "")
		if text == "" then
			text = "Tap"
		end

		refs.centerCastStateText.Text = text
		refs.centerCastButton.TextTransparency = 1
		refs.centerCastButton.BackgroundTransparency = 1
	end

	refs.centerCastButton:GetPropertyChangedSignal("Text"):Connect(updateTapVisualFromButtonText)
	updateTapVisualFromButtonText()

	refs.centerBaitText = makeText(refs.centerControls, "Bait: Basic Bait (Unlimited)", 13, Color3.fromRGB(210, 230, 255), true)
	refs.centerBaitText.AnchorPoint = Vector2.new(0.5, 0.5)
	refs.centerBaitText.Position = UDim2.fromScale(0.55, 0.10)
	refs.centerBaitText.Size = UDim2.new(0.34, 0, 0, 20)
	refs.centerBaitText.TextXAlignment = Enum.TextXAlignment.Center
	refs.centerBaitText.ZIndex = 1001
	refs.centerBaitText.Visible = false
end

return BottomControlsHud
