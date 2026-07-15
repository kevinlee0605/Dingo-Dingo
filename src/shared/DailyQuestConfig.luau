return {
	period = "Daily",
	quests = {
		{
			id = "daily_catch_any_10",
			coinMultiplier = 8,
			title = "Daily Catch",
			description = "Catch any 10 fish.",
			objectiveType = "catch_any",
			target = 10,
			reward = {
				xp = 100,
			},
		},
		{
			id = "daily_specific_fish_5",
			coinMultiplier = 10,
			title = "Focused Catch",
			description = "Catch 5 selected fish.",
			objectiveType = "catch_specific_fish",
			target = 5,
			specificFishPools = {
				LilyshoreIsland = { "Carp", "Bass" },
				RiverbendIsland = { "Salmon", "Pike" },
				CoralCoastIsland = { "Tuna", "Swordfish" },
			},
			reward = {
				bait = {
					FreshBait = 2,
				},
			},
		},
		{
			id = "daily_epic_fish_1",
			coinMultiplier = 14,
			title = "Epic Moment",
			description = "Catch 1 selected Epic fish.",
			objectiveType = "catch_specific_fish",
			target = 1,
			rarity = "Epic",
			reward = {
				bait = {
					LuckyBait = 1,
				},
			},
		},
		{
			id = "daily_perfect_cast_5",
			coinMultiplier = 8,
			title = "Perfect Casts",
			description = "Land 5 perfect casts.",
			objectiveType = "perfect_cast",
			target = 5,
			reward = {
				xp = 150,
			},
		},
	},
}
