local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Fullscreen Studio with Device Emulator disabled is the visual source of truth.
-- A compact viewport is also treated as responsive because Studio's Device
-- Emulator does not always report TouchEnabled to LocalScripts.
local isTenFootInterface = GuiService:IsTenFootInterface()
local function waitForRealViewport()
	for _ = 1, 120 do
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize
		if viewport and viewport.X >= 64 and viewport.Y >= 64 then
			return viewport
		end
		RunService.RenderStepped:Wait()
	end

	return Vector2.new(1920, 1080)
end

local initialViewport = waitForRealViewport()
local isCompactViewport = math.min(initialViewport.X, initialViewport.Y) < 900
local isTouchPrimaryDevice = UserInputService.TouchEnabled
	and (
		not UserInputService.KeyboardEnabled
		or not UserInputService.MouseEnabled
	)

if not isCompactViewport and not isTouchPrimaryDevice and not isTenFootInterface then
	return
end

print(string.format(
	"[ResponsiveUiAdapter] Active at %dx%d (touch=%s, ten-foot=%s)",
	math.floor(initialViewport.X),
	math.floor(initialViewport.Y),
	tostring(UserInputService.TouchEnabled),
	tostring(isTenFootInterface)
))

local DEVICE_SCALE_NAME = "FishyFishDeviceScale"
local DAILY_REWARD_OVERLAY_NAME = "LoginRewardOverlay"

local namedHudTargets = {
	TopButtonsFrame = true,
	ForcedTopButtonsFrame = true,
	CoinsHud = true,
	SeaStarsHud = true,
	FishingXPText = true,
	BottomButtonsFrame = true,
	ClockFrame = true,
}

local safeInsetScreenGuis = {
	CustomHotbarGui = true,
	ServerUtcClockGui = true,
}

local managedScales = setmetatable({}, { __mode = "k" })
local guardedScales = setmetatable({}, { __mode = "k" })
local loggedHudTargets = setmetatable({}, { __mode = "k" })
local dailyRewardUpdaters = setmetatable({}, { __mode = "k" })
local boundHotbarGuis = setmetatable({}, { __mode = "k" })
local boundMenuButtons = setmetatable({}, { __mode = "k" })

local currentHudScale = 1

local topButtonMenuGroup = {
	SettingsButton = "Settings",
	QuestsButton = "Quests",
	ShopButton = "Shop",
	TopLoginRewardButton = "DailyReward",
	DailyRewardButton = "DailyReward",
	LoginRewardButton = "DailyReward",
}

local menuRootGroup = {
	SettingsOverlay = "Settings",
	ModernQuestUI = "Quests",
	MainPanel = "Shop",
	LoginRewardOverlay = "DailyReward",
	ModernBagRoot = "Other",
	ModernFishdex = "Other",
	RodShopOverlay = "Other",
	SeaStarShopOverlay = "Other",
	ModernSupplyShop = "Other",
	ModernSeasideShop = "Other",
	BiomeWarpOverlay = "Other",
	FishmongerSellOverlay = "Other",
}

local function getViewportSize()
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

local function lerp(a, b, alpha)
	return a + (b - a) * alpha
end

local function calculateHudScale(viewport)
	if isTenFootInterface then
		return 1
	end

	-- Short-side breakpoints keep portrait and landscape versions of the same
	-- device visually consistent. The lower limit also keeps touch targets large.
	local shortSide = math.min(viewport.X, viewport.Y)
	if shortSide <= 480 then
		return 0.74
	elseif shortSide <= 640 then
		return lerp(0.74, 0.84, (shortSide - 480) / 160)
	elseif shortSide <= 900 then
		return lerp(0.84, 1, (shortSide - 640) / 260)
	end

	return 1
end

local function positionBottomLeftHud(target)
	if target.Name ~= "FishingXPText" and target.Name ~= "ClockFrame" then
		return
	end

	local viewport = getViewportSize()
	local logicalWidth = target.Size.X.Offset
	if logicalWidth <= 0 then
		logicalWidth = target.AbsoluteSize.X / math.max(currentHudScale, 0.01)
	end

	local leftMargin = math.max(8, math.floor(viewport.X * 0.015))
	local centerX = leftMargin + logicalWidth * currentHudScale * target.AnchorPoint.X

	if target.Name == "ClockFrame" then
		target.Position = UDim2.new(0, math.floor(centerX + 0.5), 1, -10)
		return
	end

	-- Keep the level row immediately above the coin HUD on compact screens.
	-- Use the coin HUD's scale coordinates so both rows stay together as the
	-- viewport changes, while the offsets account for their applied UIScales.
	local fishingGui = playerGui:FindFirstChild("FishingGui")
	local coinsHud = fishingGui and fishingGui:FindFirstChild("CoinsHud")
	local logicalHeight = target.Size.Y.Offset
	if logicalHeight <= 0 then
		logicalHeight = target.AbsoluteSize.Y / math.max(currentHudScale, 0.01)
	end

	local anchorXOffset = math.floor(logicalWidth * currentHudScale * target.AnchorPoint.X + 0.5)
	local anchorYOffset = math.floor(logicalHeight * currentHudScale * (1 - target.AnchorPoint.Y) + 0.5)
	if coinsHud and coinsHud:IsA("GuiObject") then
		target.Position = UDim2.new(
			coinsHud.Position.X.Scale,
			coinsHud.Position.X.Offset + anchorXOffset,
			coinsHud.Position.Y.Scale,
			coinsHud.Position.Y.Offset - anchorYOffset - 6
		)
		return
	end

	target.Position = UDim2.new(0, math.floor(centerX + 0.5), 0.10, -anchorYOffset - 6)
end

local function closeConflictingMenus(buttonName)
	local requestedGroup = topButtonMenuGroup[buttonName]
	if not requestedGroup then
		return
	end

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
	if boundMenuButtons[button] or not topButtonMenuGroup[button.Name] then
		return
	end

	boundMenuButtons[button] = true
	button.InputBegan:Connect(function(input)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.Touch
			or inputType == Enum.UserInputType.MouseButton1
		then
			closeConflictingMenus(button.Name)
		end
	end)
end

local function findDirectScale(target, preferredName)
	if preferredName then
		local preferred = target:FindFirstChild(preferredName)
		if preferred and preferred:IsA("UIScale") then
			return preferred
		end
	end

	-- BottomButtonsFrame already owns an otherwise-unused direct UIScale.
	if target.Name == "BottomButtonsFrame" then
		for _, child in ipairs(target:GetChildren()) do
			if child:IsA("UIScale") then
				return child
			end
		end
	end

	local existing = target:FindFirstChild(DEVICE_SCALE_NAME)
	if existing and existing:IsA("UIScale") then
		return existing
	end

	local scale = Instance.new("UIScale")
	scale.Name = DEVICE_SCALE_NAME
	scale.Scale = 1
	scale.Parent = target
	return scale
end

local function scaleHudTarget(target)
	if not target:IsA("GuiObject") then
		return
	end

	local preferredName = target.Name == "TopButtonsFrame" and "TopHudScale" or nil
	local scale = managedScales[target]
	if not scale or not scale.Parent then
		scale = findDirectScale(target, preferredName)
		managedScales[target] = scale
	end

	if not guardedScales[scale] then
		guardedScales[scale] = true
		scale:GetPropertyChangedSignal("Scale"):Connect(function()
			if target.Parent and math.abs(scale.Scale - currentHudScale) > 0.001 then
				task.defer(scaleHudTarget, target)
			end
		end)
	end

	if math.abs(scale.Scale - currentHudScale) > 0.001 then
		scale.Scale = currentHudScale
	end

	positionBottomLeftHud(target)

	if not loggedHudTargets[target] then
		loggedHudTargets[target] = true
		print(string.format(
			"[ResponsiveUiAdapter] Managed %s at scale %.3f",
			target.Name,
			currentHudScale
		))
	end
end

local function applySafeInsets(screenGui)
	if not screenGui:IsA("ScreenGui") or not safeInsetScreenGuis[screenGui.Name] then
		return
	end

	-- These two ScreenGuis contain edge HUD only, not full-screen artwork.
	-- CoreUISafeInsets protects both Roblox controls and device cutouts.
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	screenGui.ClipToDeviceSafeArea = true
end

local function isFullScreenObject(object, viewport)
	local size = object.AbsoluteSize
	return size.X >= viewport.X * 0.90 and size.Y >= viewport.Y * 0.75
end

local function findHotbarContainer(screenGui)
	local viewport = getViewportSize()
	local bestNamed = nil
	local bestNamedArea = 0

	for _, descendant in ipairs(screenGui:GetDescendants()) do
		if descendant:IsA("GuiObject") and not isFullScreenObject(descendant, viewport) then
			local lowerName = string.lower(descendant.Name)
			local isContainerName = string.find(lowerName, "hotbar", 1, true)
				or string.find(lowerName, "slotsframe", 1, true)
				or string.find(lowerName, "slotscontainer", 1, true)
			if isContainerName then
				local area = descendant.AbsoluteSize.X * descendant.AbsoluteSize.Y
				if area > bestNamedArea then
					bestNamed = descendant
					bestNamedArea = area
				end
			end
		end
	end

	if bestNamed then
		return bestNamed
	end

	-- Some versions use a generic direct Frame name. Prefer the largest
	-- non-fullscreen direct object in the lower half of the screen.
	local bestDirect = nil
	local bestDirectArea = 0
	for _, child in ipairs(screenGui:GetChildren()) do
		if child:IsA("GuiObject") and not isFullScreenObject(child, viewport) then
			local centerY = child.AbsolutePosition.Y + child.AbsoluteSize.Y * 0.5
			local area = child.AbsoluteSize.X * child.AbsoluteSize.Y
			if centerY >= viewport.Y * 0.5 and area > bestDirectArea then
				bestDirect = child
				bestDirectArea = area
			end
		end
	end

	return bestDirect
end

local function updateHotbar(screenGui)
	local container = findHotbarContainer(screenGui)
	if container then
		scaleHudTarget(container)
	end
end

local function bindHotbarGui(screenGui)
	if boundHotbarGuis[screenGui] then
		updateHotbar(screenGui)
		return
	end

	boundHotbarGuis[screenGui] = true
	applySafeInsets(screenGui)

	screenGui.DescendantAdded:Connect(function()
		task.defer(updateHotbar, screenGui)
	end)

	-- Absolute sizes settle after the ScreenGui enters PlayerGui.
	task.defer(updateHotbar, screenGui)
end

local function getDailyRewardCanvas(overlay)
	for _, child in ipairs(overlay:GetChildren()) do
		if child:IsA("GuiObject") then
			local scale = child:FindFirstChildWhichIsA("UIScale")
			if scale and child.Size.X.Offset >= 1000 and child.Size.Y.Offset >= 700 then
				return child, scale
			end
		end
	end
	return nil, nil
end

local function bindDailyRewardFit(overlay)
	local canvas, scale = getDailyRewardCanvas(overlay)
	if not canvas or not scale or dailyRewardUpdaters[scale] then
		return
	end

	local applying = false
	local loggedFit = false

	local function fitCanvas()
		if applying or not canvas.Parent or not scale.Parent then
			return
		end

		local viewport = getViewportSize()
		local baseWidth = canvas.Size.X.Offset
		local baseHeight = canvas.Size.Y.Offset
		if baseWidth <= 0 or baseHeight <= 0 then
			return
		end

		local maximumFit = math.max(
			0.1,
			math.min(
				(viewport.X * 0.92) / baseWidth,
				(viewport.Y * 0.90) / baseHeight,
				1
			)
		)

		-- The source currently clamps Daily Rewards to 0.50. On phones that
		-- is larger than the viewport, so only cap values that would overflow.
		if scale.Scale > maximumFit + 0.001 then
			applying = true
			scale.Scale = maximumFit
			applying = false
		end

		if not loggedFit then
			loggedFit = true
			print(string.format(
				"[ResponsiveUiAdapter] Managed Daily Rewards at scale %.3f",
				scale.Scale
			))
		end
	end

	dailyRewardUpdaters[scale] = fitCanvas
	scale:GetPropertyChangedSignal("Scale"):Connect(fitCanvas)
	fitCanvas()
end

local function inspectInstance(instance)
	if instance:IsA("ScreenGui") then
		applySafeInsets(instance)
		if instance.Name == "CustomHotbarGui" then
			bindHotbarGui(instance)
		end
	end

	if instance:IsA("GuiObject") then
		if instance:IsA("GuiButton") then
			bindTopMenuButton(instance)
		end

		if namedHudTargets[instance.Name] then
			-- The HUD constructors parent Frames before adding their own UIScales.
			-- Defer one scheduler step so an existing design scale is reused.
			task.defer(function()
				if instance.Parent then
					scaleHudTarget(instance)
				end
			end)
		elseif instance.Name == DAILY_REWARD_OVERLAY_NAME then
			task.defer(bindDailyRewardFit, instance)
		end
	end
end

local function updateAll()
	currentHudScale = calculateHudScale(getViewportSize())

	for target in pairs(managedScales) do
		if target.Parent then
			scaleHudTarget(target)
		end
	end

	for screenGui in pairs(boundHotbarGuis) do
		if screenGui.Parent then
			updateHotbar(screenGui)
		end
	end

	for scale, fitCanvas in pairs(dailyRewardUpdaters) do
		if scale.Parent then
			fitCanvas()
		end
	end

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant.Name == DAILY_REWARD_OVERLAY_NAME and descendant:IsA("GuiObject") then
			bindDailyRewardFit(descendant)
		end
	end
end

for _, descendant in ipairs(playerGui:GetDescendants()) do
	inspectInstance(descendant)
end

playerGui.DescendantAdded:Connect(function(descendant)
	inspectInstance(descendant)
end)

local cameraConnection = nil
local function bindCamera(camera)
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end

	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.defer(updateAll)
		end)
	end

	updateAll()
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindCamera(Workspace.CurrentCamera)
end)

bindCamera(Workspace.CurrentCamera)
