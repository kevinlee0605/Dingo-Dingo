local GuiPrimitives = {}

function GuiPrimitives.create(deps)
	local GameConfig = deps.GameConfig
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local primitives = {}
	local fishTemplateFolderName = "FishyFishModelTemplates"

	local function findFishVisualTemplate(fishId)
		local folder = ReplicatedStorage:FindFirstChild(fishTemplateFolderName)
		local template = folder and folder:FindFirstChild(tostring(fishId or ""))
		if template and template:IsA("Model") then
			return template
		end

		return nil
	end

	local function addFishViewportIcon(frame, template)
		local viewport = Instance.new("ViewportFrame")
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.Position = UDim2.fromScale(0, 0)
		viewport.Ambient = Color3.fromRGB(210, 225, 240)
		viewport.LightColor = Color3.fromRGB(255, 255, 255)
		viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)
		viewport.Parent = frame

		local camera = Instance.new("Camera")
		camera.FieldOfView = 34
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		local world = Instance.new("WorldModel")
		world.Parent = viewport

		local clone = template:Clone()
		clone.Parent = world

		local hasPart = false
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				hasPart = true
			end
		end

		if not hasPart then
			viewport:Destroy()
			return false
		end

		local _, boundsSize = clone:GetBoundingBox()
		local maxAxis = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z, 1)
		local yawDegrees = tonumber(template:GetAttribute("FishVisualYawDegrees")) or 90
		clone:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(yawDegrees), 0))
		camera.CFrame = CFrame.lookAt(Vector3.new(0, math.max(0.2, boundsSize.Y * 0.12), maxAxis * 2.15), Vector3.new(0, 0, 0))
		return true
	end

	function primitives.clearChildren(instance)
		for _, child in ipairs(instance:GetChildren()) do
			if not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end

	function primitives.addCorner(parent, radius)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius or 8)
		corner.Parent = parent
		return corner
	end

	function primitives.addStroke(parent, color, thickness)
		local stroke = Instance.new("UIStroke")
		stroke.Color = color or Color3.fromRGB(45, 52, 64)
		stroke.Thickness = thickness or 1
		stroke.Parent = parent
		return stroke
	end

	function primitives.addGradient(parent, topColor, bottomColor, rotation)
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, topColor),
			ColorSequenceKeypoint.new(1, bottomColor),
		})
		gradient.Rotation = rotation or 90
		gradient.Parent = parent
		return gradient
	end

	function primitives.setCornerRadius(parent, radius)
		local corner = parent:FindFirstChildOfClass("UICorner")
		if not corner then
			corner = Instance.new("UICorner")
			corner.Parent = parent
		end

		corner.CornerRadius = UDim.new(0, radius)
		return corner
	end

	function primitives.styleOutlinedText(label, size)
		label.Font = Enum.Font.FredokaOne
		label.TextSize = size or label.TextSize
		label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextTransparency = 0
		label.RichText = false
	end

	function primitives.forcePureWhiteText(label)
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextTransparency = 0
		label.TextStrokeColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 1
	end

	function primitives.limitTextSize(label, minSize, maxSize)
		local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
		if not constraint then
			constraint = Instance.new("UITextSizeConstraint")
			constraint.Parent = label
		end

		constraint.MinTextSize = minSize
		constraint.MaxTextSize = maxSize
		return constraint
	end

	function primitives.addGloss(parent, position, size)
		local gloss = Instance.new("Frame")
		gloss.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		gloss.BackgroundTransparency = 0.72
		gloss.Position = position
		gloss.Size = size
		gloss.ZIndex = (parent.ZIndex or 1) + 1
		gloss.Parent = parent
		primitives.addCorner(gloss, 24)

		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.45, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Rotation = 18
		gradient.Parent = gloss

		return gloss
	end

	function primitives.makeText(parent, text, size, color, bold)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
		label.Text = text
		label.TextColor3 = color or Color3.fromRGB(240, 244, 248)
		label.TextSize = size
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Parent = parent
		return label
	end

	function primitives.makeButton(parent, text, color)
		local button = Instance.new("TextButton")
		button.AutoButtonColor = true
		button.BackgroundColor3 = color or Color3.fromRGB(48, 126, 230)
		button.Font = Enum.Font.GothamBold
		button.Text = text
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextSize = 14
		button.Parent = parent
		primitives.addCorner(button, 7)
		primitives.addStroke(button, Color3.fromRGB(255, 255, 255), 1).Transparency = 0.85
		return button
	end

	function primitives.makeFishIcon(parent, fishId, rarity, discovered)
		local color = GameConfig.RarityColors[rarity] or Color3.fromRGB(130, 146, 166)
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Color3.fromRGB(21, 28, 38)
		frame.Parent = parent
		primitives.addCorner(frame, 6)
		primitives.addStroke(frame, color, 1).Transparency = discovered == false and 0.55 or 0.2

		local template = discovered == false and nil or findFishVisualTemplate(fishId)
		if template and addFishViewportIcon(frame, template) then
			return frame
		end

		local imageId = discovered == false and nil or GameConfig.getFishImage(fishId)
		if imageId then
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Image = imageId
			image.ScaleType = Enum.ScaleType.Fit
			image.Size = UDim2.fromScale(1, 1)
			image.Position = UDim2.fromScale(0, 0)
			image.Parent = frame
		else
			local label = primitives.makeText(frame, discovered == false and "?" or "FISH", 12, color, true)
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.Size = UDim2.fromScale(1, 1)
		end

		return frame
	end

	function primitives.makeRodIcon(parent, rodId)
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Color3.fromRGB(21, 28, 38)
		frame.Parent = parent
		primitives.addCorner(frame, 6)
		primitives.addStroke(frame, Color3.fromRGB(130, 146, 166), 1).Transparency = 0.2

		local imageId = GameConfig.getRodImage(rodId)
		if imageId then
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Image = imageId
			image.ScaleType = Enum.ScaleType.Fit
			image.Size = UDim2.fromScale(1, 1)
			image.Position = UDim2.fromScale(0, 0)
			image.Parent = frame
		else
			local label = primitives.makeText(frame, "NO IMAGE", 10, Color3.fromRGB(160, 174, 192), true)
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.Size = UDim2.fromScale(1, 1)
		end

		return frame
	end

	return primitives
end

return GuiPrimitives
