local TweenService = game:GetService("TweenService")

local TopButtonsHud = {}

-- Top HUD icon asset IDs
local SETTINGS_ICON = "rbxassetid://124685242228377"
local QUESTS_ICON = "rbxassetid://102051949478203"
local SHOP_ICON = "rbxassetid://140502313228532"

-- 여기만 수정하면 상단 버튼 기본 UI를 바꿀 수 있음.
-- 단, 지금 네 프로젝트는 ForceTopHudPosition LocalScript가 위치/크기를 한 번 더 강제 관리하고 있음.
local TOP_BUTTONS_Y_OFFSET = 2
local TOP_BUTTONS_FRAME_SIZE = UDim2.new(0, 220, 0, 64)
local TOP_BUTTON_SIZE = UDim2.new(0, 58, 0, 58)
local TOP_BUTTON_PADDING = 14
local ICON_NORMAL_SIZE = UDim2.fromScale(0.82, 0.82)
local ICON_PRESSED_SIZE = UDim2.fromScale(0.74, 0.74)
local SHADOW_NORMAL_SIZE = UDim2.fromScale(0.82, 0.82)
local SHADOW_PRESSED_SIZE = UDim2.fromScale(0.76, 0.76)
local SHADOW_TRANSPARENCY = 0.55
local SHADOW_PRESSED_TRANSPARENCY = 0.43

function TopButtonsHud.create(deps, refs)
	local screenGui = deps.screenGui

	local topHudButtons = Instance.new("Frame")
	topHudButtons.Name = "TopButtonsFrame"
	topHudButtons.Size = TOP_BUTTONS_FRAME_SIZE

	local function forceTopButtonsPosition()
		topHudButtons.AnchorPoint = Vector2.new(0.5, 0)
		topHudButtons.Position = UDim2.new(0.5, 0, 0, TOP_BUTTONS_Y_OFFSET)
	end

	forceTopButtonsPosition()

	topHudButtons:GetPropertyChangedSignal("Position"):Connect(function()
		if topHudButtons.Position ~= UDim2.new(0.5, 0, 0, TOP_BUTTONS_Y_OFFSET) then
			forceTopButtonsPosition()
		end
	end)

	task.spawn(function()
		for _ = 1, 30 do
			forceTopButtonsPosition()
			task.wait(0.1)
		end
	end)

	topHudButtons.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	topHudButtons.BackgroundTransparency = 1
	topHudButtons.ClipsDescendants = false
	topHudButtons.Visible = true
	topHudButtons.ZIndex = 1000
	topHudButtons.Parent = screenGui
	print("[HudControls] TopButtonsFrame created:", topHudButtons:GetFullName())

	local topHudScale = Instance.new("UIScale")
	topHudScale.Scale = 1
	topHudScale.Parent = topHudButtons

	local topHudConstraint = Instance.new("UISizeConstraint")
	topHudConstraint.MinSize = Vector2.new(190, 54)
	topHudConstraint.MaxSize = Vector2.new(260, 72)
	topHudConstraint.Parent = topHudButtons

	local topHudLayout = Instance.new("UIListLayout")
	topHudLayout.FillDirection = Enum.FillDirection.Horizontal
	topHudLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topHudLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topHudLayout.Padding = UDim.new(0, TOP_BUTTON_PADDING)
	topHudLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topHudLayout.Parent = topHudButtons

	local function makeTopHudButton(name, iconId)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = TOP_BUTTON_SIZE
		button.BackgroundTransparency = 1
		button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		button.BorderSizePixel = 0
		button.Text = ""
		button.TextTransparency = 1
		button.AutoButtonColor = true
		button.Visible = true
		button.ZIndex = 1001
		button.ClipsDescendants = false
		button.Parent = topHudButtons

		local pressScale = Instance.new("UIScale")
		pressScale.Name = "PressScale"
		pressScale.Scale = 1
		pressScale.Parent = button

		local shadow = Instance.new("Frame")
		shadow.Name = "IconShadow"
		shadow.AnchorPoint = Vector2.new(0.5, 0.5)
		shadow.Position = UDim2.fromScale(0.5, 0.5)
		shadow.Size = SHADOW_NORMAL_SIZE
		shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		shadow.BackgroundTransparency = SHADOW_TRANSPARENCY
		shadow.BorderSizePixel = 0
		shadow.ZIndex = 1001
		shadow.Parent = button

		local shadowCorner = Instance.new("UICorner")
		shadowCorner.CornerRadius = UDim.new(1, 0)
		shadowCorner.Parent = shadow

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = ICON_NORMAL_SIZE
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 1002
		icon.Parent = button

		local pressTweenInfo = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local releaseTweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local isPressed = false

		local function tweenPressed(pressed)
			if isPressed == pressed then
				return
			end

			isPressed = pressed
			local tweenInfo = pressed and pressTweenInfo or releaseTweenInfo

			TweenService:Create(pressScale, tweenInfo, {
				Scale = pressed and 0.88 or 1,
			}):Play()

			TweenService:Create(icon, tweenInfo, {
				Position = pressed and UDim2.fromScale(0.5, 0.56) or UDim2.fromScale(0.5, 0.5),
				Size = pressed and ICON_PRESSED_SIZE or ICON_NORMAL_SIZE,
			}):Play()

			TweenService:Create(shadow, tweenInfo, {
				Size = pressed and SHADOW_PRESSED_SIZE or SHADOW_NORMAL_SIZE,
				BackgroundTransparency = pressed and SHADOW_PRESSED_TRANSPARENCY or SHADOW_TRANSPARENCY,
			}):Play()
		end

		button.MouseButton1Down:Connect(function()
			tweenPressed(true)
		end)

		button.MouseButton1Up:Connect(function()
			tweenPressed(false)
		end)

		button.MouseLeave:Connect(function()
			tweenPressed(false)
		end)

		button.Activated:Connect(function()
			tweenPressed(false)
		end)

		return button
	end

	local function makeNotificationBadge(parent)
		local badge = Instance.new("Frame")
		badge.Name = "NotificationBadge"
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, 5, 0, -7)
		badge.Size = UDim2.fromOffset(26, 26)
		badge.BackgroundColor3 = Color3.fromRGB(220, 20, 38)
		badge.BackgroundTransparency = 0
		badge.BorderSizePixel = 0
		badge.Visible = false
		badge.ZIndex = 1010
		badge.Parent = parent

		local badgeScale = Instance.new("UIScale")
		badgeScale.Name = "BadgeScale"
		badgeScale.Scale = 1
		badgeScale.Parent = badge

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(1, 0)
		badgeCorner.Parent = badge

		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		badgeStroke.Color = Color3.fromRGB(255, 255, 255)
		badgeStroke.Thickness = 3
		badgeStroke.Transparency = 0
		badgeStroke.Parent = badge

		local badgeText = Instance.new("TextLabel")
		badgeText.Name = "CountText"
		badgeText.BackgroundTransparency = 1
		badgeText.Size = UDim2.fromScale(1, 1)
		badgeText.Position = UDim2.fromScale(0, -0.02)
		badgeText.Text = "1"
		badgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
		badgeText.TextStrokeColor3 = Color3.fromRGB(35, 0, 0)
		badgeText.TextStrokeTransparency = 0.15
		badgeText.TextScaled = true
		badgeText.Font = Enum.Font.GothamBlack
		badgeText.ZIndex = 1011
		badgeText.Parent = badge

		local textConstraint = Instance.new("UITextSizeConstraint")
		textConstraint.MinTextSize = 12
		textConstraint.MaxTextSize = 22
		textConstraint.Parent = badgeText

		return badge, badgeText, badgeScale
	end

	refs.settingsButton = makeTopHudButton("SettingsButton", SETTINGS_ICON)
	refs.settingsButton.LayoutOrder = 1

	refs.questsButton = makeTopHudButton("QuestsButton", QUESTS_ICON)
	refs.questsButton.LayoutOrder = 2
	refs.questBadge, refs.questBadgeText, refs.questBadgeScale = makeNotificationBadge(refs.questsButton)

	refs.shopButton = makeTopHudButton("ShopButton", SHOP_ICON)
	refs.shopButton.LayoutOrder = 3

	function refs.updateQuestBadgeCount(count)
		count = math.max(0, math.floor(tonumber(count) or 0))

		if not refs.questBadge or not refs.questBadgeText then
			return
		end

		refs.questBadge.Visible = count > 0
		refs.questBadgeText.Text = count > 99 and "99+" or tostring(count)
		refs.questBadge.Size = UDim2.fromOffset(count >= 10 and 32 or 26, 26)

		if count > 0 and refs.questBadgeScale then
			refs.questBadgeScale.Scale = 1.18
			TweenService:Create(
				refs.questBadgeScale,
				TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
	end

	function refs.clearQuestBadge()
		refs.updateQuestBadgeCount(0)
	end
end

return TopButtonsHud
