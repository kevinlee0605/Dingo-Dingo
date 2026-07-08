local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TEMPLATE_FOLDER_NAME = "FishyFishModelTemplates"

local function normalize(name)
	return string.lower(tostring(name or "")):gsub("[%s_%-]", "")
end

local function isWoodenSplit2(instance)
	return instance:IsA("Model") and normalize(instance.Name) == "woodenrodsplit2"
end

local function isOldWoodenRod(instance)
	if not (instance:IsA("Model") or instance:IsA("BasePart")) then
		return false
	end

	local normalized = normalize(instance.Name)
	return normalized == "woodenrod"
		or normalized == "woodenrodmk411"
		or normalized == "woodenrodmk4"
		or normalized == "woodenrodmk3"
		or normalized == "woodenrodsplit"
		or normalized == "wooden"
		or normalized == "woodenrodold"
end

local function findWoodenSplit2()
	for _, container in ipairs({ Workspace, ReplicatedStorage, ServerStorage }) do
		for _, descendant in ipairs(container:GetDescendants()) do
			if isWoodenSplit2(descendant) then
				return descendant
			end
		end
	end

	return nil
end

local function makeTemplateFolder()
	local folder = ServerStorage:FindFirstChild(TEMPLATE_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = TEMPLATE_FOLDER_NAME
		folder.Parent = ServerStorage
	end

	return folder
end

local split = findWoodenSplit2()
assert(split, "Could not find a Model named WoodenRod_Split2 in Workspace, ReplicatedStorage, or ServerStorage.")

local folder = makeTemplateFolder()
local existingTemplate = folder:FindFirstChild("WoodenRod")
if existingTemplate and existingTemplate ~= split then
	existingTemplate:Destroy()
end

local template = split:Clone()
template.Name = "WoodenRod"
template:SetAttribute("TemplatePriority", 100)
template.Parent = folder
template:PivotTo(CFrame.new(0, -1000, 0))

for _, descendant in ipairs(template:GetDescendants()) do
	if descendant:IsA("BasePart") then
		descendant.Anchored = true
		descendant.CanCollide = false
		descendant.CanTouch = false
		descendant.CanQuery = false
		descendant.Massless = true
		descendant.Transparency = 1
	end
end

for _, container in ipairs({ Workspace, ReplicatedStorage }) do
	for _, child in ipairs(container:GetDescendants()) do
		if child ~= split and isOldWoodenRod(child) then
			child:Destroy()
		end
	end
end

print("[FishyFish] Replaced old Wooden Rod template with WoodenRod_Split2.")
