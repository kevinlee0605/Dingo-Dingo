local XPBarHud = {}

-- Legacy placement is used only when FishingGui is not an authored hierarchy.
local XP_TEXT_POSITION = UDim2.new(0, 202, 0.10, -31)
local XP_TEXT_SIZE = UDim2.new(0, 380, 0, 54)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local OUTLINE_COLOR = Color3.fromRGB(0, 0, 0)
local OUTLINE_THICKNESS = 3
local MIN_TEXT_SIZE = 18
local MAX_TEXT_SIZE = 30

local function makeHiddenProgressText(parent)
	local existing = parent:FindFirstChild("LegacyXPProgressText")
	if existing and existing:IsA("TextLabel") then
		return existing
	end

	local label = Instance.new("TextLabel")
	label.Name = "LegacyXPProgressText"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(0, 0)
	label.Text = ""
	label.TextTransparency = 1
	label.Visible = false
	label.Parent = parent
	return label
end

local function makeHiddenFill(parent)
	local existing = parent:FindFirstChild("LegacyXPFill")
	if existing and existing:IsA("Frame") then
		return existing
	end

	local fill = Instance.new("Frame")
	fill.Name = "LegacyXPFill"
	fill.BackgroundTransparency = 1
	fill.Size = UDim2.fromOffset(0, 0)
	fill.Visible = false
	fill.Parent = parent
	return fill
end

local function bindUpdater(refs, xpContainer, combinedText, progressText, formatNumber, maxLevel)
	refs.xpLevelText = combinedText
	refs.xpProgressText = progressText
	refs.xpBarFrame = xpContainer
	refs.xpText = combinedText

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

function XPBarHud.create(deps, refs, formatNumber, maxLevel)
	local screenGui = deps.screenGui

	if deps.authoredUiV2 and deps.findAuthoredHost then
		local xpContainer = deps.findAuthoredHost("FishingXPText", "GuiObject")
		local combinedText = xpContainer and xpContainer:FindFirstChild("XPCombinedText")

		if xpContainer and combinedText and combinedText:IsA("TextLabel") then
			xpContainer.Visible = true
			refs.xpFill = makeHiddenFill(xpContainer)
			bindUpdater(
				refs,
				xpContainer,
				combinedText,
				makeHiddenProgressText(xpContainer),
				formatNumber,
				maxLevel
			)
			return
		end

		warn("[XPBarHud] Authored FishingXPText is incomplete; using the legacy fallback")
	end

	local xpContainer = Instance.new("Frame")
	xpContainer.Name = "FishingXPText"
	xpContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	xpContainer.Position = XP_TEXT_POSITION
	xpContainer.Size = XP_TEXT_SIZE
	xpContainer.BackgroundTransparency = 1
	xpContainer.BorderSizePixel = 0
	xpContainer.Visible = true
	xpContainer.ZIndex = 1000
	xpContainer.Parent = screenGui

	local combinedText = Instance.new("TextLabel")
	combinedText.Name = "XPCombinedText"
	combinedText.Size = UDim2.fromScale(1, 1)
	combinedText.BackgroundTransparency = 1
	combinedText.BorderSizePixel = 0
	combinedText.Text = "Level: 1 [0/40]"
	combinedText.TextColor3 = TEXT_COLOR
	combinedText.TextScaled = true
	combinedText.Font = Enum.Font.GothamBlack
	combinedText.TextXAlignment = Enum.TextXAlignment.Left
	combinedText.TextYAlignment = Enum.TextYAlignment.Center
	combinedText.TextStrokeColor3 = OUTLINE_COLOR
	combinedText.TextStrokeTransparency = 0
	combinedText.ZIndex = 1001
	combinedText.Parent = xpContainer

	local textStroke = Instance.new("UIStroke")
	textStroke.Name = "XPTextOutline"
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Color = OUTLINE_COLOR
	textStroke.Thickness = OUTLINE_THICKNESS
	textStroke.Transparency = 0
	textStroke.Parent = combinedText

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = MIN_TEXT_SIZE
	textConstraint.MaxTextSize = MAX_TEXT_SIZE
	textConstraint.Parent = combinedText

	refs.xpFill = makeHiddenFill(xpContainer)
	bindUpdater(
		refs,
		xpContainer,
		combinedText,
		makeHiddenProgressText(xpContainer),
		formatNumber,
		maxLevel
	)
end

return XPBarHud
