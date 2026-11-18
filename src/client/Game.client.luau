-- Game.client.luau — Brainrot Bazaar client input.
-- One script, one job: keyboard shortcuts for the actions that matter in a
-- chase (F slap, L lock base). Buying uses the on-screen E prompt on each
-- brainrot; the buttons live in Hud.client.luau. Nothing here touches money:
-- every action is just a request the server validates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local actionEvent = ReplicatedStorage:WaitForChild("BrainrotAction")

-- Fire one action at the server. The server checks cooldowns and costs.
local function sendAction(action)
	actionEvent:FireServer(action)
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		sendAction("Slap")
	elseif input.KeyCode == Enum.KeyCode.L then
		sendAction("Lock")
	end
end)
