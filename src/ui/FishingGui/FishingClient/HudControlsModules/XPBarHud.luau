local TweenService = game:GetService("TweenService")

local XPBarHud = {}

local ROLL_TIME = 0.65

local function requiredChild(parent, name, className)
	local child = parent:FindFirstChild(name)
	assert(
		child and child:IsA(className),
		string.format(
			"[XPBarHud] Expected %s.%s to be a %s",
			parent:GetFullName(),
			name,
			className
		)
	)
	return child
end

function XPBarHud.create(deps, refs, formatNumber, maxLevel)
	assert(deps.authoredUiV2, "[XPBarHud] AuthoredUiV2 is required")
	assert(deps.findAuthoredHost, "[XPBarHud] findAuthoredHost is required")

	local xpContainer = deps.findAuthoredHost("FishingXPText", "GuiObject")
	assert(xpContainer, "[XPBarHud] Missing authored FishingXPText")

	requiredChild(xpContainer, "LeftStatsScale", "UIScale")
	requiredChild(xpContainer, "XPSizeConstraint", "UISizeConstraint")
	local combinedText = requiredChild(xpContainer, "XPCombinedText", "TextLabel")
	requiredChild(combinedText, "UITextSizeConstraint", "UITextSizeConstraint")
	local outline = requiredChild(combinedText, "XPTextOutline", "UIStroke")
	local progressText = requiredChild(xpContainer, "LegacyXPProgressText", "TextLabel")
	local legacyFill = requiredChild(xpContainer, "LegacyXPFill", "Frame")

	xpContainer.Visible = true
	xpContainer.ClipsDescendants = true
	progressText.Visible = false
	legacyFill.Visible = false
	-- Match the currency readouts: Gotham Black, a single dark outline, and no
	-- second legacy TextStroke layered beneath it.
	combinedText.Font = Enum.Font.GothamBlack
	combinedText.TextStrokeTransparency = 1
	outline.Color = Color3.fromRGB(0, 10, 21)
	outline.Thickness = 1.6
	outline.Transparency = 0

	refs.xpLevelText = combinedText
	refs.xpProgressText = progressText
	refs.xpBarFrame = xpContainer
	refs.xpText = combinedText
	refs.xpFill = legacyFill

	local currentLevel = nil
	local rollSerial = 0
	local outgoingLabel = nil
	local activeTweens = {}

	local function cancelRoll()
		for _, tween in ipairs(activeTweens) do
			tween:Cancel()
		end
		table.clear(activeTweens)
		if outgoingLabel then
			outgoingLabel:Destroy()
			outgoingLabel = nil
		end
		combinedText.Position = UDim2.fromScale(0, 0)
	end

	local function setTextWithLevelRoll(text, level)
		if currentLevel == nil or level == currentLevel then
			cancelRoll()
			combinedText.Text = text
			currentLevel = level
			return
		end

		cancelRoll()
		rollSerial += 1
		local thisRoll = rollSerial
		local increasing = level > currentLevel
		outgoingLabel = combinedText:Clone()
		outgoingLabel.Name = "OutgoingLevelText"
		outgoingLabel.Position = UDim2.fromScale(0, 0)
		outgoingLabel.Parent = xpContainer

		combinedText.Text = text
		combinedText.Position = increasing
			and UDim2.fromScale(0, 1)
			or UDim2.fromScale(0, -1)

		local tweenInfo = TweenInfo.new(
			ROLL_TIME,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		)
		local outgoingTween = TweenService:Create(outgoingLabel, tweenInfo, {
			Position = increasing and UDim2.fromScale(0, -1) or UDim2.fromScale(0, 1),
			TextTransparency = 0.35,
		})
		local incomingTween = TweenService:Create(combinedText, tweenInfo, {
			Position = UDim2.fromScale(0, 0),
			TextTransparency = 0,
		})
		activeTweens = { outgoingTween, incomingTween }
		outgoingTween:Play()
		incomingTween:Play()
		currentLevel = level

		task.delay(ROLL_TIME + 0.06, function()
			if rollSerial ~= thisRoll then
				return
			end
			cancelRoll()
		end)
	end

	function refs.updateXP(data)
		if not data then
			setTextWithLevelRoll("Level: 1 [0/40]", 1)
			progressText.Text = "0 / 40 XP"
			return
		end

		local level = math.clamp(math.floor(tonumber(data.Level) or 1), 1, maxLevel)
		local progressXP = math.max(0, math.floor(tonumber(data.LevelProgressXP) or 0))
		local nextXP = math.max(0, math.floor(tonumber(data.NextLevelXP) or 0))
		local isMax = level >= maxLevel or nextXP <= 0

		if isMax then
			setTextWithLevelRoll(string.format("Level: %d [MAX]", level), level)
			progressText.Text = "MAX"
		else
			setTextWithLevelRoll(string.format(
				"Level: %d [%s/%s]",
				level,
				formatNumber(progressXP),
				formatNumber(nextXP)
			), level)
			progressText.Text = string.format(
				"%s / %s XP",
				formatNumber(progressXP),
				formatNumber(nextXP)
			)
		end
	end
end

return XPBarHud
