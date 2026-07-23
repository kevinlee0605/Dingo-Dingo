local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AquariumDirectoryService = {}

local ENVIRONMENT_SUFFIX = RunService:IsStudio() and "_studio" or ""
local SNAPSHOT_STORE_NAME = "FishyFish_AquariumDirectorySnapshots_v1" .. ENVIRONMENT_SUFFIX
local LIKE_COUNT_STORE_NAME = "FishyFish_AquariumLikeCounts_v1" .. ENVIRONMENT_SUFFIX
local LIKE_RANK_STORE_NAME = "FishyFish_AquariumLikeRanking_v1" .. ENVIRONMENT_SUFFIX
local RECENT_STORE_NAME = "FishyFish_AquariumRecent_v1" .. ENVIRONMENT_SUFFIX
local ONLINE_MAP_NAME = "FishyFish_AquariumOnline_v1" .. ENVIRONMENT_SUFFIX
local UPDATE_TOPIC = "FishyFish_AquariumDirectory_v1" .. ENVIRONMENT_SUFFIX

local DIRECTORY_CACHE_SECONDS = 30
local SNAPSHOT_CACHE_SECONDS = 90
local ONLINE_CACHE_SECONDS = 15
local ONLINE_TTL_SECONDS = 105
local ONLINE_HEARTBEAT_SECONDS = 40
local MAX_DIRECTORY_ENTRIES = 24
local UNCHANGED_PUBLISH_COOLDOWN_SECONDS = 30
local FEATURED_POOL_SIZE = 5
local FEATURED_ROTATION_SECONDS = 600
local LIKE_COUNT_CACHE_SECONDS = 30
local CLOUD_OPERATION_ATTEMPTS = 3
local CLOUD_RETRY_BASE_SECONDS = 0.35
local MAX_SAFE_USER_ID = 9007199254740991
local SESSION_ID = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)

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
local localLikeCountsAt = {}
local lastPublishByUserId = {}
local directorySubscription = nil
local toggleLikeInFlight = {}
local presenceKeyByPlayer = setmetatable({}, { __mode = "k" })
local presenceActiveByPlayer = setmetatable({}, { __mode = "k" })

local function normalizeUserId(userId)
	local numericUserId = tonumber(userId)
	if not numericUserId
		or numericUserId ~= numericUserId
		or numericUserId == math.huge
		or numericUserId == -math.huge
		or numericUserId < 1
		or numericUserId > MAX_SAFE_USER_ID
		or numericUserId % 1 ~= 0
	then
		return nil
	end
	return math.floor(numericUserId)
end

local function keyForUserId(userId)
	return tostring(normalizeUserId(userId) or 0)
end

local function presenceKeyForPlayer(player)
	local key = presenceKeyByPlayer[player]
	if not key then
		key = keyForUserId(player.UserId) .. ":" .. SESSION_ID .. ":" .. HttpService:GenerateGUID(false)
		presenceKeyByPlayer[player] = key
	end
	return key
end

local function userIdFromPresenceKey(key)
	if type(key) ~= "string" then
		return nil
	end
	local encodedUserId = string.match(key, "^(%d+):") or string.match(key, "^(%d+)$")
	return normalizeUserId(encodedUserId)
end

local function retryCloudOperation(operation, attempts)
	local lastError
	for attempt = 1, attempts or CLOUD_OPERATION_ATTEMPTS do
		local success, result = pcall(operation)
		if success then
			return true, result
		end
		lastError = result
		if attempt < (attempts or CLOUD_OPERATION_ATTEMPTS) then
			task.wait(CLOUD_RETRY_BASE_SECONDS * (2 ^ (attempt - 1)))
		end
	end
	return false, lastError
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
	task.spawn(function()
		retryCloudOperation(function()
			MessagingService:PublishAsync(UPDATE_TOPIC, {
				UserId = userId,
				LikeCount = likeCount,
				UpdatedAt = os.time(),
			})
		end, 2)
	end)
end

local function cacheSnapshot(snapshot)
	if type(snapshot) ~= "table" then
		return nil
	end
	local userId = normalizeUserId(snapshot.UserId)
	if not userId then
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
	snapshotCache[userId] = nil
	return nil
end

local function loadSnapshot(userId)
	userId = normalizeUserId(userId)
	if not userId then
		return nil
	end

	local cached = getCachedSnapshot(userId)
	if cached then
		return cached
	end

	local success, snapshot = retryCloudOperation(function()
		return snapshotStore:GetAsync(keyForUserId(userId))
	end, 2)
	if success
		and type(snapshot) == "table"
		and normalizeUserId(snapshot.UserId) == userId
	then
		cacheSnapshot(snapshot)
		return copyTable(snapshot)
	end
	return nil
end

local function readOrderedUserIds(store, count)
	local success, pages = retryCloudOperation(function()
		return store:GetSortedAsync(false, count)
	end, 2)
	if not success or not pages then
		return {}
	end

	local ids = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		local userId = normalizeUserId(entry.key)
		if userId then
			table.insert(ids, userId)
		end
	end
	return ids
end

local function refreshDirectoryCache()
	if directoryCache
		and directoryCacheAt > 0
		and os.clock() - directoryCacheAt <= DIRECTORY_CACHE_SECONDS
	then
		return directoryCache
	end
	local now = os.clock()
	for userId, cached in pairs(snapshotCache) do
		if not cached or now - (tonumber(cached.cachedAt) or 0) > SNAPSHOT_CACHE_SECONDS then
			snapshotCache[userId] = nil
		end
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
	for _, userId in ipairs(orderedIds) do
		local snapshot = loadSnapshot(userId)
		if snapshot then
			table.insert(entries, snapshot)
		end
	end
	directoryCache = entries
	directoryCacheAt = os.clock()
	return directoryCache
end

local function refreshOnlineCache()
	if onlineCacheAt > 0 and os.clock() - onlineCacheAt <= ONLINE_CACHE_SECONDS then
		return onlineCache
	end

	local nextOnline = {}
	local success, items = retryCloudOperation(function()
		return onlineMap:GetRangeAsync(Enum.SortDirection.Descending, 200)
	end, 2)
	if success and type(items) == "table" then
		for _, item in ipairs(items) do
			local userId = userIdFromPresenceKey(item.key)
			if userId then
				nextOnline[userId] = true
			end
		end
	else
		-- A transient MemoryStore read must not mark every remote player offline.
		for userId, isOnline in pairs(onlineCache) do
			if isOnline then
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
	if not player or player.Parent ~= Players then
		return
	end
	presenceActiveByPlayer[player] = true
	local presenceKey = presenceKeyForPlayer(player)
	retryCloudOperation(function()
		onlineMap:SetAsync(
			presenceKey,
			{
				JobId = game.JobId,
				UpdatedAt = os.time(),
			},
			ONLINE_TTL_SECONDS,
			os.time()
		)
	end, 2)
	if presenceActiveByPlayer[player] == true and player.Parent == Players then
		onlineCache[player.UserId] = true
	else
		-- If PlayerRemoving raced the yielding heartbeat, remove the write again
		-- after it completes so a departed player cannot remain online until TTL.
		retryCloudOperation(function()
			onlineMap:RemoveAsync(presenceKey)
		end, 2)
	end
end

local function resolveLikeCount(userId, fallback)
	userId = normalizeUserId(userId)
	if not userId then
		return 0
	end
	if localLikeCounts[userId] ~= nil
		and os.clock() - (localLikeCountsAt[userId] or 0) <= LIKE_COUNT_CACHE_SECONDS
	then
		return localLikeCounts[userId]
	end

	local success, storedCount = retryCloudOperation(function()
		return likeCountStore:GetAsync(keyForUserId(userId))
	end, 2)
	local resolved = math.max(0, math.floor(tonumber(success and storedCount or fallback) or 0))
	if success then
		localLikeCounts[userId] = resolved
		localLikeCountsAt[userId] = os.clock()
	else
		localLikeCounts[userId] = nil
		localLikeCountsAt[userId] = nil
	end
	return resolved
end

local function getFeaturedPool(entries)
	local pool = {}
	for _, entry in ipairs(entries or {}) do
		if type(entry) == "table" and normalizeUserId(entry.UserId) then
			table.insert(pool, entry)
		end
	end
	table.sort(pool, function(left, right)
		local leftLikes = tonumber(left.LikeCount) or 0
		local rightLikes = tonumber(right.LikeCount) or 0
		if leftLikes ~= rightLikes then
			return leftLikes > rightLikes
		end
		local leftValue = tonumber(left.TotalValue) or 0
		local rightValue = tonumber(right.TotalValue) or 0
		if leftValue ~= rightValue then
			return leftValue > rightValue
		end
		local leftUpdatedAt = tonumber(left.UpdatedAt) or 0
		local rightUpdatedAt = tonumber(right.UpdatedAt) or 0
		if leftUpdatedAt ~= rightUpdatedAt then
			return leftUpdatedAt > rightUpdatedAt
		end
		return (normalizeUserId(left.UserId) or 0) < (normalizeUserId(right.UserId) or 0)
	end)
	while #pool > FEATURED_POOL_SIZE do
		table.remove(pool)
	end
	return pool
end

local function getFeaturedRotationIndex(poolSize)
	if poolSize <= 0 then
		return nil
	end
	return (math.floor(os.time() / FEATURED_ROTATION_SECONDS) % poolSize) + 1
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

	task.spawn(function()
		local failedAttempts = 0
		while started and not directorySubscription do
			local success, connectionOrError = pcall(function()
				return MessagingService:SubscribeAsync(UPDATE_TOPIC, function(message)
					local data = message.Data
					local userId = type(data) == "table" and normalizeUserId(data.UserId) or nil
					if not userId then
						return
					end

					-- MessagingService is best-effort and messages can arrive out of order.
					-- Invalidate instead of trusting the payload as authoritative; the next
					-- state build reloads the durable count and snapshot.
					localLikeCounts[userId] = nil
					localLikeCountsAt[userId] = nil
					snapshotCache[userId] = nil
					directoryCache = nil
					directoryCacheAt = 0
					emitChanged()
				end)
			end)
			if success and connectionOrError then
				directorySubscription = connectionOrError
				break
			end
			if success then
				connectionOrError = "SubscribeAsync returned no connection"
			end

			failedAttempts += 1
			if not RunService:IsStudio() or failedAttempts == 1 then
				warn("Aquarium directory messaging subscription failed; retrying:", connectionOrError)
			end
			task.wait(math.min(30, 2 ^ math.min(failedAttempts, 5)))
		end
	end)

	task.spawn(function()
		while started do
			for _, player in ipairs(Players:GetPlayers()) do
				heartbeatPlayer(player)
			end
			task.wait(ONLINE_HEARTBEAT_SECONDS)
		end
	end)

	-- Query immediately rather than treating the initial empty table as a valid
	-- 15-second cache entry.
	task.spawn(refreshOnlineCache)

	-- Featured order is time-based, so clients need one state invalidation at
	-- every ten-minute boundary even if no aquarium data changes.
	task.spawn(function()
		while started do
			local now = os.time()
			local secondsUntilRotation = FEATURED_ROTATION_SECONDS - (now % FEATURED_ROTATION_SECONDS)
			task.wait(math.max(1, secondsUntilRotation + 0.1))
			directoryCache = nil
			directoryCacheAt = 0
			emitChanged()
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
	onlineCacheAt = 0
	presenceActiveByPlayer[player] = false
	local presenceKey = presenceKeyByPlayer[player]
	presenceKeyByPlayer[player] = nil
	if not presenceKey then
		return
	end
	task.spawn(function()
		-- Presence keys include this server session, so a delayed departure from an
		-- old player object cannot erase the same user's newer-session heartbeat.
		retryCloudOperation(function()
			onlineMap:RemoveAsync(presenceKey)
		end, 2)
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
	local likeCountResolvedAt = DateTime.now().UnixTimestampMillis
	heartbeatPlayer(player)
	local signatureOk, signature = pcall(HttpService.JSONEncode, HttpService, snapshot)
	local lastPublish = lastPublishByUserId[player.UserId]
	if signatureOk
		and lastPublish
		and lastPublish.signature == signature
		and os.clock() - lastPublish.publishedAt < UNCHANGED_PUBLISH_COOLDOWN_SECONDS
	then
		return true, snapshot.LikeCount
	end

	local userKey = keyForUserId(player.UserId)
	snapshot.UpdatedAt = DateTime.now().UnixTimestampMillis
	local snapshotSaved, savedSnapshotOrError = retryCloudOperation(function()
		return snapshotStore:UpdateAsync(userKey, function(current)
			if type(current) == "table"
				and (tonumber(current.UpdatedAt) or 0) > snapshot.UpdatedAt
			then
				-- Never allow a delayed publish from an older server/session to
				-- replace a newer durable aquarium snapshot.
				return nil
			end
			if type(current) == "table"
				and (tonumber(current.LikeUpdatedAt) or 0) > likeCountResolvedAt
			then
				-- Preserve a like mutation that committed while this snapshot publish
				-- was waiting on the data store.
				snapshot.LikeCount = math.max(0, math.floor(tonumber(current.LikeCount) or snapshot.LikeCount or 0))
				snapshot.LikeUpdatedAt = current.LikeUpdatedAt
				if type(snapshot.Aquarium) == "table" then
					snapshot.Aquarium.LikeCount = snapshot.LikeCount
				end
			end
			return snapshot
		end)
	end)
	if not snapshotSaved then
		return false, snapshot.LikeCount
	end

	-- UpdateAsync returns nil when the transform intentionally rejects an older
	-- value. In that case the newer durable snapshot already wins.
	if type(savedSnapshotOrError) ~= "table" then
		snapshotCache[player.UserId] = nil
		directoryCache = nil
		directoryCacheAt = 0
		return true, snapshot.LikeCount
	end

	cacheSnapshot(savedSnapshotOrError)
	directoryCache = nil
	directoryCacheAt = 0

	local recentSaved = retryCloudOperation(function()
		return recentStore:SetAsync(userKey, snapshot.UpdatedAt)
	end)
	local rankSaved = retryCloudOperation(function()
		return likeRankStore:SetAsync(userKey, snapshot.LikeCount)
	end)
	local fullyIndexed = recentSaved and rankSaved
	if signatureOk and fullyIndexed then
		lastPublishByUserId[player.UserId] = {
			signature = signature,
			publishedAt = os.clock(),
		}
	end
	publishDirectoryUpdate(player.UserId, snapshot.LikeCount)
	return fullyIndexed, snapshot.LikeCount
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
		local userId = normalizeUserId(entry.UserId)
		if not userId then
			return
		end
		if not merged[userId] then
			table.insert(orderedIds, userId)
		end
		local copiedEntry = copyTable(entry)
		copiedEntry.UserId = userId
		merged[userId] = copiedEntry
	end

	for _, entry in ipairs(liveEntries) do
		mergeEntry(entry)
	end

	local savedEntries = refreshDirectoryCache()
	local featuredCandidates = copyTable(savedEntries)
	for _, entry in ipairs(featuredCandidates) do
		entry.LikeCount = resolveLikeCount(entry.UserId, entry.LikeCount)
	end
	local featuredPool = getFeaturedPool(featuredCandidates)
	-- Guarantee that the canonical rotating featured pool is present even when
	-- all 12 live-server aquariums precede the saved global directory entries.
	for _, entry in ipairs(featuredPool) do
		if not merged[entry.UserId] then
			mergeEntry(entry)
		end
	end
	for _, entry in ipairs(savedEntries) do
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

	local rotationIndex = getFeaturedRotationIndex(#featuredPool)
	for rank, featuredEntry in ipairs(featuredPool) do
		for _, resultEntry in ipairs(result) do
			if resultEntry.UserId == featuredEntry.UserId then
				resultEntry.Featured = true
				resultEntry.FeaturedRank = rank
				resultEntry.FeaturedOrder = ((rank - rotationIndex) % #featuredPool) + 1
				resultEntry.IsCurrentFeatured = rank == rotationIndex
				break
			end
		end
	end
	return result
end

function AquariumDirectoryService.toggleLike(viewer, targetUserId, likedTargets)
	if not viewer then
		return false, nil, 0, "Viewer missing."
	end
	local viewerUserId = normalizeUserId(viewer.UserId)
	targetUserId = normalizeUserId(targetUserId)
	if not viewerUserId or not targetUserId or targetUserId == viewerUserId then
		return false, nil, 0, "Invalid aquarium."
	end
	if toggleLikeInFlight[viewerUserId] then
		return false, nil, resolveLikeCount(targetUserId, 0), "Please wait for the previous like request."
	end
	toggleLikeInFlight[viewerUserId] = true
	local function finish(...)
		toggleLikeInFlight[viewerUserId] = nil
		return ...
	end

	-- Do not let an arbitrary remote-supplied user id create phantom ranking
	-- records. A local live player is allowed while their initial snapshot write
	-- is still completing; offline targets require a durable snapshot.
	local targetSnapshot = loadSnapshot(targetUserId)
	if not Players:GetPlayerByUserId(targetUserId) and not targetSnapshot then
		return finish(false, nil, 0, "That aquarium is not available.")
	end

	likedTargets = type(likedTargets) == "table" and likedTargets or {}
	local targetKey = keyForUserId(targetUserId)
	local wasLiked = likedTargets[targetKey] == true
	local delta = wasLiked and -1 or 1
	local snapshotLikeCount = type(targetSnapshot) == "table" and targetSnapshot.LikeCount or 0
	local currentCount = resolveLikeCount(targetUserId, snapshotLikeCount)
	local fallbackCount = math.max(0, currentCount + delta)
	local persisted, newCount = retryCloudOperation(function()
		return likeCountStore:UpdateAsync(targetKey, function(current)
			-- Migrate legacy aquariums whose count exists only in the snapshot/profile
			-- instead of resetting their first toggle to zero or one.
			local baseCount = math.max(0, math.floor(tonumber(current) or currentCount))
			return math.max(0, baseCount + delta)
		end)
	end)
	if not persisted then
		if not RunService:IsStudio() then
			return finish(false, nil, currentCount, "Like service is temporarily unavailable.")
		end
		-- Studio uses isolated store names and may run without API access. Keep a
		-- local-only fallback there so the interaction remains testable without
		-- pretending the operation was globally durable.
		newCount = fallbackCount
	end
	newCount = math.max(0, math.floor(tonumber(newCount) or fallbackCount))

	if wasLiked then
		likedTargets[targetKey] = nil
	else
		likedTargets[targetKey] = true
	end
	localLikeCounts[targetUserId] = newCount
	localLikeCountsAt[targetUserId] = os.clock()

	local directoryMetadataSaved = true
	if persisted then
		local rankSaved = retryCloudOperation(function()
			return likeRankStore:SetAsync(targetKey, newCount)
		end)
		local snapshotWasPresent = false
		local snapshotLikeSaved = retryCloudOperation(function()
			snapshotWasPresent = false
			return snapshotStore:UpdateAsync(targetKey, function(snapshot)
				if type(snapshot) ~= "table" then
					return snapshot
				end
				snapshotWasPresent = true
				snapshot.LikeCount = newCount
				if type(snapshot.Aquarium) == "table" then
					snapshot.Aquarium.LikeCount = newCount
				end
				snapshot.LikeUpdatedAt = DateTime.now().UnixTimestampMillis
				return snapshot
			end)
		end)
		directoryMetadataSaved = rankSaved and snapshotLikeSaved and snapshotWasPresent
	end
	snapshotCache[targetUserId] = nil
	directoryCache = nil
	directoryCacheAt = 0
	if persisted then
		publishDirectoryUpdate(targetUserId, newCount)
	end
	emitChanged()
	local warning
	if not persisted then
		warning = "Saved locally for this Studio test only."
	elseif not directoryMetadataSaved then
		warning = "Like saved; directory ranking refresh is delayed."
	end
	return finish(true, not wasLiked, newCount, warning)
end

function AquariumDirectoryService.getFeaturedSnapshot()
	local entries = copyTable(refreshDirectoryCache())
	for _, entry in ipairs(entries) do
		entry.LikeCount = resolveLikeCount(entry.UserId, entry.LikeCount)
	end
	local pool = getFeaturedPool(entries)
	local rotationIndex = getFeaturedRotationIndex(#pool)
	if not rotationIndex then
		return nil
	end
	return copyTable(pool[rotationIndex])
end

return AquariumDirectoryService
