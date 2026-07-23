local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))
local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local GetState = Remotes:WaitForChild("GetState")
local StateUpdated = Remotes:WaitForChild("StateUpdated")
local ShopAction = Remotes:WaitForChild("ShopAction")
local LoginRewardAction = Remotes:WaitForChild("LoginRewardAction")
local OpenShop = Remotes:WaitForChild("OpenShop", 10)

local COLORS = {
	panel = Color3.fromRGB(18, 22, 29),
	card = Color3.fromRGB(29, 36, 47),
	cardAlt = Color3.fromRGB(38, 45, 57),
	stroke = Color3.fromRGB(71, 85, 105),
	muted = Color3.fromRGB(190, 204, 220),
	blue = Color3.fromRGB(53, 130, 246),
	green = Color3.fromRGB(28, 160, 92),
	gold = Color3.fromRGB(255, 181, 36),
	sea = Color3.fromRGB(58, 174, 205),
	disabled = Color3.fromRGB(86, 98, 115),
}

local state = nil
local stateReceivedAt = os.clock()
local activeShopTab = "Sea Stars"
local autoOpenEvaluated = false
local loginOpenedAutomatically = false
local requestedMidnightRefresh = false
local pendingClaimAnimationDay = nil

local makeText

local DAILY_REWARD_ASSETS = {
	LeftBelowDecoration = "rbxassetid://93536836630458",
	ClaimButton = "rbxassetid://139579773560573",
	UnlockedDayTab = "rbxassetid://135195025090058",
	TodayTab = "rbxassetid://119253493497690",
	PurpleTab = "rbxassetid://105275297050616",
	RedTab = "rbxassetid://109003915454192",
	DoneIcon = "rbxassetid://94167472129143",
	MainFrame = "rbxassetid://117777143534466",
	CloseButton = "rbxassetid://119322438066977",
	LeftTopDecoration = "rbxassetid://113416899840266",
	ScrollBar = "rbxassetid://73367138577137",
	SpecialDayIcon = "rbxassetid://70463548759658",
	LuckyBaitIcon = "rbxassetid://115001329325653",
	FreshBaitIcon = "rbxassetid://114397365249536",
	CoinIcon = "rbxassetid://127404869799608",
}

local DAILY_TAB_CROPS = {
	Unlocked = { Offset = Vector2.new(128, 140), Size = Vector2.new(1194, 806) },
	Today = { Offset = Vector2.new(93, 166), Size = Vector2.new(1260, 751) },
	Purple = { Offset = Vector2.new(98, 190), Size = Vector2.new(1252, 707) },
	Red = { Offset = Vector2.new(86, 158), Size = Vector2.new(1265, 756) },
}

local CLAIM_BUTTON_CROP = {
	Offset = Vector2.new(68, 272),
	Size = Vector2.new(1543, 431),
}

local TRIMMED_IMAGE_SIZES = {
	DayTab = Vector2.new(1448, 1086),
	ClaimButton = Vector2.new(1672, 941),
	ScrollBar = Vector2.new(1448, 1086),
}

local function applyVirtualCrop(image, fullSize, crop)
	image.Position = UDim2.new(-(crop.Offset.X / crop.Size.X), 0, -(crop.Offset.Y / crop.Size.Y), 0)
	image.Size = UDim2.new(fullSize.X / crop.Size.X, 0, fullSize.Y / crop.Size.Y, 0)
	image.ScaleType = Enum.ScaleType.Stretch
end

local function makeImage(parent, imageId)
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = imageId or ""
	image.Parent = parent
	return image
end

local function makeImageButton(parent, imageId)
	local button = Instance.new("ImageButton")
	button.BackgroundTransparency = 1
	button.AutoButtonColor = true
	button.Image = imageId or ""
	button.Parent = parent
	return button
end

local function styleOutlinedText(label, strokeColor)
	label.TextStrokeColor3 = strokeColor or Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	return label
end

local function makeOutlinedText(parent, text, size, color, bold)
	local label = makeText(parent, text, size, color, bold)
	styleOutlinedText(label)
	return label
end


local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or COLORS.stroke
	stroke.Thickness = thickness or 1
	stroke.Parent = instance
	return stroke
end

function makeText(parent, text, size, color, bold)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextSize = size or 14
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function makeButton(parent, text, color)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or COLORS.blue
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 13
	button.TextWrapped = true
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	addCorner(button, 7)
	return button
end

local function clearContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

-- Use a unique ScreenGui name so an old duplicate Phase3 LocalScript cannot
-- destroy this corrected UI when it starts later.
local FIXED_GUI_NAME = "FishyFishPhase3Gui_SeaStarHudFixed"
local LEGACY_GUI_NAME = "FishyFishPhase3Gui"

for _, guiName in ipairs({ FIXED_GUI_NAME, LEGACY_GUI_NAME }) do
	local existing = playerGui:FindFirstChild(guiName)
	if existing then
		existing:Destroy()
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = FIXED_GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 1001
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Some projects still contain a second copy of the old Phase3 LocalScript.
-- That old copy creates FishyFishPhase3Gui after this script and brings back
-- the yellow star, the blue SEA STARS text, and the old number. Remove only
-- those legacy copies while keeping this corrected GUI alive.
local legacyCleanupScheduled = false
local function removeLegacySeaStarUi()
	legacyCleanupScheduled = false

	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child ~= gui and child.Name == LEGACY_GUI_NAME then
			child:Destroy()
		end
	end

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant.Name == "SeaStarLoginHud" and not descendant:IsDescendantOf(gui) then
			descendant:Destroy()
		end
	end
end

local function scheduleLegacySeaStarCleanup()
	if legacyCleanupScheduled then
		return
	end
	legacyCleanupScheduled = true
	task.defer(removeLegacySeaStarUi)
end

playerGui.ChildAdded:Connect(scheduleLegacySeaStarCleanup)
playerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == LEGACY_GUI_NAME or descendant.Name == "SeaStarLoginHud" then
		scheduleLegacySeaStarCleanup()
	end
end)

task.defer(removeLegacySeaStarUi)

local function createSeaStarHud()
	-- Same screen anchor and position as the previous Sea Star button.
	-- The blue button and the "SEA STARS" wording are intentionally removed.
	local SEA_STAR_ICON_IMAGE = "rbxassetid://102284604663190"
	local HUD_POSITION = UDim2.new(1, -18, 0, 18)
	local HUD_SIZE = UDim2.fromOffset(300, 82)
	local ICON_SIZE = 74
	local ICON_POSITION = UDim2.fromOffset(0, 4)
	local NUMBER_AREA_POSITION = UDim2.fromOffset(78, 3)
	local NUMBER_AREA_SIZE = Vector2.new(214, 76)
	local DIGIT_WIDTH = 25
	local COMMA_WIDTH = 11
	local DIGIT_HEIGHT = 72
	local NUMBER_MIN_TEXT_SIZE = 28
	local NUMBER_MAX_TEXT_SIZE = 66
	local NUMBER_OUTLINE_THICKNESS = 3.3
	local NUMBER_COLOR = Color3.fromRGB(255, 255, 255)
	local NUMBER_OUTLINE_COLOR = Color3.fromRGB(0, 10, 21)
	local ROLL_TIME = 0.65

	local result = {}

	local root = Instance.new("Frame")
	root.Name = "SeaStarLoginHud"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = HUD_POSITION
	root.Size = HUD_SIZE
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Visible = true
	root.ZIndex = 1000
	root.ClipsDescendants = false
	root.Parent = gui

	-- Transparent click target preserves the old behavior of opening the Sea Star shop.
	local button = Instance.new("TextButton")
	button.Name = "SeaStarButton"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.Active = true
	button.ZIndex = 1000
	button.Parent = root

	local icon = Instance.new("ImageLabel")
	icon.Name = "SeaStarIcon"
	icon.Position = ICON_POSITION
	icon.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Image = SEA_STAR_ICON_IMAGE
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 1001
	icon.Parent = root

	local numberArea = Instance.new("Frame")
	numberArea.Name = "NumberArea"
	numberArea.Position = NUMBER_AREA_POSITION
	numberArea.Size = UDim2.fromOffset(NUMBER_AREA_SIZE.X, NUMBER_AREA_SIZE.Y)
	numberArea.BackgroundTransparency = 1
	numberArea.BorderSizePixel = 0
	numberArea.ClipsDescendants = false
	numberArea.ZIndex = 1001
	numberArea.Parent = root

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

	local function formatNumber(value)
		local formatted = tostring(math.max(0, math.floor(tonumber(value) or 0)))
		local reversed = string.reverse(formatted)
		reversed = string.gsub(reversed, "(%d%d%d)", "%1,")
		formatted = string.reverse(reversed)
		return string.gsub(formatted, "^,", "")
	end

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

	local function getTotalWidth(formatted)
		local total = 0
		for index = 1, #formatted do
			total += getCharacterWidth(string.sub(formatted, index, index))
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
		slot.ZIndex = 1003
		slot.Parent = digitsHolder
		return slot
	end

	local function renderImmediate(value)
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
			if thisAnimation == animationSerial then
				renderImmediate(value)
			end
		end)
	end

	-- Small click feedback without adding a colored background.
	local pressScale = Instance.new("UIScale")
	pressScale.Name = "PressScale"
	pressScale.Scale = 1
	pressScale.Parent = root

	local function setPressed(pressed)
		TweenService:Create(
			pressScale,
			TweenInfo.new(
				pressed and 0.07 or 0.16,
				pressed and Enum.EasingStyle.Quad or Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{ Scale = pressed and 0.92 or 1 }
		):Play()
	end

	button.MouseButton1Down:Connect(function()
		setPressed(true)
	end)
	button.MouseButton1Up:Connect(function()
		setPressed(false)
	end)
	button.MouseLeave:Connect(function()
		setPressed(false)
	end)
	button.Activated:Connect(function()
		setPressed(false)
	end)

	result.root = root
	result.button = button
	result.icon = icon
	result.update = animateTo
	result.update(0)
	return result
end

local seaStarHud = createSeaStarHud()

local loginButtonActivated = Instance.new("BindableEvent")
loginButtonActivated.Name = "LoginRewardTopButtonActivated"

local loginButton = nil

local function chooseIconDescendant(button)
	local best = nil
	local bestScore = -math.huge
	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			local size = descendant.Size
			local score = math.abs(size.X.Scale) * 1000
				+ math.abs(size.Y.Scale) * 1000
				+ math.abs(size.X.Offset)
				+ math.abs(size.Y.Offset)
			if score > bestScore then
				best = descendant
				bestScore = score
			end
		end
	end
	return best
end

local function waitForNamedDescendant(root, name, timeoutSeconds)
	local deadline = os.clock() + (timeoutSeconds or 15)
	repeat
		local found = root:FindFirstChild(name, true)
		if found then
			return found
		end
		task.wait(0.1)
	until os.clock() >= deadline
	return nil
end

local function installTopButtonPressEffect(button, icon)
	-- Exact copy of TopButtonsHud.makeTopHudButton press behavior.
	button.AutoButtonColor = true

	local pressScale = button:FindFirstChild("PressScale")
	if not pressScale or not pressScale:IsA("UIScale") then
		pressScale = Instance.new("UIScale")
		pressScale.Name = "PressScale"
		pressScale.Scale = 1
		pressScale.Parent = button
	end

	local shadow = button:FindFirstChild("IconShadow")
	if not shadow or not shadow:IsA("Frame") then
		shadow = Instance.new("Frame")
		shadow.Name = "IconShadow"
		shadow.AnchorPoint = Vector2.new(0.5, 0.5)
		shadow.Position = UDim2.fromScale(0.5, 0.5)
		shadow.Size = UDim2.fromScale(0.82, 0.82)
		shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		shadow.BackgroundTransparency = 0.55
		shadow.BorderSizePixel = 0
		shadow.ZIndex = button.ZIndex
		shadow.Parent = button

		local shadowCorner = Instance.new("UICorner")
		shadowCorner.CornerRadius = UDim.new(1, 0)
		shadowCorner.Parent = shadow
	end

	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.82, 0.82)
	icon.ZIndex = math.max(icon.ZIndex, button.ZIndex + 1)

	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.fromScale(0.5, 0.5)
	shadow.Size = UDim2.fromScale(0.82, 0.82)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.55

	local pressTweenInfo = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local releaseTweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local isPressed = false

	local function tweenPressed(pressed)
		if isPressed == pressed then
			return
		end

		isPressed = pressed
		local tweenInfo = pressed and pressTweenInfo or releaseTweenInfo

		TweenService:Create(pressScale, tweenInfo, {
			Scale = pressed and 0.88 or 1,
		}):Play()

		TweenService:Create(icon, tweenInfo, {
			Position = pressed and UDim2.fromScale(0.5, 0.56) or UDim2.fromScale(0.5, 0.5),
			Size = pressed and UDim2.fromScale(0.74, 0.74) or UDim2.fromScale(0.82, 0.82),
		}):Play()

		TweenService:Create(shadow, tweenInfo, {
			Size = pressed and UDim2.fromScale(0.76, 0.76) or UDim2.fromScale(0.82, 0.82),
			BackgroundTransparency = pressed and 0.43 or 0.55,
		}):Play()
	end

	button.MouseButton1Down:Connect(function()
		tweenPressed(true)
	end)

	button.MouseButton1Up:Connect(function()
		tweenPressed(false)
	end)

	button.MouseLeave:Connect(function()
		tweenPressed(false)
	end)

	button.Activated:Connect(function()
		tweenPressed(false)
	end)
end

local function mountLoginButtonToForcedTopFrame()
	local forcedTopGui = playerGui:WaitForChild("ForcedTopHudGui", 30)
	if not forcedTopGui then
		warn("[DailyReward] ForcedTopHudGui was not found.")
		return
	end

	local forcedFrame = forcedTopGui:WaitForChild("ForcedTopButtonsFrame", 30)
	if not forcedFrame or not forcedFrame:IsA("Frame") then
		warn("[DailyReward] ForcedTopButtonsFrame was not found.")
		return
	end

	-- The frame is often created before Settings/Quests/Shop are reparented into it.
	-- Wait until ShopButton actually exists instead of exiting immediately.
	local shopButton = waitForNamedDescendant(forcedFrame, "ShopButton", 20)
	if not shopButton then
		shopButton = waitForNamedDescendant(playerGui, "ShopButton", 10)
	end
	if not shopButton or not shopButton:IsA("GuiButton") then
		warn("[DailyReward] ShopButton did not appear, so the top reward button could not be cloned.")
		return
	end

	local previous = forcedFrame:FindFirstChild("DailyRewardButton")
	if previous then
		previous:Destroy()
	end

	local button = shopButton:Clone()
	button.Name = "DailyRewardButton"
	button.LayoutOrder = math.max(4, (shopButton.LayoutOrder or 0) + 1)
	button.Visible = true
	button.Active = true
	button.AutoButtonColor = shopButton.AutoButtonColor
	button.ZIndex = math.max(10001, shopButton.ZIndex)

	if button:IsA("TextButton") then
		button.Text = ""
	elseif button:IsA("ImageButton") then
		-- Preserve the circular background styling but remove a shop icon stored
		-- directly on the button itself.
		button.Image = ""
	end

	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			descendant.Text = ""
		end
	end

	-- Replace the most likely existing icon. If the cloned button has no icon
	-- child, add a new centered ImageLabel while keeping the cloned circle.
	local icon = nil
	for _, descendant in ipairs(button:GetDescendants()) do
		if (descendant:IsA("ImageLabel") or descendant:IsA("ImageButton"))
			and string.find(string.lower(descendant.Name), "icon", 1, true) then
			icon = descendant
			break
		end
	end
	if not icon then
		icon = chooseIconDescendant(button)
	end

	if icon then
		icon.Image = "rbxassetid://78408484505332"
		icon.ImageRectOffset = Vector2.zero
		icon.ImageRectSize = Vector2.zero
		icon.ScaleType = Enum.ScaleType.Fit
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(0.82, 0.82)
		icon.Visible = true
		icon.ZIndex = button.ZIndex + 1
		if icon:IsA("ImageButton") then
			icon.Active = false
			icon.AutoButtonColor = false
		end
	else
		icon = Instance.new("ImageLabel")
		icon.Name = "DailyRewardIcon"
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(0.82, 0.82)
		icon.Image = "rbxassetid://78408484505332"
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = button.ZIndex + 1
		icon.Parent = button
	end

	button.Parent = forcedFrame

	-- Four 64px buttons with the existing 14px spacing.
	forcedFrame.AnchorPoint = Vector2.new(0.5, 0)
	forcedFrame.Position = UDim2.new(0.5, 0, 0, 12)
	forcedFrame.Size = UDim2.fromOffset(298, 64)
	forcedFrame.BackgroundTransparency = 1
	forcedFrame.ClipsDescendants = false
	forcedFrame.ZIndex = 10000

	local layout = forcedFrame:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 14)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
	else
		button.AnchorPoint = Vector2.new(0, 0)
		button.Position = UDim2.fromOffset(234, 0)
		button.Size = UDim2.fromOffset(64, 64)
	end

	-- Recreate the exact TopButtonsHud press tween because cloned Instances do not
	-- carry over the original RBXScriptSignal connections.
	installTopButtonPressEffect(button, icon)

	button.Activated:Connect(function()
		loginButtonActivated:Fire()
	end)
	loginButton = button

	-- Another positioning script can reset this frame to its original 3-button
	-- width. Keep the fourth slot and visibility stable.
	local applying = false
	local function enforceFrameSettings()
		if applying or not forcedFrame.Parent or not button.Parent then
			return
		end
		applying = true
		forcedFrame.AnchorPoint = Vector2.new(0.5, 0)
		forcedFrame.Position = UDim2.new(0.5, 0, 0, 12)
		forcedFrame.Size = UDim2.fromOffset(298, 64)
		forcedFrame.BackgroundTransparency = 1
		forcedFrame.ClipsDescendants = false
		button.Visible = true
		button.Active = true
		button.LayoutOrder = 4
		applying = false
	end

	forcedFrame:GetPropertyChangedSignal("Position"):Connect(enforceFrameSettings)
	forcedFrame:GetPropertyChangedSignal("Size"):Connect(enforceFrameSettings)
	forcedFrame:GetPropertyChangedSignal("AnchorPoint"):Connect(enforceFrameSettings)
	button:GetPropertyChangedSignal("Visible"):Connect(enforceFrameSettings)
	task.defer(enforceFrameSettings)

	print("[DailyReward] Top reward button mounted with exact ShopButton press tween.")
end

task.spawn(mountLoginButtonToForcedTopFrame)

local function makeOverlay(name)
	local overlay = Instance.new("Frame")
	overlay.Name = name
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(7, 10, 15)
	overlay.BackgroundTransparency = 0.34
	overlay.Visible = false
	overlay.Parent = gui
	return overlay
end

local shopOverlay = makeOverlay("SeaStarShopOverlay")
local shopPanel = Instance.new("Frame")
shopPanel.AnchorPoint = Vector2.new(0.5, 0.5)
shopPanel.Position = UDim2.fromScale(0.5, 0.52)
shopPanel.Size = UDim2.new(0.72, 0, 0.78, 0)
shopPanel.BackgroundColor3 = COLORS.panel
shopPanel.Parent = shopOverlay
addCorner(shopPanel, 10)
addStroke(shopPanel)
local shopConstraint = Instance.new("UISizeConstraint")
shopConstraint.MinSize = Vector2.new(350, 400)
shopConstraint.MaxSize = Vector2.new(780, 650)
shopConstraint.Parent = shopPanel

local shopTitle = makeText(shopPanel, "Sea Star Shop", 22, Color3.new(1, 1, 1), true)
shopTitle.Position = UDim2.new(0, 18, 0, 10)
shopTitle.Size = UDim2.new(1, -80, 0, 34)
local shopBalance = makeText(shopPanel, "0 Sea Stars", 14, Color3.fromRGB(130, 231, 255), true)
shopBalance.Position = UDim2.new(0, 18, 0, 42)
shopBalance.Size = UDim2.new(1, -80, 0, 24)
local shopClose = makeButton(shopPanel, "X", COLORS.disabled)
shopClose.Position = UDim2.new(1, -50, 0, 12)
shopClose.Size = UDim2.fromOffset(34, 32)

local shopTabs = Instance.new("Frame")
shopTabs.Position = UDim2.new(0, 16, 0, 72)
shopTabs.Size = UDim2.new(1, -32, 0, 38)
shopTabs.BackgroundTransparency = 1
shopTabs.Parent = shopPanel
local shopTabLayout = Instance.new("UIListLayout")
shopTabLayout.FillDirection = Enum.FillDirection.Horizontal
shopTabLayout.Padding = UDim.new(0, 8)
shopTabLayout.Parent = shopTabs

local shopContent = Instance.new("ScrollingFrame")
shopContent.Position = UDim2.new(0, 16, 0, 118)
shopContent.Size = UDim2.new(1, -32, 1, -134)
shopContent.BackgroundTransparency = 1
shopContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopContent.CanvasSize = UDim2.new()
shopContent.ScrollBarThickness = 6
shopContent.Parent = shopPanel
local shopContentLayout = Instance.new("UIListLayout")
shopContentLayout.Padding = UDim.new(0, 8)
shopContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopContentLayout.Parent = shopContent

local loginOverlay = makeOverlay("LoginRewardOverlay")
loginOverlay.BackgroundTransparency = 1

-- Daily Reward uses a fixed 4:3 design canvas so wide PC screens do not stretch it.
local DAILY_REWARD_CANVAS_SIZE = Vector2.new(1400, 1050)
local loginPanel = Instance.new("Frame")
loginPanel.AnchorPoint = Vector2.new(0.5, 0.5)
loginPanel.Position = UDim2.fromScale(0.5, 0.5)
loginPanel.Size = UDim2.fromOffset(DAILY_REWARD_CANVAS_SIZE.X, DAILY_REWARD_CANVAS_SIZE.Y)
loginPanel.BackgroundTransparency = 1
loginPanel.Parent = loginOverlay

local loginScale = Instance.new("UIScale")
loginScale.Scale = 1
loginScale.Parent = loginPanel

local function updateLoginResponsiveScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1400, 1050)
	local scale = math.min(
		(viewport.X * 0.94) / DAILY_REWARD_CANVAS_SIZE.X,
		(viewport.Y * 0.94) / DAILY_REWARD_CANVAS_SIZE.Y
	)
	loginScale.Scale = math.clamp(scale, 0.50, 1)
end

local loginBackground = makeImage(loginPanel, DAILY_REWARD_ASSETS.MainFrame)
loginBackground.Size = UDim2.fromScale(1, 1)
loginBackground.ScaleType = Enum.ScaleType.Stretch

local loginTopDecoration = makeImage(loginPanel, DAILY_REWARD_ASSETS.LeftTopDecoration)
loginTopDecoration.Position = UDim2.fromOffset(36, 34)
loginTopDecoration.Size = UDim2.fromOffset(150, 150)
loginTopDecoration.ScaleType = Enum.ScaleType.Fit

local loginTitle = makeOutlinedText(loginPanel, "Daily Login Rewards", 60, Color3.new(1, 1, 1), true)
loginTitle.Position = UDim2.new(0, 0, 0, 48)
loginTitle.Size = UDim2.new(1, 0, 0, 76)
loginTitle.Font = Enum.Font.FredokaOne
loginTitle.TextXAlignment = Enum.TextXAlignment.Center
loginTitle.TextYAlignment = Enum.TextYAlignment.Center

local loginClose = makeImageButton(loginPanel, DAILY_REWARD_ASSETS.CloseButton)
loginClose.Position = UDim2.fromOffset(1180, 8)
loginClose.Size = UDim2.fromOffset(200, 200)
loginClose.ScaleType = Enum.ScaleType.Fit

-- X button press effect: quick press-in, soft spring release.
local loginClosePressScale = Instance.new("UIScale")
loginClosePressScale.Name = "PressScale"
loginClosePressScale.Scale = 1
loginClosePressScale.Parent = loginClose

local closePressTweenInfo = TweenInfo.new(
	0.07,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)
local closeReleaseTweenInfo = TweenInfo.new(
	0.16,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.Out
)
local loginClosePressed = false

local function setLoginClosePressed(pressed)
	if loginClosePressed == pressed then
		return
	end
	loginClosePressed = pressed

	TweenService:Create(
		loginClosePressScale,
		pressed and closePressTweenInfo or closeReleaseTweenInfo,
		{ Scale = pressed and 0.86 or 1 }
	):Play()
end

loginClose.MouseButton1Down:Connect(function()
	setLoginClosePressed(true)
end)

loginClose.MouseButton1Up:Connect(function()
	setLoginClosePressed(false)
end)

loginClose.MouseLeave:Connect(function()
	setLoginClosePressed(false)
end)

loginClose.Activated:Connect(function()
	setLoginClosePressed(false)
end)

local loginInfo = makeOutlinedText(loginPanel, "Missing dates never resets or skips your progress.", 22, Color3.fromRGB(210, 225, 245), false)
loginInfo.Position = UDim2.fromOffset(246, 126)
loginInfo.Size = UDim2.fromOffset(900, 30)
loginInfo.TextXAlignment = Enum.TextXAlignment.Left

local loginTimer = makeOutlinedText(loginPanel, "", 22, Color3.fromRGB(0, 237, 255), true)
loginTimer.Position = UDim2.fromOffset(246, 154)
loginTimer.Size = UDim2.fromOffset(900, 30)
loginTimer.TextXAlignment = Enum.TextXAlignment.Left

local loginGrid = Instance.new("ScrollingFrame")
loginGrid.Position = UDim2.fromOffset(76, 218)
loginGrid.Size = UDim2.fromOffset(1220, 700)
loginGrid.BackgroundTransparency = 1
loginGrid.AutomaticCanvasSize = Enum.AutomaticSize.None
loginGrid.CanvasSize = UDim2.new(0, 0, 0, 0)
loginGrid.ScrollBarThickness = 0
loginGrid.ScrollBarImageTransparency = 1
loginGrid.BorderSizePixel = 0
loginGrid.ScrollingDirection = Enum.ScrollingDirection.Y
loginGrid.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
loginGrid.ScrollingEnabled = true
loginGrid.Active = true
loginGrid.Parent = loginPanel

local DAILY_GRID_COLUMNS = 4
local DAILY_GRID_CELL_HEIGHT = 168
local DAILY_GRID_ROW_GAP = 12

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(296, DAILY_GRID_CELL_HEIGHT)
gridLayout.CellPadding = UDim2.fromOffset(12, DAILY_GRID_ROW_GAP)
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.FillDirectionMaxCells = DAILY_GRID_COLUMNS
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = loginGrid

-- Claim button position controls.
-- Increase X to move right, decrease X to move left.
-- Increase Y to move down, decrease Y to move up.
local CLAIM_BUTTON_X = 1038
local CLAIM_BUTTON_Y = 912

-- Completely rebuilt Daily Reward scrollbar.
-- The new uploaded image is the outer track only; one custom glow thumb moves inside it.
local DAILY_SCROLLBAR_X = 1303
local DAILY_SCROLLBAR_Y = 226
local DAILY_SCROLLBAR_WIDTH = 42
local DAILY_SCROLLBAR_HEIGHT = 670
local DAILY_SCROLLBAR_LANE_TOP = 0
local DAILY_SCROLLBAR_LANE_BOTTOM = 6
local DAILY_SCROLLBAR_LANE_WIDTH = 22
local DAILY_SCROLLBAR_THUMB_WIDTH = 22
local DAILY_SCROLLBAR_MIN_THUMB_HEIGHT = 76

local loginScrollbarFrame = Instance.new("Frame")
loginScrollbarFrame.Name = "DailyRewardCustomScrollbar"
loginScrollbarFrame.Position = UDim2.fromOffset(DAILY_SCROLLBAR_X, DAILY_SCROLLBAR_Y)
loginScrollbarFrame.Size = UDim2.fromOffset(DAILY_SCROLLBAR_WIDTH, DAILY_SCROLLBAR_HEIGHT)
loginScrollbarFrame.BackgroundTransparency = 1
loginScrollbarFrame.BorderSizePixel = 0
loginScrollbarFrame.ClipsDescendants = true
loginScrollbarFrame.ZIndex = 20
loginScrollbarFrame.Parent = loginPanel

-- Crop the new rbxassetid://73367138577137 source down to its visible vertical bar.
local loginScrollbarArt = makeImage(loginScrollbarFrame, DAILY_REWARD_ASSETS.ScrollBar)
applyVirtualCrop(loginScrollbarArt, TRIMMED_IMAGE_SIZES.ScrollBar, {
	Offset = Vector2.new(683, 29),
	Size = Vector2.new(65, 1021),
})
loginScrollbarArt.ZIndex = 20

-- This dark lane covers the fixed blue fill baked into the uploaded art.
-- It also becomes the exact travel area for the real moving thumb.
local scrollSlot = Instance.new("Frame")
scrollSlot.Name = "DailyRewardScrollLane"
scrollSlot.AnchorPoint = Vector2.new(0.5, 0)
scrollSlot.Position = UDim2.new(0.5, 0, 0, DAILY_SCROLLBAR_LANE_TOP)
scrollSlot.Size = UDim2.new(
	0,
	DAILY_SCROLLBAR_LANE_WIDTH,
	1,
	-(DAILY_SCROLLBAR_LANE_TOP + DAILY_SCROLLBAR_LANE_BOTTOM)
)
scrollSlot.BackgroundColor3 = Color3.fromRGB(5, 27, 73)
scrollSlot.BackgroundTransparency = 0
scrollSlot.BorderSizePixel = 0
scrollSlot.ClipsDescendants = true
scrollSlot.Active = true
scrollSlot.ZIndex = 21
scrollSlot.Parent = loginScrollbarFrame
addCorner(scrollSlot, math.floor(DAILY_SCROLLBAR_LANE_WIDTH * 0.5))

local slotGradient = Instance.new("UIGradient")
slotGradient.Rotation = 0
slotGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 48, 111)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(3, 20, 61)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 48, 111)),
})
slotGradient.Parent = scrollSlot

local loginScrollThumb = Instance.new("ImageButton")
loginScrollThumb.Name = "DailyRewardMovingThumb"
loginScrollThumb.AnchorPoint = Vector2.new(0.5, 0)
loginScrollThumb.Position = UDim2.new(0.5, 0, 0, 0)
loginScrollThumb.Size = UDim2.fromOffset(DAILY_SCROLLBAR_THUMB_WIDTH, 96)
loginScrollThumb.BackgroundColor3 = Color3.fromRGB(0, 125, 255)
loginScrollThumb.BorderSizePixel = 0
loginScrollThumb.AutoButtonColor = false
loginScrollThumb.Active = true
loginScrollThumb.Selectable = false
loginScrollThumb.ZIndex = 22
loginScrollThumb.Parent = scrollSlot
addCorner(loginScrollThumb, math.floor(DAILY_SCROLLBAR_THUMB_WIDTH * 0.5))
addStroke(loginScrollThumb, Color3.fromRGB(82, 246, 255), 2)

local loginScrollThumbGlow = Instance.new("UIGradient")
loginScrollThumbGlow.Rotation = 90
loginScrollThumbGlow.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(67, 246, 255)),
	ColorSequenceKeypoint.new(0.38, Color3.fromRGB(0, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 70, 235)),
})
loginScrollThumbGlow.Parent = loginScrollThumb

local loginScrollThumbHighlight = Instance.new("Frame")
loginScrollThumbHighlight.BackgroundColor3 = Color3.fromRGB(218, 255, 255)
loginScrollThumbHighlight.BackgroundTransparency = 0.56
loginScrollThumbHighlight.BorderSizePixel = 0
loginScrollThumbHighlight.Position = UDim2.new(0, 3, 0, 5)
loginScrollThumbHighlight.Size = UDim2.new(0, 3, 1, -10)
loginScrollThumbHighlight.ZIndex = 23
loginScrollThumbHighlight.Parent = loginScrollThumb
addCorner(loginScrollThumbHighlight, 3)

local loginBottomDecoration = makeImage(loginPanel, DAILY_REWARD_ASSETS.LeftBelowDecoration)
loginBottomDecoration.Position = UDim2.fromOffset(34, 914)
loginBottomDecoration.Size = UDim2.fromOffset(132, 116)
loginBottomDecoration.ScaleType = Enum.ScaleType.Fit

-- Intentionally blank: the requested design omits "Day N is ready".
local loginStatus = makeOutlinedText(loginPanel, "", 1, Color3.new(1, 1, 1), false)
loginStatus.Visible = false

local claimButton = Instance.new("ImageButton")
claimButton.BackgroundTransparency = 1
claimButton.Image = ""
claimButton.AutoButtonColor = true
claimButton.ClipsDescendants = true
claimButton.Position = UDim2.fromOffset(CLAIM_BUTTON_X, CLAIM_BUTTON_Y)
claimButton.Size = UDim2.fromOffset(288, 68)
claimButton.Parent = loginPanel

local claimButtonArt = makeImage(claimButton, DAILY_REWARD_ASSETS.ClaimButton)
claimButtonArt.ZIndex = claimButton.ZIndex
applyVirtualCrop(claimButtonArt, TRIMMED_IMAGE_SIZES.ClaimButton, CLAIM_BUTTON_CROP)

local claimButtonLabel = makeOutlinedText(claimButton, "Claim Day 1", 30, Color3.new(1, 1, 1), true)
claimButtonLabel.AnchorPoint = Vector2.new(0.5, 0.5)
claimButtonLabel.Position = UDim2.fromScale(0.5, 0.5)
claimButtonLabel.Size = UDim2.new(0.78, 0, 0.74, 0)
claimButtonLabel.Font = Enum.Font.FredokaOne
claimButtonLabel.TextXAlignment = Enum.TextXAlignment.Center
claimButtonLabel.TextYAlignment = Enum.TextYAlignment.Center

local draggingLoginThumb = false
local dragOffsetInsideThumb = 0

local function getLoginLogicalViewportHeight()
	local scale = math.max(loginScale.Scale, 0.001)
	local absoluteHeight = loginGrid.AbsoluteWindowSize.Y
	if absoluteHeight <= 0 then
		absoluteHeight = loginGrid.AbsoluteSize.Y
	end
	return absoluteHeight / scale
end

local function getLoginScrollMetrics()
	-- CanvasPosition and UDim2 offsets use the unscaled Daily Reward canvas.
	-- Convert AbsoluteSize back to logical coordinates so the thumb fills the lane correctly.
	local contentHeight = math.max(0, loginGrid.CanvasSize.Y.Offset)
	local viewHeight = getLoginLogicalViewportHeight()
	local scrollRange = math.max(0, contentHeight - viewHeight)
	local scale = math.max(loginScale.Scale, 0.001)
	local slotHeight = scrollSlot.AbsoluteSize.Y / scale
	local visibleRatio = contentHeight > 0 and math.clamp(viewHeight / contentHeight, 0, 1) or 1
	local thumbHeight = math.clamp(
		slotHeight * visibleRatio,
		math.min(DAILY_SCROLLBAR_MIN_THUMB_HEIGHT, slotHeight),
		slotHeight
	)
	local thumbTravel = math.max(0, slotHeight - thumbHeight)
	return scrollRange, thumbHeight, thumbTravel
end

local function updateLoginScrollbarThumb()
	local scrollRange, thumbHeight, thumbTravel = getLoginScrollMetrics()
	loginScrollbarArt.Visible = true
	loginScrollThumb.Visible = scrollRange > 0
	loginScrollThumb.Size = UDim2.fromOffset(DAILY_SCROLLBAR_THUMB_WIDTH, thumbHeight)

	if scrollRange <= 0 then
		loginScrollThumb.Position = UDim2.new(0.5, 0, 0, 0)
		return
	end

	local progress = math.clamp(loginGrid.CanvasPosition.Y / scrollRange, 0, 1)
	loginScrollThumb.Position = UDim2.new(0.5, 0, 0, thumbTravel * progress)
end

local function setLoginScrollProgress(progress)
	local scrollRange = getLoginScrollMetrics()
	loginGrid.CanvasPosition = Vector2.new(0, math.clamp(progress, 0, 1) * scrollRange)
end

local function setLoginCanvasY(value)
	local scrollRange = getLoginScrollMetrics()
	loginGrid.CanvasPosition = Vector2.new(0, math.clamp(value, 0, scrollRange))
end

loginScrollThumb.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		draggingLoginThumb = true
		dragOffsetInsideThumb = input.Position.Y - loginScrollThumb.AbsolutePosition.Y
	end
end)

loginScrollThumb.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		draggingLoginThumb = false
	end
end)

local UserInputService = game:GetService("UserInputService")
UserInputService.InputChanged:Connect(function(input)
	if not draggingLoginThumb then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local _, _, logicalThumbTravel = getLoginScrollMetrics()
	local absoluteThumbTravel = math.max(0, scrollSlot.AbsoluteSize.Y - loginScrollThumb.AbsoluteSize.Y)
	if logicalThumbTravel <= 0 or absoluteThumbTravel <= 0 then
		return
	end
	local thumbTop = input.Position.Y - scrollSlot.AbsolutePosition.Y - dragOffsetInsideThumb
	setLoginScrollProgress(thumbTop / absoluteThumbTravel)
end)

scrollSlot.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if draggingLoginThumb then
		return
	end

	local _, _, logicalThumbTravel = getLoginScrollMetrics()
	local absoluteThumbHeight = loginScrollThumb.AbsoluteSize.Y
	local absoluteThumbTravel = math.max(0, scrollSlot.AbsoluteSize.Y - absoluteThumbHeight)
	if logicalThumbTravel <= 0 or absoluteThumbTravel <= 0 then
		return
	end
	local localY = input.Position.Y - scrollSlot.AbsolutePosition.Y
	setLoginScrollProgress((localY - absoluteThumbHeight * 0.5) / absoluteThumbTravel)
end)

local function countLoginDayCards()
	local count = 0
	for _, child in ipairs(loginGrid:GetChildren()) do
		if child:IsA("Frame") and string.match(child.Name, "^DayCard%d+$") then
			count += 1
		end
	end
	return count
end

local function refreshLoginCanvasAndScrollbar()
	-- Do not use UIGridLayout.AbsoluteContentSize here: the whole Daily Reward
	-- panel has a UIScale, so that value is screen-scaled and made CanvasSize too
	-- short. Calculate the 4-column grid in its original logical coordinates.
	local cardCount = countLoginDayCards()
	local rowCount = cardCount > 0 and math.ceil(cardCount / DAILY_GRID_COLUMNS) or 0
	local contentHeight = 0
	if rowCount > 0 then
		contentHeight = rowCount * DAILY_GRID_CELL_HEIGHT
			+ math.max(0, rowCount - 1) * DAILY_GRID_ROW_GAP
			+ 16
	end

	loginGrid.CanvasSize = UDim2.new(0, 0, 0, contentHeight)

	local scrollRange = math.max(0, contentHeight - getLoginLogicalViewportHeight())
	loginGrid:SetAttribute("DailyRewardCardCount", cardCount)
	loginGrid:SetAttribute("DailyRewardRowCount", rowCount)
	loginGrid:SetAttribute("DailyRewardScrollRange", scrollRange)
	loginGrid.CanvasPosition = Vector2.new(
		0,
		math.clamp(loginGrid.CanvasPosition.Y, 0, scrollRange)
	)

	task.defer(updateLoginScrollbarThumb)
end

gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshLoginCanvasAndScrollbar)
loginGrid:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateLoginScrollbarThumb)
loginGrid:GetPropertyChangedSignal("CanvasPosition"):Connect(updateLoginScrollbarThumb)
loginGrid:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLoginScrollbarThumb)
loginPanel:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLoginScrollbarThumb)

local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLoginResponsiveScale)
end
updateLoginResponsiveScale()

local function currentDesignWith(changes)
	local monetization = state and state.Monetization or {}
	local source = monetization.AquariumPreviewDesign or monetization.AquariumDesign or MonetizationConfig.AquariumDesigner.defaultDesign
	local result = {
		theme = source.theme or "Classic",
		backdropEnabled = source.backdropEnabled ~= false,
		backgroundColor = source.backgroundColor or "Aqua",
		lightingColor = source.lightingColor or "SoftWhite",
		signText = source.signText or "",
		decorations = {},
		freeDecorations = {},
	}
	for slotId, decorationId in pairs(source.decorations or {}) do
		result.decorations[slotId] = decorationId
	end
	for _, item in ipairs(source.freeDecorations or {}) do
		table.insert(result.freeDecorations, {
			decorationId = item.decorationId,
			x = item.x,
			y = item.y,
			z = item.z,
			scale = item.scale,
		})
	end
	for key, value in pairs(changes or {}) do
		result[key] = value
	end
	return result
end

local function makeSectionHeading(text)
	local heading = makeText(shopContent, text, 17, Color3.new(1, 1, 1), true)
	heading.Size = UDim2.new(1, -8, 0, 30)
	return heading
end

local function makeShopCard(height)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, height or 104)
	card.BackgroundColor3 = COLORS.card
	card.Parent = shopContent
	addCorner(card, 8)
	addStroke(card, Color3.fromRGB(60, 72, 90), 1)
	return card
end

local robuxPriceCache = {}
local function getProductPrice(product)
	local productId = tonumber(product.id) or tonumber(product.Id)
	local fallback = tonumber(product.priceRobux) or tonumber(product.Price)
	if not productId or productId <= 0 then
		return fallback
	end
	if robuxPriceCache[productId] ~= nil then
		return robuxPriceCache[productId]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	end)
	local price = ok and type(info) == "table" and tonumber(info.PriceInRobux) or fallback
	robuxPriceCache[productId] = price
	return price
end

local renderShop

local function renderSeaStarProducts()
	makeSectionHeading("Sea Star Packs")
	local note = makeText(shopContent, "Sea Stars are cosmetic only and permanently unlock aquarium themes.", 13, COLORS.muted, false)
	note.Size = UDim2.new(1, -8, 0, 40)
	note.TextWrapped = true
	for _, productKey in ipairs(MonetizationConfig.SeaStarProductOrder or {}) do
		local product = MonetizationConfig.DeveloperProducts[productKey]
		if product then
			local card = makeShopCard(104)
			local title = makeText(card, product.name, 15, Color3.new(1, 1, 1), true)
			title.Position = UDim2.new(0, 14, 0, 10)
			title.Size = UDim2.new(1, -134, 0, 24)
			local detail = makeText(card, tostring(product.seaStarAmount or 0) .. " Sea Stars", 13, Color3.fromRGB(130, 231, 255), true)
			detail.Position = UDim2.new(0, 14, 0, 38)
			detail.Size = UDim2.new(1, -134, 0, 22)
			local productId = tonumber(product.id) or tonumber(product.Id)
			local available = product.purchasable ~= false and productId and productId > 0
			local price = getProductPrice(product)
			local priceLabel = makeText(card, tostring(price or "?") .. " Robux", 12, COLORS.gold, true)
			priceLabel.Position = UDim2.new(0, 14, 0, 66)
			priceLabel.Size = UDim2.new(1, -134, 0, 20)
			local buy = makeButton(card, available and "Buy" or "Coming Soon", available and COLORS.green or COLORS.disabled)
			buy.Position = UDim2.new(1, -116, 0, 33)
			buy.Size = UDim2.fromOffset(100, 38)
			buy.AutoButtonColor = available == true
			buy.Active = available == true
			buy.MouseButton1Click:Connect(function()
				if available then
					ShopAction:FireServer("PromptProduct", "Product", productKey)
				end
			end)
		end
	end
end

local function renderThemes()
	makeSectionHeading("Aquarium Themes")
	local note = makeText(shopContent, "Locked themes can always be previewed. Unlocking is permanent and costs Sea Stars only.", 13, COLORS.muted, false)
	note.Size = UDim2.new(1, -8, 0, 42)
	note.TextWrapped = true
	local unlocks = state and state.SeaStarUnlocks or {}
	for _, themeId in ipairs(MonetizationConfig.AquariumDesigner.themeOrder or {}) do
		local theme = MonetizationConfig.AquariumDesigner.themes[themeId]
		if theme then
			local owned = theme.free == true or unlocks[themeId] == true
			local card = makeShopCard(124)
			local title = makeText(card, theme.displayName or theme.name or themeId, 15, Color3.new(1, 1, 1), true)
			title.Position = UDim2.new(0, 14, 0, 8)
			title.Size = UDim2.new(1, -28, 0, 24)
			local priceText = theme.free == true and "Free" or (tostring(theme.seaStarPrice or 0) .. " Sea Stars")
			local price = makeText(card, priceText, 13, theme.free == true and Color3.fromRGB(112, 255, 156) or COLORS.gold, true)
			price.Position = UDim2.new(0, 14, 0, 34)
			price.Size = UDim2.new(1, -28, 0, 22)
			local ownedText = makeText(card, owned and "Owned" or "Locked", 12, owned and Color3.fromRGB(112, 255, 156) or COLORS.muted, true)
			ownedText.Position = UDim2.new(0, 14, 0, 58)
			ownedText.Size = UDim2.new(1, -28, 0, 20)

			local preview = makeButton(card, "Preview", COLORS.blue)
			preview.Position = UDim2.new(0, 14, 1, -38)
			preview.Size = UDim2.fromOffset(90, 30)
			preview.MouseButton1Click:Connect(function()
				ShopAction:FireServer("PreviewAquariumDesign", "Aquarium", themeId, currentDesignWith({ theme = themeId }))
			end)

			local apply = makeButton(card, "Apply", owned and COLORS.green or COLORS.disabled)
			apply.Position = UDim2.new(0, 112, 1, -38)
			apply.Size = UDim2.fromOffset(80, 30)
			apply.Active = owned
			apply.AutoButtonColor = owned
			apply.MouseButton1Click:Connect(function()
				if owned then
					ShopAction:FireServer("ApplyAquariumDesign", "Aquarium", themeId, currentDesignWith({ theme = themeId }))
				end
			end)

			local unlock = makeButton(card, owned and "Owned" or "Unlock", owned and COLORS.disabled or COLORS.gold)
			unlock.Position = UDim2.new(1, -108, 1, -38)
			unlock.Size = UDim2.fromOffset(94, 30)
			unlock.Active = not owned
			unlock.AutoButtonColor = not owned
			unlock.MouseButton1Click:Connect(function()
				if not owned then
					ShopAction:FireServer("PurchaseAquariumTheme", "AquariumTheme", themeId)
				end
			end)
		end
	end
end

local function makePresetCard(kind, optionId, option)
	local card = makeShopCard(88)
	local title = makeText(card, option.name or optionId, 14, Color3.new(1, 1, 1), true)
	title.Position = UDim2.new(0, 14, 0, 10)
	title.Size = UDim2.new(1, -220, 0, 24)
	local freeText = makeText(card, "Free editor preset", 12, Color3.fromRGB(112, 255, 156), false)
	freeText.Position = UDim2.new(0, 14, 0, 38)
	freeText.Size = UDim2.new(1, -220, 0, 20)
	local preview = makeButton(card, "Preview", COLORS.blue)
	preview.Position = UDim2.new(1, -196, 0, 27)
	preview.Size = UDim2.fromOffset(84, 32)
	preview.MouseButton1Click:Connect(function()
		ShopAction:FireServer("PreviewAquariumDesign", "Aquarium", kind, currentDesignWith({ [kind] = optionId }))
	end)
	local apply = makeButton(card, "Apply", COLORS.green)
	apply.Position = UDim2.new(1, -104, 0, 27)
	apply.Size = UDim2.fromOffset(88, 32)
	apply.MouseButton1Click:Connect(function()
		ShopAction:FireServer("ApplyAquariumDesign", "Aquarium", kind, currentDesignWith({ [kind] = optionId }))
	end)
end

local function renderEditorControls()
	makeSectionHeading("Free Aquarium Editor Controls")
	local note = makeText(shopContent, "Placement, move, rotate, scale, remove, owned decorations, precision controls, presets, backgrounds, lighting, and sign text are all free.", 13, COLORS.muted, false)
	note.Size = UDim2.new(1, -8, 0, 58)
	note.TextWrapped = true

	makeSectionHeading("Background Presets")
	for _, optionId in ipairs(MonetizationConfig.AquariumDesigner.backgroundColorOrder or {}) do
		makePresetCard("backgroundColor", optionId, MonetizationConfig.AquariumDesigner.backgroundColors[optionId])
	end
	makeSectionHeading("Lighting Presets")
	for _, optionId in ipairs(MonetizationConfig.AquariumDesigner.lightingColorOrder or {}) do
		makePresetCard("lightingColor", optionId, MonetizationConfig.AquariumDesigner.lightingColors[optionId])
	end

	makeSectionHeading("Display Sign")
	local signCard = makeShopCard(104)
	local signBox = Instance.new("TextBox")
	signBox.Position = UDim2.new(0, 14, 0, 14)
	signBox.Size = UDim2.new(1, -224, 0, 34)
	signBox.BackgroundColor3 = COLORS.cardAlt
	signBox.TextColor3 = Color3.new(1, 1, 1)
	signBox.PlaceholderText = "Aquarium sign text"
	signBox.Text = currentDesignWith().signText
	signBox.ClearTextOnFocus = false
	signBox.TextSize = 13
	signBox.Font = Enum.Font.Gotham
	signBox.Parent = signCard
	addCorner(signBox, 6)
	local preview = makeButton(signCard, "Preview", COLORS.blue)
	preview.Position = UDim2.new(1, -196, 0, 14)
	preview.Size = UDim2.fromOffset(84, 34)
	preview.MouseButton1Click:Connect(function()
		ShopAction:FireServer("PreviewAquariumDesign", "Aquarium", "signText", currentDesignWith({ signText = signBox.Text }))
	end)
	local save = makeButton(signCard, "Save", COLORS.green)
	save.Position = UDim2.new(1, -104, 0, 14)
	save.Size = UDim2.fromOffset(88, 34)
	save.MouseButton1Click:Connect(function()
		ShopAction:FireServer("ApplyAquariumDesign", "Aquarium", "signText", currentDesignWith({ signText = signBox.Text }))
	end)
	local cancel = makeButton(signCard, "Cancel Preview", COLORS.disabled)
	cancel.Position = UDim2.new(0, 14, 0, 58)
	cancel.Size = UDim2.fromOffset(130, 32)
	cancel.MouseButton1Click:Connect(function()
		ShopAction:FireServer("CancelAquariumPreview", "Aquarium")
	end)
end

renderShop = function()
	clearContainer(shopTabs)
	clearContainer(shopContent)
	shopBalance.Text = tostring(state and state.SeaStars or 0) .. " Sea Stars"
	for _, tabName in ipairs({ "Sea Stars", "Themes", "Free Editor" }) do
		local tab = makeButton(shopTabs, tabName, activeShopTab == tabName and COLORS.blue or COLORS.cardAlt)
		tab.Size = UDim2.new(0.333, -6, 1, 0)
		tab.MouseButton1Click:Connect(function()
			activeShopTab = tabName
			renderShop()
		end)
	end
	if activeShopTab == "Sea Stars" then
		renderSeaStarProducts()
	elseif activeShopTab == "Themes" then
		renderThemes()
	else
		renderEditorControls()
	end
end

local function renderLogin()
	clearContainer(loginGrid)
	local login = state and state.LoginRewards
	if not login then
		claimButton.Active = false
		claimButton.AutoButtonColor = false
		claimButtonArt.ImageColor3 = Color3.fromRGB(140, 140, 140)
		claimButtonLabel.Text = "Loading..."
		updateLoginScrollbarThumb()
		return
	end

	local daysInCycle = login.DaysInCycle or 31
	loginTitle.Text = "Daily Login Rewards"
	claimButtonLabel.Text = login.ClaimAvailable and ("Claim Day " .. tostring(login.CurrentDay)) or "Claimed"
	claimButton.Active = login.ClaimAvailable == true
	claimButton.AutoButtonColor = login.ClaimAvailable == true
	claimButtonArt.ImageColor3 = login.ClaimAvailable and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 150)

	local function rewardLinesFromSummary(summary)
		summary = tostring(summary or "")
		local lines = {}
		local function add(icon, textValue)
			if textValue and textValue ~= "" then
				table.insert(lines, { Icon = icon, Text = textValue })
			end
		end
		local coins = string.match(summary, "(%d+)%s+Coins")
		if coins then add(DAILY_REWARD_ASSETS.CoinIcon, coins .. " Coins") end
		local fresh = string.match(summary, "(%d+)%s+Fresh Bait")
		if fresh then add(DAILY_REWARD_ASSETS.FreshBaitIcon, fresh .. " Fresh Bait") end
		local lucky = string.match(summary, "(%d+)%s+Lucky Bait")
		if lucky then add(DAILY_REWARD_ASSETS.LuckyBaitIcon, lucky .. " Lucky Bait") end
		local mystic = string.match(summary, "(%d+)%s+Mystic Bait")
		if mystic then add(DAILY_REWARD_ASSETS.SpecialDayIcon, mystic .. " Mystic Bait") end
		local seaStars = string.match(summary, "(%d+)%s+Sea Stars")
		if seaStars then add(DAILY_REWARD_ASSETS.SpecialDayIcon, seaStars .. " Sea Stars") end
		local cycleSeaStars = string.match(summary, "(%d+)%s+Cycle Sea Stars")
		if cycleSeaStars then add(DAILY_REWARD_ASSETS.SpecialDayIcon, cycleSeaStars .. " Cycle Sea Stars") end
		local resources = string.match(summary, "(%d+)%s+weighted resources")
		if resources then add(DAILY_REWARD_ASSETS.SpecialDayIcon, resources .. " weighted resources") end
		if string.find(summary, "aquarium decoration", 1, true) then
			add(DAILY_REWARD_ASSETS.SpecialDayIcon, "1 aquarium decoration")
		end
		if #lines == 0 and summary ~= "" then
			add(DAILY_REWARD_ASSETS.SpecialDayIcon, summary)
		end
		return lines
	end

	local animatedClaimThisRender = false

	for _, slot in ipairs(login.RewardTrack or {}) do
		local day = slot.Day
		local claimed = day < (login.CurrentDay or 1)
		local isCurrentDay = day == (login.CurrentDay or 1)
		local isFinalDay = day == daysInCycle or slot.IsFinal
		local isMilestone = slot.IsMilestone == true or day == 7 or day == 14 or day == 21

		local imageId = DAILY_REWARD_ASSETS.UnlockedDayTab
		local crop = DAILY_TAB_CROPS.Unlocked
		if isFinalDay then
			imageId = DAILY_REWARD_ASSETS.RedTab
			crop = DAILY_TAB_CROPS.Red
		elseif isMilestone then
			imageId = DAILY_REWARD_ASSETS.PurpleTab
			crop = DAILY_TAB_CROPS.Purple
		elseif isCurrentDay and login.ClaimAvailable then
			imageId = DAILY_REWARD_ASSETS.TodayTab
			crop = DAILY_TAB_CROPS.Today
		end

		local card = Instance.new("Frame")
		card.Name = "DayCard" .. tostring(day)
		card.LayoutOrder = day
		card.BackgroundTransparency = 1
		card.ClipsDescendants = true
		card.Parent = loginGrid

		local cardImage = makeImage(card, imageId)
		applyVirtualCrop(cardImage, TRIMMED_IMAGE_SIZES.DayTab, crop)

		local dayLabel = makeOutlinedText(card, "Day " .. tostring(day), 25, Color3.new(1, 1, 1), true)
		dayLabel.Position = UDim2.fromOffset(20, 10)
		dayLabel.Size = UDim2.new(1, -40, 0, 32)
		dayLabel.Font = Enum.Font.FredokaOne
		dayLabel.TextXAlignment = Enum.TextXAlignment.Left

		local summaryLines = rewardLinesFromSummary(slot.Summary)
		if isMilestone or isFinalDay then
			-- Milestone/final days can contain up to five rewards.
			-- Keep the existing card size, but raise the whole reward group,
			-- enlarge the text, and give long reward names more horizontal room.
			local milestoneIcon = makeImage(card, DAILY_REWARD_ASSETS.SpecialDayIcon)
			milestoneIcon.Position = UDim2.fromOffset(18, 56)
			milestoneIcon.Size = UDim2.fromOffset(82, 82)
			milestoneIcon.ScaleType = Enum.ScaleType.Fit

			local visibleLineCount = math.min(#summaryLines, 5)
			local lineY = visibleLineCount >= 5 and 42 or 48
			local lineSpacing = visibleLineCount >= 5 and 22 or 23

			for index, line in ipairs(summaryLines) do
				if index > 5 then break end
				local lineLabel = makeOutlinedText(card, line.Text, 18, Color3.new(1, 1, 1), false)
				lineLabel.Position = UDim2.fromOffset(100, lineY)
				lineLabel.Size = UDim2.new(1, -106, 0, 23)
				lineLabel.TextXAlignment = Enum.TextXAlignment.Left
				lineLabel.TextYAlignment = Enum.TextYAlignment.Center
				lineY += lineSpacing
			end
		else
			local startY = 60
			for index, line in ipairs(summaryLines) do
				if index > 3 then break end
				local icon = makeImage(card, line.Icon)
				icon.Position = UDim2.fromOffset(24, startY)
				icon.Size = UDim2.fromOffset(40, 40)
				icon.ScaleType = Enum.ScaleType.Fit
				local lineLabel = makeOutlinedText(card, line.Text, 20, Color3.new(1, 1, 1), false)
				lineLabel.Position = UDim2.fromOffset(82, startY + 4)
				lineLabel.Size = UDim2.new(1, -94, 0, 26)
				lineLabel.TextXAlignment = Enum.TextXAlignment.Left
				startY += 32
			end
		end

		if claimed then
			local claimedOverlay = makeImage(card, DAILY_REWARD_ASSETS.DoneIcon)
			claimedOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
			claimedOverlay.Position = UDim2.fromScale(0.5, 0.53)
			claimedOverlay.Size = UDim2.fromOffset(160, 160)
			claimedOverlay.ScaleType = Enum.ScaleType.Fit
			claimedOverlay.ZIndex = 5

			-- Only the day claimed from the current Claim-button press fades in.
			-- Slow, smooth reveal: no bounce or sudden pop.
			if pendingClaimAnimationDay == day then
				animatedClaimThisRender = true
				claimedOverlay.ImageTransparency = 1

				local claimedScale = Instance.new("UIScale")
				claimedScale.Scale = 0.96
				claimedScale.Parent = claimedOverlay

				task.defer(function()
					local smoothFadeInfo = TweenInfo.new(
						1.55,
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.InOut
					)

					TweenService:Create(
						claimedOverlay,
						smoothFadeInfo,
						{ ImageTransparency = 0 }
					):Play()

					TweenService:Create(
						claimedScale,
						smoothFadeInfo,
						{ Scale = 1 }
					):Play()
				end)
			end
		end
	end

	if animatedClaimThisRender then
		pendingClaimAnimationDay = nil
	end

	task.defer(function()
		refreshLoginCanvasAndScrollbar()
		RunService.Heartbeat:Wait()
		refreshLoginCanvasAndScrollbar()
	end)
end

local function enforceOwnedDecorationButtons()
	local editorGui = playerGui:FindFirstChild("AquariumFreePlacementGui")
	if not editorGui then
		return
	end
	local owned = state and state.AquariumDecorations or {}
	for decorationId, decoration in pairs(MonetizationConfig.AquariumDesigner.decorations or {}) do
		if decorationId ~= "None" then
			for _, descendant in ipairs(editorGui:GetDescendants()) do
				if descendant:IsA("TextButton") then
					local taggedId = descendant:GetAttribute("Phase3DecorationId")
					if taggedId == decorationId or (taggedId == nil and descendant.Text == decoration.name) then
						descendant:SetAttribute("Phase3DecorationId", decorationId)
						local isOwned = (owned[decorationId] or 0) > 0
						descendant.Active = isOwned
						descendant.AutoButtonColor = isOwned
						descendant.Text = isOwned and decoration.name or (decoration.name .. "\nLocked")
						if not isOwned then
							descendant.BackgroundColor3 = COLORS.disabled
						end
					end
				end
			end
		end
	end
end

local function updateTimer()
	local login = state and state.LoginRewards
	if not login then
		loginTimer.Text = ""
		return
	end
	if login.ClaimAvailable then
		loginTimer.Text = "Daily rewards reset at 24:00 (Server's UTC Time)"
		return
	end
	local remaining = math.max(0, math.floor((login.SecondsUntilNextUtcClaim or 0) - (os.clock() - stateReceivedAt)))
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	local seconds = remaining % 60
	loginTimer.Text = string.format("Next UTC claim in %02d:%02d:%02d", hours, minutes, seconds)
	if remaining <= 0 and not requestedMidnightRefresh then
		requestedMidnightRefresh = true
		task.spawn(function()
			local ok, result = pcall(function()
				return GetState:InvokeServer()
			end)
			if ok and type(result) == "table" then
				state = result
				stateReceivedAt = os.clock()
				requestedMidnightRefresh = false
				renderLogin()
				updateTimer()
			end
		end)
	end
end

local function showShop(tabName)
	activeShopTab = tabName or activeShopTab
	loginOverlay.Visible = false
	shopOverlay.Visible = true
	renderShop()
end

local function showLogin()
	shopOverlay.Visible = false
	loginOverlay.Visible = true
	renderLogin()
	updateTimer()
end

local function receiveState(newState)
	if type(newState) ~= "table" then
		return
	end
	state = newState
	stateReceivedAt = os.clock()
	requestedMidnightRefresh = false
	seaStarHud.update(state.SeaStars or 0)
	local login = state.LoginRewards
	if shopOverlay.Visible then
		renderShop()
	end
	if loginOverlay.Visible then
		renderLogin()
		updateTimer()
	end
	task.defer(enforceOwnedDecorationButtons)
	if not autoOpenEvaluated then
		autoOpenEvaluated = true
		if login and login.ClaimAvailable and not loginOpenedAutomatically then
			loginOpenedAutomatically = true
			showLogin()
		end
	end
end

seaStarHud.button.Activated:Connect(function()
	showShop("Sea Stars")
end)
loginButtonActivated.Event:Connect(showLogin)
shopClose.MouseButton1Click:Connect(function()
	shopOverlay.Visible = false
end)
loginClose.MouseButton1Click:Connect(function()
	loginOverlay.Visible = false
end)
claimButton.MouseButton1Click:Connect(function()
	if state and state.LoginRewards and state.LoginRewards.ClaimAvailable then
		pendingClaimAnimationDay = state.LoginRewards.CurrentDay
		claimButton.Active = false
		claimButton.AutoButtonColor = false
		claimButtonArt.ImageColor3 = Color3.fromRGB(150, 150, 150)
		claimButtonLabel.Text = "Claiming..."
		LoginRewardAction:FireServer("Claim")
	end
end)

StateUpdated.OnClientEvent:Connect(receiveState)
LoginRewardAction.OnClientEvent:Connect(function(result)
	if type(result) == "table" then
		loginStatus.Text = result.Message or (result.Success and "Reward claimed." or "Reward unavailable.")
		if result.Success == false then
			pendingClaimAnimationDay = nil
		end
	end
end)
if OpenShop then
	OpenShop.OnClientEvent:Connect(function(tabName)
		if tabName == "SeaStars" or tabName == "Sea Stars" or tabName == "Themes" then
			showShop(tabName == "Themes" and "Themes" or "Sea Stars")
		end
	end)
end

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("TextButton") or descendant.Name == "AquariumFreePlacementGui" then
		task.defer(enforceOwnedDecorationButtons)
	end
	if descendant:IsA("LocalScript") and descendant.Name == "AquariumDesignerShopCleanup" then
		descendant.Disabled = true
	end
end)

task.defer(function()
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("LocalScript") and descendant.Name == "AquariumDesignerShopCleanup" then
			descendant.Disabled = true
		end
	end
	local ok, initialState = pcall(function()
		return GetState:InvokeServer()
	end)
	if ok then
		receiveState(initialState)
	end
end)

local timerAccumulator = 0
RunService.RenderStepped:Connect(function(deltaTime)
	timerAccumulator += deltaTime
	if timerAccumulator >= 1 then
		timerAccumulator = 0
		if loginOverlay.Visible then
			updateTimer()
		end
	end
end)

print("[Phase3EconomyUI_v34] Final-day layout + Fresh Bait icon loaded")
