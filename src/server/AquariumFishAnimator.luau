local AquariumFishAnimator = {}

-- Runtime state is intentionally kept outside Instances. Attributes are cloned,
-- but weak-table entries are not, so a gallery clone can start exactly one new
-- animation loop without inheriting the source aquarium's running-loop state.
local activeRoots = setmetatable({}, { __mode = "k" })

function AquariumFishAnimator.getSwimLane(origin, index, dimensions)
	local lane = (index - 1) % 24
	local layer = lane % 4
	local centerOffset = Vector3.new(
		0,
		3.6 + (layer * math.max(1.1, dimensions.tankHeight * 0.11)),
		0
	)

	return {
		center = if typeof(origin) == "CFrame"
			then origin:PointToWorldSpace(centerOffset)
			else origin + centerOffset,
		localCenter = centerOffset,
		xRadius = math.max(5.5, (dimensions.tankWidth / 2) - 4 - (layer * 0.35)),
		zRadius = math.max(2.4, (dimensions.tankDepth / 2) - 2.4 - ((layer % 2) * 0.25)),
		heightDrift = math.max(0.24, dimensions.tankHeight * 0.035),
	}
end

function AquariumFishAnimator.start(part, origin, index, seed, dimensions, container)
	if activeRoots[part] then
		return false
	end
	activeRoots[part] = true

	local random = Random.new(seed)
	local lane = AquariumFishAnimator.getSwimLane(origin, index, dimensions)
	local phase = random:NextNumber(0, math.pi * 2)
	local direction = random:NextInteger(0, 1) == 0 and -1 or 1
	local angularSpeed = random:NextNumber(0.5, 0.75) * direction
	local swaySpeed = random:NextNumber(0.8, 1.3)
	local heightPhase = random:NextNumber(0, math.pi * 2)
	local sidePhase = random:NextNumber(0, math.pi * 2)
	local sideDrift = random:NextNumber(0.22, 0.46)
	local localFrame = if typeof(origin) == "CFrame" then origin else nil

	task.spawn(function()
		local startedAt = os.clock()
		local lastPosition = part.Position
		local lookVector = if localFrame
			then localFrame:VectorToWorldSpace(Vector3.new(direction, 0, 0))
			else Vector3.new(direction, 0, 0)
		local lastTick = os.clock()

		while part.Parent
			and (not container or (container.Parent and part:IsDescendantOf(container)))
		do
			local now = os.clock()
			local deltaTime = math.clamp(now - lastTick, 0.016, 0.12)
			lastTick = now

			local elapsed = now - startedAt
			local currentPhase = phase + (elapsed * angularSpeed)
			local positionOffset = Vector3.new(
				math.cos(currentPhase) * lane.xRadius,
				math.sin((elapsed * swaySpeed) + heightPhase) * lane.heightDrift,
				(math.sin(currentPhase) * lane.zRadius) + (math.sin((elapsed * 0.7) + sidePhase) * sideDrift)
			)
			local position = if localFrame
				then localFrame:PointToWorldSpace(lane.localCenter + positionOffset)
				else lane.center + positionOffset

			local moveDirection = position - lastPosition
			if moveDirection.Magnitude > 0.01 then
				local turnAlpha = math.clamp(deltaTime * 2.8, 0, 1)
				lookVector = lookVector:Lerp(moveDirection.Unit, turnAlpha)
				if lookVector.Magnitude < 0.01 then
					lookVector = moveDirection.Unit
				else
					lookVector = lookVector.Unit
				end
			end

			if localFrame then
				part.CFrame = CFrame.lookAt(position, position + lookVector, localFrame.UpVector)
			else
				-- Keep the normal-aquarium assignment byte-for-byte equivalent
				-- to the pre-gallery implementation.
				part.CFrame = CFrame.lookAt(position, position + lookVector)
			end
			lastPosition = position
			task.wait(0.05)
		end

		activeRoots[part] = nil
	end)

	return true
end

function AquariumFishAnimator.getTankContext(tank)
	local base = tank:FindFirstChild("AquariumBase", true)
	if not base or not base:IsA("BasePart") then
		return nil, nil
	end

	local front = tank:FindFirstChild("GlassFront", true)
	local left = tank:FindFirstChild("GlassLeft", true)
	local tankWidth = tonumber(tank:GetAttribute("AquariumTankWidth"))
		or (front and front:IsA("BasePart") and front.Size.X)
	local tankHeight = tonumber(tank:GetAttribute("AquariumTankHeight"))
		or (front and front:IsA("BasePart") and front.Size.Y)
	local tankDepth = tonumber(tank:GetAttribute("AquariumTankDepth"))
		or (left and left:IsA("BasePart") and left.Size.Z)
	if not tankWidth or not tankHeight or not tankDepth then
		return nil, nil
	end

	local originYOffset = tonumber(tank:GetAttribute("AquariumFishOriginYOffsetFromBase")) or 2
	return base.CFrame * CFrame.new(0, originYOffset, 0), {
		tankWidth = tankWidth,
		tankHeight = tankHeight,
		tankDepth = tankDepth,
	}
end

return AquariumFishAnimator
