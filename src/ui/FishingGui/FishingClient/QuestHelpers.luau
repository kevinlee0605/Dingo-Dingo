local QuestHelpers = {}

function QuestHelpers.create(deps)
	local GameConfig = deps.GameConfig
	local getState = deps.getState
	local helpers = {}

	function helpers.formatQuestReward(reward)
		local parts = {}
		reward = type(reward) == "table" and reward or {}

		if (tonumber(reward.coins) or 0) > 0 then
			table.insert(parts, tostring(reward.coins) .. " Coins")
		end
		if (tonumber(reward.xp) or 0) > 0 then
			table.insert(parts, tostring(reward.xp) .. " Fishing XP")
		end
		if type(reward.bait) == "table" then
			for _, baitId in ipairs(GameConfig.BaitOrder) do
				local amount = tonumber(reward.bait[baitId]) or 0
				if amount > 0 then
					local bait = GameConfig.Baits[baitId]
					table.insert(parts, tostring(amount) .. " " .. (bait and bait.displayName or baitId))
				end
			end
		end
		if type(reward.decorations) == "table" then
			for _, amount in pairs(reward.decorations) do
				amount = tonumber(amount) or 0
				if amount > 0 then
					table.insert(parts, amount > 1 and (tostring(amount) .. " Aquarium Decorations") or "Aquarium Decoration")
				end
			end
		end

		if #parts == 0 then
			return "Reward ready"
		end

		return table.concat(parts, " | ")
	end

	function helpers.getQuestPeriod(periodName)
		local state = getState()
		local quests = state and state.Quests
		return quests and quests[periodName] or nil
	end

	return helpers
end

return QuestHelpers
