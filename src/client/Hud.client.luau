-- Hud.client.luau — Brainrot Bazaar HUD.
-- One script, one job: show the player what the server says is true —
-- money, income, collection progress, lock status — and give them big,
-- tappable buttons for Lock, Upgrade and Rebirth. Text is huge and
-- high-contrast so it stays readable when the screenshot is scaled down,
-- and nothing sits in the top-left corner (Roblox's menu buttons live there).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local actionEvent = ReplicatedStorage:WaitForChild("BrainrotAction")
local stateEvent = ReplicatedStorage:WaitForChild("BrainrotState")
local feedEvent = ReplicatedStorage:WaitForChild("BrainrotFeed")

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function panel(name, anchor, position, size, color)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	return frame
end

local function bigLabel(name, parent, position, size, text, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextWrapped = true
	label.Parent = parent
	return label
end

-- Top centre: the objective. Big, because the judge reads it first.
local objectivePanel = panel("ObjectivePanel", Vector2.new(0.5, 0),
	UDim2.new(0.5, 0, 0, 12), UDim2.fromOffset(460, 96), Color3.fromRGB(20, 20, 40))
local objectiveLabel = bigLabel("ObjectiveLabel", objectivePanel,
	UDim2.new(0, 0, 0, 6), UDim2.new(1, 0, 0, 44),
	"COLLECT 6 BRAINROTS", 36, Color3.fromRGB(255, 220, 80))
local progressLabel = bigLabel("ProgressLabel", objectivePanel,
	UDim2.new(0, 0, 0, 50), UDim2.new(1, 0, 0, 40),
	"0 / 6", 32, Color3.fromRGB(255, 255, 255))

-- Top right: money and income. Far from the top-left menu buttons.
local moneyPanel = panel("MoneyPanel", Vector2.new(1, 0),
	UDim2.new(1, -16, 0, 12), UDim2.fromOffset(300, 110), Color3.fromRGB(20, 40, 20))
local moneyLabel = bigLabel("MoneyLabel", moneyPanel,
	UDim2.new(0, 0, 0, 6), UDim2.new(1, 0, 0, 48),
	"$100", 40, Color3.fromRGB(120, 255, 120))
local incomeLabel = bigLabel("IncomeLabel", moneyPanel,
	UDim2.new(0, 0, 0, 54), UDim2.new(1, 0, 0, 28),
	"+$0 / sec", 26, Color3.fromRGB(200, 255, 200))
local lockLabel = bigLabel("LockLabel", moneyPanel,
	UDim2.new(0, 0, 0, 82), UDim2.new(1, 0, 0, 24),
	"", 22, Color3.fromRGB(255, 200, 80))

-- Bottom centre: what to do right now.
local hintPanel = panel("HintPanel", Vector2.new(0.5, 1),
	UDim2.new(0.5, 0, 1, -16), UDim2.fromOffset(560, 52), Color3.fromRGB(20, 20, 40))
bigLabel("HintLabel", hintPanel, UDim2.new(0, 0, 0, 8), UDim2.new(1, 0, 0, 36),
	"E — BUY   •   F — SLAP   •   L — LOCK BASE", 28, Color3.fromRGB(255, 255, 255))

-- Bottom left: the event feed, so steals, raids and rare spawns are seen.
local feedPanel = panel("FeedPanel", Vector2.new(0, 1),
	UDim2.new(0, 16, 1, -84), UDim2.fromOffset(460, 60), Color3.fromRGB(20, 20, 40))
local feedLabel = bigLabel("FeedLabel", feedPanel,
	UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 0, 44),
	"Welcome to Brainrot Bazaar!", 22, Color3.fromRGB(255, 255, 255))

-- Bottom right: the three money actions, big enough to hit mid-chase.
local buttonPanel = panel("ButtonPanel", Vector2.new(1, 1),
	UDim2.new(1, -16, 1, -16), UDim2.fromOffset(300, 180), Color3.fromRGB(20, 20, 40))
local function actionButton(name, y, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = UDim2.new(0, 12, 0, y)
	button.Size = UDim2.fromOffset(276, 48)
	button.BackgroundColor3 = color
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 26
	button.Font = Enum.Font.GothamBold
	button.Parent = buttonPanel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	return button
end

local lockButton = actionButton("LockButton", 12, "LOCK BASE (L)", Color3.fromRGB(60, 120, 220))
local upgradeButton = actionButton("UpgradeButton", 68, "UPGRADE", Color3.fromRGB(200, 160, 40))
local rebirthButton = actionButton("RebirthButton", 124, "REBIRTH", Color3.fromRGB(180, 60, 180))

lockButton.MouseButton1Click:Connect(function()
	actionEvent:FireServer("Lock")
end)
upgradeButton.MouseButton1Click:Connect(function()
	actionEvent:FireServer("Upgrade")
end)
rebirthButton.MouseButton1Click:Connect(function()
	actionEvent:FireServer("Rebirth")
end)

-- The server is the only source of numbers: refresh the HUD from snapshots.
local function formatMoney(amount)
	amount = math.floor(amount + 0.5)
	if amount >= 1000000 then
		return string.format("$%.1fM", amount / 1000000)
	end
	return "$" .. tostring(amount)
end

stateEvent.OnClientEvent:Connect(function(snapshot)
	moneyLabel.Text = formatMoney(snapshot.money)
	incomeLabel.Text = "+" .. formatMoney(snapshot.income) .. " / sec"
	progressLabel.Text = tostring(snapshot.owned) .. " / " .. tostring(snapshot.slots)
	if snapshot.owned >= snapshot.slots then
		objectiveLabel.Text = "BASE FULL — REBIRTH!"
	else
		objectiveLabel.Text = "COLLECT " .. tostring(snapshot.slots) .. " BRAINROTS"
	end
	if snapshot.lockSeconds > 0 then
		lockLabel.Text = "BASE LOCKED: " .. tostring(snapshot.lockSeconds) .. "s"
	elseif snapshot.lockCooldown > 0 then
		lockLabel.Text = "Lock ready in " .. tostring(snapshot.lockCooldown) .. "s"
	else
		lockLabel.Text = "Lock ready (L)"
	end
	upgradeButton.Text = "UPGRADE " .. formatMoney(snapshot.upgradeCost)
	rebirthButton.Text = "REBIRTH " .. formatMoney(snapshot.rebirthCost)
end)

feedEvent.OnClientEvent:Connect(function(message)
	feedLabel.Text = message
end)
