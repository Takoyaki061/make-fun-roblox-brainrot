-- Game.client.luau — Brainrot Bazaar: keyboard shortcuts only.
-- F slaps, L locks the base, U buys a Golden Conveyor upgrade, R rebirths.
-- Each fires its action string at the server through BrainrotAction; the
-- server validates everything. Buying uses the on-screen E prompt, not a key.
-- gameProcessedEvent guards every handler so typing in chat never fires one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BrainrotAction = ReplicatedStorage:WaitForChild("BrainrotAction")

local ACTIONS = {
	[Enum.KeyCode.F] = "Slap",
	[Enum.KeyCode.L] = "Lock",
	[Enum.KeyCode.U] = "Upgrade",
	[Enum.KeyCode.R] = "Rebirth",
}

local player = Players.LocalPlayer

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	local action = ACTIONS[input.KeyCode]
	if action then
		BrainrotAction:FireServer(action)
	end
end)

-- Keep the player out of the top-left corner's way: nothing here draws UI.
-- (Roblox's menu buttons live there; the HUD in Hud.client.luau stays clear.)
print("Brainrot Bazaar client controls ready: F slap, L lock, U upgrade, R rebirth.")
