local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local fishingGui = playerGui:WaitForChild("FishingGui")

if fishingGui:GetAttribute("AuthoredUiV2") ~= true then
	warn("[AuthoredUiController] FishingGui is not marked AuthoredUiV2; leaving layout untouched")
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
	local widthScale = viewport.X / 1600
	local heightScale = viewport.Y / 900
	local scale = math.min(widthScale, heightScale)

	if viewport.X < viewport.Y then
		scale *= 0.92
	end

	return math.clamp(scale, 0.52, 1.08)
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

local function updateLeftStats(viewport, hudScale)
	local xp = findNamed(fishingGui, "FishingXPText")
	local coins = findNamed(fishingGui, "CoinsHud")
	local seaStars = findNamed(fishingGui, "SeaStarsHud")

	local targets = { xp, coins, seaStars }
	for _, target in ipairs(targets) do
		if target and target:IsA("GuiObject") then
			target.AnchorPoint = Vector2.zero
			applyScale(target, hudScale)
		end
	end

	local left = math.max(12, math.floor(viewport.X * 0.008))
	local top = math.max(10, math.floor(viewport.Y * 0.018))
	local gap = math.max(2, math.floor(5 * hudScale + 0.5))

	if xp and xp:IsA("GuiObject") then
		xp.Position = UDim2.fromOffset(left, top)
	end

	local xpHeight = xp and math.max(32, xp.Size.Y.Offset) or 42
	local coinsTop = top + math.floor(xpHeight * hudScale + gap)
	if coins and coins:IsA("GuiObject") then
		coins.Position = UDim2.fromOffset(left, coinsTop)
	end

	local coinsHeight = coins and math.max(48, coins.Size.Y.Offset) or 76
	local seaStarsTop = coinsTop + math.floor((coinsHeight - 20) * hudScale + gap)
	if seaStars and seaStars:IsA("GuiObject") then
		seaStars.Position = UDim2.fromOffset(left, seaStarsTop)
	end
end

local MODAL_CANVASES = {
	{ root = "SettingsOverlay", canvas = "SettingsCanvas", width = 1448, height = 1086 },
	{ root = "ModernBagRoot", canvas = "Canvas", width = 1448, height = 1086 },
	{ root = "ModernQuestUI", canvas = "QuestCanvas", width = 1536, height = 1024 },
	{ root = "ModernFishdex", canvas = "FishdexCanvas", width = 1536, height = 1024 },
	{ root = "MainPanel", canvas = "ShopCanvas", width = 1200, height = 900 },
}

local function updateModalScales(viewport)
	for _, definition in ipairs(MODAL_CANVASES) do
		local root = findNamed(fishingGui, definition.root)
		if root and root:IsA("GuiObject") then
			local canvas = root:FindFirstChild(definition.canvas, true) or root
			if canvas:IsA("GuiObject") then
				local width = tonumber(canvas:GetAttribute("DesignWidth")) or definition.width
				local height = tonumber(canvas:GetAttribute("DesignHeight")) or definition.height
				applyScale(canvas, calculateModalScale(viewport, width, height))
			end
		end
	end
end

local function updateLayout()
	local viewport = getViewportSize()
	local hudScale = calculateHudScale(viewport)

	updateLeftStats(viewport, hudScale)

	for _, name in ipairs({ "TopButtonsFrame", "BottomButtonsFrame" }) do
		local target = findNamed(fishingGui, name)
		if target and target:IsA("GuiObject") then
			applyScale(target, hudScale)
		end
	end

	updateModalScales(viewport)
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
end

fishingGui.DescendantAdded:Connect(function(descendant)
	bindTarget(descendant)
	task.defer(updateLayout)
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
