print("FishingClient started")

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
local OpenAquariumHub = Remotes:WaitForChild("OpenAquariumHub", 10)
local AquariumAction = Remotes:WaitForChild("AquariumAction")
local ToggleAutoFish = Remotes:WaitForChild("ToggleAutoFish")
local StateUpdated = Remotes:WaitForChild("StateUpdated")
local FishingPrompt = Remotes:WaitForChild("FishingPrompt")
local Notice = Remotes:WaitForChild("Notice")
local GetState = Remotes:WaitForChild("GetState")

local RemoteActions = require(script:WaitForChild("RemoteActions"))
local PanelMarkers = require(script:WaitForChild("PanelMarkers"))
local PlayerGuiDebug = require(script:WaitForChild("PlayerGuiDebug"))
local LegacyRightUiCleanup = require(script:WaitForChild("LegacyRightUiCleanup"))
local IslandState = require(script:WaitForChild("IslandState"))
local GuiPrimitives = require(script:WaitForChild("GuiPrimitives"))
local BaitHelpers = require(script:WaitForChild("BaitHelpers"))
local QuestHelpers = require(script:WaitForChild("QuestHelpers"))
local LeaderboardHelpers = require(script:WaitForChild("LeaderboardHelpers"))

local remoteActions = RemoteActions.create({
	Remotes = Remotes,
	BaitAction = BaitAction,
	QuestAction = QuestAction,
	ShopAction = ShopAction,
})
local fireBaitAction = remoteActions.fireBaitAction
local fireQuestAction = remoteActions.fireQuestAction
local fireShopAction = remoteActions.fireShopAction

local screenGui = script.Parent
screenGui.Enabled = true
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 100
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local panelMarkers = PanelMarkers.setup(screenGui)
local openPanelEvent = panelMarkers.openPanelEvent

local pendingPanelRequests = {}
local openFishingPanelRequest = nil
openPanelEvent.Event:Connect(function(tabName)
	if openFishingPanelRequest then
		openFishingPanelRequest(tabName)
	else
		table.insert(pendingPanelRequests, tabName)
	end
end)

local playerGui = player:WaitForChild("PlayerGui")

local playerGuiDebug = PlayerGuiDebug.create({
	playerGui = playerGui,
	screenGui = screenGui,
})
local printPlayerGuiChildren = playerGuiDebug.printPlayerGuiChildren
local printFishingGuiChildren = playerGuiDebug.printFishingGuiChildren
local printPlayerGuiScreenGuis = playerGuiDebug.printPlayerGuiScreenGuis

local legacyRightUiCleanup = LegacyRightUiCleanup.create({
	scriptFullName = script:GetFullName(),
})
local disableLegacyRightUi = legacyRightUiCleanup.disableLegacyRightUi
local watchLegacyAquariumViewerTools = legacyRightUiCleanup.watchLegacyAquariumViewerTools

for _, gui in ipairs(playerGui:GetChildren()) do
	disableLegacyRightUi(gui)
end
playerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") then
		task.defer(printPlayerGuiScreenGuis, "added " .. child.Name)
		task.defer(disableLegacyRightUi, child)
	end
end)
task.defer(printPlayerGuiScreenGuis, "initial")
task.defer(printPlayerGuiChildren)
task.defer(printFishingGuiChildren)
legacyRightUiCleanup.printOldRightUiDisabled()

task.defer(function()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
end)

local state = nil
local activeTab = "Fishdex"
local activeQuestPeriod = "Daily"
local activeShopTab = "Passes"
local fishingBusy = false
local minigameRunning = false
local activeMinigameCleanup = nil
local biomeWarpActualBiome = nil
local panelCollapsed = true
local lastFishingBiomeId = nil
local DEFAULT_FISHING_ISLAND_ID = (GameConfig.IslandOrder and GameConfig.IslandOrder[1])
	or (GameConfig.BiomeOrder and GameConfig.BiomeOrder[1])
	or "LilyshoreIsland"

local islandState = IslandState.create({
	GameConfig = GameConfig,
	getState = function()
		return state
	end,
})
local normalizeIslandId = islandState.normalizeIslandId
local getUnlockedIslands = islandState.getUnlockedIslands
local getCurrentIslandId = islandState.getCurrentIslandId
local getActualIslandId = islandState.getActualIslandId

local fishingBlur = Lighting:FindFirstChild("FishyFishUiBlur")
if not fishingBlur then
	fishingBlur = Instance.new("BlurEffect")
	fishingBlur.Name = "FishyFishUiBlur"
	fishingBlur.Parent = Lighting
end
fishingBlur.Enabled = false
fishingBlur.Size = 0

local guiPrimitives = GuiPrimitives.create({
	GameConfig = GameConfig,
})
local clearChildren = guiPrimitives.clearChildren
local addCorner = guiPrimitives.addCorner
local addStroke = guiPrimitives.addStroke
local addGradient = guiPrimitives.addGradient
local setCornerRadius = guiPrimitives.setCornerRadius
local styleOutlinedText = guiPrimitives.styleOutlinedText
local forcePureWhiteText = guiPrimitives.forcePureWhiteText
local limitTextSize = guiPrimitives.limitTextSize
local addGloss = guiPrimitives.addGloss
local makeText = guiPrimitives.makeText
local makeButton = guiPrimitives.makeButton
local makeFishIcon = guiPrimitives.makeFishIcon
local makeRodIcon = guiPrimitives.makeRodIcon

local baitHelpers = BaitHelpers.create({
	GameConfig = GameConfig,
	getState = function()
		return state
	end,
})
local getBaitData = baitHelpers.getBaitData
local getBaitCount = baitHelpers.getBaitCount
local getBaitCountText = baitHelpers.getBaitCountText
local getEquippedBaitDisplay = baitHelpers.getEquippedBaitDisplay
local getBaitEffectText = baitHelpers.getBaitEffectText
local questHelpers = QuestHelpers.create({
	GameConfig = GameConfig,
	getState = function()
		return state
	end,
})
local formatQuestReward = questHelpers.formatQuestReward
local getQuestPeriod = questHelpers.getQuestPeriod
local getPlayerLeaderstat = LeaderboardHelpers.getPlayerLeaderstat
local formatCompactNumber = LeaderboardHelpers.formatCompactNumber

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.new(1, 0, 1, 0)
root.BackgroundTransparency = 1
root.Parent = screenGui

local fishingClientModules = script.Parent:FindFirstChild("FishingClientModules")
local HudControlsModule = script:FindFirstChild("HudControls") or (fishingClientModules and fishingClientModules:FindFirstChild("HudControls"))
local ToolHotbarBinderModule = script:FindFirstChild("ToolHotbarBinder") or (fishingClientModules and fishingClientModules:FindFirstChild("ToolHotbarBinder"))
if not HudControlsModule or not ToolHotbarBinderModule then
	fishingClientModules = script.Parent:WaitForChild("FishingClientModules", 10)
	HudControlsModule = HudControlsModule or (fishingClientModules and fishingClientModules:WaitForChild("HudControls", 10))
	ToolHotbarBinderModule = ToolHotbarBinderModule or (fishingClientModules and fishingClientModules:WaitForChild("ToolHotbarBinder", 10))
end
print("FishingClient split modules:", HudControlsModule and HudControlsModule:GetFullName(), ToolHotbarBinderModule and ToolHotbarBinderModule:GetFullName())
local HudControls = require(HudControlsModule)
local ToolHotbarBinder = require(ToolHotbarBinderModule)

local hudRefs = HudControls.create({
	scriptFullName = script:GetFullName(),
	root = root,
	screenGui = screenGui,
	makeText = makeText,
	makeButton = makeButton,
	addCorner = addCorner,
	addStroke = addStroke,
	addGradient = addGradient,
	setCornerRadius = setCornerRadius,
	limitTextSize = limitTextSize,
	forcePureWhiteText = forcePureWhiteText,
	addGloss = addGloss,
	maxLevel = GameConfig.MAX_LEVEL,
})

task.defer(printPlayerGuiChildren)
task.defer(printFishingGuiChildren)

local statusText = hudRefs.statusText
local updateCoinsHud = hudRefs.updateCoins
local updateXPHud = hudRefs.updateXP
local hudControls = {
	settings = hudRefs.settingsButton,
	quests = hudRefs.questsButton,
	shop = hudRefs.shopButton,
}
local setSettingsVisible = hudRefs.setSettingsVisible
local centerControls = hudRefs.centerControls
local centerTitle = hudRefs.centerTitle
local centerBaitText = hudRefs.centerBaitText
local centerAutoButton = hudRefs.centerAutoButton
local centerAutoGradient = hudRefs.centerAutoGradient
local centerCastButton = hudRefs.centerCastButton

local biomeWarpUI = {}
biomeWarpUI.biomeWarpOverlay = Instance.new("Frame")
biomeWarpUI.biomeWarpOverlay.Name = "BiomeWarpOverlay"
biomeWarpUI.biomeWarpOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
biomeWarpUI.biomeWarpOverlay.BackgroundTransparency = 0.35
biomeWarpUI.biomeWarpOverlay.Size = UDim2.fromScale(1, 1)
biomeWarpUI.biomeWarpOverlay.Visible = false
biomeWarpUI.biomeWarpOverlay.ZIndex = 90
biomeWarpUI.biomeWarpOverlay.Parent = root

biomeWarpUI.biomeWarpPanel = Instance.new("Frame")
biomeWarpUI.biomeWarpPanel.Name = "BiomeWarpPanel"
biomeWarpUI.biomeWarpPanel.AnchorPoint = Vector2.new(0.5, 0.5)
biomeWarpUI.biomeWarpPanel.BackgroundColor3 = Color3.fromRGB(17, 24, 34)
biomeWarpUI.biomeWarpPanel.Position = UDim2.fromScale(0.5, 0.5)
biomeWarpUI.biomeWarpPanel.Size = UDim2.new(0, 430, 0, 420)
biomeWarpUI.biomeWarpPanel.ZIndex = 91
biomeWarpUI.biomeWarpPanel.Parent = biomeWarpUI.biomeWarpOverlay
addCorner(biomeWarpUI.biomeWarpPanel, 8)
addStroke(biomeWarpUI.biomeWarpPanel, Color3.fromRGB(74, 95, 124), 1)

biomeWarpUI.biomeWarpTitle = makeText(biomeWarpUI.biomeWarpPanel, "Island Warp", 20, Color3.fromRGB(255, 255, 255), true)
biomeWarpUI.biomeWarpTitle.Position = UDim2.new(0, 18, 0, 12)
biomeWarpUI.biomeWarpTitle.Size = UDim2.new(1, -72, 0, 28)
biomeWarpUI.biomeWarpTitle.ZIndex = 92

biomeWarpUI.biomeWarpClose = makeButton(biomeWarpUI.biomeWarpPanel, "X", Color3.fromRGB(91, 104, 124))
biomeWarpUI.biomeWarpClose.Position = UDim2.new(1, -48, 0, 12)
biomeWarpUI.biomeWarpClose.Size = UDim2.new(0, 32, 0, 28)
biomeWarpUI.biomeWarpClose.TextSize = 14
biomeWarpUI.biomeWarpClose.ZIndex = 92

biomeWarpUI.biomeWarpList = Instance.new("Frame")
biomeWarpUI.biomeWarpList.Name = "BiomeWarpList"
biomeWarpUI.biomeWarpList.BackgroundTransparency = 1
biomeWarpUI.biomeWarpList.Position = UDim2.new(0, 16, 0, 54)
biomeWarpUI.biomeWarpList.Size = UDim2.new(1, -32, 1, -70)
biomeWarpUI.biomeWarpList.ZIndex = 92
biomeWarpUI.biomeWarpList.Parent = biomeWarpUI.biomeWarpPanel

biomeWarpUI.biomeWarpListLayout = Instance.new("UIListLayout")
biomeWarpUI.biomeWarpListLayout.Padding = UDim.new(0, 10)
biomeWarpUI.biomeWarpListLayout.SortOrder = Enum.SortOrder.LayoutOrder
biomeWarpUI.biomeWarpListLayout.Parent = biomeWarpUI.biomeWarpList

local function setBiomeWarpVisible(visible)
	biomeWarpUI.biomeWarpOverlay.Visible = visible
end

local function renderBiomeWarpOptions()
	clearChildren(biomeWarpUI.biomeWarpList)

	if not state then
		return
	end

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		local unlocked = getUnlockedIslands()[biomeId] == true
		local current = normalizeIslandId(biomeWarpActualBiome) == biomeId
		local card = Instance.new("Frame")
		card.Name = biomeId .. "WarpOption"
		card.BackgroundColor3 = Color3.fromRGB(24, 32, 44)
		card.Size = UDim2.new(1, 0, 0, 92)
		card.ZIndex = 92
		card.Parent = biomeWarpUI.biomeWarpList
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

biomeWarpUI.biomeWarpClose.MouseButton1Click:Connect(function()
	setBiomeWarpVisible(false)
end)

if OpenBiomeWarp then
	OpenBiomeWarp.OnClientEvent:Connect(openBiomeWarp)
else
	warn("OpenBiomeWarp remote was not available; island warp popup is disabled until remotes resync.")
end

local fishmongerUI = {}
fishmongerUI.fishmongerOverlay = Instance.new("Frame")
fishmongerUI.fishmongerOverlay.Name = "FishmongerSellOverlay"
fishmongerUI.fishmongerOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
fishmongerUI.fishmongerOverlay.BackgroundTransparency = 0.35
fishmongerUI.fishmongerOverlay.Size = UDim2.fromScale(1, 1)
fishmongerUI.fishmongerOverlay.Visible = false
fishmongerUI.fishmongerOverlay.ZIndex = 95
fishmongerUI.fishmongerOverlay.Parent = root

local activeFishmongerSort = "Recent"

fishmongerUI.fishmongerPanel = Instance.new("Frame")
fishmongerUI.fishmongerPanel.Name = "FishmongerSellPanel"
fishmongerUI.fishmongerPanel.AnchorPoint = Vector2.new(0.5, 0.5)
fishmongerUI.fishmongerPanel.BackgroundColor3 = Color3.fromRGB(17, 24, 34)
fishmongerUI.fishmongerPanel.Position = UDim2.fromScale(0.5, 0.5)
fishmongerUI.fishmongerPanel.Size = UDim2.new(0, 460, 0, 460)
fishmongerUI.fishmongerPanel.ZIndex = 96
fishmongerUI.fishmongerPanel.Parent = fishmongerUI.fishmongerOverlay
addCorner(fishmongerUI.fishmongerPanel, 8)
addStroke(fishmongerUI.fishmongerPanel, Color3.fromRGB(108, 78, 48), 1)

fishmongerUI.fishmongerTitle = makeText(fishmongerUI.fishmongerPanel, "Sell Fish", 20, Color3.fromRGB(255, 255, 255), true)
fishmongerUI.fishmongerTitle.Position = UDim2.new(0, 18, 0, 12)
fishmongerUI.fishmongerTitle.Size = UDim2.new(1, -176, 0, 28)
fishmongerUI.fishmongerTitle.ZIndex = 97

fishmongerUI.fishmongerSellAll = makeButton(fishmongerUI.fishmongerPanel, "Sell All", Color3.fromRGB(230, 126, 48))
fishmongerUI.fishmongerSellAll.Position = UDim2.new(1, -146, 0, 12)
fishmongerUI.fishmongerSellAll.Size = UDim2.new(0, 90, 0, 28)
fishmongerUI.fishmongerSellAll.TextSize = 13
fishmongerUI.fishmongerSellAll.ZIndex = 97

fishmongerUI.fishmongerClose = makeButton(fishmongerUI.fishmongerPanel, "X", Color3.fromRGB(91, 104, 124))
fishmongerUI.fishmongerClose.Position = UDim2.new(1, -48, 0, 12)
fishmongerUI.fishmongerClose.Size = UDim2.new(0, 32, 0, 28)
fishmongerUI.fishmongerClose.TextSize = 14
fishmongerUI.fishmongerClose.ZIndex = 97

fishmongerUI.fishmongerSortBar = Instance.new("Frame")
fishmongerUI.fishmongerSortBar.Name = "FishmongerSortBar"
fishmongerUI.fishmongerSortBar.Position = UDim2.new(0, 16, 0, 52)
fishmongerUI.fishmongerSortBar.Size = UDim2.new(1, -32, 0, 34)
fishmongerUI.fishmongerSortBar.BackgroundTransparency = 1
fishmongerUI.fishmongerSortBar.ZIndex = 97
fishmongerUI.fishmongerSortBar.Parent = fishmongerUI.fishmongerPanel

fishmongerUI.fishmongerSortLayout = Instance.new("UIListLayout")
fishmongerUI.fishmongerSortLayout.FillDirection = Enum.FillDirection.Horizontal
fishmongerUI.fishmongerSortLayout.Padding = UDim.new(0, 7)
fishmongerUI.fishmongerSortLayout.SortOrder = Enum.SortOrder.LayoutOrder
fishmongerUI.fishmongerSortLayout.Parent = fishmongerUI.fishmongerSortBar

fishmongerUI.fishmongerList = Instance.new("ScrollingFrame")
fishmongerUI.fishmongerList.Name = "FishmongerSellList"
fishmongerUI.fishmongerList.Active = true
fishmongerUI.fishmongerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
fishmongerUI.fishmongerList.BackgroundTransparency = 1
fishmongerUI.fishmongerList.BorderSizePixel = 0
fishmongerUI.fishmongerList.CanvasSize = UDim2.new(0, 0, 0, 0)
fishmongerUI.fishmongerList.Position = UDim2.new(0, 16, 0, 94)
fishmongerUI.fishmongerList.ScrollBarThickness = 6
fishmongerUI.fishmongerList.Size = UDim2.new(1, -32, 1, -110)
fishmongerUI.fishmongerList.ZIndex = 97
fishmongerUI.fishmongerList.Parent = fishmongerUI.fishmongerPanel

fishmongerUI.fishmongerListLayout = Instance.new("UIListLayout")
fishmongerUI.fishmongerListLayout.Padding = UDim.new(0, 10)
fishmongerUI.fishmongerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
fishmongerUI.fishmongerListLayout.Parent = fishmongerUI.fishmongerList

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
	fishmongerUI.fishmongerOverlay.Visible = visible
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
	clearChildren(fishmongerUI.fishmongerSortBar)

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

		local button = makeButton(fishmongerUI.fishmongerSortBar, label, selected and Color3.fromRGB(230, 126, 48) or Color3.fromRGB(38, 45, 57))
		button.Size = UDim2.new(0, 132, 1, 0)
		button.TextSize = 13
		button.ZIndex = 98
		button.MouseButton1Click:Connect(function()
			if activeFishmongerSort == descendingId then
				activeFishmongerSort = ascendingId
			else
				activeFishmongerSort = descendingId
			end
			fishmongerUI.fishmongerList.CanvasPosition = Vector2.new(0, 0)
			renderFishmongerSellOptions()
		end)
	end
end

function renderFishmongerSellOptions()
	renderFishmongerSortButtons()
	clearChildren(fishmongerUI.fishmongerList)

	if not state then
		fishmongerUI.fishmongerSellAll.Visible = false
		return
	end

	fishmongerUI.fishmongerSellAll.Visible = #state.Inventory > 0

	if #state.Inventory == 0 then
		local empty = makeText(fishmongerUI.fishmongerList, "No fish in your bag.", 16, Color3.fromRGB(190, 204, 220), true)
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

		local card = makePopupListCard(fishmongerUI.fishmongerList, "SellOption_" .. tostring(fish.serial or index), 82, color, 0.25)

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

fishmongerUI.fishmongerClose.MouseButton1Click:Connect(function()
	setFishmongerSellVisible(false)
end)

fishmongerUI.fishmongerSellAll.MouseButton1Click:Connect(function()
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
		local requiredIsland = normalizeIslandId(rod.requiredBiome)
		text ..= " | Requires " .. GameConfig.Biomes[requiredIsland].displayName
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
		local requiredIsland = normalizeIslandId(rod.requiredBiome)
		local biomeOK = not requiredIsland or getUnlockedIslands()[requiredIsland] == true
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
			statusText = "Unlock " .. GameConfig.Biomes[requiredIsland].displayName .. " first."
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

local mainPanelUI = {}
mainPanelUI.panel = Instance.new("Frame")
mainPanelUI.panel.Name = "MainPanel"
mainPanelUI.panel.AnchorPoint = Vector2.new(0.5, 0.5)
mainPanelUI.panel.Position = UDim2.fromScale(0.5, 0.52)
mainPanelUI.panel.Size = UDim2.new(0.42, 0, 0.64, 0)
mainPanelUI.panel.BackgroundColor3 = Color3.fromRGB(18, 22, 29)
mainPanelUI.panel.BackgroundTransparency = 0.04
mainPanelUI.panel.Visible = false
mainPanelUI.panel.ZIndex = 50
mainPanelUI.panel.Parent = root
addCorner(mainPanelUI.panel, 8)
addStroke(mainPanelUI.panel, Color3.fromRGB(71, 85, 105), 1)

mainPanelUI.panelConstraint = Instance.new("UISizeConstraint")
mainPanelUI.panelConstraint.MinSize = Vector2.new(330, 360)
mainPanelUI.panelConstraint.MaxSize = Vector2.new(560, 580)
mainPanelUI.panelConstraint.Parent = mainPanelUI.panel

mainPanelUI.panelTitle = makeText(mainPanelUI.panel, "Fishdex", 20, Color3.fromRGB(255, 255, 255), true)
mainPanelUI.panelTitle.Position = UDim2.new(0, 18, 0, 12)
mainPanelUI.panelTitle.Size = UDim2.new(1, -86, 0, 30)
mainPanelUI.panelTitle.ZIndex = 51

mainPanelUI.panelClose = makeButton(mainPanelUI.panel, "X", Color3.fromRGB(91, 104, 124))
mainPanelUI.panelClose.Position = UDim2.new(1, -50, 0, 12)
mainPanelUI.panelClose.Size = UDim2.new(0, 32, 0, 30)
mainPanelUI.panelClose.ZIndex = 51

mainPanelUI.panelToggle = makeButton(root, ">", Color3.fromRGB(38, 45, 57))
mainPanelUI.panelToggle.Name = "PanelToggle"
mainPanelUI.panelToggle.Visible = false
mainPanelUI.panelToggle.ZIndex = 30

local function updatePanelCollapsed()
	mainPanelUI.panel.Visible = not panelCollapsed
	mainPanelUI.panelToggle.Visible = false
end

mainPanelUI.panelClose.MouseButton1Click:Connect(function()
	panelCollapsed = true
	updatePanelCollapsed()
end)

updatePanelCollapsed()

mainPanelUI.tabs = Instance.new("Frame")
mainPanelUI.tabs.Name = "Tabs"
mainPanelUI.tabs.Position = UDim2.new(0, 12, 0, 12)
mainPanelUI.tabs.Size = UDim2.new(1, -24, 0, 0)
mainPanelUI.tabs.BackgroundTransparency = 1
mainPanelUI.tabs.Visible = false
mainPanelUI.tabs.Parent = mainPanelUI.panel

mainPanelUI.tabGrid = Instance.new("UIGridLayout")
mainPanelUI.tabGrid.CellSize = UDim2.new(0, 96, 0, 32)
mainPanelUI.tabGrid.CellPadding = UDim2.new(0, 7, 0, 7)
mainPanelUI.tabGrid.SortOrder = Enum.SortOrder.LayoutOrder
mainPanelUI.tabGrid.Parent = mainPanelUI.tabs

mainPanelUI.content = Instance.new("ScrollingFrame")
mainPanelUI.content.Name = "Content"
mainPanelUI.content.Position = UDim2.new(0, 12, 0, 54)
mainPanelUI.content.Size = UDim2.new(1, -24, 1, -66)
mainPanelUI.content.BackgroundTransparency = 1
mainPanelUI.content.ScrollBarThickness = 6
mainPanelUI.content.CanvasSize = UDim2.new(0, 0, 0, 0)
mainPanelUI.content.AutomaticCanvasSize = Enum.AutomaticSize.Y
mainPanelUI.content.ZIndex = 51
mainPanelUI.content.Parent = mainPanelUI.panel

mainPanelUI.contentLayout = Instance.new("UIListLayout")
mainPanelUI.contentLayout.Padding = UDim.new(0, 8)
mainPanelUI.contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainPanelUI.contentLayout.Parent = mainPanelUI.content

local minigameUI = {}
minigameUI.minigame = Instance.new("Frame")
minigameUI.minigame.Name = "FishingMinigame"
minigameUI.minigame.AnchorPoint = Vector2.new(0.5, 0.5)
minigameUI.minigame.Position = UDim2.new(0.5, 0, 0.48, 0)
minigameUI.minigame.Size = UDim2.new(0, 540, 0, 520)
minigameUI.minigame.BackgroundColor3 = Color3.fromRGB(10, 68, 155)
minigameUI.minigame.Visible = false
minigameUI.minigame.ZIndex = 40
minigameUI.minigame.Parent = root
addCorner(minigameUI.minigame, 30)
addStroke(minigameUI.minigame, Color3.fromRGB(0, 78, 190), 7)
addStroke(minigameUI.minigame, Color3.fromRGB(99, 210, 255), 2).Transparency = 0.08
addGradient(minigameUI.minigame, Color3.fromRGB(18, 92, 198), Color3.fromRGB(7, 52, 132), 90)

minigameUI.minigameConstraint = Instance.new("UISizeConstraint")
minigameUI.minigameConstraint.MinSize = Vector2.new(500, 450)
minigameUI.minigameConstraint.MaxSize = Vector2.new(620, 560)
minigameUI.minigameConstraint.Parent = minigameUI.minigame

minigameUI.minigameInner = Instance.new("Frame")
minigameUI.minigameInner.Name = "InnerStroke"
minigameUI.minigameInner.Position = UDim2.new(0, 14, 0, 14)
minigameUI.minigameInner.Size = UDim2.new(1, -28, 1, -28)
minigameUI.minigameInner.BackgroundTransparency = 1
minigameUI.minigameInner.ZIndex = 41
minigameUI.minigameInner.Parent = minigameUI.minigame
addCorner(minigameUI.minigameInner, 26)
addStroke(minigameUI.minigameInner, Color3.fromRGB(91, 193, 255), 2).Transparency = 0.38
addGloss(minigameUI.minigame, UDim2.new(0, 22, 0, 18), UDim2.new(0, 90, 0, 12))

minigameUI.minigameText = makeText(minigameUI.minigame, "Wait for a bite...", 18, Color3.fromRGB(255, 255, 255), true)
minigameUI.minigameText.Position = UDim2.new(0, 40, 0, 24)
minigameUI.minigameText.Size = UDim2.new(1, -80, 0, 44)
minigameUI.minigameText.ZIndex = 44
styleOutlinedText(minigameUI.minigameText, 36)
minigameUI.minigameText.TextScaled = true
forcePureWhiteText(minigameUI.minigameText)

minigameUI.minigameTextSizeConstraint = Instance.new("UITextSizeConstraint")
minigameUI.minigameTextSizeConstraint.MinTextSize = 16
minigameUI.minigameTextSizeConstraint.MaxTextSize = 24
minigameUI.minigameTextSizeConstraint.Parent = minigameUI.minigameText

minigameUI.timingBar = Instance.new("Frame")
minigameUI.timingBar.Name = "Bar"
minigameUI.timingBar.Position = UDim2.new(0, 40, 0, 86)
minigameUI.timingBar.Size = UDim2.new(1, -80, 0, 44)
minigameUI.timingBar.BackgroundColor3 = Color3.fromRGB(57, 99, 150)
minigameUI.timingBar.ZIndex = 43
minigameUI.timingBar.Parent = minigameUI.minigame
minigameUI.timingBar.Visible = false
addCorner(minigameUI.timingBar, 24)
addStroke(minigameUI.timingBar, Color3.fromRGB(7, 52, 121), 5)
addStroke(minigameUI.timingBar, Color3.fromRGB(147, 178, 212), 2).Transparency = 0.22
addGradient(minigameUI.timingBar, Color3.fromRGB(92, 132, 181), Color3.fromRGB(48, 88, 143), 90)

minigameUI.zone = Instance.new("Frame")
minigameUI.zone.Name = "Zone"
minigameUI.zone.BackgroundColor3 = Color3.fromRGB(30, 231, 53)
minigameUI.zone.Size = UDim2.new(0.22, 0, 1, 0)
minigameUI.zone.Position = UDim2.new(0.39, 0, 0, 0)
minigameUI.zone.ZIndex = 44
minigameUI.zone.Parent = minigameUI.timingBar
minigameUI.zone.Visible = false
addCorner(minigameUI.zone, 16)
addStroke(minigameUI.zone, Color3.fromRGB(3, 96, 19), 4)
addGradient(minigameUI.zone, Color3.fromRGB(104, 255, 81), Color3.fromRGB(16, 194, 38), 90)
addGloss(minigameUI.zone, UDim2.new(0, 14, 0, 8), UDim2.new(0, 66, 0, 9))

minigameUI.marker = Instance.new("Frame")
minigameUI.marker.Name = "Marker"
minigameUI.marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
minigameUI.marker.Size = UDim2.new(0, 16, 1, 28)
minigameUI.marker.Position = UDim2.new(0, 0, 0, -14)
minigameUI.marker.ZIndex = 45
minigameUI.marker.Parent = minigameUI.timingBar
minigameUI.marker.Visible = false
addCorner(minigameUI.marker, 9)
addStroke(minigameUI.marker, Color3.fromRGB(7, 55, 128), 3)

minigameUI.catchButton = makeButton(minigameUI.minigame, "", Color3.fromRGB(28, 160, 92))
minigameUI.catchButton.AnchorPoint = Vector2.new(0.5, 1)
minigameUI.catchButton.Position = UDim2.new(0.5, 0, 1, -18)
minigameUI.catchButton.Size = UDim2.new(0.29, 0, 0, 52)
minigameUI.catchButton.ZIndex = 44
minigameUI.catchButton.Visible = false
minigameUI.catchButton.Active = false
minigameUI.catchButton.AutoButtonColor = false
styleOutlinedText(minigameUI.catchButton, 34)
minigameUI.catchButton.TextScaled = true
limitTextSize(minigameUI.catchButton, 15, 24)
forcePureWhiteText(minigameUI.catchButton)
setCornerRadius(minigameUI.catchButton, 24)
addStroke(minigameUI.catchButton, Color3.fromRGB(0, 92, 18), 7)
addGradient(minigameUI.catchButton, Color3.fromRGB(104, 255, 91), Color3.fromRGB(17, 196, 38), 90)
addGloss(minigameUI.catchButton, UDim2.new(0, 22, 0, 13), UDim2.new(0, 90, 0, 12))

minigameUI.fishingGameContent = Instance.new("Frame")
minigameUI.fishingGameContent.Name = "FishingGameContent"
minigameUI.fishingGameContent.Position = UDim2.new(0, 34, 0, 82)
minigameUI.fishingGameContent.Size = UDim2.new(1, -68, 1, -106)
minigameUI.fishingGameContent.BackgroundTransparency = 1
minigameUI.fishingGameContent.ZIndex = 44
minigameUI.fishingGameContent.Parent = minigameUI.minigame

minigameUI.verticalPanel = Instance.new("Frame")
minigameUI.verticalPanel.Name = "VerticalFishingPanel"
minigameUI.verticalPanel.Position = UDim2.new(0, 18, 0, 0)
minigameUI.verticalPanel.Size = UDim2.new(0, 180, 1, -58)
minigameUI.verticalPanel.BackgroundColor3 = Color3.fromRGB(31, 95, 156)
minigameUI.verticalPanel.ZIndex = 45
minigameUI.verticalPanel.Parent = minigameUI.fishingGameContent
addCorner(minigameUI.verticalPanel, 20)
addStroke(minigameUI.verticalPanel, Color3.fromRGB(7, 48, 106), 5)
addStroke(minigameUI.verticalPanel, Color3.fromRGB(126, 219, 255), 2).Transparency = 0.18
addGradient(minigameUI.verticalPanel, Color3.fromRGB(55, 154, 210), Color3.fromRGB(18, 71, 140), 90)

minigameUI.panelWater = Instance.new("Frame")
minigameUI.panelWater.Name = "Water"
minigameUI.panelWater.Position = UDim2.new(0, 14, 0, 14)
minigameUI.panelWater.Size = UDim2.new(1, -28, 1, -28)
minigameUI.panelWater.BackgroundColor3 = Color3.fromRGB(28, 135, 204)
minigameUI.panelWater.ZIndex = 46
minigameUI.panelWater.Parent = minigameUI.verticalPanel
addCorner(minigameUI.panelWater, 16)
addStroke(minigameUI.panelWater, Color3.fromRGB(12, 68, 128), 2).Transparency = 0.2
addGradient(minigameUI.panelWater, Color3.fromRGB(70, 190, 230), Color3.fromRGB(17, 98, 177), 90)

minigameUI.catchBar = Instance.new("Frame")
minigameUI.catchBar.Name = "CatchBar"
minigameUI.catchBar.AnchorPoint = Vector2.new(0.5, 0)
minigameUI.catchBar.Position = UDim2.new(0.5, 0, 0.68, 0)
minigameUI.catchBar.Size = UDim2.new(1, -32, 0.24, 0)
minigameUI.catchBar.BackgroundColor3 = Color3.fromRGB(43, 225, 70)
minigameUI.catchBar.ZIndex = 48
minigameUI.catchBar.Parent = minigameUI.panelWater
addCorner(minigameUI.catchBar, 14)
addStroke(minigameUI.catchBar, Color3.fromRGB(8, 94, 24), 3)
addGradient(minigameUI.catchBar, Color3.fromRGB(111, 255, 94), Color3.fromRGB(20, 177, 46), 90)
addGloss(minigameUI.catchBar, UDim2.new(0, 12, 0, 7), UDim2.new(0, 54, 0, 8))

minigameUI.fishMarker = Instance.new("Frame")
minigameUI.fishMarker.Name = "FishMarker"
minigameUI.fishMarker.AnchorPoint = Vector2.new(0.5, 0.5)
minigameUI.fishMarker.Position = UDim2.new(0.5, 0, 0.5, 0)
minigameUI.fishMarker.Size = UDim2.new(0, 46, 0, 46)
minigameUI.fishMarker.BackgroundColor3 = Color3.fromRGB(17, 28, 43)
minigameUI.fishMarker.ZIndex = 50
minigameUI.fishMarker.Parent = minigameUI.panelWater
addCorner(minigameUI.fishMarker, 23)
addStroke(minigameUI.fishMarker, Color3.fromRGB(255, 255, 255), 2).Transparency = 0.08

minigameUI.fishMarkerImage = Instance.new("ImageLabel")
minigameUI.fishMarkerImage.Name = "FishImage"
minigameUI.fishMarkerImage.BackgroundTransparency = 1
minigameUI.fishMarkerImage.Position = UDim2.new(0, 5, 0, 5)
minigameUI.fishMarkerImage.Size = UDim2.new(1, -10, 1, -10)
minigameUI.fishMarkerImage.ScaleType = Enum.ScaleType.Fit
minigameUI.fishMarkerImage.ZIndex = 51
minigameUI.fishMarkerImage.Parent = minigameUI.fishMarker

minigameUI.fishMarkerLabel = makeText(minigameUI.fishMarker, "FISH", 11, Color3.fromRGB(255, 255, 255), true)
minigameUI.fishMarkerLabel.Position = UDim2.fromScale(0, 0)
minigameUI.fishMarkerLabel.Size = UDim2.fromScale(1, 1)
minigameUI.fishMarkerLabel.TextXAlignment = Enum.TextXAlignment.Center
minigameUI.fishMarkerLabel.ZIndex = 52
styleOutlinedText(minigameUI.fishMarkerLabel, 11)
forcePureWhiteText(minigameUI.fishMarkerLabel)

minigameUI.progressTrack = Instance.new("Frame")
minigameUI.progressTrack.Name = "ProgressTrack"
minigameUI.progressTrack.Position = UDim2.new(0, 226, 0, 0)
minigameUI.progressTrack.Size = UDim2.new(0, 42, 1, -58)
minigameUI.progressTrack.BackgroundColor3 = Color3.fromRGB(29, 35, 46)
minigameUI.progressTrack.ZIndex = 45
minigameUI.progressTrack.Parent = minigameUI.fishingGameContent
addCorner(minigameUI.progressTrack, 16)
addStroke(minigameUI.progressTrack, Color3.fromRGB(92, 111, 138), 2)

minigameUI.progressFill = Instance.new("Frame")
minigameUI.progressFill.Name = "ProgressFill"
minigameUI.progressFill.AnchorPoint = Vector2.new(0, 1)
minigameUI.progressFill.Position = UDim2.new(0, 0, 1, 0)
minigameUI.progressFill.Size = UDim2.new(1, 0, 0.34, 0)
minigameUI.progressFill.BackgroundColor3 = Color3.fromRGB(62, 190, 255)
minigameUI.progressFill.ZIndex = 46
minigameUI.progressFill.Parent = minigameUI.progressTrack
addCorner(minigameUI.progressFill, 16)
addGradient(minigameUI.progressFill, Color3.fromRGB(130, 235, 255), Color3.fromRGB(26, 132, 255), 90)

minigameUI.minigameFishInfo = makeText(minigameUI.fishingGameContent, "Fish", 18, Color3.fromRGB(255, 255, 255), true)
minigameUI.minigameFishInfo.Position = UDim2.new(0, 296, 0, 18)
minigameUI.minigameFishInfo.Size = UDim2.new(1, -306, 0, 46)
minigameUI.minigameFishInfo.ZIndex = 45
minigameUI.minigameFishInfo.TextWrapped = true
styleOutlinedText(minigameUI.minigameFishInfo, 18)
forcePureWhiteText(minigameUI.minigameFishInfo)

minigameUI.minigameProgressText = makeText(minigameUI.fishingGameContent, "Progress 34%", 15, Color3.fromRGB(210, 230, 255), true)
minigameUI.minigameProgressText.Position = UDim2.new(0, 296, 0, 76)
minigameUI.minigameProgressText.Size = UDim2.new(1, -306, 0, 30)
minigameUI.minigameProgressText.ZIndex = 45

minigameUI.minigameInstruction = makeText(minigameUI.fishingGameContent, "Hold mouse, tap, or Space to lift the green bar.", 14, Color3.fromRGB(210, 230, 255), false)
minigameUI.minigameInstruction.Position = UDim2.new(0, 296, 0, 116)
minigameUI.minigameInstruction.Size = UDim2.new(1, -306, 0, 70)
minigameUI.minigameInstruction.TextWrapped = true
minigameUI.minigameInstruction.ZIndex = 45

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
CastPower.content.Parent = minigameUI.minigame

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
		CastPower.status.Text = "Aim for the green perfect minigameUI.zone."
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
		minigameUI.fishMarkerImage.Image = imageId
		minigameUI.fishMarkerImage.Visible = true
		minigameUI.fishMarkerLabel.Visible = false
	else
		minigameUI.fishMarkerImage.Image = ""
		minigameUI.fishMarkerImage.Visible = false
		minigameUI.fishMarkerLabel.Visible = true
	end
end

local function setMinigameVisible(visible)
	minigameUI.minigame.Visible = visible
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
		updateCoinsHud(0)
		updateXPHud(nil)
		return
	end

	updateCoinsHud(state.Coins)
	updateXPHud(state)
end

local renderContent

local function isLilyshoreIslandInstance(instance)
	while instance do
		if instance.Name == "LilyshoreIsland"
			or instance.Name == "LilyshoreFishingZone"
			or instance.Name == "BeginnerPondArea"
			or instance.Name == "BeginnerPond_ExtraLarge"
			or instance.Name == "Beginner Pond"
		then
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
	if result and isLilyshoreIslandInstance(result.Instance) then
		return DEFAULT_FISHING_ISLAND_ID
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
		if biomeId == DEFAULT_FISHING_ISLAND_ID then
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

	local actualIslandId = getActualIslandId()
	if not actualIslandId or not GameConfig.Biomes[actualIslandId] then
		return nil
	end

	return actualIslandId
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

	return (state and normalizeIslandId(state.ActualLocation)) or "Lobby"
end

local function isHoldingFishingRod()
	local character = player.Character
	local tool = character and character:FindFirstChild("Fishing Rod")
	return tool ~= nil and tool:IsA("Tool")
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
	minigameUI.fishingGameContent.Visible = false
	minigameUI.catchButton.Visible = false
	minigameUI.timingBar.Visible = false
	minigameUI.zone.Visible = false
	minigameUI.marker.Visible = false

	minigameUI.minigameText.Text = "Cast into " .. ((biome and biome.displayName) or "the water")
	forcePureWhiteText(minigameUI.minigameText)
	forcePureWhiteText(minigameUI.catchButton)
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

		if not isHoldingFishingRod() then
			if activeMinigameCleanup then
				activeMinigameCleanup()
			end
			fishingBusy = false
			setMinigameVisible(false)
			showToast("Hold your fishing rod before fishing.")
			renderContent()
			return
		end

		finished = true
		disconnectAll()
		activeMinigameCleanup = nil
		CastPower.running = false
		minigameUI.fishingGameContent.Visible = false
		local rating, displayName = CastPower.getLocalRating(power)
		CastPower.title.Text = displayName .. " Cast!"
		CastPower.status.Text = "Bobber landed. Waiting for a bite..."
		minigameUI.minigameText.Text = displayName .. " Cast! Waiting for a bite..."
		forcePureWhiteText(minigameUI.minigameText)
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
	if fishingBusy or minigameRunning or not state then
		return
	end

	if not isHoldingFishingRod() then
		showToast("Hold your fishing rod before fishing.")
		return
	end

	local biomeId = getActiveFishingBiomeId()
	if not biomeId then
		showToast("Move to a fishing area first.")
		return
	end

	panelCollapsed = true
	updatePanelCollapsed()

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
	local autoEnabled = state and state.AutoFishEnabled == true

	centerControls.Visible = true
	centerTitle.Visible = false
	centerCastButton.Visible = true
	centerAutoButton.Visible = true
	centerBaitText.Visible = false
	centerCastButton.Text = fishingBusy and "Fishing..." or "Tap"
	centerCastButton.AutoButtonColor = state ~= nil and biomeId ~= nil and not fishingBusy
	centerAutoButton.Text = autoEnabled and "AutoFish ON" or "AutoFish OFF"
	centerBaitText.Text = state and getEquippedBaitDisplay() or "Bait: Basic Bait (Unlimited)"
	forcePureWhiteText(centerTitle)
	centerCastButton.TextColor3 = Color3.fromRGB(10, 20, 30)
	centerCastButton.TextStrokeTransparency = 1
	forcePureWhiteText(centerAutoButton)

	if not state or not biomeId then
		centerTitle.Text = "Lilyshore Island"
		centerAutoButton.BackgroundColor3 = Color3.fromRGB(53, 130, 246)
		centerAutoGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 191, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 126, 255)),
		})
		return
	end

	local biome = GameConfig.Biomes[biomeId]
	centerTitle.Text = biome.displayName

	if autoEnabled then
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

centerCastButton.MouseButton1Click:Connect(function()
	print("Tap clicked")
	startManualFishing()
end)

centerAutoButton.MouseButton1Click:Connect(function()
	print("AutoFish clicked")
	if state and not state.AutoFishEnabled and not isHoldingFishingRod() then
		showToast("Hold your fishing rod before turning on AutoFish.")
		return
	end
	ToggleAutoFish:FireServer()
end)

local function setTab(tabName)
	local isUtilityPanel = tabName == "Bag" or tabName == "Fishdex"
	if isUtilityPanel
		and (UserInputService:GetFocusedTextBox() ~= nil
			or fishingBusy
			or minigameRunning
			or CastPower.running)
	then
		return
	end

	if tabName == "Bag" then
		mainPanelUI.activeBagTab = "Fish"
		mainPanelUI.bagFishSort = mainPanelUI.bagFishSort or "Recently caught"
	end

	activeTab = tabName
	panelCollapsed = false
	updatePanelCollapsed()
	renderContent()
end

local function hasHudPanel(tabName)
	if tabName == "Bag" or tabName == "Fishdex" then
		local panels = screenGui:FindFirstChild("Panels")
		local namedPanel = panels and panels:FindFirstChild(tabName .. "Panel")
		return mainPanelUI.panel ~= nil or namedPanel ~= nil
	end

	return true
end

local function openFishingPanelFromHotbar(tabName)
	if tabName == "__CloseFishingPanels" then
		panelCollapsed = true
		updatePanelCollapsed()
		return
	end

	if tabName == "Bag" then
		if not hasHudPanel("Bag") then
			warn("BagPanel not found")
			return
		end

		print("Opening Bag UI")
		setTab("Bag")
	elseif tabName == "Fishdex" then
		if not hasHudPanel("Fishdex") then
			warn("FishdexPanel not found")
			return
		end

		print("Opening Fishdex UI")
		setTab("Fishdex")
	end
end

openFishingPanelRequest = openFishingPanelFromHotbar
for _, tabName in ipairs(pendingPanelRequests) do
	openFishingPanelRequest(tabName)
end
table.clear(pendingPanelRequests)

hudControls.settings.MouseButton1Click:Connect(function()
	print("Settings clicked")
	setSettingsVisible(true)
end)

hudControls.quests.MouseButton1Click:Connect(function()
	print("Quests clicked")
	setTab("Quests")
end)

hudControls.shop.MouseButton1Click:Connect(function()
	print("Shop clicked")
	setTab("Shop")
end)

ToolHotbarBinder.start({
	player = player,
	setTab = setTab,
	hasPanel = hasHudPanel,
	watchLegacyAquariumViewerTools = watchLegacyAquariumViewerTools,
})

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

local function openAquariumHub()
	print("Aquarium Viewer opened")
	print("Opening Aquarium Viewer GUI")
	panelCollapsed = false
	updatePanelCollapsed()
	setTab("Aquarium")
end

if OpenAquariumHub then
	OpenAquariumHub.OnClientEvent:Connect(openAquariumHub)
else
	warn("OpenAquariumHub remote was not available; aquarium hub kiosk is disabled until remotes resync.")
end

local AQUARIUM_HUB_CENTER = Vector3.new(6000, 0, 6000)

local function isInAquariumHub()
	if getLocalTravelLocation() == "AquariumHub" then
		return true
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - AQUARIUM_HUB_CENTER).Magnitude <= 130
end

local aquariumViewerFallbackButton = makeButton(screenGui, "Open Viewer", Color3.fromRGB(53, 130, 246))
local aquariumViewerMobileLayout = UserInputService.TouchEnabled
local aquariumViewerButtonWidth = aquariumViewerMobileLayout and 158 or 146
local aquariumViewerButtonHeight = aquariumViewerMobileLayout and 52 or 48
aquariumViewerFallbackButton.AnchorPoint = Vector2.new(1, 1)
aquariumViewerFallbackButton.Position = UDim2.new(1, -18, 1, -(34 + aquariumViewerButtonHeight))
aquariumViewerFallbackButton.Size = UDim2.fromOffset(aquariumViewerButtonWidth, aquariumViewerButtonHeight)
aquariumViewerFallbackButton.TextSize = 14
aquariumViewerFallbackButton.ZIndex = 31
aquariumViewerFallbackButton.Visible = false
aquariumViewerFallbackButton.MouseButton1Click:Connect(openAquariumHub)

local function updateAquariumViewerFallbackButton()
	local shouldShow = state ~= nil
		and isInAquariumHub()
		and not minigameRunning
		and not CastPower.running
		and not (activeTab == "Aquarium" and mainPanelUI.panel.Visible and not panelCollapsed)
	aquariumViewerFallbackButton.Visible = shouldShow
end

local function refreshTabs()
	clearChildren(mainPanelUI.tabs)
	mainPanelUI.tabs.Visible = false
end

local function renderBiomesTab()
	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		local unlocked = getUnlockedIslands()[biomeId]
		local current = getCurrentIslandId() == biomeId

		local card = makeCard(mainPanelUI.content, 96)
		local name = makeText(card, biome.displayName, 16, biome.color, true)
		name.Position = UDim2.new(0, 12, 0, 8)
		name.Size = UDim2.new(1, -132, 0, 22)

		local info = makeText(card, "Unlock Island: " .. GameConfig.getBiomeUnlockText(biomeId), 13, Color3.fromRGB(190, 204, 220), false)
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

mainPanelUI.activeBagTab = "Fish"
mainPanelUI.bagFishSort = "Recently caught"

function mainPanelUI.renderBagTabBar()
	local tabBar = Instance.new("Frame")
	tabBar.Name = "BagCategoryTabs"
	tabBar.Size = UDim2.new(1, -8, 0, 38)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = mainPanelUI.content

	local tabs = {
		{ id = "Fishing Rods", text = "Fishing Rods" },
		{ id = "Bait", text = "Bait" },
		{ id = "Fish", text = "Fish" },
	}
	for index, tab in ipairs(tabs) do
		local selected = mainPanelUI.activeBagTab == tab.id
		local button = makeButton(tabBar, tab.text, selected and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(38, 45, 57))
		button.Name = tab.id:gsub("%s", "") .. "Tab"
		button.Position = UDim2.new((index - 1) / 3, index == 1 and 0 or 4, 0, 0)
		button.Size = UDim2.new(1 / 3, -6, 1, 0)
		button.TextSize = 12
		button.MouseButton1Click:Connect(function()
			mainPanelUI.activeBagTab = tab.id
			renderContent()
		end)
	end
end

function mainPanelUI.renderBagRods()
	local ownedCount = 0
	for _, rodId in ipairs(GameConfig.RodOrder) do
		if state.OwnedRods[rodId] then
			ownedCount += 1
			local rod = GameConfig.Rods[rodId]
			local equipped = state.EquippedRod == rodId
			local card = makeCard(mainPanelUI.content, 96)
			addStroke(card, equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(60, 72, 90), 1).Transparency = equipped and 0.15 or 0.45

			local icon = makeRodIcon(card, rodId)
			icon.Position = UDim2.new(0, 8, 0, 16)
			icon.Size = UDim2.new(0, 64, 0, 64)

			local name = makeText(card, rod.displayName, 15, Color3.fromRGB(255, 255, 255), true)
			name.Position = UDim2.new(0, 84, 0, 8)
			name.Size = UDim2.new(1, -202, 0, 22)

			local barBonus = (((GameConfig.FishingMinigame or {}).RodBonuses or {})[rodId] or {}).barSizeMultiplier or 1
			local stats = string.format("Catch bar +%d%% | Luck +%d%% | Speed +%d%%", math.floor((barBonus - 1) * 100 + 0.5), math.floor((rod.luck or 0) * 100 + 0.5), math.floor((1 - (rod.speed or 1)) * 100 + 0.5))
			local info = makeText(card, stats, 11, Color3.fromRGB(190, 204, 220), false)
			info.Position = UDim2.new(0, 84, 0, 32)
			info.Size = UDim2.new(1, -202, 0, 30)
			info.TextWrapped = true

			local requirementText = equipped and "Equipped" or "Owned"
			if rod.requiredBiome then
				local requiredId = normalizeIslandId(rod.requiredBiome)
				local requiredIsland = GameConfig.Biomes[requiredId]
				requirementText ..= " | " .. ((requiredIsland and requiredIsland.displayName) or tostring(requiredId))
			end
			local status = makeText(card, requirementText, 11, equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(143, 160, 180), true)
			status.Position = UDim2.new(0, 84, 0, 67)
			status.Size = UDim2.new(1, -202, 0, 18)

			local button = makeButton(card, equipped and "Equipped" or "Equip", equipped and Color3.fromRGB(91, 104, 124) or Color3.fromRGB(53, 130, 246))
			button.Position = UDim2.new(1, -106, 0, 30)
			button.Size = UDim2.new(0, 90, 0, 36)
			button.TextSize = 12
			button.AutoButtonColor = not equipped
			button.MouseButton1Click:Connect(function()
				if not equipped then
					BuyRod:FireServer(rodId)
				end
			end)
		end
	end

	if ownedCount == 0 then
		local empty = makeText(mainPanelUI.content, "You do not own any fishing rods yet.", 14, Color3.fromRGB(190, 204, 220), false)
		empty.Size = UDim2.new(1, -8, 0, 48)
		empty.TextXAlignment = Enum.TextXAlignment.Center
	end
end

function mainPanelUI.renderBagBait()
	for _, baitId in ipairs(GameConfig.BaitOrder) do
		local bait = GameConfig.Baits[baitId]
		local count = getBaitCount(baitId)
		local equipped = state.EquippedBait == baitId
		local isBasic = baitId == GameConfig.BasicBaitId
		local canEquip = isBasic or count > 0
		local card = makeCard(mainPanelUI.content, 92)
		addStroke(card, equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(60, 72, 90), 1).Transparency = equipped and 0.15 or 0.45

		local badge = Instance.new("Frame")
		badge.Position = UDim2.new(0, 10, 0, 18)
		badge.Size = UDim2.new(0, 56, 0, 56)
		badge.BackgroundColor3 = isBasic and Color3.fromRGB(58, 174, 205) or Color3.fromRGB(53, 130, 246)
		badge.Parent = card
		addCorner(badge, 7)
		local badgeText = makeText(badge, bait.displayName:sub(1, 1), 22, Color3.fromRGB(255, 255, 255), true)
		badgeText.Size = UDim2.fromScale(1, 1)
		badgeText.TextXAlignment = Enum.TextXAlignment.Center

		local name = makeText(card, bait.displayName, 15, Color3.fromRGB(255, 255, 255), true)
		name.Position = UDim2.new(0, 78, 0, 8)
		name.Size = UDim2.new(1, -194, 0, 22)

		local effect = makeText(card, bait.description or getBaitEffectText(bait), 11, Color3.fromRGB(190, 204, 220), false)
		effect.Position = UDim2.new(0, 78, 0, 31)
		effect.Size = UDim2.new(1, -194, 0, 30)
		effect.TextWrapped = true

		local countText = isBasic and "Unlimited" or ("Quantity: " .. tostring(count))
		local detail = makeText(card, equipped and (countText .. " | Equipped") or countText, 11, equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(143, 160, 180), equipped)
		detail.Position = UDim2.new(0, 78, 0, 65)
		detail.Size = UDim2.new(1, -194, 0, 18)

		local equip = makeButton(card, equipped and "Equipped" or "Equip", equipped and Color3.fromRGB(91, 104, 124) or (canEquip and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(86, 98, 115)))
		equip.Position = UDim2.new(1, -106, 0, 28)
		equip.Size = UDim2.new(0, 90, 0, 36)
		equip.TextSize = 12
		equip.AutoButtonColor = canEquip and not equipped
		equip.MouseButton1Click:Connect(function()
			if canEquip and not equipped then
				fireBaitAction("Equip", baitId)
			end
		end)
	end
end

function mainPanelUI.renderBagFish()
	local storage = makeCard(mainPanelUI.content, 58)
	local storageTitle = makeText(storage, string.format("Fish Storage: %d / %d", #state.Inventory, state.BackpackSize), 16, Color3.fromRGB(255, 255, 255), true)
	storageTitle.Position = UDim2.new(0, 12, 0, 6)
	storageTitle.Size = UDim2.new(1, -24, 0, 22)
	local storageValue = makeText(storage, string.format("Bag value: %d coins", state.InventoryValue or 0), 12, Color3.fromRGB(190, 204, 220), false)
	storageValue.Position = UDim2.new(0, 12, 0, 30)
	storageValue.Size = UDim2.new(1, -24, 0, 18)

	local sortBar = Instance.new("Frame")
	sortBar.Name = "FishSortBar"
	sortBar.Size = UDim2.new(1, -8, 0, 62)
	sortBar.BackgroundTransparency = 1
	sortBar.Parent = mainPanelUI.content
	local sortLabel = makeText(sortBar, "Sort", 12, Color3.fromRGB(190, 204, 220), true)
	sortLabel.Size = UDim2.new(1, 0, 0, 18)

	local sortOptions = {
		{ id = "Rarity", text = "Rarity" },
		{ id = "Value", text = "Value" },
		{ id = "Name", text = "Name" },
		{ id = "Recently caught", text = "Recent" },
	}
	for index, option in ipairs(sortOptions) do
		local selected = mainPanelUI.bagFishSort == option.id
		local button = makeButton(sortBar, option.text, selected and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(38, 45, 57))
		button.Position = UDim2.new((index - 1) / 4, index == 1 and 0 or 4, 0, 22)
		button.Size = UDim2.new(0.25, -6, 0, 34)
		button.TextSize = 11
		button.MouseButton1Click:Connect(function()
			mainPanelUI.bagFishSort = option.id
			renderContent()
		end)
	end

	local fishRows = {}
	for index, fish in ipairs(state.Inventory) do
		table.insert(fishRows, { fish = fish, originalIndex = index })
	end
	table.sort(fishRows, function(left, right)
		local leftFish = left.fish
		local rightFish = right.fish
		if mainPanelUI.bagFishSort == "Name" then
			return string.lower(leftFish.name or leftFish.id or "") < string.lower(rightFish.name or rightFish.id or "")
		elseif mainPanelUI.bagFishSort == "Value" then
			if (leftFish.value or 0) ~= (rightFish.value or 0) then
				return (leftFish.value or 0) > (rightFish.value or 0)
			end
		elseif mainPanelUI.bagFishSort == "Rarity" then
			local rarityRank = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }
			if (rarityRank[leftFish.rarity] or 0) ~= (rarityRank[rightFish.rarity] or 0) then
				return (rarityRank[leftFish.rarity] or 0) > (rarityRank[rightFish.rarity] or 0)
			end
		end
		return left.originalIndex > right.originalIndex
	end)

	if #fishRows == 0 then
		local empty = makeText(mainPanelUI.content, "Your fish bag is empty.", 14, Color3.fromRGB(190, 204, 220), false)
		empty.Size = UDim2.new(1, -8, 0, 48)
		empty.TextXAlignment = Enum.TextXAlignment.Center
		return
	end

	local canEditAquarium = state.AquariumView and state.AquariumView.CanEdit == true
	for _, row in ipairs(fishRows) do
		local fish = row.fish
		local card = makeCard(mainPanelUI.content, 92)
		local color = GameConfig.RarityColors[fish.rarity] or Color3.fromRGB(255, 255, 255)
		local icon = makeFishIcon(card, fish.id, fish.rarity, true)
		icon.Position = UDim2.new(0, 8, 0, 17)
		icon.Size = UDim2.new(0, 58, 0, 58)

		local name = makeText(card, (fish.name or fish.id or "Fish") .. " [" .. (fish.rarity or "Common") .. "]", 14, color, true)
		name.Position = UDim2.new(0, 76, 0, 8)
		name.Size = UDim2.new(1, -190, 0, 22)
		name.TextTruncate = Enum.TextTruncate.AtEnd

		local scoreText = fish.score and (" | Score: " .. tostring(fish.score)) or ""
		local info = makeText(card, string.format("Value: %d%s", fish.value or 0, scoreText), 11, Color3.fromRGB(190, 204, 220), false)
		info.Position = UDim2.new(0, 76, 0, 33)
		info.Size = UDim2.new(1, -190, 0, 18)

		local islandId = normalizeIslandId(fish.biome)
		local island = islandId and GameConfig.Biomes[islandId]
		local islandText = (island and island.displayName) or fish.biome or "Unknown Island"
		local location = makeText(card, "Caught at: " .. tostring(islandText), 11, Color3.fromRGB(143, 160, 180), false)
		location.Position = UDim2.new(0, 76, 0, 55)
		location.Size = UDim2.new(1, -190, 0, 18)
		location.TextTruncate = Enum.TextTruncate.AtEnd

		local display = makeButton(card, canEditAquarium and "Display" or "View Only", canEditAquarium and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(86, 98, 115))
		display.Position = UDim2.new(1, -106, 0, 28)
		display.Size = UDim2.new(0, 90, 0, 36)
		display.TextSize = 11
		display.AutoButtonColor = canEditAquarium
		display.MouseButton1Click:Connect(function()
			if canEditAquarium then
				AquariumAction:FireServer("DisplayFish", fish.serial, row.originalIndex)
			end
		end)
	end
end

local function renderBagTab()
	mainPanelUI.renderBagTabBar()
	if mainPanelUI.activeBagTab == "Fishing Rods" then
		mainPanelUI.renderBagRods()
	elseif mainPanelUI.activeBagTab == "Bait" then
		mainPanelUI.renderBagBait()
	else
		mainPanelUI.renderBagFish()
	end
end

local function renderFishdexTab()
	local biomeId = getActiveFishingBiomeId()
	local biome = biomeId and GameConfig.Biomes[biomeId]
	local summary = makeCard(mainPanelUI.content, biome and 112 or 82)

	local titleLabel = makeText(summary, "Fishdex Collection: " .. getDiscoveredCount() .. "/" .. GameConfig.getFishCount(), 17, Color3.fromRGB(255, 255, 255), true)
	titleLabel.Position = UDim2.new(0, 12, 0, 8)
	titleLabel.Size = UDim2.new(1, -24, 0, 24)

	if biome then
		local rod = state and GameConfig.Rods[state.EquippedRod] or GameConfig.Rods.WoodenRod
		local autoStatus = state.AutoFishEnabled and "ON" or "OFF"

		local location = makeText(summary, "Current Island: " .. biome.displayName, 14, biome.color, true)
		location.Position = UDim2.new(0, 12, 0, 36)
		location.Size = UDim2.new(1, -24, 0, 20)

		local detail = makeText(summary, "Rod: " .. rod.displayName .. " | Luck: +" .. math.floor(rod.luck * 100) .. "% | AutoFish: " .. autoStatus, 13, Color3.fromRGB(190, 204, 220), false)
		detail.Position = UDim2.new(0, 12, 0, 60)
		detail.Size = UDim2.new(1, -24, 0, 18)

		local species = makeText(summary, "Species on this island: " .. #biome.fish, 12, Color3.fromRGB(143, 160, 180), false)
		species.Position = UDim2.new(0, 12, 0, 82)
		species.Size = UDim2.new(1, -24, 0, 18)
	else
		local detail = makeText(summary, "Enter a fishing island to see your active area here.", 13, Color3.fromRGB(190, 204, 220), false)
		detail.Position = UDim2.new(0, 12, 0, 38)
		detail.Size = UDim2.new(1, -24, 0, 20)
	end

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		local header = makeText(mainPanelUI.content, biome.displayName, 16, biome.color, true)
		header.Size = UDim2.new(1, -8, 0, 28)

		for _, fish in ipairs(biome.fish) do
			local count = state.Fishdex[fish.id] or 0
			local discovered = count > 0
			local card = makeCard(mainPanelUI.content, 76)
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
	local aquariumView = state.AquariumView or {}
	local viewLoaded = aquariumView.IsLoaded == true
	local canEditAquarium = aquariumView.CanEdit == true
	local ownerName = aquariumView.OwnerName or "Player"
	local viewOnly = viewLoaded and not canEditAquarium

	local top = makeCard(mainPanelUI.content, 96)
	local headingText = canEditAquarium and "My Aquarium" or (viewOnly and ("Viewing " .. ownerName .. "'s Aquarium") or "Aquarium Hub")
	local heading = makeText(top, headingText, 17, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 12, 0, 8)
	heading.Size = UDim2.new(1, -24, 0, 24)

	local infoText = string.format("Level %d | Space %d/%d", aquarium.Level, usedCapacity, capacity)
	if viewOnly then
		infoText = "View-only. Select My Aquarium to edit."
	elseif not viewLoaded then
		infoText = "Use the hub controls to load an aquarium."
	end
	local info = makeText(top, infoText, 14, Color3.fromRGB(190, 204, 220), false)
	info.Position = UDim2.new(0, 12, 0, 36)
	info.Size = UDim2.new(1, -24, 0, 22)

	local best = viewOnly and "Editing disabled for other players' aquariums." or (state.BestCatch and ("Best: " .. state.BestCatch.name .. " (" .. state.BestCatch.value .. " coins)") or "Best: None yet")
	local bestText = makeText(top, best, 13, Color3.fromRGB(143, 160, 180), false)
	bestText.Position = UDim2.new(0, 12, 0, 60)
	bestText.Size = UDim2.new(1, -184, 0, 20)

	if not canEditAquarium then
		renderAquariumVisitorsSection()
		return
	end

	local nextCost = GameConfig.AquariumUpgradeCosts[aquarium.Level + 1]
	local upgrade = makeButton(top, nextCost and ("Upgrade " .. nextCost) or "Max Level", Color3.fromRGB(28, 160, 92))
	upgrade.Position = UDim2.new(1, -162, 0, 58)
	upgrade.Size = UDim2.new(0, 150, 0, 28)
	upgrade.MouseButton1Click:Connect(function()
		AquariumAction:FireServer("Upgrade")
	end)

	for index, fish in ipairs(aquarium.Fish) do
		local card = makeCard(mainPanelUI.content, 62)
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

	local top = makeCard(mainPanelUI.content, 84)
	local heading = makeText(top, "Aquarium Hub", 17, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 12, 0, 8)
	heading.Size = UDim2.new(1, -24, 0, 24)

	local info = makeText(top, "Choose one aquarium to load into the main hub tank.", 13, Color3.fromRGB(190, 204, 220), false)
	info.Position = UDim2.new(0, 12, 0, 38)
	info.Size = UDim2.new(1, -24, 0, 22)

	local directory = makeCard(mainPanelUI.content, 204)
	local directoryTitle = makeText(directory, "Directory", 15, Color3.fromRGB(255, 255, 255), true)
	directoryTitle.Position = UDim2.new(0, 12, 0, 8)
	directoryTitle.Size = UDim2.new(1, -24, 0, 20)

	local function makeDirectoryButton(text, column, row, color, callback)
		local button = makeButton(directory, text, color or Color3.fromRGB(53, 130, 246))
		button.Position = UDim2.new(column == 1 and 0 or 0.5, column == 1 and 12 or 6, 0, 36 + ((row - 1) * 38))
		button.Size = UDim2.new(0.5, -18, 0, 32)
		button.TextSize = 12
		button.MouseButton1Click:Connect(callback)
		return button
	end

	local function visitSingleTank(userId)
		print("Loading aquarium:", tostring(userId))
		TeleportTo:FireServer({
			kind = "PlayerAquarium",
			userId = userId,
		})
	end

	local function getPublicVisitor(randomize)
		local choices = {}
		for _, visitor in ipairs(visitors) do
			if visitor.UserId then
				table.insert(choices, visitor)
			end
		end

		if #choices == 0 then
			return nil
		end

		if randomize then
			return choices[math.random(1, #choices)]
		end

		table.sort(choices, function(left, right)
			local leftBest = left.BestCatch and left.BestCatch.value or 0
			local rightBest = right.BestCatch and right.BestCatch.value or 0
			if leftBest ~= rightBest then
				return leftBest > rightBest
			end

			return (left.FishCount or 0) > (right.FishCount or 0)
		end)

		return choices[1]
	end

	makeDirectoryButton("My Aquarium", 1, 1, Color3.fromRGB(53, 130, 246), function()
		print("Aquarium Viewer option clicked:", "My Aquarium")
		visitSingleTank(player.UserId)
	end)
	makeDirectoryButton("Friends", 2, 1, Color3.fromRGB(38, 145, 118), function()
		print("Aquarium Viewer option clicked:", "Friends' Aquariums")
		showToast("Friends' aquariums are listed below.")
	end)
	makeDirectoryButton("Featured", 1, 2, Color3.fromRGB(86, 118, 220), function()
		print("Aquarium Viewer option clicked:", "Featured Aquariums")
		local visitor = getPublicVisitor(false)
		if visitor then
			print("Loading aquarium:", visitor.DisplayName or visitor.Name or "Featured")
			visitSingleTank(visitor.UserId)
		else
			showToast("No featured aquariums are ready yet.")
		end
	end)
	makeDirectoryButton("Most Liked", 2, 2, Color3.fromRGB(225, 156, 58), function()
		print("Aquarium Viewer option clicked:", "Most Liked Aquariums")
		local visitor = getPublicVisitor(false)
		if visitor then
			print("Loading aquarium:", visitor.DisplayName or visitor.Name or "Most Liked")
			visitSingleTank(visitor.UserId)
		else
			showToast("No liked aquariums are ready yet.")
		end
	end)
	makeDirectoryButton("Random Public", 1, 3, Color3.fromRGB(55, 170, 190), function()
		print("Aquarium Viewer option clicked:", "Random Public Aquarium")
		local visitor = getPublicVisitor(true)
		if visitor then
			print("Loading aquarium:", visitor.DisplayName or visitor.Name or "Random Public")
			visitSingleTank(visitor.UserId)
		else
			showToast("No public aquariums are ready yet.")
		end
	end)
	makeDirectoryButton("Search Player", 2, 3, Color3.fromRGB(196, 95, 128), function()
		print("Aquarium Viewer option clicked:", "Search Player Aquarium")
		showToast("Search Player Aquarium is coming soon.")
	end)

	local returnButton = makeButton(directory, "Return to Seaside Island", Color3.fromRGB(38, 45, 57))
	returnButton.Position = UDim2.new(0, 12, 0, 150)
	returnButton.Size = UDim2.new(1, -24, 0, 32)
	returnButton.TextSize = 12
	returnButton.MouseButton1Click:Connect(function()
		print("Aquarium Viewer option clicked:", "Return to Seaside Island")
		TeleportTo:FireServer("Lobby")
	end)

	if #visitors == 0 then
		local empty = makeCard(mainPanelUI.content, 64)
		local emptyText = makeText(empty, "No aquariums are ready yet.", 15, Color3.fromRGB(190, 204, 220), true)
		emptyText.Position = UDim2.new(0, 12, 0, 16)
		emptyText.Size = UDim2.new(1, -24, 0, 24)
		return
	end

	for _, visitor in ipairs(visitors) do
		local card = makeCard(mainPanelUI.content, 92)
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

		local visit = makeButton(card, visitor.IsSelf and "My Tank" or "Visit", Color3.fromRGB(53, 130, 246))
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
		{ id = "Lobby", name = "Seaside Island" },
		{ id = "AquariumHub", name = "Aquarium Hub" },
	}

	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		table.insert(targets, {
			id = biomeId,
			name = biome.displayName,
			biome = biome,
			requirement = biomeId ~= DEFAULT_FISHING_ISLAND_ID and GameConfig.getBiomeUnlockText(biomeId) or nil,
		})
	end

	for _, target in ipairs(targets) do
		local biome = target.biome
		local unlocked = not biome or getUnlockedIslands()[target.id]
		local current = currentLocation == target.id
		local card = makeCard(mainPanelUI.content, biome and 96 or 72)
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

local function renderQuestPeriodTabs()
	local selector = Instance.new("Frame")
	selector.Size = UDim2.new(1, -8, 0, 38)
	selector.BackgroundTransparency = 1
	selector.Parent = mainPanelUI.content

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
		local loading = makeCard(mainPanelUI.content, 64)
		local loadingText = makeText(loading, "Loading quests...", 15, Color3.fromRGB(190, 204, 220), true)
		loadingText.Position = UDim2.new(0, 12, 0, 16)
		loadingText.Size = UDim2.new(1, -24, 0, 24)
		return
	end

	local summary = makeCard(mainPanelUI.content, 72)
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
		local card = makeCard(mainPanelUI.content, 124)
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
		backdropEnabled = current.backdropEnabled ~= false,
		backgroundColor = current.backgroundColor,
		lightingColor = current.lightingColor,
		signText = current.signText or "",
		decorations = {},
		freeDecorations = {},
	}

	for slotId, decorationId in pairs(current.decorations or {}) do
		design.decorations[slotId] = decorationId
	end

	for _, item in ipairs(current.freeDecorations or {}) do
		if type(item) == "table" then
			table.insert(design.freeDecorations, {
				decorationId = item.decorationId,
				x = item.x,
				y = item.y,
				z = item.z,
				scale = item.scale,
			})
		end
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
			elseif key == "freeDecorations" and type(value) == "table" then
				design.freeDecorations = {}
				for _, item in ipairs(value) do
					if type(item) == "table" then
						table.insert(design.freeDecorations, {
							decorationId = item.decorationId,
							x = item.x,
							y = item.y,
							z = item.z,
							scale = item.scale,
						})
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
	selector.Parent = mainPanelUI.content

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = selector

	for _, tabName in ipairs({ "Passes", "Items", "Coins", "Upgrades" }) do
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
	local card = makeCard(mainPanelUI.content, 104)
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
	local reward = makeCard(mainPanelUI.content, 92)
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

function fishyFishRenderShopCoins()
	for _, productKey in ipairs(MonetizationConfig.CoinProductOrder or {}) do
		local product = MonetizationConfig.DeveloperProducts[productKey]
		if product then
			fishyFishRenderRobuxItem(productKey, product, function(key)
				fireShopAction("PromptProduct", "Product", key)
			end, false, "COIN", Color3.fromRGB(255, 181, 36))
		end
	end
end

function fishyFishRenderShopStorage()
	local summary = makeCard(mainPanelUI.content, 74)
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
	local canEditAquarium = state.AquariumView and state.AquariumView.CanEdit == true

	local summary = makeCard(mainPanelUI.content, 96)
	fishyFishMakeShopIcon(summary, ownsDesigner and "OPEN" or "LOCK", ownsDesigner and Color3.fromRGB(58, 174, 205) or Color3.fromRGB(96, 106, 122))
	local heading = makeText(summary, "Aquarium Designer", 16, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 76, 0, 8)
	heading.Size = UDim2.new(1, -194, 0, 22)
	local status = "Select My Aquarium in the Hub to edit."
	if canEditAquarium then
		status = ownsDesigner and "Owned | Preview, apply, and save premium designs." or "Preview is free. Apply premium designs after buying the pass."
	end
	local detail = makeText(summary, status, 12, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 76, 0, 34)
	detail.Size = UDim2.new(1, -194, 0, 34)
	detail.TextWrapped = true
	local cancel = makeButton(summary, monetization.AquariumPreviewActive and "Cancel" or "Preview", canEditAquarium and (monetization.AquariumPreviewActive and Color3.fromRGB(230, 126, 48) or Color3.fromRGB(86, 98, 115)) or Color3.fromRGB(86, 98, 115))
	cancel.Position = UDim2.new(1, -104, 0, 31)
	cancel.Size = UDim2.new(0, 88, 0, 34)
	cancel.AutoButtonColor = canEditAquarium
	cancel.MouseButton1Click:Connect(function()
		if canEditAquarium then
			fireShopAction("CancelAquariumPreview", "Aquarium")
		end
	end)

	local function renderDesignOption(kind, id, item, labelPrefix)
		local premium = item.premium == true
		local card = makeCard(mainPanelUI.content, 124)
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

		local preview = makeButton(card, canEditAquarium and "Preview" or "View Only", canEditAquarium and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(86, 98, 115))
		preview.Position = UDim2.new(1, -196, 0, 82)
		preview.Size = UDim2.new(0, 84, 0, 32)
		preview.TextSize = 12
		preview.AutoButtonColor = canEditAquarium
		preview.MouseButton1Click:Connect(function()
			if canEditAquarium then
				fireShopAction("PreviewAquariumDesign", "Aquarium", kind, fishyFishCopyAquariumDesignWith({ [kind] = id }))
			end
		end)

		local apply = makeButton(card, "Apply", canEditAquarium and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(86, 98, 115))
		apply.Position = UDim2.new(1, -104, 0, 82)
		apply.Size = UDim2.new(0, 88, 0, 32)
		apply.TextSize = 12
		apply.AutoButtonColor = canEditAquarium
		apply.MouseButton1Click:Connect(function()
			if canEditAquarium then
				fireShopAction("ApplyAquariumDesign", "Aquarium", kind, fishyFishCopyAquariumDesignWith({ [kind] = id }))
			end
		end)
	end

	local themeHeader = makeText(mainPanelUI.content, "Themes", 16, Color3.fromRGB(255, 255, 255), true)
	themeHeader.Size = UDim2.new(1, -8, 0, 28)
	for _, themeId in ipairs(MonetizationConfig.AquariumDesigner.themeOrder) do
		renderDesignOption("theme", themeId, MonetizationConfig.AquariumDesigner.themes[themeId])
	end

	local signCard = makeCard(mainPanelUI.content, 104)
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
	local applySign = makeButton(signCard, "Apply", canEditAquarium and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(86, 98, 115))
	applySign.Position = UDim2.new(1, -104, 0, 72)
	applySign.Size = UDim2.new(0, 88, 0, 26)
	applySign.TextSize = 12
	applySign.AutoButtonColor = canEditAquarium
	applySign.MouseButton1Click:Connect(function()
		if canEditAquarium then
			fireShopAction("ApplyAquariumDesign", "Aquarium", "signText", fishyFishCopyAquariumDesignWith({ signText = signBox.Text }))
		end
	end)
end

local function renderShopTab()
	fishyFishRenderShopSubTabs()

	if activeShopTab == "Passes" then
		fishyFishRenderShopGamePasses()
	elseif activeShopTab == "Items" then
		fishyFishRenderShopBait()
	elseif activeShopTab == "Coins" then
		fishyFishRenderShopCoins()
	elseif activeShopTab == "Upgrades" then
		fishyFishRenderShopStorage()
	end
end

local function renderLeaderboardTab()
	local function makeLeaderboardCard(height, strokeColor, strokeThickness, strokeTransparency)
		local wrapper = Instance.new("Frame")
		wrapper.Name = "LeaderboardCardRow"
		wrapper.Size = UDim2.new(1, 0, 0, height)
		wrapper.BackgroundTransparency = 1
		wrapper.Parent = mainPanelUI.content

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
	mainPanelUI.panelTitle.Text = activeTab
	clearChildren(mainPanelUI.content)

	if not state then
		local loading = makeText(mainPanelUI.content, "Loading player data...", 16, Color3.fromRGB(255, 255, 255), true)
		loading.Size = UDim2.new(1, -8, 0, 40)
		return
	end

	if activeTab == "Bag" and not panelCollapsed then
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

function minigameUI.legacyRunMinigame(prompt)
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
	minigameUI.catchButton.Visible = false
	minigameUI.timingBar.Visible = false
	minigameUI.zone.Visible = false
	minigameUI.marker.Visible = false
	minigameUI.fishingGameContent.Visible = true
	setMinigameFishIcon(fish)

	minigameUI.minigameText.Text = isAutoFish and "AutoFish is waiting for a bite..." or "Waiting for a bite..."
	minigameUI.minigameFishInfo.Text = "Something is biting..."
	minigameUI.minigameProgressText.Text = "Progress --"
	minigameUI.minigameInstruction.Text = promptBaitText .. castText
	minigameUI.progressFill.Size = UDim2.new(1, 0, 0, 0)
	forcePureWhiteText(minigameUI.minigameText)

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

	minigameUI.catchBar.Size = UDim2.new(1, -32, barSize, 0)
	minigameUI.catchBar.Position = UDim2.new(0.5, 0, barTop, 0)
	minigameUI.fishMarker.Position = UDim2.new(0.5, 0, fishY, 0)
	minigameUI.progressFill.Size = UDim2.new(1, 0, progress, 0)
	minigameUI.minigameText.Text = isAutoFish and "AutoFish is reeling..." or "Keep the fish inside the green bar!"
	minigameUI.minigameFishInfo.Text = string.format("%s [%s]\nValue: %d | XP: %d", fish.name or "Fish", fish.rarity or "Common", fish.value or 0, fish.xp or 0)
	minigameUI.minigameProgressText.Text = string.format("Progress %d%%", math.floor(progress * 100 + 0.5))
	minigameUI.minigameInstruction.Text = promptBaitText .. castText .. "\n" .. (isAutoFish and "AutoFish is handling this catch." or "Hold mouse, tap, or Space to lift the green bar. Release to let it fall.")
	forcePureWhiteText(minigameUI.minigameText)

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

		minigameUI.catchBar.Position = UDim2.new(0.5, 0, barTop, 0)
		minigameUI.fishMarker.Position = UDim2.new(0.5, 0, fishY, 0)
		minigameUI.progressFill.Size = UDim2.new(1, 0, progress, 0)
		minigameUI.minigameProgressText.Text = string.format("Progress %d%%", math.floor(progress * 100 + 0.5))

		if isAutoFish and elapsed >= (prompt.visualTime or 3) then
			minigameUI.minigameText.Text = "AutoFish caught it!"
			finish(true)
		elseif not isAutoFish and progress >= 1 and elapsed >= minSuccessDuration then
			minigameUI.minigameText.Text = "Caught!"
			finish(true)
		elseif not isAutoFish and progress <= 0 then
			minigameUI.minigameText.Text = "The fish escaped!"
			finish(false)
		elseif not isAutoFish and elapsed >= maxDuration then
			minigameUI.minigameText.Text = "The fish escaped!"
			finish(false)
		end
	end)
end

local function runMinigame(prompt)
	if minigameRunning then
		return
	end

	panelCollapsed = true
	updatePanelCollapsed()

	minigameRunning = true
	CastPower.running = false
	CastPower.activeConfig = nil
	setMinigameVisible(true)
	CastPower.content.Visible = false

	local lifecycleFinished = false
	local function complete(success, isAutoFish)
		if lifecycleFinished then
			return
		end

		lifecycleFinished = true
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

	local ok, cleanupOrError = pcall(function()
		local controller = script:WaitForChild("RarityCatchController", 5)
		assert(controller, "RarityCatchController was not synced")
		return require(controller).start({
			prompt = prompt,
			state = state,
			GameConfig = GameConfig,
			ui = minigameUI,
			RunService = RunService,
			UserInputService = UserInputService,
			tapButton = centerCastButton,
			getBaitData = getBaitData,
			getBaitCountText = getBaitCountText,
			setFishIcon = setMinigameFishIcon,
			forcePureWhiteText = forcePureWhiteText,
			onFinish = complete,
		})
	end)

	if not ok then
		warn("[FishingClient] Rarity catch controller failed:", cleanupOrError)
		complete(false, prompt.autoFish == true)
		return
	end

	activeMinigameCleanup = function()
		if lifecycleFinished then
			return
		end

		lifecycleFinished = true
		cleanupOrError()
		activeMinigameCleanup = nil
	end
end

StateUpdated.OnClientEvent:Connect(function(newState)
	state = newState
	refreshHud()
	renderContent()
	updateAquariumViewerFallbackButton()
	if biomeWarpUI.biomeWarpOverlay.Visible then
		renderBiomeWarpOptions()
	end
	if fishmongerUI.fishmongerOverlay.Visible then
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
	local isAquariumViewerFallbackInput = input.KeyCode == Enum.KeyCode.E and state and isInAquariumHub()
	if processed and not isAquariumViewerFallbackInput then
		return
	end

	if minigameRunning or CastPower.running then
		return
	end

	if isAquariumViewerFallbackInput then
		openAquariumHub()
	elseif input.KeyCode == Enum.KeyCode.F and state and not fishingBusy and getActiveFishingBiomeId() then
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
	updateAquariumViewerFallbackButton()
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
	updateAquariumViewerFallbackButton()
end)
