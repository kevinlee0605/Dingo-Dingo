-- Run this in Roblox Studio's Command Bar to even out lobby lighting.
-- It changes Lighting settings, Lighting effects, and light intensity only.
-- It does not move, resize, or recreate map objects.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

Lighting.Ambient = Color3.fromRGB(118, 116, 108)
Lighting.Brightness = 1.35
Lighting.EnvironmentDiffuseScale = 0.62
Lighting.EnvironmentSpecularScale = 0.02
Lighting.ExposureCompensation = -0.18
Lighting.GlobalShadows = false
Lighting.OutdoorAmbient = Color3.fromRGB(142, 138, 125)

for _, effect in ipairs(Lighting:GetChildren()) do
	if effect:IsA("BloomEffect") then
		effect.Enabled = false
		effect.Intensity = 0.02
		effect.Size = 8
		effect.Threshold = 2.25
	elseif effect:IsA("SunRaysEffect") then
		effect.Enabled = false
		effect.Intensity = 0.02
		effect.Spread = 0.05
	end
end

local bloom = Lighting:FindFirstChild("MapBloom")
if not bloom then
	bloom = Instance.new("BloomEffect")
	bloom.Name = "MapBloom"
	bloom.Parent = Lighting
end
bloom.Enabled = false
bloom.Intensity = 0.02
bloom.Size = 8
bloom.Threshold = 2.25

local sunRays = Lighting:FindFirstChild("MapSunRays")
if not sunRays then
	sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "MapSunRays"
	sunRays.Parent = Lighting
end
sunRays.Enabled = false
sunRays.Intensity = 0.02
sunRays.Spread = 0.05

local function isBeachPathLight(light)
	local lowerName = string.lower(light.Name)
	local lowerFullName = string.lower(light:GetFullName())

	return lowerName == "warmbeachpathlight"
		or string.find(lowerFullName, "beachpathlightpost") ~= nil
		or string.find(lowerFullName, "warmglasslantern") ~= nil
end

local function shouldSoftenNeonPart(part)
	local lowerName = string.lower(part.Name)
	local lowerFullName = string.lower(part:GetFullName())

	if string.find(lowerFullName, "personalaquariums") or string.find(lowerFullName, "fishmodel") then
		return false
	end

	return string.find(lowerName, "lantern") ~= nil
		or string.find(lowerName, "light") ~= nil
		or string.find(lowerName, "lamp") ~= nil
		or string.find(lowerName, "glow") ~= nil
end

local lightCount = 0
local neonCount = 0

for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
		if isBeachPathLight(descendant) then
			descendant.Brightness = 0.05
			descendant.Range = 6
		else
			descendant.Brightness = math.min(descendant.Brightness, 0.18)
			descendant.Range = math.min(descendant.Range, 9)
		end
		descendant.Shadows = false
		lightCount += 1
	elseif descendant:IsA("BasePart") and descendant.Material == Enum.Material.Neon then
		if shouldSoftenNeonPart(descendant) then
			descendant.Material = Enum.Material.Glass
			descendant.Transparency = math.max(descendant.Transparency, 0.3)
			neonCount += 1
		end
	end
end

print(("Even lobby lighting patch complete: updated Lighting and softened %d local lights / %d neon lamp parts."):format(lightCount, neonCount))
