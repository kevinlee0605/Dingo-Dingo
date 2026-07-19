-- QuestModernUI
-- ModuleScript location:
-- StarterGui > FishingGui > FishingClient > QuestModernUI
--
-- This module builds the new Daily / Weekly / Monthly quest UI.
-- It reads the existing quest state from FishingRemotes and uses
-- the existing QuestAction remote to claim completed rewards.

local QuestModernUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local ASSETS = {
	MainWindow = "rbxassetid://129797059891426",
	HeaderPanel = "rbxassetid://102559548778492",
	QuestCard = "rbxassetid://106587503742848",

	DailyWeeklyTab = "rbxassetid://121211545489513",
	MonthlyTab = "rbxassetid://115441815389393",
	CloseButton = "rbxassetid://119322438066977",

	QuestIcon1 = "rbxassetid://76825236524029",
	QuestIcon2 = "rbxassetid://105499819099238",
	QuestIcon3 = "rbxassetid://88355071605279",
	QuestIcon4 = "rbxassetid://101869041913042",

	HeaderDecoration = "rbxassetid://75908657886403",
	RewardBox = "rbxassetid://117715064456350",
	CornerDecoration = "rbxassetid://86731176898277",

	ProgressTrack = "rbxassetid://133345960968161",
	ProgressGreenFill = "rbxassetid://125033823798319",

	ScrollbarTrack = "rbxassetid://114957942985162",
	ScrollbarThumb = "rbxassetid://77566018656635",

	StatusBlue = "rbxassetid://96566593336613",
	StatusGreen = "rbxassetid://109147124391851",

	MoneyIcon = "rbxassetid://133418085425740",
	XPIcon = "rbxassetid://102202681165196",
}

-- These source rectangles remove the transparent padding from the
-- original uploaded images. Do not change these unless the source
-- PNG files are re-uploaded with different dimensions.
local SOURCE_CANVAS_SIZE = Vector2.new(1187, 1326)

local CROPS = {
	CloseButton = {
		offset = Vector2.new(375, 422),
		size = Vector2.new(427, 439),
	},
	QuestIcon1 = {
		offset = Vector2.new(343, 391),
		size = Vector2.new(492, 513),
	},
	QuestIcon2 = {
		offset = Vector2.new(317, 382),
		size = Vector2.new(547, 554),
	},
	QuestIcon3 = {
		offset = Vector2.new(302, 366),
		size = Vector2.new(582, 592),
	},
	QuestIcon4 = {
		offset = Vector2.new(375, 420),
		size = Vector2.new(435, 455),
	},
	DailyWeeklyTab = {
		offset = Vector2.new(258, 592),
		size = Vector2.new(671, 211),
	},
	MonthlyTab = {
		offset = Vector2.new(265, 515),
		size = Vector2.new(696, 225),
	},
	HeaderDecoration = {
		offset = Vector2.new(424, 504),
		size = Vector2.new(342, 174),
	},
	RewardBox = {
		offset = Vector2.new(373, 543),
		size = Vector2.new(440, 232),
	},
	MoneyIcon = {
		offset = Vector2.new(539, 618),
		size = Vector2.new(58, 64),
	},
	XPIcon = {
		offset = Vector2.new(565, 624),
		size = Vector2.new(51, 56),
	},
	CornerDecoration = {
		offset = Vector2.new(1000, 1080),
		size = Vector2.new(187, 246),
	},
}

-- =========================
-- EASY UI TUNING VALUES
-- =========================

local BASE_WIDTH = 1187
local BASE_HEIGHT = 1326
local QUEST_UI_SIZE_MULTIPLIER = 0.72

local WINDOW_X = 0
local WINDOW_Y = 0

local TAB_Y = 14
local TAB_WIDTH = 345
local TAB_HEIGHT = 104
local TAB_GAP = 8

local HEADER_X = 28
local HEADER_Y = 125
local HEADER_WIDTH = 1101
local HEADER_HEIGHT = 192

local LIST_X = 28
local LIST_Y = 327
local LIST_WIDTH = 1095
local LIST_HEIGHT = 936
local CARD_HEIGHT = 238
local CARD_GAP = 12

-- Quest UI background blur
local QUEST_BLUR_SIZE = 10
local QUEST_BLUR_TWEEN_TIME = 0.18

-- Quest list scrolling
local QUEST_SCROLL_WHEEL_STEP = 150
local QUEST_SCROLL_BOTTOM_PADDING = 120

local AUTO_CLAIM_COMPLETED_QUESTS = true

local PERIODS = { "Daily", "Weekly", "Monthly" }

local PERIOD_LABELS = {
	Daily = "Daily",
	Weekly = "Weekly",
	Monthly = "Monthly",
}

local PERIOD_TITLES = {
	Daily = "Daily Quests",
	Weekly = "Weekly Quests",
	Monthly = "Monthly Quests",
}

local function makeText(parent, name, text, textSize, color, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font or Enum.Font.FredokaOne
	label.Text = text or ""
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextSize = textSize or 24
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.25
	label.ZIndex = 205
	label.Parent = parent
	return label
end

local function addCorner(guiObject, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = guiObject
	return corner
end

local function makeArtwork(parent, imageId, zIndex, crop)
	local artwork = Instance.new("ImageLabel")
	artwork.Name = "Artwork"
	artwork.BackgroundTransparency = 1
	artwork.BorderSizePixel = 0
	artwork.Image = imageId
	artwork.ScaleType = Enum.ScaleType.Stretch
	artwork.ZIndex = zIndex or 200
	artwork.Parent = parent

	if crop then
		-- The source images were uploaded on a 1187 x 1326 transparent canvas.
		-- Roblox can resize large textures internally, so ImageRectOffset based
		-- on the original pixel size clips the wrong region. This method crops
		-- by normalized layout instead, which stays correct after resizing.
		artwork.Position = UDim2.fromScale(
			-crop.offset.X / crop.size.X,
			-crop.offset.Y / crop.size.Y
		)
		artwork.Size = UDim2.fromScale(
			SOURCE_CANVAS_SIZE.X / crop.size.X,
			SOURCE_CANVAS_SIZE.Y / crop.size.Y
		)
	else
		artwork.Position = UDim2.fromScale(0, 0)
		artwork.Size = UDim2.fromScale(1, 1)
	end

	return artwork
end

local function getArtwork(guiObject)
	if not guiObject then
		return nil
	end

	if guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
		return guiObject
	end

	return guiObject:FindFirstChild("Artwork")
end

local function setArtworkColor(guiObject, color)
	local artwork = getArtwork(guiObject)
	if artwork then
		artwork.ImageColor3 = color
	end
end

local function setArtworkTransparency(guiObject, transparency)
	local artwork = getArtwork(guiObject)
	if artwork then
		artwork.ImageTransparency = transparency
	end
end

local function makeImage(parent, name, imageId, position, size, zIndex, crop)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Position = position
	holder.Size = size
	holder.ClipsDescendants = crop ~= nil
	holder.ZIndex = zIndex or 200
	holder.Parent = parent

	makeArtwork(holder, imageId, zIndex or 200, crop)
	return holder
end

local function makeImageButton(parent, name, imageId, position, size, zIndex, crop)
	local button = Instance.new("ImageButton")
	button.Name = name
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.Image = ""
	button.AutoButtonColor = false
	button.ClipsDescendants = crop ~= nil
	button.ZIndex = zIndex or 205
	button.Parent = parent

	makeArtwork(button, imageId, zIndex or 205, crop)
	return button
end

local function addPressFeedback(button)
	local originalSize = button.Size
	local originalPosition = button.Position
	local artwork = getArtwork(button)

	local pressedSize = UDim2.new(
		originalSize.X.Scale,
		originalSize.X.Offset - 6,
		originalSize.Y.Scale,
		originalSize.Y.Offset - 6
	)

	local pressedPosition = UDim2.new(
		originalPosition.X.Scale,
		originalPosition.X.Offset + 3,
		originalPosition.Y.Scale,
		originalPosition.Y.Offset + 3
	)

	local currentButtonTween
	local currentArtworkTween

	local function tweenTo(pressed)
		if currentButtonTween then
			currentButtonTween:Cancel()
		end
		if currentArtworkTween then
			currentArtworkTween:Cancel()
		end

		currentButtonTween = TweenService:Create(
			button,
			TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Size = pressed and pressedSize or originalSize,
				Position = pressed and pressedPosition or originalPosition,
			}
		)
		currentButtonTween:Play()

		if artwork then
			currentArtworkTween = TweenService:Create(
				artwork,
				TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					ImageTransparency = pressed and 0.16 or 0,
				}
			)
			currentArtworkTween:Play()
		end
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			tweenTo(true)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			tweenTo(false)
		end
	end)

	button.MouseLeave:Connect(function()
		tweenTo(false)
	end)
end

local function getUtcNowTable(now)
	return os.date("!*t", now or DateTime.now().UnixTimestamp)
end

local function getNextResetTimestamp(periodName, now)
	now = now or DateTime.now().UnixTimestamp
	local utc = getUtcNowTable(now)

	if periodName == "Daily" then
		local startOfToday = DateTime.fromUniversalTime(
			utc.year,
			utc.month,
			utc.day,
			0,
			0,
			0
		).UnixTimestamp

		return startOfToday + 86400
	end

	if periodName == "Weekly" then
		local startOfToday = DateTime.fromUniversalTime(
			utc.year,
			utc.month,
			utc.day,
			0,
			0,
			0
		).UnixTimestamp

		-- os.date wday: Sunday = 1, Monday = 2.
		local daysUntilMonday = (9 - utc.wday) % 7
		if daysUntilMonday == 0 then
			daysUntilMonday = 7
		end

		return startOfToday + (daysUntilMonday * 86400)
	end

	local nextYear = utc.year
	local nextMonth = utc.month + 1
	if nextMonth > 12 then
		nextMonth = 1
		nextYear += 1
	end

	return DateTime.fromUniversalTime(
		nextYear,
		nextMonth,
		1,
		0,
		0,
		0
	).UnixTimestamp
end

local function formatRemainingTime(totalSeconds)
	totalSeconds = math.max(0, math.floor(totalSeconds))

	local days = math.floor(totalSeconds / 86400)
	local hours = math.floor((totalSeconds % 86400) / 3600)
	local minutes = math.floor((totalSeconds % 3600) / 60)
	local seconds = totalSeconds % 60

	if days > 0 then
		return string.format("%dd %02dh %02dm %02ds", days, hours, minutes, seconds)
	end

	return string.format("%02dh %02dm %02ds", hours, minutes, seconds)
end

local function getObjectiveIconKey(quest, index)
	-- Keep the first four quest-card icons in the exact visual order:
	-- 1 = blue fish, 2 = red fish, 3 = fishing rod, 4 = treasure chest.
	if index == 1 then
		return "QuestIcon1"
	elseif index == 2 then
		return "QuestIcon2"
	elseif index == 3 then
		return "QuestIcon3"
	elseif index == 4 then
		return "QuestIcon4"
	end

	-- For any additional quests, fall back to objective-based icons.
	local objectiveType = quest and quest.objectiveType

	if objectiveType == "catch_any"
		or objectiveType == "discover_biome_species" then
		return "QuestIcon1"
	end

	if objectiveType == "catch_specific_fish"
		or objectiveType == "catch_rarity" then
		return "QuestIcon2"
	end

	if objectiveType == "perfect_cast" then
		return "QuestIcon3"
	end

	if objectiveType == "login"
		or objectiveType == "daily_login"
		or objectiveType == "play_session" then
		return "QuestIcon4"
	end

	local fallback = ((index - 1) % 4) + 1
	return "QuestIcon" .. tostring(fallback)
end

local function getQuestTable(state)
	if type(state) ~= "table" then
		return nil
	end

	return state.Quests or state.QuestState
end

local function textLooksQuestRelated(text)
	if type(text) ~= "string" then
		return false
	end

	local lower = string.lower(text)
	return lower:find("daily quests", 1, true) ~= nil
		or lower == "daily"
		or lower == "weekly"
		or lower == "monthly"
		or lower:find("resets automatically", 1, true) ~= nil
		or lower:find("complete", 1, true) ~= nil
end

local function looksLikeLegacyQuestUi(guiObject, modernRoot)
	if not guiObject or guiObject == modernRoot then
		return false
	end

	if guiObject:IsDescendantOf(modernRoot) then
		return false
	end

	local lowerName = string.lower(guiObject.Name or "")
	if lowerName:find("quest", 1, true) then
		return true
	end

	for _, descendant in ipairs(guiObject:GetDescendants()) do
		local descendantName = string.lower(descendant.Name or "")
		if descendantName:find("quest", 1, true) then
			return true
		end

		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			if textLooksQuestRelated(descendant.Text) then
				return true
			end
		end
	end

	return false
end

local function hideLegacyQuestUi(parentGui, modernRoot, store)
	for _, child in ipairs(parentGui:GetChildren()) do
		if child:IsA("GuiObject") and looksLikeLegacyQuestUi(child, modernRoot) then
			-- Save the original visibility only once.
			-- The old quest panel can be rebuilt after the modern UI opens,
			-- so this function may run repeatedly while the modern UI is visible.
			if store[child] == nil then
				store[child] = child.Visible
			end

			child.Visible = false
		end
	end
end

local function restoreLegacyQuestUi(store)
	for guiObject in pairs(store) do
		if guiObject and guiObject.Parent and guiObject:IsA("GuiObject") then
			-- The modern quest menu permanently replaces this panel. Restoring a
			-- captured true value lets the legacy menu reappear after state updates.
			guiObject.Visible = false
		end
		store[guiObject] = nil
	end
end

function QuestModernUI.create(config)
	assert(type(config) == "table", "QuestModernUI.create requires a config table")
	assert(config.parent, "QuestModernUI.create requires config.parent")

	local player = Players.LocalPlayer
	local remotes = config.remotes
		or ReplicatedStorage:WaitForChild("FishingRemotes")

	local stateUpdated = remotes:WaitForChild("StateUpdated")
	local getState = remotes:WaitForChild("GetState")
	local questAction = remotes:WaitForChild("QuestAction")

	local controller = {
		activePeriod = "Daily",
		state = nil,
		claimRequests = {},
		lastResetRefreshAt = 0,
		backpackWasEnabled = false,
		hiddenLegacyQuestGuis = {},
		blurTween = nil,
		legacySuppressConnection = nil,
		legacySuppressElapsed = 0,
	}

	-- Keep the old Roblox Backpack / inventory hotbar hidden permanently.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	local questBlur = Lighting:FindFirstChild("FishyFishQuestUiBlur")
	if not questBlur then
		questBlur = Instance.new("BlurEffect")
		questBlur.Name = "FishyFishQuestUiBlur"
		questBlur.Parent = Lighting
	end

	questBlur.Enabled = false
	questBlur.Size = 0
	controller.questBlur = questBlur

	local function setQuestBlurVisible(visible)
		if controller.blurTween then
			controller.blurTween:Cancel()
			controller.blurTween = nil
		end

		if visible then
			questBlur.Enabled = true
			controller.blurTween = TweenService:Create(
				questBlur,
				TweenInfo.new(
					QUEST_BLUR_TWEEN_TIME,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),
				{ Size = QUEST_BLUR_SIZE }
			)
			controller.blurTween:Play()
		else
			local closingTween = TweenService:Create(
				questBlur,
				TweenInfo.new(
					QUEST_BLUR_TWEEN_TIME,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),
				{ Size = 0 }
			)

			controller.blurTween = closingTween
			closingTween.Completed:Connect(function()
				if controller.blurTween == closingTween
					and not controller.root.Visible then
					questBlur.Enabled = false
				end
			end)
			closingTween:Play()
		end
	end

	controller.setQuestBlurVisible = setQuestBlurVisible

	local overlay = Instance.new("Frame")
	overlay.Name = "ModernQuestUI"
	overlay.AnchorPoint = Vector2.new(0.5, 0.5)
	overlay.Position = UDim2.fromScale(0.5, 0.4)
	overlay.Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 180
	overlay.Parent = config.parent
	controller.root = overlay

	local function stopLegacyQuestSuppression()
		if controller.legacySuppressConnection then
			controller.legacySuppressConnection:Disconnect()
			controller.legacySuppressConnection = nil
		end
		controller.legacySuppressElapsed = 0
	end

	local function startLegacyQuestSuppression()
		stopLegacyQuestSuppression()

		-- Hide once immediately.
		hideLegacyQuestUi(
			config.parent,
			controller.root,
			controller.hiddenLegacyQuestGuis
		)

		-- FishingClient can rebuild the old quest panel after the modern UI
		-- has already opened. Keep suppressing it while this UI is visible.
		controller.legacySuppressConnection = RunService.RenderStepped:Connect(function(deltaTime)
			controller.legacySuppressElapsed += deltaTime
			if controller.legacySuppressElapsed < 0.08 then
				return
			end
			controller.legacySuppressElapsed = 0

			hideLegacyQuestUi(
				config.parent,
				controller.root,
				controller.hiddenLegacyQuestGuis
			)
		end)
	end

	controller.startLegacyQuestSuppression = startLegacyQuestSuppression
	controller.stopLegacyQuestSuppression = stopLegacyQuestSuppression
	startLegacyQuestSuppression()

	local scale = Instance.new("UIScale")
	scale.Name = "ResponsiveScale"
	scale.Parent = overlay
	controller.scale = scale

	local function updateResponsiveScale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)

		local fit = math.min(
			(viewport.X * 0.97) / BASE_WIDTH,
			(viewport.Y * 0.94) / BASE_HEIGHT
		)

		scale.Scale = math.clamp(
			fit * QUEST_UI_SIZE_MULTIPLIER,
			0.26,
			1
		)
	end

	updateResponsiveScale()

	local camera = workspace.CurrentCamera
	if camera then
		controller.viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
	end

	local background = makeImage(
		overlay,
		"MainWindow",
		ASSETS.MainWindow,
		UDim2.fromOffset(WINDOW_X, WINDOW_Y),
		UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT),
		181
	)
	controller.background = background

	-- Tabs
	controller.tabButtons = {}
	controller.tabLabels = {}
	controller.tabTints = {}

	for index, periodName in ipairs(PERIODS) do
		local x = 28 + ((index - 1) * (TAB_WIDTH + TAB_GAP))
		local imageId = periodName == "Monthly"
			and ASSETS.MonthlyTab
			or ASSETS.DailyWeeklyTab
		local crop = periodName == "Monthly"
			and CROPS.MonthlyTab
			or CROPS.DailyWeeklyTab

		local button = makeImageButton(
			overlay,
			periodName .. "Tab",
			imageId,
			UDim2.fromOffset(x, TAB_Y),
			UDim2.fromOffset(TAB_WIDTH, TAB_HEIGHT),
			190,
			crop
		)
		addPressFeedback(button)

		local selectedTint = Instance.new("Frame")
		selectedTint.Name = "SelectedTint"
		selectedTint.BackgroundColor3 = Color3.fromRGB(0, 145, 255)
		selectedTint.BackgroundTransparency = 0.32
		selectedTint.BorderSizePixel = 0
		selectedTint.Size = UDim2.fromScale(1, 1)
		selectedTint.Visible = false
		selectedTint.ZIndex = 191
		selectedTint.Parent = button
		addCorner(selectedTint, 23)

		local tintGradient = Instance.new("UIGradient")
		tintGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(31, 201, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 85, 255)),
		})
		tintGradient.Rotation = 90
		tintGradient.Parent = selectedTint

		local label = makeText(
			button,
			"Label",
			PERIOD_LABELS[periodName],
			33,
			Color3.fromRGB(235, 242, 255)
		)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.61, 0.52)
		label.Size = UDim2.fromScale(0.52, 0.56)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.ZIndex = 192

		button.MouseButton1Click:Connect(function()
			controller.activePeriod = periodName
			controller:Render()
		end)

		controller.tabButtons[periodName] = button
		controller.tabLabels[periodName] = label
		controller.tabTints[periodName] = selectedTint
	end

	local closeButton = makeImageButton(
		overlay,
		"CloseButton",
		ASSETS.CloseButton,
		UDim2.fromOffset(1080, 19),
		UDim2.fromOffset(78, 80),
		210,
		CROPS.CloseButton
	)
	addPressFeedback(closeButton)
	controller.closeButton = closeButton

	closeButton.MouseButton1Click:Connect(function()
		controller:SetVisible(false)

		if config.onClose then
			config.onClose()
		end
	end)

	-- Header
	local header = makeImage(
		overlay,
		"HeaderPanel",
		ASSETS.HeaderPanel,
		UDim2.fromOffset(HEADER_X, HEADER_Y),
		UDim2.fromOffset(HEADER_WIDTH, HEADER_HEIGHT),
		185
	)
	controller.header = header

	local headerTitle = makeText(
		header,
		"HeaderTitle",
		"Daily Quests",
		54,
		Color3.fromRGB(255, 255, 255)
	)
	headerTitle.Position = UDim2.fromOffset(38, 18)
	headerTitle.Size = UDim2.fromOffset(560, 72)
	headerTitle.TextStrokeTransparency = 0.05
	headerTitle.ZIndex = 188
	controller.headerTitle = headerTitle

	local completedText = makeText(
		header,
		"CompletedText",
		"0/0 complete",
		26,
		Color3.fromRGB(30, 221, 255),
		Enum.Font.GothamBold
	)
	completedText.Position = UDim2.fromOffset(38, 103)
	completedText.Size = UDim2.fromOffset(220, 44)
	completedText.TextStrokeTransparency = 1
	completedText.ZIndex = 188
	controller.completedText = completedText

	local separator = makeText(
		header,
		"Separator",
		"|",
		29,
		Color3.fromRGB(30, 221, 255),
		Enum.Font.GothamBold
	)
	separator.Position = UDim2.fromOffset(245, 103)
	separator.Size = UDim2.fromOffset(25, 44)
	separator.TextXAlignment = Enum.TextXAlignment.Center
	separator.TextStrokeTransparency = 1
	separator.ZIndex = 188

	local resetText = makeText(
		header,
		"ResetText",
		"Resets automatically in:",
		24,
		Color3.fromRGB(30, 221, 255),
		Enum.Font.GothamBold
	)
	resetText.Position = UDim2.fromOffset(270, 103)
	resetText.Size = UDim2.fromOffset(315, 44)
	resetText.TextStrokeTransparency = 1
	resetText.ZIndex = 188

	local clockHolder = Instance.new("Frame")
	clockHolder.Name = "Clock"
	clockHolder.BackgroundTransparency = 1
	clockHolder.Position = UDim2.fromOffset(570, 105)
	clockHolder.Size = UDim2.fromOffset(42, 42)
	clockHolder.ZIndex = 188
	clockHolder.Parent = header
	controller.clockHolder = clockHolder

	local clockCircle = Instance.new("Frame")
	clockCircle.Name = "ClockCircle"
	clockCircle.BackgroundTransparency = 1
	clockCircle.Size = UDim2.fromScale(1, 1)
	clockCircle.ZIndex = 188
	clockCircle.Parent = clockHolder
	addCorner(clockCircle, 21)

	local clockStroke = Instance.new("UIStroke")
	clockStroke.Color = Color3.fromRGB(30, 221, 255)
	clockStroke.Thickness = 3
	clockStroke.Parent = clockCircle

	local clockHand = Instance.new("Frame")
	clockHand.Name = "ClockHand"
	clockHand.AnchorPoint = Vector2.new(0.5, 1)
	clockHand.Position = UDim2.fromScale(0.5, 0.5)
	clockHand.Size = UDim2.fromOffset(3, 13)
	clockHand.BackgroundColor3 = Color3.fromRGB(30, 221, 255)
	clockHand.BorderSizePixel = 0
	clockHand.ZIndex = 190
	clockHand.Parent = clockHolder
	addCorner(clockHand, 2)
	controller.clockHand = clockHand

	local clockCenter = Instance.new("Frame")
	clockCenter.AnchorPoint = Vector2.new(0.5, 0.5)
	clockCenter.Position = UDim2.fromScale(0.5, 0.5)
	clockCenter.Size = UDim2.fromOffset(7, 7)
	clockCenter.BackgroundColor3 = Color3.fromRGB(30, 221, 255)
	clockCenter.BorderSizePixel = 0
	clockCenter.ZIndex = 191
	clockCenter.Parent = clockHolder
	addCorner(clockCenter, 4)

	local timerText = makeText(
		header,
		"TimerText",
		"00h 00m 00s",
		26,
		Color3.fromRGB(30, 221, 255),
		Enum.Font.GothamBold
	)
	timerText.Position = UDim2.fromOffset(620, 103)
	timerText.Size = UDim2.fromOffset(310, 44)
	timerText.TextStrokeTransparency = 1
	timerText.ZIndex = 188
	controller.timerText = timerText

	local headerDecoration = makeImage(
		header,
		"HeaderDecoration",
		ASSETS.HeaderDecoration,
		UDim2.fromOffset(760, 17),
		UDim2.fromOffset(320, 160),
		187,
		CROPS.HeaderDecoration
	)

	-- Scroll area
	local list = Instance.new("ScrollingFrame")
	list.Name = "QuestList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(LIST_X, LIST_Y)
	list.Size = UDim2.fromOffset(LIST_WIDTH, LIST_HEIGHT)
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.None
	list.Active = true
	list.ScrollingEnabled = true
	list.Selectable = true
	list.ScrollBarThickness = 0
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	list.ClipsDescendants = true
	list.ZIndex = 184
	list.Parent = overlay
	controller.list = list

	local scrollInputCatcher = Instance.new("TextButton")
	scrollInputCatcher.Name = "ScrollInputCatcher"
	scrollInputCatcher.BackgroundTransparency = 1
	scrollInputCatcher.BorderSizePixel = 0
	scrollInputCatcher.Text = ""
	scrollInputCatcher.AutoButtonColor = false
	scrollInputCatcher.Active = true
	scrollInputCatcher.Selectable = false
	scrollInputCatcher.Position = UDim2.fromOffset(LIST_X, LIST_Y)
	scrollInputCatcher.Size = UDim2.fromOffset(LIST_WIDTH, LIST_HEIGHT)
	scrollInputCatcher.ZIndex = 250
	scrollInputCatcher.Parent = overlay
	controller.scrollInputCatcher = scrollInputCatcher

	local listLayout = Instance.new("UIListLayout")
	listLayout.Name = "QuestListLayout"
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, CARD_GAP)
	listLayout.Parent = list
	controller.listLayout = listLayout

	-- Custom scrollbar
	local scrollbarTrack = makeImage(
		overlay,
		"ScrollbarTrack",
		ASSETS.ScrollbarTrack,
		UDim2.fromOffset(1144, LIST_Y),
		UDim2.fromOffset(18, LIST_HEIGHT),
		186
	)
	controller.scrollbarTrack = scrollbarTrack

	local scrollbarThumb = makeImage(
		overlay,
		"ScrollbarThumb",
		ASSETS.ScrollbarThumb,
		UDim2.fromOffset(1146, LIST_Y + 2),
		UDim2.fromOffset(14, 230),
		187
	)
	controller.scrollbarThumb = scrollbarThumb
	scrollbarTrack.Active = true
	scrollbarThumb.Active = true

	-- Hide the track image itself. The invisible holder remains active,
	-- so track clicking and scrolling still work.
	local trackArtwork = getArtwork(scrollbarTrack)
	if trackArtwork then
		trackArtwork.Visible = false
	end

	-- The thin pale line is actually the clipped right edge of every
	-- QuestCard image, not the scrollbar track. Mask only that 4 px edge.
	local questCardRightEdgeMask = Instance.new("Frame")
	questCardRightEdgeMask.Name = "QuestCardRightEdgeMask"
	questCardRightEdgeMask.BackgroundColor3 = Color3.fromRGB(1, 28, 58)
	questCardRightEdgeMask.BorderSizePixel = 0
	questCardRightEdgeMask.Position = UDim2.fromOffset(
		LIST_X + LIST_WIDTH - 4,
		LIST_Y
	)
	questCardRightEdgeMask.Size = UDim2.fromOffset(5, LIST_HEIGHT)
	questCardRightEdgeMask.ZIndex = 252
	questCardRightEdgeMask.Parent = overlay
	controller.questCardRightEdgeMask = questCardRightEdgeMask

	-- Bottom-right decoration.
	-- This asset was supplied separately, so it is used without ImageRect cropping.
	local cornerDecoration = makeImage(
		overlay,
		"CornerDecoration",
		ASSETS.CornerDecoration,
		UDim2.fromOffset(1000, 1090),
		UDim2.fromOffset(185, 225),
		208,
		CROPS.CornerDecoration
	)
	controller.cornerDecoration = cornerDecoration

	local function updateScrollbar()
		local contentHeight = math.max(
			listLayout.AbsoluteContentSize.Y,
			list.AbsoluteCanvasSize.Y
		)
		local viewportHeight = math.max(1, list.AbsoluteWindowSize.Y)

		if contentHeight <= viewportHeight + 1 then
			scrollbarThumb.Visible = false
			setArtworkTransparency(scrollbarTrack, 0.45)
			return
		end

		scrollbarThumb.Visible = true
		setArtworkTransparency(scrollbarTrack, 0)

		local trackHeight = scrollbarTrack.AbsoluteSize.Y
		if trackHeight <= 0 then
			return
		end

		local ratio = math.clamp(viewportHeight / contentHeight, 0.08, 1)
		local thumbHeight = math.max(48, math.floor(trackHeight * ratio))
		local maxThumbTravel = math.max(0, trackHeight - thumbHeight)

		local maxCanvasY = math.max(1, contentHeight - viewportHeight)
		local scrollRatio = math.clamp(list.CanvasPosition.Y / maxCanvasY, 0, 1)
		local thumbY = math.floor(maxThumbTravel * scrollRatio)

		scrollbarThumb.Position = UDim2.fromOffset(
			1146,
			LIST_Y + thumbY
		)
		scrollbarThumb.Size = UDim2.fromOffset(14, thumbHeight)
	end

	controller.updateScrollbar = updateScrollbar

	local function getMaxCanvasY()
		return math.max(
			0,
			list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y
		)
	end

	local function setCanvasY(newY)
		list.CanvasPosition = Vector2.new(
			0,
			math.clamp(newY, 0, getMaxCanvasY())
		)
	end

	local function updateCanvasForQuestCount(questCount)
		questCount = math.max(0, math.floor(tonumber(questCount) or 0))

		local contentHeight = 0
		if questCount > 0 then
			contentHeight = (questCount * CARD_HEIGHT)
				+ ((questCount - 1) * CARD_GAP)
				+ QUEST_SCROLL_BOTTOM_PADDING
		end

		list.CanvasSize = UDim2.fromOffset(0, contentHeight)
		task.defer(updateScrollbar)
	end

	controller.updateCanvasForQuestCount = updateCanvasForQuestCount

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		task.defer(updateScrollbar)
	end)

	list:GetPropertyChangedSignal("CanvasPosition"):Connect(updateScrollbar)
	list:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateScrollbar)

	-- Mouse wheel: the transparent catcher guarantees the event is received
	-- even when the cursor is over a quest card.
	local wheelDirectionMultiplier = nil

	scrollInputCatcher.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end

		local delta = tonumber(input.Position.Z) or 0
		if delta == 0 then
			return
		end

		-- macOS natural scrolling can reverse the wheel sign.
		-- On the first wheel event at the top, assume the player is trying
		-- to move down and remember the correct direction for this session.
		if wheelDirectionMultiplier == nil then
			if list.CanvasPosition.Y <= 1 then
				wheelDirectionMultiplier = delta > 0 and 1 or -1
			else
				wheelDirectionMultiplier = -1
			end
		end

		setCanvasY(
			list.CanvasPosition.Y
				+ (delta * wheelDirectionMultiplier * QUEST_SCROLL_WHEEL_STEP)
		)
	end)

	-- Click/touch and drag anywhere inside the quest list.
	local activeListInput = nil
	local listDragStartY = 0
	local listDragStartCanvasY = 0

	scrollInputCatcher.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			activeListInput = input
			listDragStartY = input.Position.Y
			listDragStartCanvasY = list.CanvasPosition.Y
		end
	end)

	controller.listDragChangedConnection = UserInputService.InputChanged:Connect(function(input)
		if not activeListInput then
			return
		end

		local currentY = nil

		if activeListInput.UserInputType == Enum.UserInputType.Touch then
			if input ~= activeListInput then
				return
			end
			currentY = input.Position.Y
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			currentY = input.Position.Y
		end

		if currentY == nil then
			return
		end

		setCanvasY(
			listDragStartCanvasY
			- (currentY - listDragStartY)
		)
	end)

	controller.listDragEndedConnection = UserInputService.InputEnded:Connect(function(input)
		if input == activeListInput
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeListInput = nil
		end
	end)

	-- Drag the blue scrollbar thumb.
	local activeThumbInput = nil
	local thumbDragStartY = 0
	local thumbDragStartCanvasY = 0

	scrollbarThumb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			activeThumbInput = input
			thumbDragStartY = input.Position.Y
			thumbDragStartCanvasY = list.CanvasPosition.Y
		end
	end)

	controller.thumbDragChangedConnection = UserInputService.InputChanged:Connect(function(input)
		if not activeThumbInput then
			return
		end

		local currentY = nil

		if activeThumbInput.UserInputType == Enum.UserInputType.Touch then
			if input ~= activeThumbInput then
				return
			end
			currentY = input.Position.Y
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			currentY = input.Position.Y
		end

		if currentY == nil then
			return
		end

		local trackHeight = math.max(1, scrollbarTrack.AbsoluteSize.Y)
		local thumbHeight = math.max(1, scrollbarThumb.AbsoluteSize.Y)
		local maxThumbTravel = math.max(1, trackHeight - thumbHeight)

		setCanvasY(
			thumbDragStartCanvasY
				+ (
					(currentY - thumbDragStartY)
					/ maxThumbTravel
					* getMaxCanvasY()
				)
		)
	end)

	controller.thumbDragEndedConnection = UserInputService.InputEnded:Connect(function(input)
		if input == activeThumbInput
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeThumbInput = nil
		end
	end)

	-- Clicking the scrollbar track jumps directly to that part of the list.
	scrollbarTrack.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local localY = input.Position.Y - scrollbarTrack.AbsolutePosition.Y
		local ratio = math.clamp(
			localY / math.max(1, scrollbarTrack.AbsoluteSize.Y),
			0,
			1
		)

		setCanvasY(getMaxCanvasY() * ratio)
	end)

	local function refreshStateFromServer()
		local success, result = pcall(function()
			return getState:InvokeServer()
		end)

		if success and type(result) == "table" then
			controller.state = result
			controller:Render()
		end
	end

	controller.refreshStateFromServer = refreshStateFromServer

	function controller:SetState(newState)
		self.state = newState

		if self.root.Visible then
			self:Render()
		end
	end

	function controller:GetPeriod()
		local questTable = getQuestTable(self.state)
		return questTable and questTable[self.activePeriod] or nil
	end

	function controller:UpdateTabs()
		for _, periodName in ipairs(PERIODS) do
			local selected = periodName == self.activePeriod
			local button = self.tabButtons[periodName]
			local label = self.tabLabels[periodName]
			local tint = self.tabTints[periodName]

			setArtworkColor(
				button,
				selected
					and Color3.fromRGB(255, 255, 255)
					or Color3.fromRGB(150, 155, 165)
			)

			if tint then
				tint.Visible = selected
			end

			label.TextColor3 = selected
				and Color3.fromRGB(255, 255, 255)
				or Color3.fromRGB(225, 225, 228)

			label.TextStrokeTransparency = selected and 0.08 or 0.28
		end
	end

	function controller:UpdateHeader()
		local period = self:GetPeriod()
		local quests = period and period.quests or {}

		local completedCount = 0
		local visibleQuestCount = 0
		for _, quest in ipairs(quests) do
			if self.activePeriod ~= "Daily" or quest.claimed ~= true then
				visibleQuestCount += 1
				if quest.completed == true
					or (tonumber(quest.progress) or 0) >= math.max(1, tonumber(quest.target) or 1) then
					completedCount += 1
				end
			end
		end

		self.headerTitle.Text = PERIOD_TITLES[self.activePeriod]
		self.completedText.Text = string.format(
			"%d/%d complete",
			completedCount,
			visibleQuestCount
		)
	end

	function controller:UpdateTimer()
		local now = DateTime.now().UnixTimestamp
		local resetAt = getNextResetTimestamp(self.activePeriod, now)
		local remaining = resetAt - now

		self.timerText.Text = formatRemainingTime(remaining)

		if remaining <= 0 and os.clock() - self.lastResetRefreshAt > 2 then
			self.lastResetRefreshAt = os.clock()
			task.defer(refreshStateFromServer)
		end
	end

	function controller:ClearCards()
		for _, child in ipairs(self.list:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	function controller:MakeRewardBox(card, x, iconKey, value, suffix)
		local rewardBox = makeImage(
			card,
			iconKey .. "RewardBox",
			ASSETS.RewardBox,
			UDim2.fromOffset(x, 134),
			UDim2.fromOffset(132, 70),
			204,
			CROPS.RewardBox
		)

		local icon = makeImage(
			rewardBox,
			"Icon",
			ASSETS[iconKey],
			UDim2.fromOffset(8, 10),
			UDim2.fromOffset(46, 48),
			206,
			CROPS[iconKey]
		)

		local valueText = makeText(
			rewardBox,
			"Value",
			tostring(math.floor(tonumber(value) or 0)),
			29,
			Color3.fromRGB(255, 255, 255)
		)
		valueText.Position = UDim2.fromOffset(54, 4)
		valueText.Size = UDim2.fromOffset(72, suffix and 34 or 60)
		valueText.TextXAlignment = Enum.TextXAlignment.Center
		valueText.ZIndex = 207

		if suffix then
			local suffixText = makeText(
				rewardBox,
				"Suffix",
				suffix,
				20,
				Color3.fromRGB(120, 216, 255),
				Enum.Font.GothamBold
			)
			suffixText.Position = UDim2.fromOffset(54, 35)
			suffixText.Size = UDim2.fromOffset(72, 24)
			suffixText.TextXAlignment = Enum.TextXAlignment.Center
			suffixText.TextStrokeTransparency = 0.15
			suffixText.ZIndex = 207
		end
	end

	function controller:MakeQuestCard(quest, index, period)
		local card = makeImage(
			self.list,
			"QuestCard_" .. tostring(quest.id or index),
			ASSETS.QuestCard,
			UDim2.fromOffset(0, 0),
			UDim2.fromOffset(LIST_WIDTH, CARD_HEIGHT),
			200
		)
		card.LayoutOrder = index

		local iconKey = getObjectiveIconKey(quest, index)
		local icon = makeImage(
			card,
			"QuestIcon",
			ASSETS[iconKey],
			UDim2.fromOffset(24, 26),
			UDim2.fromOffset(166, 166),
			203,
			CROPS[iconKey]
		)

		local title = makeText(
			card,
			"QuestTitle",
			quest.title or "Quest",
			38,
			Color3.fromRGB(255, 255, 255)
		)
		title.Position = UDim2.fromOffset(220, 24)
		title.Size = UDim2.fromOffset(535, 52)
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.ZIndex = 204

		local description = makeText(
			card,
			"QuestDescription",
			quest.description or "",
			25,
			Color3.fromRGB(78, 205, 255),
			Enum.Font.GothamBold
		)
		description.Position = UDim2.fromOffset(220, 74)
		description.Size = UDim2.fromOffset(535, 52)
		description.TextWrapped = true
		description.TextStrokeTransparency = 0.4
		description.ZIndex = 204

		local target = math.max(1, math.floor(tonumber(quest.target) or 1))
		local progress = math.clamp(
			math.floor(tonumber(quest.progress) or 0),
			0,
			target
		)
		local complete = quest.completed == true or progress >= target

		local track = makeImage(
			card,
			"ProgressTrack",
			ASSETS.ProgressTrack,
			UDim2.fromOffset(220, 145),
			UDim2.fromOffset(516, 52),
			203
		)
		track.ClipsDescendants = true

		local fillHolder = Instance.new("Frame")
		fillHolder.Name = "FillHolder"
		fillHolder.BackgroundTransparency = 1
		fillHolder.Position = UDim2.fromOffset(4, 4)
		fillHolder.Size = UDim2.new(1, -8, 1, -8)
		fillHolder.ClipsDescendants = true
		fillHolder.ZIndex = 204
		fillHolder.Parent = track
		addCorner(fillHolder, 20)

		local ratio = math.clamp(progress / target, 0, 1)

		if complete then
			local greenFill = makeImage(
				fillHolder,
				"GreenFill",
				ASSETS.ProgressGreenFill,
				UDim2.fromOffset(0, 0),
				UDim2.fromScale(1, 1),
				204
			)
		else
			local blueFill = Instance.new("Frame")
			blueFill.Name = "BlueFill"
			blueFill.BackgroundColor3 = Color3.fromRGB(0, 139, 255)
			blueFill.BorderSizePixel = 0
			blueFill.Size = UDim2.new(ratio, 0, 1, 0)
			blueFill.ZIndex = 204
			blueFill.Parent = fillHolder
			addCorner(blueFill, 20)

			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 221, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 106, 255)),
			})
			gradient.Rotation = 90
			gradient.Parent = blueFill
		end

		local progressText = makeText(
			track,
			"ProgressText",
			string.format("%d/%d", progress, target),
			31,
			Color3.fromRGB(255, 255, 255)
		)
		progressText.Size = UDim2.fromScale(1, 1)
		progressText.TextXAlignment = Enum.TextXAlignment.Center
		progressText.TextStrokeTransparency = 0
		progressText.ZIndex = 206

		local statusImage = complete and ASSETS.StatusGreen or ASSETS.StatusBlue
		local status = makeImage(
			card,
			"StatusBadge",
			statusImage,
			UDim2.fromOffset(785, 24),
			UDim2.fromOffset(261, 62),
			203
		)

		local statusLabel = makeText(
			status,
			"StatusText",
			complete and "✓  Completed" or "In Progress",
			28,
			complete
				and Color3.fromRGB(85, 255, 35)
				or Color3.fromRGB(0, 224, 255),
			Enum.Font.GothamBold
		)
		statusLabel.Size = UDim2.fromScale(1, 1)
		statusLabel.TextXAlignment = Enum.TextXAlignment.Center
		statusLabel.TextStrokeTransparency = 0.15
		statusLabel.ZIndex = 205

		local rewardsLabel = makeText(
			card,
			"RewardsLabel",
			"Rewards",
			25,
			Color3.fromRGB(72, 210, 255),
			Enum.Font.GothamBold
		)
		rewardsLabel.Position = UDim2.fromOffset(785, 96)
		rewardsLabel.Size = UDim2.fromOffset(250, 34)
		rewardsLabel.TextStrokeTransparency = 0.35
		rewardsLabel.ZIndex = 204

		local reward = quest.reward or {}
		self:MakeRewardBox(
			card,
			785,
			"MoneyIcon",
			reward.coins or 0,
			nil
		)
		self:MakeRewardBox(
			card,
			925,
			"XPIcon",
			reward.xp or 0,
			"XP"
		)

		if complete
			and not quest.claimed
			and AUTO_CLAIM_COMPLETED_QUESTS then
			local periodKey = period and period.periodKey or "unknown"
			local claimKey = table.concat({
				self.activePeriod,
				tostring(periodKey),
				tostring(quest.id),
			}, ":")

			if not self.claimRequests[claimKey] then
				self.claimRequests[claimKey] = true

				task.delay(0.25, function()
					questAction:FireServer(
						"Claim",
						self.activePeriod,
						quest.id
					)
				end)

				task.delay(5, function()
					self.claimRequests[claimKey] = nil
				end)
			end
		end

		return card
	end

	function controller:RenderCards()
		self:ClearCards()

		local period = self:GetPeriod()
		local quests = period and period.quests or {}
		local visibleQuests = {}

		for _, quest in ipairs(quests) do
			if self.activePeriod ~= "Daily" or quest.claimed ~= true then
				table.insert(visibleQuests, quest)
			end
		end

		if #visibleQuests == 0 then
			local empty = makeText(
				self.list,
				"EmptyText",
				self.activePeriod == "Daily"
					and "All Daily quest rewards claimed. New quests arrive after reset."
					or "Loading quests...",
				34,
				Color3.fromRGB(220, 235, 255)
			)
			empty.Size = UDim2.fromOffset(LIST_WIDTH, 100)
			empty.TextXAlignment = Enum.TextXAlignment.Center
			empty.LayoutOrder = 1
			self.updateCanvasForQuestCount(1)
			return
		end

		for index, quest in ipairs(visibleQuests) do
			self:MakeQuestCard(quest, index, period)
		end

		self.updateCanvasForQuestCount(#visibleQuests)
	end

	function controller:Render()
		if not self.root.Parent then
			return
		end

		self:UpdateTabs()
		self:UpdateHeader()
		self:UpdateTimer()
		self:RenderCards()
	end

	function controller:SetVisible(visible)
		visible = visible == true
		self.root.Visible = visible
		self.setQuestBlurVisible(visible)

		-- The game's custom hotbar is used instead of Roblox's default Backpack UI.
		-- Keep CoreGui Backpack disabled both while opening and closing Quest UI.
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)

		self.backpackWasEnabled = false

		if visible then
			self.startLegacyQuestSuppression()

			self:Render()
			task.defer(self.updateScrollbar)
		else
			restoreLegacyQuestUi(self.hiddenLegacyQuestGuis)
		end
	end

	function controller:IsVisible()
		return self.root.Visible
	end

	function controller:Destroy()
		self.stopLegacyQuestSuppression()

		if self.blurTween then
			self.blurTween:Cancel()
			self.blurTween = nil
		end

		if self.questBlur then
			self.questBlur.Size = 0
			self.questBlur.Enabled = false
		end

		-- Never restore Roblox's default Backpack UI.
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		self.backpackWasEnabled = false

		restoreLegacyQuestUi(self.hiddenLegacyQuestGuis)

		if self.stateConnection then
			self.stateConnection:Disconnect()
		end

		if self.timerConnection then
			self.timerConnection:Disconnect()
		end

		if self.viewportConnection then
			self.viewportConnection:Disconnect()
		end

		if self.listDragChangedConnection then
			self.listDragChangedConnection:Disconnect()
		end

		if self.listDragEndedConnection then
			self.listDragEndedConnection:Disconnect()
		end

		if self.thumbDragChangedConnection then
			self.thumbDragChangedConnection:Disconnect()
		end

		if self.thumbDragEndedConnection then
			self.thumbDragEndedConnection:Disconnect()
		end

		if self.root then
			self.root:Destroy()
		end
	end

	controller.stateConnection = stateUpdated.OnClientEvent:Connect(function(newState)
		controller.state = newState

		if controller.root.Visible then
			controller:Render()
		end
	end)

	controller.timerConnection = RunService.RenderStepped:Connect(function()
		if not controller.root.Visible then
			return
		end

		controller.clockHand.Rotation = (os.clock() * 120) % 360

		local second = math.floor(os.clock())
		if controller.lastTimerSecond ~= second then
			controller.lastTimerSecond = second
			controller:UpdateTimer()
		end
	end)

	task.spawn(refreshStateFromServer)

	return controller
end

return QuestModernUI
