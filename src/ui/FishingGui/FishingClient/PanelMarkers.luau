local PanelMarkers = {}

function PanelMarkers.setup(screenGui)
	local openPanelEvent = screenGui:WaitForChild("OpenFishingPanel")
	assert(openPanelEvent:IsA("BindableEvent"), "FishingGui.OpenFishingPanel must be an authored BindableEvent")

	local panelsFolder = screenGui:WaitForChild("Panels")
	assert(panelsFolder:IsA("Folder"), "FishingGui.Panels must be an authored Folder")

	local function ensurePanelMarker(panelName)
		local panel = panelsFolder:FindFirstChild(panelName)
		assert(panel and panel:IsA("Frame"), string.format(
			"FishingGui.Panels.%s must be an authored Frame",
			panelName
		))
		return panel
	end

	ensurePanelMarker("BagPanel")
	ensurePanelMarker("FishdexPanel")

	return {
		openPanelEvent = openPanelEvent,
		panelsFolder = panelsFolder,
		ensurePanelMarker = ensurePanelMarker,
	}
end

return PanelMarkers
