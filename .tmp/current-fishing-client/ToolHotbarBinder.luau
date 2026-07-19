local ToolHotbarBinder = {}

local function bindContainerTools(container, connectTool)
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		connectTool(child)
	end
	container.ChildAdded:Connect(connectTool)
end

function ToolHotbarBinder.start(deps)
	local player = deps.player
	local setTab = deps.setTab
	local hasPanel = deps.hasPanel
	local watchLegacyAquariumViewerTools = deps.watchLegacyAquariumViewerTools

	task.spawn(function()
		local connectedHudTools = {}

		local function unequipHudTool()
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:UnequipTools()
			end
		end

		local function panelExists(tabName)
			if not hasPanel then
				return true
			end

			return hasPanel(tabName)
		end

		local function connectHudTool(tool)
			if not tool:IsA("Tool") then
				return
			end

			if connectedHudTools[tool] then
				return
			end

			local tabName = nil
			local foundMessage = nil
			local equippedMessage = nil
			local openingMessage = nil
			local missingMessage = nil
			local activatedMessage = nil
			local shouldUnequipAfterOpen = false
			if tool.Name == "Bag" or tool.Name == "Backpack" then
				tabName = "Bag"
				foundMessage = "Bag tool found"
				equippedMessage = "Bag tool equipped"
				openingMessage = "Opening Bag UI"
				missingMessage = "BagPanel not found"
				activatedMessage = "Bag tool activated"
				shouldUnequipAfterOpen = true
			elseif tool.Name == "Fishdex" then
				tabName = "Fishdex"
				foundMessage = "Fishdex tool found"
				equippedMessage = "Fishdex tool equipped"
				openingMessage = "Opening Fishdex UI"
				missingMessage = "FishdexPanel not found"
				activatedMessage = "Fishdex tool activated"
				shouldUnequipAfterOpen = true
			elseif tool.Name == "Aquarium Viewer" then
				tabName = "Aquarium"
			end

			if not tabName then
				return
			end

			connectedHudTools[tool] = true
			if shouldUnequipAfterOpen then
				tool.RequiresHandle = false
				tool.CanBeDropped = false
			end
			if foundMessage then
				print(foundMessage)
			end

			local lastActivatedAt = 0
			local function activateTool(source)
				local now = os.clock()
				if now - lastActivatedAt < 0.2 then
					return
				end
				lastActivatedAt = now

				if source == "Equipped" and equippedMessage then
					print(equippedMessage)
					if tabName == "Bag" then
						print("Bag tool equipped/opening Bag UI")
					elseif tabName == "Fishdex" then
						print("Fishdex tool equipped/opening Fishdex UI")
					end
				elseif source == "Activated" and activatedMessage then
					print(activatedMessage)
				end

				if not panelExists(tabName) then
					if missingMessage then
						warn(missingMessage)
					end
					if shouldUnequipAfterOpen then
						unequipHudTool()
					end
					return
				end

				if openingMessage then
					print(openingMessage)
				end
				setTab(tabName)

				if shouldUnequipAfterOpen then
					unequipHudTool()
				end
			end

			-- Bag/Fishdex are opened from the numbered Roblox hotbar.
			-- A single slot press can fire both Equipped and Activated.
			-- Calling setTab from both events toggles the same panel twice,
			-- which is why Fishdex required another press to close.
			if tabName == "Bag" or tabName == "Fishdex" then
				tool.Equipped:Connect(function()
					activateTool("Equipped")
				end)
			else
				-- Preserve the existing behavior for other tools.
				tool.Equipped:Connect(function()
					activateTool("Equipped")
				end)
				tool.Activated:Connect(function()
					activateTool("Activated")
				end)
			end

			tool.Destroying:Connect(function()
				connectedHudTools[tool] = nil
			end)
		end

		local function bindContainer(container)
			if watchLegacyAquariumViewerTools then
				watchLegacyAquariumViewerTools(container)
			end
			bindContainerTools(container, connectHudTool)
		end

		local backpack = player:WaitForChild("Backpack", 10)
		bindContainer(backpack)
		bindContainer(player.Character)

		player.CharacterAdded:Connect(bindContainer)
	end)
end

return ToolHotbarBinder
