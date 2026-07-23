local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local TOOL_NAME = "Fishing Rod"

local OBJECT_PREFIX = "FishyFishRodVFX_"
local TOOL_PRESET_ATTRIBUTE = "RodVFXPreset"
local PLAYER_PRESET_ATTRIBUTE = "EquippedRodVFX"
local DISABLE_ATTRIBUTE = "DisableRodVFX"
local ACTIVE_PRESET_ATTRIBUTE = "ActiveRodVFXPreset"

local OWNED_FOLDER_NAME = "OwnedRodVFX"
local SERVICE_FOLDER_NAME = "RodVFXService"

-- Default high-quality progression VFX.
-- Future paid effects should use a different preset name through EquippedRodVFX
-- or RodVFXPreset. If that preset is unknown to this script, the default effect
-- is intentionally suppressed so a separate paid VFX system can take over.
local DEFAULT_PRESET_BY_ROD = {
	GoldenRod = "DefaultGolden",
	EmeraldRod = "DefaultEmerald",
	OceanRod = "DefaultOcean",
}

-- Image assets generated from the project-owned decal uploads. Each primary
-- layer uses its matching custom sprite; the secondary built-in layer keeps
-- the effect visible while a newly uploaded image is still under moderation.
-- Keep these as Image IDs (not the separate Decal IDs created by the upload).
local VFX_TEXTURES = {
	GoldStarburst = "rbxassetid://105259313691205",
	EmeraldGlint = "rbxassetid://83030794924123",
	OceanBubble = "rbxassetid://126760162748527",
}


-- Catalog metadata is intentionally separate from the visual preset definitions.
-- Future shop code can display and sell entries using either Sea Stars or Robux,
-- then grant ownership through the server-only bindable API created below.
--
-- Supported purchase metadata examples for future presets:
-- purchase = { currency = "SeaStars", price = 750 }
-- purchase = { currency = "Robux", productType = "GamePass", assetId = 123456789 }
-- purchase = { currency = "Robux", productType = "DeveloperProduct", assetId = 123456789 }
local CATALOG = {
	DefaultGolden = {
		displayName = "Golden Rod Default",
		category = "Default",
		includedWithRod = "GoldenRod",
		purchase = nil,
	},
	DefaultEmerald = {
		displayName = "Emerald Rod Default",
		category = "Default",
		includedWithRod = "EmeraldRod",
		purchase = nil,
	},
	DefaultOcean = {
		displayName = "Ocean Rod Default",
		category = "Default",
		includedWithRod = "OceanRod",
		purchase = nil,
	},
}

local PRESETS = {
	DefaultGolden = {
		emitters = {
			{
				name = "GoldSparkles",
				texture = VFX_TEXTURES.GoldStarburst,
				color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 178)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 188, 70)),
				}),
				rate = 12,
				lifetime = NumberRange.new(0.42, 0.82),
				speed = NumberRange.new(0.05, 0.26),
				acceleration = Vector3.new(0, 0.16, 0),
				drag = 0.12,
				spreadAngle = Vector2.new(42, 42),
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.06),
					NumberSequenceKeypoint.new(0.18, 0.52),
					NumberSequenceKeypoint.new(0.58, 0.25),
					NumberSequenceKeypoint.new(1, 0),
				}),
				transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.18),
					NumberSequenceKeypoint.new(0.18, 0.02),
					NumberSequenceKeypoint.new(0.76, 0.4),
					NumberSequenceKeypoint.new(1, 1),
				}),
				lightEmission = 0.95,
				brightness = 1.8,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-42, 42),
				velocityInheritance = 0.12,
				zOffset = 0.06,
			},
			{
				name = "GoldShimmer",
				texture = "rbxasset://textures/particles/sparkles_main.dds",
				color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 145)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 88)),
				}),
				rate = 6.5,
				lifetime = NumberRange.new(0.65, 1.1),
				speed = NumberRange.new(0.025, 0.11),
				acceleration = Vector3.new(0, 0.09, 0),
				drag = 0.24,
				spreadAngle = Vector2.new(34, 34),
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.06),
					NumberSequenceKeypoint.new(0.24, 0.45),
					NumberSequenceKeypoint.new(0.72, 0.2),
					NumberSequenceKeypoint.new(1, 0),
				}),
				transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.36),
					NumberSequenceKeypoint.new(0.16, 0.08),
					NumberSequenceKeypoint.new(0.78, 0.52),
					NumberSequenceKeypoint.new(1, 1),
				}),
				lightEmission = 0.9,
				brightness = 1.35,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-30, 30),
				velocityInheritance = 0.05,
				zOffset = 0.03,
			},
		},
		trail = {
			color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 170)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 201, 72)),
			}),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.42),
				NumberSequenceKeypoint.new(0.5, 0.18),
				NumberSequenceKeypoint.new(1, 1),
			}),
			widthScale = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.35, 0.72),
				NumberSequenceKeypoint.new(1, 0),
			}),
			lifetime = 0.16,
			lightEmission = 0.9,
			minLength = 0.035,
		},
		burst = {
			count = 10,
			emitterName = "GoldSparkles",
		},
	},
	DefaultEmerald = {
		highlight = {
			fillColor = Color3.fromRGB(45, 210, 118),
			fillTransparency = 0.93,
			outlineColor = Color3.fromRGB(160, 255, 204),
			outlineTransparency = 0.48,
		},
		lights = {
			{
				color = Color3.fromRGB(90, 240, 155),
				brightness = 0.38,
				range = 5.5,
			},
		},
		emitters = {
			{
				name = "EmeraldMotes",
				texture = VFX_TEXTURES.EmeraldGlint,
				color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(176, 255, 210)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(63, 225, 140)),
				}),
				rate = 9,
				lifetime = NumberRange.new(0.72, 1.25),
				speed = NumberRange.new(0.04, 0.18),
				acceleration = Vector3.new(0, 0.12, 0),
				drag = 0.22,
				spreadAngle = Vector2.new(38, 38),
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.05),
					NumberSequenceKeypoint.new(0.22, 0.46),
					NumberSequenceKeypoint.new(0.7, 0.23),
					NumberSequenceKeypoint.new(1, 0),
				}),
				transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.22),
					NumberSequenceKeypoint.new(0.18, 0.04),
					NumberSequenceKeypoint.new(0.8, 0.46),
					NumberSequenceKeypoint.new(1, 1),
				}),
				lightEmission = 0.94,
				brightness = 1.65,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-36, 36),
				velocityInheritance = 0.1,
				zOffset = 0.05,
			},
			{
				name = "EmeraldGlints",
				texture = "rbxasset://textures/particles/sparkles_main.dds",
				color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 255, 185)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(56, 184, 110)),
				}),
				rate = 6,
				lifetime = NumberRange.new(0.6, 1.05),
				speed = NumberRange.new(0.025, 0.1),
				acceleration = Vector3.new(0, 0.07, 0),
				drag = 0.26,
				spreadAngle = Vector2.new(32, 32),
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.05),
					NumberSequenceKeypoint.new(0.26, 0.4),
					NumberSequenceKeypoint.new(0.72, 0.18),
					NumberSequenceKeypoint.new(1, 0),
				}),
				transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.4),
					NumberSequenceKeypoint.new(0.18, 0.08),
					NumberSequenceKeypoint.new(0.8, 0.56),
					NumberSequenceKeypoint.new(1, 1),
				}),
				lightEmission = 0.9,
				brightness = 1.3,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-26, 26),
				velocityInheritance = 0.05,
				zOffset = 0.03,
			},
		},
		trail = {
			color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(165, 255, 212)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(61, 220, 134)),
			}),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.46),
				NumberSequenceKeypoint.new(0.5, 0.22),
				NumberSequenceKeypoint.new(1, 1),
			}),
			widthScale = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.95),
				NumberSequenceKeypoint.new(0.45, 0.62),
				NumberSequenceKeypoint.new(1, 0),
			}),
			lifetime = 0.16,
			lightEmission = 0.88,
			minLength = 0.035,
		},
		burst = {
			count = 8,
			emitterName = "EmeraldMotes",
		},
	},
	DefaultOcean = {
		highlight = {
			fillColor = Color3.fromRGB(70, 190, 255),
			fillTransparency = 0.86,
			outlineColor = Color3.fromRGB(180, 245, 255),
			outlineTransparency = 0.25,
		},
		lights = {
			{
				color = Color3.fromRGB(102, 214, 255),
				brightness = 0.85,
				range = 8,
			},
		},
		emitters = {
			{
				name = "OceanBubbles",
				texture = VFX_TEXTURES.OceanBubble,
				color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(210, 250, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(115, 215, 255)),
				}),
				rate = 16,
				lifetime = NumberRange.new(0.9, 1.5),
				speed = NumberRange.new(0.12, 0.38),
				acceleration = Vector3.new(0, 0.55, 0),
				drag = 0.12,
				spreadAngle = Vector2.new(34, 34),
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.16),
					NumberSequenceKeypoint.new(0.22, 0.62),
					NumberSequenceKeypoint.new(0.72, 0.9),
					NumberSequenceKeypoint.new(1, 0.38),
				}),
				transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.16),
					NumberSequenceKeypoint.new(0.12, 0.02),
					NumberSequenceKeypoint.new(0.82, 0.16),
					NumberSequenceKeypoint.new(1, 1),
				}),
				lightEmission = 0.92,
				brightness = 2.4,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-18, 18),
				velocityInheritance = 0.14,
				zOffset = 0.08,
			},
			{
				name = "OceanDroplets",
				texture = "rbxasset://textures/particles/sparkles_main.dds",
				color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(169, 240, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(86, 195, 255)),
				}),
				rate = 12,
				lifetime = NumberRange.new(0.4, 0.75),
				speed = NumberRange.new(0.08, 0.3),
				acceleration = Vector3.new(0, 0.3, 0),
				drag = 0.16,
				spreadAngle = Vector2.new(46, 46),
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.08),
					NumberSequenceKeypoint.new(0.2, 0.42),
					NumberSequenceKeypoint.new(0.65, 0.18),
					NumberSequenceKeypoint.new(1, 0),
				}),
				transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.22),
					NumberSequenceKeypoint.new(0.16, 0.05),
					NumberSequenceKeypoint.new(0.78, 0.26),
					NumberSequenceKeypoint.new(1, 1),
				}),
				lightEmission = 0.95,
				brightness = 1.8,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-28, 28),
				velocityInheritance = 0.12,
				zOffset = 0.06,
			},
		},
		trail = {
			color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(183, 247, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(91, 207, 255)),
			}),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.24),
				NumberSequenceKeypoint.new(0.5, 0.08),
				NumberSequenceKeypoint.new(1, 1),
			}),
			widthScale = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.3),
				NumberSequenceKeypoint.new(0.4, 0.86),
				NumberSequenceKeypoint.new(1, 0),
			}),
			lifetime = 0.28,
			lightEmission = 1,
			minLength = 0.025,
		},
		burst = {
			count = 18,
			emitterName = "OceanBubbles",
		},
	},
}

local trackedTools = setmetatable({}, { __mode = "k" })
local trackedPlayers = setmetatable({}, { __mode = "k" })
local refreshGeneration = setmetatable({}, { __mode = "k" })

local function startsWith(text, prefix)
	return string.sub(text, 1, #prefix) == prefix
end

local function destroyExistingEffects(tool)
	for _, descendant in ipairs(tool:GetDescendants()) do
		if startsWith(descendant.Name, OBJECT_PREFIX) then
			descendant:Destroy()
		end
	end
end

local function clearRenderedEffects(tool)
	destroyExistingEffects(tool)
	tool:SetAttribute(ACTIVE_PRESET_ATTRIBUTE, nil)
end

local function isEquippedFishingRod(tool)
	if not tool:IsA("Tool") or tool.Name ~= TOOL_NAME or not tool:IsDescendantOf(Workspace) then
		return false
	end

	local character = tool.Parent
	if not character or not character:IsA("Model") or not character:FindFirstChildOfClass("Humanoid") then
		return false
	end

	return Players:GetPlayerFromCharacter(character) ~= nil
end

local function isExcludedTipPart(part)
	local normalizedName = string.lower(part.Name)
	return string.find(normalizedName, "bobber", 1, true) ~= nil
		or string.find(normalizedName, "string", 1, true) ~= nil
		or string.find(normalizedName, "line", 1, true) ~= nil
		or string.find(normalizedName, "hook", 1, true) ~= nil
		or string.find(normalizedName, "reel", 1, true) ~= nil
		or string.find(normalizedName, "handle", 1, true) ~= nil
		or string.find(normalizedName, "grip", 1, true) ~= nil
end

local function getRodAttachments(tool)
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return nil, nil, nil
	end

	local visual = tool:FindFirstChild("RodVisual")
	local bestPart = nil
	local bestLocalPoint = nil
	local bestDistance = -math.huge

	if visual then
		for _, descendant in ipairs(visual:GetDescendants()) do
			if descendant:IsA("BasePart") and not isExcludedTipPart(descendant) then
				local halfSize = descendant.Size * 0.5
				for x = -1, 1, 2 do
					for y = -1, 1, 2 do
						for z = -1, 1, 2 do
							local localPoint = Vector3.new(halfSize.X * x, halfSize.Y * y, halfSize.Z * z)
							local worldPoint = descendant.CFrame:PointToWorldSpace(localPoint)
							local distance = (worldPoint - handle.Position).Magnitude
							if distance > bestDistance then
								bestDistance = distance
								bestPart = descendant
								bestLocalPoint = localPoint * 0.88
							end
						end
					end
				end
			end
		end
	end

	local tipPart = bestPart or handle
	local tipPosition = bestLocalPoint or Vector3.new(0, math.max(handle.Size.Y * 0.46, 0.1), 0)

	local tipAttachment = Instance.new("Attachment")
	tipAttachment.Name = OBJECT_PREFIX .. "Tip"
	tipAttachment.Position = tipPosition
	tipAttachment.Parent = tipPart

	-- A Trail should join two nearby points across the rod tip. Connecting the
	-- handle to the tip creates a broad sheet along the rod, which reads as a
	-- translucent ribbon instead of a short movement streak.
	local rodDirectionWorld = tipAttachment.WorldPosition - handle.Position
	if rodDirectionWorld.Magnitude < 0.001 then
		rodDirectionWorld = tipPart.CFrame.UpVector
	end
	local rodDirectionLocal = tipPart.CFrame:VectorToObjectSpace(rodDirectionWorld.Unit)
	local candidateAxes = {
		Vector3.new(1, 0, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(0, 0, 1),
	}
	local widthAxis = candidateAxes[1]
	local lowestParallel = math.huge
	for _, axis in ipairs(candidateAxes) do
		local parallel = math.abs(rodDirectionLocal:Dot(axis))
		if parallel < lowestParallel then
			lowestParallel = parallel
			widthAxis = axis
		end
	end

	local halfWidth = math.clamp(math.min(tipPart.Size.X, tipPart.Size.Y, tipPart.Size.Z) * 0.42, 0.025, 0.065)
	local trailLeft = Instance.new("Attachment")
	trailLeft.Name = OBJECT_PREFIX .. "TrailLeft"
	trailLeft.Position = tipPosition + widthAxis * halfWidth
	trailLeft.Parent = tipPart

	local trailRight = Instance.new("Attachment")
	trailRight.Name = OBJECT_PREFIX .. "TrailRight"
	trailRight.Position = tipPosition - widthAxis * halfWidth
	trailRight.Parent = tipPart

	return tipAttachment, trailLeft, trailRight
end

local function findOwningPlayer(tool)
	local character = tool.Parent
	if character and character:IsA("Model") then
		return Players:GetPlayerFromCharacter(character)
	end
	return nil
end


local function getOwnedFolder(player, createIfMissing)
	local folder = player:FindFirstChild(OWNED_FOLDER_NAME)
	if folder and not folder:IsA("Folder") then
		if not createIfMissing then
			return nil
		end
		folder:Destroy()
		folder = nil
	end

	if not folder and createIfMissing then
		folder = Instance.new("Folder")
		folder.Name = OWNED_FOLDER_NAME
		folder.Parent = player
	end

	return folder
end

local function isDefaultPreset(presetId)
	local catalogEntry = CATALOG[presetId]
	return catalogEntry ~= nil and catalogEntry.category == "Default"
end

local function ownsPreset(player, presetId)
	if presetId == "Default" or presetId == "Baseline" or presetId == "None" or presetId == "Disabled" then
		return true
	end

	if isDefaultPreset(presetId) then
		return true
	end

	if not PRESETS[presetId] or not CATALOG[presetId] then
		return false
	end

	local folder = getOwnedFolder(player, false)
	local ownedValue = folder and folder:FindFirstChild(presetId)
	return ownedValue ~= nil and ownedValue:IsA("BoolValue") and ownedValue.Value == true
end

local function grantPreset(player, presetId, acquisitionSource)
	if not player or not player:IsA("Player") then
		return false, "Invalid player."
	end

	local catalogEntry = CATALOG[presetId]
	if not catalogEntry or not PRESETS[presetId] then
		return false, "Unknown rod VFX preset."
	end

	if catalogEntry.category == "Default" then
		return false, "Default rod VFX does not require ownership."
	end

	local folder = getOwnedFolder(player, true)
	local ownedValue = folder:FindFirstChild(presetId)
	if ownedValue and not ownedValue:IsA("BoolValue") then
		ownedValue:Destroy()
		ownedValue = nil
	end

	if not ownedValue then
		ownedValue = Instance.new("BoolValue")
		ownedValue.Name = presetId
		ownedValue.Parent = folder
	end

	ownedValue.Value = true
	ownedValue:SetAttribute("AcquisitionSource", tostring(acquisitionSource or "Unknown"))
	ownedValue:SetAttribute("GrantedAtUnix", os.time())
	return true
end

local function revokePreset(player, presetId)
	if not player or not player:IsA("Player") then
		return false, "Invalid player."
	end

	local folder = getOwnedFolder(player, false)
	local ownedValue = folder and folder:FindFirstChild(presetId)
	if ownedValue then
		ownedValue:Destroy()
	end

	if player:GetAttribute(PLAYER_PRESET_ATTRIBUTE) == presetId then
		player:SetAttribute(PLAYER_PRESET_ATTRIBUTE, "Default")
	end

	return true
end

local function equipPreset(player, presetId)
	if not player or not player:IsA("Player") then
		return false, "Invalid player."
	end

	presetId = tostring(presetId or "Default")
	if presetId == "" then
		presetId = "Default"
	end

	if presetId == "Default" or presetId == "Baseline" then
		player:SetAttribute(PLAYER_PRESET_ATTRIBUTE, "Default")
		return true
	end

	if presetId == "None" or presetId == "Disabled" then
		player:SetAttribute(PLAYER_PRESET_ATTRIBUTE, "None")
		return true
	end

	if not PRESETS[presetId] or not CATALOG[presetId] then
		return false, "Unknown rod VFX preset."
	end

	if not ownsPreset(player, presetId) then
		return false, "Player does not own this rod VFX."
	end

	player:SetAttribute(PLAYER_PRESET_ATTRIBUTE, presetId)
	return true
end

local function makeCatalogSnapshot()
	local snapshot = {}

	for presetId, entry in pairs(CATALOG) do
		local purchase = entry.purchase
		snapshot[presetId] = {
			displayName = entry.displayName,
			category = entry.category,
			includedWithRod = entry.includedWithRod,
			purchase = purchase and {
				currency = purchase.currency,
				price = purchase.price,
				productType = purchase.productType,
				assetId = purchase.assetId,
			} or nil,
		}
	end

	return snapshot
end

local function resolvePresetId(tool)
	if tool:GetAttribute(DISABLE_ATTRIBUTE) == true then
		return nil
	end

	local rodId = tool:GetAttribute("RodId")
	local defaultPresetId = DEFAULT_PRESET_BY_ROD[rodId]

	-- Tool-level override has highest priority. It is intended for trusted
	-- server code, previews, admin tools, or a future dedicated paid controller.
	local explicitPreset = tool:GetAttribute(TOOL_PRESET_ATTRIBUTE)
	if type(explicitPreset) == "string" and explicitPreset ~= "" then
		if explicitPreset == "None" or explicitPreset == "Disabled" then
			return nil
		end
		if explicitPreset == "Default" or explicitPreset == "Baseline" then
			return defaultPresetId
		end
		return PRESETS[explicitPreset] and explicitPreset or nil
	end

	local player = findOwningPlayer(tool)
	if player then
		local equippedSlotPreset = player:GetAttribute(PLAYER_PRESET_ATTRIBUTE)
		if type(equippedSlotPreset) == "string" and equippedSlotPreset ~= "" then
			if equippedSlotPreset == "None" or equippedSlotPreset == "Disabled" then
				return nil
			end
			if equippedSlotPreset == "Default" or equippedSlotPreset == "Baseline" then
				return defaultPresetId
			end

			if PRESETS[equippedSlotPreset] and ownsPreset(player, equippedSlotPreset) then
				return equippedSlotPreset
			end

			-- Unknown names intentionally suppress the built-in default so a
			-- future external premium controller can own the complete effect.
			return nil
		end
	end

	return defaultPresetId
end

local function createEmitter(parentAttachment, emitterConfig)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = OBJECT_PREFIX .. emitterConfig.name
	emitter.Texture = emitterConfig.texture
	emitter.Color = emitterConfig.color
	emitter.Rate = emitterConfig.rate
	emitter.Lifetime = emitterConfig.lifetime
	emitter.Speed = emitterConfig.speed
	emitter.Acceleration = emitterConfig.acceleration
	emitter.Drag = emitterConfig.drag
	emitter.SpreadAngle = emitterConfig.spreadAngle
	emitter.Size = emitterConfig.size
	emitter.Transparency = emitterConfig.transparency
	emitter.LightEmission = emitterConfig.lightEmission or 0
	emitter.LightInfluence = 0
	emitter.Brightness = emitterConfig.brightness or 1
	emitter.Rotation = emitterConfig.rotation or NumberRange.new(0, 0)
	emitter.RotSpeed = emitterConfig.rotSpeed or NumberRange.new(0, 0)
	emitter.VelocityInheritance = emitterConfig.velocityInheritance or 0
	emitter.ZOffset = emitterConfig.zOffset or 0
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.Enabled = true
	emitter.Parent = parentAttachment
	return emitter
end

local function createLights(parentAttachment, presetConfig)
	for index, lightConfig in ipairs(presetConfig.lights or {}) do
		local light = Instance.new("PointLight")
		light.Name = string.format("%sLight_%d", OBJECT_PREFIX, index)
		light.Color = lightConfig.color
		light.Brightness = lightConfig.brightness
		light.Range = lightConfig.range
		light.Shadows = false
		light.Enabled = true
		light.Parent = parentAttachment
	end
end

local function createTrailLayer(parent, name, attachment0, attachment1, color, transparency, widthScale, lifetime, lightEmission, minLength)
	local trail = Instance.new("Trail")
	trail.Name = OBJECT_PREFIX .. name
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Color = color
	trail.Transparency = transparency
	trail.WidthScale = widthScale
	trail.Lifetime = lifetime
	trail.LightEmission = lightEmission
	trail.MinLength = minLength
	trail.FaceCamera = true
	trail.Enabled = true
	trail.Parent = parent
	return trail
end

local function createTrails(trailLeft, trailRight, trailConfig)
	if not trailConfig then
		return
	end

	local parent = trailLeft.Parent
	local minLength = trailConfig.minLength or 0.035
	createTrailLayer(
		parent,
		"TrailOuter",
		trailLeft,
		trailRight,
		trailConfig.color,
		trailConfig.transparency,
		trailConfig.widthScale,
		trailConfig.lifetime,
		trailConfig.lightEmission or 0,
		minLength
	)

	createTrailLayer(
		parent,
		"TrailCore",
		trailLeft,
		trailRight,
		trailConfig.color,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(0.55, 0.42),
			NumberSequenceKeypoint.new(1, 1),
		}),
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.44),
			NumberSequenceKeypoint.new(0.45, 0.24),
			NumberSequenceKeypoint.new(1, 0),
		}),
		trailConfig.lifetime * 0.78,
		1,
		minLength
	)
end

local function createHighlight(tool, presetConfig)
	local highlightConfig = presetConfig.highlight
	local visual = tool:FindFirstChild("RodVisual")
	if not highlightConfig or not visual then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = OBJECT_PREFIX .. "Highlight"
	highlight.Adornee = visual
	highlight.FillColor = highlightConfig.fillColor
	highlight.FillTransparency = highlightConfig.fillTransparency
	highlight.OutlineColor = highlightConfig.outlineColor
	highlight.OutlineTransparency = highlightConfig.outlineTransparency
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = tool
end

local function emitInitialBurst(tipAttachment, presetConfig)
	local burstConfig = presetConfig.burst
	if not burstConfig then
		return
	end

	local emitter = tipAttachment:FindFirstChild(OBJECT_PREFIX .. burstConfig.emitterName)
	if emitter and emitter:IsA("ParticleEmitter") then
		emitter:Emit(burstConfig.count or 0)
	end
end

local function refreshTool(tool)
	clearRenderedEffects(tool)

	if not isEquippedFishingRod(tool) then
		return
	end

	local presetId = resolvePresetId(tool)
	local presetConfig = presetId and PRESETS[presetId]
	if not presetConfig then
		return
	end

	local tipAttachment, trailLeft, trailRight = getRodAttachments(tool)
	if not tipAttachment or not trailLeft or not trailRight then
		return
	end

	createLights(tipAttachment, presetConfig)
	for _, emitterConfig in ipairs(presetConfig.emitters or {}) do
		createEmitter(tipAttachment, emitterConfig)
	end
	createTrails(trailLeft, trailRight, presetConfig.trail)
	createHighlight(tool, presetConfig)
	emitInitialBurst(tipAttachment, presetConfig)

	tool:SetAttribute(ACTIVE_PRESET_ATTRIBUTE, presetId)
end

local function scheduleRefresh(tool)
	local generation = (refreshGeneration[tool] or 0) + 1
	refreshGeneration[tool] = generation

	task.defer(function()
		if refreshGeneration[tool] ~= generation or not tool.Parent then
			return
		end
		refreshTool(tool)
	end)
end

local function untrackTool(tool)
	local connections = trackedTools[tool]
	if not connections then
		return
	end

	trackedTools[tool] = nil
	refreshGeneration[tool] = nil
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	destroyExistingEffects(tool)
end

local function refreshEquippedToolForPlayer(player)
	local character = player.Character
	if not character then
		return
	end

	local tool = character:FindFirstChild(TOOL_NAME)
	if tool and tool:IsA("Tool") then
		scheduleRefresh(tool)
	end
end

local function trackPlayerAttribute(player)
	if trackedPlayers[player] then
		return
	end

	local connections = {}
	trackedPlayers[player] = connections
	getOwnedFolder(player, true)

	if player:GetAttribute(PLAYER_PRESET_ATTRIBUTE) == nil then
		player:SetAttribute(PLAYER_PRESET_ATTRIBUTE, "Default")
	end

	table.insert(connections, player:GetAttributeChangedSignal(PLAYER_PRESET_ATTRIBUTE):Connect(function()
		refreshEquippedToolForPlayer(player)
	end))

	table.insert(connections, player.CharacterAdded:Connect(function()
		task.defer(function()
			refreshEquippedToolForPlayer(player)
		end)
	end))

	table.insert(connections, player.Destroying:Connect(function()
		local currentConnections = trackedPlayers[player]
		trackedPlayers[player] = nil
		for _, connection in ipairs(currentConnections or {}) do
			connection:Disconnect()
		end
	end))
end

local function trackTool(tool)
	if not tool:IsA("Tool") or tool.Name ~= TOOL_NAME or trackedTools[tool] then
		return
	end

	local connections = {}
	trackedTools[tool] = connections

	table.insert(connections, tool.AncestryChanged:Connect(function()
		if isEquippedFishingRod(tool) then
			scheduleRefresh(tool)
		else
			-- Remove replicated effects synchronously when the rod leaves the
			-- character. This prevents a backpack display from cloning a single
			-- frame of equipped-only VFX before a deferred refresh can run.
			refreshGeneration[tool] = (refreshGeneration[tool] or 0) + 1
			clearRenderedEffects(tool)
		end
		local player = findOwningPlayer(tool)
		if player then
			trackPlayerAttribute(player)
		end
	end))
	table.insert(connections, tool:GetAttributeChangedSignal("RodId"):Connect(function()
		scheduleRefresh(tool)
	end))
	table.insert(connections, tool:GetAttributeChangedSignal(TOOL_PRESET_ATTRIBUTE):Connect(function()
		scheduleRefresh(tool)
	end))
	table.insert(connections, tool:GetAttributeChangedSignal(DISABLE_ATTRIBUTE):Connect(function()
		scheduleRefresh(tool)
	end))
	table.insert(connections, tool.ChildAdded:Connect(function(child)
		if child.Name == "RodVisual" or child.Name == "Handle" then
			scheduleRefresh(tool)
		end
	end))
	table.insert(connections, tool.ChildRemoved:Connect(function(child)
		if child.Name == "RodVisual" or child.Name == "Handle" then
			scheduleRefresh(tool)
		end
	end))
	table.insert(connections, tool.Destroying:Connect(function()
		untrackTool(tool)
	end))

	local player = findOwningPlayer(tool)
	if player then
		trackPlayerAttribute(player)
	end

	scheduleRefresh(tool)
end


local function ensureBindableFunction(parent, name, callback)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA("BindableFunction") then
		existing:Destroy()
		existing = nil
	end

	local bindable = existing or Instance.new("BindableFunction")
	bindable.Name = name
	bindable.OnInvoke = callback
	bindable.Parent = parent
	return bindable
end

local function createServiceApi()
	local existing = ServerStorage:FindFirstChild(SERVICE_FOLDER_NAME)
	if existing and not existing:IsA("Folder") then
		existing:Destroy()
		existing = nil
	end

	local folder = existing or Instance.new("Folder")
	folder.Name = SERVICE_FOLDER_NAME
	folder.Parent = ServerStorage

	ensureBindableFunction(folder, "GrantOwnedPreset", function(player, presetId, acquisitionSource)
		local success, message = grantPreset(player, presetId, acquisitionSource)
		if success then
			refreshEquippedToolForPlayer(player)
		end
		return success, message
	end)

	ensureBindableFunction(folder, "RevokeOwnedPreset", function(player, presetId)
		local success, message = revokePreset(player, presetId)
		if success then
			refreshEquippedToolForPlayer(player)
		end
		return success, message
	end)

	ensureBindableFunction(folder, "EquipPreset", function(player, presetId)
		local success, message = equipPreset(player, presetId)
		if success then
			refreshEquippedToolForPlayer(player)
		end
		return success, message
	end)

	ensureBindableFunction(folder, "OwnsPreset", function(player, presetId)
		return ownsPreset(player, tostring(presetId or ""))
	end)

	ensureBindableFunction(folder, "GetCatalog", function()
		return makeCatalogSnapshot()
	end)

	ensureBindableFunction(folder, "RefreshPlayer", function(player)
		if player and player:IsA("Player") then
			refreshEquippedToolForPlayer(player)
			return true
		end
		return false
	end)
end

createServiceApi()

for _, player in ipairs(Players:GetPlayers()) do
	trackPlayerAttribute(player)
end

Players.PlayerAdded:Connect(trackPlayerAttribute)

for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("Tool") and descendant.Name == TOOL_NAME then
		trackTool(descendant)
	end
end

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Tool") and descendant.Name == TOOL_NAME then
		trackTool(descendant)
	end
end)
