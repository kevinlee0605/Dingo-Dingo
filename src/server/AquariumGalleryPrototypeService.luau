local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local AquariumGalleryPrototypeService = {}

local PROTOTYPE_NAME = "AquariumGalleryPrototype"
local WORKSPACE_GALLERY_NAME = "AquariumGalleryPrototypeVisual"
local ASSET_FOLDER_NAME = "AquariumGalleryAssets"
local BAY_COUNT = 12
-- Preserve the approved modular-kit layout. The imported walkway ring and bay
-- spacing were authored around a 135-stud radius; moving only the bays farther
-- out creates visible gaps and makes the connectors look like bridges.
local GALLERY_RADIUS = 135
local WALKWAY_RADIUS = 145
local GALLERY_RING_WIDTH = 66
local GALLERY_LAYOUT_VERSION = 11
local GALLERY_TANK_LAYOUT_VERSION = 2
local GALLERY_TANK_PLATFORM_OFFSET_Y = 1.8
local BAY_HOLOGRAM_NAME = "AquariumOwnerHologram"
local BAY_HOLOGRAM_HEIGHT = 2.5
local BAY_HOLOGRAM_MAX_DISTANCE = 82
local FEATURED_HOLOGRAM_NAME = "FeaturedAquariumHologram"
local AUTHORED_SHOWCASE_NAME = "SharedAquariumShowcase"
local AUTHORED_HUB_SPAWN_NAME = "AquariumHubSpawn"
local ARCHIVE_FOLDER_NAME = "ArchivedAquariumAreas"
local RETURN_PORTAL_MODEL_NAME = "AquariumGalleryReturnPortal"
local ACTIVE_GALLERY_CENTER = Vector3.new(-150, 0, -1300)
local FEATURED_TANK_ORIGIN_OFFSET = Vector3.new(0, 24.7, 36.94)
local ENTRANCE_RADIUS = GALLERY_RADIUS + 70

local IMPORTED_BAY_NAME = "AquariumGalleryBay"
local IMPORTED_WALKWAY_NAME = "AquariumGalleryWalkway"
local IMPORTED_FEATURED_NAME = "AquariumGalleryFeaturedCenter"

local makeFeaturedCenter

local HIDDEN_EXACT_NAMES = {
	AquariumOrigin = true,
	FeaturedAquariumOrigin = true,
	FeaturedSignAnchor = true,
	GallerySpawn = true,
	OwnerSpawn = true,
	SignAnchor = true,
	WalkwayEnd = true,
	WalkwayStart = true,
}

local OVERLAPPING_BAY_PARTS = {
	BayFloor = true,
	BayLeftRailing = true,
	BayRightRailing = true,
	BayTrim = true,
}

local function belongsToOverlappingBayGeometry(instance, boundary)
	local current = instance
	while current and current ~= boundary do
		if OVERLAPPING_BAY_PARTS[current.Name] then
			return true
		end
		current = current.Parent
	end
	return false
end

local COLORS = {
	navy = Color3.fromRGB(18, 39, 66),
	stone = Color3.fromRGB(83, 99, 116),
	cyan = Color3.fromRGB(38, 205, 244),
	gold = Color3.fromRGB(226, 178, 72),
	marker = Color3.fromRGB(122, 255, 169),
}

local function makePart(parent, name, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color or COLORS.stone
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeMarker(parent, name, cframe)
	local marker = makePart(
		parent,
		name,
		Vector3.new(1, 1, 1),
		cframe,
		COLORS.marker,
		Enum.Material.Neon,
		0.35
	)
	marker.CanCollide = false
	marker:SetAttribute("GalleryHelper", true)
	return marker
end

local function makeCollisionProxy(parent, name, size, cframe)
	local proxy = makePart(parent, name, size, cframe, COLORS.stone, Enum.Material.SmoothPlastic, 1)
	proxy.CanCollide = false
	proxy:SetAttribute("CollisionProxy", true)
	return proxy
end

local function shouldHideImportedPart(partName)
	return string.sub(partName, 1, 4) == "COL_"
		or HIDDEN_EXACT_NAMES[partName] == true
		or string.find(partName, "ClearanceGuide", 1, true) ~= nil
		or string.find(partName, "VisitorSpawn", 1, true) ~= nil
end

local function prepareImportedModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local isCollisionProxy = string.sub(descendant.Name, 1, 4) == "COL_"
			local isHelper = shouldHideImportedPart(descendant.Name) and not isCollisionProxy
			local isOverlappingBayPart = belongsToOverlappingBayGeometry(descendant, model)

			descendant.Anchored = true
			descendant.CanTouch = false
			descendant.CanQuery = isCollisionProxy
			descendant.CanCollide = isCollisionProxy
			if isCollisionProxy or isHelper or isOverlappingBayPart then
				descendant.Transparency = 1
			end
			if isOverlappingBayPart then
				descendant.CanCollide = false
				descendant.CanQuery = false
			end
		end
	end
end

local function cloneImportedModel(template, parent, name, pivot)
	local clone = template:Clone()
	clone.Name = name
	prepareImportedModel(clone)
	clone:PivotTo(pivot)
	clone.Parent = parent
	return clone
end

local function buildFromImportedAssets(prototype)
	local assets = ServerStorage:FindFirstChild(ASSET_FOLDER_NAME)
	if not assets then
		return false
	end

	local bayTemplate = assets:FindFirstChild(IMPORTED_BAY_NAME)
	local walkwayTemplate = assets:FindFirstChild(IMPORTED_WALKWAY_NAME)
	local featuredTemplate = assets:FindFirstChild(IMPORTED_FEATURED_NAME)
	if not (bayTemplate and bayTemplate:IsA("Model"))
		or not (walkwayTemplate and walkwayTemplate:IsA("Model"))
		or not (featuredTemplate and featuredTemplate:IsA("Model")) then
		return false
	end

	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = prototype
	local walkways = Instance.new("Folder")
	walkways.Name = "Walkways"
	walkways.Parent = prototype

	for slotNumber = 1, BAY_COUNT do
		local angle = math.rad((slotNumber - 1) * (360 / BAY_COUNT))
		local position = Vector3.new(math.sin(angle) * GALLERY_RADIUS, 0, math.cos(angle) * GALLERY_RADIUS)
		local bay = cloneImportedModel(
			bayTemplate,
			slots,
			string.format("AquariumSlot%02d", slotNumber),
			CFrame.lookAt(position, Vector3.zero)
		)
		bay:SetAttribute("SlotNumber", slotNumber)
		bay:SetAttribute("PlatformOwnerUserId", 0)
		bay:SetAttribute("DisplayedAquariumUserId", 0)
		bay:SetAttribute("ReadOnlyDisplay", false)

		cloneImportedModel(
			walkwayTemplate,
			walkways,
			string.format("AquariumGalleryWalkway%02d", slotNumber),
			CFrame.Angles(0, angle, 0)
		)
	end

	local featured = cloneImportedModel(
		featuredTemplate,
		prototype,
		"AquariumGalleryFeaturedCenter",
		CFrame.identity
	)
	featured:SetAttribute("ReadOnlyDisplay", true)
	prototype:SetAttribute("AssetSource", ASSET_FOLDER_NAME)
	return true
end

local function getGalleryCenter(root)
	local center = root:GetAttribute("GalleryCenter")
	if typeof(center) == "Vector3" then
		return center
	end
	return Vector3.zero
end

local function getGallerySlots(root)
	local slots = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Model") then
			local slotNumber = tonumber(descendant:GetAttribute("GallerySlotIndex"))
			if not slotNumber and string.match(descendant.Name, "^AquariumSlot%d+$") then
				slotNumber = tonumber(descendant:GetAttribute("SlotNumber"))
			end
			if slotNumber then
				table.insert(slots, {
					model = descendant,
					slotNumber = slotNumber,
				})
			end
		end
	end
	table.sort(slots, function(left, right)
		return left.slotNumber < right.slotNumber
	end)
	return slots
end

local function getTankMountCFrame(bay)
	local mount = bay:FindFirstChild("AquariumOrigin", true)
	if mount then
		if mount:IsA("Model") then
			return mount:GetPivot()
		end
		if mount:IsA("BasePart") then
			return mount.CFrame
		end
	end
	return bay:GetPivot() * CFrame.new(0, 1, 8)
end

local function hidePhysicalBaySign(bay)
	local signMount = bay:FindFirstChild("BaySignMount", true)
	if not signMount or not (signMount:IsA("BasePart") or signMount:IsA("Model")) then
		return
	end

	for _, descendant in ipairs(signMount:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end
	if signMount:IsA("BasePart") then
		signMount.Transparency = 1
		signMount.CanCollide = false
		signMount.CanQuery = false
	end
	bay:SetAttribute("GallerySignPlacement", "HologramAboveTank")
end

local function updateBayHologram(bay, labelText)
	local previous = bay:FindFirstChild(BAY_HOLOGRAM_NAME)
	if previous then
		previous:Destroy()
	end

	local tank = bay:FindFirstChild("GalleryTank")
	if not tank or not tank:IsA("Model") then
		return
	end

	local tankCFrame, tankSize = tank:GetBoundingBox()
	local anchor = Instance.new("Part")
	anchor.Name = BAY_HOLOGRAM_NAME
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(
		tankCFrame.Position.X,
		tankCFrame.Position.Y + tankSize.Y * 0.5 + BAY_HOLOGRAM_HEIGHT,
		tankCFrame.Position.Z
	)
	anchor.Parent = bay

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HologramBillboard"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = BAY_HOLOGRAM_MAX_DISTANCE
	billboard.Size = UDim2.fromOffset(180, 36)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "OwnerLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(120, 240, 255)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(0, 45, 85)
	label.TextStrokeTransparency = 0.12
	label.Parent = billboard
end

local function setModelVisible(model, visible)
	if not model then
		return
	end

	local function updatePart(instance)
		if instance:IsA("BasePart") then
			instance.Transparency = visible and 0 or 1
			instance.CanCollide = visible
			instance.CanQuery = visible
		end
	end
	updatePart(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		updatePart(descendant)
	end
end

local function restyleAquariumPedestal(container, pedestalName)
	local pedestal = container:FindFirstChild(pedestalName, true)
	if not pedestal then
		return
	end

	local function restyle(instance)
		if instance:IsA("BasePart") then
			instance.Color = COLORS.navy
			instance.Material = Enum.Material.Metal
		end
	end
	restyle(pedestal)
	for _, descendant in ipairs(pedestal:GetDescendants()) do
		restyle(descendant)
	end
end

local function updateFeaturedHologram(featured)
	local previous = featured:FindFirstChild(FEATURED_HOLOGRAM_NAME)
	if previous then
		previous:Destroy()
	end

	local anchorCFrame
	local featuredTank = featured:FindFirstChild("FeaturedGalleryTank")
		or featured:FindFirstChild("GalleryTank")
	if featuredTank and featuredTank:IsA("Model") then
		local tankCFrame, tankSize = featuredTank:GetBoundingBox()
		anchorCFrame = CFrame.new(
			tankCFrame.Position.X,
			tankCFrame.Position.Y + tankSize.Y * 0.5 + BAY_HOLOGRAM_HEIGHT,
			tankCFrame.Position.Z
		)
	else
		local mount = featured:FindFirstChild("FeaturedAquariumOrigin", true)
		if mount and mount:IsA("Model") then
			anchorCFrame = mount:GetPivot() * CFrame.new(0, 20, 0)
		elseif mount and mount:IsA("BasePart") then
			anchorCFrame = mount.CFrame * CFrame.new(0, 20, 0)
		else
			anchorCFrame = featured:GetPivot() * CFrame.new(0, 20, 0)
		end
	end

	local anchor = Instance.new("Part")
	anchor.Name = FEATURED_HOLOGRAM_NAME
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = anchorCFrame
	anchor.Parent = featured

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HologramBillboard"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 130
	billboard.Size = UDim2.fromOffset(220, 42)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "FeaturedLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "FEATURED AQUARIUM"
	label.TextColor3 = Color3.fromRGB(255, 218, 95)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(70, 42, 0)
	label.TextStrokeTransparency = 0.12
	label.Parent = billboard
end

local function getArchiveFolder()
	local folder = ServerStorage:FindFirstChild(ARCHIVE_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = ARCHIVE_FOLDER_NAME
		folder.Parent = ServerStorage
	end
	return folder
end

local function findLegacyShowcaseSource()
	local showcase = workspace:FindFirstChild(AUTHORED_SHOWCASE_NAME, true)
	if showcase and showcase:IsA("Model") then
		return showcase
	end

	local archived = getArchiveFolder():FindFirstChild(AUTHORED_SHOWCASE_NAME)
	if archived and archived:IsA("Model") then
		return archived
	end
	return nil
end

local function isReturnPortalComponent(instance)
	local normalizedName = string.gsub(string.lower(instance.Name), "[^%w]", "")
	return string.find(normalizedName, "returnportal", 1, true) ~= nil
		or instance.Name == "Seaside_Return_Portal_Surface_Node"
end

local function positionReturnPortal(portalRoot, galleryCenter)
	local boundsCFrame, boundsSize = portalRoot:GetBoundingBox()
	local targetCenter = galleryCenter + Vector3.new(
		0,
		(boundsSize.Y * 0.5) - 0.6,
		-ENTRANCE_RADIUS
	)
	local translation = targetCenter - boundsCFrame.Position
	portalRoot:PivotTo(CFrame.new(translation) * portalRoot:GetPivot())
	portalRoot:SetAttribute("GalleryLayoutVersion", GALLERY_LAYOUT_VERSION)
	portalRoot:SetAttribute("AppliedGalleryCenter", galleryCenter)
end

local function ensureReturnPortal(root, showcaseSource)
	local existing = root:FindFirstChild(RETURN_PORTAL_MODEL_NAME)
	if existing and existing:IsA("Model") then
		positionReturnPortal(existing, getGalleryCenter(root))
	else
		local sourceSurface = showcaseSource
			and showcaseSource:FindFirstChild("Seaside_Return_Portal_Surface", true)
		local sourceWorld = sourceSurface and sourceSurface.Parent and sourceSurface.Parent.Parent
		if not sourceSurface or not sourceWorld then
			return nil
		end

		local portalRoot = Instance.new("Model")
		portalRoot.Name = RETURN_PORTAL_MODEL_NAME
		portalRoot:SetAttribute("Source", "ArchivedSeasideReturnPortal")
		for _, child in ipairs(sourceWorld:GetChildren()) do
			if isReturnPortalComponent(child) then
				child:Clone().Parent = portalRoot
			end
		end
		if not portalRoot:FindFirstChildWhichIsA("BasePart", true) then
			portalRoot:Destroy()
			return nil
		end
		portalRoot.Parent = root
		positionReturnPortal(portalRoot, getGalleryCenter(root))
		existing = portalRoot
	end

	local surface = existing:FindFirstChild("Seaside_Return_Portal_Surface", true)
		or existing:FindFirstChild("ReturnToSeasideIslandPortal", true)
	if surface and surface:IsA("BasePart") then
		surface:SetAttribute("TargetArea", "Lobby")
		surface:SetAttribute("PortalName", "Return to Seaside Island")
		surface.CanCollide = false
		surface.CanTouch = true
		CollectionService:AddTag(surface, "AreaPortal")
	end
	return existing
end

local function ensureGalleryHubSpawn(root)
	local center = getGalleryCenter(root)
	local spawn = root:FindFirstChild(AUTHORED_HUB_SPAWN_NAME, true)
	if not spawn or not spawn:IsA("BasePart") then
		spawn = makePart(
			root,
			AUTHORED_HUB_SPAWN_NAME,
			Vector3.new(16, 1, 14),
			CFrame.new(center + Vector3.new(0, 1.1, -(GALLERY_RADIUS - 10))),
			COLORS.cyan,
			Enum.Material.ForceField,
			1
		)
	end
	spawn.CFrame = CFrame.new(center + Vector3.new(0, 1.1, -(GALLERY_RADIUS - 10)))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = true
	spawn:SetAttribute("GallerySpawn", true)
	return spawn
end

local function archiveLegacyShowcase(showcase)
	if not showcase or not showcase:IsDescendantOf(workspace) then
		return showcase
	end
	local archiveFolder = getArchiveFolder()
	local archived = archiveFolder:FindFirstChild(AUTHORED_SHOWCASE_NAME)
	if archived and archived ~= showcase then
		showcase.Name = AUTHORED_SHOWCASE_NAME .. "_Backup"
	end
	showcase.Parent = archiveFolder
	showcase:SetAttribute("ArchivedReason", "ReplacedByAquariumGallery")
	return showcase
end

local function makeTankPart(parent, name, size, cframe, color, material, transparency, canCollide)
	local part = makePart(parent, name, size, cframe, color, material, transparency)
	part.CanCollide = canCollide == true
	part.CanQuery = canCollide == true
	return part
end

local function makeClassicPlaceholderTank(bay, slotNumber)
	local existing = bay:FindFirstChild("GalleryTank")
	if existing then
		existing:Destroy()
	end

	local mountCFrame = getTankMountCFrame(bay)
	-- Build at the origin so the imported Classic theme and the procedural tank
	-- share one coordinate space, then rotate the completed tank into its bay.
	local buildCFrame = CFrame.identity
	local tank = Instance.new("Model")
	tank.Name = "GalleryTank"
	tank:SetAttribute("GalleryPlaceholder", true)
	tank:SetAttribute("ReplaceWhenPlayerJoins", true)
	tank:SetAttribute("Theme", "Classic")
	tank:SetAttribute("SlotIndex", slotNumber)
	tank:SetAttribute("GalleryTankLayoutVersion", GALLERY_TANK_LAYOUT_VERSION)
	tank:SetAttribute("GalleryAssemblyLifted", true)
	tank:SetAttribute("GalleryPlatformOffsetY", GALLERY_TANK_PLATFORM_OFFSET_Y)
	tank.Parent = bay

	local width = 24
	local height = 10
	local depth = 10
	local halfWidth = width / 2
	local halfDepth = depth / 2
	local glassY = 6.7
	local frameColor = Color3.fromRGB(38, 52, 68)
	local base = makeTankPart(
		tank,
		"AquariumBase",
		Vector3.new(32, 1, 18),
		buildCFrame * CFrame.new(0, -2, 0),
		Color3.fromRGB(45, 54, 64),
		Enum.Material.Metal,
		0,
		true
	)
	makeTankPart(
		tank,
		"AquariumBaseTopPlate",
		Vector3.new(26, 0.24, 12),
		buildCFrame * CFrame.new(0, 1.36, 0),
		Color3.fromRGB(128, 143, 154),
		Enum.Material.Metal,
		0,
		true
	)

	for _, panel in ipairs({
		{ "GlassFront", Vector3.new(width, height, 0.25), Vector3.new(0, glassY, -halfDepth - 0.15) },
		{ "GlassBack", Vector3.new(width, height, 0.25), Vector3.new(0, glassY, halfDepth + 0.15) },
		{ "GlassLeft", Vector3.new(0.25, height, depth), Vector3.new(-halfWidth - 0.15, glassY, 0) },
		{ "GlassRight", Vector3.new(0.25, height, depth), Vector3.new(halfWidth + 0.15, glassY, 0) },
	}) do
		makeTankPart(
			tank,
			panel[1],
			panel[2],
			buildCFrame * CFrame.new(panel[3]),
			Color3.fromRGB(75, 165, 220),
			Enum.Material.Glass,
			0.72,
			true
		)
	end

	makeTankPart(
		tank,
		"AquariumDesignerBackground",
		Vector3.new(width - 1.2, height - 1, 0.16),
		buildCFrame * CFrame.new(0, glassY, halfDepth - 0.2),
		Color3.fromRGB(95, 180, 210),
		Enum.Material.SmoothPlastic,
		0.08,
		false
	)
	local water = makeTankPart(
		tank,
		"AquariumWaterSurface",
		Vector3.new(width - 2, 0.18, depth - 2),
		buildCFrame * CFrame.new(0, 9.5, 0),
		Color3.fromRGB(50, 145, 220),
		Enum.Material.Glass,
		0.55,
		false
	)

	for _, corner in ipairs({
		Vector3.new(-halfWidth, glassY, -halfDepth),
		Vector3.new(halfWidth, glassY, -halfDepth),
		Vector3.new(-halfWidth, glassY, halfDepth),
		Vector3.new(halfWidth, glassY, halfDepth),
	}) do
		makeTankPart(
			tank,
			"AquariumFramePost",
			Vector3.new(0.55, height + 0.6, 0.55),
			buildCFrame * CFrame.new(corner),
			frameColor,
			Enum.Material.Metal,
			0,
			true
		)
	end

	local function makeRails(prefix, y)
		makeTankPart(tank, prefix .. "Front", Vector3.new(width + 1, 0.55, 0.55), buildCFrame * CFrame.new(0, y, -halfDepth - 0.25), frameColor, Enum.Material.Metal, 0, true)
		makeTankPart(tank, prefix .. "Back", Vector3.new(width + 1, 0.55, 0.55), buildCFrame * CFrame.new(0, y, halfDepth + 0.25), frameColor, Enum.Material.Metal, 0, true)
		makeTankPart(tank, prefix .. "Left", Vector3.new(0.55, 0.55, depth + 1), buildCFrame * CFrame.new(-halfWidth - 0.25, y, 0), frameColor, Enum.Material.Metal, 0, true)
		makeTankPart(tank, prefix .. "Right", Vector3.new(0.55, 0.55, depth + 1), buildCFrame * CFrame.new(halfWidth + 0.25, y, 0), frameColor, Enum.Material.Metal, 0, true)
	end
	makeRails("AquariumBottomFrame", 1.05)
	makeRails("AquariumTopFrame", 12)

	local light = Instance.new("PointLight")
	light.Name = "ClassicTankLight"
	light.Brightness = 0.35
	light.Range = 18
	light.Color = Color3.fromRGB(180, 225, 255)
	light.Parent = water

	tank.PrimaryPart = base
	local themeApplied, themeError = pcall(function()
		require(script.Parent:WaitForChild("AquariumThemeService")).apply(tank, "Classic", Vector3.zero, {
			tankWidth = width,
			tankHeight = height,
			tankDepth = depth,
		}, true)
	end)
	if not themeApplied then
		warn("Gallery Classic placeholder theme failed", themeError)
	end
	tank:PivotTo(mountCFrame * CFrame.new(0, GALLERY_TANK_PLATFORM_OFFSET_Y, 0))
	hidePhysicalBaySign(bay)
	updateBayHologram(bay, "OPEN AQUARIUM")
	bay:SetAttribute("PlatformOwnerUserId", 0)
	bay:SetAttribute("DisplayedAquariumUserId", 0)
	bay:SetAttribute("TankState", "ClassicPlaceholder")
	return tank
end

local function makeGalleryFoundation(root)
	local existing = root:FindFirstChild("GalleryFoundation")
	local center = getGalleryCenter(root)
	if existing then
		if existing:GetAttribute("GalleryLayoutVersion") == GALLERY_LAYOUT_VERSION
			and existing:GetAttribute("AppliedGalleryCenter") == center
		then
			return existing
		end
		existing:Destroy()
	end

	local foundation = Instance.new("Model")
	foundation.Name = "GalleryFoundation"
	foundation:SetAttribute("Purpose", "Complete aquarium gallery floor and support structure")
	foundation:SetAttribute("GalleryLayoutVersion", GALLERY_LAYOUT_VERSION)
	foundation:SetAttribute("AppliedGalleryCenter", center)
	foundation.Parent = root

	local function foundationPart(name, size, cframe, color, material, shape)
		local part = makePart(foundation, name, size, cframe, color, material)
		if shape then
			part.Shape = shape
		end
		return part
	end

	-- Keep the authored gallery visible exactly as modeled. The foundation only
	-- supplies a quiet, continuous floor and sidewall underneath it; it must not
	-- introduce radial bridges, segmented decks, extra trim, or open-water gaps.
	local foundationDiameter = (GALLERY_RADIUS + 50) * 2
	local deck = foundationPart(
		"GalleryContinuousDeck",
		Vector3.new(2.4, foundationDiameter, foundationDiameter),
		CFrame.new(center + Vector3.new(0, -2.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(44, 55, 70),
		Enum.Material.Slate,
		Enum.PartType.Cylinder
	)
	deck:SetAttribute("Purpose", "Continuous no-gap gallery floor")

	local support = foundationPart(
		"GalleryContinuousSupport",
		Vector3.new(12, foundationDiameter, foundationDiameter),
		CFrame.new(center + Vector3.new(0, -9.45, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(30, 39, 52),
		Enum.Material.Concrete,
		Enum.PartType.Cylinder
	)
	support:SetAttribute("Purpose", "Solid gallery base")

	local entranceCenter = center + Vector3.new(0, -0.55, -ENTRANCE_RADIUS + 10)
	local entranceCFrame = CFrame.lookAt(
		entranceCenter,
		Vector3.new(center.X, entranceCenter.Y, center.Z)
	)
	foundationPart(
		"GalleryEntranceApproach",
		Vector3.new(42, 1.15, 62),
		entranceCFrame,
		Color3.fromRGB(44, 55, 70),
		Enum.Material.Slate
	)
	foundationPart(
		"GalleryEntranceApproachGlowLeft",
		Vector3.new(0.9, 0.24, 62),
		entranceCFrame * CFrame.new(-19.5, 0.72, 0),
		COLORS.cyan,
		Enum.Material.Neon
	)
	foundationPart(
		"GalleryEntranceApproachGlowRight",
		Vector3.new(0.9, 0.24, 62),
		entranceCFrame * CFrame.new(19.5, 0.72, 0),
		COLORS.cyan,
		Enum.Material.Neon
	)

	return foundation
end

local function normalizeGalleryLayout(root)
	local center = getGalleryCenter(root)
	if root:GetAttribute("GalleryLayoutVersion") == GALLERY_LAYOUT_VERSION
		and root:GetAttribute("AppliedGalleryCenter") == center
	then
		return
	end

	for _, slot in getGallerySlots(root) do
		local angle = math.rad((slot.slotNumber - 1) * (360 / BAY_COUNT))
		local position = center + Vector3.new(
			math.sin(angle) * GALLERY_RADIUS,
			0,
			math.cos(angle) * GALLERY_RADIUS
		)
		slot.model:PivotTo(CFrame.lookAt(position, center))

		for _, descendant in ipairs(slot.model:GetDescendants()) do
			if descendant:IsA("BasePart") and belongsToOverlappingBayGeometry(descendant, slot.model) then
				descendant.Transparency = 1
				descendant.CanCollide = false
				descendant.CanQuery = false
			end
		end
	end

	-- The imported walkway pieces pivot around the Blender scene origin. Move the
	-- complete authored ring to the live gallery center without changing any of
	-- its mesh geometry, then rotate each segment by its original 30-degree step.
	for walkwayNumber = 1, BAY_COUNT do
		local walkway = root:FindFirstChild(string.format("Walkway%02d", walkwayNumber), true)
			or root:FindFirstChild(string.format("AquariumGalleryWalkway%02d", walkwayNumber), true)
		if walkway and walkway:IsA("Model") then
			local angle = math.rad((walkwayNumber - 1) * (360 / BAY_COUNT))
			walkway:PivotTo(CFrame.new(center) * CFrame.Angles(0, angle, 0))
			setModelVisible(walkway, true)
		end
	end

	local featured = root:FindFirstChild("AquariumGalleryFeaturedCenter", true)
		or root:FindFirstChild("GlobalFeaturedAquarium", true)
	if featured and featured:IsA("Model") then
		local mount = featured:FindFirstChild("FeaturedAquariumOrigin", true)
		local targetPosition = center + FEATURED_TANK_ORIGIN_OFFSET
		if mount and mount:IsA("BasePart") then
			local translation = targetPosition - mount.Position
			featured:PivotTo(CFrame.new(translation) * featured:GetPivot())
		else
			featured:PivotTo(CFrame.new(targetPosition))
		end
	end

	root:SetAttribute("GalleryRadius", GALLERY_RADIUS)
	root:SetAttribute("GalleryLayoutVersion", GALLERY_LAYOUT_VERSION)
	root:SetAttribute("AppliedGalleryCenter", center)
end

local function positionAuthoredWorkspaceGallery(root)
	-- The approved gallery is one authored assembly. Moving its bays, walkways,
	-- centerpiece, or foundation independently changes the model and creates the
	-- gaps/bridges seen in the failed migration. Translate the root once instead,
	-- preserving every descendant's authored relative transform.
	local authoredCenter = getGalleryCenter(root)
	local translation = ACTIVE_GALLERY_CENTER - authoredCenter
	if translation.Magnitude > 0.001 then
		root:PivotTo(CFrame.new(translation) * root:GetPivot())
	end

	root:SetAttribute("GalleryCenter", ACTIVE_GALLERY_CENTER)
	root:SetAttribute("AppliedGalleryCenter", ACTIVE_GALLERY_CENTER)
	root:SetAttribute("GalleryRadius", GALLERY_RADIUS)
	root:SetAttribute("GalleryLayoutVersion", GALLERY_LAYOUT_VERSION)
	root:SetAttribute("AuthoredGeometryPreserved", true)
end

local function ensureFeaturedCenter(root)
	local featured = root:FindFirstChild("AquariumGalleryFeaturedCenter", true)
		or root:FindFirstChild("GlobalFeaturedAquarium", true)
	if featured and featured:IsA("Model") then
		return featured
	end

	local assets = ServerStorage:FindFirstChild(ASSET_FOLDER_NAME)
	local importedTemplate = assets and assets:FindFirstChild(IMPORTED_FEATURED_NAME)
	if importedTemplate and importedTemplate:IsA("Model") then
		featured = cloneImportedModel(importedTemplate, root, "AquariumGalleryFeaturedCenter", CFrame.identity)
	elseif makeFeaturedCenter then
		featured = makeFeaturedCenter(root)
	end

	if featured then
		featured:SetAttribute("ReadOnlyDisplay", true)
		-- A newly restored centerpiece still needs the current gallery translation,
		-- even if the surrounding authored gallery already had this layout version.
		root:SetAttribute("GalleryLayoutVersion", nil)
	end
	return featured
end

local function installGalleryDefaults(root)
	local isWorkspaceGallery = root:IsDescendantOf(workspace)
	local showcaseSource
	if isWorkspaceGallery then
		root:SetAttribute("IntegrationMode", "GalleryOnly")
		root:SetAttribute("LiveIslandUnchanged", false)
		root:SetAttribute("UsesExistingPortal", true)
		showcaseSource = findLegacyShowcaseSource()
	else
		root:SetAttribute("GalleryCenter", Vector3.zero)
		root:SetAttribute("IntegrationMode", "Prototype")
	end
	ensureFeaturedCenter(root)
	if isWorkspaceGallery then
		positionAuthoredWorkspaceGallery(root)
		-- Keep the restored, approved two-part foundation exactly as authored.
		-- Runtime integration must only add behavior and nonvisual helpers.
		ensureReturnPortal(root, showcaseSource)
		ensureGalleryHubSpawn(root)
		archiveLegacyShowcase(showcaseSource)
	else
		normalizeGalleryLayout(root)
		makeGalleryFoundation(root)
	end
	for _, slot in getGallerySlots(root) do
		local bay = slot.model
		hidePhysicalBaySign(bay)
		restyleAquariumPedestal(bay, "BayPedestal")
		local ownerUserId = tonumber(bay:GetAttribute("PlatformOwnerUserId")) or 0
		local galleryTank = bay:FindFirstChild("GalleryTank")
		if ownerUserId == 0
			and (not galleryTank or galleryTank:GetAttribute("GalleryTankLayoutVersion") ~= GALLERY_TANK_LAYOUT_VERSION)
		then
			makeClassicPlaceholderTank(bay, slot.slotNumber)
		end
		if not bay:FindFirstChild(BAY_HOLOGRAM_NAME) and bay:FindFirstChild("GalleryTank") then
			updateBayHologram(bay, ownerUserId == 0 and "OPEN AQUARIUM" or "PLAYER AQUARIUM")
		end
	end

	local featured = root:FindFirstChild("AquariumGalleryFeaturedCenter", true)
		or root:FindFirstChild("GlobalFeaturedAquarium", true)
	if featured and featured:IsA("Model") then
		setModelVisible(featured:FindFirstChild("FeaturedSignMount", true), false)
		restyleAquariumPedestal(featured, "FeaturedPedestal")
		updateFeaturedHologram(featured)
	end
	root:SetAttribute("DefaultTankTheme", "Classic")
	root:SetAttribute("ReplaceTankOnPlayerJoin", true)
	root:SetAttribute("FoundationComplete", true)
	return root
end

local function makeBay(parent, slotNumber, angle)
	local position = Vector3.new(math.sin(angle) * GALLERY_RADIUS, 0, math.cos(angle) * GALLERY_RADIUS)
	local bayCFrame = CFrame.lookAt(position, Vector3.new(0, 0, 0))
	local bay = Instance.new("Model")
	bay.Name = string.format("AquariumSlot%02d", slotNumber)
	bay:SetAttribute("SlotNumber", slotNumber)
	bay:SetAttribute("PlatformOwnerUserId", 0)
	bay:SetAttribute("DisplayedAquariumUserId", 0)
	bay:SetAttribute("ReadOnlyDisplay", false)
	bay.Parent = parent

	local floor = makePart(
		bay,
		"BayFloor",
		Vector3.new(70, 1, 64),
		bayCFrame * CFrame.new(0, 0, 0),
		COLORS.navy,
		Enum.Material.Slate
	)
	makePart(
		bay,
		"BayPedestal",
		Vector3.new(60, 0.6, 34),
		bayCFrame * CFrame.new(0, 0.8, 8),
		COLORS.stone,
		Enum.Material.Metal
	)
	makePart(
		bay,
		"BayFrontSteps",
		Vector3.new(32, 1.2, 8),
		bayCFrame * CFrame.new(0, -0.35, -35),
		COLORS.stone,
		Enum.Material.Slate
	)
	makePart(
		bay,
		"BayLeftRailing",
		Vector3.new(1, 3, 54),
		bayCFrame * CFrame.new(-34, 2, 3),
		COLORS.stone,
		Enum.Material.Metal
	)
	makePart(
		bay,
		"BayRightRailing",
		Vector3.new(1, 3, 54),
		bayCFrame * CFrame.new(34, 2, 3),
		COLORS.stone,
		Enum.Material.Metal
	)
	makePart(
		bay,
		"BayTrim",
		Vector3.new(68, 0.25, 1),
		bayCFrame * CFrame.new(0, 0.65, -31),
		COLORS.cyan,
		Enum.Material.Neon
	)
	makePart(
		bay,
		"BaySignMount",
		Vector3.new(24, 5, 1),
		bayCFrame * CFrame.new(0, 4, 30),
		COLORS.navy,
		Enum.Material.Metal
	)

	local clearance = makePart(
		bay,
		"AquariumClearanceGuide",
		Vector3.new(60, 0.2, 34),
		bayCFrame * CFrame.new(0, 1.15, 8),
		COLORS.cyan,
		Enum.Material.ForceField,
		0.72
	)
	clearance.CanCollide = false
	clearance:SetAttribute("TemporaryHelper", true)

	makeCollisionProxy(bay, "COL_BayFloor", Vector3.new(70, 1, 64), bayCFrame)
	makeCollisionProxy(bay, "COL_BaySteps", Vector3.new(32, 1.2, 8), bayCFrame * CFrame.new(0, -0.35, -35))
	makeMarker(bay, "AquariumOrigin", bayCFrame * CFrame.new(0, 1.25, 8))
	makeMarker(bay, "OwnerSpawn", bayCFrame * CFrame.new(-22, 3, -20))
	makeMarker(bay, "VisitorSpawn01", bayCFrame * CFrame.new(-18, 3, -17))
	makeMarker(bay, "VisitorSpawn02", bayCFrame * CFrame.new(-6, 3, -17))
	makeMarker(bay, "VisitorSpawn03", bayCFrame * CFrame.new(6, 3, -17))
	makeMarker(bay, "VisitorSpawn04", bayCFrame * CFrame.new(18, 3, -17))
	makeMarker(bay, "SignAnchor", bayCFrame * CFrame.new(0, 4, 29))

	bay.PrimaryPart = floor
	return bay
end

local function makeWalkway(parent, segmentNumber, angle)
	local position = Vector3.new(math.sin(angle) * WALKWAY_RADIUS, 0, math.cos(angle) * WALKWAY_RADIUS)
	local segmentCFrame = CFrame.lookAt(position, Vector3.new(0, 0, 0))
	local segment = Instance.new("Model")
	segment.Name = string.format("AquariumGalleryWalkway%02d", segmentNumber)
	segment.Parent = parent

	local floor = makePart(
		segment,
		"WalkwayFloor",
		Vector3.new(59, 0.6, 22),
		segmentCFrame,
		COLORS.stone,
		Enum.Material.Slate
	)
	makePart(
		segment,
		"WalkwayOuterTrim",
		Vector3.new(59, 0.3, 1),
		segmentCFrame * CFrame.new(0, 0.4, 10.5),
		COLORS.navy,
		Enum.Material.Metal
	)
	makePart(
		segment,
		"WalkwayInnerTrim",
		Vector3.new(59, 0.3, 1),
		segmentCFrame * CFrame.new(0, 0.4, -10.5),
		COLORS.navy,
		Enum.Material.Metal
	)
	makePart(
		segment,
		"WalkwayLighting",
		Vector3.new(52, 0.16, 0.45),
		segmentCFrame * CFrame.new(0, 0.7, -9.8),
		COLORS.cyan,
		Enum.Material.Neon
	)
	makeCollisionProxy(segment, "COL_WalkwayFloor", Vector3.new(59, 0.6, 22), segmentCFrame)
	makeMarker(segment, "WalkwayStart", segmentCFrame * CFrame.new(-29, 1, 0))
	makeMarker(segment, "WalkwayEnd", segmentCFrame * CFrame.new(29, 1, 0))
	segment.PrimaryPart = floor
	return segment
end

makeFeaturedCenter = function(parent)
	local featured = Instance.new("Model")
	featured.Name = "AquariumGalleryFeaturedCenter"
	featured:SetAttribute("ReadOnlyDisplay", true)
	featured.Parent = parent

	local base = makePart(
		featured,
		"FeaturedBase",
		Vector3.new(1.2, 76, 76),
		CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.navy,
		Enum.Material.Slate
	)
	base.Shape = Enum.PartType.Cylinder
	local pedestal = makePart(
		featured,
		"FeaturedPedestal",
		Vector3.new(1, 64, 64),
		CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.stone,
		Enum.Material.Metal
	)
	pedestal.Shape = Enum.PartType.Cylinder
	local trim = makePart(
		featured,
		"FeaturedTrim",
		Vector3.new(0.35, 70, 70),
		CFrame.new(0, 1.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.gold,
		Enum.Material.Neon
	)
	trim.Shape = Enum.PartType.Cylinder
	makePart(
		featured,
		"FeaturedSignMount",
		Vector3.new(28, 6, 1),
		CFrame.new(0, 4, -35),
		COLORS.navy,
		Enum.Material.Metal
	)
	local clearance = makePart(
		featured,
		"FeaturedAquariumClearanceGuide",
		Vector3.new(60, 0.2, 34),
		CFrame.new(0, 1.7, 0),
		COLORS.cyan,
		Enum.Material.ForceField,
		0.72
	)
	clearance.CanCollide = false
	clearance:SetAttribute("TemporaryHelper", true)
	makeMarker(featured, "FeaturedAquariumOrigin", CFrame.new(0, 1.8, 0))
	makeMarker(featured, "FeaturedSignAnchor", CFrame.new(0, 4, -34.5))
	featured.PrimaryPart = base
	return featured
end

local function makeEntrance(parent)
	local entrance = Instance.new("Model")
	entrance.Name = "AquariumGalleryEntrance"
	entrance.Parent = parent
	local entranceCenter = Vector3.new(0, 0, -(GALLERY_RADIUS + 70))

	local floor = makePart(
		entrance,
		"EntranceFloor",
		Vector3.new(64, 1, 44),
		CFrame.new(entranceCenter),
		COLORS.navy,
		Enum.Material.Slate
	)
	makePart(entrance, "EntranceLeftColumn", Vector3.new(5, 20, 5), CFrame.new(entranceCenter + Vector3.new(-25, 10, 0)), COLORS.stone, Enum.Material.Metal)
	makePart(entrance, "EntranceRightColumn", Vector3.new(5, 20, 5), CFrame.new(entranceCenter + Vector3.new(25, 10, 0)), COLORS.stone, Enum.Material.Metal)
	makePart(entrance, "EntranceTop", Vector3.new(56, 5, 5), CFrame.new(entranceCenter + Vector3.new(0, 20, 0)), COLORS.navy, Enum.Material.Metal)
	makePart(entrance, "EntranceTrim", Vector3.new(50, 0.6, 5.4), CFrame.new(entranceCenter + Vector3.new(0, 17.5, 0)), COLORS.cyan, Enum.Material.Neon)
	makePart(entrance, "DirectoryMount", Vector3.new(24, 12, 1), CFrame.new(entranceCenter + Vector3.new(0, 8, 12)), COLORS.navy, Enum.Material.Metal)
	makeCollisionProxy(entrance, "COL_EntranceFloor", Vector3.new(64, 1, 44), CFrame.new(entranceCenter))
	makeMarker(entrance, "GallerySpawn", CFrame.lookAt(entranceCenter + Vector3.new(0, 3, -12), Vector3.new(0, 3, 0)))
	makeMarker(entrance, "DirectoryAnchor", CFrame.new(entranceCenter + Vector3.new(0, 8, 11.5)))
	entrance.PrimaryPart = floor
	return entrance
end

function AquariumGalleryPrototypeService.ensure()
	local existing = ServerStorage:FindFirstChild(PROTOTYPE_NAME)
	if existing then
		return existing
	end

	local prototype = Instance.new("Model")
	prototype.Name = PROTOTYPE_NAME
	prototype:SetAttribute("PrototypeOnly", true)
	prototype:SetAttribute("LiveIslandUnchanged", true)
	prototype:SetAttribute("BayCount", BAY_COUNT)
	prototype:SetAttribute("GalleryRadius", GALLERY_RADIUS)
	prototype:SetAttribute("GalleryCenter", Vector3.zero)
	prototype:SetAttribute("BlenderAssetContract", "AquariumGallery_ModularKit")
	prototype:SetAttribute("EntranceStrategy", "UseExistingPortal")

	if not buildFromImportedAssets(prototype) then
		local slots = Instance.new("Folder")
		slots.Name = "Slots"
		slots.Parent = prototype
		local walkways = Instance.new("Folder")
		walkways.Name = "Walkways"
		walkways.Parent = prototype

		for slotNumber = 1, BAY_COUNT do
			local angle = math.rad((slotNumber - 1) * (360 / BAY_COUNT))
			makeBay(slots, slotNumber, angle)
			makeWalkway(walkways, slotNumber, angle)
		end

		makeFeaturedCenter(prototype)
		prototype:SetAttribute("AssetSource", "ProceduralFallback")
	end

	installGalleryDefaults(prototype)
	prototype.Parent = ServerStorage
	return prototype
end

function AquariumGalleryPrototypeService.ensureWorkspaceDefaults()
	local gallery = workspace:FindFirstChild(WORKSPACE_GALLERY_NAME)
	if not gallery or not gallery:IsA("Model") then
		local template = AquariumGalleryPrototypeService.ensure()
		gallery = template:Clone()
		gallery.Name = WORKSPACE_GALLERY_NAME
		gallery.Parent = workspace
	end
	return installGalleryDefaults(gallery)
end

function AquariumGalleryPrototypeService.applyAuthoredMigration()
	local gallery = AquariumGalleryPrototypeService.ensureWorkspaceDefaults()
	if not gallery then
		return nil
	end
	gallery:SetAttribute("AuthoredMigrationComplete", true)
	gallery:SetAttribute("AuthoredMigrationVersion", GALLERY_LAYOUT_VERSION)
	return gallery
end

function AquariumGalleryPrototypeService.displayPlayerAquarium(player, sourceAquarium)
	if not player or not sourceAquarium or not sourceAquarium:IsA("Model") then
		return nil
	end

	local gallery = AquariumGalleryPrototypeService.ensureWorkspaceDefaults()
	if not gallery then
		return nil
	end

	local assignedSlot = nil
	for _, slot in getGallerySlots(gallery) do
		local ownerUserId = tonumber(slot.model:GetAttribute("PlatformOwnerUserId")) or 0
		if ownerUserId == player.UserId then
			assignedSlot = slot
			break
		end
		if ownerUserId == 0 and not assignedSlot then
			assignedSlot = slot
		end
	end
	if not assignedSlot then
		return nil
	end

	local bay = assignedSlot.model
	local previousTank = bay:FindFirstChild("GalleryTank")
	if previousTank then
		previousTank:Destroy()
	end

	local displayTank = sourceAquarium:Clone()
	displayTank.Name = "GalleryTank"
	displayTank:SetAttribute("GalleryPlaceholder", false)
	displayTank:SetAttribute("DisplayedAquariumUserId", player.UserId)
	displayTank:SetAttribute("SlotIndex", assignedSlot.slotNumber)
	for _, descendant in ipairs(displayTank:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanTouch = false
		end
	end
	displayTank.Parent = bay
	displayTank:PivotTo(getTankMountCFrame(bay) * CFrame.new(0, GALLERY_TANK_PLATFORM_OFFSET_Y, 0))
	hidePhysicalBaySign(bay)
	updateBayHologram(bay, player.DisplayName .. "'s Aquarium")

	bay:SetAttribute("PlatformOwnerUserId", player.UserId)
	bay:SetAttribute("DisplayedAquariumUserId", player.UserId)
	bay:SetAttribute("TankState", "PlayerAquarium")
	player:SetAttribute("AquariumGallerySlot", assignedSlot.slotNumber)
	return assignedSlot.slotNumber
end

function AquariumGalleryPrototypeService.playerHasAssignedBay(player)
	if not player then
		return false
	end

	local gallery = AquariumGalleryPrototypeService.ensureWorkspaceDefaults()
	if not gallery or not gallery:IsA("Model") then
		return false
	end

	for _, slot in getGallerySlots(gallery) do
		if tonumber(slot.model:GetAttribute("PlatformOwnerUserId")) == player.UserId then
			return true
		end
	end
	return false
end

function AquariumGalleryPrototypeService.getPlayerViewCFrame(userId, visitorIndex)
	userId = math.floor(tonumber(userId) or 0)
	if userId <= 0 then
		return nil
	end

	local gallery = workspace:FindFirstChild(WORKSPACE_GALLERY_NAME)
	if not gallery then
		return nil
	end

	for _, slot in getGallerySlots(gallery) do
		local bay = slot.model
		if tonumber(bay:GetAttribute("PlatformOwnerUserId")) == userId then
			local markerNumber = math.clamp(math.floor(tonumber(visitorIndex) or 1), 1, 4)
			local marker = bay:FindFirstChild(string.format("VisitorSpawn%02d", markerNumber), true)
				or bay:FindFirstChild("OwnerSpawn", true)
			local tank = bay:FindFirstChild("GalleryTank")
			if marker and marker:IsA("BasePart") and tank and tank:IsA("Model") then
				local tankCFrame, tankSize = tank:GetBoundingBox()
				return CFrame.lookAt(
					marker.Position + Vector3.new(0, 2.5, 0),
					tankCFrame.Position + Vector3.new(0, math.min(5, tankSize.Y * 0.3), 0)
				)
			end
			return bay:GetPivot() * CFrame.new(0, 4, -20)
		end
	end
	return nil
end

function AquariumGalleryPrototypeService.setFeaturedLabel(labelText)
	local gallery = workspace:FindFirstChild(WORKSPACE_GALLERY_NAME)
	if not gallery or not gallery:IsA("Model") then
		return false
	end
	local featured = gallery:FindFirstChild("AquariumGalleryFeaturedCenter", true)
		or gallery:FindFirstChild("GlobalFeaturedAquarium", true)
	if not featured or not featured:IsA("Model") then
		return false
	end

	local hologram = featured:FindFirstChild(FEATURED_HOLOGRAM_NAME)
	local label = hologram and hologram:FindFirstChild("FeaturedLabel", true)
	if not label or not label:IsA("TextLabel") then
		updateFeaturedHologram(featured)
		hologram = featured:FindFirstChild(FEATURED_HOLOGRAM_NAME)
		label = hologram and hologram:FindFirstChild("FeaturedLabel", true)
	end
	if label and label:IsA("TextLabel") then
		label.Text = tostring(labelText or "FEATURED AQUARIUM")
		return true
	end
	return false
end

function AquariumGalleryPrototypeService.releasePlayer(player)
	if not player then
		return false
	end

	local gallery = workspace:FindFirstChild(WORKSPACE_GALLERY_NAME)
	if not gallery or not gallery:IsA("Model") then
		return false
	end

	for _, slot in getGallerySlots(gallery) do
		local bay = slot.model
		if tonumber(bay:GetAttribute("PlatformOwnerUserId")) == player.UserId then
			makeClassicPlaceholderTank(bay, slot.slotNumber)
			player:SetAttribute("AquariumGallerySlot", nil)
			return true
		end
	end
	return false
end

return AquariumGalleryPrototypeService
