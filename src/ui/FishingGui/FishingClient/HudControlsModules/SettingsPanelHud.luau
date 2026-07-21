local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local SettingsPanelHud = {}

local BASE_WIDTH = 1448
local BASE_HEIGHT = 1086
local SETTINGS_SIZE_MULTIPLIER = 0.85
local MOBILE_SETTINGS_SIZE_MULTIPLIER = 1.05

local MIN_SPEED = 8
local MAX_SPEED = 24
local DEFAULT_SPEED = 16

local TRACK_X = 0
local TRACK_Y = 22
local TRACK_WIDTH = 1088
local FILL_X = 4
local FILL_Y = 26
local FILL_HEIGHT = 30
local FILL_CAP_WIDTH = 15
local KNOB_SIZE = 76
local KNOB_HALF = KNOB_SIZE / 2

local TOGGLE_MOVE_TWEEN = TweenInfo.new(
	0.22,
	Enum.EasingStyle.Quint,
	Enum.EasingDirection.Out
)
local TOGGLE_FADE_TWEEN = TweenInfo.new(
	0.14,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)
local PRESS_TWEEN = TweenInfo.new(
	0.07,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)
local RELEASE_TWEEN = TweenInfo.new(
	0.16,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.Out
)

local function requiredChild(parent, name, className)
	local child = parent:FindFirstChild(name)
	assert(child, string.format(
		"[SettingsPanelHud] Missing authored node %s.%s",
		parent:GetFullName(),
		name
	))
	assert(child:IsA(className), string.format(
		"[SettingsPanelHud] Authored node %s must be %s, got %s",
		child:GetFullName(),
		className,
		child.ClassName
	))
	return child
end

local function assertImage(container)
	requiredChild(container, "Image", "ImageLabel")
end

function SettingsPanelHud.create(deps, refs)
	assert(deps.authoredUiV2, "[SettingsPanelHud] AuthoredUiV2 is required")
	assert(deps.findAuthoredHost, "[SettingsPanelHud] Authored host lookup is required")

	local overlay = deps.findAuthoredHost("SettingsOverlay", "Frame")
	assert(overlay, "[SettingsPanelHud] SettingsOverlay is missing from FishingGui")

	-- Keep the saved overlay with the other modal surfaces after FishingGui is
	-- cloned. Its complete visual hierarchy remains authored in StarterGui.
	if deps.root and deps.root:IsA("GuiObject") and overlay.Parent ~= deps.root then
		overlay.Parent = deps.root
	end

	local canvas = requiredChild(overlay, "SettingsCanvas", "Frame")
	local responsiveScale = requiredChild(canvas, "UIScale", "UIScale")
	local closeButton = requiredChild(canvas, "CloseButton", "ImageButton")

	-- Validate the fixed art that the controller never modifies.
	assertImage(requiredChild(canvas, "BackboneTop", "Frame"))
	assertImage(requiredChild(canvas, "BackboneMiddle", "Frame"))
	assertImage(requiredChild(canvas, "BackboneBottom", "Frame"))
	requiredChild(canvas, "SettingsIcon", "ImageLabel")
	requiredChild(canvas, "Title", "TextLabel")

	local function bindAudioRow(name)
		local row = requiredChild(canvas, name .. "Row", "ImageLabel")
		requiredChild(row, name .. "Icon", "ImageLabel")
		requiredChild(row, name .. "Prefix", "TextLabel")
		local status = requiredChild(row, name .. "Status", "TextLabel")
		local toggle = requiredChild(row, name .. "Toggle", "TextButton")
		local pressScale = requiredChild(toggle, "PressScale", "UIScale")
		local onBackground = requiredChild(toggle, "OnBackground", "ImageLabel")
		local offBackground = requiredChild(toggle, "OffBackground", "ImageLabel")
		local toggleText = requiredChild(toggle, name .. "ToggleText", "TextLabel")
		local knob = requiredChild(toggle, name .. "Knob", "Frame")
		assertImage(knob)
		return {
			status = status,
			toggle = toggle,
			pressScale = pressScale,
			onBackground = onBackground,
			offBackground = offBackground,
			toggleText = toggleText,
			knob = knob,
		}
	end

	local music = bindAudioRow("Music")
	local sfx = bindAudioRow("Sfx")

	local speedRow = requiredChild(canvas, "MoveSpeedRow", "ImageLabel")
	requiredChild(speedRow, "MoveSpeedPrefix", "TextLabel")
	local speedValue = requiredChild(speedRow, "MoveSpeedValue", "TextLabel")
	local sliderArea = requiredChild(speedRow, "SliderArea", "Frame")
	assertImage(requiredChild(sliderArea, "TrackLeftCap", "Frame"))
	assertImage(requiredChild(sliderArea, "TrackMiddle", "Frame"))
	assertImage(requiredChild(sliderArea, "TrackRightCap", "Frame"))
	local fillLeftClip = requiredChild(sliderArea, "FillLeftCap", "Frame")
	assertImage(fillLeftClip)
	local fillMiddleClip = requiredChild(sliderArea, "FillMiddle", "Frame")
	local fillMiddleImage = requiredChild(fillMiddleClip, "Image", "ImageLabel")
	local sliderKnob = requiredChild(sliderArea, "SliderKnob", "TextButton")
	assertImage(sliderKnob)

	local aquariumRow = requiredChild(canvas, "AquariumTeleportRow", "ImageLabel")
	requiredChild(aquariumRow, "FishBowlIcon", "ImageLabel")
	requiredChild(aquariumRow, "AquariumTitle", "TextLabel")
	local teleportButton = requiredChild(aquariumRow, "TeleportButton", "ImageButton")
	local teleportScale = requiredChild(teleportButton, "PressScale", "UIScale")

	local player = Players.LocalPlayer
	local fishingRemotes = ReplicatedStorage:WaitForChild("FishingRemotes")
	local teleportRemote = fishingRemotes:WaitForChild("TeleportTo")
	local movementRemotes = ReplicatedStorage:FindFirstChild("Remotes")
	local moveSpeedRemote = movementRemotes and movementRemotes:FindFirstChild("SetMoveSpeed")

	local function updateScale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local mobileLayout = UserInputService.TouchEnabled
			and math.min(viewport.X, viewport.Y) <= 600
		local fitScale = math.min(
			viewport.X * 0.74 / BASE_WIDTH,
			viewport.Y * 0.74 / BASE_HEIGHT
		)
		responsiveScale.Scale = math.clamp(
			fitScale * (mobileLayout
				and MOBILE_SETTINGS_SIZE_MULTIPLIER
				or SETTINGS_SIZE_MULTIPLIER),
			0.10,
			mobileLayout and 0.90 or 0.75
		)

		local topLeftInset, bottomRightInset = GuiService:GetGuiInset()
		canvas.Position = UDim2.new(
			0.5,
			math.round((bottomRightInset.X - topLeftInset.X) * 0.5),
			0.5,
			math.round((bottomRightInset.Y - topLeftInset.Y) * 0.5)
		)
	end

	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()

	local activeTweens = setmetatable({}, { __mode = "k" })

	local function playTween(instance, tweenInfo, goal)
		local currentTween = activeTweens[instance]
		if currentTween then
			currentTween:Cancel()
		end

		local tween = TweenService:Create(instance, tweenInfo, goal)
		activeTweens[instance] = tween
		tween.Completed:Connect(function()
			if activeTweens[instance] == tween then
				activeTweens[instance] = nil
			end
		end)
		tween:Play()
		return tween
	end

	local closePosition = UDim2.fromOffset(1270, 60)
	local closeSize = UDim2.fromOffset(100, 100)
	local closePressed = false

	local function resetCloseButton(animated)
		if not animated then
			local currentTween = activeTweens[closeButton]
			if currentTween then
				currentTween:Cancel()
				activeTweens[closeButton] = nil
			end
			closeButton.Position = closePosition
			closeButton.Size = closeSize
			closeButton.Rotation = 0
			closeButton.ImageColor3 = Color3.new(1, 1, 1)
			closeButton.ImageTransparency = 0
			return
		end

		playTween(closeButton, PRESS_TWEEN, {
			Position = closePosition,
			Size = closeSize,
			Rotation = 0,
			ImageColor3 = Color3.new(1, 1, 1),
			ImageTransparency = 0,
		})
	end

	local function setClosePressed(pressed)
		if closePressed == pressed then
			return
		end
		closePressed = pressed
		playTween(closeButton, PRESS_TWEEN, {
			Position = UDim2.new(
				closePosition.X.Scale,
				closePosition.X.Offset + (pressed and 3 or 0),
				closePosition.Y.Scale,
				closePosition.Y.Offset + (pressed and 3 or 0)
			),
			Size = UDim2.new(
				closeSize.X.Scale,
				closeSize.X.Offset - (pressed and 6 or 0),
				closeSize.Y.Scale,
				closeSize.Y.Offset - (pressed and 6 or 0)
			),
			Rotation = 0,
			ImageColor3 = Color3.new(1, 1, 1),
			ImageTransparency = pressed and 0.16 or 0,
		})
	end

	closeButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			setClosePressed(true)
		end
	end)
	closeButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			setClosePressed(false)
		end
	end)
	closeButton.MouseLeave:Connect(function()
		setClosePressed(false)
	end)

	local musicEnabled = true
	local sfxEnabled = true

	local function isMusic(sound)
		local name = string.lower(sound.Name)
		return string.find(name, "music")
			or string.find(name, "theme")
			or string.find(name, "bgm")
	end

	local function originalVolume(sound)
		local saved = sound:GetAttribute("FishyFishOriginalVolume")
		if type(saved) ~= "number" then
			saved = sound.Volume
			sound:SetAttribute("FishyFishOriginalVolume", saved)
		end
		return saved
	end

	local function applyAudio()
		SoundService:SetAttribute("FishyFishMusicEnabled", musicEnabled)
		SoundService:SetAttribute("FishyFishSFXEnabled", sfxEnabled)
		for _, object in ipairs(SoundService:GetDescendants()) do
			if object:IsA("Sound") then
				local volume = originalVolume(object)
				if isMusic(object) then
					object.Volume = musicEnabled and volume or 0
				else
					object.Volume = sfxEnabled and volume or 0
				end
			end
		end
	end

	local function setLabelState(label, textValue, colorValue, animate)
		local serial = (label:GetAttribute("SettingsAnimationSerial") or 0) + 1
		label:SetAttribute("SettingsAnimationSerial", serial)

		if not animate then
			label.Text = textValue
			label.TextColor3 = colorValue
			label.TextTransparency = 0
			label.TextStrokeTransparency = 0.25
			return
		end

		playTween(label, PRESS_TWEEN, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		task.delay(0.065, function()
			if label:GetAttribute("SettingsAnimationSerial") ~= serial then
				return
			end
			label.Text = textValue
			label.TextColor3 = colorValue
			playTween(label, TOGGLE_FADE_TWEEN, {
				TextTransparency = 0,
				TextStrokeTransparency = 0.25,
			})
		end)
	end

	local function refreshSingleToggle(toggleRefs, enabled, animate)
		local knobPosition
		toggleRefs.toggleText.AnchorPoint = Vector2.new(0, 0)
		toggleRefs.toggleText.TextTruncate = Enum.TextTruncate.None

		if enabled then
			knobPosition = UDim2.new(1, -78, 0.5, -39)
			toggleRefs.toggleText.Position = UDim2.fromOffset(22, 0)
			toggleRefs.toggleText.Size = UDim2.fromOffset(108, 96)
			toggleRefs.toggleText.TextXAlignment = Enum.TextXAlignment.Left
		else
			knobPosition = UDim2.new(0, 2, 0.5, -39)
			toggleRefs.toggleText.Position = UDim2.fromOffset(0, 0)
			toggleRefs.toggleText.Size = UDim2.new(1, -12, 1, 0)
			toggleRefs.toggleText.TextXAlignment = Enum.TextXAlignment.Right
		end

		if animate then
			playTween(toggleRefs.onBackground, TOGGLE_FADE_TWEEN, {
				ImageTransparency = enabled and 0 or 1,
			})
			playTween(toggleRefs.offBackground, TOGGLE_FADE_TWEEN, {
				ImageTransparency = enabled and 1 or 0,
			})
			playTween(toggleRefs.knob, TOGGLE_MOVE_TWEEN, {
				Position = knobPosition,
			})
		else
			toggleRefs.onBackground.ImageTransparency = enabled and 0 or 1
			toggleRefs.offBackground.ImageTransparency = enabled and 1 or 0
			toggleRefs.knob.Position = knobPosition
		end

		setLabelState(
			toggleRefs.toggleText,
			enabled and "ON" or "OFF",
			Color3.new(1, 1, 1),
			animate
		)
		setLabelState(
			toggleRefs.status,
			enabled and "ON" or "OFF",
			enabled and Color3.fromRGB(65, 215, 255) or Color3.fromRGB(255, 75, 75),
			animate
		)
	end

	local function refreshToggle(toggleRefs, isMusicRow, animate)
		refreshSingleToggle(
			toggleRefs,
			isMusicRow and musicEnabled or sfxEnabled,
			animate
		)
	end

	local function bindToggleInput(toggleRefs, isMusicRow)
		toggleRefs.toggle.MouseButton1Down:Connect(function()
			playTween(toggleRefs.pressScale, PRESS_TWEEN, { Scale = 0.96 })
		end)
		toggleRefs.toggle.MouseButton1Up:Connect(function()
			playTween(toggleRefs.pressScale, RELEASE_TWEEN, { Scale = 1 })
		end)
		toggleRefs.toggle.MouseLeave:Connect(function()
			playTween(toggleRefs.pressScale, RELEASE_TWEEN, { Scale = 1 })
		end)
		toggleRefs.toggle.Activated:Connect(function()
			if isMusicRow then
				musicEnabled = not musicEnabled
			else
				sfxEnabled = not sfxEnabled
			end

			playTween(toggleRefs.pressScale, PRESS_TWEEN, { Scale = 0.94 })
			task.delay(0.07, function()
				playTween(toggleRefs.pressScale, RELEASE_TWEEN, { Scale = 1 })
			end)
			applyAudio()
			refreshToggle(toggleRefs, isMusicRow, true)
		end)
	end

	bindToggleInput(music, true)
	bindToggleInput(sfx, false)

	local currentSpeed = DEFAULT_SPEED
	local dragging = false
	local activeTouch = nil
	local fillSourceSize = Vector2.new(1274, 155)

	local function renderSpeed(speed)
		currentSpeed = math.clamp(
			math.round(tonumber(speed) or DEFAULT_SPEED),
			MIN_SPEED,
			MAX_SPEED
		)
		local alpha = (currentSpeed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)
		local usableKnobWidth = TRACK_WIDTH - KNOB_SIZE
		local knobX = TRACK_X + math.floor(usableKnobWidth * alpha + 0.5)
		local knobCenterX = knobX + KNOB_HALF
		local visibleFillWidth = math.max(
			0,
			math.floor(knobCenterX - FILL_X + 0.5)
		)
		local middleWidth = math.max(0, visibleFillWidth - FILL_CAP_WIDTH)

		fillLeftClip.Visible = visibleFillWidth > 0
		fillMiddleClip.Visible = middleWidth > 0
		fillMiddleClip.Size = UDim2.fromOffset(middleWidth, FILL_HEIGHT)

		if middleWidth > 0 then
			local fullImageWidth = middleWidth * fillSourceSize.X / 1118
			local fullImageHeight = FILL_HEIGHT * fillSourceSize.Y / 135
			fillMiddleImage.Position = UDim2.fromOffset(
				-(78 / fillSourceSize.X) * fullImageWidth,
				-(10 / fillSourceSize.Y) * fullImageHeight
			)
			fillMiddleImage.Size = UDim2.fromOffset(fullImageWidth, fullImageHeight)
		end

		sliderKnob.Position = UDim2.fromOffset(
			knobX,
			TRACK_Y + math.floor(38 / 2) - KNOB_HALF
		)
		speedValue.Text = tostring(currentSpeed)
	end

	local function updateFromX(x)
		local absoluteScale = responsiveScale.Scale
		local absoluteTrackStart = sliderArea.AbsolutePosition.X
			+ ((TRACK_X + KNOB_HALF) * absoluteScale)
		local absoluteUsableWidth = (TRACK_WIDTH - KNOB_SIZE) * absoluteScale
		if absoluteUsableWidth <= 0 then
			return
		end
		local alpha = math.clamp(
			(x - absoluteTrackStart) / absoluteUsableWidth,
			0,
			1
		)
		renderSpeed(MIN_SPEED + ((MAX_SPEED - MIN_SPEED) * alpha))
	end

	local function beginSlider(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		if input.UserInputType == Enum.UserInputType.Touch then
			activeTouch = input
		end
		updateFromX(input.Position.X)
	end

	sliderArea.InputBegan:Connect(beginSlider)
	sliderKnob.InputBegan:Connect(beginSlider)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			updateFromX(input.Position.X)
		elseif input.UserInputType == Enum.UserInputType.Touch and input == activeTouch then
			updateFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not dragging then
			return
		end
		local mouseEnd = input.UserInputType == Enum.UserInputType.MouseButton1
		local touchEnd = input.UserInputType == Enum.UserInputType.Touch and input == activeTouch
		if not mouseEnd and not touchEnd then
			return
		end

		dragging = false
		activeTouch = nil
		if moveSpeedRemote and moveSpeedRemote:IsA("RemoteEvent") then
			moveSpeedRemote:FireServer(currentSpeed)
		else
			warn("[SettingsPanelHud] SetMoveSpeed remote is unavailable; keeping the saved speed locally")
		end
	end)

	local teleportBusy = false
	local function releaseTeleportButton()
		playTween(teleportScale, RELEASE_TWEEN, { Scale = 1 })
	end

	teleportButton.MouseButton1Down:Connect(function()
		if not teleportBusy then
			playTween(teleportScale, PRESS_TWEEN, { Scale = 0.94 })
		end
	end)
	teleportButton.MouseButton1Up:Connect(releaseTeleportButton)
	teleportButton.MouseLeave:Connect(releaseTeleportButton)
	teleportButton.Activated:Connect(function()
		if teleportBusy then
			return
		end
		teleportBusy = true
		playTween(teleportScale, PRESS_TWEEN, { Scale = 0.91 })
		teleportRemote:FireServer({
			kind = "PlayerAquarium",
			userId = player.UserId,
		})
		task.delay(0.075, function()
			releaseTeleportButton()
			task.delay(0.08, function()
				refs.setSettingsVisible(false)
			end)
		end)
		task.delay(0.8, function()
			teleportBusy = false
		end)
	end)

	refs.setSettingsVisible = function(visible)
		overlay.Visible = visible == true
		if overlay.Visible then
			closePressed = false
			teleportBusy = false
			teleportScale.Scale = 1
			resetCloseButton(false)
			renderSpeed(player:GetAttribute("MoveSpeed") or DEFAULT_SPEED)
			refreshToggle(music, true, false)
			refreshToggle(sfx, false, false)
		end
	end

	closeButton.Activated:Connect(function()
		setClosePressed(false)
		refs.setSettingsVisible(false)
	end)

	SoundService.DescendantAdded:Connect(function(object)
		if object:IsA("Sound") then
			task.defer(applyAudio)
		end
	end)
	player:GetAttributeChangedSignal("MoveSpeed"):Connect(function()
		local value = player:GetAttribute("MoveSpeed")
		if value ~= nil then
			renderSpeed(value)
		end
	end)

	refreshToggle(music, true, false)
	refreshToggle(sfx, false, false)
	renderSpeed(player:GetAttribute("MoveSpeed") or DEFAULT_SPEED)
	overlay.Visible = false
end

return SettingsPanelHud
