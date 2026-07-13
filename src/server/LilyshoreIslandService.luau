local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local LilyshoreIslandService = {}

local ISLAND_NAME = "LilyshoreIsland"
local LEGACY_AREA_NAME = "BeginnerPond"
local BACKUP_NAME = "BeginnerPond_ExtraLarge"

local SPAWN_NAMES = {
	SeasideIsland = "LilyshoreSpawn_FromSeaside",
	Lobby = "LilyshoreSpawn_FromSeaside",
	AquariumHub = "LilyshoreSpawn_FromAquarium",
	Home = "LilyshoreSpawn_FromAquarium",
	MyAquarium = "LilyshoreSpawn_FromAquarium",
}

local PORTAL_TARGETS = {
	Lilyshore_Portal_Aquarium_Surface = "AquariumHub",
	Lilyshore_Portal_Seaside_Surface = "Lobby",
}

local function findIsland()
	local island = workspace:FindFirstChild(ISLAND_NAME)
	if island and island:IsA("PVInstance") then
		return island
	end

	return nil
end

local function findBackup()
	local backup = ServerStorage:FindFirstChild(BACKUP_NAME, true)
	if backup and backup:IsA("PVInstance") then
		return backup
	end

	return nil
end

local function findNamedBasePart(root, name)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == name and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function copyTags(source, target)
	for _, tag in ipairs(CollectionService:GetTags(source)) do
		CollectionService:AddTag(target, tag)
	end
end

local function copyAttributes(source, target)
	for name, value in pairs(source:GetAttributes()) do
		if target:GetAttribute(name) == nil then
			target:SetAttribute(name, value)
		end
	end
end

local function ensureCompatibilityContainer(island)
	local compatibility = island:FindFirstChild("BeginnerPondArea")
	if compatibility then
		return compatibility
	end

	local importedWorld = island:FindFirstChild("world")
	if importedWorld and (importedWorld:IsA("Model") or importedWorld:IsA("Folder")) then
		importedWorld.Name = "BeginnerPondArea"
		return importedWorld
	end

	return island
end

local function getScaledZoneTransform(sourceRoot, targetRoot, sourceZone)
	local sourcePivot = sourceRoot:GetPivot()
	local targetPivot = targetRoot:GetPivot()
	local sourceSize = sourceRoot:GetExtentsSize()
	local targetSize = targetRoot:GetExtentsSize()
	local relative = sourcePivot:ToObjectSpace(sourceZone.CFrame)
	local relativePosition = relative.Position
	local relativeRotation = relative - relativePosition
	local scaleX = math.clamp(targetSize.X / math.max(sourceSize.X, 1), 0.2, 5)
	local scaleY = math.clamp(targetSize.Y / math.max(sourceSize.Y, 1), 0.2, 5)
	local scaleZ = math.clamp(targetSize.Z / math.max(sourceSize.Z, 1), 0.2, 5)

	local targetCFrame = targetPivot
		* CFrame.new(relativePosition.X * scaleX, relativePosition.Y * scaleY, relativePosition.Z * scaleZ)
		* relativeRotation
	local targetSizeValue = Vector3.new(
		math.max(8, sourceZone.Size.X * scaleX),
		math.max(10, sourceZone.Size.Y * scaleY),
		math.max(8, sourceZone.Size.Z * scaleZ)
	)

	return targetCFrame, targetSizeValue
end

local function ensureFishingZone(island, compatibility)
	local existing = island:FindFirstChild("LilyshoreFishingZone", true)
	if existing and existing:IsA("BasePart") then
		CollectionService:AddTag(existing, "FishingZone")
		existing:SetAttribute("IslandId", ISLAND_NAME)
		existing:SetAttribute("BiomeId", ISLAND_NAME)
		return existing
	end

	local backup = findBackup()
	local sourceZone = backup and backup:FindFirstChild("FishZone", true)
	if not (sourceZone and sourceZone:IsA("BasePart")) then
		warn("[LilyshoreIsland] Beginner Pond backup FishZone was not found; fishing still uses island ground detection.")
		return nil
	end

	local gameplay = compatibility:FindFirstChild("Gameplay")
	if not gameplay then
		gameplay = Instance.new("Folder")
		gameplay.Name = "Gameplay"
		gameplay.Parent = compatibility
	end

	local zone = sourceZone:Clone()
	zone.Name = "LilyshoreFishingZone"
	local targetCFrame, targetSize = getScaledZoneTransform(backup, island, sourceZone)
	zone.CFrame = targetCFrame
	zone.Size = targetSize
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanTouch = false
	zone.CanQuery = true
	zone.Transparency = 1
	zone:SetAttribute("IslandId", ISLAND_NAME)
	zone:SetAttribute("BiomeId", ISLAND_NAME)
	zone:SetAttribute("LegacyBiomeId", LEGACY_AREA_NAME)
	copyTags(sourceZone, zone)
	copyAttributes(sourceZone, zone)
	CollectionService:AddTag(zone, "FishingZone")
	zone.Parent = gameplay
	return zone
end

local function configureSpawn(island, spawnName, arrivalSource)
	local spawn = findNamedBasePart(island, spawnName)
	if not (spawn and spawn:IsA("BasePart")) then
		warn("[LilyshoreIsland] Missing spawn marker:", spawnName)
		return nil
	end

	spawn.Anchored = true
	spawn.CanTouch = false
	spawn:SetAttribute("IslandId", ISLAND_NAME)
	spawn:SetAttribute("ArrivalSource", arrivalSource)
	return spawn
end

local function configurePortals(island)
	for partName, targetArea in pairs(PORTAL_TARGETS) do
		local part = findNamedBasePart(island, partName)
		if part and part:IsA("BasePart") then
			part.CanTouch = true
			part:SetAttribute("TargetArea", targetArea)
			part:SetAttribute("PortalName", targetArea == "AquariumHub" and "Aquarium Hub" or "Seaside Island")
			part:SetAttribute("SourceArea", ISLAND_NAME)
			CollectionService:AddTag(part, "AreaPortal")
		else
			warn("[LilyshoreIsland] Missing portal surface:", partName)
		end
	end
end

local function removeGeneratedPlaceholder()
	local generatedWorld = workspace:FindFirstChild("FishyFishWorld")
	if not generatedWorld then
		return
	end

	for _, name in ipairs({
		"Lilyshore Island",
		"Lilyshore Island Island",
		"Lilyshore Island Water",
		"LilyshoreIslandDock",
		"Lilyshore Island Sign",
	}) do
		local placeholder = generatedWorld:FindFirstChild(name)
		if placeholder then
			placeholder:Destroy()
		end
	end
end

function LilyshoreIslandService.ensure()
	local island = findIsland()
	if not island then
		warn("[LilyshoreIsland] Workspace.LilyshoreIsland was not found.")
		return nil
	end

	local backup = findBackup()
	if backup then
		copyTags(backup, island)
		copyAttributes(backup, island)
	end

	island:SetAttribute("IslandId", ISLAND_NAME)
	island:SetAttribute("BiomeId", ISLAND_NAME)
	island:SetAttribute("LegacyBiomeId", LEGACY_AREA_NAME)
	island:SetAttribute("FishTableId", ISLAND_NAME)
	island:SetAttribute("QuestAreaId", ISLAND_NAME)
	CollectionService:AddTag(island, "FishingIsland")
	CollectionService:AddTag(island, ISLAND_NAME)

	local compatibility = ensureCompatibilityContainer(island)
	compatibility:SetAttribute("IslandId", ISLAND_NAME)
	compatibility:SetAttribute("LegacyBiomeId", LEGACY_AREA_NAME)
	ensureFishingZone(island, compatibility)
	configureSpawn(island, "LilyshoreSpawn_FromSeaside", "SeasideIsland")
	configureSpawn(island, "LilyshoreSpawn_FromAquarium", "AquariumHub")
	configurePortals(island)
	removeGeneratedPlaceholder()
	return island
end

function LilyshoreIslandService.isIslandInstance(instance)
	local island = findIsland()
	return island ~= nil and instance ~= nil and (instance == island or instance:IsDescendantOf(island))
end

function LilyshoreIslandService.getSpawnPart(sourceArea)
	local island = findIsland()
	if not island then
		return nil
	end

	local spawnName = SPAWN_NAMES[sourceArea] or SPAWN_NAMES.SeasideIsland
	local spawn = findNamedBasePart(island, spawnName)
	return spawn and spawn:IsA("BasePart") and spawn or nil
end

function LilyshoreIslandService.getSpawnCFrame(sourceArea)
	local spawn = LilyshoreIslandService.getSpawnPart(sourceArea)
	if not spawn then
		return nil
	end

	return spawn.CFrame * CFrame.new(0, (spawn.Size.Y / 2) + 4, 0)
end

return LilyshoreIslandService
