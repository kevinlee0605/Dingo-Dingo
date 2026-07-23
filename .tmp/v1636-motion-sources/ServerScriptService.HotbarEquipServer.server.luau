local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAME = "HotbarEquipRequest"

local hotbarEquipRequest = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not hotbarEquipRequest then
	hotbarEquipRequest = Instance.new("RemoteEvent")
	hotbarEquipRequest.Name = REMOTE_NAME
	hotbarEquipRequest.Parent = ReplicatedStorage
end

local function isBlockedUtilityTool(tool)
	local name = string.lower(tool.Name)
	return name == "bag"
		or name == "backpack"
		or name == "fishdex"
		or name == "fish dex"
		or string.find(name, "aquarium") ~= nil
end

local function isRodTool(tool)
	if not tool:IsA("Tool") then
		return false
	end

	if isBlockedUtilityTool(tool) then
		return false
	end

	local name = string.lower(tool.Name)

	return name == "fishing rod"
		or string.find(name, "rod") ~= nil
		or string.find(name, "fishing") ~= nil
		or tool:GetAttribute("HotbarType") == "Rod"
		or tool:GetAttribute("RodId") ~= nil
end

local function findRodTool(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack")

	if character then
		local exactEquipped = character:FindFirstChild("Fishing Rod")
		if exactEquipped and exactEquipped:IsA("Tool") then
			return exactEquipped
		end

		for _, child in ipairs(character:GetChildren()) do
			if isRodTool(child) then
				return child
			end
		end
	end

	if backpack then
		local exactBackpack = backpack:FindFirstChild("Fishing Rod")
		if exactBackpack and exactBackpack:IsA("Tool") then
			return exactBackpack
		end

		for _, child in ipairs(backpack:GetChildren()) do
			if isRodTool(child) then
				return child
			end
		end
	end

	return nil
end

local function equipRod(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		warn("[HotbarEquipServer] Humanoid not found for", player.Name)
		return
	end

	local tool = findRodTool(player)

	if not tool then
		warn("[HotbarEquipServer] Fishing Rod Tool not found for", player.Name)
		return
	end

	if tool.Parent == character then
		print("[HotbarEquipServer] Fishing Rod already equipped:", player.Name, tool.Name)
		return
	end

	if backpack and tool.Parent ~= backpack then
		tool.Parent = backpack
		task.wait()
	end

	humanoid:EquipTool(tool)

	task.delay(0.1, function()
		if tool and tool.Parent ~= character then
			-- 마지막 안전장치: EquipTool이 실패해도 서버에서 Character 아래로 옮겨 장착 상태로 만듦.
			tool.Parent = character
		end

		print("[HotbarEquipServer] Equipped rod:", player.Name, tool:GetFullName())
	end)
end

local function unequipTools(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not character or not humanoid then
		warn("[HotbarEquipServer] Cannot unequip tools for", player.Name)
		return
	end

	humanoid:UnequipTools()

	-- 서버에서도 Character 아래의 Tool을 Backpack으로 돌려 확실히 맨손 상태로 만듭니다.
	task.defer(function()
		if not backpack then
			return
		end

		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				child.Parent = backpack
			end
		end

		print("[HotbarEquipServer] Unequipped tools:", player.Name)
	end)
end

hotbarEquipRequest.OnServerEvent:Connect(function(player, action)
	if action == "EquipRod" then
		equipRod(player)
	elseif action == "UnequipTools" then
		unequipTools(player)
	end
end)