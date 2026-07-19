local RemoteActions = {}

function RemoteActions.create(deps)
	local Remotes = deps.Remotes
	local BaitAction = deps.BaitAction
	local QuestAction = deps.QuestAction
	local ShopAction = deps.ShopAction

	local actions = {}

	function actions.fireBaitAction(action, baitId)
		if not BaitAction then
			BaitAction = Remotes:FindFirstChild("BaitAction")
		end

		if BaitAction then
			BaitAction:FireServer(action, baitId)
		else
			warn("BaitAction remote was not available; bait shop actions are disabled until remotes resync.")
		end
	end

	function actions.fireQuestAction(action, periodName, questId)
		if not QuestAction then
			QuestAction = Remotes:FindFirstChild("QuestAction")
		end

		if QuestAction then
			QuestAction:FireServer(action, periodName, questId)
		else
			warn("QuestAction remote was not available; quest claiming is disabled until remotes resync.")
		end
	end

	function actions.fireShopAction(action, category, itemKey, payload)
		if not ShopAction then
			ShopAction = Remotes:FindFirstChild("ShopAction")
		end

		if ShopAction then
			ShopAction:FireServer(action, category, itemKey, payload)
		else
			warn("ShopAction remote was not available; shop actions are disabled until remotes resync.")
		end
	end

	return actions
end

return RemoteActions
