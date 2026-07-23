local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BACKGROUND_IMAGE = "rbxassetid://127539948539559"
local HIGH_QUALITY_LOGO_IMAGE = "rbxassetid://72585587327009"
local FALLBACK_LOGO_IMAGE = "rbxassetid://137479516081769"

local MINIMUM_DISPLAY_TIME = 3.25
local MAXIMUM_DISPLAY_TIME = 20
local FADE_DURATION = 0.8
local STUDIO_PREVIEW_MODE = false

local COLORS = {
	DeepBlue = Color3.fromRGB(17, 82, 151),
	MidBlue = Color3.fromRGB(42, 128, 187),
	LightBlue = Color3.fromRGB(126, 192, 222),
	FallbackSky = Color3.fromRGB(79, 157, 219),
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local existing = playerGui:FindFirstChild("FishyFishLoadingScreen")
if existing then
	existing:Destroy()
end

local existingBackground = playerGui:FindFirstChild("FishyFishLoadingBackground")
if existingBackground then
	existingBackground:Destroy()
end

-- The background ignores every device inset so no part of the 3D world can
-- show through around notches, rounded corners, ultrawide screens, or TVs.
local backgroundScreenGui = Instance.new("ScreenGui")
backgroundScreenGui.Name = "FishyFishLoadingBackground"
backgroundScreenGui.ScreenInsets = Enum.ScreenInsets.None
backgroundScreenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
backgroundScreenGui.ClipToDeviceSafeArea = false
backgroundScreenGui.DisplayOrder = 99999
backgroundScreenGui.ResetOnSpawn = false
backgroundScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
backgroundScreenGui.Parent = playerGui

local backgroundRoot = Instance.new("CanvasGroup")
backgroundRoot.Name = "FullBleedBackgroundCanvas"
backgroundRoot.Size = UDim2.fromScale(1, 1)
backgroundRoot.BackgroundColor3 = COLORS.FallbackSky
backgroundRoot.BorderSizePixel = 0
backgroundRoot.GroupTransparency = 0
backgroundRoot.Active = true
backgroundRoot.Parent = backgroundScreenGui

-- Foreground artwork stays inside the device-safe area so it remains clear of
-- phone notches and rounded screen cutouts while using the available space.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FishyFishLoadingScreen"
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
screenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
screenGui.ClipToDeviceSafeArea = true
screenGui.DisplayOrder = 100000
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local root = Instance.new("CanvasGroup")
root.Name = "LoadingCanvas"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.BorderSizePixel = 0
root.GroupTransparency = 0
root.Active = true
root.Parent = screenGui

local background = Instance.new("ImageLabel")
background.Name = "HarborBackground"
background.AnchorPoint = Vector2.new(0.5, 0.5)
background.Position = UDim2.fromScale(0.5, 0.5)
background.Size = UDim2.fromScale(1.012, 1.012)
background.BackgroundTransparency = 1
background.BorderSizePixel = 0
background.Image = BACKGROUND_IMAGE
background.ScaleType = Enum.ScaleType.Crop
background.ResampleMode = Enum.ResamplerMode.Default
background.ZIndex = 1
background.Parent = backgroundRoot

local lowerShade = Instance.new("Frame")
lowerShade.Name = "LowerContrastShade"
lowerShade.Size = UDim2.fromScale(1, 1)
lowerShade.BackgroundColor3 = Color3.fromRGB(5, 43, 91)
lowerShade.BackgroundTransparency = 0.82
lowerShade.BorderSizePixel = 0
lowerShade.ZIndex = 2
lowerShade.Parent = backgroundRoot

local lowerShadeGradient = Instance.new("UIGradient")
lowerShadeGradient.Rotation = 90
lowerShadeGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.58, 1),
	NumberSequenceKeypoint.new(1, 0.35),
})
lowerShadeGradient.Parent = lowerShade

local logoMotion = Instance.new("Frame")
logoMotion.Name = "LogoMotion"
logoMotion.AnchorPoint = Vector2.new(0.5, 0.5)
logoMotion.Position = UDim2.fromScale(0.5, 0.5)
logoMotion.Size = UDim2.fromScale(1, 1)
logoMotion.BackgroundTransparency = 1
logoMotion.ZIndex = 5
logoMotion.Parent = root

local logo = Instance.new("ImageLabel")
logo.Name = "FishyFishLogo"
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.Position = UDim2.fromScale(0.5, 0.43)
logo.Size = UDim2.fromScale(0.54, 0.54)
logo.BackgroundTransparency = 1
logo.Image = HIGH_QUALITY_LOGO_IMAGE
logo.ImageTransparency = 1
logo.ScaleType = Enum.ScaleType.Fit
logo.ResampleMode = Enum.ResamplerMode.Default
logo.ZIndex = 6
logo.Parent = logoMotion

local logoAspect = Instance.new("UIAspectRatioConstraint")
logoAspect.AspectRatio = 1307 / 720
logoAspect.DominantAxis = Enum.DominantAxis.Width
logoAspect.Parent = logo

local fallbackLogo = Instance.new("ImageLabel")
fallbackLogo.Name = "FishyFishLogoFallback"
fallbackLogo.AnchorPoint = Vector2.new(0.5, 0.5)
fallbackLogo.Position = UDim2.fromScale(0.5, 0.43)
fallbackLogo.Size = UDim2.fromScale(0.54, 0.54)
fallbackLogo.BackgroundTransparency = 1
fallbackLogo.Image = FALLBACK_LOGO_IMAGE
fallbackLogo.ImageTransparency = 1
fallbackLogo.ScaleType = Enum.ScaleType.Fit
fallbackLogo.ResampleMode = Enum.ResamplerMode.Default
fallbackLogo.ZIndex = 5
fallbackLogo.Parent = logoMotion

local fallbackLogoAspect = Instance.new("UIAspectRatioConstraint")
fallbackLogoAspect.AspectRatio = 1672 / 941
fallbackLogoAspect.DominantAxis = Enum.DominantAxis.Width
fallbackLogoAspect.Parent = fallbackLogo

local lowerUi = Instance.new("Frame")
lowerUi.Name = "LoadingInformation"
lowerUi.AnchorPoint = Vector2.new(0.5, 0.5)
lowerUi.Position = UDim2.fromScale(0.5, 0.775)
lowerUi.Size = UDim2.fromScale(0.56, 0.22)
lowerUi.BackgroundTransparency = 1
lowerUi.ZIndex = 10
lowerUi.Parent = root

local ornament = Instance.new("Frame")
ornament.Name = "AnchorAndWaves"
ornament.AnchorPoint = Vector2.new(0.5, 0)
ornament.Position = UDim2.fromScale(0.5, 0)
ornament.Size = UDim2.fromScale(0.42, 0.28)
ornament.BackgroundTransparency = 1
ornament.ZIndex = 10
ornament.Parent = lowerUi

local function makeWave(parent, direction)
	local wave = Instance.new("Frame")
	wave.Name = direction < 0 and "LeftWave" or "RightWave"
	wave.AnchorPoint = Vector2.new(direction < 0 and 1 or 0, 0.5)
	wave.Position = UDim2.fromScale(direction < 0 and 0.38 or 0.62, 0.53)
	wave.Size = UDim2.fromScale(0.24, 0.52)
	wave.BackgroundTransparency = 1
	wave.ZIndex = 10
	wave.Parent = parent

	local segmentCount = 18
	local segments = {}
	for index = 1, segmentCount do
		local segment = Instance.new("Frame")
		segment.Name = "CurveSegment" .. index
		segment.AnchorPoint = Vector2.new(0.5, 0.5)
		segment.BackgroundColor3 = COLORS.MidBlue
		segment.BorderSizePixel = 0
		segment.ZIndex = 10
		segment.Parent = wave

		local segmentCorner = Instance.new("UICorner")
		segmentCorner.CornerRadius = UDim.new(1, 0)
		segmentCorner.Parent = segment

		table.insert(segments, segment)
	end

	local function layoutCurve()
		local size = wave.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end

		local centerY = size.Y * 0.5
		local amplitude = size.Y * 0.19
		local cycles = 2.35
		local thickness = math.clamp(size.Y * 0.17, 2.5, 4.2)

		for index, segment in ipairs(segments) do
			local progress0 = (index - 1) / segmentCount
			local progress1 = index / segmentCount
			local sample0 = direction < 0 and 1 - progress0 or progress0
			local sample1 = direction < 0 and 1 - progress1 or progress1
			local x0 = progress0 * size.X
			local x1 = progress1 * size.X
			local y0 = centerY + math.sin(sample0 * math.pi * 2 * cycles) * amplitude
			local y1 = centerY + math.sin(sample1 * math.pi * 2 * cycles) * amplitude
			local deltaX = x1 - x0
			local deltaY = y1 - y0

			segment.Position = UDim2.fromOffset((x0 + x1) * 0.5, (y0 + y1) * 0.5)
			segment.Size = UDim2.fromOffset(math.sqrt(deltaX * deltaX + deltaY * deltaY) + 1.5, thickness)
			segment.Rotation = math.deg(math.atan2(deltaY, deltaX))
		end
	end

	task.defer(layoutCurve)
	wave:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutCurve)
end

makeWave(ornament, -1)
makeWave(ornament, 1)

local anchor = Instance.new("TextLabel")
anchor.Name = "Anchor"
anchor.AnchorPoint = Vector2.new(0.5, 0.5)
anchor.Position = UDim2.fromScale(0.5, 0.53)
anchor.Size = UDim2.fromScale(0.18, 1.08)
anchor.BackgroundTransparency = 1
anchor.Font = Enum.Font.GothamBold
anchor.Text = utf8.char(0x2693)
anchor.TextColor3 = COLORS.DeepBlue
anchor.TextScaled = true
anchor.ZIndex = 11
anchor.Parent = ornament

local anchorTextSize = Instance.new("UITextSizeConstraint")
anchorTextSize.MinTextSize = 16
anchorTextSize.MaxTextSize = 42
anchorTextSize.Parent = anchor

local statusText = Instance.new("TextLabel")
statusText.Name = "StatusText"
statusText.AnchorPoint = Vector2.new(0.5, 0)
statusText.Position = UDim2.fromScale(0.5, 0.34)
statusText.Size = UDim2.fromScale(1, 0.3)
statusText.BackgroundTransparency = 1
statusText.Font = Enum.Font.GothamBold
statusText.Text = "PREPARING YOUR FISHING ADVENTURE..."
statusText.TextColor3 = COLORS.DeepBlue
statusText.TextScaled = true
statusText.TextStrokeColor3 = Color3.fromRGB(220, 241, 249)
statusText.TextStrokeTransparency = 0.82
statusText.ZIndex = 10
statusText.Parent = lowerUi

local statusTextSize = Instance.new("UITextSizeConstraint")
statusTextSize.MinTextSize = 12
statusTextSize.MaxTextSize = 25
statusTextSize.Parent = statusText

local dotRow = Instance.new("Frame")
dotRow.Name = "LoadingDots"
dotRow.AnchorPoint = Vector2.new(0.5, 0)
dotRow.Position = UDim2.fromScale(0.5, 0.7)
dotRow.Size = UDim2.fromOffset(150, 24)
dotRow.BackgroundTransparency = 1
dotRow.ZIndex = 10
dotRow.Parent = lowerUi

local dotLayout = Instance.new("UIListLayout")
dotLayout.FillDirection = Enum.FillDirection.Horizontal
dotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dotLayout.VerticalAlignment = Enum.VerticalAlignment.Center
dotLayout.Padding = UDim.new(0, 10)
dotLayout.Parent = dotRow

local dots = {}
for index = 1, 5 do
	local dot = Instance.new("Frame")
	dot.Name = "Dot" .. index
	dot.Size = UDim2.fromOffset(18, 18)
	dot.BackgroundColor3 = COLORS.LightBlue
	dot.BackgroundTransparency = 0.35
	dot.BorderSizePixel = 0
	dot.LayoutOrder = index
	dot.ZIndex = 10
	dot.Parent = dotRow

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	table.insert(dots, dot)
end

local dotScale = Instance.new("UIScale")
dotScale.Scale = 1
dotScale.Parent = dotRow

local logoBaseY = 0.43

local function updateResponsiveLayout()
	local viewport = root.AbsoluteSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return
	end

	local aspect = viewport.X / viewport.Y
	local logoWidth
	local fallbackLogoWidth
	if aspect < 0.8 then
		logoWidth = 0.77
		fallbackLogoWidth = 0.98
		logoBaseY = 0.35
		lowerUi.Position = UDim2.fromScale(0.5, 0.72)
		lowerUi.Size = UDim2.fromScale(0.9, 0.22)
	elseif aspect < 1.35 then
		logoWidth = 0.61
		fallbackLogoWidth = 0.78
		logoBaseY = 0.39
		lowerUi.Position = UDim2.fromScale(0.5, 0.74)
		lowerUi.Size = UDim2.fromScale(0.78, 0.22)
	else
		logoWidth = 0.425
		fallbackLogoWidth = 0.54
		logoBaseY = 0.43
		lowerUi.Position = UDim2.fromScale(0.5, 0.775)
		lowerUi.Size = UDim2.fromScale(0.56, 0.22)
	end

	logo.Position = UDim2.fromScale(0.5, logoBaseY)
	fallbackLogo.Position = logo.Position
	local logoWidthPixels = math.min(viewport.X * logoWidth, viewport.Y * 0.46 * logoAspect.AspectRatio)
	local fallbackLogoWidthPixels = math.min(
		viewport.X * fallbackLogoWidth,
		viewport.Y * 0.46 * fallbackLogoAspect.AspectRatio
	)
	logo.Size = UDim2.fromOffset(logoWidthPixels, logoWidthPixels)
	fallbackLogo.Size = UDim2.fromOffset(fallbackLogoWidthPixels, fallbackLogoWidthPixels)
	dotScale.Scale = math.clamp(math.min(viewport.X, viewport.Y) / 760, 0.78, 1.12)
end

updateResponsiveLayout()
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateResponsiveLayout)

local backgroundTween = TweenService:Create(
	background,
	TweenInfo.new(12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{
		Position = UDim2.fromScale(0.498, 0.502),
		Size = UDim2.fromScale(1.025, 1.025),
	}
)
backgroundTween:Play()

local logoFloatStartedAt = os.clock()
local logoFloatDistance = 8
local logoFloatConnection = RunService.RenderStepped:Connect(function()
	local elapsed = os.clock() - logoFloatStartedAt
	local offsetY = math.sin(elapsed * math.pi * 2 / 4.8) * logoFloatDistance
	local position = UDim2.new(0.5, 0, logoBaseY, offsetY)
	logo.Position = position
	fallbackLogo.Position = position
end)

local ornamentTween = TweenService:Create(
	ornament,
	TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Rotation = 1.2 }
)
ornamentTween:Play()

local textPulseTween = TweenService:Create(
	statusText,
	TweenInfo.new(1.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ TextTransparency = 0.13 }
)
textPulseTween:Play()

local animationRunning = true
task.spawn(function()
	local activeIndex = 1
	while animationRunning and screenGui.Parent do
		for index, dot in ipairs(dots) do
			local isActive = index == activeIndex
			TweenService:Create(
				dot,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					BackgroundColor3 = isActive and COLORS.DeepBlue or COLORS.LightBlue,
					BackgroundTransparency = isActive and 0 or 0.38,
					Size = isActive and UDim2.fromOffset(20, 20) or UDim2.fromOffset(18, 18),
				}
			):Play()
		end

		activeIndex = (activeIndex % #dots) + 1
		task.wait(0.32)
	end
end)

local loadStartedAt = os.clock()
local gameLoaded = game:IsLoaded()

if not gameLoaded then
	task.spawn(function()
		game.Loaded:Wait()
		gameLoaded = true
	end)
end

local uiAssetsLoaded = false
local highQualityLogoLoaded = false

task.spawn(function()
	local success = pcall(function()
		ContentProvider:PreloadAsync({ logo })
	end)
	if not success or not logo.IsLoaded or not screenGui.Parent then
		return
	end

	highQualityLogoLoaded = true
	TweenService:Create(
		logo,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ ImageTransparency = 0 }
	):Play()
	TweenService:Create(
		fallbackLogo,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ ImageTransparency = 1 }
	):Play()
end)

task.spawn(function()
	local success, preloadError = pcall(function()
		ContentProvider:PreloadAsync({ background, fallbackLogo })
	end)
	if not success then
		warn("[FishyFishLoadingScreen] Base image preload failed:", preloadError)
	end
	uiAssetsLoaded = true

	if screenGui.Parent and not highQualityLogoLoaded then
		TweenService:Create(
			fallbackLogo,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ ImageTransparency = 0 }
		):Play()
	end
end)

while screenGui.Parent do
	local elapsed = os.clock() - loadStartedAt
	local minimumReached = elapsed >= MINIMUM_DISPLAY_TIME
	local ready = gameLoaded and uiAssetsLoaded and minimumReached
	local timedOut = elapsed >= MAXIMUM_DISPLAY_TIME
	if ready or timedOut then
		break
	end
	task.wait(0.05)
end

-- Keep the animated loading screen visible for inspection while testing in Studio.
-- Set STUDIO_PREVIEW_MODE to false when you want Studio to follow the live-game timing.
if RunService:IsStudio() and STUDIO_PREVIEW_MODE then
	while screenGui.Parent do
		task.wait(0.25)
	end
	logoFloatConnection:Disconnect()
	return
end

animationRunning = false
logoFloatConnection:Disconnect()

local fadeTween = TweenService:Create(
	root,
	TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
	{ GroupTransparency = 1 }
)
local backgroundFadeTween = TweenService:Create(
	backgroundRoot,
	TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
	{ GroupTransparency = 1 }
)
backgroundFadeTween:Play()
fadeTween:Play()
fadeTween.Completed:Wait()

screenGui:Destroy()
backgroundScreenGui:Destroy()
