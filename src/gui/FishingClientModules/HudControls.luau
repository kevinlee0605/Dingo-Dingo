local SoundService = game:GetService("SoundService")

local HudControls = {}

function HudControls.create(deps)
	print("HudControls creating HUD")

	local root = deps.root
	local screenGui = deps.screenGui
	local makeText = deps.makeText
	local makeButton = deps.makeButton
	local addCorner = deps.addCorner
	local addStroke = deps.addStroke
	local addGradient = deps.addGradient
	local setCornerRadius = deps.setCornerRadius
	local limitTextSize = deps.limitTextSize
	local forcePureWhiteText = deps.forcePureWhiteText
	local addGloss = deps.addGloss
	local maxLevel = tonumber(deps.maxLevel) or 30

	local refs = {}

	local function formatNumber(value)
		local number = math.floor(tonumber(value) or 0)
		local sign = number < 0 and "-" or ""
		local digits = tostring(math.abs(number))
		local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		return sign .. formatted
	end

	do
		local CoinsHud = Instance.new("Frame")
		CoinsHud.Name = "CoinsHud"
		CoinsHud.AnchorPoint = Vector2.new(0, 0)
		CoinsHud.Position = UDim2.fromScale(0.02, 0.10)
		CoinsHud.Size = UDim2.new(0, 230, 0, 52)
		CoinsHud.BackgroundColor3 = Color3.fromRGB(255, 205, 58)
		CoinsHud.BackgroundTransparency = 0
		CoinsHud.Visible = true
		CoinsHud.ZIndex = 1000
		CoinsHud.Parent = screenGui
		print("CoinsHud parent:", CoinsHud.Parent)
		print("CoinsHud created", CoinsHud.AbsolutePosition, CoinsHud.AbsoluteSize)
		task.defer(function()
			print("CoinsHud created", CoinsHud.AbsolutePosition, CoinsHud.AbsoluteSize)
		end)
		addCorner(CoinsHud, 8)
		addStroke(CoinsHud, Color3.fromRGB(0, 0, 0), 3).Transparency = 0

		local coinIcon = makeText(CoinsHud, "$", 22, Color3.fromRGB(31, 22, 0), true)
		coinIcon.Name = "CoinIcon"
		coinIcon.Position = UDim2.new(0, 12, 0, 0)
		coinIcon.Size = UDim2.new(0, 30, 1, 0)
		coinIcon.TextXAlignment = Enum.TextXAlignment.Center
		coinIcon.ZIndex = 1001

		refs.coinsText = makeText(CoinsHud, "Coins: 0", 20, Color3.fromRGB(31, 22, 0), true)
		refs.coinsText.Name = "CoinsText"
		refs.coinsText.Position = UDim2.new(0, 50, 0, 0)
		refs.coinsText.Size = UDim2.new(1, -62, 1, 0)
		refs.coinsText.TextXAlignment = Enum.TextXAlignment.Left
		refs.coinsText.ZIndex = 1001
		limitTextSize(refs.coinsText, 16, 22)

		refs.statsText = Instance.new("TextLabel")
		refs.statsText.Name = "LegacyStatsText"
		refs.statsText.BackgroundTransparency = 1
		refs.statsText.Size = UDim2.fromOffset(0, 0)
		refs.statsText.Visible = false
		refs.statsText.Parent = screenGui

		refs.statusText = Instance.new("TextLabel")
		refs.statusText.Name = "LegacyStatusText"
		refs.statusText.BackgroundTransparency = 1
		refs.statusText.Size = UDim2.fromOffset(0, 0)
		refs.statusText.Visible = false
		refs.statusText.Parent = screenGui
	end

	do
		local FishingXPBar = Instance.new("Frame")
		FishingXPBar.Name = "FishingXPBar"
		FishingXPBar.AnchorPoint = Vector2.new(0.5, 0.5)
		FishingXPBar.Position = UDim2.fromScale(0.5, 0.86)
		FishingXPBar.Size = UDim2.new(0.42, 0, 0, 56)
		FishingXPBar.BackgroundColor3 = Color3.fromRGB(8, 32, 44)
		FishingXPBar.BackgroundTransparency = 0
		FishingXPBar.Visible = true
		FishingXPBar.ZIndex = 1000
		FishingXPBar.Parent = screenGui
		print("XPBar parent:", FishingXPBar.Parent)
		print("FishingXPBar created", FishingXPBar.AbsolutePosition, FishingXPBar.AbsoluteSize)
		task.defer(function()
			print("FishingXPBar created", FishingXPBar.AbsolutePosition, FishingXPBar.AbsoluteSize)
		end)
		addCorner(FishingXPBar, 8)
		addStroke(FishingXPBar, Color3.fromRGB(0, 0, 0), 3).Transparency = 0

		local xpConstraint = Instance.new("UISizeConstraint")
		xpConstraint.MinSize = Vector2.new(300, 48)
		xpConstraint.MaxSize = Vector2.new(560, 64)
		xpConstraint.Parent = FishingXPBar

		refs.xpLevelText = makeText(FishingXPBar, "Level 1", 17, Color3.fromRGB(224, 246, 255), true)
		refs.xpLevelText.Name = "XPLevelText"
		refs.xpLevelText.AnchorPoint = Vector2.new(0.5, 0)
		refs.xpLevelText.Position = UDim2.new(0.5, 0, 0, 3)
		refs.xpLevelText.Size = UDim2.new(1, -16, 0, 20)
		refs.xpLevelText.TextXAlignment = Enum.TextXAlignment.Center
		refs.xpLevelText.ZIndex = 1001
		limitTextSize(refs.xpLevelText, 13, 18)

		local track = Instance.new("Frame")
		track.Name = "XPTrack"
		track.Position = UDim2.new(0, 12, 0, 28)
		track.Size = UDim2.new(1, -24, 0, 22)
		track.BackgroundColor3 = Color3.fromRGB(2, 8, 14)
		track.ZIndex = 1001
		track.Parent = FishingXPBar
		addCorner(track, 4)
		addStroke(track, Color3.fromRGB(10, 16, 24), 2)

		refs.xpFill = Instance.new("Frame")
		refs.xpFill.Name = "XPFill"
		refs.xpFill.Size = UDim2.new(0, 0, 1, 0)
		refs.xpFill.BackgroundColor3 = Color3.fromRGB(70, 207, 120)
		refs.xpFill.ZIndex = 1002
		refs.xpFill.Parent = track
		addCorner(refs.xpFill, 4)
		addGradient(refs.xpFill, Color3.fromRGB(84, 228, 140), Color3.fromRGB(49, 170, 232), 0)

		refs.xpProgressText = makeText(track, "0 / 100 XP", 14, Color3.fromRGB(245, 252, 255), true)
		refs.xpProgressText.Name = "XPProgressText"
		refs.xpProgressText.Size = UDim2.fromScale(1, 1)
		refs.xpProgressText.TextXAlignment = Enum.TextXAlignment.Center
		refs.xpProgressText.ZIndex = 1003
		limitTextSize(refs.xpProgressText, 12, 15)
	end

	do
		local topHudButtons = Instance.new("Frame")
		topHudButtons.Name = "TopButtonsFrame"
		topHudButtons.AnchorPoint = Vector2.new(0.5, 0)
		topHudButtons.Position = UDim2.fromScale(0.5, 0.03)
		topHudButtons.Size = UDim2.new(0, 390, 0, 64)
		topHudButtons.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		topHudButtons.BackgroundTransparency = 0.35
		topHudButtons.Visible = true
		topHudButtons.ZIndex = 1000
		topHudButtons.Parent = screenGui
		print("TopButtonsFrame created")

		local topHudScale = Instance.new("UIScale")
		topHudScale.Scale = 1
		topHudScale.Parent = topHudButtons

		local topHudConstraint = Instance.new("UISizeConstraint")
		topHudConstraint.MinSize = Vector2.new(320, 54)
		topHudConstraint.MaxSize = Vector2.new(430, 72)
		topHudConstraint.Parent = topHudButtons

		local topHudLayout = Instance.new("UIListLayout")
		topHudLayout.FillDirection = Enum.FillDirection.Horizontal
		topHudLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		topHudLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		topHudLayout.Padding = UDim.new(0, 14)
		topHudLayout.SortOrder = Enum.SortOrder.LayoutOrder
		topHudLayout.Parent = topHudButtons

		local function makeTopHudButton(name, label, topColor, bottomColor)
			local button = makeButton(topHudButtons, label, Color3.fromRGB(248, 250, 252))
			button.Name = name
			button.Size = UDim2.new(0, 112, 0, 54)
			button.TextColor3 = Color3.fromRGB(13, 20, 31)
			button.TextScaled = true
			button.Visible = true
			button.ZIndex = 1001
			setCornerRadius(button, 12)
			limitTextSize(button, 13, 20)
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Color3.fromRGB(0, 0, 0)
				stroke.Thickness = 2
				stroke.Transparency = 0
			end
			addGradient(button, topColor, bottomColor, 90)
			return button
		end

		refs.settingsButton = makeTopHudButton("SettingsButton", "Settings", Color3.fromRGB(255, 255, 255), Color3.fromRGB(228, 236, 245))
		print("SettingsButton created")
		refs.questsButton = makeTopHudButton("QuestsButton", "Quests", Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 238, 196))
		print("QuestsButton created")
		refs.shopButton = makeTopHudButton("ShopButton", "Shop", Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 243, 255))
		print("ShopButton created")

		local settingsOverlay = Instance.new("Frame")
		settingsOverlay.Name = "SettingsOverlay"
		settingsOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		settingsOverlay.BackgroundTransparency = 0.4
		settingsOverlay.Size = UDim2.fromScale(1, 1)
		settingsOverlay.Visible = false
		settingsOverlay.ZIndex = 85
		settingsOverlay.Parent = root

		local settingsPanel = Instance.new("Frame")
		settingsPanel.Name = "SettingsPanel"
		settingsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
		settingsPanel.Position = UDim2.fromScale(0.5, 0.5)
		settingsPanel.Size = UDim2.new(0.3, 0, 0.34, 0)
		settingsPanel.BackgroundColor3 = Color3.fromRGB(18, 22, 29)
		settingsPanel.ZIndex = 86
		settingsPanel.Parent = settingsOverlay
		addCorner(settingsPanel, 8)
		addStroke(settingsPanel, Color3.fromRGB(71, 85, 105), 1)

		local settingsConstraint = Instance.new("UISizeConstraint")
		settingsConstraint.MinSize = Vector2.new(280, 230)
		settingsConstraint.MaxSize = Vector2.new(380, 290)
		settingsConstraint.Parent = settingsPanel

		local settingsTitle = makeText(settingsPanel, "Settings", 20, Color3.fromRGB(255, 255, 255), true)
		settingsTitle.Position = UDim2.new(0, 18, 0, 12)
		settingsTitle.Size = UDim2.new(1, -84, 0, 30)
		settingsTitle.ZIndex = 87

		local settingsClose = makeButton(settingsPanel, "X", Color3.fromRGB(91, 104, 124))
		settingsClose.Position = UDim2.new(1, -50, 0, 12)
		settingsClose.Size = UDim2.new(0, 32, 0, 30)
		settingsClose.ZIndex = 87

		local settingsList = Instance.new("Frame")
		settingsList.Name = "SettingsList"
		settingsList.Position = UDim2.new(0, 18, 0, 62)
		settingsList.Size = UDim2.new(1, -36, 1, -80)
		settingsList.BackgroundTransparency = 1
		settingsList.ZIndex = 87
		settingsList.Parent = settingsPanel

		local settingsLayout = Instance.new("UIListLayout")
		settingsLayout.Padding = UDim.new(0, 12)
		settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		settingsLayout.Parent = settingsList

		local musicEnabled = true
		local sfxEnabled = true
		local musicToggle = makeButton(settingsList, "Music: ON", Color3.fromRGB(53, 130, 246))
		musicToggle.Size = UDim2.new(1, 0, 0, 46)
		musicToggle.ZIndex = 88
		local sfxToggle = makeButton(settingsList, "SFX: ON", Color3.fromRGB(53, 130, 246))
		sfxToggle.Size = UDim2.new(1, 0, 0, 46)
		sfxToggle.ZIndex = 88

		local function isMusicSound(sound)
			local lowered = string.lower(sound.Name)
			return string.find(lowered, "music") ~= nil
				or string.find(lowered, "theme") ~= nil
				or string.find(lowered, "bgm") ~= nil
		end

		local function getOriginalSoundVolume(sound)
			local saved = sound:GetAttribute("FishyFishOriginalVolume")
			if type(saved) ~= "number" then
				saved = sound.Volume
				sound:SetAttribute("FishyFishOriginalVolume", saved)
			end
			return saved
		end

		local function refreshSettingsButtons()
			musicToggle.Text = musicEnabled and "Music: ON" or "Music: OFF"
			sfxToggle.Text = sfxEnabled and "SFX: ON" or "SFX: OFF"
			musicToggle.BackgroundColor3 = musicEnabled and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(91, 104, 124)
			sfxToggle.BackgroundColor3 = sfxEnabled and Color3.fromRGB(53, 130, 246) or Color3.fromRGB(91, 104, 124)
		end

		local function applyAudioSettings()
			for _, descendant in ipairs(SoundService:GetDescendants()) do
				if descendant:IsA("Sound") then
					local originalVolume = getOriginalSoundVolume(descendant)
					if isMusicSound(descendant) then
						descendant.Volume = musicEnabled and originalVolume or 0
					else
						descendant.Volume = sfxEnabled and originalVolume or 0
					end
				end
			end
		end

		refs.setSettingsVisible = function(visible)
			settingsOverlay.Visible = visible
		end

		settingsClose.MouseButton1Click:Connect(function()
			refs.setSettingsVisible(false)
		end)

		musicToggle.MouseButton1Click:Connect(function()
			musicEnabled = not musicEnabled
			applyAudioSettings()
			refreshSettingsButtons()
		end)

		sfxToggle.MouseButton1Click:Connect(function()
			sfxEnabled = not sfxEnabled
			applyAudioSettings()
			refreshSettingsButtons()
		end)

		SoundService.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Sound") then
				task.defer(applyAudioSettings)
			end
		end)

		refreshSettingsButtons()
	end

	print("New HUD loaded:", deps.scriptFullName)

	do
		refs.centerControls = Instance.new("Frame")
		refs.centerControls.Name = "BottomButtonsFrame"
		refs.centerControls.AnchorPoint = Vector2.new(0.5, 0.5)
		refs.centerControls.Position = UDim2.fromScale(0.5, 0.78)
		refs.centerControls.Size = UDim2.fromScale(1, 0.2)
		refs.centerControls.BackgroundTransparency = 1
		refs.centerControls.Visible = true
		refs.centerControls.ZIndex = 1000
		refs.centerControls.Parent = screenGui

		local centerControlsScale = Instance.new("UIScale")
		centerControlsScale.Scale = 1
		centerControlsScale.Parent = refs.centerControls

		refs.centerTitle = makeText(refs.centerControls, "Lilyshore Island", 15, Color3.fromRGB(230, 238, 248), true)
		refs.centerTitle.AnchorPoint = Vector2.new(0.5, 0.5)
		refs.centerTitle.Position = UDim2.fromScale(0.55, 0.10)
		refs.centerTitle.Size = UDim2.new(0.28, 0, 0, 22)
		refs.centerTitle.BackgroundTransparency = 1
		refs.centerTitle.ZIndex = 1001
		refs.centerTitle.Visible = false
		refs.centerTitle.TextXAlignment = Enum.TextXAlignment.Center
		limitTextSize(refs.centerTitle, 12, 16)

		refs.centerAutoButton = makeButton(refs.centerControls, "AutoFish OFF", Color3.fromRGB(53, 130, 246))
		refs.centerAutoButton.Name = "AutoFishButton"
		refs.centerAutoButton.AnchorPoint = Vector2.new(0.5, 0.5)
		refs.centerAutoButton.Position = UDim2.fromScale(0.18, 0.5)
		refs.centerAutoButton.Size = UDim2.new(0.22, 0, 0, 82)
		refs.centerAutoButton.Visible = true
		refs.centerAutoButton.ZIndex = 1001
		refs.centerAutoButton.TextScaled = true
		limitTextSize(refs.centerAutoButton, 16, 28)
		forcePureWhiteText(refs.centerAutoButton)
		setCornerRadius(refs.centerAutoButton, 20)
		addStroke(refs.centerAutoButton, Color3.fromRGB(0, 58, 147), 5)
		refs.centerAutoGradient = addGradient(refs.centerAutoButton, Color3.fromRGB(49, 188, 255), Color3.fromRGB(5, 84, 166), 90)
		addGloss(refs.centerAutoButton, UDim2.new(0, 18, 0, 10), UDim2.new(0, 84, 0, 9))
		print("AutoFishButton created")

		local centerAutoConstraint = Instance.new("UISizeConstraint")
		centerAutoConstraint.MinSize = Vector2.new(166, 58)
		centerAutoConstraint.MaxSize = Vector2.new(255, 88)
		centerAutoConstraint.Parent = refs.centerAutoButton

		refs.centerCastButton = makeButton(refs.centerControls, "Tap", Color3.fromRGB(82, 186, 236))
		refs.centerCastButton.Name = "TapButton"
		refs.centerCastButton.AnchorPoint = Vector2.new(0.5, 0.5)
		refs.centerCastButton.Position = UDim2.fromScale(0.55, 0.5)
		refs.centerCastButton.Size = UDim2.new(0.24, 0, 0, 76)
		refs.centerCastButton.Visible = true
		refs.centerCastButton.ZIndex = 1001
		refs.centerCastButton.TextColor3 = Color3.fromRGB(10, 20, 30)
		refs.centerCastButton.TextScaled = true
		limitTextSize(refs.centerCastButton, 18, 26)
		setCornerRadius(refs.centerCastButton, 24)
		addGradient(refs.centerCastButton, Color3.fromRGB(98, 198, 242), Color3.fromRGB(68, 174, 226), 90)
		print("TapButton created")

		local centerCastConstraint = Instance.new("UISizeConstraint")
		centerCastConstraint.MinSize = Vector2.new(178, 58)
		centerCastConstraint.MaxSize = Vector2.new(315, 90)
		centerCastConstraint.Parent = refs.centerCastButton

		refs.centerBaitText = makeText(refs.centerControls, "Bait: Basic Bait (Unlimited)", 13, Color3.fromRGB(210, 230, 255), true)
		refs.centerBaitText.AnchorPoint = Vector2.new(0.5, 0.5)
		refs.centerBaitText.Position = UDim2.fromScale(0.55, 0.1)
		refs.centerBaitText.Size = UDim2.new(0.34, 0, 0, 20)
		refs.centerBaitText.TextXAlignment = Enum.TextXAlignment.Center
		refs.centerBaitText.ZIndex = 1001
		refs.centerBaitText.Visible = false
	end

	function refs.updateCoins(coins)
		refs.coinsText.Text = "Coins: " .. formatNumber(coins)
	end

	function refs.updateXP(data)
		if not data then
			refs.xpLevelText.Text = "Level 1"
			refs.xpProgressText.Text = "0 / 100 XP"
			refs.xpFill.Size = UDim2.new(0, 0, 1, 0)
			return
		end

		local level = math.clamp(math.floor(tonumber(data and data.Level) or 1), 1, maxLevel)
		local progressXP = math.max(0, math.floor(tonumber(data and data.LevelProgressXP) or 0))
		local nextXP = math.max(0, math.floor(tonumber(data and data.NextLevelXP) or 0))
		local isMax = level >= maxLevel or nextXP <= 0

		if isMax then
			refs.xpLevelText.Text = string.format("Level %d MAX", level)
			refs.xpProgressText.Text = "MAX"
			refs.xpFill.Size = UDim2.new(1, 0, 1, 0)
		else
			local fill = math.clamp(progressXP / math.max(1, nextXP), 0, 1)
			refs.xpLevelText.Text = string.format("Level %d", level)
			refs.xpProgressText.Text = string.format("%s / %s XP", formatNumber(progressXP), formatNumber(nextXP))
			refs.xpFill.Size = UDim2.new(fill, 0, 1, 0)
		end
	end

	refs.updateCoins(0)
	refs.updateXP(nil)

	return refs
end

return HudControls
