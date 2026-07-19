local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = ReplicatedStorage:WaitForChild("FishingRemotes")

local MonetizationConfig = require(shared:WaitForChild("MonetizationConfig"))
local GetState = remotes:WaitForChild("GetState")
local ShopAction = remotes:WaitForChild("ShopAction")
local StateUpdated = remotes:WaitForChild("StateUpdated")

local state = nil
local seaStarsText = nil

local SHORT_THEME_LABELS = {
	ModernGlass = { modern = true },
	DeepOcean = { deep = true },
	JapaneseKoiPond = { japanese = true },
	AncientRuins = { ancient = true },
}

local function formatNumber(value)
	local number = math.max(0, math.floor(tonumber(value) or 0))
	local digits = tostring(number)
	return digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function addCorner(parent, radius)
	local corner = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function makeText(parent, name, text, size, color, bold)
	local label = parent:FindFirstChild(name)
	if not label or not label:IsA("TextLabel") then
		label = Instance.new("TextLabel")
	end
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function getGuiButtonText(button)
	if button:IsA("TextButton") then
		return button.Text
	end
	if not button:IsA("GuiButton") then
		return nil
	end
	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("TextLabel") and descendant.Text ~= "" then
			return descendant.Text
		end
	end
	return nil
end

local function findCoinsHud()
	local fishingGui = playerGui:FindFirstChild("FishingGui")
	local direct = fishingGui and fishingGui:FindFirstChild("CoinsHud")
	if direct and direct:IsA("GuiObject") and direct.Visible then
		return direct
	end

	local fallback = nil
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("GuiObject") and descendant.Name == "CoinsHud" then
			if descendant.Visible and descendant.AbsoluteSize.X > 0 and descendant.AbsoluteSize.Y > 0 then
				return descendant
			end
			fallback = fallback or descendant
		end
	end
	return fallback
end

local function getSeaStarsHudPosition(coinsHud)
	return UDim2.new(
		coinsHud.Position.X.Scale,
		coinsHud.Position.X.Offset,
		coinsHud.Position.Y.Scale,
		coinsHud.Position.Y.Offset + math.max(48, coinsHud.AbsoluteSize.Y) - 22
	)
end

local function mountSeaStarsHud()
	local fishingGui = playerGui:FindFirstChild("FishingGui")
	if not fishingGui then
		return false
	end

	if fishingGui:GetAttribute("AuthoredUiV2") == true then
		local authoredHud = fishingGui:FindFirstChild("SeaStarsHud")
			or fishingGui:FindFirstChild("SeaStarsHud", true)
		seaStarsText = authoredHud and authoredHud:FindFirstChild("SeaStarsText", true)
		if seaStarsText and seaStarsText:IsA("TextLabel") then
			return true
		end
		seaStarsText = nil
		return false
	end

	local coinsHud = findCoinsHud()
	if not coinsHud or not coinsHud.Parent then
		return false
	end

	local hudParent = coinsHud.Parent
	local existing = hudParent:FindFirstChild("SeaStarsHud")
	if existing and existing:IsA("GuiObject") then
		existing.Position = getSeaStarsHudPosition(coinsHud)
		seaStarsText = existing:FindFirstChild("SeaStarsText", true)
		return seaStarsText ~= nil
	end

	local hud = Instance.new("Frame")
	hud.Name = "SeaStarsHud"
	hud.BackgroundTransparency = 1
	hud.BorderSizePixel = 0
	hud.ClipsDescendants = false
	hud.Size = coinsHud.Size
	hud.LayoutOrder = coinsHud.LayoutOrder + 1
	hud.ZIndex = coinsHud.ZIndex
	hud.Visible = true
	hud.Position = getSeaStarsHudPosition(coinsHud)

	local star = makeText(hud, "SeaStarIcon", "★", 48, Color3.fromRGB(255, 219, 62), true)
	star.Position = UDim2.new(0, 8, 0, -2)
	star.Size = UDim2.new(0, 70, 1, 4)
	star.TextXAlignment = Enum.TextXAlignment.Center
	star.TextYAlignment = Enum.TextYAlignment.Center
	star.TextStrokeColor3 = Color3.fromRGB(4, 35, 74)
	star.TextStrokeTransparency = 0
	star.ZIndex = hud.ZIndex + 1

	local balanceLabel = makeText(hud, "SeaStarsText", "0", 30, Color3.fromRGB(255, 255, 255), true)
	balanceLabel.Font = Enum.Font.GothamBlack
	balanceLabel.Position = UDim2.new(0, 76, 0, 1)
	balanceLabel.Size = UDim2.new(1, -78, 0.62, 0)
	balanceLabel.TextScaled = true
	balanceLabel.TextStrokeColor3 = Color3.fromRGB(3, 22, 53)
	balanceLabel.TextStrokeTransparency = 0
	balanceLabel.ZIndex = hud.ZIndex + 1
	local valueConstraint = Instance.new("UITextSizeConstraint")
	valueConstraint.MinTextSize = 14
	valueConstraint.MaxTextSize = 30
	valueConstraint.Parent = balanceLabel

	local caption = makeText(hud, "SeaStarsCaption", "SEA STARS", 12, Color3.fromRGB(91, 218, 255), true)
	caption.Position = UDim2.new(0, 78, 0.6, -2)
	caption.Size = UDim2.new(1, -80, 0.34, 0)
	caption.TextStrokeColor3 = Color3.fromRGB(3, 22, 53)
	caption.TextStrokeTransparency = 0.2
	caption.ZIndex = hud.ZIndex + 1

	seaStarsText = balanceLabel
	hud.Parent = hudParent
	return true
end

local function updateSeaStarsHud()
	if not seaStarsText or not seaStarsText.Parent then
		mountSeaStarsHud()
	end
	if seaStarsText then
		seaStarsText.Text = formatNumber(state and state.SeaStars or 0)
	end
end

local function findThemeId(button)
	local taggedThemeId = button:GetAttribute("SeaStarThemeId")
	if type(taggedThemeId) == "string" then
		local taggedTheme = MonetizationConfig.AquariumDesigner.themes[taggedThemeId]
		if taggedTheme then
			return taggedThemeId, taggedTheme
		end
	end

	local text = string.lower(getGuiButtonText(button) or "")
	if text == "" then
		return nil, nil
	end
	for _, themeId in ipairs(MonetizationConfig.AquariumDesigner.themeOrder or {}) do
		local theme = MonetizationConfig.AquariumDesigner.themes[themeId]
		local name = theme and string.lower(theme.name or theme.displayName or themeId)
		local displayName = theme and string.lower(theme.displayName or theme.name or themeId)
		local aliases = SHORT_THEME_LABELS[themeId]
		if name and (
			text == string.lower(themeId)
			or text == name
			or text == displayName
			or (aliases and aliases[text])
			or string.find(text, name, 1, true)
		) then
			return themeId, theme
		end
	end
	return nil, nil
end

local function showFullThemeName(button, theme, themeId)
	local fullName = theme.displayName or theme.name or themeId
	if button:IsA("TextButton") then
		button.Text = fullName
		button.TextScaled = true
		return fullName
	end

	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("TextLabel") and not descendant:FindFirstAncestor("SeaStarThemeLock") then
			descendant.Text = fullName
			descendant.TextScaled = true
			local constraint = descendant:FindFirstChild("SeaStarThemeTextConstraint")
			if not constraint then
				constraint = Instance.new("UITextSizeConstraint")
				constraint.Name = "SeaStarThemeTextConstraint"
				constraint.MinTextSize = 6
				constraint.MaxTextSize = 12
				constraint.Parent = descendant
			end
			break
		end
	end
	return fullName
end

local function updateThemeButton(button)
	if not button:IsA("GuiButton")
		or button.Name == "SeaStarThemeLock"
		or button:FindFirstAncestor("SeaStarThemeLock")
	then
		return
	end
	local themeId, theme = findThemeId(button)
	if not themeId or not theme then
		return
	end
	local fullName = showFullThemeName(button, theme, themeId)
	if theme.free == true then
		return
	end

	button:SetAttribute("SeaStarThemeId", themeId)
	local owned = state and state.SeaStarUnlocks and state.SeaStarUnlocks[themeId] == true
	local overlay = button:FindFirstChild("SeaStarThemeLock")
	if owned then
		if overlay then
			overlay:Destroy()
		end
		return
	end

	if overlay then
		overlay.Text = fullName .. "\nLOCK  " .. formatNumber(theme.seaStarPrice or 0)
		return
	end

	overlay = Instance.new("TextButton")
	overlay.Name = "SeaStarThemeLock"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(32, 37, 52)
	overlay.BackgroundTransparency = 0.05
	overlay.AutoButtonColor = true
	overlay.Font = Enum.Font.GothamBold
	overlay.Text = fullName .. "\nLOCK  " .. formatNumber(theme.seaStarPrice or 0)
	overlay.TextColor3 = Color3.fromRGB(255, 219, 92)
	overlay.TextScaled = true
	overlay.TextWrapped = true
	overlay.ZIndex = button.ZIndex + 20
	overlay.Parent = button
	addCorner(overlay, 6)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 5
	constraint.MaxTextSize = 10
	constraint.Parent = overlay
	overlay.Activated:Connect(function()
		ShopAction:FireServer("PurchaseAquariumTheme", "AquariumTheme", themeId)
	end)
end

local function updateThemeLocks()
	local editorGui = playerGui:FindFirstChild("AquariumFreePlacementGui")
	if not editorGui then
		return
	end
	for _, descendant in ipairs(editorGui:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			updateThemeButton(descendant)
		end
	end
end

local function receiveState(newState)
	if type(newState) ~= "table" then
		return
	end
	state = newState
	MonetizationConfig.ApplyResolvedProductIds(newState.Monetization and newState.Monetization.DeveloperProductIds)
	updateSeaStarsHud()
	updateThemeLocks()
end

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "SeaStarsHud"
		or descendant.Name == "SeaStarsText"
		or descendant.Name == "FishingGui"
	then
		task.defer(updateSeaStarsHud)
	end
	if descendant:IsA("GuiButton") or descendant:IsA("TextLabel") or descendant.Name == "AquariumFreePlacementGui" then
		task.defer(updateThemeLocks)
	end
end)

StateUpdated.OnClientEvent:Connect(receiveState)

task.spawn(function()
	for _ = 1, 100 do
		if mountSeaStarsHud() then
			break
		end
		task.wait(0.1)
	end
	updateSeaStarsHud()
	updateThemeLocks()
end)

task.spawn(function()
	local ok, initialState = pcall(function()
		return GetState:InvokeServer()
	end)
	if ok then
		receiveState(initialState)
	end
end)

print("[EconomyUIIntegration] Bound the authored Sea Stars HUD and decor theme locks.")
