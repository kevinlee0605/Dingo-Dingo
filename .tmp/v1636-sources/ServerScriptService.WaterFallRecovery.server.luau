local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Terrain = workspace.Terrain

-- Players can swim down to the sand seabed. Recovery is only a final safeguard
-- if they somehow pass through that floor toward the hidden baseplate.
local MINIMUM_ALLOWED_Y = -55
local SAMPLE_INTERVAL = 0.15
local RECOVERY_LIFT = 3
local SAND_FLOOR_NAME = "UnderwaterSandFloor"
local SAND_FLOOR_POSITION = Vector3.new(0, -32, 0)
local SAND_FLOOR_SIZE = Vector3.new(2048, 4, 2048)
local OCEAN_WATER_CENTER = Vector3.new(0, -22, 0)
local OCEAN_WATER_SIZE = Vector3.new(2048, 16, 2048)
local OCEAN_WATER_SAMPLE = Vector3.new(900, -20, 900)

local lastSafeCFrames = {}
local recoveringPlayers = {}

local FALLBACK_MARKER_NAMES = {
	LilyshoreSpawn_FromSeaside = true,
	LilyshoreSpawn_FromAquarium = true,
	LimestoneLobbySpawn = true,
	LobbySpawn = true,
}

local function ensureOceanWaterVolume()
	local halfCell = Vector3.new(2, 2, 2)
	local sampleRegion = Region3.new(
		OCEAN_WATER_SAMPLE - halfCell,
		OCEAN_WATER_SAMPLE + halfCell
	):ExpandToGrid(4)
	local materials = Terrain:ReadVoxels(sampleRegion, 4)

	if materials[1][1][1] ~= Enum.Material.Water then
		Terrain:FillBlock(
			CFrame.new(OCEAN_WATER_CENTER),
			OCEAN_WATER_SIZE,
			Enum.Material.Water
		)
		print("[WaterFallRecovery] Added ocean swimming volume")
	end
end

local function ensureUnderwaterSandFloor()
	local floor = workspace:FindFirstChild(SAND_FLOOR_NAME)
	if floor and not floor:IsA("BasePart") then
		warn("[WaterFallRecovery] " .. SAND_FLOOR_NAME .. " exists but is not a BasePart")
		return nil
	end

	if not floor then
		floor = Instance.new("Part")
		floor.Name = SAND_FLOOR_NAME
		floor.Parent = workspace
	end

	floor.Anchored = true
	floor.Size = SAND_FLOOR_SIZE
	floor.Position = SAND_FLOOR_POSITION
	floor.Material = Enum.Material.Sand
	floor.Color = Color3.fromRGB(194, 178, 128)
	floor.Transparency = 0
	floor.CanCollide = true
	floor.CanTouch = false
	floor.CanQuery = true
	floor.CastShadow = false
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor:SetAttribute("FishyFishUnderwaterSeabed", true)
	return floor
end

local function getCharacterState(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, rootPart
end

local function rememberSafeGround(player, humanoid, rootPart)
	if rootPart.Position.Y <= MINIMUM_ALLOWED_Y + 5 then
		return
	end

	local floorMaterial = humanoid.FloorMaterial
	if floorMaterial == Enum.Material.Air or floorMaterial == Enum.Material.Water then
		return
	end

	lastSafeCFrames[player] = rootPart.CFrame
end

local function getNearestFallbackCFrame(position)
	local bestPart = nil
	local bestDistance = math.huge

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and FALLBACK_MARKER_NAMES[descendant.Name] then
			local offset = descendant.Position - position
			local horizontalDistance = Vector2.new(offset.X, offset.Z).Magnitude
			if horizontalDistance < bestDistance then
				bestDistance = horizontalDistance
				bestPart = descendant
			end
		end
	end

	if not bestPart then
		return nil
	end

	return bestPart.CFrame * CFrame.new(0, (bestPart.Size.Y / 2) + 4, 0)
end

local function recoverPlayer(player, character, humanoid, rootPart)
	if recoveringPlayers[player] then
		return
	end

	recoveringPlayers[player] = true
	local destination = lastSafeCFrames[player] or getNearestFallbackCFrame(rootPart.Position)

	if destination then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		character:PivotTo(destination + Vector3.new(0, RECOVERY_LIFT, 0))
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		print("[WaterFallRecovery] Recovered", player.Name)
	else
		-- This should only happen before the map's spawn markers are available.
		humanoid.Health = 0
		warn("[WaterFallRecovery] No safe position was available for", player.Name)
	end

	task.delay(0.5, function()
		recoveringPlayers[player] = nil
	end)
end

local function trackPlayer(player)
	player.CharacterAdded:Connect(function()
		lastSafeCFrames[player] = nil
		recoveringPlayers[player] = nil
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	trackPlayer(player)
end

ensureOceanWaterVolume()
ensureUnderwaterSandFloor()

Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(function(player)
	lastSafeCFrames[player] = nil
	recoveringPlayers[player] = nil
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(deltaTime)
	elapsed += deltaTime
	if elapsed < SAMPLE_INTERVAL then
		return
	end
	elapsed = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local character, humanoid, rootPart = getCharacterState(player)
		if not (character and humanoid and rootPart) or humanoid.Health <= 0 then
			continue
		end

		if rootPart.Position.Y < MINIMUM_ALLOWED_Y then
			recoverPlayer(player, character, humanoid, rootPart)
		else
			rememberSafeGround(player, humanoid, rootPart)
		end
	end
end)

print("[WaterFallRecovery] Started at Y", MINIMUM_ALLOWED_Y)
