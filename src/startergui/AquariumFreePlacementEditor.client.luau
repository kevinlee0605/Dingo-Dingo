local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
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
local DEPTH_LEVEL_COUNT = 7
local TAP_BLUE = Color3.fromRGB(28, 115, 235)
local PLACED_GREEN = Color3.fromRGB(24, 151, 82)
local SELECTED_CYAN = Color3.fromRGB(60, 225, 255)
local EDITOR_WHEEL_ACTION = "AquariumDecorEditorWheelCapture"
local EDITOR_PINCH_ACTION = "AquariumDecorEditorPinchCapture"

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
local pinchActive = false
local pinchStartScale = 1
local lastActiveInputType = UserInputService:GetLastInputType()

local gui = Instance.new("ScreenGui")
gui.Name = "AquariumFreePlacementGui"
gui.DisplayOrder = 5000
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
	local loadedDecorationIds = {}
	for _, item in ipairs(design.freeDecorations or {}) do
		if #editorItems >= maxItems then
			break
		end
		if not loadedDecorationIds[item.decorationId] then
			loadedDecorationIds[item.decorationId] = true
			table.insert(editorItems, item)
		end
	end
	selectedIndex = #editorItems > 0 and 1 or nil
	selectedDecorationId = selectedIndex and editorItems[selectedIndex].decorationId or nil
end

local function buildDesignFromEditor()
	local design = getCurrentAquariumDesign()
	design.theme = selectedThemeId or design.theme
	design.backdropEnabled = backdropEnabled
	design.freeDecorations = {}
	local savedDecorationIds = {}
	for _, item in ipairs(editorItems) do
		local clamped = clampItem(item)
		if clamped and not savedDecorationIds[clamped.decorationId] then
			savedDecorationIds[clamped.decorationId] = true
			table.insert(design.freeDecorations, clamped)
		end
	end
	return design
end

local function validateEditorItems()
	local foundDecorationIds = {}
	for index, item in ipairs(editorItems) do
		if not clampItem(item) then
			return false, "invalid decoration data at #" .. tostring(index)
		end
		if foundDecorationIds[item.decorationId] then
			return false, "duplicate decoration type: " .. tostring(item.decorationId)
		end
		foundDecorationIds[item.decorationId] = true
	end
	return true, nil
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

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.96, 0.92)
panel.BackgroundColor3 = Color3.fromRGB(5, 18, 42)
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Active = true
panel.Visible = false
panel.Parent = gui
addCorner(panel, 14)
addStroke(panel, Color3.fromRGB(20, 155, 255), 2)

local panelSize = Instance.new("UISizeConstraint")
panelSize.MinSize = Vector2.new(640, 360)
panelSize.MaxSize = Vector2.new(1500, 860)
panelSize.Parent = panel

local titleRow = Instance.new("Frame")
titleRow.BackgroundTransparency = 1
titleRow.Position = UDim2.fromScale(0.025, 0.018)
titleRow.Size = UDim2.fromScale(0.95, 0.11)
titleRow.Parent = panel

local title = makeLabel(titleRow, "Aquarium Decor Editor", 18, Color3.fromRGB(255, 255, 255), true)
title.Size = UDim2.new(1, -62, 0.58, 0)

local closeButton = makeButton(titleRow, "X", Color3.fromRGB(20, 80, 175))
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, 0, 0, 0)
closeButton.Size = UDim2.new(0, 48, 0, 48)
addStroke(closeButton, Color3.fromRGB(50, 205, 255), 2)

local statusLabel = makeLabel(titleRow, "", 13, Color3.fromRGB(47, 236, 255), true)
statusLabel.Position = UDim2.fromScale(0, 0.56)
statusLabel.Size = UDim2.new(1, -62, 0.4, 0)

local previewFrame = Instance.new("Frame")
previewFrame.Position = UDim2.fromScale(0.025, 0.145)
previewFrame.Size = UDim2.fromScale(0.525, 0.825)
previewFrame.BackgroundColor3 = Color3.fromRGB(8, 45, 92)
previewFrame.ClipsDescendants = true
previewFrame.Active = true
previewFrame.Parent = panel
addCorner(previewFrame, 12)
addStroke(previewFrame, Color3.fromRGB(25, 175, 255), 2)

local previewWater = Instance.new("Frame")
previewWater.BackgroundColor3 = Color3.fromRGB(44, 151, 212)
previewWater.BackgroundTransparency = 0.15
previewWater.Position = UDim2.fromScale(0.025, 0.025)
previewWater.Size = UDim2.fromScale(0.95, 0.95)
previewWater.Parent = previewFrame
addCorner(previewWater, 10)
addStroke(previewWater, Color3.fromRGB(89, 225, 255), 1)

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

local themeLabel = makeLabel(panel, "Themes", 14, Color3.fromRGB(255, 255, 255), true)
themeLabel.Position = UDim2.fromScale(0.575, 0.145)
themeLabel.Size = UDim2.fromScale(0.4, 0.042)

local themeScroll = Instance.new("ScrollingFrame")
themeScroll.Position = UDim2.fromScale(0.57, 0.19)
themeScroll.Size = UDim2.fromScale(0.405, 0.15)
themeScroll.BackgroundColor3 = Color3.fromRGB(7, 29, 65)
themeScroll.BorderSizePixel = 0
themeScroll.CanvasSize = UDim2.fromOffset(0, 0)
themeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
themeScroll.ScrollBarThickness = 4
themeScroll.ScrollingDirection = Enum.ScrollingDirection.Y
themeScroll.ElasticBehavior = Enum.ElasticBehavior.Always
themeScroll.Active = true
themeScroll.ClipsDescendants = true
themeScroll.Parent = panel
addCorner(themeScroll, 9)
addStroke(themeScroll, Color3.fromRGB(18, 105, 205), 1)

local themePadding = Instance.new("UIPadding")
themePadding.PaddingTop = UDim.new(0, 5)
themePadding.PaddingBottom = UDim.new(0, 5)
themePadding.PaddingLeft = UDim.new(0, 5)
themePadding.PaddingRight = UDim.new(0, 5)
themePadding.Parent = themeScroll

local themeLayout = Instance.new("UIGridLayout")
themeLayout.FillDirection = Enum.FillDirection.Horizontal
themeLayout.FillDirectionMaxCells = 4
themeLayout.SortOrder = Enum.SortOrder.LayoutOrder
themeLayout.CellPadding = UDim2.fromOffset(6, 6)
themeLayout.CellSize = UDim2.new(0.25, -5, 0, 36)
themeLayout.Parent = themeScroll

local decorLabel = makeLabel(panel, "Decor  (Tap a decor to place or select it)", 14, Color3.fromRGB(255, 255, 255), true)
decorLabel.Position = UDim2.fromScale(0.575, 0.355)
decorLabel.Size = UDim2.fromScale(0.4, 0.042)

local decorScroll = Instance.new("ScrollingFrame")
decorScroll.Position = UDim2.fromScale(0.57, 0.4)
decorScroll.Size = UDim2.fromScale(0.405, 0.275)
decorScroll.BackgroundColor3 = Color3.fromRGB(7, 29, 65)
decorScroll.BorderSizePixel = 0
decorScroll.CanvasSize = UDim2.fromOffset(0, 0)
decorScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
decorScroll.ScrollBarThickness = 4
decorScroll.ScrollingDirection = Enum.ScrollingDirection.Y
decorScroll.ElasticBehavior = Enum.ElasticBehavior.Always
decorScroll.Active = true
decorScroll.ClipsDescendants = true
decorScroll.Parent = panel
addCorner(decorScroll, 9)
addStroke(decorScroll, Color3.fromRGB(18, 105, 205), 1)

local decorPadding = Instance.new("UIPadding")
decorPadding.PaddingTop = UDim.new(0, 5)
decorPadding.PaddingBottom = UDim.new(0, 5)
decorPadding.PaddingLeft = UDim.new(0, 5)
decorPadding.PaddingRight = UDim.new(0, 5)
decorPadding.Parent = decorScroll

local decorLayout = Instance.new("UIGridLayout")
decorLayout.FillDirection = Enum.FillDirection.Horizontal
decorLayout.FillDirectionMaxCells = 4
decorLayout.SortOrder = Enum.SortOrder.LayoutOrder
decorLayout.CellPadding = UDim2.fromOffset(6, 6)
decorLayout.CellSize = UDim2.new(0.25, -5, 0, 46)
decorLayout.Parent = decorScroll

local adjustmentLabel = makeLabel(panel, "Adjustments", 14, Color3.fromRGB(255, 255, 255), true)
adjustmentLabel.Position = UDim2.fromScale(0.575, 0.69)
adjustmentLabel.Size = UDim2.fromScale(0.4, 0.042)

local adjustmentGrid = Instance.new("Frame")
adjustmentGrid.Position = UDim2.fromScale(0.57, 0.735)
adjustmentGrid.Size = UDim2.fromScale(0.405, 0.12)
adjustmentGrid.BackgroundColor3 = Color3.fromRGB(7, 29, 65)
adjustmentGrid.Parent = panel
addCorner(adjustmentGrid, 9)
addStroke(adjustmentGrid, Color3.fromRGB(18, 105, 205), 1)

local depthLabel = makeLabel(adjustmentGrid, "Depth (Forward / Backward)", 12, Color3.fromRGB(230, 242, 255), false)
depthLabel.Position = UDim2.fromScale(0.1, 0.02)
depthLabel.Size = UDim2.fromScale(0.8, 0.38)
depthLabel.TextXAlignment = Enum.TextXAlignment.Center

local depthLeftButton = makeButton(adjustmentGrid, "<", Color3.fromRGB(14, 74, 160))
depthLeftButton.AnchorPoint = Vector2.new(0, 0.5)
depthLeftButton.Position = UDim2.fromScale(0.02, 0.7)
depthLeftButton.Size = UDim2.fromOffset(32, 32)
addStroke(depthLeftButton, Color3.fromRGB(46, 215, 255), 1)

local depthRightButton = makeButton(adjustmentGrid, ">", Color3.fromRGB(14, 74, 160))
depthRightButton.AnchorPoint = Vector2.new(1, 0.5)
depthRightButton.Position = UDim2.fromScale(0.98, 0.7)
depthRightButton.Size = UDim2.fromOffset(32, 32)
addStroke(depthRightButton, Color3.fromRGB(46, 215, 255), 1)

local depthTrack = Instance.new("Frame")
depthTrack.AnchorPoint = Vector2.new(0.5, 0.5)
depthTrack.Position = UDim2.fromScale(0.5, 0.7)
depthTrack.Size = UDim2.new(0.75, 0, 0, 3)
depthTrack.BackgroundColor3 = Color3.fromRGB(56, 116, 205)
depthTrack.BorderSizePixel = 0
depthTrack.Parent = adjustmentGrid

local depthButtons = {}
for level = 1, DEPTH_LEVEL_COUNT do
	local dot = Instance.new("TextButton")
	dot.Name = "DepthLevel" .. tostring(level)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale((level - 1) / (DEPTH_LEVEL_COUNT - 1), 0.5)
	dot.Size = UDim2.fromOffset(14, 14)
	dot.BackgroundColor3 = Color3.fromRGB(20, 55, 105)
	dot.BorderSizePixel = 0
	dot.Text = ""
	dot.AutoButtonColor = false
	dot.Parent = depthTrack
	addCorner(dot, 8)
	addStroke(dot, Color3.fromRGB(105, 165, 235), 1)
	depthButtons[level] = dot
end

local actionRow = Instance.new("Frame")
actionRow.Position = UDim2.fromScale(0.57, 0.875)
actionRow.Size = UDim2.fromScale(0.405, 0.095)
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
previewButton.Size = UDim2.new(0.333, -7, 1, 0)
addStroke(previewButton, Color3.fromRGB(55, 210, 255), 1)

local removeButton = makeButton(actionRow, "Remove", Color3.fromRGB(194, 55, 55))
removeButton.LayoutOrder = 2
removeButton.Size = UDim2.new(0.333, -7, 1, 0)
addStroke(removeButton, Color3.fromRGB(255, 104, 78), 1)

local applyButton = makeButton(actionRow, "Apply", Color3.fromRGB(28, 160, 92))
applyButton.LayoutOrder = 3
applyButton.Size = UDim2.new(0.333, -7, 1, 0)
addStroke(applyButton, Color3.fromRGB(95, 255, 132), 1)

local themeButtons = {}
local themeButtonStrokes = {}
local decorButtons = {}
local decorButtonStrokes = {}

local backdropButton = makeButton(decorScroll, "Backdrop On", PLACED_GREEN)
backdropButton.LayoutOrder = 0
backdropButton.TextSize = 11
local backdropStroke = addStroke(backdropButton, Color3.fromRGB(95, 255, 132), 1)

local function updateBackdropButton()
	backdropButton.Text = backdropEnabled and "Backdrop On" or "Backdrop Off"
	backdropButton.BackgroundColor3 = backdropEnabled and PLACED_GREEN or TAP_BLUE
	backdropStroke.Color = backdropEnabled and Color3.fromRGB(95, 255, 132) or Color3.fromRGB(40, 155, 255)
	backdropStroke.Thickness = backdropEnabled and 2 or 1
end

local function applyResponsiveLayout()
	local camera = workspace.CurrentCamera
	local viewportSize = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local compactLandscape = viewportSize.Y < 520
	mobileLayoutActive = UserInputService.TouchEnabled

	panel.Size = UDim2.fromScale(0.97, 0.94)
	panelSize.MinSize = Vector2.new(math.min(640, viewportSize.X * 0.96), math.min(360, viewportSize.Y * 0.92))
	panelSize.MaxSize = Vector2.new(math.max(640, math.min(1500, viewportSize.X * 0.97)), math.max(360, math.min(860, viewportSize.Y * 0.94)))

	title.TextSize = compactLandscape and 18 or 24
	statusLabel.TextSize = compactLandscape and 11 or 14
	closeButton.Size = UDim2.fromOffset(compactLandscape and 38 or 48, compactLandscape and 38 or 48)
	themeLabel.TextSize = compactLandscape and 12 or 14
	decorLabel.TextSize = compactLandscape and 11 or 14
	adjustmentLabel.TextSize = compactLandscape and 12 or 14
	depthLabel.TextSize = compactLandscape and 10 or 12
	ghostMarker.Size = UDim2.fromOffset(mobileLayoutActive and 28 or 22, mobileLayoutActive and 28 or 22)

	local themeCellHeight = compactLandscape and 24 or 36
	local decorCellHeight = compactLandscape and 28 or 46
	themeLayout.CellSize = UDim2.new(0.25, -5, 0, themeCellHeight)
	decorLayout.CellSize = UDim2.new(0.25, -5, 0, decorCellHeight)
	themeScroll.ScrollBarThickness = mobileLayoutActive and 6 or 4
	decorScroll.ScrollBarThickness = mobileLayoutActive and 6 or 4
	for _, button in pairs(themeButtons) do
		button.TextSize = compactLandscape and 9 or 11
	end
	for _, button in pairs(decorButtons) do
		button.TextSize = compactLandscape and 9 or 11
	end
	backdropButton.TextSize = compactLandscape and 9 or 11
	previewButton.TextSize = compactLandscape and 10 or 13
	removeButton.TextSize = compactLandscape and 10 or 13
	applyButton.TextSize = compactLandscape and 10 or 13
	openButton.Size = UDim2.new(0, mobileLayoutActive and 158 or 146, 0, mobileLayoutActive and 52 or 48)
	backButton.Size = UDim2.new(0, mobileLayoutActive and 166 or 154, 0, mobileLayoutActive and 52 or 48)
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
	statusLabel.Text = lastActiveInputType == Enum.UserInputType.Touch and "Pinch to Scale" or "Scroll to Scale"
end

local refreshMarkers
local refreshDepthGauge
local updateThemeButtonSelection
local updateDecorButtonSelection

UserInputService.LastInputTypeChanged:Connect(function(inputType)
	lastActiveInputType = inputType
	updateStatus()
end)

local function updateGhost()
	if selectedIndex ~= nil then
		ghostMarker.Visible = false
		return
	end

	ghostMarker.Visible = false
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
	updateDecorButtonSelection()
	refreshDepthGauge()
	updateGhost()
end

local function findEditorItemIndex(decorationId)
	for index, item in ipairs(editorItems) do
		if item.decorationId == decorationId then
			return index
		end
	end
	return nil
end

updateDecorButtonSelection = function()
	for decorationId, button in pairs(decorButtons) do
		local placed = findEditorItemIndex(decorationId) ~= nil
		local selected = placed and decorationId == selectedDecorationId
		local decorationName = button:GetAttribute("DecorationName") or button.Text
		button.Text = placed and ("✓ " .. decorationName) or decorationName
		button.BackgroundColor3 = placed and PLACED_GREEN or TAP_BLUE
		local stroke = decorButtonStrokes[decorationId]
		if stroke then
			stroke.Color = selected and SELECTED_CYAN or (placed and Color3.fromRGB(95, 255, 132) or Color3.fromRGB(35, 160, 255))
			stroke.Thickness = selected and 3 or (placed and 2 or 1)
		end
	end
end

updateThemeButtonSelection = function()
	for themeId, button in pairs(themeButtons) do
		local selected = themeId == selectedThemeId
		button.BackgroundColor3 = selected and PLACED_GREEN or TAP_BLUE
		local stroke = themeButtonStrokes[themeId]
		if stroke then
			stroke.Color = selected and Color3.fromRGB(95, 255, 132) or Color3.fromRGB(35, 160, 255)
			stroke.Thickness = selected and 2 or 1
		end
	end

	local selectedTheme = designerConfig.themes[selectedThemeId]
	if selectedTheme then
		previewWater.BackgroundColor3 = selectedTheme.waterColor or previewWater.BackgroundColor3
		previewFrame.BackgroundColor3 = selectedTheme.frameColor or previewFrame.BackgroundColor3
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
		local button = makeButton(themeScroll, theme.name, TAP_BLUE)
		button.LayoutOrder = order
		button.TextSize = 11
		themeButtonStrokes[themeId] = addStroke(button, Color3.fromRGB(35, 160, 255), 1)
		button.MouseButton1Click:Connect(function()
			selectedThemeId = themeId
			updateThemeButtonSelection()
		end)
		themeButtons[themeId] = button
	end
end

themeLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	themeScroll.CanvasSize = UDim2.fromOffset(0, themeLayout.AbsoluteContentSize.Y + 12)
end)
themeScroll.CanvasSize = UDim2.fromOffset(0, themeLayout.AbsoluteContentSize.Y + 12)

for order, decorationId in ipairs(designerConfig.decorationOrder or {}) do
	if decorationId ~= "None" and designerConfig.decorations[decorationId] then
		local decoration = designerConfig.decorations[decorationId]
		local button = makeButton(decorScroll, decoration.name, TAP_BLUE)
		button.LayoutOrder = order
		button.TextSize = 11
		button:SetAttribute("DecorationName", decoration.name)
		decorButtonStrokes[decorationId] = addStroke(button, Color3.fromRGB(35, 160, 255), 1)
		button.MouseButton1Click:Connect(function()
			local existingIndex = findEditorItemIndex(decorationId)
			if existingIndex then
				selectedIndex = existingIndex
			else
				if #editorItems >= getMaxFreeDecorations() then
					warn("Aquarium decor editor placement failed: no free decoration slots available at this aquarium level.")
					return
				end

				table.insert(editorItems, {
					decorationId = decorationId,
					x = lastPointer.x,
					y = lastPointer.y,
					z = 0,
					scale = 1,
				})
				selectedIndex = #editorItems
			end
			selectedDecorationId = decorationId
			refreshMarkers()
		end)
		decorButtons[decorationId] = button
	end
end

decorLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	decorScroll.CanvasSize = UDim2.fromOffset(0, decorLayout.AbsoluteContentSize.Y + 12)
end)
decorScroll.CanvasSize = UDim2.fromOffset(0, decorLayout.AbsoluteContentSize.Y + 12)

local function getSelectedItem()
	return selectedIndex and editorItems[selectedIndex] or nil
end

removeButton.MouseButton1Click:Connect(function()
	if selectedIndex and editorItems[selectedIndex] then
		table.remove(editorItems, selectedIndex)
		if #editorItems == 0 then
			selectedIndex = nil
			selectedDecorationId = nil
		else
			selectedIndex = math.clamp(selectedIndex, 1, #editorItems)
			selectedDecorationId = editorItems[selectedIndex].decorationId
		end
		refreshMarkers()
	end
end)

local function depthLevelToZ(level)
	local alpha = (math.clamp(level, 1, DEPTH_LEVEL_COUNT) - 1) / (DEPTH_LEVEL_COUNT - 1)
	return zMax + ((zMin - zMax) * alpha)
end

local function zToDepthLevel(z)
	local alpha = (zMax - math.clamp(tonumber(z) or 0, zMin, zMax)) / math.max(0.001, zMax - zMin)
	return math.clamp(math.floor((alpha * (DEPTH_LEVEL_COUNT - 1)) + 0.5) + 1, 1, DEPTH_LEVEL_COUNT)
end

local function setSelectedDepthLevel(level)
	local item = getSelectedItem()
	if not item then
		return
	end
	item.z = depthLevelToZ(level)
	refreshDepthGauge()
end

refreshDepthGauge = function()
	local item = getSelectedItem()
	local selectedLevel = item and zToDepthLevel(item.z) or nil
	for level, dot in ipairs(depthButtons) do
		local selected = level == selectedLevel
		dot.BackgroundColor3 = selected and SELECTED_CYAN or Color3.fromRGB(20, 55, 105)
		dot.Size = UDim2.fromOffset(selected and 18 or 14, selected and 18 or 14)
		local stroke = dot:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = selected and Color3.fromRGB(210, 255, 255) or Color3.fromRGB(105, 165, 235)
			stroke.Thickness = selected and 2 or 1
		end
	end
	depthLeftButton.Active = item ~= nil
	depthRightButton.Active = item ~= nil
	depthLeftButton.AutoButtonColor = item ~= nil
	depthRightButton.AutoButtonColor = item ~= nil
	depthLabel.TextColor3 = item and Color3.fromRGB(230, 242, 255) or Color3.fromRGB(125, 145, 175)
end

depthLeftButton.MouseButton1Click:Connect(function()
	local item = getSelectedItem()
	if item then
		setSelectedDepthLevel(zToDepthLevel(item.z) - 1)
	end
end)

depthRightButton.MouseButton1Click:Connect(function()
	local item = getSelectedItem()
	if item then
		setSelectedDepthLevel(zToDepthLevel(item.z) + 1)
	end
end)

for level, dot in ipairs(depthButtons) do
	dot.MouseButton1Click:Connect(function()
		setSelectedDepthLevel(level)
	end)
end

local function isPointInsidePreview(position)
	local absolutePosition = previewFrame.AbsolutePosition
	local absoluteSize = previewFrame.AbsoluteSize
	return position.X >= absolutePosition.X
		and position.X <= absolutePosition.X + absoluteSize.X
		and position.Y >= absolutePosition.Y
		and position.Y <= absolutePosition.Y + absoluteSize.Y
end

local function sinkEditorCameraInput()
	return Enum.ContextActionResult.Sink
end

local function captureWheelOnlyInsidePreview()
	if panel.Visible and isPointInsidePreview(UserInputService:GetMouseLocation()) then
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function setWheelCapture(enabled)
	ContextActionService:UnbindAction(EDITOR_WHEEL_ACTION)
	if enabled and panel.Visible then
		ContextActionService:BindActionAtPriority(
			EDITOR_WHEEL_ACTION,
			captureWheelOnlyInsidePreview,
			false,
			Enum.ContextActionPriority.High.Value + 100,
			Enum.UserInputType.MouseWheel
		)
	end
end

local function setPinchCapture(enabled)
	ContextActionService:UnbindAction(EDITOR_PINCH_ACTION)
	if enabled and panel.Visible then
		ContextActionService:BindActionAtPriority(
			EDITOR_PINCH_ACTION,
			sinkEditorCameraInput,
			false,
			Enum.ContextActionPriority.High.Value + 100,
			Enum.UserInputType.Touch
		)
	end
end

local function releaseEditorInputCapture()
	setWheelCapture(false)
	setPinchCapture(false)
	pinchActive = false
end

local function scaleSelectedDecoration(newScale)
	local item = getSelectedItem()
	if not item then
		return
	end
	item.scale = math.clamp(newScale, scaleMin, scaleMax)
	refreshMarkers()
end

previewFrame.InputBegan:Connect(function(input)
	if pinchActive then
		return
	end
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
		and selectedIndex
	then
		draggingMode = "selected"
		setSelectedItemPosition(input.Position)
	end
end)

previewFrame.InputChanged:Connect(function(input)
	if not pinchActive
		and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
	then
		if draggingMode then
			setSelectedItemPosition(input.Position)
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if not panel.Visible or not getSelectedItem() then
			return
		end
		local mousePosition = UserInputService:GetMouseLocation()
		if not isPointInsidePreview(mousePosition) then
			return
		end
		local direction = math.sign(input.Position.Z)
		if direction ~= 0 then
			local item = getSelectedItem()
			scaleSelectedDecoration((tonumber(item.scale) or 1) + (direction * 0.06))
		end
		return
	end

	if not draggingMode then
		return
	end
	if not pinchActive
		and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
	then
		setSelectedItemPosition(input.Position)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingMode = nil
	end
end)

UserInputService.TouchPinch:Connect(function(touchPositions, pinchScale, _velocity, inputState)
	if inputState == Enum.UserInputState.Begin then
		if not panel.Visible or not getSelectedItem() or type(touchPositions) ~= "table" or #touchPositions < 2 then
			return
		end
		local pinchCenter = (touchPositions[1] + touchPositions[2]) / 2
		if not isPointInsidePreview(pinchCenter) then
			return
		end

		pinchActive = true
		draggingMode = nil
		pinchStartScale = tonumber(getSelectedItem().scale) or 1
		setPinchCapture(true)
	elseif inputState == Enum.UserInputState.Change then
		if pinchActive and panel.Visible and getSelectedItem() then
			scaleSelectedDecoration(pinchStartScale * math.max(0.01, tonumber(pinchScale) or 1))
		end
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		if pinchActive then
			pinchActive = false
			setPinchCapture(false)
			refreshMarkers()
		end
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
	panel.Visible = true
	setWheelCapture(true)
	openButton.Visible = false
	backButton.Visible = false
	updateStatus()
	updateThemeButtonSelection()
	updateDecorButtonSelection()
	updateBackdropButton()
	refreshMarkers()
end

local function closeEditor()
	releaseEditorInputCapture()
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
		releaseEditorInputCapture()
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
