local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TEMPLATE_NAME = "FishingBackpackTemplate"
local VISUAL_NAME = "FishingBackpackVisual"
local STOWED_ROD_NAME = "StowedFishingRodVisual"

local BACKPACK_VERTICAL_OFFSET = 0.08
local BACKPACK_GAP = 0.06
local ROD_VFX_PREFIX = "FishyFishRodVFX_"

local function isStowedRodEffect(descendant)
	return string.sub(descendant.Name, 1, #ROD_VFX_PREFIX) == ROD_VFX_PREFIX
		or descendant:IsA("ParticleEmitter")
		or descendant:IsA("Trail")
		or descendant:IsA("Beam")
		or descendant:IsA("Smoke")
		or descendant:IsA("Fire")
		or descendant:IsA("Sparkles")
		or descendant:IsA("Light")
		or descendant:IsA("Highlight")
end

local function configurePart(part)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
end

local function findPrimaryPart(model)
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local part = model:FindFirstChildWhichIsA("BasePart", true)
	if part then
		model.PrimaryPart = part
	end
	return part
end

local function clearStowedRod(backpackVisual)
	local existing = backpackVisual and backpackVisual:FindFirstChild(STOWED_ROD_NAME)
	if existing then
		existing:Destroy()
	end
end

local function createStowedRod(player, character, backpackVisual, backpackPart)
	clearStowedRod(backpackVisual)
	-- Never show the backpack copy while the real rod is equipped. Checking the
	-- character first also closes the brief Backpack/Character reparenting race.
	if character:FindFirstChild("Fishing Rod") then
		return
	end

	local playerBackpack = player:FindFirstChildOfClass("Backpack")
	local sourceTool = playerBackpack and playerBackpack:FindFirstChild("Fishing Rod")
	if not sourceTool or not sourceTool:IsA("Tool") then
		return
	end

	local container = Instance.new("Model")
	container.Name = STOWED_ROD_NAME
	container.Parent = backpackVisual

	local rodClone = sourceTool:Clone()
	rodClone.Name = "FishingRod"
	rodClone:SetAttribute("DisableRodVFX", true)
	rodClone:SetAttribute("ActiveRodVFXPreset", nil)
	rodClone.Parent = container

	for _, descendant in rodClone:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif isStowedRodEffect(descendant) then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			configurePart(descendant)
		end
	end

	local handle = rodClone:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		container:Destroy()
		return
	end

	-- The rod sits vertically along the player's right side, slightly outside the pack.
	handle.CFrame = character:GetPivot()
		* CFrame.new(0.98, 0.15, 1.12)
		* CFrame.Angles(0, 0, math.rad(-11))

	local weld = Instance.new("WeldConstraint")
	weld.Name = "BackpackRodWeld"
	weld.Part0 = backpackPart
	weld.Part1 = handle
	weld.Parent = handle
end

local function attachBackpack(player, character)
	local torso = character:WaitForChild("UpperTorso", 8) or character:WaitForChild("Torso", 2)
	if not torso or not torso:IsA("BasePart") then
		return
	end

	local previous = character:FindFirstChild(VISUAL_NAME)
	if previous then
		previous:Destroy()
	end

	local template = ReplicatedStorage:WaitForChild(TEMPLATE_NAME, 12)
	if not template or not template:IsA("Model") then
		warn("[BackpackVisual] Missing ReplicatedStorage." .. TEMPLATE_NAME)
		return
	end

	local visual = template:Clone()
	visual.Name = VISUAL_NAME
	visual.Parent = character

	local backpackPart = findPrimaryPart(visual)
	if not backpackPart then
		visual:Destroy()
		return
	end

	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			configurePart(descendant)
		end
	end

	-- Rotate the imported model so its decorated buckle-and-pocket face points
	-- away from the character, its bedroll stays above the pack, and the
	-- shoulder-strap side rests against the torso.
	local target = torso.CFrame
		* CFrame.new(0, BACKPACK_VERTICAL_OFFSET, torso.Size.Z * 0.5 + BACKPACK_GAP)
		* CFrame.Angles(math.pi, 0, 0)
	visual:PivotTo(target)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "BackpackWeld"
	weld.Part0 = torso
	weld.Part1 = backpackPart
	weld.Parent = backpackPart

	local refreshQueued = false
	local function refreshStowedRod()
		if refreshQueued then
			return
		end
		refreshQueued = true
		task.defer(function()
			refreshQueued = false
			if not visual.Parent or not character.Parent then
				return
			end
			createStowedRod(player, character, visual, backpackPart)
		end)
	end

	local playerBackpack = player:WaitForChild("Backpack", 8)
	if playerBackpack then
		playerBackpack.ChildAdded:Connect(function(child)
			if child.Name == "Fishing Rod" then
				refreshStowedRod()
			end
		end)
		playerBackpack.ChildRemoved:Connect(function(child)
			if child.Name == "Fishing Rod" then
				clearStowedRod(visual)
				refreshStowedRod()
			end
		end)
		playerBackpack.DescendantAdded:Connect(function(descendant)
			local tool = descendant:FindFirstAncestor("Fishing Rod")
			if tool and tool:IsA("Tool") then
				refreshStowedRod()
			end
		end)
		playerBackpack.DescendantRemoving:Connect(function(descendant)
			local tool = descendant:FindFirstAncestor("Fishing Rod")
			if tool and tool:IsA("Tool") then
				refreshStowedRod()
			end
		end)
	end
	character.ChildAdded:Connect(function(child)
		if child.Name == "Fishing Rod" then
			clearStowedRod(visual)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child.Name == "Fishing Rod" then
			refreshStowedRod()
		end
	end)

	refreshStowedRod()
end

local function bindPlayer(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(attachBackpack, player, character)
	end)

	if player.Character then
		task.spawn(attachBackpack, player, player.Character)
	end
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in Players:GetPlayers() do
	bindPlayer(player)
end
