local Workspace = game:GetService("Workspace")

local removableNames = {
	LimestoneLobbyBoundaries = true,
	InvisibleLobbyBoundaries = true,
}

local removablePrefixes = {
	"BlueLobbyBoundary",
	"InvisibleLobbyWall",
	"InvisibleLobbyFallbackWall",
	"LimestoneLobbyBoundary",
}

local function hasRemovablePrefix(name)
	for _, prefix in ipairs(removablePrefixes) do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end

	return false
end

local targets = {}

for _, descendant in ipairs(Workspace:GetDescendants()) do
	if removableNames[descendant.Name] or hasRemovablePrefix(descendant.Name) then
		table.insert(targets, descendant)
	end
end

for _, target in ipairs(targets) do
	if target.Parent then
		target:Destroy()
	end
end

print(("Removed %d wrong lobby blue wall object(s)."):format(#targets))
