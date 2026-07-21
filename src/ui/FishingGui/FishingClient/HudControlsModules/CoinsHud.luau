local TweenService = game:GetService("TweenService")

local CoinsHud = {}

local COIN_ICON_IMAGE = "rbxassetid://99615681502772"

local NUMBER_AREA_WIDTH = 320
-- Leave room for the 2.2 px outline so the first/last glyph is not clipped.
local DIGIT_WIDTH = 28
local COMMA_WIDTH = 15
local DIGIT_HEIGHT = 72
local GLYPH_HORIZONTAL_PADDING = 3
local ROLL_TIME = 0.65

local function requiredChild(parent, name, className)
	local child = parent:FindFirstChild(name)
	assert(
		child and child:IsA(className),
		string.format(
			"[CoinsHud] Expected %s.%s to be a %s",
			parent:GetFullName(),
			name,
			className
		)
	)
	return child
end

function CoinsHud.create(deps, refs, formatNumber)
	assert(deps.authoredUiV2, "[CoinsHud] AuthoredUiV2 is required")
	assert(deps.findAuthoredHost, "[CoinsHud] findAuthoredHost is required")

	local coinsHud = deps.findAuthoredHost("CoinsHud", "GuiObject")
	assert(coinsHud, "[CoinsHud] Missing authored CoinsHud")

	requiredChild(coinsHud, "LeftStatsScale", "UIScale")
	requiredChild(coinsHud, "CoinsSizeConstraint", "UISizeConstraint")
	local icon = requiredChild(coinsHud, "CoinIcon", "ImageLabel")
	local numberArea = requiredChild(coinsHud, "NumberArea", "Frame")
	local digitsHolder = requiredChild(numberArea, "DigitsHolder", "Frame")
	local digitsScale = requiredChild(digitsHolder, "DigitsScale", "UIScale")
	local previewSlot = requiredChild(digitsHolder, "PreviewDigitSlot", "Frame")
	local previewCharacter = requiredChild(previewSlot, "PreviewCharacter", "TextLabel")
	requiredChild(previewCharacter, "UITextSizeConstraint", "UITextSizeConstraint")
	requiredChild(previewCharacter, "NumberOutline", "UIStroke")
	local compatibilityCoinsText = requiredChild(coinsHud, "CoinsText", "TextLabel")
	local coinsTextConstraint = requiredChild(compatibilityCoinsText, "UITextSizeConstraint", "UITextSizeConstraint")
	local statsText = requiredChild(coinsHud, "LegacyStatsText", "TextLabel")
	local statusText = requiredChild(coinsHud, "LegacyStatusText", "TextLabel")

	icon.Image = COIN_ICON_IMAGE
	icon.Visible = true
	coinsHud.Visible = true
	previewSlot.Visible = false
	for _, child in ipairs(digitsHolder:GetChildren()) do
		if string.match(child.Name, "^EditorPreviewDigit") then
			child.Visible = false
		end
	end
	digitsHolder.Visible = true
	compatibilityCoinsText.Position = UDim2.fromOffset(80, 10)
	compatibilityCoinsText.Size = UDim2.fromOffset(320, 76)
	compatibilityCoinsText.TextScaled = false
	compatibilityCoinsText.TextSize = 30
	compatibilityCoinsText.TextTransparency = 1
	compatibilityCoinsText.Visible = false
	coinsTextConstraint.MinTextSize = 14
	coinsTextConstraint.MaxTextSize = 30
	statsText.Visible = false
	statusText.Visible = false

	local function createCharacterLabel(parent, name, character)
		-- Each slot clone already includes the authored preview character. The
		-- second rolling character is cloned from that same Explorer template.
		local label = parent:FindFirstChild("PreviewCharacter")
		if not (label and label:IsA("TextLabel")) then
			label = previewCharacter:Clone()
			label.Parent = parent
		end

		label.Name = name
		label.AnchorPoint = Vector2.new(0, 0)
		label.Position = UDim2.fromScale(0, 0)
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Text = character
		label.TextScaled = false
		label.TextSize = 8
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextTransparency = 0
		label.Visible = true
		label.ZIndex = 1004
		return label
	end

	local function getCharacterWidth(character)
		if character == "," then
			return COMMA_WIDTH
		end
		return DIGIT_WIDTH
	end

	local function getTotalWidth(text)
		local total = 0
		for index = 1, #text do
			total += getCharacterWidth(string.sub(text, index, index))
		end
		return total
	end

	local activeTweens = {}
	local animationSerial = 0
	local currentValue = 0
	local hasInitialized = false

	local function cancelActiveTweens()
		for _, tween in ipairs(activeTweens) do
			tween:Cancel()
		end
		table.clear(activeTweens)
	end

	local function clearDigitSlots()
		for _, child in ipairs(digitsHolder:GetChildren()) do
			if child.Name == "DigitSlot" then
				child:Destroy()
			end
		end
	end

	local function configureHolderWidth(formatted)
		local totalWidth = getTotalWidth(formatted)
		digitsHolder.Size = UDim2.fromOffset(totalWidth, DIGIT_HEIGHT)

		if totalWidth > NUMBER_AREA_WIDTH then
			digitsScale.Scale = NUMBER_AREA_WIDTH / totalWidth
		else
			digitsScale.Scale = 1
		end
	end

	local function createSlot(xOffset, width)
		local slot = previewSlot:Clone()
		slot.Name = "DigitSlot"
		-- The slot must remain vertically clipped for the rolling animation, but
		-- its text outline needs a few pixels beyond the glyph on both sides.
		-- Expanding symmetrically preserves the exact character center/spacing.
		slot.Position = UDim2.fromOffset(xOffset - GLYPH_HORIZONTAL_PADDING, 0)
		slot.Size = UDim2.fromOffset(
			width + GLYPH_HORIZONTAL_PADDING * 2,
			DIGIT_HEIGHT
		)
		slot.Visible = true
		slot.Parent = digitsHolder
		return slot
	end

	local function renderImmediate(value)
		cancelActiveTweens()
		clearDigitSlots()

		currentValue = math.floor(tonumber(value) or 0)
		local formatted = formatNumber(currentValue)
		configureHolderWidth(formatted)

		local xOffset = 0
		for index = 1, #formatted do
			local character = string.sub(formatted, index, index)
			local width = getCharacterWidth(character)
			local slot = createSlot(xOffset, width)
			createCharacterLabel(slot, "Character", character)
			xOffset += width
		end

		compatibilityCoinsText.Text = formatted
	end

	local function getOldCharacterForNewPosition(oldText, newText, newIndex)
		local distanceFromRight = #newText - newIndex
		local oldIndex = #oldText - distanceFromRight

		if oldIndex < 1 or oldIndex > #oldText then
			return ""
		end

		return string.sub(oldText, oldIndex, oldIndex)
	end

	local function animateTo(value)
		value = math.floor(tonumber(value) or 0)

		if not hasInitialized then
			hasInitialized = true
			renderImmediate(value)
			return
		end

		if value == currentValue then
			compatibilityCoinsText.Text = formatNumber(value)
			return
		end

		cancelActiveTweens()
		clearDigitSlots()

		animationSerial += 1
		local thisAnimation = animationSerial
		local oldValue = currentValue
		local oldFormatted = formatNumber(oldValue)
		local newFormatted = formatNumber(value)
		local increasing = value > oldValue

		currentValue = value
		compatibilityCoinsText.Text = newFormatted
		configureHolderWidth(newFormatted)

		local xOffset = 0
		local changedDigitCount = 0

		for newIndex = 1, #newFormatted do
			local newCharacter = string.sub(newFormatted, newIndex, newIndex)
			local oldCharacter = getOldCharacterForNewPosition(oldFormatted, newFormatted, newIndex)
			local width = getCharacterWidth(newCharacter)
			local slot = createSlot(xOffset, width)
			local isDigit = string.match(newCharacter, "%d") ~= nil
			local changed = oldCharacter ~= newCharacter

			if not isDigit or not changed then
				createCharacterLabel(slot, "StaticCharacter", newCharacter)
			else
				changedDigitCount += 1

				local outgoing = createCharacterLabel(slot, "OutgoingCharacter", oldCharacter)
				if oldCharacter == "" or string.match(oldCharacter, "%d") == nil then
					outgoing.TextTransparency = 1
				end

				local incoming = createCharacterLabel(slot, "IncomingCharacter", newCharacter)
				incoming.Position = increasing
					and UDim2.fromScale(0, 1)
					or UDim2.fromScale(0, -1)
				incoming.TextTransparency = 0.08

				local tweenInfo = TweenInfo.new(
					ROLL_TIME,
					Enum.EasingStyle.Quint,
					Enum.EasingDirection.Out
				)
				local outgoingTween = TweenService:Create(outgoing, tweenInfo, {
					Position = increasing and UDim2.fromScale(0, -1) or UDim2.fromScale(0, 1),
					TextTransparency = 0.35,
				})
				local incomingTween = TweenService:Create(incoming, tweenInfo, {
					Position = UDim2.fromScale(0, 0),
					TextTransparency = 0,
				})

				table.insert(activeTweens, outgoingTween)
				table.insert(activeTweens, incomingTween)
				outgoingTween:Play()
				incomingTween:Play()
			end

			xOffset += width
		end

		if changedDigitCount == 0 then
			renderImmediate(value)
			return
		end

		task.delay(ROLL_TIME + 0.06, function()
			if thisAnimation ~= animationSerial then
				return
			end
			renderImmediate(value)
		end)
	end

	refs.coinsText = compatibilityCoinsText
	refs.coinsHud = coinsHud
	refs.coinIcon = icon
	refs.coinNumberArea = numberArea
	refs.statsText = statsText
	refs.statusText = statusText

	function refs.updateCoins(coins)
		animateTo(coins)
	end
end

return CoinsHud
