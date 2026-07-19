local TweenService = game:GetService("TweenService")

local TopButtonsHud = {}

local SETTINGS_ICON = "rbxassetid://124685242228377"
local QUESTS_ICON = "rbxassetid://102051949478203"
local SHOP_ICON = "rbxassetid://140502313228532"
local DAILY_REWARDS_ICON = "rbxassetid://78408484505332"

local ICON_NORMAL_SIZE = UDim2.fromScale(0.82, 0.82)
local ICON_PRESSED_SIZE = UDim2.fromScale(0.74, 0.74)
local SHADOW_NORMAL_SIZE = UDim2.fromScale(0.82, 0.82)
local SHADOW_PRESSED_SIZE = UDim2.fromScale(0.76, 0.76)
local SHADOW_TRANSPARENCY = 0.55
local SHADOW_PRESSED_TRANSPARENCY = 0.43

local function requiredChild(parent, name, className)
	local child = parent:FindFirstChild(name)
	assert(
		child and child:IsA(className),
		string.format(
			"[TopButtonsHud] Expected %s.%s to be a %s",
			parent:GetFullName(),
			name,
			className
		)
	)
	return child
end

local function bindButtonTree(button)
	local pressScale = requiredChild(button, "PressScale", "UIScale")
	local shadow = requiredChild(button, "IconShadow", "Frame")
	requiredChild(shadow, "UICorner", "UICorner")
	local icon = requiredChild(button, "Icon", "ImageLabel")
	return pressScale, shadow, icon
end

function TopButtonsHud.create(deps, refs)
	assert(deps.authoredUiV2, "[TopButtonsHud] AuthoredUiV2 is required")
	assert(deps.findAuthoredHost, "[TopButtonsHud] findAuthoredHost is required")

	local topHudButtons = deps.findAuthoredHost("TopButtonsFrame", "GuiObject")
	assert(topHudButtons, "[TopButtonsHud] Missing authored TopButtonsFrame")

	-- All four always-on buttons share the authored, screen-centered row in
	-- TopHudGui. Controllers bind behavior only; they never create or reparent it.
	requiredChild(topHudButtons, "TopHudScale", "UIScale")
	requiredChild(topHudButtons, "TopButtonsSizeConstraint", "UISizeConstraint")
	requiredChild(topHudButtons, "UIListLayout", "UIListLayout")

	local settingsButton = requiredChild(topHudButtons, "SettingsButton", "TextButton")
	local settingsPressScale, settingsShadow, settingsIcon = bindButtonTree(settingsButton)
	local questsButton = requiredChild(topHudButtons, "QuestsButton", "TextButton")
	local questsPressScale, questsShadow, questsIcon = bindButtonTree(questsButton)
	local shopButton = requiredChild(topHudButtons, "ShopButton", "TextButton")
	local shopPressScale, shopShadow, shopIcon = bindButtonTree(shopButton)
	local dailyRewardsButton = requiredChild(topHudButtons, "TopLoginRewardButton", "TextButton")
	local dailyRewardsPressScale, dailyRewardsShadow, dailyRewardsIcon = bindButtonTree(dailyRewardsButton)

	settingsIcon.Image = SETTINGS_ICON
	questsIcon.Image = QUESTS_ICON
	shopIcon.Image = SHOP_ICON
	dailyRewardsIcon.Image = DAILY_REWARDS_ICON
	settingsIcon.Visible = true
	questsIcon.Visible = true
	shopIcon.Visible = true
	dailyRewardsIcon.Visible = true

	local function bindPressFeedback(button, pressScale, icon, shadow)
		local pressTweenInfo = TweenInfo.new(
			0.07,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
		local releaseTweenInfo = TweenInfo.new(
			0.16,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		)
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
				BackgroundTransparency = pressed
					and SHADOW_PRESSED_TRANSPARENCY
					or SHADOW_TRANSPARENCY,
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
	end

	bindPressFeedback(settingsButton, settingsPressScale, settingsIcon, settingsShadow)
	bindPressFeedback(questsButton, questsPressScale, questsIcon, questsShadow)
	bindPressFeedback(shopButton, shopPressScale, shopIcon, shopShadow)
	bindPressFeedback(dailyRewardsButton, dailyRewardsPressScale, dailyRewardsIcon, dailyRewardsShadow)

	refs.settingsButton = settingsButton
	refs.questsButton = questsButton
	refs.shopButton = shopButton
	refs.dailyRewardsButton = dailyRewardsButton

	-- The reference HUD has no quest notification badge. Retain the update
	-- hooks as no-ops so quest state can refresh without creating UI at runtime.
	function refs.updateQuestBadgeCount(_count) end

	function refs.clearQuestBadge()
		-- Intentionally empty: the authored reference HUD has no badge.
	end

	topHudButtons.Visible = true
end

return TopButtonsHud
