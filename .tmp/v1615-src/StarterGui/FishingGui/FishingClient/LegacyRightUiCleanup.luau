local LegacyRightUiCleanup = {}

local LEGACY_RIGHT_UI_NAMES = {
	RightSideUI = true,
	RightPanel = true,
	Sidebar = true,
	MainMenu = true,
	MenuPanel = true,
}

function LegacyRightUiCleanup.create(deps)
	local scriptFullName = deps.scriptFullName
	local oldRightUiDisabledPrinted = false
	local cleanup = {}

	function cleanup.printOldRightUiDisabled()
		if not oldRightUiDisabledPrinted then
			print("Old right UI disabled")
			oldRightUiDisabledPrinted = true
		end
	end

	function cleanup.findLegacyRightUiContainer(gui)
		local oldMainPanel = gui:FindFirstChild("MainPanel", true)
		if oldMainPanel and oldMainPanel:FindFirstChild("Tabs", true) then
			return oldMainPanel
		end

		for _, descendant in ipairs(gui:GetDescendants()) do
			if LEGACY_RIGHT_UI_NAMES[descendant.Name] and descendant:IsA("GuiObject") then
				return descendant
			end
		end

		return nil
	end

	function cleanup.isLegacyRightUi(gui)
		return gui:IsA("ScreenGui") and cleanup.findLegacyRightUiContainer(gui) ~= nil
	end

	function cleanup.disableLegacyRightUi(gui)
		if not cleanup.isLegacyRightUi(gui) then
			return
		end

		local legacyRightUi = cleanup.findLegacyRightUiContainer(gui)
		if not legacyRightUi then
			return
		end

		print("ACTIVE OLD RIGHT UI SCRIPT FOUND:", scriptFullName)
		pcall(function()
			legacyRightUi.Visible = false
		end)
		legacyRightUi:Destroy()
		cleanup.printOldRightUiDisabled()
	end

	function cleanup.removeLegacyAquariumViewerTool(instance)
		if instance:IsA("Tool") and instance.Name == "Aquarium Viewer" then
			instance:Destroy()
		end
	end

	function cleanup.watchLegacyAquariumViewerTools(container)
		if not container then
			return
		end

		for _, child in ipairs(container:GetChildren()) do
			cleanup.removeLegacyAquariumViewerTool(child)
		end

		container.ChildAdded:Connect(cleanup.removeLegacyAquariumViewerTool)
	end

	return cleanup
end

return LegacyRightUiCleanup
