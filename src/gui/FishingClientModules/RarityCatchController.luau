local RarityCatchController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FishingMinigameSimulation = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishingMinigameSimulation")
)
local FishingSFX = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishingSFX"))

local PURPLE_TOP = Color3.fromRGB(222, 137, 255)
local PURPLE_BOTTOM = Color3.fromRGB(119, 52, 226)
local ORANGE_TOP = Color3.fromRGB(255, 207, 92)
local ORANGE_BOTTOM = Color3.fromRGB(235, 102, 27)
local RED_TOP = Color3.fromRGB(255, 126, 116)
local RED_BOTTOM = Color3.fromRGB(218, 34, 52)

local TAP_GOALS = {
	Epic = 8,
	Legendary = 14,
	Mythic = 14,
}

local PHASE_DURATIONS = {
	Epic = 4.5,
	Legendary = 4.5,
	Mythic = 4.5,
}

local function normalizeRarity(rarity)
	if rarity == "Mythical" then
		return "Mythic"
	end

	return rarity or "Common"
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

local function ensureTapProgressFill(ui)
	local fill = ui.progressTrack:FindFirstChild("TapProgressFill")
	if fill and fill:IsA("Frame") then
		return fill
	end

	fill = Instance.new("Frame")
	fill.Name = "TapProgressFill"
	fill.AnchorPoint = Vector2.new(1, 1)
	fill.Position = UDim2.new(1, -2, 1, 0)
	fill.Size = UDim2.new(0.44, -1, 0, 0)
	fill.BackgroundColor3 = RED_BOTTOM
	fill.BorderSizePixel = 0
	fill.Visible = false
	fill.ZIndex = ui.progressFill.ZIndex + 1
	fill.Parent = ui.progressTrack

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = fill
	setGradient(fill, RED_TOP, RED_BOTTOM)

	return fill
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
	local tapButton = options.tapButton
	assert(tapButton and tapButton:IsA("GuiButton"), "RarityCatchController requires the current Tap button")
	local tapButtonOriginalText = tapButton.Text
	local tapButtonOriginalAutoButtonColor = tapButton.AutoButtonColor
	local tapButtonOriginalActive = tapButton.Active
	local tapButtonParent = tapButton.Parent
	local tapButtonParentWasVisible = tapButtonParent:IsA("GuiObject") and tapButtonParent.Visible or nil
	local tapButtonParentForceVisible = tapButtonParent:GetAttribute("ForceFishingTapVisible")
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

	local tapFill = ensureTapProgressFill(ui)
	local standardProgressBackground = ui.progressFill.BackgroundColor3
	local standardProgressGradient = ui.progressFill:FindFirstChildOfClass("UIGradient")
	local standardProgressGradientColor = standardProgressGradient and standardProgressGradient.Color or nil
	local session = {
		cancelled = false,
		finished = false,
		phase = "WAITING",
		phaseNumber = 1,
		progress = math.clamp(tonumber(minigameConfig.startProgress) or 0.34, 0.08, 0.86),
		phaseProgress = 0,
		tapCount = 0,
		tapGoal = TAP_GOALS[rarity] or 0,
		lastTapAt = 0,
	}
	local connections = {}
	local evidenceStartedAt = tonumber(options.startedAt) or os.clock()

	local function reportInput(kind, holding)
		if isAutoFish or type(options.onInputEvent) ~= "function" then
			return
		end
		options.onInputEvent({
			kind = kind,
			holding = holding,
			elapsed = math.max(0, os.clock() - evidenceStartedAt),
		})
	end

	local function setCurrentTapEnabled(enabled)
		tapButton.Text = enabled and "Tap" or "Fishing..."
		tapButton.AutoButtonColor = enabled
		if enabled then
			tapButton.Active = true
			tapButtonParent:SetAttribute("ForceFishingTapVisible", true)
			if tapButtonParent:IsA("GuiObject") then
				tapButtonParent.Visible = true
			end
		end
	end

	local function useStandardGauge()
		if modernUi then
			ui.progressFill.AnchorPoint = Vector2.new(0.5, 1)
			ui.progressFill.Position = UDim2.fromScale(0.5, 0.890)
			ui.progressFill.Size = UDim2.fromScale(0.58, session.progress)
		else
			ui.progressFill.AnchorPoint = Vector2.new(0, 1)
			ui.progressFill.Position = UDim2.new(0, 0, 1, 0)
			ui.progressFill.Size = UDim2.new(1, 0, session.progress, 0)
		end
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

		tapFill.Visible = false
		if modernUi then
			tapFill.AnchorPoint = Vector2.new(0.5, 1)
			tapFill.Position = UDim2.fromScale(0.68, 0.890)
			tapFill.Size = UDim2.fromScale(0.30, 0)
		else
			tapFill.AnchorPoint = Vector2.new(1, 1)
			tapFill.Position = UDim2.new(1, -2, 1, 0)
			tapFill.Size = UDim2.new(0.44, -1, 0, 0)
		end
	end

	local function usePhaseGauge()
		local phaseTop = rarity == "Epic" and PURPLE_TOP or ORANGE_TOP
		local phaseBottom = rarity == "Epic" and PURPLE_BOTTOM or ORANGE_BOTTOM

		if modernUi then
			ui.progressFill.AnchorPoint = Vector2.new(0.5, 1)
			ui.progressFill.Position = UDim2.fromScale(0.32, 0.890)
			ui.progressFill.Size = UDim2.fromScale(0.30, session.phaseProgress)
		else
			ui.progressFill.AnchorPoint = Vector2.new(0, 1)
			ui.progressFill.Position = UDim2.new(0, 2, 1, 0)
			ui.progressFill.Size = UDim2.new(0.44, -1, session.phaseProgress, 0)
		end
		ui.progressFill.BackgroundColor3 = phaseBottom
		setGradient(ui.progressFill, phaseTop, phaseBottom)

		tapFill.Visible = true
		if modernUi then
			tapFill.AnchorPoint = Vector2.new(0.5, 1)
			tapFill.Position = UDim2.fromScale(0.68, 0.890)
			tapFill.Size = UDim2.fromScale(
				0.30,
				session.tapGoal > 0 and (session.tapCount / session.tapGoal) or 0
			)
		else
			tapFill.AnchorPoint = Vector2.new(1, 1)
			tapFill.Position = UDim2.new(1, -2, 1, 0)
			tapFill.Size = UDim2.new(0.44, -1, session.tapGoal > 0 and (session.tapCount / session.tapGoal) or 0, 0)
		end
		if tapButtonParent:IsA("GuiObject") then
			-- The existing fishing-area visibility controller also runs every frame.
			-- Keep the current persistent Tap button on-screen throughout special phases.
			tapButtonParent.Visible = true
		end
		tapButtonParent:SetAttribute("ForceFishingTapVisible", true)
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
		tapButton.Text = tapButtonOriginalText
		tapButton.AutoButtonColor = tapButtonOriginalAutoButtonColor
		tapButton.Active = tapButtonOriginalActive
		tapButtonParent:SetAttribute("ForceFishingTapVisible", tapButtonParentForceVisible)
		if tapButtonParentWasVisible ~= nil and tapButtonParent:IsA("GuiObject") then
			tapButtonParent.Visible = tapButtonParentWasVisible
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

		session.finished = true
		FishingSFX.stopReeling()
		if success == true then
			FishingSFX.playCatchReveal(rarity, isAutoFish)
		end
		disconnectAll()
		resetFishingOnlyVisuals()
		options.onFinish(success == true, isAutoFish)
	end

	local function beginTapPhase(phaseNumber)
		FishingSFX.stopReeling()
		session.phase = "TAP"
		session.phaseNumber = phaseNumber
		session.phaseProgress = 0
		session.tapCount = 0
		session.lastTapAt = 0

		ui.catchBar.Visible = false
		ui.fishMarker.Visible = false
		usePhaseGauge()
		setCurrentTapEnabled(true)

		ui.minigameText.Text = string.format("Phase %d - Tap!", phaseNumber)
		ui.minigameProgressText.Text = string.format("Phase %d | Power 0%% | Taps 0 / %d", phaseNumber, session.tapGoal)
		setInstruction(
			"Use the current Tap button to fill the red gauge.",
			promptBaitText .. castText .. "\nUse the current Tap button to fill the red gauge."
		)
	end

	local function beginDrain(nextPhaseNumber)
		FishingSFX.stopReeling()
		session.phase = "DRAIN"
		session.phaseNumber = nextPhaseNumber
		setCurrentTapEnabled(false)
		ui.minigameText.Text = string.format("Phase %d incoming...", nextPhaseNumber)
		setInstruction(
			"Get ready for the next phase.",
			promptBaitText .. castText .. "\nGet ready for the next phase."
		)
	end

	local function registerTap()
		if session.phase ~= "TAP" or session.cancelled or session.finished then
			return
		end

		local now = os.clock()
		if now - session.lastTapAt < 0.08 then
			return
		end
		session.lastTapAt = now
		FishingSFX.playReelTap()
		session.tapCount = math.min(session.tapGoal, session.tapCount + 1)
		reportInput("Tap")
		usePhaseGauge()
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

	table.insert(connections, tapButton.InputBegan:Connect(function(input)
		if session.phase == "TAP"
			and (input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch)
		then
			registerTap()
		end
	end))
	table.insert(connections, inputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent and input.UserInputType == Enum.UserInputType.Keyboard then
			return
		end

		if session.phase == "REEL" and isReelInput(input) then
			if not session.holding then
				session.holding = true
				FishingSFX.setReelingHolding(true)
				reportInput("Hold", true)
			end
		elseif session.phase == "TAP" and isKeyboardTapInput(input) then
			registerTap()
		end
	end))
	table.insert(connections, inputService.InputEnded:Connect(function(input)
		if session.phase == "REEL" and isReelInput(input) then
			if session.holding then
				session.holding = false
				FishingSFX.setReelingHolding(false)
				reportInput("Hold", false)
			end
		end
	end))

	local remainingBiteDelay = math.max(
		0,
		(tonumber(prompt.biteDelay) or 0) - math.max(0, os.clock() - evidenceStartedAt)
	)
	task.delay(remainingBiteDelay, function()
		if session.cancelled or session.finished then
			return
		end

		local simulation = FishingMinigameSimulation.new(
			minigameConfig,
			difficulty,
			prompt.minigameSeed,
			rarity
		)
		local snapshot = simulation:getSnapshot()
		local barSize = snapshot.barSize
		local gameStartedAt = os.clock()
		local maxDuration = tonumber(minigameConfig.maxDuration) or 35
		local phaseDuration = PHASE_DURATIONS[rarity] or 0

		FishingSFX.playBiteAlert()
		FishingSFX.startReeling(isAutoFish)
		session.phase = "REEL"
		session.holding = false
		ui.catchBar.Size = modernUi and UDim2.fromScale(0.82, barSize) or UDim2.new(1, -32, barSize, 0)
		ui.catchBar.Position = UDim2.new(0.5, 0, snapshot.barTop, 0)
		ui.fishMarker.Position = UDim2.new(0.5, 0, snapshot.fishY, 0)
		reportInput("Hold", false)
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

			local now = os.clock()
			local elapsed = now - gameStartedAt

			if session.phase == "DRAIN" then
				session.progress = math.max(0, session.progress - (2 * deltaTime))
				session.phaseProgress = math.max(0, session.phaseProgress - (2 * deltaTime))
				session.tapCount = math.max(0, session.tapCount - (session.tapGoal * 2 * deltaTime))

				if tapFill.Visible then
					usePhaseGauge()
				else
					useStandardGauge()
				end

				ui.minigameProgressText.Text = string.format(
					"Phase %d incoming... %d%%",
					session.phaseNumber,
					math.floor(math.max(session.progress, session.phaseProgress) * 100 + 0.5)
				)

				if session.progress <= 0 and session.phaseProgress <= 0 and session.tapCount <= 0 then
					beginTapPhase(session.phaseNumber)
				end
			elseif session.phase == "TAP" then
				session.phaseProgress = math.min(1, session.phaseProgress + (deltaTime / phaseDuration))
				usePhaseGauge()
				ui.minigameProgressText.Text = string.format(
					"Phase %d | Power %d%% | Taps %d / %d",
					session.phaseNumber,
					math.floor(session.phaseProgress * 100 + 0.5),
					math.floor(session.tapCount + 0.5),
					session.tapGoal
				)

				if session.phaseProgress >= 1 and session.tapCount >= session.tapGoal then
					if rarity == "Mythic" and session.phaseNumber == 2 then
						session.progress = 0
						beginDrain(3)
					else
						ui.minigameText.Text = "Caught!"
						finish(true)
					end
				end
			else
				snapshot = simulation:advance(deltaTime, session.holding)
				if isAutoFish then
					session.progress = math.clamp(
						session.progress + (minigameConfig.progressGainPerSecond or 0.34) * deltaTime,
						0,
						1
					)
				else
					session.progress = snapshot.progress
				end

				ui.catchBar.Position = UDim2.new(0.5, 0, snapshot.barTop, 0)
				ui.fishMarker.Position = UDim2.new(0.5, 0, snapshot.fishY, 0)
				useStandardGauge()
				ui.minigameProgressText.Text = string.format(
					"Progress %d%%",
					math.floor(session.progress * 100 + 0.5)
				)

				if isAutoFish and elapsed >= (prompt.visualTime or 3) then
					ui.minigameText.Text = "AutoFish caught it!"
					finish(true)
				elseif not isAutoFish and snapshot.reelCompletedAt then
					if rarity == "Epic" or rarity == "Legendary" or rarity == "Mythic" then
						beginDrain(2)
					else
						ui.minigameText.Text = "Caught!"
						finish(true)
					end
				elseif not isAutoFish and snapshot.failedAt then
					ui.minigameText.Text = "Caught!"
					finish(true)
				end
			end

			if not isAutoFish and not session.finished and elapsed >= maxDuration then
				ui.minigameText.Text = "Caught!"
				finish(true)
			end
		end))
	end)

	return cleanup
end

return RarityCatchController
