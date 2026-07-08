local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	TextChatService.OnIncomingMessage = function(message)
		local source = message.TextSource
		if not source then
			return nil
		end

		local speaker = Players:GetPlayerByUserId(source.UserId)
		if not speaker or speaker:GetAttribute("FishyFishVip") ~= true then
			return nil
		end

		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = "<font color='#FFD94F'>[VIP]</font> " .. message.PrefixText
		return properties
	end
end

local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local StartFishing = Remotes:WaitForChild("StartFishing")
local GetCastConfig = Remotes:WaitForChild("GetCastConfig", 10)
local FinishMinigame = Remotes:WaitForChild("FinishMinigame")
local SellFish = Remotes:WaitForChild("SellFish")
local BuyRod = Remotes:WaitForChild("BuyRod")
local BaitAction = Remotes:WaitForChild("BaitAction", 10)
local QuestAction = Remotes:WaitForChild("QuestAction", 10)
local ShopAction = Remotes:WaitForChild("ShopAction", 10)
local UnlockBiome = Remotes:WaitForChild("UnlockBiome")
local TeleportTo = Remotes:WaitForChild("TeleportTo")
local OpenBiomeWarp = Remotes:WaitForChild("OpenBiomeWarp", 10)
local OpenSellFish = Remotes:WaitForChild("OpenSellFish", 10)
local OpenRodShop = Remotes:WaitForChild("OpenRodShop", 10)
local AquariumAction = Remotes:WaitForChild("AquariumAction")
local ToggleAutoFish = Remotes:WaitForChild("ToggleAutoFish")
local StateUpdated = Remotes:WaitForChild("StateUpdated")
local FishingPrompt = Remotes:WaitForChild("FishingPrompt")
local Notice = Remotes:WaitForChild("Notice")
local GetState = Remotes:WaitForChild("GetState")

local function fireBaitAction(action, baitId)
	if not BaitAction then
		BaitAction = Remotes:FindFirstChild("BaitAction")
	end

	if BaitAction then
		BaitAction:FireServer(action, baitId)
	else
		warn("BaitAction remote was not available; bait shop actions are disabled until remotes resync.")
	end
end

local function fireQuestAction(action, periodName, questId)
	if not QuestAction then
		QuestAction = Remotes:FindFirstChild("QuestAction")
	end

	if QuestAction then
		QuestAction:FireServer(action, periodName, questId)
	else
		warn("QuestAction remote was not available; quest claiming is disabled until remotes resync.")
	end
end

local function fireShopAction(action, category, itemKey, payload)
	if not ShopAction then
		ShopAction = Remotes:FindFirstChild("ShopAction")
	end

	if ShopAction then
		ShopAction:FireServer(action, category, itemKey, payload)
	else
		warn("ShopAction remote was not available; shop actions are disabled until remotes resync.")
	end
end

local screenGui = script.Parent
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

task.defer(function()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
end)

local state = nil
local activeTab = "Fishdex"
local activeQuestPeriod = "Daily"
local activeShopTab = "Game Passes"
local fishingBusy = false
local minigameRunning = false
local activeMinigameCleanup = nil
local biomeWarpActualBiome = nil
local panelCollapsed = false
local lastFishingBiomeId = nil

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

local function getBaitData(baitId)
	return GameConfig.getBait(baitId)
end

local function getBaitCount(baitId)
	if not state then
		return 0
	end

	baitId = baitId or GameConfig.BasicBaitId
	if baitId == GameConfig.BasicBaitId then
		return math.huge
	end

	local inventory = state.BaitInventory or {}
	return math.max(0, math.floor(tonumber(inventory[baitId]) or 0))
end

local function getBaitCountText(baitId, count)
	if baitId == GameConfig.BasicBaitId or count == math.huge or count == -1 then
		return "Unlimited"
	end

	return tostring(count or getBaitCount(baitId)) .. " left"
end

local function getEquippedBaitDisplay()
	local baitId = state and state.EquippedBait or GameConfig.BasicBaitId
	local bait = getBaitData(baitId)
	local remaining = state and state.EquippedBaitRemaining or -1

	return "Bait: " .. bait.displayName .. " (" .. getBaitCountText(baitId, remaining) .. ")"
end

local function getBaitEffectText(bait)
	local parts = {}

	if (tonumber(bait.biteSpeedMultiplier) or 1) < 1 then
		table.insert(parts, "faster bites")
	end
	if (tonumber(bait.rareChanceBonus) or 0) > 0 then
		table.insert(parts, "+" .. tostring(math.floor((bait.rareChanceBonus or 0) * 100)) .. "% rare luck")
	end
	if (tonumber(bait.valueMultiplier) or 1) > 1 then
		table.insert(parts, "+" .. tostring(math.floor(((bait.valueMultiplier or 1) - 1) * 100 + 0.5)) .. "% value")
	end
	if (tonumber(bait.xpMultiplier) or 1) > 1 then
		table.insert(parts, "+" .. tostring(math.floor(((bait.xpMultiplier or 1) - 1) * 100 + 0.5)) .. "% XP")
	end

	if #parts == 0 then
		return bait.description or "Default fishing."
	end

	return table.concat(parts, " | ")
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
		local current = biomeWarpActualBiome == biomeId
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

local function openBiomeWarp(actualBiome)
	biomeWarpActualBiome = actualBiome
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

local fishmongerOverlay = Instance.new("Frame")
fishmongerOverlay.Name = "FishmongerSellOverlay"
fishmongerOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fishmongerOverlay.BackgroundTransparency = 0.35
fishmongerOverlay.Size = UDim2.fromScale(1, 1)
fishmongerOverlay.Visible = false
fishmongerOverlay.ZIndex = 95
fishmongerOverlay.Parent = root

local activeFishmongerSort = "Recent"

local fishmongerPanel = Instance.new("Frame")
fishmongerPanel.Name = "FishmongerSellPanel"
fishmongerPanel.AnchorPoint = Vector2.new(0.5, 0.5)
fishmongerPanel.BackgroundColor3 = Color3.fromRGB(17, 24, 34)
fishmongerPanel.Position = UDim2.fromScale(0.5, 0.5)
fishmongerPanel.Size = UDim2.new(0, 460, 0, 460)
fishmongerPanel.ZIndex = 96
fishmongerPanel.Parent = fishmongerOverlay
addCorner(fishmongerPanel, 8)
addStroke(fishmongerPanel, Color3.fromRGB(108, 78, 48), 1)

local fishmongerTitle = makeText(fishmongerPanel, "Sell Fish", 20, Color3.fromRGB(255, 255, 255), true)
fishmongerTitle.Position = UDim2.new(0, 18, 0, 12)
fishmongerTitle.Size = UDim2.new(1, -176, 0, 28)
fishmongerTitle.ZIndex = 97

local fishmongerSellAll = makeButton(fishmongerPanel, "Sell All", Color3.fromRGB(230, 126, 48))
fishmongerSellAll.Position = UDim2.new(1, -146, 0, 12)
fishmongerSellAll.Size = UDim2.new(0, 90, 0, 28)
fishmongerSellAll.TextSize = 13
fishmongerSellAll.ZIndex = 97

local fishmongerClose = makeButton(fishmongerPanel, "X", Color3.fromRGB(91, 104, 124))
fishmongerClose.Position = UDim2.new(1, -48, 0, 12)
fishmongerClose.Size = UDim2.new(0, 32, 0, 28)
fishmongerClose.TextSize = 14
fishmongerClose.ZIndex = 97

local fishmongerSortBar = Instance.new("Frame")
fishmongerSortBar.Name = "FishmongerSortBar"
fishmongerSortBar.Position = UDim2.new(0, 16, 0, 52)
fishmongerSortBar.Size = UDim2.new(1, -32, 0, 34)
fishmongerSortBar.BackgroundTransparency = 1
fishmongerSortBar.ZIndex = 97
fishmongerSortBar.Parent = fishmongerPanel

local fishmongerSortLayout = Instance.new("UIListLayout")
fishmongerSortLayout.FillDirection = Enum.FillDirection.Horizontal
fishmongerSortLayout.Padding = UDim.new(0, 7)
fishmongerSortLayout.SortOrder = Enum.SortOrder.LayoutOrder
fishmongerSortLayout.Parent = fishmongerSortBar

local fishmongerList = Instance.new("ScrollingFrame")
fishmongerList.Name = "FishmongerSellList"
fishmongerList.Active = true
fishmongerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
fishmongerList.BackgroundTransparency = 1
fishmongerList.BorderSizePixel = 0
fishmongerList.CanvasSize = UDim2.new(0, 0, 0, 0)
fishmongerList.Position = UDim2.new(0, 16, 0, 94)
fishmongerList.ScrollBarThickness = 6
fishmongerList.Size = UDim2.new(1, -32, 1, -110)
fishmongerList.ZIndex = 97
fishmongerList.Parent = fishmongerPanel

local fishmongerListLayout = Instance.new("UIListLayout")
fishmongerListLayout.Padding = UDim.new(0, 10)
fishmongerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
fishmongerListLayout.Parent = fishmongerList

local POPUP_SCROLL_GUTTER = 18

local function makePopupListCard(parent, name, height, strokeColor, strokeTransparency)
	local wrapper = Instance.new("Frame")
	wrapper.Name = name .. "Row"
	wrapper.Size = UDim2.new(1, -POPUP_SCROLL_GUTTER, 0, height)
	wrapper.BackgroundTransparency = 1
	wrapper.ZIndex = 97
	wrapper.Parent = parent

	local card = Instance.new("Frame")
	card.Name = name
	card.BackgroundColor3 = Color3.fromRGB(24, 32, 44)
	card.Position = UDim2.new(0, 6, 0, 1)
	card.Size = UDim2.new(1, -12, 1, -2)
	card.ZIndex = 97
	card.Parent = wrapper
	addCorner(card, 8)
	local stroke = addStroke(card, strokeColor or Color3.fromRGB(83, 104, 134), 1)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if strokeTransparency ~= nil then
		stroke.Transparency = strokeTransparency
	end
	return card
end

local function setFishmongerSellVisible(visible)
	fishmongerOverlay.Visible = visible
end

local renderFishmongerSellOptions

local function getFishmongerRarityRank(rarity)
	local ranks = {
		Common = 1,
		Uncommon = 2,
		Rare = 3,
		Epic = 4,
		Legendary = 5,
		Mythic = 6,
	}

	return ranks[rarity] or 0
end

local function renderFishmongerSortButtons()
	clearChildren(fishmongerSortBar)

	local sortOptions = {
		{ mode = "Rarity", label = "Rarity" },
		{ mode = "Value", label = "Value" },
	}

	for _, option in ipairs(sortOptions) do
		local descendingId = option.mode .. "Desc"
		local ascendingId = option.mode .. "Asc"
		local selected = activeFishmongerSort == descendingId or activeFishmongerSort == ascendingId
		local label = option.label
		if selected then
			label = option.label .. (activeFishmongerSort == descendingId and ": High" or ": Low")
		end

		local button = makeButton(fishmongerSortBar, label, selected and Color3.fromRGB(230, 126, 48) or Color3.fromRGB(38, 45, 57))
		button.Size = UDim2.new(0, 132, 1, 0)
		button.TextSize = 13
		button.ZIndex = 98
		button.MouseButton1Click:Connect(function()
			if activeFishmongerSort == descendingId then
				activeFishmongerSort = ascendingId
			else
				activeFishmongerSort = descendingId
			end
			fishmongerList.CanvasPosition = Vector2.new(0, 0)
			renderFishmongerSellOptions()
		end)
	end
end

function renderFishmongerSellOptions()
	renderFishmongerSortButtons()
	clearChildren(fishmongerList)

	if not state then
		fishmongerSellAll.Visible = false
		return
	end

	fishmongerSellAll.Visible = #state.Inventory > 0

	if #state.Inventory == 0 then
		local empty = makeText(fishmongerList, "No fish in your bag.", 16, Color3.fromRGB(190, 204, 220), true)
		empty.Size = UDim2.new(1, -8, 0, 54)
		empty.ZIndex = 98
		return
	end

	local fishEntries = {}
	for index, fish in ipairs(state.Inventory) do
		table.insert(fishEntries, {
			fish = fish,
			index = index,
		})
	end

	table.sort(fishEntries, function(left, right)
		local leftFish = left.fish
		local rightFish = right.fish

		if activeFishmongerSort == "RarityAsc" or activeFishmongerSort == "RarityDesc" then
			local leftRank = getFishmongerRarityRank(leftFish.rarity)
			local rightRank = getFishmongerRarityRank(rightFish.rarity)
			if leftRank ~= rightRank then
				if activeFishmongerSort == "RarityAsc" then
					return leftRank < rightRank
				end
				return leftRank > rightRank
			end
		elseif activeFishmongerSort == "ValueAsc" or activeFishmongerSort == "ValueDesc" then
			local leftValue = tonumber(leftFish.value) or 0
			local rightValue = tonumber(rightFish.value) or 0
			if leftValue ~= rightValue then
				if activeFishmongerSort == "ValueAsc" then
					return leftValue < rightValue
				end
				return leftValue > rightValue
			end
		end

		return left.index > right.index
	end)

	for _, entry in ipairs(fishEntries) do
		local fish = entry.fish
		local index = entry.index
		local color = GameConfig.RarityColors[fish.rarity] or Color3.fromRGB(255, 255, 255)

		local card = makePopupListCard(fishmongerList, "SellOption_" .. tostring(fish.serial or index), 82, color, 0.25)

		local icon = makeFishIcon(card, fish.id, fish.rarity, true)
		icon.Position = UDim2.new(0, 8, 0, 12)
		icon.Size = UDim2.new(0, 58, 0, 58)
		icon.ZIndex = 98

		local name = makeText(card, fish.name .. " [" .. fish.rarity .. "]", 15, color, true)
		name.Position = UDim2.new(0, 76, 0, 10)
		name.Size = UDim2.new(1, -182, 0, 24)
		name.ZIndex = 98

		local info = makeText(card, "Sell value: " .. tostring(fish.value or 0) .. " coins", 13, Color3.fromRGB(190, 204, 220), false)
		info.Position = UDim2.new(0, 76, 0, 40)
		info.Size = UDim2.new(1, -182, 0, 20)
		info.ZIndex = 98

		local sell = makeButton(card, "Sell", Color3.fromRGB(230, 126, 48))
		sell.Position = UDim2.new(1, -92, 0, 23)
		sell.Size = UDim2.new(0, 76, 0, 34)
		sell.TextSize = 13
		sell.ZIndex = 98
		sell.MouseButton1Click:Connect(function()
			SellFish:FireServer("Single", fish.serial, index)
		end)
	end
end

local function openFishmongerSell()
	renderFishmongerSellOptions()
	setFishmongerSellVisible(true)
end

fishmongerClose.MouseButton1Click:Connect(function()
	setFishmongerSellVisible(false)
end)

fishmongerSellAll.MouseButton1Click:Connect(function()
	if state and #state.Inventory > 0 then
		SellFish:FireServer()
	end
end)

if OpenSellFish then
	OpenSellFish.OnClientEvent:Connect(openFishmongerSell)
else
	warn("OpenSellFish remote was not available; fishmonger sell popup is disabled until remotes resync.")
end

local rodShopUI = {}
local activeSupplyShopTab = "Rods"

rodShopUI.overlay = Instance.new("Frame")
rodShopUI.overlay.Name = "RodShopOverlay"
rodShopUI.overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
rodShopUI.overlay.BackgroundTransparency = 0.35
rodShopUI.overlay.Size = UDim2.fromScale(1, 1)
rodShopUI.overlay.Visible = false
rodShopUI.overlay.ZIndex = 95
rodShopUI.overlay.Parent = root

rodShopUI.panel = Instance.new("Frame")
rodShopUI.panel.Name = "RodShopPanel"
rodShopUI.panel.AnchorPoint = Vector2.new(0.5, 0.5)
rodShopUI.panel.BackgroundColor3 = Color3.fromRGB(17, 24, 34)
rodShopUI.panel.Position = UDim2.fromScale(0.5, 0.5)
rodShopUI.panel.Size = UDim2.new(0, 520, 0, 500)
rodShopUI.panel.ZIndex = 96
rodShopUI.panel.Parent = rodShopUI.overlay
addCorner(rodShopUI.panel, 8)
addStroke(rodShopUI.panel, Color3.fromRGB(70, 94, 134), 1)

rodShopUI.title = makeText(rodShopUI.panel, "Supply Shop", 20, Color3.fromRGB(255, 255, 255), true)
rodShopUI.title.Position = UDim2.new(0, 18, 0, 12)
rodShopUI.title.Size = UDim2.new(1, -72, 0, 28)
rodShopUI.title.ZIndex = 97

rodShopUI.close = makeButton(rodShopUI.panel, "X", Color3.fromRGB(91, 104, 124))
rodShopUI.close.Position = UDim2.new(1, -48, 0, 12)
rodShopUI.close.Size = UDim2.new(0, 32, 0, 28)
rodShopUI.close.TextSize = 14
rodShopUI.close.ZIndex = 97

rodShopUI.tabs = Instance.new("Frame")
rodShopUI.tabs.Name = "SupplyShopTabs"
rodShopUI.tabs.Position = UDim2.new(0, 16, 0, 52)
rodShopUI.tabs.Size = UDim2.new(1, -32, 0, 34)
rodShopUI.tabs.BackgroundTransparency = 1
rodShopUI.tabs.ZIndex = 97
rodShopUI.tabs.Parent = rodShopUI.panel

rodShopUI.tabLayout = Instance.new("UIListLayout")
rodShopUI.tabLayout.FillDirection = Enum.FillDirection.Horizontal
rodShopUI.tabLayout.Padding = UDim.new(0, 8)
rodShopUI.tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
rodShopUI.tabLayout.Parent = rodShopUI.tabs

rodShopUI.list = Instance.new("ScrollingFrame")
rodShopUI.list.Name = "RodShopList"
rodShopUI.list.Active = true
rodShopUI.list.AutomaticCanvasSize = Enum.AutomaticSize.Y
rodShopUI.list.BackgroundTransparency = 1
rodShopUI.list.BorderSizePixel = 0
rodShopUI.list.CanvasSize = UDim2.new(0, 0, 0, 0)
rodShopUI.list.Position = UDim2.new(0, 16, 0, 94)
rodShopUI.list.ScrollBarThickness = 6
rodShopUI.list.Size = UDim2.new(1, -32, 1, -110)
rodShopUI.list.ZIndex = 97
rodShopUI.list.Parent = rodShopUI.panel

rodShopUI.layout = Instance.new("UIListLayout")
rodShopUI.layout.Padding = UDim.new(0, 10)
rodShopUI.layout.SortOrder = Enum.SortOrder.LayoutOrder
rodShopUI.layout.Parent = rodShopUI.list

local function setRodShopVisible(visible)
	rodShopUI.overlay.Visible = visible
end

local renderRodShopOptions

local function renderSupplyShopTabs()
	clearChildren(rodShopUI.tabs)

	for _, tabName in ipairs({ "Rods", "Bait" }) do
		local selected = activeSupplyShopTab == tabName
		local button = makeButton(rodShopUI.tabs, tabName, selected and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(38, 45, 57))
		button.Size = UDim2.new(0, 112, 1, 0)
		button.TextSize = 14
		button.ZIndex = 98
		button.MouseButton1Click:Connect(function()
			activeSupplyShopTab = tabName
			rodShopUI.list.CanvasPosition = Vector2.new(0, 0)
			renderRodShopOptions()
		end)
	end
end

local function getRodRequirementText(rod)
	local text = string.format("Cost: %d | Unlock: Level %d | Luck: +%d%%", rod.cost, rod.unlockLevel, math.floor(rod.luck * 100))
	if rod.requiredBiome then
		text ..= " | Requires " .. GameConfig.Biomes[rod.requiredBiome].displayName
	end

	return text
end

function renderRodShopOptions()
	renderSupplyShopTabs()
	clearChildren(rodShopUI.list)

	if not state then
		return
	end

	if activeSupplyShopTab == "Rods" then
		for _, rodId in ipairs(GameConfig.RodOrder) do
		local rod = GameConfig.Rods[rodId]
		local owned = state.OwnedRods[rodId] == true
		local equipped = state.EquippedRod == rodId
		local canAfford = state.Coins >= rod.cost
		local levelOK = state.Level >= rod.unlockLevel
		local biomeOK = not rod.requiredBiome or state.UnlockedBiomes[rod.requiredBiome] == true
		local canUseButton = (owned and not equipped) or (not owned and canAfford and levelOK and biomeOK)

		local card = makePopupListCard(rodShopUI.list, rodId .. "ShopOption", 92, owned and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(83, 104, 134), 0.25)

		local icon = makeRodIcon(card, rodId)
		icon.Position = UDim2.new(0, 8, 0, 14)
		icon.Size = UDim2.new(0, 64, 0, 64)
		icon.ZIndex = 98

		local name = makeText(card, rod.displayName, 16, Color3.fromRGB(255, 255, 255), true)
		name.Position = UDim2.new(0, 84, 0, 10)
		name.Size = UDim2.new(1, -208, 0, 22)
		name.ZIndex = 98

		local info = makeText(card, getRodRequirementText(rod), 13, Color3.fromRGB(190, 204, 220), false)
		info.Position = UDim2.new(0, 84, 0, 36)
		info.Size = UDim2.new(1, -208, 0, 20)
		info.ZIndex = 98

		local statusText = "Improves speed and timing zone."
		if equipped then
			statusText = "Currently equipped."
		elseif owned then
			statusText = "Owned."
		elseif not levelOK then
			statusText = "Reach level " .. tostring(rod.unlockLevel) .. " to buy."
		elseif not canAfford then
			statusText = "Need " .. tostring(rod.cost - state.Coins) .. " more coins."
		elseif not biomeOK then
			statusText = "Unlock " .. GameConfig.Biomes[rod.requiredBiome].displayName .. " first."
		end

		local status = makeText(card, statusText, 12, Color3.fromRGB(143, 160, 180), false)
		status.Position = UDim2.new(0, 84, 0, 62)
		status.Size = UDim2.new(1, -208, 0, 18)
		status.ZIndex = 98

		local label = equipped and "Equipped" or (owned and "Equip" or "Buy")
		local buttonColor = canUseButton and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(86, 98, 115)
		if not owned and canUseButton then
			buttonColor = Color3.fromRGB(28, 160, 92)
		end

		local button = makeButton(card, label, buttonColor)
		button.Position = UDim2.new(1, -110, 0, 28)
		button.Size = UDim2.new(0, 94, 0, 36)
		button.ZIndex = 98
		button.AutoButtonColor = canUseButton
		button.MouseButton1Click:Connect(function()
			if canUseButton then
				BuyRod:FireServer(rodId)
			end
		end)
		end

		return
	end

	for _, baitId in ipairs(GameConfig.BaitOrder) do
		local bait = GameConfig.Baits[baitId]
		local count = getBaitCount(baitId)
		local equipped = state.EquippedBait == baitId
		local isBasic = baitId == GameConfig.BasicBaitId
		local canEquip = isBasic or count > 0
		local canBuy = not isBasic and state.Level >= (bait.unlockLevel or 1) and state.Coins >= (bait.cost or 0)

		local card = makePopupListCard(rodShopUI.list, baitId .. "ShopOption", 104, equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(83, 104, 134), equipped and 0.15 or 0.35)

		local name = makeText(card, bait.displayName, 16, Color3.fromRGB(255, 255, 255), true)
		name.Position = UDim2.new(0, 12, 0, 8)
		name.Size = UDim2.new(1, -222, 0, 22)
		name.ZIndex = 98

		local effect = makeText(card, getBaitEffectText(bait), 12, Color3.fromRGB(190, 204, 220), false)
		effect.Position = UDim2.new(0, 12, 0, 34)
		effect.Size = UDim2.new(1, -222, 0, 34)
		effect.TextWrapped = true
		effect.ZIndex = 98

		local countText = getBaitCountText(baitId, count)
		if not isBasic then
			countText ..= string.format(" | %d coins / %d | Lv %d", bait.cost or 0, bait.purchaseAmount or 1, bait.unlockLevel or 1)
		end
		local detail = makeText(card, countText, 12, equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(143, 160, 180), false)
		detail.Position = UDim2.new(0, 12, 0, 72)
		detail.Size = UDim2.new(1, -222, 0, 18)
		detail.ZIndex = 98

		if not isBasic then
			local buy = makeButton(card, "Buy +" .. tostring(bait.purchaseAmount or 1), canBuy and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(86, 98, 115))
			buy.Position = UDim2.new(1, -194, 0, 35)
			buy.Size = UDim2.new(0, 84, 0, 34)
			buy.TextSize = 12
			buy.ZIndex = 98
			buy.AutoButtonColor = canBuy
			buy.MouseButton1Click:Connect(function()
				fireBaitAction("Buy", baitId)
			end)
		end

		local equip = makeButton(card, equipped and "Equipped" or "Equip", equipped and Color3.fromRGB(91, 104, 124) or (canEquip and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(86, 98, 115)))
		equip.Position = UDim2.new(1, -102, 0, 35)
		equip.Size = UDim2.new(0, 86, 0, 34)
		equip.TextSize = 12
		equip.ZIndex = 98
		equip.AutoButtonColor = canEquip and not equipped
		equip.MouseButton1Click:Connect(function()
			if not equipped then
				fireBaitAction("Equip", baitId)
			end
		end)
	end
end

rodShopUI.close.MouseButton1Click:Connect(function()
	setRodShopVisible(false)
end)

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

local centerBaitText = makeText(centerControls, "Bait: Basic Bait (Unlimited)", 13, Color3.fromRGB(210, 230, 255), true)
centerBaitText.Position = UDim2.new(0, 42, 0, 8)
centerBaitText.Size = UDim2.new(1, -84, 0, 18)
centerBaitText.TextXAlignment = Enum.TextXAlignment.Center
centerBaitText.ZIndex = 24

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

local panelToggle = makeButton(root, ">", Color3.fromRGB(38, 45, 57))
panelToggle.Name = "PanelToggle"
panelToggle.AnchorPoint = Vector2.new(1, 0.5)
panelToggle.Position = UDim2.new(1, -456, 0.42, 0)
panelToggle.Size = UDim2.new(0, 34, 0, 64)
panelToggle.ZIndex = 30
panelToggle.TextSize = 18

local function updatePanelCollapsed()
	if panelCollapsed then
		panel.Position = UDim2.new(1, 430, 0.42, 0)
		panelToggle.Position = UDim2.new(1, -10, 0.42, 0)
		panelToggle.Text = "<"
	else
		panel.Position = UDim2.new(1, -18, 0.42, 0)
		panelToggle.Position = UDim2.new(1, -456, 0.42, 0)
		panelToggle.Text = ">"
	end
end

panelToggle.MouseButton1Click:Connect(function()
	panelCollapsed = not panelCollapsed
	updatePanelCollapsed()
end)

updatePanelCollapsed()

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
minigame.Name = "FishingMinigame"
minigame.AnchorPoint = Vector2.new(0.5, 0.5)
minigame.Position = UDim2.new(0.5, 0, 0.48, 0)
minigame.Size = UDim2.new(0, 540, 0, 520)
minigame.BackgroundColor3 = Color3.fromRGB(10, 68, 155)
minigame.Visible = false
minigame.ZIndex = 40
minigame.Parent = root
addCorner(minigame, 30)
addStroke(minigame, Color3.fromRGB(0, 78, 190), 7)
addStroke(minigame, Color3.fromRGB(99, 210, 255), 2).Transparency = 0.08
addGradient(minigame, Color3.fromRGB(18, 92, 198), Color3.fromRGB(7, 52, 132), 90)

local minigameConstraint = Instance.new("UISizeConstraint")
minigameConstraint.MinSize = Vector2.new(500, 450)
minigameConstraint.MaxSize = Vector2.new(620, 560)
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
timingBar.Visible = false
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
zone.Visible = false
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
marker.Visible = false
addCorner(marker, 9)
addStroke(marker, Color3.fromRGB(7, 55, 128), 3)

local catchButton = makeButton(minigame, "", Color3.fromRGB(28, 160, 92))
catchButton.AnchorPoint = Vector2.new(0.5, 1)
catchButton.Position = UDim2.new(0.5, 0, 1, -18)
catchButton.Size = UDim2.new(0.29, 0, 0, 52)
catchButton.ZIndex = 44
catchButton.Visible = false
catchButton.Active = false
catchButton.AutoButtonColor = false
styleOutlinedText(catchButton, 34)
catchButton.TextScaled = true
limitTextSize(catchButton, 15, 24)
forcePureWhiteText(catchButton)
setCornerRadius(catchButton, 24)
addStroke(catchButton, Color3.fromRGB(0, 92, 18), 7)
addGradient(catchButton, Color3.fromRGB(104, 255, 91), Color3.fromRGB(17, 196, 38), 90)
addGloss(catchButton, UDim2.new(0, 22, 0, 13), UDim2.new(0, 90, 0, 12))

local fishingGameContent = Instance.new("Frame")
fishingGameContent.Name = "FishingGameContent"
fishingGameContent.Position = UDim2.new(0, 34, 0, 82)
fishingGameContent.Size = UDim2.new(1, -68, 1, -106)
fishingGameContent.BackgroundTransparency = 1
fishingGameContent.ZIndex = 44
fishingGameContent.Parent = minigame

local verticalPanel = Instance.new("Frame")
verticalPanel.Name = "VerticalFishingPanel"
verticalPanel.Position = UDim2.new(0, 18, 0, 0)
verticalPanel.Size = UDim2.new(0, 180, 1, -58)
verticalPanel.BackgroundColor3 = Color3.fromRGB(31, 95, 156)
verticalPanel.ZIndex = 45
verticalPanel.Parent = fishingGameContent
addCorner(verticalPanel, 20)
addStroke(verticalPanel, Color3.fromRGB(7, 48, 106), 5)
addStroke(verticalPanel, Color3.fromRGB(126, 219, 255), 2).Transparency = 0.18
addGradient(verticalPanel, Color3.fromRGB(55, 154, 210), Color3.fromRGB(18, 71, 140), 90)

local panelWater = Instance.new("Frame")
panelWater.Name = "Water"
panelWater.Position = UDim2.new(0, 14, 0, 14)
panelWater.Size = UDim2.new(1, -28, 1, -28)
panelWater.BackgroundColor3 = Color3.fromRGB(28, 135, 204)
panelWater.ZIndex = 46
panelWater.Parent = verticalPanel
addCorner(panelWater, 16)
addStroke(panelWater, Color3.fromRGB(12, 68, 128), 2).Transparency = 0.2
addGradient(panelWater, Color3.fromRGB(70, 190, 230), Color3.fromRGB(17, 98, 177), 90)

local catchBar = Instance.new("Frame")
catchBar.Name = "CatchBar"
catchBar.AnchorPoint = Vector2.new(0.5, 0)
catchBar.Position = UDim2.new(0.5, 0, 0.68, 0)
catchBar.Size = UDim2.new(1, -32, 0.24, 0)
catchBar.BackgroundColor3 = Color3.fromRGB(43, 225, 70)
catchBar.ZIndex = 48
catchBar.Parent = panelWater
addCorner(catchBar, 14)
addStroke(catchBar, Color3.fromRGB(8, 94, 24), 3)
addGradient(catchBar, Color3.fromRGB(111, 255, 94), Color3.fromRGB(20, 177, 46), 90)
addGloss(catchBar, UDim2.new(0, 12, 0, 7), UDim2.new(0, 54, 0, 8))

local fishMarker = Instance.new("Frame")
fishMarker.Name = "FishMarker"
fishMarker.AnchorPoint = Vector2.new(0.5, 0.5)
fishMarker.Position = UDim2.new(0.5, 0, 0.5, 0)
fishMarker.Size = UDim2.new(0, 46, 0, 46)
fishMarker.BackgroundColor3 = Color3.fromRGB(17, 28, 43)
fishMarker.ZIndex = 50
fishMarker.Parent = panelWater
addCorner(fishMarker, 23)
addStroke(fishMarker, Color3.fromRGB(255, 255, 255), 2).Transparency = 0.08

local fishMarkerImage = Instance.new("ImageLabel")
fishMarkerImage.Name = "FishImage"
fishMarkerImage.BackgroundTransparency = 1
fishMarkerImage.Position = UDim2.new(0, 5, 0, 5)
fishMarkerImage.Size = UDim2.new(1, -10, 1, -10)
fishMarkerImage.ScaleType = Enum.ScaleType.Fit
fishMarkerImage.ZIndex = 51
fishMarkerImage.Parent = fishMarker

local fishMarkerLabel = makeText(fishMarker, "FISH", 11, Color3.fromRGB(255, 255, 255), true)
fishMarkerLabel.Position = UDim2.fromScale(0, 0)
fishMarkerLabel.Size = UDim2.fromScale(1, 1)
fishMarkerLabel.TextXAlignment = Enum.TextXAlignment.Center
fishMarkerLabel.ZIndex = 52
styleOutlinedText(fishMarkerLabel, 11)
forcePureWhiteText(fishMarkerLabel)

local progressTrack = Instance.new("Frame")
progressTrack.Name = "ProgressTrack"
progressTrack.Position = UDim2.new(0, 226, 0, 0)
progressTrack.Size = UDim2.new(0, 42, 1, -58)
progressTrack.BackgroundColor3 = Color3.fromRGB(29, 35, 46)
progressTrack.ZIndex = 45
progressTrack.Parent = fishingGameContent
addCorner(progressTrack, 16)
addStroke(progressTrack, Color3.fromRGB(92, 111, 138), 2)

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.AnchorPoint = Vector2.new(0, 1)
progressFill.Position = UDim2.new(0, 0, 1, 0)
progressFill.Size = UDim2.new(1, 0, 0.34, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(62, 190, 255)
progressFill.ZIndex = 46
progressFill.Parent = progressTrack
addCorner(progressFill, 16)
addGradient(progressFill, Color3.fromRGB(130, 235, 255), Color3.fromRGB(26, 132, 255), 90)

local minigameFishInfo = makeText(fishingGameContent, "Fish", 18, Color3.fromRGB(255, 255, 255), true)
minigameFishInfo.Position = UDim2.new(0, 296, 0, 18)
minigameFishInfo.Size = UDim2.new(1, -306, 0, 46)
minigameFishInfo.ZIndex = 45
minigameFishInfo.TextWrapped = true
styleOutlinedText(minigameFishInfo, 18)
forcePureWhiteText(minigameFishInfo)

local minigameProgressText = makeText(fishingGameContent, "Progress 34%", 15, Color3.fromRGB(210, 230, 255), true)
minigameProgressText.Position = UDim2.new(0, 296, 0, 76)
minigameProgressText.Size = UDim2.new(1, -306, 0, 30)
minigameProgressText.ZIndex = 45

local minigameInstruction = makeText(fishingGameContent, "Hold mouse, tap, or Space to lift the green bar.", 14, Color3.fromRGB(210, 230, 255), false)
minigameInstruction.Position = UDim2.new(0, 296, 0, 116)
minigameInstruction.Size = UDim2.new(1, -306, 0, 70)
minigameInstruction.TextWrapped = true
minigameInstruction.ZIndex = 45

local CastPower = {
	running = false,
}

CastPower.content = Instance.new("Frame")
CastPower.content.Name = "CastPowerContent"
CastPower.content.Position = UDim2.new(0, 40, 0, 92)
CastPower.content.Size = UDim2.new(1, -80, 1, -126)
CastPower.content.BackgroundTransparency = 1
CastPower.content.Visible = false
CastPower.content.ZIndex = 44
CastPower.content.Parent = minigame

CastPower.title = makeText(CastPower.content, "Hold to charge. Release to cast.", 18, Color3.fromRGB(255, 255, 255), true)
CastPower.title.Position = UDim2.new(0, 0, 0, 8)
CastPower.title.Size = UDim2.new(1, 0, 0, 36)
CastPower.title.TextXAlignment = Enum.TextXAlignment.Center
CastPower.title.TextScaled = true
CastPower.title.ZIndex = 45
styleOutlinedText(CastPower.title, 20)
forcePureWhiteText(CastPower.title)
limitTextSize(CastPower.title, 16, 22)

CastPower.track = Instance.new("Frame")
CastPower.track.Name = "CastPowerTrack"
CastPower.track.Position = UDim2.new(0, 14, 0, 96)
CastPower.track.Size = UDim2.new(1, -28, 0, 58)
CastPower.track.BackgroundColor3 = Color3.fromRGB(27, 73, 132)
CastPower.track.ZIndex = 45
CastPower.track.Parent = CastPower.content
addCorner(CastPower.track, 22)
addStroke(CastPower.track, Color3.fromRGB(7, 48, 106), 5)
addStroke(CastPower.track, Color3.fromRGB(126, 219, 255), 2).Transparency = 0.18
addGradient(CastPower.track, Color3.fromRGB(62, 153, 213), Color3.fromRGB(16, 69, 137), 90)

CastPower.perfectZone = Instance.new("Frame")
CastPower.perfectZone.Name = "PerfectTimingZone"
CastPower.perfectZone.BackgroundColor3 = Color3.fromRGB(61, 255, 132)
CastPower.perfectZone.BackgroundTransparency = 0.12
CastPower.perfectZone.Position = UDim2.new(0.675, 0, 0, 0)
CastPower.perfectZone.Size = UDim2.new(0.09, 0, 1, 0)
CastPower.perfectZone.ZIndex = 46
CastPower.perfectZone.Parent = CastPower.track
addCorner(CastPower.perfectZone, 18)
addStroke(CastPower.perfectZone, Color3.fromRGB(10, 120, 42), 3).Transparency = 0.1
addGradient(CastPower.perfectZone, Color3.fromRGB(117, 255, 129), Color3.fromRGB(23, 190, 72), 90)

CastPower.fill = Instance.new("Frame")
CastPower.fill.Name = "PowerFill"
CastPower.fill.BackgroundColor3 = Color3.fromRGB(255, 204, 65)
CastPower.fill.Size = UDim2.new(0, 0, 1, 0)
CastPower.fill.ZIndex = 47
CastPower.fill.Parent = CastPower.track
addCorner(CastPower.fill, 18)
addGradient(CastPower.fill, Color3.fromRGB(255, 235, 121), Color3.fromRGB(255, 126, 40), 90)

CastPower.marker = Instance.new("Frame")
CastPower.marker.Name = "BobberMarker"
CastPower.marker.AnchorPoint = Vector2.new(0.5, 0.5)
CastPower.marker.Position = UDim2.new(0, 0, 0.5, 0)
CastPower.marker.Size = UDim2.new(0, 18, 1, 28)
CastPower.marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CastPower.marker.ZIndex = 49
CastPower.marker.Parent = CastPower.track
addCorner(CastPower.marker, 9)
addStroke(CastPower.marker, Color3.fromRGB(7, 55, 128), 3)

CastPower.value = makeText(CastPower.content, "Power 0%", 16, Color3.fromRGB(255, 255, 255), true)
CastPower.value.Position = UDim2.new(0, 0, 0, 168)
CastPower.value.Size = UDim2.new(1, 0, 0, 30)
CastPower.value.TextXAlignment = Enum.TextXAlignment.Center
CastPower.value.ZIndex = 45
forcePureWhiteText(CastPower.value)

CastPower.status = makeText(CastPower.content, "Release in the green zone for a Perfect cast.", 15, Color3.fromRGB(218, 239, 255), false)
CastPower.status.Position = UDim2.new(0, 0, 0, 206)
CastPower.status.Size = UDim2.new(1, 0, 0, 46)
CastPower.status.TextXAlignment = Enum.TextXAlignment.Center
CastPower.status.TextWrapped = true
CastPower.status.ZIndex = 45

CastPower.hint = makeText(CastPower.content, "Mouse, tap, or Space", 14, Color3.fromRGB(184, 219, 255), false)
CastPower.hint.Position = UDim2.new(0, 0, 1, -64)
CastPower.hint.Size = UDim2.new(1, 0, 0, 28)
CastPower.hint.TextXAlignment = Enum.TextXAlignment.Center
CastPower.hint.ZIndex = 45
local showToast
CastPower.activeConfig = nil

function CastPower.getConfig()
	return CastPower.activeConfig or GameConfig.Casting or {}
end

function CastPower.ease(value)
	local clamped = math.clamp(tonumber(value) or 0, 0, 1)
	return clamped * clamped * (3 - (2 * clamped))
end

function CastPower.requestConfig(biomeId)
	if not GetCastConfig then
		GetCastConfig = Remotes:FindFirstChild("GetCastConfig")
	end

	if not GetCastConfig then
		showToast("Cast meter is still syncing. Try again.")
		return nil
	end

	local success, response = pcall(function()
		return GetCastConfig:InvokeServer(biomeId)
	end)

	if not success or type(response) ~= "table" or response.ok ~= true then
		showToast((type(response) == "table" and response.message) or "Could not start casting.")
		return nil
	end

	return response
end

function CastPower.getPerfectTiming()
	local config = CastPower.getConfig()
	local targetPower = math.clamp(tonumber(config.perfectCenter) or 0.72, 0, 1)
	local tolerance = math.clamp(tonumber(config.perfectRadius) or 0.045, 0.01, 0.35)
	return targetPower, tolerance
end

function CastPower.getLocalRating(power)
	local config = CastPower.getConfig()
	local casting = GameConfig.Casting or {}
	local targetPower = math.clamp(tonumber(config.perfectCenter) or 0.72, 0, 1)
	local perfectRadius = math.clamp(tonumber(config.perfectRadius) or 0.045, 0.01, 0.5)
	local greatRadius = math.clamp(tonumber(config.greatRadius) or tonumber(casting.greatRadius) or 0.11, perfectRadius, 0.5)
	local goodRadius = math.clamp(tonumber(config.goodRadius) or tonumber(casting.goodRadius) or 0.24, greatRadius, 0.5)
	local accuracy = math.abs(math.clamp(tonumber(power) or 0, 0, 1) - targetPower)
	local rating = "Weak"

	if accuracy <= perfectRadius then
		rating = "Perfect"
	elseif accuracy <= greatRadius then
		rating = "Great"
	elseif accuracy <= goodRadius then
		rating = "Good"
	end

	local ratingConfig = casting.Ratings and casting.Ratings[rating]
	return rating, (ratingConfig and ratingConfig.displayName) or rating
end

function CastPower.updateVisual(power)
	local clampedPower = math.clamp(tonumber(power) or 0, 0, 1)
	CastPower.fill.Size = UDim2.new(clampedPower, 0, 1, 0)
	CastPower.marker.Position = UDim2.new(clampedPower, 0, 0.5, 0)
	CastPower.value.Text = string.format("Power %d%%", math.floor(clampedPower * 100 + 0.5))

	local targetPower, tolerance = CastPower.getPerfectTiming()
	local left = math.clamp(targetPower - tolerance, 0, 1)
	local right = math.clamp(targetPower + tolerance, 0, 1)
	CastPower.perfectZone.Visible = true
	CastPower.perfectZone.Position = UDim2.new(left, 0, 0, 0)
	CastPower.perfectZone.Size = UDim2.new(math.max(0.04, right - left), 0, 1, 0)

	local rating = CastPower.getLocalRating(clampedPower)
	if rating == "Perfect" then
		CastPower.status.Text = "Release now for Perfect!"
	elseif rating == "Great" then
		CastPower.status.Text = "Great timing. Nudge closer for Perfect."
	else
		CastPower.status.Text = "Aim for the green perfect zone."
	end
end

function CastPower.showSparkle()
	for index = 1, 5 do
		local sparkle = Instance.new("Frame")
		sparkle.Name = "PerfectCastSparkle"
		sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
		sparkle.BackgroundColor3 = index % 2 == 0 and Color3.fromRGB(255, 245, 156) or Color3.fromRGB(255, 255, 255)
		sparkle.BorderSizePixel = 0
		sparkle.Position = UDim2.new(0.34 + (index * 0.06), 0, 0.42 + ((index % 2) * 0.12), 0)
		sparkle.Size = UDim2.new(0, 10, 0, 10)
		sparkle.ZIndex = 60
		sparkle.Parent = CastPower.content
		addCorner(sparkle, 10)
		task.delay(0.5 + (index * 0.04), function()
			if sparkle.Parent then
				sparkle:Destroy()
			end
		end)
	end
end

local function setMinigameFishIcon(fish)
	local fishId = fish and (fish.imageKey or fish.id)
	local imageId = fishId and GameConfig.getFishImage(fishId)

	if imageId then
		fishMarkerImage.Image = imageId
		fishMarkerImage.Visible = true
		fishMarkerLabel.Visible = false
	else
		fishMarkerImage.Image = ""
		fishMarkerImage.Visible = false
		fishMarkerLabel.Visible = true
	end
end

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

function showToast(message)
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
	local wrapper = Instance.new("Frame")
	wrapper.Name = "CardRow"
	wrapper.Size = UDim2.new(1, 0, 0, height)
	wrapper.BackgroundTransparency = 1
	wrapper.Parent = parent

	local card = Instance.new("Frame")
	card.Position = UDim2.new(0, 6, 0, 1)
	card.Size = UDim2.new(1, -12, 1, -2)
	card.BackgroundColor3 = Color3.fromRGB(27, 33, 43)
	card.Parent = wrapper
	addCorner(card, 8)
	local stroke = addStroke(card, Color3.fromRGB(60, 72, 90), 1)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return card
end

local function attachNotificationBadge(parent, count)
	count = math.max(0, math.floor(tonumber(count) or 0))
	local badge = Instance.new("Frame")
	badge.Name = "NotificationBadge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 4, 0, -6)
	badge.Size = UDim2.new(0, count >= 10 and 26 or 20, 0, 20)
	badge.BackgroundColor3 = Color3.fromRGB(226, 50, 50)
	badge.BorderSizePixel = 0
	badge.Visible = count > 0
	badge.ZIndex = (parent.ZIndex or 1) + 5
	badge.Parent = parent
	addCorner(badge, 10)
	addStroke(badge, Color3.fromRGB(255, 232, 232), 1).Transparency = 0.1

	local label = makeText(badge, count > 99 and "99+" or tostring(count), 11, Color3.fromRGB(255, 255, 255), true)
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = badge.ZIndex + 1
	return badge
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

local function isBeginnerPondInstance(instance)
	while instance do
		if instance.Name == "BeginnerPond_ExtraLarge" or instance.Name == "Beginner Pond" then
			return true
		end
		instance = instance.Parent
	end

	return false
end

local function getGroundBiomeId(position, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = character and { character } or {}

	local result = workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -90, 0), params)
	if result and isBeginnerPondInstance(result.Instance) then
		return "BeginnerPond"
	end

	return nil
end

local function getLocalFishingBiomeId()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end

	local groundBiomeId = getGroundBiomeId(rootPart.Position, character)
	if groundBiomeId then
		return groundBiomeId
	end

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		if biomeId == "BeginnerPond" then
			continue
		end

		local biome = GameConfig.Biomes[biomeId]
		local center = biome.position
		local dx = math.abs(rootPart.Position.X - center.X)
		local dz = math.abs(rootPart.Position.Z - center.Z)
		local rangeX = 58
		local rangeZ = 54

		if dx <= rangeX and dz <= rangeZ then
			return biomeId
		end
	end

	return nil
end

local function getActiveFishingBiomeId()
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		return getLocalFishingBiomeId()
	end

	local localBiomeId = getLocalFishingBiomeId()
	if localBiomeId then
		return localBiomeId
	end

	if not state or not state.ActualBiome or not GameConfig.Biomes[state.ActualBiome] then
		return nil
	end

	return state.ActualBiome
end

local function getLocalTravelLocation()
	local localBiomeId = getLocalFishingBiomeId()
	if localBiomeId then
		return localBiomeId
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local lobby = GameConfig.Lobby
	local bounds = lobby and lobby.bounds
	if rootPart and bounds then
		local position = rootPart.Position
		if position.X >= bounds.minX
			and position.X <= bounds.maxX
			and position.Z >= bounds.minZ
			and position.Z <= bounds.maxZ
		then
			return "Lobby"
		end
	end

	return (state and state.ActualLocation) or "Lobby"
end

function CastPower.isInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space
end

function CastPower.run(biomeId)
	if CastPower.running then
		return
	end

	local biome = GameConfig.Biomes[biomeId]
	local castConfig = CastPower.requestConfig(biomeId)
	if not castConfig then
		return false
	end

	CastPower.activeConfig = castConfig
	local meterSpeed = tonumber(castConfig.meterSpeed) or tonumber((GameConfig.Casting or {}).chargeSpeed) or 1.05
	local progress = math.clamp(tonumber(castConfig.startProgress) or 0, 0, 1)
	local power = CastPower.ease(progress)
	local direction = tonumber(castConfig.direction) == -1 and -1 or 1
	local holding = false
	local hasHeld = false
	local finished = false
	local renderConnection
	local inputBeganConnection
	local inputEndedConnection

	CastPower.running = true
	setMinigameVisible(true)
	CastPower.content.Visible = true
	CastPower.title.Text = "Hold to charge. Release to cast."
	CastPower.status.Text = "Release in the green zone for a Perfect cast."
	CastPower.hint.Text = string.format("Left start - %s speed", castConfig.speedName or "Random")
	fishingGameContent.Visible = false
	catchButton.Visible = false
	timingBar.Visible = false
	zone.Visible = false
	marker.Visible = false

	minigameText.Text = "Cast into " .. ((biome and biome.displayName) or "the water")
	forcePureWhiteText(minigameText)
	forcePureWhiteText(catchButton)
	CastPower.updateVisual(power)

	local function disconnectAll()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		if inputBeganConnection then
			inputBeganConnection:Disconnect()
			inputBeganConnection = nil
		end
		if inputEndedConnection then
			inputEndedConnection:Disconnect()
			inputEndedConnection = nil
		end
	end

	activeMinigameCleanup = function()
		finished = true
		disconnectAll()
		activeMinigameCleanup = nil
		CastPower.running = false
		CastPower.activeConfig = nil
		CastPower.content.Visible = false
	end

	local function finishCast()
		if finished then
			return
		end

		finished = true
		disconnectAll()
		activeMinigameCleanup = nil
		CastPower.running = false
		fishingGameContent.Visible = false
		local rating, displayName = CastPower.getLocalRating(power)
		CastPower.title.Text = displayName .. " Cast!"
		CastPower.status.Text = "Bobber landed. Waiting for a bite..."
		minigameText.Text = displayName .. " Cast! Waiting for a bite..."
		forcePureWhiteText(minigameText)
		if rating == "Perfect" then
			CastPower.showSparkle()
		end
		task.delay(0.45, function()
			if not CastPower.running and not minigameRunning then
				CastPower.content.Visible = false
			end
		end)

		StartFishing:FireServer({
			biomeId = biomeId,
			castPower = math.clamp(power, 0, 1),
			castAttemptId = castConfig.attemptId,
		})
		renderContent()
	end

	inputBeganConnection = UserInputService.InputBegan:Connect(function(input)
		if CastPower.isInput(input) then
			holding = true
			hasHeld = true
		end
	end)

	inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
		if CastPower.isInput(input) and hasHeld then
			holding = false
			finishCast()
		end
	end)

	renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if finished or not CastPower.running then
			return
		end

		if holding then
			progress += direction * meterSpeed * deltaTime

			if progress >= 1 then
				progress = 1
				direction = -1
			elseif progress <= 0 then
				progress = 0
				direction = 1
			end

			power = CastPower.ease(progress)
			CastPower.updateVisual(power)
		end
	end)

	return true
end

function startManualFishing()
	if fishingBusy or not state then
		return
	end

	local biomeId = getActiveFishingBiomeId()
	if not biomeId then
		showToast("Move to a fishing area first.")
		return
	end

	local biome = GameConfig.Biomes[biomeId]
	fishingBusy = true
	showToast("Casting in " .. biome.displayName .. "...")
	if not CastPower.run(biomeId) then
		fishingBusy = false
	end
	renderContent()
end

local function refreshCenterControls()
	local biomeId = getActiveFishingBiomeId()

	if not state or not biomeId then
		centerControls.Visible = false
		centerTitle.Text = "Beginner Pond"
		centerTitle.Visible = false
		centerCastButton.Text = "Cast Rod"
		centerAutoButton.Text = "AutoFish: OFF"
		centerBaitText.Text = "Bait: Basic Bait (Unlimited)"
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

	centerControls.Visible = true
	local biome = GameConfig.Biomes[biomeId]
	centerTitle.Text = biome.displayName
	centerTitle.Visible = false
	centerCastButton.Text = fishingBusy and "Fishing..." or "Cast Rod"
	centerAutoButton.Text = state.AutoFishEnabled and "AutoFish: ON" or "AutoFish: OFF"
	centerBaitText.Text = getEquippedBaitDisplay()
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
	if not getActiveFishingBiomeId() then
		showToast("Move to a fishing area first.")
		return
	end

	ToggleAutoFish:FireServer()
end)

local function setTab(tabName)
	activeTab = tabName
	renderContent()
end

local connectedAquariumViewerTools = {}

local function openAquariumViewer()
	panelCollapsed = false
	updatePanelCollapsed()
	setTab("Aquarium")
end

local function connectAquariumViewerTool(tool)
	if not tool:IsA("Tool") or tool.Name ~= "Aquarium Viewer" then
		return
	end

	if connectedAquariumViewerTools[tool] then
		return
	end

	connectedAquariumViewerTools[tool] = true
	tool.Equipped:Connect(openAquariumViewer)
	tool.Activated:Connect(openAquariumViewer)
	tool.Destroying:Connect(function()
		connectedAquariumViewerTools[tool] = nil
	end)
end

local function watchAquariumViewerTools(container)
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		connectAquariumViewerTool(child)
	end

	container.ChildAdded:Connect(connectAquariumViewerTool)
end

task.spawn(function()
	local backpack = player:WaitForChild("Backpack", 10)
	if backpack then
		watchAquariumViewerTools(backpack)
	end
end)

if player.Character then
	task.defer(watchAquariumViewerTools, player.Character)
end

player.CharacterAdded:Connect(function(character)
	task.defer(watchAquariumViewerTools, character)
end)

local function refreshLeaderboardTabIfOpen()
	if activeTab == "Leaderboard" then
		renderContent()
	end
end

Players.PlayerAdded:Connect(refreshLeaderboardTabIfOpen)
Players.PlayerRemoving:Connect(refreshLeaderboardTabIfOpen)

local function openRodShop()
	renderRodShopOptions()
	setRodShopVisible(true)
end

if OpenRodShop then
	OpenRodShop.OnClientEvent:Connect(openRodShop)
else
	warn("OpenRodShop remote was not available; rod shop prompt is disabled until remotes resync.")
end

local function refreshTabs()
	clearChildren(tabs)

	local tabNames = { "Fishdex", "Bag", "Aquarium", "Teleport", "Quests", "Shop", "Leaderboard" }
	for _, tabName in ipairs(tabNames) do
		local color = activeTab == tabName and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(38, 45, 57)
		local button = makeButton(tabs, tabName, color)
		if tabName == "Quests" then
			attachNotificationBadge(button, state and state.QuestUnclaimedCount or 0)
		end
		button.MouseButton1Click:Connect(function()
			setTab(tabName)
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
	heading.Size = UDim2.new(1, -24, 0, 24)

	local detail = makeText(top, string.format("%d/%d fish | %d rods | Total value: %d coins", #state.Inventory, state.BackpackSize, ownedRodCount, value), 14, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 12, 0, 38)
	detail.Size = UDim2.new(1, -24, 0, 22)

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

	local baitsHeader = makeText(content, "Bait", 16, Color3.fromRGB(255, 255, 255), true)
	baitsHeader.Size = UDim2.new(1, -8, 0, 28)

	for _, baitId in ipairs(GameConfig.BaitOrder) do
		local bait = GameConfig.Baits[baitId]
		local count = getBaitCount(baitId)
		local equipped = state.EquippedBait == baitId
		local isBasic = baitId == GameConfig.BasicBaitId
		local canEquip = isBasic or count > 0
		local canBuy = not isBasic and state.Level >= (bait.unlockLevel or 1) and state.Coins >= (bait.cost or 0)

		local card = makeCard(content, 104)
		addStroke(card, equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(60, 72, 90), 1).Transparency = equipped and 0.15 or 0.45

		local name = makeText(card, bait.displayName, 15, Color3.fromRGB(255, 255, 255), true)
		name.Position = UDim2.new(0, 12, 0, 6)
		name.Size = UDim2.new(1, -222, 0, 22)

		local effect = makeText(card, getBaitEffectText(bait), 12, Color3.fromRGB(190, 204, 220), false)
		effect.Position = UDim2.new(0, 12, 0, 30)
		effect.Size = UDim2.new(1, -222, 0, 34)
		effect.TextWrapped = true

		local countText = getBaitCountText(baitId, count)
		if not isBasic then
			countText ..= string.format(" | %d coins / %d | Lv %d", bait.cost or 0, bait.purchaseAmount or 1, bait.unlockLevel or 1)
		end
		local detail = makeText(card, countText, 12, equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(143, 160, 180), false)
		detail.Position = UDim2.new(0, 12, 0, 68)
		detail.Size = UDim2.new(1, -222, 0, 18)

		if not isBasic then
			local buy = makeButton(card, "Buy +" .. tostring(bait.purchaseAmount or 1), canBuy and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(86, 98, 115))
			buy.Position = UDim2.new(1, -194, 0, 35)
			buy.Size = UDim2.new(0, 84, 0, 34)
			buy.TextSize = 12
			buy.AutoButtonColor = canBuy
			buy.MouseButton1Click:Connect(function()
				fireBaitAction("Buy", baitId)
			end)
		end

		local equip = makeButton(card, equipped and "Equipped" or "Equip", equipped and Color3.fromRGB(91, 104, 124) or (canEquip and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(86, 98, 115)))
		equip.Position = UDim2.new(1, -102, 0, 35)
		equip.Size = UDim2.new(0, 86, 0, 34)
		equip.TextSize = 12
		equip.AutoButtonColor = canEquip and not equipped
		equip.MouseButton1Click:Connect(function()
			if not equipped then
				fireBaitAction("Equip", baitId)
			end
		end)
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
		display.Position = UDim2.new(1, -110, 0, 24)
		display.Size = UDim2.new(0, 94, 0, 36)
		display.TextSize = 12
		display.MouseButton1Click:Connect(function()
			AquariumAction:FireServer("DisplayFish", fish.serial, index)
		end)
	end
end

local function renderFishdexTab()
	local biomeId = getActiveFishingBiomeId()
	local biome = biomeId and GameConfig.Biomes[biomeId]
	local summary = makeCard(content, biome and 112 or 82)

	local titleLabel = makeText(summary, "Fishdex Collection: " .. getDiscoveredCount() .. "/" .. GameConfig.getFishCount(), 17, Color3.fromRGB(255, 255, 255), true)
	titleLabel.Position = UDim2.new(0, 12, 0, 8)
	titleLabel.Size = UDim2.new(1, -24, 0, 24)

	if biome then
		local rod = state and GameConfig.Rods[state.EquippedRod] or GameConfig.Rods.WoodenRod
		local autoStatus = state.AutoFishEnabled and "ON" or "OFF"

		local location = makeText(summary, "Current Biome: " .. biome.displayName, 14, biome.color, true)
		location.Position = UDim2.new(0, 12, 0, 36)
		location.Size = UDim2.new(1, -24, 0, 20)

		local detail = makeText(summary, "Rod: " .. rod.displayName .. " | Luck: +" .. math.floor(rod.luck * 100) .. "% | AutoFish: " .. autoStatus, 13, Color3.fromRGB(190, 204, 220), false)
		detail.Position = UDim2.new(0, 12, 0, 60)
		detail.Size = UDim2.new(1, -24, 0, 18)

		local species = makeText(summary, "Species in this biome: " .. #biome.fish, 12, Color3.fromRGB(143, 160, 180), false)
		species.Position = UDim2.new(0, 12, 0, 82)
		species.Size = UDim2.new(1, -24, 0, 18)
	else
		local detail = makeText(summary, "Enter a fishing biome to see your active area here.", 13, Color3.fromRGB(190, 204, 220), false)
		detail.Position = UDim2.new(0, 12, 0, 38)
		detail.Size = UDim2.new(1, -24, 0, 20)
	end

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		local header = makeText(content, biome.displayName, 16, biome.color, true)
		header.Size = UDim2.new(1, -8, 0, 28)

		for _, fish in ipairs(biome.fish) do
			local count = state.Fishdex[fish.id] or 0
			local discovered = count > 0
			local card = makeCard(content, 76)
			local color = discovered and (GameConfig.RarityColors[fish.rarity] or Color3.new(1, 1, 1)) or Color3.fromRGB(115, 125, 140)

			local icon = makeFishIcon(card, fish.id, fish.rarity, discovered)
			icon.Position = UDim2.new(0, 8, 0, 10)
			icon.Size = UDim2.new(0, 56, 0, 56)

			local name = makeText(card, discovered and fish.name or "???", 14, color, true)
			name.Position = UDim2.new(0, 68, 0, 7)
			name.Size = UDim2.new(1, -80, 0, 20)

			local infoText = discovered and string.format("%s | Caught: %d", fish.rarity, count) or (fish.rarity .. " | Not discovered")
			local info = makeText(card, infoText, 12, Color3.fromRGB(190, 204, 220), false)
			info.Position = UDim2.new(0, 68, 0, 31)
			info.Size = UDim2.new(1, -80, 0, 16)

			local marketText = discovered and string.format("Chance: %s%% | Price: %d Coins", fish.chance, fish.value) or "Chance: ??? | Price: ???"
			local market = makeText(card, marketText, 12, Color3.fromRGB(143, 160, 180), false)
			market.Position = UDim2.new(0, 68, 0, 51)
			market.Size = UDim2.new(1, -80, 0, 16)
		end
	end
end

local renderAquariumVisitorsSection

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

	renderAquariumVisitorsSection()
end

renderAquariumVisitorsSection = function()
	local visitors = state.AquariumVisitors or {}

	local top = makeCard(content, 84)
	local heading = makeText(top, "Visit Aquariums", 17, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 12, 0, 8)
	heading.Size = UDim2.new(1, -24, 0, 24)

	local info = makeText(top, "Pick an online player's aquarium and jump straight to it.", 13, Color3.fromRGB(190, 204, 220), false)
	info.Position = UDim2.new(0, 12, 0, 38)
	info.Size = UDim2.new(1, -24, 0, 22)

	if #visitors == 0 then
		local empty = makeCard(content, 64)
		local emptyText = makeText(empty, "No aquariums are ready yet.", 15, Color3.fromRGB(190, 204, 220), true)
		emptyText.Position = UDim2.new(0, 12, 0, 16)
		emptyText.Size = UDim2.new(1, -24, 0, 24)
		return
	end

	for _, visitor in ipairs(visitors) do
		local card = makeCard(content, 92)
		local nameText = visitor.DisplayName or visitor.Name or "Player"
		if visitor.IsSelf then
			nameText = nameText .. " (You)"
		end

		local name = makeText(card, nameText, 16, Color3.fromRGB(255, 255, 255), true)
		name.Position = UDim2.new(0, 12, 0, 8)
		name.Size = UDim2.new(1, -122, 0, 22)

		local used = visitor.UsedCapacity or 0
		local capacity = visitor.Capacity or 0
		local detail = makeText(card, string.format("Online | Level %d | Fish %d | Space %d/%d", visitor.AquariumLevel or 1, visitor.FishCount or 0, used, capacity), 13, Color3.fromRGB(190, 204, 220), false)
		detail.Position = UDim2.new(0, 12, 0, 34)
		detail.Size = UDim2.new(1, -122, 0, 20)

		local bestText = "Best: None yet"
		if visitor.BestCatch then
			bestText = string.format("Best: %s (%d coins)", visitor.BestCatch.name or "Fish", visitor.BestCatch.value or 0)
		end
		local best = makeText(card, bestText, 12, Color3.fromRGB(143, 160, 180), false)
		best.Position = UDim2.new(0, 12, 0, 56)
		best.Size = UDim2.new(1, -122, 0, 18)

		local visit = makeButton(card, visitor.IsSelf and "Go Home" or "Visit", Color3.fromRGB(53, 130, 246))
		visit.Position = UDim2.new(1, -102, 0, 28)
		visit.Size = UDim2.new(0, 86, 0, 36)
		visit.TextSize = 13
		visit.MouseButton1Click:Connect(function()
			TeleportTo:FireServer({
				kind = "PlayerAquarium",
				userId = visitor.UserId,
			})
		end)
	end
end

local function renderTeleportTab()
	local currentLocation = getLocalTravelLocation()
	local targets = {
		{ id = "Lobby", name = "Lobby" },
		{ id = "Home", name = "Home Aquarium" },
	}

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		table.insert(targets, {
			id = biomeId,
			name = biome.displayName,
			biome = biome,
			requirement = biomeId ~= "BeginnerPond" and GameConfig.getBiomeUnlockText(biomeId) or nil,
		})
	end

	for _, target in ipairs(targets) do
		local biome = target.biome
		local unlocked = not biome or state.UnlockedBiomes[target.id]
		local current = currentLocation == target.id
		local card = makeCard(content, biome and 96 or 72)
		local nameColor = biome and biome.color or Color3.fromRGB(255, 255, 255)
		if not unlocked then
			nameColor = Color3.fromRGB(130, 140, 155)
		end

		local name = makeText(card, target.name, 16, nameColor, true)
		name.Position = UDim2.new(0, 12, 0, 8)
		name.Size = UDim2.new(1, -132, 0, 22)

		local detailY = 34
		if target.requirement then
			local requirement = makeText(card, "Requirement: " .. target.requirement, 13, Color3.fromRGB(190, 204, 220), false)
			requirement.Position = UDim2.new(0, 12, 0, detailY)
			requirement.Size = UDim2.new(1, -132, 0, 20)
			detailY = 58
		end

		if biome then
			local detail = makeText(card, "Species: " .. #biome.fish, 12, Color3.fromRGB(143, 160, 180), false)
			detail.Position = UDim2.new(0, 12, 0, detailY)
			detail.Size = UDim2.new(1, -132, 0, 18)
		end

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

local function formatQuestReward(reward)
	local parts = {}
	reward = type(reward) == "table" and reward or {}

	if (tonumber(reward.coins) or 0) > 0 then
		table.insert(parts, tostring(reward.coins) .. " Coins")
	end
	if (tonumber(reward.xp) or 0) > 0 then
		table.insert(parts, tostring(reward.xp) .. " Fishing XP")
	end
	if type(reward.bait) == "table" then
		for _, baitId in ipairs(GameConfig.BaitOrder) do
			local amount = tonumber(reward.bait[baitId]) or 0
			if amount > 0 then
				local bait = GameConfig.Baits[baitId]
				table.insert(parts, tostring(amount) .. " " .. (bait and bait.displayName or baitId))
			end
		end
	end
	if type(reward.decorations) == "table" then
		for _, amount in pairs(reward.decorations) do
			amount = tonumber(amount) or 0
			if amount > 0 then
				table.insert(parts, amount > 1 and (tostring(amount) .. " Aquarium Decorations") or "Aquarium Decoration")
			end
		end
	end

	if #parts == 0 then
		return "Reward ready"
	end

	return table.concat(parts, " | ")
end

local function getQuestPeriod(periodName)
	local quests = state and state.Quests
	return quests and quests[periodName] or nil
end

local function renderQuestPeriodTabs()
	local selector = Instance.new("Frame")
	selector.Size = UDim2.new(1, -8, 0, 38)
	selector.BackgroundTransparency = 1
	selector.Parent = content

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = selector

	for _, periodName in ipairs({ "Daily", "Weekly", "Monthly" }) do
		local button = makeButton(selector, periodName, activeQuestPeriod == periodName and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(38, 45, 57))
		button.Size = UDim2.new(0.333, -5, 1, 0)
		button.MouseButton1Click:Connect(function()
			activeQuestPeriod = periodName
			renderContent()
		end)
	end
end

local function renderQuestsTab()
	renderQuestPeriodTabs()

	local period = getQuestPeriod(activeQuestPeriod)
	if not period then
		local loading = makeCard(content, 64)
		local loadingText = makeText(loading, "Loading quests...", 15, Color3.fromRGB(190, 204, 220), true)
		loadingText.Position = UDim2.new(0, 12, 0, 16)
		loadingText.Size = UDim2.new(1, -24, 0, 24)
		return
	end

	local summary = makeCard(content, 72)
	local heading = makeText(summary, activeQuestPeriod .. " Quests", 17, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 12, 0, 8)
	heading.Size = UDim2.new(1, -24, 0, 24)

	local completedCount = 0
	for _, quest in ipairs(period.quests or {}) do
		if quest.completed then
			completedCount += 1
		end
	end

	local detail = makeText(summary, string.format("%d/%d complete | Resets automatically", completedCount, #(period.quests or {})), 13, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 12, 0, 38)
	detail.Size = UDim2.new(1, -24, 0, 20)

	for _, quest in ipairs(period.quests or {}) do
		local card = makeCard(content, 124)
		local complete = quest.completed == true
		local claimed = quest.claimed == true
		addStroke(card, claimed and Color3.fromRGB(112, 255, 156) or (complete and Color3.fromRGB(255, 219, 92) or Color3.fromRGB(60, 72, 90)), 1).Transparency = complete and 0.16 or 0.45

		local title = makeText(card, quest.title or "Quest", 15, complete and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(235, 242, 255), true)
		title.Position = UDim2.new(0, 12, 0, 7)
		title.Size = UDim2.new(1, -126, 0, 22)

		local description = makeText(card, quest.description or "", 12, Color3.fromRGB(190, 204, 220), false)
		description.Position = UDim2.new(0, 12, 0, 31)
		description.Size = UDim2.new(1, -126, 0, 32)
		description.TextWrapped = true

		local progressText = string.format("Progress: %d/%d", tonumber(quest.progress) or 0, tonumber(quest.target) or 1)
		local progress = makeText(card, progressText, 12, complete and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(143, 160, 180), true)
		progress.Position = UDim2.new(0, 12, 0, 66)
		progress.Size = UDim2.new(1, -126, 0, 18)

		local reward = makeText(card, "Reward: " .. formatQuestReward(quest.reward), 12, Color3.fromRGB(214, 226, 244), false)
		reward.Position = UDim2.new(0, 12, 0, 88)
		reward.Size = UDim2.new(1, -126, 0, 28)
		reward.TextWrapped = true

		if claimed then
			local checkHolder = Instance.new("Frame")
			checkHolder.Position = UDim2.new(1, -82, 0, 18)
			checkHolder.Size = UDim2.new(0, 48, 0, 38)
			checkHolder.BackgroundTransparency = 1
			checkHolder.Parent = card

			local checkShort = Instance.new("Frame")
			checkShort.AnchorPoint = Vector2.new(0.5, 0.5)
			checkShort.Position = UDim2.new(0, 18, 0, 23)
			checkShort.Size = UDim2.new(0, 8, 0, 22)
			checkShort.Rotation = -38
			checkShort.BackgroundColor3 = Color3.fromRGB(112, 255, 156)
			checkShort.BorderSizePixel = 0
			checkShort.Parent = checkHolder
			addCorner(checkShort, 4)

			local checkLong = Instance.new("Frame")
			checkLong.AnchorPoint = Vector2.new(0.5, 0.5)
			checkLong.Position = UDim2.new(0, 30, 0, 18)
			checkLong.Size = UDim2.new(0, 8, 0, 34)
			checkLong.Rotation = 42
			checkLong.BackgroundColor3 = Color3.fromRGB(112, 255, 156)
			checkLong.BorderSizePixel = 0
			checkLong.Parent = checkHolder
			addCorner(checkLong, 4)

			local claimedText = makeText(card, "Claimed", 12, Color3.fromRGB(112, 255, 156), true)
			claimedText.Position = UDim2.new(1, -104, 0, 58)
			claimedText.Size = UDim2.new(0, 90, 0, 20)
			claimedText.TextXAlignment = Enum.TextXAlignment.Center
		elseif complete then
			local claim = makeButton(card, "Claim", Color3.fromRGB(28, 160, 92))
			claim.Position = UDim2.new(1, -104, 0, 42)
			claim.Size = UDim2.new(0, 88, 0, 36)
			claim.MouseButton1Click:Connect(function()
				fireQuestAction("Claim", activeQuestPeriod, quest.id)
			end)
		else
			local status = makeText(card, "In Progress", 12, Color3.fromRGB(143, 160, 180), true)
			status.Position = UDim2.new(1, -106, 0, 48)
			status.Size = UDim2.new(0, 92, 0, 24)
			status.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
end

function fishyFishGetMonetizationState()
	return state and state.Monetization or {}
end

function fishyFishOwnsGamePass(passKey)
	local monetization = fishyFishGetMonetizationState()
	local owned = monetization.OwnedGamePasses or {}
	return owned[passKey] == true
end

function fishyFishCopyAquariumDesignWith(changes)
	local monetization = fishyFishGetMonetizationState()
	local current = monetization.AquariumPreviewDesign or monetization.AquariumDesign or MonetizationConfig.AquariumDesigner.defaultDesign
	local design = {
		theme = current.theme,
		backgroundColor = current.backgroundColor,
		lightingColor = current.lightingColor,
		signText = current.signText or "",
		decorations = {},
	}

	for slotId, decorationId in pairs(current.decorations or {}) do
		design.decorations[slotId] = decorationId
	end

	if type(changes) == "table" then
		for key, value in pairs(changes) do
			if key == "decorations" and type(value) == "table" then
				for slotId, decorationId in pairs(value) do
					if decorationId == "None" then
						design.decorations[slotId] = nil
					else
						design.decorations[slotId] = decorationId
					end
				end
			else
				design[key] = value
			end
		end
	end

	return design
end

function fishyFishMakeShopIcon(parent, text, color)
	local icon = Instance.new("Frame")
	icon.Position = UDim2.new(0, 10, 0, 12)
	icon.Size = UDim2.new(0, 54, 0, 54)
	icon.BackgroundColor3 = color or Color3.fromRGB(53, 130, 246)
	icon.Parent = parent
	addCorner(icon, 8)
	addStroke(icon, Color3.fromRGB(255, 255, 255), 1).Transparency = 0.75

	local label = makeText(icon, text, 14, Color3.fromRGB(255, 255, 255), true)
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextWrapped = true
	return icon
end

function fishyFishRenderShopSubTabs()
	local selector = Instance.new("Frame")
	selector.Size = UDim2.new(1, -8, 0, 38)
	selector.BackgroundTransparency = 1
	selector.Parent = content

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = selector

	for _, tabName in ipairs({ "Game Passes", "Bait", "Aquarium", "Storage" }) do
		local button = makeButton(selector, tabName, activeShopTab == tabName and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(38, 45, 57))
		button.Size = UDim2.new(0.25, -5, 1, 0)
		button.TextSize = 12
		button.MouseButton1Click:Connect(function()
			activeShopTab = tabName
			renderContent()
		end)
	end
end

function fishyFishRenderRobuxItem(itemKey, item, purchaseAction, owned, iconText, iconColor)
	local card = makeCard(content, 104)
	fishyFishMakeShopIcon(card, iconText, iconColor)

	local name = makeText(card, item.name, 15, Color3.fromRGB(255, 255, 255), true)
	name.Position = UDim2.new(0, 76, 0, 8)
	name.Size = UDim2.new(1, -194, 0, 22)

	local description = makeText(card, item.description, 12, Color3.fromRGB(190, 204, 220), false)
	description.Position = UDim2.new(0, 76, 0, 32)
	description.Size = UDim2.new(1, -194, 0, 36)
	description.TextWrapped = true

	local price = makeText(card, tostring(item.priceRobux or "?") .. " Robux", 12, Color3.fromRGB(255, 219, 92), true)
	price.Position = UDim2.new(0, 76, 0, 74)
	price.Size = UDim2.new(1, -194, 0, 18)

	if owned then
		local ownedText = makeText(card, "Owned", 13, Color3.fromRGB(112, 255, 156), true)
		ownedText.Position = UDim2.new(1, -108, 0, 35)
		ownedText.Size = UDim2.new(0, 92, 0, 34)
		ownedText.TextXAlignment = Enum.TextXAlignment.Center
	else
		local purchase = makeButton(card, "Buy", Color3.fromRGB(28, 160, 92))
		purchase.Position = UDim2.new(1, -104, 0, 35)
		purchase.Size = UDim2.new(0, 88, 0, 34)
		purchase.MouseButton1Click:Connect(function()
			purchaseAction(itemKey)
		end)
	end
end

function fishyFishRenderShopGamePasses()
	local monetization = fishyFishGetMonetizationState()
	local reward = makeCard(content, 92)
	fishyFishMakeShopIcon(reward, "VIP", Color3.fromRGB(255, 181, 36))
	local title = makeText(reward, "VIP Daily Reward", 16, Color3.fromRGB(255, 255, 255), true)
	title.Position = UDim2.new(0, 76, 0, 10)
	title.Size = UDim2.new(1, -194, 0, 22)
	local detail = makeText(reward, "5 Fresh Bait + 2 Lucky Bait once per day.", 12, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 76, 0, 36)
	detail.Size = UDim2.new(1, -194, 0, 20)
	local rewardButton = makeButton(reward, monetization.VipRewardAvailable and "Claim" or "VIP", monetization.VipRewardAvailable and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(86, 98, 115))
	rewardButton.Position = UDim2.new(1, -104, 0, 29)
	rewardButton.Size = UDim2.new(0, 88, 0, 34)
	rewardButton.AutoButtonColor = monetization.VipRewardAvailable == true
	rewardButton.MouseButton1Click:Connect(function()
		fireShopAction("ClaimVipReward", "GamePass", "VipAngler")
	end)

	for _, passKey in ipairs({ "VipAngler", "AquariumDesigner" }) do
		local pass = MonetizationConfig.GamePasses[passKey]
		fishyFishRenderRobuxItem(passKey, pass, function(key)
			fireShopAction("PromptGamePass", "GamePass", key)
		end, fishyFishOwnsGamePass(passKey), passKey == "VipAngler" and "VIP" or "AQUA", passKey == "VipAngler" and Color3.fromRGB(255, 181, 36) or Color3.fromRGB(58, 174, 205))
	end
end

function fishyFishRenderShopBait()
	for _, productKey in ipairs(MonetizationConfig.DeveloperProductOrder) do
		local product = MonetizationConfig.DeveloperProducts[productKey]
		fishyFishRenderRobuxItem(productKey, product, function(key)
			fireShopAction("PromptProduct", "Product", key)
		end, false, "BAIT", Color3.fromRGB(116, 94, 255))
	end
end

function fishyFishRenderShopStorage()
	local summary = makeCard(content, 74)
	local heading = makeText(summary, "Fish Bag Storage", 16, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 12, 0, 10)
	heading.Size = UDim2.new(1, -24, 0, 22)
	local detail = makeText(summary, string.format("Current capacity: %d fish", state.BackpackSize or 0), 13, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 12, 0, 38)
	detail.Size = UDim2.new(1, -24, 0, 20)

	for _, passKey in ipairs({ "SmallBag", "MediumBag", "LargeBag" }) do
		local pass = MonetizationConfig.GamePasses[passKey]
		fishyFishRenderRobuxItem(passKey, pass, function(key)
			fireShopAction("PromptGamePass", "GamePass", key)
		end, fishyFishOwnsGamePass(passKey), "+" .. tostring(pass.bonusSlots or 0), Color3.fromRGB(76, 160, 92))
	end
end

function fishyFishRenderAquariumDesignerControls()
	local monetization = fishyFishGetMonetizationState()
	local ownsDesigner = fishyFishOwnsGamePass("AquariumDesigner")
	local currentDesign = monetization.AquariumPreviewDesign or monetization.AquariumDesign or MonetizationConfig.AquariumDesigner.defaultDesign
	local aquariumLevel = (state and state.Aquarium and tonumber(state.Aquarium.Level)) or 1

	local summary = makeCard(content, 96)
	fishyFishMakeShopIcon(summary, ownsDesigner and "OPEN" or "LOCK", ownsDesigner and Color3.fromRGB(58, 174, 205) or Color3.fromRGB(96, 106, 122))
	local heading = makeText(summary, "Aquarium Designer", 16, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 76, 0, 8)
	heading.Size = UDim2.new(1, -194, 0, 22)
	local status = ownsDesigner and "Owned | Preview, apply, and save premium designs." or "Preview is free. Apply premium designs after buying the pass."
	local detail = makeText(summary, status, 12, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 76, 0, 34)
	detail.Size = UDim2.new(1, -194, 0, 34)
	detail.TextWrapped = true
	local cancel = makeButton(summary, monetization.AquariumPreviewActive and "Cancel" or "Preview", monetization.AquariumPreviewActive and Color3.fromRGB(230, 126, 48) or Color3.fromRGB(86, 98, 115))
	cancel.Position = UDim2.new(1, -104, 0, 31)
	cancel.Size = UDim2.new(0, 88, 0, 34)
	cancel.MouseButton1Click:Connect(function()
		fireShopAction("CancelAquariumPreview", "Aquarium")
	end)

	local function renderDesignOption(kind, id, item, labelPrefix)
		local premium = item.premium == true
		local card = makeCard(content, 124)
		fishyFishMakeShopIcon(card, premium and "LOCK" or "FREE", premium and Color3.fromRGB(255, 181, 36) or Color3.fromRGB(58, 174, 205))
		local name = makeText(card, (labelPrefix or "") .. item.name, 15, Color3.fromRGB(255, 255, 255), true)
		name.Position = UDim2.new(0, 76, 0, 8)
		name.Size = UDim2.new(1, -96, 0, 22)
		local desc = makeText(card, premium and "Premium aquarium option" or "Standard aquarium option", 12, Color3.fromRGB(190, 204, 220), false)
		desc.Position = UDim2.new(0, 76, 0, 34)
		desc.Size = UDim2.new(1, -96, 0, 18)
		local selected = currentDesign[kind] == id
		local statusText = makeText(card, selected and "Selected" or (premium and "Requires Designer Pass" or "Available"), 12, selected and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(143, 160, 180), false)
		statusText.Position = UDim2.new(0, 76, 0, 58)
		statusText.Size = UDim2.new(1, -96, 0, 18)

		local preview = makeButton(card, "Preview", Color3.fromRGB(53, 130, 246))
		preview.Position = UDim2.new(1, -196, 0, 82)
		preview.Size = UDim2.new(0, 84, 0, 32)
		preview.TextSize = 12
		preview.MouseButton1Click:Connect(function()
			fireShopAction("PreviewAquariumDesign", "Aquarium", kind, fishyFishCopyAquariumDesignWith({ [kind] = id }))
		end)

		local apply = makeButton(card, premium and "Apply" or "Apply", premium and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(28, 160, 92))
		apply.Position = UDim2.new(1, -104, 0, 82)
		apply.Size = UDim2.new(0, 88, 0, 32)
		apply.TextSize = 12
		apply.MouseButton1Click:Connect(function()
			fireShopAction("ApplyAquariumDesign", "Aquarium", kind, fishyFishCopyAquariumDesignWith({ [kind] = id }))
		end)
	end

	local themeHeader = makeText(content, "Themes", 16, Color3.fromRGB(255, 255, 255), true)
	themeHeader.Size = UDim2.new(1, -8, 0, 28)
	for _, themeId in ipairs(MonetizationConfig.AquariumDesigner.themeOrder) do
		renderDesignOption("theme", themeId, MonetizationConfig.AquariumDesigner.themes[themeId])
	end

	local signCard = makeCard(content, 104)
	fishyFishMakeShopIcon(signCard, "TEXT", Color3.fromRGB(255, 181, 36))
	local signTitle = makeText(signCard, "Display Sign Text", 15, Color3.fromRGB(255, 255, 255), true)
	signTitle.Position = UDim2.new(0, 76, 0, 8)
	signTitle.Size = UDim2.new(1, -194, 0, 22)
	local signBox = Instance.new("TextBox")
	signBox.Position = UDim2.new(0, 76, 0, 38)
	signBox.Size = UDim2.new(1, -194, 0, 32)
	signBox.BackgroundColor3 = Color3.fromRGB(38, 45, 57)
	signBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	signBox.PlaceholderText = "Custom sign text"
	signBox.Text = currentDesign.signText or ""
	signBox.Font = Enum.Font.Gotham
	signBox.TextSize = 13
	signBox.ClearTextOnFocus = false
	signBox.Parent = signCard
	addCorner(signBox, 6)
	addStroke(signBox, Color3.fromRGB(60, 72, 90), 1)
	local applySign = makeButton(signCard, "Apply", Color3.fromRGB(28, 160, 92))
	applySign.Position = UDim2.new(1, -104, 0, 72)
	applySign.Size = UDim2.new(0, 88, 0, 26)
	applySign.TextSize = 12
	applySign.MouseButton1Click:Connect(function()
		fireShopAction("ApplyAquariumDesign", "Aquarium", "signText", fishyFishCopyAquariumDesignWith({ signText = signBox.Text }))
	end)

	local decorHeader = makeText(content, "Fixed Decoration Slots", 16, Color3.fromRGB(255, 255, 255), true)
	decorHeader.Size = UDim2.new(1, -8, 0, 28)
	for _, slotId in ipairs(MonetizationConfig.AquariumDesigner.slotOrder) do
		local slot = MonetizationConfig.AquariumDesigner.slots[slotId]
		local card = makeCard(content, 190)
		local requiredLevel = tonumber(slot.level) or 1
		local lockedByLevel = requiredLevel > aquariumLevel
		local lockedByPass = not ownsDesigner
		local locked = lockedByLevel
		local selectedDecoration = currentDesign.decorations and currentDesign.decorations[slotId] or "None"
		local lockLabel = ""
		if lockedByLevel then
			lockLabel = "  [Level " .. tostring(requiredLevel) .. "]"
		elseif lockedByPass then
			lockLabel = "  [LOCK]"
		end
		local name = makeText(card, slot.name .. lockLabel, 15, (lockedByLevel or lockedByPass) and Color3.fromRGB(143, 160, 180) or Color3.fromRGB(255, 255, 255), true)
		name.Position = UDim2.new(0, 12, 0, 8)
		name.Size = UDim2.new(1, -24, 0, 22)
		local detailText
		if lockedByLevel then
			detailText = "Locked until aquarium level " .. tostring(requiredLevel)
		elseif lockedByPass then
			detailText = "Requires Aquarium Designer Pass. Preview is allowed."
		else
			detailText = "Selected: " .. ((MonetizationConfig.AquariumDesigner.decorations[selectedDecoration] or {}).name or "None")
		end
		local detail = makeText(card, detailText, 12, (lockedByLevel or lockedByPass) and Color3.fromRGB(255, 190, 105) or Color3.fromRGB(190, 204, 220), false)
		detail.Position = UDim2.new(0, 12, 0, 32)
		detail.Size = UDim2.new(1, -24, 0, 18)

		local x = 12
		local rowY = 56
		for _, decorationId in ipairs(MonetizationConfig.AquariumDesigner.decorationOrder) do
			local decoration = MonetizationConfig.AquariumDesigner.decorations[decorationId]
			local wideButton = decorationId == "TreasureChest" or decorationId == "ShipwreckPiece" or decorationId == "BubbleMachine"
			local buttonWidth = wideButton and 112 or 76
			if x + buttonWidth > 380 then
				x = 12
				rowY += 32
			end
			local buttonColor = locked and Color3.fromRGB(64, 72, 86) or (decorationId == selectedDecoration and Color3.fromRGB(91, 104, 124) or Color3.fromRGB(53, 130, 246))
			local button = makeButton(card, decoration.name, buttonColor)
			button.Position = UDim2.new(0, x, 0, rowY)
			button.Size = UDim2.new(0, buttonWidth, 0, 28)
			button.TextSize = 10
			button.AutoButtonColor = not locked
			if locked then
				button.TextColor3 = Color3.fromRGB(160, 171, 190)
			else
				button.MouseButton1Click:Connect(function()
					fireShopAction("PreviewAquariumDesign", "Aquarium", slotId, fishyFishCopyAquariumDesignWith({
						decorations = {
							[slotId] = decorationId,
						},
					}))
				end)
			end
			x += buttonWidth + 6
		end

		local applyText = lockedByLevel and "Locked" or (lockedByPass and "Buy Pass" or "Apply Slot")
		local applyColor = (lockedByLevel or lockedByPass) and Color3.fromRGB(86, 98, 115) or Color3.fromRGB(28, 160, 92)
		local apply = makeButton(card, applyText, applyColor)
		apply.Position = UDim2.new(1, -112, 0, 150)
		apply.Size = UDim2.new(0, 96, 0, 28)
		apply.TextSize = 12
		apply.AutoButtonColor = not lockedByLevel
		if lockedByPass and not lockedByLevel then
			apply.MouseButton1Click:Connect(function()
				fireShopAction("PromptGamePass", "GamePass", "AquariumDesigner")
			end)
		elseif not lockedByLevel then
			apply.MouseButton1Click:Connect(function()
				fireShopAction("ApplyAquariumDesign", "Aquarium", slotId, currentDesign)
			end)
		end
	end
end

local function renderShopTab()
	fishyFishRenderShopSubTabs()

	if activeShopTab == "Game Passes" then
		fishyFishRenderShopGamePasses()
	elseif activeShopTab == "Bait" then
		fishyFishRenderShopBait()
	elseif activeShopTab == "Aquarium" then
		fishyFishRenderAquariumDesignerControls()
	elseif activeShopTab == "Storage" then
		fishyFishRenderShopStorage()
	end
end

local function getPlayerLeaderstat(targetPlayer, statName)
	local leaderstats = targetPlayer:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(statName)
	if stat and stat:IsA("ValueBase") then
		return stat.Value
	end

	return 0
end

local function formatCompactNumber(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000):gsub("%.0M", "M")
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000):gsub("%.0K", "K")
	end

	return tostring(value)
end

local function renderLeaderboardTab()
	local function makeLeaderboardCard(height, strokeColor, strokeThickness, strokeTransparency)
		local wrapper = Instance.new("Frame")
		wrapper.Name = "LeaderboardCardRow"
		wrapper.Size = UDim2.new(1, 0, 0, height)
		wrapper.BackgroundTransparency = 1
		wrapper.Parent = content

		local card = Instance.new("Frame")
		card.Name = "LeaderboardCard"
		card.Position = UDim2.new(0, 6, 0, 1)
		card.Size = UDim2.new(1, -12, 1, -2)
		card.BackgroundColor3 = Color3.fromRGB(27, 33, 43)
		card.Parent = wrapper
		addCorner(card, 8)
		local stroke = addStroke(card, strokeColor or Color3.fromRGB(60, 72, 90), strokeThickness or 1)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		if strokeTransparency ~= nil then
			stroke.Transparency = strokeTransparency
		end
		return card, stroke
	end

	local onlinePlayers = Players:GetPlayers()
	table.sort(onlinePlayers, function(left, right)
		local leftCaught = tonumber(getPlayerLeaderstat(left, "Fish Caught")) or 0
		local rightCaught = tonumber(getPlayerLeaderstat(right, "Fish Caught")) or 0
		if leftCaught ~= rightCaught then
			return leftCaught > rightCaught
		end

		return string.lower(left.DisplayName or left.Name) < string.lower(right.DisplayName or right.Name)
	end)

	local summary = makeLeaderboardCard(80)
	local heading = makeText(summary, "Leaderboard", 17, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 18, 0, 8)
	heading.Size = UDim2.new(1, -30, 0, 24)

	local detail = makeText(summary, string.format("Sorted by fish-caught leaderboard | %d player%s online", #onlinePlayers, #onlinePlayers == 1 and "" or "s"), 13, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 18, 0, 38)
	detail.Size = UDim2.new(1, -36, 0, 20)

	local header = makeLeaderboardCard(38)
	local rankHeader = makeText(header, "#", 12, Color3.fromRGB(143, 160, 180), true)
	rankHeader.Position = UDim2.new(0, 16, 0, 8)
	rankHeader.Size = UDim2.new(0, 28, 0, 20)
	rankHeader.TextXAlignment = Enum.TextXAlignment.Center
	local nameHeader = makeText(header, "Player", 12, Color3.fromRGB(143, 160, 180), true)
	nameHeader.Position = UDim2.new(0, 52, 0, 8)
	nameHeader.Size = UDim2.new(0.48, -52, 0, 20)
	local coinsHeader = makeText(header, "Coins", 12, Color3.fromRGB(143, 160, 180), true)
	coinsHeader.Position = UDim2.new(0.52, 0, 0, 8)
	coinsHeader.Size = UDim2.new(0.17, 0, 0, 20)
	coinsHeader.TextXAlignment = Enum.TextXAlignment.Center
	local levelHeader = makeText(header, "Level", 12, Color3.fromRGB(143, 160, 180), true)
	levelHeader.Position = UDim2.new(0.69, 0, 0, 8)
	levelHeader.Size = UDim2.new(0.14, 0, 0, 20)
	levelHeader.TextXAlignment = Enum.TextXAlignment.Center
	local caughtHeader = makeText(header, "Fish", 12, Color3.fromRGB(143, 160, 180), true)
	caughtHeader.Position = UDim2.new(0.83, 0, 0, 8)
	caughtHeader.Size = UDim2.new(0.17, -18, 0, 20)
	caughtHeader.TextXAlignment = Enum.TextXAlignment.Center

	for rank, listedPlayer in ipairs(onlinePlayers) do
		local isSelf = listedPlayer == player
		local card = makeLeaderboardCard(62, isSelf and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(60, 72, 90), isSelf and 2 or 1, isSelf and 0 or 0.45)

		local displayName = listedPlayer.DisplayName or listedPlayer.Name
		if listedPlayer:GetAttribute("FishyFishVip") == true then
			displayName = "[VIP] " .. displayName
		end
		if isSelf then
			displayName ..= " (You)"
		end

		local rankLabel = makeText(card, tostring(rank), 13, Color3.fromRGB(143, 160, 180), true)
		rankLabel.Position = UDim2.new(0, 16, 0, 20)
		rankLabel.Size = UDim2.new(0, 28, 0, 20)
		rankLabel.TextXAlignment = Enum.TextXAlignment.Center

		local name = makeText(card, displayName, 13, isSelf and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(255, 255, 255), true)
		name.Position = UDim2.new(0, 52, 0, 8)
		name.Size = UDim2.new(0.48, -52, 0, 22)
		name.TextTruncate = Enum.TextTruncate.None

		local username = makeText(card, "@" .. listedPlayer.Name, 11, Color3.fromRGB(143, 160, 180), false)
		username.Position = UDim2.new(0, 52, 0, 32)
		username.Size = UDim2.new(0.48, -52, 0, 16)
		username.TextTruncate = Enum.TextTruncate.None

		local coins = makeText(card, formatCompactNumber(getPlayerLeaderstat(listedPlayer, "Coins")), 13, Color3.fromRGB(235, 242, 255), true)
		coins.Position = UDim2.new(0.52, 0, 0, 20)
		coins.Size = UDim2.new(0.17, 0, 0, 20)
		coins.TextXAlignment = Enum.TextXAlignment.Center

		local level = makeText(card, tostring(getPlayerLeaderstat(listedPlayer, "Level")), 13, Color3.fromRGB(235, 242, 255), true)
		level.Position = UDim2.new(0.69, 0, 0, 20)
		level.Size = UDim2.new(0.14, 0, 0, 20)
		level.TextXAlignment = Enum.TextXAlignment.Center

		local caught = makeText(card, formatCompactNumber(getPlayerLeaderstat(listedPlayer, "Fish Caught")), 13, Color3.fromRGB(235, 242, 255), true)
		caught.Position = UDim2.new(0.83, 0, 0, 20)
		caught.Size = UDim2.new(0.17, -18, 0, 20)
		caught.TextXAlignment = Enum.TextXAlignment.Center
	end
end

renderContent = function()
	if activeTab == "Rods" then
		activeTab = "Bag"
	elseif activeTab == "Fish" then
		activeTab = "Fishdex"
	elseif activeTab == "Aquariums" then
		activeTab = "Aquarium"
	elseif activeTab == "Biomes" then
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

	if activeTab == "Bag" then
		renderBagTab()
	elseif activeTab == "Fishdex" then
		renderFishdexTab()
	elseif activeTab == "Aquarium" then
		renderAquariumTab()
	elseif activeTab == "Teleport" then
		renderTeleportTab()
	elseif activeTab == "Quests" then
		renderQuestsTab()
	elseif activeTab == "Shop" then
		renderShopTab()
	elseif activeTab == "Leaderboard" then
		renderLeaderboardTab()
	end
end

local function runMinigame(prompt)
	if minigameRunning then
		return
	end

	local isAutoFish = prompt.autoFish == true
	local fish = prompt.fish or {}
	local promptBait = prompt.bait or {}
	local promptBaitId = promptBait.id or (state and state.EquippedBait) or GameConfig.BasicBaitId
	local promptBaitData = getBaitData(promptBaitId)
	local promptBaitName = promptBait.name or promptBaitData.displayName
	local promptBaitText = "Bait: " .. promptBaitName .. " (" .. getBaitCountText(promptBaitId, promptBait.remaining) .. ")"
	local castText = prompt.cast and prompt.cast.displayName and ("\nCast: " .. prompt.cast.displayName) or ""
	local minigameConfig = prompt.minigame or GameConfig.getFishingMinigameConfig(fish.rarity or "Common", state and state.EquippedRod or "WoodenRod")
	local difficulty = minigameConfig.difficulty or GameConfig.FishingMinigame.RarityDifficulty.Common
	local random = Random.new(math.floor((os.clock() * 100000) % 2147483647))

	minigameRunning = true
	CastPower.running = false
	CastPower.activeConfig = nil
	setMinigameVisible(true)
	CastPower.content.Visible = false
	catchButton.Visible = false
	timingBar.Visible = false
	zone.Visible = false
	marker.Visible = false
	fishingGameContent.Visible = true
	setMinigameFishIcon(fish)

	minigameText.Text = isAutoFish and "AutoFish is waiting for a bite..." or "Waiting for a bite..."
	minigameFishInfo.Text = "Something is biting..."
	minigameProgressText.Text = "Progress --"
	minigameInstruction.Text = promptBaitText .. castText
	progressFill.Size = UDim2.new(1, 0, 0, 0)
	forcePureWhiteText(minigameText)

	task.wait(tonumber(prompt.biteDelay) or 0)

	if not minigameRunning then
		return
	end

	local barSize = math.clamp(tonumber(minigameConfig.barSize) or 0.24, 0.16, 0.58)
	local maxBarTop = 1 - barSize
	local barTop = math.clamp(0.70, 0, maxBarTop)
	local barVelocity = 0
	local fishY = random:NextNumber(0.20, 0.80)
	local fishTarget = random:NextNumber(0.15, 0.85)
	local fishVelocity = 0
	local progress = math.clamp(tonumber(minigameConfig.startProgress) or 0.34, 0.08, 0.86)
	local minSuccessDuration = tonumber(minigameConfig.minSuccessDuration) or 1.75
	local maxDuration = tonumber(minigameConfig.maxDuration) or 35
	local gameStartedAt = os.clock()
	local nextDecisionAt = gameStartedAt + random:NextNumber(difficulty.turnIntervalMin or 1, difficulty.turnIntervalMax or 2)
	local pauseUntil = 0
	local burstUntil = 0
	local holding = false
	local finished = false

	catchBar.Size = UDim2.new(1, -32, barSize, 0)
	catchBar.Position = UDim2.new(0.5, 0, barTop, 0)
	fishMarker.Position = UDim2.new(0.5, 0, fishY, 0)
	progressFill.Size = UDim2.new(1, 0, progress, 0)
	minigameText.Text = isAutoFish and "AutoFish is reeling..." or "Keep the fish inside the green bar!"
	minigameFishInfo.Text = string.format("%s [%s]\nValue: %d | XP: %d", fish.name or "Fish", fish.rarity or "Common", fish.value or 0, fish.xp or 0)
	minigameProgressText.Text = string.format("Progress %d%%", math.floor(progress * 100 + 0.5))
	minigameInstruction.Text = promptBaitText .. castText .. "\n" .. (isAutoFish and "AutoFish is handling this catch." or "Hold mouse, tap, or Space to lift the green bar. Release to let it fall.")
	forcePureWhiteText(minigameText)

	local renderConnection
	local inputBeganConnection
	local inputEndedConnection

	local function disconnectAll()
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		if inputBeganConnection then
			inputBeganConnection:Disconnect()
			inputBeganConnection = nil
		end
		if inputEndedConnection then
			inputEndedConnection:Disconnect()
			inputEndedConnection = nil
		end
	end
	activeMinigameCleanup = disconnectAll

	local function finish(success)
		if finished then
			return
		end

		finished = true
		disconnectAll()
		activeMinigameCleanup = nil

		setMinigameVisible(false)
		minigameRunning = false
		fishingBusy = false

		if not isAutoFish then
			FinishMinigame:FireServer({
				success = success == true,
				sessionId = prompt.sessionId,
			})
		end

		renderContent()
	end

	local function isCatchInput(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.Space
	end

	if not isAutoFish then
		inputBeganConnection = UserInputService.InputBegan:Connect(function(input)
			if isCatchInput(input) then
				holding = true
			end
		end)

		inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
			if isCatchInput(input) then
				holding = false
			end
		end)
	end

	local function chooseFishTarget(fromY, preferFarTarget)
		if preferFarTarget then
			local jumpMin = tonumber(difficulty.jumpMin) or 0.12
			local jumpMax = math.max(jumpMin, tonumber(difficulty.jumpMax) or jumpMin)
			local direction = random:NextInteger(0, 1) == 0 and -1 or 1
			local distance = random:NextNumber(jumpMin, jumpMax)
			local target = fromY + (direction * distance)

			if target < 0.08 or target > 0.92 then
				target = fromY - (direction * distance)
			end

			return math.clamp(target, 0.08, 0.92)
		end

		return random:NextNumber(0.08, 0.92)
	end

	renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if not minigameRunning or finished then
			return
		end

		local now = os.clock()
		local elapsed = now - gameStartedAt

		if now >= nextDecisionAt then
			local pauseChance = difficulty.pauseChance or 0
			local jumpChance = difficulty.jumpChance or 0
			local burstChance = difficulty.burstChance or 0

			fishTarget = chooseFishTarget(fishY, jumpChance > 0 and random:NextNumber() < jumpChance)

			if pauseChance > 0 and random:NextNumber() < pauseChance then
				pauseUntil = now + random:NextNumber(difficulty.pauseMin or 0.12, difficulty.pauseMax or 0.45)
			end

			if burstChance > 0 and random:NextNumber() < burstChance then
				burstUntil = now + random:NextNumber(difficulty.burstMin or 0.18, difficulty.burstMax or 0.38)
			end

			nextDecisionAt = now + random:NextNumber(difficulty.turnIntervalMin or 1, difficulty.turnIntervalMax or 2)
		end

		local targetVelocity = 0
		if now >= pauseUntil then
			local distance = fishTarget - fishY
			local targetSlack = tonumber(difficulty.targetSlack) or 0.025
			if math.abs(distance) < targetSlack then
				fishTarget = chooseFishTarget(fishY, false)
				distance = fishTarget - fishY
			end

			local direction = distance >= 0 and 1 or -1
			local jitter = random:NextNumber(-(difficulty.jitter or 0), difficulty.jitter or 0)
			local speed = tonumber(difficulty.moveSpeed) or 0.25
			if now < burstUntil then
				speed *= tonumber(difficulty.burstMultiplier) or 1.35
			end

			targetVelocity = (direction * speed) + jitter
		end

		local acceleration = tonumber(difficulty.acceleration) or 6
		local velocityBlend = math.min(1, acceleration * deltaTime)
		fishVelocity += (targetVelocity - fishVelocity) * velocityBlend
		fishY += fishVelocity * deltaTime

		if fishY <= 0.04 then
			fishY = 0.04
			fishVelocity = math.abs(fishVelocity) * 0.35
			fishTarget = math.max(fishTarget, 0.16)
		elseif fishY >= 0.96 then
			fishY = 0.96
			fishVelocity = -math.abs(fishVelocity) * 0.35
			fishTarget = math.min(fishTarget, 0.84)
		end

		if isAutoFish then
			local targetTop = math.clamp(fishY - (barSize / 2), 0, maxBarTop)
			barTop += (targetTop - barTop) * math.min(1, deltaTime * 5)
			progress = math.clamp(progress + (minigameConfig.progressGainPerSecond or 0.34) * deltaTime, 0, 1)
		else
			local acceleration = holding and -(minigameConfig.lift or 2.75) or (minigameConfig.gravity or 1.8)
			barVelocity += acceleration * deltaTime
			barVelocity = math.clamp(barVelocity, -(minigameConfig.maxBarVelocity or 1.65), minigameConfig.maxBarVelocity or 1.65)
			barVelocity *= math.pow(minigameConfig.damping or 0.90, deltaTime * 60)
			barTop += barVelocity * deltaTime

			if barTop <= 0 then
				barTop = 0
				barVelocity = math.abs(barVelocity) * (minigameConfig.bounceDamping or 0.36)
			elseif barTop >= maxBarTop then
				barTop = maxBarTop
				barVelocity = -math.abs(barVelocity) * (minigameConfig.bounceDamping or 0.36)
			end

			local fishInsideBar = fishY >= barTop and fishY <= barTop + barSize
			if fishInsideBar then
				progress += (minigameConfig.progressGainPerSecond or 0.34) * deltaTime
			else
				progress -= (minigameConfig.progressDrainPerSecond or 0.16) * deltaTime
			end
			progress = math.clamp(progress, 0, 1)
		end

		catchBar.Position = UDim2.new(0.5, 0, barTop, 0)
		fishMarker.Position = UDim2.new(0.5, 0, fishY, 0)
		progressFill.Size = UDim2.new(1, 0, progress, 0)
		minigameProgressText.Text = string.format("Progress %d%%", math.floor(progress * 100 + 0.5))

		if isAutoFish and elapsed >= (prompt.visualTime or 3) then
			minigameText.Text = "AutoFish caught it!"
			finish(true)
		elseif not isAutoFish and progress >= 1 and elapsed >= minSuccessDuration then
			minigameText.Text = "Caught!"
			finish(true)
		elseif not isAutoFish and progress <= 0 then
			minigameText.Text = "The fish escaped!"
			finish(false)
		elseif not isAutoFish and elapsed >= maxDuration then
			minigameText.Text = "The fish escaped!"
			finish(false)
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
	if fishmongerOverlay.Visible then
		renderFishmongerSellOptions()
	end
	if rodShopUI.overlay.Visible then
		renderRodShopOptions()
	end
end)

FishingPrompt.OnClientEvent:Connect(function(prompt)
	if prompt.autoFish then
		showToast("AutoFish is catching...")
	elseif prompt.cast and prompt.cast.displayName then
		if prompt.cast.sparkle then
			CastPower.showSparkle()
		end
		showToast(prompt.cast.displayName .. " Cast! Fish is biting!")
	else
		showToast("Fish is biting. Keep it in the green bar!")
	end
	runMinigame(prompt)
end)

Notice.OnClientEvent:Connect(function(message)
	if activeMinigameCleanup then
		activeMinigameCleanup()
		activeMinigameCleanup = nil
	end

	showToast(message)
	fishingBusy = false
	minigameRunning = false
	CastPower.running = false
	CastPower.activeConfig = nil
	CastPower.content.Visible = false
	setMinigameVisible(false)
	renderContent()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if minigameRunning or CastPower.running then
		return
	end

	if input.KeyCode == Enum.KeyCode.F and state and not fishingBusy and getActiveFishingBiomeId() then
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

local locationCheckElapsed = 0
RunService.RenderStepped:Connect(function(deltaTime)
	locationCheckElapsed += deltaTime
	if locationCheckElapsed < 0.25 then
		return
	end
	locationCheckElapsed = 0

	local biomeId = getLocalFishingBiomeId()
	if biomeId ~= lastFishingBiomeId then
		lastFishingBiomeId = biomeId
		renderContent()
	end
end)
