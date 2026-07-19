-- QuestModernUI
-- ModuleScript location:
-- StarterGui > FishingGui > FishingClient > QuestModernUI
--
-- This module binds the authored Daily / Weekly / Monthly quest UI.
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
	MainWindow = "rbxassetid://75381184130055",
	HeaderPanel = "rbxassetid://139422887890221",
	QuestCard = "rbxassetid://93889386487602",

	-- Exact tab artwork supplied by the user.
	TabNormal = "rbxassetid://101135473927300",
	TabSelected = "rbxassetid://106120450577925",
	DailyWeeklyTabIcon = "rbxassetid://86912435019607",
	MonthlyTabIcon = "rbxassetid://78189475055056",

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

	-- The supplied scrollbar image contains both track and thumb artwork.
	Scrollbar = "rbxassetid://73367138577137",

	StatusBlue = "rbxassetid://96566593336613",
	StatusGreen = "rbxassetid://109147124391851",

	MoneyIcon = "rbxassetid://133418085425740",
	XPIcon = "rbxassetid://102202681165196",
}

-- These source rectangles remove the transparent padding from the
-- original uploaded images. Do not change these unless the source
-- PNG files are re-uploaded with different dimensions.
local DEFAULT_SOURCE_CANVAS_SIZE = Vector2.new(1187, 1326)
local TAB_SOURCE_CANVAS_SIZE = Vector2.new(1448, 1086)
local PANEL_SOURCE_CANVAS_SIZE = Vector2.new(1672, 941)
local SCROLLBAR_SOURCE_CANVAS_SIZE = Vector2.new(1448, 1086)
local SCROLLBAR_TRACK_X = 1122
local SCROLLBAR_THUMB_X = 1129

local CROPS = {
	HeaderPanel = {
		canvas = PANEL_SOURCE_CANVAS_SIZE,
		offset = Vector2.new(22, 279),
		size = Vector2.new(1628, 376),
	},
	QuestCard = {
		canvas = PANEL_SOURCE_CANVAS_SIZE,
		offset = Vector2.new(14, 218),
		size = Vector2.new(1650, 466),
	},

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
	-- IMPORTANT: use the original tab assets directly with no crop.
	-- The previous crop rectangles were cutting off the rounded ends,
	-- which is why the tabs looked like squared rectangles.
	TabNormal = nil,
	TabSelected = nil,
	ScrollbarTrack = {
		canvas = SCROLLBAR_SOURCE_CANVAS_SIZE,
		offset = Vector2.new(683, 29),
		size = Vector2.new(65, 1021),
	},
	ScrollbarThumb = {
		canvas = SCROLLBAR_SOURCE_CANVAS_SIZE,
		offset = Vector2.new(701, 77),
		size = Vector2.new(30, 825),
	},
	ScrollbarChannel = {
		canvas = SCROLLBAR_SOURCE_CANVAS_SIZE,
		offset = Vector2.new(701, 914),
		size = Vector2.new(30, 90),
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
-- Exact recovered v1615 post-fit scale. Keeping this in the behavior module
-- makes the authored Explorer panel and the original runtime presentation use
-- the same responsive size on every viewport.
local QUEST_UI_SIZE_MULTIPLIER = 0.72

-- Keep the quest cards below the lowered header panel.
local LIST_Y = 382
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

local function requireChild(parent, name, className)
	local child = parent:FindFirstChild(name)
	assert(child, string.format("Quest authored node %s.%s is missing", parent:GetFullName(), name))
	assert(
		child:IsA(className),
		string.format(
			"Quest authored node %s.%s must be %s, got %s",
			parent:GetFullName(),
			name,
			className,
			child.ClassName
		)
	)
	return child
end

local function cloneTemplate(templates, name, className)
	local template = requireChild(templates, name, className)
	return template:Clone()
end

local function makeText(parent, name, text, textSize, color, font)
	local label = requireChild(parent, name, "TextLabel")
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
	label.Visible = true
	return label
end

local function makeArtwork(parent, imageId, zIndex, crop)
	local artwork = requireChild(parent, "Artwork", "ImageLabel")
	artwork.BackgroundTransparency = 1
	artwork.BorderSizePixel = 0
	artwork.Image = imageId
	artwork.ScaleType = Enum.ScaleType.Stretch
	artwork.ZIndex = zIndex or 200
	artwork.Visible = true

	if crop then
		-- Crop by normalized layout. Each asset can provide its real source
		-- canvas size, so tab/scrollbar images are not clipped with the old
		-- 1187 x 1326 coordinates.
		local canvas = crop.canvas or DEFAULT_SOURCE_CANVAS_SIZE
		artwork.Position = UDim2.fromScale(
			-crop.offset.X / crop.size.X,
			-crop.offset.Y / crop.size.Y
		)
		artwork.Size = UDim2.fromScale(
			canvas.X / crop.size.X,
			canvas.Y / crop.size.Y
		)
	else
		artwork.Position = UDim2.fromScale(0, 0)
		artwork.Size = UDim2.fromScale(1, 1)
	end

	return artwork
end

local function applyArtworkCrop(artwork, imageId, crop)
	if not artwork then
		return
	end

	artwork.Image = imageId
	artwork.ImageColor3 = Color3.new(1, 1, 1)
	artwork.ImageTransparency = 0
	artwork.ScaleType = Enum.ScaleType.Stretch

	if crop then
		local canvas = crop.canvas or DEFAULT_SOURCE_CANVAS_SIZE
		artwork.Position = UDim2.fromScale(
			-crop.offset.X / crop.size.X,
			-crop.offset.Y / crop.size.Y
		)
		artwork.Size = UDim2.fromScale(
			canvas.X / crop.size.X,
			canvas.Y / crop.size.Y
		)
	else
		artwork.Position = UDim2.fromScale(0, 0)
		artwork.Size = UDim2.fromScale(1, 1)
	end
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
	local holder = requireChild(parent, name, "Frame")
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Position = position
	holder.Size = size
	holder.ClipsDescendants = crop ~= nil
	holder.ZIndex = zIndex or 200
	holder.Visible = true

	makeArtwork(holder, imageId, zIndex or 200, crop)
	return holder
end

local function addPressFeedback(button, bind)
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

	bind(button.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			tweenTo(true)
		end
	end)

	bind(button.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			tweenTo(false)
		end
	end)

	bind(button.MouseLeave, function()
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
			guiObject.Visible = false
		end
		store[guiObject] = nil
	end
end

function QuestModernUI.create(config)
	assert(type(config) == "table", "QuestModernUI.create requires a config table")
	assert(config.parent, "QuestModernUI.create requires config.parent")

	if QuestModernUI.activeController
		and QuestModernUI.activeController.root
		and QuestModernUI.activeController.root.Parent
	then
		return QuestModernUI.activeController
	end

	local player = Players.LocalPlayer
	local remotes = config.remotes
		or ReplicatedStorage:WaitForChild("FishingRemotes")

	local stateUpdated = remotes:WaitForChild("StateUpdated")
	local getState = remotes:WaitForChild("GetState")
	local questAction = remotes:WaitForChild("QuestAction")

	local controller = {
		activePeriod = "Daily",
		state = config.initialState,
		claimRequests = {},
		lastResetRefreshAt = 0,
		backpackWasEnabled = false,
		hiddenLegacyQuestGuis = {},
		blurTween = nil,
		legacySuppressConnection = nil,
		legacySuppressElapsed = 0,
		authoredUi = config.authoredUi == true,
		boundConnections = {},
	}

	local function bind(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(controller.boundConnections, connection)
		return connection
	end

	-- Keep the old Roblox Backpack / inventory hotbar hidden permanently.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	assert(controller.authoredUi, "QuestModernUI requires the authored StarterGui hierarchy")
	local authoredHost = requireChild(config.parent, "ModernQuestUI", "Frame")
	local overlay = requireChild(authoredHost, "QuestCanvas", "Frame")
	local templates = requireChild(authoredHost, "Templates", "Folder")
	controller.root = overlay
	controller.host = authoredHost
	controller.templates = templates
	controller.root.Visible = false
	controller.host.Visible = false

	local questBlur = Lighting:FindFirstChild("FishyFishQuestUiBlur")
	if not questBlur then
		questBlur = requireChild(authoredHost, "FishyFishQuestUiBlur", "BlurEffect")
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

	local function stopLegacyQuestSuppression()
		if controller.legacySuppressConnection then
			controller.legacySuppressConnection:Disconnect()
			controller.legacySuppressConnection = nil
		end
		controller.legacySuppressElapsed = 0
	end

	local function startLegacyQuestSuppression()
		stopLegacyQuestSuppression()
		if controller.authoredUi then
			return
		end

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

	local scale = requireChild(overlay, "ResponsiveScale", "UIScale")
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

	local background = requireChild(overlay, "MainWindow", "Frame")
	controller.background = background

	-- Tabs
	-- The actual selected/unselected images are created here in QuestModernUI.
	-- QuestModernClient no longer paints any rectangles over these buttons.
	controller.tabButtons = {}
	controller.tabLabels = {}
	controller.tabArtworks = {}
	controller.tabVisualHolders = {}

	for _, periodName in ipairs(PERIODS) do
		local button = requireChild(overlay, periodName .. "Tab", "ImageButton")
		local visualHolder = requireChild(button, "TabVisual", "Frame")
		local artwork = requireChild(visualHolder, "Artwork", "ImageLabel")
		local label = requireChild(button, "Label", "TextLabel")
		label.TextSize = 40
		requireChild(button, periodName .. "Icon", "ImageLabel")

		bind(button.MouseButton1Click, function()
			controller.activePeriod = periodName
			controller.list.CanvasPosition = Vector2.zero
			controller:Render()
		end)

		controller.tabButtons[periodName] = button
		controller.tabLabels[periodName] = label
		controller.tabArtworks[periodName] = artwork
		controller.tabVisualHolders[periodName] = visualHolder
	end

	local closeButton = requireChild(overlay, "CloseButton", "ImageButton")
	addPressFeedback(closeButton, bind)
	controller.closeButton = closeButton

	bind(closeButton.MouseButton1Click, function()
		controller:SetVisible(false)

		if config.onClose then
			config.onClose()
		end
	end)

	-- Header
	local header = requireChild(overlay, "HeaderPanel", "Frame")
	controller.header = header

	local headerTitle = requireChild(header, "HeaderTitle", "TextLabel")
	controller.headerTitle = headerTitle

	local completedText = requireChild(header, "CompletedText", "TextLabel")
	completedText.TextSize = 30
	controller.completedText = completedText

	local separator = requireChild(header, "Separator", "TextLabel")
	separator.Position = UDim2.fromOffset(215, 103)
	local resetText = requireChild(header, "ResetText", "TextLabel")
	resetText.Position = UDim2.fromOffset(240, 103)
	resetText.TextSize = 26

	local clockHolder = requireChild(header, "Clock", "Frame")
	clockHolder.Position = UDim2.fromOffset(540, 105)
	controller.clockHolder = clockHolder

	requireChild(clockHolder, "ClockCircle", "Frame")
	local clockHand = requireChild(clockHolder, "ClockHand", "Frame")
	requireChild(clockHand, "HandVisual", "Frame")
	controller.clockHand = clockHand

	requireChild(clockHolder, "ClockCenter", "Frame")

	local timerText = requireChild(header, "TimerText", "TextLabel")
	timerText.Position = UDim2.fromOffset(590, 103)
	timerText.TextSize = 29
	controller.timerText = timerText

	requireChild(header, "HeaderDecoration", "Frame")

	-- Scroll area
	local list = requireChild(overlay, "QuestList", "ScrollingFrame")
	-- The previous UI used only the supplied custom scrollbar artwork. Keep the
	-- native Roblox bar disabled in both the authored model and at runtime.
	list.ScrollBarThickness = 0
	list.ScrollBarImageTransparency = 1
	list.VerticalScrollBarInset = Enum.ScrollBarInset.None
	controller.list = list

	local scrollInputCatcher = requireChild(overlay, "ScrollInputCatcher", "TextButton")
	controller.scrollInputCatcher = scrollInputCatcher

	local listLayout = requireChild(list, "QuestListLayout", "UIListLayout")
	controller.listLayout = listLayout

	-- Custom scrollbar using the supplied image.
	local scrollbarTrack = requireChild(overlay, "ScrollbarTrack", "Frame")
	scrollbarTrack.Position = UDim2.fromOffset(SCROLLBAR_TRACK_X, LIST_Y)
	controller.scrollbarTrack = scrollbarTrack

	-- Cover the sample thumb baked into the full scrollbar artwork.
	local scrollbarChannel = requireChild(scrollbarTrack, "ScrollbarChannel", "Frame")
	controller.scrollbarChannel = scrollbarChannel

	local scrollbarThumb = requireChild(overlay, "ScrollbarThumb", "Frame")
	scrollbarThumb.Position = UDim2.fromOffset(SCROLLBAR_THUMB_X, LIST_Y)
	controller.scrollbarThumb = scrollbarThumb

	-- The thin pale line is actually the clipped right edge of every
	-- QuestCard image, not the scrollbar track. Mask only that 4 px edge.
	local questCardRightEdgeMask = requireChild(overlay, "QuestCardRightEdgeMask", "Frame")
	questCardRightEdgeMask.Visible = true
	controller.questCardRightEdgeMask = questCardRightEdgeMask

	-- Bottom-right decoration.
	-- This asset was supplied separately, so it is used without ImageRect cropping.
	local cornerDecoration = requireChild(overlay, "CornerDecoration", "Frame")
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
			SCROLLBAR_THUMB_X,
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

	bind(listLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		task.defer(updateScrollbar)
	end)

	bind(list:GetPropertyChangedSignal("CanvasPosition"), updateScrollbar)
	bind(list:GetPropertyChangedSignal("AbsoluteWindowSize"), updateScrollbar)

	-- Mouse wheel: the transparent catcher guarantees the event is received
	-- even when the cursor is over a quest card.
	local wheelDirectionMultiplier = nil

	bind(scrollInputCatcher.InputChanged, function(input)
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

	bind(scrollInputCatcher.InputBegan, function(input)
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

	bind(scrollbarThumb.InputBegan, function(input)
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
	bind(scrollbarTrack.InputBegan, function(input)
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
			local artwork = self.tabArtworks[periodName]
			local visualHolder = self.tabVisualHolders[periodName]
			local label = self.tabLabels[periodName]

			visualHolder.Size = UDim2.fromScale(1, 1)
			visualHolder.Position = UDim2.fromScale(0.5, 0.5)
			applyArtworkCrop(
				artwork,
				selected and ASSETS.TabSelected or ASSETS.TabNormal,
				nil
			)
			artwork.Position = UDim2.fromScale(0, 0)
			artwork.Size = UDim2.fromScale(1, 1)
			artwork.ScaleType = Enum.ScaleType.Stretch

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
		for _, quest in ipairs(quests) do
			if quest.completed == true
				or (tonumber(quest.progress) or 0) >= math.max(1, tonumber(quest.target) or 1) then
				completedCount += 1
			end
		end

		self.headerTitle.Text = PERIOD_TITLES[self.activePeriod]
		self.completedText.Text = string.format(
			"%d/%d complete",
			completedCount,
			#quests
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

	function controller:MakeRewardBox(card, x, width, iconKey, value, suffix)
		local rewardBox = makeImage(
			card,
			iconKey .. "RewardBox",
			ASSETS.RewardBox,
			UDim2.fromOffset(x, 134),
			UDim2.fromOffset(width, 70),
			204,
			CROPS.RewardBox
		)

		local icon = makeImage(
			rewardBox,
			"Icon",
			ASSETS[iconKey],
			UDim2.fromOffset(6, 13),
			UDim2.fromOffset(42, 44),
			206,
			CROPS[iconKey]
		)
		local valueWidth = width - 52

		local valueText = makeText(
			rewardBox,
			"Value",
			tostring(math.floor(tonumber(value) or 0)),
			33,
			Color3.fromRGB(255, 255, 255)
		)
		valueText.Position = UDim2.fromOffset(46, suffix and 1 or 4)
		valueText.Size = UDim2.fromOffset(valueWidth, suffix and 38 or 60)
		valueText.TextXAlignment = Enum.TextXAlignment.Center
		valueText.ZIndex = 207

		if suffix then
			local suffixText = makeText(
				rewardBox,
				"Suffix",
				suffix,
				23,
				Color3.fromRGB(120, 216, 255),
				Enum.Font.GothamBold
			)
			suffixText.Position = UDim2.fromOffset(46, 37)
			suffixText.Size = UDim2.fromOffset(valueWidth, 27)
			suffixText.TextXAlignment = Enum.TextXAlignment.Center
			suffixText.TextStrokeTransparency = 0.15
			suffixText.ZIndex = 207
		end
	end

	function controller:MakeQuestCard(quest, index, period)
		local card = cloneTemplate(self.templates, "QuestCardTemplate", "Frame")
		card.Name = "QuestCard_" .. tostring(quest.id or index)
		card.LayoutOrder = index
		card.Visible = true
		card.Parent = self.list

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
			46,
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
			30,
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

		local fillHolder = requireChild(track, "FillHolder", "Frame")
		local greenFill = requireChild(fillHolder, "GreenFill", "Frame")
		local blueFill = requireChild(fillHolder, "BlueFill", "Frame")

		local ratio = math.clamp(progress / target, 0, 1)

		if complete then
			greenFill.Visible = true
			blueFill.Visible = false
		else
			greenFill.Visible = false
			blueFill.Visible = true
			blueFill.Size = UDim2.new(ratio, 0, 1, 0)
		end

		local progressText = makeText(
			track,
			"ProgressText",
			string.format("%d/%d", progress, target),
			36,
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
			32,
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
			29,
			Color3.fromRGB(72, 210, 255),
			Enum.Font.GothamBold
		)
		rewardsLabel.Position = UDim2.fromOffset(770, 96)
		rewardsLabel.Size = UDim2.fromOffset(250, 34)
		rewardsLabel.TextStrokeTransparency = 0.35
		rewardsLabel.ZIndex = 204

		local reward = quest.reward or {}
		self:MakeRewardBox(
			card,
			770,
			157,
			"MoneyIcon",
			reward.coins or 0,
			nil
		)
		self:MakeRewardBox(
			card,
			935,
			122,
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

		if #quests == 0 then
			local empty = cloneTemplate(self.templates, "EmptyQuestTemplate", "TextLabel")
			empty.Name = "EmptyText"
			empty.Visible = true
			empty.Parent = self.list
			self.updateCanvasForQuestCount(1)
			return
		end

		for index, quest in ipairs(quests) do
			self:MakeQuestCard(quest, index, period)
		end

		self.updateCanvasForQuestCount(#quests)
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
		self.host.Visible = visible
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
			self.stopLegacyQuestSuppression()
			restoreLegacyQuestUi(self.hiddenLegacyQuestGuis)
		end
	end

	function controller:IsVisible()
		return self.host.Visible and self.root.Visible
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

		for _, connection in ipairs(self.boundConnections) do
			connection:Disconnect()
		end
		table.clear(self.boundConnections)

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
			self.root.Visible = false
		end
		if self.host then
			self.host.Visible = false
		end
		QuestModernUI.activeController = nil
	end

	if config.manageRemoteState ~= false then
		controller.stateConnection = stateUpdated.OnClientEvent:Connect(function(newState)
			controller:SetState(newState)
		end)
	end

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

	if config.manageRemoteState ~= false then
		task.spawn(refreshStateFromServer)
	end

	print("[QuestModernUI] Header/card margins rebalanced and top tabs enlarged/lowered.")

	QuestModernUI.activeController = controller
	return controller
end

return QuestModernUI
