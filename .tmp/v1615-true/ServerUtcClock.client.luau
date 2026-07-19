local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("ServerUtcClockGui")
local frame = gui:WaitForChild("ClockFrame")
local clockText = frame:WaitForChild("ServerUtcText")
local separator = utf8.char(0x2022)
local lastDisplayedSecond = -1

local function updateClock()
	local serverSecond = math.floor(workspace:GetServerTimeNow())
	if serverSecond == lastDisplayedSecond then
		return
	end

	lastDisplayedSecond = serverSecond
	clockText.Text = "SERVER UTC  " .. separator .. "  " .. os.date("!%H:%M:%S", serverSecond)
end

updateClock()
RunService.Heartbeat:Connect(updateClock)
