local IslandState = {}

function IslandState.create(deps)
	local GameConfig = deps.GameConfig
	local getState = deps.getState
	local helpers = {}

	function helpers.normalizeIslandId(areaId)
		if areaId == "Home" or areaId == "AquariumArea" then
			return "AquariumHub"
		elseif areaId == "Lobby" or areaId == "SeasideIsland" then
			return areaId
		end

		local legacyMap = GameConfig.LegacyBiomeIdToIslandId or {}
		if legacyMap[areaId] then
			return legacyMap[areaId]
		elseif GameConfig.normalizeIslandId then
			return GameConfig.normalizeIslandId(areaId) or areaId
		end

		if areaId == "BeginnerPond" then
			return "LilyshoreIsland"
		elseif areaId == "River" then
			return "RiverbendIsland"
		elseif areaId == "Ocean" then
			return "CoralCoastIsland"
		end

		return areaId
	end

	function helpers.getUnlockedIslands()
		local state = getState()
		return (state and (state.UnlockedIslands or state.UnlockedBiomes)) or {}
	end

	function helpers.getCurrentIslandId()
		local state = getState()
		return helpers.normalizeIslandId(state and (state.CurrentIsland or state.CurrentBiome))
	end

	function helpers.getActualIslandId()
		local state = getState()
		return helpers.normalizeIslandId(state and (state.ActualIsland or state.ActualBiome))
	end

	return helpers
end

return IslandState
