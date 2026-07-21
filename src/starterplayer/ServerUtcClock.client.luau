local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("ServerUtcClockGui")
local frame = gui:WaitForChild("ClockFrame")
local clockText = frame:WaitForChild("ServerUtcText")
local deviceScale = frame:WaitForChild("FishyFishDeviceScale")
local separator = utf8.char(0x2022)
local lastDisplayedSecond = -1

local DESKTOP_SCALE = 1.05
local TOUCH_SCALE = 0.86

local function updateDeviceScale()
	local isDesktopPc = UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
	deviceScale.Scale = isDesktopPc and DESKTOP_SCALE or TOUCH_SCALE
end

local function updateClock()
	local serverSecond = math.floor(workspace:GetServerTimeNow())
	if serverSecond == lastDisplayedSecond then
		return
	end

	lastDisplayedSecond = serverSecond
	clockText.Text = "SERVER UTC  " .. separator .. "  " .. os.date("!%H:%M:%S", serverSecond)
end

updateClock()
updateDeviceScale()
RunService.Heartbeat:Connect(updateClock)
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updateDeviceScale)
