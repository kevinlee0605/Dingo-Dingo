-- IslandWarpModernClient (authored v1615 binder)
-- The complete fixed skin lives in StarterGui > FishingGui >
-- BiomeWarpOverlay > ModernIslandWarp. Only destination cards are cloned from
-- the authored IslandCardTemplate because their text/cost/icon are data-driven.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local screenGui = script.Parent
local authoredHost = screenGui:WaitForChild("BiomeWarpOverlay")
local root = authoredHost:WaitForChild("ModernIslandWarp")
local uiScale = root:WaitForChild("ResponsiveScale")
local closeButton = root:WaitForChild("CloseButton")
local scroll = root:WaitForChild("IslandList")
local listHolder = scroll:WaitForChild("Cards")
local layout = listHolder:FindFirstChildOfClass("UIListLayout")
local cardTemplate = root:WaitForChild("IslandCardTemplate")

assert(authoredHost:IsA("GuiObject"), "BiomeWarpOverlay must be an authored GuiObject")
assert(root:IsA("ImageLabel"), "ModernIslandWarp must be an authored ImageLabel")
assert(uiScale:IsA("UIScale"), "ModernIslandWarp.ResponsiveScale must be authored")
assert(closeButton:IsA("ImageButton"), "ModernIslandWarp.CloseButton must be authored")
assert(scroll:IsA("ScrollingFrame"), "ModernIslandWarp.IslandList must be authored")
assert(listHolder:IsA("Frame") and layout, "ModernIslandWarp.Cards layout must be authored")
assert(cardTemplate:IsA("Frame"), "ModernIslandWarp.IslandCardTemplate must be authored")

local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local OpenBiomeWarp = Remotes:WaitForChild("OpenBiomeWarp")
local TeleportTo = Remotes:WaitForChild("TeleportTo")

local BASE_WIDTH = 1211
local BASE_HEIGHT = 1299
local ISLAND_WARP_UI_SIZE_MULTIPLIER = 0.70
local SCROLL_WHEEL_STEP = 135
local CARD_HEIGHT = 300
local CARD_GAP = 26

local ASSETS = {
	LilyshoreIsland = "rbxassetid://94386681729236",
	RiverbendIsland = "rbxassetid://83913634264814",
	CoralCoastIsland = "rbxassetid://122703152321295",
	CoinIcon = "rbxassetid://79109082679955",
}

local CROPS = {
	LilyshoreIsland = {
		source = Vector2.new(1211, 1299),
		offset = Vector2.new(462, 552),
		size = Vector2.new(254, 247),
	},
	RiverbendIsland = {
		source = Vector2.new(1211, 1299),
		offset = Vector2.new(443, 527),
		size = Vector2.new(264, 237),
	},
	CoralCoastIsland = {
		source = Vector2.new(1211, 1299),
		offset = Vector2.new(477, 515),
		size = Vector2.new(260, 268),
	},
}

local ISLANDS = {
	{
		id = "LilyshoreIsland",
		title = "Lilyshore Island",
		iconKey = "LilyshoreIsland",
		level = nil,
		coins = nil,
	},
	{
		id = "RiverbendIsland",
		title = "Riverbend Island",
		iconKey = "RiverbendIsland",
		level = 10,
		coins = 5000,
	},
	{
		id = "CoralCoastIsland",
		title = "Coral Coast Island",
		iconKey = "CoralCoastIsland",
		level = 25,
		coins = 50000,
	},
}

local function requireChild(parent, name, className)
	local child = parent:FindFirstChild(name)
	assert(
		child and child.ClassName == className,
		string.format("[IslandWarpModernClient] Authored node %s.%s (%s) is missing", parent:GetFullName(), name, className)
	)
	return child
end

local function addPressFeedback(button)
	local artwork = requireChild(button, "Artwork", "ImageLabel")
	local originalPosition = button.Position
	local originalSize = button.Size
	local pressedPosition = UDim2.new(
		originalPosition.X.Scale,
		originalPosition.X.Offset + 4,
		originalPosition.Y.Scale,
		originalPosition.Y.Offset + 4
	)
	local pressedSize = UDim2.new(
		originalSize.X.Scale,
		originalSize.X.Offset - 8,
		originalSize.Y.Scale,
		originalSize.Y.Offset - 8
	)
	local buttonTween
	local artworkTween

	local function setPressed(pressed)
		if buttonTween then
			buttonTween:Cancel()
		end
		if artworkTween then
			artworkTween:Cancel()
		end
		buttonTween = TweenService:Create(
			button,
			TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = pressed and pressedPosition or originalPosition,
				Size = pressed and pressedSize or originalSize,
			}
		)
		buttonTween:Play()
		artworkTween = TweenService:Create(
			artwork,
			TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ ImageTransparency = pressed and 0.16 or 0 }
		)
		artworkTween:Play()
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			setPressed(true)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			setPressed(false)
		end
	end)
	button.MouseLeave:Connect(function()
		setPressed(false)
	end)
end

local function updateResponsiveScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local fit = math.min(
		(viewport.X * 0.97) / BASE_WIDTH,
		(viewport.Y * 0.95) / BASE_HEIGHT
	)
	uiScale.Scale = math.clamp(
		fit * ISLAND_WARP_UI_SIZE_MULTIPLIER,
		0.28,
		1
	)
end

updateResponsiveScale()
local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
end

-- FishingClient keeps a compatibility BiomeWarpPanel inside this same authored
-- host. Suppress that panel, but never hide the authored host itself.
local legacyConnections = {}
local function suppressLegacyOverlay(instance)
	local isLegacyPanel = instance.Name == "BiomeWarpPanel"
	local isSeparateLegacyOverlay = instance.Name == "BiomeWarpOverlay"
		and instance ~= authoredHost
	if not (isLegacyPanel or isSeparateLegacyOverlay)
		or not instance:IsA("GuiObject")
	then
		return
	end
	instance.Visible = false
	if not legacyConnections[instance] then
		legacyConnections[instance] = instance:GetPropertyChangedSignal("Visible"):Connect(function()
			if instance.Parent and instance.Visible then
				instance.Visible = false
			end
		end)
	end
end

for _, descendant in ipairs(screenGui:GetDescendants()) do
	suppressLegacyOverlay(descendant)
end
screenGui.DescendantAdded:Connect(function(descendant)
	task.defer(suppressLegacyOverlay, descendant)
end)

local correctingHostBackground = false
authoredHost.BackgroundTransparency = 1
authoredHost.ZIndex = 300
authoredHost:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
	if correctingHostBackground or authoredHost.BackgroundTransparency == 1 then
		return
	end
	correctingHostBackground = true
	authoredHost.BackgroundTransparency = 1
	correctingHostBackground = false
end)
authoredHost:GetPropertyChangedSignal("ZIndex"):Connect(function()
	if authoredHost.ZIndex ~= 300 then
		authoredHost.ZIndex = 300
	end
end)

local function applyCroppedArtwork(holder, imageId, crop)
	local artwork = requireChild(holder, "Artwork", "ImageLabel")
	artwork.Image = imageId
	artwork.Position = UDim2.fromScale(
		-crop.offset.X / crop.size.X,
		-crop.offset.Y / crop.size.Y
	)
	artwork.Size = UDim2.fromScale(
		crop.source.X / crop.size.X,
		crop.source.Y / crop.size.Y
	)
end

local function formatNumber(value)
	local formatted = string.format("%d", value)
	return formatted
		:reverse()
		:gsub("(%d%d%d)", "%1,")
		:reverse()
		:gsub("^,", "")
end

local function configureIslandCard(island, layoutOrder)
	local card = cardTemplate:Clone()
	card.Name = island.id .. "Card"
	card.LayoutOrder = layoutOrder
	card.Visible = true
	card:SetAttribute("IslandWarpDynamicCard", true)

	local icon = requireChild(card, "IslandIcon", "Frame")
	applyCroppedArtwork(icon, ASSETS[island.iconKey], CROPS[island.iconKey])
	requireChild(card, "IslandTitle", "TextLabel").Text = island.title

	local requirementLabel = requireChild(card, "RequirementLabel", "TextLabel")
	local requirementValue = requireChild(card, "RequirementValue", "TextLabel")
	local coinIcon = requireChild(card, "CoinIcon", "Frame")
	local coinRequirement = requireChild(card, "CoinRequirement", "TextLabel")
	if island.level then
		requirementLabel.Text = string.format("Requirement: Level %d +", island.level)
		requirementLabel.Position = UDim2.fromOffset(315, 126)
		requirementLabel.Size = UDim2.fromOffset(480, 50)
		requirementValue.Visible = false
		coinIcon.Visible = true
		coinRequirement.Text = string.format("%s Coins", formatNumber(island.coins))
		coinRequirement.Visible = true
	else
		requirementLabel.Text = "Requirement:"
		requirementLabel.Position = UDim2.fromOffset(315, 142)
		requirementLabel.Size = UDim2.fromOffset(235, 50)
		requirementValue.Text = "Free"
		requirementValue.Visible = true
		coinIcon.Visible = false
		coinRequirement.Visible = false
	end

	local goButton = requireChild(card, "GoButton", "ImageButton")
	requireChild(goButton, "Label", "TextLabel").Text = "GO"
	addPressFeedback(goButton)
	goButton.MouseButton1Click:Connect(function()
		root.Visible = false
		authoredHost.Visible = false
		TeleportTo:FireServer(island.id)
	end)

	card.Parent = listHolder
end

for _, child in ipairs(listHolder:GetChildren()) do
	if child:GetAttribute("IslandWarpDynamicCard") == true then
		child:Destroy()
	end
end
for index, island in ipairs(ISLANDS) do
	configureIslandCard(island, index)
end

local function updateScrollCanvas()
	task.defer(function()
		local cardCount = #ISLANDS + 1
		local contentHeight = (cardCount * CARD_HEIGHT)
			+ ((cardCount - 1) * CARD_GAP)
			+ 24
		listHolder.Size = UDim2.new(1, -16, 0, contentHeight)
		scroll.CanvasSize = UDim2.fromOffset(0, contentHeight)
	end)
end
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateScrollCanvas)
updateScrollCanvas()

local function isPointInside(guiObject, point)
	local position = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

local function setCanvasY(newY)
	local maxY = math.max(
		0,
		scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y
	)
	scroll.CanvasPosition = Vector2.new(0, math.clamp(newY, 0, maxY))
end

UserInputService.InputChanged:Connect(function(input)
	if not root.Visible or input.UserInputType ~= Enum.UserInputType.MouseWheel then
		return
	end
	if not isPointInside(scroll, UserInputService:GetMouseLocation()) then
		return
	end
	setCanvasY(scroll.CanvasPosition.Y - (input.Position.Z * SCROLL_WHEEL_STEP))
end)

local activeTouch = nil
local previousTouchY = 0
scroll.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		activeTouch = input
		previousTouchY = input.Position.Y
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input ~= activeTouch then
		return
	end
	local deltaY = input.Position.Y - previousTouchY
	previousTouchY = input.Position.Y
	setCanvasY(scroll.CanvasPosition.Y - deltaY)
end)
UserInputService.InputEnded:Connect(function(input)
	if input == activeTouch then
		activeTouch = nil
	end
end)

local function setVisible(visible)
	local isVisible = visible == true
	authoredHost.ZIndex = 300
	root.Visible = isVisible
	authoredHost.Visible = isVisible
	if isVisible then
		scroll.CanvasPosition = Vector2.new(0, 0)
		updateScrollCanvas()
	end
	for _, descendant in ipairs(screenGui:GetDescendants()) do
		suppressLegacyOverlay(descendant)
	end
end

addPressFeedback(closeButton)
closeButton.MouseButton1Click:Connect(function()
	setVisible(false)
end)
OpenBiomeWarp.OnClientEvent:Connect(function()
	setVisible(true)
	task.defer(setVisible, true)
end)

setVisible(false)
print("[IslandWarpModernClient] Bound authored v1615 Island Warp UI.")
