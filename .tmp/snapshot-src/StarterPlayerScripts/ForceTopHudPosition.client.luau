local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TOP_Y_OFFSET = 12 -- 거의 맨 위. 더 내리고 싶으면 10, 18 이런 식으로 올리기
local BUTTON_SIZE = 80
local BUTTON_PADDING = 20

local buttonNames = {
	SettingsButton = true,
	QuestsButton = true,
	ShopButton = true,
}

local layoutOrder = {
	SettingsButton = 1,
	QuestsButton = 2,
	ShopButton = 3,
}

local forcedGui = playerGui:FindFirstChild("ForcedTopHudGui")
if not forcedGui then
	forcedGui = Instance.new("ScreenGui")
	forcedGui.Name = "ForcedTopHudGui"
	forcedGui.ResetOnSpawn = false
	forcedGui.IgnoreGuiInset = true
	forcedGui.DisplayOrder = 10000
	forcedGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	forcedGui.Parent = playerGui
end

local forcedFrame = forcedGui:FindFirstChild("ForcedTopButtonsFrame")
if not forcedFrame then
	forcedFrame = Instance.new("Frame")
	forcedFrame.Name = "ForcedTopButtonsFrame"
	forcedFrame.AnchorPoint = Vector2.new(0.5, 0)
	forcedFrame.Position = UDim2.new(0.5, 0, 0, TOP_Y_OFFSET)
	forcedFrame.Size = UDim2.new(0, 280, 0, 104)
	forcedFrame.BackgroundTransparency = 1
	forcedFrame.ClipsDescendants = false
	forcedFrame.ZIndex = 10000
	forcedFrame.Parent = forcedGui

	local layout = Instance.new("UIListLayout")
	layout.Name = "ForcedLayout"
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, BUTTON_PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = forcedFrame
end

local function findButtons()
	local found = {}

	for _, obj in ipairs(playerGui:GetDescendants()) do
		if buttonNames[obj.Name] and obj:IsA("GuiButton") then
			found[obj.Name] = obj
		end
	end

	return found
end

local function forceButtonsToTop()
	forcedGui.Parent = playerGui
	forcedGui.Enabled = true
	forcedGui.DisplayOrder = 10000

	forcedFrame.AnchorPoint = Vector2.new(0.5, 0)
	forcedFrame.Position = UDim2.new(0.5, 0, 0, TOP_Y_OFFSET)
	forcedFrame.Size = UDim2.new(0, 220, 0, 64)
	forcedFrame.Visible = true
	forcedFrame.ZIndex = 10000

	local buttons = findButtons()
	local movedCount = 0

	for name, button in pairs(buttons) do
		if button.Parent ~= forcedFrame then
			button.Parent = forcedFrame
			movedCount += 1
		end

		button.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
		button.LayoutOrder = layoutOrder[name] or 1
		button.Visible = true
		button.ZIndex = 10001
		button.BackgroundTransparency = 1

		for _, child in ipairs(button:GetDescendants()) do
			if child:IsA("GuiObject") then
				child.ZIndex = math.max(child.ZIndex, 10002)
			end
		end
	end

	return movedCount, buttons
end

task.spawn(function()
	while true do
		local movedCount, buttons = forceButtonsToTop()

		local count = 0
		for _ in pairs(buttons) do
			count += 1
		end

		if count > 0 then
			print("[ForceTopHudPosition] Found buttons:", count, "Moved:", movedCount)
		else
			warn("[ForceTopHudPosition] SettingsButton / QuestsButton / ShopButton not found yet")
		end

		task.wait(0.5)
	end
end)

RunService.RenderStepped:Connect(function()
	forceButtonsToTop()
end)

print("[ForceTopHudPosition] Running")