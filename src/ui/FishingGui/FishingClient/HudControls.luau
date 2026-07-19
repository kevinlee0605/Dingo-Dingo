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
	local screenGui = deps.screenGui

	-- AuthoredUiV2 keeps compatibility-sensitive HUD hosts persisted in
	-- StarterGui. Most are direct FishingGui children; the always-on four-button
	-- row lives in TopHudGui so it remains above every modal without runtime
	-- reparenting. Feature modules bind those saved instances only.
	deps.authoredUiV2 = screenGui
		and screenGui:GetAttribute("AuthoredUiV2") == true
		or false
	deps.findAuthoredHost = function(name, className)
		if not deps.authoredUiV2 or not screenGui then
			return nil
		end

		local host = nil
		if name == "TopButtonsFrame" then
			local playerGui = screenGui.Parent
			local topHudGui = playerGui and playerGui:WaitForChild("TopHudGui", 30)
			host = topHudGui and topHudGui:FindFirstChild(name)
		else
			host = screenGui:FindFirstChild(name)
		end
		if not host then
			warn(string.format(
				"[HudControls] AuthoredUiV2 host %s is missing; using the legacy fallback",
				name
			))
			return nil
		end

		if className and not host:IsA(className) then
			warn(string.format(
				"[HudControls] AuthoredUiV2 host %s is a %s, expected %s; using the legacy fallback",
				name,
				host.ClassName,
				className
			))
			return nil
		end

		return host
	end

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
