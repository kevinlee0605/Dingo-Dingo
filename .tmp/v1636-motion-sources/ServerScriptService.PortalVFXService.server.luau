-- Adds presentation-only VFX to the visible surfaces behind AreaPortal triggers.
-- Teleport triggers, imported meshes, collisions, and travel logic are never changed.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PORTAL_TAG = "AreaPortal"
local GENERATED_ATTRIBUTE = "FishyFishGeneratedPortalVFX"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local DEFAULT_COLOR = Color3.fromRGB(0, 221, 255)
local DEFAULT_ACCENT = Color3.fromRGB(191, 255, 255)

type AxisName = "X" | "Y" | "Z"
type PortalState = {
	surface: BasePart,
	instances: { Instance },
	tweens: { Tween },
	connections: { RBXScriptConnection },
}

local portalStates: { [BasePart]: PortalState } = {}
local triggerConnections: { [BasePart]: { RBXScriptConnection } } = {}

local function markGenerated(instance: Instance)
	instance:SetAttribute(GENERATED_ATTRIBUTE, true)
end

local function remember(state: PortalState, instance: Instance)
	markGenerated(instance)
	table.insert(state.instances, instance)
	return instance
end

local function axisSize(size: Vector3, axis: AxisName): number
	if axis == "X" then
		return size.X
	elseif axis == "Y" then
		return size.Y
	end
	return size.Z
end

local function axisVector(axis: AxisName, amount: number): Vector3
	if axis == "X" then
		return Vector3.new(amount, 0, 0)
	elseif axis == "Y" then
		return Vector3.new(0, amount, 0)
	end
	return Vector3.new(0, 0, amount)
end

local function worldAxis(part: BasePart, axis: AxisName): Vector3
	if axis == "X" then
		return part.CFrame.RightVector
	elseif axis == "Y" then
		return part.CFrame.UpVector
	end
	return -part.CFrame.LookVector
end

local function faceForAxis(axis: AxisName): Enum.NormalId
	if axis == "X" then
		return Enum.NormalId.Right
	elseif axis == "Y" then
		return Enum.NormalId.Top
	end
	return Enum.NormalId.Front
end

local function oppositeFace(face: Enum.NormalId): Enum.NormalId
	if face == Enum.NormalId.Right then
		return Enum.NormalId.Left
	elseif face == Enum.NormalId.Left then
		return Enum.NormalId.Right
	elseif face == Enum.NormalId.Top then
		return Enum.NormalId.Bottom
	elseif face == Enum.NormalId.Bottom then
		return Enum.NormalId.Top
	elseif face == Enum.NormalId.Front then
		return Enum.NormalId.Back
	end
	return Enum.NormalId.Front
end

local function getSurfaceAxes(part: BasePart): (AxisName, AxisName, AxisName)
	local sizes = {
		X = part.Size.X,
		Y = part.Size.Y,
		Z = part.Size.Z,
	}
	local axes: { AxisName } = { "X", "Y", "Z" }
	table.sort(axes, function(a, b)
		return sizes[a] < sizes[b]
	end)

	local normalAxis = axes[1]
	local planeA = axes[2]
	local planeB = axes[3]
	local aVerticality = math.abs(worldAxis(part, planeA).Y)
	local bVerticality = math.abs(worldAxis(part, planeB).Y)

	if aVerticality >= bVerticality then
		return normalAxis, planeB, planeA
	end
	return normalAxis, planeA, planeB
end

local function getColorAttribute(instance: Instance, name: string, fallback: Color3): Color3
	local value = instance:GetAttribute(name)
	if typeof(value) == "Color3" then
		return value
	end
	return fallback
end

local function getIntensity(trigger: BasePart): number
	local value = tonumber(trigger:GetAttribute("PortalVFXIntensity")) or 1
	return math.clamp(value, 0.25, 2)
end

local function hasThinPlane(part: BasePart): boolean
	local smallest = math.min(part.Size.X, part.Size.Y, part.Size.Z)
	local largest = math.max(part.Size.X, part.Size.Y, part.Size.Z)
	return largest > 0 and smallest / largest <= 0.22
end

local function isDirectSurface(part: BasePart): boolean
	return part.Transparency < 0.98 and hasThinPlane(part)
end

local function lowerName(instance: Instance): string
	return string.lower(instance.Name)
end

local function candidateScore(trigger: BasePart, candidate: BasePart, searchRadius: number): number?
	if candidate == trigger or candidate.Transparency >= 0.98 then
		return nil
	end

	local distance = (candidate.Position - trigger.Position).Magnitude
	if distance > searchRadius then
		return nil
	end

	local name = lowerName(candidate)
	local smallest = math.min(candidate.Size.X, candidate.Size.Y, candidate.Size.Z)
	local largest = math.max(candidate.Size.X, candidate.Size.Y, candidate.Size.Z)
	if largest <= 0 then
		return nil
	end

	local thinness = smallest / largest
	local score = -distance * 1.15

	if candidate:GetAttribute("PortalVFXSurface") == true then
		score += 240
	end
	if string.find(name, "warpwater", 1, true) then
		score += 150
	end
	if string.find(name, "portal_surface", 1, true)
		or (string.find(name, "portal", 1, true) and string.find(name, "surface", 1, true)) then
		score += 135
	elseif string.find(name, "surface", 1, true) then
		score += 78
	elseif string.find(name, "portal", 1, true) then
		score += 48
	elseif string.find(name, "warp", 1, true) then
		score += 42
	elseif string.find(name, "water", 1, true) then
		score += 25
	end

	if thinness <= 0.22 then
		score += 72 * (1 - thinness / 0.22)
	else
		score -= 35
	end

	if candidate:IsA("MeshPart") then
		score += 14
		if candidate.TextureID ~= "" then
			score += 8
		end
	end

	if candidate.Material == Enum.Material.Neon or candidate.Material == Enum.Material.ForceField then
		score += 12
	end

	local color = candidate.Color
	if color.B > color.R * 1.15 and color.G > color.R * 1.05 then
		score += 16
	end

	for _, rejectedWord in ipairs({ "trigger", "spawn", "zone", "sign", "_pad", "_base" }) do
		if string.find(name, rejectedWord, 1, true) then
			score -= 150
		end
	end

	return score
end

local function findExplicitSurface(trigger: BasePart): BasePart?
	local surfaceValue = trigger:FindFirstChild("PortalVFXSurface")
	if surfaceValue and surfaceValue:IsA("ObjectValue") then
		local value = surfaceValue.Value
		if value and value:IsA("BasePart") then
			return value
		end
	end

	local surfaceName = trigger:GetAttribute("PortalVFXSurfaceName")
	if type(surfaceName) ~= "string" or surfaceName == "" then
		return nil
	end

	local root: Instance? = trigger.Parent
	for _ = 1, 5 do
		if not root or root == Workspace then
			break
		end
		local candidate = root:FindFirstChild(surfaceName, true)
		if candidate and candidate:IsA("BasePart") then
			return candidate
		end
		root = root.Parent
	end

	local workspaceCandidate = Workspace:FindFirstChild(surfaceName, true)
	if workspaceCandidate and workspaceCandidate:IsA("BasePart") then
		return workspaceCandidate
	end
	return nil
end

local function findVisualSurface(trigger: BasePart): BasePart?
	local explicitSurface = findExplicitSurface(trigger)
	if explicitSurface then
		return explicitSurface
	end

	if isDirectSurface(trigger) then
		return trigger
	end

	local searchRadius = math.clamp(trigger.Size.Magnitude * 1.35, 30, 90)
	local bestPart: BasePart? = nil
	local bestScore = -math.huge
	local seen: { [BasePart]: boolean } = {}

	local function consider(instance: Instance)
		if not instance:IsA("BasePart") or seen[instance] then
			return
		end
		seen[instance] = true
		local score = candidateScore(trigger, instance, searchRadius)
		if score and score > bestScore then
			bestScore = score
			bestPart = instance
		end
	end

	local root: Instance? = trigger.Parent
	for _ = 1, 4 do
		if not root or root == Workspace then
			break
		end
		consider(root)
		for _, descendant in ipairs(root:GetDescendants()) do
			consider(descendant)
		end
		root = root.Parent
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart")
			and (descendant.Position - trigger.Position).Magnitude <= searchRadius then
			consider(descendant)
		end
	end

	if bestScore >= 58 then
		return bestPart
	end
	return nil
end

local function makeAttachment(
	state: PortalState,
	surface: BasePart,
	name: string,
	position: Vector3,
	normalAxis: AxisName,
	normalDirection: number?
): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.SecondaryAxis = normalAxis == "Y" and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	attachment.Axis = axisVector(normalAxis, normalDirection or 1)
	attachment.Parent = surface
	remember(state, attachment)
	return attachment
end

local function makeEnergyEmitter(
	state: PortalState,
	surface: BasePart,
	name: string,
	face: Enum.NormalId,
	color: Color3,
	accent: Color3,
	rate: number,
	speed: NumberRange
): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = SPARK_TEXTURE
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, accent),
		ColorSequenceKeypoint.new(0.45, color),
		ColorSequenceKeypoint.new(1, accent),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.12),
		NumberSequenceKeypoint.new(0.7, 0.42),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.18, 0.16),
		NumberSequenceKeypoint.new(0.62, 0.34),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.7, 1.45)
	emitter.Rate = rate
	emitter.Speed = speed
	emitter.Drag = 2.8
	emitter.Acceleration = Vector3.new(0, 1.2, 0)
	emitter.Rotation = NumberRange.new(-180, 180)
	emitter.RotSpeed = NumberRange.new(-80, 80)
	emitter.SpreadAngle = Vector2.new(18, 18)
	emitter.EmissionDirection = face
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Brightness = 2.2
	emitter.ZOffset = 0.08
	emitter.Parent = surface
	remember(state, emitter)
	return emitter
end

local function makeEdgeSparkEmitter(
	state: PortalState,
	attachment: Attachment,
	face: Enum.NormalId,
	color: Color3,
	accent: Color3,
	rate: number
)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PortalEdgeSparks"
	emitter.Texture = SPARK_TEXTURE
	emitter.Color = ColorSequence.new(accent, color)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.72, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.46),
		NumberSequenceKeypoint.new(0.42, 0.24),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.65, 1.2)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(0.2, 0.8)
	emitter.Drag = 0.8
	emitter.Acceleration = Vector3.new(0, 3.4, 0)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Rotation = NumberRange.new(-180, 180)
	emitter.RotSpeed = NumberRange.new(-110, 110)
	emitter.EmissionDirection = face
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Brightness = 2.8
	emitter.ZOffset = 0.2
	emitter.Parent = attachment
	remember(state, emitter)
end

local function makeArcBeam(
	state: PortalState,
	surface: BasePart,
	name: string,
	attachment0: Attachment,
	attachment1: Attachment,
	color: Color3,
	accent: Color3,
	width: number,
	curve: number,
	speed: number
)
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.5, accent),
		ColorSequenceKeypoint.new(1, color),
	})
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.38),
		NumberSequenceKeypoint.new(0.18, 0.04),
		NumberSequenceKeypoint.new(0.82, 0.17),
		NumberSequenceKeypoint.new(1, 0.54),
	})
	beam.Width0 = width
	beam.Width1 = width * 0.58
	beam.CurveSize0 = curve
	beam.CurveSize1 = -curve * 0.72
	beam.Segments = 20
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Brightness = 2.6
	beam.ZOffset = 0.12
	beam.Texture = SPARK_TEXTURE
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 1.35
	beam.TextureSpeed = speed
	beam.Parent = surface
	remember(state, beam)
end

local function cleanupPortal(trigger: BasePart)
	local state = portalStates[trigger]
	if not state then
		return
	end
	portalStates[trigger] = nil

	for _, connection in ipairs(state.connections) do
		connection:Disconnect()
	end
	for _, tween in ipairs(state.tweens) do
		tween:Cancel()
	end
	for index = #state.instances, 1, -1 do
		local instance = state.instances[index]
		if instance.Parent then
			instance:Destroy()
		end
	end
end

local function buildPortalVFX(trigger: BasePart, surface: BasePart)
	cleanupPortal(trigger)

	local state: PortalState = {
		surface = surface,
		instances = {},
		tweens = {},
		connections = {},
	}
	portalStates[trigger] = state

	local normalAxis, horizontalAxis, verticalAxis = getSurfaceAxes(surface)
	local horizontalSize = axisSize(surface.Size, horizontalAxis)
	local verticalSize = axisSize(surface.Size, verticalAxis)
	local smallerPlaneSize = math.min(horizontalSize, verticalSize)
	local area = horizontalSize * verticalSize
	local intensity = getIntensity(trigger)
	local color = getColorAttribute(trigger, "PortalVFXColor", DEFAULT_COLOR)
	local accent = getColorAttribute(trigger, "PortalVFXAccentColor", DEFAULT_ACCENT)
	local frontFace = faceForAxis(normalAxis)
	local backFace = oppositeFace(frontFace)
	local surfaceOffset = math.max(axisSize(surface.Size, normalAxis) * 0.5 + 0.1, 0.14)

	local center = makeAttachment(state, surface, "PortalVFXCenter", Vector3.zero, normalAxis)
	local pointLight = Instance.new("PointLight")
	pointLight.Name = "PortalVFXGlow"
	pointLight.Color = color
	pointLight.Brightness = 1.05 * intensity
	pointLight.Range = math.clamp(math.max(horizontalSize, verticalSize) * 0.72, 12, 30)
	pointLight.Shadows = false
	pointLight.Parent = center
	remember(state, pointLight)

	local highlight = Instance.new("Highlight")
	highlight.Name = "PortalVFXOutline"
	highlight.Adornee = surface
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 1
	highlight.OutlineColor = accent
	highlight.OutlineTransparency = 0.28
	highlight.Parent = surface
	remember(state, highlight)

	for index, face in ipairs({ frontFace, backFace }) do
		local light = Instance.new("SurfaceLight")
		light.Name = index == 1 and "PortalVFXFrontGlow" or "PortalVFXBackGlow"
		light.Face = face
		light.Color = color
		light.Angle = 120
		light.Brightness = 0.62 * intensity
		light.Range = math.clamp(smallerPlaneSize * 0.7, 8, 22)
		light.Shadows = false
		light.Parent = surface
		remember(state, light)

		local tween = TweenService:Create(
			light,
			TweenInfo.new(1.45 + index * 0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Brightness = 1.02 * intensity }
		)
		table.insert(state.tweens, tween)
		tween:Play()
	end

	local glowTween = TweenService:Create(
		pointLight,
		TweenInfo.new(1.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Brightness = 1.72 * intensity }
	)
	table.insert(state.tweens, glowTween)
	glowTween:Play()

	local surfaceRate = math.clamp(area / 18, 12, 46) * intensity
	makeEnergyEmitter(
		state,
		surface,
		"PortalEnergyWispsFront",
		frontFace,
		color,
		accent,
		surfaceRate * 0.62,
		NumberRange.new(0.35, 1.15)
	)
	makeEnergyEmitter(
		state,
		surface,
		"PortalEnergyWispsBack",
		backFace,
		color,
		accent,
		surfaceRate * 0.38,
		NumberRange.new(0.2, 0.8)
	)

	local horizontalHalf = horizontalSize * 0.47
	local verticalHalf = verticalSize * 0.47
	local edgePositions = {
		axisVector(horizontalAxis, -horizontalHalf) + axisVector(verticalAxis, -verticalHalf),
		axisVector(horizontalAxis, horizontalHalf) + axisVector(verticalAxis, -verticalHalf),
		axisVector(horizontalAxis, -horizontalHalf) + axisVector(verticalAxis, verticalHalf),
		axisVector(horizontalAxis, horizontalHalf) + axisVector(verticalAxis, verticalHalf),
		axisVector(horizontalAxis, -horizontalHalf),
		axisVector(horizontalAxis, horizontalHalf),
		axisVector(verticalAxis, -verticalHalf),
		axisVector(verticalAxis, verticalHalf),
	}
	local edgeRate = math.clamp(area / 340, 1.8, 5.2) * intensity
	for index, position in ipairs(edgePositions) do
		local direction = index % 2 == 0 and -1 or 1
		local attachment = makeAttachment(
			state,
			surface,
			"PortalVFXEdge" .. tostring(index),
			position + axisVector(normalAxis, surfaceOffset * direction),
			normalAxis,
			direction
		)
		makeEdgeSparkEmitter(state, attachment, Enum.NormalId.Right, color, accent, edgeRate)
	end

	local beamPlans = {
		{ -0.44, -0.24, 0.42, 0.31, 0.24, 0.42 },
		{ -0.38, 0.36, 0.38, -0.34, -0.2, -0.34 },
		{ -0.46, 0.06, 0.46, -0.04, 0.13, 0.28 },
	}
	local beamWidth = math.clamp(smallerPlaneSize * 0.016, 0.12, 0.38) * intensity
	for index, plan in ipairs(beamPlans) do
		for sideIndex, direction in ipairs({ 1, -1 }) do
			local sideName = sideIndex == 1 and "Front" or "Back"
			local normalOffset = axisVector(normalAxis, surfaceOffset * direction)
			local startPosition = axisVector(horizontalAxis, horizontalSize * plan[1])
				+ axisVector(verticalAxis, verticalSize * plan[2])
				+ normalOffset
			local endPosition = axisVector(horizontalAxis, horizontalSize * plan[3])
				+ axisVector(verticalAxis, verticalSize * plan[4])
				+ normalOffset
			local startAttachment = makeAttachment(
				state,
				surface,
				"PortalVFXArc" .. tostring(index) .. sideName .. "Start",
				startPosition,
				normalAxis,
				direction
			)
			local endAttachment = makeAttachment(
				state,
				surface,
				"PortalVFXArc" .. tostring(index) .. sideName .. "End",
				endPosition,
				normalAxis,
				-direction
			)
			makeArcBeam(
				state,
				surface,
				"PortalVFXArc" .. tostring(index) .. sideName,
				startAttachment,
				endAttachment,
				color,
				accent,
				beamWidth * (1 - (index - 1) * 0.14) * (sideIndex == 1 and 1 or 0.8),
				smallerPlaneSize * plan[5],
				plan[6] * direction
			)
		end
	end

	table.insert(state.connections, surface.AncestryChanged:Connect(function()
		if not surface:IsDescendantOf(Workspace) then
			cleanupPortal(trigger)
		end
	end))

	print(string.format(
		"[PortalVFXService] Applied %s -> %s (%.1f x %.1f)",
		tostring(trigger:GetAttribute("PortalName") or trigger.Name),
		surface:GetFullName(),
		horizontalSize,
		verticalSize
	))
end

local function refreshPortal(trigger: BasePart)
	if not trigger:IsDescendantOf(Workspace)
		or not CollectionService:HasTag(trigger, PORTAL_TAG)
		or trigger:GetAttribute("PortalVFXDisabled") == true then
		cleanupPortal(trigger)
		return
	end

	local surface = findVisualSurface(trigger)
	if not surface then
		cleanupPortal(trigger)
		warn("[PortalVFXService] No visual surface found for", trigger:GetFullName())
		return
	end

	local current = portalStates[trigger]
	if current and current.surface == surface and surface:IsDescendantOf(Workspace) then
		return
	end
	buildPortalVFX(trigger, surface)
end

local function disconnectTrigger(trigger: BasePart)
	cleanupPortal(trigger)
	local connections = triggerConnections[trigger]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end
	triggerConnections[trigger] = nil
end

local function connectTrigger(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local trigger = instance
	if triggerConnections[trigger] then
		refreshPortal(trigger)
		return
	end

	triggerConnections[trigger] = {
		trigger:GetAttributeChangedSignal("PortalVFXDisabled"):Connect(function()
			refreshPortal(trigger)
		end),
		trigger:GetAttributeChangedSignal("PortalVFXIntensity"):Connect(function()
			cleanupPortal(trigger)
			refreshPortal(trigger)
		end),
		trigger:GetAttributeChangedSignal("PortalVFXColor"):Connect(function()
			cleanupPortal(trigger)
			refreshPortal(trigger)
		end),
		trigger:GetAttributeChangedSignal("PortalVFXAccentColor"):Connect(function()
			cleanupPortal(trigger)
			refreshPortal(trigger)
		end),
		trigger.AncestryChanged:Connect(function()
			if not trigger:IsDescendantOf(Workspace) then
				disconnectTrigger(trigger)
			end
		end),
	}

	task.defer(refreshPortal, trigger)
end

-- Remove only top-level remnants generated by an older copy of this controller.
local generatedRoots = {}
for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:GetAttribute(GENERATED_ATTRIBUTE) == true then
		local parent = descendant.Parent
		if not parent or parent:GetAttribute(GENERATED_ATTRIBUTE) ~= true then
			table.insert(generatedRoots, descendant)
		end
	end
end
for _, generatedRoot in ipairs(generatedRoots) do
	generatedRoot:Destroy()
end

for _, portal in ipairs(CollectionService:GetTagged(PORTAL_TAG)) do
	connectTrigger(portal)
end

CollectionService:GetInstanceAddedSignal(PORTAL_TAG):Connect(connectTrigger)
CollectionService:GetInstanceRemovedSignal(PORTAL_TAG):Connect(function(instance)
	if instance:IsA("BasePart") then
		disconnectTrigger(instance)
	end
end)

print("[PortalVFXService] Layered portal VFX controller loaded.")
