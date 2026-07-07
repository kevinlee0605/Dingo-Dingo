-- Run this in Roblox Studio's Command Bar after importing WoodenRod_split.gltf.
-- It names/groups the imported split model so Fishy Fish uses it for Wooden Rod.

local Workspace = game:GetService("Workspace")

local function getModelsFolder()
	local folder = Workspace:FindFirstChild("Models")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Models"
		folder.Parent = Workspace
	end
	return folder
end

local function hasSplitRodParts(model)
	return model:FindFirstChild("Rod_Body", true)
		and model:FindFirstChild("Rod_Bobber", true)
		and model:FindFirstChild("Rod_String", true)
end

local function findImportedRod()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and (descendant.Name == "WoodenRod_split" or hasSplitRodParts(descendant)) then
			return descendant
		end
	end

	local body = Workspace:FindFirstChild("Rod_Body", true)
	local bobber = Workspace:FindFirstChild("Rod_Bobber", true)
	local stringPart = Workspace:FindFirstChild("Rod_String", true)
	if body and bobber and stringPart then
		local model = Instance.new("Model")
		model.Name = "WoodenRod_split"
		model.Parent = Workspace

		local function moveTopObject(instance)
			local current = instance
			while current.Parent and current.Parent ~= Workspace do
				current = current.Parent
			end
			current.Parent = model
		end

		moveTopObject(body)
		moveTopObject(bobber)
		moveTopObject(stringPart)
		return model
	end

	return nil
end

local rod = findImportedRod()
assert(rod, "Could not find imported Rod_Body, Rod_Bobber, and Rod_String. Import WoodenRod_split.gltf first.")

rod.Name = "WoodenRod_split"
rod.Parent = getModelsFolder()

for _, descendant in ipairs(rod:GetDescendants()) do
	if descendant:IsA("BasePart") then
		descendant.Anchored = true
		descendant.CanCollide = false
		descendant.CanTouch = false
		descendant.CanQuery = true
		descendant.Massless = true
	end
end

print("WoodenRod_split installed in Workspace.Models. Save the place, then Play/Test to see it on the Wooden Rod.")
