local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function hasButtonNamed(root: Instance, buttonText: string): boolean
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("TextButton") and descendant.Text == buttonText then
			return true
		end
	end

	return false
end

local function findOptionRow(label: TextLabel): Frame?
	local current = label.Parent

	while current and current ~= playerGui do
		if current:IsA("Frame") and hasButtonNamed(current, "Preview") and hasButtonNamed(current, "Apply") then
			local row = current.Parent

			if row and row:IsA("Frame") and row.Name == "CardRow" then
				return row
			end

			return current
		end

		current = current.Parent
	end

	return nil
end

local function removeColorDesignerSection()
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("TextLabel") and (descendant.Text:match("^Background:") or descendant.Text:match("^Light:")) then
			local row = findOptionRow(descendant)

			if row then
				row:Destroy()
			end
		elseif descendant:IsA("TextLabel") and descendant.Text == "Colors" then
			descendant:Destroy()
		elseif descendant:IsA("Frame") and descendant.Name == "CardRow" and not descendant:FindFirstChildWhichIsA("GuiObject") then
			descendant:Destroy()
		end
	end
end

removeColorDesignerSection()

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("TextLabel") and (descendant.Text == "Colors" or descendant.Text:match("^Background:") or descendant.Text:match("^Light:")) then
		task.defer(removeColorDesignerSection)
	end
end)
