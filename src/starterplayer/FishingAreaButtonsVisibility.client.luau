local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local GameConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")
)

local DEFAULT_FISHING_ISLAND_ID =
	(GameConfig.IslandOrder and GameConfig.IslandOrder[1])
	or (GameConfig.BiomeOrder and GameConfig.BiomeOrder[1])

local CHECK_INTERVAL = 0.15
local BIND_NAME = "FishingAreaButtonsVisibility"

local bottomButtonsFrame = nil
local visibilityConnection = nil
local shouldShow = false
local applyingVisibility = false

local function isLilyshoreIslandInstance(instance)
	while instance do
		if instance.Name == "LilyshoreIsland"
			or instance.Name == "LilyshoreFishingZone"
			or instance.Name == "BeginnerPondArea"
			or instance.Name == "BeginnerPond_ExtraLarge"
			or instance.Name == "Beginner Pond"
		then
			return true
		end

		instance = instance.Parent
	end

	return false
end

local function getGroundBiomeId(position, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = character and { character } or {}

	local result = workspace:Raycast(
		position + Vector3.new(0, 12, 0),
		Vector3.new(0, -90, 0),
		params
	)

	if result and isLilyshoreIslandInstance(result.Instance) then
		return DEFAULT_FISHING_ISLAND_ID
	end

	return nil
end

local function getLocalFishingBiomeId()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if not rootPart then
		return nil
	end

	local groundBiomeId = getGroundBiomeId(rootPart.Position, character)
	if groundBiomeId then
		return groundBiomeId
	end

	for _, biomeId in ipairs(GameConfig.BiomeOrder or {}) do
		if biomeId == DEFAULT_FISHING_ISLAND_ID then
			continue
		end

		local biome = GameConfig.Biomes and GameConfig.Biomes[biomeId]
		local center = biome and biome.position

		if center then
			local dx = math.abs(rootPart.Position.X - center.X)
			local dz = math.abs(rootPart.Position.Z - center.Z)

			if dx <= 58 and dz <= 54 then
				return biomeId
			end
		end
	end

	return nil
end

local function applyVisibility()
	if not bottomButtonsFrame or not bottomButtonsFrame.Parent then
		return
	end

	local targetVisible = shouldShow or bottomButtonsFrame:GetAttribute("ForceFishingTapVisible") == true
	if bottomButtonsFrame.Visible == targetVisible then
		return
	end

	applyingVisibility = true
	bottomButtonsFrame.Visible = targetVisible
	applyingVisibility = false
end

local function bindBottomButtonsFrame(frame)
	if bottomButtonsFrame == frame then
		applyVisibility()
		return
	end

	if visibilityConnection then
		visibilityConnection:Disconnect()
		visibilityConnection = nil
	end

	bottomButtonsFrame = frame

	visibilityConnection = frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not applyingVisibility then
			applyVisibility()
		end
	end)

	applyVisibility()
end

local function findAndBindBottomButtonsFrame()
	local frame = playerGui:FindFirstChild("BottomButtonsFrame", true)

	if frame and frame:IsA("GuiObject") then
		bindBottomButtonsFrame(frame)
	else
		bottomButtonsFrame = nil
	end
end

local function updateFishingAreaState()
	shouldShow = getLocalFishingBiomeId() ~= nil

	if not bottomButtonsFrame or not bottomButtonsFrame.Parent then
		findAndBindBottomButtonsFrame()
	end

	applyVisibility()
end

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "BottomButtonsFrame" and descendant:IsA("GuiObject") then
		task.defer(function()
			bindBottomButtonsFrame(descendant)
			updateFishingAreaState()
		end)
	end
end)

player.CharacterAdded:Connect(function()
	shouldShow = false
	applyVisibility()
	task.delay(0.3, updateFishingAreaState)
end)

findAndBindBottomButtonsFrame()
updateFishingAreaState()

RunService:BindToRenderStep(BIND_NAME, 3000, applyVisibility)

task.spawn(function()
	while true do
		updateFishingAreaState()
		task.wait(CHECK_INTERVAL)
	end
end)

print("[FishingAreaButtonsVisibility] Started")

local function startFishingRodSway()
	local CAST_FLEX_ATTRIBUTE = "FishingRodCastFlex"
	local CAST_TWIST_ATTRIBUTE = "FishingRodCastTwist"
	local CAST_SIDE_ATTRIBUTE = "FishingRodCastSide"
	local CAST_LINE_SWING_ATTRIBUTE = "FishingRodLineSwing"
	local MAX_SWAY = math.rad(6)
	local FORWARD_SWAY_PER_SPEED = math.rad(0.28)
	local SIDE_SWAY_PER_SPEED = math.rad(0.32)
	local STEP_SWAY = math.rad(0.8)
	local SPRING_STIFFNESS = 48
	local SPRING_DAMPING = 9
	local STEP_FREQUENCY = 8
	local swayStates = setmetatable({}, { __mode = "k" })
	local stowedRodConnections = setmetatable({}, { __mode = "k" })
	local CAST_TIP_ATTACHMENT_NAME = "FishingCastTipAttachment"
	local CAST_BOBBER_ATTACHMENT_NAME = "FishingCastBobberAttachment"
	local CAST_LINE_BEAM_NAME = "FishingCastLineBeam"
	local CAST_LINE_WIDTH = 0.035
	local CAST_LINE_FALLBACK_COLOR = Color3.fromRGB(235, 235, 235)
	local CAST_LINE_MIN_BRIGHTNESS = 235 / 255
	-- These are the Fishing Line material colors from each original FBX model.
	-- Roblox flattens the imported material into a texture, so the MeshPart.Color
	-- property is white and cannot be used to recover the visible line color.
	local CAST_LINE_COLORS_BY_ROD_ID = {
		WoodenRod = Color3.fromRGB(224, 219, 199),
		IronRod = Color3.fromRGB(224, 224, 209),
		GoldenRod = Color3.fromRGB(242, 230, 184),
		EmeraldRod = Color3.fromRGB(0, 255, 107),
		OceanRod = Color3.fromRGB(0, 217, 255),
	}

	local function getSwayJoints(tool)
		local joints = {}
		for _, descendant in ipairs(tool:GetDescendants()) do
			if descendant:IsA("Motor6D") and descendant:GetAttribute("FishingRodSwayJoint") == true then
				table.insert(joints, descendant)
			end
		end
		return joints
	end

	local function jointsAreValid(joints)
		if not joints or #joints == 0 then
			return false
		end
		for _, joint in ipairs(joints) do
			if not joint.Parent or not joint.Part0 or not joint.Part1 then
				return false
			end
		end
		return true
	end

	local function getCastingLineParts(tool)
		local stringParts = {}
		local bobberPart = nil

		for _, descendant in ipairs(tool:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local normalizedName = string.lower(descendant.Name)
				if string.find(normalizedName, "string", 1, true) then
					table.insert(stringParts, descendant)
				elseif not bobberPart and string.find(normalizedName, "bobber", 1, true) then
					bobberPart = descendant
				end
			end
		end

		return stringParts, bobberPart
	end

	local function getCastingLineAppearance(tool, stringParts)
		local sourceString = stringParts and stringParts[1]
		local rodId = tool and tool:GetAttribute("RodId")
		local modelLineColor = CAST_LINE_COLORS_BY_ROD_ID[rodId]
		if modelLineColor then
			return modelLineColor, sourceString and math.clamp(sourceString.Transparency, 0, 1) or 0
		end

		if not sourceString then
			return CAST_LINE_FALLBACK_COLOR, 0
		end

		-- Imported rods use separate texture atlases, and future rods may also tint
		-- the source string. Preserve that hue while lifting neutral imported gray
		-- to the bright, thread-like appearance visible on the original mesh.
		local sourceColor = sourceString.Color
		local brightestChannel = math.max(sourceColor.R, sourceColor.G, sourceColor.B)
		local brightnessScale = brightestChannel > 0
			and math.max(1, CAST_LINE_MIN_BRIGHTNESS / brightestChannel)
			or 1
		local lineColor = Color3.new(
			math.clamp(sourceColor.R * brightnessScale, 0, 1),
			math.clamp(sourceColor.G * brightnessScale, 0, 1),
			math.clamp(sourceColor.B * brightnessScale, 0, 1)
		)

		return lineColor, math.clamp(sourceString.Transparency, 0, 1)
	end

	local function getRodTipAnchor(tool, handle, joints, stringParts)
		local bestPart = nil
		local bestLength = -math.huge

		for _, descendant in ipairs(tool:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant ~= handle then
				local normalizedName = string.gsub(string.lower(descendant.Name), "[^%w]", "")
				local isBodyPart = string.find(normalizedName, "rodbase", 1, true)
					or string.find(normalizedName, "body", 1, true)
					or string.find(normalizedName, "shaft", 1, true)
				if isBodyPart then
					local longestAxis = math.max(descendant.Size.X, descendant.Size.Y, descendant.Size.Z)
					if longestAxis > bestLength then
						bestPart = descendant
						bestLength = longestAxis
					end
				end
			end
		end

		if not bestPart then
			return handle, nil
		end

		local halfSize = bestPart.Size * 0.5
		local positiveEnd
		if bestPart.Size.X >= bestPart.Size.Y and bestPart.Size.X >= bestPart.Size.Z then
			positiveEnd = Vector3.new(halfSize.X, 0, 0)
		elseif bestPart.Size.Y >= bestPart.Size.X and bestPart.Size.Y >= bestPart.Size.Z then
			positiveEnd = Vector3.new(0, halfSize.Y, 0)
		else
			positiveEnd = Vector3.new(0, 0, halfSize.Z)
		end

		local negativeEnd = positiveEnd * -1
		local positiveWorld = bestPart.CFrame:PointToWorldSpace(positiveEnd)
		local negativeWorld = bestPart.CFrame:PointToWorldSpace(negativeEnd)
		local localTip = (positiveWorld - handle.Position).Magnitude >= (negativeWorld - handle.Position).Magnitude
			and positiveEnd
			or negativeEnd

		-- The rod mesh includes its reel in the same bounding box, so the center
		-- of the end face is not necessarily where the modeled string connects.
		-- Use the closest corner of the string's unrotated bounds to choose the
		-- correct point across that end face.
		local stringPart = stringParts and stringParts[1]
		local stringJoint = nil
		for _, joint in ipairs(joints or {}) do
			if joint.Part1 == stringPart then
				stringJoint = joint
				break
			end
		end
		if stringPart and stringJoint then
			local baselineStringCFrame = handle.CFrame * stringJoint.C0 * stringJoint.C1:Inverse()
			local bodyTipCenter = bestPart.CFrame:PointToWorldSpace(localTip)
			local stringHalfSize = stringPart.Size * 0.5
			local closestCorner = nil
			local closestDistance = math.huge
			for _, xSign in ipairs({ -1, 1 }) do
				for _, ySign in ipairs({ -1, 1 }) do
					for _, zSign in ipairs({ -1, 1 }) do
						local corner = baselineStringCFrame:PointToWorldSpace(Vector3.new(
							stringHalfSize.X * xSign,
							stringHalfSize.Y * ySign,
							stringHalfSize.Z * zSign
						))
						local distance = (corner - bodyTipCenter).Magnitude
						if distance < closestDistance then
							closestCorner = corner
							closestDistance = distance
						end
					end
				end
			end

			if closestCorner then
				local cornerOnBody = bestPart.CFrame:PointToObjectSpace(closestCorner)
				if bestPart.Size.X >= bestPart.Size.Y and bestPart.Size.X >= bestPart.Size.Z then
					localTip = Vector3.new(localTip.X, math.clamp(cornerOnBody.Y, -halfSize.Y, halfSize.Y), math.clamp(cornerOnBody.Z, -halfSize.Z, halfSize.Z))
				elseif bestPart.Size.Y >= bestPart.Size.X and bestPart.Size.Y >= bestPart.Size.Z then
					-- The reel widens the positive-X side of this combined mesh. Move the
					-- modeled connection slightly toward the shaft corner, but keep it
					-- inside the visible cap instead of overshooting the rod bounds.
					local bodyX = -math.abs(math.clamp(cornerOnBody.X, -halfSize.X, halfSize.X))
					local bodyZ = math.clamp(cornerOnBody.Z, -halfSize.Z, halfSize.Z)
					localTip = Vector3.new(
						bodyX + ((-halfSize.X - bodyX) * 0.2),
						localTip.Y,
						bodyZ + ((-halfSize.Z - bodyZ) * 0.2)
					)
				else
					localTip = Vector3.new(math.clamp(cornerOnBody.X, -halfSize.X, halfSize.X), math.clamp(cornerOnBody.Y, -halfSize.Y, halfSize.Y), localTip.Z)
				end
			end
		end

		return bestPart, CFrame.new(localTip)
	end

	local function ensureCastingLine(tool, state)
		if state.castBeam and state.castBeam.Parent and state.bobberAttachment and state.bobberAttachment.Parent then
			return
		end
		if not jointsAreValid(state.joints) then
			return
		end

		local pivotJoint = state.joints[1]
		local handle = pivotJoint.Part0
		local stringParts, bobberPart = getCastingLineParts(tool)
		if not handle or not bobberPart then
			return
		end

		local tipPart, tipCFrame = getRodTipAnchor(tool, handle, state.joints, stringParts)
		local tipAttachment = tipPart:FindFirstChild(CAST_TIP_ATTACHMENT_NAME)
		if not tipAttachment or not tipAttachment:IsA("Attachment") then
			tipAttachment = Instance.new("Attachment")
			tipAttachment.Name = CAST_TIP_ATTACHMENT_NAME
			tipAttachment.Parent = tipPart
		end
		-- Anchor to the physical end of the imported rod body. The sway motors use
		-- an approximate model-bounds pivot, which is not always the mesh's tip.
		tipAttachment.CFrame = tipCFrame or pivotJoint.C0

		local bobberAttachment = bobberPart:FindFirstChild(CAST_BOBBER_ATTACHMENT_NAME)
		if not bobberAttachment or not bobberAttachment:IsA("Attachment") then
			bobberAttachment = Instance.new("Attachment")
			bobberAttachment.Name = CAST_BOBBER_ATTACHMENT_NAME
			bobberAttachment.Parent = bobberPart
		end
		bobberAttachment.CFrame = CFrame.new()

		local castBeam = handle:FindFirstChild(CAST_LINE_BEAM_NAME)
		if not castBeam or not castBeam:IsA("Beam") then
			castBeam = Instance.new("Beam")
			castBeam.Name = CAST_LINE_BEAM_NAME
			castBeam.Parent = handle
		end
		-- Match the original held line's appearance without changing that model.
		local lineColor, lineTransparency = getCastingLineAppearance(tool, stringParts)
		castBeam.Width0 = CAST_LINE_WIDTH
		castBeam.Width1 = CAST_LINE_WIDTH
		castBeam.Color = ColorSequence.new(lineColor)
		castBeam.Transparency = NumberSequence.new(lineTransparency)
		castBeam.LightInfluence = 0
		castBeam.FaceCamera = true
		castBeam.Segments = 1
		castBeam.Attachment0 = tipAttachment
		castBeam.Attachment1 = bobberAttachment
		castBeam.Enabled = false

		state.stringParts = stringParts
		state.bobberAttachment = bobberAttachment
		for _, joint in ipairs(state.joints) do
			if joint.Part1 == tipPart then
				state.tipJoint = joint
			end
			if joint.Part1 == bobberPart then
				state.bobberJoint = joint
			end
		end
		state.castBeam = castBeam
	end

	local function getJointPart1CFrame(joint)
		if not joint or not joint.Parent or not joint.Part0 or not joint.Part1 then
			return nil
		end

		return joint.Part0.CFrame * joint.C0 * joint.Transform * joint.C1:Inverse()
	end

	local function getCastingTipWorldPosition(state, tipAttachment)
		local tipPartCFrame = getJointPart1CFrame(state.tipJoint)
		if tipPartCFrame then
			return tipPartCFrame:PointToWorldSpace(tipAttachment.Position)
		end
		return tipAttachment.WorldPosition
	end

	local function alignBobberWithCastingLine(tool, state, lineSwing)
		local bobberJoint = state.bobberJoint
		local bobberAttachment = state.bobberAttachment
		local tipAttachment = state.castBeam and state.castBeam.Attachment0
		local bobberPart = bobberAttachment and bobberAttachment.Parent
		if not bobberJoint or not bobberJoint.Parent or not bobberJoint.Part0 or not bobberJoint.Part1 then
			return
		end
		if not tipAttachment or not bobberPart or not bobberPart:IsA("BasePart") then
			return
		end

		-- Read the baseline pose directly from the Motor6D equation. Part.CFrame is
		-- not updated immediately after Transform changes, so using it here caused
		-- the bobber to mirror its previous result and alternate sides every frame.
		local currentCFrame = getJointPart1CFrame(bobberJoint) or bobberPart.CFrame
		local tipWorld = getCastingTipWorldPosition(state, tipAttachment)
		local currentPosition = currentCFrame.Position
		local forwardOffset = currentPosition - tipWorld
		if forwardOffset.Magnitude < 0.0001 then
			return
		end

		-- Cast in the direction the character is facing instead of treating the
		-- imported hanging offset as the forward endpoint. Keep the whole path on
		-- the rod-hand side of the avatar so neither the bobber nor the straight Beam
		-- connecting it to the tip cuts through the torso during the overhead swing.
		local swing = math.clamp(tonumber(lineSwing) or 0, 0, 1)
		local character = tool and tool.Parent
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local horizontalForward = rootPart and Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
			or Vector3.new(forwardOffset.X, 0, forwardOffset.Z)
		if horizontalForward.Magnitude < 0.0001 then
			horizontalForward = Vector3.new(currentCFrame.LookVector.X, 0, currentCFrame.LookVector.Z)
		end
		if horizontalForward.Magnitude < 0.0001 then
			return
		end
		horizontalForward = horizontalForward.Unit

		local castLength = math.max(forwardOffset.Magnitude, 3.2)
		local safeSide
		if rootPart then
			local tipLocal = rootPart.CFrame:PointToObjectSpace(tipWorld)
			local sideSign = tipLocal.X >= 0 and 1 or -1
			safeSide = rootPart.CFrame.RightVector * sideSign
		else
			safeSide = currentCFrame.RightVector
		end

		local pulledBackOffset = (-horizontalForward * castLength * 0.8)
			+ (Vector3.yAxis * castLength * 0.9)
			+ (safeSide * castLength * 0.78)
		local overheadOffset = (horizontalForward * castLength * 0.5)
			+ (Vector3.yAxis * castLength * 1.75)
			+ (safeSide * castLength * 0.62)
		local releasedOffset = (horizontalForward * castLength * 2.1)
			- (Vector3.yAxis * castLength * 0.62)
			+ (safeSide * castLength * 0.12)

		-- Resolve the release endpoint once in world space. This keeps the bobber at
		-- the water surface after the player's arm (or character) moves. Starting a
		-- new windup clears it so the next cast gets a fresh landing point.
		if swing <= 0.001 then
			state.landedBobberWorldPosition = nil
		elseif not state.landedBobberWorldPosition then
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = character and { character } or {}
			raycastParams.IgnoreWater = false

			local fallbackPosition = tipWorld + releasedOffset
			local landingPosition = nil
			-- Sample a forward cone rather than one narrow line. Shore edges are often
			-- irregular, so the straight-ahead point can be grass even while the player
			-- is correctly facing the pond. The cone never reaches behind the avatar,
			-- which also prevents the landed Beam from cutting back through the body.
			local directionAngles = { 0, 12, -12, 24, -24, 36, -36, 48, -48, 60, -60, 72, -72 }
			-- Use world-space distances here. Imported rods have very different modeled
			-- string lengths, so scaling this search by castLength can stop several studs
			-- short of the same shoreline for one rod and overshoot it for another.
			local landingDistances = { 6, 9, 12, 15, 18, 21, 25, 30, 36, 44 }
			for _, landingDistance in ipairs(landingDistances) do
				for _, angleDegrees in ipairs(directionAngles) do
					local angle = math.rad(angleDegrees)
					local castDirection = (horizontalForward * math.cos(angle))
						+ (safeSide * math.sin(angle))
					if castDirection.Magnitude > 0.0001 then
						castDirection = castDirection.Unit
					end

					local candidate = tipWorld
						+ (castDirection * landingDistance)
						+ (safeSide * castLength * 0.12)
					local rayOrigin = Vector3.new(candidate.X, tipWorld.Y + 24, candidate.Z)
					local result = workspace:Raycast(rayOrigin, Vector3.new(0, -80, 0), raycastParams)
					if result then
						local hitName = result.Instance and string.lower(result.Instance.Name) or ""
						if result.Material == Enum.Material.Water
							or string.find(hitName, "water", 1, true)
						then
							landingPosition = result.Position
							break
						end
					end
				end
				if landingPosition then
					break
				end
			end

			-- Never pin the released bobber to grass or a wall. Fishing zones place
			-- water in the forward cone; the geometric endpoint is only a last-resort
			-- visual fallback if a custom map has no detectable water surface.
			state.landedBobberWorldPosition = landingPosition or fallbackPosition
		end

		local landingPosition = state.landedBobberWorldPosition or (tipWorld + releasedOffset)
		local inverseSwing = 1 - swing
		local pulledBackPosition = tipWorld + pulledBackOffset
		local overheadPosition = tipWorld + overheadOffset
		local desiredPosition = (pulledBackPosition * inverseSwing * inverseSwing)
			+ (overheadPosition * 2 * inverseSwing * swing)
			+ (landingPosition * swing * swing)
		local toTip = tipWorld - desiredPosition
		if toTip.Magnitude < 0.0001 then
			return
		end

		local localAxis
		if bobberPart.Size.X >= bobberPart.Size.Y and bobberPart.Size.X >= bobberPart.Size.Z then
			localAxis = Vector3.new(1, 0, 0)
		elseif bobberPart.Size.Y >= bobberPart.Size.X and bobberPart.Size.Y >= bobberPart.Size.Z then
			localAxis = Vector3.new(0, 1, 0)
		else
			localAxis = Vector3.new(0, 0, 1)
		end

		-- Point whichever modeled end owns the connector toward the rod tip.
		local connectorSign = bobberAttachment.Position:Dot(localAxis) >= 0 and 1 or -1
		local currentConnectorAxis = currentCFrame:VectorToWorldSpace(localAxis * connectorSign)
		local desiredConnectorAxis = toTip.Unit
		local cross = currentConnectorAxis:Cross(desiredConnectorAxis)
		local dot = math.clamp(currentConnectorAxis:Dot(desiredConnectorAxis), -1, 1)
		local deltaRotation = CFrame.new()

		if cross.Magnitude > 0.0001 then
			deltaRotation = CFrame.fromAxisAngle(cross.Unit, math.atan2(cross.Magnitude, dot))
		elseif dot < 0 then
			local fallbackAxis = currentCFrame.RightVector
			if math.abs(fallbackAxis:Dot(currentConnectorAxis)) > 0.95 then
				fallbackAxis = currentCFrame.LookVector
			end
			deltaRotation = CFrame.fromAxisAngle(fallbackAxis, math.pi)
		end

		local currentRotation = currentCFrame - currentCFrame.Position
		local desiredCFrame = CFrame.new(desiredPosition) * deltaRotation * currentRotation
		bobberJoint.Transform = (bobberJoint.Part0.CFrame * bobberJoint.C0):Inverse()
			* desiredCFrame
			* bobberJoint.C1
	end

	local function setCastingLineActive(tool, state, active, lineSwing)
		ensureCastingLine(tool, state)
		for _, stringPart in ipairs(state.stringParts or {}) do
			if stringPart.Parent then
				stringPart.LocalTransparencyModifier = active and 1 or 0
			end
		end
		if state.castBeam and state.castBeam.Parent then
			if active and state.bobberAttachment and state.bobberAttachment.Parent then
				-- Connect to the center of the bobber end that faces the rod. Projecting
				-- diagonally toward the tip put the beam on an upper edge, so it looked
				-- detached from the modeled red-side connector.
				local tipAttachment = state.castBeam.Attachment0
				local bobberPart = state.bobberAttachment.Parent
				if tipAttachment and bobberPart:IsA("BasePart") then
					local halfSize = bobberPart.Size * 0.5
					local positiveEnd
					if bobberPart.Size.X >= bobberPart.Size.Y and bobberPart.Size.X >= bobberPart.Size.Z then
						positiveEnd = Vector3.new(halfSize.X, 0, 0)
					elseif bobberPart.Size.Y >= bobberPart.Size.X and bobberPart.Size.Y >= bobberPart.Size.Z then
						positiveEnd = Vector3.new(0, halfSize.Y, 0)
					else
						positiveEnd = Vector3.new(0, 0, halfSize.Z)
					end

					local negativeEnd = -positiveEnd
					local bobberCFrame = getJointPart1CFrame(state.bobberJoint) or bobberPart.CFrame
					local tipWorld = getCastingTipWorldPosition(state, tipAttachment)
					local positiveDistance = (bobberCFrame:PointToWorldSpace(positiveEnd) - tipWorld).Magnitude
					local negativeDistance = (bobberCFrame:PointToWorldSpace(negativeEnd) - tipWorld).Magnitude
					state.bobberAttachment.Position = positiveDistance <= negativeDistance and positiveEnd or negativeEnd
					alignBobberWithCastingLine(tool, state, lineSwing)
				end
			end
			state.castBeam.Enabled = active
		end
		if not active then
			state.landedBobberWorldPosition = nil
		end
	end

	local function resetState(state)
		for _, stringPart in ipairs(state.stringParts or {}) do
			if stringPart.Parent then
				stringPart.LocalTransparencyModifier = 0
			end
		end
		if state.castBeam and state.castBeam.Parent then
			state.castBeam.Enabled = false
		end
		state.landedBobberWorldPosition = nil
		if state.joints then
			for _, joint in ipairs(state.joints) do
				if joint.Parent then
					joint.Transform = CFrame.new()
				end
			end
		end
	end

	local function getState(tool)
		local state = swayStates[tool]
		if not state then
			state = {
				pitch = 0,
				roll = 0,
				pitchVelocity = 0,
				rollVelocity = 0,
				joints = nil,
				stringParts = nil,
				bobberAttachment = nil,
				tipJoint = nil,
				bobberJoint = nil,
				castBeam = nil,
				landedBobberWorldPosition = nil,
			}
			swayStates[tool] = state
		end
		if not jointsAreValid(state.joints) then
			state.joints = getSwayJoints(tool)
			state.stringParts = nil
			state.bobberAttachment = nil
			state.tipJoint = nil
			state.bobberJoint = nil
			state.castBeam = nil
			state.landedBobberWorldPosition = nil
		end
		return state
	end

	local function springAxis(position, velocity, target, deltaTime)
		local acceleration = ((target - position) * SPRING_STIFFNESS) - (velocity * SPRING_DAMPING)
		velocity += acceleration * deltaTime
		position += velocity * deltaTime
		return position, velocity
	end

	local function removeStowedRodClone(character)
		local backpackVisual = character and character:FindFirstChild("FishingBackpackVisual")
		local stowedRod = backpackVisual and backpackVisual:FindFirstChild("StowedFishingRodVisual")
		if stowedRod then
			-- This is only the cosmetic backpack clone. Removing it locally prevents a
			-- replicated replacement from flashing for a frame while the real rod is held.
			stowedRod:Destroy()
		end
	end

	local function bindStowedRodSuppression(character)
		if not character or stowedRodConnections[character] then
			return
		end

		stowedRodConnections[character] = character.DescendantAdded:Connect(function(descendant)
			if descendant.Name == "Fishing Rod" or descendant.Name == "StowedFishingRodVisual" then
				task.defer(function()
					local heldRod = character:FindFirstChild("Fishing Rod")
					if heldRod and heldRod:IsA("Tool") then
						removeStowedRodClone(character)
					end
				end)
			end
		end)
	end

	RunService.PreSimulation:Connect(function(deltaTime)
		local step = math.min(deltaTime, 1 / 20)
		local activeTools = {}

		for _, observedPlayer in ipairs(Players:GetPlayers()) do
			local character = observedPlayer.Character
			bindStowedRodSuppression(character)
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local tool = character and character:FindFirstChild("Fishing Rod")
			if tool and tool:IsA("Tool") then
				removeStowedRodClone(character)
			end

			if rootPart and humanoid and tool and tool:IsA("Tool") then
				local state = getState(tool)
				if jointsAreValid(state.joints) then
					activeTools[tool] = true
					local movementVelocity = rootPart.AssemblyLinearVelocity
					if humanoid.MoveDirection.Magnitude > 0.01 then
						movementVelocity = humanoid.MoveDirection * humanoid.WalkSpeed
					end
					local localVelocity = rootPart.CFrame:VectorToObjectSpace(movementVelocity)
					local horizontalSpeed = Vector3.new(localVelocity.X, 0, localVelocity.Z).Magnitude
					local walkScale = math.clamp(horizontalSpeed / math.max(humanoid.WalkSpeed, 1), 0, 1.25)
					local stepPhase = (os.clock() * STEP_FREQUENCY) + ((observedPlayer.UserId % 17) * 0.31)
					local targetPitch = math.clamp(localVelocity.Z * FORWARD_SWAY_PER_SPEED, -MAX_SWAY, MAX_SWAY)
					local targetRoll = math.clamp(-localVelocity.X * SIDE_SWAY_PER_SPEED, -MAX_SWAY, MAX_SWAY)
					targetRoll += math.sin(stepPhase) * STEP_SWAY * walkScale

					state.pitch, state.pitchVelocity = springAxis(state.pitch, state.pitchVelocity, targetPitch, step)
					state.roll, state.rollVelocity = springAxis(state.roll, state.rollVelocity, targetRoll, step)
					state.pitch = math.clamp(state.pitch, -MAX_SWAY, MAX_SWAY)
					state.roll = math.clamp(state.roll, -MAX_SWAY, MAX_SWAY)
					local castFlex = math.clamp(
						tonumber(tool:GetAttribute(CAST_FLEX_ATTRIBUTE)) or 0,
						math.rad(-12),
						math.rad(12)
					)
					local castTwist = math.clamp(
						tonumber(tool:GetAttribute(CAST_TWIST_ATTRIBUTE)) or 0,
						math.rad(-5),
						math.rad(5)
					)
					local castSide = math.clamp(
						tonumber(tool:GetAttribute(CAST_SIDE_ATTRIBUTE)) or 0,
						0,
						1
					)
					local lineSwing = math.clamp(
						tonumber(tool:GetAttribute(CAST_LINE_SWING_ATTRIBUTE)) or 0,
						0,
						1
					)
					-- During the casting game, angle only the hanging line and bobber
					-- downward from the rod tip. At castSide = 0 the imported idle pose
					-- remains untouched.
					local castSideCorrection = (math.pi / 2) * castSide
					local transform = CFrame.Angles(
						state.pitch - castFlex,
						castTwist,
						state.roll + castSideCorrection
					)
					for _, joint in ipairs(state.joints) do
						joint.Transform = transform
					end
					setCastingLineActive(tool, state, castSide > 0.001, lineSwing)
				end
			end
		end

		for tool, state in pairs(swayStates) do
			if not activeTools[tool] then
				resetState(state)
				swayStates[tool] = nil
			end
		end
	end)
end

startFishingRodSway()
