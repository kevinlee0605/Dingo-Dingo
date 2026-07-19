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
	local MAX_SWAY = math.rad(6)
	local FORWARD_SWAY_PER_SPEED = math.rad(0.28)
	local SIDE_SWAY_PER_SPEED = math.rad(0.32)
	local STEP_SWAY = math.rad(0.8)
	local SPRING_STIFFNESS = 48
	local SPRING_DAMPING = 9
	local STEP_FREQUENCY = 8
	local swayStates = setmetatable({}, { __mode = "k" })

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

	local function resetState(state)
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
			}
			swayStates[tool] = state
		end
		if not jointsAreValid(state.joints) then
			state.joints = getSwayJoints(tool)
		end
		return state
	end

	local function springAxis(position, velocity, target, deltaTime)
		local acceleration = ((target - position) * SPRING_STIFFNESS) - (velocity * SPRING_DAMPING)
		velocity += acceleration * deltaTime
		position += velocity * deltaTime
		return position, velocity
	end

	RunService.PreSimulation:Connect(function(deltaTime)
		local step = math.min(deltaTime, 1 / 20)
		local activeTools = {}

		for _, observedPlayer in ipairs(Players:GetPlayers()) do
			local character = observedPlayer.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local tool = character and character:FindFirstChild("Fishing Rod")

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
					local transform = CFrame.Angles(state.pitch + castFlex, castTwist, state.roll)
					for _, joint in ipairs(state.joints) do
						joint.Transform = transform
					end
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
