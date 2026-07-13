-- Run in Roblox Studio edit mode after Rojo is connected.
-- Replaces Workspace.LilyshoreIsland with Workspace.LilyshoreIsland_New while
-- preserving the old island's gameplay identity, portals, fishing zone, and warps.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

local oldIsland = workspace:FindFirstChild("LilyshoreIsland")
local newIsland = workspace:FindFirstChild("LilyshoreIsland_New")

assert(oldIsland and oldIsland:IsA("Model"), "Workspace.LilyshoreIsland was not found or is not a Model")
assert(newIsland and newIsland:IsA("Model"), "Workspace.LilyshoreIsland_New was not found or is not a Model")

local function findNamedBasePart(root, name)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == name and descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function copyAttributes(source, target)
	for name, value in pairs(source:GetAttributes()) do
		if name ~= "RBX_ReimportId" and name ~= "FishyFishAreaPortalConnected" then
			target:SetAttribute(name, value)
		end
	end
end

local function copyTags(source, target)
	for _, tag in ipairs(CollectionService:GetTags(source)) do
		CollectionService:AddTag(target, tag)
	end
end

local function uniqueBackupName()
	local baseName = "LilyshoreIsland_PreReplacementBackup_" .. os.date("%Y%m%d_%H%M%S")
	local candidate = baseName
	local suffix = 2
	while ServerStorage:FindFirstChild(candidate) do
		candidate = baseName .. "_" .. suffix
		suffix += 1
	end
	return candidate
end

ChangeHistoryService:SetWaypoint("Before replacing Lilyshore Island")

-- The two imports use the same local origin. Matching pivots puts every new
-- visual feature, including the portal meshes, at the old island's location.
newIsland:PivotTo(oldIsland:GetPivot())

copyAttributes(oldIsland, newIsland)
copyTags(oldIsland, newIsland)
newIsland:SetAttribute("IslandId", "LilyshoreIsland")
newIsland:SetAttribute("BiomeId", "LilyshoreIsland")
newIsland:SetAttribute("LegacyBiomeId", "BeginnerPond")
newIsland:SetAttribute("FishTableId", "LilyshoreIsland")
newIsland:SetAttribute("QuestAreaId", "LilyshoreIsland")
CollectionService:AddTag(newIsland, "FishingIsland")
CollectionService:AddTag(newIsland, "LilyshoreIsland")

local compatibility = newIsland:FindFirstChild("BeginnerPondArea") or newIsland:FindFirstChild("world")
assert(compatibility and (compatibility:IsA("Model") or compatibility:IsA("Folder")), "New island world container was not found")
compatibility.Name = "BeginnerPondArea"
compatibility:SetAttribute("IslandId", "LilyshoreIsland")
compatibility:SetAttribute("LegacyBiomeId", "BeginnerPond")

local gameplay = compatibility:FindFirstChild("Gameplay")
if not gameplay then
	gameplay = Instance.new("Folder")
	gameplay.Name = "Gameplay"
	gameplay.Parent = compatibility
end

local oldZone = findNamedBasePart(oldIsland, "LilyshoreFishingZone")
assert(oldZone, "Old LilyshoreFishingZone was not found")
local newZone = findNamedBasePart(newIsland, "LilyshoreFishingZone")
if not newZone then
	newZone = oldZone:Clone()
	newZone.Parent = gameplay
end
newZone.Name = "LilyshoreFishingZone"
newZone.Anchored = true
newZone.CanCollide = false
newZone.CanTouch = false
newZone.CanQuery = true
newZone.Transparency = 1
newZone:SetAttribute("IslandId", "LilyshoreIsland")
newZone:SetAttribute("BiomeId", "LilyshoreIsland")
newZone:SetAttribute("LegacyBiomeId", "BeginnerPond")
copyAttributes(oldZone, newZone)
copyTags(oldZone, newZone)
CollectionService:AddTag(newZone, "FishingZone")

for _, spawnName in ipairs({ "LilyshoreSpawn_FromSeaside", "LilyshoreSpawn_FromAquarium" }) do
	local oldSpawn = findNamedBasePart(oldIsland, spawnName)
	assert(oldSpawn, "Old spawn marker was not found: " .. spawnName)
	local newSpawn = findNamedBasePart(newIsland, spawnName)
	if not newSpawn then
		newSpawn = oldSpawn:Clone()
		newSpawn.Parent = newIsland
	end
	newSpawn.Name = spawnName
	newSpawn.Anchored = true
	newSpawn.CanTouch = false
	newSpawn:SetAttribute("IslandId", "LilyshoreIsland")
	copyAttributes(oldSpawn, newSpawn)
	copyTags(oldSpawn, newSpawn)
end

local portalTargets = {
	Lilyshore_Portal_Aquarium_Surface = { target = "AquariumHub", display = "Aquarium Hub" },
	Lilyshore_Portal_Seaside_Surface = { target = "Lobby", display = "Seaside Island" },
}

for partName, portal in pairs(portalTargets) do
	local oldPart = findNamedBasePart(oldIsland, partName)
	local newPart = findNamedBasePart(newIsland, partName)
	assert(newPart, "New portal surface was not found: " .. partName)
	if oldPart then
		copyAttributes(oldPart, newPart)
		copyTags(oldPart, newPart)
		newPart.CanCollide = oldPart.CanCollide
		newPart.CanQuery = oldPart.CanQuery
		newPart.Transparency = oldPart.Transparency
	end
	newPart.Anchored = true
	newPart.CanTouch = true
	newPart:SetAttribute("TargetArea", portal.target)
	newPart:SetAttribute("PortalName", portal.display)
	newPart:SetAttribute("SourceArea", "LilyshoreIsland")
	CollectionService:AddTag(newPart, "AreaPortal")
end

for _, descendant in ipairs(newIsland:GetDescendants()) do
	if descendant:IsA("BasePart") then
		descendant.Anchored = true
	end
end

local backupName = uniqueBackupName()
oldIsland.Name = backupName
oldIsland.Parent = ServerStorage
newIsland.Name = "LilyshoreIsland"

Selection:Set({ newIsland })
ChangeHistoryService:SetWaypoint("Replaced Lilyshore Island with new model")

print(
	"[LilyshoreReplacement] Complete",
	"active=", newIsland:GetFullName(),
	"backup=", ServerStorage:FindFirstChild(backupName):GetFullName(),
	"pivot=", newIsland:GetPivot(),
	"zone=", findNamedBasePart(newIsland, "LilyshoreFishingZone") ~= nil,
	"seasideSpawn=", findNamedBasePart(newIsland, "LilyshoreSpawn_FromSeaside") ~= nil,
	"aquariumSpawn=", findNamedBasePart(newIsland, "LilyshoreSpawn_FromAquarium") ~= nil,
	"seasidePortal=", findNamedBasePart(newIsland, "Lilyshore_Portal_Seaside_Surface") ~= nil,
	"aquariumPortal=", findNamedBasePart(newIsland, "Lilyshore_Portal_Aquarium_Surface") ~= nil
)
