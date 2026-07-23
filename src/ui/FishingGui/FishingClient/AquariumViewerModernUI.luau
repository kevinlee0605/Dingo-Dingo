local AquariumViewerModernUI = {}

local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local rarityColors = {
	Common = Color3.fromRGB(25, 238, 255),
	Uncommon = Color3.fromRGB(41, 255, 71),
	Rare = Color3.fromRGB(255, 104, 208),
	Epic = Color3.fromRGB(174, 87, 255),
	Legendary = Color3.fromRGB(255, 196, 42),
}

local function descendant(root, name, className)
	local node = root:FindFirstChild(name, true)
	assert(node, ("AquariumViewerGui is missing %s"):format(name))
	if className then
		assert(node:IsA(className), ("AquariumViewerGui.%s must be a %s"):format(name, className))
	end
	return node
end

local function setPressedFeedback(button)
	if not button:IsA("GuiButton") then
		return
	end

	local original = button.Size
	button.MouseButton1Down:Connect(function()
		button.Size = UDim2.new(original.X.Scale, original.X.Offset - 4, original.Y.Scale, original.Y.Offset - 4)
	end)
	button.MouseButton1Up:Connect(function()
		button.Size = original
	end)
	button.MouseLeave:Connect(function()
		button.Size = original
	end)
end

local function clearRows(scroller)
	for _, child in ipairs(scroller:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function fishImage(gameConfig, fish)
	if type(fish) ~= "table" or not gameConfig.getFishImage then
		return ""
	end
	return gameConfig.getFishImage(fish.imageKey or fish.id) or ""
end

local function formatNumber(value)
	local number = math.max(0, math.floor(tonumber(value) or 0))
	local text = tostring(number)
	while true do
		local formatted, replacements = text:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
		text = formatted
		if replacements == 0 then
			break
		end
	end
	return text
end

local function aquariumTotalValue(fish)
	local total = 0
	for _, entry in ipairs(fish or {}) do
		total += tonumber(entry.value) or 0
	end
	return total
end

local function bestFish(currentState, fish)
	if type(currentState.BestCatch) == "table" then
		return currentState.BestCatch
	end

	local best = nil
	for _, entry in ipairs(fish or {}) do
		if not best or (tonumber(entry.value) or 0) > (tonumber(best.value) or 0) then
			best = entry
		end
	end
	return best
end

function AquariumViewerModernUI.create(context)
	local playerGui = assert(context.playerGui, "Aquarium viewer requires playerGui")
	local screenGui = playerGui:WaitForChild("AquariumViewerGui")
	-- Rojo names the top-level instance after an .rbxmx filename during a live
	-- sync. Older saved copies therefore expose this frame as `Interface`, while
	-- clean builds preserve its authored `Root` name. Support both hierarchies so
	-- the aquarium viewer cannot break the rest of FishingClient during startup.
	local root = screenGui:FindFirstChild("Root") or screenGui:FindFirstChild("Interface")
	assert(root and root:IsA("Frame"), "AquariumViewerGui is missing its Root frame")
	local uiScale = descendant(root, "DeviceScale", "UIScale")
	local myTankPage = descendant(root, "MyTankPage", "Frame")
	local explorePage = descendant(root, "ExplorePage", "Frame")
	local myTankSelected = descendant(root, "MyTankSelected", "ImageLabel")
	local exploreSelected = descendant(root, "ExploreSelected", "ImageLabel")
	local myTankTabBase = descendant(root, "MyTankTabBase", "Frame")
	local exploreTabBase = descendant(root, "ExploreTabBase", "Frame")
	local myTankList = descendant(root, "MyTankFishList", "ScrollingFrame")
	local visitorList = descendant(root, "ExploreVisitorList", "ScrollingFrame")
	local fishTemplate = descendant(root, "MyTankFishRowTemplate", "Frame")
	local visitorTemplate = descendant(root, "ExploreVisitorRowTemplate", "Frame")
	local myTankEmpty = descendant(root, "EmptyMessage", "TextLabel")
	local exploreEmpty = descendant(root, "ExploreEmptyMessage", "TextLabel")
	local searchBox = descendant(root, "SearchBox", "TextBox")
	local myTankScrollTrack = descendant(root, "CustomScrollBar", "ImageLabel")
	local myTankScrollThumb = descendant(myTankScrollTrack, "MyTankScrollThumb", "ImageLabel")
	local scrollTrack = descendant(root, "ExploreScrollTrack", "ImageLabel")
	local scrollThumb = descendant(scrollTrack, "ExploreScrollThumb", "ImageLabel")
	local filterSelected = {
		Featured = descendant(explorePage, "FeaturedSelected", "ImageLabel"),
		MostLiked = descendant(explorePage, "MostLikedSelected", "ImageLabel"),
		Friends = descendant(explorePage, "FriendsSelected", "ImageLabel"),
		Random = descendant(explorePage, "RandomSelected", "ImageLabel"),
	}
	local filterBase = {
		Featured = descendant(explorePage, "FeaturedButtonPanel", "Frame"),
		MostLiked = descendant(explorePage, "MostLikedButtonPanel", "Frame"),
		Friends = descendant(explorePage, "FriendsButtonPanel", "Frame"),
		Random = descendant(explorePage, "RandomButtonPanel", "Frame"),
	}

	local function hideAquariumEditorAccessButtons()
		local editorGui = playerGui:FindFirstChild("AquariumFreePlacementGui")
		if not editorGui then
			return
		end
		for _, buttonName in ipairs({ "OpenAquariumDecorEditor", "BackToAquariumEditor" }) do
			local button = editorGui:FindFirstChild(buttonName, true)
			if button and button:IsA("GuiObject") then
				button.Visible = false
			end
		end
	end

	local controller = {
		state = nil,
		page = "MyTank",
		filter = "Featured",
		visible = false,
	}

	local function updateScale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1672, 941)
		local compactLayout = UserInputService.TouchEnabled or math.min(viewport.X, viewport.Y) <= 700

		if compactLayout then
			-- AquariumViewerGui already uses CoreUISafeInsets. Its AbsoluteSize is
			-- therefore the real drawable mobile canvas; subtracting GuiInset again
			-- made the Viewer much too small on landscape phones.
			local usableViewport = screenGui.AbsoluteSize
			if usableViewport.X < 1 or usableViewport.Y < 1 then
				usableViewport = viewport
			end
			local fit = math.min(
				(usableViewport.X * 0.98) / 1672,
				(usableViewport.Y * 0.98) / 941
			)

			uiScale.Scale = math.clamp(fit, 0.24, 1.05)
			root.Position = UDim2.fromScale(0.5, 0.5)
		else
			-- Preserve the approved edge-to-edge desktop composition exactly.
			uiScale.Scale = math.clamp(math.min(viewport.X / 1672, viewport.Y / 941), 0.34, 1.05)
			root.Position = UDim2.fromScale(0.5, 0.5)
		end
	end

	local function setPage(page)
		controller.page = page
		local myTank = page == "MyTank"
		myTankPage.Visible = myTank
		explorePage.Visible = not myTank
		myTankSelected.Visible = myTank
		exploreSelected.Visible = not myTank
		myTankTabBase.Visible = not myTank
		exploreTabBase.Visible = myTank
	end

	local function updateExploreFilterVisuals()
		for filter, artwork in pairs(filterSelected) do
			local selected = controller.filter == filter
			artwork.Visible = selected
			filterBase[filter].Visible = not selected
		end
	end

	local function visitVisitor(visitor)
		if type(visitor) ~= "table" or not visitor.UserId then
			return
		end
		context.Remote.TeleportTo:FireServer({
			kind = "PlayerAquarium",
			userId = visitor.UserId,
		})
	end

	local function getFilteredVisitors()
		local source = controller.state and controller.state.AquariumVisitors or {}
		local result = {}
		local query = string.lower(searchBox.Text or "")

		for _, visitor in ipairs(source) do
			local displayName = string.lower(visitor.DisplayName or "")
			local username = string.lower(visitor.Name or "")
			local matchesSearch = query == ""
				or string.find(displayName, query, 1, true) ~= nil
				or string.find(username, query, 1, true) ~= nil
			local matchesFilter = true
			if query ~= "" then
				-- Searching is a directory-wide action, not a filter within whichever
				-- category button happened to be selected previously.
				matchesFilter = true
			elseif controller.filter == "Featured" then
				matchesFilter = visitor.Featured == true
			elseif controller.filter == "Friends" then
				if visitor.IsSelf then
					matchesFilter = false
				else
					local ok, isFriend = pcall(context.player.IsFriendsWith, context.player, visitor.UserId)
					matchesFilter = ok and isFriend == true
				end
			elseif controller.filter == "Random" then
				matchesFilter = not visitor.IsSelf
			end

			if matchesSearch and matchesFilter then
				table.insert(result, visitor)
			end
		end

		if controller.filter == "MostLiked" then
			table.sort(result, function(a, b)
				local leftLikes = tonumber(a.LikeCount) or 0
				local rightLikes = tonumber(b.LikeCount) or 0
				if leftLikes ~= rightLikes then
					return leftLikes > rightLikes
				end
				return (tonumber(a.TotalValue) or 0) > (tonumber(b.TotalValue) or 0)
			end)
		elseif controller.filter == "Featured" then
			table.sort(result, function(a, b)
				local leftOrder = tonumber(a.FeaturedOrder) or math.huge
				local rightOrder = tonumber(b.FeaturedOrder) or math.huge
				if leftOrder ~= rightOrder then
					return leftOrder < rightOrder
				end
				return (tonumber(a.FeaturedRank) or math.huge) < (tonumber(b.FeaturedRank) or math.huge)
			end)
		elseif controller.filter == "Random" then
			for index = #result, 2, -1 do
				local swap = math.random(1, index)
				result[index], result[swap] = result[swap], result[index]
			end
		end

		return result
	end

	local function updateCustomScroll(list, track, thumb)
		local contentHeight = list.AbsoluteCanvasSize.Y
		local viewHeight = list.AbsoluteWindowSize.Y
		local trackHeight = track.AbsoluteSize.Y
		if contentHeight <= viewHeight or contentHeight <= 0 then
			thumb.Visible = true
			thumb.Size = UDim2.fromOffset(
				14,
				math.clamp(math.floor(trackHeight * 0.72), 90, trackHeight)
			)
			thumb.Position = UDim2.fromOffset(7, 0)
			return
		end

		thumb.Visible = true
		local thumbHeight = math.max(90, math.floor(trackHeight * (viewHeight / contentHeight)))
		local available = trackHeight - thumbHeight
		local maxCanvas = math.max(1, contentHeight - viewHeight)
		local ratio = math.clamp(list.CanvasPosition.Y / maxCanvas, 0, 1)
		thumb.Size = UDim2.fromOffset(14, thumbHeight)
		thumb.Position = UDim2.fromOffset(7, math.floor(available * ratio))
	end

	local function updateMyTankScroll()
		updateCustomScroll(myTankList, myTankScrollTrack, myTankScrollThumb)
	end

	local function updateExploreScroll()
		updateCustomScroll(visitorList, scrollTrack, scrollThumb)
	end

	local function renderMyTank()
		local currentState = controller.state
		if not currentState then
			return
		end

		local aquarium = currentState.Aquarium or { Level = 1, Capacity = 40, Fish = {} }
		local fish = aquarium.Fish or {}
		local level = tonumber(aquarium.Level) or 1
		local used = tonumber(aquarium.UsedCapacity)
			or context.GameConfig.getAquariumUsedSpace(fish)
		local capacity = tonumber(aquarium.Capacity)
			or context.GameConfig.AquariumCapacities[level]
			or 40
		local best = bestFish(currentState, fish)
		local nextCost = context.GameConfig.AquariumUpgradeCosts[level + 1]

		descendant(myTankPage, "LevelValue", "TextLabel").Text = tostring(level)
		descendant(myTankPage, "CapacityValue", "TextLabel").Text = string.format("%d / %d", used, capacity)
		descendant(myTankPage, "BestFishValue", "TextLabel").Text = best and (best.name or "Fish") or "None yet"
		local totalValue = descendant(myTankPage, "TotalValueValue", "TextLabel")
		totalValue.RichText = true
		totalValue.Text = string.format(
			'%s <font size="22">coins</font>',
			formatNumber(aquariumTotalValue(fish))
		)
		descendant(myTankPage, "FishCount", "TextLabel").Text = string.format("FISH  —  %d", #fish)
		descendant(myTankPage, "UpgradeText", "TextLabel").Text = nextCost
			and ("Upgrade +" .. formatNumber(nextCost))
			or "Max Level"

		clearRows(myTankList)
		for index, entry in ipairs(fish) do
			local row = fishTemplate:Clone()
			row.Name = "FishRow_" .. tostring(index)
			row.LayoutOrder = index
			row.Visible = true
			descendant(row, "FishImage", "ImageLabel").Image = fishImage(context.GameConfig, entry)
			local fishName = descendant(row, "FishName", "TextLabel")
			fishName.Text = entry.name or "Fish"
			local rarity = descendant(row, "Rarity", "TextLabel")
			rarity.Text = entry.rarity or "Common"
			rarity.TextColor3 = rarityColors[entry.rarity] or rarityColors.Common
			local nameWidth = TextService:GetTextSize(
				fishName.Text,
				fishName.TextSize,
				fishName.Font,
				Vector2.new(340, 43)
			).X
			rarity.Position = UDim2.fromOffset(math.clamp(186 + nameWidth + 18, 350, 500), 15)
			descendant(row, "Value", "TextLabel").Text = formatNumber(entry.value)
			descendant(row, "SpaceUsed", "TextLabel").Text = "Space used: " .. tostring(context.GameConfig.getAquariumFishSpace(entry))
			local remove = descendant(row, "RemoveButton", "TextButton")
			remove.MouseButton1Click:Connect(function()
				context.Remote.AquariumAction:FireServer("RemoveFish", entry.serial, index)
			end)
			setPressedFeedback(remove)
			row.Parent = myTankList
		end
		myTankEmpty.Visible = #fish == 0
		task.defer(updateMyTankScroll)
	end

	local function renderExplore()
		local visitors = getFilteredVisitors()
		clearRows(visitorList)

		for index, visitor in ipairs(visitors) do
			local row = visitorTemplate:Clone()
			row.Name = "AquariumRow_" .. tostring(visitor.UserId or index)
			row.LayoutOrder = index
			row.Visible = true
			local displayName = visitor.DisplayName or visitor.Name or "Player"
			if visitor.IsSelf then
				displayName ..= " (You)"
			end
			local playerName = descendant(row, "PlayerName", "TextLabel")
			playerName.Text = displayName
			local onlineStatus = descendant(row, "OnlineStatus", "TextLabel")
			local isOnline = visitor.Online ~= false
			onlineStatus.Text = isOnline and "● Online" or "○ Offline"
			onlineStatus.TextColor3 = isOnline
				and Color3.fromRGB(55, 255, 188)
				or Color3.fromRGB(190, 198, 214)
			local playerNameWidth = TextService:GetTextSize(
				displayName,
				playerName.TextSize,
				playerName.Font,
				Vector2.new(360, 38)
			).X
			onlineStatus.Position = UDim2.fromOffset(math.clamp(260 + playerNameWidth + 14, 465, 590), 14)
			descendant(row, "AquariumName", "TextLabel").Text = string.format("Level %d Aquarium", visitor.AquariumLevel or 1)
			descendant(row, "TotalValue", "TextLabel").Text = formatNumber(visitor.TotalValue)
			local best = visitor.BestCatch
			descendant(row, "BestFish", "TextLabel").Text = best and (best.name or "Fish") or "None yet"
			local image = fishImage(context.GameConfig, best)
			descendant(row, "BestFishImage", "ImageLabel").Image = image
			descendant(row, "PreviewFish", "ImageLabel").Image = image
			local likedByViewer = visitor.LikedByViewer == true
			local likeCount = descendant(row, "FishCount", "TextLabel")
			likeCount.Text = string.format(
				"%s %s",
				likedByViewer and "♥" or "♡",
				formatNumber(visitor.LikeCount)
			)
			likeCount.TextColor3 = likedByViewer
				and Color3.fromRGB(255, 116, 174)
				or Color3.fromRGB(255, 251, 238)

			local likeButton = descendant(row, "LikeButton", "TextButton")
			likeButton.Active = not visitor.IsSelf
			likeButton.Selectable = not visitor.IsSelf
			if not visitor.IsSelf then
				likeButton.MouseButton1Click:Connect(function()
					context.Remote.AquariumAction:FireServer("ToggleLike", visitor.UserId)
				end)
			end
			local visit = descendant(row, "ViewButton", "TextButton")
			visit.MouseButton1Click:Connect(function()
				visitVisitor(visitor)
			end)
			setPressedFeedback(visit)
			row.Parent = visitorList
		end

		exploreEmpty.Visible = #visitors == 0
		task.defer(updateExploreScroll)
	end

	function controller:Render(newState)
		if newState then
			self.state = newState
		end
		if not self.state then
			return
		end
		renderMyTank()
		renderExplore()
	end

	function controller:Show(newState)
		self.visible = true
		hideAquariumEditorAccessButtons()
		root.Visible = true
		setPage(self.page)
		updateScale()
		self:Render(newState)
	end

	function controller:Hide()
		self.visible = false
		root.Visible = false
	end

	function controller:IsVisible()
		return root.Visible
	end

	descendant(root, "MyTankButton", "TextButton").MouseButton1Click:Connect(function()
		setPage("MyTank")
		renderMyTank()
	end)
	descendant(root, "ExploreButton", "TextButton").MouseButton1Click:Connect(function()
		setPage("Explore")
		renderExplore()
	end)
	descendant(root, "CloseButton", "ImageButton").MouseButton1Click:Connect(function()
		controller:Hide()
		if context.onClose then
			context.onClose()
		end
	end)
	descendant(myTankPage, "UpgradeButton", "TextButton").MouseButton1Click:Connect(function()
		context.Remote.AquariumAction:FireServer("Upgrade")
	end)

	local filterButtons = {
		FeaturedButton = "Featured",
		MostLikedButton = "MostLiked",
		FriendsButton = "Friends",
		RandomButton = "Random",
	}
	for buttonName, filter in pairs(filterButtons) do
		local button = descendant(explorePage, buttonName, "TextButton")
		button.MouseButton1Click:Connect(function()
			controller.filter = filter
			updateExploreFilterVisuals()
			descendant(explorePage, "ExploreHeading", "TextLabel").Text = string.upper(filter == "MostLiked" and "Most Liked Aquariums" or (filter .. " Aquariums"))
			renderExplore()
		end)
		setPressedFeedback(button)
	end

	descendant(explorePage, "VisitRandomButton", "TextButton").MouseButton1Click:Connect(function()
		local choices = {}
		for _, visitor in ipairs(controller.state and controller.state.AquariumVisitors or {}) do
			if not visitor.IsSelf then
				table.insert(choices, visitor)
			end
		end
		if #choices == 0 then
			context.showToast("No other aquariums are available yet.")
			return
		end
		visitVisitor(choices[math.random(1, #choices)])
	end)

	searchBox:GetPropertyChangedSignal("Text"):Connect(renderExplore)
	visitorList:GetPropertyChangedSignal("CanvasPosition"):Connect(updateExploreScroll)
	visitorList:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateExploreScroll)
	myTankList:GetPropertyChangedSignal("CanvasPosition"):Connect(updateMyTankScroll)
	myTankList:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateMyTankScroll)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	for _, name in ipairs({ "MyTankButton", "ExploreButton", "UpgradeButton", "CloseButton" }) do
		setPressedFeedback(descendant(root, name))
	end

	updateScale()
	updateExploreFilterVisuals()
	controller:Hide()
	return controller
end

return AquariumViewerModernUI
