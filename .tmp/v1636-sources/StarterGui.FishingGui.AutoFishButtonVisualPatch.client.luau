-- AutoFishButtonVisualPatch_V5_CodeVisual
-- LocalScript로 사용하세요.
--
-- 위치:
-- StarterGui > FishingGui > AutoFishButtonVisualPatch
--
-- 기존 AutoFishButtonVisualPatch는 삭제하거나 비활성화하세요.
-- 이 버전은 이미지 Asset ID를 사용하지 않습니다.

task.spawn(function()
	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local fishingGui =
		script:FindFirstAncestorWhichIsA("ScreenGui")
		or playerGui:WaitForChild("FishingGui")

	--------------------------------------------------
	-- 버튼 크기 설정
	--------------------------------------------------

	local VISUAL_SIZE = 104
	local PRESSED_SCALE = 0.90

	--------------------------------------------------
	-- TAP 버튼 기준 AUTO 버튼 위치
	--------------------------------------------------

	-- 숫자가 커지면 AUTO 버튼이 오른쪽으로 이동
	local TAP_RIGHT_SHIFT_RATIO = 0.38

	-- 숫자가 커지면 TAP 버튼과 AUTO 버튼 사이가 멀어짐
	local TAP_VERTICAL_GAP_RATIO = 0.08

	local MIN_VERTICAL_GAP = 8
	local MAX_VERTICAL_GAP = 20

	local RESIZE_BUTTON_HITBOX = true

	--------------------------------------------------
	-- 반투명도
	--
	-- Roblox에서는:
	-- 0 = 불투명
	-- 1 = 완전 투명
	--------------------------------------------------

	-- 원 내부 반투명도
	local CIRCLE_TRANSPARENCY = 0.28

	-- 버튼이 비활성화됐을 때 추가 투명도
	local DISABLED_TRANSPARENCY = 0.55

	--------------------------------------------------
	-- OFF 디자인
	--------------------------------------------------

	local OFF_BACKGROUND = Color3.fromRGB(226, 65, 72)
	local OFF_OUTER_STROKE = Color3.fromRGB(255, 104, 108)
	local OFF_INNER_STROKE = Color3.fromRGB(135, 17, 25)

	--------------------------------------------------
	-- ON 디자인
	--------------------------------------------------

	local ON_BACKGROUND = Color3.fromRGB(101, 205, 74)
	local ON_OUTER_STROKE = Color3.fromRGB(151, 255, 105)
	local ON_INNER_STROKE = Color3.fromRGB(35, 112, 22)

	--------------------------------------------------
	-- 내부 설정
	--------------------------------------------------

	local patchedButtons = {}
	local cachedTapButton = nil

	--------------------------------------------------
	-- 공통 함수
	--------------------------------------------------

	local function normalize(value)
		return string.lower(tostring(value or ""))
	end

	local function readButtonStateText(button)
		local combined = ""

		if button:IsA("TextButton") then
			combined ..= " " .. normalize(button.Text)
		end

		for _, descendant in ipairs(button:GetDescendants()) do
			if descendant:IsA("TextLabel")
				or descendant:IsA("TextButton")
			then
				combined ..= " " .. normalize(descendant.Text)
			end
		end

		return combined
	end

	--------------------------------------------------
	-- AutoFish 버튼 검색
	--------------------------------------------------

	local function isAutoFishButton(instance)
		if not instance:IsA("GuiButton") then
			return false
		end

		local name = normalize(instance.Name)
		local stateText = readButtonStateText(instance)

		return name:find("autofish", 1, true) ~= nil
			or name:find("centerauto", 1, true) ~= nil
			or stateText:find("autofish", 1, true) ~= nil
	end

	--------------------------------------------------
	-- TAP 버튼 검색
	--------------------------------------------------

	local function isTapButton(instance)
		if not instance:IsA("GuiButton") then
			return false
		end

		local name = normalize(instance.Name)
		local text = readButtonStateText(instance)
		local compactText = text:gsub("%s+", "")

		if name == "tap"
			or name == "tapbutton"
			or name:find("tapbutton", 1, true) ~= nil
			or name:find("mobiletap", 1, true) ~= nil
		then
			return true
		end

		return compactText == "tap"
	end

	local function findTapButton()
		if cachedTapButton
			and cachedTapButton.Parent
			and cachedTapButton:IsDescendantOf(fishingGui)
		then
			return cachedTapButton
		end

		cachedTapButton = nil

		local hiddenCandidate = nil

		for _, descendant in ipairs(fishingGui:GetDescendants()) do
			if isTapButton(descendant) then
				if descendant.Visible
					and descendant.AbsoluteSize.X > 0
					and descendant.AbsoluteSize.Y > 0
				then
					cachedTapButton = descendant
					return descendant
				end

				hiddenCandidate = hiddenCandidate or descendant
			end
		end

		cachedTapButton = hiddenCandidate
		return hiddenCandidate
	end

	--------------------------------------------------
	-- AUTO 버튼 위치 조정
	--------------------------------------------------

	local function positionAutoButton(button)
		if not button.Parent then
			return
		end

		local tapButton = findTapButton()

		if not tapButton
			or not tapButton.Parent
			or tapButton == button
		then
			return
		end

		local tapSize = tapButton.AbsoluteSize
		local tapPosition = tapButton.AbsolutePosition

		if tapSize.X <= 0 or tapSize.Y <= 0 then
			return
		end

		if RESIZE_BUTTON_HITBOX then
			button.Size = UDim2.fromOffset(
				VISUAL_SIZE,
				VISUAL_SIZE
			)
		end

		local autoSize = button.AbsoluteSize

		if autoSize.X <= 0 or autoSize.Y <= 0 then
			autoSize = Vector2.new(
				VISUAL_SIZE,
				VISUAL_SIZE
			)
		end

		local verticalGap = math.clamp(
			tapSize.Y * TAP_VERTICAL_GAP_RATIO,
			MIN_VERTICAL_GAP,
			MAX_VERTICAL_GAP
		)

		local targetCenterX =
			tapPosition.X
			+ tapSize.X * 0.5
			+ tapSize.X * TAP_RIGHT_SHIFT_RATIO

		local targetBottomY =
			tapPosition.Y
		- verticalGap

		local targetTopLeft = Vector2.new(
			targetCenterX - autoSize.X * 0.5,
			targetBottomY - autoSize.Y
		)

		local currentTopLeft = button.AbsolutePosition
		local difference = targetTopLeft - currentTopLeft

		if math.abs(difference.X) < 0.5
			and math.abs(difference.Y) < 0.5
		then
			return
		end

		local currentPosition = button.Position

		button.Position = UDim2.new(
			currentPosition.X.Scale,
			currentPosition.X.Offset + math.round(difference.X),
			currentPosition.Y.Scale,
			currentPosition.Y.Offset + math.round(difference.Y)
		)

		button.ZIndex = math.max(
			button.ZIndex,
			tapButton.ZIndex + 10
		)
	end

	--------------------------------------------------
	-- AutoFish ON/OFF 상태 확인
	--------------------------------------------------

	local function isAutoFishEnabled(button)
		local stateText = readButtonStateText(button)

		if button:GetAttribute("AutoFishEnabled") == true then
			return true
		end

		if button:GetAttribute("Enabled") == true then
			return true
		end

		if stateText:find("autofish on", 1, true) ~= nil then
			return true
		end

		if stateText:match("%f[%a]on%f[%A]") ~= nil then
			return true
		end

		return false
	end

	--------------------------------------------------
	-- AutoFish 디자인 적용
	--------------------------------------------------

	local function patchButton(button)
		if patchedButtons[button] or not button.Parent then
			return
		end

		patchedButtons[button] = true

		local existing =
			button:FindFirstChild("ModernAutoFishVisual")

		if existing then
			existing:Destroy()
		end

		if RESIZE_BUTTON_HITBOX then
			button.Size = UDim2.fromOffset(
				VISUAL_SIZE,
				VISUAL_SIZE
			)
		end

		local visual
		local circle
		local outerStroke
		local innerRing
		local innerStroke
		local autoText
		local pressScale
		local activeTween

		--------------------------------------------------
		-- 기존 AutoFish 디자인 숨기기
		--------------------------------------------------

		local function hideOriginal()
			if not button.Parent then
				return
			end

			button.BackgroundTransparency = 1
			button.BorderSizePixel = 0
			button.ClipsDescendants = false

			if button:IsA("TextButton") then
				button.TextTransparency = 1
				button.TextStrokeTransparency = 1
			end

			if button:IsA("ImageButton") then
				button.ImageTransparency = 1
			end

			for _, child in ipairs(button:GetChildren()) do
				if child ~= visual
					and child.Name ~= "ModernAutoFishVisual"
				then
					if child:IsA("UIStroke")
						or child:IsA("UIGradient")
					then
						child.Enabled = false
					elseif child:IsA("GuiObject") then
						child.Visible = false
					end
				end
			end
		end

		--------------------------------------------------
		-- 전체 비주얼 컨테이너
		--------------------------------------------------

		visual = Instance.new("Frame")
		visual.Name = "ModernAutoFishVisual"
		visual.AnchorPoint = Vector2.new(0.5, 0.5)
		visual.Position = UDim2.fromScale(0.5, 0.5)
		visual.Size = UDim2.fromOffset(
			VISUAL_SIZE,
			VISUAL_SIZE
		)
		visual.BackgroundTransparency = 1
		visual.BorderSizePixel = 0
		visual.Active = false
		visual.ZIndex = button.ZIndex + 50
		visual.Parent = button

		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 1
		aspect.Parent = visual

		pressScale = Instance.new("UIScale")
		pressScale.Name = "PressScale"
		pressScale.Scale = 1
		pressScale.Parent = visual

		--------------------------------------------------
		-- 원형 배경
		--------------------------------------------------

		circle = Instance.new("Frame")
		circle.Name = "Circle"
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromScale(0.5, 0.5)
		circle.Size = UDim2.fromScale(0.94, 0.94)
		circle.BackgroundColor3 = OFF_BACKGROUND
		circle.BackgroundTransparency = CIRCLE_TRANSPARENCY
		circle.BorderSizePixel = 0
		circle.ZIndex = visual.ZIndex
		circle.Parent = visual

		local circleCorner = Instance.new("UICorner")
		circleCorner.CornerRadius = UDim.new(1, 0)
		circleCorner.Parent = circle

		--------------------------------------------------
		-- 바깥쪽 두꺼운 테두리
		--------------------------------------------------

		outerStroke = Instance.new("UIStroke")
		outerStroke.Name = "OuterStroke"
		outerStroke.ApplyStrokeMode =
			Enum.ApplyStrokeMode.Border
		outerStroke.Color = OFF_OUTER_STROKE
		outerStroke.Thickness = 6
		outerStroke.Transparency = 0.05
		outerStroke.LineJoinMode = Enum.LineJoinMode.Round
		outerStroke.Parent = circle

		--------------------------------------------------
		-- 안쪽 원형 테두리
		--------------------------------------------------

		innerRing = Instance.new("Frame")
		innerRing.Name = "InnerRing"
		innerRing.AnchorPoint = Vector2.new(0.5, 0.5)
		innerRing.Position = UDim2.fromScale(0.5, 0.5)
		innerRing.Size = UDim2.fromScale(0.84, 0.84)
		innerRing.BackgroundTransparency = 1
		innerRing.BorderSizePixel = 0
		innerRing.ZIndex = circle.ZIndex + 1
		innerRing.Parent = circle

		local innerCorner = Instance.new("UICorner")
		innerCorner.CornerRadius = UDim.new(1, 0)
		innerCorner.Parent = innerRing

		innerStroke = Instance.new("UIStroke")
		innerStroke.Name = "InnerStroke"
		innerStroke.ApplyStrokeMode =
			Enum.ApplyStrokeMode.Border
		innerStroke.Color = OFF_INNER_STROKE
		innerStroke.Thickness = 3
		innerStroke.Transparency = 0.05
		innerStroke.LineJoinMode = Enum.LineJoinMode.Round
		innerStroke.Parent = innerRing

		--------------------------------------------------
		-- AUTO 텍스트
		--------------------------------------------------

		autoText = Instance.new("TextLabel")
		autoText.Name = "AutoText"
		autoText.AnchorPoint = Vector2.new(0.5, 0.5)
		autoText.Position = UDim2.fromScale(0.5, 0.5)
		autoText.Size = UDim2.fromScale(0.82, 0.38)
		autoText.BackgroundTransparency = 1
		autoText.BorderSizePixel = 0
		autoText.Text = "AUTO"
		autoText.TextColor3 = Color3.fromRGB(255, 255, 255)
		autoText.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
		autoText.TextStrokeTransparency = 0
		autoText.Font = Enum.Font.GothamBlack
		autoText.TextScaled = true
		autoText.TextXAlignment = Enum.TextXAlignment.Center
		autoText.TextYAlignment = Enum.TextYAlignment.Center
		autoText.ZIndex = circle.ZIndex + 3
		autoText.Parent = circle

		local textConstraint =
			Instance.new("UITextSizeConstraint")

		textConstraint.MinTextSize = 18
		textConstraint.MaxTextSize = 24
		textConstraint.Parent = autoText

		--------------------------------------------------
		-- 눌림 애니메이션
		--------------------------------------------------

		local function setPressed(pressed)
			if activeTween then
				activeTween:Cancel()
			end

			activeTween = TweenService:Create(
				pressScale,
				TweenInfo.new(
					0.08,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),
				{
					Scale =
						pressed and PRESSED_SCALE or 1,
				}
			)

			activeTween:Play()
		end

		--------------------------------------------------
		-- ON/OFF 디자인 변경
		--------------------------------------------------

		local function updateVisual()
			if not button.Parent
				or not visual.Parent
			then
				return
			end

			local enabled = isAutoFishEnabled(button)

			if enabled then
				circle.BackgroundColor3 = ON_BACKGROUND
				outerStroke.Color = ON_OUTER_STROKE
				innerStroke.Color = ON_INNER_STROKE
			else
				circle.BackgroundColor3 = OFF_BACKGROUND
				outerStroke.Color = OFF_OUTER_STROKE
				innerStroke.Color = OFF_INNER_STROKE
			end

			local available =
				button.Visible and button.Active

			if available then
				circle.BackgroundTransparency =
					CIRCLE_TRANSPARENCY

				outerStroke.Transparency = 0.05
				innerStroke.Transparency = 0.05
				autoText.TextTransparency = 0
				autoText.TextStrokeTransparency = 0
			else
				circle.BackgroundTransparency =
					DISABLED_TRANSPARENCY

				outerStroke.Transparency = 0.40
				innerStroke.Transparency = 0.40
				autoText.TextTransparency = 0.30
				autoText.TextStrokeTransparency = 0.45
			end
		end

		--------------------------------------------------
		-- 클릭 및 터치 입력
		--------------------------------------------------

		button.InputBegan:Connect(function(input)
			if input.UserInputType
				== Enum.UserInputType.MouseButton1
				or input.UserInputType
				== Enum.UserInputType.Touch
			then
				setPressed(true)
			end
		end)

		button.InputEnded:Connect(function(input)
			if input.UserInputType
				== Enum.UserInputType.MouseButton1
				or input.UserInputType
				== Enum.UserInputType.Touch
			then
				setPressed(false)
			end
		end)

		button.MouseLeave:Connect(function()
			setPressed(false)
		end)

		--------------------------------------------------
		-- 상태 변화 감지
		--------------------------------------------------

		if button:IsA("TextButton") then
			button:GetPropertyChangedSignal("Text")
				:Connect(updateVisual)
		end

		button:GetPropertyChangedSignal("Visible")
			:Connect(function()
				updateVisual()
				task.defer(positionAutoButton, button)
			end)

		button:GetPropertyChangedSignal("Active")
			:Connect(updateVisual)

		button:GetAttributeChangedSignal(
			"AutoFishEnabled"
		):Connect(updateVisual)

		button:GetAttributeChangedSignal(
			"Enabled"
		):Connect(updateVisual)

		for _, descendant in ipairs(button:GetDescendants()) do
			if descendant:IsA("TextLabel")
				or descendant:IsA("TextButton")
			then
				descendant:GetPropertyChangedSignal("Text")
					:Connect(updateVisual)
			end
		end

		button.DescendantAdded:Connect(function(descendant)
			if descendant == visual
				or descendant:IsDescendantOf(visual)
			then
				return
			end

			if descendant:IsA("TextLabel")
				or descendant:IsA("TextButton")
			then
				descendant:GetPropertyChangedSignal("Text")
					:Connect(updateVisual)
			end

			task.defer(hideOriginal)
			task.defer(updateVisual)
			task.defer(positionAutoButton, button)
		end)

		--------------------------------------------------
		-- 최초 실행
		--------------------------------------------------

		hideOriginal()
		updateVisual()
		task.defer(positionAutoButton, button)

		--------------------------------------------------
		-- 다른 코드가 디자인을 복원하는 것을 방지
		--------------------------------------------------

		task.spawn(function()
			while button.Parent do
				hideOriginal()
				updateVisual()
				positionAutoButton(button)

				task.wait(0.15)
			end

			patchedButtons[button] = nil
		end)
	end

	--------------------------------------------------
	-- AutoFish 버튼 검색
	--------------------------------------------------

	local function scanForButtons()
		for _, descendant in ipairs(
			fishingGui:GetDescendants()
			) do
			if isAutoFishButton(descendant) then
				patchButton(descendant)
			end
		end
	end

	fishingGui.DescendantAdded:Connect(function(descendant)
		if isTapButton(descendant) then
			cachedTapButton = descendant

			for button in pairs(patchedButtons) do
				task.defer(positionAutoButton, button)
			end
		end

		if isAutoFishButton(descendant) then
			task.defer(patchButton, descendant)
		end
	end)

	fishingGui.DescendantRemoving:Connect(function(descendant)
		if descendant == cachedTapButton then
			cachedTapButton = nil
		end
	end)

	scanForButtons()

	--------------------------------------------------
	-- 버튼이 늦게 생성되는 경우 재검색
	--------------------------------------------------

	task.spawn(function()
		local warnedAuto = false
		local warnedTap = false

		while fishingGui.Parent do
			scanForButtons()

			if not warnedAuto
				and next(patchedButtons) == nil
			then
				warn(
					"[AutoFishButtonVisualPatch] "
						.. "AutoFish button was not found. "
						.. "Place this LocalScript under "
						.. "StarterGui > FishingGui."
				)

				warnedAuto = true
			end

			if not warnedTap
				and not findTapButton()
			then
				warn(
					"[AutoFishButtonVisualPatch] "
						.. "TAP button was not found. "
						.. "Its name should include TapButton "
						.. "or its text should be TAP."
				)

				warnedTap = true
			end

			task.wait(1)
		end
	end)
end)
