local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local StartFishing = Remotes:WaitForChild("StartFishing")
local FinishMinigame = Remotes:WaitForChild("FinishMinigame")
local SellFish = Remotes:WaitForChild("SellFish")
local BuyRod = Remotes:WaitForChild("BuyRod")
local UnlockBiome = Remotes:WaitForChild("UnlockBiome")
local TeleportTo = Remotes:WaitForChild("TeleportTo")
local OpenBiomeWarp = Remotes:WaitForChild("OpenBiomeWarp", 10)
local AquariumAction = Remotes:WaitForChild("AquariumAction")
local ToggleAutoFish = Remotes:WaitForChild("ToggleAutoFish")
local StateUpdated = Remotes:WaitForChild("StateUpdated")
local FishingPrompt = Remotes:WaitForChild("FishingPrompt")
local Notice = Remotes:WaitForChild("Notice")
local GetState = Remotes:WaitForChild("GetState")

local screenGui = script.Parent
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local state = nil
local activeTab = "Fish"
local fishingBusy = false
local minigameRunning = false

local fishingBlur = Lighting:FindFirstChild("FishyFishUiBlur")
if not fishingBlur then
	fishingBlur = Instance.new("BlurEffect")
	fishingBlur.Name = "FishyFishUiBlur"
	fishingBlur.Parent = Lighting
end
fishingBlur.Enabled = false
fishingBlur.Size = 0

local function clearChildren(instance)
	for _, child in ipairs(instance:GetChildren()) do
		if not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(45, 52, 64)
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

local function addGradient(parent, topColor, bottomColor, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topColor),
		ColorSequenceKeypoint.new(1, bottomColor),
	})
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

local function setCornerRadius(parent, radius)
	local corner = parent:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = parent
	end

	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

local function styleOutlinedText(label, size)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = size or label.TextSize
	label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextTransparency = 0
	label.RichText = false
end

local function forcePureWhiteText(label)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 0
	label.TextStrokeColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 1
end

local function limitTextSize(label, minSize, maxSize)
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not constraint then
		constraint = Instance.new("UITextSizeConstraint")
		constraint.Parent = label
	end

	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	return constraint
end

local function addGloss(parent, position, size)
	local gloss = Instance.new("Frame")
	gloss.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	gloss.BackgroundTransparency = 0.72
	gloss.Position = position
	gloss.Size = size
	gloss.ZIndex = (parent.ZIndex or 1) + 1
	gloss.Parent = parent
	addCorner(gloss, 24)

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.45, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Rotation = 18
	gradient.Parent = gloss

	return gloss
end

local function makeText(parent, text, size, color, bold)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(240, 244, 248)
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function makeButton(parent, text, color)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or Color3.fromRGB(48, 126, 230)
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.Parent = parent
	addCorner(button, 7)
	addStroke(button, Color3.fromRGB(255, 255, 255), 1).Transparency = 0.85
	return button
end

local function makeFishIcon(parent, fishId, rarity, discovered)
	local color = GameConfig.RarityColors[rarity] or Color3.fromRGB(130, 146, 166)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(21, 28, 38)
	frame.Parent = parent
	addCorner(frame, 6)
	addStroke(frame, color, 1).Transparency = discovered == false and 0.55 or 0.2

	local imageId = discovered == false and nil or GameConfig.getFishImage(fishId)
	if imageId then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = imageId
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromScale(1, 1)
		image.Position = UDim2.fromScale(0, 0)
		image.Parent = frame
	else
		local label = makeText(frame, discovered == false and "?" or "FISH", 12, color, true)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.Size = UDim2.fromScale(1, 1)
	end

	return frame
end

local function makeRodIcon(parent, rodId)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(21, 28, 38)
	frame.Parent = parent
	addCorner(frame, 6)
	addStroke(frame, Color3.fromRGB(130, 146, 166), 1).Transparency = 0.2

	local imageId = GameConfig.getRodImage(rodId)
	if imageId then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = imageId
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromScale(1, 1)
		image.Position = UDim2.fromScale(0, 0)
		image.Parent = frame
	else
		local label = makeText(frame, "NO IMAGE", 10, Color3.fromRGB(160, 174, 192), true)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.Size = UDim2.fromScale(1, 1)
	end

	return frame
end

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.new(1, 0, 1, 0)
root.BackgroundTransparency = 1
root.Parent = screenGui

local biomeWarpOverlay = Instance.new("Frame")
biomeWarpOverlay.Name = "BiomeWarpOverlay"
biomeWarpOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
biomeWarpOverlay.BackgroundTransparency = 0.35
biomeWarpOverlay.Size = UDim2.fromScale(1, 1)
biomeWarpOverlay.Visible = false
biomeWarpOverlay.ZIndex = 90
biomeWarpOverlay.Parent = root

local biomeWarpPanel = Instance.new("Frame")
biomeWarpPanel.Name = "BiomeWarpPanel"
biomeWarpPanel.AnchorPoint = Vector2.new(0.5, 0.5)
biomeWarpPanel.BackgroundColor3 = Color3.fromRGB(17, 24, 34)
biomeWarpPanel.Position = UDim2.fromScale(0.5, 0.5)
biomeWarpPanel.Size = UDim2.new(0, 430, 0, 420)
biomeWarpPanel.ZIndex = 91
biomeWarpPanel.Parent = biomeWarpOverlay
addCorner(biomeWarpPanel, 8)
addStroke(biomeWarpPanel, Color3.fromRGB(74, 95, 124), 1)

local biomeWarpTitle = makeText(biomeWarpPanel, "Biome Warp", 20, Color3.fromRGB(255, 255, 255), true)
biomeWarpTitle.Position = UDim2.new(0, 18, 0, 12)
biomeWarpTitle.Size = UDim2.new(1, -72, 0, 28)
biomeWarpTitle.ZIndex = 92

local biomeWarpClose = makeButton(biomeWarpPanel, "X", Color3.fromRGB(91, 104, 124))
biomeWarpClose.Position = UDim2.new(1, -48, 0, 12)
biomeWarpClose.Size = UDim2.new(0, 32, 0, 28)
biomeWarpClose.TextSize = 14
biomeWarpClose.ZIndex = 92

local biomeWarpList = Instance.new("Frame")
biomeWarpList.Name = "BiomeWarpList"
biomeWarpList.BackgroundTransparency = 1
biomeWarpList.Position = UDim2.new(0, 16, 0, 54)
biomeWarpList.Size = UDim2.new(1, -32, 1, -70)
biomeWarpList.ZIndex = 92
biomeWarpList.Parent = biomeWarpPanel

local biomeWarpListLayout = Instance.new("UIListLayout")
biomeWarpListLayout.Padding = UDim.new(0, 10)
biomeWarpListLayout.SortOrder = Enum.SortOrder.LayoutOrder
biomeWarpListLayout.Parent = biomeWarpList

local function setBiomeWarpVisible(visible)
	biomeWarpOverlay.Visible = visible
end

local function renderBiomeWarpOptions()
	clearChildren(biomeWarpList)

	if not state then
		return
	end

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		local unlocked = state.UnlockedBiomes[biomeId] == true
		local current = state.CurrentBiome == biomeId
		local card = Instance.new("Frame")
		card.Name = biomeId .. "WarpOption"
		card.BackgroundColor3 = Color3.fromRGB(24, 32, 44)
		card.Size = UDim2.new(1, 0, 0, 92)
		card.ZIndex = 92
		card.Parent = biomeWarpList
		addCorner(card, 8)
		addStroke(card, unlocked and biome.color or Color3.fromRGB(82, 92, 106), 1).Transparency = 0.25

		local nameColor = unlocked and biome.color or Color3.fromRGB(130, 140, 155)
		local name = makeText(card, biome.displayName, 16, nameColor, true)
		name.Position = UDim2.new(0, 12, 0, 8)
		name.Size = UDim2.new(1, -128, 0, 22)
		name.ZIndex = 93

		local requirement = makeText(card, "Requirement: " .. GameConfig.getBiomeUnlockText(biomeId), 13, Color3.fromRGB(190, 204, 220), false)
		requirement.Position = UDim2.new(0, 12, 0, 34)
		requirement.Size = UDim2.new(1, -128, 0, 18)
		requirement.ZIndex = 93

		local detail = makeText(card, "Species: " .. #biome.fish, 12, Color3.fromRGB(143, 160, 180), false)
		detail.Position = UDim2.new(0, 12, 0, 56)
		detail.Size = UDim2.new(1, -128, 0, 18)
		detail.ZIndex = 93

		local label = current and "Selected" or (unlocked and "Go" or "Unlock")
		local buttonColor = current and Color3.fromRGB(91, 104, 124) or (unlocked and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(28, 160, 92))
		local button = makeButton(card, label, buttonColor)
		button.Position = UDim2.new(1, -106, 0, 28)
		button.Size = UDim2.new(0, 90, 0, 36)
		button.ZIndex = 93
		button.MouseButton1Click:Connect(function()
			if current then
				setBiomeWarpVisible(false)
			elseif unlocked then
				setBiomeWarpVisible(false)
				TeleportTo:FireServer(biomeId)
			else
				UnlockBiome:FireServer(biomeId)
			end
		end)
	end
end

local function openBiomeWarp()
	renderBiomeWarpOptions()
	setBiomeWarpVisible(true)
end

biomeWarpClose.MouseButton1Click:Connect(function()
	setBiomeWarpVisible(false)
end)

if OpenBiomeWarp then
	OpenBiomeWarp.OnClientEvent:Connect(openBiomeWarp)
else
	warn("OpenBiomeWarp remote was not available; biome warp popup is disabled until remotes resync.")
end

local hud = Instance.new("Frame")
hud.Name = "Hud"
hud.Position = UDim2.new(0, 18, 0, 18)
hud.Size = UDim2.new(0, 430, 0, 92)
hud.BackgroundColor3 = Color3.fromRGB(20, 25, 32)
hud.BackgroundTransparency = 0.08
hud.Parent = root
addCorner(hud, 8)
addStroke(hud, Color3.fromRGB(71, 85, 105), 1)

local title = makeText(hud, "Fishy Fish", 22, Color3.fromRGB(255, 255, 255), true)
title.Position = UDim2.new(0, 16, 0, 8)
title.Size = UDim2.new(1, -32, 0, 28)

local statsText = makeText(hud, "Loading...", 15, Color3.fromRGB(196, 211, 227), false)
statsText.Position = UDim2.new(0, 16, 0, 40)
statsText.Size = UDim2.new(1, -32, 0, 22)

local statusText = makeText(hud, "Ready.", 14, Color3.fromRGB(143, 215, 255), false)
statusText.Position = UDim2.new(0, 16, 0, 64)
statusText.Size = UDim2.new(1, -32, 0, 20)

local centerControls = Instance.new("Frame")
centerControls.Name = "CenterControls"
centerControls.AnchorPoint = Vector2.new(0.5, 1)
centerControls.Position = UDim2.new(0.5, 0, 1, -84)
centerControls.Size = UDim2.new(0.68, 0, 0, 126)
centerControls.BackgroundColor3 = Color3.fromRGB(7, 48, 115)
centerControls.BackgroundTransparency = 0
centerControls.ZIndex = 20
centerControls.Parent = root
addCorner(centerControls, 28)
addStroke(centerControls, Color3.fromRGB(0, 88, 215), 7)
addStroke(centerControls, Color3.fromRGB(87, 198, 255), 2).Transparency = 0.08
addGradient(centerControls, Color3.fromRGB(11, 65, 147), Color3.fromRGB(4, 34, 91), 90)

local centerConstraint = Instance.new("UISizeConstraint")
centerConstraint.MinSize = Vector2.new(560, 110)
centerConstraint.MaxSize = Vector2.new(980, 138)
centerConstraint.Parent = centerControls

local centerInner = Instance.new("Frame")
centerInner.Name = "InnerGlow"
centerInner.Position = UDim2.new(0, 13, 0, 13)
centerInner.Size = UDim2.new(1, -26, 1, -26)
centerInner.BackgroundTransparency = 1
centerInner.ZIndex = 21
centerInner.Parent = centerControls
addCorner(centerInner, 28)
addStroke(centerInner, Color3.fromRGB(73, 180, 255), 2).Transparency = 0.35
addGloss(centerControls, UDim2.new(0, 24, 0, 15), UDim2.new(0, 108, 0, 10))

local centerTitle = makeText(centerControls, "Beginner Pond", 15, Color3.fromRGB(230, 238, 248), true)
centerTitle.AnchorPoint = Vector2.new(0.5, 0)
centerTitle.Position = UDim2.new(0.5, 0, 0, -34)
centerTitle.Size = UDim2.new(0.43, 0, 0, 62)
centerTitle.BackgroundColor3 = Color3.fromRGB(20, 143, 255)
centerTitle.BackgroundTransparency = 1
centerTitle.ZIndex = 25
centerTitle.Visible = false
centerTitle.TextXAlignment = Enum.TextXAlignment.Center
styleOutlinedText(centerTitle, 36)
centerTitle.TextScaled = true
limitTextSize(centerTitle, 18, 26)
forcePureWhiteText(centerTitle)
setCornerRadius(centerTitle, 30)
addStroke(centerTitle, Color3.fromRGB(0, 66, 168), 6)
addStroke(centerTitle, Color3.fromRGB(104, 208, 255), 2).Transparency = 0.18
addGradient(centerTitle, Color3.fromRGB(47, 156, 255), Color3.fromRGB(6, 95, 226), 90)
addGloss(centerTitle, UDim2.new(0, 22, 0, 12), UDim2.new(0, 82, 0, 12))

local centerCastButton = makeButton(centerControls, "Cast Rod", Color3.fromRGB(28, 160, 92))
centerCastButton.Position = UDim2.new(0, 42, 0, 34)
centerCastButton.Size = UDim2.new(0.48, -58, 0, 62)
centerCastButton.ZIndex = 24
styleOutlinedText(centerCastButton, 38)
centerCastButton.TextScaled = true
limitTextSize(centerCastButton, 16, 28)
forcePureWhiteText(centerCastButton)
setCornerRadius(centerCastButton, 24)
addStroke(centerCastButton, Color3.fromRGB(0, 91, 16), 7)
local centerCastGradient = addGradient(centerCastButton, Color3.fromRGB(135, 255, 119), Color3.fromRGB(25, 218, 46), 90)
addGloss(centerCastButton, UDim2.new(0, 20, 0, 11), UDim2.new(0, 104, 0, 10))

local centerAutoButton = makeButton(centerControls, "AutoFish: OFF", Color3.fromRGB(53, 130, 246))
centerAutoButton.Position = UDim2.new(0.52, 16, 0, 34)
centerAutoButton.Size = UDim2.new(0.48, -58, 0, 62)
centerAutoButton.ZIndex = 24
styleOutlinedText(centerAutoButton, 34)
centerAutoButton.TextScaled = true
limitTextSize(centerAutoButton, 15, 28)
forcePureWhiteText(centerAutoButton)
setCornerRadius(centerAutoButton, 24)
addStroke(centerAutoButton, Color3.fromRGB(0, 58, 147), 7)
local centerAutoGradient = addGradient(centerAutoButton, Color3.fromRGB(92, 191, 255), Color3.fromRGB(16, 126, 255), 90)
addGloss(centerAutoButton, UDim2.new(0, 20, 0, 11), UDim2.new(0, 104, 0, 10))

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -18, 0.42, 0)
panel.Size = UDim2.new(0, 430, 0, 500)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 29)
panel.BackgroundTransparency = 0.04
panel.Parent = root
addCorner(panel, 8)
addStroke(panel, Color3.fromRGB(71, 85, 105), 1)

local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.Position = UDim2.new(0, 12, 0, 12)
tabs.Size = UDim2.new(1, -24, 0, 78)
tabs.BackgroundTransparency = 1
tabs.Parent = panel

local tabGrid = Instance.new("UIGridLayout")
tabGrid.CellSize = UDim2.new(0, 96, 0, 32)
tabGrid.CellPadding = UDim2.new(0, 7, 0, 7)
tabGrid.SortOrder = Enum.SortOrder.LayoutOrder
tabGrid.Parent = tabs

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.new(0, 12, 0, 100)
content.Size = UDim2.new(1, -24, 1, -112)
content.BackgroundTransparency = 1
content.ScrollBarThickness = 6
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = panel

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 8)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

local minigame = Instance.new("Frame")
minigame.Name = "TimingGame"
minigame.AnchorPoint = Vector2.new(0.5, 0.5)
minigame.Position = UDim2.new(0.5, 0, 0.44, 0)
minigame.Size = UDim2.new(0.62, 0, 0, 210)
minigame.BackgroundColor3 = Color3.fromRGB(10, 68, 155)
minigame.Visible = false
minigame.ZIndex = 40
minigame.Parent = root
addCorner(minigame, 30)
addStroke(minigame, Color3.fromRGB(0, 78, 190), 7)
addStroke(minigame, Color3.fromRGB(99, 210, 255), 2).Transparency = 0.08
addGradient(minigame, Color3.fromRGB(18, 92, 198), Color3.fromRGB(7, 52, 132), 90)

local minigameConstraint = Instance.new("UISizeConstraint")
minigameConstraint.MinSize = Vector2.new(500, 182)
minigameConstraint.MaxSize = Vector2.new(860, 230)
minigameConstraint.Parent = minigame

local minigameInner = Instance.new("Frame")
minigameInner.Name = "InnerStroke"
minigameInner.Position = UDim2.new(0, 14, 0, 14)
minigameInner.Size = UDim2.new(1, -28, 1, -28)
minigameInner.BackgroundTransparency = 1
minigameInner.ZIndex = 41
minigameInner.Parent = minigame
addCorner(minigameInner, 26)
addStroke(minigameInner, Color3.fromRGB(91, 193, 255), 2).Transparency = 0.38
addGloss(minigame, UDim2.new(0, 22, 0, 18), UDim2.new(0, 90, 0, 12))

local minigameText = makeText(minigame, "Wait for a bite...", 18, Color3.fromRGB(255, 255, 255), true)
minigameText.Position = UDim2.new(0, 40, 0, 24)
minigameText.Size = UDim2.new(1, -80, 0, 44)
minigameText.ZIndex = 44
styleOutlinedText(minigameText, 36)
minigameText.TextScaled = true
forcePureWhiteText(minigameText)

local minigameTextSizeConstraint = Instance.new("UITextSizeConstraint")
minigameTextSizeConstraint.MinTextSize = 16
minigameTextSizeConstraint.MaxTextSize = 24
minigameTextSizeConstraint.Parent = minigameText

local timingBar = Instance.new("Frame")
timingBar.Name = "Bar"
timingBar.Position = UDim2.new(0, 40, 0, 86)
timingBar.Size = UDim2.new(1, -80, 0, 44)
timingBar.BackgroundColor3 = Color3.fromRGB(57, 99, 150)
timingBar.ZIndex = 43
timingBar.Parent = minigame
addCorner(timingBar, 24)
addStroke(timingBar, Color3.fromRGB(7, 52, 121), 5)
addStroke(timingBar, Color3.fromRGB(147, 178, 212), 2).Transparency = 0.22
addGradient(timingBar, Color3.fromRGB(92, 132, 181), Color3.fromRGB(48, 88, 143), 90)

local zone = Instance.new("Frame")
zone.Name = "Zone"
zone.BackgroundColor3 = Color3.fromRGB(30, 231, 53)
zone.Size = UDim2.new(0.22, 0, 1, 0)
zone.Position = UDim2.new(0.39, 0, 0, 0)
zone.ZIndex = 44
zone.Parent = timingBar
addCorner(zone, 16)
addStroke(zone, Color3.fromRGB(3, 96, 19), 4)
addGradient(zone, Color3.fromRGB(104, 255, 81), Color3.fromRGB(16, 194, 38), 90)
addGloss(zone, UDim2.new(0, 14, 0, 8), UDim2.new(0, 66, 0, 9))

local marker = Instance.new("Frame")
marker.Name = "Marker"
marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
marker.Size = UDim2.new(0, 16, 1, 28)
marker.Position = UDim2.new(0, 0, 0, -14)
marker.ZIndex = 45
marker.Parent = timingBar
addCorner(marker, 9)
addStroke(marker, Color3.fromRGB(7, 55, 128), 3)

local catchButton = makeButton(minigame, "Catch!", Color3.fromRGB(28, 160, 92))
catchButton.AnchorPoint = Vector2.new(0.5, 1)
catchButton.Position = UDim2.new(0.5, 0, 1, -18)
catchButton.Size = UDim2.new(0.29, 0, 0, 52)
catchButton.ZIndex = 44
styleOutlinedText(catchButton, 34)
catchButton.TextScaled = true
limitTextSize(catchButton, 15, 24)
forcePureWhiteText(catchButton)
setCornerRadius(catchButton, 24)
addStroke(catchButton, Color3.fromRGB(0, 92, 18), 7)
addGradient(catchButton, Color3.fromRGB(104, 255, 91), Color3.fromRGB(17, 196, 38), 90)
addGloss(catchButton, UDim2.new(0, 22, 0, 13), UDim2.new(0, 90, 0, 12))

local function setMinigameVisible(visible)
	minigame.Visible = visible
	fishingBlur.Enabled = visible
	fishingBlur.Size = visible and 10 or 0
end

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 22)
toast.Size = UDim2.new(0, 520, 0, 38)
toast.BackgroundColor3 = Color3.fromRGB(20, 25, 32)
toast.BackgroundTransparency = 0.06
toast.Font = Enum.Font.GothamBold
toast.TextColor3 = Color3.fromRGB(255, 255, 255)
toast.TextSize = 16
toast.Visible = false
toast.Parent = root
addCorner(toast, 8)
addStroke(toast, Color3.fromRGB(255, 255, 255), 1).Transparency = 0.88

local function showToast(message)
	statusText.Text = message
	toast.Text = message
	toast.Visible = true

	task.delay(3, function()
		if toast.Text == message then
			toast.Visible = false
		end
	end)
end

local function makeCard(parent, height)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, height)
	card.BackgroundColor3 = Color3.fromRGB(27, 33, 43)
	card.Parent = parent
	addCorner(card, 8)
	addStroke(card, Color3.fromRGB(60, 72, 90), 1)
	return card
end

local function getDiscoveredCount()
	if not state or not state.Fishdex then
		return 0
	end

	local count = 0
	for _, amount in pairs(state.Fishdex) do
		if amount > 0 then
			count += 1
		end
	end
	return count
end

local function refreshHud()
	if not state then
		statsText.Text = "Loading..."
		return
	end

	local nextText = state.NextLevelXP > 0 and (state.LevelProgressXP .. "/" .. state.NextLevelXP .. " XP") or "MAX"
	statsText.Text = string.format(
		"Coins: %d   Level: %d   XP: %s   Bag: %d/%d",
		state.Coins,
		state.Level,
		nextText,
		#state.Inventory,
		state.BackpackSize
	)
end

local renderContent

local function startManualFishing()
	if fishingBusy or not state then
		return
	end

	local biome = GameConfig.Biomes[state.CurrentBiome] or GameConfig.Biomes.BeginnerPond
	fishingBusy = true
	showToast("Casting in " .. biome.displayName .. "...")
	setMinigameVisible(true)
	minigameText.Text = "Waiting for a fish..."
	forcePureWhiteText(minigameText)
	forcePureWhiteText(catchButton)
	catchButton.Visible = false
	StartFishing:FireServer(state.CurrentBiome)
	renderContent()
end

local function refreshCenterControls()
	if not state then
		centerTitle.Text = "Beginner Pond"
		centerTitle.Visible = false
		centerCastButton.Text = "Cast Rod"
		centerAutoButton.Text = "AutoFish: OFF"
		forcePureWhiteText(centerTitle)
		forcePureWhiteText(centerCastButton)
		forcePureWhiteText(centerAutoButton)
		centerAutoButton.BackgroundColor3 = Color3.fromRGB(53, 130, 246)
		centerAutoGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 191, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 126, 255)),
		})
		return
	end

	local biome = GameConfig.Biomes[state.CurrentBiome] or GameConfig.Biomes.BeginnerPond
	centerTitle.Text = biome.displayName
	centerTitle.Visible = false
	centerCastButton.Text = fishingBusy and "Fishing..." or "Cast Rod"
	centerAutoButton.Text = state.AutoFishEnabled and "AutoFish: ON" or "AutoFish: OFF"
	forcePureWhiteText(centerTitle)
	forcePureWhiteText(centerCastButton)
	forcePureWhiteText(centerAutoButton)

	if state.AutoFishEnabled then
		centerAutoButton.BackgroundColor3 = Color3.fromRGB(43, 142, 255)
		centerAutoGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 191, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 126, 255)),
		})
	else
		centerAutoButton.BackgroundColor3 = Color3.fromRGB(53, 130, 246)
		centerAutoGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 191, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 126, 255)),
		})
	end
end

centerCastButton.MouseButton1Click:Connect(startManualFishing)

centerAutoButton.MouseButton1Click:Connect(function()
	ToggleAutoFish:FireServer()
end)

local function setTab(tabName)
	activeTab = tabName
	renderContent()
end

local function refreshTabs()
	clearChildren(tabs)

	local tabNames = { "Fish", "Rods", "Bag", "Fishdex", "Aquarium", "Teleport" }
	for _, tabName in ipairs(tabNames) do
		local color = activeTab == tabName and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(38, 45, 57)
		local button = makeButton(tabs, tabName, color)
		button.MouseButton1Click:Connect(function()
			setTab(tabName)
		end)
	end
end

local function renderFishTab()
	local biome = state and GameConfig.Biomes[state.CurrentBiome] or GameConfig.Biomes.BeginnerPond
	local rod = state and GameConfig.Rods[state.EquippedRod] or GameConfig.Rods.WoodenRod

	local card = makeCard(content, 132)
	local heading = makeText(card, "Current Biome: " .. biome.displayName, 19, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 14, 0, 10)
	heading.Size = UDim2.new(1, -28, 0, 28)

	local autoStatus = state.AutoFishEnabled and "ON" or "OFF"
	local detail = makeText(card, "Rod: " .. rod.displayName .. "  |  Luck: +" .. math.floor(rod.luck * 100) .. "%  |  AutoFish: " .. autoStatus, 14, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 14, 0, 44)
	detail.Size = UDim2.new(1, -28, 0, 24)

	local collection = makeText(card, "Fishdex: " .. getDiscoveredCount() .. "/" .. GameConfig.getFishCount(), 13, Color3.fromRGB(143, 160, 180), false)
	collection.Position = UDim2.new(0, 14, 0, 68)
	collection.Size = UDim2.new(1, -28, 0, 20)

	local hint = makeText(card, "Use the center buttons to cast manually or toggle AutoFish.", 13, Color3.fromRGB(143, 160, 180), false)
	hint.Position = UDim2.new(0, 14, 0, 96)
	hint.Size = UDim2.new(1, -28, 0, 22)

	local listHeader = makeText(content, "Fish in this biome", 17, Color3.fromRGB(255, 255, 255), true)
	listHeader.Size = UDim2.new(1, -8, 0, 28)

	for _, fish in ipairs(biome.fish) do
		local fishCard = makeCard(content, 64)
		local color = GameConfig.RarityColors[fish.rarity] or Color3.fromRGB(255, 255, 255)

		local icon = makeFishIcon(fishCard, fish.id, fish.rarity, true)
		icon.Position = UDim2.new(0, 8, 0, 6)
		icon.Size = UDim2.new(0, 52, 0, 52)

		local name = makeText(fishCard, fish.name .. " [" .. fish.rarity .. "]", 15, color, true)
		name.Position = UDim2.new(0, 68, 0, 8)
		name.Size = UDim2.new(1, -80, 0, 22)

		local info = makeText(fishCard, string.format("Chance: %s%%   Sell: %d Coins", fish.chance, fish.value), 13, Color3.fromRGB(190, 204, 220), false)
		info.Position = UDim2.new(0, 68, 0, 34)
		info.Size = UDim2.new(1, -80, 0, 18)
	end
end

local function renderRodsTab()
	for _, rodId in ipairs(GameConfig.RodOrder) do
		local rod = GameConfig.Rods[rodId]
		local owned = state and state.OwnedRods[rodId]
		local equipped = state and state.EquippedRod == rodId
		local canAfford = state and state.Coins >= rod.cost
		local levelOK = state and state.Level >= rod.unlockLevel

		local card = makeCard(content, 84)

		local icon = makeRodIcon(card, rodId)
		icon.Position = UDim2.new(0, 8, 0, 10)
		icon.Size = UDim2.new(0, 64, 0, 64)

		local name = makeText(card, rod.displayName, 16, Color3.fromRGB(255, 255, 255), true)
		name.Position = UDim2.new(0, 84, 0, 8)
		name.Size = UDim2.new(1, -204, 0, 22)

		local info = makeText(card, string.format("Cost: %d | Unlock: Level %d | Luck: +%d%%", rod.cost, rod.unlockLevel, math.floor(rod.luck * 100)), 13, Color3.fromRGB(190, 204, 220), false)
		info.Position = UDim2.new(0, 84, 0, 34)
		info.Size = UDim2.new(1, -204, 0, 20)

		local extra = rod.requiredBiome and ("Requires " .. GameConfig.Biomes[rod.requiredBiome].displayName) or "Improves speed and timing zone."
		local desc = makeText(card, extra, 12, Color3.fromRGB(143, 160, 180), false)
		desc.Position = UDim2.new(0, 84, 0, 58)
		desc.Size = UDim2.new(1, -204, 0, 18)

		local label = equipped and "Equipped" or (owned and "Equip" or "Buy")
		local color = equipped and Color3.fromRGB(91, 104, 124) or Color3.fromRGB(53, 130, 246)
		if not owned and (not canAfford or not levelOK) then
			color = Color3.fromRGB(86, 98, 115)
		end

		local button = makeButton(card, label, color)
		button.Position = UDim2.new(1, -110, 0, 24)
		button.Size = UDim2.new(0, 94, 0, 36)
		button.MouseButton1Click:Connect(function()
			BuyRod:FireServer(rodId)
		end)
	end
end

local function renderBiomesTab()
	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		local unlocked = state and state.UnlockedBiomes[biomeId]
		local current = state and state.CurrentBiome == biomeId

		local card = makeCard(content, 96)
		local name = makeText(card, biome.displayName, 16, biome.color, true)
		name.Position = UDim2.new(0, 12, 0, 8)
		name.Size = UDim2.new(1, -132, 0, 22)

		local info = makeText(card, "Unlock: " .. GameConfig.getBiomeUnlockText(biomeId), 13, Color3.fromRGB(190, 204, 220), false)
		info.Position = UDim2.new(0, 12, 0, 34)
		info.Size = UDim2.new(1, -132, 0, 20)

		local fishCount = makeText(card, "Species: " .. #biome.fish, 12, Color3.fromRGB(143, 160, 180), false)
		fishCount.Position = UDim2.new(0, 12, 0, 58)
		fishCount.Size = UDim2.new(1, -132, 0, 18)

		local label = current and "Selected" or (unlocked and "Select" or "Unlock")
		local color = unlocked and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(53, 130, 246)
		if current then
			color = Color3.fromRGB(91, 104, 124)
		end

		local button = makeButton(card, label, color)
		button.Position = UDim2.new(1, -110, 0, 26)
		button.Size = UDim2.new(0, 94, 0, 36)
		button.MouseButton1Click:Connect(function()
			if unlocked then
				TeleportTo:FireServer(biomeId)
			else
				UnlockBiome:FireServer(biomeId)
			end
		end)
	end
end

local function renderBagTab()
	local top = makeCard(content, 82)
	local value = state and state.InventoryValue or 0
	local ownedRodCount = 0
	for _, rodId in ipairs(GameConfig.RodOrder) do
		if state and state.OwnedRods[rodId] then
			ownedRodCount += 1
		end
	end

	local heading = makeText(top, "Inventory", 17, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 12, 0, 8)
	heading.Size = UDim2.new(1, -132, 0, 24)

	local detail = makeText(top, string.format("%d/%d fish | %d rods | Total value: %d coins", #state.Inventory, state.BackpackSize, ownedRodCount, value), 14, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 12, 0, 38)
	detail.Size = UDim2.new(1, -132, 0, 22)

	local sell = makeButton(top, "Sell All", Color3.fromRGB(230, 126, 48))
	sell.Position = UDim2.new(1, -110, 0, 23)
	sell.Size = UDim2.new(0, 94, 0, 36)
	sell.MouseButton1Click:Connect(function()
		SellFish:FireServer()
	end)

	local rodsHeader = makeText(content, "Rods", 16, Color3.fromRGB(255, 255, 255), true)
	rodsHeader.Size = UDim2.new(1, -8, 0, 28)

	for _, rodId in ipairs(GameConfig.RodOrder) do
		if state.OwnedRods[rodId] then
			local rod = GameConfig.Rods[rodId]
			local equipped = state.EquippedRod == rodId
			local card = makeCard(content, 76)

			local icon = makeRodIcon(card, rodId)
			icon.Position = UDim2.new(0, 8, 0, 6)
			icon.Size = UDim2.new(0, 64, 0, 64)

			local name = makeText(card, rod.displayName, 15, Color3.fromRGB(255, 255, 255), true)
			name.Position = UDim2.new(0, 84, 0, 8)
			name.Size = UDim2.new(1, -204, 0, 22)

			local info = makeText(card, string.format("Luck: +%d%% | Speed: %d%%", math.floor(rod.luck * 100), math.floor((1 / rod.speed) * 100)), 12, Color3.fromRGB(190, 204, 220), false)
			info.Position = UDim2.new(0, 84, 0, 34)
			info.Size = UDim2.new(1, -204, 0, 18)

			local status = makeText(card, equipped and "Equipped" or "Owned", 12, equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(143, 160, 180), true)
			status.Position = UDim2.new(0, 84, 0, 52)
			status.Size = UDim2.new(1, -204, 0, 18)

			local button = makeButton(card, equipped and "Equipped" or "Equip", equipped and Color3.fromRGB(91, 104, 124) or Color3.fromRGB(53, 130, 246))
			button.Position = UDim2.new(1, -110, 0, 20)
			button.Size = UDim2.new(0, 94, 0, 36)
			button.MouseButton1Click:Connect(function()
				if not equipped then
					BuyRod:FireServer(rodId)
				end
			end)
		end
	end

	local fishHeader = makeText(content, "Fish", 16, Color3.fromRGB(255, 255, 255), true)
	fishHeader.Size = UDim2.new(1, -8, 0, 28)

	for index = #state.Inventory, 1, -1 do
		local fish = state.Inventory[index]
		local card = makeCard(content, 84)
		local color = GameConfig.RarityColors[fish.rarity] or Color3.fromRGB(255, 255, 255)

		local icon = makeFishIcon(card, fish.id, fish.rarity, true)
		icon.Position = UDim2.new(0, 8, 0, 13)
		icon.Size = UDim2.new(0, 58, 0, 58)

		local name = makeText(card, fish.name .. " [" .. fish.rarity .. "]", 15, color, true)
		name.Position = UDim2.new(0, 76, 0, 9)
		name.Size = UDim2.new(1, -176, 0, 22)

		local fishSpace = GameConfig.getAquariumFishSpace(fish)
		local info = makeText(card, string.format("Value: %d | Aquarium: %d space", fish.value, fishSpace), 13, Color3.fromRGB(190, 204, 220), false)
		info.Position = UDim2.new(0, 76, 0, 34)
		info.Size = UDim2.new(1, -176, 0, 18)

		local display = makeButton(card, "Display", Color3.fromRGB(53, 130, 246))
		display.Position = UDim2.new(1, -92, 0, 8)
		display.Size = UDim2.new(0, 76, 0, 30)
		display.TextSize = 12
		display.MouseButton1Click:Connect(function()
			AquariumAction:FireServer("DisplayFish", fish.serial, index)
		end)

		local sellOne = makeButton(card, "Sell", Color3.fromRGB(230, 126, 48))
		sellOne.Position = UDim2.new(1, -92, 0, 46)
		sellOne.Size = UDim2.new(0, 76, 0, 30)
		sellOne.TextSize = 12
		sellOne.MouseButton1Click:Connect(function()
			SellFish:FireServer("Single", fish.serial, index)
		end)
	end
end

local function renderFishdexTab()
	local summary = makeCard(content, 58)
	local titleLabel = makeText(summary, "Fishdex Collection: " .. getDiscoveredCount() .. "/" .. GameConfig.getFishCount(), 16, Color3.fromRGB(255, 255, 255), true)
	titleLabel.Position = UDim2.new(0, 12, 0, 14)
	titleLabel.Size = UDim2.new(1, -24, 0, 26)

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		local header = makeText(content, biome.displayName, 16, biome.color, true)
		header.Size = UDim2.new(1, -8, 0, 28)

		for _, fish in ipairs(biome.fish) do
			local count = state.Fishdex[fish.id] or 0
			local discovered = count > 0
			local card = makeCard(content, 62)
			local color = discovered and (GameConfig.RarityColors[fish.rarity] or Color3.new(1, 1, 1)) or Color3.fromRGB(115, 125, 140)

			local icon = makeFishIcon(card, fish.id, fish.rarity, discovered)
			icon.Position = UDim2.new(0, 8, 0, 6)
			icon.Size = UDim2.new(0, 50, 0, 50)

			local name = makeText(card, discovered and fish.name or "???", 14, color, true)
			name.Position = UDim2.new(0, 68, 0, 7)
			name.Size = UDim2.new(1, -80, 0, 20)

			local infoText = discovered and string.format("%s | Caught: %d | Value: %d", fish.rarity, count, fish.value) or (fish.rarity .. " | Not discovered")
			local info = makeText(card, infoText, 12, Color3.fromRGB(190, 204, 220), false)
			info.Position = UDim2.new(0, 68, 0, 31)
			info.Size = UDim2.new(1, -80, 0, 16)
		end
	end
end

local function renderAquariumTab()
	local aquarium = state.Aquarium
	local capacity = aquarium.Capacity
	local usedCapacity = aquarium.UsedCapacity or GameConfig.getAquariumUsedSpace(aquarium.Fish)

	local top = makeCard(content, 96)
	local heading = makeText(top, "Personal Aquarium", 17, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 12, 0, 8)
	heading.Size = UDim2.new(1, -24, 0, 24)

	local info = makeText(top, string.format("Level %d | Space %d/%d", aquarium.Level, usedCapacity, capacity), 14, Color3.fromRGB(190, 204, 220), false)
	info.Position = UDim2.new(0, 12, 0, 36)
	info.Size = UDim2.new(1, -24, 0, 22)

	local best = state.BestCatch and ("Best: " .. state.BestCatch.name .. " (" .. state.BestCatch.value .. " coins)") or "Best: None yet"
	local bestText = makeText(top, best, 13, Color3.fromRGB(143, 160, 180), false)
	bestText.Position = UDim2.new(0, 12, 0, 60)
	bestText.Size = UDim2.new(1, -184, 0, 20)

	local nextCost = GameConfig.AquariumUpgradeCosts[aquarium.Level + 1]
	local upgrade = makeButton(top, nextCost and ("Upgrade " .. nextCost) or "Max Level", Color3.fromRGB(28, 160, 92))
	upgrade.Position = UDim2.new(1, -162, 0, 58)
	upgrade.Size = UDim2.new(0, 150, 0, 28)
	upgrade.MouseButton1Click:Connect(function()
		AquariumAction:FireServer("Upgrade")
	end)

	for index, fish in ipairs(aquarium.Fish) do
		local card = makeCard(content, 62)
		local color = GameConfig.RarityColors[fish.rarity] or Color3.new(1, 1, 1)
		local name = makeText(card, index .. ". " .. fish.name .. " [" .. fish.rarity .. "]", 14, color, true)
		name.Position = UDim2.new(0, 12, 0, 6)
		name.Size = UDim2.new(1, -118, 0, 20)

		local fishSpace = GameConfig.getAquariumFishSpace(fish)
		local valueText = makeText(card, "Value: " .. fish.value .. " coins | Space: " .. fishSpace, 12, Color3.fromRGB(190, 204, 220), false)
		valueText.Position = UDim2.new(0, 12, 0, 26)
		valueText.Size = UDim2.new(1, -118, 0, 16)

		local remove = makeButton(card, "Remove", Color3.fromRGB(230, 126, 48))
		remove.Position = UDim2.new(1, -94, 0, 15)
		remove.Size = UDim2.new(0, 78, 0, 32)
		remove.TextSize = 12
		remove.MouseButton1Click:Connect(function()
			AquariumAction:FireServer("RemoveFish", fish.serial, index)
		end)
	end
end

local function renderTeleportTab()
	local targets = {
		{ id = "Lobby", name = "Lobby", requirement = "Free" },
		{ id = "Home", name = "Home Aquarium", requirement = "Free" },
	}

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		table.insert(targets, {
			id = biomeId,
			name = biome.displayName,
			biome = biome,
			requirement = GameConfig.getBiomeUnlockText(biomeId),
		})
	end

	for _, target in ipairs(targets) do
		local biome = target.biome
		local unlocked = not biome or state.UnlockedBiomes[target.id]
		local current = biome and state.CurrentBiome == target.id
		local card = makeCard(content, biome and 96 or 72)
		local nameColor = biome and biome.color or Color3.fromRGB(255, 255, 255)
		if not unlocked then
			nameColor = Color3.fromRGB(130, 140, 155)
		end

		local name = makeText(card, target.name, 16, nameColor, true)
		name.Position = UDim2.new(0, 12, 0, 8)
		name.Size = UDim2.new(1, -132, 0, 22)

		local requirement = makeText(card, "Requirement: " .. target.requirement, 13, Color3.fromRGB(190, 204, 220), false)
		requirement.Position = UDim2.new(0, 12, 0, 34)
		requirement.Size = UDim2.new(1, -132, 0, 20)

		local detailText = biome and ("Species: " .. #biome.fish) or "Safe travel point"
		local detail = makeText(card, detailText, 12, Color3.fromRGB(143, 160, 180), false)
		detail.Position = UDim2.new(0, 12, 0, 58)
		detail.Size = UDim2.new(1, -132, 0, 18)

		local label = current and "Selected" or (unlocked and "Go" or "Unlock")
		local color = unlocked and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(28, 160, 92)
		if current then
			color = Color3.fromRGB(91, 104, 124)
		end

		local button = makeButton(card, label, color)
		button.Position = UDim2.new(1, -110, 0, biome and 30 or 19)
		button.Size = UDim2.new(0, 94, 0, 36)
		button.MouseButton1Click:Connect(function()
			if unlocked then
				TeleportTo:FireServer(target.id)
			elseif biome then
				UnlockBiome:FireServer(target.id)
			end
		end)
	end
end

renderContent = function()
	if activeTab == "Biomes" then
		activeTab = "Teleport"
	end

	refreshHud()
	refreshCenterControls()
	refreshTabs()
	clearChildren(content)

	if not state then
		local loading = makeText(content, "Loading player data...", 16, Color3.fromRGB(255, 255, 255), true)
		loading.Size = UDim2.new(1, -8, 0, 40)
		return
	end

	if activeTab == "Fish" then
		renderFishTab()
	elseif activeTab == "Rods" then
		renderRodsTab()
	elseif activeTab == "Bag" then
		renderBagTab()
	elseif activeTab == "Fishdex" then
		renderFishdexTab()
	elseif activeTab == "Aquarium" then
		renderAquariumTab()
	elseif activeTab == "Teleport" then
		renderTeleportTab()
	end
end

local function runMinigame(prompt)
	if minigameRunning then
		return
	end

	local isAutoFish = prompt.autoFish == true
	minigameRunning = true
	setMinigameVisible(true)
	catchButton.Visible = false
	minigameText.Text = isAutoFish and "AutoFish is waiting for a bite..." or "Waiting for a fish..."
	forcePureWhiteText(minigameText)
	forcePureWhiteText(catchButton)

	task.wait(prompt.biteDelay)

	if not minigameRunning then
		return
	end

	local zoneSize = prompt.zoneSize or 0.22
	local zoneStart = Random.new():NextNumber(0.12, 0.88 - zoneSize)
	local speed = prompt.markerSpeed or 1
	local markerPosition = 0
	local direction = 1
	local caught = false

	zone.Size = UDim2.new(zoneSize, 0, 1, 0)
	zone.Position = UDim2.new(zoneStart, 0, 0, 0)
	marker.Position = UDim2.new(0, 0, 0, -14)
	catchButton.Visible = not isAutoFish
	minigameText.Text = isAutoFish and "AutoFish is timing the catch..." or "Click when the marker is in the green zone."
	forcePureWhiteText(minigameText)
	forcePureWhiteText(catchButton)

	local connection
	local function finish()
		if caught then
			return
		end

		caught = true

		local zoneEnd = zoneStart + zoneSize
		local center = zoneStart + (zoneSize / 2)
		local score = 0

		if markerPosition >= zoneStart and markerPosition <= zoneEnd then
			local distance = math.abs(markerPosition - center)
			score = math.clamp(1 - (distance / (zoneSize / 2)), 0.35, 1)
		end

		if connection then
			connection:Disconnect()
		end

		setMinigameVisible(false)
		minigameRunning = false
		fishingBusy = false

		if not isAutoFish then
			FinishMinigame:FireServer(score)
		end

		renderContent()
	end

	local autoStartedAt = os.clock()
	local autoVisualTime = prompt.visualTime or 2.4
	local autoScore = math.clamp(prompt.autoScore or 0.5, 0.35, 0.85)
	local autoDirection = Random.new():NextInteger(0, 1) == 0 and -1 or 1
	local autoTarget = math.clamp(
		(zoneStart + (zoneSize / 2)) + (autoDirection * (1 - autoScore) * (zoneSize / 2)),
		zoneStart + 0.01,
		zoneStart + zoneSize - 0.01
	)

	connection = RunService.RenderStepped:Connect(function(deltaTime)
		if isAutoFish then
			local alpha = math.clamp((os.clock() - autoStartedAt) / autoVisualTime, 0, 1)
			markerPosition = markerPosition + ((autoTarget - markerPosition) * math.min(1, deltaTime * 4.5))

			if alpha >= 1 then
				minigameText.Text = "AutoFish caught it!"
				finish()
			end
		else
			markerPosition += direction * deltaTime * 0.72 * speed

			if markerPosition >= 1 then
				markerPosition = 1
				direction = -1
			elseif markerPosition <= 0 then
				markerPosition = 0
				direction = 1
			end
		end

		marker.Position = UDim2.new(markerPosition, -8, 0, -14)
	end)

	local clickConnection = nil
	if not isAutoFish then
		clickConnection = catchButton.MouseButton1Click:Connect(function()
			clickConnection:Disconnect()
			finish()
		end)
	end

	task.delay(isAutoFish and (autoVisualTime + 1) or 6, function()
		if minigameRunning and not caught then
			if clickConnection and clickConnection.Connected then
				clickConnection:Disconnect()
			end

			if connection then
				connection:Disconnect()
			end

			setMinigameVisible(false)
			minigameRunning = false
			fishingBusy = false

			if not isAutoFish then
				FinishMinigame:FireServer(0)
			end

			renderContent()
		end
	end)
end

StateUpdated.OnClientEvent:Connect(function(newState)
	state = newState
	refreshHud()
	renderContent()
	if biomeWarpOverlay.Visible then
		renderBiomeWarpOptions()
	end
end)

FishingPrompt.OnClientEvent:Connect(function(prompt)
	if prompt.autoFish then
		showToast("AutoFish is catching...")
	else
		showToast("Fish is biting. Time your catch!")
	end
	runMinigame(prompt)
end)

Notice.OnClientEvent:Connect(function(message)
	showToast(message)
	fishingBusy = false
	minigameRunning = false
	setMinigameVisible(false)
	renderContent()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.F and state and not fishingBusy then
		startManualFishing()
	elseif input.KeyCode == Enum.KeyCode.B then
		setTab("Bag")
	end
end)

task.spawn(function()
	local success, result = pcall(function()
		return GetState:InvokeServer()
	end)

	if success and result then
		state = result
	end

	renderContent()
end)
