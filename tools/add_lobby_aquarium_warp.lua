-- Run once in Roblox Studio's Command Bar while editing the place.
-- Creates/updates only Workspace.LobbyAquariumWarp. Save the place afterward.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local MODEL_NAME = "LobbyAquariumWarp"

local function isInsideGeneratedWorld(instance)
	local current = instance.Parent
	while current do
		if current.Name == "FishyFishWorld" then
			return true
		end
		current = current.Parent
	end

	return false
end

local function isGoodLobbyFloorPart(part)
	if isInsideGeneratedWorld(part) then
		return false
	end

	if part.Name == "Baseplate" or part.Name == MODEL_NAME then
		return false
	end

	if part.Transparency >= 0.95 or not part.Anchored then
		return false
	end

	if part.Position.Y < -10 or part.Position.Y > 20 then
		return false
	end

	if math.abs(part.Position.X) > 220 or math.abs(part.Position.Z) > 220 then
		return false
	end

	return part.Size.X >= 20 and part.Size.Z >= 20
end

local function findLobbyFloor()
	local bestPart = nil
	local bestArea = 0

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and isGoodLobbyFloorPart(descendant) then
			local area = descendant.Size.X * descendant.Size.Z
			if area > bestArea then
				bestPart = descendant
				bestArea = area
			end
		end
	end

	return bestPart
end

local old = Workspace:FindFirstChild(MODEL_NAME)
if old then
	old:Destroy()
end

local floor = findLobbyFloor()
local floorTopY = 3
local center = Vector3.new(0, 0, 0)

if floor then
	floorTopY = floor.Position.Y + (floor.Size.Y / 2)
	center = Vector3.new(floor.Position.X, 0, floor.Position.Z)
else
	warn("Aquarium warp patch: could not auto-detect the lobby floor, using the default lobby position.")
end

local model = Instance.new("Model")
model.Name = MODEL_NAME
model.Parent = Workspace

local parts = Instance.new("Folder")
parts.Name = "EditableParts"
parts.Parent = model

local function makePart(name, size, position, color, material, transparency, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.CanCollide = canCollide == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parts
	return part
end

local function createSurfaceLabel(part, textValue)
	local gui = Instance.new("SurfaceGui")
	gui.Name = part.Name .. "_SurfaceGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(800, 320)
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = textValue
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(17, 38, 55)
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui
end

local basePosition = Vector3.new(center.X - 58, floorTopY + 0.25, center.Z + 34)
local aqua = Color3.fromRGB(35, 205, 235)
local deepAqua = Color3.fromRGB(20, 105, 145)
local glass = Color3.fromRGB(90, 210, 255)
local dark = Color3.fromRGB(28, 45, 60)
local pearl = Color3.fromRGB(230, 245, 245)
local coral = Color3.fromRGB(255, 118, 96)
local gold = Color3.fromRGB(255, 204, 75)

local base = makePart("WarpPadBase", Vector3.new(20, 1, 16), basePosition, deepAqua, Enum.Material.SmoothPlastic, 0, true)
makePart("WarpPadGlow", Vector3.new(16, 0.28, 12), basePosition + Vector3.new(0, 0.65, 0), aqua, Enum.Material.Neon, 0.15, false)
makePart("WarpPadInnerWater", Vector3.new(11, 0.18, 8), basePosition + Vector3.new(0, 0.86, 0), glass, Enum.Material.Glass, 0.28, false)

makePart("LeftArchPost", Vector3.new(2.2, 13, 2.2), basePosition + Vector3.new(-8.2, 7, 2.2), deepAqua, Enum.Material.Metal, 0, true)
makePart("RightArchPost", Vector3.new(2.2, 13, 2.2), basePosition + Vector3.new(8.2, 7, 2.2), deepAqua, Enum.Material.Metal, 0, true)
makePart("ArchTop", Vector3.new(19, 2.4, 2.4), basePosition + Vector3.new(0, 13.9, 2.2), deepAqua, Enum.Material.Metal, 0, true)
makePart("ArchGlow", Vector3.new(13.5, 1, 1), basePosition + Vector3.new(0, 13.85, 0.8), aqua, Enum.Material.Neon, 0.1, false)

local sign = makePart("AquariumWarpSign", Vector3.new(15, 4, 0.65), basePosition + Vector3.new(0, 17.1, 1.05), dark, Enum.Material.SmoothPlastic, 0, false)
createSurfaceLabel(sign, "Aquarium\nWarp")

for index, offset in ipairs({ -6, -2, 2, 6 }) do
	local bubble = makePart("Bubble_" .. tostring(index), Vector3.new(1.2, 1.2, 1.2), basePosition + Vector3.new(offset, 4 + (index % 2) * 2, -3.2), pearl, Enum.Material.Glass, 0.35, false)
	bubble.Shape = Enum.PartType.Ball
end

for index, spec in ipairs({
	{ offset = Vector3.new(-5.5, 2.4, -5), color = coral },
	{ offset = Vector3.new(5.5, 2.2, -5.2), color = gold },
	{ offset = Vector3.new(0, 3.3, -4.8), color = Color3.fromRGB(65, 160, 235) },
}) do
	local body = makePart("DisplayFishBody_" .. tostring(index), Vector3.new(2.3, 0.75, 1), basePosition + spec.offset, spec.color, Enum.Material.SmoothPlastic, 0, false)
	body.Shape = Enum.PartType.Ball
	makePart("DisplayFishTail_" .. tostring(index), Vector3.new(0.7, 1.2, 1.1), basePosition + spec.offset + Vector3.new(-1.25, 0, 0), spec.color, Enum.Material.SmoothPlastic, 0, false)
end

local trigger = makePart("AquariumWarpTrigger", Vector3.new(18, 10, 14), basePosition + Vector3.new(0, 5.5, 0), aqua, Enum.Material.ForceField, 1, false)
trigger.CanTouch = true
trigger.CanQuery = false
trigger:SetAttribute("TargetArea", "Home")
CollectionService:AddTag(trigger, "AreaPortal")

local lightPart = makePart("AquariumWarpLight", Vector3.new(1, 1, 1), basePosition + Vector3.new(0, 9, 0), aqua, Enum.Material.Neon, 1, false)
local light = Instance.new("PointLight")
light.Color = aqua
light.Brightness = 1.8
light.Range = 28
light.Parent = lightPart

model.PrimaryPart = base
print("Aquarium warp patch: created Workspace." .. MODEL_NAME .. ". Save the place to keep it.")
