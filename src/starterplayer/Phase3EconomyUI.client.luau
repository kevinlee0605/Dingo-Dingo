-- Phase3EconomyUI is the behavior/data controller for the authored daily
-- reward surface.  The visual hierarchy lives in StarterGui >
-- Phase3EconomyGui; this script does not construct a ScreenGui or static UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("FishingRemotes")
local GetState = remotes:WaitForChild("GetState")
local StateUpdated = remotes:WaitForChild("StateUpdated")
local LoginRewardAction = remotes:WaitForChild("LoginRewardAction")

local DAILY_REWARD_ASSETS = {
	UnlockedDayTab = "rbxassetid://135195025090058",
	TodayTab = "rbxassetid://119253493497690",
	PurpleTab = "rbxassetid://105275297050616",
	RedTab = "rbxassetid://109003915454192",
	DoneIcon = "rbxassetid://94167472129143",
	SpecialDayIcon = "rbxassetid://70463548759658",
	LuckyBaitIcon = "rbxassetid://115001329325653",
	FreshBaitIcon = "rbxassetid://77845345155967",
	CoinIcon = "rbxassetid://127404869799608",
}

local DAILY_TAB_CROPS = {
	Unlocked = { Offset = Vector2.new(128, 140), Size = Vector2.new(1194, 806) },
	Today = { Offset = Vector2.new(93, 166), Size = Vector2.new(1260, 751) },
	Purple = { Offset = Vector2.new(98, 190), Size = Vector2.new(1252, 707) },
	Red = { Offset = Vector2.new(86, 158), Size = Vector2.new(1265, 756) },
}

local CLAIM_BUTTON_CROP = {
	Offset = Vector2.new(68, 272),
	Size = Vector2.new(1543, 431),
}

local TRIMMED_IMAGE_SIZES = {
	DayTab = Vector2.new(1448, 1086),
	ClaimButton = Vector2.new(1672, 941),
	ScrollBar = Vector2.new(1448, 1086),
}

local DAILY_REWARD_CANVAS_SIZE = Vector2.new(1400, 1050)
local DAILY_GRID_COLUMNS = 4
local DAILY_GRID_CELL_HEIGHT = 168
local DAILY_GRID_ROW_GAP = 12
local DAILY_SCROLLBAR_THUMB_WIDTH = 22
local DAILY_SCROLLBAR_MIN_THUMB_HEIGHT = 76

local function findAuthoredGui()
	local ancestor = script:FindFirstAncestor("Phase3EconomyGui")
	if ancestor and ancestor:IsA("ScreenGui") then
		return ancestor
	end
	return playerGui:WaitForChild("Phase3EconomyGui", 30)
end

local gui = findAuthoredGui()
if not gui or not gui:IsA("ScreenGui") then
	warn("[Phase3EconomyUI] Phase3EconomyGui is missing; daily rewards were not mounted.")
	return
end
if gui:GetAttribute("AuthoredDailyRewards") ~= true then
	warn("[Phase3EconomyUI] Phase3EconomyGui is not marked AuthoredDailyRewards; refusing to mutate an unknown UI.")
	return
end
if gui:GetAttribute("DailyRewardControllerBound") == true then
	warn("[Phase3EconomyUI] A daily-reward controller is already bound; skipping the duplicate copy.")
	return
end
gui:SetAttribute("DailyRewardControllerBound", true)

-- A pre-migration copy can survive in PlayerGui during a live Studio sync.
-- Remove only that specifically named obsolete root.
for _, legacyName in ipairs({ "FishyFishPhase3Gui", "FishyFishPhase3Gui_SeaStarHudFixed" }) do
	local legacyGui = playerGui:FindFirstChild(legacyName)
	if legacyGui and legacyGui ~= gui then
		legacyGui:Destroy()
	end
end

local surface = gui:WaitForChild("DailyRewardSurface")
local topHudGui = playerGui:WaitForChild("TopHudGui")
local topButtonsFrame = topHudGui:WaitForChild("TopButtonsFrame")
local loginButton = topButtonsFrame:WaitForChild("TopLoginRewardButton")
local loginOverlay = surface:WaitForChild("LoginRewardOverlay")
local loginPanel = loginOverlay:WaitForChild("LoginPanel")
local loginScale = loginPanel:WaitForChild("LoginScale")
local loginTitle = loginPanel:WaitForChild("LoginTitle")
local loginClose = loginPanel:WaitForChild("LoginClose")
local loginClosePressScale = loginClose:WaitForChild("PressScale")
local loginTimer = loginPanel:WaitForChild("LoginTimer")
local loginGrid = loginPanel:WaitForChild("LoginGrid")
loginGrid.ClipsDescendants = true
loginGrid.Active = true
loginGrid.ScrollingEnabled = true
local gridLayout = loginGrid:WaitForChild("DailyRewardGridLayout")
local scrollbarFrame = loginPanel:WaitForChild("DailyRewardCustomScrollbar")
local loginScrollbarArt = scrollbarFrame:WaitForChild("DailyRewardScrollbarArt")
local scrollSlot = scrollbarFrame:WaitForChild("DailyRewardScrollLane")
local loginScrollThumb = scrollSlot:WaitForChild("DailyRewardMovingThumb")
local loginStatus = loginPanel:WaitForChild("LoginStatus")
local claimButton = loginPanel:WaitForChild("ClaimButton")
local claimButtonArt = claimButton:WaitForChild("ClaimButtonArt")
local claimButtonLabel = claimButton:WaitForChild("ClaimButtonLabel")
local templates = gui:WaitForChild("DailyRewardTemplates")
local dayCardTemplate = templates:WaitForChild("DayCardTemplate")
local rewardLineTemplate = templates:WaitForChild("RewardLineTemplate")
local milestoneRewardLineTemplate = templates:WaitForChild("MilestoneRewardLineTemplate")
local claimedIconTemplate = templates:WaitForChild("ClaimedIconTemplate")

local closePressTweenInfo = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local closeReleaseTweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local loginClosePressed = false

local function setLoginClosePressed(pressed)
	if loginClosePressed == pressed then
		return
	end
	loginClosePressed = pressed
	TweenService:Create(
		loginClosePressScale,
		pressed and closePressTweenInfo or closeReleaseTweenInfo,
		{ Scale = pressed and 0.86 or 1 }
	):Play()
end

loginClose.MouseButton1Down:Connect(function()
	setLoginClosePressed(true)
end)
loginClose.MouseButton1Up:Connect(function()
	setLoginClosePressed(false)
end)
loginClose.MouseLeave:Connect(function()
	setLoginClosePressed(false)
end)
loginClose.Activated:Connect(function()
	setLoginClosePressed(false)
end)

local state = nil
local stateReceivedAt = os.clock()
local autoOpenEvaluated = false
local loginOpenedAutomatically = false
local requestedMidnightRefresh = false
local draggingLoginThumb = false
local dragOffsetInsideThumb = 0
local cameraConnection = nil

local function applyVirtualCrop(image, fullSize, crop)
	image.Position = UDim2.new(-(crop.Offset.X / crop.Size.X), 0, -(crop.Offset.Y / crop.Size.Y), 0)
	image.Size = UDim2.new(fullSize.X / crop.Size.X, 0, fullSize.Y / crop.Size.Y, 0)
	image.ScaleType = Enum.ScaleType.Stretch
end

-- These are layout adjustments for authored image surfaces, not UI creation.
applyVirtualCrop(claimButtonArt, TRIMMED_IMAGE_SIZES.ClaimButton, CLAIM_BUTTON_CROP)
applyVirtualCrop(loginScrollbarArt, TRIMMED_IMAGE_SIZES.ScrollBar, {
	Offset = Vector2.new(683, 29),
	Size = Vector2.new(65, 1021),
})

loginTitle.Font = Enum.Font.FredokaOne
claimButtonLabel.Font = Enum.Font.FredokaOne

local function updateLoginResponsiveScale()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or DAILY_REWARD_CANVAS_SIZE
	local scale = math.min(
		(viewport.X * 0.94) / DAILY_REWARD_CANVAS_SIZE.X,
		(viewport.Y * 0.94) / DAILY_REWARD_CANVAS_SIZE.Y,
		1
	)
	loginScale.Scale = math.clamp(scale, 0.18, 1)
end

local function bindCamera(camera)
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLoginResponsiveScale)
	end
	updateLoginResponsiveScale()
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindCamera(Workspace.CurrentCamera)
end)
bindCamera(Workspace.CurrentCamera)

local function getLoginLogicalViewportHeight()
	local scale = math.max(loginScale.Scale, 0.001)
	local absoluteHeight = loginGrid.AbsoluteWindowSize.Y
	if absoluteHeight <= 0 then
		absoluteHeight = loginGrid.AbsoluteSize.Y
	end
	return absoluteHeight / scale
end

local function getLoginScrollMetrics()
	local contentHeight = math.max(0, loginGrid.CanvasSize.Y.Offset)
	local viewHeight = getLoginLogicalViewportHeight()
	local scrollRange = math.max(0, contentHeight - viewHeight)
	local scale = math.max(loginScale.Scale, 0.001)
	local slotHeight = scrollSlot.AbsoluteSize.Y / scale
	local visibleRatio = contentHeight > 0 and math.clamp(viewHeight / contentHeight, 0, 1) or 1
	local thumbHeight = math.clamp(
		slotHeight * visibleRatio,
		math.min(DAILY_SCROLLBAR_MIN_THUMB_HEIGHT, slotHeight),
		slotHeight
	)
	return scrollRange, thumbHeight, math.max(0, slotHeight - thumbHeight)
end

local function updateLoginScrollbarThumb()
	local scrollRange, thumbHeight, thumbTravel = getLoginScrollMetrics()
	loginScrollThumb.Visible = scrollRange > 0
	loginScrollThumb.Size = UDim2.fromOffset(DAILY_SCROLLBAR_THUMB_WIDTH, thumbHeight)
	if scrollRange <= 0 then
		loginScrollThumb.Position = UDim2.new(0.5, 0, 0, 0)
		return
	end
	local progress = math.clamp(loginGrid.CanvasPosition.Y / scrollRange, 0, 1)
	loginScrollThumb.Position = UDim2.new(0.5, 0, 0, thumbTravel * progress)
end

local function setLoginScrollProgress(progress)
	local scrollRange = getLoginScrollMetrics()
	loginGrid.CanvasPosition = Vector2.new(0, math.clamp(progress, 0, 1) * scrollRange)
end

loginScrollThumb.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		draggingLoginThumb = true
		dragOffsetInsideThumb = input.Position.Y - loginScrollThumb.AbsolutePosition.Y
	end
end)

loginScrollThumb.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		draggingLoginThumb = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not draggingLoginThumb then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local _, _, logicalThumbTravel = getLoginScrollMetrics()
	local absoluteThumbTravel = math.max(0, scrollSlot.AbsoluteSize.Y - loginScrollThumb.AbsoluteSize.Y)
	if logicalThumbTravel <= 0 or absoluteThumbTravel <= 0 then
		return
	end
	local thumbTop = input.Position.Y - scrollSlot.AbsolutePosition.Y - dragOffsetInsideThumb
	setLoginScrollProgress(thumbTop / absoluteThumbTravel)
end)

scrollSlot.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if draggingLoginThumb then
		return
	end
	local _, _, logicalThumbTravel = getLoginScrollMetrics()
	local absoluteThumbHeight = loginScrollThumb.AbsoluteSize.Y
	local absoluteThumbTravel = math.max(0, scrollSlot.AbsoluteSize.Y - absoluteThumbHeight)
	if logicalThumbTravel <= 0 or absoluteThumbTravel <= 0 then
		return
	end
	local localY = input.Position.Y - scrollSlot.AbsolutePosition.Y
	setLoginScrollProgress((localY - absoluteThumbHeight * 0.5) / absoluteThumbTravel)
end)

local function clearRenderedDayCards()
	for _, child in ipairs(loginGrid:GetChildren()) do
		if child:IsA("Frame") and string.match(child.Name, "^DayCard%d+$") then
			child:Destroy()
		end
	end
end

local function countLoginDayCards()
	local count = 0
	for _, child in ipairs(loginGrid:GetChildren()) do
		if child:IsA("Frame") and string.match(child.Name, "^DayCard%d+$") then
			count += 1
		end
	end
	return count
end

local function refreshLoginCanvasAndScrollbar()
	local cardCount = countLoginDayCards()
	local rowCount = cardCount > 0 and math.ceil(cardCount / DAILY_GRID_COLUMNS) or 0
	local contentHeight = 0
	if rowCount > 0 then
		contentHeight = rowCount * DAILY_GRID_CELL_HEIGHT
			+ math.max(0, rowCount - 1) * DAILY_GRID_ROW_GAP
			+ 16
	end
	loginGrid.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
	local scrollRange = math.max(0, contentHeight - getLoginLogicalViewportHeight())
	loginGrid:SetAttribute("DailyRewardCardCount", cardCount)
	loginGrid:SetAttribute("DailyRewardRowCount", rowCount)
	loginGrid:SetAttribute("DailyRewardScrollRange", scrollRange)
	loginGrid.CanvasPosition = Vector2.new(0, math.clamp(loginGrid.CanvasPosition.Y, 0, scrollRange))
	task.defer(updateLoginScrollbarThumb)
end

gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshLoginCanvasAndScrollbar)
loginGrid:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateLoginScrollbarThumb)
loginGrid:GetPropertyChangedSignal("CanvasPosition"):Connect(updateLoginScrollbarThumb)
loginGrid:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLoginScrollbarThumb)
loginPanel:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLoginScrollbarThumb)

local function rewardLinesFromSummary(summary)
	summary = tostring(summary or "")
	local lines = {}
	local function add(icon, textValue)
		if textValue and textValue ~= "" then
			table.insert(lines, { Icon = icon, Text = textValue })
		end
	end
	local coins = string.match(summary, "(%d+)%s+Coins")
	if coins then add(DAILY_REWARD_ASSETS.CoinIcon, coins .. " Coins") end
	local fresh = string.match(summary, "(%d+)%s+Fresh Bait")
	if fresh then add(DAILY_REWARD_ASSETS.FreshBaitIcon, fresh .. " Fresh Bait") end
	local lucky = string.match(summary, "(%d+)%s+Lucky Bait")
	if lucky then add(DAILY_REWARD_ASSETS.LuckyBaitIcon, lucky .. " Lucky Bait") end
	local mystic = string.match(summary, "(%d+)%s+Mystic Bait")
	if mystic then add(DAILY_REWARD_ASSETS.SpecialDayIcon, mystic .. " Mystic Bait") end
	local seaStars = string.match(summary, "(%d+)%s+Sea Stars")
	if seaStars then add(DAILY_REWARD_ASSETS.SpecialDayIcon, seaStars .. " Sea Stars") end
	local cycleSeaStars = string.match(summary, "(%d+)%s+Cycle Sea Stars")
	if cycleSeaStars then add(DAILY_REWARD_ASSETS.SpecialDayIcon, cycleSeaStars .. " Cycle Sea Stars") end
	local resources = string.match(summary, "(%d+)%s+weighted resources")
	if resources then add(DAILY_REWARD_ASSETS.SpecialDayIcon, resources .. " weighted resources") end
	if string.find(summary, "aquarium decoration", 1, true) then
		add(DAILY_REWARD_ASSETS.SpecialDayIcon, "1 aquarium decoration")
	end
	if #lines == 0 and summary ~= "" then
		add(DAILY_REWARD_ASSETS.SpecialDayIcon, summary)
	end
	return lines
end

local function addStandardRewardLine(card, line, index)
	local rewardLine = rewardLineTemplate:Clone()
	rewardLine.Name = "RewardLine" .. tostring(index)
	rewardLine.Position = UDim2.fromOffset(24, 60 + (index - 1) * 32)
	rewardLine.Visible = true
	local icon = rewardLine:WaitForChild("RewardIcon")
	icon.Image = line.Icon
	local textLabel = rewardLine:WaitForChild("RewardText")
	textLabel.Text = line.Text
	rewardLine.Parent = card
end

local function addMilestoneRewardLine(card, line, index, verticalOffset)
	local rewardLine = milestoneRewardLineTemplate:Clone()
	rewardLine.Name = "MilestoneRewardLine" .. tostring(index)
	rewardLine.Position = UDim2.fromOffset(108, 54 + (index - 1) * 21 + (verticalOffset or 0))
	rewardLine.Visible = true
	rewardLine:WaitForChild("RewardText").Text = line.Text
	rewardLine.Parent = card
end

local function renderLogin()
	clearRenderedDayCards()
	local login = state and state.LoginRewards
	if not login then
		claimButton.Active = false
		claimButton.AutoButtonColor = false
		claimButtonArt.ImageColor3 = Color3.fromRGB(140, 140, 140)
		claimButtonLabel.Text = "Loading..."
		refreshLoginCanvasAndScrollbar()
		return
	end

	loginTitle.Text = "Daily Login Rewards"
	claimButtonLabel.Text = login.ClaimAvailable and ("Claim Day " .. tostring(login.CurrentDay)) or "Claimed"
	claimButton.Active = login.ClaimAvailable == true
	claimButton.AutoButtonColor = login.ClaimAvailable == true
	claimButtonArt.ImageColor3 = login.ClaimAvailable and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 150)

	for _, slot in ipairs(login.RewardTrack or {}) do
		local day = slot.Day
		local claimed = day < (login.CurrentDay or 1)
		local isCurrentDay = day == (login.CurrentDay or 1)
		local isFinalDay = day == daysInCycle or slot.IsFinal
		local isMilestone = slot.IsMilestone == true or day == 7 or day == 14 or day == 21

		local imageId = DAILY_REWARD_ASSETS.UnlockedDayTab
		local crop = DAILY_TAB_CROPS.Unlocked
		if isFinalDay then
			imageId = DAILY_REWARD_ASSETS.RedTab
			crop = DAILY_TAB_CROPS.Red
		elseif isMilestone then
			imageId = DAILY_REWARD_ASSETS.PurpleTab
			crop = DAILY_TAB_CROPS.Purple
		elseif isCurrentDay and login.ClaimAvailable then
			imageId = DAILY_REWARD_ASSETS.TodayTab
			crop = DAILY_TAB_CROPS.Today
		end

		local card = dayCardTemplate:Clone()
		card.Name = "DayCard" .. tostring(day)
		card.LayoutOrder = day
		card.Visible = true
		local cardImage = card:WaitForChild("CardArt")
		cardImage.Image = imageId
		applyVirtualCrop(cardImage, TRIMMED_IMAGE_SIZES.DayTab, crop)
		local dayLabel = card:WaitForChild("DayLabel")
		dayLabel.Text = "Day " .. tostring(day)
		dayLabel.Font = Enum.Font.FredokaOne
		card:WaitForChild("MilestoneIcon").Visible = isMilestone or isFinalDay

		local summaryLines = rewardLinesFromSummary(slot.Summary)
		if isMilestone or isFinalDay then
			local rewardTextOffset = isFinalDay and -8 or 0
			for index, line in ipairs(summaryLines) do
				if index > 5 then break end
				addMilestoneRewardLine(card, line, index, rewardTextOffset)
			end
		else
			for index, line in ipairs(summaryLines) do
				if index > 3 then break end
				addStandardRewardLine(card, line, index)
			end
		end

		if claimed then
			local claimedIcon = claimedIconTemplate:Clone()
			claimedIcon.Name = "ClaimedIcon"
			claimedIcon.Image = DAILY_REWARD_ASSETS.DoneIcon
			claimedIcon.Visible = true
			claimedIcon.Parent = card
		end
		card.Parent = loginGrid
	end

	task.defer(function()
		refreshLoginCanvasAndScrollbar()
		RunService.Heartbeat:Wait()
		refreshLoginCanvasAndScrollbar()
	end)
end

local function updateTimer()
	local login = state and state.LoginRewards
	if not login then
		loginTimer.Text = "Daily rewards reset at 24:00 (Server's UTC Time)"
		return
	end
	if login.ClaimAvailable then
		loginTimer.Text = "Daily rewards reset at 24:00 (Server's UTC Time)"
		return
	end
	local remaining = math.max(0, math.floor((login.SecondsUntilNextUtcClaim or 0) - (os.clock() - stateReceivedAt)))
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	local seconds = remaining % 60
	loginTimer.Text = "Daily rewards reset at 24:00 (Server's UTC Time)"
	if remaining <= 0 and not requestedMidnightRefresh then
		requestedMidnightRefresh = true
		task.spawn(function()
			local ok, result = pcall(function()
				return GetState:InvokeServer()
			end)
			if ok and type(result) == "table" then
				state = result
				stateReceivedAt = os.clock()
				requestedMidnightRefresh = false
				renderLogin()
				updateTimer()
			end
		end)
	end
end

local function showLogin()
	loginOverlay.Visible = true
	renderLogin()
	updateTimer()
end

local function receiveState(newState)
	if type(newState) ~= "table" then
		return
	end
	state = newState
	stateReceivedAt = os.clock()
	requestedMidnightRefresh = false
	local login = state.LoginRewards
	if loginOverlay.Visible then
		renderLogin()
		updateTimer()
	end
	if not autoOpenEvaluated then
		autoOpenEvaluated = true
		if login and login.ClaimAvailable and not loginOpenedAutomatically then
			loginOpenedAutomatically = true
			showLogin()
		end
	end
end

loginButton.MouseButton1Click:Connect(showLogin)
loginClose.MouseButton1Click:Connect(function()
	loginOverlay.Visible = false
end)
claimButton.MouseButton1Click:Connect(function()
	if state and state.LoginRewards and state.LoginRewards.ClaimAvailable then
		claimButton.Active = false
		claimButton.AutoButtonColor = false
		claimButtonArt.ImageColor3 = Color3.fromRGB(150, 150, 150)
		claimButtonLabel.Text = "Claiming..."
		LoginRewardAction:FireServer("Claim")
	end
end)

StateUpdated.OnClientEvent:Connect(receiveState)
LoginRewardAction.OnClientEvent:Connect(function(result)
	if type(result) == "table" then
		loginStatus.Text = result.Message or (result.Success and "Reward claimed." or "Reward unavailable.")
		if result.Success ~= true then
			-- Lock/contention failures do not necessarily emit StateUpdated. Restore
			-- the authored claim button from the last valid state so it cannot remain
			-- stuck on "Claiming..." for the rest of the session.
			renderLogin()
			updateTimer()
		end
	end
end)

task.defer(function()
	local ok, initialState = pcall(function()
		return GetState:InvokeServer()
	end)
	if ok then
		receiveState(initialState)
	end
end)

local timerAccumulator = 0
RunService.RenderStepped:Connect(function(deltaTime)
	timerAccumulator += deltaTime
	if timerAccumulator >= 1 then
		timerAccumulator = 0
		if loginOverlay.Visible then
			updateTimer()
		end
	end
end)

print("[Phase3EconomyUI_v34] Bound authored final-day layout, Fresh Bait icon, and exact ShopButton press tween.")
