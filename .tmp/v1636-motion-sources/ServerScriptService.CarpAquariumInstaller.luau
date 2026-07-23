local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")

local Installer = {}

local TEMPLATE_FOLDER_NAME = "FishyFishModelTemplates"
local TEMPLATE_NAME = "Carp"
local IMPORTED_NAME = "Carp_New"
local DEFAULT_YAW_DEGREES = 90

local function getTemplateFolder()
	local folder = ServerStorage:FindFirstChild(TEMPLATE_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = TEMPLATE_FOLDER_NAME
		folder.Parent = ServerStorage
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

local function printHierarchy(root)
	print("[CarpAquarium] hierarchy inside " .. root:GetFullName())
	local function visit(instance, depth)
		local details = ""
		if instance:IsA("MeshPart") then
			details = " MeshId=" .. instance.MeshId .. " TextureID=" .. instance.TextureID
		end
		print(string.rep("  ", depth) .. "- " .. instance.Name .. " [" .. instance.ClassName .. "]" .. details)
		for _, child in ipairs(instance:GetChildren()) do
			visit(child, depth + 1)
		end
	end
	visit(root, 0)
end

local function isShopCarpReference(instance)
	local path = string.lower(instance:GetFullName())
	if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		return string.find(path, "carp", 1, true) ~= nil
			or string.find(instance.Image, "85530716090863", 1, true) ~= nil
	end
	return instance:IsA("ViewportFrame") and string.find(path, "carp", 1, true) ~= nil
end

local function captureShopReferences()
	local references = {}
	for _, root in ipairs({ StarterGui, ReplicatedStorage, Workspace }) do
		for _, descendant in ipairs(root:GetDescendants()) do
			if isShopCarpReference(descendant) then
				local value = if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton")
					then descendant.Image
					else "ViewportFrame"
				table.insert(references, descendant:GetFullName() .. "|" .. descendant.ClassName .. "|" .. value)
			end
		end
	end
	table.sort(references)
	return references
end

local function printShopReferences(references)
	print("[CarpAquarium] Seaside Shop Carp image/icon references (read-only):")
	if #references == 0 then
		print("  No live Carp-named ImageLabel/ImageButton/ViewportFrame instances found in Edit mode.")
	end
	for _, reference in ipairs(references) do
		print("  " .. reference)
	end
	print("  Source image asset: ReplicatedStorage.Shared.GameConfig.FishImageAssets.Carp = rbxassetid://85530716090863")
	print("  Source icon path: ReplicatedStorage.Shared.GameConfig.FishImageFiles.Carp = assets/fish_icons/Carp.png")
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

local function prepareTemplate(model)
	model.Name = TEMPLATE_NAME
	model:SetAttribute("FishTemplateId", TEMPLATE_NAME)
	model:SetAttribute("AquariumOnlyTemplate", true)
	if model:GetAttribute("FishVisualYawDegrees") == nil then
		model:SetAttribute("FishVisualYawDegrees", DEFAULT_YAW_DEGREES)
	end

	local parts, largestPart = collectParts(model)
	assert(#parts > 0, "Workspace.Carp_New contains no BasePart or MeshPart descendants.")
	model.PrimaryPart = largestPart or parts[1]

	for _, part in ipairs(parts) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = true
		part.Massless = true
	end

	local boundsCFrame = select(1, model:GetBoundingBox())
	model.PrimaryPart.PivotOffset = model.PrimaryPart.CFrame:ToObjectSpace(boundsCFrame)

	for _, part in ipairs(parts) do
		if part ~= model.PrimaryPart then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "CarpAquariumTemplateWeld"
			weld.Part0 = model.PrimaryPart
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

local function removeRuntimeClones()
	local removed = {}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "AquariumFish_Carp" then
			table.insert(removed, descendant:GetFullName())
			descendant:Destroy()
		end
	end
	return removed
end

function Installer.inspect()
	local folder = ServerStorage:FindFirstChild(TEMPLATE_FOLDER_NAME)
	local oldTemplate = folder and folder:FindFirstChild(TEMPLATE_NAME)
	local imported = Workspace:FindFirstChild(IMPORTED_NAME)

	print("[CarpAquarium] exact aquarium Carp template path:", oldTemplate and oldTemplate:GetFullName() or "none; FishingServer procedural fallback")
	print("[CarpAquarium] exact runtime clone source:", "ServerStorage." .. TEMPLATE_FOLDER_NAME .. "." .. TEMPLATE_NAME)
	printShopReferences(captureShopReferences())
	assert(imported and imported:IsA("Model"), "Expected the existing Workspace.Carp_New Model.")
	printHierarchy(imported)
	return true
end

function Installer.install()
	local imported = Workspace:FindFirstChild(IMPORTED_NAME)
	assert(imported and imported:IsA("Model"), "Expected the existing Workspace.Carp_New Model.")
	local shopBefore = captureShopReferences()
	local folder = getTemplateFolder()
	local template = folder:FindFirstChild(TEMPLATE_NAME)

	if template and template:IsA("Model") then
		clearOldVisualGeometry(template)
	else
		if template then
			template:Destroy()
		end
		template = Instance.new("Model")
		template.Name = TEMPLATE_NAME
		template.Parent = folder
	end

	for _, tag in ipairs(CollectionService:GetTags(imported)) do
		CollectionService:AddTag(template, tag)
	end
	for attributeName, attributeValue in pairs(imported:GetAttributes()) do
		if string.sub(attributeName, 1, 3) == "RBX" then
			print("[CarpAquarium] skipped protected import attribute:", attributeName)
		else
			local copied = pcall(function()
				template:SetAttribute(attributeName, attributeValue)
			end)
			if not copied then
				print("[CarpAquarium] skipped unwritable import attribute:", attributeName)
			end
		end
	end

	local children = imported:GetChildren()
	assert(#children > 0, "Workspace.Carp_New has no visual children to install.")
	for _, child in ipairs(children) do
		child.Parent = template
	end

	prepareTemplate(template)
	template.Parent = folder
	template:PivotTo(CFrame.new(0, -1000, 0))
	local removedClones = removeRuntimeClones()
	imported:Destroy()

	local shopAfter = captureShopReferences()
	assert(#shopBefore == #shopAfter, "A shop Carp image/icon reference count changed during installation.")
	for index, reference in ipairs(shopBefore) do
		assert(shopAfter[index] == reference, "A shop Carp image/icon reference changed during installation: " .. reference)
	end

	print("[CarpAquarium] final aquarium Carp template path:", template:GetFullName())
	print("[CarpAquarium] runtime clone source remains:", "ServerStorage." .. TEMPLATE_FOLDER_NAME .. "." .. TEMPLATE_NAME)
	print("[CarpAquarium] old aquarium Carp clones regenerated on next aquarium render; removed now:", #removedClones)
	for _, path in ipairs(removedClones) do
		print("  " .. path)
	end
	print("[CarpAquarium] Workspace.Carp_New removed after safe transfer.")
	print("[CarpAquarium] VERIFIED: no Seaside Shop Carp image/icon property changed.")
	return template:GetFullName(), #removedClones
end

function Installer.verifyRuntime()
	local folder = ServerStorage:FindFirstChild(TEMPLATE_FOLDER_NAME)
	local template = folder and folder:FindFirstChild(TEMPLATE_NAME)
	assert(template and template:IsA("Model"), "Aquarium Carp template is missing.")
	local templateParts = collectParts(template)
	assert(#templateParts > 0, "Aquarium Carp template has no visual parts.")

	local clones = {}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "AquariumFish_Carp" then
			table.insert(clones, descendant)
		end
	end
	print("[CarpAquarium] runtime AquariumFish_Carp clones:", #clones)
	for _, clone in ipairs(clones) do
		local visual = clone:FindFirstChild("FishVisual")
		local parts = visual and collectParts(visual) or {}
		print("  ", clone:GetFullName(), "FishVisual=", visual ~= nil, "parts=", #parts)
	end
	printShopReferences(captureShopReferences())
	return #clones
end

return Installer
