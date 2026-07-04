-- Run this in Roblox Studio's Command Bar to dim existing beach path lightposts
-- without moving, resizing, or recreating any lamp parts.

local Workspace = game:GetService("Workspace")

local function isInsideFishyFishWorld(instance)
	local current = instance.Parent
	while current do
		if current.Name == "FishyFishWorld" then
			return true
		end
		current = current.Parent
	end

	return false
end

local function findSavedLobbyArea()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "LobbyArea" and not isInsideFishyFishWorld(descendant) then
			return descendant
		end
	end

	local lobby = Workspace:FindFirstChild("LobbyArea", true)
	if lobby and lobby:IsA("Model") then
		return lobby
	end

	return nil
end

local lobby = findSavedLobbyArea()
if not lobby then
	warn("Beach path light dim patch: could not find LobbyArea.")
	return
end

local lightsFolder = lobby:FindFirstChild("LimestoneLobbyPathLights")
if not lightsFolder then
	warn("Beach path light dim patch: could not find LimestoneLobbyPathLights.")
	return
end

local lanternGlass = Color3.fromRGB(145, 104, 56)
local glow = Color3.fromRGB(255, 206, 120)
local lampBrightness = 0.05
local lampRange = 6
local changed = 0

for _, model in ipairs(lightsFolder:GetChildren()) do
	if model:IsA("Model") and string.sub(model.Name, 1, #"BeachPathLightPost_") == "BeachPathLightPost_" then
		local lantern = model:FindFirstChild("WarmGlassLantern", true)
		if lantern and lantern:IsA("BasePart") then
			lantern.Color = lanternGlass
			lantern.Material = Enum.Material.Glass
			lantern.Transparency = 0.32

			local pointLight = lantern:FindFirstChild("WarmBeachPathLight")
			if not pointLight then
				pointLight = Instance.new("PointLight")
				pointLight.Name = "WarmBeachPathLight"
				pointLight.Parent = lantern
			end
		end

		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("PointLight") then
				descendant.Brightness = lampBrightness
				descendant.Range = lampRange
				descendant.Color = glow
				descendant.Shadows = false
			end
		end

		changed += 1
	end
end

print(("Beach path light dim patch complete: updated %d existing lightposts without moving them."):format(changed))
