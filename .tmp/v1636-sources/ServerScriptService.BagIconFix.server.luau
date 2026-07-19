local BAG_ICON = "rbxassetid://75795273892452"

local BAG_TOOL_NAMES = {
	Bag = true,
	Backpack = true,
}

local function isBagTool(instance)
	return instance:IsA("Tool") and BAG_TOOL_NAMES[instance.Name] == true
end

local function applyBagIcon(tool)
	if not isBagTool(tool) then
		return
	end

	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.TextureId = BAG_ICON

	print("[BagIconFix] Applied:", tool:GetFullName(), tool.TextureId)
end

local function bindBagTool(tool)
	if not isBagTool(tool) then
		return
	end

	applyBagIcon(tool)

	if tool:GetAttribute("BagIconFixBound") then
		return
	end

	tool:SetAttribute("BagIconFixBound", true)

	tool:GetPropertyChangedSignal("TextureId"):Connect(function()
		if tool.TextureId ~= BAG_ICON then
			warn("[BagIconFix] Someone changed Bag TextureId:", tool:GetFullName(), tool.TextureId)
			tool.TextureId = BAG_ICON
		end
	end)
end

for _, instance in ipairs(game:GetDescendants()) do
	bindBagTool(instance)
end

game.DescendantAdded:Connect(function(instance)
	task.defer(function()
		bindBagTool(instance)
	end)
end)