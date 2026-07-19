local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("FishingRemotes")

local GetCastConfig = Remotes:FindFirstChild("GetCastConfig")
if not GetCastConfig then
	GetCastConfig = Instance.new("RemoteFunction")
	GetCastConfig.Name = "GetCastConfig"
	GetCastConfig.Parent = Remotes
end

local CastConfigService = {}

local pendingCasts = {}
local lastCenters = {}
local options = {}
local random = Random.new()

local function getCastingConfig()
	return GameConfig.Casting or {}
end

local function normalizeIslandId(areaId)
	if GameConfig.normalizeIslandId then
		return GameConfig.normalizeIslandId(areaId) or areaId
	end

	return areaId
end

local function getRodPerfectBonus(rodId)
	local casting = getCastingConfig()
	local bonuses = casting.RodPerfectZoneBonuses or {}
	return tonumber(bonuses[rodId or "WoodenRod"]) or 0
end

local function chooseSpeed()
	local casting = getCastingConfig()
	local speeds = casting.meterSpeeds or {
		{ name = "Slow", min = 0.62, max = 0.78 },
		{ name = "Medium", min = 0.86, max = 1.04 },
		{ name = "Fast", min = 1.10, max = 1.28 },
	}

	local choice = speeds[random:NextInteger(1, #speeds)]
	return random:NextNumber(choice.min, choice.max), choice.name
end

local function chooseStart()
	return 0, 1, "Left"
end

local function makeAttemptId(player)
	return tostring(player.UserId) .. ":" .. tostring(math.floor(os.clock() * 1000)) .. ":" .. tostring(random:NextInteger(100000, 999999))
end

local function generateConfig(player, data, biomeId)
	local casting = getCastingConfig()
	local minRadius = tonumber(casting.perfectRadiusMin) or 0.035
	local maxRadius = tonumber(casting.perfectRadiusMax) or 0.058
	local rodId = data and data.EquippedRod or "WoodenRod"
	local perfectRadius = math.clamp(random:NextNumber(minRadius, maxRadius) * (1 + getRodPerfectBonus(rodId)), 0.03, 0.09)
	local edgeMargin = math.max(tonumber(casting.perfectEdgeMargin) or 0.08, perfectRadius + 0.035)
	local perfectCenter = random:NextNumber(edgeMargin, 1 - edgeMargin)
	local previousCenter = lastCenters[player]
	local minShift = tonumber(casting.minPerfectCenterShift) or 0.08

	if previousCenter and math.abs(perfectCenter - previousCenter) < minShift then
		local direction = perfectCenter >= 0.5 and -1 or 1
		perfectCenter = math.clamp(previousCenter + direction * random:NextNumber(minShift, minShift + 0.12), edgeMargin, 1 - edgeMargin)
	end

	lastCenters[player] = perfectCenter

	local meterSpeed, speedName = chooseSpeed()
	local startProgress, direction, startName = chooseStart()
	local attemptId = makeAttemptId(player)
	local config = {
		attemptId = attemptId,
		biomeId = biomeId,
		rodId = rodId,
		perfectCenter = perfectCenter,
		perfectRadius = perfectRadius,
		greatRadius = math.clamp(perfectRadius + (tonumber(casting.greatExtraRadius) or 0.065), perfectRadius, 0.5),
		goodRadius = math.clamp(perfectRadius + (tonumber(casting.goodExtraRadius) or 0.20), perfectRadius, 0.5),
		meterSpeed = meterSpeed,
		speedName = speedName,
		startProgress = startProgress,
		startName = startName,
		direction = direction,
		createdAt = os.clock(),
		expiresAt = os.clock() + (tonumber(casting.castConfigLifetime) or 20),
	}

	pendingCasts[player] = config
	return config
end

local function publicConfig(config)
	return {
		ok = true,
		attemptId = config.attemptId,
		perfectCenter = config.perfectCenter,
		perfectRadius = config.perfectRadius,
		greatRadius = config.greatRadius,
		goodRadius = config.goodRadius,
		meterSpeed = config.meterSpeed,
		speedName = config.speedName,
		startProgress = config.startProgress,
		startName = config.startName,
		direction = config.direction,
	}
end

function CastConfigService.configure(nextOptions)
	options = nextOptions or {}
end

function CastConfigService.getCastResult(castPower, castConfig)
	local casting = getCastingConfig()
	local power = math.clamp(tonumber(castPower) or casting.defaultPower or 0.5, 0, 1)
	local perfectCenter = math.clamp(tonumber(castConfig and castConfig.perfectCenter) or tonumber(casting.perfectCenter) or 0.72, 0, 1)
	local perfectRadius = math.clamp(tonumber(castConfig and castConfig.perfectRadius) or tonumber(casting.perfectRadius) or 0.045, 0.01, 0.5)
	local greatRadius = math.clamp(tonumber(castConfig and castConfig.greatRadius) or tonumber(casting.greatRadius) or 0.11, perfectRadius, 0.5)
	local goodRadius = math.clamp(tonumber(castConfig and castConfig.goodRadius) or tonumber(casting.goodRadius) or 0.24, greatRadius, 0.5)
	local accuracy = math.abs(power - perfectCenter)
	local rating = "Weak"

	if accuracy <= perfectRadius then
		rating = "Perfect"
	elseif accuracy <= greatRadius then
		rating = "Great"
	elseif accuracy <= goodRadius then
		rating = "Good"
	end

	local ratingConfig = (casting.Ratings and casting.Ratings[rating]) or {}
	return {
		power = power,
		rating = rating,
		displayName = ratingConfig.displayName or rating,
		accuracy = accuracy,
		biteSpeedMultiplier = tonumber(ratingConfig.biteSpeedMultiplier) or 1,
		progressGainMultiplier = tonumber(ratingConfig.progressGainMultiplier) or 1,
		countsAsPerfect = ratingConfig.countsAsPerfect == true or rating == "Perfect",
		sparkle = ratingConfig.sparkle == true,
	}
end

function CastConfigService.consume(player, castRequest, data, biomeId)
	local power = castRequest and (castRequest.castPower or castRequest.power) or nil
	if tonumber(power) == nil then
		return nil
	end

	local attemptId = castRequest and castRequest.castAttemptId
	local config = pendingCasts[player]
	pendingCasts[player] = nil

	if not config
		or config.attemptId ~= attemptId
		or config.biomeId ~= biomeId
		or os.clock() > config.expiresAt
	then
		return CastConfigService.getCastResult(power, nil)
	end

	return CastConfigService.getCastResult(power, config)
end

function CastConfigService.clearPlayer(player)
	pendingCasts[player] = nil
	lastCenters[player] = nil
end

GetCastConfig.OnServerInvoke = function(player, biomeId)
	local data = options.getPlayerData and options.getPlayerData(player)
	if not data then
		return { ok = false, message = "Player data is still loading." }
	end

	local currentBiome = normalizeIslandId(options.getPlayerFishingBiome and options.getPlayerFishingBiome(player))
	if not currentBiome then
		return { ok = false, message = "Move to a fishing area first." }
	end

	biomeId = normalizeIslandId(biomeId)
	if biomeId and biomeId ~= currentBiome then
		return { ok = false, message = "You can only cast where you are standing." }
	end

	if options.isBiomeUnlocked and not options.isBiomeUnlocked(data, currentBiome) then
		return { ok = false, message = "Unlock that island first." }
	end

	return publicConfig(generateConfig(player, data, currentBiome))
end

return CastConfigService
