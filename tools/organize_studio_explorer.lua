-- Run this in Roblox Studio's Command Bar to organize Workspace Explorer.
-- It only changes Explorer hierarchy. It does not move, resize, or edit parts in 3D.

local Workspace = game:GetService("Workspace")

local ROOT_NAME = "_EditorMap"

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	if existing then
		existing.Name = name .. "_BeforeExplorerOrganize"
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local root = ensureFolder(Workspace, ROOT_NAME)
local lobbyCore = ensureFolder(root, "00_LobbyCore")
local decor = ensureFolder(root, "01_LobbyDecor")
local shops = ensureFolder(root, "02_Shops")
local bordersAndLights = ensureFolder(root, "03_BordersAndLights")
local misc = ensureFolder(root, "04_MiscMapObjects")

local keepTopLevel = {
	Camera = true,
	Terrain = true,
	Baseplate = true,
	FishyFishWorld = true,
	FishingAreas = true,
	LobbyDefinition = true,
}

local keepClassTopLevel = {
	Camera = true,
	Terrain = true,
}

local function containsAny(text, needles)
	for _, needle in ipairs(needles) do
		if string.find(text, needle) then
			return true
		end
	end

	return false
end

local function chooseFolder(instance)
	local name = instance.Name
	local lower = string.lower(name)

	if keepTopLevel[name] or keepClassTopLevel[instance.ClassName] or instance == root then
		return nil
	end

	if name == "LobbyArea"
		or name == "LobbyAquariumWarp"
		or instance:IsA("SpawnLocation")
		or containsAny(lower, {
			"fountain",
			"biomewarp",
			"lobbywarp",
			"lobbyaquarium",
		}) then
		return lobbyCore
	end

	if containsAny(lower, {
		"border",
		"boundary",
		"invisible",
		"safety",
		"pathlight",
		"lightpost",
		"lantern",
	}) then
		return bordersAndLights
	end

	if containsAny(lower, {
		"shop",
		"fishmonger",
			"rodshop",
			"seaside",
			"counter",
			"awning",
			"column",
			"deck",
			"floor",
			"roof",
			"shelf",
			"stone",
			"trim",
			"wall",
			"window",
			}) then
		return shops
	end

	if containsAny(lower, {
		"decor",
		"parasol",
		"palm",
		"tree",
		"crab",
		"turtle",
		"volleyball",
		"bucket",
		"shovel",
		"sandcastle",
		"beach",
	}) then
		return decor
	end

	if instance:IsA("Model")
		or instance:IsA("Folder")
		or instance:IsA("BasePart")
		or instance:IsA("Decal")
		or instance:IsA("Texture")
		or instance:IsA("LuaSourceContainer") then
		return misc
	end

	return nil
end

local moved = {}
for _, child in ipairs(Workspace:GetChildren()) do
	local target = chooseFolder(child)
	if target and child.Parent ~= target then
		child.Parent = target
		table.insert(moved, child.Name .. " -> " .. target.Name)
	end
end

print(("Explorer organize complete: moved %d Workspace objects into %s."):format(#moved, ROOT_NAME))
for _, line in ipairs(moved) do
	print("  " .. line)
end
