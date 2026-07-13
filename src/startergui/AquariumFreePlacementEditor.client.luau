local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local ShopAction = Remotes:WaitForChild("ShopAction", 10)
local StateUpdated = Remotes:WaitForChild("StateUpdated", 10)
local GetState = Remotes:WaitForChild("GetState", 10)
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MonetizationConfig"))

local existingGui = playerGui:FindFirstChild("AquariumFreePlacementGui")
if existingGui then
	existingGui:Destroy()
end

local designerConfig = MonetizationConfig.AquariumDesigner
local placementConfig = designerConfig.freePlacement or {}
local bounds = placementConfig.bounds or {}
local xMin = tonumber(bounds.xMin) or -0.42
local xMax = tonumber(bounds.xMax) or 0.42
local yMin = tonumber(bounds.yMin) or 0.08
local yMax = tonumber(bounds.yMax) or 0.82
local zMin = tonumber(bounds.zMin) or -0.42
local zMax = tonumber(bounds.zMax) or 0.42
local scaleMin = tonumber(bounds.scaleMin) or 0.55
local scaleMax = tonumber(bounds.scaleMax) or 1.35

local state = nil
local editorItems = {}
local selectedIndex = nil
local selectedDecorationId = nil
local selectedThemeId = designerConfig.defaultDesign.theme
local backdropEnabled = designerConfig.defaultDesign.backdropEnabled ~= false
local lastPointer = { x = 0, y = 0.16 }
local draggingMode = nil
local previewMode = false
local nearOwnAquarium = false
local mobileLayoutActive = false

local gui = Instance.new("ScreenGui")
gui.Name = "AquariumFreePlacementGui"
gui.DisplayOrder = 1000
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function makeLabel(parent, text, size, color, bold)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(235, 242, 255)
	label.TextSize = size or 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function makeButton(parent, text, color)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or Color3.fromRGB(53, 130, 246)
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 13
	button.TextWrapped = true
	button.Parent = parent
	addCorner(button, 7)
	return button
end

local function getOwnedPasses()
	local monetization = state and state.Monetization
	return monetization and monetization.OwnedGamePasses or {}
end

local function ownsDesignerPass()
	return getOwnedPasses().AquariumDesigner == true
end

local function canEditLoadedAquarium()
	return state and state.AquariumView and state.AquariumView.CanEdit == true
end

local function getAquariumLevel()
	return math.clamp(tonumber(state and state.Aquarium and state.Aquarium.Level) or 1, 1, 4)
end

local function getMaxFreeDecorations()
	local maxByLevel = placementConfig.maxByLevel or {}
	return math.max(0, math.floor(tonumber(maxByLevel[getAquariumLevel()]) or 0))
end

local function refreshState()
	if not GetState then
		return
	end

	local ok, result = pcall(function()
		return GetState:InvokeServer()
	end)
	if ok and type(result) == "table" then
		state = result
	end
end

if StateUpdated then
	StateUpdated.OnClientEvent:Connect(function(newState)
		if type(newState) == "table" then
			state = newState
		end
	end)
end

task.defer(refreshState)

local function findOwnAquarium()
	local world = workspace:FindFirstChild("FishyFishWorld")
	local folder = world and world:FindFirstChild("PersonalAquariums")
	if not folder then
		return nil
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("OccupantUserId") == player.UserId then
			return child
		end
	end

	return nil
end

local function getModelPosition(model)
	local base = model and model:FindFirstChild("AquariumBase", true)
	if base and base:IsA("BasePart") then
		return base.Position
	end
	if model and model.PrimaryPart then
		return model.PrimaryPart.Position
	end
	if model then
		return model:GetPivot().Position
	end
	return nil
end

local function getRootPosition()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function updateNearAquarium()
	if not canEditLoadedAquarium() then
		nearOwnAquarium = false
		return false
	end

	local aquarium = findOwnAquarium()
	local aquariumPosition = getModelPosition(aquarium)
	local rootPosition = getRootPosition()
	nearOwnAquarium = aquariumPosition ~= nil and rootPosition ~= nil and (rootPosition - aquariumPosition).Magnitude <= 72
	return nearOwnAquarium
end

local function clampItem(item)
	if type(item) ~= "table" then
		return nil
	end

	local decorationId = item.decorationId or item.id or item.decoration
	if decorationId == "None" or not designerConfig.decorations[decorationId] then
		return nil
	end

	local depth = item.z
	if depth == nil then
		depth = item.depth
	end

	return {
		decorationId = decorationId,
		x = math.clamp(tonumber(item.x) or 0, xMin, xMax),
		y = math.clamp(tonumber(item.y) or 0.16, yMin, yMax),
		z = math.clamp(tonumber(depth) or 0, zMin, zMax),
		scale = math.clamp(tonumber(item.scale) or 1, scaleMin, scaleMax),
	}
end

local function getCurrentAquariumDesign()
	local monetization = state and state.Monetization
	local current = monetization and (monetization.AquariumPreviewDesign or monetization.AquariumDesign) or nil
	current = current or designerConfig.defaultDesign

	local design = {
		theme = current.theme or designerConfig.defaultDesign.theme,
		backdropEnabled = current.backdropEnabled ~= false,
		backgroundColor = current.backgroundColor or designerConfig.defaultDesign.backgroundColor,
		lightingColor = current.lightingColor or designerConfig.defaultDesign.lightingColor,
		signText = current.signText or "",
		decorations = {},
		freeDecorations = {},
	}

	for slotId, decorationId in pairs(current.decorations or {}) do
		if designerConfig.slots[slotId] and designerConfig.decorations[decorationId] then
			design.decorations[slotId] = decorationId
		end
	end

	for _, item in ipairs(current.freeDecorations or {}) do
		local clamped = clampItem(item)
		if clamped then
			table.insert(design.freeDecorations, clamped)
		end
	end

	return design
end

local function loadEditorItemsFromState()
	editorItems = {}
	local design = getCurrentAquariumDesign()
	selectedThemeId = design.theme or designerConfig.defaultDesign.theme
	backdropEnabled = design.backdropEnabled ~= false
	local maxItems = getMaxFreeDecorations()
	for _, item in ipairs(design.freeDecorations or {}) do
		if #editorItems >= maxItems then
			break
		end
		table.insert(editorItems, item)
	end
	selectedIndex = #editorItems > 0 and 1 or nil
end

local function buildDesignFromEditor()
	local design = getCurrentAquariumDesign()
	design.theme = selectedThemeId or design.theme
	design.backdropEnabled = backdropEnabled
	design.freeDecorations = {}
	for _, item in ipairs(editorItems) do
		local clamped = clampItem(item)
		if clamped then
			table.insert(design.freeDecorations, clamped)
		end
	end
	return design
end

local function validateEditorItems()
	for index, item in ipairs(editorItems) do
		if not clampItem(item) then
			return false, "invalid decoration data at #" .. tostring(index)
		end
	end
	return true, nil
end

for _, decorationId in ipairs(designerConfig.decorationOrder or {}) do
	if decorationId ~= "None" and designerConfig.decorations[decorationId] then
		selectedDecorationId = decorationId
		break
	end
end

local openButton = makeButton(gui, "Decor Editor", Color3.fromRGB(28, 160, 92))
openButton.AnchorPoint = Vector2.new(1, 1)
openButton.Position = UDim2.new(1, -18, 1, -24)
openButton.Size = UDim2.new(0, 128, 0, 42)
openButton.Visible = false

local backButton = makeButton(gui, "Back to Editor", Color3.fromRGB(53, 130, 246))
backButton.AnchorPoint = Vector2.new(1, 1)
backButton.Position = UDim2.new(1, -18, 1, -24)
backButton.Size = UDim2.new(0, 138, 0, 42)
backButton.Visible = false

local panel = Instance.new("ScrollingFrame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.96, 0.92)
panel.BackgroundColor3 = Color3.fromRGB(15, 21, 30)
panel.BorderSizePixel = 0
panel.AutomaticCanvasSize = Enum.AutomaticSize.None
panel.CanvasSize = UDim2.fromOffset(0, 0)
panel.ClipsDescendants = true
panel.Active = true
panel.ScrollingEnabled = true
panel.ScrollBarThickness = 6
panel.ScrollingDirection = Enum.ScrollingDirection.Y
panel.ElasticBehavior = Enum.ElasticBehavior.Always
panel.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
panel.Visible = false
panel.Parent = gui
addCorner(panel, 10)
addStroke(panel, Color3.fromRGB(64, 80, 104), 1)

local panelSize = Instance.new("UISizeConstraint")
panelSize.MinSize = Vector2.new(300, 320)
panelSize.MaxSize = Vector2.new(680, 760)
panelSize.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 16)
padding.PaddingBottom = UDim.new(0, 16)
padding.PaddingLeft = UDim.new(0, 16)
padding.PaddingRight = UDim.new(0, 16)
padding.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)
layout.Parent = panel

local titleRow = Instance.new("Frame")
titleRow.LayoutOrder = 1
titleRow.BackgroundTransparency = 1
titleRow.Size = UDim2.new(1, 0, 0, 32)
titleRow.Parent = panel

local title = makeLabel(titleRow, "Aquarium Decor Editor", 18, Color3.fromRGB(255, 255, 255), true)
title.Size = UDim2.new(1, -42, 1, 0)

local closeButton = makeButton(titleRow, "X", Color3.fromRGB(86, 98, 115))
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, 0, 0, 0)
closeButton.Size = UDim2.new(0, 40, 0, 40)

local statusLabel = makeLabel(panel, "", 12, Color3.fromRGB(190, 204, 220), false)
statusLabel.LayoutOrder = 2
statusLabel.Size = UDim2.new(1, 0, 0, 30)

local previewFrame = Instance.new("Frame")
previewFrame.LayoutOrder = 3
previewFrame.Size = UDim2.new(1, 0, 0, 300)
previewFrame.BackgroundColor3 = Color3.fromRGB(31, 72, 96)
previewFrame.ClipsDescendants = true
previewFrame.Parent = panel
addCorner(previewFrame, 8)
addStroke(previewFrame, Color3.fromRGB(85, 166, 215), 1)

local previewWater = Instance.new("Frame")
previewWater.BackgroundColor3 = Color3.fromRGB(44, 151, 212)
previewWater.BackgroundTransparency = 0.15
previewWater.Position = UDim2.fromScale(0.04, 0.08)
previewWater.Size = UDim2.fromScale(0.92, 0.84)
previewWater.Parent = previewFrame
addCorner(previewWater, 6)

local markerLayer = Instance.new("Frame")
markerLayer.BackgroundTransparency = 1
markerLayer.Size = UDim2.fromScale(1, 1)
markerLayer.Parent = previewFrame

local ghostMarker = Instance.new("Frame")
ghostMarker.AnchorPoint = Vector2.new(0.5, 0.5)
ghostMarker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ghostMarker.BackgroundTransparency = 0.45
ghostMarker.Size = UDim2.fromOffset(22, 22)
ghostMarker.Visible = false
ghostMarker.Parent = previewFrame
addCorner(ghostMarker, 12)
addStroke(ghostMarker, Color3.fromRGB(255, 255, 255), 1)

local themeLabel = makeLabel(panel, "Themes", 13, Color3.fromRGB(255, 255, 255), true)
themeLabel.LayoutOrder = 4
themeLabel.Size = UDim2.new(1, 0, 0, 22)

local themeScroll = Instance.new("ScrollingFrame")
themeScroll.LayoutOrder = 5
themeScroll.Size = UDim2.new(1, 0, 0, 52)
themeScroll.BackgroundColor3 = Color3.fromRGB(21, 29, 40)
themeScroll.BorderSizePixel = 0
themeScroll.CanvasSize = UDim2.fromOffset(0, 0)
themeScroll.ScrollBarThickness = 5
themeScroll.ScrollingDirection = Enum.ScrollingDirection.X
themeScroll.ElasticBehavior = Enum.ElasticBehavior.Always
themeScroll.Active = true
themeScroll.ClipsDescendants = true
themeScroll.Parent = panel
addCorner(themeScroll, 7)

local themePadding = Instance.new("UIPadding")
themePadding.PaddingTop = UDim.new(0, 5)
themePadding.PaddingBottom = UDim.new(0, 5)
themePadding.PaddingLeft = UDim.new(0, 5)
themePadding.PaddingRight = UDim.new(0, 5)
themePadding.Parent = themeScroll

local themeLayout = Instance.new("UIListLayout")
themeLayout.FillDirection = Enum.FillDirection.Horizontal
themeLayout.SortOrder = Enum.SortOrder.LayoutOrder
themeLayout.Padding = UDim.new(0, 6)
themeLayout.Parent = themeScroll

local decorLabel = makeLabel(panel, "Decor", 13, Color3.fromRGB(255, 255, 255), true)
decorLabel.LayoutOrder = 6
decorLabel.Size = UDim2.new(1, 0, 0, 22)

local decorScroll = Instance.new("ScrollingFrame")
decorScroll.LayoutOrder = 7
decorScroll.Size = UDim2.new(1, 0, 0, 52)
decorScroll.BackgroundColor3 = Color3.fromRGB(21, 29, 40)
decorScroll.BorderSizePixel = 0
decorScroll.CanvasSize = UDim2.fromOffset(0, 0)
decorScroll.ScrollBarThickness = 5
decorScroll.ScrollingDirection = Enum.ScrollingDirection.X
decorScroll.ElasticBehavior = Enum.ElasticBehavior.Always
decorScroll.Active = true
decorScroll.ClipsDescendants = true
decorScroll.Parent = panel
addCorner(decorScroll, 7)

local decorPadding = Instance.new("UIPadding")
decorPadding.PaddingTop = UDim.new(0, 5)
decorPadding.PaddingBottom = UDim.new(0, 5)
decorPadding.PaddingLeft = UDim.new(0, 5)
decorPadding.PaddingRight = UDim.new(0, 5)
decorPadding.Parent = decorScroll

local decorLayout = Instance.new("UIListLayout")
decorLayout.FillDirection = Enum.FillDirection.Horizontal
decorLayout.SortOrder = Enum.SortOrder.LayoutOrder
decorLayout.Padding = UDim.new(0, 6)
decorLayout.Parent = decorScroll

local adjustmentLabel = makeLabel(panel, "Adjustments", 13, Color3.fromRGB(255, 255, 255), true)
adjustmentLabel.LayoutOrder = 8
adjustmentLabel.Size = UDim2.new(1, 0, 0, 22)

local adjustmentGrid = Instance.new("Frame")
adjustmentGrid.LayoutOrder = 9
adjustmentGrid.Size = UDim2.new(1, 0, 0, 86)
adjustmentGrid.BackgroundTransparency = 1
adjustmentGrid.Parent = panel

local grid = Instance.new("UIGridLayout")
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.CellSize = UDim2.new(0.333, -8, 0, 42)
grid.Parent = adjustmentGrid

local actionRow = Instance.new("Frame")
actionRow.LayoutOrder = 10
actionRow.Size = UDim2.new(1, 0, 0, 48)
actionRow.BackgroundTransparency = 1
actionRow.Parent = panel

local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionLayout.Padding = UDim.new(0, 10)
actionLayout.Parent = actionRow

local previewButton = makeButton(actionRow, "Preview", Color3.fromRGB(53, 130, 246))
previewButton.LayoutOrder = 1
previewButton.Size = UDim2.new(0, 136, 0, 44)

local applyButton = makeButton(actionRow, "Apply", Color3.fromRGB(28, 160, 92))
applyButton.LayoutOrder = 2
applyButton.Size = UDim2.new(0, 136, 0, 44)

local themeButtons = {}
local decorButtons = {}

local backdropButton = makeButton(decorScroll, "Backdrop: On", Color3.fromRGB(28, 160, 92))
backdropButton.LayoutOrder = 0
backdropButton.Size = UDim2.fromOffset(104, 30)
backdropButton.TextSize = 11

local function updateBackdropButton()
	backdropButton.Text = backdropEnabled and "Backdrop: On" or "Backdrop: Off"
	backdropButton.BackgroundColor3 = backdropEnabled and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(194, 76, 76)
end

local function updatePanelCanvas()
	local verticalPadding = padding.PaddingTop.Offset + padding.PaddingBottom.Offset
	panel.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + verticalPadding)
end

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updatePanelCanvas)

local function applyResponsiveLayout()
	local camera = workspace.CurrentCamera
	local viewportSize = camera and camera.ViewportSize or Vector2.new(900, 650)
	local shortScreen = viewportSize.Y < 620
	local veryShortScreen = viewportSize.Y < 460
	local narrowScreen = viewportSize.X < 760
	local veryNarrowScreen = viewportSize.X < 480
	mobileLayoutActive = UserInputService.TouchEnabled or narrowScreen

	panel.Size = UDim2.fromScale(narrowScreen and 0.98 or 0.94, shortScreen and 0.94 or 0.9)
	panelSize.MinSize = Vector2.new(math.min(300, viewportSize.X * 0.9), math.min(320, viewportSize.Y * 0.8))
	panelSize.MaxSize = Vector2.new(math.max(320, math.min(720, viewportSize.X * 0.96)), math.max(340, math.min(780, viewportSize.Y * 0.92)))
	panel.ScrollBarThickness = mobileLayoutActive and 8 or 6

	local sidePadding = mobileLayoutActive and 12 or 18
	padding.PaddingTop = UDim.new(0, mobileLayoutActive and 12 or 18)
	padding.PaddingBottom = UDim.new(0, mobileLayoutActive and 18 or 18)
	padding.PaddingLeft = UDim.new(0, sidePadding)
	padding.PaddingRight = UDim.new(0, sidePadding)
	layout.Padding = UDim.new(0, mobileLayoutActive and 8 or 10)

	titleRow.Size = UDim2.new(1, 0, 0, mobileLayoutActive and 48 or 42)
	title.TextSize = mobileLayoutActive and 17 or 19
	closeButton.Size = UDim2.new(0, mobileLayoutActive and 48 or 42, 0, mobileLayoutActive and 48 or 42)
	statusLabel.Size = UDim2.new(1, 0, 0, mobileLayoutActive and 50 or 30)
	statusLabel.TextSize = mobileLayoutActive and 12 or 13

	local previewHeight = 320
	if veryShortScreen then
		previewHeight = 150
	elseif shortScreen then
		previewHeight = 190
	elseif mobileLayoutActive then
		previewHeight = 240
	end
	previewFrame.Size = UDim2.new(1, 0, 0, previewHeight)
	ghostMarker.Size = UDim2.fromOffset(mobileLayoutActive and 30 or 22, mobileLayoutActive and 30 or 22)

	local selectorHeight = mobileLayoutActive and 44 or 30
	local selectorRowHeight = mobileLayoutActive and 64 or 56
	themeScroll.Size = UDim2.new(1, 0, 0, selectorRowHeight)
	decorScroll.Size = UDim2.new(1, 0, 0, selectorRowHeight)
	themeScroll.ScrollBarThickness = mobileLayoutActive and 7 or 5
	decorScroll.ScrollBarThickness = mobileLayoutActive and 7 or 5
	for _, button in pairs(themeButtons) do
		button.Size = UDim2.fromOffset(button.Size.X.Offset, selectorHeight)
		button.TextSize = mobileLayoutActive and 12 or 11
	end
	for _, button in pairs(decorButtons) do
		button.Size = UDim2.fromOffset(button.Size.X.Offset, selectorHeight)
		button.TextSize = mobileLayoutActive and 12 or 11
	end
	backdropButton.Size = UDim2.fromOffset(mobileLayoutActive and 118 or 104, selectorHeight)
	backdropButton.TextSize = mobileLayoutActive and 12 or 11

	grid.FillDirectionMaxCells = veryNarrowScreen and 2 or 3
	grid.CellSize = veryNarrowScreen and UDim2.new(0.5, -4, 0, 48) or UDim2.new(0.333, -8, 0, mobileLayoutActive and 48 or 44)
	adjustmentGrid.Size = UDim2.new(1, 0, 0, veryNarrowScreen and 160 or (mobileLayoutActive and 108 or 100))
	actionRow.Size = UDim2.new(1, 0, 0, mobileLayoutActive and 58 or 52)
	previewButton.Size = mobileLayoutActive and UDim2.new(0.5, -5, 0, 50) or UDim2.new(0, 146, 0, 46)
	applyButton.Size = mobileLayoutActive and UDim2.new(0.5, -5, 0, 50) or UDim2.new(0, 146, 0, 46)
	openButton.Size = UDim2.new(0, mobileLayoutActive and 158 or 146, 0, mobileLayoutActive and 52 or 48)
	backButton.Size = UDim2.new(0, mobileLayoutActive and 166 or 154, 0, mobileLayoutActive and 52 or 48)
	task.defer(updatePanelCanvas)
end

applyResponsiveLayout()

local function relativeToScalePosition(x, y)
	local px = (math.clamp(x, xMin, xMax) - xMin) / math.max(0.001, xMax - xMin)
	local py = (yMax - math.clamp(y, yMin, yMax)) / math.max(0.001, yMax - yMin)
	return px, py
end

local function pointerToRelative(position)
	local absolutePosition = previewFrame.AbsolutePosition
	local absoluteSize = previewFrame.AbsoluteSize
	if absoluteSize.X <= 0 or absoluteSize.Y <= 0 then
		return lastPointer.x, lastPointer.y
	end

	local px = math.clamp((position.X - absolutePosition.X) / absoluteSize.X, 0, 1)
	local py = math.clamp((position.Y - absolutePosition.Y) / absoluteSize.Y, 0, 1)
	return xMin + (px * (xMax - xMin)), yMax - (py * (yMax - yMin))
end

local function updateStatus()
	local maxItems = getMaxFreeDecorations()
	local passText = ownsDesignerPass() and "Designer Pass owned" or "Designer Pass required to save"
	local statusText = string.format("%s | Free decorations: %d/%d", passText, #editorItems, maxItems)
	if mobileLayoutActive then
		statusText ..= "\nTap a decor, tap Add, then drag its marker in the tank."
	end
	statusLabel.Text = statusText
end

local refreshMarkers
local updateThemeButtonSelection
local updateDecorButtonSelection

local function updateGhost()
	if selectedIndex ~= nil then
		ghostMarker.Visible = false
		return
	end

	local px, py = relativeToScalePosition(lastPointer.x, lastPointer.y)
	ghostMarker.Position = UDim2.fromScale(px, py)
	ghostMarker.Visible = panel.Visible and selectedDecorationId ~= nil
end

refreshMarkers = function()
	for _, child in ipairs(markerLayer:GetChildren()) do
		child:Destroy()
	end

	if selectedIndex and not editorItems[selectedIndex] then
		selectedIndex = nil
	end

	for index, item in ipairs(editorItems) do
		local decoration = designerConfig.decorations[item.decorationId]
		local px, py = relativeToScalePosition(item.x, item.y)
		local markerSize = mobileLayoutActive
			and math.clamp(30 * (tonumber(item.scale) or 1), 26, 46)
			or math.clamp(22 * (tonumber(item.scale) or 1), 15, 36)
		local marker = Instance.new("TextButton")
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.Position = UDim2.fromScale(px, py)
		marker.Size = UDim2.fromOffset(markerSize, markerSize)
		marker.BackgroundColor3 = decoration and decoration.color or Color3.fromRGB(160, 180, 190)
		marker.Text = string.sub((decoration and decoration.name) or item.decorationId, 1, 1)
		marker.TextColor3 = Color3.fromRGB(255, 255, 255)
		marker.TextSize = 12
		marker.Font = Enum.Font.GothamBold
		marker.Parent = markerLayer
		addCorner(marker, markerSize)
		addStroke(marker, index == selectedIndex and Color3.fromRGB(112, 255, 156) or Color3.fromRGB(255, 255, 255), index == selectedIndex and 2 or 1)
		marker.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				selectedIndex = index
				selectedDecorationId = item.decorationId
				draggingMode = "selected"
				lastPointer.x = item.x
				lastPointer.y = item.y
				refreshMarkers()
				updateDecorButtonSelection()
				updateGhost()
			end
		end)
	end

	updateStatus()
	updateGhost()
end

updateDecorButtonSelection = function()
	for decorationId, button in pairs(decorButtons) do
		button.BackgroundColor3 = decorationId == selectedDecorationId and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(53, 130, 246)
	end
end

updateThemeButtonSelection = function()
	for themeId, button in pairs(themeButtons) do
		button.BackgroundColor3 = themeId == selectedThemeId and Color3.fromRGB(28, 160, 92) or Color3.fromRGB(53, 130, 246)
	end
end

backdropButton.MouseButton1Click:Connect(function()
	backdropEnabled = not backdropEnabled
	updateBackdropButton()
end)

local function setSelectedItemPosition(position)
	local x, y = pointerToRelative(position)
	lastPointer.x = x
	lastPointer.y = y

	if draggingMode == "selected" and selectedIndex and editorItems[selectedIndex] then
		editorItems[selectedIndex].x = x
		editorItems[selectedIndex].y = y
		refreshMarkers()
	else
		updateGhost()
	end
end

for order, themeId in ipairs(designerConfig.themeOrder or {}) do
	local theme = designerConfig.themes[themeId]
	if theme then
		local button = makeButton(themeScroll, theme.name, Color3.fromRGB(53, 130, 246))
		button.LayoutOrder = order
		button.Size = UDim2.fromOffset(math.max(78, string.len(theme.name) * 7 + 20), 30)
		button.TextSize = 11
		button.MouseButton1Click:Connect(function()
			selectedThemeId = themeId
			updateThemeButtonSelection()
		end)
		themeButtons[themeId] = button
	end
end

themeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	themeScroll.CanvasSize = UDim2.fromOffset(themeLayout.AbsoluteContentSize.X + 16, 0)
end)
themeScroll.CanvasSize = UDim2.fromOffset(themeLayout.AbsoluteContentSize.X + 16, 0)

for order, decorationId in ipairs(designerConfig.decorationOrder or {}) do
	if decorationId ~= "None" and designerConfig.decorations[decorationId] then
		local decoration = designerConfig.decorations[decorationId]
		local button = makeButton(decorScroll, decoration.name, Color3.fromRGB(53, 130, 246))
		button.LayoutOrder = order
		button.Size = UDim2.fromOffset(math.max(78, string.len(decoration.name) * 7 + 20), 30)
		button.TextSize = 11
		button.MouseButton1Click:Connect(function()
			selectedDecorationId = decorationId
			if selectedIndex and editorItems[selectedIndex] then
				editorItems[selectedIndex].decorationId = decorationId
			end
			updateDecorButtonSelection()
			refreshMarkers()
		end)
		decorButtons[decorationId] = button
	end
end

decorLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	decorScroll.CanvasSize = UDim2.fromOffset(decorLayout.AbsoluteContentSize.X + 16, 0)
end)
decorScroll.CanvasSize = UDim2.fromOffset(decorLayout.AbsoluteContentSize.X + 16, 0)

local function getSelectedItem()
	return selectedIndex and editorItems[selectedIndex] or nil
end

local addButton = makeButton(adjustmentGrid, "Add", Color3.fromRGB(53, 130, 246))
addButton.LayoutOrder = 1
addButton.MouseButton1Click:Connect(function()
	if not selectedDecorationId then
		warn("Aquarium decor editor Add failed: no selected decoration.")
		return
	end
	if #editorItems >= getMaxFreeDecorations() then
		warn("Aquarium decor editor Add failed: no free decoration slots available at this aquarium level.")
		return
	end

	table.insert(editorItems, {
		decorationId = selectedDecorationId,
		x = lastPointer.x,
		y = lastPointer.y,
		z = 0,
		scale = 1,
	})
	selectedIndex = #editorItems
	refreshMarkers()
end)

local removeButton = makeButton(adjustmentGrid, "Remove", Color3.fromRGB(194, 76, 76))
removeButton.LayoutOrder = 2
removeButton.MouseButton1Click:Connect(function()
	if selectedIndex and editorItems[selectedIndex] then
		table.remove(editorItems, selectedIndex)
		if #editorItems == 0 then
			selectedIndex = nil
		else
			selectedIndex = math.clamp(selectedIndex, 1, #editorItems)
			selectedDecorationId = editorItems[selectedIndex].decorationId
		end
		updateDecorButtonSelection()
		refreshMarkers()
	end
end)

local forwardButton = makeButton(adjustmentGrid, "Forward", Color3.fromRGB(53, 130, 246))
forwardButton.LayoutOrder = 3
forwardButton.MouseButton1Click:Connect(function()
	local item = getSelectedItem()
	if item then
		item.z = math.clamp((tonumber(item.z) or 0) - 0.08, zMin, zMax)
		refreshMarkers()
	end
end)

local backwardButton = makeButton(adjustmentGrid, "Backward", Color3.fromRGB(53, 130, 246))
backwardButton.LayoutOrder = 4
backwardButton.MouseButton1Click:Connect(function()
	local item = getSelectedItem()
	if item then
		item.z = math.clamp((tonumber(item.z) or 0) + 0.08, zMin, zMax)
		refreshMarkers()
	end
end)

local scaleUpButton = makeButton(adjustmentGrid, "Scale +", Color3.fromRGB(53, 130, 246))
scaleUpButton.LayoutOrder = 5
scaleUpButton.MouseButton1Click:Connect(function()
	local item = getSelectedItem()
	if item then
		item.scale = math.clamp((tonumber(item.scale) or 1) + 0.1, scaleMin, scaleMax)
		refreshMarkers()
	end
end)

local scaleDownButton = makeButton(adjustmentGrid, "Scale -", Color3.fromRGB(53, 130, 246))
scaleDownButton.LayoutOrder = 6
scaleDownButton.MouseButton1Click:Connect(function()
	local item = getSelectedItem()
	if item then
		item.scale = math.clamp((tonumber(item.scale) or 1) - 0.1, scaleMin, scaleMax)
		refreshMarkers()
	end
end)

previewFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingMode = selectedIndex and "selected" or "ghost"
		setSelectedItemPosition(input.Position)
	end
end)

previewFrame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		if draggingMode then
			setSelectedItemPosition(input.Position)
		else
			local x, y = pointerToRelative(input.Position)
			lastPointer.x = x
			lastPointer.y = y
			updateGhost()
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not draggingMode then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		setSelectedItemPosition(input.Position)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingMode = nil
	end
end)

local function openEditor()
	refreshState()
	updateNearAquarium()
	if not nearOwnAquarium then
		warn("Aquarium decor editor cannot open: no personal aquarium found nearby.")
		return
	end

	previewMode = false
	loadEditorItemsFromState()
	panel.CanvasPosition = Vector2.zero
	panel.Visible = true
	openButton.Visible = false
	backButton.Visible = false
	updateThemeButtonSelection()
	updateDecorButtonSelection()
	updateBackdropButton()
	refreshMarkers()
end

local function closeEditor()
	panel.Visible = false
	draggingMode = nil
	refreshMarkers()
end

local function sendAquariumDesign(actionName)
	if not canEditLoadedAquarium() then
		warn("Aquarium " .. actionName .. " failed: current aquarium is view-only.")
		return false
	end

	if not ShopAction or not ShopAction.Parent then
		ShopAction = Remotes:FindFirstChild("ShopAction")
	end
	if not ShopAction then
		warn("Aquarium " .. actionName .. " failed: preview remote missing.")
		return false
	end
	if not findOwnAquarium() then
		warn("Aquarium " .. actionName .. " failed: no aquarium found.")
		return false
	end
	if selectedDecorationId == nil and #editorItems == 0 then
		warn("Aquarium " .. actionName .. " failed: no selected decoration.")
		return false
	end

	local ok, reason = validateEditorItems()
	if not ok then
		warn("Aquarium " .. actionName .. " failed: " .. tostring(reason or "invalid decoration data"))
		return false
	end

	ShopAction:FireServer(actionName, "Aquarium", "freeDecorations", buildDesignFromEditor())
	return true
end

previewButton.MouseButton1Click:Connect(function()
	if sendAquariumDesign("PreviewAquariumDesign") then
		previewMode = true
		panel.Visible = false
		openButton.Visible = false
		backButton.Visible = nearOwnAquarium
	end
end)

applyButton.MouseButton1Click:Connect(function()
	sendAquariumDesign("ApplyAquariumDesign")
end)

openButton.MouseButton1Click:Connect(openEditor)
backButton.MouseButton1Click:Connect(openEditor)
closeButton.MouseButton1Click:Connect(closeEditor)

local visibilityAccumulator = 0
RunService.RenderStepped:Connect(function(deltaTime)
	visibilityAccumulator += deltaTime
	if visibilityAccumulator < 0.2 then
		return
	end
	visibilityAccumulator = 0

	applyResponsiveLayout()
	updateNearAquarium()
	if not nearOwnAquarium then
		if panel.Visible then
			closeEditor()
		end
		openButton.Visible = false
		backButton.Visible = false
		return
	end

	backButton.Visible = previewMode and not panel.Visible
	openButton.Visible = not panel.Visible and not backButton.Visible
end)

updateThemeButtonSelection()
updateDecorButtonSelection()
updateBackdropButton()
refreshMarkers()
