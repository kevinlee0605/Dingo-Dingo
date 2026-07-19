local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local EarlyModelMigrationService = {}

local EARLY_ROD_TEMPLATE_FOLDER_NAME = "FishyFishModelTemplates"
local function normalizeEarlyRodName(name)
	return string.lower(name):gsub("[%s_%-]", "")
end

local function shouldStoreEarlyRodModel(name)
	local normalized = normalizeEarlyRodName(name)
	return normalized == "woodenrodmk411"
		or normalized == "bluegillnew"
		or normalized == "bassnew"
		or normalized == "woodenrodsplit"
		or normalized == "woodenrodsplit2"
		or normalized == "woodenrodmk4"
		or normalized == "woodenrodmk3"
		or normalized == "woodenrod"
		or normalized == "wooden"
		or normalized == "ironrodsplit"
		or normalized == "ironrodsplit2"
		or normalized == "ironrod11"
		or normalized == "ironrod"
		or normalized == "iron"
		or normalized == "emeraldrodsplit"
		or normalized == "emeraldrodsplit2"
		or normalized == "emeraldrod11"
		or normalized == "emeraldrod"
		or normalized == "emerald"
		or normalized == "goldenrodsplit"
		or normalized == "goldenrodsplit2"
		or normalized == "goldenrod11"
		or normalized == "goldenrod"
		or normalized == "goldrod"
		or normalized == "golden"
		or normalized == "oceanrodsplit"
		or normalized == "oceanrodsplit2"
		or normalized == "oceanrod11"
		or normalized == "oceanrod"
		or normalized == "ocean"
end

local function isImportedSplitRodModel(instance)
	if not instance:IsA("Model") then
		return false
	end

	local normalized = normalizeEarlyRodName(instance.Name)
	if normalized == "woodenrodsplit2" then
		return true
	end

	if normalized == "goldenrodsplit" or normalized == "goldenrodsplit2" then
		return true
	end

	if normalized == "emeraldrodsplit" or normalized == "emeraldrodsplit2" then
		return true
	end

	if normalized == "oceanrodsplit" or normalized == "oceanrodsplit2" then
		return true
	end

	return instance:FindFirstChild("Rod_Body", true) ~= nil
		and instance:FindFirstChild("Rod_Bobber", true) ~= nil
		and instance:FindFirstChild("Rod_String", true) ~= nil
end

function EarlyModelMigrationService.getImportedSplitRodTemplateName(instance)
	local normalized = normalizeEarlyRodName(instance.Name)
	if instance:IsA("Model") or instance:IsA("BasePart") then
		if normalized == "bluegillnew" then
			return "Bluegill"
		elseif normalized == "bassnew" then
			return "Bass"
		end
	end

	if not isImportedSplitRodModel(instance) then
		return nil
	end

	if normalized == "ironrodsplit" or normalized == "ironrodsplit2" then
		return "IronRod_Split"
	end

	if normalized == "goldenrodsplit" or normalized == "goldenrodsplit2" then
		return "GoldenRod_Split"
	end

	if normalized == "emeraldrodsplit" or normalized == "emeraldrodsplit2" then
		return "EmeraldRod_Split"
	end

	if normalized == "oceanrodsplit" or normalized == "oceanrodsplit2" then
		return "OceanRod_Split"
	end

	if normalized == "woodenrodsplit2" then
		return "WoodenRod_Split2"
	end

	if normalized == "woodenrodsplit" or normalized == "scene" then
		return "WoodenRod_split"
	end

	return nil
end

local function disablePhysicsForSourceModel(instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.Massless = true
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end
end

local function removeWorkspaceModelsFolder()
	local models = workspace:FindFirstChild("Models")
	local storage = ServerStorage:FindFirstChild(EARLY_ROD_TEMPLATE_FOLDER_NAME)
	if not storage then
		storage = Instance.new("Folder")
		storage.Name = EARLY_ROD_TEMPLATE_FOLDER_NAME
		storage.Parent = ServerStorage
	end

	local moved = {}
	local function moveRodSource(instance)
		if moved[instance] then
			return
		end

		local splitTemplateName = EarlyModelMigrationService.getImportedSplitRodTemplateName(instance)
		if not shouldStoreEarlyRodModel(instance.Name) and not splitTemplateName then
			return
		end

		if instance:IsA("Model") or instance:IsA("BasePart") then
			moved[instance] = true
			local fishTemplateName = if splitTemplateName == "Bluegill" or splitTemplateName == "Bass"
				then splitTemplateName
				else nil
			if splitTemplateName then
				instance.Name = splitTemplateName
			end
			if fishTemplateName then
				local existingFishTemplate = storage:FindFirstChild(fishTemplateName)
				if existingFishTemplate and existingFishTemplate ~= instance then
					existingFishTemplate:Destroy()
				end
				instance:SetAttribute("FishTemplateId", fishTemplateName)
				if instance:GetAttribute("FishVisualYawDegrees") == nil then
					instance:SetAttribute("FishVisualYawDegrees", 90)
				end
			end
			disablePhysicsForSourceModel(instance)
			instance.Parent = storage
			if fishTemplateName then
				local clientFolder = ReplicatedStorage:FindFirstChild(EARLY_ROD_TEMPLATE_FOLDER_NAME)
				if not clientFolder then
					clientFolder = Instance.new("Folder")
					clientFolder.Name = EARLY_ROD_TEMPLATE_FOLDER_NAME
					clientFolder.Parent = ReplicatedStorage
				end

				local existingClientFishTemplate = clientFolder:FindFirstChild(fishTemplateName)
				if existingClientFishTemplate then
					existingClientFishTemplate:Destroy()
				end

				local clientFishTemplate = instance:Clone()
				clientFishTemplate.Name = fishTemplateName
				clientFishTemplate.Parent = clientFolder
				disablePhysicsForSourceModel(clientFishTemplate)

				for _, descendant in ipairs(workspace:GetDescendants()) do
					if descendant:IsA("Model") and descendant.Name == "AquariumFish_" .. fishTemplateName then
						descendant:Destroy()
					end
				end

				print("[FishyFish] " .. fishTemplateName .. " template source:", instance:GetFullName())
				print("[FishyFish] Aquarium runtime source path:", "ServerStorage." .. EARLY_ROD_TEMPLATE_FOLDER_NAME .. "." .. fishTemplateName)
			end
		end
	end

	if models then
		for _, child in ipairs(models:GetChildren()) do
			moveRodSource(child)
		end
	end

	for _, child in ipairs(workspace:GetChildren()) do
		if child ~= models then
			moveRodSource(child)
		end
	end
end

function EarlyModelMigrationService.start()
	removeWorkspaceModelsFolder()
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Models" then
			task.defer(removeWorkspaceModelsFolder)
		end
	end)
	
end

return EarlyModelMigrationService
