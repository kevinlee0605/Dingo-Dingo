local IslandConfig = {}

IslandConfig.SeasideIslandId = "SeasideIsland"
IslandConfig.AquariumHubId = "AquariumHub"

IslandConfig.LegacyIdToIslandId = {
	BeginnerPond = "LilyshoreIsland",
	River = "RiverbendIsland",
	Ocean = "CoralCoastIsland",
	Lobby = "SeasideIsland",
	Home = "AquariumHub",
	AquariumArea = "AquariumHub",
}

IslandConfig.IslandIdToLegacyId = {
	LilyshoreIsland = "BeginnerPond",
	RiverbendIsland = "River",
	CoralCoastIsland = "Ocean",
	SeasideIsland = "Lobby",
	AquariumHub = "Home",
}

IslandConfig.Order = {
	"LilyshoreIsland",
	"RiverbendIsland",
	"CoralCoastIsland",
}

function IslandConfig.normalizeIslandId(areaId)
	if type(areaId) ~= "string" then
		return nil
	end

	return IslandConfig.LegacyIdToIslandId[areaId] or areaId
end

function IslandConfig.getLegacyId(islandId)
	islandId = IslandConfig.normalizeIslandId(islandId)
	return islandId and IslandConfig.IslandIdToLegacyId[islandId] or nil
end

return IslandConfig
