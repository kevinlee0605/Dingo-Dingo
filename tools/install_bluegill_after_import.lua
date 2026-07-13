-- Run this in Roblox Studio's Command Bar after importing the new model as:
-- Workspace.Bluegill_New
--
-- This uses the already-imported Studio instance. It does not re-import anything.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local TEMPLATE_FOLDER_NAME = "FishyFishModelTemplates"
local TEMPLATE_NAME = "Bluegill"
local IMPORTED_NAME = "Bluegill_New"
local DEFAULT_YAW_DEGREES = 90

local function getTemplateFolder(parent)
	local folder = parent:FindFirstChild(TEMPLATE_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = TEMPLATE_FOLDER_NAME
		folder.Parent = parent
	end
	return folder
end

local function printHierarchy(root)
	print("[FishyFish] Hierarchy inside " .. root:GetFullName() .. ":")
	local function visit(instance, depth)
		local indent = string.rep("  ", depth)
		print(indent .. "- " .. instance.Name .. " [" .. instance.ClassName .. "]")
		for _, child in ipairs(instance:GetChildren()) do
			visit(child, depth + 1)
		end
	end
	visit(root, 0)
end

local function collectParts(model)
	local parts = {}
	local largestPart = nil
	local largestVolume = 0

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > largestVolume then
				largestVolume = volume
				largestPart = descendant
			end
		end
	end

	return parts, largestPart
end

local function clearOldVisualGeometry(container)
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("WeldConstraint") or descendant:IsA("Motor6D") then
			descendant:Destroy()
		end
	end

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant:Destroy()
		end
	end

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("Model") and #descendant:GetChildren() == 0 then
			descendant:Destroy()
		end
	end
end

local function prepareTemplateModel(model)
	model.Name = TEMPLATE_NAME
	model:SetAttribute("FishTemplateId", TEMPLATE_NAME)
	if model:GetAttribute("FishVisualYawDegrees") == nil then
		model:SetAttribute("FishVisualYawDegrees", DEFAULT_YAW_DEGREES)
	end

	local parts, mainBody = collectParts(model)
	assert(#parts > 0, "Bluegill template has no BasePart or MeshPart descendants.")

	model.PrimaryPart = mainBody or parts[1]

	for _, part in ipairs(parts) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = true
		part.Massless = true
	end

	for _, part in ipairs(parts) do
		if part ~= model.PrimaryPart then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "BluegillTemplateWeld"
			weld.Part0 = model.PrimaryPart
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

local function mirrorToReplicatedStorage(serverTemplate)
	local clientFolder = getTemplateFolder(ReplicatedStorage)
	local oldClientTemplate = clientFolder:FindFirstChild(TEMPLATE_NAME)
	if oldClientTemplate then
		oldClientTemplate:Destroy()
	end

	local clientTemplate = serverTemplate:Clone()
	clientTemplate.Name = TEMPLATE_NAME
	clientTemplate.Parent = clientFolder
	prepareTemplateModel(clientTemplate)
	return clientTemplate
end

local function removeExistingRuntimeBluegillClones()
	local removed = 0
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "AquariumFish_Bluegill" then
			descendant:Destroy()
			removed += 1
		end
	end
	return removed
end

local imported = Workspace:FindFirstChild(IMPORTED_NAME)
assert(imported and imported:IsA("Model"), "Expected Workspace.Bluegill_New to be an imported Model.")

local serverFolder = getTemplateFolder(ServerStorage)
local oldTemplate = serverFolder:FindFirstChild(TEMPLATE_NAME)

print("[FishyFish] Old Bluegill template path:", oldTemplate and oldTemplate:GetFullName() or "none; runtime was using procedural fallback in FishingServer.makeAquariumFish/buildAquariumFishModel")
print("[FishyFish] Aquarium runtime source path:", "ServerStorage." .. TEMPLATE_FOLDER_NAME .. "." .. TEMPLATE_NAME)
printHierarchy(imported)

local template = oldTemplate
if template and template:IsA("Model") then
	clearOldVisualGeometry(template)
else
	if template then
		template:Destroy()
	end
	template = Instance.new("Model")
	template.Name = TEMPLATE_NAME
	template.Parent = serverFolder
end

for _, tag in ipairs(CollectionService:GetTags(imported)) do
	CollectionService:AddTag(template, tag)
end

for attributeName, attributeValue in pairs(imported:GetAttributes()) do
	template:SetAttribute(attributeName, attributeValue)
end

local importedChildren = imported:GetChildren()
if #importedChildren == 0 then
	error("Workspace.Bluegill_New has no children to install.")
end

for _, child in ipairs(importedChildren) do
	child.Parent = template
end

prepareTemplateModel(template)
template.Parent = serverFolder
template:PivotTo(CFrame.new(0, -1000, 0))

local clientTemplate = mirrorToReplicatedStorage(template)
local removedRuntimeClones = removeExistingRuntimeBluegillClones()

imported:Destroy()

print("[FishyFish] Final Bluegill template path:", template:GetFullName())
print("[FishyFish] Client preview template path:", clientTemplate:GetFullName())
print("[FishyFish] Removed old aquarium Bluegill runtime clones:", removedRuntimeClones)
print("[FishyFish] Bluegill_New was safely removed after its contents were installed.")
print("[FishyFish] Press Play or refresh/reopen the aquarium view to regenerate Bluegill with the new voxel model.")
