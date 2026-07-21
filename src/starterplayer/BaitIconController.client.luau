local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local fishingGui = playerGui:WaitForChild("FishingGui")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local baitIconTemplates = fishingGui:WaitForChild("BaitIconTemplates")
local baitIconTemplate = baitIconTemplates:WaitForChild("BaitIconTemplate")

if not baitIconTemplate:IsA("ImageLabel") then
	error("[BaitIconController] FishingGui.BaitIconTemplates.BaitIconTemplate must be an ImageLabel")
end

local BAIT_IMAGE_SCALES = {
	FreshBait = 1.55,
	TastyBait = 1.50,
}

local function getImageContent(baitId)
	return GameConfig.getBaitImage(baitId)
end

local function scaleUDim2(value, scale)
	return UDim2.new(
		value.X.Scale * scale,
		value.X.Offset * scale,
		value.Y.Scale * scale,
		value.Y.Offset * scale
	)
end

local function applyImagePresentation(image, baitId, size, position)
	local visualScale = BAIT_IMAGE_SCALES[baitId] or 1
	image.ImageRectOffset = Vector2.zero
	image.ImageRectSize = Vector2.zero
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = position + UDim2.new(size.X.Scale * 0.5, size.X.Offset * 0.5, size.Y.Scale * 0.5, size.Y.Offset * 0.5)
	image.Size = scaleUDim2(size, visualScale)
end

local function addImage(parent, baitId, size, position)
	local imageContent = getImageContent(baitId)
	if not imageContent or imageContent == "" then
		return false
	end

	local existing = parent:FindFirstChild("BaitIcon")
	if existing and existing:IsA("ImageLabel") then
		existing.Image = imageContent
		applyImagePresentation(existing, baitId, size, position)
		return true
	end

	local image = baitIconTemplate:Clone()
	image.Name = "BaitIcon"
	image.Image = imageContent
	applyImagePresentation(image, baitId, size, position)
	image.Visible = true
	image.Parent = parent
	task.spawn(function()
		ContentProvider:PreloadAsync({ image }, function(contentId, status)
			if status ~= Enum.AssetFetchStatus.Success then
				warn("[BaitIconController] Failed to load", baitId, contentId, status)
			end
		end)
	end)
	return true
end

local function decorateShopCard(card, baitId)
	if card:GetAttribute("BaitIconDecorated") then
		return
	end
	if not addImage(card, baitId, UDim2.fromOffset(68, 68), UDim2.fromOffset(10, 18)) then
		return
	end
	card:SetAttribute("BaitIconDecorated", true)
	for _, child in ipairs(card:GetChildren()) do
		if child:IsA("TextLabel") and child.Position.X.Offset == 12 then
			child.Position = UDim2.new(child.Position.X.Scale, 90, child.Position.Y.Scale, child.Position.Y.Offset)
			child.Size = UDim2.new(child.Size.X.Scale, child.Size.X.Offset - 78, child.Size.Y.Scale, child.Size.Y.Offset)
		end
	end
end

local function decorateBagCard(card, baitId)
	if card:GetAttribute("BaitIconDecorated") then
		return
	end

	local badge = nil
	for _, child in ipairs(card:GetChildren()) do
		if child:IsA("Frame") and child.Position.X.Offset == 10 and child.Size.X.Offset == 56 then
			badge = child
			break
		end
	end

	if badge then
		if not addImage(badge, baitId, UDim2.new(1, -4, 1, -4), UDim2.fromOffset(2, 2)) then
			return
		end
		for _, child in ipairs(badge:GetChildren()) do
			if child:IsA("TextLabel") then
				child.Visible = false
			end
		end
	else
		if not addImage(card, baitId, UDim2.fromOffset(56, 56), UDim2.fromOffset(10, 18)) then
			return
		end
		for _, child in ipairs(card:GetChildren()) do
			if child:IsA("TextLabel") and child.Position.X.Offset <= 16 then
				child.Position = UDim2.new(child.Position.X.Scale, 78, child.Position.Y.Scale, child.Position.Y.Offset)
				child.Size = UDim2.new(child.Size.X.Scale, child.Size.X.Offset - 66, child.Size.Y.Scale, child.Size.Y.Offset)
			end
		end
	end
	card:SetAttribute("BaitIconDecorated", true)
end

local function decorateBaitCards()
	for _, baitId in ipairs(GameConfig.BaitOrder) do
		local bait = GameConfig.Baits[baitId]
		local shopCard = fishingGui:FindFirstChild(baitId .. "ShopOption", true)
		if shopCard and shopCard:IsA("GuiObject") then
			decorateShopCard(shopCard, baitId)
		end

		for _, descendant in ipairs(fishingGui:GetDescendants()) do
			if descendant:IsA("TextLabel") and descendant.Text == bait.displayName then
				local card = descendant.Parent
				if card and card:IsA("GuiObject")
					and card.Name ~= baitId .. "ShopOption"
					and not card:FindFirstAncestor("ModernSupplyShop")
				then
					decorateBagCard(card, baitId)
				end
			end
		end
	end
end

local refreshQueued = false
local function queueRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		decorateBaitCards()
	end)
end

fishingGui.DescendantAdded:Connect(queueRefresh)
queueRefresh()
