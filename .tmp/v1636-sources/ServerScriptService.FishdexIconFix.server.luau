local FISHDEX_ICON = "rbxassetid://135629767511743"

local FISHDEX_TOOL_NAMES = {
	Fishdex = true,
	FishDex = true,
	FISHDEX = true,
}

local function isFishdexTool(instance)
	return instance:IsA("Tool") and FISHDEX_TOOL_NAMES[instance.Name] == true
end

local function applyFishdexIcon(tool)
	if not isFishdexTool(tool) then
		return
	end

	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.TextureId = FISHDEX_ICON

	print("[FishdexIconFix] Applied:", tool:GetFullName(), tool.TextureId)
end

local function bindFishdexTool(tool)
	if not isFishdexTool(tool) then
		return
	end

	applyFishdexIcon(tool)

	if tool:GetAttribute("FishdexIconFixBound") then
		return
	end

	tool:SetAttribute("FishdexIconFixBound", true)

	tool:GetPropertyChangedSignal("TextureId"):Connect(function()
		if tool.TextureId ~= FISHDEX_ICON then
			warn("[FishdexIconFix] Someone changed Fishdex TextureId:", tool:GetFullName(), tool.TextureId)
			tool.TextureId = FISHDEX_ICON
		end
	end)
end

for _, instance in ipairs(game:GetDescendants()) do
	bindFishdexTool(instance)
end

game.DescendantAdded:Connect(function(instance)
	task.defer(function()
		bindFishdexTool(instance)
	end)
end)