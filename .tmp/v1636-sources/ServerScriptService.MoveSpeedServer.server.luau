local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MIN_SPEED = 8
local MAX_SPEED = 24
local DEFAULT_SPEED = 16

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")

if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local setMoveSpeedRemote =
	remotesFolder:FindFirstChild("SetMoveSpeed")

if not setMoveSpeedRemote then
	setMoveSpeedRemote = Instance.new("RemoteEvent")
	setMoveSpeedRemote.Name = "SetMoveSpeed"
	setMoveSpeedRemote.Parent = remotesFolder
end

local lastRequests = {}

local function validateSpeed(value)
	if typeof(value) ~= "number" then
		return nil
	end

	-- NaN 방지
	if value ~= value then
		return nil
	end

	return math.clamp(
		math.round(value),
		MIN_SPEED,
		MAX_SPEED
	)
end

local function applyPlayerSpeed(player, character)
	local humanoid =
		character:WaitForChild("Humanoid", 10)

	if not humanoid then
		return
	end

	local savedSpeed =
		validateSpeed(player:GetAttribute("MoveSpeed"))
		or DEFAULT_SPEED

	player:SetAttribute("MoveSpeed", savedSpeed)
	humanoid.WalkSpeed = savedSpeed
end

local function setupPlayer(player)
	if player:GetAttribute("MoveSpeed") == nil then
		player:SetAttribute("MoveSpeed", DEFAULT_SPEED)
	end

	player.CharacterAdded:Connect(function(character)
		applyPlayerSpeed(player, character)
	end)

	if player.Character then
		task.spawn(
			applyPlayerSpeed,
			player,
			player.Character
		)
	end
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

setMoveSpeedRemote.OnServerEvent:Connect(
	function(player, requestedSpeed)
		local currentTime = os.clock()
		local previousTime = lastRequests[player] or 0

		if currentTime - previousTime < 0.05 then
			return
		end

		lastRequests[player] = currentTime

		local validSpeed =
			validateSpeed(requestedSpeed)

		if not validSpeed then
			return
		end

		player:SetAttribute("MoveSpeed", validSpeed)

		local character = player.Character
		local humanoid = character
			and character:FindFirstChildOfClass("Humanoid")

		if humanoid then
			humanoid.WalkSpeed = validSpeed
		end
	end
)

Players.PlayerRemoving:Connect(function(player)
	lastRequests[player] = nil
end)