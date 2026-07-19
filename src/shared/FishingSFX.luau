local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local FishingSFX = {}

local ASSET_IDS = {
	Cast = "rbxassetid://83682073380871",
	BiteAlert = "rbxassetid://72291234208295",
	ReelLoop = "rbxassetid://92659416339023",
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
	Common = 0.34,
	Uncommon = 0.38,
	Rare = 0.44,
	Epic = 0.50,
	Legendary = 0.58,
	Mythic = 0.64,
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

function FishingSFX.getAssetId(assetName)
	return ASSET_IDS[assetName]
end

function FishingSFX.isEnabled()
	return isSFXEnabled()
end

function FishingSFX.playCast()
	playOneShot(
		"FishingCastSFX",
		ASSET_IDS.Cast,
		0.55,
		1,
		4,
		0.22
	)
end

function FishingSFX.playBiteAlert()
	playOneShot(
		"FishingBiteAlertSFX",
		ASSET_IDS.BiteAlert,
		0.52,
		1 + random:NextNumber(-0.012, 0.012),
		3
	)
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
