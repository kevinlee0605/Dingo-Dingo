-- QuestModernClient_SAFE
-- Runs independently from FishingClient so a Quest UI error cannot stop
-- Bag, Fishdex, Shop, HUD, fishing controls, or the minigame from loading.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local fishingGui = script.Parent

local fishingClient = fishingGui:WaitForChild("FishingClient", 20)
if not fishingClient then
	warn("[QuestModernClient] FishingClient was not found.")
	return
end

local root = fishingGui:WaitForChild("Root", 20)
if not root then
	warn("[QuestModernClient] FishingGui.Root was not created.")
	return
end

local questModule = fishingClient:FindFirstChild("QuestModernUI")
if not questModule or not questModule:IsA("ModuleScript") then
	warn("[QuestModernClient] QuestModernUI ModuleScript was not found under FishingClient.")
	return
end

local requireSucceeded, QuestModernUI = pcall(require, questModule)
if not requireSucceeded then
	warn("[QuestModernClient] QuestModernUI require failed:", QuestModernUI)
	return
end

if type(QuestModernUI) ~= "table" or type(QuestModernUI.create) ~= "function" then
	warn("[QuestModernClient] QuestModernUI must return a table containing create().")
	return
end

local controller
local mainPanel
local panelTitle

local function refreshLegacyRefs()
	mainPanel = root:FindFirstChild("MainPanel", true)
	panelTitle = mainPanel and mainPanel:FindFirstChild("PanelTitle", true)
end

local function hideLegacyQuestPanel()
	refreshLegacyRefs()
	if mainPanel then
		mainPanel.Visible = false
	end
end

local function hideModernQuest()
	if controller then
		controller:SetVisible(false)
	end
end

local createSucceeded, createdController = pcall(function()
	return QuestModernUI.create({
		parent = fishingGui,
		authoredUi = true,
		remotes = ReplicatedStorage:WaitForChild("FishingRemotes"),

		onClose = function()
			hideModernQuest()
			hideLegacyQuestPanel()
		end,
	})
end)

if not createSucceeded then
	warn("[QuestModernClient] QuestModernUI.create failed:", createdController)
	return
end

controller = createdController
controller:SetVisible(false)

local function showModernQuest()
	-- FishingClient's own Quest callback runs on the same click and first creates
	-- the old panel. Deferring this makes the modern UI win after that callback.
	task.defer(function()
		hideLegacyQuestPanel()
		controller:SetVisible(true)
	end)
end

local connectedButtons = setmetatable({}, { __mode = "k" })
local connectedFishdexRoots = setmetatable({}, { __mode = "k" })
local connectedPanelTitles = setmetatable({}, { __mode = "k" })
local connectedOpenEvents = setmetatable({}, { __mode = "k" })

local function connectButton(instance)
	if not instance:IsA("GuiButton") or connectedButtons[instance] then
		return
	end

	if instance.Name == "QuestsButton" then
		connectedButtons[instance] = true
		instance.Activated:Connect(showModernQuest)
	elseif instance.Name == "SettingsButton" or instance.Name == "ShopButton" then
		connectedButtons[instance] = true
		instance.Activated:Connect(hideModernQuest)
	end
end

local function connectFishdexRoot(instance)
	if not instance:IsA("GuiObject")
		or instance.Name ~= "ModernFishdex"
		or connectedFishdexRoots[instance] then
		return
	end

	connectedFishdexRoots[instance] = true
	instance:GetPropertyChangedSignal("Visible"):Connect(function()
		if instance.Visible then
			hideModernQuest()
		end
	end)
end

local function connectPanelTitle(instance)
	if not instance:IsA("TextLabel")
		or instance.Name ~= "PanelTitle"
		or connectedPanelTitles[instance] then
		return
	end

	connectedPanelTitles[instance] = true
	instance:GetPropertyChangedSignal("Text"):Connect(function()
		if instance.Text ~= "Quests" then
			hideModernQuest()
		end
	end)
end

local function connectOpenPanelEvent(instance)
	if not instance:IsA("BindableEvent")
		or instance.Name ~= "OpenFishingPanel"
		or connectedOpenEvents[instance] then
		return
	end

	connectedOpenEvents[instance] = true
	instance.Event:Connect(function()
		hideModernQuest()
	end)
end

local function scan(instance)
	connectButton(instance)
	connectFishdexRoot(instance)
	connectPanelTitle(instance)
	connectOpenPanelEvent(instance)
end

for _, descendant in ipairs(fishingGui:GetDescendants()) do
	scan(descendant)
end

fishingGui.DescendantAdded:Connect(function(descendant)
	task.defer(scan, descendant)
end)

print("[QuestModernClient] Safe standalone Quest UI loaded.")
