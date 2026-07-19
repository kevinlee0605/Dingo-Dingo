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

local HUD_TEXT_LEFT = 12
local HUD_ICON_FRAME_LEFT = 8

-- AuthoredUiController is the sole scale/position writer for these saved
-- FishingGui hosts. ResponsiveUiAdapter still owns the custom hotbar, UTC
-- clock, daily reward fitting, and menu-safe-band logic below.
local authoredFishingHudHosts = {
	TopButtonsFrame = true,
	CoinsHud = true,
	SeaStarsHud = true,
	FishingXPText = true,
	BottomButtonsFrame = true,
}

local function isAuthoredFishingHudHost(target)
	if not authoredFishingHudHosts[target.Name] then
		return false
	end
	local parent = target.Parent
	if not (parent and parent:IsA("ScreenGui")) then
		return false
	end
	if parent.Name == "FishingGui" then
		return parent:GetAttribute("AuthoredUiV2") == true
	end
	if target.Name == "TopButtonsFrame" and parent.Name == "TopHudGui" then
		return parent:GetAttribute("AuthoredTopHud") == true
	end
	return false
end

local function alignLeftHud(target)
	if isAuthoredFishingHudHost(target) then
		return
	end
	if target.Name == "XPCombinedText" and target:IsA("TextLabel") then
		target.TextXAlignment = Enum.TextXAlignment.Left
	elseif target.Name == "FishingXPText" and target:IsA("GuiObject") then
		local logicalWidth = target.Size.X.Offset > 0 and target.Size.X.Offset or 380
		target.Position = UDim2.new(
			0,
			HUD_TEXT_LEFT + logicalWidth * target.AnchorPoint.X,
			target.Position.Y.Scale,
			target.Position.Y.Offset
		)
	elseif (target.Name == "CoinsHud" or target.Name == "SeaStarsHud") and target:IsA("GuiObject") then
		target.Position = UDim2.new(
			0,
			HUD_ICON_FRAME_LEFT,
			target.Position.Y.Scale,
			target.Position.Y.Offset
		)
	end
end

for _, descendant in ipairs(playerGui:GetDescendants()) do
	alignLeftHud(descendant)
end
playerGui.DescendantAdded:Connect(alignLeftHud)

-- The desktop design is authored against the usable area of fullscreen Studio
-- on a 1920x1080 display (roughly 1600 pixels wide after Studio chrome/panels).
-- Run the adapter on any smaller viewport so the left statistics can preserve
-- that visual proportion on every landscape resolution, not just touch devices.
local needsViewportScaling = initialViewport.X < 1600 or initialViewport.Y < 640
if not isCompactViewport
	and not isTouchPrimaryDevice
	and not isTenFootInterface
	and not needsViewportScaling
then
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

local leftStatsTargets = {
	CoinsHud = true,
	SeaStarsHud = true,
	FishingXPText = true,
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
local menuCanvasUpdaters = setmetatable({}, { __mode = "k" })
local bagTextRecords = setmetatable({}, { __mode = "k" })
local boundBagTextCanvases = setmetatable({}, { __mode = "k" })

local RESPONSIVE_TEXT_CONSTRAINT_NAME = "ResponsiveTextMinimum"

local currentHudScale = 1
local currentStatsScale = 1

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

local menuCanvasNames = {
	ModernQuestUI = true,
	SettingsCanvas = true,
	MainPanel = true,
	ModernFishdex = true,
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
	if UserInputService.TouchEnabled and viewport.X > viewport.Y and shortSide <= 480 then
		-- Compact landscape phones need a little more room between the top HUD
		-- and hotbar. The 0.70 floor keeps the smallest buttons at least 44 px.
		return lerp(0.70, 0.74, math.clamp((shortSide - 320) / 160, 0, 1))
	end
	if shortSide <= 480 then
		return 0.74
	elseif shortSide <= 640 then
		return lerp(0.74, 0.84, (shortSide - 480) / 160)
	elseif shortSide <= 900 then
		return lerp(0.84, 1, (shortSide - 640) / 260)
	end

	return 1
end

local function calculateStatsScale(viewport)
	-- Unlike buttons, these readouts do not need a minimum touch-target size.
	-- Scale them continuously from the fullscreen Studio reference area. Width
	-- normally controls landscape devices; height protects very wide displays.
	local widthScale = viewport.X / 1600
	local heightScale = viewport.Y / 640
	return math.clamp(math.min(widthScale, heightScale), 0.42, 1)
end

local function getHudTargetScale(target)
	if leftStatsTargets[target.Name] then
		return currentStatsScale
	end
	return currentHudScale
end

local function positionBottomLeftHud(target)
	if target.Name ~= "FishingXPText"
		and target.Name ~= "CoinsHud"
		and target.Name ~= "SeaStarsHud"
		and target.Name ~= "ClockFrame"
	then
		return
	end

	local viewport = getViewportSize()
	local targetScale = getHudTargetScale(target)

	if target.Name == "CoinsHud" then
		target.Position = UDim2.new(0, HUD_ICON_FRAME_LEFT, 0.10, 0)
		return
	end

	if target.Name == "SeaStarsHud" then
		local fishingGui = playerGui:FindFirstChild("FishingGui")
		local coinsHud = fishingGui and fishingGui:FindFirstChild("CoinsHud")
		local basePosition = coinsHud and coinsHud:IsA("GuiObject")
			and coinsHud.Position
			or UDim2.new(0, HUD_ICON_FRAME_LEFT, 0.10, 0)
		local coinHeight = coinsHud and coinsHud:IsA("GuiObject")
			and coinsHud.Size.Y.Offset
			or target.Size.Y.Offset
		if coinHeight <= 0 then
			coinHeight = 96
		end

		-- The desktop art overlaps these two 96px rows by 22px. Scale that
		-- complete 74px step so the group remains compact on smaller screens.
		local rowStep = (math.max(48, coinHeight) - 22) * currentStatsScale
		target.Position = UDim2.new(
			0,
			HUD_ICON_FRAME_LEFT,
			basePosition.Y.Scale,
			basePosition.Y.Offset + math.floor(rowStep + 0.5)
		)
		return
	end

	local logicalWidth = target.Size.X.Offset
	if logicalWidth <= 0 then
		logicalWidth = target.AbsoluteSize.X / math.max(targetScale, 0.01)
	end

	local leftMargin = target.Name == "FishingXPText"
		and HUD_TEXT_LEFT
		or math.max(8, math.floor(viewport.X * 0.015))
	local centerX = leftMargin + logicalWidth * targetScale * target.AnchorPoint.X

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
		logicalHeight = target.AbsoluteSize.Y / math.max(targetScale, 0.01)
	end

	local anchorXOffset = math.floor(logicalWidth * targetScale * target.AnchorPoint.X + 0.5)
	local anchorYOffset = math.floor(logicalHeight * targetScale * (1 - target.AnchorPoint.Y) + 0.5)
	local rowGap = math.max(2, math.floor(6 * targetScale + 0.5))
	if coinsHud and coinsHud:IsA("GuiObject") then
		target.Position = UDim2.new(
			coinsHud.Position.X.Scale,
			coinsHud.Position.X.Offset + (HUD_TEXT_LEFT - HUD_ICON_FRAME_LEFT) + anchorXOffset,
			coinsHud.Position.Y.Scale,
			coinsHud.Position.Y.Offset - anchorYOffset - rowGap
		)
		return
	end

	target.Position = UDim2.new(0, math.floor(centerX + 0.5), 0.10, -anchorYOffset - rowGap)
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
			local targetScale = getHudTargetScale(target)
			if target.Parent and math.abs(scale.Scale - targetScale) > 0.001 then
				task.defer(scaleHudTarget, target)
			end
		end)
	end

	local targetScale = getHudTargetScale(target)
	if math.abs(scale.Scale - targetScale) > 0.001 then
		scale.Scale = targetScale
	end

	positionBottomLeftHud(target)

	if not loggedHudTargets[target] then
		loggedHudTargets[target] = true
		print(string.format(
			"[ResponsiveUiAdapter] Managed %s at scale %.3f",
			target.Name,
			targetScale
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
	-- The authored custom hotbar has its own viewport binding. Letting this
	-- legacy adapter bind it too produces a scale race on narrower viewports.
	if screenGui:GetAttribute("AuthoredCustomHotbar") == true then
		return
	end

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

local function getVisibleTopHudBottom()
	local topFrame = playerGui:FindFirstChild("ForcedTopButtonsFrame", true)
		or playerGui:FindFirstChild("TopButtonsFrame", true)
	if topFrame and topFrame:IsA("GuiObject") and topFrame.Visible then
		return topFrame.AbsolutePosition.Y + topFrame.AbsoluteSize.Y
	end
	return nil
end

local function getVisibleHotbarTop()
	local hotbarGui = playerGui:FindFirstChild("CustomHotbarGui")
	if not hotbarGui or not hotbarGui:IsA("ScreenGui") then
		return nil
	end

	local container = findHotbarContainer(hotbarGui)
	if container and container.Visible and container.AbsoluteSize.Y > 0 then
		return container.AbsolutePosition.Y
	end
	return nil
end

local function getMenuSafeBand()
	if not UserInputService.TouchEnabled then
		return nil, nil
	end

	local viewport = getViewportSize()
	local top = getVisibleTopHudBottom() or viewport.Y * 0.16
	local bottom = getVisibleHotbarTop() or viewport.Y * 0.84
	local menuGap = viewport.X > viewport.Y and viewport.Y <= 400 and 4 or 10
	top += menuGap
	bottom -= menuGap

	if bottom - top < 140 then
		top = viewport.Y * 0.18
		bottom = viewport.Y * 0.82
	end

	return top, bottom
end

local function fitCanvasInsideHudBand(canvas, scale, originalPosition, widthFactor)
	local top, bottom = getMenuSafeBand()
	if not top or not bottom then
		if canvas.Position ~= originalPosition then
			canvas.Position = originalPosition
		end
		return nil
	end

	local baseWidth = canvas.Size.X.Offset
	local baseHeight = canvas.Size.Y.Offset
	if baseWidth <= 0 or baseHeight <= 0 then
		return nil
	end

	local viewport = getViewportSize()
	local maximumFit = math.max(
		0.1,
		math.min(
			(viewport.X * (widthFactor or 0.94)) / baseWidth,
			(bottom - top) / baseHeight,
			1
		)
	)

	local renderedHeight = baseHeight * math.min(scale.Scale, maximumFit)
	local desiredAnchorY = (top + bottom) * 0.5
		+ (canvas.AnchorPoint.Y - 0.5) * renderedHeight
	local parent = canvas.Parent
	local parentAbsoluteY = parent and parent:IsA("GuiObject")
		and parent.AbsolutePosition.Y
		or 0
	local desiredPosition = UDim2.new(
		originalPosition.X.Scale,
		originalPosition.X.Offset,
		0,
		math.floor(desiredAnchorY - parentAbsoluteY + 0.5)
	)
	if canvas.Position ~= desiredPosition then
		canvas.Position = desiredPosition
	end

	return maximumFit
end

local function isKnownMenuCanvas(instance)
	if menuCanvasNames[instance.Name] then
		return true
	end
	if instance.Name == "Canvas" then
		return instance:FindFirstAncestor("ModernBagRoot") ~= nil
	end
	return false
end

local function updateBagTextObject(object, scale)
	if not (object:IsA("TextLabel") or object:IsA("TextButton")) then
		return
	end

	local record = bagTextRecords[object]
	if not record then
		local parent = object.Parent
		local isTabLabel = object:IsA("TextLabel")
			and object.Name == "Label"
			and parent
			and string.match(parent.Name, "Tab$") ~= nil
		local existingConstraint = object:FindFirstChildOfClass("UITextSizeConstraint")

		if isTabLabel and object.TextScaled and existingConstraint then
			record = {
				isTabLabel = true,
				textScaled = object.TextScaled,
				textSize = object.TextSize,
				textWrapped = object.TextWrapped,
				constraint = existingConstraint,
				minTextSize = existingConstraint.MinTextSize,
				maxTextSize = existingConstraint.MaxTextSize,
			}
			bagTextRecords[object] = record
		else
			-- The large title and other already-scaled labels are intentionally left
			-- alone. This only protects the fixed-size item text that became tiny
			-- when the complete 1448x1086 Bag canvas was reduced for a phone.
			if object.TextScaled or object.TextSize > 36 then
				return
			end

			record = {
				isTabLabel = false,
				textScaled = object.TextScaled,
				textSize = object.TextSize,
			}
			bagTextRecords[object] = record
		end
	end

	local useMobileMinimum = UserInputService.TouchEnabled and scale.Scale < 0.34
	if record.isTabLabel then
		local constraint = record.constraint
		if not constraint or not constraint.Parent then
			return
		end

		if useMobileMinimum then
			if scale.Scale < 0.18 then
				constraint.MinTextSize = 9
			elseif scale.Scale < 0.22 then
				constraint.MinTextSize = 11
			else
				constraint.MinTextSize = record.minTextSize
			end
			constraint.MaxTextSize = record.maxTextSize
			object.TextWrapped = object.Parent.Name == "RodsTab"
		else
			constraint.MinTextSize = record.minTextSize
			constraint.MaxTextSize = record.maxTextSize
			object.TextWrapped = record.textWrapped
		end
		return
	end

	local responsiveConstraint = object:FindFirstChild(RESPONSIVE_TEXT_CONSTRAINT_NAME)

	if useMobileMinimum then
		object.TextScaled = true
		if not responsiveConstraint then
			responsiveConstraint = Instance.new("UITextSizeConstraint")
			responsiveConstraint.Name = RESPONSIVE_TEXT_CONSTRAINT_NAME
			responsiveConstraint.Parent = object
		end

		local minimumSize = record.textSize >= 30 and 9 or 8
		responsiveConstraint.MinTextSize = minimumSize
		responsiveConstraint.MaxTextSize = math.max(minimumSize, record.textSize)
	else
		if responsiveConstraint then
			responsiveConstraint:Destroy()
		end
		object.TextScaled = record.textScaled
	end
end

local function updateBagTextReadability(canvas, scale)
	for _, descendant in ipairs(canvas:GetDescendants()) do
		updateBagTextObject(descendant, scale)
	end
end

local function bindBagTextReadability(canvas, scale)
	if boundBagTextCanvases[canvas] then
		updateBagTextReadability(canvas, scale)
		return
	end

	boundBagTextCanvases[canvas] = true
	canvas.DescendantAdded:Connect(function(descendant)
		task.defer(function()
			if descendant.Parent and scale.Parent then
				updateBagTextObject(descendant, scale)
			end
		end)
	end)
	updateBagTextReadability(canvas, scale)
end

local function bindMenuCanvasFit(canvas)
	if not canvas:IsA("GuiObject") or not isKnownMenuCanvas(canvas) then
		return
	end

	local scale = canvas:FindFirstChildWhichIsA("UIScale")
	if not scale or menuCanvasUpdaters[scale] then
		return
	end

	local originalPosition = canvas.Position
	local isBagCanvas = canvas.Name == "Canvas"
		and canvas:FindFirstAncestor("ModernBagRoot") ~= nil
	local applying = false
	local function updateFit()
		if applying or not canvas.Parent or not scale.Parent then
			return
		end

		applying = true
		local maximumFit = fitCanvasInsideHudBand(
			canvas,
			scale,
			originalPosition,
			0.94
		)
		if maximumFit and scale.Scale > maximumFit + 0.001 then
			scale.Scale = maximumFit
		end
		if isBagCanvas then
			updateBagTextReadability(canvas, scale)
		end
		applying = false
	end

	menuCanvasUpdaters[scale] = updateFit
	scale:GetPropertyChangedSignal("Scale"):Connect(updateFit)
	canvas:GetPropertyChangedSignal("Visible"):Connect(function()
		if canvas.Visible then
			task.defer(updateFit)
		end
	end)
	local parent = canvas.Parent
	if parent and parent:IsA("GuiObject") then
		parent:GetPropertyChangedSignal("Visible"):Connect(function()
			if parent.Visible then
				task.defer(updateFit)
			end
		end)
	end
	if isBagCanvas then
		bindBagTextReadability(canvas, scale)
	end
	updateFit()
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
	local originalPosition = canvas.Position

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
		local bandFit = fitCanvasInsideHudBand(
			canvas,
			scale,
			originalPosition,
			0.92
		)
		if bandFit then
			maximumFit = math.min(maximumFit, bandFit)
		end

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
	overlay:GetPropertyChangedSignal("Visible"):Connect(function()
		if overlay.Visible then
			task.defer(fitCanvas)
		end
	end)
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
			if not isAuthoredFishingHudHost(instance) then
				task.defer(function()
					if instance.Parent then
						scaleHudTarget(instance)
					end
				end)
			end
		elseif instance.Name == DAILY_REWARD_OVERLAY_NAME then
			task.defer(bindDailyRewardFit, instance)
		elseif isKnownMenuCanvas(instance) then
			task.defer(bindMenuCanvasFit, instance)
		end
	elseif instance:IsA("UIScale") then
		local parent = instance.Parent
		if parent and parent:IsA("GuiObject") and isKnownMenuCanvas(parent) then
			task.defer(bindMenuCanvasFit, parent)
		end
	end
end

local function updateAll()
	local viewport = getViewportSize()
	currentHudScale = calculateHudScale(viewport)
	currentStatsScale = calculateStatsScale(viewport)

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

	for scale, updateFit in pairs(menuCanvasUpdaters) do
		if scale.Parent then
			updateFit()
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
