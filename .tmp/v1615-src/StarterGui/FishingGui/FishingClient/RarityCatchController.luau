local RarityCatchController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FishingSFX = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishingSFX"))

local BLUE_GAUGE_ASSET = "rbxassetid://138976342109765"
local PURPLE_GAUGE_ASSET = "rbxassetid://139485689258376"
local ORANGE_GAUGE_ASSET = "rbxassetid://127598747171041"
local RED_GAUGE_ASSET = "rbxassetid://97502541593370"

local RAGE_WARNING_DURATION = 3
local INITIAL_DRAIN_DURATION = 0.65
local STAGE_DRAIN_DURATION = 0.55

local RAGE_STAGES = {
	{
		name = "Epic",
		goal = 30,
		asset = PURPLE_GAUGE_ASSET,
		topColor = Color3.fromRGB(222, 137, 255),
		bottomColor = Color3.fromRGB(119, 52, 226),
	},
	{
		name = "Legendary",
		goal = 50,
		asset = ORANGE_GAUGE_ASSET,
		topColor = Color3.fromRGB(255, 207, 92),
		bottomColor = Color3.fromRGB(235, 102, 27),
	},
	{
		name = "Mythic",
		goal = 100,
		asset = RED_GAUGE_ASSET,
		topColor = Color3.fromRGB(255, 126, 116),
		bottomColor = Color3.fromRGB(218, 34, 52),
	},
}

local RARITY_STAGE_COUNTS = {
	Epic = 1,
	Legendary = 2,
	Mythic = 3,
}

local function normalizeRarity(rarity)
	if rarity == "Mythical" then
		return "Mythic"
	end

	return rarity or "Common"
end

local function isRageRarity(rarity)
	return RARITY_STAGE_COUNTS[rarity] ~= nil
end

local function setGradient(guiObject, topColor, bottomColor)
	local gradient = guiObject:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Parent = guiObject
	end

	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topColor),
		ColorSequenceKeypoint.new(1, bottomColor),
	})
end

local function isReelInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space
end

local function isKeyboardTapInput(input)
	return input.KeyCode == Enum.KeyCode.Space
		or input.KeyCode == Enum.KeyCode.ButtonA
end

function RarityCatchController.start(options)
	local prompt = options.prompt or {}
	local gameConfig = options.GameConfig
	local legacyUi = options.ui
	local modernUi = options.modernUi
	local ui = legacyUi
	if modernUi then
		ui = setmetatable({
			catchButton = legacyUi.catchButton,
			timingBar = legacyUi.timingBar,
			zone = legacyUi.zone,
			marker = legacyUi.marker,
			fishingGameContent = modernUi.panel,
			catchBar = modernUi.catchBar,
			fishMarker = modernUi.fishMarker,
			progressTrack = modernUi.progressTrack,
			progressFill = modernUi.progressFill,
			minigameText = modernUi.headerText,
			minigameFishInfo = modernUi.statusText,
			minigameProgressText = modernUi.progressText,
			minigameInstruction = modernUi.instructionText,
		}, { __index = legacyUi })
	end
	local runService = options.RunService
	local inputService = options.UserInputService
	local showToast = options.showToast
	local tapButton = options.tapButton
	assert(tapButton and tapButton:IsA("GuiButton"), "RarityCatchController requires the current Tap button")
	local tapButtonIsTextButton = tapButton:IsA("TextButton")
	local tapButtonOriginalText = tapButtonIsTextButton and tapButton.Text or nil
	local tapButtonOriginalAutoButtonColor = tapButton.AutoButtonColor
	local tapButtonOriginalActive = tapButton.Active
	local tapButtonOriginalVisible = tapButton.Visible
	local tapButtonParent = tapButton.Parent
	local tapButtonParentWasVisible = tapButtonParent
		and tapButtonParent:IsA("GuiObject")
		and tapButtonParent.Visible
		or nil
	local tapButtonParentForceVisible = tapButtonParent
		and tapButtonParent:GetAttribute("ForceFishingTapVisible")
		or nil
	local tapSiblingVisibility = {}
	if tapButtonParent then
		for _, sibling in ipairs(tapButtonParent:GetChildren()) do
			if sibling ~= tapButton and sibling:IsA("GuiObject") then
				tapSiblingVisibility[sibling] = sibling.Visible
			end
		end
	end
	local fish = prompt.fish or {}
	local rarity = normalizeRarity(fish.rarity)
	local isAutoFish = prompt.autoFish == true
	local minigameConfig = prompt.minigame
		or gameConfig.getFishingMinigameConfig(rarity, options.state and options.state.EquippedRod or "WoodenRod")
	local difficulty = minigameConfig.difficulty
		or gameConfig.FishingMinigame.RarityDifficulty.Common

	-- Uncommon deliberately uses Common movement and only fills more slowly.
	if rarity == "Uncommon" then
		difficulty = gameConfig.FishingMinigame.RarityDifficulty.Common
	end

	local promptBait = prompt.bait or {}
	local promptBaitId = promptBait.id
		or (options.state and options.state.EquippedBait)
		or gameConfig.BasicBaitId
	local promptBaitData = options.getBaitData(promptBaitId)
	local promptBaitName = promptBait.name or promptBaitData.displayName
	local promptBaitText = "Bait: "
		.. promptBaitName
		.. " ("
		.. options.getBaitCountText(promptBaitId, promptBait.remaining)
		.. ")"
	local castText = prompt.cast and prompt.cast.displayName
		and ("\nCast: " .. prompt.cast.displayName)
		or ""
	if modernUi then
		modernUi.baitText.Text = string.format(
			'<font color="#38D9FF">Bait:</font> %s (%s)',
			promptBaitName,
			options.getBaitCountText(promptBaitId, promptBait.remaining)
		)
		modernUi.castText.Text = prompt.cast and prompt.cast.displayName
			and string.format('<font color="#38D9FF">Cast:</font> %s', prompt.cast.displayName)
			or '<font color="#38D9FF">Cast:</font> --'
	end

	local random = Random.new(math.floor((os.clock() * 100000) % 2147483647))
	local standardProgressBackground = ui.progressFill.BackgroundColor3
	local standardProgressGradient = ui.progressFill:FindFirstChildOfClass("UIGradient")
	local standardProgressGradientColor = standardProgressGradient and standardProgressGradient.Color or nil
	local session = {
		cancelled = false,
		finished = false,
		startedAt = os.clock(),
		inputSequence = 0,
		holding = false,
		phase = "WAITING",
		phaseNumber = 0,
		stageCount = RARITY_STAGE_COUNTS[rarity] or 0,
		progress = math.clamp(tonumber(minigameConfig.startProgress) or 0.34, 0.08, 0.86),
		phaseProgress = 0,
		tapCount = 0,
		tapGoal = 0,
		lastTapAt = 0,
		stageCompleting = false,
		rageSequenceStarted = false,
		rareReversalTriggered = false,
		forcedReverseUntil = 0,
		forcedReverseDirection = 0,
	}
	local connections = {}

	function session.emitInput(kind, holding)
		if isAutoFish or type(options.onInputEvent) ~= "function" then
			return
		end

		session.inputSequence += 1
		options.onInputEvent({
			sequence = session.inputSequence,
			kind = kind,
			holding = holding == true,
			elapsed = math.max(0, os.clock() - session.startedAt),
		})
	end

	function session.setHolding(holding)
		holding = holding == true
		if session.holding == holding then
			return
		end

		session.holding = holding
		FishingSFX.setReelingHolding(holding)
		session.emitInput("Hold", holding)
	end

	local function setTapButtonText(text)
		if tapButtonIsTextButton then
			tapButton.Text = text
		end
	end

	local function setCurrentTapEnabled(enabled)
		setTapButtonText(enabled and "Tap" or "Fishing...")
		tapButton.AutoButtonColor = enabled
		tapButton.Active = enabled
		tapButton.Visible = enabled

		if tapButtonParent then
			for sibling in pairs(tapSiblingVisibility) do
				if sibling.Parent == tapButtonParent then
					sibling.Visible = false
				end
			end
			tapButtonParent:SetAttribute("ForceFishingTapVisible", enabled)
			if tapButtonParent:IsA("GuiObject") then
				tapButtonParent.Visible = enabled
			end
		end
	end

	local function setModernGaugeAsset(assetId)
		if modernUi and modernUi.setGaugeAsset then
			modernUi.setGaugeAsset(assetId)
		end
	end

	local function setGaugeAmount(amount)
		amount = math.clamp(tonumber(amount) or 0, 0, 1)
		if modernUi and modernUi.setProgress then
			modernUi.setProgress(amount)
		else
			ui.progressFill.AnchorPoint = Vector2.new(0, 1)
			ui.progressFill.Position = UDim2.new(0, 0, 1, 0)
			ui.progressFill.Size = UDim2.new(1, 0, amount, 0)
		end
	end

	local function useStandardGauge()
		setModernGaugeAsset(BLUE_GAUGE_ASSET)
		setGaugeAmount(session.progress)
		ui.progressFill.BackgroundColor3 = standardProgressBackground

		local gradient = ui.progressFill:FindFirstChildOfClass("UIGradient")
		if standardProgressGradientColor then
			if not gradient then
				gradient = Instance.new("UIGradient")
				gradient.Rotation = 90
				gradient.Parent = ui.progressFill
			end
			gradient.Color = standardProgressGradientColor
		elseif gradient then
			gradient:Destroy()
		end
	end

	local function getCurrentStage()
		return RAGE_STAGES[session.phaseNumber]
	end

	local function usePhaseGauge()
		local stage = getCurrentStage()
		if not stage then
			return
		end

		setModernGaugeAsset(stage.asset)
		setGaugeAmount(session.phaseProgress)
		ui.progressFill.BackgroundColor3 = stage.bottomColor
		setGradient(ui.progressFill, stage.topColor, stage.bottomColor)

	end

	local function disconnectAll()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	local function setInstruction(instruction, legacyInstruction)
		ui.minigameInstruction.Text = modernUi and instruction or legacyInstruction
	end

	local function resetFishingOnlyVisuals()
		if modernUi and modernUi.restoreRagePresentation then
			modernUi.restoreRagePresentation()
		end
		if modernUi and modernUi.setFishSilhouette then
			modernUi.setFishSilhouette(false)
		end

		if tapButtonIsTextButton and tapButtonOriginalText ~= nil then
			tapButton.Text = tapButtonOriginalText
		end
		tapButton.AutoButtonColor = tapButtonOriginalAutoButtonColor
		tapButton.Active = tapButtonOriginalActive
		tapButton.Visible = tapButtonOriginalVisible
		if tapButtonParent then
			for sibling, wasVisible in pairs(tapSiblingVisibility) do
				if sibling.Parent == tapButtonParent then
					sibling.Visible = wasVisible
				end
			end
			tapButtonParent:SetAttribute("ForceFishingTapVisible", tapButtonParentForceVisible)
			if tapButtonParentWasVisible ~= nil and tapButtonParent:IsA("GuiObject") then
				tapButtonParent.Visible = tapButtonParentWasVisible
			end
		end
		-- Hide the old floating header. The black top banner owns the waiting/reel messages.
		if ui.minigameText and ui.minigameText:IsA("GuiObject") then
			ui.minigameText.Visible = false
		end

		ui.catchButton.Visible = false
		ui.catchButton.Active = false
		ui.catchBar.Visible = true
		ui.fishMarker.Visible = true
		session.progress = math.clamp(session.progress, 0, 1)
		useStandardGauge()
	end

	local function cleanup()
		if session.cancelled or session.finished then
			return
		end

		session.cancelled = true
		FishingSFX.stopReeling()
		disconnectAll()
		resetFishingOnlyVisuals()
	end

	local function finish(success)
		if session.cancelled or session.finished then
			return
		end

		session.setHolding(false)
		session.finished = true
		FishingSFX.stopReeling()
		if success == true then
			FishingSFX.playCatchReveal(rarity, isAutoFish)
		end
		disconnectAll()
		resetFishingOnlyVisuals()
		options.onFinish(
			success == true,
			isAutoFish,
			math.max(0, os.clock() - session.startedAt)
		)
	end

	local function isSessionAlive()
		return not session.cancelled and not session.finished
	end

	local function animateGauge(fromAmount, toAmount, duration, applyAmount)
		local startedAt = os.clock()
		duration = math.max(0.01, tonumber(duration) or 0.01)

		while isSessionAlive() do
			local alpha = math.clamp((os.clock() - startedAt) / duration, 0, 1)
			local eased = 1 - ((1 - alpha) * (1 - alpha))
			local amount = fromAmount + ((toAmount - fromAmount) * eased)
			applyAmount(amount)

			if alpha >= 1 then
				return true
			end
			runService.RenderStepped:Wait()
		end

		return false
	end

	local completeTapStage

	local function beginTapPhase(phaseNumber)
		local stage = RAGE_STAGES[phaseNumber]
		if not stage or not isSessionAlive() then
			return
		end

		FishingSFX.stopReeling()
		session.phase = "TAP"
		session.phaseNumber = phaseNumber
		session.phaseProgress = 0
		session.tapCount = 0
		session.tapGoal = stage.goal
		session.lastTapAt = 0
		session.stageCompleting = false

		ui.catchBar.Visible = false
		ui.fishMarker.Visible = false
		usePhaseGauge()
		setCurrentTapEnabled(true)

		ui.minigameText.Text = string.format("%s Stage - Tap!", stage.name)
		ui.minigameProgressText.Text = string.format("Taps 0 / %d", stage.goal)
		setInstruction(
			string.format("Tap %d times to fill the gauge.", stage.goal),
			promptBaitText .. castText .. string.format("\nTap %d times to fill the gauge.", stage.goal)
		)
	end

	completeTapStage = function()
		if session.stageCompleting or session.phase ~= "TAP" then
			return
		end

		session.stageCompleting = true
		setCurrentTapEnabled(false)

		if session.phaseNumber < session.stageCount then
			local currentPhase = session.phaseNumber
			session.phase = "STAGE_DRAIN"
			task.spawn(function()
				local completed = animateGauge(1, 0, STAGE_DRAIN_DURATION, function(amount)
					session.phaseProgress = amount
					usePhaseGauge()
				end)
				if completed and isSessionAlive() then
					beginTapPhase(currentPhase + 1)
				end
			end)
		else
			session.phase = "COMPLETE"
			ui.minigameText.Text = "Caught!"
			task.delay(0.18, function()
				if isSessionAlive() then
					finish(true)
				end
			end)
		end
	end

	local function registerTap()
		if session.phase ~= "TAP" or session.cancelled or session.finished then
			return
		end

		local now = os.clock()
		-- Keep a small margin above the server's 65 ms validation floor.
		if now - session.lastTapAt < 0.07 then
			return
		end
		session.lastTapAt = now
		session.emitInput("Tap", session.holding)
		session.tapCount = math.min(session.tapGoal, session.tapCount + 1)
		session.phaseProgress = session.tapGoal > 0
			and (session.tapCount / session.tapGoal)
			or 0
		usePhaseGauge()
		ui.minigameProgressText.Text = string.format(
			"Taps %d / %d",
			session.tapCount,
			session.tapGoal
		)

		if session.tapCount >= session.tapGoal then
			completeTapStage()
		end
	end

	local function startRageSequence()
		if not isRageRarity(rarity)
			or session.rageSequenceStarted
			or not isSessionAlive()
		then
			return
		end

		session.rageSequenceStarted = true
		session.phase = "RAGE_WARNING"
		session.setHolding(false)
		session.progress = 1
		useStandardGauge()
		setCurrentTapEnabled(false)
		ui.catchBar.Visible = false
		ui.fishMarker.Visible = false

		if modernUi and modernUi.beginRagePresentation then
			modernUi.beginRagePresentation()
		end

		task.spawn(function()
			local warningCompleted = true
			if modernUi and modernUi.showRageWarning then
				warningCompleted = modernUi.showRageWarning(
					RAGE_WARNING_DURATION,
					isSessionAlive
				)
			else
				local warningEnd = os.clock() + RAGE_WARNING_DURATION
				while isSessionAlive() and os.clock() < warningEnd do
					task.wait(0.05)
				end
				warningCompleted = isSessionAlive()
			end

			if not warningCompleted or not isSessionAlive() then
				return
			end

			session.phase = "INITIAL_DRAIN"
			local drained = animateGauge(1, 0, INITIAL_DRAIN_DURATION, function(amount)
				session.progress = amount
				useStandardGauge()
			end)
			if not drained or not isSessionAlive() then
				return
			end

			session.phase = "GAUGE_FOCUS"
			if modernUi and modernUi.focusGauge then
				local focused = modernUi.focusGauge(isSessionAlive)
				if not focused or not isSessionAlive() then
					return
				end
			end

			-- The gauge has finished moving, enlarging, and rotating into place.
			-- Reuse FishingClient's existing black banner for a short TAP prompt.
			if type(showToast) == "function" then
				showToast("Press the Tap button!", 2)
			end

			beginTapPhase(1)
		end)
	end

	ui.catchButton.Visible = false
	ui.catchButton.Active = false
	ui.timingBar.Visible = false
	ui.zone.Visible = false
	ui.marker.Visible = false
	ui.fishingGameContent.Visible = true
	ui.catchBar.Visible = true
	ui.fishMarker.Visible = true
	options.setFishIcon(fish)
	if modernUi and modernUi.setFishSilhouette then
		modernUi.setFishSilhouette(isRageRarity(rarity))
	elseif modernUi and modernUi.fishImage then
		modernUi.fishImage.ImageColor3 = isRageRarity(rarity)
			and Color3.fromRGB(0, 0, 0)
			or Color3.fromRGB(255, 255, 255)
	end
	setCurrentTapEnabled(false)
	useStandardGauge()

	ui.minigameText.Text = isAutoFish and "AutoFish is waiting for a bite..." or "Waiting for a bite..."
	ui.minigameFishInfo.Text = "Something is biting..."
	ui.minigameProgressText.Text = "Progress --"
	setInstruction(
		isAutoFish and "AutoFish is handling this catch." or "The fish is biting...",
		promptBaitText .. castText
	)
	options.forcePureWhiteText(ui.minigameText)

	table.insert(connections, tapButton.Activated:Connect(registerTap))

	-- Explicit button press/release handling for phones and tablets.
	-- UserInputService below remains as the fallback for mouse, touch, and Space.
	table.insert(connections, tapButton.InputBegan:Connect(function(input)
		if session.phase == "REEL" and isReelInput(input) then
			session.setHolding(true)
		end
	end))
	table.insert(connections, tapButton.InputEnded:Connect(function(input)
		if session.phase == "REEL" and isReelInput(input) then
			session.setHolding(false)
		end
	end))
	table.insert(connections, tapButton.MouseLeave:Connect(function()
		if session.phase == "REEL" then
			session.setHolding(false)
		end
	end))

	table.insert(connections, inputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent and input.UserInputType == Enum.UserInputType.Keyboard then
			return
		end

		if session.phase == "REEL" and isReelInput(input) then
			session.setHolding(true)
		elseif session.phase == "TAP" and isKeyboardTapInput(input) then
			registerTap()
		end
	end))
	table.insert(connections, inputService.InputEnded:Connect(function(input)
		if session.phase == "REEL" and isReelInput(input) then
			session.setHolding(false)
		end
	end))

	task.delay(tonumber(prompt.biteDelay) or 0, function()
		if session.cancelled or session.finished then
			return
		end

		local barSize = math.clamp(tonumber(minigameConfig.barSize) or 0.24, 0.16, 0.58)
		local maxBarTop = 1 - barSize
		local barTop = math.clamp(0.70, 0, maxBarTop)
		local barVelocity = 0
		local fishY = random:NextNumber(0.20, 0.80)
		local fishTarget = random:NextNumber(0.15, 0.85)
		local fishVelocity = 0
		local gameStartedAt = os.clock()
		local nextDecisionAt = gameStartedAt
			+ random:NextNumber(difficulty.turnIntervalMin or 1, difficulty.turnIntervalMax or 2)
		local pauseUntil = 0
		local burstUntil = 0
		local minSuccessDuration = tonumber(minigameConfig.minSuccessDuration) or 1.75
		local gainMultiplier = rarity == "Uncommon" and 0.88 or 1

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

		local function getRareMovementDirection()
			local currentDirection = fishVelocity > 0.01 and 1 or (fishVelocity < -0.01 and -1 or 0)
			if currentDirection == 0 then
				currentDirection = fishTarget >= fishY and 1 or -1
			end

			return currentDirection
		end

		local function hasRoomForRareReversal()
			local reverseDirection = -getRareMovementDirection()
			local availableDistance = reverseDirection < 0 and (fishY - 0.04) or (0.96 - fishY)
			return availableDistance >= 0.12
		end

		local function triggerRareReversal(now)
			if rarity ~= "Rare" or session.rareReversalTriggered then
				return
			end

			session.rareReversalTriggered = true
			session.forcedReverseDirection = -getRareMovementDirection()
			session.forcedReverseUntil = now + 0.32
			local reverseSpeed = math.max((tonumber(difficulty.moveSpeed) or 0.25) * 2.4, 0.72)
			fishVelocity = session.forcedReverseDirection * reverseSpeed
			fishTarget = math.clamp(fishY + (session.forcedReverseDirection * 0.42), 0.06, 0.94)
			pauseUntil = 0
			burstUntil = 0
			nextDecisionAt = session.forcedReverseUntil + 0.10
		end

		FishingSFX.playBiteAlert()
		FishingSFX.startReeling(isAutoFish)
		session.phase = "REEL"
		session.setHolding(false)

		-- The fish has actually bitten. Replace the persistent waiting banner,
		-- then automatically hide the banner after two seconds.
		if not isAutoFish and type(showToast) == "function" then
			showToast("Keep the fish inside the green bar!", 2)
		end

		-- Show the circular TAP button during the normal reel minigame.
		-- Holding it raises the green catch bar; releasing it lets the bar fall.
		-- AutoFish keeps the button hidden because no manual input is needed.
		setCurrentTapEnabled(not isAutoFish)

		ui.catchBar.Size = modernUi and UDim2.fromScale(0.82, barSize) or UDim2.new(1, -32, barSize, 0)
		ui.catchBar.Position = UDim2.new(0.5, 0, barTop, 0)
		ui.fishMarker.Position = UDim2.new(0.5, 0, fishY, 0)
		useStandardGauge()
		ui.minigameText.Text = isAutoFish and "AutoFish is reeling..." or "Keep the fish inside the green bar!"
		ui.minigameFishInfo.Text = string.format(
			"%s [%s]\nValue: %d | XP: %d",
			fish.name or "Fish",
			rarity,
			fish.value or 0,
			fish.xp or 0
		)
		ui.minigameProgressText.Text = string.format("Progress %d%%", math.floor(session.progress * 100 + 0.5))
		local reelInstruction = isAutoFish
			and "AutoFish is handling this catch."
			or "Hold mouse, tap, or Space to lift the green bar. Release to let it fall."
		setInstruction(reelInstruction, promptBaitText .. castText .. "\n" .. reelInstruction)
		options.forcePureWhiteText(ui.minigameText)

		table.insert(connections, runService.RenderStepped:Connect(function(deltaTime)
			if session.cancelled or session.finished then
				return
			end

			if session.phase ~= "REEL" then
				return
			end

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

				nextDecisionAt = now
					+ random:NextNumber(difficulty.turnIntervalMin or 1, difficulty.turnIntervalMax or 2)
			end

			local targetVelocity = 0
			if now < session.forcedReverseUntil then
				targetVelocity = session.forcedReverseDirection
					* math.max((tonumber(difficulty.moveSpeed) or 0.25) * 2.4, 0.72)
			elseif now >= pauseUntil then
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

			local fishAcceleration = tonumber(difficulty.acceleration) or 6
			local velocityBlend = math.min(1, fishAcceleration * deltaTime)
			fishVelocity += (targetVelocity - fishVelocity) * velocityBlend
			fishY += fishVelocity * deltaTime

			if fishY <= 0.04 then
				fishY = 0.04
				fishVelocity = math.abs(fishVelocity) * 0.35
				fishTarget = math.max(fishTarget, 0.16)
			elseif fishY >= 0.96 then
				fishY = 0.96
				fishVelocity = -math.abs(fishVelocity) * 0.35
				fishTarget = math.min(fishTarget, 0.84)
			end

			if isAutoFish then
				local targetTop = math.clamp(fishY - (barSize / 2), 0, maxBarTop)
				barTop += (targetTop - barTop) * math.min(1, deltaTime * 5)
				session.progress = math.clamp(
					session.progress + (minigameConfig.progressGainPerSecond or 0.34) * deltaTime,
					0,
					1
				)
			else
				local barAcceleration = session.holding
					and -(minigameConfig.lift or 2.75)
					or (minigameConfig.gravity or 1.8)
				barVelocity += barAcceleration * deltaTime
				barVelocity = math.clamp(
					barVelocity,
					-(minigameConfig.maxBarVelocity or 1.65),
					minigameConfig.maxBarVelocity or 1.65
				)
				barVelocity *= math.pow(minigameConfig.damping or 0.90, deltaTime * 60)
				barTop += barVelocity * deltaTime

				if barTop <= 0 then
					barTop = 0
					barVelocity = math.abs(barVelocity) * (minigameConfig.bounceDamping or 0.36)
				elseif barTop >= maxBarTop then
					barTop = maxBarTop
					barVelocity = -math.abs(barVelocity) * (minigameConfig.bounceDamping or 0.36)
				end

				local fishInsideBar = fishY >= barTop and fishY <= barTop + barSize
				if fishInsideBar then
					session.progress += (minigameConfig.progressGainPerSecond or 0.34)
						* gainMultiplier
						* deltaTime
				else
					session.progress -= (minigameConfig.progressDrainPerSecond or 0.16) * deltaTime
				end
				session.progress = math.clamp(session.progress, 0, 1)
				-- Progress may reach 0, but the catch never fails and there is no time limit.
			end

			if rarity == "Rare" and not session.rareReversalTriggered and session.progress >= 0.85 then
				if hasRoomForRareReversal() then
					triggerRareReversal(now)
				else
					-- Hold just below the threshold until the opposite dash has room to be visible.
					session.progress = math.min(session.progress, 0.849)
				end
			end

			if rarity == "Rare" and now < session.forcedReverseUntil and session.progress >= 1 then
				session.progress = 0.995
			end

			ui.catchBar.Position = UDim2.new(0.5, 0, barTop, 0)
			ui.fishMarker.Position = UDim2.new(0.5, 0, fishY, 0)
			useStandardGauge()
			ui.minigameProgressText.Text = string.format(
				"Progress %d%%",
				math.floor(session.progress * 100 + 0.5)
			)

			if isRageRarity(rarity) and session.progress >= 1 then
				startRageSequence()
			elseif isAutoFish
				and not isRageRarity(rarity)
				and elapsed >= (prompt.visualTime or 3)
			then
				ui.minigameText.Text = "AutoFish caught it!"
				finish(true)
			elseif not isAutoFish and session.progress >= 1 and elapsed >= minSuccessDuration then
				ui.minigameText.Text = "Caught!"
				finish(true)
			end
		end))
	end)

	return cleanup
end

return RarityCatchController
