local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local STORE_NAME = "FishyFish_fish_caught_v1"
local BOARD_MODEL_NAME = "LimestoneFishCaughtLeaderboard"
local DATASTORE_ENABLED = not RunService:IsStudio()
local DEFAULT_BOARD_CFRAME = CFrame.new(-330, 21, -418)

local leaderboardStore = DataStoreService:GetOrderedDataStore(STORE_NAME)

local Service = {
	nameCache = {},
	lastText = nil,
	playerData = {},
}

function Service.configure(options)
	Service.playerData = options and options.playerData or Service.playerData
end

function Service.getDisplayName(userId)
	local cached = Service.nameCache[userId]
	if cached then
		return cached
	end

	local player = Players:GetPlayerByUserId(userId)
	if player then
		Service.nameCache[userId] = player.DisplayName
		return player.DisplayName
	end

	local success, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if success and name then
		Service.nameCache[userId] = name
		return name
	end

	return "Player " .. tostring(userId)
end

function Service.isInsideRuntimeWorld(instance)
	local current = instance
	while current do
		if current.Name == "FishyFishWorld" then
			return true
		end
		current = current.Parent
	end

	return false
end

function Service.findSavedBoardModel()
	local exact = workspace:FindFirstChild(BOARD_MODEL_NAME, true)
	if exact and exact:IsA("Model") and not Service.isInsideRuntimeWorld(exact) then
		return exact
	end

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Model")
			and descendant.Name == "Leaderboard"
			and not Service.isInsideRuntimeWorld(descendant)
			and (
				descendant:FindFirstChild("LeaderboardPanel", true)
				or descendant:FindFirstChild("LeaderboardBoard", true)
				or descendant:FindFirstChild("FishCaughtLeaderboardGui", true)
			)
		then
			return descendant
		end
	end

	return nil
end

function Service.findBoardPanel(model)
	local existingGui = model:FindFirstChild("FishCaughtLeaderboardGui", true)
	if existingGui and existingGui.Parent and existingGui.Parent:IsA("BasePart") then
		return existingGui.Parent
	end

	for _, name in ipairs({ "LeaderboardPanel", "LeaderboardBoard" }) do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end

	return nil
end

function Service.ensurePart(parent, name, size, position, color, material, transparency, canCollide)
	local part = parent:FindFirstChild(name)
	local created = false
	if not part or not part:IsA("BasePart") then
		if part then
			part:Destroy()
		end
		part = Instance.new("Part")
		part.Name = name
		part.Parent = parent
		created = true
		part.Size = size
		part.Position = position
	end

	part.Anchored = true
	if created then
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Transparency = transparency or 0
		part.CanCollide = canCollide ~= false
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

function Service.ensureBoard()
	local model = Service.findSavedBoardModel()
	local createdModel = false
	if not model then
		model = Instance.new("Model")
		model.Name = BOARD_MODEL_NAME
		model.Parent = workspace
		createdModel = true
	end

	local parts = model:FindFirstChild("EditableParts")
	if not parts then
		parts = Instance.new("Folder")
		parts.Name = "EditableParts"
		parts.Parent = model
	end

	local wood = Color3.fromRGB(110, 72, 42)
	local darkWood = Color3.fromRGB(70, 45, 28)
	local boardBlue = Color3.fromRGB(28, 75, 118)
	local gold = Color3.fromRGB(245, 190, 65)

	local panel = Service.findBoardPanel(model)
	local createdPanel = false
	if not panel then
		panel = Service.ensurePart(parts, "LeaderboardPanel", Vector3.new(64, 34, 1.2), DEFAULT_BOARD_CFRAME.Position, boardBlue, Enum.Material.Wood, 0, false)
		createdPanel = true
	end

	if createdModel or createdPanel then
		local boardCFrame = panel.CFrame
		Service.ensurePart(parts, "LeftPost", Vector3.new(2.2, 31, 2.2), (boardCFrame * CFrame.new(-33, -8.5, -0.4)).Position, darkWood, Enum.Material.Wood, 0, true)
		Service.ensurePart(parts, "RightPost", Vector3.new(2.2, 31, 2.2), (boardCFrame * CFrame.new(33, -8.5, -0.4)).Position, darkWood, Enum.Material.Wood, 0, true)
		Service.ensurePart(parts, "TopTrim", Vector3.new(68, 2.2, 2), (boardCFrame * CFrame.new(0, 18, -0.7)).Position, gold, Enum.Material.Metal, 0, false)
		Service.ensurePart(parts, "BottomTrim", Vector3.new(68, 2.2, 2), (boardCFrame * CFrame.new(0, -18, -0.7)).Position, wood, Enum.Material.Wood, 0, true)
	end

	local gui = panel:FindFirstChild("FishCaughtLeaderboardGui")
	if not gui or not gui:IsA("SurfaceGui") then
		if gui then
			gui:Destroy()
		end
		gui = Instance.new("SurfaceGui")
		gui.Name = "FishCaughtLeaderboardGui"
		gui.Parent = panel
	end

	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(1200, 700)
	gui.AlwaysOnTop = false

	local title = gui:FindFirstChild("Title")
	if not title or not title:IsA("TextLabel") then
		if title then
			title:Destroy()
		end
		title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Parent = gui
	end

	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.04, 0.04)
	title.Size = UDim2.fromScale(0.92, 0.2)
	title.Text = "Leaderboard - Most Fish Caught"
	title.TextColor3 = Color3.fromRGB(255, 238, 170)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(10, 18, 28)
	title.TextScaled = true
	title.Font = Enum.Font.FredokaOne

	local rows = gui:FindFirstChild("Rows")
	if not rows or not rows:IsA("TextLabel") then
		if rows then
			rows:Destroy()
		end
		rows = Instance.new("TextLabel")
		rows.Name = "Rows"
		rows.Parent = gui
	end

	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromScale(0.08, 0.27)
	rows.Size = UDim2.fromScale(0.84, 0.66)
	rows.TextColor3 = Color3.fromRGB(245, 250, 255)
	rows.TextStrokeTransparency = 0.25
	rows.TextStrokeColor3 = Color3.fromRGB(5, 10, 18)
	rows.TextScaled = true
	rows.TextXAlignment = Enum.TextXAlignment.Left
	rows.TextYAlignment = Enum.TextYAlignment.Top
	rows.Font = Enum.Font.FredokaOne
	rows.Text = Service.lastText or "1. ---\n2. ---\n3. ---\n4. ---\n5. ---"

	model.PrimaryPart = panel
	return rows
end

function Service.getOnlineRows()
	local rows = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = Service.playerData[player]
		if type(data) == "table" then
			table.insert(rows, {
				userId = player.UserId,
				name = player.DisplayName,
				count = math.max(0, math.floor(tonumber(data.TotalFishCaught) or 0)),
			})
		end
	end

	table.sort(rows, function(a, b)
		if a.count == b.count then
			return a.name < b.name
		end
		return a.count > b.count
	end)

	while #rows > 5 do
		table.remove(rows)
	end

	return rows
end

function Service.getStoredRows()
	if not DATASTORE_ENABLED then
		return nil
	end

	local success, pages = pcall(function()
		return leaderboardStore:GetSortedAsync(false, 5)
	end)

	if not success then
		return nil
	end

	local rows = {}
	for _, item in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(item.key)
		if userId then
			table.insert(rows, {
				userId = userId,
				name = Service.getDisplayName(userId),
				count = tonumber(item.value) or 0,
			})
		end
	end

	return rows
end

function Service.setRows(rows)
	local textRows = {}
	for index = 1, 5 do
		local row = rows[index]
		if row and row.count > 0 then
			table.insert(textRows, string.format("%d. %s - %d", index, row.name, row.count))
		else
			table.insert(textRows, string.format("%d. ---", index))
		end
	end

	Service.lastText = table.concat(textRows, "\n")
	local label = Service.ensureBoard()
	label.Text = Service.lastText
end

function Service.refresh(useOnlineFallback)
	local rows = Service.getStoredRows()
	if not rows or #rows == 0 then
		rows = useOnlineFallback and Service.getOnlineRows() or {}
	end
	Service.setRows(rows)
end

function Service.publish(player, data)
	local count = math.max(0, math.floor(tonumber(data.TotalFishCaught) or 0))
	if not DATASTORE_ENABLED then
		Service.refresh(true)
		return
	end

	task.spawn(function()
		local success, err = pcall(function()
			leaderboardStore:SetAsync(tostring(player.UserId), count)
		end)
		if not success then
			warn("Fish caught leaderboard update failed for", player.UserId, err)
		end
		Service.refresh(true)
	end)
end

return Service
