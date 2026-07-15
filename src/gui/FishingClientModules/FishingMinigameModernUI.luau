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

function MinigameController.run(ctx, prompt)
	local ui = ctx.ui
	local state = ctx.state
	local getBaitData = ctx.BaitUtils.getBaitData
	local getBaitCountText = ctx.BaitUtils.getBaitCountText

	if ctx.minigameRunning then
		return
	end

	local custom = ensureUi(ctx)

	local isAutoFish = prompt.autoFish == true
	local fish = prompt.fish or {}
	local promptBait = prompt.bait or {}
	local promptBaitId = promptBait.id or (state and state.EquippedBait) or ctx.GameConfig.BasicBaitId
	local promptBaitData = getBaitData(promptBaitId)
	local promptBaitName = promptBait.name or promptBaitData.displayName
	local castDisplay = prompt.cast and prompt.cast.displayName or nil

	local minigameConfig = prompt.minigame or ctx.GameConfig.getFishingMinigameConfig(fish.rarity or "Common", state and state.EquippedRod or "WoodenRod")
	local difficulty = minigameConfig.difficulty or ctx.GameConfig.FishingMinigame.RarityDifficulty.Common
	local random = Random.new(math.floor((os.clock() * 100000) % 2147483647))

	ctx.minigameRunning = true
	ctx.fishingBusy = true

	if ctx.CastPower then
		ctx.CastPower.running = false
		ctx.CastPower.activeConfig = nil
		if ctx.CastPower.content then
			ctx.CastPower.content.Visible = false
		end
	end

	if ui.minigame then
		ui.minigame.Visible = false
	end

	if ctx.fishingBlur then
		ctx.fishingBlur.Enabled = true
		ctx.fishingBlur.Size = 10
	end

	custom.panel.Visible = true
	setFishingBarsVisible(ctx, false)

	custom.headerText.Text = isAutoFish and "AutoFish is waiting..." or "Waiting for a bite..."
	custom.statusText.Text = "Something is biting..."
	custom.progressText.Text = "Progress --"
	custom.baitText.Text = string.format('<font color="#38D9FF">Bait:</font> %s (%s)', promptBaitName, getBaitCountText(promptBaitId, promptBait.remaining))
	custom.castText.Text = castDisplay and string.format('<font color="#38D9FF">Cast:</font> %s', castDisplay) or '<font color="#38D9FF">Cast:</font> --'
	custom.instructionText.Text = isAutoFish and "AutoFish is handling this catch." or "Hold mouse, tap, or Space to lift the green bar. Release to let it fall."
	custom.progressFill.Size = UDim2.fromScale(0.58, 0)
	custom.fishImage.Image = getFishImage(ctx, fish)

	local hideBarsConnection = ctx.RunService.RenderStepped:Connect(function()
		if ctx.minigameRunning and custom.panel.Visible then
			setFishingBarsVisible(ctx, false)
			if ui.minigame then
				ui.minigame.Visible = false
			end
		end
	end)

	task.wait(tonumber(prompt.biteDelay) or 0)

	if not ctx.minigameRunning then
		if hideBarsConnection then
			hideBarsConnection:Disconnect()
		end
		custom.panel.Visible = false
		return
	end

	local barSize = math.clamp(tonumber(minigameConfig.barSize) or 0.24, 0.16, 0.52)
	local CATCH_TOP_LIMIT = 0.055
	local CATCH_BOTTOM_LIMIT = 0.925
	local maxBarTop = CATCH_BOTTOM_LIMIT - barSize
	local barTop = math.clamp(0.610, CATCH_TOP_LIMIT, maxBarTop)
	local barVelocity = 0

	local fishY = random:NextNumber(0.20, 0.80)
	local fishTarget = random:NextNumber(0.15, 0.85)
	local fishVelocity = 0

	local progress = math.clamp(tonumber(minigameConfig.startProgress) or 0.34, 0.08, 0.86)
	local minSuccessDuration = tonumber(minigameConfig.minSuccessDuration) or 1.75
	local maxDuration = tonumber(minigameConfig.maxDuration) or 35
	local gameStartedAt = os.clock()
	local nextDecisionAt = gameStartedAt + random:NextNumber(difficulty.turnIntervalMin or 1, difficulty.turnIntervalMax or 2)
	local pauseUntil = 0
	local burstUntil = 0
	local holding = false
	local finished = false

	custom.catchBar.Size = UDim2.fromScale(0.82, barSize)
	custom.catchBar.Position = UDim2.fromScale(0.5, barTop)
	custom.fishMarker.Position = UDim2.fromScale(0.5, fishY)
	custom.progressFill.Size = UDim2.fromScale(0.58, progress)

	-- When the fish actually bites, change the top instruction.
	custom.headerText.Text = isAutoFish and "AutoFish is reeling..." or "Keep the fish inside the green bar!"
	custom.statusText.Text = "Something is biting..."
	custom.progressText.Text = string.format("Progress %d%%", math.floor(progress * 100 + 0.5))

	local renderConnection
	local inputBeganConnection
	local inputEndedConnection

	local function disconnectAll()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		if inputBeganConnection then
			inputBeganConnection:Disconnect()
			inputBeganConnection = nil
		end
		if inputEndedConnection then
			inputEndedConnection:Disconnect()
			inputEndedConnection = nil
		end
		if hideBarsConnection then
			hideBarsConnection:Disconnect()
			hideBarsConnection = nil
		end
	end

	ctx.activeMinigameCleanup = disconnectAll

	local function finish(success)
		if finished then
			return
		end

		finished = true
		disconnectAll()
		ctx.activeMinigameCleanup = nil

		custom.panel.Visible = false
		ctx.minigameRunning = false
		ctx.fishingBusy = false

		if ctx.fishingBlur then
			ctx.fishingBlur.Enabled = false
			ctx.fishingBlur.Size = 0
		end

		if not isAutoFish then
			ctx.Remotes.FinishMinigame:FireServer({
				success = success == true,
				sessionId = prompt.sessionId,
			})
		end

		if ctx.renderContent then
			ctx.renderContent()
		else
			setFishingBarsVisible(ctx, true)
		end
	end

	local function isCatchInput(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.Space
	end

	if not isAutoFish then
		inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if isCatchInput(input) then
				holding = true
			end
		end)

		inputEndedConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
			if isCatchInput(input) then
				holding = false
			end
		end)
	end

	local function chooseFishTarget(fromY, preferFarTarget)
		if preferFarTarget then
			local jumpMin = tonumber(difficulty.jumpMin) or 0.12
			local jumpMax = math.max(jumpMin, tonumber(difficulty.jumpMax) or jumpMin)
			local direction = random:NextInteger(0, 1) == 0 and -1 or 1
			local distance = random:NextNumber(jumpMin, jumpMax)
			local target = fromY + (direction * distance)

			if target < 0.08 or target > 0.92 then
				target = fromY - (direction * distance)
			end

			return math.clamp(target, 0.08, 0.92)
		end

		return random:NextNumber(0.08, 0.92)
	end

	renderConnection = ctx.RunService.RenderStepped:Connect(function(deltaTime)
		if not ctx.minigameRunning or finished then
			return
		end

		setFishingBarsVisible(ctx, false)

		local now = os.clock()
		local elapsed = now - gameStartedAt

		if now >= nextDecisionAt then
			local pauseChance = difficulty.pauseChance or 0
			local jumpChance = difficulty.jumpChance or 0
			local burstChance = difficulty.burstChance or 0

			fishTarget = chooseFishTarget(fishY, jumpChance > 0 and random:NextNumber() < jumpChance)

			if pauseChance > 0 and random:NextNumber() < pauseChance then
				pauseUntil = now + random:NextNumber(difficulty.pauseMin or 0.12, difficulty.pauseMax or 0.45)
			end

			if burstChance > 0 and random:NextNumber() < burstChance then
				burstUntil = now + random:NextNumber(difficulty.burstMin or 0.18, difficulty.burstMax or 0.38)
			end

			nextDecisionAt = now + random:NextNumber(difficulty.turnIntervalMin or 1, difficulty.turnIntervalMax or 2)
		end

		local targetVelocity = 0
		if now >= pauseUntil then
			local distance = fishTarget - fishY
			local targetSlack = tonumber(difficulty.targetSlack) or 0.025
			if math.abs(distance) < targetSlack then
				fishTarget = chooseFishTarget(fishY, false)
				distance = fishTarget - fishY
			end

			local direction = distance >= 0 and 1 or -1
			local jitter = random:NextNumber(-(difficulty.jitter or 0), difficulty.jitter or 0)
			local speed = tonumber(difficulty.moveSpeed) or 0.25
			if now < burstUntil then
				speed *= tonumber(difficulty.burstMultiplier) or 1.35
			end

			targetVelocity = (direction * speed) + jitter
		end

		local acceleration = tonumber(difficulty.acceleration) or 6
		local velocityBlend = math.min(1, acceleration * deltaTime)
		fishVelocity += (targetVelocity - fishVelocity) * velocityBlend
		fishY += fishVelocity * deltaTime

		if fishY <= 0.04 then
			fishY = 0.075
			fishVelocity = math.abs(fishVelocity) * 0.35
			fishTarget = math.max(fishTarget, 0.16)
		elseif fishY >= 0.96 then
			fishY = 0.925
			fishVelocity = -math.abs(fishVelocity) * 0.35
			fishTarget = math.min(fishTarget, 0.84)
		end

		if isAutoFish then
			local targetTop = math.clamp(fishY - (barSize / 2), CATCH_TOP_LIMIT, maxBarTop)
			barTop += (targetTop - barTop) * math.min(1, deltaTime * 5)
			progress = math.clamp(progress + (minigameConfig.progressGainPerSecond or 0.34) * deltaTime, 0, 1)
		else
			local barAcceleration = holding and -(minigameConfig.lift or 2.75) or (minigameConfig.gravity or 1.8)
			barVelocity += barAcceleration * deltaTime
			barVelocity = math.clamp(barVelocity, -(minigameConfig.maxBarVelocity or 1.65), minigameConfig.maxBarVelocity or 1.65)
			barVelocity *= math.pow(minigameConfig.damping or 0.90, deltaTime * 60)
			barTop += barVelocity * deltaTime

			if barTop <= CATCH_TOP_LIMIT then
				barTop = CATCH_TOP_LIMIT
				barVelocity = math.abs(barVelocity) * (minigameConfig.bounceDamping or 0.36)
			elseif barTop >= maxBarTop then
				barTop = maxBarTop
				barVelocity = -math.abs(barVelocity) * (minigameConfig.bounceDamping or 0.36)
			end

			local fishInsideBar = fishY >= barTop and fishY <= barTop + barSize
			if fishInsideBar then
				progress += (minigameConfig.progressGainPerSecond or 0.34) * deltaTime
			else
				progress -= (minigameConfig.progressDrainPerSecond or 0.16) * deltaTime
			end
			progress = math.clamp(progress, 0, 1)
		end

		custom.catchBar.Position = UDim2.fromScale(0.5, barTop)
		custom.fishMarker.Position = UDim2.fromScale(0.5, fishY)
		custom.progressFill.Size = UDim2.fromScale(0.58, progress)
		custom.progressText.Text = string.format("Progress %d%%", math.floor(progress * 100 + 0.5))

		if isAutoFish and elapsed >= (prompt.visualTime or 3) then
			custom.headerText.Text = "AutoFish caught it!"
			finish(true)
		elseif not isAutoFish and progress >= 1 and elapsed >= minSuccessDuration then
			custom.headerText.Text = "Caught!"
			finish(true)
		elseif not isAutoFish and progress <= 0 then
			custom.headerText.Text = "The fish escaped!"
			finish(false)
		elseif not isAutoFish and elapsed >= maxDuration then
			custom.headerText.Text = "The fish escaped!"
			finish(false)
		end
	end)
end

return MinigameController


