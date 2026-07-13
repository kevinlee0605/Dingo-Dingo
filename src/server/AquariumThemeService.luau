local ServerStorage = game:GetService("ServerStorage")

local AquariumThemeService = {}

local FRAME_FOLDER_NAME = "AquariumThemeFrames"
local BACKDROP_FOLDER_NAME = "AquariumThemes"
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

local function setModelVisible(model, visible)
	if not model then
		return
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
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
	local oldFrame = tank:FindFirstChild("AquariumPremiumThemeFrame")
	if oldFrame then
		oldFrame:Destroy()
	end

	local oldBackdrop = tank:FindFirstChild("AquariumPremiumThemeBackdrop")
	if oldBackdrop then
		oldBackdrop:Destroy()
	end

	local proceduralBackdrop = tank:FindFirstChild("AquariumDesignerBackground")
	if themeId == "Classic" then
		setDefaultFrameVisible(tank, true)
		if proceduralBackdrop and proceduralBackdrop:IsA("BasePart") then
			proceduralBackdrop.Transparency = backdropEnabled and 0.08 or 1
		end
		return true
	end

	local frameFolder = ServerStorage:FindFirstChild(FRAME_FOLDER_NAME)
	local backdropFolder = ServerStorage:FindFirstChild(BACKDROP_FOLDER_NAME)
	local frameTemplate = frameFolder and frameFolder:FindFirstChild(themeId)
	local backdropTemplate = backdropFolder and backdropFolder:FindFirstChild(themeId)
	if not (frameTemplate and frameTemplate:IsA("Model") and backdropTemplate and backdropTemplate:IsA("Model")) then
		warn(string.format("[AquariumThemeService] Missing imported premium theme assets for %s", tostring(themeId)))
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
	local frame = scaleAndPlace(frameTemplate, "AquariumPremiumThemeFrame", targetAnchor, dimensions)
	frame.Parent = tank

	local backdrop = scaleAndPlace(backdropTemplate, "AquariumPremiumThemeBackdrop", targetAnchor, dimensions)
	backdrop.Parent = tank
	setModelVisible(backdrop, backdropEnabled)

	return true
end

return AquariumThemeService
