-- Run this once in Roblox Studio's Command Bar while Workspace.Bass_New exists.
-- It uses the already-imported Studio instance and does not import another asset.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local TEMPLATE_FOLDER_NAME = "FishyFishModelTemplates"
local TEMPLATE_NAME = "Bass"
local IMPORTED_NAME = "Bass_New"
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

local function collectParts(root)
	local parts = {}
	local largestPart = nil
	local largestVolume = 0
	for _, descendant in ipairs(root:GetDescendants()) do
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

local function printMeshIds(label, root)
	local found = false
	print("[BassReplace] " .. label)
	if root then
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("MeshPart") then
				found = true
				print("  ", descendant:GetFullName(), descendant.MeshId)
			elseif descendant:IsA("SpecialMesh") then
				found = true
				print("  ", descendant:GetFullName(), descendant.MeshId)
			end
		end
	end
	if not found then
		print("  none")
	end
end

local function printHierarchy(root)
	print("[BassReplace] hierarchy inside " .. root:GetFullName())
	local function visit(instance, depth)
		print(string.rep("  ", depth) .. "- " .. instance.Name .. " [" .. instance.ClassName .. "]")
		for _, child in ipairs(instance:GetChildren()) do
			visit(child, depth + 1)
		end
	end
	visit(root, 0)
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
	assert(#parts > 0, "Bass_New contains no BasePart or MeshPart descendants.")
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
			weld.Name = "BassTemplateWeld"
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

local function removeOldBassClones()
	local removed = {}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "AquariumFish_Bass" then
			table.insert(removed, descendant:GetFullName())
			descendant:Destroy()
		end
	end
	return removed
end

local imported = Workspace:FindFirstChild(IMPORTED_NAME)
assert(imported and imported:IsA("Model"), "Expected the existing Workspace.Bass_New Model.")

local serverFolder = getTemplateFolder(ServerStorage)
local oldTemplate = serverFolder:FindFirstChild(TEMPLATE_NAME)

print("[BassReplace] exact old Bass template path:", oldTemplate and oldTemplate:GetFullName() or "none; aquarium used FishingServer procedural fallback")
print("[BassReplace] aquarium runtime source path:", "ServerStorage." .. TEMPLATE_FOLDER_NAME .. "." .. TEMPLATE_NAME)
printHierarchy(imported)
printMeshIds("old Bass MeshId or MeshIds:", oldTemplate)
printMeshIds("new imported Bass MeshId or MeshIds:", imported)

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
assert(#importedChildren > 0, "Workspace.Bass_New has no visual children to install.")
for _, child in ipairs(importedChildren) do
	child.Parent = template
end

prepareTemplateModel(template)
template.Parent = serverFolder
template:PivotTo(CFrame.new(0, -1000, 0))

local clientTemplate = mirrorToReplicatedStorage(template)
local removedClones = removeOldBassClones()
imported:Destroy()

print("[BassReplace] final Bass template path:", template:GetFullName())
print("[BassReplace] client preview template path:", clientTemplate:GetFullName())
printMeshIds("final Bass MeshId or MeshIds:", template)
print("[BassReplace] duplicate old aquarium Bass models removed:", #removedClones)
for _, path in ipairs(removedClones) do
	print("  ", path)
end
print("[BassReplace] Workspace.Bass_New removed after its contents were safely installed.")
print("[BassReplace] Refresh the aquarium to regenerate Bass clones from the new template.")
