local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MINIMUM_DISPLAY_TIME = 3.25
local MAXIMUM_DISPLAY_TIME = 20
local FADE_DURATION = 0.8
local STUDIO_PREVIEW_MODE = false

local COLORS = {
	DeepBlue = Color3.fromRGB(17, 82, 151),
	LightBlue = Color3.fromRGB(126, 192, 222),
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

local templates = ReplicatedFirst:WaitForChild("AuxiliaryUiTemplates")

-- The two authored ScreenGui templates intentionally use different inset
-- policies: the background is full bleed, while the artwork is device-safe.
local backgroundScreenGui = templates:WaitForChild("FishyFishLoadingBackground"):Clone()
backgroundScreenGui.ScreenInsets = Enum.ScreenInsets.None
backgroundScreenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
backgroundScreenGui.ClipToDeviceSafeArea = false
backgroundScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local screenGui = templates:WaitForChild("FishyFishLoadingScreen"):Clone()
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
screenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
screenGui.ClipToDeviceSafeArea = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local backgroundRoot = backgroundScreenGui:WaitForChild("FullBleedBackgroundCanvas")
local background = backgroundRoot:WaitForChild("HarborBackground")
local lowerShade = backgroundRoot:WaitForChild("LowerContrastShade")
local lowerShadeGradient = lowerShade:WaitForChild("LowerShadeGradient")
local root = screenGui:WaitForChild("LoadingCanvas")
local logoMotion = root:WaitForChild("LogoMotion")
local logo = logoMotion:WaitForChild("FishyFishLogo")
local logoAspect = logo:WaitForChild("LogoAspect")
local fallbackLogo = logoMotion:WaitForChild("FishyFishLogoFallback")
local fallbackLogoAspect = fallbackLogo:WaitForChild("FallbackLogoAspect")
local lowerUi = root:WaitForChild("LoadingInformation")
local ornament = lowerUi:WaitForChild("AnchorAndWaves")
local statusText = lowerUi:WaitForChild("StatusText")
local dotRow = lowerUi:WaitForChild("LoadingDots")
local dotLayout = dotRow:WaitForChild("DotLayout")
local dotScale = dotRow:WaitForChild("ResponsiveScale")

background.ScaleType = Enum.ScaleType.Crop
background.ResampleMode = Enum.ResamplerMode.Default
lowerShadeGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.58, 1),
	NumberSequenceKeypoint.new(1, 0.35),
})
logo.ScaleType = Enum.ScaleType.Fit
logo.ResampleMode = Enum.ResamplerMode.Default
logoAspect.DominantAxis = Enum.DominantAxis.Width
fallbackLogo.ScaleType = Enum.ScaleType.Fit
fallbackLogo.ResampleMode = Enum.ResamplerMode.Default
fallbackLogoAspect.DominantAxis = Enum.DominantAxis.Width
dotLayout.FillDirection = Enum.FillDirection.Horizontal
dotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dotLayout.VerticalAlignment = Enum.VerticalAlignment.Center

backgroundScreenGui.Parent = playerGui
screenGui.Parent = playerGui

local function bindWave(wave, direction)
	local segmentCount = 18
	local segments = {}
	for index = 1, segmentCount do
		table.insert(segments, wave:WaitForChild("CurveSegment" .. index))
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

bindWave(ornament:WaitForChild("LeftWave"), -1)
bindWave(ornament:WaitForChild("RightWave"), 1)

local dots = {}
for index = 1, 5 do
	table.insert(dots, dotRow:WaitForChild("Dot" .. index))
end

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
