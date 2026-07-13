local ServerStorage = game:GetService("ServerStorage")

local AquariumThemeService = {}

local THEME_FOLDER_NAME = "AquariumThemesV21"
local THEME_MODEL_NAME = "AquariumPremiumTheme"
local STANDARD_TANK_SIZE = Vector3.new(40, 15, 14)

local function configurePart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part:SetAttribute("AquariumThemeSavedTransparency", part.Transparency)
end

local function isBackdropPart(part)
	return string.find(string.upper(part.Name), "BACKDROP", 1, true) ~= nil
end

local function setBackdropVisible(model, visible)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and isBackdropPart(descendant) then
			local savedTransparency = descendant:GetAttribute("AquariumThemeSavedTransparency")
			if savedTransparency == nil then
				savedTransparency = descendant.Transparency
				descendant:SetAttribute("AquariumThemeSavedTransparency", savedTransparency)
			end
			descendant.Transparency = visible and savedTransparency or 1
		end
	end
end

local function isDefaultFramePart(part)
	local name = part.Name
	return name == "AquariumFramePost"
		or string.sub(name, 1, 16) == "AquariumTopFrame"
		or string.sub(name, 1, 19) == "AquariumBottomFrame"
end

local function setDefaultFrameVisible(tank, visible)
	for _, descendant in ipairs(tank:GetDescendants()) do
		if descendant:IsA("BasePart") and isDefaultFramePart(descendant) then
			local savedTransparency = descendant:GetAttribute("AquariumDefaultFrameTransparency")
			if savedTransparency == nil then
				savedTransparency = descendant.Transparency
				descendant:SetAttribute("AquariumDefaultFrameTransparency", savedTransparency)
			end
			descendant.Transparency = visible and savedTransparency or 1
		end
	end
end

local function scaleAndPlace(template, name, targetAnchor, dimensions)
	local clone = template:Clone()
	clone.Name = name

	local sourcePivot = clone:GetPivot()
	local scale = Vector3.new(
		dimensions.tankWidth / STANDARD_TANK_SIZE.X,
		dimensions.tankHeight / STANDARD_TANK_SIZE.Y,
		dimensions.tankDepth / STANDARD_TANK_SIZE.Z
	)

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local relative = sourcePivot:ToObjectSpace(descendant.CFrame)
			local relativePosition = relative.Position
			local scaledPosition = Vector3.new(
				relativePosition.X * scale.X,
				relativePosition.Y * scale.Y,
				relativePosition.Z * scale.Z
			)
			descendant.Size = Vector3.new(
				descendant.Size.X * scale.X,
				descendant.Size.Y * scale.Y,
				descendant.Size.Z * scale.Z
			)
			descendant.CFrame = targetAnchor * CFrame.new(scaledPosition) * relative.Rotation
			configurePart(descendant)
		end
	end

	return clone
end

function AquariumThemeService.apply(tank, themeId, origin, dimensions, backdropEnabled)
	local oldTheme = tank:FindFirstChild(THEME_MODEL_NAME)
	if oldTheme then
		oldTheme:Destroy()
	end

	-- Remove legacy split assets from aquariums created before the v2.1 combined models.
	local oldFrame = tank:FindFirstChild("AquariumPremiumThemeFrame")
	if oldFrame then
		oldFrame:Destroy()
	end

	local oldBackdrop = tank:FindFirstChild("AquariumPremiumThemeBackdrop")
	if oldBackdrop then
		oldBackdrop:Destroy()
	end

	local proceduralBackdrop = tank:FindFirstChild("AquariumDesignerBackground")
	local themeFolder = ServerStorage:FindFirstChild(THEME_FOLDER_NAME)
	local themeTemplate = themeFolder and themeFolder:FindFirstChild(themeId)
	if not (themeTemplate and themeTemplate:IsA("Model")) then
		warn(string.format("[AquariumThemeService] Missing imported v2.1 theme asset for %s", tostring(themeId)))
		setDefaultFrameVisible(tank, true)
		if proceduralBackdrop and proceduralBackdrop:IsA("BasePart") then
			proceduralBackdrop.Transparency = backdropEnabled and 0.08 or 1
		end
		return false
	end

	setDefaultFrameVisible(tank, false)
	if proceduralBackdrop and proceduralBackdrop:IsA("BasePart") then
		proceduralBackdrop.Transparency = 1
	end

	local targetAnchor = CFrame.new(origin + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.pi, 0)
	local theme = scaleAndPlace(themeTemplate, THEME_MODEL_NAME, targetAnchor, dimensions)
	theme.Parent = tank
	setBackdropVisible(theme, backdropEnabled)

	return true
end

return AquariumThemeService
