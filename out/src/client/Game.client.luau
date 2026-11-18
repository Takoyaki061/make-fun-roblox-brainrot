-- Game.client.luau — Brainrot Bazaar client input.
-- One script, one job: keyboard shortcuts for the actions that matter in a
-- chase (F slap, L lock base) and at the base (U upgrade, R rebirth).
-- Buying uses the on-screen E prompt on each brainrot; the buttons live in
-- Hud.client.luau. Nothing here touches money: every action is just a
-- request the server validates. Keys are read with InputBegan and the
-- gameProcessedEvent guard, so typing in chat never fires an action.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local actionEvent = ReplicatedStorage:WaitForChild("BrainrotAction")

-- Fire one action at the server. The server checks cooldowns and costs.
local function sendAction(action)
	actionEvent:FireServer(action)
end

-- One key per action, so a player mid-chase never has to find the mouse.
local KEY_ACTIONS = {
	[Enum.KeyCode.F] = "Slap",
	[Enum.KeyCode.L] = "Lock",
	[Enum.KeyCode.U] = "Upgrade",
	[Enum.KeyCode.R] = "Rebirth",
}

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	local action = KEY_ACTIONS[input.KeyCode]
	if action then
		sendAction(action)
	end
end)
