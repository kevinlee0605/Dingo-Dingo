return {
	period = "Weekly",
	quests = {
		{
			id = "weekly_biome_species",
			title = "Island Collector",
			description = "Catch every fish species on the selected island.",
			objectiveType = "discover_biome_species",
			reward = {
				coins = 10000,
				bait = {
					LuckyBait = 5,
				},
				decorations = {
					BiomeCollectorTrophy = 1,
				},
			},
		},
		{
			id = "weekly_rare_fish_10",
			title = "Rare Haul",
			description = "Catch 10 Rare fish.",
			objectiveType = "catch_rarity",
			rarity = "Rare",
			target = 10,
			reward = {
				coins = 7500,
				bait = {
					GlowBait = 3,
				},
			},
		},
		{
			id = "weekly_epic_fish_3",
			title = "Epic Streak",
			description = "Catch 3 Epic fish.",
			objectiveType = "catch_rarity",
			rarity = "Epic",
			target = 3,
			reward = {
				coins = 12500,
				bait = {
					MysticBait = 2,
				},
			},
		},
	},
}
