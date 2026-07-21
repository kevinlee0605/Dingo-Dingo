local FishingWater = {}

FishingWater.NEARBY_RADIUS = 20
FishingWater.MAX_NEARBY_VERTICAL_DIFFERENCE = 18

local NEARBY_DISTANCES = { 0, 5, 10, 15, 20 }
local NEARBY_ANGLES = { 0, 45, 90, 135, 180, 225, 270, 315 }
local CAST_DISTANCES = { 6, 9, 12, 15, 18, 21, 25, 30, 36, 44 }
local CAST_ANGLES = { 0, 12, -12, 24, -24, 36, -36, 48, -48, 60, -60, 72, -72 }

local function makeRaycastParams(ignoreInstances)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreInstances or {}
	params.IgnoreWater = false
	return params
end

local function isWaterResult(result)
	if not result then
		return false
	end

	if result.Material == Enum.Material.Water then
		return true
	end

	local instance = result.Instance
	if instance and type(instance:GetAttribute("FishingWaterSurfaceY")) == "number" then
		return true
	end

	local lowerName = instance and string.lower(instance.Name) or ""
	return string.find(lowerName, "water", 1, true) ~= nil
		or string.find(lowerName, "ocean surface", 1, true) ~= nil
		or string.find(lowerName, "oceansurface", 1, true) ~= nil
		or string.find(lowerName, "pond surface", 1, true) ~= nil
		or string.find(lowerName, "pondsurface", 1, true) ~= nil
		or string.find(lowerName, "river surface", 1, true) ~= nil
		or string.find(lowerName, "riversurface", 1, true) ~= nil
end

local function castDown(candidate, referenceY, params, rayHeight, rayDepth)
	local origin = Vector3.new(candidate.X, referenceY + rayHeight, candidate.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -rayDepth, 0), params)
	if isWaterResult(result) then
		local authoredSurfaceY = result.Instance:GetAttribute("FishingWaterSurfaceY")
		if type(authoredSurfaceY) == "number" then
			return Vector3.new(result.Position.X, authoredSurfaceY, result.Position.Z), result
		end
		return result.Position, result
	end
	return nil, nil
end

function FishingWater.findNearbySurface(position, ignoreInstances, radius)
	local searchRadius = math.max(0, tonumber(radius) or FishingWater.NEARBY_RADIUS)
	local params = makeRaycastParams(ignoreInstances)

	for _, rawDistance in ipairs(NEARBY_DISTANCES) do
		local distance = rawDistance == 0 and 0 or math.min(rawDistance, searchRadius)
		if rawDistance > searchRadius and rawDistance ~= 0 then
			continue
		end

		local angles = distance == 0 and { 0 } or NEARBY_ANGLES
		for _, angleDegrees in ipairs(angles) do
			local angle = math.rad(angleDegrees)
			local candidate = position + Vector3.new(
				math.cos(angle) * distance,
				0,
				math.sin(angle) * distance
			)
			local surfacePosition, result = castDown(candidate, position.Y, params, 30, 150)
			if surfacePosition
				and math.abs(surfacePosition.Y - position.Y) <= FishingWater.MAX_NEARBY_VERTICAL_DIFFERENCE
			then
				return surfacePosition, result
			end
		end
	end

	return nil, nil
end

function FishingWater.isNearWater(position, ignoreInstances, radius)
	return FishingWater.findNearbySurface(position, ignoreInstances, radius) ~= nil
end

function FishingWater.findCastSurface(origin, forward, side, ignoreInstances, options)
	options = options or {}
	local horizontalForward = Vector3.new(forward.X, 0, forward.Z)
	if horizontalForward.Magnitude < 0.0001 then
		return nil, nil
	end
	horizontalForward = horizontalForward.Unit

	local horizontalSide = Vector3.new(side.X, 0, side.Z)
	if horizontalSide.Magnitude < 0.0001 then
		horizontalSide = Vector3.new(-horizontalForward.Z, 0, horizontalForward.X)
	else
		horizontalSide = horizontalSide.Unit
	end

	local params = makeRaycastParams(ignoreInstances)
	local distances = options.distances or CAST_DISTANCES
	local angles = options.angles or CAST_ANGLES
	local sideOffset = tonumber(options.sideOffset) or 0
	local rayHeight = tonumber(options.rayHeight) or 30
	local rayDepth = tonumber(options.rayDepth) or 160

	for _, distance in ipairs(distances) do
		for _, angleDegrees in ipairs(angles) do
			local angle = math.rad(angleDegrees)
			local direction = (horizontalForward * math.cos(angle))
				+ (horizontalSide * math.sin(angle))
			if direction.Magnitude > 0.0001 then
				direction = direction.Unit
			end

			local candidate = origin
				+ (direction * distance)
				+ (horizontalSide * sideOffset)
			local surfacePosition, result = castDown(candidate, origin.Y, params, rayHeight, rayDepth)
			if surfacePosition then
				return surfacePosition, result
			end
		end
	end

	return nil, nil
end

return FishingWater
