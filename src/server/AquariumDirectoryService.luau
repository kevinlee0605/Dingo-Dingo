local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

local AquariumDirectoryService = {}

local SNAPSHOT_STORE_NAME = "FishyFish_AquariumDirectorySnapshots_v1"
local LIKE_COUNT_STORE_NAME = "FishyFish_AquariumLikeCounts_v1"
local LIKE_RANK_STORE_NAME = "FishyFish_AquariumLikeRanking_v1"
local RECENT_STORE_NAME = "FishyFish_AquariumRecent_v1"
local ONLINE_MAP_NAME = "FishyFish_AquariumOnline_v1"
local UPDATE_TOPIC = "FishyFish_AquariumDirectory_v1"

local DIRECTORY_CACHE_SECONDS = 30
local SNAPSHOT_CACHE_SECONDS = 90
local ONLINE_CACHE_SECONDS = 15
local ONLINE_TTL_SECONDS = 105
local ONLINE_HEARTBEAT_SECONDS = 40
local MAX_DIRECTORY_ENTRIES = 24
local UNCHANGED_PUBLISH_COOLDOWN_SECONDS = 30

local snapshotStore = DataStoreService:GetDataStore(SNAPSHOT_STORE_NAME)
local likeCountStore = DataStoreService:GetDataStore(LIKE_COUNT_STORE_NAME)
local likeRankStore = DataStoreService:GetOrderedDataStore(LIKE_RANK_STORE_NAME)
local recentStore = DataStoreService:GetOrderedDataStore(RECENT_STORE_NAME)
local onlineMap = MemoryStoreService:GetSortedMap(ONLINE_MAP_NAME)

local configured = {
	onChanged = nil,
}
local started = false
local directoryCache = nil
local directoryCacheAt = 0
local onlineCache = {}
local onlineCacheAt = 0
local snapshotCache = {}
local localLikeCounts = {}
local lastPublishByUserId = {}

local function keyForUserId(userId)
	return tostring(math.max(0, math.floor(tonumber(userId) or 0)))
end

local function copyTable(value, depth)
	if type(value) ~= "table" then
		return value
	end
	if (depth or 0) >= 8 then
		return nil
	end

	local copy = {}
	for key, child in pairs(value) do
		local copiedKey = copyTable(key, (depth or 0) + 1)
		local copiedValue = copyTable(child, (depth or 0) + 1)
		if copiedKey ~= nil and copiedValue ~= nil then
			copy[copiedKey] = copiedValue
		end
	end
	return copy
end

local function emitChanged()
	if configured.onChanged then
		task.defer(configured.onChanged)
	end
end

local function publishDirectoryUpdate(userId, likeCount)
	pcall(function()
		MessagingService:PublishAsync(UPDATE_TOPIC, {
			UserId = userId,
			LikeCount = likeCount,
			UpdatedAt = os.time(),
		})
	end)
end

local function cacheSnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return nil
	end
	local userId = math.floor(tonumber(snapshot.UserId) or 0)
	if userId <= 0 then
		return nil
	end
	snapshot.UserId = userId
	snapshotCache[userId] = {
		value = copyTable(snapshot),
		cachedAt = os.clock(),
	}
	return snapshot
end

local function getCachedSnapshot(userId)
	local cached = snapshotCache[userId]
	if cached and os.clock() - cached.cachedAt <= SNAPSHOT_CACHE_SECONDS then
		return copyTable(cached.value)
	end
	return nil
end

local function loadSnapshot(userId)
	userId = math.floor(tonumber(userId) or 0)
	if userId <= 0 then
		return nil
	end

	local cached = getCachedSnapshot(userId)
	if cached then
		return cached
	end

	local success, snapshot = pcall(function()
		return snapshotStore:GetAsync(keyForUserId(userId))
	end)
	if success and type(snapshot) == "table" then
		cacheSnapshot(snapshot)
		return copyTable(snapshot)
	end
	return nil
end

local function readOrderedUserIds(store, count)
	local success, pages = pcall(function()
		return store:GetSortedAsync(false, count)
	end)
	if not success or not pages then
		return {}
	end

	local ids = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		local userId = math.floor(tonumber(entry.key) or 0)
		if userId > 0 then
			table.insert(ids, userId)
		end
	end
	return ids
end

local function refreshDirectoryCache()
	if directoryCache and os.clock() - directoryCacheAt <= DIRECTORY_CACHE_SECONDS then
		return directoryCache
	end

	local orderedIds = {}
	local seen = {}
	local function appendIds(ids)
		for _, userId in ipairs(ids) do
			if not seen[userId] and #orderedIds < MAX_DIRECTORY_ENTRIES then
				seen[userId] = true
				table.insert(orderedIds, userId)
			end
		end
	end

	appendIds(readOrderedUserIds(likeRankStore, 16))
	appendIds(readOrderedUserIds(recentStore, MAX_DIRECTORY_ENTRIES))

	local entries = {}
	local addedEntries = {}
	for userId, cached in pairs(snapshotCache) do
		if cached and type(cached.value) == "table" then
			addedEntries[userId] = true
			table.insert(entries, copyTable(cached.value))
		end
	end
	for _, userId in ipairs(orderedIds) do
		local snapshot = loadSnapshot(userId)
		if snapshot and not addedEntries[userId] then
			addedEntries[userId] = true
			table.insert(entries, snapshot)
		end
	end
	directoryCache = entries
	directoryCacheAt = os.clock()
	return directoryCache
end

local function refreshOnlineCache()
	if os.clock() - onlineCacheAt <= ONLINE_CACHE_SECONDS then
		return onlineCache
	end

	local nextOnline = {}
	local success, items = pcall(function()
		return onlineMap:GetRangeAsync(Enum.SortDirection.Descending, 100)
	end)
	if success and type(items) == "table" then
		for _, item in ipairs(items) do
			local userId = math.floor(tonumber(item.key) or 0)
			if userId > 0 then
				nextOnline[userId] = true
			end
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		nextOnline[player.UserId] = true
	end
	onlineCache = nextOnline
	onlineCacheAt = os.clock()
	return onlineCache
end

local function heartbeatPlayer(player)
	pcall(function()
		onlineMap:SetAsync(
			keyForUserId(player.UserId),
			{
				JobId = game.JobId,
				UpdatedAt = os.time(),
			},
			ONLINE_TTL_SECONDS,
			os.time()
		)
	end)
	onlineCache[player.UserId] = true
end

local function resolveLikeCount(userId, fallback)
	userId = math.floor(tonumber(userId) or 0)
	if userId <= 0 then
		return 0
	end
	if localLikeCounts[userId] ~= nil then
		return localLikeCounts[userId]
	end

	local success, storedCount = pcall(function()
		return likeCountStore:GetAsync(keyForUserId(userId))
	end)
	localLikeCounts[userId] = math.max(
		0,
		math.floor(tonumber(success and storedCount or fallback) or 0)
	)
	return localLikeCounts[userId]
end

function AquariumDirectoryService.configure(options)
	options = type(options) == "table" and options or {}
	configured.onChanged = options.onChanged
end

function AquariumDirectoryService.start()
	if started then
		return
	end
	started = true

	pcall(function()
		MessagingService:SubscribeAsync(UPDATE_TOPIC, function(message)
			local data = message.Data
			if type(data) == "table" then
				local userId = math.floor(tonumber(data.UserId) or 0)
				if userId > 0 then
					localLikeCounts[userId] = math.max(0, math.floor(tonumber(data.LikeCount) or 0))
					snapshotCache[userId] = nil
					directoryCacheAt = 0
					emitChanged()
				end
			end
		end)
	end)

	task.spawn(function()
		while started do
			for _, player in ipairs(Players:GetPlayers()) do
				heartbeatPlayer(player)
			end
			task.wait(ONLINE_HEARTBEAT_SECONDS)
		end
	end)
end

function AquariumDirectoryService.markOnline(player)
	if not player then
		return
	end
	AquariumDirectoryService.start()
	heartbeatPlayer(player)
end

function AquariumDirectoryService.markOffline(player)
	if not player then
		return
	end
	onlineCache[player.UserId] = nil
	pcall(function()
		onlineMap:RemoveAsync(keyForUserId(player.UserId))
	end)
end

function AquariumDirectoryService.publish(player, snapshot)
	if not player or type(snapshot) ~= "table" then
		return false
	end
	AquariumDirectoryService.start()

	snapshot = copyTable(snapshot)
	snapshot.UserId = player.UserId
	snapshot.Name = player.Name
	snapshot.DisplayName = player.DisplayName
	snapshot.LikeCount = resolveLikeCount(player.UserId, snapshot.LikeCount)
	local signatureOk, signature = pcall(HttpService.JSONEncode, HttpService, snapshot)
	local lastPublish = lastPublishByUserId[player.UserId]
	if signatureOk
		and lastPublish
		and lastPublish.signature == signature
		and os.clock() - lastPublish.publishedAt < UNCHANGED_PUBLISH_COOLDOWN_SECONDS
	then
		heartbeatPlayer(player)
		return true, snapshot.LikeCount
	end
	snapshot.UpdatedAt = os.time()
	cacheSnapshot(snapshot)
	directoryCacheAt = 0
	heartbeatPlayer(player)

	local saved = pcall(function()
		snapshotStore:SetAsync(keyForUserId(player.UserId), snapshot)
		recentStore:SetAsync(keyForUserId(player.UserId), snapshot.UpdatedAt)
		likeRankStore:SetAsync(keyForUserId(player.UserId), snapshot.LikeCount)
	end)
	if signatureOk then
		lastPublishByUserId[player.UserId] = {
			signature = signature,
			publishedAt = os.clock(),
		}
	end
	publishDirectoryUpdate(player.UserId, snapshot.LikeCount)
	return saved, snapshot.LikeCount
end

function AquariumDirectoryService.getLikeCount(userId, fallback)
	return resolveLikeCount(userId, fallback)
end

function AquariumDirectoryService.getSnapshot(userId)
	return loadSnapshot(userId)
end

function AquariumDirectoryService.getDirectory(requestingPlayer, likedTargets, liveEntries)
	AquariumDirectoryService.start()
	likedTargets = type(likedTargets) == "table" and likedTargets or {}
	liveEntries = type(liveEntries) == "table" and liveEntries or {}

	local merged = {}
	local orderedIds = {}
	local function mergeEntry(entry)
		if type(entry) ~= "table" then
			return
		end
		local userId = math.floor(tonumber(entry.UserId) or 0)
		if userId <= 0 then
			return
		end
		if not merged[userId] then
			table.insert(orderedIds, userId)
		end
		merged[userId] = copyTable(entry)
	end

	for _, entry in ipairs(liveEntries) do
		mergeEntry(entry)
	end
	for _, entry in ipairs(refreshDirectoryCache()) do
		if not merged[entry.UserId] then
			mergeEntry(entry)
		end
	end

	local online = refreshOnlineCache()
	local result = {}
	for _, userId in ipairs(orderedIds) do
		local entry = merged[userId]
		table.insert(result, {
			UserId = userId,
			Name = entry.Name,
			DisplayName = entry.DisplayName,
			IsSelf = requestingPlayer and userId == requestingPlayer.UserId or false,
			Online = online[userId] == true,
			LikedByViewer = likedTargets[keyForUserId(userId)] == true,
			LikeCount = resolveLikeCount(userId, entry.LikeCount),
			AquariumLevel = entry.AquariumLevel,
			FishCount = entry.FishCount,
			UsedCapacity = entry.UsedCapacity,
			Capacity = entry.Capacity,
			TotalValue = entry.TotalValue,
			BestCatch = copyTable(entry.BestCatch),
			UpdatedAt = entry.UpdatedAt,
		})
		if #result >= MAX_DIRECTORY_ENTRIES then
			break
		end
	end
	return result
end

function AquariumDirectoryService.toggleLike(viewer, targetUserId, likedTargets)
	if not viewer then
		return false, nil, 0, "Viewer missing."
	end
	targetUserId = math.floor(tonumber(targetUserId) or 0)
	if targetUserId <= 0 or targetUserId == viewer.UserId then
		return false, nil, 0, "Invalid aquarium."
	end

	likedTargets = type(likedTargets) == "table" and likedTargets or {}
	local targetKey = keyForUserId(targetUserId)
	local wasLiked = likedTargets[targetKey] == true
	local delta = wasLiked and -1 or 1
	local fallbackCount = math.max(0, math.floor(tonumber(localLikeCounts[targetUserId]) or 0) + delta)
	local persisted, newCount = pcall(function()
		return likeCountStore:UpdateAsync(targetKey, function(current)
			return math.max(0, math.floor(tonumber(current) or 0) + delta)
		end)
	end)
	if not persisted then
		newCount = fallbackCount
	end
	newCount = math.max(0, math.floor(tonumber(newCount) or fallbackCount))

	if wasLiked then
		likedTargets[targetKey] = nil
	else
		likedTargets[targetKey] = true
	end
	localLikeCounts[targetUserId] = newCount

	pcall(function()
		likeRankStore:SetAsync(targetKey, newCount)
		snapshotStore:UpdateAsync(targetKey, function(snapshot)
			if type(snapshot) ~= "table" then
				return snapshot
			end
			snapshot.LikeCount = newCount
			snapshot.UpdatedAt = os.time()
			return snapshot
		end)
	end)
	snapshotCache[targetUserId] = nil
	directoryCacheAt = 0
	publishDirectoryUpdate(targetUserId, newCount)
	emitChanged()
	return true, not wasLiked, newCount, persisted and nil or "Saved locally; persistent services unavailable."
end

function AquariumDirectoryService.getFeaturedSnapshot()
	local entries = refreshDirectoryCache()
	if #entries == 0 then
		return nil
	end
	table.sort(entries, function(left, right)
		local leftLikes = tonumber(left.LikeCount) or 0
		local rightLikes = tonumber(right.LikeCount) or 0
		if leftLikes ~= rightLikes then
			return leftLikes > rightLikes
		end
		return (tonumber(left.TotalValue) or 0) > (tonumber(right.TotalValue) or 0)
	end)
	local featuredPoolSize = math.min(5, #entries)
	local rotationIndex = (math.floor(os.time() / 600) % featuredPoolSize) + 1
	return copyTable(entries[rotationIndex])
end

return AquariumDirectoryService
