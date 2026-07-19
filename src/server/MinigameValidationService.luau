local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FishingMinigameSimulation = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishingMinigameSimulation")
)

local MinigameValidationService = {}

local MAX_EVENTS = 256
local EVENT_CLOCK_TOLERANCE = 2.5
local COMPLETION_CLOCK_TOLERANCE = 3
local MIN_TAP_INTERVAL = 0.065
local TAP_PHASE_CLOCK_TOLERANCE = 0.2
local DRAIN_DURATION = 0.5
local PHASE_DURATION = 4.5
local TAP_GOALS = {
	Epic = 8,
	Legendary = 14,
	Mythic = 14,
}

local function failSession(session, reason)
	session.invalidReason = session.invalidReason or reason
	return false, session.invalidReason
end

function MinigameValidationService.newSession(options)
	return {
		sessionId = options.sessionId,
		requestedAt = options.requestedAt,
		biteDelay = options.biteDelay,
		seed = options.seed,
		rarity = options.rarity,
		config = options.config,
		difficulty = options.difficulty,
		events = {},
		lastSequence = 0,
		lastElapsed = 0,
		lastTapElapsed = -math.huge,
		invalidReason = nil,
	}
end

function MinigameValidationService.recordInput(session, payload, now)
	if session.invalidReason then
		return false, session.invalidReason
	end
	if type(payload) ~= "table" or payload.sessionId ~= session.sessionId then
		return failSession(session, "session mismatch")
	end

	local sequence = tonumber(payload.sequence)
	local elapsed = tonumber(payload.elapsed)
	local serverElapsed = now - session.requestedAt
	if not sequence or sequence ~= session.lastSequence + 1 or sequence ~= math.floor(sequence) then
		return failSession(session, "input sequence mismatch")
	end
	if not elapsed or elapsed < session.lastElapsed or elapsed < 0 then
		return failSession(session, "input clock moved backwards")
	end
	if elapsed > serverElapsed + 0.75 or serverElapsed - elapsed > EVENT_CLOCK_TOLERANCE then
		return failSession(session, "input arrived outside the live validation window")
	end
	if #session.events >= MAX_EVENTS then
		return failSession(session, "too many input events")
	end

	local kind = payload.kind
	if kind == "Hold" then
		if type(payload.holding) ~= "boolean" then
			return failSession(session, "invalid hold state")
		end
		table.insert(session.events, { kind = kind, elapsed = elapsed, holding = payload.holding })
	elseif kind == "Tap" then
		if elapsed - session.lastTapElapsed < MIN_TAP_INTERVAL then
			return failSession(session, "tap rate exceeded")
		end
		session.lastTapElapsed = elapsed
		table.insert(session.events, { kind = kind, elapsed = elapsed })
	else
		return failSession(session, "unknown input kind")
	end

	session.lastSequence = sequence
	session.lastElapsed = elapsed
	return true
end

local function getTapGoalAt(events, phaseStart, goal)
	local count = 0
	for _, event in ipairs(events) do
		if event.kind == "Tap" and event.elapsed >= phaseStart - TAP_PHASE_CLOCK_TOLERANCE then
			count += 1
			if count >= goal then
				return event.elapsed
			end
		end
	end
	return nil
end

function MinigameValidationService.evaluate(session, payload, now)
	if session.invalidReason then
		return false, session.invalidReason
	end
	if type(payload) ~= "table" or payload.sessionId ~= session.sessionId then
		return false, "session mismatch"
	end
	if payload.success ~= true then
		return false, "client reported failure"
	end

	local clientElapsed = tonumber(payload.elapsed)
	local serverElapsed = now - session.requestedAt
	if not clientElapsed or clientElapsed < session.biteDelay then
		return false, "invalid completion clock"
	end
	if math.abs(serverElapsed - clientElapsed) > COMPLETION_CLOCK_TOLERANCE then
		return false, "completion arrived outside the live validation window"
	end

	local reelDuration = clientElapsed - session.biteDelay
	local maxDuration = tonumber(session.config.maxDuration) or 35
	if reelDuration > maxDuration + 0.5 then
		return false, "minigame timed out"
	end

	local simulation = FishingMinigameSimulation.new(
		session.config,
		session.difficulty,
		session.seed,
		session.rarity
	)
	local holding = false
	local replayAt = 0
	local relativeEvents = {}
	for _, event in ipairs(session.events) do
		local relativeElapsed = event.elapsed - session.biteDelay
		if relativeElapsed >= 0 and relativeElapsed <= reelDuration + 0.25 then
			local replayEvent = {
				kind = event.kind,
				elapsed = relativeElapsed,
				holding = event.holding,
			}
			table.insert(relativeEvents, replayEvent)
			if event.kind == "Hold" then
				simulation:advance(relativeElapsed - replayAt, holding)
				replayAt = relativeElapsed
				holding = event.holding
			end
		end
	end
	simulation:advance(reelDuration - replayAt, holding)
	local snapshot = simulation:getSnapshot()
	if snapshot.failedAt then
		return false, "server simulation reached zero progress"
	end
	if not snapshot.reelCompletedAt then
		return false, "server simulation did not complete"
	end

	local expectedCompletion = snapshot.reelCompletedAt
	local tapGoal = TAP_GOALS[session.rarity]
	if tapGoal then
		local secondPhaseStart = expectedCompletion + DRAIN_DURATION
		local secondTapGoalAt = getTapGoalAt(relativeEvents, secondPhaseStart, tapGoal)
		if not secondTapGoalAt then
			return false, "server did not receive the required phase taps"
		end
		expectedCompletion = math.max(secondPhaseStart + PHASE_DURATION, secondTapGoalAt)

		if session.rarity == "Mythic" then
			local thirdPhaseStart = expectedCompletion + DRAIN_DURATION
			local thirdTapGoalAt = getTapGoalAt(relativeEvents, thirdPhaseStart, tapGoal)
			if not thirdTapGoalAt then
				return false, "server did not receive the final phase taps"
			end
			expectedCompletion = math.max(thirdPhaseStart + PHASE_DURATION, thirdTapGoalAt)
		end
	end

	if reelDuration + 0.2 < expectedCompletion then
		return false, "completion was earlier than the server simulation"
	end
	return true
end

return MinigameValidationService
