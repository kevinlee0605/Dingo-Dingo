local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local fishingGui = playerGui:WaitForChild("FishingGui")
local topHudGui = playerGui:WaitForChild("TopHudGui")

if fishingGui:GetAttribute("AuthoredUiV2") ~= true then
	warn("[AuthoredUiController] FishingGui is not marked AuthoredUiV2; leaving layout untouched")
	return
end
if topHudGui:GetAttribute("AuthoredTopHud") ~= true then
	warn("[AuthoredUiController] TopHudGui is not marked AuthoredTopHud; leaving layout untouched")
	return
end

-- Version 1615 can still contain two pre-migration layout patchers in
-- StarterPlayerScripts. They race the authored HUD every frame, so disable only
-- those exact obsolete copies and remove the one screen they generated.
local playerScripts = player:WaitForChild("PlayerScripts")
local retiredControllerNames = {
	ForceTopHudPosition = true,
	SeastarHudOverride = true,
	SeaStarHudOverride = true,
}

local function retireLegacyController(instance)
	if instance:IsA("LocalScript") and retiredControllerNames[instance.Name] then
		instance.Enabled = false
	end
end

for _, child in ipairs(playerScripts:GetChildren()) do
	retireLegacyController(child)
end
playerScripts.ChildAdded:Connect(retireLegacyController)

local forcedTopHud = playerGui:FindFirstChild("ForcedTopHudGui")
if forcedTopHud and forcedTopHud:IsA("ScreenGui") then
	forcedTopHud:Destroy()
end

local managedConnections = {}
local cameraConnection = nil
local boundTopButtons = setmetatable({}, { __mode = "k" })
local boundPanelEvents = setmetatable({}, { __mode = "k" })
local boundMenuRoots = setmetatable({}, { __mode = "k" })

local topButtonMenuGroup = {
	SettingsButton = "Settings",
	QuestsButton = "Quests",
	ShopButton = "Shop",
	TopLoginRewardButton = "DailyReward",
}

local menuRootGroup = {
	SettingsOverlay = "Settings",
	ModernQuestUI = "Quests",
	MainPanel = "Shop",
	LoginRewardOverlay = "DailyReward",
	ModernBagRoot = "Bag",
	ModernFishdex = "Fishdex",
	RodShopOverlay = "Other",
	ModernSupplyShop = "Other",
	ModernSeasideShop = "Other",
	BiomeWarpOverlay = "Other",
	FishmongerSellOverlay = "Other",
}

local function closeMenusExcept(requestedGroup)
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("GuiObject") and descendant.Visible then
			local openGroup = menuRootGroup[descendant.Name]
			if openGroup and openGroup ~= requestedGroup then
				descendant.Visible = false
			end
		end
	end
end

local function bindTopMenuButton(button)
	if not button:IsA("GuiButton") or not topButtonMenuGroup[button.Name] or boundTopButtons[button] then
		return
	end
	boundTopButtons[button] = true
	button.InputBegan:Connect(function(input)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.Touch
			or inputType == Enum.UserInputType.MouseButton1 then
			closeMenusExcept(topButtonMenuGroup[button.Name])
		end
	end)
end

local function bindPanelEvent(instance)
	if not instance:IsA("BindableEvent")
		or instance.Name ~= "OpenFishingPanel"
		or boundPanelEvents[instance] then
		return
	end
	boundPanelEvents[instance] = true
	instance.Event:Connect(function(tabName)
		if tabName == "Bag" or tabName == "Fishdex" then
			closeMenusExcept(tabName)
		elseif tabName == "__CloseFishingPanels" then
			closeMenusExcept(nil)
		end
	end)
end

local function disconnect(connection)
	if connection then
		connection:Disconnect()
	end
end

local function findNamed(root, name)
	local direct = root:FindFirstChild(name)
	if direct then
		return direct
	end
	return root:FindFirstChild(name, true)
end

local function updateTopButtonsVisibility()
	local topButtons = findNamed(topHudGui, "TopButtonsFrame")
	local menuVisible = false
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("GuiObject")
			and menuRootGroup[descendant.Name]
			and descendant.Visible then
			menuVisible = true
			break
		end
	end

	if topButtons and topButtons:IsA("GuiObject") then
		topButtons.Visible = not menuVisible
	end
	for _, name in ipairs({ "FishingXPText", "CoinsHud", "SeaStarsHud" }) do
		local edgeHud = findNamed(fishingGui, name)
		if edgeHud and edgeHud:IsA("GuiObject") then
			edgeHud.Visible = not menuVisible
		end
	end
end

local function bindMenuRoot(instance)
	if not instance:IsA("GuiObject") or not menuRootGroup[instance.Name] or boundMenuRoots[instance] then
		return
	end
	boundMenuRoots[instance] = true
	instance:GetPropertyChangedSignal("Visible"):Connect(function()
		task.defer(updateTopButtonsVisibility)
	end)
end

local function getViewportSize()
	local camera = Workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1600, 900)
end

local function getDeviceScale(target)
	if not target or not target:IsA("GuiObject") then
		return nil
	end

	local scale = target:FindFirstChild("DeviceScale")
	if scale and scale:IsA("UIScale") then
		return scale
	end

	local preferredName = ({
		FishingXPText = "LeftStatsScale",
		CoinsHud = "LeftStatsScale",
		SeaStarsHud = "LeftStatsScale",
		TopButtonsFrame = "TopHudScale",
		BottomButtonsFrame = "BottomHudScale",
	})[target.Name]
	if preferredName then
		local preferred = target:FindFirstChild(preferredName)
		if preferred and preferred:IsA("UIScale") then
			return preferred
		end
	end

	-- Feature canvases can keep a separately named design scale. Only an
	-- explicitly tagged scale may be used by this controller, preventing the
	-- old double-scaling race between feature modules and the global adapter.
	for _, child in ipairs(target:GetChildren()) do
		if child:IsA("UIScale") and child:GetAttribute("DeviceScale") == true then
			return child
		end
	end

	return nil
end

local function calculateHudScale(viewport)
	-- v1636 used 0.74 for the edge HUD at both the 894x465 reference capture
	-- and the full desktop layout. Keep that value stable on desktop so the
	-- saved StarterGui hierarchy and PlayerGui are visually identical. Only
	-- reduce it when a genuinely smaller viewport cannot fit the authored HUD.
	local fit = math.min(viewport.X / 894, viewport.Y / 465, 1)
	return math.clamp(0.74 * fit, 0.52, 0.74)
end

local function calculateLeftStatsScale(viewport)
	return calculateHudScale(viewport)
end

local function calculateModalScale(viewport, designWidth, designHeight)
	local horizontalPadding = math.max(20, math.floor(viewport.X * 0.04))
	local verticalPadding = math.max(28, math.floor(viewport.Y * 0.08))
	return math.clamp(
		math.min(
			(viewport.X - horizontalPadding * 2) / designWidth,
			(viewport.Y - verticalPadding * 2) / designHeight,
			1
		),
		0.18,
		1
	)
end

local function applyScale(target, value)
	local scale = getDeviceScale(target)
	if scale and math.abs(scale.Scale - value) > 0.001 then
		scale.Scale = value
	end
end

local function updateLeftStats(_viewport, statsScale)
	local xp = findNamed(fishingGui, "FishingXPText")
	local coins = findNamed(fishingGui, "CoinsHud")
	local seaStars = findNamed(fishingGui, "SeaStarsHud")

	if xp and xp:IsA("GuiObject") then
		-- Align the level label's left edge with the coin and Sea Star icons.
		xp.AnchorPoint = Vector2.zero
		xp.Position = UDim2.new(0.01, 0, 0.10, -44)
		xp.Size = UDim2.fromOffset(380, 54)
		local levelText = xp:FindFirstChild("XPCombinedText")
		if levelText and levelText:IsA("TextLabel") then
			levelText.TextXAlignment = Enum.TextXAlignment.Left
		end
		applyScale(xp, statsScale)
	end
	if coins and coins:IsA("GuiObject") then
		coins.AnchorPoint = Vector2.zero
		-- The icon artwork has six transparent pixels on its left edge. Offset
		-- the host so the first visible pixel lines up with the level text.
		coins.Position = UDim2.new(0.01, -6, 0.10, 0)
		coins.Size = UDim2.fromOffset(430, 96)
		applyScale(coins, statsScale)
	end
	if seaStars and seaStars:IsA("GuiObject") then
		seaStars.AnchorPoint = Vector2.zero
		seaStars.Position = UDim2.new(0.01, -8, 0.10, 49)
		seaStars.Size = UDim2.fromOffset(330, 96)
		applyScale(seaStars, statsScale)
	end
end

local function updateLayout()
	local viewport = getViewportSize()
	local hudScale = calculateHudScale(viewport)

	updateLeftStats(viewport, calculateLeftStatsScale(viewport))

	local topButtons = findNamed(topHudGui, "TopButtonsFrame")
	if topButtons and topButtons:IsA("GuiObject") then
		topButtons.Position = UDim2.new(0.5, 0, 0, 0)
		applyScale(topButtons, hudScale)
	end

	local bottomButtons = findNamed(fishingGui, "BottomButtonsFrame")
	if bottomButtons and bottomButtons:IsA("GuiObject") then
		applyScale(bottomButtons, hudScale)
	end

end

local function bindTarget(target)
	if not target:IsA("GuiObject") then
		return
	end

	local scale = getDeviceScale(target)
	if scale and not managedConnections[scale] then
		managedConnections[scale] = scale:GetPropertyChangedSignal("Scale"):Connect(function()
			task.defer(updateLayout)
		end)
	end
end

for _, descendant in ipairs(fishingGui:GetDescendants()) do
	bindTarget(descendant)
	bindPanelEvent(descendant)
end
for _, descendant in ipairs(topHudGui:GetDescendants()) do
	bindTarget(descendant)
	bindTopMenuButton(descendant)
end
for _, descendant in ipairs(playerGui:GetDescendants()) do
	bindMenuRoot(descendant)
end

fishingGui.DescendantAdded:Connect(function(descendant)
	bindTarget(descendant)
	bindPanelEvent(descendant)
	task.defer(updateLayout)
end)
topHudGui.DescendantAdded:Connect(function(descendant)
	bindTarget(descendant)
	bindTopMenuButton(descendant)
	task.defer(updateLayout)
end)
playerGui.DescendantAdded:Connect(function(descendant)
	bindMenuRoot(descendant)
	task.defer(updateTopButtonsVisibility)
end)

local function bindCamera(camera)
	disconnect(cameraConnection)
	cameraConnection = nil

	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.defer(updateLayout)
		end)
	end

	updateLayout()
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindCamera(Workspace.CurrentCamera)
end)

bindCamera(Workspace.CurrentCamera)
task.defer(updateTopButtonsVisibility)
