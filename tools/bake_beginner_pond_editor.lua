-- Run this once in Roblox Studio's Command Bar while NOT in Play/Test mode.
-- It bakes the working generated Beginner Pond into edit-mode Workspace objects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if RunService:IsRunning() then
	error("Stop Play/Test before baking the Beginner Pond into the editor map.")
end

local shared = ReplicatedStorage:FindFirstChild("Shared")
local builderModule = shared and shared:FindFirstChild("BeginnerPondBuilder")
assert(builderModule, "BeginnerPondBuilder is not synced yet. Connect Rojo/source sync first, then run this again.")

local ok, builder = pcall(require, builderModule)
assert(ok and type(builder) == "table" and type(builder.build) == "function", "Could not load BeginnerPondBuilder.")

local world = Workspace:FindFirstChild("FishyFishWorld")
if not world then
	world = Instance.new("Folder")
	world.Name = "FishyFishWorld"
	world.Parent = Workspace
end

builder.build(world, {
	position = Vector3.new(0, 8, 0),
	color = Color3.fromRGB(74, 163, 104),
})

local pond = world:FindFirstChild("BeginnerPondArea")
assert(pond, "BeginnerPondArea was not created.")

local pondFolder = pond:FindFirstChild("Pond")
local waterFolder = pondFolder and pondFolder:FindFirstChild("Water")
assert(waterFolder and #waterFolder:GetChildren() > 0, "Beginner Pond water was not created.")

print(("Beginner Pond baked into editor map with %d water parts. Save/publish the place now."):format(#waterFolder:GetChildren()))
