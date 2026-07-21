print("FishingClient started")
-- LOCALSAFE refactor: top-level locals reduced by grouping services, remotes, modules, and helper aliases.

local Services = {
	Players = game:GetService("Players"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	RunService = game:GetService("RunService"),
	TweenService = game:GetService("TweenService"),
	UserInputService = game:GetService("UserInputService"),
	ContextActionService = game:GetService("ContextActionService"),
	Lighting = game:GetService("Lighting"),
	TextService = game:GetService("TextService"),
	TextChatService = game:GetService("TextChatService"),
	StarterGui = game:GetService("StarterGui"),
	GuiService = game:GetService("GuiService"),
}

local player = Services.Players.LocalPlayer
local GameConfig = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
ResourceConfig = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ResourceConfig"))
local MonetizationConfig = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))
local FishingSFX = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishingSFX"))

if Services.TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	Services.TextChatService.OnIncomingMessage = function(message)
		local source = message.TextSource
		if not source then
			return nil
		end

		local speaker = Services.Players:GetPlayerByUserId(source.UserId)
		if not speaker or speaker:GetAttribute("FishyFishVip") ~= true then
			return nil
		end

		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = "<font color='#FFD94F'>[VIP]</font> " .. message.PrefixText
		return properties
	end
end

local Remotes = Services.ReplicatedStorage:WaitForChild("FishingRemotes")
local Remote = {
	StartFishing = Remotes:WaitForChild("StartFishing"),
	GetCastConfig = Remotes:WaitForChild("GetCastConfig", 10),
	FinishMinigame = Remotes:WaitForChild("FinishMinigame"),
	SellFish = Remotes:WaitForChild("SellFish"),
	BuyRod = Remotes:WaitForChild("BuyRod"),
	BaitAction = Remotes:WaitForChild("BaitAction", 10),
	QuestAction = Remotes:WaitForChild("QuestAction", 10),
	ShopAction = Remotes:WaitForChild("ShopAction", 10),
	OpenShop = Remotes:WaitForChild("OpenShop", 10),
	UnlockBiome = Remotes:WaitForChild("UnlockBiome"),
	TeleportTo = Remotes:WaitForChild("TeleportTo"),
	OpenBiomeWarp = Remotes:WaitForChild("OpenBiomeWarp", 10),
	OpenSellFish = Remotes:WaitForChild("OpenSellFish", 10),
	OpenRodShop = Remotes:WaitForChild("OpenRodShop", 10),
	OpenAquariumHub = Remotes:WaitForChild("OpenAquariumHub", 10),
	AquariumAction = Remotes:WaitForChild("AquariumAction"),
	ToggleAutoFish = Remotes:WaitForChild("ToggleAutoFish"),
	StateUpdated = Remotes:WaitForChild("StateUpdated"),
	FishingPrompt = Remotes:WaitForChild("FishingPrompt"),
	Notice = Remotes:WaitForChild("Notice"),
	GetState = Remotes:WaitForChild("GetState"),
}

local Modules = {
	RemoteActions = require(script:WaitForChild("RemoteActions")),
	PanelMarkers = require(script:WaitForChild("PanelMarkers")),
	PlayerGuiDebug = require(script:WaitForChild("PlayerGuiDebug")),
	LegacyRightUiCleanup = require(script:WaitForChild("LegacyRightUiCleanup")),
	IslandState = require(script:WaitForChild("IslandState")),
	GuiPrimitives = require(script:WaitForChild("GuiPrimitives")),
	BaitHelpers = require(script:WaitForChild("BaitHelpers")),
	QuestHelpers = require(script:WaitForChild("QuestHelpers")),
	QuestModernUI = require(script:WaitForChild("QuestModernUI")),
	AquariumViewerModernUI = require(script:WaitForChild("AquariumViewerModernUI")),
	LeaderboardHelpers = require(script:WaitForChild("LeaderboardHelpers")),
	FishingWater = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishingWater")),
}

local remoteActions = Modules.RemoteActions.create({
	Remotes = Remotes,
	BaitAction = Remote.BaitAction,
	QuestAction = Remote.QuestAction,
	ShopAction = Remote.ShopAction,
})
local screenGui = script.Parent
screenGui.Enabled = true
screenGui.ResetOnSpawn = false
-- Match the persisted v1636 inset policy. Keeping this authored value in Play
-- prevents a runtime-only vertical shift between StarterGui and PlayerGui.
screenGui.IgnoreGuiInset = false
screenGui.DisplayOrder = 100
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- AuthoredUiV2 surfaces are direct children of FishingGui. Detecting the
-- declared Root plus Templates makes this safe during the migration even if an
-- older place copy has not received the persisted ScreenGui attribute yet.
local AuthoredUi = {
	enabled = screenGui:GetAttribute("AuthoredUiV2") == true,
}
if not AuthoredUi.enabled then
	AuthoredUi.enabled = screenGui:FindFirstChild("Root") ~= nil
		and screenGui:FindFirstChild("Templates") ~= nil
		and screenGui:FindFirstChild("ModernQuestUI") ~= nil
end
if AuthoredUi.enabled then
	screenGui:SetAttribute("AuthoredUiV2", true)
end
assert(AuthoredUi.enabled, "FishingGui must contain the authored StarterGui hierarchy")

function AuthoredUi.getSurface(name)
	if not AuthoredUi.enabled then
		return nil
	end

	local surface = screenGui:FindFirstChild(name)
	return surface and surface:IsA("GuiObject") and surface or nil
end

function AuthoredUi.countClaimableQuests(currentState)
	if type(currentState) ~= "table" then
		return 0
	end

	local serverCount = tonumber(currentState.QuestUnclaimedCount)
	if serverCount then
		return math.max(0, math.floor(serverCount))
	end

	local count = 0
	for _, period in pairs(currentState.Quests or currentState.QuestState or {}) do
		local quests = type(period) == "table"
			and type(period.quests) == "table"
			and period.quests
			or {}
		for _, quest in ipairs(quests) do
			if quest.completed == true and quest.claimed ~= true then
				count += 1
			end
		end
	end
	return count
end

function AuthoredUi.closeQuest()
	local controller = AuthoredUi.questController
	if controller and controller.IsVisible and controller:IsVisible() then
		controller:SetVisible(false)
	end
end

local panelMarkers = Modules.PanelMarkers.setup(screenGui)
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

local playerGuiDebug = Modules.PlayerGuiDebug.create({
	playerGui = playerGui,
	screenGui = screenGui,
})
local legacyRightUiCleanup = Modules.LegacyRightUiCleanup.create({
	scriptFullName = script:GetFullName(),
})
if not AuthoredUi.enabled then
	for _, gui in ipairs(playerGui:GetChildren()) do
		legacyRightUiCleanup.disableLegacyRightUi(gui)
	end
end
playerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") then
		task.defer(playerGuiDebug.printPlayerGuiScreenGuis, "added " .. child.Name)
		if not AuthoredUi.enabled then
			task.defer(legacyRightUiCleanup.disableLegacyRightUi, child)
		end
	end
end)
task.defer(playerGuiDebug.printPlayerGuiScreenGuis, "initial")
task.defer(playerGuiDebug.printPlayerGuiChildren)
task.defer(playerGuiDebug.printFishingGuiChildren)
if not AuthoredUi.enabled then
	legacyRightUiCleanup.printOldRightUiDisabled()
end

task.defer(function()
	pcall(function()
		Services.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
end)

local state = nil
local activeTab = "Fishdex"
local activeQuestPeriod = "Daily"
local activeShopTab = "Passes"
local shopModernUI = nil
local shopModernContext = nil
local fishingBusy = false
local minigameRunning = false
local activeMinigameCleanup = nil
local panelCollapsed = true
local toolSwitchLock = {
	active = false,
	actionName = "FishyFishLockUtilityHotbar",
}

function toolSwitchLock.set(locked)
	locked = locked == true
	if toolSwitchLock.active == locked then
		return
	end

	toolSwitchLock.active = locked
	player:SetAttribute("FishingToolSwitchLocked", locked)
	if locked then
		Services.ContextActionService:BindActionAtPriority(
			toolSwitchLock.actionName,
			function()
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value + 100,
			Enum.KeyCode.One,
			Enum.KeyCode.Two,
			Enum.KeyCode.Three
		)
	else
		Services.ContextActionService:UnbindAction(toolSwitchLock.actionName)
	end
end

player:SetAttribute("FishingToolSwitchLocked", false)

-- One physical hotbar click currently reaches setTab through two routes:
-- PanelEvent and ToolHotbarBinder. Ignore the immediate duplicate call.
local lastPanelTabRequestName = nil
local lastPanelTabRequestAt = 0
local PANEL_TAB_DUPLICATE_WINDOW = 0.25

local lastFishingBiomeId = nil
local DEFAULT_FISHING_ISLAND_ID = (GameConfig.IslandOrder and GameConfig.IslandOrder[1])
	or (GameConfig.BiomeOrder and GameConfig.BiomeOrder[1])
	or "LilyshoreIsland"

local islandState = Modules.IslandState.create({
	GameConfig = GameConfig,
	getState = function()
		return state
	end,
})
local fishingBlur = Services.Lighting:FindFirstChild("FishyFishUiBlur")
if not fishingBlur then
	fishingBlur = Instance.new("BlurEffect")
	fishingBlur.Name = "FishyFishUiBlur"
	fishingBlur.Parent = Services.Lighting
end
fishingBlur.Enabled = false
fishingBlur.Size = 0

local guiPrimitives = Modules.GuiPrimitives.create({
	GameConfig = GameConfig,
})
local baitHelpers = Modules.BaitHelpers.create({
	GameConfig = GameConfig,
	getState = function()
		return state
	end,
})
local questHelpers = Modules.QuestHelpers.create({
	GameConfig = GameConfig,
	getState = function()
		return state
	end,
})
local root = assert(
	AuthoredUi.getSurface("Root"),
	"FishingGui.Root is missing from the authored StarterGui hierarchy"
)

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
	makeText = guiPrimitives.makeText,
	makeButton = guiPrimitives.makeButton,
	addCorner = guiPrimitives.addCorner,
	addStroke = guiPrimitives.addStroke,
	addGradient = guiPrimitives.addGradient,
	setCornerRadius = guiPrimitives.setCornerRadius,
	limitTextSize = guiPrimitives.limitTextSize,
	forcePureWhiteText = guiPrimitives.forcePureWhiteText,
	addGloss = guiPrimitives.addGloss,
	maxLevel = GameConfig.MAX_LEVEL,
})

task.defer(playerGuiDebug.printPlayerGuiChildren)
task.defer(playerGuiDebug.printFishingGuiChildren)

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

AuthoredUi.questCreateOk, AuthoredUi.questController = pcall(
	Modules.QuestModernUI.create,
	{
		parent = AuthoredUi.enabled and screenGui or root,
		remotes = Remotes,
		authoredUi = AuthoredUi.enabled,
		manageRemoteState = false,
		initialState = state,
	}
)
if not AuthoredUi.questCreateOk then
	warn("[FishingClient] Modern quest UI failed to initialize:", AuthoredUi.questController)
	AuthoredUi.questController = nil
end

-- IslandWarpModernClient owns the complete authored v1615 surface and listens
-- to OpenBiomeWarp directly. FishingClient only needs a close hook so opening
-- another panel can hide the authored island selector without constructing a
-- second compatibility popup over it.
local biomeWarpUI = {
	biomeWarpOverlay = assert(
		AuthoredUi.getSurface("BiomeWarpOverlay"),
		"BiomeWarpOverlay is missing from the authored FishingGui"
	),
}

local function setBiomeWarpVisible(visible)
	if visible then
		AuthoredUi.closeQuest()
		return
	end

	biomeWarpUI.biomeWarpOverlay.Visible = false
	local modernIslandWarp = biomeWarpUI.biomeWarpOverlay:FindFirstChild("ModernIslandWarp")
	if modernIslandWarp and modernIslandWarp:IsA("GuiObject") then
		modernIslandWarp.Visible = false
	end
end

local function renderBiomeWarpOptions()
	-- Dynamic destination cards are cloned from IslandCardTemplate by the
	-- authored IslandWarpModernClient binder.
end

local function requiredAuthoredNode(parent, name, className)
	local child = parent:FindFirstChild(name)
	assert(child, string.format("Missing authored UI node %s.%s", parent:GetFullName(), name))
	assert(child:IsA(className), string.format(
		"Authored UI node %s must be %s, got %s",
		child:GetFullName(),
		className,
		child.ClassName
	))
	return child
end

local function clonePopupListCard(template, parent, name, strokeColor, strokeTransparency)
	local wrapper = template:Clone()
	wrapper.Name = name .. "Row"
	wrapper.Visible = true
	local card = requiredAuthoredNode(wrapper, "Card", "Frame")
	card.Name = name
	local cardStroke = requiredAuthoredNode(card, "Border", "UIStroke")
	cardStroke.Color = strokeColor or Color3.fromRGB(83, 104, 134)
	cardStroke.Transparency = strokeTransparency or 0
	wrapper.Parent = parent
	return card
end

local function setPopupIcon(icon, imageId, fallbackText, strokeColor)
	local border = requiredAuthoredNode(icon, "Border", "UIStroke")
	local image = requiredAuthoredNode(icon, "Image", "ImageLabel")
	local fallback = requiredAuthoredNode(icon, "Fallback", "TextLabel")
	border.Color = strokeColor or Color3.fromRGB(130, 146, 166)
	if imageId and imageId ~= "" then
		image.Image = imageId
		image.Visible = true
		fallback.Visible = false
	else
		image.Image = ""
		image.Visible = false
		fallback.Text = fallbackText
		fallback.TextColor3 = strokeColor or Color3.fromRGB(130, 146, 166)
		fallback.Visible = true
	end
end

local fishmongerUI = {}
fishmongerUI.fishmongerOverlay = assert(
	AuthoredUi.getSurface("FishmongerSellOverlay"),
	"FishmongerSellOverlay is missing from the authored FishingGui"
)
fishmongerUI.fishmongerPanel = requiredAuthoredNode(
	fishmongerUI.fishmongerOverlay,
	"FishmongerSellPanel",
	"Frame"
)
fishmongerUI.fishmongerTitle = requiredAuthoredNode(fishmongerUI.fishmongerPanel, "Title", "TextLabel")
fishmongerUI.fishmongerSellAll = requiredAuthoredNode(fishmongerUI.fishmongerPanel, "SellAllButton", "TextButton")
fishmongerUI.fishmongerClose = requiredAuthoredNode(fishmongerUI.fishmongerPanel, "CloseButton", "TextButton")
fishmongerUI.fishmongerSortBar = requiredAuthoredNode(fishmongerUI.fishmongerPanel, "FishmongerSortBar", "Frame")
fishmongerUI.fishmongerList = requiredAuthoredNode(fishmongerUI.fishmongerPanel, "FishmongerSellList", "ScrollingFrame")
fishmongerUI.templates = requiredAuthoredNode(fishmongerUI.fishmongerPanel, "Templates", "Folder")
fishmongerUI.sortButtonTemplate = requiredAuthoredNode(fishmongerUI.templates, "SortButtonTemplate", "TextButton")
fishmongerUI.emptyStateTemplate = requiredAuthoredNode(fishmongerUI.templates, "EmptyStateTemplate", "TextLabel")
fishmongerUI.fishSellRowTemplate = requiredAuthoredNode(fishmongerUI.templates, "FishSellRowTemplate", "Frame")

local activeFishmongerSort = "Recent"

local function setFishmongerSellVisible(visible)
	if visible then
		AuthoredUi.closeQuest()
	end
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
	guiPrimitives.clearChildren(fishmongerUI.fishmongerSortBar)

	local sortOptions = {
		{ mode = "Rarity", label = "Rarity" },
		{ mode = "Value", label = "Value" },
	}

	for optionIndex, option in ipairs(sortOptions) do
		local descendingId = option.mode .. "Desc"
		local ascendingId = option.mode .. "Asc"
		local selected = activeFishmongerSort == descendingId or activeFishmongerSort == ascendingId
		local label = option.label
		if selected then
			label = option.label .. (activeFishmongerSort == descendingId and ": High" or ": Low")
		end

		local button = fishmongerUI.sortButtonTemplate:Clone()
		button.Name = option.mode .. "SortButton"
		button.LayoutOrder = optionIndex
		button.Text = label
		button.BackgroundColor3 = selected
			and Color3.fromRGB(230, 126, 48)
			or Color3.fromRGB(38, 45, 57)
		button.Visible = true
		button.Parent = fishmongerUI.fishmongerSortBar
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
	guiPrimitives.clearChildren(fishmongerUI.fishmongerList)

	if not state then
		fishmongerUI.fishmongerSellAll.Visible = false
		return
	end

	fishmongerUI.fishmongerSellAll.Visible = #state.Inventory > 0

	if #state.Inventory == 0 then
		local empty = fishmongerUI.emptyStateTemplate:Clone()
		empty.Name = "EmptyState"
		empty.Visible = true
		empty.Parent = fishmongerUI.fishmongerList
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

		local card = clonePopupListCard(
			fishmongerUI.fishSellRowTemplate,
			fishmongerUI.fishmongerList,
			"SellOption_" .. tostring(fish.serial or index),
			color,
			0.25
		)

		local icon = requiredAuthoredNode(card, "Icon", "Frame")
		setPopupIcon(icon, GameConfig.getFishImage(fish.id), "FISH", color)
		requiredAuthoredNode(icon, "Border", "UIStroke").Transparency = 0.2

		local name = requiredAuthoredNode(card, "Name", "TextLabel")
		name.Text = fish.name .. " [" .. fish.rarity .. "]"
		name.TextColor3 = color

		local info = requiredAuthoredNode(card, "Info", "TextLabel")
		info.Text = "Sell value: " .. tostring(fish.value or 0) .. " coins"

		local sell = requiredAuthoredNode(card, "SellButton", "TextButton")
		sell.MouseButton1Click:Connect(function()
			Remote.SellFish:FireServer("Single", fish.serial, index)
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
		Remote.SellFish:FireServer()
	end
end)

if Remote.OpenSellFish then
	Remote.OpenSellFish.OnClientEvent:Connect(openFishmongerSell)
else
	warn("OpenSellFish remote was not available; fishmonger sell popup is disabled until remotes resync.")
end

local rodShopUI = {}
local activeSupplyShopTab = "Rods"

rodShopUI.overlay = assert(
	AuthoredUi.getSurface("RodShopOverlay"),
	"RodShopOverlay is missing from the authored FishingGui"
)
rodShopUI.panel = requiredAuthoredNode(rodShopUI.overlay, "RodShopPanel", "Frame")
rodShopUI.title = requiredAuthoredNode(rodShopUI.panel, "Title", "TextLabel")
rodShopUI.close = requiredAuthoredNode(rodShopUI.panel, "CloseButton", "TextButton")
rodShopUI.tabs = requiredAuthoredNode(rodShopUI.panel, "SupplyShopTabs", "Frame")
rodShopUI.list = requiredAuthoredNode(rodShopUI.panel, "RodShopList", "ScrollingFrame")
rodShopUI.templates = requiredAuthoredNode(rodShopUI.panel, "Templates", "Folder")
rodShopUI.tabButtonTemplate = requiredAuthoredNode(rodShopUI.templates, "TabButtonTemplate", "TextButton")
rodShopUI.rodRowTemplate = requiredAuthoredNode(rodShopUI.templates, "RodRowTemplate", "Frame")
rodShopUI.baitRowTemplate = requiredAuthoredNode(rodShopUI.templates, "BaitRowTemplate", "Frame")

local function setRodShopVisible(visible)
	if visible then
		AuthoredUi.closeQuest()
	end
	rodShopUI.overlay.Visible = visible
end

local renderRodShopOptions

local function renderSupplyShopTabs()
	guiPrimitives.clearChildren(rodShopUI.tabs)

	for tabIndex, tabName in ipairs({ "Rods", "Bait" }) do
		local selected = activeSupplyShopTab == tabName
		local button = rodShopUI.tabButtonTemplate:Clone()
		button.Name = tabName .. "Tab"
		button.LayoutOrder = tabIndex
		button.Text = tabName
		button.BackgroundColor3 = selected
			and Color3.fromRGB(53, 130, 246)
			or Color3.fromRGB(38, 45, 57)
		button.Visible = true
		button.Parent = rodShopUI.tabs
		button.MouseButton1Click:Connect(function()
			activeSupplyShopTab = tabName
			rodShopUI.list.CanvasPosition = Vector2.new(0, 0)
			renderRodShopOptions()
		end)
	end
end

local function getRodRequirementText(rod)
	local levelMet = state.Level >= rod.unlockLevel
	local coinsMet = state.Coins >= rod.cost
	return string.format(
		"Level %d (%s)  |  %d Coins (%s)",
		rod.unlockLevel,
		levelMet and "Met" or "Unmet",
		rod.cost,
		coinsMet and "Met" or "Unmet"
	)
end

function fishyFishGetRodResourceRequirement(rod)
	local inventory = state.ResourceInventory or {}
	for _, resourceId in ipairs(ResourceConfig.ResourceOrder) do
		local required = tonumber(rod.resourceCosts and rod.resourceCosts[resourceId]) or 0
		if required > 0 then
			local current = math.max(0, math.floor(tonumber(inventory[resourceId]) or 0))
			local met = current >= required
			return string.format("%s: %d/%d (%s)", ResourceConfig.Resources[resourceId].displayName, current, required, met and "Met" or "Unmet"), met
		end
	end
	return "Resources: None (Met)", true
end

function renderRodShopOptions()
	renderSupplyShopTabs()
	guiPrimitives.clearChildren(rodShopUI.list)

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
			local previousOK = not rod.previousRod or state.OwnedRods[rod.previousRod] == true
			local resourceText, resourcesOK = fishyFishGetRodResourceRequirement(rod)
			local canUseButton = (owned and not equipped) or (not owned and previousOK and levelOK and resourcesOK and canAfford)

			local card = clonePopupListCard(
				rodShopUI.rodRowTemplate,
				rodShopUI.list,
				rodId .. "ShopOption",
				owned and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(83, 104, 134),
				0.25
			)

			local icon = requiredAuthoredNode(card, "Icon", "Frame")
			setPopupIcon(
				icon,
				GameConfig.getRodImage(rodId),
				"NO IMAGE",
				Color3.fromRGB(130, 146, 166)
			)
			requiredAuthoredNode(icon, "Fallback", "TextLabel").TextSize = 10

			local name = requiredAuthoredNode(card, "Name", "TextLabel")
			name.Text = rod.displayName

			local info = requiredAuthoredNode(card, "Info", "TextLabel")
			info.Text = getRodRequirementText(rod)
			info.TextColor3 = levelOK and canAfford and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(255, 145, 145)

			local previousName = rod.previousRod and GameConfig.Rods[rod.previousRod].displayName or "None"
			local previous = requiredAuthoredNode(card, "Previous", "TextLabel")
			previous.Text = "Previous: " .. previousName .. " (" .. (previousOK and "Met" or "Unmet") .. ")"
			previous.TextColor3 = previousOK and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(255, 145, 145)

			local resource = requiredAuthoredNode(card, "Resource", "TextLabel")
			resource.Text = resourceText
			resource.TextColor3 = resourcesOK and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(255, 145, 145)

			local statusText = "Improves speed and timing zone."
			if equipped then
				statusText = "Currently equipped."
			elseif owned then
				statusText = "Owned."
			elseif not previousOK then
				statusText = "Previous rod required."
			elseif not levelOK then
				statusText = "Reach level " .. tostring(rod.unlockLevel) .. " to buy."
			elseif not resourcesOK then
				statusText = "More crafting resources required."
			elseif not canAfford then
				statusText = "Need " .. tostring(rod.cost - state.Coins) .. " more coins."
			end

			local status = requiredAuthoredNode(card, "Status", "TextLabel")
			status.Text = statusText

			local label = equipped and "Equipped" or (owned and "Equip" or "Buy")
			local buttonColor = canUseButton and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(86, 98, 115)
			if not owned and canUseButton then
				buttonColor = Color3.fromRGB(28, 160, 92)
			end

			local button = requiredAuthoredNode(card, "ActionButton", "TextButton")
			button.Text = label
			button.BackgroundColor3 = buttonColor
			button.AutoButtonColor = canUseButton
			button.MouseButton1Click:Connect(function()
				if canUseButton then
					Remote.BuyRod:FireServer(rodId, owned and "Equip" or "Buy")
				end
			end)
		end

		return
	end

	for _, baitId in ipairs(GameConfig.BaitOrder) do
		local bait = GameConfig.Baits[baitId]
		local count = baitHelpers.getBaitCount(baitId)
		local equipped = state.EquippedBait == baitId
		local isBasic = baitId == GameConfig.BasicBaitId
		local canEquip = isBasic or count > 0
		local canBuy = not isBasic and state.Level >= (bait.unlockLevel or 1) and state.Coins >= (bait.cost or 0)

		local card = clonePopupListCard(
			rodShopUI.baitRowTemplate,
			rodShopUI.list,
			baitId .. "ShopOption",
			equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(83, 104, 134),
			equipped and 0.15 or 0.35
		)

		local name = requiredAuthoredNode(card, "Name", "TextLabel")
		name.Text = bait.displayName

		local effect = requiredAuthoredNode(card, "Effect", "TextLabel")
		effect.Text = baitHelpers.getBaitEffectText(bait)

		local countText = baitHelpers.getBaitCountText(baitId, count)
		if not isBasic then
			countText ..= string.format(" | %d coins / %d | Lv %d", bait.cost or 0, bait.purchaseAmount or 1, bait.unlockLevel or 1)
		end
		local detail = requiredAuthoredNode(card, "Detail", "TextLabel")
		detail.Text = countText
		detail.TextColor3 = equipped and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(143, 160, 180)

		local buy = requiredAuthoredNode(card, "BuyButton", "TextButton")
		buy.Visible = not isBasic
		if buy.Visible then
			buy.Text = "Buy +" .. tostring(bait.purchaseAmount or 1)
			buy.BackgroundColor3 = canBuy and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(86, 98, 115)
			buy.AutoButtonColor = canBuy
			buy.MouseButton1Click:Connect(function()
				remoteActions.fireBaitAction("Buy", baitId)
			end)
		end

		local equip = requiredAuthoredNode(card, "EquipButton", "TextButton")
		equip.Text = equipped and "Equipped" or "Equip"
		equip.BackgroundColor3 = equipped
			and Color3.fromRGB(91, 104, 124)
			or (canEquip and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(86, 98, 115))
		equip.AutoButtonColor = canEquip and not equipped
		equip.MouseButton1Click:Connect(function()
			if not equipped then
				remoteActions.fireBaitAction("Equip", baitId)
			end
		end)
	end
end

rodShopUI.close.MouseButton1Click:Connect(function()
	setRodShopVisible(false)
end)


local FISHDEX_ASSETS = {
	Backbone = "rbxassetid://103454732696314",
	AllTab = "rbxassetid://118189169708215",
	LilyshoreIslandTab = "rbxassetid://114808409268766",
	RiverbendIslandTab = "rbxassetid://108890245611164",
	CoralCoastIslandTab = "rbxassetid://99827097832276",
	FishBackground = "rbxassetid://80769049450525",
	CollectionTab = "rbxassetid://109496036302333",
	Common = "rbxassetid://108586755444398",
	Uncommon = "rbxassetid://85531077583088",
	Rare = "rbxassetid://90678177285266",
	Epic = "rbxassetid://85211034408359",
	Legendary = "rbxassetid://86612679843061",
	Mythic = "rbxassetid://98199432465143",
	CloseButton = "rbxassetid://112132624750898",
}

local FISHDEX_FALLBACK_IMAGES = {
	Bass = "rbxassetid://124462000894673",
	Bluegill = "rbxassetid://139664436647833",
	Carp = "rbxassetid://85530716090863",
	Catfish = "rbxassetid://84885381823789",
	GoldenCarp = "rbxassetid://138971721449676",
	Koi = "rbxassetid://135595232171014",
	PondGuardian = "rbxassetid://86635246735309",
	SmallFish = "rbxassetid://92425635797325",
}

local fishdexModernUI = {
	selectedIsland = "All",
	tabButtons = {},
	root = nil,
	host = nil,
}

local mainPanelUI = {}
mainPanelUI.panel = assert(
	AuthoredUi.getSurface("MainPanel"),
	"MainPanel is missing from the authored FishingGui"
)
mainPanelUI.host = mainPanelUI.panel
mainPanelUI.panelConstraint = requiredAuthoredNode(mainPanelUI.panel, "PanelSizeConstraint", "UISizeConstraint")
mainPanelUI.panelTitle = requiredAuthoredNode(mainPanelUI.panel, "PanelTitle", "TextLabel")
mainPanelUI.panelClose = requiredAuthoredNode(mainPanelUI.panel, "PanelClose", "TextButton")
mainPanelUI.panelToggle = requiredAuthoredNode(mainPanelUI.panel, "PanelToggle", "TextButton")

local function updatePanelCollapsed()
	if panelCollapsed and shopModernUI and shopModernUI.hide then
		shopModernUI.hide()
	end

	local showingFishdex = activeTab == "Fishdex" and not panelCollapsed
	mainPanelUI.panel.Visible = not panelCollapsed
		and activeTab ~= "Fishdex"
		and activeTab ~= "Bag"
		and activeTab ~= "Quests"
		and activeTab ~= "Aquarium"
	mainPanelUI.panelToggle.Visible = false

	if fishdexModernUI.root then
		fishdexModernUI.root.Visible = showingFishdex
	end

	if AuthoredUi.aquariumController
		and (panelCollapsed or activeTab ~= "Aquarium")
	then
		AuthoredUi.aquariumController:Hide()
	end

	if panelCollapsed then
		local bagModuleScript = script:FindFirstChild("BagModernUI")
		if bagModuleScript then
			local ok, bagModule = pcall(require, bagModuleScript)
			if ok and bagModule and bagModule.hide then
				bagModule.hide()
			end
		end
	end
end

mainPanelUI.panelClose.MouseButton1Click:Connect(function()
	AuthoredUi.closeQuest()
	panelCollapsed = true
	updatePanelCollapsed()
end)

updatePanelCollapsed()

mainPanelUI.tabs = requiredAuthoredNode(mainPanelUI.panel, "Tabs", "Frame")
mainPanelUI.tabGrid = requiredAuthoredNode(mainPanelUI.tabs, "UIGridLayout", "UIGridLayout")
mainPanelUI.content = requiredAuthoredNode(mainPanelUI.panel, "Content", "ScrollingFrame")
mainPanelUI.contentLayout = requiredAuthoredNode(mainPanelUI.content, "UIListLayout", "UIListLayout")
mainPanelUI.legacyTemplates = requiredAuthoredNode(
	mainPanelUI.panel,
	"LegacyMainPanelTemplates",
	"Folder"
)

local LEGACY_MAIN_PANEL_TEMPLATE_CLASSES = {
	AquariumSummaryTemplate = "Frame",
	AquariumFishTemplate = "Frame",
	AquariumHubHeaderTemplate = "Frame",
	AquariumDirectoryTemplate = "Frame",
	AquariumEmptyTemplate = "Frame",
	AquariumVisitorTemplate = "Frame",
	LoadingLabelTemplate = "TextLabel",
}

mainPanelUI.legacyTemplateRefs = {}
for templateName, className in pairs(LEGACY_MAIN_PANEL_TEMPLATE_CLASSES) do
	mainPanelUI.legacyTemplateRefs[templateName] = requiredAuthoredNode(
		mainPanelUI.legacyTemplates,
		templateName,
		className
	)
end

local function cloneLegacyMainPanelTemplate(templateName, parent)
	local template = mainPanelUI.legacyTemplateRefs[templateName]
	assert(template, "Missing authored MainPanel template " .. templateName)
	local clone = template:Clone()
	if clone:IsA("GuiObject") then
		clone.Visible = true
	end
	clone.Parent = parent or mainPanelUI.content
	return clone
end

local function authoredLegacyCard(templateName)
	local wrapper = cloneLegacyMainPanelTemplate(templateName, mainPanelUI.content)
	wrapper.Name = "CardRow"
	local card = requiredAuthoredNode(wrapper, "Card", "Frame")
	return wrapper, card
end

local function requireLegacyDecorationSet(parent, declarations)
	for _, declaration in ipairs(declarations) do
		requiredAuthoredNode(parent, declaration[1], declaration[2])
	end
end

local function requireLegacyGloss(parent, name)
	local gloss = requiredAuthoredNode(parent, name, "Frame")
	requireLegacyDecorationSet(gloss, {
		{ "GlossCorner", "UICorner" },
		{ "GlossGradient", "UIGradient" },
	})
	return gloss
end

local minigameUI = {}
minigameUI.minigame = requiredAuthoredNode(screenGui, "FishingMinigame", "Frame")
minigameUI.minigame.Visible = false
requireLegacyDecorationSet(minigameUI.minigame, {
	{ "PanelCorner", "UICorner" },
	{ "OuterStroke", "UIStroke" },
	{ "HighlightStroke", "UIStroke" },
	{ "PanelGradient", "UIGradient" },
})
minigameUI.minigameConstraint = requiredAuthoredNode(
	minigameUI.minigame,
	"MinigameSizeConstraint",
	"UISizeConstraint"
)

minigameUI.minigameInner = requiredAuthoredNode(minigameUI.minigame, "InnerStroke", "Frame")
requireLegacyDecorationSet(minigameUI.minigameInner, {
	{ "InnerCorner", "UICorner" },
	{ "InnerOutline", "UIStroke" },
})
requireLegacyGloss(minigameUI.minigame, "PanelGloss")

minigameUI.minigameText = requiredAuthoredNode(minigameUI.minigame, "MinigameText", "TextLabel")
minigameUI.minigameTextSizeConstraint = requiredAuthoredNode(
	minigameUI.minigameText,
	"UITextSizeConstraint",
	"UITextSizeConstraint"
)

minigameUI.timingBar = requiredAuthoredNode(minigameUI.minigame, "Bar", "Frame")
requireLegacyDecorationSet(minigameUI.timingBar, {
	{ "BarCorner", "UICorner" },
	{ "BarOuterStroke", "UIStroke" },
	{ "BarHighlightStroke", "UIStroke" },
	{ "BarGradient", "UIGradient" },
})
minigameUI.zone = requiredAuthoredNode(minigameUI.timingBar, "Zone", "Frame")
requireLegacyDecorationSet(minigameUI.zone, {
	{ "ZoneCorner", "UICorner" },
	{ "ZoneStroke", "UIStroke" },
	{ "ZoneGradient", "UIGradient" },
})
requireLegacyGloss(minigameUI.zone, "ZoneGloss")
minigameUI.marker = requiredAuthoredNode(minigameUI.timingBar, "Marker", "Frame")
requireLegacyDecorationSet(minigameUI.marker, {
	{ "MarkerCorner", "UICorner" },
	{ "MarkerStroke", "UIStroke" },
})

minigameUI.catchButton = requiredAuthoredNode(minigameUI.minigame, "CatchButton", "TextButton")
requireLegacyDecorationSet(minigameUI.catchButton, {
	{ "ButtonCorner", "UICorner" },
	{ "ButtonBaseStroke", "UIStroke" },
	{ "UITextSizeConstraint", "UITextSizeConstraint" },
	{ "CatchOutline", "UIStroke" },
	{ "ButtonGradient", "UIGradient" },
})
requireLegacyGloss(minigameUI.catchButton, "ButtonGloss")

minigameUI.fishingGameContent = requiredAuthoredNode(
	minigameUI.minigame,
	"FishingGameContent",
	"Frame"
)
minigameUI.verticalPanel = requiredAuthoredNode(
	minigameUI.fishingGameContent,
	"VerticalFishingPanel",
	"Frame"
)
requireLegacyDecorationSet(minigameUI.verticalPanel, {
	{ "PanelCorner", "UICorner" },
	{ "PanelOuterStroke", "UIStroke" },
	{ "PanelHighlightStroke", "UIStroke" },
	{ "PanelGradient", "UIGradient" },
})
minigameUI.panelWater = requiredAuthoredNode(minigameUI.verticalPanel, "Water", "Frame")
requireLegacyDecorationSet(minigameUI.panelWater, {
	{ "WaterCorner", "UICorner" },
	{ "WaterStroke", "UIStroke" },
	{ "WaterGradient", "UIGradient" },
})
minigameUI.catchBar = requiredAuthoredNode(minigameUI.panelWater, "CatchBar", "Frame")
requireLegacyDecorationSet(minigameUI.catchBar, {
	{ "CatchBarCorner", "UICorner" },
	{ "CatchBarStroke", "UIStroke" },
	{ "CatchBarGradient", "UIGradient" },
})
requireLegacyGloss(minigameUI.catchBar, "CatchBarGloss")

minigameUI.fishMarker = requiredAuthoredNode(minigameUI.panelWater, "FishMarker", "Frame")
requireLegacyDecorationSet(minigameUI.fishMarker, {
	{ "FishMarkerCorner", "UICorner" },
	{ "FishMarkerStroke", "UIStroke" },
})
minigameUI.fishMarkerImage = requiredAuthoredNode(minigameUI.fishMarker, "FishImage", "ImageLabel")
minigameUI.fishMarkerLabel = requiredAuthoredNode(
	minigameUI.fishMarker,
	"FishMarkerLabel",
	"TextLabel"
)

minigameUI.progressTrack = requiredAuthoredNode(
	minigameUI.fishingGameContent,
	"ProgressTrack",
	"Frame"
)
requireLegacyDecorationSet(minigameUI.progressTrack, {
	{ "ProgressCorner", "UICorner" },
	{ "ProgressStroke", "UIStroke" },
})
minigameUI.progressFill = requiredAuthoredNode(minigameUI.progressTrack, "ProgressFill", "Frame")
requireLegacyDecorationSet(minigameUI.progressFill, {
	{ "ProgressFillCorner", "UICorner" },
	{ "ProgressFillGradient", "UIGradient" },
})
minigameUI.minigameFishInfo = requiredAuthoredNode(
	minigameUI.fishingGameContent,
	"MinigameFishInfo",
	"TextLabel"
)
minigameUI.minigameProgressText = requiredAuthoredNode(
	minigameUI.fishingGameContent,
	"MinigameProgressText",
	"TextLabel"
)
minigameUI.minigameInstruction = requiredAuthoredNode(
	minigameUI.fishingGameContent,
	"MinigameInstruction",
	"TextLabel"
)

minigameUI.root = root
do
	local moduleScript = script:FindFirstChild("FishingMinigameModernUI")
	if moduleScript then
		local ok, moduleOrError = pcall(require, moduleScript)
		if ok and type(moduleOrError) == "table" then
			local buildOk, resultOrError = pcall(moduleOrError.build, {
				ui = minigameUI,
				GameConfig = GameConfig,
			})
			if buildOk then
				minigameUI.modern = resultOrError
			else
				warn("[FishingClient] Modern fishing minigame UI failed to build:", resultOrError)
			end
		else
			warn("[FishingClient] Modern fishing minigame UI failed to load:", moduleOrError)
		end
	end
end

local CAST_PRESENTATION_DURATION = 1.25
local castPresentationUntil = 0

local CastPower = {
	running = false,
}

CastPower.content = requiredAuthoredNode(minigameUI.minigame, "CastPowerContent", "Frame")
CastPower.content.Visible = false
CastPower.title = requiredAuthoredNode(CastPower.content, "CastPowerTitle", "TextLabel")
requiredAuthoredNode(CastPower.title, "UITextSizeConstraint", "UITextSizeConstraint")

CastPower.track = requiredAuthoredNode(CastPower.content, "CastPowerTrack", "Frame")
requireLegacyDecorationSet(CastPower.track, {
	{ "CastTrackCorner", "UICorner" },
	{ "CastTrackOuterStroke", "UIStroke" },
	{ "CastTrackHighlightStroke", "UIStroke" },
	{ "CastTrackGradient", "UIGradient" },
})
CastPower.perfectZone = requiredAuthoredNode(CastPower.track, "PerfectTimingZone", "Frame")
requireLegacyDecorationSet(CastPower.perfectZone, {
	{ "PerfectZoneCorner", "UICorner" },
	{ "PerfectZoneStroke", "UIStroke" },
	{ "PerfectZoneGradient", "UIGradient" },
})
CastPower.fill = requiredAuthoredNode(CastPower.track, "PowerFill", "Frame")
requireLegacyDecorationSet(CastPower.fill, {
	{ "PowerFillCorner", "UICorner" },
	{ "PowerFillGradient", "UIGradient" },
})
CastPower.marker = requiredAuthoredNode(CastPower.track, "BobberMarker", "Frame")
requireLegacyDecorationSet(CastPower.marker, {
	{ "BobberCorner", "UICorner" },
	{ "BobberStroke", "UIStroke" },
})

CastPower.value = requiredAuthoredNode(CastPower.content, "CastPowerValue", "TextLabel")
CastPower.status = requiredAuthoredNode(CastPower.content, "CastPowerStatus", "TextLabel")
CastPower.hint = requiredAuthoredNode(CastPower.content, "CastPowerHint", "TextLabel")

local castPowerModernUI = nil
do
	local moduleScript = script:FindFirstChild("CastPowerModernUI")
	if moduleScript then
		local ok, moduleOrError = pcall(require, moduleScript)
		if ok and type(moduleOrError) == "table" then
			local buildOk, buildError = pcall(moduleOrError.build, root)
			if buildOk then
				castPowerModernUI = moduleOrError
			else
				warn("[FishingClient] Modern cast UI failed to build:", buildError)
			end
		else
			warn("[FishingClient] Modern cast UI failed to load:", moduleOrError)
		end
	end
end

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
	if not Remote.GetCastConfig then
		Remote.GetCastConfig = Remotes:FindFirstChild("GetCastConfig")
	end

	if not Remote.GetCastConfig then
		showToast("Cast meter is still syncing. Try again.")
		return nil
	end

	local success, response = pcall(function()
		return Remote.GetCastConfig:InvokeServer(biomeId)
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
	if castPowerModernUI then
		castPowerModernUI.updateVisual(clampedPower, targetPower)
	end

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
	if not castPowerModernUI then
		return
	end

	local sparkleTemplate = castPowerModernUI.getSparkleTemplate()
	local sparkleParent = castPowerModernUI.getSparkleParent()
	if not (sparkleTemplate and sparkleParent) then
		return
	end

	for index = 1, 5 do
		local sparkle = sparkleTemplate:Clone()
		sparkle.Name = "PerfectCastSparkle"
		sparkle.BackgroundColor3 = index % 2 == 0 and Color3.fromRGB(255, 245, 156) or Color3.fromRGB(255, 255, 255)
		sparkle.Position = UDim2.new(0.34 + (index * 0.06), 0, 0.42 + ((index % 2) * 0.12), 0)
		sparkle.Visible = true
		sparkle.Parent = sparkleParent
		if not castPowerModernUI.retainSparkle() then
			sparkle:Destroy()
			return
		end
		task.delay(0.5 + (index * 0.04), function()
			if sparkle.Parent then
				sparkle:Destroy()
			end
			castPowerModernUI.releaseSparkle()
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
		if minigameUI.modern then
			minigameUI.modern.fishImage.Image = imageId
		end
	else
		minigameUI.fishMarkerImage.Image = ""
		minigameUI.fishMarkerImage.Visible = false
		minigameUI.fishMarkerLabel.Visible = true
		if minigameUI.modern then
			minigameUI.modern.fishImage.Image = ""
		end
	end
end

local function setMinigameVisible(visible)
	if castPowerModernUI then
		castPowerModernUI.setVisible(false)
	end
	if minigameUI.modern then
		minigameUI.modern.panel.Visible = false
	end
	minigameUI.minigame.Visible = visible

	-- Never blur the world for fishing UI.
	fishingBlur.Enabled = false
	fishingBlur.Size = 0
end

function minigameUI.setFishingVisible(visible)
	if castPowerModernUI then
		castPowerModernUI.setVisible(false)
	end
	CastPower.content.Visible = false

	if minigameUI.modern then
		minigameUI.minigame.Visible = false
		minigameUI.modern.panel.Visible = visible
	else
		setMinigameVisible(visible)
	end

	-- Never blur the world for the modern minigame.
	fishingBlur.Enabled = false
	fishingBlur.Size = 0
end

local function setCastPowerVisible(visible)
	if minigameUI.modern then
		minigameUI.modern.panel.Visible = false
	end
	if castPowerModernUI then
		minigameUI.minigame.Visible = false
		CastPower.content.Visible = false
		castPowerModernUI.setVisible(visible)
	else
		setMinigameVisible(visible)
		CastPower.content.Visible = visible
	end

	fishingBlur.Enabled = false
	fishingBlur.Size = 0
end

local toast = assert(
	AuthoredUi.getSurface("Toast"),
	"FishingGui.Toast is missing from the authored StarterGui hierarchy"
)

local toastRevision = 0

local toastResponsive = {
	desktopPosition = toast.Position,
	desktopSize = toast.Size,
	desktopTextSize = toast.TextSize,
	viewportConnection = nil,
}

function toastResponsive.update()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local isMobile = math.min(viewport.X, viewport.Y) <= 600
	local textSize = isMobile and 10 or toastResponsive.desktopTextSize
	local horizontalPadding = isMobile and 20 or 30
	local verticalPadding = isMobile and 8 or 12
	local minimumWidth = isMobile and 220 or toastResponsive.desktopSize.X.Offset
	local maximumWidth = math.max(minimumWidth, math.floor(viewport.X * 0.84))
	local message = toast.Text or ""

	-- Measure each notice instead of forcing every fish/bait combination into
	-- the old fixed 300/520-pixel banner. Long messages expand horizontally;
	-- on a narrow screen they wrap and the black box grows vertically.
	local unwrappedBounds = Services.TextService:GetTextSize(
		message,
		textSize,
		toast.Font,
		Vector2.new(100000, 100000)
	)
	local requiredWidth = math.clamp(
		math.ceil(unwrappedBounds.X + horizontalPadding),
		minimumWidth,
		maximumWidth
	)
	local wrappedBounds = Services.TextService:GetTextSize(
		message,
		textSize,
		toast.Font,
		Vector2.new(math.max(1, requiredWidth - horizontalPadding), 100000)
	)
	local minimumHeight = isMobile and 24 or toastResponsive.desktopSize.Y.Offset
	local requiredHeight = math.max(
		minimumHeight,
		math.ceil(wrappedBounds.Y + verticalPadding)
	)

	toast.TextSize = textSize
	toast.TextWrapped = unwrappedBounds.X + horizontalPadding > maximumWidth
	toast.Size = UDim2.fromOffset(requiredWidth, requiredHeight)
	if isMobile then
		-- Mobile fishing prompts should stay compact and above the action UI.
		toast.Position = UDim2.new(0.5, 0, 0, 4)
	else
		toast.Position = toastResponsive.desktopPosition
	end
end

function toastResponsive.bindCamera(camera)
	if toastResponsive.viewportConnection then
		toastResponsive.viewportConnection:Disconnect()
		toastResponsive.viewportConnection = nil
	end
	if camera then
		toastResponsive.viewportConnection = camera:GetPropertyChangedSignal("ViewportSize")
			:Connect(toastResponsive.update)
	end
	toastResponsive.update()
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	toastResponsive.bindCamera(workspace.CurrentCamera)
end)
toastResponsive.bindCamera(workspace.CurrentCamera)

function showToast(message, duration)
	toastRevision += 1
	local revision = toastRevision

	statusText.Text = message
	toast.Text = message
	toastResponsive.update()
	toast.Visible = true

	-- duration <= 0 keeps the banner visible until the next message replaces it.
	if duration == nil then
		duration = 3
	end

	if duration > 0 then
		task.delay(duration, function()
			if toastRevision == revision then
				toast.Visible = false
			end
		end)
	end
end

do
	local created, controllerOrError = pcall(Modules.AquariumViewerModernUI.create, {
		player = player,
		playerGui = playerGui,
		GameConfig = GameConfig,
		Remote = Remote,
		showToast = showToast,
		onClose = function()
			panelCollapsed = true
			updatePanelCollapsed()
		end,
	})
	if created then
		AuthoredUi.aquariumController = controllerOrError
	else
		AuthoredUi.aquariumController = nil
		warn("Aquarium Viewer initialization was skipped without stopping FishingClient:", controllerOrError)
	end
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
	guiPrimitives.addCorner(card, 8)
	local stroke = guiPrimitives.addStroke(card, Color3.fromRGB(60, 72, 90), 1)
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
	guiPrimitives.addCorner(badge, 10)
	guiPrimitives.addStroke(badge, Color3.fromRGB(255, 232, 232), 1).Transparency = 0.1

	local label = guiPrimitives.makeText(badge, count > 99 and "99+" or tostring(count), 11, Color3.fromRGB(255, 255, 255), true)
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
		if hudRefs.updateQuestBadgeCount then
			hudRefs.updateQuestBadgeCount(0)
		end
		return
	end

	updateCoinsHud(state.Coins)
	updateXPHud(state)
	if hudRefs.updateQuestBadgeCount then
		hudRefs.updateQuestBadgeCount(AuthoredUi.countClaimableQuests(state))
	end
end

local renderContent

local function isLilyshoreIslandInstance(instance)
	while instance do
		if instance.Name == "LilyshoreIsland" or instance.Name == "LilyshoreFishingZone" or instance.Name == "BeginnerPondArea" or instance.Name == "BeginnerPond_ExtraLarge" or instance.Name == "Beginner Pond" then
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

	local biomeIdAtPosition = getGroundBiomeId(rootPart.Position, character)

	if not biomeIdAtPosition then
		for _, biomeId in ipairs(GameConfig.BiomeOrder) do
			local biome = GameConfig.Biomes[biomeId]
			local center = biome.position
			local dx = math.abs(rootPart.Position.X - center.X)
			local dz = math.abs(rootPart.Position.Z - center.Z)
			local rangeX = 58
			local rangeZ = 54

			if dx <= rangeX and dz <= rangeZ then
				biomeIdAtPosition = biomeId
				break
			end
		end
	end

	if not biomeIdAtPosition
		or not Modules.FishingWater.isNearWater(rootPart.Position, { character })
	then
		return nil
	end

	return biomeIdAtPosition
end

local function getForwardFishingWaterSurface()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end

	return Modules.FishingWater.findCastSurface(
		rootPart.Position,
		rootPart.CFrame.LookVector,
		rootPart.CFrame.RightVector,
		{ character }
	)
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

	local actualIslandId = islandState.getActualIslandId()
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

	return (state and islandState.normalizeIslandId(state.ActualLocation)) or "Lobby"
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
	-- The charge meter replaces the AutoFish interaction until the cast is
	-- released. refreshCenterControls uses the same state while rendering.
	centerAutoButton.Visible = false
	setCastPowerVisible(true)
	CastPower.title.Text = "Hold to charge. Release to cast."
	CastPower.status.Text = "Release in the green zone for a Perfect cast."
	CastPower.hint.Text = string.format("Left start - %s speed", castConfig.speedName or "Random")
	if castPowerModernUI then
		castPowerModernUI.setInstruction("Hold to charge. Release to cast.")
	end
	minigameUI.fishingGameContent.Visible = false
	minigameUI.catchButton.Visible = false
	minigameUI.timingBar.Visible = false
	minigameUI.zone.Visible = false
	minigameUI.marker.Visible = false

	minigameUI.minigameText.Text = "Cast into " .. ((biome and biome.displayName) or "the water")
	guiPrimitives.forcePureWhiteText(minigameUI.minigameText)
	guiPrimitives.forcePureWhiteText(minigameUI.catchButton)
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
		setCastPowerVisible(false)
	end

	local function finishCast()
		if finished then
			return
		end

		if not isHoldingFishingRod() then
			if activeMinigameCleanup then
				activeMinigameCleanup()
			end
			toolSwitchLock.set(false)
			fishingBusy = false
			setCastPowerVisible(false)
			showToast("Hold your fishing rod before fishing.")
			renderContent()
			return
		end

		-- Start the combined cast/plop cue before the release presentation so
		-- its casting transient lines up with the rod animation.
		FishingSFX.playCast()
		toolSwitchLock.set(true)
		finished = true
		disconnectAll()
		activeMinigameCleanup = nil
		CastPower.running = false
		minigameUI.fishingGameContent.Visible = false
		castPresentationUntil = os.clock() + CAST_PRESENTATION_DURATION
		local rating, displayName = CastPower.getLocalRating(power)
		CastPower.title.Text = displayName .. " Cast!"
		CastPower.status.Text = "Bobber landed. Waiting for a bite..."
		minigameUI.minigameText.Text = displayName .. " Cast! Waiting for a bite..."
		guiPrimitives.forcePureWhiteText(minigameUI.minigameText)
		if rating == "Perfect" then
			CastPower.showSparkle()
		end
		CastPower.content.Visible = false
		setCastPowerVisible(false)

		-- Replace the small minigame header with the existing black banner.
		-- Keep this message visible until the fish actually bites.
		showToast(displayName .. " Cast! Waiting for a bite...", 0)

		Remote.StartFishing:FireServer({
			biomeId = biomeId,
			castPower = math.clamp(power, 0, 1),
			castAttemptId = castConfig.attemptId,
		})
		renderContent()
	end

	inputBeganConnection = Services.UserInputService.InputBegan:Connect(function(input)
		if CastPower.isInput(input) then
			holding = true
			hasHeld = true
		end
	end)

	inputEndedConnection = Services.UserInputService.InputEnded:Connect(function(input)
		if CastPower.isInput(input) and hasHeld then
			holding = false
			finishCast()
		end
	end)

	renderConnection = Services.RunService.RenderStepped:Connect(function(deltaTime)
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
		showToast("Move closer to the water before fishing.")
		return
	end

	if not getForwardFishingWaterSurface() then
		showToast("Face the nearby water before casting.")
		return
	end

	AuthoredUi.closeQuest()
	panelCollapsed = true
	updatePanelCollapsed()

	local biome = GameConfig.Biomes[biomeId]
	fishingBusy = true

	-- Do not show the old "Casting in <island>..." toast.
	-- Invalidate any delayed toast hide and clear the black banner immediately.
	toastRevision += 1
	toast.Visible = false
	statusText.Text = ""

	if not CastPower.run(biomeId) then
		toolSwitchLock.set(false)
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
	centerAutoButton.Visible = not CastPower.running
	centerBaitText.Visible = false
	centerCastButton.Text = fishingBusy and "Fishing..." or "Tap"
	centerCastButton.AutoButtonColor = state ~= nil and biomeId ~= nil and not fishingBusy
	centerAutoButton.Text = autoEnabled and "AutoFish ON" or "AutoFish OFF"
	centerBaitText.Text = state and baitHelpers.getEquippedBaitDisplay() or "Bait: Basic Bait (Unlimited)"
	guiPrimitives.forcePureWhiteText(centerTitle)
	centerCastButton.TextColor3 = Color3.fromRGB(10, 20, 30)
	centerCastButton.TextStrokeTransparency = 1
	guiPrimitives.forcePureWhiteText(centerAutoButton)

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
	Remote.ToggleAutoFish:FireServer()
end)

local suppressLegacyBagFishdexPanels

local function setTab(tabName)
	local isUtilityPanel = tabName == "Bag" or tabName == "Fishdex"
	if isUtilityPanel
		and (Services.UserInputService:GetFocusedTextBox() ~= nil
			or toolSwitchLock.active
			or fishingBusy
			or minigameRunning
			or CastPower.running)
	then
		return
	end

	local now = os.clock()

	-- PanelEvent and ToolHotbarBinder can both report the same physical click.
	-- Process only the first report so slot 3 truly works as a one-click toggle.
	if lastPanelTabRequestName == tabName
		and now - lastPanelTabRequestAt < PANEL_TAB_DUPLICATE_WINDOW then
		return
	end

	lastPanelTabRequestName = tabName
	lastPanelTabRequestAt = now
	AuthoredUi.closeQuest()
	setSettingsVisible(false)

	if tabName == "Fishdex"
		and activeTab == "Fishdex"
		and panelCollapsed == false then
		panelCollapsed = true
		updatePanelCollapsed()
		return
	end

	activeTab = tabName
	panelCollapsed = false
	updatePanelCollapsed()
	renderContent()

	if tabName == "Bag" or tabName == "Fishdex" then
		suppressLegacyBagFishdexPanels()
	end
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
	AuthoredUi.closeQuest()
	panelCollapsed = true
	updatePanelCollapsed()
	setSettingsVisible(true)
end)

hudControls.quests.MouseButton1Click:Connect(function()
	local controller = AuthoredUi.questController
	if not controller then
		warn("[FishingClient] Quest UI is unavailable")
		return
	end

	local shouldOpen = not controller:IsVisible()
	setSettingsVisible(false)
	panelCollapsed = true
	updatePanelCollapsed()
	setBiomeWarpVisible(false)
	setFishmongerSellVisible(false)
	setRodShopVisible(false)
	controller:SetVisible(shouldOpen)
end)

hudControls.shop.MouseButton1Click:Connect(function()
	print("Shop clicked")
	setTab("Shop")
end)

ToolHotbarBinder.start({
	player = player,
	setTab = setTab,
	hasPanel = hasHudPanel,
	isToolSwitchLocked = function()
		return toolSwitchLock.active
	end,
	watchLegacyAquariumViewerTools = legacyRightUiCleanup.watchLegacyAquariumViewerTools,
})

local function refreshLeaderboardTabIfOpen()
	if activeTab == "Leaderboard" then
		renderContent()
	end
end

Services.Players.PlayerAdded:Connect(refreshLeaderboardTabIfOpen)
Services.Players.PlayerRemoving:Connect(refreshLeaderboardTabIfOpen)

local function openRodShop()
	renderRodShopOptions()
	setRodShopVisible(true)
end

if Remote.OpenRodShop then
	Remote.OpenRodShop.OnClientEvent:Connect(openRodShop)
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

if Remote.OpenAquariumHub then
	Remote.OpenAquariumHub.OnClientEvent:Connect(openAquariumHub)
else
	warn("OpenAquariumHub remote was not available; aquarium hub kiosk is disabled until remotes resync.")
end

local VALID_SHOP_TABS = {
	Passes = true,
	Items = true,
	Coins = true,
	Upgrades = true,
}

local function openShop(requestedTab)
	if type(requestedTab) == "string" and VALID_SHOP_TABS[requestedTab] then
		activeShopTab = requestedTab
		if shopModernUI and type(shopModernUI.setSelectedTab) == "function" then
			shopModernUI.setSelectedTab(requestedTab)
		end
	end

	setTab("Shop")
end

if Remote.OpenShop then
	Remote.OpenShop.OnClientEvent:Connect(openShop)
else
	warn("OpenShop remote was not available; world shop prompts are disabled until remotes resync.")
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

local aquariumViewerFallbackButton = assert(
	AuthoredUi.getSurface("AquariumViewerFallbackButton"),
	"FishingGui.AquariumViewerFallbackButton is missing from the authored hierarchy"
)
assert(
	aquariumViewerFallbackButton:IsA("TextButton"),
	"FishingGui.AquariumViewerFallbackButton must be a TextButton"
)
local function updateAquariumViewerFallbackButtonLayout()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local compactLayout = Services.UserInputService.TouchEnabled
		or math.min(viewport.X, viewport.Y) <= 700
	local buttonWidth = compactLayout and 168 or 210
	local buttonHeight = compactLayout and 42 or 53
	local seaStarsHud = AuthoredUi.getSurface("SeaStarsHud")
	local rootSurface = AuthoredUi.getSurface("Root")
	local origin = rootSurface and rootSurface.AbsolutePosition or Vector2.zero

	aquariumViewerFallbackButton.AnchorPoint = Vector2.new(1, 0)
	aquariumViewerFallbackButton.Size = UDim2.fromOffset(buttonWidth, buttonHeight)
	if seaStarsHud then
		local rightEdge = seaStarsHud.AbsolutePosition.X + seaStarsHud.AbsoluteSize.X - origin.X
		local topEdge = seaStarsHud.AbsolutePosition.Y + seaStarsHud.AbsoluteSize.Y + 6 - origin.Y
		aquariumViewerFallbackButton.Position = UDim2.fromOffset(
			math.floor(rightEdge + 0.5),
			math.floor(topEdge + 0.5)
		)
	else
		aquariumViewerFallbackButton.Position = UDim2.new(1, -18, 0, 160)
	end
end

updateAquariumViewerFallbackButtonLayout()
do
	local seaStarsHud = AuthoredUi.getSurface("SeaStarsHud")
	if seaStarsHud then
		seaStarsHud:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateAquariumViewerFallbackButtonLayout)
		seaStarsHud:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateAquariumViewerFallbackButtonLayout)
	end
	local rootSurface = AuthoredUi.getSurface("Root")
	if rootSurface then
		rootSurface:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateAquariumViewerFallbackButtonLayout)
		rootSurface:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateAquariumViewerFallbackButtonLayout)
	end
end
aquariumViewerFallbackButton.Visible = false
aquariumViewerFallbackButton.MouseButton1Click:Connect(openAquariumHub)

local function isAquariumEditorOpen()
	local editorGui = playerGui:FindFirstChild("AquariumFreePlacementGui")
	if not editorGui or not editorGui:IsA("ScreenGui") or not editorGui.Enabled then
		return false
	end

	local editorPanel = editorGui:FindFirstChild("ModernAquariumEditor", true)
	local backButton = editorGui:FindFirstChild("BackToAquariumEditor", true)
	return (editorPanel and editorPanel:IsA("GuiObject") and editorPanel.Visible)
		or (backButton and backButton:IsA("GuiObject") and backButton.Visible)
end

local function updateAquariumViewerFallbackButton()
	local shouldShow = state ~= nil
		and isInAquariumHub()
		and not minigameRunning
		and not CastPower.running
		and not (AuthoredUi.aquariumController and AuthoredUi.aquariumController:IsVisible())
		and not isAquariumEditorOpen()
	aquariumViewerFallbackButton.Visible = shouldShow
end

local function refreshTabs()
	guiPrimitives.clearChildren(mainPanelUI.tabs)
	mainPanelUI.tabs.Visible = false
end

local function renderBiomesTab()
	for _, biomeId in ipairs(GameConfig.BiomeOrder) do
		local biome = GameConfig.Biomes[biomeId]
		local unlocked = islandState.getUnlockedIslands()[biomeId]
		local current = islandState.getCurrentIslandId() == biomeId

		local card = makeCard(mainPanelUI.content, 96)
		local name = guiPrimitives.makeText(card, biome.displayName, 16, biome.color, true)
		name.Position = UDim2.new(0, 12, 0, 8)
		name.Size = UDim2.new(1, -132, 0, 22)

		local info = guiPrimitives.makeText(card, "Unlock Island: " .. GameConfig.getBiomeUnlockText(biomeId), 13, Color3.fromRGB(190, 204, 220), false)
		info.Position = UDim2.new(0, 12, 0, 34)
		info.Size = UDim2.new(1, -132, 0, 20)

		local fishCount = guiPrimitives.makeText(card, "Species: " .. #biome.fish, 12, Color3.fromRGB(143, 160, 180), false)
		fishCount.Position = UDim2.new(0, 12, 0, 58)
		fishCount.Size = UDim2.new(1, -132, 0, 18)

		local label = current and "Selected" or (unlocked and "Select" or "Unlock")
		local color = unlocked and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(53, 130, 246)
		if current then
			color = Color3.fromRGB(91, 104, 124)
		end

		local button = guiPrimitives.makeButton(card, label, color)
		button.Position = UDim2.new(1, -110, 0, 26)
		button.Size = UDim2.new(0, 94, 0, 36)
		button.MouseButton1Click:Connect(function()
			if unlocked then
				Remote.TeleportTo:FireServer(biomeId)
			else
				Remote.UnlockBiome:FireServer(biomeId)
			end
		end)
	end
end

local function renderBagTab()
	-- Bag must never use the old MainPanel.
	mainPanelUI.panel.Visible = false

	local bagModuleScript = script:FindFirstChild("BagModernUI")
		or script.Parent:FindFirstChild("BagModernUI")

	if not bagModuleScript then
		warn(
			"[FishingClient] BagModernUI is missing. "
				.. "The old Bag panel will remain hidden."
		)
		return
	end

	local ok, bagModule = pcall(require, bagModuleScript)
	if not ok or not bagModule or not bagModule.show then
		warn(
			"[FishingClient] BagModernUI failed to load. "
				.. "The old Bag panel will remain hidden. Error: "
				.. tostring(bagModule)
		)
		return
	end

	local showOk, showError = xpcall(function()
		bagModule.show({
			parent = root,
			state = state,
			GameConfig = GameConfig,
			ResourceConfig = ResourceConfig,
			getBaitCount = baitHelpers.getBaitCount,
			equipRod = function(rodId)
				Remote.BuyRod:FireServer(rodId, "Equip")
			end,
			equipBait = function(baitId)
				remoteActions.fireBaitAction("Equip", baitId)
			end,
			displayFish = function(fish, index)
				Remote.AquariumAction:FireServer(
					"DisplayFish",
					fish.serial,
					index
				)
			end,
			onClose = function()
				panelCollapsed = true
				updatePanelCollapsed()
			end,
		})
	end, debug.traceback)

	if not showOk then
		warn(
			"[FishingClient] Modern Bag show failed. "
				.. "The old Bag panel will remain hidden.\n"
				.. tostring(showError)
		)
	end

	mainPanelUI.panel.Visible = false
end

function fishdexModernUI.normalizeAssetId(assetId)
	if assetId == nil then
		return ""
	end

	local textId = tostring(assetId)
	if textId == "" then
		return ""
	end

	if string.find(textId, "rbxassetid://", 1, true) then
		return textId
	end

	local numericId = tonumber(textId)
	if numericId then
		return "rbxassetid://" .. tostring(math.floor(numericId))
	end

	return textId
end

function fishdexModernUI.getFishdexFishImage(fish)
	local key = fish.imageKey or fish.id
	local configured = ""

	if GameConfig.getFishImage then
		configured = GameConfig.getFishImage(key) or GameConfig.getFishImage(fish.id) or ""
	end

	if configured == "" then
		configured = FISHDEX_FALLBACK_IMAGES[fish.id]
			or FISHDEX_FALLBACK_IMAGES[key]
			or FISHDEX_FALLBACK_IMAGES.SmallFish
	end

	return fishdexModernUI.normalizeAssetId(configured)
end

function fishdexModernUI.getFishdexRarityImage(rarity)
	if rarity == "Mythical" then
		rarity = "Mythic"
	end

	return FISHDEX_ASSETS[rarity] or FISHDEX_ASSETS.Common
end

function fishdexModernUI.isFishdexEntryDiscovered(fish)
	if not state or type(state.Fishdex) ~= "table" then
		return false
	end

	for _, key in ipairs({ fish.id, fish.name, fish.imageKey }) do
		if key ~= nil then
			local amount = state.Fishdex[key]
			if amount == true or (tonumber(amount) or 0) > 0 then
				return true
			end
		end
	end

	return false
end

function fishdexModernUI.getFishdexCollectionCounts()
	local discovered = 0
	local total = 0

	for _, biomeId in ipairs(GameConfig.BiomeOrder or GameConfig.IslandOrder or {}) do
		local biome = GameConfig.Biomes[biomeId]
		if biome and type(biome.fish) == "table" then
			for _, fish in ipairs(biome.fish) do
				total += 1
				if fishdexModernUI.isFishdexEntryDiscovered(fish) then
					discovered += 1
				end
			end
		end
	end

	return discovered, total
end

local FISHDEX_UI_SIZE_MULTIPLIER = 0.68
-- Fill approximately 89% of a landscape phone's usable width, matching the
-- approved mobile reference while retaining a safe margin for device edges.
local FISHDEX_MOBILE_SIZE_MULTIPLIER = 0.98

function fishdexModernUI.updateFishdexResponsiveScale()
	if not fishdexModernUI.root or not fishdexModernUI.scale then
		return
	end

	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1536, 1024)
	local topLeftInset, bottomRightInset = Services.GuiService:GetGuiInset()
	local usableViewport = Vector2.new(
		math.max(1, viewport.X - topLeftInset.X - bottomRightInset.X),
		math.max(1, viewport.Y - topLeftInset.Y - bottomRightInset.Y)
	)
	local scale = math.min(
		(usableViewport.X * 0.97) / 1536,
		(usableViewport.Y * 0.94) / 1024
	)

	local isMobile = math.min(usableViewport.X, usableViewport.Y) <= 600
	local deviceMultiplier = if isMobile
		then FISHDEX_MOBILE_SIZE_MULTIPLIER
		else FISHDEX_UI_SIZE_MULTIPLIER

	fishdexModernUI.scale.Scale = math.clamp(
		scale * deviceMultiplier,
		0.10,
		1
	)
	fishdexModernUI.root.Position = UDim2.new(
		0.5,
		math.round((bottomRightInset.X - topLeftInset.X) * 0.5),
		0.5,
		math.round((bottomRightInset.Y - topLeftInset.Y) * 0.5)
	)
end

function fishdexModernUI.setFishdexTabSelected(tabId)
	fishdexModernUI.selectedIsland = tabId

	for id, button in pairs(fishdexModernUI.tabButtons) do
		local stroke = button:FindFirstChild("SelectedStroke")
		if stroke then
			stroke.Transparency = id == tabId and 0 or 1
		end
	end
end

function fishdexModernUI.clearFishdexCards()
	if not fishdexModernUI.cardsHolder then
		return
	end

	for _, child in ipairs(fishdexModernUI.cardsHolder:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function fishdexModernUI.makeFishdexCard(fish, layoutOrder)
	local discovered = fishdexModernUI.isFishdexEntryDiscovered(fish)
	local authoredTemplate = fishdexModernUI.root
		and fishdexModernUI.root:FindFirstChild("FishCardTemplate")
	if authoredTemplate and authoredTemplate:IsA("ImageLabel") then
		local card = authoredTemplate:Clone()
		local image = card:FindFirstChild("FishImage")
		local name = card:FindFirstChild("FishName")
		local badge = card:FindFirstChild("RarityBadge")
		local rarity = badge and badge:FindFirstChild("RarityText")
		if image and image:IsA("ImageLabel")
			and name and name:IsA("TextLabel")
			and badge and badge:IsA("ImageLabel")
			and rarity and rarity:IsA("TextLabel")
		then
			card.Name = tostring(fish.id) .. "Card"
			card.LayoutOrder = layoutOrder
			card.Visible = true

			image.Image = fishdexModernUI.getFishdexFishImage(fish)
			image.ImageColor3 = discovered and Color3.new(1, 1, 1)
				or Color3.fromRGB(2, 8, 18)
			image.ImageTransparency = discovered and 0 or 0.04
			name.Text = discovered and (fish.name or tostring(fish.id)) or "???"
			badge.Image = fishdexModernUI.getFishdexRarityImage(fish.rarity)

			local rarityName = fish.rarity == "Mythical" and "Mythic" or fish.rarity
			rarity.Text = string.upper(rarityName)
			card.Parent = fishdexModernUI.cardsHolder
			return
		end
		card:Destroy()
		warn("[FishingClient] Authored FishCardTemplate is incomplete; using compatibility card construction")
	end

	local card = Instance.new("ImageLabel")
	card.Name = tostring(fish.id) .. "Card"
	card.BackgroundTransparency = 1
	card.Image = FISHDEX_ASSETS.FishBackground
	card.ScaleType = Enum.ScaleType.Stretch
	card.LayoutOrder = layoutOrder
	card.ZIndex = 203
	card.Parent = fishdexModernUI.cardsHolder

	local image = Instance.new("ImageLabel")
	image.Name = "FishImage"
	image.BackgroundTransparency = 1
	image.AnchorPoint = Vector2.new(0.5, 0)
	image.Position = UDim2.new(0.5, 0, 0.055, 0)
	image.Size = UDim2.new(0.69, 0, 0.48, 0)
	image.Image = fishdexModernUI.getFishdexFishImage(fish)
	image.ScaleType = Enum.ScaleType.Fit
	image.ImageColor3 = discovered and Color3.new(1, 1, 1) or Color3.fromRGB(2, 8, 18)
	image.ImageTransparency = discovered and 0 or 0.04
	image.ZIndex = 204
	image.Parent = card

	local name = Instance.new("TextLabel")
	name.Name = "FishName"
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(0.5, 0, 0.61, 0)
	name.Size = UDim2.new(0.88, 0, 0.14, 0)
	name.Font = Enum.Font.GothamBlack
	name.Text = discovered and (fish.name or tostring(fish.id)) or "???"
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeColor3 = Color3.new(0, 0, 0)
	name.TextStrokeTransparency = 0
	name.TextScaled = true
	name.ZIndex = 205
	name.Parent = card

	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MinTextSize = 15
	nameLimit.MaxTextSize = 38
	nameLimit.Parent = name

	local badge = Instance.new("ImageLabel")
	badge.Name = "RarityBadge"
	badge.BackgroundTransparency = 1
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0.70, 0)
	badge.Size = UDim2.new(1.04, 0, 0.38, 0)
	badge.Image = fishdexModernUI.getFishdexRarityImage(fish.rarity)
	badge.ScaleType = Enum.ScaleType.Stretch
	badge.ZIndex = 204
	badge.Parent = card

	local rarityName = fish.rarity == "Mythical" and "Mythic" or fish.rarity
	local rarityTextWidth = 0.43
	if rarityName == "Uncommon" or rarityName == "Mythic" then
		rarityTextWidth = 0.47
	elseif rarityName == "Legendary" then
		rarityTextWidth = 0.54
	end

	local rarity = Instance.new("TextLabel")
	rarity.Name = "RarityText"
	rarity.BackgroundTransparency = 1
	rarity.AnchorPoint = Vector2.new(0.5, 0.5)
	rarity.Position = UDim2.fromScale(0.5, 0.50)
	rarity.Size = UDim2.new(rarityTextWidth, 0, 0.42, 0)
	rarity.Font = Enum.Font.GothamBlack
	rarity.Text = string.upper(rarityName)
	rarity.TextColor3 = Color3.new(1, 1, 1)
	rarity.TextStrokeColor3 = Color3.new(0, 0, 0)
	rarity.TextStrokeTransparency = 0
	rarity.TextScaled = true
	rarity.TextXAlignment = Enum.TextXAlignment.Center
	rarity.TextYAlignment = Enum.TextYAlignment.Center
	rarity.ZIndex = 205
	rarity.Parent = badge

	local rarityLimit = Instance.new("UITextSizeConstraint")
	rarityLimit.MinTextSize = 10
	rarityLimit.MaxTextSize = 24
	rarityLimit.Parent = rarity
end

function fishdexModernUI.renderModernFishdexCards()
	if not fishdexModernUI.root then
		return
	end

	fishdexModernUI.clearFishdexCards()

	local layoutOrder = 0
	for _, biomeId in ipairs(GameConfig.BiomeOrder or GameConfig.IslandOrder or {}) do
		local biome = GameConfig.Biomes[biomeId]
		if biome and (fishdexModernUI.selectedIsland == "All" or fishdexModernUI.selectedIsland == biomeId) then
			for _, fish in ipairs(biome.fish or {}) do
				layoutOrder += 1
				fishdexModernUI.makeFishdexCard(fish, layoutOrder)
			end
		end
	end

	local discovered, total = fishdexModernUI.getFishdexCollectionCounts()
	if state and tonumber(state.FishdexTotal) and tonumber(state.FishdexTotal) > 0 then
		total = tonumber(state.FishdexTotal)
	end

	if fishdexModernUI.collectionCount then
		fishdexModernUI.collectionCount.Text = string.format("%d / %d", discovered, total)
	end
end

function fishdexModernUI.addFishdexButtonPressFeedback(button)
	local originalPosition = button.Position
	local pressedPosition = UDim2.new(
		originalPosition.X.Scale,
		originalPosition.X.Offset,
		originalPosition.Y.Scale,
		originalPosition.Y.Offset + 5
	)

	local activeTween = nil
	local isPressed = false

	local function setPressed(pressed)
		isPressed = pressed

		if activeTween then
			activeTween:Cancel()
		end

		activeTween = Services.TweenService:Create(
			button,
			TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = pressed and pressedPosition or originalPosition,
				ImageColor3 = pressed and Color3.fromRGB(205, 205, 205) or Color3.new(1, 1, 1),
			}
		)
		activeTween:Play()
	end

	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			setPressed(true)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			setPressed(false)
		end
	end)

	button.MouseLeave:Connect(function()
		if isPressed then
			setPressed(false)
		end
	end)

	button.Activated:Connect(function()
		setPressed(false)
	end)
end

function fishdexModernUI.buildModernFishdex()
	if fishdexModernUI.root and fishdexModernUI.cardsHolder then
		return
	end

	local authoredHost = AuthoredUi.getSurface("ModernFishdex")
	local authoredScaffold = authoredHost and authoredHost:FindFirstChild("Panel")
	if authoredScaffold and authoredScaffold:IsA("GuiObject") then
		authoredScaffold.Visible = false
	end

	-- AuthoredUiV2 persists the complete v1615/v22 Fishdex base under the
	-- ModernFishdex host.  Bind behavior and live data to those instances; only
	-- fish cards themselves are data-driven clones created at runtime.
	local authoredRoot = authoredHost and authoredHost:FindFirstChild("ModernFishdex")
	if authoredRoot and authoredRoot:IsA("ImageLabel") then
		local authoredScale = authoredRoot:FindFirstChild("ResponsiveScale")
		local authoredClose = authoredRoot:FindFirstChild("CloseButton")
		local authoredScroll = authoredRoot:FindFirstChild("FishCardsScroll")
		local authoredCards = authoredScroll and authoredScroll:FindFirstChild("CardsHolder")
		local authoredCollection = authoredRoot:FindFirstChild("CollectionPanel")
		local authoredCount = authoredCollection and authoredCollection:FindFirstChild("CollectionCount")
		local authoredTabs = {
			All = authoredRoot:FindFirstChild("AllTab"),
			LilyshoreIsland = authoredRoot:FindFirstChild("LilyshoreIslandTab"),
			RiverbendIsland = authoredRoot:FindFirstChild("RiverbendIslandTab"),
			CoralCoastIsland = authoredRoot:FindFirstChild("CoralCoastIslandTab"),
		}

		local authoredComplete = authoredScale and authoredScale:IsA("UIScale")
			and authoredClose and authoredClose:IsA("ImageButton")
			and authoredScroll and authoredScroll:IsA("ScrollingFrame")
			and authoredCards and authoredCards:IsA("Frame")
			and authoredCount and authoredCount:IsA("TextLabel")
			and authoredTabs.All and authoredTabs.All:IsA("ImageButton")
			and authoredTabs.LilyshoreIsland and authoredTabs.LilyshoreIsland:IsA("ImageButton")
			and authoredTabs.RiverbendIsland and authoredTabs.RiverbendIsland:IsA("ImageButton")
			and authoredTabs.CoralCoastIsland and authoredTabs.CoralCoastIsland:IsA("ImageButton")
		for _, tabButton in pairs(authoredTabs) do
			authoredComplete = authoredComplete
				and tabButton ~= nil
				and tabButton:IsA("ImageButton")
		end

		if authoredComplete then
			fishdexModernUI.root = authoredRoot
			fishdexModernUI.host = authoredHost
			fishdexModernUI.scale = authoredScale
			fishdexModernUI.cardsScroll = authoredScroll
			fishdexModernUI.cardsHolder = authoredCards
			fishdexModernUI.collectionCount = authoredCount
			fishdexModernUI.tabButtons = authoredTabs

			authoredHost.Visible = authoredRoot.Visible
			authoredRoot:GetPropertyChangedSignal("Visible"):Connect(function()
				authoredHost.Visible = authoredRoot.Visible
			end)

			fishdexModernUI.addFishdexButtonPressFeedback(authoredClose)
			authoredClose.MouseButton1Click:Connect(function()
				panelCollapsed = true
				updatePanelCollapsed()
			end)

			for tabId, tabButton in pairs(authoredTabs) do
				fishdexModernUI.addFishdexButtonPressFeedback(tabButton)
				tabButton.MouseButton1Click:Connect(function()
					fishdexModernUI.setFishdexTabSelected(tabId)
					fishdexModernUI.renderModernFishdexCards()
				end)
			end

			local camera = workspace.CurrentCamera
			if camera then
				camera:GetPropertyChangedSignal("ViewportSize"):Connect(
					fishdexModernUI.updateFishdexResponsiveScale
				)
			end
			fishdexModernUI.updateFishdexResponsiveScale()
			fishdexModernUI.setFishdexTabSelected("All")
			return
		end
	end

	if authoredHost then
		warn("[FishingClient] Authored ModernFishdex v22 base is incomplete; Fishdex was not reconstructed at runtime")
		return
	end

	-- Keep the v1615 runtime canvas name even when it is mounted inside the
	-- authored StarterGui host. FishdexRebuildClient v22 deliberately discovers
	-- this ImageLabel by name and applies the final approved artwork/layout.
	local modernRoot = authoredHost and (
		authoredHost:FindFirstChild("ModernFishdex")
		or authoredHost:FindFirstChild("FishdexCanvas")
	)
	if modernRoot and modernRoot:IsA("ImageLabel") then
		for _, child in ipairs(modernRoot:GetChildren()) do
			child:Destroy()
		end
	else
		modernRoot = Instance.new("ImageLabel")
	end
	modernRoot.Name = "ModernFishdex"
	modernRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	modernRoot.Position = UDim2.fromScale(0.5, 0.46)
	modernRoot.Size = UDim2.fromOffset(1536, 1024)
	modernRoot.BackgroundTransparency = 1
	modernRoot.Image = FISHDEX_ASSETS.Backbone
	modernRoot.ScaleType = Enum.ScaleType.Stretch
	modernRoot.Visible = false
	modernRoot.ZIndex = 200
	modernRoot.Parent = authoredHost or root
	fishdexModernUI.root = modernRoot
	fishdexModernUI.host = authoredHost
	if authoredHost then
		authoredHost.Visible = false
		modernRoot:GetPropertyChangedSignal("Visible"):Connect(function()
			authoredHost.Visible = modernRoot.Visible
		end)
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale.Parent = modernRoot
	fishdexModernUI.scale = uiScale
	fishdexModernUI.updateFishdexResponsiveScale()

	local title = Instance.new("TextLabel")
	title.Name = "FishdexTitle"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(598, 20)
	title.Size = UDim2.fromOffset(410, 100)
	title.Font = Enum.Font.GothamBlack
	title.Text = "FISHDEX"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeColor3 = Color3.new(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.TextScaled = true
	title.ZIndex = 204
	title.Parent = modernRoot

	local titleLimit = Instance.new("UITextSizeConstraint")
	titleLimit.MinTextSize = 38
	titleLimit.MaxTextSize = 88
	titleLimit.Parent = title

	local closeButton = Instance.new("ImageButton")
	closeButton.Name = "CloseButton"
	closeButton.BackgroundTransparency = 1
	closeButton.Position = UDim2.fromOffset(1402, 35)
	closeButton.Size = UDim2.fromOffset(93, 93)
	closeButton.Image = FISHDEX_ASSETS.CloseButton
	closeButton.ScaleType = Enum.ScaleType.Fit
	closeButton.ZIndex = 210
	closeButton.Parent = modernRoot
	fishdexModernUI.addFishdexButtonPressFeedback(closeButton)
	closeButton.MouseButton1Click:Connect(function()
		panelCollapsed = true
		updatePanelCollapsed()
	end)

	local tabDefinitions = {
		{ id = "All", label = "All", image = FISHDEX_ASSETS.AllTab, position = UDim2.fromOffset(136, 153), size = UDim2.fromOffset(194, 82) },
		{ id = "LilyshoreIsland", label = "Lilyshore Island", image = FISHDEX_ASSETS.LilyshoreIslandTab, position = UDim2.fromOffset(356, 153), size = UDim2.fromOffset(345, 82) },
		{ id = "RiverbendIsland", label = "Riverbend Island", image = FISHDEX_ASSETS.RiverbendIslandTab, position = UDim2.fromOffset(725, 153), size = UDim2.fromOffset(342, 82) },
		{ id = "CoralCoastIsland", label = "Coral Coast Island", image = FISHDEX_ASSETS.CoralCoastIslandTab, position = UDim2.fromOffset(1090, 153), size = UDim2.fromOffset(335, 82) },
	}

	for _, definition in ipairs(tabDefinitions) do
		local button = Instance.new("ImageButton")
		button.Name = definition.id .. "Tab"
		button.BackgroundTransparency = 1
		button.Position = definition.position
		button.Size = definition.size
		button.Image = definition.image
		button.ScaleType = Enum.ScaleType.Stretch
		button.ZIndex = 205
		button.Parent = modernRoot
		fishdexModernUI.addFishdexButtonPressFeedback(button)

		-- Draw tab text separately instead of relying on text baked into the PNG.
		-- This keeps All and every island name visible at all responsive scales.
		local tabTitle = Instance.new("TextLabel")
		tabTitle.Name = "TabTitle"
		tabTitle.BackgroundTransparency = 1
		tabTitle.AnchorPoint = Vector2.new(0.5, 0.5)

		if definition.id == "All" then
			tabTitle.Position = UDim2.fromScale(0.64, 0.51)
			tabTitle.Size = UDim2.fromScale(0.42, 0.54)
		else
			tabTitle.Position = UDim2.fromScale(0.64, 0.51)
			tabTitle.Size = UDim2.fromScale(0.68, 0.54)
		end

		tabTitle.Font = Enum.Font.GothamBlack
		tabTitle.Text = definition.label
		tabTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
		tabTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		tabTitle.TextStrokeTransparency = 0
		tabTitle.TextScaled = true
		tabTitle.ZIndex = 207
		tabTitle.Parent = button

		local tabTitleSize = Instance.new("UITextSizeConstraint")
		tabTitleSize.MinTextSize = 11
		tabTitleSize.MaxTextSize = definition.id == "All" and 31 or 28
		tabTitleSize.Parent = tabTitle

		local selectedStroke = Instance.new("UIStroke")
		selectedStroke.Name = "SelectedStroke"
		selectedStroke.Color = Color3.fromRGB(160, 235, 255)
		selectedStroke.Thickness = 3
		selectedStroke.Transparency = 1
		selectedStroke.Parent = button

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 18)
		corner.Parent = button

		button.MouseButton1Click:Connect(function()
			fishdexModernUI.setFishdexTabSelected(definition.id)
			fishdexModernUI.renderModernFishdexCards()
		end)

		fishdexModernUI.tabButtons[definition.id] = button
	end

	local cardsScroll = Instance.new("ScrollingFrame")
	cardsScroll.Name = "FishCardsScroll"
	cardsScroll.Position = UDim2.fromOffset(137, 302)
	cardsScroll.Size = UDim2.fromOffset(1260, 578)
	cardsScroll.BackgroundTransparency = 1
	cardsScroll.BorderSizePixel = 0
	cardsScroll.ScrollBarThickness = 7
	cardsScroll.ScrollBarImageColor3 = Color3.fromRGB(41, 154, 255)
	cardsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	cardsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cardsScroll.ZIndex = 202
	cardsScroll.Parent = modernRoot
	fishdexModernUI.cardsScroll = cardsScroll

	local cardsHolder = Instance.new("Frame")
	cardsHolder.Name = "CardsHolder"
	cardsHolder.BackgroundTransparency = 1
	cardsHolder.Size = UDim2.new(1, -8, 0, 0)
	cardsHolder.AutomaticSize = Enum.AutomaticSize.Y
	cardsHolder.ZIndex = 202
	cardsHolder.Parent = cardsScroll
	fishdexModernUI.cardsHolder = cardsHolder

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(390, 270)
	grid.CellPadding = UDim2.fromOffset(30, 24)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = 3
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = cardsHolder

	local collection = Instance.new("ImageLabel")
	collection.Name = "CollectionPanel"
	collection.BackgroundTransparency = 1
	collection.Position = UDim2.fromOffset(1132, 885)
	collection.Size = UDim2.fromOffset(327, 103)
	collection.Image = FISHDEX_ASSETS.CollectionTab
	collection.ScaleType = Enum.ScaleType.Stretch
	collection.ZIndex = 206
	collection.Parent = modernRoot

	local collectionTitle = Instance.new("TextLabel")
	collectionTitle.Name = "CollectionTitle"
	collectionTitle.BackgroundTransparency = 1
	collectionTitle.Position = UDim2.new(0.35, 0, 0.14, 0)
	collectionTitle.Size = UDim2.new(0.56, 0, 0.30, 0)
	collectionTitle.Font = Enum.Font.GothamBlack
	collectionTitle.Text = "Collection"
	collectionTitle.TextColor3 = Color3.fromRGB(46, 231, 255)
	collectionTitle.TextStrokeColor3 = Color3.new(0, 0, 0)
	collectionTitle.TextStrokeTransparency = 0
	collectionTitle.TextScaled = true
	collectionTitle.ZIndex = 207
	collectionTitle.Parent = collection

	local collectionCount = Instance.new("TextLabel")
	collectionCount.Name = "CollectionCount"
	collectionCount.BackgroundTransparency = 1
	collectionCount.Position = UDim2.new(0.35, 0, 0.44, 0)
	collectionCount.Size = UDim2.new(0.55, 0, 0.40, 0)
	collectionCount.Font = Enum.Font.GothamBlack
	collectionCount.Text = "0 / 0"
	collectionCount.TextColor3 = Color3.new(1, 1, 1)
	collectionCount.TextStrokeColor3 = Color3.new(0, 0, 0)
	collectionCount.TextStrokeTransparency = 0
	collectionCount.TextScaled = true
	collectionCount.ZIndex = 207
	collectionCount.Parent = collection
	fishdexModernUI.collectionCount = collectionCount

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fishdexModernUI.updateFishdexResponsiveScale)
	end

	fishdexModernUI.setFishdexTabSelected("All")
end

local function renderFishdexTab()
	fishdexModernUI.buildModernFishdex()
	mainPanelUI.panel.Visible = false
	fishdexModernUI.root.Visible = not panelCollapsed
	fishdexModernUI.renderModernFishdexCards()
end

local renderAquariumVisitorsSection

local function renderAquariumTab()
	mainPanelUI.panel.Visible = false
	if AuthoredUi.aquariumController then
		-- StateUpdated re-renders the active tab frequently. Closing the Viewer
		-- leaves Aquarium as the active tab but collapses the panel, so calling
		-- Show here unconditionally caused it to pop open again on the next state
		-- packet. Keep its data fresh while hidden and reserve Show for an explicit
		-- open action.
		if panelCollapsed then
			AuthoredUi.aquariumController:Render(state)
			AuthoredUi.aquariumController:Hide()
		else
			AuthoredUi.aquariumController:Show(state)
		end
		return
	end

	local aquarium = state.Aquarium
	local capacity = aquarium.Capacity
	local usedCapacity = aquarium.UsedCapacity or GameConfig.getAquariumUsedSpace(aquarium.Fish)
	local aquariumView = state.AquariumView or {}
	local viewLoaded = aquariumView.IsLoaded == true
	local canEditAquarium = aquariumView.CanEdit == true
	local ownerName = aquariumView.OwnerName or "Player"
	local viewOnly = viewLoaded and not canEditAquarium

	local _, top = authoredLegacyCard("AquariumSummaryTemplate")
	local headingText = canEditAquarium and "My Aquarium" or (viewOnly and ("Viewing " .. ownerName .. "'s Aquarium") or "Aquarium Hub")
	local heading = requiredAuthoredNode(top, "Heading", "TextLabel")
	heading.Text = headingText

	local infoText = string.format("Level %d | Space %d/%d", aquarium.Level, usedCapacity, capacity)
	if viewOnly then
		infoText = "View-only. Select My Aquarium to edit."
	elseif not viewLoaded then
		infoText = "Use the hub controls to load an aquarium."
	end
	local info = requiredAuthoredNode(top, "Info", "TextLabel")
	info.Text = infoText

	local best = viewOnly and "Editing disabled for other players' aquariums." or (state.BestCatch and ("Best: " .. state.BestCatch.name .. " (" .. state.BestCatch.value .. " coins)") or "Best: None yet")
	local bestText = requiredAuthoredNode(top, "Best", "TextLabel")
	bestText.Text = best

	local nextCost = GameConfig.AquariumUpgradeCosts[aquarium.Level + 1]
	local upgrade = requiredAuthoredNode(top, "UpgradeButton", "TextButton")
	upgrade.Text = nextCost and ("Upgrade " .. nextCost) or "Max Level"
	upgrade.Visible = canEditAquarium

	if not canEditAquarium then
		renderAquariumVisitorsSection()
		return
	end

	upgrade.MouseButton1Click:Connect(function()
		Remote.AquariumAction:FireServer("Upgrade")
	end)

	for index, fish in ipairs(aquarium.Fish) do
		local _, card = authoredLegacyCard("AquariumFishTemplate")
		local color = GameConfig.RarityColors[fish.rarity] or Color3.new(1, 1, 1)
		local name = requiredAuthoredNode(card, "Name", "TextLabel")
		name.Text = index .. ". " .. fish.name .. " [" .. fish.rarity .. "]"
		name.TextColor3 = color

		local fishSpace = GameConfig.getAquariumFishSpace(fish)
		local valueText = requiredAuthoredNode(card, "Value", "TextLabel")
		valueText.Text = "Value: " .. fish.value .. " coins | Space: " .. fishSpace

		local remove = requiredAuthoredNode(card, "RemoveButton", "TextButton")
		remove.MouseButton1Click:Connect(function()
			Remote.AquariumAction:FireServer("RemoveFish", fish.serial, index)
		end)
	end

	renderAquariumVisitorsSection()
end

renderAquariumVisitorsSection = function()
	local visitors = state.AquariumVisitors or {}

	local _, top = authoredLegacyCard("AquariumHubHeaderTemplate")
	requiredAuthoredNode(top, "Heading", "TextLabel")
	requiredAuthoredNode(top, "Info", "TextLabel")

	local _, directory = authoredLegacyCard("AquariumDirectoryTemplate")
	requiredAuthoredNode(directory, "DirectoryTitle", "TextLabel")

	local function bindDirectoryButton(name, callback)
		local button = requiredAuthoredNode(directory, name, "TextButton")
		button.MouseButton1Click:Connect(callback)
		return button
	end

	local function visitSingleTank(userId)
		print("Loading aquarium:", tostring(userId))
		Remote.TeleportTo:FireServer({
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

	bindDirectoryButton("MyAquariumButton", function()
		print("Aquarium Viewer option clicked:", "My Aquarium")
		visitSingleTank(player.UserId)
	end)
	bindDirectoryButton("FriendsButton", function()
		print("Aquarium Viewer option clicked:", "Friends' Aquariums")
		showToast("Friends' aquariums are listed below.")
	end)
	bindDirectoryButton("FeaturedButton", function()
		print("Aquarium Viewer option clicked:", "Featured Aquariums")
		local visitor = getPublicVisitor(false)
		if visitor then
			print("Loading aquarium:", visitor.DisplayName or visitor.Name or "Featured")
			visitSingleTank(visitor.UserId)
		else
			showToast("No featured aquariums are ready yet.")
		end
	end)
	bindDirectoryButton("MostLikedButton", function()
		print("Aquarium Viewer option clicked:", "Most Liked Aquariums")
		local visitor = getPublicVisitor(false)
		if visitor then
			print("Loading aquarium:", visitor.DisplayName or visitor.Name or "Most Liked")
			visitSingleTank(visitor.UserId)
		else
			showToast("No liked aquariums are ready yet.")
		end
	end)
	bindDirectoryButton("RandomPublicButton", function()
		print("Aquarium Viewer option clicked:", "Random Public Aquarium")
		local visitor = getPublicVisitor(true)
		if visitor then
			print("Loading aquarium:", visitor.DisplayName or visitor.Name or "Random Public")
			visitSingleTank(visitor.UserId)
		else
			showToast("No public aquariums are ready yet.")
		end
	end)
	bindDirectoryButton("SearchPlayerButton", function()
		print("Aquarium Viewer option clicked:", "Search Player Aquarium")
		showToast("Search Player Aquarium is coming soon.")
	end)

	local returnButton = requiredAuthoredNode(directory, "ReturnButton", "TextButton")
	returnButton.MouseButton1Click:Connect(function()
		print("Aquarium Viewer option clicked:", "Return to Seaside Island")
		Remote.TeleportTo:FireServer("Lobby")
	end)

	if #visitors == 0 then
		local _, empty = authoredLegacyCard("AquariumEmptyTemplate")
		requiredAuthoredNode(empty, "Message", "TextLabel")
		return
	end

	for _, visitor in ipairs(visitors) do
		local _, card = authoredLegacyCard("AquariumVisitorTemplate")
		local nameText = visitor.DisplayName or visitor.Name or "Player"
		if visitor.IsSelf then
			nameText = nameText .. " (You)"
		end

		local name = requiredAuthoredNode(card, "Name", "TextLabel")
		name.Text = nameText

		local used = visitor.UsedCapacity or 0
		local capacity = visitor.Capacity or 0
		local detail = requiredAuthoredNode(card, "Detail", "TextLabel")
		detail.Text = string.format("Online | Level %d | Fish %d | Space %d/%d", visitor.AquariumLevel or 1, visitor.FishCount or 0, used, capacity)

		local bestText = "Best: None yet"
		if visitor.BestCatch then
			bestText = string.format("Best: %s (%d coins)", visitor.BestCatch.name or "Fish", visitor.BestCatch.value or 0)
		end
		local best = requiredAuthoredNode(card, "Best", "TextLabel")
		best.Text = bestText

		local visit = requiredAuthoredNode(card, "VisitButton", "TextButton")
		visit.Text = visitor.IsSelf and "My Tank" or "Visit"
		visit.MouseButton1Click:Connect(function()
			Remote.TeleportTo:FireServer({
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
		local unlocked = not biome or islandState.getUnlockedIslands()[target.id]
		local current = currentLocation == target.id
		local card = makeCard(mainPanelUI.content, biome and 96 or 72)
		local nameColor = biome and biome.color or Color3.fromRGB(255, 255, 255)
		if not unlocked then
			nameColor = Color3.fromRGB(130, 140, 155)
		end

		local name = guiPrimitives.makeText(card, target.name, 16, nameColor, true)
		name.Position = UDim2.new(0, 12, 0, 8)
		name.Size = UDim2.new(1, -132, 0, 22)

		local detailY = 34
		if target.requirement then
			local requirement = guiPrimitives.makeText(card, "Requirement: " .. target.requirement, 13, Color3.fromRGB(190, 204, 220), false)
			requirement.Position = UDim2.new(0, 12, 0, detailY)
			requirement.Size = UDim2.new(1, -132, 0, 20)
			detailY = 58
		end

		if biome then
			local detail = guiPrimitives.makeText(card, "Species: " .. #biome.fish, 12, Color3.fromRGB(143, 160, 180), false)
			detail.Position = UDim2.new(0, 12, 0, detailY)
			detail.Size = UDim2.new(1, -132, 0, 18)
		end

		local label = current and "Selected" or (unlocked and "Go" or "Unlock")
		local color = unlocked and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(28, 160, 92)
		if current then
			color = Color3.fromRGB(91, 104, 124)
		end

		local button = guiPrimitives.makeButton(card, label, color)
		button.Position = UDim2.new(1, -110, 0, biome and 30 or 19)
		button.Size = UDim2.new(0, 94, 0, 36)
		button.MouseButton1Click:Connect(function()
			if unlocked then
				Remote.TeleportTo:FireServer(target.id)
			elseif biome then
				Remote.UnlockBiome:FireServer(target.id)
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
		local button = guiPrimitives.makeButton(selector, periodName, activeQuestPeriod == periodName and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(38, 45, 57))
		button.Size = UDim2.new(0.333, -5, 1, 0)
		button.MouseButton1Click:Connect(function()
			activeQuestPeriod = periodName
			renderContent()
		end)
	end
end

local function renderQuestsTab()
	renderQuestPeriodTabs()

	local period = questHelpers.getQuestPeriod(activeQuestPeriod)
	if not period then
		local loading = makeCard(mainPanelUI.content, 64)
		local loadingText = guiPrimitives.makeText(loading, "Loading quests...", 15, Color3.fromRGB(190, 204, 220), true)
		loadingText.Position = UDim2.new(0, 12, 0, 16)
		loadingText.Size = UDim2.new(1, -24, 0, 24)
		return
	end

	local summary = makeCard(mainPanelUI.content, 72)
	local heading = guiPrimitives.makeText(summary, activeQuestPeriod .. " Quests", 17, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 12, 0, 8)
	heading.Size = UDim2.new(1, -24, 0, 24)

	local completedCount = 0
	for _, quest in ipairs(period.quests or {}) do
		if quest.completed then
			completedCount += 1
		end
	end

	local detail = guiPrimitives.makeText(summary, string.format("%d/%d complete | Resets automatically", completedCount, #(period.quests or {})), 13, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 12, 0, 38)
	detail.Size = UDim2.new(1, -24, 0, 20)

	for _, quest in ipairs(period.quests or {}) do
		local card = makeCard(mainPanelUI.content, 124)
		local complete = quest.completed == true
		local claimed = quest.claimed == true
		guiPrimitives.addStroke(card, claimed and Color3.fromRGB(112, 255, 156) or (complete and Color3.fromRGB(255, 219, 92) or Color3.fromRGB(60, 72, 90)), 1).Transparency = complete and 0.16 or 0.45

		local title = guiPrimitives.makeText(card, quest.title or "Quest", 15, complete and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(235, 242, 255), true)
		title.Position = UDim2.new(0, 12, 0, 7)
		title.Size = UDim2.new(1, -126, 0, 22)

		local description = guiPrimitives.makeText(card, quest.description or "", 12, Color3.fromRGB(190, 204, 220), false)
		description.Position = UDim2.new(0, 12, 0, 31)
		description.Size = UDim2.new(1, -126, 0, 32)
		description.TextWrapped = true

		local progressText = string.format("Progress: %d/%d", tonumber(quest.progress) or 0, tonumber(quest.target) or 1)
		local progress = guiPrimitives.makeText(card, progressText, 12, complete and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(143, 160, 180), true)
		progress.Position = UDim2.new(0, 12, 0, 66)
		progress.Size = UDim2.new(1, -126, 0, 18)

		local reward = guiPrimitives.makeText(card, "Reward: " .. formatQuestReward(quest.reward), 12, Color3.fromRGB(214, 226, 244), false)
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
			guiPrimitives.addCorner(checkShort, 4)

			local checkLong = Instance.new("Frame")
			checkLong.AnchorPoint = Vector2.new(0.5, 0.5)
			checkLong.Position = UDim2.new(0, 30, 0, 18)
			checkLong.Size = UDim2.new(0, 8, 0, 34)
			checkLong.Rotation = 42
			checkLong.BackgroundColor3 = Color3.fromRGB(112, 255, 156)
			checkLong.BorderSizePixel = 0
			checkLong.Parent = checkHolder
			guiPrimitives.addCorner(checkLong, 4)

			local claimedText = guiPrimitives.makeText(card, "Claimed", 12, Color3.fromRGB(112, 255, 156), true)
			claimedText.Position = UDim2.new(1, -104, 0, 58)
			claimedText.Size = UDim2.new(0, 90, 0, 20)
			claimedText.TextXAlignment = Enum.TextXAlignment.Center
		elseif complete then
			local claim = guiPrimitives.makeButton(card, "Claim", Color3.fromRGB(28, 160, 92))
			claim.Position = UDim2.new(1, -104, 0, 42)
			claim.Size = UDim2.new(0, 88, 0, 36)
			claim.MouseButton1Click:Connect(function()
				remoteActions.fireQuestAction("Claim", activeQuestPeriod, quest.id)
			end)
		else
			local status = guiPrimitives.makeText(card, "In Progress", 12, Color3.fromRGB(143, 160, 180), true)
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
	guiPrimitives.addCorner(icon, 8)
	guiPrimitives.addStroke(icon, Color3.fromRGB(255, 255, 255), 1).Transparency = 0.75

	local label = guiPrimitives.makeText(icon, text, 14, Color3.fromRGB(255, 255, 255), true)
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
		local button = guiPrimitives.makeButton(selector, tabName, activeShopTab == tabName and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(38, 45, 57))
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

	local name = guiPrimitives.makeText(card, item.name, 15, Color3.fromRGB(255, 255, 255), true)
	name.Position = UDim2.new(0, 76, 0, 8)
	name.Size = UDim2.new(1, -194, 0, 22)

	local description = guiPrimitives.makeText(card, item.description, 12, Color3.fromRGB(190, 204, 220), false)
	description.Position = UDim2.new(0, 76, 0, 32)
	description.Size = UDim2.new(1, -194, 0, 36)
	description.TextWrapped = true

	local price = guiPrimitives.makeText(card, tostring(item.priceRobux or "?") .. " Robux", 12, Color3.fromRGB(255, 219, 92), true)
	price.Position = UDim2.new(0, 76, 0, 74)
	price.Size = UDim2.new(1, -194, 0, 18)

	if owned then
		local ownedText = guiPrimitives.makeText(card, "Owned", 13, Color3.fromRGB(112, 255, 156), true)
		ownedText.Position = UDim2.new(1, -108, 0, 35)
		ownedText.Size = UDim2.new(0, 92, 0, 34)
		ownedText.TextXAlignment = Enum.TextXAlignment.Center
	else
		local purchase = guiPrimitives.makeButton(card, "Buy", Color3.fromRGB(28, 160, 92))
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
	local title = guiPrimitives.makeText(reward, "VIP Daily Reward", 16, Color3.fromRGB(255, 255, 255), true)
	title.Position = UDim2.new(0, 76, 0, 10)
	title.Size = UDim2.new(1, -194, 0, 22)
	local detail = guiPrimitives.makeText(reward, "5 Fresh Bait + 2 Lucky Bait once per day.", 12, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 76, 0, 36)
	detail.Size = UDim2.new(1, -194, 0, 20)
	local rewardButton = guiPrimitives.makeButton(reward, monetization.VipRewardAvailable and "Claim" or "VIP", monetization.VipRewardAvailable and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(86, 98, 115))
	rewardButton.Position = UDim2.new(1, -104, 0, 29)
	rewardButton.Size = UDim2.new(0, 88, 0, 34)
	rewardButton.AutoButtonColor = monetization.VipRewardAvailable == true
	rewardButton.MouseButton1Click:Connect(function()
		remoteActions.fireShopAction("ClaimVipReward", "GamePass", "VipAngler")
	end)

	for _, passKey in ipairs({ "VipAngler", "AquariumDesigner" }) do
		local pass = MonetizationConfig.GamePasses[passKey]
		fishyFishRenderRobuxItem(passKey, pass, function(key)
			remoteActions.fireShopAction("PromptGamePass", "GamePass", key)
		end, fishyFishOwnsGamePass(passKey), passKey == "VipAngler" and "VIP" or "AQUA", passKey == "VipAngler" and Color3.fromRGB(255, 181, 36) or Color3.fromRGB(58, 174, 205))
	end
end

function fishyFishRenderShopBait()
	for _, productKey in ipairs(MonetizationConfig.DeveloperProductOrder) do
		local product = MonetizationConfig.DeveloperProducts[productKey]
		fishyFishRenderRobuxItem(productKey, product, function(key)
			remoteActions.fireShopAction("PromptProduct", "Product", key)
		end, false, "BAIT", Color3.fromRGB(116, 94, 255))
	end
end

function fishyFishRenderShopCoins()
	for _, productKey in ipairs(MonetizationConfig.CoinProductOrder or {}) do
		local product = MonetizationConfig.DeveloperProducts[productKey]
		if product then
			fishyFishRenderRobuxItem(productKey, product, function(key)
				remoteActions.fireShopAction("PromptProduct", "Product", key)
			end, false, "COIN", Color3.fromRGB(255, 181, 36))
		end
	end
end

function fishyFishRenderShopStorage()
	local summary = makeCard(mainPanelUI.content, 74)
	local heading = guiPrimitives.makeText(summary, "Fish Bag Storage", 16, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 12, 0, 10)
	heading.Size = UDim2.new(1, -24, 0, 22)
	local detail = guiPrimitives.makeText(summary, string.format("Current capacity: %d fish", state.BackpackSize or 0), 13, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 12, 0, 38)
	detail.Size = UDim2.new(1, -24, 0, 20)

	for _, passKey in ipairs({ "SmallBag", "MediumBag", "LargeBag" }) do
		local pass = MonetizationConfig.GamePasses[passKey]
		fishyFishRenderRobuxItem(passKey, pass, function(key)
			remoteActions.fireShopAction("PromptGamePass", "GamePass", key)
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
	local heading = guiPrimitives.makeText(summary, "Aquarium Designer", 16, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 76, 0, 8)
	heading.Size = UDim2.new(1, -194, 0, 22)
	local status = "Select My Aquarium in the Hub to edit."
	if canEditAquarium then
		status = ownsDesigner and "Owned | Preview, apply, and save premium designs." or "Preview is free. Apply premium designs after buying the pass."
	end
	local detail = guiPrimitives.makeText(summary, status, 12, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 76, 0, 34)
	detail.Size = UDim2.new(1, -194, 0, 34)
	detail.TextWrapped = true
	local cancel = guiPrimitives.makeButton(summary, monetization.AquariumPreviewActive and "Cancel" or "Preview", canEditAquarium and (monetization.AquariumPreviewActive and Color3.fromRGB(230, 126, 48) or Color3.fromRGB(86, 98, 115)) or Color3.fromRGB(86, 98, 115))
	cancel.Position = UDim2.new(1, -104, 0, 31)
	cancel.Size = UDim2.new(0, 88, 0, 34)
	cancel.AutoButtonColor = canEditAquarium
	cancel.MouseButton1Click:Connect(function()
		if canEditAquarium then
			remoteActions.fireShopAction("CancelAquariumPreview", "Aquarium")
		end
	end)

	local function renderDesignOption(kind, id, item, labelPrefix)
		local premium = item.premium == true
		local card = makeCard(mainPanelUI.content, 124)
		fishyFishMakeShopIcon(card, premium and "LOCK" or "FREE", premium and Color3.fromRGB(255, 181, 36) or Color3.fromRGB(58, 174, 205))
		local name = guiPrimitives.makeText(card, (labelPrefix or "") .. item.name, 15, Color3.fromRGB(255, 255, 255), true)
		name.Position = UDim2.new(0, 76, 0, 8)
		name.Size = UDim2.new(1, -96, 0, 22)
		local desc = guiPrimitives.makeText(card, premium and "Premium aquarium option" or "Standard aquarium option", 12, Color3.fromRGB(190, 204, 220), false)
		desc.Position = UDim2.new(0, 76, 0, 34)
		desc.Size = UDim2.new(1, -96, 0, 18)
		local selected = currentDesign[kind] == id
		local statusText = guiPrimitives.makeText(card, selected and "Selected" or (premium and "Requires Designer Pass" or "Available"), 12, selected and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(143, 160, 180), false)
		statusText.Position = UDim2.new(0, 76, 0, 58)
		statusText.Size = UDim2.new(1, -96, 0, 18)

		local preview = guiPrimitives.makeButton(card, canEditAquarium and "Preview" or "View Only", canEditAquarium and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(86, 98, 115))
		preview.Position = UDim2.new(1, -196, 0, 82)
		preview.Size = UDim2.new(0, 84, 0, 32)
		preview.TextSize = 12
		preview.AutoButtonColor = canEditAquarium
		preview.MouseButton1Click:Connect(function()
			if canEditAquarium then
				remoteActions.fireShopAction("PreviewAquariumDesign", "Aquarium", kind, fishyFishCopyAquariumDesignWith({ [kind] = id }))
			end
		end)

		local apply = guiPrimitives.makeButton(card, "Apply", canEditAquarium and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(86, 98, 115))
		apply.Position = UDim2.new(1, -104, 0, 82)
		apply.Size = UDim2.new(0, 88, 0, 32)
		apply.TextSize = 12
		apply.AutoButtonColor = canEditAquarium
		apply.MouseButton1Click:Connect(function()
			if canEditAquarium then
				remoteActions.fireShopAction("ApplyAquariumDesign", "Aquarium", kind, fishyFishCopyAquariumDesignWith({ [kind] = id }))
			end
		end)
	end

	local themeHeader = guiPrimitives.makeText(mainPanelUI.content, "Themes", 16, Color3.fromRGB(255, 255, 255), true)
	themeHeader.Size = UDim2.new(1, -8, 0, 28)
	for _, themeId in ipairs(MonetizationConfig.AquariumDesigner.themeOrder) do
		renderDesignOption("theme", themeId, MonetizationConfig.AquariumDesigner.themes[themeId])
	end

	local signCard = makeCard(mainPanelUI.content, 104)
	fishyFishMakeShopIcon(signCard, "TEXT", Color3.fromRGB(255, 181, 36))
	local signTitle = guiPrimitives.makeText(signCard, "Display Sign Text", 15, Color3.fromRGB(255, 255, 255), true)
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
	guiPrimitives.addCorner(signBox, 6)
	guiPrimitives.addStroke(signBox, Color3.fromRGB(60, 72, 90), 1)
	local applySign = guiPrimitives.makeButton(signCard, "Apply", canEditAquarium and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(86, 98, 115))
	applySign.Position = UDim2.new(1, -104, 0, 72)
	applySign.Size = UDim2.new(0, 88, 0, 26)
	applySign.TextSize = 12
	applySign.AutoButtonColor = canEditAquarium
	applySign.MouseButton1Click:Connect(function()
		if canEditAquarium then
			remoteActions.fireShopAction("ApplyAquariumDesign", "Aquarium", "signText", fishyFishCopyAquariumDesignWith({ signText = signBox.Text }))
		end
	end)
end

do
	local moduleScript = script:FindFirstChild("ShopModernUI")
	if moduleScript then
		local ok, module = pcall(require, moduleScript)
		if ok and type(module) == "table" and type(module.render) == "function" then
			shopModernUI = module
		else
			warn("ShopModernUI could not be loaded; using the legacy shop renderer.", module)
		end
	end
end

local function renderShopTab()
	if shopModernUI then
		if not shopModernContext then
			shopModernContext = {
				parent = mainPanelUI.content,
				panel = mainPanelUI.panel,
				panelTitle = mainPanelUI.panelTitle,
				panelClose = mainPanelUI.panelClose,
				MonetizationConfig = MonetizationConfig,
				fireShopAction = remoteActions.fireShopAction,
				makeText = guiPrimitives.makeText,
				addCorner = guiPrimitives.addCorner,
				addStroke = guiPrimitives.addStroke,
				onSelectedTabChanged = function(tabName)
					if VALID_SHOP_TABS[tabName] then
						activeShopTab = tabName
					end
				end,
				close = function()
					panelCollapsed = true
					updatePanelCollapsed()
				end,
			}
		end

		shopModernContext.state = state
		if type(shopModernUI.setSelectedTab) == "function" then
			shopModernUI.setSelectedTab(activeShopTab)
		end
		shopModernUI.render(shopModernContext)
		return
	end

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
		guiPrimitives.addCorner(card, 8)
		local stroke = guiPrimitives.addStroke(card, strokeColor or Color3.fromRGB(60, 72, 90), strokeThickness or 1)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		if strokeTransparency ~= nil then
			stroke.Transparency = strokeTransparency
		end
		return card, stroke
	end

	local onlinePlayers = Services.Players:GetPlayers()
	table.sort(onlinePlayers, function(left, right)
		local leftCaught = tonumber(Modules.LeaderboardHelpers.getPlayerLeaderstat(left, "Fish Caught")) or 0
		local rightCaught = tonumber(Modules.LeaderboardHelpers.getPlayerLeaderstat(right, "Fish Caught")) or 0
		if leftCaught ~= rightCaught then
			return leftCaught > rightCaught
		end

		return string.lower(left.DisplayName or left.Name) < string.lower(right.DisplayName or right.Name)
	end)

	local summary = makeLeaderboardCard(80)
	local heading = guiPrimitives.makeText(summary, "Leaderboard", 17, Color3.fromRGB(255, 255, 255), true)
	heading.Position = UDim2.new(0, 18, 0, 8)
	heading.Size = UDim2.new(1, -30, 0, 24)

	local detail = guiPrimitives.makeText(summary, string.format("Sorted by fish-caught leaderboard | %d player%s online", #onlinePlayers, #onlinePlayers == 1 and "" or "s"), 13, Color3.fromRGB(190, 204, 220), false)
	detail.Position = UDim2.new(0, 18, 0, 38)
	detail.Size = UDim2.new(1, -36, 0, 20)

	local header = makeLeaderboardCard(38)
	local rankHeader = guiPrimitives.makeText(header, "#", 12, Color3.fromRGB(143, 160, 180), true)
	rankHeader.Position = UDim2.new(0, 16, 0, 8)
	rankHeader.Size = UDim2.new(0, 28, 0, 20)
	rankHeader.TextXAlignment = Enum.TextXAlignment.Center
	local nameHeader = guiPrimitives.makeText(header, "Player", 12, Color3.fromRGB(143, 160, 180), true)
	nameHeader.Position = UDim2.new(0, 52, 0, 8)
	nameHeader.Size = UDim2.new(0.48, -52, 0, 20)
	local coinsHeader = guiPrimitives.makeText(header, "Coins", 12, Color3.fromRGB(143, 160, 180), true)
	coinsHeader.Position = UDim2.new(0.52, 0, 0, 8)
	coinsHeader.Size = UDim2.new(0.17, 0, 0, 20)
	coinsHeader.TextXAlignment = Enum.TextXAlignment.Center
	local levelHeader = guiPrimitives.makeText(header, "Level", 12, Color3.fromRGB(143, 160, 180), true)
	levelHeader.Position = UDim2.new(0.69, 0, 0, 8)
	levelHeader.Size = UDim2.new(0.14, 0, 0, 20)
	levelHeader.TextXAlignment = Enum.TextXAlignment.Center
	local caughtHeader = guiPrimitives.makeText(header, "Fish", 12, Color3.fromRGB(143, 160, 180), true)
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

		local rankLabel = guiPrimitives.makeText(card, tostring(rank), 13, Color3.fromRGB(143, 160, 180), true)
		rankLabel.Position = UDim2.new(0, 16, 0, 20)
		rankLabel.Size = UDim2.new(0, 28, 0, 20)
		rankLabel.TextXAlignment = Enum.TextXAlignment.Center

		local name = guiPrimitives.makeText(card, displayName, 13, isSelf and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(255, 255, 255), true)
		name.Position = UDim2.new(0, 52, 0, 8)
		name.Size = UDim2.new(0.48, -52, 0, 22)
		name.TextTruncate = Enum.TextTruncate.None

		local username = guiPrimitives.makeText(card, "@" .. listedPlayer.Name, 11, Color3.fromRGB(143, 160, 180), false)
		username.Position = UDim2.new(0, 52, 0, 32)
		username.Size = UDim2.new(0.48, -52, 0, 16)
		username.TextTruncate = Enum.TextTruncate.None

		local coins = guiPrimitives.makeText(card, Modules.LeaderboardHelpers.formatCompactNumber(Modules.LeaderboardHelpers.getPlayerLeaderstat(listedPlayer, "Coins")), 13, Color3.fromRGB(235, 242, 255), true)
		coins.Position = UDim2.new(0.52, 0, 0, 20)
		coins.Size = UDim2.new(0.17, 0, 0, 20)
		coins.TextXAlignment = Enum.TextXAlignment.Center

		local level = guiPrimitives.makeText(card, tostring(Modules.LeaderboardHelpers.getPlayerLeaderstat(listedPlayer, "Level")), 13, Color3.fromRGB(235, 242, 255), true)
		level.Position = UDim2.new(0.69, 0, 0, 20)
		level.Size = UDim2.new(0.14, 0, 0, 20)
		level.TextXAlignment = Enum.TextXAlignment.Center

		local caught = guiPrimitives.makeText(card, Modules.LeaderboardHelpers.formatCompactNumber(Modules.LeaderboardHelpers.getPlayerLeaderstat(listedPlayer, "Fish Caught")), 13, Color3.fromRGB(235, 242, 255), true)
		caught.Position = UDim2.new(0.83, 0, 0, 20)
		caught.Size = UDim2.new(0.17, -18, 0, 20)
		caught.TextXAlignment = Enum.TextXAlignment.Center
	end
end

renderContent = function()
	if activeTab ~= "Bag" or panelCollapsed then
		local bagModuleScript = script:FindFirstChild("BagModernUI")
		if bagModuleScript then
			local ok, bagModule = pcall(require, bagModuleScript)
			if ok and bagModule and bagModule.hide then
				bagModule.hide()
			end
		end
	end

	if activeTab == "Rods" then
		activeTab = "Bag"
	elseif activeTab == "Fish" then
		activeTab = "Fishdex"
	elseif activeTab == "Aquariums" then
		activeTab = "Aquarium"
	elseif activeTab == "Biomes" then
		activeTab = "Teleport"
	end

	if activeTab ~= "Shop" and shopModernUI and shopModernUI.hide then
		shopModernUI.hide()
	end

	if fishdexModernUI.root and activeTab ~= "Fishdex" then
		fishdexModernUI.root.Visible = false
	end
	if activeTab ~= "Fishdex" and activeTab ~= "Bag" and activeTab ~= "Quests" then
		mainPanelUI.panel.Visible = not panelCollapsed
	else
		mainPanelUI.panel.Visible = false
	end

	refreshHud()
	refreshCenterControls()
	refreshTabs()
	mainPanelUI.panelTitle.Text = activeTab

	if activeTab == "Shop" and shopModernUI and state then
		renderShopTab()
		return
	end

	guiPrimitives.clearChildren(mainPanelUI.content)

	if not state then
		cloneLegacyMainPanelTemplate("LoadingLabelTemplate", mainPanelUI.content)
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

-- Hard guard for duplicate/older Bag and Fishdex panels.
-- This runs inside the real FishingClient, so it knows exactly when Bag or
-- Fishdex is the active tab and does not rely on guessing from UI names alone.
local legacyBagFishdexGuardElapsed = 0

suppressLegacyBagFishdexPanels = function()
	-- AuthoredUiV2 has one declared owner for every surface. The old global
	-- descendant scan can mistake those authored hosts for duplicates and must
	-- never mutate that tree.
	if AuthoredUi.enabled then
		return
	end

	if panelCollapsed
		or (activeTab ~= "Bag" and activeTab ~= "Fishdex")
	then
		return
	end

	-- The integrated old Bag/Fishdex panel must always stay hidden.
	mainPanelUI.panel.Visible = false

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if not descendant:IsA("GuiObject") then
			continue
		end

		local lowerName = string.lower(descendant.Name or "")
		local legacyCandidate = descendant.Name == "MainPanel"
			or lowerName == "bagpanel"
			or lowerName == "fishdexpanel"
			or lowerName == "legacybag"
			or lowerName == "legacyfishdex"
			or lowerName == "oldbag"
			or lowerName == "oldfishdex"

		if not legacyCandidate then
			continue
		end

		-- Never touch the modern roots.
		if descendant.Name == "ModernBagRoot"
			or descendant.Name == "ModernBag"
			or descendant.Name == "ModernFishdex"
		then
			continue
		end

		-- Empty marker panels under FishingGui/Panels do not render anything,
		-- but hiding them is harmless.
		descendant.Visible = false
	end
end

Services.RunService.RenderStepped:Connect(function(deltaTime)
	legacyBagFishdexGuardElapsed += deltaTime
	if legacyBagFishdexGuardElapsed < 0.05 then
		return
	end
	legacyBagFishdexGuardElapsed = 0

	suppressLegacyBagFishdexPanels()

	if activeTab == "Fishdex"
		and not panelCollapsed
		and fishdexModernUI.root
	then
		fishdexModernUI.root.Visible = true
	end

	if activeTab == "Bag" and not panelCollapsed then
		local modernBag = screenGui:FindFirstChild("ModernBagRoot")
			or screenGui:FindFirstChild("ModernBag")
		if modernBag and modernBag:IsA("GuiObject") then
			modernBag.Visible = true
		end
	end
end)

function minigameUI.legacyRunMinigame(prompt)
	if minigameRunning then
		return
	end

	local isAutoFish = prompt.autoFish == true
	local clientSessionStartedAt = os.clock()
	local fish = prompt.fish or {}
	local promptBait = prompt.bait or {}
	local promptBaitId = promptBait.id or (state and state.EquippedBait) or GameConfig.BasicBaitId
	local promptBaitData = baitHelpers.getBaitData(promptBaitId)
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
	guiPrimitives.forcePureWhiteText(minigameUI.minigameText)

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
	guiPrimitives.forcePureWhiteText(minigameUI.minigameText)

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
			Remote.FinishMinigame:FireServer({
				action = "Complete",
				success = success == true,
				sessionId = prompt.sessionId,
				elapsed = math.max(0, os.clock() - clientSessionStartedAt),
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
		inputBeganConnection = Services.UserInputService.InputBegan:Connect(function(input)
			if isCatchInput(input) then
				holding = true
			end
		end)

		inputEndedConnection = Services.UserInputService.InputEnded:Connect(function(input)
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

	renderConnection = Services.RunService.RenderStepped:Connect(function(deltaTime)
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
		end
	end)
end

local function runMinigame(prompt)
	if minigameRunning then
		return
	end

	AuthoredUi.closeQuest()
	panelCollapsed = true
	updatePanelCollapsed()

	minigameRunning = true
	CastPower.running = false
	CastPower.activeConfig = nil
	minigameUI.setFishingVisible(true)
	CastPower.content.Visible = false

	local lifecycleFinished = false
	local clientSessionStartedAt = os.clock()
	local function complete(success, isAutoFish, elapsed)
		if lifecycleFinished then
			return
		end

		lifecycleFinished = true
		activeMinigameCleanup = nil
		minigameUI.setFishingVisible(false)
		minigameRunning = false
		fishingBusy = false
		toolSwitchLock.set(false)

		if not isAutoFish then
			Remote.FinishMinigame:FireServer({
				action = "Complete",
				success = success == true,
				sessionId = prompt.sessionId,
				elapsed = tonumber(elapsed) or (os.clock() - clientSessionStartedAt),
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
			modernUi = minigameUI.modern,
			RunService = Services.RunService,
			UserInputService = Services.UserInputService,
			tapButton = centerCastButton,
			getBaitData = baitHelpers.getBaitData,
			getBaitCountText = baitHelpers.getBaitCountText,
			setFishIcon = setMinigameFishIcon,
			forcePureWhiteText = guiPrimitives.forcePureWhiteText,
			showToast = showToast,
			onInputEvent = function(evidence)
				if type(evidence) ~= "table" or prompt.autoFish == true then
					return
				end

				Remote.FinishMinigame:FireServer({
					action = "Input",
					sessionId = prompt.sessionId,
					sequence = evidence.sequence,
					kind = evidence.kind,
					holding = evidence.holding,
					elapsed = evidence.elapsed,
				})
			end,
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

local function syncEquippedRodAttributes()
	if not state or not state.EquippedRod then
		return
	end

	local rodId = state.EquippedRod
	local rod = GameConfig.Rods and GameConfig.Rods[rodId]

	local rodName = rod and rod.displayName or tostring(rodId)
	local rodIcon = ""

	if GameConfig.getRodImage then
		rodIcon = GameConfig.getRodImage(rodId) or ""
	end

	if rodIcon ~= "" and not string.find(tostring(rodIcon), "rbxassetid://") and tonumber(rodIcon) then
		rodIcon = "rbxassetid://" .. tostring(rodIcon)
	end

	player:SetAttribute("EquippedRodId", rodId)
	player:SetAttribute("EquippedRodName", rodName)
	player:SetAttribute("EquippedRodIcon", rodIcon)

	print("[FishingClient] Equipped rod synced:", rodId, rodName, rodIcon)
end

Remote.StateUpdated.OnClientEvent:Connect(function(newState)
	state = newState
	if AuthoredUi.questController then
		AuthoredUi.questController:SetState(newState)
	end
	syncEquippedRodAttributes()

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

Remote.FishingPrompt.OnClientEvent:Connect(function(prompt)
	if prompt.autoFish then
		showToast("AutoFish is catching...", 2)
	elseif prompt.cast and prompt.cast.sparkle then
		CastPower.showSparkle()
	end

	-- Manual fishing keeps the persistent "Waiting for a bite..." banner.
	-- RarityCatchController replaces it exactly when the reel phase begins.
	if not prompt.autoFish then
		local presentationTimeLeft = castPresentationUntil - os.clock()
		if presentationTimeLeft > 0 then
			task.wait(presentationTimeLeft)
		end
	end
	runMinigame(prompt)
end)

Remote.Notice.OnClientEvent:Connect(function(message)
	if activeMinigameCleanup then
		activeMinigameCleanup()
		activeMinigameCleanup = nil
	end

	showToast(message)
	toolSwitchLock.set(false)
	fishingBusy = false
	minigameRunning = false
	CastPower.running = false
	CastPower.activeConfig = nil
	castPresentationUntil = 0
	CastPower.content.Visible = false
	setMinigameVisible(false)
	renderContent()
end)

Services.UserInputService.InputBegan:Connect(function(input, processed)
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
		return Remote.GetState:InvokeServer()
	end)

	if success and result then
		state = result
		if AuthoredUi.questController then
			AuthoredUi.questController:SetState(result)
		end
		syncEquippedRodAttributes()
	end

	refreshHud()
	renderContent()
	updateAquariumViewerFallbackButton()
end)

player.CharacterAdded:Connect(function()
	toolSwitchLock.set(false)
end)

local locationCheckElapsed = 0
Services.RunService.RenderStepped:Connect(function(deltaTime)
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
