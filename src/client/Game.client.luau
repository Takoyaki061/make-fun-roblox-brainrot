-- Game.client.luau
-- Keyboard shortcuts only. Buying uses the on-screen E prompt; the
-- keys below fire an action string at the server through
-- BrainrotAction, and the server validates everything.
--
--   F -> Slap      L -> Lock base
--   U -> Upgrade   R -> Rebirth
--
-- gameProcessedEvent is checked so typing in chat never fires an action.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ActionRemote = ReplicatedStorage:WaitForChild("BrainrotAction")

local KEYS = {
	[Enum.KeyCode.F] = "Slap",
	[Enum.KeyCode.L] = "Lock",
	[Enum.KeyCode.U] = "Upgrade",
	[Enum.KeyCode.R] = "Rebirth",
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local action = KEYS[input.KeyCode]
	if action then
		ActionRemote:FireServer(action)
	end
end)

-- Keep the local player reference warm so the script stays alive and
-- the client is ready the moment the server sends its first snapshot.
local _player = Players.LocalPlayer
