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
local seaStarDigitsHolder = nil
local seaStarDigitsScale = nil
local seaStarPreviewSlot = nil
local boundThemeLocks = setmetatable({}, { __mode = "k" })

-- Match the coin readout and leave room for the outlined glyph edges.
local DIGIT_WIDTH = 28
local COMMA_WIDTH = 15
local DIGIT_HEIGHT = 72
local SEA_STAR_NUMBER_AREA_WIDTH = 240
local GLYPH_HORIZONTAL_PADDING = 3

local SHORT_THEME_LABELS = {
	ModernGlass = { modern = true },
	DeepOcean = { deep = true },
	JapaneseKoiPond = { japanese = true },
	AncientRuins = { ancient = true },
}
local AQUARIUM_THEME_TEXT_SIZE = 18

local function formatNumber(value)
	local number = math.max(0, math.floor(tonumber(value) or 0))
	local digits = tostring(number)
	return digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function characterWidth(character)
	return character == "," and COMMA_WIDTH or DIGIT_WIDTH
end

local function renderSeaStarDigits(value)
	if not seaStarDigitsHolder or not seaStarDigitsHolder.Parent
		or not seaStarPreviewSlot or not seaStarPreviewSlot.Parent then
		return
	end

	for _, child in ipairs(seaStarDigitsHolder:GetChildren()) do
		if child.Name == "DigitSlot" then
			child:Destroy()
		elseif string.match(child.Name, "^EditorPreviewDigit") then
			child.Visible = false
		end
	end

	local formatted = formatNumber(value)
	local totalWidth = 0
	for index = 1, #formatted do
		totalWidth += characterWidth(string.sub(formatted, index, index))
	end
	seaStarDigitsHolder.Size = UDim2.fromOffset(totalWidth, DIGIT_HEIGHT)
	if seaStarDigitsScale then
		seaStarDigitsScale.Scale = totalWidth > SEA_STAR_NUMBER_AREA_WIDTH
			and SEA_STAR_NUMBER_AREA_WIDTH / totalWidth
			or 1
	end

	local xOffset = 0
	for index = 1, #formatted do
		local character = string.sub(formatted, index, index)
		local width = characterWidth(character)
		local slot = seaStarPreviewSlot:Clone()
		slot.Name = "DigitSlot"
		-- Match the coin readout: preserve the glyph center while giving its
		-- outline room beyond the otherwise clipped rolling-digit slot.
		slot.Position = UDim2.fromOffset(xOffset - GLYPH_HORIZONTAL_PADDING, 0)
		slot.Size = UDim2.fromOffset(
			width + GLYPH_HORIZONTAL_PADDING * 2,
			DIGIT_HEIGHT
		)
		slot.Visible = true
		slot.Parent = seaStarDigitsHolder

		local label = slot:FindFirstChild("PreviewCharacter")
		if label and label:IsA("TextLabel") then
			label.Name = "Character"
			label.Text = character
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.Visible = true
		end
		xOffset += width
	end
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

local function mountSeaStarsHud()
	local fishingGui = playerGui:FindFirstChild("FishingGui")
	if not fishingGui or fishingGui:GetAttribute("AuthoredUiV2") ~= true then
		return false
	end

	local authoredHud = fishingGui:FindFirstChild("SeaStarsHud")
	if not authoredHud or not authoredHud:IsA("GuiObject") then
		return false
	end

	local authoredText = authoredHud:FindFirstChild("SeaStarsText")
	local coinStyle = authoredHud:FindFirstChild("SeaStarCoinStyleVisual")
	local numberArea = coinStyle and coinStyle:FindFirstChild("NumberArea")
	local digitsHolder = numberArea and numberArea:FindFirstChild("DigitsHolder")
	local digitsScale = digitsHolder and digitsHolder:FindFirstChild("DigitsScale")
	local previewSlot = digitsHolder and digitsHolder:FindFirstChild("PreviewDigitSlot")
	if not authoredText or not authoredText:IsA("TextLabel")
		or not digitsHolder or not digitsHolder:IsA("Frame")
		or not digitsScale or not digitsScale:IsA("UIScale")
		or not previewSlot or not previewSlot:IsA("Frame")
	then
		seaStarsText = nil
		seaStarDigitsHolder = nil
		seaStarDigitsScale = nil
		seaStarPreviewSlot = nil
		return false
	end

	authoredHud.Visible = true
	seaStarsText = authoredText
	seaStarDigitsHolder = digitsHolder
	seaStarDigitsScale = digitsScale
	seaStarPreviewSlot = previewSlot
	previewSlot.Visible = false
	return true
end

local function updateSeaStarsHud()
	if not seaStarsText or not seaStarsText.Parent then
		mountSeaStarsHud()
	end
	if seaStarsText then
		local value = state and state.SeaStars or 0
		seaStarsText.Text = formatNumber(value)
		renderSeaStarDigits(value)
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
		button.TextScaled = false
		button.TextSize = AQUARIUM_THEME_TEXT_SIZE
		button.TextWrapped = true
		return fullName
	end

	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("TextLabel") and not descendant:FindFirstAncestor("SeaStarThemeLock") then
			descendant.Text = fullName
			descendant.TextScaled = false
			descendant.TextSize = AQUARIUM_THEME_TEXT_SIZE
			descendant.TextWrapped = true
			local constraint = descendant:FindFirstChild("SeaStarThemeTextConstraint")
			if constraint and constraint:IsA("UITextSizeConstraint") then
				constraint.MinTextSize = AQUARIUM_THEME_TEXT_SIZE
				constraint.MaxTextSize = AQUARIUM_THEME_TEXT_SIZE
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
	local overlay = button:FindFirstChild("SeaStarThemeLock")
	if overlay and not overlay:IsA("TextButton") then
		overlay = nil
	end

	if theme.free == true then
		if overlay then
			overlay.Visible = false
		end
		return
	end

	button:SetAttribute("SeaStarThemeId", themeId)
	if not overlay then
		return
	end

	local owned = state and state.SeaStarUnlocks and state.SeaStarUnlocks[themeId] == true
	if owned then
		overlay.Visible = false
		return
	end

	overlay.Text = fullName .. "\nLOCK  " .. formatNumber(theme.seaStarPrice or 0)
	overlay.Visible = true
	if not boundThemeLocks[overlay] then
		boundThemeLocks[overlay] = true
		overlay.Activated:Connect(function()
			ShopAction:FireServer("PurchaseAquariumTheme", "AquariumTheme", themeId)
		end)
	end
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
