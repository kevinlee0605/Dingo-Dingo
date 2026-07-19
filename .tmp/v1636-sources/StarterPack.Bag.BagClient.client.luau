local Players = game:GetService("Players")

local player = Players.LocalPlayer
local tool = script.Parent
local lastOpenAt = 0

tool.RequiresHandle = false
tool.CanBeDropped = false

local function unequipTool()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
end

local function getOpenPanelEvent()
	local playerGui = player:WaitForChild("PlayerGui", 10)
	local fishingGui = playerGui and playerGui:WaitForChild("FishingGui", 10)
	if not fishingGui then
		return nil
	end

	return fishingGui:WaitForChild("OpenFishingPanel", 10)
end

local function openBag()
	local now = os.clock()
	if now - lastOpenAt < 0.2 then
		return
	end
	lastOpenAt = now

	print("Bag tool equipped")

	local openPanelEvent = getOpenPanelEvent()
	if openPanelEvent and openPanelEvent:IsA("BindableEvent") then
		print("Opening Bag UI")
		openPanelEvent:Fire("Bag")
	else
		warn("BagPanel not found")
	end

	task.defer(unequipTool)
end

tool.Equipped:Connect(openBag)
tool.Activated:Connect(openBag)