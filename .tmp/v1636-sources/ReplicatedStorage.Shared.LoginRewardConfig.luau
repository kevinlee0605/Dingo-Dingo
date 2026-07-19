local LoginRewardConfig = {}

LoginRewardConfig.MilestoneDays = {
	[7] = true,
	[14] = true,
	[21] = true,
}

LoginRewardConfig.FinalDecorationPool = {
	"Coral",
	"Seaweed",
	"TreasureChest",
	"Rocks",
	"ShipwreckPiece",
	"BubbleMachine",
	"Clams",
	"Driftwood",
}

local VALID_CYCLE_LENGTHS = {
	[28] = true,
	[29] = true,
	[30] = true,
	[31] = true,
}

local function nonnegativeInteger(value)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		return 0
	end
	return math.max(0, math.floor(number))
end

function LoginRewardConfig.IsLeapYear(year)
	year = math.floor(tonumber(year) or 0)
	return year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0)
end

function LoginRewardConfig.DaysInMonth(year, month)
	year = math.floor(tonumber(year) or 1970)
	month = math.clamp(math.floor(tonumber(month) or 1), 1, 12)
	if month == 2 then
		return LoginRewardConfig.IsLeapYear(year) and 29 or 28
	end
	if month == 4 or month == 6 or month == 9 or month == 11 then
		return 30
	end
	return 31
end

function LoginRewardConfig.UtcNow(timestamp)
	local date = os.date("!*t", timestamp)
	return {
		year = date.year,
		month = date.month,
		day = date.day,
		hour = date.hour,
		min = date.min,
		sec = date.sec,
	}
end

function LoginRewardConfig.MonthKey(date)
	return string.format("%04d-%02d", date.year, date.month)
end

function LoginRewardConfig.DateKey(date)
	return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

function LoginRewardConfig.IsValidMonthKey(value)
	if type(value) ~= "string" then
		return false
	end
	local yearText, monthText = string.match(value, "^(%d%d%d%d)%-(%d%d)$")
	local year = tonumber(yearText)
	local month = tonumber(monthText)
	return year ~= nil and year >= 1970 and month ~= nil and month >= 1 and month <= 12
end

function LoginRewardConfig.IsValidDateKey(value)
	if value == "" then
		return true
	end
	if type(value) ~= "string" then
		return false
	end
	local yearText, monthText, dayText = string.match(value, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	local year = tonumber(yearText)
	local month = tonumber(monthText)
	local day = tonumber(dayText)
	return year ~= nil
		and year >= 1970
		and month ~= nil
		and month >= 1
		and month <= 12
		and day ~= nil
		and day >= 1
		and day <= LoginRewardConfig.DaysInMonth(year, month)
end

function LoginRewardConfig.MakeDefault(now)
	now = now or LoginRewardConfig.UtcNow()
	return {
		CurrentDay = 1,
		DaysInCycle = LoginRewardConfig.DaysInMonth(now.year, now.month),
		CycleMonthKey = LoginRewardConfig.MonthKey(now),
		LastClaimDate = "",
		CompletedCycles = 0,
	}
end

function LoginRewardConfig.Normalize(value, now)
	now = now or LoginRewardConfig.UtcNow()
	local defaults = LoginRewardConfig.MakeDefault(now)
	local source = type(value) == "table" and value or {}
	local daysInCycle = nonnegativeInteger(source.DaysInCycle)
	if not VALID_CYCLE_LENGTHS[daysInCycle] then
		daysInCycle = defaults.DaysInCycle
	end

	local monthKey = source.CycleMonthKey
	if not LoginRewardConfig.IsValidMonthKey(monthKey) then
		monthKey = defaults.CycleMonthKey
	end

	local lastClaimDate = source.LastClaimDate
	if not LoginRewardConfig.IsValidDateKey(lastClaimDate) then
		lastClaimDate = ""
	end

	return {
		CurrentDay = math.clamp(nonnegativeInteger(source.CurrentDay), 1, daysInCycle),
		DaysInCycle = daysInCycle,
		CycleMonthKey = monthKey,
		LastClaimDate = lastClaimDate,
		CompletedCycles = nonnegativeInteger(source.CompletedCycles),
	}
end

function LoginRewardConfig.GetReward(day, daysInCycle, economyValue)
	day = math.clamp(math.floor(tonumber(day) or 1), 1, math.max(1, math.floor(tonumber(daysInCycle) or 28)))
	daysInCycle = math.max(day, math.floor(tonumber(daysInCycle) or 28))
	economyValue = math.max(0, tonumber(economyValue) or 0)

	local reward = {
		day = day,
		coins = math.round(2 * economyValue),
		bait = { FreshBait = 2 },
		seaStars = 0,
		resourceCount = 0,
		isMilestone = false,
		isFinal = false,
	}

	if day == daysInCycle then
		reward.coins = math.round(30 * economyValue)
		reward.bait = { MysticBait = 5 }
		reward.seaStars = 30
		reward.cycleSeaStars = 75
		reward.decorationReward = true
		reward.isFinal = true
		reward.isMilestone = true
	elseif day == 7 then
		reward.coins = math.round(8 * economyValue)
		reward.bait = { LuckyBait = 5 }
		reward.seaStars = 10
		reward.resourceCount = 3
		reward.isMilestone = true
	elseif day == 14 then
		reward.coins = math.round(12 * economyValue)
		reward.bait = { MysticBait = 3 }
		reward.seaStars = 15
		reward.isMilestone = true
	elseif day == 21 then
		reward.coins = math.round(18 * economyValue)
		reward.bait = {}
		reward.seaStars = 20
		reward.resourceCount = 6
		reward.guaranteeUncommon = true
		reward.isMilestone = true
	elseif day % 3 == 0 then
		reward.bait = { LuckyBait = 1 }
	end

	return reward
end

function LoginRewardConfig.FormatReward(reward)
	local parts = {}
	if (reward.coins or 0) > 0 then
		table.insert(parts, tostring(reward.coins) .. " Coins")
	end
	for _, baitId in ipairs({ "FreshBait", "LuckyBait", "MysticBait" }) do
		local amount = reward.bait and reward.bait[baitId] or 0
		if amount > 0 then
			local displayName = string.gsub(baitId, "Bait$", " Bait")
			table.insert(parts, tostring(amount) .. " " .. displayName)
		end
	end
	if (reward.seaStars or 0) > 0 then
		table.insert(parts, tostring(reward.seaStars) .. " Sea Stars")
	end
	if (reward.cycleSeaStars or 0) > 0 then
		table.insert(parts, tostring(reward.cycleSeaStars) .. " Cycle Sea Stars")
	end
	if (reward.resourceCount or 0) > 0 then
		table.insert(parts, tostring(reward.resourceCount) .. " weighted resources")
	end
	if reward.decorationReward then
		table.insert(parts, "1 new aquarium decoration (or 10 Sea Stars)")
	end
	return table.concat(parts, " • ")
end

function LoginRewardConfig.Validate()
	assert(LoginRewardConfig.DaysInMonth(2025, 3) == 31, "March must have 31 days")
	assert(LoginRewardConfig.DaysInMonth(2025, 4) == 30, "April must have 30 days")
	assert(LoginRewardConfig.DaysInMonth(2025, 2) == 28, "Normal February must have 28 days")
	assert(LoginRewardConfig.DaysInMonth(2024, 2) == 29, "Leap-year February must have 29 days")
	assert(LoginRewardConfig.GetReward(7, 31, 25).resourceCount == 3, "Day 7 reward is incorrect")
	assert(LoginRewardConfig.GetReward(14, 31, 25).bait.MysticBait == 3, "Day 14 reward is incorrect")
	assert(LoginRewardConfig.GetReward(21, 31, 25).guaranteeUncommon == true, "Day 21 guarantee is missing")
	local final = LoginRewardConfig.GetReward(30, 30, 25)
	assert(final.isFinal and final.seaStars == 30 and final.cycleSeaStars == 75, "Final reward is incorrect")
	return true
end

return LoginRewardConfig
