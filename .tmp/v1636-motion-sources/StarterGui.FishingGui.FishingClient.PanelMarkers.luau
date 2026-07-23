local PanelMarkers = {}

function PanelMarkers.setup(screenGui)
	local openPanelEvent = screenGui:FindFirstChild("OpenFishingPanel")
	if not openPanelEvent then
		openPanelEvent = Instance.new("BindableEvent")
		openPanelEvent.Name = "OpenFishingPanel"
		openPanelEvent.Parent = screenGui
	end

	local panelsFolder = screenGui:FindFirstChild("Panels")
	if not panelsFolder then
		panelsFolder = Instance.new("Folder")
		panelsFolder.Name = "Panels"
		panelsFolder.Parent = screenGui
	end

	local function ensurePanelMarker(panelName)
		local panel = panelsFolder:FindFirstChild(panelName)
		if not panel then
			panel = Instance.new("Frame")
			panel.Name = panelName
			panel.BackgroundTransparency = 1
			panel.Size = UDim2.fromScale(1, 1)
			panel.Visible = false
			panel.Parent = panelsFolder
		end

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
