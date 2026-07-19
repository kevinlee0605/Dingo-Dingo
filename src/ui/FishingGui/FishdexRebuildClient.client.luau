-- FishdexVisualPatch_REDESIGN_v22_ShortTrackThumbFit
-- Replace your current FishdexVisualPatch.luau with this whole file.
-- StarterGui > FishingGui > FishdexVisualPatch

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local fishingGui = playerGui:WaitForChild("FishingGui")
assert(
	fishingGui:GetAttribute("AuthoredUiV2") == true,
	"[FishdexRebuildClient] AuthoredUiV2 is required"
)

local ASSETS = {
	FishdexIcon = "rbxassetid://126888363962311",
	AllTabSelected = "rbxassetid://74193356060798",
	AllTabUnselected = "rbxassetid://122642765846638",
	IslandTabSelected = "rbxassetid://119120751789446",
	IslandTabUnselected = "rbxassetid://74423157457349",
	AllIcon = "rbxassetid://104401098200678",
	LilyshoreIslandIcon = "rbxassetid://98205500611196",
	RiverbendIslandIcon = "rbxassetid://71447038153276",
	CoralCoastIslandIcon = "rbxassetid://118883751708776",
	CollectionTab = "rbxassetid://101419501637204",
	CheckedIcon = "rbxassetid://73430945226148",
	FishyBackGround = "rbxassetid://77909229815890",
	FishdexRealBackGround = "rbxassetid://89231191992466",
	YellowButton = "rbxassetid://86677248763340",
	XButton = "rbxassetid://119322438066977",
	CustomScrollBar = "rbxassetid://73367138577137",
}

local TAB_CONFIG = {
	AllTab = {
		label = "All",
		icon = ASSETS.AllIcon,
		selectedImage = ASSETS.AllTabSelected,
		unselectedImage = ASSETS.AllTabUnselected,
		textX = 0.70,
		textWidth = 0.28,
		textSize = 35,
		iconX = 0.25,
		iconSize = UDim2.fromOffset(48, 48),
	},
	LilyshoreIslandTab = {
		label = "Lilyshore Island",
		icon = ASSETS.LilyshoreIslandIcon,
		selectedImage = ASSETS.IslandTabSelected,
		unselectedImage = ASSETS.IslandTabUnselected,
		textX = 0.63,
		textWidth = 0.60,
		textSize = 32,
		iconX = 0.16,
		iconSize = UDim2.fromOffset(60, 60),
	},
	RiverbendIslandTab = {
		label = "Riverbend Island",
		icon = ASSETS.RiverbendIslandIcon,
		selectedImage = ASSETS.IslandTabSelected,
		unselectedImage = ASSETS.IslandTabUnselected,
		textX = 0.63,
		textWidth = 0.60,
		textSize = 32,
		iconX = 0.16,
		iconSize = UDim2.fromOffset(60, 60),
	},
	CoralCoastIslandTab = {
		label = "Coral Coast Island",
		icon = ASSETS.CoralCoastIslandIcon,
		selectedImage = ASSETS.IslandTabSelected,
		unselectedImage = ASSETS.IslandTabUnselected,
		textX = 0.63,
		textWidth = 0.62,
		textSize = 31,
		iconX = 0.16,
		iconSize = UDim2.fromOffset(60, 60),
	},
}

local CARD_WIDTH = 390
local CARD_HEIGHT = 270
local CARD_GAP_X = 24
local CARD_GAP_Y = 22

local selectedTabName = "AllTab"

-- =========================
-- CUSTOM SCROLLBAR SETTINGS
-- =========================
-- X 증가 = 오른쪽 / Y 증가 = 아래
-- Custom Fishdex scrollbar layout.
-- The shortened 520px track stops above the Collection panel.
-- The 18px thumb stays centered inside the 30px track with equal side gaps.
local CUSTOM_SCROLL_X = 1390
local CUSTOM_SCROLL_Y = 310
local CUSTOM_SCROLL_WIDTH = 24
local CUSTOM_SCROLL_HEIGHT = 520
local CUSTOM_SCROLL_MIN_THUMB_HEIGHT = 90
local CUSTOM_SCROLL_TRACK_PADDING = 2
local CUSTOM_SCROLL_THUMB_WIDTH = 20


local function findModernFishdex()
	local container = fishingGui:WaitForChild("ModernFishdex", 30)
	if not (container and container:IsA("Frame")) then
		error(
			"[FishdexRebuildClient] Authored ModernFishdex container is missing",
			2
		)
	end
	local modernRoot = container:FindFirstChild("ModernFishdex")
	if not (modernRoot and modernRoot:IsA("ImageLabel")) then
		error(
			"[FishdexRebuildClient] Authored ModernFishdex ImageLabel is missing",
			2
		)
	end
	return modernRoot
end

local function requireAuthoredChild(parent, className, name)
	local child = parent:FindFirstChild(name)
	if child and child.ClassName == className then
		return child
	end
	error(string.format(
		"[FishdexRebuildClient] Authored v22 node %s (%s) is missing or has the wrong class under %s",
		name,
		className,
		parent:GetFullName()
	), 2)
end

local function setTextConstraint(label, minSize, maxSize)
	local c = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not c then
		error(
			"[FishdexRebuildClient] Authored v22 text constraint is missing from "
				.. label:GetFullName(),
			2
		)
	end
	c.MinTextSize = minSize
	c.MaxTextSize = maxSize
end

local function isTabSelected(button)
	if selectedTabName and button.Name == selectedTabName then
		return true
	end

	local stroke = button:FindFirstChild("SelectedStroke")
	if stroke and stroke:IsA("UIStroke") then
		return stroke.Transparency < 0.5
	end

	return button.Name == "AllTab"
end

local function isUnknownFishCard(card, fishImage, fishName)
	if fishName and fishName:IsA("TextLabel") then
		local text = string.lower((fishName.Text or ""):gsub("%s+", ""))
		if text == "" or text == "?" or text == "??" or text == "???" or text == "unknown" or text == "locked" then
			return true
		end
	end

	if fishImage and fishImage:IsA("ImageLabel") then
		local c = fishImage.ImageColor3
		if c.R <= 0.08 and c.G <= 0.08 and c.B <= 0.08 then
			return true
		end
	end

	return false
end

local function syncSelectedTabFromState(modernRoot)
	for _, child in ipairs(modernRoot:GetChildren()) do
		if child:IsA("ImageButton") and TAB_CONFIG[child.Name] then
			local stroke = child:FindFirstChild("SelectedStroke")
			if stroke and stroke:IsA("UIStroke") and stroke.Transparency < 0.5 then
				selectedTabName = child.Name
				return
			end
		end
	end
end

local function patchBase(modernRoot)
	-- Fishdex 전체 UI의 기준점을 중앙으로 고정
	modernRoot.AnchorPoint = Vector2.new(0.5, 0.5)

	-- 전체 Fishdex UI 위치
	-- 두 번째 숫자를 줄이면 위로, 키우면 아래로 이동
	modernRoot.Position = UDim2.fromScale(0.5, 0.43)

	modernRoot.ScaleType = Enum.ScaleType.Stretch
	modernRoot.BackgroundTransparency = 1
	modernRoot.Image = ASSETS.FishdexRealBackGround
	modernRoot.ZIndex = 200
end

local function patchHeader(modernRoot)
	local title = modernRoot:FindFirstChild("FishdexTitle")
	if title and title:IsA("TextLabel") then
		title.AnchorPoint = Vector2.new(0.5, 0)
		title.Position = UDim2.fromOffset(790, 25)
		title.Size = UDim2.fromOffset(650, 112)
		title.Text = "FISHDEX"
		title.TextScaled = false
		title.TextSize = 132
		title.Font = Enum.Font.FredokaOne
		-- 기본 TextStroke는 끄기
		title.TextStrokeTransparency = 1

		-- 두께를 조절할 수 있는 외곽선
		local titleOutline = requireAuthoredChild(
			title,
			"UIStroke",
			"FishdexTitleOutline"
		)

		titleOutline.Color = Color3.fromRGB(0, 0, 0)
		titleOutline.Thickness = 4
		titleOutline.Transparency = 0
		title.TextStrokeTransparency = 0
		setTextConstraint(title, 38, 88)
		title.ZIndex = 210
	end

	local book = requireAuthoredChild(modernRoot, "ImageLabel", "FishdexHeaderIcon")
	book.BackgroundTransparency = 1
	book.AnchorPoint = Vector2.new(0.5, 0)
	book.Position = UDim2.fromOffset(540, 10)
	book.Size = UDim2.fromOffset(114, 114)
	book.Image = ASSETS.FishdexIcon
	book.ScaleType = Enum.ScaleType.Fit
	book.ZIndex = 210

	local leftBadge = requireAuthoredChild(modernRoot, "ImageLabel", "HeaderYellowBadge")
	leftBadge.BackgroundTransparency = 1
	leftBadge.Position = UDim2.fromOffset(48, 43)
	leftBadge.Size = UDim2.fromOffset(60, 60)
	leftBadge.Image = ASSETS.YellowButton
	leftBadge.ScaleType = Enum.ScaleType.Fit
	leftBadge.ZIndex = 210

	local closeButton = modernRoot:FindFirstChild("CloseButton")
	if closeButton and closeButton:IsA("ImageButton") then
		local fixedPosition = UDim2.fromOffset(1290, -20)
		local fixedSize = UDim2.fromOffset(250, 250)

		-- Keep the original button functional, but make its moving image invisible.
		-- FishingClient still runs its old press tween, but the player cannot see it.
		closeButton.BackgroundTransparency = 1
		closeButton.Position = fixedPosition
		closeButton.Size = fixedSize
		closeButton.Image = ASSETS.XButton
		closeButton.ImageTransparency = 1
		closeButton.ScaleType = Enum.ScaleType.Fit
		closeButton.AutoButtonColor = false
		closeButton.ZIndex = 211

		-- This separate, non-interactive image stays completely fixed.
		-- Clicks pass through to the invisible original CloseButton underneath.
		local staticVisual = requireAuthoredChild(modernRoot, "ImageLabel", "CloseButtonStaticVisual")
		staticVisual.BackgroundTransparency = 1
		staticVisual.Position = fixedPosition
		staticVisual.Size = fixedSize
		staticVisual.Image = ASSETS.XButton
		staticVisual.ImageTransparency = 0
		staticVisual.ScaleType = Enum.ScaleType.Fit
		staticVisual.Active = false
		staticVisual.Selectable = false
		staticVisual.ZIndex = 212
		staticVisual.ImageColor3 = Color3.new(1, 1, 1)

		-- Press feedback without moving the X button.
		-- The visual shrinks slightly and darkens while pressed, then springs back.
		local pressScale = requireAuthoredChild(
			staticVisual,
			"UIScale",
			"ClosePressScale"
		)

		if not closeButton:GetAttribute("FishdexClosePressFeedbackConnected") then
			closeButton:SetAttribute("FishdexClosePressFeedbackConnected", true)

			local pressTween = nil
			local isPressed = false

			local function tweenPressState(pressed)
				isPressed = pressed
				if pressTween then
					pressTween:Cancel()
				end

				pressTween = TweenService:Create(
					pressScale,
					TweenInfo.new(
						pressed and 0.055 or 0.11,
						pressed and Enum.EasingStyle.Quad or Enum.EasingStyle.Back,
						Enum.EasingDirection.Out
					),
					{ Scale = pressed and 0.88 or 1 }
				)
				pressTween:Play()

				TweenService:Create(
					staticVisual,
					TweenInfo.new(pressed and 0.055 or 0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ ImageColor3 = pressed and Color3.fromRGB(205, 205, 205) or Color3.new(1, 1, 1) }
				):Play()
			end

			closeButton.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					tweenPressState(true)
				end
			end)

			closeButton.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					tweenPressState(false)
				end
			end)

			closeButton.MouseLeave:Connect(function()
				if isPressed then
					tweenPressState(false)
				end
			end)

			closeButton.Activated:Connect(function()
				tweenPressState(false)
			end)
		end

		-- Keep the invisible click area fixed after the old tween tries to move it.
		if not closeButton:GetAttribute("FishdexCloseInvisiblePositionLocked") then
			closeButton:SetAttribute("FishdexCloseInvisiblePositionLocked", true)
			local correcting = false
			closeButton:GetPropertyChangedSignal("Position"):Connect(function()
				if correcting or closeButton.Position == fixedPosition then
					return
				end

				correcting = true
				closeButton.Position = fixedPosition
				correcting = false
			end)
		end
	end

	local divider = requireAuthoredChild(modernRoot, "Frame", "TabsDivider")
	divider.AnchorPoint = Vector2.new(0.5, 0)
	divider.Position = UDim2.fromOffset(770, 262)
	divider.Size = UDim2.fromOffset(1368, 2)
	divider.BackgroundColor3 = Color3.fromRGB(68, 164, 255)
	divider.BackgroundTransparency = 0.35
	divider.BorderSizePixel = 0
	divider.ZIndex = 206
end

local function patchTab(button)
	if not button:IsA("ImageButton") then
		return
	end
	local cfg = TAB_CONFIG[button.Name]
	if not cfg then
		return
	end

	button.AutoButtonColor = false
	button.ScaleType = Enum.ScaleType.Stretch
	button.Image = isTabSelected(button) and cfg.selectedImage or cfg.unselectedImage
	button.ZIndex = 207

	local stroke = button:FindFirstChild("SelectedStroke")
	if stroke then
		stroke.Transparency = 1
	end

	local title = button:FindFirstChild("TabTitle")
	if title and title:IsA("TextLabel") then
		title.BackgroundTransparency = 1
		title.AnchorPoint = Vector2.new(0.5, 0.5)
		title.Position = UDim2.fromScale(cfg.textX, 0.50)
		title.Size = UDim2.fromScale(cfg.textWidth, 0.68)
		title.Font = Enum.Font.FredokaOne
		title.Text = cfg.label
		title.TextScaled = true
		title.TextSize = cfg.textSize
		title.TextColor3 = Color3.fromRGB(255,255,255)
		title.TextStrokeColor3 = Color3.fromRGB(0,0,0)
		title.TextStrokeTransparency = 0
		setTextConstraint(title, 14, cfg.textSize)
		title.ZIndex = 208
	end

	local icon = requireAuthoredChild(button, "ImageLabel", "TabIcon")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(cfg.iconX, 0.5)
	icon.Size = cfg.iconSize
	icon.Image = cfg.icon
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 208
	icon.Active = false
end

local function refreshTabs(modernRoot)
	syncSelectedTabFromState(modernRoot)
	for _, child in ipairs(modernRoot:GetChildren()) do
		patchTab(child)
	end
end

local function patchCollection(modernRoot)
	local panel = modernRoot:FindFirstChild("CollectionPanel")
	if not (panel and panel:IsA("ImageLabel")) then
		return
	end

	-- Match the Collection panel proportions and internal spacing to the reference image.
	panel.Image = ASSETS.CollectionTab
	panel.Position = UDim2.fromOffset(1172, 860)
	panel.Size = UDim2.fromOffset(327, 103)
	panel.ScaleType = Enum.ScaleType.Stretch
	panel.ZIndex = 207

	local checked = requireAuthoredChild(panel, "ImageLabel", "CheckedIcon")
	checked.BackgroundTransparency = 1
	checked.AnchorPoint = Vector2.new(0.5, 0.5)
	checked.Position = UDim2.fromScale(0.20, 0.50)
	checked.Size = UDim2.fromOffset(78, 78)
	checked.Image = ASSETS.CheckedIcon
	checked.ScaleType = Enum.ScaleType.Fit
	checked.ZIndex = 208

	local title = panel:FindFirstChild("CollectionTitle")
	if title and title:IsA("TextLabel") then
		title.BackgroundTransparency = 1
		title.AnchorPoint = Vector2.new(0.5, 0.5)
		title.Position = UDim2.fromScale(0.64, 0.28)
		title.Size = UDim2.fromScale(0.58, 0.30)
		title.Font = Enum.Font.FredokaOne
		title.Text = "Collection"
		title.TextScaled = false
		title.TextSize = 30
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.TextYAlignment = Enum.TextYAlignment.Center
		title.TextColor3 = Color3.fromRGB(50, 241, 255)
		title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		title.TextStrokeTransparency = 0
		setTextConstraint(title, 16, 30)
	end

	local count = panel:FindFirstChild("CollectionCount")
	if count and count:IsA("TextLabel") then
		count.BackgroundTransparency = 1
		count.AnchorPoint = Vector2.new(0.5, 0.5)
		count.Position = UDim2.fromScale(0.64, 0.68)
		count.Size = UDim2.fromScale(0.54, 0.38)
		count.Font = Enum.Font.FredokaOne
		count.TextScaled = false
		count.TextSize = 38
		count.TextXAlignment = Enum.TextXAlignment.Center
		count.TextYAlignment = Enum.TextYAlignment.Center
		count.TextColor3 = Color3.fromRGB(255, 255, 255)
		count.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		count.TextStrokeTransparency = 0
		setTextConstraint(count, 20, 38)
	end
end

local function patchFishCard(card)
	if not card:IsA("ImageLabel") or not string.match(card.Name, "Card$") then
		return
	end

	card.ScaleType = Enum.ScaleType.Stretch
	card.Image = ASSETS.FishyBackGround
	card.BackgroundTransparency = 1
	card.ZIndex = 206

	local fishImage = card:FindFirstChild("FishImage")
	if fishImage and fishImage:IsA("ImageLabel") then
		fishImage.BackgroundTransparency = 1
		fishImage.AnchorPoint = Vector2.new(0.5, 0.5)
		fishImage.Position = UDim2.new(0.5, 0, 0.33, 0)
		fishImage.Size = UDim2.new(0.92, 0, 0.58, 0)
		fishImage.ScaleType = Enum.ScaleType.Fit
		fishImage.ZIndex = 207
	end

	local fishName = card:FindFirstChild("FishName")
	if fishName and fishName:IsA("TextLabel") then
		fishName.AnchorPoint = Vector2.new(0.5, 0.5)
		fishName.Position = UDim2.new(0.5, 0, 0.67, 0)
		fishName.Size = UDim2.new(0.92, 0, 0.16, 0)
		fishName.BackgroundTransparency = 1
		fishName.Font = Enum.Font.FredokaOne
		fishName.TextScaled = true
		setTextConstraint(fishName, 12, 25)
		fishName.TextColor3 = Color3.fromRGB(255,255,255)
		fishName.TextStrokeColor3 = Color3.fromRGB(0,0,0)
		fishName.TextStrokeTransparency = 0
		fishName.ZIndex = 207
	end

	local badge = card:FindFirstChild("RarityBadge")
	if badge and badge:IsA("ImageLabel") then
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(0.5, 0, 0.84, 0)

		-- 원본 배지 이미지에는 투명 여백이 있어서 ImageLabel 자체를 크게 잡아야
		-- 실제로 보이는 색상 탭이 참고 이미지와 비슷한 크기가 된다.
		badge.Size = UDim2.new(0.84, 0, 0.28, 0)
		badge.ScaleType = Enum.ScaleType.Stretch
		badge.ZIndex = 207

		local rarityText = badge:FindFirstChild("RarityText")
		if rarityText and rarityText:IsA("TextLabel") then
			local rarityName = string.upper(rarityText.Text or "")
			local rarityTextWidth = 0.30
			local rarityTextMaxSize = 17

			if rarityName == "UNCOMMON" then
				-- UNCOMMON은 글자가 길고 원본 배지 이미지에 투명 여백이 많아서
				-- 배지 자체를 별도로 더 크게 잡아 글자 주변 여백을 확보한다.
				badge.Size = UDim2.new(1.02, 0, 0.34, 0)
				rarityTextWidth = 0.38
				rarityTextMaxSize = 15
			elseif rarityName == "LEGENDARY" then
				rarityTextWidth = 0.45
			elseif rarityName == "COMMON" then
				rarityTextWidth = 0.34
			elseif rarityName == "MYTHIC" then
				rarityTextWidth = 0.32
			elseif rarityName == "RARE" or rarityName == "EPIC" then
				rarityTextWidth = 0.25
			end

			rarityText.AnchorPoint = Vector2.new(0.5, 0.5)
			rarityText.Position = UDim2.fromScale(0.5, 0.5)
			rarityText.Size = UDim2.new(rarityTextWidth, 0, 0.34, 0)
			rarityText.BackgroundTransparency = 1
			rarityText.Font = Enum.Font.FredokaOne
			rarityText.TextScaled = true
			setTextConstraint(rarityText, 8, rarityTextMaxSize)
			rarityText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			rarityText.TextStrokeTransparency = 0
			rarityText.ZIndex = 208
		end
	end

	local unknown = isUnknownFishCard(card, fishImage, fishName)
	if unknown then
		if fishImage and fishImage:IsA("ImageLabel") then
			fishImage.AnchorPoint = Vector2.new(0.5, 0.5)
			fishImage.Position = UDim2.fromScale(0.5, 0.42)
			fishImage.Size = UDim2.new(0.80, 0, 0.50, 0)
			fishImage.ImageColor3 = Color3.new(0, 0, 0)
			fishImage.ImageTransparency = 0
		end
		if fishName and fishName:IsA("TextLabel") then
			fishName.Visible = true
			fishName.Text = "???"
		end
		if badge and badge:IsA("ImageLabel") then
			badge.Visible = false
		end
	else
		if fishName and fishName:IsA("TextLabel") then
			fishName.Visible = true
		end
		if badge and badge:IsA("ImageLabel") then
			badge.Visible = true
		end
	end
end

local function patchCustomScrollbar(modernRoot, cardsScroll)
	-- Hide Roblox's native scrollbar completely.
	local function hideNativeScrollbar()
		cardsScroll.ScrollBarThickness = 0
		cardsScroll.ScrollBarImageTransparency = 1

		pcall(function()
			cardsScroll.TopImage = ""
			cardsScroll.MidImage = ""
			cardsScroll.BottomImage = ""
			cardsScroll.VerticalScrollBarInset = Enum.ScrollBarInset.None
		end)
	end

	hideNativeScrollbar()
	cardsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	cardsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cardsScroll.ClipsDescendants = true
	cardsScroll.Active = true
	cardsScroll.ScrollingEnabled = true

	if not cardsScroll:GetAttribute("FishdexNativeScrollbarLockedV7") then
		cardsScroll:SetAttribute("FishdexNativeScrollbarLockedV7", true)
		cardsScroll:GetPropertyChangedSignal("ScrollBarThickness"):Connect(hideNativeScrollbar)
		cardsScroll:GetPropertyChangedSignal("ScrollBarImageTransparency"):Connect(hideNativeScrollbar)
	end

	-- One single dark track. There is no inner slot/frame.
	local track = requireAuthoredChild(modernRoot, "Frame", "FishdexCustomScrollTrack")
	track.BackgroundColor3 = Color3.fromRGB(3, 22, 62)
	track.BackgroundTransparency = 0
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(CUSTOM_SCROLL_X, CUSTOM_SCROLL_Y)
	track.Size = UDim2.fromOffset(CUSTOM_SCROLL_WIDTH, CUSTOM_SCROLL_HEIGHT)
	track.Active = true
	track.ClipsDescendants = true
	track.Visible = true
	track.ZIndex = 214

	local trackCorner = requireAuthoredChild(track, "UICorner", "TrackCorner")
	trackCorner.CornerRadius = UDim.new(1, 0)

	local trackStroke = requireAuthoredChild(track, "UIStroke", "TrackStroke")
	trackStroke.Color = Color3.fromRGB(18, 93, 245)
	trackStroke.Thickness = 2
	trackStroke.Transparency = 0.08

	local trackGradient = requireAuthoredChild(track, "UIGradient", "TrackGradient")
	trackGradient.Rotation = 0
	trackGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 39, 101)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(2, 18, 53)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 39, 101)),
	})

	-- The glowing thumb is a direct child of the track, centered horizontally.
	local thumb = requireAuthoredChild(track, "ImageButton", "FishdexCustomScrollThumb")
	thumb.AnchorPoint = Vector2.new(0.5, 0)
	thumb.BackgroundColor3 = Color3.fromRGB(0, 118, 255)
	thumb.BackgroundTransparency = 0
	thumb.BorderSizePixel = 0
	thumb.Image = ""
	thumb.AutoButtonColor = false
	thumb.Active = true
	thumb.Selectable = false
	thumb.ZIndex = 216

	local thumbCorner = requireAuthoredChild(thumb, "UICorner", "ThumbCorner")
	thumbCorner.CornerRadius = UDim.new(1, 0)

	local thumbGradient = requireAuthoredChild(thumb, "UIGradient", "ThumbGradient")
	thumbGradient.Rotation = 90
	thumbGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 239, 255)),
		ColorSequenceKeypoint.new(0.34, Color3.fromRGB(0, 167, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 72, 235)),
	})

	local thumbStroke = requireAuthoredChild(thumb, "UIStroke", "ThumbGlowStroke")
	thumbStroke.Color = Color3.fromRGB(0, 235, 255)
	thumbStroke.Thickness = 2
	thumbStroke.Transparency = 0

	local thumbHighlight = requireAuthoredChild(thumb, "Frame", "ThumbHighlight")
	thumbHighlight.BackgroundColor3 = Color3.fromRGB(188, 252, 255)
	thumbHighlight.BackgroundTransparency = 0.43
	thumbHighlight.BorderSizePixel = 0
	thumbHighlight.Position = UDim2.fromScale(0.18, 0.04)
	thumbHighlight.Size = UDim2.fromScale(0.18, 0.92)
	thumbHighlight.Active = false
	thumbHighlight.ZIndex = 217

	local highlightCorner = requireAuthoredChild(
		thumbHighlight,
		"UICorner",
		"HighlightCorner"
	)
	highlightCorner.CornerRadius = UDim.new(1, 0)

	local function getScrollMetrics()
		local usableHeight = math.max(0, track.AbsoluteSize.Y - CUSTOM_SCROLL_TRACK_PADDING * 2)
		local viewportHeight = cardsScroll.AbsoluteWindowSize.Y
		if viewportHeight <= 0 then
			viewportHeight = cardsScroll.AbsoluteSize.Y
		end

		local canvasHeight = math.max(cardsScroll.AbsoluteCanvasSize.Y, viewportHeight)
		local scrollRange = math.max(0, canvasHeight - viewportHeight)
		local visibleRatio = canvasHeight > 0
			and math.clamp(viewportHeight / canvasHeight, 0, 1)
			or 1

		local minimumHeight = math.min(CUSTOM_SCROLL_MIN_THUMB_HEIGHT, usableHeight)
		local thumbHeight = math.clamp(usableHeight * visibleRatio, minimumHeight, usableHeight)
		local thumbTravel = math.max(0, usableHeight - thumbHeight)
		return usableHeight, thumbHeight, thumbTravel, scrollRange
	end

	local updating = false
	local function updateThumbFromCanvas()
		if updating then
			return
		end

		local usableHeight, thumbHeight, thumbTravel, scrollRange = getScrollMetrics()
		if usableHeight <= 0 then
			task.defer(updateThumbFromCanvas)
			return
		end

		local progress = scrollRange > 0
			and math.clamp(cardsScroll.CanvasPosition.Y / scrollRange, 0, 1)
			or 0

		updating = true
		thumb.Size = UDim2.fromOffset(CUSTOM_SCROLL_THUMB_WIDTH, thumbHeight)
		thumb.Position = UDim2.new(
			0.5,
			0,
			0,
			CUSTOM_SCROLL_TRACK_PADDING + thumbTravel * progress
		)
		thumb.Active = scrollRange > 0
		track.Visible = true
		updating = false
	end

	local function setCanvasFromThumbTop(thumbTopInsideUsableArea)
		local _, _, thumbTravel, scrollRange = getScrollMetrics()
		if thumbTravel <= 0 or scrollRange <= 0 then
			cardsScroll.CanvasPosition = Vector2.new(cardsScroll.CanvasPosition.X, 0)
			return
		end

		local progress = math.clamp(thumbTopInsideUsableArea / thumbTravel, 0, 1)
		cardsScroll.CanvasPosition = Vector2.new(
			cardsScroll.CanvasPosition.X,
			progress * scrollRange
		)
	end

	if not track:GetAttribute("FishdexCustomScrollbarConnectedV7") then
		track:SetAttribute("FishdexCustomScrollbarConnectedV7", true)

		local dragging = false
		local dragOffsetY = 0

		thumb.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragOffsetY = input.Position.Y - thumb.AbsolutePosition.Y
				TweenService:Create(
					thumb,
					TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundColor3 = Color3.fromRGB(0, 205, 255) }
				):Play()
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch then
				local thumbTop = input.Position.Y
				- track.AbsolutePosition.Y
				- CUSTOM_SCROLL_TRACK_PADDING
				- dragOffsetY
				setCanvasFromThumbTop(thumbTop)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				if dragging then
					dragging = false
					TweenService:Create(
						thumb,
						TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundColor3 = Color3.fromRGB(0, 118, 255) }
					):Play()
				end
			end
		end)

		track.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			local pointerY = input.Position.Y
			if pointerY >= thumb.AbsolutePosition.Y
				and pointerY <= thumb.AbsolutePosition.Y + thumb.AbsoluteSize.Y then
				return
			end

			local _, thumbHeight = getScrollMetrics()
			local top = pointerY
			- track.AbsolutePosition.Y
			- CUSTOM_SCROLL_TRACK_PADDING
			- thumbHeight * 0.5
			setCanvasFromThumbTop(top)
		end)

		cardsScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateThumbFromCanvas)
		cardsScroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateThumbFromCanvas)
		cardsScroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateThumbFromCanvas)
		track:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateThumbFromCanvas)

		local cardsHolder = cardsScroll:FindFirstChild("CardsHolder")
		if cardsHolder then
			local grid = cardsHolder:FindFirstChildOfClass("UIGridLayout")
			if grid then
				grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateThumbFromCanvas)
			end
		end
	end

	updateThumbFromCanvas()
	task.defer(function()
		hideNativeScrollbar()
		updateThumbFromCanvas()
	end)
	task.delay(0.25, function()
		hideNativeScrollbar()
		updateThumbFromCanvas()
	end)
end

local function patchCards(modernRoot)
	local cardsScroll = modernRoot:FindFirstChild("FishCardsScroll")
	if not (cardsScroll and cardsScroll:IsA("ScrollingFrame")) then
		return
	end

	cardsScroll.Position = UDim2.fromOffset(125, 300)
	cardsScroll.Size = UDim2.fromOffset(1275, 610)
	cardsScroll.BackgroundTransparency = 1
	cardsScroll.ZIndex = 205
	cardsScroll.ScrollBarThickness = 0
	cardsScroll.ScrollBarImageTransparency = 1

	local cardsHolder = cardsScroll:FindFirstChild("CardsHolder")
	if not cardsHolder then
		return
	end

	local grid = cardsHolder:FindFirstChildOfClass("UIGridLayout")
	if grid then
		grid.CellSize = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
		grid.CellPadding = UDim2.fromOffset(CARD_GAP_X, CARD_GAP_Y)
	end

	for _, child in ipairs(cardsHolder:GetChildren()) do
		patchFishCard(child)
	end

	if not cardsHolder:GetAttribute("PatchedV5") then
		cardsHolder:SetAttribute("PatchedV5", true)
		cardsHolder.ChildAdded:Connect(function(child)
			task.defer(function()
				patchFishCard(child)
				patchCustomScrollbar(modernRoot, cardsScroll)
			end)
		end)
	end

	patchCustomScrollbar(modernRoot, cardsScroll)
end

local function hookTabs(modernRoot)
	for _, child in ipairs(modernRoot:GetChildren()) do
		if child:IsA("ImageButton") and TAB_CONFIG[child.Name] and not child:GetAttribute("HookedV5") then
			child:SetAttribute("HookedV5", true)
			local stroke = child:FindFirstChild("SelectedStroke")
			if stroke and stroke:IsA("UIStroke") then
				stroke:GetPropertyChangedSignal("Transparency"):Connect(function()
					refreshTabs(modernRoot)
				end)
			end
			child.MouseButton1Click:Connect(function()
				selectedTabName = child.Name
				task.defer(function()
					refreshTabs(modernRoot)
				end)
			end)
		end
	end
end

local function validateAuthoredFishdex(modernRoot)
	requireAuthoredChild(modernRoot, "UIScale", "ResponsiveScale")
	local title = requireAuthoredChild(modernRoot, "TextLabel", "FishdexTitle")
	requireAuthoredChild(title, "UIStroke", "FishdexTitleOutline")
	requireAuthoredChild(title, "UITextSizeConstraint", "UITextSizeConstraint")
	requireAuthoredChild(modernRoot, "ImageLabel", "FishdexHeaderIcon")
	requireAuthoredChild(modernRoot, "ImageLabel", "HeaderYellowBadge")
	requireAuthoredChild(modernRoot, "Frame", "TabsDivider")
	requireAuthoredChild(modernRoot, "ImageButton", "CloseButton")
	local staticClose = requireAuthoredChild(
		modernRoot,
		"ImageLabel",
		"CloseButtonStaticVisual"
	)
	requireAuthoredChild(staticClose, "UIScale", "ClosePressScale")

	for tabName in pairs(TAB_CONFIG) do
		local tab = requireAuthoredChild(modernRoot, "ImageButton", tabName)
		requireAuthoredChild(tab, "UIStroke", "SelectedStroke")
		requireAuthoredChild(tab, "ImageLabel", "TabIcon")
		local tabTitle = requireAuthoredChild(tab, "TextLabel", "TabTitle")
		requireAuthoredChild(tabTitle, "UITextSizeConstraint", "UITextSizeConstraint")
	end

	local cardsScroll = requireAuthoredChild(
		modernRoot,
		"ScrollingFrame",
		"FishCardsScroll"
	)
	local cardsHolder = requireAuthoredChild(cardsScroll, "Frame", "CardsHolder")
	requireAuthoredChild(cardsHolder, "UIGridLayout", "UIGridLayout")

	local cardTemplate = requireAuthoredChild(
		modernRoot,
		"ImageLabel",
		"FishCardTemplate"
	)
	requireAuthoredChild(cardTemplate, "ImageLabel", "FishImage")
	local fishName = requireAuthoredChild(cardTemplate, "TextLabel", "FishName")
	requireAuthoredChild(fishName, "UITextSizeConstraint", "UITextSizeConstraint")
	local rarityBadge = requireAuthoredChild(cardTemplate, "ImageLabel", "RarityBadge")
	local rarityText = requireAuthoredChild(rarityBadge, "TextLabel", "RarityText")
	requireAuthoredChild(rarityText, "UITextSizeConstraint", "UITextSizeConstraint")

	local collection = requireAuthoredChild(
		modernRoot,
		"ImageLabel",
		"CollectionPanel"
	)
	requireAuthoredChild(collection, "ImageLabel", "CheckedIcon")
	local collectionTitle = requireAuthoredChild(
		collection,
		"TextLabel",
		"CollectionTitle"
	)
	requireAuthoredChild(collectionTitle, "UITextSizeConstraint", "UITextSizeConstraint")
	local collectionCount = requireAuthoredChild(
		collection,
		"TextLabel",
		"CollectionCount"
	)
	requireAuthoredChild(collectionCount, "UITextSizeConstraint", "UITextSizeConstraint")

	local track = requireAuthoredChild(
		modernRoot,
		"Frame",
		"FishdexCustomScrollTrack"
	)
	requireAuthoredChild(track, "UICorner", "TrackCorner")
	requireAuthoredChild(track, "UIStroke", "TrackStroke")
	requireAuthoredChild(track, "UIGradient", "TrackGradient")
	local thumb = requireAuthoredChild(
		track,
		"ImageButton",
		"FishdexCustomScrollThumb"
	)
	requireAuthoredChild(thumb, "UICorner", "ThumbCorner")
	requireAuthoredChild(thumb, "UIGradient", "ThumbGradient")
	requireAuthoredChild(thumb, "UIStroke", "ThumbGlowStroke")
	local highlight = requireAuthoredChild(thumb, "Frame", "ThumbHighlight")
	requireAuthoredChild(highlight, "UICorner", "HighlightCorner")
end

local function patchModernFishdex(modernRoot)
	validateAuthoredFishdex(modernRoot)
	patchBase(modernRoot)
	patchHeader(modernRoot)
	patchCards(modernRoot)
	patchCollection(modernRoot)
	syncSelectedTabFromState(modernRoot)
	refreshTabs(modernRoot)
	hookTabs(modernRoot)

	if not modernRoot:GetAttribute("RootPatchedV5") then
		modernRoot:SetAttribute("RootPatchedV5", true)
		modernRoot.ChildAdded:Connect(function()
			task.defer(function()
				patchHeader(modernRoot)
				patchCards(modernRoot)
				patchCollection(modernRoot)
				syncSelectedTabFromState(modernRoot)
				refreshTabs(modernRoot)
				hookTabs(modernRoot)
			end)
		end)
	end
end

local modernRoot = findModernFishdex()
patchModernFishdex(modernRoot)

print("[FishdexVisualPatch_REDESIGN_v22_ShortTrackThumbFit] Loaded.")
