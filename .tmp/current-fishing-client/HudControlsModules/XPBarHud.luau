local XPBarHud = {}

-- 텍스트 전체 위치와 크기
-- X가 작아지면 왼쪽, 커지면 오른쪽
-- Y가 작아지면 위, 커지면 아래
local XP_TEXT_POSITION = UDim2.fromScale(0.1, 0.9)
local XP_TEXT_SIZE = UDim2.new(0, 380, 0, 54)

-- 텍스트 스타일
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local OUTLINE_COLOR = Color3.fromRGB(0, 0, 0)
local OUTLINE_THICKNESS = 3
local MIN_TEXT_SIZE = 18
local MAX_TEXT_SIZE = 30

function XPBarHud.create(deps, refs, formatNumber, maxLevel)
	local screenGui = deps.screenGui

	-- 배경 없는 투명 컨테이너
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

	-- 실제로 보이는 단일 텍스트
	local combinedText = Instance.new("TextLabel")
	combinedText.Name = "XPCombinedText"
	combinedText.Size = UDim2.fromScale(1, 1)
	combinedText.BackgroundTransparency = 1
	combinedText.BorderSizePixel = 0
	combinedText.Text = "Level: 1 [0/40]"
	combinedText.TextColor3 = TEXT_COLOR
	combinedText.TextScaled = true
	combinedText.Font = Enum.Font.GothamBlack
	combinedText.TextXAlignment = Enum.TextXAlignment.Center
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

	-- 기존 코드와의 호환성을 위한 refs
	refs.xpLevelText = combinedText

	refs.xpProgressText = Instance.new("TextLabel")
	refs.xpProgressText.Name = "LegacyXPProgressText"
	refs.xpProgressText.BackgroundTransparency = 1
	refs.xpProgressText.Size = UDim2.fromOffset(0, 0)
	refs.xpProgressText.Visible = false
	refs.xpProgressText.Parent = xpContainer

	refs.xpFill = Instance.new("Frame")
	refs.xpFill.Name = "LegacyXPFill"
	refs.xpFill.BackgroundTransparency = 1
	refs.xpFill.Size = UDim2.fromOffset(0, 0)
	refs.xpFill.Visible = false
	refs.xpFill.Parent = xpContainer

	function refs.updateXP(data)
		if not data then
			combinedText.Text = "Level: 1 [0/40]"
			refs.xpProgressText.Text = "0 / 40 XP"
			return
		end

		local level = math.clamp(
			math.floor(tonumber(data.Level) or 1),
			1,
			maxLevel
		)

		local progressXP = math.max(
			0,
			math.floor(tonumber(data.LevelProgressXP) or 0)
		)

		local nextXP = math.max(
			0,
			math.floor(tonumber(data.NextLevelXP) or 0)
		)

		local isMax = level >= maxLevel or nextXP <= 0

		if isMax then
			combinedText.Text = string.format("Level: %d [MAX]", level)
			refs.xpProgressText.Text = "MAX"
		else
			combinedText.Text = string.format(
				"Level: %d [%s/%s]",
				level,
				formatNumber(progressXP),
				formatNumber(nextXP)
			)

			refs.xpProgressText.Text = string.format(
				"%s / %s XP",
				formatNumber(progressXP),
				formatNumber(nextXP)
			)
		end
	end

	-- 외부에서 위치/크기를 조정할 때 사용할 수 있는 ref
	refs.xpBarFrame = xpContainer
	refs.xpText = combinedText
end

return XPBarHud
