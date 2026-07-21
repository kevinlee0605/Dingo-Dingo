local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local FishingSFX = {}

local ASSET_IDS = {
	Cast = "rbxassetid://83682073380871",
	BiteAlert = "rbxassetid://72291234208295",
	ReelLoop = "rbxassetid://9114454163",
	RarityWarning = "rbxassetid://89119877198350",
	RevealCommon = "rbxassetid://74332544003952",
	RevealUncommon = "rbxassetid://125758019916365",
	RevealRare = "rbxassetid://109598132007713",
	RevealEpic = "rbxassetid://107836963921337",
	RevealLegendary = "rbxassetid://93961696300593",
	RevealMythic = "rbxassetid://110938581306711",
}

local REVEAL_ASSET_BY_RARITY = {
	Common = ASSET_IDS.RevealCommon,
	Uncommon = ASSET_IDS.RevealUncommon,
	Rare = ASSET_IDS.RevealRare,
	Epic = ASSET_IDS.RevealEpic,
	Legendary = ASSET_IDS.RevealLegendary,
	Mythic = ASSET_IDS.RevealMythic,
}

local REVEAL_VOLUME_BY_RARITY = {
	Common = 0.24,
	Uncommon = 0.27,
	Rare = 0.31,
	Epic = 0.35,
	Legendary = 0.41,
	Mythic = 0.45,
}

local soundRoot = SoundService:FindFirstChild("FishyFishSFX")
if not soundRoot then
	soundRoot = Instance.new("Folder")
	soundRoot.Name = "FishyFishSFX"
	soundRoot.Parent = SoundService
end

local random = Random.new()
local activeReelSound = nil
local reelFadeTween = nil
local activeRarityWarningSound = nil
-- The uploaded cast/plop file has a quiet lead-in before its first transient.
-- Start at the transient so input release and the audible cast happen together.
local CAST_START_OFFSET = 0.45

local function isSFXEnabled()
	return SoundService:GetAttribute("FishyFishSFXEnabled") ~= false
end

local function normalizeRarity(rarity)
	if rarity == "Mythical" then
		return "Mythic"
	end
	return REVEAL_ASSET_BY_RARITY[rarity] and rarity or "Common"
end

local function createSound(name, soundId, volume, playbackSpeed)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed or 1
	sound:SetAttribute("FishyFishSFX", true)
	sound:SetAttribute("FishyFishOriginalVolume", volume)
	sound.Parent = soundRoot
	return sound
end

local function playOneShot(name, soundId, volume, playbackSpeed, cleanupDelay, startOffset)
	if not isSFXEnabled() then
		return nil
	end
	local sound = createSound(name, soundId, volume, playbackSpeed)
	if startOffset and startOffset > 0 then
		sound.TimePosition = startOffset
	end
	sound:Play()
	Debris:AddItem(sound, cleanupDelay or 5)
	return sound
end

-- Keep the cast cue resident instead of constructing and streaming it only
-- after the player releases the casting meter. Preload synchronously while
-- the fishing client initializes so even the first cast has no stream delay.
local castSound = createSound(
	"FishingCastSFX",
	ASSET_IDS.Cast,
	0.55,
	1
)
local castPreloadSuccess, castPreloadMessage = pcall(function()
	ContentProvider:PreloadAsync({ castSound })
end)
if not castPreloadSuccess then
	warn("[FishingSFX] Cast sound preload failed:", castPreloadMessage)
end

-- Cycle through enough copies that every accepted rapid tap gets its own reel
-- burst. The active minigame accepts at most about 17 taps/second, so eight
-- 0.42-second voices finish before that same pool slot is reused.
local REEL_TAP_POOL_SIZE = 8
local REEL_TAP_VOLUME = 0.16
local REEL_TAP_DURATION = 0.42
local REEL_TAP_START_OFFSET = 0.04
local reelTapSounds = {}
local reelTapSerials = {}
local reelTapIndex = 0

for index = 1, REEL_TAP_POOL_SIZE do
	local sound = createSound(
		"FishingReelTapSFX" .. index,
		ASSET_IDS.ReelLoop,
		REEL_TAP_VOLUME,
		1.04
	)
	table.insert(reelTapSounds, sound)
	reelTapSerials[index] = 0
end

local function stopReelTap()
	for index, sound in ipairs(reelTapSounds) do
		reelTapSerials[index] += 1
		sound:Stop()
	end
end

function FishingSFX.getAssetId(assetName)
	return ASSET_IDS[assetName]
end

function FishingSFX.isEnabled()
	return isSFXEnabled()
end

function FishingSFX.playCast()
	if not isSFXEnabled() then
		castSound:Stop()
		return
	end

	castSound:Stop()
	castSound.Volume = 0.55
	castSound.PlaybackSpeed = 1
	castSound.TimePosition = CAST_START_OFFSET
	castSound:Play()
end

function FishingSFX.playBiteAlert()
	playOneShot(
		"FishingBiteAlertSFX",
		ASSET_IDS.BiteAlert,
		0.36,
		1 + random:NextNumber(-0.012, 0.012),
		3
	)
end

function FishingSFX.stopRarityWarning()
	local warningSound = activeRarityWarningSound
	activeRarityWarningSound = nil
	if warningSound and warningSound.Parent then
		warningSound:Stop()
		warningSound:Destroy()
	end
end

function FishingSFX.playRarityWarning(rarity)
	FishingSFX.stopRarityWarning()
	local normalized = normalizeRarity(rarity)
	if not isSFXEnabled()
		or (normalized ~= "Epic" and normalized ~= "Legendary" and normalized ~= "Mythic")
	then
		return nil
	end

	activeRarityWarningSound = createSound(
		"FishingRarityWarningSFX",
		ASSET_IDS.RarityWarning,
		0.32,
		1
	)
	activeRarityWarningSound.Looped = true
	activeRarityWarningSound:Play()
	return activeRarityWarningSound
end

function FishingSFX.playReelTap()
	if not isSFXEnabled() then
		stopReelTap()
		return
	end

	reelTapIndex = (reelTapIndex % REEL_TAP_POOL_SIZE) + 1
	local poolIndex = reelTapIndex
	local sound = reelTapSounds[poolIndex]
	reelTapSerials[poolIndex] += 1
	local playSerial = reelTapSerials[poolIndex]

	sound:Stop()
	sound:SetAttribute("FishyFishOriginalVolume", REEL_TAP_VOLUME)
	sound.Volume = REEL_TAP_VOLUME
	sound.PlaybackSpeed = 1.04
	sound.TimePosition = REEL_TAP_START_OFFSET
	sound:Play()

	task.delay(REEL_TAP_DURATION, function()
		if reelTapSerials[poolIndex] == playSerial then
			sound:Stop()
		end
	end)
end

function FishingSFX.startReeling(isAutoFish)
	FishingSFX.stopReeling(true)
	if not isSFXEnabled() then
		return
	end

	activeReelSound = createSound(
		"FishingReelLoopSFX",
		ASSET_IDS.ReelLoop,
		isAutoFish and 0.10 or 0.15,
		0.88
	)
	activeReelSound.Looped = true
	activeReelSound:Play()
end

function FishingSFX.setReelingHolding(holding)
	local reelSound = activeReelSound
	if not reelSound or reelSound.Parent == nil then
		return
	end

	if reelFadeTween then
		reelFadeTween:Cancel()
		reelFadeTween = nil
	end
	local targetVolume = holding and 0.34 or 0.15
	reelSound:SetAttribute("FishyFishOriginalVolume", targetVolume)
	reelSound.Volume = isSFXEnabled() and targetVolume or 0
	reelSound.PlaybackSpeed = holding and 1.04 or 0.88
end

function FishingSFX.stopReeling(immediate)
	stopReelTap()
	local reelSound = activeReelSound
	activeReelSound = nil
	if reelFadeTween then
		reelFadeTween:Cancel()
		reelFadeTween = nil
	end
	if not reelSound or reelSound.Parent == nil then
		return
	end

	if immediate then
		reelSound:Stop()
		reelSound:Destroy()
		return
	end

	local fade = TweenService:Create(
		reelSound,
		TweenInfo.new(0.10, Enum.EasingStyle.Linear),
		{ Volume = 0 }
	)
	reelFadeTween = fade
	fade.Completed:Once(function()
		if reelFadeTween == fade then
			reelFadeTween = nil
		end
		if reelSound.Parent then
			reelSound:Stop()
			reelSound:Destroy()
		end
	end)
	fade:Play()
end

function FishingSFX.playCatchReveal(rarity, isAutoFish)
	local normalized = normalizeRarity(rarity)
	local volume = REVEAL_VOLUME_BY_RARITY[normalized] or REVEAL_VOLUME_BY_RARITY.Common
	if isAutoFish then
		volume *= 0.70
	end

	playOneShot(
		"FishingReveal" .. normalized .. "SFX",
		REVEAL_ASSET_BY_RARITY[normalized],
		volume,
		1,
		4
	)
end

task.spawn(function()
	local preloadSounds = {}
	for _, soundId in pairs(ASSET_IDS) do
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		table.insert(preloadSounds, sound)
	end
	pcall(function()
		ContentProvider:PreloadAsync(preloadSounds)
	end)
	for _, sound in ipairs(preloadSounds) do
		sound:Destroy()
	end
end)

return FishingSFX
