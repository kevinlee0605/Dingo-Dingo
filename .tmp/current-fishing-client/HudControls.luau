local HudControls = {}

local modulesFolder = script.Parent:WaitForChild("HudControlsModules")

local CoinsHud = require(modulesFolder:WaitForChild("CoinsHud"))
local XPBarHud = require(modulesFolder:WaitForChild("XPBarHud"))
local TopButtonsHud = require(modulesFolder:WaitForChild("TopButtonsHud"))
local SettingsPanelHud = require(modulesFolder:WaitForChild("SettingsPanelHud"))
local BottomControlsHud = require(modulesFolder:WaitForChild("BottomControlsHud"))

local function formatNumber(value)
	local number = math.floor(tonumber(value) or 0)
	local sign = number < 0 and "-" or ""
	local digits = tostring(math.abs(number))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return sign .. formatted
end

function HudControls.create(deps)
	print("HudControls creating HUD")

	local refs = {}
	local maxLevel = tonumber(deps.maxLevel) or 30

	CoinsHud.create(deps, refs, formatNumber)
	XPBarHud.create(deps, refs, formatNumber, maxLevel)
	TopButtonsHud.create(deps, refs)
	SettingsPanelHud.create(deps, refs)
	BottomControlsHud.create(deps, refs)

	print("New HUD loaded:", deps.scriptFullName)

	if refs.updateQuestBadgeCount then
		refs.updateQuestBadgeCount(0)
	end

	if refs.updateCoins then
		refs.updateCoins(0)
	end

	if refs.updateXP then
		refs.updateXP(nil)
	end

	return refs
end

return HudControls
