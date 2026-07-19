local TweenService = game:GetService("TweenService")

local CoinsHud = {}

function CoinsHud.create(deps, refs, formatNumber)
	local screenGui = deps.screenGui

	-- ============================================================
	-- EDIT THESE VALUES
	-- ============================================================

	-- Upload the transparent coin-stack image to Asset Manager,
	-- then paste the asset ID here.
	local COIN_ICON_IMAGE = "rbxassetid://99615681502772"

	-- Whole HUD position.
	-- Smaller X = left, larger X = right
	-- Smaller Y = up,   larger Y = down
	local COINS_HUD_POSITION = UDim2.new(0, 8, 0.10, 0)

	-- Overall dimensions.
	local COINS_HUD_SIZE = UDim2.fromOffset(430, 96)

	-- Coin image.
	local ICON_SIZE = 75
	local ICON_POSITION = UDim2.fromOffset(0, 4)

	-- Number area.
	local NUMBER_AREA_POSITION = UDim2.fromOffset(80, 10)
	local NUMBER_AREA_SIZE = Vector2.new(320, 76)

	-- Per-character dimensions.
	local DIGIT_WIDTH = 20
	local COMMA_WIDTH = 9
	local DIGIT_HEIGHT = 72

	-- Number appearance.
	local NUMBER_MIN_TEXT_SIZE = 28
	local NUMBER_MAX_TEXT_SIZE = 68
	local NUMBER_OUTLINE_THICKNESS = 3.3
	local NUMBER_COLOR = Color3.fromRGB(255, 255, 255)
	local NUMBER_OUTLINE_COLOR = Color3.fromRGB(0, 10, 21)

	-- Slower than the previous rolling animation.
	local ROLL_TIME = 0.65

	-- ============================================================

	if deps.authoredUiV2 and deps.findAuthoredHost then
		local coinsHud = deps.findAuthoredHost("CoinsHud", "GuiObject")
		local icon = coinsHud and coinsHud:FindFirstChild("CoinIcon")
		local coinsText = coinsHud and coinsHud:FindFirstChild("CoinsText")

		if coinsHud
			and icon
			and icon:IsA("ImageLabel")
			and coinsText
			and coinsText:IsA("TextLabel")
		then
			-- The authored instances own layout and device scaling.  This module
			-- only supplies the live asset/data and the compatibility refs used by
			-- FishingClient.
			icon.Image = COIN_ICON_IMAGE
			coinsHud.Visible = true
			coinsText.Text = "0"

			refs.coinsHud = coinsHud
			refs.coinIcon = icon
			refs.coinNumberArea = coinsHud
			refs.coinsText = coinsText

			function refs.updateCoins(coins)
				coinsText.Text = formatNumber(coins)
			end

			local function getCompatibilityLabel(name)
				local existing = screenGui:FindFirstChild(name)
				if existing and existing:IsA("TextLabel") then
					return existing
				end

				local label = Instance.new("TextLabel")
				label.Name = name
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromOffset(0, 0)
				label.Text = ""
				label.TextTransparency = 1
				label.Visible = false
				label.Parent = screenGui
				return label
			end

			refs.statsText = getCompatibilityLabel("LegacyStatsText")
			refs.statusText = getCompatibilityLabel("LegacyStatusText")
			return
		end

		warn("[CoinsHud] Authored CoinsHud is incomplete; using the legacy fallback")
	end

	local coinsHud = Instance.new("Frame")
	coinsHud.Name = "CoinsHud"
	coinsHud.AnchorPoint = Vector2.new(0, 0)
	coinsHud.Position = COINS_HUD_POSITION
	coinsHud.Size = COINS_HUD_SIZE
	coinsHud.BackgroundTransparency = 1
	coinsHud.BorderSizePixel = 0
	coinsHud.Visible = true
	coinsHud.ZIndex = 1000
	coinsHud.ClipsDescendants = false
	coinsHud.Parent = screenGui

	local icon = Instance.new("ImageLabel")
	icon.Name = "CoinIcon"
	icon.Position = ICON_POSITION
	icon.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Image = COIN_ICON_IMAGE
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 1001
	icon.Parent = coinsHud

	local numberArea = Instance.new("Frame")
	numberArea.Name = "NumberArea"
	numberArea.Position = NUMBER_AREA_POSITION
	numberArea.Size = UDim2.fromOffset(NUMBER_AREA_SIZE.X, NUMBER_AREA_SIZE.Y)
	numberArea.BackgroundTransparency = 1
	numberArea.BorderSizePixel = 0
	numberArea.ClipsDescendants = false
	numberArea.ZIndex = 1001
	numberArea.Parent = coinsHud

	local digitsHolder = Instance.new("Frame")
	digitsHolder.Name = "DigitsHolder"
	digitsHolder.AnchorPoint = Vector2.new(0, 0.5)
	digitsHolder.Position = UDim2.fromScale(0, 0.5)
	digitsHolder.Size = UDim2.fromOffset(0, DIGIT_HEIGHT)
	digitsHolder.BackgroundTransparency = 1
	digitsHolder.BorderSizePixel = 0
	digitsHolder.ClipsDescendants = false
	digitsHolder.ZIndex = 1002
	digitsHolder.Parent = numberArea

	local digitsScale = Instance.new("UIScale")
	digitsScale.Name = "DigitsScale"
	digitsScale.Scale = 1
	digitsScale.Parent = digitsHolder

	local function createCharacterLabel(parent, name, character)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.AnchorPoint = Vector2.new(0, 0)
		label.Position = UDim2.fromScale(0, 0)
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Text = character
		label.TextColor3 = NUMBER_COLOR
		label.TextTransparency = 0
		label.TextScaled = true
		label.TextWrapped = false
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Font = Enum.Font.GothamBlack
		label.ZIndex = 1004
		label.Parent = parent

		local textSizeConstraint = Instance.new("UITextSizeConstraint")
		textSizeConstraint.MinTextSize = NUMBER_MIN_TEXT_SIZE
		textSizeConstraint.MaxTextSize = NUMBER_MAX_TEXT_SIZE
		textSizeConstraint.Parent = label

		local outline = Instance.new("UIStroke")
		outline.Name = "NumberOutline"
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		outline.Color = NUMBER_OUTLINE_COLOR
		outline.Thickness = NUMBER_OUTLINE_THICKNESS
		outline.Transparency = 0
		outline.LineJoinMode = Enum.LineJoinMode.Round
		outline.Parent = label

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
			if child ~= digitsScale then
				child:Destroy()
			end
		end
	end

	local function configureHolderWidth(formatted)
		local totalWidth = getTotalWidth(formatted)
		digitsHolder.Size = UDim2.fromOffset(totalWidth, DIGIT_HEIGHT)

		if totalWidth > NUMBER_AREA_SIZE.X then
			digitsScale.Scale = NUMBER_AREA_SIZE.X / totalWidth
		else
			digitsScale.Scale = 1
		end
	end

	local function createSlot(xOffset, width)
		local slot = Instance.new("Frame")
		slot.Name = "DigitSlot"
		slot.Position = UDim2.fromOffset(xOffset, 0)
		slot.Size = UDim2.fromOffset(width, DIGIT_HEIGHT)
		slot.BackgroundTransparency = 1
		slot.BorderSizePixel = 0
		slot.ClipsDescendants = true
		slot.ZIndex = 1003
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

		refs.coinsText.Text = formatted
	end

	local function getOldCharacterForNewPosition(oldText, newText, newIndex)
		-- Compare characters from the right side so unchanged place values
		-- stay still even when commas or digit counts change.
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
			refs.coinsText.Text = formatNumber(value)
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
		refs.coinsText.Text = newFormatted
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
				-- Commas and unchanged digits remain still.
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
					Position = increasing
						and UDim2.fromScale(0, -1)
						or UDim2.fromScale(0, 1),
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

	-- Compatibility label retained for the existing FishingClient.
	refs.coinsText = Instance.new("TextLabel")
	refs.coinsText.Name = "CoinsText"
	refs.coinsText.Size = UDim2.fromOffset(0, 0)
	refs.coinsText.BackgroundTransparency = 1
	refs.coinsText.TextTransparency = 1
	refs.coinsText.Visible = false
	refs.coinsText.Text = "0"
	refs.coinsText.Parent = screenGui

	refs.coinsHud = coinsHud
	refs.coinIcon = icon
	refs.coinNumberArea = numberArea

	function refs.updateCoins(coins)
		animateTo(coins)
	end

	-- Legacy hidden labels retained so older FishingClient code stays compatible.
	refs.statsText = Instance.new("TextLabel")
	refs.statsText.Name = "LegacyStatsText"
	refs.statsText.BackgroundTransparency = 1
	refs.statsText.Size = UDim2.fromOffset(0, 0)
	refs.statsText.Visible = false
	refs.statsText.Parent = screenGui

	refs.statusText = Instance.new("TextLabel")
	refs.statusText.Name = "LegacyStatusText"
	refs.statusText.BackgroundTransparency = 1
	refs.statusText.Size = UDim2.fromOffset(0, 0)
	refs.statusText.Visible = false
	refs.statusText.Parent = screenGui
end

return CoinsHud
