-- TapButton_CodeCircle_Replacement
-- Put this as a NEW LocalScript here:
-- StarterGui > FishingGui > TapButtonCodeCircle
--
-- This keeps the existing fishing button's click logic.
-- It only replaces the old visual with a code-drawn circular UI.
-- Do NOT paste this into FishingClient.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local fishingGui = playerGui:WaitForChild("FishingGui")

-- =========================================================
-- EASY SETTINGS
-- =========================================================
local BUTTON_SIZE_DESKTOP = 118
local BUTTON_SIZE_MOBILE = 104

local OFFSET_X = 0
local OFFSET_Y = 0

local OUTER_RING_THICKNESS = 7

-- Dark ring, but no longer fully opaque.
local OUTER_COLOR = Color3.fromRGB(22, 24, 28)
local OUTER_TRANSPARENCY = 0.22

-- Brighter outer outline so the button is visible over water/terrain.
local OUTER_STROKE_COLOR = Color3.fromRGB(178, 188, 202)
local OUTER_STROKE_TRANSPARENCY = 0.18
local OUTER_STROKE_THICKNESS = 2.5

-- Much more transparent center.
local INNER_COLOR = Color3.fromRGB(42, 45, 50)
local INNER_TRANSPARENCY = 0.80

-- Soft inner highlight ring.
local INNER_STROKE_COLOR = Color3.fromRGB(140, 150, 166)
local INNER_STROKE_TRANSPARENCY = 0.42
local INNER_STROKE_THICKNESS = 1.5

local SHOW_TAP_TEXT = true
local TAP_TEXT = "TAP"
local TAP_TEXT_SIZE = 26

local PRESSED_SCALE = 0.92
local DISABLED_TRANSPARENCY = 0.48

-- =========================================================

local patchedButton = nil
local visualRoot = nil
local pressScale = nil
local innerCircle = nil
local tapLabel = nil
local activeTween = nil

local function normalize(value)
	return string.lower(
		tostring(value or "")
			:gsub("^%s+", "")
			:gsub("%s+$", "")
	)
end

local function disableOldTapVisualScripts()
	local oldNames = {
		"TapButtonVisualPatch",
		"TapButtonVisualPatchV2",
		"TapButtonVisualPatch_V2_EXACT_TARGET",
	}

	for _, name in ipairs(oldNames) do
		local oldScript = fishingGui:FindFirstChild(name)

		if oldScript
			and oldScript:IsA("LocalScript")
			and oldScript ~= script
		then
			oldScript.Enabled = false
		end
	end
end

local function isTapButton(instance)
	if not instance:IsA("GuiButton") then
		return false
	end

	local name = normalize(instance.Name)
	local text = instance:IsA("TextButton")
		and normalize(instance.Text)
		or ""

	if name:find("auto", 1, true) then
		return false
	end

	return name == "centercastbutton"
		or name == "castrodbutton"
		or name == "tapbutton"
		or name:find("centercast", 1, true) ~= nil
		or name:find("castrod", 1, true) ~= nil
		or text == "tap"
		or text == "cast rod"
		or text == "fishing..."
end

local function findTapButton()
	-- Prefer exact names first.
	for _, descendant in ipairs(fishingGui:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			local name = normalize(descendant.Name)

			if name == "centercastbutton"
				or name == "castrodbutton"
				or name == "tapbutton"
			then
				return descendant
			end
		end
	end

	for _, descendant in ipairs(fishingGui:GetDescendants()) do
		if isTapButton(descendant) then
			return descendant
		end
	end

	return nil
end

local function addCircleCorner(parent)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function getTargetSize()
	if UserInputService.TouchEnabled then
		return BUTTON_SIZE_MOBILE
	end

	return BUTTON_SIZE_DESKTOP
end

local function hideOldButtonVisual(button)
	button.BackgroundTransparency = 1
	button.ClipsDescendants = false

	if button:IsA("TextButton") then
		button.TextTransparency = 1
		button.TextStrokeTransparency = 1
	elseif button:IsA("ImageButton") then
		button.ImageTransparency = 1
	end

	for _, child in ipairs(button:GetChildren()) do
		if child.Name == "CodeCircleVisual" then
			continue
		end

		if child.Name == "ModernTapVisual"
			or child.Name == "TapArtwork"
		then
			child:Destroy()
		elseif child:IsA("UIStroke") then
			child.Enabled = false
		elseif child:IsA("UIGradient") then
			child.Enabled = false
		elseif child:IsA("Frame")
			or child:IsA("ImageLabel")
			or child:IsA("ImageButton")
			or child:IsA("TextLabel")
			or child:IsA("TextButton")
		then
			child.Visible = false
		end
	end
end

local function tweenPressed(pressed)
	if not pressScale then
		return
	end

	if activeTween then
		activeTween:Cancel()
	end

	activeTween = TweenService:Create(
		pressScale,
		TweenInfo.new(
			0.08,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			Scale = pressed and PRESSED_SCALE or 1,
		}
	)

	activeTween:Play()
end

local function updateEnabledLook()
	if not patchedButton or not innerCircle then
		return
	end

	local usable = patchedButton.Visible
		and patchedButton.Active

	innerCircle.BackgroundTransparency = usable
		and INNER_TRANSPARENCY
		or DISABLED_TRANSPARENCY

	if tapLabel then
		tapLabel.TextTransparency = usable and 0 or 0.45
	end
end

local function buildVisual(button)
	local oldVisual = button:FindFirstChild("CodeCircleVisual")
	if oldVisual then
		oldVisual:Destroy()
	end

	local size = getTargetSize()

	visualRoot = Instance.new("Frame")
	visualRoot.Name = "CodeCircleVisual"
	visualRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	visualRoot.Position = UDim2.new(
		0.5,
		OFFSET_X,
		0.5,
		OFFSET_Y
	)
	visualRoot.Size = UDim2.fromOffset(size, size)
	visualRoot.BackgroundColor3 = OUTER_COLOR
	visualRoot.BackgroundTransparency = OUTER_TRANSPARENCY
	visualRoot.BorderSizePixel = 0
	visualRoot.Active = false
	visualRoot.ZIndex = button.ZIndex + 20
	visualRoot.Parent = button
	addCircleCorner(visualRoot)
	addStroke(
		visualRoot,
		OUTER_STROKE_COLOR,
		OUTER_STROKE_THICKNESS,
		OUTER_STROKE_TRANSPARENCY
	)

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = visualRoot

	pressScale = Instance.new("UIScale")
	pressScale.Name = "PressScale"
	pressScale.Scale = 1
	pressScale.Parent = visualRoot

	innerCircle = Instance.new("Frame")
	innerCircle.Name = "TranslucentCenter"
	innerCircle.Position = UDim2.fromOffset(
		OUTER_RING_THICKNESS,
		OUTER_RING_THICKNESS
	)
	innerCircle.Size = UDim2.new(
		1,
		-(OUTER_RING_THICKNESS * 2),
		1,
		-(OUTER_RING_THICKNESS * 2)
	)
	innerCircle.BackgroundColor3 = INNER_COLOR
	innerCircle.BackgroundTransparency = INNER_TRANSPARENCY
	innerCircle.BorderSizePixel = 0
	innerCircle.Active = false
	innerCircle.ZIndex = visualRoot.ZIndex + 1
	innerCircle.Parent = visualRoot
	addCircleCorner(innerCircle)

	-- Soft inner highlight ring.
	addStroke(
		innerCircle,
		INNER_STROKE_COLOR,
		INNER_STROKE_THICKNESS,
		INNER_STROKE_TRANSPARENCY
	)

	if SHOW_TAP_TEXT then
		tapLabel = Instance.new("TextLabel")
		tapLabel.Name = "TapText"
		tapLabel.BackgroundTransparency = 1
		tapLabel.Size = UDim2.fromScale(1, 1)
		tapLabel.Font = Enum.Font.GothamBold
		tapLabel.Text = TAP_TEXT
		tapLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		tapLabel.TextSize = TAP_TEXT_SIZE
		tapLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		tapLabel.TextStrokeTransparency = 0.45
		tapLabel.TextXAlignment = Enum.TextXAlignment.Center
		tapLabel.TextYAlignment = Enum.TextYAlignment.Center
		tapLabel.Active = false
		tapLabel.ZIndex = innerCircle.ZIndex + 1
		tapLabel.Parent = innerCircle
	end

	updateEnabledLook()
end

local function patchButton(button)
	if patchedButton == button
		and button:FindFirstChild("CodeCircleVisual")
	then
		return
	end

	patchedButton = button
	hideOldButtonVisual(button)
	buildVisual(button)

	button.ChildAdded:Connect(function()
		task.defer(function()
			if button.Parent then
				hideOldButtonVisual(button)
			end
		end)
	end)

	button:GetPropertyChangedSignal(
		"BackgroundTransparency"
	):Connect(function()
		if button.BackgroundTransparency ~= 1 then
			button.BackgroundTransparency = 1
		end
	end)

	if button:IsA("TextButton") then
		button:GetPropertyChangedSignal("Text"):Connect(function()
			button.TextTransparency = 1
			button.TextStrokeTransparency = 1
		end)
	end

	if button:IsA("ImageButton") then
		button:GetPropertyChangedSignal(
			"ImageTransparency"
		):Connect(function()
			if button.ImageTransparency ~= 1 then
				button.ImageTransparency = 1
			end
		end)
	end

	button:GetPropertyChangedSignal("Active"):Connect(
		updateEnabledLook
	)
	button:GetPropertyChangedSignal("Visible"):Connect(
		updateEnabledLook
	)

	button.InputBegan:Connect(function(input)
		if not button.Active then
			return
		end

		if input.UserInputType
			== Enum.UserInputType.MouseButton1
			or input.UserInputType
			== Enum.UserInputType.Touch
		then
			tweenPressed(true)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType
			== Enum.UserInputType.MouseButton1
			or input.UserInputType
			== Enum.UserInputType.Touch
		then
			tweenPressed(false)
		end
	end)

	button.MouseLeave:Connect(function()
		tweenPressed(false)
	end)

	print(
		"[TapButtonCodeCircle] Patched:",
		button:GetFullName()
	)
end

disableOldTapVisualScripts()

-- Wait until FishingClient/HudControls creates the original Tap button.
task.spawn(function()
	while true do
		local button = findTapButton()

		if button then
			patchButton(button)
			break
		end

		task.wait(0.20)
	end
end)

-- Recover safely if the original button is recreated.
task.spawn(function()
	while true do
		task.wait(0.25)

		if patchedButton and patchedButton.Parent then
			hideOldButtonVisual(patchedButton)
			updateEnabledLook()
		else
			patchedButton = nil
			visualRoot = nil
			pressScale = nil
			innerCircle = nil
			tapLabel = nil

			local button = findTapButton()
			if button then
				patchButton(button)
			end
		end
	end
end)

print("[TapButtonCodeCircle] Transparent V2 loaded.")
