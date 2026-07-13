local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CAST_FRAME_NAME = "CastPowerContent"
local FORWARD_DURATION = 0.18
local FOLLOW_THROUGH_DURATION = 0.22
local RECOVERY_DURATION = 0.28
local CHARGE_RESPONSE = 12

local IDENTITY_POSE = {
	rightShoulder = CFrame.new(),
	leftShoulder = CFrame.new(),
	waist = CFrame.new(),
}

local WINDUP_POSE = {
	rightShoulder = CFrame.Angles(math.rad(-62), math.rad(-12), math.rad(38)),
	leftShoulder = CFrame.Angles(math.rad(-12), math.rad(8), math.rad(-9)),
	waist = CFrame.Angles(math.rad(-5), math.rad(-20), math.rad(3)),
}

local FORWARD_POSE = {
	rightShoulder = CFrame.Angles(math.rad(-108), math.rad(8), math.rad(-12)),
	leftShoulder = CFrame.Angles(math.rad(-22), math.rad(-6), math.rad(8)),
	waist = CFrame.Angles(math.rad(4), math.rad(18), math.rad(-3)),
}

local FOLLOW_THROUGH_POSE = {
	rightShoulder = CFrame.Angles(math.rad(-78), math.rad(10), math.rad(-24)),
	leftShoulder = CFrame.Angles(math.rad(-8), 0, math.rad(4)),
	waist = CFrame.Angles(math.rad(2), math.rad(9), 0),
}

local castFrame = nil
local castFrameVisibilityConnection = nil
local character = nil
local joints = nil
local phase = "idle"
local phaseStartedAt = 0
local releaseStartPose = nil
local currentPose = table.clone(IDENTITY_POSE)

local function copyPose(pose)
	return {
		rightShoulder = pose.rightShoulder,
		leftShoulder = pose.leftShoulder,
		waist = pose.waist,
	}
end

local function lerpPose(fromPose, toPose, alpha)
	local clampedAlpha = math.clamp(alpha, 0, 1)
	return {
		rightShoulder = fromPose.rightShoulder:Lerp(toPose.rightShoulder, clampedAlpha),
		leftShoulder = fromPose.leftShoulder:Lerp(toPose.leftShoulder, clampedAlpha),
		waist = fromPose.waist:Lerp(toPose.waist, clampedAlpha),
	}
end

local function easeOutCubic(value)
	local inverse = 1 - math.clamp(value, 0, 1)
	return 1 - (inverse * inverse * inverse)
end

local function easeInOutSine(value)
	return -(math.cos(math.pi * math.clamp(value, 0, 1)) - 1) / 2
end

local function findMotor(model, motorName)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") and descendant.Name == motorName then
			return descendant
		end
	end
	return nil
end

local function restoreJointC0s()
	if not joints then
		return
	end

	for _, jointData in pairs(joints) do
		if jointData.motor and jointData.motor.Parent then
			jointData.motor.C0 = jointData.baseC0
		end
	end
end

local function applyPose(pose)
	if not joints then
		return
	end

	local rightShoulder = joints.rightShoulder
	local leftShoulder = joints.leftShoulder
	local waist = joints.waist

	if rightShoulder.motor.Parent then
		rightShoulder.motor.C0 = rightShoulder.baseC0 * pose.rightShoulder
	end
	if leftShoulder.motor.Parent then
		leftShoulder.motor.C0 = leftShoulder.baseC0 * pose.leftShoulder
	end
	if waist.motor.Parent then
		waist.motor.C0 = waist.baseC0 * pose.waist
	end
end

local function setupCharacter(nextCharacter)
	restoreJointC0s()
	character = nextCharacter
	joints = nil
	phase = "idle"
	currentPose = copyPose(IDENTITY_POSE)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end

	local rightShoulder = findMotor(character, "RightShoulder")
	local leftShoulder = findMotor(character, "LeftShoulder")
	local waist = findMotor(character, "Waist")
	if not rightShoulder or not leftShoulder or not waist then
		return
	end

	joints = {
		rightShoulder = { motor = rightShoulder, baseC0 = rightShoulder.C0 },
		leftShoulder = { motor = leftShoulder, baseC0 = leftShoulder.C0 },
		waist = { motor = waist, baseC0 = waist.C0 },
	}
end

local function isCastInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space
end

local function hasEquippedFishingRod()
	return character ~= nil and character:FindFirstChild("Fishing Rod") ~= nil
end

local function isCastMeterVisible()
	return castFrame ~= nil and castFrame.Parent ~= nil and castFrame.Visible == true
end

local function beginRecovery()
	if phase == "idle" or phase == "release" then
		return
	end

	phase = "recover"
	phaseStartedAt = os.clock()
	releaseStartPose = copyPose(currentPose)
end

local function bindCastFrame(frame)
	if castFrame == frame then
		return
	end

	if castFrameVisibilityConnection then
		castFrameVisibilityConnection:Disconnect()
		castFrameVisibilityConnection = nil
	end

	castFrame = frame
	castFrameVisibilityConnection = frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible then
			beginRecovery()
		end
	end)
end

local function findCastFrame()
	local candidate = playerGui:FindFirstChild(CAST_FRAME_NAME, true)
	if candidate and candidate:IsA("GuiObject") then
		bindCastFrame(candidate)
	end
end

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == CAST_FRAME_NAME and descendant:IsA("GuiObject") then
		bindCastFrame(descendant)
	end
end)

UserInputService.InputBegan:Connect(function(input)
	if not isCastInput(input) or not isCastMeterVisible() or not hasEquippedFishingRod() or not joints then
		return
	end

	phase = "charge"
	phaseStartedAt = os.clock()
end)

UserInputService.InputEnded:Connect(function(input)
	if not isCastInput(input) or phase ~= "charge" then
		return
	end

	phase = "release"
	phaseStartedAt = os.clock()
	releaseStartPose = copyPose(currentPose)
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if not joints then
		return
	end

	if phase == "charge" then
		if not isCastMeterVisible() or not hasEquippedFishingRod() then
			beginRecovery()
		else
			local blend = 1 - math.exp(-CHARGE_RESPONSE * deltaTime)
			currentPose = lerpPose(currentPose, WINDUP_POSE, blend)
			applyPose(currentPose)
		end
	elseif phase == "release" then
		local elapsed = os.clock() - phaseStartedAt
		if elapsed <= FORWARD_DURATION then
			currentPose = lerpPose(
				releaseStartPose or WINDUP_POSE,
				FORWARD_POSE,
				easeOutCubic(elapsed / FORWARD_DURATION)
			)
		elseif elapsed <= FORWARD_DURATION + FOLLOW_THROUGH_DURATION then
			local followProgress = (elapsed - FORWARD_DURATION) / FOLLOW_THROUGH_DURATION
			currentPose = lerpPose(FORWARD_POSE, FOLLOW_THROUGH_POSE, easeInOutSine(followProgress))
		elseif elapsed <= FORWARD_DURATION + FOLLOW_THROUGH_DURATION + RECOVERY_DURATION then
			local recoveryProgress = (elapsed - FORWARD_DURATION - FOLLOW_THROUGH_DURATION) / RECOVERY_DURATION
			currentPose = lerpPose(FOLLOW_THROUGH_POSE, IDENTITY_POSE, easeInOutSine(recoveryProgress))
		else
			currentPose = copyPose(IDENTITY_POSE)
			restoreJointC0s()
			phase = "idle"
			return
		end

		applyPose(currentPose)
	elseif phase == "recover" then
		local elapsed = os.clock() - phaseStartedAt
		local progress = easeInOutSine(elapsed / RECOVERY_DURATION)
		currentPose = lerpPose(releaseStartPose or currentPose, IDENTITY_POSE, progress)
		applyPose(currentPose)

		if elapsed >= RECOVERY_DURATION then
			currentPose = copyPose(IDENTITY_POSE)
			restoreJointC0s()
			phase = "idle"
		end
	end
end)

player.CharacterAdded:Connect(function(nextCharacter)
	task.spawn(setupCharacter, nextCharacter)
end)

script.Destroying:Connect(restoreJointC0s)

findCastFrame()
if player.Character then
	task.spawn(setupCharacter, player.Character)
end
