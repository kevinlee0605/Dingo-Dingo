local MinigameController = {}

--[[
FISHING MINIGAME MODERN UI - NEW ASSETS + ROD GREEN SIZES

Replace this ModuleScript:
StarterGui/FishingGui/FishingClient/FishingMinigameModernUI

Assets:
- Blue Gauge: 138976342109765
- Fish Background: 74137560034505
- Main Panel: 134199963481930
- Slider Track: 85876175896136
- Wooden/Iron green bar: 84261877127360
- Golden/Emerald green bar: 91785205837549
- Ocean green bar: 135326965597959

Behavior:
- Wooden Rod and Iron Rod use the smallest green image/catch height.
- Golden Rod and Emerald Rod use the medium green image/catch height.
- Ocean Rod uses the largest green image/catch height.
- Existing fish movement, input, progress, success/failure, and server calls are preserved.
- Progress now uses visible fish/green-box overlap instead of checking only the fish center point.
- The right Blue Gauge now visibly grows from the bottom to the top as progress increases.
- The Blue Gauge is split into fixed rounded caps plus a stretchable center, preventing a pointed top.
- Gauge pieces now relayout automatically when RarityCatchController changes progressFill.Size.
- The fill is forced to the track bottom and clamped to the full inner height, so 100% touches the top exactly.
- Complete supplied image ratios are locked so the main panel and slider are not squashed.
- The entire UI group is shifted upward to clear the hotbar.
- The Blue Gauge fill starts at the bottom interior edge of the Slider Track.
- Blue Gauge stays at its original aspect ratio and moves vertically as one complete capsule.
- The complete Blue Gauge marker starts at the bottom and stops inside the top edge.
- The fishing background blur is disabled.
- During focused Rage Mode, the fill uses a fixed left edge and grows only to the right.
- Fish marker, green bar, and blue gauge default positions are tuned to match the supplied reference more closely.
- BlurEffect and DepthOfFieldEffect are disabled in Lighting and the current camera after normal render updates.
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local UI_VERSION = "NEW_ASSETS_ROD_GREEN_V19_NO_HEADER_BLACK_BANNER"

local ASSETS = {
	BlueGauge = "rbxassetid://138976342109765",
	PurpleGauge = "rbxassetid://139485689258376",
	OrangeGauge = "rbxassetid://127598747171041",
	RedGauge = "rbxassetid://97502541593370",
	RageWarning = "rbxassetid://92582541870517",
	FishBackground = "rbxassetid://74137560034505",
	MainPanel = "rbxassetid://134199963481930",
	SliderTrack = "rbxassetid://85876175896136",

	GreenWoodenIron = "rbxassetid://84261877127360",
	GreenGoldenEmerald = "rbxassetid://91785205837549",
	GreenOcean = "rbxassetid://135326965597959",
}

-- Supplied Blue Gauge source dimensions.
-- The image is rendered as three pieces so its rounded top can never become pointed.
local BLUE_GAUGE_WIDTH = 604
local BLUE_GAUGE_HEIGHT = 1026
local BLUE_GAUGE_CAP_HEIGHT = 240

-- A small source/geometry overlap prevents thin dark seams between the
-- three gauge slices. The supplied artwork and rounded ends stay unchanged.
local GAUGE_SOURCE_OVERLAP = 8
local GAUGE_SEAM_OVERLAP_PIXELS = 3

-- The complete group was designed from the supplied 850x1514 main panel
-- and 287x2048 slider track. This aspect keeps both images undistorted.
-- 전체 UI 크기/위치 조절
-- UI_SCALE: 1.10 = 10% 확대 / 0.90 = 10% 축소
-- UI_POSITION_X: 작아질수록 왼쪽 / 커질수록 오른쪽
-- UI_POSITION_Y: 작아질수록 위 / 커질수록 아래
local UI_SCALE = 0.9
local UI_POSITION_X = 0.3
local UI_POSITION_Y = 0.4

local PANEL_ASPECT = 0.76

-- Responsive size limits.
local DESKTOP_WIDTH_LIMIT = 0.48
local DESKTOP_HEIGHT_LIMIT = 0.74

local TABLET_WIDTH_LIMIT = 0.62
local TABLET_HEIGHT_LIMIT = 0.74

local PHONE_WIDTH_LIMIT = 0.90
local PHONE_HEIGHT_LIMIT = 0.70

local WHITE = Color3.fromRGB(255, 255, 255)
local PROGRESS_BLUE = Color3.fromRGB(19, 153, 255)
local PROGRESS_BLUE_LIGHT = Color3.fromRGB(102, 225, 255)

local function addCorner(obj, radiusScale, radiusOffset)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radiusScale or 0, radiusOffset or 12)
	corner.Parent = obj
	return corner
end

local function addGradient(obj, topColor, bottomColor, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topColor),
		ColorSequenceKeypoint.new(1, bottomColor),
	})
	gradient.Rotation = rotation or 90
	gradient.Parent = obj
	return gradient
end

local function makeImage(parent, name, image, position, size, zIndex)
	local img = Instance.new("ImageLabel")
	img.Name = name
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = position
	img.Size = size
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = image
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = zIndex or 1
	img.Parent = parent
	return img
end

local function setProgressFillAmount(progressFill, amount)
	-- The controller provides a normalized amount from 0 to 1.
	-- Keep one complete gauge and reveal it vertically from the bottom.
	-- The three image pieces preserve the rounded caps at every size.
	local clampedAmount = math.clamp(tonumber(amount) or 0, 0, 1)
	progressFill.AnchorPoint = Vector2.new(0.5, 1)
	progressFill.Position = UDim2.fromScale(0.5, 1)
	progressFill.Size = UDim2.fromScale(0.92, clampedAmount)
end

local NO_BLUR_RENDER_STEP = "FishingMinigame_NoPostBlur"

-- Connections used to stop other LocalScripts from turning Blur/DepthOfField
-- back on while the fishing minigame is visible.
local noBlurConnections = {}
local guardedPostEffects = setmetatable({}, { __mode = "k" })

local function disconnectNoBlurConnections()
	for _, connection in ipairs(noBlurConnections) do
		connection:Disconnect()
	end
	table.clear(noBlurConnections)
	table.clear(guardedPostEffects)
end

local function disablePostEffect(effect)
	if not effect or not effect.Parent then
		return
	end

	if effect:IsA("BlurEffect") then
		effect.Enabled = false
		effect.Size = 0
	elseif effect:IsA("DepthOfFieldEffect") then
		effect.Enabled = false
		effect.FarIntensity = 0
		effect.NearIntensity = 0
		effect.InFocusRadius = 100000
	end
end

local function guardPostEffect(ctx, effect)
	if not effect or guardedPostEffects[effect] then
		return
	end
	if not effect:IsA("BlurEffect") and not effect:IsA("DepthOfFieldEffect") then
		return
	end

	guardedPostEffects[effect] = true
	disablePostEffect(effect)

	local function forceOffAgain()
		if ctx.minigameRunning and effect.Parent then
			disablePostEffect(effect)
		end
	end

	table.insert(noBlurConnections, effect:GetPropertyChangedSignal("Enabled"):Connect(forceOffAgain))

	if effect:IsA("BlurEffect") then
		table.insert(noBlurConnections, effect:GetPropertyChangedSignal("Size"):Connect(forceOffAgain))
	else
		table.insert(noBlurConnections, effect:GetPropertyChangedSignal("FarIntensity"):Connect(forceOffAgain))
		table.insert(noBlurConnections, effect:GetPropertyChangedSignal("NearIntensity"):Connect(forceOffAgain))
		table.insert(noBlurConnections, effect:GetPropertyChangedSignal("InFocusRadius"):Connect(forceOffAgain))
	end
end

local function guardPostEffectsUnder(ctx, parent)
	if not parent then
		return
	end

	guardPostEffect(ctx, parent)
	for _, descendant in ipairs(parent:GetDescendants()) do
		guardPostEffect(ctx, descendant)
	end
end

local function forceFishingBlurOff(ctx)
	local directBlur = ctx and ctx.fishingBlur
	if directBlur then
		guardPostEffect(ctx, directBlur)
		disablePostEffect(directBlur)
	end

	guardPostEffectsUnder(ctx, Lighting)

	local camera = workspace.CurrentCamera
	if camera then
		guardPostEffectsUnder(ctx, camera)
	end
end

local function bindNoBlur(ctx)
	local runService = ctx.RunService
	runService:UnbindFromRenderStep(NO_BLUR_RENDER_STEP)
	disconnectNoBlurConnections()

	-- Turn off existing effects immediately, before the minigame panel appears.
	forceFishingBlurOff(ctx)

	-- Catch BlurEffect/DepthOfFieldEffect instances created during the minigame.
	table.insert(noBlurConnections, Lighting.DescendantAdded:Connect(function(descendant)
		if ctx.minigameRunning then
			guardPostEffect(ctx, descendant)
		end
	end))

	table.insert(noBlurConnections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if ctx.minigameRunning then
			forceFishingBlurOff(ctx)
		end
	end))

	-- Run after the normal camera update. Property guards above also undo any
	-- later attempt to re-enable blur in the same frame.
	runService:BindToRenderStep(NO_BLUR_RENDER_STEP, 10000, function()
		if ctx.minigameRunning then
			forceFishingBlurOff(ctx)
		end
	end)

	-- PreRender is the last client-side render stage on current Roblox builds.
	-- Keeping this extra guard makes the result reliable against other UI scripts.
	if runService.PreRender then
		table.insert(noBlurConnections, runService.PreRender:Connect(function()
			if ctx.minigameRunning then
				forceFishingBlurOff(ctx)
			end
		end))
	end
end

local function unbindNoBlur(ctx)
	ctx.RunService:UnbindFromRenderStep(NO_BLUR_RENDER_STEP)
	disconnectNoBlurConnections()

	-- Leave the fishing blur itself off after the minigame closes. Other systems
	-- can still enable their own post effects later if they need them.
	local directBlur = ctx and ctx.fishingBlur
	if directBlur then
		disablePostEffect(directBlur)
	end
end

-- The live fishing flow uses RarityCatchController directly, so MinigameController.run
-- is not always called. This independent guard follows the actual modern panel/Rage
-- presentation and keeps every BlurEffect/DepthOfFieldEffect off for the whole catch.
local HARD_NO_BLUR_RENDER_STEP = "FishyFish_ModernFishing_HardNoBlur"

local function createHardNoBlurGuard()
	local active = false
	local connections = {}
	local watchedEffects = setmetatable({}, { __mode = "k" })

	local function disconnectConnections()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
		table.clear(watchedEffects)
	end

	local function forceEffectOff(effect)
		if not active or not effect or not effect.Parent then
			return
		end

		if effect:IsA("BlurEffect") then
			if effect.Enabled then
				effect.Enabled = false
			end
			if effect.Size ~= 0 then
				effect.Size = 0
			end
		elseif effect:IsA("DepthOfFieldEffect") then
			if effect.Enabled then
				effect.Enabled = false
			end
			if effect.FarIntensity ~= 0 then
				effect.FarIntensity = 0
			end
			if effect.NearIntensity ~= 0 then
				effect.NearIntensity = 0
			end
			if effect.InFocusRadius < 100000 then
				effect.InFocusRadius = 100000
			end
		end
	end

	local function watchEffect(effect)
		if not effect or watchedEffects[effect] then
			return
		end
		if not effect:IsA("BlurEffect") and not effect:IsA("DepthOfFieldEffect") then
			return
		end

		watchedEffects[effect] = true
		forceEffectOff(effect)

		table.insert(connections, effect:GetPropertyChangedSignal("Enabled"):Connect(function()
			forceEffectOff(effect)
		end))

		if effect:IsA("BlurEffect") then
			table.insert(connections, effect:GetPropertyChangedSignal("Size"):Connect(function()
				forceEffectOff(effect)
			end))
		else
			for _, propertyName in ipairs({
				"FarIntensity",
				"NearIntensity",
				"InFocusRadius",
				}) do
				table.insert(connections, effect:GetPropertyChangedSignal(propertyName):Connect(function()
					forceEffectOff(effect)
				end))
			end
		end
	end

	local function scanParent(parent)
		if not parent then
			return
		end

		watchEffect(parent)
		for _, descendant in ipairs(parent:GetDescendants()) do
			watchEffect(descendant)
		end
	end

	local function scanAll()
		scanParent(Lighting)
		scanParent(workspace.CurrentCamera)
	end

	local function setActive(shouldBeActive)
		shouldBeActive = shouldBeActive == true
		if active == shouldBeActive then
			if active then
				scanAll()
			end
			return
		end

		active = shouldBeActive
		RunService:UnbindFromRenderStep(HARD_NO_BLUR_RENDER_STEP)
		disconnectConnections()

		if not active then
			return
		end

		scanAll()

		table.insert(connections, Lighting.DescendantAdded:Connect(function(descendant)
			watchEffect(descendant)
		end))

		table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			if active then
				scanAll()
			end
		end))

		RunService:BindToRenderStep(HARD_NO_BLUR_RENDER_STEP, 10000, function()
			if active then
				scanAll()
			end
		end)

		if RunService.PreRender then
			table.insert(connections, RunService.PreRender:Connect(function()
				if active then
					scanAll()
				end
			end))
		end
	end

	local function destroy()
		active = false
		RunService:UnbindFromRenderStep(HARD_NO_BLUR_RENDER_STEP)
		disconnectConnections()
	end

	return setActive, destroy
end

local function makeText(parent, name, text, position, size, maxTextSize, color, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = text or ""
	label.TextColor3 = color or WHITE
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.10
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextWrapped = true
	label.ZIndex = zIndex or 1
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 9
	constraint.MaxTextSize = maxTextSize or 28
	constraint.Parent = label

	return label
end

local function makeRichText(parent, name, text, position, size, maxTextSize, zIndex)
	local label = makeText(parent, name, text, position, size, maxTextSize, WHITE, zIndex)
	label.RichText = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	return label
end

local function getDeviceKind(viewport)
	local width = viewport.X
	local height = viewport.Y
	local shortest = math.min(width, height)
	local longest = math.max(width, height)
	local aspect = longest / math.max(shortest, 1)

	local isTouch = UserInputService.TouchEnabled

	if isTouch and (shortest <= 520 or aspect >= 1.75) then
		return "phone"
	end

	if isTouch or shortest <= 900 then
		return "tablet"
	end

	return "desktop"
end

local function getSizingForDevice(deviceKind)
	if deviceKind == "phone" then
		return PHONE_WIDTH_LIMIT, PHONE_HEIGHT_LIMIT
	elseif deviceKind == "tablet" then
		return TABLET_WIDTH_LIMIT, TABLET_HEIGHT_LIMIT
	else
		return DESKTOP_WIDTH_LIMIT, DESKTOP_HEIGHT_LIMIT
	end
end

local function attachResponsivePanelLayout(panel)
	local function updateLayout()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)

		local screenWidth = math.max(viewport.X, 1)
		local screenHeight = math.max(viewport.Y, 1)
		local deviceKind = getDeviceKind(viewport)
		local widthLimit, heightLimit = getSizingForDevice(deviceKind)

		local maxWidth = screenWidth * widthLimit
		local maxHeight = screenHeight * heightLimit

		local finalHeight = math.min(maxHeight, maxWidth / PANEL_ASPECT)
		local finalWidth = finalHeight * PANEL_ASPECT

		-- 위에서 설정한 전체 배율 적용
		finalWidth *= UI_SCALE
		finalHeight *= UI_SCALE

		-- 배율을 크게 올려도 화면 바깥으로 완전히 벗어나지 않도록 보호
		local safeWidth = screenWidth * 0.96
		local safeHeight = screenHeight * 0.96
		local fitScale = math.min(
			1,
			safeWidth / math.max(finalWidth, 1),
			safeHeight / math.max(finalHeight, 1)
		)

		finalWidth *= fitScale
		finalHeight *= fitScale

		panel.Size = UDim2.fromOffset(
			math.floor(finalWidth + 0.5),
			math.floor(finalHeight + 0.5)
		)

		-- 위에서 설정한 전체 위치 적용
		panel.Position = UDim2.fromScale(
			UI_POSITION_X,
			UI_POSITION_Y
		)
	end

	updateLayout()

	task.defer(function()
		updateLayout()

		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
		end
	end)

	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		task.defer(updateLayout)
	end)
end

local function setFishingBarsVisible(ctx, visible)
	local ui = ctx.ui
	local root = ui and ui.root

	if ui and ui.centerControls then
		ui.centerControls.Visible = visible
	end

	if root then
		local names = {
			LayeredFishingBar = true,
			FishingBar = true,
			FishingCenterControls = true,
			CenterControls = true,
			CenterActionBar = true,
		}

		for _, obj in ipairs(root:GetDescendants()) do
			if names[obj.Name] and obj:IsA("GuiObject") then
				obj.Visible = visible
			end
		end
	end
end

local function getFishImage(ctx, fish)
	if not fish then
		return ""
	end

	if fish.image then
		return fish.image
	end
	if fish.imageId then
		return fish.imageId
	end
	if fish.icon then
		return fish.icon
	end

	local fishId = fish.imageKey or fish.id or fish.fishId
	if not fishId then
		return ""
	end

	local ok, image = pcall(function()
		return ctx.GameConfig.getFishImage(fishId)
	end)

	if ok and image then
		return image
	end

	return ""
end

local ROD_GREEN_STYLES = {
	WoodenRod = {
		image = ASSETS.GreenWoodenIron,
		barSize = 0.232,
	},
	IronRod = {
		image = ASSETS.GreenWoodenIron,
		barSize = 0.232,
	},
	GoldenRod = {
		image = ASSETS.GreenGoldenEmerald,
		barSize = 0.261,
	},
	EmeraldRod = {
		image = ASSETS.GreenGoldenEmerald,
		barSize = 0.261,
	},
	OceanRod = {
		image = ASSETS.GreenOcean,
		barSize = 0.290,
	},
}

local function normalizeRodName(value)
	if type(value) == "table" then
		value = value.id
			or value.rodId
			or value.name
			or value.displayName
	end

	local normalized = string.lower(tostring(value or "WoodenRod"))
	normalized = normalized:gsub("[^%w]", "")

	if normalized:find("ocean", 1, true) then
		return "OceanRod"
	elseif normalized:find("emerald", 1, true) then
		return "EmeraldRod"
	elseif normalized:find("gold", 1, true) then
		return "GoldenRod"
	elseif normalized:find("iron", 1, true) then
		return "IronRod"
	end

	return "WoodenRod"
end

local function getRodGreenStyle(prompt, state)
	local rodValue = prompt and (
		prompt.rod
			or prompt.rodId
			or prompt.equippedRod
	)

	if rodValue == nil and state then
		rodValue = state.EquippedRod
	end

	local rodName = normalizeRodName(rodValue)
	return ROD_GREEN_STYLES[rodName], rodName
end

local function ensureUi(ctx)
	local ui = ctx.ui
	local root = ui.root

	local existing = ui.customFishingMinigame
	if type(existing) == "table"
		and existing.version == UI_VERSION
		and existing.panel
		and existing.panel.Parent
	then
		return existing
	end

	if type(existing) == "table" and existing.panel and existing.panel.Parent then
		existing.panel:Destroy()
	elseif typeof(existing) == "Instance" and existing.Parent then
		existing:Destroy()
	end
	ui.customFishingMinigame = nil

	local panel = Instance.new("Frame")
	panel.Name = "CustomFishingMinigameRodAssets"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 120
	panel.Parent = root

	attachResponsivePanelLayout(panel)

	local ragePresentationActive = false
	local setHardNoBlurActive, destroyHardNoBlurGuard = createHardNoBlurGuard()

	local function refreshHardNoBlur()
		setHardNoBlurActive(panel.Visible or ragePresentationActive)
	end

	panel:GetPropertyChangedSignal("Visible"):Connect(refreshHardNoBlur)
	panel.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			destroyHardNoBlurGuard()
		end
	end)

	local headerText = makeText(
		panel,
		"HeaderText",
		"Waiting for a bite...",
		UDim2.fromScale(0.5, 0.055),
		UDim2.fromScale(0.98, 0.065),
		30,
		WHITE,
		150
	)
	headerText.TextWrapped = false
	headerText.TextXAlignment = Enum.TextXAlignment.Center
	headerText.TextYAlignment = Enum.TextYAlignment.Center
	headerText.TextStrokeColor3 = Color3.fromRGB(16, 72, 190)
	headerText.TextStrokeTransparency = 0.45
	-- Replaced by FishingClient's black top banner.
	headerText.Visible = false

	-- Main movement panel. The aspect ratio is locked to the supplied
	-- 850x1514 PNG, so it cannot become squashed.
	local waterPanel = makeImage(
		panel,
		"WaterPanel",
		ASSETS.MainPanel,
		UDim2.fromScale(0.405, 0.56),
		UDim2.fromScale(0.61, 0.82),
		130
	)
	waterPanel.ScaleType = Enum.ScaleType.Fit
	waterPanel.ClipsDescendants = true

	local waterPanelAspect = Instance.new("UIAspectRatioConstraint")
	waterPanelAspect.AspectRatio = 850 / 1514
	waterPanelAspect.DominantAxis = Enum.DominantAxis.Height
	waterPanelAspect.Parent = waterPanel

	local waterInner = Instance.new("Frame")
	waterInner.Name = "WaterInnerMovementArea"
	waterInner.AnchorPoint = Vector2.new(0.5, 0.5)
	waterInner.Position = UDim2.fromScale(0.5, 0.505)
	waterInner.Size = UDim2.fromScale(0.88, 0.84)
	waterInner.BackgroundTransparency = 1
	waterInner.BorderSizePixel = 0
	waterInner.ClipsDescendants = true
	waterInner.ZIndex = 132
	waterInner.Parent = waterPanel

	-- Green bar. The image and height are swapped at runtime according
	-- to the equipped rod.
	local catchBar = makeImage(
		waterInner,
		"CatchBar",
		ASSETS.GreenWoodenIron,
		UDim2.fromScale(0.5, 0.70),
		UDim2.fromScale(0.94, ROD_GREEN_STYLES.WoodenRod.barSize),
		138
	)
	catchBar.AnchorPoint = Vector2.new(0.5, 0)
	catchBar.ScaleType = Enum.ScaleType.Stretch

	-- Fish-background image. The source file has an opaque square
	-- background, so a circular UICorner clips it into the intended dish.
	local fishMarker = makeImage(
		waterInner,
		"FishMarkerCircle",
		ASSETS.FishBackground,
		UDim2.fromScale(0.5, 0.34),
		UDim2.fromScale(0.31, 0.19),
		142
	)
	fishMarker.ScaleType = Enum.ScaleType.Stretch
	fishMarker.ClipsDescendants = true
	addCorner(fishMarker, 1, 0)

	local fishMarkerAspect = Instance.new("UIAspectRatioConstraint")
	fishMarkerAspect.AspectRatio = 1
	fishMarkerAspect.DominantAxis = Enum.DominantAxis.Height
	fishMarkerAspect.Parent = fishMarker

	local fishImage = Instance.new("ImageLabel")
	fishImage.Name = "FishImage"
	fishImage.AnchorPoint = Vector2.new(0.5, 0.5)
	fishImage.Position = UDim2.fromScale(0.5, 0.5)
	fishImage.Size = UDim2.fromScale(0.80, 0.80)
	fishImage.BackgroundTransparency = 1
	fishImage.BorderSizePixel = 0
	fishImage.ScaleType = Enum.ScaleType.Fit
	fishImage.ZIndex = 145
	fishImage.Parent = fishMarker

	-- Right progress track. Its aspect is locked to the supplied
	-- 287x2048 PNG, and its visible height matches the main panel.
	local progressTrack = makeImage(
		panel,
		"ProgressTrack",
		ASSETS.SliderTrack,
		UDim2.fromScale(0.805, 0.56),
		UDim2.fromScale(0.15, 0.82),
		130
	)
	progressTrack.ScaleType = Enum.ScaleType.Fit
	progressTrack.ClipsDescendants = true

	local progressTrackAspect = Instance.new("UIAspectRatioConstraint")
	progressTrackAspect.AspectRatio = 287 / 2048
	progressTrackAspect.DominantAxis = Enum.DominantAxis.Height
	progressTrackAspect.Parent = progressTrack

	local progressInner = Instance.new("Frame")
	progressInner.Name = "ProgressInner"
	progressInner.AnchorPoint = Vector2.new(0.5, 0.5)
	progressInner.Position = UDim2.fromScale(0.5, 0.5)
	progressInner.Size = UDim2.fromScale(0.72, 0.94)
	progressInner.BackgroundTransparency = 1
	progressInner.BorderSizePixel = 0
	progressInner.ClipsDescendants = true
	progressInner.ZIndex = 134
	progressInner.Parent = progressTrack

	-- Three-piece Blue Gauge fill.
	-- This uses the same supplied asset ID; no new image upload is required.
	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.AnchorPoint = Vector2.new(0.5, 1)
	progressFill.Position = UDim2.fromScale(0.5, 1)
	progressFill.Size = UDim2.fromScale(0.92, 0.12)
	progressFill.BackgroundTransparency = 1
	progressFill.BorderSizePixel = 0
	progressFill.ClipsDescendants = true
	progressFill.ZIndex = 136
	progressFill.Parent = progressInner

	local function makeGaugePiece(name, rectOffset, rectSize)
		local piece = Instance.new("ImageLabel")
		piece.Name = name
		piece.AnchorPoint = Vector2.new(0, 0)
		piece.BackgroundTransparency = 1
		piece.BorderSizePixel = 0
		piece.Image = ASSETS.BlueGauge
		piece.ImageRectOffset = rectOffset
		piece.ImageRectSize = rectSize
		piece.ScaleType = Enum.ScaleType.Stretch
		piece.ZIndex = 136
		piece.Parent = progressFill
		return piece
	end

	local topCap = makeGaugePiece(
		"TopCap",
		Vector2.new(0, 0),
		Vector2.new(
			BLUE_GAUGE_WIDTH,
			BLUE_GAUGE_CAP_HEIGHT + GAUGE_SOURCE_OVERLAP
		)
	)

	local middle = makeGaugePiece(
		"Middle",
		Vector2.new(0, BLUE_GAUGE_CAP_HEIGHT - GAUGE_SOURCE_OVERLAP),
		Vector2.new(
			BLUE_GAUGE_WIDTH,
			BLUE_GAUGE_HEIGHT
			- (BLUE_GAUGE_CAP_HEIGHT * 2)
				+ (GAUGE_SOURCE_OVERLAP * 2)
		)
	)

	local bottomCap = makeGaugePiece(
		"BottomCap",
		Vector2.new(
			0,
			BLUE_GAUGE_HEIGHT
			- BLUE_GAUGE_CAP_HEIGHT
			- GAUGE_SOURCE_OVERLAP
		),
		Vector2.new(
			BLUE_GAUGE_WIDTH,
			BLUE_GAUGE_CAP_HEIGHT + GAUGE_SOURCE_OVERLAP
		)
	)

	-- FishingClient runs RarityCatchController, which updates progressFill.Size
	-- directly. The module's run() function is not the code driving the live
	-- minigame, so the three image pieces must automatically relayout whenever
	-- the external controller changes the fill size.
	local gaugeLayoutBusy = false

	local function layoutGaugePieces()
		if gaugeLayoutBusy or not progressFill.Parent then
			return
		end

		gaugeLayoutBusy = true

		local fillWidth = math.max(progressFill.AbsoluteSize.X, 1)
		local fillHeight = math.max(progressFill.AbsoluteSize.Y, 0)

		if fillHeight <= 1 then
			topCap.Visible = false
			middle.Visible = false
			bottomCap.Visible = false
			gaugeLayoutBusy = false
			return
		end

		topCap.Visible = true
		middle.Visible = true
		bottomCap.Visible = true

		local naturalCapHeight = fillWidth
			* (BLUE_GAUGE_CAP_HEIGHT / BLUE_GAUGE_WIDTH)
		local capHeight = math.min(naturalCapHeight, fillHeight * 0.5)
		local middleHeight = math.max(0, fillHeight - (capHeight * 2))
		local seamOverlap = math.min(
			GAUGE_SEAM_OVERLAP_PIXELS,
			capHeight * 0.22,
			fillHeight * 0.08
		)

		-- Overlap neighboring slices slightly. This hides texture sampling seams
		-- without changing the original rounded cap shape.
		topCap.Position = UDim2.fromOffset(0, 0)
		topCap.Size = UDim2.new(1, 0, 0, capHeight + seamOverlap)

		middle.Position = UDim2.fromOffset(0, capHeight - seamOverlap)
		middle.Size = UDim2.new(
			1,
			0,
			0,
			middleHeight + (seamOverlap * 2)
		)

		bottomCap.Position = UDim2.fromOffset(
			0,
			fillHeight - capHeight - seamOverlap
		)
		bottomCap.Size = UDim2.new(
			1,
			0,
			0,
			capHeight + seamOverlap
		)

		gaugeLayoutBusy = false
	end

	local geometryCorrectionBusy = false

	local function correctGaugeGeometry()
		if geometryCorrectionBusy or not progressFill.Parent then
			return
		end

		geometryCorrectionBusy = true

		-- RarityCatchController still writes values intended for the old
		-- progress image, including Position Y = 0.89. Force this new fill
		-- to stay anchored to the exact bottom of ProgressInner.
		progressFill.AnchorPoint = Vector2.new(0.5, 1)
		progressFill.Position = UDim2.fromScale(0.5, 1)

		local currentSize = progressFill.Size
		local progressHeight = currentSize.Y.Scale

		-- Convert an unexpected pixel offset into a scale before clamping.
		if currentSize.Y.Offset ~= 0 then
			local innerHeight = math.max(progressInner.AbsoluteSize.Y, 1)
			progressHeight += currentSize.Y.Offset / innerHeight
		end

		progressHeight = math.clamp(progressHeight, 0, 1)

		-- Keep the supplied gauge width stable. At progress 1 the height is
		-- exactly the full ProgressInner height, so it touches the top edge
		-- and cannot continue beyond it.
		progressFill.Size = UDim2.fromScale(0.92, progressHeight)

		geometryCorrectionBusy = false
		task.defer(layoutGaugePieces)
	end

	progressFill:GetPropertyChangedSignal("Size"):Connect(
		correctGaugeGeometry
	)
	progressFill:GetPropertyChangedSignal("Position"):Connect(
		correctGaugeGeometry
	)
	progressFill:GetPropertyChangedSignal("AnchorPoint"):Connect(
		correctGaugeGeometry
	)
	progressFill:GetPropertyChangedSignal("AbsoluteSize"):Connect(
		layoutGaugePieces
	)
	progressInner:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		correctGaugeGeometry()
		layoutGaugePieces()
	end)

	task.defer(correctGaugeGeometry)
	task.defer(layoutGaugePieces)

	-- Rage Mode warning and gauge focus animation.
	local rageWarning = makeImage(
		root,
		"RageModeWarning",
		ASSETS.RageWarning,
		UDim2.fromScale(0.5, 0.14),
		UDim2.fromScale(1, 0.3),
		520
	)
	rageWarning.Visible = false
	rageWarning.ImageTransparency = 1
	rageWarning.ScaleType = Enum.ScaleType.Fit

	local warningScale = Instance.new("UIScale")
	warningScale.Name = "WarningPulseScale"
	warningScale.Scale = 1
	warningScale.Parent = rageWarning

	local gaugeFocusScale = Instance.new("UIScale")
	gaugeFocusScale.Name = "RageGaugeFocusScale"
	gaugeFocusScale.Scale = 1
	gaugeFocusScale.Parent = progressTrack

	-- The focused gauge is visually horizontal after ProgressTrack rotates 90°.
	-- A separate, unrotated fill is used during Rage Mode so its left edge stays
	-- fixed and only the right edge advances as the player taps.
	local RAGE_FOCUS_SCALE = 1.28
	-- Focused horizontal gauge target: directly below the three top buttons.
	-- X: smaller = left, larger = right
	-- Y: smaller = higher, larger = lower
	local RAGE_FOCUS_POSITION_X = 0.5
	local RAGE_FOCUS_POSITION_Y = 0.16
	local RAGE_INNER_LENGTH_SCALE = 0.94
	local RAGE_INNER_THICKNESS_SCALE = 0.72

	local rageHorizontalFill = Instance.new("Frame")
	rageHorizontalFill.Name = "RageHorizontalFill"
	rageHorizontalFill.AnchorPoint = Vector2.new(0, 0.5)
	rageHorizontalFill.Position = UDim2.fromOffset(0, 0)
	rageHorizontalFill.Size = UDim2.fromOffset(0, 1)
	rageHorizontalFill.BackgroundTransparency = 1
	rageHorizontalFill.BorderSizePixel = 0
	rageHorizontalFill.ClipsDescendants = false
	rageHorizontalFill.Visible = false
	rageHorizontalFill.ZIndex = 490
	rageHorizontalFill.Parent = root

	-- Restored the original three-piece gauge renderer.
	-- This keeps the supplied gauge artwork's normal rounded shape instead of
	-- distorting it with 9-slice stretching.
	local function makeRageHorizontalPiece(name, rectOffset, rectSize)
		local holder = Instance.new("Frame")
		holder.Name = name .. "Holder"
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.ClipsDescendants = true
		holder.ZIndex = 490
		holder.Parent = rageHorizontalFill

		local image = Instance.new("ImageLabel")
		image.Name = name
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.Image = ASSETS.BlueGauge
		image.ImageRectOffset = rectOffset
		image.ImageRectSize = rectSize
		image.ScaleType = Enum.ScaleType.Stretch
		image.Rotation = 90
		image.ZIndex = 491
		image.Parent = holder

		return {
			holder = holder,
			image = image,
		}
	end

	-- After a clockwise 90° rotation, the source bottom cap becomes the fixed
	-- left cap and the source top cap becomes the moving right cap.
	local rageLeftCap = makeRageHorizontalPiece(
		"LeftCap",
		Vector2.new(
			0,
			BLUE_GAUGE_HEIGHT
			- BLUE_GAUGE_CAP_HEIGHT
			- GAUGE_SOURCE_OVERLAP
		),
		Vector2.new(
			BLUE_GAUGE_WIDTH,
			BLUE_GAUGE_CAP_HEIGHT + GAUGE_SOURCE_OVERLAP
		)
	)
	local rageMiddle = makeRageHorizontalPiece(
		"Middle",
		Vector2.new(0, BLUE_GAUGE_CAP_HEIGHT - GAUGE_SOURCE_OVERLAP),
		Vector2.new(
			BLUE_GAUGE_WIDTH,
			BLUE_GAUGE_HEIGHT
			- (BLUE_GAUGE_CAP_HEIGHT * 2)
				+ (GAUGE_SOURCE_OVERLAP * 2)
		)
	)
	local rageRightCap = makeRageHorizontalPiece(
		"RightCap",
		Vector2.new(0, 0),
		Vector2.new(
			BLUE_GAUGE_WIDTH,
			BLUE_GAUGE_CAP_HEIGHT + GAUGE_SOURCE_OVERLAP
		)
	)

	local rageHorizontalFullWidth = 0
	local rageHorizontalFullHeight = 0
	local rageHorizontalLeft = 0
	local rageHorizontalCenterY = 0
	local lastProgressAmount = 0
	local gaugeFocused = false

	local function setRagePieceGeometry(piece, x, width, height)
		piece.holder.Position = UDim2.fromOffset(x, 0)
		piece.holder.Size = UDim2.fromOffset(width, height)

		-- The image is rotated 90°, so its unrotated dimensions are swapped.
		piece.image.Size = UDim2.fromOffset(height, width)
	end

	local function layoutRageHorizontalPieces(fillWidth, fillHeight)
		fillWidth = math.max(tonumber(fillWidth) or 0, 0)
		fillHeight = math.max(tonumber(fillHeight) or 0, 0)

		if fillWidth <= 1 or fillHeight <= 1 then
			rageLeftCap.holder.Visible = false
			rageMiddle.holder.Visible = false
			rageRightCap.holder.Visible = false
			return
		end

		rageLeftCap.holder.Visible = true
		rageMiddle.holder.Visible = true
		rageRightCap.holder.Visible = true

		local naturalCapWidth = fillHeight
			* (BLUE_GAUGE_CAP_HEIGHT / BLUE_GAUGE_WIDTH)
		local capWidth = math.min(naturalCapWidth, fillWidth * 0.5)
		local middleWidth = math.max(0, fillWidth - (capWidth * 2))
		local seamOverlap = math.min(
			GAUGE_SEAM_OVERLAP_PIXELS,
			capWidth * 0.22,
			fillWidth * 0.04
		)

		-- The holders overlap by a few pixels and their source rectangles also
		-- overlap. This removes the black vertical slice line while preserving
		-- the supplied rounded left/right ends.
		setRagePieceGeometry(
			rageLeftCap,
			0,
			math.min(fillWidth, capWidth + seamOverlap),
			fillHeight
		)
		setRagePieceGeometry(
			rageMiddle,
			math.max(0, capWidth - seamOverlap),
			math.max(0, middleWidth + (seamOverlap * 2)),
			fillHeight
		)
		setRagePieceGeometry(
			rageRightCap,
			math.max(0, fillWidth - capWidth - seamOverlap),
			math.min(fillWidth, capWidth + seamOverlap),
			fillHeight
		)
	end

	local function updateRageHorizontalFill(amount)
		lastProgressAmount = math.clamp(tonumber(amount) or 0, 0, 1)

		local fillWidth = rageHorizontalFullWidth * lastProgressAmount
		rageHorizontalFill.Position = UDim2.fromOffset(
			rageHorizontalLeft,
			rageHorizontalCenterY
		)
		rageHorizontalFill.Size = UDim2.fromOffset(
			fillWidth,
			math.max(1, rageHorizontalFullHeight)
		)
		rageHorizontalFill.Visible = gaugeFocused and fillWidth > 1
		layoutRageHorizontalPieces(fillWidth, rageHorizontalFullHeight)
	end

	local function configureRageHorizontalFill(baseTrackSize, centerX, centerY)
		rageHorizontalFullWidth = math.max(
			1,
			baseTrackSize.Y * RAGE_INNER_LENGTH_SCALE * RAGE_FOCUS_SCALE
		)
		rageHorizontalFullHeight = math.max(
			1,
			baseTrackSize.X * RAGE_INNER_THICKNESS_SCALE * RAGE_FOCUS_SCALE
		)
		rageHorizontalLeft = centerX - (rageHorizontalFullWidth * 0.5)
		rageHorizontalCenterY = centerY
		updateRageHorizontalFill(lastProgressAmount)
	end

	local gaugeHome = {
		parent = progressTrack.Parent,
		anchorPoint = progressTrack.AnchorPoint,
		position = progressTrack.Position,
		size = progressTrack.Size,
		rotation = progressTrack.Rotation,
		zIndex = progressTrack.ZIndex,
	}
	local currentGaugeAsset = ASSETS.BlueGauge
	local savedVisibility = nil
	local warningTween = nil
	local gaugeMoveTween = nil
	local gaugeScaleTween = nil

	local function cancelTween(tween)
		if tween then
			tween:Cancel()
		end
	end

	local function setDisplayedProgress(amount)
		lastProgressAmount = math.clamp(tonumber(amount) or 0, 0, 1)

		if gaugeFocused then
			progressFill.Visible = false
			updateRageHorizontalFill(lastProgressAmount)
		else
			rageHorizontalFill.Visible = false
			progressFill.Visible = true
			setProgressFillAmount(progressFill, lastProgressAmount)
			task.defer(layoutGaugePieces)
		end
	end

	local function setGaugeAsset(assetId)
		assetId = assetId or ASSETS.BlueGauge
		if currentGaugeAsset == assetId then
			return
		end

		currentGaugeAsset = assetId
		topCap.Image = assetId
		middle.Image = assetId
		bottomCap.Image = assetId
		rageLeftCap.image.Image = assetId
		rageMiddle.image.Image = assetId
		rageRightCap.image.Image = assetId
	end

	local function setFishSilhouette(enabled)
		fishImage.ImageColor3 = enabled
			and Color3.fromRGB(0, 0, 0)
			or Color3.fromRGB(255, 255, 255)
	end

	local function beginRagePresentation()
		if ragePresentationActive then
			setHardNoBlurActive(true)
			return
		end

		ragePresentationActive = true
		setHardNoBlurActive(true)
		savedVisibility = {
			panel = panel.Visible,
			headerText = headerText.Visible,
			waterPanel = waterPanel.Visible,
			progressTrack = progressTrack.Visible,
		}

		panel.Visible = true
		headerText.Visible = false
		waterPanel.Visible = false
		progressTrack.Visible = true
	end

	local function hideRageWarning()
		cancelTween(warningTween)
		warningTween = nil
		rageWarning.Visible = false
		rageWarning.ImageTransparency = 1
		warningScale.Scale = 1
	end

	local function showRageWarning(duration, shouldContinue)
		duration = math.max(0, tonumber(duration) or 3)
		rageWarning.Visible = true
		rageWarning.ImageTransparency = 1
		warningScale.Scale = 0.96

		local endTime = os.clock() + duration
		local showing = false

		while os.clock() < endTime do
			if shouldContinue and not shouldContinue() then
				hideRageWarning()
				return false
			end

			showing = not showing
			cancelTween(warningTween)
			warningTween = TweenService:Create(
				rageWarning,
				TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ ImageTransparency = showing and 0 or 1 }
			)
			local pulseTween = TweenService:Create(
				warningScale,
				TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = showing and 1.035 or 0.97 }
			)
			warningTween:Play()
			pulseTween:Play()
			task.wait(0.24)
		end

		hideRageWarning()
		return true
	end

	local function focusGauge(shouldContinue)
		if gaugeFocused then
			return true
		end
		if shouldContinue and not shouldContinue() then
			return false
		end

		local rootAbsolutePosition = root.AbsolutePosition
		local rootAbsoluteSize = root.AbsoluteSize
		local currentAbsolutePosition = progressTrack.AbsolutePosition
		local currentAbsoluteSize = progressTrack.AbsoluteSize

		progressTrack.Parent = root
		progressTrack.AnchorPoint = Vector2.new(0.5, 0.5)
		progressTrack.Size = UDim2.fromOffset(
			math.max(1, currentAbsoluteSize.X),
			math.max(1, currentAbsoluteSize.Y)
		)
		progressTrack.Position = UDim2.fromOffset(
			currentAbsolutePosition.X - rootAbsolutePosition.X + (currentAbsoluteSize.X * 0.5),
			currentAbsolutePosition.Y - rootAbsolutePosition.Y + (currentAbsoluteSize.Y * 0.5)
		)
		progressTrack.ZIndex = 480
		progressTrack.Visible = true
		progressTrack.Rotation = gaugeHome.rotation
		panel.Visible = false
		gaugeFocusScale.Scale = 1

		-- Move, enlarge, and rotate the complete gauge at the same time.
		-- Positive Rotation values turn clockwise in Roblox UI.
		local focusTweenInfo = TweenInfo.new(
			0.72,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		)

		cancelTween(gaugeMoveTween)
		cancelTween(gaugeScaleTween)
		gaugeMoveTween = TweenService:Create(
			progressTrack,
			focusTweenInfo,
			{
				Position = UDim2.fromOffset(
					rootAbsoluteSize.X * RAGE_FOCUS_POSITION_X,
					rootAbsoluteSize.Y * RAGE_FOCUS_POSITION_Y
				),
				Rotation = gaugeHome.rotation + 90,
			}
		)
		gaugeScaleTween = TweenService:Create(
			gaugeFocusScale,
			focusTweenInfo,
			{ Scale = RAGE_FOCUS_SCALE }
		)
		gaugeMoveTween:Play()
		gaugeScaleTween:Play()
		gaugeMoveTween.Completed:Wait()

		if shouldContinue and not shouldContinue() then
			return false
		end

		gaugeFocused = true
		progressFill.Visible = false
		configureRageHorizontalFill(
			currentAbsoluteSize,
			rootAbsoluteSize.X * RAGE_FOCUS_POSITION_X,
			rootAbsoluteSize.Y * RAGE_FOCUS_POSITION_Y
		)
		return true
	end

	local function restoreRagePresentation()
		hideRageWarning()
		cancelTween(gaugeMoveTween)
		cancelTween(gaugeScaleTween)
		gaugeMoveTween = nil
		gaugeScaleTween = nil

		-- Hide first, then reset instantly while invisible.
		-- There is intentionally no reverse movement or reverse rotation tween.
		progressTrack.Visible = false
		rageHorizontalFill.Visible = false
		progressFill.Visible = true

		if progressTrack.Parent ~= gaugeHome.parent then
			progressTrack.Parent = gaugeHome.parent
		end
		progressTrack.AnchorPoint = gaugeHome.anchorPoint
		progressTrack.Position = gaugeHome.position
		progressTrack.Size = gaugeHome.size
		progressTrack.Rotation = gaugeHome.rotation
		progressTrack.ZIndex = gaugeHome.zIndex
		gaugeFocusScale.Scale = 1
		gaugeFocused = false
		rageHorizontalFullWidth = 0
		rageHorizontalFullHeight = 0
		rageHorizontalLeft = 0
		rageHorizontalCenterY = 0

		if savedVisibility then
			panel.Visible = savedVisibility.panel
			waterPanel.Visible = savedVisibility.waterPanel
			progressTrack.Visible = savedVisibility.progressTrack
		else
			waterPanel.Visible = true
			progressTrack.Visible = true
		end
		headerText.Visible = false

		ragePresentationActive = false
		savedVisibility = nil
		refreshHardNoBlur()
		setFishSilhouette(false)
		setGaugeAsset(ASSETS.BlueGauge)
		task.defer(correctGaugeGeometry)
		task.defer(layoutGaugePieces)
	end

	-- Compatibility placeholders used by the existing run logic.
	local statusText = Instance.new("TextLabel")
	statusText.Name = "StatusText"
	statusText.Visible = false
	statusText.Parent = panel

	local progressText = Instance.new("TextLabel")
	progressText.Name = "ProgressText"
	progressText.Visible = false
	progressText.Parent = panel

	local baitText = Instance.new("TextLabel")
	baitText.Name = "BaitText"
	baitText.Visible = false
	baitText.Parent = panel

	local castText = Instance.new("TextLabel")
	castText.Name = "CastText"
	castText.Visible = false
	castText.Parent = panel

	local instructionText = Instance.new("TextLabel")
	instructionText.Name = "InstructionText"
	instructionText.Visible = false
	instructionText.Parent = panel

	ui.customFishingMinigame = {
		version = UI_VERSION,
		panel = panel,
		backbone = panel,
		headerText = headerText,
		waterPanel = waterPanel,
		waterInner = waterInner,
		catchBar = catchBar,
		fishMarker = fishMarker,
		fishImage = fishImage,
		progressTrack = progressTrack,
		progressInner = progressInner,
		progressFill = progressFill,
		gaugeAssets = {
			Blue = ASSETS.BlueGauge,
			Purple = ASSETS.PurpleGauge,
			Orange = ASSETS.OrangeGauge,
			Red = ASSETS.RedGauge,
		},
		setGaugeAsset = setGaugeAsset,
		setFishSilhouette = setFishSilhouette,
		beginRagePresentation = beginRagePresentation,
		showRageWarning = showRageWarning,
		hideRageWarning = hideRageWarning,
		focusGauge = focusGauge,
		restoreRagePresentation = restoreRagePresentation,
		setNoBlurActive = setHardNoBlurActive,
		refreshNoBlur = refreshHardNoBlur,
		setProgress = function(amount)
			setDisplayedProgress(amount)
		end,
		updateProgress = function(amount)
			setDisplayedProgress(amount)
		end,
		statusBubble = panel,
		statusText = statusText,
		progressText = progressText,
		baitText = baitText,
		castText = castText,
		instructionText = instructionText,
	}

	return ui.customFishingMinigame
end

function MinigameController.build(ctx)
	return ensureUi(ctx)
end

function MinigameController.run(ctx, prompt)
	local ui = ctx.ui
	local state = ctx.state
	local getBaitData = ctx.BaitUtils.getBaitData
	local getBaitCountText = ctx.BaitUtils.getBaitCountText

	if ctx.minigameRunning then
		return
	end

	local custom = ensureUi(ctx)

	local isAutoFish = prompt.autoFish == true
	local fish = prompt.fish or {}
	local promptBait = prompt.bait or {}
	local promptBaitId = promptBait.id or (state and state.EquippedBait) or ctx.GameConfig.BasicBaitId
	local promptBaitData = getBaitData(promptBaitId)
	local promptBaitName = promptBait.name or promptBaitData.displayName
	local castDisplay = prompt.cast and prompt.cast.displayName or nil
	local rodGreenStyle = getRodGreenStyle(prompt, state)

	local minigameConfig = prompt.minigame or ctx.GameConfig.getFishingMinigameConfig(fish.rarity or "Common", state and state.EquippedRod or "WoodenRod")
	local difficulty = minigameConfig.difficulty or ctx.GameConfig.FishingMinigame.RarityDifficulty.Common
	local random = Random.new(math.floor((os.clock() * 100000) % 2147483647))

	ctx.minigameRunning = true
	ctx.fishingBusy = true

	if ctx.CastPower then
		ctx.CastPower.running = false
		ctx.CastPower.activeConfig = nil
		if ctx.CastPower.content then
			ctx.CastPower.content.Visible = false
		end
	end

	if ui.minigame then
		ui.minigame.Visible = false
	end

	-- Remove BlurEffect and DepthOfFieldEffect and keep them disabled.
	bindNoBlur(ctx)

	custom.panel.Visible = true
	setFishingBarsVisible(ctx, false)

	custom.headerText.Text = isAutoFish and "AutoFish is waiting..." or "Waiting for a bite..."
	custom.statusText.Text = "Something is biting..."
	custom.progressText.Text = "Progress --"
	custom.baitText.Text = string.format('<font color="#38D9FF">Bait:</font> %s (%s)', promptBaitName, getBaitCountText(promptBaitId, promptBait.remaining))
	custom.castText.Text = castDisplay and string.format('<font color="#38D9FF">Cast:</font> %s', castDisplay) or '<font color="#38D9FF">Cast:</font> --'
	custom.instructionText.Text = isAutoFish and "AutoFish is handling this catch." or "Hold mouse, tap, or Space to lift the green bar. Release to let it fall."
	setProgressFillAmount(custom.progressFill, 0)
	custom.fishImage.Image = getFishImage(ctx, fish)
	custom.catchBar.Image = rodGreenStyle.image

	local hideBarsConnection = ctx.RunService.RenderStepped:Connect(function()
		if ctx.minigameRunning and custom.panel.Visible then
			forceFishingBlurOff(ctx)
			setFishingBarsVisible(ctx, false)
			if ui.minigame then
				ui.minigame.Visible = false
			end
		end
	end)

	task.wait(tonumber(prompt.biteDelay) or 0)

	if not ctx.minigameRunning then
		if hideBarsConnection then
			hideBarsConnection:Disconnect()
		end
		custom.panel.Visible = false
		return
	end

	-- The equipped rod now controls both the green image and its physical catch height.
	local barSize = rodGreenStyle.barSize
	local CATCH_TOP_LIMIT = 0.055
	local CATCH_BOTTOM_LIMIT = 0.925
	local maxBarTop = CATCH_BOTTOM_LIMIT - barSize
	local barTop = math.clamp(0.720, CATCH_TOP_LIMIT, maxBarTop)
	local barVelocity = 0

	local fishY = random:NextNumber(0.28, 0.42)
	local fishTarget = random:NextNumber(0.15, 0.85)
	local fishVelocity = 0

	local configuredStartProgress = tonumber(minigameConfig.startProgress)
	if configuredStartProgress == nil then
		configuredStartProgress = 0.10
	end
	local progress = math.clamp(configuredStartProgress, 0.05, 0.18)
	local minSuccessDuration = tonumber(minigameConfig.minSuccessDuration) or 1.75
	local maxDuration = tonumber(minigameConfig.maxDuration) or 35
	local gameStartedAt = os.clock()
	local nextDecisionAt = gameStartedAt + random:NextNumber(difficulty.turnIntervalMin or 1, difficulty.turnIntervalMax or 2)
	local pauseUntil = 0
	local burstUntil = 0
	local holding = false
	local finished = false

	custom.catchBar.Size = UDim2.fromScale(0.94, barSize)
	custom.catchBar.Position = UDim2.fromScale(0.5, barTop)
	custom.fishMarker.Position = UDim2.fromScale(0.5, fishY)
	setProgressFillAmount(custom.progressFill, progress)

	-- When the fish actually bites, change the top instruction.
	custom.headerText.Text = isAutoFish and "AutoFish is reeling..." or "Keep the fish inside the green bar!"
	custom.statusText.Text = "Something is biting..."
	custom.progressText.Text = string.format("Progress %d%%", math.floor(progress * 100 + 0.5))

	local renderConnection
	local inputBeganConnection
	local inputEndedConnection

	local function disconnectAll()
		unbindNoBlur(ctx)

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
		if hideBarsConnection then
			hideBarsConnection:Disconnect()
			hideBarsConnection = nil
		end
	end

	ctx.activeMinigameCleanup = disconnectAll

	local function finish(success)
		if finished then
			return
		end

		finished = true
		disconnectAll()
		ctx.activeMinigameCleanup = nil

		custom.panel.Visible = false
		ctx.minigameRunning = false
		ctx.fishingBusy = false

		forceFishingBlurOff(ctx)

		if not isAutoFish then
			ctx.Remotes.FinishMinigame:FireServer({
				success = success == true,
				sessionId = prompt.sessionId,
			})
		end

		if ctx.renderContent then
			ctx.renderContent()
		else
			setFishingBarsVisible(ctx, true)
		end
	end

	local function isCatchInput(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.Space
	end

	if not isAutoFish then
		inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if isCatchInput(input) then
				holding = true
			end
		end)

		inputEndedConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
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

	renderConnection = ctx.RunService.RenderStepped:Connect(function(deltaTime)
		if not ctx.minigameRunning or finished then
			return
		end

		setFishingBarsVisible(ctx, false)

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
			fishY = 0.075
			fishVelocity = math.abs(fishVelocity) * 0.35
			fishTarget = math.max(fishTarget, 0.16)
		elseif fishY >= 0.96 then
			fishY = 0.925
			fishVelocity = -math.abs(fishVelocity) * 0.35
			fishTarget = math.min(fishTarget, 0.84)
		end

		if isAutoFish then
			local targetTop = math.clamp(fishY - (barSize / 2), CATCH_TOP_LIMIT, maxBarTop)
			barTop += (targetTop - barTop) * math.min(1, deltaTime * 5)
			progress = math.clamp(progress + (minigameConfig.progressGainPerSecond or 0.34) * deltaTime, 0, 1)
		else
			local barAcceleration = holding and -(minigameConfig.lift or 2.75) or (minigameConfig.gravity or 1.8)
			barVelocity += barAcceleration * deltaTime
			barVelocity = math.clamp(barVelocity, -(minigameConfig.maxBarVelocity or 1.65), minigameConfig.maxBarVelocity or 1.65)
			barVelocity *= math.pow(minigameConfig.damping or 0.90, deltaTime * 60)
			barTop += barVelocity * deltaTime

			if barTop <= CATCH_TOP_LIMIT then
				barTop = CATCH_TOP_LIMIT
				barVelocity = math.abs(barVelocity) * (minigameConfig.bounceDamping or 0.36)
			elseif barTop >= maxBarTop then
				barTop = maxBarTop
				barVelocity = -math.abs(barVelocity) * (minigameConfig.bounceDamping or 0.36)
			end

			-- The old code checked only the exact center point of the fish.
			-- Visually, the fish/circle could already overlap the green box while
			-- its center was still just outside, so the progress gauge did not rise.
			-- Use the visible fish-marker height to perform an overlap test instead.
			local movementHeight = math.max(custom.waterInner.AbsoluteSize.Y, 1)
			local markerHeightScale = custom.fishMarker.AbsoluteSize.Y / movementHeight

			-- Fallback for the first rendered frame before AbsoluteSize is ready.
			if markerHeightScale <= 0.001 then
				markerHeightScale = 0.19
			end

			-- Use most of the visible fish dish as the collision area.
			local fishCollisionHalfHeight = markerHeightScale * 0.40
			local fishTop = fishY - fishCollisionHalfHeight
			local fishBottom = fishY + fishCollisionHalfHeight
			local barBottom = barTop + barSize

			local overlapHeight = math.max(
				0,
				math.min(fishBottom, barBottom) - math.max(fishTop, barTop)
			)
			local fishCollisionHeight = math.max(fishCollisionHalfHeight * 2, 0.001)
			local overlapRatio = overlapHeight / fishCollisionHeight

			-- About 12% visible overlap is enough to count as being inside.
			-- This matches what the player actually sees on screen.
			local fishInsideBar = overlapRatio >= 0.12

			if fishInsideBar then
				progress += (minigameConfig.progressGainPerSecond or 0.34) * deltaTime
			else
				progress -= (minigameConfig.progressDrainPerSecond or 0.16) * deltaTime
			end
			progress = math.clamp(progress, 0, 1)
		end

		custom.catchBar.Position = UDim2.fromScale(0.5, barTop)
		custom.fishMarker.Position = UDim2.fromScale(0.5, fishY)
		setProgressFillAmount(custom.progressFill, progress)
		custom.progressText.Text = string.format("Progress %d%%", math.floor(progress * 100 + 0.5))

		if isAutoFish and elapsed >= (prompt.visualTime or 3) then
			custom.headerText.Text = "AutoFish caught it!"
			finish(true)
		elseif not isAutoFish and progress >= 1 and elapsed >= minSuccessDuration then
			custom.headerText.Text = "Caught!"
			finish(true)
		elseif not isAutoFish and progress <= 0 then
			custom.headerText.Text = "The fish escaped!"
			finish(false)
		elseif not isAutoFish and elapsed >= maxDuration then
			custom.headerText.Text = "The fish escaped!"
			finish(false)
		end
	end)
end

return MinigameController


