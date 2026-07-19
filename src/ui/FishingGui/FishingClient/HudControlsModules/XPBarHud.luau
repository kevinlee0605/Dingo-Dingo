local XPBarHud = {}

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
	requiredChild(combinedText, "XPTextOutline", "UIStroke")
	local progressText = requiredChild(xpContainer, "LegacyXPProgressText", "TextLabel")
	local legacyFill = requiredChild(xpContainer, "LegacyXPFill", "Frame")

	xpContainer.Visible = true
	progressText.Visible = false
	legacyFill.Visible = false

	refs.xpLevelText = combinedText
	refs.xpProgressText = progressText
	refs.xpBarFrame = xpContainer
	refs.xpText = combinedText
	refs.xpFill = legacyFill

	function refs.updateXP(data)
		if not data then
			combinedText.Text = "Level: 1 [0/40]"
			progressText.Text = "0 / 40 XP"
			return
		end

		local level = math.clamp(math.floor(tonumber(data.Level) or 1), 1, maxLevel)
		local progressXP = math.max(0, math.floor(tonumber(data.LevelProgressXP) or 0))
		local nextXP = math.max(0, math.floor(tonumber(data.NextLevelXP) or 0))
		local isMax = level >= maxLevel or nextXP <= 0

		if isMax then
			combinedText.Text = string.format("Level: %d [MAX]", level)
			progressText.Text = "MAX"
		else
			combinedText.Text = string.format(
				"Level: %d [%s/%s]",
				level,
				formatNumber(progressXP),
				formatNumber(nextXP)
			)
			progressText.Text = string.format(
				"%s / %s XP",
				formatNumber(progressXP),
				formatNumber(nextXP)
			)
		end
	end
end

return XPBarHud
