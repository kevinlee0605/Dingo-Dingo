local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishdexService = {}

local remotesFolder = ReplicatedStorage:FindFirstChild("FishingRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "FishingRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local getFishdexData = remotesFolder:FindFirstChild("GetFishdexData")
if not getFishdexData then
	getFishdexData = Instance.new("RemoteFunction")
	getFishdexData.Name = "GetFishdexData"
	getFishdexData.Parent = remotesFolder
end

local fishdexUpdated = remotesFolder:FindFirstChild("FishdexUpdated")
if not fishdexUpdated then
	fishdexUpdated = Instance.new("RemoteEvent")
	fishdexUpdated.Name = "FishdexUpdated"
	fishdexUpdated.Parent = remotesFolder
end

local cache = {}

local function cloneTable(t)
	local copy = {}
	if type(t) ~= "table" then
		return copy
	end

	for k, v in pairs(t) do
		copy[k] = v
	end
	return copy
end

function FishdexService.Hydrate(player, fishdexTable)
	cache[player] = cloneTable(fishdexTable or {})
end

function FishdexService.Push(player, fishdexTable)
	cache[player] = cloneTable(fishdexTable or {})
	fishdexUpdated:FireClient(player, cache[player])
end

function FishdexService.MarkDiscovered(player, fishId)
	if not player or not fishId then
		return
	end

	local dex = cache[player] or {}
	dex[tostring(fishId)] = true
	cache[player] = dex

	fishdexUpdated:FireClient(player, dex)
end

function FishdexService.Get(player)
	return cloneTable(cache[player] or {})
end

getFishdexData.OnServerInvoke = function(player)
	return FishdexService.Get(player)
end

Players.PlayerRemoving:Connect(function(player)
	cache[player] = nil
end)

return FishdexService