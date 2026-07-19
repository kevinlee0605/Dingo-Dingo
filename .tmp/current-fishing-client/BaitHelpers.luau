local BaitHelpers = {}

function BaitHelpers.create(deps)
	local GameConfig = deps.GameConfig
	local getState = deps.getState
	local helpers = {}

	function helpers.getBaitData(baitId)
		return GameConfig.getBait(baitId)
	end

	function helpers.getBaitCount(baitId)
		local state = getState()
		if not state then
			return 0
		end

		baitId = baitId or GameConfig.BasicBaitId
		if baitId == GameConfig.BasicBaitId then
			return math.huge
		end

		local inventory = state.BaitInventory or {}
		return math.max(0, math.floor(tonumber(inventory[baitId]) or 0))
	end

	function helpers.getBaitCountText(baitId, count)
		if baitId == GameConfig.BasicBaitId or count == math.huge or count == -1 then
			return "Unlimited"
		end

		return tostring(count or helpers.getBaitCount(baitId)) .. " left"
	end

	function helpers.getEquippedBaitDisplay()
		local state = getState()
		local baitId = state and state.EquippedBait or GameConfig.BasicBaitId
		local bait = helpers.getBaitData(baitId)
		local remaining = state and state.EquippedBaitRemaining or -1

		return "Bait: " .. bait.displayName .. " (" .. helpers.getBaitCountText(baitId, remaining) .. ")"
	end

	function helpers.getBaitEffectText(bait)
		local parts = {}

		if (tonumber(bait.biteSpeedMultiplier) or 1) < 1 then
			table.insert(parts, "faster bites")
		end
		if (tonumber(bait.rareChanceBonus) or 0) > 0 then
			table.insert(parts, "+" .. tostring(math.floor((bait.rareChanceBonus or 0) * 100)) .. "% rare luck")
		end
		if (tonumber(bait.valueMultiplier) or 1) > 1 then
			table.insert(parts, "+" .. tostring(math.floor(((bait.valueMultiplier or 1) - 1) * 100 + 0.5)) .. "% value")
		end
		if (tonumber(bait.xpMultiplier) or 1) > 1 then
			table.insert(parts, "+" .. tostring(math.floor(((bait.xpMultiplier or 1) - 1) * 100 + 0.5)) .. "% XP")
		end

		if #parts == 0 then
			return bait.description or "Default fishing."
		end

		return table.concat(parts, " | ")
	end

	return helpers
end

return BaitHelpers
