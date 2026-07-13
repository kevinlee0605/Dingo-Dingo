local LocationService = {}

function LocationService.new(ctx)
	local api = {}
	local GameConfig = ctx.GameConfig
	local player = ctx.player

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

		local result = workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -90, 0), params)
		if result and isLilyshoreIslandInstance(result.Instance) then
			return "LilyshoreIsland"
		end

		return nil
	end

	function api.getLocalFishingBiomeId()
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return nil
		end

		local groundBiomeId = getGroundBiomeId(rootPart.Position, character)
		if groundBiomeId then
			return groundBiomeId
		end

		for _, biomeId in ipairs(GameConfig.BiomeOrder) do
			if biomeId == "LilyshoreIsland" or biomeId == "BeginnerPond" then
				continue
			end

			local biome = GameConfig.Biomes[biomeId]
			local center = biome.position
			local dx = math.abs(rootPart.Position.X - center.X)
			local dz = math.abs(rootPart.Position.Z - center.Z)
			local rangeX = 58
			local rangeZ = 54

			if dx <= rangeX and dz <= rangeZ then
				return biomeId
			end
		end

		return nil
	end

	function api.getActiveFishingBiomeId()
		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			return api.getLocalFishingBiomeId()
		end

		local localBiomeId = api.getLocalFishingBiomeId()
		if localBiomeId then
			return localBiomeId
		end

		if not ctx.state or not ctx.state.ActualBiome or not GameConfig.Biomes[ctx.state.ActualBiome] then
			return nil
		end

		return ctx.state.ActualBiome
	end

	function api.getLocalTravelLocation()
		local localBiomeId = api.getLocalFishingBiomeId()
		if localBiomeId then
			return localBiomeId
		end

		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local lobby = GameConfig.Lobby
		local bounds = lobby and lobby.bounds
		if rootPart and bounds then
			local position = rootPart.Position
			if position.X >= bounds.minX
				and position.X <= bounds.maxX
				and position.Z >= bounds.minZ
				and position.Z <= bounds.maxZ
			then
				return "Lobby"
			end
		end

		return (ctx.state and ctx.state.ActualLocation) or "Lobby"
	end

	return api
end

return LocationService
