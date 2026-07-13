-- Run once in Roblox Studio edit mode after importing all eight decor GLTF files.
-- The imported Workspace models are moved into ServerStorage templates by filename.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local TEMPLATE_FOLDER_NAME = "AquariumDecorationTemplates"
local mappings = {
	{ imported = "Coral", template = "Coral" },
	{ imported = "Seaweed", template = "Seaweed" },
	{ imported = "TreasureChest", template = "TreasureChest" },
	{ imported = "Rocks", template = "Rocks" },
	{ imported = "Shipwreck", template = "ShipwreckPiece" },
	{ imported = "BubbleMachine", template = "BubbleMachine" },
	{ imported = "Clams", template = "Clams" },
	{ imported = "Driftwood", template = "Driftwood" },
}

local function normalize(name)
	return string.lower(name):gsub("[^%w]", "")
end

local function findImportedModel(name)
	local wanted = normalize(name)
	for _, child in ipairs(Workspace:GetChildren()) do
		if (child:IsA("Model") or child:IsA("BasePart")) and normalize(child.Name) == wanted then
			return child
		end
	end

	for _, child in ipairs(Workspace:GetChildren()) do
		local rootName = normalize(child.Name)
		if child:IsA("Model") and (rootName == "scene" or string.match(rootName, "^scene%d+$")) then
			for _, descendant in ipairs(child:GetDescendants()) do
				if string.find(normalize(descendant.Name), wanted, 1, true) then
					return child
				end
			end
		end
	end
	return nil
end

local function collectParts(root)
	local parts = {}
	local largestPart = nil
	local largestVolume = -1
	if root:IsA("BasePart") then
		table.insert(parts, root)
		largestPart = root
		largestVolume = root.Size.X * root.Size.Y * root.Size.Z
	end
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

local function asModel(imported, templateName)
	if imported:IsA("Model") then
		imported.Name = templateName
		return imported
	end

	local model = Instance.new("Model")
	model.Name = templateName
	model.Parent = Workspace
	imported.Parent = model
	return model
end

local templateFolder = ServerStorage:FindFirstChild(TEMPLATE_FOLDER_NAME)
if not templateFolder then
	templateFolder = Instance.new("Folder")
	templateFolder.Name = TEMPLATE_FOLDER_NAME
	templateFolder.Parent = ServerStorage
end

local importedByTemplate = {}
for _, mapping in ipairs(mappings) do
	local imported = findImportedModel(mapping.imported)
	assert(imported, "Missing imported Workspace model: " .. mapping.imported)
	importedByTemplate[mapping.template] = imported
end

for _, mapping in ipairs(mappings) do
	local imported = importedByTemplate[mapping.template]
	local existing = templateFolder:FindFirstChild(mapping.template)
	if existing and existing ~= imported then
		existing:Destroy()
	end

	local template = asModel(imported, mapping.template)
	local parts, largestPart = collectParts(template)
	assert(#parts > 0, mapping.imported .. " contains no BasePart or MeshPart geometry")

	template.PrimaryPart = largestPart
	template:SetAttribute("DecorationTemplateId", mapping.template)
	for _, part in ipairs(parts) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = true
		part.Massless = true
	end

	template.Parent = templateFolder
	print("[AquariumDecor] Installed", mapping.imported, "as", template:GetFullName())
end

print("[AquariumDecor] Installed all eight filename-matched decoration models.")
