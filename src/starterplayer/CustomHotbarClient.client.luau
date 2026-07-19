local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

print("[CustomHotbar] Started")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local backpack = player:WaitForChild("Backpack")
local hotbarEquipRequest = ReplicatedStorage:WaitForChild("HotbarEquipRequest", 10)

if not hotbarEquipRequest then
	warn("[CustomHotbar] HotbarEquipRequest RemoteEvent not found. Add HotbarEquipServer to ServerScriptService.")
end

-- 네 가방 이미지 ID
local BAG_ICON = "rbxassetid://75795273892452"

-- Fishdex 이미지 ID
local FISHDEX_ICON = "rbxassetid://135629767511743"

-- EquippedRodIcon이 비어있을 때만 쓰는 기본 낚싯대 이미지
-- 다른 기본 낚싯대 이미지를 쓰고 싶으면 이 ID만 바꾸면 됨.
local ROD_FALLBACK_ICON = "rbxassetid://105149981299569"

local SLOT_WIDTH = 96
local SLOT_HEIGHT = 88
local SLOT_PADDING = 10

local NORMAL_SCALE = 1
local SELECTED_SCALE = 1.12
local TWEEN_TIME = 0.13

-- 디바이스별 핫바 전체 크기 조정값
-- PC는 1, 태블릿/폰은 화면 크기에 따라 아래 값으로 자동 축소됨.
local HOTBAR_SCALE_PC = 1.6

-- Average Laptop 전용 크기.
-- Roblox Studio의 Average Laptop 미리보기나 1366x768 / 1440x900 / 1536x864 근처 화면에서 적용됨.
-- Average Laptop에서 작으면 이 값만 올리면 됨. 추천 범위: 1.2 ~ 1.6
local HOTBAR_SCALE_AVERAGE_LAPTOP = 1.4

local HOTBAR_SCALE_TABLET = 1.6
local HOTBAR_SCALE_PHONE_LANDSCAPE = 0.82
local HOTBAR_SCALE_PHONE_PORTRAIT = 1
local HOTBAR_SCALE_TINY_PHONE = 0.94

-- 하단 위치 조정값. 음수 숫자가 커질수록 위로 올라감.
local HOTBAR_BOTTOM_OFFSET_PC = -18
local HOTBAR_BOTTOM_OFFSET_TOUCH = -24
local HOTBAR_BOTTOM_OFFSET_SHORT_SCREEN = -12

local selectedSlot = nil
local slots = {}
local currentTools = {}

local activateSlot
local updateHotbar

-- PC/노트북에서는 1, 2, 3 숫자 박스를 표시하고,
-- 터치 디바이스(휴대폰/태블릿)에서는 숨깁니다.
local function shouldShowHotbarNumbers()
	return not UserInputService.TouchEnabled
end

-- 기본 Roblox 핫바 끄기
-- 가끔 CoreGui가 늦게 켜질 때가 있어서 여러 번 꺼줌.
task.spawn(function()
	for _ = 1, 30 do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		task.wait(0.1)
	end
end)

-- The exact v1615 visual tree is authored in StarterGui > CustomHotbarGui.
-- This LocalScript owns behavior only and binds the cloned PlayerGui objects.
local function requireAuthoredChild(parent, childName, className)
	local child = parent:WaitForChild(childName, 30)
	assert(
		child and child:IsA(className),
		string.format("[CustomHotbar] Authored %s (%s) is missing", childName, className)
	)
	return child
end

local screenGui = script:FindFirstAncestor("CustomHotbarGui")
if not screenGui then
	screenGui = playerGui:WaitForChild("CustomHotbarGui", 30)
end
if not screenGui or not screenGui:IsA("ScreenGui") then
	warn("[CustomHotbar] Authored CustomHotbarGui is missing; controller was not bound.")
	return
end
if screenGui:GetAttribute("AuthoredCustomHotbar") ~= true then
	warn("[CustomHotbar] CustomHotbarGui is not the authored v1615 surface; refusing to bind it.")
	return
end

if screenGui:GetAttribute("CustomHotbarControllerBound") == true then
	warn("[CustomHotbar] A controller is already bound; skipping the duplicate copy.")
	return
end
screenGui:SetAttribute("CustomHotbarControllerBound", true)

local holder = requireAuthoredChild(screenGui, "Holder", "Frame")
local deviceScale = requireAuthoredChild(holder, "DeviceScale", "UIScale")

local cameraViewportConnection = nil

local function updateHotbarDeviceScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local viewport = camera.ViewportSize
	local screenWidth = viewport.X
	local screenHeight = viewport.Y
	local minSide = math.min(screenWidth, screenHeight)
	local maxSide = math.max(screenWidth, screenHeight)
	local isTouch = UserInputService.TouchEnabled

	local scale = HOTBAR_SCALE_PC
	local bottomOffset = HOTBAR_BOTTOM_OFFSET_PC

	if isTouch then
		bottomOffset = HOTBAR_BOTTOM_OFFSET_TOUCH

		-- 작은 폰 세로 화면
		if minSide <= 430 and maxSide <= 950 then
			scale = HOTBAR_SCALE_TINY_PHONE

			-- 일반 폰 세로 화면
		elseif minSide <= 520 then
			scale = HOTBAR_SCALE_PHONE_PORTRAIT

			-- 폰 가로 또는 작은 태블릿
		elseif minSide <= 760 then
			scale = HOTBAR_SCALE_PHONE_LANDSCAPE

			-- 태블릿
		else
			scale = HOTBAR_SCALE_TABLET
		end
	else
		-- PC / Laptop 화면
		-- Average Laptop 미리보기는 보통 screenWidth <= 1600, screenHeight <= 1000 범위에 들어감.
		-- 이 조건을 먼저 검사해야 1366x768, 1440x900, 1536x864 같은 노트북에서 작게 보이지 않음.
		if screenWidth <= 1600 and screenHeight <= 1000 then
			scale = HOTBAR_SCALE_AVERAGE_LAPTOP

			-- PC 창을 아주 작게 줄였을 때만 축소
		elseif minSide <= 650 then
			scale = 0.82
		elseif minSide <= 850 then
			scale = 0.92
		else
			scale = HOTBAR_SCALE_PC
		end
	end

	-- 화면 높이가 낮은 가로 화면에서는 더 줄임
	if screenHeight <= 520 then
		scale = scale * 0.9
		bottomOffset = HOTBAR_BOTTOM_OFFSET_SHORT_SCREEN
	end

	deviceScale.Scale = math.clamp(scale, 0.58, 2)
	holder.Position = UDim2.new(0.5, 0, 1, bottomOffset)
end

local function bindCameraViewportScale()
	if cameraViewportConnection then
		cameraViewportConnection:Disconnect()
		cameraViewportConnection = nil
	end

	local camera = workspace.CurrentCamera
	if camera then
		cameraViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateHotbarDeviceScale)
		updateHotbarDeviceScale()
	end
end

bindCameraViewportScale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCameraViewportScale)

requireAuthoredChild(holder, "UIListLayout", "UIListLayout")

for index = 1, 3 do
	local button = requireAuthoredChild(holder, "Slot" .. index, "TextButton")
	local icon = requireAuthoredChild(button, "Icon", "ImageLabel")
	local label = requireAuthoredChild(button, "Label", "TextLabel")
	local stroke = requireAuthoredChild(button, "UIStroke", "UIStroke")
	local scale = requireAuthoredChild(button, "UIScale", "UIScale")
	local numberBox = requireAuthoredChild(button, "NumberBox", "TextLabel")

	slots[index] = {
		Button = button,
		Icon = icon,
		Label = label,
		Stroke = stroke,
		Scale = scale,
		NumberBox = numberBox,
	}

	button.MouseButton1Click:Connect(function()
		if activateSlot then
			activateSlot(index)
		end
	end)
end

local function updateHotbarNumberVisibility()
	local shouldShow = shouldShowHotbarNumbers()

	for _, slot in pairs(slots) do
		if slot.NumberBox then
			slot.NumberBox.Visible = shouldShow
		end
	end
end

updateHotbarNumberVisibility()

-- 디바이스 입력 환경이 바뀌면 숫자 박스 표시 상태도 즉시 갱신합니다.
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(updateHotbarNumberVisibility)

local function cleanAssetId(value)
	if value == nil then
		return ""
	end

	local text = tostring(value)
	if text == "" then
		return ""
	end

	if string.find(text, "rbxassetid://") then
		return text
	end

	if tonumber(text) then
		return "rbxassetid://" .. text
	end

	return text
end

local function isBagTool(tool)
	if not tool:IsA("Tool") then
		return false
	end

	local name = string.lower(tool.Name)
	return name == "bag" or name == "backpack"
end

local function isFishdexTool(tool)
	if not tool:IsA("Tool") then
		return false
	end

	local name = string.lower(tool.Name)
	return name == "fishdex" or name == "fish dex" or name == "fishbook"
end

local function isAquariumTool(tool)
	if not tool:IsA("Tool") then
		return false
	end

	local name = string.lower(tool.Name)
	return string.find(name, "aquarium") ~= nil
end

local function isRodTool(tool)
	if not tool:IsA("Tool") then
		return false
	end

	if isBagTool(tool) or isFishdexTool(tool) or isAquariumTool(tool) then
		return false
	end

	local name = string.lower(tool.Name)

	if string.find(name, "rod") then
		return true
	end

	if string.find(name, "fishing") then
		return true
	end

	if tool:GetAttribute("RodId") ~= nil then
		return true
	end

	if tool:GetAttribute("HotbarType") == "Rod" then
		return true
	end

	return false
end

local function getAllTools()
	local tools = {}

	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") then
			table.insert(tools, child)
		end
	end

	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end

	return tools
end

local function getEquippedTool()
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Tool")
end

local function findRodTool(tools)
	local character = player.Character

	-- 1순위: 실제 손에 들고 있는 낚싯대 Tool
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and isRodTool(child) then
				return child
			end
		end
	end

	-- 2순위: Tool Attribute로 현재 장착 낚싯대 표시가 되어 있는 경우
	for _, tool in ipairs(tools) do
		if isRodTool(tool) and tool:GetAttribute("IsEquippedRod") == true then
			return tool
		end
	end

	-- 3순위: FishingClient가 player Attribute에 저장한 EquippedRodId와 일치하는 Tool
	local equippedRodId =
		player:GetAttribute("EquippedRodId")
		or player:GetAttribute("CurrentRodId")
		or player:GetAttribute("SelectedRodId")

	if equippedRodId then
		for _, tool in ipairs(tools) do
			if isRodTool(tool) then
				local toolRodId = tool:GetAttribute("RodId") or tool.Name
				if tostring(toolRodId) == tostring(equippedRodId) then
					return tool
				end
			end
		end
	end

	-- 4순위: 일반 낚싯대 Tool
	for _, tool in ipairs(tools) do
		if isRodTool(tool) then
			return tool
		end
	end

	-- 마지막 예비: Bag/Fishdex/Aquarium이 아닌 Tool
	for _, tool in ipairs(tools) do
		if tool:IsA("Tool") and not isBagTool(tool) and not isFishdexTool(tool) and not isAquariumTool(tool) then
			return tool
		end
	end

	return nil
end

local function findToolForSlot(index, tools)
	if index == 1 then
		return findRodTool(tools)
	end

	for _, tool in ipairs(tools) do
		if index == 2 and isBagTool(tool) then
			return tool
		end

		if index == 3 and isFishdexTool(tool) then
			return tool
		end
	end

	return nil
end

local function getToolIcon(tool, fallbackIcon)
	if tool then
		local textureId = cleanAssetId(tool.TextureId)
		if textureId ~= "" then
			return textureId
		end

		local icon =
			tool:GetAttribute("Icon")
			or tool:GetAttribute("ToolIcon")
			or tool:GetAttribute("Image")
			or tool:GetAttribute("ImageId")
			or tool:GetAttribute("TextureId")

		icon = cleanAssetId(icon)
		if icon ~= "" then
			return icon
		end
	end

	return cleanAssetId(fallbackIcon)
end

local function getRodName(tool)
	if not tool then
		return "Rod"
	end

	if tool.ToolTip and tool.ToolTip ~= "" then
		return tool.ToolTip
	end

	local displayName = tool:GetAttribute("DisplayName")
	if displayName then
		return tostring(displayName)
	end

	local rodId = tool:GetAttribute("RodId")
	if rodId then
		return tostring(rodId)
	end

	return tool.Name
end

local function getCurrentRodIcon(tool)
	-- FishingClient에서 저장한 현재 장착 낚싯대 이미지가 최우선
	local playerRodIcon =
		player:GetAttribute("EquippedRodIcon")
		or player:GetAttribute("CurrentRodIcon")
		or player:GetAttribute("SelectedRodIcon")

	playerRodIcon = cleanAssetId(playerRodIcon)
	if playerRodIcon ~= "" then
		return playerRodIcon
	end

	return getToolIcon(tool, ROD_FALLBACK_ICON)
end

local function getCurrentRodName(tool)
	-- FishingClient에서 저장한 현재 장착 낚싯대 이름이 최우선
	local playerRodName =
		player:GetAttribute("EquippedRodName")
		or player:GetAttribute("CurrentRodName")
		or player:GetAttribute("SelectedRodName")

	if playerRodName and tostring(playerRodName) ~= "" then
		return tostring(playerRodName)
	end

	return getRodName(tool)
end

local function openFishingPanel(tabName)
	local fishingGui = playerGui:FindFirstChild("FishingGui")
	if not fishingGui then
		warn("[CustomHotbar] FishingGui not found")
		return
	end

	local openPanelEvent = fishingGui:FindFirstChild("OpenFishingPanel", true)
	if openPanelEvent and openPanelEvent:IsA("BindableEvent") then
		openPanelEvent:Fire(tabName)
		print("[CustomHotbar] Opened panel:", tabName)
	else
		warn("[CustomHotbar] OpenFishingPanel BindableEvent not found")
	end
end

local function closeFishingPanels()
	local fishingGui = playerGui:FindFirstChild("FishingGui")
	if not fishingGui then
		return
	end
	local closeEvent = fishingGui:FindFirstChild("OpenFishingPanel", true)
	if closeEvent and closeEvent:IsA("BindableEvent") then
		closeEvent:Fire("__CloseFishingPanels")
	end


	local namesToClose = {
		MainPanel = true,
		BagPanel = true,
		FishdexPanel = true,
	}

	for _, descendant in ipairs(fishingGui:GetDescendants()) do
		if descendant:IsA("GuiObject") and namesToClose[descendant.Name] then
			descendant.Visible = false
		end
	end

	-- Panels 폴더 안의 직접 패널들도 같이 닫기
	local panelsFolder = fishingGui:FindFirstChild("Panels", true)
	if panelsFolder then
		for _, child in ipairs(panelsFolder:GetChildren()) do
			if child:IsA("GuiObject") then
				child.Visible = false
			end
		end
	end
end

local function unequipCurrentTool()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid:UnequipTools()
	end
end

-- 현재 캐릭터가 실제 낚싯대 Tool을 들고 있는지 확인합니다.
local function isRodCurrentlyEquipped()
	local character = player.Character
	if not character then
		return false
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and isRodTool(child) then
			return true
		end
	end

	return false
end

-- 클라이언트에서 즉시 맨손으로 바꾸고,
-- 서버에도 해제 요청을 보내 장착 상태가 다시 돌아오지 않게 합니다.
local function unequipAllTools()
	unequipCurrentTool()

	if hotbarEquipRequest and hotbarEquipRequest:IsA("RemoteEvent") then
		hotbarEquipRequest:FireServer("UnequipTools")
		print("[CustomHotbar] Requested server to unequip tools")
	end

	task.defer(updateHotbar)
	task.delay(0.12, updateHotbar)
	task.delay(0.35, updateHotbar)
end

-- Bag/Fishdex가 실제로 열려 있는지 확인합니다.
local function isFishingPanelVisible(tabName)
	local fishingGui = playerGui:FindFirstChild("FishingGui")
	if not fishingGui then
		return false
	end

	local targetName = tabName == "Bag" and "BagPanel" or "FishdexPanel"

	for _, descendant in ipairs(fishingGui:GetDescendants()) do
		if descendant:IsA("GuiObject")
			and descendant.Name == targetName
			and descendant.Visible then
			return true
		end
	end

	return false
end

local function getCharacter()
	local character = player.Character

	if character and character.Parent then
		return character
	end

	character = workspace:FindFirstChild(player.Name)
	if character then
		return character
	end

	return player.CharacterAdded:Wait()
end

local function findFishingRodTool()
	local character = player.Character

	-- 이미 손에 들고 있는 낚싯대가 있으면 그걸 우선 사용
	if character then
		local exactEquippedRod = character:FindFirstChild("Fishing Rod")
		if exactEquippedRod and exactEquippedRod:IsA("Tool") then
			return exactEquippedRod
		end

		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and isRodTool(child) then
				return child
			end
		end
	end

	-- Backpack 안의 실제 Fishing Rod Tool 찾기
	local exactBackpackRod = backpack:FindFirstChild("Fishing Rod")
	if exactBackpackRod and exactBackpackRod:IsA("Tool") then
		return exactBackpackRod
	end

	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") and isRodTool(child) then
			return child
		end
	end

	-- currentTools[1]에 잡힌 참조가 있으면 마지막 예비로 사용
	local currentRod = currentTools[1]
	if currentRod and currentRod:IsA("Tool") then
		return currentRod
	end

	return nil
end

local function equipRodTool()
	-- 서버에서 장착하게 해야 Explorer에서도 Backpack -> Workspace.Character 로 확실히 이동함.
	if hotbarEquipRequest and hotbarEquipRequest:IsA("RemoteEvent") then
		hotbarEquipRequest:FireServer("EquipRod")
		print("[CustomHotbar] Requested server to equip Fishing Rod")
		task.defer(updateHotbar)
		task.delay(0.15, updateHotbar)
		task.delay(0.4, updateHotbar)
		return
	end

	-- RemoteEvent가 없을 때만 클라이언트 예비 방식으로 시도
	local character = getCharacter()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		warn("[CustomHotbar] Humanoid not found in character")
		return
	end

	local tool = findFishingRodTool()

	if not tool then
		warn("[CustomHotbar] Fishing Rod tool not found in Backpack or Character")
		return
	end

	if tool.Parent == character then
		print("[CustomHotbar] Fishing Rod already equipped:", tool.Name)
		return
	end

	if tool.Parent ~= backpack then
		tool.Parent = backpack
		task.wait()
	end

	humanoid:EquipTool(tool)
	print("[CustomHotbar] Equipped Fishing Rod locally:", tool:GetFullName())

	task.defer(updateHotbar)
	task.delay(0.1, updateHotbar)
end

function activateSlot(index)
	if index == 2 then
		if UserInputService:GetFocusedTextBox() then
			return
		end

		local fishingGui = playerGui:FindFirstChild("FishingGui")
		local minigame = fishingGui and fishingGui:FindFirstChild("FishingMinigame", true)
		if minigame and minigame:IsA("GuiObject") and minigame.Visible then
			return
		end
	end

	if index == 1 then
		-- 1번: 장착 중이면 다시 눌렀을 때 맨손으로 돌아갑니다.
		closeFishingPanels()

		if isRodCurrentlyEquipped() then
			selectedSlot = nil
			unequipAllTools()
		else
			selectedSlot = 1
			equipRodTool()
		end

	elseif index == 2 then
		-- 2번: 현재 선택된 슬롯이 2번이면 Bag을 닫고 선택 해제합니다.
		-- 패널 이름/Visible 상태를 검사하지 않고 selectedSlot만 확인하므로 확실하게 토글됩니다.
		if selectedSlot == 2 then
			selectedSlot = nil
			closeFishingPanels()
			unequipAllTools()
			print("[CustomHotbar] Bag deselected")
		else
			selectedSlot = 2
			unequipAllTools()
			closeFishingPanels()

			task.defer(function()
				openFishingPanel("Bag")
			end)

			print("[CustomHotbar] Bag selected")
		end

	elseif index == 3 then
		-- 3번: 현재 선택된 슬롯이 3번이면 Fishdex를 닫고 선택 해제합니다.
		if selectedSlot == 3 then
			selectedSlot = nil
			closeFishingPanels()
			unequipAllTools()
			print("[CustomHotbar] Fishdex deselected")
		else
			selectedSlot = 3
			unequipAllTools()
			closeFishingPanels()

			task.defer(function()
				openFishingPanel("Fishdex")
			end)

			print("[CustomHotbar] Fishdex selected")
		end
	end

	updateHotbar()
end

function updateHotbar()
	local tools = getAllTools()
	local equippedTool = getEquippedTool()
	local rodTool = findToolForSlot(1, tools)
	local rodIsEquipped = rodTool ~= nil and equippedTool == rodTool

	for index = 1, 3 do
		local slot = slots[index]
		local tool = findToolForSlot(index, tools)

		currentTools[index] = tool

		if index == 1 then
			slot.Icon.Image = getCurrentRodIcon(tool)
			slot.Icon.Visible = slot.Icon.Image ~= ""
			slot.Label.Text = getCurrentRodName(tool)
			slot.Label.TextColor3 = Color3.fromRGB(160, 255, 80)
		elseif index == 2 then
			slot.Icon.Image = getToolIcon(tool, BAG_ICON)
			slot.Icon.Visible = slot.Icon.Image ~= ""
			slot.Label.Text = "Bag"
			slot.Label.TextColor3 = Color3.fromRGB(45, 210, 255)
		elseif index == 3 then
			slot.Icon.Image = getToolIcon(tool, FISHDEX_ICON)
			slot.Icon.Visible = slot.Icon.Image ~= ""
			slot.Label.Text = "Fishdex"
			slot.Label.TextColor3 = Color3.fromRGB(255, 220, 130)
		end

		-- 선택된 슬롯은 커짐.
		-- 1번은 실제 낚싯대 Tool을 손에 들고 있어도 커지게 함.
		-- A genuinely equipped rod takes selection priority over an open utility
		-- panel. This keeps the hotbar highlight mutually exclusive when a rod is
		-- equipped from inside the Bag while the Bag panel remains open.
		local isSelected = if index == 1
			then selectedSlot == 1 or rodIsEquipped
			else selectedSlot == index and not rodIsEquipped
		local targetScale = isSelected and SELECTED_SCALE or NORMAL_SCALE

		TweenService:Create(
			slot.Scale,
			TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = targetScale }
		):Play()

		if isSelected then
			slot.Button.BackgroundTransparency = 0.1
			slot.Stroke.Thickness = 4
			slot.Button.ZIndex = 30

			if index == 1 then
				slot.Stroke.Color = Color3.fromRGB(150, 255, 80)
			elseif index == 2 then
				slot.Stroke.Color = Color3.fromRGB(45, 210, 255)
			elseif index == 3 then
				slot.Stroke.Color = Color3.fromRGB(255, 205, 80)
			end
		else
			slot.Button.BackgroundTransparency = 0.22
			slot.Stroke.Thickness = 3
			slot.Stroke.Color = Color3.fromRGB(0, 0, 0)
			slot.Button.ZIndex = 1
		end
	end
end

local function bindTool(tool)
	if not tool:IsA("Tool") then
		return
	end

	tool:GetPropertyChangedSignal("TextureId"):Connect(updateHotbar)
	tool:GetPropertyChangedSignal("ToolTip"):Connect(updateHotbar)

	tool.AttributeChanged:Connect(function()
		updateHotbar()
	end)
end

local function bindContainer(container)
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		bindTool(child)
	end

	container.ChildAdded:Connect(function(child)
		bindTool(child)
		task.defer(updateHotbar)
	end)

	container.ChildRemoved:Connect(function()
		task.defer(updateHotbar)
	end)
end

bindContainer(backpack)

player.CharacterAdded:Connect(function(character)
	bindContainer(character)

	character.ChildAdded:Connect(function(child)
		bindTool(child)
		task.defer(updateHotbar)
	end)

	character.ChildRemoved:Connect(function()
		task.defer(updateHotbar)
	end)

	task.wait(0.3)
	updateHotbar()
end)

if player.Character then
	bindContainer(player.Character)
end

-- FishingClient가 현재 장착 낚싯대 정보를 업데이트하면 커스텀 핫바도 즉시 갱신
player:GetAttributeChangedSignal("EquippedRodIcon"):Connect(updateHotbar)
player:GetAttributeChangedSignal("EquippedRodName"):Connect(updateHotbar)
player:GetAttributeChangedSignal("EquippedRodId"):Connect(updateHotbar)
player:GetAttributeChangedSignal("CurrentRodIcon"):Connect(updateHotbar)
player:GetAttributeChangedSignal("CurrentRodName"):Connect(updateHotbar)
player:GetAttributeChangedSignal("CurrentRodId"):Connect(updateHotbar)
player:GetAttributeChangedSignal("SelectedRodIcon"):Connect(updateHotbar)
player:GetAttributeChangedSignal("SelectedRodName"):Connect(updateHotbar)
player:GetAttributeChangedSignal("SelectedRodId"):Connect(updateHotbar)

ContextActionService:BindActionAtPriority(
	"CustomHotbarSlot1",
	function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			activateSlot(1)
		end
		return Enum.ContextActionResult.Sink
	end,
	false,
	3000,
	Enum.KeyCode.One
)

ContextActionService:BindActionAtPriority(
	"CustomHotbarSlot2",
	function(_, inputState)
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if inputState == Enum.UserInputState.Begin then
			activateSlot(2)
		end
		return Enum.ContextActionResult.Sink
	end,
	false,
	3000,
	Enum.KeyCode.Two
)

ContextActionService:BindActionAtPriority(
	"CustomHotbarSlot3",
	function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			activateSlot(3)
		end
		return Enum.ContextActionResult.Sink
	end,
	false,
	3000,
	Enum.KeyCode.Three
)

task.defer(updateHotbar)

task.spawn(function()
	while true do
		updateHotbar()
		task.wait(0.25)
	end
end)

print("[CustomHotbar] Created successfully")
