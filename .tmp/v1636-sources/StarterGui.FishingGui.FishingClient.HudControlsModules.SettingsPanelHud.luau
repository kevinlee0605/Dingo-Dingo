local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local SettingsPanelHud = {}

local ASSETS = {
	Backbone = "rbxassetid://81766141914014",
	CloseButton = "rbxassetid://74437026548245",
	SettingsIcon = "rbxassetid://94678436497650",
	RowBackground = "rbxassetid://130386889052542",
	MusicIcon = "rbxassetid://70574718515061",
	SfxIcon = "rbxassetid://92653426073517",
	FishBowl = "rbxassetid://81878984079270",
	TeleportButton = "rbxassetid://107462888144853",
	ToggleOff = "rbxassetid://131550730293382",
	ToggleOn = "rbxassetid://110978225407848",
	SliderTrack = "rbxassetid://79604035889224",
	SliderFill = "rbxassetid://107077598572207",
	SliderKnob = "rbxassetid://75219052415065",
}

local BASE_WIDTH = 1448
local BASE_HEIGHT = 1086
local PANEL_HEIGHT = BASE_HEIGHT

local function makeImage(parent, name, image, position, size, zIndex, button)
	local obj = Instance.new(button and "ImageButton" or "ImageLabel")
	obj.Name = name
	obj.BackgroundTransparency = 1
	obj.Position = position
	obj.Size = size
	obj.Image = image
	obj.ScaleType = Enum.ScaleType.Fit
	obj.ZIndex = zIndex
	if button then
		obj.AutoButtonColor = false
	end
	obj.Parent = parent
	return obj
end

local function makeLabel(parent, name, text, position, size, textSize, color, align, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.25
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = zIndex
	label.Parent = parent
	return label
end

function SettingsPanelHud.create(deps, refs)
	local root = deps.root
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local fishingRemotes = ReplicatedStorage:WaitForChild("FishingRemotes")

	local moveSpeedRemote = remotes:WaitForChild("SetMoveSpeed")
	local teleportRemote = fishingRemotes:WaitForChild("TeleportTo")

	local MIN_SPEED, MAX_SPEED, DEFAULT_SPEED = 8, 24, 16
	local musicEnabled, sfxEnabled = true, true

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

	local overlay = Instance.new("Frame")
	overlay.Name = "SettingsOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.Visible = false
	overlay.Active = true
	overlay.ZIndex = 200
	overlay.Parent = root

	local canvas = Instance.new("Frame")
	canvas.Name = "SettingsCanvas"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.new(0.5, 0, 0.5, -60)
	canvas.Size = UDim2.fromOffset(BASE_WIDTH, PANEL_HEIGHT)
	canvas.BackgroundTransparency = 1
	canvas.ZIndex = 201
	canvas.Parent = overlay

	local scale = Instance.new("UIScale")
	scale.Parent = canvas

	local SETTINGS_SIZE_MULTIPLIER = 0.85

	local function updateScale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)

		local responsiveScale = math.min(
			viewport.X * 0.74 / BASE_WIDTH,
			viewport.Y * 0.74 / BASE_HEIGHT
		)

		scale.Scale = math.clamp(
			responsiveScale * SETTINGS_SIZE_MULTIPLIER,
			0.25,
			0.75
		)
	end

	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()

	-- Build the full-height Backbone from three mapped sections.
	-- With PANEL_HEIGHT equal to BASE_HEIGHT, every source section keeps
	-- its original proportions while still preserving the clean corner art.
	local function createBackboneSection(
		name,
		targetY,
		targetHeight,
		sourceY,
		sourceHeight
	)
		local clip = Instance.new("Frame")
		clip.Name = name
		clip.Position = UDim2.fromOffset(0, targetY)
		clip.Size = UDim2.fromOffset(BASE_WIDTH, targetHeight)
		clip.BackgroundTransparency = 1
		clip.BorderSizePixel = 0
		clip.ClipsDescendants = true
		clip.ZIndex = 201
		clip.Parent = canvas

		local fullImageHeight =
			targetHeight * BASE_HEIGHT / sourceHeight
		local imageY =
			-(sourceY / BASE_HEIGHT) * fullImageHeight

		local image = makeImage(
			clip,
			"Image",
			ASSETS.Backbone,
			UDim2.fromOffset(0, imageY),
			UDim2.fromOffset(BASE_WIDTH, fullImageHeight),
			201,
			false
		)
		image.ScaleType = Enum.ScaleType.Stretch
	end

	local TOP_SECTION_HEIGHT = 160
	local BOTTOM_SECTION_HEIGHT = 160
	local MIDDLE_TARGET_HEIGHT =
		PANEL_HEIGHT - TOP_SECTION_HEIGHT - BOTTOM_SECTION_HEIGHT

	-- Original source image is 1448 x 1086.
	-- Preserve y=0..160 and y=926..1086 exactly.
	-- Compress only y=160..926 into the remaining middle height.
	createBackboneSection(
		"BackboneTop",
		0,
		TOP_SECTION_HEIGHT,
		0,
		160
	)

	createBackboneSection(
		"BackboneMiddle",
		TOP_SECTION_HEIGHT,
		MIDDLE_TARGET_HEIGHT,
		160,
		766
	)

	createBackboneSection(
		"BackboneBottom",
		PANEL_HEIGHT - BOTTOM_SECTION_HEIGHT,
		BOTTOM_SECTION_HEIGHT,
		926,
		160
	)

	canvas.ClipsDescendants = false

	makeImage(canvas, "SettingsIcon", ASSETS.SettingsIcon, UDim2.fromOffset(72, 56), UDim2.fromOffset(120, 120), 204, false)
	makeLabel(canvas, "Title", "Settings", UDim2.fromOffset(205, 48), UDim2.fromOffset(510, 120), 72, Color3.new(1,1,1), Enum.TextXAlignment.Left, 205)

	local CLOSE_POSITION = UDim2.fromOffset(1270, 60)
	local CLOSE_SIZE = UDim2.fromOffset(100, 100)

	local closeButton = makeImage(
		canvas,
		"CloseButton",
		ASSETS.CloseButton,
		CLOSE_POSITION,
		CLOSE_SIZE,
		210,
		true
	)

	local closeBusy = false

	local function resetCloseButton(animated)
		if not animated then
			local currentTween = activeTweens[closeButton]
			if currentTween then
				currentTween:Cancel()
				activeTweens[closeButton] = nil
			end

			closeButton.Position = CLOSE_POSITION
			closeButton.Size = CLOSE_SIZE
			closeButton.Rotation = 0
			closeButton.ImageColor3 = Color3.new(1, 1, 1)
			return
		end

		playTween(closeButton, RELEASE_TWEEN, {
			Position = CLOSE_POSITION,
			Size = CLOSE_SIZE,
			Rotation = 0,
			ImageColor3 = Color3.new(1, 1, 1),
		})
	end

	closeButton.MouseEnter:Connect(function()
		if closeBusy then
			return
		end

		playTween(closeButton, TOGGLE_FADE_TWEEN, {
			Position = UDim2.fromOffset(1257, 49),
			Size = UDim2.fromOffset(106, 106),
			ImageColor3 = Color3.fromRGB(255, 244, 190),
		})
	end)

	closeButton.MouseLeave:Connect(function()
		if closeBusy then
			return
		end

		resetCloseButton(true)
	end)

	local musicStatus, sfxStatus
	local musicToggle, sfxToggle
	local musicKnob, sfxKnob
	local musicToggleText, sfxToggleText

	local function isMusic(sound)
		local n = string.lower(sound.Name)
		return string.find(n, "music") or string.find(n, "theme") or string.find(n, "bgm")
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
		for _, obj in ipairs(SoundService:GetDescendants()) do
			if obj:IsA("Sound") then
				local volume = originalVolume(obj)
				if isMusic(obj) then
					obj.Volume = musicEnabled and volume or 0
				else
					obj.Volume = sfxEnabled and volume or 0
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

		playTween(label, TweenInfo.new(
			0.07,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
			), {
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

	local function refreshSingleToggle(toggle, knob, toggleText, enabled, animate)
		local onBackground = toggle:FindFirstChild("OnBackground")
		local offBackground = toggle:FindFirstChild("OffBackground")

		if not onBackground or not offBackground then
			return
		end

		local knobPosition

		-- Keep the text label fully inside the 230x96 switch.
		-- OFF uses the full switch width with right alignment, so it cannot
		-- disappear due to AnchorPoint or a narrow text box.
		toggleText.AnchorPoint = Vector2.new(0, 0)
		toggleText.TextTruncate = Enum.TextTruncate.None

		if enabled then
			knobPosition = UDim2.new(1, -78, 0.5, -39)
			toggleText.Position = UDim2.fromOffset(22, 0)
			toggleText.Size = UDim2.fromOffset(108, 96)
			toggleText.TextXAlignment = Enum.TextXAlignment.Left
		else
			knobPosition = UDim2.new(0, 2, 0.5, -39)
			toggleText.Position = UDim2.fromOffset(0, 0)
			toggleText.Size = UDim2.new(1, -12, 1, 0)
			toggleText.TextXAlignment = Enum.TextXAlignment.Right
		end

		if animate then
			playTween(onBackground, TOGGLE_FADE_TWEEN, {
				ImageTransparency = enabled and 0 or 1,
			})
			playTween(offBackground, TOGGLE_FADE_TWEEN, {
				ImageTransparency = enabled and 1 or 0,
			})
			playTween(knob, TOGGLE_MOVE_TWEEN, {
				Position = knobPosition,
			})
		else
			onBackground.ImageTransparency = enabled and 0 or 1
			offBackground.ImageTransparency = enabled and 1 or 0
			knob.Position = knobPosition
		end

		setLabelState(
			toggleText,
			enabled and "ON" or "OFF",
			Color3.new(1, 1, 1),
			animate
		)
	end

	local function refreshToggleRow(isMusicRow, animate)
		local toggle
		local knob
		local toggleText
		local statusLabel
		local enabled

		if isMusicRow then
			toggle = musicToggle
			knob = musicKnob
			toggleText = musicToggleText
			statusLabel = musicStatus
			enabled = musicEnabled
		else
			toggle = sfxToggle
			knob = sfxKnob
			toggleText = sfxToggleText
			statusLabel = sfxStatus
			enabled = sfxEnabled
		end

		refreshSingleToggle(
			toggle,
			knob,
			toggleText,
			enabled,
			animate
		)

		setLabelState(
			statusLabel,
			enabled and "ON" or "OFF",
			enabled
				and Color3.fromRGB(65, 215, 255)
				or Color3.fromRGB(255, 75, 75),
			animate
		)
	end

	local function refreshToggles(animate)
		-- Used only when opening/initializing the Settings window.
		refreshToggleRow(true, animate)
		refreshToggleRow(false, animate)
	end

	local function createToggle(parent, name, isMusicRow)
		local toggle = Instance.new("TextButton")
		toggle.Name = name .. "Toggle"
		toggle.BackgroundTransparency = 1
		toggle.AutoButtonColor = false
		toggle.Text = ""
		toggle.Position = UDim2.fromOffset(955, 64)
		toggle.Size = UDim2.fromOffset(230, 96)
		toggle.ClipsDescendants = true
		toggle.ZIndex = 207
		toggle.Parent = parent

		local toggleScale = Instance.new("UIScale")
		toggleScale.Name = "PressScale"
		toggleScale.Scale = 1
		toggleScale.Parent = toggle

		local onBackground = makeImage(
			toggle,
			"OnBackground",
			ASSETS.ToggleOn,
			UDim2.fromOffset(-83, -82),
			UDim2.fromOffset(396, 264),
			207,
			false
		)
		onBackground.ScaleType = Enum.ScaleType.Stretch

		local offBackground = makeImage(
			toggle,
			"OffBackground",
			ASSETS.ToggleOff,
			UDim2.fromOffset(-39, -55),
			UDim2.fromOffset(307, 213),
			207,
			false
		)
		offBackground.ScaleType = Enum.ScaleType.Stretch
		offBackground.ImageTransparency = 1

		local toggleText = makeLabel(
			toggle,
			name .. "ToggleText",
			"ON",
			UDim2.fromOffset(22, 0),
			UDim2.fromOffset(108, 96),
			38,
			Color3.new(1, 1, 1),
			Enum.TextXAlignment.Left,
			209
		)
		toggleText.TextTruncate = Enum.TextTruncate.None

		local knob = Instance.new("Frame")
		knob.Name = name .. "Knob"
		knob.BackgroundTransparency = 1
		knob.Position = UDim2.new(1, -78, 0.5, -39)
		knob.Size = UDim2.fromOffset(78, 78)
		knob.ClipsDescendants = true
		knob.ZIndex = 210
		knob.Parent = toggle

		local knobImage = makeImage(
			knob,
			"Image",
			ASSETS.SliderKnob,
			UDim2.fromOffset(-44, -41),
			UDim2.fromOffset(165, 164),
			211,
			false
		)
		knobImage.ScaleType = Enum.ScaleType.Stretch

		if isMusicRow then
			musicToggle, musicKnob, musicToggleText = toggle, knob, toggleText
		else
			sfxToggle, sfxKnob, sfxToggleText = toggle, knob, toggleText
		end

		toggle.MouseButton1Down:Connect(function()
			playTween(toggleScale, PRESS_TWEEN, {
				Scale = 0.96,
			})
		end)

		toggle.MouseButton1Up:Connect(function()
			playTween(toggleScale, RELEASE_TWEEN, {
				Scale = 1,
			})
		end)

		toggle.MouseLeave:Connect(function()
			playTween(toggleScale, RELEASE_TWEEN, {
				Scale = 1,
			})
		end)

		toggle.Activated:Connect(function()
			if isMusicRow then
				musicEnabled = not musicEnabled
			else
				sfxEnabled = not sfxEnabled
			end

			playTween(toggleScale, PRESS_TWEEN, {
				Scale = 0.94,
			})
			task.delay(0.07, function()
				playTween(toggleScale, RELEASE_TWEEN, {
					Scale = 1,
				})
			end)

			applyAudio()

			-- Only animate the row that was clicked.
			-- This prevents the untouched Music/SFX switch from blinking.
			refreshToggleRow(isMusicRow, true)
		end)
	end

	local function makeAudioRow(name, y, icon, prefix, isMusicRow)
		local row = makeImage(
			canvas,
			name .. "Row",
			ASSETS.RowBackground,
			UDim2.fromOffset(86, y),
			UDim2.fromOffset(1278, 226),
			203,
			false
		)
		row.ScaleType = Enum.ScaleType.Stretch

		makeImage(
			row,
			name .. "Icon",
			icon,
			UDim2.fromOffset(60, 30),
			UDim2.fromOffset(160, 160),
			205,
			false
		)

		makeLabel(
			row,
			name .. "Prefix",
			prefix .. ":",
			UDim2.fromOffset(460, 55),
			UDim2.fromOffset(230, 110),
			52,
			Color3.new(1, 1, 1),
			Enum.TextXAlignment.Right,
			206
		)

		local status = makeLabel(
			row,
			name .. "Status",
			"ON",
			UDim2.fromOffset(700, 55),
			UDim2.fromOffset(180, 110),
			52,
			Color3.fromRGB(65, 215, 255),
			Enum.TextXAlignment.Left,
			206
		)

		if isMusicRow then
			musicStatus = status
		else
			sfxStatus = status
		end

		createToggle(row, name, isMusicRow)
	end

	makeAudioRow("Music", 160, ASSETS.MusicIcon, "Music", true)
	makeAudioRow("Sfx", 360, ASSETS.SfxIcon, "SFX", false)

	local speedRow = makeImage(canvas, "MoveSpeedRow", ASSETS.RowBackground, UDim2.fromOffset(86,560), UDim2.fromOffset(1278,226), 203, false)
	speedRow.ScaleType = Enum.ScaleType.Stretch
	makeLabel(speedRow, "MoveSpeedPrefix", "Move Speed:", UDim2.fromOffset(400,35), UDim2.fromOffset(360,80), 46, Color3.new(1,1,1), Enum.TextXAlignment.Right, 206)
	local speedValue = makeLabel(speedRow, "MoveSpeedValue", "16", UDim2.fromOffset(770,35), UDim2.fromOffset(120,80), 46, Color3.fromRGB(65,215,255), Enum.TextXAlignment.Left, 206)

	local sliderArea = Instance.new("Frame")
	sliderArea.Name = "SliderArea"
	sliderArea.BackgroundTransparency = 1
	sliderArea.Active = true
	sliderArea.Position = UDim2.fromOffset(95,108)
	sliderArea.Size = UDim2.fromOffset(1088,82)
	sliderArea.ZIndex = 205
	sliderArea.Parent = speedRow

	-- The existing SliderTrack and SliderFill assets are reused as-is.
	-- Each rounded end is rendered separately from the stretchable middle,
	-- so the left cap can never be squashed.

	local TRACK_X = 0
	local TRACK_Y = 22
	local TRACK_WIDTH = 1088
	local TRACK_HEIGHT = 38

	local TRACK_CAP_WIDTH = 19
	local TRACK_MIDDLE_WIDTH = TRACK_WIDTH - (TRACK_CAP_WIDTH * 2)

	local FILL_X = 4
	local FILL_Y = 26
	local FILL_HEIGHT = 30
	local FILL_CAP_WIDTH = 15

	local KNOB_SIZE = 76
	local KNOB_HALF = KNOB_SIZE / 2

	-- Maps a normalized region of a source image into a clipping frame.
	-- This avoids ImageRect coordinates, which can break when Roblox resizes
	-- an uploaded image internally.
	local function createMappedPiece(
		parent,
		name,
		image,
		clipPosition,
		clipSize,
		sourceImageSize,
		sourceRegion,
		zIndex
	)
		local clip = Instance.new("Frame")
		clip.Name = name
		clip.Position = clipPosition
		clip.Size = clipSize
		clip.BackgroundTransparency = 1
		clip.BorderSizePixel = 0
		clip.ClipsDescendants = true
		clip.ZIndex = zIndex
		clip.Parent = parent

		local clipWidth = clipSize.X.Offset
		local clipHeight = clipSize.Y.Offset

		local fullImageWidth =
			clipWidth * sourceImageSize.X / sourceRegion.Width
		local fullImageHeight =
			clipHeight * sourceImageSize.Y / sourceRegion.Height

		local imagePositionX =
			-(sourceRegion.X / sourceImageSize.X) * fullImageWidth
		local imagePositionY =
			-(sourceRegion.Y / sourceImageSize.Y) * fullImageHeight

		local imageObject = makeImage(
			clip,
			"Image",
			image,
			UDim2.fromOffset(imagePositionX, imagePositionY),
			UDim2.fromOffset(fullImageWidth, fullImageHeight),
			zIndex,
			false
		)
		imageObject.ScaleType = Enum.ScaleType.Stretch

		return clip, imageObject
	end

	-- SliderTrack source PNG:
	-- canvas 1536x1024, visible bar approximately x=103..1477, y=432..554.
	local trackSourceSize = Vector2.new(1536, 1024)

	local trackLeftClip = createMappedPiece(
		sliderArea,
		"TrackLeftCap",
		ASSETS.SliderTrack,
		UDim2.fromOffset(TRACK_X, TRACK_Y),
		UDim2.fromOffset(TRACK_CAP_WIDTH, TRACK_HEIGHT),
		trackSourceSize,
		{
			X = 103,
			Y = 432,
			Width = 61,
			Height = 122,
		},
		206
	)

	local trackMiddleClip = createMappedPiece(
		sliderArea,
		"TrackMiddle",
		ASSETS.SliderTrack,
		UDim2.fromOffset(TRACK_X + TRACK_CAP_WIDTH, TRACK_Y),
		UDim2.fromOffset(TRACK_MIDDLE_WIDTH, TRACK_HEIGHT),
		trackSourceSize,
		{
			X = 164,
			Y = 432,
			Width = 1252,
			Height = 122,
		},
		206
	)

	local trackRightClip = createMappedPiece(
		sliderArea,
		"TrackRightCap",
		ASSETS.SliderTrack,
		UDim2.fromOffset(
			TRACK_X + TRACK_WIDTH - TRACK_CAP_WIDTH,
			TRACK_Y
		),
		UDim2.fromOffset(TRACK_CAP_WIDTH, TRACK_HEIGHT),
		trackSourceSize,
		{
			X = 1416,
			Y = 432,
			Width = 61,
			Height = 122,
		},
		206
	)

	-- SliderFill source PNG:
	-- canvas 1274x155, visible fill approximately x=10..1264, y=10..145.
	local fillSourceSize = Vector2.new(1274, 155)

	local fillLeftClip = createMappedPiece(
		sliderArea,
		"FillLeftCap",
		ASSETS.SliderFill,
		UDim2.fromOffset(FILL_X, FILL_Y),
		UDim2.fromOffset(FILL_CAP_WIDTH, FILL_HEIGHT),
		fillSourceSize,
		{
			X = 10,
			Y = 10,
			Width = 68,
			Height = 135,
		},
		207
	)

	-- The middle is the only piece whose width changes.
	-- It excludes both rounded ends from the source image.
	local fillMiddleClip = Instance.new("Frame")
	fillMiddleClip.Name = "FillMiddle"
	fillMiddleClip.Position = UDim2.fromOffset(
		FILL_X + FILL_CAP_WIDTH,
		FILL_Y
	)
	fillMiddleClip.Size = UDim2.fromOffset(1, FILL_HEIGHT)
	fillMiddleClip.BackgroundTransparency = 1
	fillMiddleClip.BorderSizePixel = 0
	fillMiddleClip.ClipsDescendants = true
	fillMiddleClip.ZIndex = 207
	fillMiddleClip.Parent = sliderArea

	local fillMiddleImage = makeImage(
		fillMiddleClip,
		"Image",
		ASSETS.SliderFill,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(1, FILL_HEIGHT),
		207,
		false
	)
	fillMiddleImage.ScaleType = Enum.ScaleType.Stretch

	-- Crop the transparent padding around Circle.png using a clipping frame.
	local knob = Instance.new("TextButton")
	knob.Name = "SliderKnob"
	knob.BackgroundTransparency = 1
	knob.AutoButtonColor = false
	knob.Text = ""
	knob.Position = UDim2.fromOffset(
		math.floor((TRACK_WIDTH - KNOB_SIZE) * 0.5),
		TRACK_Y + math.floor(TRACK_HEIGHT / 2) - KNOB_HALF
	)
	knob.Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE)
	knob.ClipsDescendants = true
	knob.ZIndex = 209
	knob.Parent = sliderArea

	local knobImage = makeImage(
		knob,
		"Image",
		ASSETS.SliderKnob,
		UDim2.fromOffset(-42, -40),
		UDim2.fromOffset(160, 160),
		210,
		false
	)
	knobImage.ScaleType = Enum.ScaleType.Stretch

	local currentSpeed, dragging, activeTouch = DEFAULT_SPEED, false, nil

	local function renderSpeed(speed)
		currentSpeed = math.clamp(
			math.round(tonumber(speed) or DEFAULT_SPEED),
			MIN_SPEED,
			MAX_SPEED
		)

		local alpha =
			(currentSpeed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)

		local usableKnobWidth = TRACK_WIDTH - KNOB_SIZE
		local knobX = TRACK_X
			+ math.floor(usableKnobWidth * alpha + 0.5)
		local knobCenterX = knobX + KNOB_HALF

		-- Fill reaches the center of the knob.
		local visibleFillWidth = math.max(
			0,
			math.floor(knobCenterX - FILL_X + 0.5)
		)
		local middleWidth = math.max(
			0,
			visibleFillWidth - FILL_CAP_WIDTH
		)

		fillLeftClip.Visible = visibleFillWidth > 0
		fillMiddleClip.Visible = middleWidth > 0
		fillMiddleClip.Size = UDim2.fromOffset(
			middleWidth,
			FILL_HEIGHT
		)

		if middleWidth > 0 then
			-- Middle source region:
			-- x=78..1196, y=10..145 in the 1274x155 PNG.
			local fullImageWidth =
				middleWidth * fillSourceSize.X / 1118
			local fullImageHeight =
				FILL_HEIGHT * fillSourceSize.Y / 135

			fillMiddleImage.Position = UDim2.fromOffset(
				-(78 / fillSourceSize.X) * fullImageWidth,
				-(10 / fillSourceSize.Y) * fullImageHeight
			)
			fillMiddleImage.Size = UDim2.fromOffset(
				fullImageWidth,
				fullImageHeight
			)
		end

		knob.Position = UDim2.fromOffset(
			knobX,
			TRACK_Y + math.floor(TRACK_HEIGHT / 2) - KNOB_HALF
		)

		speedValue.Text = tostring(currentSpeed)
	end

	local function updateFromX(x)
		local absoluteScale = scale.Scale
		local absoluteTrackStart = sliderArea.AbsolutePosition.X
			+ ((TRACK_X + KNOB_HALF) * absoluteScale)
		local absoluteUsableWidth =
			(TRACK_WIDTH - KNOB_SIZE) * absoluteScale

		if absoluteUsableWidth <= 0 then
			return
		end

		local alpha = math.clamp(
			(x - absoluteTrackStart) / absoluteUsableWidth,
			0,
			1
		)

		renderSpeed(
			MIN_SPEED + ((MAX_SPEED - MIN_SPEED) * alpha)
		)
	end

	local function begin(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		dragging = true
		if input.UserInputType == Enum.UserInputType.Touch then activeTouch = input end
		updateFromX(input.Position.X)
	end

	sliderArea.InputBegan:Connect(begin)
	knob.InputBegan:Connect(begin)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			updateFromX(input.Position.X)
		elseif input.UserInputType == Enum.UserInputType.Touch and input == activeTouch then
			updateFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not dragging then return end
		local mouseEnd = input.UserInputType == Enum.UserInputType.MouseButton1
		local touchEnd = input.UserInputType == Enum.UserInputType.Touch and input == activeTouch
		if not mouseEnd and not touchEnd then return end
		dragging, activeTouch = false, nil
		moveSpeedRemote:FireServer(currentSpeed)
	end)

	-- Fourth row: teleport directly to the local player's aquarium.
	local aquariumRow = makeImage(
		canvas,
		"AquariumTeleportRow",
		ASSETS.RowBackground,
		UDim2.fromOffset(86, 760),
		UDim2.fromOffset(1278, 226),
		203,
		false
	)
	aquariumRow.ScaleType = Enum.ScaleType.Stretch

	makeImage(
		aquariumRow,
		"FishBowlIcon",
		ASSETS.FishBowl,
		UDim2.fromOffset(60, 30),
		UDim2.fromOffset(160, 160),
		205,
		false
	)

	makeLabel(
		aquariumRow,
		"AquariumTitle",
		"My Aquarium",
		UDim2.fromOffset(220, 55),
		UDim2.fromOffset(830, 110),
		46,
		Color3.new(1, 1, 1),
		Enum.TextXAlignment.Center,
		206
	)

	local teleportButton = makeImage(
		aquariumRow,
		"TeleportButton",
		ASSETS.TeleportButton,
		UDim2.fromOffset(930, 64),
		UDim2.fromOffset(270, 96),
		208,
		true
	)
	teleportButton.ScaleType = Enum.ScaleType.Fit

	local teleportScale = Instance.new("UIScale")
	teleportScale.Name = "PressScale"
	teleportScale.Scale = 1
	teleportScale.Parent = teleportButton

	local teleportBusy = false

	local function releaseTeleportButton()
		playTween(teleportScale, RELEASE_TWEEN, {
			Scale = 1,
		})
	end

	teleportButton.MouseButton1Down:Connect(function()
		if teleportBusy then
			return
		end

		playTween(teleportScale, PRESS_TWEEN, {
			Scale = 0.94,
		})
	end)

	teleportButton.MouseButton1Up:Connect(releaseTeleportButton)
	teleportButton.MouseLeave:Connect(releaseTeleportButton)

	teleportButton.Activated:Connect(function()
		if teleportBusy then
			return
		end

		teleportBusy = true

		playTween(teleportScale, PRESS_TWEEN, {
			Scale = 0.91,
		})

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

		-- A short lock prevents accidental double teleports on touch devices.
		task.delay(0.8, function()
			teleportBusy = false
		end)
	end)

	refs.setSettingsVisible = function(visible)
		overlay.Visible = visible
		if visible then
			closeBusy = false
			teleportBusy = false
			teleportScale.Scale = 1
			resetCloseButton(false)
			renderSpeed(player:GetAttribute("MoveSpeed") or DEFAULT_SPEED)
			refreshToggles(false)
		end
	end

	closeButton.Activated:Connect(function()
		if closeBusy then
			return
		end

		closeBusy = true

		playTween(closeButton, PRESS_TWEEN, {
			Position = UDim2.fromOffset(1268, 60),
			Size = UDim2.fromOffset(84, 84),
			Rotation = -7,
			ImageColor3 = Color3.fromRGB(255, 223, 100),
		})

		task.delay(0.075, function()
			playTween(closeButton, RELEASE_TWEEN, {
				Position = UDim2.fromOffset(1257, 49),
				Size = UDim2.fromOffset(106, 106),
				Rotation = 3,
				ImageColor3 = Color3.new(1, 1, 1),
			})

			task.delay(0.12, function()
				resetCloseButton(true)

				task.delay(0.055, function()
					refs.setSettingsVisible(false)
					closeBusy = false
				end)
			end)
		end)
	end)

	SoundService.DescendantAdded:Connect(function(obj)
		if obj:IsA("Sound") then task.defer(applyAudio) end
	end)

	player:GetAttributeChangedSignal("MoveSpeed"):Connect(function()
		local value = player:GetAttribute("MoveSpeed")
		if value ~= nil then renderSpeed(value) end
	end)

	refreshToggles(false)
	renderSpeed(player:GetAttribute("MoveSpeed") or DEFAULT_SPEED)
end

return SettingsPanelHud
