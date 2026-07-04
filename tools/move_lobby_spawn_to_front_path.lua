-- Run this in Roblox Studio's Command Bar to move the player lobby spawn.
-- It updates Workspace.LobbyDefinition so the editor place and play tests use the
-- same front-center brick path spawn point.

local Workspace = game:GetService("Workspace")

local TARGET_FALLBACK = Vector3.new(-147, 10, -492)
local LOBBY_DEFINITION_FOLDER_NAME = "LobbyDefinition"
local LOBBY_SPAWN_NAME = "LobbySpawn"
local LIMESTONE_SPAWN_NAME = "LimestoneLobbySpawn"

local function findLobbyArea()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "LobbyArea" then
			return descendant
		end
	end

	return nil
end

local function isPathPart(part)
	local lowerName = string.lower(part.Name)
	return part.Material == Enum.Material.Brick
		or string.find(lowerName, "path") ~= nil
		or string.find(lowerName, "brick") ~= nil
end

local function getLobbyCenterX(lobby)
	local minX = math.huge
	local maxX = -math.huge

	for _, descendant in ipairs(lobby:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Size.X >= 3 and descendant.Size.Z >= 3 and descendant.Position.Y < 12 then
			minX = math.min(minX, descendant.Position.X - descendant.Size.X / 2)
			maxX = math.max(maxX, descendant.Position.X + descendant.Size.X / 2)
		end
	end

	if minX == math.huge then
		return TARGET_FALLBACK.X
	end

	return (minX + maxX) / 2
end

local function getFrontPathPosition(lobby)
	if not lobby then
		return TARGET_FALLBACK
	end

	local centerX = getLobbyCenterX(lobby)
	local bestZ = math.huge
	local sumX = 0
	local count = 0

	for _, descendant in ipairs(lobby:GetDescendants()) do
		if descendant:IsA("BasePart") and isPathPart(descendant) and math.abs(descendant.Position.X - centerX) <= 12 then
			if descendant.Position.Z < bestZ - 0.1 then
				bestZ = descendant.Position.Z
				sumX = descendant.Position.X
				count = 1
			elseif math.abs(descendant.Position.Z - bestZ) <= 0.1 then
				sumX += descendant.Position.X
				count += 1
			end
		end
	end

	if count == 0 then
		return TARGET_FALLBACK
	end

	return Vector3.new(sumX / count, TARGET_FALLBACK.Y, bestZ)
end

local function getGroundPosition(targetXZ, ignoreInstances)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreInstances or {}

	local result = Workspace:Raycast(Vector3.new(targetXZ.X, 220, targetXZ.Z), Vector3.new(0, -500, 0), params)
	if result then
		return result.Position
	end

	return Vector3.new(targetXZ.X, 3, targetXZ.Z)
end

local definition = Workspace:FindFirstChild(LOBBY_DEFINITION_FOLDER_NAME)
if not definition then
	definition = Instance.new("Folder")
	definition.Name = LOBBY_DEFINITION_FOLDER_NAME
	definition.Parent = Workspace
end

local lobby = findLobbyArea()
local targetXZ = getFrontPathPosition(lobby)
local ignore = { definition }
local ground = getGroundPosition(targetXZ, ignore)
local spawnPosition = Vector3.new(targetXZ.X, ground.Y + 0.6, targetXZ.Z)

local spawn = definition:FindFirstChild(LOBBY_SPAWN_NAME)
if spawn and not spawn:IsA("SpawnLocation") then
	spawn:Destroy()
	spawn = nil
end
if not spawn then
	spawn = Instance.new("SpawnLocation")
	spawn.Name = LOBBY_SPAWN_NAME
	spawn.Parent = definition
end

spawn.Size = Vector3.new(10, 1, 10)
spawn.Position = spawnPosition
spawn.Anchored = true
spawn.Neutral = true
spawn.Transparency = 1
spawn.CanCollide = false
spawn.CanTouch = false
spawn.CanQuery = true
spawn.Material = Enum.Material.SmoothPlastic
spawn.Color = Color3.fromRGB(80, 180, 255)
spawn:SetAttribute("Purpose", "Player lobby spawn")

for _, descendant in ipairs(spawn:GetDescendants()) do
	if descendant:IsA("Decal") or descendant:IsA("Texture") then
		descendant:Destroy()
	end
end

local marker = definition:FindFirstChild(LIMESTONE_SPAWN_NAME)
if marker and not marker:IsA("BasePart") then
	marker:Destroy()
	marker = nil
end
if not marker then
	marker = Instance.new("Part")
	marker.Name = LIMESTONE_SPAWN_NAME
	marker.Parent = definition
end

marker.Size = Vector3.new(8, 0.4, 8)
marker.Position = spawnPosition
marker.Anchored = true
marker.Transparency = 1
marker.CanCollide = false
marker.CanTouch = false
marker.CanQuery = true
marker.Material = Enum.Material.SmoothPlastic
marker.Color = Color3.fromRGB(80, 180, 255)
marker:SetAttribute("Purpose", "Lobby teleport marker")

print(("Lobby spawn moved to front-center path at %.1f, %.1f, %.1f."):format(spawnPosition.X, spawnPosition.Y, spawnPosition.Z))
