local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local existing = playerGui:FindFirstChild("ServerUtcClockGui")
if existing then
	existing:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ServerUtcClockGui"
gui.DisplayOrder = 2100
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "ClockFrame"
frame.AnchorPoint = Vector2.new(0, 1)
frame.Position = UDim2.new(0, 8, 1, -8)
frame.Size = UDim2.fromOffset(380, 34)
frame.BackgroundTransparency = 1
frame.BorderSizePixel = 0
frame.Parent = gui

local clockText = Instance.new("TextLabel")
clockText.Name = "ServerUtcText"
clockText.Position = UDim2.fromOffset(8, 2)
clockText.Size = UDim2.new(1, -16, 1, -4)
clockText.BackgroundTransparency = 1
clockText.Font = Enum.Font.GothamBlack
clockText.Text = "SERVER UTC  •  --:--:--"
clockText.TextColor3 = Color3.fromRGB(255, 255, 255)
clockText.TextSize = 14
clockText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
clockText.TextStrokeTransparency = 0
clockText.TextXAlignment = Enum.TextXAlignment.Left
clockText.TextYAlignment = Enum.TextYAlignment.Center
clockText.Parent = frame

local textStroke = Instance.new("UIStroke")
textStroke.Name = "ServerUtcTextOutline"
textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
textStroke.Color = Color3.fromRGB(0, 0, 0)
textStroke.Thickness = 3
textStroke.Transparency = 0
textStroke.Parent = clockText

local lastDisplayedSecond = -1

local function updateClock()
	local serverSecond = math.floor(workspace:GetServerTimeNow())
	if serverSecond == lastDisplayedSecond then
		return
	end

	lastDisplayedSecond = serverSecond
	clockText.Text = "SERVER UTC  •  " .. os.date("!%H:%M:%S", serverSecond)
end

updateClock()
RunService.Heartbeat:Connect(updateClock)
