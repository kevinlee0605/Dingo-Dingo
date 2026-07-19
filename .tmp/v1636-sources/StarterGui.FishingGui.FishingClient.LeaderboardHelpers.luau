local LeaderboardHelpers = {}

function LeaderboardHelpers.getPlayerLeaderstat(targetPlayer, statName)
	local leaderstats = targetPlayer:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(statName)
	if stat and stat:IsA("ValueBase") then
		return stat.Value
	end

	return 0
end

function LeaderboardHelpers.formatCompactNumber(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000):gsub("%.0M", "M")
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000):gsub("%.0K", "K")
	end

	return tostring(value)
end

return LeaderboardHelpers
