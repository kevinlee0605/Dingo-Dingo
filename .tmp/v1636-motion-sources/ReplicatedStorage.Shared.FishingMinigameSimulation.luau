local FishingMinigameSimulation = {}

local FIXED_STEP = 1 / 60
local FIXED_STEP_EPSILON = 1e-7
local MAX_ADVANCE_SECONDS = 60

local Simulation = {}
Simulation.__index = Simulation

local function normalizeRarity(rarity)
	if rarity == "Mythical" then
		return "Mythic"
	end
	return rarity or "Common"
end

local function isSpecialRarity(rarity)
	return rarity == "Epic" or rarity == "Legendary" or rarity == "Mythic"
end

local function chooseFishTarget(self, preferFarTarget)
	if preferFarTarget then
		local jumpMin = tonumber(self.difficulty.jumpMin) or 0.12
		local jumpMax = math.max(jumpMin, tonumber(self.difficulty.jumpMax) or jumpMin)
		local direction = self.random:NextInteger(0, 1) == 0 and -1 or 1
		local distance = self.random:NextNumber(jumpMin, jumpMax)
		local target = self.fishY + (direction * distance)
		if target < 0.08 or target > 0.92 then
			target = self.fishY - (direction * distance)
		end
		return math.clamp(target, 0.08, 0.92)
	end

	return self.random:NextNumber(0.08, 0.92)
end

local function getMovementDirection(self)
	if self.fishVelocity > 0.01 then
		return 1
	elseif self.fishVelocity < -0.01 then
		return -1
	end
	return self.fishTarget >= self.fishY and 1 or -1
end

local function triggerRareReversal(self)
	local reverseDirection = -getMovementDirection(self)
	local availableDistance = reverseDirection < 0 and (self.fishY - 0.04) or (0.96 - self.fishY)
	if availableDistance < 0.12 then
		self.progress = math.min(self.progress, 0.849)
		return
	end

	self.rareReversalTriggered = true
	self.forcedReverseDirection = reverseDirection
	self.forcedReverseUntil = self.elapsed + 0.32
	local reverseSpeed = math.max((tonumber(self.difficulty.moveSpeed) or 0.25) * 2.4, 0.72)
	self.fishVelocity = reverseDirection * reverseSpeed
	self.fishTarget = math.clamp(self.fishY + (reverseDirection * 0.42), 0.06, 0.94)
	self.pauseUntil = 0
	self.burstUntil = 0
	self.nextDecisionAt = self.forcedReverseUntil + 0.10
end

function FishingMinigameSimulation.new(config, difficulty, seed, rarity)
	local resolvedRarity = normalizeRarity(rarity)
	local random = Random.new(math.floor(tonumber(seed) or 1))
	local barSize = math.clamp(tonumber(config.barSize) or 0.24, 0.16, 0.58)
	local simulation = setmetatable({
		config = config,
		difficulty = difficulty,
		rarity = resolvedRarity,
		random = random,
		barSize = barSize,
		maxBarTop = 1 - barSize,
		barTop = math.clamp(0.70, 0, 1 - barSize),
		barVelocity = 0,
		fishY = random:NextNumber(0.20, 0.80),
		fishTarget = random:NextNumber(0.15, 0.85),
		fishVelocity = 0,
		progress = math.clamp(tonumber(config.startProgress) or 0.34, 0.08, 0.86),
		elapsed = 0,
		accumulator = 0,
		pauseUntil = 0,
		burstUntil = 0,
		forcedReverseUntil = 0,
		forcedReverseDirection = 0,
		rareReversalTriggered = false,
		reelCompletedAt = nil,
		failedAt = nil,
	}, Simulation)
	simulation.nextDecisionAt = random:NextNumber(
		difficulty.turnIntervalMin or 1,
		difficulty.turnIntervalMax or 2
	)
	return simulation
end

function Simulation:_step(holding)
	if self.reelCompletedAt or self.failedAt then
		return
	end

	local deltaTime = FIXED_STEP
	self.elapsed += deltaTime

	if self.elapsed >= self.nextDecisionAt then
		local pauseChance = self.difficulty.pauseChance or 0
		local jumpChance = self.difficulty.jumpChance or 0
		local burstChance = self.difficulty.burstChance or 0
		self.fishTarget = chooseFishTarget(self, jumpChance > 0 and self.random:NextNumber() < jumpChance)

		if pauseChance > 0 and self.random:NextNumber() < pauseChance then
			self.pauseUntil = self.elapsed
				+ self.random:NextNumber(self.difficulty.pauseMin or 0.12, self.difficulty.pauseMax or 0.45)
		end
		if burstChance > 0 and self.random:NextNumber() < burstChance then
			self.burstUntil = self.elapsed
				+ self.random:NextNumber(self.difficulty.burstMin or 0.18, self.difficulty.burstMax or 0.38)
		end
		self.nextDecisionAt = self.elapsed
			+ self.random:NextNumber(self.difficulty.turnIntervalMin or 1, self.difficulty.turnIntervalMax or 2)
	end

	local targetVelocity = 0
	if self.elapsed < self.forcedReverseUntil then
		targetVelocity = self.forcedReverseDirection
			* math.max((tonumber(self.difficulty.moveSpeed) or 0.25) * 2.4, 0.72)
	elseif self.elapsed >= self.pauseUntil then
		local distance = self.fishTarget - self.fishY
		local targetSlack = tonumber(self.difficulty.targetSlack) or 0.025
		if math.abs(distance) < targetSlack then
			self.fishTarget = chooseFishTarget(self, false)
			distance = self.fishTarget - self.fishY
		end

		local direction = distance >= 0 and 1 or -1
		local jitter = self.random:NextNumber(-(self.difficulty.jitter or 0), self.difficulty.jitter or 0)
		local speed = tonumber(self.difficulty.moveSpeed) or 0.25
		if self.elapsed < self.burstUntil then
			speed *= tonumber(self.difficulty.burstMultiplier) or 1.35
		end
		targetVelocity = (direction * speed) + jitter
	end

	local fishAcceleration = tonumber(self.difficulty.acceleration) or 6
	self.fishVelocity += (targetVelocity - self.fishVelocity) * math.min(1, fishAcceleration * deltaTime)
	self.fishY += self.fishVelocity * deltaTime
	if self.fishY <= 0.04 then
		self.fishY = 0.04
		self.fishVelocity = math.abs(self.fishVelocity) * 0.35
		self.fishTarget = math.max(self.fishTarget, 0.16)
	elseif self.fishY >= 0.96 then
		self.fishY = 0.96
		self.fishVelocity = -math.abs(self.fishVelocity) * 0.35
		self.fishTarget = math.min(self.fishTarget, 0.84)
	end

	local barAcceleration = holding and -(self.config.lift or 2.75) or (self.config.gravity or 1.8)
	self.barVelocity += barAcceleration * deltaTime
	self.barVelocity = math.clamp(
		self.barVelocity,
		-(self.config.maxBarVelocity or 1.65),
		self.config.maxBarVelocity or 1.65
	)
	self.barVelocity *= math.pow(self.config.damping or 0.90, deltaTime * 60)
	self.barTop += self.barVelocity * deltaTime
	if self.barTop <= 0 then
		self.barTop = 0
		self.barVelocity = math.abs(self.barVelocity) * (self.config.bounceDamping or 0.36)
	elseif self.barTop >= self.maxBarTop then
		self.barTop = self.maxBarTop
		self.barVelocity = -math.abs(self.barVelocity) * (self.config.bounceDamping or 0.36)
	end

	local gainMultiplier = self.rarity == "Uncommon" and 0.88 or 1
	if self.fishY >= self.barTop and self.fishY <= self.barTop + self.barSize then
		self.progress += (self.config.progressGainPerSecond or 0.34) * gainMultiplier * deltaTime
	else
		self.progress -= (self.config.progressDrainPerSecond or 0.16) * deltaTime
	end
	self.progress = math.clamp(self.progress, 0, 1)

	if self.rarity == "Rare" and not self.rareReversalTriggered and self.progress >= 0.85 then
		triggerRareReversal(self)
	end
	if self.rarity == "Rare" and self.elapsed < self.forcedReverseUntil and self.progress >= 1 then
		self.progress = 0.995
	end

	if self.progress <= 0 then
		self.failedAt = self.elapsed
	elseif self.progress >= 1 then
		local minDuration = tonumber(self.config.minSuccessDuration) or 1.75
		if isSpecialRarity(self.rarity) or self.elapsed >= minDuration then
			self.reelCompletedAt = self.elapsed
		end
	end
end

function Simulation:advance(duration, holding)
	duration = math.clamp(tonumber(duration) or 0, 0, MAX_ADVANCE_SECONDS)
	self.accumulator += duration
	while self.accumulator + FIXED_STEP_EPSILON >= FIXED_STEP
		and not self.reelCompletedAt
		and not self.failedAt
	do
		self.accumulator = math.max(0, self.accumulator - FIXED_STEP)
		self:_step(holding == true)
	end
	return self:getSnapshot()
end

function Simulation:getSnapshot()
	return {
		barSize = self.barSize,
		barTop = self.barTop,
		fishY = self.fishY,
		progress = self.progress,
		elapsed = self.elapsed,
		reelCompletedAt = self.reelCompletedAt,
		failedAt = self.failedAt,
	}
end

return FishingMinigameSimulation
