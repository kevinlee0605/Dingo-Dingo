local PlayerGuiDebug = {}

local function getGuiVisibleState(instance)
	if instance:IsA("ScreenGui") then
		return instance.Enabled
	elseif instance:IsA("GuiObject") then
		return instance.Visible
	end

	return "n/a"
end

function PlayerGuiDebug.create(deps)
	local playerGui = deps.playerGui
	local screenGui = deps.screenGui

	local debugTools = {}

	function debugTools.printPlayerGuiChildren()
		for _, child in ipairs(playerGui:GetChildren()) do
			print("PlayerGui child:", child.Name, child.ClassName, getGuiVisibleState(child))
		end
	end

	function debugTools.printFishingGuiChildren()
		for _, child in ipairs(screenGui:GetChildren()) do
			print("FishingGui child:", child.Name, child.ClassName, getGuiVisibleState(child))
		end

		for _, descendant in ipairs(screenGui:GetDescendants()) do
			if descendant.Name == "CoinsHud"
				or descendant.Name == "FishingXPBar"
				or descendant.Name == "TopButtonsFrame"
				or descendant.Name == "SettingsButton"
				or descendant.Name == "QuestsButton"
				or descendant.Name == "ShopButton"
				or descendant.Name == "AutoFishButton"
				or descendant.Name == "TapButton"
			then
				print("FishingGui HUD descendant:", descendant.Name, descendant.ClassName, getGuiVisibleState(descendant))
			end
		end
	end

	function debugTools.printPlayerGuiScreenGuis(context)
		local names = {}
		for _, child in ipairs(playerGui:GetChildren()) do
			if child:IsA("ScreenGui") then
				table.insert(names, child.Name .. " [" .. child:GetFullName() .. "]")
			end
		end
		table.sort(names)
		print("PlayerGui ScreenGui children after spawn:", context, #names > 0 and table.concat(names, ", ") or "(none)")
	end

	return debugTools
end

return PlayerGuiDebug
