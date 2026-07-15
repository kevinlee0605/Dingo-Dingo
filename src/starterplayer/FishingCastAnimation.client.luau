local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local FishingPrompt = remotes:WaitForChild("FishingPrompt")
local Notice = remotes:WaitForChild("Notice")

local CAST_FRAME_NAMES = {
	"CastPowerContent",
	"ModernCastPowerUI",
}
local ROD_FLEX_ATTRIBUTE = "FishingRodCastFlex"
local ROD_TWIST_ATTRIBUTE = "FishingRodCastTwist"
local ROD_CAST_SIDE_ATTRIBUTE = "FishingRodCastSide"
local ROD_LINE_SWING_ATTRIBUTE = "FishingRodLineSwing"
local FORWARD_DURATION = 0.38
local FOLLOW_THROUGH_DURATION = 0.2
local RECOVERY_DURATION = 0.32
local CHARGE_RESPONSE = 12
local MINIGAME_HIDDEN_CONFIRMATION = 0.25

local POSE_KEYS = {
	"rightShoulder",
	"leftShoulder",
	"waist",
	"neck",
	"rightHip",
	"leftHip",
}

local JOINT_NAMES = {
	rightShoulder = { "RightShoulder", "Right Shoulder" },
	leftShoulder = { "LeftShoulder", "Left Shoulder" },
	waist = { "Waist", "RootJoint", "Root Joint" },
	neck = { "Neck" },
	rightHip = { "RightHip", "Right Hip" },
	leftHip = { "LeftHip", "Left Hip" },
}

local IDENTITY_POSE = {
	rightShoulder = CFrame.new(),
	leftShoulder = CFrame.new(),
	waist = CFrame.new(),
	neck = CFrame.new(),
	rightHip = CFrame.new(),
	leftHip = CFrame.new(),
}

local WINDUP_POSE = {
	rightShoulder = CFrame.Angles(math.rad(-72), math.rad(-16), math.rad(43)),
	leftShoulder = CFrame.Angles(math.rad(-20), math.rad(10), math.rad(-13)),
	waist = CFrame.Angles(math.rad(-7), math.rad(-23), math.rad(4)),
	neck = CFrame.Angles(math.rad(3), math.rad(12), math.rad(-2)),
	rightHip = CFrame.Angles(math.rad(2), math.rad(7), math.rad(-2)),
	leftHip = CFrame.Angles(math.rad(-2), math.rad(5), math.rad(1)),
}

local FORWARD_POSE = {
	rightShoulder = CFrame.Angles(math.rad(-116), math.rad(10), math.rad(-15)),
	leftShoulder = CFrame.Angles(math.rad(-34), math.rad(-8), math.rad(11)),
	waist = CFrame.Angles(math.rad(7), math.rad(24), math.rad(-5)),
	neck = CFrame.Angles(math.rad(-3), math.rad(-13), math.rad(2)),
	rightHip = CFrame.Angles(math.rad(-3), math.rad(-8), math.rad(2)),
	leftHip = CFrame.Angles(math.rad(3), math.rad(-6), math.rad(-1)),
}

local FOLLOW_THROUGH_POSE = {
	rightShoulder = CFrame.Angles(math.rad(-84), math.rad(12), math.rad(-27)),
	leftShoulder = CFrame.Angles(math.rad(-14), math.rad(-2), math.rad(5)),
	waist = CFrame.Angles(math.rad(3), math.rad(11), math.rad(-1)),
	neck = CFrame.Angles(math.rad(-1), math.rad(-6), 0),
	rightHip = CFrame.Angles(math.rad(-1), math.rad(-4), math.rad(1)),
	leftHip = CFrame.Angles(math.rad(1), math.rad(-3), 0),
}

local character = nil
local joints = nil
local phase = "idle"
local phaseStartedAt = 0
local activeCastInput = nil
local releaseStartPose = nil
local releaseStartFlex = 0
local releaseStartTwist = 0
local releaseStartSide = 0
local releaseStartLineSwing = 0
local currentPose = table.clone(IDENTITY_POSE)
local currentFlex = 0
local currentTwist = 0
local currentCastSide = 0
local currentLineSwing = 0
local flexTool = nil
local landedSawMinigame = false
local landedMinigameHiddenAt = nil
local activeFishingSessionId = nil

local function copyPose(pose)
	local result = {}
	for _, key in ipairs(POSE_KEYS) do
		result[key] = pose[key] or CFrame.new()
	end
	return result
end

local function lerpPose(fromPose, toPose, alpha)
	local clampedAlpha = math.clamp(alpha, 0, 1)
	local result = {}
	for _, key in ipairs(POSE_KEYS) do
		result[key] = (fromPose[key] or CFrame.new()):Lerp(toPose[key] or CFrame.new(), clampedAlpha)
	end
	return result
end

local function easeOutCubic(value)
	local inverse = 1 - math.clamp(value, 0, 1)
	return 1 - (inverse * inverse * inverse)
end

local function easeInOutSine(value)
	return -(math.cos(math.pi * math.clamp(value, 0, 1)) - 1) / 2
end

local function findJoint(jointsByName, aliases)
	for _, motorName in ipairs(aliases) do
		if jointsByName[motorName] then
			return jointsByName[motorName]
		end
	end
	return nil
end

local function restoreJointC0s()
	currentPose = copyPose(IDENTITY_POSE)
end

local function applyPose(pose)
	currentPose = copyPose(pose)
end

local function getEquippedFishingRod()
	local tool = character and character:FindFirstChild("Fishing Rod")
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

local function clearRodFlex()
	local equippedTool = getEquippedFishingRod()
	local function clearTool(tool)
		if tool and tool.Parent then
			tool:SetAttribute(ROD_FLEX_ATTRIBUTE, nil)
			tool:SetAttribute(ROD_TWIST_ATTRIBUTE, nil)
			tool:SetAttribute(ROD_CAST_SIDE_ATTRIBUTE, nil)
			tool:SetAttribute(ROD_LINE_SWING_ATTRIBUTE, nil)
		end
	end

	clearTool(flexTool)
	if equippedTool ~= flexTool then
		clearTool(equippedTool)
	end
	flexTool = nil
	currentFlex = 0
	currentTwist = 0
	currentCastSide = 0
	currentLineSwing = 0
end

local function applyRodFlex(flex, twist, castSide, lineSwing)
	local tool = getEquippedFishingRod()
	if flexTool ~= tool then
		clearRodFlex()
		flexTool = tool
	end

	currentFlex = flex
	currentTwist = twist
	currentCastSide = math.clamp(tonumber(castSide) or 0, 0, 1)
	currentLineSwing = math.clamp(tonumber(lineSwing) or 0, 0, 1)
	if tool then
		tool:SetAttribute(ROD_FLEX_ATTRIBUTE, flex)
		tool:SetAttribute(ROD_TWIST_ATTRIBUTE, twist)
		tool:SetAttribute(ROD_CAST_SIDE_ATTRIBUTE, currentCastSide)
		tool:SetAttribute(ROD_LINE_SWING_ATTRIBUTE, currentLineSwing)
	end
end

local function finishAnimation()
	currentPose = copyPose(IDENTITY_POSE)
	restoreJointC0s()
	clearRodFlex()
	activeCastInput = nil
	landedSawMinigame = false
	landedMinigameHiddenAt = nil
	activeFishingSessionId = nil
	phase = "idle"
end

local function setupCharacter(nextCharacter)
	restoreJointC0s()
	clearRodFlex()
	character = nextCharacter
	joints = nil
	phase = "idle"
	activeCastInput = nil
	landedSawMinigame = false
	landedMinigameHiddenAt = nil
	activeFishingSessionId = nil
	currentPose = copyPose(IDENTITY_POSE)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	-- CharacterAdded can fire before an R15 rig has finished parenting its motors.
	-- Wait for both shoulders instead of permanently disabling the animation.
	local nextJoints = nil
	local jointDeadline = os.clock() + 10
	repeat
		local jointsByName = {}
		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("AnimationConstraint") then
				-- Prefer upgraded avatar joints when both systems are present.
				jointsByName[descendant.Name] = descendant
			elseif descendant:IsA("Motor6D") and jointsByName[descendant.Name] == nil then
				jointsByName[descendant.Name] = descendant
			end
		end

		local candidateJoints = {}
		for key, aliases in pairs(JOINT_NAMES) do
			local joint = findJoint(jointsByName, aliases)
			if joint then
				candidateJoints[key] = joint
			end
		end

		if candidateJoints.rightShoulder and candidateJoints.leftShoulder then
			nextJoints = candidateJoints
			break
		end
		task.wait(0.05)
	until os.clock() >= jointDeadline or character.Parent == nil

	if not nextJoints then
		warn("[FishingCastAnimation] Character shoulders were not found")
		return
	end
	joints = nextJoints
end

local function isCastInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space
end

local function hasEquippedFishingRod()
	return getEquippedFishingRod() ~= nil
end

local function isGuiObjectActuallyVisible(guiObject)
	if not guiObject.Visible then
		return false
	end

	local ancestor = guiObject.Parent
	while ancestor and ancestor ~= playerGui do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		end
		if ancestor:IsA("LayerCollector") and not ancestor.Enabled then
			return false
		end
		ancestor = ancestor.Parent
	end

	return ancestor == playerGui
end

local function isCastMeterVisible()
	for _, frameName in ipairs(CAST_FRAME_NAMES) do
		local candidate = playerGui:FindFirstChild(frameName, true)
		if candidate and candidate:IsA("GuiObject") and isGuiObjectActuallyVisible(candidate) then
			return true
		end
	end

	return false
end

local function isFishingMinigameVisible()
	-- FishingClient owns one blur for the complete minigame lifecycle. Use it as
	-- the authoritative signal so duplicate legacy frames in PlayerGui cannot keep
	-- the landed bobber alive after the active game has closed.
	local fishingBlur = Lighting:FindFirstChild("FishyFishUiBlur")
	if fishingBlur and fishingBlur:IsA("BlurEffect") then
		return fishingBlur.Enabled and fishingBlur.Size > 0
	end

	-- Fallback for stripped-down test places that do not create the fishing blur.
	local frameNames = {
		CustomFishingMinigame = true,
		FishingGameContent = true,
	}
	for _, candidate in ipairs(playerGui:GetDescendants()) do
		if frameNames[candidate.Name]
			and candidate:IsA("GuiObject")
			and isGuiObjectActuallyVisible(candidate)
		then
			return true
		end
	end

	return false
end

local function beginRecovery()
	if phase == "idle" or phase == "release" then
		return
	end

	phase = "recover"
	phaseStartedAt = os.clock()
	releaseStartPose = copyPose(currentPose)
	releaseStartFlex = currentFlex
	releaseStartTwist = currentTwist
	releaseStartSide = currentCastSide
	releaseStartLineSwing = currentLineSwing
	activeCastInput = nil
end

-- FishingPrompt starts the exact manual fishing session associated with this
-- cast. The server's following Notice is the authoritative completion signal
-- for every result (caught, escaped, invalidated, or rod unequipped). This is
-- independent of whichever visual minigame layout is currently installed.
FishingPrompt.OnClientEvent:Connect(function(prompt)
	if type(prompt) ~= "table" or prompt.autoFish == true then
		return
	end

	activeFishingSessionId = prompt.sessionId or true
	landedSawMinigame = true
end)

Notice.OnClientEvent:Connect(function()
	if activeFishingSessionId == nil then
		return
	end

	finishAnimation()
end)

UserInputService.InputBegan:Connect(function(input)
	if not isCastInput(input)
		or activeCastInput ~= nil
		or phase ~= "idle"
		or not isCastMeterVisible()
		or not hasEquippedFishingRod()
		or not joints
	then
		return
	end

	activeCastInput = input
	phase = "charge"
	phaseStartedAt = os.clock()
end)

UserInputService.InputEnded:Connect(function(input)
	if input ~= activeCastInput or phase ~= "charge" then
		return
	end

	activeCastInput = nil
	phase = "release"
	phaseStartedAt = os.clock()
	releaseStartPose = copyPose(currentPose)
	releaseStartFlex = currentFlex
	releaseStartTwist = currentTwist
	releaseStartSide = currentCastSide
	releaseStartLineSwing = currentLineSwing
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if not joints then
		return
	end

	if phase == "idle" then
		-- Pull the line behind the rod when the casting meter first appears. The
		-- release phase sweeps it over the tip and toward the water.
		if isCastMeterVisible() and hasEquippedFishingRod() then
			applyRodFlex(0, 0, 1, 0)
		elseif flexTool then
			clearRodFlex()
		end
		return
	end

	if phase == "charge" then
		if not isCastMeterVisible() or not hasEquippedFishingRod() then
			beginRecovery()
		else
			local elapsed = os.clock() - phaseStartedAt
			local blend = 1 - math.exp(-CHARGE_RESPONSE * deltaTime)
			currentPose = lerpPose(currentPose, WINDUP_POSE, blend)

			local displayPose = copyPose(currentPose)
			local settleAmount = math.clamp(elapsed / 0.3, 0, 1)
			local loadedPulse = math.sin(elapsed * 5.5) * math.rad(1.2) * settleAmount
			displayPose.rightShoulder *= CFrame.Angles(loadedPulse, 0, 0)
			displayPose.waist *= CFrame.Angles(0, loadedPulse * -0.35, 0)
			applyPose(displayPose)

			local flex = math.rad(4) * settleAmount + loadedPulse * 0.45
			local twist = math.rad(-1.5) * settleAmount
			applyRodFlex(flex, twist, 1, 0)
		end
	elseif phase == "release" then
		local elapsed = os.clock() - phaseStartedAt
		if elapsed <= FORWARD_DURATION then
			local poseProgress = easeOutCubic(elapsed / FORWARD_DURATION)
			local lineProgress = easeInOutSine(elapsed / FORWARD_DURATION)
			currentPose = lerpPose(releaseStartPose or WINDUP_POSE, FORWARD_POSE, poseProgress)
			applyRodFlex(
				releaseStartFlex + (math.rad(-10) - releaseStartFlex) * poseProgress,
				releaseStartTwist + (math.rad(2.5) - releaseStartTwist) * poseProgress,
				releaseStartSide + (1 - releaseStartSide) * poseProgress,
				releaseStartLineSwing + (1 - releaseStartLineSwing) * lineProgress
			)
		elseif elapsed <= FORWARD_DURATION + FOLLOW_THROUGH_DURATION then
			local followProgress = (elapsed - FORWARD_DURATION) / FOLLOW_THROUGH_DURATION
			currentPose = lerpPose(FORWARD_POSE, FOLLOW_THROUGH_POSE, easeInOutSine(followProgress))
			local damping = 1 - followProgress
			local flex = math.rad(-10) * damping + math.sin(followProgress * math.pi * 2) * math.rad(3) * damping
			local twist = math.rad(2.5) * damping
			applyRodFlex(flex, twist, 1, 1)
		elseif elapsed <= FORWARD_DURATION + FOLLOW_THROUGH_DURATION + RECOVERY_DURATION then
			local recoveryProgress = (elapsed - FORWARD_DURATION - FOLLOW_THROUGH_DURATION) / RECOVERY_DURATION
			currentPose = lerpPose(FOLLOW_THROUGH_POSE, IDENTITY_POSE, easeInOutSine(recoveryProgress))
			-- The arm can recover, but the released line stays active and its cached
			-- world-space endpoint remains on the water.
			applyRodFlex(0, 0, 1, 1)
		else
			currentPose = copyPose(IDENTITY_POSE)
			applyPose(currentPose)
			applyRodFlex(0, 0, 1, 1)
			phase = "landed"
			phaseStartedAt = os.clock()
			landedSawMinigame = isFishingMinigameVisible()
			landedMinigameHiddenAt = nil
		end

		applyPose(currentPose)
	elseif phase == "landed" then
		if not hasEquippedFishingRod() then
			finishAnimation()
			return
		end

		currentPose = copyPose(IDENTITY_POSE)
		applyPose(currentPose)
		applyRodFlex(0, 0, 1, 1)

		local minigameVisible = isFishingMinigameVisible()
		if minigameVisible then
			landedSawMinigame = true
			landedMinigameHiddenAt = nil
		elseif landedSawMinigame then
			landedMinigameHiddenAt = landedMinigameHiddenAt or os.clock()
			if os.clock() - landedMinigameHiddenAt >= MINIGAME_HIDDEN_CONFIRMATION then
				finishAnimation()
			end
		end
	elseif phase == "recover" then
		local elapsed = os.clock() - phaseStartedAt
		local progress = easeInOutSine(elapsed / RECOVERY_DURATION)
		currentPose = lerpPose(releaseStartPose or currentPose, IDENTITY_POSE, progress)
		applyPose(currentPose)
		applyRodFlex(
			releaseStartFlex * (1 - progress),
			releaseStartTwist * (1 - progress),
			releaseStartSide * (1 - progress),
			releaseStartLineSwing * (1 - progress)
		)

		if elapsed >= RECOVERY_DURATION then
			finishAnimation()
		end
	end
end)

-- Roblox's Animator writes joint transforms before PreSimulation. Multiplying
-- our procedural layer here supports both AnimationConstraint and Motor6D rigs
-- without fighting the normal walk, idle, and tool animations.
RunService.PreSimulation:Connect(function()
	if not joints or phase == "idle" then
		return
	end

	for key, joint in pairs(joints) do
		if joint.Parent then
			joint.Transform = (currentPose[key] or CFrame.new()) * joint.Transform
		end
	end
end)

player.CharacterAdded:Connect(function(nextCharacter)
	task.spawn(setupCharacter, nextCharacter)
end)

script.Destroying:Connect(function()
	restoreJointC0s()
	clearRodFlex()
end)

if player.Character then
	task.spawn(setupCharacter, player.Character)
end
