-- TapButtonVisualPatch
-- Place this as a NEW LocalScript under:
-- StarterGui > FishingGui
--
-- This changes only the existing fishing-area Tap / Cast Rod button's visuals.
-- It does not replace FishingClient, HudControls, AutoFish, or the click logic.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local fishingGui = playerGui:WaitForChild("FishingGui")

-- =========================================================
-- REQUIRED: Upload TapButton_Cropped_Transparent.png to
-- Asset Manager, then paste its image ID below.
-- Example: "rbxassetid://86146745555803"
-- =========================================================
local TAP_BUTTON_IMAGE = "rbxassetid://113864703941423"

-- EASY POSITION / SIZE CONTROLS
local TAP_VISUAL_SIZE = 200
local TAP_OFFSET_X = 0
local TAP_OFFSET_Y = -7

local PRESSED_SCALE = 0.90
local DISABLED_TRANSPARENCY = 0.42

local patchedButtons = setmetatable({}, {
	__mode = "k",
})

local function normalizeText(value)
	return string.lower(
		tostring(value or "")
			:gsub("^%s+", "")
			:gsub("%s+$", "")
	)
end

local function hasValidImageId()
	local numericId = TAP_BUTTON_IMAGE:match(
		"^rbxassetid://(%d+)$"
	)

	return numericId ~= nil
		and numericId ~= "0"
end

local function hasAutoFishSibling(button)
	local parent = button.Parent
	if not parent then
		return false
	end

	for _, sibling in ipairs(parent:GetChildren()) do
		if sibling:IsA("TextButton")
			and sibling ~= button
		then
			local text = normalizeText(sibling.Text)

			if text:find("autofish", 1, true) then
				return true
			end
		end
	end

	return false
end

local function isFishingTapButton(instance)
	if not instance:IsA("TextButton") then
		return false
	end

	local text = normalizeText(instance.Text)
	local name = normalizeText(instance.Name)

	local looksLikeTap =
		text == "tap"
		or text == "cast rod"
		or text == "fishing..."
		or name:find("cast", 1, true) ~= nil
		or name:find("tap", 1, true) ~= nil

	return looksLikeTap
		and hasAutoFishSibling(instance)
end

local function hideOldButtonChild(child)
	if child.Name == "ModernTapVisual" then
		return
	end

	if child:IsA("UIStroke") then
		child.Enabled = false
	elseif child:IsA("UIGradient") then
		child.Enabled = false
	elseif child:IsA("GuiObject") then
		child.Visible = false
	end
end

local function patchButton(button)
	if patchedButtons[button]
		or button:GetAttribute("ModernTapVisualPatched")
	then
		return
	end

	if not hasValidImageId() then
		warn(
			"[TapButtonVisualPatch] Replace TAP_BUTTON_IMAGE "
				.. "with the uploaded Roblox image asset ID."
		)
		return
	end

	patchedButtons[button] = true
	button:SetAttribute(
		"ModernTapVisualPatched",
		true
	)

	-- Keep the existing TextButton and its original MouseButton1Click
	-- connection. Only hide the old rectangular artwork.
	button.BackgroundTransparency = 1
	button.TextTransparency = 1
	button.TextStrokeTransparency = 1
	button.ClipsDescendants = false

	for _, child in ipairs(button:GetChildren()) do
		hideOldButtonChild(child)
	end

	button.ChildAdded:Connect(function(child)
		task.defer(hideOldButtonChild, child)
	end)

	local visual = Instance.new("Frame")
	visual.Name = "ModernTapVisual"
	visual.AnchorPoint = Vector2.new(0.5, 0.5)
	visual.Position = UDim2.new(
		0.5,
		TAP_OFFSET_X,
		0.5,
		TAP_OFFSET_Y
	)
	visual.Size = UDim2.fromOffset(
		TAP_VISUAL_SIZE,
		TAP_VISUAL_SIZE
	)
	visual.BackgroundTransparency = 1
	visual.BorderSizePixel = 0
	visual.Active = false
	visual.ZIndex = button.ZIndex + 10
	visual.Parent = button

	local aspect = Instance.new(
		"UIAspectRatioConstraint"
	)
	aspect.AspectRatio = 1
	aspect.Parent = visual

	local visualScale = Instance.new("UIScale")
	visualScale.Name = "PressScale"
	visualScale.Scale = 1
	visualScale.Parent = visual

	local artwork = Instance.new("ImageLabel")
	artwork.Name = "TapArtwork"
	artwork.BackgroundTransparency = 1
	artwork.BorderSizePixel = 0
	artwork.Size = UDim2.fromScale(1, 1)
	artwork.Image = TAP_BUTTON_IMAGE
	artwork.ScaleType = Enum.ScaleType.Fit
	artwork.ZIndex = visual.ZIndex
	artwork.Parent = visual

	local activeTween

	local function tweenScale(targetScale)
		if activeTween then
			activeTween:Cancel()
		end

		activeTween = TweenService:Create(
			visualScale,
			TweenInfo.new(
				0.08,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				Scale = targetScale,
			}
		)
		activeTween:Play()
	end

	local function updateEnabledLook()
		local canPress =
			button.Active
			and button.AutoButtonColor

		artwork.ImageTransparency =
			canPress and 0
			or DISABLED_TRANSPARENCY
	end

	button.InputBegan:Connect(function(input)
		if not (
			button.Active
				and button.AutoButtonColor
			) then
			return
		end

		if input.UserInputType
			== Enum.UserInputType.MouseButton1
			or input.UserInputType
			== Enum.UserInputType.Touch
		then
			tweenScale(PRESSED_SCALE)
		end
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType
			== Enum.UserInputType.MouseButton1
			or input.UserInputType
			== Enum.UserInputType.Touch
		then
			tweenScale(1)
		end
	end)

	button.MouseLeave:Connect(function()
		tweenScale(1)
	end)

	button:GetPropertyChangedSignal(
		"AutoButtonColor"
	):Connect(updateEnabledLook)

	button:GetPropertyChangedSignal(
		"Active"
	):Connect(updateEnabledLook)

	-- FishingClient rewrites the button text to Tap/Fishing...
	-- during refreshes. Keep that text invisible.
	button:GetPropertyChangedSignal("Text"):Connect(
		function()
			button.TextTransparency = 1
			button.TextStrokeTransparency = 1
		end
	)

	button:GetPropertyChangedSignal(
		"BackgroundTransparency"
	):Connect(function()
		if button.BackgroundTransparency ~= 1 then
			button.BackgroundTransparency = 1
		end
	end)

	updateEnabledLook()

	print(
		"[TapButtonVisualPatch] Patched:",
		button:GetFullName()
	)
end

local function scanForTapButton()
	for _, descendant in ipairs(
		fishingGui:GetDescendants()
		) do
		if isFishingTapButton(descendant) then
			patchButton(descendant)
		end
	end
end

fishingGui.DescendantAdded:Connect(function(descendant)
	task.defer(function()
		if isFishingTapButton(descendant) then
			patchButton(descendant)
		else
			scanForTapButton()
		end
	end)
end)

scanForTapButton()

-- The original button text can change after StateUpdated,
-- so retry briefly without modifying FishingClient itself.
task.spawn(function()
	for _ = 1, 40 do
		task.wait(0.25)
		scanForTapButton()
	end
end)

print("[TapButtonVisualPatch] Loaded.")
