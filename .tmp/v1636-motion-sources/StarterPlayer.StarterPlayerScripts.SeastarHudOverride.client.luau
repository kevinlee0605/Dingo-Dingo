-- SeaStarHudOverride.client.luau
-- Put this LocalScript in: StarterPlayer > StarterPlayerScripts
-- This script keeps the existing Sea Star HUD position, hides the old visuals,
-- and rebuilds only the icon + number in the same style as the coin HUD.

print("[SeaStarHudOverride] STARTED")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local GetState = Remotes:WaitForChild("GetState")
local StateUpdated = Remotes:WaitForChild("StateUpdated")

local SEA_STAR_ICON = "rbxassetid://102284604663190"

local HUD_SIZE = UDim2.fromOffset(330, 96)
local ICON_SIZE = 75
local ICON_POSITION = UDim2.fromOffset(0, 4)
local NUMBER_AREA_POSITION = UDim2.fromOffset(80, 10)
local NUMBER_AREA_SIZE = Vector2.new(240, 76)

local DIGIT_WIDTH = 20
local COMMA_WIDTH = 9
local DIGIT_HEIGHT = 72

local NUMBER_MIN_TEXT_SIZE = 28
local NUMBER_MAX_TEXT_SIZE = 68
local NUMBER_OUTLINE_THICKNESS = 3.3
local NUMBER_COLOR = Color3.fromRGB(255, 255, 255)
local NUMBER_OUTLINE_COLOR = Color3.fromRGB(0, 10, 21)
local ROLL_TIME = 0.65

local VISUAL_NAME = "SeaStarCoinStyleVisual"
local currentValue = 0
local hasInitialized = false
local activeTweens = {}
local animationSerial = 0
local boundRoot = nil
local digitsHolder = nil
local digitsScale = nil

local function formatNumber(value)
	value = math.max(0, math.floor(tonumber(value) or 0))
	local text = tostring(value)
	while true do
		local replaced, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = replaced
		if count == 0 then
			break
		end
	end
	return text
end

local function normalizedText(value)
	return string.upper(
		tostring(value or "")
			:gsub("_", " ")
			:gsub("%s+", " ")
			:match("^%s*(.-)%s*$")
	)
end

local function isSeaStarText(value)
	local text = normalizedText(value)
	return text == "SEA STARS"
		or text == "SEASTARS"
		or string.find(text, "SEA STARS:", 1, true) == 1
end

local function isInsideNewVisual(instance)
	local current = instance
	while current do
		if current.Name == VISUAL_NAME then
			return true
		end
		current = current.Parent
	end
	return false
end

local function findLegacyRoot()
	local named = playerGui:FindFirstChild("SeaStarLoginHud", true)
	if named and named:IsA("GuiObject") then
		return named
	end

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if (descendant:IsA("TextLabel") or descendant:IsA("TextButton"))
			and isSeaStarText(descendant.Text)
		then
			local current = descendant
			for _ = 1, 6 do
				current = current.Parent
				if not current then
					break
				end
				if current:IsA("Frame") or current:IsA("GuiButton") then
					return current
				end
			end
		end
	end

	return nil
end

local function findExistingClickButton(root)
	if root:IsA("GuiButton") then
		return root
	end

	local best = nil
	local bestArea = -1

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiButton") and not isInsideNewVisual(descendant) then
			local size = descendant.AbsoluteSize
			local area = size.X * size.Y
			if area > bestArea then
				best = descendant
				bestArea = area
			end
		end
	end

	return best
end

local function hideLegacyAppearance(root, clickButton)
	for _, descendant in ipairs(root:GetDescendants()) do
		if isInsideNewVisual(descendant) then
			continue
		end

		if descendant:IsA("UIStroke") then
			descendant.Transparency = 1
		elseif descendant:IsA("TextLabel") then
			descendant.TextTransparency = 1
			descendant.TextStrokeTransparency = 1
			descendant.BackgroundTransparency = 1
		elseif descendant:IsA("TextButton") then
			descendant.TextTransparency = 1
			descendant.TextStrokeTransparency = 1
			descendant.BackgroundTransparency = 1
			if descendant ~= clickButton then
				descendant.Active = false
			end
		elseif descendant:IsA("ImageLabel") then
			descendant.ImageTransparency = 1
			descendant.BackgroundTransparency = 1
		elseif descendant:IsA("ImageButton") then
			descendant.ImageTransparency = 1
			descendant.BackgroundTransparency = 1
			if descendant ~= clickButton then
				descendant.Active = false
			end
		elseif descendant:IsA("Frame") then
			descendant.BackgroundTransparency = 1
		end
	end

	if clickButton then
		clickButton.Visible = true
		clickButton.Active = true
		clickButton.AutoButtonColor = false
		clickButton.AnchorPoint = Vector2.zero
		clickButton.Position = UDim2.fromScale(0, 0)
		clickButton.Size = UDim2.fromScale(1, 1)
		clickButton.BackgroundTransparency = 1
		clickButton.ZIndex = 5005

		if clickButton:IsA("TextButton") then
			clickButton.TextTransparency = 1
			clickButton.TextStrokeTransparency = 1
		elseif clickButton:IsA("ImageButton") then
			clickButton.ImageTransparency = 1
		end
	end
end

local function createCharacterLabel(parent, name, character)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.zero
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
	label.ZIndex = 5004
	label.Parent = parent

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MinTextSize = NUMBER_MIN_TEXT_SIZE
	sizeConstraint.MaxTextSize = NUMBER_MAX_TEXT_SIZE
	sizeConstraint.Parent = label

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
	return character == "," and COMMA_WIDTH or DIGIT_WIDTH
end

local function getTotalWidth(text)
	local total = 0
	for index = 1, #text do
		total += getCharacterWidth(string.sub(text, index, index))
	end
	return total
end

local function cancelActiveTweens()
	for _, tween in ipairs(activeTweens) do
		tween:Cancel()
	end
	table.clear(activeTweens)
end

local function clearDigitSlots()
	if not digitsHolder then
		return
	end

	for _, child in ipairs(digitsHolder:GetChildren()) do
		if child ~= digitsScale then
			child:Destroy()
		end
	end
end

local function configureHolderWidth(formatted)
	if not digitsHolder or not digitsScale then
		return
	end

	local totalWidth = getTotalWidth(formatted)
	digitsHolder.Size = UDim2.fromOffset(totalWidth, DIGIT_HEIGHT)
	digitsScale.Scale = totalWidth > NUMBER_AREA_SIZE.X
		and (NUMBER_AREA_SIZE.X / totalWidth)
		or 1
end

local function createSlot(xOffset, width)
	local slot = Instance.new("Frame")
	slot.Name = "DigitSlot"
	slot.Position = UDim2.fromOffset(xOffset, 0)
	slot.Size = UDim2.fromOffset(width, DIGIT_HEIGHT)
	slot.BackgroundTransparency = 1
	slot.BorderSizePixel = 0
	slot.ClipsDescendants = true
	slot.ZIndex = 5003
	slot.Parent = digitsHolder
	return slot
end

local function renderImmediate(value)
	if not digitsHolder then
		currentValue = math.max(0, math.floor(tonumber(value) or 0))
		return
	end

	cancelActiveTweens()
	clearDigitSlots()

	currentValue = math.max(0, math.floor(tonumber(value) or 0))
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
	value = math.max(0, math.floor(tonumber(value) or 0))

	if not digitsHolder then
		currentValue = value
		return
	end

	if not hasInitialized then
		hasInitialized = true
		renderImmediate(value)
		return
	end

	if value == currentValue then
		return
	end

	cancelActiveTweens()
	clearDigitSlots()

	animationSerial += 1
	local thisAnimation = animationSerial

	local oldFormatted = formatNumber(currentValue)
	local newFormatted = formatNumber(value)
	local increasing = value > currentValue

	currentValue = value
	configureHolderWidth(newFormatted)

	local xOffset = 0
	local changedDigitCount = 0

	for newIndex = 1, #newFormatted do
		local newCharacter = string.sub(newFormatted, newIndex, newIndex)
		local oldCharacter = getOldCharacterForNewPosition(
			oldFormatted,
			newFormatted,
			newIndex
		)
		local width = getCharacterWidth(newCharacter)
		local slot = createSlot(xOffset, width)

		local isDigit = string.match(newCharacter, "%d") ~= nil
		local changed = oldCharacter ~= newCharacter

		if not isDigit or not changed then
			createCharacterLabel(slot, "StaticCharacter", newCharacter)
		else
			changedDigitCount += 1

			local outgoing = createCharacterLabel(
				slot,
				"OutgoingCharacter",
				oldCharacter
			)
			if oldCharacter == ""
				or string.match(oldCharacter, "%d") == nil
			then
				outgoing.TextTransparency = 1
			end

			local incoming = createCharacterLabel(
				slot,
				"IncomingCharacter",
				newCharacter
			)
			incoming.Position = increasing
				and UDim2.fromScale(0, 1)
				or UDim2.fromScale(0, -1)
			incoming.TextTransparency = 0.08

			local tweenInfo = TweenInfo.new(
				ROLL_TIME,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			)

			local outgoingTween = TweenService:Create(
				outgoing,
				tweenInfo,
				{
					Position = increasing
						and UDim2.fromScale(0, -1)
						or UDim2.fromScale(0, 1),
					TextTransparency = 0.35,
				}
			)

			local incomingTween = TweenService:Create(
				incoming,
				tweenInfo,
				{
					Position = UDim2.fromScale(0, 0),
					TextTransparency = 0,
				}
			)

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
		if thisAnimation == animationSerial then
			renderImmediate(value)
		end
	end)
end

local function hideDuplicateLegacyHuds(primaryRoot)
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant ~= primaryRoot
			and descendant.Name == "SeaStarLoginHud"
			and descendant:IsA("GuiObject")
		then
			descendant.Visible = false
		end
	end

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if (descendant:IsA("TextLabel") or descendant:IsA("TextButton"))
			and isSeaStarText(descendant.Text)
			and not descendant:IsDescendantOf(primaryRoot)
		then
			local current = descendant.Parent
			while current and current ~= playerGui do
				if current:IsA("GuiObject") then
					current.Visible = false
					break
				end
				current = current.Parent
			end
		end
	end
end

local function buildVisual(root)
	local previous = root:FindFirstChild(VISUAL_NAME)
	if previous then
		previous:Destroy()
	end

	root.Visible = true
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ClipsDescendants = false
	root.Size = HUD_SIZE
	root.ZIndex = math.max(root.ZIndex, 5000)

	local clickButton = findExistingClickButton(root)
	hideLegacyAppearance(root, clickButton)
	hideDuplicateLegacyHuds(root)

	local visual = Instance.new("Frame")
	visual.Name = VISUAL_NAME
	visual.AnchorPoint = Vector2.zero
	visual.Position = UDim2.fromScale(0, 0)
	visual.Size = UDim2.fromScale(1, 1)
	visual.BackgroundTransparency = 1
	visual.BorderSizePixel = 0
	visual.Active = false
	visual.ZIndex = 5001
	visual.Parent = root

	local icon = Instance.new("ImageLabel")
	icon.Name = "SeaStarIcon"
	icon.Position = ICON_POSITION
	icon.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Image = SEA_STAR_ICON
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 5002
	icon.Parent = visual

	local numberArea = Instance.new("Frame")
	numberArea.Name = "NumberArea"
	numberArea.Position = NUMBER_AREA_POSITION
	numberArea.Size = UDim2.fromOffset(
		NUMBER_AREA_SIZE.X,
		NUMBER_AREA_SIZE.Y
	)
	numberArea.BackgroundTransparency = 1
	numberArea.BorderSizePixel = 0
	numberArea.ClipsDescendants = false
	numberArea.ZIndex = 5002
	numberArea.Parent = visual

	digitsHolder = Instance.new("Frame")
	digitsHolder.Name = "DigitsHolder"
	digitsHolder.AnchorPoint = Vector2.new(0, 0.5)
	digitsHolder.Position = UDim2.fromScale(0, 0.5)
	digitsHolder.Size = UDim2.fromOffset(0, DIGIT_HEIGHT)
	digitsHolder.BackgroundTransparency = 1
	digitsHolder.BorderSizePixel = 0
	digitsHolder.ClipsDescendants = false
	digitsHolder.ZIndex = 5003
	digitsHolder.Parent = numberArea

	digitsScale = Instance.new("UIScale")
	digitsScale.Name = "DigitsScale"
	digitsScale.Scale = 1
	digitsScale.Parent = digitsHolder

	if clickButton then
		clickButton.ZIndex = 5005
	end

	boundRoot = root
	hasInitialized = false
	renderImmediate(currentValue)

	print(
		"[SeaStarHudOverride] HUD REBUILT:",
		root:GetFullName()
	)
end

local binding = false

local function ensureBound()
	if binding then
		return
	end
	binding = true

	local root = findLegacyRoot()
	if root then
		if root ~= boundRoot
			or not root:FindFirstChild(VISUAL_NAME)
		then
			buildVisual(root)
		else
			local clickButton = findExistingClickButton(root)
			hideLegacyAppearance(root, clickButton)
			hideDuplicateLegacyHuds(root)
			root.Visible = true
			root.Size = HUD_SIZE
		end
	end

	binding = false
end

local function receiveState(newState)
	if type(newState) ~= "table" then
		return
	end

	local nextValue = math.max(
		0,
		math.floor(tonumber(newState.SeaStars) or 0)
	)

	ensureBound()
	animateTo(nextValue)
end

StateUpdated.OnClientEvent:Connect(receiveState)

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "SeaStarLoginHud"
		or descendant.Name == "FishyFishPhase3Gui"
		or (descendant:IsA("TextLabel") and isSeaStarText(descendant.Text))
		or (descendant:IsA("TextButton") and isSeaStarText(descendant.Text))
	then
		task.defer(ensureBound)
	end
end)

task.spawn(function()
	local success, initialState = pcall(function()
		return GetState:InvokeServer()
	end)

	if success then
		receiveState(initialState)
	else
		warn(
			"[SeaStarHudOverride] GetState failed:",
			initialState
		)
	end
end)

-- The old UI script may finish building after this script.
-- Re-apply the override without changing the saved HUD position.
task.spawn(function()
	while player.Parent do
		ensureBound()
		task.wait(1)
	end
end)
